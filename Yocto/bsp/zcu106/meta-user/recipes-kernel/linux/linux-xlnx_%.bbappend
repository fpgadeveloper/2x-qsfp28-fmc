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

# Fix from first hardware bring-up (zcu106_hpc0): the HSE mactype must be
# exempt from the probe-time pcs-handle/phy-handle requirement, like MRMAC.
SRC_URI:append = " file://0003-net-axienet-hse-exempt-pcs-handle-requirement.patch"

# Fix from zcu106_hpc0 bring-up: the 40G/50G subsystem (l_ethernet) has
# different TICK/STAT offsets than the CMAC and SLVERR-on-undefined-offset
# enabled at reset - the CMAC offsets caused an SError panic at first ifup.
SRC_URI:append = " file://0004-net-axienet-hse-fix-l_ethernet-register-map.patch"

# Fix from zcu106_hpc0 bring-up: the RX status register is latched-low +
# clear-on-read, so the link poll must read it twice (flush, then sample) or
# its own GT reset pulses keep the link down forever.
SRC_URI:append = " file://0005-net-axienet-hse-fix-latched-low-link-poll.patch"

# The HSE MACs (CMAC, l_ethernet) have no RX backpressure: the MCDMA S2MM drops
# whole frames whenever the RX descriptor ring is empty (measured on the MRMAC
# sibling design: TCP retransmits /200 with 1024 instead of 128 RX
# descriptors). Default HSE (and MRMAC) ports to 1024 RX descriptors
# ("ethtool -g"), and show the MCDMA S2MM drop count as "rx_dma_pkt_drop" in
# "ethtool -S". Same patches as the other BSP (Yocto/PetaLinux).
SRC_URI:append = " \
    file://0006-net-axienet-default-to-1024-RX-descriptors-on-MRMAC-and-HSE.patch \
    file://0007-net-axienet-report-the-MCDMA-S2MM-packet-drop-count-.patch \
"

# HSE link monitor (40G l_ethernet and 100G CMAC): keep MODE_REG
# tick_reg_mode_sel so the l_ethernet statistics latch; HSE link monitor with bad-code / per-lane BIP detection,
# debounce (3 samples), RX-only GT reset before reset-all, raw status logging,
# and an interface restart when good MAC frames stop reaching the stack.
SRC_URI:append = " file://0008-net-axienet-hse-link-monitor-bad-code-recovery.patch"

# HSE link monitor, visible outages: rate-limited info on short RX outages + ethtool -S hse_* counters;
# no GT reset-all while there is no signal (no block lock on any lane).
SRC_URI:append = " file://0009-net-axienet-hse-monitor-visible-outages-no-reset-all-without-signal.patch"

# HSE link monitor, interval sampling: interval-latched RX status/block lock (healed outages counted),
# no reset-all unless all lanes stayed locked+aligned, 64-bit MAC RX counters,
# rx_dma_pkt_drop cumulative across down/up.
SRC_URI:append = " file://0010-net-axienet-hse-monitor-interval-latched-status-no-signal-rule-counters.patch"
