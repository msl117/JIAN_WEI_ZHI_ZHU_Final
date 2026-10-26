// Moments of the same 240x135 samples used by the shape frame store.
// Three stages isolate ROI decode, 8-bit products and frame accumulators.
module roi_moment_stats #(
    parameter integer IMG_WIDTH=1280, IMG_HEIGHT=720,
    parameter integer ROI_X_START=160, ROI_X_END=1120,
    parameter integer ROI_Y_START=90, ROI_Y_END=630
)(
    input wire I_clk,I_rst_n,I_tuser,I_tvalid,
    input wire [95:0] I_tdata,
    output reg O_valid,
    output reg [19:0] O_m00,
    output reg [28:0] O_m10,O_m01,
    output reg [39:0] O_m20,
    output reg [38:0] O_m02,
    output reg [39:0] O_m11,
    output reg [9:0] O_min_x,O_max_x,O_min_y,O_max_y
);
    reg [8:0] S_x;
    reg [10:0] S_y;
    wire [8:0] x=I_tuser ? 9'd0 : S_x;
    wire [10:0] y=I_tuser ? 11'd0 : S_y;
    wire [8:0] lx=x-ROI_X_START/4;
    wire [10:0] ly=y-ROI_Y_START;
    reg hit1,hit2,sof1,sof2,eof1,eof2;
    reg [7:0] x1,y1,x2,y2;
    reg [15:0] xx2,yy2,xy2;
    reg [15:0] n;
    reg [22:0] sx,sy;
    reg [30:0] sxx,syy,sxy;
    reg [7:0] xmin,xmax,ymin,ymax;
    reg seen, publish;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_x<=0; S_y<=0;
            hit1<=0; hit2<=0; sof1<=0; sof2<=0; eof1<=0; eof2<=0;
            x1<=0; y1<=0; x2<=0; y2<=0; xx2<=0; yy2<=0; xy2<=0;
            n<=0; sx<=0; sy<=0; sxx<=0; syy<=0; sxy<=0;
            xmin<=0; xmax<=0; ymin<=0; ymax<=0; seen<=0; publish<=0;
            O_valid<=0; O_m00<=0; O_m10<=0; O_m01<=0;
            O_m20<=0; O_m02<=0; O_m11<=0;
            O_min_x<=0; O_max_x<=0; O_min_y<=0; O_max_y<=0;
        end else begin
            if(I_tuser) begin S_x<=0; S_y<=0; end
            if(I_tvalid) begin
                if(x==IMG_WIDTH/4-1) begin
                    S_x<=0; S_y<=(y==IMG_HEIGHT-1) ? 0 : y+1'b1;
                end else begin S_x<=x+1'b1; S_y<=y; end
            end
            hit1<=I_tvalid && x>=ROI_X_START/4 && x<ROI_X_END/4 &&
                  y>=ROI_Y_START && y<ROI_Y_END && ly[1:0]==2 &&
                  I_tdata[71:48]==24'h000000;
            x1<=lx[7:0]; y1<=ly[9:2];
            sof1<=I_tuser;
            eof1<=I_tvalid && x==IMG_WIDTH/4-1 && y==IMG_HEIGHT-1;
            hit2<=hit1; sof2<=sof1; eof2<=eof1;
            x2<=x1; y2<=y1;
            xx2<=x1*x1; yy2<=y1*y1; xy2<=x1*y1;
            if(sof2) begin
                n<=hit2; sx<=hit2 ? x2:0; sy<=hit2 ? y2:0;
                sxx<=hit2 ? xx2:0; syy<=hit2 ? yy2:0; sxy<=hit2 ? xy2:0;
                seen<=hit2; xmin<=x2; xmax<=x2; ymin<=y2; ymax<=y2;
            end else if(hit2) begin
                n<=n+1'b1; sx<=sx+x2; sy<=sy+y2;
                sxx<=sxx+xx2; syy<=syy+yy2; sxy<=sxy+xy2;
                seen<=1;
                if(!seen || x2<xmin) xmin<=x2;
                if(!seen || x2>xmax) xmax<=x2;
                if(!seen || y2<ymin) ymin<=y2;
                if(!seen || y2>ymax) ymax<=y2;
            end
            // Publish one cycle after the last accumulation, including its pixel.
            publish<=eof2;
            O_valid<=publish;
            if(publish) begin
                O_m00<=n; O_m10<=sx; O_m01<=sy;
                O_m20<=sxx; O_m02<=syy; O_m11<=sxy;
                O_min_x<=seen ? xmin:0; O_max_x<=seen ? xmax:0;
                O_min_y<=seen ? ymin:0; O_max_y<=seen ? ymax:0;
            end
        end
    end
endmodule
