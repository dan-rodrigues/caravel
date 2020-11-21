// delay_ff.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

// verilator lint_save
// verilator lint_off DECLFILENAME

module delay_ff #(
    parameter DELAY = 1,
    parameter WIDTH = 1
) (
    input clk,

    input [WIDTH-1:0] in,
    output [WIDTH-1:0] out
);
    delay_ffr #(
        .DELAY(DELAY),
        .WIDTH(WIDTH)
    ) ffr (
        .clk(clk),
        .reset(1'b0),

        .in(in),
        .out(out)
    );

endmodule

// verilator lint_restore
