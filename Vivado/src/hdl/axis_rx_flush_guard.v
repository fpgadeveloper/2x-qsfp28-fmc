// ---------------------------------------------------------------------------
// RX flush guard: flush the MAC-side RX datapath on a DMA reset, frame-safe
// towards the AXI MCDMA S2MM.
//
// Opsero 2x QSFP28 FMC reference design.
//
// The RX chain between the MAC and the S2MM (frame FIFO, width converter,
// CDC FIFO) is NOT reset by MAC/GT resets: a reset there could cut a frame
// the S2MM is reading and merge its head with the next frame (seen in
// testing as a corrupted UDP datagram during reset-alls under load). It is
// flushed only when the S2MM itself is reset (s2mm_prmry_reset_out_n: every
// driver open/close, DMA error recovery, the driver's RX-wedge restart, and
// the hardware reset), i.e. when no frame can be in flight into the DMA:
//
//   1. S2MM reset seen -> the stream into the S2MM is blocked (tvalid/tready
//      forced low) and flush_req is raised.
//   2. flush_req is synchronised into the MAC clock domain by a
//      proc_sys_reset, whose peripheral_reset (flush_ack) resets the chain.
//      If the MAC clock is stopped (GT in reset) the request simply waits.
//   3. flush_ack seen high -> flush_req dropped; flush_ack seen low again
//      (chain released) -> SETTLE_CYC more cycles for the CDC FIFO's read
//      side to leave reset -> stream unblocked. The S2MM then starts on a
//      frame boundary, with no stale beats of an old frame.
// ---------------------------------------------------------------------------
`timescale 1ns / 1ps

module axis_rx_flush_guard #(
  parameter integer DATA_W     = 512,
  parameter integer SETTLE_CYC = 32
)(
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TDATA"  *) input  wire [DATA_W-1:0]   s_axis_tdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TKEEP"  *) input  wire [DATA_W/8-1:0] s_axis_tkeep,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TLAST"  *) input  wire                s_axis_tlast,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TVALID" *) input  wire                s_axis_tvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TREADY" *) output wire                s_axis_tready,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TDATA"  *) output wire [DATA_W-1:0]   m_axis_tdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TKEEP"  *) output wire [DATA_W/8-1:0] m_axis_tkeep,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TLAST"  *) output wire                m_axis_tlast,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TVALID" *) output wire                m_axis_tvalid,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TREADY" *) input  wire                m_axis_tready,
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 ACLK CLK" *)
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXIS:M_AXIS, ASSOCIATED_RESET dma_resetn" *)
  input  wire aclk,
  // S2MM primary reset out of the AXI MCDMA (active low, aclk domain)
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 DMA_RESETN RST" *)
  (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
  input  wire dma_resetn,
  // Flush request to the MAC-clock proc_sys_reset (ext_reset_in, active high)
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 FLUSH_REQ RST" *)
  (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_HIGH" *)
  output reg  flush_req = 1'b1,
  // That proc_sys_reset's peripheral_reset (active high, MAC clock domain)
  input  wire flush_ack
);
  wire ack_s;
  xpm_cdc_single #(
    .DEST_SYNC_FF   (4),
    .INIT_SYNC_FF   (0),
    .SIM_ASSERT_CHK (0),
    .SRC_INPUT_REG  (0)
  ) ack_sync (
    .src_clk  (1'b0),
    .src_in   (flush_ack),
    .dest_clk (aclk),
    .dest_out (ack_s)
  );

  localparam [1:0] S_RUN = 2'd0, S_REQ = 2'd1, S_REL = 2'd2, S_SETTLE = 2'd3;
  reg [1:0] state = S_REQ;
  reg [7:0] settle = 8'd0;

  always @(posedge aclk) begin
    if (!dma_resetn) begin
      state     <= S_REQ;
      flush_req <= 1'b1;
    end else begin
      case (state)
        S_REQ:    if (ack_s) begin flush_req <= 1'b0; state <= S_REL; end
        S_REL:    if (!ack_s) begin settle <= SETTLE_CYC; state <= S_SETTLE; end
        S_SETTLE: if (settle == 0) state <= S_RUN; else settle <= settle - 1'b1;
        default:  ;
      endcase
    end
  end

  wire run = (state == S_RUN);
  assign m_axis_tdata  = s_axis_tdata;
  assign m_axis_tkeep  = s_axis_tkeep;
  assign m_axis_tlast  = s_axis_tlast;
  assign m_axis_tvalid = s_axis_tvalid & run;
  assign s_axis_tready = m_axis_tready & run;
endmodule
