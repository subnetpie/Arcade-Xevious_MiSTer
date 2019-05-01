//============================================================================
//  Arcade: Xevious
//
//  Port to MiSTer
//  Copyright (C) 2019 Sorgelig
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
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [44:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        VGA_CLK,

	//Multiple resolutions are supported using different VGA_CE rates.
	//Must be based on CLK_VIDEO
	output        VGA_CE,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)

	//Base video clock. Usually equals to CLK_SYS.
	output        HDMI_CLK,

	//Multiple resolutions are supported using different HDMI_CE rates.
	//Must be based on CLK_VIDEO
	output        HDMI_CE,

	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_DE,   // = ~(VBlank | HBlank)
	output  [1:0] HDMI_SL,   // scanlines fx

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] HDMI_ARX,
	output  [7:0] HDMI_ARY,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S    // 1 - signed audio samples, 0 - unsigned
);

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign HDMI_ARX = status[1] ? 8'd16 : status[2] ? 8'd4 : 8'd3;
assign HDMI_ARY = status[1] ? 8'd9  : status[2] ? 8'd3 : 8'd4;

`include "build_id.v" 
parameter CONF_STR = {
	"A.XEVS;;",
	"F,rom;", // allow loading of alternate ROMs
	"-;",
	"O1,Aspect Ratio,Original,Wide;",
	"O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"O67,Difficulty,Stadard,Easy,Hard,Very Hard;",
	"O89,Lives,3,1,2,5;",
	"OAC,Bonus,20K/every 60K,20K/every 40K,20K/every 50K,20K/every 60K,20K/every 70K,20K/every 80K,20K 2nd at 60K,No bonus;",
   "OD,Flag Bonus,Extra Life,10K;",
//	"OEF,Credits,1 coin/1 credit,1 coin/2 credits,2 coins/1 credit,2 coins/3 credits;", 
//	"OG,Cabinet,Upright,Cocktail;",
	"-;",
	"R0,Reset;",
	"J,Fire,Bomb,Start 1P,Start 2P,Coin,Pause;",
	"V,v",`BUILD_DATE
};

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

wire [10:0] ps2_key;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;

wire        forced_scandoubler;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.ps2_key(ps2_key)
);

////////////////////   CLOCKS   ///////////////////

wire clk_sys, clk_12m;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(clk_12m),
	.locked(pll_locked)
);

///////////////////   KEYBOARD   //////////////////
// button codes https://github.com/mist-devel/mist-firmware/blob/master/keycodes.h

wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(code)
			'hX75: btn_up               <= pressed; // up
			'hX72: btn_down             <= pressed; // down
			'hX6B: btn_left             <= pressed; // left
			'hX74: btn_right            <= pressed; // right
			'h029: btn_fire             <= pressed; // space
			'hX14: btn_bomb             <= pressed; // ctrl
			
			'h005: btn_coin_one_player  <= pressed; // F1
			'h006: btn_coin_two_players <= pressed; // F2
			
			// JPAC/IPAC/MAME Style Codes
			'h016: btn_one_player       <= pressed; // 1
			'h01E: btn_two_players      <= pressed; // 2
			'h02E: btn_coin_l           <= pressed; // 5 
			'h036: btn_coin_r           <= pressed; // 6
			'h01b: btn_service          <= pressed; // s
			'h04D: btn_pause            <= pressed; // p
		endcase
	end
end

//////////    BUTTONS/SETTINGS DEFINED    //////////

reg btn_up               = 0;
reg btn_down             = 0;
reg btn_left             = 0;
reg btn_right            = 0;
reg btn_fire             = 0;
reg btn_bomb             = 0;
reg btn_coin_one_player  = 0;
reg btn_coin_two_players = 0;
reg btn_one_player       = 0;
reg btn_two_players      = 0;
reg btn_coin_l           = 0;
reg btn_coin_r           = 0;
reg btn_service          = 0;
reg btn_test             = 0;
reg btn_pause            = 0;

wire m_up                = status[2] ? btn_left  | joy[1] : btn_up    | joy[3];
wire m_down              = status[2] ? btn_right | joy[0] : btn_down  | joy[2];
wire m_left              = status[2] ? btn_down  | joy[2] : btn_left  | joy[1];
wire m_right             = status[2] ? btn_up    | joy[3] : btn_right | joy[0];
wire m_fire              = btn_fire | joy[4];
wire m_bomb              = btn_bomb | joy[5];
wire m_coin              = m_coinstart1 | m_coinstart2 | btn_coin_l | btn_coin_r | joy[8];
wire m_start1            = btn_coin_one_player  | btn_one_player  | joy[6];
wire m_start2            = btn_coin_two_players | btn_two_players | joy[7];
wire m_coinstart1        = btn_coin_one_player  | joy[6];
wire m_coinstart2        = btn_coin_two_players | joy[7];
wire m_pause             = btn_pause | joy[9];

reg pause = 0;
always @(posedge clk_sys) begin
	reg old_pause;
	old_pause <= m_pause;
	if(~old_pause & m_pause) pause <= ~pause;
	if(status[0] | buttons[1]) pause <= 1'b0;
end

wire [3:0]joystick = {m_up,m_right,m_down,m_left};
wire [3:0]controls = {m_start1,m_start2,m_fire,m_bomb};
wire [3:0]credits  = {btn_coin_l,btn_coin_r,btn_service,btn_test};

wire [7:0]dip_sw_a = {~status[16],~status[9:8],~status[12:10],~status[15:14]};
// DIP switches sourced from Xevious manual:
// +-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-+
// |FACTORY DEFAULT = *                                | 8   7   6   5   4   3   2   1 |
// +-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-=-=-=-=-=-=-+-=-+-=-+
// |COINS                  |1 coin/1 credit *          |                       |OFF|OFF|
// |                       |1 coin/2 credits           |                       |OFF|ON |
// | Coin Slot A           |2 coins/1 credit           |                       |ON |OFF|
// |                       |2 coins/3 credits          |                       |ON |ON |
// +-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-+-=-+-=-+-=-+-=-+-=-|
// |BONUS LIVES            |20,000 and every 60,000 *  |           |OFF|OFF|OFF|       |
// |                       |20,000 and every 40,000    |           |OFF|OFF|ON |       |
// | Switches 6 and 7 set  |20,000 and every 50,000    |           |OFF|ON |OFF|       |
// | for 1 to 3 lives      |20,000 and every 50,000    |           |OFF|ON |ON |       |
// |                       |20,000 and every 70,000    |           |ON |OFF|OFF|       |
// |                       |20,000 and every 80,000    |           |ON |OFF|ON |       |
// |                       |20,000 2nd bonus at 60,000 |           |ON |ON |OFF|       |
// |                       |No bonus                   |           |ON |ON |ON |       |
// +-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-+-=-+-=-+-=-+-=-=-=-|
// |BONUS LIVES            |20,000 and every 70,000    |           |OFF|OFF|OFF|       |
// |                       |10,000 and every 50,000    |           |OFF|OFF|ON |       |
// | Switches 6 and 7 set  |20,000 and every 50,000    |           |OFF|ON |OFF|       |
// | for 5 lives           |20,000 and every 60,000    |           |OFF|ON |ON |       |
// |                       |20,000 and every 80,000    |           |ON |OFF|OFF|       |
// |                       |30,000 and every 100,000   |           |ON |OFF|ON |       |
// |                       |20,000 2nd bonus at 80,000 |           |ON |ON |OFF|       |
// |                       |No bonus                   |           |ON |ON |ON |       |
// +-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-=-=-=-=-=-=-=-=-+-=-+-=-+-=-+-=-+-=-+-=-+-=-=-=-|
// |LIVES                  |3 lives *                  |   |OFF|OFF|                   |
// |                       |1 life                     |   |OFF|ON |                   |
// |                       |2 lives                    |   |ON |OFF|                   |
// |                       |5 lives                    |   |ON |ON |                   |
// +-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-=-=-=-=-=-=-=-=-+-=-+-=-+-=-+-=-=-=-=-=-=-=-=-=-|
// |CABINET                |Upright - 2 coin counters  |OFF|                           |
// | Coin slots            |Cocktail - 1 coin counter  |ON |                           |
// +-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-=-=-=-=-=-=-=-=-+-=-+-=-=-=-=-=-=-=-=-=-=-=-=-=-|

wire [7:0]dip_sw_b = {~pause,~status[7:6],1'b1,status[15:14],~status[13],~m_bomb};
// DIP switches sourced from Xevious manual:
// +-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-+
// |FACTORY DEFAULT = *                                | 8   7   6   5   4   3   2   1 |
// +-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-=-=-=-=-=-=-=-=-+-=-+
// |Must be off or Blaster |Manual bomb *              |                           |OFF|
// |fires continuously     |Auto bomb                  |                           |ON |
// +-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-=-=-=-=-=-=-+-=-+-=-+
// |Bonus Life Flags       |Yes *                      |                       |OFF|   |
// |                       |No                         |                       |ON |   |
// +-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-=-=-+-=-+-=-+-=-+-=-|
// |COINS                  |1 coin/1 credit *          |               |OFF|OFF|       |
// |                       |1 coin/2 credits           |               |OFF|ON |       |
// | Coin Slot B           |2 coins/1 credit           |               |ON |OFF|       |
// |                       |2 coins/3 credits          |               |ON |ON |       |
// +-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-+-=-+-=-+-=-+-=-=-=-+
// |Undocumented           |Undocumented *             |           |OFF|               |
// |                       |Undocumented               |           |ON |               |
// +-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-+-=-+-=-=-=-=-=-=-=-|
// |DIFFICULTY             |Standard game play *1      |   |OFF|OFF|                   |
// |                       |Easy game play             |   |OFF|ON |                   |
// |                       |Hard game play             |   |ON |OFF|                   |
// |                       |Very hard game play        |   |ON |ON |                   |
// +-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-=-=-=-=-=-=-=-=-+-=-+-=-=-=-+-=-=-=-=-=-=-=-=-=-|
// |Freeze                 |Super Xevious              |OFF|                           |
// |                       |Xevious *                  |ON |                           |
// +-=-=-=-=-=-=-=-=-=-=-=-+-=-=-=-=-=-=-=-=-=-=-=-=-=-+-=-+-=-=-=-=-=-=-=-=-=-=-=-=-=-|

////////////////////   VIDEO   ////////////////////

wire HBlank, VBlank, hs, vs;
wire [3:0] r,g,b;

arcade_rotate_fx #(288,224,12) arcade_video
(
	.*,

	.clk_video(clk_sys),
	.ce_pix(clk_12m),
	
	.RGB_in({r,g,b}),
	.HSync(~hs),
	.VSync(~vs),

	.fx(status[5:3]),
	.no_rotate(status[2])
);

////////////////////   AUDIO   ////////////////////

wire [10:0] audio;
assign AUDIO_L = {audio, 5'b00000};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;

//////////////////   TOP MODULE   /////////////////

xevious xevious
(
	.clock_18(clk_sys),
	.reset(RESET | status[0] | buttons[1] | ioctl_download),

	.dn_addr(ioctl_addr[16:0]),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr),

	.video_r(r),
	.video_g(g),
	.video_b(b),
	.video_hs(hs),
	.video_vs(vs),
	.blank_h(HBlank),
	.blank_v(VBlank),

	.audio(audio),

	.b_test(0),
	.b_svce(0),
	.coin(m_coin),
	.start1(m_start1),
	.start2(m_start2),
	
	.joystick(joystick),
	.controls(controls),
	.credits(credits),

	.dip_sw_a(dip_sw_a),
	.dip_sw_b(dip_sw_b)
);

endmodule
