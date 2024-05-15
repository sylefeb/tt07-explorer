`define UART 1
`define PMOD_QQSPI 1
`define SPISCREEN_EXTRA 1
`define NO_FASTRAM 1
`define SIM_SB_IO 1
/*

Copyright 2019, (C) Sylvain Lefebvre and contributors
List contributors with: git shortlog -n -s -- <filename>

MIT license

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

(header_2_M)

*/
`define ICESTICK 1
`define ICE40 1
`default_nettype none
// declare package pins (has to match the hardware pin definition)
// pin.NAME = <WIDTH>
// pin groups and renaming
//

// NOTE: this is a modified exerpt from Yosys ice40 cell_sim.v
// WARNING: heavily hacked and does not support some cases (unregistered output, inverted output)

`timescale 1ps / 1ps
// `define SB_DFF_INIT initial Q = 0;
// `define SB_DFF_INIT

// SiliconBlue IO Cells

module _SB_IO (
	// inout  PACKAGE_PIN,
  input  PACKAGE_PIN_I,
  output PACKAGE_PIN_O,
  output PACKAGE_PIN_OE,

	//input  LATCH_INPUT_VALUE,
	//input  CLOCK_ENABLE,
	input  INPUT_CLK,
	input  OUTPUT_CLK,
	input  OUTPUT_ENABLE,
	input  D_OUT_0,
	input  D_OUT_1,
	output D_IN_0,
	output D_IN_1
);
	parameter [5:0] PIN_TYPE = 6'b000000;
	parameter [0:0] PULLUP = 1'b0;
	parameter [0:0] NEG_TRIGGER = 1'b0;
	parameter IO_STANDARD = "SB_LVCMOS";

	reg dout, din_0, din_1;
	reg din_q_0, din_q_1;
	reg dout_q_0, dout_q_1;
	reg outena_q;

  wire CLOCK_ENABLE;
  assign CLOCK_ENABLE = 1'b1;
  wire LATCH_INPUT_VALUE;
  assign LATCH_INPUT_VALUE = 1'b0;

	// IO tile generates a constant 1'b1 internally if global_cen is not connected

	generate if (!NEG_TRIGGER) begin
		always @(posedge INPUT_CLK)  din_q_0         <= PACKAGE_PIN_I;
		always @(negedge INPUT_CLK)  din_q_1         <= PACKAGE_PIN_I;
		always @(posedge OUTPUT_CLK) dout_q_0        <= D_OUT_0;
		always @(negedge OUTPUT_CLK) dout_q_1        <= D_OUT_1;
		always @(posedge OUTPUT_CLK) outena_q        <= OUTPUT_ENABLE;
	end else begin
		always @(negedge INPUT_CLK)  din_q_0         <= PACKAGE_PIN_I;
		always @(posedge INPUT_CLK)  din_q_1         <= PACKAGE_PIN_I;
		always @(negedge OUTPUT_CLK) dout_q_0        <= D_OUT_0;
		always @(posedge OUTPUT_CLK) dout_q_1        <= D_OUT_1;
		always @(negedge OUTPUT_CLK) outena_q        <= OUTPUT_ENABLE;
	end endgenerate

	always @* begin
		//if (!PIN_TYPE[1] || !LATCH_INPUT_VALUE)
	  din_0 = PIN_TYPE[0] ? PACKAGE_PIN_I : din_q_0;
		din_1 = din_q_1;
	end

	// work around simulation glitches on dout in DDR mode
	//reg outclk_delayed_1;
	//reg outclk_delayed_2;
	//always @* outclk_delayed_1 <= OUTPUT_CLK;
	//always @* outclk_delayed_2 <= outclk_delayed_1;

	always @* begin
		//if (PIN_TYPE[3])
	  //  dout = PIN_TYPE[2] ? !dout_q_0 : D_OUT_0;
		//else
		dout = (/*outclk_delayed_2*/OUTPUT_CLK ^ NEG_TRIGGER) || PIN_TYPE[2] ? dout_q_0 : dout_q_1;
	end

	assign D_IN_0 = din_0, D_IN_1 = din_1;

	generate
    PACKAGE_PIN_O = dout;
		if (PIN_TYPE[5:4] == 2'b01) assign PACKAGE_PIN_OE = 1'b1;
		if (PIN_TYPE[5:4] == 2'b10) assign PACKAGE_PIN_OE = OUTPUT_ENABLE;
		if (PIN_TYPE[5:4] == 2'b11) assign PACKAGE_PIN_OE = outena_q;
	endgenerate

endmodule


`ifndef PASSTHROUGH
`define PASSTHROUGH

module passthrough(
	input  inv,
  output outv);

assign outv = inv;

endmodule

`endif


module pll(
  input  clock_in,
  output clock_out,
  output rst
);
  wire lock;
  assign rst = ~lock;
  SB_PLL40_CORE #(.FEEDBACK_PATH("SIMPLE"),
                  .PLLOUT_SELECT("GENCLK"),
                  .DIVR(4'b0001),
                  .DIVF(7'b1000010),
                  .DIVQ(3'b100),
                  .FILTER_RANGE(3'b001),
                 ) uut (
                         .REFERENCECLK(clock_in),
                         .PLLOUTCORE(clock_out),
                         .RESETB(1'b1),
                         .BYPASS(1'b0),
                         .LOCK(lock)
                        );

endmodule


// SL 2021-12-12
// produces an inverted clock of same frequency through DDR primitives

`ifndef DDR_CLOCK
`define DDR_CLOCK

module ddr_clock(
        input  clock,
        input  enable,
        output ddr_clock
    );

`ifdef ICE40

`ifdef SIM_SB_IO
  _SB_IO #(
`else
  SB_IO #(
`endif
    .PIN_TYPE(6'b1100_01)
  ) sbio_clk (
      .PACKAGE_PIN_O(ddr_clock),
      .D_OUT_0(1'b0),
      .D_OUT_1(1'b1),
      .OUTPUT_ENABLE(enable),
      .OUTPUT_CLK(clock)
  );

`else

`ifdef ECP5

reg rnenable;

ODDRX1F oddr
      (
        .Q(ddr_clock),
        .D0(1'b0),
        .D1(1'b1),
        .SCLK(clock),
        .RST(~enable)
      );

always @(posedge clock) begin
  rnenable <= ~enable;
end

`else

  reg renable;
  reg rddr_clock;
  always @(posedge clock) begin
    rddr_clock <= 0;
    renable    <= enable;
  end
  always @(negedge clock) begin
    rddr_clock <= renable;
  end
  assign ddr_clock = rddr_clock;

`endif
`endif

endmodule

`endif


`ifndef ICE40_SB_IO_INOUT
`define ICE40_SB_IO_INOUT

module sb_io_inout #(parameter TYPE=6'b1101_00) (
  input        clock,
	input        oe,
  input        out,
	output       in,
  input        pin_i,
  output       pin_o,
  output       pin_oe
  );

  wire unused;

`ifdef SIM_SB_IO
  _SB_IO #(
`else
  SB_IO #(
`endif
    .PIN_TYPE(TYPE)
  ) sbio (
      .PACKAGE_PIN_I(pin_i),
      .PACKAGE_PIN_O(pin_o),
      .PACKAGE_PIN_OE(pin_oe),
			.OUTPUT_ENABLE(oe),
      .D_OUT_0(out),
      .D_OUT_1(out),
      .D_IN_0(unused),
			.D_IN_1(in),
      .OUTPUT_CLK(clock),
      .INPUT_CLK(clock)
  );

endmodule

`endif

// http://www.latticesemi.com/~/media/LatticeSemi/Documents/TechnicalBriefs/SBTICETechnologyLibrary201504.pdf


`ifndef ICE40_SB_IO
`define ICE40_SB_IO

module sb_io(
  input        clock,
  input        out,
  output       pin
  );
`ifdef SIM_SB_IO
  _SB_IO #(
`else
  SB_IO #(
`endif
    .PIN_TYPE(6'b0101_01)
    //                ^^ ignored (input)
    //           ^^^^ registered output
  ) sbio (
      .PACKAGE_PIN_O(pin),
      .D_OUT_0(out),
      .OUTPUT_ENABLE(1'b1),
      .OUTPUT_CLK(clock)
  );

endmodule

`endif

// http://www.latticesemi.com/~/media/LatticeSemi/Documents/TechnicalBriefs/SBTICETechnologyLibrary201504.pdf


module M_spi_mode3_send_M_main_display (
in_enable,
in_data_or_command,
in_byte,
out_spi_clk,
out_spi_mosi,
out_spi_dc,
out_ready,
reset,
out_clock,
clock
);
input  [0:0] in_enable;
input  [0:0] in_data_or_command;
input  [7:0] in_byte;
output  [0:0] out_spi_clk;
output  [0:0] out_spi_mosi;
output  [0:0] out_spi_dc;
output  [0:0] out_ready;
input reset;
output out_clock;
input clock;
assign out_clock = clock;

reg  [1:0] _d_osc;
reg  [1:0] _q_osc;
reg  [0:0] _d_dc;
reg  [0:0] _q_dc;
reg  [8:0] _d_sending;
reg  [8:0] _q_sending;
reg  [8:0] _d_busy;
reg  [8:0] _q_busy;
reg  [0:0] _d_spi_clk;
reg  [0:0] _q_spi_clk;
reg  [0:0] _d_spi_mosi;
reg  [0:0] _q_spi_mosi;
reg  [0:0] _d_spi_dc;
reg  [0:0] _q_spi_dc;
reg  [0:0] _d_ready;
reg  [0:0] _q_ready;
assign out_spi_clk = _q_spi_clk;
assign out_spi_mosi = _q_spi_mosi;
assign out_spi_dc = _q_spi_dc;
assign out_ready = _q_ready;



`ifdef FORMAL
initial begin
assume(reset);
end
`endif
always @* begin
_d_osc = _q_osc;
_d_dc = _q_dc;
_d_sending = _q_sending;
_d_busy = _q_busy;
_d_spi_clk = _q_spi_clk;
_d_spi_mosi = _q_spi_mosi;
_d_spi_dc = _q_spi_dc;
_d_ready = _q_ready;
// _always_pre
// __block_1
_d_spi_dc = _q_dc;

_d_osc = _q_busy[0+:1] ? {_q_osc[0+:1],_q_osc[1+:1]}:2'b1;

_d_spi_clk = ~_q_busy[0+:1]||(_d_osc[1+:1]);

_d_ready = ~_q_busy[1+:1];

if (in_enable) begin
// __block_2
// __block_4
_d_dc = in_data_or_command;

_d_sending = {in_byte[0+:1],in_byte[1+:1],in_byte[2+:1],in_byte[3+:1],in_byte[4+:1],in_byte[5+:1],in_byte[6+:1],in_byte[7+:1],1'b0};

_d_busy = 9'b111111111;

_d_osc = 1;

// __block_5
end else begin
// __block_3
// __block_6
_d_spi_mosi = _q_sending[0+:1];

_d_sending = _d_osc[1+:1] ? {1'b0,_q_sending[1+:8]}:_q_sending;

_d_busy = _d_osc[1+:1] ? {1'b0,_q_busy[1+:8]}:_q_busy;

// __block_7
end
// 'after'
// __block_8
// __block_9
// _always_post
// pipeline stage triggers
end

always @(posedge clock) begin
_q_osc <= (reset) ? 1 : _d_osc;
_q_dc <= (reset) ? 0 : _d_dc;
_q_sending <= (reset) ? 0 : _d_sending;
_q_busy <= (reset) ? 0 : _d_busy;
_q_spi_clk <= _d_spi_clk;
_q_spi_mosi <= _d_spi_mosi;
_q_spi_dc <= _d_spi_dc;
_q_ready <= _d_ready;
end

endmodule


module M_qpsram_qspi_M_main_ram_ram_spi (
in_send,
in_trigger,
in_send_else_read,
out_read,
out_clk,
out_csn,
inout_io0_i,
inout_io0_o,
inout_io0_oe,
inout_io1_i,
inout_io1_o,
inout_io1_oe,
inout_io2_i,
inout_io2_o,
inout_io2_oe,
inout_io3_i,
inout_io3_o,
inout_io3_oe,
reset,
out_clock,
clock
);
input   [7:0] in_send;
input   [0:0] in_trigger;
input   [0:0] in_send_else_read;
output  [7:0] out_read;
output  [0:0] out_clk;
output  [0:0] out_csn;
input   [0:0] inout_io0_i;
output  [0:0] inout_io0_o;
output  [0:0] inout_io0_oe;
input   [0:0] inout_io1_i;
output  [0:0] inout_io1_o;
output  [0:0] inout_io1_oe;
input   [0:0] inout_io2_i;
output  [0:0] inout_io2_o;
output  [0:0] inout_io2_oe;
input   [0:0] inout_io3_i;
output  [0:0] inout_io3_o;
output  [0:0] inout_io3_oe;
input reset;
output out_clock;
input clock;
assign out_clock = clock;
wire  [0:0] _w_ddr_clock_unnamed_5_ddr_clock;
wire  [0:0] _w_sb_io_inout_unnamed_6_in;
wire  [0:0] _w_sb_io_inout_unnamed_7_in;
wire  [0:0] _w_sb_io_inout_unnamed_8_in;
wire  [0:0] _w_sb_io_inout_unnamed_9_in;
wire  [0:0] _w_sb_io_unnamed_10_pin;
reg  [3:0] _t_io_oe;
reg  [3:0] _t_io_o;
reg  [0:0] _t_chip_select;

reg  [7:0] _d_sending = 0;
reg  [7:0] _q_sending = 0;
reg  [0:0] _d_osc = 0;
reg  [0:0] _q_osc = 0;
reg  [0:0] _d_enable = 0;
reg  [0:0] _q_enable = 0;
reg  [7:0] _d_read;
reg  [7:0] _q_read;
assign out_read = _q_read;
assign out_clk = _w_ddr_clock_unnamed_5_ddr_clock;
assign out_csn = _w_sb_io_unnamed_10_pin;
ddr_clock ddr_clock_unnamed_5 (
.clock(clock),
.enable(_q_enable),
.ddr_clock(_w_ddr_clock_unnamed_5_ddr_clock));
sb_io_inout #(
.TYPE(6'b1101_00)
)
sb_io_inout_unnamed_6 (
.clock(clock),
.oe(_t_io_oe[0+:1]),
.out(_t_io_o[0+:1]),
.in(_w_sb_io_inout_unnamed_6_in),
.pin_i(inout_io0_i)
.pin_o(inout_io0_o)
.pin_oe(inout_io0_oe)
);
sb_io_inout #(
.TYPE(6'b1101_00)
)
sb_io_inout_unnamed_7 (
.clock(clock),
.oe(_t_io_oe[1+:1]),
.out(_t_io_o[1+:1]),
.in(_w_sb_io_inout_unnamed_7_in),
.pin_i(inout_io1_i)
.pin_o(inout_io1_o)
.pin_oe(inout_io1_oe)
);
sb_io_inout #(
.TYPE(6'b1101_00)
)
sb_io_inout_unnamed_8 (
.clock(clock),
.oe(_t_io_oe[2+:1]),
.out(_t_io_o[2+:1]),
.in(_w_sb_io_inout_unnamed_8_in),
.pin_i(inout_io2_i)
.pin_o(inout_io2_o)
.pin_oe(inout_io2_oe)
);
sb_io_inout #(
.TYPE(6'b1101_00)
)
sb_io_inout_unnamed_9 (
.clock(clock),
.oe(_t_io_oe[3+:1]),
.out(_t_io_o[3+:1]),
.in(_w_sb_io_inout_unnamed_9_in),
.pin_i(inout_io3_i)
.pin_o(inout_io3_o)
.pin_oe(inout_io3_oe)
);
sb_io sb_io_unnamed_10 (
.clock(clock),
.out(_t_chip_select),
.pin(_w_sb_io_unnamed_10_pin));



`ifdef FORMAL
initial begin
assume(reset);
end
`endif
always @* begin
_d_sending = _q_sending;
_d_osc = _q_osc;
_d_enable = _q_enable;
_d_read = _q_read;
// _always_pre
// __block_1
_t_chip_select = ~(in_trigger|_q_enable);

_t_io_oe = {4{in_send_else_read}};

_d_read = {_q_read[0+:4],{_w_sb_io_inout_unnamed_9_in[0+:1],_w_sb_io_inout_unnamed_8_in[0+:1],_w_sb_io_inout_unnamed_7_in[0+:1],_w_sb_io_inout_unnamed_6_in[0+:1]}};

_t_io_o = ~_q_osc ? _q_sending[0+:4]:_q_sending[4+:4];

_d_sending = (~_q_osc|~_q_enable) ? in_send:_q_sending;

_d_osc = ~in_trigger ? 1'b0:~_q_osc;

_d_enable = in_trigger;

// __block_2
// _always_post
// pipeline stage triggers
end

always @(posedge clock) begin
_q_sending <= _d_sending;
_q_osc <= _d_osc;
_q_enable <= _d_enable;
_q_read <= _d_read;
end

endmodule


module M_qpsram_ram_M_main_ram_ram (
in_in_ready,
in_init,
in_addr,
in_wdata,
in_wenable,
out_rdata,
out_busy,
out_data_next,
out_ram_csn,
out_ram_clk,
inout_ram_io0_i,
inout_ram_io0_o,
inout_ram_io0_oe,
inout_ram_io1_i,
inout_ram_io1_o,
inout_ram_io1_oe,
inout_ram_io2_i,
inout_ram_io2_o,
inout_ram_io2_oe,
inout_ram_io3_i,
inout_ram_io3_o,
inout_ram_io3_oe,
reset,
out_clock,
clock
);
input  [0:0] in_in_ready;
input  [0:0] in_init;
input  [23:0] in_addr;
input  [7:0] in_wdata;
input  [0:0] in_wenable;
output  [7:0] out_rdata;
output  [0:0] out_busy;
output  [0:0] out_data_next;
output  [0:0] out_ram_csn;
output  [0:0] out_ram_clk;
input   [0:0] inout_ram_io0_i;
output  [0:0] inout_ram_io0_o;
output  [0:0] inout_ram_io0_oe;
input   [0:0] inout_ram_io1_i;
output  [0:0] inout_ram_io1_o;
output  [0:0] inout_ram_io1_oe;
input   [0:0] inout_ram_io2_i;
output  [0:0] inout_ram_io2_o;
output  [0:0] inout_ram_io2_oe;
input   [0:0] inout_ram_io3_i;
output  [0:0] inout_ram_io3_o;
output  [0:0] inout_ram_io3_oe;
input reset;
output out_clock;
input clock;
assign out_clock = clock;
wire  [7:0] _w_spi_read;
wire  [0:0] _w_spi_clk;
wire  [0:0] _w_spi_csn;
reg  [0:0] _t_accept_in;

reg  [31:0] _d_sendvec = 0;
reg  [31:0] _q_sendvec = 0;
reg  [7:0] _d__spi_send;
reg  [7:0] _q__spi_send;
reg  [0:0] _d__spi_trigger;
reg  [0:0] _q__spi_trigger;
reg  [0:0] _d__spi_send_else_read;
reg  [0:0] _q__spi_send_else_read;
reg  [2:0] _d_stage = 1;
reg  [2:0] _q_stage = 1;
reg  [4:0] _d_wait = 0;
reg  [4:0] _q_wait = 0;
reg  [2:0] _d_after = 0;
reg  [2:0] _q_after = 0;
reg  [4:0] _d_sending = 0;
reg  [4:0] _q_sending = 0;
reg  [0:0] _d_send_else_read = 0;
reg  [0:0] _q_send_else_read = 0;
reg  [0:0] _d_continue = 0;
reg  [0:0] _q_continue = 0;
reg  [7:0] _d_rdata;
reg  [7:0] _q_rdata;
reg  [0:0] _d_busy = 0;
reg  [0:0] _q_busy = 0;
reg  [0:0] _d_data_next = 0;
reg  [0:0] _q_data_next = 0;
assign out_rdata = _q_rdata;
assign out_busy = _q_busy;
assign out_data_next = _q_data_next;
assign out_ram_csn = _w_spi_csn;
assign out_ram_clk = _w_spi_clk;
M_qpsram_qspi_M_main_ram_ram_spi spi (
.in_send(_q__spi_send),
.in_trigger(_q__spi_trigger),
.in_send_else_read(_q__spi_send_else_read),
.out_read(_w_spi_read),
.out_clk(_w_spi_clk),
.out_csn(_w_spi_csn),
.inout_io0_i(inout_ram_io0_i),
.inout_io0_o(inout_ram_io0_o),
.inout_io0_oe(inout_ram_io0_oe),
.inout_io1_i(inout_ram_io1_i),
.inout_io1_o(inout_ram_io1_o),
.inout_io1_oe(inout_ram_io1_oe),
.inout_io2_i(inout_ram_io2_i),
.inout_io2_o(inout_ram_io2_o),
.inout_io2_oe(inout_ram_io2_oe),
.inout_io3_i(inout_ram_io3_i),
.inout_io3_o(inout_ram_io3_o),
.inout_io3_oe(inout_ram_io3_oe),
.reset(reset),
.clock(clock));



`ifdef FORMAL
initial begin
assume(reset);
end
`endif
always @* begin
_d_sendvec = _q_sendvec;
_d__spi_send = _q__spi_send;
_d__spi_trigger = _q__spi_trigger;
_d__spi_send_else_read = _q__spi_send_else_read;
_d_stage = _q_stage;
_d_wait = _q_wait;
_d_after = _q_after;
_d_sending = _q_sending;
_d_send_else_read = _q_send_else_read;
_d_continue = _q_continue;
_d_rdata = _q_rdata;
_d_busy = _q_busy;
_d_data_next = _q_data_next;
// _always_pre
// __block_1
_d__spi_send_else_read = _q_send_else_read;

_t_accept_in = 0;

_d_data_next = 0;

_d_continue = _q_continue&in_in_ready;

  case (_q_stage)
  0: begin
// __block_3_case
// __block_4
_d_stage = _q_wait[4+:1] ? _q_after:0;

_d_wait = _q_wait+1;

// __block_5
  end
  1: begin
// __block_6_case
// __block_7
_t_accept_in = 1;

// __block_8
  end
  2: begin
// __block_9_case
// __block_10
_d__spi_trigger = 1;

_d__spi_send = _q_sendvec[24+:8];

_d_sendvec = {_q_sendvec[0+:24],8'b0};

_d_stage = 0;

_d_wait = 16;

_d_after = _q_sending[0+:1] ? 3:2;

_d_sending = _q_sending>>1;

// __block_11
  end
  3: begin
// __block_12_case
// __block_13
_d_send_else_read = in_wenable;

_d__spi_trigger = ~in_init;

_d__spi_send = in_wdata;

_d_data_next = in_wenable;

_d_stage = 0;

_d_wait = in_wenable ? 16:7;

_d_after = 4;

// __block_14
  end
  4: begin
// __block_15_case
// __block_16
_d_rdata = _w_spi_read;

_d_data_next = 1;

_d__spi_trigger = _d_continue;

_d__spi_send = in_wdata;

_d_busy = _d_continue;

_d_wait = 16;

_d_stage = ~_d_continue ? 1:0;

_d_after = 4;

_t_accept_in = ~_d_continue;

// __block_17
  end
endcase
// __block_2
if ((in_in_ready|in_init)&_t_accept_in&~reset) begin
// __block_18
// __block_20
_d_sending = 5'b01000;

_d_sendvec = in_init ? {32'b00000000000100010000000100000001}:{in_wenable ? 8'h02:8'hEB,in_addr};

_d_send_else_read = 1;

_d_busy = 1;

_d_stage = 2;

_d_continue = 1;

// __block_21
end else begin
// __block_19
end
// 'after'
// __block_22
// __block_23
// _always_post
// pipeline stage triggers
end

always @(posedge clock) begin
_q_sendvec <= _d_sendvec;
_q__spi_send <= _d__spi_send;
_q__spi_trigger <= _d__spi_trigger;
_q__spi_send_else_read <= _d__spi_send_else_read;
_q_stage <= _d_stage;
_q_wait <= _d_wait;
_q_after <= _d_after;
_q_sending <= _d_sending;
_q_send_else_read <= _d_send_else_read;
_q_continue <= _d_continue;
_q_rdata <= _d_rdata;
_q_busy <= _d_busy;
_q_data_next <= _d_data_next;
end

endmodule


module M_qqspi_memory_M_main_ram (
in_io_addr,
in_io_wenable,
in_io_byte_size,
in_io_byte_offset,
in_io_wdata,
in_io_req_valid,
out_io_rdata,
out_io_done,
out_ram_clk,
out_ram_csn,
out_ram_bank,
inout_ram_io0_i,
inout_ram_io0_o,
inout_ram_io0_oe,
inout_ram_io1_i,
inout_ram_io1_o,
inout_ram_io1_oe,
inout_ram_io2_i,
inout_ram_io2_o,
inout_ram_io2_oe,
inout_ram_io3_i,
inout_ram_io3_o,
inout_ram_io3_oe,
reset,
out_clock,
clock
);
input  [24-1:0] in_io_addr;
input  [1-1:0] in_io_wenable;
input  [3-1:0] in_io_byte_size;
input  [2-1:0] in_io_byte_offset;
input  [32-1:0] in_io_wdata;
input  [1-1:0] in_io_req_valid;
output  [32-1:0] out_io_rdata;
output  [1-1:0] out_io_done;
output  [0:0] out_ram_clk;
output  [0:0] out_ram_csn;
output  [1:0] out_ram_bank;
input   [0:0] inout_ram_io0_i;
output  [0:0] inout_ram_io0_o;
output  [0:0] inout_ram_io0_oe;
input   [0:0] inout_ram_io1_i;
output  [0:0] inout_ram_io1_o;
output  [0:0] inout_ram_io1_oe;
input   [0:0] inout_ram_io2_i;
output  [0:0] inout_ram_io2_o;
output  [0:0] inout_ram_io2_oe;
input   [0:0] inout_ram_io3_i;
output  [0:0] inout_ram_io3_o;
output  [0:0] inout_ram_io3_oe;
input reset;
output out_clock;
input clock;
assign out_clock = clock;
wire  [7:0] _w_ram_rdata;
wire  [0:0] _w_ram_busy;
wire  [0:0] _w_ram_data_next;
wire  [0:0] _w_ram_ram_csn;
wire  [0:0] _w_ram_ram_clk;
wire  [0:0] _c___block_1_in_fastram;
assign _c___block_1_in_fastram = 0;
reg  [0:0] _t__ram_init;
reg  [7:0] _t__ram_wdata;
reg  [0:0] _t___block_1_in_periph;
reg  [0:0] _t___block_1_req_valid;
reg  [0:0] _t___block_1_req_valid_ram;
reg  [3:0] _t___block_1_work_init;

reg  [0:0] _d__ram_in_ready;
reg  [0:0] _q__ram_in_ready;
reg  [23:0] _d__ram_addr;
reg  [23:0] _q__ram_addr;
reg  [0:0] _d__ram_wenable;
reg  [0:0] _q__ram_wenable;
reg  [0:0] _d_ram_was_busy = 0;
reg  [0:0] _q_ram_was_busy = 0;
reg  [3:0] _d_work_vector = 0;
reg  [3:0] _q_work_vector = 0;
reg  [1:0] _d_count = 0;
reg  [1:0] _q_count = 0;
reg  [31:0] _d_wdata = 0;
reg  [31:0] _q_wdata = 0;
reg  [32-1:0] _d_io_rdata;
reg  [32-1:0] _q_io_rdata;
reg  [1-1:0] _d_io_done;
reg  [1-1:0] _q_io_done;
reg  [1:0] _d_ram_bank;
reg  [1:0] _q_ram_bank;
assign out_io_rdata = _q_io_rdata;
assign out_io_done = _q_io_done;
assign out_ram_clk = _w_ram_ram_clk;
assign out_ram_csn = _w_ram_ram_csn;
assign out_ram_bank = _q_ram_bank;
M_qpsram_ram_M_main_ram_ram ram (
.in_in_ready(_d__ram_in_ready),
.in_init(_t__ram_init),
.in_addr(_d__ram_addr),
.in_wdata(_t__ram_wdata),
.in_wenable(_d__ram_wenable),
.out_rdata(_w_ram_rdata),
.out_busy(_w_ram_busy),
.out_data_next(_w_ram_data_next),
.out_ram_csn(_w_ram_ram_csn),
.out_ram_clk(_w_ram_ram_clk),
.inout_io0_i(inout_ram_io0_i),
.inout_io0_o(inout_ram_io0_o),
.inout_io0_oe(inout_ram_io0_oe),
.inout_io1_i(inout_ram_io1_i),
.inout_io1_o(inout_ram_io1_o),
.inout_io1_oe(inout_ram_io1_oe),
.inout_io2_i(inout_ram_io2_i),
.inout_io2_o(inout_ram_io2_o),
.inout_io2_oe(inout_ram_io2_oe),
.inout_io3_i(inout_ram_io3_i),
.inout_io3_o(inout_ram_io3_o),
.inout_io3_oe(inout_ram_io3_oe),
.reset(reset),
.clock(clock));



`ifdef FORMAL
initial begin
assume(reset);
end
`endif
always @* begin
_d__ram_in_ready = _q__ram_in_ready;
_d__ram_addr = _q__ram_addr;
_d__ram_wenable = _q__ram_wenable;
_d_ram_was_busy = _q_ram_was_busy;
_d_work_vector = _q_work_vector;
_d_count = _q_count;
_d_wdata = _q_wdata;
_d_io_rdata = _q_io_rdata;
_d_io_done = _q_io_done;
_d_ram_bank = _q_ram_bank;
// _always_pre
// __block_1
// var inits
// --
_t__ram_init = 0;

_t___block_1_in_periph = in_io_addr[21+:3]==3'b100;

_t___block_1_req_valid = in_io_req_valid&~_t___block_1_in_periph;

_t___block_1_req_valid_ram = _t___block_1_req_valid;

_d_io_rdata[{_q_count,3'b0}+:8] = (_w_ram_data_next ? _w_ram_rdata:8'b0)|((~_w_ram_data_next&~_c___block_1_in_fastram) ? _q_io_rdata[{_q_count,3'b0}+:8]:8'b0);

_t__ram_wdata = _q_wdata[0+:8];

_d_wdata = (_w_ram_data_next|(_c___block_1_in_fastram&~in_io_req_valid)) ? {8'b0,_q_wdata[8+:24]}:_t___block_1_req_valid ? in_io_wdata:_q_wdata;

_d__ram_addr = _t___block_1_req_valid_ram ? {in_io_addr[0+:21],in_io_byte_offset}:_q__ram_addr;

_d_ram_bank = in_io_addr[21+:2];

_d__ram_wenable = _t___block_1_req_valid_ram ? in_io_wenable:_q__ram_wenable;

_d_count = (_t___block_1_req_valid) ? 0:(_w_ram_data_next|_c___block_1_in_fastram) ? (_q_count+1):_q_count;

_t___block_1_work_init = (in_io_byte_size[1+:1] ? 3'b001:3'b000)|(in_io_byte_size[2+:1] ? 3'b100:3'b000);

_d_work_vector = _t___block_1_req_valid ? ((_d__ram_wenable|(_c___block_1_in_fastram&~in_io_wenable)) ? {_t___block_1_work_init,_c___block_1_in_fastram}:_t___block_1_work_init):(_w_ram_data_next|_c___block_1_in_fastram) ? {1'b0,_q_work_vector[1+:3]}:_q_work_vector;

_d_io_done = (_q_ram_was_busy&~_w_ram_busy)|(in_io_req_valid&_t___block_1_in_periph);

_d_ram_was_busy = _w_ram_busy|_t___block_1_req_valid_ram;

_d__ram_in_ready = ((_d_work_vector!=0)&_q__ram_in_ready)|_t___block_1_req_valid_ram;

// __block_2
// _always_post
// pipeline stage triggers
end

always @(posedge clock) begin
_q__ram_in_ready <= _d__ram_in_ready;
_q__ram_addr <= _d__ram_addr;
_q__ram_wenable <= _d__ram_wenable;
_q_ram_was_busy <= _d_ram_was_busy;
_q_work_vector <= _d_work_vector;
_q_count <= _d_count;
_q_wdata <= _d_wdata;
_q_io_rdata <= (reset) ? 0 : _d_io_rdata;
_q_io_done <= (reset) ? 0 : _d_io_done;
_q_ram_bank <= _d_ram_bank;
end

endmodule


module M_execute_M_main_cpu_exec (
in_instr,
in_pc,
in_xa,
in_xb,
in_trigger,
out_op,
out_write_rd,
out_no_rd,
out_jump,
out_load,
out_store,
out_val,
out_storeVal,
out_working,
out_n,
out_storeAddr,
out_intop,
out_r,
reset,
out_clock,
clock
);
input  [31:0] in_instr;
input  [23:0] in_pc;
input signed [31:0] in_xa;
input signed [31:0] in_xb;
input  [0:0] in_trigger;
output  [2:0] out_op;
output  [4:0] out_write_rd;
output  [0:0] out_no_rd;
output  [0:0] out_jump;
output  [0:0] out_load;
output  [0:0] out_store;
output signed [31:0] out_val;
output  [0:0] out_storeVal;
output  [0:0] out_working;
output  [25:0] out_n;
output  [0:0] out_storeAddr;
output  [0:0] out_intop;
output signed [31:0] out_r;
input reset;
output out_clock;
input clock;
assign out_clock = clock;
reg  [0:0] _t___block_1_j;
reg  [0:0] _t___block_1_shiting;
reg  [0:0] _t___block_4_aluShift;
wire signed [31:0] _w_imm_u;
wire signed [31:0] _w_imm_j;
wire signed [31:0] _w_imm_i;
wire signed [31:0] _w_imm_b;
wire signed [31:0] _w_imm_s;
wire  [4:0] _w_opcode;
wire  [0:0] _w_AUIPC;
wire  [0:0] _w_LUI;
wire  [0:0] _w_JAL;
wire  [0:0] _w_JALR;
wire  [0:0] _w_IntImm;
wire  [0:0] _w_IntReg;
wire  [0:0] _w_CSR;
wire  [0:0] _w_branch;
wire  [0:0] _w_regOrImm;
wire  [0:0] _w_pcOrReg;
wire  [0:0] _w_sub;
wire signed [26:0] _w_addr_a;
wire signed [31:0] _w_b;
wire signed [31:0] _w_ra;
wire signed [31:0] _w_rb;
wire signed [32:0] _w_a_minus_b;
wire  [0:0] _w_a_lt_b;
wire  [0:0] _w_a_lt_b_u;
wire  [0:0] _w_a_eq_b;
wire signed [26:0] _w_addr_imm;

reg  [4:0] _d_shamt = 0;
reg  [4:0] _q_shamt = 0;
reg  [31:0] _d_cycle = 0;
reg  [31:0] _q_cycle = 0;
reg  [2:0] _d_op;
reg  [2:0] _q_op;
reg  [4:0] _d_write_rd;
reg  [4:0] _q_write_rd;
reg  [0:0] _d_no_rd;
reg  [0:0] _q_no_rd;
reg  [0:0] _d_jump;
reg  [0:0] _q_jump;
reg  [0:0] _d_load;
reg  [0:0] _q_load;
reg  [0:0] _d_store;
reg  [0:0] _q_store;
reg signed [31:0] _d_val;
reg signed [31:0] _q_val;
reg  [0:0] _d_storeVal;
reg  [0:0] _q_storeVal;
reg  [0:0] _d_working = 0;
reg  [0:0] _q_working = 0;
reg  [25:0] _d_n = 0;
reg  [25:0] _q_n = 0;
reg  [0:0] _d_storeAddr;
reg  [0:0] _q_storeAddr;
reg  [0:0] _d_intop;
reg  [0:0] _q_intop;
reg signed [31:0] _d_r;
reg signed [31:0] _q_r;
assign out_op = _q_op;
assign out_write_rd = _q_write_rd;
assign out_no_rd = _q_no_rd;
assign out_jump = _q_jump;
assign out_load = _q_load;
assign out_store = _q_store;
assign out_val = _q_val;
assign out_storeVal = _q_storeVal;
assign out_working = _q_working;
assign out_n = _q_n;
assign out_storeAddr = _q_storeAddr;
assign out_intop = _q_intop;
assign out_r = _q_r;


assign _w_imm_u = {in_instr[12+:20],12'b0};
assign _w_imm_j = {{12{in_instr[31+:1]}},in_instr[12+:8],in_instr[20+:1],in_instr[21+:10],1'b0};
assign _w_imm_i = {{20{in_instr[31+:1]}},in_instr[20+:12]};
assign _w_imm_b = {{20{in_instr[31+:1]}},in_instr[7+:1],in_instr[25+:6],in_instr[8+:4],1'b0};
assign _w_imm_s = {{20{in_instr[31+:1]}},in_instr[25+:7],in_instr[7+:5]};
assign _w_opcode = in_instr[2+:5];
assign _w_AUIPC = _w_opcode==5'b00101;
assign _w_LUI = _w_opcode==5'b01101;
assign _w_JAL = _w_opcode==5'b11011;
assign _w_JALR = _w_opcode==5'b11001;
assign _w_IntImm = _w_opcode==5'b00100;
assign _w_IntReg = _w_opcode==5'b01100;
assign _w_CSR = _w_opcode==5'b11100;
assign _w_branch = _w_opcode==5'b11000;
assign _w_regOrImm = _w_IntReg|_w_branch;
assign _w_pcOrReg = _w_AUIPC|_w_JAL|_w_branch;
assign _w_sub = _w_IntReg&in_instr[30+:1];
assign _w_addr_a = _w_pcOrReg ? $signed({1'b0,in_pc[0+:24],2'b0}):in_xa;
assign _w_b = _w_regOrImm ? (in_xb):_w_imm_i;
assign _w_ra = in_xa;
assign _w_rb = _w_b;
assign _w_a_minus_b = {1'b1,~_w_rb}+{1'b0,_w_ra}+33'b1;
assign _w_a_lt_b = (_w_ra[31+:1]^_w_rb[31+:1]) ? _w_ra[31+:1]:_w_a_minus_b[32+:1];
assign _w_a_lt_b_u = _w_a_minus_b[32+:1];
assign _w_a_eq_b = _w_a_minus_b[0+:32]==0;
assign _w_addr_imm = (_w_AUIPC ? _w_imm_u:32'b0)|(_w_JAL ? _w_imm_j:32'b0)|(_w_branch ? _w_imm_b:32'b0)|((_w_JALR|_d_load) ? _w_imm_i:32'b0)|(_d_store ? _w_imm_s:32'b0);

`ifdef FORMAL
initial begin
assume(reset);
end
`endif
always @* begin
_d_shamt = _q_shamt;
_d_cycle = _q_cycle;
_d_op = _q_op;
_d_write_rd = _q_write_rd;
_d_no_rd = _q_no_rd;
_d_jump = _q_jump;
_d_load = _q_load;
_d_store = _q_store;
_d_val = _q_val;
_d_storeVal = _q_storeVal;
_d_working = _q_working;
_d_n = _q_n;
_d_storeAddr = _q_storeAddr;
_d_intop = _q_intop;
_d_r = _q_r;
_t___block_4_aluShift = 0;
// _always_pre
// __block_1
_d_load = _w_opcode==5'b00000;

_d_store = _w_opcode==5'b01000;

_d_op = in_instr[12+:3];

_d_write_rd = in_instr[7+:5];

_d_no_rd = _w_branch|_d_store|(in_instr[7+:5]==5'b0);

_d_intop = (_w_IntImm|_w_IntReg);

_d_storeAddr = _w_AUIPC;

_d_val = _w_LUI ? _w_imm_u:0;

_d_storeVal = _w_LUI|_w_CSR;

_t___block_1_shiting = (_q_shamt!=0);

if (in_trigger) begin
// __block_2
// __block_4
_t___block_4_aluShift = (_w_IntImm|_w_IntReg)&_d_op[0+:2]==2'b01;

_d_shamt = _t___block_4_aluShift ? $unsigned(_w_b[0+:5]):0;

_d_r = in_xa;

// __block_5
end else begin
// __block_3
// __block_6
if (_t___block_1_shiting) begin
// __block_7
// __block_9
_d_shamt = _q_shamt-1;

_d_r = _d_op[2+:1] ? (in_instr[30+:1] ? {_q_r[31+:1],_q_r[1+:31]}:{$signed(1'b0),_q_r[1+:31]}):{_q_r[0+:31],$signed(1'b0)};

// __block_10
end else begin
// __block_8
end
// 'after'
// __block_11
// __block_12
end
// 'after'
// __block_13
_d_working = (_d_shamt!=0);

  case (_d_op)
  3'b000: begin
// __block_15_case
// __block_16
_d_r = _w_sub ? _w_a_minus_b:_w_ra+_w_rb;

// __block_17
  end
  3'b010: begin
// __block_18_case
// __block_19
_d_r = _w_a_lt_b;

// __block_20
  end
  3'b011: begin
// __block_21_case
// __block_22
_d_r = _w_a_lt_b_u;

// __block_23
  end
  3'b100: begin
// __block_24_case
// __block_25
_d_r = _w_ra^_w_rb;

// __block_26
  end
  3'b110: begin
// __block_27_case
// __block_28
_d_r = _w_ra|_w_rb;

// __block_29
  end
  3'b001: begin
// __block_30_case
// __block_31
// __block_32
  end
  3'b101: begin
// __block_33_case
// __block_34
// __block_35
  end
  3'b111: begin
// __block_36_case
// __block_37
_d_r = _w_ra&_w_rb;

// __block_38
  end
  default: begin
// __block_39_case
// __block_40
_d_r = {32{1'bx}};

// __block_41
  end
endcase
// __block_14
  case (_d_op[1+:2])
  2'b00: begin
// __block_43_case
// __block_44
_t___block_1_j = _w_a_eq_b;

// __block_45
  end
  2'b10: begin
// __block_46_case
// __block_47
_t___block_1_j = _w_a_lt_b;

// __block_48
  end
  2'b11: begin
// __block_49_case
// __block_50
_t___block_1_j = _w_a_lt_b_u;

// __block_51
  end
  default: begin
// __block_52_case
// __block_53
_t___block_1_j = 1'bx;

// __block_54
  end
endcase
// __block_42
_d_jump = (_w_JAL|_w_JALR)|(_w_branch&(_t___block_1_j^_d_op[0+:1]));

_d_n = _w_addr_a+_w_addr_imm;

_d_cycle = _q_cycle+1;

// __block_55
// _always_post
// pipeline stage triggers
end

always @(posedge clock) begin
_q_shamt <= _d_shamt;
_q_cycle <= _d_cycle;
_q_op <= _d_op;
_q_write_rd <= _d_write_rd;
_q_no_rd <= _d_no_rd;
_q_jump <= _d_jump;
_q_load <= _d_load;
_q_store <= _d_store;
_q_val <= _d_val;
_q_storeVal <= _d_storeVal;
_q_working <= _d_working;
_q_n <= _d_n;
_q_storeAddr <= _d_storeAddr;
_q_intop <= _d_intop;
_q_r <= _d_r;
end

endmodule


// SL 2019, MIT license
module M_icev_ram_M_main_cpu_mem_xregsA(
input                  [1-1:0] in_wenable,
input      signed [32-1:0]    in_wdata,
input                  [5-1:0]    in_addr,
output reg signed [32-1:0]    out_rdata,
input                                        clock
);
  (* no_rw_check *) reg signed [32-1:0] buffer[32-1:0];
`ifdef SIMULATION
  // in simulation we use a different code that matches yosys output with
  // no_rw_check enabled (which we use to preserve compact LUT designs)
  always @(posedge clock) begin
    if (in_wenable) begin
      buffer[in_addr] <= in_wdata;
      out_rdata       <= in_wdata;
    end else begin
      out_rdata       <= buffer[in_addr];
    end
  end
`else
  always @(posedge clock) begin
    if (in_wenable) begin
      buffer[in_addr] <= in_wdata;
    end
    out_rdata <= buffer[in_addr];
  end
`endif
initial begin
 buffer[0] = 0;
 buffer[1] = 0;
 buffer[2] = 0;
 buffer[3] = 0;
 buffer[4] = 0;
 buffer[5] = 0;
 buffer[6] = 0;
 buffer[7] = 0;
 buffer[8] = 0;
 buffer[9] = 0;
 buffer[10] = 0;
 buffer[11] = 0;
 buffer[12] = 0;
 buffer[13] = 0;
 buffer[14] = 0;
 buffer[15] = 0;
 buffer[16] = 0;
 buffer[17] = 0;
 buffer[18] = 0;
 buffer[19] = 0;
 buffer[20] = 0;
 buffer[21] = 0;
 buffer[22] = 0;
 buffer[23] = 0;
 buffer[24] = 0;
 buffer[25] = 0;
 buffer[26] = 0;
 buffer[27] = 0;
 buffer[28] = 0;
 buffer[29] = 0;
 buffer[30] = 0;
 buffer[31] = 0;
end

endmodule

// SL 2019, MIT license
module M_icev_ram_M_main_cpu_mem_xregsB(
input                  [1-1:0] in_wenable,
input      signed [32-1:0]    in_wdata,
input                  [5-1:0]    in_addr,
output reg signed [32-1:0]    out_rdata,
input                                        clock
);
  (* no_rw_check *) reg signed [32-1:0] buffer[32-1:0];
`ifdef SIMULATION
  // in simulation we use a different code that matches yosys output with
  // no_rw_check enabled (which we use to preserve compact LUT designs)
  always @(posedge clock) begin
    if (in_wenable) begin
      buffer[in_addr] <= in_wdata;
      out_rdata       <= in_wdata;
    end else begin
      out_rdata       <= buffer[in_addr];
    end
  end
`else
  always @(posedge clock) begin
    if (in_wenable) begin
      buffer[in_addr] <= in_wdata;
    end
    out_rdata <= buffer[in_addr];
  end
`endif
initial begin
 buffer[0] = 0;
 buffer[1] = 0;
 buffer[2] = 0;
 buffer[3] = 0;
 buffer[4] = 0;
 buffer[5] = 0;
 buffer[6] = 0;
 buffer[7] = 0;
 buffer[8] = 0;
 buffer[9] = 0;
 buffer[10] = 0;
 buffer[11] = 0;
 buffer[12] = 0;
 buffer[13] = 0;
 buffer[14] = 0;
 buffer[15] = 0;
 buffer[16] = 0;
 buffer[17] = 0;
 buffer[18] = 0;
 buffer[19] = 0;
 buffer[20] = 0;
 buffer[21] = 0;
 buffer[22] = 0;
 buffer[23] = 0;
 buffer[24] = 0;
 buffer[25] = 0;
 buffer[26] = 0;
 buffer[27] = 0;
 buffer[28] = 0;
 buffer[29] = 0;
 buffer[30] = 0;
 buffer[31] = 0;
end

endmodule

module M_icev_ram_M_main_cpu (
in_mem_rdata,
in_mem_done,
out_mem_addr,
out_mem_wenable,
out_mem_byte_offset,
out_mem_byte_size,
out_mem_wdata,
out_mem_req_valid,
reset,
out_clock,
clock
);
input  [32-1:0] in_mem_rdata;
input  [1-1:0] in_mem_done;
output  [24-1:0] out_mem_addr;
output  [1-1:0] out_mem_wenable;
output  [2-1:0] out_mem_byte_offset;
output  [3-1:0] out_mem_byte_size;
output  [32-1:0] out_mem_wdata;
output  [1-1:0] out_mem_req_valid;
input reset;
output out_clock;
input clock;
assign out_clock = clock;
wire  [2:0] _w_exec_op;
wire  [4:0] _w_exec_write_rd;
wire  [0:0] _w_exec_no_rd;
wire  [0:0] _w_exec_jump;
wire  [0:0] _w_exec_load;
wire  [0:0] _w_exec_store;
wire signed [31:0] _w_exec_val;
wire  [0:0] _w_exec_storeVal;
wire  [0:0] _w_exec_working;
wire  [25:0] _w_exec_n;
wire  [0:0] _w_exec_storeAddr;
wire  [0:0] _w_exec_intop;
wire signed [31:0] _w_exec_r;
wire signed [31:0] _w_mem_xregsA_rdata;
wire signed [31:0] _w_mem_xregsB_rdata;
reg  [0:0] _t_xregsA_wenable;
reg signed [31:0] _t_xregsA_wdata;
reg  [4:0] _t_xregsA_addr;
reg  [0:0] _t_xregsB_wenable;
reg signed [31:0] _t_xregsB_wdata;
reg  [4:0] _t_xregsB_addr;
reg signed [31:0] _t_loaded;
reg  [0:0] _t__exec_trigger;
reg signed [31:0] _t_write_back;
reg  [0:0] _t_do_load_store;
reg  [0:0] _t_do_fetch;
reg  [0:0] _t___block_26_instr_done;
wire  [23:0] _w_pc_plus1;
wire  [4:0] _w_opcode;
wire  [0:0] _w_load;
wire  [0:0] _w_store;
wire  [0:0] _w_load_store;
wire  [0:0] _w_reqmem_done;
wire  [0:0] _w_reqmem_pending;

reg  [31:0] _d_instr = 19;
reg  [31:0] _q_instr = 19;
reg  [0:0] _d_instr_trigger = 0;
reg  [0:0] _q_instr_trigger = 0;
reg  [3:0] _d_stage = 4'b1000;
reg  [3:0] _q_stage = 4'b1000;
reg  [23:0] _d_pc = -1;
reg  [23:0] _q_pc = -1;
reg  [0:0] _d_reqmem = 0;
reg  [0:0] _q_reqmem = 0;
reg  [24-1:0] _d_mem_addr;
reg  [24-1:0] _q_mem_addr;
reg  [1-1:0] _d_mem_wenable;
reg  [1-1:0] _q_mem_wenable;
reg  [2-1:0] _d_mem_byte_offset;
reg  [2-1:0] _q_mem_byte_offset;
reg  [3-1:0] _d_mem_byte_size;
reg  [3-1:0] _q_mem_byte_size;
reg  [32-1:0] _d_mem_wdata;
reg  [32-1:0] _q_mem_wdata;
reg  [1-1:0] _d_mem_req_valid;
reg  [1-1:0] _q_mem_req_valid;
assign out_mem_addr = _q_mem_addr;
assign out_mem_wenable = _q_mem_wenable;
assign out_mem_byte_offset = _q_mem_byte_offset;
assign out_mem_byte_size = _q_mem_byte_size;
assign out_mem_wdata = _q_mem_wdata;
assign out_mem_req_valid = _q_mem_req_valid;
M_execute_M_main_cpu_exec exec (
.in_instr(_q_instr),
.in_pc(_q_pc),
.in_xa(_w_mem_xregsA_rdata),
.in_xb(_w_mem_xregsB_rdata),
.in_trigger(_t__exec_trigger),
.out_op(_w_exec_op),
.out_write_rd(_w_exec_write_rd),
.out_no_rd(_w_exec_no_rd),
.out_jump(_w_exec_jump),
.out_load(_w_exec_load),
.out_store(_w_exec_store),
.out_val(_w_exec_val),
.out_storeVal(_w_exec_storeVal),
.out_working(_w_exec_working),
.out_n(_w_exec_n),
.out_storeAddr(_w_exec_storeAddr),
.out_intop(_w_exec_intop),
.out_r(_w_exec_r),
.reset(reset),
.clock(clock));

M_icev_ram_M_main_cpu_mem_xregsA __mem__xregsA(
.clock(clock),
.in_wenable(_t_xregsA_wenable),
.in_wdata(_t_xregsA_wdata),
.in_addr(_t_xregsA_addr),
.out_rdata(_w_mem_xregsA_rdata)
);
M_icev_ram_M_main_cpu_mem_xregsB __mem__xregsB(
.clock(clock),
.in_wenable(_t_xregsB_wenable),
.in_wdata(_t_xregsB_wdata),
.in_addr(_t_xregsB_addr),
.out_rdata(_w_mem_xregsB_rdata)
);

assign _w_pc_plus1 = _q_pc+1;
assign _w_opcode = _q_instr[2+:5];
assign _w_load = _w_opcode==5'b00000;
assign _w_store = _w_opcode==5'b01000;
assign _w_load_store = (_w_load|_w_store);
assign _w_reqmem_done = _q_reqmem&in_mem_done;
assign _w_reqmem_pending = _q_reqmem&~_w_reqmem_done;

`ifdef FORMAL
initial begin
assume(reset);
end
`endif
always @* begin
_d_instr = _q_instr;
_d_instr_trigger = _q_instr_trigger;
_d_stage = _q_stage;
_d_pc = _q_pc;
_d_reqmem = _q_reqmem;
_d_mem_addr = _q_mem_addr;
_d_mem_wenable = _q_mem_wenable;
_d_mem_byte_offset = _q_mem_byte_offset;
_d_mem_byte_size = _q_mem_byte_size;
_d_mem_wdata = _q_mem_wdata;
_d_mem_req_valid = _q_mem_req_valid;
_t___block_26_instr_done = 0;
// _always_pre
// __block_1
_d_mem_req_valid = 0;

_t_do_load_store = 0;

_t_do_fetch = 0;

_d_mem_byte_offset = 0;

_d_mem_byte_size = 4;

  case (_w_exec_op[0+:2])
  2'b00: begin
// __block_3_case
// __block_4
_t_loaded = {{24{(~_w_exec_op[2+:1])&in_mem_rdata[7+:1]}},in_mem_rdata[0+:8]};

// __block_5
  end
  2'b01: begin
// __block_6_case
// __block_7
_t_loaded = {{16{(~_w_exec_op[2+:1])&in_mem_rdata[15+:1]}},in_mem_rdata[0+:16]};

// __block_8
  end
  2'b10: begin
// __block_9_case
// __block_10
_t_loaded = in_mem_rdata;

// __block_11
  end
  default: begin
// __block_12_case
// __block_13
_t_loaded = {32{1'bx}};

// __block_14
  end
endcase
// __block_2
_t_write_back = (_w_exec_jump ? (_w_pc_plus1<<2):32'b0)|(_w_exec_storeAddr ? _w_exec_n[0+:26]:32'b0)|(_w_exec_storeVal ? _w_exec_val:32'b0)|(_w_exec_load ? _t_loaded:32'b0)|(_w_exec_intop ? _w_exec_r:32'b0);

_d_mem_wdata = _w_mem_xregsB_rdata;

_d_mem_wenable = 0;

_t__exec_trigger = 0;

_t_xregsA_wenable = 0;

(* parallel_case, full_case *)
  case (1'b1)
  _q_stage[0]: begin
// __block_16_case
// __block_17
_d_instr = _w_reqmem_done ? in_mem_rdata:_q_instr;

_d_pc = _w_reqmem_done ? _q_mem_addr:_q_pc;

_d_instr_trigger = _w_reqmem_done;

// __block_18
  end
  _q_stage[1]: begin
// __block_19_case
// __block_20
_t__exec_trigger = _q_instr_trigger;

_d_instr_trigger = 0;

// __block_21
  end
  _q_stage[2]: begin
// __block_22_case
// __block_23
_t_do_load_store = ~_w_exec_working&_w_load_store;

_d_mem_addr = (_w_exec_n>>2);

_d_mem_req_valid = _t_do_load_store;

_d_mem_wenable = _w_exec_store;

_d_mem_byte_size = 1<<_w_exec_op[0+:2];

_d_mem_byte_offset = _w_exec_n[0+:2];

// __block_24
  end
  _q_stage[3]: begin
// __block_25_case
// __block_26
_t___block_26_instr_done = ~_w_reqmem_pending&~_w_exec_working;

_t_xregsA_wenable = ~_w_exec_no_rd&~_w_reqmem_pending&~_w_exec_working;

_t_do_fetch = _t___block_26_instr_done&~reset;

_d_mem_addr = _t_do_fetch ? (_w_exec_jump ? (_w_exec_n>>2):_w_pc_plus1):_q_mem_addr;

_d_mem_req_valid = _t_do_fetch;

// __block_27
  end
endcase
// __block_15
_d_stage = (_w_exec_working|reset|_w_reqmem_pending) ? _q_stage:{_q_stage[2+:1]|(_q_stage[1+:1]&~_w_load_store),_q_stage[1+:1]&_w_load_store,_q_stage[0+:1],_q_stage[3+:1]};

_d_reqmem = _t_do_fetch|_t_do_load_store|_w_reqmem_pending;

_t_xregsA_wdata = _t_write_back;

_t_xregsB_wdata = _t_write_back;

_t_xregsB_wenable = _t_xregsA_wenable;

_t_xregsA_addr = _t_xregsA_wenable ? _w_exec_write_rd:_d_instr[15+:5];

_t_xregsB_addr = _t_xregsA_wenable ? _w_exec_write_rd:_d_instr[20+:5];

// __block_28
// _always_post
// pipeline stage triggers
end

always @(posedge clock) begin
_q_instr <= _d_instr;
_q_instr_trigger <= _d_instr_trigger;
_q_stage <= _d_stage;
_q_pc <= _d_pc;
_q_reqmem <= _d_reqmem;
_q_mem_addr <= (reset) ? 0 : _d_mem_addr;
_q_mem_wenable <= (reset) ? 0 : _d_mem_wenable;
_q_mem_byte_offset <= (reset) ? 0 : _d_mem_byte_offset;
_q_mem_byte_size <= (reset) ? 0 : _d_mem_byte_size;
_q_mem_wdata <= (reset) ? 0 : _d_mem_wdata;
_q_mem_req_valid <= (reset) ? 0 : _d_mem_req_valid;
end

endmodule


module M_uart_sender_M_main_usend (
in_io_data_in,
in_io_data_in_ready,
out_io_busy,
out_uart_tx,
reset,
out_clock,
clock
);
input  [8-1:0] in_io_data_in;
input  [1-1:0] in_io_data_in_ready;
output  [1-1:0] out_io_busy;
output  [0:0] out_uart_tx;
input reset;
output out_clock;
input clock;
assign out_clock = clock;
wire  [9:0] _c_interval;
assign _c_interval = 217;

reg  [9:0] _d_counter;
reg  [9:0] _q_counter;
reg  [10:0] _d_transmit;
reg  [10:0] _q_transmit;
reg  [1-1:0] _d_io_busy;
reg  [1-1:0] _q_io_busy;
reg  [0:0] _d_uart_tx;
reg  [0:0] _q_uart_tx;
assign out_io_busy = _q_io_busy;
assign out_uart_tx = _q_uart_tx;



`ifdef FORMAL
initial begin
assume(reset);
end
`endif
always @* begin
_d_counter = _q_counter;
_d_transmit = _q_transmit;
_d_io_busy = _q_io_busy;
_d_uart_tx = _q_uart_tx;
// _always_pre
// __block_1
if (_q_transmit[1+:10]!=0) begin
// __block_2
// __block_4
if (_q_counter==0) begin
// __block_5
// __block_7
_d_uart_tx = _q_transmit[0+:1];

_d_transmit = {1'b0,_q_transmit[1+:10]};

// __block_8
end else begin
// __block_6
end
// 'after'
// __block_9
_d_counter = (_q_counter==_c_interval) ? 0:(_q_counter+1);

// __block_10
end else begin
// __block_3
// __block_11
_d_uart_tx = 1;

_d_io_busy = 0;

if (in_io_data_in_ready) begin
// __block_12
// __block_14
_d_io_busy = 1;

_d_transmit = {1'b1,1'b0,in_io_data_in,1'b0};

// __block_15
end else begin
// __block_13
end
// 'after'
// __block_16
// __block_17
end
// 'after'
// __block_18
// __block_19
// _always_post
// pipeline stage triggers
end

always @(posedge clock) begin
_q_counter <= (reset) ? 0 : _d_counter;
_q_transmit <= (reset) ? 0 : _d_transmit;
_q_io_busy <= (reset) ? 0 : _d_io_busy;
_q_uart_tx <= (reset) ? 0 : _d_uart_tx;
end

endmodule


module M_main (
in_uart_rx,
out_leds,
out_ram_clk,
out_ram_csn,
out_ram_bank,
out_uart_tx,
out_spiscreen_clk,
out_spiscreen_mosi,
out_spiscreen_dc,
out_spiscreen_resn,
out_spiscreen_csn,
inout_ram_io0_i,
inout_ram_io0_o,
inout_ram_io0_oe,
inout_ram_io1_i,
inout_ram_io1_o,
inout_ram_io1_oe,
inout_ram_io2_i,
inout_ram_io2_o,
inout_ram_io2_oe,
inout_ram_io3_i,
inout_ram_io3_o,
inout_ram_io3_oe,
in_run,
out_done,
reset,
out_clock,
clock
);
input  [0:0] in_uart_rx;
output  [4:0] out_leds;
output  [0:0] out_ram_clk;
output  [0:0] out_ram_csn;
output  [1:0] out_ram_bank;
output  [0:0] out_uart_tx;
output  [0:0] out_spiscreen_clk;
output  [0:0] out_spiscreen_mosi;
output  [0:0] out_spiscreen_dc;
output  [0:0] out_spiscreen_resn;
output  [0:0] out_spiscreen_csn;
input   [0:0] inout_ram_io0_i;
output  [0:0] inout_ram_io0_o;
output  [0:0] inout_ram_io0_oe;
input   [0:0] inout_ram_io1_i;
output  [0:0] inout_ram_io1_o;
output  [0:0] inout_ram_io1_oe;
input   [0:0] inout_ram_io2_i;
output  [0:0] inout_ram_io2_o;
output  [0:0] inout_ram_io2_oe;
input   [0:0] inout_ram_io3_i;
output  [0:0] inout_ram_io3_o;
output  [0:0] inout_ram_io3_oe;
input in_run;
output out_done;
input reset;
output out_clock;
input clock;
assign out_clock = clock;
wire  [0:0] _w_passthrough_unnamed_0_outv;
wire  [0:0] _w_display_spi_clk;
wire  [0:0] _w_display_spi_mosi;
wire  [0:0] _w_display_spi_dc;
wire  [0:0] _w_display_ready;
wire  [0:0] _w_sb_io_unnamed_1_pin;
wire  [0:0] _w_sb_io_unnamed_2_pin;
wire  [0:0] _w_sb_io_unnamed_3_pin;
wire  [0:0] _w_sb_io_unnamed_4_pin;
wire  [32-1:0] _w_ram_io_rdata;
wire  [1-1:0] _w_ram_io_done;
wire  [0:0] _w_ram_ram_clk;
wire  [0:0] _w_ram_ram_csn;
wire  [1:0] _w_ram_ram_bank;
wire  [24-1:0] _w_cpu_mem_addr;
wire  [1-1:0] _w_cpu_mem_wenable;
wire  [2-1:0] _w_cpu_mem_byte_offset;
wire  [3-1:0] _w_cpu_mem_byte_size;
wire  [32-1:0] _w_cpu_mem_wdata;
wire  [1-1:0] _w_cpu_mem_req_valid;
wire  [1-1:0] _w_usend_io_busy;
wire  [0:0] _w_usend_uart_tx;
reg  [0:0] _t__display_enable;
reg  [7:0] _t_uo_data_in;
reg  [0:0] _t_uo_data_in_ready;
reg  [2:0] _t___block_4_select;
wire  [0:0] _w_displ_dta_or_cmd;
wire  [7:0] _w_displ_byte;

reg  [0:0] _d_screen_resn = 0;
reg  [0:0] _q_screen_resn = 0;
reg  [4:0] _d_leds;
reg  [4:0] _q_leds;
reg  [0:0] _d_spiscreen_csn = 0;
reg  [0:0] _q_spiscreen_csn = 0;
assign out_leds = _q_leds;
assign out_ram_clk = _w_ram_ram_clk;
assign out_ram_csn = _w_ram_ram_csn;
assign out_ram_bank = _w_ram_ram_bank;
assign out_uart_tx = _w_usend_uart_tx;
assign out_spiscreen_clk = _w_sb_io_unnamed_1_pin;
assign out_spiscreen_mosi = _w_sb_io_unnamed_2_pin;
assign out_spiscreen_dc = _w_sb_io_unnamed_3_pin;
assign out_spiscreen_resn = _w_sb_io_unnamed_4_pin;
assign out_spiscreen_csn = _q_spiscreen_csn;
assign out_done = 0;
passthrough passthrough_unnamed_0 (
.inv(clock),
.outv(_w_passthrough_unnamed_0_outv));
M_spi_mode3_send_M_main_display display (
.in_enable(_t__display_enable),
.in_data_or_command(_w_displ_dta_or_cmd),
.in_byte(_w_displ_byte),
.out_spi_clk(_w_display_spi_clk),
.out_spi_mosi(_w_display_spi_mosi),
.out_spi_dc(_w_display_spi_dc),
.out_ready(_w_display_ready),
.reset(reset),
.clock(clock));
sb_io sb_io_unnamed_1 (
.clock(_w_passthrough_unnamed_0_outv),
.out(_w_display_spi_clk),
.pin(_w_sb_io_unnamed_1_pin));
sb_io sb_io_unnamed_2 (
.clock(_w_passthrough_unnamed_0_outv),
.out(_w_display_spi_mosi),
.pin(_w_sb_io_unnamed_2_pin));
sb_io sb_io_unnamed_3 (
.clock(_w_passthrough_unnamed_0_outv),
.out(_w_display_spi_dc),
.pin(_w_sb_io_unnamed_3_pin));
sb_io sb_io_unnamed_4 (
.clock(_w_passthrough_unnamed_0_outv),
.out(_d_screen_resn),
.pin(_w_sb_io_unnamed_4_pin));
M_qqspi_memory_M_main_ram ram (
.in_io_addr(_w_cpu_mem_addr),
.in_io_wenable(_w_cpu_mem_wenable),
.in_io_byte_size(_w_cpu_mem_byte_size),
.in_io_byte_offset(_w_cpu_mem_byte_offset),
.in_io_wdata(_w_cpu_mem_wdata),
.in_io_req_valid(_w_cpu_mem_req_valid),
.out_io_rdata(_w_ram_io_rdata),
.out_io_done(_w_ram_io_done),
.out_ram_clk(_w_ram_ram_clk),
.out_ram_csn(_w_ram_ram_csn),
.out_ram_bank(_w_ram_ram_bank),
.inout_io0_i(inout_ram_io0_i),
.inout_io0_o(inout_ram_io0_o),
.inout_io0_oe(inout_ram_io0_oe),
.inout_io1_i(inout_ram_io1_i),
.inout_io1_o(inout_ram_io1_o),
.inout_io1_oe(inout_ram_io1_oe),
.inout_io2_i(inout_ram_io2_i),
.inout_io2_o(inout_ram_io2_o),
.inout_io2_oe(inout_ram_io2_oe),
.inout_io3_i(inout_ram_io3_i),
.inout_io3_o(inout_ram_io3_o),
.inout_io3_oe(inout_ram_io3_oe),
.reset(reset),
.clock(clock));
M_icev_ram_M_main_cpu cpu (
.in_mem_rdata(_w_ram_io_rdata),
.in_mem_done(_w_ram_io_done),
.out_mem_addr(_w_cpu_mem_addr),
.out_mem_wenable(_w_cpu_mem_wenable),
.out_mem_byte_offset(_w_cpu_mem_byte_offset),
.out_mem_byte_size(_w_cpu_mem_byte_size),
.out_mem_wdata(_w_cpu_mem_wdata),
.out_mem_req_valid(_w_cpu_mem_req_valid),
.reset(reset),
.clock(clock));
M_uart_sender_M_main_usend usend (
.in_io_data_in(_t_uo_data_in),
.in_io_data_in_ready(_t_uo_data_in_ready),
.out_io_busy(_w_usend_io_busy),
.out_uart_tx(_w_usend_uart_tx),
.reset(reset),
.clock(clock));


assign _w_displ_dta_or_cmd = ~_w_cpu_mem_wdata[9+:1];
assign _w_displ_byte = _w_cpu_mem_wdata[0+:8];

`ifdef FORMAL
initial begin
assume(reset);
end
`endif
always @* begin
_d_screen_resn = _q_screen_resn;
_d_leds = _q_leds;
_d_spiscreen_csn = _q_spiscreen_csn;
_t___block_4_select = 0;
// _always_pre
// __block_1
_t_uo_data_in_ready = 0;

_t_uo_data_in = _w_cpu_mem_wdata[0+:8];

_t__display_enable = 0;

if (_w_cpu_mem_req_valid&_w_cpu_mem_wenable&_w_cpu_mem_addr[21+:3]==3'b100) begin
// __block_2
// __block_4
_t___block_4_select = _w_cpu_mem_addr[0+:3];

(* parallel_case, full_case *)
  case (1'b1)
  _t___block_4_select[0]: begin
// __block_6_case
// __block_7
_d_leds = _w_cpu_mem_wdata[0+:5];

_t_uo_data_in_ready = 1;

// __block_8
  end
  _t___block_4_select[1]: begin
// __block_9_case
// __block_10
_t__display_enable = 1;

// __block_11
  end
  _t___block_4_select[2]: begin
// __block_12_case
// __block_13
_d_screen_resn = ~_w_cpu_mem_wdata[0+:1];

// __block_14
  end
  default: begin
// __block_15_case
// __block_16
// __block_17
  end
endcase
// __block_5
// __block_18
end else begin
// __block_3
end
// 'after'
// __block_19
// __block_20
// _always_post
// pipeline stage triggers
end

always @(posedge clock) begin
_q_screen_resn <= _d_screen_resn;
_q_leds <= _d_leds;
_q_spiscreen_csn <= _d_spiscreen_csn;
end

endmodule
