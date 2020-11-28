set script_dir [file dirname [file normalize [info script]]]

set ::env(DESIGN_NAME) vdp_lite_user_proj

set ::env(DESIGN_IS_CORE) 0
set ::env(FP_PDN_CORE_RING) 0
set ::env(GLB_RT_MAXLAYER) 5

set ::env(VERILOG_FILES) "\
    $script_dir/../../verilog/rtl/defines.v \
    $script_dir/../../verilog/rtl/user_project_wrapper.v \
    $script_dir/../../vdp/vdp.v \
    $script_dir/../../vdp/vdp_host_interface.v \
    $script_dir/../../vdp/vdp_vga_timing.v \
    $script_dir/../../vdp/vdp_sprite_core.v \
    $script_dir/../../vdp/vdp_sprite_raster_collision.v \
    $script_dir/../../vdp/vdp_vram_bus_arbiter_standard.v \
    $script_dir/../../vdp/vdp_sprite_render.v \
    $script_dir/../../vdp/vdp_priority_compute.v \
    $script_dir/../../vdp/vdp_layer_priority_select.v \
    $script_dir/../../vdp/ffram.v \
    $script_dir/../../vdp/delay_ff.v \
    $script_dir/../../vdp/delay_ffr.v \
    $script_dir/../../verilog/rtl/vdp_lite_user_proj/vdp_lite_user_proj.v \
    $script_dir/../../verilog/rtl/vdp_lite_user_proj/char_rom.v"

set ::env(VERILOG_INCLUDE_DIRS) "$script_dir/../../vdp/"

set ::env(CLOCK_PORT) "wb_clk_i"
set ::env(CLOCK_PERIOD) "39"

set ::env(FP_SIZING) absolute
set ::env(DIE_AREA) "0 0 1400 1100"
set ::env(PL_TARGET_DENSITY) 0.3

set ::env(DIODE_INSERTION_STRATEGY) 0

# Extra options:

set ::env(ROUTING_CORES) 6

# set ::env(GLB_RT_MAX_DIODE_INS_ITERS) 10

# Only for DFFRAM which is off by default:

#set ::env(VERILOG_FILES_BLACKBOX) "\
#	$script_dir/../../verilog/rtl/defines.v \
#	$script_dir/../../verilog/rtl/DFFRAM.v"

#set ::env(EXTRA_LEFS) "\
#	$script_dir/../../lef/DFFRAM.lef"
#set ::env(EXTRA_GDS_FILES) "\
#	$script_dir/../../gds/DFFRAM.gds"

