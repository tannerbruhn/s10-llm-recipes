# /dev/s10cpumem: 184 MB of CPU-only memory from the modem carve-out (experimental)

The S10's device tree reserves 185 MB at 0xf0000000 for the cellular modem (`modem_if`). Mainline never runs the
modem, but this range cannot become normal RAM: giving it to Linux makes the boot hang (device DMA there fails; the
bootloader also writes the modem's table of contents into its first megabyte). The CPU can use it: this small module
exposes 0xf0100000-0xfb8fffff as `/dev/s10cpumem`, mapped cacheable into one process at a time. Reads run at about
8 GB/s (normal RAM 22-24 GB/s), enough for data the CPU streams more slowly than that, such as the int2 copies of
the 27B (`GGML_S10_INT2_POOL=/dev/s10cpumem GGML_S10_INT2_POOL_MB=184` in llama.cpp-s10).

Tested on one phone: a pattern over all 184 MB verified with 0 bad words, also after a reboot.

## Build and install
Build against the kernel tree the phone runs (`Kbuild` here; `make LLVM=1 M=$PWD modules` in the kernel tree with
the same compiler), then on the phone:
```sh
sudo install -D -m 644 s10cpumem.ko /lib/modules/$(uname -r)/extra/s10cpumem.ko && sudo depmod -a
echo s10cpumem | sudo tee /etc/modules-load.d/s10cpumem.conf
echo 'KERNEL=="s10cpumem", OWNER="user", GROUP="user", MODE="0600"' | sudo tee /etc/udev/rules.d/91-s10cpumem.rules
sudo modprobe s10cpumem
```
`cpumemuser.c` checks it (pattern + bandwidth): `gcc -O2 -pthread cpumemuser.c -o cpumemuser && ./cpumemuser`.
A second process trying to map it gets EBUSY.
