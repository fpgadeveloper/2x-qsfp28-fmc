# Copyright (C) 2025-2026, Opsero Electronic Design Inc.  All rights reserved.
#
# SPDX-License-Identifier: MIT

# 2x QSFP28 FMC reference-design rootfs packages (design test/utility tools
# layered on the amd-edf base).
IMAGE_INSTALL:append = " \
    ethtool \
    iperf3 \
    iproute2-nstat \
    mtd-utils \
    nfs-utils \
    pciutils \
    qsfp-loopback-test \
"

# phytool (MDIO/PHY register access) + can-utils: explicit, as in the PetaLinux rootfs_config and the vck190 BSP.
IMAGE_INSTALL:append = " \
    phytool \
    can-utils \
"
