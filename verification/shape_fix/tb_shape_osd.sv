`timescale 1ns/1ps
module tb_shape_osd;
    reg clk=0; always #5 clk=~clk;
    reg rst=0,user=0,de=0,hs=0,vs=0;
    reg [2:0] mode=4;
    reg [8:0] angle=0;
    reg [10:0] score=11'h15a;
    reg [1:0] code=1;
    reg [23:0] data=24'h123456;
    reg qvalid=0;
    reg [6:0] qscore=0;
    reg [2:0] qgrade=0;
    wire [23:0] outdata;
    wire outde,ouths,outvs;
    hdmi_mixer dut(
        .I_clk(clk),.I_rst_n(rst),.I_video_vsync(vs),.I_video_hsync(hs),
        .I_video_de(de),.I_video_user(user),.I_video_last(1'b0),
        .I_debug_status(4'd0),.I_display_mode(mode),.I_gain_level(2'd0),
        .I_gain_level_update_toggle(1'b0),.I_inspection_object(1'b0),
        .I_inspection_baseline_valid(1'b0),.I_inspection_result_code(2'd0),
        .I_inspection_black_count_bcd(24'd0),
        .I_inspection_bbox_min_x(11'd0),.I_inspection_bbox_max_x(11'd0),
        .I_inspection_bbox_min_y(11'd0),.I_inspection_bbox_max_y(11'd0),
        .I_shape_valid(1'b1),.I_shape_result_code(code),.I_shape_score(score),
        .I_shape_angle(angle),.I_video_rd_data(data),
        .I_quality_valid(qvalid),.I_quality_score(qscore),
        .I_quality_grade(qgrade),.I_pass_count_bcd(20'd0),
        .I_fail_count_bcd(20'd0),
        .O_hdmi_data(outdata),.O_hdmi_de(outde),
        .O_hdmi_hsync(ouths),.O_hdmi_vsync(outvs),.O_video_rd_en()
    );
    integer a,c,row,m,xpos,ypos;
    task sof;
        begin
            @(negedge clk); user=1;
            @(negedge clk); user=0;
            repeat(12) @(negedge clk);
        end
    endtask
    initial begin
        repeat(5) @(negedge clk); rst=1;
        for(a=0;a<180;a=a+1) begin
            angle=a; sof();
            if(dut.S_angle_bcd[11:8]!=(a/100) ||
               dut.S_angle_bcd[7:4]!=((a/10)%10) ||
               dut.S_angle_bcd[3:0]!=(a%10))
                $fatal(1,"BCD mismatch angle %0d bcd %h",a,dut.S_angle_bcd);
        end
        angle=27; score=11'h123; code=1; sof();
        angle=151; score=11'h333; code=2;
        repeat(15) @(negedge clk);
        if(dut.S_shape_angle_frame!=27 || dut.S_shape_score_frame!=11'h123 ||
           dut.S_shape_result_code_frame!=1 || dut.S_angle_bcd!=12'h027)
            $fatal(1,"mid-frame shape metadata changed");
        de=1;
        repeat(4) @(negedge clk);
        force dut.S_x_2d=xpos;
        force dut.S_y_2d=ypos;
        for(m=0;m<5;m=m+1) begin
            mode=m; sof();
            for(row=32;row<56;row=row+1) begin
                ypos=184+row;
                for(c=0;c<216;c=c+1) begin
                    xpos=20+c; #1;
                    if(m<4 && dut.S_dyn_on) $fatal(1,"shape overlay leaked into mode %0d",m);
                    if(row>=40 && row<48 && c>=88 && dut.S_shape_info_on)
                        $fatal(1,"score trailing digits");
                    if(row>=48 && c>=72 && dut.S_shape_info_on)
                        $fatal(1,"angle trailing digits");
                end
            end
        end
        xpos=600; ypos=500;
        repeat(5) @(negedge clk);
        if(outdata!=data || !outde) $fatal(1,"unmodified video pixel");
        qvalid=1; qscore=81; qgrade=1; sof();
        if(!dut.S_quality_valid_frame ||
           dut.S_quality_score_bcd_frame!=12'h081 ||
           dut.S_quality_grade_frame!=1)
            $fatal(1,"quality frame metadata not captured");
        qvalid=0; qscore=0; qgrade=0;
        repeat(15) @(negedge clk);
        if(!dut.S_quality_valid_frame ||
           dut.S_quality_score_bcd_frame!=12'h081 ||
           dut.S_quality_grade_frame!=1)
            $fatal(1,"quality changed mid-frame");
        xpos=1152+10*8; ypos=36; #1;
        if(dut.S_quality_char!="8") $fatal(1,"quality tens digit");
        xpos=1152+7*8; ypos=52; #1;
        if(dut.S_quality_char!="P") $fatal(1,"grade PREMIUM text");
        sof();
        if(dut.S_quality_valid_frame || dut.S_quality_grade_frame!=0)
            $fatal(1,"WAIT not captured on next frame");
        release dut.S_x_2d; release dut.S_y_2d;
        $display("PASS: 180 angle labels, frame locking, mode isolation, trailing blanks, video pixel");
        $finish;
    end
endmodule
