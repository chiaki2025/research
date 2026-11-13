`timescale 1ns / 1ps

module tb_line_buffer;

    localparam int W_IN   = 4; // Test thử với ảnh rộng 4 pixel cho dễ nhìn
    localparam int DATA_W = 8;

    logic                     clk;
    logic                     rst_n;
    logic                     clr;
    logic                     shift_en;
    logic signed [DATA_W-1:0] pixel_in;

    logic signed [DATA_W-1:0] row_0_out;
    logic signed [DATA_W-1:0] row_m1_out;
    logic signed [DATA_W-1:0] row_m2_out;

    // Gọi module line_buffer
    line_buffer #(
        .W_IN  (W_IN),
        .DATA_W(DATA_W)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .clr       (clr),
        .shift_en  (shift_en),
        .pixel_in  (pixel_in),
        .row_0_out (row_0_out),
        .row_m1_out(row_m1_out),
        .row_m2_out(row_m2_out)
    );

    // Tạo xung clock chu kỳ 10ns (100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // Kịch bản bơm 12 pixel (3 hàng x 4 cột: 1..12)
    initial begin
        rst_n    = 0;
        clr      = 0;
        shift_en = 0;
        pixel_in = 0;

        #20 rst_n = 1; // Nhả reset

        // Bơm lần lượt các số từ 1 đến 12 vào mỗi nhịp clock
        for (int val = 1; val <= 12; val++) begin
            @(negedge clk);
            shift_en = 1;
            pixel_in = val;
            #1; // Đợi 1ns để tổ hợp ổn định rồi in kết quả ra console
            $display("Time=%0t | In=%2d | Out(r, r-1, r-2) = [%2d, %2d, %2d]",
                     $time, pixel_in, row_0_out, row_m1_out, row_m2_out);
        end

        @(negedge clk);
        shift_en = 0;
        #20 $finish;
    end

endmodule