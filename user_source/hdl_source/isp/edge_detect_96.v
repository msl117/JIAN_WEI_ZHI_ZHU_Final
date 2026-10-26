module edge_detect_96 #(
    parameter IMG_WIDTH  = 1280,
    parameter IMG_HEIGHT = 720,
    parameter EDGE_TH    = 11'd80
)(
    input               I_clk,
    input               I_rst_n,
    input               I_tlast,
    input               I_tuser,
    input      [95:0]   I_tdata,
    input               I_tvalid,
    input               I_tready,
    output reg          O_tlast,
    output reg          O_tuser,
    output reg [95:0]   O_tdata,
    output reg          O_tvalid,
    output              O_tready,
    output reg [95:0]   O_gray_data
);

assign O_tready = I_tready;

wire [23:0] pix0 = I_tdata[95:72];
wire [23:0] pix1 = I_tdata[71:48];
wire [23:0] pix2 = I_tdata[47:24];
wire [23:0] pix3 = I_tdata[23:0];

// Low-cost luminance approximation: R/4 + G/2 + B/4.  Its maximum is
// 253, so it cannot overflow an 8-bit result and requires no divider.
wire [7:0] gray0 = {2'b0,pix0[23:18]} + {1'b0,pix0[15:9]} + {2'b0,pix0[7:2]};
wire [7:0] gray1 = {2'b0,pix1[23:18]} + {1'b0,pix1[15:9]} + {2'b0,pix1[7:2]};
wire [7:0] gray2 = {2'b0,pix2[23:18]} + {1'b0,pix2[15:9]} + {2'b0,pix2[7:2]};
wire [7:0] gray3 = {2'b0,pix3[23:18]} + {1'b0,pix3[15:9]} + {2'b0,pix3[7:2]};

localparam IMG_WIDTH_GRP = (IMG_WIDTH >> 2);

// Use two grayscale samples per 4-pixel input beat.  Each sample represents
// a neighbouring pair of pixels, providing 640 horizontal edge samples while
// keeping the two line buffers small enough for this device.
wire [8:0] pair_sum0 = {1'b0,gray0} + {1'b0,gray1};
wire [8:0] pair_sum1 = {1'b0,gray2} + {1'b0,gray3};
wire [7:0] pair0 = pair_sum0[8:1];
wire [7:0] pair1 = pair_sum1[8:1];

(* ram_style = "block" *) reg [15:0] line1_mem [0:IMG_WIDTH_GRP-1];
(* ram_style = "block" *) reg [15:0] line2_mem [0:IMG_WIDTH_GRP-1];

reg [10:0] x_grp;
reg [10:0] y_pos;

wire [15:0] top_word = line2_mem[x_grp];
wire [15:0] mid_word = line1_mem[x_grp];
wire [15:0] bot_word = {pair0,pair1};

wire [7:0] top0 = top_word[15:8];
wire [7:0] top1 = top_word[7:0];
wire [7:0] mid0 = mid_word[15:8];
wire [7:0] mid1 = mid_word[7:0];

reg [7:0] top_prev2, top_prev1;
reg [7:0] mid_prev2, mid_prev1;
reg [7:0] bot_prev2, bot_prev1;

// Balance the positive/negative Sobel sums and register each arithmetic
// stage. Pixel values are bit-exact with the original function; markers and
// grayscale are delayed by the same two additional cycles.
reg [9:0] sx_pos0,sx_neg0,sy_pos0,sy_neg0;
reg [9:0] sx_pos1,sx_neg1,sy_pos1,sy_neg1;
reg [9:0] ax0,ay0,ax1,ay1;
reg [95:0] gray_d1,gray_d2;
reg [1:0] valid_d,user_d,last_d,window_d;
wire [10:0] magnitude0={1'b0,ax0}+{1'b0,ay0};
wire [10:0] magnitude1={1'b0,ax1}+{1'b0,ay1};
wire edge0=window_d[1] && magnitude0>=EDGE_TH;
wire edge1=window_d[1] && magnitude1>=EDGE_TH;
wire window_valid=(y_pos>=11'd2) && (x_grp!=11'd0) && !I_tuser;

always @(posedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        sx_pos0<=0; sx_neg0<=0; sy_pos0<=0; sy_neg0<=0;
        sx_pos1<=0; sx_neg1<=0; sy_pos1<=0; sy_neg1<=0;
        ax0<=0; ay0<=0; ax1<=0; ay1<=0;
        gray_d1<=0; gray_d2<=0;
        valid_d<=0; user_d<=0; last_d<=0; window_d<=0;
        O_tdata<=0; O_gray_data<=0; O_tvalid<=0; O_tuser<=0; O_tlast<=0;
    end else begin
        sx_pos0<=({2'b0,top0}+{2'b0,pair0})+{1'b0,mid0,1'b0};
        sx_neg0<=({2'b0,top_prev2}+{2'b0,bot_prev2})+{1'b0,mid_prev2,1'b0};
        sy_pos0<=({2'b0,top_prev2}+{2'b0,top0})+{1'b0,top_prev1,1'b0};
        sy_neg0<=({2'b0,bot_prev2}+{2'b0,pair0})+{1'b0,bot_prev1,1'b0};
        sx_pos1<=({2'b0,top1}+{2'b0,pair1})+{1'b0,mid1,1'b0};
        sx_neg1<=({2'b0,top_prev1}+{2'b0,bot_prev1})+{1'b0,mid_prev1,1'b0};
        sy_pos1<=({2'b0,top_prev1}+{2'b0,top1})+{1'b0,top0,1'b0};
        sy_neg1<=({2'b0,bot_prev1}+{2'b0,pair1})+{1'b0,pair0,1'b0};
        ax0<=sx_pos0>=sx_neg0 ? sx_pos0-sx_neg0:sx_neg0-sx_pos0;
        ay0<=sy_pos0>=sy_neg0 ? sy_pos0-sy_neg0:sy_neg0-sy_pos0;
        ax1<=sx_pos1>=sx_neg1 ? sx_pos1-sx_neg1:sx_neg1-sx_pos1;
        ay1<=sy_pos1>=sy_neg1 ? sy_pos1-sy_neg1:sy_neg1-sy_pos1;
        gray_d1<={gray3,gray3,gray3,gray2,gray2,gray2,
                  gray1,gray1,gray1,gray0,gray0,gray0};
        gray_d2<=gray_d1;
        valid_d<={valid_d[0],I_tvalid};
        user_d<={user_d[0],I_tuser};
        last_d<={last_d[0],I_tlast};
        window_d<={window_d[0],window_valid};
        O_tvalid<=valid_d[1]; O_tuser<=user_d[1]; O_tlast<=last_d[1];
        O_tdata<=valid_d[1] ? {{48{edge0}},{48{edge1}}}:96'd0;
        O_gray_data<=valid_d[1] ? gray_d2:96'd0;
    end
end

always @(posedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
        x_grp    <= 11'd0;
        y_pos    <= 11'd0;
        top_prev2 <= 8'd0; top_prev1 <= 8'd0;
        mid_prev2 <= 8'd0; mid_prev1 <= 8'd0;
        bot_prev2 <= 8'd0; bot_prev1 <= 8'd0;
        // Do not clear line memories here.  A reset loop turns the 10-Kbit
        // buffers into slice registers on this device.  The first two rows
        // are masked by window_valid and naturally initialize both buffers.
    end else begin
        if(I_tvalid) begin
            line2_mem[x_grp] <= mid_word;
            line1_mem[x_grp] <= bot_word;

            top_prev2 <= top0; top_prev1 <= top1;
            mid_prev2 <= mid0; mid_prev1 <= mid1;
            bot_prev2 <= pair0; bot_prev1 <= pair1;

            if(I_tuser) begin
                x_grp <= 11'd1;
                y_pos <= 11'd0;
            end else if(x_grp == IMG_WIDTH_GRP - 1) begin
                x_grp <= 11'd0;
                if(y_pos == IMG_HEIGHT - 1)
                    y_pos <= 11'd0;
                else
                    y_pos <= y_pos + 1'b1;
                top_prev2 <= 8'd0; top_prev1 <= 8'd0;
                mid_prev2 <= 8'd0; mid_prev1 <= 8'd0;
                bot_prev2 <= 8'd0; bot_prev1 <= 8'd0;
            end else begin
                x_grp <= x_grp + 1'b1;
            end
        end
    end
end

endmodule
