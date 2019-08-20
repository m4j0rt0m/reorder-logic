/*
 *  File:                   sim_fifo_behaviour.v
 *  Description:            Behavioural module for FIFO simulation:
 *                            - Not allowed to push if full and there is no pull
 *                            - Not allowed to pull if empty
 *  Project:                Status Value Vector
 *  Author:                 Abraham J. Ruiz R. (https://github.com/m4j0rt0m)
 *  Revision:               0.1 - First version
 */
module sim_fifo_behaviour
# (
    parameter DEPTH = 8,
    parameter WIDTH = 8
  )
(/*AUTOARG*/
   // Outputs
   value_o, valid_o, full_o,
   // Inputs
   clk_i, rsn_i, push_i, pull_i, value_i, set_i, set_value_i
   );

  input               clk_i;
  input               rsn_i;

  input               push_i;
  input               pull_i;

  input   [WIDTH-1:0] value_i;
  output  [WIDTH-1:0] value_o;

  output              valid_o;
  output              full_o;

  input               set_i;
  input   [WIDTH-1:0] set_value_i;


  integer i;
  reg [WIDTH-1:0]         sim_fifo_mem  [DEPTH-1:0];                        //..fifo memory
  reg [$clog2(DEPTH)-1:0] sim_fifo_wr_ptr;                                  //..fifo write pointer
  reg [$clog2(DEPTH):0]   sim_fifo_amount;                                  //..fifo amount
  wire                    sim_fifo_empty = (sim_fifo_amount==0) ? 1 : 0;    //..fifo empty
  wire                    sim_fifo_full = (sim_fifo_amount==DEPTH) ? 1 : 0; //..fifo full

  always @ (posedge clk_i, negedge rsn_i) begin
    if(~rsn_i)  begin
      for(i=0; i<DEPTH; i=i+1)  begin
        sim_fifo_mem[i] = 0;
      end
      sim_fifo_wr_ptr = 0;
      sim_fifo_amount = 0;
    end
    else  begin
      case({set_i, pull_i, push_i})
        3'b000: begin //..do nothing
          for(i=0; i<DEPTH; i=i+1)  begin
            sim_fifo_mem[i] = sim_fifo_mem[i];
          end
        end
        3'b001: begin //..push a new entry
          if(~sim_fifo_full)  begin
            sim_fifo_mem[sim_fifo_wr_ptr] = value_i;
            sim_fifo_wr_ptr               = sim_fifo_wr_ptr + 1;
            sim_fifo_amount               = sim_fifo_amount + 1;
          end
        end
        3'b010: begin //..pull the oldest entry
          for(i=0; i<DEPTH-1; i=i+1)  begin
            sim_fifo_mem[i] = sim_fifo_mem[i+1];
          end
          sim_fifo_mem[DEPTH-1] = 0;
          if(~sim_fifo_empty) begin
            sim_fifo_wr_ptr = sim_fifo_wr_ptr - 1;
            sim_fifo_amount = sim_fifo_amount - 1;
          end
        end
        3'b011: begin //..push a new entry and pull the oldest entry
          case({sim_fifo_full, sim_fifo_empty})
            2'b00:  begin
              for(i=0; i<DEPTH-1; i=i+1)  begin
                sim_fifo_mem[i] = sim_fifo_mem[i+1];
              end
              sim_fifo_mem[DEPTH-1] = 0;
              sim_fifo_mem[(sim_fifo_wr_ptr-1)] = value_i;
            end
            2'b01:  begin
              sim_fifo_mem[sim_fifo_wr_ptr] = value_i;
              sim_fifo_wr_ptr               = sim_fifo_wr_ptr + 1;
              sim_fifo_amount               = sim_fifo_amount + 1;
            end
            2'b10:  begin
              for(i=0; i<DEPTH-1; i=i+1)  begin
                sim_fifo_mem[i] = sim_fifo_mem[i+1];
              end
              sim_fifo_mem[DEPTH-1] = value_i;
            end
            2'b11:  begin
              $display("Something is wrong!");
              $stop;
            end
          endcase
        end
        3'b100: begin //..re-update the last entry
          case({sim_fifo_full, sim_fifo_empty})
            2'b00:  sim_fifo_mem[(sim_fifo_wr_ptr-1)] = set_value_i;
            2'b01:  begin
              for(i=0; i<DEPTH; i=i+1)  begin
                sim_fifo_mem[i] = sim_fifo_mem[i];
              end
            end
            2'b10:  sim_fifo_mem[DEPTH-1] = set_value_i;
            2'b11:  begin
              $display("Something is wrong!");
              $stop;
            end
          endcase
        end
        3'b101: begin //..re-update the last entry and push a new entry
          case({sim_fifo_full, sim_fifo_empty})
            2'b00:  begin
              sim_fifo_mem[(sim_fifo_wr_ptr-1)] = set_value_i;
              sim_fifo_mem[sim_fifo_wr_ptr]   = value_i;
              sim_fifo_wr_ptr                 = sim_fifo_wr_ptr + 1;
              sim_fifo_amount                 = sim_fifo_amount + 1;
            end
            2'b01:  begin
              sim_fifo_mem[sim_fifo_wr_ptr]   = value_i;
              sim_fifo_wr_ptr                 = sim_fifo_wr_ptr + 1;
              sim_fifo_amount                 = sim_fifo_amount + 1;
            end
            2'b10:  begin
              sim_fifo_mem[DEPTH-1] = set_value_i;
            end
            2'b11:  begin
              $display("Something is wrong!");
              $stop;
            end
          endcase
        end
        3'b110: begin //..re-update the last entry and pull the oldest entry
          if(~sim_fifo_empty) begin
            if(sim_fifo_full)
              sim_fifo_mem[DEPTH-1] = set_value_i;
            else
              sim_fifo_mem[(sim_fifo_wr_ptr-1)] = set_value_i;
            for(i=0; i<DEPTH-1; i=i+1)  begin
              sim_fifo_mem[i] = sim_fifo_mem[i+1];
            end
            sim_fifo_mem[DEPTH-1] = 0;
            sim_fifo_wr_ptr = sim_fifo_wr_ptr - 1;
            sim_fifo_amount = sim_fifo_amount - 1;
          end
        end
        3'b111: begin //..re-update the last entry, push a new entry and pull the oldest entry
          case({sim_fifo_full, sim_fifo_empty})
            2'b00:  begin
              sim_fifo_mem[(sim_fifo_wr_ptr-1)] = set_value_i;
              sim_fifo_mem[sim_fifo_wr_ptr]   = value_i;
              for(i=0; i<DEPTH-1; i=i+1)  begin
                sim_fifo_mem[i] = sim_fifo_mem[i+1];
              end
              sim_fifo_mem[DEPTH-1] = 0;
            end
            2'b01:  begin
              sim_fifo_mem[sim_fifo_wr_ptr] = value_i;
              sim_fifo_wr_ptr = sim_fifo_wr_ptr + 1;
              sim_fifo_amount = sim_fifo_amount + 1;
            end
            2'b10:  begin
              sim_fifo_mem[DEPTH-1] = set_value_i;
              for(i=0; i<DEPTH-1; i=i+1)  begin
                sim_fifo_mem[i] = sim_fifo_mem[i+1];
              end
              sim_fifo_mem[DEPTH-1] = value_i;
            end
            2'b11:  begin
              $display("Something is wrong!");
              $stop;
            end
          endcase
        end
      endcase
    end
  end

  /* output assignment */
  assign value_o  = sim_fifo_mem[0];
  assign valid_o  = (sim_fifo_amount>0) ? 1 : 0;
  assign full_o   = sim_fifo_full;

endmodule // sim_fifo_behaviour
