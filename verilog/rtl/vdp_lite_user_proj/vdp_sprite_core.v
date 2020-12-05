// vdp_sprite_core.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

module vdp_sprite_core #(
    parameter INIT_X_BLOCK = "",
    parameter INIT_Y_BLOCK = "",
    parameter INIT_G_BLOCK = "",
    parameter SPRITES_TOTAL = 31,

    parameter [0:0] REGSTER_RENDER_X = 0
) (
    input clk,
    input start_new_line,

    input [9:0] render_x,
    input [8:0] render_y,
    input line_buffer_hold,

    input [4:0] meta_address,
    input [15:0] meta_write_data,
    input [2:0] meta_block_select,
    input meta_we,

    input [13:0] vram_base_address,
    output vram_read_data_needs_x_flip,
    output [13:0] vram_read_address,
    input [31:0] vram_read_data,
    input vram_data_valid,

    output [7:0] pixel,
    output [1:0] pixel_priority
);
    localparam SPRITES_ADDR_BITS = $clog2(SPRITES_TOTAL);

    reg line_buffer_hold_r;

    always @(posedge clk) begin
        if (start_new_line) begin
            line_buffer_hold_r <= line_buffer_hold;
        end
    end

    reg start_new_line_r;

    always @(posedge clk) begin
        start_new_line_r <= start_new_line;
    end

    // yosys hangs on the "make count" target with x_r removed:
    // > 28.39. Executing DFF2DFFE pass (transform $dff to $dffe where applicable).
    // ...
    // need to investigate this, leaving this commented out until then
    // It would save on LCs though
    // SPRITE_X_INITIAL needs to have an additional -1 if this change is made

    reg [9:0] render_x_r;

    generate
        if (REGSTER_RENDER_X) begin
            always @(posedge clk) begin
                render_x_r <= render_x;
            end
        end else begin
            always @* begin
                render_x_r = render_x;
            end
        end
    endgenerate

    // --- Metadata block writing ---

    assign x_block_we = meta_block_select[0] && meta_we;
    assign y_block_we = meta_block_select[1] && meta_we;
    assign g_block_we = meta_block_select[2] && meta_we;

    // --- y_block ---

    // ----whYy yyyyyyyy
    // y: sprite y (9 bits, could be extended to 10bits on another platform)
    // h: height select (8 or 16)
    // w: width select (8 or 16)
    // Y: Y flip - the advantage of doing it here is that it frees up bits in other attribute blocks
    // -: unused

    wire [7:0] y_block_read_address;
    wire [15:0] y_block_data_out;
    wire y_block_we;

    ffram #(
        .INIT_FILE(INIT_Y_BLOCK),
        .DATA_WIDTH(16),
        .ADDR_WIDTH(SPRITES_ADDR_BITS)
    ) y_block (
        .clk(clk),
        .wdata0(meta_write_data),
        .we0(y_block_we),
        .addr0(meta_address),

        .addr1(y_block_read_address[4:0]),
        .rdata1(y_block_data_out)
    );

    // --- g_block ---

    // ppppPPgg gggggggg
    // g: character #
    // p: palette
    // P: priority

    wire [7:0] g_block_read_address;
    wire [15:0] g_block_data_out;
    wire g_block_we;

    ffram #(
        .INIT_FILE(INIT_G_BLOCK),
        .DATA_WIDTH(16),
        .ADDR_WIDTH(SPRITES_ADDR_BITS)
    ) g_block (
        .clk(clk),
        .wdata0(meta_write_data),
        .we0(g_block_we),
        .addr0(meta_address),

        .addr1(g_block_read_address[4:0]),
        .rdata1(g_block_data_out)
    );

    // --- x_block ---

    // -----Xxx xxxxxxxx
    // x: x position
    // X: flip
    // -: unused

    wire [7:0] x_block_read_address;
    wire [15:0] x_block_data_out;
    wire x_block_we;

    ffram #(
        .INIT_FILE(INIT_X_BLOCK),
        .DATA_WIDTH(16),
        .ADDR_WIDTH(SPRITES_ADDR_BITS)
    ) x_block (
        .clk(clk),
        .wdata0(meta_write_data),
        .we0(x_block_we),
        .addr0(meta_address),

        .addr1(x_block_read_address[4:0]),
        .rdata1(x_block_data_out)
    );

    // --- Hit list (private) ---

    // layout:
    // T--wcccc iiiiiiii
    // i: sprite ID
    // c: collision Y within sprite (0-15, 16px sprite tall is the max)
    // w: width select (8 or 16)
    // T: terminator bit
    // -: unused

    wire hit_list_select = render_y[0];

    wire hit_list_ended = hit_list_render_read_data[15];

    wire [15:0] hit_list_render_read_data = hit_list_select ?
        hit_list_read_data_1 : hit_list_read_data_0;

    wire [7:0] hit_list_read_address;

    wire [7:0] hit_list_write_address;
    wire hit_list_write_en;
    wire [15:0] hit_list_data_in;

    wire [31:0] hit_list_read_data;
    wire [15:0] hit_list_read_data_0 = hit_list_read_data[15:0];
    wire [15:0] hit_list_read_data_1 = hit_list_read_data[31:16];

    generate
        genvar i;
        for (i = 0; i < 2; i = i + 1) begin : hit_list_gen
            wire write_en = hit_list_write_en & (hit_list_select ^ i);
            wire [15:0] read_data;

            assign hit_list_read_data[i * 16 + 15: i * 16] = read_data;

            wire [7:0] address = write_en ? hit_list_write_address : hit_list_read_address;

            ffram #(
                .DATA_WIDTH(16),
                .ADDR_WIDTH(SPRITES_ADDR_BITS)
            ) hit_list (
                .clk(clk),
                .wdata0(hit_list_data_in),
                .rdata0(read_data),
                .we0(write_en),
                .addr0(address[4:0])
            );
        end
    endgenerate

    // --- Line buffers ---

    // selected buffer toggles every line
    wire line_buffer_select = !render_y[0];

    // there is an offscreen and onscreen buffer at any given time
    // on: onscreen - being read
    // off: offscreen - being rendered to

    wire [9:0] line_buffer_write_address;
    wire [11:0] line_buffer_data_in;
    wire line_buffer_write_en;

    wire [9:0] line_buffer_clear_write_address;
    wire line_buffer_clear_en;

    // Reduced line buffer width means writes must be gated according to write address
    // The original BRAM setup means there was "spillover" RAM and this check wasn't needed
    wire line_buffer_write_gate = line_buffer_write_address < 256;
    wire line_buffer_gated_write = line_buffer_write_en && line_buffer_write_gate;

    // --- Line buffers ---

    wire [23:0] line_buffer_data_out;
    wire [11:0] line_buffer_data_out_0 = line_buffer_data_out[11:0];
    wire [11:0] line_buffer_data_out_1 = line_buffer_data_out[23:12];

    generate
        for (i = 0; i < 2; i = i + 1) begin : line_buffer_gen
            wire select = line_buffer_select ^ i;

            wire [9:0] write_address = select ? line_buffer_write_address : line_buffer_clear_write_address;
            wire [11:0] write_data = select ? line_buffer_data_in : line_buffer_clear_data_in;
            wire write_en = (select ? line_buffer_gated_write : line_buffer_clear_en) && !line_buffer_hold_r;
            wire [11:0] read_data;

            // Line buffer has reduced size and color index bitwidth
            // Originally it was 1024px x 10bit words
            // It is reduced to 256px (double-width rendered) and 2bit words

            wire [1:0] pixel_2bpp;
            assign read_data = {10'b0, pixel_2bpp};

            ffram #(
                .DATA_WIDTH(2),
                .ADDR_WIDTH(8)
            ) line_buffer (
                .clk(clk),
                .wdata0(write_data[1:0]),
                .we0(write_en),
                .addr0(write_address[7:0]),

                .addr1(line_buffer_display_read_address[7:0]),
                .rdata1(pixel_2bpp)
            );

            assign line_buffer_data_out[i * 12 + 11 : i * 12] = read_data;
        end
    endgenerate
    
    // --- Line buffer clearing ---

    reg [9:0] line_buffer_previous_read_address;
    assign line_buffer_clear_write_address = line_buffer_previous_read_address;
    wire [11:0] line_buffer_clear_data_in = 12'h000;

    assign line_buffer_clear_en = line_buffer_clear_write_address < 9'h100;

    always @(posedge clk) begin
        line_buffer_previous_read_address <= line_buffer_display_read_address;
    end
    
    // --- Line buffer reading ---

    wire [9:0] line_buffer_display_read_address;
    wire [9:0] line_buffer_display_data;

    // data to read from active buffer
    assign line_buffer_display_data = line_buffer_select ?
        line_buffer_data_out_1 : line_buffer_data_out_0;

    assign line_buffer_display_read_address = render_x_r;

    // These are registered in the sprite_line_buffer module

    // 8bit palette index
    assign pixel = line_buffer_display_data[7:0];
    // 2bit priority
    assign pixel_priority = line_buffer_display_data[9:8];

    // there is no competing access from blitter / prefetch
    assign hit_list_read_address = hit_list_blitter_read_address;

    // --- Sprite raster-collision testing ---

    // attribute extraction from y_block data

    wire [8:0] sprite_y_read = y_block_data_out[8:0];
    wire [4:0] sprite_selected_height = y_block_data_out[10] ? 16 : 8;
    wire sprite_flip_y = y_block_data_out[9];
    wire sprite_width_select = y_block_data_out[11];

    assign hit_list_data_in[14:13] = 0;

    vdp_sprite_raster_collision #(
        .SPRITES_TOTAL(SPRITES_TOTAL)
    ) collision (
        .clk(clk),
        .restart(start_new_line_r),

        .render_y(render_y),

        // reading
        .sprite_y(sprite_y_read),
        .sprite_test_id(y_block_read_address),
        .sprite_height(sprite_selected_height),
        .flip_y(sprite_flip_y),
        .width_select_in(sprite_width_select),

        // writing
        .sprite_y_intersect(hit_list_data_in[11:8]),
        .sprite_id(hit_list_data_in[7:0]),
        .hit_list_index(hit_list_write_address),
        .finished(hit_list_data_in[15]),
        .width_select_out(hit_list_data_in[12]),
        .hit_list_write_en(hit_list_write_en)
    );

    // --- Sprite render ---

    wire [7:0] hit_list_blitter_read_address;
    wire [7:0] blitter_sprite_meta_read_address;

    // these happen to be the same read address, at the same time
    assign g_block_read_address = blitter_sprite_meta_read_address;
    assign x_block_read_address = blitter_sprite_meta_read_address;

    vdp_sprite_render render(
        .clk(clk),
        .restart(start_new_line_r),

        .vram_base_address(vram_base_address),
        .vram_read_address(vram_read_address),
        .vram_read_data_needs_x_flip(vram_read_data_needs_x_flip),
        .vram_read_data(vram_read_data),
        .vram_data_valid(vram_data_valid),

        .sprite_meta_address(blitter_sprite_meta_read_address),

        .character(g_block_data_out[9:0]),
        .palette(g_block_data_out[15:12]),
        .pixel_priority(g_block_data_out[11:10]),

        .target_x(x_block_data_out[9:0]),
        .flip_x(x_block_data_out[10]),

        .line_buffer_write_address(line_buffer_write_address),
        .line_buffer_write_data(line_buffer_data_in),
        .line_buffer_write_en(line_buffer_write_en),
        
        .hit_list_read_address(hit_list_blitter_read_address),
        .sprite_id(hit_list_render_read_data[7:0]),
        .line_offset(hit_list_render_read_data[11:8]),
        .width_select(hit_list_render_read_data[12]),
        .hit_list_ended(hit_list_ended)
    );

endmodule
