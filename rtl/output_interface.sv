// =============================================================================
// Module      : output_interface
// Project     : Thiết kế Phần cứng cho Depthwise Convolution (DWC)
// Description : Khối Giao tiếp Đầu ra
//               Đồng bộ hóa kết quả 32-bit từ N_LANES làn xử lý, đóng gói thành
//               bus N_LANES x 32-bit kèm địa chỉ cơ sở out_base_addr và cờ
//               xác nhận out_valid để ghi vào bộ nhớ kết quả.
// =============================================================================

module output_interface #(
    parameter int N_LANES = 4,
    parameter int ACC_W   = 32,
    parameter int ADDR_W  = 19
)(
    input  logic                                clk,
    input  logic                                rst_n,
    input  logic                                lane_valid_in,
    input  logic signed [N_LANES-1:0][ACC_W-1:0] lane_data_in,
    input  logic [ADDR_W-1:0]                   out_base_addr_in,
    output logic                                out_valid,
    output logic [ADDR_W-1:0]                   out_base_addr,
    output logic signed [N_LANES-1:0][ACC_W-1:0] out_data_bus
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid     <= 1'b0;
            out_base_addr <= '0;
            out_data_bus  <= '0;
        end else begin
            out_valid <= lane_valid_in;
            if (lane_valid_in) begin
                out_base_addr <= out_base_addr_in;
                out_data_bus  <= lane_data_in;
            end
        end
    end

endmodule
