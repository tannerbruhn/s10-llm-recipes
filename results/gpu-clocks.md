# GPU clocks (2026-11-14)

The Mali-G76 runs at rates from Samsung's DVFS table; the firmware sets the voltage for each rate. Mainline
started at 433 MHz; Samsung's stock maximum is 702 MHz.

| GPU clock | Bonsai 27B generation, CPU + GPU |
|---|---|
| 433 MHz | 1.12, 1.10 |
| 572 MHz | 1.19-1.22 |
| 650 MHz | 1.17-1.22 |
| **702 MHz** | **1.26-1.27** (+14% over 433) |

- Rates outside Samsung's table (546 and 600 MHz) are rejected by the firmware.
- No GPU faults at any rate; output identical at all rates.
- Sustained runs at 702 MHz stayed inside our thermal limits (pause above a 10 s CPU average of 88 C).
