// vdp_lite_mprj_io.vh
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

`ifndef vdp_lite_mprj_io_vh
`define vdp_lite_mprj_io_vh

`define MGMT_RESERVED_WIDTH 12

`define VIDEO_IO_BASE 12
`define VIDEO_IO_WIDTH 18

`define GAMEPAD_IO_BASE (12 + 18)
`define GAMEPAD_IO_WIDTH 4

`define GAMEPAD_OUTPUT_BASE (12 + 18 + 0)
`define GAMEPAD_OUTPUT_WIDTH 2

`define GAMEPAD_INPUT_BASE (12 + 18 + 2)
`define GAMEPAD_INPUT_WIDTH 2

`define LED_IO_BASE (12 + 18 + 2 + 2)
`define LED_IO_WIDTH 4

`endif
