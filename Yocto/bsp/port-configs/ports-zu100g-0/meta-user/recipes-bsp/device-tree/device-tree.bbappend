# Copyright (C) 2025-2026, Opsero Electronic Design Inc.  All rights reserved.
#
# SPDX-License-Identifier: MIT

# Per-target port-config overlay. Supplies the per-port wiring (MAC driver
# compatible, DMA hookup, interrupts, MAC address, link rate) and the FMC
# Si5328 clock-generator node that the XSA / SDT does not describe.
#
# Injected via EXTRA_DT_INCLUDE_FILES; scoped to the Linux (APU) domain DTS,
# same as the board system-user.dtsi.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

EXTRA_DT_INCLUDE_FILES:append = "${@' port-config.dtsi' if 'linux' in os.path.basename(d.getVar('CONFIG_DTFILE') or '') else ''}"
