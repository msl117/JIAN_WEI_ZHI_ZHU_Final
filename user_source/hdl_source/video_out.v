


module video_out (
    input wire        I_rst_n,

    input wire        I_ddr_clk,
    input wire        I_ddr_init_done,
    output wire       O_video_out_rd_busy,  
    input wire        I_video_in_wr_busy,   
    input wire[1:0]   I_video_out_rp,
    input wire[3:0]   I_frame_ready,
    input wire[11:0]  I_frame_mode_slots,
    output wire       O_display_frame_start,
    output wire[1:0]  O_display_frame_slot,
    output wire       O_display_frame_ready,
    output wire       O_ddr_user_rd_en,
    output reg[24:0]  O_ddr_user_addr,
    input wire        I_ddr_user_ready,
    input wire        I_ddr_user_rd_valid,
    input wire[127:0] I_ddr_user_rd_data,

    input wire        I_dsi_clk,
    input wire        I_video_vsync,
    input wire        I_video_rd_en,  
    output reg[23:0]  O_vdieo_data,
    output reg[2:0]   O_display_mode
);

    reg         S_fifo_rst;     
    reg[7:0]    S_fifo_rst_cnt;
    wire[8:0]   S_fifo_wr_num;       
    wire        S_fifo_rd_en;        
    wire[127:0] S_fifo_rd_data;      
    reg         S_video_vsync_1d;
    reg         S_video_vsync_2d;
    reg         S_video_vsync_3d;
    wire        S_video_frame_start;   
    wire        S_ddr_rd_trig;       
    reg         S_ddr_rd_valid;      
    reg[9:0]    S_ddr_rd_cnt;        
    reg[3:0]    S_fifo_rd_cnt;       
    reg         S_video_rd_en_1d;
    reg         S_fifo_word_valid;
    reg[3:0]    S_fifo_rd_cnt_1d;     
    reg[127:0]  S_fifo_rd_data_1d;    
	reg         S_fifo_word_valid_1d;
	wire        S_fifo_emtpy;     
    reg         S_read_frame_ready;
    reg[2:0]    S_display_frame_mode_ddr;
    reg[2:0]    S_display_frame_mode_gray_1d;
    reg[2:0]    S_display_frame_mode_gray_2d;
    reg         S_display_frame_mode_toggle_ddr;
    reg         S_display_frame_mode_toggle_1d;
    reg         S_display_frame_mode_toggle_2d;
    reg         S_display_frame_mode_toggle_seen;
    wire[2:0]   S_display_frame_mode_bin;



    localparam IMAGE_BASE_ADDR_0 = 25'd0;
    localparam IMAGE_BASE_ADDR_1 = 25'd7000000;
    localparam IMAGE_BASE_ADDR_2 = 25'd14000000;
    localparam IMAGE_BASE_ADDR_3 = 25'd21000000;

    assign S_display_frame_mode_bin = {
        S_display_frame_mode_gray_2d[2],
        S_display_frame_mode_gray_2d[2] ^ S_display_frame_mode_gray_2d[1],
        S_display_frame_mode_gray_2d[2] ^ S_display_frame_mode_gray_2d[1] ^
        S_display_frame_mode_gray_2d[0]
    };

    // Select the rotating DDR slot at HDMI VSYNC. The reference design
    // starts prefetching after DDR calibration; the FIFO and DDR arbiter
    // provide the buffering needed while a new camera frame is written.

    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_video_vsync_1d <= 1'b0;
            S_video_vsync_2d <= 1'b0;
            S_video_vsync_3d <= 1'b0;
        end else begin
            S_video_vsync_1d <= I_video_vsync;
            S_video_vsync_2d <= S_video_vsync_1d;
            S_video_vsync_3d <= S_video_vsync_2d;
        end
    end

    assign S_video_frame_start = ~S_video_vsync_3d & S_video_vsync_2d;
    assign O_display_frame_start = S_video_frame_start && I_ddr_init_done;
    assign O_display_frame_slot = I_video_out_rp;
    assign O_display_frame_ready = I_frame_ready[I_video_out_rp];

    // Lock one frame slot for the whole HDMI frame. The writer asserts
    // frame_ready only after all 172800 DDR words have been accepted.
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_read_frame_ready <= 1'b0;
        end else if(!I_ddr_init_done) begin
            S_read_frame_ready <= 1'b0;
        end else if(S_video_frame_start) begin
            case(I_video_out_rp)
                2'd0: S_read_frame_ready <= I_frame_ready[0];
                2'd1: S_read_frame_ready <= I_frame_ready[1];
                2'd2: S_read_frame_ready <= I_frame_ready[2];
                2'd3: S_read_frame_ready <= I_frame_ready[3];
            endcase
        end
    end

    // Lock the selected mode to the same DDR frame slot used for this frame.
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_display_frame_mode_ddr <= 3'd0;
            S_display_frame_mode_toggle_ddr <= 1'b0;
        end else if(!I_ddr_init_done) begin
            S_display_frame_mode_ddr <= 3'd0;
            S_display_frame_mode_toggle_ddr <= 1'b0;
        end else if(S_video_frame_start) begin
            case(I_video_out_rp)
                2'd0: S_display_frame_mode_ddr <= I_frame_mode_slots[2:0];
                2'd1: S_display_frame_mode_ddr <= I_frame_mode_slots[5:3];
                2'd2: S_display_frame_mode_ddr <= I_frame_mode_slots[8:6];
                2'd3: S_display_frame_mode_ddr <= I_frame_mode_slots[11:9];
            endcase
            S_display_frame_mode_toggle_ddr <= ~S_display_frame_mode_toggle_ddr;
        end
    end

    // Gray-coded stable-bus CDC into the HDMI pixel clock domain. The toggle
    // identifies the frame boundary, so the decoded bus is consumed only
    // after both synchronized Gray stages have settled.
    always @(posedge I_dsi_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_display_frame_mode_gray_1d <= 3'd0;
            S_display_frame_mode_gray_2d <= 3'd0;
            S_display_frame_mode_toggle_1d <= 1'b0;
            S_display_frame_mode_toggle_2d <= 1'b0;
            S_display_frame_mode_toggle_seen <= 1'b0;
            O_display_mode <= 3'd0;
        end else begin
                S_display_frame_mode_gray_1d <= {
                S_display_frame_mode_ddr[2],
                S_display_frame_mode_ddr[2] ^ S_display_frame_mode_ddr[1],
                S_display_frame_mode_ddr[1] ^ S_display_frame_mode_ddr[0]
            };
            S_display_frame_mode_gray_2d <= S_display_frame_mode_gray_1d;
            S_display_frame_mode_toggle_1d <= S_display_frame_mode_toggle_ddr;
            S_display_frame_mode_toggle_2d <= S_display_frame_mode_toggle_1d;
            if(S_display_frame_mode_toggle_2d != S_display_frame_mode_toggle_seen) begin
                O_display_mode <= S_display_frame_mode_bin;
                S_display_frame_mode_toggle_seen <= S_display_frame_mode_toggle_2d;
            end
        end
    end


    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_fifo_rst <= 1'b1;
        else if(!I_ddr_init_done)
            S_fifo_rst <= 1'b1;
        else
            if(S_video_frame_start)
                S_fifo_rst <= 1'b1;
            else if(S_fifo_rst_cnt == 'd10)
                S_fifo_rst <= 1'b0;
            else
                S_fifo_rst <= S_fifo_rst;
    end


    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_fifo_rst_cnt <= 'd0;
        else if(!I_ddr_init_done)
            S_fifo_rst_cnt <= 'd0;
        else if(S_fifo_rst)
            S_fifo_rst_cnt <= S_fifo_rst_cnt + 'd1;
        else
            S_fifo_rst_cnt <= 'd0;
    end

    /*
        这里需要注意fifo的剩余空间一定要大于将要写入的长度，因为ddr读出的时候会有至少40个时钟周期的延时，
        例如每次从ddr读出240个长度的数据，那么fifo的剩余空间最少要设为280，否则会引起fifo写满丢失数据。
    */
    assign S_ddr_rd_trig = (('d511 - S_fifo_wr_num) >= 'd300) &&
                           (!I_video_in_wr_busy) &&
                           (!S_ddr_rd_valid) &&
                           (!S_fifo_rst) &&
                           S_read_frame_ready &&
                           I_rst_n &&
                           I_ddr_init_done ? 1'b1 : 1'b0;

    /*
        fifo的深度是512，实际的深度是510，因此需要注意每次读出的长度避免为256，否则连续两次写入会引起fifo写满，丢失数据
    */
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_ddr_rd_valid <= 1'b0;
        else if(!I_ddr_init_done)
            S_ddr_rd_valid <= 1'b0;
        else
			if(O_ddr_user_rd_en && S_ddr_rd_cnt == 'd239)
                S_ddr_rd_valid <= 1'b0;
            else if(S_ddr_rd_trig)
                S_ddr_rd_valid <= 1'b1;
            else
                S_ddr_rd_valid <= S_ddr_rd_valid;
    end

    assign O_ddr_user_rd_en = S_ddr_rd_valid & I_ddr_user_ready &
                              I_ddr_init_done;

    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_ddr_rd_cnt <= 'd0;
        else if(S_ddr_rd_valid)
            begin
                if(O_ddr_user_rd_en)
                    S_ddr_rd_cnt <= S_ddr_rd_cnt + 'd1;
                else
                    S_ddr_rd_cnt <= S_ddr_rd_cnt;
            end
        else    
            S_ddr_rd_cnt <= 'd0;
    end


    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            O_ddr_user_addr <= 'd0;
        else
            if(S_video_frame_start && I_ddr_init_done)
                begin
                    // Use the pointer sampled on this VSYNC edge. The DDR
                    // address is then held and incremented for the complete
                    // displayed frame, so it cannot switch slots mid-frame.
                    case(I_video_out_rp)
                        'd0: O_ddr_user_addr <= IMAGE_BASE_ADDR_0;
                        'd1: O_ddr_user_addr <= IMAGE_BASE_ADDR_1;
                        'd2: O_ddr_user_addr <= IMAGE_BASE_ADDR_2;
                        'd3: O_ddr_user_addr <= IMAGE_BASE_ADDR_3;
                    endcase
                end
            else if(O_ddr_user_rd_en)
                O_ddr_user_addr <= O_ddr_user_addr + 'd8;
            else    
                O_ddr_user_addr <= O_ddr_user_addr;
    end

    
    assign O_video_out_rd_busy = S_ddr_rd_trig | S_ddr_rd_valid;


    w128_d512_fifo U_w128_d512_fifo(
        .rst        ( S_fifo_rst          ),   

        .clkw       ( I_ddr_clk           ),     
        .we         ( I_ddr_user_rd_valid && I_ddr_init_done ),
        .di         ( I_ddr_user_rd_data  ),
        .wrusedw    ( S_fifo_wr_num       ),
        .afull      (),
        .full_flag  (),
 
        .clkr       ( I_dsi_clk           ),
        .re         ( S_fifo_rd_en        ), 
        .dout       ( S_fifo_rd_data      ),  
        .rdusedw    (), 
        .valid      (),  
        .empty_flag ( S_fifo_emtpy        ),
        .aempty     ()
    );


    always @(posedge I_dsi_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_fifo_rd_cnt <= 'd0;
            S_fifo_word_valid <= 1'b0;
        end else if(I_video_rd_en) begin
            if((S_fifo_rd_cnt == 'd0) ||
               (S_fifo_rd_cnt == 'd5) ||
               (S_fifo_rd_cnt == 'd10))
                S_fifo_word_valid <= S_fifo_rd_en;
            S_fifo_rd_cnt <= S_fifo_rd_cnt + 'd1;
        end else begin
            S_fifo_rd_cnt <= 'd0;
            S_fifo_word_valid <= 1'b0;
        end
    end

    assign S_fifo_rd_en = (!S_fifo_emtpy) &&
                          (I_video_rd_en && (S_fifo_rd_cnt == 'd0)  ? 1'b1 :
                           I_video_rd_en && (S_fifo_rd_cnt == 'd5)  ? 1'b1 :
                           I_video_rd_en && (S_fifo_rd_cnt == 'd10) ? 1'b1 : 1'b0);

    always @(posedge I_dsi_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_video_rd_en_1d <= 1'b0;
            S_fifo_rd_cnt_1d <= 'd0;
            S_fifo_rd_data_1d <= 'd0;
			S_fifo_word_valid_1d <= 1'b0;
        end else begin
        S_video_rd_en_1d  <= I_video_rd_en;
        S_fifo_rd_cnt_1d  <= S_fifo_rd_cnt;
        S_fifo_rd_data_1d <= S_fifo_rd_data;
		S_fifo_word_valid_1d <= S_fifo_word_valid;
        end
    end

    always @(posedge I_dsi_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            O_vdieo_data <= 24'd0;
        else if(S_video_rd_en_1d && S_fifo_word_valid_1d)
           begin
               case(S_fifo_rd_cnt_1d)
                   'd0: O_vdieo_data  <= S_fifo_rd_data[127:104];
                   'd1: O_vdieo_data  <= S_fifo_rd_data[103:80];
                   'd2: O_vdieo_data  <= S_fifo_rd_data[79:56];
                   'd3: O_vdieo_data  <= S_fifo_rd_data[55:32];
                   'd4: O_vdieo_data  <= S_fifo_rd_data[31:8];
                   'd5: O_vdieo_data  <= {S_fifo_rd_data_1d[7:0],S_fifo_rd_data[127:112]};
                   'd6: O_vdieo_data  <= S_fifo_rd_data[111:88];
                   'd7: O_vdieo_data  <= S_fifo_rd_data[87:64];
                   'd8: O_vdieo_data  <= S_fifo_rd_data[63:40];
                   'd9: O_vdieo_data  <= S_fifo_rd_data[39:16];
                   'd10: O_vdieo_data <= {S_fifo_rd_data_1d[15:0],S_fifo_rd_data[127:120]};
                   'd11: O_vdieo_data <= S_fifo_rd_data[119:96];
                   'd12: O_vdieo_data <= S_fifo_rd_data[95:72];
                   'd13: O_vdieo_data <= S_fifo_rd_data[71:48];
                   'd14: O_vdieo_data <= S_fifo_rd_data[47:24];
                   'd15: O_vdieo_data <= S_fifo_rd_data[23:0];
               endcase
           end
       else
           O_vdieo_data <= 'd0;
   end

    
endmodule
