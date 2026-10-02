################################################################
# Block design build script for Zynq UltraScale+ QSFP28 designs
#
# Opsero 2x QSFP28 FMC reference design.
#
# This script is sourced by build.tcl, which sets:
#   block_name = qsfp
#   board_name = zcu111 | zcu208 | zcu216 | zcu102 | zcu106
#   target     = zcu111 | zcu208 | zcu216 | zcu102_hpc0 | zcu106_hpc0
#                | zcu111_ss | zcu208_ss | zcu216_ss
#   ports      = { 0 } or { 0 1 }
#   line_rate  = 100 | 40
#
# ZynqMP has no MRMAC hard block, so the MAC depends on the line rate:
#   line_rate 100 (RFSoC: ZCU111/ZCU208/ZCU216, GTY):
#     UltraScale+ Integrated 100G Ethernet (cmac_usplus) hard block, CAUI-4
#     (4 lanes x 25.78125 Gb/s, GT refclk 322.265625 MHz), AXIS user
#     interface (512-bit) + AXI4-Lite control.
#     NOTE: only CMACE4_X0Y1 can reach GT quads X0Y12-15/X0Y16-19 (the IP
#     restricts CMACE4_X0Y0 to X0Y4-11 on all three devices), which is why
#     ZCU208/ZCU216 - whose FMC+ lanes sit on X0Y12-19 - are single-port
#     (2x100G is not physically possible there); ZCU111 (X0Y8-15) gets both.
#   line_rate 40 (ZCU102/ZCU106 on GTH; _ss variants of the RFSoC boards
#   on GTY):
#     40G/50G High Speed Ethernet Subsystem (l_ethernet) soft MAC/PCS,
#     40GBASE-R4 (4 lanes x 10.3125 Gb/s, GT refclk 156.25 MHz), 256-bit
#     regular AXI4-Stream + AXI4-Lite control. The soft MAC has no CMAC
#     placement restriction, so the RFSoC _ss variants enable BOTH QSFP28
#     ports - including on ZCU208/ZCU216 where the 100G target is
#     single-port.
#
# Both MACs present a standard AXI4-Stream client (no MRMAC-style custom
# adapters needed). Each QSFP port gets an AXI MCDMA datapath to the PS DDR
# via its own S_AXI_HPx_FPD port; the CPU handles all packets through the
# Linux xilinx_axienet driver (CMAC/l_ethernet support added by a kernel
# patch carried in the Yocto BSP).
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

# Number of ports
set num_ports [llength $ports]

# List of interrupt pins (wired to pl_ps_irq0, max 8)
set intr_list {}

# Per-target GT placement.
#
# 100G (cmac_usplus): port -> {CMAC_CORE_SELECT GT_GROUP_SELECT}. The FMC DP
# lanes of each port sit in one full GTY quad with that port's GBTCLK in the
# same quad (checked against the board pinouts and the device package files):
#   ZCU111 (ZU28DR): port 0 = bank 129 (X0Y8-11),  port 1 = bank 130 (X0Y12-15)
#   ZCU208 (ZU48DR): port 0 = bank 130 (X0Y12-15)  [port 1 = bank 131, no CMAC reach]
#   ZCU216 (ZU49DR): port 0 = bank 130 (X0Y12-15)  [port 1 = bank 131, no CMAC reach]
set cmac_map [dict create \
  zcu111 {0 {CMACE4_X0Y0 X0Y8~X0Y11} 1 {CMACE4_X0Y1 X0Y12~X0Y15}} \
  zcu208 {0 {CMACE4_X0Y1 X0Y12~X0Y15}} \
  zcu216 {0 {CMACE4_X0Y1 X0Y12~X0Y15}} \
]

# 40G (l_ethernet): port -> GT_GROUP_SELECT (one full GT quad per port).
# GTH boards:
#   ZCU102 (ZU9EG): port 0 = bank 229 (Quad_X1Y2), port 1 = bank 228 (Quad_X1Y1)
#   ZCU106 (ZU7EV): port 0 = bank 226 (Quad_X0Y3), port 1 = bank 227 (Quad_X0Y4)
# GTY boards (RFSoC _ss variants; quads verified against the l_ethernet
# customization rules for each device):
#   ZCU111 (ZU28DR): port 0 = bank 129 (Quad_X0Y2), port 1 = bank 130 (Quad_X0Y3)
#   ZCU208 (ZU48DR): port 0 = bank 130 (Quad_X0Y3), port 1 = bank 131 (Quad_X0Y4)
#   ZCU216 (ZU49DR): port 0 = bank 130 (Quad_X0Y3), port 1 = bank 131 (Quad_X0Y4)
set leth_map [dict create \
  zcu102_hpc0 {0 Quad_X1Y2 1 Quad_X1Y1} \
  zcu106_hpc0 {0 Quad_X0Y3 1 Quad_X0Y4} \
  zcu111_ss   {0 Quad_X0Y2 1 Quad_X0Y3} \
  zcu208_ss   {0 Quad_X0Y3 1 Quad_X0Y4} \
  zcu216_ss   {0 Quad_X0Y3 1 Quad_X0Y4} \
]

# GT reference clock frequency (from the FMC Si5328: GBTCLK0 -> port 0,
# GBTCLK1 -> port 1; the port-config.dtsi programs the Si5328 to this value).
if {$line_rate == "100"} {
  set gt_refclk_hz 322265625
  set gt_refclk_mhz 322.265625
} else {
  set gt_refclk_hz 156250000
  set gt_refclk_mhz 156.25
}

# Add the Processor System and apply board preset
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" }  [get_bd_cells zynq_ultra_ps_e_0]

# Configure the PS: HPM0 LPD for AXI-Lite control, one HPx FPD port per QSFP
# port for the MCDMA datapath, PL-PS interrupts on IRQ0.
set_property -dict [list \
  CONFIG.PSU__USE__M_AXI_GP0 {0} \
  CONFIG.PSU__USE__M_AXI_GP1 {0} \
  CONFIG.PSU__USE__M_AXI_GP2 {1} \
  CONFIG.PSU__USE__IRQ0 {1} \
  CONFIG.PSU__HIGH_ADDRESS__ENABLE {1} \
] [get_bd_cells zynq_ultra_ps_e_0]

# System clock (pl_clk0, 100MHz) - all AXI-Lite control and the MCDMA/HP
# datapath run in this domain (mirrors the vck190 design's 100MHz sys_clk).
set sys_clk "zynq_ultra_ps_e_0/pl_clk0"

# Proc system reset for the system clock
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_ps_100m
connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins rst_ps_100m/slowest_sync_clk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] [get_bd_pins rst_ps_100m/ext_reset_in]

# Connect the HPM0 LPD clock
connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_lpd_aclk]

# AXI SmartConnect for the AXI-Lite control interfaces. Masters are allocated
# with a running counter (smc_mi): per QSFP port -> {port control aggregate,
# qsfp sideband GPIO, qsfp module I2C} = 3 each, plus 1 shared Si5328 clk I2C.
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect axi_smc
set_property -dict [list CONFIG.NUM_MI [expr {3 * $num_ports + 1}] CONFIG.NUM_SI {1} ] [get_bd_cells axi_smc]
connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_smc/aclk]
connect_bd_net [get_bd_pins rst_ps_100m/interconnect_aresetn] [get_bd_pins axi_smc/aresetn]
connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_LPD] [get_bd_intf_pins axi_smc/S00_AXI]
set smc_mi 0

#########################################################
# QSFP ports
#########################################################
#
# Each QSFP port instantiates:
#  - the MAC (cmac_usplus @100G or l_ethernet @40G) with its own in-core GT
#    quad and AXI4-Lite control interface
#  - an axi_mcdma datapath (512-bit MM/stream on sys_clk) with
#    axis_data_fifo CDC between the MAC client clock and sys_clk, and (40G
#    only) axis_dwidth_converter 512<->256
#  - an AXI SmartConnect aggregating the MCDMA's SG/MM2S/S2MM masters into
#    one S_AXI_HPx_FPD port
#

proc create_qsfp_port {label} {

  global line_rate target cmac_map leth_map gt_refclk_mhz

  set hier_obj [create_bd_cell -type hier qsfp_port$label]
  current_bd_instance $hier_obj

  # Pins
  create_bd_pin -dir I sys_clk
  create_bd_pin -dir I periph_rstn
  create_bd_pin -dir I -type rst periph_rst
  create_bd_pin -dir I intercon_rstn
  create_bd_pin -dir O dma_mm2s_introut
  create_bd_pin -dir O dma_s2mm_introut
  create_bd_pin -dir O grn_led
  create_bd_pin -dir O red_led
  create_bd_pin -dir O -from 29 -to 0 rx_drop_status

  # Interfaces
  create_bd_intf_pin -mode Slave  -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_LITE
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 m_axi_hp
  create_bd_intf_pin -mode Slave  -vlnv xilinx.com:interface:diff_clock_rtl:1.0 gt_ref_clk

  # Constants shared by the MAC tie-offs
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconstant:1.0 const_low
  set_property CONFIG.CONST_VAL {0} [get_bd_cells const_low]
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconstant:1.0 const_high
  set_property CONFIG.CONST_VAL {1} [get_bd_cells const_high]

  #########################################################
  # MAC
  #########################################################
  if {$line_rate == "100"} {
    #########################################################
    # 100G: UltraScale+ Integrated 100G Ethernet (CMAC hard block)
    #########################################################
    set cfg [dict get [dict get $cmac_map $target] $label]
    set cmac_core [lindex $cfg 0]
    set gt_group  [lindex $cfg 1]
    create_bd_cell -type ip -vlnv xilinx.com:ip:cmac_usplus cmac
    set_property -dict [list \
      CONFIG.CMAC_CAUI4_MODE {1} \
      CONFIG.NUM_LANES {4x25} \
      CONFIG.GT_REF_CLK_FREQ $gt_refclk_mhz \
      CONFIG.GT_DRP_CLK {100.00} \
      CONFIG.USER_INTERFACE {AXIS} \
      CONFIG.ENABLE_AXI_INTERFACE {1} \
      CONFIG.INCLUDE_RS_FEC {0} \
      CONFIG.CMAC_CORE_SELECT $cmac_core \
      CONFIG.GT_GROUP_SELECT $gt_group \
    ] [get_bd_cells cmac]

    # GT serial + refclk to the hier boundary
    create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:gt_rtl:1.0 qsfp_gt
    connect_bd_intf_net [get_bd_intf_pins cmac/gt_serial_port] [get_bd_intf_pins qsfp_gt]
    connect_bd_intf_net [get_bd_intf_pins gt_ref_clk] [get_bd_intf_pins cmac/gt_ref_clk]

    # Clocks: init/DRP/AXI-Lite on sys_clk; the AXIS client runs on the
    # CMAC's own gt_txusrclk2 (322.27MHz); the RX AXIS domain (rx_clk) is
    # driven from the same clock, per the cmac_usplus AXIS example design.
    connect_bd_net [get_bd_pins sys_clk] [get_bd_pins cmac/init_clk]
    connect_bd_net [get_bd_pins sys_clk] [get_bd_pins cmac/drp_clk]
    connect_bd_net [get_bd_pins sys_clk] [get_bd_pins cmac/s_axi_aclk]
    connect_bd_net [get_bd_pins cmac/gt_txusrclk2] [get_bd_pins cmac/rx_clk]
    set mac_tx_clk "cmac/gt_txusrclk2"
    set mac_rx_clk "cmac/gt_txusrclk2"

    # Resets: s_axi_sreset/sys_reset are ACTIVE-HIGH; core/gtwiz resets are
    # tied off (the Linux driver drives GT resets through the AXI GT_RESET
    # register instead).
    connect_bd_net [get_bd_pins periph_rst] [get_bd_pins cmac/s_axi_sreset]
    connect_bd_net [get_bd_pins periph_rst] [get_bd_pins cmac/sys_reset]
    foreach p {core_rx_reset core_tx_reset core_drp_reset gtwiz_reset_tx_datapath gtwiz_reset_rx_datapath} {
      connect_bd_net [get_bd_pins const_low/dout] [get_bd_pins cmac/$p]
    }

    # Tie-offs (no pause, no PTP tick from fabric - the driver uses TICK_REG)
    foreach p {ctl_tx_send_idle ctl_tx_send_lfi ctl_tx_send_rfi pm_tick} {
      connect_bd_net [get_bd_pins const_low/dout] [get_bd_pins cmac/$p]
    }

    # AXIS user-side resets (active-high, synchronous to the client clocks)
    set mac_tx_rst "cmac/usr_tx_reset"
    set mac_rx_rst "cmac/usr_rx_reset"
    set mac_axis_tx "cmac/axis_tx"
    set mac_axis_rx "cmac/axis_rx"
    set mac_axis_rx_tuser "cmac/rx_axis_tuser"
    set mac_s_axi "cmac/s_axi"
    set mac_link_up "cmac/stat_rx_aligned"
    set mac_bytes 64
  } else {
    #########################################################
    # 40G: 40G/50G High Speed Ethernet Subsystem (l_ethernet)
    #########################################################
    set gt_group [dict get [dict get $leth_map $target] $label]
    create_bd_cell -type ip -vlnv xilinx.com:ip:l_ethernet leth
    set_property -dict [list \
      CONFIG.LINE_RATE {40} \
      CONFIG.BASE_R_KR {BASE-R} \
      CONFIG.GT_REF_CLK_FREQ $gt_refclk_mhz \
      CONFIG.GT_DRP_CLK {100.00} \
      CONFIG.DATA_PATH_INTERFACE {256-bit Regular AXI4-Stream} \
      CONFIG.INCLUDE_AXI4_INTERFACE {1} \
      CONFIG.INCLUDE_STATISTICS_COUNTERS {1} \
      CONFIG.GT_GROUP_SELECT $gt_group \
    ] [get_bd_cells leth]

    # GT serial + refclk to the hier boundary
    create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:gt_rtl:1.0 qsfp_gt
    connect_bd_intf_net [get_bd_intf_pins leth/gt_serial_port] [get_bd_intf_pins qsfp_gt]
    connect_bd_intf_net [get_bd_intf_pins gt_ref_clk] [get_bd_intf_pins leth/gt_ref_clk]

    # Clocks: dclk/AXI-Lite on sys_clk; BOTH AXIS directions on tx_clk_out_0.
    # In this configuration (40G, 256-bit Regular AXI4-Stream, user FIFO,
    # "Asynchronous" clocking) the MAC core has ONE clock, tx_clk: the
    # generated l_ethernet wrapper instantiates the core with .clk(tx_clk)
    # and uses rx_core_clk only to synchronise the RX reset, and the routed
    # timing report shows every rx_axis_* bit launched by txoutclk_out. The
    # IP's own example design wires rx_core_clk_0 = tx_clk_out_0 the same
    # way (its CLOCKING parameter is fixed/disabled for this configuration,
    # so there is no IP option that expresses it). The
    # RX user FIFO inside the core crosses from the recovered clock
    # (rx_clk_out_0 / rx_serdes_clk) to tx_clk. rx_core_clk_0 and all RX
    # AXIS logic must therefore be on tx_clk_out_0 (with rx_clk_out_0
    # here, the RX AXIS was sampled by the recovered clock at a phase that
    # is arbitrary after every CDR lock, while Vivado timed the crossing as
    # synchronous -> fixed-bit corruption, wrong tkeep/tlast, silent loss).
    connect_bd_net [get_bd_pins sys_clk] [get_bd_pins leth/dclk]
    connect_bd_net [get_bd_pins sys_clk] [get_bd_pins leth/s_axi_aclk_0]
    connect_bd_net [get_bd_pins leth/tx_clk_out_0] [get_bd_pins leth/rx_core_clk_0]
    set mac_tx_clk "leth/tx_clk_out_0"
    set mac_rx_clk "leth/tx_clk_out_0"

    # Resets: s_axi_aresetn is ACTIVE-LOW; sys_reset active-high; the
    # tx/rx_reset datapath resets and gtwiz datapath resets are tied off
    # (the Linux driver drives GT resets through the AXI GT_RESET register).
    connect_bd_net [get_bd_pins periph_rstn] [get_bd_pins leth/s_axi_aresetn_0]
    connect_bd_net [get_bd_pins periph_rst] [get_bd_pins leth/sys_reset]
    foreach p {tx_reset_0 rx_reset_0 gtwiz_reset_tx_datapath_0 gtwiz_reset_rx_datapath_0} {
      connect_bd_net [get_bd_pins const_low/dout] [get_bd_pins leth/$p]
    }

    # Tie-offs
    foreach p {ctl_tx_send_idle_0 ctl_tx_send_lfi_0 ctl_tx_send_rfi_0 pm_tick_0} {
      connect_bd_net [get_bd_pins const_low/dout] [get_bd_pins leth/$p]
    }

    # tx/rxoutclksel: 3'b101 (PROGDIVCLK) per lane, 4 lanes -> 12'b101101101101
    create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconstant:1.0 const_clksel
    set_property -dict [list CONFIG.CONST_VAL {2925} CONFIG.CONST_WIDTH {12}] [get_bd_cells const_clksel]
    connect_bd_net [get_bd_pins const_clksel/dout] [get_bd_pins leth/txoutclksel_in_0]
    connect_bd_net [get_bd_pins const_clksel/dout] [get_bd_pins leth/rxoutclksel_in_0]

    set mac_tx_rst "leth/user_tx_reset_0"
    set mac_rx_rst "leth/user_rx_reset_0"
    set mac_axis_tx "leth/axis_tx_0"
    set mac_axis_rx "leth/axis_rx_0"
    set mac_axis_rx_tuser "leth/rx_axis_tuser_0"
    set mac_s_axi "leth/s_axi_0"
    set mac_link_up "leth/stat_rx_status_0"
    set mac_bytes 32
  }

  # Resets of the AXIS blocks in the MAC client clock domain(s):
  #   mac_tx_rstn  - TX chain on mac_tx_clk (tx_dwidth, tx_gate)
  #   tx_fifo_rstn - tx_cdc_fifo (its reset is in the sys_clk write domain)
  #   RX chain     - see "RX chain resets" below (same for both MACs)
  if {$mac_bytes == 32} {
    # l_ethernet: ONE MAC client clock, tx_clk_out_0 (see above). It STOPS
    # during a GT reset-all / TX reset and restarts afterwards, and the
    # MAC's user resets are synchronised in that clock, so they can only
    # be seen once it runs again.
    #  * rst_mac (tx_clk_out_0): the TX chain is reset after ANY
    #    interruption of that clock (user_tx_reset), and whenever the TX CDC
    #    FIFO is reset (aux input), so it is always released after the
    #    FIFO's read side, with the FIFO empty (axis_tx_frame_gate drops the
    #    tail of a frame cut by it).
    #  * rst_tx_fifo (sys_clk): the TX CDC FIFO is reset from its write
    #    (sys_clk) side on user_tx_reset or the peripheral reset, so a
    #    stopped/restarting read clock cannot leave its pointers inconsistent.
    # proc_sys_reset synchronises its inputs, stretches the reset and
    # releases it synchronously; its ext input filter is set to 1 clock so
    # that even the shortest user_tx_reset (1 tx clock) is never filtered out.
    create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_tx_fifo
    set_property CONFIG.C_AUX_RESET_HIGH.VALUE_SRC USER [get_bd_cells rst_tx_fifo]
    set_property -dict [list CONFIG.C_AUX_RESET_HIGH {1} CONFIG.C_EXT_RST_WIDTH {1}] [get_bd_cells rst_tx_fifo]
    connect_bd_net [get_bd_pins sys_clk] [get_bd_pins rst_tx_fifo/slowest_sync_clk]
    connect_bd_net [get_bd_pins $mac_tx_rst] [get_bd_pins rst_tx_fifo/ext_reset_in]
    connect_bd_net [get_bd_pins periph_rst] [get_bd_pins rst_tx_fifo/aux_reset_in]
    connect_bd_net [get_bd_pins const_high/dout] [get_bd_pins rst_tx_fifo/dcm_locked]

    create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_mac
    set_property CONFIG.C_AUX_RESET_HIGH.VALUE_SRC USER [get_bd_cells rst_mac]
    set_property -dict [list CONFIG.C_AUX_RESET_HIGH {1} CONFIG.C_EXT_RST_WIDTH {1}] [get_bd_cells rst_mac]
    connect_bd_net [get_bd_pins $mac_tx_clk] [get_bd_pins rst_mac/slowest_sync_clk]
    connect_bd_net [get_bd_pins $mac_tx_rst] [get_bd_pins rst_mac/ext_reset_in]
    connect_bd_net [get_bd_pins rst_tx_fifo/peripheral_reset] [get_bd_pins rst_mac/aux_reset_in]
    connect_bd_net [get_bd_pins const_high/dout] [get_bd_pins rst_mac/dcm_locked]

    set mac_tx_rstn  "rst_mac/peripheral_aresetn"
    set tx_fifo_rstn "rst_tx_fifo/peripheral_aresetn"
  } else {
    # CMAC TX (unchanged, HW-proven): active-low version of usr_tx_reset
    create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilvector_logic:1.0 logic_tx_rstn
    set_property -dict [list CONFIG.C_OPERATION {not} CONFIG.C_SIZE {1}] [get_bd_cells logic_tx_rstn]
    connect_bd_net [get_bd_pins $mac_tx_rst] [get_bd_pins logic_tx_rstn/Op1]
    set mac_tx_rstn  "logic_tx_rstn/Res"
    set tx_fifo_rstn "periph_rstn"
  }

  # RX chain resets (both MACs). The RX chain (rx_frame_fifo,
  # [rx_dwidth,] rx_cdc_fifo write side, all on mac_rx_clk) is NOT reset by
  # MAC/GT resets: resetting it could cut a frame the S2MM is reading and
  # merge its head with the next frame. Instead:
  #  * the MAC's RX reset (rx_abort) and TX reset / clock interruption
  #    (rx_hold; the MAC client clock stops on a GT reset) only make the
  #    frame FIFO discard its input frame in progress - committed frames and
  #    everything downstream drain normally (a clean BUFG_GT stop freezes
  #    them, they continue when the clock resumes);
  #  * the whole chain is flushed only when the S2MM is reset (every driver
  #    open/close, DMA error recovery, the hardware reset): rx_guard blocks
  #    the stream into the S2MM and requests rst_rx (mac_rx_clk), then
  #    releases the stream on a frame boundary (axis_rx_flush_guard.v).
  create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_rx
  set_property -dict [list CONFIG.C_EXT_RST_WIDTH {1}] [get_bd_cells rst_rx]
  connect_bd_net [get_bd_pins $mac_rx_clk] [get_bd_pins rst_rx/slowest_sync_clk]
  connect_bd_net [get_bd_pins const_high/dout] [get_bd_pins rst_rx/dcm_locked]
  create_bd_cell -type module -reference axis_rx_flush_guard rx_guard
  set_property CONFIG.DATA_W {512} [get_bd_cells rx_guard]
  connect_bd_net [get_bd_pins sys_clk] [get_bd_pins rx_guard/aclk]
  connect_bd_net [get_bd_pins rx_guard/flush_req] [get_bd_pins rst_rx/ext_reset_in]
  connect_bd_net [get_bd_pins rst_rx/peripheral_reset] [get_bd_pins rx_guard/flush_ack]
  set mac_rx_rstn  "rst_rx/peripheral_aresetn"
  set mac_rx_abort $mac_rx_rst
  set mac_rx_hold  $mac_tx_rst

  #########################################################
  # AXI MCDMA datapath (512-bit, sys_clk domain - mirrors the vck190 design)
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
    CONFIG.c_addr_width {40} \
    CONFIG.c_m_axi_mm2s_data_width {512} \
    CONFIG.c_m_axi_s2mm_data_width {512} \
    CONFIG.c_m_axis_mm2s_tdata_width {512} \
  ] [get_bd_cells axi_mcdma]
  connect_bd_net [get_bd_pins sys_clk] [get_bd_pins axi_mcdma/s_axi_lite_aclk]
  connect_bd_net [get_bd_pins sys_clk] [get_bd_pins axi_mcdma/s_axi_aclk]
  connect_bd_net [get_bd_pins periph_rstn] [get_bd_pins axi_mcdma/axi_resetn]
  connect_bd_net [get_bd_pins axi_mcdma/mm2s_ch1_introut] [get_bd_pins dma_mm2s_introut]
  connect_bd_net [get_bd_pins axi_mcdma/s2mm_ch1_introut] [get_bd_pins dma_s2mm_introut]

  # MCDMA memory-mapped masters -> one HP port via SmartConnect
  create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect axi_smc_hp
  set_property -dict [list CONFIG.NUM_SI {3} CONFIG.NUM_MI {1}] [get_bd_cells axi_smc_hp]
  connect_bd_net [get_bd_pins sys_clk] [get_bd_pins axi_smc_hp/aclk]
  connect_bd_net [get_bd_pins intercon_rstn] [get_bd_pins axi_smc_hp/aresetn]
  connect_bd_intf_net [get_bd_intf_pins axi_mcdma/M_AXI_SG]   [get_bd_intf_pins axi_smc_hp/S00_AXI]
  connect_bd_intf_net [get_bd_intf_pins axi_mcdma/M_AXI_MM2S] [get_bd_intf_pins axi_smc_hp/S01_AXI]
  connect_bd_intf_net [get_bd_intf_pins axi_mcdma/M_AXI_S2MM] [get_bd_intf_pins axi_smc_hp/S02_AXI]
  connect_bd_intf_net [get_bd_intf_pins axi_smc_hp/M00_AXI] -boundary_type upper [get_bd_intf_pins m_axi_hp]

  #########################################################
  # AXI-Lite SmartConnect (MAC s_axi + mcdma s_axi_lite)
  #########################################################
  create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect axi_smc_lite
  set_property CONFIG.NUM_MI {2} [get_bd_cells axi_smc_lite]
  connect_bd_net [get_bd_pins sys_clk] [get_bd_pins axi_smc_lite/aclk]
  connect_bd_net [get_bd_pins intercon_rstn] [get_bd_pins axi_smc_lite/aresetn]
  connect_bd_intf_net [get_bd_intf_pins S_AXI_LITE] [get_bd_intf_pins axi_smc_lite/S00_AXI]
  connect_bd_intf_net [get_bd_intf_pins axi_smc_lite/M00_AXI] [get_bd_intf_pins $mac_s_axi]
  connect_bd_intf_net [get_bd_intf_pins axi_smc_lite/M01_AXI] [get_bd_intf_pins axi_mcdma/S_AXI_LITE]

  #########################################################
  # TX datapath: MCDMA(512b, sys_clk) -> CDC fifo -> [40G: dwidth 512->256] -> MAC
  #########################################################
  create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo tx_cdc_fifo
  set_property -dict [list \
    CONFIG.FIFO_DEPTH {512} \
    CONFIG.IS_ACLK_ASYNC {1} \
    CONFIG.FIFO_MODE {2} \
  ] [get_bd_cells tx_cdc_fifo]
  connect_bd_intf_net [get_bd_intf_pins axi_mcdma/M_AXIS_MM2S] [get_bd_intf_pins tx_cdc_fifo/S_AXIS]
  connect_bd_net [get_bd_pins sys_clk]  [get_bd_pins tx_cdc_fifo/s_axis_aclk]
  connect_bd_net [get_bd_pins $tx_fifo_rstn] [get_bd_pins tx_cdc_fifo/s_axis_aresetn]
  connect_bd_net [get_bd_pins $mac_tx_clk] [get_bd_pins tx_cdc_fifo/m_axis_aclk]

  if {$mac_bytes == 64} {
    # 100G: MCDMA and CMAC are both 512-bit - direct connection
    connect_bd_intf_net [get_bd_intf_pins tx_cdc_fifo/M_AXIS] [get_bd_intf_pins $mac_axis_tx]
  } else {
    # 40G: 64 bytes (MCDMA) -> 32 bytes (l_ethernet)
    create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter tx_dwidth
    set_property -dict [list \
      CONFIG.S_TDATA_NUM_BYTES {64} \
      CONFIG.M_TDATA_NUM_BYTES {32} \
      CONFIG.HAS_TLAST {1} \
      CONFIG.HAS_TKEEP {1} \
    ] [get_bd_cells tx_dwidth]
    connect_bd_net [get_bd_pins $mac_tx_clk] [get_bd_pins tx_dwidth/aclk]
    connect_bd_net [get_bd_pins $mac_tx_rstn] [get_bd_pins tx_dwidth/aresetn]
    connect_bd_intf_net [get_bd_intf_pins tx_cdc_fifo/M_AXIS] [get_bd_intf_pins tx_dwidth/S_AXIS]
    # After a TX-side reset, drop the tail of a frame whose head was flushed
    # (axis_tx_frame_gate.v) instead of sending it as a frame of its own.
    create_bd_cell -type module -reference axis_tx_frame_gate tx_gate
    set_property CONFIG.DATA_W {256} [get_bd_cells tx_gate]
    connect_bd_net [get_bd_pins $mac_tx_clk] [get_bd_pins tx_gate/aclk]
    connect_bd_net [get_bd_pins $mac_tx_rstn] [get_bd_pins tx_gate/aresetn]
    connect_bd_intf_net [get_bd_intf_pins tx_dwidth/M_AXIS] [get_bd_intf_pins tx_gate/S_AXIS]
    connect_bd_intf_net [get_bd_intf_pins tx_gate/M_AXIS] [get_bd_intf_pins $mac_axis_tx]
  }

  #########################################################
  # RX datapath: MAC -> frame FIFO -> [40G: dwidth 256->512] -> CDC fifo -> MCDMA(512b, sys_clk)
  #########################################################
  # Neither the CMAC nor the l_ethernet RX AXI4-Stream has a TREADY: the MAC
  # cannot be stalled, but everything behind it can (dwidth / CDC FIFO / MCDMA
  # S2MM / HP port / descriptor starvation) and at 100G the S2MM path (512b x
  # 100 MHz = 51.2 Gb/s) is slower than the line. So the MAC feeds a
  # store-and-forward frame FIFO in its RX clock domain (rx_frame_fifo.v):
  # frames are released only once complete and good, dropped WHOLE on
  # overflow (never truncated or merged), frames the MAC flags bad (tuser on
  # TLAST) are dropped, and its output honours tready. Depth 2048 beats:
  # 100G CMAC 2048 x 64 B = 128 KB (a 64 KB TSO burst at line rate plus
  # ~10 us of S2MM stall; ~33 RAMB36), 40G l_ethernet 2048 x 32 B = 64 KB
  # (13 us of line rate while the 51.2 Gb/s S2MM is stalled; ~17 RAMB36).
  # Drop counters -> rx_drop_status -> GPIO channel 2 of axi_gpio_qsfp$label.
  # TUSER width follows the MAC's rx tuser pin (bit 0 = bad frame)
  set tuser_pin [get_bd_pins $mac_axis_rx_tuser]
  if {[get_property LEFT $tuser_pin] eq ""} {
    set tuser_w 1
  } else {
    set tuser_w [expr {abs([get_property LEFT $tuser_pin] - [get_property RIGHT $tuser_pin]) + 1}]
  }
  create_bd_cell -type module -reference axis_rx_frame_fifo rx_frame_fifo
  set_property -dict [list \
    CONFIG.DATA_W [expr {8 * $mac_bytes}] \
    CONFIG.TUSER_W $tuser_w \
    CONFIG.DEPTH {2048} \
    CONFIG.DROP_ERR_FRAMES {1} \
  ] [get_bd_cells rx_frame_fifo]
  connect_bd_net [get_bd_pins $mac_rx_clk] [get_bd_pins rx_frame_fifo/aclk]
  connect_bd_net [get_bd_pins $mac_rx_rstn] [get_bd_pins rx_frame_fifo/aresetn]
  connect_bd_net [get_bd_pins $mac_rx_abort] [get_bd_pins rx_frame_fifo/rx_abort]
  connect_bd_net [get_bd_pins $mac_rx_hold] [get_bd_pins rx_frame_fifo/rx_hold]
  connect_bd_net [get_bd_pins sys_clk] [get_bd_pins rx_frame_fifo/sys_clk]
  connect_bd_net [get_bd_pins rx_frame_fifo/rx_drop_status] [get_bd_pins rx_drop_status]
  connect_bd_intf_net [get_bd_intf_pins $mac_axis_rx] [get_bd_intf_pins rx_frame_fifo/S_AXIS]

  create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo rx_cdc_fifo
  set_property -dict [list \
    CONFIG.FIFO_DEPTH {512} \
    CONFIG.IS_ACLK_ASYNC {1} \
    CONFIG.FIFO_MODE {2} \
  ] [get_bd_cells rx_cdc_fifo]
  connect_bd_net [get_bd_pins $mac_rx_clk] [get_bd_pins rx_cdc_fifo/s_axis_aclk]
  connect_bd_net [get_bd_pins $mac_rx_rstn] [get_bd_pins rx_cdc_fifo/s_axis_aresetn]
  connect_bd_net [get_bd_pins sys_clk]  [get_bd_pins rx_cdc_fifo/m_axis_aclk]
  connect_bd_intf_net [get_bd_intf_pins rx_cdc_fifo/M_AXIS] [get_bd_intf_pins rx_guard/S_AXIS]
  connect_bd_intf_net [get_bd_intf_pins rx_guard/M_AXIS] [get_bd_intf_pins axi_mcdma/S_AXIS_S2MM]
  connect_bd_net [get_bd_pins axi_mcdma/s2mm_prmry_reset_out_n] [get_bd_pins rx_guard/dma_resetn]

  if {$mac_bytes == 64} {
    connect_bd_intf_net [get_bd_intf_pins rx_frame_fifo/M_AXIS] [get_bd_intf_pins rx_cdc_fifo/S_AXIS]
  } else {
    # 40G: 32 bytes (l_ethernet) -> 64 bytes (MCDMA)
    create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter rx_dwidth
    set_property -dict [list \
      CONFIG.S_TDATA_NUM_BYTES {32} \
      CONFIG.M_TDATA_NUM_BYTES {64} \
      CONFIG.HAS_TLAST {1} \
      CONFIG.HAS_TKEEP {1} \
    ] [get_bd_cells rx_dwidth]
    connect_bd_net [get_bd_pins $mac_rx_clk] [get_bd_pins rx_dwidth/aclk]
    connect_bd_net [get_bd_pins $mac_rx_rstn] [get_bd_pins rx_dwidth/aresetn]
    connect_bd_intf_net [get_bd_intf_pins rx_frame_fifo/M_AXIS] [get_bd_intf_pins rx_dwidth/S_AXIS]
    connect_bd_intf_net [get_bd_intf_pins rx_dwidth/M_AXIS] [get_bd_intf_pins rx_cdc_fifo/S_AXIS]
  }

  #########################################################
  # User LEDs: Green = RX link up (aligned), Red = NOT aligned
  #########################################################
  connect_bd_net [get_bd_pins $mac_link_up] [get_bd_pins grn_led]
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilvector_logic:1.0 logic_red_led
  set_property -dict [list CONFIG.C_OPERATION {not} CONFIG.C_SIZE {1}] [get_bd_cells logic_red_led]
  connect_bd_net [get_bd_pins $mac_link_up] [get_bd_pins logic_red_led/Op1]
  connect_bd_net [get_bd_pins logic_red_led/Res] [get_bd_pins red_led]

  current_bd_instance \
}

# HP port allocation: port 0 -> S_AXI_HP0_FPD, port 1 -> S_AXI_HP1_FPD
set hp_ports   {S_AXI_HP0_FPD S_AXI_HP1_FPD}
set hp_configs {CONFIG.PSU__USE__S_AXI_GP2 CONFIG.PSU__USE__S_AXI_GP3}
set hp_clks    {saxihp0_fpd_aclk saxihp1_fpd_aclk}
set hp_index 0

# Create each QSFP port
foreach label $ports {
  create_qsfp_port $label

  # Connect clocks/resets
  connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins qsfp_port$label/sys_clk]
  connect_bd_net [get_bd_pins rst_ps_100m/peripheral_aresetn] [get_bd_pins qsfp_port$label/periph_rstn]
  connect_bd_net [get_bd_pins rst_ps_100m/peripheral_reset] [get_bd_pins qsfp_port$label/periph_rst]
  connect_bd_net [get_bd_pins rst_ps_100m/interconnect_aresetn] [get_bd_pins qsfp_port$label/intercon_rstn]

  # GT reference clock (GBTCLK$label from the FMC Si5328)
  create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 gt_ref_clk_$label
  set_property CONFIG.FREQ_HZ $gt_refclk_hz [get_bd_intf_ports /gt_ref_clk_$label]
  connect_bd_intf_net [get_bd_intf_ports gt_ref_clk_$label] [get_bd_intf_pins qsfp_port$label/gt_ref_clk]

  # GT serial lines (both MACs expose a gt_rtl serial interface)
  create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gt_rtl:1.0 qsfp${label}_gt
  connect_bd_intf_net [get_bd_intf_pins qsfp_port$label/qsfp_gt] [get_bd_intf_ports qsfp${label}_gt]

  # MCDMA -> PS HP port
  set hp_port [lindex $hp_ports $hp_index]
  set hp_config [lindex $hp_configs $hp_index]
  set hp_clk [lindex $hp_clks $hp_index]
  set_property $hp_config {1} [get_bd_cells zynq_ultra_ps_e_0]
  set hp_index [expr {$hp_index+1}]
  connect_bd_intf_net [get_bd_intf_pins qsfp_port$label/m_axi_hp] [get_bd_intf_pins zynq_ultra_ps_e_0/$hp_port]
  connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins zynq_ultra_ps_e_0/$hp_clk]

  # AXI-Lite control interface (port control aggregate: MAC + mcdma)
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
  # Channel 2 (inputs):  bit0=modprsl, bit1=intl,
  #                      bits[15:2]  = RX frames dropped because the MAC
  #                                    flagged them bad (14-bit, wraps)
  #                      bits[31:16] = RX frames the MAC received good but the
  #                                    RX frame FIFO dropped: full/oversize,
  #                                    or cut by a MAC/GT reset (16-bit, wraps)
  #   MAC good frames = netdev rx + rx_dma_pkt_drop + bits[31:16] (the VCK190
  #   MRMAC design keeps its own layout: [7:2] error, [31:8] full).
  #   (drop counters from qsfp_port$label/rx_frame_fifo; read GPIO2_DATA at
  #   offset 0x8 of this GPIO. The Linux gpio line numbers of modprsl/intl
  #   are unchanged: channel 2 lines start after the 3 channel-1 lines.)
  #
  # Power-on default 0x2 -> modsell=0, resetl=1 (deasserted, active-low),
  # lpmode=0 (high power) - so the QSFP module comes out of reset at config
  # time without software intervention (same rationale as the vck190 design).
  create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_qsfp$label
  set_property -dict [list \
    CONFIG.C_GPIO_WIDTH {3} \
    CONFIG.C_GPIO2_WIDTH {32} \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_ALL_INPUTS_2 {1} \
    CONFIG.C_IS_DUAL {1} \
    CONFIG.C_DOUT_DEFAULT {0x00000002} \
  ] [get_bd_cells axi_gpio_qsfp$label]
  connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_gpio_qsfp$label/s_axi_aclk]
  connect_bd_net [get_bd_pins rst_ps_100m/peripheral_aresetn] [get_bd_pins axi_gpio_qsfp$label/s_axi_aresetn]
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

  # GPIO channel 2 inputs <- modprsl/intl + RX drop counters
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconcat:1.0 qsfp_in_cat$label
  set_property -dict [list CONFIG.NUM_PORTS {3} CONFIG.IN2_WIDTH {30}] [get_bd_cells qsfp_in_cat$label]
  create_bd_port -dir I modprsl_qsfp$label
  create_bd_port -dir I intl_qsfp$label
  connect_bd_net [get_bd_ports modprsl_qsfp$label] [get_bd_pins qsfp_in_cat$label/In0]
  connect_bd_net [get_bd_ports intl_qsfp$label] [get_bd_pins qsfp_in_cat$label/In1]
  connect_bd_net [get_bd_pins qsfp_port$label/rx_drop_status] [get_bd_pins qsfp_in_cat$label/In2]
  connect_bd_net [get_bd_pins qsfp_in_cat$label/dout] [get_bd_pins axi_gpio_qsfp$label/gpio2_io_i]

  #########################################################
  # QSFP module management I2C (per port)
  #########################################################
  create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic axi_iic_qsfp$label
  connect_bd_intf_net [get_bd_intf_pins axi_smc/M[format "%02d" $smc_mi]_AXI] [get_bd_intf_pins axi_iic_qsfp$label/S_AXI]
  incr smc_mi
  connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_iic_qsfp$label/s_axi_aclk]
  connect_bd_net [get_bd_pins rst_ps_100m/peripheral_aresetn] [get_bd_pins axi_iic_qsfp$label/s_axi_aresetn]
  lappend intr_list "axi_iic_qsfp$label/iic2intc_irpt"
  create_bd_intf_port -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 qsfp${label}_i2c
  connect_bd_intf_net [get_bd_intf_ports qsfp${label}_i2c] [get_bd_intf_pins axi_iic_qsfp$label/IIC]
}

#########################################################
# Unused QSFP ports (e.g. port 1 on ZCU208/ZCU216)
#########################################################
# The module in an unpopulated port is held in reset and put in low-power
# mode; its LEDs are off. No I2C/GPIO is instantiated for it.
#   modsell = 1 (deselected), resetl = 0 (held in reset), lpmode = 1
foreach label {0 1} {
  if {[lsearch -exact $ports $label] >= 0} { continue }
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconstant:1.0 const_high_qsfp$label
  set_property CONFIG.CONST_VAL {1} [get_bd_cells const_high_qsfp$label]
  create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconstant:1.0 const_low_qsfp$label
  set_property CONFIG.CONST_VAL {0} [get_bd_cells const_low_qsfp$label]
  foreach {port net} {modsell const_high resetl const_low lpmode const_high grn_led const_low red_led const_low} {
    create_bd_port -dir O ${port}_qsfp$label
    connect_bd_net [get_bd_pins ${net}_qsfp$label/dout] [get_bd_ports ${port}_qsfp$label]
  }
}

#########################################################
# Shared I2C bus (direct, no PCA9548 mux)
#########################################################
# clk_i2c : Si5328 jitter-attenuating clock generator (one per board, shared
# by both QSFP ports - it sources both GBTCLK0 and GBTCLK1 reference clocks).
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic axi_iic_clk
connect_bd_intf_net [get_bd_intf_pins axi_smc/M[format "%02d" $smc_mi]_AXI] [get_bd_intf_pins axi_iic_clk/S_AXI]
incr smc_mi
connect_bd_net [get_bd_pins $sys_clk] [get_bd_pins axi_iic_clk/s_axi_aclk]
connect_bd_net [get_bd_pins rst_ps_100m/peripheral_aresetn] [get_bd_pins axi_iic_clk/s_axi_aresetn]
lappend intr_list "axi_iic_clk/iic2intc_irpt"
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 clk_i2c
connect_bd_intf_net [get_bd_intf_ports clk_i2c] [get_bd_intf_pins axi_iic_clk/IIC]

#########################################################
# PL-to-PS interrupts (pl_ps_irq0, max 8)
#########################################################
set n_interrupts [llength $intr_list]
create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconcat:1.0 intr_concat
set_property CONFIG.NUM_PORTS $n_interrupts [get_bd_cells intr_concat]
set intr_index 0
foreach intr $intr_list {
  connect_bd_net [get_bd_pins $intr] [get_bd_pins intr_concat/In$intr_index]
  set intr_index [expr {$intr_index+1}]
}
connect_bd_net [get_bd_pins intr_concat/dout] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]

# Assign addresses
assign_bd_address

# Layout and validate
regenerate_bd_layout
save_bd_design
validate_bd_design
save_bd_design
