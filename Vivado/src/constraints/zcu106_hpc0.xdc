#---------------------------------------------------------------------
# Constraints for Opsero 2x QSFP28 FMC ref design for ZCU106-HPC0
#
# Both QSFP28 ports, each a 1x40GbE (40GBASE-R4) l_ethernet subsystem:
#   port 0 = FMC slot 0 / DP0-3 (GTH bank 226, quad X0Y12-15)
#   port 1 = FMC slot 1 / DP4-7 (GTH bank 227, quad X0Y16-19)
# GT serial pins are listed in GT channel order (lane [i] = channel i of
# the quad); the FMC DP number of each lane is noted in the comment (the
# HPC0 DP lanes are not wired to the GT channels in order). Ethernet
# multi-lane PCS tolerates the lane permutation.
#
# NOTE: DP4 pins were verified against the ZU7EV package file (the
# board-repo ZCU106 pinout has a corrupt DP4 entry): DP4 = GTH channel
# X0Y19 -> C2M on H4/H3, M2C on G2/G1.
#---------------------------------------------------------------------

#####################
# Si5328 clock generator I2C (shared)
#####################
set_property PACKAGE_PIN L20 [get_ports clk_i2c_scl_io]; # LA02_P
set_property PACKAGE_PIN K20 [get_ports clk_i2c_sda_io]; # LA02_N
set_property IOSTANDARD LVCMOS18 [get_ports clk_i2c_*]
set_property SLEW SLOW [get_ports clk_i2c_*]
set_property DRIVE 4 [get_ports clk_i2c_*]

# QSFP0 module I2C
set_property PACKAGE_PIN K19 [get_ports qsfp0_i2c_scl_io]; # LA03_P
set_property PACKAGE_PIN K18 [get_ports qsfp0_i2c_sda_io]; # LA03_N

# QSFP1 module I2C
set_property PACKAGE_PIN F11 [get_ports qsfp1_i2c_scl_io]; # LA17_CC_P
set_property PACKAGE_PIN E10 [get_ports qsfp1_i2c_sda_io]; # LA17_CC_N

set_property IOSTANDARD LVCMOS18 [get_ports qsfp*_i2c_*]
set_property SLEW SLOW [get_ports qsfp*_i2c_*]
set_property DRIVE 4 [get_ports qsfp*_i2c_*]

#####################
# GT reference clocks (from the FMC Si5328)
#####################
set_property PACKAGE_PIN V8 [get_ports gt_ref_clk_0_clk_p*]; # GBTCLK0_M2C_P (bank 226)
set_property PACKAGE_PIN T8 [get_ports gt_ref_clk_1_clk_p*]; # GBTCLK1_M2C_P (bank 227)

#############
# QSFP SLOT 0 (port 0) - DP0-3, GTH bank 226 (quad X0Y12-15)
#############

# Gigabit transceivers (4 lanes -> 1x40GbE 40GBASE-R4)
set_property PACKAGE_PIN U6 [get_ports {qsfp0_gt_gtx_p[0]}]; # DP3_C2M_P (ch0)
set_property PACKAGE_PIN U5 [get_ports {qsfp0_gt_gtx_n[0]}]; # DP3_C2M_N
set_property PACKAGE_PIN V4 [get_ports {qsfp0_gt_grx_p[0]}]; # DP3_M2C_P
set_property PACKAGE_PIN V3 [get_ports {qsfp0_gt_grx_n[0]}]; # DP3_M2C_N

set_property PACKAGE_PIN T4 [get_ports {qsfp0_gt_gtx_p[1]}]; # DP1_C2M_P (ch1)
set_property PACKAGE_PIN T3 [get_ports {qsfp0_gt_gtx_n[1]}]; # DP1_C2M_N
set_property PACKAGE_PIN U2 [get_ports {qsfp0_gt_grx_p[1]}]; # DP1_M2C_P
set_property PACKAGE_PIN U1 [get_ports {qsfp0_gt_grx_n[1]}]; # DP1_M2C_N

set_property PACKAGE_PIN R6 [get_ports {qsfp0_gt_gtx_p[2]}]; # DP0_C2M_P (ch2)
set_property PACKAGE_PIN R5 [get_ports {qsfp0_gt_gtx_n[2]}]; # DP0_C2M_N
set_property PACKAGE_PIN R2 [get_ports {qsfp0_gt_grx_p[2]}]; # DP0_M2C_P
set_property PACKAGE_PIN R1 [get_ports {qsfp0_gt_grx_n[2]}]; # DP0_M2C_N

set_property PACKAGE_PIN N6 [get_ports {qsfp0_gt_gtx_p[3]}]; # DP2_C2M_P (ch3)
set_property PACKAGE_PIN N5 [get_ports {qsfp0_gt_gtx_n[3]}]; # DP2_C2M_N
set_property PACKAGE_PIN P4 [get_ports {qsfp0_gt_grx_p[3]}]; # DP2_M2C_P
set_property PACKAGE_PIN P3 [get_ports {qsfp0_gt_grx_n[3]}]; # DP2_M2C_N

# QSFP slot 0: module I/O and User LEDs
set_property PACKAGE_PIN L17 [get_ports {modsell_qsfp0[0]}]; # LA04_P
set_property PACKAGE_PIN L16 [get_ports {resetl_qsfp0[0]}]; # LA04_N
set_property PACKAGE_PIN G18 [get_ports modprsl_qsfp0]; # LA12_P
set_property PACKAGE_PIN F18 [get_ports intl_qsfp0]; # LA12_N
set_property PACKAGE_PIN A13 [get_ports {lpmode_qsfp0[0]}]; # LA11_P
set_property PACKAGE_PIN J16 [get_ports grn_led_qsfp0]; # LA07_P
set_property PACKAGE_PIN J15 [get_ports {red_led_qsfp0[0]}]; # LA07_N

#############
# QSFP SLOT 1 (port 1) - DP4-7, GTH bank 227 (quad X0Y16-19)
#############

# Gigabit transceivers (4 lanes -> 1x40GbE 40GBASE-R4)
set_property PACKAGE_PIN M4 [get_ports {qsfp1_gt_gtx_p[0]}]; # DP6_C2M_P (ch0)
set_property PACKAGE_PIN M3 [get_ports {qsfp1_gt_gtx_n[0]}]; # DP6_C2M_N
set_property PACKAGE_PIN N2 [get_ports {qsfp1_gt_grx_p[0]}]; # DP6_M2C_P
set_property PACKAGE_PIN N1 [get_ports {qsfp1_gt_grx_n[0]}]; # DP6_M2C_N

set_property PACKAGE_PIN L6 [get_ports {qsfp1_gt_gtx_p[1]}]; # DP5_C2M_P (ch1)
set_property PACKAGE_PIN L5 [get_ports {qsfp1_gt_gtx_n[1]}]; # DP5_C2M_N
set_property PACKAGE_PIN L2 [get_ports {qsfp1_gt_grx_p[1]}]; # DP5_M2C_P
set_property PACKAGE_PIN L1 [get_ports {qsfp1_gt_grx_n[1]}]; # DP5_M2C_N

set_property PACKAGE_PIN K4 [get_ports {qsfp1_gt_gtx_p[2]}]; # DP7_C2M_P (ch2)
set_property PACKAGE_PIN K3 [get_ports {qsfp1_gt_gtx_n[2]}]; # DP7_C2M_N
set_property PACKAGE_PIN J2 [get_ports {qsfp1_gt_grx_p[2]}]; # DP7_M2C_P
set_property PACKAGE_PIN J1 [get_ports {qsfp1_gt_grx_n[2]}]; # DP7_M2C_N

set_property PACKAGE_PIN H4 [get_ports {qsfp1_gt_gtx_p[3]}]; # DP4_C2M_P (ch3)
set_property PACKAGE_PIN H3 [get_ports {qsfp1_gt_gtx_n[3]}]; # DP4_C2M_N
set_property PACKAGE_PIN G2 [get_ports {qsfp1_gt_grx_p[3]}]; # DP4_M2C_P
set_property PACKAGE_PIN G1 [get_ports {qsfp1_gt_grx_n[3]}]; # DP4_M2C_N

# QSFP slot 1: module I/O and User LEDs
set_property PACKAGE_PIN D16 [get_ports {modsell_qsfp1[0]}]; # LA15_P
set_property PACKAGE_PIN C16 [get_ports {resetl_qsfp1[0]}]; # LA15_N
set_property PACKAGE_PIN K17 [get_ports modprsl_qsfp1]; # LA05_P
set_property PACKAGE_PIN J17 [get_ports intl_qsfp1]; # LA05_N
set_property PACKAGE_PIN A12 [get_ports {lpmode_qsfp1[0]}]; # LA11_N
set_property PACKAGE_PIN E18 [get_ports grn_led_qsfp1]; # LA08_P
set_property PACKAGE_PIN E17 [get_ports {red_led_qsfp1[0]}]; # LA08_N

# QSFP module I/O IOSTANDARDs (both slots)
set_property IOSTANDARD LVCMOS18 [get_ports modsell_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports resetl_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports modprsl_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports intl_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports lpmode_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports grn_led_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports red_led_qsfp*]
