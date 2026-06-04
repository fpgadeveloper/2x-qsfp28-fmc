#!/usr/bin/env python3
"""
Generate the block diagram for the Opsero 2x QSFP28 FMC reference design docs.

The design has two QSFP28 ports, each a single 1x100GbE (CAUI-4) MRMAC with an
AXI MCDMA datapath to DDR via the Versal NoC. The Si5328 jitter-attenuating
clock generator lives on the FMC card; its two outputs (GBTCLK0/GBTCLK1) come
through the FMC connector to clock each GT quad's reference-clock input.

The output PNG is written next to this script (i.e. into docs/source/images/):
    versal-mrmac-100g-block-diagram.png

Usage (from anywhere):
    python3 docs/source/images/gen_block_diagram.py
"""

import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, FancyBboxPatch, FancyArrowPatch

# ---- palette (sampled to match the sfp28-fmc-xxv block diagrams) -------------
C_PS_FILL      = "#D9D9D9"; C_PS_EDGE      = "#7F7F7F"   # PS / NoC column
C_FAB_FILL     = "#F2F2F2"; C_FAB_EDGE     = "#BFBFBF"   # FPGA fabric container
C_DMA_FILL     = "#808080"; C_DMA_EDGE     = "#404040"   # AXI MCDMA (dark grey)
C_BRIDGE_FILL  = "#D6D6D6"; C_BRIDGE_EDGE  = "#7F7F7F"   # datapath bridge (grey)
C_MAC_FILL     = "#E8E8F2"; C_MAC_EDGE     = "#8C8CC0"   # MRMAC (lavender)
C_GT_FILL      = "#F3EFE2"; C_GT_EDGE      = "#BFB585"   # GT quad (cream)
C_FMC_FILL     = "#DCE6F2"; C_FMC_EDGE     = "#9DB7D4"   # external FMC (blue-grey)
C_CAGE_FILL    = "#FFFFFF"                                # QSFP cage (white on FMC)
C_CLK_FILL     = "#FDE9D9"; C_CLK_EDGE     = "#E0B090"   # Si5328 (peach)
C_CTRL_FILL    = "#ECECEC"; C_CTRL_EDGE    = "#BFBFBF"   # control-plane caption
C_AXARR_FILL   = "#EDF3D4"; C_AXARR_EDGE   = "#A6B85A"   # data arrows (pale green)
C_LINKARR_FILL = "#DAE8F5"; C_LINKARR_EDGE = "#6F9FCF"   # link arrows (pale blue)
C_REFCLK_LINE  = "#C8823C"                                # refclk arrows (orange)
TXT = "#1A1A1A"


def box(ax, x, y, w, h, fc, ec, label, fs=10, rot=0, lw=1.2, weight="normal",
        round_=False, txtcolor=None):
    if round_:
        p = FancyBboxPatch((x + 0.4, y + 0.4), w - 0.8, h - 0.8,
                           boxstyle="round,pad=0.0,rounding_size=1.2",
                           fc=fc, ec=ec, lw=lw, zorder=2)
    else:
        p = plt.Rectangle((x, y), w, h, fc=fc, ec=ec, lw=lw, zorder=2)
    ax.add_patch(p)
    ax.text(x + w / 2, y + h / 2, label, ha="center", va="center",
            fontsize=fs, rotation=rot, color=txtcolor or TXT, weight=weight,
            zorder=3, linespacing=1.25)


def harrow(ax, x0, x1, yc, label, fc, ec, double=True, bh=2.0, hh=3.4, hl=3.2,
           fs=8.5, lw=1.1, lab_dy=0.0):
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
                fontsize=fs, color=TXT, zorder=3, linespacing=1.15)


def refclk_arrow(ax, p0, p1, label, lab_xy, fs=7.8, lw=1.9):
    """Thin single-line arrow (head at p1) for a single clock net, at any angle.

    A reference clock is one net (not a wide bus), so a thin arrow distinguishes
    it from the fat AXI/AXIS/CAUI-4 bus arrows.
    """
    ax.add_patch(FancyArrowPatch(p0, p1, arrowstyle="-|>", mutation_scale=13,
                                 lw=lw, color=C_REFCLK_LINE, zorder=3,
                                 shrinkA=0, shrinkB=0))
    ax.text(lab_xy[0], lab_xy[1], label, ha="center", va="center",
            fontsize=fs, color=C_REFCLK_LINE, zorder=4, weight="bold")


def main():
    fig, ax = plt.subplots(figsize=(15.0, 8.4), dpi=120)
    ax.set_xlim(0, 150)
    ax.set_ylim(0, 86)
    ax.axis("off")

    # ---- containers ----------------------------------------------------------
    # PS / NoC column
    box(ax, 3, 6, 17, 74, C_PS_FILL, C_PS_EDGE,
        "Versal PS\n(CIPS)\n\n+\n\nNoC\n+\nDDR4", fs=11, weight="bold")
    # FPGA fabric container
    fab_x0, fab_x1 = 22, 118
    ax.add_patch(plt.Rectangle((fab_x0, 4), fab_x1 - fab_x0, 78,
                               fc=C_FAB_FILL, ec=C_FAB_EDGE, lw=1.3, zorder=1))
    ax.text((fab_x0 + fab_x1) / 2, 83.2, "FPGA Fabric (PL)", ha="center",
            va="bottom", fontsize=13, weight="bold", color=TXT)
    # External FMC block (carries the two QSFP28 cages AND the Si5328 clock gen)
    fmc_x0, fmc_x1 = 126, 146
    ax.add_patch(plt.Rectangle((fmc_x0, 6), fmc_x1 - fmc_x0, 74,
                               fc=C_FMC_FILL, ec=C_FMC_EDGE, lw=1.3, zorder=1))
    ax.text((fmc_x0 + fmc_x1) / 2, 83.2, "External to Versal", ha="center",
            va="bottom", fontsize=12, weight="bold", color=TXT)
    ax.text((fmc_x0 + fmc_x1) / 2, 76.0, "2x QSFP28 FMC\n(OP120)", ha="center",
            va="center", fontsize=11, weight="bold", color=TXT)

    # ---- column x-coordinates (shared by both port rows) ---------------------
    dma_x, dma_w     = 29, 15
    br_x,  br_w      = 52, 19
    mac_x, mac_w     = 79, 15
    gt_x,  gt_w      = 101, 11
    box_h = 19

    rows = [("0", 56), ("1", 14)]   # (port label, box bottom y)
    gt_right = gt_x + gt_w

    # ---- FMC sub-blocks: a QSFP28 cage per port + the shared Si5328 ----------
    sub_x, sub_w = 129, 14
    for plabel, by in rows:
        yc = by + box_h / 2
        box(ax, sub_x, yc - 8, sub_w, 16, C_CAGE_FILL, C_FMC_EDGE,
            "QSFP%s\ncage" % plabel, fs=9.5, weight="bold")
    si_yc = ((rows[0][1] + box_h / 2) + (rows[1][1] + box_h / 2)) / 2  # 44.5
    box(ax, sub_x, si_yc - 7.5, sub_w, 15, C_CLK_FILL, C_CLK_EDGE,
        "Si5328\nclock gen\n322.26 MHz", fs=8.2)

    # ---- per-port datapath rows ----------------------------------------------
    for plabel, by in rows:
        yc = by + box_h / 2
        # NoC <-> MCDMA  (3x AXI)
        harrow(ax, 20, dma_x, yc, "3x AXI\nSG/MM2S/S2MM\n512-bit",
               C_AXARR_FILL, C_AXARR_EDGE, lab_dy=0.2)
        # AXI MCDMA
        box(ax, dma_x, by, dma_w, box_h, C_DMA_FILL, C_DMA_EDGE,
            "AXI\nMCDMA", fs=11, weight="bold", txtcolor="#FFFFFF")
        # MCDMA <-> bridge (AXIS 512b)
        harrow(ax, dma_x + dma_w, br_x, yc, "AXIS\n512-bit",
               C_AXARR_FILL, C_AXARR_EDGE, lab_dy=0.2)
        # datapath bridge
        box(ax, br_x, by, br_w, box_h, C_BRIDGE_FILL, C_BRIDGE_EDGE,
            "CDC FIFO\n+ width conv\n(512<->384b)\n+ MRMAC client\nAXIS adapter", fs=8.6)
        # bridge <-> MRMAC (AXIS client 384b)
        harrow(ax, br_x + br_w, mac_x, yc, "AXIS\nclient\n384-bit",
               C_AXARR_FILL, C_AXARR_EDGE, lab_dy=0.2)
        # MRMAC
        box(ax, mac_x, by, mac_w, box_h, C_MAC_FILL, C_MAC_EDGE,
            "MRMAC\n1x100GbE\nCAUI-4", fs=10.5, weight="bold")
        # MRMAC <-> GT quad : TX (->, into GT) and RX (<-, into MRMAC)
        harrow(ax, mac_x + mac_w, gt_x, yc + 4.4, "TX", C_AXARR_FILL,
               C_AXARR_EDGE, double=False, bh=1.4, hh=2.5, hl=2.6, fs=8.5, lab_dy=4.0)
        harrow(ax, gt_x, mac_x + mac_w, yc - 4.4, "RX", C_AXARR_FILL,
               C_AXARR_EDGE, double=False, bh=1.4, hh=2.5, hl=2.6, fs=8.5, lab_dy=-4.0)
        # GT quad
        box(ax, gt_x, by, gt_w, box_h, C_GT_FILL, C_GT_EDGE,
            "GT Quad\n(GTY)\n\n4 lanes\n@ 25.78\nGb/s", fs=8.6, weight="bold")
        # GT quad -> QSFP cage : CAUI-4 link (pale blue, double headed)
        harrow(ax, gt_right, fmc_x0, yc, "CAUI-4\n4 lanes\nQSFP%s" % plabel,
               C_LINKARR_FILL, C_LINKARR_EDGE, bh=2.6, hh=4.2, hl=4.0,
               fs=8.8, lab_dy=0.2)

    # ---- GBTCLK reference clocks: Si5328 (on the FMC) -> each GT quad ---------
    # The clocks come through the FMC connector and clock each GT's refclk input.
    refclk_arrow(ax, (sub_x, si_yc + 4.5), (gt_right, 58), "GBTCLK0", (119.5, 57.0))
    refclk_arrow(ax, (sub_x, si_yc - 4.5), (gt_right, 31), "GBTCLK1", (119.5, 32.0))

    # ---- control-plane caption strip -----------------------------------------
    box(ax, 24, 5.5, 64, 4.4, C_CTRL_FILL, C_CTRL_EDGE,
        "AXI-Lite control  |  AXI-IIC (Si5328 clock + per-port QSFP mgmt)  "
        "|  GT-control GPIO  |  user LEDs (link status)", fs=8.2)

    out = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "versal-mrmac-100g-block-diagram.png")
    fig.savefig(out, bbox_inches="tight", pad_inches=0.15, facecolor="white")
    print("wrote", out)


if __name__ == "__main__":
    main()
