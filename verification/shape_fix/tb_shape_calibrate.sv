`timescale 1ns/1ps
module tb_shape_calibrate;
    reg clk=0; always #5 clk=~clk;
    reg rst=0,start=0,valid=0,pixel=0,cal=0;
    reg [4:0] x=0,y=0;
    wire done,result_valid,ok;
    wire [10:0] score;
    wire [10:0] shape_union;
    shape_template_match dut(clk,rst,start,valid,pixel,x,y,1'b1,cal,done,result_valid,ok,score,shape_union,);
    function automatic bit pattern(input integer a,input integer b,input integer kind);
        case(kind)
            0:pattern=(a>=4 && a<=21 && b>=8 && b<=23) ||
                      (a>=8 && a<=10 && b>=3 && b<=8);
            1:pattern=(a>=9 && a<=25 && b>=4 && b<=18);
            2:pattern=pattern(31-a,31-b,0);
            4:pattern=(pattern(a,b,0) && a!=4 && a!=5 && a!=6 &&
                       b!=8 && b!=9) || (a==22 && b>=8 && b<=23);
            5:pattern=pattern(a,b-5,0);
            6:pattern=(a>=2 && a<=8 && b>=2 && b<=8);
            default:pattern=0;
        endcase
    endfunction
    task automatic send(input integer kind,input integer press_at,input integer expectation);
        integer j;
        begin
            @(negedge clk); start=1;
            @(negedge clk); start=0;
            for(j=0;j<1024;j=j+1) begin
                valid=1; x=j%32; y=j/32;
                pixel=pattern(x,y,kind); cal=j==press_at;
                @(negedge clk);
            end
            valid=0; cal=0;
            wait(done); @(negedge clk);
            if(expectation==3 && result_valid) $fatal(1,"untrained must WAIT");
            if(expectation<3 && (!result_valid || ok!=(expectation==1)))
                $fatal(1,"kind %0d expected %0d got valid %0b ok %0b score %0d",kind,expectation,result_valid,ok,score);
            $display("PASS matcher kind=%0d press_at=%0d score=%0d valid=%0b ok=%0b",kind,press_at,score,result_valid,ok);
            repeat(3) @(negedge clk);
        end
    endtask
    initial begin
        repeat(4) @(negedge clk); rst=1;
        send(1,500,3); // press mid-frame: capture must wait until next start
        send(0,-1,1);
        send(0,-1,1);
        if(score!=0) $fatal(1,"partial template captured");
        send(2,-1,1); // 180-degree ambiguity
        if(score!=0) $fatal(1,"reverse template mismatch");
        send(4,-1,1); // contour sampling shift: 94/319 union pixels differ
        if(score!=94) $fatal(1,"unexpected contour tolerance score %0d",score);
        send(5,-1,1); // moderate positional/angle normalization error
        if(score*3<=shape_union || score*2>shape_union)
            $fatal(1,"tolerance case did not cross only the old overlap limit");
        send(6,-1,2); // distinctly smaller silhouette still fails
        send(1,-1,2);
        send(1,800,2); // finish old comparison while scheduling re-calibration
        send(1,-1,1);
        send(1,-1,1);
        if(score!=0) $fatal(1,"recalibration mismatch");
        send(3,-1,2);
        $display("PASS: queued calibration, contour tolerance, recapture, reverse, empty mismatch");
        $finish;
    end
    initial begin #1000000; $fatal(1,"watchdog"); end
endmodule
