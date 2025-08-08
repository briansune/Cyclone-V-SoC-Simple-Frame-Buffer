// ===========================================================================
// Updates / Reports / Modifications
// ===========================================================================
// Autor: BrianSune
// Date: 2025/08
// ===========================================================================
//                      DVI / HDMI Framebuffer V0.1
// github.com/ultraembedded, Email: admin@ultra-embedded.com, License: MIT
// ===========================================================================

`timescale 1ns/1ns

`include "dvi_framebuffer_defs.v"

//-----------------------------------------------------------------
// Module:  DVI Framebuffer
//-----------------------------------------------------------------
module dvi_framebuffer
//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
#(
     parameter [0:0]   VIDEO_ENABLE     = 1'b1
    ,parameter [0:0]   VIDEO_X2_MODE    = 1'b1
    ,parameter [31:0]  VIDEO_FB_RAM     = 32'h1E00_0000
    ,parameter [3:0]   BURST_LEN        = 4'd15
	,parameter integer BUFFER_SIZE		= 2048
    ,parameter integer axi3_bw          = 256
)
//-----------------------------------------------------------------
// Ports
//-----------------------------------------------------------------
(
    
	input			vid_pclk_i
	,input			vid_nrst_i
	
	,output			vid_hsync_o
	,output			vid_vsync_o
	,output			vid_den_o
	,output	[23:0]	vid_data_o
	
	// ,output         intr_o
	
	// ================================================
	// APB Interface
	// For configurations and Settings
	// ================================================
	,input							cfg_clk_i
    ,input							cfg_nrst_i
	
	,input		[11:0]				cfg_paddr_i
	,input							cfg_penable_i
	,input							cfg_pwrite_i
	,input		[31:0]				cfg_pwdata_i
	,input							cfg_psel_i
	,output reg	[31:0]				cfg_prdata_o
	,output reg						cfg_pready_o
	// ================================================
    
	// ================================================
	// AXI3
	// ================================================
	,input						outport_clk_i
	,input						outport_nrst_i
	
	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	// Address Read Group
	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	,input						outport_arready_i
	,output		[31:0]			outport_araddr_o
	,output		[3:0]			outport_arlen_o
	,output		[7:0]			outport_arid_o
	,output		[2:0]			outport_arsize_o
	,output		[1:0]			outport_arburst_o
	,output		[1:0]			outport_arlock_o
	,output		[2:0]			outport_arprot_o
	,output						outport_arvalid_o
	,output		[3:0]			outport_arcache_o
	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	
	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	// Address Write Group
	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	,input						outport_awready_i
	,output		[31:0]			outport_awaddr_o
	,output		[3:0]			outport_awlen_o
	,output		[7:0]			outport_awid_o
	,output		[2:0]			outport_awsize_o
	,output		[1:0]			outport_awburst_o
	,output		[1:0]			outport_awlock_o
	,output		[2:0]			outport_awprot_o
	,output						outport_awvalid_o
    ,output		[3:0]			outport_awcache_o
	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	
	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	// Read Group
	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ,input		[axi3_bw-1:0]	outport_rdata_i
    ,input		[1:0]			outport_rresp_i
    ,input						outport_rlast_i
    ,input		[7:0]			outport_rid_i
    ,input						outport_rvalid_i
	,output						outport_rready_o
	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	
	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	// Write Group
	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ,output							outport_wlast_o
    ,output		[axi3_bw-1:0]		outport_wdata_o
    ,output		[(axi3_bw/8)-1:0]   outport_wstrb_o
	,input							outport_wready_i
    ,output							outport_wvalid_o
	,output		[7:0]				outport_wid_o
	
	,input		[1:0]			outport_bresp_i
    ,input		[7:0]			outport_bid_i
	,input						outport_bvalid_i
    ,output						outport_bready_o
);
	
    // Register storage
    reg [31:0] config_reg;
    reg [31:0] status_reg;
    reg [31:0] frame_buffer_reg;

    // Address decoding (assume word aligned)
    wire sel_config       = (cfg_paddr_i[11:0] == 12'h000);
    wire sel_status       = (cfg_paddr_i[11:0] == 12'h004);
    wire sel_frame_buffer = (cfg_paddr_i[11:0] == 12'h008);

    // APB ready logic (simple 1-cycle ready)
    always @(posedge cfg_clk_i or negedge cfg_nrst_i)
    if (!cfg_nrst_i)
        cfg_pready_o <= 1'b0;
    else
        cfg_pready_o <= cfg_psel_i & cfg_penable_i;

    // Register write
    always @(posedge cfg_clk_i or negedge cfg_nrst_i)
    if (!cfg_nrst_i) begin
		
		config_reg[`CONFIG_X2_MODE_R]		<= VIDEO_X2_MODE;
		config_reg[`CONFIG_INT_EN_SOF_R]	<= 1'd`CONFIG_INT_EN_SOF_DEFAULT;
		config_reg[`CONFIG_ENABLE_R]		<= VIDEO_ENABLE;
        config_reg[31:3]					<= 29'd0;
		
		frame_buffer_reg					<= ( VIDEO_FB_RAM / (16 * (64/8)) );
		
        // status_reg        <= 32'h0;
		
    end else if (cfg_psel_i && cfg_penable_i && cfg_pwrite_i) begin
        if (sel_config)
            config_reg <= cfg_pwdata_i;
        else if (sel_frame_buffer)
            frame_buffer_reg <= cfg_pwdata_i;
        // `status_reg` is read-only (written by hardware elsewhere)
    end
	
	wire [15:0]  status_y_pos_in_w;
	wire [15:0]  status_h_pos_in_w;
	
    // Register read
    always @(posedge cfg_clk_i or negedge cfg_nrst_i)
    if (!cfg_nrst_i) begin
        cfg_prdata_o <= 32'h0;
    end else if (cfg_psel_i && cfg_penable_i && !cfg_pwrite_i) begin
        if (sel_config)
            cfg_prdata_o <= config_reg;
        else if (sel_status)
            cfg_prdata_o <= {status_y_pos_in_w, status_h_pos_in_w};
        else if (sel_frame_buffer)
            cfg_prdata_o <= frame_buffer_reg;
        else
            cfg_prdata_o <= 32'hDEADBEEF;  // default if unmapped
    end
	
	wire config_x2_mode_out_w		= config_reg[`CONFIG_X2_MODE_R];
	wire config_int_en_sof_out_w	= config_reg[`CONFIG_INT_EN_SOF_R];
	wire config_enable_out_w		= config_reg[`CONFIG_ENABLE_R];
	
	localparam integer bw_fbiff_a	= 32 - 7;
	
	wire [bw_fbiff_a-1:0]  frame_buffer_addr_out_w = frame_buffer_reg[0+:bw_fbiff_a];
	
	// XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
	// Cross Clock Domain enable, x2 mode
	// XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
	reg		ccd_config_enable_out_r0;
	reg		ccd_config_enable_out_r1;
	
	always @ (posedge vid_pclk_i)begin
		ccd_config_enable_out_r0 <= config_enable_out_w;
		ccd_config_enable_out_r1 <= ccd_config_enable_out_r0;
	end
	
	reg		ccd_config_x2_mode_out_r0;
	reg		ccd_config_x2_mode_out_r1;
	
	always @ (posedge vid_pclk_i)begin
		ccd_config_x2_mode_out_r0 <= config_x2_mode_out_w;
		ccd_config_x2_mode_out_r1 <= ccd_config_x2_mode_out_r0;
	end
	
	reg		[bw_fbiff_a-1:0]  ccd_fbuff_add_r0;
	reg		[bw_fbiff_a-1:0]  ccd_fbuff_add_r1;
	
	always @ (posedge outport_clk_i)begin
		ccd_fbuff_add_r0 <= frame_buffer_addr_out_w;
		ccd_fbuff_add_r1 <= ccd_fbuff_add_r0;
	end
	
	// reg		ccd_op_x2_mode_out_r0;
	// reg		ccd_op_x2_mode_out_r1;
	
	// always @ (posedge outport_clk_i)begin
		// ccd_op_x2_mode_out_r0 <= config_x2_mode_out_w;
		// ccd_op_x2_mode_out_r1 <= ccd_op_x2_mode_out_r0;
	// end
	// XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
	
	//-----------------------------------------------------------------
	// Video Timings
	//-----------------------------------------------------------------
	wire	[13 : 0]	pixel_x_w;
	
	wire	[13 : 0]	h_pos_w;
	wire	[13 : 0]	v_pos_w;
	
	assign status_h_pos_in_w = {2'b00, h_pos_w};
	assign status_y_pos_in_w = {2'b00, v_pos_w};
	
	wire	[255 : 0]	pixel_data_w;
	
	wire				vid_den_w;
	
	video_timing_ctrl vid_tim_u0(
		
		.pixel_clock		(vid_pclk_i),
		.nrst				(vid_nrst_i),
		
		.pixel_x			(pixel_x_w),
		
		.timing_h_pos		(h_pos_w),
		.timing_v_pos		(v_pos_w),
		
		.video_vsync		(vid_vsync_o),
		.video_hsync		(vid_hsync_o),
		.video_den			(vid_den_w)
	);
	
	reg		dly_den_r0;
	reg		dly_den_r1;
	reg		dly_den_r2;
	
	always@(posedge vid_pclk_i)begin
		dly_den_r0 <= vid_den_w;
		dly_den_r1 <= dly_den_r0;
		dly_den_r2 <= dly_den_r1;
	end
	
	assign vid_den_o = dly_den_r2;
	
	reg		[2 : 0]		bsf_cnt;
	reg		[2 : 0]		bsf_cnt_r0;
	
	always@(posedge vid_pclk_i or negedge vid_nrst_i)begin
		if (!vid_nrst_i)begin
			bsf_cnt <= 3'd0;
		end else if(dly_den_r0)begin
			bsf_cnt <= bsf_cnt + 1'b1;
		end else begin
			bsf_cnt <= 3'd0;
		end
	end
	
	reg		[23 : 0]	vid_dout;
	
	always@(posedge vid_pclk_i or negedge vid_nrst_i)begin
		if (!vid_nrst_i)begin
			bsf_cnt_r0 <= 3'd0;
			vid_dout <= 24'd0;
		end else begin
			bsf_cnt_r0 <= bsf_cnt;
			case(bsf_cnt_r0)
				3'd0: vid_dout <= pixel_data_w[(32*0)+:24];
				3'd1: vid_dout <= pixel_data_w[(32*1)+:24];
				3'd2: vid_dout <= pixel_data_w[(32*2)+:24];
				3'd3: vid_dout <= pixel_data_w[(32*3)+:24];
				3'd4: vid_dout <= pixel_data_w[(32*4)+:24];
				3'd5: vid_dout <= pixel_data_w[(32*5)+:24];
				3'd6: vid_dout <= pixel_data_w[(32*6)+:24];
				3'd7: vid_dout <= pixel_data_w[(32*7)+:24];
			endcase
		end
	end
	
	assign vid_data_o = vid_dout;
	
	wire fifo_rd = dly_den_r0 & (bsf_cnt == 3'd0);
	
	//-----------------------------------------------------------------
	// Pixel fetch FIFO
	//-----------------------------------------------------------------
	
	wire fifo_wr = outport_rvalid_i & outport_rready_o;
	
	wire fifo_flush = (!ccd_vsync_r2 & ccd_vsync_r1) & (!ccd_hsync_r2 & ccd_hsync_r1);
	
	dvi_fifo line_buffer(
		
		.wrclk			(outport_clk_i),
		.aclr			(fifo_flush),

		.wrreq			(fifo_wr),
		.data			(outport_rdata_i),
		.wrfull			(),

		.rdclk			(vid_pclk_i),
		.rdempty		(),
		.q				(pixel_data_w),
		.rdreq			(fifo_rd)
	);
	
	//-----------------------------------------------------------------
	// FIFO allocation
	//-----------------------------------------------------------------
	localparam [31:0] fetch_bytes	= ( (BURST_LEN + 1) * (axi3_bw / 8) );
	localparam [31:0] frame_last	= VIDEO_FB_RAM + (1920*1080*4);
	
	//-----------------------------------------------------------------
	// AXI Request
	//-----------------------------------------------------------------
	reg		ccd_hsync_r0;
	reg		ccd_hsync_r1;
	reg		ccd_hsync_r2;
	
	reg		ccd_vsync_r0;
	reg		ccd_vsync_r1;
	reg		ccd_vsync_r2;
	
	always @ (posedge outport_clk_i)begin
		ccd_hsync_r0 <= vid_hsync_o;
		ccd_hsync_r1 <= ccd_hsync_r0;
		ccd_hsync_r2 <= ccd_hsync_r1;
		
		ccd_vsync_r0 <= vid_vsync_o;
		ccd_vsync_r1 <= ccd_vsync_r0;
		ccd_vsync_r2 <= ccd_vsync_r1;
	end
	
	localparam integer axia_cnt_bw = $clog2(BUFFER_SIZE);
	
	(* keep *) reg		[axia_cnt_bw-1:0]		axia_cnt;
	
	always@(posedge outport_clk_i)begin
		if (fifo_flush)begin
			axia_cnt <= 0;
		end else begin
			if(
				outport_arvalid_o & outport_arready_i
			)begin
				if(fifo_rd)
					axia_cnt <= axia_cnt + 15;
				else
					axia_cnt <= axia_cnt + 16;
			end else if(
				(axia_cnt >= 1) & fifo_rd
			)begin
				axia_cnt <= axia_cnt - 1'b1;
			end
		end
	end
	
	reg 	[31 : 0]	araddr_q;
	
	always@(posedge outport_clk_i or negedge outport_nrst_i)begin
		if (!outport_nrst_i)begin
			araddr_q <= {ccd_fbuff_add_r1, 7'b000_0000};
		end else begin
			if(
				(!ccd_vsync_r2 & ccd_vsync_r1) &
				(!ccd_hsync_r2 & ccd_hsync_r1)
			)begin
				araddr_q <= {ccd_fbuff_add_r1, 7'b000_0000};
			end else if(
				outport_arvalid_o & outport_arready_i & (araddr_q < frame_last)
			)begin
				araddr_q <= araddr_q + fetch_bytes;
			end
		end
	end

	reg        arvalid_q;
	
	always @ (posedge outport_clk_i or negedge outport_nrst_i) begin
		if (!outport_nrst_i)begin
			arvalid_q <= 1'b0;
		end else begin
			if (
				!outport_arvalid_o & outport_arready_i &
				(araddr_q < frame_last) &
				( axia_cnt < (BUFFER_SIZE-32) )
			)
				arvalid_q <= 1'b1;
			else if(outport_arvalid_o & outport_arready_i)
				arvalid_q <= 1'b0;
		end
	end
	
	assign outport_araddr_o		= araddr_q;
	assign outport_arvalid_o	= arvalid_q;
	assign outport_rready_o		= 1'b1;
	
	assign outport_arburst_o	= 2'b01;
	assign outport_arlen_o		= BURST_LEN;
	assign outport_arsize_o 	= 3'b101;
	
	assign outport_arid_o		= 8'd0;	// Master sets ID to 0
	
	assign outport_arlock_o		= 2'b00;	// Normal access
	assign outport_arprot_o		= 3'b000;	// Secure, privileged, data
	assign outport_arcache_o	= 4'b0000;	// Non-cacheable, non-bufferable
	
	
	// ====================================================
	// write group
	// ====================================================
	assign outport_awaddr_o  = 32'h0;
	assign outport_awlen_o   = 4'h0;
	assign outport_awid_o    = 8'h0;
	assign outport_awsize_o  = 3'b000;
	assign outport_awburst_o = 2'b01;
	assign outport_awlock_o  = 2'b00;
	assign outport_awprot_o  = 3'b000;
	assign outport_awcache_o = 4'b0000;
	assign outport_awvalid_o = 1'b0;
	
	assign outport_wdata_o   = 256'h0;
	assign outport_wstrb_o   = 8'h0;
	assign outport_wlast_o   = 1'b0;
	assign outport_wvalid_o  = 1'b0;
	assign outport_wid_o     = 8'h0;
	
	assign outport_bready_o  = 1'b0;
	// ====================================================
	
	//-----------------------------------------------------------------
	// Interrupt output
	// This interrupt is not clock dependent on the interface
	// edge or level trigger
	//-----------------------------------------------------------------
	// reg		irq_op_ccd;
	
	// always @ (posedge outport_clk_i)begin
		// irq_op_ccd <= (fetch_h_pos_q == 12'b0 && fetch_v_pos_q == 12'b0);
	// end
	
	// reg		irq_cfg_ccd_r0;
	// reg		irq_cfg_ccd_r1;
	
	// always @ (posedge cfg_clk_i)begin
		// irq_cfg_ccd_r0 <= irq_op_ccd;
		// irq_cfg_ccd_r1 <= irq_cfg_ccd_r0;
	// end
	
	// reg intr_q;

	// always @ (posedge cfg_clk_i or negedge cfg_nrst_i)
	// if (!cfg_nrst_i)
		// intr_q <= 1'b0;
	// else if (config_int_en_sof_out_w & irq_cfg_ccd_r1)
		// intr_q <= 1'b1;
	// else
		// intr_q <= 1'b0;

	// assign intr_o = intr_q;
	
endmodule
