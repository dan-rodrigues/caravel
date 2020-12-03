// gamepad_tb.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

`timescale 1 ns / 1 ps

`default_nettype none

`include "caravel.v"
`include "spiflash.v"
`include "tbuart.v"

`include "vdp_lite_mprj_io.vh"

module gamepad_tb;
    // From Caravel example:

    reg clock;
    reg RSTB;
    reg power1, power2;
    reg power3, power4;

    wire gpio;
    wire [37:0] mprj_io;

    // External clock is used by default.  Make this artificially fast for the
    // simulation.  Normally this would be a slow clock and the digital PLL
    // would be the fast clock.

    always #12.5 clock <= (clock === 1'b0);

    initial begin
        clock = 0;
    end

`ifdef WRITE_VCD

    initial begin
        $dumpfile("trace.vcd");
        $dumpvars(0, gamepad_tb);
    end

`endif

    initial begin
        RSTB <= 1'b0;
        #2000;
        RSTB <= 1'b1;       // Release reset
    end

    initial begin       // Power-up sequence
        power1 <= 1'b0;
        power2 <= 1'b0;
        power3 <= 1'b0;
        power4 <= 1'b0;
        #200;
        power1 <= 1'b1;
        #200;
        power2 <= 1'b1;
        #200;
        power3 <= 1'b1;
        #200;
        power4 <= 1'b1;
    end

    wire flash_csb;
    wire flash_clk;
    wire flash_io0;
    wire flash_io1;

    wire VDD1V8;
    wire VDD3V3;
    wire VSS;
    
    assign VDD3V3 = power1;
    assign VDD1V8 = power2;
    assign USER_VDD3V3 = power3;
    assign USER_VDD1V8 = power4;
    assign VSS = 1'b0;

    caravel uut (
        .vddio    (VDD3V3),
        .vssio    (VSS),
        .vdda     (VDD3V3),
        .vssa     (VSS),
        .vccd     (VDD1V8),
        .vssd     (VSS),
        .vdda1    (USER_VDD3V3),
        .vdda2    (USER_VDD3V3),
        .vssa1    (VSS),
        .vssa2    (VSS),
        .vccd1    (USER_VDD1V8),
        .vccd2    (USER_VDD1V8),
        .vssd1    (VSS),
        .vssd2    (VSS),
        .clock    (clock),
        .gpio     (gpio),
        .mprj_io  (mprj_io),
        .flash_csb(flash_csb),
        .flash_clk(flash_clk),
        .flash_io0(flash_io0),
        .flash_io1(flash_io1),
        .resetb   (RSTB)
    );

    spiflash #(
        .FILENAME("gamepad.hex")
    ) spiflash (
        .csb(flash_csb),
        .clk(flash_clk),
        .io0(flash_io0),
        .io1(flash_io1),
        .io2(),         // not used
        .io3()          // not used
    );

    // New additions:

    // --- UART ---

    wire uart_tx = mprj_io[6];

    tbuart tbuart (
        .ser_rx(uart_tx)
    );

    // --- Gamepad testbench support ---

    localparam [11:0] P1_DATA = 12'h5a5;
    localparam [11:0] P2_DATA = 12'hc2c;

    reg [11:0] gamepad_shift [0:1];

    wire [`GAMEPAD_OUTPUT_WIDTH - 1:0] gamepad_io = mprj_io[`GAMEPAD_OUTPUT_BASE+:`GAMEPAD_OUTPUT_WIDTH];
    wire gamepad_latch = gamepad_io[0];
    wire gamepad_clk = gamepad_io[1];

    wire gamepad_p1_in = gamepad_shift[0][0];
    wire gamepad_p2_in = gamepad_shift[1][0];

    assign mprj_io[`GAMEPAD_INPUT_BASE+:`GAMEPAD_INPUT_WIDTH] = {gamepad_p2_in, gamepad_p1_in};

    wire [`LED_IO_WIDTH - 1:0] led = mprj_io[`LED_IO_BASE+:`LED_IO_WIDTH];

    initial begin
        @(posedge gamepad_latch);
        gamepad_shift[0] = P1_DATA;
        gamepad_shift[1] = P2_DATA;
        $display("GP: latched..");

        repeat (12) begin
            @(posedge gamepad_clk) begin
                gamepad_shift[0] <= gamepad_shift[0] >> 1;
                gamepad_shift[1] <= gamepad_shift[1] >> 1;
                $strobe("GP: shift register clocked, P1 = %x, P2 = %x", gamepad_shift[0], gamepad_shift[1]);
            end
        end
        $display("Finished complete gamepad read..");

        // Wait for CPU to output matching pad state

        wait(led == ((P1_DATA >> 0) & 4'hf));
        wait(led == ((P1_DATA >> 4) & 4'hf));
        wait(led == ((P1_DATA >> 8) & 4'hf));
        $display("P1 data matches..");

        wait(led == ((P2_DATA >> 0) & 4'hf));
        wait(led == ((P2_DATA >> 4) & 4'hf));
        wait(led == ((P2_DATA >> 8) & 4'hf));
        $display("P2 data matches..");

        $display("Gamepads successfully read / written");
        $stop;
    end

    initial begin
        repeat (10000000) @(posedge clock);
        $display("Timed out");
        $stop;
    end

endmodule
