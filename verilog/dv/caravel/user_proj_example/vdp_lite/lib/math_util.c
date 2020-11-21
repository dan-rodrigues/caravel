// math_util.c
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#include "math_util.h"

#include "sin_table.h"

// sin() / cos()

static const uint16_t SIN_HALF_PERIOD = SIN_PERIOD / 2;
static const uint16_t SIN_QUARTER_PERIOD = SIN_PERIOD / 4;

int16_t cos(uint16_t angle) {
    return sin(angle + SIN_QUARTER_PERIOD);
}

int16_t sin(uint16_t angle) {
    angle &= (SIN_PERIOD - 1);

    // special cases to avoid "flat spots" in the sin wave
    if (angle == SIN_QUARTER_PERIOD) {
        return SIN_MAX;
    } else if (angle == (3 * SIN_QUARTER_PERIOD)) {
        return -SIN_MAX;
    }

    uint16_t index = angle;
    index = (angle & SIN_QUARTER_PERIOD ? -index : index);
    index &= (SIN_QUARTER_PERIOD - 1);

    int16_t sin = sin_table[index];

    return (angle & SIN_HALF_PERIOD ? -sin : sin);
}
