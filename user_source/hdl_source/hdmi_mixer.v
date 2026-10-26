module hdmi_mixer #(
    parameter H_OFFSET = 128,
    parameter V_OFFSET = 60,
    parameter IMG_WIDTH = 1280,
    parameter IMG_HEIGHT = 720,
    parameter integer DEBUG_MODE = 0
)(
    input wire        I_clk,
    input wire        I_rst_n,

    input wire        I_video_vsync,
    input wire        I_video_hsync,
    input wire        I_video_de,
    input wire        I_video_user,
    input wire        I_video_last,

    input wire[3:0]   I_debug_status,
    input wire[2:0]   I_display_mode,
    input wire        I_awb_enable,
    input wire[1:0]   I_gain_level,
    input wire        I_gain_level_update_toggle,
    input wire        I_inspection_object,
    input wire        I_inspection_baseline_valid,
    input wire[1:0]   I_inspection_result_code,
    input wire[23:0]  I_inspection_black_count_bcd,
    input wire[10:0]  I_inspection_bbox_min_x,
    input wire[10:0]  I_inspection_bbox_max_x,
    input wire[10:0]  I_inspection_bbox_min_y,
    input wire[10:0]  I_inspection_bbox_max_y,
    input wire        I_shape_valid,
    input wire[1:0]   I_shape_result_code,
    input wire[10:0]  I_shape_score,
    input wire[8:0]   I_shape_angle,
    input wire        I_quality_valid,
    input wire[6:0]   I_quality_score,
    input wire[2:0]   I_quality_grade,
    input wire[19:0]  I_pass_count_bcd,
    input wire[19:0]  I_fail_count_bcd,
    input wire        I_video_latency_valid,
    input wire[11:0]  I_video_latency_ms,
    input wire[7:0]   I_camera_fps_bcd,

    output wire       O_video_rd_en,
    input wire[23:0]  I_video_rd_data,

    output reg        O_hdmi_vsync,
    output reg        O_hdmi_hsync,
    output reg        O_hdmi_de,
    output reg[23:0]  O_hdmi_data
);

// Runs entirely in the HDMI pixel clock domain. The two-cycle input delay
// keeps DDR-read pixels aligned with the fixed timing and OSD coordinates.
    reg        S_video_vsync_1d;
    reg        S_video_vsync_2d;
    reg        S_video_hsync_1d;
    reg        S_video_hsync_2d;
    reg        S_video_de_1d;
    reg        S_video_de_2d;
    reg [23:0] S_video_data_1d;
    reg [23:0] S_video_data_2d;
    reg [11:0] S_x;
    reg [11:0] S_y;
    reg [11:0] S_x_1d;
    reg [11:0] S_x_2d;
    reg [11:0] S_y_1d;
    reg [11:0] S_y_2d;

    reg        S_osd_hit;
    reg [23:0] S_osd_color;
    reg [11:0] S_logo_x;
    reg [11:0] S_logo_y;
    reg [3:0]  S_char_idx;
    reg [2:0]  S_char_row;
    reg [2:0]  S_char_col;
    reg [4:0]  S_char_bits;
    reg        S_char_on;
    reg        S_logo_blue_on;
    reg        S_logo_red_on;
    reg [11:0] S_logo_tmp_y;
    reg [3:0]  S_logo_red_band;
    reg [11:0] S_logo_red_x_start;
    reg [11:0] S_logo_red_x_end;
    reg [14:0] S_logo_addr;
    wire[24:0] S_logo_pixel;
    reg [31:0] S_frame_cnt;
    reg [11:0] S_dyn_x;
    reg [11:0] S_dyn_y;
    reg [3:0]  S_dyn_char;
    reg [2:0]  S_dyn_col;
    reg [2:0]  S_dyn_row;
    reg [4:0]  S_dyn_bits;
    reg        S_dyn_on;
    reg [3:0]  S_dyn_digit_idx;
    reg [11:0] S_dyn_digit_x;
    reg [6:0]  S_dyn_seg;
    reg [4:0]  S_mode_char_idx;
    reg [7:0]  S_mode_char;
    reg [2:0]  S_mode_col;
    reg [2:0]  S_mode_row;
    reg [4:0]  S_mode_bits;
    reg        S_mode_on;
    reg [4:0]  S_gain_char_idx;
    reg [7:0]  S_gain_char;
    reg [2:0]  S_gain_col;
    reg [2:0]  S_gain_row;
    reg [4:0]  S_gain_bits;
    reg        S_gain_on;
    reg [4:0]  S_status_char_idx;
    reg [7:0]  S_status_char;
    reg [2:0]  S_status_col;
    reg [2:0]  S_status_row;
    reg [4:0]  S_status_bits;
    reg        S_status_on;
    reg [4:0]  S_result_char_idx;
    reg [7:0]  S_result_char;
    reg [2:0]  S_result_row;
    reg [4:0]  S_result_bits;
    reg        S_result_on;
    reg [4:0]  S_shape_char_idx;
    reg [7:0]  S_shape_char;
    reg [2:0]  S_shape_row;
    reg [4:0]  S_shape_bits;
    reg        S_shape_on;
    reg [4:0]  S_shape_info_char_idx;
    reg [7:0]  S_shape_info_char;
    reg [3:0]  S_shape_info_digit;
    reg [2:0]  S_shape_info_row;
    reg [4:0]  S_shape_info_bits;
    reg        S_shape_info_on;
    reg [7:0]  S_dyn_glyph_char;
    reg [3:0]  S_dyn_glyph_digit;
    reg [2:0]  S_dyn_glyph_row;
    reg [2:0]  S_dyn_glyph_kind;
    reg        S_dyn_glyph_is_digit;
    reg        S_dyn_glyph_active;
    reg [4:0]  S_dyn_glyph_bits;
    reg [11:0] S_count_x;
    reg [3:0]  S_count_char_idx;
    reg [7:0]  S_count_char;
    reg [3:0]  S_count_digit;
    reg [2:0]  S_count_row;
    reg [4:0]  S_count_bits;
    reg        S_count_on;
    reg [11:0] S_track_osd_x;
    reg [4:0]  S_track_char_idx;
    reg [7:0]  S_track_char;
    reg [3:0]  S_track_digit;
    reg [2:0]  S_track_row;
    reg [4:0]  S_track_bits;
    reg        S_track_on;
    reg        S_track_is_digit;
    reg [2:0]  S_display_mode_frame;
    reg [1:0]  S_gain_level_bus_1d;
    reg [1:0]  S_gain_level_bus_2d;
    reg        S_gain_level_toggle_1d;
    reg        S_gain_level_toggle_2d;
    reg        S_gain_level_toggle_seen;
    reg [1:0]  S_gain_level_captured;
    reg [1:0]  S_gain_level_frame;
    (* ASYNC_REG = "TRUE" *) reg [1:0] S_awb_enable_sync;
    reg S_awb_enable_frame;
    reg [2:0] S_awb_char_idx;
    reg [2:0] S_awb_col;
    reg [7:0] S_awb_char;
    reg [2:0] S_awb_row;
    reg [4:0] S_awb_bits;
    reg        S_inspection_object_frame;
    reg        S_inspection_baseline_valid_frame;
    reg [1:0]  S_inspection_result_code_frame;
    reg [23:0] S_inspection_black_count_bcd_frame;
    reg [10:0] S_inspection_bbox_min_x_frame;
    reg [10:0] S_inspection_bbox_max_x_frame;
    reg [10:0] S_inspection_bbox_min_y_frame;
    reg [10:0] S_inspection_bbox_max_y_frame;
    reg        S_shape_valid_frame;
    reg [1:0]  S_shape_result_code_frame;
    reg [10:0] S_shape_score_frame;
    reg [8:0]  S_shape_angle_frame;
    reg S_quality_valid_frame;
    reg [2:0] S_quality_grade_frame;
    reg [19:0] S_pass_count_bcd_frame;
    reg [19:0] S_fail_count_bcd_frame;
    reg [11:0] S_track_anchor_x_frame;
    reg [11:0] S_track_anchor_y_frame;
    reg [10:0] S_track_center_x_frame;
    reg [10:0] S_track_center_y_frame;
    reg        S_video_latency_valid_frame;
    reg [11:0] S_video_latency_ms_frame;
    reg [7:0]  S_camera_fps_bcd_frame;
    wire [11:0] S_bbox_center_x_sum =
        {1'b0,I_inspection_bbox_min_x} + {1'b0,I_inspection_bbox_max_x};
    wire [11:0] S_bbox_center_y_sum =
        {1'b0,I_inspection_bbox_min_y} + {1'b0,I_inspection_bbox_max_y};
    reg [11:0] S_quality_score_bcd_frame;
    reg [6:0] S_quality_shift;
    reg [3:0] S_quality_count;
    reg [11:0] S_quality_adjust;
    always @* begin
        S_quality_adjust = S_quality_score_bcd_frame;
        if(S_quality_adjust[3:0]>=5)
            S_quality_adjust[3:0] = S_quality_adjust[3:0]+4'd3;
        if(S_quality_adjust[7:4]>=5)
            S_quality_adjust[7:4] = S_quality_adjust[7:4]+4'd3;
        if(S_quality_adjust[11:8]>=5)
            S_quality_adjust[11:8] = S_quality_adjust[11:8]+4'd3;
    end
    reg [4:0] S_quality_char_idx;
    reg [7:0] S_quality_char;
    reg [2:0] S_quality_row;
    reg [4:0] S_quality_bits;
    reg [8:0]  S_angle_shift;
    reg [11:0] S_angle_bcd;
    reg [3:0]  S_angle_count;
    reg [11:0] S_angle_adjust;

    always @* begin
        S_angle_adjust = S_angle_bcd;
        if(S_angle_bcd[3:0] >= 5)
            S_angle_adjust[3:0] = S_angle_bcd[3:0] + 4'd3;
        if(S_angle_bcd[7:4] >= 5)
            S_angle_adjust[7:4] = S_angle_bcd[7:4] + 4'd3;
        if(S_angle_bcd[11:8] >= 5)
            S_angle_adjust[11:8] = S_angle_bcd[11:8] + 4'd3;
    end
    // Nine short cycles after SOF, completed long before the text at y=232.
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_angle_shift <= 0; S_angle_bcd <= 0; S_angle_count <= 0;
        end else if(I_video_user) begin
            S_angle_shift <= I_shape_angle;
            S_angle_bcd <= 0; S_angle_count <= 9;
        end else if(S_angle_count != 0) begin
            S_angle_bcd <= {S_angle_adjust[10:0],S_angle_shift[8]};
            S_angle_shift <= {S_angle_shift[7:0],1'b0};
            S_angle_count <= S_angle_count - 1'b1;
        end
    end
    reg [3:0]  S_cnt_d0;
    reg [3:0]  S_cnt_d1;
    reg [3:0]  S_cnt_d2;
    reg [3:0]  S_cnt_d3;
    reg [3:0]  S_cnt_d4;
    reg [3:0]  S_cnt_d5;
    reg [2:0]  S_lbl_row;
    reg [2:0]  S_lbl_col;
    reg [1:0]  S_lbl_idx;
    reg [4:0]  S_lbl_bits;
    reg [6:0]  S_lbl_local_x;
    reg [3:0]  S_dyn_dec_digit;
    reg [4:0]  S_cn_local_x;
    reg [4:0]  S_cn_local_y;
    reg [3:0]  S_cn_col;
    reg [3:0]  S_cn_row;
    reg [15:0] S_cn_row_bits;
    reg        S_cn_on;
    reg [9:0]  S_cn_scale_x;
    reg [9:0]  S_cn_scale_y;
    reg [7:0]  S_pf_char;
    reg [4:0]  S_pf_local_x;
    reg [4:0]  S_pf_local_y;
    reg [3:0]  S_pf_col;
    reg [3:0]  S_pf_row;
    wire [15:0] S_pf_row_bits;
    reg        S_pf_on;
    reg [9:0]  S_pf_scale_x;
    reg [9:0]  S_pf_scale_y;

    localparam LOGO_X = 12'd24;
    localparam LOGO_Y = 12'd20;
    localparam LOGO_W = 12'd160;
    localparam LOGO_H = 12'd160;

    localparam COLOR_LOGO_BLUE   = 24'h1f315c;
    localparam COLOR_LOGO_RED    = 24'hec1c2d;
    localparam COLOR_TEXT        = 24'h00e6ff;
    // 27 8-pixel cells give a 216-pixel caption, comparable to the logo width.
    localparam DYN_OSD_X         = 12'd20;
    localparam DYN_OSD_Y         = 12'd184;
    localparam DYN_OSD_W         = 12'd216;
    localparam DYN_OSD_H         = 12'd56;
    localparam COUNT_OSD_X       = 12'd1152;
    localparam COUNT_OSD_Y       = 12'd20;
    localparam COUNT_OSD_W       = 12'd96;
    localparam QUALITY_OSD_W     = 12'd112;
    localparam QUALITY_OSD_Y     = 12'd36;
    localparam GRADE_OSD_Y       = 12'd52;
    localparam PASS_OSD_Y        = 12'd68;
    localparam FAIL_OSD_Y        = 12'd84;
    // The short tag follows the box; telemetry stays below the status block.
    localparam TRACK_OSD_W       = 12'd72;
    localparam TRACK_OSD_H       = 12'd24;
    localparam TELEMETRY_OSD_X   = 12'd1144;
    localparam TELEMETRY_OSD_Y   = 12'd100;
    localparam TELEMETRY_OSD_W   = 12'd112;
    localparam TELEMETRY_OSD_H   = 12'd32;
    localparam AWB_OSD_Y         = 12'd248;
    localparam COLOR_BBOX        = 24'h00ff40;
    localparam COLOR_TRACK_TEXT  = 24'hff0000;
    localparam CN_Y_OFFSET       = 12'd2;
    localparam COLOR_DYN_TEXT    = 24'hfff200;
    localparam CHAR_AN           = 8'h80;
    localparam CHAR_LU           = 8'h81;
    localparam CHAR_C            = 8'h43;
    localparam CHAR_A            = 8'h41;
    localparam CHAR_E            = 8'h45;
    localparam CHAR_K            = 8'h4b;
    localparam CHAR_M            = 8'h4d;
    localparam CHAR_N            = 8'h4e;
    localparam CHAR_R            = 8'h52;
    localparam CHAR_T            = 8'h54;
    localparam CHAR_SPACE        = 8'h20;
    localparam CHAR_0            = 8'h30;
    localparam CHAR_COLON        = 8'h3a;

    function [4:0] F_logo_text_bits;
        input [3:0] I_char;
        input [2:0] I_row;
        begin
            case(I_char)
                4'd0: begin
                    case(I_row) // A
                        3'd0: F_logo_text_bits = 5'b01110;
                        3'd1: F_logo_text_bits = 5'b10001;
                        3'd2: F_logo_text_bits = 5'b10001;
                        3'd3: F_logo_text_bits = 5'b11111;
                        3'd4: F_logo_text_bits = 5'b10001;
                        3'd5: F_logo_text_bits = 5'b10001;
                        3'd6: F_logo_text_bits = 5'b10001;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                4'd1: begin
                    case(I_row) // N
                        3'd0: F_logo_text_bits = 5'b10001;
                        3'd1: F_logo_text_bits = 5'b11001;
                        3'd2: F_logo_text_bits = 5'b10101;
                        3'd3: F_logo_text_bits = 5'b10011;
                        3'd4: F_logo_text_bits = 5'b10001;
                        3'd5: F_logo_text_bits = 5'b10001;
                        3'd6: F_logo_text_bits = 5'b10001;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                4'd2: begin
                    case(I_row) // L
                        3'd0: F_logo_text_bits = 5'b10000;
                        3'd1: F_logo_text_bits = 5'b10000;
                        3'd2: F_logo_text_bits = 5'b10000;
                        3'd3: F_logo_text_bits = 5'b10000;
                        3'd4: F_logo_text_bits = 5'b10000;
                        3'd5: F_logo_text_bits = 5'b10000;
                        3'd6: F_logo_text_bits = 5'b11111;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                4'd3: begin
                    case(I_row) // O
                        3'd0: F_logo_text_bits = 5'b01110;
                        3'd1: F_logo_text_bits = 5'b10001;
                        3'd2: F_logo_text_bits = 5'b10001;
                        3'd3: F_logo_text_bits = 5'b10001;
                        3'd4: F_logo_text_bits = 5'b10001;
                        3'd5: F_logo_text_bits = 5'b10001;
                        3'd6: F_logo_text_bits = 5'b01110;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                4'd4: begin
                    case(I_row) // G
                        3'd0: F_logo_text_bits = 5'b01110;
                        3'd1: F_logo_text_bits = 5'b10001;
                        3'd2: F_logo_text_bits = 5'b10000;
                        3'd3: F_logo_text_bits = 5'b10111;
                        3'd4: F_logo_text_bits = 5'b10001;
                        3'd5: F_logo_text_bits = 5'b10001;
                        3'd6: F_logo_text_bits = 5'b01110;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                4'd5: begin
                    case(I_row) // I
                        3'd0: F_logo_text_bits = 5'b11111;
                        3'd1: F_logo_text_bits = 5'b00100;
                        3'd2: F_logo_text_bits = 5'b00100;
                        3'd3: F_logo_text_bits = 5'b00100;
                        3'd4: F_logo_text_bits = 5'b00100;
                        3'd5: F_logo_text_bits = 5'b00100;
                        3'd6: F_logo_text_bits = 5'b11111;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                4'd6: begin
                    case(I_row) // C
                        3'd0: F_logo_text_bits = 5'b01110;
                        3'd1: F_logo_text_bits = 5'b10001;
                        3'd2: F_logo_text_bits = 5'b10000;
                        3'd3: F_logo_text_bits = 5'b10000;
                        3'd4: F_logo_text_bits = 5'b10000;
                        3'd5: F_logo_text_bits = 5'b10001;
                        3'd6: F_logo_text_bits = 5'b01110;
                        default: F_logo_text_bits = 5'b00000;
                    endcase
                end
                default: F_logo_text_bits = 5'b00000;
            endcase
        end
    endfunction

    // 7-seg bit mapping: {a,b,c,d,e,f,g}
    function [6:0] F_hex7seg;
        input [3:0] I_hex;
        begin
            case(I_hex)
                4'h0: F_hex7seg = 7'b1111110;
                4'h1: F_hex7seg = 7'b0110000;
                4'h2: F_hex7seg = 7'b1101101;
                4'h3: F_hex7seg = 7'b1111001;
                4'h4: F_hex7seg = 7'b0110011;
                4'h5: F_hex7seg = 7'b1011011;
                4'h6: F_hex7seg = 7'b1011111;
                4'h7: F_hex7seg = 7'b1110000;
                4'h8: F_hex7seg = 7'b1111111;
                4'h9: F_hex7seg = 7'b1111011;
                4'ha: F_hex7seg = 7'b1110111;
                4'hb: F_hex7seg = 7'b0011111;
                4'hc: F_hex7seg = 7'b1001110;
                4'hd: F_hex7seg = 7'b0111101;
                4'he: F_hex7seg = 7'b1001111;
                4'hf: F_hex7seg = 7'b1000111;
                default: F_hex7seg = 7'b0000000;
            endcase
        end
    endfunction

    function [4:0] F_cnt_label_bits;
        input [1:0] I_idx;
        input [2:0] I_row;
        begin
            case(I_idx)
                2'd0: begin // C
                    case(I_row)
                        3'd0: F_cnt_label_bits = 5'b01110;
                        3'd1: F_cnt_label_bits = 5'b10001;
                        3'd2: F_cnt_label_bits = 5'b10000;
                        3'd3: F_cnt_label_bits = 5'b10000;
                        3'd4: F_cnt_label_bits = 5'b10000;
                        3'd5: F_cnt_label_bits = 5'b10001;
                        3'd6: F_cnt_label_bits = 5'b01110;
                        default: F_cnt_label_bits = 5'b00000;
                    endcase
                end
                2'd1: begin // N
                    case(I_row)
                        3'd0: F_cnt_label_bits = 5'b10001;
                        3'd1: F_cnt_label_bits = 5'b11001;
                        3'd2: F_cnt_label_bits = 5'b10101;
                        3'd3: F_cnt_label_bits = 5'b10011;
                        3'd4: F_cnt_label_bits = 5'b10001;
                        3'd5: F_cnt_label_bits = 5'b10001;
                        3'd6: F_cnt_label_bits = 5'b10001;
                        default: F_cnt_label_bits = 5'b00000;
                    endcase
                end
                2'd2: begin // T
                    case(I_row)
                        3'd0: F_cnt_label_bits = 5'b11111;
                        3'd1: F_cnt_label_bits = 5'b00100;
                        3'd2: F_cnt_label_bits = 5'b00100;
                        3'd3: F_cnt_label_bits = 5'b00100;
                        3'd4: F_cnt_label_bits = 5'b00100;
                        3'd5: F_cnt_label_bits = 5'b00100;
                        3'd6: F_cnt_label_bits = 5'b00100;
                        default: F_cnt_label_bits = 5'b00000;
                    endcase
                end
                default: begin // ':'
                    case(I_row)
                        3'd2: F_cnt_label_bits = 5'b00100;
                        3'd5: F_cnt_label_bits = 5'b00100;
                        default: F_cnt_label_bits = 5'b00000;
                    endcase
                end
            endcase
        end
    endfunction

    // Minimal 16x16 Chinese bitmap rows for "an" and "lu".
    function [15:0] F_cn16_row;
        input I_char; // 0: an, 1: lu
        input [3:0] I_row;
        begin
            if(!I_char) begin
                case(I_row)
                    4'd0:  F_cn16_row = 16'h0200;
                    4'd1:  F_cn16_row = 16'h7ff0;
                    4'd2:  F_cn16_row = 16'h4410;
                    4'd3:  F_cn16_row = 16'h0400;
                    4'd4:  F_cn16_row = 16'h7ff0;
                    4'd5:  F_cn16_row = 16'h0840;
                    4'd6:  F_cn16_row = 16'h1040;
                    4'd7:  F_cn16_row = 16'h1c80;
                    4'd8:  F_cn16_row = 16'h0300;
                    4'd9:  F_cn16_row = 16'h0cc0;
                    4'd10: F_cn16_row = 16'h7020;
                    4'd11: F_cn16_row = 16'h0000;
                    4'd12: F_cn16_row = 16'h0000;
                    4'd13: F_cn16_row = 16'h0000;
                    4'd14: F_cn16_row = 16'h0000;
                    4'd15: F_cn16_row = 16'h0000;
                    default: F_cn16_row = 16'h0000;
                endcase
            end
            else begin
                case(I_row)
                    4'd0:  F_cn16_row = 16'h79e0;
                    4'd1:  F_cn16_row = 16'h4a20;
                    4'd2:  F_cn16_row = 16'h4d40;
                    4'd3:  F_cn16_row = 16'h7880;
                    4'd4:  F_cn16_row = 16'h1140;
                    4'd5:  F_cn16_row = 16'h1630;
                    4'd6:  F_cn16_row = 16'h5be0;
                    4'd7:  F_cn16_row = 16'h5220;
                    4'd8:  F_cn16_row = 16'h5220;
                    4'd9:  F_cn16_row = 16'h5be0;
                    4'd10: F_cn16_row = 16'h6220;
                    4'd11: F_cn16_row = 16'h0000;
                    4'd12: F_cn16_row = 16'h0000;
                    4'd13: F_cn16_row = 16'h0000;
                    4'd14: F_cn16_row = 16'h0000;
                    4'd15: F_cn16_row = 16'h0000;
                    default: F_cn16_row = 16'h0000;
                endcase
            end
        end
    endfunction

    function [4:0] F_dyn_char_bits;
        input [3:0] I_char;
        input [2:0] I_row;
        begin
            case(I_char)
                4'h0: begin case(I_row) 3'd0:F_dyn_char_bits=5'b01110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10011; 3'd3:F_dyn_char_bits=5'b10101; 3'd4:F_dyn_char_bits=5'b11001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b01110; default:F_dyn_char_bits=5'b00000; endcase end
                4'h1: begin case(I_row) 3'd0:F_dyn_char_bits=5'b00100; 3'd1:F_dyn_char_bits=5'b01100; 3'd2:F_dyn_char_bits=5'b00100; 3'd3:F_dyn_char_bits=5'b00100; 3'd4:F_dyn_char_bits=5'b00100; 3'd5:F_dyn_char_bits=5'b00100; 3'd6:F_dyn_char_bits=5'b01110; default:F_dyn_char_bits=5'b00000; endcase end
                4'h2: begin case(I_row) 3'd0:F_dyn_char_bits=5'b01110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b00001; 3'd3:F_dyn_char_bits=5'b00110; 3'd4:F_dyn_char_bits=5'b01000; 3'd5:F_dyn_char_bits=5'b10000; 3'd6:F_dyn_char_bits=5'b11111; default:F_dyn_char_bits=5'b00000; endcase end
                4'h3: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11110; 3'd1:F_dyn_char_bits=5'b00001; 3'd2:F_dyn_char_bits=5'b00001; 3'd3:F_dyn_char_bits=5'b01110; 3'd4:F_dyn_char_bits=5'b00001; 3'd5:F_dyn_char_bits=5'b00001; 3'd6:F_dyn_char_bits=5'b11110; default:F_dyn_char_bits=5'b00000; endcase end
                4'h4: begin case(I_row) 3'd0:F_dyn_char_bits=5'b00010; 3'd1:F_dyn_char_bits=5'b00110; 3'd2:F_dyn_char_bits=5'b01010; 3'd3:F_dyn_char_bits=5'b10010; 3'd4:F_dyn_char_bits=5'b11111; 3'd5:F_dyn_char_bits=5'b00010; 3'd6:F_dyn_char_bits=5'b00010; default:F_dyn_char_bits=5'b00000; endcase end
                4'h5: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11111; 3'd1:F_dyn_char_bits=5'b10000; 3'd2:F_dyn_char_bits=5'b11110; 3'd3:F_dyn_char_bits=5'b00001; 3'd4:F_dyn_char_bits=5'b00001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b01110; default:F_dyn_char_bits=5'b00000; endcase end
                4'h6: begin case(I_row) 3'd0:F_dyn_char_bits=5'b00110; 3'd1:F_dyn_char_bits=5'b01000; 3'd2:F_dyn_char_bits=5'b10000; 3'd3:F_dyn_char_bits=5'b11110; 3'd4:F_dyn_char_bits=5'b10001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b01110; default:F_dyn_char_bits=5'b00000; endcase end
                4'h7: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11111; 3'd1:F_dyn_char_bits=5'b00001; 3'd2:F_dyn_char_bits=5'b00010; 3'd3:F_dyn_char_bits=5'b00100; 3'd4:F_dyn_char_bits=5'b01000; 3'd5:F_dyn_char_bits=5'b01000; 3'd6:F_dyn_char_bits=5'b01000; default:F_dyn_char_bits=5'b00000; endcase end
                4'h8: begin case(I_row) 3'd0:F_dyn_char_bits=5'b01110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10001; 3'd3:F_dyn_char_bits=5'b01110; 3'd4:F_dyn_char_bits=5'b10001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b01110; default:F_dyn_char_bits=5'b00000; endcase end
                4'h9: begin case(I_row) 3'd0:F_dyn_char_bits=5'b01110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10001; 3'd3:F_dyn_char_bits=5'b01111; 3'd4:F_dyn_char_bits=5'b00001; 3'd5:F_dyn_char_bits=5'b00010; 3'd6:F_dyn_char_bits=5'b11100; default:F_dyn_char_bits=5'b00000; endcase end
                4'ha: begin case(I_row) 3'd0:F_dyn_char_bits=5'b01110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10001; 3'd3:F_dyn_char_bits=5'b11111; 3'd4:F_dyn_char_bits=5'b10001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b10001; default:F_dyn_char_bits=5'b00000; endcase end
                4'hb: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10001; 3'd3:F_dyn_char_bits=5'b11110; 3'd4:F_dyn_char_bits=5'b10001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b11110; default:F_dyn_char_bits=5'b00000; endcase end
                4'hc: begin case(I_row) 3'd0:F_dyn_char_bits=5'b01110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10000; 3'd3:F_dyn_char_bits=5'b10000; 3'd4:F_dyn_char_bits=5'b10000; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b01110; default:F_dyn_char_bits=5'b00000; endcase end
                4'hd: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11110; 3'd1:F_dyn_char_bits=5'b10001; 3'd2:F_dyn_char_bits=5'b10001; 3'd3:F_dyn_char_bits=5'b10001; 3'd4:F_dyn_char_bits=5'b10001; 3'd5:F_dyn_char_bits=5'b10001; 3'd6:F_dyn_char_bits=5'b11110; default:F_dyn_char_bits=5'b00000; endcase end
                4'he: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11111; 3'd1:F_dyn_char_bits=5'b10000; 3'd2:F_dyn_char_bits=5'b10000; 3'd3:F_dyn_char_bits=5'b11110; 3'd4:F_dyn_char_bits=5'b10000; 3'd5:F_dyn_char_bits=5'b10000; 3'd6:F_dyn_char_bits=5'b11111; default:F_dyn_char_bits=5'b00000; endcase end
                4'hf: begin case(I_row) 3'd0:F_dyn_char_bits=5'b11111; 3'd1:F_dyn_char_bits=5'b10000; 3'd2:F_dyn_char_bits=5'b10000; 3'd3:F_dyn_char_bits=5'b11110; 3'd4:F_dyn_char_bits=5'b10000; 3'd5:F_dyn_char_bits=5'b10000; 3'd6:F_dyn_char_bits=5'b10000; default:F_dyn_char_bits=5'b00000; endcase end
                default: F_dyn_char_bits = 5'b00000;
            endcase
        end
    endfunction

    // 5x7 uppercase glyphs used by the mode caption. Each character cell is
    // 8x8 pixels, leaving a three-pixel gap between glyphs.
    function [7:0] F_mode_text_char;
        input [2:0]  I_display_mode;
        input [4:0]  I_idx;
        begin
            case(I_display_mode)
            3'd0: begin
                case(I_idx)
                    5'd0:  F_mode_text_char = 8'h43; // C
                    5'd1:  F_mode_text_char = 8'h41; // A
                    5'd2:  F_mode_text_char = 8'h4d; // M
                    5'd3:  F_mode_text_char = 8'h45; // E
                    5'd4:  F_mode_text_char = 8'h52; // R
                    5'd5:  F_mode_text_char = 8'h41; // A
                    5'd6:  F_mode_text_char = 8'h20; // space
                    5'd7:  F_mode_text_char = 8'h4d; // M
                    5'd8:  F_mode_text_char = 8'h4f; // O
                    5'd9:  F_mode_text_char = 8'h44; // D
                    5'd10: F_mode_text_char = 8'h45; // E
                    5'd11: F_mode_text_char = 8'h3a; // colon
                    5'd12: F_mode_text_char = 8'h20; // space
                    5'd13: F_mode_text_char = 8'h4f; // O
                    5'd14: F_mode_text_char = 8'h52; // R
                    5'd15: F_mode_text_char = 8'h49; // I
                    5'd16: F_mode_text_char = 8'h47; // G
                    5'd17: F_mode_text_char = 8'h49; // I
                    5'd18: F_mode_text_char = 8'h4e; // N
                    5'd19: F_mode_text_char = 8'h41; // A
                    5'd20: F_mode_text_char = 8'h4c; // L
                    5'd21: F_mode_text_char = 8'h20; // space
                    5'd22: F_mode_text_char = 8'h49; // I
                    5'd23: F_mode_text_char = 8'h4d; // M
                    5'd24: F_mode_text_char = 8'h41; // A
                    5'd25: F_mode_text_char = 8'h47; // G
                    5'd26: F_mode_text_char = 8'h45; // E
                    default: F_mode_text_char = 8'h20;
                endcase
            end
            3'd1: begin
                case(I_idx)
                    5'd0:  F_mode_text_char = 8'h43; // C
                    5'd1:  F_mode_text_char = 8'h41; // A
                    5'd2:  F_mode_text_char = 8'h4d; // M
                    5'd3:  F_mode_text_char = 8'h45; // E
                    5'd4:  F_mode_text_char = 8'h52; // R
                    5'd5:  F_mode_text_char = 8'h41; // A
                    5'd6:  F_mode_text_char = 8'h20; // space
                    5'd7:  F_mode_text_char = 8'h4d; // M
                    5'd8:  F_mode_text_char = 8'h4f; // O
                    5'd9:  F_mode_text_char = 8'h44; // D
                    5'd10: F_mode_text_char = 8'h45; // E
                    5'd11: F_mode_text_char = 8'h3a; // colon
                    5'd12: F_mode_text_char = 8'h20; // space
                    5'd13: F_mode_text_char = 8'h45; // E
                    5'd14: F_mode_text_char = 8'h44; // D
                    5'd15: F_mode_text_char = 8'h47; // G
                    5'd16: F_mode_text_char = 8'h45; // E
                    5'd17: F_mode_text_char = 8'h20; // space
                    5'd18: F_mode_text_char = 8'h44; // D
                    5'd19: F_mode_text_char = 8'h45; // E
                    5'd20: F_mode_text_char = 8'h54; // T
                    5'd21: F_mode_text_char = 8'h45; // E
                    5'd22: F_mode_text_char = 8'h43; // C
                    5'd23: F_mode_text_char = 8'h54; // T
                    5'd24: F_mode_text_char = 8'h49; // I
                    5'd25: F_mode_text_char = 8'h4f; // O
                    5'd26: F_mode_text_char = 8'h4e; // N
                    default: F_mode_text_char = 8'h20;
                endcase
            end
            3'd2: begin
                case(I_idx)
                    5'd0:  F_mode_text_char = 8'h43; // C
                    5'd1:  F_mode_text_char = 8'h41; // A
                    5'd2:  F_mode_text_char = 8'h4d; // M
                    5'd3:  F_mode_text_char = 8'h45; // E
                    5'd4:  F_mode_text_char = 8'h52; // R
                    5'd5:  F_mode_text_char = 8'h41; // A
                    5'd6:  F_mode_text_char = 8'h20; // space
                    5'd7:  F_mode_text_char = 8'h4d; // M
                    5'd8:  F_mode_text_char = 8'h4f; // O
                    5'd9:  F_mode_text_char = 8'h44; // D
                    5'd10: F_mode_text_char = 8'h45; // E
                    5'd11: F_mode_text_char = 8'h3a; // colon
                    5'd12: F_mode_text_char = 8'h20; // space
                    5'd13: F_mode_text_char = 8'h47; // G
                    5'd14: F_mode_text_char = 8'h52; // R
                    5'd15: F_mode_text_char = 8'h41; // A
                    5'd16: F_mode_text_char = 8'h59; // Y
                    5'd17: F_mode_text_char = 8'h53; // S
                    5'd18: F_mode_text_char = 8'h43; // C
                    5'd19: F_mode_text_char = 8'h41; // A
                    5'd20: F_mode_text_char = 8'h4c; // L
                    5'd21: F_mode_text_char = 8'h45; // E
                    default: F_mode_text_char = 8'h20;
                endcase
            end
            3'd3: begin
                case(I_idx)
                    5'd0:  F_mode_text_char = 8'h43; // C
                    5'd1:  F_mode_text_char = 8'h41; // A
                    5'd2:  F_mode_text_char = 8'h4d; // M
                    5'd3:  F_mode_text_char = 8'h45; // E
                    5'd4:  F_mode_text_char = 8'h52; // R
                    5'd5:  F_mode_text_char = 8'h41; // A
                    5'd6:  F_mode_text_char = 8'h20; // space
                    5'd7:  F_mode_text_char = 8'h4d; // M
                    5'd8:  F_mode_text_char = 8'h4f; // O
                    5'd9:  F_mode_text_char = 8'h44; // D
                    5'd10: F_mode_text_char = 8'h45; // E
                    5'd11: F_mode_text_char = 8'h3a; // colon
                    5'd12: F_mode_text_char = 8'h20; // space
                    5'd13: F_mode_text_char = 8'h52; // R
                    5'd14: F_mode_text_char = 8'h4f; // O
                    5'd15: F_mode_text_char = 8'h49; // I
                    5'd16: F_mode_text_char = 8'h20; // space
                    5'd17: F_mode_text_char = 8'h42; // B
                    5'd18: F_mode_text_char = 8'h49; // I
                    5'd19: F_mode_text_char = 8'h4e; // N
                    5'd20: F_mode_text_char = 8'h41; // A
                    5'd21: F_mode_text_char = 8'h52; // R
                    5'd22: F_mode_text_char = 8'h59; // Y
                    default: F_mode_text_char = 8'h20;
                endcase
            end
            3'd4: begin
                case(I_idx)
                    5'd0:  F_mode_text_char = 8'h43; // C
                    5'd1:  F_mode_text_char = 8'h41; // A
                    5'd2:  F_mode_text_char = 8'h4d; // M
                    5'd3:  F_mode_text_char = 8'h45; // E
                    5'd4:  F_mode_text_char = 8'h52; // R
                    5'd5:  F_mode_text_char = 8'h41; // A
                    5'd6:  F_mode_text_char = 8'h20; // space
                    5'd7:  F_mode_text_char = 8'h4d; // M
                    5'd8:  F_mode_text_char = 8'h4f; // O
                    5'd9:  F_mode_text_char = 8'h44; // D
                    5'd10: F_mode_text_char = 8'h45; // E
                    5'd11: F_mode_text_char = 8'h3a; // colon
                    5'd12: F_mode_text_char = 8'h20; // space
                    5'd13: F_mode_text_char = 8'h44; // D
                    5'd14: F_mode_text_char = 8'h45; // E
                    5'd15: F_mode_text_char = 8'h42; // B
                    5'd16: F_mode_text_char = 8'h55; // U
                    5'd17: F_mode_text_char = 8'h47; // G
                    5'd18: F_mode_text_char = 8'h20; // space
                    5'd19: F_mode_text_char = 8'h52; // R
                    5'd20: F_mode_text_char = 8'h4f; // O
                    5'd21: F_mode_text_char = 8'h49; // I
                    default: F_mode_text_char = 8'h20;
                endcase
            end
            default: F_mode_text_char = 8'h20;
            endcase
        end
    endfunction

    // Gain caption uses the same 8x8 character cells as the mode caption.
    // The first three levels are manual presets; level 3 is AUTO.
    function [7:0] F_gain_text_char;
        input [1:0] I_gain_level;
        input [4:0] I_idx;
        begin
            case(I_idx)
                5'd0:  F_gain_text_char = 8'h41; // A
                5'd1:  F_gain_text_char = 8'h4e; // N
                5'd2:  F_gain_text_char = 8'h41; // A
                5'd3:  F_gain_text_char = 8'h4c; // L
                5'd4:  F_gain_text_char = 8'h4f; // O
                5'd5:  F_gain_text_char = 8'h47; // G
                5'd6:  F_gain_text_char = 8'h20; // space
                5'd7:  F_gain_text_char = 8'h47; // G
                5'd8:  F_gain_text_char = 8'h41; // A
                5'd9:  F_gain_text_char = 8'h49; // I
                5'd10: F_gain_text_char = 8'h4e; // N
                5'd11: F_gain_text_char = 8'h3a; // colon
                5'd12: F_gain_text_char = 8'h20; // space
                default: begin
                    case(I_gain_level)
                        2'd0: begin
                            case(I_idx)
                                5'd13: F_gain_text_char = 8'h4c; // L
                                5'd14: F_gain_text_char = 8'h4f; // O
                                5'd15: F_gain_text_char = 8'h57; // W
                                default: F_gain_text_char = 8'h20;
                            endcase
                        end
                        2'd1: begin
                            case(I_idx)
                                5'd13: F_gain_text_char = 8'h4d; // M
                                5'd14: F_gain_text_char = 8'h45; // E
                                5'd15: F_gain_text_char = 8'h44; // D
                                5'd16: F_gain_text_char = 8'h49; // I
                                5'd17: F_gain_text_char = 8'h55; // U
                                5'd18: F_gain_text_char = 8'h4d; // M
                                default: F_gain_text_char = 8'h20;
                            endcase
                        end
                        2'd2: begin
                            case(I_idx)
                                5'd13: F_gain_text_char = 8'h48; // H
                                5'd14: F_gain_text_char = 8'h49; // I
                                5'd15: F_gain_text_char = 8'h47; // G
                                5'd16: F_gain_text_char = 8'h48; // H
                                default: F_gain_text_char = 8'h20;
                            endcase
                        end
                        default: begin
                            case(I_idx)
                                5'd13: F_gain_text_char = 8'h41; // A
                                5'd14: F_gain_text_char = 8'h55; // U
                                5'd15: F_gain_text_char = 8'h54; // T
                                5'd16: F_gain_text_char = 8'h4f; // O
                                default: F_gain_text_char = 8'h20;
                            endcase
                        end
                    endcase
                end
            endcase
        end
    endfunction

    // Third caption row: the stable result of the ROI dark-object detector.
    function [7:0] F_inspection_text_char;
        input I_object_present;
        input [4:0] I_idx;
        begin
            if(I_object_present) begin
                case(I_idx)
                    5'd0: F_inspection_text_char = 8'h4f; // O
                    5'd1: F_inspection_text_char = 8'h42; // B
                    5'd2: F_inspection_text_char = 8'h4a; // J
                    5'd3: F_inspection_text_char = 8'h45; // E
                    5'd4: F_inspection_text_char = 8'h43; // C
                    5'd5: F_inspection_text_char = 8'h54; // T
                    default: F_inspection_text_char = 8'h20;
                endcase
            end
            else begin
                case(I_idx)
                    5'd0: F_inspection_text_char = 8'h4e; // N
                    5'd1: F_inspection_text_char = 8'h4f; // O
                    5'd2: F_inspection_text_char = 8'h20; // space
                    5'd3: F_inspection_text_char = 8'h4f; // O
                    5'd4: F_inspection_text_char = 8'h42; // B
                    5'd5: F_inspection_text_char = 8'h4a; // J
                    5'd6: F_inspection_text_char = 8'h45; // E
                    5'd7: F_inspection_text_char = 8'h43; // C
                    5'd8: F_inspection_text_char = 8'h54; // T
                    default: F_inspection_text_char = 8'h20;
                endcase
            end
        end
    endfunction

    function [7:0] F_result_text_char;
        input [1:0] I_code;
        input [4:0] I_idx;
        begin
            case(I_code)
                2'd1: case(I_idx)
                    3'd0: F_result_text_char = 8'h4f; // O
                    3'd1: F_result_text_char = 8'h4b; // K
                    default: F_result_text_char = 8'h20;
                endcase
                2'd2: case(I_idx)
                    3'd0: F_result_text_char = 8'h4e; // N
                    3'd1: F_result_text_char = 8'h47; // G
                    default: F_result_text_char = 8'h20;
                endcase
                default: case(I_idx)
                    3'd0: F_result_text_char = 8'h57; // W
                    3'd1: F_result_text_char = 8'h41; // A
                    3'd2: F_result_text_char = 8'h49; // I
                    3'd3: F_result_text_char = 8'h54; // T
                    default: F_result_text_char = 8'h20;
                endcase
            endcase
        end
    endfunction

    function [7:0] F_shape_text_char;
        input [1:0] I_code;
        input [4:0] I_idx;
        begin
            F_shape_text_char = 8'h20;
            case(I_code)
                2'd0: case(I_idx)
                    5'd0:F_shape_text_char=8'h41; 5'd1:F_shape_text_char=8'h58;
                    5'd2:F_shape_text_char=8'h49; 5'd3:F_shape_text_char=8'h53;
                    5'd5:F_shape_text_char=8'h42; 5'd6:F_shape_text_char=8'h41;
                    5'd7:F_shape_text_char=8'h44;
                    default:F_shape_text_char=8'h20;
                endcase
                2'd1: case(I_idx)
                    5'd0:F_shape_text_char=8'h4d; 5'd1:F_shape_text_char=8'h41;
                    5'd2:F_shape_text_char=8'h54; 5'd3:F_shape_text_char=8'h43;
                    5'd4:F_shape_text_char=8'h48;
                    default:F_shape_text_char=8'h20;
                endcase
                2'd2: case(I_idx)
                    5'd0:F_shape_text_char=8'h53; 5'd1:F_shape_text_char=8'h48;
                    5'd2:F_shape_text_char=8'h41; 5'd3:F_shape_text_char=8'h50;
                    5'd4:F_shape_text_char=8'h45; 5'd6:F_shape_text_char=8'h4e;
                    5'd7:F_shape_text_char=8'h47;
                    default:F_shape_text_char=8'h20;
                endcase
                default: case(I_idx)
                    5'd0:F_shape_text_char=8'h57; 5'd1:F_shape_text_char=8'h41;
                    5'd2:F_shape_text_char=8'h49; 5'd3:F_shape_text_char=8'h54;
                    default:F_shape_text_char=8'h20;
                endcase
            endcase
        end
    endfunction

    function [7:0] F_shape_info_char;
        input [1:0] I_line;
        input [4:0] I_idx;
        begin
            F_shape_info_char = 8'h20;
            if(I_line == 2'd0) begin
                case(I_idx)
                    5'd0: F_shape_info_char = 8'h53; // S
                    5'd1: F_shape_info_char = 8'h43; // C
                    5'd2: F_shape_info_char = 8'h4f; // O
                    5'd3: F_shape_info_char = 8'h52; // R
                    5'd4: F_shape_info_char = 8'h45; // E
                    5'd5: F_shape_info_char = 8'h3a; // :
                    5'd6: F_shape_info_char = 8'h30; // 0
                    5'd7: F_shape_info_char = 8'h58; // X
                    default: F_shape_info_char = 8'h20;
                endcase
            end
            else begin
                case(I_idx)
                    5'd0: F_shape_info_char = 8'h41; // A
                    5'd1: F_shape_info_char = 8'h4e; // N
                    5'd2: F_shape_info_char = 8'h47; // G
                    5'd3: F_shape_info_char = 8'h4c; // L
                    5'd4: F_shape_info_char = 8'h45; // E
                    5'd5: F_shape_info_char = 8'h3a; // :
                    default: F_shape_info_char = 8'h20;
                endcase
            end
        end
    endfunction

    function [7:0] F_shape_hex_char;
        input [3:0] I_digit;
        begin
            if(I_digit < 4'd10)
                F_shape_hex_char = 8'h30 + I_digit;
            else
                F_shape_hex_char = 8'h41 + (I_digit - 4'd10);
        end
    endfunction

    function [7:0] F_track_label_char;
        input [2:0] I_line;
        input [4:0] I_idx;
        begin
            F_track_label_char = 8'h20;
            case(I_line)
                3'd0: case(I_idx)
                    5'd0: F_track_label_char = 8'h49; // I
                    5'd1: F_track_label_char = 8'h44; // D
                    5'd2: F_track_label_char = 8'h3a; // :
                    default: F_track_label_char = 8'h20;
                endcase
                3'd1: case(I_idx)
                    5'd0: F_track_label_char = 8'h43; // C
                    5'd1: F_track_label_char = 8'h58; // X
                    5'd2: F_track_label_char = 8'h3a; // :
                    5'd3: F_track_label_char = 8'h30; // 0
                    5'd4: F_track_label_char = 8'h58; // X
                    default: F_track_label_char = 8'h20;
                endcase
                3'd2: case(I_idx)
                    5'd0: F_track_label_char = 8'h43; // C
                    5'd1: F_track_label_char = 8'h59; // Y
                    5'd2: F_track_label_char = 8'h3a; // :
                    5'd3: F_track_label_char = 8'h30; // 0
                    5'd4: F_track_label_char = 8'h58; // X
                    default: F_track_label_char = 8'h20;
                endcase
                3'd3: case(I_idx)
                    5'd0: F_track_label_char = 8'h4c; // L
                    5'd1: F_track_label_char = 8'h41; // A
                    5'd2: F_track_label_char = 8'h54; // T
                    5'd3: F_track_label_char = 8'h3a; // :
                    5'd4: F_track_label_char = 8'h30; // 0
                    5'd5: F_track_label_char = 8'h58; // X
                    5'd10: F_track_label_char = 8'h4d; // M
                    5'd11: F_track_label_char = 8'h53; // S
                    default: F_track_label_char = 8'h20;
                endcase
                3'd4: case(I_idx)
                    5'd0: F_track_label_char = 8'h43; // C
                    5'd1: F_track_label_char = 8'h2d; // -
                    5'd2: F_track_label_char = 8'h46; // F
                    5'd3: F_track_label_char = 8'h50; // P
                    5'd4: F_track_label_char = 8'h53; // S
                    5'd5: F_track_label_char = 8'h3a; // :
                    default: F_track_label_char = 8'h20;
                endcase
                default: F_track_label_char = 8'h20;
            endcase
        end
    endfunction

    function [7:0] F_quality_label;
        input [4:0] idx;
        begin
            case(idx)
                0:F_quality_label="Q"; 1:F_quality_label="U";
                2:F_quality_label="A"; 3:F_quality_label="L";
                4:F_quality_label="I"; 5:F_quality_label="T";
                6:F_quality_label="Y"; 7:F_quality_label=":";
                default:F_quality_label=" ";
            endcase
        end
    endfunction
    function [7:0] F_grade_label;
        input [4:0] idx;
        begin
            case(idx)
                0:F_grade_label="G"; 1:F_grade_label="R";
                2:F_grade_label="A"; 3:F_grade_label="D";
                4:F_grade_label="E"; 5:F_grade_label=":";
                default:F_grade_label=" ";
            endcase
        end
    endfunction
    function [7:0] F_grade_value;
        input [2:0] grade;
        input [4:0] idx;
        begin
            F_grade_value=" ";
            case(grade)
                1:case(idx)
                    0:F_grade_value="P"; 1:F_grade_value="R";
                    2:F_grade_value="E"; 3:F_grade_value="M";
                    4:F_grade_value="I"; 5:F_grade_value="U";
                    6:F_grade_value="M";
                endcase
                2:case(idx)
                    0:F_grade_value="G"; 1:F_grade_value="O";
                    2:F_grade_value="O"; 3:F_grade_value="D";
                endcase
                3:case(idx)
                    0:F_grade_value="P"; 1:F_grade_value="A";
                    2:F_grade_value="S"; 3:F_grade_value="S";
                endcase
                4:case(idx)
                    0:F_grade_value="F"; 1:F_grade_value="A";
                    2:F_grade_value="I"; 3:F_grade_value="L";
                endcase
                default:case(idx)
                    0:F_grade_value="W"; 1:F_grade_value="A";
                    2:F_grade_value="I"; 3:F_grade_value="T";
                endcase
            endcase
        end
    endfunction

    function [4:0] F_mode_char_bits;
        input [7:0] I_char;
        input [2:0] I_row;
        begin
            case(I_char)
                8'h42: begin // B
                    case(I_row) 3'd0:F_mode_char_bits=5'b11110; 3'd1:F_mode_char_bits=5'b10001; 3'd2:F_mode_char_bits=5'b10001; 3'd3:F_mode_char_bits=5'b11110; 3'd4:F_mode_char_bits=5'b10001; 3'd5:F_mode_char_bits=5'b10001; 3'd6:F_mode_char_bits=5'b11110; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h46: begin // F
                    case(I_row) 0:F_mode_char_bits=5'b11111; 1:F_mode_char_bits=5'b10000; 2:F_mode_char_bits=5'b10000; 3:F_mode_char_bits=5'b11110; 4:F_mode_char_bits=5'b10000; 5:F_mode_char_bits=5'b10000; 6:F_mode_char_bits=5'b10000; default:F_mode_char_bits=0; endcase
                end
                8'h51: begin // Q
                    case(I_row) 0:F_mode_char_bits=5'b01110; 1:F_mode_char_bits=5'b10001; 2:F_mode_char_bits=5'b10001; 3:F_mode_char_bits=5'b10001; 4:F_mode_char_bits=5'b10101; 5:F_mode_char_bits=5'b10010; 6:F_mode_char_bits=5'b01101; default:F_mode_char_bits=0; endcase
                end
                8'h25: begin // percent
                    case(I_row) 0:F_mode_char_bits=5'b11001; 1:F_mode_char_bits=5'b11010; 2:F_mode_char_bits=5'b00100; 3:F_mode_char_bits=5'b01000; 4:F_mode_char_bits=5'b10110; 5:F_mode_char_bits=5'b00110; default:F_mode_char_bits=0; endcase
                end
                8'h2d: begin // dash
                    F_mode_char_bits=(I_row==3) ? 5'b11111:5'b00000;
                end
                8'h41: begin // A
                    case(I_row) 3'd0:F_mode_char_bits=5'b01110; 3'd1:F_mode_char_bits=5'b10001; 3'd2:F_mode_char_bits=5'b10001; 3'd3:F_mode_char_bits=5'b11111; 3'd4:F_mode_char_bits=5'b10001; 3'd5:F_mode_char_bits=5'b10001; 3'd6:F_mode_char_bits=5'b10001; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h43: begin // C
                    case(I_row) 3'd0:F_mode_char_bits=5'b01110; 3'd1:F_mode_char_bits=5'b10001; 3'd2:F_mode_char_bits=5'b10000; 3'd3:F_mode_char_bits=5'b10000; 3'd4:F_mode_char_bits=5'b10000; 3'd5:F_mode_char_bits=5'b10001; 3'd6:F_mode_char_bits=5'b01110; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h44: begin // D
                    case(I_row) 3'd0:F_mode_char_bits=5'b11110; 3'd1:F_mode_char_bits=5'b10001; 3'd2:F_mode_char_bits=5'b10001; 3'd3:F_mode_char_bits=5'b10001; 3'd4:F_mode_char_bits=5'b10001; 3'd5:F_mode_char_bits=5'b10001; 3'd6:F_mode_char_bits=5'b11110; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h45: begin // E
                    case(I_row) 3'd0:F_mode_char_bits=5'b11111; 3'd1:F_mode_char_bits=5'b10000; 3'd2:F_mode_char_bits=5'b10000; 3'd3:F_mode_char_bits=5'b11110; 3'd4:F_mode_char_bits=5'b10000; 3'd5:F_mode_char_bits=5'b10000; 3'd6:F_mode_char_bits=5'b11111; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h47: begin // G
                    case(I_row) 3'd0:F_mode_char_bits=5'b01110; 3'd1:F_mode_char_bits=5'b10001; 3'd2:F_mode_char_bits=5'b10000; 3'd3:F_mode_char_bits=5'b10111; 3'd4:F_mode_char_bits=5'b10001; 3'd5:F_mode_char_bits=5'b10001; 3'd6:F_mode_char_bits=5'b01110; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h48: begin // H
                    case(I_row) 3'd0:F_mode_char_bits=5'b10001; 3'd1:F_mode_char_bits=5'b10001; 3'd2:F_mode_char_bits=5'b10001; 3'd3:F_mode_char_bits=5'b11111; 3'd4:F_mode_char_bits=5'b10001; 3'd5:F_mode_char_bits=5'b10001; 3'd6:F_mode_char_bits=5'b10001; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h49: begin // I
                    case(I_row) 3'd0:F_mode_char_bits=5'b11111; 3'd1:F_mode_char_bits=5'b00100; 3'd2:F_mode_char_bits=5'b00100; 3'd3:F_mode_char_bits=5'b00100; 3'd4:F_mode_char_bits=5'b00100; 3'd5:F_mode_char_bits=5'b00100; 3'd6:F_mode_char_bits=5'b11111; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h4a: begin // J
                    case(I_row) 3'd0:F_mode_char_bits=5'b00111; 3'd1:F_mode_char_bits=5'b00010; 3'd2:F_mode_char_bits=5'b00010; 3'd3:F_mode_char_bits=5'b00010; 3'd4:F_mode_char_bits=5'b00010; 3'd5:F_mode_char_bits=5'b10010; 3'd6:F_mode_char_bits=5'b01100; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h4b: begin // K
                    case(I_row) 3'd0:F_mode_char_bits=5'b10001; 3'd1:F_mode_char_bits=5'b10010; 3'd2:F_mode_char_bits=5'b10100; 3'd3:F_mode_char_bits=5'b11000; 3'd4:F_mode_char_bits=5'b10100; 3'd5:F_mode_char_bits=5'b10010; 3'd6:F_mode_char_bits=5'b10001; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h4c: begin // L
                    case(I_row) 3'd0:F_mode_char_bits=5'b10000; 3'd1:F_mode_char_bits=5'b10000; 3'd2:F_mode_char_bits=5'b10000; 3'd3:F_mode_char_bits=5'b10000; 3'd4:F_mode_char_bits=5'b10000; 3'd5:F_mode_char_bits=5'b10000; 3'd6:F_mode_char_bits=5'b11111; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h4d: begin // M
                    case(I_row) 3'd0:F_mode_char_bits=5'b10001; 3'd1:F_mode_char_bits=5'b11011; 3'd2:F_mode_char_bits=5'b10101; 3'd3:F_mode_char_bits=5'b10101; 3'd4:F_mode_char_bits=5'b10001; 3'd5:F_mode_char_bits=5'b10001; 3'd6:F_mode_char_bits=5'b10001; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h4e: begin // N
                    case(I_row) 3'd0:F_mode_char_bits=5'b10001; 3'd1:F_mode_char_bits=5'b11001; 3'd2:F_mode_char_bits=5'b10101; 3'd3:F_mode_char_bits=5'b10011; 3'd4:F_mode_char_bits=5'b10001; 3'd5:F_mode_char_bits=5'b10001; 3'd6:F_mode_char_bits=5'b10001; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h4f: begin // O
                    case(I_row) 3'd0:F_mode_char_bits=5'b01110; 3'd1:F_mode_char_bits=5'b10001; 3'd2:F_mode_char_bits=5'b10001; 3'd3:F_mode_char_bits=5'b10001; 3'd4:F_mode_char_bits=5'b10001; 3'd5:F_mode_char_bits=5'b10001; 3'd6:F_mode_char_bits=5'b01110; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h50: begin // P
                    case(I_row) 3'd0:F_mode_char_bits=5'b11110; 3'd1:F_mode_char_bits=5'b10001; 3'd2:F_mode_char_bits=5'b10001; 3'd3:F_mode_char_bits=5'b11110; 3'd4:F_mode_char_bits=5'b10000; 3'd5:F_mode_char_bits=5'b10000; 3'd6:F_mode_char_bits=5'b10000; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h52: begin // R
                    case(I_row) 3'd0:F_mode_char_bits=5'b11110; 3'd1:F_mode_char_bits=5'b10001; 3'd2:F_mode_char_bits=5'b10001; 3'd3:F_mode_char_bits=5'b11110; 3'd4:F_mode_char_bits=5'b10100; 3'd5:F_mode_char_bits=5'b10010; 3'd6:F_mode_char_bits=5'b10001; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h53: begin // S
                    case(I_row)
                        3'd0: F_mode_char_bits = 5'b01111;
                        3'd1: F_mode_char_bits = 5'b10000;
                        3'd2: F_mode_char_bits = 5'b10000;
                        3'd3: F_mode_char_bits = 5'b01110;
                        3'd4: F_mode_char_bits = 5'b00001;
                        3'd5: F_mode_char_bits = 5'b00001;
                        3'd6: F_mode_char_bits = 5'b11110;
                        default: F_mode_char_bits = 5'b00000;
                    endcase
                end
                8'h54: begin // T
                    case(I_row) 3'd0:F_mode_char_bits=5'b11111; 3'd1:F_mode_char_bits=5'b00100; 3'd2:F_mode_char_bits=5'b00100; 3'd3:F_mode_char_bits=5'b00100; 3'd4:F_mode_char_bits=5'b00100; 3'd5:F_mode_char_bits=5'b00100; 3'd6:F_mode_char_bits=5'b00100; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h55: begin // U
                    case(I_row) 3'd0:F_mode_char_bits=5'b10001; 3'd1:F_mode_char_bits=5'b10001; 3'd2:F_mode_char_bits=5'b10001; 3'd3:F_mode_char_bits=5'b10001; 3'd4:F_mode_char_bits=5'b10001; 3'd5:F_mode_char_bits=5'b10001; 3'd6:F_mode_char_bits=5'b01110; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h57: begin // W
                    case(I_row) 3'd0:F_mode_char_bits=5'b10001; 3'd1:F_mode_char_bits=5'b10001; 3'd2:F_mode_char_bits=5'b10001; 3'd3:F_mode_char_bits=5'b10101; 3'd4:F_mode_char_bits=5'b10101; 3'd5:F_mode_char_bits=5'b11011; 3'd6:F_mode_char_bits=5'b01010; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h59: begin // Y
                    case(I_row) 3'd0:F_mode_char_bits=5'b10001; 3'd1:F_mode_char_bits=5'b10001; 3'd2:F_mode_char_bits=5'b01010; 3'd3:F_mode_char_bits=5'b00100; 3'd4:F_mode_char_bits=5'b00100; 3'd5:F_mode_char_bits=5'b00100; 3'd6:F_mode_char_bits=5'b00100; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h58: begin // X
                    case(I_row) 3'd0:F_mode_char_bits=5'b10001; 3'd1:F_mode_char_bits=5'b10001; 3'd2:F_mode_char_bits=5'b01010; 3'd3:F_mode_char_bits=5'b00100; 3'd4:F_mode_char_bits=5'b01010; 3'd5:F_mode_char_bits=5'b10001; 3'd6:F_mode_char_bits=5'b10001; default:F_mode_char_bits=5'b00000; endcase
                end
                8'h3a: begin // colon
                    case(I_row) 3'd2:F_mode_char_bits=5'b00100; 3'd5:F_mode_char_bits=5'b00100; default:F_mode_char_bits=5'b00000; endcase
                end
                default: F_mode_char_bits = 5'b00000;
            endcase
        end
    endfunction

    // Unified prefix character library (16x16 rows): an/lu/C/N/T/:
    function [15:0] F_osd_char16_row;
        input [7:0] I_char;
        input [3:0] I_row;
        begin
            case(I_char)
                CHAR_AN: begin
                    case(I_row)
                        4'd0:  F_osd_char16_row = 16'h0200;
                        4'd1:  F_osd_char16_row = 16'h7ff0;
                        4'd2:  F_osd_char16_row = 16'h4410;
                        4'd3:  F_osd_char16_row = 16'h0400;
                        4'd4:  F_osd_char16_row = 16'h7ff0;
                        4'd5:  F_osd_char16_row = 16'h0840;
                        4'd6:  F_osd_char16_row = 16'h1040;
                        4'd7:  F_osd_char16_row = 16'h1c80;
                        4'd8:  F_osd_char16_row = 16'h0300;
                        4'd9:  F_osd_char16_row = 16'h0cc0;
                        4'd10: F_osd_char16_row = 16'h7020;
                        default: F_osd_char16_row = 16'h0000;
                    endcase
                end
                CHAR_LU: begin
                    case(I_row)
                        4'd0:  F_osd_char16_row = 16'h79e0;
                        4'd1:  F_osd_char16_row = 16'h4a20;
                        4'd2:  F_osd_char16_row = 16'h4d40;
                        4'd3:  F_osd_char16_row = 16'h7880;
                        4'd4:  F_osd_char16_row = 16'h1140;
                        4'd5:  F_osd_char16_row = 16'h1630;
                        4'd6:  F_osd_char16_row = 16'h5be0;
                        4'd7:  F_osd_char16_row = 16'h5220;
                        4'd8:  F_osd_char16_row = 16'h5220;
                        4'd9:  F_osd_char16_row = 16'h5be0;
                        4'd10: F_osd_char16_row = 16'h6220;
                        default: F_osd_char16_row = 16'h0000;
                    endcase
                end
                CHAR_C: begin
                    case(I_row)
                        4'd2:  F_osd_char16_row = 16'h03f0;
                        4'd3:  F_osd_char16_row = 16'h0c0c;
                        4'd4:  F_osd_char16_row = 16'h1800;
                        4'd5:  F_osd_char16_row = 16'h3000;
                        4'd6:  F_osd_char16_row = 16'h3000;
                        4'd7:  F_osd_char16_row = 16'h3000;
                        4'd8:  F_osd_char16_row = 16'h3000;
                        4'd9:  F_osd_char16_row = 16'h3000;
                        4'd10: F_osd_char16_row = 16'h1800;
                        4'd11: F_osd_char16_row = 16'h0c0c;
                        4'd12: F_osd_char16_row = 16'h03f0;
                        default: F_osd_char16_row = 16'h0000;
                    endcase
                end
                CHAR_N: begin
                    case(I_row)
                        4'd2:  F_osd_char16_row = 16'h300c;
                        4'd3:  F_osd_char16_row = 16'h380c;
                        4'd4:  F_osd_char16_row = 16'h3c0c;
                        4'd5:  F_osd_char16_row = 16'h360c;
                        4'd6:  F_osd_char16_row = 16'h330c;
                        4'd7:  F_osd_char16_row = 16'h318c;
                        4'd8:  F_osd_char16_row = 16'h30cc;
                        4'd9:  F_osd_char16_row = 16'h306c;
                        4'd10: F_osd_char16_row = 16'h303c;
                        4'd11: F_osd_char16_row = 16'h301c;
                        4'd12: F_osd_char16_row = 16'h300c;
                        default: F_osd_char16_row = 16'h0000;
                    endcase
                end
                CHAR_T: begin
                    case(I_row)
                        4'd2:  F_osd_char16_row = 16'h3ffc;
                        4'd3:  F_osd_char16_row = 16'h03c0;
                        4'd4:  F_osd_char16_row = 16'h03c0;
                        4'd5:  F_osd_char16_row = 16'h03c0;
                        4'd6:  F_osd_char16_row = 16'h03c0;
                        4'd7:  F_osd_char16_row = 16'h03c0;
                        4'd8:  F_osd_char16_row = 16'h03c0;
                        4'd9:  F_osd_char16_row = 16'h03c0;
                        4'd10: F_osd_char16_row = 16'h03c0;
                        4'd11: F_osd_char16_row = 16'h03c0;
                        4'd12: F_osd_char16_row = 16'h03c0;
                        default: F_osd_char16_row = 16'h0000;
                    endcase
                end
                CHAR_COLON: begin
                    case(I_row)
                        4'd6:  F_osd_char16_row = 16'h0180;
                        4'd7:  F_osd_char16_row = 16'h0180;
                        4'd10: F_osd_char16_row = 16'h0180;
                        4'd11: F_osd_char16_row = 16'h0180;
                        default: F_osd_char16_row = 16'h0000;
                    endcase
                end
                default: F_osd_char16_row = 16'h0000;
            endcase
        end
    endfunction

    assign O_video_rd_en = I_video_de;

    anlogic_logo_rom u_anlogic_logo_rom(
        .I_addr  ( S_logo_addr  ),
        .O_pixel ( S_logo_pixel )
    );

    osd_char_lib u_osd_char_lib(
        .I_char     ( S_pf_char     ),
        .I_row      ( S_pf_row      ),
        .O_row_bits ( S_pf_row_bits )
    );

    // The mode arrives from video_out already associated with the selected
    // DDR frame slot. Lock it only at the HDMI frame marker so the caption
    // cannot change partway through a displayed frame. Gain arrives as a
    // stable data bus with a synchronized update toggle.
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_display_mode_frame <= 3'd0;
            S_gain_level_bus_1d   <= 2'b00;
            S_gain_level_bus_2d   <= 2'b00;
            S_gain_level_toggle_1d <= 1'b0;
            S_gain_level_toggle_2d <= 1'b0;
            S_gain_level_toggle_seen <= 1'b0;
            S_gain_level_captured <= 2'b00;
            S_gain_level_frame    <= 2'b00;
            S_awb_enable_sync <= 2'b11;
            S_awb_enable_frame <= 1'b1;
            S_inspection_object_frame <= 1'b0;
            S_inspection_baseline_valid_frame <= 1'b0;
            S_inspection_result_code_frame <= 2'd0;
            S_inspection_black_count_bcd_frame <= 24'd0;
            S_inspection_bbox_min_x_frame <= 11'd0;
            S_inspection_bbox_max_x_frame <= 11'd0;
            S_inspection_bbox_min_y_frame <= 11'd0;
            S_inspection_bbox_max_y_frame <= 11'd0;
            S_shape_valid_frame <= 1'b0;
            S_shape_result_code_frame <= 2'd3;
            S_shape_score_frame <= 11'd0;
            S_shape_angle_frame <= 9'd0;
            S_quality_valid_frame <= 0;
            S_quality_grade_frame <= 0;
            S_pass_count_bcd_frame <= 0;
            S_fail_count_bcd_frame <= 0;
            S_track_anchor_x_frame <= 12'd0;
            S_track_anchor_y_frame <= 12'd0;
            S_track_center_x_frame <= 11'd0;
            S_track_center_y_frame <= 11'd0;
            S_video_latency_valid_frame <= 1'b0;
            S_video_latency_ms_frame <= 12'd0;
            S_camera_fps_bcd_frame <= 8'h00;
            S_quality_score_bcd_frame <= 0;
            S_quality_shift <= 0;
            S_quality_count <= 0;
        end
        else begin
            S_awb_enable_sync <= {S_awb_enable_sync[0], I_awb_enable};
            S_gain_level_bus_1d <= I_gain_level;
            S_gain_level_bus_2d <= S_gain_level_bus_1d;
            S_gain_level_toggle_1d <= I_gain_level_update_toggle;
            S_gain_level_toggle_2d <= S_gain_level_toggle_1d;
            if(S_gain_level_toggle_2d != S_gain_level_toggle_seen) begin
                S_gain_level_captured <= S_gain_level_bus_2d;
                S_gain_level_toggle_seen <= S_gain_level_toggle_2d;
            end
            if(I_video_user) begin
                S_display_mode_frame <= I_display_mode;
                S_gain_level_frame <= S_gain_level_captured;
                S_awb_enable_frame <= S_awb_enable_sync[1];
                S_inspection_object_frame <= I_inspection_object;
                S_inspection_baseline_valid_frame <= I_inspection_baseline_valid;
                S_inspection_result_code_frame <= I_inspection_result_code;
                S_inspection_black_count_bcd_frame <= I_inspection_black_count_bcd;
                S_inspection_bbox_min_x_frame <= I_inspection_bbox_min_x;
                S_inspection_bbox_max_x_frame <= I_inspection_bbox_max_x;
                S_inspection_bbox_min_y_frame <= I_inspection_bbox_min_y;
                S_inspection_bbox_max_y_frame <= I_inspection_bbox_max_y;
                S_shape_valid_frame <= I_shape_valid;
                S_shape_result_code_frame <= I_shape_result_code;
                S_shape_score_frame <= I_shape_score;
                S_shape_angle_frame <= I_shape_angle;
                S_quality_valid_frame <= I_quality_valid;
                S_quality_grade_frame <= I_quality_valid ? I_quality_grade:3'd0;
                S_pass_count_bcd_frame <= I_pass_count_bcd;
                S_fail_count_bcd_frame <= I_fail_count_bcd;
                // Box, center and label position are latched together.
                S_track_center_x_frame <= S_bbox_center_x_sum[11:1];
                S_track_center_y_frame <= S_bbox_center_y_sum[11:1];
                if (I_inspection_bbox_max_x <= 11'd1064)
                    S_track_anchor_x_frame <=
                        {1'b0,I_inspection_bbox_max_x} + 12'd8;
                else if (I_inspection_bbox_min_x >= 11'd264)
                    S_track_anchor_x_frame <=
                        {1'b0,I_inspection_bbox_min_x} - 12'd80;
                else
                    S_track_anchor_x_frame <=
                        {1'b0,I_inspection_bbox_min_x} + 12'd80;
                S_track_anchor_y_frame <=
                    I_inspection_bbox_min_y > 11'd696 ? 12'd696 :
                    {1'b0,I_inspection_bbox_min_y};
                S_video_latency_valid_frame <= I_video_latency_valid;
                S_video_latency_ms_frame <= I_video_latency_ms;
                S_camera_fps_bcd_frame <= I_camera_fps_bcd;
                S_quality_score_bcd_frame <= 0;
                S_quality_shift <= I_quality_score;
                S_quality_count <= 4'd7;
            end else if(S_quality_count != 0) begin
                S_quality_score_bcd_frame <= {
                    S_quality_adjust[10:0],S_quality_shift[6]
                };
                S_quality_shift <= {S_quality_shift[5:0],1'b0};
                S_quality_count <= S_quality_count-1'b1;
            end
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_x <= 12'd0;
            S_y <= 12'd0;
        end
        else if(I_video_user) begin
            S_x <= 12'd0;
            S_y <= 12'd0;
        end
        else if(I_video_de) begin
            if(I_video_last) begin
                S_x <= 12'd0;
                S_y <= S_y + 12'd1;
            end
            else begin
                S_x <= S_x + 12'd1;
            end
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_frame_cnt <= 32'd0;
            S_cnt_d0 <= 4'd0;
            S_cnt_d1 <= 4'd0;
            S_cnt_d2 <= 4'd0;
            S_cnt_d3 <= 4'd0;
            S_cnt_d4 <= 4'd0;
            S_cnt_d5 <= 4'd0;
        end
        else if(I_video_user) begin
            S_frame_cnt <= S_frame_cnt + 32'd1;
            if(S_cnt_d0 == 4'd9) begin
                S_cnt_d0 <= 4'd0;
                if(S_cnt_d1 == 4'd9) begin
                    S_cnt_d1 <= 4'd0;
                    if(S_cnt_d2 == 4'd9) begin
                        S_cnt_d2 <= 4'd0;
                        if(S_cnt_d3 == 4'd9) begin
                            S_cnt_d3 <= 4'd0;
                            if(S_cnt_d4 == 4'd9) begin
                                S_cnt_d4 <= 4'd0;
                                if(S_cnt_d5 == 4'd9)
                                    S_cnt_d5 <= 4'd0;
                                else
                                    S_cnt_d5 <= S_cnt_d5 + 4'd1;
                            end
                            else
                                S_cnt_d4 <= S_cnt_d4 + 4'd1;
                        end
                        else
                            S_cnt_d3 <= S_cnt_d3 + 4'd1;
                    end
                    else
                        S_cnt_d2 <= S_cnt_d2 + 4'd1;
                end
                else
                    S_cnt_d1 <= S_cnt_d1 + 4'd1;
            end
            else
                S_cnt_d0 <= S_cnt_d0 + 4'd1;
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_x_1d <= 12'd0;
            S_x_2d <= 12'd0;
            S_y_1d <= 12'd0;
            S_y_2d <= 12'd0;
        end
        else begin
            S_x_1d <= S_x;
            S_x_2d <= S_x_1d;
            S_y_1d <= S_y;
            S_y_2d <= S_y_1d;
        end
    end

    always @(*) begin
        S_osd_hit   = 1'b0;
        S_osd_color = 24'd0;
        S_logo_addr = 15'd0;

        S_logo_x = 12'd0;
        S_logo_y = 12'd0;
        S_char_idx = 4'd0;
        S_char_row = 3'd0;
        S_char_col = 3'd0;
        S_char_bits = 5'd0;
        S_char_on = 1'b0;
        S_logo_blue_on = 1'b0;
        S_logo_red_on = 1'b0;
        S_logo_tmp_y = 12'd0;
        S_logo_red_band = 4'd0;
        S_logo_red_x_start = 12'd0;
        S_logo_red_x_end = 12'd0;
        S_dyn_x = 12'd0;
        S_dyn_y = 12'd0;
        S_dyn_char = 4'd0;
        S_dyn_col = 3'd0;
        S_dyn_row = 3'd0;
        S_dyn_bits = 5'd0;
        S_dyn_on = 1'b0;
        S_dyn_digit_idx = 4'd0;
        S_dyn_digit_x = 12'd0;
        S_dyn_seg = 7'd0;
        S_mode_char_idx = 5'd0;
        S_mode_char = 8'h20;
        S_mode_col = 3'd0;
        S_mode_row = 3'd0;
        S_mode_bits = 5'd0;
        S_mode_on = 1'b0;
        S_gain_char_idx = 5'd0;
        S_gain_char = 8'h20;
        S_gain_col = 3'd0;
        S_gain_row = 3'd0;
        S_gain_bits = 5'd0;
        S_gain_on = 1'b0;
        S_awb_char_idx = 3'd0;
        S_awb_col = 3'd0;
        S_awb_char = 8'h20;
        S_awb_row = 3'd0;
        S_awb_bits = 5'd0;
        S_status_char_idx = 5'd0;
        S_status_char = 8'h20;
        S_status_col = 3'd0;
        S_status_row = 3'd0;
        S_status_bits = 5'd0;
        S_status_on = 1'b0;
        S_result_char_idx = 5'd0;
        S_result_char = 8'h20;
        S_result_row = 3'd0;
        S_result_bits = 5'd0;
        S_result_on = 1'b0;
        S_shape_char_idx = 5'd0;
        S_shape_char = 8'h20;
        S_shape_row = 3'd0;
        S_shape_bits = 5'd0;
        S_shape_on = 1'b0;
        S_shape_info_char_idx = 5'd0;
        S_shape_info_char = 8'h20;
        S_shape_info_digit = 4'd0;
        S_shape_info_row = 3'd0;
        S_shape_info_bits = 5'd0;
        S_shape_info_on = 1'b0;
        S_dyn_glyph_char = " ";
        S_dyn_glyph_digit = 0;
        S_dyn_glyph_row = 0;
        S_dyn_glyph_kind = 0;
        S_dyn_glyph_is_digit = 0;
        S_dyn_glyph_active = 0;
        S_dyn_glyph_bits = 0;
        S_count_x = 12'd0;
        S_count_char_idx = 4'd0;
        S_count_char = 8'h20;
        S_count_digit = 4'd0;
        S_count_row = 3'd0;
        S_count_bits = 5'd0;
        S_count_on = 1'b0;
        S_track_osd_x = 12'd0;
        S_track_char_idx = 5'd0;
        S_track_char = 8'h20;
        S_track_digit = 4'd0;
        S_track_row = 3'd0;
        S_track_bits = 5'd0;
        S_track_on = 1'b0;
        S_track_is_digit = 1'b0;
        S_quality_char_idx = 0;
        S_quality_char = " ";
        S_quality_row = 0;
        S_quality_bits = 0;
        S_lbl_row = 3'd0;
        S_lbl_col = 3'd0;
        S_lbl_idx = 2'd0;
        S_lbl_bits = 5'd0;
        S_lbl_local_x = 7'd0;
        S_dyn_dec_digit = 4'd0;
        S_cn_local_x = 5'd0;
        S_cn_local_y = 5'd0;
        S_cn_col = 4'd0;
        S_cn_row = 4'd0;
        S_cn_row_bits = 16'd0;
        S_cn_on = 1'b0;
        S_cn_scale_x = 10'd0;
        S_cn_scale_y = 10'd0;
        S_pf_char = 8'd0;
        S_pf_local_x = 5'd0;
        S_pf_local_y = 5'd0;
        S_pf_col = 4'd0;
        S_pf_row = 4'd0;
        S_pf_on = 1'b0;
        S_pf_scale_x = 10'd0;
        S_pf_scale_y = 10'd0;

        if(S_video_de_2d) begin
            if(S_inspection_object_frame &&
               (S_inspection_bbox_min_x_frame <= S_inspection_bbox_max_x_frame) &&
               (S_inspection_bbox_min_y_frame <= S_inspection_bbox_max_y_frame) &&
               (S_x_2d >= {1'b0,S_inspection_bbox_min_x_frame}) &&
               (S_x_2d <= {1'b0,S_inspection_bbox_max_x_frame}) &&
               (S_y_2d >= {1'b0,S_inspection_bbox_min_y_frame}) &&
               (S_y_2d <= {1'b0,S_inspection_bbox_max_y_frame}) &&
               ((S_x_2d == {1'b0,S_inspection_bbox_min_x_frame}) ||
                (S_x_2d == {1'b0,S_inspection_bbox_max_x_frame}) ||
                (S_y_2d == {1'b0,S_inspection_bbox_min_y_frame}) ||
                (S_y_2d == {1'b0,S_inspection_bbox_max_y_frame}))) begin
                S_osd_hit = 1'b1;
                S_osd_color = COLOR_BBOX;
            end

            // DEBUG ROI: attach the ID and box center to the same frame's box.
            if((S_display_mode_frame == 3'd4) &&
               S_inspection_object_frame &&
               (S_x_2d >= S_track_anchor_x_frame) &&
               (S_x_2d < S_track_anchor_x_frame + TRACK_OSD_W) &&
               (S_y_2d >= S_track_anchor_y_frame) &&
               (S_y_2d < S_track_anchor_y_frame + TRACK_OSD_H)) begin
                S_track_osd_x = S_x_2d - S_track_anchor_x_frame;
                S_track_char_idx = S_track_osd_x[11:3];
                S_track_row = S_y_2d - S_track_anchor_y_frame;
                case((S_y_2d - S_track_anchor_y_frame) >> 3)
                    2'd0: begin
                        S_track_char = F_track_label_char(3'd0,
                                                          S_track_char_idx);
                        if(S_track_char_idx == 5'd3) begin
                            S_track_digit = 4'd1;
                            S_track_is_digit = 1'b1;
                        end
                    end
                    2'd1: begin
                        S_track_char = F_track_label_char(3'd1,
                                                          S_track_char_idx);
                        if(S_track_char_idx == 5'd5) begin
                            S_track_digit = {1'b0,S_track_center_x_frame[10:8]};
                            S_track_is_digit = 1'b1;
                        end
                        else if(S_track_char_idx == 5'd6) begin
                            S_track_digit = S_track_center_x_frame[7:4];
                            S_track_is_digit = 1'b1;
                        end
                        else if(S_track_char_idx == 5'd7) begin
                            S_track_digit = S_track_center_x_frame[3:0];
                            S_track_is_digit = 1'b1;
                        end
                    end
                    2'd2: begin
                        S_track_char = F_track_label_char(3'd2,
                                                          S_track_char_idx);
                        if(S_track_char_idx == 5'd5) begin
                            S_track_digit = {1'b0,S_track_center_y_frame[10:8]};
                            S_track_is_digit = 1'b1;
                        end
                        else if(S_track_char_idx == 5'd6) begin
                            S_track_digit = S_track_center_y_frame[7:4];
                            S_track_is_digit = 1'b1;
                        end
                        else if(S_track_char_idx == 5'd7) begin
                            S_track_digit = S_track_center_y_frame[3:0];
                            S_track_is_digit = 1'b1;
                        end
                    end
                    default: S_track_char = 8'h20;
                endcase
                S_track_bits = S_track_is_digit ?
                    F_dyn_char_bits(S_track_digit,S_track_row) :
                    F_mode_char_bits(S_track_char,S_track_row);
                if((S_track_osd_x[2:0] < 3'd5) &&
                   (S_track_row < 3'd7))
                    S_track_on = S_track_bits[4-S_track_osd_x[2:0]];
                if(S_track_on) begin
                    S_osd_hit = 1'b1;
                    S_osd_color = COLOR_TRACK_TEXT;
                end
            end

            // This number follows the DDR slot shown on HDMI, not QUALITY.
            if((S_display_mode_frame == 3'd4) &&
               (S_x_2d >= TELEMETRY_OSD_X) &&
               (S_x_2d < TELEMETRY_OSD_X + TELEMETRY_OSD_W) &&
               (S_y_2d >= TELEMETRY_OSD_Y) &&
               (S_y_2d < TELEMETRY_OSD_Y + TELEMETRY_OSD_H)) begin
                S_track_osd_x = S_x_2d - TELEMETRY_OSD_X;
                S_track_char_idx = S_track_osd_x[11:3];
                S_track_row = S_y_2d - TELEMETRY_OSD_Y;
                S_track_char = 8'h20;
                S_track_is_digit = 1'b0;
                S_track_on = 1'b0;
                if((S_y_2d - TELEMETRY_OSD_Y) < 12'd8) begin
                    S_track_char = F_track_label_char(3'd3,S_track_char_idx);
                    if(!S_video_latency_valid_frame &&
                       (S_track_char_idx == 5'd4 ||
                        S_track_char_idx == 5'd5))
                        S_track_char = 8'h20;
                    if(S_track_char_idx >= 5'd6 &&
                       S_track_char_idx <= 5'd8) begin
                        if(S_video_latency_valid_frame) begin
                            case(S_track_char_idx)
                                5'd6: S_track_digit = S_video_latency_ms_frame[11:8];
                                5'd7: S_track_digit = S_video_latency_ms_frame[7:4];
                                default: S_track_digit = S_video_latency_ms_frame[3:0];
                            endcase
                            S_track_is_digit = 1'b1;
                        end else
                            S_track_char = 8'h2d;
                    end
                end else if((S_y_2d - TELEMETRY_OSD_Y) < 12'd16) begin
                    S_track_char = F_track_label_char(3'd4,S_track_char_idx);
                    if(S_track_char_idx == 5'd6 ||
                       S_track_char_idx == 5'd7) begin
                        S_track_digit = S_track_char_idx == 5'd6 ?
                            S_camera_fps_bcd_frame[7:4] :
                            S_camera_fps_bcd_frame[3:0];
                        S_track_is_digit = 1'b1;
                    end
                end
                S_track_bits = S_track_is_digit ?
                    F_dyn_char_bits(S_track_digit,S_track_row) :
                    F_mode_char_bits(S_track_char,S_track_row);
                if((S_track_osd_x[2:0] < 3'd5) &&
                   (S_track_row < 3'd7))
                    S_track_on = S_track_bits[4-S_track_osd_x[2:0]];
                if(S_track_on) begin
                    S_osd_hit = 1'b1;
                    S_osd_color = COLOR_DYN_TEXT;
                end
            end

            if((S_x_2d >= COUNT_OSD_X) &&
               (S_x_2d < COUNT_OSD_X + COUNT_OSD_W) &&
               (S_y_2d >= COUNT_OSD_Y) && (S_y_2d < COUNT_OSD_Y + 12'd8)) begin
                S_count_x = S_x_2d - COUNT_OSD_X;
                S_count_char_idx = S_count_x[11:3];
                S_count_row = S_y_2d - COUNT_OSD_Y;
                case(S_count_char_idx)
                    4'd0: S_count_char = 8'h42; // B
                    4'd1: S_count_char = 8'h4c; // L
                    4'd2: S_count_char = 8'h41; // A
                    4'd3: S_count_char = 8'h43; // C
                    4'd4: S_count_char = 8'h4b; // K
                    4'd5: S_count_char = 8'h3a; // :
                    default: begin
                        case(S_count_char_idx)
                            4'd6: S_count_digit = S_inspection_black_count_bcd_frame[23:20];
                            4'd7: S_count_digit = S_inspection_black_count_bcd_frame[19:16];
                            4'd8: S_count_digit = S_inspection_black_count_bcd_frame[15:12];
                            4'd9: S_count_digit = S_inspection_black_count_bcd_frame[11:8];
                            4'd10: S_count_digit = S_inspection_black_count_bcd_frame[7:4];
                            default: S_count_digit = S_inspection_black_count_bcd_frame[3:0];
                        endcase
                        S_count_char = 8'h30 + {4'd0,S_count_digit};
                    end
                endcase
                S_count_bits = (S_count_char_idx < 4'd6) ?
                    F_mode_char_bits(S_count_char,S_count_row) :
                    F_dyn_char_bits(S_count_digit,S_count_row);
                if((S_count_x[2:0] < 3'd5) && (S_count_row < 3'd7))
                    S_count_on = S_count_bits[4 - S_count_x[2:0]];
                if(S_count_on) begin
                    S_osd_hit = 1'b1;
                    S_osd_color = COLOR_DYN_TEXT;
                end
            end

            if((S_x_2d >= COUNT_OSD_X) &&
               (S_x_2d < COUNT_OSD_X + QUALITY_OSD_W) &&
               (((S_y_2d >= QUALITY_OSD_Y) &&
                 (S_y_2d < QUALITY_OSD_Y + 12'd8)) ||
                ((S_y_2d >= GRADE_OSD_Y) &&
                 (S_y_2d < GRADE_OSD_Y + 12'd8)) ||
                ((S_display_mode_frame == 3'd4) &&
                 (((S_y_2d >= PASS_OSD_Y) &&
                   (S_y_2d < PASS_OSD_Y + 12'd8)) ||
                  ((S_y_2d >= FAIL_OSD_Y) &&
                   (S_y_2d < FAIL_OSD_Y + 12'd8)))))) begin
                S_quality_char_idx = (S_x_2d - COUNT_OSD_X) >> 3;
                if(S_y_2d < GRADE_OSD_Y) begin
                    S_quality_row = S_y_2d - QUALITY_OSD_Y;
                    S_quality_char = F_quality_label(S_quality_char_idx);
                    case(S_quality_char_idx)
                        9:S_quality_char = S_quality_valid_frame &&
                            S_quality_score_bcd_frame[11:8]!=0 ?
                            "0"+S_quality_score_bcd_frame[11:8]:" ";
                        10:S_quality_char = S_quality_valid_frame ?
                             ((S_quality_score_bcd_frame[11:8]!=0 ||
                               S_quality_score_bcd_frame[7:4]!=0) ?
                              "0"+S_quality_score_bcd_frame[7:4]:" ") : "-";
                        11:S_quality_char = S_quality_valid_frame ?
                             "0"+S_quality_score_bcd_frame[3:0]:"-";
                        12:S_quality_char = "%";
                    endcase
                end else if(S_y_2d < PASS_OSD_Y) begin
                    S_quality_row = S_y_2d - GRADE_OSD_Y;
                    S_quality_char = S_quality_char_idx < 6 ?
                        F_grade_label(S_quality_char_idx) :
                        F_grade_value(S_quality_grade_frame,
                                      S_quality_char_idx-7);
                end else begin
                    S_quality_row = S_y_2d < FAIL_OSD_Y ?
                                    S_y_2d-PASS_OSD_Y : S_y_2d-FAIL_OSD_Y;
                    S_quality_char = " ";
                    if(S_quality_char_idx < 4) begin
                        if(S_y_2d < FAIL_OSD_Y)
                            case(S_quality_char_idx)
                                0:S_quality_char="P"; 1:S_quality_char="A";
                                2:S_quality_char="S"; 3:S_quality_char="S";
                            endcase
                        else
                            case(S_quality_char_idx)
                                0:S_quality_char="F"; 1:S_quality_char="A";
                                2:S_quality_char="I"; 3:S_quality_char="L";
                            endcase
                    end else if(S_quality_char_idx == 4)
                        S_quality_char = ":";
                    else if(S_quality_char_idx >= 6 &&
                            S_quality_char_idx <= 10) begin
                        case(S_quality_char_idx)
                            6:S_quality_char="0" + (S_y_2d < FAIL_OSD_Y ?
                                S_pass_count_bcd_frame[19:16] : S_fail_count_bcd_frame[19:16]);
                            7:S_quality_char="0" + (S_y_2d < FAIL_OSD_Y ?
                                S_pass_count_bcd_frame[15:12] : S_fail_count_bcd_frame[15:12]);
                            8:S_quality_char="0" + (S_y_2d < FAIL_OSD_Y ?
                                S_pass_count_bcd_frame[11:8] : S_fail_count_bcd_frame[11:8]);
                            9:S_quality_char="0" + (S_y_2d < FAIL_OSD_Y ?
                                S_pass_count_bcd_frame[7:4] : S_fail_count_bcd_frame[7:4]);
                            10:S_quality_char="0" + (S_y_2d < FAIL_OSD_Y ?
                                 S_pass_count_bcd_frame[3:0] : S_fail_count_bcd_frame[3:0]);
                        endcase
                    end
                end
                if(S_quality_char >= "0" && S_quality_char <= "9")
                    S_quality_bits = F_dyn_char_bits(
                        S_quality_char-"0",S_quality_row);
                else
                    S_quality_bits = F_mode_char_bits(S_quality_char,
                                                     S_quality_row);
                if(((S_x_2d-COUNT_OSD_X) & 12'd7) < 5 &&
                   S_quality_row < 7 &&
                   S_quality_bits[4-((S_x_2d-COUNT_OSD_X) & 12'd7)]) begin
                    S_osd_hit = 1;
                    S_osd_color = COLOR_DYN_TEXT;
                end
            end

            if((S_x_2d >= LOGO_X) && (S_x_2d < (LOGO_X + LOGO_W)) &&
               (S_y_2d >= LOGO_Y) && (S_y_2d < (LOGO_Y + LOGO_H))) begin
                S_logo_x = S_x_2d - LOGO_X;
                S_logo_y = S_y_2d - LOGO_Y;
                // 160*y = 128*y + 32*y; avoid a variable multiplier in the
                // HDMI pixel-clock combinational path.
                S_logo_addr = ({3'd0, S_logo_y} << 7) +
                              ({3'd0, S_logo_y} << 5) +
                              S_logo_x;
                if(S_logo_pixel[24]) begin
                    S_osd_hit   = 1'b1;
                    S_osd_color = S_logo_pixel[23:0];
                end
            end

            if((S_x_2d >= DYN_OSD_X) && (S_x_2d < (DYN_OSD_X + DYN_OSD_W)) &&
               (S_y_2d >= DYN_OSD_Y) && (S_y_2d < (DYN_OSD_Y + DYN_OSD_H))) begin
                S_dyn_x = S_x_2d - DYN_OSD_X;
                S_dyn_y = S_y_2d - DYN_OSD_Y;

                  // Five 8x8 rows below the logo; shape status is Debug-only.
                 if((S_dyn_y < DYN_OSD_H) && (S_dyn_x < DYN_OSD_W)) begin
                      if(S_dyn_y < 12'd8) begin
                         S_mode_char_idx = S_dyn_x[11:3];
                         S_mode_char = F_mode_text_char(S_display_mode_frame,
                                                         S_mode_char_idx);
                         S_mode_row = S_dyn_y[2:0];
                         S_dyn_glyph_char = S_mode_char;
                         S_dyn_glyph_row = S_mode_row;
                         S_dyn_glyph_kind = 0;
                         S_dyn_glyph_active = 1;
                     end
                      else if(S_dyn_y < 12'd16) begin
                          S_gain_char_idx = S_dyn_x[11:3];
                          S_gain_char = F_gain_text_char(S_gain_level_frame,
                                                         S_gain_char_idx);
                         S_gain_row = S_dyn_y - 12'd8;
                          S_dyn_glyph_char = S_gain_char;
                          S_dyn_glyph_row = S_gain_row;
                          S_dyn_glyph_kind = 1;
                          S_dyn_glyph_active = 1;
                      end
                       else if(S_dyn_y < 12'd24) begin
                          S_status_char_idx = S_dyn_x[11:3];
                          S_status_char = F_inspection_text_char(
                              S_inspection_object_frame, S_status_char_idx);
                          S_status_row = S_dyn_y - 12'd16;
                          S_dyn_glyph_char = S_status_char;
                          S_dyn_glyph_row = S_status_row;
                          S_dyn_glyph_kind = 2;
                          S_dyn_glyph_active = 1;
                       end
                       else if(S_dyn_y < 12'd32) begin
                           S_result_char_idx = S_dyn_x[11:3];
                           S_result_char = F_result_text_char(
                               S_inspection_baseline_valid_frame ?
                                   S_inspection_result_code_frame : 2'd0,
                               S_result_char_idx);
                           S_result_row = S_dyn_y - 12'd24;
                           S_dyn_glyph_char = S_result_char;
                           S_dyn_glyph_row = S_result_row;
                           S_dyn_glyph_kind = 3;
                           S_dyn_glyph_active = 1;
                       end
                       else if((S_display_mode_frame == 3'd4) &&
                               S_shape_valid_frame) begin
                           if(S_dyn_y < 12'd40) begin
                               S_shape_char_idx = S_dyn_x[11:3];
                               S_shape_char = F_shape_text_char(
                                   S_shape_result_code_frame,S_shape_char_idx);
                               S_shape_row = S_dyn_y - 12'd32;
                               S_dyn_glyph_char = S_shape_char;
                               S_dyn_glyph_row = S_shape_row;
                               S_dyn_glyph_kind = 4;
                               S_dyn_glyph_active = 1;
                           end
                           else if(S_dyn_y < 12'd48) begin
                               // SCORE:0xXXX, using the locked frame score.
                               S_shape_info_char_idx = S_dyn_x[11:3];
                               S_shape_info_char = F_shape_info_char(
                                   2'd0,S_shape_info_char_idx);
                               case(S_shape_info_char_idx)
                                   5'd8: S_shape_info_digit =
                                       {1'b0,S_shape_score_frame[10:8]};
                                   5'd9: S_shape_info_digit =
                                       S_shape_score_frame[7:4];
                                   5'd10: S_shape_info_digit =
                                       S_shape_score_frame[3:0];
                                   default: S_shape_info_digit = 4'd0;
                               endcase
                               if((S_shape_info_char_idx == 5'd6) ||
                                   ((S_shape_info_char_idx >= 5'd8) &&
                                   (S_shape_info_char_idx <= 5'd10)))
                                   S_shape_info_char = F_shape_hex_char(
                                       S_shape_info_digit);
                               S_shape_info_row = S_dyn_y - 12'd40;
                               S_dyn_glyph_char = S_shape_info_char;
                               S_dyn_glyph_digit = S_shape_info_digit;
                               S_dyn_glyph_row = S_shape_info_row;
                               S_dyn_glyph_kind = 5;
                               S_dyn_glyph_is_digit =
                                   (S_shape_info_char_idx == 5'd6) ||
                                   ((S_shape_info_char_idx >= 5'd8) &&
                                    (S_shape_info_char_idx <= 5'd10));
                               S_dyn_glyph_active = 1;
                           end
                           else begin
                               // ANGLE in whole degrees, 000..179.
                               S_shape_info_char_idx = S_dyn_x[11:3];
                               S_shape_info_char = F_shape_info_char(
                                   2'd1,S_shape_info_char_idx);
                               case(S_shape_info_char_idx)
                                   5'd6: S_shape_info_digit = S_angle_bcd[11:8];
                                   5'd7: S_shape_info_digit = S_angle_bcd[7:4];
                                   5'd8: S_shape_info_digit = S_angle_bcd[3:0];
                                   default: S_shape_info_digit = 4'd0;
                               endcase
                               if((S_shape_info_char_idx >= 5'd6) &&
                                  (S_shape_info_char_idx <= 5'd8))
                                   S_shape_info_char = F_shape_hex_char(
                                       S_shape_info_digit);
                               S_shape_info_row = S_dyn_y - 12'd48;
                               S_dyn_glyph_char = S_shape_info_char;
                               S_dyn_glyph_digit = S_shape_info_digit;
                               S_dyn_glyph_row = S_shape_info_row;
                               S_dyn_glyph_kind = 5;
                               S_dyn_glyph_is_digit =
                                   (S_shape_info_char_idx >= 5'd6) &&
                                   (S_shape_info_char_idx <= 5'd8);
                               S_dyn_glyph_active = 1;
                           end
                       end

                      if(S_dyn_glyph_active) begin
                          S_dyn_glyph_bits = S_dyn_glyph_is_digit ?
                              F_dyn_char_bits(S_dyn_glyph_digit,S_dyn_glyph_row) :
                              F_mode_char_bits(S_dyn_glyph_char,S_dyn_glyph_row);
                          if(S_dyn_x[2:0] < 3'd5 && S_dyn_glyph_row < 3'd7)
                              S_dyn_on = S_dyn_glyph_bits[4-S_dyn_x[2:0]];
                          case(S_dyn_glyph_kind)
                              0: begin S_mode_bits=S_dyn_glyph_bits; S_mode_on=S_dyn_on; end
                              1: begin S_gain_bits=S_dyn_glyph_bits; S_gain_on=S_dyn_on; end
                              2: begin S_status_bits=S_dyn_glyph_bits; S_status_on=S_dyn_on; end
                              3: begin S_result_bits=S_dyn_glyph_bits; S_result_on=S_dyn_on; end
                              4: begin S_shape_bits=S_dyn_glyph_bits; S_shape_on=S_dyn_on; end
                              5: begin S_shape_info_bits=S_dyn_glyph_bits; S_shape_info_on=S_dyn_on; end
                          endcase
                      end
                  end

                if(S_dyn_on) begin
                    S_osd_hit = 1'b1;
                    S_osd_color = COLOR_DYN_TEXT;
                end
            end
            if(S_display_mode_frame == 3'd4 &&
               S_x_2d >= DYN_OSD_X && S_x_2d < DYN_OSD_X + 12'd64 &&
               S_y_2d >= AWB_OSD_Y && S_y_2d < AWB_OSD_Y + 12'd8) begin
                S_awb_char_idx = (S_x_2d - DYN_OSD_X) >> 3;
                S_awb_col = S_x_2d[2:0] - DYN_OSD_X[2:0];
                S_awb_row = S_y_2d - AWB_OSD_Y;
                case(S_awb_char_idx)
                    3'd0: S_awb_char = 8'h41; // A
                    3'd1: S_awb_char = 8'h57; // W
                    3'd2: S_awb_char = 8'h42; // B
                    3'd3: S_awb_char = 8'h3a; // :
                    3'd4: S_awb_char = 8'h20;
                    3'd5: S_awb_char = 8'h4f; // O
                    3'd6: S_awb_char = S_awb_enable_frame ? 8'h4e : 8'h46;
                    3'd7: S_awb_char = S_awb_enable_frame ? 8'h20 : 8'h46;
                endcase
                S_awb_bits = F_mode_char_bits(S_awb_char,S_awb_row);
                if(S_awb_col < 3'd5 && S_awb_bits[4-S_awb_col]) begin
                    S_osd_hit = 1'b1;
                    S_osd_color = COLOR_DYN_TEXT;
                end
            end
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_video_vsync_1d <= 1'b0;
            S_video_vsync_2d <= 1'b0;
            S_video_hsync_1d <= 1'b0;
            S_video_hsync_2d <= 1'b0;
            S_video_de_1d    <= 1'b0;
            S_video_de_2d    <= 1'b0;
            O_hdmi_vsync     <= 1'b0;
            O_hdmi_hsync     <= 1'b0;
            O_hdmi_de        <= 1'b0;
            O_hdmi_data      <= 24'd0;
        end
        else begin
            S_video_vsync_1d <= I_video_vsync;
            S_video_vsync_2d <= S_video_vsync_1d;
            O_hdmi_vsync     <= S_video_vsync_2d;

            S_video_hsync_1d <= I_video_hsync;
            S_video_hsync_2d <= S_video_hsync_1d;
            O_hdmi_hsync     <= S_video_hsync_2d;

            S_video_de_1d    <= I_video_de;
            S_video_de_2d    <= S_video_de_1d;
            O_hdmi_de        <= S_video_de_2d;
            S_video_data_1d  <= I_video_rd_data;
            S_video_data_2d  <= S_video_data_1d;

            if(DEBUG_MODE == 1) begin
                if(S_video_de_2d) begin
                    if(S_x < 12'd128)
                        O_hdmi_data <= 24'hff0000;
                    else if(S_x < 12'd256)
                        O_hdmi_data <= 24'h00ff00;
                    else if(S_x < 12'd384)
                        O_hdmi_data <= 24'h0000ff;
                    else if(S_x < 12'd512)
                        O_hdmi_data <= 24'hffff00;
                    else if(S_x < 12'd640)
                        O_hdmi_data <= 24'h00ffff;
                    else if(S_x < 12'd768)
                        O_hdmi_data <= 24'hff00ff;
                    else if(S_x < 12'd896)
                        O_hdmi_data <= 24'hffffff;
                    else
                        O_hdmi_data <= 24'h202020;
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end
            else if(DEBUG_MODE == 2) begin
                if(S_video_de_2d) begin
                    case (I_debug_status)
                        4'b0000: O_hdmi_data <= 24'h000000;
                        4'b0001: O_hdmi_data <= 24'hff0000;
                        4'b0011: O_hdmi_data <= 24'hffff00;
                        4'b0111: O_hdmi_data <= 24'h00ff00;
                        4'b1111: O_hdmi_data <= I_video_rd_data;
                        default: O_hdmi_data <= 24'h0000ff;
                    endcase
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end
            else if(DEBUG_MODE == 3) begin
                if(S_video_de_2d) begin
                    if(S_x < 12'd256)
                        O_hdmi_data <= I_debug_status[0] ? 24'hff8000 : 24'h201000;
                    else if(S_x < 12'd512)
                        O_hdmi_data <= I_debug_status[1] ? 24'hffff00 : 24'h202000;
                    else if(S_x < 12'd768)
                        O_hdmi_data <= I_debug_status[2] ? 24'hff0000 : 24'h200000;
                    else
                        O_hdmi_data <= I_debug_status[3] ? 24'h00ffff : 24'h002020;
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end
            else begin
                if(S_osd_hit)
                    O_hdmi_data <= S_osd_color;
                else
                    O_hdmi_data <= S_video_data_2d;
            end
        end
    end

endmodule
