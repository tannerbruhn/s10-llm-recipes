#!/bin/sh
# Battery-less boots only (s10.nobatt=1). If a cell IS connected: on a one-shot test entry (guard masked) reboot at
# once (the entry is used up, the next boot is the normal one); on the permanent bare-board entry apply the normal
# battery rules instead (a reboot would land on the same entry again).
# Detection: without a cell the charger holds the battery node at its regulated ~4.35 V (VSYS 4.356 V measured in
# T1c), so the gauge reads >= 4.20 V; these phones cap the cell at 4.00 V, so a connected cell reads < 4.20 V.
# (BAT_DTLS and the gauge's "present" both claim a battery when none is connected: false alarm on 2026-11-17.)
B=/sys/class/power_supply/max170xx_battery
check() {
  v=$(cat $B/voltage_now 2>/dev/null || echo 0)
  d=$(i2cget -f -y 1 0x69 0xb4 2>/dev/null); bd=$(( (${d:-0} >> 4) & 7 ))
  echo "s10-nobatt guardrail: vbat=${v}uV present=$(cat $B/present 2>/dev/null) BAT_DTLS=$bd" > /dev/kmsg
  [ "$v" -ge 4200000 ]
}
sleep 3
check && { echo "s10-nobatt guardrail: no battery (vbat >= 4.20 V), test continues" > /dev/kmsg; exit 0; }
sleep 2
check && { echo "s10-nobatt guardrail: no battery on 2nd check, test continues" > /dev/kmsg; exit 0; }
if grep -q "systemd.mask=s10-thermal-guard" /proc/cmdline; then
  # one-shot test entry with the guard masked: reboot; the entry is used up, the next boot is the normal one
  echo "s10-nobatt guardrail: BATTERY CONNECTED on a test boot -> rebooting into the normal entry" > /dev/kmsg
  sync; systemctl reboot
else
  # permanent bare-board entry: a cell is there after all -> normal battery rules (guard sees the flag and runs in
  # normal mode; the charge-limit udev rule was skipped at boot, so apply its values here)
  touch /run/s10-cell-present
  P=/sys/class/power_supply/max77705-charger
  echo 4000000 > $P/constant_charge_voltage; echo 2000000 > $P/input_current_limit; echo 500000 > $P/constant_charge_current
  echo "s10-nobatt guardrail: BATTERY CONNECTED on the bare-board entry -> battery rules applied (4.00 V, 500 mA)" > /dev/kmsg
fi
