// SC520CS exposure/gain control. D5 cycles LOW, MEDIUM, HIGH, AUTO.
// All register writes use the existing uicfgcs520 request/done interface.
module ae_set #(
    parameter integer GAIN_KEY_DEBOUNCE_CYCLES = 476190
) (
    input  wire        I_clk,
    input  wire        I_rst,
    input  wire [3:0]  I_btn,
    input  wire        I_ae_cfg_done,
    input  wire        I_cam_cfg_done,
    input  wire        I_feature_valid,
    input  wire        I_object_present,
    input  wire        I_debug_mode,
    input  wire        I_meter_valid,
    input  wire [9:0]  I_meter_luma,
    output reg         O_ae_req,
    output reg  [15:0] O_ae,
    output reg  [15:0] O_ag,
    output reg  [1:0]  O_gain_mode
);
    // Exposure is in half-lines. VTS=1000 in the official 720p60 table.
    localparam [15:0] EXP_MAX = 16'd1991;
    localparam [15:0] GAIN_MIN = 16'd16;
    localparam [15:0] GAIN_MAX = 16'd176;
    localparam [9:0] LUMA_LOW = 10'd720;
    localparam [9:0] LUMA_HIGH = 10'd840;

    reg [1:0] S_key_sync;
    reg [18:0] S_key_count;
    reg S_key_pressed, S_key_pulse;
    reg [1:0] S_requested_mode, S_write_mode;
    reg [2:0] S_settle_frames;
    reg [9:0] S_meter_luma;
    reg S_meter_pending, S_initial_write;
    reg S_mode_write_pending, S_wait_write, S_seen_busy;
    reg [15:0] S_target_ae, S_target_ag;
    wire S_auto_hold = I_debug_mode && I_object_present;

    always @(posedge I_clk or posedge I_rst) begin
        if (I_rst) begin
            S_key_sync <= 2'b11;
            S_key_count <= 0;
            S_key_pressed <= 0;
            S_key_pulse <= 0;
        end else begin
            S_key_sync <= {S_key_sync[0], I_btn[3]};
            S_key_pulse <= 0;
            if ((~S_key_sync[1]) == S_key_pressed)
                S_key_count <= 0;
            else if (S_key_count == GAIN_KEY_DEBOUNCE_CYCLES - 1) begin
                S_key_count <= 0;
                S_key_pressed <= ~S_key_sync[1];
                if (!S_key_sync[1])
                    S_key_pulse <= 1;
            end else
                S_key_count <= S_key_count + 1'b1;
        end
    end

    always @(posedge I_clk or posedge I_rst) begin
        if (I_rst) begin
            S_requested_mode <= 0;
            S_write_mode <= 0;
            O_gain_mode <= 0;
            S_settle_frames <= 0;
            S_meter_luma <= 0;
            S_meter_pending <= 0;
            S_initial_write <= 0;
            S_mode_write_pending <= 0;
            S_wait_write <= 0;
            S_seen_busy <= 0;
            S_target_ae <= EXP_MAX;
            S_target_ag <= 16'd144;
            O_ae <= 16'd1990;
            O_ag <= 16'd17;
            O_ae_req <= 0;
        end else begin
            O_ae_req <= 0;
            if (S_key_pulse)
                S_requested_mode <= S_requested_mode + 1'b1;

            if (I_meter_valid) begin
                S_meter_luma <= I_meter_luma;
                S_meter_pending <= 1;
            end
            if (I_feature_valid) begin
                if (S_auto_hold)
                    S_meter_pending <= 0;
                if (S_settle_frames != 0)
                    S_settle_frames <= S_settle_frames - 1'b1;
            end

            if (S_wait_write) begin
                if (!I_ae_cfg_done)
                    S_seen_busy <= 1;
                if (S_seen_busy && I_ae_cfg_done) begin
                    S_wait_write <= 0;
                    S_seen_busy <= 0;
                    S_settle_frames <= 3'd1;
                    S_meter_pending <= 0;
                    if (S_mode_write_pending) begin
                        O_gain_mode <= S_write_mode;
                        S_mode_write_pending <= 0;
                    end
                end
            end else if (I_cam_cfg_done && I_ae_cfg_done) begin
                if (!S_initial_write || O_ae != S_target_ae ||
                    O_ag != S_target_ag) begin
                    O_ae <= S_target_ae;
                    O_ag <= S_target_ag;
                    O_ae_req <= 1;
                    S_initial_write <= 1;
                    S_wait_write <= 1;
                    S_seen_busy <= 0;
                end else if (!S_mode_write_pending &&
                             S_requested_mode != O_gain_mode) begin
                    S_write_mode <= S_requested_mode;
                    S_meter_pending <= 0;
                    if (S_requested_mode == 2'd3) begin
                        // AUTO starts from the settings already in the sensor.
                        O_gain_mode <= 2'd3;
                        S_target_ae <= EXP_MAX;
                        S_settle_frames <= 3'd1;
                    end else begin
                        S_target_ae <= EXP_MAX;
                        case (S_requested_mode)
                            2'd0: S_target_ag <= 16'd144;
                            2'd1: S_target_ag <= 16'd160;
                            default: S_target_ag <= 16'd176;
                        endcase
                        S_mode_write_pending <= 1;
                    end
                end else if (S_mode_write_pending &&
                             O_ae == S_target_ae && O_ag == S_target_ag) begin
                    O_gain_mode <= S_write_mode;
                    S_mode_write_pending <= 0;
                end else if (O_gain_mode == 2'd3 &&
                             S_requested_mode == 2'd3 &&
                             !S_mode_write_pending && !S_auto_hold &&
                             I_feature_valid && S_meter_pending &&
                             S_settle_frames == 0) begin
                    S_meter_pending <= 0;
                    if (S_meter_luma < LUMA_LOW) begin
                        if (S_target_ag < GAIN_MAX - 16'd8)
                            S_target_ag <= S_target_ag + 16'd8;
                        else
                            S_target_ag <= GAIN_MAX;
                    end else if (S_meter_luma > LUMA_HIGH) begin
                        if (S_target_ag > GAIN_MIN + 16'd8)
                            S_target_ag <= S_target_ag - 16'd8;
                        else
                            S_target_ag <= GAIN_MIN;
                    end
                end
            end
        end
    end
endmodule
