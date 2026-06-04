################################################################
# Block design build script for Versal QSFP28 designs (MRMAC 100G)
#
# Opsero 2x QSFP28 FMC reference design.
#
# This script is sourced by build.tcl, which sets:
#   block_name = qsfp
#   board_name = vck190
#   ports      = { 0 }   (Phase 1: QSFP port 0 only)
#   line_rate  = 100
#
# For each QSFP port it builds a single 100GbE (CAUI-4) MRMAC subsystem
# with an AXI MCDMA datapath to DDR via the NoC.
################################################################

# CHECKING IF PROJECT EXISTS
if { [get_projects -quiet] eq "" } {
   puts "ERROR: Please open or create a project!"
   return 1
}

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

create_bd_design $block_name
current_bd_design $block_name

set parentCell [get_bd_cells /]
set parentObj [get_bd_cells $parentCell]
if { $parentObj == "" } {
   puts "ERROR: Unable to find parent cell <$parentCell>!"
   return
}
set parentType [get_property TYPE $parentObj]
if { $parentType ne "hier" } {
   puts "ERROR: Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."
   return
}

set oldCurInst [current_bd_instance .]
current_bd_instance $parentObj

# Returns true if str contains substr
proc str_contains {str substr} {
  if {[string first $substr $str] == -1} { return 0 } else { return 1 }
}

# Target board checks
set is_vck190 [str_contains $board_name "vck190"]

# Number of ports
set num_ports [llength $ports]

# List of interrupt pins
set intr_list {}

# Add the CIPS
create_bd_cell -type ip -vlnv xilinx.com:ip:versal_cips versal_cips_0

# Configure the CIPS using automation feature (vck190 = DDR branch)
apply_bd_automation -rule xilinx.com:bd_rule:cips -config { \
  board_preset {Yes} \
  boot_config {Custom} \
  configure_noc {Add new AXI NoC} \
  debug_config {JTAG} \
  design_flow {Full System} \
  mc_type {DDR} \
  num_mc_ddr {1} \
  num_mc_lpddr {None} \
  pl_clocks {None} \
  pl_resets {None} \
}  [get_bd_cells versal_cips_0]

# Extra PS PMC config for this design (vck190 branch from sfp28 reference)
# - PL CLK0 = 100MHz, PL CLK1 = 50MHz
# - M_AXI_LPD enable, PL-to-PS interrupts IRQ0-15, one fabric reset
set_property -dict [list \
  CONFIG.CLOCK_MODE {Custom} \
  CONFIG.PS_BOARD_INTERFACE {Custom} \
  CONFIG.PS_PL_CONNECTIVITY_MODE {Custom} \
  CONFIG.PS_PMC_CONFIG { \
    CLOCK_MODE {Custom} \
    DDR_MEMORY_MODE {Connectivity to DDR via NOC} \
    DEBUG_MODE {JTAG} \
    DESIGN_MODE {1} \
    PMC_CRP_PL0_REF_CTRL_FREQMHZ {100} \
    PMC_CRP_PL1_REF_CTRL_FREQMHZ {50} \
    PMC_GPIO0_MIO_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 0 .. 25}}} \
    PMC_GPIO1_MIO_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 26 .. 51}}} \
    PMC_MIO37 {{AUX_IO 0} {DIRECTION out} {DRIVE_STRENGTH 8mA} {OUTPUT_DATA high} {PULL pullup} {SCHMITT 0} {SLEW slow} {USAGE GPIO}} \
    PMC_OSPI_PERIPHERAL {{ENABLE 0} {IO {PMC_MIO 0 .. 11}} {MODE Single}} \
    PMC_QSPI_COHERENCY {0} \
    PMC_QSPI_FBCLK {{ENABLE 1} {IO {PMC_MIO 6}}} \
    PMC_QSPI_PERIPHERAL_DATA_MODE {x4} \
    PMC_QSPI_PERIPHERAL_ENABLE {1} \
    PMC_QSPI_PERIPHERAL_MODE {Dual Parallel} \
    PMC_REF_CLK_FREQMHZ {33.3333} \
    PMC_SD1 {{CD_ENABLE 1} {CD_IO {PMC_MIO 28}} {POW_ENABLE 1} {POW_IO {PMC_MIO 51}} {RESET_ENABLE 0} {RESET_IO {PMC_MIO 12}} {WP_ENABLE 0} {WP_IO {PMC_MIO 1}}} \
    PMC_SD1_COHERENCY {0} \
    PMC_SD1_DATA_TRANSFER_MODE {8Bit} \
    PMC_SD1_PERIPHERAL {{CLK_100_SDR_OTAP_DLY 0x3} {CLK_200_SDR_OTAP_DLY 0x2} {CLK_50_DDR_ITAP_DLY 0x36} {CLK_50_DDR_OTAP_DLY 0x3} {CLK_50_SDR_ITAP_DLY 0x2C} {CLK_50_SDR_OTAP_DLY 0x4} {ENABLE 1} {IO {PMC_MIO 26 .. 36}}} \
    PMC_SD1_SLOT_TYPE {SD 3.0} \
    PMC_USE_PMC_NOC_AXI0 {1} \
    PS_BOARD_INTERFACE {Custom} \
    PS_ENET0_MDIO {{ENABLE 1} {IO {PS_MIO 24 .. 25}}} \
    PS_ENET0_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 0 .. 11}}} \
    PS_ENET1_PERIPHERAL {{ENABLE 1} {IO {PS_MIO 12 .. 23}}} \
    PS_GEN_IPI0_ENABLE {1} \
    PS_GEN_IPI0_MASTER {A72} \
    PS_GEN_IPI1_ENABLE {1} \
    PS_GEN_IPI2_ENABLE {1} \
    PS_GEN_IPI3_ENABLE {1} \
    PS_GEN_IPI4_ENABLE {1} \
    PS_GEN_IPI5_ENABLE {1} \
    PS_GEN_IPI6_ENABLE {1} \
    PS_HSDP_EGRESS_TRAFFIC {JTAG} \
    PS_HSDP_INGRESS_TRAFFIC {JTAG} \
    PS_HSDP_MODE {NONE} \
    PS_I2C0_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 46 .. 47}}} \
    PS_I2C1_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 44 .. 45}}} \
    PS_IRQ_USAGE {{CH0 1} {CH1 1} {CH10 1} {CH11 1} {CH12 1} {CH13 1} {CH14 1} {CH15 1} {CH2 1} {CH3 1} {CH4 1} {CH5 1} {CH6 1} {CH7 1} {CH8 1} {CH9 1}} \
    PS_NUM_FABRIC_RESETS {1} \
    PS_PCIE_EP_RESET1_IO {PMC_MIO 38} \
    PS_PCIE_EP_RESET2_IO {PMC_MIO 39} \
    PS_PCIE_RESET {ENABLE 1} \
    PS_PL_CONNECTIVITY_MODE {Custom} \
    PS_UART0_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 42 .. 43}}} \
    PS_USB3_PERIPHERAL {{ENABLE 1} {IO {PMC_MIO 13 .. 25}}} \
    PS_USE_FPD_CCI_NOC {1} \
    PS_USE_FPD_CCI_NOC0 {1} \
    PS_USE_M_AXI_LPD {1} \
    PS_USE_NOC_LPD_AXI0 {1} \
    PS_USE_PMCPL_CLK0 {1} \
    PS_USE_PMCPL_CLK1 {1} \
    PS_USE_PMCPL_CLK2 {0} \
    PS_USE_PMCPL_CLK3 {0} \
    SMON_ALARMS {Set_Alarms_On} \
    SMON_ENABLE_TEMP_AVERAGING {0} \
    SMON_TEMP_AVERAGING_SAMPLES {0} \
  } \
] [get_bd_cells versal_cips_0]

# Add clock wizard to generate the system clock (100MHz)
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wizard clk_wizard_0
set_property -dict [list \
  CONFIG.CLKOUT_DRIVES {BUFG,BUFG,BUFG,BUFG,BUFG,BUFG,BUFG} \
  CONFIG.CLKOUT_DYN_PS {None,None,None,None,None,None,None} \
  CONFIG.CLKOUT_GROUPING {Auto,Auto,Auto,Auto,Auto,Auto,Auto} \
  CONFIG.CLKOUT_MATCHED_ROUTING {false,false,false,false,false,false,false} \
  CONFIG.CLKOUT_PORT {clk_100m,clk_out2,clk_out3,clk_out4,clk_out5,clk_out6,clk_out7} \
  CONFIG.CLKOUT_REQUESTED_DUTY_CYCLE {50.000,50.000,50.000,50.000,50.000,50.000,50.000} \
  CONFIG.CLKOUT_REQUESTED_OUT_FREQUENCY {100.000,100.000,100.000,100.000,100.000,100.000,100.000} \
  CONFIG.CLKOUT_REQUESTED_PHASE {0.000,0.000,0.000,0.000,0.000,0.000,0.000} \
  CONFIG.CLKOUT_USED {true,false,false,false,false,false,false} \
] [get_bd_cells clk_wizard_0]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins clk_wizard_0/clk_in1]

# System clock (100MHz) - used for all AXI-Lite control and MCDMA/NoC datapath
set sys_clk "clk_wizard_0/clk_100m"

# AXIS client clock wizard: 100MHz -> 390.625MHz (drives MRMAC tx_axi_clk/rx_axi_clk)
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wizard axis_clk_wiz
set_property -dict [list \
  CONFIG.CLKOUT_DRIVES {BUFG,BUFG,BUFG,BUFG,BUFG,BUFG,BUFG} \
  CONFIG.CLKOUT_DYN_PS {None,None,None,None,None,None,None} \
  CONFIG.CLKOUT_GROUPING {Auto,Auto,Auto,Auto,Auto,Auto,Auto} \
  CONFIG.CLKOUT_MATCHED_ROUTING {false,false,false,false,false,false,false} \
  CONFIG.CLKOUT_PORT {clk_390m625,clk_out2,clk_out3,clk_out4,clk_out5,clk_out6,clk_out7} \
  CONFIG.CLKOUT_REQUESTED_OUT_FREQUENCY {390.625,100.000,100.000,100.000,100.000,100.000,100.000} \
  CONFIG.CLKOUT_USED {true,false,false,false,false,false,false} \
] [get_bd_cells axis_clk_wiz]
connect_bd_net [get_bd_pins versal_cips_0/pl0_ref_clk] [get_bd_pins axis_clk_wiz/clk_in1]
set axis_clk "axis_clk_wiz/clk_390m625"

# Configure the NoC. The CIPS automation pre-connects S00..S05 (FPD/LPD/PMC)
# and aclk0..5. Each QSFP port's MCDMA adds 3 AXI slave ports (SG/MM2S/S2MM) on
# aclk6 (system clock); their per-SI memory-controller CONNECTIONS are set in
# the per-port loop below. So NUM_SI = 6 (CIPS) + 3 per QSFP port.
set_property -dict [list CONFIG.NUM_CLKS {7} CONFIG.NUM_SI [expr {6 + 3 * $num_ports}]] [get_bd_cells axi_noc_0]
connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_noc_0/aclk6]
set noc_port_index 6
set noc_clk_index 6

# Connect the AXI interface clocks
connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins versal_cips_0/m_axi_lpd_aclk]

# Proc system reset for main clock
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_100m
connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins rst_100m/slowest_sync_clk]
connect_bd_net [get_bd_pins versal_cips_0/pl0_resetn] [get_bd_pins rst_100m/ext_reset_in]

# Proc system reset for the 390.625MHz AXIS client clock
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_390m625
connect_bd_net [get_bd_pins $axis_clk] [get_bd_pins rst_390m625/slowest_sync_clk]
connect_bd_net [get_bd_pins versal_cips_0/pl0_resetn] [get_bd_pins rst_390m625/ext_reset_in]

# AXI SmartConnect for the AXI-Lite control interfaces. Masters are allocated
# with a running counter (smc_mi): per QSFP port -> {port control aggregate,
# qsfp sideband GPIO, qsfp module I2C} = 3 each, plus 1 shared Si5328 clk I2C.
# So NUM_MI = 3 per port + 1.
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect axi_smc
set_property -dict [list CONFIG.NUM_MI [expr {3 * $num_ports + 1}] CONFIG.NUM_SI {1} ] [get_bd_cells axi_smc]
connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_smc/aclk]
connect_bd_net [get_bd_pins rst_100m/interconnect_aresetn] [get_bd_pins axi_smc/aresetn]
connect_bd_intf_net [get_bd_intf_pins versal_cips_0/M_AXI_LPD] [get_bd_intf_pins axi_smc/S00_AXI]
set smc_mi 0

# GT ref clock (322.265625 MHz, from the FMC Si5328) and utility buffer.
# 322.265625 MHz + LCPLL integer-N replicates the AMD VCK190 Ethernet TRD's
# proven MRMAC GT config (see the gt_quad_base PROT0 settings below).
create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 gt_ref_clk_0
set_property CONFIG.FREQ_HZ 322265625 [get_bd_intf_ports /gt_ref_clk_0]
create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf util_ds_buf_0
set_property CONFIG.C_BUF_TYPE {IBUFDSGTE} [get_bd_cells util_ds_buf_0]
connect_bd_intf_net [get_bd_intf_ports gt_ref_clk_0] [get_bd_intf_pins util_ds_buf_0/CLK_IN_D]

# GT Quad base (Transceiver wizard), GTY, 4 lanes bonded for 100G CAUI-4.
# The 4 lanes each run at 25.78125 Gb/s (raw) off the 322.265625 MHz refclk;
# lane bonding into a single 100G MAC happens inside the MRMAC core.
create_bd_cell -type ip -vlnv xilinx.com:ip:gt_quad_base gt_quad_base_0

# Configure PROT0 = 4 lanes for the MRMAC by replicating the AMD VCK190
# Ethernet TRD's exact gt_quad_base PROT0_LR0_SETTINGS (PRESET None, 80-bit
# RAW, 25.78125 Gb/s, LCPLL integer-N, 322.265625 MHz refclk). The MRMAC needs
# an 80-bit RAW GT datapath that no named Ethernet preset provides - which is
# why the TRD sets PRESET None and specifies every field manually. We merge the
# TRD's field set onto THIS IP version's default LR0 dict, applying only field
# names that still exist in the 2025.2 gt_quad_base (so any 2022.1-only fields
# are silently dropped instead of erroring).
set trd_gt {
  PRESET None
  RX_PAM_SEL NRZ
  TX_PAM_SEL NRZ
  RX_GRAY_BYP true
  TX_GRAY_BYP true
  RX_GRAY_LITTLEENDIAN true
  TX_GRAY_LITTLEENDIAN true
  RX_PRECODE_BYP true
  TX_PRECODE_BYP true
  RX_PRECODE_LITTLEENDIAN false
  TX_PRECODE_LITTLEENDIAN false
  INTERNAL_PRESET None
  GT_TYPE GTY
  GT_DIRECTION DUPLEX
  TX_LINE_RATE 25.78125
  TX_PLL_TYPE LCPLL
  TX_REFCLK_FREQUENCY 322.265625
  TX_ACTUAL_REFCLK_FREQUENCY 322.265625000000
  TX_FRACN_ENABLED false
  TX_FRACN_NUMERATOR 0
  TX_REFCLK_SOURCE R0
  TX_DATA_ENCODING RAW
  TX_USER_DATA_WIDTH 80
  TX_INT_DATA_WIDTH 80
  TX_BUFFER_MODE 1
  TX_BUFFER_BYPASS_MODE Fast_Sync
  TX_PIPM_ENABLE false
  TX_OUTCLK_SOURCE TXPROGDIVCLK
  TXPROGDIV_FREQ_ENABLE true
  TXPROGDIV_FREQ_SOURCE LCPLL
  TXPROGDIV_FREQ_VAL 644.531
  TX_DIFF_SWING_EMPH_MODE CUSTOM
  TX_64B66B_SCRAMBLER false
  TX_64B66B_ENCODER false
  TX_64B66B_CRC false
  TX_RATE_GROUP A
  RX_LINE_RATE 25.78125
  RX_PLL_TYPE LCPLL
  RX_REFCLK_FREQUENCY 322.265625
  RX_ACTUAL_REFCLK_FREQUENCY 322.265625000000
  RX_FRACN_ENABLED false
  RX_FRACN_NUMERATOR 0
  RX_REFCLK_SOURCE R0
  RX_DATA_DECODING RAW
  RX_USER_DATA_WIDTH 80
  RX_INT_DATA_WIDTH 80
  RX_BUFFER_MODE 1
  RX_OUTCLK_SOURCE RXPROGDIVCLK
  RXPROGDIV_FREQ_ENABLE true
  RXPROGDIV_FREQ_SOURCE LCPLL
  RXPROGDIV_FREQ_VAL 644.531
  INS_LOSS_NYQ 20
  RX_EQ_MODE AUTO
  RX_COUPLING AC
  RX_TERMINATION PROGRAMMABLE
  RX_RATE_GROUP A
  RX_TERMINATION_PROG_VALUE 800
  RX_PPM_OFFSET 0
  RX_64B66B_DESCRAMBLER false
  RX_64B66B_DECODER false
  RX_64B66B_CRC false
  OOB_ENABLE false
  RX_COMMA_ALIGN_WORD 1
  RX_COMMA_SHOW_REALIGN_ENABLE true
  PCIE_ENABLE false
  TX_LANE_DESKEW_HDMI_ENABLE false
  RX_COMMA_P_ENABLE false
  RX_COMMA_M_ENABLE false
  RX_COMMA_DOUBLE_ENABLE false
  RX_COMMA_P_VAL 0101111100
  RX_COMMA_M_VAL 1010000011
  RX_COMMA_MASK 0000000000
  RX_SLIDE_MODE OFF
  RX_SSC_PPM 0
  RX_CB_NUM_SEQ 0
  RX_CB_LEN_SEQ 1
  RX_CB_MAX_SKEW 1
  RX_CB_MAX_LEVEL 1
  RX_CB_MASK_0_0 false
  RX_CB_VAL_0_0 0000000000
  RX_CB_K_0_0 false
  RX_CB_DISP_0_0 false
  RX_CB_MASK_0_1 false
  RX_CB_VAL_0_1 0000000000
  RX_CB_K_0_1 false
  RX_CB_DISP_0_1 false
  RX_CB_MASK_0_2 false
  RX_CB_VAL_0_2 0000000000
  RX_CB_K_0_2 false
  RX_CB_DISP_0_2 false
  RX_CB_MASK_0_3 false
  RX_CB_VAL_0_3 0000000000
  RX_CB_K_0_3 false
  RX_CB_DISP_0_3 false
  RX_CB_MASK_1_0 false
  RX_CB_VAL_1_0 0000000000
  RX_CB_K_1_0 false
  RX_CB_DISP_1_0 false
  RX_CB_MASK_1_1 false
  RX_CB_VAL_1_1 0000000000
  RX_CB_K_1_1 false
  RX_CB_DISP_1_1 false
  RX_CB_MASK_1_2 false
  RX_CB_VAL_1_2 0000000000
  RX_CB_K_1_2 false
  RX_CB_DISP_1_2 false
  RX_CB_MASK_1_3 false
  RX_CB_VAL_1_3 0000000000
  RX_CB_K_1_3 false
  RX_CB_DISP_1_3 false
  RX_CC_NUM_SEQ 0
  RX_CC_LEN_SEQ 1
  RX_CC_PERIODICITY 5000
  RX_CC_KEEP_IDLE DISABLE
  RX_CC_PRECEDENCE ENABLE
  RX_CC_REPEAT_WAIT 0
  RX_CC_VAL 00000000000000000000000000000000000000000000000000000000000000000000000000000000
  RX_CC_MASK_0_0 false
  RX_CC_VAL_0_0 0000000000
  RX_CC_K_0_0 false
  RX_CC_DISP_0_0 false
  RX_CC_MASK_0_1 false
  RX_CC_VAL_0_1 0000000000
  RX_CC_K_0_1 false
  RX_CC_DISP_0_1 false
  RX_CC_MASK_0_2 false
  RX_CC_VAL_0_2 0000000000
  RX_CC_K_0_2 false
  RX_CC_DISP_0_2 false
  RX_CC_MASK_0_3 false
  RX_CC_VAL_0_3 0000000000
  RX_CC_K_0_3 false
  RX_CC_DISP_0_3 false
  RX_CC_MASK_1_0 false
  RX_CC_VAL_1_0 0000000000
  RX_CC_K_1_0 false
  RX_CC_DISP_1_0 false
  RX_CC_MASK_1_1 false
  RX_CC_VAL_1_1 0000000000
  RX_CC_K_1_1 false
  RX_CC_DISP_1_1 false
  RX_CC_MASK_1_2 false
  RX_CC_VAL_1_2 0000000000
  RX_CC_K_1_2 false
  RX_CC_DISP_1_2 false
  RX_CC_MASK_1_3 false
  RX_CC_VAL_1_3 0000000000
  RX_CC_K_1_3 false
  RX_CC_DISP_1_3 false
  PCIE_USERCLK2_FREQ 250
  PCIE_USERCLK_FREQ 250
  RX_JTOL_FC 10
  RX_JTOL_LF_SLOPE -20
  RX_BUFFER_BYPASS_MODE Fast_Sync
  RX_BUFFER_BYPASS_MODE_LANE MULTI
  RX_BUFFER_RESET_ON_CB_CHANGE ENABLE
  RX_BUFFER_RESET_ON_COMMAALIGN DISABLE
  RX_BUFFER_RESET_ON_RATE_CHANGE ENABLE
  TX_BUFFER_RESET_ON_RATE_CHANGE ENABLE
  RESET_SEQUENCE_INTERVAL 0
  RX_COMMA_PRESET NONE
  RX_COMMA_VALID_ONLY 0
}
set_property -dict [list \
  CONFIG.PROT0_LR0_SETTINGS.VALUE_MODE MANUAL \
  CONFIG.PROT0_NO_OF_LANES.VALUE_MODE MANUAL \
] [get_bd_cells gt_quad_base_0]
array set gtset [get_property CONFIG.PROT0_LR0_SETTINGS [get_bd_cells gt_quad_base_0]]
foreach {k v} $trd_gt {
  if {[info exists gtset($k)]} { set gtset($k) $v }
}
set_property -dict [list \
  CONFIG.PROT0_LR0_SETTINGS [array get gtset] \
  CONFIG.PROT0_NO_OF_LANES {4} \
] [get_bd_cells gt_quad_base_0]

connect_bd_net [get_bd_pins util_ds_buf_0/IBUF_OUT] [get_bd_pins gt_quad_base_0/GT_REFCLK0]
connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins gt_quad_base_0/apb3clk]
connect_bd_net [get_bd_pins rst_100m/peripheral_aresetn] [get_bd_pins gt_quad_base_0/apb3presetn]

# QSFP slot 0 GT interface (4-lane serial)
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gt_rtl:1.0 qsfp0_gt
connect_bd_intf_net [get_bd_intf_pins gt_quad_base_0/GT_Serial] [get_bd_intf_ports qsfp0_gt]

# APB3 bridge to drive the GT quad's dynamic reconfiguration port
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_apb_bridge axi_apb_bridge_0
set_property -dict [list CONFIG.C_APB_NUM_SLAVES {1} CONFIG.C_M_APB_PROTOCOL {apb3}] [get_bd_cells axi_apb_bridge_0]
connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_apb_bridge_0/s_axi_aclk]
connect_bd_net [get_bd_pins rst_100m/peripheral_aresetn] [get_bd_pins axi_apb_bridge_0/s_axi_aresetn]
connect_bd_intf_net [get_bd_intf_pins axi_apb_bridge_0/APB_M] [get_bd_intf_pins gt_quad_base_0/APB3_INTF]

#########################################################
# QSFP slot 1 GT quad (Phase 2) - DP4-7, second 100G CAUI-4 MRMAC port.
#########################################################
# Identical GT config to slot 0 (reuses the same $trd_gt field set), with its
# own reference clock (gt_ref_clk_1 = GBTCLK1 from the FMC Si5328) and its own
# qsfp1_gt serial port. Only built when port 1 is in $ports.
if {[lsearch -exact $ports 1] >= 0} {
  create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 gt_ref_clk_1
  set_property CONFIG.FREQ_HZ 322265625 [get_bd_intf_ports /gt_ref_clk_1]
  create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf util_ds_buf_1
  set_property CONFIG.C_BUF_TYPE {IBUFDSGTE} [get_bd_cells util_ds_buf_1]
  connect_bd_intf_net [get_bd_intf_ports gt_ref_clk_1] [get_bd_intf_pins util_ds_buf_1/CLK_IN_D]

  create_bd_cell -type ip -vlnv xilinx.com:ip:gt_quad_base gt_quad_base_1
  set_property -dict [list \
    CONFIG.PROT0_LR0_SETTINGS.VALUE_MODE MANUAL \
    CONFIG.PROT0_NO_OF_LANES.VALUE_MODE MANUAL \
  ] [get_bd_cells gt_quad_base_1]
  array unset gtset1
  array set gtset1 [get_property CONFIG.PROT0_LR0_SETTINGS [get_bd_cells gt_quad_base_1]]
  foreach {k v} $trd_gt {
    if {[info exists gtset1($k)]} { set gtset1($k) $v }
  }
  set_property -dict [list \
    CONFIG.PROT0_LR0_SETTINGS [array get gtset1] \
    CONFIG.PROT0_NO_OF_LANES {4} \
  ] [get_bd_cells gt_quad_base_1]

  connect_bd_net [get_bd_pins util_ds_buf_1/IBUF_OUT] [get_bd_pins gt_quad_base_1/GT_REFCLK0]
  connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins gt_quad_base_1/apb3clk]
  connect_bd_net [get_bd_pins rst_100m/peripheral_aresetn] [get_bd_pins gt_quad_base_1/apb3presetn]

  create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gt_rtl:1.0 qsfp1_gt
  connect_bd_intf_net [get_bd_intf_pins gt_quad_base_1/GT_Serial] [get_bd_intf_ports qsfp1_gt]

  create_bd_cell -type ip -vlnv xilinx.com:ip:axi_apb_bridge axi_apb_bridge_1
  set_property -dict [list CONFIG.C_APB_NUM_SLAVES {1} CONFIG.C_M_APB_PROTOCOL {apb3}] [get_bd_cells axi_apb_bridge_1]
  connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_apb_bridge_1/s_axi_aclk]
  connect_bd_net [get_bd_pins rst_100m/peripheral_aresetn] [get_bd_pins axi_apb_bridge_1/s_axi_aresetn]
  connect_bd_intf_net [get_bd_intf_pins axi_apb_bridge_1/APB_M] [get_bd_intf_pins gt_quad_base_1/APB3_INTF]
}

#########################################################
# QSFP ports
#########################################################
#
# Each QSFP port instantiates a 100GbE (CAUI-4) MRMAC subsystem:
#  - mrmac (1x100GE) with s_axi control
#  - per-channel bufg_gt clock buffers from gt_quad_base outclks
#  - axi_mcdma datapath with axis_dwidth_converter (384b<->512b) and
#    axis_data_fifo CDC between the MRMAC axi clock and the MCDMA/NoC clock
#

proc create_qsfp_port {label} {

  global axis_clk

  set hier_obj [create_bd_cell -type hier qsfp_port$label]
  current_bd_instance $hier_obj

  # Pins
  create_bd_pin -dir I sys_clk
  create_bd_pin -dir I axis_clk
  create_bd_pin -dir I periph_rstn
  create_bd_pin -dir I intercon_rstn
  create_bd_pin -dir I axis_rstn
  create_bd_pin -dir I gtpowergood_in
  create_bd_pin -dir O dma_mm2s_introut
  create_bd_pin -dir O dma_s2mm_introut
  create_bd_pin -dir O grn_led
  create_bd_pin -dir O red_led
  # per-channel GT outclks (raw) and usrclks (to GT)
  foreach ch {0 1 2 3} {
    create_bd_pin -dir I ch${ch}_txoutclk
    create_bd_pin -dir I ch${ch}_rxoutclk
    create_bd_pin -dir O ch${ch}_txusrclk
    create_bd_pin -dir O ch${ch}_rxusrclk
  }

  # Interfaces
  create_bd_intf_pin -mode Slave  -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_LITE
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_sg
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_mm2s
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_s2mm
  foreach ch {0 1 2 3} {
    create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:gt_tx_interface_rtl:1.0 gt_tx_serdes_interface_$ch
    create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:gt_rx_interface_rtl:1.0 gt_rx_serdes_interface_$ch
  }

  #########################################################
  # MRMAC (1x100GE CAUI-4)
  #########################################################
  create_bd_cell -type ip -vlnv xilinx.com:ip:mrmac mrmac
  # Use the "old" GT wizard model so the MRMAC exposes the gt serdes
  # interface pins (gt_*_serdes_interface_*) that connect directly to
  # gt_quad_base TXn/RXn_GT_IP_Interface (same VLNV).
  set_property CONFIG.MRMAC_IS_GT_WIZ_OLD {1} [get_bd_cells mrmac]
  # Pin each port's MRMAC to the integrated-MAC site in the clock region of its
  # GT quad. Port 0 = GTY_QUAD_X1Y1 (region X9Y1) -> MRMAC_X0Y0; port 1 =
  # GTY_QUAD_X1Y2 (region X9Y2) -> MRMAC_X0Y2. Both MRMACs default to
  # MRMAC_X0Y0, so without this port 1 fails to place ("bel is occupied").
  set mrmac_loc_map {0 MRMAC_X0Y0 1 MRMAC_X0Y2}
  set_property CONFIG.MRMAC_LOCATION_C0 [dict get $mrmac_loc_map $label] [get_bd_cells mrmac]
  # GT reference clock = 322.265625 MHz (the FMC Si5328 output) - matches the
  # AMD TRD's MRMAC GT config. Set it (and the per-channel refclks) explicitly
  # so the MRMAC and gt_quad_base agree. Line rate stays 25.78125 Gb/s
  # (LCPLL integer-N).
  set_property -dict [list \
    CONFIG.GT_REF_CLK_FREQ_C0 {322.265625} \
    CONFIG.GT_CH0_RX_REFCLK_FREQUENCY_C0 {322.265625} \
    CONFIG.GT_CH0_TX_REFCLK_FREQUENCY_C0 {322.265625} \
    CONFIG.GT_CH1_RX_REFCLK_FREQUENCY_C0 {322.265625} \
    CONFIG.GT_CH1_TX_REFCLK_FREQUENCY_C0 {322.265625} \
    CONFIG.GT_CH2_RX_REFCLK_FREQUENCY_C0 {322.265625} \
    CONFIG.GT_CH2_TX_REFCLK_FREQUENCY_C0 {322.265625} \
    CONFIG.GT_CH3_RX_REFCLK_FREQUENCY_C0 {322.265625} \
    CONFIG.GT_CH3_TX_REFCLK_FREQUENCY_C0 {322.265625} \
  ] [get_bd_cells mrmac]

  # NOTE: mrmac/s_axi_aclk (sys_clk, 100MHz) is connected at the very END of
  # this proc, after the AXIS datapath converters are wired. Connecting the
  # 100MHz control clock while the 390MHz AXIS client domain is already set
  # makes the MRMAC client interface report a 4-segment PHASE; wiring the
  # converters first (while the PHASE is still single-segment) avoids a
  # PHASE-mismatch error at validate.

  # GT power good
  connect_bd_net [get_bd_pins gtpowergood_in] [get_bd_pins mrmac/gtpowergood_in]

  # GT serdes interfaces (carry data + per-channel reset handshake)
  foreach ch {0 1 2 3} {
    connect_bd_intf_net [get_bd_intf_pins mrmac/gt_tx_serdes_interface_$ch] [get_bd_intf_pins gt_tx_serdes_interface_$ch]
    connect_bd_intf_net [get_bd_intf_pins mrmac/gt_rx_serdes_interface_$ch] [get_bd_intf_pins gt_rx_serdes_interface_$ch]
  }

  #########################################################
  # Per-channel user clock buffers (GT outclk -> usrclk + usrclk/2)
  #########################################################
  # CAUI-4 GT clocking - replicates BOTH AMD references (the MRMAC 1x100GE
  # CAUI-4 IP example design and the vck190 ethernet TRD), which wire it
  # identically:
  #   RX: each of the 4 GT lanes recovers its OWN clock, so each lane gets its
  #       own pair of BUFG_GTs - a full-rate "usrclk" and a half-rate "usrclk2"
  #       (the BUFG_GT /2 divided output). The MRMAC rx_serdes_clk/rx_core_clk
  #       buses take the per-lane FULL-rate clocks; rx_alt_serdes_clk takes the
  #       per-lane HALF-rate clocks; the GT's own chN_rxusrclk input takes the
  #       per-lane HALF-rate clock.
  #   TX: all 4 lanes share the TX PLL, so a single ch0 pair drives all four TX
  #       lanes. tx_core_clk = ch0 FULL-rate x4; tx_alt_serdes_clk and the GT
  #       chN_txusrclk inputs = ch0 HALF-rate.
  # The MRMAC clock buses are 4-bit; driving them from a 4-way ilconcat is
  # correct here (these are internal GT/MRMAC clocks, NOT the AXIS client clock,
  # so the old single-segment-PHASE concern - which only applies to the AXIS
  # client tx_axi_clk/rx_axi_clk - does not apply). The previous design drove
  # rx_serdes_clk/rx_core_clk from ch0 alone, leaving lanes 1-3 sampled in the
  # wrong recovered-clock domain: those PCS lanes never block-lock and 100G
  # alignment never completes, even with a passive loopback.

  # /2 divider value for the half-rate (usrclk2) BUFG_GT outputs.
  # BUFG_GT divides by (gt_bufgtdiv + 1), so a value of 1 gives /2.
  create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant bufg_gt_div_val
  set_property -dict [list CONFIG.CONST_WIDTH {3} CONFIG.CONST_VAL {1}] [get_bd_cells bufg_gt_div_val]

  # RX: per-lane full-rate + half-rate buffers
  foreach ch {0 1 2 3} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:bufg_gt bufg_gt_rx$ch
    connect_bd_net [get_bd_pins ch${ch}_rxoutclk] [get_bd_pins bufg_gt_rx$ch/outclk]

    create_bd_cell -type ip -vlnv xilinx.com:ip:bufg_gt bufg_gt_rx_div2_$ch
    connect_bd_net [get_bd_pins ch${ch}_rxoutclk] [get_bd_pins bufg_gt_rx_div2_$ch/outclk]
    connect_bd_net [get_bd_pins bufg_gt_div_val/dout] [get_bd_pins bufg_gt_rx_div2_$ch/gt_bufgtdiv]
    # GT chN_rxusrclk takes the per-lane HALF-rate clock
    connect_bd_net [get_bd_pins bufg_gt_rx_div2_$ch/usrclk] [get_bd_pins ch${ch}_rxusrclk]
  }

  # TX: single ch0 full-rate + half-rate buffers feed all four TX lanes
  create_bd_cell -type ip -vlnv xilinx.com:ip:bufg_gt bufg_gt_tx0
  connect_bd_net [get_bd_pins ch0_txoutclk] [get_bd_pins bufg_gt_tx0/outclk]
  create_bd_cell -type ip -vlnv xilinx.com:ip:bufg_gt bufg_gt_tx_div2_0
  connect_bd_net [get_bd_pins ch0_txoutclk] [get_bd_pins bufg_gt_tx_div2_0/outclk]
  connect_bd_net [get_bd_pins bufg_gt_div_val/dout] [get_bd_pins bufg_gt_tx_div2_0/gt_bufgtdiv]
  # All four GT chN_txusrclk inputs take ch0's HALF-rate clock
  foreach ch {0 1 2 3} {
    connect_bd_net [get_bd_pins bufg_gt_tx_div2_0/usrclk] [get_bd_pins ch${ch}_txusrclk]
  }

  # MRMAC RX core + serdes clocks = per-lane FULL-rate, 4-bit bus {ch3,ch2,ch1,ch0}
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconcat:1.0 rx_serdes_clk_cat
  set_property CONFIG.NUM_PORTS {4} [get_bd_cells rx_serdes_clk_cat]
  foreach ch {0 1 2 3} {
    connect_bd_net [get_bd_pins bufg_gt_rx$ch/usrclk] [get_bd_pins rx_serdes_clk_cat/In$ch]
  }
  connect_bd_net [get_bd_pins rx_serdes_clk_cat/dout] [get_bd_pins mrmac/rx_core_clk]
  connect_bd_net [get_bd_pins rx_serdes_clk_cat/dout] [get_bd_pins mrmac/rx_serdes_clk]

  # MRMAC RX alt-serdes clock = per-lane HALF-rate, 4-bit bus {ch3,ch2,ch1,ch0}
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconcat:1.0 rx_alt_serdes_clk_cat
  set_property CONFIG.NUM_PORTS {4} [get_bd_cells rx_alt_serdes_clk_cat]
  foreach ch {0 1 2 3} {
    connect_bd_net [get_bd_pins bufg_gt_rx_div2_$ch/usrclk] [get_bd_pins rx_alt_serdes_clk_cat/In$ch]
  }
  connect_bd_net [get_bd_pins rx_alt_serdes_clk_cat/dout] [get_bd_pins mrmac/rx_alt_serdes_clk]

  # MRMAC TX core clock = ch0 FULL-rate on all four lanes
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconcat:1.0 tx_core_clk_cat
  set_property CONFIG.NUM_PORTS {4} [get_bd_cells tx_core_clk_cat]
  foreach ch {0 1 2 3} {
    connect_bd_net [get_bd_pins bufg_gt_tx0/usrclk] [get_bd_pins tx_core_clk_cat/In$ch]
  }
  connect_bd_net [get_bd_pins tx_core_clk_cat/dout] [get_bd_pins mrmac/tx_core_clk]

  # MRMAC TX alt-serdes clock = ch0 HALF-rate on all four lanes
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconcat:1.0 tx_alt_serdes_clk_cat
  set_property CONFIG.NUM_PORTS {4} [get_bd_cells tx_alt_serdes_clk_cat]
  foreach ch {0 1 2 3} {
    connect_bd_net [get_bd_pins bufg_gt_tx_div2_0/usrclk] [get_bd_pins tx_alt_serdes_clk_cat/In$ch]
  }
  connect_bd_net [get_bd_pins tx_alt_serdes_clk_cat/dout] [get_bd_pins mrmac/tx_alt_serdes_clk]

  #########################################################
  # MRMAC AXIS client clocks (390.625MHz) - tx_axi_clk/rx_axi_clk (4-bit bus,
  # driven from the single scalar axis_clk net).
  #########################################################
  connect_bd_net [get_bd_pins axis_clk] [get_bd_pins mrmac/tx_axi_clk]
  connect_bd_net [get_bd_pins axis_clk] [get_bd_pins mrmac/rx_axi_clk]

  #########################################################
  # MRMAC core/serdes resets (4-bit) - released by GT reset-done
  #########################################################
  # rx_core_reset / rx_serdes_reset = ~gt_rx_reset_done_out
  # tx_core_reset / tx_serdes_reset = ~gt_tx_reset_done_out
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilvector_logic:1.0 logic_rx_reset
  set_property -dict [list CONFIG.C_OPERATION {not} CONFIG.C_SIZE {4}] [get_bd_cells logic_rx_reset]
  connect_bd_net [get_bd_pins mrmac/gt_rx_reset_done_out] [get_bd_pins logic_rx_reset/Op1]
  connect_bd_net [get_bd_pins logic_rx_reset/Res] [get_bd_pins mrmac/rx_core_reset]
  connect_bd_net [get_bd_pins logic_rx_reset/Res] [get_bd_pins mrmac/rx_serdes_reset]

  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilvector_logic:1.0 logic_tx_reset
  set_property -dict [list CONFIG.C_OPERATION {not} CONFIG.C_SIZE {4}] [get_bd_cells logic_tx_reset]
  connect_bd_net [get_bd_pins mrmac/gt_tx_reset_done_out] [get_bd_pins logic_tx_reset/Op1]
  connect_bd_net [get_bd_pins logic_tx_reset/Res] [get_bd_pins mrmac/tx_core_reset]
  connect_bd_net [get_bd_pins logic_tx_reset/Res] [get_bd_pins mrmac/tx_serdes_reset]

  # rx_flexif_reset (4-bit) = ~periph_rstn on all four lanes (no PTP/flex used).
  # Replicate periph_rstn to 4 bits, then invert with a 4-bit NOT.
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconcat:1.0 periph_rstn_cat
  set_property CONFIG.NUM_PORTS {4} [get_bd_cells periph_rstn_cat]
  foreach ch {0 1 2 3} {
    connect_bd_net [get_bd_pins periph_rstn] [get_bd_pins periph_rstn_cat/In$ch]
  }
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilvector_logic:1.0 logic_not_rstn
  set_property -dict [list CONFIG.C_OPERATION {not} CONFIG.C_SIZE {4}] [get_bd_cells logic_not_rstn]
  connect_bd_net [get_bd_pins periph_rstn_cat/dout] [get_bd_pins logic_not_rstn/Op1]
  connect_bd_net [get_bd_pins logic_not_rstn/Res] [get_bd_pins mrmac/rx_flexif_reset]

  #########################################################
  # Tie off unused MRMAC clocks (flexif/ts) and pm_tick to 0 (no PTP)
  #########################################################
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconstant:1.0 const_zero4
  set_property -dict [list CONFIG.CONST_WIDTH {4} CONFIG.CONST_VAL {0}] [get_bd_cells const_zero4]
  connect_bd_net [get_bd_pins const_zero4/dout] [get_bd_pins mrmac/tx_flexif_clk]
  connect_bd_net [get_bd_pins const_zero4/dout] [get_bd_pins mrmac/rx_flexif_clk]
  connect_bd_net [get_bd_pins const_zero4/dout] [get_bd_pins mrmac/tx_ts_clk]
  connect_bd_net [get_bd_pins const_zero4/dout] [get_bd_pins mrmac/rx_ts_clk]
  connect_bd_net [get_bd_pins const_zero4/dout] [get_bd_pins mrmac/pm_tick]

  #########################################################
  # AXI MCDMA datapath
  #########################################################
  create_bd_cell -type ip -vlnv xilinx.com:ip:axi_mcdma axi_mcdma
  set_property -dict [list \
    CONFIG.c_num_mm2s_channels {1} \
    CONFIG.c_num_s2mm_channels {1} \
    CONFIG.c_include_mm2s {1} \
    CONFIG.c_include_s2mm {1} \
    CONFIG.c_include_mm2s_dre {1} \
    CONFIG.c_include_s2mm_dre {1} \
    CONFIG.c_sg_length_width {14} \
    CONFIG.c_addr_width {64} \
    CONFIG.c_m_axi_mm2s_data_width {512} \
    CONFIG.c_m_axi_s2mm_data_width {512} \
    CONFIG.c_m_axis_mm2s_tdata_width {512} \
  ] [get_bd_cells axi_mcdma]
  connect_bd_net [get_bd_pins sys_clk] [get_bd_pins axi_mcdma/s_axi_lite_aclk]
  connect_bd_net [get_bd_pins sys_clk] [get_bd_pins axi_mcdma/s_axi_aclk]
  connect_bd_net [get_bd_pins periph_rstn] [get_bd_pins axi_mcdma/axi_resetn]
  connect_bd_net [get_bd_pins axi_mcdma/mm2s_ch1_introut] [get_bd_pins dma_mm2s_introut]
  connect_bd_net [get_bd_pins axi_mcdma/s2mm_ch1_introut] [get_bd_pins dma_s2mm_introut]

  # MCDMA memory-mapped interfaces (to NoC)
  connect_bd_intf_net [get_bd_intf_pins axi_mcdma/M_AXI_SG]   -boundary_type upper [get_bd_intf_pins m_axi_sg]
  connect_bd_intf_net [get_bd_intf_pins axi_mcdma/M_AXI_MM2S] -boundary_type upper [get_bd_intf_pins m_axi_mm2s]
  connect_bd_intf_net [get_bd_intf_pins axi_mcdma/M_AXI_S2MM] -boundary_type upper [get_bd_intf_pins m_axi_s2mm]

  #########################################################
  # AXI-Lite SmartConnect (mrmac s_axi + mcdma s_axi_lite + gt-ctrl gpio)
  #########################################################
  # M00 -> mrmac/s_axi, M01 -> mcdma/S_AXI_LITE, M02 -> axi_gpio_gt$label/S_AXI
  create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect axi_smc_lite
  set_property CONFIG.NUM_MI {3} [get_bd_cells axi_smc_lite]
  connect_bd_net [get_bd_pins sys_clk] [get_bd_pins axi_smc_lite/aclk]
  connect_bd_net [get_bd_pins intercon_rstn] [get_bd_pins axi_smc_lite/aresetn]
  connect_bd_intf_net [get_bd_intf_pins S_AXI_LITE] [get_bd_intf_pins axi_smc_lite/S00_AXI]
  connect_bd_intf_net [get_bd_intf_pins axi_smc_lite/M01_AXI] [get_bd_intf_pins axi_mcdma/S_AXI_LITE]
  # axi_smc_lite/M00_AXI -> mrmac/s_axi is connected at the end of this proc,
  # together with mrmac/s_axi_aclk (see PHASE note at MRMAC creation).

  #########################################################
  # GT control GPIO (lets the Linux axienet driver reset the GT and read
  # reset-done). Dual-channel AXI GPIO -> ONE Linux gpiochip:
  #   Channel 1 (5 outputs): bit0=gt_reset_all, bit1=gt_reset_tx_datapath,
  #                          bit2=gt_reset_rx_datapath, bits3-4=gt-ctrl-rate (spare)
  #   Channel 2 (2 inputs):  bit0=gt_tx_reset_done, bit1=gt_rx_reset_done
  #########################################################
  create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_gt$label
  set_property -dict [list \
    CONFIG.C_GPIO_WIDTH {5} \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_IS_DUAL {1} \
    CONFIG.C_GPIO2_WIDTH {2} \
    CONFIG.C_ALL_INPUTS_2 {1} \
  ] [get_bd_cells axi_gpio_gt$label]
  connect_bd_net [get_bd_pins sys_clk] [get_bd_pins axi_gpio_gt$label/s_axi_aclk]
  connect_bd_net [get_bd_pins periph_rstn] [get_bd_pins axi_gpio_gt$label/s_axi_aresetn]
  connect_bd_intf_net [get_bd_intf_pins axi_smc_lite/M02_AXI] [get_bd_intf_pins axi_gpio_gt$label/S_AXI]

  # Channel 1 outputs (5-bit gpio_io_o). The mrmac gt_reset_*_in pins are each
  # 4-bit (one bit per bonded lane), so for each control bit we slice it out of
  # gpio_io_o (1-bit) then replicate it to all 4 lanes via a 4-port ilconcat
  # (same scalar-net broadcast pattern as periph_rstn_cat).
  #   gpio bit0 -> gt_reset_all_in[3:0]
  #   gpio bit1 -> gt_reset_tx_datapath_in[3:0]
  #   gpio bit2 -> gt_reset_rx_datapath_in[3:0]
  # gpio bits 3-4 (gt-ctrl-rate) are spare and left unconnected.
  foreach {nm bit pin} {
    gt_rst_all 0 gt_reset_all_in
    gt_rst_tx  1 gt_reset_tx_datapath_in
    gt_rst_rx  2 gt_reset_rx_datapath_in
  } {
    create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilslice:1.0 slice_${nm}$label
    set_property -dict [list CONFIG.DIN_WIDTH {5} CONFIG.DIN_FROM $bit CONFIG.DIN_TO $bit CONFIG.DOUT_WIDTH {1}] [get_bd_cells slice_${nm}$label]
    connect_bd_net [get_bd_pins axi_gpio_gt$label/gpio_io_o] [get_bd_pins slice_${nm}$label/Din]
    create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconcat:1.0 cat_${nm}$label
    set_property CONFIG.NUM_PORTS {4} [get_bd_cells cat_${nm}$label]
    foreach ch {0 1 2 3} {
      connect_bd_net [get_bd_pins slice_${nm}$label/Dout] [get_bd_pins cat_${nm}$label/In$ch]
    }
    connect_bd_net [get_bd_pins cat_${nm}$label/dout] [get_bd_pins mrmac/$pin]
  }

  # Channel 2 inputs <- mrmac GT reset-done outputs (each 4-bit, one per bonded
  # lane). Take lane-0's done bit from each and concat into the 2-bit gpio2_io_i:
  #   gpio2 bit0 = gt_tx_reset_done_out[0]
  #   gpio2 bit1 = gt_rx_reset_done_out[0]
  # These outputs already drive logic_tx_reset/logic_rx_reset; the extra slices
  # are just additional loads on the same nets (existing conns left intact).
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilslice:1.0 slice_gt_tx_done$label
  set_property -dict [list CONFIG.DIN_WIDTH {4} CONFIG.DIN_FROM {0} CONFIG.DIN_TO {0} CONFIG.DOUT_WIDTH {1}] [get_bd_cells slice_gt_tx_done$label]
  connect_bd_net [get_bd_pins mrmac/gt_tx_reset_done_out] [get_bd_pins slice_gt_tx_done$label/Din]
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilslice:1.0 slice_gt_rx_done$label
  set_property -dict [list CONFIG.DIN_WIDTH {4} CONFIG.DIN_FROM {0} CONFIG.DIN_TO {0} CONFIG.DOUT_WIDTH {1}] [get_bd_cells slice_gt_rx_done$label]
  connect_bd_net [get_bd_pins mrmac/gt_rx_reset_done_out] [get_bd_pins slice_gt_rx_done$label/Din]
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconcat:1.0 gt_rst_done_cat$label
  set_property CONFIG.NUM_PORTS {2} [get_bd_cells gt_rst_done_cat$label]
  connect_bd_net [get_bd_pins slice_gt_tx_done$label/Dout] [get_bd_pins gt_rst_done_cat$label/In0]
  connect_bd_net [get_bd_pins slice_gt_rx_done$label/Dout] [get_bd_pins gt_rst_done_cat$label/In1]
  connect_bd_net [get_bd_pins gt_rst_done_cat$label/dout] [get_bd_pins axi_gpio_gt$label/gpio2_io_i]

  #########################################################
  # TX datapath: MCDMA(512b, sys_clk) -> CDC fifo -> dwidth(512->384) -> MRMAC tx(384b, axis_clk)
  #########################################################
  create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo tx_cdc_fifo
  set_property -dict [list \
    CONFIG.FIFO_DEPTH {512} \
    CONFIG.IS_ACLK_ASYNC {1} \
    CONFIG.FIFO_MODE {2} \
  ] [get_bd_cells tx_cdc_fifo]
  connect_bd_intf_net [get_bd_intf_pins axi_mcdma/M_AXIS_MM2S] [get_bd_intf_pins tx_cdc_fifo/S_AXIS]
  connect_bd_net [get_bd_pins sys_clk]  [get_bd_pins tx_cdc_fifo/s_axis_aclk]
  connect_bd_net [get_bd_pins periph_rstn] [get_bd_pins tx_cdc_fifo/s_axis_aresetn]
  connect_bd_net [get_bd_pins axis_clk] [get_bd_pins tx_cdc_fifo/m_axis_aclk]

  # TX dwidth: 64 bytes (512b, MCDMA side) -> 48 bytes (384b, MRMAC side).
  # The MRMAC AXIS does not propagate a TDATA width, so set both sides
  # explicitly. TLAST is carried; TKEEP added on the MCDMA (wide) side.
  create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter tx_dwidth
  set_property -dict [list \
    CONFIG.S_TDATA_NUM_BYTES {64} \
    CONFIG.M_TDATA_NUM_BYTES {48} \
    CONFIG.HAS_TLAST {1} \
    CONFIG.HAS_TKEEP {1} \
  ] [get_bd_cells tx_dwidth]
  connect_bd_net [get_bd_pins axis_clk] [get_bd_pins tx_dwidth/aclk]
  connect_bd_net [get_bd_pins axis_rstn] [get_bd_pins tx_dwidth/aresetn]
  connect_bd_intf_net [get_bd_intf_pins tx_cdc_fifo/M_AXIS] [get_bd_intf_pins tx_dwidth/S_AXIS]
  # TX adapter: standard 384b AXIS (from tx_dwidth) -> MRMAC 6-lane client.
  # The MRMAC axis_tx_port0 BD interface is handshake-only (TDATA_NUM_BYTES=0);
  # the data rides on loose ports tx_axis_tdata0..5 + tx_axis_tkeep_user0..5, so
  # we cannot connect tx_dwidth straight to axis_tx_port0 (that mis-delineated
  # frames). The adapter splits the 384b AXIS into the six MRMAC lanes.
  create_bd_cell -type module -reference mrmac_tx_axis_adapter tx_axis_adapter
  connect_bd_net [get_bd_pins axis_clk] [get_bd_pins tx_axis_adapter/aclk]
  connect_bd_intf_net [get_bd_intf_pins tx_dwidth/M_AXIS] [get_bd_intf_pins tx_axis_adapter/S_AXIS]
  foreach ln {0 1 2 3 4 5} {
    connect_bd_net [get_bd_pins tx_axis_adapter/tx_axis_tdata$ln]      [get_bd_pins mrmac/tx_axis_tdata$ln]
    connect_bd_net [get_bd_pins tx_axis_adapter/tx_axis_tkeep_user$ln] [get_bd_pins mrmac/tx_axis_tkeep_user$ln]
  }
  connect_bd_net [get_bd_pins tx_axis_adapter/tx_axis_tlast]  [get_bd_pins mrmac/tx_axis_tlast_0]
  connect_bd_net [get_bd_pins tx_axis_adapter/tx_axis_tvalid] [get_bd_pins mrmac/tx_axis_tvalid_0]
  connect_bd_net [get_bd_pins mrmac/tx_axis_tready_0]         [get_bd_pins tx_axis_adapter/tx_axis_tready]

  #########################################################
  # RX datapath: MRMAC rx(384b, axis_clk) -> dwidth(384->512) -> CDC fifo -> MCDMA(512b, sys_clk)
  #########################################################
  # RX dwidth: 48 bytes (384b, MRMAC side) -> 64 bytes (512b, MCDMA side).
  create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter rx_dwidth
  set_property -dict [list \
    CONFIG.S_TDATA_NUM_BYTES {48} \
    CONFIG.M_TDATA_NUM_BYTES {64} \
    CONFIG.HAS_TLAST {1} \
    CONFIG.HAS_TKEEP {1} \
  ] [get_bd_cells rx_dwidth]
  connect_bd_net [get_bd_pins axis_clk] [get_bd_pins rx_dwidth/aclk]
  connect_bd_net [get_bd_pins axis_rstn] [get_bd_pins rx_dwidth/aresetn]
  # RX adapter: MRMAC 6-lane client -> standard 384b AXIS (into rx_dwidth).
  # axis_rx_port0 is handshake-only; data is on loose ports rx_axis_tdata0..5 +
  # rx_axis_tkeep_user0..5. Connecting axis_rx_port0 straight to rx_dwidth made
  # the converter assert TLAST every beat (each 384b beat became one packet ->
  # frames fragmented into ~48-byte pieces). The adapter packs the six lanes
  # into one 384b word and passes the single per-frame TLAST through.
  create_bd_cell -type module -reference mrmac_rx_axis_adapter rx_axis_adapter
  connect_bd_net [get_bd_pins axis_clk] [get_bd_pins rx_axis_adapter/aclk]
  foreach ln {0 1 2 3 4 5} {
    connect_bd_net [get_bd_pins mrmac/rx_axis_tdata$ln]      [get_bd_pins rx_axis_adapter/rx_axis_tdata$ln]
    connect_bd_net [get_bd_pins mrmac/rx_axis_tkeep_user$ln] [get_bd_pins rx_axis_adapter/rx_axis_tkeep_user$ln]
  }
  connect_bd_net [get_bd_pins mrmac/rx_axis_tlast_0]  [get_bd_pins rx_axis_adapter/rx_axis_tlast]
  connect_bd_net [get_bd_pins mrmac/rx_axis_tvalid_0] [get_bd_pins rx_axis_adapter/rx_axis_tvalid]
  connect_bd_intf_net [get_bd_intf_pins rx_axis_adapter/M_AXIS] [get_bd_intf_pins rx_dwidth/S_AXIS]

  create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo rx_cdc_fifo
  set_property -dict [list \
    CONFIG.FIFO_DEPTH {512} \
    CONFIG.IS_ACLK_ASYNC {1} \
    CONFIG.FIFO_MODE {2} \
  ] [get_bd_cells rx_cdc_fifo]
  connect_bd_intf_net [get_bd_intf_pins rx_dwidth/M_AXIS] [get_bd_intf_pins rx_cdc_fifo/S_AXIS]
  connect_bd_net [get_bd_pins axis_clk] [get_bd_pins rx_cdc_fifo/s_axis_aclk]
  connect_bd_net [get_bd_pins axis_rstn] [get_bd_pins rx_cdc_fifo/s_axis_aresetn]
  connect_bd_net [get_bd_pins sys_clk]  [get_bd_pins rx_cdc_fifo/m_axis_aclk]
  connect_bd_intf_net [get_bd_intf_pins rx_cdc_fifo/M_AXIS] [get_bd_intf_pins axi_mcdma/S_AXIS_S2MM]

  #########################################################
  # MRMAC AXI-Lite control (connected last - see note at MRMAC creation)
  #########################################################
  connect_bd_net [get_bd_pins sys_clk] [get_bd_pins mrmac/s_axi_aclk]
  connect_bd_net [get_bd_pins periph_rstn] [get_bd_pins mrmac/s_axi_aresetn]
  connect_bd_intf_net [get_bd_intf_pins axi_smc_lite/M00_AXI] [get_bd_intf_pins mrmac/s_axi]

  #########################################################
  # User LEDs
  #########################################################
  # Green LED = RX aligned (link up) on port 0; Red LED = NOT aligned.
  connect_bd_net [get_bd_pins mrmac/stat_rx_status_0] [get_bd_pins grn_led]
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilvector_logic:1.0 logic_red_led
  set_property -dict [list CONFIG.C_OPERATION {not} CONFIG.C_SIZE {1}] [get_bd_cells logic_red_led]
  connect_bd_net [get_bd_pins mrmac/stat_rx_status_0] [get_bd_pins logic_red_led/Op1]
  connect_bd_net [get_bd_pins logic_red_led/Res] [get_bd_pins red_led]

  current_bd_instance \
}

# Create each QSFP port
foreach label $ports {
  create_qsfp_port $label

  # Connect clocks/resets
  connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins qsfp_port$label/sys_clk]
  connect_bd_net [get_bd_pins $axis_clk] [get_bd_pins qsfp_port$label/axis_clk]
  connect_bd_net [get_bd_pins rst_100m/peripheral_aresetn] [get_bd_pins qsfp_port$label/periph_rstn]
  connect_bd_net [get_bd_pins rst_100m/interconnect_aresetn] [get_bd_pins qsfp_port$label/intercon_rstn]
  connect_bd_net [get_bd_pins rst_390m625/peripheral_aresetn] [get_bd_pins qsfp_port$label/axis_rstn]
  # Each QSFP port has its own GT quad (gt_quad_base_$label): port 0 = slot 0
  # (DP0-3), port 1 = slot 1 (DP4-7).
  set gtq gt_quad_base_$label
  connect_bd_net [get_bd_pins $gtq/gtpowergood] [get_bd_pins qsfp_port$label/gtpowergood_in]

  # GT serdes interfaces (4 lanes) and per-channel out/usr clocks
  foreach ch {0 1 2 3} {
    connect_bd_intf_net [get_bd_intf_pins qsfp_port$label/gt_tx_serdes_interface_$ch] [get_bd_intf_pins $gtq/TX${ch}_GT_IP_Interface]
    connect_bd_intf_net [get_bd_intf_pins qsfp_port$label/gt_rx_serdes_interface_$ch] [get_bd_intf_pins $gtq/RX${ch}_GT_IP_Interface]
    connect_bd_net [get_bd_pins $gtq/ch${ch}_txoutclk] [get_bd_pins qsfp_port$label/ch${ch}_txoutclk]
    connect_bd_net [get_bd_pins $gtq/ch${ch}_rxoutclk] [get_bd_pins qsfp_port$label/ch${ch}_rxoutclk]
    connect_bd_net [get_bd_pins qsfp_port$label/ch${ch}_txusrclk] [get_bd_pins $gtq/ch${ch}_txusrclk]
    connect_bd_net [get_bd_pins qsfp_port$label/ch${ch}_rxusrclk] [get_bd_pins $gtq/ch${ch}_rxusrclk]
  }

  # MCDMA MM interfaces to NoC (SG, MM2S, S2MM)
  # SG / MM2S / S2MM each take a NoC slave port, mapped to memory-controller
  # ports MC_0 / MC_1 / MC_2. Both QSFP ports share the same MC ports (the
  # single DDR controller); the NoC arbitrates. CONNECTIONS must be set per SI.
  foreach {intf mc} {m_axi_sg MC_0 m_axi_mm2s MC_1 m_axi_s2mm MC_2} {
    set index_padded [format "%02d" $noc_port_index]
    set_property -dict [list CONFIG.CONNECTIONS [list $mc {read_bw {500} write_bw {500} read_avg_burst {4} write_avg_burst {4}}]] [get_bd_intf_pins /axi_noc_0/S${index_padded}_AXI]
    connect_bd_intf_net [get_bd_intf_pins qsfp_port$label/$intf] [get_bd_intf_pins axi_noc_0/S${index_padded}_AXI]
    set noc_port_index [expr {$noc_port_index + 1}]
  }

  # All MCDMA NoC ports share aclk6 (system clock), already connected above.

  # AXI-Lite control interface (port control aggregate: mrmac + mcdma + gt gpio)
  connect_bd_intf_net [get_bd_intf_pins qsfp_port$label/S_AXI_LITE] [get_bd_intf_pins axi_smc/M[format "%02d" $smc_mi]_AXI]
  incr smc_mi

  # External LED ports
  create_bd_port -dir O grn_led_qsfp$label
  create_bd_port -dir O red_led_qsfp$label
  connect_bd_net [get_bd_pins qsfp_port$label/grn_led] [get_bd_ports grn_led_qsfp$label]
  connect_bd_net [get_bd_pins qsfp_port$label/red_led] [get_bd_ports red_led_qsfp$label]

  # Interrupts
  lappend intr_list "qsfp_port$label/dma_mm2s_introut"
  lappend intr_list "qsfp_port$label/dma_s2mm_introut"

  #########################################################
  # QSFP sideband GPIO (per port)
  #########################################################
  # Channel 1 (outputs): bit0=modsell, bit1=resetl, bit2=lpmode
  # Channel 2 (inputs):  bit0=modprsl, bit1=intl
  #
  # Power-on default 0x2 -> modsell=0, resetl=1 (deasserted, active-low),
  # lpmode=0 (high power). resetl MUST default high or the QSFP module powers
  # up held in reset (laser off, no link) until software writes the GPIO. The
  # sfp28-fmc-xxv reference hard-ties its SFP tx_disable to const_low for the
  # same "module enabled at config time" behaviour; here we keep the line
  # software-controllable (modsell/lpmode/resetl on the GPIO) but default it to
  # the enabled state. Nothing else drives this signal (no driver/gpio-hog).
  create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_qsfp$label
  set_property -dict [list \
    CONFIG.C_GPIO_WIDTH {3} \
    CONFIG.C_GPIO2_WIDTH {2} \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_ALL_INPUTS_2 {1} \
    CONFIG.C_IS_DUAL {1} \
    CONFIG.C_DOUT_DEFAULT {0x00000002} \
  ] [get_bd_cells axi_gpio_qsfp$label]
  connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_gpio_qsfp$label/s_axi_aclk]
  connect_bd_net [get_bd_pins rst_100m/peripheral_aresetn] [get_bd_pins axi_gpio_qsfp$label/s_axi_aresetn]
  connect_bd_intf_net [get_bd_intf_pins axi_smc/M[format "%02d" $smc_mi]_AXI] [get_bd_intf_pins axi_gpio_qsfp$label/S_AXI]
  incr smc_mi

  # GPIO channel 1 outputs -> modsell/resetl/lpmode
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilslice:1.0 slice_modsell$label
  set_property -dict [list CONFIG.DIN_WIDTH {3} CONFIG.DIN_FROM {0} CONFIG.DIN_TO {0} CONFIG.DOUT_WIDTH {1}] [get_bd_cells slice_modsell$label]
  connect_bd_net [get_bd_pins axi_gpio_qsfp$label/gpio_io_o] [get_bd_pins slice_modsell$label/Din]
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilslice:1.0 slice_resetl$label
  set_property -dict [list CONFIG.DIN_WIDTH {3} CONFIG.DIN_FROM {1} CONFIG.DIN_TO {1} CONFIG.DOUT_WIDTH {1}] [get_bd_cells slice_resetl$label]
  connect_bd_net [get_bd_pins axi_gpio_qsfp$label/gpio_io_o] [get_bd_pins slice_resetl$label/Din]
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilslice:1.0 slice_lpmode$label
  set_property -dict [list CONFIG.DIN_WIDTH {3} CONFIG.DIN_FROM {2} CONFIG.DIN_TO {2} CONFIG.DOUT_WIDTH {1}] [get_bd_cells slice_lpmode$label]
  connect_bd_net [get_bd_pins axi_gpio_qsfp$label/gpio_io_o] [get_bd_pins slice_lpmode$label/Din]

  create_bd_port -dir O modsell_qsfp$label
  create_bd_port -dir O resetl_qsfp$label
  create_bd_port -dir O lpmode_qsfp$label
  connect_bd_net [get_bd_pins slice_modsell$label/Dout] [get_bd_ports modsell_qsfp$label]
  connect_bd_net [get_bd_pins slice_resetl$label/Dout] [get_bd_ports resetl_qsfp$label]
  connect_bd_net [get_bd_pins slice_lpmode$label/Dout] [get_bd_ports lpmode_qsfp$label]

  # GPIO channel 2 inputs <- modprsl/intl
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconcat:1.0 qsfp_in_cat$label
  set_property CONFIG.NUM_PORTS {2} [get_bd_cells qsfp_in_cat$label]
  create_bd_port -dir I modprsl_qsfp$label
  create_bd_port -dir I intl_qsfp$label
  connect_bd_net [get_bd_ports modprsl_qsfp$label] [get_bd_pins qsfp_in_cat$label/In0]
  connect_bd_net [get_bd_ports intl_qsfp$label] [get_bd_pins qsfp_in_cat$label/In1]
  connect_bd_net [get_bd_pins qsfp_in_cat$label/dout] [get_bd_pins axi_gpio_qsfp$label/gpio2_io_i]

  #########################################################
  # QSFP module management I2C (per port)
  #########################################################
  create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic axi_iic_qsfp$label
  connect_bd_intf_net [get_bd_intf_pins axi_smc/M[format "%02d" $smc_mi]_AXI] [get_bd_intf_pins axi_iic_qsfp$label/S_AXI]
  incr smc_mi
  connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_iic_qsfp$label/s_axi_aclk]
  connect_bd_net [get_bd_pins rst_100m/peripheral_aresetn] [get_bd_pins axi_iic_qsfp$label/s_axi_aresetn]
  lappend intr_list "axi_iic_qsfp$label/iic2intc_irpt"
  create_bd_intf_port -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 qsfp${label}_i2c
  connect_bd_intf_net [get_bd_intf_ports qsfp${label}_i2c] [get_bd_intf_pins axi_iic_qsfp$label/IIC]
}

#########################################################
# Shared I2C bus (direct, no PCA9548 mux)
#########################################################
# clk_i2c : Si5328 jitter-attenuating clock generator (one per board, shared by
# both QSFP ports - it sources both GBTCLK0 and GBTCLK1 reference clocks).
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic axi_iic_clk
connect_bd_intf_net [get_bd_intf_pins axi_smc/M[format "%02d" $smc_mi]_AXI] [get_bd_intf_pins axi_iic_clk/S_AXI]
incr smc_mi
connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_iic_clk/s_axi_aclk]
connect_bd_net [get_bd_pins rst_100m/peripheral_aresetn] [get_bd_pins axi_iic_clk/s_axi_aresetn]
lappend intr_list "axi_iic_clk/iic2intc_irpt"
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 clk_i2c
connect_bd_intf_net [get_bd_intf_ports clk_i2c] [get_bd_intf_pins axi_iic_clk/IIC]

# Connect the interrupts to CIPS
set intr_index 0
foreach intr $intr_list {
  connect_bd_net [get_bd_pins $intr] [get_bd_pins versal_cips_0/pl_ps_irq$intr_index]
  set intr_index [expr {$intr_index+1}]
}

# Assign addresses
assign_bd_address

# Layout and validate
regenerate_bd_layout
save_bd_design
validate_bd_design
save_bd_design
