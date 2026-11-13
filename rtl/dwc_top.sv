// =============================================================================
// Module      : dwc_top
// Project     : Thiết kế Phần cứng cho Depthwise Convolution (DWC)
// Description : Khối Tích hợp Cấp cao nhất (Top-Level Module)
//               Kết nối hoàn chỉnh nhánh Điều khiển & Giao tiếp (control_unit,
//               weight_storage, channel_dispatcher, output_interface) với mảng
//               N_LANES làn xử lý song song (processing_lane).
// =============================================================================

module dwc_top #(
    parameter int H_IN    = 112,
    parameter int W_IN    = 112,
    parameter int C       = 32,
    parameter int N_LANES = 4,
    parameter int PADDING = 1,
    parameter int DATA_W  = 8,
    parameter int PROD_W  = 16,
    parameter int ACC_W   = 32,
    parameter int W_DEPTH = 9 * C,
    parameter int ADDR_W  = $clog2(H_IN * W_IN * C),
    parameter int G_WIDTH = (C / N_LANES > 1) ? $clog2(C / N_LANES) : 1
)(
    input  logic                                clk,
    input  logic                                rst_n,
    input  logic                                start,

    // Giao tiếp Bộ nhớ Trọng số (Weight Memory Interface)
    output logic [$clog2(W_DEPTH)-1:0]          w_rd_addr,
    input  logic signed [DATA_W-1:0]            w_rd_data,

    // Giao tiếp Bộ nhớ Đặc trưng Đầu vào (Input Feature Map Interface)
    output logic                                in_rd_en,
    output logic [ADDR_W-1:0]                   in_base_addr,
    input  logic [N_LANES*DATA_W-1:0]           in_data_bus,

    // Giao tiếp Bộ nhớ Đặc trưng Đầu ra (Output Feature Map Interface)
    output logic                                out_valid,
    output logic [ADDR_W-1:0]                   out_base_addr,
    output logic signed [N_LANES-1:0][ACC_W-1:0] out_data_bus,

    // Tín hiệu Trạng thái (Status Interface)
    output logic                                busy,
    output logic                                done
);

    // Khai báo dây nối nội bộ
    logic                                      w_wr_en_w;
    logic [$clog2(W_DEPTH)-1:0]                w_addr_w;
    logic [G_WIDTH-1:0]                        group_idx_w;
    logic                                      force_zero_in_w;
    logic                                      lane_clr_w;
    logic                                      lb_shift_en_w;
    logic                                      wg_shift_en_w;
    logic                                      win_valid_w;
    logic                                      pad_top_w, pad_bottom_w, pad_left_w, pad_right_w;
    logic [ADDR_W-1:0]                         cu_out_base_addr_w;

    logic [N_LANES*DATA_W-1:0]                 muxed_in_data_bus_w;
    logic signed [N_LANES-1:0][DATA_W-1:0]     lane_pixels_w;
    logic signed [N_LANES-1:0][8:0][DATA_W-1:0] lane_weights_w;
    logic [N_LANES-1:0]                        lane_valid_out_w;
    logic signed [N_LANES-1:0][ACC_W-1:0]      lane_data_out_w;

    assign w_rd_addr           = w_addr_w;
    assign muxed_in_data_bus_w = force_zero_in_w ? '0 : in_data_bus;

    // 1. Khối Điều khiển Trung tâm
    control_unit #(
        .H_IN(H_IN), .W_IN(W_IN), .C(C),
        .N_LANES(N_LANES), .PADDING(PADDING),
        .W_DEPTH(W_DEPTH), .ADDR_W(ADDR_W), .G_WIDTH(G_WIDTH)
    ) u_control_unit (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (start),
        .w_wr_en       (w_wr_en_w),
        .w_addr        (w_addr_w),
        .in_rd_en      (in_rd_en),
        .in_base_addr  (in_base_addr),
        .force_zero_in (force_zero_in_w),
        .group_idx     (group_idx_w),
        .lane_clr      (lane_clr_w),
        .lb_shift_en   (lb_shift_en_w),
        .wg_shift_en   (wg_shift_en_w),
        .win_valid     (win_valid_w),
        .pad_top       (pad_top_w),
        .pad_bottom    (pad_bottom_w),
        .pad_left      (pad_left_w),
        .pad_right     (pad_right_w),
        .out_base_addr (cu_out_base_addr_w),
        .busy          (busy),
        .done          (done)
    );

    // 2. Khối Lưu trữ Trọng số
    weight_storage #(
        .C(C), .N_LANES(N_LANES), .DATA_W(DATA_W),
        .W_DEPTH(W_DEPTH), .G_WIDTH(G_WIDTH)
    ) u_weight_storage (
        .clk              (clk),
        .rst_n            (rst_n),
        .w_wr_en          (w_wr_en_w),
        .w_wr_addr        (w_addr_w),
        .w_wr_data        (w_rd_data),
        .group_idx        (group_idx_w),
        .lane_weights_out (lane_weights_w)
    );

    // 3. Khối Phân phối Kênh
    channel_dispatcher #(
        .N_LANES(N_LANES), .DATA_W(DATA_W)
    ) u_channel_dispatcher (
        .in_data_bus    (muxed_in_data_bus_w),
        .lane_pixel_out (lane_pixels_w)
    );

    // 4. Mảng N Làn Xử lý Song song
    generate
        for (genvar i = 0; i < N_LANES; i++) begin : gen_lanes
            processing_lane #(
                .W_IN(W_IN), .DATA_W(DATA_W), .PROD_W(PROD_W), .ACC_W(ACC_W)
            ) u_lane (
                .clk            (clk),
                .rst_n          (rst_n),
                .lane_clr       (lane_clr_w),
                .lb_shift_en    (lb_shift_en_w),
                .wg_shift_en    (wg_shift_en_w),
                .win_valid      (win_valid_w),
                .pad_top        (pad_top_w),
                .pad_bottom     (pad_bottom_w),
                .pad_left       (pad_left_w),
                .pad_right      (pad_right_w),
                .pixel_in       (lane_pixels_w[i]),
                .weights_in     (lane_weights_w[i]),
                .lane_valid_out (lane_valid_out_w[i]),
                .lane_data_out  (lane_data_out_w[i])
            );
        end
    endgenerate

    // 5. Khối Giao tiếp Đầu ra
    output_interface #(
        .N_LANES(N_LANES), .ACC_W(ACC_W), .ADDR_W(ADDR_W)
    ) u_output_interface (
        .clk              (clk),
        .rst_n            (rst_n),
        .lane_valid_in    (lane_valid_out_w[0]),
        .lane_data_in     (lane_data_out_w),
        .out_base_addr_in (cu_out_base_addr_w),
        .out_valid        (out_valid),
        .out_base_addr    (out_base_addr),
        .out_data_bus     (out_data_bus)
    );

endmodule
