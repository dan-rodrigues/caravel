// vdp.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

`include "layer_encoding.vh"

module vdp #(
    parameter INIT_PALETTE_RAM = "",
    parameter INIT_X_BLOCK = "",
    parameter INIT_Y_BLOCK = "",
    parameter INIT_G_BLOCK = "",

    parameter integer CLIP_LEFT = 64,
    parameter integer CLIP_RIGHT = 64,

    parameter [0:0] ENABLE_WIDESCREEN = 0,
    parameter [1:0] LAYERS_TOTAL = 3
) (
    input clk,
    input reset,

    // Host interface

    input [15:0] host_address,
    
    input [15:0] host_write_data,
    input host_write_en,

    input host_read_en,
    output reg [15:0] host_read_data,
    output host_ready,

    // VGA output

    output reg [3:0] r,
    output reg [3:0] g,
    output reg [3:0] b,

    output vga_hsync,
    output vga_vsync,

    output active_display,

    input hold_raster,

    // Single-cycle strobes, NOT suitable for VGA

    output line_ended,
    output frame_ended,
    output active_frame_ended,
    
    // VRAM interface

    output [13:0] vram_address,

    output vram_we_even,
    input [15:0] vram_read_data_even,
    output [15:0] vram_write_data_even,

    output vram_we_odd,
    input [15:0] vram_read_data_odd,    
    output [15:0] vram_write_data_odd,

    // Copper RAM interface

    output cop_ram_read_en,
    output [10:0] cop_ram_read_address,
    input [15:0] cop_ram_read_data
);
    // --- Video timing ---

    // 848x480@60hz

    localparam H_ACTIVE_WIDTH_848 = 848;
    localparam H_SYNC_848 = 112;
    localparam H_BACKPORCH_848 = 112;

    localparam V_FRONTPORCH_848 = 6;
    localparam V_SYNC_848 = 8;
    localparam V_BACKPORCH_848 = 23;

    // 640x480@60hz

    localparam H_ACTIVE_WIDTH_640 = 640;
    localparam H_SYNC_640 = 96;
    localparam H_BACKPORCH_640 = 48;

    localparam V_FRONTPORCH_640 = 11;
    localparam V_SYNC_640 = 2;
    localparam V_BACKPORCH_640 = 31;

    // common between both modes
    
    localparam V_ACTIVE_HEIGHT = 480;
    localparam H_FRONTPORCH = 16;

    // select one of the above video modes according to parameter

    localparam H_ACTIVE_WIDTH = ENABLE_WIDESCREEN ? H_ACTIVE_WIDTH_848 : H_ACTIVE_WIDTH_640;
    localparam H_SYNC = ENABLE_WIDESCREEN ? H_SYNC_848 : H_SYNC_640;
    localparam H_BACKPORCH = ENABLE_WIDESCREEN ? H_BACKPORCH_848 : H_BACKPORCH_640;

    localparam V_FRONTPORCH = ENABLE_WIDESCREEN ? V_FRONTPORCH_848 : V_FRONTPORCH_640;
    localparam V_SYNC = ENABLE_WIDESCREEN ? V_SYNC_848 : V_SYNC_640;
    localparam V_BACKPORCH = ENABLE_WIDESCREEN ? V_BACKPORCH_848 : V_BACKPORCH_640;

    // for use by other blocks below

    localparam OFFSCREEN_X_TOTAL = H_SYNC + H_FRONTPORCH + H_BACKPORCH;
    localparam HEIGHT_TOTAL = V_ACTIVE_HEIGHT + V_FRONTPORCH + V_SYNC + V_BACKPORCH;

    wire [10:0] raster_x;
    wire [9:0] raster_y;

    // verilator lint_off PINMISSING

    vdp_vga_timing #(
        .H_ACTIVE_WIDTH(H_ACTIVE_WIDTH),
        .V_ACTIVE_HEIGHT(V_ACTIVE_HEIGHT),
        .H_FRONTPORCH(H_FRONTPORCH),
        .H_SYNC(H_SYNC),
        .H_BACKPORCH(H_BACKPORCH),
        .V_FRONTPORCH(V_FRONTPORCH),
        .V_SYNC(V_SYNC),
        .V_BACKPORCH(V_BACKPORCH)
    ) vga_timing (
        .clk(clk),
        .reset(reset),
        .hold_raster(hold_raster),

        .raster_x(raster_x),
        .raster_y(raster_y),

        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .active_display(active_display),
        .active_frame_ended(active_frame_ended),

        .line_ended(line_ended),
        .frame_ended(frame_ended)
    );

    // verilator lint_on PINMISSING

    // --- Host interface ---

    wire [4:0] register_write_address, register_read_address;
    wire [15:0] register_write_data;
    wire register_write_en;

    vdp_host_interface host_interface(
        .clk(clk),
        .reset(reset),

        .host_read_en(host_read_en),
        .ready(host_ready),
        .vram_write_pending(vram_write_pending),

        .host_write_en(host_write_en),
        .register_write_en(register_write_en),

        .cop_write_address(5'b0),
        .cop_write_data(16'b0),
        .cop_write_en(1'b0),

        .host_address(host_address[5:0]),
        .host_write_data(host_write_data),
        .register_write_data(register_write_data),
        .register_write_address(register_write_address),
        .read_address(register_read_address)
    );

    // --- Copper ---
    // (vdp_lite doesn't have the copper coprocessor)

    // --- Register writes ---

    reg [5:0] layer_enable = 0;
    reg [4:0] layer_enable_alpha_over = 0;

    wire affine_enabled = 0;

    reg [15:0] scroll_tile_base;
    reg [15:0] scroll_map_base;

    reg [15:0] scroll_x [0:3];
    reg [15:0] scroll_y [0:3];

    reg [3:0] scroll_use_wide_map;

    reg [3:0] sprite_tile_base;
    wire [13:0] full_sprite_tile_base = {sprite_tile_base, 10'b0};

    reg [15:0] vram_write_data_16b;
    reg [1:0] vram_port_write_en_mask;
    reg [14:0] vram_write_address_full;
    wire [13:0] vram_write_address_16b = vram_write_address_full[14:1];
    reg [7:0] vram_port_address_increment;
    reg vram_write_pending;
    
    // --- Writes: comb. ---

    always @* begin
        palette_write_en = 0;

        // This block has the same structure as the below one, for consistency
        // Looks odd while only one case is handled for the time being

        if (register_write_en) begin
            if (!register_write_address[4]) begin
                case (register_write_address[3:0])
                    3: begin
                        palette_write_en = 1;
                    end
                endcase
            end
        end
    end

    // --- Writes: clocked ---

    always @(posedge clk) begin
        if (reset) begin
            layer_enable <= `LAYER_SPRITES_OHE;
            layer_enable_alpha_over <= 0;
            sprite_tile_base <= 0;
            vram_write_pending <= 0;
        end

        sprite_metadata_write_en <= 0;
        sprite_metadata_block_select <= sprite_metadata_block_select_nx;

        if (sprite_metadata_write_en && sprite_meta_address_needs_increment) begin
            sprite_metadata_address <= sprite_metadata_address + 1;
        end

        if (palette_write_en) begin
            palette_write_address <= palette_write_address + 1;
        end

        if (vram_write_pending && vram_written) begin
            vram_write_pending <= 0;
            vram_write_address_full <= vram_write_address_full + vram_port_address_increment;
            vram_port_write_en_mask <= 2'b00;
        end

        if (register_write_en) begin
            if (!register_write_address[4]) begin
                case (register_write_address[3:0])
                    0: begin
                        sprite_metadata_address <= register_write_data[7:0];
                        sprite_metadata_block_select <= 3'b001;
                    end
                    1: begin
                        // (sprite_metadata_write_data driven directly by register_write_data below)
                        sprite_metadata_write_en <= 1;
                    end
                    2: begin
                        palette_write_address <= register_write_data[1:0];
                    end
                    3: begin
                        // (palette write, which is handed separately above)
                    end
                    4: begin
                        vram_write_address_full <= register_write_data;
                        vram_port_write_en_mask <= 2'b00;
                    end
                    5: begin
                        vram_write_data_16b <= register_write_data;
                        vram_port_write_en_mask <= vram_write_address_full[0] ? 2'b10 : 2'b01;

                        vram_write_pending <= 1;
                    end
                    6: begin
                        vram_port_address_increment <= register_write_data[7:0];
                    end
                    7: begin
                        sprite_tile_base <= register_write_data[13:10];
                    end
                    8: begin
                        // cop_enable <= register_write_data[0];
                    end
                    9: begin
                        scroll_tile_base <= register_write_data;
                    end
                    10: begin
                        scroll_map_base <= register_write_data;
                    end
                    11: begin
                        layer_enable <= register_write_data[5:0];
                    end
                    12: begin
                        layer_enable_alpha_over <= register_write_data[7:0];
                    end
                    13: begin
                        scroll_use_wide_map <= register_write_data[3:0];
                    end
                    default: begin
`ifndef SYNTHESIS
                    $display("unimplemented register: %x", register_write_address);
                    $stop;
`endif
                    end
                endcase
            end else if (register_write_address[4]) begin
                case (register_write_address[3:2])
                    0: scroll_x[register_write_address[1:0]] <= register_write_data;
                    1: scroll_y[register_write_address[1:0]] <= register_write_data;
                endcase
            end
        end
    end

    // --- Register reads ---

    always @(posedge clk) begin
        case (register_read_address[1])
            0: host_read_data <= raster_x;
            1: host_read_data <= raster_y;
        endcase
    end

    // --- Sprite metadata writing ---
    
    reg [7:0] sprite_metadata_address;
    reg [2:0] sprite_metadata_block_select;
    wire [15:0] sprite_metadata_write_data = register_write_data;
    reg sprite_metadata_write_en;

    reg [2:0] sprite_metadata_block_select_nx;
    wire sprite_meta_address_needs_increment = sprite_metadata_block_select[2];

    always @* begin
        sprite_metadata_block_select_nx = sprite_metadata_block_select;

        if (sprite_metadata_write_en) begin
            sprite_metadata_block_select_nx = {sprite_metadata_block_select[1:0], sprite_metadata_block_select[2]};
        end
    end

    // --- Affine layer register mapping ---
    // (affine disabled in vdp_lite)

    // --- Palette RAM ---

    reg [1:0] palette_write_address;
    wire [11:0] pal_write_data = register_write_data;
    reg palette_write_en;

    wire [11:0] palette_output;

    wire [7:0] palette_masked_read_address = prioritized_masked_pixel;
    reg [15:0] palette_masked_output;

    wire [1:0] palette_read_address = prioritized_pixel[1:0];

    // Only 4 colors (1 transparent)
    // Original is 256 colors (16 palettes of 16 each)
    // Single palette only

    ffram #(
        .INIT_FILE(INIT_PALETTE_RAM),
        .DATA_WIDTH(12),
        .ADDR_WIDTH(2)
    ) palette_ram (
        .clk(clk),
        .wdata0(pal_write_data),
        .addr0(palette_write_address),
        .we0(palette_write_en),

        .addr1(palette_read_address),
        .rdata1(palette_output)
    );

    // --- Blender and RGB output ---

    // (blender disabled in vdp_lite so original color is always used)

    wire clipping_left = raster_x < (OFFSCREEN_X_TOTAL + CLIP_LEFT);
    wire clipping_right = raster_x >= (OFFSCREEN_X_TOTAL + H_ACTIVE_WIDTH - CLIP_RIGHT);
    wire clipping_rgb = clipping_left || clipping_right;

    wire [11:0] output_color = (active_display && !clipping_rgb ? palette_output : 12'b0);

    always @(posedge clk) begin
        r <= output_color[11:8];
        g <= output_color[7:4];
        b <= output_color[3:0];
    end

    // --- Raster offset for scrolling layers ---

    localparam SCROLL_START_LEAD_TIME = 32;
    localparam SCROLL_OFFSCREEN_ADVANCE = -7;

    reg [10:0] raster_x_offset;

    localparam HEIGHT_DIFF = HEIGHT_TOTAL - 512;

    wire scroll_base_x_start = raster_x == (OFFSCREEN_X_TOTAL - SCROLL_START_LEAD_TIME);

    // the +1 is to preserve alignment between raster_x[2:0] (used to sequence VRAM access)
    localparam SCROLL_BASE_X_INITIAL = SCROLL_OFFSCREEN_ADVANCE + 1;

    always @(posedge clk) begin
        raster_x_offset <= scroll_base_x_start ? SCROLL_BASE_X_INITIAL : raster_x_offset + 1;
    end

    // --- Raster offset for sprites ---

    reg [9:0] sprites_x;
    reg [8:0] sprites_y;
    
    localparam SPRITE_X_INITIAL = -1;
    localparam SPRITE_START_LEAD_TIME = 6;
    localparam SPRITE_HOLD_TIME = HEIGHT_TOTAL - 512;

    // alternatively instead of comparing all bits in raster_x, just check for all 1-bits
    // since it counts up and resets to 0 predictably
    wire sprites_x_start = (raster_x == (OFFSCREEN_X_TOTAL - SPRITE_START_LEAD_TIME + CLIP_LEFT));
    wire sprites_x_reset = line_ended;
    reg sprites_x_counting;

    always @(posedge clk) begin
        // used for line buffer read address for display
        if (reset || sprites_x_reset) begin
            sprites_x_counting <= 0;
        end else if (sprites_x_start) begin
            sprites_x_counting <= 1;
        end

        sprites_x <= (sprites_x_counting ? sprites_x + 1 : SPRITE_X_INITIAL);
    end

    localparam SPRITE_MAX_HEIGHT = 16;
    localparam SPRITE_Y_DELAY = 2;

    always @(posedge clk) begin
        if (reset) begin
            sprites_y <= 0;
        end else if (line_ended) begin
            if (raster_y == (HEIGHT_TOTAL - SPRITE_MAX_HEIGHT - SPRITE_Y_DELAY)) begin
                sprites_y <= 512 - SPRITE_MAX_HEIGHT;
            end else begin
                sprites_y <= sprites_y + 1;
            end
        end
    end

    // --- Shared pixel row reverser ---

    // Sprites and scroll layers can optionally have their graphics data flipped horizontally.
    // Since only 1 of these can be read at a time, this reversing logic can be shared between all.

    wire map_pixel_row_needs_x_flip = |(scroll_x_flip & scroll_char_load);
    wire sprite_pixel_row_needs_x_flip = vram_sprite_read_data_needs_x_flip && vram_sprite_read_data_valid;
    wire should_reverse_pixel_row = map_pixel_row_needs_x_flip || sprite_pixel_row_needs_x_flip;

    reg [31:0] pixel_row_ordered;

    always @* begin
        if (should_reverse_pixel_row) begin
            pixel_row_ordered[31:28] = vram_read_data_r[3:0];
            pixel_row_ordered[27:24] = vram_read_data_r[7:4];
            pixel_row_ordered[23:20] = vram_read_data_r[11:8];
            pixel_row_ordered[19:16] = vram_read_data_r[15:12];

            pixel_row_ordered[15:12] = vram_read_data_r[19:16];
            pixel_row_ordered[11:8] = vram_read_data_r[23:20];
            pixel_row_ordered[7:4] = vram_read_data_r[27:24];
            pixel_row_ordered[3:0] = vram_read_data_r[31:28];
        end else begin
            pixel_row_ordered = vram_read_data_r;
        end
    end

    // --- Scroll pixel generators ---
    // (no scrolling layers in vdp_lite)

    // --- Priority control --- 

    localparam [4:0] LAYER_ENABLE_MASK = (1 << (LAYERS_TOTAL)) - 1 | `LAYER_SPRITES_OHE;

    wire [7:0] prioritized_pixel;
    wire [4:0] prioritized_masked_layer;
    wire [7:0] prioritized_masked_pixel;

    // verilator lint_off UNUSED
    wire [4:0] prioritized_layer;
    // verilator lint_on UNUSED

    wire [4:0] layer_mask = ~layer_enable_alpha_over;

    vdp_priority_compute priority_compute(
        .clk(clk),

        .scroll0_pixel(8'b0),
        .scroll0_is_8bpp(1'b0),

        .scroll1_pixel(8'b0),
        .scroll2_pixel(8'b0),
        .scroll3_pixel(8'b0),

        .sprite_pixel(sprite_pixel),
        .sprite_priority(sprite_pixel_priority),

        .layer_enable(layer_enable[4:0] & LAYER_ENABLE_MASK),
        .layer_mask(layer_mask),

        .prioritized_pixel(prioritized_pixel),
        .prioritized_layer(prioritized_layer),
        .prioritized_masked_layer(prioritized_masked_layer),
        .prioritized_masked_pixel(prioritized_masked_pixel)
    );

    // --- VRAM bus arbiter ---

    reg [15:0] vram_read_data_even_r, vram_read_data_odd_r;
    wire [31:0] vram_read_data_r = {vram_read_data_odd_r, vram_read_data_even_r};

    always @(posedge clk) begin
        vram_read_data_even_r <= vram_read_data_even;
        vram_read_data_odd_r <= vram_read_data_odd;
    end

    wire [3:0] scroll_meta_load;
    wire [3:0] scroll_char_load;

    wire load_all_scroll_row_data;
    wire vram_written;

    wire [3:0] scroll_palette [0:3];
    wire [3:0] scroll_x_flip;

    // Most of the inputs to this aren't used in this iteration as they require substantial RAM
    // This could be revisited if a RAM compiler becomes available in a future run

    vdp_vram_bus_arbiter_standard bus_arbiter(
        .clk(clk),

        .raster_x_offset(raster_x_offset),
        .raster_x(raster_x),
        .raster_y(raster_y),

        // Scroll attributes

        .scroll_x_0(10'b0), .scroll_x_1(10'b0), .scroll_x_2(10'b0), .scroll_x_3(10'b0),
        .scroll_y_0(9'b0), .scroll_y_1(9'b0), .scroll_y_2(9'b0), .scroll_y_3(9'b0),

        .scroll_tile_base(16'b0),
        .scroll_map_base(16'b0),
        .scroll_use_wide_map(4'b0),

        // Affine attributes

        .affine_enabled(1'b0),
        .affine_offscreen(1'b0),

        .affine_vram_address_even(), .affine_vram_address_odd(),

        // Sprite attributes

        .vram_sprite_address(vram_sprite_address),

        // Output control for various functional blocks

        .vram_written(vram_written),
        .load_all_scroll_row_data(load_all_scroll_row_data),
        .vram_sprite_read_data_valid(vram_sprite_read_data_valid),

        .scroll_char_load(scroll_char_load),
        .scroll_meta_load(scroll_meta_load),

        // VRAM write control

        .vram_port_write_en_mask(vram_port_write_en_mask),
        .vram_write_address_16b(vram_write_address_16b),
        .vram_write_data_16b(vram_write_data_16b),

        // Output scroll attributes

        .scroll_palette_0(scroll_palette[0]), .scroll_palette_1(scroll_palette[1]),
        .scroll_palette_2(scroll_palette[2]), .scroll_palette_3(scroll_palette[3]),

        .scroll_x_flip_0(scroll_x_flip[0]), .scroll_x_flip_1(scroll_x_flip[1]),
        .scroll_x_flip_2(scroll_x_flip[2]), .scroll_x_flip_3(scroll_x_flip[3]),

        // VRAM interface

        .vram_read_data_even(vram_read_data_even_r),
        .vram_read_data_odd(vram_read_data_odd_r),

        .vram_address(vram_address),
        .vram_write_data_even(vram_write_data_even), .vram_write_data_odd(vram_write_data_odd),
        .vram_we_even(vram_we_even), .vram_we_odd(vram_we_odd)
    );

    // --- Sprites ---

    wire [7:0] sprite_pixel;
    wire [1:0] sprite_pixel_priority;

    wire [13:0] vram_sprite_address;
    wire vram_sprite_read_data_needs_x_flip;
    wire vram_sprite_read_data_valid;

    wire sprite_core_reset = line_ended;

    wire line_buffer_hold = sprites_y[0];

    vdp_sprite_core #(
        // .INIT_X_BLOCK(INIT_X_BLOCK),
        // .INIT_Y_BLOCK(INIT_Y_BLOCK),
        // .INIT_G_BLOCK(INIT_G_BLOCK)
    ) sprites (
        .clk(clk),
        .start_new_line(sprite_core_reset),

        // Drop LSB of countera to double pixel size
        .render_x({1'b0, sprites_x[9:1]}),

        .render_y({1'b0, sprites_y[8:1]}),
        // .render_y(sprites_y[8:0]),

        // Line buffer is normally cleared every line at full res
        // Doubling height means the rows are repeated and must be held for an extra line

        .line_buffer_hold(line_buffer_hold),
        // .line_buffer_hold(1'b0),

        .meta_address(sprite_metadata_address[4:0]),
        .meta_write_data(sprite_metadata_write_data),
        .meta_block_select(sprite_metadata_block_select),
        .meta_we(sprite_metadata_write_en),

        .vram_base_address(full_sprite_tile_base),
        .vram_read_address(vram_sprite_address),
        .vram_read_data(pixel_row_ordered),
        .vram_read_data_needs_x_flip(vram_sprite_read_data_needs_x_flip),
        .vram_data_valid(vram_sprite_read_data_valid),

        .pixel(sprite_pixel),
        .pixel_priority(sprite_pixel_priority)
    );

    // --- Affine layer ---
    // (affine disabled in vdp_lite)

endmodule
