# Bare board: run the S10 without a battery

New, tested on one SM-G973F board (2026-11-17/18) on a USB-PD charger (Steam Deck charger, 5/9/15/20 V):
- boots without a cell (`powersave` at boot, below), runs headless with the display disconnected;
- **on 9 V USB-PD (below) it served the 27B for 7 h** for an agent (1.21 tok/s), through 189 thermal-guard pauses,
  without a brown-out. On 5 V it browned out under the 27B at full clocks.
- needs airflow: see "Cooling".

## Why it did not boot before
Without a cell nothing buffers the load spike of all eight cores starting at the boot clock, and the phone resets
within about a second, before anything can lower the clocks. Starting the kernel with the `powersave` governor is
enough; once booted, the normal governor and clock caps work on USB power alone (`maxcpus=4` also boots, but the
big cores can then never be brought online: the kernel refuses them as CPU features were fixed without them).

## Install (on a phone that still has its battery, from this folder)
```sh
sudo install -m 755 05-s10-power.sh /etc/mkinitfs/hooks/        # 3 A input limit on s10.nobatt=1
sudo install -m 755 s10-nobatt-marker /usr/sbin/
sudo cp s10-nobatt.files /etc/mkinitfs/files/
sudo install -m 755 s10-nobatt-guardrail.sh /usr/sbin/s10-nobatt-guardrail
sudo cp s10-nobatt-guardrail.service s10-bare-governor.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable s10-nobatt-guardrail s10-bare-governor
sudo mkinitfs
```
Then a boot entry next to the normal one, copied from it (`/boot/loader/entries/`), with a sort key that sorts
first (e.g. `sort-key 0-0-bare`) and these additions on the `options` line:
```
cpufreq.default_governor=powersave s10.nobatt=1 systemd.mask=s10-power-keepalive.service
```
Also install the updated safety stack (`../safety/`): its thermal guard has a bare-board mode, and the charge-limit
rule steps aside on these boots.

## What changes on a bare-board boot
- initramfs hook: input limit 3 A (instead of 2 A).
- Charge-limit udev rule skipped; the thermal guard only protects against heat and leaves the charger alone (without
  a cell, the charge-voltage setting is the system-rail target: keep the driver's 4.35 V).
- `s10-bare-governor.service`: powersave -> schedutil once booted.
- Guardrail: if a cell is connected after all, it applies the normal battery rules (4.00 V, 500 mA) and the guard
  runs in normal mode. (With the gauge, "present" and the charger's battery bits all claim a cell when there is none;
  the cell voltage tells them apart: without a cell it sits at ~4.35 V, a cell capped at 4.00 V reads below 4.20 V.)
- `s10-nobatt-marker`: prints charger and fuel-gauge readings (VSYS, ISYS, IIN) to the console; useful for tests.

## Power: request 9 V over USB-PD (needed for the 27B)
At 5 V the 27B at full clocks needs 2.4-2.8 A at the input, right at the 3 A limit, and the input sags (4.93 ->
4.67 V measured). When the thermal guard resumes after a pause, the load jumps from ~0.9 to ~2.5 A in 0.4 s; on
2026-11-17 the ninth such jump reset the board. At 9 V the same ~12 W need only ~1.2-1.5 A.

The S10's MAX77705 has a USB-C/PD controller with its own firmware (I2C bus 1, address 0x25). Mainline binds no
driver to it, so nothing asks the charger for more than 5 V. `s10-pd` talks to it through the same command
interface as Samsung's vendor driver (`drivers/ccic/max77705_usbc.c`, `max77705_pd.c`): write the opcode and data
from register 0x21, 0x00 to 0x41, read the answer at 0x51 once UIC_INT (0x02) bit 7 is set.
- `s10-pd status` (read-only): controller revision, CC/PD status, the source's PDO list, the active PDO, VBUS.
- `s10-pd request N`: ask for PDO N (opcode 0x32).
- `s10-pd9v` + `s10-pd9v.service` (bare-board boots only): every 20 s, if a fixed 9 V PDO is offered and not
  active (after boot or a replug, which always start at 5 V), set the input limit to 2 A and request it.

```sh
sudo install -m 755 s10-pd /usr/local/sbin/s10-pd
sudo install -m 755 s10-pd9v /usr/local/sbin/s10-pd9v
sudo cp s10-pd9v.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable --now s10-pd9v
sudo s10-pd status
```
Measured on 9 V (27B, 3 x 256-token answers, 117 guard pauses): input current at most 1.54 A, VBUS at least
8.74 V, system rail steady at 4.35 V. A replug falls back to 5 V until the service asks again (~20 s); a charger
without PD stays at 5 V (then keep to the 9B models, or lower the clocks).

## Cooling
Without its upper frame part (the antenna carrier that also presses the board onto the thermal pad) and with no
airflow, the board hit the guard's pause threshold every few seconds: 25/43/49 pauses on three back-to-back
256-token answers (0.58/0.40/0.32 tok/s). Extra screws with nylon washers to press the board down: 23/28/29
(0.61/0.53/0.52). The same plus gentle airflow on the display-side frame (an air purifier on low): **0/1/0 pauses,
1.27/1.17/1.12 tok/s**, the full speed of the battery phone. A fan is required; in sunlight or a warm room more
airflow is needed.

## Supply
Use a USB-PD charger that offers 9 V (most phone/laptop PD chargers) and a short cable. Laptop USB ports
(0.5-0.9 A) are too weak. The USB port carries power only, so the network is Wi-Fi (the antennas sit in the frame:
keep it, or expect a weak signal; -79 dBm without the upper frame part).
