/*
 * mrmac.c — Bare-metal MRMAC (1x100GE CAUI-4) bring-up for the
 * 2x QSFP28 FMC Versal designs.
 *
 * Opsero 2x QSFP28 FMC reference design.
 *
 * There is no embeddedsw driver for the Versal MRMAC hard block, so this
 * module drives its registers directly. Offsets, bits and sequence
 * replicate the Linux xilinx_axienet driver's MRMAC support at
 * max-speed = 100000 (the same path this design's PetaLinux/Yocto flows
 * use), which in turn follows PG314. Each QSFP port has its own MRMAC in
 * 1x100GE mode, so only the port-0 register page (offset 0) of each block
 * is used — port_base below is the MRMAC's s_axi base address.
 *
 * The bring-up per port:
 *   1. one-time GT reset through the port's GT-control AXI GPIO
 *      (channel 1: bit0 = gt_reset_all, bit1/bit2 = TX/RX datapath resets;
 *       channel 2: bit0/bit1 = TX/RX reset-done), then a TX and an RX
 *      datapath reset pulse — same order as the Linux driver. The rate
 *      GPIO bits (3-4) are unconnected spares in this design (the GT quad
 *      is statically configured for 25.78125 Gb/s) and are not driven.
 *   2. assert the MAC's TX/RX serdes + core resets
 *   3. program the MODE register for 100G: DATA_RATE = 100G, AXIS client
 *      config = independent 384-bit, serdes width = 100G "Wide"
 *   4. release the resets
 *   5. enable TX (with FCS insertion) and RX (with FCS deletion)
 *
 * Link state: RX block lock + RX status good (sticky, write-1-to-clear).
 * The 10G/25G "RX valid control code" cross-check does not apply at 100G.
 */

#include <stdio.h>
#include "xil_printf.h"
#include "xil_io.h"
#include "xgpio.h"
#include "sleep.h"
#include "mrmac.h"

/* Register offsets (PG314 / Linux xilinx_axienet.h), port-0 page */
#define MRMAC_RESET_OFFSET         0x00000004
#define MRMAC_MODE_OFFSET          0x00000008
#define MRMAC_CONFIG_TX_OFFSET     0x0000000C
#define MRMAC_CONFIG_RX_OFFSET     0x00000010
#define MRMAC_TICK_OFFSET          0x0000002C
#define MRMAC_TX_STS_OFFSET        0x00000740
#define MRMAC_RX_STS_OFFSET        0x00000744
#define MRMAC_STATRX_BLKLCK_OFFSET 0x00000754

/* RESET register */
#define MRMAC_RX_SERDES_RST_MASK   (0xF << 0)
#define MRMAC_TX_SERDES_RST_MASK   (1 << 4)
#define MRMAC_RX_RST_MASK          (1 << 5)
#define MRMAC_TX_RST_MASK          (1 << 6)

/* MODE register, 100G values (Linux axienet_mrmac_reset, max-speed 100000;
 * serdes width "Wide" — the design's DT sets no gt-mode-narrow) */
#define MRMAC_CTL_DATA_RATE_MASK   0x7
#define MRMAC_CTL_DATA_RATE_100G   4
#define MRMAC_CTL_AXIS_CFG_MASK    (0x7 << 9)
#define MRMAC_CTL_AXIS_CFG_SHIFT   9
#define MRMAC_CTL_AXIS_CFG_100G_IND_384    5
#define MRMAC_CTL_SERDES_WIDTH_MASK  (0x7 << 4)
#define MRMAC_CTL_SERDES_WIDTH_SHIFT 4
#define MRMAC_CTL_SERDES_WIDTH_100G_WIDE   6
#define MRMAC_CTL_RATE_CFG_MASK    (MRMAC_CTL_DATA_RATE_MASK | \
                                    MRMAC_CTL_AXIS_CFG_MASK | \
                                    MRMAC_CTL_SERDES_WIDTH_MASK)
#define MRMAC_CTL_PM_TICK_MASK     (1u << 30)

/* CONFIG_TX / CONFIG_RX registers */
#define MRMAC_TX_EN_MASK           (1 << 0)
#define MRMAC_TX_INS_FCS_MASK      (1 << 1)
#define MRMAC_RX_EN_MASK           (1 << 0)
#define MRMAC_RX_DEL_FCS_MASK      (1 << 1)

/* Status bits (sticky: write-1-to-clear, then read) */
#define MRMAC_STS_ALL_MASK         0xFFFFFFFF
#define MRMAC_RX_BLKLCK_MASK       (1 << 0)
#define MRMAC_RX_STATUS_MASK       (1 << 0)

#define MRMAC_TICK_TRIGGER         (1 << 0)

/* GT-control GPIO: channel 1 outputs (5 bits), channel 2 inputs (2 bits) */
#define GT_CTRL_RESET_ALL          (1 << 0)
#define GT_CTRL_RESET_TX_DPATH     (1 << 1)
#define GT_CTRL_RESET_RX_DPATH     (1 << 2)
#define GT_DONE_TX                 (1 << 0)
#define GT_DONE_RX                 (1 << 1)

static inline u32 rd(UINTPTR base, u32 off)        { return Xil_In32(base + off); }
static inline void wr(UINTPTR base, u32 off, u32 v) { Xil_Out32(base + off, v); }

/*
 * One-time GT bring-up through the port's GT-control GPIO: pulse
 * gt_reset_all, wait for TX+RX reset-done, then pulse the TX and RX
 * datapath resets (Linux axienet_mrmac_gt_reset order). As per PG314 the
 * all-lane GT reset must only be issued once after power-on; the MAC
 * core/serdes reset (mrmac_port_init) is what gets repeated to re-attempt
 * lock. Returns 0 on success, -1 if reset-done did not assert.
 */
int mrmac_gt_reset(UINTPTR gpio_base)
{
	XGpio gpio;
	XGpio_Config *cfg;
	u32 done = 0;
	int timeout = 100; /* x 10ms */

	cfg = XGpio_LookupConfig(gpio_base);
	if (cfg == NULL)
		return -1;
	XGpio_CfgInitialize(&gpio, cfg, cfg->BaseAddress);

	/* Pulse gt_reset_all */
	XGpio_DiscreteWrite(&gpio, 1, GT_CTRL_RESET_ALL);
	usleep(1000);
	XGpio_DiscreteWrite(&gpio, 1, 0);

	/* Wait for tx/rx reset done */
	do {
		done = XGpio_DiscreteRead(&gpio, 2);
		if ((done & (GT_DONE_TX | GT_DONE_RX)) == (GT_DONE_TX | GT_DONE_RX))
			break;
		usleep(10000);
	} while (--timeout);
	if (!timeout) {
		xil_printf("mrmac: GT reset-done timeout (done=0x%02x)\r\n",
			   (unsigned)done);
		return -1;
	}

	/* TX then RX datapath reset pulses, 1ms apart (as the Linux driver) */
	XGpio_DiscreteWrite(&gpio, 1, GT_CTRL_RESET_TX_DPATH);
	usleep(1000);
	XGpio_DiscreteWrite(&gpio, 1, 0);
	usleep(1000);
	XGpio_DiscreteWrite(&gpio, 1, GT_CTRL_RESET_RX_DPATH);
	usleep(1000);
	XGpio_DiscreteWrite(&gpio, 1, 0);
	usleep(1000);

	return 0;
}

/*
 * Reset and configure one MRMAC (axienet_mrmac_reset equivalent, 100G).
 */
void mrmac_port_init(UINTPTR port_base)
{
	u32 val, reg;

	/* Assert serdes + core resets */
	val = rd(port_base, MRMAC_RESET_OFFSET);
	val |= (MRMAC_RX_SERDES_RST_MASK | MRMAC_TX_SERDES_RST_MASK |
		MRMAC_RX_RST_MASK | MRMAC_TX_RST_MASK);
	wr(port_base, MRMAC_RESET_OFFSET, val);
	usleep(1000);

	/* Rate / AXIS configuration / serdes width: 100G, IND 384-bit, Wide */
	reg = rd(port_base, MRMAC_MODE_OFFSET);
	reg &= ~MRMAC_CTL_RATE_CFG_MASK;
	reg |= MRMAC_CTL_DATA_RATE_100G;
	reg |= (MRMAC_CTL_AXIS_CFG_100G_IND_384 << MRMAC_CTL_AXIS_CFG_SHIFT);
	reg |= (MRMAC_CTL_SERDES_WIDTH_100G_WIDE << MRMAC_CTL_SERDES_WIDTH_SHIFT);
	reg |= MRMAC_CTL_PM_TICK_MASK;
	wr(port_base, MRMAC_MODE_OFFSET, reg);

	/* Release resets */
	val = rd(port_base, MRMAC_RESET_OFFSET);
	val &= ~(MRMAC_RX_SERDES_RST_MASK | MRMAC_TX_SERDES_RST_MASK |
		 MRMAC_RX_RST_MASK | MRMAC_TX_RST_MASK);
	wr(port_base, MRMAC_RESET_OFFSET, val);

	/* Enable TX (insert FCS) and RX (delete FCS) */
	wr(port_base, MRMAC_CONFIG_TX_OFFSET, MRMAC_TX_EN_MASK | MRMAC_TX_INS_FCS_MASK);
	wr(port_base, MRMAC_CONFIG_RX_OFFSET, MRMAC_RX_EN_MASK | MRMAC_RX_DEL_FCS_MASK);

	/* Latch the statistics counters once so they start clean */
	wr(port_base, MRMAC_TICK_OFFSET, MRMAC_TICK_TRIGGER);
}

/*
 * Return 1 if the port has RX block lock AND RX status good (link up).
 * The status registers are sticky: write-1-to-clear, then read the live state.
 */
int mrmac_port_link_up(UINTPTR port_base)
{
	u32 blklck, rxsts;

	wr(port_base, MRMAC_STATRX_BLKLCK_OFFSET, MRMAC_STS_ALL_MASK);
	blklck = rd(port_base, MRMAC_STATRX_BLKLCK_OFFSET);
	if (!(blklck & MRMAC_RX_BLKLCK_MASK))
		return 0;

	wr(port_base, MRMAC_RX_STS_OFFSET, MRMAC_STS_ALL_MASK);
	rxsts = rd(port_base, MRMAC_RX_STS_OFFSET);
	return !!(rxsts & MRMAC_RX_STATUS_MASK);
}
