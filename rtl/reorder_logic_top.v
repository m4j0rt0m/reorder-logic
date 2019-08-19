/*
 *  File:                   reorder_sel_logic.v
 *  Description:            Combinational logic used in the acknowledge for queues re-ordering
 *  Project:                Re-Order Logic
 *  Author:                 Abraham J. Ruiz R. (https://github.com/m4j0rt0m)
 *  Revision:               0.1 - First version
 */
module reorder_logic_top
# (
    parameter NUM_QUEUES  = 4,
    parameter DEPTH       = 64,
    parameter WIDTH       = 1,
    parameter SET_EN      = 0
  )
(/*AUTOARG*/
   // Outputs
   full_o, commit_valid_o, commit_value_o,
   // Inputs
   clk_i, arsn_i, id_push_i, id_value_i, trace_push_i, trace_sel_i,
   trace_break_i, trace_update_i, queues_push_i, commit_pull_i
   );

  /* clog2 function */
  function integer clog2;
    input integer value;
    begin
      value = value-1;
      for (clog2=0; value>0; clog2=clog2+1)
        value = value>>1;
    end
  endfunction

  /* local parameters */
  localparam  ID_WIDTH  = $clog2(DEPTH);
  localparam  SEL_WIDTH = $clog2(NUM_QUEUES);

  /* flow control */
  input                     clk_i;            //..clock signal
  input                     arsn_i;           //..active low reset
  output                    full_o;           //..full entries

  /* id port */
  input                     id_push_i;        //..push a new id entry
  input   [ID_WIDTH-1:0]    id_value_i;       //..new id for trace in queue

  /* trace port */
  input                     trace_push_i;     //..push a new entry in the trace buffer
  input   [SEL_WIDTH-1:0]   trace_sel_i;      //..new queue selector in trace buffer entry (will wait for that queue)
  input                     trace_break_i;    //..breakpoint entry of trace
  input                     trace_update_i;   //..reupdate end of trace (due to next invalid entry)

  /* queues port */
  input   [NUM_QUEUES-1:0]  queues_push_i;    //..push a new status in N queue

  /* commit port */
  input                     commit_pull_i;
  output                    commit_valid_o;
  output  [ID_WIDTH-1:0]    commit_value_o;

  /* regs and wires */
  reg                       id_pull;              //..pull the oldest ID from mapped IDs queue
  wire    [ID_WIDTH-1:0]    id_value;             //..next ID to be committed
  wire                      id_valid;             //..valid IDs in queue
  wire                      id_full;              //..mapped IDs queue is full
  reg                       trace_pull;           //..pull the oldest entry from trace breakpoint queues
  wire                      trace_break;          //..trace-breakpoint value
  wire                      trace_break_valid;    //..valid trace-breakpoints in queue
  wire                      trace_break_full;     //..trace-breakpoints queue is full
  wire    [SEL_WIDTH-1:0]   trace_selector;       //..reordering queue selector
  wire                      trace_selector_valid; //..valid entries in trace-selector queue
  wire                      trace_selector_full;  //..trace-selector queue is full
  
  reg     [NUM_QUEUES-1:0]  queues_pull;          //..pull the oldest status from N queue

  /* genvars and integers */
  genvar I;

  /* mapped IDs queue */
  status_value_vector
    # (
        .DEPTH  (DEPTH),
        .WIDTH  (ID_WIDTH),
        .SET_EN (0)
      )
    mapped_ids_queue (
        .clk_i        (clk_i),
        .rsn_i        (arsn_i),
        .push_i       (id_push_i),
        .pull_i       (id_pull),
        .value_i      (id_value_i),
        .value_o      (id_value),
        .valid_o      (id_valid),
        .full_o       (id_full),

        .set_i        (0),
        .set_value_i  (0)
      );

  /* trace-breakpoints queue */
  status_value_vector
    # (
        .DEPTH  (DEPTH),
        .WIDTH  (1),
        .SET_EN (1)
      )
    mapped_trace_breakpoints_queue (
        .clk_i        (clk_i),
        .rsn_i        (arsn_i),
        .push_i       (trace_push_i),
        .pull_i       (trace_pull),
        .value_i      (trace_break_i),
        .value_o      (trace_break),
        .valid_o      (trace_break_valid),
        .full_o       (trace_break_full),

        .set_i        (trace_update_i),
        .set_value_i  (1'b1)
      );

  /* trace-selection queue */
  status_value_vector
    # (
        .DEPTH  (DEPTH),
        .WIDTH  (SEL_WIDTH),
        .SET_EN (0)
      )
    mapped_trace_selector_queue (
        .clk_i        (clk_i),
        .rsn_i        (arsn_i),
        .push_i       (trace_push_i),
        .pull_i       (trace_pull),
        .value_i      (trace_break_i),
        .value_o      (trace_selector),
        .valid_o      (trace_selector_valid),
        .full_o       (trace_selector_full),

        .set_i        (0),
        .set_value_i  (0)
      );

  /* status N queues */
  generate
    for(I=0; I<NUM_QUEUES; I=I+1) begin:  status_queues
      status_value_vector
        # (
            .DEPTH  (DEPTH),
            .WIDTH  (1),
            .SET_EN (0)
          )
        trace_queues (
            .clk_i        (clk_i),
            .rsn_i        (arsn_i),
            .push_i       (queues_push_i[I]),
            .pull_i       (queues_pull[I]),
            .value_i      (1'b1),
            .value_o      (queues_status_value[I]),
            .valid_o      (queues_status_valid[I]),
            .full_o       (queues_full[I]),

            .set_i        (0),
            .set_value_i  (0)
          );
    end
  endgenerate

  /* reorder selector logic */
  reorder_logic_selector
    # (
        .NUM_QUEUES (NUM_QUEUES)
      )
    trace_queues_selector_logic (
        .valid_i  (trace_selector_valid), //..valid expected value
        .next_i   (trace_selector),       //..next expected value
        .status_i (queues_status),        //..status value from queues
        .ack_o    (queues_pull)           //..pull-acknowledge response to queues
      );


endmodule // reorder_logic_top
