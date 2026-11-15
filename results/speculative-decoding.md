# Speculative decoding for Ornith 9B (2026-11-15)

A small model guesses the next tokens and Ornith checks several at once.

## Cost of checking k tokens at once (Ornith, 2 big cores)
| k | 1 | 2 | 3 | 4 | 8 | 16 |
|---|---|---|---|---|---|---|
| seconds | 0.30 | 0.53 | 0.75 | 0.57 | 1.07 | 2.08 |

## Generation tok/s (160-token answers; plain Ornith: 3.32-3.34)
| Setup | Code | Prose | Copy/edit task |
|---|---|---|---|
| Qwen3.5-0.8B Q8_0 draft, 3 tokens | 3.18 (54% accepted) | **1.88** (19%) | **4.75** (100%) |
| Qwen3.5-0.8B Q4_0 draft, 3 tokens | 3.00 (47%) | 1.77 (14%) | 4.88 (100%) |
| Q4_0 draft, 7 tokens | 1.34 | 0.82 | 4.59 |
| Q8_0 draft, only confident guesses (p >= 0.7) | 2.36 | 2.19 | 4.20 |
| n-gram lookup, no draft model | 2.92 | 3.05 | 3.79 |

Verdict: not a default on this phone. Checking tokens is compute-bound on a phone CPU, so wrong guesses cost almost
as much as generating. Only copy-heavy edits gain (+43-47%). DFlash-style drafts (16-token blocks) are ruled out by
the table above. Ornith 1.0 has no MTP head; Ornith 1.5 has one:

## Ornith 1.5 with its own MTP layer (2026-11-15)
| Text | tok/s (no MTP: 3.33) | guesses accepted |
|---|---|---|
| code | **3.94** (+18%) | 74% |
| copy/edit | **4.48** (+35%) | 88% |
| long prose | 3.26 (-2%) | 55% |
| short prose | 2.89 (-13%) | 45% |

Verdict: MTP works where a separate draft model fails, because the guesses come from the model itself. It pays above
~55% acceptance, so on this phone it is an opt-in preset for coding and editing, not the default.

## Cheaper 2-token checks (2026-11-15)
A kernel that reads Ornith's 4-bit weights once for two tokens: checking 2 tokens 0.53 -> 0.44 s (+21%), identical
output. With it, MTP guessing one token per round: code 3.33, prose 3.15, edits 3.41 tok/s (plain: 3.27 / 3.13 / 3.13),
so roughly break-even: each MTP guess runs the full output layer (1.1 GB). Guessing 3 tokens per round stays best for
code and edits.

## Ternary 27B with a small draft model
No MTP layer exists for Bonsai 2 27B. A Qwen3.5-0.8B draft (same tokenizer) ran at 0.31 tok/s vs 1.22 without it,
with 49% of guesses accepted, in our first setup (draft and 27B sharing the same 4 cores). Not a verdict yet.
