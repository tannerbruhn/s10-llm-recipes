# CPU + Mali GPU (2026-11-14/15)

The GPU computes part of every weight matrix while the CPU does the rest.

## Ternary Bonsai 2 27B: it pays
| Setup | Generation tok/s |
|---|---|
| CPU only (4 cores), our kernels | 0.85 |
| CPU + GPU, GPU at 433 MHz | 1.12-1.13 |
| CPU + GPU, GPU at 702 MHz | **1.21-1.27** |
| same, sustained 128 tokens | 1.17 |
| same, heat-soaked server, 2 x 256 tokens | 1.12, 1.07 |

Output with the GPU is identical to CPU-only output. Prompt speed with the GPU: ~2.0 tok/s (CPU only 1.56-1.66).

## Ornith 9B (4-bit IQ4_NL): it does not
| | |
|---|---|
| Ornith alone, CPU | 3.35 tok/s |
| CPU + GPU memory bandwidth together | ~25 GB/s (CPU alone ~17.4): the memory has room |
| Best 4-bit GPU kernel | 5.85 GB/s alone, 5.2 GB/s next to the CPU |
| Cost of one CPU-to-GPU hand-off | ~0.3-0.4 ms (Rusticl + Panfrost) |
| Predicted with the GPU | **2.89 tok/s** (2.99 with fused calls): slower than the CPU alone |

Verdict: GPU help pays for models whose matrix work is heavy per call (ternary weights keep the CPU busy). For
4-bit models with ~176 light calls per token, the fixed hand-off cost eats the gain.
