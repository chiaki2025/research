`timescale 1ns / 1ps

module processing_lane #(
    parameter int W_IN   = 112,
    parameter int DATA_W = 8,
    parameter int PROD_W = 16,
    parameter int ACC_W  = 32
)(
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic                          clr,         // Xóa đồng bộ line_buffer và window_generator

    // Tín hiệu điều khiển luồng dữ liệu
    input  logic                          shift_en,    // Cho phép dịch pixel mới vào hàng đệm
    input  logic                          win_valid,   // Báo hiệu cửa sổ 3x3 hiện tại hợp lệ để chốt tổng

    // 4 cờ đệm biên SAME Padding
    input  logic                          pad_top,
    input  logic                          pad_bottom,
    input  logic                          pad_left,
    input  logic                          pad_right,

    // Dữ liệu đầu vào
    input  logic signed [DATA_W-1:0]      pixel_in,    // Điểm ảnh đầu vào theo luồng raster
    input  logic signed [8:0][DATA_W-1:0] weight_in,   // 9 trọng số kernel 3x3 của kênh hiện tại

    // Kết quả đầu ra
    output logic                          acc_valid,   // Cờ báo kết quả tích chập đã sẵn sàng
    output logic signed [ACC_W-1:0]       acc_out      // Tổng tích chập 32-bit có dấu
);

    // Dây nối trung gian giữa các khối con
    logic signed [DATA_W-1:0]      lb_row_0;
    logic signed [DATA_W-1:0]      lb_row_m1;
    logic signed [DATA_W-1:0]      lb_row_m2;

    logic signed [8:0][DATA_W-1:0] win_data;
    logic signed [8:0][PROD_W-1:0] mac_prod;

    // 1. Khối lưu trữ 2 hàng đệm (Line Buffer)
    line_buffer #(
        .W_IN  (W_IN),
        .DATA_W(DATA_W)
    ) u_line_buffer (
        .clk       (clk),
        .rst_n     (rst_n),
        .clr       (clr),
        .shift_en  (shift_en),
        .pixel_in  (pixel_in),
        .row_0_out (lb_row_0),
        .row_m1_out(lb_row_m1),
        .row_m2_out(lb_row_m2)
    );

    // 2. Khối tạo cửa sổ 3x3 và đệm biên 0 (Window Generator)
    window_generator #(
        .DATA_W(DATA_W)
    ) u_window_generator (
        .clk       (clk),
        .rst_n     (rst_n),
        .clr       (clr),
        .shift_en  (shift_en),
        .row_0_in  (lb_row_0),
        .row_m1_in (lb_row_m1),
        .row_m2_in (lb_row_m2),
        .pad_top   (pad_top),
        .pad_bottom(pad_bottom),
        .pad_left  (pad_left),
        .pad_right (pad_right),
        .win_out   (win_data)
    );

    // 3. Khối nhân song song 9 phần tử (MAC Unit)
    mac_unit #(
        .DATA_W(DATA_W),
        .PROD_W(PROD_W)
    ) u_mac_unit (
        .win_in   (win_data),
        .weight_in(weight_in),
        .prod_out (mac_prod)
    );

    // 4. Khối cây cộng 4 tầng và chốt thanh ghi đầu ra (Adder Tree)
    adder_tree #(
        .PROD_W(PROD_W),
        .ACC_W (ACC_W)
    ) u_adder_tree (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (win_valid),
        .prod_in  (mac_prod),
        .valid_out(acc_valid),
        .acc_out  (acc_out)
    );

endmodule