// ---------------------------------------------------------------------------
// RX store-and-forward frame FIFO for MACs without RX backpressure
//
// Opsero 2x QSFP28 FMC reference design.
//
// None of the MACs used by this design can stall its RX client: the Versal
// MRMAC, the UltraScale+ CMAC (cmac_usplus axis_rx) and the 40G/50G
// subsystem (l_ethernet axis_rx_0) have no RX tready at all - every beat
// they present must be taken on that cycle or it is lost. Everything behind
// them CAN stall: dwidth converter -> CDC FIFO -> AXI MCDMA S2MM -> NoC/HP
// port -> DDR, and the S2MM also waits for free RX descriptors. The S2MM
// datapath (512 bit x 100 MHz = 51.2 Gb/s) is also slower than a 100G line.
// Without this FIFO, individual beats - including TLAST beats - silently
// vanished whenever the CDC FIFO was full: truncated and MERGED frames
// reached the DMA while the MAC counters stayed clean (the same defect was
// fixed in the sfp28-fmc-mrmac design, which shares this datapath structure).
//
// Behaviour:
//  * A frame is released downstream only after its TLAST beat has been
//    written and it was not flagged bad (store-and-forward, "commit").
//  * If the FIFO fills up while a frame is being written, the partial frame
//    is rolled back and the remainder of that frame is discarded: frames are
//    dropped WHOLE, never truncated or merged. Frames that cannot fit at all
//    (> DEPTH beats) are dropped the same way.
//  * Frames the MAC flags as errored (s_err on the TLAST beat) are rolled
//    back when DROP_ERR_FRAMES = 1.
//  * The FIFO never starts in the middle of a frame. MODE 0 (MRMAC adapter,
//    unchanged): after reset, input is ignored up to and including the first
//    TLAST. MODE 1 (CMAC / l_ethernet): the MAC's frame state is tracked from
//    the input beats (never reset); after reset or an input hold, only the
//    rest of a frame that is really in progress is skipped - an idle MAC's
//    next frame is accepted.
//  * MODE 1 input hold (s_abort = MAC RX in reset, s_hold = MAC TX clock
//    interrupted / TX reset; both level, synchronous to aclk): the frame
//    being written is rolled back and every input beat is discarded while
//    it lasts; committed frames and the output side are NOT touched, so a
//    MAC/GT reset can never truncate or merge a frame downstream.
//  * MODE 1 accounting: every frame whose TLAST reaches the FIFO and that is
//    not committed is counted - as an error drop if the MAC flagged it, else
//    as a drop (overflow, oversize, reset, hold, skip). So MAC good frames =
//    frames delivered + drop counter, across resets too (frames cut by the
//    MAC's own reset never show a TLAST and are not MAC-good frames either).
//  * The output honours m_axis_tready (full AXI4-Stream compliance).
//
// Drop counters (free running since configuration - NOT cleared by aresetn,
// so they survive MAC/link resets; wrap around), synchronised into sys_clk
// with xpm_cdc_gray so an AXI GPIO clocked by sys_clk can sample them:
//   MODE 0: rx_drop_status[29:6]  = frames dropped: FIFO full / oversize
//           rx_drop_status[5:0]   = frames dropped: MAC flagged an error
//   MODE 1: rx_drop_status[29:14] = frames dropped for any other reason
//                                   (full, oversize, reset, hold, skip), 16 bit
//           rx_drop_status[13:0]  = frames dropped: MAC flagged an error, 14 bit
//
// Timing structure (the FIFO runs in the clock the MAC's RX AXIS is
// synchronous to: 390.625 MHz MRMAC rx_axi_clk, 322 MHz CMAC gt_txusrclk2,
// 312.5 MHz l_ethernet tx_clk_out - NOT its rx_clk_out, see the l_ethernet
// clocking comment in bd_zynqmp.tcl; the RAM is 300-600 bits wide and
// spans 10-35 block RAMs):
//  * write: enable/address/data are registered before the RAM, so the RAM
//    write-enable is a flop (replicable), not logic; the commit pointer seen
//    by the read side is delayed by the same cycle.
//  * read: the RAM is read EVERY cycle at the read pointer (no RAM enables);
//    a read is "issued" by advancing the pointer while an output buffer
//    credit is free. Data flows through a fixed 2-stage pipeline (RAM
//    latch + RAM output register) into a small distributed-RAM output
//    buffer (OB_DEPTH entries), which is the only part that sees tready.
//    Full throughput (one beat per cycle) with tready held high.
// ---------------------------------------------------------------------------

`timescale 1ns / 1ps

module rx_frame_fifo #(
  parameter integer DATA_W          = 384,   // bits per beat (multiple of 8)
  parameter integer DEPTH           = 2048,  // beats, power of 2
  parameter integer DROP_ERR_FRAMES = 1,     // 1 = drop frames the MAC flagged bad
  parameter integer MODE            = 0      // 0 = MRMAC (legacy), 1 = CMAC/l_ethernet
)(
  input  wire                aclk,
  input  wire                aresetn,
  // From the MAC (no backpressure)
  input  wire                s_abort,        // MODE 1: MAC RX in reset (level)
  input  wire                s_hold,         // MODE 1: MAC TX clock interrupted (level)
  input  wire                s_valid,
  input  wire                s_last,
  input  wire                s_err,          // valid with s_last
  input  wire [DATA_W/8-1:0] s_keep,
  input  wire [DATA_W-1:0]   s_data,
  // Standard AXI4-Stream master
  output wire [DATA_W-1:0]   m_axis_tdata,
  output wire [DATA_W/8-1:0] m_axis_tkeep,
  output wire                m_axis_tlast,
  output wire                m_axis_tvalid,
  input  wire                m_axis_tready,
  // Drop counters in the sys_clk domain
  input  wire                sys_clk,
  output wire [29:0]         rx_drop_status
);
  localparam integer KW       = DATA_W / 8;
  localparam integer AW       = $clog2(DEPTH);
  localparam integer MW       = DATA_W + KW + 1;   // {tlast, tkeep, tdata}
  localparam integer OB_DEPTH = 8;                 // output buffer entries
  localparam integer OBW      = 3;                 // log2(OB_DEPTH)
  localparam         NEW      = (MODE != 0);
  localparam integer ERR_W    = NEW ? 14 : 6;
  localparam integer DRP_W    = 30 - ERR_W;

  // -------------------------------------------------------------------------
  // Input register (decouples the MAC hard-block pins from the FIFO logic)
  // -------------------------------------------------------------------------
  reg              in_hold  = 1'b0;   // MODE 1: abort or hold
  reg              in_abort = 1'b0;   // MODE 1: MAC RX in reset
  reg              in_beat  = 1'b0;   // MODE 1: raw s_valid (not gated by reset)
  reg              in_rstn  = 1'b0;   // MODE 1: aresetn when this beat was sampled
  reg              in_valid = 1'b0;
  reg              in_last  = 1'b0;
  reg              in_err   = 1'b0;
  reg [KW-1:0]     in_keep;
  reg [DATA_W-1:0] in_data;
  always @(posedge aclk) begin
    in_hold  <= NEW & (s_abort | s_hold);
    in_abort <= NEW & s_abort;
    in_beat  <= s_valid;
    in_rstn  <= aresetn;
    in_valid <= aresetn & s_valid;
    in_last  <= s_last;
    in_err   <= s_err;
    in_keep  <= s_keep;
    in_data  <= s_data;
  end

  // MODE 1: is the MAC in the middle of a frame (after this cycle's beat)?
  // Tracked from every input beat, never reset: only the MAC's own RX reset
  // ends a frame without a TLAST.
  reg  mac_in_frame = 1'b0;
  wire mif_next     = in_abort ? 1'b0 : (in_beat ? ~in_last : mac_in_frame);
  always @(posedge aclk)
    mac_in_frame <= mif_next;

  // -------------------------------------------------------------------------
  // Frame FIFO storage
  // -------------------------------------------------------------------------
  (* ram_style = "block" *) reg [MW-1:0] mem [0:DEPTH-1];

  reg [AW:0] wr_ptr        = 0;   // speculative write pointer
  reg [AW:0] wr_ptr_commit = 0;   // end of the last complete, good frame
  reg [AW:0] commit_rd     = 0;   // wr_ptr_commit, delayed like the RAM write
  reg [AW:0] rd_ptr        = 0;

  // -------------------------------------------------------------------------
  // Write side
  // -------------------------------------------------------------------------
  // full_r is registered from the previous cycle's pointers. The fill level
  // grows by at most one per cycle, so "fill >= DEPTH-1 last cycle" is a
  // safe full flag for this cycle's write (fill never exceeds DEPTH).
  reg             full_r   = 1'b0;
  reg             synced   = 1'b0;   // MODE 0: a TLAST has been seen since reset
  reg             dropping = 1'b0;   // discarding the rest of the current frame
  reg [DRP_W-1:0] ovf_cnt  = 0;      // no reset: free running since configuration
  reg [ERR_W-1:0] err_cnt  = 0;

  wire [AW:0] fill = wr_ptr - rd_ptr;   // AW+1 bits: modulo pointer difference

  // Input beat: MODE 0 uses the reset-gated in_valid; MODE 1 sees every beat
  // (in_beat) - the reset branch below tracks what arrives during reset.
  // MODE 0 accepts after the first TLAST; MODE 1 is "synced" by construction.
  wire in_v   = NEW ? in_beat : in_valid;
  wire acc    = in_v & (NEW | synced) & ~dropping & ~in_hold;
  // MODE 1 write side is in reset while aresetn is low AND for the beat
  // sampled in the last reset cycle (it belongs to the reset window)
  wire wrst   = ~aresetn | (NEW & ~in_rstn);
  wire wr_en  = acc & ~full_r & ~(NEW & wrst);
  wire is_bad = (DROP_ERR_FRAMES != 0) & in_err;

  // MODE 1 accounting: a TLAST that reaches the FIFO and is not committed
  wire commit_last = wr_en & in_last & ~is_bad;
  wire lost_last   = NEW & in_beat & in_last & ~commit_last;
  wire cnt_err     = NEW ? (lost_last & in_err)
                         : (aresetn & acc & ~full_r & in_last & is_bad);
  wire cnt_drop    = NEW ? (lost_last & ~in_err)
                         : (aresetn & in_valid & synced & in_last & (dropping | full_r));

  always @(posedge aclk) begin
    if (cnt_err)
      err_cnt <= err_cnt + 1'b1;
    if (cnt_drop)
      ovf_cnt <= ovf_cnt + 1'b1;
  end

  // Registered RAM write port
  reg          we_r = 1'b0;
  reg [AW-1:0] wa_r;
  reg [MW-1:0] wd_r;
  always @(posedge aclk) begin
    we_r <= wr_en;
    wa_r <= wr_ptr[AW-1:0];
    wd_r <= {in_last, in_keep, in_data};
    if (we_r)
      mem[wa_r] <= wd_r;
  end

  always @(posedge aclk) begin
    if (wrst) begin
      wr_ptr        <= 0;
      wr_ptr_commit <= 0;
      commit_rd     <= 0;
      full_r        <= 1'b0;
      synced        <= 1'b0;
      // MODE 1: skip the rest of a frame the MAC is sending across reset
      dropping      <= NEW & mif_next;
    end else begin
      full_r    <= (fill >= DEPTH - 1);
      commit_rd <= wr_ptr_commit;
      if (in_hold) begin
        // MODE 1 hold: roll back a partial frame, then skip the rest of the
        // MAC frame in progress when the hold ends (none after an RX reset)
        wr_ptr   <= wr_ptr_commit;
        dropping <= mif_next;
      end else if (in_v) begin
        if (!NEW && !synced) begin
          // MODE 0: skip the (possibly partial) frame in flight at reset release
          if (in_last)
            synced <= 1'b1;
        end else if (dropping) begin
          if (in_last)
            dropping <= 1'b0;
        end else if (full_r) begin
          // No room: roll back the partial frame, discard its remainder.
          wr_ptr <= wr_ptr_commit;
          if (!in_last)
            dropping <= 1'b1;
        end else if (in_last) begin
          if (is_bad) begin
            wr_ptr  <= wr_ptr_commit;              // roll back bad frame
          end else begin
            wr_ptr        <= wr_ptr + 1'b1;        // commit good frame
            wr_ptr_commit <= wr_ptr + 1'b1;
          end
        end else begin
          wr_ptr <= wr_ptr + 1'b1;
        end
      end
    end
  end

  // -------------------------------------------------------------------------
  // Read side
  // -------------------------------------------------------------------------
  // cnt = beats issued from the RAM and not yet taken downstream (in the
  // 2-stage read pipeline or in the output buffer); issuing only while
  // cnt < OB_DEPTH guarantees the output buffer never overflows.
  reg  [OBW:0] cnt = 0;
  reg  [OBW:0] ob_wp = 0, ob_rp = 0;
  reg          v1 = 1'b0, v2 = 1'b0;
  reg [MW-1:0] qa, qb;

  wire rd_avail = (rd_ptr != commit_rd);
  wire rd_issue = rd_avail & (cnt < OB_DEPTH);
  wire ob_valid = (ob_wp != ob_rp);
  wire ob_pop   = ob_valid & m_axis_tready;

  // RAM read every cycle at rd_ptr (RAM latch qa + RAM output register qb).
  // A collision with the write port only affects qa of a non-issued read.
  always @(posedge aclk) begin
    qa <= mem[rd_ptr[AW-1:0]];
    qb <= qa;
  end

  (* ram_style = "distributed" *) reg [MW-1:0] ob [0:OB_DEPTH-1];
  always @(posedge aclk) begin
    if (v2)
      ob[ob_wp[OBW-1:0]] <= qb;
  end

  always @(posedge aclk) begin
    if (!aresetn) begin
      rd_ptr <= 0;
      v1     <= 1'b0;
      v2     <= 1'b0;
      cnt    <= 0;
      ob_wp  <= 0;
      ob_rp  <= 0;
    end else begin
      if (rd_issue)
        rd_ptr <= rd_ptr + 1'b1;
      v1 <= rd_issue;
      v2 <= v1;
      if (v2)
        ob_wp <= ob_wp + 1'b1;
      if (ob_pop)
        ob_rp <= ob_rp + 1'b1;
      cnt <= cnt + rd_issue - ob_pop;
    end
  end

  wire [MW-1:0] ob_q = ob[ob_rp[OBW-1:0]];
  assign m_axis_tvalid = ob_valid;
  assign m_axis_tlast  = ob_q[MW-1];
  assign m_axis_tkeep  = ob_q[MW-2 -: KW];
  assign m_axis_tdata  = ob_q[DATA_W-1:0];

  // -------------------------------------------------------------------------
  // Drop counters -> sys_clk domain (Gray-code CDC; the counters change by at
  // most one per aclk cycle and are never reset, as xpm_cdc_gray requires)
  // -------------------------------------------------------------------------
  wire [DRP_W-1:0] ovf_cnt_sys;
  wire [ERR_W-1:0] err_cnt_sys;

  xpm_cdc_gray #(
    .DEST_SYNC_FF (3),
    .INIT_SYNC_FF (0),
    .REG_OUTPUT   (1),
    .WIDTH        (DRP_W)
  ) ovf_cnt_cdc (
    .src_clk      (aclk),
    .src_in_bin   (ovf_cnt),
    .dest_clk     (sys_clk),
    .dest_out_bin (ovf_cnt_sys)
  );

  xpm_cdc_gray #(
    .DEST_SYNC_FF (3),
    .INIT_SYNC_FF (0),
    .REG_OUTPUT   (1),
    .WIDTH        (ERR_W)
  ) err_cnt_cdc (
    .src_clk      (aclk),
    .src_in_bin   (err_cnt),
    .dest_clk     (sys_clk),
    .dest_out_bin (err_cnt_sys)
  );

  assign rx_drop_status = {ovf_cnt_sys, err_cnt_sys};
endmodule

// ---------------------------------------------------------------------------
// Block-design wrapper for MACs with a standard (tready-less) RX AXI4-Stream:
// UltraScale+ CMAC (cmac_usplus axis_rx, 512 bit) and the 40G/50G subsystem
// (l_ethernet axis_rx_0, 256-bit "Regular AXI4-Stream"). Both flag a bad
// frame (FCS error etc.) with tuser[0] on the TLAST beat. MODE 1 (see top).
// ---------------------------------------------------------------------------
module axis_rx_frame_fifo #(
  parameter integer DATA_W          = 512,
  parameter integer TUSER_W         = 1,
  parameter integer DEPTH           = 2048,
  parameter integer DROP_ERR_FRAMES = 1
)(
  // From the MAC RX client (no TREADY: the MAC cannot be stalled)
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TDATA"  *) input  wire [DATA_W-1:0]   s_axis_tdata,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TKEEP"  *) input  wire [DATA_W/8-1:0] s_axis_tkeep,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TLAST"  *) input  wire                s_axis_tlast,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TUSER"  *) input  wire [TUSER_W-1:0]  s_axis_tuser,
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TVALID" *) input  wire                s_axis_tvalid,
  // To a standard AXIS slave (dwidth converter / CDC FIFO)
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
  input  wire aresetn,
  // MAC RX-side reset (active high, synchronous to aclk): discard the frame
  // being received; committed frames are kept (see s_abort above)
  input  wire rx_abort,
  // MAC TX-side reset / TX clock interruption (active high, synchronous to
  // aclk; the MAC's core clock is its TX clock): discard input while high
  input  wire rx_hold,
  // Drop-counter read-out clock (the AXI GPIO's s_axi_aclk)
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 SYS_CLK CLK" *)
  input  wire sys_clk,
  output wire [29:0] rx_drop_status
);
  rx_frame_fifo #(
    .DATA_W          (DATA_W),
    .DEPTH           (DEPTH),
    .DROP_ERR_FRAMES (DROP_ERR_FRAMES),
    .MODE            (1)
  ) fifo (
    .aclk           (aclk),
    .aresetn        (aresetn),
    .s_abort        (rx_abort),
    .s_hold         (rx_hold),
    .s_valid        (s_axis_tvalid),
    .s_last         (s_axis_tlast),
    .s_err          (s_axis_tuser[0]),
    .s_keep         (s_axis_tkeep),
    .s_data         (s_axis_tdata),
    .m_axis_tdata   (m_axis_tdata),
    .m_axis_tkeep   (m_axis_tkeep),
    .m_axis_tlast   (m_axis_tlast),
    .m_axis_tvalid  (m_axis_tvalid),
    .m_axis_tready  (m_axis_tready),
    .sys_clk        (sys_clk),
    .rx_drop_status (rx_drop_status)
  );
endmodule
