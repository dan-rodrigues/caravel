// math_util.h
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

#ifndef math_util_h
#define math_util_h

#include <stdint.h>

#define MIN(a, b) (((a) < (b)) ? (a) : (b))
#define MAX(a, b) (((a) > (b)) ? (a) : (b))
#define ABS(a) (((a) < 0) ? (-(a)) : (a))
#define SIGN(a) ((a) < 0)

static const uint16_t SIN_PERIOD = 0x400;
static const int16_t SIN_MAX = 0x4000;

int16_t cos(uint16_t angle);
int16_t sin(uint16_t angle);

#endif
