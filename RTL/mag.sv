module mag
  #(
   // This is here to help, but we won't change it.
   parameter width_in_p = 16
  ,parameter width_out_p = 16
   )
  (input [0:0] clk_i
  ,input [0:0] reset_i

  ,input [0:0] valid_i
  ,input [width_in_p - 1:0] gx_i
  ,input [width_in_p - 1:0] gy_i
  ,output [0:0] ready_o

  ,output [0:0] valid_o
  ,output [width_out_p - 1:0] mag_o
  ,input [0:0] ready_i
  );

   // Your code here
   wire signed [(2 * width_in_p) - 1 : 0] gx_w; // signed 32 bit product
   // temporarily make gx_i and gy_i signed? $signed forces mult/DSP usage
   assign gx_w = $signed(gx_i) * $signed(gx_i); // compute G_x^2
   wire signed [(2 * width_in_p) - 1 : 0] gy_w; // signed 32 bit product
   assign gy_w = $signed(gy_i) * $signed(gy_i); // compute G_y^2
   // max gradient = 1020 --> 1020^2 + 1020^2 = 2,080,800
   wire [(2 * width_in_p) - 1 : 0] plus_w; // 32 bit result of addition
   assign plus_w = gx_w + gy_w; // inner expression before sqrt // 16 bits + 16 bits
   wire [width_out_p - 1 : 0] sqrt_w; // output of ram

   ram_1r1w_async #(
    .width_p(width_out_p), // 16
    .depth_p(256), // rows
    .filename_p("sqrt.hex") // holds round(sqrt(i * 8192)) vals
   ) ram_async_inst (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .wr_valid_i(1'b0), // no writing read only
    .wr_data_i('0), // no writing
    .wr_addr_i('0), // no place to write to
    .rd_addr_i(plus_w[20:13]), // upper 8 bits of (G_x^2 + G_y^2) >> 13 for lut row --> dividing by 2^13 (8192) --> map 21 bit sum to 8 bit address
    .rd_data_o(sqrt_w) // approx sqrt from hex
   );

   elastic #( // async w/ elastic stage for output forces bram block?
    .width_p(width_out_p), // 16
    .datapath_gate_p(1),
    .datapath_reset_p(0)
   ) elastic_inst (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .data_i(sqrt_w), // lut output
    .valid_i(valid_i),
    .ready_o(ready_o),
    .valid_o(valid_o),
    .data_o(mag_o), // 16 bit output
    .ready_i(ready_i)
   );
   

endmodule
