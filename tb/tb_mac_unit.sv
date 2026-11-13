`timescale 1ns / 1ps

module tb_mac_unit;

    localparam int DATA_W = 8;
    localparam int PROD_W = 16;

    logic signed [8:0][DATA_W-1:0] win_in;
    logic signed [8:0][DATA_W-1:0] weight_in;
    logic signed [8:0][PROD_W-1:0] prod_out;

    mac_unit #(
        .DATA_W(DATA_W),
        .PROD_W(PROD_W)
    ) dut (
        .win_in   (win_in),
        .weight_in(weight_in),
        .prod_out (prod_out)
    );

    initial begin
        // Khởi tạo giá trị thử nghiệm (có cả số âm để test signed)
        for (int i = 0; i < 9; i++) begin
            win_in[i]    = i + 1;      // 1, 2, 3, ..., 9
            weight_in[i] = (i % 2 == 0) ? 8'sd2 : -8'sd3; // Xen kẽ +2 và -3
        end

        #10; // Đợi 10ns cho mạch tổ hợp tính xong

        $display("--- Ket qua MAC Unit ---");
        for (int i = 0; i < 9; i++) begin
            $display("k=%0d | win=%3d * weight=%3d = prod=%5d",
                     i, signed'(win_in[i]), signed'(weight_in[i]), signed'(prod_out[i]));
        end

        #10 $finish;
    end

endmodule