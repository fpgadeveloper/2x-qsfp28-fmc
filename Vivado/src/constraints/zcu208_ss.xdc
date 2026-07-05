#---------------------------------------------------------------------
# Constraints for Opsero 2x QSFP28 FMC ref design for ZCU208 (FMCP)
# 40G Ethernet subsystem (_ss) variant
#
# Both QSFP28 ports, each a 1x40GbE (40GBASE-R4) l_ethernet soft MAC:
#   port 0 = FMC slot 0 / DP0-3 (GTY bank 130, quad X0Y12-15, Quad_X0Y3)
#   port 1 = FMC slot 1 / DP4-7 (GTY bank 131, quad X0Y16-19, Quad_X0Y4)
# Unlike the 100G CMAC target (zcu208, single-port because only CMACE4_X0Y1
# reaches the FMC+ quads), the soft MAC has no CMAC placement restriction,
# so this variant enables BOTH QSFP28 ports (4 lanes x 10.3125 Gb/s each,
# refclk 156.25 MHz).
# GT serial pins are listed in GT channel order (lane [i] = channel i of the
# quad); the FMC DP number of each lane is noted in the comment. Ethernet
# multi-lane PCS tolerates the lane permutation.
#---------------------------------------------------------------------

#####################
# Si5328 clock generator I2C (shared)
#####################
set_property PACKAGE_PIN A20 [get_ports clk_i2c_scl_io]; # LA02_P
set_property PACKAGE_PIN A21 [get_ports clk_i2c_sda_io]; # LA02_N
set_property IOSTANDARD LVCMOS18 [get_ports clk_i2c_*]
set_property SLEW SLOW [get_ports clk_i2c_*]
set_property DRIVE 4 [get_ports clk_i2c_*]

# QSFP0 module I2C
set_property PACKAGE_PIN C21 [get_ports qsfp0_i2c_scl_io]; # LA03_P
set_property PACKAGE_PIN C22 [get_ports qsfp0_i2c_sda_io]; # LA03_N

# QSFP1 module I2C
set_property PACKAGE_PIN AL16 [get_ports qsfp1_i2c_scl_io]; # LA17_CC_P
set_property PACKAGE_PIN AL15 [get_ports qsfp1_i2c_sda_io]; # LA17_CC_N

set_property IOSTANDARD LVCMOS18 [get_ports qsfp*_i2c_*]
set_property SLEW SLOW [get_ports qsfp*_i2c_*]
set_property DRIVE 4 [get_ports qsfp*_i2c_*]

#####################
# GT reference clocks (from the FMC Si5328)
#####################
set_property PACKAGE_PIN U33 [get_ports gt_ref_clk_0_clk_p*]; # GBTCLK0_M2C_P (bank 130)
set_property PACKAGE_PIN P31 [get_ports gt_ref_clk_1_clk_p*]; # GBTCLK1_M2C_P (bank 131)

#############
# QSFP SLOT 0 (port 0) - DP0-3, GTY bank 130 (quad X0Y12-15)
#############

# Gigabit transceivers (4 lanes -> 1x40GbE 40GBASE-R4)
set_property PACKAGE_PIN H31 [get_ports {qsfp0_gt_gtx_p[0]}]; # DP0_C2M_P (ch0)
set_property PACKAGE_PIN H32 [get_ports {qsfp0_gt_gtx_n[0]}]; # DP0_C2M_N
set_property PACKAGE_PIN J38 [get_ports {qsfp0_gt_grx_p[0]}]; # DP0_M2C_P
set_property PACKAGE_PIN J39 [get_ports {qsfp0_gt_grx_n[0]}]; # DP0_M2C_N

set_property PACKAGE_PIN G33 [get_ports {qsfp0_gt_gtx_p[1]}]; # DP1_C2M_P (ch1)
set_property PACKAGE_PIN G34 [get_ports {qsfp0_gt_gtx_n[1]}]; # DP1_C2M_N
set_property PACKAGE_PIN H36 [get_ports {qsfp0_gt_grx_p[1]}]; # DP1_M2C_P
set_property PACKAGE_PIN H37 [get_ports {qsfp0_gt_grx_n[1]}]; # DP1_M2C_N

set_property PACKAGE_PIN F31 [get_ports {qsfp0_gt_gtx_p[2]}]; # DP2_C2M_P (ch2)
set_property PACKAGE_PIN F32 [get_ports {qsfp0_gt_gtx_n[2]}]; # DP2_C2M_N
set_property PACKAGE_PIN G38 [get_ports {qsfp0_gt_grx_p[2]}]; # DP2_M2C_P
set_property PACKAGE_PIN G39 [get_ports {qsfp0_gt_grx_n[2]}]; # DP2_M2C_N

set_property PACKAGE_PIN E33 [get_ports {qsfp0_gt_gtx_p[3]}]; # DP3_C2M_P (ch3)
set_property PACKAGE_PIN E34 [get_ports {qsfp0_gt_gtx_n[3]}]; # DP3_C2M_N
set_property PACKAGE_PIN F36 [get_ports {qsfp0_gt_grx_p[3]}]; # DP3_M2C_P
set_property PACKAGE_PIN F37 [get_ports {qsfp0_gt_grx_n[3]}]; # DP3_M2C_N

# QSFP slot 0: module I/O and User LEDs
set_property PACKAGE_PIN C20 [get_ports {modsell_qsfp0[0]}]; # LA04_P
set_property PACKAGE_PIN B20 [get_ports {resetl_qsfp0[0]}]; # LA04_N
set_property PACKAGE_PIN J21 [get_ports modprsl_qsfp0]; # LA12_P
set_property PACKAGE_PIN H21 [get_ports intl_qsfp0]; # LA12_N
set_property PACKAGE_PIN L19 [get_ports {lpmode_qsfp0[0]}]; # LA11_P
set_property PACKAGE_PIN C23 [get_ports grn_led_qsfp0]; # LA07_P
set_property PACKAGE_PIN B23 [get_ports {red_led_qsfp0[0]}]; # LA07_N

#############
# QSFP SLOT 1 (port 1) - DP4-7, GTY bank 131 (quad X0Y16-19)
#############

# Gigabit transceivers (4 lanes -> 1x40GbE 40GBASE-R4)
set_property PACKAGE_PIN D31 [get_ports {qsfp1_gt_gtx_p[0]}]; # DP4_C2M_P (ch0)
set_property PACKAGE_PIN D32 [get_ports {qsfp1_gt_gtx_n[0]}]; # DP4_C2M_N
set_property PACKAGE_PIN E38 [get_ports {qsfp1_gt_grx_p[0]}]; # DP4_M2C_P
set_property PACKAGE_PIN E39 [get_ports {qsfp1_gt_grx_n[0]}]; # DP4_M2C_N

set_property PACKAGE_PIN C33 [get_ports {qsfp1_gt_gtx_p[1]}]; # DP5_C2M_P (ch1)
set_property PACKAGE_PIN C34 [get_ports {qsfp1_gt_gtx_n[1]}]; # DP5_C2M_N
set_property PACKAGE_PIN D36 [get_ports {qsfp1_gt_grx_p[1]}]; # DP5_M2C_P
set_property PACKAGE_PIN D37 [get_ports {qsfp1_gt_grx_n[1]}]; # DP5_M2C_N

set_property PACKAGE_PIN B31 [get_ports {qsfp1_gt_gtx_p[2]}]; # DP6_C2M_P (ch2)
set_property PACKAGE_PIN B32 [get_ports {qsfp1_gt_gtx_n[2]}]; # DP6_C2M_N
set_property PACKAGE_PIN C38 [get_ports {qsfp1_gt_grx_p[2]}]; # DP6_M2C_P
set_property PACKAGE_PIN C39 [get_ports {qsfp1_gt_grx_n[2]}]; # DP6_M2C_N

set_property PACKAGE_PIN A33 [get_ports {qsfp1_gt_gtx_p[3]}]; # DP7_C2M_P (ch3)
set_property PACKAGE_PIN A34 [get_ports {qsfp1_gt_gtx_n[3]}]; # DP7_C2M_N
set_property PACKAGE_PIN B36 [get_ports {qsfp1_gt_grx_p[3]}]; # DP7_M2C_P
set_property PACKAGE_PIN B37 [get_ports {qsfp1_gt_grx_n[3]}]; # DP7_M2C_N

# QSFP slot 1: module I/O and User LEDs
set_property PACKAGE_PIN B22 [get_ports {modsell_qsfp1[0]}]; # LA15_P
set_property PACKAGE_PIN A22 [get_ports {resetl_qsfp1[0]}]; # LA15_N
set_property PACKAGE_PIN F24 [get_ports modprsl_qsfp1]; # LA05_P
set_property PACKAGE_PIN E24 [get_ports intl_qsfp1]; # LA05_N
set_property PACKAGE_PIN L20 [get_ports {lpmode_qsfp1[0]}]; # LA11_N
set_property PACKAGE_PIN E22 [get_ports grn_led_qsfp1]; # LA08_P
set_property PACKAGE_PIN E23 [get_ports {red_led_qsfp1[0]}]; # LA08_N

# QSFP module I/O IOSTANDARDs (both slots)
set_property IOSTANDARD LVCMOS18 [get_ports modsell_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports resetl_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports modprsl_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports intl_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports lpmode_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports grn_led_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports red_led_qsfp*]
