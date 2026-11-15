# Models on the S10

## Speed (tokens/s, prompt / generation)
Measured 2026-11-12/13 on mainline postmarketOS, stock llama.cpp builds of that time, 2 big cores, before any of our
kernel work. Current numbers for the two models we serve are in the recipes.

| Model | Size | Prompt | Generation |
|---|---|---|---|
| Gemma 4 E4B Q4_K_M | 5.0 GB | 13.2 | 4.6 |
| Qwen3.5-4B Q4_K_M | 2.7 GB | 10.5 | 4.4 |
| Qwen3-4B Q4_K_M | 2.5 GB | 10.7 | 4.2 |
| Qwen3.5-9B Q4_K_M | 5.7 GB | 5.6 | 2.45 |
| Ornith 1.0 9B Q4_K_M | 5.7 GB | 5.6 | ~2.45 |
| Ministral 3 8B Q4_K_M | ~5 GB | 5.3 | ~2.2 |
| Granite 4.1 8B Q4_K_M | ~5 GB | 3.3 | 1.6 |
| Bonsai 2 9B PTQ1_0 (ternary) | 2.0 GB | 1.63 | 1.32 |
| Bonsai 2 27B PTQ1_0 (ternary) | 5.95 GB | 0.46 | 0.41 |

## Now, with our fork (2026-11-15)
| Model | Prompt | Generation |
|---|---|---|
| Ornith 1.5 9B, our IQ4_NL mix + MTP layer | ~7.5 | 3.33 (MTP: 3.94 code, 4.48 edits) |
| Ornith 1.0 9B, our IQ4_NL mix | 7.9 | 3.33 |
| Bonsai 2 27B, CPU + GPU | ~2.0 | 1.21-1.27 |
| Bonsai 2 9B, CPU + GPU | 6.9 | ~3.0 |

## Answer quality (our 8-question set: reasoning, facts, a constrained verse, a shell task)
| Model | Score |
|---|---|
| **Bonsai 2 27B, thinking** (budget 1000) | **8/8**, the only model to write the constrained verse correctly |
| Ornith 1.0 9B, thinking (budget 1000) | 7/8 |
| Ornith 1.5 9B, thinking (budget 1000), our quant + MTP | 6/8 (missed the clock-cap trap) |
| Ornith 1.5 9B, no thinking | 3/8 (Ornith 1.0 same day: 2/8) |
| Bonsai 2 27B, no thinking | 3/8 |
| Ornith 1.0 9B, no thinking | 3/8 |
| Qwen3.5-9B, no thinking | 2.5/8 |

Verdict: Ornith 1.5 is the daily model (equal to 1.0 within noise on this set, faster with MTP on code) (fast enough to chat). The 27B is for hard questions where waiting is fine.
Bonsai 2 9B is as fast as Ornith on our stack but gave worse answers, so it is not served. Eight questions is a
small set; treat the scores as a hint, not a ranking.
