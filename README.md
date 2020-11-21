# vdp-lite (SKY130 shuttle)

![vdp-lite animated GIF demo](demo.gif)

This is a basic sprite generator that can be controlled using the PicoRV32 + WB interface of the Caravel SoC. It outputs 640x480@60Hz video with pixels doubled to 320x240. The sides of the screen are clipped by 64 pixels each to reduce the "FF RAM" address width to 8bits. If all goes well, OpenRAM could be used in future runs to relax some of these constraints, restore features etc.

The sprites can have arbitrary screen positions and can select any glyph from the character ROM.

It is a minimized variant of the VDP found in the [icestation-32](https://github.com/dan-rodrigues/icestation-32) project. The rest of the system is not included although minimal serial IO for gamepad reading is included. To fit the time / memory constraints, functionality has either been removed or simplified.

The font included in the character ROM is the [Good Neighbours pixel font](https://opengameart.org/content/good-neighbors-pixel-font) by Clint Bellanger, which is public domain.

## Tests

Testbenches that instantiate the `caravel` SoC running tests software.

* `video_frame`: Outputs a complete video frame using dumped RGBHV outputs, which is then converted using a Python script to a PNG.
* `gamepad`: Exercises the gamepad serial IO and (tentative) LED outputs.

A sample PNG from the `video_frame` is shown below. It takes a very long time to complete and can be manually cut short to show a partial frame. The black borders represent the front/backporches.

![](verilog/dv/caravel/user_proj_example/vdp_lite/video_frame/screen_progress/complete.png)

## TODO

* Configured config.tcl files appropriately for DRC clean design.
* SPDX license headers.
* Extract this README.md section.
* Extract project-specific contents to separate repo.

The original contents of the README file follow:

# CIIC Harness  

A template SoC for Google SKY130 free shuttles. It is still WIP. The current SoC architecture is given below.

<p align=”center”>
<img src="/doc/ciic_harness.png" width="75%" height="75%"> 
</p>

## Managment SoC
The managment SoC runs firmware that can be used to:
- Configure Mega Project I/O pads
- Observe and control Mega Project signals (through on-chip logic analyzer probes)
- Control the Mega Project power supply

The memory map of the management SoC can be found [here](verilog/rtl/README)

## Mega Project Area
This is the user space. It has limited silicon area (TBD, about 3.1mm x 3.8mm) as well as a fixed number of I/O pads (37) and power pads (10).  See [the Caravel  premliminary datasheet](doc/caravel_datasheet.pdf) for details.
The repository contains a [sample mega project](/verilog/rtl/user_proj_example.v) that contains a binary 32-bit up counter.  </br>

<p align=”center”>
<img src="/doc/counter_32.png" width="50%" height="50%">
</p>

The firmware running on the Management Area SoC, configures the I/O pads used by the counter and uses the logic probes to observe/control the counter. Three firmware examples are provided:
1. Configure the Mega Project I/O pads as o/p. Observe the counter value in the testbench: [IO_Ports Test](verilog/dv/caravel/user_proj_example/io_ports).
2. Configure the Mega Project I/O pads as o/p. Use the Chip LA to load the counter and observe the o/p till it reaches 500: [LA_Test1](verilog/dv/caravel/user_proj_example/la_test1).
3. Configure the Mega Project I/O pads as o/p. Use the Chip LA to control the clock source and reset signals and observe the counter value for five clock cylcles:  [LA_Test2](verilog/dv/caravel/user_proj_example/la_test2).
