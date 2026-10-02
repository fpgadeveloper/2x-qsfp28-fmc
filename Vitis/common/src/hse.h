/*
 * hse.h — Bare-metal bring-up for the "high speed ethernet" MACs of the
 * 2x QSFP28 FMC designs: the UltraScale+ Integrated 100G Ethernet (CMAC,
 * PG203) and the 40G/50G High Speed Ethernet Subsystem (l_ethernet, PG211).
 *
 * Opsero 2x QSFP28 FMC reference design.
 */

#ifndef HSE_H_
#define HSE_H_

#include "xil_types.h"

/* MAC flavour: the two cores share the GT-reset / TX-RX-enable register
 * template but differ beyond it (see hse.c). */
#define HSE_CMAC   0
#define HSE_LETH   1

void hse_init(UINTPTR base, int is_leth);
void hse_gt_reset(UINTPTR base);
int  hse_link_up(UINTPTR base, int is_leth);

#endif /* HSE_H_ */
