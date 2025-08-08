# The Video DMA via Simple Frame Buffer

## References

+ Highly based on "https://github.com/ultraembedded/core_dvi_framebuffer".

  + Plug and use is 100% fail on HPS.

  + ultraembedded design uses AXI-Lite and AXI4 which is not supported on HPS

  + ultraembedded verilog HDL design is so messy and modification on the FIFO is tedious

  + ultraembedded fifo and control design is all in the same clock domain which make no sense.

+ Chat GPT - GPT-5 model

## Block Diagram

<img width="461" height="202" alt="sfv" src="https://github.com/user-attachments/assets/d52c0d5e-33dd-4ac3-be29-1a27ded67267" />

## Limitations or ToDo

1) APB register is not use for control

2) APB register can changed to control VDMA easily

3) No complex design very lightweight

4) Current design is just made to work but not welly design as well

5) Hard coded address and control

6) !!! VERY-IMPORTANT !!! To use the 1080p on C8 C7 I7 speed grade, you must override to C6.

## Device Tree - DTS

```
	reserved-memory {
		#address-cells = <1>;
		#size-cells = <1>;
		ranges;

		framebuffer_mem: framebuffer_mem@1E000000 {
			reg = <0x1E000000 0x7E9000>; // 1920 * 1080 * 4 = 0x7E9000
			no-map;
		};
	};

	framebuffer0: framebuffer@1E000000 {
		compatible = "simple-framebuffer";
		reg = <0x1E000000 (1920 * 1080 * 4)>;
		width = <1920>;
		height = <1080>;
		stride = <(1920 * 4)>;
		format = "a8r8g8b8";
		memory-region = <&framebuffer_mem>;
	}; 
```

## Verilog Instantiation

```
hdmi_test hdmi_test_inst0(
		
		.clk_200m_p		(clk_200m_p),
		.clk_200m_n		(clk_200m_n),
		
		.hdmi_clk_p		(hdmi_clk_p),
		.hdmi_clk_n		(hdmi_clk_n),
		
		.hdmi_d0_p		(hdmi_d0_p),
		.hdmi_d0_n		(hdmi_d0_n),
		
		.hdmi_d1_p		(hdmi_d1_p),
		.hdmi_d1_n		(hdmi_d1_n),
		
		.hdmi_d2_p		(hdmi_d2_p),
		.hdmi_d2_n		(hdmi_d2_n),
		
		.dvi_data		(vid_data_w),
		.dvi_hsync		(vid_hsync_w),
		.dvi_vsync		(vid_vsync_w),
		.dvi_den		(vid_den_w),
		
		.vid_pclk		(axi3_clk)
	);
	
	dvi_framebuffer#(
		
		.VIDEO_ENABLE		(1),
		.VIDEO_X2_MODE		(1),
		.VIDEO_FB_RAM		(32'h1E00_0000)
		
	)axi3_sfb_inst(

		// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
		// clock domain: 148.5MHz
		// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
		.vid_pclk_i			(axi3_clk),
		.vid_nrst_i			(hps_0_h2f_reset_reset_n),
		
		.vid_hsync_o		(vid_hsync_w),
		.vid_vsync_o		(vid_vsync_w),
		.vid_den_o			(vid_den_w),
		.vid_data_o			(vid_data_w),
		
		// .intr_o				(irq0_w[0]),
		
		// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
		// Clock domain: h2c_clk0,1,2 100MHz
		// Reset domain: h2f_lw_clk - nrst
		// Configuration do not require high speed
		// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
		
		.cfg_clk_i				(clock_bridge_0_out_clk_clk),
		.cfg_nrst_i				(hps_0_h2f_reset_reset_n),
		
		.cfg_paddr_i			(apb_vid_paddr),
		.cfg_psel_i				(apb_vid_psel),
		.cfg_penable_i			(apb_vid_penable),
		.cfg_pwrite_i			(apb_vid_pwrite),
		.cfg_pwdata_i			(apb_vid_pwdata),
		.cfg_prdata_o			(apb_vid_prdata),
		.cfg_pready_o			(apb_vid_pready),
		
		// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
		// clock domain: 148.5MHz
		// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
		
		.outport_clk_i			(axi3_clk),
		.outport_nrst_i			(hps_0_h2f_reset_reset_n),
		// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		.outport_arready_i		(axi3_arready) ,
		.outport_araddr_o		(axi3_araddr) ,
		.outport_arlen_o		(axi3_arlen) ,
		.outport_arid_o			(axi3_arid) ,
		.outport_arsize_o		(axi3_arsize) ,
		.outport_arburst_o		(axi3_arburst) ,
		.outport_arlock_o		(axi3_arlock) ,
		.outport_arprot_o		(axi3_arprot) ,
		.outport_arvalid_o		(axi3_arvalid) ,
		.outport_arcache_o		(axi3_arcache) ,
		// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		.outport_awready_i		(axi3_awready) ,
		.outport_awaddr_o		(axi3_awaddr) ,
		.outport_awlen_o		(axi3_awlen) ,
		.outport_awid_o			(axi3_awid) ,
		.outport_awsize_o		(axi3_awsize) ,
		.outport_awburst_o		(axi3_awburst) ,
		.outport_awlock_o		(axi3_awlock) ,
		.outport_awprot_o		(axi3_awprot) ,
		.outport_awvalid_o		(axi3_awvalid) ,
		.outport_awcache_o		(axi3_awcache) ,
		// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		.outport_rdata_i		(axi3_rdata) ,
		.outport_rresp_i		(axi3_rresp) ,
		.outport_rlast_i		(axi3_rlast) ,
		.outport_rid_i			(axi3_rid) ,
		.outport_rvalid_i		(axi3_rvalid) ,
		.outport_rready_o		(axi3_rready) ,
		// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		.outport_wlast_o		(axi3_wlast) ,
		.outport_wdata_o		(axi3_wdata) ,
		.outport_wstrb_o		(axi3_wstrb) ,
		.outport_wready_i		(axi3_wready) ,
		.outport_wvalid_o		(axi3_wvalid) ,
		.outport_wid_o			(axi3_wid) ,
		
		.outport_bresp_i		(axi3_bresp) ,
		.outport_bid_i			(axi3_bid) ,
		.outport_bvalid_i		(axi3_bvalid) ,
		.outport_bready_o		(axi3_bready)
	);
```
