`timescale 1ns / 1ps

module tb_processing_lane;

    localparam int W_IN   = 4;
    localparam int DATA_W = 8;
    localparam int PROD_W = 16;
    localparam int ACC_W  = 32;

    logic                          clk;
    logic                          rst_n;
    logic                          clr;
    logic                          shift_en;
    logic                          win_valid;
    logic                          pad_top;
    logic                          pad_bottom;
    logic                          pad_left;
    logic                          pad_right;
    logic signed [DATA_W-1:0]      pixel_in;
    logic signed [8:0][DATA_W-1:0] weight_in;
    logic                          acc_valid;
    logic signed [ACC_W-1:0]       acc_out;

    processing_lane #(
        .W_IN  (W_IN),
        .DATA_W(DATA_W),
        .PROD_W(PROD_W),
        .ACC_W (ACC_W)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .clr       (clr),
        .shift_en  (shift_en),
        .win_valid (win_valid),
        .pad_top   (pad_top),
        .pad_bottom(pad_bottom),
        .pad_left  (pad_left),
        .pad_right (pad_right),
        .pixel_in  (pixel_in),
        .weight_in (weight_in),
        .acc_valid (acc_valid),
        .acc_out   (acc_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0; clr = 0; shift_en = 0; win_valid = 0;
        pad_top = 0; pad_bottom = 0; pad_left = 0; pad_right = 0;
        pixel_in = 0;

        // Đặt cả 9 trọng số bằng +1 để tính tổng 9 ô trong cửa sổ 3x3
        for (int i = 0; i < 9; i++) weight_in[i] = 8'sd1;

        #20 rst_n = 1;

        // Bơm lần lượt 12 pixel đầu tiên (3 hàng x 4 cột: 1..12)
        for (int val = 1; val <= 12; val++) begin
            @(negedge clk);
            shift_en  = 1;
            pixel_in  = val;
            // Khi val = 12, cột [3,7,11] của nhịp trước đã nằm gọn trong window_generator (tâm 6)
            win_valid = (val == 12) ? 1'b1 : 1'b0;
        end

        // Thêm 1 nhịp để cột [4,8,12] chốt vào window_generator (tâm 7)
        @(negedge clk);
        shift_en  = 0;
        win_valid = 1;

        @(negedge clk);
        win_valid = 0;

        #30 $finish;

        @(negedge clk);
        shift_en  = 0;
        win_valid = 0;

        #30 $finish;
    end

    // Tự động in kết quả mỗi khi acc_valid bật lên 1
    always @(posedge clk) begin
        #1;
        if (acc_valid) begin
            $display("Time=%0t | acc_valid=1 | Tong tich chap acc_out = %0d", $time, signed'(acc_out));
        end
    end

endmodule