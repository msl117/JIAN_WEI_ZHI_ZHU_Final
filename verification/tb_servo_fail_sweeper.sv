`timescale 1ns/1ps
module tb_servo_fail_sweeper;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg result_valid = 1'b0;
    reg [2:0] result_grade = 3'd0;
    reg result_toggle = 1'b0;
    wire servo_pwm;
    wire busy;
    integer cycle;
    integer busy_rises;
    integer max_positions;
    reg previous_busy;
    reg saw_180;
    reg saw_return;
    reg previous_max;

    always #5 clk = ~clk;

    servo_fail_sweeper #(
        .SERVO_PERIOD_CYCLES(20),
        .PULSE_0_CYCLES(2),
        .PULSE_180_CYCLES(10),
        .ANGLE_STEP_DEG(90)
    ) dut (
        .I_clk(clk),
        .I_rst_n(rst_n),
        .I_result_valid(result_valid),
        .I_result_grade(result_grade),
        .I_result_toggle(result_toggle),
        .O_servo_pwm(servo_pwm),
        .O_busy(busy)
    );

    initial begin
        busy_rises = 0;
        max_positions = 0;
        previous_busy = 1'b0;
        previous_max = 1'b0;
        saw_180 = 1'b0;
        saw_return = 1'b0;
        repeat(4) @(posedge clk);
        rst_n = 1'b1;

        @(negedge clk);
        result_valid = 1'b1;
        result_grade = 3'd4;
        result_toggle = 1'b1;

        for(cycle=0; cycle<1600; cycle=cycle+1) begin
            if(cycle == 60) begin
                @(negedge clk);
                result_grade = 3'd0;
                result_toggle = ~result_toggle;
            end
            if(cycle == 62) begin
                @(negedge clk);
                result_grade = 3'd4;
                result_toggle = ~result_toggle;
            end
            @(posedge clk);
            #1;
            if(busy && !dut.S_returning && dut.S_angle_deg == 180) begin
                saw_180 = 1'b1;
                if(!previous_max)
                    max_positions = max_positions + 1;
                if(dut.S_pulse_width != 10)
                    $fatal(1, "180 degree pulse width was not exact");
            end
            if(saw_180 && dut.S_returning && dut.S_angle_deg < 180)
                saw_return = 1'b1;
            previous_max = busy && !dut.S_returning &&
                           dut.S_angle_deg == 180;
            if(busy && !previous_busy)
                busy_rises = busy_rises + 1;
            previous_busy = busy;
        end

        if(!saw_180 || !saw_return)
            $fatal(1, "servo did not complete the 0 -> 180 -> 0 sweep");
        if(busy)
            $fatal(1, "servo remained busy after completing the sweep");
        if(busy_rises != 1)
            $fatal(1, "queued FAIL caused a gap between actions");
        if(max_positions != 2)
            $fatal(1, "expected two sweeps, observed %0d", max_positions);

        $display("PASS: persistent FAIL does not retrigger; queued FAIL runs after return");
        $finish;
    end
endmodule
