/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

`include "build.v"

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    // inout  wire [7:0] uio,
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)    
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  wire D5,D4,D3,D2,D1; // ignored
  wire PMOD10,PMOD9; // ignored
  
  wire TODO0,TODO1,TODO2,TODO3;

  M_main main(
  
    .out_leds({D5,D4,D3,D2,D1}),
    .out_ram_bank({PMOD10,PMOD9}), // use uio?
    
    .out_ram_clk(uo_out[0]),
    .out_ram_csn(uo_out[1]),
    .inout_ram_io0(TODO0),
    .inout_ram_io1(TODO1),
    .inout_ram_io2(TODO2),
    .inout_ram_io3(TODO3),
    .out_spiscreen_clk(uo_out[2]),
    .out_spiscreen_csn(uo_out[3]),
    .out_spiscreen_dc(uo_out[4]),
    .out_spiscreen_mosi(uo_out[5]),
    .out_spiscreen_resn(uo_out[6]),
    .in_uart_rx(ui_in[0]),
    .out_uart_tx(uo_out[7]),  

    .in_run(1'b1),
    .reset(~rst_n),
    .clock(clk)
  );

  assign uio_out = 0;
  assign uio_oe  = 0;

endmodule
