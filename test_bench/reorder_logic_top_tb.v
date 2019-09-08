/*
 *  File:                   reorder_logic_top_tb.v
 *  Description:            Test bench for the re-order logic module
 *  Project:                Re-Order Logic
 *  Author:                 Abraham J. Ruiz R. (https://github.com/m4j0rt0m)
 *  Revision:               0.1 - First version
 */
module reorder_logic_top_tb ();

  /* local parameters */
  localparam  DEBUG_PRINT     = 0;                      //..enable display simulation messages
  localparam  RUN_CYCLES      = 20000000;               //..number of cycles per simulation
  localparam  FREQ_CLK        = 50;                     //..MHz
  localparam  CLK_F           = (1000 / FREQ_CLK) / 2;  //..ns
  localparam  NUM_QUEUES      = 8;                      //..number of queues to reorder
  localparam  DEPTH           = 64;                      //..entries depth
  localparam  BREAKPOINT      = 1'b1;                   //..trace breakpoint value
  localparam  ID_WIDTH        = $clog2(DEPTH);          //..ID width
  localparam  SEL_WIDTH       = $clog2(NUM_QUEUES);     //..queue selector width
  localparam  MAX_SIM_LATENCY = 20;                     //..maximum execution latency for every queue entry
  localparam  MAX_GEN_ENTRIES = 8;                      //..maximum number of generated entries per ID
  localparam  MAX_DEADLOCK    = 2000;                   //..maximum of waiting cycles

  /* defines */
  `define CYCLES(cycles)  (CLK_F*2*cycles)

  /* dut regs and wires */
  reg                     clk_i;                //..clock signal
  reg                     arsn_i;               //..active low reset
  wire                    full_o;               //..full entries
  reg                     trace_id_push_i;      //..push a new id entry
  reg   [ID_WIDTH-1:0]    trace_id_value_i;     //..new id for trace in queue
  reg                     trace_push_i;         //..push a new entry in the trace buffer
  reg   [SEL_WIDTH-1:0]   trace_sel_i;          //..new queue selector in trace buffer entry (will wait for that queue)
  reg                     trace_break_i;        //..breakpoint entry of trace
  reg                     trace_update_i;       //..reupdate end of trace (due to next invalid entry)
  wire  [NUM_QUEUES-1:0]  queues_status_push_i; //..push a new status in N queue
  reg                     commit_id_pull_i;     //..pull the oldest entry from committed IDs queue
  wire                    commit_id_valid_o;    //..valid entry in committed IDs queue
  wire  [ID_WIDTH-1:0]    commit_id_value_o;    //..ID value from committed IDs queue
  wire                    commit_id_full_o;     //..committed IDs queue is full

  /* sim dut regs and wires */
  wire  [NUM_QUEUES-1:0]  sim_queue_valid;
  wire  [NUM_QUEUES-1:0]  sim_queue_value;
  reg   [NUM_QUEUES-1:0]  sim_queue_pull;
  wire  [NUM_QUEUES-1:0]  sim_queue_full;
  wire                    sim_commit_id_valid;
  wire  [ID_WIDTH-1:0]    sim_commit_id_value;
  wire                    sim_commit_id_full;
  reg                     error;
  reg                     match;
  reg                     evaluate;
  reg   [ID_WIDTH-1:0]    dut_eval, sim_eval;
  reg   [ID_WIDTH-1:0]    dut_val, sim_val;

  /* integers and genvars */
  integer idx, jdx, sim_cnt;
  genvar I;

  /* simulated queue execution fsm */
  localparam  StateSimInit  = 3'b000;
  localparam  StateSimIdle  = 3'b011;
  localparam  StateSimRun   = 3'b101;
  reg [2:0] sim_queues_fsm [NUM_QUEUES-1:0];

  /* simulated queue execution regs and wires */
  reg
  reg [$clog2(MAX_SIM_LATENCY)-1:0] sim_queues_cnt    [NUM_QUEUES-1:0];
  reg [$clog2(MAX_SIM_LATENCY)-1:0] sim_queues_limit  [NUM_QUEUES-1:0];
  reg [NUM_QUEUES-1:0]              sim_queues_exec_finish;

  /* dut */
  reorder_logic_top
    # (
        .NUM_QUEUES (NUM_QUEUES),
        .DEPTH      (DEPTH),
        .BREAKPOINT (BREAKPOINT)
      )
    dut (
        .clk_i                (clk_i),
        .arsn_i               (arsn_i),
        .full_o               (full_o),

        .trace_id_push_i      (trace_id_push_i),
        .trace_id_value_i     (trace_id_value_i),

        .trace_push_i         (trace_push_i),
        .trace_sel_i          (trace_sel_i),
        .trace_break_i        (trace_break_i),
        .trace_update_i       (trace_update_i),

        .queues_status_push_i (queues_status_push_i),

        .commit_id_pull_i     (commit_id_pull_i),
        .commit_id_valid_o    (commit_id_valid_o),
        .commit_id_value_o    (commit_id_value_o),
        .commit_id_full_o     (commit_id_full_o)
      );

  /* initialization */
  initial begin
    clk_i                 = 0;
    arsn_i                = 0;
    trace_id_push_i       = 0;
    trace_id_value_i      = 0;
    trace_push_i          = 0;
    trace_sel_i           = 0;
    trace_break_i         = 0;
    trace_update_i        = 0;
    commit_id_pull_i      = 0;

    gen_entries_amount    = 0;
    gen_entries_cnt       = 0;

    sim_gen_id            = 0;
    deadlock_cnt          = 0;
    error                 = 0;
    match                 = 0;
    evaluate              = 0;
    dut_eval              = 0;
    sim_eval              = 0;
    dut_val               = 0;
    sim_val               = 0;

    sim_cnt               = 0;

    $dumpfile("reorder_logic_top.vcd");
    $dumpvars(0, reorder_logic_top_tb);
    for (idx = 0; idx < NUM_QUEUES; idx = idx+1) $dumpvars(0, reorder_logic_top_tb.sim_queues_limit[idx]);
    for (idx = 0; idx < NUM_QUEUES; idx = idx+1) $dumpvars(0, reorder_logic_top_tb.sim_queues_cnt[idx]);
    for (idx = 0; idx < NUM_QUEUES; idx = idx+1) $dumpvars(0, reorder_logic_top_tb.sim_queues_fsm[idx]);
    for (idx = 0; idx < DEPTH; idx = idx+1) $dumpvars(1, dut.mapped_trace_breakpoints_queue.status_vector_q[idx]);
    for (idx = 0; idx < DEPTH; idx = idx+1) $dumpvars(1, dut.mapped_trace_selector_queue.status_vector_q[idx]);
    for (idx = 0; idx < DEPTH; idx = idx+1) $dumpvars(1, sim_dut.status_vector_q[idx]);
    for (idx = 0; idx < DEPTH; idx = idx+1) $dumpvars(1, dut.mapped_ids_queue.status_vector_q[idx]);
    for (idx = 0; idx < DEPTH; idx = idx+1) $dumpvars(1, dut.committed_ids_queue.status_vector_q[idx]);
    for (idx = 0; idx < DEPTH; idx = idx+1) $dumpvars(1, sim_dut.status_vector_q[idx]);
//    for (idx = 0; idx < DEPTH; idx = idx+1) $dumpvars(1, sim_dut.sim_fifo_mem[idx]);
    $display("\n***** Starting simulation *****\n");
    #`CYCLES(RUN_CYCLES);
    $display("\n******* Finished simulation ********");
    if(errors_cnt==0)
      $display(" >>> Passed!");
    else
      $display(" >>> Found errors!");
    $display("Generated instructions:       %d", gen_instr_cnt);
    $display("Generated micro-instructions: %d", gen_micro_cnt);
    $display("Errors:                       %d", errors_cnt);
    $display("************************************");
    $finish;
  end

  /* clock signal */
  always  begin
    #CLK_F  clk_i = ~clk_i;
  end

  /* asynchronous reset signal */
  always  begin
    #`CYCLES(4)             arsn_i  = 1;
    #`CYCLES(RUN_CYCLES/2)  arsn_i  = 0;
  end

  /* simulation */
  reg [ID_WIDTH-1:0]  sim_gen_id;
  always  @ (negedge clk_i, negedge arsn_i) begin
    if(~arsn_i)  begin
      sim_gen_id = 0;
    end
    else  begin
      if((sim_cnt%100)==0) begin
        $display("Simulated intructions: %d", sim_cnt);
      end
      if(DEBUG_PRINT) $display("New instruction trace:");
      new_entry(sim_gen_id);
      if(DEBUG_PRINT) $display("");
      sim_gen_id = sim_gen_id + 1;
      sim_cnt = sim_cnt + 1;
    end
  end

  /* new entry task */
  reg [$clog2(MAX_GEN_ENTRIES)-1:0] gen_entries_amount;
  reg [$clog2(MAX_GEN_ENTRIES)-1:0] gen_entries_cnt;
  reg [$clog2(MAX_DEADLOCK)-1:0]    deadlock_cnt;
  task automatic new_entry;
    input [ID_WIDTH-1:0] new_id;
    begin
      gen_entries_amount  = $urandom%MAX_GEN_ENTRIES;
      gen_entries_amount  = (gen_entries_amount == 0) ? 1 : gen_entries_amount;
      gen_entries_cnt     = 0;
      trace_id_push_i     = 0;
      trace_break_i       = 0;
      trace_id_value_i    = new_id;
      deadlock_cnt        = 0;
      if(DEBUG_PRINT) $display("  ID: %d", new_id);
      if(DEBUG_PRINT) $display("  Micro-instr amount: %d", gen_entries_amount);
      while (gen_entries_amount > gen_entries_cnt) begin
        if(~full_o) begin
          trace_push_i    = 1'b1;
          trace_sel_i     = ($urandom%(NUM_QUEUES));
          if(DEBUG_PRINT) $display("  Queue: %d", trace_sel_i);
          if((gen_entries_amount - gen_entries_cnt)==1) begin
            trace_break_i = BREAKPOINT;
            trace_id_push_i = 1;
          end
          else begin
            trace_break_i = 0;
          end
          if(DEBUG_PRINT) $display("  Breakpoint: %d", trace_break_i);
          #`CYCLES(1);
          trace_id_push_i = 1'b0;
          trace_push_i    = 1'b0;
          gen_entries_cnt = gen_entries_cnt + 1;
        end
        else  begin
          if(deadlock_cnt == MAX_DEADLOCK)  begin
            $display("Stopped by deadlock!");
            $finish;
          end
          else  begin
            #`CYCLES(1);
            deadlock_cnt  = deadlock_cnt + 1;
          end
        end
      end
      trace_push_i      = 1'b0;
    end
  endtask

  /* simulated update breakpoint */
  always @ (negedge clk_i) begin
    if(arsn_i)  begin
      #`CYCLES(($urandom%100)) trace_update_i = 0;
      #`CYCLES(1)              trace_update_i = 0;
    end
  end

  /* simulated queues structs */
  generate
    for(I=0; I<NUM_QUEUES; I=I+1) begin: gen_sim_queues
      status_value_vector
        # (
            .DEPTH  (DEPTH),
            .WIDTH  (1),
            .SET_EN (0)
          )
        sim_queue (
            .clk_i        (clk_i),
            .rsn_i        (arsn_i),
            .push_i       (trace_push_i & (trace_sel_i==I)),
            .pull_i       (sim_queue_pull[I]),
            .value_i      (1'b1),
            .value_o      (sim_queue_value[I]),
            .valid_o      (sim_queue_valid[I]),
            .full_o       (sim_queue_full[I]),
            .set_i        (1'b0),
            .set_value_i  (1'b0)
          );
    end
  endgenerate

  /* sim queues execution */
  generate
    for(I=0; I<NUM_QUEUES; I=I+1) begin: gen_sim_queues_exec
      always @ (posedge clk_i, negedge arsn_i) begin
        if(~arsn_i) begin
          sim_queues_cnt[I]         <=  0;
          sim_queues_limit[I]       <=  0;
          sim_queues_exec_finish[I] <=  0;
          sim_queue_pull[I]         <=  0;
          sim_queues_fsm[I]         <=  StateSimInit;
        end
        else  begin
          case(sim_queues_fsm[I])
            StateSimInit: begin
              sim_queues_cnt[I]         <=  0;
              sim_queues_limit[I]       <=  0;
              sim_queues_exec_finish[I] <=  0;
              sim_queue_pull[I]         <=  0;
              sim_queues_fsm[I]         <=  StateSimIdle;
            end
            StateSimIdle: begin //..wait for a valid entry in the N queue
              if(sim_queue_valid[I])  begin
                sim_queues_cnt[I]   <=  0;
                sim_queues_limit[I] <=  ($urandom%MAX_SIM_LATENCY);
                sim_queue_pull[I]   <=  1'b1;
                sim_queues_fsm[I]   <=  StateSimRun;
              end
              sim_queues_exec_finish[I] <=  1'b0;
            end
            StateSimRun:  begin
              if(sim_queues_cnt[I] == sim_queues_limit[I]) begin
                sim_queues_exec_finish[I] <=  1'b1;
                sim_queues_fsm[I]         <=  StateSimIdle;
              end
              sim_queues_cnt[I] <=  sim_queues_cnt[I] + 1;
              sim_queue_pull[I] <=  1'b0;
            end
            default:  sim_queues_fsm[I] <=  StateSimInit;
          endcase
        end
      end
      assign queues_status_push_i[I] = sim_queues_exec_finish[I];
    end
  endgenerate

  /* sim commit pull */
  always @ (negedge clk_i, negedge arsn_i)  begin
    if(~arsn_i)
      commit_id_pull_i = 1'b0;
    else begin
      if(commit_id_valid_o)
        commit_id_pull_i = 1'b1;
      else
        commit_id_pull_i = 1'b0;
    end
  end

  /* behavioural evaluation sim model */
//  sim_fifo_behaviour
  status_value_vector
    # (
        .DEPTH  (NUM_QUEUES*DEPTH),
        .WIDTH  (ID_WIDTH),
        .SET_EN (0)
      )
    sim_dut (
        .clk_i        (clk_i),
        .rsn_i        (arsn_i),
        .push_i       (trace_id_push_i),
        .pull_i       (commit_id_pull_i),
        .value_i      (trace_id_value_i),
        .value_o      (sim_commit_id_value),
        .valid_o      (sim_commit_id_valid),
        .full_o       (sim_commit_id_full),
        .set_i        (1'b0),
        .set_value_i  ({ID_WIDTH{1'b0}})
      );

  /* sim evaluation */
  always @ (posedge clk_i, negedge arsn_i)  begin
    if(~arsn_i) begin
      match     <=  0;
      error     <=  0;
      dut_val   <=  0;
      sim_val   <=  0;
      evaluate  <=  0;
    end
    else  begin
      if(commit_id_pull_i)  begin
        if(commit_id_value_o != sim_commit_id_value) begin
          error <= 1'b1;
          match <= 1'b0;
        end
        else begin
          error <= 1'b0;
          match <= 1'b1;
        end
        dut_val   <=  commit_id_value_o;
        sim_val   <=  sim_commit_id_value;
        evaluate  <=  1'b1;
      end
      else begin
        error     <=  1'b0;
        match     <=  1'b0;
        evaluate  <=  1'b0;
      end
    end
  end

  /* sim counters */
  reg [$clog2(RUN_CYCLES)-1:0] errors_cnt;
  reg [$clog2(RUN_CYCLES)-1:0] gen_instr_cnt;
  reg [$clog2(RUN_CYCLES)-1:0] gen_micro_cnt;
  initial begin
    errors_cnt = 0;
    gen_instr_cnt = 0;
    gen_micro_cnt = 0;
  end
  always @ (posedge clk_i) begin
    if(error)
      errors_cnt    <= errors_cnt + 1;
    if(trace_id_push_i)
      gen_instr_cnt <= gen_instr_cnt + 1;
    if(trace_push_i)
      gen_micro_cnt <= gen_micro_cnt + 1;
  end

endmodule // reorder_logic_tb
