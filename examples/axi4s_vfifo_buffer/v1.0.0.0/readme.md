# axi4s_vfifo_buffer
This component provides a MIG (Memory interface Generator) based (external DDR memory) fifo buffering scheme (virtual fifo) for high bandwidth, multi channel, async, axi4 streams. It is platform dependent due to the nature of MIG. The objective of this component is to optimize the overall input to output throughput while providing large buffers in between. This is particularly useful as an elastic buffer for axi streams that cannot take back-pressure. **In addition to the `tdest` requirement mentioned below, keep in mind that the instances created based on this reference must be tuned for design specifics.**

## Implementation details
![Block diagram](./axi4s_vfifo_buffer.png)
**This component is a simple IPI hierarchy** which integrates multiple axi stream IP components from the [axi stream infrastructure](../../../docs/xilinx/axi4_stream/pg085-axi4stream-infrastructure.pdf) together. The components are tied to a [xilinx' virtual fifo IP](../../../docs/xilinx/axi_vfifo_controller/pg038_axi_vfifo_ctrl.pdf) and provide arbitration, per channel input & output fifo buffers, and clock and data width converters.

### Xilinx virtual fifo IP
The general scheme of the axi stream components used with the virtual fifo IP is depicted [here](../../../../../docs/xilinx/axi_vfifo_controller/pg038_axi_vfifo_ctrl.pdf#page=8). There are [several key points](../../../docs/xilinx/axi_vfifo_controller/pg038_axi_vfifo_ctrl.pdf#page=29) to pay attention to when designing with the virtual fifo IP:
1. Per channel page allocation and burst size, which are also correlated with packet size and should be configured carefully keeping the output interface requirements in mind
2. Per channel weight allocation for arbitration
3. Size of output buffers

### Channel conditioning
Each channel conditioner includes a combination of:
1. Clock and data width conversion for allowing flexible async axi streams
2. Packet fifos (data is available on the fifo's output interface only after `tlast` was received on the fifo's input interface). Packet fifos are critical for per channel reset (by flushing data through the output interface) since the virtual fifo IP only has a single global reset. Any axi stream packets contained in the `vfifo_clk` domain must be complete or else the flush will leave traces behind.

### Mux/Demux of multiple axi4 stream channels
The virtual fifo IP has a single axi stream interface. It implements multi channel buffering based on the axi stream `tdest` signal. As a result, an arbitration scheme must be used to grant channel access. On the output side, a demux uses `tdest` to distribute the axi streams to different output fifos. 
**:information_source:The input axi streams must be fill in `tdest` such that channel `i` uses `tdest` of `i`. This is critical for the arbitration scheme to work correctly**

### Output fifos
The output buffer size should be determined by the weight allocation and burst size as described [here](#xilinx-virtual-fifo-ip)

### Resets
The virtual fifo (associated with `vfifo_aresetn`) as well as each individual channel (associated with `aresetn_*`) should be reset before initial use. **[Resets should only be applied when clocks are stable](https://support.xilinx.com/s/question/0D52E00006hpgGfSAI/builtin-fifo-reset?language=en_US).** Channel buffers reset is based on a flushing scheme as described below. This scheme guarantees that all data is flushed and the stream integrity on capture start is valid only when the entire pipeline is full:
1. Stop the input stream. This can be done using a custom axi4 stream component
2. Flush the channel by asserting `m_tready` of the output interface until it is empty.
3. Wait long enough for the channel `vfifo_clk` domain side buffers to completely empty out. Depending on factors such as packet size and output fifo size, the data on the output interface might come out back-to-back and then tvalid could be used to indicate when the channel is empty. Otherwise, this phase must be based on a waited timeout.
4. Stall the channel by deasserting `m_tready` of the output interface
5. Restart the input stream

:information_source:It has been observed (on the hardware, not in simulation) that resetting the channel's `data_clk` domain side buffers can cause the channel's s2m_full indication in the virtual fifo to hang high. This is an unrecoverable state and the fpga will have to be rebooted. The theory (to be validated) is that a packet between the channel conditioner and the axis mux is likely to be in mid flight and a reset will screw up the index of the axis last indication between the channel conditioner packet fifos and the axis mux. **This requires more research**

### Using MIG with other AXI masters
The IPI hierarchy generated by this component includes a MIG for simple integration. If MIG is already used in the design, it can be easily pulled out of the hierarchy. An arbiter can then be placed in front of MIG, which will arbitrate between the AXI data stream sourced by the virtual fifo IP and other AXI masters.