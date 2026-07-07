# Copyright (C) 2025-2026, Opsero Electronic Design Inc.  All rights reserved.
#
# SPDX-License-Identifier: MIT

# Board-level Linux DT fixes the SDT flow cannot derive from the XSA
# (PS-side PHY wiring: DP83867 RGMII delays, fixed MAC). Injected via
# EXTRA_DT_INCLUDE_FILES, scoped to the Linux (APU) domain DTS, same
# mechanism as the port-config overlay.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " file://board-user.dtsi"
EXTRA_DT_INCLUDE_FILES:append = "${@' board-user.dtsi' if 'linux' in os.path.basename(d.getVar('CONFIG_DTFILE') or '') else ''}"
