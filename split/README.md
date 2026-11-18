# Two phones, one model: the 27B over llama.cpp RPC (experimental)

Tested 2026-11-18 on two SM-G973F phones, both on Wi-Fi to the same router, with Ternary Bonsai 2 27B (PTQ1_0) and
llama.cpp-s10 built with `-DGGML_RPC=ON` (plus the usual flags from the fork's AGENTS.md). Phone A runs
`llama-server` and half of the layers; phone B runs `ggml-rpc-server` with the other half.

## Results (3 x 256-token answers back to back unless noted)
| Setup | Generation tok/s | Notes |
|---|---|---|
| one phone (bare board, airflow) | 1.27 / 1.17 / 1.12 | for comparison; 0-1 thermal pauses per answer |
| layer split, over a VPN on the phones | 1.06 / 1.05 / 1.07 | 0 pauses, CPUs 59-67 C on both phones |
| + output layer kept on phone A (`-ot`) | 1.05 (32 tokens) | +1.5% |
| + plain Wi-Fi instead of the VPN | **1.16** (32 tokens) | the VPN's software encryption cost ~45 ms per token |
| tensor parallel (`-sm tensor`), plain Wi-Fi | 0.49 (24 tokens) | correct output, but ~128 syncs per token at ~12 ms each |

What the layer split gives: the whole 27B at about one phone's speed, with both phones cool (each computes half
the time) and **~4 GB free on phone A** (one phone alone: ~350 MB). That room is enough for the vision projector
(`Ternary-Bonsai-2-27B-mmproj-Q8_0.gguf`, 0.63 GB; a test image was described correctly) and a 16k context.
It does not make one answer faster: the phones take turns.

Tensor parallel splits every layer across both phones, so each reads half the weights per token; it is the only
way to go faster than one phone, but it needs a link with well under 1 ms per round trip (Ethernet), not Wi-Fi.
It needs llama.cpp-s10 from 2026-11-18 or later (fix for the Hadamard sign vectors of the Bonsai models).

## Security first
`ggml-rpc-server` has **no authentication** and runs whatever graph a client sends. The postmarketOS kernel used
here has no firewall support (neither iptables nor nftables). Bind it only to an address on a network that holds
nothing but your own devices: a VPN interface on the phones, or a dedicated link between the two phones. Never on a
shared LAN or `0.0.0.0`.

## Run
Phone B (stop the normal LLM service first, same GPU-assist/int2 settings as `server/s10-llm.service`):
```sh
OCL_ICD_VENDORS=/home/user/mesa-idp/vendors RUSTICL_ENABLE=panfrost GGML_OPENCL_PLATFORM=0 \
GGML_S10_GPU_FRAC=0.35 GGML_S10_GPU_MINMB=6 GGML_S10_INT2=all \
GGML_S10_INT2_POOL=/dev/s10cpumem GGML_S10_INT2_POOL_MB=184 LLAMA_CACHE=/home/user/rpc-cache \
taskset -c 4-7 ggml-rpc-server -H <private address of phone B> -p 50052 -t 4 -c
```
Phone A (same environment):
```sh
llama-server -m Ternary-Bonsai-2-27B-PTQ1_0.gguf --rpc <private address of phone B>:50052 -ngl 32 \
  -ot '^output\.weight$=CPU,^output_norm\.weight$=CPU,^token_embd\.weight$=CPU' \
  -t 4 -C 0xf0 --cpu-strict 1 -c 4096 -np 1 --host 127.0.0.1 --port 8090
```
- `-ngl 32` puts the last 32 of the 64 layers on phone B. Moving the split does not change the speed (the phones
  take turns), only where the heat goes.
- `-c` on the RPC server caches the weights on phone B: the first load sends ~2.2 GB over the network, later loads
  read them locally (~2 min).
- Vision: add `--mmproj <mmproj file> --no-mmproj-offload` on phone A (the projector then runs on phone A's CPU).
- Tensor parallel: run `ggml-rpc-server` on both phones and point phone A's `llama-server` at both, with
  `-sm tensor -ngl 99` (`--rpc <A>:50052,<B>:50052`).

## Known issues
- **Restart `ggml-rpc-server` before every new load.** It outlives its clients, and the GPU-assist/int2 copies of a
  disconnected client's weights are not freed: the next load duplicates them and the phone runs out of memory.
- Each per-token transfer is 20 KB; with the VPN on the phones they ran at ~3-4 MB/s (5-8 ms each), on plain Wi-Fi
  at 1-4 ms. A direct phone-to-phone link (hotspot or Ethernet) is the next thing to try.
