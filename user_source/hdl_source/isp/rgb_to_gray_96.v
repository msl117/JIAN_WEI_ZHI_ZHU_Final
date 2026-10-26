module rgb_to_gray_96 (
    input             I_clk,
    input             I_rst_n,

    input             I_tlast,
    input             I_tuser,
    input      [95:0] I_tdata,
    input             I_tvalid,
    output            I_tready,

    output            O_tlast,
    output            O_tuser,
    output     [95:0] O_tdata,
    output            O_tvalid,
    input             O_tready
);

    reg         S_tvalid;
    reg         S_tlast;
    reg         S_tuser;
    reg  [95:0] S_tdata;

    wire [7:0] S_r0;
    wire [7:0] S_g0;
    wire [7:0] S_b0;
    wire [7:0] S_r1;
    wire [7:0] S_g1;
    wire [7:0] S_b1;
    wire [7:0] S_r2;
    wire [7:0] S_g2;
    wire [7:0] S_b2;
    wire [7:0] S_r3;
    wire [7:0] S_g3;
    wire [7:0] S_b3;

    assign S_r0 = I_tdata[23:16];
    assign S_g0 = I_tdata[15:8];
    assign S_b0 = I_tdata[7:0];

    assign S_r1 = I_tdata[47:40];
    assign S_g1 = I_tdata[39:32];
    assign S_b1 = I_tdata[31:24];

    assign S_r2 = I_tdata[71:64];
    assign S_g2 = I_tdata[63:56];
    assign S_b2 = I_tdata[55:48];

    assign S_r3 = I_tdata[95:88];
    assign S_g3 = I_tdata[87:80];
    assign S_b3 = I_tdata[79:72];

    function [7:0] rgb_to_gray;
        input [7:0] I_r;
        input [7:0] I_g;
        input [7:0] I_b;
        reg  [15:0] S_sum;
        begin
            // Y = 0.299R + 0.587G + 0.114B, rounded to 8 bits.
            S_sum = I_r * 8'd77
                  + I_g * 8'd150
                  + I_b * 8'd29
                  + 16'd128;
            rgb_to_gray = S_sum[15:8];
        end
    endfunction

    assign I_tready = (~S_tvalid) | O_tready;

    assign O_tvalid = S_tvalid;
    assign O_tlast  = S_tlast;
    assign O_tuser  = S_tuser;
    assign O_tdata  = S_tdata;

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            S_tvalid <= 1'b0;
            S_tlast  <= 1'b0;
            S_tuser  <= 1'b0;
            S_tdata  <= 96'd0;
        end else if (I_tready) begin
            if (I_tvalid) begin
                S_tvalid <= 1'b1;
                S_tlast  <= I_tlast;
                S_tuser  <= I_tuser;
                S_tdata  <= {
                    rgb_to_gray(S_r3, S_g3, S_b3),
                    rgb_to_gray(S_r3, S_g3, S_b3),
                    rgb_to_gray(S_r3, S_g3, S_b3),
                    rgb_to_gray(S_r2, S_g2, S_b2),
                    rgb_to_gray(S_r2, S_g2, S_b2),
                    rgb_to_gray(S_r2, S_g2, S_b2),
                    rgb_to_gray(S_r1, S_g1, S_b1),
                    rgb_to_gray(S_r1, S_g1, S_b1),
                    rgb_to_gray(S_r1, S_g1, S_b1),
                    rgb_to_gray(S_r0, S_g0, S_b0),
                    rgb_to_gray(S_r0, S_g0, S_b0),
                    rgb_to_gray(S_r0, S_g0, S_b0)
                };
            end else begin
                S_tvalid <= 1'b0;
                S_tlast  <= 1'b0;
                S_tuser  <= 1'b0;
                S_tdata  <= 96'd0;
            end
        end
    end

endmodule
