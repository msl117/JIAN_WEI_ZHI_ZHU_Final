`timescale 1ns/1ps
module tb_shape_pipeline;
    reg clk=0; always #5 clk=~clk;
    reg rst=0,user=0,valid=0,calibrate=0;
    reg [95:0] data=0;
    wire mv,av,axis_ok;
    wire [19:0] n;
    wire [28:0] mx,my;
    wire [39:0] mxx,mxy;
    wire [38:0] myy;
    wire [9:0] xmin,xmax,ymin,ymax,cx,cy,extent;
    wire [8:0] angle;
    wire signed [15:0] cosine,sine;
    wire read_en,pixel,rv,rp,rdone,mdone,match_valid,match_ok;
    wire [9:0] rx,ry;
    wire [4:0] dx,dy;
    wire [10:0] score;
    wire toggle,fvalid;
    wire [1:0] code;
    wire [10:0] fscore;
    wire [8:0] fangle;
    reg start=0;
    wire [17:0] address=ry*18'd60+(rx>>2);
    roi_binary_frame_buffer buf_dut(clk,rst,user,valid,data,read_en,address,
        rx[1:0],pixel,,);
    roi_moment_stats mom(clk,rst,user,valid,data,mv,n,mx,my,mxx,myy,mxy,
        xmin,xmax,ymin,ymax);
    roi_axis_calc axis_dut(clk,rst,mv,n,mx,my,mxx,myy,mxy,av,axis_ok,,
        angle,cx,cy,extent,cosine,sine);
    always @(posedge clk) start<=rst && av && axis_ok;
    roi_rotate_normalize rot(clk,rst,start,axis_ok,angle,cx,cy,xmin,xmax,ymin,ymax,
        extent,cosine,sine,pixel,read_en,rx,ry,rv,dx,dy,rp,rdone);
    shape_template_match match_dut(clk,rst,start,rv,rp,dx,dy,axis_ok,calibrate,
        mdone,match_valid,match_ok,score,,);
    shape_match_fusion fusion(clk,rst,av,axis_ok,angle,mdone,match_valid,
        match_ok,score,toggle,fvalid,code,fscore,fangle);

    integer expected_n,expected_x,expected_y,expected_xx,expected_yy,expected_xy;
    integer frame_number=0,publications=0;
    reg seen_toggle=0,was_mv=0;
    integer count;
    always @(negedge clk) begin
        if(rst && mv && !was_mv) begin
            if(n!==expected_n || mx!==expected_x || my!==expected_y ||
               mxx!==expected_xx || myy!==expected_yy || mxy!==expected_xy)
                $fatal(1,"moments mismatch frame %0d got %0d/%0d/%0d/%0d/%0d/%0d expected %0d/%0d/%0d/%0d/%0d/%0d",
                    frame_number,n,mx,my,mxx,myy,mxy,
                    expected_n,expected_x,expected_y,expected_xx,expected_yy,expected_xy);
        end
        was_mv=mv;
        if(rst && toggle!=seen_toggle) begin
            seen_toggle=toggle; publications=publications+1;
        end
    end
    function automatic bit object_pixel(input integer sx,input integer sy,
                                       input real deg,input integer shape);
        real u,v,a,b,t;
        begin
            t=deg*3.141592653589793/180.0;
            a=(sx-160)/4.0-119.5; b=(sy-90)/4.0-67.0;
            u=a*$cos(t)+b*$sin(t); v=-a*$sin(t)+b*$cos(t);
            case(shape)
                0:object_pixel=(u>=-52 && u<=52 && v>=-9 && v<=9);
                1:object_pixel=(u>=-52 && u<=52 && v>=-22 && v<=22);
                2:object_pixel=0;
                default:object_pixel=(a>=-25 && a<=25 && b>=-25 && b<=25);
            endcase
        end
    endfunction
    task automatic frame(input real deg,input integer shape,input bit capture,
                         input integer expected_code,input bit inline_user);
        integer x,y,p,ix,iy,old_pub,guard,angle_err;
        reg fg;
        begin
            old_pub=publications;
            expected_n=0; expected_x=0; expected_y=0;
            expected_xx=0; expected_yy=0; expected_xy=0;
            frame_number=frame_number+1;
            @(negedge clk); calibrate=capture;
            @(negedge clk); calibrate=0;
            if(!inline_user) begin
                user=1; valid=0;
                @(negedge clk); user=0;
            end
            for(y=0;y<720;y=y+1) begin
                for(x=0;x<1280;x=x+4) begin
                    valid=1; user=inline_user && y==0 && x==0;
                    data={4{24'hffffff}};
                    for(p=0;p<4;p=p+1) begin
                        fg=x+p>=160 && x+p<1120 && y>=90 && y<630 &&
                           object_pixel(x+p,y,deg,shape);
                        data[p*24+:24]=fg ? 24'h000000:24'hffffff;
                        if(fg && p==2 && ((y-90)%4)==2) begin
                            ix=(x-160)/4; iy=(y-90)/4;
                            expected_n=expected_n+1;
                            expected_x=expected_x+ix; expected_y=expected_y+iy;
                            expected_xx=expected_xx+ix*ix;
                            expected_yy=expected_yy+iy*iy;
                            expected_xy=expected_xy+ix*iy;
                        end
                    end
                    @(negedge clk);
                    // Gaps must not advance the subsampled coordinates.
                    if(x==300 && (y%17)==0) begin
                        valid=0; user=0;
                        repeat(3) @(negedge clk);
                    end
                end
                valid=0; user=0;
                repeat(2) @(negedge clk);
            end
            valid=0; user=0; guard=0;
            while(publications==old_pub && guard<16000) begin
                @(negedge clk); guard=guard+1;
            end
            if(guard==16000) $fatal(1,"no result frame %0d state %0d",frame_number,axis_dut.state);
            if(code!==expected_code)
                $fatal(1,"code frame %0d deg %f code %0d expected %0d score %0d angle %0d extent %0d",frame_number,deg,code,expected_code,fscore,fangle,extent);
            if(shape<2) begin
                angle_err=fangle-$rtoi(deg);
                if(angle_err<0) angle_err=-angle_err;
                if(angle_err>90) angle_err=180-angle_err;
                if(angle_err>2) $fatal(1,"angle deg %f got %0d",deg,fangle);
                if(cx<118 || cx>120 || cy<65 || cy>68) $fatal(1,"centroid %0d %0d",cx,cy);
            end
            repeat(40) @(negedge clk);
            if(publications!=old_pub+1) $fatal(1,"extra WAIT publication");
            $display("PASS frame=%0d angle=%0d score=%0d status=%0d area=%0d extent=%0d",
                frame_number,fangle,fscore,code,n,extent);
        end
    endtask
    initial begin
        repeat(5) @(negedge clk); rst=1;
        frame(0,0,0,3,0);  // no static demonstration template before calibration
        frame(0,0,1,1,1);  // learn full completed silhouette
        frame(0,0,0,1,0);
        if(fscore!=0) $fatal(1,"same frame must match exactly");
        frame(13,0,0,1,1);
        frame(27,0,0,1,0);
        frame(44,0,0,1,1);
        frame(68,0,0,1,0);
        frame(90,0,0,1,1);
        frame(119,0,0,1,0);
        frame(151,0,0,1,1);
        frame(179,0,0,1,0);
        frame(27,1,0,2,0); // thicker wrong part
        frame(27,1,1,1,1); // re-learn
        frame(27,1,0,1,0);
        frame(0,2,0,0,0);  // empty object: axis invalid
        frame(0,3,0,0,1);  // symmetric shape: axis ambiguous, not false MATCH
        $display("PASS: shape pipeline, calibration, fine angle, rotation, mismatch, frame publication");
        $finish;
    end
    initial begin #100000000; $fatal(1,"simulation watchdog"); end
endmodule
