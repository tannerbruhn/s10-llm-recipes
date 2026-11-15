# Ternary Bonsai 2 27B on the S10: CPU + Mali GPU

PrismML's Ternary-Bonsai-2-27B has ternary weights (-1/0/+1, one fp16 scale per 128 weights). In the PTQ1_0
format the whole 27B is 5.95 GB, which fits in the S10's 8 GB. Generation is limited by memory bandwidth, so this
recipe makes the CPU read ternary weights as cheaply as possible and gives part of every matrix to the Mali-G76 GPU.

## Result (cpus 4-7: 2 Samsung M4 + 2 Cortex-A75; GPU at the stock 702 MHz; charger on)

| Setup | Prompt (pp128) | Generation (tg24) |
|---|---|---|
| PrismML llama.cpp as published (same 4 cores, clocks capped then) | 0.66 | 0.48 |
| our fork, CPU only | 1.56-1.66 | 0.85 |
| **our fork, CPU + GPU (FRAC 0.45)** | **1.98** | **1.21-1.27** |

- Sustained: tg128 1.17 tok/s at 702 MHz, with no thermal-guard pauses.
- Server, heat-soaked, two 256-token answers back to back: 1.12 then 1.07 tok/s. The second one had one 6 s
  thermal-guard pause (CPU 10 s average 88.2 C), and the guard cut the charge current once (board 61 C).
- Through the server: one 48-token answer gave prompt 1.80 and generation 1.21 tok/s.
- Output with the GPU is identical to CPU-only greedy output. Perplexity on wikitext-2 (12x512) is 11.1794 with
  and without the new prompt kernel.

## 1. Sources

- `prism-ml/Ternary-Bonsai-2-27B-gguf`, file `Ternary-Bonsai-2-27B-PTQ1_0.gguf` (5.95 GB). No requantizing:
  PTQ1_0 is the native ternary format.
- Our llama.cpp fork, branch `mali-port`: the PrismML llama.cpp (PTQ1_0 support) plus:
  - a two-row PTQ1_0 dot kernel with prefetch of the next row pair (generation, CPU only 0.76 -> 0.86);
  - a decode-once prompt kernel that unpacks each row pair once and reuses it for every token (CPU pp +33%);
  - the GPU assist `ggml-cpu/s10-gpu-assist.c`: on each PTQ1_0 matrix-vector product the GPU computes the first
    `GGML_S10_GPU_FRAC` of the rows while the CPU threads do the rest. Weights are re-encoded for the GPU once,
    at first use, and the CPU's copy of those rows is dropped from RAM.
- Mesa 26.2.6 Rusticl (OpenCL on Panfrost) with [bifrost-v7-idp.patch](bifrost-v7-idp.patch): Mesa lowers OpenCL's
  int8 `dot()` to scalar code on Bifrost v7 although the G76 has a 4-way int8 dot instruction. With the patch the
  GPU kernel is 43% faster. Build with [build-rusticl.sh](build-rusticl.sh) in an `alpine:edge` aarch64 container
  (postmarketOS is musl).

## 2. Phone setup

- Kernel and U-Boot from [setup/](../setup/): Panfrost support for the Exynos 9820 and the GPU rates up to 702 MHz.
- Install the patched `libRusticlOpenCL.so` somewhere private (for example `/home/user/mesa-idp/`) and point an ICD
  file at it:

```sh
mkdir -p /home/user/mesa-idp/vendors
echo /home/user/mesa-idp/libRusticlOpenCL.so.1 > /home/user/mesa-idp/vendors/rusticl-idp.icd
```

- Build our fork on the phone with `-DGGML_CPU_S10_GPU_ASSIST=ON` (plus the OpenCL headers and ICD loader).

## 3. Run

```sh
D=/sys/class/devfreq/18500000.gpu        # as root: pin the GPU at 702 MHz while serving
echo 702000000 > $D/max_freq; echo 702000000 > $D/min_freq

export OCL_ICD_VENDORS=/home/user/mesa-idp/vendors RUSTICL_ENABLE=panfrost
export GGML_S10_GPU_FRAC=0.45 GGML_S10_GPU_MINMB=6
llama-server -m /home/user/models/Ternary-Bonsai-2-27B-PTQ1_0.gguf --alias bonsai-27b \
  -t 4 -C 0xf0 --cpu-strict 1 -c 8192 -np 1 --jinja --reasoning-budget 1000 \
  --cache-ram 0 --ctx-checkpoints 4 --host 0.0.0.0 --port 8080 --no-webui --api-key-file /etc/s10-llm/api-key
```

Or use the [server](../server/) preset `bonsai-27b`, which does all of this.

Why these settings:

- **Pin the GPU clock.** The devfreq governor does not raise the clock for the short bursts of GPU work, and the
  assist then waits on a slow GPU. The GPU suspends itself when idle, so the pin costs nothing when no model is
  using it. 702 MHz is Samsung's stock maximum; the firmware (ACPM) sets the voltage for each rate.
- **FRAC 0.45:** the best share for generation. 0.35 gives 5-10% faster prompts but about 10% slower generation.
- **MINMB 6:** skip tensors under 6 MB (small ones cost more in GPU dispatch than they save).
- **cpus 4-7, 4 threads, strict:** the OpenCL driver threads stay on the little cores 0-3.

## Steps and dead ends

Every step was measured and committed separately; the full log is `gpu/ASSIST.md` in the work repo. Things that
did not help: a third and fourth row in the CPU kernel (register spills), an 8-column GPU prompt kernel
(1.38 vs 1.97 tok/s), huge pages (TLB cost was only 1-2%), and rates outside Samsung's DVFS table (rejected by
the firmware).
