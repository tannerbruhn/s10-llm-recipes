# Ornith 1.0 9B on the S10: own IQ4_NL mix "S10-M5"

Ornith-1.0-9B (deepreinforce-ai / ornith-ai) is a hybrid model: Gated DeltaNet layers plus 8 full-attention
layers. This recipe keeps quality close to Q4_K_M while using only tensor types that have fast ARM repack paths in
our fork (IQ4_NL and Q8_0), so it generates 7% faster than the best previous setup (ik_llama.cpp + Q4_K_M).

## Result (2 Samsung M4 big cores, cpus 6-7)

| Engine + file | Size | pp64 | tg64 | Wikitext PPL |
|---|---|---|---|---|
| BF16 (reference, desktop) | 17.9 GB | - | - | 9.0376 |
| ik_llama.cpp `-rtr` + unsloth Q4_K_M (previous) | 5.70 GB | 8.07 | 3.11 | 9.0834 |
| our fork + unsloth Q4_0 | 5.40 GB | 8.27 | 3.13 | 9.5063 |
| **our fork + S10-M5 (this recipe)** | 5.78 GB | 7.86 | **3.33** | 9.2301 |
| our fork + S10-M6 (more Q8_0) | 6.40 GB | 8.05 | 3.14 | 9.1922 |

Through the server (one 48-token answer, the GPU not involved): prompt 7.4-7.6, generation 3.33-3.35.

## 1. Sources

- `bartowski/deepreinforce-ai_Ornith-1.0-9B-GGUF`: the BF16 GGUF and its `imatrix.gguf`
  (calibration_datav5, 248 entries).
- Our llama.cpp fork ([llama.cpp-s10](https://github.com/tannerbruhn/llama.cpp-s10)) built on any desktop or server: `llama-quantize`, `llama-perplexity`.

## 2. Quantize

```sh
llama-quantize --imatrix imatrix.gguf --pure --output-tensor-type q8_0 \
  --tensor-type ssm_alpha=f32 --tensor-type ssm_beta=f32 --tensor-type ssm_out=q8_0 \
  Ornith-1.0-9B-bf16.gguf Ornith-1.0-9B-S10-m5.gguf IQ4_NL 8
```

Resulting mix: IQ4_NL 177, Q8_0 25 (output + 24 `ssm_out`), F32 225. sha256 of our file:
`e38403949fe96c407e6a3544f6bf8cedbf86e44c2c2e65b6c5d301b2693bfec5`.

Why each flag:

- `--pure` keeps everything in one fast type. Q4_K/Q5_K/Q6_K have no repack path on this CPU in our fork; the
  same model in Q4_K_M runs only 2.60 tok/s there.
- `--pure` also quantizes the 48 DeltaNet gate projections `ssm_alpha`/`ssm_beta` (4096x32 each), which every
  published quant keeps in F32. They are tiny and quality-sensitive, so they are forced back to F32.
- `ssm_out=q8_0` and an 8-bit `output.weight`: published files protect `ssm_out` too (unsloth Q5_K, bartowski Q8_0).
- IQ4_NL instead of Q4_0: same size and speed on this CPU, much better quality. Our best Q4_0 mix stayed 5.4% above
  BF16 in perplexity; the same mix in IQ4_NL is 2.1% above.

The mixes tried along the way (M1-M6) and their perplexities are in [STEPS.md](STEPS.md).

## 3. Check quality (optional, off the phone)

```sh
llama-perplexity -m Ornith-1.0-9B-S10-m5.gguf -f wiki.test.raw -c 512 --chunks 12 -t 8
# expect: Final estimate: PPL = 9.2301
```

## 4. Run

Copy the file to the phone (`/home/user/models/`), then either use the [server](../server/) preset
`ornith-1.0-9b`, or run it alone:

```sh
llama-server -m /home/user/models/Ornith-1.0-9B-S10-m5.gguf --alias ornith-1.0-9b \
  -t 2 -C 0xc0 --cpu-strict 1 -c 16384 -np 1 --jinja --reasoning-budget 1000 \
  --cache-ram 0 --ctx-checkpoints 4 --host 0.0.0.0 --port 8080 --no-webui --api-key-file /etc/s10-llm/api-key
```

- 2 threads on the two big cores (cpus 6-7) is the fastest setting: generation is limited by memory bandwidth, and
  more threads make it slower and hotter.
- Thinking is on with a 1000-token budget. Clients can turn it off per request with
  `"chat_template_kwargs": {"enable_thinking": false}`.
