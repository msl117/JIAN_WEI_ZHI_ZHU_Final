// Shape-only 4x4 subsampling, sampled at the centre of each cell.
// Full-resolution display, area and bounding-box paths are independent.
// Four samples per RAM word; padded banks make bank selection a wire.
module roi_binary_frame_buffer #(
    parameter integer IMG_WIDTH=1280, IMG_HEIGHT=720,
    parameter integer ROI_X_START=160, ROI_X_END=1120,
    parameter integer ROI_Y_START=90, ROI_Y_END=630
)(
    input wire I_clk, I_rst_n, I_tuser, I_tvalid,
    input wire [95:0] I_tdata,
    input wire I_read_en,
    input wire [17:0] I_read_addr,
    input wire [1:0] I_read_bit_sel,
    output reg O_read_pixel, O_frame_toggle, O_frame_valid
);
    localparam integer WORDS_PER_LINE=(ROI_X_END-ROI_X_START)/16;
    localparam integer DEPTH=WORDS_PER_LINE*((ROI_Y_END-ROI_Y_START)/4);
    localparam integer BANK_BITS=$clog2(DEPTH);
    reg [3:0] S_mem [0:(2**(BANK_BITS+1))-1];
    reg [8:0] S_x;
    reg [10:0] S_y;
    reg S_write_bank, S_read_bank;
    reg [2:0] S_pack;
    reg S_write_en;
    reg [BANK_BITS:0] S_write_addr;
    reg [3:0] S_write_data;
    wire [8:0] x=I_tuser ? 9'd0 : S_x;
    wire [10:0] y=I_tuser ? 11'd0 : S_y;
    wire [8:0] lx=x-ROI_X_START/4;
    wire [10:0] ly=y-ROI_Y_START;
    wire sample=I_tvalid && x>=ROI_X_START/4 && x<ROI_X_END/4 &&
                y>=ROI_Y_START && y<ROI_Y_END && ly[1:0]==2;
    wire pixel=(I_tdata[71:48]==24'h000000);
    wire [BANK_BITS-1:0] addr=(ly>>2)*WORDS_PER_LINE+(lx>>2);
    wire last=I_tvalid && x==IMG_WIDTH/4-1 && y==IMG_HEIGHT-1;

    // Synchronous RAM without reset on the storage array.
    always @(posedge I_clk) begin
        if(S_write_en) S_mem[S_write_addr]<=S_write_data;
        if(I_read_en && I_read_addr<DEPTH)
            O_read_pixel<=S_mem[{S_read_bank,I_read_addr[BANK_BITS-1:0]}][I_read_bit_sel];
    end
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_x<=0; S_y<=0; S_write_bank<=0; S_read_bank<=1;
            S_pack<=0; S_write_en<=0; S_write_addr<=0; S_write_data<=0;
            O_frame_toggle<=0; O_frame_valid<=0;
        end else begin
            O_frame_valid<=0;
            S_write_en<=0;
            if(sample) begin
                case(lx[1:0])
                    0:S_pack[0]<=pixel;
                    1:S_pack[1]<=pixel;
                    2:S_pack[2]<=pixel;
                    3:begin
                        S_write_en<=1;
                        S_write_addr<={S_write_bank,addr};
                        S_write_data<={pixel,S_pack};
                    end
                endcase
            end
            if(I_tuser) begin S_x<=0; S_y<=0; end
            if(I_tvalid) begin
                if(x==IMG_WIDTH/4-1) begin S_x<=0; S_y<=y+1'b1; end
                else begin S_x<=x+1'b1; S_y<=y; end
                if(last) begin
                    S_x<=0; S_y<=0;
                    S_read_bank<=S_write_bank;
                    S_write_bank<=~S_write_bank;
                    O_frame_toggle<=~O_frame_toggle;
                    O_frame_valid<=1;
                end
            end
        end
    end
endmodule
