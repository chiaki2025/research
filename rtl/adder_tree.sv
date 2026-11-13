`timescale 1ns / 1ps

module adder_tree #(
    parameter int PROD_W = 16,
    parameter int ACC_W  = 32
)(
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic                          valid_in,  // Báo hiệu 9 tích số đầu vào đang hợp lệ
    input  logic signed [8:0][PROD_W-1:0] prod_in,   // 9 tích số 16-bit có dấu từ mac_unit

    output logic                          valid_out, // Báo hiệu tổng tích chập ở acc_out đã sẵn sàng
    output logic signed [ACC_W-1:0]       acc_out    // Tổng tích chập 32-bit có dấu xuất sang khối lượng tử hóa
);

    // Các tín hiệu trung gian cho cây cộng 4 tầng (mở rộng bit từng tầng để không bao giờ tràn số)
    logic signed [PROD_W:0]   sum_l1 [0:3]; // Tầng 1: 4 cặp cộng (17-bit)
    logic signed [PROD_W+1:0] sum_l2 [0:1]; // Tầng 2: 2 cặp cộng (18-bit)
    logic signed [PROD_W+2:0] sum_l3;       // Tầng 3: 1 cặp cộng (19-bit)
    logic signed [ACC_W-1:0]  sum_comb;     // Tầng 4: Tổng cuối cùng mở rộng đủ 32-bit

    // Tầng 1: Cộng 4 cặp đầu tiên song song (phần tử thứ 8 đi thẳng xuống tầng 4)
    assign sum_l1[0] = signed'(prod_in[0]) + signed'(prod_in[1]);
    assign sum_l1[1] = signed'(prod_in[2]) + signed'(prod_in[3]);
    assign sum_l1[2] = signed'(prod_in[4]) + signed'(prod_in[5]);
    assign sum_l1[3] = signed'(prod_in[6]) + signed'(prod_in[7]);

    // Tầng 2: Cộng tiếp 2 cặp
    assign sum_l2[0] = sum_l1[0] + sum_l1[1];
    assign sum_l2[1] = sum_l1[2] + sum_l1[3];

    // Tầng 3: Cộng tổng 8 phần tử đầu
    assign sum_l3 = sum_l2[0] + sum_l2[1];

    // Tầng 4: Cộng nốt phần tử thứ 9 (prod_in[8]) và mở rộng dấu lên 32-bit
    assign sum_comb = ACC_W'(sum_l3) + ACC_W'(signed'(prod_in[8]));

    // Chốt thanh ghi đầu ra tại sườn dương xung clock
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_out   <= '0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= valid_in;
            if (valid_in) begin
                acc_out <= sum_comb;
            end
        end
    end

endmodule