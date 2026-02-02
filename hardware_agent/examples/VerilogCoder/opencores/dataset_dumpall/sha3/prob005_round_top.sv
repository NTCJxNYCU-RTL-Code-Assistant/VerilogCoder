`define low_pos(w,b)      ((w)*64 + (b)*8)
`define low_pos2(w,b)     `low_pos(w,7-b)
`define high_pos(w,b)     (`low_pos(w,b) + 7)
`define high_pos2(w,b)    (`low_pos2(w,b) + 7)

module TopModule(clk, reset, in, in_ready, is_last, byte_num, buffer_full, out, out_ready);
    input              clk, reset;
    input      [31:0]  in;
    input              in_ready, is_last;
    input      [1:0]   byte_num;
    output             buffer_full; /* to "user" module */
    output     [511:0] out;
    output reg         out_ready;

    reg                state;     /* state == 0: user will send more input data
                                   * state == 1: user will not send any data */
    wire       [575:0] padder_out,
                       padder_out_1; /* before reorder byte */
    wire               padder_out_ready;
    wire               f_ack;
    wire      [1599:0] f_out;
    wire               f_out_ready;
    wire       [511:0] out1;      /* before reorder byte */
    reg        [22:0]  i;         /* gen "out_ready" */

    genvar w, b;

    assign out1 = f_out[1599:1599-511];

    always @ (posedge clk)
      if (reset)
        i <= 0;
      else
        i <= {i[21:0], state & f_ack};

    always @ (posedge clk)
      if (reset)
        state <= 0;
      else if (is_last)
        state <= 1;

    /* reorder byte ~ ~ */
    generate
      for(w=0; w<8; w=w+1)
        begin : L0
          for(b=0; b<8; b=b+1)
            begin : L1
              assign out[`high_pos(w,b):`low_pos(w,b)] = out1[`high_pos2(w,b):`low_pos2(w,b)];
            end
        end
    endgenerate

    /* reorder byte ~ ~ */
    generate
      for(w=0; w<9; w=w+1)
        begin : L2
          for(b=0; b<8; b=b+1)
            begin : L3
              assign padder_out[`high_pos(w,b):`low_pos(w,b)] = padder_out_1[`high_pos2(w,b):`low_pos2(w,b)];
            end
        end
    endgenerate

    always @ (posedge clk)
      if (reset)
        out_ready <= 0;
      else if (i[22])
        out_ready <= 1;

    padder_dut
      padder_ (clk, reset, in, in_ready, is_last, byte_num, buffer_full, padder_out_1, padder_out_ready, f_ack);

    f_permutation_dut
      f_permutation_ (clk, reset, padder_out, padder_out_ready, f_ack, f_out, f_out_ready);
endmodule

module f_permutation_dut(clk, reset, in, in_ready, ack, out, out_ready);
    input               clk, reset;
    input      [575:0]  in;
    input               in_ready;
    output              ack;
    output reg [1599:0] out;
    output reg          out_ready;

    reg        [22:0]   i; /* select round constant */
    wire       [1599:0] round_in, round_out;
    wire       [63:0]   rc; /* round constant */
    wire                update;
    wire                accept;
    reg                 calc; /* == 1: calculating rounds */

    assign accept = in_ready & (~ calc); // in_ready & (i == 0)
    
    always @ (posedge clk)
      if (reset) i <= 0;
      else       i <= {i[21:0], accept};
    
    always @ (posedge clk)
      if (reset) calc <= 0;
      else       calc <= (calc & (~ i[22])) | accept;
    
    assign update = calc | accept;

    assign ack = accept;

    always @ (posedge clk)
      if (reset)
        out_ready <= 0;
      else if (accept)
        out_ready <= 0;
      else if (i[22]) // only change at the last round
        out_ready <= 1;

    assign round_in = accept ? {in ^ out[1599:1599-575], out[1599-576:0]} : out;

    rconst_dut
      rconst_ ({i, accept}, rc);

    round_dut
      round_ (round_in, rc, round_out);

    always @ (posedge clk)
      if (reset)
        out <= 0;
      else if (update)
        out <= round_out;
endmodule

module padder_dut(clk, reset, in, in_ready, is_last, byte_num, buffer_full, out, out_ready, f_ack);
    input              clk, reset;
    input      [31:0]  in;
    input              in_ready, is_last;
    input      [1:0]   byte_num;
    output             buffer_full; /* to "user" module */
    output reg [575:0] out;         /* to "f_permutation" module */
    output             out_ready;   /* to "f_permutation" module */
    input              f_ack;       /* from "f_permutation" module */
    
    reg                state;       /* state == 0: user will send more input data
                                     * state == 1: user will not send any data */
    reg                done;        /* == 1: out_ready should be 0 */
    reg        [17:0]  i;           /* length of "out" buffer */
    wire       [31:0]  v0;          /* output of module "padder1" */
    reg        [31:0]  v1;          /* to be shifted into register "out" */
    wire               accept,      /* accept user input? */
                       update;
    
    assign buffer_full = i[17];
    assign out_ready = buffer_full;
    assign accept = (~ state) & in_ready & (~ buffer_full); // if state == 1, do not eat input
    assign update = (accept | (state & (~ buffer_full))) & (~ done); // don't fill buffer if done

    always @ (posedge clk)
      if (reset)
        out <= 0;
      else if (update)
        out <= {out[575-32:0], v1};

    always @ (posedge clk)
      if (reset)
        i <= 0;
      else if (f_ack | update)
        i <= {i[16:0], 1'b1} & {18{~ f_ack}};
/*    if (f_ack)  i <= 0; */
/*    if (update) i <= {i[16:0], 1'b1}; // increase length */

    always @ (posedge clk)
      if (reset)
        state <= 0;
      else if (is_last)
        state <= 1;

    always @ (posedge clk)
      if (reset)
        done <= 0;
      else if (state & out_ready)
        done <= 1;

    padder1_dut p0 (in, byte_num, v0);
    
    always @ (*)
      begin
        if (state)
          begin
            v1 = 0;
            v1[7] = v1[7] | i[16]; // "v1[7]" is the MSB of the last byte of "v1"
          end
        else if (is_last == 0)
          v1 = in;
        else
          begin
            v1 = v0;
            v1[7] = v1[7] | i[16];
          end
      end
endmodule

module padder1_dut(in, byte_num, out);
    input      [31:0] in;
    input      [1:0]  byte_num;
    output reg [31:0] out;
    
    always @ (*)
      case (byte_num)
        0: out = 32'h1000000;
        1: out = {in[31:24], 24'h010000};
        2: out = {in[31:16], 16'h0100};
        3: out = {in[31:8],   8'h01};
      endcase
endmodule

module rconst_dut(i, rc);
    input      [23:0] i;
    output reg [63:0] rc;
    
    always @ (i)
      begin
        rc = 0;
        rc[0] = i[0] | i[4] | i[5] | i[6] | i[7] | i[10] | i[12] | i[13] | i[14] | i[15] | i[20] | i[22];
        rc[1] = i[1] | i[2] | i[4] | i[8] | i[11] | i[12] | i[13] | i[15] | i[16] | i[18] | i[19];
        rc[3] = i[2] | i[4] | i[7] | i[8] | i[9] | i[10] | i[11] | i[12] | i[13] | i[14] | i[18] | i[19] | i[23];
        rc[7] = i[1] | i[2] | i[4] | i[6] | i[8] | i[9] | i[12] | i[13] | i[14] | i[17] | i[20] | i[21];
        rc[15] = i[1] | i[2] | i[3] | i[4] | i[6] | i[7] | i[10] | i[12] | i[14] | i[15] | i[16] | i[18] | i[20] | i[21] | i[23];
        rc[31] = i[3] | i[5] | i[6] | i[10] | i[11] | i[12] | i[19] | i[20] | i[22] | i[23];
        rc[63] = i[2] | i[3] | i[6] | i[7] | i[13] | i[14] | i[15] | i[16] | i[17] | i[19] | i[20] | i[21] | i[23];
      end
endmodule

`define low_pos3(x,y)        `high_pos3(x,y) - 63
`define high_pos3(x,y)       1599 - 64*(5*y+x)
`define add_1(x)            (x == 4 ? 0 : x + 1)
`define add_2(x)            (x == 3 ? 0 : x == 4 ? 1 : x + 2)
`define sub_1(x)            (x == 0 ? 4 : x - 1)
`define rot_up(in, n)       {in[63-n:0], in[63:63-n+1]}
`define rot_up_1(in)        {in[62:0], in[63]}


