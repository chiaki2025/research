`timescale 1ns / 1ps

module window_generator #(
    parameter int DATA_W = 8
)(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     clr,         // Xóa đồng bộ 9 thanh ghi cửa sổ về 0
    input  logic                     shift_en,    // Cho phép dịch cột mới vào cửa sổ 3x3
    input  logic signed [DATA_W-1:0] row_0_in,    // Điểm ảnh hàng r   (từ line_buffer.row_0_out)
    input  logic signed [DATA_W-1:0] row_m1_in,   // Điểm ảnh hàng r-1 (từ line_buffer.row_m1_out)
    input  logic signed [DATA_W-1:0] row_m2_in,   // Điểm ảnh hàng r-2 (từ line_buffer.row_m2_out)

    // 4 cờ báo tâm cửa sổ đang nằm tại biên ảnh
    input  logic                     pad_top,
    input  logic                     pad_bottom,
    input  logic                     pad_left,
    input  logic                     pad_right,

    // 9 phần tử cửa sổ 3x3 đã qua xử lý đệm biên (trải phẳng theo thứ tự hàng -> cột)
    output logic signed [8:0][DATA_W-1:0] win_out
);

    // Mảng thanh ghi dịch 3x3: win_reg[hàng][cột]
    logic signed [DATA_W-1:0] win_reg [0:2][0:2];

    // 1. Mạch tuần tự: Dịch ngang từ phải sang trái tại sườn dương clk
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int r = 0; r < 3; r++) begin
                for (int c = 0; c < 3; c++) begin
                    win_reg[r][c] <= '0;
                end
            end
        end else if (clr) begin
            for (int r = 0; r < 3; r++) begin
                for (int c = 0; c < 3; c++) begin
                    win_reg[r][c] <= '0;
                end
            end
        end else if (shift_en) begin
            // Dịch cột 1 sang cột 0, cột 2 sang cột 1
            for (int r = 0; r < 3; r++) begin
                win_reg[r][0] <= win_reg[r][1];
                win_reg[r][1] <= win_reg[r][2];
            end

            // Nạp cột dọc mới vào cột 2 (ngoài cùng bên phải)
            win_reg[0][2] <= row_m2_in; // Hàng trên (r-2)
            win_reg[1][2] <= row_m1_in; // Hàng giữa (r-1) -> nhịp sau sẽ vào tâm win_reg[1][1]
            win_reg[2][2] <= row_0_in;  // Hàng dưới (r)
        end
    end

    // 2. Mạch tổ hợp: Xuất 9 phần tử và che số 0 ở viền (Zero-Padding Masking)
    assign win_out[0] = (pad_top    || pad_left)  ? '0 : win_reg[0][0]; // Góc trên - trái
    assign win_out[1] = (pad_top)                 ? '0 : win_reg[0][1]; // Cạnh trên - giữa
    assign win_out[2] = (pad_top    || pad_right) ? '0 : win_reg[0][2]; // Góc trên - phải
    assign win_out[3] = (pad_left)                ? '0 : win_reg[1][0]; // Cạnh trái - giữa
    assign win_out[4] =                                  win_reg[1][1]; // Tâm cửa sổ (luôn giữ nguyên)
    assign win_out[5] = (pad_right)               ? '0 : win_reg[1][2]; // Cạnh phải - giữa
    assign win_out[6] = (pad_bottom || pad_left)  ? '0 : win_reg[2][0]; // Góc dưới - trái
    assign win_out[7] = (pad_bottom)              ? '0 : win_reg[2][1]; // Cạnh dưới - giữa
    assign win_out[8] = (pad_bottom || pad_right) ? '0 : win_reg[2][2]; // Góc dưới - phải

endmodule