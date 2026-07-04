#---------------------------------------------------------------------
# Constraints for Opsero 2x QSFP28 FMC ref design for ZCU102-HPC0
#
# Both QSFP28 ports, each a 1x40GbE (40GBASE-R4) l_ethernet subsystem:
#   port 0 = FMC slot 0 / DP0-3 (GTH bank 229, quad X1Y8-11)
#   port 1 = FMC slot 1 / DP4-7 (GTH bank 228, quad X1Y4-7)
# GT serial pins are listed in GT channel order (lane [i] = channel i of
# the quad); the FMC DP number of each lane is noted in the comment (the
# HPC0 DP lanes are not wired to the GT channels in order). Ethernet
# multi-lane PCS tolerates the lane permutation.
#---------------------------------------------------------------------

#####################
# Si5328 clock generator I2C (shared)
#####################
set_property PACKAGE_PIN V2 [get_ports clk_i2c_scl_io]; # LA02_P
set_property PACKAGE_PIN V1 [get_ports clk_i2c_sda_io]; # LA02_N
set_property IOSTANDARD LVCMOS18 [get_ports clk_i2c_*]
set_property SLEW SLOW [get_ports clk_i2c_*]
set_property DRIVE 4 [get_ports clk_i2c_*]

# QSFP0 module I2C
set_property PACKAGE_PIN Y2 [get_ports qsfp0_i2c_scl_io]; # LA03_P
set_property PACKAGE_PIN Y1 [get_ports qsfp0_i2c_sda_io]; # LA03_N

# QSFP1 module I2C
set_property PACKAGE_PIN P11 [get_ports qsfp1_i2c_scl_io]; # LA17_CC_P
set_property PACKAGE_PIN N11 [get_ports qsfp1_i2c_sda_io]; # LA17_CC_N

set_property IOSTANDARD LVCMOS18 [get_ports qsfp*_i2c_*]
set_property SLEW SLOW [get_ports qsfp*_i2c_*]
set_property DRIVE 4 [get_ports qsfp*_i2c_*]

#####################
# GT reference clocks (from the FMC Si5328)
#####################
set_property PACKAGE_PIN G8 [get_ports gt_ref_clk_0_clk_p*]; # GBTCLK0_M2C_P (bank 229)
set_property PACKAGE_PIN L8 [get_ports gt_ref_clk_1_clk_p*]; # GBTCLK1_M2C_P (bank 228)

#############
# QSFP SLOT 0 (port 0) - DP0-3, GTH bank 229 (quad X1Y8-11)
#############

# Gigabit transceivers (4 lanes -> 1x40GbE 40GBASE-R4)
set_property PACKAGE_PIN K6 [get_ports {qsfp0_gt_gtx_p[0]}]; # DP3_C2M_P (ch0)
set_property PACKAGE_PIN K5 [get_ports {qsfp0_gt_gtx_n[0]}]; # DP3_C2M_N
set_property PACKAGE_PIN K2 [get_ports {qsfp0_gt_grx_p[0]}]; # DP3_M2C_P
set_property PACKAGE_PIN K1 [get_ports {qsfp0_gt_grx_n[0]}]; # DP3_M2C_N

set_property PACKAGE_PIN H6 [get_ports {qsfp0_gt_gtx_p[1]}]; # DP1_C2M_P (ch1)
set_property PACKAGE_PIN H5 [get_ports {qsfp0_gt_gtx_n[1]}]; # DP1_C2M_N
set_property PACKAGE_PIN J4 [get_ports {qsfp0_gt_grx_p[1]}]; # DP1_M2C_P
set_property PACKAGE_PIN J3 [get_ports {qsfp0_gt_grx_n[1]}]; # DP1_M2C_N

set_property PACKAGE_PIN G4 [get_ports {qsfp0_gt_gtx_p[2]}]; # DP0_C2M_P (ch2)
set_property PACKAGE_PIN G3 [get_ports {qsfp0_gt_gtx_n[2]}]; # DP0_C2M_N
set_property PACKAGE_PIN H2 [get_ports {qsfp0_gt_grx_p[2]}]; # DP0_M2C_P
set_property PACKAGE_PIN H1 [get_ports {qsfp0_gt_grx_n[2]}]; # DP0_M2C_N

set_property PACKAGE_PIN F6 [get_ports {qsfp0_gt_gtx_p[3]}]; # DP2_C2M_P (ch3)
set_property PACKAGE_PIN F5 [get_ports {qsfp0_gt_gtx_n[3]}]; # DP2_C2M_N
set_property PACKAGE_PIN F2 [get_ports {qsfp0_gt_grx_p[3]}]; # DP2_M2C_P
set_property PACKAGE_PIN F1 [get_ports {qsfp0_gt_grx_n[3]}]; # DP2_M2C_N

# QSFP slot 0: module I/O and User LEDs
set_property PACKAGE_PIN AA2 [get_ports {modsell_qsfp0[0]}]; # LA04_P
set_property PACKAGE_PIN AA1 [get_ports {resetl_qsfp0[0]}]; # LA04_N
set_property PACKAGE_PIN W7 [get_ports modprsl_qsfp0]; # LA12_P
set_property PACKAGE_PIN W6 [get_ports intl_qsfp0]; # LA12_N
set_property PACKAGE_PIN AB6 [get_ports {lpmode_qsfp0[0]}]; # LA11_P
set_property PACKAGE_PIN U5 [get_ports grn_led_qsfp0]; # LA07_P
set_property PACKAGE_PIN U4 [get_ports {red_led_qsfp0[0]}]; # LA07_N

#############
# QSFP SLOT 1 (port 1) - DP4-7, GTH bank 228 (quad X1Y4-7)
#############

# Gigabit transceivers (4 lanes -> 1x40GbE 40GBASE-R4)
set_property PACKAGE_PIN R4 [get_ports {qsfp1_gt_gtx_p[0]}]; # DP6_C2M_P (ch0)
set_property PACKAGE_PIN R3 [get_ports {qsfp1_gt_gtx_n[0]}]; # DP6_C2M_N
set_property PACKAGE_PIN T2 [get_ports {qsfp1_gt_grx_p[0]}]; # DP6_M2C_P
set_property PACKAGE_PIN T1 [get_ports {qsfp1_gt_grx_n[0]}]; # DP6_M2C_N

set_property PACKAGE_PIN P6 [get_ports {qsfp1_gt_gtx_p[1]}]; # DP5_C2M_P (ch1)
set_property PACKAGE_PIN P5 [get_ports {qsfp1_gt_gtx_n[1]}]; # DP5_C2M_N
set_property PACKAGE_PIN P2 [get_ports {qsfp1_gt_grx_p[1]}]; # DP5_M2C_P
set_property PACKAGE_PIN P1 [get_ports {qsfp1_gt_grx_n[1]}]; # DP5_M2C_N

set_property PACKAGE_PIN N4 [get_ports {qsfp1_gt_gtx_p[2]}]; # DP7_C2M_P (ch2)
set_property PACKAGE_PIN N3 [get_ports {qsfp1_gt_gtx_n[2]}]; # DP7_C2M_N
set_property PACKAGE_PIN M2 [get_ports {qsfp1_gt_grx_p[2]}]; # DP7_M2C_P
set_property PACKAGE_PIN M1 [get_ports {qsfp1_gt_grx_n[2]}]; # DP7_M2C_N

set_property PACKAGE_PIN M6 [get_ports {qsfp1_gt_gtx_p[3]}]; # DP4_C2M_P (ch3)
set_property PACKAGE_PIN M5 [get_ports {qsfp1_gt_gtx_n[3]}]; # DP4_C2M_N
set_property PACKAGE_PIN L4 [get_ports {qsfp1_gt_grx_p[3]}]; # DP4_M2C_P
set_property PACKAGE_PIN L3 [get_ports {qsfp1_gt_grx_n[3]}]; # DP4_M2C_N

# QSFP slot 1: module I/O and User LEDs
set_property PACKAGE_PIN Y10 [get_ports {modsell_qsfp1[0]}]; # LA15_P
set_property PACKAGE_PIN Y9 [get_ports {resetl_qsfp1[0]}]; # LA15_N
set_property PACKAGE_PIN AB3 [get_ports modprsl_qsfp1]; # LA05_P
set_property PACKAGE_PIN AC3 [get_ports intl_qsfp1]; # LA05_N
set_property PACKAGE_PIN AB5 [get_ports {lpmode_qsfp1[0]}]; # LA11_N
set_property PACKAGE_PIN V4 [get_ports grn_led_qsfp1]; # LA08_P
set_property PACKAGE_PIN V3 [get_ports {red_led_qsfp1[0]}]; # LA08_N

# QSFP module I/O IOSTANDARDs (both slots)
set_property IOSTANDARD LVCMOS18 [get_ports modsell_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports resetl_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports modprsl_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports intl_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports lpmode_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports grn_led_qsfp*]
set_property IOSTANDARD LVCMOS18 [get_ports red_led_qsfp*]
