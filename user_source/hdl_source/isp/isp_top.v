module isp_top (
    input 			axi4s_video_aclk,
    input 			I_rst_n			,
    input 			I_tlast			,
    input 			I_tuser			,
    input [39:0] 	I_tdata			,
    input 			I_tvalid		,
    input [9:0] 	I_tdest			,
    input [2:0]     I_display_mode,
    input           I_awb_enable,
    input           I_shape_calibrate,
    input 			O_tready		,
    output [127:0] 	O_tdata			,
    output 			O_tlast			,
    output 			O_tuser			,
    output 			O_tvalid		,
    output [2:0]     O_display_mode,
    output 			I_tready,
    output          O_inspection_object,
    output          O_inspection_update_toggle,
    output          O_inspection_feature_toggle,
    output [19:0]   O_inspection_black_count,
    output [10:0]   O_inspection_min_x,
    output [10:0]   O_inspection_max_x,
    output [10:0]   O_inspection_min_y,
    output [10:0]   O_inspection_max_y,
    output          O_shape_update_toggle,
    output          O_shape_valid,
    output [1:0]    O_shape_result_code,
    output [10:0]   O_shape_score,
    output [8:0]    O_shape_angle,
    output reg       O_quality_pair_toggle,
    output reg [45:0] O_quality_pair_payload,
    input            I_quality_pair_ack
);

// Processing order:
// demosaic -> 128-to-96 packing -> AWB
//                              -> normal RGB 96-to-128 packing
//                              -> official Lab2 RGB-to-Sobel -> 96-to-128 packing
//                                 + shared SC520 reference grayscale output
//                              -> fixed ROI binary -> 96-to-128 packing
// All display paths run continuously; the selected path changes at an AWB
// frame boundary.
wire         m_aixs_tvalid;  //synthesis keep 
  wire [127:0] m_aixs_tdata;  //synthesis keep 
  wire         m_aixs_tuser;  //synthesis keep 
  wire         m_aixs_tlast;  //synthesis keep 
  wire         m_aixs_tready;  //synthesis keep 
  
  wire [ 95:0] m_aixs_tdata_96;  //synthesis keep 


  wire         awb_O_tlast;  //synthesis keep 
  wire         awb_O_tuser;  //synthesis keep 
  wire [ 95:0] awb_O_tdata;  //synthesis keep 
  wire         awb_O_tvalid;  //synthesis keep 
  wire         awb_O_tready;  //synthesis keep 

  wire         edge_O_tlast;  //synthesis keep
  wire         edge_O_tuser;  //synthesis keep
  wire [ 95:0] edge_O_tdata;  //synthesis keep
  wire         edge_O_tvalid; //synthesis keep
  wire         edge_O_tready; //synthesis keep
  wire [ 95:0] edge_gray_O_tdata; //synthesis keep

  wire         edge_O_tuser_128;  //synthesis keep
  wire         edge_O_tvalid_128;  //synthesis keep
  wire [127:0] edge_O_tdata_128;  //synthesis keep
  wire         rgb_O_tuser_128;  //synthesis keep
  wire         rgb_O_tvalid_128;  //synthesis keep
  wire [127:0] rgb_O_tdata_128;  //synthesis keep
  wire         gray_O_tuser_128;  //synthesis keep
  wire         gray_O_tvalid_128; //synthesis keep
  wire [127:0] gray_O_tdata_128;  //synthesis keep
  wire         roi_O_tlast;       //synthesis keep
  wire         roi_O_tuser;       //synthesis keep
  wire [95:0]  roi_O_tdata;       //synthesis keep
  wire         roi_O_tvalid;      //synthesis keep
  wire         roi_O_tlast_128;   //synthesis keep
  wire         roi_O_tuser_128;   //synthesis keep
  wire         roi_O_tvalid_128;  //synthesis keep
  wire [127:0] roi_O_tdata_128;   //synthesis keep
  wire         roi_feature_valid;
  wire [19:0]  roi_black_count;
  wire [10:0]  roi_min_x;
  wire [10:0]  roi_max_x;
  wire [10:0]  roi_min_y;
  wire [10:0]  roi_max_y;
  wire [7:0]   roi_border_count;
  reg [1:0]    S_clean_frames;
  reg          S_feature_ready;
  reg          S_shape_ready_snapshot;
  reg [2:0]    S_display_mode_frame;
  reg          S_inspection_feature_toggle;

  wire         S_shape_buffer_pixel;
  wire [17:0]  S_shape_read_addr;
  wire [1:0]   S_shape_read_bit_sel;
  wire         S_shape_buffer_toggle;
  wire         S_shape_buffer_valid;
  wire         S_moment_valid;
  wire [19:0]  S_m00;
  wire [28:0]  S_m10;
  wire [28:0]  S_m01;
  wire [39:0]  S_m20;
  wire [38:0]  S_m02;
  wire [39:0]  S_m11;
  wire [9:0]   S_moment_min_x;
  wire [9:0]   S_moment_max_x;
  wire [9:0]   S_moment_min_y;
  wire [9:0]   S_moment_max_y;
  wire         S_axis_valid_pulse;
  wire         S_axis_valid;
  wire [8:0]   S_axis_angle;
  wire [9:0]   S_axis_cx;
  wire [9:0]   S_axis_cy;
  wire [9:0]   S_axis_extent;
  wire signed [15:0] S_axis_cos, S_axis_sin;
  reg          S_shape_rotate_start;
  wire         S_rotate_source_req;
  wire [9:0]   S_rotate_source_x;
  wire [9:0]   S_rotate_source_y;
  wire         S_rotate_valid;
  wire [4:0]   S_rotate_dst_x;
  wire [4:0]   S_rotate_dst_y;
  wire         S_rotate_pixel;
  wire         S_rotate_done;
  wire         S_shape_match_valid;
  wire         S_shape_match_ok;
  wire [10:0]  S_shape_match_score;
  wire         S_shape_match_done;
  wire [10:0]  S_shape_match_union;
  wire         S_shape_match_captured;
  wire         S_axis_accept;
  reg [1:0]    S_feature_frame_id, S_shape_frame_id;
  reg [19:0]   S_feature_area;
  reg [10:0]   S_prev_min_x, S_prev_max_x, S_prev_min_y, S_prev_max_y;
  reg          S_prev_valid;
  reg [19:0]   S_shape_area_snapshot;
  wire [20:0] S_area_delta = roi_black_count >= S_feature_area ?
      {1'b0,roi_black_count}-{1'b0,S_feature_area} :
      {1'b0,S_feature_area}-{1'b0,roi_black_count};
  wire S_position_stable =
      ({1'b0,roi_min_x} <= {1'b0,S_prev_min_x}+12'd16) &&
      ({1'b0,S_prev_min_x} <= {1'b0,roi_min_x}+12'd16) &&
      ({1'b0,roi_max_x} <= {1'b0,S_prev_max_x}+12'd16) &&
      ({1'b0,S_prev_max_x} <= {1'b0,roi_max_x}+12'd16) &&
      ({1'b0,roi_min_y} <= {1'b0,S_prev_min_y}+12'd16) &&
      ({1'b0,S_prev_min_y} <= {1'b0,roi_min_y}+12'd16) &&
      ({1'b0,roi_max_y} <= {1'b0,S_prev_max_y}+12'd16) &&
      ({1'b0,S_prev_max_y} <= {1'b0,roi_max_y}+12'd16);
  (* ASYNC_REG = "TRUE" *) reg [1:0] S_quality_ack_sync;
  wire         S_shape_fusion_valid;
  wire         S_shape_result_toggle;
  wire         S_shape_result_valid;
  wire [1:0]   S_shape_result_code;
  wire [10:0]  S_shape_score;
  wire [8:0]   S_shape_angle;

  // Mode selected for the current ISP frame. Downstream DDR logic stores
  // this as metadata for the corresponding frame slot.
  assign O_display_mode = S_display_mode_frame;

  wire         S_display_mode_gray;
  wire         S_display_mode_roi;
  wire         S_display_mode_edge_compat;
  assign S_display_mode_gray = (S_display_mode_frame == 3'd2);
  assign S_display_mode_roi = (S_display_mode_frame == 3'd3) ||
                              (S_display_mode_frame == 3'd4);
  assign S_display_mode_edge_compat = (S_display_mode_frame == 3'd1);

  // The top level keeps this video path continuously ready.
  assign awb_O_tready = edge_O_tready;
  assign O_tdata  = S_display_mode_roi ? roi_O_tdata_128 :
                    S_display_mode_gray ? gray_O_tdata_128 :
                    S_display_mode_edge_compat ? edge_O_tdata_128 :
                    rgb_O_tdata_128;
  assign O_tlast  = S_display_mode_roi ? roi_O_tlast_128 :
                    (S_display_mode_gray || S_display_mode_edge_compat) ? edge_O_tlast :
                    1'b0;
  assign O_tuser  = S_display_mode_roi ? roi_O_tuser_128 :
                    S_display_mode_gray ? gray_O_tuser_128 :
                    S_display_mode_edge_compat ? edge_O_tuser_128 :
                    rgb_O_tuser_128;
  assign O_tvalid = S_display_mode_roi ? roi_O_tvalid_128 :
                    S_display_mode_gray ? gray_O_tvalid_128 :
                    S_display_mode_edge_compat ? edge_O_tvalid_128 :
                    rgb_O_tvalid_128;

  // The active AWB emits frame start before valid pixels. Reuse Sobel's
  // unconditionally registered markers; do not qualify tuser with tvalid.
  data_96bit_to_128bit u_gray_data_96bit_to_128bit(
      .I_clk              ( axi4s_video_aclk  ),
      .I_rst_n            ( I_rst_n           ),
      .I_96b_frame_start  ( edge_O_tuser      ),
      .I_96b_valid        ( edge_O_tvalid     ),
      .I_96b_data         ( edge_gray_O_tdata ),
      .O_128b_frame_start ( gray_O_tuser_128  ),
      .O_128b_valid       ( gray_O_tvalid_128 ),
      .O_128b_data        ( gray_O_tdata_128  )
  );

  always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
    if(!I_rst_n)
      S_display_mode_frame <= 3'd0;
    else if(awb_O_tuser)
      S_display_mode_frame <= I_display_mode;
  end
  
  //assign m_aixs_tready = O_tready;
  //assign O_tdata  = m_aixs_tdata;
  //assign O_tlast  = m_aixs_tlast    ;
  //assign O_tuser  = m_aixs_tuser    ;
  //assign O_tvalid = m_aixs_tvalid   ;
 
 
demosaic #(
    .IMG_HEIGHT          (720 ), // 图像高度
    .IMG_WIDTH           (1280), // 图像宽度
    .data_complete_delay (50  ),
    .BAYER_MODE          ("BGGR")
)
u_demosaic
(
    .I_clk   			(axi4s_video_aclk)	,   // 时钟信号
    .I_rst_n 			(I_rst_n)	,   // 复位信号，低有效
    .axi4s_video_tdata 	(I_tdata)	,  // AXI4-Stream视频数据
    .axi4s_video_tdest 	(I_tdest)	,
    .axi4s_video_tlast 	(I_tlast)	,  // 行结束信号
    .axi4s_video_tvalid	(I_tvalid)	,  // 数据有效信号
    .axi4s_video_tuser 	(I_tuser)	,  // 帧开始信号
    .axi4s_video_tready	(I_tready)	,  // 从模块准备好接受数据
    .O_tlast  			(m_aixs_tlast)	,  // 输出行结束信号
    .O_tuser  			(m_aixs_tuser)	,  // 输出帧开始信号
    .O_tdata  			(m_aixs_tdata)	,  // 输出数据
    .O_tvalid 			(m_aixs_tvalid)	,  // 输出数据有效信号
    .O_tready   		(m_aixs_tready)	   // 输出数据准备好信号
);
 
data128_96 u_data128_96 (
    .I_tdata(m_aixs_tdata),
    .O_tdata(m_aixs_tdata_96)
);

awb #(
    .IMG_HEIGHT(720 ),
    .IMG_WIDTH (1280)
) u_awb (
    .I_clk   (axi4s_video_aclk),
    .I_rst_n (I_rst_n),
    .I_awb_enable(I_awb_enable),
    .I_tlast (m_aixs_tlast),
    .I_tuser (m_aixs_tuser),
    .I_tdata (m_aixs_tdata_96),
    .I_tvalid(m_aixs_tvalid),
    .I_tready(m_aixs_tready),
    .O_tlast (awb_O_tlast ),
    .O_tuser (awb_O_tuser ),
    .O_tdata (awb_O_tdata ),
    .O_tvalid(awb_O_tvalid),
    .O_tready(awb_O_tready)
);

    // Normal-image path. AWB already provides RGB888 pixels packed as four
    // pixels per 96-bit beat, so it can share the same DDR format as Sobel.
    data_96bit_to_128bit u_rgb_data_96bit_to_128bit(
        .I_clk              ( axi4s_video_aclk  ),
        .I_rst_n            ( I_rst_n           ),
        .I_96b_frame_start  ( awb_O_tuser       ),
        .I_96b_valid        ( awb_O_tvalid      ),
        .I_96b_data         ( awb_O_tdata       ),
        .O_128b_frame_start ( rgb_O_tuser_128   ),
        .O_128b_valid       ( rgb_O_tvalid_128  ),
        .O_128b_data        ( rgb_O_tdata_128   )
    );

    roi_binary_96 #(
        .IMG_WIDTH        ( 1280 ),
        .IMG_HEIGHT       ( 720  ),
        .ROI_X_START      ( 160  ),
        .ROI_X_END        ( 1120 ),
        .ROI_Y_START      ( 90   ),
        .ROI_Y_END        ( 630  ),
        .BINARY_THRESHOLD ( 128  )
    ) u_roi_binary_96 (
        .I_clk    ( axi4s_video_aclk ),
        .I_rst_n  ( I_rst_n           ),
        .I_tlast  ( awb_O_tlast       ),
        .I_tuser  ( awb_O_tuser       ),
        .I_tdata  ( awb_O_tdata       ),
        .I_tvalid ( awb_O_tvalid      ),
        .O_tlast  ( roi_O_tlast       ),
        .O_tuser  ( roi_O_tuser       ),
        .O_tdata  ( roi_O_tdata       ),
        .O_tvalid ( roi_O_tvalid      )
    );

    roi_data_96bit_to_128bit u_roi_data_96bit_to_128bit (
        .I_clk              ( axi4s_video_aclk ),
        .I_rst_n            ( I_rst_n           ),
        .I_96b_frame_start  ( roi_O_tuser       ),
        .I_96b_last         ( roi_O_tlast       ),
        .I_96b_valid        ( roi_O_tvalid      ),
        .I_96b_data         ( roi_O_tdata       ),
        .O_128b_frame_start ( roi_O_tuser_128   ),
        .O_128b_last        ( roi_O_tlast_128   ),
        .O_128b_valid       ( roi_O_tvalid_128  ),
        .O_128b_data        ( roi_O_tdata_128   )
    );

    // Inspection is a parallel consumer of the 96-bit ROI stream. It does
    // not sit in the DDR/HDMI path and therefore cannot back-pressure or
    // alter the selected display stream.
    roi_feature_extract #(
        .IMG_WIDTH   ( 1280 ),
        .IMG_HEIGHT  ( 720  ),
        .ROI_X_START ( 160  ),
        .ROI_X_END   ( 1120 ),
        .ROI_Y_START ( 90   ),
        .ROI_Y_END   ( 630  )
    ) u_roi_feature_extract (
        .I_clk           ( axi4s_video_aclk ),
        .I_rst_n         ( I_rst_n           ),
        .I_tuser         ( roi_O_tuser       ),
        .I_tvalid        ( roi_O_tvalid      ),
        .I_tdata         ( roi_O_tdata       ),
        .O_feature_valid ( roi_feature_valid ),
        .O_black_count   ( roi_black_count   ),
        .O_min_x         ( roi_min_x         ),
        .O_max_x         ( roi_max_x         ),
        .O_min_y         ( roi_min_y         ),
        .O_max_y         ( roi_max_y         ),
        .O_border_count  ( roi_border_count  )
    );

    assign O_inspection_black_count = roi_black_count;
    assign O_inspection_min_x       = roi_min_x;
    assign O_inspection_max_x       = roi_max_x;
    assign O_inspection_min_y       = roi_min_y;
    assign O_inspection_max_y       = roi_max_y;
    assign O_inspection_feature_toggle = S_inspection_feature_toggle;

    always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_inspection_feature_toggle <= 1'b0;
        else if(roi_feature_valid)
            S_inspection_feature_toggle <= ~S_inspection_feature_toggle;
    end

    // Both feature streams originate from the same ROI frame. A skipped or
    // late shape calculation is discarded instead of pairing with newer area.
    always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_feature_frame_id <= 2'd0;
            S_shape_frame_id <= 2'd0;
            S_feature_area <= 20'd0;
            S_prev_min_x <= 0; S_prev_max_x <= 0;
            S_prev_min_y <= 0; S_prev_max_y <= 0;
            S_prev_valid <= 0;
            S_shape_area_snapshot <= 20'd0;
            S_clean_frames <= 2'd0;
            S_feature_ready <= 1'b0;
            S_shape_ready_snapshot <= 1'b0;
            O_quality_pair_toggle <= 1'b0;
            O_quality_pair_payload <= 46'd0;
            S_quality_ack_sync <= 2'b00;
        end else begin
            S_quality_ack_sync <= {S_quality_ack_sync[0],I_quality_pair_ack};
            if(roi_feature_valid) begin
                S_feature_frame_id <= S_feature_frame_id + 2'd1;
                S_feature_area <= roi_black_count;
                S_prev_min_x <= roi_min_x; S_prev_max_x <= roi_max_x;
                S_prev_min_y <= roi_min_y; S_prev_max_y <= roi_max_y;
                S_prev_valid <= 1;
                if(roi_black_count >= 20'd2048 &&
                   roi_border_count <= 8'd4 &&
                   (!S_prev_valid ||
                    (S_position_stable &&
                     S_area_delta <= ({1'b0,roi_black_count} >> 5)+21'd128))) begin
                    S_feature_ready <= S_clean_frames >= 2'd2;
                    if(S_clean_frames < 2'd3)
                        S_clean_frames <= S_clean_frames + 2'd1;
                end else begin
                    S_clean_frames <= 2'd0;
                    S_feature_ready <= 1'b0;
                end
            end
            if(S_axis_accept) begin
                S_shape_frame_id <= S_feature_frame_id;
                S_shape_area_snapshot <= S_feature_area;
                S_shape_ready_snapshot <= S_feature_ready;
            end
            if(S_axis_valid_pulse && !S_axis_valid &&
               S_shape_frame_id == S_feature_frame_id &&
               O_quality_pair_toggle == S_quality_ack_sync[1]) begin
                O_quality_pair_payload <= {
                    S_shape_area_snapshot, 11'd0, 11'd0,
                    3'b000, S_shape_ready_snapshot
                };
                O_quality_pair_toggle <= ~O_quality_pair_toggle;
            end else if(S_shape_match_done &&
               S_shape_frame_id == S_feature_frame_id &&
               O_quality_pair_toggle == S_quality_ack_sync[1]) begin
                O_quality_pair_payload <= {
                    S_shape_area_snapshot,
                    S_shape_match_score, S_shape_match_union,
                    S_shape_match_valid, S_shape_match_ok,
                    S_shape_match_captured, S_shape_ready_snapshot
                };
                O_quality_pair_toggle <= ~O_quality_pair_toggle;
            end
        end
    end

    inspection_decision #(
        .OBJECT_MIN_BLACK_PIXELS ( 2048  ),
        .OBJECT_MAX_BLACK_PIXELS ( 518400),
        .BBOX_MIN_WIDTH          ( 64    ),
        .BBOX_MIN_HEIGHT         ( 64    ),
        .STABLE_FRAMES           ( 3     )
    ) u_inspection_decision (
        .I_clk                   ( axi4s_video_aclk       ),
        .I_rst_n                 ( I_rst_n                 ),
        .I_feature_valid         ( roi_feature_valid       ),
        .I_black_count           ( roi_black_count         ),
        .I_min_x                 ( roi_min_x               ),
        .I_max_x                 ( roi_max_x               ),
        .I_min_y                 ( roi_min_y               ),
        .I_max_y                 ( roi_max_y               ),
        .O_object_present        ( O_inspection_object     ),
        .O_result_update_toggle  ( O_inspection_update_toggle )
    );

    // Shape-analysis branch. It consumes the existing ROI binary stream in
    // parallel with the display packer and never drives video back-pressure.
    roi_binary_frame_buffer #(
        .IMG_WIDTH(1280), .IMG_HEIGHT(720),
        .ROI_X_START(160), .ROI_X_END(1120),
        .ROI_Y_START(90), .ROI_Y_END(630)
    ) u_roi_binary_frame_buffer (
        .I_clk          (axi4s_video_aclk),
        .I_rst_n        (I_rst_n),
        .I_tuser        (roi_O_tuser),
        .I_tvalid       (roi_O_tvalid),
        .I_tdata        (roi_O_tdata),
        .I_read_en      (S_rotate_source_req),
        .I_read_addr    (S_shape_read_addr),
        .I_read_bit_sel (S_shape_read_bit_sel),
        .O_read_pixel   (S_shape_buffer_pixel),
        .O_frame_toggle (S_shape_buffer_toggle),
        .O_frame_valid  (S_shape_buffer_valid)
    );

    roi_moment_stats #(
        .IMG_WIDTH(1280), .IMG_HEIGHT(720),
        .ROI_X_START(160), .ROI_X_END(1120),
        .ROI_Y_START(90), .ROI_Y_END(630)
    ) u_roi_moment_stats (
        .I_clk     (axi4s_video_aclk),
        .I_rst_n   (I_rst_n),
        .I_tuser   (roi_O_tuser),
        .I_tvalid  (roi_O_tvalid),
        .I_tdata   (roi_O_tdata),
        .O_valid   (S_moment_valid),
        .O_m00     (S_m00), .O_m10(S_m10), .O_m01(S_m01),
        .O_m20     (S_m20), .O_m02(S_m02), .O_m11(S_m11),
        .O_min_x   (S_moment_min_x), .O_max_x(S_moment_max_x),
        .O_min_y   (S_moment_min_y), .O_max_y(S_moment_max_y)
    );

    roi_axis_calc u_roi_axis_calc (
        .I_clk       (axi4s_video_aclk),
        .I_rst_n     (I_rst_n),
        .I_valid     (S_moment_valid),
        .I_m00       (S_m00), .I_m10(S_m10), .I_m01(S_m01),
        .I_m20       (S_m20), .I_m02(S_m02), .I_m11(S_m11),
        .O_valid     (S_axis_valid_pulse),
        .O_accept    (S_axis_accept),
        .O_axis_valid(S_axis_valid),
        .O_angle_bin (S_axis_angle),
        .O_cx        (S_axis_cx), .O_cy(S_axis_cy),
        .O_extent    (S_axis_extent),
        .O_cos       (S_axis_cos), .O_sin(S_axis_sin)
    );

    always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_shape_rotate_start <= 1'b0;
        else
            S_shape_rotate_start <= S_axis_valid_pulse && S_axis_valid;
    end

    roi_rotate_normalize u_roi_rotate_normalize (
        .I_clk         (axi4s_video_aclk),
        .I_rst_n       (I_rst_n),
        .I_start       (S_shape_rotate_start),
        .I_axis_valid  (S_axis_valid),
        .I_angle_bin   (S_axis_angle),
        .I_cx          (S_axis_cx), .I_cy(S_axis_cy),
        .I_extent      (S_axis_extent),
        .I_cos         (S_axis_cos), .I_sin(S_axis_sin),
        .I_min_x       (S_moment_min_x), .I_max_x(S_moment_max_x),
        .I_min_y       (S_moment_min_y), .I_max_y(S_moment_max_y),
        .I_source_pixel(S_shape_buffer_pixel),
        .O_source_req  (S_rotate_source_req),
        .O_source_x    (S_rotate_source_x), .O_source_y(S_rotate_source_y),
        .O_valid       (S_rotate_valid),
        .O_dst_x       (S_rotate_dst_x), .O_dst_y(S_rotate_dst_y),
        .O_pixel       (S_rotate_pixel), .O_done(S_rotate_done)
    );

    assign S_shape_read_addr = (S_rotate_source_y * 18'd60) +
                               (S_rotate_source_x >> 2);
    assign S_shape_read_bit_sel = S_rotate_source_x[1:0];

    shape_template_match #(.SCORE_THRESHOLD(320)) u_shape_template_match (
        .I_clk        (axi4s_video_aclk),
        .I_rst_n      (I_rst_n),
        .I_start      (S_shape_rotate_start),
        .I_valid      (S_rotate_valid),
        .I_pixel      (S_rotate_pixel),
        .I_x          (S_rotate_dst_x), .I_y(S_rotate_dst_y),
        .I_axis_valid (S_axis_valid),
        .I_calibrate  (I_shape_calibrate),
        .O_done       (S_shape_match_done),
        .O_valid      (S_shape_match_valid),
        .O_ok         (S_shape_match_ok),
        .O_score      (S_shape_match_score)
        ,.O_union    (S_shape_match_union)
        ,.O_captured (S_shape_match_captured)
    );

    assign S_shape_result_valid = S_shape_match_done;

    shape_match_fusion u_shape_match_fusion (
        .I_clk          (axi4s_video_aclk),
        .I_rst_n        (I_rst_n),
        .I_axis_update  (S_axis_valid_pulse),
        .I_axis_valid   (S_axis_valid),
        .I_angle_bin    (S_axis_angle),
        .I_match_update (S_shape_result_valid),
        .I_match_valid  (S_shape_match_valid),
        .I_match_ok     (S_shape_match_ok),
        .I_match_score  (S_shape_match_score),
        .O_update_toggle(S_shape_result_toggle),
        .O_valid        (S_shape_fusion_valid),
        .O_result_code  (S_shape_result_code),
        .O_score        (S_shape_score),
        .O_angle_bin    (S_shape_angle)
    );

    assign O_shape_update_toggle = S_shape_result_toggle;
    assign O_shape_valid = S_shape_fusion_valid;
    assign O_shape_result_code = S_shape_result_code;
    assign O_shape_score = S_shape_score;
    assign O_shape_angle = S_shape_angle;


edge_detect_96 #(
    .IMG_WIDTH  (1280),
    .IMG_HEIGHT (720),
    .EDGE_TH    (11'd120)
) u_edge_detect_96 (
    .I_clk    (axi4s_video_aclk),
    .I_rst_n  (I_rst_n),
    .I_tlast  (awb_O_tlast),
    .I_tuser  (awb_O_tuser),
    .I_tdata  (awb_O_tdata),
    .I_tvalid (awb_O_tvalid),
    .I_tready (O_tready),
    .O_tlast  (edge_O_tlast),
    .O_tuser  (edge_O_tuser),
    .O_tdata  (edge_O_tdata),
    .O_tvalid (edge_O_tvalid),
    .O_tready (edge_O_tready),
    .O_gray_data (edge_gray_O_tdata)
 );

    data_96bit_to_128bit u_data_96bit_to_128bit(
        .I_clk              ( axi4s_video_aclk  ),
        .I_rst_n            ( I_rst_n           ),
	
        .I_96b_frame_start  ( edge_O_tuser ),
        .I_96b_valid        ( edge_O_tvalid ),
        .I_96b_data         ( edge_O_tdata ),
	
        .O_128b_frame_start ( edge_O_tuser_128 ),
        .O_128b_valid       ( edge_O_tvalid_128 ),
        .O_128b_data        ( edge_O_tdata_128 )
    );



//data96_128 u_data96_128 (
//    .I_tdata(awb_O_tdata),
//    .O_tdata(awb_O_tdata_128)
//);
	
endmodule
