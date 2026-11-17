#!/bin/sh
# S10 initramfs hook: make early boot survivable on USB power without a battery.
# The MAX77705 driver starts with a 500 mA input limit and the big cores at full clock; on a
# battery-less phone the boot load then browns the phone out before userspace can fix it.
# Battery-less test flags (cmdline): s10.nobatt=1 (3 A, marker lines), s10.nobatt_factory=1 (Samsung factory charger
# state: AICL off, buck only), s10.nobatt_hold=1 (stay here printing markers every 250 ms, never continue).
P=/sys/class/power_supply/max77705-charger
C=$(cat /proc/cmdline)
case " $C " in *" s10.nobatt=1 "*) NB=1;; *) NB=0;; esac
if [ $NB = 1 ]; then
  [ -w $P/input_current_limit ] && echo 3000000 > $P/input_current_limit
else
  [ -w $P/input_current_limit ] && echo 2000000 > $P/input_current_limit
fi
# Cap M4 (policy6) and A75 (policy4) pairs to their minimum until s10-cpucap.service sets the normal caps.
for n in 4 6; do
  f=/sys/devices/system/cpu/cpufreq/policy$n
  [ -r $f/cpuinfo_min_freq ] && cat $f/cpuinfo_min_freq > $f/scaling_max_freq
done
echo "s10-power hook: ilim=$(cat $P/input_current_limit 2>/dev/null) m4max=$(cat /sys/devices/system/cpu/cpufreq/policy6/scaling_max_freq 2>/dev/null)" > /dev/kmsg 2>/dev/null
if [ $NB = 1 ]; then
  case " $C " in *" s10.nobatt_factory=1 "*)
    # CNFG_06 (0xbd) bit 4 = DIS_AICL; CNFG_00 (0xb7) low nibble 0x4 = buck on, charger off
    r=$(i2cget -f -y 1 0x69 0xbd) && i2cset -f -y 1 0x69 0xbd $(printf 0x%02x $(( r | 0x10 )))
    r=$(i2cget -f -y 1 0x69 0xb7) && i2cset -f -y 1 0x69 0xb7 $(printf 0x%02x $(( (r & 0xf0) | 0x04 )))
    echo "s10-power hook: factory state (DIS_AICL, buck only)" > /dev/kmsg;;
  esac
  s10-nobatt-marker
  case " $C " in *" s10.nobatt_hold=1 "*)
    echo "s10-power hook: HOLD - staying in the initramfs" > /dev/kmsg
    while :; do s10-nobatt-marker; sleep 0.25; done;;
  esac
fi
true
