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

## Device Tree

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
