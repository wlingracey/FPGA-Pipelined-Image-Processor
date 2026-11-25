module elastic
  #(parameter [31:0] width_p = 8
   /* verilator lint_off WIDTHTRUNC */
   ,parameter [0:0] datapath_gate_p = 0
   ,parameter [0:0] datapath_reset_p = 0
   /* verilator lint_on WIDTHTRUNC */
   )
  (input [0:0] clk_i
  ,input [0:0] reset_i

  ,input [width_p - 1:0] data_i
  ,input [0:0] valid_i
  ,output [0:0] ready_o 

  ,output [0:0] valid_o 
  ,output logic [width_p - 1:0] data_o 
  ,input [0:0] ready_i
  );

  reg [0:0] full_r;
  wire [0:0] in_w, out_w;
  logic [0:0] data_w;
  assign valid_o = full_r;
  assign ready_o = (!full_r) | ready_i;
  assign in_w = valid_i & ready_o;
  assign out_w = valid_o & ready_i;

  /* verilator lint_off WIDTHTRUNC */
  assign data_w = (datapath_gate_p == 1'b1) ? in_w : ready_o;
  /* verilator lint_on WIDTHTRUNC */

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      full_r <= 1'b0;
    end else begin
      if (in_w && !out_w) begin
        full_r <= 1'b1;
      end else if (!in_w && out_w) begin
        full_r <= 1'b0;
      end
    end
  end

  always_ff @(posedge clk_i) begin
    /* verilator lint_off WIDTHTRUNC */
    if (reset_i && datapath_reset_p) begin
    /* verilator lint_on WIDTHTRUNC */  
      data_o <= width_p'(0);
    end else if (data_w) begin
      data_o <= data_i;
    end
  end

endmodule
