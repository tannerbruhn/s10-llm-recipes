#!/bin/sh
# s10-thermal-guard v2 (polls every 2 s): safety net for an always-on, always-plugged-in Galaxy S10.
#
# Sensors: all five zones are channels of ONE on-die TMU. "die" below is isp-thermal, the slowest on-die
# channel: it is silicon temperature, NOT board or battery temperature. The battery thermistor is not
# wired on this port, so the cell temperature is ESTIMATED: a ~15 min low-pass of the die temperature.
#
#  heavy jobs   CPU/GPU 10 s average > 88 C, or die > 75 C   -> freeze s10-llm's cgroup + SIGSTOP known heavy
#                                                               tools + clamp big cores and GPU to minimum
#               resume when average < 75 C and die < 70 C
#  charging     die > 60 C or cell estimate > 48 C           -> charger OFF (CNFG_00 CHG bit) + 100 mA
#               back on when die < 52 C and cell estimate < 45 C
#               the charger latches "done" and never restarts on mainline: the guard enables the chip's
#               150 mV auto-restart and also restarts a latched charge itself
#               the charge voltage is held at <= 4.00 V (about 60-65 %), whatever udev or the driver says
#  critical     CPU > 100 C on 2 polls in a row, or die > 85 C -> freeze + clamp + charger off; if still
#               critical after 60 s (or CPU > 105 C) -> poweroff, forced if the orderly one hangs
#  low battery  <= 15 %: freeze s10-llm until >= 25 % (the cable alone may not cover a heavy model); a 5-point
#               drop in 30 min while plugged in is logged as a warning (charging not keeping up)
#               a battery <= 30 % while heat holds the charger off is logged as an early warning
#  hold         touch /run/s10-charge-hold: charger off until the file is removed (or a reboot)
#  blind        any zone missing, or all readings frozen for 2 min while busy -> treated as hot
# Every action is re-asserted, not written once (udev, cable events and new processes can undo them).
# Runs under a systemd watchdog (Type=notify, WatchdogSec): a hung guard is killed and restarted, and
# s10-llm.service refuses to start without it. Kernel throttling (from 75 C) runs independently.
# The s10-llm cgroup is frozen only while the unit is active: frozen during start or stop, its own helpers
# (ExecStartPre, systemctl) hang and the unit wedges (2026-11-20). Outside "active" the unit's processes are left
# running; every other heavy tool is still SIGSTOPped. A low-battery freeze survives a guard restart (/run flag).
# State for benchmarks: /run/s10-guard.state, one line "frozen=0|1 freezes=N ..." rewritten every 10 s and on
# every change. freezes counts freeze events since the guard started: a timed run that saw it change is void.

P=/sys/class/power_supply/max77705-charger
B=/sys/class/power_supply/max170xx_battery
CG=/sys/fs/cgroup/system.slice/s10-llm.service/cgroup.freeze
CGP=/sys/fs/cgroup/system.slice/s10-llm.service/cgroup.procs
STATE=${GUARD_TEST_STATE:-/run/s10-guard.state}; LOWF=${GUARD_TEST_LOWF:-/run/s10-guard.lowbat}
GPU=/sys/class/devfreq/18500000.gpu
PAT='llama-.*|physwatch|memwatch|ptq1bench|microbench|clstream|clbench|test-backend-op|cc1|cc1plus'
CV_MAX=4000000      # charge voltage ceiling (uV)
# Bare-board mode (no cell): kernel cmdline s10.nobatt=1 and no /run/s10-cell-present (written by the guardrail when
# it finds a cell anyway). Then the guard only protects against heat; it leaves the charger alone (the charge-voltage
# setting is the system-rail target without a cell: keep the driver's 4.35 V) and skips the battery logic.
NOBATT=0; grep -qw s10.nobatt=1 /proc/cmdline && [ ! -e /run/s10-cell-present ] && NOBATT=1
# Dummy battery (a buck converter on the battery connector, no cell): the gauge sees a plausible cell voltage, so the
# voltage test above cannot tell; the file says it. Same bare-board behaviour: heat protection only, charger untouched.
[ -e /etc/s10-llm/dummy-battery ] && NOBATT=1
NOBATT=${GUARD_TEST_NOBATT:-$NOBATT}   # test hook
CC_NORM=500000      # charge current when charging is allowed (uA)
CC_MIN=100000       # driver minimum; used together with charger-off as belt and braces
CAP4=1898000; CAP6=1976000   # s10-cpucap.service values (A75 pair, M4 pair)
I2C="1 0x69"        # MAX77705 charger: 0xb4 DETAILS_01, 0xb7 CNFG_00, 0xb8 CNFG_01

log() { echo "$*"; }    # stdout: journald always attributes it to the unit
zpath() { for z in /sys/class/thermal/thermal_zone*; do read t < $z/type; [ "$t" = "$1" ] && echo $z/temp; done; }
# Test hooks (unset in service): fake zone files, faster polls, a harmless poweroff.
[ -n "$GUARD_TEST_ZDIR" ] && zpath() { echo $GUARD_TEST_ZDIR/$1; }
POLL=${GUARD_TEST_POLL:-2}; POWEROFF=${GUARD_TEST_POWEROFF:-poweroff}
CAPF=${GUARD_TEST_CAPF:-/sys/class/power_supply/max170xx_battery/capacity}
LOW=15; LOW_OK=25
Z0=$(zpath cpucl0-thermal); Z1=$(zpath cpucl1-thermal); Z2=$(zpath cpucl2-thermal)
ZG=$(zpath g3d-thermal); ZI=$(zpath isp-thermal)
rz() { v=0; [ -n "$1" ] && read v < $1 2>/dev/null; case "$v" in ''|*[!0-9]*) v=0 ;; esac; }   # -> $v
rf() { v=0; read v < $1 2>/dev/null; case "$v" in ''|*[!0-9-]*) v=0 ;; esac; }

# ---- actions ----
freeze() {
  if [ $1 = 1 ]; then
    pkill -STOP -x "$PAT"
    if [ "$(systemctl show -p ActiveState --value s10-llm.service 2>/dev/null)" = active ]; then
      [ -w $CG ] && echo 1 > $CG
    else                                   # starting or stopping: let the unit finish its transition
      [ -w $CG ] && echo 0 > $CG
      [ -r $CGP ] && for p in $(cat $CGP); do kill -CONT $p 2>/dev/null; done
    fi
  else
    [ -w $CG ] && echo 0 > $CG; pkill -CONT -x "$PAT"
  fi
}
wstate() {
  echo "frozen=$(( paused | lowbat )) freezes=$nfrz paused=$paused lowbat=$lowbat chg=$chg cap=$cap cpu=$cpu die=$isp" \
    > $STATE.tmp 2>/dev/null && mv $STATE.tmp $STATE
}
clamp() {
  if [ $1 = 1 ]; then
    for n in 4 6; do f=/sys/devices/system/cpu/cpufreq/policy$n
      read m < $f/cpuinfo_min_freq; echo $m > $f/scaling_max_freq; done
    if [ -z "$GSAVE" ]; then read gmin < $GPU/min_freq; read gmax < $GPU/max_freq; GSAVE="$gmin $gmax"; fi
    echo 156000000 > $GPU/min_freq; echo 156000000 > $GPU/max_freq
  else
    echo $CAP4 > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq
    echo $CAP6 > /sys/devices/system/cpu/cpufreq/policy6/scaling_max_freq
    if [ -n "$GSAVE" ]; then set -- $GSAVE; echo $2 > $GPU/max_freq; echo $1 > $GPU/min_freq; GSAVE=; fi
  fi
}
reg() { i2cget -f -y $I2C $1 2>/dev/null; }
regw() { i2cset -f -y $I2C $1 $(printf 0x%02x $2) 2>/dev/null; }
charger() {   # 1 = charging allowed, 0 = off; re-asserted, writes only on difference
  [ $NOBATT = 1 ] && return
  set -- $1; [ -e /run/s10-charge-hold ] && set -- 0   # manual hold: touch /run/s10-charge-hold (gone at reboot)
  r=$(reg 0xb7) || r=
  # never touch CNFG_00 while the OTG boost (bits 1+3, USB host power for the Ethernet adapter) is on
  [ -n "$r" ] && [ $(( $r & 0x0a )) -eq $(( 0x0a )) ] && return
  if [ -n "$r" ]; then
    want=$(( ($r & 0xfe) | $1 )); [ $want -ne $(( $r )) ] && regw 0xb7 $want
  fi
  if [ $1 = 1 ]; then cc=$CC_NORM; else cc=$CC_MIN; fi
  rf $P/constant_charge_current; [ $v -ne $cc ] && echo $cc > $P/constant_charge_current
}
housekeeping() {   # once a minute: voltage ceiling, auto-restart, latched charge
  [ $NOBATT = 1 ] && return
  rf $P/constant_charge_voltage
  if [ $v -gt $CV_MAX ]; then echo $CV_MAX > $P/constant_charge_voltage; log "charge voltage was $v, set to $CV_MAX"; fi
  r=$(reg 0xb8) && { want=$(( ($r & 0xcf) | 0x10 )); [ $want -ne $(( $r )) ] && regw 0xb8 $want; }  # CHG_RSTRT 150 mV
  if [ $chg = 1 ]; then
    d=$(reg 0xb4) && rf $B/voltage_now && \
    if [ $(( $d & 0x0f )) -eq 4 ] && [ $v -gt 0 ] && [ $v -lt $(( CV_MAX - 150000 )) ]; then
      regw 0xb7 $(( $(reg 0xb7) & 0xfe )); sleep 1; charger 1; log "charge latched done at vbat=$v: restarted"
    fi
  fi
}
battery() {   # once a minute: low-battery freeze, and a warning when the cable is not keeping up
  [ $NOBATT = 1 ] && return
  rf $CAPF; cap=$v; [ $cap -gt 0 ] || return
  if [ $lowbat = 0 ] && [ $cap -le $LOW ]; then
    [ $paused = 0 ] && nfrz=$((nfrz + 1))
    lowbat=1; touch $LOWF; freeze 1; log "battery ${cap}% <= ${LOW}%: LLM frozen until ${LOW_OK}%"; wstate
  elif [ $lowbat = 1 ] && [ $cap -ge $LOW_OK ]; then
    lowbat=0; rm -f $LOWF; [ $paused = 0 ] && freeze 0; log "battery ${cap}%: LLM released"; wstate
  fi
  if [ $lowwarn = 0 ] && [ $chg = 0 ] && [ $lowbat = 0 ] && [ $cap -le 30 ]; then
    lowwarn=1; log "WARN battery ${cap}% and the charger is held off by heat: the LLM freezes at ${LOW}%"
  elif [ $lowwarn = 1 ] && { [ $chg = 1 ] || [ $cap -gt 35 ]; }; then lowwarn=0; fi
  if [ $((tick % 900)) = 0 ]; then
    rf $P/online
    [ $v = 1 ] && [ $capt -ge 0 ] && [ $cap -le $((capt - 5)) ] && log "WARN battery ${capt}% -> ${cap}% in 30 min on the cable"
    capt=$cap
  fi
}
status() {
  rf $B/voltage_now; vb=$v; rf $B/current_now; ib=$v; rf $B/capacity; cap=$v; rf $P/input_current_limit
  log "status cpu=$cpu die=$isp cell~$((est/1000))C avg=$avg paused=$paused chg=$chg bat=${cap}% ${vb}uV ${ib}uA ilim=$v"
}

# ---- start: undo anything a previous instance may have left behind ----
lowbat=0; lowwarn=0; nfrz=0; cap=0; cpu=0; isp=0; capt=-1; paused=0; chg=1; hot=0; crit=0; blind=0; same=0; last=0; lasti=0; tick=0; GSAVE=
freeze 0; clamp 0
read gmin < $GPU/min_freq; read gmax < $GPU/max_freq
if [ "$gmin $gmax" = "156000000 156000000" ]; then     # left clamped by a dead instance
  if systemctl is-active -q s10-llm.service; then echo 702000000 > $GPU/max_freq; echo 702000000 > $GPU/min_freq
  else echo 433000000 > $GPU/max_freq; fi
fi
rz $ZI; est=$v; [ $est -gt 0 ] || est=50000          # hot reboot: the estimate starts hot, charging waits
rz $Z0; s1=$v; [ $s1 -gt 0 ] || s1=50000; s2=$s1; s3=$s1; s4=$s1; s5=$s1
[ $est -gt 48000 ] && chg=0
charger $chg; housekeeping
# a low-battery freeze outlives a guard restart (otherwise a restart between 15 and 25 % would release it)
[ $NOBATT = 0 ] && [ -e $LOWF ] && { lowbat=1; nfrz=1; freeze 1; log "low-battery freeze carried over from before the restart"; }
battery; wstate
log "started v2 (die=$est charging=$chg cv<=$CV_MAX cc=$CC_NORM nobatt=$NOBATT)"
systemd-notify --ready

while true; do
  tick=$((tick + 1))
  rz $Z0; c0=$v; rz $Z1; c1=$v; rz $Z2; c2=$v; rz $ZG; g=$v; rz $ZI; i=$v
  new=$c0; for x in $c1 $c2 $g; do [ $x -gt $new ] && new=$x; done
  if [ $c0 -eq 0 ] || [ $c1 -eq 0 ] || [ $c2 -eq 0 ] || [ $g -eq 0 ] || [ $i -eq 0 ]
  then blind=$((blind + 1)); else blind=0; fi
  # readings that do not move for 2 min while busy count as missing (stuck sensor firmware)
  if [ $new -eq $last ] && [ $i -eq $lasti ]; then same=$((same + 1)); else same=0; fi; last=$new; lasti=$i
  if [ $same -ge 60 ]; then read la _ < /proc/loadavg; [ ${la%%.*} -ge 2 ] && blind=3; fi
  [ $blind -eq 3 ] && log "BLIND: sensor missing or frozen, treating as hot"
  cpu=$new; isp=$i
  [ $blind -ge 3 ] && { cpu=89000; isp=76000; }
  s5=$s4; s4=$s3; s3=$s2; s2=$s1; s1=$cpu; avg=$(( (s1 + s2 + s3 + s4 + s5) / 5 ))
  est=$(( est + (isp - est) / 450 ))                   # ~15 min time constant at 2 s polls

  # critical: stop all heat first, power off only if that does not work
  if [ $cpu -gt 100000 ]; then hot=$((hot + 1)); else hot=0; fi
  if [ $hot -ge 2 ] || [ $isp -gt 85000 ]; then
    [ $crit = 0 ] && [ $paused = 0 ] && [ $lowbat = 0 ] && nfrz=$((nfrz + 1))
    [ $crit = 0 ] && log "CRITICAL cpu=$cpu (x$hot) die=$isp: freeze, clamp, charger off"
    crit=$((crit + 1)); paused=1; chg=0; freeze 1; clamp 1; charger 0
    if [ $crit -ge 30 ] || [ $cpu -gt 105000 ]; then
      log "CRITICAL for $((crit * 2)) s, cpu=$cpu die=$isp -> poweroff"; sync
      if [ "$POWEROFF" = poweroff ]; then
        systemctl poweroff --no-block; sleep 45
        log "orderly poweroff hung -> forced"; systemctl poweroff -ff; sleep 10; echo o > /proc/sysrq-trigger
      else $POWEROFF; exit 0; fi
    fi
  else
    crit=0
  fi

  if [ $paused = 0 ] && { [ $avg -gt 88000 ] || [ $isp -gt 75000 ]; }; then
    [ $lowbat = 0 ] && nfrz=$((nfrz + 1))
    paused=1; freeze 1; clamp 1; log "cpu avg=$avg die=$isp: paused heavy jobs, clocks clamped"; wstate
  elif [ $paused = 1 ] && [ $crit = 0 ] && [ $avg -lt 75000 ] && [ $isp -lt 70000 ]; then
    paused=0; [ $lowbat = 0 ] && freeze 0; clamp 0; log "cpu avg=$avg die=$isp: resumed heavy jobs"; wstate
  fi

  if [ $chg = 1 ] && { [ $isp -gt 60000 ] || [ $est -gt 48000 ]; }; then
    chg=0; charger 0; log "die=$isp cell~$((est/1000))C: charger off"
  elif [ $chg = 0 ] && [ $crit = 0 ] && [ $isp -lt 52000 ] && [ $est -lt 45000 ]; then
    chg=1; charger 1; log "die=$isp cell~$((est/1000))C: charger on"
  fi

  if [ $((tick % 5)) = 0 ]; then                      # every 10 s: re-assert, feed the watchdog
    [ $paused = 1 ] && { freeze 1; clamp 1; }
    [ $lowbat = 1 ] && freeze 1
    charger $chg; wstate
    systemd-notify WATCHDOG=1
  fi
  [ $((tick % 30)) = 0 ] && { housekeeping; battery; }
  [ $((tick % 300)) = 0 ] && status
  sleep $POLL
done
