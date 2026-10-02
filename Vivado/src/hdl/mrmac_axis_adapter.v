// ---------------------------------------------------------------------------
// MRMAC 1x100GE CAUI-4 client <-> standard AXI4-Stream adapters
//
// Opsero 2x QSFP28 FMC reference design.
//
// The Versal MRMAC 100G "Independent 384b Non-Segmented" client is NOT a
// standard AXI4-Stream bus. In a block design its axis_rx_port0 / axis_tx_port0
// interfaces are handshake-only (they map TVALID/TLAST/TREADY only, so the BD
// reports TDATA_NUM_BYTES=0, HAS_TKEEP=0). The actual 384-bit data rides on six
// separate 64-bit lane ports (rx/tx_axis_tdata0..5) plus six per-lane
// tkeep_user0..5[10:0] control words. Feeding that handshake-only interface
// into a stock axis_dwidth_converter is invalid and delineated one packet per
// 384-bit beat (frames received fragmented into ~48-byte pieces).
//
// These adapters present the MRMAC client as a single 384-bit standard AXIS
// stream (tdata[383:0], tkeep[47:0], tlast, tvalid[, tready]) so the existing
// dwidth-converter / CDC-FIFO / MCDMA datapath delineates frames correctly:
// one TLAST per Ethernet frame.
//
// Unlike the AMD VCK190 ethernet TRD - which runs 4x INDEPENDENT 10G/25G ports,
// each a single 64-bit lane straight into its own MCDMA (no packing needed) -
// 1x100GE CAUI-4 bonds all six lanes into one frame, hence this packing logic.
//
// tkeep_user<M>[10:0] decode (PG, per 64-bit lane):
//   [7:0] = tkeep (per-byte valid, only meaningful on the TLAST beat)
//   [8]   = Err     (RX: 1 = errored frame; valid when tlast=1)
//   [9]   = Preempt (frame preemption; valid when tlast=1)
//   [10]  = Resume  (TX preemption; unused here)
//
// The TX adapter is purely combinational glue (the MRMAC TX client HAS
// backpressure, tx_axis_tready); its aclk port carries no logic - it exists
// only so the AXIS interface has an associated clock (FREQ_HZ propagation) in
// IP integrator. The RX adapter is NOT: the MRMAC RX client has no
// backpressure at all (no rx tready pin on the IP), so every beat it presents
// must be taken on that cycle or it is lost. The RX adapter therefore feeds
// the packed 384b beats into a store-and-forward frame FIFO with whole-frame
// drop (rx_frame_fifo, see rx_frame_fifo.v) - the ONLY place in the RX path
// where frames may be discarded, and it discards them whole.
// ---------------------------------------------------------------------------

`timescale 1ns / 1ps

// RX: MRMAC client (6x64b + 6x tkeep_user) -> standard 384b AXIS master,
// through a store-and-forward frame FIFO in the MRMAC client clock domain
// (aclk, 390.625 MHz).
//
// Why: the MRMAC RX client cannot be stalled, but everything downstream can
// (dwidth converter -> CDC FIFO -> AXI MCDMA S2MM -> NoC -> DDR, plus the S2MM
// waiting for free descriptors), and the S2MM path (512b x 100 MHz = 51.2
// Gb/s) is slower than the 100G line. Previously the six lanes went straight
// into the dwidth converter with m_axis_tready ignored, so whenever the CDC
// FIFO filled up, individual beats (including TLAST beats) silently vanished
// mid-frame: truncated and MERGED frames reached the DMA while the MAC
// counters stayed clean (the same defect was fixed in the sfp28-fmc-mrmac
// design, which shares this datapath structure).
//
// Frame error: tkeep_user<M>[8] is the per-lane Err flag of the TLAST beat.
// It is taken from every lane that carries data on that beat (tkeep bit 0 of
// the lane set; the valid bytes of the last beat are contiguous from lane 0),
// so undefined flags of empty lanes cannot drop a good frame.
//
// Drop counters (see rx_frame_fifo): rx_drop_status[29:6] = frames dropped
// because the FIFO was full / oversize, [5:0] = frames the MAC flagged bad.
//
// Memory: FIFO_DEPTH beats of 48 bytes (default 2048 = 96 KB: ~26 x 36Kb
// block RAM), one write + one read port in aclk.
module mrmac_rx_axis_adapter #(
  parameter integer FIFO_DEPTH      = 2048,  // frame FIFO depth in 384b beats (power of 2)
  parameter integer DROP_ERR_FRAMES = 1      // 1 = drop frames with the MAC error flag set
)(
  // From the MRMAC 100G client (loose ports; not part of an AXIS interface)
  (* X_INTERFACE_IGNORE = "true" *) input wire [63:0] rx_axis_tdata0,
  (* X_INTERFACE_IGNORE = "true" *) input wire [63:0] rx_axis_tdata1,
  (* X_INTERFACE_IGNORE = "true" *) input wire [63:0] rx_axis_tdata2,
  (* X_INTERFACE_IGNORE = "true" *) input wire [63:0] rx_axis_tdata3,
  (* X_INTERFACE_IGNORE = "true" *) input wire [63:0] rx_axis_tdata4,
  (* X_INTERFACE_IGNORE = "true" *) input wire [63:0] rx_axis_tdata5,
  (* X_INTERFACE_IGNORE = "true" *) input wire [10:0] rx_axis_tkeep_user0,
  (* X_INTERFACE_IGNORE = "true" *) input wire [10:0] rx_axis_tkeep_user1,
  (* X_INTERFACE_IGNORE = "true" *) input wire [10:0] rx_axis_tkeep_user2,
  (* X_INTERFACE_IGNORE = "true" *) input wire [10:0] rx_axis_tkeep_user3,
  (* X_INTERFACE_IGNORE = "true" *) input wire [10:0] rx_axis_tkeep_user4,
  (* X_INTERFACE_IGNORE = "true" *) input wire [10:0] rx_axis_tkeep_user5,
  (* X_INTERFACE_IGNORE = "true" *) input wire        rx_axis_tlast,
  (* X_INTERFACE_IGNORE = "true" *) input wire        rx_axis_tvalid,
  // To a standard AXIS slave (axis_dwidth_converter S_AXIS, 384b)
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TDATA"  *) output wire [383:0] m_axis_tdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TKEEP"  *) output wire [47:0]  m_axis_tkeep,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TLAST"  *) output wire         m_axis_tlast,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TVALID" *) output wire         m_axis_tvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TREADY" *) input  wire         m_axis_tready,
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 ACLK CLK" *)
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF M_AXIS, ASSOCIATED_RESET aresetn" *)
  input wire aclk,
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 ARESETN RST" *)
  (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
  input wire aresetn,
  // Drop-counter read-out clock (the AXI GPIO's s_axi_aclk)
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 SYS_CLK CLK" *)
  input wire sys_clk,
  output wire [29:0] rx_drop_status
);
  wire [383:0] data = {rx_axis_tdata5, rx_axis_tdata4, rx_axis_tdata3,
                       rx_axis_tdata2, rx_axis_tdata1, rx_axis_tdata0};
  // tkeep_user[7:0] is only valid on the last beat; every other beat is full
  // (48 valid bytes). Forcing all-ones on non-last beats avoids propagating the
  // undefined tkeep_user value the MRMAC drives mid-frame.
  wire [47:0] keep = rx_axis_tlast
        ? {rx_axis_tkeep_user5[7:0], rx_axis_tkeep_user4[7:0], rx_axis_tkeep_user3[7:0],
           rx_axis_tkeep_user2[7:0], rx_axis_tkeep_user1[7:0], rx_axis_tkeep_user0[7:0]}
        : {48{1'b1}};
  wire err = (rx_axis_tkeep_user0[8] & rx_axis_tkeep_user0[0]) |
             (rx_axis_tkeep_user1[8] & rx_axis_tkeep_user1[0]) |
             (rx_axis_tkeep_user2[8] & rx_axis_tkeep_user2[0]) |
             (rx_axis_tkeep_user3[8] & rx_axis_tkeep_user3[0]) |
             (rx_axis_tkeep_user4[8] & rx_axis_tkeep_user4[0]) |
             (rx_axis_tkeep_user5[8] & rx_axis_tkeep_user5[0]);

  rx_frame_fifo #(
    .DATA_W          (384),
    .DEPTH           (FIFO_DEPTH),
    .DROP_ERR_FRAMES (DROP_ERR_FRAMES),
    .MODE            (0)        // unchanged (HW-proven) MRMAC behaviour and layout
  ) fifo (
    .aclk           (aclk),
    .aresetn        (aresetn),
    .s_abort        (1'b0),
    .s_hold         (1'b0),
    .s_valid        (rx_axis_tvalid),
    .s_last         (rx_axis_tlast),
    .s_err          (err),
    .s_keep         (keep),
    .s_data         (data),
    .m_axis_tdata   (m_axis_tdata),
    .m_axis_tkeep   (m_axis_tkeep),
    .m_axis_tlast   (m_axis_tlast),
    .m_axis_tvalid  (m_axis_tvalid),
    .m_axis_tready  (m_axis_tready),
    .sys_clk        (sys_clk),
    .rx_drop_status (rx_drop_status)
  );
endmodule

// TX: standard 384b AXIS slave -> MRMAC client (6x64b + 6x tkeep_user)
module mrmac_tx_axis_adapter (
  // From a standard AXIS master (axis_dwidth_converter M_AXIS, 384b)
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TDATA"  *) input  wire [383:0] s_axis_tdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TKEEP"  *) input  wire [47:0]  s_axis_tkeep,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TLAST"  *) input  wire         s_axis_tlast,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TVALID" *) input  wire         s_axis_tvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TREADY" *) output wire         s_axis_tready,
  // To the MRMAC 100G client (loose ports; not part of an AXIS interface)
  (* X_INTERFACE_IGNORE = "true" *) output wire [63:0] tx_axis_tdata0,
  (* X_INTERFACE_IGNORE = "true" *) output wire [63:0] tx_axis_tdata1,
  (* X_INTERFACE_IGNORE = "true" *) output wire [63:0] tx_axis_tdata2,
  (* X_INTERFACE_IGNORE = "true" *) output wire [63:0] tx_axis_tdata3,
  (* X_INTERFACE_IGNORE = "true" *) output wire [63:0] tx_axis_tdata4,
  (* X_INTERFACE_IGNORE = "true" *) output wire [63:0] tx_axis_tdata5,
  (* X_INTERFACE_IGNORE = "true" *) output wire [10:0] tx_axis_tkeep_user0,
  (* X_INTERFACE_IGNORE = "true" *) output wire [10:0] tx_axis_tkeep_user1,
  (* X_INTERFACE_IGNORE = "true" *) output wire [10:0] tx_axis_tkeep_user2,
  (* X_INTERFACE_IGNORE = "true" *) output wire [10:0] tx_axis_tkeep_user3,
  (* X_INTERFACE_IGNORE = "true" *) output wire [10:0] tx_axis_tkeep_user4,
  (* X_INTERFACE_IGNORE = "true" *) output wire [10:0] tx_axis_tkeep_user5,
  (* X_INTERFACE_IGNORE = "true" *) output wire        tx_axis_tlast,
  (* X_INTERFACE_IGNORE = "true" *) output wire        tx_axis_tvalid,
  (* X_INTERFACE_IGNORE = "true" *) input  wire        tx_axis_tready,
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 ACLK CLK" *)
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXIS" *)
  input wire aclk
);
  assign tx_axis_tdata0 = s_axis_tdata[63:0];
  assign tx_axis_tdata1 = s_axis_tdata[127:64];
  assign tx_axis_tdata2 = s_axis_tdata[191:128];
  assign tx_axis_tdata3 = s_axis_tdata[255:192];
  assign tx_axis_tdata4 = s_axis_tdata[319:256];
  assign tx_axis_tdata5 = s_axis_tdata[383:320];
  // Per-lane keep from the AXIS tkeep; upper control bits [10:8] (Err/Preempt/
  // Resume) tied 0. tkeep is full on non-last beats and partial on the last
  // beat, exactly what the MRMAC expects (it only consults keep when tlast=1).
  assign tx_axis_tkeep_user0 = {3'b000, s_axis_tkeep[7:0]};
  assign tx_axis_tkeep_user1 = {3'b000, s_axis_tkeep[15:8]};
  assign tx_axis_tkeep_user2 = {3'b000, s_axis_tkeep[23:16]};
  assign tx_axis_tkeep_user3 = {3'b000, s_axis_tkeep[31:24]};
  assign tx_axis_tkeep_user4 = {3'b000, s_axis_tkeep[39:32]};
  assign tx_axis_tkeep_user5 = {3'b000, s_axis_tkeep[47:40]};
  assign tx_axis_tlast  = s_axis_tlast;
  assign tx_axis_tvalid = s_axis_tvalid;
  assign s_axis_tready  = tx_axis_tready;
endmodule
