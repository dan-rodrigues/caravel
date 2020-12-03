// gpio.h
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

#ifndef gpio_h
#define gpio_h

#include <stdint.h>

void gpio_init(void);
void led_set(uint8_t state);

#endif /* gpio_h */
