module rgb2gray
  #(
   // This is here to help, but we won't change it.
   parameter width_p = 8
   )
  (input [0:0] clk_i
  ,input [0:0] reset_i

  ,input [0:0] valid_i
  ,input [width_p - 1:0] red_i
  ,input [width_p - 1:0] blue_i
  ,input [width_p - 1:0] green_i
  ,output [0:0] ready_o

  ,output [0:0] valid_o
  ,output [width_p - 1:0] gray_o
  ,input [0:0] ready_i
  );

   // The testbench uses this function to test your code. How many
   // fractional bits are needed to enode these values?

   // gray = 0.2989 * r + 0.5870 * g + 0.1140 * b

   // Your code here
   wire [-1 : -14] red_w = 14'd4897; // scaled by 2^14 --> integer consts --> 16384 --> good precision?
   wire [-1 : -14] green_w = 14'd9617;
   wire [-1 : -14] blue_w = 14'd1868;
   wire [width_p - 1 : -14] sum_w;
   assign sum_w = (red_i * red_w) + (green_i * green_w) + (blue_i * blue_w); // each color channel * weight and sum fixed point result, 3 DSP total
   wire [width_p - 1 : 0] int_w = sum_w[width_p - 1 : 0]; // drop 14 fractional bits --> 8 integer bits, 14 fractional bits get dropped
   
   elastic #(
    .width_p(width_p),
    .datapath_reset_p(1'b1)
   ) elastic_inst (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .data_i(int_w), // 8 bits
    .ready_i(ready_i),
    .valid_i(valid_i),
    .ready_o(ready_o),
    .valid_o(valid_o),
    .data_o(gray_o) // 8 bits
   );

endmodule

