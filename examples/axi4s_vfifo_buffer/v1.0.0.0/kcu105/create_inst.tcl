
################################################################
# This is a generated script based on design: design_1
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2020.1
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source design_1_script.tcl

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:xlconcat:2.1\
xilinx.com:ip:axis_dwidth_converter:1.1\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:ip:xlconstant:1.1\
xilinx.com:ip:axis_data_fifo:2.0\
xilinx.com:ip:axis_register_slice:1.1\
xilinx.com:ip:axi_vfifo_ctrl:2.0\
xilinx.com:ip:ddr4:2.2\
xilinx.com:ip:xlslice:1.0\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################


# Hierarchical cell: vfifo_ddr4_buffer
proc create_hier_cell_vfifo_ddr4_buffer { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_vfifo_ddr4_buffer() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 M_AXIS

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 ddr4_sdram

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 sys_clk_0


  # Create pins
  create_bd_pin -dir O c0_init_calib_complete_0
  create_bd_pin -dir O -from 0 -to 0 s2mm_full_0
  create_bd_pin -dir O -from 0 -to 0 s2mm_full_1
  create_bd_pin -dir O -from 0 -to 0 s2mm_full_2
  create_bd_pin -dir O -from 0 -to 0 s2mm_full_3
  create_bd_pin -dir I -type rst sys_rst_0
  create_bd_pin -dir I -type rst vfifo_aresetn
  create_bd_pin -dir I -type clk vfifo_clk
  create_bd_pin -dir I -from 3 -to 0 vfifo_mm2s_channel_full

  # Create instance: axi_interconnect_1, and set properties
  set axi_interconnect_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_1 ]
  set_property -dict [ list \
   CONFIG.NUM_MI {1} \
 ] $axi_interconnect_1

  # Create instance: axi_vfifo_ctrl_0, and set properties
  set axi_vfifo_ctrl_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_vfifo_ctrl:2.0 axi_vfifo_ctrl_0 ]
  set_property -dict [ list \
   CONFIG.ar_weight_ch0 {1} \
   CONFIG.ar_weight_ch1 {1} \
   CONFIG.ar_weight_ch2 {1} \
   CONFIG.ar_weight_ch3 {1} \
   CONFIG.axi_burst_size {4096} \
   CONFIG.axis_tdata_width {256} \
   CONFIG.number_of_channel {4} \
   CONFIG.number_of_page_ch0 {8192} \
   CONFIG.number_of_page_ch1 {8192} \
   CONFIG.number_of_page_ch2 {8192} \
   CONFIG.number_of_page_ch3 {8192} \
   CONFIG.number_of_page_ch4 {64} \
   CONFIG.number_of_page_ch5 {64} \
   CONFIG.number_of_page_ch6 {64} \
   CONFIG.number_of_page_ch7 {64} \
 ] $axi_vfifo_ctrl_0

  # Create instance: ddr4_0, and set properties
  set ddr4_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 ddr4_0 ]
  set_property -dict [ list \
   CONFIG.C0_DDR4_BOARD_INTERFACE {ddr4_sdram} \
 ] $ddr4_0

  # Create instance: proc_sys_reset_0, and set properties
  set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]

  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]

  # Create instance: xlslice_0, and set properties
  set xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0 ]
  set_property -dict [ list \
   CONFIG.DIN_WIDTH {4} \
 ] $xlslice_0

  # Create instance: xlslice_1, and set properties
  set xlslice_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_1 ]
  set_property -dict [ list \
   CONFIG.DIN_FROM {1} \
   CONFIG.DIN_TO {1} \
   CONFIG.DIN_WIDTH {4} \
 ] $xlslice_1

  # Create instance: xlslice_2, and set properties
  set xlslice_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_2 ]
  set_property -dict [ list \
   CONFIG.DIN_FROM {2} \
   CONFIG.DIN_TO {2} \
   CONFIG.DIN_WIDTH {4} \
   CONFIG.DOUT_WIDTH {1} \
 ] $xlslice_2

  # Create instance: xlslice_3, and set properties
  set xlslice_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_3 ]
  set_property -dict [ list \
   CONFIG.DIN_FROM {3} \
   CONFIG.DIN_TO {3} \
   CONFIG.DIN_WIDTH {4} \
 ] $xlslice_3

  # Create interface connections
  connect_bd_intf_net -intf_net C0_SYS_CLK_0_1 [get_bd_intf_pins sys_clk_0] [get_bd_intf_pins ddr4_0/C0_SYS_CLK]
  connect_bd_intf_net -intf_net axi_interconnect_1_M00_AXI [get_bd_intf_pins axi_interconnect_1/M00_AXI] [get_bd_intf_pins ddr4_0/C0_DDR4_S_AXI]
  connect_bd_intf_net -intf_net axi_vfifo_ctrl_0_M_AXI [get_bd_intf_pins axi_interconnect_1/S00_AXI] [get_bd_intf_pins axi_vfifo_ctrl_0/M_AXI]
  connect_bd_intf_net -intf_net axi_vfifo_ctrl_0_M_AXIS [get_bd_intf_pins M_AXIS] [get_bd_intf_pins axi_vfifo_ctrl_0/M_AXIS]
  connect_bd_intf_net -intf_net axis_interconnect_0_M00_AXIS [get_bd_intf_pins S_AXIS] [get_bd_intf_pins axi_vfifo_ctrl_0/S_AXIS]
  connect_bd_intf_net -intf_net ddr4_0_C0_DDR4 [get_bd_intf_pins ddr4_sdram] [get_bd_intf_pins ddr4_0/C0_DDR4]

  # Create port connections
  connect_bd_net -net M00_AXIS_ACLK_0_1 [get_bd_pins vfifo_clk] [get_bd_pins axi_interconnect_1/ACLK] [get_bd_pins axi_interconnect_1/S00_ACLK] [get_bd_pins axi_vfifo_ctrl_0/aclk]
  connect_bd_net -net Net2 [get_bd_pins axi_interconnect_1/M00_ACLK] [get_bd_pins ddr4_0/c0_ddr4_ui_clk] [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
  connect_bd_net -net axi_vfifo_ctrl_0_vfifo_s2mm_channel_full [get_bd_pins axi_vfifo_ctrl_0/vfifo_s2mm_channel_full] [get_bd_pins xlslice_0/Din] [get_bd_pins xlslice_1/Din] [get_bd_pins xlslice_2/Din] [get_bd_pins xlslice_3/Din]
  connect_bd_net -net ddr4_0_c0_ddr4_ui_clk_sync_rst [get_bd_pins ddr4_0/c0_ddr4_ui_clk_sync_rst] [get_bd_pins proc_sys_reset_0/ext_reset_in]
  connect_bd_net -net ddr4_0_c0_init_calib_complete [get_bd_pins c0_init_calib_complete_0] [get_bd_pins ddr4_0/c0_init_calib_complete]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn [get_bd_pins axi_interconnect_1/M00_ARESETN] [get_bd_pins ddr4_0/c0_ddr4_aresetn] [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
  connect_bd_net -net sys_rst_0_1 [get_bd_pins sys_rst_0] [get_bd_pins ddr4_0/sys_rst]
  connect_bd_net -net vfifo_aresetn [get_bd_pins vfifo_aresetn] [get_bd_pins axi_interconnect_1/ARESETN] [get_bd_pins axi_interconnect_1/S00_ARESETN] [get_bd_pins axi_vfifo_ctrl_0/aresetn]
  connect_bd_net -net vfifo_mm2s_channel_full_1 [get_bd_pins vfifo_mm2s_channel_full] [get_bd_pins axi_vfifo_ctrl_0/vfifo_mm2s_channel_full]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins proc_sys_reset_0/dcm_locked] [get_bd_pins xlconstant_0/dout]
  connect_bd_net -net xlslice_0_Dout [get_bd_pins s2mm_full_0] [get_bd_pins xlslice_0/Dout]
  connect_bd_net -net xlslice_1_Dout [get_bd_pins s2mm_full_1] [get_bd_pins xlslice_1/Dout]
  connect_bd_net -net xlslice_2_Dout [get_bd_pins s2mm_full_2] [get_bd_pins xlslice_2/Dout]
  connect_bd_net -net xlslice_3_Dout [get_bd_pins s2mm_full_3] [get_bd_pins xlslice_3/Dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: ch_output_3
proc create_hier_cell_ch_output_3 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_ch_output_3() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_3


  # Create pins
  create_bd_pin -dir O prog_full
  create_bd_pin -dir I -type rst vfifo_aresetn
  create_bd_pin -dir I -type clk vfifo_clk

  # Create instance: axis_data_fifo_3, and set properties
  set axis_data_fifo_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_data_fifo_3 ]
  set_property -dict [ list \
   CONFIG.FIFO_DEPTH {256} \
   CONFIG.FIFO_MODE {2} \
   CONFIG.HAS_PROG_FULL {1} \
   CONFIG.IS_ACLK_ASYNC {0} \
   CONFIG.PROG_FULL_THRESH {128} \
 ] $axis_data_fifo_3

  # Create instance: axis_register_slice_3, and set properties
  set axis_register_slice_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_3 ]

  # Create interface connections
  connect_bd_intf_net -intf_net axis_data_fifo_3_M_AXIS [get_bd_intf_pins axis_data_fifo_3/M_AXIS] [get_bd_intf_pins axis_register_slice_3/S_AXIS]
  connect_bd_intf_net -intf_net axis_demux_M03_AXIS [get_bd_intf_pins S_AXIS] [get_bd_intf_pins axis_data_fifo_3/S_AXIS]
  connect_bd_intf_net -intf_net axis_register_slice_3_M_AXIS [get_bd_intf_pins m_axis_3] [get_bd_intf_pins axis_register_slice_3/M_AXIS]

  # Create port connections
  connect_bd_net -net M00_AXIS_ACLK_0_1 [get_bd_pins vfifo_clk] [get_bd_pins axis_data_fifo_3/s_axis_aclk] [get_bd_pins axis_register_slice_3/aclk]
  connect_bd_net -net axis_data_fifo_3_prog_full [get_bd_pins prog_full] [get_bd_pins axis_data_fifo_3/prog_full]
  connect_bd_net -net vfifo_aresetn [get_bd_pins vfifo_aresetn] [get_bd_pins axis_data_fifo_3/s_axis_aresetn] [get_bd_pins axis_register_slice_3/aresetn]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: ch_output_2
proc create_hier_cell_ch_output_2 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_ch_output_2() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_2


  # Create pins
  create_bd_pin -dir O prog_full
  create_bd_pin -dir I -type rst vfifo_aresetn
  create_bd_pin -dir I -type clk vfifo_clk

  # Create instance: axis_data_fifo_2, and set properties
  set axis_data_fifo_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_data_fifo_2 ]
  set_property -dict [ list \
   CONFIG.FIFO_DEPTH {256} \
   CONFIG.FIFO_MODE {2} \
   CONFIG.HAS_PROG_FULL {1} \
   CONFIG.IS_ACLK_ASYNC {0} \
   CONFIG.PROG_FULL_THRESH {128} \
 ] $axis_data_fifo_2

  # Create instance: axis_register_slice_2, and set properties
  set axis_register_slice_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_2 ]

  # Create interface connections
  connect_bd_intf_net -intf_net axis_data_fifo_2_M_AXIS [get_bd_intf_pins axis_data_fifo_2/M_AXIS] [get_bd_intf_pins axis_register_slice_2/S_AXIS]
  connect_bd_intf_net -intf_net axis_demux_M02_AXIS [get_bd_intf_pins S_AXIS] [get_bd_intf_pins axis_data_fifo_2/S_AXIS]
  connect_bd_intf_net -intf_net axis_register_slice_2_M_AXIS [get_bd_intf_pins m_axis_2] [get_bd_intf_pins axis_register_slice_2/M_AXIS]

  # Create port connections
  connect_bd_net -net M00_AXIS_ACLK_0_1 [get_bd_pins vfifo_clk] [get_bd_pins axis_data_fifo_2/s_axis_aclk] [get_bd_pins axis_register_slice_2/aclk]
  connect_bd_net -net axis_data_fifo_2_prog_full [get_bd_pins prog_full] [get_bd_pins axis_data_fifo_2/prog_full]
  connect_bd_net -net vfifo_aresetn [get_bd_pins vfifo_aresetn] [get_bd_pins axis_data_fifo_2/s_axis_aresetn] [get_bd_pins axis_register_slice_2/aresetn]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: ch_output_1
proc create_hier_cell_ch_output_1 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_ch_output_1() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_1


  # Create pins
  create_bd_pin -dir O prog_full
  create_bd_pin -dir I -type rst vfifo_aresetn
  create_bd_pin -dir I -type clk vfifo_clk

  # Create instance: axis_data_fifo_1, and set properties
  set axis_data_fifo_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_data_fifo_1 ]
  set_property -dict [ list \
   CONFIG.FIFO_DEPTH {256} \
   CONFIG.FIFO_MODE {2} \
   CONFIG.HAS_PROG_FULL {1} \
   CONFIG.IS_ACLK_ASYNC {0} \
   CONFIG.PROG_FULL_THRESH {128} \
 ] $axis_data_fifo_1

  # Create instance: axis_register_slice_1, and set properties
  set axis_register_slice_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_1 ]

  # Create interface connections
  connect_bd_intf_net -intf_net axis_data_fifo_1_M_AXIS [get_bd_intf_pins axis_data_fifo_1/M_AXIS] [get_bd_intf_pins axis_register_slice_1/S_AXIS]
  connect_bd_intf_net -intf_net axis_demux_M01_AXIS [get_bd_intf_pins S_AXIS] [get_bd_intf_pins axis_data_fifo_1/S_AXIS]
  connect_bd_intf_net -intf_net axis_register_slice_1_M_AXIS [get_bd_intf_pins m_axis_1] [get_bd_intf_pins axis_register_slice_1/M_AXIS]

  # Create port connections
  connect_bd_net -net M00_AXIS_ACLK_0_1 [get_bd_pins vfifo_clk] [get_bd_pins axis_data_fifo_1/s_axis_aclk] [get_bd_pins axis_register_slice_1/aclk]
  connect_bd_net -net axis_data_fifo_1_prog_full [get_bd_pins prog_full] [get_bd_pins axis_data_fifo_1/prog_full]
  connect_bd_net -net vfifo_aresetn [get_bd_pins vfifo_aresetn] [get_bd_pins axis_data_fifo_1/s_axis_aresetn] [get_bd_pins axis_register_slice_1/aresetn]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: ch_output_0
proc create_hier_cell_ch_output_0 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_ch_output_0() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_0


  # Create pins
  create_bd_pin -dir O prog_full
  create_bd_pin -dir I -type rst vfifo_aresetn
  create_bd_pin -dir I -type clk vfifo_clk

  # Create instance: axis_data_fifo_0, and set properties
  set axis_data_fifo_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_data_fifo:2.0 axis_data_fifo_0 ]
  set_property -dict [ list \
   CONFIG.FIFO_DEPTH {256} \
   CONFIG.FIFO_MODE {2} \
   CONFIG.HAS_PROG_FULL {1} \
   CONFIG.IS_ACLK_ASYNC {0} \
   CONFIG.PROG_FULL_THRESH {128} \
 ] $axis_data_fifo_0

  # Create instance: axis_register_slice_0, and set properties
  set axis_register_slice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_register_slice:1.1 axis_register_slice_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net axis_data_fifo_0_M_AXIS [get_bd_intf_pins axis_data_fifo_0/M_AXIS] [get_bd_intf_pins axis_register_slice_0/S_AXIS]
  connect_bd_intf_net -intf_net axis_demux_M00_AXIS [get_bd_intf_pins S_AXIS] [get_bd_intf_pins axis_data_fifo_0/S_AXIS]
  connect_bd_intf_net -intf_net axis_register_slice_0_M_AXIS [get_bd_intf_pins m_axis_0] [get_bd_intf_pins axis_register_slice_0/M_AXIS]

  # Create port connections
  connect_bd_net -net M00_AXIS_ACLK_0_1 [get_bd_pins vfifo_clk] [get_bd_pins axis_data_fifo_0/s_axis_aclk] [get_bd_pins axis_register_slice_0/aclk]
  connect_bd_net -net axis_data_fifo_0_prog_full [get_bd_pins prog_full] [get_bd_pins axis_data_fifo_0/prog_full]
  connect_bd_net -net vfifo_aresetn [get_bd_pins vfifo_aresetn] [get_bd_pins axis_data_fifo_0/s_axis_aresetn] [get_bd_pins axis_register_slice_0/aresetn]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: ch_cond_3
proc create_hier_cell_ch_cond_3 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_ch_cond_3() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 M00_AXIS

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s03_axis_axi4s_vfifo_buffer


  # Create pins
  create_bd_pin -dir I -type rst aresetn_3
  create_bd_pin -dir I -type clk data_clk_3
  create_bd_pin -dir I -type rst vfifo_aresetn
  create_bd_pin -dir I -type clk vfifo_clk

  # Create instance: axis_dwidth_converter_3, and set properties
  set axis_dwidth_converter_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter:1.1 axis_dwidth_converter_3 ]
  set_property -dict [ list \
   CONFIG.M_TDATA_NUM_BYTES {32} \
 ] $axis_dwidth_converter_3

  # Create instance: clk_converter_w_fifos_3, and set properties
  set clk_converter_w_fifos_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_interconnect:2.1 clk_converter_w_fifos_3 ]
  set_property -dict [ list \
   CONFIG.M00_AXIS_BASETDEST {0x00000003} \
   CONFIG.M00_AXIS_HIGHTDEST {0x00000003} \
   CONFIG.M00_FIFO_DEPTH {1024} \
   CONFIG.M00_FIFO_MODE {1} \
   CONFIG.NUM_MI {1} \
   CONFIG.S00_FIFO_DEPTH {1024} \
   CONFIG.S00_FIFO_MODE {1} \
 ] $clk_converter_w_fifos_3

  # Create instance: proc_sys_reset_0, and set properties
  set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]

  # Create instance: proc_sys_reset_1, and set properties
  set proc_sys_reset_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_1 ]

  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net S00_AXIS_3 [get_bd_intf_pins axis_dwidth_converter_3/M_AXIS] [get_bd_intf_pins clk_converter_w_fifos_3/S00_AXIS]
  connect_bd_intf_net -intf_net S03_AXIS_0_1 [get_bd_intf_pins s03_axis_axi4s_vfifo_buffer] [get_bd_intf_pins axis_dwidth_converter_3/S_AXIS]
  connect_bd_intf_net -intf_net width_converter_w_mfifo_3_M00_AXIS [get_bd_intf_pins M00_AXIS] [get_bd_intf_pins clk_converter_w_fifos_3/M00_AXIS]

  # Create port connections
  connect_bd_net -net M00_AXIS_ACLK_0_1 [get_bd_pins vfifo_clk] [get_bd_pins clk_converter_w_fifos_3/ACLK] [get_bd_pins clk_converter_w_fifos_3/M00_AXIS_ACLK] [get_bd_pins proc_sys_reset_1/slowest_sync_clk]
  connect_bd_net -net aresetn_3_1 [get_bd_pins aresetn_3] [get_bd_pins proc_sys_reset_0/ext_reset_in] [get_bd_pins proc_sys_reset_1/ext_reset_in]
  connect_bd_net -net data_clk_3_1 [get_bd_pins data_clk_3] [get_bd_pins axis_dwidth_converter_3/aclk] [get_bd_pins clk_converter_w_fifos_3/S00_AXIS_ACLK] [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn [get_bd_pins axis_dwidth_converter_3/aresetn] [get_bd_pins clk_converter_w_fifos_3/S00_AXIS_ARESETN] [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
  connect_bd_net -net proc_sys_reset_1_peripheral_aresetn [get_bd_pins clk_converter_w_fifos_3/M00_AXIS_ARESETN] [get_bd_pins proc_sys_reset_1/peripheral_aresetn]
  connect_bd_net -net vfifo_aresetn [get_bd_pins vfifo_aresetn] [get_bd_pins clk_converter_w_fifos_3/ARESETN]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins proc_sys_reset_0/dcm_locked] [get_bd_pins proc_sys_reset_1/dcm_locked] [get_bd_pins xlconstant_0/dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: ch_cond_2
proc create_hier_cell_ch_cond_2 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_ch_cond_2() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 M00_AXIS

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s02_axis_axi4s_vfifo_buffer


  # Create pins
  create_bd_pin -dir I -type rst aresetn_2
  create_bd_pin -dir I -type clk data_clk_2
  create_bd_pin -dir I -type rst vfifo_aresetn
  create_bd_pin -dir I -type clk vfifo_clk

  # Create instance: axis_dwidth_converter_2, and set properties
  set axis_dwidth_converter_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter:1.1 axis_dwidth_converter_2 ]
  set_property -dict [ list \
   CONFIG.M_TDATA_NUM_BYTES {32} \
 ] $axis_dwidth_converter_2

  # Create instance: clk_converter_w_fifos_2, and set properties
  set clk_converter_w_fifos_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_interconnect:2.1 clk_converter_w_fifos_2 ]
  set_property -dict [ list \
   CONFIG.M00_AXIS_BASETDEST {0x00000002} \
   CONFIG.M00_AXIS_HIGHTDEST {0x00000002} \
   CONFIG.M00_FIFO_DEPTH {1024} \
   CONFIG.M00_FIFO_MODE {1} \
   CONFIG.NUM_MI {1} \
   CONFIG.S00_FIFO_DEPTH {1024} \
   CONFIG.S00_FIFO_MODE {1} \
 ] $clk_converter_w_fifos_2

  # Create instance: proc_sys_reset_0, and set properties
  set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]

  # Create instance: proc_sys_reset_1, and set properties
  set proc_sys_reset_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_1 ]

  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net S02_AXIS_0_1 [get_bd_intf_pins s02_axis_axi4s_vfifo_buffer] [get_bd_intf_pins axis_dwidth_converter_2/S_AXIS]
  connect_bd_intf_net -intf_net axis_dwidth_converter_2_M_AXIS [get_bd_intf_pins axis_dwidth_converter_2/M_AXIS] [get_bd_intf_pins clk_converter_w_fifos_2/S00_AXIS]
  connect_bd_intf_net -intf_net width_converter_w_mfifo_2_M00_AXIS [get_bd_intf_pins M00_AXIS] [get_bd_intf_pins clk_converter_w_fifos_2/M00_AXIS]

  # Create port connections
  connect_bd_net -net M00_AXIS_ACLK_0_1 [get_bd_pins vfifo_clk] [get_bd_pins clk_converter_w_fifos_2/ACLK] [get_bd_pins clk_converter_w_fifos_2/M00_AXIS_ACLK] [get_bd_pins proc_sys_reset_1/slowest_sync_clk]
  connect_bd_net -net aresetn_2_1 [get_bd_pins aresetn_2] [get_bd_pins proc_sys_reset_0/ext_reset_in] [get_bd_pins proc_sys_reset_1/ext_reset_in]
  connect_bd_net -net data_clk_2_1 [get_bd_pins data_clk_2] [get_bd_pins axis_dwidth_converter_2/aclk] [get_bd_pins clk_converter_w_fifos_2/S00_AXIS_ACLK] [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn [get_bd_pins axis_dwidth_converter_2/aresetn] [get_bd_pins clk_converter_w_fifos_2/S00_AXIS_ARESETN] [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
  connect_bd_net -net proc_sys_reset_1_peripheral_aresetn [get_bd_pins clk_converter_w_fifos_2/M00_AXIS_ARESETN] [get_bd_pins proc_sys_reset_1/peripheral_aresetn]
  connect_bd_net -net vfifo_aresetn [get_bd_pins vfifo_aresetn] [get_bd_pins clk_converter_w_fifos_2/ARESETN]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins proc_sys_reset_0/dcm_locked] [get_bd_pins proc_sys_reset_1/dcm_locked] [get_bd_pins xlconstant_0/dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: ch_cond_1
proc create_hier_cell_ch_cond_1 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_ch_cond_1() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 M00_AXIS

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s01_axis_axi4s_vfifo_buffer


  # Create pins
  create_bd_pin -dir I -type rst aresetn_1
  create_bd_pin -dir I -type clk data_clk_1
  create_bd_pin -dir I -type rst vfifo_aresetn
  create_bd_pin -dir I -type clk vfifo_clk

  # Create instance: axis_dwidth_converter_1, and set properties
  set axis_dwidth_converter_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter:1.1 axis_dwidth_converter_1 ]
  set_property -dict [ list \
   CONFIG.M_TDATA_NUM_BYTES {32} \
 ] $axis_dwidth_converter_1

  # Create instance: clk_converter_w_fifos_1, and set properties
  set clk_converter_w_fifos_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_interconnect:2.1 clk_converter_w_fifos_1 ]
  set_property -dict [ list \
   CONFIG.M00_AXIS_BASETDEST {0x00000001} \
   CONFIG.M00_AXIS_HIGHTDEST {0x00000001} \
   CONFIG.M00_FIFO_DEPTH {1024} \
   CONFIG.M00_FIFO_MODE {1} \
   CONFIG.NUM_MI {1} \
   CONFIG.S00_FIFO_DEPTH {1024} \
   CONFIG.S00_FIFO_MODE {1} \
 ] $clk_converter_w_fifos_1

  # Create instance: proc_sys_reset_0, and set properties
  set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]

  # Create instance: proc_sys_reset_1, and set properties
  set proc_sys_reset_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_1 ]

  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net S01_AXIS_1 [get_bd_intf_pins s01_axis_axi4s_vfifo_buffer] [get_bd_intf_pins axis_dwidth_converter_1/S_AXIS]
  connect_bd_intf_net -intf_net axis_dwidth_converter_1_M_AXIS [get_bd_intf_pins axis_dwidth_converter_1/M_AXIS] [get_bd_intf_pins clk_converter_w_fifos_1/S00_AXIS]
  connect_bd_intf_net -intf_net width_converter_w_mfifo_1_M00_AXIS [get_bd_intf_pins M00_AXIS] [get_bd_intf_pins clk_converter_w_fifos_1/M00_AXIS]

  # Create port connections
  connect_bd_net -net M00_AXIS_ACLK_0_1 [get_bd_pins vfifo_clk] [get_bd_pins clk_converter_w_fifos_1/ACLK] [get_bd_pins clk_converter_w_fifos_1/M00_AXIS_ACLK] [get_bd_pins proc_sys_reset_1/slowest_sync_clk]
  connect_bd_net -net aresetn_1_1 [get_bd_pins aresetn_1] [get_bd_pins proc_sys_reset_0/ext_reset_in] [get_bd_pins proc_sys_reset_1/ext_reset_in]
  connect_bd_net -net data_clk_1_1 [get_bd_pins data_clk_1] [get_bd_pins axis_dwidth_converter_1/aclk] [get_bd_pins clk_converter_w_fifos_1/S00_AXIS_ACLK] [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn [get_bd_pins axis_dwidth_converter_1/aresetn] [get_bd_pins clk_converter_w_fifos_1/S00_AXIS_ARESETN] [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
  connect_bd_net -net proc_sys_reset_1_peripheral_aresetn [get_bd_pins clk_converter_w_fifos_1/M00_AXIS_ARESETN] [get_bd_pins proc_sys_reset_1/peripheral_aresetn]
  connect_bd_net -net vfifo_aresetn [get_bd_pins vfifo_aresetn] [get_bd_pins clk_converter_w_fifos_1/ARESETN]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins proc_sys_reset_0/dcm_locked] [get_bd_pins proc_sys_reset_1/dcm_locked] [get_bd_pins xlconstant_0/dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: ch_cond_0
proc create_hier_cell_ch_cond_0 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_ch_cond_0() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 M00_AXIS

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s00_axis_axi4s_vfifo_buffer


  # Create pins
  create_bd_pin -dir I -type rst aresetn_0
  create_bd_pin -dir I -type clk data_clk_0
  create_bd_pin -dir I -type rst vfifo_aresetn
  create_bd_pin -dir I -type clk vfifo_clk

  # Create instance: axis_dwidth_converter_0, and set properties
  set axis_dwidth_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_dwidth_converter:1.1 axis_dwidth_converter_0 ]
  set_property -dict [ list \
   CONFIG.M_TDATA_NUM_BYTES {32} \
 ] $axis_dwidth_converter_0

  # Create instance: clk_converter_w_fifos_0, and set properties
  set clk_converter_w_fifos_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_interconnect:2.1 clk_converter_w_fifos_0 ]
  set_property -dict [ list \
   CONFIG.M00_FIFO_DEPTH {1024} \
   CONFIG.M00_FIFO_MODE {1} \
   CONFIG.NUM_MI {1} \
   CONFIG.S00_FIFO_DEPTH {1024} \
   CONFIG.S00_FIFO_MODE {1} \
 ] $clk_converter_w_fifos_0

  # Create instance: proc_sys_reset_0, and set properties
  set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]

  # Create instance: proc_sys_reset_1, and set properties
  set proc_sys_reset_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_1 ]

  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net S00_AXIS_1 [get_bd_intf_pins s00_axis_axi4s_vfifo_buffer] [get_bd_intf_pins axis_dwidth_converter_0/S_AXIS]
  connect_bd_intf_net -intf_net S00_AXIS_2 [get_bd_intf_pins axis_dwidth_converter_0/M_AXIS] [get_bd_intf_pins clk_converter_w_fifos_0/S00_AXIS]
  connect_bd_intf_net -intf_net width_converter_w_mfifo_0_M00_AXIS [get_bd_intf_pins M00_AXIS] [get_bd_intf_pins clk_converter_w_fifos_0/M00_AXIS]

  # Create port connections
  connect_bd_net -net M00_AXIS_ACLK_0_1 [get_bd_pins vfifo_clk] [get_bd_pins clk_converter_w_fifos_0/ACLK] [get_bd_pins clk_converter_w_fifos_0/M00_AXIS_ACLK] [get_bd_pins proc_sys_reset_1/slowest_sync_clk]
  connect_bd_net -net aresetn_0_1 [get_bd_pins aresetn_0] [get_bd_pins proc_sys_reset_0/ext_reset_in] [get_bd_pins proc_sys_reset_1/ext_reset_in]
  connect_bd_net -net data_clk_0_1 [get_bd_pins data_clk_0] [get_bd_pins axis_dwidth_converter_0/aclk] [get_bd_pins clk_converter_w_fifos_0/S00_AXIS_ACLK] [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn [get_bd_pins axis_dwidth_converter_0/aresetn] [get_bd_pins clk_converter_w_fifos_0/S00_AXIS_ARESETN] [get_bd_pins proc_sys_reset_0/peripheral_aresetn]
  connect_bd_net -net proc_sys_reset_1_peripheral_aresetn [get_bd_pins clk_converter_w_fifos_0/M00_AXIS_ARESETN] [get_bd_pins proc_sys_reset_1/peripheral_aresetn]
  connect_bd_net -net vfifo_aresetn [get_bd_pins vfifo_aresetn] [get_bd_pins clk_converter_w_fifos_0/ARESETN]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins proc_sys_reset_0/dcm_locked] [get_bd_pins proc_sys_reset_1/dcm_locked] [get_bd_pins xlconstant_0/dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: axi4s_vfifo_buffer_0
proc create_hier_cell_axi4s_vfifo_buffer_0 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_axi4s_vfifo_buffer_0() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:ddr4_rtl:1.0 ddr4_sdram

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_1

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_2

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis_3

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 mig_clk

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s00_axis

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s01_axis

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s02_axis

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 s03_axis


  # Create pins
  create_bd_pin -dir I -type rst aresetn_0
  create_bd_pin -dir I -type rst aresetn_1
  create_bd_pin -dir I -type rst aresetn_2
  create_bd_pin -dir I -type rst aresetn_3
  create_bd_pin -dir I -type clk data_clk_0
  create_bd_pin -dir I -type clk data_clk_1
  create_bd_pin -dir I -type clk data_clk_2
  create_bd_pin -dir I -type clk data_clk_3
  create_bd_pin -dir O mig_init_calib_complete
  create_bd_pin -dir I -type rst mig_rst
  create_bd_pin -dir I -type rst vfifo_aresetn
  create_bd_pin -dir I -type clk vfifo_clk

  # Create instance: axis_demux, and set properties
  set axis_demux [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_interconnect:2.1 axis_demux ]
  set_property -dict [ list \
   CONFIG.ARB_ON_TLAST {0} \
   CONFIG.NUM_MI {4} \
 ] $axis_demux

  # Create instance: axis_mux, and set properties
  set axis_mux [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_interconnect:2.1 axis_mux ]
  set_property -dict [ list \
   CONFIG.ARB_ALGORITHM {3} \
   CONFIG.ARB_ON_MAX_XFERS {128} \
   CONFIG.ARB_ON_NUM_CYCLES {0} \
   CONFIG.ARB_ON_TLAST {0} \
   CONFIG.M00_AXIS_HIGHTDEST {0x00000003} \
   CONFIG.M00_FIFO_DEPTH {0} \
   CONFIG.M00_FIFO_MODE {0} \
   CONFIG.M00_HAS_REGSLICE {0} \
   CONFIG.NUM_MI {1} \
   CONFIG.NUM_SI {4} \
   CONFIG.S00_FIFO_DEPTH {0} \
   CONFIG.S00_FIFO_MODE {0} \
   CONFIG.S00_HAS_REGSLICE {0} \
   CONFIG.S01_FIFO_DEPTH {0} \
   CONFIG.S01_FIFO_MODE {0} \
   CONFIG.S01_HAS_REGSLICE {0} \
   CONFIG.S02_FIFO_DEPTH {0} \
   CONFIG.S02_FIFO_MODE {0} \
   CONFIG.S02_HAS_REGSLICE {0} \
   CONFIG.S03_FIFO_DEPTH {0} \
   CONFIG.S03_FIFO_MODE {0} \
   CONFIG.S03_HAS_REGSLICE {0} \
 ] $axis_mux

  # Create instance: ch_cond_0
  create_hier_cell_ch_cond_0 $hier_obj ch_cond_0

  # Create instance: ch_cond_1
  create_hier_cell_ch_cond_1 $hier_obj ch_cond_1

  # Create instance: ch_cond_2
  create_hier_cell_ch_cond_2 $hier_obj ch_cond_2

  # Create instance: ch_cond_3
  create_hier_cell_ch_cond_3 $hier_obj ch_cond_3

  # Create instance: ch_output_0
  create_hier_cell_ch_output_0 $hier_obj ch_output_0

  # Create instance: ch_output_1
  create_hier_cell_ch_output_1 $hier_obj ch_output_1

  # Create instance: ch_output_2
  create_hier_cell_ch_output_2 $hier_obj ch_output_2

  # Create instance: ch_output_3
  create_hier_cell_ch_output_3 $hier_obj ch_output_3

  # Create instance: vfifo_ddr4_buffer
  create_hier_cell_vfifo_ddr4_buffer $hier_obj vfifo_ddr4_buffer

  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
  set_property -dict [ list \
   CONFIG.NUM_PORTS {4} \
 ] $xlconcat_0

  # Create interface connections
  connect_bd_intf_net -intf_net C0_SYS_CLK_0_1 [get_bd_intf_pins mig_clk] [get_bd_intf_pins vfifo_ddr4_buffer/sys_clk_0]
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins m_axis_0] [get_bd_intf_pins ch_output_0/m_axis_0]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins m_axis_1] [get_bd_intf_pins ch_output_1/m_axis_1]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins m_axis_2] [get_bd_intf_pins ch_output_2/m_axis_2]
  connect_bd_intf_net -intf_net Conn4 [get_bd_intf_pins m_axis_3] [get_bd_intf_pins ch_output_3/m_axis_3]
  connect_bd_intf_net -intf_net S00_AXIS_1 [get_bd_intf_pins s00_axis] [get_bd_intf_pins ch_cond_0/s00_axis_axi4s_vfifo_buffer]
  connect_bd_intf_net -intf_net S01_AXIS_1 [get_bd_intf_pins s01_axis] [get_bd_intf_pins ch_cond_1/s01_axis_axi4s_vfifo_buffer]
  connect_bd_intf_net -intf_net S02_AXIS_0_1 [get_bd_intf_pins s02_axis] [get_bd_intf_pins ch_cond_2/s02_axis_axi4s_vfifo_buffer]
  connect_bd_intf_net -intf_net S03_AXIS_0_1 [get_bd_intf_pins s03_axis] [get_bd_intf_pins ch_cond_3/s03_axis_axi4s_vfifo_buffer]
  connect_bd_intf_net -intf_net axis_demux_M00_AXIS [get_bd_intf_pins axis_demux/M00_AXIS] [get_bd_intf_pins ch_output_0/S_AXIS]
  connect_bd_intf_net -intf_net axis_demux_M01_AXIS [get_bd_intf_pins axis_demux/M01_AXIS] [get_bd_intf_pins ch_output_1/S_AXIS]
  connect_bd_intf_net -intf_net axis_demux_M02_AXIS [get_bd_intf_pins axis_demux/M02_AXIS] [get_bd_intf_pins ch_output_2/S_AXIS]
  connect_bd_intf_net -intf_net axis_demux_M03_AXIS [get_bd_intf_pins axis_demux/M03_AXIS] [get_bd_intf_pins ch_output_3/S_AXIS]
  connect_bd_intf_net -intf_net axis_interconnect_0_M00_AXIS [get_bd_intf_pins axis_mux/M00_AXIS] [get_bd_intf_pins vfifo_ddr4_buffer/S_AXIS]
  connect_bd_intf_net -intf_net ddr4_0_C0_DDR4 [get_bd_intf_pins ddr4_sdram] [get_bd_intf_pins vfifo_ddr4_buffer/ddr4_sdram]
  connect_bd_intf_net -intf_net vfifo_ddr4_buffer_M_AXIS [get_bd_intf_pins axis_demux/S00_AXIS] [get_bd_intf_pins vfifo_ddr4_buffer/M_AXIS]
  connect_bd_intf_net -intf_net width_converter_w_mfifo_0_M00_AXIS [get_bd_intf_pins axis_mux/S00_AXIS] [get_bd_intf_pins ch_cond_0/M00_AXIS]
  connect_bd_intf_net -intf_net width_converter_w_mfifo_1_M00_AXIS [get_bd_intf_pins axis_mux/S01_AXIS] [get_bd_intf_pins ch_cond_1/M00_AXIS]
  connect_bd_intf_net -intf_net width_converter_w_mfifo_2_M00_AXIS [get_bd_intf_pins axis_mux/S02_AXIS] [get_bd_intf_pins ch_cond_2/M00_AXIS]
  connect_bd_intf_net -intf_net width_converter_w_mfifo_3_M00_AXIS [get_bd_intf_pins axis_mux/S03_AXIS] [get_bd_intf_pins ch_cond_3/M00_AXIS]

  # Create port connections
  connect_bd_net -net M00_AXIS_ACLK_0_1 [get_bd_pins vfifo_clk] [get_bd_pins axis_demux/ACLK] [get_bd_pins axis_demux/M00_AXIS_ACLK] [get_bd_pins axis_demux/M01_AXIS_ACLK] [get_bd_pins axis_demux/M02_AXIS_ACLK] [get_bd_pins axis_demux/M03_AXIS_ACLK] [get_bd_pins axis_demux/S00_AXIS_ACLK] [get_bd_pins axis_mux/ACLK] [get_bd_pins axis_mux/M00_AXIS_ACLK] [get_bd_pins axis_mux/S00_AXIS_ACLK] [get_bd_pins axis_mux/S01_AXIS_ACLK] [get_bd_pins axis_mux/S02_AXIS_ACLK] [get_bd_pins axis_mux/S03_AXIS_ACLK] [get_bd_pins ch_cond_0/vfifo_clk] [get_bd_pins ch_cond_1/vfifo_clk] [get_bd_pins ch_cond_2/vfifo_clk] [get_bd_pins ch_cond_3/vfifo_clk] [get_bd_pins ch_output_0/vfifo_clk] [get_bd_pins ch_output_1/vfifo_clk] [get_bd_pins ch_output_2/vfifo_clk] [get_bd_pins ch_output_3/vfifo_clk] [get_bd_pins vfifo_ddr4_buffer/vfifo_clk]
  connect_bd_net -net S00_ARB_REQ_SUPPRESS_1 [get_bd_pins axis_mux/S00_ARB_REQ_SUPPRESS] [get_bd_pins vfifo_ddr4_buffer/s2mm_full_0]
  connect_bd_net -net S00_AXIS_ARESETN_1 [get_bd_pins aresetn_2] [get_bd_pins ch_cond_2/aresetn_2]
  connect_bd_net -net S00_AXIS_ARESETN_2 [get_bd_pins aresetn_3] [get_bd_pins ch_cond_3/aresetn_3]
  connect_bd_net -net S00_AXIS_ARESETN_3 [get_bd_pins aresetn_1] [get_bd_pins ch_cond_1/aresetn_1]
  connect_bd_net -net S00_AXIS_ARESETN_4 [get_bd_pins aresetn_0] [get_bd_pins ch_cond_0/aresetn_0]
  connect_bd_net -net S01_ARB_REQ_SUPPRESS_1 [get_bd_pins axis_mux/S01_ARB_REQ_SUPPRESS] [get_bd_pins vfifo_ddr4_buffer/s2mm_full_1]
  connect_bd_net -net S02_ARB_REQ_SUPPRESS_1 [get_bd_pins axis_mux/S02_ARB_REQ_SUPPRESS] [get_bd_pins vfifo_ddr4_buffer/s2mm_full_2]
  connect_bd_net -net S03_ARB_REQ_SUPPRESS_1 [get_bd_pins axis_mux/S03_ARB_REQ_SUPPRESS] [get_bd_pins vfifo_ddr4_buffer/s2mm_full_3]
  connect_bd_net -net axis_data_fifo_0_prog_full [get_bd_pins ch_output_0/prog_full] [get_bd_pins xlconcat_0/In0]
  connect_bd_net -net axis_data_fifo_1_prog_full [get_bd_pins ch_output_1/prog_full] [get_bd_pins xlconcat_0/In1]
  connect_bd_net -net axis_data_fifo_2_prog_full [get_bd_pins ch_output_2/prog_full] [get_bd_pins xlconcat_0/In2]
  connect_bd_net -net axis_data_fifo_3_prog_full [get_bd_pins ch_output_3/prog_full] [get_bd_pins xlconcat_0/In3]
  connect_bd_net -net data_clk_0_1 [get_bd_pins data_clk_0] [get_bd_pins ch_cond_0/data_clk_0]
  connect_bd_net -net data_clk_1_1 [get_bd_pins data_clk_1] [get_bd_pins ch_cond_1/data_clk_1]
  connect_bd_net -net data_clk_2_1 [get_bd_pins data_clk_2] [get_bd_pins ch_cond_2/data_clk_2]
  connect_bd_net -net data_clk_3_1 [get_bd_pins data_clk_3] [get_bd_pins ch_cond_3/data_clk_3]
  connect_bd_net -net sys_rst_0_1 [get_bd_pins mig_rst] [get_bd_pins vfifo_ddr4_buffer/sys_rst_0]
  connect_bd_net -net vfifo_aresetn [get_bd_pins vfifo_aresetn] [get_bd_pins axis_demux/ARESETN] [get_bd_pins axis_demux/M00_AXIS_ARESETN] [get_bd_pins axis_demux/M01_AXIS_ARESETN] [get_bd_pins axis_demux/M02_AXIS_ARESETN] [get_bd_pins axis_demux/M03_AXIS_ARESETN] [get_bd_pins axis_demux/S00_AXIS_ARESETN] [get_bd_pins axis_mux/ARESETN] [get_bd_pins axis_mux/M00_AXIS_ARESETN] [get_bd_pins axis_mux/S00_AXIS_ARESETN] [get_bd_pins axis_mux/S01_AXIS_ARESETN] [get_bd_pins axis_mux/S02_AXIS_ARESETN] [get_bd_pins axis_mux/S03_AXIS_ARESETN] [get_bd_pins ch_cond_0/vfifo_aresetn] [get_bd_pins ch_cond_1/vfifo_aresetn] [get_bd_pins ch_cond_2/vfifo_aresetn] [get_bd_pins ch_cond_3/vfifo_aresetn] [get_bd_pins ch_output_0/vfifo_aresetn] [get_bd_pins ch_output_1/vfifo_aresetn] [get_bd_pins ch_output_2/vfifo_aresetn] [get_bd_pins ch_output_3/vfifo_aresetn] [get_bd_pins vfifo_ddr4_buffer/vfifo_aresetn]
  connect_bd_net -net vfifo_ddr4_buffer_c0_init_calib_complete_0 [get_bd_pins mig_init_calib_complete] [get_bd_pins vfifo_ddr4_buffer/c0_init_calib_complete_0]
  connect_bd_net -net vfifo_mm2s_channel_full_1 [get_bd_pins vfifo_ddr4_buffer/vfifo_mm2s_channel_full] [get_bd_pins xlconcat_0/dout]

  # Create address segments
  assign_bd_address -offset 0x80000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces $hier_obj/vfifo_ddr4_buffer/axi_vfifo_ctrl_0/Data_S2MM] [get_bd_addr_segs $hier_obj/vfifo_ddr4_buffer/ddr4_0/C0_DDR4_MEMORY_MAP/C0_DDR4_ADDRESS_BLOCK] -force

  # Restore current instance
  current_bd_instance $oldCurInst
}


proc available_tcl_procs { } {
   puts "##################################################################"
   puts "# Available Tcl procedures to recreate hierarchical blocks:"
   puts "#"
   puts "#    create_hier_cell_axi4s_vfifo_buffer_0 parentCell nameHier"
   puts "#    create_hier_cell_ch_cond_0 parentCell nameHier"
   puts "#    create_hier_cell_ch_cond_1 parentCell nameHier"
   puts "#    create_hier_cell_ch_cond_2 parentCell nameHier"
   puts "#    create_hier_cell_ch_cond_3 parentCell nameHier"
   puts "#    create_hier_cell_ch_output_0 parentCell nameHier"
   puts "#    create_hier_cell_ch_output_1 parentCell nameHier"
   puts "#    create_hier_cell_ch_output_2 parentCell nameHier"
   puts "#    create_hier_cell_ch_output_3 parentCell nameHier"
   puts "#    create_hier_cell_vfifo_ddr4_buffer parentCell nameHier"
   puts "#"
   puts "#"
   puts "# The following procedures will create hiearchical blocks with addressing "
   puts "# for IPs within those blocks and their sub-hierarchical blocks. Addressing "
   puts "# will not be handled outside those blocks:"
   puts "#"
   puts "#    create_hier_cell_axi4s_vfifo_buffer_0 "
   puts "#"
   puts "##################################################################"
}

available_tcl_procs
