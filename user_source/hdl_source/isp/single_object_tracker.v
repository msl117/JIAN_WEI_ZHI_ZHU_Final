// Single-object tracking for the inspection branch.
// Clock domain: 24 MHz control clock. The existing stable ROI feature and
// quality result events are sampled here; the HDMI path receives the bundled
// result through a toggle-based CDC in design_top_wrapper.
//
// This is intentionally a light-weight tracker for the fixed single-workpiece
// station: a valid object owns ID 1, and its box center is updated once per
// completed ROI feature frame. The latency value measures feature-update to
// quality-publication time in microseconds, not camera-to-display latency.
module single_object_tracker #(
    parameter integer CLK_HZ = 24000000
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_feature_update,
    input  wire        I_object_present,
    input  wire [10:0] I_min_x,
    input  wire [10:0] I_max_x,
    input  wire [10:0] I_min_y,
    input  wire [10:0] I_max_y,
    input  wire        I_quality_valid,
    input  wire        I_quality_update_toggle,

    output reg         O_track_valid,
    output reg  [3:0]  O_track_id,
    output reg  [10:0] O_center_x,
    output reg  [10:0] O_center_y,
    output reg  [11:0] O_latency_us,
    output reg         O_latency_valid,
    output reg         O_update_toggle
);

    localparam integer TICKS_PER_US = CLK_HZ / 1000000;

    reg         S_latency_active;
    reg         S_measure_done;
    reg         S_quality_toggle_seen;
    reg [4:0]   S_us_tick;
    reg [11:0]  S_elapsed_us;

    wire [11:0] S_center_x_sum = {1'b0,I_min_x} + {1'b0,I_max_x};
    wire [11:0] S_center_y_sum = {1'b0,I_min_y} + {1'b0,I_max_y};

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_track_valid        <= 1'b0;
            O_track_id           <= 4'd0;
            O_center_x           <= 11'd0;
            O_center_y           <= 11'd0;
            O_latency_us         <= 12'd0;
            O_latency_valid      <= 1'b0;
            O_update_toggle      <= 1'b0;
            S_latency_active     <= 1'b0;
            S_measure_done       <= 1'b0;
            S_quality_toggle_seen<= 1'b0;
            S_us_tick             <= 5'd0;
            S_elapsed_us          <= 12'd0;
        end
        else begin
            // The quality controller changes its toggle for intermediate
            // events too. Only a valid publication closes the measurement.
            if(I_quality_update_toggle != S_quality_toggle_seen) begin
                S_quality_toggle_seen <= I_quality_update_toggle;
                if(I_quality_valid && S_latency_active) begin
                    O_latency_us    <= S_elapsed_us;
                    O_latency_valid <= 1'b1;
                    O_update_toggle <= ~O_update_toggle;
                    S_latency_active<= 1'b0;
                end
            end

            if(S_latency_active) begin
                if(S_us_tick == TICKS_PER_US-1) begin
                    S_us_tick <= 5'd0;
                    if(S_elapsed_us != 12'hfff)
                        S_elapsed_us <= S_elapsed_us + 12'd1;
                end
                else begin
                    S_us_tick <= S_us_tick + 5'd1;
                end
            end

            if(I_feature_update) begin
                O_track_valid   <= I_object_present;
                O_track_id      <= I_object_present ? 4'd1 : 4'd0;
                O_center_x      <= S_center_x_sum[11:1];
                O_center_y      <= S_center_y_sum[11:1];
                O_update_toggle <= ~O_update_toggle;

                // Start one measurement for each occupied inspection cycle.
                // The next measurement is armed only after a valid result or
                // after the object has left the ROI.
                if(I_object_present && !S_latency_active && !S_measure_done) begin
                    S_latency_active <= 1'b1;
                    S_measure_done   <= 1'b1;
                    S_us_tick         <= 5'd0;
                    S_elapsed_us      <= 12'd0;
                end
                else if(!I_object_present) begin
                    S_latency_active <= 1'b0;
                    S_measure_done   <= 1'b0;
                    S_us_tick         <= 5'd0;
                    S_elapsed_us      <= 12'd0;
                end
            end
        end
    end

endmodule
