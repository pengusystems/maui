set script_name [file normalize [info script]]
set src_dir [file dirname $script_name]
set proj_name [file tail $src_dir]

# Create a project
open_project -reset proj_${proj_name}

# Add design files
add_files ${src_dir}/tx_if.cpp
add_files ${src_dir}/rx_if.cpp
add_files ${src_dir}/pulsed_radar.cpp

# Add test bench & files
add_files -tb ${src_dir}/pulsed_radar_tb.cpp

# Set the top-level function
set_top pulsed_radar_top

# Create a solution
open_solution -reset solution1
# Define technology and clock rate
set_part {xc7k160tfbg676-2}
create_clock -period 8.35

# Set any optimization directives
if { [file exists "${src_dir}/directives.tcl"] } {
  puts "  Sourcing directives.tcl...  "
  source "${src_dir}/directives.tcl"
}

csim_design

# Set to 1: to run setup and synthesis
# Set to 2: to run setup, synthesis and RTL simulation
# Set to 3: to run setup, synthesis, RTL simulation and RTL synthesis
# Any other value will run setup only
set hls_exec 1

if {$hls_exec == 1} {
        # Run Synthesis and Exit
        csynth_design

} elseif {$hls_exec == 2} {
        # Run Synthesis, RTL Simulation and Exit
        csynth_design

        cosim_design -rtl verilog
} elseif {$hls_exec == 3} {
        # Run Synthesis, RTL Simulation, RTL implementation and Exit
        csynth_design

        cosim_design -rtl verilog

        export_design
} else {
        # Default is to exit after setup
        csynth_design
}

exit

