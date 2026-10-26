// Frame-rate PCA engine for the 4x4-subsampled shape image.
// Products and divisions are serial; CORDIC uses 1/256-degree angles.
// The scale 4*sqrt(variance_x+variance_y) is invariant under rotation.
module roi_axis_calc (
    input wire I_clk,I_rst_n,I_valid,
    input wire [19:0] I_m00,
    input wire [28:0] I_m10,I_m01,
    input wire [39:0] I_m20,
    input wire [38:0] I_m02,
    input wire [39:0] I_m11,
    output reg O_valid,O_axis_valid,
    output reg O_accept,
    output reg [8:0] O_angle_bin,
    output reg [9:0] O_cx,O_cy,
    output reg [9:0] O_extent,
    output reg signed [15:0] O_cos,O_sin
);
    localparam IDLE=0,MUL_LOAD=1,MUL_LO=2,MUL_HI=3,MUL_SAVE=4,
        COV=5,DIFF=6,ABS=7,NORM=8,VEC_LOAD=9,VEC=10,ANGLE=11,
        ROT_LOAD=12,ROT=13,DIV_LOAD=14,DIV=15,DIV_SAVE=16,
        SQRT_LOAD=17,SQRT=18,PUBLISH=19;
    reg [4:0] state;
    reg [15:0] n;
    reg [22:0] mx,my;
    reg [30:0] mxx,myy,mxy;
    reg [2:0] prod_index;
    reg [47:0] products[0:5];
    reg [47:0] ma,acc;
    reg [22:0] mb;
    reg [24:0] low_sum;
    reg [4:0] count;
    reg [47:0] xx,yy;
    reg signed [48:0] xy,delta,cross_term;
    reg [48:0] trace_value,abs_delta,abs_cross;
    reg delta_neg,cross_neg;
    reg signed [24:0] vx,vy;
    reg signed [17:0] vz,theta;
    reg signed [17:0] rx,ry,rz;
    reg [3:0] iter;
    reg flip_cos;
    reg [1:0] div_index;
    reg [48:0] dividend,quotient;
    reg [16:0] remainder;
    reg [5:0] div_count;
    wire [16:0] trial={remainder[15:0],dividend[48]};
    wire take=trial>={1'b0,n};
    wire [16:0] next_rem=take ? trial-{1'b0,n}:trial;
    wire [48:0] next_q={quotient[47:0],take};
    reg [48:0] radial_sum;
    reg [19:0] radial_mean;
    reg [19:0] sqrt_bits;
    reg [21:0] sqrt_rem;
    reg [9:0] sqrt_root;
    wire [21:0] sqrt_trial={sqrt_rem[19:0],sqrt_bits[19:18]};
    wire [21:0] sqrt_sub={10'd0,sqrt_root,2'b01};
    wire sqrt_take=sqrt_trial>=sqrt_sub;
    integer k;
    function [17:0] atan_q8;
        input [3:0] i;
        begin
            case(i)
                0:atan_q8=11520; 1:atan_q8=6801; 2:atan_q8=3593;
                3:atan_q8=1824; 4:atan_q8=916; 5:atan_q8=458;
                6:atan_q8=229; 7:atan_q8=115; 8:atan_q8=57;
                9:atan_q8=29; 10:atan_q8=14; default:atan_q8=7;
            endcase
        end
    endfunction
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            state<=IDLE; n<=0; mx<=0; my<=0; mxx<=0; myy<=0; mxy<=0;
            prod_index<=0; ma<=0; mb<=0; acc<=0; low_sum<=0; count<=0;
            for(k=0;k<6;k=k+1) products[k]<=0;
            xx<=0; yy<=0; xy<=0; delta<=0; cross_term<=0;
            trace_value<=0; abs_delta<=0; abs_cross<=0;
            delta_neg<=0; cross_neg<=0; vx<=0; vy<=0; vz<=0; theta<=0;
            rx<=0; ry<=0; rz<=0; iter<=0; flip_cos<=0;
            div_index<=0; dividend<=0; quotient<=0; remainder<=0; div_count<=0;
            radial_sum<=0; radial_mean<=0;
            sqrt_bits<=0; sqrt_rem<=0; sqrt_root<=0;
            O_valid<=0; O_accept<=0; O_axis_valid<=0; O_angle_bin<=0;
            O_cx<=0; O_cy<=0; O_extent<=0; O_cos<=0; O_sin<=0;
        end else begin
            O_valid<=0;
            O_accept<=0;
            case(state)
                IDLE:if(I_valid) begin
                    O_accept<=1;
                    n<=I_m00[15:0]; mx<=I_m10[22:0]; my<=I_m01[22:0];
                    mxx<=I_m20[30:0]; myy<=I_m02[30:0]; mxy<=I_m11[30:0];
                    prod_index<=0; state<=MUL_LOAD;
                    if(I_m00<128) begin
                        O_axis_valid<=0; O_angle_bin<=0; O_valid<=1;
                        state<=IDLE;
                    end
                end
                MUL_LOAD:begin
                    case(prod_index)
                        0:begin ma<=mxx; mb<=n; end
                        1:begin ma<=mx; mb<=mx; end
                        2:begin ma<=myy; mb<=n; end
                        3:begin ma<=my; mb<=my; end
                        4:begin ma<=mxy; mb<=n; end
                        5:begin ma<=mx; mb<=my; end
                    endcase
                    acc<=0; count<=0; state<=MUL_LO;
                end
                MUL_LO:begin
                    low_sum<={1'b0,acc[23:0]}+(mb[0] ? {1'b0,ma[23:0]}:25'd0);
                    state<=MUL_HI;
                end
                MUL_HI:begin
                    acc<={acc[47:24]+(mb[0] ? ma[47:24]:24'd0)+
                          {{23{1'b0}},low_sum[24]},low_sum[23:0]};
                    ma<=ma<<1; mb<=mb>>1;
                    count<=count+1'b1;
                    state<=(count==22) ? MUL_SAVE:MUL_LO;
                end
                MUL_SAVE:begin
                    products[prod_index]<=acc;
                    prod_index<=prod_index+1'b1;
                    state<=(prod_index==5) ? COV:MUL_LOAD;
                end
                COV:begin
                    xx<=products[0]-products[1];
                    yy<=products[2]-products[3];
                    xy<=$signed({1'b0,products[4]})-$signed({1'b0,products[5]});
                    state<=DIFF;
                end
                DIFF:begin
                    delta<=$signed({1'b0,xx})-$signed({1'b0,yy});
                    cross_term<=xy<<<1;
                    trace_value<={1'b0,xx}+{1'b0,yy};
                    state<=ABS;
                end
                ABS:begin
                    abs_delta<=delta[48] ? -delta:delta;
                    abs_cross<=cross_term[48] ? -cross_term:cross_term;
                    delta_neg<=delta[48]; cross_neg<=cross_term[48];
                    radial_sum<=trace_value;
                    state<=NORM;
                end
                NORM:begin
                    if(|abs_delta[48:22] || |abs_cross[48:22] || |trace_value[48:22]) begin
                        abs_delta<=abs_delta>>1; abs_cross<=abs_cross>>1;
                        trace_value<=trace_value>>1;
                    end else state<=VEC_LOAD;
                end
                VEC_LOAD:begin
                    O_axis_valid<=trace_value!=0 &&
                        (abs_delta[21:0]+{1'b0,abs_cross[21:0]})>(trace_value[21:0]>>4);
                    vx<=$signed({3'd0,abs_delta[21:0]});
                    vy<=$signed({3'd0,abs_cross[21:0]});
                    vz<=0; iter<=0; state<=VEC;
                end
                VEC:begin
                    if(vy>0) begin
                        vx<=vx+(vy>>>iter); vy<=vy-(vx>>>iter);
                        vz<=vz+$signed(atan_q8(iter));
                    end else if(vy<0) begin
                        vx<=vx-(vy>>>iter); vy<=vy+(vx>>>iter);
                        vz<=vz-$signed(atan_q8(iter));
                    end
                    iter<=iter+1'b1;
                    if(iter==11) state<=ANGLE;
                end
                ANGLE:begin
                    if(delta_neg)
                        theta<=cross_neg ? 18'sd23040+(vz>>>1):18'sd23040-(vz>>>1);
                    else
                        theta<=cross_neg ? 18'sd46080-(vz>>>1):(vz>>>1);
                    state<=ROT_LOAD;
                end
                ROT_LOAD:begin
                    // Round only the displayed degrees; mapping retains Q8.
                    O_angle_bin<=((theta+18'sd128)>=18'sd46080) ? 9'd0 :
                                  ((theta+18'sd128)>>>8);
                    flip_cos<=theta>18'sd23040;
                    rz<=(theta>18'sd23040) ? 18'sd46080-theta:theta;
                    rx<=18'sd9949; ry<=0; iter<=0; state<=ROT;
                end
                ROT:begin
                    if(rz>=0) begin
                        rx<=rx-(ry>>>iter); ry<=ry+(rx>>>iter);
                        rz<=rz-$signed(atan_q8(iter));
                    end else begin
                        rx<=rx+(ry>>>iter); ry<=ry-(rx>>>iter);
                        rz<=rz+$signed(atan_q8(iter));
                    end
                    iter<=iter+1'b1;
                    if(iter==11) begin div_index<=0; state<=DIV_LOAD; end
                end
                DIV_LOAD:begin
                    O_cos<=flip_cos ? -rx:rx; O_sin<=ry;
                    case(div_index)
                        0:dividend<=mx;
                        1:dividend<=my;
                        2:dividend<=radial_sum;
                        3:dividend<=radial_sum;
                    endcase
                    quotient<=0; remainder<=0; div_count<=0; state<=DIV;
                end
                DIV:begin
                    dividend<=dividend<<1; remainder<=next_rem; quotient<=next_q;
                    div_count<=div_count+1'b1;
                    if(div_count==48) state<=DIV_SAVE;
                end
                DIV_SAVE:begin
                    case(div_index)
                        0:O_cx<=quotient[9:0];
                        1:O_cy<=quotient[9:0];
                        2:radial_sum<=quotient;
                        3:radial_mean<=quotient[19:0];
                    endcase
                    div_index<=div_index+1'b1;
                    state<=(div_index==3) ? SQRT_LOAD:DIV_LOAD;
                end
                SQRT_LOAD:begin
                    sqrt_bits<=radial_mean; sqrt_rem<=0; sqrt_root<=0;
                    iter<=0; state<=SQRT;
                end
                SQRT:begin
                    sqrt_bits<=sqrt_bits<<2;
                    sqrt_rem<=sqrt_take ? sqrt_trial-sqrt_sub:sqrt_trial;
                    sqrt_root<={sqrt_root[8:0],sqrt_take};
                    iter<=iter+1'b1;
                    if(iter==9) state<=PUBLISH;
                end
                PUBLISH:begin
                    O_extent<=(sqrt_root<4) ? 10'd16 :
                              (sqrt_root>254) ? 10'd1020:{sqrt_root[7:0],2'b00};
                    O_valid<=1; state<=IDLE;
                end
                default:state<=IDLE;
            endcase
        end
    end
endmodule
