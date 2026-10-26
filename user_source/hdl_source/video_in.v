

module video_in (
    input wire         I_rst_n,

    input wire         I_camera_clk,
    input wire         I_camera_frame_start,
    input wire[2:0]    I_camera_frame_mode,
    input wire         I_camera_valid,
    input wire[127:0]  I_camera_data,
    input wire         I_mipi_rx_error,

    input wire         I_ddr_clk,
    input wire         I_ddr_init_done,

    input wire         I_display_pause,
    input wire         I_video_out_rd_busy,
    output wire        O_video_in_wr_busy,
    output reg[11:0]   O_frame_mode_slots,
    output reg[1:0]    O_video_out_rp,     ///读指针
    output reg[3:0]    O_frame_ready,
    output wire        O_frame_write_start,
    output wire[1:0]   O_frame_write_slot,

    output reg         O_ddr_user_wr_en,
    output reg[24:0]   O_ddr_user_addr,
    output wire[127:0] O_ddr_user_wr_data,
    input wire         I_ddr_user_ready
);

    wire        S_fifo_rst;
    reg         S_camera_frame_start_extend; ///脉冲展宽，同步到ddr_clk时钟域
    reg[3:0]    S_extend_cnt;
    reg         S_camera_frame_start_extend_1d;
    reg         S_camera_frame_start_extend_2d;
    reg         S_camera_frame_start_extend_3d;
    wire        S_frame_start;
    reg[1:0]    S_video_in_wp;       ///写指针
    wire[8:0]   S_fifo_rd_num;      
    wire        S_fifo_rd_en;   
    wire        S_fifo_rd_valid;
    wire[127:0] S_fifo_rd_data; 
    reg         S_ddr_wr_valid;
    reg[9:0]    S_ddr_wr_cnt;
    reg[17:0]   S_frame_word_cnt;
    reg[1:0]    S_active_wr_frame;
    reg[2:0]    S_camera_frame_mode_bin;
    reg[2:0]    S_camera_frame_mode_gray_1d;
    reg[2:0]    S_camera_frame_mode_gray_2d;
    wire[2:0]   S_camera_frame_mode_gray;
    wire[2:0]   S_camera_frame_mode_ddr;

    localparam FRAME_WORDS = 18'd172800;
    localparam IMAGE_BASE_ADDR_0 = 25'd0;
    localparam IMAGE_BASE_ADDR_1 = 25'd7000000;
    localparam IMAGE_BASE_ADDR_2 = 25'd14000000;
    localparam IMAGE_BASE_ADDR_3 = 25'd21000000;

    // One 128-bit word contains four RGB pixels: 1280*720/4 = 172800 words.
    // Four non-overlapping regions leave the writer and reader on separate
    // frame slots while DDR traffic is still draining.

    // Reset the asynchronous input FIFO only from the global active-low
    // reset. Resetting it on every frame start can erase the first line
    // when frame_start and the first valid beat are adjacent.
    assign S_fifo_rst = ~I_rst_n;

    assign S_camera_frame_mode_gray = {
        S_camera_frame_mode_bin[2],
        S_camera_frame_mode_bin[2] ^ S_camera_frame_mode_bin[1],
        S_camera_frame_mode_bin[1] ^ S_camera_frame_mode_bin[0]
    };
    assign S_camera_frame_mode_ddr = {
        S_camera_frame_mode_gray_2d[2],
        S_camera_frame_mode_gray_2d[2] ^ S_camera_frame_mode_gray_2d[1],
        S_camera_frame_mode_gray_2d[2] ^ S_camera_frame_mode_gray_2d[1] ^
        S_camera_frame_mode_gray_2d[0]
    };

    // S_ddr_wr_valid is the ownership flag for the complete DDR write burst.
    // O_ddr_user_wr_en is registered one cycle after S_fifo_rd_en; including it
    // here bridges the only idle cycle between consecutive 240-beat bursts.
    // With a continuous 1080p stream that kept wr_busy permanently asserted and
    // starved video_out, so no DDR read request could ever start.
    assign O_video_in_wr_busy = S_ddr_wr_valid;

    w128_d512_fifo U_w128_d512_fifo(
        .rst        ( S_fifo_rst         ),   

        .clkw       ( I_camera_clk       ),     
        .we         ( I_camera_valid     ),
        .di         ( I_camera_data      ),
        .afull      (),
        .full_flag  (),
        .wrusedw    (),
 
        .clkr       ( I_ddr_clk          ),
        .re         ( S_fifo_rd_en       ), 
        .dout       ( O_ddr_user_wr_data ),  
        .rdusedw    ( S_fifo_rd_num      ),
        .valid      (), 
        .empty_flag (),
        .aempty     ()
    );


    always @(posedge I_camera_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_camera_frame_start_extend <= 1'b0;
        else
            if(I_camera_frame_start)
                S_camera_frame_start_extend <= 1'b1;
            else if(S_extend_cnt == 'd7)
                S_camera_frame_start_extend <= 1'b0;
            else
                S_camera_frame_start_extend <= S_camera_frame_start_extend;
    end

    always @(posedge I_camera_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_camera_frame_mode_bin <= 3'd0;
        else if(I_camera_frame_start)
            S_camera_frame_mode_bin <= I_camera_frame_mode;
    end

	
    always @ (posedge I_camera_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_extend_cnt <= 'd0;
        else if(S_camera_frame_start_extend)
            S_extend_cnt <= S_extend_cnt + 'd1;
        else
            S_extend_cnt <= 'd0;
    end


    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_camera_frame_start_extend_1d <= 1'b0;
            S_camera_frame_start_extend_2d <= 1'b0;
            S_camera_frame_start_extend_3d <= 1'b0;
        end else begin
            S_camera_frame_start_extend_1d <= S_camera_frame_start_extend;
            S_camera_frame_start_extend_2d <= S_camera_frame_start_extend_1d;
            S_camera_frame_start_extend_3d <= S_camera_frame_start_extend_2d;
        end
    end

    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_camera_frame_mode_gray_1d <= 3'd0;
            S_camera_frame_mode_gray_2d <= 3'd0;
        end else begin
            S_camera_frame_mode_gray_1d <= S_camera_frame_mode_gray;
            S_camera_frame_mode_gray_2d <= S_camera_frame_mode_gray_1d;
        end
    end

    assign S_frame_start = ~S_camera_frame_start_extend_3d & S_camera_frame_start_extend_2d;
    assign O_frame_write_start = S_frame_start && !I_display_pause &&
                                 I_ddr_init_done && !I_mipi_rx_error;
    assign O_frame_write_slot = S_video_in_wp;

	/*
		如果前一帧图像有误少行了，那么地址回退为之前的，覆盖有问题的那帧图像
	*/
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_video_in_wp <= 'd0;
        else
            if(I_display_pause || !I_ddr_init_done)
                S_video_in_wp <= S_video_in_wp;
            else if(S_frame_start)
                begin
                    if(I_mipi_rx_error)
                        S_video_in_wp <= S_video_in_wp;
                    else
                        S_video_in_wp <= S_video_in_wp + 'd1;
                end
            else
                S_video_in_wp <= S_video_in_wp;
    end


    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            O_video_out_rp <= 'd0;
        else
            if(I_display_pause || !I_ddr_init_done)
                O_video_out_rp <= O_video_out_rp;
            else if(S_frame_start)
                begin
                    case(S_video_in_wp)
                        'd0: O_video_out_rp <= 'd2;
                        'd1: O_video_out_rp <= 'd3;
                        'd2: O_video_out_rp <= 'd0;
                        'd3: O_video_out_rp <= 'd1;
                    endcase
                end
            else
                O_video_out_rp <= O_video_out_rp;
    end

    // A frame becomes readable only after all 172800 128-bit words have
    // entered the DDR request path.  The existing four-frame rotation keeps
    // the display two frames behind the writer, allowing pending DDR writes
    // to drain before the frame is selected.
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_frame_word_cnt <= 'd0;
            S_active_wr_frame <= 'd0;
            O_frame_ready <= 4'b0000;
            O_frame_mode_slots <= 12'd0;
        end else if(!I_ddr_init_done) begin
            S_frame_word_cnt <= 'd0;
            S_active_wr_frame <= 'd0;
            O_frame_ready <= 4'b0000;
            O_frame_mode_slots <= 12'd0;
        end else begin
            if(S_frame_start && !I_display_pause && !I_mipi_rx_error) begin
                S_active_wr_frame <= S_video_in_wp;
                S_frame_word_cnt <= 'd0;
                case(S_video_in_wp)
                    2'd0: begin
                        O_frame_ready[0] <= 1'b0;
                        O_frame_mode_slots[2:0] <= S_camera_frame_mode_ddr;
                    end
                    2'd1: begin
                        O_frame_ready[1] <= 1'b0;
                        O_frame_mode_slots[5:3] <= S_camera_frame_mode_ddr;
                    end
                    2'd2: begin
                        O_frame_ready[2] <= 1'b0;
                        O_frame_mode_slots[8:6] <= S_camera_frame_mode_ddr;
                    end
                    2'd3: begin
                        O_frame_ready[3] <= 1'b0;
                        O_frame_mode_slots[11:9] <= S_camera_frame_mode_ddr;
                    end
                endcase
            end

            if(O_ddr_user_wr_en) begin
                if(S_frame_word_cnt == FRAME_WORDS - 1'b1) begin
                    case(S_active_wr_frame)
                        2'd0: O_frame_ready[0] <= 1'b1;
                        2'd1: O_frame_ready[1] <= 1'b1;
                        2'd2: O_frame_ready[2] <= 1'b1;
                        2'd3: O_frame_ready[3] <= 1'b1;
                    endcase
                    S_frame_word_cnt <= 'd0;
                end else begin
                    S_frame_word_cnt <= S_frame_word_cnt + 1'b1;
                end
            end
        end
    end

    /*
        fifo的深度是512，实际的深度是510，因此需要注意每次读出的长度避免为256，否则连续两次读写会引起fifo读空，丢失数据
    */
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_ddr_wr_valid <= 1'b0;
        else
            if(!I_ddr_init_done)
                S_ddr_wr_valid <= 1'b0;
            else if(S_ddr_wr_valid && I_ddr_user_ready && S_ddr_wr_cnt == 'd239)
                S_ddr_wr_valid <= 1'b0;
            else if(S_fifo_rd_num >= 'd240 && (!I_video_out_rd_busy) &&
                    (!S_fifo_rst) && I_ddr_init_done)
                S_ddr_wr_valid <= 1'b1;
            else
                S_ddr_wr_valid <= S_ddr_wr_valid;
    end

    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_ddr_wr_cnt <= 'd0;
        else if(S_ddr_wr_valid)
            begin
                if(I_ddr_user_ready)
                    S_ddr_wr_cnt <= S_ddr_wr_cnt + 'd1;
                else
                    S_ddr_wr_cnt <= S_ddr_wr_cnt;
            end
        else
            S_ddr_wr_cnt <= 'd0;
    end

    assign S_fifo_rd_en = S_ddr_wr_valid & I_ddr_user_ready &
                          I_ddr_init_done;

    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            O_ddr_user_wr_en <= 1'b0;
        else
            O_ddr_user_wr_en <= S_fifo_rd_en;
    end

	/*
		如果前一帧图像有误少行了，那么地址回退为之前的，覆盖有问题的那帧图像
	*/
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            O_ddr_user_addr <= 1'b0;
        else
            if(S_frame_start && I_ddr_init_done && (!I_mipi_rx_error))
                begin
                    case(S_video_in_wp)
                        'd0: O_ddr_user_addr <= IMAGE_BASE_ADDR_0;
                        'd1: O_ddr_user_addr <= IMAGE_BASE_ADDR_1;
                        'd2: O_ddr_user_addr <= IMAGE_BASE_ADDR_2;
                        'd3: O_ddr_user_addr <= IMAGE_BASE_ADDR_3;
                    endcase
                end
            else if(S_frame_start && I_ddr_init_done && I_mipi_rx_error)
				begin
                	case(S_video_in_wp)
                        'd0: O_ddr_user_addr <= IMAGE_BASE_ADDR_3;
                        'd1: O_ddr_user_addr <= IMAGE_BASE_ADDR_0;
                        'd2: O_ddr_user_addr <= IMAGE_BASE_ADDR_1;
                        'd3: O_ddr_user_addr <= IMAGE_BASE_ADDR_2;
                    endcase
                end
            else if(O_ddr_user_wr_en)
                O_ddr_user_addr <= O_ddr_user_addr + 'd8;
            else    
                O_ddr_user_addr <= O_ddr_user_addr;
    end

    
endmodule
