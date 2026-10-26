`timescale 1ns/1ps

module tb_awb_switch;
    reg clk = 0;
    reg rst_n = 0;
    reg awb_enable = 1;
    reg tuser = 0;
    reg tvalid = 1;
    wire [95:0] tdata_out;
    wire tvalid_out;

    always #5 clk = ~clk;

    awb dut (
        .I_clk(clk), .I_rst_n(rst_n), .I_awb_enable(awb_enable),
        .I_tlast(1'b0), .I_tuser(tuser),
        .I_tdata({4{24'h202020}}), .I_tvalid(tvalid), .I_tready(),
        .O_tlast(), .O_tuser(), .O_tdata(tdata_out),
        .O_tvalid(tvalid_out), .O_tready(1'b1)
    );

    task frame_start;
        begin
            @(negedge clk) tuser = 1;
            @(negedge clk) tuser = 0;
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1;
        frame_start();
        repeat (5) @(negedge clk);
        if (dut.in_r_r1 !== 20'h20000 || dut.in_b_r1 !== 20'h20000)
            $fatal(1,"enabled gains missing");
        awb_enable = 0;
        repeat (5) @(negedge clk);
        if (dut.in_r_r1 !== 20'h20000)
            $fatal(1,"switch changed AWB mid-frame");
        frame_start();
        repeat (5) @(negedge clk);
        if (dut.in_r_r1 !== 20'h10000 || dut.in_b_r1 !== 20'h10000)
            $fatal(1,"AWB bypass did not select unity gain");
        awb_enable = 1;
        repeat (5) @(negedge clk);
        if (dut.in_r_r1 !== 20'h10000)
            $fatal(1,"AWB bypass changed mid-frame");
        frame_start();
        repeat (5) @(negedge clk);
        if (dut.in_r_r1 !== 20'h20000)
            $fatal(1,"AWB did not re-enable");
        $display("tb_awb_switch PASS");
        $finish;
    end
endmodule

module divider (
    input wire clk,
    input wire rst,
    input wire start,
    input wire [31:0] denominator,
    input wire [47:0] numerator,
    output wire [47:0] quotient,
    output reg done
);
    assign quotient = 48'h0000020000;
    always @(posedge clk or posedge rst)
        if (rst) done <= 0;
        else done <= start;
endmodule

module signal_delay #(
    parameter IMG_HEIGHT = 1080,
    parameter IMG_WIDTH = 1920,
    parameter DATA_WIDTH = 96,
    parameter DELAY_CYCLE = 50
)(
    input wire I_clk,
    input wire I_rst_n,
    input wire I_tuser,
    input wire I_valid,
    input wire [DATA_WIDTH-1:0] I_data,
    output wire O_valid,
    output wire [DATA_WIDTH-1:0] O_data,
    output wire O_tuser
);
    assign O_valid = I_valid;
    assign O_data = I_data;
    assign O_tuser = I_tuser;
endmodule
