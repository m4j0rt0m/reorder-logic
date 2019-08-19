# Automatically created by Makefile #
set project_name reorder_logic
if [catch {project_open reorder_logic}] {project_new reorder_logic}
set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0
set_global_assignment -name MAX_CORE_JUNCTION_TEMP 85
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name TOP_LEVEL_ENTITY reorder_logic
set_global_assignment -name DEVICE "EP4CE22F17C6"
set_global_assignment -name ERROR_CHECK_FREQUENCY_DIVISOR 256
set_global_assignment -name SOURCE_FILE /hdd/m4j0rt0m/Projects/Homeland/rtl_modules/reorder-logic/rtl/reorder_logic.v
set_global_assignment -name SDC_FILE /hdd/m4j0rt0m/Projects/Homeland/rtl_modules/reorder-logic/scripts/reorder_logic.sdc
project_close
qexit -success
