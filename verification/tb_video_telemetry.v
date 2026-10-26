`timescale 1ns/1ps

module tb_video_telemetry;
    reg camera_clk = 0;
    reg ddr_clk = 0;
    reg rst_n = 0;
    reg camera_start = 0;
    reg write_start = 0;
    reg [1:0] write_slot = 0;
    reg display_start = 0;
    reg [1:0] display_slot = 0;
    reg display_ready = 0;
    wire [11:0] latency_ms;
    wire latency_valid;
    wire [7:0] fps_bcd;
    wire update_toggle;

    always #5 camera_clk = ~camera_clk;
    always #5 ddr_clk = ~ddr_clk;

    video_telemetry #(.DDR_CLK_HZ(1000000)) dut (
        .I_camera_clk(camera_clk),
        .I_camera_frame_start(camera_start),
        .I_ddr_clk(ddr_clk),
        .I_rst_n(rst_n),
        .I_write_start(write_start),
        .I_write_slot(write_slot),
        .I_display_start(display_start),
        .I_display_slot(display_slot),
        .I_display_ready(display_ready),
        .O_latency_ms(latency_ms),
        .O_latency_valid(latency_valid),
        .O_camera_fps_bcd(fps_bcd),
        .O_update_toggle(update_toggle)
    );

    task camera_frame;
        begin
            @(negedge camera_clk);
            camera_start = 1;
            @(negedge camera_clk);
            camera_start = 0;
            repeat (6) @(negedge ddr_clk);
        end
    endtask

    task write_frame;
        input [1:0] slot;
        begin
            @(negedge ddr_clk);
            write_slot = slot;
            write_start = 1;
            @(negedge ddr_clk);
            write_start = 0;
        end
    endtask

    task display_frame;
        input [1:0] slot;
        input ready;
        begin
            @(negedge ddr_clk);
            display_slot = slot;
            display_ready = ready;
            display_start = 1;
            @(negedge ddr_clk);
            display_start = 0;
            #1;
        end
    endtask

    initial begin
        repeat (5) @(negedge ddr_clk);
        rst_n = 1;
        display_frame(2'd1, 1'b1);
        if (latency_valid !== 1'b0) $fatal(1, "empty slot must be invalid");

        camera_frame();
        write_frame(2'd2);
        repeat (3200) @(negedge ddr_clk);
        display_frame(2'd2, 1'b1);
        if (latency_valid !== 1'b1 || latency_ms < 12'd3 ||
            latency_ms > 12'd4)
            $fatal(1, "slot latency mismatch: valid=%b ms=%d",
                   latency_valid, latency_ms);

        display_frame(2'd2, 1'b0);
        if (latency_valid !== 1'b0)
            $fatal(1, "unready display slot must be invalid");

        camera_frame();
        write_frame(2'd3);
        repeat (1200) @(negedge ddr_clk);
        display_frame(2'd2, 1'b1);
        if (latency_valid !== 1'b1 || latency_ms < 12'd4)
            $fatal(1, "older slot timestamp was overwritten");
        display_frame(2'd3, 1'b1);
        if (latency_valid !== 1'b1 || latency_ms < 12'd1 ||
            latency_ms > 12'd2)
            $fatal(1, "new slot timestamp mismatch");

        repeat (1000000) @(negedge ddr_clk);
        if (fps_bcd !== 8'h02)
            $fatal(1, "camera FPS should be two: %h", fps_bcd);
        repeat (1000000) @(negedge ddr_clk);
        if (fps_bcd !== 8'h00)
            $fatal(1, "stopped camera FPS should be zero: %h", fps_bcd);
        $display("PASS telemetry: slot pairing, invalid slot, 2/0 FPS");
        $finish;
    end
endmodule
