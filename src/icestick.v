/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

`include "build.v"

/*
module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  wire D5,D4,D3,D2,D1; // ignored

  wire [3:0] main_uio_oe;

  // https://tinytapeout.com/specs/pinouts/

  M_main main(

    .out_leds({D5,D4,D3,D2,D1}),
    .out_ram_bank({uio_out[7],uio_out[6]}),

    //// !!TODO!! recheck pmod wiring for machdyne pmod?

    .out_ram_csn(uio_out[0]),
    .out_ram_clk(uio_out[3]),

    .inout_ram_io0_i(uio_in[1]),
    .inout_ram_io0_o(uio_out[1]),
    .inout_ram_io0_oe(main_uio_oe[0]),

    .inout_ram_io1_i(uio_in[2]),
    .inout_ram_io1_o(uio_out[2]),
    .inout_ram_io1_oe(main_uio_oe[1]),

    .inout_ram_io2_i(uio_in[4]),
    .inout_ram_io2_o(uio_out[4]),
    .inout_ram_io2_oe(main_uio_oe[2]),

    .inout_ram_io3_i(uio_in[5]),
    .inout_ram_io3_o(uio_out[5]),
    .inout_ram_io3_oe(main_uio_oe[3]),

    .out_spiscreen_clk(uo_out[1]),
    .out_spiscreen_csn(uo_out[2]),
    .out_spiscreen_dc(uo_out[3]),
    .out_spiscreen_mosi(uo_out[4]),
    .out_spiscreen_resn(uo_out[5]),

    //.in_uart_rx(ui_in[7]),
    //.out_uart_tx(uo_out[0]),

    .in_run(1'b1),
    .reset(~rst_n),
    .clock(clk)
  );

  //              vvvvv inputs when in reset to allow PMOD external takeover
  assign uio_oe = rst_n ? {1'b1,1'b1,main_uio_oe[3],main_uio_oe[2],1'b1,main_uio_oe[1],main_uio_oe[0],1'b1} : 8'h00;

  assign uo_out[0] = 0;
  assign uo_out[6] = 0;
  assign uo_out[7] = 0;

endmodule
*/

module top(
  output D1,
  output D2,
  output D3,
  output D4,
  output D5,
  output PMOD1,
  output PMOD10,
  inout  PMOD2,
  inout  PMOD3,
  output PMOD4,
  inout  PMOD7,
  inout  PMOD8,
  output PMOD9,
  output TR3,
  output TR4,
  output TR5,
  output TR6,
  output TR7,
  input  CLK
  );

reg ready = 0;
reg [23:0] RST_d;
reg [23:0] RST_q;

always @* begin
  RST_d = RST_q[23] ? RST_q : RST_q + 1;
end

always @(posedge CLK) begin
  if (ready) begin
    RST_q <= RST_d;
  end else begin
    ready <= 1;
    RST_q <= 0;
  end
end

wire run_main;
assign run_main = 1'b1;

wire uio_out0,uio_oe0;
wire uio_out1,uio_oe1;
wire uio_out2,uio_oe2;
wire uio_out3,uio_oe3;

assign PMOD2 = uio_oe0 ? uio_out0 : 1'bz;
assign PMOD3 = uio_oe1 ? uio_out1 : 1'bz;
assign PMOD7 = uio_oe2 ? uio_out2 : 1'bz;
assign PMOD8 = uio_oe3 ? uio_out3 : 1'bz;

M_main __main(
  .clock(CLK),
  .reset(~RST_q[23]),
  .out_leds({D5,D4,D3,D2,D1}),
  .out_ram_bank({PMOD10,PMOD9}),
  .out_ram_clk({PMOD4}),
  .out_ram_csn({PMOD1}),

  .inout_ram_io0_i(PMOD2),
  .inout_ram_io0_o(uio_out0),
  .inout_ram_io0_oe(uio_oe0),

  .inout_ram_io1_i(PMOD3),
  .inout_ram_io1_o(uio_out1),
  .inout_ram_io1_oe(uio_oe1),

  .inout_ram_io2_i(PMOD7),
  .inout_ram_io2_o(uio_out2),
  .inout_ram_io2_oe(uio_oe2),

  .inout_ram_io3_i(PMOD8),
  .inout_ram_io3_o(uio_out3),
  .inout_ram_io3_oe(uio_oe3),
  
  //.inout_ram_io0({PMOD2}),
  //.inout_ram_io1({PMOD3}),
  //.inout_ram_io2({PMOD7}),
  //.inout_ram_io3({PMOD8}),
  
  .out_spiscreen_clk({TR4}),
  .out_spiscreen_csn({TR5}),
  .out_spiscreen_dc({TR6}),
  .out_spiscreen_mosi({TR3}),
  .out_spiscreen_resn({TR7}),
  .in_run(run_main)
);

endmodule
