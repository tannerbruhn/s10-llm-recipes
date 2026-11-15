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
the table above. Ornith 1.0 has no MTP head; Ornith 1.5 has one (not tested yet).
