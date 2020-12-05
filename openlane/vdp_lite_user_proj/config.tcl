set script_dir [file dirname [file normalize [info script]]]
set vdp_rtl_dir "$script_dir/../../verilog/rtl/vdp_lite_user_proj/"

set ::env(DESIGN_NAME) vdp_lite_user_proj

set ::env(DESIGN_IS_CORE) 0
set ::env(FP_PDN_CORE_RING) 0
set ::env(GLB_RT_MAXLAYER) 5

set ::env(VERILOG_FILES) "\
    $script_dir/../../verilog/rtl/defines.v \
    $script_dir/../../verilog/rtl/user_project_wrapper.v \
    $vdp_rtl_dir/vdp.v \
    $vdp_rtl_dir/vdp_host_interface.v \
    $vdp_rtl_dir/vdp_vga_timing.v \
    $vdp_rtl_dir/vdp_sprite_core.v \
    $vdp_rtl_dir/vdp_sprite_raster_collision.v \
    $vdp_rtl_dir/vdp_vram_bus_arbiter_standard.v \
    $vdp_rtl_dir/vdp_sprite_render.v \
    $vdp_rtl_dir/vdp_priority_compute.v \
    $vdp_rtl_dir/vdp_layer_priority_select.v \
    $vdp_rtl_dir/ffram.v \
    $vdp_rtl_dir/delay_ff.v \
    $vdp_rtl_dir/delay_ffr.v \
    $vdp_rtl_dir/vdp_lite_user_proj.v \
    $vdp_rtl_dir/char_rom.v"

set ::env(VERILOG_INCLUDE_DIRS) "$vdp_rtl_dir/"

set ::env(CLOCK_PORT) "wb_clk_i"
set ::env(CLOCK_PERIOD) "39"

set ::env(FP_SIZING) absolute
set ::env(DIE_AREA) "0 0 1400 1100"
set ::env(PL_TARGET_DENSITY) 0.28

set ::env(DIODE_INSERTION_STRATEGY) 0

# Extra options:

set ::env(FP_PIN_ORDER_CFG) $script_dir/pin_order.cfg

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
