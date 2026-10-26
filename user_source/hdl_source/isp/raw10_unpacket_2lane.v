// RAW10 unpacker: four 10-bit pixels are emitted as one 40-bit beat.
// Payload alignment is preserved in the same clock domain as the CSI parser.
module raw10_unpacket_2lane (
    input  wire        I_clk,
    input  wire        I_rst_n,

    input  wire        I_csi_frame_start,
    input  wire        I_csi_frame_end,
    input  wire        I_csi_valid,
    input  wire [31:0] I_csi_data,
    input  wire [9:0]  I_camera_black_level,

    output reg         O_raw10_frame_start,
    output reg         O_raw10_frame_end,
    output reg         O_raw10_valid,
    output reg  [39:0] O_raw10_data
);

    reg        S_csi_valid_1d;
    reg        S_csi_valid_2d;
    reg [31:0] S_csi_data_1d;
    reg [31:0] S_csi_data_2d;
    reg [2:0]  S_cnt;
    reg        S_raw10_wr_en;
    reg [39:0] S_raw10_wr_data;

    // The CSI parser produces a 32-bit valid pulse on alternating cycles.
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            O_raw10_frame_start <= 1'b0;
            O_raw10_frame_end   <= 1'b0;
            S_csi_valid_1d      <= 1'b0;
            S_csi_valid_2d      <= 1'b0;
            S_csi_data_1d       <= 32'd0;
            S_csi_data_2d       <= 32'd0;
        end
        else begin
            O_raw10_frame_start <= I_csi_frame_start;
            O_raw10_frame_end   <= I_csi_frame_end;
            S_csi_valid_1d      <= I_csi_valid;
            S_csi_valid_2d      <= S_csi_valid_1d;
            S_csi_data_1d       <= I_csi_data;
            S_csi_data_2d       <= S_csi_data_1d;
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n)
            S_cnt <= 3'd0;
        else if ({S_csi_valid_2d, S_csi_valid_1d, I_csi_valid} == 3'b101) begin
            if (S_cnt == 3'd4)
                S_cnt <= 3'd0;
            else
                S_cnt <= S_cnt + 3'd1;
        end
        else if ({S_csi_valid_2d, S_csi_valid_1d, I_csi_valid} == 3'b000)
            S_cnt <= 3'd0;
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            S_raw10_wr_en   <= 1'b0;
            S_raw10_wr_data <= 40'd0;
        end
        else if ({S_csi_valid_2d, S_csi_valid_1d, I_csi_valid} == 3'b101) begin
            case (S_cnt)
                3'd0: begin
                    S_raw10_wr_en          <= 1'b1;
                    S_raw10_wr_data[39:30] <= {S_csi_data_2d[31:24],
                                                I_csi_data[25:24]};
                    S_raw10_wr_data[29:20] <= {S_csi_data_2d[23:16],
                                                I_csi_data[27:26]};
                    S_raw10_wr_data[19:10] <= {S_csi_data_2d[15:8],
                                                I_csi_data[29:28]};
                    S_raw10_wr_data[9:0]   <= {S_csi_data_2d[7:0],
                                                I_csi_data[31:30]};
                end
                3'd1: begin
                    S_raw10_wr_en          <= 1'b1;
                    S_raw10_wr_data[39:30] <= {S_csi_data_2d[23:16],
                                                I_csi_data[17:16]};
                    S_raw10_wr_data[29:20] <= {S_csi_data_2d[15:8],
                                                I_csi_data[19:18]};
                    S_raw10_wr_data[19:10] <= {S_csi_data_2d[7:0],
                                                I_csi_data[21:20]};
                    S_raw10_wr_data[9:0]   <= {I_csi_data[31:24],
                                                I_csi_data[23:22]};
                end
                3'd2: begin
                    S_raw10_wr_en          <= 1'b1;
                    S_raw10_wr_data[39:30] <= {S_csi_data_2d[15:8],
                                                I_csi_data[9:8]};
                    S_raw10_wr_data[29:20] <= {S_csi_data_2d[7:0],
                                                I_csi_data[11:10]};
                    S_raw10_wr_data[19:10] <= {I_csi_data[31:24],
                                                I_csi_data[13:12]};
                    S_raw10_wr_data[9:0]   <= {I_csi_data[23:16],
                                                I_csi_data[15:14]};
                end
                3'd3: begin
                    S_raw10_wr_en          <= 1'b1;
                    S_raw10_wr_data[39:30] <= {S_csi_data_2d[7:0],
                                                I_csi_data[1:0]};
                    S_raw10_wr_data[29:20] <= {I_csi_data[31:24],
                                                I_csi_data[3:2]};
                    S_raw10_wr_data[19:10] <= {I_csi_data[23:16],
                                                I_csi_data[5:4]};
                    S_raw10_wr_data[9:0]   <= {I_csi_data[15:8],
                                                I_csi_data[7:6]};
                end
                default: begin
                    S_raw10_wr_en   <= 1'b0;
                    S_raw10_wr_data <= 40'd0;
                end
            endcase
        end
        else begin
            S_raw10_wr_en   <= 1'b0;
            S_raw10_wr_data <= 40'd0;
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            O_raw10_data  <= 40'd0;
            O_raw10_valid <= 1'b0;
        end
        else begin
            O_raw10_data <= {S_raw10_wr_data[9:0],
                             S_raw10_wr_data[19:10],
                             S_raw10_wr_data[29:20],
                             S_raw10_wr_data[39:30]};
            O_raw10_valid <= S_raw10_wr_en;
        end
    end

endmodule
