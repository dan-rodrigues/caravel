package require openlane
set script_dir [file dirname [file normalize [info script]]]

prep -design $script_dir -tag user_project_wrapper -overwrite
set save_path $script_dir/../..

verilog_elaborate

init_floorplan

place_io_ol

set ::env(FP_DEF_TEMPATE) $script_dir/../../def/user_project_wrapper_empty.def

apply_def_template

add_macro_placement mprj 800 800 N

manual_macro_placement f
exec -ignorestderr openroad -exit $script_dir/gen_pdn.tcl
set_def $::env(pdn_tmp_file_tag).def

global_routing_or
detailed_routing

# Required to get the .powered.lvs.v:
write_powered_verilog
set_netlist $::env(lvs_result_file_tag).powered.v

run_magic
run_magic_spice_export

save_views       -lef_path $::env(magic_result_file_tag).lef \
                 -def_path $::env(tritonRoute_result_file_tag).def \
                 -gds_path $::env(magic_result_file_tag).gds \
                 -mag_path $::env(magic_result_file_tag).mag \
		 -verilog_path $::env(CURRENT_NETLIST) \
                 -save_path $save_path \
                 -tag $::env(RUN_TAG)

run_magic_drc

run_lvs; # requires run_magic_spice_export

run_antenna_check
