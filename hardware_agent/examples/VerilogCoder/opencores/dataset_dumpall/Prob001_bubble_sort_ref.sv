module bitsplit_ref(
    input   clk,
    input   bit1_i,
    input   bit2_i,
    output  largebit_o,
    output  smallbit_o,
    input   swap_i,
    output  swap_o,
    input   run_i,
    output  run_o
    );

    reg     r_bit1;
    reg     r_bit2;
    reg     r_small_bit;
    reg     r_large_bit;
    reg     r_compare_result;
    reg     r_freeze_compare;
    reg [0:1]   r_swap;
    reg [0:1]   r_run;

    wire    w_different_bits;

    always @(posedge clk)
        begin
            if (~run_i) begin
                r_freeze_compare <= 0;      end
            else if (w_different_bits) begin
                r_freeze_compare <= 1;      end
        end
        
    always @(posedge clk)
        begin
            if (~run_i) begin
                r_compare_result <= 0;      end
            else if (~r_freeze_compare) begin
                if (bit1_i & ~bit2_i)   begin
                    r_compare_result <= 1;  end
                else begin
                    r_compare_result <= 0;  end                
                end
        end

    always @(posedge clk)
        begin
            r_bit1 <= bit1_i;
            r_bit2 <= bit2_i;
            if (~r_compare_result) begin
                r_small_bit <= r_bit1;
                r_large_bit <= r_bit2;   end
            else begin
                r_small_bit <= r_bit2;
                r_large_bit <= r_bit1;   end
        end
        
    always @(posedge clk)
        begin
            r_swap[0] <= swap_i;
            r_swap[1] <= r_swap[0] | r_compare_result;
        end

    always @(posedge clk)
        begin
            r_run[0] <= run_i;
            r_run[1] <= r_run[0];
        end
        
    assign w_different_bits = bit1_i ^ bit2_i;

    assign largebit_o = r_large_bit;
    assign smallbit_o = r_small_bit;
    assign swap_o = r_swap[1];
    assign run_o = r_run[1];
    
endmodule


module intgenerator_ref #(parameter N_BITS=8, parameter K_NUMBERS=8)
    (
    input   clk,
    input   rst,
    input   run_i,
    input   swap_i,
    output  done_o,
    output  interrupt_o
    );

    parameter P_PULSES = (2*(K_NUMBERS+11))/(N_BITS+4);
    parameter P_WIDTH = $clog2(P_PULSES)+1;
    
    reg     r_run_delay;
    reg     r_swap_delay;
    reg [P_WIDTH:0]   r_pulses;
    reg     r_done;
    
    wire    w_falling_run; 
    always @(posedge clk)
        begin
            if (rst) begin
                r_run_delay <= 1'b0;
                r_swap_delay <= 1'b0;    end
            else begin
                r_run_delay <= run_i;
                r_swap_delay <= swap_i;  end            
        end
        
    always @(posedge clk) 
        begin
            if (rst || (r_pulses[P_WIDTH])) begin
                r_pulses <= P_PULSES - 1;            end
            else if (w_falling_run) begin
                if (~r_swap_delay) begin
                    r_pulses <= r_pulses - 1;        end
                else begin
                    r_pulses <= P_PULSES - 1;        end
                end
        end
    
    always @(posedge clk) 
        begin
            /*if (rst) begin
                r_done <= 1'b0;                      end
            else*/ if (w_falling_run & (~r_swap_delay)) begin
                r_done <= 1'b1;                      end
            else begin
                r_done <= 1'b0;                      end
        end
    
    assign w_falling_run = (~run_i) & r_run_delay;

    assign done_o = r_done;
    assign interrupt_o = r_pulses[P_WIDTH];
        
endmodule

module rungenerator_ref #(parameter N_BITS=8)
    (
    input   clk,
    input   rst,
    input   start_i,
    input   all_sorted_i,
    output  run_o
    );

    reg [N_BITS+4-1:0]  r_count;
    reg     r_job_done;
    
    wire    w_ready_to_stop;
    wire    w_next_bit;
    
    always @(posedge clk)
        begin
            if (rst) begin
                r_count <= {{N_BITS{1'd0}},4'b0000};             end
            else if(start_i) begin
                r_count <= {{N_BITS{1'd1}},4'b0000};             end
            else  begin
                r_count <= {r_count[N_BITS+4-2:0],w_next_bit};   end
        end
        
    always @(posedge clk)
        begin
            if (rst) begin
                r_job_done <= 1'b1;          end
            else if (all_sorted_i) begin
                r_job_done <= 1'b1;          end            
            else if (start_i) begin
                r_job_done <= 1'b0;          end            
        end
    
    assign w_ready_to_stop = ~r_count[0];
    assign w_next_bit = (r_job_done & w_ready_to_stop) ? 1'b0 : r_count[N_BITS+4-1];
    
    assign run_o = r_count[0];
    
endmodule

module stageen_ref #(parameter N_BITS=8)
(
    input   clk,
    input   load,
    input  [N_BITS-1:0] data_i,
    output [N_BITS-1:0] data_o,
    input   swap_i,
    output  swap_o,
    input   run_i,
    input   run_late_i,
    output  run_o,
    input   bit_i,
    output  bit_o,
    input   value_i,
    output  value_o
    );

    reg[N_BITS-1:0]    r_data;
    
    wire    w_large_bit;
    wire    w_small_bit;
    wire    w_swap_o;
    wire    w_run_o;
    
    always @(posedge clk)
        begin
            if (load) begin
                r_data <= data_i;                        end
            else if (run_i | run_late_i) begin
                r_data <= {r_data[N_BITS-2:0],value_i};  end
        end
        
    bitsplit_ref split_module (
        .clk(clk),
        .bit1_i(bit_i),
        .bit2_i(r_data[N_BITS-1]),
        .largebit_o(w_large_bit),
        .smallbit_o(w_small_bit),
        .swap_i(swap_i),
        .swap_o(w_swap_o),
        .run_i(run_i),
        .run_o(w_run_o)
        );
    
    assign data_o = r_data;
    assign swap_o = w_swap_o;
    assign run_o = w_run_o;
    assign bit_o = w_large_bit;
    assign value_o = w_small_bit;
    
endmodule

module RefModule #(parameter N_BITS = 8, parameter K_NUMBERS =49)
    (
    input   clk,
    input   rst,
    input   [K_NUMBERS-1:0] load_i, 
    input   [K_NUMBERS*N_BITS-1:0] writedata_i,
    output  [K_NUMBERS*N_BITS-1:0] readdata_o,
    input   start_i,
    output  done_o,
    output  interrupt_o,
    input   abort_i
    );
    
    genvar     i;
    
    reg [0:1]   r_value_66;
    reg [0:1]   r_run_late_66;
    
    wire w_runback;
    wire w_swapback;
    wire w_done;
    wire w_interrupt;
    wire [K_NUMBERS+1:0]    w_run_up;
    wire [K_NUMBERS:0]      w_swap_up;
    wire [K_NUMBERS:0]      w_bit_up;
    wire [K_NUMBERS:0]      w_value_down;
    wire w_run;
    
    rungenerator_ref #(.N_BITS(N_BITS))
    run_module (
        .clk(clk),
        .rst(rst),
        .start_i(start_i),
        .all_sorted_i(w_done),
        .run_o(w_run)
    );

    intgenerator_ref #(.N_BITS(N_BITS),.K_NUMBERS(K_NUMBERS))
    interrupt_module (
        .clk(clk),
        .rst(rst),
        .run_i(w_runback),
        .swap_i(w_swapback),
        .done_o(w_done),
        .interrupt_o(w_interrupt)
    );

generate
    for (i=0; i < K_NUMBERS; i=i+1) begin : STAGEN
        stageen_ref #(.N_BITS(N_BITS))
        stage (
            .clk(clk),
            .load(load_i[i]),
            .data_i(writedata_i[(i+1)*N_BITS-1:(i+0)*N_BITS]),
            .data_o(readdata_o[(i+1)*N_BITS-1:(i+0)*N_BITS]),
            .swap_i(w_swap_up[i]),
            .swap_o(w_swap_up[i+1]),
            .run_i(w_run_up[i]),
            .run_late_i(w_run_up[i+2]),
            .run_o(w_run_up[i+1]),
            .bit_i(w_bit_up[i]),
            .bit_o(w_bit_up[i+1]),
            .value_i(w_value_down[i+1]),
            .value_o(w_value_down[i])
        );
    end
endgenerate
    
    always @(posedge clk)
        begin
            r_value_66[0] <= w_bit_up[K_NUMBERS];
            r_value_66[1] <= r_value_66[0];
        end

    always @(posedge clk)
        begin
            r_run_late_66[0] <= w_runback;
            r_run_late_66[1] <= r_run_late_66[0];
        end
        
    assign w_value_down[K_NUMBERS] = r_value_66[1];
    assign w_run_up[K_NUMBERS+1] = r_run_late_66[1];
    assign w_swap_up[0] = 1'b0;
    assign w_bit_up[0] = 1'b0;
    assign w_runback = w_run_up[K_NUMBERS];
    assign w_run_up[0] = w_run;
    assign w_swapback = w_swap_up[K_NUMBERS];
    
    assign done_o = w_done;
    assign interrupt_o = w_interrupt;
        
endmodule
