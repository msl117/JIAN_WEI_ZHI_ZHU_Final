// Relative black-pixel comparison in the 24 MHz control clock domain.
// C7 captures the current frame count as the new workpiece baseline.
module inspection_baseline_ctrl #(
    parameter integer BASELINE_TOL_PCT = 10,
    parameter integer MIN_BASELINE_COUNT = 1
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_calibrate_pulse,
    input  wire        I_feature_valid,
    input  wire [19:0] I_black_count,
    input  wire        I_object_present,

    output reg [1:0]   O_result_code,
    output reg         O_baseline_valid,
    output reg [19:0]  O_baseline_count,
    output reg [19:0]  O_black_count,
    output reg [23:0]  O_black_count_bcd,
    output reg         O_update_toggle
);

    localparam [1:0] RESULT_WAIT = 2'd0;
    localparam [1:0] RESULT_OK   = 2'd1;
    localparam [1:0] RESULT_NG   = 2'd2;

    wire [31:0] S_margin_product = O_baseline_count * BASELINE_TOL_PCT;
    wire [31:0] S_margin_count   = S_margin_product / 100;
    wire [20:0] S_lower_bound = (O_baseline_count > S_margin_count) ?
                                 ({1'b0,O_baseline_count} - S_margin_count) : 21'd0;
    wire [21:0] S_upper_bound = {2'd0,O_baseline_count} + S_margin_count;
    wire S_count_in_range = O_baseline_valid &&
                            ({1'b0,I_black_count} >= S_lower_bound) &&
                            ((S_upper_bound > 22'd1048575) ||
                             ({2'd0,I_black_count} <= S_upper_bound));

    function [23:0] F_bin_to_bcd;
        input [19:0] I_binary;
        integer i;
        reg [43:0] S_shift;
        begin
            S_shift = 44'd0;
            S_shift[19:0] = I_binary;
            for(i = 0; i < 20; i = i + 1) begin
                if(S_shift[23:20] >= 5) S_shift[23:20] = S_shift[23:20] + 3;
                if(S_shift[27:24] >= 5) S_shift[27:24] = S_shift[27:24] + 3;
                if(S_shift[31:28] >= 5) S_shift[31:28] = S_shift[31:28] + 3;
                if(S_shift[35:32] >= 5) S_shift[35:32] = S_shift[35:32] + 3;
                if(S_shift[39:36] >= 5) S_shift[39:36] = S_shift[39:36] + 3;
                if(S_shift[43:40] >= 5) S_shift[43:40] = S_shift[43:40] + 3;
                S_shift = S_shift << 1;
            end
            F_bin_to_bcd = S_shift[43:20];
        end
    endfunction

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_result_code     <= RESULT_WAIT;
            O_baseline_valid  <= 1'b0;
            O_baseline_count  <= 20'd0;
            O_black_count     <= 20'd0;
            O_black_count_bcd <= 24'd0;
            O_update_toggle   <= 1'b0;
        end
        else begin
            if(I_calibrate_pulse && I_object_present &&
               (I_black_count >= MIN_BASELINE_COUNT)) begin
                O_baseline_count <= I_black_count;
                O_baseline_valid <= 1'b1;
                O_result_code    <= RESULT_WAIT;
            end
            else if(I_feature_valid) begin
                O_black_count     <= I_black_count;
                O_black_count_bcd <= F_bin_to_bcd(I_black_count);
                if(!O_baseline_valid)
                    O_result_code <= RESULT_WAIT;
                else if(I_object_present && S_count_in_range)
                    O_result_code <= RESULT_OK;
                else
                    O_result_code <= RESULT_NG;
            end

            if((I_calibrate_pulse && I_object_present &&
                (I_black_count >= MIN_BASELINE_COUNT)) || I_feature_valid)
                O_update_toggle <= ~O_update_toggle;
        end
    end

endmodule
