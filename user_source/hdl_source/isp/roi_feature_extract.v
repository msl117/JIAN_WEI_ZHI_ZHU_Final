// Feature extraction for the fixed ROI binary stream.
// The current inspection polarity is dark object on a light background:
// black pixels inside the ROI are counted and used for the bounding box.
// One input beat contains four RGB888 binary pixels in x, x+1, x+2, x+3
// order at bit slices [23:0], [47:24], [71:48], and [95:72].
module roi_feature_extract #(
    parameter integer IMG_WIDTH     = 1280,
    parameter integer IMG_HEIGHT    = 720,
    parameter integer ROI_X_START   = 160,
    parameter integer ROI_X_END     = 1120,
    parameter integer ROI_Y_START   = 90,
    parameter integer ROI_Y_END     = 630,
    parameter integer BORDER_WIDTH  = 24
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_tuser,
    input  wire        I_tvalid,
    input  wire [95:0] I_tdata,

    output reg         O_feature_valid,
    output reg [19:0]  O_black_count,
    output reg [10:0]  O_min_x,
    output reg [10:0]  O_max_x,
    output reg [10:0]  O_min_y,
    output reg [10:0]  O_max_y,
    output reg [7:0]   O_border_count
);

    localparam integer GROUPS_PER_LINE = (IMG_WIDTH / 4);

    reg [8:0]  S_x_group;
    reg [10:0] S_y_pos;

    reg [19:0] S_black_count;
    reg [7:0]  S_border_count;
    reg        S_target_seen;
    reg [10:0] S_min_x;
    reg [10:0] S_max_x;
    reg [10:0] S_min_y;
    reg [10:0] S_max_y;

    wire [23:0] S_pixel_x0 = I_tdata[23:0];
    wire [23:0] S_pixel_x1 = I_tdata[47:24];
    wire [23:0] S_pixel_x2 = I_tdata[71:48];
    wire [23:0] S_pixel_x3 = I_tdata[95:72];

    // tuser may arrive one cycle before the first valid beat. The current
    // coordinate is therefore selected from tuser, while the state counters
    // are advanced only when valid data is actually consumed.
    wire [11:0] S_x_base = I_tuser ? 12'd0 : {1'b0,S_x_group,2'b00};
    wire [10:0] S_y_base = I_tuser ? 11'd0 : S_y_pos;
    wire [11:0] S_x0 = S_x_base;
    wire [11:0] S_x1 = S_x_base + 12'd1;
    wire [11:0] S_x2 = S_x_base + 12'd2;
    wire [11:0] S_x3 = S_x_base + 12'd3;

    wire S_hit_x0 = (S_x0 >= ROI_X_START) && (S_x0 < ROI_X_END) &&
                    (S_y_base >= ROI_Y_START) && (S_y_base < ROI_Y_END) &&
                    (S_pixel_x0 == 24'h000000);
    wire S_hit_x1 = (S_x1 >= ROI_X_START) && (S_x1 < ROI_X_END) &&
                    (S_y_base >= ROI_Y_START) && (S_y_base < ROI_Y_END) &&
                    (S_pixel_x1 == 24'h000000);
    wire S_hit_x2 = (S_x2 >= ROI_X_START) && (S_x2 < ROI_X_END) &&
                    (S_y_base >= ROI_Y_START) && (S_y_base < ROI_Y_END) &&
                    (S_pixel_x2 == 24'h000000);
    wire S_hit_x3 = (S_x3 >= ROI_X_START) && (S_x3 < ROI_X_END) &&
                    (S_y_base >= ROI_Y_START) && (S_y_base < ROI_Y_END) &&
                    (S_pixel_x3 == 24'h000000);

    wire S_frame_last = I_tvalid &&
                        (S_x_group == GROUPS_PER_LINE - 1) &&
                        (S_y_pos   == IMG_HEIGHT - 1);

    wire       S_any_hit = S_hit_x0 | S_hit_x1 | S_hit_x2 | S_hit_x3;
    wire [2:0] S_pair_hit_count_0 = {1'b0,S_hit_x0} + {1'b0,S_hit_x1};
    wire [2:0] S_pair_hit_count_1 = {1'b0,S_hit_x2} + {1'b0,S_hit_x3};
    wire [2:0] S_hit_count = S_pair_hit_count_0 + S_pair_hit_count_1;
    wire [2:0] S_border_hit_count =
        {2'd0,(S_hit_x0 && ((S_x0 < ROI_X_START+BORDER_WIDTH) ||
                            (S_x0 >= ROI_X_END-BORDER_WIDTH) ||
                            (S_y_base < ROI_Y_START+BORDER_WIDTH) ||
                            (S_y_base >= ROI_Y_END-BORDER_WIDTH)))} +
        {2'd0,(S_hit_x1 && ((S_x1 < ROI_X_START+BORDER_WIDTH) ||
                            (S_x1 >= ROI_X_END-BORDER_WIDTH) ||
                            (S_y_base < ROI_Y_START+BORDER_WIDTH) ||
                            (S_y_base >= ROI_Y_END-BORDER_WIDTH)))} +
        {2'd0,(S_hit_x2 && ((S_x2 < ROI_X_START+BORDER_WIDTH) ||
                            (S_x2 >= ROI_X_END-BORDER_WIDTH) ||
                            (S_y_base < ROI_Y_START+BORDER_WIDTH) ||
                            (S_y_base >= ROI_Y_END-BORDER_WIDTH)))} +
        {2'd0,(S_hit_x3 && ((S_x3 < ROI_X_START+BORDER_WIDTH) ||
                            (S_x3 >= ROI_X_END-BORDER_WIDTH) ||
                            (S_y_base < ROI_Y_START+BORDER_WIDTH) ||
                            (S_y_base >= ROI_Y_END-BORDER_WIDTH)))};
    wire [8:0] S_border_sum = {1'b0,S_border_count} +
                              {6'd0,S_border_hit_count};
    wire [10:0] S_beat_min_x = S_hit_x0 ? S_x0[10:0] :
                                S_hit_x1 ? S_x1[10:0] :
                                S_hit_x2 ? S_x2[10:0] : S_x3[10:0];
    wire [10:0] S_beat_max_x = S_hit_x3 ? S_x3[10:0] :
                                S_hit_x2 ? S_x2[10:0] :
                                S_hit_x1 ? S_x1[10:0] : S_x0[10:0];

    reg [20:0] S_calc_black_count;
    reg        S_calc_target_seen;
    reg [10:0] S_calc_min_x;
    reg [10:0] S_calc_max_x;
    reg [10:0] S_calc_min_y;
    reg [10:0] S_calc_max_y;

    // Reduce the four pixels in a beat first, then update the frame state once.
    // This keeps the bounding-box path short and includes the final beat.
    always @(*) begin
        S_calc_black_count = {1'b0,S_black_count} + {18'd0,S_hit_count};
        S_calc_target_seen = S_target_seen | S_any_hit;
        S_calc_min_x = S_min_x;
        S_calc_max_x = S_max_x;
        S_calc_min_y = S_min_y;
        S_calc_max_y = S_max_y;

        if(S_any_hit) begin
            if(!S_target_seen) begin
                S_calc_min_x = S_beat_min_x;
                S_calc_max_x = S_beat_max_x;
                S_calc_min_y = S_y_base;
                S_calc_max_y = S_y_base;
            end
            else begin
                if(S_beat_min_x < S_min_x) S_calc_min_x = S_beat_min_x;
                if(S_beat_max_x > S_max_x) S_calc_max_x = S_beat_max_x;
                if(S_y_base < S_min_y) S_calc_min_y = S_y_base;
                if(S_y_base > S_max_y) S_calc_max_y = S_y_base;
            end
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_x_group       <= 9'd0;
            S_y_pos         <= 11'd0;
            S_black_count   <= 20'd0;
            S_border_count  <= 8'd0;
            S_target_seen   <= 1'b0;
            S_min_x         <= 11'd0;
            S_max_x         <= 11'd0;
            S_min_y         <= 11'd0;
            S_max_y         <= 11'd0;
            O_feature_valid <= 1'b0;
            O_black_count   <= 20'd0;
            O_min_x         <= 11'd0;
            O_max_x         <= 11'd0;
            O_min_y         <= 11'd0;
            O_max_y         <= 11'd0;
            O_border_count  <= 8'd0;
        end
        else begin
            O_feature_valid <= 1'b0;

            if(I_tvalid) begin
                S_black_count <= S_calc_black_count[19:0];
                S_border_count <= S_border_sum > 9'd255 ?
                                  8'd255 : S_border_sum[7:0];
                S_target_seen <= S_calc_target_seen;
                S_min_x       <= S_calc_min_x;
                S_max_x       <= S_calc_max_x;
                S_min_y       <= S_calc_min_y;
                S_max_y       <= S_calc_max_y;

                if(S_frame_last) begin
                    O_feature_valid <= 1'b1;
                    O_black_count   <= S_calc_black_count[19:0];
                    O_min_x         <= S_calc_min_x;
                    O_max_x         <= S_calc_max_x;
                    O_min_y         <= S_calc_min_y;
                    O_max_y         <= S_calc_max_y;
                    O_border_count  <= S_border_sum > 9'd255 ?
                                       8'd255 : S_border_sum[7:0];
                    S_black_count   <= 20'd0;
                    S_border_count  <= 8'd0;
                    S_target_seen   <= 1'b0;
                    S_min_x         <= 11'd0;
                    S_max_x         <= 11'd0;
                    S_min_y         <= 11'd0;
                    S_max_y         <= 11'd0;
                end
            end

            if(I_tuser) begin
                S_y_pos <= 11'd0;
                if(I_tvalid)
                    S_x_group <= (GROUPS_PER_LINE == 1) ? 9'd0 : 9'd1;
                else
                    S_x_group <= 9'd0;
            end
            else if(I_tvalid) begin
                if(S_x_group == GROUPS_PER_LINE - 1) begin
                    S_x_group <= 9'd0;
                    if(S_y_pos == IMG_HEIGHT - 1)
                        S_y_pos <= 11'd0;
                    else
                        S_y_pos <= S_y_pos + 11'd1;
                end
                else begin
                    S_x_group <= S_x_group + 9'd1;
                end
            end
        end
    end

endmodule
