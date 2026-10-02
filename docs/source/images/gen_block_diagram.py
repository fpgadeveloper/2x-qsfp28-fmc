#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Opsero Electronic Design Inc.
"""
Generate the system-level block diagrams for the Opsero 2x QSFP28 FMC (OP120)
100G/40G Ethernet reference design docs.

The design exists in three architectural flavours, one figure each:

  versal-mrmac-100g-block-diagram.png   Versal (vck190_fmcp1): per QSFP28 port a
      Versal integrated MRMAC (1x100GE CAUI-4) on its own GTY quad, the MRMAC
      client adapters (the RX adapter carries the store-and-forward RX frame
      FIFO), 384<->512-bit width converters, CDC FIFOs and an AXI MCDMA to DDR
      through the NoC.
  zynqmp-block-diagram.png              Zynq UltraScale+ (zcu102_hpc0,
      zcu106_hpc0, zcu111, zcu208, zcu216 and the *_ss targets): per port an
      UltraScale+ 100G CMAC (100G targets) or a 40G/50G Ethernet Subsystem
      (40G targets) with its in-core GT quad, the RX frame FIFO, the RX flush
      guard, the TX frame gate (40G), CDC FIFOs and an AXI MCDMA to the PS DDR
      through an S_AXI_HPx_FPD port.
  microblaze-block-diagram.png          KCU116 (kcu116, kcu116_ss): the same
      port datapath (single port) behind a MicroBlaze with a DDR4 MIG.

Every block and number is taken from Vivado/src/bd/bd_versal.tcl,
bd_zynqmp.tcl and bd_mb.tcl. The palette and the drawing helpers are shared
with the other Opsero reference-design block diagrams and with
gen_bd_diagram.py (the Vivado block-design views).

The output PNGs are written next to this script (i.e. into docs/source/images/).

Usage (from anywhere):
    python3 docs/source/images/gen_block_diagram.py
"""

import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, FancyBboxPatch, FancyArrowPatch
from matplotlib.lines import Line2D

# ---- palette (shared with the other Opsero reference-design block diagrams) --
C_PS_FILL      = "#D9D9D9"; C_PS_EDGE      = "#7F7F7F"   # processor / DDR column
C_FAB_FILL     = "#F2F2F2"; C_FAB_EDGE     = "#BFBFBF"   # FPGA fabric container
C_DMA_FILL     = "#808080"; C_DMA_EDGE     = "#404040"   # AXI MCDMA (dark grey)
C_MAC_FILL     = "#E8E8F2"; C_MAC_EDGE     = "#8C8CC0"   # datapath logic (lavender)
C_GT_FILL      = "#F3EFE2"; C_GT_EDGE      = "#BFB585"   # hard blocks: MAC, GT (cream)
C_FMC_FILL     = "#DCE6F2"; C_FMC_EDGE     = "#9DB7D4"   # external FMC (blue-grey)
C_CAGE_FILL    = "#FFFFFF"                                # QSFP28 cages (white on FMC)
C_CLK_FILL     = "#FDE9D9"; C_CLK_EDGE     = "#E0B090"   # clocking (peach)
C_CTRL_FILL    = "#ECECEC"; C_CTRL_EDGE    = "#BFBFBF"   # control plane
C_AXARR_FILL   = "#EDF3D4"; C_AXARR_EDGE   = "#A6B85A"   # data arrows (pale green)
C_LINKARR_FILL = "#DAE8F5"; C_LINKARR_EDGE = "#6F9FCF"   # link arrows (pale blue)
C_REFCLK_LINE  = "#C8823C"                                # refclk arrows (orange)
TXT = "#1A1A1A"
# additions for this design
C_DPARR_FILL   = "#D5E6A3"; C_DPARR_EDGE   = "#7F9A2E"   # MAC-clock datapath arrows
C_FIFO_FILL    = "#E4F0D0"; C_FIFO_EDGE    = "#7F9A2E"   # RX frame FIFO / guards
C_OPT_EDGE     = "#9A9A9A"                                # 40G-only blocks (dashed)
C_DROP         = "#B03A2E"                                # drop counters (red)
C_DOM_SYS      = "#FFFFFF"                                # sys_clk domain region
C_DOM_MAC      = "#FBF7E6"; C_DOM_MAC_EDGE = "#D9C27A"   # MAC clock domain region
C_DOM_TXT      = "#8A6D12"


def box(ax, x, y, w, h, fc, ec, label, fs=10, rot=0, lw=1.2, weight="normal",
        round_=False, txtcolor=None, ls="-", z=2):
    if round_:
        p = FancyBboxPatch((x + 0.4, y + 0.4), w - 0.8, h - 0.8,
                           boxstyle="round,pad=0.0,rounding_size=1.2",
                           fc=fc, ec=ec, lw=lw, ls=ls, zorder=z)
    else:
        p = plt.Rectangle((x, y), w, h, fc=fc, ec=ec, lw=lw, ls=ls, zorder=z)
    ax.add_patch(p)
    if label:
        ax.text(x + w / 2, y + h / 2, label, ha="center", va="center",
                fontsize=fs, rotation=rot, color=txtcolor or TXT, weight=weight,
                zorder=z + 1, linespacing=1.25)


def titled_box(ax, x, y, w, h, fc, ec, title, body, title_fs=9.5, body_fs=7.6,
               lw=1.2, txtcolor=None, title_dy=2.6, ls="-"):
    """A box() with a bold title line at the top and a smaller body below it."""
    box(ax, x, y, w, h, fc, ec, "", lw=lw, ls=ls)
    cx = x + w / 2
    ax.text(cx, y + h - title_dy, title, ha="center", va="center",
            fontsize=title_fs, weight="bold", color=txtcolor or TXT, zorder=3)
    ax.text(cx, y + (h - title_dy * 1.9) / 2, body, ha="center", va="center",
            fontsize=body_fs, color=txtcolor or TXT, zorder=3, linespacing=1.3)


def harrow(ax, x0, x1, yc, label, fc, ec, double=True, bh=2.0, hh=3.4, hl=3.2,
           fs=8.5, lw=1.1, lab_dy=0.0, lab_color=None, weight="normal"):
    """Horizontal block arrow from x0 to x1.

    double=True  : double-headed (requires x0 < x1).
    double=False : single-headed with the head at x1; works in either
                   direction (x1 may be < x0 for a leftward arrow).
    """
    if double:
        pts = [(x0, yc), (x0 + hl, yc + hh), (x0 + hl, yc + bh),
               (x1 - hl, yc + bh), (x1 - hl, yc + hh), (x1, yc),
               (x1 - hl, yc - hh), (x1 - hl, yc - bh),
               (x0 + hl, yc - bh), (x0 + hl, yc - hh)]
    else:
        s = 1.0 if x1 >= x0 else -1.0   # direction from tail (x0) to head (x1)
        neck = x1 - s * hl              # base of the arrowhead
        pts = [(x0, yc + bh), (neck, yc + bh), (neck, yc + hh),
               (x1, yc), (neck, yc - hh), (neck, yc - bh), (x0, yc - bh)]
    ax.add_patch(Polygon(pts, closed=True, fc=fc, ec=ec, lw=lw, zorder=2))
    if label:
        ax.text((x0 + x1) / 2, yc + lab_dy, label, ha="center", va="center",
                fontsize=fs, color=lab_color or TXT, zorder=3, linespacing=1.15,
                weight=weight)


def varrow(ax, xc, y0, y1, fc, ec, double=True, bw=1.4, hw=2.6, hl=2.4, lw=1.1):
    """Vertical block arrow from y0 to y1 (head at y1; both ends if double)."""
    if double:
        lo, hi = min(y0, y1), max(y0, y1)
        pts = [(xc, lo), (xc + hw, lo + hl), (xc + bw, lo + hl),
               (xc + bw, hi - hl), (xc + hw, hi - hl), (xc, hi),
               (xc - hw, hi - hl), (xc - bw, hi - hl),
               (xc - bw, lo + hl), (xc - hw, lo + hl)]
    else:
        s = 1.0 if y1 >= y0 else -1.0
        neck = y1 - s * hl
        pts = [(xc - bw, y0), (xc - bw, neck), (xc - hw, neck), (xc, y1),
               (xc + hw, neck), (xc + bw, neck), (xc + bw, y0)]
    ax.add_patch(Polygon(pts, closed=True, fc=fc, ec=ec, lw=lw, zorder=2))


def route(ax, pts, color, lw=1.8, ls="-"):
    """Thin elbow arrow through the points in pts (head at the last point)."""
    xs, ys = zip(*pts[:-1])
    ax.add_line(Line2D(xs, ys, color=color, lw=lw, zorder=3, ls=ls,
                       solid_capstyle="butt", solid_joinstyle="miter"))
    ax.add_patch(FancyArrowPatch(pts[-2], pts[-1], arrowstyle="-|>",
                                 mutation_scale=11, lw=lw, color=color,
                                 zorder=3, shrinkA=0, shrinkB=0))


def refclk_arrow(ax, p0, p1, label, lab_xy, fs=7.8, lw=1.9):
    """Thin single-line arrow (head at p1) for a single clock net, at any angle."""
    ax.add_patch(FancyArrowPatch(p0, p1, arrowstyle="-|>", mutation_scale=13,
                                 lw=lw, color=C_REFCLK_LINE, zorder=3,
                                 shrinkA=0, shrinkB=0))
    ax.text(lab_xy[0], lab_xy[1], label, ha="center", va="center",
            fontsize=fs, color=C_REFCLK_LINE, zorder=4, weight="bold",
            linespacing=1.2)


def region(ax, x0, y0, x1, y1, label, fc, ec, lab_color, lab_fs=7.6,
           lab_xy=None, ls=(0, (5, 3)), z=1.2):
    """Dashed rounded region (clock domain) with a small bold label."""
    ax.add_patch(FancyBboxPatch((x0, y0), x1 - x0, y1 - y0,
                                boxstyle="round,pad=0.0,rounding_size=0.8",
                                fc=fc, ec=ec, lw=1.2, ls=ls, zorder=z))
    if label:
        lx, ly = lab_xy if lab_xy else (x0 + 1.0, y1 - 1.6)
        ax.text(lx, ly, label, ha="left", va="center", fontsize=lab_fs,
                weight="bold", color=lab_color, zorder=3)


def note(ax, x, y, s, fs=6.8, ha="center", color="#404040", weight="normal",
         va="center", z=4, rot=0):
    ax.text(x, y, s, ha=ha, va=va, fontsize=fs, color=color, zorder=z,
            linespacing=1.3, weight=weight, rotation=rot)


def new_fig(w=200, h=132):
    fig, ax = plt.subplots(figsize=(w / 10.0, h / 10.0), dpi=120)
    ax.set_xlim(0, w)
    ax.set_ylim(0, h)
    ax.axis("off")
    return fig, ax


def save(fig, name):
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), name)
    fig.savefig(out, bbox_inches="tight", pad_inches=0.15, facecolor="white")
    plt.close(fig)
    print("wrote", out)


# ---------------------------------------------------------------------------
# Shared pieces: the FMC column and the test setups
# ---------------------------------------------------------------------------
def draw_fmc(ax, x0, x1, top, p0_y, p1_y, si_y, rate, slot, lanes_txt,
             refclk_mhz, gt_right, p0_lane_y, p1_lane_y, si_label_x,
             single_port=False, partner_txt=""):
    """The 2x QSFP28 FMC column: two cages, the Si5328, link arrows."""
    fcx = (x0 + x1) / 2
    ax.add_patch(plt.Rectangle((x0, 26.0), x1 - x0, top - 26.0,
                               fc=C_FMC_FILL, ec=C_FMC_EDGE, lw=1.3, zorder=1))
    ax.text(fcx, top + 0.6, "External", ha="center", va="bottom",
            fontsize=12, weight="bold", color=TXT)
    ax.text(fcx, top - 5.0, "2x QSFP28 FMC\n(OP120) on " + slot, ha="center",
            va="center", fontsize=9.6, weight="bold", color=TXT, linespacing=1.3)
    sx, sw = x0 + 2.0, x1 - x0 - 4.0
    c0_y0, c0_y1 = p0_y
    titled_box(ax, sx, c0_y0, sw, c0_y1 - c0_y0, C_CAGE_FILL, C_FMC_EDGE,
               "QSFP28 port 0",
               f"{rate}\n{lanes_txt}\nFMC DP0-3\n\nsideband + module\nI2C from the PL",
               title_fs=8.8, body_fs=7.0, title_dy=2.8)
    s_y0, s_y1 = si_y
    titled_box(ax, sx, s_y0, sw, s_y1 - s_y0, C_CLK_FILL, C_CLK_EDGE, "Si5328",
               f"{refclk_mhz} MHz\nCKOUT1 → GBTCLK0\nCKOUT2 → GBTCLK1\n"
               "programmed by software\nover AXI IIC",
               title_fs=8.8, body_fs=6.8, title_dy=2.6)
    c1_y0, c1_y1 = p1_y
    if single_port:
        titled_box(ax, sx, c1_y0, sw, c1_y1 - c1_y0, C_CAGE_FILL, C_FMC_EDGE,
                   "QSFP28 port 1",
                   "not used by this target:\nmodule held in reset /\nlow-power "
                   "mode",
                   title_fs=8.8, body_fs=7.0, title_dy=2.8, ls=(0, (4, 2)))
    else:
        titled_box(ax, sx, c1_y0, sw, c1_y1 - c1_y0, C_CAGE_FILL, C_FMC_EDGE,
                   "QSFP28 port 1",
                   f"{rate}\nFMC DP4-7\n\nsideband + I2C",
                   title_fs=8.8, body_fs=7.0, title_dy=2.8)
    harrow(ax, gt_right, sx, p0_lane_y, "", C_LINKARR_FILL, C_LINKARR_EDGE,
           bh=2.0, hh=3.4, hl=1.6)
    note(ax, (gt_right + sx) / 2, p0_lane_y + 5.4, "FMC\nDP0-3", fs=7.0,
         color=TXT)
    if not single_port:
        harrow(ax, gt_right, sx, p1_lane_y, "", C_LINKARR_FILL, C_LINKARR_EDGE,
               bh=2.0, hh=3.4, hl=1.6)
        note(ax, (gt_right + sx) / 2, p1_lane_y - 5.4, "FMC\nDP4-7", fs=7.0,
             color=TXT)
    refclk_arrow(ax, (sx, s_y1 - 2.0), (gt_right, p0_lane_y - 7.0), "GBTCLK0",
                 (si_label_x, s_y1 + 1.0), fs=6.6)
    if not single_port:
        refclk_arrow(ax, (sx, s_y0 + 2.0), (gt_right, p1_lane_y + 6.0),
                     "GBTCLK1", (si_label_x, s_y0 - 1.6), fs=6.6)
    return sx, sw


def draw_tests(ax, x0, x1, y0, y1, cable_txt, partner_txt):
    titled_box(ax, x0, y0, x1 - x0, y1 - y0, C_CAGE_FILL, C_LINKARR_EDGE,
               "Test setups",
               cable_txt + "\n\n" + partner_txt,
               title_fs=8.8, body_fs=6.9, title_dy=2.8, lw=1.3)


# ---------------------------------------------------------------------------
# Figure 1: Versal (vck190_fmcp1)
# ---------------------------------------------------------------------------
def fig_versal():
    fig, ax = new_fig(200, 136)
    # vertical plan: control strip 4-22, port 1 row 27-49, port 0 54-118
    rx_y0, rx_h = 96.0, 17.0      # port 0 RX row (right -> left)
    tx_y0, tx_h = 60.0, 17.0      # port 0 TX row (left -> right)
    rx_yc, tx_yc = rx_y0 + rx_h / 2, tx_y0 + tx_h / 2
    p1_y0, p1_y1 = 27.5, 49.5
    p1_yc = (p1_y0 + p1_y1) / 2

    # ---- PS column -----------------------------------------------------------
    ps_x0, ps_w = 2, 16
    ps_r = ps_x0 + ps_w
    titled_box(ax, ps_x0, 112, ps_w, 14, C_PS_FILL, C_PS_EDGE, "DDR4",
               "VCK190\non-board", title_fs=10.5, body_fs=7.4, title_dy=3.4,
               lw=1.3)
    box(ax, ps_x0, 4, ps_w, 104, C_PS_FILL, C_PS_EDGE, "", lw=1.3)
    cx = ps_x0 + ps_w / 2
    note(ax, cx, 101.0, "Versal PS\n(CIPS)", fs=11.5, weight="bold", color=TXT)
    note(ax, cx, 84.0, "Arm Cortex-A72\n\nLinux:\nxilinx_axienet\n+ MRMAC link\nmonitor\n\n"
         "or bare-metal\necho server", fs=7.4, color=TXT)
    note(ax, cx, 52.0, "packet data:\nMCDMA ↔ DDR4\nvia the NoC\n\ncontrol:\n"
         "M_AXI_LPD\n(100 MHz)\n\nbring-up:\nVADJ 1.5 V\n(U-Boot or\napp),\nSi5328 over\n"
         "AXI IIC", fs=7.0, color="#404040")
    noc_x, noc_w = 20.5, 4.0
    box(ax, noc_x, 26, noc_w, 100, C_PS_FILL, C_PS_EDGE, "NoC  (axi_noc_0)",
        fs=8.2, rot=90, weight="bold", lw=1.3)
    harrow(ax, ps_r, noc_x, 119.0, "", C_AXARR_FILL, C_AXARR_EDGE, bh=1.2,
           hh=2.2, hl=1.1)
    harrow(ax, ps_r, noc_x, 95.0, "", C_AXARR_FILL, C_AXARR_EDGE, bh=1.2,
           hh=2.2, hl=1.1)

    # ---- fabric ---------------------------------------------------------------
    fab_x0, fab_x1 = 27, 152
    ax.add_patch(plt.Rectangle((fab_x0, 2.5), fab_x1 - fab_x0, 126,
                               fc=C_FAB_FILL, ec=C_FAB_EDGE, lw=1.3, zorder=1))
    ax.text((fab_x0 + fab_x1) / 2, 129.1,
            "Versal PL + integrated blocks  (XCVC1902, VCK190, FMCP1)",
            ha="center", va="bottom", fontsize=13, weight="bold", color=TXT)
    # clock domains of port 0
    region(ax, 28.0, 55.5, 74.5, 125.5, "sys_clk  100 MHz", C_DOM_SYS,
           C_FAB_EDGE, "#606060")
    region(ax, 75.5, 55.5, 151.0, 125.5,
           "MRMAC client clock  390.625 MHz  (axis_clk_wiz)", C_DOM_MAC,
           C_DOM_MAC_EDGE, C_DOM_TXT)

    # MCDMA
    dma_x, dma_w = 29.0, 12.0
    titled_box(ax, dma_x, tx_y0, dma_w, rx_y0 + rx_h - tx_y0, C_DMA_FILL,
               C_DMA_EDGE, "AXI\nMCDMA",
               "\n\n512-bit\n1 MM2S +\n1 S2MM\nchannel\n\nSG / MM2S /\nS2MM\n→ NoC\n\n"
               "S2MM = RX\n\nMM2S = TX",
               title_fs=9.0, body_fs=7.0, txtcolor="#FFFFFF", title_dy=4.4)
    for yc in (rx_yc, tx_yc, (rx_yc + tx_yc) / 2):
        harrow(ax, noc_x + noc_w, dma_x, yc, "", C_AXARR_FILL, C_AXARR_EDGE,
               bh=1.3, hh=2.4, hl=1.2)

    # RX row (right to left): MRMAC -> RX adapter (frame FIFO) -> dwidth -> CDC
    cdc_x, cdc_w = 60.0, 23.0
    dw_x, dw_w = 87.0, 11.0
    ad_x, ad_w = 102.0, 20.0
    mr_x, mr_w = 126.0, 11.0
    gt_x, gt_w = 140.0, 9.0
    titled_box(ax, cdc_x, rx_y0, cdc_w, rx_h, C_MAC_FILL, C_MAC_EDGE,
               "rx_cdc_fifo", "async AXIS FIFO\n512 deep\n390.625 → 100 MHz",
               title_fs=8.4, body_fs=7.0, title_dy=2.6)
    titled_box(ax, dw_x, rx_y0, dw_w, rx_h, C_MAC_FILL, C_MAC_EDGE,
               "rx_dwidth", "AXIS width\nconverter\n48 → 64 B",
               title_fs=8.0, body_fs=6.9, title_dy=2.6)
    titled_box(ax, ad_x, rx_y0, ad_w, rx_h, C_FIFO_FILL, C_FIFO_EDGE,
               "rx_axis_adapter",
               "6 MRMAC lanes → 384-bit AXIS\n+ RX frame FIFO 2048 × 48 B\n"
               "store-and-forward: whole\nframes dropped on overflow\n"
               "or MAC error",
               title_fs=8.4, body_fs=6.6, title_dy=2.6)
    harrow(ax, dw_x, cdc_x + cdc_w, rx_yc, "", C_DPARR_FILL, C_DPARR_EDGE,
           double=False, bh=1.2, hh=2.2, hl=1.6)
    harrow(ax, ad_x, dw_x + dw_w, rx_yc, "", C_DPARR_FILL, C_DPARR_EDGE,
           double=False, bh=1.2, hh=2.2, hl=1.6)
    harrow(ax, cdc_x, dma_x + dma_w, rx_yc, "S2MM", C_AXARR_FILL, C_AXARR_EDGE,
           double=False, bh=1.5, hh=2.7, hl=2.0, fs=7.0, lab_dy=4.2)
    harrow(ax, mr_x, ad_x + ad_w, rx_yc, "", C_DPARR_FILL, C_DPARR_EDGE,
           double=False, bh=1.5, hh=2.7, hl=1.6)
    note(ax, (ad_x + ad_w + mr_x) / 2, rx_yc + 5.0, "6 × 64b\nno ready", fs=6.2)

    # TX row (left to right): CDC -> dwidth -> TX adapter -> MRMAC
    titled_box(ax, cdc_x, tx_y0, cdc_w, tx_h, C_MAC_FILL, C_MAC_EDGE,
               "tx_cdc_fifo", "async AXIS FIFO\n512 deep\n100 → 390.625 MHz",
               title_fs=8.4, body_fs=7.0, title_dy=2.6)
    titled_box(ax, dw_x, tx_y0, dw_w, tx_h, C_MAC_FILL, C_MAC_EDGE,
               "tx_dwidth", "AXIS width\nconverter\n64 → 48 B",
               title_fs=8.0, body_fs=6.9, title_dy=2.6)
    titled_box(ax, ad_x, tx_y0, ad_w, tx_h, C_MAC_FILL, C_MAC_EDGE,
               "tx_axis_adapter", "384-bit AXIS →\n6 MRMAC client lanes",
               title_fs=8.4, body_fs=6.8, title_dy=2.6)
    harrow(ax, dma_x + dma_w, cdc_x, tx_yc, "MM2S", C_AXARR_FILL, C_AXARR_EDGE,
           double=False, bh=1.5, hh=2.7, hl=2.0, fs=7.0, lab_dy=-4.2)
    harrow(ax, cdc_x + cdc_w, dw_x, tx_yc, "", C_DPARR_FILL, C_DPARR_EDGE,
           double=False, bh=1.2, hh=2.2, hl=1.6)
    harrow(ax, dw_x + dw_w, ad_x, tx_yc, "", C_DPARR_FILL, C_DPARR_EDGE,
           double=False, bh=1.2, hh=2.2, hl=1.6)
    harrow(ax, ad_x + ad_w, mr_x, tx_yc, "", C_DPARR_FILL, C_DPARR_EDGE,
           double=False, bh=1.5, hh=2.7, hl=1.6)

    # MRMAC + GTY
    titled_box(ax, mr_x, tx_y0, mr_w, rx_y0 + rx_h - tx_y0, C_GT_FILL, C_GT_EDGE,
               "MRMAC",
               "\nMRMAC_X0Y0\n\n1x100GE\nCAUI-4\n\nno FEC\n\nFCS insert\n/ strip\n\n"
               "s_axi\n0x8000_0000",
               title_fs=9.2, body_fs=6.9, title_dy=2.8)
    titled_box(ax, gt_x, tx_y0, gt_w, rx_y0 + rx_h - tx_y0, C_GT_FILL, C_GT_EDGE,
               "GTY",
               "\nquad\nX1Y1\n\n4 lanes\n25.78125\nGb/s\n\nper-lane\nRX user\nclocks\n"
               "(BUFG_GT)",
               title_fs=9.2, body_fs=6.7, title_dy=2.8)
    p0_lane_y = 88.0
    harrow(ax, mr_x + mr_w, gt_x, p0_lane_y, "", C_DPARR_FILL, C_DPARR_EDGE,
           bh=1.5, hh=2.7, hl=1.0)

    # middle band: GT-control GPIO with the drop counters, LEDs
    band_y0, band_y1 = tx_y0 + tx_h, rx_y0
    titled_box(ax, 60.0, band_y0 + 2.0, 39.0, band_y1 - band_y0 - 4.0,
               C_CTRL_FILL, C_CTRL_EDGE, "axi_gpio_gt0   (0x8007_0000)",
               "CH1 out: GT reset-all, TX / RX datapath reset\n"
               "CH2 in: [0] TX / [1] RX reset done,\n"
               "[7:2] MAC-error drops, [31:8] FIFO-full drops",
               title_fs=7.8, body_fs=6.6, title_dy=2.2)
    route(ax, [(ad_x + 6.0, rx_y0), (ad_x + 6.0, band_y1 - 4.5),
               (99.0, band_y1 - 4.5)], C_DROP, lw=1.4)
    note(ax, 110.5, band_y1 - 6.6, "drop counters", fs=6.4, color=C_DROP,
         weight="bold")
    note(ax, (mr_x + mr_w / 2), band_y0 - 0.0 + 1.0, "", fs=6)
    note(ax, 116.5, band_y0 + 3.6, "stat_rx_status → green / red\nLEDs on the FMC",
         fs=6.3)

    # ---- port 1 (compact) ----------------------------------------------------
    region(ax, 28.0, 26.5, 151.0, 51.5, "", "#F7F7F7", C_FAB_EDGE, "#606060",
           z=1.1)
    titled_box(ax, dma_x, p1_y0, dma_w, p1_y1 - p1_y0, C_DMA_FILL, C_DMA_EDGE,
               "AXI\nMCDMA", "\n\nport 1", title_fs=8.6, body_fs=7.0,
               txtcolor="#FFFFFF", title_dy=4.4)
    harrow(ax, noc_x + noc_w, dma_x, p1_yc, "", C_AXARR_FILL, C_AXARR_EDGE,
           bh=1.3, hh=2.4, hl=1.2)
    titled_box(ax, cdc_x, p1_y0, ad_x + ad_w - cdc_x, p1_y1 - p1_y0, C_MAC_FILL,
               C_MAC_EDGE, "QSFP28 port 1 datapath  —  the same chain as port 0",
               "rx_cdc_fifo ← rx_dwidth ← rx_axis_adapter (RX frame FIFO)\n"
               "tx_cdc_fifo → tx_dwidth → tx_axis_adapter\n"
               "axi_gpio_gt1 (0x8009_0000): GT resets, reset done, drop counters",
               title_fs=8.6, body_fs=7.0, title_dy=2.8)
    harrow(ax, dma_x + dma_w, cdc_x, p1_yc, "", C_AXARR_FILL, C_AXARR_EDGE,
           bh=1.5, hh=2.7, hl=1.6)
    titled_box(ax, mr_x, p1_y0, mr_w, p1_y1 - p1_y0, C_GT_FILL, C_GT_EDGE,
               "MRMAC", "\nMRMAC_X0Y2\n1x100GE\nCAUI-4", title_fs=9.0,
               body_fs=6.8, title_dy=2.8)
    titled_box(ax, gt_x, p1_y0, gt_w, p1_y1 - p1_y0, C_GT_FILL, C_GT_EDGE,
               "GTY", "\nquad\nX1Y2\n4 lanes", title_fs=9.0, body_fs=6.8,
               title_dy=2.8)
    harrow(ax, ad_x + ad_w, mr_x, p1_yc, "", C_DPARR_FILL, C_DPARR_EDGE,
           bh=1.5, hh=2.7, hl=1.1)
    harrow(ax, mr_x + mr_w, gt_x, p1_yc, "", C_DPARR_FILL, C_DPARR_EDGE,
           bh=1.5, hh=2.7, hl=1.0)

    # ---- control plane + clocking strip --------------------------------------
    harrow(ax, ps_r, 29.0, 13.0, "", C_CTRL_FILL, C_PS_EDGE, double=False,
           bh=1.6, hh=2.9, hl=2.0)
    titled_box(ax, 29.0, 4.0, 70.0, 19.5, C_CTRL_FILL, C_CTRL_EDGE,
               "Control plane: AXI-Lite from M_AXI_LPD (axi_smc)",
               "per port: MRMAC, MCDMA, axi_gpio_gt (GT reset / drop counters),\n"
               "axi_gpio_qsfp (ModSelL, ResetL, LPMode / ModPrsL, IntL),\n"
               "axi_iic_qsfp (QSFP module management)\n"
               "shared: axi_iic_clk (Si5328)    interrupts: 4 MCDMA + 3 IIC",
               title_fs=8.6, body_fs=7.0, title_dy=3.0)
    titled_box(ax, 101.0, 4.0, 50.0, 19.5, C_CLK_FILL, C_CLK_EDGE,
               "Clocking (CIPS pl0_ref_clk)",
               "clk_wizard_0:  100 MHz  sys_clk — AXI-Lite,\n"
               "MCDMA, NoC ports, MRMAC s_axi\n"
               "axis_clk_wiz:  390.625 MHz  MRMAC client\n"
               "GT refclk: 322.265625 MHz from the FMC Si5328",
               title_fs=8.6, body_fs=7.0, title_dy=3.0)

    # ---- external -------------------------------------------------------------
    fx0, fx1 = 158.0, 180.0
    draw_fmc(ax, fx0, fx1, 128.5, (90.0, 118.0), (27.5, 49.5), (58.0, 80.0),
             "100GBASE-R", "FMCP1", "4 × 25.78125 Gb/s", "322.265625",
             gt_x + gt_w, p0_lane_y, p1_yc, 155.5)
    draw_tests(ax, 182.0, 199.0, 40.0, 118.0,
               "A: passive QSFP28\nDAC cable\nport 0 ↔ port 1\n→ qsfp-loopback-\ntest",
               "B: 100G link\npartner\n(NIC / switch)\nwith FEC OFF\n\n"
               "C: passive\nloopback\nmodule\n→ --single")
    save(fig, "versal-mrmac-100g-block-diagram.png")


# ---------------------------------------------------------------------------
# Figures 2 and 3: CMAC / 40G-50G subsystem (Zynq UltraScale+ and MicroBlaze)
# ---------------------------------------------------------------------------
def hse_port0(ax, top, dma_x, dma_w, sys_x1, fab_x1, single_line=False):
    """Draw the detailed port-0 datapath of the ZynqMP / MicroBlaze designs.

    Returns (rx_yc, tx_yc, gt_right, lane_y)."""
    rx_y0, rx_h = top - 25.0, 17.0
    tx_y0, tx_h = top - 61.0, 17.0
    rx_yc, tx_yc = rx_y0 + rx_h / 2, tx_y0 + tx_h / 2
    region(ax, dma_x - 1.0, tx_y0 - 4.5, sys_x1, top + 4.0, "sys_clk  100 MHz",
           C_DOM_SYS, C_FAB_EDGE, "#606060")
    region(ax, sys_x1 + 1.0, tx_y0 - 4.5, fab_x1 - 1.0, top + 4.0,
           "MAC client clock, TX and RX:  CMAC gt_txusrclk2 322.27 MHz  /  "
           "40G tx_clk_out_0 312.5 MHz",
           C_DOM_MAC, C_DOM_MAC_EDGE, C_DOM_TXT, lab_fs=7.2)

    # MCDMA
    titled_box(ax, dma_x, tx_y0, dma_w, rx_y0 + rx_h - tx_y0, C_DMA_FILL,
               C_DMA_EDGE, "AXI\nMCDMA",
               "\n\n512-bit\n1 MM2S +\n1 S2MM\n\nSG / MM2S /\nS2MM\n\nS2MM = RX\n\n"
               "MM2S = TX",
               title_fs=9.0, body_fs=7.0, txtcolor="#FFFFFF", title_dy=4.4)

    # columns
    gd_x, gd_w = dma_x + dma_w + 6.0, 14.0          # rx flush guard
    cdc_x, cdc_w = gd_x + gd_w + 4.0, 15.0
    dw_x, dw_w = cdc_x + cdc_w + 6.0, 12.0          # 40G-only dwidth
    ff_x, ff_w = dw_x + dw_w + 4.0, 20.0            # frame FIFO / tx gate
    mac_x, mac_w = ff_x + ff_w + 5.0, 15.0
    # TX row: cdc, dwidth, tx gate aligned under the RX columns
    titled_box(ax, gd_x, rx_y0, gd_w, rx_h, C_FIFO_FILL, C_FIFO_EDGE,
               "rx_guard", "RX flush guard\nflushes the RX\nchain on S2MM\nreset, "
               "releases\non a frame\nboundary",
               title_fs=8.0, body_fs=6.3, title_dy=2.4)
    titled_box(ax, cdc_x, rx_y0, cdc_w, rx_h, C_MAC_FILL, C_MAC_EDGE,
               "rx_cdc_fifo", "async AXIS\nFIFO, 512 deep\nMAC clk →\n100 MHz",
               title_fs=8.0, body_fs=6.6, title_dy=2.4)
    titled_box(ax, dw_x, rx_y0, dw_w, rx_h, C_MAC_FILL, C_OPT_EDGE,
               "rx_dwidth", "40G only\n32 → 64 B", title_fs=8.0, body_fs=6.6,
               title_dy=2.4, ls=(0, (4, 2)))
    titled_box(ax, ff_x, rx_y0, ff_w, rx_h, C_FIFO_FILL, C_FIFO_EDGE,
               "rx_frame_fifo",
               "store-and-forward, 2048 beats\n(128 KB CMAC / 64 KB 40G)\n"
               "whole frames dropped on\noverflow, MAC error or\nMAC reset",
               title_fs=8.4, body_fs=6.4, title_dy=2.4)
    harrow(ax, gd_x, dma_x + dma_w, rx_yc, "S2MM", C_AXARR_FILL, C_AXARR_EDGE,
           double=False, bh=1.5, hh=2.7, hl=1.8, fs=6.8, lab_dy=4.2)
    harrow(ax, cdc_x, gd_x + gd_w, rx_yc, "", C_AXARR_FILL, C_AXARR_EDGE,
           double=False, bh=1.2, hh=2.2, hl=1.4)
    harrow(ax, dw_x, cdc_x + cdc_w, rx_yc, "", C_DPARR_FILL, C_DPARR_EDGE,
           double=False, bh=1.2, hh=2.2, hl=1.4)
    harrow(ax, ff_x, dw_x + dw_w, rx_yc, "", C_DPARR_FILL, C_DPARR_EDGE,
           double=False, bh=1.2, hh=2.2, hl=1.4)
    harrow(ax, mac_x, ff_x + ff_w, rx_yc, "", C_DPARR_FILL, C_DPARR_EDGE,
           double=False, bh=1.5, hh=2.7, hl=1.6)
    note(ax, (ff_x + ff_w + mac_x) / 2, rx_yc + 5.0, "no\nready", fs=6.2)

    titled_box(ax, cdc_x, tx_y0, cdc_w, tx_h, C_MAC_FILL, C_MAC_EDGE,
               "tx_cdc_fifo", "async AXIS\nFIFO, 512 deep\n100 MHz →\nMAC clk",
               title_fs=8.0, body_fs=6.6, title_dy=2.4)
    titled_box(ax, dw_x, tx_y0, dw_w, tx_h, C_MAC_FILL, C_OPT_EDGE,
               "tx_dwidth", "40G only\n64 → 32 B", title_fs=8.0, body_fs=6.6,
               title_dy=2.4, ls=(0, (4, 2)))
    titled_box(ax, ff_x, tx_y0, ff_w, tx_h, C_FIFO_FILL, C_OPT_EDGE,
               "tx_gate", "40G only: TX frame gate\nafter a MAC-side reset,\n"
               "drops the tail of a\ncut frame",
               title_fs=8.4, body_fs=6.4, title_dy=2.4, ls=(0, (4, 2)))
    harrow(ax, dma_x + dma_w, cdc_x, tx_yc, "MM2S", C_AXARR_FILL, C_AXARR_EDGE,
           double=False, bh=1.5, hh=2.7, hl=1.8, fs=6.8, lab_dy=-4.2)
    harrow(ax, cdc_x + cdc_w, dw_x, tx_yc, "", C_DPARR_FILL, C_DPARR_EDGE,
           double=False, bh=1.2, hh=2.2, hl=1.4)
    harrow(ax, dw_x + dw_w, ff_x, tx_yc, "", C_DPARR_FILL, C_DPARR_EDGE,
           double=False, bh=1.2, hh=2.2, hl=1.4)
    harrow(ax, ff_x + ff_w, mac_x, tx_yc, "", C_DPARR_FILL, C_DPARR_EDGE,
           double=False, bh=1.5, hh=2.7, hl=1.6)

    titled_box(ax, mac_x, tx_y0, mac_w, rx_y0 + rx_h - tx_y0, C_GT_FILL,
               C_GT_EDGE, "MAC",
               "\n100G targets:\nUltraScale+\nIntegrated 100G\nEthernet (CMAC)\n"
               "CAUI-4, no RS-FEC\n512-bit AXIS\n\n40G targets:\n40G/50G Ethernet\n"
               "Subsystem\n40GBASE-R4\n256-bit AXIS\n\nin-core GT quad",
               title_fs=9.2, body_fs=6.6, title_dy=2.8)

    # middle band: QSFP GPIO + drop counters, LEDs
    band_y0, band_y1 = tx_y0 + tx_h, rx_y0
    titled_box(ax, gd_x, band_y0 + 2.0, dw_x + dw_w - gd_x, band_y1 - band_y0 - 4.0,
               C_CTRL_FILL, C_CTRL_EDGE, "axi_gpio_qsfp0  (top level)",
               "CH1 out: [0] ModSelL [1] ResetL [2] LPMode (default 0x2)\n"
               "CH2 in: [0] ModPrsL [1] IntL, [15:2] MAC-error drops,\n"
               "[31:16] other drops (full / oversize / reset)",
               title_fs=7.8, body_fs=6.5, title_dy=2.2)
    route(ax, [(ff_x + 5.0, rx_y0), (ff_x + 5.0, band_y1 - 5.0),
               (dw_x + dw_w, band_y1 - 5.0)], C_DROP, lw=1.4)
    note(ax, ff_x + 12.5, band_y1 - 5.0, "drop\ncounters", fs=6.3,
         color=C_DROP, weight="bold")
    note(ax, ff_x + ff_w / 2, band_y0 + 4.0,
         "MAC RX aligned → green /\nred LEDs on the FMC", fs=6.2)
    gt_right = mac_x + mac_w
    lane_y = (tx_y0 + rx_y0 + rx_h) / 2
    return rx_yc, tx_yc, gt_right, lane_y, cdc_x, ff_x + ff_w, mac_x


def hse_port1(ax, y0, y1, dma_x, dma_w, left_x, right_x, mac_x, mac_w, noc_x,
              hp_label):
    yc = (y0 + y1) / 2
    region(ax, dma_x - 1.0, y0 - 1.0, mac_x + mac_w + 1.0, y1 + 1.0, "",
           "#F7F7F7", C_FAB_EDGE, "#606060", z=1.1)
    titled_box(ax, dma_x, y0, dma_w, y1 - y0, C_DMA_FILL, C_DMA_EDGE, "AXI\nMCDMA",
               "\n\nport 1", title_fs=8.6, body_fs=7.0, txtcolor="#FFFFFF",
               title_dy=4.4)
    harrow(ax, noc_x, dma_x, yc, hp_label, C_AXARR_FILL, C_AXARR_EDGE,
           bh=1.5, hh=2.7, hl=1.4, fs=6.6, lab_dy=4.0)
    titled_box(ax, left_x, y0, right_x - left_x, y1 - y0, C_MAC_FILL, C_MAC_EDGE,
               "QSFP28 port 1 datapath  —  the same chain as port 0",
               "RX: rx_frame_fifo → [rx_dwidth] → rx_cdc_fifo → rx_guard → S2MM\n"
               "TX: MM2S → tx_cdc_fifo → [tx_dwidth → tx_gate]\n"
               "axi_gpio_qsfp1 / axi_iic_qsfp1 at the top level",
               title_fs=8.6, body_fs=7.0, title_dy=2.8)
    harrow(ax, dma_x + dma_w, left_x, yc, "", C_AXARR_FILL, C_AXARR_EDGE,
           bh=1.5, hh=2.7, hl=1.4)
    titled_box(ax, mac_x, y0, mac_w, y1 - y0, C_GT_FILL, C_GT_EDGE, "MAC",
               "\nCMAC or\n40G/50G\nsubsystem", title_fs=9.0, body_fs=6.8,
               title_dy=2.8)
    harrow(ax, right_x, mac_x, yc, "", C_DPARR_FILL, C_DPARR_EDGE, bh=1.5,
           hh=2.7, hl=1.1)
    return yc


def fig_zynqmp():
    fig, ax = new_fig(200, 140)
    top = 116.0
    # ---- PS column -------------------------------------------------------------
    ps_x0, ps_w = 2, 17
    ps_r = ps_x0 + ps_w
    titled_box(ax, ps_x0, 122, ps_w, 12, C_PS_FILL, C_PS_EDGE, "DDR4",
               "PS DDR", title_fs=10.5, body_fs=7.4, title_dy=3.0, lw=1.3)
    box(ax, ps_x0, 4, ps_w, 114, C_PS_FILL, C_PS_EDGE, "", lw=1.3)
    cx = ps_x0 + ps_w / 2
    note(ax, cx, 111.0, "Zynq\nUltraScale+\nPS", fs=11.0, weight="bold",
         color=TXT)
    note(ax, cx, 96.0, "Arm Cortex-A53\n\nLinux:\nxilinx_axienet\n+ HSE support\nand link monitor\n\n"
         "or bare-metal\necho server", fs=7.2, color=TXT)
    note(ax, cx, 50.0, "S_AXI_HP0_FPD\n← port 0 MCDMA\n\nS_AXI_HP1_FPD\n← port 1 MCDMA\n\n"
         "M_AXI_HPM0_LPD\n→ AXI-Lite\n(100 MHz)\n\npl_clk0 100 MHz\n= sys_clk\n\n"
         "pl_ps_irq0[6:0]", fs=6.9, color="#404040")
    varrow(ax, cx, 118.0, 122.0, C_AXARR_FILL, C_AXARR_EDGE, bw=1.2, hw=2.2,
           hl=1.2)

    # ---- fabric ---------------------------------------------------------------
    fab_x0, fab_x1 = 22, 156
    ax.add_patch(plt.Rectangle((fab_x0, 2.5), fab_x1 - fab_x0, 132.0,
                               fc=C_FAB_FILL, ec=C_FAB_EDGE, lw=1.3, zorder=1))
    ax.text((fab_x0 + fab_x1) / 2, 135.1,
            "Zynq UltraScale+ PL  (ZCU102 / ZCU106: 40G on GTH;  "
            "ZCU111 / ZCU208 / ZCU216: 100G CMAC or 40G _ss on GTY)",
            ha="center", va="bottom", fontsize=11.5, weight="bold", color=TXT)
    smc_x, smc_w = 24.0, 4.0
    box(ax, smc_x, 60.0, smc_w, 62.0, C_CTRL_FILL, C_CTRL_EDGE,
        "port 0 axi_smc_hp  (3 → 1)", fs=7.0, rot=90, weight="bold")
    harrow(ax, ps_r, smc_x, 91.0, "HP0", C_AXARR_FILL, C_AXARR_EDGE, bh=1.4,
           hh=2.5, hl=1.0, fs=6.4, lab_dy=4.0)
    dma_x, dma_w = 31.0, 11.0
    rx_yc, tx_yc, gt_right, lane_y, cdc_x, ff_r, mac_x = hse_port0(
        ax, top, dma_x, dma_w, 79.0, fab_x1, )
    for yc in (rx_yc, tx_yc, (rx_yc + tx_yc) / 2):
        harrow(ax, smc_x + smc_w, dma_x, yc, "", C_AXARR_FILL, C_AXARR_EDGE,
               bh=1.2, hh=2.2, hl=1.0)

    p1_yc = hse_port1(ax, 27.5, 47.5, dma_x, dma_w, cdc_x, ff_r, mac_x, 15.0,
                      ps_r, "HP1 (port 1\naxi_smc_hp)")

    # ---- control + clocking strip -----------------------------------------
    harrow(ax, ps_r, 30.0, 13.0, "", C_CTRL_FILL, C_PS_EDGE, double=False,
           bh=1.6, hh=2.9, hl=2.0)
    titled_box(ax, 30.0, 4.0, 72.0, 19.5, C_CTRL_FILL, C_CTRL_EDGE,
               "Control plane: AXI-Lite from M_AXI_HPM0_LPD (axi_smc)",
               "per port: MAC s_axi, MCDMA, axi_gpio_qsfp (sideband + drop counters),\n"
               "axi_iic_qsfp (QSFP module management)\n"
               "shared: axi_iic_clk (Si5328)\n"
               "ZCU102 example: GPIO 0x8000_0000 / 0x8001_0000, MAC 0x8006_0000 / 0x8008_0000",
               title_fs=8.6, body_fs=6.9, title_dy=3.0)
    titled_box(ax, 104.0, 4.0, 51.0, 19.5, C_CLK_FILL, C_CLK_EDGE,
               "Clocking",
               "pl_clk0: 100 MHz sys_clk — AXI-Lite, MCDMA, HP ports\n"
               "MAC client clock from the MAC's own GT quad\n"
               "GT refclk from the FMC Si5328:\n"
               "322.265625 MHz (100G)  /  156.25 MHz (40G)",
               title_fs=8.6, body_fs=6.9, title_dy=3.0)

    fx0, fx1 = 160.0, 181.0
    draw_fmc(ax, fx0, fx1, 134.0, (86.0, 116.0), (27.5, 49.5), (56.0, 79.0),
             "100GBASE-R4 or\n40GBASE-R4", "HPC0 / FMCP",
             "4 × 25.78 / 10.31 Gb/s", "322.27 / 156.25", gt_right, lane_y,
             p1_yc, 158.0)
    draw_tests(ax, 183.0, 199.5, 40.0, 116.0,
               "A: passive QSFP28\nDAC cable\nport 0 ↔ port 1\n→ qsfp-loopback-\ntest",
               "B: link partner\nat the same rate,\nFEC OFF\n\nC: passive\nloopback module\n"
               "→ --single\n\nZCU208 / ZCU216\n100G: port 0 only")
    save(fig, "zynqmp-block-diagram.png")


def fig_microblaze():
    fig, ax = new_fig(200, 140)
    top = 116.0
    ps_x0, ps_w = 2, 17
    ps_r = ps_x0 + ps_w
    titled_box(ax, ps_x0, 122, ps_w, 12, C_PS_FILL, C_PS_EDGE, "DDR4",
               "KCU116 1 GB", title_fs=10.5, body_fs=7.4, title_dy=3.0, lw=1.3)
    # MicroBlaze subsystem drawn inside the fabric, on the left
    fab_x0, fab_x1 = 2, 156
    ax.add_patch(plt.Rectangle((fab_x0, 2.5), fab_x1 - fab_x0, 117.0,
                               fc=C_FAB_FILL, ec=C_FAB_EDGE, lw=1.3, zorder=1))
    ax.text((fab_x0 + fab_x1) / 2, 120.2,
            "Kintex UltraScale+ FPGA  (XCKU5P, KCU116, FMC HPC: DP0-3 only)",
            ha="center", va="bottom", fontsize=12, weight="bold", color=TXT)
    titled_box(ax, ps_x0 + 1.0, 96.0, ps_w - 1.0, 21.0, C_PS_FILL, C_PS_EDGE,
               "DDR4 MIG", "ddr4_0\n300 MHz ui_clk\naddn_ui_clkout1\n= 100 MHz\nsys_clk",
               title_fs=8.6, body_fs=6.7, title_dy=2.6)
    varrow(ax, cx := ps_x0 + ps_w / 2 + 0.5, 117.0, 122.0, C_AXARR_FILL,
           C_AXARR_EDGE, bw=1.2, hw=2.2, hl=1.2)
    titled_box(ax, ps_x0 + 1.0, 30.0, ps_w - 1.0, 62.0, C_PS_FILL, C_PS_EDGE,
               "MicroBlaze",
               "\nMMU, caches\n64 KB local\nmemory\n\nbare-metal\necho server\n"
               "(no Linux flow)\n\naxi_intc\naxi_timer\naxi_uart16550\n(USB-UART,\n"
               "115200)\naxi_quad_spi\n(config flash\nvia STARTUPE3)\nreset_gpio",
               title_fs=9.4, body_fs=6.7, title_dy=2.8)
    smc_x, smc_w = 21.5, 4.0
    box(ax, smc_x, 60.0, smc_w, 62.0, C_CTRL_FILL, C_CTRL_EDGE,
        "axi_smc → MIG", fs=7.0, rot=90, weight="bold")
    harrow(ax, ps_r, smc_x, 106.0, "", C_AXARR_FILL, C_AXARR_EDGE, bh=1.2,
           hh=2.2, hl=1.0)
    dma_x, dma_w = 29.0, 11.0
    rx_yc, tx_yc, gt_right, lane_y, cdc_x, ff_r, mac_x = hse_port0(
        ax, top - 4.0, dma_x, dma_w, 77.0, fab_x1)
    for yc in (rx_yc, tx_yc, (rx_yc + tx_yc) / 2):
        harrow(ax, smc_x + smc_w, dma_x, yc, "", C_AXARR_FILL, C_AXARR_EDGE,
               bh=1.2, hh=2.2, hl=1.0)
    # single port: note instead of port 1
    titled_box(ax, cdc_x, 27.5, ff_r - cdc_x, 18.0, C_CTRL_FILL, C_CTRL_EDGE,
               "Single port",
               "the KCU116 FMC HPC wires only DP0-3, so these targets have\n"
               "one QSFP28 port: kcu116 = 100G CMAC (CMACE4_X0Y0, the KU5P's only\n"
               "CMAC), kcu116_ss = 40G/50G subsystem; QSFP28 port 1 is held in reset",
               title_fs=8.6, body_fs=6.9, title_dy=2.8)
    harrow(ax, ps_r, smc_x, 70.0, "", C_AXARR_FILL, C_AXARR_EDGE, bh=1.2,
           hh=2.2, hl=1.0)
    note(ax, ps_r + 1.2, 74.5, "DC/IC", fs=5.8)
    route(ax, [(ps_x0 + ps_w / 2, 30.0), (ps_x0 + ps_w / 2, 13.0), (29.0, 13.0)],
          C_PS_EDGE, lw=1.8)
    note(ax, 21.0, 15.5, "M_AXI_DP", fs=6.0)
    titled_box(ax, 29.0, 4.0, 73.0, 19.5, C_CTRL_FILL, C_CTRL_EDGE,
               "Control plane: AXI-Lite (microblaze_0_axi_periph)",
               "MAC 0x44A3_0000, MCDMA 0x44A2_0000, axi_gpio_qsfp0 0x4000_0000\n"
               "axi_iic_qsfp0 0x4081_0000, axi_iic_clk (Si5328) 0x4080_0000\n"
               "UART16550 0x44A1_0000, QSPI 0x44A0_0000, timer, intc",
               title_fs=8.6, body_fs=6.9, title_dy=3.0)
    titled_box(ax, 104.0, 4.0, 51.0, 19.5, C_CLK_FILL, C_CLK_EDGE, "Clocking",
               "MIG addn_ui_clkout1: 100 MHz sys_clk\n"
               "addn_ui_clkout2: 50 MHz QSPI ext_spi_clk\n"
               "GT refclk from the FMC Si5328:\n"
               "322.265625 MHz (kcu116) / 156.25 MHz (kcu116_ss)",
               title_fs=8.6, body_fs=6.9, title_dy=3.0)
    fx0, fx1 = 160.0, 181.0
    draw_fmc(ax, fx0, fx1, 134.0, (82.0, 112.0), (27.5, 49.5), (55.0, 77.0),
             "100GBASE-R4 or\n40GBASE-R4", "HPC", "4 lanes", "322.27 / 156.25",
             gt_right, lane_y, 38.0, 158.0, single_port=True)
    draw_tests(ax, 183.0, 199.5, 50.0, 112.0,
               "passive QSFP28\nloopback module,\nor a link partner\nat the same rate\n"
               "with FEC OFF",
               "echo server:\nARP, ping,\nUDP echo\n192.168.10.10")
    save(fig, "microblaze-block-diagram.png")


def main():
    fig_versal()
    fig_zynqmp()
    fig_microblaze()


if __name__ == "__main__":
    main()
