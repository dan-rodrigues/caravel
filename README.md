<!---
# SPDX-FileCopyrightText: 2020 Efabless Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
-->

# vdp-lite (SKY130 shuttle)

![vdp-lite animated GIF demo](demo.gif)

This is a basic sprite generator that can be controlled using the PicoRV32 + WB interface of the Caravel SoC. It outputs 640x480@60Hz video with pixels doubled to 320x240. The sides of the screen are clipped by 64 pixels each to reduce the "FF RAM" address width to 8bits. If all goes well, OpenRAM could be used in future runs to relax some of these constraints, restore features etc.

The sprites can have arbitrary screen positions and can select any glyph from the character ROM.

It is a minimized variant of the VDP found in the [icestation-32](https://github.com/dan-rodrigues/icestation-32) project. The rest of the system is not included although minimal serial IO for gamepad reading is included. To fit the time / memory constraints, functionality has either been removed or simplified.

The font included in the character ROM is the [Good Neighbours pixel font](https://opengameart.org/content/good-neighbors-pixel-font) by Clint Bellanger, which is public domain.

## Building

### User project GDS

```
cd openlane
make vdp_lite_user_proj
```

The `/openlane` directory contains  a symlink to a `$readmemh` file to be treated as ROM. Attempting to build it a different way or with a different CWD may fail.

The resulting `vdp_lite_user_proj.gds` and `vdp_lite_user_proj.lef` should be moved to the project `/gds` and `/lef` directories respectively, to be consistent with how others in caravel are handled.

### User project wrapper

Then to build the user project wrapper:

```
cd openlane
make user_project_wrapper
```

The resulting GDS / LEF can then be integrated into Caravel

## Tools used

`mpw-one-a` openlane / open_pdks was used to create the user project and wrapper GDS.

`mpw-one-b` was used to create caravel.gds as part of `make ship`.

## Tests

Testbenches that instantiate the `caravel` SoC running tests software. They can be found in the `verilog/dv/vdp_lite` directory. 

There is a `GL_SIM` variable in core.mk that can enable the `gl/` verilog (on by default).

* `video_frame`: Outputs a complete video frame using dumped RGBHV outputs, which is then converted using a Python script to a PNG.
* `gamepad`: Exercises the gamepad serial IO and (tentative) LED outputs.

A sample PNG from the `video_frame` is shown below. It takes a very long time to complete and can be manually cut short to show a partial frame. The black borders represent the front/backporches.

![](verilog/dv/vdp_lite/video_frame/screen_progress/gl_sim_output.png)

## TODO

* Extract project-specific contents to separate repo.

The original contents of the README file follow:

# CIIC Harness  

A template SoC for Google SKY130 free shuttles. It is still WIP. The current SoC architecture is given below.

<p align="center">
<img src="/doc/ciic_harness.png" width="75%" height="75%"> 
</p>


## Getting Started:

* For information on tooling and versioning, please refer to [this][1].

Start by cloning the repo and uncompressing the files.
```bash
git clone https://github.com/efabless/caravel.git
cd caravel
make uncompress
```

Then you need to install the open_pdks prerequisite:
 - [Magic VLSI Layout Tool](http://opencircuitdesign.com/magic/index.html) is needed to run open_pdks -- version >= 8.3.60*

 > \* Note: You can avoid the need for the magic prerequisite by using the openlane docker to do the installation step in open_pdks. This could be done by cloning [openlane](https://github.com/efabless/openlane/tree/master) and following the instructions given there to use the Makefile.

Install the required version of the PDK by running the following commands:

```bash
export PDK_ROOT=<The place where you want to install the pdk>
make pdk
```

Then, you can learn more about the caravel chip by watching these video:
- Caravel User Project Features -- https://youtu.be/zJhnmilXGPo
- Aboard Caravel -- How to put your design on Caravel? -- https://youtu.be/9QV8SDelURk
- Things to Clarify About Caravel -- What versions to use with Caravel? -- https://youtu.be/-LZ522mxXMw
    - You could only use openlane:rc6
    - Make sure you have the commit hashes provided here inside the [Makefile](./Makefile)
## Aboard Caravel:

Your area is the full user_project_wrapper, so feel free to add your project there or create a differnt macro and harden it seperately then insert it into the user_project_wrapper. For example, if your design is analog or you're using a different tool other than OpenLANE.

If you will use OpenLANE to harden your design, go through the instructions in this [README.md][0].

You must copy your synthesized gate-level-netlist for `user_project_wrapper` to `verilog/gl/` and overwrite `user_project_wrapper.v`. Otherwise, you can point to it in [info.yaml](info.yaml).

> Note: If you're using openlane to harden your design, this should happen automatically.

Then, you will need to put your design aboard the Caravel chip. Make sure you have the following:

- [Magic VLSI Layout Tool](http://opencircuitdesign.com/magic/index.html) installed on your machine. We may provide a Dockerized version later.\*
- You have your user_project_wrapper.gds under `./gds/` in the Caravel directory.

 > \* **Note:** You can avoid the need for the magic prerequisite by using the openlane docker to run the make step. This [section](#running-make-using-openlane-magic) shows how.

Run the following command:

```bash
export PDK_ROOT=<The place where the installed pdk resides. The same PDK_ROOT used in the pdk installation step>
make
```

This should merge the GDSes using magic and you'll end up with your version of `./gds/caravel.gds`. You should expect ~90 magic DRC violations with the current "development" state of caravel.

## Running Make using OpenLANE Magic

To use the magic installed inside Openlane to complete the final GDS streaming out step, export the following:

```bash
export PDK_ROOT=<The location where the pdk is installed>
export OPENLANE_ROOT=<the absolute path to the openlane directory cloned or to be cloned>
export IMAGE_NAME=<the openlane image name installed on your machine. Preferably openlane:rc6>
export CARAVEL_PATH=$(pwd)
```

Then, mount the docker:

```bash
docker run -it -v $CARAVEL_PATH:$CARAVEL_PATH -v $OPENLANE_ROOT:/openLANE_flow -v $PDK_ROOT:$PDK_ROOT -e CARAVEL_PATH=$CARAVEL_PATH -e PDK_ROOT=$PDK_ROOT -u $(id -u $USER):$(id -g $USER) $IMAGE_NAME
```

Finally, once inside the docker run the following commands:
```bash
cd $CARAVEL_PATH
make
exit
```

This should merge the GDSes using magic and you'll end up with your version of `./gds/caravel.gds`. You should expect ~90 magic DRC violations with the current "development" state of caravel.


## IMPORTANT:

Please make sure to run `make compress` before commiting anything to your repository. Avoid having 2 versions of the gds/user_project_wrapper.gds or gds/caravel.gds one compressed and the other not compressed.

## Required Directory Structure

- ./gds/ : includes all the gds files used or produced from the project.
- ./def/ : includes all the def files used or produced from the project.
- ./lef/ : includes all the lef files used or produced from the project.
- ./mag/ : includes all the mag files used or produced from the project.
- ./maglef/ : includes all the maglef files used or produced from the project.
- ./spi/lvs/ : includes all the maglef files used or produced from the project.
- ./verilog/dv/ : includes all the simulation test benches and how to run them. 
- ./verilog/gl/ : includes all the synthesized/elaborated netlists. 
- ./verilog/rtl/ : includes all the Verilog RTLs and source files.
- ./openlane/`<macro>`/ : includes all configuration files used to run openlane on your project.
- info.yaml: includes all the info required in [this example](info.yaml). Please make sure that you are pointing to an elaborated caravel netlist as well as a synthesized gate-level-netlist for the user_project_wrapper

## Managment SoC
The managment SoC runs firmware that can be used to:
- Configure User Project I/O pads
- Observe and control User Project signals (through on-chip logic analyzer probes)
- Control the User Project power supply

The memory map of the management SoC can be found [here](verilog/rtl/README)

## User Project Area
This is the user space. It has limited silicon area (TBD, about 3.1mm x 3.8mm) as well as a fixed number of I/O pads (37) and power pads (10).  See [the Caravel  premliminary datasheet](doc/caravel_datasheet.pdf) for details.
The repository contains a [sample user project](/verilog/rtl/user_proj_example.v) that contains a binary 32-bit up counter.  </br>

<p align="center">
<img src="/doc/counter_32.png" width="50%" height="50%">
</p>

The firmware running on the Management Area SoC, configures the I/O pads used by the counter and uses the logic probes to observe/control the counter. Three firmware examples are provided:
1. Configure the User Project I/O pads as o/p. Observe the counter value in the testbench: [IO_Ports Test](verilog/dv/caravel/user_proj_example/io_ports).
2. Configure the User Project I/O pads as o/p. Use the Chip LA to load the counter and observe the o/p till it reaches 500: [LA_Test1](verilog/dv/caravel/user_proj_example/la_test1).
3. Configure the User Project I/O pads as o/p. Use the Chip LA to control the clock source and reset signals and observe the counter value for five clock cylcles:  [LA_Test2](verilog/dv/caravel/user_proj_example/la_test2).

[0]: openlane/README.md
[1]: mpw-one-b.md
