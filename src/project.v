/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

`include "build.v"

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

  // https://tinytapeout.com/specs/pinouts/

  M_main main(

    .out_leds({D5,D4,D3,D2,D1}),
    .out_ram_bank({uio_out[7],uio_out[6]}),

    .out_ram_csn(uio_out[0]),
    .out_ram_clk(uio_out[3]),

    .inout_ram_io0_i(uio_in[1]),
    .inout_ram_io0_o(uio_out[1]),
    .inout_ram_io0_oe(uio_oe[1]),

    .inout_ram_io1_i(uio_in[2]),
    .inout_ram_io1_o(uio_out[2]),
    .inout_ram_io1_oe(uio_oe[2]),

    .inout_ram_io2_i(uio_in[4]),
    .inout_ram_io2_o(uio_out[4]),
    .inout_ram_io2_oe(uio_oe[4]),

    .inout_ram_io3_i(uio_in[5]),
    .inout_ram_io3_o(uio_out[5]),
    .inout_ram_io3_oe(uio_oe[5]),

    .out_spiscreen_clk(uo_out[1]),
    .out_spiscreen_csn(uo_out[2]),
    .out_spiscreen_dc(uo_out[3]),
    .out_spiscreen_mosi(uo_out[4]),
    .out_spiscreen_resn(uo_out[5]),

    .in_uart_rx(ui_in[7]),
    .out_uart_tx(uo_out[0]),

    .in_run(1'b1),
    .reset(~rst_n),
    .clock(clk)
  );

  assign uio_oe[0] = 1;
  assign uio_oe[3] = 1;
  assign uio_oe[6] = 1;
  assign uio_oe[7] = 1;

endmodule
