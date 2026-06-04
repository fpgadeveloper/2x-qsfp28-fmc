#---------------------------------------------------------------------
# Constraints for Opsero 2x QSFP28 FMC ref design for VCK190-FMCP1
#
# Phase 2: both QSFP28 ports (port 0 = FMC slot 0 / DP0-3, port 1 = FMC slot 1
# / DP4-7), each a 1x100GbE (CAUI-4) MRMAC.
#---------------------------------------------------------------------

#####################
# Si5328 clock generator I2C (shared)
#####################
set_property PACKAGE_PIN AW24 [get_ports clk_i2c_scl_io]; # LA02_P
set_property PACKAGE_PIN AY25 [get_ports clk_i2c_sda_io]; # LA02_N
set_property IOSTANDARD LVCMOS15 [get_ports clk_i2c_*]
set_property SLEW SLOW [get_ports clk_i2c_*]
set_property DRIVE 4 [get_ports clk_i2c_*]

# QSFP0 module I2C
set_property PACKAGE_PIN AV22 [get_ports qsfp0_i2c_scl_io]; # LA03_P
set_property PACKAGE_PIN AW21 [get_ports qsfp0_i2c_sda_io]; # LA03_N

# QSFP1 module I2C
set_property PACKAGE_PIN BB16 [get_ports qsfp1_i2c_scl_io]; # LA17_CC_P
set_property PACKAGE_PIN BC16 [get_ports qsfp1_i2c_sda_io]; # LA17_CC_N

set_property IOSTANDARD LVCMOS15 [get_ports qsfp*_i2c_*]
set_property SLEW SLOW [get_ports qsfp*_i2c_*]
set_property DRIVE 4 [get_ports qsfp*_i2c_*]

#####################
# GT reference clocks (from the FMC Si5328)
#####################
set_property PACKAGE_PIN M15 [get_ports {gt_ref_clk_0_clk_p[0]}]; # GBTCLK0_M2C_P
set_property PACKAGE_PIN K15 [get_ports {gt_ref_clk_1_clk_p[0]}]; # GBTCLK1_M2C_P

#############
# QSFP SLOT 0 (port 0) - DP0-3
#############

# Gigabit transceivers (4 lanes -> 1x100GbE CAUI-4)
set_property PACKAGE_PIN AB7 [get_ports {qsfp0_gt_gtx_p[0]}]; # DP0_C2M_P
set_property PACKAGE_PIN AB6 [get_ports {qsfp0_gt_gtx_n[0]}]; # DP0_C2M_N
set_property PACKAGE_PIN AB2 [get_ports {qsfp0_gt_grx_p[0]}]; # DP0_M2C_P
set_property PACKAGE_PIN AB1 [get_ports {qsfp0_gt_grx_n[0]}]; # DP0_M2C_N

set_property PACKAGE_PIN AA9 [get_ports {qsfp0_gt_gtx_p[1]}]; # DP1_C2M_P
set_property PACKAGE_PIN AA8 [get_ports {qsfp0_gt_gtx_n[1]}]; # DP1_C2M_N
set_property PACKAGE_PIN AA4 [get_ports {qsfp0_gt_grx_p[1]}]; # DP1_M2C_P
set_property PACKAGE_PIN AA3 [get_ports {qsfp0_gt_grx_n[1]}]; # DP1_M2C_N

set_property PACKAGE_PIN Y7 [get_ports {qsfp0_gt_gtx_p[2]}]; # DP2_C2M_P
set_property PACKAGE_PIN Y6 [get_ports {qsfp0_gt_gtx_n[2]}]; # DP2_C2M_N
set_property PACKAGE_PIN Y2 [get_ports {qsfp0_gt_grx_p[2]}]; # DP2_M2C_P
set_property PACKAGE_PIN Y1 [get_ports {qsfp0_gt_grx_n[2]}]; # DP2_M2C_N

set_property PACKAGE_PIN W9 [get_ports {qsfp0_gt_gtx_p[3]}]; # DP3_C2M_P
set_property PACKAGE_PIN W8 [get_ports {qsfp0_gt_gtx_n[3]}]; # DP3_C2M_N
set_property PACKAGE_PIN W4 [get_ports {qsfp0_gt_grx_p[3]}]; # DP3_M2C_P
set_property PACKAGE_PIN W3 [get_ports {qsfp0_gt_grx_n[3]}]; # DP3_M2C_N

# QSFP slot 0: module I/O and User LEDs
set_property PACKAGE_PIN AU21 [get_ports {modsell_qsfp0[0]}]; # LA04_P
set_property PACKAGE_PIN AV21 [get_ports {resetl_qsfp0[0]}]; # LA04_N
set_property PACKAGE_PIN BG21 [get_ports modprsl_qsfp0]; # LA12_P
set_property PACKAGE_PIN BF22 [get_ports intl_qsfp0]; # LA12_N
set_property PACKAGE_PIN BF23 [get_ports {lpmode_qsfp0[0]}]; # LA11_P
set_property PACKAGE_PIN BC25 [get_ports grn_led_qsfp0]; # LA07_P
set_property PACKAGE_PIN BD25 [get_ports {red_led_qsfp0[0]}]; # LA07_N

#############
# QSFP SLOT 1 (port 1) - DP4-7
#############

# Gigabit transceivers (4 lanes -> 1x100GbE CAUI-4)
set_property PACKAGE_PIN V7 [get_ports {qsfp1_gt_gtx_p[0]}]; # DP4_C2M_P
set_property PACKAGE_PIN V6 [get_ports {qsfp1_gt_gtx_n[0]}]; # DP4_C2M_N
set_property PACKAGE_PIN V2 [get_ports {qsfp1_gt_grx_p[0]}]; # DP4_M2C_P
set_property PACKAGE_PIN V1 [get_ports {qsfp1_gt_grx_n[0]}]; # DP4_M2C_N

set_property PACKAGE_PIN U9 [get_ports {qsfp1_gt_gtx_p[1]}]; # DP5_C2M_P
set_property PACKAGE_PIN U8 [get_ports {qsfp1_gt_gtx_n[1]}]; # DP5_C2M_N
set_property PACKAGE_PIN U4 [get_ports {qsfp1_gt_grx_p[1]}]; # DP5_M2C_P
set_property PACKAGE_PIN U3 [get_ports {qsfp1_gt_grx_n[1]}]; # DP5_M2C_N

set_property PACKAGE_PIN T7 [get_ports {qsfp1_gt_gtx_p[2]}]; # DP6_C2M_P
set_property PACKAGE_PIN T6 [get_ports {qsfp1_gt_gtx_n[2]}]; # DP6_C2M_N
set_property PACKAGE_PIN T2 [get_ports {qsfp1_gt_grx_p[2]}]; # DP6_M2C_P
set_property PACKAGE_PIN T1 [get_ports {qsfp1_gt_grx_n[2]}]; # DP6_M2C_N

set_property PACKAGE_PIN R9 [get_ports {qsfp1_gt_gtx_p[3]}]; # DP7_C2M_P
set_property PACKAGE_PIN R8 [get_ports {qsfp1_gt_gtx_n[3]}]; # DP7_C2M_N
set_property PACKAGE_PIN R4 [get_ports {qsfp1_gt_grx_p[3]}]; # DP7_M2C_P
set_property PACKAGE_PIN R3 [get_ports {qsfp1_gt_grx_n[3]}]; # DP7_M2C_N

# QSFP slot 1: module I/O and User LEDs
set_property PACKAGE_PIN AY22 [get_ports {modsell_qsfp1[0]}]; # LA15_P
set_property PACKAGE_PIN AY23 [get_ports {resetl_qsfp1[0]}]; # LA15_N
set_property PACKAGE_PIN BF24 [get_ports modprsl_qsfp1]; # LA05_P
set_property PACKAGE_PIN BG23 [get_ports intl_qsfp1]; # LA05_N
set_property PACKAGE_PIN BE22 [get_ports {lpmode_qsfp1[0]}]; # LA11_N
set_property PACKAGE_PIN BC22 [get_ports grn_led_qsfp1]; # LA08_P
set_property PACKAGE_PIN BC21 [get_ports {red_led_qsfp1[0]}]; # LA08_N

# QSFP module I/O IOSTANDARDs (both slots)
set_property IOSTANDARD LVCMOS15 [get_ports modsell_qsfp*]
set_property IOSTANDARD LVCMOS15 [get_ports resetl_qsfp*]
set_property IOSTANDARD LVCMOS15 [get_ports modprsl_qsfp*]
set_property IOSTANDARD LVCMOS15 [get_ports intl_qsfp*]
set_property IOSTANDARD LVCMOS15 [get_ports lpmode_qsfp*]
set_property IOSTANDARD LVCMOS15 [get_ports grn_led_qsfp*]
set_property IOSTANDARD LVCMOS15 [get_ports red_led_qsfp*]
