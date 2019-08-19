/*
 *  File:                   reorder_logic_selector.v
 *  Description:            Combinational logic used in the acknowledge for queues re-ordering
 *  Project:                Re-Order Logic
 *  Author:                 Abraham J. Ruiz R. (https://github.com/m4j0rt0m)
 *  Revision:               0.1 - First version
 */
module reorder_logic_selector
# (
    parameter NUM_QUEUES  = 4
  )
(/*AUTOARG*/
   // Outputs
   ack_o,
   // Inputs
   valid_i, next_i, status_i
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
  localparam  SEL_WIDTH = $clog2(NUM_QUEUES);

  /* PORTS: request control */
  input                     valid_i;    //..valid expected value
  input   [SEL_WIDTH-1:0]   next_i;     //..next expected value

  /* PORTS: queues status */
  input   [NUM_QUEUES-1:0]  status_i;   //..status value from queues

  /* PORTS: queues pulling control */
  output  [NUM_QUEUES-1:0]  ack_o;      //..pull-acknowledge response to queues

  /* genvars and integers */
  genvar I;

  /* regs and wires */
  wire    [NUM_QUEUES-1:0]  select_int; //..demux selector

  /* generate combinational logic */
  generate
    for(I=0; I<NUM_QUEUES; I=I+1) begin:  reorder_comb_logic
      assign select_int[I] = (next_i == I) ? 1'b1 : 1'b0;               //..demux logic
      assign ack_o[I] = (valid_i) ? select_int[I] & status_i[I] : 1'b0; //..acknowledge bit per queue
    end
  endgenerate

endmodule // reorder_logic_selector
