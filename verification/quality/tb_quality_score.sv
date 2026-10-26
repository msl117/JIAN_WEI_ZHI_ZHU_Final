`timescale 1ns/1ps
module tb_quality_score;
    reg clk = 0;
    always #5 clk = ~clk;

    reg rst = 0;
    reg cal = 0;
    reg pair_pulse = 0;
    reg inspect_ready = 1;
    reg feature_update = 0;
    reg [19:0] live_black_count = 0;
    reg [19:0] area = 0;
    reg [19:0] baseline = 10000;
    reg baseline_valid = 1;
    reg object_present = 1;
    reg [10:0] mismatch = 0;
    reg [10:0] shape_union = 300;
    reg shape_valid = 1;
    reg shape_ok = 1;
    reg capture = 0;
    wire valid;
    wire [6:0] score;
    wire [2:0] grade;
    wire [19:0] pass_count_bcd;
    wire [19:0] fail_count_bcd;
    wire update_toggle;

    quality_score_ctrl dut (
        .I_clk(clk), .I_rst_n(rst), .I_calibrate(cal),
        .I_pair_pulse(pair_pulse), .I_inspect_ready(inspect_ready),
        .I_feature_update(feature_update),
        .I_live_black_count(live_black_count),
        .I_area(area), .I_baseline(baseline),
        .I_baseline_valid(baseline_valid),
        .I_object_present(object_present),
        .I_mismatch(mismatch), .I_union(shape_union),
        .I_shape_valid(shape_valid), .I_shape_ok(shape_ok),
        .I_capture(capture), .O_valid(valid), .O_score(score),
        .O_grade(grade), .O_pass_count_bcd(pass_count_bcd),
        .O_fail_count_bcd(fail_count_bcd),
        .O_update_toggle(update_toggle)
    );

    task send_pair(input [19:0] pixels, input [10:0] miss,
                   input [10:0] uni, input ok, input cap);
        begin
            @(negedge clk);
            area = pixels;
            live_black_count = pixels;
            mismatch = miss;
            shape_union = uni;
            shape_ok = ok;
            capture = cap;
            pair_pulse = 1;
            @(negedge clk);
            pair_pulse = 0;
            capture = 0;
        end
    endtask

    task leave_workpiece;
        integer i;
        begin
            live_black_count = 0;
            for (i = 0; i < 3; i = i + 1) begin
                @(negedge clk);
                feature_update = 1;
                @(negedge clk);
                feature_update = 0;
            end
            @(negedge clk);
        end
    endtask

    task expect_result(input [2:0] wanted_grade,
                       input [6:0] min_score, input [6:0] max_score);
        integer cycles;
        begin
            cycles = 0;
            while (!valid && cycles < 160) begin
                @(negedge clk);
                cycles = cycles + 1;
            end
            if (!valid || grade !== wanted_grade ||
                score < min_score || score > max_score)
                $fatal(1, "grade=%0d score=%0d valid=%0d expected=%0d [%0d,%0d]",
                       grade, score, valid, wanted_grade, min_score, max_score);
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst = 1;
        if (valid || grade !== 3'd0)
            $fatal(1, "reset must be WAIT");

        send_pair(10000, 0, 300, 1, 0);
        if (valid || grade !== 3'd0)
            $fatal(1, "uncalibrated workpiece must be WAIT");

        @(negedge clk); cal = 1;
        @(negedge clk); cal = 0;
        send_pair(10000, 0, 300, 1, 1);
        if (valid || grade !== 3'd0)
            $fatal(1, "template capture must be WAIT");

        leave_workpiece();
        send_pair(10000, 0, 300, 1, 0);
        expect_result(3'd3, 7'd100, 7'd100);
        if (pass_count_bcd !== 20'h00001 || fail_count_bcd !== 0)
            $fatal(1, "first PASS not counted once");

        leave_workpiece();
        send_pair(11000, 100, 300, 1, 0);
        expect_result(3'd3, 7'd1, 7'd99);
        if (pass_count_bcd !== 20'h00002)
            $fatal(1, "second PASS not counted once");

        leave_workpiece();
        send_pair(12000, 0, 300, 1, 0);
        expect_result(3'd4, 7'd0, 7'd60);
        if (fail_count_bcd !== 20'h00001)
            $fatal(1, "area FAIL not counted once");

        leave_workpiece();
        send_pair(10000, 400, 650, 0, 0);
        expect_result(3'd4, 7'd0, 7'd60);
        if (fail_count_bcd !== 20'h00002)
            $fatal(1, "shape FAIL not counted once");

        leave_workpiece();
        object_present = 0;
        send_pair(10000, 0, 300, 1, 0);
        if (valid || grade !== 3'd0)
            $fatal(1, "no object must be WAIT");

        object_present = 1;
        send_pair(10000, 0, 0, 1, 0);
        if (valid || grade !== 3'd0)
            $fatal(1, "zero union must be WAIT");

        @(negedge clk); cal = 1;
        @(negedge clk); cal = 0;
        if (valid || grade !== 3'd0 ||
            pass_count_bcd !== 0 || fail_count_bcd !== 0)
            $fatal(1, "C7 must reset grade and counters");

        $display("QUALITY_SCORE_PASS");
        $finish;
    end
endmodule
