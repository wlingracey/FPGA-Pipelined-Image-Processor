module sobel
    #(
     parameter  linewidth_px_p = 640
    ,parameter width_p = 8
    ,parameter width_out_p = 16)
    (input [0:0] clk_i
    ,input [0:0] reset_i

    ,input [0:0] valid_i
    ,output [0:0] ready_o
    ,input [width_p - 1 : 0] data_i

    ,output [0:0] valid_o
    ,input [0:0] ready_i
    ,output [width_out_p - 1 : 0] gx_o
    ,output [width_out_p - 1 : 0] gy_o
    );

   logic                        valid_r;
   wire                         enable_w;
   assign enable_w = valid_i & ready_o;

   assign ready_o = ~valid_o | ready_i;

   always_ff @(posedge clk_i) begin
      if (reset_i) begin
         valid_r <= 1'b0;
      end else if (ready_o) begin
         valid_r <= enable_w;
      end
   end
   assign valid_o = valid_r;

   logic [width_p-1:0] newest_r [2:0];   

   always_ff @(posedge clk_i) begin
      if (reset_i) begin
         newest_r[0] <= '0; // reset bottom row
         newest_r[1] <= '0;
         newest_r[2] <= '0;
      end else if (enable_w) begin
         newest_r[0] <= data_i; // take the new data into rightmost pixel
         newest_r[1] <= newest_r[0]; // shift 1 (middle pixel)
         newest_r[2] <= newest_r[1]; // shift 1 (left pixel)
      end
   end

   localparam addr_width_lp = ($clog2(linewidth_px_p - 1));
   wire [addr_width_lp - 1 : 0] count_w;
   counter_roll #(
      .max_val_p(linewidth_px_p - 2), // 640 - ram delay - newest pixel = 638, newest_r has 1 pixel already, need 1 cycle latency, 640 total raw delay
      .width_p(addr_width_lp)
   ) counter_roll_inst (
      .clk_i(clk_i),
      .reset_i(reset_i),
      .up_i(enable_w),
      .down_i(1'b0),
      .count_o(count_w)
   );
   wire [width_p - 1 : 0] middle_w; // right pixel of middle row, throws lint errors if first bit of middle bus is not a standalone wire
   logic [width_p - 1 : 0] middle_r [2:1]; // middle/left, rest of middle line bus
   wire [width_p - 1 : 0] oldest_w; // right pixel of top row, because lint errors
   logic [width_p - 1 : 0] oldest_r [2:1]; // middle/left, rest of oldest line bus

   ram_1r1w_sync #( // delays newest pixel by 1 image row to create the middle row, read before write
      .width_p(width_p),
      .depth_p(linewidth_px_p - 1), // 640 - 1 --> 639 cuz newest already has a pixel and 1 cycle read delay
      .filename_p("")
   ) ram_inst0 (
      .clk_i(clk_i),
      .reset_i(reset_i),
      .wr_valid_i(enable_w),
      .wr_data_i(newest_r[0]),
      .wr_addr_i(count_w),
      .rd_valid_i(enable_w),
      .rd_addr_i(count_w), // outputs pixel from 1 row before while storing new one
      .rd_data_o(middle_w) // samples old pixel from previous row at count_w while rd_addr_i being overwritten with new pixel
   );

   always_ff @(posedge clk_i) begin
      if (reset_i) begin
         middle_r[1] <= '0; // reset middle/left
         middle_r[2] <= '0;
      end else if (enable_w) begin
         middle_r[1] <= middle_w; // shifting along
         middle_r[2] <= middle_r[1];
      end
   end

   ram_1r1w_sync #(
      .width_p(width_p),
      .depth_p(linewidth_px_p - 1),
      .filename_p("")
   ) ram_inst1 (
      .clk_i(clk_i),
      .reset_i(reset_i),
      .wr_valid_i(enable_w),
      .wr_data_i(middle_w),
      .wr_addr_i(count_w),
      .rd_valid_i(enable_w),
      .rd_addr_i(count_w),
      .rd_data_o(oldest_w)
   );

   always_ff @(posedge clk_i) begin
      if (reset_i) begin
         oldest_r[1] <= '0;
         oldest_r[2] <= '0;
      end else if (enable_w) begin
         oldest_r[1] <= oldest_w;
         oldest_r[2] <= oldest_r[1];
      end
   end
   wire [(2 * width_p)-1:0] window_w [2:0][2:0]; // 3x3 slidign

   // Three pixels from the "oldest" line.
   assign window_w[0][2] = {{width_p{1'b0}}, oldest_r[2]}; // left top
   assign window_w[0][1] = {{width_p{1'b0}}, oldest_r[1]}; // center top
   assign window_w[0][0] = {{width_p{1'b0}}, oldest_w}; // right top

   // Three pixels from the "middle" line.
   assign window_w[1][2] = {{width_p{1'b0}}, middle_r[2]}; // left middle
   assign window_w[1][1] = {{width_p{1'b0}}, middle_r[1]}; // center middle
   assign window_w[1][0] = {{width_p{1'b0}}, middle_w}; // right middle

   // Three pixels from the "newest" line.
   assign window_w[2][2] = {{width_p{1'b0}}, newest_r[2]}; // left bottom
   assign window_w[2][1] = {{width_p{1'b0}}, newest_r[1]}; // center bottom
   assign window_w[2][0] = {{width_p{1'b0}}, newest_r[0]}; // right bottom

   // right column - left column
   // middle row of columns gets << 1 to double weight
   // [-1 0 +1]
   // [-2 0 +2]
   // [-1 0 +1]
   // right column - left --> << 1 gets the multiplied by 2, avoids DSP?
   assign gx_o = (window_w[0][0] + (window_w[1][0] << 1) + window_w[2][0]) - (window_w[0][2] + (window_w[1][2] << 1) + window_w[2][2]);
   // bottom row - top row 
   // middle column of rows gets << 1 to double weight
   // [-1 -2 -1]
   // [ 0  0  0]
   // [+1  2  1]
   // bottom row - top --> << 1 gets the mult by 2
   assign gy_o = (window_w[2][2] + (window_w[2][1] << 1) + window_w[2][0]) - (window_w[0][2] + (window_w[0][1] << 1) + window_w[0][0]);

endmodule
