# Bare board: run the S10 without a battery (experimental)

Tested on one SM-G973F board, 2026-11-17, on a Steam Deck charger: full boot, then the 27B with the GPU assist at
1.32 tok/s and Ornith 1.5 9B at 3.34 tok/s, system voltage flat at 4.355 V. Not yet run for hours.

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

## Supply
Up to ~1 A at 5 V was drawn under full load (5 s sampling). Laptop USB ports (0.5-0.9 A) are too weak; use a real
charger and a short cable. The USB port carries power only, so the network is Wi-Fi (the antennas sit in the frame:
keep it, or expect a weak signal).
