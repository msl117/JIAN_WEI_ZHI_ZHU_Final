// Display-mode controller for the SC520 camera path.
//
// The button is active-low. A short press changes the current display mode;
// a long press changes between compatibility and extension mode. Actions are
// committed on release so a long press can never also create a short press.
// The mode is exported in Gray code because it crosses into video clock
// domains as a stable multi-bit control value.
module display_mode_ctrl #(
    parameter integer CLK_HZ = 23809524,
    parameter integer DEBOUNCE_MS = 20,
    parameter integer LONG_PRESS_MS = 1000
)(
    input  wire       I_clk,
    input  wire       I_rst_n,
    input  wire       I_key_in,
    output reg [1:0]  O_mode_bin,
    output wire [1:0] O_mode_gray,
    output wire       O_extended_mode
);

    localparam integer DEBOUNCE_CYCLES = (CLK_HZ / 1000) * DEBOUNCE_MS;
    localparam integer LONG_PRESS_CYCLES = (CLK_HZ / 1000) * LONG_PRESS_MS;

    reg S_key_sync_1d;
    reg S_key_sync_2d;
    reg S_key_stable;
    reg S_key_stable_1d;
    reg [23:0] S_debounce_cnt;
    reg [24:0] S_press_cnt;
    reg        S_long_seen;
    reg        S_extended_mode;

    wire S_press_event;
    wire S_release_event;

    assign S_press_event = S_key_stable_1d & ~S_key_stable;
    assign S_release_event = ~S_key_stable_1d & S_key_stable;
    assign O_mode_gray = {O_mode_bin[1], O_mode_bin[1] ^ O_mode_bin[0]};
    assign O_extended_mode = S_extended_mode;

    // Synchronize the mechanical input and accept a new state only after it
    // has remained unchanged for the debounce interval.
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_key_sync_1d  <= 1'b1;
            S_key_sync_2d  <= 1'b1;
            S_key_stable   <= 1'b1;
            S_debounce_cnt <= 24'd0;
        end
        else begin
            S_key_sync_1d <= I_key_in;
            S_key_sync_2d <= S_key_sync_1d;

            if(S_key_sync_2d != S_key_stable) begin
                if(S_debounce_cnt < DEBOUNCE_CYCLES - 1)
                    S_debounce_cnt <= S_debounce_cnt + 1'b1;
                else begin
                    S_key_stable   <= S_key_sync_2d;
                    S_debounce_cnt <= 24'd0;
                end
            end
            else
                S_debounce_cnt <= 24'd0;
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_key_stable_1d <= 1'b1;
        else
            S_key_stable_1d <= S_key_stable;
    end

    // Count only the debounced press interval. The decision is made on
    // release, which prevents a long press from producing a short-press
    // action before the long-press threshold has been reached.
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_press_cnt   <= 25'd0;
            S_long_seen   <= 1'b0;
            S_extended_mode <= 1'b0;
            O_mode_bin    <= 2'b00;
        end
        else begin
            if(S_press_event) begin
                S_press_cnt <= 25'd0;
                S_long_seen <= 1'b0;
            end
            else if(!S_key_stable) begin
                if(S_press_cnt < LONG_PRESS_CYCLES)
                    S_press_cnt <= S_press_cnt + 1'b1;
                if(S_press_cnt >= LONG_PRESS_CYCLES - 1)
                    S_long_seen <= 1'b1;
            end

            if(S_release_event) begin
                S_press_cnt <= 25'd0;
                if(S_long_seen) begin
                    S_extended_mode <= ~S_extended_mode;
                    // Returning to compatibility mode always selects one of
                    // the two already-supported display modes.
                    if(S_extended_mode)
                        O_mode_bin <= {1'b0, O_mode_bin[0]};
                end
                else if(S_extended_mode)
                    O_mode_bin <= O_mode_bin + 2'b01;
                else
                    O_mode_bin <= {1'b0, ~O_mode_bin[0]};
            end
        end
    end

endmodule
