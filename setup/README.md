# Phone setup

- **postmarketOS** on the Galaxy S10 (SM-G973F, `samsung-beyond1lte`).
- **Kernel:** `tannerbruhn/exynos-9820-mainline-linux`, branch `s10-wifi`: Wi-Fi (BCM4375 over PCIe), the
  MAX77705 charger, and Panfrost support for the non-coherent Exynos 9820 Mali-G76.
- **U-Boot:** `tannerbruhn/u-boot`, branch `s10-wifi`: the S10 device tree, with the Mali-G76 GPU node (adapted
  from Gregor Sprint's work in omnipha/linux-samsung-s10-exynos9820) and the GPU rates up to the stock 702 MHz.
- **CPU:** 2 Samsung M4 (cpus 6-7), 2 Cortex-A75 (cpus 4-5), 4 Cortex-A55 (cpus 0-3); 8 GB LPDDR4X.
- **Safety for a phone that runs 24/7 on the charger:** a thermal guard (pause heavy jobs when hot, cut the charge
  current when the board is warm, clean power-off at the critical limits). See the kernel fork's S10-WIFI.md for known issues.

The GPU commits on both forks are local for now and will be pushed with these recipes.
