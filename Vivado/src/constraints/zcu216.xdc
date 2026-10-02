#---------------------------------------------------------------------
# Constraints for Opsero 2x QSFP28 FMC ref design for ZCU216 (FMCP)
#
# Single QSFP28 port at 100G (CAUI-4 CMAC):
#   port 0 = FMC slot 0 / DP0-3 (GTY bank 130, quad X0Y12-15, CMACE4_X0Y1)
# Port 1 (DP4-7, bank 131 / quad X0Y16-19) is UNUSED: on the ZU49DR only
# CMACE4_X0Y1 can reach the FMC+ quads (CMACE4_X0Y0 is restricted to quads
# X0Y4-11), so a second 100G port is not possible. The QSFP1 module is held
# in reset / low-power via constant drivers.
#---------------------------------------------------------------------

#####################
# Si5328 clock generator I2C (shared)
#####################
set_property PACKAGE_PIN A29 [get_ports clk_i2c_scl_io]; # LA02_P
set_property PACKAGE_PIN A30 [get_ports clk_i2c_sda_io]; # LA02_N
set_property IOSTANDARD LVCMOS18 [get_ports clk_i2c_*]
set_property SLEW SLOW [get_ports clk_i2c_*]
set_property DRIVE 4 [get_ports clk_i2c_*]

# QSFP0 module I2C
set_property PACKAGE_PIN B30 [get_ports qsfp0_i2c_scl_io]; # LA03_P
set_property PACKAGE_PIN B31 [get_ports qsfp0_i2c_sda_io]; # LA03_N

set_property IOSTANDARD LVCMOS18 [get_ports qsfp*_i2c_*]
set_property SLEW SLOW [get_ports qsfp*_i2c_*]
set_property DRIVE 4 [get_ports qsfp*_i2c_*]

#####################
# GT reference clock (from the FMC Si5328)
#####################
set_property PACKAGE_PIN P34 [get_ports gt_ref_clk_0_clk_p*]; # GBTCLK0_M2C_P (bank 130)

#############
# QSFP SLOT 0 (port 0) - DP0-3, GTY bank 130 (quad X0Y12-15)
#############

# Gigabit transceivers (4 lanes -> 1x100GbE CAUI-4)
set_property PACKAGE_PIN K38 [get_ports {qsfp0_gt_gtx_p[0]}]; # DP0_C2M_P (ch0)
set_property PACKAGE_PIN K39 [get_ports {qsfp0_gt_gtx_n[0]}]; # DP0_C2M_N
set_property PACKAGE_PIN L41 [get_ports {qsfp0_gt_grx_p[0]}]; # DP0_M2C_P
set_property PACKAGE_PIN L42 [get_ports {qsfp0_gt_grx_n[0]}]; # DP0_M2C_N

set_property PACKAGE_PIN J36 [get_ports {qsfp0_gt_gtx_p[1]}]; # DP1_C2M_P (ch1)
set_property PACKAGE_PIN J37 [get_ports {qsfp0_gt_gtx_n[1]}]; # DP1_C2M_N
set_property PACKAGE_PIN J41 [get_ports {qsfp0_gt_grx_p[1]}]; # DP1_M2C_P
set_property PACKAGE_PIN J42 [get_ports {qsfp0_gt_grx_n[1]}]; # DP1_M2C_N

set_property PACKAGE_PIN H38 [get_ports {qsfp0_gt_gtx_p[2]}]; # DP2_C2M_P (ch2)
set_property PACKAGE_PIN H39 [get_ports {qsfp0_gt_gtx_n[2]}]; # DP2_C2M_N
set_property PACKAGE_PIN G41 [get_ports {qsfp0_gt_grx_p[2]}]; # DP2_M2C_P
set_property PACKAGE_PIN G42 [get_ports {qsfp0_gt_grx_n[2]}]; # DP2_M2C_N

set_property PACKAGE_PIN G36 [get_ports {qsfp0_gt_gtx_p[3]}]; # DP3_C2M_P (ch3)
set_property PACKAGE_PIN G37 [get_ports {qsfp0_gt_gtx_n[3]}]; # DP3_C2M_N
set_property PACKAGE_PIN F39 [get_ports {qsfp0_gt_grx_p[3]}]; # DP3_M2C_P
set_property PACKAGE_PIN F40 [get_ports {qsfp0_gt_grx_n[3]}]; # DP3_M2C_N

# QSFP slot 0: module I/O and User LEDs
set_property PACKAGE_PIN B32 [get_ports {modsell_qsfp0[0]}]; # LA04_P
set_property PACKAGE_PIN A32 [get_ports {resetl_qsfp0[0]}]; # LA04_N
set_property PACKAGE_PIN K29 [get_ports modprsl_qsfp0]; # LA12_P
set_property PACKAGE_PIN J29 [get_ports intl_qsfp0]; # LA12_N
set_property PACKAGE_PIN L25 [get_ports {lpmode_qsfp0[0]}]; # LA11_P
set_property PACKAGE_PIN C30 [get_ports grn_led_qsfp0]; # LA07_P
set_property PACKAGE_PIN C31 [get_ports {red_led_qsfp0[0]}]; # LA07_N

#############
# QSFP SLOT 1 (port 1) - UNUSED (held in reset / low-power)
#############
set_property PACKAGE_PIN B28 [get_ports {modsell_qsfp1[0]}]; # LA15_P
set_property PACKAGE_PIN A28 [get_ports {resetl_qsfp1[0]}]; # LA15_N
set_property PACKAGE_PIN K25 [get_ports {lpmode_qsfp1[0]}]; # LA11_N
set_property PACKAGE_PIN D29 [get_ports {grn_led_qsfp1[0]}]; # LA08_P
set_property PACKAGE_PIN C29 [get_ports {red_led_qsfp1[0]}]; # LA08_N

# QSFP module I/O IOSTANDARDs (both slots)
set_property IOSTANDARD LVCMOS18 [get_ports modsell_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports resetl_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports modprsl_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports intl_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports lpmode_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports grn_led_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports red_led_qsfp*]
