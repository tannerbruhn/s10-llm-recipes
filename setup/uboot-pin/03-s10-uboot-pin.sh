#!/bin/sh
# S10 initramfs hook: keep the known-good U-Boot on the boot partition. If the partition does not start with the
# image embedded here (/s10/uboot-pinned.img), write it back. A trial U-Boot is therefore used for exactly one boot,
# and the restore happens here, before anything in the trial boot can hang. To change U-Boot for good, replace
# /usr/share/s10/uboot-pinned.img and rerun mkinitfs.
IMG=/s10/uboot-pinned.img
log() { echo "s10-uboot-pin: $*" > /dev/kmsg 2>/dev/null; }
[ -f $IMG ] || { log "no pinned image"; exit 0; }
dev=""
for u in /sys/class/block/*/uevent; do
  grep -qx "PARTNAME=boot" "$u" 2>/dev/null || continue
  n=$(sed -n 's/^DEVNAME=//p' "$u"); d=/dev/$n
  [ -b "$d" ] || { log "$d not a block device"; continue; }
  sz=$(cat /sys/class/block/$n/size 2>/dev/null)
  [ "$sz" = 112640 ] || { log "$d size $sz sectors, expected 112640"; continue; }
  [ "$(dd if=$d bs=8 count=1 2>/dev/null)" = "ANDROID!" ] || { log "$d has no boot image header"; continue; }
  dev=$d
done
[ -n "$dev" ] || { log "boot partition not identified, nothing done"; exit 0; }
s=$(stat -c %s $IMG)
if cmp -s -n $s $IMG $dev; then log "$dev matches the pinned U-Boot"; exit 0; fi
log "$dev differs from the pinned U-Boot: restoring"
dd if=$IMG of=$dev bs=4096 conv=fsync 2>/dev/null; sync
if cmp -s -n $s $IMG $dev; then log "restored $dev"; else log "RESTORE FAILED on $dev"; fi
true
