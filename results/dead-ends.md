# Dead ends

Things we tried and dropped, with the number that decided it.

| Idea | Result |
|---|---|
| GPU help for 4-bit Ornith | predicted 2.89 tok/s vs 3.35 on the CPU alone ([gpu-assist.md](gpu-assist.md)) |
| Speculative decoding as a default | prose -44% ([speculative-decoding.md](speculative-decoding.md)) |
| Huge pages for the 27B | TLB misses cost only 1-2% |
| CPU kernel with 3-4 ternary rows at once | ~0.4x (runs out of registers) |
| 8-column GPU prompt kernel | 1.38 tok/s vs 1.97 with 4 columns |
| A third GPU kernel layout for the 27B | 1.08 tok/s, same as the second (1.09) |
| GPU rates 546 / 600 MHz | rejected by the firmware |
| Q4_K_M on our fork's ARM path | 2.60 tok/s vs 3.33 for our IQ4_NL mix (no fast path for K-quants) |
| Plain Q4_0 for Ornith | best Q4_0 mix 5.4% worse perplexity than BF16; IQ4_NL at the same size is 2.1% |
| Bonsai 2 9B as a daily model | as fast as Ornith (~3.0 tok/s) but worse answers |
| GPU share 0.35 instead of 0.45 for the 27B | prompts 5-10% faster, generation ~10% slower |
