/*
 *  File:                   reorder_logic_tb.v
 *  Description:            Test bench for the re-order logic module
 *  Project:                Re-Order Logic
 *  Author:                 Abraham J. Ruiz R. (https://github.com/m4j0rt0m)
 *  Revision:               0.1 - First version
 */
module reorder_logic_tb ();

  /* local parameters */
  localparam  RUN_CYCLES      = 200000;                 //..number of cycles per simulation
  localparam  FREQ_CLK        = 50;                     //..MHz
  localparam  CLK_F           = (1000 / FREQ_CLK) / 2;  //..ns
  localparam  NUM_QUEUES      = 4,                      //..number of queues to reorder
  localparam  DEPTH           = 8;                      //..entries depth
  localparam  BREAKPOINT      = 1'b1;                   //..trace breakpoint value
  localparam  ID_WIDTH        = $clog2(DEPTH);          //..ID width
  localparam  SEL_WIDTH       = $clog2(NUM_QUEUES);     //..queue selector width
  localparam  MAX_SIM_LATENCY = 40;                     //..maximum execution latency for every queue entry
  localparam  MAX_GEN_ENTRIES = 8;                      //..maximum number of generated entries per ID

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
  wire                    sim_commit_id_valid;
  wire  [ID_WIDTH-1:0]    sim_commit_id_value;
  wire                    sim_commit_id_full;
  reg   [SEL_WIDTH-1:0]   sim_trace_sel;
  reg                     error;

  /* integers and genvars */
  genvar I;

  /* simulated queue execution fsm */
  localparam  StateSimInit  = 3'b000;
  localparam  StateSimIdle  = 3'b011;
  localparam  StateSimRun   = 3'b101;
  reg [2:0] sim_queues_fsm [NUM_QUEUES-1:0];

  /* simulated queue execution regs and wires */
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
    trace_push_i;         = 0;
    trace_sel_i           = 0;
    trace_break_i         = 0;
    trace_update_i        = 0;
    queues_status_push_i  = 0;
    commit_id_pull_i      = 0;

    sim_trace_sel         = 0;
    error                 = 0;

    $dumpfile("reorder_logic.vcd");
    $dumpvars(0, reorder_logic_tb);
    #`CYCLES(RUN_CYCLES)  $finish;
  end

  /* clock signal */
  always  begin
    #CLK_F  clk_i = ~clk_i;
  end

  /* asynchronous reset signal */
  always  begin
    #`CYCLES(4)     arsn_i  = 1;
    #`CYCLES(2000)  arsn_i  = 0;
  end

  /* simulation */
  always  begin
    while(~full_o)  begin
      #`CYCLES(1) new_entry(($urandom%DEPTH));
    end
  end

  /* new entry task */
  reg [$clog2(MAX_GEN_ENTRIES)-1:0] gen_entries_amount;
  reg [$clog2(MAX_GEN_ENTRIES)-1:0] gen_entries_cnt;
  task automatic new_entry;
    input [$clog2(DEPTH)-1:0] new_id;
    begin
      gen_entries_amount  = $urandom%MAX_GEN_ENTRIES;
      gen_entries_amount  = (gen_entries_amount == 0) ? 1 : gen_entries_amount;
      gen_entries_cnt     = 0;
      trace_id_push_i     = 1;
      trace_id_value_i    = new_id;
      while (gen_entries_amount != gen_entries_cnt) begin
        trace_push_i    = 1'b1;
        trace_sel_i     = //...CONTINUE HERE
        #`CYCLES(1);
        trace_id_push_i = 1'b0;
      end
    end
  endtask

  /* simulated update breakpoint */
  always  begin
    #`CYCLES(($urandom%10)) trace_update_i = 1;
    #`CYCLES(1)             trace_update_i = 0;
  end

  /* sim queues */
  generate
    for(I=0; I<NUM_QUEUES; I=I+1) begin: gen_sim_queues
      sim_fifo_behaviour
        # (
            .DEPTH  (DEPTH),
            .WIDTH  (1)
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
            .set_i        (0),
            .set_value_i  (0)
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
          sim_queues_fsm[I]         <=  StateSimInit;
        end
        else  begin
          case(sim_queues_fsm[I])
            StateSimInit: begin
              sim_queues_cnt[I]         <=  0;
              sim_queues_limit[I]       <=  0;
              sim_queues_exec_finish[I] <=  0;
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

  /* behavioural sim model */
  sim_fifo_behaviour
    # (
        .DEPTH  (DEPTH),
        .WIDTH  (ID_WIDTH)
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
        .set_i        (0),
        .set_value_i  (0)
      );

  /* sim evaluation */
  always @ (posedge clk_i, negedge arsn_i)  begin
    if(~arsn_i)
      error <=  0;
    else  begin
      if(commit_id_pull_i)  begin
        if((commit_id_value_o != sim_commit_id_value)|
           (commit_id_valid_o != sim_commit_id_valid)|
           (commit_id_full_o  != sim_commit_id_full)) begin
          error <=  1'b1;
          $finish;
        end
        else
          error <=  1'b0;
      end
      else
        error <=  1'b0;
    end
  end

endmodule // reorder_logic_tb
