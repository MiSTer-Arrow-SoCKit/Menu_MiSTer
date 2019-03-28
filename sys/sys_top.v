//=================================================================================================
//
//	 MenuCore for DE10-standard / DE1-soc kit
//  hardware abstraction module (based on MiST MenuCore Sorgelig release 201900204)
//  (c)2019 mazsola2k@modernhackers.com / http://www.modernhackers.com
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//=================================================================================================

module sys_top
(
	/////////// CLOCK //////////
	input         FPGA_CLK1_50,
	input         FPGA_CLK2_50,
	input         FPGA_CLK3_50,

	//////////// VGA ///////////
	//DE10-nano board implementation contained 6 / color
	//output  [5:0] VGA_R,
	//output  [5:0] VGA_G,
	//output  [5:0] VGA_B,
	//DE10-standard / DE1-soc kit board implementation has to contian 8 / color otherwise the brightness is low on the DAC
	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,  // VGA_HS is secondary SD card detect when VGA_EN = 1 (inactive)
	output		  VGA_VS,
	//DE10-nano implementation for VGA expansion daugher board
	//input         VGA_EN,  // active low
	//DE10-standard / DE1-soc kit implementation for on-board VGA DAC route - this will be overrided by code to set value to 0
	inout         VGA_EN,  // active low
	//DE10-standard / DE1-soc kit implementation for on-board VGA DAC route - additional pins
	output 		  VGA_CLK,
	output 		  VGA_BLANK_N,
	output 		  VGA_SYNC_N,

	//DE10-nano implementation for VGA expansion daugher board including analoge audio output jack
	/////////// AUDIO //////////
	output		  AUDIO_L,
	output		  AUDIO_R,
	output		  AUDIO_SPDIF,
	
	//DE10-standard / DE1-soc kit implementation for on-board Wolfson WM8731 Audio DAC
	// Audio CODEC
	inout wire    AUD_ADCLRCK,  // Audio CODEC ADC LR Clock
	input wire    AUD_ADCDAT,   // Audio CODEC ADC Data
	inout wire    AUD_DACLRCK,  // Audio CODEC DAC LR Clock
	output wire   AUD_DACDAT,   // Audio CODEC DAC Data
   inout wire    AUD_BCLK,     // Audio CODEC Bit-Stream Clock
   output wire   AUD_XCK,      // Audio CODEC Chip Clock

	// I2C
   inout wire    I2C_SDAT,     // I2C Data
   output wire   I2C_SCLK,     // I2C Clock

	//////////// HDMI //////////
	output        HDMI_I2C_SCL,
	inout         HDMI_I2C_SDA,

	output        HDMI_MCLK,
	output        HDMI_SCLK,
	output        HDMI_LRCLK,
	output        HDMI_I2S,

	output        HDMI_TX_CLK,
	output        HDMI_TX_DE,
	output [23:0] HDMI_TX_D,
	output        HDMI_TX_HS,
	output        HDMI_TX_VS,
	
	input         HDMI_TX_INT,

	//////////// SDR ///////////
	output [12:0] SDRAM_A,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nWE,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nCS,
	output  [1:0] SDRAM_BA,
	output        SDRAM_CLK,
	output        SDRAM_CKE,

	//////////// I/O ///////////
	output        LED_USER,
	output        LED_HDD,
	output        LED_POWER,
	input         BTN_USER,
	input         BTN_OSD,
	input         BTN_RESET,

	//////////// SDIO ///////////
	inout   [3:0] SDIO_DAT,
	inout         SDIO_CMD,
	output        SDIO_CLK,
	input         SDIO_CD,

	////////// MB KEY ///////////
	input   [1:0] KEY,

	////////// MB SWITCH ////////
	input   [3:0] SW,

	////////// MB LED ///////////
	output  [7:0] LED,

	///////// USER IO ///////////
	inout   [5:0] USER_IO
);


assign SDIO_DAT[2:1] = 2'bZZ;

//////////////////////////  LEDs  ///////////////////////////////////////

reg [7:0] led_overtake = 0;
reg [7:0] led_state    = 0;

wire led_p =  led_power[1] ? ~led_power[0] : 1'b0;
wire led_d =  led_disk[1]  ? ~led_disk[0]  : ~(led_disk[0] | gp_out[29]);
wire led_u = ~led_user;

assign LED_POWER = led_p ? 1'bZ : 1'b0;
assign LED_HDD   = led_d ? 1'bZ : 1'b0;
assign LED_USER  = led_u ? 1'bZ : 1'b0;

//LEDs on main board
assign LED = (led_overtake & led_state) | (~led_overtake & {3'b000, ~led_p, 1'b0, ~led_d, 1'b0, ~led_u});


//////////////////////////  Buttons  ///////////////////////////////////
reg btn_user, btn_osd;
always @(posedge FPGA_CLK2_50) begin
	integer div;
	reg [7:0] deb_user;
	reg [7:0] deb_osd;

	div <= div + 1'b1;
	if(div > 100000) div <= 0;
	
	if(!div) begin
		deb_user <= {deb_user[6:0], ~(BTN_USER & KEY[1])};
		if(&deb_user) btn_user <= 1;
		if(!deb_user) btn_user <= 0;

		deb_osd <= {deb_osd[6:0], ~(BTN_OSD & KEY[0])};
		if(&deb_osd) btn_osd <= 1;
		if(!deb_osd) btn_osd <= 0;
	end
end

reg btn_reset = 1;
always @(posedge FPGA_CLK2_50) btn_reset <= BTN_RESET;


/////////////////////////  HPS I/O  /////////////////////////////////////

// gp_in[31] = 0 - quick flag that FPGA is initialized (HPS reads 1 when FPGA is not in user mode)
//                 used to avoid lockups while JTAG loading
wire [31:0] gp_in = {1'b0, btn_user, btn_osd, 9'd0, io_ver, io_ack, io_wide, io_dout};
wire [31:0] gp_out;

wire  [1:0] io_ver    = 1; // 0 - standard MiST I/O (for quick porting of complex MiST cores). 1 - optimized HPS I/O. 2,3 - reserved for future.
wire        io_wait;
wire        io_wide;
wire [15:0] io_dout;                  
wire [15:0] io_din    = gp_outr[15:0];
wire        io_clk    = gp_outr[17];
wire        io_fpga   = gp_outr[18];
wire        io_osd    = gp_outr[19];
wire        io_uio    = gp_outr[20];
//wire        io_sdd    = gp_outr[21]; // used only in ST core

reg  io_ack;
reg  rack;
wire io_strobe = ~rack & io_clk;

always @(posedge clk_sys) begin
	if(~io_wait | io_strobe) begin
		rack <= io_clk;
		io_ack <= rack;
	end
end

reg [31:0] gp_outr;
always @(posedge clk_sys) begin
	reg [31:0] gp_outd;
	gp_outr <= gp_outd;
	gp_outd <= gp_out;
end

wire  [7:0] core_type  = 'hA4; // A4 - generic core.

// HPS will not communicate to core if magic is different
wire [31:0] core_magic = {24'h5CA623, core_type};

cyclonev_hps_interface_mpu_general_purpose h2f_gp
(
	.gp_in({~gp_out[31] ? core_magic : gp_in}),
	.gp_out(gp_out)
);


reg [15:0] cfg;

reg        cfg_got   = 0;
reg        cfg_set   = 0;
//wire [2:0] hdmi_res  = cfg[10:8];
wire       dvi_mode  = cfg[7];
wire       audio_96k = cfg[6];
wire       ypbpr_en  = cfg[5];
wire       csync     = cfg[3];
wire       vga_scaler= cfg[2];

reg        cfg_custom_t = 0;
reg  [5:0] cfg_custom_p1;
reg [31:0] cfg_custom_p2;

reg  [4:0] vol_att = 0;
reg        pal = 0;

always@(posedge clk_sys) begin
	reg  [7:0] cmd;
	reg        has_cmd;
	reg        old_strobe;
	reg  [7:0] cnt = 0;

	old_strobe <= io_strobe;

	if(~io_uio) begin
		has_cmd <= 0;
	end
	else
	if(~old_strobe & io_strobe) begin
		if(!has_cmd) begin
			has_cmd <= 1;
			cmd <= io_din[7:0];
			cnt <= 0;
		end
		else begin
			if(cmd == 1) begin
				cfg <= io_din;
				cfg_set <= 1;
			end
			if(cmd == 'h20) begin
				cfg_set <= 0;
				cnt <= cnt + 1'd1;
				if(cnt<8) begin
					case(cnt)
						0: if(WIDTH  != io_din[11:0]) begin WIDTH  <= io_din[11:0]; end
						1: if(HFP    != io_din[11:0]) begin HFP    <= io_din[11:0]; end
						2: if(HS     != io_din[11:0]) begin HS     <= io_din[11:0]; end
						3: if(HBP    != io_din[11:0]) begin HBP    <= io_din[11:0]; end
						4: if(HEIGHT != io_din[11:0]) begin HEIGHT <= io_din[11:0]; end
						5: if(VFP    != io_din[11:0]) begin VFP    <= io_din[11:0]; end
						6: if(VS     != io_din[11:0]) begin VS     <= io_din[11:0]; end
						7: if(VBP    != io_din[11:0]) begin VBP    <= io_din[11:0]; end
					endcase
					if(cnt == 1) begin
						cfg_custom_p1 <= 0;
						cfg_custom_p2 <= 0;
						cfg_custom_t <= ~cfg_custom_t;
					end
				end
				else begin
					if(cnt[1:0]==0) cfg_custom_p1 <= io_din[5:0];
					if(cnt[1:0]==1) cfg_custom_p2[15:0]  <= io_din;
					if(cnt[1:0]==2) begin
						cfg_custom_p2[31:16] <= io_din;
						cfg_custom_t <= ~cfg_custom_t;
						cnt[2:0] <= 3'b100;
					end
					if(cnt == 8) pal <= io_din[15];
				end
			end
			if(cmd == 'h25) {led_overtake, led_state} <= io_din;
			if(cmd == 'h26) vol_att <= io_din[4:0];
		end
	end
end

always @(posedge clk_sys) begin
	reg vsd, vsd2;
	if(~cfg_ready || ~cfg_set) cfg_got <= cfg_set;
	else begin
		vsd  <= HDMI_TX_VS;
		vsd2 <= vsd;
		if(~vsd2 & vsd) cfg_got <= cfg_set;
	end
end

cyclonev_hps_interface_peripheral_uart uart
(
	.ri(0),
	.dsr(uart_dsr),
	.dcd(uart_dsr),
	.dtr(uart_dtr),

	.cts(uart_cts),
	.rts(uart_rts),
	.rxd(uart_rxd),
	.txd(uart_txd)
);

wire aspi_sck,aspi_mosi,aspi_ss;
cyclonev_hps_interface_peripheral_spi_master spi
(
	.sclk_out(aspi_sck),
	.txd(aspi_mosi), // mosi
	.rxd(1),         // miso

	.ss_0_n(aspi_ss),
	.ss_in_n(1)
);


///////////////////////////  RESET  ///////////////////////////////////

reg reset_req = 0;
always @(posedge FPGA_CLK2_50) begin
	reg [1:0] resetd, resetd2;
	reg       old_reset;

	//latch the reset
	old_reset <= reset;
	if(~old_reset & reset) reset_req <= 1;

	//special combination to set/clear the reset
	//preventing of accidental reset control
	if(resetd==1) reset_req <= 1;
	if(resetd==2 && resetd2==0) reset_req <= 0;

	resetd  <= gp_out[31:30];
	resetd2 <= resetd;
end

wire clk_100m;
wire clk_hdmi  = ~HDMI_TX_CLK;  // Internal HDMI clock, inverted in relation to external clock
wire clk_audio = FPGA_CLK3_50;

/////////////////////////  Lite version  ////////////////////////////////

wire [11:0] x;
wire [11:0] y;

sync_vg #(.X_BITS(12), .Y_BITS(12)) sync_vg
(
	.clk(clk_hdmi),
	.reset(reset),
	.v_total(HEIGHT+VFP+VBP+VS),
	.v_fp(VFP),
	.v_bp(VBP),
	.v_sync(VS),
	.h_total(WIDTH+HFP+HBP+HS),
	.h_fp(HFP),
	.h_bp(HBP),
	.h_sync(HS),
	.vde_out(vde),
	.hde_out(hde),
	.vs_out(hdmi_vs),
	.x_out(x),
	.y_out(y),
	.hs_out(hdmi_hs)
);

wire vde, hde;
wire hdmi_vs,hdmi_vs2;
wire hdmi_hs,hdmi_hs2;


pattern_vg
#(
	.B(8),
	.X_BITS(12),
	.Y_BITS(12)
)
pattern_vg
(
	.reset(reset),
	.clk_in(clk_hdmi),
	.x(x),
	.y(y),
	.vs_in(hdmi_vs),
	.hs_in(hdmi_hs),
	.de_in(vde & hde),
	.vs_out(hdmi_vs2),
	.hs_out(hdmi_hs2),
	.de_out(hdmi_de),
	.r(hdmi_data[23:16]),
	.g(hdmi_data[15:8]),
	.b(hdmi_data[7:0]),
	.width(WIDTH),
	.height(HEIGHT),
	.pattern(patt)
);

wire reset;
sysmem_lite sysmem
(
	//Reset/Clock
	.reset_core_req(reset_req),
	.reset_out(reset),
	.clock(clk_100m),
	
	.reset_hps_cold_req(~btn_reset),

	//64-bit DDR3 RAM access
	.ram1_clk(ram_clk),
	.ram1_address(ram_address),
	.ram1_burstcount(ram_burstcount),
	.ram1_waitrequest(ram_waitrequest),
	.ram1_readdata(ram_readdata),
	.ram1_readdatavalid(ram_readdatavalid),
	.ram1_read(ram_read),
	.ram1_writedata(ram_writedata),
	.ram1_byteenable(ram_byteenable),
	.ram1_write(ram_write),

	//64-bit DDR3 RAM access
	.ram2_clk(clk_audio),
	.ram2_address(aram_address),
	.ram2_burstcount(aram_burstcount),
	.ram2_waitrequest(aram_waitrequest),
	.ram2_readdata(aram_readdata),
	.ram2_readdatavalid(aram_readdatavalid),
	.ram2_read(aram_read),
	.ram2_writedata(0),
	.ram2_byteenable(8'hFF),
	.ram2_write(0),

	//HDMI frame buffer
	.vbuf_clk(clk_100m),
	.vbuf_address(0),
	.vbuf_burstcount(0),
	.vbuf_waitrequest(),
	.vbuf_writedata(0),
	.vbuf_byteenable(0),
	.vbuf_write(0),
	.vbuf_readdata(),
	.vbuf_readdatavalid(),
	.vbuf_read(0)
);



/////////////////////////  HDMI output  /////////////////////////////////

pll_hdmi pll_hdmi
(
	.refclk(FPGA_CLK1_50),
	.rst(reset_req),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll),
	.outclk_0(HDMI_TX_CLK)
);


//1920x1080@60 PCLK=148.5MHz CEA
reg  [11:0] WIDTH  = 1920;
reg  [11:0] HFP    = 88;
reg  [11:0] HS     = 48;
reg  [11:0] HBP    = 148;
reg  [11:0] HEIGHT = 1080;
reg  [11:0] VFP    = 4;
reg  [11:0] VS     = 5;
reg  [11:0] VBP    = 36;

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;
wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

pll_hdmi_cfg pll_hdmi_cfg
(
	.mgmt_clk(FPGA_CLK1_50),
	.mgmt_reset(reset_req),
	.mgmt_waitrequest(cfg_waitrequest),
	.mgmt_read(0),
	.mgmt_readdata(),
	.mgmt_write(cfg_write),
	.mgmt_address(cfg_address),
	.mgmt_writedata(cfg_data),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);


reg cfg_ready = 0;

always @(posedge FPGA_CLK1_50) begin
	reg gotd = 0, gotd2 = 0;
	reg custd = 0, custd2 = 0;
	reg old_wait = 0;

	gotd  <= cfg_got;
	gotd2 <= gotd;
	
	cfg_write <= 0;
	
	custd <= cfg_custom_t;
	custd2 <= custd;
	if(custd2 != custd & ~gotd) begin
		cfg_address <= cfg_custom_p1;
		cfg_data <= cfg_custom_p2;
		cfg_write <= 1;
	end

	if(~gotd2 & gotd) begin
		cfg_address <= 2;
		cfg_data <= 0;
		cfg_write <= 1;
	end

	old_wait <= cfg_waitrequest;
	if(old_wait & ~cfg_waitrequest & gotd) cfg_ready <= 1;
end

hdmi_config hdmi_config
(
	.iCLK(FPGA_CLK1_50),
	.iRST_N(cfg_ready & ~HDMI_TX_INT & ~reset_hdmi),

	.I2C_SCL(HDMI_I2C_SCL),
	.I2C_SDA(HDMI_I2C_SDA),

	.dvi_mode(dvi_mode),
	.audio_96k(audio_96k)
);

wire [23:0] hdmi_data,hdmi_data2;
wire        hdmi_de,hdmi_de2;

osd hdmi_osd
(
	.clk_sys(clk_sys),

	.io_osd(io_osd),
	.io_strobe(io_strobe),
	.io_din(io_din),

	.clk_video(clk_hdmi),
	.din(hdmi_data),
	.dout(hdmi_data2),
	.de_in(hdmi_de),
	.de_out(hdmi_de2)
);


vid_dim hdmi_dim
(
	.clk(clk_hdmi),

	.r_in(hdmi_data2[23:16]),
	.g_in(hdmi_data2[15:8]),
	.b_in(hdmi_data2[7:0]),
	.de_in(hdmi_de2),
	.hs_in(hdmi_hs2),
	.vs_in(hdmi_vs2),

	.r_out(HDMI_TX_D[23:16]),
	.g_out(HDMI_TX_D[15:8]),
	.b_out(HDMI_TX_D[7:0]),
	.de_out(HDMI_TX_DE),
	.hs_out(HDMI_TX_HS),
	.vs_out(HDMI_TX_VS),

	.dim(dim)
);


/////////////////////////  VGA output  //////////////////////////////////

wire [23:0] vga_q, vga_q2;
wire hs2,vs2;

osd vga_osd
(
	.clk_sys(clk_sys),

	.io_osd(io_osd),
	.io_strobe(io_strobe),
	.io_din(io_din),

	.clk_video(clk_vid),
	
	.din(de ? {r_out, g_out, b_out} : 24'd0),
	.dout(vga_q),
	.de_in(de)
);

vid_dim vga_dim
(
	.clk(clk_vid),

	.r_in(vga_q[23:16]),
	.g_in(vga_q[15:8]),
	.b_in(vga_q[7:0]),
	.hs_in(hs),
	.vs_in(vs),

	.r_out(vga_q2[23:16]),
	.g_out(vga_q2[15:8]),
	.b_out(vga_q2[7:0]),
	.hs_out(hs2),
	.vs_out(vs2),

	.dim(dim)
);

wire [23:0] vga_o;
vga_out vga_out
(
	.ypbpr_full(1),
	.ypbpr_en(ypbpr_en),
	.dout(vga_o),
	.din(vga_scaler ? (HDMI_TX_DE ? HDMI_TX_D : 24'd0) : vga_q2)
);

wire vs1 = vga_scaler ? HDMI_TX_VS : vs2;
wire hs1 = vga_scaler ? HDMI_TX_HS : hs2;

assign VGA_VS = VGA_EN ? 1'bZ      : csync ?     1'b1     : ~vs1;
assign VGA_HS = VGA_EN ? 1'bZ      : csync ? ~(vs1 ^ hs1) : ~hs1;

//DE10-standard implementation for on-board VGA DAC route - assign values
assign VGA_EN = 1'b0;						//enable VGA mode when VGA_EN is low
assign VGA_CLK=HDMI_TX_CLK;				//has to define a clock to VGA DAC clock otherwise the picture is noisy
assign VGA_SYNC_N = 1'b0;					//VGA DAC additional required pin
assign VGA_BLANK_N = VGA_HS && VGA_VS;	//VGA DAC additional required pin

//DE10-nano implementation for VGA Expansion board 6 channels / color
//assign VGA_R  = VGA_EN ? 6'bZZZZZZ : vga_o[23:18];
//assign VGA_G  = VGA_EN ? 6'bZZZZZZ : vga_o[15:10];
//assign VGA_B  = VGA_EN ? 6'bZZZZZZ : vga_o[7:2];
//DE10-standard / DE1-soc kit implementation for on-board VGA DAC route - use 8 channels / color
assign VGA_R  = VGA_EN ? 6'bZZZZZZ : vga_o[23:16];
assign VGA_G  = VGA_EN ? 6'bZZZZZZ : vga_o[15:8];
assign VGA_B  = VGA_EN ? 6'bZZZZZZ : vga_o[7:0];

//// de10-standard / de1-soc kit does not have HDMI audio anMister audio expansion board ///
/////////////////////////  Audio output  ////////////////////////////////

assign AUDIO_SPDIF = SW[0] ? HDMI_LRCLK : aspdif;
assign AUDIO_R     = SW[0] ? HDMI_I2S   : anr;
assign AUDIO_L     = SW[0] ? HDMI_SCLK  : anl;

assign HDMI_MCLK = 0;
i2s i2s
(
	.clk_sys(clk_audio),
	.reset(reset),

	.half_rate(~audio_96k),

	.sclk(HDMI_SCLK),
	.lrclk(HDMI_LRCLK),
	.sdata(HDMI_I2S),

	.left_chan (audio_l),
	.right_chan(audio_r)
);

wire anl;

sigma_delta_dac #(15) dac_l
(
	.CLK(clk_audio),
	.RESET(reset),
	.DACin({~audio_l[15], audio_l[14:0]}),
	.DACout(anl)
);

wire anr;
sigma_delta_dac #(15) dac_r
(
	.CLK(clk_audio),
	.RESET(reset),
	.DACin({~audio_r[15], audio_r[14:0]}),
	.DACout(anr)
);

wire aspdif;
spdif toslink
(
	.clk_i(clk_audio),

	.rst_i(reset),
	.half_rate(0),

	.audio_l(audio_l),
	.audio_r(audio_r),

	.spdif_o(aspdif)
);

wire [15:0] audio_l, audio_l_pre;
aud_mix_top audmix_l
(
	.clk(clk_audio),
	.att(vol_att),
	.mix(audio_mix),
	.is_signed(audio_s),

	.core_audio(audio_ls),
	.pre_in(audio_r_pre),
	.linux_audio(alsa_l),

	.pre_out(audio_l_pre),
	.out(audio_l)
);

wire [15:0] audio_r, audio_r_pre;
aud_mix_top audmix_r
(
	.clk(clk_audio),
	.att(vol_att),
	.mix(audio_mix),
	.is_signed(audio_s),

	.core_audio(audio_rs),
	.pre_in(audio_l_pre),
	.linux_audio(alsa_r),

	.pre_out(audio_r_pre),
	.out(audio_r)
);

wire [28:0] aram_address;
wire  [7:0] aram_burstcount;
wire        aram_waitrequest;
wire [63:0] aram_readdata;
wire        aram_readdatavalid;
wire        aram_read;

wire [15:0] alsa_l, alsa_r;

alsa alsa
(
	.reset(reset),

	.ram_clk(clk_audio),
	.ram_address(aram_address),
	.ram_burstcount(aram_burstcount),
	.ram_waitrequest(aram_waitrequest),
	.ram_readdata(aram_readdata),
	.ram_readdatavalid(aram_readdatavalid),
	.ram_read(aram_read),

	.spi_ss(aspi_ss),
	.spi_sck(aspi_sck),
	.spi_mosi(aspi_mosi),

	.pcm_l(alsa_l),
	.pcm_r(alsa_r)
);

//// de10-standard / de1-soc kit audio codec i2c ////

wire exchan;
wire mix;
assign exchan    = 1'b0;
assign mix       = 1'b0;
audio_top audio_top (
  .clk          (clk_audio),  // input clock
  .rst_n        (!BTN_RESET),  // active low reset (from when reset button not pushed)
  // config
  .exchan       (exchan),  // switch audio left / right channel
  .mix          (mix),  // normal / centered mix (play some left channel on the right channel and vise-versa)
  // audio shifter
  .rdata        (audio_r),  // right channel sample data
  .ldata        (audio_l),  // left channel sample data
  .aud_bclk     (AUD_BCLK),  // CODEC data clock
  .aud_daclrck  (AUD_DACLRCK),  // CODEC data clock
  .aud_dacdat   (AUD_DACDAT),  // CODEC data
  .aud_xck      (AUD_XCK),  // CODEC data clock
  // I2C audio config
  .i2c_sclk     (I2C_SCLK),  // CODEC config clock
  .i2c_sdat     (I2C_SDAT)   // CODEC config data
);

////////////////  User I/O (USB 3.0 connector) /////////////////////////

assign USER_IO[0] = 1'bZ;
assign USER_IO[1] = 1'bZ;
assign USER_IO[2] = (SW[1] & ~HDMI_I2S)   ? 1'b0 : 1'bZ;
assign USER_IO[3] = 1'bZ;
assign USER_IO[4] = (SW[1] & ~HDMI_SCLK)  ? 1'b0 : 1'bZ;
assign USER_IO[5] = (SW[1] & ~HDMI_LRCLK) ? 1'b0 : 1'bZ;


///////////////////  User module connection ////////////////////////////

wire [15:0] audio_ls, audio_rs;
wire        audio_s;
wire  [1:0] audio_mix;
wire  [7:0] r_out, g_out, b_out;
wire        vs, hs, de;
wire        clk_sys, clk_vid, ce_pix;


wire  [2:0] patt;
wire        dim;
wire        reset_hdmi;

wire        ram_clk;
wire [28:0] ram_address;
wire [7:0]  ram_burstcount;
wire        ram_waitrequest;
wire [63:0] ram_readdata;
wire        ram_readdatavalid;
wire        ram_read;
wire [63:0] ram_writedata;
wire [7:0]  ram_byteenable;
wire        ram_write;

wire        led_user;
wire  [1:0] led_power;
wire  [1:0] led_disk;

wire vs_emu, hs_emu;
sync_fix sync_v(clk_vid, vs_emu, vs);
sync_fix sync_h(clk_vid, hs_emu, hs);

wire        uart_dtr;
wire        uart_dsr;
wire        uart_cts;
wire        uart_rts;
wire        uart_rxd;
wire        uart_txd;


emu emu
(
	.CLK_50M(FPGA_CLK3_50),
	.RESET(reset),
	.RESET_OUT(reset_hdmi),
	.HPS_BUS({HDMI_TX_VS, clk_100m, clk_vid, ce_pix, de, hs, vs, io_wait, clk_sys, io_fpga, io_uio, io_strobe, io_wide, io_din, io_dout}),

	.CLK_VIDEO(clk_vid),
	.CE_PIXEL(ce_pix),

	.PAL(pal),
	.VGA_R(r_out),
	.VGA_G(g_out),
	.VGA_B(b_out),
	.VGA_HS(hs_emu),
	.VGA_VS(vs_emu),
	.VGA_DE(de),

	.LED_USER(led_user),
	.LED_POWER(led_power),
	.LED_DISK(led_disk),

	.PATTERN(patt),
	.DIM(dim),

	.AUDIO_L(audio_ls),
	.AUDIO_R(audio_rs),
	.AUDIO_S(audio_s),
	.AUDIO_MIX(audio_mix),
	.TAPE_IN(0),

	.SD_SCK(SDIO_CLK),
	.SD_MOSI(SDIO_CMD),
	.SD_MISO(SDIO_DAT[0]),
	.SD_CS(SDIO_DAT[3]),
	.SD_CD(VGA_EN ? VGA_HS : SDIO_CD),

	.DDRAM_CLK(ram_clk),
	.DDRAM_ADDR(ram_address),
	.DDRAM_BURSTCNT(ram_burstcount),
	.DDRAM_BUSY(ram_waitrequest),
	.DDRAM_DOUT(ram_readdata),
	.DDRAM_DOUT_READY(ram_readdatavalid),
	.DDRAM_RD(ram_read),
	.DDRAM_DIN(ram_writedata),
	.DDRAM_BE(ram_byteenable),
	.DDRAM_WE(ram_write),

	.SDRAM_DQ(SDRAM_DQ),
	.SDRAM_A(SDRAM_A),
	.SDRAM_DQML(SDRAM_DQML),
	.SDRAM_DQMH(SDRAM_DQMH),
	.SDRAM_BA(SDRAM_BA),
	.SDRAM_nCS(SDRAM_nCS),
	.SDRAM_nWE(SDRAM_nWE),
	.SDRAM_nRAS(SDRAM_nRAS),
	.SDRAM_nCAS(SDRAM_nCAS),
	.SDRAM_CLK(SDRAM_CLK),
	.SDRAM_CKE(SDRAM_CKE),

	.UART_CTS(uart_rts),
	.UART_RTS(uart_cts),
	.UART_RXD(uart_txd),
	.UART_TXD(uart_rxd),
	.UART_DTR(uart_dsr),
	.UART_DSR(uart_dtr)
);

endmodule

/////////////////////////////////////////////////////////////////////

module sync_fix
(
	input clk,
	
	input sync_in,
	output sync_out
);

assign sync_out = sync_in ^ pol;

reg pol;
always @(posedge clk) begin
	integer pos = 0, neg = 0, cnt = 0;
	reg s1,s2;

	s1 <= sync_in;
	s2 <= s1;

	if(~s2 & s1) neg <= cnt;
	if(s2 & ~s1) pos <= cnt;

	cnt <= cnt + 1;
	if(s2 != s1) cnt <= 0;

	pol <= pos > neg;
end

endmodule

/////////////////////////////////////////////////////////////////////

module aud_mix_top
(
	input             clk,

	input       [4:0] att,
	input       [1:0] mix,
	input             is_signed,

	input      [15:0] core_audio,
	input      [15:0] linux_audio,
	input      [15:0] pre_in,

	output reg [15:0] pre_out,
	output reg [15:0] out
);

reg [15:0] ca;
always @(posedge clk) begin
	reg [15:0] d1,d2,d3;

	d1 <= core_audio; d2<=d1; d3<=d2;
	if(d2 == d3) ca <= d2;
end

always @(posedge clk) begin
	reg signed [16:0] a1, a2, a3, a4;

	a1 <= is_signed ? {ca[15],ca} : {2'b00,ca[15:1]};
	a2 <= a1 + {linux_audio[15],linux_audio};

	pre_out <= a2[16:1];

	case(mix)
		0: a3 <= a2;
		1: a3 <= $signed(a2) - $signed(a2[16:3]) + $signed(pre_in[15:2]);
		2: a3 <= $signed(a2) - $signed(a2[16:2]) + $signed(pre_in[15:1]);
		3: a3 <= {a2[16],a2[16:1]} + {pre_in[15],pre_in};
	endcase

	if(att[4]) a4 <= 0;
	else a4 <= a3 >>> att[3:0];

	//clamping
	out <= ^a4[16:15] ? {a4[16],{15{a4[15]}}} : a4[15:0];
end

endmodule

/////////////////////////////////////////////////////////////////////

module vid_dim
(
	input clk,

	input [7:0] r_in,g_in,b_in,
	input de_in,
	input hs_in,
	input vs_in,

	output reg [7:0] r_out,g_out,b_out,
	output reg de_out,
	output reg hs_out,
	output reg vs_out,

	input dim
);

always @(posedge clk) begin
	reg hs_in1,vs_in1;

	//compensate osd
	hs_in1 <= hs_in;
	vs_in1 <= vs_in;

	hs_out <= hs_in1;
	vs_out <= vs_in1;
	
	de_out <= de_in;
	
	if(dim) begin
		r_out <= r_in[7:2];
		g_out <= g_in[7:2];
		b_out <= b_in[7:2];
	end
	else begin
		r_out <= r_in;
		g_out <= g_in;
		b_out <= b_in;
	end
end

endmodule
