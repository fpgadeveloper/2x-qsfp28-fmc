/*
 * hse.c — Bare-metal bring-up for the 100G CMAC / 40G l_ethernet MACs
 *
 * Opsero 2x QSFP28 FMC reference design.
 *
 * There is no embeddedsw driver for either core, so this module drives
 * their registers directly. The offsets, bits and sequence replicate the
 * Linux xilinx_axienet HSE support carried in this design's PetaLinux/Yocto
 * BSPs (0002-net-axienet-add-hse-cmac-l-ethernet-support.patch and its
 * fixes), which is the same code the design's Linux images use:
 *
 *  - Both cores share one register template for GT reset (GT_RESET_REG,
 *    0x0000, bit 0) and TX/RX enable + FCS controls (CONFIGURATION_TX/RX,
 *    0x000C/0x0014, bit 0 = enable, bit 1 = FCS insert/delete).
 *  - Beyond that they differ: the CMAC (PG203) has RX status at 0x0204 and
 *    the statistics tick at 0x02B0; the l_ethernet (PG211) has RX status at
 *    0x0404 and the tick at 0x0020 (verified against the generated
 *    l_ethernet AXI4-Lite RTL and on zcu106_hpc0 hardware).
 *  - The l_ethernet AXI4-Lite decoder answers undefined offsets with SLVERR
 *    and comes out of reset with the SLVERR-indication enables SET
 *    (MODE_REG[1:0]) — on the Cortex-A53 that arrives as an asynchronous
 *    SError and is fatal. Clear MODE_REG first, before touching anything
 *    else, so racing/timed-out status reads return the 0xBADBAD00 marker
 *    (treated as link-down) instead of a bus error. Touch ONLY defined
 *    offsets on this core.
 *  - The RX status bits are latched-low, cleared on read: a single read
 *    returns the history of the interval (which, while the link is down,
 *    always includes our own GT reset pulse). Read twice — the first read
 *    flushes the latch, the second samples the current state. Without this
 *    the link never comes up (reset -> align -> read stale low -> reset).
 */

#include "xil_io.h"
#include "sleep.h"
#include "hse.h"

/* Shared register template (XXV MAC offsets, same bit positions) */
#define HSE_GT_RESET_OFFSET        0x00000000
#define HSE_CFG_TX_OFFSET          0x0000000C
#define HSE_CFG_RX_OFFSET          0x00000014

#define HSE_GT_RESET_MASK          (1 << 0)
#define HSE_TX_EN_MASK             (1 << 0)
#define HSE_TX_INS_FCS_MASK        (1 << 1)
#define HSE_RX_EN_MASK             (1 << 0)
#define HSE_RX_DEL_FCS_MASK        (1 << 1)

/* 100G CMAC (PG203) */
#define HSE_CMAC_STAT_RX_OFFSET    0x00000204
#define HSE_CMAC_TICK_OFFSET       0x000002B0

/* 40G/50G High Speed Ethernet Subsystem (l_ethernet, PG211) */
#define HSE_LETH_MODE_OFFSET       0x00000008
#define HSE_LETH_TICK_OFFSET       0x00000020
#define HSE_LETH_STAT_RX_OFFSET    0x00000404

#define HSE_RX_STATUS_MASK         (1 << 0)   /* stat_rx_status  */
#define HSE_RX_ALIGNED_MASK        (1 << 1)   /* stat_rx_aligned */
#define HSE_TICK_TRIGGER           (1 << 0)

static inline u32 rd(UINTPTR base, u32 off)        { return Xil_In32(base + off); }
static inline void wr(UINTPTR base, u32 off, u32 v) { Xil_Out32(base + off, v); }

/*
 * Pulse the in-core GT reset (all lanes). Used once at init and then
 * repeatedly while the link is down to re-attempt RX alignment — the GT
 * does not re-align on a partner signal (or reference clock) that appears
 * after our last reset. Same as the Linux driver's xxv_gt_reset().
 */
void hse_gt_reset(UINTPTR base)
{
	u32 val;

	val = rd(base, HSE_GT_RESET_OFFSET);
	wr(base, HSE_GT_RESET_OFFSET, val | HSE_GT_RESET_MASK);
	usleep(1000);           /* 1 ms per spec */
	val = rd(base, HSE_GT_RESET_OFFSET);
	wr(base, HSE_GT_RESET_OFFSET, val & ~HSE_GT_RESET_MASK);
}

/*
 * One-time MAC configuration: TX enable (+FCS insert), RX enable (+FCS
 * delete), statistics tick, then a first GT reset pulse. On l_ethernet the
 * SLVERR-indication enables are cleared FIRST (see header comment).
 */
void hse_init(UINTPTR base, int is_leth)
{
	if (is_leth)
		wr(base, HSE_LETH_MODE_OFFSET, 0);

	wr(base, HSE_CFG_TX_OFFSET, HSE_TX_EN_MASK | HSE_TX_INS_FCS_MASK);
	wr(base, HSE_CFG_RX_OFFSET, HSE_RX_EN_MASK | HSE_RX_DEL_FCS_MASK);

	/* Latch the statistics counters once so they start clean */
	wr(base, is_leth ? HSE_LETH_TICK_OFFSET : HSE_CMAC_TICK_OFFSET,
	   HSE_TICK_TRIGGER);

	hse_gt_reset(base);
}

/*
 * Return 1 if RX status good AND RX aligned. Latched-low, cleared-on-read
 * register: read twice, judge from the second read. A read that races the
 * GT clock bring-up on l_ethernet returns 0xBADBAD00 (bits 1:0 = 0), which
 * correctly reads as link-down.
 */
int hse_link_up(UINTPTR base, int is_leth)
{
	u32 off = is_leth ? HSE_LETH_STAT_RX_OFFSET : HSE_CMAC_STAT_RX_OFFSET;
	u32 val;

	(void)rd(base, off);    /* flush the latch */
	val = rd(base, off);
	return (val & HSE_RX_STATUS_MASK) && (val & HSE_RX_ALIGNED_MASK);
}
