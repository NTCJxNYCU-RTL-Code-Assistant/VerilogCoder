`define SDR_REQ_ID_W       4

`define SDR_RFSH_TIMER_W    12
`define SDR_RFSH_ROW_CNT_W   3

// B2X Command

`define OP_PRE           2'b00
`define OP_ACT           2'b01
`define OP_RD            2'b10
`define OP_WR            2'b11

// SDRAM Commands (CS_N, RAS_N, CAS_N, WE_N)

`define SDR_DESEL        4'b1111
`define SDR_NOOP         4'b0111
`define SDR_ACTIVATE     4'b0011
`define SDR_READ         4'b0101
`define SDR_WRITE        4'b0100
`define SDR_BT           4'b0110
`define SDR_PRECHARGE    4'b0010
`define SDR_REFRESH      4'b0001
`define SDR_MODE         4'b0000

`define  ASIC            1'b1
`define  FPGA            1'b0
`define  TARGET_DESIGN   `FPGA
// 12 bit subtractor is not feasibile for FPGA, so changed to 6 bits
`define  REQ_BW    (`TARGET_DESIGN == `FPGA) ? 6 : 12   //  Request Width

module sdrc_bank_ctl_ref (clk,
		     reset_n,
		     a2b_req_depth,  // Number of requests we can buffer

		     /* Req from req_gen */
		     r2b_req,	   // request
		     r2b_req_id,   // ID
		     r2b_start,	   // First chunk of burst
		     r2b_last,	   // Last chunk of burst
		     r2b_wrap,
		     r2b_ba,	   // bank address
		     r2b_raddr,	   // row address
		     r2b_caddr,	   // col address
		     r2b_len,	   // length
		     r2b_write,	   // write request
		     b2r_arb_ok,   // OK to arbitrate for next xfr
		     b2r_ack,

		     /* Transfer request to xfr_ctl */
		     b2x_idle,	   // All banks are idle
		     b2x_req,	   // Request to xfr_ctl
		     b2x_start,	   // first chunk of transfer
		     b2x_last,	   // last chunk of transfer
		     b2x_wrap,
		     b2x_id,	   // Transfer ID
		     b2x_ba,	   // bank address
		     b2x_addr,	   // row/col address
		     b2x_len,	   // transfer length
		     b2x_cmd,	   // transfer command
		     x2b_ack,	   // command accepted
		     
		     /* Status to/from xfr_ctl */
		     b2x_tras_ok,  // TRAS OK for all banks
		     x2b_refresh,  // We did a refresh
		     x2b_pre_ok,   // OK to do a precharge (per bank)
		     x2b_act_ok,   // OK to do an activate
		     x2b_rdok,	   // OK to do a read
		     x2b_wrok,	   // OK to do a write

		     /* xfr msb address */
		     xfr_bank_sel,
                     sdr_req_norm_dma_last,

		     /* SDRAM Timing */
		     tras_delay,   // Active to precharge delay
		     trp_delay,	   // Precharge to active delay
		     trcd_delay);  // Active to R/W delay
   
parameter  SDR_DW   = 16;  // SDR Data Width 
parameter  SDR_BW   = 2;   // SDR Byte Width

   input                        clk, reset_n;

   input [1:0] 			a2b_req_depth;
   
   /* Req from bank_ctl */
   input 			r2b_req, r2b_start, r2b_last,
				r2b_write, r2b_wrap;
   input [`SDR_REQ_ID_W-1:0] 	r2b_req_id;
   input [1:0] 			r2b_ba;
   input [12:0] 		r2b_raddr;
   input [12:0] 		r2b_caddr;
   input [`REQ_BW-1:0] 	        r2b_len;
   output 			b2r_arb_ok, b2r_ack;
   input                        sdr_req_norm_dma_last;

   /* Req to xfr_ctl */
   output 			b2x_idle, b2x_req, b2x_start, b2x_last,
				b2x_tras_ok, b2x_wrap;
   output [`SDR_REQ_ID_W-1:0] 	b2x_id;
   output [1:0] 		b2x_ba;
   output [12:0] 		b2x_addr;
   output [`REQ_BW-1:0] 	b2x_len;
   output [1:0] 		b2x_cmd;
   input 			x2b_ack;

   /* Status from xfr_ctl */
   input [3:0] 			x2b_pre_ok;
   input 			x2b_refresh, x2b_act_ok, x2b_rdok,
				x2b_wrok;
   
   input [3:0] 			tras_delay, trp_delay, trcd_delay;

   input [1:0] xfr_bank_sel;

   /****************************************************************************/
   // Internal Nets

   wire [3:0] 			r2i_req, i2r_ack, i2x_req, 
				i2x_start, i2x_last, i2x_wrap, tras_ok;
   wire [12:0] 			i2x_addr0, i2x_addr1, i2x_addr2, i2x_addr3;
   wire [`REQ_BW-1:0] 		i2x_len0, i2x_len1, i2x_len2, i2x_len3;
   wire [1:0] 			i2x_cmd0, i2x_cmd1, i2x_cmd2, i2x_cmd3;
   wire [`SDR_REQ_ID_W-1:0] 	i2x_id0, i2x_id1, i2x_id2, i2x_id3;

   // ✅ 重要修正：這兩個在 always 裡被賦值，所以必須是 reg
   reg 				b2x_req;
   reg [1:0] 			b2x_ba;

   wire [3:0] 			x2i_ack;
   
   reg [`SDR_REQ_ID_W-1:0] 	curr_id;

   wire [1:0] 			xfr_ba;
   wire  			xfr_ba_last;
   wire [3:0] 			xfr_ok;

   // This 8 bit register stores the bank addresses for upto 4 requests.
   reg [7:0] 			rank_ba;
   reg [3:0] 			rank_ba_last;
   // This 3 bit counter counts the number of requests we have
   // buffered so far, legal values are 0, 1, 2, 3, or 4.
   reg [2:0] 			rank_cnt;
   wire [3:0] 			rank_req, rank_wr_sel;
   wire 			rank_fifo_wr, rank_fifo_rd;
   wire 			rank_fifo_full, rank_fifo_mt;
   
   wire [12:0] bank0_row, bank1_row, bank2_row, bank3_row;

   assign  b2x_tras_ok        = &tras_ok;

   // Distribute the request from req_gen
   assign r2i_req[0] = (r2b_ba == 2'b00) ? r2b_req & ~rank_fifo_full : 1'b0;
   assign r2i_req[1] = (r2b_ba == 2'b01) ? r2b_req & ~rank_fifo_full : 1'b0;
   assign r2i_req[2] = (r2b_ba == 2'b10) ? r2b_req & ~rank_fifo_full : 1'b0;
   assign r2i_req[3] = (r2b_ba == 2'b11) ? r2b_req & ~rank_fifo_full : 1'b0;

   // Assumption: Only one Ack Will be asserted at a time.
   assign b2r_ack  =|i2r_ack; 

   assign b2r_arb_ok = ~rank_fifo_full;
   
   // In FPGA Mode, to improve the timing, also send the rank_ba
   assign xfr_ba = (`TARGET_DESIGN == `FPGA) ? rank_ba[1:0]:
	           ((rank_fifo_mt) ? r2b_ba : rank_ba[1:0]);
   assign xfr_ba_last = (`TARGET_DESIGN == `FPGA) ? rank_ba_last[0]:
	                ((rank_fifo_mt) ? sdr_req_norm_dma_last : rank_ba_last[0]);
   
   assign rank_req[0] = i2x_req[xfr_ba];     // each rank generates requests
			
   assign rank_req[1] = (rank_cnt < 3'h2) ? 1'b0 :
			(rank_ba[3:2] == 2'b00) ? i2x_req[0] & ~i2x_cmd0[1] :
			(rank_ba[3:2] == 2'b01) ? i2x_req[1] & ~i2x_cmd1[1] :
			(rank_ba[3:2] == 2'b10) ? i2x_req[2] & ~i2x_cmd2[1] : 
			i2x_req[3] & ~i2x_cmd3[1];
			
   assign rank_req[2] = (rank_cnt < 3'h3) ? 1'b0 :
			(rank_ba[5:4] == 2'b00) ? i2x_req[0] & ~i2x_cmd0[1] :
			(rank_ba[5:4] == 2'b01) ? i2x_req[1] & ~i2x_cmd1[1] :
			(rank_ba[5:4] == 2'b10) ? i2x_req[2] & ~i2x_cmd2[1] : 
			i2x_req[3] & ~i2x_cmd3[1];
			
   assign rank_req[3] = (rank_cnt < 3'h4) ? 1'b0 :
			(rank_ba[7:6] == 2'b00) ? i2x_req[0] & ~i2x_cmd0[1] :
			(rank_ba[7:6] == 2'b01) ? i2x_req[1] & ~i2x_cmd1[1] :
			(rank_ba[7:6] == 2'b10) ? i2x_req[2] & ~i2x_cmd2[1] : 
			i2x_req[3] & ~i2x_cmd3[1];
			
   always @ (*) begin
      b2x_req = 1'b0;
      b2x_ba  = xfr_ba;

      if(`TARGET_DESIGN == `ASIC) begin // Support Multiple Rank request only on ASIC
         if (rank_req[0]) begin 
	    b2x_req = 1'b1;
	    b2x_ba  = xfr_ba;
         end
	 else if (rank_req[1]) begin 
	    b2x_req = 1'b1;
	    b2x_ba  = rank_ba[3:2];
         end
         else if (rank_req[2]) begin 
	    b2x_req = 1'b1;
	    b2x_ba  = rank_ba[5:4];
         end
         else if (rank_req[3]) begin 
	    b2x_req = 1'b1;
	    b2x_ba  = rank_ba[7:6];
         end
      end else begin // If FPGA
         if (rank_req[0]) begin 
	    b2x_req = 1'b1;
	 end
      end
   end

   assign b2x_idle  = rank_fifo_mt;
   assign b2x_start = i2x_start[b2x_ba];
   assign b2x_last  = i2x_last[b2x_ba];
   assign b2x_wrap  = i2x_wrap[b2x_ba];

   assign b2x_addr = (b2x_ba == 2'b11) ? i2x_addr3 :
		     (b2x_ba == 2'b10) ? i2x_addr2 :
		     (b2x_ba == 2'b01) ? i2x_addr1 : i2x_addr0;
   
   assign b2x_len = (b2x_ba == 2'b11) ? i2x_len3 :
		    (b2x_ba == 2'b10) ? i2x_len2 :
		    (b2x_ba == 2'b01) ? i2x_len1 : i2x_len0;
   
   assign b2x_cmd = (b2x_ba == 2'b11) ? i2x_cmd3 :
		    (b2x_ba == 2'b10) ? i2x_cmd2 :
		    (b2x_ba == 2'b01) ? i2x_cmd1 : i2x_cmd0;
   
   assign b2x_id = (b2x_ba == 2'b11) ? i2x_id3 :
		   (b2x_ba == 2'b10) ? i2x_id2 :
		   (b2x_ba == 2'b01) ? i2x_id1 : i2x_id0;
   
   assign x2i_ack[0] = (b2x_ba == 2'b00) ? x2b_ack : 1'b0;
   assign x2i_ack[1] = (b2x_ba == 2'b01) ? x2b_ack : 1'b0;
   assign x2i_ack[2] = (b2x_ba == 2'b10) ? x2b_ack : 1'b0;
   assign x2i_ack[3] = (b2x_ba == 2'b11) ? x2b_ack : 1'b0;

   // Rank Fifo
   assign rank_fifo_wr = b2r_ack;
   assign rank_fifo_rd = b2x_req & b2x_cmd[1] & x2b_ack;
   
   assign rank_wr_sel[0] = (rank_cnt == 3'h0) ? rank_fifo_wr : 
			   (rank_cnt == 3'h1) ? rank_fifo_wr & rank_fifo_rd : 
			   1'b0;

   assign rank_wr_sel[1] = (rank_cnt == 3'h1) ? rank_fifo_wr & ~rank_fifo_rd :
			   (rank_cnt == 3'h2) ? rank_fifo_wr & rank_fifo_rd :
			   1'b0; 

   assign rank_wr_sel[2] = (rank_cnt == 3'h2) ? rank_fifo_wr & ~rank_fifo_rd :
			   (rank_cnt == 3'h3) ? rank_fifo_wr & rank_fifo_rd :
			   1'b0; 

   assign rank_wr_sel[3] = (rank_cnt == 3'h3) ? rank_fifo_wr & ~rank_fifo_rd :
			   (rank_cnt == 3'h4) ? rank_fifo_wr & rank_fifo_rd :
			   1'b0; 

   assign rank_fifo_mt = (rank_cnt == 3'b0) ? 1'b1 : 1'b0;

   assign rank_fifo_full = (rank_cnt[2]) ? 1'b1 : 
			   (rank_cnt[1:0] == a2b_req_depth) ? 1'b1 : 1'b0; 

   // FIFO Check (simulation only)
   // synopsys translate_off
   always @ (posedge clk) begin
      if (~rank_fifo_wr & rank_fifo_rd && rank_cnt == 3'h0) begin
	 $display ("%t: %m: ERROR!!! Read from empty Fifo", $time);
	 $stop;
      end
      if (rank_fifo_wr && ~rank_fifo_rd && rank_cnt == 3'h4) begin
	 $display ("%t: %m: ERROR!!! Write to full Fifo", $time);
	 $stop;
      end
   end
   // synopsys translate_on
      
   always @ (posedge clk)
      if (~reset_n) begin
	 rank_cnt <= 3'b0;
	 rank_ba <= 8'b0;
	 rank_ba_last <= 4'b0;
      end
      else begin
	 rank_cnt <= (rank_fifo_wr & ~rank_fifo_rd) ? rank_cnt + 3'b1 :
		     (~rank_fifo_wr & rank_fifo_rd) ? rank_cnt - 3'b1 :
		     rank_cnt;

	 rank_ba[1:0] <= (rank_wr_sel[0]) ? r2b_ba :
			 (rank_fifo_rd) ? rank_ba[3:2] : rank_ba[1:0];
	 
	 rank_ba[3:2] <= (rank_wr_sel[1]) ? r2b_ba :
			 (rank_fifo_rd) ? rank_ba[5:4] : rank_ba[3:2];
	 
	 rank_ba[5:4] <= (rank_wr_sel[2]) ? r2b_ba :
			 (rank_fifo_rd) ? rank_ba[7:6] : rank_ba[5:4];
	 
	 rank_ba[7:6] <= (rank_wr_sel[3]) ? r2b_ba :
			 (rank_fifo_rd) ? 2'b00 : rank_ba[7:6];

	 if(`TARGET_DESIGN == `ASIC) begin
            rank_ba_last[0] <= (rank_wr_sel[0]) ? sdr_req_norm_dma_last :
                               (rank_fifo_rd) ?  rank_ba_last[1] : rank_ba_last[0];

            rank_ba_last[1] <= (rank_wr_sel[1]) ? sdr_req_norm_dma_last :
                               (rank_fifo_rd) ?  rank_ba_last[2] : rank_ba_last[1];

            rank_ba_last[2] <= (rank_wr_sel[2]) ? sdr_req_norm_dma_last :
                               (rank_fifo_rd) ?  rank_ba_last[3] : rank_ba_last[2];

            rank_ba_last[3] <= (rank_wr_sel[3]) ? sdr_req_norm_dma_last :
                               (rank_fifo_rd) ?  1'b0 : rank_ba_last[3];
         end
      end
   
   assign xfr_ok[0] = (xfr_ba == 2'b00) ? 1'b1 : 1'b0;
   assign xfr_ok[1] = (xfr_ba == 2'b01) ? 1'b1 : 1'b0;
   assign xfr_ok[2] = (xfr_ba == 2'b10) ? 1'b1 : 1'b0;
   assign xfr_ok[3] = (xfr_ba == 2'b11) ? 1'b1 : 1'b0;
   
   /****************************************************************************/
   // Instantiate Bank Ctl FSM 0
   sdrc_bank_fsm_ref bank0_fsm (.clk (clk),
			   .reset_n (reset_n),
			   .r2b_req (r2i_req[0]),
			   .r2b_req_id (r2b_req_id),
			   .r2b_start (r2b_start),
			   .r2b_last (r2b_last),
			   .r2b_wrap (r2b_wrap),
			   .r2b_raddr (r2b_raddr),
			   .r2b_caddr (r2b_caddr),
			   .r2b_len (r2b_len),
			   .r2b_write (r2b_write),
			   .b2r_ack (i2r_ack[0]),
                           .sdr_dma_last(rank_ba_last[0]),
			   .b2x_req (i2x_req[0]),
			   .b2x_start (i2x_start[0]),
			   .b2x_last (i2x_last[0]),
			   .b2x_wrap (i2x_wrap[0]),
			   .b2x_id (i2x_id0),
			   .b2x_addr (i2x_addr0),
			   .b2x_len (i2x_len0),
			   .b2x_cmd (i2x_cmd0),
			   .x2b_ack (x2i_ack[0]),
			   .tras_ok (tras_ok[0]),
			   .xfr_ok (xfr_ok[0]),
			   .x2b_refresh (x2b_refresh),
			   .x2b_pre_ok (x2b_pre_ok[0]),
			   .x2b_act_ok (x2b_act_ok),
			   .x2b_rdok (x2b_rdok),
			   .x2b_wrok (x2b_wrok),
			   .bank_row(bank0_row),
			   .tras_delay (tras_delay),
			   .trp_delay (trp_delay),
			   .trcd_delay (trcd_delay));
   
   /****************************************************************************/
   // Instantiate Bank Ctl FSM 1
   sdrc_bank_fsm_ref bank1_fsm (.clk (clk),
			   .reset_n (reset_n),
			   .r2b_req (r2i_req[1]),
			   .r2b_req_id (r2b_req_id),
			   .r2b_start (r2b_start),
			   .r2b_last (r2b_last),
			   .r2b_wrap (r2b_wrap),
			   .r2b_raddr (r2b_raddr),
			   .r2b_caddr (r2b_caddr),
			   .r2b_len (r2b_len),
			   .r2b_write (r2b_write),
			   .b2r_ack (i2r_ack[1]),
                           .sdr_dma_last(rank_ba_last[1]),
			   .b2x_req (i2x_req[1]),
			   .b2x_start (i2x_start[1]),
			   .b2x_last (i2x_last[1]),
			   .b2x_wrap (i2x_wrap[1]),
			   .b2x_id (i2x_id1),
			   .b2x_addr (i2x_addr1),
			   .b2x_len (i2x_len1),
			   .b2x_cmd (i2x_cmd1),
			   .x2b_ack (x2i_ack[1]),
			   .tras_ok (tras_ok[1]),
			   .xfr_ok (xfr_ok[1]),
			   .x2b_refresh (x2b_refresh),
			   .x2b_pre_ok (x2b_pre_ok[1]),
			   .x2b_act_ok (x2b_act_ok),
			   .x2b_rdok (x2b_rdok),
			   .x2b_wrok (x2b_wrok),
			   .bank_row(bank1_row),
			   .tras_delay (tras_delay),
			   .trp_delay (trp_delay),
			   .trcd_delay (trcd_delay));
   
   /****************************************************************************/
   // Instantiate Bank Ctl FSM 2
   sdrc_bank_fsm_ref bank2_fsm (.clk (clk),
			   .reset_n (reset_n),
			   .r2b_req (r2i_req[2]),
			   .r2b_req_id (r2b_req_id),
			   .r2b_start (r2b_start),
			   .r2b_last (r2b_last),
			   .r2b_wrap (r2b_wrap),
			   .r2b_raddr (r2b_raddr),
			   .r2b_caddr (r2b_caddr),
			   .r2b_len (r2b_len),
			   .r2b_write (r2b_write),
			   .b2r_ack (i2r_ack[2]),
                           .sdr_dma_last(rank_ba_last[2]),
			   .b2x_req (i2x_req[2]),
			   .b2x_start (i2x_start[2]),
			   .b2x_last (i2x_last[2]),
			   .b2x_wrap (i2x_wrap[2]),
			   .b2x_id (i2x_id2),
			   .b2x_addr (i2x_addr2),
			   .b2x_len (i2x_len2),
			   .b2x_cmd (i2x_cmd2),
			   .x2b_ack (x2i_ack[2]),
			   .tras_ok (tras_ok[2]),
			   .xfr_ok (xfr_ok[2]),
			   .x2b_refresh (x2b_refresh),
			   .x2b_pre_ok (x2b_pre_ok[2]),
			   .x2b_act_ok (x2b_act_ok),
			   .x2b_rdok (x2b_rdok),
			   .x2b_wrok (x2b_wrok),
			   .bank_row(bank2_row),
			   .tras_delay (tras_delay),
			   .trp_delay (trp_delay),
			   .trcd_delay (trcd_delay));
   
   /****************************************************************************/
   // Instantiate Bank Ctl FSM 3
   sdrc_bank_fsm_ref bank3_fsm (.clk (clk),
			   .reset_n (reset_n),
			   .r2b_req (r2i_req[3]),
			   .r2b_req_id (r2b_req_id),
			   .r2b_start (r2b_start),
			   .r2b_last (r2b_last),
			   .r2b_wrap (r2b_wrap),
			   .r2b_raddr (r2b_raddr),
			   .r2b_caddr (r2b_caddr),
			   .r2b_len (r2b_len),
			   .r2b_write (r2b_write),
			   .b2r_ack (i2r_ack[3]),
                           .sdr_dma_last(rank_ba_last[3]),
			   .b2x_req (i2x_req[3]),
			   .b2x_start (i2x_start[3]),
			   .b2x_last (i2x_last[3]),
			   .b2x_wrap (i2x_wrap[3]),
			   .b2x_id (i2x_id3),
			   .b2x_addr (i2x_addr3),
			   .b2x_len (i2x_len3),
			   .b2x_cmd (i2x_cmd3),
			   .x2b_ack (x2i_ack[3]),
			   .tras_ok (tras_ok[3]),
			   .xfr_ok (xfr_ok[3]),
			   .x2b_refresh (x2b_refresh),
			   .x2b_pre_ok (x2b_pre_ok[3]),
			   .x2b_act_ok (x2b_act_ok),
			   .x2b_rdok (x2b_rdok),
			   .x2b_wrok (x2b_wrok),
			   .bank_row(bank3_row),
			   .tras_delay (tras_delay),
			   .trp_delay (trp_delay),
			   .trcd_delay (trcd_delay));

   /* address for current xfr, debug only */
   wire [12:0] cur_row = (xfr_bank_sel==3) ? bank3_row:
			(xfr_bank_sel==2) ? bank2_row: 
			(xfr_bank_sel==1) ? bank1_row: bank0_row; 

endmodule // sdr_bank_ctl

module sdrc_bank_fsm_ref (clk,
		     reset_n,

		     /* Req from req_gen */
		     r2b_req,	   // request
		     r2b_req_id,   // ID
		     r2b_start,	   // First chunk of burst
		     r2b_last,	   // Last chunk of burst
		     r2b_wrap,
		     r2b_raddr,	   // row address
		     r2b_caddr,	   // col address
		     r2b_len,	   // length
		     r2b_write,	   // write request
		     b2r_ack,
                     sdr_dma_last,

		     /* Transfer request to xfr_ctl */
		     b2x_req,	   // Request to xfr_ctl
		     b2x_start,	   // first chunk of transfer
		     b2x_last,	   // last chunk of transfer
		     b2x_wrap,
		     b2x_id,	   // Transfer ID
		     b2x_addr,	   // row/col address
		     b2x_len,	   // transfer length
		     b2x_cmd,	   // transfer command
		     x2b_ack,	   // command accepted
		     
		     /* Status to/from xfr_ctl */
		     tras_ok,      // TRAS OK for this bank
		     xfr_ok,
		     x2b_refresh,  // We did a refresh
		     x2b_pre_ok,   // OK to do a precharge (per bank)
		     x2b_act_ok,   // OK to do an activate
		     x2b_rdok,	   // OK to do a read
		     x2b_wrok,	   // OK to do a write

		     /* current xfr row address of the bank */
		     bank_row,

		     /* SDRAM Timing */
		     tras_delay,   // Active to precharge delay
		     trp_delay,	   // Precharge to active delay
		     trcd_delay);  // Active to R/W delay
   

parameter  SDR_DW   = 16;  // SDR Data Width 
parameter  SDR_BW   = 2;   // SDR Byte Width

   input                        clk, reset_n;

   /* Req from bank_ctl */
   input 			r2b_req, r2b_start, r2b_last,
				r2b_write, r2b_wrap;
   input [`SDR_REQ_ID_W-1:0] 	r2b_req_id;
   input [12:0] 		r2b_raddr;
   input [12:0] 		r2b_caddr;
   input [`REQ_BW-1:0] 	r2b_len;
   output 			b2r_ack;
   input                        sdr_dma_last;

   /* Req to xfr_ctl */
   output 			b2x_req, b2x_start, b2x_last,
				tras_ok, b2x_wrap;
   output [`SDR_REQ_ID_W-1:0] 	b2x_id;
   output [12:0] 		b2x_addr;
   output [`REQ_BW-1:0] 	b2x_len;
   output [1:0] 		b2x_cmd;
   input 			x2b_ack;

   /* Status from xfr_ctl */
   input 			x2b_refresh, x2b_act_ok, x2b_rdok,
				x2b_wrok, x2b_pre_ok, xfr_ok;
   
   input [3:0] 			tras_delay, trp_delay, trcd_delay;

   output [12:0] 			bank_row;

   /****************************************************************************/
   // Internal Nets

   `define BANK_IDLE         3'b000
   `define BANK_PRE          3'b001
   `define BANK_ACT          3'b010
   `define BANK_XFR          3'b011
   `define BANK_DMA_LAST_PRE 3'b100

   reg [2:0] 			bank_st, next_bank_st;
   wire 			b2x_start, b2x_last;
   reg 				l_start, l_last;
   reg 				b2x_req, b2r_ack;
   wire [`SDR_REQ_ID_W-1:0] 	b2x_id;
   reg [`SDR_REQ_ID_W-1:0] 	l_id;
   reg [12:0] 			b2x_addr;
   reg [`REQ_BW-1:0] 	l_len;
   wire [`REQ_BW-1:0] 	b2x_len;
   reg [1:0] 			b2x_cmd_t;
   reg  			bank_valid;
   reg [12:0] 			bank_row;
   reg [3:0] 			tras_cntr, timer0;
   reg 				l_wrap, l_write;
   wire 			b2x_wrap;
   reg [12:0] 			l_raddr;
   reg [12:0] 			l_caddr;
   reg                          l_sdr_dma_last;
   reg                          bank_prech_page_closed;
   
   wire  			tras_ok_internal, tras_ok, activate_bank;
   
   wire 			page_hit, timer0_tc_t, ld_trp, ld_trcd;

   /*** Timing Break Logic Added for FPGA - Start ****/
   reg	x2b_wrok_r, xfr_ok_r , x2b_rdok_r;
   reg [1:0] b2x_cmd_r,timer0_tc_r,tras_ok_r,x2b_pre_ok_r,x2b_act_ok_r;
   always @ (posedge clk)
      if (~reset_n) begin
	 x2b_wrok_r <= 1'b0;
	 xfr_ok_r   <= 1'b0;
	 x2b_rdok_r <= 1'b0;
	 b2x_cmd_r  <= 2'b0;
	 timer0_tc_r  <= 1'b0;
	 tras_ok_r    <= 1'b0;
	 x2b_pre_ok_r <= 1'b0;
	 x2b_act_ok_r <= 1'b0;
      end
      else begin
	 x2b_wrok_r <= x2b_wrok;
	 xfr_ok_r   <= xfr_ok;
	 x2b_rdok_r <= x2b_rdok;
	 b2x_cmd_r  <= b2x_cmd_t;
	 timer0_tc_r <= (ld_trp | ld_trcd) ? 1'b0 : timer0_tc_t;
	 tras_ok_r   <= tras_ok_internal;
	 x2b_pre_ok_r  <= x2b_pre_ok;
	 x2b_act_ok_r  <= x2b_act_ok;
      end

 wire  x2b_wrok_t     = (`TARGET_DESIGN == `FPGA) ? x2b_wrok_r : x2b_wrok;
 wire  xfr_ok_t       = (`TARGET_DESIGN == `FPGA) ? xfr_ok_r : xfr_ok;
 wire  x2b_rdok_t     = (`TARGET_DESIGN == `FPGA) ? x2b_rdok_r : x2b_rdok;
 wire [1:0] b2x_cmd   = (`TARGET_DESIGN == `FPGA) ? b2x_cmd_r : b2x_cmd_t;
 wire  timer0_tc      = (`TARGET_DESIGN == `FPGA) ? timer0_tc_r : timer0_tc_t;
 assign  tras_ok      = (`TARGET_DESIGN == `FPGA) ? tras_ok_r : tras_ok_internal;
 wire  x2b_pre_ok_t   = (`TARGET_DESIGN == `FPGA) ? x2b_pre_ok_r : x2b_pre_ok;
 wire  x2b_act_ok_t   = (`TARGET_DESIGN == `FPGA) ? x2b_act_ok_r : x2b_act_ok;

   /*** Timing Break Logic Added for FPGA - End****/


   always @ (posedge clk)
      if (~reset_n) begin
	 bank_valid <= 1'b0;
	 tras_cntr <= 4'b0;
	 timer0 <= 4'b0;
	 bank_st <= `BANK_IDLE;
      end // if (~reset_n)

      else begin

	 bank_valid <= (x2b_refresh || bank_prech_page_closed) ? 1'b0 :  // force the bank status to be invalid
		       (activate_bank) ? 1'b1 : bank_valid;

	 tras_cntr <= (activate_bank) ? tras_delay :
		      (~tras_ok_internal) ? tras_cntr - 4'b1 : 4'b0;
	 
	 timer0 <= (ld_trp) ? trp_delay :
		   (ld_trcd) ? trcd_delay :
		   (timer0 != 'h0) ? timer0 - 4'b1 : timer0;
	 
	 bank_st <= next_bank_st;

      end // else: !if(~reset_n)

   always @ (posedge clk) begin 

      bank_row <= (bank_st == `BANK_ACT) ? b2x_addr : bank_row;

      if (~reset_n) begin
	 l_start <= 1'b0;
	 l_last <= 1'b0;
	 l_id <= 1'b0;
	 l_len <= 1'b0;
	 l_wrap <= 1'b0;
	 l_write <= 1'b0;
	 l_raddr <= 1'b0;
	 l_caddr <= 1'b0;
         l_sdr_dma_last <= 1'b0;
      end
      else begin
        if (b2r_ack) begin
  	   l_start <= r2b_start;
  	   l_last <= r2b_last;
  	   l_id <= r2b_req_id;
  	   l_len <= r2b_len;
  	   l_wrap <= r2b_wrap;
  	   l_write <= r2b_write;
  	   l_raddr <= r2b_raddr;
  	   l_caddr <= r2b_caddr;
           l_sdr_dma_last <= sdr_dma_last;
        end // if (b2r_ack)
      end

   end // always @ (posedge clk)
   
   assign tras_ok_internal = ~|tras_cntr;

   assign activate_bank = (b2x_cmd == `OP_ACT) & x2b_ack;

   assign page_hit = (r2b_raddr == bank_row) ? bank_valid : 1'b0;    // its a hit only if bank is valid

   assign timer0_tc_t = ~|timer0;

   assign ld_trp = (b2x_cmd == `OP_PRE) ? x2b_ack : 1'b0;

   assign ld_trcd = (b2x_cmd == `OP_ACT) ? x2b_ack : 1'b0;
   


   always @ (*) begin

       bank_prech_page_closed = 1'b0;
       b2x_req = 1'b0;
       b2x_cmd_t = 2'bx;
       b2r_ack = 1'b0;
       b2x_addr = 13'bx;
       next_bank_st = bank_st;

      case (bank_st)

	`BANK_IDLE : begin
		if(`TARGET_DESIGN == `FPGA) begin // To break the timing, b2x request are generated delayed
	             if (~r2b_req) begin
	                next_bank_st = `BANK_IDLE;
	             end // if (~r2b_req)
	             else if (page_hit) begin 
	                b2r_ack = 1'b1;
	                b2x_cmd_t = (r2b_write) ? `OP_WR : `OP_RD;
	                next_bank_st = `BANK_XFR;  
	             end // if (page_hit)
	             else begin  // page_miss
	                b2r_ack = 1'b1;
	                b2x_cmd_t = `OP_PRE;
	                next_bank_st = `BANK_PRE;  // bank was precharged on l_sdr_dma_last
	             end // else: !if(page_hit)
		end else begin // ASIC
	             if (~r2b_req) begin
                        bank_prech_page_closed = 1'b0;
	                b2x_req = 1'b0;
	                b2x_cmd_t = 2'bx;
	                b2r_ack = 1'b0;
	                b2x_addr = 13'bx;
	                next_bank_st = `BANK_IDLE;
	             end // if (~r2b_req)
	             else if (page_hit) begin 
	                b2x_req = (r2b_write) ? x2b_wrok_t & xfr_ok_t : 
			                       x2b_rdok_t & xfr_ok_t;
	                b2x_cmd_t = (r2b_write) ? `OP_WR : `OP_RD;
	                b2r_ack = 1'b1;
	                b2x_addr = r2b_caddr;
	                next_bank_st = (x2b_ack) ? `BANK_IDLE : `BANK_XFR;  // in case of hit, stay here till xfr sm acks
	             end // if (page_hit)
	             else begin  // page_miss
	                b2x_req = tras_ok & x2b_pre_ok_t;
	                b2x_cmd_t = `OP_PRE;
	                b2r_ack = 1'b1;
	                b2x_addr = r2b_raddr & 13'hBFF;	   // Dont want to pre all banks!
	                next_bank_st = (l_sdr_dma_last) ? `BANK_PRE : (x2b_ack) ? `BANK_ACT : `BANK_PRE;  // bank was precharged on l_sdr_dma_last
	             end // else: !if(page_hit)
	        end
	end // case: `BANK_IDLE

	`BANK_PRE : begin
	   b2x_req = tras_ok & x2b_pre_ok_t;
	   b2x_cmd_t = `OP_PRE;
	   b2r_ack = 1'b0;
	   b2x_addr = l_raddr & 13'hBFF;	   // Dont want to pre all banks!
           bank_prech_page_closed = 1'b0;
	   next_bank_st = (x2b_ack) ? `BANK_ACT : `BANK_PRE;
	end // case: `BANK_PRE

	`BANK_ACT : begin
	   b2x_req = timer0_tc & x2b_act_ok_t;
	   b2x_cmd_t = `OP_ACT;
	   b2r_ack = 1'b0;
	   b2x_addr = l_raddr;
           bank_prech_page_closed = 1'b0;
	   next_bank_st = (x2b_ack) ? `BANK_XFR : `BANK_ACT;
	end // case: `BANK_ACT
	
	`BANK_XFR : begin
	   b2x_req = (l_write) ? timer0_tc & x2b_wrok_t & xfr_ok_t :
		     timer0_tc & x2b_rdok_t & xfr_ok_t; 
	   b2x_cmd_t = (l_write) ? `OP_WR : `OP_RD;
	   b2r_ack = 1'b0;
	   b2x_addr = l_caddr;
           bank_prech_page_closed = 1'b0;
	   next_bank_st = (x2b_refresh) ? `BANK_ACT : 
                          (x2b_ack & l_sdr_dma_last) ? `BANK_DMA_LAST_PRE :
			  (x2b_ack) ? `BANK_IDLE : `BANK_XFR;
	end // case: `BANK_XFR

        `BANK_DMA_LAST_PRE : begin
	   b2x_req = tras_ok & x2b_pre_ok_t;
	   b2x_cmd_t = `OP_PRE;
	   b2r_ack = 1'b0;
	   b2x_addr = l_raddr & 13'hBFF;	   // Dont want to pre all banks!
           bank_prech_page_closed = 1'b1;
	   next_bank_st = (x2b_ack) ? `BANK_IDLE : `BANK_DMA_LAST_PRE;
	end // case: `BANK_DMA_LAST_PRE
          
      endcase // case(bank_st)

   end // always @ (bank_st or ...)

   assign b2x_start = (bank_st == `BANK_IDLE) ? r2b_start : l_start;

   assign b2x_last = (bank_st == `BANK_IDLE) ? r2b_last : l_last;

   assign b2x_id = (bank_st == `BANK_IDLE) ? r2b_req_id : l_id;

   assign b2x_len = (bank_st == `BANK_IDLE) ? r2b_len : l_len;

   assign b2x_wrap = (bank_st == `BANK_IDLE) ? r2b_wrap : l_wrap;
   
endmodule // sdr_bank_fsm

module sdrc_bs_convert_ref (
                    clk                 ,
                    reset_n             ,
                    sdr_width           ,

        /* Control Signal from xfr ctrl */
                    x2a_rdstart         ,
                    x2a_wrstart         ,
                    x2a_rdlast          ,
                    x2a_wrlast          ,
                    x2a_rddt            ,
                    x2a_rdok            ,
                    a2x_wrdt            ,
                    a2x_wren_n          ,
                    x2a_wrnext          ,

   /*  Control Signal from/to to application i/f  */
                    app_wr_data         ,
                    app_wr_en_n         ,
                    app_wr_next         ,
                    app_last_wr         ,
                    app_rd_data         ,
                    app_rd_valid        ,
		    app_last_rd
		);


parameter  APP_AW   = 30;  // Application Address Width
parameter  APP_DW   = 32;  // Application Data Width 
parameter  APP_BW   = 4;   // Application Byte Width

parameter  SDR_DW   = 16;  // SDR Data Width 
parameter  SDR_BW   = 2;   // SDR Byte Width
   
input                    clk              ;
input                    reset_n          ;
input [1:0]              sdr_width        ; // 2'b00 - 32 Bit SDR, 2'b01 - 16 Bit SDR, 2'b1x - 8 Bit

/* Control Signal from xfr ctrl Read Transaction*/
input                    x2a_rdstart      ; // read start indication
input                    x2a_rdlast       ; //  read last burst access
input [SDR_DW-1:0]       x2a_rddt         ;
input                    x2a_rdok         ;

/* Control Signal from xfr ctrl Write Transaction*/
input                    x2a_wrstart      ; // writ start indication
input                    x2a_wrlast       ; // write last transfer
input                    x2a_wrnext       ;
output [SDR_DW-1:0]      a2x_wrdt         ;
output [SDR_BW-1:0]      a2x_wren_n       ;

// Application Write Transaction
input  [APP_DW-1:0]      app_wr_data      ;
input  [APP_BW-1:0]      app_wr_en_n      ;
output                   app_wr_next      ;
output                   app_last_wr      ; // Indicate last Write Transfer for a given burst size

// Application Read Transaction
output [APP_DW-1:0]      app_rd_data      ;
output                   app_rd_valid     ;
output                   app_last_rd      ; // Indicate last Read Transfer for a given burst size

//----------------------------------------------
// Local Decleration
// ----------------------------------------

reg [APP_DW-1:0]         app_rd_data      ;
reg                      app_rd_valid     ;
reg [SDR_DW-1:0]         a2x_wrdt         ;
reg [SDR_BW-1:0]         a2x_wren_n       ;
reg                      app_wr_next      ;

reg [23:0]               saved_rd_data    ;
reg [1:0]                rd_xfr_count     ;
reg [1:0]                wr_xfr_count     ;


assign  app_last_wr = x2a_wrlast;
assign  app_last_rd = x2a_rdlast;

always @(*) begin
        if(sdr_width == 2'b00) // 32 Bit SDR Mode
          begin
            a2x_wrdt             = app_wr_data;
            a2x_wren_n           = app_wr_en_n;
            app_wr_next          = x2a_wrnext;
            app_rd_data          = x2a_rddt;
            app_rd_valid         = x2a_rdok;
          end
        else if(sdr_width == 2'b01) // 16 Bit SDR Mode
        begin
           // Changed the address and length to match the 16 bit SDR Mode
            app_wr_next          = (x2a_wrnext & wr_xfr_count[0]);
            app_rd_valid         = (x2a_rdok & rd_xfr_count[0]);
            if(wr_xfr_count[0] == 1'b1)
              begin
                a2x_wren_n      = app_wr_en_n[3:2];
                a2x_wrdt        = app_wr_data[31:16];
              end
            else
              begin
                a2x_wren_n      = app_wr_en_n[1:0];
                a2x_wrdt        = app_wr_data[15:0];
              end
            
            app_rd_data = {x2a_rddt,saved_rd_data[15:0]};
        end else  // 8 Bit SDR Mode
        begin
           // Changed the address and length to match the 16 bit SDR Mode
            app_wr_next         = (x2a_wrnext & (wr_xfr_count[1:0]== 2'b11));
            app_rd_valid        = (x2a_rdok &   (rd_xfr_count[1:0]== 2'b11));
            if(wr_xfr_count[1:0] == 2'b11)
            begin
                a2x_wren_n      = app_wr_en_n[3];
                a2x_wrdt        = app_wr_data[31:24];
            end
            else if(wr_xfr_count[1:0] == 2'b10)
            begin
                a2x_wren_n      = app_wr_en_n[2];
                a2x_wrdt        = app_wr_data[23:16];
            end
            else if(wr_xfr_count[1:0] == 2'b01)
            begin
                a2x_wren_n      = app_wr_en_n[1];
                a2x_wrdt        = app_wr_data[15:8];
            end
            else begin
                a2x_wren_n      = app_wr_en_n[0];
                a2x_wrdt        = app_wr_data[7:0];
            end
            
            app_rd_data         = {x2a_rddt,saved_rd_data[23:0]};
          end
     end



always @(posedge clk)
  begin
    if(!reset_n)
      begin
        rd_xfr_count    <= 8'b0;
        wr_xfr_count    <= 8'b0;
	saved_rd_data   <= 24'h0;
      end
    else begin

	// During Write Phase
        if(x2a_wrlast) begin
           wr_xfr_count    <= 0;
        end
        else if(x2a_wrnext) begin
           wr_xfr_count <= wr_xfr_count + 1'b1;
        end

	// During Read Phase
        if(x2a_rdlast) begin
           rd_xfr_count    <= 0;
        end
        else if(x2a_rdok) begin
           rd_xfr_count   <= rd_xfr_count + 1'b1;
	end

	// Save Previous Data
        if(x2a_rdok) begin
	   if(sdr_width == 2'b01) // 16 Bit SDR Mode
	      saved_rd_data[15:0]  <= x2a_rddt;
            else begin// 8 bit SDR Mode - 
	       if(rd_xfr_count[1:0] == 2'b00)      saved_rd_data[7:0]   <= x2a_rddt[7:0];
	       else if(rd_xfr_count[1:0] == 2'b01) saved_rd_data[15:8]  <= x2a_rddt[7:0];
	       else if(rd_xfr_count[1:0] == 2'b10) saved_rd_data[23:16] <= x2a_rddt[7:0];
	    end
        end
    end
end

endmodule // sdr_bs_convert


module RefModule 
           (
		clk,
                pad_clk,
		reset_n,
                sdr_width,
		cfg_colbits,

		/* Request from app */
		app_req,	        // Transfer Request
		app_req_addr,	        // SDRAM Address
		app_req_len,	        // Burst Length (in 16 bit words)
		app_req_wrap,	        // Wrap mode request (xfr_len = 4)
		app_req_wr_n,	        // 0 => Write request, 1 => read req
		app_req_ack,	        // Request has been accepted
		cfg_req_depth,	        //how many req. buffer should hold
		
		app_wr_data,
                app_wr_en_n,
		app_last_wr,

		app_rd_data,
		app_rd_valid,
		app_last_rd,
		app_wr_next_req,
		sdr_init_done,
		app_req_dma_last,

		/* Interface to SDRAMs */
		sdr_cs_n,
		sdr_cke,
		sdr_ras_n,
		sdr_cas_n,
		sdr_we_n,
		sdr_dqm,
		sdr_ba,
		sdr_addr, 
		pad_sdr_din,
		sdr_dout,
		sdr_den_n,

		/* Parameters */
		cfg_sdr_en,
		cfg_sdr_mode_reg,
		cfg_sdr_tras_d,
		cfg_sdr_trp_d,
		cfg_sdr_trcd_d,
		cfg_sdr_cas,
		cfg_sdr_trcar_d,
		cfg_sdr_twr_d,
		cfg_sdr_rfsh,
		cfg_sdr_rfmax);
  
parameter  APP_AW   = 26;  // Application Address Width
parameter  APP_DW   = 32;  // Application Data Width 
parameter  APP_BW   = 4;   // Application Byte Width
parameter  APP_RW   = 9;   // Application Request Width

parameter  SDR_DW   = 16;  // SDR Data Width 
parameter  SDR_BW   = 2;   // SDR Byte Width
             

//-----------------------------------------------
// Global Variable
// ----------------------------------------------
input                   clk                 ; // SDRAM Clock 
input                   pad_clk             ; // SDRAM Clock from Pad, used for registering Read Data
input                   reset_n             ; // Reset Signal
input [1:0]             sdr_width           ; // 2'b00 - 32 Bit SDR, 2'b01 - 16 Bit SDR, 2'b1x - 8 Bit
input [1:0]             cfg_colbits         ; // 2'b00 - 8 Bit column address, 2'b01 - 9 Bit, 10 - 10 bit, 11 - 11Bits


//------------------------------------------------
// Request from app
//------------------------------------------------
input 			app_req             ; // Application Request
input [APP_AW-1:0] 	app_req_addr        ; // Address 
input 			app_req_wr_n        ; // 0 - Write, 1 - Read
input                   app_req_wrap        ; // Address Wrap
output                  app_req_ack         ; // Application Request Ack
		
input [APP_DW-1:0] 	app_wr_data         ; // Write Data
output 		        app_wr_next_req     ; // Next Write Data Request
input [APP_BW-1:0] 	app_wr_en_n         ; // Byte wise Write Enable
output                  app_last_wr         ; // Last Write trannsfer of a given Burst
output [APP_DW-1:0] 	app_rd_data         ; // Read Data
output                  app_rd_valid        ; // Read Valid
output                  app_last_rd         ; // Last Read Transfer of a given Burst
		
//------------------------------------------------
// Interface to SDRAMs
//------------------------------------------------
output                  sdr_cke             ; // SDRAM CKE
output 			sdr_cs_n            ; // SDRAM Chip Select
output                  sdr_ras_n           ; // SDRAM ras
output                  sdr_cas_n           ; // SDRAM cas
output			sdr_we_n            ; // SDRAM write enable
output [SDR_BW-1:0] 	sdr_dqm             ; // SDRAM Data Mask
output [1:0] 		sdr_ba              ; // SDRAM Bank Enable
output [12:0] 		sdr_addr            ; // SDRAM Address
input [SDR_DW-1:0] 	pad_sdr_din         ; // SDRA Data Input
output [SDR_DW-1:0] 	sdr_dout            ; // SDRAM Data Output
output [SDR_BW-1:0] 	sdr_den_n           ; // SDRAM Data Output enable

//------------------------------------------------
// Configuration Parameter
//------------------------------------------------
output                  sdr_init_done       ; // Indicate SDRAM Initialisation Done
input [3:0] 		cfg_sdr_tras_d      ; // Active to precharge delay
input [3:0]             cfg_sdr_trp_d       ; // Precharge to active delay
input [3:0]             cfg_sdr_trcd_d      ; // Active to R/W delay
input 			cfg_sdr_en          ; // Enable SDRAM controller
input [1:0] 		cfg_req_depth       ; // Maximum Request accepted by SDRAM controller
input [APP_RW-1:0]	app_req_len         ; // Application Burst Request length in 32 bit 
input [12:0] 		cfg_sdr_mode_reg    ;
input [2:0] 		cfg_sdr_cas         ; // SDRAM CAS Latency
input [3:0] 		cfg_sdr_trcar_d     ; // Auto-refresh period
input [3:0]             cfg_sdr_twr_d       ; // Write recovery delay
input [`SDR_RFSH_TIMER_W-1 : 0] cfg_sdr_rfsh;
input [`SDR_RFSH_ROW_CNT_W -1 : 0] cfg_sdr_rfmax;
input                   app_req_dma_last;    // this signal should close the bank

/****************************************************************************/
// Internal Nets  (✅ 修正：補齊缺的 wire、移除重複宣告 port 的 wire)

/* req_gen -> bank_ctl */
wire                        r2b_req;
wire [`SDR_REQ_ID_W-1:0]     r2b_req_id;
wire                        r2b_start;
wire                        r2b_last;
wire                        r2b_wrap;
wire [1:0]                  r2b_ba;
wire [12:0]                 r2b_raddr;
wire [12:0]                 r2b_caddr;
wire [`REQ_BW-1:0]           r2b_len;
wire                        r2b_write;

/* bank_ctl <-> req_gen */
wire                        b2r_ack;
wire                        b2r_arb_ok;

/* bank_ctl -> xfr_ctl */
wire                        b2x_idle;
wire                        b2x_req;
wire                        b2x_start;
wire                        b2x_last;
wire                        b2x_wrap;
wire [`SDR_REQ_ID_W-1:0]     b2x_id;
wire [1:0]                  b2x_ba;
wire [12:0]                 b2x_addr;
wire [`REQ_BW-1:0]           b2x_len;
wire [1:0]                  b2x_cmd;

/* xfr_ctl -> bank_ctl status */
wire                        x2b_ack;
wire                        b2x_tras_ok;
wire                        x2b_refresh;
wire [3:0]                  x2b_pre_ok;
wire                        x2b_act_ok;
wire                        x2b_rdok;
wire                        x2b_wrok;

/* req_gen <-> xfr_ctl */
wire                        r2x_idle;

/* xfr_ctl <-> bs_convert (dataflow control) */
wire                        x2a_rdstart;
wire                        x2a_wrstart;
wire [`SDR_REQ_ID_W-1:0]     xfr_id;
wire                        x2a_rdlast;
wire                        x2a_wrlast;
wire                        x2a_wrnext;
wire [SDR_DW-1:0]            x2a_rddt;
wire                        x2a_rdok;

/* bs_convert -> xfr_ctl write data */
wire [SDR_DW-1:0]            a2x_wrdt;
wire [SDR_BW-1:0]            a2x_wren_n;

/* xfr_ctl internal SDR outputs (to drive ports via assign) */
wire [SDR_DW-1:0]            sdr_dout_int;
wire [SDR_BW-1:0]            sdr_den_n_int;

wire [1:0]                   xfr_bank_sel;

// synopsys translate_off 
   wire [3:0]           sdr_cmd;
   assign sdr_cmd = {sdr_cs_n, sdr_ras_n, sdr_cas_n, sdr_we_n}; 
// synopsys translate_on 

assign sdr_den_n = sdr_den_n_int ; 
assign sdr_dout  = sdr_dout_int ;


// To meet the timing at read path, read data is registered w.r.t pad_sdram_clock and register back to sdram_clk
reg [SDR_DW-1:0] pad_sdr_din1;
reg [SDR_DW-1:0] pad_sdr_din2;
always@(posedge pad_clk) begin
   pad_sdr_din1 <= pad_sdr_din;
end

always@(posedge clk) begin
   pad_sdr_din2 <= pad_sdr_din1;
end


sdrc_req_gen_ref #(.SDR_DW(SDR_DW) , .SDR_BW(SDR_BW)) u_req_gen (
          .clk                (clk          ),
          .reset_n            (reset_n            ),
	  .cfg_colbits        (cfg_colbits        ),
          .sdr_width          (sdr_width          ),

	/* Req to xfr_ctl */
          .r2x_idle           (r2x_idle           ),

	/* Request from app */
          .req                (app_req            ),
          .req_id             (4'b0               ),
          .req_addr           (app_req_addr       ),
          .req_len            (app_req_len        ),
          .req_wrap           (app_req_wrap       ),
          .req_wr_n           (app_req_wr_n       ),
          .req_ack            (app_req_ack        ),
		
       /* Req to bank_ctl */
          .r2b_req            (r2b_req            ),
          .r2b_req_id         (r2b_req_id         ),
          .r2b_start          (r2b_start          ),
          .r2b_last           (r2b_last           ),
          .r2b_wrap           (r2b_wrap           ),
          .r2b_ba             (r2b_ba             ),
          .r2b_raddr          (r2b_raddr          ),
          .r2b_caddr          (r2b_caddr          ),
          .r2b_len            (r2b_len            ),
          .r2b_write          (r2b_write          ),
          .b2r_ack            (b2r_ack            ),
          .b2r_arb_ok         (b2r_arb_ok         )
     );


sdrc_bank_ctl_ref #(.SDR_DW(SDR_DW) ,  .SDR_BW(SDR_BW)) u_bank_ctl (
          .clk                (clk          ),
          .reset_n            (reset_n            ),
          .a2b_req_depth      (cfg_req_depth      ),
			      
      /* Req from req_gen */
          .r2b_req            (r2b_req            ),
          .r2b_req_id         (r2b_req_id         ),
          .r2b_start          (r2b_start          ),
          .r2b_last           (r2b_last           ),
          .r2b_wrap           (r2b_wrap           ),
          .r2b_ba             (r2b_ba             ),
          .r2b_raddr          (r2b_raddr          ),
          .r2b_caddr          (r2b_caddr          ),
          .r2b_len            (r2b_len            ),
          .r2b_write          (r2b_write          ),
          .b2r_arb_ok         (b2r_arb_ok         ),
          .b2r_ack            (b2r_ack            ),
			      
      /* Transfer request to xfr_ctl */
          .b2x_idle           (b2x_idle           ),
          .b2x_req            (b2x_req            ),
          .b2x_start          (b2x_start          ),
          .b2x_last           (b2x_last           ),
          .b2x_wrap           (b2x_wrap           ),
          .b2x_id             (b2x_id             ),
          .b2x_ba             (b2x_ba             ),
          .b2x_addr           (b2x_addr           ),
          .b2x_len            (b2x_len            ),
          .b2x_cmd            (b2x_cmd            ),
          .x2b_ack            (x2b_ack            ),
		     
      /* Status from xfr_ctl */
          .b2x_tras_ok        (b2x_tras_ok        ),
          .x2b_refresh        (x2b_refresh        ),
          .x2b_pre_ok         (x2b_pre_ok         ),
          .x2b_act_ok         (x2b_act_ok         ),
          .x2b_rdok           (x2b_rdok           ),
          .x2b_wrok           (x2b_wrok           ),

      /* for generate cuurent xfr address msb */
          .sdr_req_norm_dma_last(app_req_dma_last),
          .xfr_bank_sel       (xfr_bank_sel       ),

       /* SDRAM Timing */
          .tras_delay         (cfg_sdr_tras_d     ),
          .trp_delay          (cfg_sdr_trp_d      ),
          .trcd_delay         (cfg_sdr_trcd_d     )
      );
   

sdrc_xfr_ctl_ref #(.SDR_DW(SDR_DW) ,  .SDR_BW(SDR_BW)) u_xfr_ctl (
          .clk                (clk          ),
          .reset_n            (reset_n            ),
			    
      /* Transfer request from bank_ctl */
          .r2x_idle           (r2x_idle           ),
          .b2x_idle           (b2x_idle           ),
          .b2x_req            (b2x_req            ),
          .b2x_start          (b2x_start          ),
          .b2x_last           (b2x_last           ),
          .b2x_wrap           (b2x_wrap           ),
          .b2x_id             (b2x_id             ),
          .b2x_ba             (b2x_ba             ),
          .b2x_addr           (b2x_addr           ),
          .b2x_len            (b2x_len            ),
          .b2x_cmd            (b2x_cmd            ),
          .x2b_ack            (x2b_ack            ),
		     
       /* Status to bank_ctl, req_gen */
          .b2x_tras_ok        (b2x_tras_ok        ),
          .x2b_refresh        (x2b_refresh        ),
          .x2b_pre_ok         (x2b_pre_ok         ),
          .x2b_act_ok         (x2b_act_ok         ),
          .x2b_rdok           (x2b_rdok           ),
          .x2b_wrok           (x2b_wrok           ),
		    
       /* SDRAM I/O */
          .sdr_cs_n           (sdr_cs_n           ),
          .sdr_cke            (sdr_cke            ),
          .sdr_ras_n          (sdr_ras_n          ),
          .sdr_cas_n          (sdr_cas_n          ),
          .sdr_we_n           (sdr_we_n           ),
          .sdr_dqm            (sdr_dqm            ),
          .sdr_ba             (sdr_ba             ),
          .sdr_addr           (sdr_addr           ),
          .sdr_din            (pad_sdr_din2       ),
          .sdr_dout           (sdr_dout_int       ),
          .sdr_den_n          (sdr_den_n_int      ),
      /* Data Flow to the app */
          .x2a_rdstart        (x2a_rdstart        ),
          .x2a_wrstart        (x2a_wrstart        ),
          .x2a_id             (xfr_id             ),
          .x2a_rdlast         (x2a_rdlast         ),
          .x2a_wrlast         (x2a_wrlast         ),
          .a2x_wrdt           (a2x_wrdt           ),
          .a2x_wren_n         (a2x_wren_n         ),
          .x2a_wrnext         (x2a_wrnext         ),
          .x2a_rddt           (x2a_rddt           ),
          .x2a_rdok           (x2a_rdok           ),
          .sdr_init_done      (sdr_init_done      ),
			    
      /* SDRAM Parameters */
          .sdram_enable       (cfg_sdr_en         ),
          .sdram_mode_reg     (cfg_sdr_mode_reg   ),
		    
      /* current xfr bank */
          .xfr_bank_sel       (xfr_bank_sel       ),

      /* SDRAM Timing */
          .cas_latency        (cfg_sdr_cas        ),
          .trp_delay          (cfg_sdr_trp_d      ),
          .trcar_delay        (cfg_sdr_trcar_d    ),
          .twr_delay          (cfg_sdr_twr_d      ),
          .rfsh_time          (cfg_sdr_rfsh       ),
          .rfsh_rmax          (cfg_sdr_rfmax      )
    );
   

sdrc_bs_convert_ref #(.SDR_DW(SDR_DW) ,  .SDR_BW(SDR_BW)) u_bs_convert (
          .clk                (clk          ),
          .reset_n            (reset_n            ),
          .sdr_width          (sdr_width          ),

   /* Control Signal from xfr ctrl */
          .x2a_rdstart        (x2a_rdstart        ),
          .x2a_rdlast         (x2a_rdlast         ),
          .x2a_rdok           (x2a_rdok           ),
          .x2a_rddt           (x2a_rddt           ),

          .x2a_wrstart        (x2a_wrstart        ),
          .x2a_wrlast         (x2a_wrlast         ),
          .x2a_wrnext         (x2a_wrnext         ),

          .a2x_wrdt           (a2x_wrdt           ),
          .a2x_wren_n         (a2x_wren_n         ),

   /*  Control Signal from/to to application i/f  */
          .app_wr_data        (app_wr_data        ),
          .app_wr_en_n        (app_wr_en_n        ),
          .app_wr_next        (app_wr_next_req    ),
	  .app_last_wr        (app_last_wr        ),
          .app_rd_data        (app_rd_data        ),
          .app_rd_valid       (app_rd_valid       ),
	  .app_last_rd        (app_last_rd        )
       );   
   
endmodule // sdrc_core

module sdrc_req_gen_ref (clk,
		    reset_n,
		    cfg_colbits,
		    sdr_width,

		    /* Request from app */
		    req,	        // Transfer Request
		    req_id,	        // ID for this transfer
		    req_addr,	        // SDRAM Address
		    req_len,	        // Burst Length (in 32 bit words)
		    req_wrap,	        // Wrap mode request (xfr_len = 4)
		    req_wr_n,	        // 0 => Write request, 1 => read req
		    req_ack,	        // Request has been accepted
		    
		    /* Req to xfr_ctl */
		    r2x_idle,

		    /* Req to bank_ctl */
		    r2b_req,	        // request
		    r2b_req_id,	        // ID
		    r2b_start,	        // First chunk of burst
		    r2b_last,	        // Last chunk of burst
		    r2b_wrap,	        // Wrap Mode
		    r2b_ba,	        // bank address
		    r2b_raddr,	        // row address
		    r2b_caddr,	        // col address
		    r2b_len,	        // length
		    r2b_write,	        // write request
		    b2r_ack,
		    b2r_arb_ok
		    );

parameter  APP_AW   = 26;  // Application Address Width
parameter  APP_DW   = 32;  // Application Data Width 
parameter  APP_BW   = 4;   // Application Byte Width
parameter  APP_RW   = 9;   // Application Request Width

parameter  SDR_DW   = 16;  // SDR Data Width 
parameter  SDR_BW   = 2;   // SDR Byte Width


input                   clk           ;
input                   reset_n       ;
input [1:0]             cfg_colbits   ; // 2'b00 - 8 Bit column address, 2'b01 - 9 Bit, 10 - 10 bit, 11 - 11Bits

/* Request from app */
input 			req           ; // Request 
input [`SDR_REQ_ID_W-1:0] req_id      ; // Request ID
input [APP_AW-1:0] 	req_addr      ; // Request Address
input [APP_RW-1:0] 	req_len       ; // Request length
input 			req_wr_n      ; // 0 -Write, 1 - Read
input                   req_wrap      ; // 1 - Wrap the Address on page boundary
output 			req_ack       ; // Request Ack
		
/* Req to bank_ctl */
output 			r2x_idle      ; 
output                  r2b_req       ; // Request
output                  r2b_start     ; // First Junk of the Burst Access
output                  r2b_last      ; // Last Junk of the Burst Access
output                  r2b_write     ; // 1 - Write, 0 - Read
output                  r2b_wrap      ; // 1 - Wrap the Address at the page boundary.
output [`SDR_REQ_ID_W-1:0] 	r2b_req_id;
output [1:0] 		r2b_ba        ; // Bank Address
output [12:0] 		r2b_raddr     ; // Row Address
output [12:0] 		r2b_caddr     ; // Column Address
output [`REQ_BW-1:0] 	r2b_len       ; // Burst Length
input 			b2r_ack       ; // Request Ack
input                   b2r_arb_ok    ; // Bank controller fifo is not full and ready to accept the command
//
input [1:0] 	        sdr_width; // 2'b00 - 32 Bit, 2'b01 - 16 Bit, 2'b1x - 8Bit
                                         

   /****************************************************************************/
   // Internal Nets

   `define REQ_IDLE        2'b00
   `define REQ_ACTIVE      2'b01
   `define REQ_PAGE_WRAP   2'b10

   reg  [1:0]		req_st, next_req_st;
   reg 			r2x_idle, req_ack, r2b_req, r2b_start, 
			r2b_write, req_idle, req_ld, lcl_wrap;
   reg [`SDR_REQ_ID_W-1:0] 	r2b_req_id;
   reg [`REQ_BW-1:0] 	lcl_req_len;

   wire 		r2b_last, page_ovflw;
   reg page_ovflw_r;
   wire [`REQ_BW-1:0] 	r2b_len, next_req_len;
   wire [12:0] 	        max_r2b_len;
   reg  [12:0] 	        max_r2b_len_r;

   reg [1:0] 		r2b_ba;
   reg [12:0] 		r2b_raddr;
   reg [12:0] 		r2b_caddr;

   reg [APP_AW-1:0] 	curr_sdr_addr ;
   wire [APP_AW-1:0] 	next_sdr_addr ;


//--------------------------------------------------------------------
// Generate the internal Adress and Burst length Based on sdram width
//--------------------------------------------------------------------
reg [APP_AW:0]           req_addr_int;
reg [APP_RW-1:0]         req_len_int;

always @(*) begin
   if(sdr_width == 2'b00) begin // 32 Bit SDR Mode
      req_addr_int     = {1'b0,req_addr};
      req_len_int      = req_len;
   end else if(sdr_width == 2'b01) begin // 16 Bit SDR Mode
      // Changed the address and length to match the 16 bit SDR Mode
      req_addr_int     = {req_addr,1'b0};
      req_len_int      = {req_len,1'b0};
   end else  begin // 8 Bit SDR Mode
      // Changed the address and length to match the 16 bit SDR Mode
      req_addr_int    = {req_addr,2'b0};
      req_len_int     = {req_len,2'b0};
   end
end

   //
   // Identify the page over flow.
   // Find the Maximum Burst length allowed from the selected column
   // address, If the requested burst length is more than the allowed Maximum
   // burst length, then we need to handle the bank cross over case and we
   // need to split the reuest.
   //
   assign max_r2b_len = (cfg_colbits == 2'b00) ? (12'h100 - {4'b0, req_addr_int[7:0]}) :
	                (cfg_colbits == 2'b01) ? (12'h200 - {3'b0, req_addr_int[8:0]}) :
			(cfg_colbits == 2'b10) ? (12'h400 - {2'b0, req_addr_int[9:0]}) : (12'h800 - {1'b0, req_addr_int[10:0]});


     // If the wrap = 0 and current application burst length is crossing the page boundary, 
     // then request will be split into two with corresponding change in request address and request length.
     //
     // If the wrap = 0 and current burst length is not crossing the page boundary, 
     // then request from application layer will be transparently passed on the bank control block.

     //
     // if the wrap = 1, then this block will not modify the request address and length. 
     // The wrapping functionality will be handle by the bank control module and 
     // column address will rewind back as follows XX -> FF ? 00 ? 1
     //
     // Note: With Wrap = 0, each request from Application layer will be spilited into two request, 
     //	if the current burst cross the page boundary. 
   assign page_ovflw = ({1'b0, req_len_int} > max_r2b_len) ? ~r2b_wrap : 1'b0;

   assign r2b_len = r2b_start ? ((page_ovflw_r) ? max_r2b_len_r : lcl_req_len) :
                      lcl_req_len;

   assign next_req_len = lcl_req_len - r2b_len;

   assign next_sdr_addr = curr_sdr_addr + r2b_len;


   assign r2b_wrap = lcl_wrap;

   assign r2b_last = (r2b_start & !page_ovflw_r) | (req_st == `REQ_PAGE_WRAP);
//
//
//
   always @ (posedge clk) begin

      page_ovflw_r   <= (req_ack) ? page_ovflw: 'h0;

      max_r2b_len_r  <= (req_ack) ? max_r2b_len: 'h0;
      r2b_start      <= (req_ack) ? 1'b1 :
		        (b2r_ack) ? 1'b0 : r2b_start;

      r2b_write      <= (req_ack) ? ~req_wr_n : r2b_write;

      r2b_req_id     <= (req_ack) ? req_id : r2b_req_id;

      lcl_wrap       <= (req_ack) ? req_wrap : lcl_wrap;
	     
      lcl_req_len    <= (req_ack) ? req_len_int  :
		        (req_ld) ? next_req_len : lcl_req_len;

      curr_sdr_addr  <= (req_ack) ? req_addr_int :
		        (req_ld) ? next_sdr_addr : curr_sdr_addr;

   end // always @ (posedge clk)
   
   always @ (*) begin
      r2x_idle    = 1'b0;
      req_idle    = 1'b0;
      req_ack     = 1'b0;
      req_ld      = 1'b0;
      r2b_req     = 1'b0;
      next_req_st = `REQ_IDLE;

      case (req_st)      // synopsys full_case parallel_case

	`REQ_IDLE : begin
	   r2x_idle = ~req;
	   req_idle = 1'b1;
	   req_ack = req & b2r_arb_ok;
	   req_ld = 1'b0;
	   r2b_req = 1'b0;
	   next_req_st = (req & b2r_arb_ok) ? `REQ_ACTIVE : `REQ_IDLE;
	end // case: `REQ_IDLE

	`REQ_ACTIVE : begin
	   r2x_idle = 1'b0;
	   req_idle = 1'b0;
	   req_ack = 1'b0;
	   req_ld = b2r_ack;
	   r2b_req = 1'b1;                       // req_gen to bank_req
	   next_req_st = (b2r_ack ) ? ((page_ovflw_r) ? `REQ_PAGE_WRAP :`REQ_IDLE) : `REQ_ACTIVE;
	end // case: `REQ_ACTIVE
	`REQ_PAGE_WRAP : begin
	   r2x_idle = 1'b0;
	   req_idle = 1'b0;
	   req_ack  = 1'b0;
	   req_ld = b2r_ack;
	   r2b_req = 1'b1;                       // req_gen to bank_req
	   next_req_st = (b2r_ack) ? `REQ_IDLE : `REQ_PAGE_WRAP;
	end // case: `REQ_ACTIVE

      endcase // case(req_st)

   end // always @ (req_st or ....)

   always @ (posedge clk)
      if (~reset_n) begin
	 req_st <= `REQ_IDLE;
      end // if (~reset_n)
      else begin
	 req_st <= next_req_st;
      end // else: !if(~reset_n)
//
// addrs bits for the bank, row and column
//
// Register row/column/bank to improve fpga timing issue
wire [APP_AW-1:0] 	map_address ;

assign      map_address  = (req_ack) ? req_addr_int :
		           (req_ld)  ? next_sdr_addr : curr_sdr_addr;

always @ (posedge clk) begin
// Bank Bits are always - 2 Bits
    r2b_ba <= (cfg_colbits == 2'b00) ? {map_address[9:8]}   :
	      (cfg_colbits == 2'b01) ? {map_address[10:9]}  :
	      (cfg_colbits == 2'b10) ? {map_address[11:10]} : map_address[12:11];

/********************
*  Colbits Mapping:
*           2'b00 - 8 Bit
*           2'b01 - 16 Bit
*           2'b10 - 10 Bit
*           2'b11 - 11 Bits
************************/
    r2b_caddr <= (cfg_colbits == 2'b00) ? {5'b0, map_address[7:0]} :
	         (cfg_colbits == 2'b01) ? {4'b0, map_address[8:0]} :
	         (cfg_colbits == 2'b10) ? {3'b0, map_address[9:0]} : {2'b0, map_address[10:0]};

    r2b_raddr <= (cfg_colbits == 2'b00)  ? map_address[22:10] :
	         (cfg_colbits == 2'b01)  ? map_address[23:11] :
	         (cfg_colbits == 2'b10)  ? map_address[24:12] : map_address[25:13];
end	   
   
endmodule // sdr_req_gen

module sdrc_xfr_ctl_ref (clk,
		    reset_n,
		    
		    /* Transfer request from bank_ctl */
		    r2x_idle,	   // Req is idle
		    b2x_idle,      // All banks are idle
		    b2x_req,	   // Req from bank_ctl
		    b2x_start,	   // first chunk of transfer
		    b2x_last,	   // last chunk of transfer
		    b2x_id,	   // Transfer ID
		    b2x_ba,	   // bank address
		    b2x_addr,	   // row/col address
		    b2x_len,	   // transfer length
		    b2x_cmd,	   // transfer command
		    b2x_wrap,	   // Wrap mode transfer
		    x2b_ack,	   // command accepted
		     
		    /* Status to bank_ctl, req_gen */
		    b2x_tras_ok,   // Tras for all banks expired
		    x2b_refresh,   // We did a refresh
		    x2b_pre_ok,	   // OK to do a precharge (per bank)
		    x2b_act_ok,	   // OK to do an activate
		    x2b_rdok,	   // OK to do a read
		    x2b_wrok,	   // OK to do a write
		    
		    /* SDRAM I/O */
		    sdr_cs_n,
		    sdr_cke,
		    sdr_ras_n,
		    sdr_cas_n,
		    sdr_we_n,
		    sdr_dqm,
		    sdr_ba,
		    sdr_addr, 
		    sdr_din,
		    sdr_dout,
		    sdr_den_n,
		    
		    /* Data Flow to the app */
		    x2a_rdstart,
		    x2a_wrstart,
		    x2a_rdlast,
		    x2a_wrlast,
		    x2a_id,
		    a2x_wrdt,
		    a2x_wren_n,
		    x2a_wrnext,
		    x2a_rddt,
		    x2a_rdok,
		    sdr_init_done,
		    
		    /* SDRAM Parameters */
		    sdram_enable,
		    sdram_mode_reg,
		    
		    /* output for generate row address of the transfer */
		    xfr_bank_sel,

		    /* SDRAM Timing */
		    cas_latency,
		    trp_delay,	   // Precharge to refresh delay
		    trcar_delay,   // Auto-refresh period
		    twr_delay,	   // Write recovery delay
		    rfsh_time,	   // time per row (31.25 or 15.6125 uS)
		    rfsh_rmax);	   // Number of rows to rfsh at a time (<120uS)
   
parameter  SDR_DW   = 16;  // SDR Data Width 
parameter  SDR_BW   = 2;   // SDR Byte Width


input            clk, reset_n; 

   /* Req from bank_ctl */
input 			b2x_req, b2x_start, b2x_last, b2x_tras_ok,
				b2x_wrap, r2x_idle, b2x_idle; 
input [`SDR_REQ_ID_W-1:0] 	b2x_id;
input [1:0] 			b2x_ba;
input [12:0] 		b2x_addr;
input [`REQ_BW-1:0] 	b2x_len;
input [1:0] 			b2x_cmd;
output 			x2b_ack;

/* Status to bank_ctl */
output [3:0] 		x2b_pre_ok;
output 			x2b_refresh, x2b_act_ok, x2b_rdok,
				x2b_wrok;
/* Data Flow to the app */
output 			x2a_rdstart, x2a_wrstart, x2a_rdlast, x2a_wrlast;
output [`SDR_REQ_ID_W-1:0] 	x2a_id;

input [SDR_DW-1:0] 	a2x_wrdt;
input [SDR_BW-1:0] 	a2x_wren_n;
output [SDR_DW-1:0] 	x2a_rddt;
output 			x2a_wrnext, x2a_rdok, sdr_init_done;
		
/* Interface to SDRAMs */
output 			sdr_cs_n, sdr_cke, sdr_ras_n, sdr_cas_n,
				sdr_we_n; 
output [SDR_BW-1:0] 	sdr_dqm;
output [1:0] 		sdr_ba;
output [12:0] 		sdr_addr;
input [SDR_DW-1:0] 	sdr_din;
output [SDR_DW-1:0] 	sdr_dout;
output [SDR_BW-1:0] 	sdr_den_n;

   output [1:0]			xfr_bank_sel;

   input 			sdram_enable;
   input [12:0] 		sdram_mode_reg;
   input [2:0] 			cas_latency;
   input [3:0] 			trp_delay, trcar_delay, twr_delay;
   input [`SDR_RFSH_TIMER_W-1 : 0] rfsh_time;
   input [`SDR_RFSH_ROW_CNT_W-1:0] rfsh_rmax;
   

   /************************************************************************/
   // Internal Nets

   `define XFR_IDLE        2'b00
   `define XFR_WRITE       2'b01
   `define XFR_READ        2'b10
   `define XFR_RDWT        2'b11

   reg [1:0] 			xfr_st, next_xfr_st;
   reg [12:0] 			xfr_caddr;
   wire 			last_burst;
   wire 			x2a_rdstart, x2a_wrstart, x2a_rdlast, x2a_wrlast;
   reg 				l_start, l_last, l_wrap;
   wire [`SDR_REQ_ID_W-1:0] 	x2a_id;
   reg [`SDR_REQ_ID_W-1:0] 	l_id;
   wire [1:0] 			xfr_ba;
   reg [1:0] 			l_ba;
   wire [12:0] 			xfr_addr;
   wire [`REQ_BW-1:0] 	xfr_len, next_xfr_len;
   reg [`REQ_BW-1:0] 	l_len;

   reg 				mgmt_idle, mgmt_req;
   reg [3:0] 			mgmt_cmd;
   reg [12:0] 			mgmt_addr;
   reg [1:0] 			mgmt_ba;

   reg 				sel_mgmt, sel_b2x;
   reg 				cb_pre_ok, rdok, wrok, wr_next,
				rd_next, sdr_init_done, act_cmd, d_act_cmd;
   wire [3:0] 			b2x_sdr_cmd, xfr_cmd;
   reg [3:0] 			i_xfr_cmd;
   wire 			mgmt_ack, x2b_ack, b2x_read, b2x_write, 
				b2x_prechg, d_rd_next, dt_next, xfr_end,
				rd_pipe_mt, ld_xfr, rd_last, d_rd_last, 
				wr_last, l_xfr_end, rd_start, d_rd_start,
				wr_start, page_hit, burst_bdry, xfr_wrap,
				b2x_prechg_hit;
   reg [6:0] 			l_rd_next, l_rd_start, l_rd_last;
   
   assign b2x_read = (b2x_cmd == `OP_RD) ? 1'b1 : 1'b0;

   assign b2x_write = (b2x_cmd == `OP_WR) ? 1'b1 : 1'b0;

   assign b2x_prechg = (b2x_cmd == `OP_PRE) ? 1'b1 : 1'b0;
   
   assign b2x_sdr_cmd = (b2x_cmd == `OP_PRE) ? `SDR_PRECHARGE :
			(b2x_cmd == `OP_ACT) ? `SDR_ACTIVATE :
			(b2x_cmd == `OP_RD) ? `SDR_READ :
			(b2x_cmd == `OP_WR) ? `SDR_WRITE : `SDR_DESEL;

   assign page_hit = (b2x_ba == l_ba) ? 1'b1 : 1'b0;

   assign b2x_prechg_hit = b2x_prechg & page_hit;
   
   assign xfr_cmd = (sel_mgmt) ? mgmt_cmd :
		    (sel_b2x) ? b2x_sdr_cmd : i_xfr_cmd;

   assign xfr_addr = (sel_mgmt) ? mgmt_addr : 
		     (sel_b2x) ? b2x_addr : xfr_caddr+1;

   assign mgmt_ack = sel_mgmt;

   assign x2b_ack = sel_b2x;

   assign ld_xfr = sel_b2x & (b2x_read | b2x_write);
   
   assign xfr_len = (ld_xfr) ? b2x_len : l_len;

   //assign next_xfr_len = (l_xfr_end && !ld_xfr) ? l_len : xfr_len - 1;
   assign next_xfr_len = (ld_xfr) ? b2x_len : 
	                 (l_xfr_end) ? l_len:  l_len - 1;

   assign d_rd_next = (cas_latency == 3'b001) ? l_rd_next[2] :
		      (cas_latency == 3'b010) ? l_rd_next[3] :
		      (cas_latency == 3'b011) ? l_rd_next[4] :
		      (cas_latency == 3'b100) ? l_rd_next[5] :
		      l_rd_next[6];

   assign d_rd_last = (cas_latency == 3'b001) ? l_rd_last[2] :
		      (cas_latency == 3'b010) ? l_rd_last[3] :
		      (cas_latency == 3'b011) ? l_rd_last[4] :
		      (cas_latency == 3'b100) ? l_rd_last[5] :
		      l_rd_last[6];

   assign d_rd_start = (cas_latency == 3'b001) ? l_rd_start[2] :
		       (cas_latency == 3'b010) ? l_rd_start[3] :
		       (cas_latency == 3'b011) ? l_rd_start[4] :
		       (cas_latency == 3'b100) ? l_rd_start[5] :
		       l_rd_start[6];

   assign rd_pipe_mt = (cas_latency == 3'b001) ? ~|l_rd_next[1:0] :
		       (cas_latency == 3'b010) ? ~|l_rd_next[2:0] :
		       (cas_latency == 3'b011) ? ~|l_rd_next[3:0] :
		       (cas_latency == 3'b100) ? ~|l_rd_next[4:0] :
		       ~|l_rd_next[5:0];

   assign dt_next = wr_next | d_rd_next;

   assign xfr_end = ~|xfr_len;

   assign l_xfr_end = ~|(l_len-1);

   assign rd_start = ld_xfr & b2x_read & b2x_start;

   assign wr_start = ld_xfr & b2x_write & b2x_start;
   
   assign rd_last = rd_next & last_burst & ~|xfr_len[`REQ_BW-1:1];

   //assign wr_last = wr_next & last_burst & ~|xfr_len[APP_RW-1:1];

   assign wr_last = last_burst & ~|xfr_len[`REQ_BW-1:1];
   
   //assign xfr_ba = (ld_xfr) ? b2x_ba : l_ba;
   assign xfr_ba = (sel_mgmt) ? mgmt_ba : 
		   (sel_b2x) ? b2x_ba : l_ba;

   assign xfr_wrap = (ld_xfr) ? b2x_wrap : l_wrap;
   
//   assign burst_bdry = ~|xfr_caddr[2:0];
   wire [1:0] xfr_caddr_lsb = (xfr_caddr[1:0]+1);
   assign burst_bdry = ~|(xfr_caddr_lsb[1:0]);
  
   always @ (posedge clk) begin
      if (~reset_n) begin
	 xfr_caddr <= 13'b0;
	 l_start <= 1'b0;
	 l_last <= 1'b0;
	 l_wrap <= 1'b0;
	 l_id <= 0;
	 l_ba <= 0;
	 l_len <= 0;
	 l_rd_next <= 7'b0;
	 l_rd_start <= 7'b0;
	 l_rd_last <= 7'b0;
	 act_cmd <= 1'b0;
	 d_act_cmd <= 1'b0;
	 xfr_st <= `XFR_IDLE;
      end // if (~reset_n)

      else begin
	 xfr_caddr <= (ld_xfr) ? b2x_addr :
		      (rd_next | wr_next) ? xfr_caddr + 1 : xfr_caddr; 
	 l_start <= (dt_next) ? 1'b0 : 
		   (ld_xfr) ? b2x_start : l_start;
	 l_last <= (ld_xfr) ? b2x_last : l_last;
	 l_wrap <= (ld_xfr) ? b2x_wrap : l_wrap;
	 l_id <= (ld_xfr) ? b2x_id : l_id;
	 l_ba <= (ld_xfr) ? b2x_ba : l_ba;
	 l_len <= next_xfr_len;
	 l_rd_next <= {l_rd_next[5:0], rd_next};
	 l_rd_start <= {l_rd_start[5:0], rd_start};
	 l_rd_last <= {l_rd_last[5:0], rd_last};
	 act_cmd <= (xfr_cmd == `SDR_ACTIVATE) ? 1'b1 : 1'b0;
	 d_act_cmd <= act_cmd;
	 xfr_st <= next_xfr_st;
      end // else: !if(~reset_n)
      
   end // always @ (posedge clk)
   

   always @ (*) begin 
      case (xfr_st)

	`XFR_IDLE : begin

	   sel_mgmt = mgmt_req;
	   sel_b2x = ~mgmt_req & sdr_init_done & b2x_req;
	   i_xfr_cmd = `SDR_DESEL;
	   rd_next = ~mgmt_req & sdr_init_done & b2x_req & b2x_read;
	   wr_next = ~mgmt_req & sdr_init_done & b2x_req & b2x_write;
	   rdok = ~mgmt_req;
	   cb_pre_ok = 1'b1;
	   wrok = ~mgmt_req;
	   next_xfr_st = (mgmt_req | ~sdr_init_done) ? `XFR_IDLE :
			 (~b2x_req) ? `XFR_IDLE :
			 (b2x_read) ? `XFR_READ :
			 (b2x_write) ? `XFR_WRITE : `XFR_IDLE;

	end // case: `XFR_IDLE
	   
	`XFR_READ : begin
	   rd_next = ~l_xfr_end |
		     l_xfr_end & ~mgmt_req & b2x_req & b2x_read;
	   wr_next = 1'b0;
	   rdok = l_xfr_end & ~mgmt_req;
	   // Break the timing path for FPGA Based Design
	   cb_pre_ok = (`TARGET_DESIGN == `FPGA) ? 1'b0 : l_xfr_end;
	   wrok = 1'b0;
	   sel_mgmt = 1'b0;

	   if (l_xfr_end) begin		  // end of transfer

	      if (~l_wrap) begin
		 // Current transfer was not wrap mode, may need BT
		 // If next cmd is a R or W or PRE to same bank allow
		 // it else issue BT 
		 // This is a little pessimistic since BT is issued
		 // for non-wrap mode transfers even if the transfer
		 // ends on a burst boundary, but is felt to be of
		 // minimal performance impact.

		 i_xfr_cmd = `SDR_BT;
		 sel_b2x = b2x_req & ~mgmt_req & (b2x_read | b2x_prechg_hit);

	      end // if (~l_wrap)
	      
	      else begin
		 // Wrap mode transfer, by definition is end of burst
		 // boundary 

		 i_xfr_cmd = `SDR_DESEL;
		 sel_b2x = b2x_req & ~mgmt_req & ~b2x_write;

	      end // else: !if(~l_wrap)
		 
	      next_xfr_st = (sdr_init_done) ? ((b2x_req & ~mgmt_req & b2x_read) ? `XFR_READ : `XFR_RDWT) : `XFR_IDLE;

	   end // if (l_xfr_end)

	   else begin
	      // Not end of transfer
	      // If current transfer was not wrap mode and we are at
	      // the start of a burst boundary issue another R cmd to
	      // step sequemtially thru memory, ELSE,
	      // issue precharge/activate commands from the bank control

	      i_xfr_cmd = (burst_bdry & ~l_wrap) ? `SDR_READ : `SDR_DESEL;
	      sel_b2x = ~(burst_bdry & ~l_wrap) & b2x_req;
	      next_xfr_st = `XFR_READ;

	   end // else: !if(l_xfr_end)
	   
	end // case: `XFR_READ
	
	`XFR_RDWT : begin 
	   rd_next = ~mgmt_req & b2x_req & b2x_read;
	   wr_next = rd_pipe_mt & ~mgmt_req & b2x_req & b2x_write;
	   rdok = ~mgmt_req;
	   cb_pre_ok = 1'b1;
	   wrok = rd_pipe_mt & ~mgmt_req;

	   sel_mgmt = mgmt_req;
	   
	   sel_b2x = ~mgmt_req & b2x_req;

	   i_xfr_cmd = `SDR_DESEL;

	   next_xfr_st = (~mgmt_req & b2x_req & b2x_read) ? `XFR_READ : 
			 (~rd_pipe_mt) ? `XFR_RDWT :
			 (~mgmt_req & b2x_req & b2x_write) ? `XFR_WRITE : 
			 `XFR_IDLE;

	end // case: `XFR_RDWT
	
	`XFR_WRITE : begin
	   rd_next = l_xfr_end & ~mgmt_req & b2x_req & b2x_read;
	   wr_next = ~l_xfr_end |
		     l_xfr_end & ~mgmt_req & b2x_req & b2x_write;
	   rdok = l_xfr_end & ~mgmt_req;
	   cb_pre_ok = 1'b0;
	   wrok = l_xfr_end & ~mgmt_req;
	   sel_mgmt = 1'b0;

	   if (l_xfr_end) begin		  // End of transfer

	      if (~l_wrap) begin
		 // Current transfer was not wrap mode, may need BT
		 // If next cmd is a R or W allow it else issue BT 
		 // This is a little pessimistic since BT is issued
		 // for non-wrap mode transfers even if the transfer
		 // ends on a burst boundary, but is felt to be of
		 // minimal performance impact.


		 sel_b2x = b2x_req & ~mgmt_req & (b2x_read | b2x_write);
		 i_xfr_cmd = `SDR_BT;
	      end // if (~l_wrap)

	      else begin
		 // Wrap mode transfer, by definition is end of burst
		 // boundary 

		 sel_b2x = b2x_req & ~mgmt_req & ~b2x_prechg_hit;
		 i_xfr_cmd = `SDR_DESEL;
	      end // else: !if(~l_wrap)
	      
	      next_xfr_st = (~mgmt_req & b2x_req & b2x_read) ? `XFR_READ : 
			    (~mgmt_req & b2x_req & b2x_write) ? `XFR_WRITE : 
			    `XFR_IDLE;

	   end // if (l_xfr_end)

	   else begin
	      // Not end of transfer
	      // If current transfer was not wrap mode and we are at
	      // the start of a burst boundary issue another R cmd to
	      // step sequemtially thru memory, ELSE,
	      // issue precharge/activate commands from the bank control

	      if (burst_bdry & ~l_wrap) begin
		 sel_b2x = 1'b0;
		 i_xfr_cmd = `SDR_WRITE;
	      end // if (burst_bdry & ~l_wrap)
	      
	      else begin
		 sel_b2x = b2x_req & ~mgmt_req;
		 i_xfr_cmd = `SDR_DESEL;
	      end // else: !if(burst_bdry & ~l_wrap)

	      next_xfr_st = `XFR_WRITE;
	   end // else: !if(l_xfr_end)

	end // case: `XFR_WRITE

      endcase // case(xfr_st)

   end // always @ (xfr_st or ...)

   // signals to bank_ctl (x2b_refresh, x2b_act_ok, x2b_rdok, x2b_wrok,
   // x2b_pre_ok[3:0] 

   assign x2b_refresh = (xfr_cmd == `SDR_REFRESH) ? 1'b1 : 1'b0;

   assign x2b_act_ok = ~act_cmd & ~d_act_cmd;

   assign x2b_rdok = rdok;

   assign x2b_wrok = wrok;

   //assign x2b_pre_ok[0] = (l_ba == 2'b00) ? cb_pre_ok : 1'b1;
   //assign x2b_pre_ok[1] = (l_ba == 2'b01) ? cb_pre_ok : 1'b1;
   //assign x2b_pre_ok[2] = (l_ba == 2'b10) ? cb_pre_ok : 1'b1;
   //assign x2b_pre_ok[3] = (l_ba == 2'b11) ? cb_pre_ok : 1'b1;
   
   assign x2b_pre_ok[0] = cb_pre_ok;
   assign x2b_pre_ok[1] = cb_pre_ok;
   assign x2b_pre_ok[2] = cb_pre_ok;
   assign x2b_pre_ok[3] = cb_pre_ok;
   assign last_burst = (ld_xfr) ? b2x_last : l_last;
   
   /************************************************************************/
   // APP Data I/F

   wire [SDR_DW-1:0] 	x2a_rddt;

   //assign x2a_start = (ld_xfr) ? b2x_start : l_start;
   assign x2a_rdstart = d_rd_start;
   assign x2a_wrstart = wr_start;
   
   assign x2a_rdlast = d_rd_last;
   assign x2a_wrlast = wr_last;

   assign x2a_id = (ld_xfr) ? b2x_id : l_id;

   assign x2a_rddt = sdr_din;

   assign x2a_wrnext = wr_next;

   assign x2a_rdok = d_rd_next;
   
   /************************************************************************/
   // SDRAM I/F

   reg 				sdr_cs_n, sdr_cke, sdr_ras_n, sdr_cas_n,
				sdr_we_n; 
   reg [SDR_BW-1:0] 	sdr_dqm;
   reg [1:0] 			sdr_ba;
   reg [12:0] 			sdr_addr;
   reg [SDR_DW-1:0] 	sdr_dout;
   reg [SDR_BW-1:0] 	sdr_den_n;

   always @ (posedge clk)
      if (~reset_n) begin
	 sdr_cs_n <= 1'b1;
	 sdr_cke <= 1'b1;
	 sdr_ras_n <= 1'b1;
	 sdr_cas_n <= 1'b1;
	 sdr_we_n <= 1'b1;
	 sdr_dqm   <= {SDR_BW{1'b1}};
	 sdr_den_n <= {SDR_BW{1'b1}};
      end // if (~reset_n)
      else begin
	 sdr_cs_n <= xfr_cmd[3];
	 sdr_ras_n <= xfr_cmd[2];
	 sdr_cas_n <= xfr_cmd[1];
	 sdr_we_n <= xfr_cmd[0];
	 sdr_cke <= (xfr_st != `XFR_IDLE) ? 1'b1 : 
		    ~(mgmt_idle & b2x_idle & r2x_idle);
	 sdr_dqm <= (wr_next) ? a2x_wren_n : {SDR_BW{1'b0}};
         sdr_den_n <= (wr_next) ? {SDR_BW{1'b0}} : {SDR_BW{1'b1}};
      end // else: !if(~reset_n)

   always @ (posedge clk) begin 

      if (~xfr_cmd[3]) begin 
	 sdr_addr <= xfr_addr;
	 sdr_ba <= xfr_ba;
      end // if (~xfr_cmd[3])
      
      sdr_dout <= (wr_next) ? a2x_wrdt : sdr_dout;

   end // always @ (posedge clk)
   
   /************************************************************************/
   // Refresh and Initialization

   `define MGM_POWERUP         3'b000
   `define MGM_PRECHARGE    3'b001
   `define MGM_PCHWT        3'b010
   `define MGM_REFRESH      3'b011
   `define MGM_REFWT        3'b100
   `define MGM_MODE_REG     3'b101
   `define MGM_MODE_WT      3'b110
   `define MGM_ACTIVE       3'b111
   
   reg [2:0]       mgmt_st, next_mgmt_st;
   reg [3:0] 	   tmr0, tmr0_d;
   reg [3:0] 	   cntr1, cntr1_d;
   wire 	   tmr0_tc, cntr1_tc, rfsh_timer_tc, ref_req, precharge_ok;
   reg 		   ld_tmr0, ld_cntr1, dec_cntr1, set_sdr_init_done;
   reg [`SDR_RFSH_TIMER_W-1 : 0]  rfsh_timer;
   reg [`SDR_RFSH_ROW_CNT_W-1:0]  rfsh_row_cnt;
   
   always @ (posedge clk) 
      if (~reset_n) begin
	 mgmt_st <= `MGM_POWERUP;
	 tmr0 <= 4'b0;
	 cntr1 <= 4'h7;
	 rfsh_timer <= 0;
	 rfsh_row_cnt <= 0;
	 sdr_init_done <= 1'b0;
      end // if (~reset_n)
      else begin
	 mgmt_st <= next_mgmt_st;
	 tmr0 <= (ld_tmr0) ? tmr0_d :
		  (~tmr0_tc) ? tmr0 - 1 : tmr0;
	 cntr1 <= (ld_cntr1) ? cntr1_d :
		  (dec_cntr1) ? cntr1 - 1 : cntr1;
	 sdr_init_done <= (set_sdr_init_done | sdr_init_done) & sdram_enable;
	 rfsh_timer <= (rfsh_timer_tc) ? 0 : rfsh_timer + 1;
	 rfsh_row_cnt <= (~set_sdr_init_done) ? 0 :
			 (rfsh_timer_tc) ? rfsh_row_cnt + 1 : rfsh_row_cnt;
      end // else: !if(~reset_n)

   assign tmr0_tc = ~|tmr0;

   assign cntr1_tc = ~|cntr1;

   assign rfsh_timer_tc = (rfsh_timer == rfsh_time) ? 1'b1 : 1'b0;

   assign ref_req = (rfsh_row_cnt >= rfsh_rmax) ? 1'b1 : 1'b0;

   assign precharge_ok = cb_pre_ok & b2x_tras_ok;

   assign xfr_bank_sel = l_ba;
   
   always @ (mgmt_st or sdram_enable or mgmt_ack or trp_delay or tmr0_tc or
	     cntr1_tc or trcar_delay or rfsh_row_cnt or ref_req or sdr_init_done
	     or precharge_ok or sdram_mode_reg) begin 

      case (mgmt_st)          // synopsys full_case parallel_case

	`MGM_POWERUP : begin
	   mgmt_idle = 1'b0;
	   mgmt_req = 1'b0;
	   mgmt_cmd = `SDR_DESEL;
	   mgmt_ba = 2'b0;
	   mgmt_addr = 13'h400;    // A10 = 1 => all banks
	   ld_tmr0 = 1'b0;
	   tmr0_d = 4'b0;
	   dec_cntr1 = 1'b0;
	   ld_cntr1 = 1'b1;
	   cntr1_d = 4'hf; // changed for sdrams with higher refresh cycles during initialization
	   set_sdr_init_done = 1'b0;
	   next_mgmt_st = (sdram_enable) ? `MGM_PRECHARGE : `MGM_POWERUP; 
	end // case: `MGM_POWERUP

	`MGM_PRECHARGE : begin	   // Precharge all banks
	   mgmt_idle = 1'b0;
	   mgmt_req = 1'b1;
	   mgmt_cmd = (precharge_ok) ? `SDR_PRECHARGE : `SDR_DESEL;
	   mgmt_ba = 2'b0;
	   mgmt_addr = 13'h400;	   // A10 = 1 => all banks
	   ld_tmr0 = mgmt_ack;
	   tmr0_d = trp_delay;
	   ld_cntr1 = 1'b0;
	   cntr1_d = 4'h7;
	   dec_cntr1 = 1'b0;
	   set_sdr_init_done = 1'b0;
	   next_mgmt_st = (precharge_ok & mgmt_ack) ? `MGM_PCHWT : `MGM_PRECHARGE;
	end // case: `MGM_PRECHARGE
	
	`MGM_PCHWT : begin	   // Wait for Trp
	   mgmt_idle = 1'b0;
	   mgmt_req = 1'b1;
	   mgmt_cmd = `SDR_DESEL;
	   mgmt_ba = 2'b0;
	   mgmt_addr = 13'h400;	   // A10 = 1 => all banks
	   ld_tmr0 = 1'b0;
	   tmr0_d = trp_delay;
	   ld_cntr1 = 1'b0;
	   cntr1_d = 4'b0;
	   dec_cntr1 = 1'b0;
	   set_sdr_init_done = 1'b0;
	   next_mgmt_st = (tmr0_tc) ? `MGM_REFRESH : `MGM_PCHWT;
	end // case: `MGM_PRECHARGE
	
	`MGM_REFRESH : begin	   // Refresh
	   mgmt_idle = 1'b0;
	   mgmt_req = 1'b1;
	   mgmt_cmd = `SDR_REFRESH;
	   mgmt_ba = 2'b0;
	   mgmt_addr = 13'h400;	   // A10 = 1 => all banks
	   ld_tmr0 = mgmt_ack;
	   tmr0_d = trcar_delay;
	   dec_cntr1 = mgmt_ack;
	   ld_cntr1 = 1'b0;
	   cntr1_d = 4'h7;
	   set_sdr_init_done = 1'b0;
	   next_mgmt_st = (mgmt_ack) ? `MGM_REFWT : `MGM_REFRESH;
	end // case: `MGM_REFRESH
	
	`MGM_REFWT : begin	   // Wait for trcar
	   mgmt_idle = 1'b0;
	   mgmt_req = 1'b1;
	   mgmt_cmd = `SDR_DESEL;
	   mgmt_ba = 2'b0;
	   mgmt_addr = 13'h400;	   // A10 = 1 => all banks
	   ld_tmr0 = 1'b0;
	   tmr0_d = trcar_delay;
	   dec_cntr1 = 1'b0;
	   ld_cntr1 = 1'b0;
	   cntr1_d = 4'h7;
	   set_sdr_init_done = 1'b0;
	   next_mgmt_st = (~tmr0_tc) ? `MGM_REFWT : 
			  (~cntr1_tc) ? `MGM_REFRESH :
			  (sdr_init_done) ? `MGM_ACTIVE : `MGM_MODE_REG;
	end // case: `MGM_REFWT
	
	`MGM_MODE_REG : begin	   // Program mode Register & wait for 
	   mgmt_idle = 1'b0;
	   mgmt_req = 1'b1;
	   mgmt_cmd = `SDR_MODE;
	   mgmt_ba = {1'b0, sdram_mode_reg[11]};
	   mgmt_addr = sdram_mode_reg;
	   ld_tmr0 = mgmt_ack;
	   tmr0_d = 4'h7;
	   dec_cntr1 = 1'b0;
	   ld_cntr1 = 1'b0;
	   cntr1_d = 4'h7;
	   set_sdr_init_done = 1'b0;
	   next_mgmt_st = (mgmt_ack) ? `MGM_MODE_WT : `MGM_MODE_REG;
	end // case: `MGM_MODE_REG
	
	`MGM_MODE_WT : begin	   // Wait for tMRD
	   mgmt_idle = 1'b0;
	   mgmt_req = 1'b1;
	   mgmt_cmd = `SDR_DESEL;
	   mgmt_ba = 2'bx;
	   mgmt_addr = 13'bx;
	   ld_tmr0 = 1'b0;
	   tmr0_d = 4'h7;
	   dec_cntr1 = 1'b0;
	   ld_cntr1 = 1'b0;
	   cntr1_d = 4'h7;
	   set_sdr_init_done = 1'b0;
	   next_mgmt_st = (~tmr0_tc) ? `MGM_MODE_WT : `MGM_ACTIVE;
	end // case: `MGM_MODE_WT
	
	`MGM_ACTIVE : begin	   // Wait for ref_req
	   mgmt_idle = ~ref_req;
	   mgmt_req = 1'b0;
	   mgmt_cmd = `SDR_DESEL;
	   mgmt_ba = 2'bx;
	   mgmt_addr = 13'bx;
	   ld_tmr0 = 1'b0;
	   tmr0_d = 4'h7;
	   dec_cntr1 = 1'b0;
	   ld_cntr1 = ref_req;
	   cntr1_d = rfsh_row_cnt;
	   set_sdr_init_done = 1'b1;
	   next_mgmt_st =  (~sdram_enable) ? `MGM_POWERUP :
                           (ref_req) ? `MGM_PRECHARGE : `MGM_ACTIVE;
	end // case: `MGM_MODE_WT
	
      endcase // case(mgmt_st)

   end // always @ (mgmt_st or ....)
   
	   

endmodule // sdr_xfr_ctl

module mt48lc8m8a2_ref (Dq, Addr, Ba, Clk, Cke, Cs_n, Ras_n, Cas_n, We_n, Dqm);

    parameter addr_bits =      12;
    parameter data_bits =      8;
    parameter col_bits  =       9;
    parameter mem_sizes = 2097151;                                  // 2 Meg

    inout     [data_bits - 1 : 0] Dq;
    input     [addr_bits - 1 : 0] Addr;
    input                 [1 : 0] Ba;
    input                         Clk;
    input                         Cke;
    input                         Cs_n;
    input                         Ras_n;
    input                         Cas_n;
    input                         We_n;
    input                 [0 : 0] Dqm;

    reg       [data_bits - 1 : 0] Bank0 [0 : mem_sizes];
    reg       [data_bits - 1 : 0] Bank1 [0 : mem_sizes];
    reg       [data_bits - 1 : 0] Bank2 [0 : mem_sizes];
    reg       [data_bits - 1 : 0] Bank3 [0 : mem_sizes];

    reg                   [1 : 0] Bank_addr [0 : 3];                // Bank Address Pipeline
    reg        [col_bits - 1 : 0] Col_addr [0 : 3];                 // Column Address Pipeline
    reg                   [3 : 0] Command [0 : 3];                  // Command Operation Pipeline
    reg                   [0 : 0] Dqm_reg0, Dqm_reg1;               // DQM Operation Pipeline
    reg       [addr_bits - 1 : 0] B0_row_addr, B1_row_addr, B2_row_addr, B3_row_addr;

    reg       [addr_bits - 1 : 0] Mode_reg;
    reg       [data_bits - 1 : 0] Dq_reg, Dq_dqm;
    reg        [col_bits - 1 : 0] Col_temp, Burst_counter;

    reg                           Act_b0, Act_b1, Act_b2, Act_b3;   // Bank Activate
    reg                           Pc_b0, Pc_b1, Pc_b2, Pc_b3;       // Bank Precharge

    reg                   [1 : 0] Bank_precharge     [0 : 3];       // Precharge Command
    reg                           A10_precharge      [0 : 3];       // Addr[10] = 1 (All banks)
    reg                           Auto_precharge     [0 : 3];       // RW AutoPrecharge (Bank)
    reg                           Read_precharge     [0 : 3];       // R  AutoPrecharge
    reg                           Write_precharge    [0 : 3];       //  W AutoPrecharge
    integer                       Count_precharge    [0 : 3];       // RW AutoPrecharge (Counter)
    reg                           RW_interrupt_read  [0 : 3];       // RW Interrupt Read with Auto Precharge
    reg                           RW_interrupt_write [0 : 3];       // RW Interrupt Write with Auto Precharge

    reg                           Data_in_enable;
    reg                           Data_out_enable;

    reg                   [1 : 0] Bank, Previous_bank;
    reg       [addr_bits - 1 : 0] Row;
    reg        [col_bits - 1 : 0] Col, Col_brst;

    // Internal system clock
    reg                           CkeZ, Sys_clk;

    // Commands Decode
    wire      Active_enable    = ~Cs_n & ~Ras_n &  Cas_n &  We_n;
    wire      Aref_enable      = ~Cs_n & ~Ras_n & ~Cas_n &  We_n;
    wire      Burst_term       = ~Cs_n &  Ras_n &  Cas_n & ~We_n;
    wire      Mode_reg_enable  = ~Cs_n & ~Ras_n & ~Cas_n & ~We_n;
    wire      Prech_enable     = ~Cs_n & ~Ras_n &  Cas_n & ~We_n;
    wire      Read_enable      = ~Cs_n &  Ras_n & ~Cas_n &  We_n;
    wire      Write_enable     = ~Cs_n &  Ras_n & ~Cas_n & ~We_n;

    // Burst Length Decode
    wire      Burst_length_1   = ~Mode_reg[2] & ~Mode_reg[1] & ~Mode_reg[0];
    wire      Burst_length_2   = ~Mode_reg[2] & ~Mode_reg[1] &  Mode_reg[0];
    wire      Burst_length_4   = ~Mode_reg[2] &  Mode_reg[1] & ~Mode_reg[0];
    wire      Burst_length_8   = ~Mode_reg[2] &  Mode_reg[1] &  Mode_reg[0];

    // CAS Latency Decode
    wire      Cas_latency_2    = ~Mode_reg[6] &  Mode_reg[5] & ~Mode_reg[4];
    wire      Cas_latency_3    = ~Mode_reg[6] &  Mode_reg[5] &  Mode_reg[4];

`ifdef VERBOSE
    wire      Debug            = 1'b1;                          // Debug messages : 1 = On
`else
    wire      Debug            = 1'b0;                          // Debug messages : 1 = On
`endif
    // Write Burst Mode
    wire      Write_burst_mode = Mode_reg[9];

    wire      Dq_chk           = Sys_clk & Data_in_enable;      // Check setup/hold time for DQ

    assign    Dq               = Dq_reg;                        // DQ buffer

    // Commands Operation
    `define   ACT       0
    `define   NOP       1
    `define   READ      2
    `define   READ_A    3
    `define   SDRAM_WRITE     4
    `define   WRITE_A   5
    `define   SDRAM_PRECH     6
    `define   SDRAM_A_REF     7
    `define   SDRAM_BST       8
    `define   SDRAM_LMR       9

    // Timing Parameters for -75 (PC133) and CAS Latency = 2
    parameter tAC  =   6.0;
    parameter tHZ  =   7.0;
    parameter tOH  =   2.7;
    parameter tMRD =   2.0;     // 2 Clk Cycles
    parameter tRAS =  44.0;
    parameter tRC  =  66.0;
    parameter tRCD =  20.0;
    parameter tRP  =  20.0;
    parameter tRRD =  15.0;
    parameter tWRa =   7.5;     // A2 Version - Auto precharge mode only (1 Clk + 7.5 ns)
    parameter tWRp =  15.0;     // A2 Version - Precharge mode only (15 ns)

    // Timing Check variable
    integer   MRD_chk;
    integer   WR_counter [0 : 3];
    time      WR_chk [0 : 3];
    time      RC_chk, RRD_chk;
    time      RAS_chk0, RAS_chk1, RAS_chk2, RAS_chk3;
    time      RCD_chk0, RCD_chk1, RCD_chk2, RCD_chk3;
    time      RP_chk0, RP_chk1, RP_chk2, RP_chk3;

    initial begin
      
        Dq_reg = {data_bits{1'bz}};
        {Data_in_enable, Data_out_enable} = 0;
        {Act_b0, Act_b1, Act_b2, Act_b3} = 4'b0000;
        {Pc_b0, Pc_b1, Pc_b2, Pc_b3} = 4'b0000;
        {WR_chk[0], WR_chk[1], WR_chk[2], WR_chk[3]} = 0;
        {WR_counter[0], WR_counter[1], WR_counter[2], WR_counter[3]} = 0;
        {RW_interrupt_read[0], RW_interrupt_read[1], RW_interrupt_read[2], RW_interrupt_read[3]} = 0;
        {RW_interrupt_write[0], RW_interrupt_write[1], RW_interrupt_write[2], RW_interrupt_write[3]} = 0;
        {MRD_chk, RC_chk, RRD_chk} = 0;
        {RAS_chk0, RAS_chk1, RAS_chk2, RAS_chk3} = 0;
        {RCD_chk0, RCD_chk1, RCD_chk2, RCD_chk3} = 0;
        {RP_chk0, RP_chk1, RP_chk2, RP_chk3} = 0;
        $timeformat (-9, 0, " ns", 12);
        //$readmemh("bank0.txt", Bank0);
        //$readmemh("bank1.txt", Bank1);
        //$readmemh("bank2.txt", Bank2);
        //$readmemh("bank3.txt", Bank3);
    end

    // System clock generator
    always begin
        @ (posedge Clk) begin
            Sys_clk = CkeZ;
            CkeZ = Cke;
        end
        @ (negedge Clk) begin
            Sys_clk = 1'b0;
        end
    end

    always @ (posedge Sys_clk) begin
        // Internal Commamd Pipelined
        Command[0] = Command[1];
        Command[1] = Command[2];
        Command[2] = Command[3];
        Command[3] = `NOP;

        Col_addr[0] = Col_addr[1];
        Col_addr[1] = Col_addr[2];
        Col_addr[2] = Col_addr[3];
        Col_addr[3] = {col_bits{1'b0}};

        Bank_addr[0] = Bank_addr[1];
        Bank_addr[1] = Bank_addr[2];
        Bank_addr[2] = Bank_addr[3];
        Bank_addr[3] = 2'b0;

        Bank_precharge[0] = Bank_precharge[1];
        Bank_precharge[1] = Bank_precharge[2];
        Bank_precharge[2] = Bank_precharge[3];
        Bank_precharge[3] = 2'b0;

        A10_precharge[0] = A10_precharge[1];
        A10_precharge[1] = A10_precharge[2];
        A10_precharge[2] = A10_precharge[3];
        A10_precharge[3] = 1'b0;

        // Dqm pipeline for Read
        Dqm_reg0 = Dqm_reg1;
        Dqm_reg1 = Dqm;

        // Read or Write with Auto Precharge Counter
        if (Auto_precharge[0] == 1'b1) begin
            Count_precharge[0] = Count_precharge[0] + 1;
        end
        if (Auto_precharge[1] == 1'b1) begin
            Count_precharge[1] = Count_precharge[1] + 1;
        end
        if (Auto_precharge[2] == 1'b1) begin
            Count_precharge[2] = Count_precharge[2] + 1;
        end
        if (Auto_precharge[3] == 1'b1) begin
            Count_precharge[3] = Count_precharge[3] + 1;
        end

        // tMRD Counter
        MRD_chk = MRD_chk + 1;

        // tWR Counter for Write
        WR_counter[0] = WR_counter[0] + 1;
        WR_counter[1] = WR_counter[1] + 1;
        WR_counter[2] = WR_counter[2] + 1;
        WR_counter[3] = WR_counter[3] + 1;

        // Auto Refresh
        if (Aref_enable == 1'b1) begin
            if (Debug) $display ("at time %t AREF : Auto Refresh", $time);
            // Auto Refresh to Auto Refresh
            if ($time - RC_chk < tRC) begin
	       //->tb.test_control.error_detected;
                $display ("at time %t ERROR: tRC violation during Auto Refresh", $time);
            end
            // Precharge to Auto Refresh
            if ($time - RP_chk0 < tRP || $time - RP_chk1 < tRP || $time - RP_chk2 < tRP || $time - RP_chk3 < tRP) begin
	       //->tb.test_control.error_detected;
                $display ("at time %t ERROR: tRP violation during Auto Refresh", $time);
            end
            // Precharge to Refresh
            if (Pc_b0 == 1'b0 || Pc_b1 == 1'b0 || Pc_b2 == 1'b0 || Pc_b3 == 1'b0) begin
	       //->tb.test_control.error_detected;
                $display ("at time %t ERROR: All banks must be Precharge before Auto Refresh", $time);
            end
            // Record Current tRC time
            RC_chk = $time;
        end
        
        // Load Mode Register
        if (Mode_reg_enable == 1'b1) begin
            // Decode CAS Latency, Burst Length, Burst Type, and Write Burst Mode
            if (Pc_b0 == 1'b1 && Pc_b1 == 1'b1 && Pc_b2 == 1'b1 && Pc_b3 == 1'b1) begin
                Mode_reg = Addr;
                if (Debug) begin
                    $display ("at time %t LMR  : Load Mode Register", $time);
                    // CAS Latency
                    if (Addr[6 : 4] == 3'b010)
                        $display ("                            CAS Latency      = 2");
                    else if (Addr[6 : 4] == 3'b011)
                        $display ("                            CAS Latency      = 3");
                    else
                        $display ("                            CAS Latency      = Reserved");
                    // Burst Length
                    if (Addr[2 : 0] == 3'b000)
                        $display ("                            Burst Length     = 1");
                    else if (Addr[2 : 0] == 3'b001)
                        $display ("                            Burst Length     = 2");
                    else if (Addr[2 : 0] == 3'b010)
                        $display ("                            Burst Length     = 4");
                    else if (Addr[2 : 0] == 3'b011)
                        $display ("                            Burst Length     = 8");
                    else if (Addr[3 : 0] == 4'b0111)
                        $display ("                            Burst Length     = Full");
                    else
                        $display ("                            Burst Length     = Reserved");
                    // Burst Type
                    if (Addr[3] == 1'b0)
                        $display ("                            Burst Type       = Sequential");
                    else if (Addr[3] == 1'b1)
                        $display ("                            Burst Type       = Interleaved");
                    else
                        $display ("                            Burst Type       = Reserved");
                    // Write Burst Mode
                    if (Addr[9] == 1'b0)
                        $display ("                            Write Burst Mode = Programmed Burst Length");
                    else if (Addr[9] == 1'b1)
                        $display ("                            Write Burst Mode = Single Location Access");
                    else
                        $display ("                            Write Burst Mode = Reserved");
                end
            end else begin

	       //->tb.test_control.error_detected;
                $display ("at time %t ERROR: all banks must be Precharge before Load Mode Register", $time);
            end
            // REF to LMR
            if ($time - RC_chk < tRC) begin

	       //->tb.test_control.error_detected;
                $display ("at time %t ERROR: tRC violation during Load Mode Register", $time);
            end
            // LMR to LMR
            if (MRD_chk < tMRD) begin

	       //->tb.test_control.error_detected;
                $display ("at time %t ERROR: tMRD violation during Load Mode Register", $time);
            end
            MRD_chk = 0;
        end
        
        // Active Block (Latch Bank Address and Row Address)
        if (Active_enable == 1'b1) begin
            if (Ba == 2'b00 && Pc_b0 == 1'b1) begin
                {Act_b0, Pc_b0} = 2'b10;
                B0_row_addr = Addr [addr_bits - 1 : 0];
                RCD_chk0 = $time;
                RAS_chk0 = $time;
                if (Debug) $display ("at time %t ACT  : Bank = 0 Row = %d", $time, Addr);
                // Precharge to Activate Bank 0
                if ($time - RP_chk0 < tRP) begin

		   //->tb.test_control.error_detected;
                   $display ("at time %t ERROR: tRP violation during Activate bank 0", $time);
                end
            end else if (Ba == 2'b01 && Pc_b1 == 1'b1) begin
                {Act_b1, Pc_b1} = 2'b10;
                B1_row_addr = Addr [addr_bits - 1 : 0];
                RCD_chk1 = $time;
                RAS_chk1 = $time;
                if (Debug) $display ("at time %t ACT  : Bank = 1 Row = %d", $time, Addr);
                // Precharge to Activate Bank 1
                if ($time - RP_chk1 < tRP) begin

		   //->tb.test_control.error_detected;
                    $display ("at time %t ERROR: tRP violation during Activate bank 1", $time);
                end
            end else if (Ba == 2'b10 && Pc_b2 == 1'b1) begin
                {Act_b2, Pc_b2} = 2'b10;
                B2_row_addr = Addr [addr_bits - 1 : 0];
                RCD_chk2 = $time;
                RAS_chk2 = $time;
                if (Debug) $display ("at time %t ACT  : Bank = 2 Row = %d", $time, Addr);
                // Precharge to Activate Bank 2
                if ($time - RP_chk2 < tRP) begin

		   //->tb.test_control.error_detected;
                    $display ("at time %t ERROR: tRP violation during Activate bank 2", $time);
                end
            end else if (Ba == 2'b11 && Pc_b3 == 1'b1) begin
                {Act_b3, Pc_b3} = 2'b10;
                B3_row_addr = Addr [addr_bits - 1 : 0];
                RCD_chk3 = $time;
                RAS_chk3 = $time;
                if (Debug) $display ("at time %t ACT  : Bank = 3 Row = %d", $time, Addr);
                // Precharge to Activate Bank 3
                if ($time - RP_chk3 < tRP) begin

		   //->tb.test_control.error_detected;
                    $display ("at time %t ERROR: tRP violation during Activate bank 3", $time);
                end
            end else if (Ba == 2'b00 && Pc_b0 == 1'b0) begin

	       //->tb.test_control.error_detected;
                $display ("at time %t ERROR: Bank 0 is not Precharged.", $time);
            end else if (Ba == 2'b01 && Pc_b1 == 1'b0) begin

	       //->tb.test_control.error_detected;
                $display ("at time %t ERROR: Bank 1 is not Precharged.", $time);
            end else if (Ba == 2'b10 && Pc_b2 == 1'b0) begin

	       //->tb.test_control.error_detected;
                $display ("at time %t ERROR: Bank 2 is not Precharged.", $time);
            end else if (Ba == 2'b11 && Pc_b3 == 1'b0) begin

	       //->tb.test_control.error_detected;
                $display ("at time %t ERROR: Bank 3 is not Precharged.", $time);
            end
            // Active Bank A to Active Bank B
            if ((Previous_bank != Ba) && ($time - RRD_chk < tRRD)) begin

	       //->tb.test_control.error_detected;
                $display ("at time %t ERROR: tRRD violation during Activate bank = %d", $time, Ba);
            end
            // Load Mode Register to Active
            if (MRD_chk < tMRD ) begin

	       //->tb.test_control.error_detected;
                $display ("at time %t ERROR: tMRD violation during Activate bank = %d", $time, Ba);
            end
            // Auto Refresh to Activate
            if ($time - RC_chk < tRC) begin

	       //->tb.test_control.error_detected;
                $display ("at time %t ERROR: tRC violation during Activate bank = %d", $time, Ba);
            end
            // Record variables for checking violation
            RRD_chk = $time;
            Previous_bank = Ba;
        end
        
        // Precharge Block
        if (Prech_enable == 1'b1) begin
            if (Addr[10] == 1'b1) begin
                {Pc_b0, Pc_b1, Pc_b2, Pc_b3} = 4'b1111;
                {Act_b0, Act_b1, Act_b2, Act_b3} = 4'b0000;
                RP_chk0 = $time;
                RP_chk1 = $time;
                RP_chk2 = $time;
                RP_chk3 = $time;
                if (Debug) $display ("at time %t PRE  : Bank = ALL",$time);
                // Activate to Precharge all banks
                if (($time - RAS_chk0 < tRAS) || ($time - RAS_chk1 < tRAS) ||
                    ($time - RAS_chk2 < tRAS) || ($time - RAS_chk3 < tRAS)) begin

		   //->tb.test_control.error_detected;
                    $display ("at time %t ERROR: tRAS violation during Precharge all bank", $time);
                end
                // tWR violation check for write
                if (($time - WR_chk[0] < tWRp) || ($time - WR_chk[1] < tWRp) ||
                    ($time - WR_chk[2] < tWRp) || ($time - WR_chk[3] < tWRp)) begin

		   //->tb.test_control.error_detected;
                    $display ("at time %t ERROR: tWR violation during Precharge all bank", $time);
                end
            end else if (Addr[10] == 1'b0) begin
                if (Ba == 2'b00) begin
                    {Pc_b0, Act_b0} = 2'b10;
                    RP_chk0 = $time;
                    if (Debug) $display ("at time %t PRE  : Bank = 0",$time);
                    // Activate to Precharge Bank 0
                    if ($time - RAS_chk0 < tRAS) begin

		       //->tb.test_control.error_detected;
                        $display ("at time %t ERROR: tRAS violation during Precharge bank 0", $time);
                    end
                end else if (Ba == 2'b01) begin
                    {Pc_b1, Act_b1} = 2'b10;
                    RP_chk1 = $time;
                    if (Debug) $display ("at time %t PRE  : Bank = 1",$time);
                    // Activate to Precharge Bank 1
                    if ($time - RAS_chk1 < tRAS) begin

		       //->tb.test_control.error_detected;
                        $display ("at time %t ERROR: tRAS violation during Precharge bank 1", $time);
                    end
                end else if (Ba == 2'b10) begin
                    {Pc_b2, Act_b2} = 2'b10;
                    RP_chk2 = $time;
                    if (Debug) $display ("at time %t PRE  : Bank = 2",$time);
                    // Activate to Precharge Bank 2
                    if ($time - RAS_chk2 < tRAS) begin

		       //->tb.test_control.error_detected;
                        $display ("at time %t ERROR: tRAS violation during Precharge bank 2", $time);
                    end
                end else if (Ba == 2'b11) begin
                    {Pc_b3, Act_b3} = 2'b10;
                    RP_chk3 = $time;
                    if (Debug) $display ("at time %t PRE  : Bank = 3",$time);
                    // Activate to Precharge Bank 3
                    if ($time - RAS_chk3 < tRAS) begin

		       //->tb.test_control.error_detected;
                        $display ("at time %t ERROR: tRAS violation during Precharge bank 3", $time);
                    end
                end
                // tWR violation check for write
                if ($time - WR_chk[Ba] < tWRp) begin

		   //->tb.test_control.error_detected;
                    $display ("at time %t ERROR: tWR violation during Precharge bank %d", $time, Ba);
                end
            end
            // Terminate a Write Immediately (if same bank or all banks)
            if (Data_in_enable == 1'b1 && (Bank == Ba || Addr[10] == 1'b1)) begin
                Data_in_enable = 1'b0;
            end
            // Precharge Command Pipeline for Read
            if (Cas_latency_3 == 1'b1) begin
                Command[2] = `SDRAM_PRECH;
                Bank_precharge[2] = Ba;
                A10_precharge[2] = Addr[10];
            end else if (Cas_latency_2 == 1'b1) begin
                Command[1] = `SDRAM_PRECH;
                Bank_precharge[1] = Ba;
                A10_precharge[1] = Addr[10];
            end
        end
        
        // Burst terminate
        if (Burst_term == 1'b1) begin
            // Terminate a Write Immediately
            if (Data_in_enable == 1'b1) begin
                Data_in_enable = 1'b0;
            end
            // Terminate a Read Depend on CAS Latency
            if (Cas_latency_3 == 1'b1) begin
                Command[2] = `SDRAM_BST;
            end else if (Cas_latency_2 == 1'b1) begin
                Command[1] = `SDRAM_BST;
            end
            if (Debug) $display ("at time %t BST  : Burst Terminate",$time);
        end
        
        // Read, Write, Column Latch
        if (Read_enable == 1'b1 || Write_enable == 1'b1) begin
            // Check to see if bank is open (ACT)
            if ((Ba == 2'b00 && Pc_b0 == 1'b1) || (Ba == 2'b01 && Pc_b1 == 1'b1) ||
                (Ba == 2'b10 && Pc_b2 == 1'b1) || (Ba == 2'b11 && Pc_b3 == 1'b1)) begin

	       //->tb.test_control.error_detected;
                $display("at time %t ERROR: Cannot Read or Write - Bank %d is not Activated", $time, Ba);
            end
            // Activate to Read or Write
            if ((Ba == 2'b00) && ($time - RCD_chk0 < tRCD))
	      begin
		 //->tb.test_control.error_detected;
                 $display("at time %t ERROR: tRCD violation during Read or Write to Bank 0", $time);
	      end
	   
            if ((Ba == 2'b01) && ($time - RCD_chk1 < tRCD))
	      begin
		 //->tb.test_control.error_detected;
                 $display("at time %t ERROR: tRCD violation during Read or Write to Bank 1", $time);
	      end
            if ((Ba == 2'b10) && ($time - RCD_chk2 < tRCD))
	      begin
		 //->tb.test_control.error_detected;
                 $display("at time %t ERROR: tRCD violation during Read or Write to Bank 2", $time);
	      end
            if ((Ba == 2'b11) && ($time - RCD_chk3 < tRCD))
	      begin
		 //->tb.test_control.error_detected;
                 $display("at time %t ERROR: tRCD violation during Read or Write to Bank 3", $time);
	      end
            // Read Command
            if (Read_enable == 1'b1) begin
                // CAS Latency pipeline
                if (Cas_latency_3 == 1'b1) begin
                    if (Addr[10] == 1'b1) begin
                        Command[2] = `READ_A;
                    end else begin
                        Command[2] = `READ;
                    end
                    Col_addr[2] = Addr;
                    Bank_addr[2] = Ba;
                end else if (Cas_latency_2 == 1'b1) begin
                    if (Addr[10] == 1'b1) begin
                        Command[1] = `READ_A;
                    end else begin
                        Command[1] = `READ;
                    end
                    Col_addr[1] = Addr;
                    Bank_addr[1] = Ba;
                end

                // Read interrupt Write (terminate Write immediately)
                if (Data_in_enable == 1'b1) begin
                    Data_in_enable = 1'b0;
                end

            // Write Command
            end else if (Write_enable == 1'b1) begin
                if (Addr[10] == 1'b1) begin
                    Command[0] = `WRITE_A;
                end else begin
                    Command[0] = `SDRAM_WRITE;
                end
                Col_addr[0] = Addr;
                Bank_addr[0] = Ba;

                // Write interrupt Write (terminate Write immediately)
                if (Data_in_enable == 1'b1) begin
                    Data_in_enable = 1'b0;
                end

                // Write interrupt Read (terminate Read immediately)
                if (Data_out_enable == 1'b1) begin
                    Data_out_enable = 1'b0;
                end
            end

            // Interrupting a Write with Autoprecharge
            if (Auto_precharge[Bank] == 1'b1 && Write_precharge[Bank] == 1'b1) begin
                RW_interrupt_write[Bank] = 1'b1;
                if (Debug) $display ("at time %t NOTE : Read/Write Bank %d interrupt Write Bank %d with Autoprecharge", $time, Ba, Bank);
            end

            // Interrupting a Read with Autoprecharge
            if (Auto_precharge[Bank] == 1'b1 && Read_precharge[Bank] == 1'b1) begin
                RW_interrupt_read[Bank] = 1'b1;
                if (Debug) $display ("at time %t NOTE : Read/Write Bank %d interrupt Read Bank %d with Autoprecharge", $time, Ba, Bank);
            end

            // Read or Write with Auto Precharge
            if (Addr[10] == 1'b1) begin
                Auto_precharge[Ba] = 1'b1;
                Count_precharge[Ba] = 0;
                if (Read_enable == 1'b1) begin
                    Read_precharge[Ba] = 1'b1;
                end else if (Write_enable == 1'b1) begin
                    Write_precharge[Ba] = 1'b1;
                end
            end
        end

        //  Read with Auto Precharge Calculation
        //      The device start internal precharge:
        //          1.  CAS Latency - 1 cycles before last burst
        //      and 2.  Meet minimum tRAS requirement
        //       or 3.  Interrupt by a Read or Write (with or without AutoPrecharge)
        if ((Auto_precharge[0] == 1'b1) && (Read_precharge[0] == 1'b1)) begin
            if ((($time - RAS_chk0 >= tRAS) &&                                                      // Case 2
                ((Burst_length_1 == 1'b1 && Count_precharge[0] >= 1) ||                             // Case 1
                 (Burst_length_2 == 1'b1 && Count_precharge[0] >= 2) ||
                 (Burst_length_4 == 1'b1 && Count_precharge[0] >= 4) ||
                 (Burst_length_8 == 1'b1 && Count_precharge[0] >= 8))) ||
                 (RW_interrupt_read[0] == 1'b1)) begin                                              // Case 3
                    Pc_b0 = 1'b1;
                    Act_b0 = 1'b0;
                    RP_chk0 = $time;
                    Auto_precharge[0] = 1'b0;
                    Read_precharge[0] = 1'b0;
                    RW_interrupt_read[0] = 1'b0;
                    if (Debug) $display ("at time %t NOTE : Start Internal Auto Precharge for Bank 0", $time);
            end
        end
        if ((Auto_precharge[1] == 1'b1) && (Read_precharge[1] == 1'b1)) begin
            if ((($time - RAS_chk1 >= tRAS) &&
                ((Burst_length_1 == 1'b1 && Count_precharge[1] >= 1) || 
                 (Burst_length_2 == 1'b1 && Count_precharge[1] >= 2) ||
                 (Burst_length_4 == 1'b1 && Count_precharge[1] >= 4) ||
                 (Burst_length_8 == 1'b1 && Count_precharge[1] >= 8))) ||
                 (RW_interrupt_read[1] == 1'b1)) begin
                    Pc_b1 = 1'b1;
                    Act_b1 = 1'b0;
                    RP_chk1 = $time;
                    Auto_precharge[1] = 1'b0;
                    Read_precharge[1] = 1'b0;
                    RW_interrupt_read[1] = 1'b0;
                    if (Debug) $display ("at time %t NOTE : Start Internal Auto Precharge for Bank 1", $time);
            end
        end
        if ((Auto_precharge[2] == 1'b1) && (Read_precharge[2] == 1'b1)) begin
            if ((($time - RAS_chk2 >= tRAS) &&
                ((Burst_length_1 == 1'b1 && Count_precharge[2] >= 1) || 
                 (Burst_length_2 == 1'b1 && Count_precharge[2] >= 2) ||
                 (Burst_length_4 == 1'b1 && Count_precharge[2] >= 4) ||
                 (Burst_length_8 == 1'b1 && Count_precharge[2] >= 8))) ||
                 (RW_interrupt_read[2] == 1'b1)) begin
                    Pc_b2 = 1'b1;
                    Act_b2 = 1'b0;
                    RP_chk2 = $time;
                    Auto_precharge[2] = 1'b0;
                    Read_precharge[2] = 1'b0;
                    RW_interrupt_read[2] = 1'b0;
                    if (Debug) $display ("at time %t NOTE : Start Internal Auto Precharge for Bank 2", $time);
            end
        end
        if ((Auto_precharge[3] == 1'b1) && (Read_precharge[3] == 1'b1)) begin
            if ((($time - RAS_chk3 >= tRAS) &&
                ((Burst_length_1 == 1'b1 && Count_precharge[3] >= 1) || 
                 (Burst_length_2 == 1'b1 && Count_precharge[3] >= 2) ||
                 (Burst_length_4 == 1'b1 && Count_precharge[3] >= 4) ||
                 (Burst_length_8 == 1'b1 && Count_precharge[3] >= 8))) ||
                 (RW_interrupt_read[3] == 1'b1)) begin
                    Pc_b3 = 1'b1;
                    Act_b3 = 1'b0;
                    RP_chk3 = $time;
                    Auto_precharge[3] = 1'b0;
                    Read_precharge[3] = 1'b0;
                    RW_interrupt_read[3] = 1'b0;
                    if (Debug) $display ("at time %t NOTE : Start Internal Auto Precharge for Bank 3", $time);
            end
        end

        // Internal Precharge or Bst
        if (Command[0] == `SDRAM_PRECH) begin                         // Precharge terminate a read with same bank or all banks
            if (Bank_precharge[0] == Bank || A10_precharge[0] == 1'b1) begin
                if (Data_out_enable == 1'b1) begin
                    Data_out_enable = 1'b0;
                end
            end
        end else if (Command[0] == `SDRAM_BST) begin                  // BST terminate a read to current bank
            if (Data_out_enable == 1'b1) begin
                Data_out_enable = 1'b0;
            end
        end

        if (Data_out_enable == 1'b0) begin
            Dq_reg <= #tOH {data_bits{1'bz}};
        end

        // Detect Read or Write command
        if (Command[0] == `READ || Command[0] == `READ_A) begin
            Bank = Bank_addr[0];
            Col = Col_addr[0];
            Col_brst = Col_addr[0];
            if (Bank_addr[0] == 2'b00) begin
                Row = B0_row_addr;
            end else if (Bank_addr[0] == 2'b01) begin
                Row = B1_row_addr;
            end else if (Bank_addr[0] == 2'b10) begin
                Row = B2_row_addr;
            end else if (Bank_addr[0] == 2'b11) begin
                Row = B3_row_addr;
            end
            Burst_counter = 0;
            Data_in_enable = 1'b0;
            Data_out_enable = 1'b1;
        end else if (Command[0] == `SDRAM_WRITE || Command[0] == `WRITE_A) begin
            Bank = Bank_addr[0];
            Col = Col_addr[0];
            Col_brst = Col_addr[0];
            if (Bank_addr[0] == 2'b00) begin
                Row = B0_row_addr;
            end else if (Bank_addr[0] == 2'b01) begin
                Row = B1_row_addr;
            end else if (Bank_addr[0] == 2'b10) begin
                Row = B2_row_addr;
            end else if (Bank_addr[0] == 2'b11) begin
                Row = B3_row_addr;
            end
            Burst_counter = 0;
            Data_in_enable = 1'b1;
            Data_out_enable = 1'b0;
        end

        // DQ buffer (Driver/Receiver)
        if (Data_in_enable == 1'b1) begin                                   // Writing Data to Memory
            // Array buffer
            if (Bank == 2'b00) Dq_dqm [7 : 0] = Bank0 [{Row, Col}];
            if (Bank == 2'b01) Dq_dqm [7 : 0] = Bank1 [{Row, Col}];
            if (Bank == 2'b10) Dq_dqm [7 : 0] = Bank2 [{Row, Col}];
            if (Bank == 2'b11) Dq_dqm [7 : 0] = Bank3 [{Row, Col}];
            // Dqm operation
            if (Dqm[0] == 1'b0) Dq_dqm [ 7 : 0] = Dq [ 7 : 0];
            // Write to memory
            if (Bank == 2'b00) Bank0 [{Row, Col}] = Dq_dqm [7 : 0];
            if (Bank == 2'b01) Bank1 [{Row, Col}] = Dq_dqm [7 : 0];
            if (Bank == 2'b10) Bank2 [{Row, Col}] = Dq_dqm [7 : 0];
            if (Bank == 2'b11) Bank3 [{Row, Col}] = Dq_dqm [7 : 0];
            // Output result
            if (Dqm == 1'b1) begin
                if (Debug) $display("at time %t WRITE: Bank = %d Row = %d, Col = %d, Data = Hi-Z due to DQM", $time, Bank, Row, Col);
            end else begin
                if (Debug) $display("at time %t WRITE: Bank = %d Row = %d, Col = %d, Data = %h, Dqm = %b", $time, Bank, Row, Col, Dq_dqm, Dqm);
                // Record tWR time and reset counter
                WR_chk [Bank] = $time;
                WR_counter [Bank] = 0;
            end
            // Advance burst counter subroutine
            #tHZ Burst;
        end else if (Data_out_enable == 1'b1) begin                         // Reading Data from Memory
            // Array buffer
            if (Bank == 2'b00) Dq_dqm [7 : 0] = Bank0 [{Row, Col}];
            if (Bank == 2'b01) Dq_dqm [7 : 0] = Bank1 [{Row, Col}];
            if (Bank == 2'b10) Dq_dqm [7 : 0] = Bank2 [{Row, Col}];
            if (Bank == 2'b11) Dq_dqm [7 : 0] = Bank3 [{Row, Col}];
            // Dqm operation
            if (Dqm_reg0[0] == 1'b1) Dq_dqm [ 7 : 0] = 8'bz;
            // Display result
            Dq_reg [7 : 0] = #tAC Dq_dqm [7 : 0];
            if (Dqm_reg0 == 1'b1) begin
                if (Debug) $display("at time %t READ : Bank = %d Row = %d, Col = %d, Data = Hi-Z due to DQM", $time, Bank, Row, Col);
            end else begin
                if (Debug) $display("at time %t READ : Bank = %d Row = %d, Col = %d, Data = %h, Dqm = %b", $time, Bank, Row, Col, Dq_reg, Dqm_reg0);
            end
            // Advance burst counter subroutine
            Burst;
        end
    end

    //  Write with Auto Precharge Calculation
    //      The device start internal precharge:
    //          1.  tWR Clock after last burst
    //      and 2.  Meet minimum tRAS requirement
    //       or 3.  Interrupt by a Read or Write (with or without AutoPrecharge)
    always @ (WR_counter[0]) begin
        if ((Auto_precharge[0] == 1'b1) && (Write_precharge[0] == 1'b1)) begin
            if ((($time - RAS_chk0 >= tRAS) &&                                                          // Case 2
               (((Burst_length_1 == 1'b1 || Write_burst_mode == 1'b1) && Count_precharge [0] >= 1) ||   // Case 1
                 (Burst_length_2 == 1'b1 && Count_precharge [0] >= 2) ||
                 (Burst_length_4 == 1'b1 && Count_precharge [0] >= 4) ||
                 (Burst_length_8 == 1'b1 && Count_precharge [0] >= 8))) ||
                 (RW_interrupt_write[0] == 1'b1 && WR_counter[0] >= 2)) begin                           // Case 3 (stop count when interrupt)
                    Auto_precharge[0] = 1'b0;
                    Write_precharge[0] = 1'b0;
                    RW_interrupt_write[0] = 1'b0;
                    #tWRa;                          // Wait for tWR
                    Pc_b0 = 1'b1;
                    Act_b0 = 1'b0;
                    RP_chk0 = $time;
                    if (Debug) $display ("at time %t NOTE : Start Internal Auto Precharge for Bank 0", $time);
            end
        end
    end
    always @ (WR_counter[1]) begin
        if ((Auto_precharge[1] == 1'b1) && (Write_precharge[1] == 1'b1)) begin
            if ((($time - RAS_chk1 >= tRAS) &&
               (((Burst_length_1 == 1'b1 || Write_burst_mode == 1'b1) && Count_precharge [1] >= 1) || 
                 (Burst_length_2 == 1'b1 && Count_precharge [1] >= 2) ||
                 (Burst_length_4 == 1'b1 && Count_precharge [1] >= 4) ||
                 (Burst_length_8 == 1'b1 && Count_precharge [1] >= 8))) ||
                 (RW_interrupt_write[1] == 1'b1 && WR_counter[1] >= 2)) begin
                    Auto_precharge[1] = 1'b0;
                    Write_precharge[1] = 1'b0;
                    RW_interrupt_write[1] = 1'b0;
                    #tWRa;                          // Wait for tWR
                    Pc_b1 = 1'b1;
                    Act_b1 = 1'b0;
                    RP_chk1 = $time;
                    if (Debug) $display ("at time %t NOTE : Start Internal Auto Precharge for Bank 1", $time);
            end
        end
    end
    always @ (WR_counter[2]) begin
        if ((Auto_precharge[2] == 1'b1) && (Write_precharge[2] == 1'b1)) begin
            if ((($time - RAS_chk2 >= tRAS) &&
               (((Burst_length_1 == 1'b1 || Write_burst_mode == 1'b1) && Count_precharge [2] >= 1) || 
                 (Burst_length_2 == 1'b1 && Count_precharge [2] >= 2) ||
                 (Burst_length_4 == 1'b1 && Count_precharge [2] >= 4) ||
                 (Burst_length_8 == 1'b1 && Count_precharge [2] >= 8))) ||
                 (RW_interrupt_write[2] == 1'b1 && WR_counter[2] >= 2)) begin
                    Auto_precharge[2] = 1'b0;
                    Write_precharge[2] = 1'b0;
                    RW_interrupt_write[2] = 1'b0;
                    #tWRa;                          // Wait for tWR
                    Pc_b2 = 1'b1;
                    Act_b2 = 1'b0;
                    RP_chk2 = $time;
                    if (Debug) $display ("at time %t NOTE : Start Internal Auto Precharge for Bank 2", $time);
            end
        end
    end
    always @ (WR_counter[3]) begin
        if ((Auto_precharge[3] == 1'b1) && (Write_precharge[3] == 1'b1)) begin
            if ((($time - RAS_chk3 >= tRAS) &&
               (((Burst_length_1 == 1'b1 || Write_burst_mode == 1'b1) && Count_precharge [3] >= 1) || 
                 (Burst_length_2 == 1'b1 && Count_precharge [3] >= 2) ||
                 (Burst_length_4 == 1'b1 && Count_precharge [3] >= 4) ||
                 (Burst_length_8 == 1'b1 && Count_precharge [3] >= 8))) ||
                 (RW_interrupt_write[3] == 1'b1 && WR_counter[3] >= 2)) begin
                    Auto_precharge[3] = 1'b0;
                    Write_precharge[3] = 1'b0;
                    RW_interrupt_write[3] = 1'b0;
                    #tWRa;                          // Wait for tWR
                    Pc_b3 = 1'b1;
                    Act_b3 = 1'b0;
                    RP_chk3 = $time;
                    if (Debug) $display ("at time %t NOTE : Start Internal Auto Precharge for Bank 3", $time);
            end
        end
    end

    task Burst;
        begin
            // Advance Burst Counter
            Burst_counter = Burst_counter + 1;

            // Burst Type
            if (Mode_reg[3] == 1'b0) begin                                  // Sequential Burst
                Col_temp = Col + 1;
            end else if (Mode_reg[3] == 1'b1) begin                         // Interleaved Burst
                Col_temp[2] =  Burst_counter[2] ^  Col_brst[2];
                Col_temp[1] =  Burst_counter[1] ^  Col_brst[1];
                Col_temp[0] =  Burst_counter[0] ^  Col_brst[0];
            end

            // Burst Length
            if (Burst_length_2) begin                                       // Burst Length = 2
                Col [0] = Col_temp [0];
            end else if (Burst_length_4) begin                              // Burst Length = 4
                Col [1 : 0] = Col_temp [1 : 0];
            end else if (Burst_length_8) begin                              // Burst Length = 8
                Col [2 : 0] = Col_temp [2 : 0];
            end else begin                                                  // Burst Length = FULL
                Col = Col_temp;
            end

            // Burst Read Single Write            
            if (Write_burst_mode == 1'b1) begin
                Data_in_enable = 1'b0;
            end

            // Data Counter
            if (Burst_length_1 == 1'b1) begin
                if (Burst_counter >= 1) begin
                    Data_in_enable = 1'b0;
                    Data_out_enable = 1'b0;
                end
            end else if (Burst_length_2 == 1'b1) begin
                if (Burst_counter >= 2) begin
                    Data_in_enable = 1'b0;
                    Data_out_enable = 1'b0;
                end
            end else if (Burst_length_4 == 1'b1) begin
                if (Burst_counter >= 4) begin
                    Data_in_enable = 1'b0;
                    Data_out_enable = 1'b0;
                end
            end else if (Burst_length_8 == 1'b1) begin
                if (Burst_counter >= 8) begin
                    Data_in_enable = 1'b0;
                    Data_out_enable = 1'b0;
                end
            end
        end
    endtask

    // Timing Parameters for -75 (PC133) and CAS Latency = 2
    specify
        specparam
                    tAH  =  0.8,                                        // Addr, Ba Hold Time
                    tAS  =  1.5,                                        // Addr, Ba Setup Time
                    tCH  =  2.5,                                        // Clock High-Level Width
                    tCL  =  2.5,                                        // Clock Low-Level Width
                    tCK  = 10,                                          // Clock Cycle Time
                    tDH  =  0.8,                                        // Data-in Hold Time
                    tDS  =  1.5,                                        // Data-in Setup Time
                    tCKH =  0.8,                                        // CKE Hold  Time
                    tCKS =  1.5,                                        // CKE Setup Time
                    tCMH =  0.8,                                        // CS#, RAS#, CAS#, WE#, DQM# Hold  Time
                    tCMS =  1.5;                                        // CS#, RAS#, CAS#, WE#, DQM# Setup Time
        $width    (posedge Clk,           tCH);
        $width    (negedge Clk,           tCL);
        $period   (negedge Clk,           tCK);
        $period   (posedge Clk,           tCK);
        $setuphold(posedge Clk,    Cke,   tCKS, tCKH);
        $setuphold(posedge Clk,    Cs_n,  tCMS, tCMH);
        $setuphold(posedge Clk,    Cas_n, tCMS, tCMH);
        $setuphold(posedge Clk,    Ras_n, tCMS, tCMH);
        $setuphold(posedge Clk,    We_n,  tCMS, tCMH);
        $setuphold(posedge Clk,    Addr,  tAS,  tAH);
        $setuphold(posedge Clk,    Ba,    tAS,  tAH);
        $setuphold(posedge Clk,    Dqm,   tCMS, tCMH);
        $setuphold(posedge Dq_chk, Dq,    tDS,  tDH);
    endspecify

endmodule

