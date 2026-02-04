module tb;

//declare:
// 1) Inputs & Inouts driven by TB
logic clk;
logic reset;
logic [63:0] in;
logic in_ready;
logic is_last;
logic [2:0] byte_num;

// 2) Outputs & Inouts observed from DUT/REF
wire buffer_full_dut;
wire buffer_full_ref;
wire [511:0] out_dut;
wire [511:0] out_ref;
wire out_ready_dut;
wire out_ready_ref;

// 2.1) Output queues and events
logic buffer_full_ref_q[$];
logic buffer_full_ref_pop;
logic buffer_full_dut_q[$];
logic buffer_full_dut_pop;
event buffer_full_ref_event;
int errortime_buffer_full_dut_q[$];
int errortime_buffer_full_dut_pop;
logic [511:0] out_ref_q[$];
logic [511:0] out_ref_pop;
logic [511:0] out_dut_q[$];
logic [511:0] out_dut_pop;
event out_ref_event;
int errortime_out_dut_q[$];
int errortime_out_dut_pop;
logic out_ready_ref_q[$];
logic out_ready_ref_pop;
logic out_ready_dut_q[$];
logic out_ready_dut_pop;
event out_ready_ref_event;
int errortime_out_ready_dut_q[$];
int errortime_out_ready_dut_pop;

// 2.2) signal for tb
int test_errors;

// 2.3) signal for verilogcoder
typedef struct packed {
    int errors;
    int errortime;
    int clocks;
    int samples;

    int errors_buffer_full;
    int errortime_buffer_full;
    int errors_out;
    int errortime_out;
    int errors_out_ready;
    int errortime_out_ready;

} stats;

stats stats1;

//link:
// 3) Instances
TopModule top_module1 (
  .clk(clk),
  .reset(reset),
  .in(in),
  .in_ready(in_ready),
  .is_last(is_last),
  .byte_num(byte_num),
  .buffer_full(buffer_full_dut),
  .out(out_dut),
  .out_ready(out_ready_dut)
);

RefModule good1 (
  .clk(clk),
  .reset(reset),
  .in(in),
  .in_ready(in_ready),
  .is_last(is_last),
  .byte_num(byte_num),
  .buffer_full(buffer_full_ref),
  .out(out_ref),
  .out_ready(out_ready_ref)
);

task monitor_dut;
  bit out_ready_dut_d;
  out_ready_dut_d = out_ready_dut;
  forever begin
    @(posedge clk);
    if (out_ready_dut && !out_ready_dut_d) begin
      @(posedge clk);
      out_dut_q.push_back(out_dut);
      errortime_out_dut_q.push_back($time);
    end
    out_ready_dut_d = out_ready_dut;
  end
endtask

task monitor_ref;
  bit out_ready_ref_d;
  out_ready_ref_d = out_ready_ref;
  forever begin
    @(posedge clk);
    if (out_ready_ref && !out_ready_ref_d) begin
      @(posedge clk);
      out_ref_q.push_back(out_ref);
      stats1.samples++;
      -> out_ref_event;
    end
    out_ready_ref_d = out_ready_ref;
  end
endtask

// Auto-generated checker tasks (inline)
// Notes:
//  - Assumes external declarations of queues/events/vars: *_ref_q, *_dut_q, *_ref_event, *_ref_pop, *_dut_pop, errors.
//  - One checker task per data base name.


// === Auto-generated checker for out ===
task checker_out;
    realtime t1, t2, ref_time;
    t1 = $realtime;
    //$display("@%0d,waiting out_ref_event", $time);
    @(out_ref_event);
    t2 = $realtime;
    ref_time = t2 - t1;
    //$display("@%0d,wait out_ref_event done", $time);
    if (out_dut_q.size() > 0) begin
        out_ref_pop = out_ref_q.pop_front();
        out_dut_pop = out_dut_q.pop_front();
        errortime_out_dut_pop = errortime_out_dut_q.pop_front();
        if (out_ref_pop == out_dut_pop) begin
            //$display("[check out passed] @time:%0t dut=%0h, ref=%0h ",
            //         $time, out_dut_pop, out_ref_pop);
        end
        else begin
            if (stats1.errors_out == 0) begin
                stats1.errortime_out = errortime_out_dut_pop;
                if (stats1.errors == 0) stats1.errortime = errortime_out_dut_pop;
            end
            stats1.errors_out++;
            stats1.errors++;
            test_errors++;
            $display("[check out FAILED] @time:%0t dut=%0h, ref=%0h ",
                     $time, out_dut_pop, out_ref_pop);
        end
    end
    else begin
        fork
            begin
                wait (out_dut_q.size() > 0);
                out_ref_pop = out_ref_q.pop_front();
                out_dut_pop = out_dut_q.pop_front();
                errortime_out_dut_pop = errortime_out_dut_q.pop_front();
                if (out_ref_pop == out_dut_pop) begin
                    //$display("[check out passed] @time:%0t dut=%0h, ref=%0h ",
                    //         $time, out_dut_pop, out_ref_pop);
                end
                else begin
                    if (stats1.errors_out == 0) begin
                        stats1.errortime_out = errortime_out_dut_pop;
                        if (stats1.errors == 0) stats1.errortime = errortime_out_dut_pop;
                    end
                    stats1.errors_out++;
                    stats1.errors++;
                    test_errors++;
                    $display("[check out FAILED] @time:%0t dut=%0h, ref=%0h ",
                             $time, out_dut_pop, out_ref_pop);
                end
            end
            begin
                #(ref_time);
                stats1.errors++;
                test_errors++;
                $display("[check output protocol FAILED] @time:%0d dut=%0h, ref=%0h ",
                         $time, 0, 1);
                $finish;
            end
        join_any
        disable fork;
    end
endtask

task drive_rst;
  begin
    // assert reset
    reset = 1'b1;

    // initialize all DUT input ports
    in       = '0;
    in_ready = 1'b0;
    is_last  = 1'b0;
    byte_num = '0;

    #20;

    // deassert reset
    reset = 1'b0;
  end
endtask

task drive_clk;
  begin
    clk = 1'b0;
    forever begin
      #10 clk = ~clk;
    end
  end
endtask

// ===== Stimuli from: /mnt/e/Yuren/Researsh/project/opencores_downloads/downloads/sha3_h/sha3/trunk/high_throughput_core/testbench/test_f_permutation.v =====
task drive_stimuli_1;
  @(posedge clk);
  reset    <= 1'b1;
  in_ready <= 1'b0;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
  in       <= 64'd0;

  @(posedge clk);
  reset    <= 1'b0;

  @(posedge clk);
  in       <= 64'hA1B2C3D4E5000000; // 5-byte last word, MSB-aligned
  is_last  <= 1'b1;
  byte_num <= 3'd5;

  @(posedge clk);
  in_ready <= 1'b1;

  @(posedge clk);
  in_ready <= 1'b0;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
endtask

task drive_stimuli_2;
  @(posedge clk);
  reset    <= 1'b1;
  in_ready <= 1'b0;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
  in       <= 64'd0;

  @(posedge clk);
  reset    <= 1'b0;

  // Word 1 (full)
  @(posedge clk);
  in       <= 64'h1122334455667788;
  is_last  <= 1'b0;
  byte_num <= 3'd0;

  @(posedge clk);
  in_ready <= 1'b1;

  @(posedge clk);
  in_ready <= 1'b0;

  // Word 2 (full)
  @(posedge clk);
  in       <= 64'hFFEEDDCCBBAA0099;
  is_last  <= 1'b0;
  byte_num <= 3'd0;

  @(posedge clk);
  in_ready <= 1'b1;

  @(posedge clk);
  in_ready <= 1'b0;

  // Word 3 (last, 3-byte partial, MSB-aligned)
  @(posedge clk);
  in       <= 64'hCAFEB00000000000; // 3 bytes: CA FE B0 at [63:40]
  is_last  <= 1'b1;
  byte_num <= 3'd3;

  @(posedge clk);
  in_ready <= 1'b1;

  @(posedge clk);
  in_ready <= 1'b0;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
endtask

task drive_stimuli_3;
  @(posedge clk);
  reset    <= 1'b1;
  in_ready <= 1'b0;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
  in       <= 64'd0;

  @(posedge clk);
  reset    <= 1'b0;

  // Full-width word (not last)
  @(posedge clk);
  in       <= 64'h0123456789ABCDEF;
  is_last  <= 1'b0;
  byte_num <= 3'd0;

  @(posedge clk);
  in_ready <= 1'b1;

  @(posedge clk);
  in_ready <= 1'b0;

  // Extra zero-length final block (is_last=1, byte_num=0)
  @(posedge clk);
  in       <= 64'd0;
  is_last  <= 1'b1;
  byte_num <= 3'd0;

  @(posedge clk);
  in_ready <= 1'b1;

  @(posedge clk);
  in_ready <= 1'b0;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
endtask

task drive_stimuli_4;
  @(posedge clk);
  reset    <= 1'b1;
  in_ready <= 1'b0;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
  in       <= 64'd0;

  @(posedge clk);
  reset    <= 1'b0;

  // Empty message: only zero-length final block
  @(posedge clk);
  in       <= 64'd0;
  is_last  <= 1'b1;
  byte_num <= 3'd0;

  @(posedge clk);
  in_ready <= 1'b1;

  @(posedge clk);
  in_ready <= 1'b0;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
endtask

// ===== Stimuli from: /mnt/e/Yuren/Researsh/project/opencores_downloads/downloads/sha3_h/sha3/trunk/high_throughput_core/testbench/test_keccak.v =====
task automatic drive_stimuli_5;
  @(posedge clk);
  reset <= 1'b1;
  in_ready <= 1'b0;
  is_last <= 1'b0;
  byte_num <= 3'd0;
  in <= 64'd0;
  @(posedge clk);
  reset <= 1'b0;
  @(posedge clk);
  in <= 64'h6162630000000000;
  is_last <= 1'b1;
  byte_num <= 3'd3;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  is_last <= 1'b0;
  byte_num <= 3'd0;
endtask

task automatic drive_stimuli_6;
  @(posedge clk);
  reset <= 1'b1;
  in_ready <= 1'b0;
  is_last <= 1'b0;
  byte_num <= 3'd0;
  in <= 64'd0;
  @(posedge clk);
  reset <= 1'b0;
  @(posedge clk);
  in <= 64'h0123456789ABCDEF;
  is_last <= 1'b0;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  @(posedge clk);
  @(posedge clk);
  in <= 64'hDEADBEEF11000000;
  is_last <= 1'b1;
  byte_num <= 3'd5;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  is_last <= 1'b0;
  byte_num <= 3'd0;
endtask

task automatic drive_stimuli_7;
  @(posedge clk);
  reset <= 1'b1;
  in_ready <= 1'b0;
  is_last <= 1'b0;
  byte_num <= 3'd0;
  in <= 64'd0;
  @(posedge clk);
  reset <= 1'b0;
  @(posedge clk);
  in <= 64'hF0F1F2F3F4F5F6F7;
  is_last <= 1'b0;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  @(posedge clk);
  @(posedge clk);
  in <= 64'd0;
  is_last <= 1'b1;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  is_last <= 1'b0;
  byte_num <= 3'd0;
endtask

task automatic drive_stimuli_8;
  @(posedge clk);
  reset <= 1'b1;
  in_ready <= 1'b0;
  is_last <= 1'b0;
  byte_num <= 3'd0;
  in <= 64'd0;
  @(posedge clk);
  reset <= 1'b0;

  // Word 1
  @(posedge clk);
  in <= 64'h0102030405060708;
  is_last <= 1'b0;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  @(posedge clk);

  // Word 2
  @(posedge clk);
  in <= 64'h1112131415161718;
  is_last <= 1'b0;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  @(posedge clk);

  // Word 3
  @(posedge clk);
  in <= 64'h2122232425262728;
  is_last <= 1'b0;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  @(posedge clk);

  // Word 4
  @(posedge clk);
  in <= 64'h3132333435363738;
  is_last <= 1'b0;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  @(posedge clk);

  // Word 5
  @(posedge clk);
  in <= 64'h4142434445464748;
  is_last <= 1'b0;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  @(posedge clk);

  // Word 6
  @(posedge clk);
  in <= 64'h5152535455565758;
  is_last <= 1'b0;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  @(posedge clk);

  // Word 7
  @(posedge clk);
  in <= 64'h6162636465666768;
  is_last <= 1'b0;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  @(posedge clk);

  // Word 8 (final, 2-byte partial)
  @(posedge clk);
  in <= 64'hAA55000000000000;
  is_last <= 1'b1;
  byte_num <= 3'd2;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  is_last <= 1'b0;
  byte_num <= 3'd0;
endtask

task automatic drive_stimuli_9;
  @(posedge clk);
  reset <= 1'b1;
  in_ready <= 1'b0;
  is_last <= 1'b0;
  byte_num <= 3'd0;
  in <= 64'd0;
  @(posedge clk);
  reset <= 1'b0;
  @(posedge clk);
  in <= 64'd0;
  is_last <= 1'b1;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  is_last <= 1'b0;
  byte_num <= 3'd0;
endtask

// ===== Stimuli from: /mnt/e/Yuren/Researsh/project/opencores_downloads/downloads/sha3_h/sha3/trunk/high_throughput_core/testbench/test_padder1.v =====
task drive_stimuli_10;
  @(posedge clk);
  reset    <= 1'b1;
  in_ready <= 1'b0;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
  in       <= 64'd0;

  @(posedge clk);
  reset <= 1'b0;

  @(posedge clk);
  in       <= 64'hA1B2C30000000000;
  byte_num <= 3'd3;

  @(posedge clk);
  in_ready <= 1'b1;
  is_last  <= 1'b1;

  repeat (2) @(posedge clk);

  in_ready <= 1'b0;
  is_last  <= 1'b0;

  @(posedge clk);
  in       <= 64'd0;
  byte_num <= 3'd0;
endtask

task drive_stimuli_11;
  @(posedge clk);
  reset    <= 1'b1;
  in_ready <= 1'b0;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
  in       <= 64'd0;

  @(posedge clk);
  reset <= 1'b0;

  @(posedge clk);
  in       <= 64'h0123_4567_89AB_CDEF;
  byte_num <= 3'd0;

  @(posedge clk);
  in_ready <= 1'b1;

  repeat (2) @(posedge clk);

  in_ready <= 1'b0;

  @(posedge clk);
  in       <= 64'h0011_2233_4455_6677;
  byte_num <= 3'd0;

  @(posedge clk);
  in_ready <= 1'b1;

  repeat (2) @(posedge clk);

  in_ready <= 1'b0;

  @(posedge clk);
  in       <= 64'd0;
  byte_num <= 3'd0;

  @(posedge clk);
  in_ready <= 1'b1;
  is_last  <= 1'b1;

  repeat (2) @(posedge clk);

  in_ready <= 1'b0;
  is_last  <= 1'b0;

  @(posedge clk);
  in       <= 64'd0;
  byte_num <= 3'd0;
endtask

task drive_stimuli_12;
  @(posedge clk);
  reset    <= 1'b1;
  in_ready <= 1'b0;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
  in       <= 64'd0;

  @(posedge clk);
  reset <= 1'b0;

  @(posedge clk);
  in       <= 64'hFFEE_DDCC_BBAA_9988;
  byte_num <= 3'd0;

  @(posedge clk);
  in_ready <= 1'b1;

  repeat (3) @(posedge clk);

  in_ready <= 1'b0;

  @(posedge clk);
  in       <= 64'h7766_5544_3322_1100;
  byte_num <= 3'd0;

  @(posedge clk);
  in_ready <= 1'b1;

  repeat (4) @(posedge clk);

  in_ready <= 1'b0;

  @(posedge clk);
  in       <= 64'hDEAD_BEEF_5500_0000;
  byte_num <= 3'd5;

  @(posedge clk);
  in_ready <= 1'b1;
  is_last  <= 1'b1;

  repeat (4) @(posedge clk);

  in_ready <= 1'b0;
  is_last  <= 1'b0;

  @(posedge clk);
  in       <= 64'd0;
  byte_num <= 3'd0;
endtask

// ===== Stimuli from: /mnt/e/Yuren/Researsh/project/opencores_downloads/downloads/sha3_h/sha3/trunk/high_throughput_core/testbench/test_padder.v =====
task drive_stimuli_13;
  @(posedge clk);
  reset <= 1'b1;
  in_ready <= 1'b0;
  is_last <= 1'b0;
  byte_num <= 3'd0;
  in <= 64'd0;
  @(posedge clk);
  reset <= 1'b0;
  @(posedge clk);
  in <= 64'h1122334455000000;
  byte_num <= 3'd5;
  @(posedge clk);
  in_ready <= 1'b1;
  is_last <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  is_last <= 1'b0;
  byte_num <= 3'd0;
endtask

task drive_stimuli_14;
  @(posedge clk);
  reset <= 1'b1;
  in_ready <= 1'b0;
  is_last <= 1'b0;
  byte_num <= 3'd0;
  in <= 64'd0;
  @(posedge clk);
  reset <= 1'b0;
  @(posedge clk);
  in <= 64'h0123456789ABCDEF;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  is_last <= 1'b0;
  @(posedge clk);
  in_ready <= 1'b0;
  @(posedge clk);
  in <= 64'h0F1E2D3C4B5A6978;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  is_last <= 1'b0;
  @(posedge clk);
  in_ready <= 1'b0;
  @(posedge clk);
  in <= 64'd0;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  is_last <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  is_last <= 1'b0;
  byte_num <= 3'd0;
endtask

task drive_stimuli_15;
  @(posedge clk);
  reset <= 1'b1;
  in_ready <= 1'b0;
  is_last <= 1'b0;
  byte_num <= 3'd0;
  in <= 64'd0;
  @(posedge clk);
  reset <= 1'b0;
  @(posedge clk);
  in <= 64'hFFEEDDCCBBAA9988;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  is_last <= 1'b0;
  @(posedge clk);
  in_ready <= 1'b0;
  @(posedge clk);
  in <= 64'h7766554433221100;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  is_last <= 1'b0;
  @(posedge clk);
  in_ready <= 1'b0;
  @(posedge clk);
  in <= 64'hA1B2000000000000;
  byte_num <= 3'd2;
  @(posedge clk);
  in_ready <= 1'b1;
  is_last <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  is_last <= 1'b0;
  byte_num <= 3'd0;
endtask

// ===== Stimuli from: /mnt/e/Yuren/Researsh/project/opencores_downloads/downloads/sha3_h/sha3/trunk/high_throughput_core/testbench/test_rconst2in1.v =====
task drive_stimuli_16;
  @(posedge clk);
  reset    <= 1'b1;
  in_ready <= 1'b0;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
  in       <= 64'd0;
  @(posedge clk);
  reset    <= 1'b0;

  @(posedge clk);
  in       <= 64'd0;
  is_last  <= 1'b1;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
endtask

task drive_stimuli_17;
  @(posedge clk);
  reset    <= 1'b1;
  in_ready <= 1'b0;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
  in       <= 64'd0;
  @(posedge clk);
  reset    <= 1'b0;

  @(posedge clk);
  in       <= 64'h6162630000000000;
  is_last  <= 1'b1;
  byte_num <= 3'd3;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
endtask

task drive_stimuli_18;
  @(posedge clk);
  reset    <= 1'b1;
  in_ready <= 1'b0;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
  in       <= 64'd0;
  @(posedge clk);
  reset    <= 1'b0;

  @(posedge clk);
  in       <= 64'h1122334455667788;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;

  @(posedge clk);
  in       <= 64'h99AABBCCDDEEFF00;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;

  @(posedge clk);
  in       <= 64'hDEADBEEF55000000;
  is_last  <= 1'b1;
  byte_num <= 3'd5;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
endtask

task drive_stimuli_19;
  @(posedge clk);
  reset    <= 1'b1;
  in_ready <= 1'b0;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
  in       <= 64'd0;
  @(posedge clk);
  reset    <= 1'b0;

  @(posedge clk);
  in       <= 64'h0123456789ABCDEF;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;

  @(posedge clk);
  in       <= 64'h0F1E2D3C4B5A6978;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;

  @(posedge clk);
  in       <= 64'd0;
  is_last  <= 1'b1;
  byte_num <= 3'd0;
  @(posedge clk);
  in_ready <= 1'b1;
  @(posedge clk);
  in_ready <= 1'b0;
  is_last  <= 1'b0;
  byte_num <= 3'd0;
endtask

  // Clock generator
  initial begin
     drive_clk();
  end

  // Main test sequence
  initial begin
     drive_rst();
    fork
        drive_stimuli_1();
        repeat (1) begin
            checker_out();
        end
    join
    fork
        drive_stimuli_2();
        repeat (1) begin
            checker_out();
        end
    join
    fork
        drive_stimuli_3();
        repeat (1) begin
            checker_out();
        end
    join
    fork
        drive_stimuli_4();
        repeat (1) begin
            checker_out();
        end
    join
    fork
        drive_stimuli_5();
        repeat (1) begin
            checker_out();
        end
    join
    fork
        drive_stimuli_6();
        repeat (1) begin
            checker_out();
        end
    join
    fork
        drive_stimuli_7();
        repeat (1) begin
            checker_out();
        end
    join
    fork
        drive_stimuli_8();
        repeat (1) begin
            checker_out();
        end
    join
    fork
        drive_stimuli_9();
        repeat (1) begin
            checker_out();
        end
    join
    fork
        drive_stimuli_10();
        repeat (1) begin
            checker_out();
        end
    join
    fork
        drive_stimuli_11();
        repeat (1) begin
            checker_out();
        end
    join
    fork
        drive_stimuli_12();
        repeat (1) begin
            checker_out();
        end
    join
    fork
        drive_stimuli_13();
        repeat (1) begin
            checker_out();
        end
    join
    fork
        drive_stimuli_14();
        repeat (1) begin
            checker_out();
        end
    join
    fork
        drive_stimuli_15();
        repeat (1) begin
            checker_out();
        end
    join
    fork
        drive_stimuli_16();
        repeat (1) begin
            checker_out();
        end
    join
    fork
        drive_stimuli_17();
        repeat (1) begin
            checker_out();
        end
    join
    fork
        drive_stimuli_18();
        repeat (1) begin
            checker_out();
        end
    join
    fork
        drive_stimuli_19();
        repeat (1) begin
            checker_out();
        end
    join
     $display("all patterns test done");
     $finish();
  end

  // Monitor both DUT and REF simultaneously
  initial begin
     fork
        monitor_dut;
        monitor_ref;
     join
  end

  // Watchdog for timeout protection
  initial begin
     repeat(10000)
         @(posedge clk);
     $display("ERROR, watchdog fail");
     $finish();
  end
  always @(posedge clk, negedge clk) begin
     stats1.clocks++;
  end
	initial begin
		$dumpfile("wave.vcd");
		$dumpvars(0, tb);
	end
  // Statistics summary (verilogcoder)
  final begin
    if (stats1.errors_buffer_full)
      $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "buffer_full", stats1.errors_buffer_full, stats1.errortime_buffer_full);
    else
      $display("Hint: Output buffer_full has no mismatches.");
    if (stats1.errors_out)
      $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "out", stats1.errors_out, stats1.errortime_out);
    else
      $display("Hint: Output out has no mismatches.");
    if (stats1.errors_out_ready)
      $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "out_ready", stats1.errors_out_ready, stats1.errortime_out_ready);
    else
      $display("Hint: Output out_ready has no mismatches.");

    $display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.samples);
    $display("Simulation finished at %0d ps", $time);
    $display("Mismatches: %1d in %1d samples", stats1.errors, stats1.samples);
  end

endmodule
