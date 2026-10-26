// Adds AXI4-Stream-style frame/line markers to the native RAW10 beat stream.
// This converter is intentionally valid-only; the current ISP path is
// continuous and has no downstream ready signal at this boundary.
module uial2axis #(
    parameter IMG_WIDTH        = 1280,
    parameter IMG_HEIGHT       = 720,
    parameter INPUT_DATA_WIDTH = 128
) (
    input  I_native_clk,
    input  I_rst_n,

    input  [INPUT_DATA_WIDTH-1:0] I_data,
    input                         I_data_valid,
    input                         I_data_start,
    input                         I_data_end,

    output                         axis_tvalid,
    output [INPUT_DATA_WIDTH-1:0] axis_tdata,
    output                         axis_tuser,
    output                         axis_tlast
);

    localparam IMG_WIDTH_4X = (IMG_WIDTH >> 2);

    reg [13:0] hcnt;
    reg [13:0] vcnt;

    assign axis_tdata  = I_data_valid ? I_data : {INPUT_DATA_WIDTH{1'b0}};
    assign axis_tvalid = I_data_valid;
    assign axis_tlast  = (hcnt == IMG_WIDTH_4X - 1) && axis_tvalid;
    assign axis_tuser  = (vcnt == 0) && (hcnt == 0) && axis_tvalid;

    // Match the reference stream formatter: a frame-start marker is the
    // authoritative point for resetting the image coordinates. The frame-end
    // packet arrives after the last line and must not reset counters early.
    always @(posedge I_native_clk or negedge I_rst_n) begin
        if (!I_rst_n || I_data_start)
            hcnt <= 14'd0;
        else if (I_data_valid && (hcnt < IMG_WIDTH_4X - 1))
            hcnt <= hcnt + 14'd1;
        else if (I_data_valid && (hcnt == IMG_WIDTH_4X - 1))
            hcnt <= 14'd0;
    end

    always @(posedge I_native_clk or negedge I_rst_n) begin
        if (!I_rst_n || I_data_start)
            vcnt <= 14'd0;
        else if (axis_tlast && (vcnt == IMG_HEIGHT - 1))
            vcnt <= 14'd0;
        else if (axis_tlast && (vcnt < IMG_HEIGHT - 1))
            vcnt <= vcnt + 14'd1;
    end

endmodule
