module tb;

//declare:
// 1) Inputs & Inouts driven by TB
logic clk;
logic sdram_clk;
logic sdram_clk_d;
logic pad_clk;
logic reset_n;
logic [1:0] sdr_width;
logic [1:0] cfg_colbits;
logic app_req;
logic [25:0] app_req_addr;
logic [8:0] app_req_len;
logic app_req_wrap;
logic app_req_wr_n;
logic [1:0] cfg_req_depth;
logic [31:0] app_wr_data;
logic [3:0] app_wr_en_n;
logic app_req_dma_last;
logic [7:0] pad_sdr_din;
logic cfg_sdr_en;
logic [12:0] cfg_sdr_mode_reg;
logic [3:0] cfg_sdr_tras_d;
logic [3:0] cfg_sdr_trp_d;
logic [3:0] cfg_sdr_trcd_d;
logic [2:0] cfg_sdr_cas;
logic [3:0] cfg_sdr_trcar_d;
logic [3:0] cfg_sdr_twr_d;
logic [11:0] cfg_sdr_rfsh;
logic [2:0] cfg_sdr_rfmax;

// 2) Outputs & Inouts observed from DUT/REF
wire app_req_ack_dut;
wire app_req_ack_ref;
wire app_last_wr_dut;
wire app_last_wr_ref;
wire [31:0] app_rd_data_dut;
wire [31:0] app_rd_data_ref;
wire app_rd_valid_dut;
wire app_rd_valid_ref;
wire app_last_rd_dut;
wire app_last_rd_ref;
wire app_wr_next_req_dut;
wire app_wr_next_req_ref;
wire sdr_init_done_dut;
wire sdr_init_done_ref;
wire sdr_cs_n_dut;
wire sdr_cs_n_ref;
wire sdr_cke_dut;
wire sdr_cke_ref;
wire sdr_ras_n_dut;
wire sdr_ras_n_ref;
wire sdr_cas_n_dut;
wire sdr_cas_n_ref;
wire sdr_we_n_dut;
wire sdr_we_n_ref;
wire [0:0] sdr_dqm_dut;
wire [0:0] sdr_dqm_ref;
wire [1:0] sdr_ba_dut;
wire [1:0] sdr_ba_ref;
wire [12:0] sdr_addr_dut;
wire [12:0] sdr_addr_ref;
wire [7:0] sdr_dout_dut;
wire [7:0] sdr_dout_ref;
wire [0:0] sdr_den_n_dut;
wire [0:0] sdr_den_n_ref;
wire [7:0] Dq_ref;
wire [7:0] Dq_dut;

// 2.1) Output queues and events
logic app_req_ack_ref_q[$];
logic app_req_ack_ref_pop;
logic app_req_ack_dut_q[$];
logic app_req_ack_dut_pop;
event app_req_ack_ref_event;
int errortime_app_req_ack_dut_q[$];
int errortime_app_req_ack_dut_pop;
logic app_last_wr_ref_q[$];
logic app_last_wr_ref_pop;
logic app_last_wr_dut_q[$];
logic app_last_wr_dut_pop;
event app_last_wr_ref_event;
int errortime_app_last_wr_dut_q[$];
int errortime_app_last_wr_dut_pop;
logic [31:0] app_rd_data_ref_q[$];
logic [31:0] app_rd_data_ref_pop;
logic [31:0] app_rd_data_dut_q[$];
logic [31:0] app_rd_data_dut_pop;
event app_rd_data_ref_event;
int errortime_app_rd_data_dut_q[$];
int errortime_app_rd_data_dut_pop;
logic app_rd_valid_ref_q[$];
logic app_rd_valid_ref_pop;
logic app_rd_valid_dut_q[$];
logic app_rd_valid_dut_pop;
event app_rd_valid_ref_event;
int errortime_app_rd_valid_dut_q[$];
int errortime_app_rd_valid_dut_pop;
logic app_last_rd_ref_q[$];
logic app_last_rd_ref_pop;
logic app_last_rd_dut_q[$];
logic app_last_rd_dut_pop;
event app_last_rd_ref_event;
int errortime_app_last_rd_dut_q[$];
int errortime_app_last_rd_dut_pop;
logic app_wr_next_req_ref_q[$];
logic app_wr_next_req_ref_pop;
logic app_wr_next_req_dut_q[$];
logic app_wr_next_req_dut_pop;
event app_wr_next_req_ref_event;
int errortime_app_wr_next_req_dut_q[$];
int errortime_app_wr_next_req_dut_pop;
logic sdr_init_done_ref_q[$];
logic sdr_init_done_ref_pop;
logic sdr_init_done_dut_q[$];
logic sdr_init_done_dut_pop;
event sdr_init_done_ref_event;
int errortime_sdr_init_done_dut_q[$];
int errortime_sdr_init_done_dut_pop;
logic sdr_cs_n_ref_q[$];
logic sdr_cs_n_ref_pop;
logic sdr_cs_n_dut_q[$];
logic sdr_cs_n_dut_pop;
event sdr_cs_n_ref_event;
int errortime_sdr_cs_n_dut_q[$];
int errortime_sdr_cs_n_dut_pop;
logic sdr_cke_ref_q[$];
logic sdr_cke_ref_pop;
logic sdr_cke_dut_q[$];
logic sdr_cke_dut_pop;
event sdr_cke_ref_event;
int errortime_sdr_cke_dut_q[$];
int errortime_sdr_cke_dut_pop;
logic sdr_ras_n_ref_q[$];
logic sdr_ras_n_ref_pop;
logic sdr_ras_n_dut_q[$];
logic sdr_ras_n_dut_pop;
event sdr_ras_n_ref_event;
int errortime_sdr_ras_n_dut_q[$];
int errortime_sdr_ras_n_dut_pop;
logic sdr_cas_n_ref_q[$];
logic sdr_cas_n_ref_pop;
logic sdr_cas_n_dut_q[$];
logic sdr_cas_n_dut_pop;
event sdr_cas_n_ref_event;
int errortime_sdr_cas_n_dut_q[$];
int errortime_sdr_cas_n_dut_pop;
logic sdr_we_n_ref_q[$];
logic sdr_we_n_ref_pop;
logic sdr_we_n_dut_q[$];
logic sdr_we_n_dut_pop;
event sdr_we_n_ref_event;
int errortime_sdr_we_n_dut_q[$];
int errortime_sdr_we_n_dut_pop;
logic [0:0] sdr_dqm_ref_q[$];
logic [0:0] sdr_dqm_ref_pop;
logic [0:0] sdr_dqm_dut_q[$];
logic [0:0] sdr_dqm_dut_pop;
event sdr_dqm_ref_event;
int errortime_sdr_dqm_dut_q[$];
int errortime_sdr_dqm_dut_pop;
logic [1:0] sdr_ba_ref_q[$];
logic [1:0] sdr_ba_ref_pop;
logic [1:0] sdr_ba_dut_q[$];
logic [1:0] sdr_ba_dut_pop;
event sdr_ba_ref_event;
int errortime_sdr_ba_dut_q[$];
int errortime_sdr_ba_dut_pop;
logic [12:0] sdr_addr_ref_q[$];
logic [12:0] sdr_addr_ref_pop;
logic [12:0] sdr_addr_dut_q[$];
logic [12:0] sdr_addr_dut_pop;
event sdr_addr_ref_event;
int errortime_sdr_addr_dut_q[$];
int errortime_sdr_addr_dut_pop;
logic [7:0] sdr_dout_ref_q[$];
logic [7:0] sdr_dout_ref_pop;
logic [7:0] sdr_dout_dut_q[$];
logic [7:0] sdr_dout_dut_pop;
event sdr_dout_ref_event;
int errortime_sdr_dout_dut_q[$];
int errortime_sdr_dout_dut_pop;
logic [0:0] sdr_den_n_ref_q[$];
logic [0:0] sdr_den_n_ref_pop;
logic [0:0] sdr_den_n_dut_q[$];
logic [0:0] sdr_den_n_dut_pop;
event sdr_den_n_ref_event;
int errortime_sdr_den_n_dut_q[$];
int errortime_sdr_den_n_dut_pop;

// 2.2) signal for tb
int test_errors;

int dfifo[$]; // data fifo
int afifo[$]; // address  fifo
int bfifo[$]; // Burst Length fifo

// 2.3) signal for verilogcoder
typedef struct packed {
    int errors;
    int errortime;
    int clocks;

    int errors_app_req_ack;
    int errortime_app_req_ack;
    int errors_app_last_wr;
    int errortime_app_last_wr;
    int errors_app_rd_data;
    int errortime_app_rd_data;
    int errors_app_rd_valid;
    int errortime_app_rd_valid;
    int errors_app_last_rd;
    int errortime_app_last_rd;
    int errors_app_wr_next_req;
    int errortime_app_wr_next_req;
    int errors_sdr_init_done;
    int errortime_sdr_init_done;
    int errors_sdr_cs_n;
    int errortime_sdr_cs_n;
    int errors_sdr_cke;
    int errortime_sdr_cke;
    int errors_sdr_ras_n;
    int errortime_sdr_ras_n;
    int errors_sdr_cas_n;
    int errortime_sdr_cas_n;
    int errors_sdr_we_n;
    int errortime_sdr_we_n;
    int errors_sdr_dqm;
    int errortime_sdr_dqm;
    int errors_sdr_ba;
    int errortime_sdr_ba;
    int errors_sdr_addr;
    int errortime_sdr_addr;
    int errors_sdr_dout;
    int errortime_sdr_dout;
    int errors_sdr_den_n;
    int errortime_sdr_den_n;

} stats;

stats stats1;

//link:
// 3) Instances
TopModule #(.SDR_DW(8),.SDR_BW(1)) dut (
  .clk(clk),
  .pad_clk(pad_clk),
  .reset_n(reset_n),
  .sdr_width(sdr_width),
  .cfg_colbits(cfg_colbits),
  .app_req(app_req),
  .app_req_addr(app_req_addr),
  .app_req_len(app_req_len),
  .app_req_wrap(app_req_wrap),
  .app_req_wr_n(app_req_wr_n),
  .cfg_req_depth(cfg_req_depth),
  .app_wr_data(app_wr_data),
  .app_wr_en_n(app_wr_en_n),
  .app_req_dma_last(app_req_dma_last),
  .pad_sdr_din(Dq_dut),
  .cfg_sdr_en(cfg_sdr_en),
  .cfg_sdr_mode_reg(cfg_sdr_mode_reg),
  .cfg_sdr_tras_d(cfg_sdr_tras_d),
  .cfg_sdr_trp_d(cfg_sdr_trp_d),
  .cfg_sdr_trcd_d(cfg_sdr_trcd_d),
  .cfg_sdr_cas(cfg_sdr_cas),
  .cfg_sdr_trcar_d(cfg_sdr_trcar_d),
  .cfg_sdr_twr_d(cfg_sdr_twr_d),
  .cfg_sdr_rfsh(cfg_sdr_rfsh),
  .cfg_sdr_rfmax(cfg_sdr_rfmax),
  .app_req_ack(app_req_ack_dut),
  .app_last_wr(app_last_wr_dut),
  .app_rd_data(app_rd_data_dut),
  .app_rd_valid(app_rd_valid_dut),
  .app_last_rd(app_last_rd_dut),
  .app_wr_next_req(app_wr_next_req_dut),
  .sdr_init_done(sdr_init_done_dut),
  .sdr_cs_n(sdr_cs_n_dut),
  .sdr_cke(sdr_cke_dut),
  .sdr_ras_n(sdr_ras_n_dut),
  .sdr_cas_n(sdr_cas_n_dut),
  .sdr_we_n(sdr_we_n_dut),
  .sdr_dqm(sdr_dqm_dut),
  .sdr_ba(sdr_ba_dut),
  .sdr_addr(sdr_addr_dut),
  .sdr_dout(sdr_dout_dut),
  .sdr_den_n(sdr_den_n_dut)
);

assign Dq_dut[7:0]  = (sdr_den_n_dut[0] == 1'b0) ? sdr_dout_dut[7:0]  : 8'hZZ;
mt48lc8m8a2_dut #(.data_bits(8)) u_sdram8_dut (
          .Dq                 (Dq_dut                 ) , 
          .Addr               (sdr_addr_dut[11:0]     ), 
          .Ba                 (sdr_ba_dut             ), 
          .Clk                (sdram_clk_d            ), 
          .Cke                (sdr_cke_dut            ), 
          .Cs_n               (sdr_cs_n_dut           ), 
          .Ras_n              (sdr_ras_n_dut          ), 
          .Cas_n              (sdr_cas_n_dut          ), 
          .We_n               (sdr_we_n_dut           ), 
          .Dqm                (sdr_dqm_dut            )
);

RefModule #(.SDR_DW(8),.SDR_BW(1)) ref_mdl (
  .clk(clk),
  .pad_clk(pad_clk),
  .reset_n(reset_n),
  .sdr_width(sdr_width),
  .cfg_colbits(cfg_colbits),
  .app_req(app_req),
  .app_req_addr(app_req_addr),
  .app_req_len(app_req_len),
  .app_req_wrap(app_req_wrap),
  .app_req_wr_n(app_req_wr_n),
  .cfg_req_depth(cfg_req_depth),
  .app_wr_data(app_wr_data),
  .app_wr_en_n(app_wr_en_n),
  .app_req_dma_last(app_req_dma_last),
  .pad_sdr_din(Dq_ref),
  .cfg_sdr_en(cfg_sdr_en),
  .cfg_sdr_mode_reg(cfg_sdr_mode_reg),
  .cfg_sdr_tras_d(cfg_sdr_tras_d),
  .cfg_sdr_trp_d(cfg_sdr_trp_d),
  .cfg_sdr_trcd_d(cfg_sdr_trcd_d),
  .cfg_sdr_cas(cfg_sdr_cas),
  .cfg_sdr_trcar_d(cfg_sdr_trcar_d),
  .cfg_sdr_twr_d(cfg_sdr_twr_d),
  .cfg_sdr_rfsh(cfg_sdr_rfsh),
  .cfg_sdr_rfmax(cfg_sdr_rfmax),
  .app_req_ack(app_req_ack_ref),
  .app_last_wr(app_last_wr_ref),
  .app_rd_data(app_rd_data_ref),
  .app_rd_valid(app_rd_valid_ref),
  .app_last_rd(app_last_rd_ref),
  .app_wr_next_req(app_wr_next_req_ref),
  .sdr_init_done(sdr_init_done_ref),
  .sdr_cs_n(sdr_cs_n_ref),
  .sdr_cke(sdr_cke_ref),
  .sdr_ras_n(sdr_ras_n_ref),
  .sdr_cas_n(sdr_cas_n_ref),
  .sdr_we_n(sdr_we_n_ref),
  .sdr_dqm(sdr_dqm_ref),
  .sdr_ba(sdr_ba_ref),
  .sdr_addr(sdr_addr_ref),
  .sdr_dout(sdr_dout_ref),
  .sdr_den_n(sdr_den_n_ref)
);

assign Dq_ref[7:0]  = (sdr_den_n_ref[0] == 1'b0) ? sdr_dout_ref[7:0]  : 8'hZZ;
mt48lc8m8a2_ref #(.data_bits(8)) u_sdram8_ref (
          .Dq                 (Dq_ref                 ) , 
          .Addr               (sdr_addr_ref[11:0]     ), 
          .Ba                 (sdr_ba_ref             ), 
          .Clk                (sdram_clk_d            ), 
          .Cke                (sdr_cke_ref            ), 
          .Cs_n               (sdr_cs_n_ref           ), 
          .Ras_n              (sdr_ras_n_ref          ), 
          .Cas_n              (sdr_cas_n_ref          ), 
          .We_n               (sdr_we_n_ref           ), 
          .Dqm                (sdr_dqm_ref            )
);


task monitor_dut;
  fork
    // Monitor application read data: valid gated by app_rd_valid_dut
    begin
      forever begin
        @(posedge clk);
        if (app_rd_valid_dut) begin
          app_rd_data_dut_q.push_back(app_rd_data_dut);
          errortime_app_rd_data_dut_q.push_back($time);
        end
      end
    end
  join
endtask

task monitor_ref;
  fork
    // Monitor application read data: valid gated by app_rd_valid_ref
    begin
      forever begin
        @(posedge clk);
        if (app_rd_valid_ref) begin
          app_rd_data_ref_q.push_back(app_rd_data_ref);
          -> app_rd_data_ref_event;
        end
      end
    end
  join
endtask

// Auto-generated checker tasks (inline)
// Notes:
//  - Assumes external declarations of queues/events/vars: *_ref_q, *_dut_q, *_ref_event, *_ref_pop, *_dut_pop, errors.
//  - One checker task per data base name.


// === Auto-generated checker for app_rd_data ===
task checker_app_rd_data;
    realtime t1, t2, ref_time;
    t1 = $realtime;
    //$display("@%0d,waiting app_rd_data_ref_event", $time);
    @(app_rd_data_ref_event);
    t2 = $realtime;
    ref_time = t2 - t1;
    //$display("@%0d,wait app_rd_data_ref_event done", $time);
    if (app_rd_data_dut_q.size() > 0) begin
        app_rd_data_ref_pop = app_rd_data_ref_q.pop_front();
        app_rd_data_dut_pop = app_rd_data_dut_q.pop_front();
        errortime_app_rd_data_dut_pop = errortime_app_rd_data_dut_q.pop_front();
        if (app_rd_data_ref_pop == app_rd_data_dut_pop) begin
            $display("[check app_rd_data passed] @time:%0t dut=%0h, ref=%0h ",
                     $time, app_rd_data_dut_pop, app_rd_data_ref_pop);
        end
        else begin
            if (stats1.errors_app_rd_data == 0) begin
                stats1.errortime_app_rd_data = errortime_app_rd_data_dut_pop;
                if (stats1.errors == 0) stats1.errortime = errortime_app_rd_data_dut_pop;
            end
            stats1.errors_app_rd_data++;
            stats1.errors++;
            test_errors++;
            $display("[check app_rd_data FAILED] @time:%0t dut=%0h, ref=%0h ",
                     $time, app_rd_data_dut_pop, app_rd_data_ref_pop);
        end
    end
    else begin
        fork
            begin
                wait (app_rd_data_dut_q.size() > 0);
                app_rd_data_ref_pop = app_rd_data_ref_q.pop_front();
                app_rd_data_dut_pop = app_rd_data_dut_q.pop_front();
                errortime_app_rd_data_dut_pop = errortime_app_rd_data_dut_q.pop_front();
                if (app_rd_data_ref_pop == app_rd_data_dut_pop) begin
                    //$display("[check app_rd_data passed] @time:%0t dut=%0h, ref=%0h ",
                    //         $time, app_rd_data_dut_pop, app_rd_data_ref_pop);
                end
                else begin
                    if (stats1.errors_app_rd_data == 0) begin
                        stats1.errortime_app_rd_data = errortime_app_rd_data_dut_pop;
                        if (stats1.errors == 0) stats1.errortime = errortime_app_rd_data_dut_pop;
                    end
                    stats1.errors_app_rd_data++;
                    stats1.errors++;
                    test_errors++;
                    $display("[check app_rd_data FAILED] @time:%0t dut=%0h, ref=%0h ",
                             $time, app_rd_data_dut_pop, app_rd_data_ref_pop);
                end
            end
            begin
                #(ref_time);
                test_errors++;
                $display("[check output protocol FAILED] @time:%0d dut=%0h, ref=%0h ",
                         $time, 0, 1);
                $finish;
            end
        join_any
        disable fork;
    end
endtask

// === Auto-generated checker for sdr_dout ===
task checker_sdr_dout;
    realtime t1, t2, ref_time;
    t1 = $realtime;
    //$display("@%0d,waiting sdr_dout_ref_event", $time);
    @(sdr_dout_ref_event);
    t2 = $realtime;
    ref_time = t2 - t1;
    //$display("@%0d,wait sdr_dout_ref_event done", $time);
    if (sdr_dout_dut_q.size() > 0) begin
        sdr_dout_ref_pop = sdr_dout_ref_q.pop_front();
        sdr_dout_dut_pop = sdr_dout_dut_q.pop_front();
        errortime_sdr_dout_dut_pop = errortime_sdr_dout_dut_q.pop_front();
        if (sdr_dout_ref_pop == sdr_dout_dut_pop) begin
            //$display("[check sdr_dout passed] @time:%0t dut=%0h, ref=%0h ",
            //         $time, sdr_dout_dut_pop, sdr_dout_ref_pop);
        end
        else begin
            if (stats1.errors_sdr_dout == 0) begin
                stats1.errortime_sdr_dout = errortime_sdr_dout_dut_pop;
                if (stats1.errors == 0) stats1.errortime = errortime_sdr_dout_dut_pop;
            end
            stats1.errors_sdr_dout++;
            stats1.errors++;
            test_errors++;
            $display("[check sdr_dout FAILED] @time:%0t dut=%0h, ref=%0h ",
                     $time, sdr_dout_dut_pop, sdr_dout_ref_pop);
        end
    end
    else begin
        fork
            begin
                wait (sdr_dout_dut_q.size() > 0);
                sdr_dout_ref_pop = sdr_dout_ref_q.pop_front();
                sdr_dout_dut_pop = sdr_dout_dut_q.pop_front();
                errortime_sdr_dout_dut_pop = errortime_sdr_dout_dut_q.pop_front();
                if (sdr_dout_ref_pop == sdr_dout_dut_pop) begin
                    //$display("[check sdr_dout passed] @time:%0t dut=%0h, ref=%0h ",
                    //         $time, sdr_dout_dut_pop, sdr_dout_ref_pop);
                end
                else begin
                    if (stats1.errors_sdr_dout == 0) begin
                        stats1.errortime_sdr_dout = errortime_sdr_dout_dut_pop;
                        if (stats1.errors == 0) stats1.errortime = errortime_sdr_dout_dut_pop;
                    end
                    stats1.errors_sdr_dout++;
                    stats1.errors++;
                    test_errors++;
                    $display("[check sdr_dout FAILED] @time:%0t dut=%0h, ref=%0h ",
                             $time, sdr_dout_dut_pop, sdr_dout_ref_pop);
                end
            end
            begin
                #(ref_time);
                test_errors++;
                stats1.errors++;
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
  // assert reset (active low)
  reset_n = 1'b0;

  // initialize inputs to inactive defaults
  sdram_clk=0;
  sdram_clk_d=0;
  pad_clk=0;
  clk=0;
  reset_n=0;
  sdr_width=2'd2;
  cfg_colbits=0;
  app_req=0;
  app_req_addr=0;
  app_req_len=0;
  app_req_wrap=0;
  app_req_wr_n=0;
  app_wr_data=0;
  app_wr_en_n=4'hF;
  app_req_dma_last=0;
  pad_sdr_din=0;
  cfg_req_depth      =2'h3      ;	
  cfg_sdr_en         =1'b1      ;
  cfg_sdr_mode_reg   =13'h033   ;
  cfg_sdr_tras_d     =4'h4      ;
  cfg_sdr_trp_d      =4'h2      ;
  cfg_sdr_trcd_d     =4'h2      ;
  cfg_sdr_cas        =3'h3      ;
  cfg_sdr_trcar_d    =4'h7      ;
  cfg_sdr_twr_d      =4'h1      ;
  cfg_sdr_rfsh       =12'h100   ; 
  cfg_sdr_rfmax      =3'h6      ;

  // hold reset
  #100;

  // deassert reset
  reset_n = 1'b1;
end
endtask

always@(*) clk = sdram_clk;
always@(*) sdram_clk_d = #(2.0) sdram_clk;
always@(*) pad_clk = #(1.0) sdram_clk_d;

task drive_clk;
begin
  sdram_clk = 1'b0;
  fork
    forever begin
      #5 sdram_clk = ~sdram_clk;
    end
  join_none
end
endtask

// ===== Stimuli from: /mnt/e/Yuren/Researsh/project/opencores_downloads/downloads/sdr_ctrl/sdr_ctrl/trunk/verif/tb/tb_top.sv =====
task drive_stimuli_1;
  burst_write(32'h4_0000,8'h4);  
 #1000;
  burst_read();  
endtask

task drive_stimuli_2;
  burst_write(32'h4_0000,8'h4);  
  burst_read();  
  burst_write(32'h0040_0000,8'h5);  
  burst_read();  
endtask

task drive_stimuli_3;
  burst_write(32'h0000_0FF0,8'h8);  
  burst_write(32'h0001_0FF4,8'hF);  
  burst_write(32'h0002_0FF8,8'hF);  
  burst_write(32'h0003_0FFC,8'hF);  
  burst_write(32'h0004_0FE0,8'hF);  
  burst_write(32'h0005_0FE4,8'hF);  
  burst_write(32'h0006_0FE8,8'hF);  
  burst_write(32'h0007_0FEC,8'hF);  
  burst_write(32'h0008_0FD0,8'hF);  
  burst_write(32'h0009_0FD4,8'hF);  
  burst_write(32'h000A_0FD8,8'hF);  
  burst_write(32'h000B_0FDC,8'hF);  
  burst_write(32'h000C_0FC0,8'hF);  
  burst_write(32'h000D_0FC4,8'hF);  
  burst_write(32'h000E_0FC8,8'hF);  
  burst_write(32'h000F_0FCC,8'hF);  
  burst_write(32'h0010_0FB0,8'hF);  
  burst_write(32'h0011_0FB4,8'hF);  
  burst_write(32'h0012_0FB8,8'hF);  
  burst_write(32'h0013_0FBC,8'hF);  
  burst_write(32'h0014_0FA0,8'hF);  
  burst_write(32'h0015_0FA4,8'hF);  
  burst_write(32'h0016_0FA8,8'hF);  
  burst_write(32'h0017_0FAC,8'hF);  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
endtask

task drive_stimuli_4;
  burst_write(32'h4_0000,8'h4);  
  burst_write(32'h5_0000,8'h5);  
  burst_write(32'h6_0000,8'h6);  
  burst_write(32'h7_0000,8'h7);  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
endtask

task drive_stimuli_5;
  burst_write({12'h000,2'b00,8'h00,2'b00},8'h4);   // Row: 0 Bank : 0
  burst_write({12'h000,2'b01,8'h00,2'b00},8'h5);   // Row: 0 Bank : 1
  burst_write({12'h000,2'b10,8'h00,2'b00},8'h6);   // Row: 0 Bank : 2
  burst_write({12'h000,2'b11,8'h00,2'b00},8'h7);   // Row: 0 Bank : 3
  burst_write({12'h001,2'b00,8'h00,2'b00},8'h4);   // Row: 1 Bank : 0
  burst_write({12'h001,2'b01,8'h00,2'b00},8'h5);   // Row: 1 Bank : 1
  burst_write({12'h001,2'b10,8'h00,2'b00},8'h6);   // Row: 1 Bank : 2
  burst_write({12'h001,2'b11,8'h00,2'b00},8'h7);   // Row: 1 Bank : 3
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  

  burst_write({12'h002,2'b00,8'h00,2'b00},8'h4);   // Row: 2 Bank : 0
  burst_write({12'h002,2'b01,8'h00,2'b00},8'h5);   // Row: 2 Bank : 1
  burst_write({12'h002,2'b10,8'h00,2'b00},8'h6);   // Row: 2 Bank : 2
  burst_write({12'h002,2'b11,8'h00,2'b00},8'h7);   // Row: 2 Bank : 3
  burst_write({12'h003,2'b00,8'h00,2'b00},8'h4);   // Row: 3 Bank : 0
  burst_write({12'h003,2'b01,8'h00,2'b00},8'h5);   // Row: 3 Bank : 1
  burst_write({12'h003,2'b10,8'h00,2'b00},8'h6);   // Row: 3 Bank : 2
  burst_write({12'h003,2'b11,8'h00,2'b00},8'h7);   // Row: 3 Bank : 3

  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  


  burst_write({12'h002,2'b00,8'h00,2'b00},8'h4);   // Row: 2 Bank : 0
  burst_write({12'h002,2'b01,8'h01,2'b00},8'h5);   // Row: 2 Bank : 1
  burst_write({12'h002,2'b10,8'h02,2'b00},8'h6);   // Row: 2 Bank : 2
  burst_write({12'h002,2'b11,8'h03,2'b00},8'h7);   // Row: 2 Bank : 3
  burst_write({12'h003,2'b00,8'h04,2'b00},8'h4);   // Row: 3 Bank : 0
  burst_write({12'h003,2'b01,8'h05,2'b00},8'h5);   // Row: 3 Bank : 1
  burst_write({12'h003,2'b10,8'h06,2'b00},8'h6);   // Row: 3 Bank : 2
  burst_write({12'h003,2'b11,8'h07,2'b00},8'h7);   // Row: 3 Bank : 3

  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
  burst_read();  
endtask

task burst_write;
input [31:0] Address;
input [7:0]  bl;
int i;
begin
  afifo.push_back(Address);
  bfifo.push_back(bl);

   @ (negedge sdram_clk);
   app_req        = 1;
   app_wr_en_n    = 0;
   app_req_wr_n   = 1'b0;
   app_req_addr   = Address[31:2];
   app_req_len    = bl;
   $display("Write Address: %x, Burst Size: %d",Address,bl);

   // wait for app_req_ack == 1
   do begin
       @ (posedge sdram_clk);
   end while(app_req_ack_ref == 1'b0);
   @ (negedge sdram_clk);
   app_req           = 0;

   for(i=0; i < bl; i++) begin
      app_wr_data        = $random & 32'hFFFFFFFF;
      dfifo.push_back(app_wr_data);

      do begin
          @ (posedge sdram_clk);
      end while(app_wr_next_req_ref == 1'b0);
          @ (negedge sdram_clk);
   
       $display("Status: Burst-No: %d  Write Address: %x  WriteData: %x ",i,Address,app_wr_data);
   end
   app_req        = 0;
   app_wr_en_n    = 'hx;
   app_req_wr_n   = 'hx;
   app_req_addr   = 'hx;
   app_req_len    = 'hx;


end
endtask

task burst_read;
reg [31:0] Address;
reg [7:0]  bl;

int i,j;
reg [31:0]   exp_data;
begin
  
   Address = afifo.pop_front(); 
   bl      = bfifo.pop_front(); 

   @ (negedge sdram_clk);
   app_req        = 1;
   app_wr_en_n    = 0;
   app_req_wr_n   = 1;
   app_req_addr   = Address[29:2];
   app_req_len    = bl;

      // wait for app_req_ack == 1
      do begin
          @ (posedge sdram_clk);
      end while(app_req_ack_ref == 1'b0);
      @ (negedge sdram_clk);
      app_req        = 0;
      app_wr_en_n    = 'hx;
      app_req_wr_n   = 'hx;
      app_req_addr   = 'hx;
      app_req_len    = 'hx;

      for(j=0; j < bl; j++) begin
         wait(app_rd_valid_ref == 1);
         exp_data        = dfifo.pop_front(); // Exptected Read Data
         //if(app_rd_data !== exp_data) begin
         //    $display("READ ERROR: Burst-No: %d Addr: %x Rxp: %x Exd: %x",j,Address+(j*2),app_rd_data,exp_data);
         //    ErrCnt = ErrCnt+1;
         //end else begin
         //    $display("READ STATUS: Burst-No: %d Addr: %x Rxd: %x",j,Address+(j*2),app_rd_data);
         //end 
         @ (posedge sdram_clk);
         @ (negedge sdram_clk);
      end
end
endtask

  // Clock generator
  initial begin
     drive_clk();
  end

  // Main test sequence
  initial begin
     drive_rst();
     fork
        begin
           drive_stimuli_1();
           drive_stimuli_2();
           drive_stimuli_3();
           drive_stimuli_4();
           drive_stimuli_5();
        end
        begin
          //1
           repeat (4) begin
              checker_app_rd_data();
           end
           //2
           repeat (9) begin
              checker_app_rd_data();
           end
           //3
           repeat (353) begin
              checker_app_rd_data();
           end
           //4
           repeat (22) begin
              checker_app_rd_data();
           end
           //5
           repeat (132) begin
              checker_app_rd_data();
           end
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

  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb);
  end 

  // Watchdog for timeout protection
  initial begin
     repeat(100000)
         @(posedge clk);
     $display("ERROR, watchdog fail");
     $finish();
  end
  always @(posedge clk, negedge clk) begin
     stats1.clocks++;
  end

  // Statistics summary (verilogcoder)
  final begin
    if (stats1.errors_app_req_ack)
      $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "app_req_ack", stats1.errors_app_req_ack, stats1.errortime_app_req_ack);
    else
      $display("Hint: Output app_req_ack has no mismatches.");
    if (stats1.errors_app_last_wr)
      $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "app_last_wr", stats1.errors_app_last_wr, stats1.errortime_app_last_wr);
    else
      $display("Hint: Output app_last_wr has no mismatches.");
    if (stats1.errors_app_rd_data)
      $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "app_rd_data", stats1.errors_app_rd_data, stats1.errortime_app_rd_data);
    else
      $display("Hint: Output app_rd_data has no mismatches.");
    if (stats1.errors_app_rd_valid)
      $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "app_rd_valid", stats1.errors_app_rd_valid, stats1.errortime_app_rd_valid);
    else
      $display("Hint: Output app_rd_valid has no mismatches.");
    if (stats1.errors_app_last_rd)
      $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "app_last_rd", stats1.errors_app_last_rd, stats1.errortime_app_last_rd);
    else
      $display("Hint: Output app_last_rd has no mismatches.");
    if (stats1.errors_app_wr_next_req)
      $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "app_wr_next_req", stats1.errors_app_wr_next_req, stats1.errortime_app_wr_next_req);
    else
      $display("Hint: Output app_wr_next_req has no mismatches.");
    if (stats1.errors_sdr_init_done)
      $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "sdr_init_done", stats1.errors_sdr_init_done, stats1.errortime_sdr_init_done);
    else
      $display("Hint: Output sdr_init_done has no mismatches.");
    if (stats1.errors_sdr_cs_n)
      $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "sdr_cs_n", stats1.errors_sdr_cs_n, stats1.errortime_sdr_cs_n);
    else
      $display("Hint: Output sdr_cs_n has no mismatches.");
    if (stats1.errors_sdr_cke)
      $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "sdr_cke", stats1.errors_sdr_cke, stats1.errortime_sdr_cke);
    else
      $display("Hint: Output sdr_cke has no mismatches.");
    if (stats1.errors_sdr_ras_n)
      $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "sdr_ras_n", stats1.errors_sdr_ras_n, stats1.errortime_sdr_ras_n);
    else
      $display("Hint: Output sdr_ras_n has no mismatches.");
    if (stats1.errors_sdr_cas_n)
      $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "sdr_cas_n", stats1.errors_sdr_cas_n, stats1.errortime_sdr_cas_n);
    else
      $display("Hint: Output sdr_cas_n has no mismatches.");
    if (stats1.errors_sdr_we_n)
      $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "sdr_we_n", stats1.errors_sdr_we_n, stats1.errortime_sdr_we_n);
    else
      $display("Hint: Output sdr_we_n has no mismatches.");
    if (stats1.errors_sdr_dqm)
      $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "sdr_dqm", stats1.errors_sdr_dqm, stats1.errortime_sdr_dqm);
    else
      $display("Hint: Output sdr_dqm has no mismatches.");
    if (stats1.errors_sdr_ba)
      $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "sdr_ba", stats1.errors_sdr_ba, stats1.errortime_sdr_ba);
    else
      $display("Hint: Output sdr_ba has no mismatches.");
    if (stats1.errors_sdr_addr)
      $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "sdr_addr", stats1.errors_sdr_addr, stats1.errortime_sdr_addr);
    else
      $display("Hint: Output sdr_addr has no mismatches.");
    if (stats1.errors_sdr_dout)
      $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "sdr_dout", stats1.errors_sdr_dout, stats1.errortime_sdr_dout);
    else
      $display("Hint: Output sdr_dout has no mismatches.");
    if (stats1.errors_sdr_den_n)
      $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "sdr_den_n", stats1.errors_sdr_den_n, stats1.errortime_sdr_den_n);
    else
      $display("Hint: Output sdr_den_n has no mismatches.");

    $display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
    $display("Simulation finished at %0d ps", $time);
    $display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
  end

endmodule
