// Replacement of user_proj_example.v

`default_nettype none

`include "vdp_lite_mprj_io.vh"

module vdp_lite_user_proj #(
    parameter [0:0] ENABLE_VRAM = 1
) (
    inout vdda1,	// User area 1 3.3V supply
    inout vdda2,	// User area 2 3.3V supply
    inout vssa1,	// User area 1 analog ground
    inout vssa2,	// User area 2 analog ground
    inout vccd1,	// User area 1 1.8V supply
    inout vccd2,	// User area 2 1.8v supply
    inout vssd1,	// User area 1 digital ground
    inout vssd2,	// User area 2 digital ground

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oen,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb
);
    wire clk = wb_clk_i;
    wire reset = wb_rst_i;

    // LA unused (for now)
    assign la_data_out = {128{1'b0}};

    reg [31:0] rdata; 
    wire [31:0] wdata;

    wire valid;
    wire [3:0] wstrb;
    wire [31:0] la_write;

    // WB MI A
    assign valid = wbs_cyc_i && wbs_stb_i; 
    assign wstrb = wbs_sel_i & {4{wbs_we_i}};
    assign wbs_dat_o = rdata;
    assign wdata = wbs_dat_i;

    reg ready;
    assign wbs_ack_o = ready;

    // Video IO

    // Mind the use of clk here which is an optional extra
    // Not sure if this will be reliable or if there will be setup/hold violations etc. given lack of IO regs(?)
    //
    // If it is not reliable, this could be used with the other video outputss over VGA
    // If it is reliable, it could be used with both VGA and a VGA-to-DVI converter
    
	// Timing issues when attempting to output clk?
    // wire [`VIDEO_IO_WIDTH - 1:0] video_io = {clk, hold_raster, line_ended, frame_ended, vsync, hsync, r, g, b};
    wire [`VIDEO_IO_WIDTH - 1:0] video_io = {1'b0, hold_raster, line_ended, frame_ended, vsync, hsync, r, g, b};

    assign io_out[`VIDEO_IO_BASE+:`VIDEO_IO_WIDTH] = video_io;

    // Gamepad IO

    reg gamepad_clk;
    reg gamepad_latch;

    wire [`GAMEPAD_OUTPUT_WIDTH - 1:0] gamepad_out = {gamepad_clk, gamepad_latch};

    wire [`GAMEPAD_INPUT_WIDTH - 1:0] gamepad_in = io_in[`GAMEPAD_INPUT_BASE+:`GAMEPAD_INPUT_WIDTH];
    assign io_out[`GAMEPAD_INPUT_BASE+:`GAMEPAD_INPUT_WIDTH] = 2'b11;

    wire gamepad_p1_data = gamepad_in[0];
    wire gamepad_p2_data = gamepad_in[1];

    assign io_out[`GAMEPAD_OUTPUT_BASE+:`GAMEPAD_OUTPUT_WIDTH] = gamepad_out;

    // LED IO

    reg [`LED_IO_WIDTH - 1:0] led;

    assign io_out[`LED_IO_BASE+:`LED_IO_WIDTH] = led;

    // Remaining unused IO (all IO are used but this can be restored if needed)

    // localparam UNALLOCATED_IO_WIDTH = `MPRJ_IO_PADS - `UNALLOCATED_IO_BASE;
    // assign io_out[`UNALLOCATED_IO_BASE+:UNALLOCATED_IO_WIDTH] = {UNALLOCATED_IO_WIDTH{1'b0}};

    // OE control

    reg [`MPRJ_IO_PADS - 1:0] io_oe;
    assign io_oeb = ~io_oe;

    always @* begin
        // Always default to disabled outputs
        io_oe = {`MPRJ_IO_PADS{1'b0}};

        if (reset) begin
            io_oe = {`MPRJ_IO_PADS{1'b0}};
        end else begin
            io_oe = {
                {`LED_IO_WIDTH{1'b1}},
                {`GAMEPAD_INPUT_WIDTH{1'b0}},
                {`GAMEPAD_OUTPUT_WIDTH{1'b1}},
                {`VIDEO_IO_WIDTH{1'b1}},
                // Bottom 12 io are used by Caravel
                {`MGMT_RESERVED_WIDTH{1'b0}}
            };
        end
    end

    // --- WB address decoding ---

    reg vdp_active;
    reg hold_raster;

    reg vdp_en, vdp_write_en;
    reg pad_en, pad_write_en;
    reg ctrl_en;
    reg led_en, led_write_en;

    always @* begin
        vdp_en = 0; vdp_write_en = 0;
        pad_en = 0; pad_write_en = 0;
        ctrl_en = 0;
        led_en = 0; led_write_en = 0;

        if (valid) begin
            case (wbs_adr_i[31:16])
                16'h3000: ctrl_en = 1'b1;
                16'h3010: vdp_en = 1'b1;
                16'h3020: pad_en = 1'b1;
                16'h3030: led_en = 1'b1;
            endcase
        end

        vdp_write_en = vdp_en && |wstrb;
        pad_write_en = pad_en && |wstrb;
        led_write_en = led_en && |wstrb;
    end

    // --- WB adapter ---

    // Writing:

    always @(posedge clk) begin
        if (reset) begin
            vdp_active <= 1'b0;
            hold_raster <= 1'b1;
            gamepad_clk <= 1'b0;
            gamepad_latch <= 1'b0;
            led <= {`LED_IO_WIDTH{1'b0}};
        end else begin
            if (ctrl_en) begin
                vdp_active <= wdata[0];
                hold_raster <=  wdata[1];
            end else if (vdp_write_en) begin
                // (nothing, VDP handles it)
            end else if (pad_write_en) begin
                gamepad_clk <= wdata[1];
                gamepad_latch <= wdata[0];
            end else if (led_write_en) begin
                led <= wdata[`LED_IO_WIDTH - 1:0];
            end
        end
    end

    // Reading:

    always @(posedge clk) begin
        if (reset) begin
            rdata <= 32'b0;
        end else if (vdp_en) begin
            rdata <= {2{vdp_read_data}};
        end else if (pad_en) begin
            rdata <= {{30{1'b0}}, {gamepad_p2_data, gamepad_p1_data}};
        end
    end

    // ACK asserting:

    always @(posedge clk) begin
        if (reset) begin
            ready <= 1'b0;
        end else begin
            ready <= 1'b0;

            if (valid && !ready) begin
                if (vdp_en) begin
                    ready <= vdp_ready;
                end else if (ctrl_en || pad_en || led_write_en) begin
                    ready <= 1'b1;
                end else begin
`ifndef SYNTHESIS
                    $display("ERROR: WB transaction has no handler",);
                    $stop;
`endif
                end
            end
        end
    end

    // --- ROM / RAM for tiles ---

    wire ram_selected = vram_address[10];
    wire [15:0] vram_read_data_selected = ram_selected ? vram_read_data : vrom_read_data;

    // ROM:

    wire [15:0] vrom_read_data;

    char_rom #(
        .FILENAME("reduce.hex")
    ) char_rom (
        .clk(clk),

        .address(vram_address[9:0]),
        .read_data(vrom_read_data)
    );

    // RAM:

    wire [15:0] vram_read_data;

    generate
        if (ENABLE_VRAM) begin
            wire [31:0] vram_write_data = {2{vram_write_data_collapsed}};
            wire [3:0] vram_we = {2{vram_we_odd, vram_we_even}} & {{2{vram_address[0]}}, {2{~vram_address[0]}}};

            wire [31:0] vram_read_data_32;
            wire [15:0] vram_read_data =  vram_address[0] ? vram_read_data_32[31:16] : vram_read_data_32[15:0];

            // 1KByte DFFRAM:

            DFFRAM vram_dff (
`ifdef USE_POWER_PINS
                .VPWR(vccd1),
                .VGND(vssd1),
`endif
                .CLK(clk),
                .WE(vram_we),
                .EN(1'b1),
                .Di(vram_write_data),
                .Do(vram_read_data_32),
                .A(vram_address[7:0])
            );
        end else begin
            assign vram_read_data = 16'b0;
        end
    endgenerate

    // --- VDP lite ---

    wire [31:0] vram_read_expanded = vram_expanded(vram_read_data_selected);
    wire [15:0] vram_write_data_collapsed = vram_collapsed({vram_write_data_odd, vram_write_data_even});
    assign {vram_read_data_odd, vram_read_data_even} = vram_read_expanded;

    wire [13:0] vram_address;
    wire [15:0] vram_read_data_odd, vram_read_data_even;
    wire vram_we_odd, vram_we_even;
    wire [15:0] vram_write_data_odd, vram_write_data_even;

    wire [3:0] r, g, b;
    wire hsync, vsync;
    wire frame_ended, line_ended;

    wire vdp_reset = !vdp_active || reset;

    // CPU control:

    wire [15:0] vdp_write_address = {wbs_adr_i[15:2], wstrb[2]};

    wire vdp_read_en = vdp_en && !vdp_write_en;

    wire [15:0] vdp_read_data;
    wire vdp_ready;

    vdp #(
`ifdef INIT_VIDEO_RAMS
        .INIT_PALETTE_RAM(`INIT_PALETTE_RAM),
        .INIT_X_BLOCK(`INIT_SPRITE_X),
        .INIT_Y_BLOCK(`INIT_SPRITE_Y),
        .INIT_G_BLOCK(`INIT_SPRITE_G)
`endif
    ) vdp (
        .clk(clk),
        .reset(vdp_reset),
        .hold_raster(hold_raster),

        .host_address(vdp_write_address),
        .host_read_en(vdp_read_en),
        .host_write_en(vdp_write_en),
        .host_read_data(vdp_read_data),
        .host_ready(vdp_ready),
        .host_write_data(wdata[15:0]),

        .r(r),
        .g(g),
        .b(b),
        .vga_hsync(hsync),
        .vga_vsync(vsync),

        .frame_ended(frame_ended),
        .line_ended(line_ended),

        .vram_address(vram_address),
        .vram_read_data_even(vram_read_data_even),
        .vram_read_data_odd(vram_read_data_odd),

        .vram_write_data_even(vram_write_data_even),
        .vram_write_data_odd(vram_write_data_odd),
        .vram_we_even(vram_we_even),
        .vram_we_odd(vram_we_odd)
    );

    function [15:0] vram_collapsed;
        input [31:0] in;

        vram_collapsed = {
            in[29:28], in[25:24], in[21:20], in[17:16],
            in[13:12], in[9:8], in[5:4], in[1:0]
        };
    endfunction

    function [31:0] vram_expanded;
        input [15:0] in;

        vram_expanded = {
            2'b00, in[15:14], 2'b00, in[13:12],
            2'b00, in[11:10], 2'b00, in[9:8],
            2'b00, in[7:6], 2'b00, in[5:4],
            2'b00, in[3:2], 2'b00, in[1:0]
        };
    endfunction

    // --- Simulator-only logging ---

`ifndef SYNTHESIS

    wire vdp_hi_word = wstrb[2];

    always @(reset)
        $display("WB reset: %d", reset);

    always @(vdp_reset)
        $display("VDP Reset: %d", vdp_reset);

    reg ready_r = 0;

    always @(posedge clk) begin
        if (ready && !ready_r) begin
            if (vdp_write_en) begin
                $display("VDP write @ %x + %d = %x", wbs_adr_i, vdp_hi_word, wdata);
            end else if (ctrl_en) begin
                $display("CTRL write @ %x = %x", wbs_adr_i, wdata);
            end else if (vdp_en) begin
                $display("VDP read @ %x, read %x", wbs_adr_i, rdata);
            end else if (pad_en && !pad_write_en) begin
                $display("GP read @ %x, read %x", wbs_adr_i, rdata);
            end else if (pad_write_en) begin
                $display("GP write @ %x = %x", wbs_adr_i, wdata);
            end else if (led_write_en) begin
                $display("LED write @ %x = %x", wbs_adr_i, wdata);
            end else begin
                $display("ERROR: Wishbone ready asserted but no peripheral was enabled");
                $stop;
            end
        end

        ready_r <= ready;
    end

`endif

endmodule
