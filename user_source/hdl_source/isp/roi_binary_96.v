// Fixed-ROI binary image branch for the AWB RGB888 stream.
// One 96-bit beat contains four RGB888 pixels. The bus order used by AWB is
// [95:72]=x+3, [71:48]=x+2, [47:24]=x+1, and [23:0]=x.
module roi_binary_96 #(
    parameter integer IMG_WIDTH          = 1280,
    parameter integer IMG_HEIGHT         = 720,
    parameter integer ROI_X_START        = 160,
    parameter integer ROI_X_END          = 1120,
    parameter integer ROI_Y_START        = 90,
    parameter integer ROI_Y_END          = 630,
    parameter integer BINARY_THRESHOLD   = 128
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_tlast,
    input  wire        I_tuser,
    input  wire [95:0] I_tdata,
    input  wire        I_tvalid,
    output reg         O_tlast,
    output reg         O_tuser,
    output reg [95:0]  O_tdata,
    output reg         O_tvalid
);

    localparam integer GROUPS_PER_LINE = (IMG_WIDTH >> 2);

    reg [8:0]  S_x_group;
    reg [10:0] S_y_pos;

    reg [7:0]  S_gray_x3;
    reg [7:0]  S_gray_x2;
    reg [7:0]  S_gray_x1;
    reg [7:0]  S_gray_x0;
    reg [11:0] S_x_base_d1;
    reg [10:0] S_y_pos_d1;
    reg        S_valid_d1;
    reg        S_tuser_d1;
    reg        S_tlast_d1;

    wire [23:0] S_pix_x3 = I_tdata[95:72];
    wire [23:0] S_pix_x2 = I_tdata[71:48];
    wire [23:0] S_pix_x1 = I_tdata[47:24];
    wire [23:0] S_pix_x0 = I_tdata[23:0];

    // R/4 + G/2 + B/4, matching the existing low-cost Sobel luminance.
    wire [8:0] S_gray_sum_x3 = {3'b000,S_pix_x3[23:18]} +
                               {2'b00,S_pix_x3[15:9]} +
                               {3'b000,S_pix_x3[7:2]};
    wire [8:0] S_gray_sum_x2 = {3'b000,S_pix_x2[23:18]} +
                               {2'b00,S_pix_x2[15:9]} +
                               {3'b000,S_pix_x2[7:2]};
    wire [8:0] S_gray_sum_x1 = {3'b000,S_pix_x1[23:18]} +
                               {2'b00,S_pix_x1[15:9]} +
                               {3'b000,S_pix_x1[7:2]};
    wire [8:0] S_gray_sum_x0 = {3'b000,S_pix_x0[23:18]} +
                               {2'b00,S_pix_x0[15:9]} +
                               {3'b000,S_pix_x0[7:2]};

    wire [11:0] S_input_x_base = I_tuser ? 12'd0 : {1'b0,S_x_group,2'b00};
    wire [10:0] S_input_y_pos  = I_tuser ? 11'd0 : S_y_pos;

    function [23:0] F_binary_pixel;
        input [7:0]  I_gray;
        input [11:0] I_x;
        input [10:0] I_y;
        begin
            if ((I_x >= ROI_X_START) && (I_x < ROI_X_END) &&
                (I_y >= ROI_Y_START) && (I_y < ROI_Y_END)) begin
                F_binary_pixel = (I_gray >= BINARY_THRESHOLD) ?
                                 24'hffffff : 24'h000000;
            end
            else begin
                F_binary_pixel = 24'h000000;
            end
        end
    endfunction

    wire [23:0] S_binary_x3 = F_binary_pixel(
        S_gray_x3, S_x_base_d1 + 12'd3, S_y_pos_d1);
    wire [23:0] S_binary_x2 = F_binary_pixel(
        S_gray_x2, S_x_base_d1 + 12'd2, S_y_pos_d1);
    wire [23:0] S_binary_x1 = F_binary_pixel(
        S_gray_x1, S_x_base_d1 + 12'd1, S_y_pos_d1);
    wire [23:0] S_binary_x0 = F_binary_pixel(
        S_gray_x0, S_x_base_d1, S_y_pos_d1);

    // Stage 1: register luminance and the coordinates belonging to this
    // four-pixel beat. Fixed geometry gives a reliable line marker even
    // though the existing AWB block emits tlast during a valid gap.
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_x_group    <= 9'd0;
            S_y_pos      <= 11'd0;
            S_gray_x3    <= 8'd0;
            S_gray_x2    <= 8'd0;
            S_gray_x1    <= 8'd0;
            S_gray_x0    <= 8'd0;
            S_x_base_d1  <= 12'd0;
            S_y_pos_d1   <= 11'd0;
            S_valid_d1   <= 1'b0;
            S_tuser_d1   <= 1'b0;
            S_tlast_d1   <= 1'b0;
        end
        else begin
            S_valid_d1 <= I_tvalid;
            S_tuser_d1 <= I_tuser;
            S_tlast_d1 <= I_tvalid &&
                          ((I_tuser && (GROUPS_PER_LINE == 1)) ||
                           (!I_tuser && (S_x_group == GROUPS_PER_LINE - 1)));

            if(I_tvalid) begin
                S_gray_x3   <= S_gray_sum_x3[7:0];
                S_gray_x2   <= S_gray_sum_x2[7:0];
                S_gray_x1   <= S_gray_sum_x1[7:0];
                S_gray_x0   <= S_gray_sum_x0[7:0];
                S_x_base_d1 <= S_input_x_base;
                S_y_pos_d1  <= S_input_y_pos;
            end

            if(I_tuser) begin
                S_y_pos <= 11'd0;
                if(I_tvalid) begin
                    if(GROUPS_PER_LINE == 1)
                        S_x_group <= 9'd0;
                    else
                        S_x_group <= 9'd1;
                end
                else begin
                    S_x_group <= 9'd0;
                end
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

    // Stage 2: threshold and register the output stream. All stream markers
    // have the same latency as the image data.
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_tlast  <= 1'b0;
            O_tuser  <= 1'b0;
            O_tdata  <= 96'd0;
            O_tvalid <= 1'b0;
        end
        else begin
            O_tlast  <= S_tlast_d1;
            O_tuser  <= S_tuser_d1;
            O_tvalid <= S_valid_d1;
            if(S_valid_d1)
                O_tdata <= {S_binary_x3,S_binary_x2,S_binary_x1,S_binary_x0};
            else
                O_tdata <= 96'd0;
        end
    end

endmodule
