# Results

What we measured on the Galaxy S10 (SM-G973F, Exynos 9820, 8 GB) and what we concluded, including what did not
work. Numbers only; each page says when it was measured and under which conditions.

| Page | Verdict |
|---|---|
| [models.md](models.md) | Ornith 1.5 9B is the daily model; the ternary 27B wins on hard questions but runs at ~1.2 tok/s |
| [gpu-assist.md](gpu-assist.md) | The Mali GPU speeds up the ternary 27B by ~45%; for 4-bit models it makes things slower |
| [gpu-clocks.md](gpu-clocks.md) | Running the GPU at Samsung's stock 702 MHz is worth +14% on the 27B |
| [speculative-decoding.md](speculative-decoding.md) | A draft model loses on prose; Ornith 1.5's own MTP layer gives +18% on code, +35% on edits |
| [platform.md](platform.md) | Mainline Linux frees ~2.9 GB of RAM over stock Android; Wi-Fi ~200 Mbit/s |
| [dead-ends.md](dead-ends.md) | Everything we tried and dropped, with the number that decided it |

Updates: [@t24_lab on X](https://x.com/t24_lab)
