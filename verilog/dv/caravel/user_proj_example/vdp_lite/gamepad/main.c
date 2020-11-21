#include <stdbool.h>
#include <stddef.h>

#include "gamepad.h"
#include "gpio.h"

void main() {
    gpio_init();

    // 1. Read gamepads

    uint16_t p1 = 0, p1_edge = 0, p2 = 0, p2_edge = 0;
    pad_read(&p1, &p2, &p1_edge, &p2);
    
    // 2. Output gamepad state, a nybble at a time, to LEDs

    led_set(p1 & 0xf);
    led_set(p1 >> 4 & 0xf);
    led_set(p1 >> 8 & 0xf);

    led_set(p2 & 0xf);
    led_set(p2 >> 4 & 0xf);
    led_set(p2 >> 8 & 0xf);
}
