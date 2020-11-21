# Required config:

# Rename these accordingly
GCC_PREFIX=/Users/dan.rodrigues/opt/riscv-none-embed-gcc/8.3.0-1.1/bin/riscv-none-embed-
PDK_PATH?=/Users/dan.rodrigues/hw/sky130A

###

# Options:

WRITE_VCD ?= 0

# Enables $readmemh init of palette and sprite attribute memory
# Usually disabled even for iverilog runs
INIT_VIDEO_RAMS ?= 0

###

MK_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

# From Caravel Makefile:

FIRMWARE_PATH = $(MK_DIR)../..
RTL_PATH = $(MK_DIR)../../../../rtl
IP_PATH = $(MK_DIR)../../../../ip
BEHAVIOURAL_MODELS = $(MK_DIR)../../ 

### VDP user proj additions:

# Verilog:

VDP_USER_PROJ_DIR := $(MK_DIR)../../../../rtl/vdp_lite_user_proj/
VDP_SOURCES_DIR := $(MK_DIR)../../../../../vdp/

VDP_USER_PROJ_SOURCES := $(addprefix $(VDP_USER_PROJ_DIR), \
	vdp_lite_user_proj.v \
	char_rom.v \
)

VDP_RTL_SOURCES := $(addprefix $(VDP_SOURCES_DIR), \
	vdp.v \
	vdp_vga_timing.v \
	vdp_sprite_render.v \
	vdp_sprite_raster_collision.v \
	vdp_sprite_core.v \
	vdp_priority_compute.v \
	vdp_layer_priority_select.v \
	vdp_vram_bus_arbiter_standard.v \
	vdp_host_interface.v \
)

EXTRA_RTL_SOURCES := $(addprefix $(VDP_SOURCES_DIR), \
	ffram.v \
	delay_ff.v \
	delay_ffr.v \
)

RTL_INCLUDES := $(addprefix $(VDP_SOURCES_DIR), \
	debug.vh \
	layer_encoding.vh \
)

CHAR_ROMS := $(addprefix $(VDP_SOURCES_DIR), \
	reduce.hex \
)

ALL_RTL_DEPS := \
	$(VDP_RTL_SOURCES) \
	$(EXTRA_RTL_SOURCES) \
	$(RTL_INCLUDES) \
	$(VDP_USER_PROJ) \
	$(VDP_USER_PROJ_SOURCES)

###

# C:

CFLAGS := \
	--std=c11 \
	-march=rv32imc \
	-I$(MK_DIR)lib/ -I$(MK_DIR)software/ \
	-O3 -flto -funroll-loops

SW_LIB_DIR := $(MK_DIR)lib/
SW_LIB_SOURCES := $(addprefix $(SW_LIB_DIR), \
	vdp.c \
	gamepad.c \
	math_util.c \
	gpio.c \
)

SW_LIB_HEADERS := $(addprefix $(SW_LIB_DIR), \
	vdp.h \
	gamepad.h \
	math_util.h \
	gpio.h \
)

SW_DIR := $(MK_DIR)software/
SW_SOURCES := $(addprefix $(SW_DIR), \
	sprite_text_attributes.c \
)

###

# Includer additional sources:

EXTRA_RTL_SOURCES += $(TB_RTL_SOURCES)
SW_SOURCES += $(TB_SW_SOURCES)

###

# Optional RAM test files:

PALETTE_HEX := test_ram/palette.hex

SPR_X_HEX := test_ram/spr_x_block.hex
SPR_Y_HEX := test_ram/spr_y_block.hex
SPR_G_HEX := test_ram/spr_g_block.hex

# Video RAMs only initialized in sim

ifeq ($(INIT_VIDEO_RAMS), 1)

IVERILOG_PARAMS := -DINIT_PALETTE_RAM=\"test_ram/palette.hex\"

IVERILOG_PARAMS += -DINIT_SPRITE_X=\"$(SPR_X_HEX)\"
IVERILOG_PARAMS += -DINIT_SPRITE_Y=\"$(SPR_Y_HEX)\"
IVERILOG_PARAMS += -DINIT_SPRITE_G=\"$(SPR_G_HEX)\"

IVERILOG_PARAMS += -DINIT_VIDEO_RAMS

endif

ifeq ($(WRITE_VCD), 1)
IVERILOG_PARAMS += -DWRITE_VCD
endif

###

all: $(PROJ).vcd

$(PROJ).vvp: $(PROJ)_tb.v $(PROJ).hex $(ALL_RTL_DEPS) $(CHAR_ROMS)
	iverilog -DFUNCTIONAL -I $(BEHAVIOURAL_MODELS) \
	$(IVERILOG_PARAMS) \
	-I $(PDK_PATH) -I $(IP_PATH) -I $(RTL_PATH) \
	-I $(VDP_SOURCES_DIR) \
	-o $@ $< $(ALL_RTL_DEPS)

$(PROJ).vcd: $(PROJ).vvp
	vvp $<

$(PROJ).elf: $(FIRMWARE_PATH)/sections.lds $(FIRMWARE_PATH)/start.s $(SW_LIB_SOURCES) $(SW_LIB_HEADERS) $(SW_SOURCES)
	$(GCC_PREFIX)gcc $(CFLAGS) \
		-Wl,-Bstatic,-T,$(FIRMWARE_PATH)/sections.lds,--strip-debug -ffreestanding -nostdlib \
		-o $@ \
		$(FIRMWARE_PATH)/start.s $< $(SW_LIB_SOURCES) $(SW_SOURCES)

$(PROJ).hex: $(PROJ).elf
	$(GCC_PREFIX)objcopy -O verilog $< $@ 
	# TODO: confirm if this is still needed?
	# to fix flash base address
	gsed -i 's/@10000000/@00000000/g' $@

$(PROJ).bin: $(PROJ).elf
	$(GCC_PREFIX)objcopy -O binary $< /dev/stdout | tail -c +1048577 > $@

###

dasm: $(PROJ).elf
	$(GCC_PREFIX)objdump -d $(DFLAGS) $< > dasm

# ---- Clean ----

clean:
	rm -f *.elf $(PROJ).hex *.bin *.vvp *.vcd *.log

.PHONY: clean hex

.PRECIOUS: rgbs.log
