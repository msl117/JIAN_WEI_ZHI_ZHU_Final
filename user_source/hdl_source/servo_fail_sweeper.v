// 50 Hz servo driver for the FAIL reject action.
// The output is an active-high 0.5 ms to 2.5 ms pulse on a 20 ms frame.
// A published FAIL starts one 0 -> 180 -> 0 degree movement. The result
// event is edge-qualified; one new FAIL can be queued while the servo is busy.
module servo_fail_sweeper #(
    parameter integer SERVO_PERIOD_CYCLES = 476190,
    parameter integer PULSE_0_CYCLES      = 11905,
    parameter integer PULSE_180_CYCLES    = 59524,
    parameter integer ANGLE_STEP_DEG      = 10
)(
    input  wire I_clk,
    input  wire I_rst_n,
    input  wire I_result_valid,
    input  wire [2:0] I_result_grade,
    input  wire I_result_toggle,
    output wire O_servo_pwm,
    output wire O_busy
);

    localparam [2:0] GRADE_FAIL = 3'd4;
    localparam [18:0] SERVO_PERIOD_LAST = SERVO_PERIOD_CYCLES - 1;
    localparam [15:0] PULSE_STEP_CYCLES =
        (PULSE_180_CYCLES - PULSE_0_CYCLES) /
        (180 / ANGLE_STEP_DEG);
    localparam [7:0] ANGLE_STEP_VALUE = ANGLE_STEP_DEG;

    reg [18:0] S_period_count;
    reg [15:0] S_pulse_width;
    reg [7:0]  S_angle_deg;
    reg        S_returning;
    reg        S_busy;
    reg        S_fail_armed;
    reg        S_pending_fail;
    reg        S_result_toggle_seen;
    wire       S_result_event = I_result_toggle != S_result_toggle_seen;
    wire       S_fail_event = S_result_event && I_result_valid &&
                              I_result_grade == GRADE_FAIL;

    // Keep sending the 0-degree pulse while idle so the servo holds position.
    assign O_servo_pwm = (S_period_count < S_pulse_width) && I_rst_n;
    assign O_busy = S_busy;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_period_count       <= 19'd0;
            S_pulse_width        <= PULSE_0_CYCLES[15:0];
            S_angle_deg           <= 8'd0;
            S_returning           <= 1'b0;
            S_busy                <= 1'b0;
            S_fail_armed          <= 1'b1;
            S_pending_fail        <= 1'b0;
            S_result_toggle_seen  <= 1'b0;
        end else begin
            if(S_period_count >= SERVO_PERIOD_LAST)
                S_period_count <= 19'd0;
            else
                S_period_count <= S_period_count + 1'b1;

            // A non-FAIL published result arms the next FAIL event.  This
            // prevents a persistent FAIL or a repeated display update from
            // starting another sweep.
            if(S_result_event) begin
                S_result_toggle_seen <= I_result_toggle;
                if(S_fail_event) begin
                    if(S_fail_armed) begin
                        S_fail_armed   <= 1'b0;
                        if(!S_busy) begin
                            S_busy         <= 1'b1;
                            S_returning    <= 1'b0;
                            S_angle_deg    <= 8'd0;
                            S_pulse_width  <= PULSE_0_CYCLES[15:0];
                        end else begin
                            S_pending_fail <= 1'b1;
                        end
                    end
                end else begin
                    S_fail_armed <= 1'b1;
                end
            end

            if(S_busy && S_period_count >= SERVO_PERIOD_LAST) begin
                if(!S_returning) begin
                    if(S_angle_deg >= 8'd180) begin
                        // Keep 180 degrees for one complete servo period.
                        S_returning <= 1'b1;
                    end else if(S_angle_deg >=
                                (8'd180 - ANGLE_STEP_VALUE)) begin
                        S_angle_deg   <= 8'd180;
                        S_pulse_width <= PULSE_180_CYCLES[15:0];
                    end else begin
                        S_angle_deg   <= S_angle_deg + ANGLE_STEP_VALUE;
                        S_pulse_width <= S_pulse_width + PULSE_STEP_CYCLES;
                    end
                end else if(S_angle_deg <= ANGLE_STEP_VALUE) begin
                    S_angle_deg   <= 8'd0;
                    S_pulse_width <= PULSE_0_CYCLES[15:0];
                    if(S_pending_fail || (S_fail_event && S_fail_armed)) begin
                        S_pending_fail <= 1'b0;
                        S_returning    <= 1'b0;
                    end else begin
                        S_busy <= 1'b0;
                    end
                end else begin
                    S_angle_deg   <= S_angle_deg - ANGLE_STEP_VALUE;
                    S_pulse_width <= S_pulse_width - PULSE_STEP_CYCLES;
                end
            end
        end
    end
endmodule
