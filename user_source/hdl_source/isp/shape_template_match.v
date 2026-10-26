// Learned 32x32 silhouette, with a 180-degree alternative for PCA ambiguity.
// Calibration is consumed only at a new normalized frame, never mid-frame.
module shape_template_match #(
    parameter integer SCORE_THRESHOLD=320
)(
    input wire I_clk,I_rst_n,I_start,I_valid,I_pixel,
    input wire [4:0] I_x,I_y,
    input wire I_axis_valid,I_calibrate,
    output reg O_done,O_valid,O_ok,
    output reg [10:0] O_score,
    output reg [10:0] O_union,
    output reg O_captured
);
    reg template_a[0:1023];
    reg template_b[0:1023];
    reg read_a,read_b;
    reg pending,capture,loaded,axis_valid;
    reg pipe_valid,pipe_pixel,pipe_last,pipe_capture;
    reg [10:0] score_a,score_b,union_a,union_b,foreground;
    wire [9:0] addr={I_y,I_x};
    wire [10:0] next_a=score_a+(pipe_pixel!=read_a);
    wire [10:0] next_b=score_b+(pipe_pixel!=read_b);
    wire [10:0] next_ua=union_a+(pipe_pixel|read_a);
    wire [10:0] next_ub=union_b+(pipe_pixel|read_b);
    wire [10:0] best=(next_a<=next_b) ? next_a:next_b;
    wire [10:0] best_union=(next_a<=next_b) ? next_ua:next_ub;
    wire [11:0] double_best={best,1'b0};
    // RAM contents need no reset: loaded masks them until a full capture.
    always @(posedge I_clk) begin
        if(I_valid) begin
            read_a<=template_a[addr];
            read_b<=template_b[~addr];
            if(capture) begin
                template_a[addr]<=I_pixel;
                template_b[addr]<=I_pixel;
            end
        end
    end
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            pending<=0; capture<=0; loaded<=0; axis_valid<=0;
            pipe_valid<=0; pipe_pixel<=0; pipe_last<=0; pipe_capture<=0;
            score_a<=0; score_b<=0; union_a<=0; union_b<=0; foreground<=0;
            O_done<=0; O_valid<=0; O_ok<=0; O_score<=0;
            O_union<=0; O_captured<=0;
        end else begin
            O_done<=0;
            pipe_valid<=I_valid;
            pipe_pixel<=I_pixel;
            pipe_last<=I_x==31 && I_y==31;
            pipe_capture<=capture;
            if(I_calibrate) pending<=1;
            if(I_start) begin
                score_a<=0; score_b<=0; union_a<=0; union_b<=0; foreground<=0;
                axis_valid<=I_axis_valid;
                capture<=(pending || I_calibrate) && I_axis_valid;
                if((pending || I_calibrate) && I_axis_valid) begin
                    pending<=0;
                    loaded<=0;
                end
            end
            if(pipe_valid) begin
                score_a<=next_a; score_b<=next_b;
                union_a<=next_ua; union_b<=next_ub;
                foreground<=foreground+pipe_pixel;
                if(pipe_last) begin
                    O_done<=1;
                    O_captured<=pipe_capture;
                    if(pipe_capture) begin
                        loaded<=(foreground+pipe_pixel)>=8;
                        O_valid<=axis_valid && (foreground+pipe_pixel)>=8;
                        O_ok<=axis_valid && (foreground+pipe_pixel)>=8;
                        O_score<=0;
                        O_union<=0;
                    end else begin
                        O_valid<=axis_valid && loaded;
                        O_score<=loaded ? best:0;
                        O_union<=loaded ? best_union:0;
                        // Cap absolute mismatch and require at least 1/2 overlap.
                        // This prevents an empty/thin silhouette passing merely
                        // because it occupies less than SCORE_THRESHOLD pixels.
                        O_ok<=axis_valid && loaded && best<=SCORE_THRESHOLD &&
                              double_best<={1'b0,best_union} && best_union!=0;
                    end
                end
            end
        end
    end
endmodule
