# Ornith 1.5 9B on the S10: IQ4_NL mix "S10-M5" with MTP (default model)

Ornith-1.5-9B (ornith-ai) has the same architecture as 1.0 (Gated DeltaNet + 8 full-attention layers, same shapes
and tokenizer) plus one multi-token-prediction (MTP) layer. Our quant keeps that layer, so the model can run with
or without MTP speculation.

## Result (2 Samsung M4 big cores, cpus 6-7, charger on)

| | Generation tok/s |
|---|---|
| Ornith 1.5, no speculation (server default) | **3.31-3.33** on every kind of text |
| Ornith 1.5 + MTP, code | **4.07** (+23%, 74% of guesses accepted) |
| Ornith 1.5 + MTP, copy/edit tasks | **4.51** (+36%, 86%) |
| Ornith 1.5 + MTP, prose | **3.46** (+4%, 58%) |
| Ornith 1.0 (previous default) | 3.33 |

Prompt speed: ~7.5 tok/s. MTP numbers from release s10-b12179 (2026-11-19): rollback by replay replaced the
per-guess state snapshots, which made MTP faster (prose was 2.9-3.3, -2 to -13%, before) and saves 116 MB. The
server still runs plain 1.5 by default and offers MTP as a separate preset (`ornith-1.5-9b-mtp`).

**Ready-made file:** [tanman24/Ornith-1.5-9B-S10-GGUF](https://huggingface.co/tanman24/Ornith-1.5-9B-S10-GGUF)
(`Ornith-1.5-9B-S10-m5.gguf`, the exact file this recipe makes). Or make it yourself with the steps below.

| Quality | |
|---|---|
| Wikitext perplexity, BF16 | 10.15 |
| Wikitext perplexity, this quant | 10.56 (+4.0%) |
| Our 8-question hard set, thinking on | 6/8 (Ornith 1.0: 7/8; one sample each, within noise) |
| Same, quick mode (300 tokens) | 3/8 (Ornith 1.0 same day: 2/8) |

Perplexity on wikitext does not compare the two versions (1.5 is tuned further toward code and agents); it shows
how much the quant loses against 1.5's own BF16.

## 1. Sources

- `ornith-ai/Ornith-1.5-9B-GGUF`, file `Ornith-1.5-9B-BF16.gguf` (18.41 GB). Use this one: it is the BF16 that
  contains the MTP layer (`blk.32.nextn.*`).
- `bartowski/Ornith-1.5-9B-GGUF`, file `Ornith-1.5-9B-imatrix.gguf`.
- Our llama.cpp fork, [llama.cpp-s10](https://github.com/tannerbruhn/llama.cpp-s10).

## 2. Quantize

```sh
llama-quantize --imatrix Ornith-1.5-9B-imatrix.gguf --pure --output-tensor-type q8_0 \
  --tensor-type ssm_alpha=f32 --tensor-type ssm_beta=f32 --tensor-type ssm_out=q8_0 \
  --tensor-type 'blk\.32\.=q8_0' \
  Ornith-1.5-9B-BF16.gguf Ornith-1.5-9B-S10-m5.gguf IQ4_NL 8
```

Result: 6.04 GB; IQ4_NL 177, Q8_0 33 (output, 24 `ssm_out`, the 8 MTP-layer matrices), F32 232. sha256 of our file:
`df32e79d62f0e86350cd78409c0eab42adc99011a31de3da90b22f2a4bcfe862`.

The flags are the [Ornith 1.0 recipe](../ornith-1.0-9b/) plus `blk\.32\.=q8_0`: the MTP layer keeps 8 bits, since
the imatrix has no data for it and its accuracy sets the MTP acceptance rate.

## 3. Run

Plain (default):
```sh
llama-server -m Ornith-1.5-9B-S10-m5.gguf -t 2 -C 0xc0 --cpu-strict 1 -c 16384 -np 1 --jinja \
  --reasoning-budget 1000 --cache-ram 0 --ctx-checkpoints 4 --no-webui
```
With MTP, add `--spec-type draft-mtp`. Or use the [server](../server/) presets `ornith-1.5-9b` and
`ornith-1.5-9b-mtp`.
