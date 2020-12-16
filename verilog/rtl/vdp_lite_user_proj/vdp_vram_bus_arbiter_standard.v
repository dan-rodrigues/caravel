// vdp_vram_bus_arbiter_standard.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

`include "debug.vh"
`include "layer_encoding.vh"

// 3 layer, non-interleaved bus arbiter
// Unlike vdp_vram_bus_arbiter_interleaved, tilemaps are stored in VRAM contiguously
// This sacrifices 1 layer in exchange for more flexible, less wasteful VRAM management

module vdp_vram_bus_arbiter_standard(
    input clk,

    // Reference raster positions

    input [10:0] raster_x_offset,
    input [10:0] raster_x,
    input [9:0] raster_y,

    // Scroll attributes

    input [9:0] scroll_x_0, scroll_x_1, scroll_x_2, scroll_x_3,
    input [8:0] scroll_y_0, scroll_y_1, scroll_y_2, scroll_y_3,

    // 4 layers combined
    input [15:0] scroll_tile_base,
    input [15:0] scroll_map_base,

    // Affine attributes

    input affine_enabled,
    input affine_offscreen,
    input [13:0] affine_vram_address_even, affine_vram_address_odd,

    // Sprite attributes

    input [13:0] vram_sprite_address,

    // 4 layers combined
    input [3:0] scroll_use_wide_map,

    // Output scroll attributes

    output [3:0] scroll_palette_0, scroll_palette_1, scroll_palette_2, scroll_palette_3,
    output scroll_x_flip_0, scroll_x_flip_1, scroll_x_flip_2, scroll_x_flip_3,

    // Output control for various functional blocks

    output reg load_all_scroll_row_data,
    output reg vram_written,
    output reg vram_sprite_read_data_valid,

    output reg [3:0] scroll_char_load,
    output reg [3:0] scroll_meta_load,

    // VRAM write control

    input [1:0] vram_port_write_en_mask,
    input [13:0] vram_write_address_16b,
    input [15:0] vram_write_data_16b,

    // VRAM interface

    input [15:0] vram_read_data_even,  vram_read_data_odd,

    // vdp_lite has one address instead of split even / odd (affine layer used it only)
    output reg [13:0] vram_address,
    output reg [15:0] vram_write_data_even, vram_write_data_odd,
    output reg vram_we_even, vram_we_odd
);
    // No scrolling layers in vdp_lite, so these sections have been removed completely

    // --- Layer attribute selection ---
    // --- Tile address generator ---
    // --- Map address generators ---

    assign scroll_palette_0 = 0;
    assign scroll_palette_1 = 0;
    assign scroll_palette_2 = 0;
    assign scroll_palette_3 = 0;

    assign scroll_x_flip_0 = 0;
    assign scroll_x_flip_1 = 0;
    assign scroll_x_flip_2 = 0;
    assign scroll_x_flip_3 = 0;

    // --- VRAM bus control ---

    reg [13:0] vram_address_nx;
    reg [1:0] vram_render_write_en_mask_nx;

    reg [1:0] map_address_layer_select;
    reg [1:0] tile_address_layer_select;

    always @* begin
        scroll_meta_load = 0;
        scroll_char_load = 0;

        map_address_layer_select = 0;
        tile_address_layer_select = 0;

        load_all_scroll_row_data = 0;
        vram_render_write_en_mask_nx = 0;

        vram_address_nx = 0;
        vram_written = 0;

        vram_sprite_read_data_valid = 0;

        case (raster_x_offset[2:0])
            0: begin
                // now: s0 map data
                // scroll_meta_load = `LAYER_SCROLL0_OHE;

                // host write - every 8 cycles
                vram_address_nx = vram_write_address_16b;
                vram_written = 1;
                vram_render_write_en_mask_nx = vram_port_write_en_mask;
            end
            1: begin
                // now: s1 map
                // scroll_meta_load = `LAYER_SCROLL1_OHE;

                // next: sprite access
                vram_address_nx = vram_sprite_address;

                // next next: s0 tile address
                // tile_address_layer_select = `LAYER_SCROLL0;
            end
            2: begin
                // now: s2 map
                // scroll_meta_load = `LAYER_SCROLL2_OHE;

                // next: s0 tile
                // vram_address_nx = tile_address;

                // next next: s1 tile address
                // tile_address_layer_select = `LAYER_SCROLL1;
            end
            3: begin
                // next: s1 tile
                // vram_address_nx = tile_address;

                // next next: s2 tile address
                // tile_address_layer_select = `LAYER_SCROLL2;
            end
            4: begin
                // now: sprites acccess
                vram_sprite_read_data_valid = 1;

                // next: s2 tile
                // vram_address_nx = tile_address;

                // next next: s0 map
                // map_address_layer_select = `LAYER_SCROLL0;
            end
            5: begin
                // now: s0 tile
                // scroll_char_load = `LAYER_SCROLL0_OHE;

                // next: s0 map
                // vram_address_nx = map_address;

                // next next: s1 map
                // map_address_layer_select = `LAYER_SCROLL1;
            end
            6: begin
                // now: s1 tile
                // scroll_char_load = `LAYER_SCROLL1_OHE;

                // next: s1 map
                // vram_address_nx = map_address;

                // next next: s2 map
                // map_address_layer_select = `LAYER_SCROLL2;
            end
            7: begin
                // now: s1 tile
                // scroll_char_load = `LAYER_SCROLL2_OHE;

                // next: s2 map
                // vram_address_nx = map_address;

                // now: s3 tile, which is loaded simultaneously with the previously prefetched layers
                // load_all_scroll_row_data = 1;
            end
        endcase
    end

    // --- VRAM write data passthrough ---

    always @* begin
        vram_write_data_even = vram_write_data_16b;
        vram_write_data_odd = vram_write_data_16b;
    end

    // --- VRAM bus registers ---

    always @(posedge clk) begin
        vram_address <= vram_address_nx;

        vram_we_even <= vram_render_write_en_mask_nx[0];
        vram_we_odd <= vram_render_write_en_mask_nx[1];
    end

    // --- VRAM base address mapping functions ---

    function [13:0] full_scroll_tile_base;
        input [1:0] layer;

        begin
            full_scroll_tile_base = {scroll_tile_base >> (layer * 4), 11'b0};
        end

    endfunction
        
    function [14:0] full_scroll_map_base;
        input [1:0] layer;

        begin
            full_scroll_map_base = {scroll_map_base >> (layer * 4), 12'b0};
        end

    endfunction

endmodule
