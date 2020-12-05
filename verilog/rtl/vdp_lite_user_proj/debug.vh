// debug.vh
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

`undef debug
`undef stop

`ifndef SYNTHESIS
	`define debug(debug_command) debug_command
	`define stop(debug_command) debug_command; $stop;
`else
	`define debug(debug_command)
	`define stop(debug_command)
`endif
