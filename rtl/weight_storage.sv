// =============================================================================
// Module      : weight_storage
// Project     : Thiết kế Phần cứng cho Depthwise Convolution (DWC)
// Description : Khối Lưu trữ Trọng số
//               Lưu trữ toàn bộ 3 x 3 x C trọng số lọc (INT8 có dấu) và cấp phát
//               đồng thời N_LANES x 9 trọng số cho N_LANES làn xử lý theo chỉ số
//               nhóm kênh group_idx.
// =============================================================================

module weight_storage #(
    parameter int C       = 32,
    parameter int N_LANES = 4,
    parameter int DATA_W  = 8,
    parameter int W_DEPTH = 9 * C,
    parameter int G_WIDTH = (C / N_LANES > 1) ? $clog2(C / N_LANES) : 1
)(
    input  logic                                      clk,
    input  logic                                      rst_n,
    input  logic                                      w_wr_en,
    input  logic [$clog2(W_DEPTH)-1:0]                w_wr_addr,
    input  logic signed [DATA_W-1:0]                  w_wr_data,
    input  logic [G_WIDTH-1:0]                        group_idx,
    output logic signed [N_LANES-1:0][8:0][DATA_W-1:0] lane_weights_out
);

    // Mảng thanh ghi lưu trữ toàn bộ 9 * C trọng số
    logic signed [DATA_W-1:0] weight_mem [0:W_DEPTH-1];

    // Quá trình ghi trọng số đồng bộ
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int idx = 0; idx < W_DEPTH; idx++) begin
                weight_mem[idx] <= '0;
            end
        end else if (w_wr_en) begin
            weight_mem[w_wr_addr] <= w_wr_data;
        end
    end

    // Đọc trọng số song song theo nhóm kênh group_idx (cấu trúc Channel-Last: k * C + ch)
    always_comb begin
        for (int i = 0; i < N_LANES; i++) begin
            for (int k = 0; k < 9; k++) begin
                lane_weights_out[i][k] = weight_mem[k * C + (int'(group_idx) * N_LANES + i)];
            end
        end
    end

endmodule
