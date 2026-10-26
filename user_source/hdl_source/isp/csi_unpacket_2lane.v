`timescale 1ns / 1ns

// CSI-2 packet parser: converts the D-PHY 16-bit HS stream into 32-bit
// payload words and emits one-cycle frame start/end markers.
module csi_unpacket_2lane (
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_hs_valid,
    input  wire [15:0] I_hs_data,

    output reg         O_csi_frame_start,
    output reg         O_csi_frame_end,
    output reg         O_csi_valid,
    output reg         O_csi_hs,
    output reg  [31:0] O_csi_data
);

    localparam [7:0] FRAME_DATA_DT  = 8'h2b;
    localparam [7:0] FRAME_START_DT = 8'h00;
    localparam [7:0] FRAME_END_DT   = 8'h01;

    reg        S_hs_valid_1d;
    reg [15:0] S_hs_data_1d;
    wire       S_head_en;
    reg        S_head_en_1d;
    reg [15:0] S_data_length;
    reg        S_data_en;
    reg [15:0] S_data_en_cnt;
    reg        csi_valid_r;

    assign S_head_en = ~S_hs_valid_1d & I_hs_valid;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            S_hs_valid_1d <= 1'b0;
            S_hs_data_1d  <= 16'd0;
            S_head_en_1d  <= 1'b0;
        end
        else begin
            S_hs_valid_1d <= I_hs_valid;
            S_hs_data_1d  <= I_hs_data;
            S_head_en_1d  <= S_head_en;
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n)
            O_csi_frame_start <= 1'b0;
        else
            O_csi_frame_start <= S_head_en_1d &&
                                 (S_hs_data_1d[15:8] == FRAME_START_DT);
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n)
            O_csi_frame_end <= 1'b0;
        else
            O_csi_frame_end <= S_head_en_1d &&
                               (S_hs_data_1d[15:8] == FRAME_END_DT);
    end

    // The four CSI header bytes arrive as two 16-bit cycles.
    // Convert the byte count to the number of 16-bit input cycles.
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n)
            S_data_length <= 16'd0;
        else if (I_hs_valid) begin
            if (S_head_en_1d &&
                (S_hs_data_1d[15:8] == FRAME_DATA_DT))
                S_data_length <= {I_hs_data[15:8],
                                  S_hs_data_1d[7:0]} >> 1;
        end
        else
            S_data_length <= 16'd0;
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n)
            S_data_en <= 1'b0;
        else if (S_head_en_1d &&
                 (S_hs_data_1d[15:8] == FRAME_DATA_DT))
            S_data_en <= 1'b1;
        else if ((S_data_length == 16'd0) ||
                 (S_data_en_cnt == S_data_length - 16'd1))
            S_data_en <= 1'b0;
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n)
            S_data_en_cnt <= 16'd0;
        else if (S_data_en)
            S_data_en_cnt <= S_data_en_cnt + 16'd1;
        else
            S_data_en_cnt <= 16'd0;
    end

    // Preserve the example's 16-bit-to-32-bit packing cadence:
    // one 32-bit valid pulse for every two valid 16-bit input cycles.
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            csi_valid_r <= 1'b0;
            O_csi_valid <= 1'b0;
            O_csi_hs    <= 1'b0;
            O_csi_data  <= 32'd0;
        end
        else begin
            csi_valid_r <= S_data_en ? ~csi_valid_r : 1'b0;
            O_csi_valid <= csi_valid_r;
            O_csi_hs    <= I_hs_valid;
            O_csi_data  <= S_data_en ? {O_csi_data[15:0], I_hs_data}
                                     : 32'd0;
        end
    end

endmodule
