// Publish only completed frame results. Starting another calculation must
// not clear SCORE or expose a transient WAIT to the display clock domain.
// Codes: 0 AXIS BAD, 1 MATCH, 2 SHAPE NG, 3 WAIT (no learned template).
module shape_match_fusion (
    input wire I_clk,I_rst_n,I_axis_update,I_axis_valid,
    input wire [8:0] I_angle_bin,
    input wire I_match_update,I_match_valid,I_match_ok,
    input wire [10:0] I_match_score,
    output reg O_update_toggle,O_valid,
    output reg [1:0] O_result_code,
    output reg [10:0] O_score,
    output reg [8:0] O_angle_bin
);
    reg [8:0] pending_angle;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            pending_angle<=0; O_update_toggle<=0; O_valid<=0;
            O_result_code<=3; O_score<=0; O_angle_bin<=0;
        end else begin
            if(I_axis_update) begin
                pending_angle<=I_angle_bin;
                if(!I_axis_valid) begin
                    O_valid<=1; O_result_code<=0; O_score<=0;
                    O_angle_bin<=I_angle_bin; O_update_toggle<=~O_update_toggle;
                end
            end
            if(I_match_update) begin
                O_valid<=1;
                O_score<=I_match_score;
                O_angle_bin<=pending_angle;
                O_result_code<=!I_match_valid ? 2'd3:I_match_ok ? 2'd1:2'd2;
                O_update_toggle<=~O_update_toggle;
            end
        end
    end
endmodule
