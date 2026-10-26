// Serial inverse mapper. Each arithmetic stage has its own clock cycle.
// Coordinates and extent are in shape-buffer cells (one cell = 4x4 pixels).
module roi_rotate_normalize #(
    parameter integer TEMPLATE_SIZE=32
)(
    input wire I_clk,I_rst_n,I_start,I_axis_valid,
    input wire [8:0] I_angle_bin,
    input wire [9:0] I_cx,I_cy,I_min_x,I_max_x,I_min_y,I_max_y,
    input wire [9:0] I_extent,
    input wire signed [15:0] I_cos,I_sin,
    input wire I_source_pixel,
    output reg O_source_req,
    output reg [9:0] O_source_x,O_source_y,
    output reg O_valid,
    output reg [4:0] O_dst_x,O_dst_y,
    output reg O_pixel,O_done
);
    localparam IDLE=0,OFFSET=1,SCALE=2,MULT=3,ROTATE=4,
               CENTRE=5,REQUEST=6,WAIT_RAM=7,SAMPLE=8;
    reg [3:0] state;
    reg [4:0] x,y;
    reg [9:0] cx,cy,xmin,xmax,ymin,ymax,extent;
    reg signed [15:0] cosine,sine;
    reg signed [6:0] dx,dy;
    reg signed [17:0] u,v;
    reg signed [33:0] uc,us,vc,vs;
    reg signed [34:0] rot_x,rot_y;
    reg signed [13:0] src_x,src_y;
    reg in_bounds;
    wire bounds=src_x>=0 && src_y>=0 && src_x<240 && src_y<135 &&
                src_x>=$signed({4'b0,xmin}) && src_x<=$signed({4'b0,xmax}) &&
                src_y>=$signed({4'b0,ymin}) && src_y<=$signed({4'b0,ymax});
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            state<=IDLE; x<=0; y<=0; cx<=0; cy<=0;
            xmin<=0; xmax<=0; ymin<=0; ymax<=0; extent<=0;
            cosine<=0; sine<=0; dx<=0; dy<=0; u<=0; v<=0;
            uc<=0; us<=0; vc<=0; vs<=0; rot_x<=0; rot_y<=0;
            src_x<=0; src_y<=0; in_bounds<=0;
            O_source_req<=0; O_source_x<=0; O_source_y<=0;
            O_valid<=0; O_dst_x<=0; O_dst_y<=0; O_pixel<=0; O_done<=0;
        end else begin
            O_source_req<=0; O_valid<=0; O_done<=0;
            case(state)
                IDLE:if(I_start) begin
                    x<=0; y<=0; cx<=I_cx; cy<=I_cy;
                    xmin<=I_min_x; xmax<=I_max_x; ymin<=I_min_y; ymax<=I_max_y;
                    extent<=I_extent; cosine<=I_cos; sine<=I_sin;
                    if(I_axis_valid && I_min_x<=I_max_x && I_min_y<=I_max_y)
                        state<=OFFSET;
                    else O_done<=1;
                end
                OFFSET:begin
                    dx<=$signed({1'b0,x,1'b0})-7'sd31;
                    dy<=$signed({1'b0,y,1'b0})-7'sd31;
                    state<=SCALE;
                end
                SCALE:begin
                    u<=dx*$signed({1'b0,extent});
                    v<=dy*$signed({1'b0,extent});
                    state<=MULT;
                end
                MULT:begin
                    uc<=u*cosine; us<=u*sine;
                    vc<=v*cosine; vs<=v*sine;
                    state<=ROTATE;
                end
                ROTATE:begin
                    rot_x<=$signed({uc[33],uc})-$signed({vs[33],vs});
                    rot_y<=$signed({us[33],us})+$signed({vc[33],vc});
                    state<=CENTRE;
                end
                CENTRE:begin
                    // extent/64 times Q14 rotation; nearest-neighbour sampling.
                    src_x<=$signed({4'b0,cx})+((rot_x+35'sd524288)>>>20);
                    src_y<=$signed({4'b0,cy})+((rot_y+35'sd524288)>>>20);
                    state<=REQUEST;
                end
                REQUEST:begin
                    O_source_x<=bounds ? src_x[9:0]:0;
                    O_source_y<=bounds ? src_y[9:0]:0;
                    O_source_req<=bounds; in_bounds<=bounds; state<=WAIT_RAM;
                end
                WAIT_RAM:state<=SAMPLE;
                SAMPLE:begin
                    O_valid<=1; O_dst_x<=x; O_dst_y<=y;
                    O_pixel<=in_bounds ? I_source_pixel:0;
                    if(x==TEMPLATE_SIZE-1 && y==TEMPLATE_SIZE-1) begin
                        O_done<=1; state<=IDLE;
                    end else begin
                        if(x==TEMPLATE_SIZE-1) begin x<=0; y<=y+1'b1; end
                        else x<=x+1'b1;
                        state<=OFFSET;
                    end
                end
                default:state<=IDLE;
            endcase
        end
    end
endmodule
