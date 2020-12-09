// gpio.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

#include <stddef.h>

// From Caravel:

#include "../../caravel/defs.h"

// New additions:

#include "gpio.h"

#define GPIO_LED_0 reg_mprj_io_34
#define GPIO_LED_1 reg_mprj_io_35
#define GPIO_LED_2 reg_mprj_io_36
#define GPIO_LED_3 reg_mprj_io_37

#define GPIO_LED (*(volatile uint32_t*)0x30300000)

// Could walk the address space instead but not taking chances incase these regs move around
void gpio_init() {
    // Video IO

    // RGB out
    reg_mprj_io_12 =  GPIO_MODE_USER_STD_OUTPUT;
    reg_mprj_io_13 =  GPIO_MODE_USER_STD_OUTPUT;
    reg_mprj_io_14 =  GPIO_MODE_USER_STD_OUTPUT;
    reg_mprj_io_15 =  GPIO_MODE_USER_STD_OUTPUT;
    reg_mprj_io_16 =  GPIO_MODE_USER_STD_OUTPUT;
    reg_mprj_io_17 =  GPIO_MODE_USER_STD_OUTPUT;
    reg_mprj_io_18 =  GPIO_MODE_USER_STD_OUTPUT;
    reg_mprj_io_19 =  GPIO_MODE_USER_STD_OUTPUT;
    reg_mprj_io_20 =  GPIO_MODE_USER_STD_OUTPUT;
    reg_mprj_io_21 =  GPIO_MODE_USER_STD_OUTPUT;
    reg_mprj_io_22 =  GPIO_MODE_USER_STD_OUTPUT;
    reg_mprj_io_23 =  GPIO_MODE_USER_STD_OUTPUT;

    // VDP flags
    reg_mprj_io_24 =  GPIO_MODE_USER_STD_OUTPUT;
    reg_mprj_io_25 =  GPIO_MODE_USER_STD_OUTPUT;
    reg_mprj_io_26 =  GPIO_MODE_USER_STD_OUTPUT;
    reg_mprj_io_27 =  GPIO_MODE_USER_STD_OUTPUT;

    // Pixel clock (optional)
    reg_mprj_io_28 =  GPIO_MODE_USER_STD_OUTPUT;

    // VDP raster hold flag
    reg_mprj_io_29 =  GPIO_MODE_USER_STD_OUTPUT;

    // Gamepad IO

    // CLK
    reg_mprj_io_30 =  GPIO_MODE_USER_STD_OUTPUT;
    // Latch
    reg_mprj_io_31 =  GPIO_MODE_USER_STD_OUTPUT;
    // P1 serial data in
    reg_mprj_io_32 =  GPIO_MODE_USER_STD_INPUT_NOPULL;
    // P2 serial data in
    reg_mprj_io_33 =  GPIO_MODE_USER_STD_INPUT_NOPULL;

    // LEDs (or whatever substitute)

    reg_mprj_io_34 =  GPIO_MODE_USER_STD_OUTPUT;
    reg_mprj_io_35 =  GPIO_MODE_USER_STD_OUTPUT;
    reg_mprj_io_36 =  GPIO_MODE_USER_STD_OUTPUT;
    reg_mprj_io_37 =  GPIO_MODE_USER_STD_OUTPUT;

    // UART (VERY low in simulator)
    reg_mprj_io_6  = GPIO_MODE_MGMT_STD_OUTPUT;
    // Set UART clock to 64 kbaud (enable before I/O configuration)
    reg_uart_clkdiv = 625;
    reg_uart_enable = 1;

    // Apply config
    reg_mprj_xfer = 1;
    while (reg_mprj_xfer == 1);
}

void led_set(uint8_t state) {
	GPIO_LED = state;
}
