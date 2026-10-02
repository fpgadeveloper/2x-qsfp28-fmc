// ---------------------------------------------------------------------------
// TX frame gate: after reset, discard beats up to and including the first
// TLAST, then pass the AXI4-Stream through unchanged (combinational).
//
// Opsero 2x QSFP28 FMC reference design.
//
// The MAC-side TX AXIS blocks (CDC FIFO read side, 512->256 width converter)
// are reset whenever the MAC's TX clock is interrupted (GT TX / reset-all).
// The AXI MCDMA MM2S is NOT reset then and simply continues the frame it was
// sending, so the first beats that reach the MAC after the reset can be the
// tail of a frame whose head was flushed. Without this gate the MAC would
// send that tail as a frame of its own, with a freshly computed (good) FCS.
// The gate drops everything up to the first TLAST after reset (at most one
// frame is lost per reset - the same rule as rx_frame_fifo's "synced").
// ---------------------------------------------------------------------------
`timescale 1ns / 1ps

module axis_tx_frame_gate #(
  parameter integer DATA_W = 256
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
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXIS:M_AXIS, ASSOCIATED_RESET aresetn" *)
  input  wire aclk,
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 ARESETN RST" *)
  (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
  input  wire aresetn
);
  reg synced = 1'b0;   // a TLAST has passed (been discarded) since reset

  always @(posedge aclk) begin
    if (!aresetn)
      synced <= 1'b0;
    else if (!synced && s_axis_tvalid && s_axis_tlast)
      synced <= 1'b1;   // s_axis_tready is 1 while !synced
  end

  assign m_axis_tdata  = s_axis_tdata;
  assign m_axis_tkeep  = s_axis_tkeep;
  assign m_axis_tlast  = s_axis_tlast;
  assign m_axis_tvalid = s_axis_tvalid & synced;
  assign s_axis_tready = synced ? m_axis_tready : aresetn;
endmodule
