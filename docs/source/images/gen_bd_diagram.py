#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Opsero Electronic Design Inc.
"""
Generate the block-design (Vivado view) diagrams for the Opsero 2x QSFP28 FMC
(OP120) 100G/40G Ethernet reference design docs.

Where the system diagrams of gen_block_diagram.py are the conceptual view, these
show the block design `qsfp` as the Vivado scripts build it: every box is a real
cell (or hierarchy pin / external port) and every number a real property of the
built design. One QSFP28 port hierarchy (`qsfp_port0`) is drawn in full, together
with the top-level cells it connects to:

  bd-zynqmp-qsfp-port.png   Vivado/src/bd/bd_zynqmp.tcl (and bd_mb.tcl, whose
                            qsfp_port hierarchy is identical): CMAC (100G) or
                            40G/50G Ethernet Subsystem (40G) port with the RX
                            frame FIFO, RX flush guard, TX frame gate and the
                            reset structure of the MAC clock domain.
  bd-versal-qsfp-port.png   Vivado/src/bd/bd_versal.tcl: MRMAC port with the
                            per-lane GT user clocking, the MRMAC client
                            adapters and the GT-control GPIO.

It reuses the palette and drawing helpers of gen_block_diagram.py so that all
diagrams look the same. The output PNGs are written next to this script.

Usage (from anywhere):
    python3 docs/source/images/gen_bd_diagram.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_block_diagram as g                      # noqa: E402  (palette + helpers)
from gen_block_diagram import (box, titled_box, harrow, route, region,  # noqa: E402
                               refclk_arrow, note, new_fig, save, plt)

C_RST = "#B0703C"          # reset nets (brown)
C_CLKN = "#C8823C"         # clock nets
C_CTRL_LINE = "#8C8C8C"    # AXI-Lite
C_HIER_FILL = "#FAFAFD"    # hierarchy background
TXT = g.TXT


def cell(ax, x, y, w, h, name, body, fc=g.C_MAC_FILL, ec=g.C_MAC_EDGE,
         title_fs=7.8, body_fs=6.3, title_dy=2.2, ls="-", txtcolor=None):
    titled_box(ax, x, y, w, h, fc, ec, name, body, title_fs=title_fs,
               body_fs=body_fs, title_dy=title_dy, ls=ls, txtcolor=txtcolor)


def net(ax, pts, color, lw=1.2, ls="-"):
    route(ax, pts, color, lw=lw, ls=ls)


def legend(ax, x0, y1, opt=True):
    note(ax, x0 + 0.5, y1 - 0.8, "Legend", fs=8.0, ha="left", weight="bold",
         color=TXT)
    sw = [(g.C_PS_FILL, g.C_PS_EDGE, "PS / processor"),
          (g.C_DMA_FILL, g.C_DMA_EDGE, "AXI MCDMA"),
          (g.C_MAC_FILL, g.C_MAC_EDGE, "AXIS infrastructure"),
          (g.C_FIFO_FILL, g.C_FIFO_EDGE, "Opsero RTL module"),
          (g.C_GT_FILL, g.C_GT_EDGE, "MAC / GT / clock buffer"),
          (g.C_CTRL_FILL, g.C_CTRL_EDGE, "AXI-Lite peripheral"),
          (g.C_CLK_FILL, g.C_CLK_EDGE, "reset / clock")]
    for i, (fc, ec, lab) in enumerate(sw):
        yy = y1 - 4.0 - i * 2.9
        box(ax, x0 + 0.5, yy - 0.9, 2.8, 1.8, fc, ec, "", lw=1.0)
        note(ax, x0 + 4.0, yy, lab, fs=6.3, ha="left", color=TXT)
    lines = [(g.C_AXARR_EDGE, "AXI / AXIS @ 100 MHz"),
             (g.C_DPARR_EDGE, "AXIS @ MAC client clock"),
             (C_RST, "reset nets"), (C_CLKN, "clock nets"),
             (g.C_DROP, "drop counters")]
    if opt:
        lines.append((g.C_OPT_EDGE, "40G-only cell (dashed)"))
    for i, (c, lab) in enumerate(lines):
        yy = y1 - 4.0 - (len(sw) + i) * 2.9
        ax.add_line(plt.Line2D([x0 + 0.5, x0 + 3.3], [yy, yy], color=c, lw=2.4,
                               zorder=3, ls="--" if "dashed" in lab else "-"))
        note(ax, x0 + 4.0, yy, lab, fs=6.3, ha="left", color=TXT)


# ---------------------------------------------------------------------------
def fig_zynqmp():
    fig, ax = new_fig(200, 128)
    ax.text(100, 126.0,
            "Block design  qsfp  —  qsfp_port0 hierarchy   "
            "(Vivado/src/bd/bd_zynqmp.tcl; bd_mb.tcl builds the same hierarchy)",
            ha="center", va="bottom", fontsize=12, weight="bold", color=TXT)
    # hierarchy
    hx0, hx1, hy0, hy1 = 22.0, 166.0, 36.0, 123.0
    box(ax, hx0, hy0, hx1 - hx0, hy1 - hy0, C_HIER_FILL, g.C_MAC_EDGE, "",
        lw=1.3, ls=(0, (4, 2)), z=1.0)
    note(ax, hx0 + 1.0, hy1 - 1.8, "qsfp_port0  (hierarchy, one per QSFP28 port)",
         fs=9.0, ha="left", weight="bold", color=TXT)
    region(ax, hx0 + 1.0, hy0 + 1.0, 83.0, hy1 - 4.0, "sys_clk 100 MHz (pl_clk0)",
           "none", g.C_FAB_EDGE, "#606060", lab_fs=6.8)
    region(ax, 84.0, hy0 + 1.0, hx1 - 1.0, hy1 - 4.0,
           "mac_rx_clk = mac_tx_clk:  cmac/gt_txusrclk2  |  leth/tx_clk_out_0 "
           "(also drives leth/rx_core_clk_0)",
           g.C_DOM_MAC, g.C_DOM_MAC_EDGE, g.C_DOM_TXT, lab_fs=6.8)

    rx_y0, rx_y1 = 96.0, 112.0
    tx_y0, tx_y1 = 41.0, 57.0
    rx_yc, tx_yc = (rx_y0 + rx_y1) / 2, (tx_y0 + tx_y1) / 2
    # MCDMA + smc_hp + smc_lite
    cell(ax, 34.0, tx_y0, 13.0, rx_y1 - tx_y0, "axi_mcdma",
         "\n512-bit MM / AXIS\n40-bit address\n1 MM2S + 1 S2MM\nDRE on\n\n"
         "s2mm_prmry_\nreset_out_n\n→ rx_guard\n\nmm2s / s2mm\nch1_introut\n→ irq",
         fc=g.C_DMA_FILL, ec=g.C_DMA_EDGE, txtcolor="#FFFFFF", title_dy=2.6)
    cell(ax, 24.0, 82.0, 8.0, 30.0, "axi_\nsmc_hp", "\n\n\nSG\nMM2S\nS2MM\n→ M00\n\n"
         "m_axi_hp\n→ HPp\n_FPD", fc=g.C_CTRL_FILL, ec=g.C_CTRL_EDGE,
         title_dy=3.2, body_fs=6.0)
    harrow(ax, 32.0, 34.0, 97.0, "", g.C_AXARR_FILL, g.C_AXARR_EDGE, double=False,
           bh=1.0, hh=1.9, hl=0.9)
    cell(ax, 24.0, 41.0, 8.0, 30.0, "axi_\nsmc_lite", "\n\n\nS_AXI_\nLITE\n\nM00 →\nMAC\n"
         "s_axi\nM01 →\nmcdma", fc=g.C_CTRL_FILL, ec=g.C_CTRL_EDGE, title_dy=3.2,
         body_fs=6.0)

    # RX row (right -> left)
    cell(ax, 50.0, rx_y0, 14.0, rx_y1 - rx_y0, "rx_guard",
         "axis_rx_flush_guard\nDATA_W 512\nflush_req → rst_rx\n← flush_ack",
         fc=g.C_FIFO_FILL, ec=g.C_FIFO_EDGE)
    cell(ax, 67.0, rx_y0, 15.0, rx_y1 - rx_y0, "rx_cdc_fifo",
         "axis_data_fifo\n512 deep, async\ns: mac_rx_clk\nm: sys_clk")
    cell(ax, 87.0, rx_y0, 13.0, rx_y1 - rx_y0, "rx_dwidth",
         "32 → 64 B\nrst: rst_rx", ec=g.C_OPT_EDGE, ls=(0, (4, 2)))
    cell(ax, 103.0, rx_y0, 24.0, rx_y1 - rx_y0, "rx_frame_fifo",
         "axis_rx_frame_fifo, DEPTH 2048\nDATA_W 512 (CMAC) / 256 (40G)\n"
         "DROP_ERR_FRAMES 1, tuser = bad\nrx_abort ← user_rx_reset\n"
         "rx_hold ← user_tx_reset",
         fc=g.C_FIFO_FILL, ec=g.C_FIFO_EDGE, body_fs=6.0)
    for xa, xb in ((50.0, 47.0), (67.0, 64.0), (87.0, 82.0), (103.0, 100.0)):
        harrow(ax, xa, xb, rx_yc, "", g.C_DPARR_FILL if xa > 84 else g.C_AXARR_FILL,
               g.C_DPARR_EDGE if xa > 84 else g.C_AXARR_EDGE, double=False,
               bh=1.0, hh=1.9, hl=1.0)
    # TX row (left -> right)
    cell(ax, 67.0, tx_y0, 15.0, tx_y1 - tx_y0, "tx_cdc_fifo",
         "axis_data_fifo\n512 deep, async\ns: sys_clk\nm: mac_tx_clk")
    cell(ax, 87.0, tx_y0, 13.0, tx_y1 - tx_y0, "tx_dwidth", "64 → 32 B\nrst: rst_mac",
         ec=g.C_OPT_EDGE, ls=(0, (4, 2)))
    cell(ax, 103.0, tx_y0, 24.0, tx_y1 - tx_y0, "tx_gate",
         "axis_tx_frame_gate, DATA_W 256\nafter reset: drop beats up to\n"
         "and incl. the first TLAST\nrst: rst_mac",
         fc=g.C_FIFO_FILL, ec=g.C_OPT_EDGE, ls=(0, (4, 2)), body_fs=6.0)
    for xa, xb in ((47.0, 67.0), (82.0, 87.0), (100.0, 103.0), (127.0, 132.0)):
        harrow(ax, xa, xb, tx_yc, "", g.C_DPARR_FILL if xa > 80 else g.C_AXARR_FILL,
               g.C_DPARR_EDGE if xa > 80 else g.C_AXARR_EDGE, double=False,
               bh=1.0, hh=1.9, hl=1.0)
    harrow(ax, 132.0, 127.0, rx_yc, "", g.C_DPARR_FILL, g.C_DPARR_EDGE, double=False,
           bh=1.0, hh=1.9, hl=1.0)

    # MAC
    cell(ax, 132.0, tx_y0, 22.0, rx_y1 - tx_y0, "cmac  |  leth",
         "\ncmac_usplus (100G)\nCAUI-4, 4x25, no RS-FEC\nCMAC_CORE_SELECT /\n"
         "GT_GROUP_SELECT per board\nAXIS 512-bit + s_axi\n\n"
         "l_ethernet (40G)\nLINE_RATE 40, BASE-R\n256-bit Regular AXIS\nstatistics counters\n"
         "GT_GROUP_SELECT per board\ntx/rxoutclksel = PROGDIV\n\n"
         "init / drp / s_axi clk\n= sys_clk\nsys_reset ← periph_rst\n"
         "core / gtwiz resets\ntied low (software uses\nthe GT_RESET register)",
         fc=g.C_GT_FILL, ec=g.C_GT_EDGE, title_fs=8.6, body_fs=6.1, title_dy=2.4)
    # reset band
    by0, by1 = 62.0, 90.0
    cell(ax, 103.0, by0 + 15.0, 24.0, 12.0, "rst_rx  (proc_sys_reset)",
         "slowest_sync_clk = mac_rx_clk\next ← rx_guard/flush_req\n"
         "reset → rx_guard/flush_ack\naresetn → rx chain",
         fc=g.C_CLK_FILL, ec=g.C_CLK_EDGE, body_fs=5.9, title_fs=7.0)
    cell(ax, 103.0, by0, 24.0, 13.0, "rst_mac  (40G)",
         "proc_sys_reset, mac_tx_clk\next ← user_tx_reset_0\naux ← rst_tx_fifo reset\n"
         "→ tx_dwidth, tx_gate\n(CMAC: logic_tx_rstn)",
         fc=g.C_CLK_FILL, ec=g.C_OPT_EDGE, ls=(0, (4, 2)), body_fs=5.9, title_fs=7.0)
    cell(ax, 50.0, by0, 30.0, 13.0, "rst_tx_fifo  (40G)",
         "proc_sys_reset on sys_clk\next ← user_tx_reset_0, aux ← periph_rst\n"
         "→ tx_cdc_fifo s_axis_aresetn\n(CMAC: periph_rstn)",
         fc=g.C_CLK_FILL, ec=g.C_OPT_EDGE, ls=(0, (4, 2)), body_fs=5.9, title_fs=7.0)
    net(ax, [(57.0, rx_y0), (57.0, 91.5), (100.5, 91.5), (100.5, by0 + 21.0),
             (103.0, by0 + 21.0)], C_RST)
    net(ax, [(132.0, 84.0), (128.5, 84.0), (128.5, rx_y0)], C_RST)
    note(ax, 129.6, 86.5, "user_rx/\ntx_reset", fs=5.5, color=C_RST, ha="left")
    net(ax, [(80.0, by0 + 6.0), (103.0, by0 + 6.0)], C_RST)
    net(ax, [(74.5, by0), (74.5, tx_y1)], C_RST)
    # LEDs / drop status
    cell(ax, 50.0, by0 + 15.0, 30.0, 12.0, "logic_red_led",
         "grn_led ← stat_rx_aligned (CMAC)\n/ stat_rx_status (40G)\n"
         "red_led = NOT of the same", fc=g.C_CTRL_FILL, ec=g.C_CTRL_EDGE,
         body_fs=5.9, title_fs=7.0)
    net(ax, [(115.0, rx_y0), (115.0, 93.0), (hx0 + 0.5, 93.0), (hx0 - 2.0, 93.0)],
        g.C_DROP, lw=1.4)
    note(ax, 70.0, 94.6, "rx_drop_status[29:0]  →  hierarchy pin  →  "
         "qsfp_in_cat0/In2  →  axi_gpio_qsfp0 GPIO2[31:2]", fs=6.2,
         color=g.C_DROP, weight="bold")

    # hierarchy pins / external
    note(ax, hx1 + 1.0, 100.0, "qsfp0_gt\n(gt_rtl)\n→ FMC\nDP0-3", fs=6.5,
         ha="left", color=TXT)
    harrow(ax, 154.0, 166.5, 97.0, "", g.C_LINKARR_FILL, g.C_LINKARR_EDGE,
           bh=1.4, hh=2.5, hl=1.0)
    refclk_arrow(ax, (176.0, 70.0), (154.0, 70.0), "gt_ref_clk_0\n(GBTCLK0)",
                 (176.0, 75.0), fs=6.4, lw=1.6)

    # top-level cells (bottom strip)
    sy0, sy1 = 3.0, 31.0
    cell(ax, 2.0, sy0, 18.0, 120.0 - sy0, "zynq_ultra_\nps_e_0",
         "\n\n\nboard preset\n\nM_AXI_HPM0_LPD\n→ axi_smc\n\nS_AXI_HP0_FPD\n← port 0\n"
         "S_AXI_HP1_FPD\n← port 1\n\npl_clk0 100 MHz\n→ sys_clk\npl_resetn0\n→ rst_ps_100m\n\n"
         "pl_ps_irq0[6:0]\n← intr_concat:\n0/1 port0 mm2s/s2mm\n2 axi_iic_qsfp0\n"
         "3/4 port1 mm2s/s2mm\n5 axi_iic_qsfp1\n6 axi_iic_clk\n(single-port: 0-2,\n3 = clk iic)",
         fc=g.C_PS_FILL, ec=g.C_PS_EDGE, title_fs=8.4, body_fs=6.2, title_dy=3.4)
    harrow(ax, 20.0, 24.0, 106.0, "", g.C_AXARR_FILL, g.C_AXARR_EDGE, bh=1.0,
           hh=1.9, hl=0.9)
    cell(ax, 24.0, sy0, 34.0, sy1 - sy0, "axi_smc  (1 SI → 3 per port + 1 MI)",
         "M00 qsfp_port0/S_AXI_LITE\nM01 axi_gpio_qsfp0   M02 axi_iic_qsfp0\n"
         "M03 qsfp_port1/S_AXI_LITE\nM04 axi_gpio_qsfp1   M05 axi_iic_qsfp1\n"
         "M06 axi_iic_clk", fc=g.C_CTRL_FILL, ec=g.C_CTRL_EDGE, body_fs=6.1)
    net(ax, [(34.0, sy1), (34.0, 38.0), (28.0, 38.0), (28.0, 41.0)], C_CTRL_LINE)
    cell(ax, 60.0, sy0, 40.0, sy1 - sy0, "axi_gpio_qsfp0  (dual, top level)",
         "CH1 3 outputs, C_DOUT_DEFAULT 0x2:\n[0] modsell  [1] resetl  [2] lpmode\n"
         "CH2 32 inputs (qsfp_in_cat0):\n[0] modprsl  [1] intl\n"
         "[15:2] MAC-error drops (14 bit)\n[31:16] other drops (16 bit)",
         fc=g.C_CTRL_FILL, ec=g.C_CTRL_EDGE, body_fs=6.1)
    net(ax, [(hx0 - 2.0, 93.0), (hx0 - 2.0, 34.0), (80.0, 34.0), (80.0, sy1)],
        g.C_DROP, lw=1.4)
    cell(ax, 102.0, sy0, 24.0, sy1 - sy0, "axi_iic_qsfp0  ·  axi_iic_clk",
         "QSFP module management\n(FMC LA03 on ZCU102)\n\nshared Si5328 bus\n"
         "(FMC LA02 on ZCU102)", fc=g.C_CTRL_FILL, ec=g.C_CTRL_EDGE, body_fs=6.1)
    cell(ax, 128.0, sy0, 38.0, sy1 - sy0, "Address map  (zcu102_hpc0 / 40G)",
         "axi_gpio_qsfp0  0x8000_0000   qsfp1  0x8001_0000\n"
         "axi_iic_clk     0x8002_0000\n"
         "axi_iic_qsfp0   0x8003_0000   qsfp1  0x8004_0000\n"
         "port0 MCDMA     0x8005_0000   MAC    0x8006_0000\n"
         "port1 MCDMA     0x8007_0000   MAC    0x8008_0000\n"
         "(assign_bd_address: check your target's\nhardware file / device tree)",
         fc=g.C_CTRL_FILL, ec=g.C_CTRL_EDGE, body_fs=5.9)
    legend(ax, 168.0, 64.0)
    save(fig, "bd-zynqmp-qsfp-port.png")


# ---------------------------------------------------------------------------
def fig_versal():
    fig, ax = new_fig(200, 128)
    ax.text(100, 126.0,
            "Block design  qsfp  —  qsfp_port0 hierarchy   "
            "(Vivado/src/bd/bd_versal.tcl, target vck190_fmcp1)",
            ha="center", va="bottom", fontsize=12, weight="bold", color=TXT)
    hx0, hx1, hy0, hy1 = 22.0, 158.0, 36.0, 123.0
    box(ax, hx0, hy0, hx1 - hx0, hy1 - hy0, C_HIER_FILL, g.C_MAC_EDGE, "",
        lw=1.3, ls=(0, (4, 2)), z=1.0)
    note(ax, hx0 + 1.0, hy1 - 1.8, "qsfp_port0  (hierarchy, one per QSFP28 port)",
         fs=9.0, ha="left", weight="bold", color=TXT)
    region(ax, hx0 + 1.0, hy0 + 1.0, 72.0, hy1 - 4.0, "sys_clk 100 MHz (clk_wizard_0)",
           "none", g.C_FAB_EDGE, "#606060", lab_fs=6.8)
    region(ax, 73.0, 64.0, 118.0, hy1 - 4.0, "axis_clk 390.625 MHz",
           g.C_DOM_MAC, g.C_DOM_MAC_EDGE, g.C_DOM_TXT, lab_fs=6.8)
    rx_y0, rx_y1 = 96.0, 112.0
    tx_y0, tx_y1 = 67.0, 83.0
    rx_yc, tx_yc = (rx_y0 + rx_y1) / 2, (tx_y0 + tx_y1) / 2
    cell(ax, 24.0, tx_y0, 13.0, rx_y1 - tx_y0, "axi_mcdma",
         "\n512-bit MM / AXIS\n64-bit address\n1 MM2S + 1 S2MM\n\nm_axi_sg /\n_mm2s / _s2mm\n"
         "→ NoC S06-S08\n(port 1: S09-S11)\n→ MC_0/1/2",
         fc=g.C_DMA_FILL, ec=g.C_DMA_EDGE, txtcolor="#FFFFFF", title_dy=2.6)
    cell(ax, 41.0, rx_y0, 14.0, rx_y1 - rx_y0, "rx_cdc_fifo",
         "512 deep, async\ns: axis_clk\nm: sys_clk")
    cell(ax, 76.0, rx_y0, 11.0, rx_y1 - rx_y0, "rx_dwidth", "48 → 64 B")
    cell(ax, 90.0, rx_y0, 25.0, rx_y1 - rx_y0, "rx_axis_adapter",
         "mrmac_rx_axis_adapter (+ frame FIFO)\nrx_axis_tdata0..5 / tkeep_user0..5\n"
         "→ 384-bit AXIS, FIFO_DEPTH 2048\nDROP_ERR_FRAMES 1\n"
         "rx_drop_status → GPIO2[31:2]", fc=g.C_FIFO_FILL, ec=g.C_FIFO_EDGE,
         body_fs=5.9)
    cell(ax, 41.0, tx_y0, 14.0, tx_y1 - tx_y0, "tx_cdc_fifo",
         "512 deep, async\ns: sys_clk\nm: axis_clk")
    cell(ax, 76.0, tx_y0, 11.0, tx_y1 - tx_y0, "tx_dwidth", "64 → 48 B")
    cell(ax, 90.0, tx_y0, 25.0, tx_y1 - tx_y0, "tx_axis_adapter",
         "mrmac_tx_axis_adapter\n384-bit AXIS →\ntx_axis_tdata0..5 / tkeep_user0..5",
         fc=g.C_FIFO_FILL, ec=g.C_FIFO_EDGE, body_fs=6.0)
    harrow(ax, 41.0, 37.0, rx_yc, "", g.C_AXARR_FILL, g.C_AXARR_EDGE, double=False,
           bh=1.0, hh=1.9, hl=1.0)
    harrow(ax, 76.0, 55.0, rx_yc, "", g.C_DPARR_FILL, g.C_DPARR_EDGE, double=False,
           bh=1.0, hh=1.9, hl=1.0)
    harrow(ax, 90.0, 87.0, rx_yc, "", g.C_DPARR_FILL, g.C_DPARR_EDGE, double=False,
           bh=1.0, hh=1.9, hl=1.0)
    harrow(ax, 37.0, 41.0, tx_yc, "", g.C_AXARR_FILL, g.C_AXARR_EDGE, double=False,
           bh=1.0, hh=1.9, hl=1.0)
    harrow(ax, 55.0, 76.0, tx_yc, "", g.C_DPARR_FILL, g.C_DPARR_EDGE, double=False,
           bh=1.0, hh=1.9, hl=1.0)
    harrow(ax, 87.0, 90.0, tx_yc, "", g.C_DPARR_FILL, g.C_DPARR_EDGE, double=False,
           bh=1.0, hh=1.9, hl=1.0)
    # MRMAC
    cell(ax, 120.0, tx_y0, 22.0, rx_y1 - tx_y0, "mrmac",
         "\nMRMAC_LOCATION_C0\nport 0 MRMAC_X0Y0\nport 1 MRMAC_X0Y2\n\n1x100GE CAUI-4\n"
         "GT refclk 322.265625\nMRMAC_IS_GT_WIZ_OLD 1\n\n"
         "tx/rx_axi_clk = axis_clk\ns_axi_aclk = sys_clk\n"
         "core/serdes resets =\nNOT gt_*_reset_done_out\n"
         "stat_rx_status_0 → LEDs",
         fc=g.C_GT_FILL, ec=g.C_GT_EDGE, title_fs=8.6, body_fs=6.1, title_dy=2.4)
    harrow(ax, 120.0, 115.0, rx_yc, "", g.C_DPARR_FILL, g.C_DPARR_EDGE, double=False,
           bh=1.0, hh=1.9, hl=1.0)
    harrow(ax, 115.0, 120.0, tx_yc, "", g.C_DPARR_FILL, g.C_DPARR_EDGE, double=False,
           bh=1.0, hh=1.9, hl=1.0)
    note(ax, 117.5, rx_yc + 4.0, "6 lanes", fs=5.6)
    # GT control gpio + smc_lite + clock buffers
    cell(ax, 24.0, 39.0, 13.0, 24.0, "axi_smc_\nlite", "\n\nS_AXI_LITE\nM00 → mrmac\nM01 → mcdma\n"
         "M02 → axi_\ngpio_gt0", fc=g.C_CTRL_FILL, ec=g.C_CTRL_EDGE, title_dy=3.2,
         body_fs=6.0)
    cell(ax, 40.0, 39.0, 31.0, 24.0, "axi_gpio_gt0",
         "CH1 5 outputs (sliced, ×4 lanes):\n[0] gt_reset_all  [1] tx datapath\n"
         "[2] rx datapath reset  [4:3] spare\nCH2 32 inputs:\n[0] tx / [1] rx reset done\n"
         "[7:2] MAC-error drops (6 bit)\n[31:8] FIFO-full drops (24 bit)",
         fc=g.C_CTRL_FILL, ec=g.C_CTRL_EDGE, body_fs=5.9)
    net(ax, [(100.0, rx_y0), (100.0, 89.0), (65.0, 89.0), (65.0, 63.0)], g.C_DROP,
        lw=1.4)
    note(ax, 82.0, 90.6, "rx_drop_status", fs=6.0, color=g.C_DROP, weight="bold")
    cell(ax, 74.0, 39.0, 44.0, 24.0, "10 × bufg_gt  +  ilconcat clock buses",
         "RX: per lane full-rate (rx_core_clk, rx_serdes_clk)\n"
         "and /2 (rx_alt_serdes_clk, GT chN_rxusrclk)\n"
         "TX: ch0 full-rate → tx_core_clk ×4,\n"
         "ch0 /2 → tx_alt_serdes_clk, all GT chN_txusrclk\n"
         "(per-lane RX clocking is required for CAUI-4)",
         fc=g.C_GT_FILL, ec=g.C_GT_EDGE, body_fs=6.0)
    net(ax, [(118.0, 50.0), (131.0, 50.0), (131.0, tx_y0)], C_CLKN)
    # GT quad etc. (top level, right)
    cell(ax, 160.0, 74.0, 22.0, 38.0, "gt_quad_base_0",
         "\nGTY, PROT0 4 lanes\nPRESET None\n80-bit RAW\n25.78125 Gb/s\nLCPLL integer-N\n"
         "refclk 322.265625\n\nTX/RXn_GT_IP_\nInterface ↔ mrmac\nchN_tx/rxoutclk\n→ bufg_gt",
         fc=g.C_GT_FILL, ec=g.C_GT_EDGE, body_fs=6.0)
    harrow(ax, 142.0, 160.0, 98.0, "", g.C_DPARR_FILL, g.C_DPARR_EDGE, bh=1.2,
           hh=2.2, hl=1.0)
    cell(ax, 160.0, 60.0, 22.0, 10.0, "util_ds_buf_0", "IBUFDSGTE\n← gt_ref_clk_0",
         fc=g.C_GT_FILL, ec=g.C_GT_EDGE, body_fs=6.0)
    net(ax, [(171.0, 70.0), (171.0, 74.0)], C_CLKN, lw=1.6)
    cell(ax, 160.0, 46.0, 22.0, 11.0, "axi_apb_bridge_0", "APB3 → GT DRP",
         fc=g.C_CTRL_FILL, ec=g.C_CTRL_EDGE, body_fs=6.0)
    note(ax, 184.0, 93.0, "qsfp0_gt\n→ FMC\nDP0-3", fs=6.5, ha="left", color=TXT)
    harrow(ax, 182.0, 190.0, 88.0, "", g.C_LINKARR_FILL, g.C_LINKARR_EDGE, bh=1.4,
           hh=2.5, hl=1.0)
    # bottom strip
    sy0, sy1 = 3.0, 31.0
    cell(ax, 2.0, sy0, 18.0, 120.0 - sy0, "versal_\ncips_0",
         "\n\n\nCIPS automation,\nDDR via NoC\n\nM_AXI_LPD\n→ axi_smc\n\npl0_ref_clk\n"
         "→ clk_wizard_0\n(clk_100m)\n→ axis_clk_wiz\n(clk_390m625)\n\npl0_resetn\n"
         "→ rst_100m,\nrst_390m625\n\npl_ps_irq0..6:\n0/1 port0 mm2s/s2mm\n2 axi_iic_qsfp0\n"
         "3/4 port1 mm2s/s2mm\n5 axi_iic_qsfp1\n6 axi_iic_clk",
         fc=g.C_PS_FILL, ec=g.C_PS_EDGE, title_fs=8.4, body_fs=6.2, title_dy=3.4)
    cell(ax, 24.0, sy0, 44.0, sy1 - sy0, "axi_smc  (M_AXI_LPD)  —  address map",
         "mrmac         0x8000_0000 / 0x8001_0000\n"
         "axi_gpio_qsfp 0x8002_0000 / 0x8003_0000\n"
         "axi_iic_clk   0x8004_0000\n"
         "axi_iic_qsfp  0x8005_0000 / 0x8006_0000\n"
         "axi_gpio_gt   0x8007_0000 / 0x8009_0000\n"
         "axi_mcdma     0x8008_0000 / 0x800A_0000   (port 0 / port 1)",
         fc=g.C_CTRL_FILL, ec=g.C_CTRL_EDGE, body_fs=6.0)
    cell(ax, 70.0, sy0, 34.0, sy1 - sy0, "axi_gpio_qsfp0  (top level)",
         "CH1 3 outputs, C_DOUT_DEFAULT 0x2:\n[0] modsell  [1] resetl  [2] lpmode\n"
         "CH2 2 inputs:\n[0] modprsl  [1] intl\n(no drop counters here on Versal)",
         fc=g.C_CTRL_FILL, ec=g.C_CTRL_EDGE, body_fs=6.0)
    cell(ax, 106.0, sy0, 50.0, sy1 - sy0, "Clocks and resets",
         "clk_wizard_0/clk_100m: AXI-Lite, MCDMA, NoC aclk6,\nGT APB3, MRMAC s_axi\n"
         "axis_clk_wiz/clk_390m625: MRMAC client, adapters,\ndwidth converters, CDC FIFO "
         "MRMAC side\nrst_100m, rst_390m625 (proc_sys_reset ← pl0_resetn)",
         fc=g.C_CLK_FILL, ec=g.C_CLK_EDGE, body_fs=6.0)
    legend(ax, 160.0, 42.0, opt=False)
    save(fig, "bd-versal-qsfp-port.png")


def main():
    fig_zynqmp()
    fig_versal()


if __name__ == "__main__":
    main()
