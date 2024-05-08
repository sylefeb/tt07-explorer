/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

`include "build.v"

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    //input  wire [7:0] uio_in,   // IOs: Input path
    //output wire [7:0] uio_out,  // IOs: Output path
    //output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  M_main main(
    .out_leds(uo_out),
    .in_run(1'b1),
    .reset(~rst_n),
    .clock(clk)
  );

endmodule
