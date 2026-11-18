# Phone setup

The kernel and U-Boot forks are general Galaxy S10 support, not LLM-specific: they make the phone work as a
postmarketOS device (Wi-Fi, charging, GPU). The LLM recipes build on them.

- **postmarketOS** on the Galaxy S10 (SM-G973F, `samsung-beyond1lte`).
- **Kernel:** [tannerbruhn/exynos-9820-mainline-linux](https://github.com/tannerbruhn/exynos-9820-mainline-linux)
  (`main`): Wi-Fi (BCM4375 over PCIe), the MAX77705 charger, Panfrost support for the non-coherent Exynos 9820
  Mali-G76, and the hardware watchdog. Install notes and known issues: S10.md there.
- **Install:** the kernel fork's latest release (v4) has a prebuilt kernel, U-Boot image and an installer that boots
  the new kernel once as a trial before making it the default.
- **U-Boot:** [tannerbruhn/u-boot](https://github.com/tannerbruhn/u-boot) (`main`): the S10 device tree, with the
  Mali-G76 GPU node (adapted from Gregor Sprint's work in omnipha/linux-samsung-s10-exynos9820) and the GPU rates up
  to the stock 702 MHz, and the watchdog node.
- **CPU:** 2 Samsung M4 (cpus 6-7), 2 Cortex-A75 (cpus 4-5), 4 Cortex-A55 (cpus 0-3); 8 GB LPDDR4X.
- **Safety for a phone that runs 24/7 on the charger:** [safety/](safety/) has the thermal guard (freeze heavy jobs
  and clamp clocks when hot, charging off while the die or the estimated battery temperature is warm, poweroff at
  the critical limits), the clock caps and the charge limit, with an install script. Install them before the LLM
  service. The hardware watchdog resets the phone after 60 s if the system hangs.
- [cpumem/](cpumem/) exposes 184 MB of the unused modem carve-out as CPU-only memory (in use on two phones).
- **New, one board:** [bare-board/](bare-board/) runs the phone without a battery (9 V USB-PD and a fan for the 27B).
- **Experimental:** [uboot-pin/](uboot-pin/) makes a U-Boot change undo itself at the next boot, so a bad trial costs
  a restart, not a reflash.
