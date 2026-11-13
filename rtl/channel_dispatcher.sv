// =============================================================================
// Module      : channel_dispatcher
// Project     : Thiết kế Phần cứng cho Depthwise Convolution (DWC)
// Description : Khối Giao tiếp Đầu vào & Phân phối Kênh
//               Giải đóng gói (Unpack) từ dữ liệu N_LANES * DATA_W bit từ bộ nhớ
//               ngoài thành N_LANES luồng dữ liệu DATA_W-bit có dấu độc lập.
// =============================================================================

module channel_dispatcher #(
    parameter int N_LANES = 4,
    parameter int DATA_W  = 8
)(
    input  logic [N_LANES*DATA_W-1:0]             in_data_bus,
    output logic signed [N_LANES-1:0][DATA_W-1:0] lane_pixel_out
);

    always_comb begin
        for (int i = 0; i < N_LANES; i++) begin
            lane_pixel_out[i] = $signed(in_data_bus[i * DATA_W +: DATA_W]);
        end
    end

endmodule
