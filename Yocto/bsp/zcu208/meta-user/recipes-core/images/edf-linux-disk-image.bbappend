# Copyright (C) 2025-2026, Opsero Electronic Design Inc.  All rights reserved.
#
# SPDX-License-Identifier: MIT

# 2x QSFP28 FMC reference-design rootfs packages (design test/utility tools
# layered on the amd-edf base).
IMAGE_INSTALL:append = " \
    ethtool \
    iperf3 \
    mtd-utils \
    nfs-utils \
    pciutils \
    qsfp-loopback-test \
"
