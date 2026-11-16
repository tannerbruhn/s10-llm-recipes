#!/bin/sh
# Install the safety parts for an always-on, always-plugged-in Galaxy S10 (run as root, from this directory):
# thermal guard + its failure handler, big-core and GPU clock caps, charge limit. Install these BEFORE s10-llm.service.
set -e
cd "$(dirname "$0")"
command -v i2cget >/dev/null || apk add i2c-tools
install -m 755 s10-thermal-guard.sh /usr/local/bin/s10-thermal-guard
install -m 644 s10-thermal-guard.service s10-guard-failed.service s10-cpucap.service s10-gpu-cap.service /etc/systemd/system/
install -m 644 90-s10-charge-limit.rules /etc/udev/rules.d/
udevadm control --reload
udevadm trigger -c add /sys/class/power_supply/max77705-charger
systemctl daemon-reload
systemctl enable --now s10-gpu-cap.service s10-cpucap.service s10-thermal-guard.service
systemctl is-active s10-thermal-guard.service
journalctl -u s10-thermal-guard -n 3 --no-pager -o cat
