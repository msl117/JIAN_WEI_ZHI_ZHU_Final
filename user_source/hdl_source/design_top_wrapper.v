

module design_top_wrapper (
    input wire        I_sys_clk,
    input wire        I_rst_n,
      
    output wire       O_cam_scl,
    inout  wire       IO_cam_sda,
    output wire       O_cam_24m,
    output wire       O_cam_rst,
      
    inout wire [3:0]  I_button,
    input wire        I_sw_awb,

    output wire       O_screen_pwm,
    output wire       O_beep,
    output wire       O_servo,
    output wire       O_tmds_ch0_p,
    output wire       O_tmds_ch1_p,
    output wire       O_tmds_ch2_p,
    output wire       O_tmds_clk_p,

    inout wire        IO_rx_clk_pad_n, 
    inout wire        IO_rx_clk_pad_p, 
    inout wire[3:0]   IO_rx_data_pad_n,
    inout wire[3:0]   IO_rx_data_pad_p,

    output wire[12:0] ddr_addr,
    output wire[ 1:0] ddr_ba,
    output wire[ 0:0] ddr_cke,
    output wire[ 0:0] ddr_odt,
    output wire[ 0:0] ddr_cs_n,
    output wire       ddr_ras_n,
    output wire       ddr_cas_n,
    output wire       ddr_we_n,
    output wire[ 0:0] ddr_ck_p,
    output wire[ 0:0] ddr_ck_n,
    inout wire[1:0]   ddr_dm,
    inout wire[15:0]  ddr_dq,
    inout wire[1:0]   ddr_dqs_p,
    inout wire[1:0]   ddr_dqs_n   
);

// Top-level clock ownership:
// MIPI/ISP use S_csi_rx_clk, DDR buffering uses S_ddr_clk, and HDMI/OSD use
// S_hdmi_pixel_clk. The vendor PLL, D-PHY, DDR, and HDMI instances are kept
// as generated/official blocks; only ordinary RTL is connected around them.

    wire        	S_100m_clk;
    wire        	S_24m_clk;
    wire        	S_aux_50m_clk;
	wire        	S_10m_clk;
		
	wire        	S_pll_lock;
    wire        	S_rst_n;
    reg  [17:0] 	S_cam_power_cnt;
    reg         	S_cam_pwdnb;
    reg         	S_cam_i2c_ready;
    (* keep = "true" *) wire [15:0] S_cam_sensor_id;
    (* keep = "true" *) wire        S_cam_sensor_id_ok;
    (* keep = "true" *) wire        S_cam_i2c_error;
    localparam integer CAM_PWDNB_LOW_CYCLES = 23810;  // >= 1 ms at 23.809524 MHz
    localparam integer CAM_I2C_START_CYCLES = 142857; // XSHUTDN release + >= 5 ms
	
	wire [15:0] 	S_ae;
    wire [15:0] 	S_ag;
    wire 			S_cam_cfg_done;
    wire 			S_ae_cfg_done;
    wire 			S_ae_req; 
    reg  [2:0]      S_display_mode_24m;
    reg             S_camera_mode_24m;
    reg  [1:0]      S_roi_mode_24m;
    reg             S_roi_selected_24m;
    reg             S_display_mode_update_pending_24m;
    reg             S_display_mode_update_toggle_24m;
    wire            S_camera_key_pulse;
    wire            S_roi_key_pulse;
    reg  [2:0]      S_display_mode_csi_bus_1d;
    reg  [2:0]      S_display_mode_csi_bus_2d;
    reg             S_display_mode_toggle_csi_1d;
    reg             S_display_mode_toggle_csi_2d;
    reg             S_display_mode_toggle_csi_seen;
    reg  [2:0]      S_display_mode_csi;
    wire [1:0]      S_gain_level_24m;
    wire [9:0]      S_ae_meter_luma_csi;
    wire            S_ae_meter_toggle_csi;
    reg [1:0]       S_ae_meter_toggle_24m_sync;
    reg             S_ae_meter_toggle_24m_seen;
    reg [9:0]       S_ae_meter_luma_24m_1d, S_ae_meter_luma_24m_2d;
    reg [9:0]       S_ae_meter_luma_24m;
    reg             S_ae_meter_valid_24m;
    reg  [1:0]      S_gain_level_bus_24m;
    reg  [1:0]      S_gain_level_last_24m;
    reg             S_gain_level_update_pending_24m;
    reg             S_gain_level_update_toggle_24m;
	
	wire        	S_csi_rx_clk;  
    wire        	S_hs_rx_valid;  
    wire[15:0]  	S_hs_rx_data;   
	wire[1:0]   	S_lane_error;
	
	wire        	S_csi_frame_start;       
	wire        	S_csi_frame_end;         
	wire        	S_csi_valid;             
	wire[31:0]  	S_csi_data;  
		
	wire        	S_raw10_frame_start; 
	wire        	S_raw10_frame_end;   
	wire        	S_raw10_valid;       
	wire [39:0] 	S_raw10_data;
		
	wire 			S_axis_tlast;  
	wire 			S_axis_tuser;  
	wire [39:0]		S_axis_tdata;  
	wire 			S_axis_tvalid; 
	
	wire [39:0]		S_raw_tdata ;
	wire			S_raw_tlast ;
	wire 			S_raw_tvalid;
	wire 			S_raw_tuser ;
	
	wire			S_ISP_O_tready;
	wire [127:0]	S_ISP_O_tdata ;
	wire 			S_ISP_O_tlast ;
	wire 			S_ISP_O_tuser ;
	wire 			S_ISP_O_tvalid; 
    wire [2:0]	S_ISP_O_display_mode;
    wire            S_inspection_object_csi;
    wire            S_inspection_update_toggle_csi;
    wire            S_inspection_feature_toggle_csi;
    wire [19:0]     S_inspection_black_count_csi;
    wire [10:0]     S_inspection_min_x_csi;
    wire [10:0]     S_inspection_max_x_csi;
    wire [10:0]     S_inspection_min_y_csi;
    wire [10:0]     S_inspection_max_y_csi;
    wire            S_shape_update_toggle_csi;
    wire            S_shape_valid_csi;
    wire [1:0]      S_shape_result_code_csi;
    wire [10:0]     S_shape_score_csi;
    wire [8:0]      S_shape_angle_csi;
    wire            S_quality_pair_toggle_csi;
    wire [45:0]     S_quality_pair_payload_csi;
    reg             S_quality_pair_ack_24m;
	

    wire        S_ddr_clk;
    wire        S_hdmi_pixel_clk;
    wire        S_hdmi_serial_clk;
    wire        S_hdmi_rst_n;
    wire        S_video_out_rst_n;
    wire [11:0] S_frame_mode_slots;
    wire [2:0]  S_display_mode_video;


    wire        S_vi_128b_frame_start;
    wire        S_vi_128b_valid;      
    wire[127:0] S_vi_128b_data;    
    
    wire        S_video_out_rd_busy;
    wire        S_video_in_wr_busy; 
    wire[1:0]   S_video_out_rp;     
    wire[3:0]   S_frame_ready;
    wire        S_frame_write_start_ddr;
    wire[1:0]   S_frame_write_slot_ddr;
    wire        S_display_frame_start_ddr;
    wire[1:0]   S_display_frame_slot_ddr;
    wire        S_display_frame_ready_ddr;
    wire[11:0]  S_video_latency_ms_ddr;
    wire        S_video_latency_valid_ddr;
    wire[7:0]   S_camera_fps_bcd_ddr;
    wire        S_video_telemetry_toggle_ddr;
    (* ASYNC_REG = "TRUE" *) reg[1:0] S_video_telemetry_sync_hdmi;
    reg         S_video_telemetry_seen_hdmi;
    reg[20:0]   S_video_telemetry_bus_1d, S_video_telemetry_bus_2d;
    reg[20:0]   S_video_telemetry_hdmi;
    wire[20:0]  S_video_telemetry_ddr = {
        S_video_latency_valid_ddr, S_video_latency_ms_ddr,
        S_camera_fps_bcd_ddr
    };

    wire        S_ddr_user_wr_en;       
    wire        S_ddr_user_rd_en;       
    wire[24:0]  S_ddr_user_addr;        
    wire[127:0] S_ddr_user_wr_data;     
    wire        S_ddr_user_ready;       
    wire        S_ddr_user_rd_valid;    
    wire[127:0] S_ddr_user_rd_data;     

    wire        S_vi_ddr_wr_en;   
    wire[24:0]  S_vi_ddr_wr_addr; 
    wire[127:0] S_vi_ddr_wr_data;
    wire        S_vi_ddr_wr_ready;

    wire        S_vo_ddr_rd_en;   
    wire[24:0]  S_vo_ddr_rd_addr; 
    wire        S_vo_ddr_rd_ready;
    wire        S_vo_dbg_fifo_rst;
    wire        S_vo_dbg_ddr_rd_valid;
    wire        S_vo_dbg_fifo_rd_en;
    wire        S_vo_dbg_fifo_empty;

    wire        S_init_calib_complete; 
    wire[24:0]  S_mc_app_addr;          
    wire[2:0]   S_mc_app_cmd;           
    wire        S_mc_app_en;            
    wire[127:0] S_mc_app_wdf_data;      
    wire        S_mc_app_wdf_end;       
    wire[15:0]  S_mc_app_wdf_mask;      
    wire        S_mc_app_wdf_wren;      
    wire[127:0] S_mc_app_rd_data;       
    wire        S_mc_app_rd_data_end;   
    wire        S_mc_app_rd_data_valid; 
    wire        S_mc_app_rdy;           
    wire        S_mc_app_wdf_rdy;       
    wire        S_mc_dbg_fifo_afull;
    wire        S_mc_dbg_app_rdy;
    wire        S_mc_dbg_wdf_rdy;
    wire        S_mc_dbg_cmd_pop;

    wire        S_hdmi_vsync;
    wire        S_hdmi_hsync;
    wire        S_hdmi_de;
    wire        S_hdmi_user;
    wire        S_hdmi_last;
    wire        S_video_out_vsync;
    wire        S_hdmi_window_rd_en;
    wire        S_hdmi_out_vsync;
    wire        S_hdmi_out_hsync;
    wire        S_hdmi_out_de;
    wire[23:0]  S_hdmi_out_data;

    wire[23:0]  S_video_rd_data;
    reg         S_dbg_raw_seen;
    reg         S_dbg_isp_seen;
    reg         S_dbg_ddr_wr_seen;
    reg         S_dbg_ddr_rd_seen;
    reg         S_dbg_cam_cfg_seen;
    reg         S_dbg_hs_seen;
    reg         S_dbg_csi_seen;
    reg         S_dbg_raw10_seen;
    reg         S_dbg_isp_fs_seen;
    reg         S_dbg_isp_valid_seen;
    reg         S_dbg_ddr_req_seen;
    reg         S_dbg_ddr_ready_seen;
    reg [1:0]   S_dbg_raw_seen_sync;
    reg [1:0]   S_dbg_isp_seen_sync;
    reg [1:0]   S_dbg_ddr_wr_seen_sync;
    reg [1:0]   S_dbg_ddr_rd_seen_sync;
    reg [1:0]   S_dbg_cam_cfg_seen_sync;
    reg [1:0]   S_dbg_hs_seen_sync;
    reg [1:0]   S_dbg_csi_seen_sync;
    reg [1:0]   S_dbg_raw10_seen_sync;
    reg [1:0]   S_dbg_isp_fs_seen_sync;
    reg [1:0]   S_dbg_isp_valid_seen_sync;
    reg [1:0]   S_dbg_ddr_req_seen_sync;
    reg [1:0]   S_dbg_ddr_ready_seen_sync;
    reg         S_dbg_video_nonzero_seen;
    reg         S_dbg_rd_req_seen;
    reg         S_dbg_rd_valid_seen;
    reg         S_dbg_rd_nonzero_seen;
    reg [1:0]   S_dbg_rd_req_seen_sync;
    reg [1:0]   S_dbg_rd_valid_seen_sync;
    reg [1:0]   S_dbg_rd_nonzero_seen_sync;
    reg         S_dbg_mc_init_seen;
    reg         S_dbg_mc_app_rdy_seen;
    reg         S_dbg_mc_wdf_rdy_seen;
    reg         S_dbg_mc_cmd_pop_seen;
    reg [1:0]   S_dbg_mc_init_seen_sync;
    reg [1:0]   S_dbg_mc_app_rdy_seen_sync;
    reg [1:0]   S_dbg_mc_wdf_rdy_seen_sync;
    reg [1:0]   S_dbg_mc_cmd_pop_seen_sync;
    // 720p input-format diagnostics.  One RAW10 line from the factory
    // 1280-pixel mode contains 1600 bytes, i.e. 400 valid 32-bit CSI words.
    reg         S_dbg_hs_valid_d;
    reg [10:0]  S_dbg_csi_words;
    reg [10:0]  S_dbg_good_lines;
    reg         S_dbg_frame_seen_once;
    reg         S_dbg_frame_repeat_seen;
    reg         S_dbg_width_1280_seen;
    reg         S_dbg_height_720_seen;
    reg         S_dbg_isp_frame_seen_once;
    reg         S_dbg_isp_frame_repeat_seen;
    reg [1:0]   S_dbg_frame_repeat_sync;
    reg [1:0]   S_dbg_width_1280_sync;
    reg [1:0]   S_dbg_height_720_sync;
    reg [1:0]   S_dbg_isp_frame_repeat_sync;
    reg [1:0]   S_dbg_cam_i2c_error_sync;
    reg [1:0]   S_dbg_cam_sensor_id_ok_sync;
    wire[3:0]   S_hdmi_debug_status;
    wire        S_lane_error_any;
    wire        defect_alarm;
    wire        S_servo_busy;
    reg         S_beep_active;
    reg [23:0]  S_beep_count;
    reg [12:0]  S_beep_tone_count;
    reg         S_beep_phase;
    reg         S_beep_quality_toggle_seen;
    localparam [23:0] BEEP_CYCLES = 24'd12000000;
    // 24 MHz / (2 * 4000) = approximately 3 kHz for a passive buzzer.
    localparam [12:0] BEEP_HALF_PERIOD = 13'd4000;
    wire        S_calibrate_key_pulse;
    reg         S_shape_calibrate_toggle;
    (* ASYNC_REG = "TRUE" *) reg [2:0] S_shape_calibrate_sync;
    reg         S_shape_calibrate_seen;
    wire        S_shape_calibrate_pulse =
                    S_shape_calibrate_sync[2] ^ S_shape_calibrate_seen;
    reg [1:0]   S_inspection_object_hdmi_sync;
    reg [1:0]   S_inspection_toggle_hdmi_sync;
    reg         S_inspection_toggle_hdmi_seen;
    reg         S_inspection_object_hdmi;
    reg [1:0]   S_inspection_feature_toggle_24m_sync;
    reg         S_inspection_feature_toggle_24m_seen;
    reg         S_inspection_feature_update_24m;
    reg [19:0]  S_inspection_black_count_24m_1d;
    reg [19:0]  S_inspection_black_count_24m_2d;
    reg [10:0]  S_inspection_min_x_24m_1d;
    reg [10:0]  S_inspection_min_x_24m_2d;
    reg [10:0]  S_inspection_max_x_24m_1d;
    reg [10:0]  S_inspection_max_x_24m_2d;
    reg [10:0]  S_inspection_min_y_24m_1d;
    reg [10:0]  S_inspection_min_y_24m_2d;
    reg [10:0]  S_inspection_max_y_24m_1d;
    reg [10:0]  S_inspection_max_y_24m_2d;
    reg         S_inspection_object_24m_1d;
    reg         S_inspection_object_24m_2d;
    reg [19:0]  S_inspection_black_count_24m;
    reg [10:0]  S_inspection_min_x_24m;
    reg [10:0]  S_inspection_max_x_24m;
    reg [10:0]  S_inspection_min_y_24m;
    reg [10:0]  S_inspection_max_y_24m;
    reg         S_inspection_object_24m;
    wire [1:0]  S_inspection_result_code_24m;
    wire        S_inspection_baseline_valid_24m;
    wire [19:0] S_inspection_baseline_count_24m;
    wire [19:0] S_inspection_display_count_24m;
    wire [23:0] S_inspection_display_count_bcd_24m;
    wire        S_inspection_display_toggle_24m;
    reg [1:0]   S_inspection_display_toggle_hdmi_sync;
    reg         S_inspection_display_toggle_hdmi_seen;
    reg [70:0]  S_inspection_payload_hdmi_1d;
    reg [70:0]  S_inspection_payload_hdmi_2d;
    reg [70:0]  S_inspection_payload_hdmi;
    reg [1:0]   S_shape_toggle_24m_sync;
    reg         S_shape_toggle_24m_seen;
    reg [22:0]  S_shape_payload_24m_1d;
    reg [22:0]  S_shape_payload_24m_2d;
    reg [22:0]  S_shape_payload_24m;
    reg         S_shape_payload_toggle_24m;
    reg [1:0]   S_shape_toggle_hdmi_sync;
    reg         S_shape_toggle_hdmi_seen;
    reg [22:0]  S_shape_payload_hdmi_1d;
    reg [22:0]  S_shape_payload_hdmi_2d;
    reg [22:0]  S_shape_payload_hdmi;
    (* ASYNC_REG = "TRUE" *) reg [1:0] S_quality_pair_req_sync;
    reg S_quality_pair_seen, S_quality_pair_pulse_24m;
    reg [45:0] S_quality_pair_24m;
    wire S_quality_valid_24m, S_quality_update_toggle_24m;
    wire [6:0] S_quality_score_24m;
    wire [2:0] S_quality_grade_24m;
    wire [19:0] S_pass_count_bcd_24m, S_fail_count_bcd_24m;
    wire [50:0] S_quality_payload_24m = {
        S_quality_valid_24m,S_quality_score_24m,S_quality_grade_24m,
        S_pass_count_bcd_24m,S_fail_count_bcd_24m
    };
    (* ASYNC_REG = "TRUE" *) reg [1:0] S_quality_toggle_hdmi_sync;
    reg S_quality_toggle_hdmi_seen;
    reg [50:0] S_quality_payload_hdmi;
    wire [70:0] S_inspection_payload_24m = {
        S_inspection_baseline_valid_24m,
        S_inspection_result_code_24m,
        S_inspection_display_count_bcd_24m,
        S_inspection_min_x_24m, S_inspection_max_x_24m,
        S_inspection_min_y_24m, S_inspection_max_y_24m
    };

    assign O_screen_pwm = 1'b1;
    // C12 is active-low. During FAIL, S_beep_phase generates a square wave;
    // outside the alarm window the pin stays high and the buzzer is off.
    assign defect_alarm = S_beep_active;
    assign O_beep       = S_beep_active ? ~S_beep_phase : 1'b1;
    servo_fail_sweeper u_servo_fail_sweeper (
        .I_clk             ( S_24m_clk                  ),
        .I_rst_n           ( S_rst_n                    ),
        .I_result_valid    ( S_quality_valid_24m        ),
        .I_result_grade    ( S_quality_grade_24m        ),
        .I_result_toggle   ( S_quality_update_toggle_24m),
        .O_servo_pwm       ( O_servo                   ),
        .O_busy            ( S_servo_busy              )
    );
    assign S_video_out_vsync = ~S_hdmi_vsync;

    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_beep_active             <= 1'b0;
            S_beep_count              <= 24'd0;
            S_beep_tone_count         <= 13'd0;
            S_beep_phase              <= 1'b0;
            S_beep_quality_toggle_seen<= 1'b0;
        end else begin
            if(S_quality_update_toggle_24m != S_beep_quality_toggle_seen) begin
                S_beep_quality_toggle_seen <= S_quality_update_toggle_24m;
                if(S_quality_valid_24m && S_quality_grade_24m == 3'd4) begin
                    S_beep_active <= 1'b1;
                    S_beep_count  <= BEEP_CYCLES - 1'b1;
                    S_beep_tone_count <= BEEP_HALF_PERIOD - 1'b1;
                    S_beep_phase <= 1'b0;
                end
            end else if(S_beep_active) begin
                if(S_beep_count == 0) begin
                    S_beep_active <= 1'b0;
                    S_beep_tone_count <= 13'd0;
                    S_beep_phase <= 1'b0;
                end else begin
                    S_beep_count <= S_beep_count - 1'b1;
                    if(S_beep_tone_count == 0) begin
                        S_beep_tone_count <= BEEP_HALF_PERIOD - 1'b1;
                        S_beep_phase <= ~S_beep_phase;
                    end else begin
                        S_beep_tone_count <= S_beep_tone_count - 1'b1;
                    end
                end
            end
        end
    end
	
	
    assign S_rst_n 		= S_pll_lock;
    assign S_hdmi_rst_n = S_pll_lock;

    // Synchronize the frame-stable inspection result into the HDMI domain.
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_inspection_object_hdmi_sync <= 2'b00;
            S_inspection_toggle_hdmi_sync <= 2'b00;
            S_inspection_toggle_hdmi_seen <= 1'b0;
            S_inspection_object_hdmi      <= 1'b0;
        end
        else begin
            S_inspection_object_hdmi_sync[0] <= S_inspection_object_csi;
            S_inspection_object_hdmi_sync[1] <= S_inspection_object_hdmi_sync[0];
            S_inspection_toggle_hdmi_sync[0] <= S_inspection_update_toggle_csi;
            S_inspection_toggle_hdmi_sync[1] <= S_inspection_toggle_hdmi_sync[0];
            if(S_inspection_toggle_hdmi_sync[1] != S_inspection_toggle_hdmi_seen) begin
                S_inspection_object_hdmi      <= S_inspection_object_hdmi_sync[1];
                S_inspection_toggle_hdmi_seen <= S_inspection_toggle_hdmi_sync[1];
            end
        end
    end

    // A debounced C7 press requests one full shape capture in the CSI domain.
    // Use the same acceptance conditions as the existing area calibration.
    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_shape_calibrate_toggle <= 1'b0;
        else if(S_calibrate_key_pulse && S_inspection_object_24m &&
                S_inspection_black_count_24m >= 20'd2048)
            S_shape_calibrate_toggle <= ~S_shape_calibrate_toggle;
    end
    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_shape_calibrate_sync <= 3'd0;
            S_shape_calibrate_seen <= 1'b0;
        end else begin
            S_shape_calibrate_sync <=
                {S_shape_calibrate_sync[1:0],S_shape_calibrate_toggle};
            S_shape_calibrate_seen <= S_shape_calibrate_sync[2];
        end
    end

    // Shape-match results cross CSI -> 24 MHz -> HDMI as stable payloads
    // accompanied by synchronized event toggles.
    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_shape_toggle_24m_sync <= 2'b00;
            S_shape_toggle_24m_seen <= 1'b0;
            S_shape_payload_24m_1d <= 23'd0;
            S_shape_payload_24m_2d <= 23'd0;
            S_shape_payload_24m <= 23'd0;
            S_shape_payload_toggle_24m <= 1'b0;
        end
        else begin
            S_shape_toggle_24m_sync[0] <= S_shape_update_toggle_csi;
            S_shape_toggle_24m_sync[1] <= S_shape_toggle_24m_sync[0];
            S_shape_payload_24m_1d <= {
                S_shape_valid_csi, S_shape_result_code_csi,
                S_shape_score_csi, S_shape_angle_csi
            };
            S_shape_payload_24m_2d <= S_shape_payload_24m_1d;
            if(S_shape_toggle_24m_sync[1] != S_shape_toggle_24m_seen) begin
                S_shape_toggle_24m_seen <= S_shape_toggle_24m_sync[1];
                S_shape_payload_24m <= S_shape_payload_24m_2d;
                S_shape_payload_toggle_24m <= ~S_shape_payload_toggle_24m;
            end
        end
    end

    // Acknowledged CSI-to-control mailbox: the source holds all 46 bits
    // until the synchronized request has been sampled and acknowledged.
    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_quality_pair_req_sync<=0; S_quality_pair_seen<=0;
            S_quality_pair_ack_24m<=0; S_quality_pair_pulse_24m<=0;
            S_quality_pair_24m<=0;
        end else begin
            S_quality_pair_req_sync <= {S_quality_pair_req_sync[0],
                                        S_quality_pair_toggle_csi};
            S_quality_pair_pulse_24m <= 0;
            if(S_quality_pair_req_sync[1] != S_quality_pair_seen) begin
                S_quality_pair_seen <= S_quality_pair_req_sync[1];
                S_quality_pair_ack_24m <= S_quality_pair_req_sync[1];
                S_quality_pair_24m <= S_quality_pair_payload_csi;
                S_quality_pair_pulse_24m <= 1;
            end
        end
    end

    quality_score_ctrl u_quality_score_ctrl (
        .I_clk(S_24m_clk), .I_rst_n(S_rst_n),
        .I_calibrate(S_calibrate_key_pulse && S_inspection_object_24m &&
                     S_inspection_black_count_24m >= 20'd2048),
        .I_pair_pulse(S_quality_pair_pulse_24m),
        .I_inspect_ready(S_quality_pair_24m[0]),
        .I_feature_update(S_inspection_feature_update_24m),
        .I_live_black_count(S_inspection_black_count_24m),
        .I_area(S_quality_pair_24m[45:26]),
        .I_mismatch(S_quality_pair_24m[25:15]),
        .I_union(S_quality_pair_24m[14:4]),
        .I_shape_valid(S_quality_pair_24m[3]),
        .I_shape_ok(S_quality_pair_24m[2]),
        .I_capture(S_quality_pair_24m[1]),
        .I_baseline(S_inspection_baseline_count_24m),
        .I_baseline_valid(S_inspection_baseline_valid_24m),
        .I_object_present(S_inspection_object_24m),
        .O_valid(S_quality_valid_24m),
        .O_score(S_quality_score_24m),
        .O_grade(S_quality_grade_24m),
        .O_pass_count_bcd(S_pass_count_bcd_24m),
        .O_fail_count_bcd(S_fail_count_bcd_24m),
        .O_update_toggle(S_quality_update_toggle_24m)
    );

    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_quality_toggle_hdmi_sync<=0; S_quality_toggle_hdmi_seen<=0;
            S_quality_payload_hdmi<=0;
        end else begin
            S_quality_toggle_hdmi_sync <= {S_quality_toggle_hdmi_sync[0],
                                           S_quality_update_toggle_24m};
            if(S_quality_toggle_hdmi_sync[1] != S_quality_toggle_hdmi_seen) begin
                S_quality_toggle_hdmi_seen <= S_quality_toggle_hdmi_sync[1];
                S_quality_payload_hdmi <= S_quality_payload_24m;
            end
        end
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_shape_toggle_hdmi_sync <= 2'b00;
            S_shape_toggle_hdmi_seen <= 1'b0;
            S_shape_payload_hdmi_1d <= 23'd0;
            S_shape_payload_hdmi_2d <= 23'd0;
            S_shape_payload_hdmi <= 23'd0;
        end
        else begin
            S_shape_toggle_hdmi_sync[0] <= S_shape_payload_toggle_24m;
            S_shape_toggle_hdmi_sync[1] <= S_shape_toggle_hdmi_sync[0];
            S_shape_payload_hdmi_1d <= S_shape_payload_24m;
            S_shape_payload_hdmi_2d <= S_shape_payload_hdmi_1d;
            if(S_shape_toggle_hdmi_sync[1] != S_shape_toggle_hdmi_seen) begin
                S_shape_toggle_hdmi_seen <= S_shape_toggle_hdmi_sync[1];
                S_shape_payload_hdmi <= S_shape_payload_hdmi_2d;
            end
        end
    end

    // Stable statistics cross from the CSI clock into the 24 MHz control
    // domain by bundled data plus a toggle. The payload is held for a full
    // frame, so the two-stage toggle synchronizer identifies a safe sample.
    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_inspection_feature_toggle_24m_sync <= 2'b00;
            S_inspection_feature_toggle_24m_seen <= 1'b0;
            S_inspection_feature_update_24m      <= 1'b0;
            S_inspection_black_count_24m_1d      <= 20'd0;
            S_inspection_black_count_24m_2d      <= 20'd0;
            S_inspection_min_x_24m_1d            <= 11'd0;
            S_inspection_min_x_24m_2d            <= 11'd0;
            S_inspection_max_x_24m_1d            <= 11'd0;
            S_inspection_max_x_24m_2d            <= 11'd0;
            S_inspection_min_y_24m_1d            <= 11'd0;
            S_inspection_min_y_24m_2d            <= 11'd0;
            S_inspection_max_y_24m_1d            <= 11'd0;
            S_inspection_max_y_24m_2d            <= 11'd0;
            S_inspection_object_24m_1d          <= 1'b0;
            S_inspection_object_24m_2d          <= 1'b0;
            S_inspection_black_count_24m        <= 20'd0;
            S_inspection_min_x_24m              <= 11'd0;
            S_inspection_max_x_24m              <= 11'd0;
            S_inspection_min_y_24m              <= 11'd0;
            S_inspection_max_y_24m              <= 11'd0;
            S_inspection_object_24m             <= 1'b0;
        end
        else begin
            S_inspection_feature_toggle_24m_sync[0] <= S_inspection_feature_toggle_csi;
            S_inspection_feature_toggle_24m_sync[1] <= S_inspection_feature_toggle_24m_sync[0];
            S_inspection_black_count_24m_1d <= S_inspection_black_count_csi;
            S_inspection_black_count_24m_2d <= S_inspection_black_count_24m_1d;
            S_inspection_min_x_24m_1d <= S_inspection_min_x_csi;
            S_inspection_min_x_24m_2d <= S_inspection_min_x_24m_1d;
            S_inspection_max_x_24m_1d <= S_inspection_max_x_csi;
            S_inspection_max_x_24m_2d <= S_inspection_max_x_24m_1d;
            S_inspection_min_y_24m_1d <= S_inspection_min_y_csi;
            S_inspection_min_y_24m_2d <= S_inspection_min_y_24m_1d;
            S_inspection_max_y_24m_1d <= S_inspection_max_y_csi;
            S_inspection_max_y_24m_2d <= S_inspection_max_y_24m_1d;
            S_inspection_object_24m_1d <= S_inspection_object_csi;
            S_inspection_object_24m_2d <= S_inspection_object_24m_1d;
            S_inspection_feature_update_24m <= 1'b0;

            if(S_inspection_feature_toggle_24m_sync[1] !=
               S_inspection_feature_toggle_24m_seen) begin
                S_inspection_feature_toggle_24m_seen <=
                    S_inspection_feature_toggle_24m_sync[1];
                S_inspection_feature_update_24m <= 1'b1;
                S_inspection_black_count_24m <= S_inspection_black_count_24m_2d;
                S_inspection_min_x_24m <= S_inspection_min_x_24m_2d;
                S_inspection_max_x_24m <= S_inspection_max_x_24m_2d;
                S_inspection_min_y_24m <= S_inspection_min_y_24m_2d;
                S_inspection_max_y_24m <= S_inspection_max_y_24m_2d;
                S_inspection_object_24m <= S_inspection_object_24m_2d;
            end
        end
    end

    inspection_baseline_ctrl #(
        .BASELINE_TOL_PCT   ( 10 ),
        .MIN_BASELINE_COUNT ( 2048 )
    ) u_inspection_baseline_ctrl (
        .I_clk             ( S_24m_clk                    ),
        .I_rst_n           ( S_rst_n                      ),
        .I_calibrate_pulse ( S_calibrate_key_pulse        ),
        .I_feature_valid   ( S_inspection_feature_update_24m ),
        .I_black_count     ( S_inspection_black_count_24m  ),
        .I_object_present  ( S_inspection_object_24m       ),
        .O_result_code     ( S_inspection_result_code_24m  ),
        .O_baseline_valid  ( S_inspection_baseline_valid_24m ),
        .O_baseline_count  ( S_inspection_baseline_count_24m ),
        .O_black_count     ( S_inspection_display_count_24m ),
        .O_black_count_bcd ( S_inspection_display_count_bcd_24m ),
        .O_update_toggle   ( S_inspection_display_toggle_24m )
    );

    // Frame statistics and the comparison result are held between updates.
    // Sample the bundled payload after synchronizing its update toggle.
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_inspection_display_toggle_hdmi_sync <= 2'b00;
            S_inspection_display_toggle_hdmi_seen <= 1'b0;
            S_inspection_payload_hdmi_1d <= 71'd0;
            S_inspection_payload_hdmi_2d <= 71'd0;
            S_inspection_payload_hdmi <= 71'd0;
        end
        else begin
            S_inspection_display_toggle_hdmi_sync[0] <= S_inspection_display_toggle_24m;
            S_inspection_display_toggle_hdmi_sync[1] <= S_inspection_display_toggle_hdmi_sync[0];
            S_inspection_payload_hdmi_1d <= S_inspection_payload_24m;
            S_inspection_payload_hdmi_2d <= S_inspection_payload_hdmi_1d;
            if(S_inspection_display_toggle_hdmi_sync[1] !=
               S_inspection_display_toggle_hdmi_seen) begin
                S_inspection_display_toggle_hdmi_seen <= S_inspection_display_toggle_hdmi_sync[1];
                S_inspection_payload_hdmi <= S_inspection_payload_hdmi_2d;
            end
        end
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_raw_seen <= 1'b0;
        else if(S_raw10_frame_start | S_axis_tvalid)
            S_dbg_raw_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_seen <= 1'b0;
        else if(S_ISP_O_tuser | S_ISP_O_tvalid)
            S_dbg_isp_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_wr_seen <= 1'b0;
        else if(S_vi_ddr_wr_en)
            S_dbg_ddr_wr_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_rd_seen <= 1'b0;
        else if(S_ddr_user_rd_valid)
            S_dbg_ddr_rd_seen <= 1'b1;
    end

    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_cam_cfg_seen <= 1'b0;
        else if(S_cam_cfg_done)
            S_dbg_cam_cfg_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_hs_seen <= 1'b0;
        else if(S_hs_rx_valid)
            S_dbg_hs_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_csi_seen <= 1'b0;
        else if(S_csi_frame_start | S_csi_valid)
            S_dbg_csi_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_raw10_seen <= 1'b0;
        else if(S_raw10_frame_start | S_raw10_valid)
            S_dbg_raw10_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_fs_seen <= 1'b0;
        else if(S_ISP_O_tuser)
            S_dbg_isp_fs_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_valid_seen <= 1'b0;
        else if(S_ISP_O_tvalid)
            S_dbg_isp_valid_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_req_seen <= 1'b0;
        else if(S_vi_ddr_wr_en)
            S_dbg_ddr_req_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_ready_seen <= 1'b0;
        else if(S_ddr_user_ready)
            S_dbg_ddr_ready_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_req_seen <= 1'b0;
        else if(S_vo_ddr_rd_en)
            S_dbg_rd_req_seen <= 1'b1;
    end

    // Count CSI payload words between HS packet boundaries.  This avoids
    // probing an internal net of csi_unpacket_2lane (which ChipWatcher cannot
    // legally connect to) and verifies the received line length externally.
    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_dbg_hs_valid_d          <= 1'b0;
            S_dbg_csi_words           <= 11'd0;
            S_dbg_good_lines          <= 11'd0;
            S_dbg_frame_seen_once     <= 1'b0;
            S_dbg_frame_repeat_seen   <= 1'b0;
            S_dbg_width_1280_seen     <= 1'b0;
            S_dbg_height_720_seen     <= 1'b0;
            S_dbg_isp_frame_seen_once <= 1'b0;
            S_dbg_isp_frame_repeat_seen <= 1'b0;
        end
        else begin
            S_dbg_hs_valid_d <= S_hs_rx_valid;

            if(!S_dbg_hs_valid_d && S_hs_rx_valid)
                S_dbg_csi_words <= 11'd0;
            else if(S_csi_valid)
                S_dbg_csi_words <= S_dbg_csi_words + 11'd1;

            // A packet with CSI payload is an image line.  Ignore short
            // frame-start/frame-end packets, whose payload count is zero.
            if(S_dbg_hs_valid_d && !S_hs_rx_valid && (S_dbg_csi_words != 0)) begin
                if(S_dbg_csi_words == 11'd400) begin
                    S_dbg_width_1280_seen <= 1'b1;
                    S_dbg_good_lines <= S_dbg_good_lines + 11'd1;
                end
            end

            if(S_csi_frame_start) begin
                if(S_dbg_frame_seen_once) begin
                    S_dbg_frame_repeat_seen <= 1'b1;
                    if(S_dbg_good_lines == 11'd720)
                        S_dbg_height_720_seen <= 1'b1;
                end
                else
                    S_dbg_frame_seen_once <= 1'b1;
                S_dbg_good_lines <= 11'd0;
            end

            if(S_ISP_O_tuser) begin
                if(S_dbg_isp_frame_seen_once)
                    S_dbg_isp_frame_repeat_seen <= 1'b1;
                else
                    S_dbg_isp_frame_seen_once <= 1'b1;
            end
        end
    end

    always @(posedge S_ddr_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_valid_seen <= 1'b0;
        else if(S_ddr_user_rd_valid)
            S_dbg_rd_valid_seen <= 1'b1;
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_nonzero_seen <= 1'b0;
        else if(S_hdmi_window_rd_en && (S_video_rd_data != 24'd0))
            S_dbg_rd_nonzero_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_init_seen <= 1'b0;
        else if(S_init_calib_complete)
            S_dbg_mc_init_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_app_rdy_seen <= 1'b0;
        else if(S_mc_dbg_app_rdy)
            S_dbg_mc_app_rdy_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_wdf_rdy_seen <= 1'b0;
        else if(S_mc_dbg_wdf_rdy)
            S_dbg_mc_wdf_rdy_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_cmd_pop_seen <= 1'b0;
        else if(S_mc_dbg_cmd_pop)
            S_dbg_mc_cmd_pop_seen <= 1'b1;
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_dbg_cam_cfg_seen_sync <= 2'b00;
            S_dbg_hs_seen_sync      <= 2'b00;
            S_dbg_csi_seen_sync     <= 2'b00;
            S_dbg_raw10_seen_sync   <= 2'b00;
            S_dbg_raw_seen_sync    <= 2'b00;
            S_dbg_isp_seen_sync    <= 2'b00;
            S_dbg_ddr_wr_seen_sync <= 2'b00;
            S_dbg_ddr_rd_seen_sync <= 2'b00;
            S_dbg_isp_fs_seen_sync  <= 2'b00;
            S_dbg_isp_valid_seen_sync <= 2'b00;
            S_dbg_ddr_req_seen_sync <= 2'b00;
            S_dbg_ddr_ready_seen_sync <= 2'b00;
            S_dbg_video_nonzero_seen <= 1'b0;
            S_dbg_rd_req_seen_sync <= 2'b00;
            S_dbg_rd_valid_seen_sync <= 2'b00;
            S_dbg_rd_nonzero_seen_sync <= 2'b00;
            S_dbg_mc_init_seen_sync <= 2'b00;
            S_dbg_mc_app_rdy_seen_sync <= 2'b00;
            S_dbg_mc_wdf_rdy_seen_sync <= 2'b00;
            S_dbg_mc_cmd_pop_seen_sync <= 2'b00;
            S_dbg_frame_repeat_sync <= 2'b00;
            S_dbg_width_1280_sync <= 2'b00;
            S_dbg_height_720_sync <= 2'b00;
            S_dbg_isp_frame_repeat_sync <= 2'b00;
            S_dbg_cam_i2c_error_sync <= 2'b00;
            S_dbg_cam_sensor_id_ok_sync <= 2'b00;
        end
        else begin
            S_dbg_cam_cfg_seen_sync <= {S_dbg_cam_cfg_seen_sync[0], S_dbg_cam_cfg_seen};
            S_dbg_hs_seen_sync      <= {S_dbg_hs_seen_sync[0],      S_dbg_hs_seen};
            S_dbg_csi_seen_sync     <= {S_dbg_csi_seen_sync[0],     S_dbg_csi_seen};
            S_dbg_raw10_seen_sync   <= {S_dbg_raw10_seen_sync[0],   S_dbg_raw10_seen};
            S_dbg_raw_seen_sync    <= {S_dbg_raw_seen_sync[0],    S_dbg_raw_seen};
            S_dbg_isp_seen_sync    <= {S_dbg_isp_seen_sync[0],    S_dbg_isp_seen};
            S_dbg_ddr_wr_seen_sync <= {S_dbg_ddr_wr_seen_sync[0], S_dbg_ddr_wr_seen};
            S_dbg_ddr_rd_seen_sync <= {S_dbg_ddr_rd_seen_sync[0], S_dbg_ddr_rd_seen};
            S_dbg_isp_fs_seen_sync  <= {S_dbg_isp_fs_seen_sync[0],  S_dbg_isp_fs_seen};
            S_dbg_isp_valid_seen_sync <= {S_dbg_isp_valid_seen_sync[0], S_dbg_isp_valid_seen};
            S_dbg_ddr_req_seen_sync <= {S_dbg_ddr_req_seen_sync[0], S_dbg_ddr_req_seen};
            S_dbg_ddr_ready_seen_sync <= {S_dbg_ddr_ready_seen_sync[0], S_dbg_ddr_ready_seen};
            S_dbg_rd_req_seen_sync <= {S_dbg_rd_req_seen_sync[0], S_dbg_rd_req_seen};
            S_dbg_rd_valid_seen_sync <= {S_dbg_rd_valid_seen_sync[0], S_dbg_rd_valid_seen};
            S_dbg_rd_nonzero_seen_sync <= {S_dbg_rd_nonzero_seen_sync[0], S_dbg_rd_nonzero_seen};
            S_dbg_mc_init_seen_sync <= {S_dbg_mc_init_seen_sync[0], S_dbg_mc_init_seen};
            S_dbg_mc_app_rdy_seen_sync <= {S_dbg_mc_app_rdy_seen_sync[0], S_dbg_mc_app_rdy_seen};
            S_dbg_mc_wdf_rdy_seen_sync <= {S_dbg_mc_wdf_rdy_seen_sync[0], S_dbg_mc_wdf_rdy_seen};
            S_dbg_mc_cmd_pop_seen_sync <= {S_dbg_mc_cmd_pop_seen_sync[0], S_dbg_mc_cmd_pop_seen};
            S_dbg_frame_repeat_sync <= {S_dbg_frame_repeat_sync[0], S_dbg_frame_repeat_seen};
            S_dbg_width_1280_sync <= {S_dbg_width_1280_sync[0], S_dbg_width_1280_seen};
            S_dbg_height_720_sync <= {S_dbg_height_720_sync[0], S_dbg_height_720_seen};
            S_dbg_isp_frame_repeat_sync <= {S_dbg_isp_frame_repeat_sync[0], S_dbg_isp_frame_repeat_seen};
            S_dbg_cam_i2c_error_sync <= {S_dbg_cam_i2c_error_sync[0], S_cam_i2c_error};
            S_dbg_cam_sensor_id_ok_sync <= {S_dbg_cam_sensor_id_ok_sync[0], S_cam_sensor_id_ok};
            if(S_hdmi_window_rd_en && (S_video_rd_data != 24'd0))
                S_dbg_video_nonzero_seen <= 1'b1;
        end
    end

    assign S_lane_error_any = |S_lane_error;

    assign S_vo_dbg_fifo_rst = 1'b0;
    assign S_vo_dbg_ddr_rd_valid = 1'b0;
    assign S_vo_dbg_fifo_rd_en = 1'b0;
    assign S_vo_dbg_fifo_empty = 1'b0;
    assign S_mc_dbg_fifo_afull = 1'b0;
    assign S_mc_dbg_app_rdy = 1'b0;
    assign S_mc_dbg_wdf_rdy = 1'b0;
    assign S_mc_dbg_cmd_pop = 1'b0;

    // On-screen bring-up status, from left to right in DEBUG_MODE=3:
    // SC520 I2C/ID valid, MIPI HS activity, repeated CSI frames, and a
    // 1280-pixel RAW10 line (400 x 32-bit CSI payload words) seen.
    assign S_hdmi_debug_status = S_dbg_cam_i2c_error_sync[1] ? 4'h8 : {
        S_dbg_width_1280_sync[1],
        S_dbg_frame_repeat_sync[1],
        S_dbg_hs_seen_sync[1],
        S_dbg_cam_cfg_seen_sync[1] & S_dbg_cam_sensor_id_ok_sync[1]
    };
	
    // SC520CS XSHUTDN/PWDNB is active-low.  Keep it low after PLL lock for
    // at least 1 ms, then wait another 5 ms before starting I2C configuration.
    always @(posedge S_24m_clk or negedge S_pll_lock) begin
        if (!S_pll_lock) begin
            S_cam_power_cnt <= 18'd0;
            S_cam_pwdnb <= 1'b0;
            S_cam_i2c_ready <= 1'b0;
        end
        else begin
            if (S_cam_power_cnt < CAM_I2C_START_CYCLES)
                S_cam_power_cnt <= S_cam_power_cnt + 1'b1;
            if (S_cam_power_cnt >= CAM_PWDNB_LOW_CYCLES)
                S_cam_pwdnb <= 1'b1;
            if (S_cam_power_cnt >= CAM_I2C_START_CYCLES - 1)
                S_cam_i2c_ready <= 1'b1;
        end
    end

	assign O_cam_rst 	= S_cam_pwdnb;
    assign O_cam_24m 	= S_24m_clk;

    // All four buttons are active-low. A9 selects/toggles the original and
    // Sobel modes; B9 selects/toggles the ROI binary and ROI debug modes.
    // D5 is reserved for the camera gain key and is connected below to ae_set.
    button_press_debounce #(
        .CLK_HZ ( 23809524 ),
        .DEBOUNCE_MS ( 20 )
    ) u_camera_mode_key (
        .I_clk          ( S_24m_clk          ),
        .I_rst_n        ( S_rst_n            ),
        .I_key_n        ( I_button[1]        ),
        .O_press_pulse  ( S_camera_key_pulse )
    );

    button_press_debounce #(
        .CLK_HZ ( 23809524 ),
        .DEBOUNCE_MS ( 20 )
    ) u_roi_mode_key (
        .I_clk          ( S_24m_clk       ),
        .I_rst_n        ( S_rst_n         ),
        .I_key_n        ( I_button[2]     ),
        .O_press_pulse  ( S_roi_key_pulse )
    );

    button_press_debounce #(
        .CLK_HZ ( 23809524 ),
        .DEBOUNCE_MS ( 20 )
    ) u_calibrate_key (
        .I_clk         ( S_24m_clk             ),
        .I_rst_n       ( S_rst_n               ),
        .I_key_n       ( I_button[3]           ),
        .O_press_pulse ( S_calibrate_key_pulse )
    );

    // A9 toggles original/edge. B9 cycles grayscale -> ROI binary -> ROI
    // debug while leaving the A9 camera group independent.
    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_display_mode_24m                <= 3'd0;
            S_camera_mode_24m                 <= 1'b0;
            S_roi_mode_24m                    <= 2'd0;
            S_roi_selected_24m                <= 1'b0;
            S_display_mode_update_pending_24m <= 1'b0;
            S_display_mode_update_toggle_24m  <= 1'b0;
        end
        else begin
            if(S_display_mode_update_pending_24m) begin
                S_display_mode_update_toggle_24m  <= ~S_display_mode_update_toggle_24m;
                S_display_mode_update_pending_24m <= 1'b0;
            end

            if(S_camera_key_pulse) begin
                S_camera_mode_24m  <= ~S_camera_mode_24m;
                S_roi_selected_24m <= 1'b0;
                S_roi_mode_24m     <= 2'd0;
                S_display_mode_24m <= {2'b00, ~S_camera_mode_24m};
                S_display_mode_update_pending_24m <= 1'b1;
            end
            else if(S_roi_key_pulse) begin
                S_roi_selected_24m <= 1'b1;
                if(!S_roi_selected_24m) begin
                    S_roi_mode_24m     <= 2'd1;
                    S_display_mode_24m <= 3'd2;
                end
                else case(S_roi_mode_24m)
                    2'd1: begin
                        S_roi_mode_24m     <= 2'd2;
                        S_display_mode_24m <= 3'd3;
                    end
                    2'd2: begin
                        S_roi_mode_24m     <= 2'd0;
                        S_display_mode_24m <= 3'd4;
                    end
                    default: begin
                        S_roi_mode_24m     <= 2'd1;
                        S_display_mode_24m <= 3'd2;
                    end
                endcase
                S_display_mode_update_pending_24m <= 1'b1;
            end
        end
    end

    // Bundled-data CDC: the mode bus is held stable before the update toggle
    // changes. The destination accepts the bus only after both synchronizer
    // stages see the new toggle, so no independent bit can form a transient
    // invalid mode.
    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_display_mode_csi_bus_1d      <= 3'd0;
            S_display_mode_csi_bus_2d      <= 3'd0;
            S_display_mode_toggle_csi_1d   <= 1'b0;
            S_display_mode_toggle_csi_2d   <= 1'b0;
            S_display_mode_toggle_csi_seen <= 1'b0;
            S_display_mode_csi             <= 3'd0;
        end
        else begin
            S_display_mode_csi_bus_1d    <= S_display_mode_24m;
            S_display_mode_csi_bus_2d    <= S_display_mode_csi_bus_1d;
            S_display_mode_toggle_csi_1d <= S_display_mode_update_toggle_24m;
            S_display_mode_toggle_csi_2d <= S_display_mode_toggle_csi_1d;
            if(S_display_mode_toggle_csi_2d != S_display_mode_toggle_csi_seen) begin
                S_display_mode_csi <= S_display_mode_csi_bus_2d;
                S_display_mode_toggle_csi_seen <= S_display_mode_toggle_csi_2d;
            end
        end
    end

    PLL u_PLL(
        .refclk      ( I_sys_clk         ),
        .reset    	 ( ~I_rst_n          ),
        
        .clk0_out    ( S_100m_clk        ),
        .clk1_out    ( S_24m_clk         ),

        .clk4_out    ( S_hdmi_pixel_clk  ),
        .clk5_out    ( S_hdmi_serial_clk ),

        .lock        ( S_pll_lock        )

    );


	

  
  ae_set u_ae_set (
      .I_clk(S_24m_clk),
      .I_rst(~S_rst_n),
      .I_btn({I_button[0],1'b1,2'b11}),
      .I_cam_cfg_done(S_cam_cfg_done),
      .I_ae_cfg_done(S_ae_cfg_done),
      .I_feature_valid(S_inspection_feature_update_24m),
      .I_object_present(S_inspection_object_24m),
      .I_debug_mode(S_display_mode_24m == 3'd4),
      .I_meter_valid(S_ae_meter_valid_24m),
      .I_meter_luma(S_ae_meter_luma_24m),
      .O_ae_req(S_ae_req),
      .O_ae(S_ae),
      .O_ag(S_ag),
      .O_gain_mode(S_gain_level_24m)
  );

  // The OSD follows the camera-applied mode, not AUTO's changing gain code.

  // Transfer the low-rate gain status as a stable bus with a toggle event.
  // The payload is held for at least one source cycle before the toggle moves.
  always @(posedge S_24m_clk or negedge S_rst_n) begin
      if(!S_rst_n) begin
          S_gain_level_bus_24m             <= 2'd0;
          S_gain_level_last_24m            <= 2'd0;
          S_gain_level_update_pending_24m  <= 1'b0;
          S_gain_level_update_toggle_24m   <= 1'b0;
      end
      else begin
          if(S_gain_level_update_pending_24m) begin
              S_gain_level_update_toggle_24m  <= ~S_gain_level_update_toggle_24m;
              S_gain_level_update_pending_24m <= 1'b0;
          end

          if(S_gain_level_24m != S_gain_level_last_24m) begin
              S_gain_level_bus_24m            <= S_gain_level_24m;
              S_gain_level_last_24m           <= S_gain_level_24m;
              S_gain_level_update_pending_24m <= 1'b1;
          end
      end
  end
  
    uicfgcs520 #(
      .CLK_DIV(23809524 / 100000 - 1)
  ) u_uicfgcs520 (
      .I_clk(S_24m_clk),  //系统时钟输入
      .I_rst_n(S_cam_i2c_ready), // SC520CS power-up delay completed
      .I_ae_req(S_ae_req),
      .I_ae(S_ae),
      .I_ag(S_ag),
      .O_cam_scl(O_cam_scl),  //I2C总线，SCL时钟
      .IO_cam_sda(IO_cam_sda),  //I2C总线，SDA数据
      .O_cfg_done(S_cam_cfg_done),  //摄像头寄存器初始化完成
      .O_ae_cfg_done(S_ae_cfg_done), //AE配置完成
      .O_sensor_id(S_cam_sensor_id),
      .O_sensor_id_ok(S_cam_sensor_id_ok),
      .O_iic_error(S_cam_i2c_error)
  );
	
    mipi_dphy_rx_ph1p_mipiio_wrapper#(
        .DPHY_RX_LOCATION      ( "DPHY0" ),
        .HS_EQUALIZER          ( "3dB"   ),// SC520CS 828 Mbps/lane reference setting
        .HS_VGA_GAIN           ( "8dB" ),// PH1P35 valid values include 0dB,1.5dB,3dB,4.5dB,6dB,8dB,10dB,12dB
        .LANE_NUM              ( 2       ),
        .BYTE_NUM              ( 1       )
    )u_mipi_dphy_rx_ph1p_mipiio_wrapper(
        .I_lp_clk              ( S_100m_clk       ),
        .I_rst                 ( ~S_rst_n         ),

        .I_clk_lane_in_delay   ( 6'd0             ),
        .I_data_lane0_in_delay ( 6'd0             ),
        .I_data_lane1_in_delay ( 6'd0             ),
        .I_data_lane2_in_delay ( 6'd0             ),
        .I_data_lane3_in_delay ( 6'd0             ),

        .I_lane_invert         ( 4'b0000          ),
     
        .O_hs_rx_clk           ( S_csi_rx_clk     ),
        .O_hs_rx_valid         ( S_hs_rx_valid    ),
        .O_hs_rx_data          ( S_hs_rx_data     ),
      
        .O_lp_rx_lane0_p       (  ),
        .O_lp_rx_lane0_n       (  ),
      
        .I_lp_tx_en            ( 1'b0             ),
        .I_lp_tx_lane0_p       ( 1'b1             ),
        .I_lp_tx_lane0_n       ( 1'b1             ),
      
        .O_lane_match_error    (                  ),
        .O_lane_error          ( S_lane_error     ),
      
        .IO_rx_clk_pad_n       ( IO_rx_clk_pad_n  ),
        .IO_rx_clk_pad_p       ( IO_rx_clk_pad_p  ),
        .IO_rx_data_pad_n      ( IO_rx_data_pad_n ),
        .IO_rx_data_pad_p      ( IO_rx_data_pad_p )
    );
	
	
 //  cwc cwc_inst
 //(
 //    .probe0(S_hs_rx_valid),
 //    .probe1(S_hs_rx_data),
 //    .probe2(S_lane_error),
 //    .clk(S_csi_rx_clk)
 //);

 //csi 解码为RAW数据
csi_unpacket_2lane u_csi_unpacket(
.I_clk                 ( S_csi_rx_clk       ),
.I_rst_n               ( S_rst_n        	),
.I_hs_valid            ( S_hs_rx_valid     ),
.I_hs_data             ( S_hs_rx_data      ),

.O_csi_frame_start     ( S_csi_frame_start ),
.O_csi_frame_end       ( S_csi_frame_end   ),
.O_csi_valid           ( S_csi_valid       ),
.O_csi_data            ( S_csi_data        )
);


//解码为RAW8
raw10_unpacket_2lane u_raw10_unpacket (
.I_clk  (S_csi_rx_clk),
.I_rst_n(S_rst_n),

.I_csi_frame_start(S_csi_frame_start),
.I_csi_frame_end  (S_csi_frame_end),
.I_csi_valid      (S_csi_valid),
.I_csi_data       (S_csi_data),

.O_raw10_frame_start(S_raw10_frame_start),
.O_raw10_frame_end  (S_raw10_frame_end),
.O_raw10_valid      (S_raw10_valid),
.O_raw10_data       (S_raw10_data)
  );


// Camera path: packetized CSI data -> RAW10 beats -> frame/line-marked stream.
// The stream remains in S_csi_rx_clk until video_in crosses into the DDR side.
uial2axis #(
.IMG_WIDTH(1280),
.IMG_HEIGHT(720),
.INPUT_DATA_WIDTH(40)
) 
u_uial2axis (
.I_native_clk(S_csi_rx_clk),
.I_rst_n     (S_rst_n),
.I_data      (S_raw10_data       ),
.I_data_valid(S_raw10_valid      ),
.I_data_start(S_raw10_frame_start),
.I_data_end  (S_raw10_frame_end  ),
.axis_tvalid (S_axis_tvalid),
.axis_tdata  (S_axis_tdata ),
.axis_tuser  (S_axis_tuser ),
.axis_tlast  (S_axis_tlast )
);

raw10_ae_meter u_raw10_ae_meter (
    .I_clk(S_csi_rx_clk), .I_rst_n(S_rst_n),
    .I_tdata(S_axis_tdata), .I_tvalid(S_axis_tvalid),
    .I_tuser(S_axis_tuser), .I_tlast(S_axis_tlast),
    .O_luma(S_ae_meter_luma_csi),
    .O_update_toggle(S_ae_meter_toggle_csi)
);

// The metering payload remains stable for one frame. Synchronize its
// update toggle and sample the settled bus in the camera-control domain.
always @(posedge S_24m_clk or negedge S_rst_n) begin
    if (!S_rst_n) begin
        S_ae_meter_toggle_24m_sync <= 0;
        S_ae_meter_toggle_24m_seen <= 0;
        S_ae_meter_luma_24m_1d <= 0;
        S_ae_meter_luma_24m_2d <= 0;
        S_ae_meter_luma_24m <= 0;
        S_ae_meter_valid_24m <= 0;
    end else begin
        S_ae_meter_toggle_24m_sync <=
            {S_ae_meter_toggle_24m_sync[0], S_ae_meter_toggle_csi};
        S_ae_meter_luma_24m_1d <= S_ae_meter_luma_csi;
        S_ae_meter_luma_24m_2d <= S_ae_meter_luma_24m_1d;
        S_ae_meter_valid_24m <= 0;
        if (S_ae_meter_toggle_24m_sync[1] != S_ae_meter_toggle_24m_seen) begin
            S_ae_meter_toggle_24m_seen <= S_ae_meter_toggle_24m_sync[1];
            S_ae_meter_luma_24m <= S_ae_meter_luma_24m_2d;
            S_ae_meter_valid_24m <= 1;
        end
    end
end
	

// SC520CS factory HD mode outputs native 1280x720 RAW10.
assign S_raw_tdata  = S_axis_tdata;
assign S_raw_tvalid = S_axis_tvalid;
assign S_raw_tlast  = S_axis_tlast;
assign S_raw_tuser  = S_axis_tuser;


//cwc1 cwc1_Inst
//  (
//      .probe0(S_axis_tuser),
//      .probe1(S_axis_tvalid),
//      .probe2(S_axis_tlast),
//      .probe3(S_axis_tdata),
//      .probe4(S_ISP_O_tuser),
//      .probe5(S_ISP_O_tvalid),
//      .probe6(S_ISP_O_tlast),
//      .probe7(S_ISP_O_tdata),
//      .probe8 (S_raw_tdata ),
//      .probe9 (S_raw_tlast ),
//      .probe10(S_raw_tvalid),
//      .probe11(S_raw_tuser ),
//      .clk(S_csi_rx_clk)
//  );


// ISP path contains demosaic, AWB, grayscale, Sobel, and the 96-to-128
// packing stage. It is intentionally kept in the MIPI receive clock domain.
isp_top u_isp_top (
.axi4s_video_aclk(S_csi_rx_clk),
.I_rst_n         (S_rst_n),
.I_tlast         (S_raw_tlast	),
.I_tuser         (S_raw_tuser	),
.I_tdata         (S_raw_tdata	),
.I_tvalid        (S_raw_tvalid	),
.I_tdest         (),
.I_display_mode  (S_display_mode_csi),
.I_awb_enable    (I_sw_awb),
.I_shape_calibrate(S_shape_calibrate_pulse),
.O_tready        (1'b1),
.O_tdata         (S_ISP_O_tdata ),
.O_tlast         (S_ISP_O_tlast ),
.O_tuser         (S_ISP_O_tuser ),
.O_tvalid        (S_ISP_O_tvalid),
.O_display_mode  (S_ISP_O_display_mode),
.O_inspection_object         (S_inspection_object_csi),
.O_inspection_update_toggle (S_inspection_update_toggle_csi),
.O_inspection_feature_toggle (S_inspection_feature_toggle_csi),
.O_inspection_black_count    (S_inspection_black_count_csi),
.O_inspection_min_x          (S_inspection_min_x_csi),
.O_inspection_max_x          (S_inspection_max_x_csi),
.O_inspection_min_y          (S_inspection_min_y_csi),
.O_inspection_max_y          (S_inspection_max_y_csi),
.O_shape_update_toggle       (S_shape_update_toggle_csi),
.O_shape_valid               (S_shape_valid_csi),
.O_shape_result_code         (S_shape_result_code_csi),
.O_shape_score               (S_shape_score_csi),
.O_shape_angle               (S_shape_angle_csi),
.O_quality_pair_toggle       (S_quality_pair_toggle_csi),
.O_quality_pair_payload      (S_quality_pair_payload_csi),
.I_quality_pair_ack          (S_quality_pair_ack_24m),
.I_tready        ()
  );


    // video_in performs the camera-clock to DDR-clock buffering and rotates
    // the four DDR frame regions.
    video_in u_video_in(
        .I_rst_n              (  S_rst_n             ),

        .I_camera_clk         ( S_csi_rx_clk          ),
        .I_camera_frame_start ( S_ISP_O_tuser  ),
        .I_camera_frame_mode  ( S_ISP_O_display_mode ),
        .I_camera_valid       ( S_ISP_O_tvalid ),
        .I_camera_data        ( S_ISP_O_tdata  ),
        .I_mipi_rx_error      ( 1'b0			      ),

         .I_ddr_clk            ( S_ddr_clk             ),
         .I_ddr_init_done      ( S_init_calib_complete ),
		 .I_display_pause      ( 1'b0                  ),
         .I_video_out_rd_busy  ( S_video_out_rd_busy   ),
         .O_video_in_wr_busy   ( S_video_in_wr_busy    ),
         .O_video_out_rp       ( S_video_out_rp        ),
         .O_frame_ready        ( S_frame_ready          ),
         .O_frame_mode_slots   ( S_frame_mode_slots     ),
         .O_frame_write_start  ( S_frame_write_start_ddr ),
         .O_frame_write_slot   ( S_frame_write_slot_ddr  ),

        .O_ddr_user_wr_en     ( S_vi_ddr_wr_en        ),
        .O_ddr_user_addr      ( S_vi_ddr_wr_addr      ),
        .O_ddr_user_wr_data   ( S_vi_ddr_wr_data      ),
        .I_ddr_user_ready     ( S_ddr_user_ready      )
    );



    assign S_ddr_user_wr_en    = S_vi_ddr_wr_en;

    assign S_ddr_user_rd_en    = S_vo_ddr_rd_en;

    assign S_ddr_user_addr     = S_vi_ddr_wr_en ? S_vi_ddr_wr_addr :
                                 S_vo_ddr_rd_en ? S_vo_ddr_rd_addr : 'd0;

    assign S_ddr_user_wr_data  = S_vi_ddr_wr_data;


    assign S_video_out_rst_n = S_hdmi_rst_n;

    video_out u_video_out(
        .I_rst_n             ( S_video_out_rst_n    ),
         .I_ddr_clk           ( S_ddr_clk            ),
         .I_ddr_init_done     ( S_init_calib_complete ),
 
         .O_video_out_rd_busy ( S_video_out_rd_busy  ),
         .I_video_in_wr_busy  ( S_video_in_wr_busy   ),
         .I_video_out_rp      ( S_video_out_rp       ),
         .I_frame_ready       ( S_frame_ready         ),
         .I_frame_mode_slots  ( S_frame_mode_slots    ),
         .O_display_frame_start( S_display_frame_start_ddr ),
         .O_display_frame_slot ( S_display_frame_slot_ddr  ),
         .O_display_frame_ready( S_display_frame_ready_ddr ),
 
        .O_ddr_user_rd_en    ( S_vo_ddr_rd_en       ),
        .O_ddr_user_addr     ( S_vo_ddr_rd_addr     ),
        .I_ddr_user_ready    ( S_ddr_user_ready     ),
        .I_ddr_user_rd_valid ( S_ddr_user_rd_valid  ),
        .I_ddr_user_rd_data  ( S_ddr_user_rd_data   ),

        .I_dsi_clk           ( S_hdmi_pixel_clk     ),
        .I_video_vsync       ( S_video_out_vsync    ),
         .I_video_rd_en       ( S_hdmi_window_rd_en  ),
        .O_vdieo_data        ( S_video_rd_data      ),
        .O_display_mode    ( S_display_mode_video )
    );

    video_telemetry #(.DDR_CLK_HZ(66666667)) u_video_telemetry (
        .I_camera_clk         ( S_csi_rx_clk ),
        .I_camera_frame_start ( S_raw10_frame_start ),
        .I_ddr_clk            ( S_ddr_clk ),
        .I_rst_n              ( S_rst_n ),
        .I_write_start        ( S_frame_write_start_ddr ),
        .I_write_slot         ( S_frame_write_slot_ddr ),
        .I_display_start      ( S_display_frame_start_ddr ),
        .I_display_slot       ( S_display_frame_slot_ddr ),
        .I_display_ready      ( S_display_frame_ready_ddr ),
        .O_latency_ms         ( S_video_latency_ms_ddr ),
        .O_latency_valid      ( S_video_latency_valid_ddr ),
        .O_camera_fps_bcd     ( S_camera_fps_bcd_ddr ),
        .O_update_toggle      ( S_video_telemetry_toggle_ddr )
    );

    // One stable telemetry payload per selected HDMI frame crosses DDR -> HDMI.
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if (!S_hdmi_rst_n) begin
            S_video_telemetry_sync_hdmi <= 2'b00;
            S_video_telemetry_seen_hdmi <= 1'b0;
            S_video_telemetry_bus_1d <= 21'd0;
            S_video_telemetry_bus_2d <= 21'd0;
            S_video_telemetry_hdmi <= 21'd0;
        end else begin
            S_video_telemetry_sync_hdmi <= {
                S_video_telemetry_sync_hdmi[0],
                S_video_telemetry_toggle_ddr
            };
            S_video_telemetry_bus_1d <= S_video_telemetry_ddr;
            S_video_telemetry_bus_2d <= S_video_telemetry_bus_1d;
            if (S_video_telemetry_sync_hdmi[1] !=
                S_video_telemetry_seen_hdmi) begin
                S_video_telemetry_seen_hdmi <= S_video_telemetry_sync_hdmi[1];
                S_video_telemetry_hdmi <= S_video_telemetry_bus_2d;
            end
        end
    end



    mc_to_user_interface u_mc_to_user_interface(
        .I_clk                   ( S_ddr_clk               ),
        .I_rst_n                 ( S_rst_n                 ),

        .I_ddr_user_wr_en        ( S_ddr_user_wr_en        ),
        .I_ddr_user_rd_en        ( S_ddr_user_rd_en        ),
        .I_ddr_user_addr         ( S_ddr_user_addr         ),
        .I_ddr_user_wr_data      ( S_ddr_user_wr_data      ),
        .O_ddr_user_ready        ( S_ddr_user_ready        ),
        .O_ddr_user_rd_valid     ( S_ddr_user_rd_valid     ),
        .O_ddr_user_rd_data      ( S_ddr_user_rd_data      ),
            
        .O_mc_app_en             ( S_mc_app_en             ),
        .O_mc_app_addr           ( S_mc_app_addr           ),
        .O_mc_app_cmd            ( S_mc_app_cmd            ),
        .I_mc_app_rdy            ( S_mc_app_rdy            ),
        .O_mc_app_wdf_wren       ( S_mc_app_wdf_wren       ),
        .O_mc_app_wdf_data       ( S_mc_app_wdf_data       ),
        .O_mc_app_wdf_end        ( S_mc_app_wdf_end        ),
        .O_mc_app_wdf_mask       ( S_mc_app_wdf_mask       ),
        .I_mc_app_wdf_rdy        ( S_mc_app_wdf_rdy        ),
        .I_mc_app_rd_data        ( S_mc_app_rd_data        ),
        .I_mc_app_rd_data_end    ( S_mc_app_rd_data_end    ),
        .I_mc_app_rd_data_valid  ( S_mc_app_rd_data_valid  )
    );



    ph1p35_324_ddr_wrapper u_ph1p35_324_ddr_wrapper(
        .I_sys_clk              ( I_sys_clk              ),
        .I_sys_rst_n            ( S_rst_n                ),

        .O_ddr_clk              ( S_ddr_clk              ),
        .O_init_calib_complete  ( S_init_calib_complete  ),
        .I_mc_app_addr          ( S_mc_app_addr          ),
        .I_mc_app_cmd           ( S_mc_app_cmd           ),
        .I_mc_app_en            ( S_mc_app_en            ),
        .I_mc_app_wdf_data      ( S_mc_app_wdf_data      ),
        .I_mc_app_wdf_end       ( S_mc_app_wdf_end       ),
        .I_mc_app_wdf_mask      ( S_mc_app_wdf_mask      ),
        .I_mc_app_wdf_wren      ( S_mc_app_wdf_wren      ),
        .O_mc_app_rd_data       ( S_mc_app_rd_data       ),
        .O_mc_app_rd_data_end   ( S_mc_app_rd_data_end   ),
        .O_mc_app_rd_data_valid ( S_mc_app_rd_data_valid ),
        .O_mc_app_rdy           ( S_mc_app_rdy           ),
        .O_mc_app_wdf_rdy       ( S_mc_app_wdf_rdy       ),

        .ddr_addr               ( ddr_addr               ),
        .ddr_ba                 ( ddr_ba                 ),
        .ddr_cke                ( ddr_cke                ),
        .ddr_odt                ( ddr_odt                ),
        .ddr_cs_n               ( ddr_cs_n               ),
        .ddr_ras_n              ( ddr_ras_n              ),
        .ddr_cas_n              ( ddr_cas_n              ),
        .ddr_we_n               ( ddr_we_n               ),
        .ddr_ck_p               ( ddr_ck_p               ),
        .ddr_ck_n               ( ddr_ck_n               ),
        .ddr_dm                 ( ddr_dm                 ),
        .ddr_dq                 ( ddr_dq                 ),
        .ddr_dqs_p              ( ddr_dqs_p              ),
        .ddr_dqs_n              ( ddr_dqs_n              )
    );



    // Fixed 1280x720 timing in the HDMI pixel-clock domain.
    uivtc #(
        .H_ActiveSize ( 1280 ),
        .H_FrameSize  ( 1650 ),
        .H_SyncStart  ( 1390 ),
        .H_SyncEnd    ( 1430 ),
        .V_ActiveSize ( 720  ),
        .V_FrameSize  ( 750  ),
        .V_SyncStart  ( 725  ),
        .V_SyncEnd    ( 730  )
    )u_hdmi_vtc(
        .I_vtc_rstn    ( S_hdmi_rst_n    ),
        .I_vtc_clk     ( S_hdmi_pixel_clk ),
        .O_vtc_vs      ( S_hdmi_vsync     ),
        .O_vtc_hs      ( S_hdmi_hsync     ),
        .O_vtc_de_valid( S_hdmi_de        ),
        .O_vtc_user    ( S_hdmi_user      ),
        .O_vtc_last    ( S_hdmi_last      )
    );

    hdmi_mixer #(
        .H_OFFSET   ( 0    ),
        .V_OFFSET   ( 0    ),
        .IMG_WIDTH  ( 1280 ),
        .IMG_HEIGHT ( 720  ),
        .DEBUG_MODE ( 0    ) // Normal SC520 1280x720 camera image
    )u_hdmi_mixer(
        .I_clk           ( S_hdmi_pixel_clk   ),
        .I_rst_n         ( S_hdmi_rst_n       ),
        .I_video_vsync   ( S_hdmi_vsync       ),
        .I_video_hsync   ( S_hdmi_hsync       ),
        .I_video_de      ( S_hdmi_de          ),
        .I_video_user    ( S_hdmi_user        ),
        .I_video_last    ( S_hdmi_last        ),
        .I_debug_status  ( S_hdmi_debug_status),
        .I_display_mode  ( S_display_mode_video ),
        .I_awb_enable   ( I_sw_awb ),
        .I_gain_level               ( S_gain_level_bus_24m          ),
        .I_gain_level_update_toggle ( S_gain_level_update_toggle_24m ),
        .I_inspection_object        ( S_inspection_object_hdmi ),
        .I_inspection_baseline_valid ( S_inspection_payload_hdmi[70] ),
        .I_inspection_result_code    ( S_inspection_payload_hdmi[69:68] ),
        .I_inspection_black_count_bcd( S_inspection_payload_hdmi[67:44] ),
        .I_inspection_bbox_min_x     ( S_inspection_payload_hdmi[43:33] ),
        .I_inspection_bbox_max_x     ( S_inspection_payload_hdmi[32:22] ),
        .I_inspection_bbox_min_y     ( S_inspection_payload_hdmi[21:11] ),
        .I_inspection_bbox_max_y     ( S_inspection_payload_hdmi[10:0] ),
        .I_shape_valid               ( S_shape_payload_hdmi[22] ),
        .I_shape_result_code         ( S_shape_payload_hdmi[21:20] ),
        .I_shape_score               ( S_shape_payload_hdmi[19:9] ),
        .I_shape_angle               ( S_shape_payload_hdmi[8:0] ),
        .I_quality_valid             ( S_quality_payload_hdmi[50] ),
        .I_quality_score             ( S_quality_payload_hdmi[49:43] ),
        .I_quality_grade             ( S_quality_payload_hdmi[42:40] ),
        .I_pass_count_bcd            ( S_quality_payload_hdmi[39:20] ),
        .I_fail_count_bcd            ( S_quality_payload_hdmi[19:0] ),
        .I_video_latency_valid       ( S_video_telemetry_hdmi[20]    ),
        .I_video_latency_ms          ( S_video_telemetry_hdmi[19:8]  ),
        .I_camera_fps_bcd            ( S_video_telemetry_hdmi[7:0]   ),
        .O_video_rd_en   ( S_hdmi_window_rd_en),
        .I_video_rd_data ( S_video_rd_data    ),
        .O_hdmi_vsync    ( S_hdmi_out_vsync   ),
        .O_hdmi_hsync    ( S_hdmi_out_hsync   ),
        .O_hdmi_de       ( S_hdmi_out_de      ),
        .O_hdmi_data     ( S_hdmi_out_data    )
    );

    hdmi_tx u_hdmi_tx(
        .I_pixel_clk        ( S_hdmi_pixel_clk  ),
        .I_serial_clk       ( S_hdmi_serial_clk ),
        .I_rst              ( ~S_hdmi_rst_n     ),
        .I_key_in           ( 1'b0              ),
        .I_edid_read_trig   ( 1'b0              ),
        .O_edid_read_valid  (                   ),
        .O_edid_read_data   (                   ),
        .I_video_rgb_enable ( 1'b1              ),
        .I_video_in_vs      ( S_hdmi_out_vsync  ),
        .I_video_in_de      ( S_hdmi_out_de     ),
        .I_video_in_user    ( 1'b0              ),
        .I_video_in_valid   ( 1'b0              ),
        .I_video_in_last    ( 1'b0              ),
        .O_video_in_ready   (                   ),
        .I_video_in_data    ( S_hdmi_out_data   ),
        .I_audio_valid      ( 1'b0              ),
        .I_audio_left_data  ( 24'd0             ),
        .I_audio_right_data ( 24'd0             ),
        .I_i2s_BCLK         ( 1'b0              ),
        .I_i2s_LRCK         ( 1'b0              ),
        .I_i2s_DOUT         ( 1'b0              ),
        .O_ddc_scl          (                   ),
        .O_hdmi_clk_p       (                   ),
        .O_hdmi_tx_p        (                   ),
        .O_tmds_ch0_p       ( O_tmds_ch0_p      ),
        .O_tmds_ch1_p       ( O_tmds_ch1_p      ),
        .O_tmds_ch2_p       ( O_tmds_ch2_p      ),
        .O_tmds_clk_p       ( O_tmds_clk_p      )
    );


    
endmodule

// Four green RAW10 samples per selected line, outside x=160..1119 ROI.
// 64 selected lines x 4 samples = 256, so the mean needs no divider.
module raw10_ae_meter (
    input wire I_clk,
    input wire I_rst_n,
    input wire [39:0] I_tdata,
    input wire I_tvalid,
    input wire I_tuser,
    input wire I_tlast,
    output reg [9:0] O_luma,
    output reg O_update_toggle
);
    reg [8:0] S_beat_x;
    reg [9:0] S_y;
    reg [8:0] S_samples;
    reg [17:0] S_sum;
    wire S_sample = I_tvalid && S_y >= 10'd128 && S_y < 10'd640 &&
                    S_y[2:0] == 3'd0 &&
                    (S_beat_x == 9'd8 || S_beat_x == 9'd24 ||
                     S_beat_x == 9'd288 || S_beat_x == 9'd304);

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            S_beat_x <= 0;
            S_y <= 0;
            S_samples <= 0;
            S_sum <= 0;
            O_luma <= 0;
            O_update_toggle <= 0;
        end else if (I_tuser && I_tvalid) begin
            S_beat_x <= 9'd1;
            S_y <= 0;
            S_samples <= 0;
            S_sum <= 0;
        end else if (I_tvalid) begin
            if (I_tlast) begin
                S_beat_x <= 0;
                if (S_y == 10'd719) begin
                    if (S_samples == 9'd256) begin
                        O_luma <= S_sum[17:8];
                        O_update_toggle <= ~O_update_toggle;
                    end
                    S_y <= 0;
                end else
                    S_y <= S_y + 1'b1;
            end else
                S_beat_x <= S_beat_x + 1'b1;

            if (S_sample && S_samples < 9'd256) begin
                // The RAW10 unpacker places BGGR pixel P1 here.
                S_sum <= S_sum + {8'd0, I_tdata[19:10]};
                S_samples <= S_samples + 1'b1;
            end
        end
    end
endmodule

module button_press_debounce #(
    parameter integer CLK_HZ = 23809524,
    parameter integer DEBOUNCE_MS = 20
)(
    input  wire I_clk,
    input  wire I_rst_n,
    input  wire I_key_n,
    output reg  O_press_pulse
);

    localparam integer DEBOUNCE_CYCLES = (CLK_HZ / 1000) * DEBOUNCE_MS;
    localparam integer COUNTER_WIDTH = $clog2(DEBOUNCE_CYCLES + 1);

    reg S_key_sync_1d;
    reg S_key_sync_2d;
    reg S_key_stable;
    reg [COUNTER_WIDTH-1:0] S_debounce_count;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_key_sync_1d   <= 1'b1;
            S_key_sync_2d   <= 1'b1;
            S_key_stable    <= 1'b1;
            S_debounce_count <= {COUNTER_WIDTH{1'b0}};
            O_press_pulse   <= 1'b0;
        end
        else begin
            S_key_sync_1d <= I_key_n;
            S_key_sync_2d <= S_key_sync_1d;
            O_press_pulse <= 1'b0;

            if(S_key_sync_2d == S_key_stable)
                S_debounce_count <= {COUNTER_WIDTH{1'b0}};
            else if(S_debounce_count >= DEBOUNCE_CYCLES - 1) begin
                S_debounce_count <= {COUNTER_WIDTH{1'b0}};
                S_key_stable <= S_key_sync_2d;
                if(!S_key_sync_2d)
                    O_press_pulse <= 1'b1;
            end
            else
                S_debounce_count <= S_debounce_count + 1'b1;
        end
    end
endmodule
