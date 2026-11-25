module uart_axis
  #(parameter example_p = 0)
  (input [0:0] clk_i // 25 MHz Clock
  ,input [0:0] reset_i

  ,input [0:0] rx_serial_i
  ,output [0:0] tx_serial_o


  ,output [5:1] led_o // For debugging
   );

   localparam [31:0] data_width_lp = 8;

   wire [data_width_lp-1:0] m_axis_uart_tdata;
   wire       m_axis_uart_tvalid;
   wire       m_axis_uart_tready;

   wire [data_width_lp-1:0] s_axis_uart_tdata;
   wire       s_axis_uart_tvalid;
   wire       s_axis_uart_tready;

   // Expanded data, coming out of the adapter
   wire [31:0] m_axis_tdata;
   wire        m_axis_tvalid;
   wire [3:0]  m_axis_tkeep;
   wire        m_axis_tready;
   
   // Expanded data, going back into the adapter
   wire [31:0] s_axis_tdata;
   wire        s_axis_tvalid;
   wire [3:0]  s_axis_tkeep;
   wire        s_axis_tready;

   uart uart_inst (
    .clk(clk_i),
    .rst(reset_i),
    .s_axis_tdata(s_axis_uart_tdata),
    .s_axis_tvalid(s_axis_uart_tvalid),
    .s_axis_tready(s_axis_uart_tready),
    .m_axis_tdata(m_axis_uart_tdata),
    .m_axis_tvalid(m_axis_uart_tvalid),
    .m_axis_tready(m_axis_uart_tready),
    .rxd(rx_serial_i),
    .txd(tx_serial_o),
    .tx_busy(),
    .rx_busy(),
    .rx_overrun_error(),
    .rx_frame_error(),
    .prescale(16'd27)
   );

    axis_adapter
     #(// Parameters
       .S_DATA_WIDTH                    (data_width_lp), // 8 bits from serial
       .M_DATA_WIDTH                    (32), // 32 bits expanded
       .S_KEEP_ENABLE                   (0),
       .M_KEEP_ENABLE                   (1),
       .M_KEEP_WIDTH                    (4),
       .ID_ENABLE                       (0),
       .DEST_ENABLE                     (0),
       .USER_ENABLE                     (0))
   adapter_widener (
    .clk(clk_i),
    .rst(reset_i),
    .s_axis_tdata(m_axis_uart_tdata),
    .s_axis_tkeep('0),
    .s_axis_tvalid(m_axis_uart_tvalid),
    .s_axis_tready(m_axis_uart_tready),
    .s_axis_tlast(1'b0),
    .s_axis_tid('0),
    .s_axis_tdest('0),
    .s_axis_tuser('0),
    .m_axis_tdata(m_axis_tdata),
    .m_axis_tkeep(m_axis_tkeep),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .m_axis_tlast(),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser()
   );

   axis_adapter
     #(// Parameters
       .S_DATA_WIDTH                    (32), // 32 bits expanded
       .M_DATA_WIDTH                    (data_width_lp), // 8 bits to serial
       .S_KEEP_ENABLE                   (1),
       .S_KEEP_WIDTH                    (4),
       .M_KEEP_ENABLE                   (0),
       .ID_ENABLE                       (0),
       .DEST_ENABLE                     (0),
       .USER_ENABLE                     (0))
   adapter_narrower (
    .clk(clk_i),
    .rst(reset_i),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tkeep(s_axis_tkeep),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .s_axis_tlast(1'b0),
    .s_axis_tid('0),
    .s_axis_tdest('0),
    .s_axis_tuser('0),
    .m_axis_tdata(s_axis_uart_tdata),
    .m_axis_tkeep(),
    .m_axis_tvalid(s_axis_uart_tvalid),
    .m_axis_tready(s_axis_uart_tready),
    .m_axis_tlast(),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser()
   );

   wire [7:0] gray_w; // output wire from rgb2gray to input of sobel
   wire gray_ready_w; // handshakes from rgb2gray to sobel
   wire gray_valid_w; // handshakes from rgb2gray to sobel
   rgb2gray rgb2gray_inst (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .valid_i(m_axis_tvalid), // m axis valid handshake
    .red_i(m_axis_tdata[7:0]), // lower 8 bits of data
    .green_i(m_axis_tdata[15:8]), // middle 8 bits of data
    .blue_i(m_axis_tdata[23:16]), // upper 8 bits of data
    .ready_o(m_axis_tready), // m axis ready handshake
    .valid_o(gray_valid_w), // sends out handshake
    .gray_o(gray_w),
    .ready_i(gray_ready_w) // sends out handshake
   );

   wire [15:0] gx_w; // wire for output gx of sobel 
   wire [15:0] gy_w; // wire for output gy of sobel
   wire sobel_valid_w; // sobel out handshakes to mag
   wire sobel_ready_w; // sobel out handshakes to mag

   sobel #(
    .linewidth_px_p(640),
    .width_p(8),
    .width_out_p(16)
   ) sobel_inst (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .valid_i(gray_valid_w), // handshake from rgb2gray
    .ready_o(gray_ready_w), // handshake from rgb2gray
    .data_i(gray_w), // data from rgb2gray
    .valid_o(sobel_valid_w), // now controls s handshake
    .ready_i(sobel_ready_w), // now controls s handshake
    .gx_o(gx_w),
    .gy_o(gy_w)
   );

   wire [15:0] mag_w; // output wire from mag

   mag #(
    .width_in_p(16),
    .width_out_p(16)
   ) mag_inst (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .valid_i(sobel_valid_w), // handshake from sobel
    .gx_i(gx_w), // takes output from sobel
    .gy_i(gy_w), // output from sobel
    .ready_o(sobel_ready_w), // handshakes from sobel
    .valid_o(s_axis_tvalid), // outputs handshakes back to uart
    .mag_o(mag_w),
    .ready_i(s_axis_tready) // handshakes back to uart
   );

  // data should now be from the conv2d gx and gy
   assign s_axis_tdata = {16'b0, mag_w}; // pad upper bits only need lower 16
   assign s_axis_tkeep = 4'b1111;
   
endmodule

