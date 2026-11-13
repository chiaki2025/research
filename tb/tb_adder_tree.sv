`timescale 1ns / 1ps

module tb_adder_tree;

    localparam int PROD_W = 16;
    localparam int ACC_W  = 32;

    logic                          clk;
    logic                          rst_n;
    logic                          valid_in;
    logic signed [8:0][PROD_W-1:0] prod_in;
    logic                          valid_out;
    logic signed [ACC_W-1:0]       acc_out;

    adder_tree #(
        .PROD_W(PROD_W),
        .ACC_W (ACC_W)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_in),
        .prod_in  (prod_in),
        .valid_out(valid_out),
        .acc_out  (acc_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n    = 0;
        valid_in = 0;
        for (int i = 0; i < 9; i++) prod_in[i] = 0;

        #20 rst_n = 1;

        // Test 1: Bơm 9 số dương [10, 20, 30, 40, 50, 60, 70, 80, 90] -> Tổng phải bằng 450
        @(negedge clk);
        valid_in = 1;
        for (int i = 0; i < 9; i++) prod_in[i] = (i + 1) * 10;

        @(posedge clk); #1;
        $display("Test 1 | valid_out=%b | acc_out=%0d (Ky vong: 450)", valid_out, acc_out);

        // Test 2: Bơm cả số âm và dương [-100, 50, -25, 25, 10, -10, 5, -5, -30] -> Tổng phải bằng -80
        @(negedge clk);
        valid_in   = 1;
        prod_in[0] = -16'sd100; prod_in[1] =  16'sd50; prod_in[2] = -16'sd25;
        prod_in[3] =  16'sd25;  prod_in[4] =  16'sd10; prod_in[5] = -16'sd10;
        prod_in[6] =  16'sd5;   prod_in[7] = -16'sd5;  prod_in[8] = -16'sd30;

        @(posedge clk); #1;
        $display("Test 2 | valid_out=%b | acc_out=%0d (Ky vong: -80)", valid_out, acc_out);

        // Test 3: Khi valid_in = 0, valid_out phải hạ về 0
        @(negedge clk);
        valid_in = 0;

        @(posedge clk); #1;
        $display("Test 3 | valid_out=%b | acc_out=%0d (Giu nguyen -80)", valid_out, acc_out);

        #20 $finish;
    end

endmodule