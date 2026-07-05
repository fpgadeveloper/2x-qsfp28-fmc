#---------------------------------------------------------------------
# Constraints for Opsero 2x QSFP28 FMC ref design for ZCU111 (FMCP)
# 40G Ethernet subsystem (_ss) variant
#
# Both QSFP28 ports, each a 1x40GbE (40GBASE-R4) l_ethernet soft MAC:
#   port 0 = FMC slot 0 / DP0-3 (GTY bank 129, quad X0Y8-11,  Quad_X0Y2)
#   port 1 = FMC slot 1 / DP4-7 (GTY bank 130, quad X0Y12-15, Quad_X0Y3)
# Same pinout as the 100G CMAC target (zcu111); only the MAC and the GT
# line rate differ (4 lanes x 10.3125 Gb/s, refclk 156.25 MHz).
# GT serial pins are listed in GT channel order (lane [i] = channel i of the
# quad); the FMC DP number of each lane is noted in the comment. Ethernet
# multi-lane PCS tolerates the lane permutation.
#---------------------------------------------------------------------

#####################
# Si5328 clock generator I2C (shared)
#####################
set_property PACKAGE_PIN AH13 [get_ports clk_i2c_scl_io]; # LA02_P
set_property PACKAGE_PIN AJ13 [get_ports clk_i2c_sda_io]; # LA02_N
set_property IOSTANDARD LVCMOS18 [get_ports clk_i2c_*]
set_property SLEW SLOW [get_ports clk_i2c_*]
set_property DRIVE 4 [get_ports clk_i2c_*]

# QSFP0 module I2C
set_property PACKAGE_PIN AJ12 [get_ports qsfp0_i2c_scl_io]; # LA03_P
set_property PACKAGE_PIN AK12 [get_ports qsfp0_i2c_sda_io]; # LA03_N

# QSFP1 module I2C
set_property PACKAGE_PIN AN21 [get_ports qsfp1_i2c_scl_io]; # LA17_CC_P
set_property PACKAGE_PIN AP21 [get_ports qsfp1_i2c_sda_io]; # LA17_CC_N

set_property IOSTANDARD LVCMOS18 [get_ports qsfp*_i2c_*]
set_property SLEW SLOW [get_ports qsfp*_i2c_*]
set_property DRIVE 4 [get_ports qsfp*_i2c_*]

#####################
# GT reference clocks (from the FMC Si5328)
#####################
set_property PACKAGE_PIN W33 [get_ports gt_ref_clk_0_clk_p*]; # GBTCLK0_M2C_P (bank 129)
set_property PACKAGE_PIN U33 [get_ports gt_ref_clk_1_clk_p*]; # GBTCLK1_M2C_P (bank 130)

#############
# QSFP SLOT 0 (port 0) - DP0-3, GTY bank 129 (quad X0Y8-11)
#############

# Gigabit transceivers (4 lanes -> 1x40GbE 40GBASE-R4)
set_property PACKAGE_PIN P35 [get_ports {qsfp0_gt_gtx_p[0]}]; # DP0_C2M_P (ch0)
set_property PACKAGE_PIN P36 [get_ports {qsfp0_gt_gtx_n[0]}]; # DP0_C2M_N
set_property PACKAGE_PIN N38 [get_ports {qsfp0_gt_grx_p[0]}]; # DP0_M2C_P
set_property PACKAGE_PIN N39 [get_ports {qsfp0_gt_grx_n[0]}]; # DP0_M2C_N

set_property PACKAGE_PIN N33 [get_ports {qsfp0_gt_gtx_p[1]}]; # DP1_C2M_P (ch1)
set_property PACKAGE_PIN N34 [get_ports {qsfp0_gt_gtx_n[1]}]; # DP1_C2M_N
set_property PACKAGE_PIN M36 [get_ports {qsfp0_gt_grx_p[1]}]; # DP1_M2C_P
set_property PACKAGE_PIN M37 [get_ports {qsfp0_gt_grx_n[1]}]; # DP1_M2C_N

set_property PACKAGE_PIN L33 [get_ports {qsfp0_gt_gtx_p[2]}]; # DP2_C2M_P (ch2)
set_property PACKAGE_PIN L34 [get_ports {qsfp0_gt_gtx_n[2]}]; # DP2_C2M_N
set_property PACKAGE_PIN L38 [get_ports {qsfp0_gt_grx_p[2]}]; # DP2_M2C_P
set_property PACKAGE_PIN L39 [get_ports {qsfp0_gt_grx_n[2]}]; # DP2_M2C_N

set_property PACKAGE_PIN J33 [get_ports {qsfp0_gt_gtx_p[3]}]; # DP3_C2M_P (ch3)
set_property PACKAGE_PIN J34 [get_ports {qsfp0_gt_gtx_n[3]}]; # DP3_C2M_N
set_property PACKAGE_PIN K36 [get_ports {qsfp0_gt_grx_p[3]}]; # DP3_M2C_P
set_property PACKAGE_PIN K37 [get_ports {qsfp0_gt_grx_n[3]}]; # DP3_M2C_N

# QSFP slot 0: module I/O and User LEDs
set_property PACKAGE_PIN AG12 [get_ports {modsell_qsfp0[0]}]; # LA04_P
set_property PACKAGE_PIN AH12 [get_ports {resetl_qsfp0[0]}]; # LA04_N
set_property PACKAGE_PIN AL10 [get_ports modprsl_qsfp0]; # LA12_P
set_property PACKAGE_PIN AM10 [get_ports intl_qsfp0]; # LA12_N
set_property PACKAGE_PIN AT10 [get_ports {lpmode_qsfp0[0]}]; # LA11_P
set_property PACKAGE_PIN AK13 [get_ports grn_led_qsfp0]; # LA07_P
set_property PACKAGE_PIN AL12 [get_ports {red_led_qsfp0[0]}]; # LA07_N

#############
# QSFP SLOT 1 (port 1) - DP4-7, GTY bank 130 (quad X0Y12-15)
#############

# Gigabit transceivers (4 lanes -> 1x40GbE 40GBASE-R4)
set_property PACKAGE_PIN H31 [get_ports {qsfp1_gt_gtx_p[0]}]; # DP4_C2M_P (ch0)
set_property PACKAGE_PIN H32 [get_ports {qsfp1_gt_gtx_n[0]}]; # DP4_C2M_N
set_property PACKAGE_PIN J38 [get_ports {qsfp1_gt_grx_p[0]}]; # DP4_M2C_P
set_property PACKAGE_PIN J39 [get_ports {qsfp1_gt_grx_n[0]}]; # DP4_M2C_N

set_property PACKAGE_PIN G33 [get_ports {qsfp1_gt_gtx_p[1]}]; # DP5_C2M_P (ch1)
set_property PACKAGE_PIN G34 [get_ports {qsfp1_gt_gtx_n[1]}]; # DP5_C2M_N
set_property PACKAGE_PIN H36 [get_ports {qsfp1_gt_grx_p[1]}]; # DP5_M2C_P
set_property PACKAGE_PIN H37 [get_ports {qsfp1_gt_grx_n[1]}]; # DP5_M2C_N

set_property PACKAGE_PIN F31 [get_ports {qsfp1_gt_gtx_p[2]}]; # DP6_C2M_P (ch2)
set_property PACKAGE_PIN F32 [get_ports {qsfp1_gt_gtx_n[2]}]; # DP6_C2M_N
set_property PACKAGE_PIN G38 [get_ports {qsfp1_gt_grx_p[2]}]; # DP6_M2C_P
set_property PACKAGE_PIN G39 [get_ports {qsfp1_gt_grx_n[2]}]; # DP6_M2C_N

set_property PACKAGE_PIN E33 [get_ports {qsfp1_gt_gtx_p[3]}]; # DP7_C2M_P (ch3)
set_property PACKAGE_PIN E34 [get_ports {qsfp1_gt_gtx_n[3]}]; # DP7_C2M_N
set_property PACKAGE_PIN F36 [get_ports {qsfp1_gt_grx_p[3]}]; # DP7_M2C_P
set_property PACKAGE_PIN F37 [get_ports {qsfp1_gt_grx_n[3]}]; # DP7_M2C_N

# QSFP slot 1: module I/O and User LEDs
set_property PACKAGE_PIN AJ14 [get_ports {modsell_qsfp1[0]}]; # LA15_P
set_property PACKAGE_PIN AK14 [get_ports {resetl_qsfp1[0]}]; # LA15_N
set_property PACKAGE_PIN AM8 [get_ports modprsl_qsfp1]; # LA05_P
set_property PACKAGE_PIN AM7 [get_ports intl_qsfp1]; # LA05_N
set_property PACKAGE_PIN AU10 [get_ports {lpmode_qsfp1[0]}]; # LA11_N
set_property PACKAGE_PIN AL9 [get_ports grn_led_qsfp1]; # LA08_P
set_property PACKAGE_PIN AM9 [get_ports {red_led_qsfp1[0]}]; # LA08_N

# QSFP module I/O IOSTANDARDs (both slots)
set_property IOSTANDARD LVCMOS18 [get_ports modsell_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports resetl_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports modprsl_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports intl_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports lpmode_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports grn_led_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports red_led_qsfp*]
