# S10 LLM recipes

Recipes for running LLMs on a Samsung Galaxy S10 (SM-G973F, Exynos 9820, 8 GB RAM) under postmarketOS.
Each folder is one model: where the weights come from, how to quantize them, how to run them, and what was measured.
All numbers are from one phone, measured with the scripts named in each recipe.

This repo was AI-written and tested on real hardware.

## The S10 project

These four repos turn an old Samsung Galaxy S10 (SM-G973F, Exynos 9820) into a small always-on LLM server under
postmarketOS. The kernel and U-Boot forks are general S10 support; the other two are the LLM side.

- [exynos-9820-mainline-linux](https://github.com/tannerbruhn/exynos-9820-mainline-linux): kernel (Wi-Fi, charger,
  Mali-G76 GPU through Panfrost)
- [u-boot](https://github.com/tannerbruhn/u-boot): bootloader and device tree (Wi-Fi, reserved memory, GPU node and
  clocks)
- [llama.cpp-s10](https://github.com/tannerbruhn/llama.cpp-s10): inference (ternary CPU kernels, Mali GPU assist)
- [s10-llm-recipes](https://github.com/tannerbruhn/s10-llm-recipes): models, quantization, server setup, measured
  numbers

Updates: [@t24_lab on X](https://x.com/t24_lab)

| Recipe | Model | File | Prompt tok/s | Generation tok/s | Quality |
|---|---|---|---|---|---|
| [ornith-1.5-9b](ornith-1.5-9b/) | Ornith 1.5 9B (default) | own IQ4_NL mix + MTP layer, 6.04 GB | ~7.5 | **3.33**; with MTP 3.94 code / 4.48 edits | hard set 6/8 (thinking) |
| [ornith-1.0-9b](ornith-1.0-9b/) | Ornith 1.0 9B (previous) | own IQ4_NL mix, 5.78 GB | 7.4-7.9 | 3.33 | wikitext PPL 9.23 (BF16 9.04) |
| [bonsai-2-27b](bonsai-2-27b/) | Ternary Bonsai 2 27B | PrismML PTQ1_0, 5.95 GB | ~2.0 | **1.21**; with the int2 CPU kernel **1.34** | ternary as published |

All of them run behind one OpenAI-compatible server that swaps between them on demand: see [server/](server/).

Everything else we measured, including what did not work: [results/](results/).

In daily use on two phones since 2026-11-17 (one served an agent for 15 h overnight without a restart):
- **int2 CPU kernel** in llama.cpp-s10 for the 27B (+8.5% short answers, +25-58% long ones; output unchanged).
- **+56 MB of RAM** from two unused reserved-memory regions (U-Boot fork) and **184 MB of CPU-only memory** from the
  modem carve-out ([setup/cpumem/](setup/cpumem/)).

New, tested on one board:
- **No battery needed:** the phone boots and serves the 27B on USB power alone, with 9 V requested over USB-PD
  (the 27B browns out a bare board at 5 V) and a fan ([setup/bare-board/](setup/bare-board/)); 7 h of agent use.

Experimental:
- **Two phones, one model** over llama.cpp RPC ([split/](split/)): the 27B split by layers runs at 1.16 tok/s over
  Wi-Fi with both phones cool and ~4 GB free on the first; tensor parallel works but needs Ethernet.
- A U-Boot safety hook for trying device-tree changes ([setup/uboot-pin/](setup/uboot-pin/)).

## What you need

- The phone setup in [setup/](setup/): postmarketOS with the Wi-Fi and GPU kernel/U-Boot forks.
- Our llama.cpp fork, [tannerbruhn/llama.cpp-s10](https://github.com/tannerbruhn/llama.cpp-s10) (`main`): the PrismML
  llama.cpp (for PTQ1_0) with ARM kernels for PTQ1_0 and a Mali GPU assist for the 27B.
  Pre-built for postmarketOS (aarch64, musl) on its
  [releases page](https://github.com/tannerbruhn/llama.cpp-s10/releases) (`llama-s10-b<build>-<commit>-bin-postmarketos-arm64.tar.gz`,
  upstream-style naming), or build it on the phone with the flags in the fork's AGENTS.md.
- For the 27B only: Mesa Rusticl (OpenCL) with a small Bifrost patch, see the 27B recipe.

## Measuring

- Speeds use `llama-bench` from a dropped page cache, with the phone below 50 C before each run, and
  alternate A/B runs (noise is about +/-0.03 tok/s). The charger is on, as in service.
- Perplexity uses wikitext-2 test, 12 chunks of 512 tokens. A desktop build of the same fork gives the same
  value as the phone within 0.2%, so quality runs can be done off the phone.
- Heat: the phone runs the thermal guard from [setup/safety](setup/safety/) (pause at a 10 s CPU average above 88 C or
  a die temperature above 75 C; charging off above a die temperature of 60 C). None of the results here needed a pause.
