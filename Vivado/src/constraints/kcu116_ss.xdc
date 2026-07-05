#---------------------------------------------------------------------
# Constraints for Opsero 2x QSFP28 FMC ref design for KCU116 (HPC)
# 40G Ethernet subsystem (_ss) variant
#
# Single QSFP28 port at 40G (40GBASE-R4 l_ethernet soft MAC):
#   port 0 = FMC slot 0 / DP0-3 (GTY bank 227, quad X0Y12-15, Quad_X0Y3)
# The KCU116 FMC HPC connector wires only DP0-3 (one GTY quad), so QSFP
# slot 1 of the FMC cannot be connected on this board: the QSFP1 module is
# held in reset / low-power via constant drivers.
# The l_ethernet soft MAC has no hard-block placement restriction; the GT
# quad is selected with GT_GROUP_SELECT Quad_X0Y3 (4 lanes x 10.3125 Gb/s,
# refclk 156.25 MHz).
# GT serial pins are listed in GT channel order (lane [i] = channel i of the
# quad); the FMC DP number of each lane is noted in the comment.
# MicroBlaze system I/O (DDR4, UART, sys clock, reset) comes from the KCU116
# board files via block-design board automation - not constrained here.
#---------------------------------------------------------------------

#####################
# Si5328 clock generator I2C (shared)
#####################
set_property PACKAGE_PIN Y17 [get_ports clk_i2c_scl_io]; # LA02_P
set_property PACKAGE_PIN AA17 [get_ports clk_i2c_sda_io]; # LA02_N
set_property IOSTANDARD LVCMOS18 [get_ports clk_i2c_*]
set_property SLEW SLOW [get_ports clk_i2c_*]
set_property DRIVE 4 [get_ports clk_i2c_*]

# QSFP0 module I2C
set_property PACKAGE_PIN AB17 [get_ports qsfp0_i2c_scl_io]; # LA03_P
set_property PACKAGE_PIN AC17 [get_ports qsfp0_i2c_sda_io]; # LA03_N

set_property IOSTANDARD LVCMOS18 [get_ports qsfp*_i2c_*]
set_property SLEW SLOW [get_ports qsfp*_i2c_*]
set_property DRIVE 4 [get_ports qsfp*_i2c_*]

#####################
# GT reference clock (from the FMC Si5328)
#####################
set_property PACKAGE_PIN K7 [get_ports gt_ref_clk_0_clk_p*]; # GBTCLK0_M2C_P (bank 227)

#############
# QSFP SLOT 0 (port 0) - DP0-3, GTY bank 227 (quad X0Y12-15)
#############

# Gigabit transceivers (4 lanes -> 1x40GbE 40GBASE-R4)
set_property PACKAGE_PIN F7 [get_ports {qsfp0_gt_gtx_p[0]}]; # DP0_C2M_P (ch0)
set_property PACKAGE_PIN F6 [get_ports {qsfp0_gt_gtx_n[0]}]; # DP0_C2M_N
set_property PACKAGE_PIN D2 [get_ports {qsfp0_gt_grx_p[0]}]; # DP0_M2C_P
set_property PACKAGE_PIN D1 [get_ports {qsfp0_gt_grx_n[0]}]; # DP0_M2C_N

set_property PACKAGE_PIN E5 [get_ports {qsfp0_gt_gtx_p[1]}]; # DP1_C2M_P (ch1)
set_property PACKAGE_PIN E4 [get_ports {qsfp0_gt_gtx_n[1]}]; # DP1_C2M_N
set_property PACKAGE_PIN C4 [get_ports {qsfp0_gt_grx_p[1]}]; # DP1_M2C_P
set_property PACKAGE_PIN C3 [get_ports {qsfp0_gt_grx_n[1]}]; # DP1_M2C_N

set_property PACKAGE_PIN D7 [get_ports {qsfp0_gt_gtx_p[2]}]; # DP2_C2M_P (ch2)
set_property PACKAGE_PIN D6 [get_ports {qsfp0_gt_gtx_n[2]}]; # DP2_C2M_N
set_property PACKAGE_PIN B2 [get_ports {qsfp0_gt_grx_p[2]}]; # DP2_M2C_P
set_property PACKAGE_PIN B1 [get_ports {qsfp0_gt_grx_n[2]}]; # DP2_M2C_N

set_property PACKAGE_PIN B7 [get_ports {qsfp0_gt_gtx_p[3]}]; # DP3_C2M_P (ch3)
set_property PACKAGE_PIN B6 [get_ports {qsfp0_gt_gtx_n[3]}]; # DP3_C2M_N
set_property PACKAGE_PIN A4 [get_ports {qsfp0_gt_grx_p[3]}]; # DP3_M2C_P
set_property PACKAGE_PIN A3 [get_ports {qsfp0_gt_grx_n[3]}]; # DP3_M2C_N

# QSFP slot 0: module I/O and User LEDs
set_property PACKAGE_PIN AA20 [get_ports {modsell_qsfp0[0]}]; # LA04_P
set_property PACKAGE_PIN AB20 [get_ports {resetl_qsfp0[0]}]; # LA04_N
set_property PACKAGE_PIN AC22 [get_ports modprsl_qsfp0]; # LA12_P
set_property PACKAGE_PIN AC23 [get_ports intl_qsfp0]; # LA12_N
set_property PACKAGE_PIN Y18 [get_ports {lpmode_qsfp0[0]}]; # LA11_P
set_property PACKAGE_PIN AD16 [get_ports grn_led_qsfp0]; # LA07_P
set_property PACKAGE_PIN AE16 [get_ports {red_led_qsfp0[0]}]; # LA07_N

#############
# QSFP SLOT 1 (port 1) - NOT CONNECTED on KCU116 (held in reset / low-power)
#############
set_property PACKAGE_PIN AB24 [get_ports {modsell_qsfp1[0]}]; # LA15_P
set_property PACKAGE_PIN AC24 [get_ports {resetl_qsfp1[0]}]; # LA15_N
set_property PACKAGE_PIN AA18 [get_ports {lpmode_qsfp1[0]}]; # LA11_N
set_property PACKAGE_PIN AE17 [get_ports {grn_led_qsfp1[0]}]; # LA08_P
set_property PACKAGE_PIN AF17 [get_ports {red_led_qsfp1[0]}]; # LA08_N

# QSFP module I/O IOSTANDARDs (both slots)
set_property IOSTANDARD LVCMOS18 [get_ports modsell_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports resetl_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports modprsl_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports intl_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports lpmode_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports grn_led_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports red_led_qsfp*]

#####################
# Bitstream / QSPI flash boot
#####################
# The boot.mcs flash image must fit bitstream + u-boot + kernel/initramfs in
# the 32MB QSPI: compression shrinks the ~15.4MB uncompressed KU5P bitstream
# to fit the flash partition table (see PetaLinux/bsp/kcu116). The SPI
# properties configure the FPGA to boot from the flash in x4 mode (required
# by the SPIx4 MCS that petalinux-package generates).
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES [current_design]
