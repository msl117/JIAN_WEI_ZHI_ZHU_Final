// Timestamps the incoming RAW10 frame and the DDR slot selected for HDMI.
// The displayed latency ends at HDMI frame selection (VSYNC), not at the
// monitor's panel; resolution is one millisecond.
module video_telemetry #(
    parameter integer DDR_CLK_HZ = 66666667
)(
    input  wire        I_camera_clk,
    input  wire        I_camera_frame_start,
    input  wire        I_ddr_clk,
    input  wire        I_rst_n,
    input  wire        I_write_start,
    input  wire [1:0]  I_write_slot,
    input  wire        I_display_start,
    input  wire [1:0]  I_display_slot,
    input  wire        I_display_ready,
    output reg  [11:0] O_latency_ms,
    output reg         O_latency_valid,
    output reg  [7:0]  O_camera_fps_bcd,
    output reg         O_update_toggle
);
    localparam integer TICKS_PER_MS = DDR_CLK_HZ / 1000;

    reg S_camera_toggle;
    (* ASYNC_REG = "TRUE" *) reg [1:0] S_camera_sync;
    reg S_camera_seen;
    wire S_camera_event = S_camera_sync[1] != S_camera_seen;

    reg [16:0] S_ms_divider;
    reg [9:0]  S_ms_in_second;
    reg [15:0] S_ms_counter;
    reg [15:0] S_pending_stamp;
    reg        S_pending_valid;
    reg        S_pending_overrun;
    reg [15:0] S_slot_stamp [0:3];
    reg [3:0]  S_slot_valid;
    reg [3:0]  S_slot_expired;
    reg [7:0]  S_fps_count_bcd;
    wire [15:0] S_elapsed_ms = S_ms_counter - S_slot_stamp[I_display_slot];
    integer i;

    always @(posedge I_camera_clk or negedge I_rst_n) begin
        if (!I_rst_n)
            S_camera_toggle <= 1'b0;
        else if (I_camera_frame_start)
            S_camera_toggle <= ~S_camera_toggle;
    end

    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            S_camera_sync <= 2'b00;
            S_camera_seen <= 1'b0;
            S_ms_divider <= 17'd0;
            S_ms_in_second <= 10'd0;
            S_ms_counter <= 16'd0;
            S_pending_stamp <= 16'd0;
            S_pending_valid <= 1'b0;
            S_pending_overrun <= 1'b0;
            S_slot_valid <= 4'b0000;
            S_slot_expired <= 4'b0000;
            S_fps_count_bcd <= 8'h00;
            O_camera_fps_bcd <= 8'h00;
            O_latency_ms <= 12'd0;
            O_latency_valid <= 1'b0;
            O_update_toggle <= 1'b0;
            for (i = 0; i < 4; i = i + 1)
                S_slot_stamp[i] <= 16'd0;
        end else begin
            S_camera_sync <= {S_camera_sync[0], S_camera_toggle};
            if (S_camera_event)
                S_camera_seen <= S_camera_sync[1];

            if (S_ms_divider == TICKS_PER_MS - 1) begin
                S_ms_divider <= 17'd0;
                S_ms_counter <= S_ms_counter + 1'b1;
                if (S_ms_in_second == 10'd999) begin
                    S_ms_in_second <= 10'd0;
                    O_camera_fps_bcd <= S_fps_count_bcd;
                    S_fps_count_bcd <= S_camera_event ? 8'h01 : 8'h00;
                end else
                    S_ms_in_second <= S_ms_in_second + 1'b1;
            end else
                S_ms_divider <= S_ms_divider + 1'b1;

            if (S_camera_event) begin
                S_pending_stamp <= S_ms_counter;
                S_pending_valid <= 1'b1;
                if (S_pending_valid)
                    S_pending_overrun <= 1'b1;
                if (!(S_ms_divider == TICKS_PER_MS - 1 &&
                      S_ms_in_second == 10'd999) &&
                    S_fps_count_bcd != 8'h99) begin
                    if (S_fps_count_bcd[3:0] == 4'd9)
                        S_fps_count_bcd <= {S_fps_count_bcd[7:4] + 4'd1, 4'd0};
                    else
                        S_fps_count_bcd <= S_fps_count_bcd + 1'b1;
                end
            end

            if (I_write_start) begin
                S_slot_stamp[I_write_slot] <=
                    S_camera_event ? S_ms_counter : S_pending_stamp;
                S_slot_valid[I_write_slot] <=
                    (S_pending_valid || S_camera_event) &&
                    !S_pending_overrun &&
                    !(S_pending_valid && S_camera_event);
                S_slot_expired[I_write_slot] <= 1'b0;
                S_pending_valid <= 1'b0;
                S_pending_overrun <= 1'b0;
            end

            if (I_display_start) begin
                O_latency_valid <= I_display_ready &&
                                   S_slot_valid[I_display_slot] &&
                                   !S_slot_expired[I_display_slot] &&
                                   (S_elapsed_ms <= 16'd4095);
                O_latency_ms <= S_elapsed_ms[11:0];
                if (S_elapsed_ms > 16'd4095)
                    S_slot_expired[I_display_slot] <= 1'b1;
                O_update_toggle <= ~O_update_toggle;
            end
        end
    end
endmodule
