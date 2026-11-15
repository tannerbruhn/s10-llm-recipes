# One server for all models

`llama-server` from our fork runs in router mode: one OpenAI-compatible endpoint on port 8080, and the `model`
field of each request picks the model. Only one model fits in 8 GB, so `--models-max 1`: asking for the other model
stops the current one and loads the requested one.

- [s10-models.ini](s10-models.ini): one section per model, with its threads, cores, context and file. Copy to
  `/etc/s10-llm/s10-models.ini`. Presets: `ornith-1.5-9b` (default, loaded at start), `ornith-1.5-9b-mtp` (same
  model with MTP speculation, for coding agents and edit jobs), `ornith-1.0-9b`, `bonsai-27b`.
- [s10-llm.service](s10-llm.service): the systemd unit. It sets the GPU-assist environment (only the 27B's PTQ1_0
  weights use it; Ornith never opens OpenCL), pins the GPU at 702 MHz while it runs, and returns the GPU to a
  433 MHz cap when it stops.
- [swaptest.sh](swaptest.sh): sends one request per model named and prints the wall time (including any swap) and
  the server's own speeds.

## Measured (swaptest.sh, 48-token prose answers)

With Ornith 1.5 (2026-11-15): `ornith-1.5-9b` 3.34 tok/s, `ornith-1.5-9b-mtp` 2.89 on this prose prompt (MTP is for
code and edits), `ornith-1.0-9b` 3.34, `bonsai-27b` 1.20; every swap clean. Earlier, with Ornith 1.0 as default:

| Request | Wall time | Prompt tok/s | Generation tok/s |
|---|---|---|---|
| ornith-1.0-9b (already loaded) | 18 s | 7.4 | 3.33 |
| bonsai-27b (swap in) | 142 s, of which ~100 s loading | 1.80 | 1.21 |
| ornith-1.0-9b (swap back) | 49 s, of which ~30 s loading | 7.6 | 3.35 |

The old model process exits before the new one loads; with the 27B loaded, 3.1 GB of RAM stays free.

## Default model

Clients written for a single-model server often send no model name, or a name the router does not know (for
example `gpt-4o`). Our fork adds `LLAMA_ROUTER_DEFAULT_MODEL` (here `ornith-1.5-9b`): such requests go to that model, and the router logs a
warning for unknown names. Upstream llama.cpp answers them with an HTTP 400.

## Notes

- Upstream's flag is `--no-webui`; ik_llama.cpp's `--webui none` makes upstream exit with "invalid argument: none".
- `--api-key-file` is applied by the router; the model processes listen only on 127.0.0.1.
- A thermal guard that pauses heavy jobs must match both the router and its child process: they are both named
  `llama-server`.
