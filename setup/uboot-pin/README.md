# U-Boot pin hook: try a U-Boot change for exactly one boot (experimental)

A changed U-Boot (or its device tree) that hangs early cannot be undone from the running system; recovering it needs
download mode and a PC. This initramfs hook runs at ~2.5 s, before udev: it compares the boot partition with a pinned
known-good image and writes the image back if they differ. A trial U-Boot then runs for one boot only, and a hang
costs a forced restart (Power + Volume Down), not a reflash.

```sh
sudo install -D -m 644 uboot-wifi-boot.img /usr/share/s10/uboot-pinned.img   # the image you installed (release tarball)
echo /usr/share/s10/uboot-pinned.img:/s10/uboot-pinned.img | sudo tee /etc/mkinitfs/files/s10-uboot-pin.files
sudo install -m 755 03-s10-uboot-pin.sh /etc/mkinitfs/hooks/ && sudo mkinitfs
```
The hook only writes after finding a partition named `boot` with the expected size (112640 sectors) and an
`ANDROID!` header. To change U-Boot for good, replace the pinned image and run `mkinitfs` first, or the hook will
undo the change at the next boot.
