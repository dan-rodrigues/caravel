#!/usr/bin/env python

# process_rgbs.py
#
# Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0

import png
import struct
import sys

# Read sim generated log of RGBS output:

log_file = open("rgbs.log", "rb")

raw_log = log_file.read()
log_file.close()

image_width = 640 + 160 + 5
image_height = 480 + 44 + 5

total_size = image_width * image_height * 3
rgba = bytearray(total_size)

# Convert to RGB24:

x = 0
y = 0
hsync_prev = 0
index = 0

while index < len(raw_log):
    word = int.from_bytes(raw_log[index:index + 4], byteorder='little')

    hsync = (word & (1 << 24)) == 0
    vsync = (word & (1 << 25)) == 0
    frame_ended = (word & (1 << 26) != 0)

    if frame_ended:
        print("Frame ended")
        break

    if y >= image_height:
        sys.exit("Error: expected frame_ended before reaching end of frame")

    is_newline = hsync and not hsync_prev
    if is_newline:
        print("Finished line: %d, (hsync active at x=%d)" % (y, x))
        x = 0
        y += 1
            

    base = (y * image_width + x) * 3

    if x < image_width:
        rgba[base + 0] = (word >> 16 & 0xff)
        rgba[base + 1] = (word >> 8 & 0xff)
        rgba[base + 2] = (word >> 0 & 0xff)
        x += 1
    else:
        sys.exit("Error: xpos moved beyond bounds (did not receive expected hsync)")

    hsync_prev = hsync

    index += 4

# Write RGB24 data to PNG for review:

png_file = open('screen.png', 'wb')
w = png.Writer(greyscale=False, width=image_width, height=image_height).write_array(png_file, rgba)   
png_file.close()
