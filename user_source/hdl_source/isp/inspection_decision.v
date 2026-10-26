// Frame-level object presence decision for a dark object on a light background.
// A candidate must satisfy the pixel-count and bounding-box limits. The
// published result changes only after three consecutive equal candidates.
module inspection_decision #(
    parameter integer OBJECT_MIN_BLACK_PIXELS = 2048,
    parameter integer OBJECT_MAX_BLACK_PIXELS = 518400,
    parameter integer BBOX_MIN_WIDTH          = 64,
    parameter integer BBOX_MIN_HEIGHT         = 64,
    parameter integer STABLE_FRAMES           = 3
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_feature_valid,
    input  wire [19:0] I_black_count,
    input  wire [10:0] I_min_x,
    input  wire [10:0] I_max_x,
    input  wire [10:0] I_min_y,
    input  wire [10:0] I_max_y,

    output reg         O_object_present,
    output reg         O_result_update_toggle
);

    reg        S_last_candidate;
    reg [2:0]  S_same_count;
    wire [11:0] S_bbox_width  = {1'b0,I_max_x} - {1'b0,I_min_x} + 12'd1;
    wire [11:0] S_bbox_height = {1'b0,I_max_y} - {1'b0,I_min_y} + 12'd1;

    wire S_candidate = (I_black_count >= OBJECT_MIN_BLACK_PIXELS) &&
                       (I_black_count <= OBJECT_MAX_BLACK_PIXELS) &&
                       (S_bbox_width >= BBOX_MIN_WIDTH) &&
                       (S_bbox_height >= BBOX_MIN_HEIGHT) &&
                       (I_black_count != 20'd0);

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_last_candidate       <= 1'b0;
            S_same_count           <= 3'd0;
            O_object_present       <= 1'b0;
            O_result_update_toggle <= 1'b0;
        end
        else if(I_feature_valid) begin
            if(S_candidate == S_last_candidate) begin
                if(S_same_count < STABLE_FRAMES)
                    S_same_count <= S_same_count + 3'd1;

                // The third equal frame publishes the new stable result.
                if((S_same_count >= STABLE_FRAMES - 1) &&
                   (S_same_count < STABLE_FRAMES)) begin
                    O_object_present       <= S_candidate;
                    O_result_update_toggle <= ~O_result_update_toggle;
                end
            end
            else begin
                S_last_candidate <= S_candidate;
                S_same_count     <= 3'd1;
            end
        end
    end

endmodule
