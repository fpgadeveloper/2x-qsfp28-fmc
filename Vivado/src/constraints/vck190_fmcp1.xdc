#---------------------------------------------------------------------
# Constraints for Opsero 2x QSFP28 FMC ref design for VCK190-FMCP1
#
# Phase 1: single QSFP28 port (port 0), 1x100GbE (CAUI-4) MRMAC.
# Port 1 (slot 1) pins are added in Phase 2.
#---------------------------------------------------------------------

# Si5328 I2C signals (jitter-attenuating clock generator)
set_property PACKAGE_PIN AW24 [get_ports clk_i2c_scl_io]; # LA02_P
set_property PACKAGE_PIN AY25 [get_ports clk_i2c_sda_io]; # LA02_N
set_property IOSTANDARD LVCMOS15 [get_ports clk_i2c_*]
set_property SLEW SLOW [get_ports clk_i2c_*]
set_property DRIVE 4 [get_ports clk_i2c_*]

# QSFP0 I2C signals
set_property PACKAGE_PIN AV22 [get_ports qsfp0_i2c_scl_io]; # LA03_P
set_property PACKAGE_PIN AW21 [get_ports qsfp0_i2c_sda_io]; # LA03_N
set_property IOSTANDARD LVCMOS15 [get_ports qsfp0_i2c_*]
set_property SLEW SLOW [get_ports qsfp0_i2c_*]
set_property DRIVE 4 [get_ports qsfp0_i2c_*]

#####################
# GT reference clock
#####################

# GT ref CLKOUT1 from the 2x QSFP28 FMC Si5328
set_property PACKAGE_PIN M15 [get_ports {gt_ref_clk_0_clk_p[0]}]; # GBTCLK0_M2C_P

#############
# QSFP SLOT 0
#############

# QSFP slot 0: Gigabit transceivers (4 lanes -> 1x100GbE CAUI-4)
set_property PACKAGE_PIN AB7 [get_ports {qsfp_gt_gtx_p[0]}]; # DP0_C2M_P
set_property PACKAGE_PIN AB6 [get_ports {qsfp_gt_gtx_n[0]}]; # DP0_C2M_N
set_property PACKAGE_PIN AB2 [get_ports {qsfp_gt_grx_p[0]}]; # DP0_M2C_P
set_property PACKAGE_PIN AB1 [get_ports {qsfp_gt_grx_n[0]}]; # DP0_M2C_N

set_property PACKAGE_PIN AA9 [get_ports {qsfp_gt_gtx_p[1]}]; # DP1_C2M_P
set_property PACKAGE_PIN AA8 [get_ports {qsfp_gt_gtx_n[1]}]; # DP1_C2M_N
set_property PACKAGE_PIN AA4 [get_ports {qsfp_gt_grx_p[1]}]; # DP1_M2C_P
set_property PACKAGE_PIN AA3 [get_ports {qsfp_gt_grx_n[1]}]; # DP1_M2C_N

set_property PACKAGE_PIN Y7 [get_ports {qsfp_gt_gtx_p[2]}]; # DP2_C2M_P
set_property PACKAGE_PIN Y6 [get_ports {qsfp_gt_gtx_n[2]}]; # DP2_C2M_N
set_property PACKAGE_PIN Y2 [get_ports {qsfp_gt_grx_p[2]}]; # DP2_M2C_P
set_property PACKAGE_PIN Y1 [get_ports {qsfp_gt_grx_n[2]}]; # DP2_M2C_N

set_property PACKAGE_PIN W9 [get_ports {qsfp_gt_gtx_p[3]}]; # DP3_C2M_P
set_property PACKAGE_PIN W8 [get_ports {qsfp_gt_gtx_n[3]}]; # DP3_C2M_N
set_property PACKAGE_PIN W4 [get_ports {qsfp_gt_grx_p[3]}]; # DP3_M2C_P
set_property PACKAGE_PIN W3 [get_ports {qsfp_gt_grx_n[3]}]; # DP3_M2C_N

# QSFP slot 0: QSFP module I/O and User LEDs
set_property PACKAGE_PIN AU21 [get_ports {modsell_qsfp0[0]}]; # LA04_P
set_property PACKAGE_PIN AV21 [get_ports {resetl_qsfp0[0]}]; # LA04_N
set_property PACKAGE_PIN BG21 [get_ports modprsl_qsfp0]; # LA12_P
set_property PACKAGE_PIN BF22 [get_ports intl_qsfp0]; # LA12_N
set_property PACKAGE_PIN BF23 [get_ports {lpmode_qsfp0[0]}]; # LA11_P
set_property PACKAGE_PIN BC25 [get_ports grn_led_qsfp0]; # LA07_P
set_property PACKAGE_PIN BD25 [get_ports {red_led_qsfp0[0]}]; # LA07_N

# QSFP I/O IOSTANDARDs
set_property IOSTANDARD LVCMOS15 [get_ports modsell_qsfp0*]
set_property IOSTANDARD LVCMOS15 [get_ports resetl_qsfp0*]
set_property IOSTANDARD LVCMOS15 [get_ports modprsl_qsfp0]
set_property IOSTANDARD LVCMOS15 [get_ports intl_qsfp0]
set_property IOSTANDARD LVCMOS15 [get_ports lpmode_qsfp0*]
set_property IOSTANDARD LVCMOS15 [get_ports grn_led_qsfp0]
set_property IOSTANDARD LVCMOS15 [get_ports red_led_qsfp0*]
