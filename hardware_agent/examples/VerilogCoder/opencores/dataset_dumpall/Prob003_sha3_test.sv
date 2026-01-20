module tb;

//declare:
 // 1) Inputs & Inouts driven by TB
logic clk;
logic reset;
logic [31:0] in;
logic in_ready;
logic is_last;
logic [1:0] byte_num;

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
logic [511:0] out_ref_q[$];
logic [511:0] out_ref_pop;
logic [511:0] out_dut_q[$];
logic [511:0] out_dut_pop;
event out_ref_event;
logic out_ready_ref_q[$];
logic out_ready_ref_pop;
logic out_ready_dut_q[$];
logic out_ready_dut_pop;
event out_ready_ref_event;

int errortime_out_dut_q[$];
int errortime_out_dut_pop;

 // 2.2) signal for tb
int test_errors;

typedef struct packed {
	int errors;
	int errortime;
	int errors_out;
	int errortime_out;
	int errors_out_ready;
	int errortime_out_ready;					  						
	int errors_buffer_full;
	int errortime_buffer_full;					  
	int clocks;
    int samples;
} stats;

stats stats1;


//link:
 // 3) Instances
TopModule dut (
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

RefModule ref_mdl (
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

task automatic monitor_dut();
  bit prev_out_ready;
  prev_out_ready = out_ready_dut;
  forever begin
    @(posedge clk);
    if (out_ready_dut && !prev_out_ready) begin
      @(posedge clk);
      out_dut_q.push_back(out_dut);
      errortime_out_dut_q.push_back($time);
    end
    prev_out_ready = out_ready_dut;
  end
endtask

task automatic monitor_ref();
  bit prev_out_ready;
  prev_out_ready = out_ready_ref;
  forever begin
    @(posedge clk);
    if (out_ready_ref && !prev_out_ready) begin
      @(posedge clk);
      out_ref_q.push_back(out_ref);
      stats1.samples++;
      -> out_ref_event;
    end
    prev_out_ready = out_ready_ref;
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
    $display("@%0d,waiting out_ref_event", $time);
    @(out_ref_event);
    t2 = $realtime;
    ref_time = t2 - t1;
    $display("@%0d,wait out_ref_event done", $time);
    if (out_dut_q.size() > 0) begin
        out_ref_pop = out_ref_q.pop_front();
        out_dut_pop = out_dut_q.pop_front();
        errortime_out_dut_pop = errortime_out_dut_q.pop_front();
        if (out_ref_pop == out_dut_pop) begin
            $display("[check out passed] @time:%0t dut=%0h, ref=%0h ",
                     $time, out_dut_pop, out_ref_pop);
        end
        else begin
					  if (stats1.errors_out == 0) begin
					  	stats1.errortime_out = errortime_out_dut_pop;
					  	if (stats1.errors == 0) stats1.errortime = errortime_out_dut_pop;
					  end
					  stats1.errors_out = stats1.errors_out+1'b1;
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
                    $display("[check out passed] @time:%0t dut=%0h, ref=%0h ",
                             $time, out_dut_pop, out_ref_pop);
                end
                else begin
					          if (stats1.errors_out == 0) begin
					          	stats1.errortime_out = errortime_out_dut_pop;
					          	if (stats1.errors == 0) stats1.errortime = errortime_out_dut_pop;
					          end
					          stats1.errors_out = stats1.errors_out+1'b1;
					          stats1.errors++;                  
                    test_errors++;
                    $display("[check out FAILED] @time:%0t dut=%0h, ref=%0h ",
                             $time, out_dut_pop, out_ref_pop);
                end
            end
            begin
                #(ref_time);
					      if (stats1.errors_out_ready == 0) begin
					      	stats1.errortime_out_ready = $time;
					      	if (stats1.errors == 0) stats1.errortime = $time;
					      end
					      stats1.errors_out_ready = stats1.errors_out_ready+1'b1;
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
    reset = 1'b1;
    #20;
    reset = 1'b0;
  end
endtask

task drive_clk();
  begin
    clk = 1'b0;
    forever begin
      #10 clk = ~clk;
    end
  end
endtask

// task below represents one complete input-driving sequence (one hash message).
// Sequential protocol: data prepared one cycle before asserting in_ready/is_last.
// Only official interface inputs are driven: clk, reset, in, in_ready, is_last, byte_num.

task drive_stimuli_1;
  // Single partial-block message: 3-byte message (MSB-aligned), zeros data
  begin
    // Synchronous reset (one rising edge)
    @(posedge clk);
    reset    <= 1'b1;
    in       <= 32'h00000000;
    in_ready <= 1'b0;
    is_last  <= 1'b0;
    byte_num <= 2'b00;
    @(posedge clk);
    reset    <= 1'b0;

    // Prepare last data (3 bytes valid, MSB-aligned; data = 0)
    @(posedge clk);
    in       <= 32'h00000000;

    // Present last block (valid for one cycle)
    @(posedge clk);
    in_ready <= 1'b1;
    is_last  <= 1'b1;
    byte_num <= 2'b11; // 3 bytes valid

    // Release/cleanup
    @(posedge clk);
    in_ready <= 1'b0;
    is_last  <= 1'b0;
    byte_num <= 2'b00;
  end
endtask

task drive_stimuli_2;
  // Two full 32-bit words (zeros) followed by a zero-length last block
  begin
    // Synchronous reset
    @(posedge clk);
    reset    <= 1'b1;
    in       <= 32'h00000000;
    in_ready <= 1'b0;
    is_last  <= 1'b0;
    byte_num <= 2'b00;
    @(posedge clk);
    reset    <= 1'b0;

    // Word 1 (data prepared one cycle before in_ready)
    @(posedge clk);
    in       <= 32'h00000000;
    @(posedge clk);
    in_ready <= 1'b1;
    is_last  <= 1'b0;
    @(posedge clk);
    in_ready <= 1'b0;

    // Word 2
    @(posedge clk);
    in       <= 32'h00000000;
    @(posedge clk);
    in_ready <= 1'b1;
    is_last  <= 1'b0;
    @(posedge clk);
    in_ready <= 1'b0;

    // Zero-length final block (required when message length is multiple of input width)
    @(posedge clk);
    in       <= 32'h00000000; // don't care; keep stable
    @(posedge clk);
    in_ready <= 1'b1;
    is_last  <= 1'b1;
    byte_num <= 2'b00; // zero-length
    @(posedge clk);
    in_ready <= 1'b0;
    is_last  <= 1'b0;
    byte_num <= 2'b00;
  end
endtask

task drive_stimuli_3;
  // Empty message: send only the zero-length last block after reset
  begin
    // Synchronous reset
    @(posedge clk);
    reset    <= 1'b1;
    in       <= 32'h00000000;
    in_ready <= 1'b0;
    is_last  <= 1'b0;
    byte_num <= 2'b00;
    @(posedge clk);
    reset    <= 1'b0;

    // Prepare (no data word; keep bus stable)
    @(posedge clk);
    in       <= 32'h00000000;

    // Zero-length final block to request digest for empty message
    @(posedge clk);
    in_ready <= 1'b1;
    is_last  <= 1'b1;
    byte_num <= 2'b00;
    @(posedge clk);
    in_ready <= 1'b0;
    is_last  <= 1'b0;
    byte_num <= 2'b00;
  end
endtask

task drive_stimuli_4;
  // Exactly one full 576-bit absorption: 18 words of zeros, then zero-length last block
  int k;
  begin
    // Synchronous reset
    @(posedge clk);
    reset    <= 1'b1;
    in       <= 32'h00000000;
    in_ready <= 1'b0;
    is_last  <= 1'b0;
    byte_num <= 2'b00;
    @(posedge clk);
    reset    <= 1'b0;

    // Send 18 words (18 * 32 = 576 bits)
    for (k = 0; k < 18; k++) begin
      @(posedge clk);
      in       <= 32'h00000000;
      @(posedge clk);
      in_ready <= 1'b1;
      is_last  <= 1'b0;
      @(posedge clk);
      in_ready <= 1'b0;
    end

    // Zero-length final block
    @(posedge clk);
    in       <= 32'h00000000;
    @(posedge clk);
    in_ready <= 1'b1;
    is_last  <= 1'b1;
    byte_num <= 2'b00;
    @(posedge clk);
    in_ready <= 1'b0;
    is_last  <= 1'b0;
    byte_num <= 2'b00;
  end
endtask

task drive_stimuli_5; // SHA3-512("The quick brown fox jumps over the lazy dog")
    begin
        // Synchronous reset (one cycle)
        @(posedge clk); reset = 1'b1;
        @(posedge clk); reset = 1'b0;

        // Prepare first data word, keep controls low
        @(negedge clk);
        in       = "The ";
        is_last  = 1'b0;
        byte_num = 2'd0;

        // Assert in_ready after data is stable
        @(posedge clk);
        in_ready = 1'b1;

        // Stream remaining data words
        @(negedge clk); in = "quic"; @(posedge clk);
        @(negedge clk); in = "k br"; @(posedge clk);
        @(negedge clk); in = "own "; @(posedge clk);
        @(negedge clk); in = "fox "; @(posedge clk);
        @(negedge clk); in = "jump"; @(posedge clk);
        @(negedge clk); in = "s ov"; @(posedge clk);
        @(negedge clk); in = "er t"; @(posedge clk);
        @(negedge clk); in = "he l"; @(posedge clk);
        @(negedge clk); in = "azy "; @(posedge clk);

        // Last block: set data and byte_num first, then assert is_last
        @(negedge clk);
        in       = "dog ";
        byte_num = 2'd3; // 3 bytes valid for last block
        @(posedge clk);
        is_last  = 1'b1;

        // Cleanup
        @(posedge clk);
        in_ready = 1'b0;
        is_last  = 1'b0;
        byte_num = 2'd0;
        @(negedge clk);
        in       = 32'd0;
    end
endtask

task drive_stimuli_6; // SHA3-512("The quick brown fox jumps over the lazy dog.")
    begin
        // Synchronous reset (one cycle)
        @(posedge clk); reset = 1'b1;
        @(posedge clk); reset = 1'b0;

        // Prepare first data word, controls low
        @(negedge clk);
        in       = "The ";
        is_last  = 1'b0;
        byte_num = 2'd0;

        // Assert in_ready after data is stable
        @(posedge clk);
        in_ready = 1'b1;

        // Stream message
        @(negedge clk); in = "quic"; @(posedge clk);
        @(negedge clk); in = "k br"; @(posedge clk);
        @(negedge clk); in = "own "; @(posedge clk);
        @(negedge clk); in = "fox "; @(posedge clk);
        @(negedge clk); in = "jump"; @(posedge clk);
        @(negedge clk); in = "s ov"; @(posedge clk);
        @(negedge clk); in = "er t"; @(posedge clk);
        @(negedge clk); in = "he l"; @(posedge clk);
        @(negedge clk); in = "azy "; @(posedge clk);
        @(negedge clk); in = "dog."; @(posedge clk);

        // Extra zero-length final block (is_last=1, byte_num=0)
        @(negedge clk);
        in       = 32'd0;
        byte_num = 2'd0;
        @(posedge clk);
        is_last  = 1'b1;

        // Cleanup
        @(posedge clk);
        in_ready = 1'b0;
        is_last  = 1'b0;
        @(negedge clk);
        in       = 32'd0;
    end
endtask

task drive_stimuli_7; // Hash bytes A1 A2 A3 A4 A5 (length = 5)
    begin
        // Synchronous reset (one cycle)
        @(posedge clk); reset = 1'b1;
        @(posedge clk); reset = 1'b0;

        // Wait 7 cycles before feeding data
        repeat (7) @(posedge clk);

        // First word (A1 A2 A3 A4), set byte_num (no effect yet), controls low
        @(negedge clk);
        in       = 32'hA1A2A3A4;
        is_last  = 1'b0;
        byte_num = 2'd1; // will be meaningful on last block

        // Start streaming
        @(posedge clk);
        in_ready = 1'b1;

        // Last word (A5 is MSB-aligned), set byte_num then assert is_last
        @(negedge clk);
        in       = 32'hA5000000;
        byte_num = 2'd1;
        @(posedge clk);
        is_last  = 1'b1;

        // Cleanup
        @(posedge clk);
        in_ready = 1'b0;
        is_last  = 1'b0;
        byte_num = 2'd0;
        @(negedge clk);
        in       = 32'd0;
    end
endtask

task drive_stimuli_8; // Hash an empty string (zero-length block)
    begin
        // Synchronous reset (one cycle)
        @(posedge clk); reset = 1'b1;
        @(posedge clk); reset = 1'b0;

        // Wait 7 cycles before feeding data
        repeat (7) @(posedge clk);

        // Prepare zero-length block (in value irrelevant), then assert is_last with byte_num=0
        @(negedge clk);
        in       = 32'h12345678;
        is_last  = 1'b0;
        byte_num = 2'd0;
        @(posedge clk);
        in_ready = 1'b1;
        is_last  = 1'b1;

        // Cleanup
        @(posedge clk);
        in_ready = 1'b0;
        is_last  = 1'b0;
        @(negedge clk);
        in       = 32'd0;
    end
endtask

task drive_stimuli_9; // Hash a (576-8) bit string
    integer j;
    begin
        // Synchronous reset (one cycle)
        @(posedge clk); reset = 1'b1;
        @(posedge clk); reset = 1'b0;

        // Wait 4 cycles before feeding data
        repeat (4) @(posedge clk);

        // Preload first word and byte_num (will apply on last block)
        @(negedge clk);
        in       = 32'hEFCDAB90;
        is_last  = 1'b0;
        byte_num = 2'd3; // 3 bytes valid on last block

        // Start streaming
        @(posedge clk);
        in_ready = 1'b1;

        // Stream 8 pairs (16 words)
        for (j = 0; j < 8; j = j + 1) begin
            @(negedge clk); in = 32'h78563412; @(posedge clk);
            @(negedge clk); in = 32'hEFCDAB90; @(posedge clk);
        end

        // Final two words, assert is_last on the last
        @(negedge clk); in = 32'h78563412; @(posedge clk);
        @(negedge clk);
        in       = 32'hEFCDAB90; // penultimate word
        @(posedge clk);
        // prepare last word and assert is_last
        @(negedge clk);
        in       = 32'h78563412; // last word
        byte_num = 2'd3;
        @(posedge clk);
        is_last  = 1'b1;

        // Cleanup
        @(posedge clk);
        in_ready = 1'b0;
        is_last  = 1'b0;
        byte_num = 2'd0;
        @(negedge clk);
        in       = 32'd0;
    end
endtask

task drive_stimuli_10; // Pad a (576-64) bit string
    integer j;
    begin
        // Synchronous reset (one cycle)
        @(posedge clk); reset = 1'b1;
        @(posedge clk); reset = 1'b0;

        // Do not wait any cycles; start immediately
        @(negedge clk);
        in       = 32'hEFCDAB90;
        is_last  = 1'b0;
        byte_num = 2'd3; // original TB used 7; width truncates to 3, has no effect before is_last

        @(posedge clk);
        in_ready = 1'b1;

        // Stream 8 pairs (16 words = 512 bits)
        for (j = 0; j < 8; j = j + 1) begin
            @(negedge clk); in = 32'h78563412; @(posedge clk);
            @(negedge clk); in = 32'hEFCDAB90; @(posedge clk);
        end

        // Extra zero-length final block: is_last=1, byte_num=0
        @(negedge clk);
        byte_num = 2'd0;
        @(posedge clk);
        is_last  = 1'b1;

        // Cleanup
        @(posedge clk);
        in_ready = 1'b0;
        is_last  = 1'b0;
        @(negedge clk);
        in       = 32'd0;
    end
endtask

task drive_stimuli_11; // Pad a (576*2 - 16) bit string
    integer j;
    begin
        // Synchronous reset (one cycle)
        @(posedge clk); reset = 1'b1;
        @(posedge clk); reset = 1'b0;

        // First 576-bit block (18 words)
        @(negedge clk);
        in       = 32'hEFCDAB90;
        is_last  = 1'b0;
        byte_num = 2'd1; // original TB used 1; no effect until last
        @(posedge clk);
        in_ready = 1'b1;

        for (j = 0; j < 9; j = j + 1) begin
            @(negedge clk); in = 32'h78563412; @(posedge clk);
            @(negedge clk); in = 32'hEFCDAB90; @(posedge clk);
        end

        // Brief pause (simulate gating behavior without checking outputs)
        @(posedge clk);
        in_ready = 1'b0;

        // Next (576-16) bits
        @(negedge clk);
        in = 32'hEFCDAB90;
        @(posedge clk);
        in_ready = 1'b1;

        // 8 pairs (16 words)
        for (j = 0; j < 8; j = j + 1) begin
            @(negedge clk); in = 32'h78563412; @(posedge clk);
            @(negedge clk); in = 32'hEFCDAB90; @(posedge clk);
        end

        // Penultimate word
        @(negedge clk); in = 32'hEFCDAB90; @(posedge clk);

        // Last word: set byte_num=2 then assert is_last
        @(negedge clk);
        in       = 32'h78563412;
        byte_num = 2'd2; // 16 bits valid on last word
        @(posedge clk);
        is_last  = 1'b1;

        // Cleanup
        @(posedge clk);
        in_ready = 1'b0;
        is_last  = 1'b0;
        byte_num = 2'd0;
        @(negedge clk);
        in       = 32'd0;
    end
endtask

task drive_stimuli_12;
  begin
    // Start a new hash: synchronous reset for one cycle
    @(posedge clk);
    reset    <= 1'b1;
    in_ready <= 1'b0;
    is_last  <= 1'b0;
    byte_num <= 2'b00;
    in       <= 32'h90ABCDEF;

    @(posedge clk);
    reset    <= 1'b0;

    // Prepare last-block data one cycle before asserting in_ready
    @(posedge clk);
    in       <= 32'h90ABCDEF;
    byte_num <= 2'b00;     // zero-length last block
    is_last  <= 1'b1;

    // Present the last block for one cycle
    @(posedge clk);
    in_ready <= 1'b1;

    // Cleanup
    @(posedge clk);
    in_ready <= 1'b0;
    is_last  <= 1'b0;
  end
endtask

task drive_stimuli_13;
  begin
    // Start a new hash: synchronous reset for one cycle
    @(posedge clk);
    reset    <= 1'b1;
    in_ready <= 1'b0;
    is_last  <= 1'b0;
    byte_num <= 2'b00;
    in       <= 32'h90ABCDEF;

    @(posedge clk);
    reset    <= 1'b0;

    // Prepare last-block data one cycle before asserting in_ready
    @(posedge clk);
    in       <= 32'h90ABCDEF;
    byte_num <= 2'b01;     // 1 valid byte in last block
    is_last  <= 1'b1;

    // Present the last block for one cycle
    @(posedge clk);
    in_ready <= 1'b1;

    // Cleanup
    @(posedge clk);
    in_ready <= 1'b0;
    is_last  <= 1'b0;
  end
endtask

task drive_stimuli_14;
  begin
    // Start a new hash: synchronous reset for one cycle
    @(posedge clk);
    reset    <= 1'b1;
    in_ready <= 1'b0;
    is_last  <= 1'b0;
    byte_num <= 2'b00;
    in       <= 32'h90ABCDEF;

    @(posedge clk);
    reset    <= 1'b0;

    // Prepare last-block data one cycle before asserting in_ready
    @(posedge clk);
    in       <= 32'h90ABCDEF;
    byte_num <= 2'b10;     // 2 valid bytes in last block
    is_last  <= 1'b1;

    // Present the last block for one cycle
    @(posedge clk);
    in_ready <= 1'b1;

    // Cleanup
    @(posedge clk);
    in_ready <= 1'b0;
    is_last  <= 1'b0;
  end
endtask

task drive_stimuli_15;
  begin
    // Start a new hash: synchronous reset for one cycle
    @(posedge clk);
    reset    <= 1'b1;
    in_ready <= 1'b0;
    is_last  <= 1'b0;
    byte_num <= 2'b00;
    in       <= 32'h90ABCDEF;

    @(posedge clk);
    reset    <= 1'b0;

    // Prepare last-block data one cycle before asserting in_ready
    @(posedge clk);
    in       <= 32'h90ABCDEF;
    byte_num <= 2'b11;     // 3 valid bytes in last block
    is_last  <= 1'b1;

    // Present the last block for one cycle
    @(posedge clk);
    in_ready <= 1'b1;

    // Cleanup
    @(posedge clk);
    in_ready <= 1'b0;
    is_last  <= 1'b0;
  end
endtask

task drive_stimuli_16; // Empty message (zero-length last block)
    // Synchronous reset for one cycle
    @(posedge clk);
    reset    <= 1'b1;
    in_ready <= 1'b0;
    is_last  <= 1'b0;
    byte_num <= 2'd0;
    in       <= 32'h00000000;

    @(posedge clk);
    reset <= 1'b0;

    // Wait 7 cycles (as in original TB)
    repeat (7) @(posedge clk);

    // Send zero-length final block: assert in_ready and is_last for two cycles
    @(negedge clk);
    in       <= 32'h00000000;
    byte_num <= 2'd0;
    is_last  <= 1'b0;
    in_ready <= 1'b0;

    @(posedge clk);
    in_ready <= 1'b1;
    is_last  <= 1'b1;

    @(posedge clk);
    in_ready <= 1'b1;
    is_last  <= 1'b1;

    @(posedge clk);
    in_ready <= 1'b0;
    is_last  <= 1'b0;
endtask

task drive_stimuli_17; // (576-8)-bit message stream ending with is_last
    int i;

    // Synchronous reset for one cycle
    @(posedge clk);
    reset    <= 1'b1;
    in_ready <= 1'b0;
    is_last  <= 1'b0;
    byte_num <= 2'd0;
    in       <= 32'h00000000;

    @(posedge clk);
    reset <= 1'b0;

    // Wait 4 cycles (as in original TB)
    repeat (4) @(posedge clk);

    // Prepare first word before asserting in_ready
    @(negedge clk);
    in       <= 32'h12345678;
    in_ready <= 1'b0;
    is_last  <= 1'b0;
    byte_num <= 2'd3; // "should have no effect" (not last)

    // Start streaming
    @(posedge clk);
    in_ready <= 1'b1;

    // After first word accepted, stream alternating words:
    // We want 16 words total before the two trailing words; first word already sent.
    // Generate next 14 words in 7 pairs: (90AB, 1234) x7
    for (i = 0; i < 7; i++) begin
        @(negedge clk);
        in <= 32'h90ABCDEF; // even word
        @(negedge clk);
        in <= 32'h12345678; // odd word
    end

    // Now send the 16th word of this segment
    @(negedge clk);
    in <= 32'h90ABCDEF;

    // Send trailing two words: 12345678 then last word 90ABCDEF with is_last
    @(negedge clk);
    in <= 32'h12345678;

    @(negedge clk);
    in <= 32'h90ABCDEF;

    @(posedge clk);
    is_last <= 1'b1; // mark current word as the last

    // Cleanup
    @(posedge clk);
    in_ready <= 1'b0;
    is_last  <= 1'b0;
endtask

task drive_stimuli_18; // (576-64)-bit message; final zero-length block required (byte_num=0)
    int i;

    // Synchronous reset for one cycle
    @(posedge clk);
    reset    <= 1'b1;
    in_ready <= 1'b0;
    is_last  <= 1'b0;
    byte_num <= 2'd0;
    in       <= 32'h00000000;

    @(posedge clk);
    reset <= 1'b0;

    // No wait cycles (as in original TB)

    // Prepare first word before asserting in_ready
    @(negedge clk);
    in       <= 32'h12345678;
    in_ready <= 1'b0;
    is_last  <= 1'b0;
    byte_num <= 2'd1; // "should have no effect" (not last)

    // Start streaming
    @(posedge clk);
    in_ready <= 1'b1;

    // After first word accepted, stream until 16 words total:
    // 7 pairs (90AB, 1234) => +14 words, total 15 so far (last=1234)
    for (i = 0; i < 7; i++) begin
        @(negedge clk);
        in <= 32'h90ABCDEF;
        @(negedge clk);
        in <= 32'h12345678;
    end

    // 16th word of this segment (should end on 90AB)
    @(negedge clk);
    in <= 32'h90ABCDEF;

    // Assert last-block zero-length (byte_num=0) next cycle
    @(posedge clk);
    is_last  <= 1'b1;
    byte_num <= 2'd0;

    // Cleanup
    @(posedge clk);
    in_ready <= 1'b0;
    is_last  <= 1'b0;
endtask

task drive_stimuli_19; // Two-block message: first full 576b block, then (576-16)b final with byte_num=2
    int i;

    // Synchronous reset for one cycle
    @(posedge clk);
    reset    <= 1'b1;
    in_ready <= 1'b0;
    is_last  <= 1'b0;
    byte_num <= 2'd0;
    in       <= 32'h00000000;

    @(posedge clk);
    reset <= 1'b0;

    // -------- Block 1: exactly 576 bits (18 words) --------
    // Prepare first word before asserting in_ready
    @(negedge clk);
    in       <= 32'h12345678;
    in_ready <= 1'b0;
    is_last  <= 1'b0;

    // Start streaming
    @(posedge clk);
    in_ready <= 1'b1;

    // Provide remaining 17 words to complete 18-word block:
    // 8 pairs (90AB, 1234) => 16 words, plus one final 90AB => total 17 after the very first 1234
    for (i = 0; i < 8; i++) begin
        @(negedge clk);
        in <= 32'h90ABCDEF;
        @(negedge clk);
        in <= 32'h12345678;
    end
    // After loop, we've sent 17 words in addition to the initial; last sent word is 1234.
    // Send one more 90AB to make 18th word of block 1
    @(negedge clk);
    in <= 32'h90ABCDEF;

    // Insert idle gap to avoid backpressure between blocks
    @(posedge clk);
    in_ready <= 1'b0;
    repeat (32) @(posedge clk); // allow internal processing to drain

    // -------- Block 2: 576-16 bits (17.5 words) --------
    // Prepare first word of block 2 before asserting in_ready
    @(negedge clk);
    in       <= 32'h12345678;
    is_last  <= 1'b0;
    byte_num <= 2'd0;

    @(posedge clk);
    in_ready <= 1'b1;

    // Deliver 16-word segment: 7 pairs (90AB,1234) + one final 90AB => ends on 90AB
    for (i = 0; i < 7; i++) begin
        @(negedge clk);
        in <= 32'h90ABCDEF;
        @(negedge clk);
        in <= 32'h12345678;
    end
    @(negedge clk);
    in <= 32'h90ABCDEF; // word 16

    // Add 17th word (1234)
    @(negedge clk);
    in <= 32'h12345678;

    // Final partial word (only 2 bytes valid): present 90AB and assert is_last with byte_num=2
    @(negedge clk);
    in <= 32'h90ABCDEF;

    @(posedge clk);
    is_last  <= 1'b1;
    byte_num <= 2'd2; // 2 valid bytes in the last word

    // Cleanup
    @(posedge clk);
    in_ready <= 1'b0;
    is_last  <= 1'b0;
endtask

task drive_stimuli_20;
    // Single-block message: 3-byte "abc" (0x61 0x62 0x63), MSB-aligned on 32-bit port
    // byte_num = 3, is_last = 1 for this block

    // Reset for new hash
    @(posedge clk);
        reset    = 1'b1;
        in_ready = 1'b0;
        is_last  = 1'b0;
        byte_num = 2'b00;
        in       = 32'h0000_0000;
    @(posedge clk);
        reset    = 1'b0;

    // Prepare data one cycle before asserting in_ready/is_last
    @(posedge clk);
        in       = 32'h61_62_63_00;   // MSB-aligned: [31:24]=0x61, [23:16]=0x62, [15:8]=0x63, [7:0]=0x00

    // Drive valid last block
    @(posedge clk);
        in_ready = 1'b1;
        is_last  = 1'b1;
        byte_num = 2'b11;             // 3 bytes

    // Cleanup
    @(posedge clk);
        in_ready = 1'b0;
        is_last  = 1'b0;
        byte_num = 2'b00;
        in       = 32'h0000_0000;
endtask

task drive_stimuli_21;
    // Two-block message:
    //   Block 0: full 4 bytes "abcd" (0x61 0x62 0x63 0x64), is_last = 0
    //   Block 1: last 2 bytes "ef" (0x65 0x66) MSB-aligned, is_last = 1, byte_num = 2

    // Reset for new hash
    @(posedge clk);
        reset    = 1'b1;
        in_ready = 1'b0;
        is_last  = 1'b0;
        byte_num = 2'b00;
        in       = 32'h0000_0000;
    @(posedge clk);
        reset    = 1'b0;

    // Prepare block 0 (full 4 bytes)
    @(posedge clk);
        in       = 32'h61_62_63_64;

    // Send block 0
    @(posedge clk);
        in_ready = 1'b1;
        is_last  = 1'b0;

    // Deassert valid
    @(posedge clk);
        in_ready = 1'b0;

    // Prepare block 1 (2-byte last block, MSB-aligned)
    @(posedge clk);
        in       = 32'h65_66_00_00;

    // Send block 1 as last
    @(posedge clk);
        in_ready = 1'b1;
        is_last  = 1'b1;
        byte_num = 2'b10;             // 2 bytes

    // Cleanup
    @(posedge clk);
        in_ready = 1'b0;
        is_last  = 1'b0;
        byte_num = 2'b00;
        in       = 32'h0000_0000;
endtask

task drive_stimuli_22;
    // Multiple-of-width message: 4-byte block followed by zero-length final block
    //   Block 0: full 4 bytes "wxyz" (0x77 0x78 0x79 0x7A), is_last = 0
    //   Block 1: zero-length last block, is_last = 1, byte_num = 0

    // Reset for new hash
    @(posedge clk);
        reset    = 1'b1;
        in_ready = 1'b0;
        is_last  = 1'b0;
        byte_num = 2'b00;
        in       = 32'h0000_0000;
    @(posedge clk);
        reset    = 1'b0;

    // Prepare block 0 (full 4 bytes)
    @(posedge clk);
        in       = 32'h77_78_79_7A;

    // Send block 0
    @(posedge clk);
        in_ready = 1'b1;
        is_last  = 1'b0;

    // Deassert valid
    @(posedge clk);
        in_ready = 1'b0;

    // Prepare zero-length last block
    @(posedge clk);
        in       = 32'h0000_0000;

    // Send zero-length last block
    @(posedge clk);
        in_ready = 1'b1;
        is_last  = 1'b1;
        byte_num = 2'b00;             // zero-length final block

    // Cleanup
    @(posedge clk);
        in_ready = 1'b0;
        is_last  = 1'b0;
        byte_num = 2'b00;
        in       = 32'h0000_0000;
endtask

task drive_stimuli_23;
    // Multi-block message with a conservative repeat of one block value across two consecutive valid cycles.
    // This accommodates scenarios where buffer_full might block the first attempt; the next valid repeats the same 'in'.
    //   Block 0: 4 bytes 0x01 0x23 0x45 0x67 (full width), sent twice consecutively with the same value
    //   Block 1: 4 bytes 0x89 0xAB 0xCD 0xEF (full width)
    //   Block 2: last 1 byte 0x21 ('!'), MSB-aligned, is_last = 1, byte_num = 1

    // Reset for new hash
    @(posedge clk);
        reset    = 1'b1;
        in_ready = 1'b0;
        is_last  = 1'b0;
        byte_num = 2'b00;
        in       = 32'h0000_0000;
    @(posedge clk);
        reset    = 1'b0;

    // Prepare block 0 (full 4 bytes)
    @(posedge clk);
        in       = 32'h01_23_45_67;

    // Send block 0 attempt 1
    @(posedge clk);
        in_ready = 1'b1;
        is_last  = 1'b0;

    // Keep the same value and send block 0 attempt 2 (repeat)
    @(posedge clk);
        in_ready = 1'b1;              // same 'in' value; repeated valid
        is_last  = 1'b0;

    // Deassert valid
    @(posedge clk);
        in_ready = 1'b0;

    // Prepare block 1 (full 4 bytes)
    @(posedge clk);
        in       = 32'h89_AB_CD_EF;

    // Send block 1
    @(posedge clk);
        in_ready = 1'b1;
        is_last  = 1'b0;

    // Deassert valid
    @(posedge clk);
        in_ready = 1'b0;

    // Prepare block 2: last 1 byte 0x21 ('!') MSB-aligned
    @(posedge clk);
        in       = 32'h21_00_00_00;

    // Send last block
    @(posedge clk);
        in_ready = 1'b1;
        is_last  = 1'b1;
        byte_num = 2'b01;             // 1 byte

    // Cleanup
    @(posedge clk);
        in_ready = 1'b0;
        is_last  = 1'b0;
        byte_num = 2'b00;
        in       = 32'h0000_0000;
endtask

  // Clock generator
  initial begin
     drive_clk();
  end

  // Main test sequence
  initial begin
     drive_rst();
     drive_stimuli_1();
     fork
        checker_out();
     join

     drive_stimuli_2();
     fork
        checker_out();
     join

     drive_stimuli_3();
     fork
        checker_out();
     join

     drive_stimuli_4();
     fork
        checker_out();
     join

     drive_stimuli_5();
     fork
        checker_out();
     join

     drive_stimuli_6();
     fork
        checker_out();
     join

     drive_stimuli_7();
     fork
        checker_out();
     join

     drive_stimuli_8();
     fork
        checker_out();
     join

     drive_stimuli_9();
     fork
        checker_out();
     join

     drive_stimuli_10();
     fork
        checker_out();
     join

     drive_stimuli_11();
     fork
        checker_out();
     join

     drive_stimuli_12();
     fork
        checker_out();
     join

     drive_stimuli_13();
     fork
        checker_out();
     join

     drive_stimuli_14();
     fork
        checker_out();
     join

     drive_stimuli_15();
     fork
        checker_out();
     join

     drive_stimuli_16();
     fork
        checker_out();
     join

     drive_stimuli_17();
     fork
        checker_out();
     join

     drive_stimuli_18();
     fork
        checker_out();
     join

     drive_stimuli_19();
     fork
        checker_out();
     join

     drive_stimuli_20();
     fork
        checker_out();
     join

     drive_stimuli_21();
     fork
        checker_out();
     join

     drive_stimuli_22();
     fork
        checker_out();
     join

     drive_stimuli_23();
     fork
        checker_out();
     join

     $display("all patterns test done");
     if (test_errors>0) begin
      $display("The test FAILED!! error_num=%0d", test_errors);
     end
     else begin
      $display("The test PASSED!!");
     end
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
  
	initial begin
		$dumpfile("wave.vcd");
		$dumpvars(0, tb);
	end

  always @(posedge clk, negedge clk) begin
		stats1.clocks++;
	end

	final begin
		if (stats1.errors_out) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "out", stats1.errors_out, stats1.errortime_out);
		else $display("Hint: Output '%s' has no mismatches.", "out");
		if (stats1.errors_out_ready) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "out_ready", stats1.errors_out_ready, stats1.errortime_out_ready);
		else $display("Hint: Output '%s' has no mismatches.", "out_ready");	
		if (stats1.errors_buffer_full) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "buffer_full", stats1.errors_buffer_full, stats1.errortime_buffer_full);
		else $display("Hint: Output '%s' has no mismatches.", "buffer_full");
		
		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.samples);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.samples);
	end
endmodule
