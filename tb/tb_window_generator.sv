`timescale 1ns / 1ps

module tb_window_generator;

    localparam int DATA_W = 8;

    logic                          clk;
    logic                          rst_n;
    logic                          clr;
    logic                          shift_en;
    logic signed [DATA_W-1:0]      row_0_in;
    logic signed [DATA_W-1:0]      row_m1_in;
    logic signed [DATA_W-1:0]      row_m2_in;
    logic                          pad_top;
    logic                          pad_bottom;
    logic                          pad_left;
    logic                          pad_right;
    logic signed [8:0][DATA_W-1:0] win_out;

    window_generator #(
        .DATA_W(DATA_W)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .clr       (clr),
        .shift_en  (shift_en),
        .row_0_in  (row_0_in),
        .row_m1_in (row_m1_in),
        .row_m2_in (row_m2_in),
        .pad_top   (pad_top),
        .pad_bottom(pad_bottom),
        .pad_left  (pad_left),
        .pad_right (pad_right),
        .win_out   (win_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task print_window(string title);
        #1;
        $display("--- %s ---", title);
        $display("[%3d, %3d, %3d]", signed'(win_out[0]), signed'(win_out[1]), signed'(win_out[2]));
        $display("[%3d, %3d, %3d]", signed'(win_out[3]), signed'(win_out[4]), signed'(win_out[5]));
        $display("[%3d, %3d, %3d]", signed'(win_out[6]), signed'(win_out[7]), signed'(win_out[8]));
    endtask

    initial begin
        rst_n = 0; clr = 0; shift_en = 0;
        row_0_in = 0; row_m1_in = 0; row_m2_in = 0;
        pad_top = 0; pad_bottom = 0; pad_left = 0; pad_right = 0;

        #20 rst_n = 1;

        // Nạp lần lượt 3 cột dọc: [1,5,9], [2,6,10], [3,7,11]
        @(negedge clk); shift_en = 1; row_m2_in = 1; row_m1_in = 5; row_0_in = 9;
        @(negedge clk);               row_m2_in = 2; row_m1_in = 6; row_0_in = 10;
        @(negedge clk);               row_m2_in = 3; row_m1_in = 7; row_0_in = 11;

        @(negedge clk); shift_en = 0;

        // Test 1: Giữa ảnh (không padding)
        print_window("Test 1: Khong Padding (Giua anh)");

        // Test 2: Góc trên - trái (pad_top=1, pad_left=1)
        pad_top = 1; pad_left = 1;
        print_window("Test 2: Pad Top + Pad Left");

        // Test 3: Góc dưới - phải (pad_bottom=1, pad_right=1)
        pad_top = 0; pad_left = 0; pad_bottom = 1; pad_right = 1;
        print_window("Test 3: Pad Bottom + Pad Right");

        #20 $finish;
    end

endmodule