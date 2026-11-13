// =============================================================================
// Module      : control_unit
// Project     : Thiết kế Phần cứng cho Depthwise Convolution (DWC)
// Description : Khối Điều khiển Trung tâm
//               Quản lý máy trạng thái hữu hạn (FSM), bộ đếm nạp trọng số,
//               bộ đếm quét không gian (scan_r, scan_c), theo dõi tọa độ tâm
//               cửa sổ 3x3 (center_r, center_c), sinh cờ đệm biên Zero-Padding,
//               điều phối phân nhóm kênh (group_idx) và đồng bộ địa chỉ đầu ra.
// =============================================================================

module control_unit #(
    parameter int H_IN    = 112,
    parameter int W_IN    = 112,
    parameter int C       = 32,
    parameter int N_LANES = 4,
    parameter int PADDING = 1,
    parameter int W_DEPTH = 9 * C,
    parameter int ADDR_W  = $clog2(H_IN * W_IN * C),
    parameter int G_WIDTH = (C / N_LANES > 1) ? $clog2(C / N_LANES) : 1
)(
    input  logic                        clk,
    input  logic                        rst_n,
    input  logic                        start,
    output logic                        w_wr_en,
    output logic [$clog2(W_DEPTH)-1:0]  w_addr,
    output logic                        in_rd_en,
    output logic [ADDR_W-1:0]           in_base_addr,
    output logic                        force_zero_in,
    output logic [G_WIDTH-1:0]          group_idx,
    output logic                        lane_clr,
    output logic                        lb_shift_en,
    output logic                        wg_shift_en,
    output logic                        win_valid,
    output logic                        pad_top,
    output logic                        pad_bottom,
    output logic                        pad_left,
    output logic                        pad_right,
    output logic [ADDR_W-1:0]           out_base_addr,
    output logic                        busy,
    output logic                        done
);

    // -------------------------------------------------------------------------
    // Hằng số dẫn xuất nội bộ
    // -------------------------------------------------------------------------
    localparam int NUM_GROUPS = C / N_LANES;
    localparam int W_OUT      = H_IN_W_OUT_CALC(W_IN, PADDING);
    localparam int W_CNT_W    = $clog2(W_DEPTH);
    localparam int ROW_W      = $clog2(H_IN + 2);
    localparam int COL_W      = $clog2(W_IN + 1);

    function automatic int H_IN_W_OUT_CALC(input int w_in, input int pad);
        return w_in + 2 * pad - 2;
    endfunction

    // -------------------------------------------------------------------------
    // Định nghĩa các trạng thái của FSM
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE        = 3'd0,
        LOAD_W      = 3'd1,
        INIT_GROUP  = 3'd2,
        STREAM_SCAN = 3'd3,
        NEXT_GROUP  = 3'd4,
        DONE        = 3'd5
    } state_t;

    state_t state_reg, state_next;

    // -------------------------------------------------------------------------
    // Thanh ghi bộ đếm và theo dõi tọa độ
    // -------------------------------------------------------------------------
    logic [W_CNT_W-1:0] w_cnt;
    logic [ROW_W-1:0]   scan_r;
    logic [COL_W-1:0]   scan_c;
    logic [1:0]         flush_cnt;

    // Tọa độ tâm cửa sổ 3x3 hiện tại nằm tại win_reg[1][1] (Chu kỳ T+1)
    logic               center_active;
    logic [ROW_W-1:0]   center_r;
    logic [COL_W-1:0]   center_c;

    // Tọa độ đầu ra hợp lệ trước khi trễ 1 chu kỳ qua adder_tree
    logic [ROW_W-1:0]   out_r_comb;
    logic [COL_W-1:0]   out_c_comb;

    // -------------------------------------------------------------------------
    // 1. Khối chuyển trạng thái FSM (State Register)
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= IDLE;
        end else begin
            state_reg <= state_next;
        end
    end

    // -------------------------------------------------------------------------
    // 2. Logic trạng thái kế tiếp (Next-State Logic)
    // -------------------------------------------------------------------------
    always_comb begin
        state_next = state_reg;
        case (state_reg)
            IDLE: begin
                if (start) begin
                    state_next = LOAD_W;
                end
            end

            LOAD_W: begin
                if (int'(w_cnt) == W_DEPTH - 1) begin
                    state_next = INIT_GROUP;
                end
            end

            INIT_GROUP: begin
                state_next = STREAM_SCAN;
            end

            STREAM_SCAN: begin
                if ((int'(scan_r) == H_IN) && (int'(scan_c) == W_IN - 1)) begin
                    state_next = NEXT_GROUP;
                end
            end

            NEXT_GROUP: begin
                // Chờ hoàn tất dịch điểm cuối và làm rỗng đường ống (adder_tree -> output_interface)
                if (flush_cnt == 2'd3) begin
                    if (int'(group_idx) < NUM_GROUPS - 1) begin
                        state_next = INIT_GROUP;
                    end else begin
                        state_next = DONE;
                    end
                end
            end

            DONE: begin
                state_next = IDLE;
            end

            default: begin
                state_next = IDLE;
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // 3. Quản lý các bộ đếm (w_cnt, scan_r, scan_c, group_idx, flush_cnt)
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_cnt     <= '0;
            scan_r    <= '0;
            scan_c    <= '0;
            group_idx <= '0;
            flush_cnt <= '0;
        end else begin
            case (state_reg)
                IDLE: begin
                    w_cnt     <= '0;
                    scan_r    <= '0;
                    scan_c    <= '0;
                    group_idx <= '0;
                    flush_cnt <= '0;
                end

                LOAD_W: begin
                    if (int'(w_cnt) < W_DEPTH - 1) begin
                        w_cnt <= w_cnt + 1'b1;
                    end else begin
                        w_cnt <= '0;
                    end
                end

                INIT_GROUP: begin
                    scan_r    <= '0;
                    scan_c    <= '0;
                    flush_cnt <= '0;
                end

                STREAM_SCAN: begin
                    if (int'(scan_c) == W_IN - 1) begin
                        scan_c <= '0;
                        scan_r <= scan_r + 1'b1;
                    end else begin
                        scan_c <= scan_c + 1'b1;
                    end
                end

                NEXT_GROUP: begin
                    flush_cnt <= flush_cnt + 1'b1;
                    if (flush_cnt == 2'd3) begin
                        if (int'(group_idx) < NUM_GROUPS - 1) begin
                            group_idx <= group_idx + 1'b1;
                        end
                    end
                end

                DONE: begin
                    group_idx <= '0;
                end

                default: ;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // 4. Theo dõi tọa độ tâm cửa sổ 3x3 (Window Center Tracking)
    //    Khi điểm ảnh tại (scan_r = 1, scan_c = 1) được dịch vào cột phải của
    //    window_generator ở Chu kỳ T, thì tại Chu kỳ T+1 điểm ảnh X[0, 0] hội tụ
    //    tại tâm cửa sổ win_reg[1][1] (center_r = 0, center_c = 0).
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            center_active <= 1'b0;
            center_r      <= '0;
            center_c      <= '0;
        end else begin
            if (state_reg == IDLE || state_reg == INIT_GROUP) begin
                center_active <= 1'b0;
                center_r      <= '0;
                center_c      <= '0;
            end else if (state_reg == STREAM_SCAN) begin
                if (!center_active) begin
                    if ((int'(scan_r) == 1) && (int'(scan_c) == 1)) begin
                        center_active <= 1'b1;
                        center_r      <= '0;
                        center_c      <= '0;
                    end
                end else begin
                    if (int'(center_c) == W_IN - 1) begin
                        center_c <= '0;
                        center_r <= center_r + 1'b1;
                    end else begin
                        center_c <= center_c + 1'b1;
                    end
                end
            end else if (state_reg == NEXT_GROUP) begin
                if (flush_cnt == 2'd0) begin
                    // Dịch nốt điểm ảnh cuối cùng (H_IN - 1, W_IN - 1) vào tâm win_reg[1][1]
                    if (int'(center_c) == W_IN - 1) begin
                        center_c <= '0;
                        center_r <= center_r + 1'b1;
                    end else begin
                        center_c <= center_c + 1'b1;
                    end
                end else if (flush_cnt == 2'd1) begin
                    // Đã hoàn thành toàn bộ H_IN x W_IN vị trí tâm cửa sổ
                    center_active <= 1'b0;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // 5. Tín hiệu điều khiển bộ nhớ, đường ống và cờ đệm biên (Combinational)
    // -------------------------------------------------------------------------
    always_comb begin
        // Giá trị mặc định
        w_wr_en       = 1'b0;
        w_addr        = '0;
        in_rd_en      = 1'b0;
        in_base_addr  = '0;
        force_zero_in = 1'b0;
        lane_clr      = 1'b0;
        lb_shift_en   = 1'b0;
        wg_shift_en   = 1'b0;
        busy          = 1'b0;
        done          = 1'b0;

        case (state_reg)
            IDLE: begin
                busy = 1'b0;
                done = 1'b0;
            end

            LOAD_W: begin
                busy    = 1'b1;
                w_wr_en = 1'b1;
                w_addr  = w_cnt;
            end

            INIT_GROUP: begin
                busy     = 1'b1;
                lane_clr = 1'b1;
            end

            STREAM_SCAN: begin
                busy        = 1'b1;
                lb_shift_en = 1'b1;
                wg_shift_en = 1'b1;
                if (int'(scan_r) < H_IN) begin
                    in_rd_en      = 1'b1;
                    force_zero_in = 1'b0;
                    in_base_addr  = ADDR_W'((int'(scan_r) * W_IN + int'(scan_c)) * C + int'(group_idx) * N_LANES);
                end else begin
                    // Hàng đẩy dữ liệu cuối (Flush row: scan_r == H_IN)
                    in_rd_en      = 1'b0;
                    force_zero_in = 1'b1;
                    in_base_addr  = '0;
                end
            end

            NEXT_GROUP: begin
                busy          = 1'b1;
                in_rd_en      = 1'b0;
                force_zero_in = 1'b1;
                in_base_addr  = '0;
                // Tại chu kỳ đầu của NEXT_GROUP, dịch thêm 1 nhịp để đưa điểm (H_IN-1, W_IN-1) vào tâm cửa sổ
                if (flush_cnt == 2'd0) begin
                    lb_shift_en = 1'b1;
                    wg_shift_en = 1'b1;
                end
            end

            DONE: begin
                busy = 1'b0;
                done = 1'b1;
            end

            default: ;
        endcase
    end

    // Sinh cờ đệm biên và win_valid ứng với tâm cửa sổ (center_r, center_c)
    always_comb begin
        pad_top    = 1'b0;
        pad_bottom = 1'b0;
        pad_left   = 1'b0;
        pad_right  = 1'b0;
        win_valid  = 1'b0;
        out_r_comb = '0;
        out_c_comb = '0;

        if (center_active) begin
            if (PADDING == 1) begin
                // Chế độ SAME: có đệm biên 0, toàn bộ H_IN x W_IN tâm cửa sổ đều hợp lệ
                pad_top    = (int'(center_r) == 0);
                pad_bottom = (int'(center_r) == H_IN - 1);
                pad_left   = (int'(center_c) == 0);
                pad_right  = (int'(center_c) == W_IN - 1);
                win_valid  = 1'b1;
                out_r_comb = center_r;
                out_c_comb = center_c;
            end else begin
                // Chế độ VALID: không đệm biên, chỉ lấy vùng tâm từ [1..H_IN-2] x [1..W_IN-2]
                if ((int'(center_r) >= 1) && (int'(center_r) <= H_IN - 2) &&
                    (int'(center_c) >= 1) && (int'(center_c) <= W_IN - 2)) begin
                    win_valid  = 1'b1;
                    out_r_comb = center_r - 1'b1;
                    out_c_comb = center_c - 1'b1;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // 6. Đồng bộ địa chỉ đầu ra khớp với độ trễ 1 chu kỳ của adder_tree
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_base_addr <= '0;
        end else if (win_valid) begin
            out_base_addr <= ADDR_W'((int'(out_r_comb) * W_OUT + int'(out_c_comb)) * C + int'(group_idx) * N_LANES);
        end
    end

endmodule
