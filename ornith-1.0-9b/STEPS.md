# Ornith 9B: our own Q4_0 mix for the S10 (started 2026-11-14 evening)

Goal: Q4_K_M-level quality on tensor types that have fast paths in our fork (Q4_0 / Q8_0 repack on dotprod),
for one fork and no ik_llama.

## 1. Why (measured)
- Perplexity, wikitext-2 test, 12 chunks x 512, our fork, 2 M4: unsloth Q4_0 **9.51 +/- 0.46**,
  unsloth Q4_K_M **9.07 +/- 0.43** (Q4_0 +4.9%).
- Speed, 2 M4, pp64/tg: our fork unsloth Q4_0 8.24-8.28 / 3.09-3.15; ik Q4_K_M -rtr 8.06 / 3.08-3.12;
  ik Q4_0 -rtr 7.53-7.56 / 3.51-3.63; our fork Q4_K_M 5.53 / 2.60.
- Tensor mix (header read with `gguf_types.py`):
  - unsloth Q4_0 (already imatrix, unsloth calibration): Q4_0 173, Q5_K 24, Q4_1 4, Q6_K 1 (output)
  - bartowski Q4_0 (imatrix, calibration_datav5): Q4_0 181, Q8_0 12, Q6_K 5, Q4_1 4
  - bartowski IQ4_NL: IQ4_NL 177, Q8_0 12, Q6_K 13
  - every file: output.weight [4096 x 248320] in Q6_K (~0.8 GB, ~15% of the bytes read per token), and Q6_K / Q5_K /
    Q4_1 have no repack (fast) path in our fork on this CPU.

## 2. Sources
- bartowski/deepreinforce-ai_Ornith-1.0-9B-GGUF: `...-bf16.gguf` (17.92 GB) and `...-imatrix.gguf`.
- Quantizer: our fork (gpu/llama-mali) `llama-quantize`, built on an ARM64 desktop (CPU, GGML_NATIVE).

## 3. Mixes (quantized on the desktop 2026-11-14 ~22:00 local, ~29 s each, 8 threads)
Common: `llama-quantize --imatrix imatrix.gguf --pure --output-tensor-type q8_0
--tensor-type ssm_alpha=f32 --tensor-type ssm_beta=f32 ornith-bf16.gguf OUT.gguf Q4_0 8`
- M1 "all fast" (5.58 GB): the common command. Mix: Q4_0 201, Q8_0 1 (output), F32 225.
- M2 "quality-tuned" (5.67 GB): + `--tensor-type attn_v=q8_0 --tensor-type "blk\.[0-2]\.ffn_down=q8_0"`
  (11 overrides: attn_v exists only in the 8 full-attention layers). Mix: Q4_0 190, Q8_0 12, F32 225.
- Lesson: `--pure` alone also quantized the 48 DeltaNet gate projections (`ssm_alpha`, `ssm_beta`, 4096x32 each) that
  every published quant keeps in F32. Tiny (no speed value), quality-sensitive: forced back to F32. The first
  M1/M2 build (5.56/5.65 GB) was discarded for this.
- Files on the phone: `~/models/Ornith-1.0-9B-S10-m1.gguf`, `...-m2.gguf` (sha256 checked after copy).

## 4. More mixes (after M1 was worse than unsloth Q4_0)
Published files protect `ssm_out` (unsloth Q5_K x24, bartowski Q8_0 x12); Q4_K_M also puts Q6_K on
attn_qkv layers 0,1,2,6,9,12,18,21,24,28,29,30, ffn_down layers 0,1,2,3,6,9,12,15,18,21,24,27,28,29,30,31 and
attn_v layers 3,15,27,31. All of ours keep `ssm_alpha/ssm_beta` F32 and output Q8_0.
- M3 = M1 + `ssm_out=q8_0` (5.78 GB)
- M4 = M3 + Q8_0 on exactly Q4_K_M's Q6_K layers (6.40 GB)
- M5 = M3 on IQ4_NL instead of Q4_0 (5.78 GB)
- M6 = M4 on IQ4_NL (6.40 GB)

## 5. Perplexity on the desktop (same text and settings; desktop and phone agree to ~0.2%)
| File | Size | PPL | vs BF16 |
|---|---|---|---|
| BF16 (reference) | 17.9 GB | 9.0376 | - |
| unsloth Q4_K_M (production, ik) | 5.70 GB | 9.0834 | +0.5% |
| unsloth Q4_0 | 5.40 GB | 9.5063 | +5.2% |
| M1 pure Q4_0 + output Q8_0 | 5.58 GB | 9.6603 | +6.9% |
| M2 M1 + attn_v + ffn_down 0-2 Q8_0 | 5.67 GB | 9.5416 | +5.6% |
| M3 M1 + ssm_out Q8_0 | 5.78 GB | 9.5301 | +5.4% |
| M4 M3 + Q4_K_M's layers Q8_0 | 6.40 GB | 9.3600 | +3.6% |
| **M5 IQ4_NL + ssm_out/output Q8_0** | 5.78 GB | **9.2301** | +2.1% |
| **M6 IQ4_NL + M4's Q8_0 layers** | 6.40 GB | **9.1922** | +1.7% |
(phone cross-check: unsloth Q4_0 9.5101, Q4_K_M 9.0656, M1 9.6641)
Q4_0 itself is the limit; IQ4_NL (non-linear 4-bit, repack 4x4 on dotprod in our fork) closes most of the gap.
Next: speed of M5/M6 on the phone vs ik + Q4_K_M.

## 6. Speed on the phone (2026-11-15 ~00:50, 2 M4, ornith-compare.sh: dropped cache + <50 C per run, pp64 / tg64 -r 2, alternating, charger on)
| Engine + file | pp64 | tg64 | PPL |
|---|---|---|---|
| ik -rtr + unsloth Q4_K_M (production) | 8.07, 8.08 | 3.11, 3.12 | 9.0834 |
| **ours + M5** (IQ4_NL, 5.78 GB) | 7.86, 7.86 | **3.34, 3.33** | 9.2301 |
| ours + M6 (IQ4_NL + Q8_0 layers, 6.40 GB) | 8.05, 8.06 | 3.14, 3.15 | 9.1922 |
| ours + unsloth Q4_0 | 8.27, 8.27 | 3.13, 3.14 | 9.5063 |
Our fork replaces ik for Ornith: M5 = +7% generation, -3% prompt, +1.6% perplexity vs production;
M6 = production speed, +1.2% perplexity. M5 chosen as the default (2026-11-15). sha256: M5 e384039..., M6 ed9a7fa...
(full hashes in the recipe README).
