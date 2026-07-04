# Copyright (C) 2025-2026, Opsero Electronic Design Inc.  All rights reserved.
#
# SPDX-License-Identifier: MIT

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append = " file://bsp.cfg"
KERNEL_FEATURES:append = " bsp.cfg"

# 2x QSFP28 FMC: enable the Si5328 CKOUT2 output (GBTCLK1, QSFP port 1) in
# the si5324 clk driver - the stock driver disables CKOUT2, leaving port 1
# with no GT reference clock.
SRC_URI:append = " file://0001-clk-si5324-enable-ckout2-for-2x-qsfp28-fmc.patch"

# 2x QSFP28 FMC on ZynqMP: the MAC is the 100G CMAC (RFSoC/GTY targets) or
# the 40G/50G Ethernet subsystem (GTH targets) - neither is supported by the
# stock xilinx_axienet driver. Add an HSE mactype for both, with a 1 Hz
# carrier monitor that re-attempts GT/RX alignment while the link is down
# (the GT refclk only starts once Linux programs the FMC's Si5328).
SRC_URI:append = " file://0002-net-axienet-add-hse-cmac-l-ethernet-support.patch"
