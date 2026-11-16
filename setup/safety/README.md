# Safety parts for a phone that runs 24/7 on the charger

Install these before `server/s10-llm.service`: `sudo ./install-safety.sh`. The LLM service refuses to start
without the guard.

| File | What it does |
|---|---|
| `s10-thermal-guard.sh` | Polls every 2 s. Hot (CPU/GPU 10 s average > 88 C, or die > 75 C): freezes the LLM service, stops other known heavy tools, clamps big cores and GPU to minimum. Charging off when the die is > 60 C or the estimated cell temperature is > 48 C. Critical (CPU > 100 C twice, or die > 85 C): everything above, then poweroff if it does not cool within 60 s. Missing or frozen sensors count as hot. Every action is re-asserted every 10 s |
| `s10-thermal-guard.service` | Runs the guard under a systemd watchdog: a hung guard is killed and restarted within 30 s; never OOM-killed |
| `s10-guard-failed.service` | If the guard stays down: stops the LLM service and switches charging off |
| `s10-cpucap.service` | Caps the M4 pair at 1.976 GHz and the A75 pair at 1.898 GHz (the guard restores these values after a clamp; change both together) |
| `s10-gpu-cap.service` | GPU at 433 MHz at boot; the LLM service raises it to 702 MHz while serving |
| `90-s10-charge-limit.rules` | Charge voltage 4.00 V (about 60-65 %), charge current 500 mA |

What to know:

- **There is no battery temperature on this port.** The fuel gauge reports a fixed 37.3 C. The guard estimates
  the cell temperature as a slow (about 15 min) average of the die temperature, so charging waits after a long hot
  run. It is an estimate, not a measurement.
- **The charger latches "Full" and never restarts on its own** with the mainline driver. The guard turns on the
  chip's restart (150 mV below the charge voltage) and restarts a latched charge itself.
- **The guard holds the charge voltage at 4.00 V or below**, even if the udev rule is lost.
- **The critical poweroff** has not been observed with the cable in. The phone may end up in the bootloader's
  charging screen rather than off. The guard tries hard to cool the phone in Linux first.
- **Placement matters more than any script:** a non-flammable surface, no case, back glass in free air, out of
  the sun, a smoke detector in the room. Check for a swollen battery (phone rocks on a table, gap at the back
  seam, lifted screen) every week, and stop charging that phone if you see one.
