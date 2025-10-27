////////////////////////////////////////////////
//yrlu the following is tb provided by Opencores auther
module tb;

	// Inputs
	reg clk;
	reg rst;
	reg load0_i;
	reg load1_i;
	reg load2_i;
	reg load3_i;
	reg load4_i;
	reg load5_i;
	reg load6_i;
	reg [7:0] writedata0_i;
	reg [7:0] writedata1_i;
	reg [7:0] writedata2_i;
	reg [7:0] writedata3_i;
	reg [7:0] writedata4_i;
	reg [7:0] writedata5_i;
	reg [7:0] writedata6_i;
	reg start_i;
	reg abort_i;

	// Outputs
	wire [7:0] readdata0_o_dut;
	wire [7:0] readdata1_o_dut;
	wire [7:0] readdata2_o_dut;
	wire [7:0] readdata3_o_dut;
	wire [7:0] readdata4_o_dut;
	wire [7:0] readdata5_o_dut;
	wire [7:0] readdata6_o_dut;
	wire [55:0] readdata_o_dut;
	wire done_o_dut;
	assign {readdata6_o_dut,readdata5_o_dut,readdata4_o_dut,readdata3_o_dut,readdata2_o_dut,readdata1_o_dut,readdata0_o_dut} = readdata_o_dut;
	wire interrupt_o_dut;

	// Outputs
	wire [7:0] readdata0_o_ref;
	wire [7:0] readdata1_o_ref;
	wire [7:0] readdata2_o_ref;
	wire [7:0] readdata3_o_ref;
	wire [7:0] readdata4_o_ref;
	wire [7:0] readdata5_o_ref;
	wire [7:0] readdata6_o_ref;
	wire [55:0] readdata_o_ref;
	
	wire done_o_ref;
	wire interrupt_o_ref;
	assign {readdata6_o_ref,readdata5_o_ref,readdata4_o_ref,readdata3_o_ref,readdata2_o_ref,readdata1_o_ref,readdata0_o_ref} = readdata_o_ref;

	bit [55:0] readdata_o_ref_q[$];
	bit [55:0] readdata_o_ref_pop;
	bit [55:0] readdata_o_dut_q[$];
	bit [55:0] readdata_o_dut_pop;
	int errortime_readdata_o_dut_q[$];
	int errortime_readdata_o_dut_pop;
	event ref_data_evt;

	task drive_random_data();
		@(posedge clk);
        writedata0_i <= $urandom_range(0, 2<<8-1);
        writedata1_i <= $urandom_range(0, 2<<8-1);
        writedata2_i <= $urandom_range(0, 2<<8-1);
        writedata3_i <= $urandom_range(0, 2<<8-1);
        writedata4_i <= $urandom_range(0, 2<<8-1);
        writedata5_i <= $urandom_range(0, 2<<8-1);
        writedata6_i <= $urandom_range(0, 2<<8-1);

		@(posedge clk);
        load0_i <= 1;
        load1_i <= 1;
        load2_i <= 1;
        load3_i <= 1;
        load4_i <= 1;
        load5_i <= 1;
        load6_i <= 1;

		@(posedge clk);
        writedata0_i <= 0;
        writedata1_i <= 0;
        writedata2_i <= 0;
        writedata3_i <= 0;
        writedata4_i <= 0;
        writedata5_i <= 0;
        writedata6_i <= 0;
        load0_i <= 0;
        load1_i <= 0;
        load2_i <= 0;
        load3_i <= 0;
        load4_i <= 0;
        load5_i <= 0;
        load6_i <= 0;
        start_i <= 1;

        @(posedge clk);
    	start_i <= 0;
        fork
            @(posedge interrupt_o_ref);
		    @(posedge interrupt_o_dut);
        join
		repeat(5) @(posedge clk);	
	endtask

	initial begin:monitor_dut
		forever @(posedge clk) begin
			//if (interrupt_o_dut==1'b1 && done_o_dut==1'b1) begin
            if (interrupt_o_dut==1'b1) begin
				@(posedge clk); //sample data at next cycle
				readdata_o_dut_q.push_back(readdata_o_dut);
				errortime_readdata_o_dut_q.push_back($time);
				$display("@%0d, get readdata_o_dut", $time);
			end
		end
	end:monitor_dut

	initial begin:monitor_ref
		forever @(posedge clk) begin
			//if (interrupt_o_ref==1'b1 && done_o_ref==1'b1) begin
            if (interrupt_o_ref==1'b1) begin
				@(posedge clk); //sample data at next cycle
				readdata_o_ref_q.push_back(readdata_o_ref);
				$display("@%0d, get readdata_o_ref", $time);
				-> ref_data_evt;
			end
		end
	end:monitor_ref

	initial begin
		forever begin
			$display("@%0d,waiting ref_data_evt", $time);
			@(ref_data_evt);
			$display("@%0d,wait ref_data_evt done", $time);
			if (readdata_o_dut_q.size()>0) begin
				readdata_o_ref_pop = readdata_o_ref_q.pop_front();
				readdata_o_dut_pop = readdata_o_dut_q.pop_front();
				errortime_readdata_o_dut_pop = errortime_readdata_o_dut_q.pop_front();
				if(readdata_o_ref_pop==readdata_o_dut_pop) begin
					$display("[check readdata_o passed] @time:%0d dut=%0h, ref=%0h ",errortime_readdata_o_dut_pop
					                                                                ,readdata_o_dut_pop
																					,readdata_o_ref_pop);
				end
				else begin
					if (stats1.errors_readdata_o == 0) begin
						stats1.errortime_readdata_o = $time;
						if (stats1.errors == 0) stats1.errortime = errortime_readdata_o_dut_pop;
					end
					stats1.errors_readdata_o = stats1.errors_readdata_o+1'b1;
					stats1.errors++;	
					$display("[check readdata_o FAILED] @time:%0d dut=%0h, ref=%0h ",errortime_readdata_o_dut_pop
					                                                                ,readdata_o_dut_pop
																					,readdata_o_ref_pop);
				end
			end
			else begin
				fork
				begin
					wait(readdata_o_dut_q.size()>0);
					readdata_o_ref_pop = readdata_o_ref_q.pop_front();
					readdata_o_dut_pop = readdata_o_dut_q.pop_front();
					errortime_readdata_o_dut_pop = errortime_readdata_o_dut_q.pop_front();
					if(readdata_o_ref_pop==readdata_o_dut_pop) begin
						$display("[check readdata_o passed] @time:%0d dut=%0h, ref=%0h ",errortime_readdata_o_dut_pop
						                                                                ,readdata_o_dut_pop
																						,readdata_o_ref_pop);
					end
					else begin
						if (stats1.errors_readdata_o == 0) begin
							stats1.errortime_readdata_o = $time;
							if (stats1.errors == 0) stats1.errortime = errortime_readdata_o_dut_pop;
						end
						stats1.errors_readdata_o = stats1.errors_readdata_o+1'b1;
						stats1.errors++;	
						$display("[check readdata_o FAILED] @time:%0d dut=%0h, ref=%0h ",errortime_readdata_o_dut_pop
						                                                                ,readdata_o_dut_pop
																						,readdata_o_ref_pop);
					end
				end
				begin
					//If interrupt_o doesn’t assert within 50 cycles, raise error and stop simulation.
					repeat(50) begin
						@(posedge clk);
					end
					if (stats1.errors_interrupt_o == 0) begin
						stats1.errortime_interrupt_o = $time;
						if (stats1.errors == 0) stats1.errortime = $time;
					end
					stats1.errors_interrupt_o = stats1.errors_interrupt_o+1'b1;
					stats1.errors++;
					$display("[check interrupt_o FAILED] @time:%0d dut=%0h, ref=%0h ",$time, 0, 1);
					//if (stats1.errors_done_o == 0) begin
					//	stats1.errortime_done_o = $time;
					//	if (stats1.errors == 0) stats1.errortime = $time;
					//end
					//stats1.errors_done_o = stats1.errors_done_o+1'b1;
					//stats1.errors++;
					//$display("[check done_o FAILED] @time:%0d dut=%0h, ref=%0h ",$time, 0, 1);
					$finish;
				end
				join_any
				disable fork;
			end
		end
	end



	typedef struct packed {
		int errors;
		int errortime;
		int errors_readdata_o;
		int errortime_readdata_o;
		int errors_done_o;
		int errortime_done_o;		
		int errors_interrupt_o;
		int errortime_interrupt_o;								
		int clocks;

	} stats;
	
	stats stats1;
	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;

	// Instantiate the Unit Under Test
	TopModule #(8,7)
	top_module1 (
		.clk(clk), 
		.rst(rst), 
		.load_i({load6_i,load5_i,load4_i,load3_i,load2_i,load1_i,load0_i}), 
		.writedata_i({writedata6_i,writedata5_i,writedata4_i,writedata3_i,writedata2_i,writedata1_i,writedata0_i}), 
		.readdata_o(readdata_o_dut), 
		.start_i(start_i), 
		.done_o(done_o_dut), 
		.interrupt_o(interrupt_o_dut), 
		.abort_i(abort_i)
	);

	// Instantiate the Refmdl
	RefModule #(8,7)
	good1 (
		.clk(clk), 
		.rst(rst), 
		.load_i({load6_i,load5_i,load4_i,load3_i,load2_i,load1_i,load0_i}), 
		.writedata_i({writedata6_i,writedata5_i,writedata4_i,writedata3_i,writedata2_i,writedata1_i,writedata0_i}), 
		.readdata_o(readdata_o_ref), 
		.start_i(start_i), 
		.done_o(done_o_ref), 
		.interrupt_o(interrupt_o_ref), 
		.abort_i(abort_i)
	);

	//yrlu add
	initial begin
    	//$fsdbDumpfile("wave.fsdb");
    	//$fsdbDumpvars(0, tb); 
		$dumpfile("wave.vcd");
		$dumpvars(0, tb);
	end
	// add timeout after 100K cycles
    initial begin
     	#1000000
     	$display("TIMEOUT");
		$finish;
    end

	
	final begin
		if (stats1.errors_readdata_o) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "readdata_o", stats1.errors_readdata_o, stats1.errortime_readdata_o);
		else $display("Hint: Output '%s' has no mismatches.", "readdata_o");
		if (stats1.errors_interrupt_o) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "interrupt_o", stats1.errors_interrupt_o, stats1.errortime_interrupt_o);
		else $display("Hint: Output '%s' has no mismatches.", "interrupt_o");	
		if (stats1.errors_done_o) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "done_o", stats1.errors_done_o, stats1.errortime_done_o);
		else $display("Hint: Output '%s' has no mismatches.", "done_o");
		
		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end

	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { readdata_o_ref,done_o_ref,interrupt_o_ref } === 
		( { readdata_o_ref,done_o_ref,interrupt_o_ref } 
		^ { readdata_o_dut,done_o_dut,interrupt_o_dut } 
		^ { readdata_o_ref,done_o_ref,interrupt_o_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin
		stats1.clocks++;
	end

	always #5 clk=~clk;


	//stimuli generation
	initial begin
		// Initialize Inputs
		clk = 0;
		rst = 1;
		load0_i = 0;
		writedata0_i = 0;
		load1_i = 0;
		writedata1_i = 0;
		load2_i = 0;
		writedata2_i = 0;
		load3_i = 0;
		writedata3_i = 0;
		load4_i = 0;
		writedata4_i = 0;
		load5_i = 0;
		writedata5_i = 0;
		load6_i = 0;
		writedata6_i = 0;
		start_i = 0;
		abort_i = 0;

		repeat(2) @(posedge clk);
        rst <= 0;
		
		@(posedge clk);
        writedata0_i <= 0;
        writedata1_i <= 7;
        writedata2_i <= 100;
        writedata3_i <= 254;
        writedata4_i <= 255;
        writedata5_i <= 128;
        writedata6_i <= 2;

		@(posedge clk);
        load0_i <= 1;
        load1_i <= 1;
        load2_i <= 1;
        load3_i <= 1;
        load4_i <= 1;
        load5_i <= 1;
        load6_i <= 1;

		@(posedge clk);
        writedata0_i <= 0;
        writedata1_i <= 0;
        writedata2_i <= 0;
        writedata3_i <= 0;
        writedata4_i <= 0;
        writedata5_i <= 0;
        writedata6_i <= 0;
        load0_i <= 0;
        load1_i <= 0;
        load2_i <= 0;
        load3_i <= 0;
        load4_i <= 0;
        load5_i <= 0;
        load6_i <= 0;
        start_i <= 1;

        @(posedge clk);
    	start_i <= 0;
        fork
            @(posedge interrupt_o_ref);
		    @(posedge interrupt_o_dut);
        join
        
		repeat(5) @(posedge clk);

		drive_random_data();
		drive_random_data();

		$finish();
	end
endmodule
////////////////////////////////////////////////