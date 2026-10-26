// Frame-paired, single-workpiece score. All divisions run serially at 24 MHz.
module quality_score_ctrl #(
    parameter integer ROI_WEIGHT = 40,
    parameter integer SHAPE_WEIGHT = 60
)(
    input wire I_clk, I_rst_n,
    input wire I_calibrate,
    input wire I_pair_pulse,
    input wire I_inspect_ready,
    input wire I_feature_update,
    input wire [19:0] I_live_black_count,
    input wire [19:0] I_area, I_baseline,
    input wire I_baseline_valid, I_object_present,
    input wire [10:0] I_mismatch, I_union,
    input wire I_shape_valid, I_shape_ok, I_capture,
    output reg O_valid,
    output reg [6:0] O_score,
    output reg [2:0] O_grade,
    output reg [19:0] O_pass_count_bcd,
    output reg [19:0] O_fail_count_bcd,
    output reg O_update_toggle
);
    localparam IDLE=3'd0, DIV_ROI=3'd1, DIV_SHAPE=3'd2,
               DIV_ABS=3'd3, LOAD_WEIGHT=3'd4, DIV_WEIGHT=3'd5,
               PUBLISH=3'd6;
    localparam GRADE_WAIT=3'd0, GRADE_PASS=3'd3, GRADE_FAIL=3'd4;
    reg [2:0] state;
    reg S_latched;
    reg [1:0] S_empty_frames;
    reg shape_ready;
    reg [28:0] dividend;
    reg [7:0] quotient;
    reg quotient_overflow;
    reg [20:0] remainder;
    reg [19:0] divisor;
    reg [4:0] bit_count;
    reg [10:0] mismatch_hold, union_hold;
    reg shape_ok_hold, area_ok_hold;
    reg [6:0] roi_score, shape_score;
    reg [6:0] raw_score;
    reg [7:0] relative_penalty;
    wire [21:0] trial = {remainder,dividend[28]};
    wire take = trial >= {2'b0,divisor};
    wire [21:0] next_remainder = take ? trial-{2'b0,divisor}:trial;
    wire [7:0] next_quotient = {quotient[6:0],take};
    wire next_overflow = quotient_overflow | quotient[7];
    wire [19:0] area_error = I_area >= I_baseline ?
                              I_area-I_baseline : I_baseline-I_area;
    wire area_in_range = ({4'd0,area_error} * 10) <= {4'd0,I_baseline};
    wire [13:0] weighted_score;
    wire [19:0] weight_divisor;
    generate if(ROI_WEIGHT == 40 && SHAPE_WEIGHT == 60) begin: g_default_weights
        assign weighted_score = ({7'd0,roi_score} << 1) +
                                ({7'd0,shape_score} << 1) +
                                {7'd0,shape_score};
        assign weight_divisor = 20'd5;
    end else begin: g_custom_weights
        assign weighted_score = roi_score*ROI_WEIGHT +
                                shape_score*SHAPE_WEIGHT;
        assign weight_divisor = ROI_WEIGHT+SHAPE_WEIGHT;
    end endgenerate
    wire [6:0] limited_score = (!area_ok_hold || !shape_ok_hold) &&
                               raw_score > 7'd60 ? 7'd60:raw_score;

    function [6:0] minus_penalty;
        input [31:0] penalty;
        begin
            minus_penalty = penalty >= 100 ? 7'd0 : 7'd100-penalty[6:0];
        end
    endfunction
    function [19:0] next_bcd;
        input [19:0] value;
        begin
            next_bcd = value;
            if(value != 20'h99999) begin
                if(value[3:0] != 9) next_bcd[3:0] = value[3:0]+1'b1;
                else begin
                    next_bcd[3:0] = 0;
                    if(value[7:4] != 9) next_bcd[7:4] = value[7:4]+1'b1;
                    else begin
                        next_bcd[7:4] = 0;
                        if(value[11:8] != 9) next_bcd[11:8] = value[11:8]+1'b1;
                        else begin
                            next_bcd[11:8] = 0;
                            if(value[15:12] != 9) next_bcd[15:12] = value[15:12]+1'b1;
                            else begin
                                next_bcd[15:12] = 0;
                                next_bcd[19:16] = value[19:16]+1'b1;
                            end
                        end
                    end
                end
            end
        end
    endfunction

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            state<=IDLE; shape_ready<=0;
            dividend<=0; quotient<=0; quotient_overflow<=0;
            remainder<=0; divisor<=0;
            bit_count<=0; mismatch_hold<=0; union_hold<=0;
            shape_ok_hold<=0; area_ok_hold<=0;
            roi_score<=0; shape_score<=0; raw_score<=0;
            relative_penalty<=0;
            S_latched<=0; S_empty_frames<=0;
            O_pass_count_bcd<=0; O_fail_count_bcd<=0;
            O_valid<=0; O_score<=0; O_grade<=GRADE_WAIT;
            O_update_toggle<=0;
        end else if(I_calibrate) begin
            state<=IDLE; shape_ready<=0;
            S_latched<=1; S_empty_frames<=0;
            O_valid<=0; O_grade<=GRADE_WAIT;
            // A new workpiece baseline starts a new production count window.
            O_pass_count_bcd<=0; O_fail_count_bcd<=0;
            O_update_toggle<=~O_update_toggle;
        end else if(I_pair_pulse && I_capture) begin
            state<=IDLE;
            shape_ready<=I_shape_valid;
            O_valid<=0; O_grade<=GRADE_WAIT;
            O_update_toggle<=~O_update_toggle;
        end else begin
            if(I_feature_update) begin
                if(I_live_black_count < 20'd300) begin
                    if(S_empty_frames < 2'd3)
                        S_empty_frames <= S_empty_frames+1'b1;
                end else
                    S_empty_frames <= 0;
            end
            // Re-arm only after three consecutive near-empty ROI frames.
            if(I_feature_update && I_live_black_count < 20'd300 &&
               S_empty_frames == 2'd2 && (S_latched || state != IDLE)) begin
                S_latched<=0;
                state<=IDLE;
                O_valid<=0; O_grade<=GRADE_WAIT;
                O_update_toggle<=~O_update_toggle;
            end else begin
            case(state)
                IDLE: if(I_pair_pulse && !S_latched) begin
                    if(I_inspect_ready && shape_ready &&
                       I_baseline_valid && I_baseline != 0 &&
                       I_object_present && I_area >= 20'd2048 &&
                       I_live_black_count >= 20'd2048 &&
                       I_shape_valid && I_union != 0) begin
                        mismatch_hold<=I_mismatch;
                        union_hold<=I_union;
                        shape_ok_hold<=I_shape_ok;
                        area_ok_hold<=area_in_range;
                        dividend<=area_error*400;
                        divisor<=I_baseline;
                        quotient<=0; quotient_overflow<=0;
                        remainder<=0; bit_count<=0;
                        O_valid<=0; O_grade<=GRADE_WAIT;
                        O_update_toggle<=~O_update_toggle;
                        state<=DIV_ROI;
                    end else begin
                        O_valid<=0; O_grade<=GRADE_WAIT;
                        O_update_toggle<=~O_update_toggle;
                    end
                end
                DIV_ROI, DIV_SHAPE, DIV_ABS, DIV_WEIGHT: begin
                    dividend<={dividend[27:0],1'b0};
                    quotient<=next_quotient;
                    quotient_overflow<=next_overflow;
                    remainder<=next_remainder[20:0];
                    bit_count<=bit_count+1'b1;
                    if(bit_count==28) begin
                        bit_count<=0; quotient<=0; quotient_overflow<=0;
                        remainder<=0;
                        if(state==DIV_ROI) begin
                            roi_score<=minus_penalty(
                                next_overflow ? 32'd256:{24'd0,next_quotient});
                            dividend<=mismatch_hold*100;
                            divisor<={9'd0,union_hold};
                            state<=DIV_SHAPE;
                        end else if(state==DIV_SHAPE) begin
                            relative_penalty<=next_overflow ? 8'd255:
                                              next_quotient;
                            dividend<=mismatch_hold*50;
                            divisor<=20'd320;
                            state<=DIV_ABS;
                        end else if(state==DIV_ABS) begin
                            shape_score<=minus_penalty(
                                (next_overflow ||
                                 next_quotient>relative_penalty) ?
                                (next_overflow ? 32'd256:
                                 {24'd0,next_quotient}) :
                                {24'd0,relative_penalty});
                            state<=LOAD_WEIGHT;
                        end else begin
                            raw_score<=(next_overflow ||
                                        next_quotient>100) ? 7'd100:
                                       next_quotient[6:0];
                            state<=PUBLISH;
                        end
                    end
                end
                LOAD_WEIGHT: begin
                    dividend<={15'd0,weighted_score};
                    divisor<=weight_divisor;
                    quotient<=0; quotient_overflow<=0;
                    remainder<=0; bit_count<=0;
                    state<=DIV_WEIGHT;
                end
                // Publish and count once per accepted workpiece; keep the
                // result latched until the near-empty ROI re-arms inspection.
                PUBLISH: begin
                    O_valid<=1;
                    O_score<=limited_score;
                    S_empty_frames<=0;
                    O_grade<=area_ok_hold && shape_ok_hold ?
                             GRADE_PASS : GRADE_FAIL;
                    S_latched<=1;
                    if(area_ok_hold && shape_ok_hold)
                        O_pass_count_bcd<=next_bcd(O_pass_count_bcd);
                    else
                        O_fail_count_bcd<=next_bcd(O_fail_count_bcd);
                    O_update_toggle<=~O_update_toggle;
                    state<=IDLE;
                end
                default: state<=IDLE;
            endcase
            end
        end
    end
endmodule
