`timescale 1ns/1ps

module tb_ae_set_debug_auto;
    reg clk = 0;
    reg rst = 1;
    reg [3:0] btn = 4'hf;
    reg cfg_done = 1;
    reg feature_valid = 0;
    reg object_present = 0;
    reg debug_mode = 0;
    reg meter_valid = 0;
    reg [9:0] meter_luma = 10'd900;
    wire ae_req;
    wire [15:0] ae;
    wire [15:0] ag;
    wire [1:0] mode;
    integer busy_count = 0;
    integer timeout_count;

    always #5 clk = ~clk;

    ae_set #(.GAIN_KEY_DEBOUNCE_CYCLES(2)) dut (
        .I_clk(clk), .I_rst(rst), .I_btn(btn),
        .I_ae_cfg_done(cfg_done), .I_cam_cfg_done(1'b1),
        .I_feature_valid(feature_valid), .I_object_present(object_present),
        .I_debug_mode(debug_mode), .I_meter_valid(meter_valid),
        .I_meter_luma(meter_luma), .O_ae_req(ae_req),
        .O_ae(ae), .O_ag(ag), .O_gain_mode(mode)
    );

    always @(posedge clk) begin
        if (rst) begin
            cfg_done <= 1;
            busy_count <= 0;
        end else if (ae_req) begin
            cfg_done <= 0;
            busy_count <= 3;
        end else if (busy_count != 0) begin
            busy_count <= busy_count - 1;
            if (busy_count == 1)
                cfg_done <= 1;
        end
    end

    task press_gain;
        begin
            @(negedge clk) btn[3] = 0;
            repeat (5) @(negedge clk);
            btn[3] = 1;
            repeat (8) @(negedge clk);
        end
    endtask

    task wait_mode;
        input [1:0] expected;
        begin
            timeout_count = 0;
            while (mode !== expected && timeout_count < 100) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end
            if (mode !== expected) $fatal(1,"mode timeout: %d",expected);
        end
    endtask

    task sample_frame;
        begin
            @(negedge clk) meter_valid = 1;
            @(negedge clk) meter_valid = 0;
            @(negedge clk) feature_valid = 1;
            @(negedge clk) feature_valid = 0;
            repeat (12) @(negedge clk);
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst = 0;
        repeat (12) @(negedge clk);
        press_gain(); wait_mode(2'd1);
        press_gain(); wait_mode(2'd2);
        if (ag !== 16'd176) $fatal(1,"HIGH gain mismatch");
        press_gain(); wait_mode(2'd3);
        object_present = 1;
        debug_mode = 1;
        sample_frame();
        if (ag !== 16'd176) $fatal(1,"DEBUG should hold AUTO");
        debug_mode = 0;
        sample_frame();
        sample_frame();
        if (ag !== 16'd168) $fatal(1,"non-DEBUG AUTO did not step");
        press_gain(); wait_mode(2'd0);
        if (ag !== 16'd144) $fatal(1,"manual LOW was restricted");
        $display("tb_ae_set_debug_auto PASS");
        $finish;
    end
endmodule
