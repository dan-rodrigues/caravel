`timescale 1 ns / 1 ps

`default_nettype none

`include "caravel.v"
`include "spiflash.v"
`include "tbuart.v"

`include "vdp_lite_mprj_io.vh"

module video_frame_tb;
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
        $dumpvars(0, video_frame_tb);
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
        .FILENAME("video_frame.hex")
    ) spiflash (
        .csb(flash_csb),
        .clk(flash_clk),
        .io0(flash_io0),
        .io1(flash_io1),
        .io2(),         // not used
        .io3()          // not used
    );

    // --- UART ---

    wire uart_tx = mprj_io[6];

    tbuart tbuart (
        .ser_rx(uart_tx)
    );

    // --- VDP testbench support ---

    wire [3:0] r, g, b;
    wire hsync, vsync;
    wire frame_ended, line_ended;
    wire holding_raster;

    wire [`VIDEO_IO_WIDTH - 1:0] video_io = mprj_io[`VIDEO_IO_BASE+:`VIDEO_IO_WIDTH];

    assign b = video_io[3:0];
    assign g = video_io[7:4];
    assign r = video_io[11:8];
    assign hsync = video_io[12];
    assign vsync = video_io[13];
    assign frame_ended = video_io[14];
    assign line_ended = video_io[15];
    assign holding_raster = video_io[16];

    rgbs_logger rgbs_logger(
        .clk(clock),
        .reset(~RSTB),
        .holding_raster(holding_raster),

        .r(r),
        .g(g),
        .b(b),
        .hsync(hsync),
        .vsync(vsync),
        .frame_ended(frame_ended)
    );

    integer current_line = 0;

    always @(posedge clock) begin
        if (line_ended) begin
            current_line <= current_line + 1;

            $display("Line: %d", current_line);
        end

        // Automatically stop after one full frame has been completed

        if (frame_ended) begin
            $display("Frame ended..");
            #2
            $finish;
        end
    end

endmodule

// Video signal logging for later processing
// The included Python script will parse this and output a PNG file of the frame

// It's possible to stop the iverilog run before a frame is fully completed
// In this case, only the completed frame portion is visible

module rgbs_logger #(
    parameter FILENAME = "rgbs.log"
) (
    input clk,
    input reset,
    input holding_raster,

    input [3:0] r, g, b,
    input hsync, vsync,
    input frame_ended
);
    integer file;

    initial begin
        file = $fopen(FILENAME, "wb");

        if (!file) begin
            $display("Couldn't open file: %s", FILENAME);
        end
    end

    integer started_writing = 0;

    always @(posedge clk) begin
        if (!reset && !holding_raster) begin
            $fwrite(file, "%u", {frame_ended, vsync, hsync, {2{r}}, {2{g}}, {2{b}}});

            if (!started_writing) begin
                $display("Started writing RGBS output..");
                started_writing = 1;
            end
        end
    end

endmodule
