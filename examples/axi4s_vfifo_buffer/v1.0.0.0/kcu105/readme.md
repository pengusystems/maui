## Integrating the `axi4s_vfifo_buffer` into another design
The tcl command: `write_bd_tcl -hier_blks [get_bd_cells /axi4s_vfifo_buffer_0] create_inst.tcl -force` was used to generate [`create_inst.tcl`](./create_inst.tcl) which can be used to integrate this IP into a different design:
1. Source `create_inst.tcl` using the tcl `source` command 
2. Reference the printed message with another tcl call for the integration. For example: `create_hier_cell_axi4s_vfifo_buffer_0 / axi4s_vfifo_buffer_0`, where the first argument is the parent block design or cell and the second argument is the name of the hierarchy to generate.
