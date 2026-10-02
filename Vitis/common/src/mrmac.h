/*
 * mrmac.h — Bare-metal MRMAC (1x100GE CAUI-4) bring-up for the
 * 2x QSFP28 FMC Versal designs.
 *
 * Opsero 2x QSFP28 FMC reference design.
 */

#ifndef MRMAC_H_
#define MRMAC_H_

#include "xil_types.h"

int  mrmac_gt_reset(UINTPTR gpio_base);
void mrmac_port_init(UINTPTR port_base);
int  mrmac_port_link_up(UINTPTR port_base);

#endif /* MRMAC_H_ */
