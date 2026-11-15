# S10 LLM recipes

Recipes for running LLMs on a Samsung Galaxy S10 (SM-G973F, Exynos 9820, 8 GB RAM) under postmarketOS.
Each folder is one model: where the weights come from, how to quantize them, how to run them, and what was measured.
All numbers are from one phone, measured with the scripts named in each recipe.

This repo was AI-written and tested on real hardware.

| Recipe | Model | File | Prompt tok/s | Generation tok/s | Quality |
|---|---|---|---|---|---|
| [ornith-1.0-9b](ornith-1.0-9b/) | Ornith 1.0 9B | own IQ4_NL mix, 5.78 GB | 7.4-7.9 | **3.33** | wikitext PPL 9.23 (BF16 9.04) |
| [bonsai-2-27b](bonsai-2-27b/) | Ternary Bonsai 2 27B | PrismML PTQ1_0, 5.95 GB | ~2.0 | **1.21** | ternary as published |

Both models run behind one OpenAI-compatible server that swaps between them on demand: see [server/](server/).

## What you need

- The phone setup in [setup/](setup/): postmarketOS with the Wi-Fi and GPU kernel/U-Boot forks.
- Our llama.cpp fork, [tannerbruhn/llama.cpp-s10](https://github.com/tannerbruhn/llama.cpp-s10) (`main`): the PrismML
  llama.cpp (for PTQ1_0) with ARM kernels for PTQ1_0 and a Mali GPU assist for the 27B.
- For the 27B only: Mesa Rusticl (OpenCL) with a small Bifrost patch, see the 27B recipe.

## Measuring

- Speeds use `llama-bench` from a dropped page cache, with the phone below 50 C before each run, and
  alternate A/B runs (noise is about +/-0.03 tok/s). The charger is on, as in service.
- Perplexity uses wikitext-2 test, 12 chunks of 512 tokens. A desktop build of the same fork gives the same
  value as the phone within 0.2%, so quality runs can be done off the phone.
- Heat: the phone runs a thermal guard (pause at a 10 s CPU average above 88 C or a board temperature above 75 C,
  reduced charging above a board temperature of 60 C). None of the results here needed a pause.
