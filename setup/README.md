# Phone setup

The kernel and U-Boot forks are general Galaxy S10 support, not LLM-specific: they make the phone work as a
postmarketOS device (Wi-Fi, charging, GPU). The LLM recipes build on them.

- **postmarketOS** on the Galaxy S10 (SM-G973F, `samsung-beyond1lte`).
- **Kernel:** [tannerbruhn/exynos-9820-mainline-linux](https://github.com/tannerbruhn/exynos-9820-mainline-linux)
  (`main`): Wi-Fi (BCM4375 over PCIe), the MAX77705 charger, and Panfrost support for the non-coherent Exynos 9820
  Mali-G76. Install notes and known issues: S10-WIFI.md there.
- **U-Boot:** [tannerbruhn/u-boot](https://github.com/tannerbruhn/u-boot) (`main`): the S10 device tree, with the
  Mali-G76 GPU node (adapted from Gregor Sprint's work in omnipha/linux-samsung-s10-exynos9820) and the GPU rates up
  to the stock 702 MHz.
- **CPU:** 2 Samsung M4 (cpus 6-7), 2 Cortex-A75 (cpus 4-5), 4 Cortex-A55 (cpus 0-3); 8 GB LPDDR4X.
- **Safety for a phone that runs 24/7 on the charger:** a thermal guard (pause heavy jobs when hot, cut the charge
  current when the board is warm, clean power-off at the critical limits).
