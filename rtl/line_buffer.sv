`timescale 1ns / 1ps

module line_buffer #(
    parameter int W_IN   = 112, // Chiều rộng ảnh đầu vào
    parameter int DATA_W = 8    // Độ rộng bit mỗi điểm ảnh
)(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     clr,       // Xóa đồng bộ khi đổi nhóm kênh
    input  logic                     shift_en,  // Cho phép dịch điểm ảnh mới vào
    input  logic signed [DATA_W-1:0] pixel_in,  // Điểm ảnh hàng hiện tại r

    output logic signed [DATA_W-1:0] row_0_out,  // Điểm ảnh hàng r
    output logic signed [DATA_W-1:0] row_m1_out, // Điểm ảnh hàng r-1
    output logic signed [DATA_W-1:0] row_m2_out  // Điểm ảnh hàng r-2
);

    // 2 băng chuyền thanh ghi dịch lưu 2 hàng trước đó
    logic signed [DATA_W-1:0] buf_row1 [0:W_IN-1];
    logic signed [DATA_W-1:0] buf_row2 [0:W_IN-1];

    // Mạch tuần tự: Dịch dữ liệu tại sườn dương xung clock
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < W_IN; i++) begin
                buf_row1[i] <= '0;
                buf_row2[i] <= '0;
            end
        end else if (clr) begin
            for (int i = 0; i < W_IN; i++) begin
                buf_row1[i] <= '0;
                buf_row2[i] <= '0;
            end
        end else if (shift_en) begin
            // Đẩy pixel mới vào đầu ống 1, các phần tử cũ dịch sang phải 1 vị trí
            buf_row1[0] <= pixel_in;
            for (int i = 1; i < W_IN; i++) begin
                buf_row1[i] <= buf_row1[i-1];
            end

            // Phần tử cuối ống 1 đẩy nối tiếp sang đầu ống 2
            buf_row2[0] <= buf_row1[W_IN-1];
            for (int i = 1; i < W_IN; i++) begin
                buf_row2[i] <= buf_row2[i-1];
            end
        end
    end

    // Mạch tổ hợp: Xuất đồng thời 3 điểm ảnh cùng cột của 3 hàng liên tiếp
    assign row_0_out  = pixel_in;
    assign row_m1_out = buf_row1[W_IN-1];
    assign row_m2_out = buf_row2[W_IN-1];

endmodule