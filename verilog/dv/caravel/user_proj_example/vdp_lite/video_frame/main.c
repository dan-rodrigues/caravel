// main.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

// From Caravel:

#include "../../../defs.h"
#include "../../../stub.c"

// User proj additions:

#include <stdbool.h>
#include <stddef.h>

#include "vdp.h"
#include "vdp_regs.h"
#include "math_util.h"
#include "gamepad.h"
#include "gpio.h"

#include "sprite_text_attributes.h"

// Adjusted defines with minimized VDP:

#define SPRITES_TOTAL 31

static uint16_t sprite_buffer[SPRITES_TOTAL * 3];
static uint16_t *sprite_buffer_pointer;

#define LITE_ACTIVE_WIDTH 256
#define LITE_ACTIVE_HEIGHT 240

// UART: (very slow in sim when enabled)

//#define UART_ENABLED

static void println(const char *line);

// Additional VDP control:

typedef enum {
    VDP_EXTRA_CTRL_ACTIVE = (1 << 0),
    VDP_EXTRA_CTRL_HOLD_RASTER = (1 << 1)
} VDPExtraControlMask;

static void palette_init(void);
static void sprite_init(void);

// Sprites:

static void sprite_init(void);
static void draw_circle_sprites(uint16_t angle);
static void draw_greeting_sprites(uint16_t step);
static void sprite_write_buffer(uint16_t x, uint16_t y, uint16_t g);
static void sprite_reset_buffer(void);
static void sprite_upload_buffer(void);
static void sprite_putc(char c, uint16_t *x, uint16_t y);

static void custom_tiles_init(void);

void main() {
    gpio_init();
    println("GPIO inititalized");
    
    // Enable VDP (remains in reset until this is set)
    reg_mprj_slave = VDP_EXTRA_CTRL_ACTIVE | VDP_EXTRA_CTRL_HOLD_RASTER;
    println("VDP on");
    
    palette_init();
    sprite_init();
    println("VDP sprites on");
    
    // Prepare screen content before starting raster counter
    // This also gives the sim something to render when raster counters start
    draw_circle_sprites(0);
    draw_greeting_sprites(0);

    // Only used to test VRAM writing / reading
//    custom_tiles_init();

    sprite_upload_buffer();
    
    // Allow VDP raster to start after initial config
    reg_mprj_slave = VDP_EXTRA_CTRL_ACTIVE;
    println("VDP raster counter on");
    
    // Allow one frame to finish so it can be captured by sim
    vdp_wait_frame_ended();
    
    uint16_t step = 0;
    
    while(true) {
        draw_circle_sprites(step);
        draw_greeting_sprites(step);
        step++;
        
        vdp_wait_frame_ended();
        sprite_upload_buffer();
    }
}

static void println(const char *line) {
#ifdef UART_ENABLED
    print(line);
    print("\n");
#endif
}

static void palette_init() {
    const uint16_t bg_color = 0xf488;
    const uint16_t text_foreground_color = 0xffff;
    const uint16_t text_background_color = 0xf000;
    
    vdp_set_single_palette_color(0, bg_color);
    vdp_set_single_palette_color(1, text_background_color);
    vdp_set_single_palette_color(2, text_foreground_color);
}

static void draw_circle_sprites(uint16_t angle) {
    const int16_t screen_center_x = LITE_ACTIVE_WIDTH / 2;
    const int16_t screen_center_y = LITE_ACTIVE_HEIGHT / 2;
    
    const uint8_t star_count = 8;
    const int16_t circle_radius = 110;
    const int16_t angle_delta = SIN_PERIOD / star_count;
    
    const SpriteTextCharAttributes *attributes = st_char_attributes('*');
    
    for (uint32_t i = 0; i < star_count; i++) {
        // Position within circle
        
        int16_t x = screen_center_x - 8;
        int16_t y = screen_center_y - 8;
        
        x += (cos(angle) * circle_radius) / SIN_MAX;
        y += (sin(angle) * circle_radius) / SIN_MAX;
        angle += angle_delta;
        
        // Draw sprite
        
        uint16_t x_block = x;
        
        uint16_t y_block = y;
        y_block |= SPRITE_16_TALL | SPRITE_16_WIDE;
        
        uint16_t g_block = attributes->base_tile;
        
        sprite_write_buffer(x_block, y_block, g_block);
    }
}

static void draw_greeting_sprites(uint16_t step) {
    const char *greeting1 = "* VDP LITE *";
    const char *greeting2 = "ASIC SPRITES!";
    
    // Greeting 1 has a wave effect
    
    const int16_t g1_x = 80;
    const int16_t g1_y = 90;
    
    uint16_t x = g1_x;
    const int16_t g1_wave_amplitude = 8;
    const int16_t g1_wave_period = 8;
    const uint16_t g1_wave_angle_delta = SIN_PERIOD / g1_wave_period;
    
    uint32_t char_count = 0;
    uint16_t g1_angle = step * 16;
    
    while (*greeting1) {
        int16_t wave_offset_y = (sin(g1_angle) * g1_wave_amplitude / 2) / SIN_MAX;
        int16_t y = g1_y + wave_offset_y;
        sprite_putc(*greeting1++, &x, y);
        
        g1_angle += g1_wave_angle_delta;
        char_count++;
    }
    
    // Greeting 2 has a bounce effect
    
    const int16_t g2_x = 78;
    const int16_t g2_y = 170;
    
    const int16_t g2_wave_amplitude = 80;
    const int16_t g2_wave_period = 32;
    const uint16_t g2_wave_angle_delta = SIN_PERIOD / g2_wave_period;
    
    uint16_t g2_angle = step * 4;
    char_count = 0;
    x = g2_x;
    
    while (*greeting2) {
        g2_angle %= SIN_PERIOD / 2;
        int16_t wave_offset_y = -(sin(g2_angle) * g2_wave_amplitude / 2) / SIN_MAX;
        int16_t y = g2_y + wave_offset_y;
        sprite_putc(*greeting2++, &x, y);
        
        g2_angle += g2_wave_angle_delta;
        
        char_count++;
    }
}

static void sprite_putc(char c, uint16_t *x, uint16_t y) {
    const SpriteTextCharAttributes *attributes = st_char_attributes(c);
    
    if (c == ' ') {
        *x += 5;
        return;
    }
    
    uint16_t x_block = *x;
    
    uint16_t y_block = y;
    y_block |= SPRITE_16_TALL;
    y_block |= attributes->wide ? SPRITE_16_WIDE : 0;
    
    uint16_t g_block = attributes->base_tile;
    
    sprite_write_buffer(x_block, y_block, g_block);
    
    *x += attributes->width;
}

static void sprite_init() {
    vdp_enable_layers(SPRITES);
    
    // Move all sprites offscreen
    vdp_seek_sprite(0);
    for (uint32_t i = 0; i < SPRITES_TOTAL; i++) {
        vdp_write_sprite_meta(0, LITE_ACTIVE_HEIGHT, 0);
        
        sprite_buffer[i * 3 + 0] = 0;
        sprite_buffer[i * 3 + 1] = LITE_ACTIVE_HEIGHT;
        sprite_buffer[i * 3 + 2] = 0;
    }
    
    sprite_reset_buffer();
}

static void sprite_reset_buffer() {
    sprite_buffer_pointer = sprite_buffer;
}

static void sprite_write_buffer(uint16_t x, uint16_t y, uint16_t g) {
    *sprite_buffer_pointer++ = x;
    *sprite_buffer_pointer++ = y;
    *sprite_buffer_pointer++ = g;
}

static void sprite_upload_buffer() {
	vdp_seek_sprite(0);

    for (uint16_t *buffer_read = sprite_buffer; buffer_read < sprite_buffer_pointer; buffer_read += 3) {
        vdp_write_sprite_meta(buffer_read[0], buffer_read[1], buffer_read[2]);
    }
    
    sprite_reset_buffer();
}

static void custom_tiles_init() {
    static const uint32_t tiles0[] = {
        0x12222221,
        0x11222211,
        0x11122111,
        0x11122111,
        0x11122111,
        0x11222211,
        0x12222221,
        0x12222221,

        0x10101010,
        0x11222211,
        0x11122111,
        0x11122111,
        0x11122111,
        0x12222221,
        0x11222211,
        0x10101010
    };

    static const uint32_t tiles1[] = {
        0x11111111,
        0x22222222,
        0x11111111,
        0x22222222,
        0x11111111,
        0x22222222,
        0x11111111,
        0x22222222,

        0x12222221,
        0x11222211,
        0x11122111,
        0x11122111,
        0x11122111,
        0x11222211,
        0x12222221,
        0x12222221,
    };

    // VDP *must* start or else can't write VRAM
    reg_mprj_slave = VDP_EXTRA_CTRL_ACTIVE;

    const uint16_t vram_base = 0x80 * 32 / 2;
    vdp_set_vram_increment(1);

    vdp_seek_vram(vram_base);
    vdp_write_vram_block((uint16_t *)tiles0, 0x10 * 2);
    vdp_seek_vram(vram_base + 0x10 * 0x10);
    vdp_write_vram_block((uint16_t *)tiles1, 0x10 * 2);

    // Sprites:

    sprite_init();

    vdp_seek_sprite(0);
    vdp_write_sprite_meta(8, 20 | SPRITE_16_TALL | SPRITE_16_WIDE, 0x80);
}
