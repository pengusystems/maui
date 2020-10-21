//////////////////////////////////////////////////////////////////////////////////
// Target Devices: 7 series
// Description: Arbitrates between three, or less, 32bit AXI4 streams with dram
//              buffering capablities.
//              The arbiter receives a system clock which should be clocked at 200MHz
//              to clock the dram controller. From the system clock it generates
//              mclk = sys_clk/2, which the user should use to clock the ingress
//              streams. If the memory is disabled, then the arbiter forwards
//              a seperate input clk, dclk, to mclk.
//              The arbiter egress can be asynchronous with the ingress streams and is 
//              clocked by gclk.
//              The arbitration is performed based on ingress streams buffering level,
//              where the stream with the highest level is granted the pipe.
//              Arbitration and overflow logic are assuming that the size of the 
//              buffers of all ingress streams is equal.
//              The arbiter has two datapaths:
//              1.Memory bypass, which is selected if none of the ingress streams are 
//                in an overflow risk and the memory is empty. In that case, four samples of 
//                32bit wide data are spliced together, and then written to the output buffer.
//                The size of the transfer (#32 bit samples) is also written to the transfer 
//                size buffer, such that the egress side can recreate exactly the same transfer.
//                In order to save space in the transfer size buffer, only the size of transfers
//                smaller than a full transfer is registered. A count of the number of
//                transfers from the last registered transfer is registered as well,
//                and, generally, full transfers are not registered, unless the count
//                reached a higher bound.
//              2.Memory write & read, which is selected if any of the ingress streams is
//                in an overflow risk, or, since the arbiter is in-order, if the memory 
//                already contains data. Similarly to a memory bypass, samples are spliced
//                together to form 128bit wide words and the size of the transfer is 
//                registered to allow the egress side to recreate it. 
//              On the egress side, ouput buffer dout, 128bit words are splitted to 32 bit 
//              samples and the transfer size buffered is used to recreate the ingress transfer.
//              The arbiter can be enabled or disabled asynchronously to its operation.
//              If a disable request was asserted, it would wait until after the memory
//              is empty. A memory enable request can happen between transfers.
//              If the memory fills up, the arbiter will stall the AXI ingress pipe
//              and initiate a read all memory command. The pipe will open only
//              after the memory is empty.
//
// Dependencies: sync_upcnt.v, sync_upcnt_downcnt.v, synchronizer_1bit.v ddr2.xci, 
//               output_buffer.xci, transfer_size_buffer.xci, ddr2.xci, mig_b.prj
//////////////////////////////////////////////////////////////////////////////////
module dram_buffered_arbiter #(
    parameter INGRESS_FIFO_DEPTH_IN_32BIT_WORDS = 16384,
    parameter INGRESS_FULL_TRANSFER_SIZE_IN_32BIT_WORDS = 4096,
    parameter INGRESS_MAX_BITRATE_IN_MEGABIT_PER_SEC = 1280
   )
   (
    input mem_enable_async,
    input sys_clk,
    input gclk,
    input dclk,
    input sys_clk_and_gclk_locked,      
    output mclk,
    output mem_enabled_mclk,
    output [31:0] mem_use_cnt_in_16bytes_mclk,

    // AXI ingress stream 0.
    output s0_tready_mclk,
    input s0_tvalid_mclk,
    input s0_tlast_mclk,
    input [31:0] s0_tdata_mclk,
    input [14:0] s0_fifo_level_mclk,

    // AXI ingress stream 1.
    output s1_tready_mclk,
    input s1_tvalid_mclk,
    input s1_tlast_mclk,
    input [31:0] s1_tdata_mclk,
    input [14:0] s1_fifo_level_mclk,

    // AXI ingress stream 2.
    output s2_tready_mclk,
    input s2_tvalid_mclk,
    input s2_tlast_mclk,
    input [31:0] s2_tdata_mclk,
    input [14:0] s2_fifo_level_mclk,

    // AXI egress.
    input m_tready_gclk,
    output m_tvalid_gclk,
    output m_tlast_gclk,
    output [31:0] m_tdata_gclk,
    output [1:0] urgency_level_gclk,

    // DDR2 memory interface.
    output [12:0] ddr_a,     
    output [2:0] ddr_b,      
    output ddr_cas,          
    output ddr_ce,           
    output ddr_clk_p,        
    output ddr_clk_n,        
    output ddr_cs,           
    inout [15:0] ddr_dq,     
    output [1:0] ddr_dqm,    
    inout [1:0] ddr_dqs_n,   
    inout [1:0] ddr_dqs_p,   
    output ddr_odt,          
    output ddr_ras,          
    output ddr_we,           
    output vtt_en  
  );


  /////////////////////////////////////////////////
  //               PARAMETERS                    //
  /////////////////////////////////////////////////
  // MEM FSM parameters.
  localparam MEM_FSM_WIDTH        = 3;
  localparam MEM_FSM_IDLE         = 3'd0;
  localparam MEM_FSM_WAIT_ENABLE  = 3'd1;
  localparam MEM_FSM_WAIT_DISABLE = 3'd2;  
  localparam MEM_FSM_BYPASS       = 3'd3;
  localparam MEM_FSM_WR           = 3'd4;
  localparam MEM_FSM_RD           = 3'd5;
  
  // Memory and ingress clock selection state.
  localparam MEM_ENABLED = 1'b0;  
  localparam MEM_DISABLED = 1'b1;
  localparam SELECT_MEM_CLK = 1'b0;
  localparam SELECT_DCLK = 1'b1;
  
  // Memory controller parameters.
  localparam MEM_ADDR_WIDTH = 26;  
  localparam MEM_CMD_WIDTH = 3;
  localparam MEM_CMD_IDLE  = 3'b010;
  localparam MEM_CMD_WR    = 3'b000;
  localparam MEM_CMD_RD    = 3'b001;  
  
  // Memory addressing parameters.
  // The memory uses a burst length of 8 in 4:1 mode, its data width is 128 which also dictates the ingress data width.
  // MEM_CAPACITY_IN_TRANSFERS sets how many transfers can fit in the memory, where one transfer has INGRESS_FULL_TRANSFER_SIZE_IN_32BIT_WORDS words.
  // MEM_CAPACITY_IN_128BIT_WORDS is how many 128bit words can fit in the memory.
  // MEM_ADDR_LAST is set according to MEM_CAPACITY_IN_TRANSFERS, 
  // MEM_USE_CNT_WIDTH should be able to fit MEM_CAPACITY_IN_TRANSFERS.
  // For example for MEM_CAPACITY_IN_TRANSFERS = 8000 and INGRESS_FULL_TRANSFER_SIZE_IN_32BIT_WORDS = 4096
  // INGRESS_FULL_TRANSFER_SIZE_IN_128BIT_WORDS = 4096 >> 2 = 1024.
  // The memory will be able to store 8000 * 1024 * 128 bits = 1,048,576,000bits = 125MBytes.
  // Addressing will range between 0 to 8 * 8000 * 1024 - 8 = 65,535,992 = 0x3E7FFF8.  
  localparam MEM_USE_CNT_WIDTH = 32;
  localparam MEM_PENDING_RD_REQ_CNT_WIDTH = MEM_USE_CNT_WIDTH;
  localparam INGRESS_FULL_TRANSFER_SIZE_IN_128BIT_WORDS = INGRESS_FULL_TRANSFER_SIZE_IN_32BIT_WORDS >> 2;    
  localparam MEM_CAPACITY_IN_TRANSFERS = 32'd8000;
  localparam MEM_CAPACITY_IN_128BIT_WORDS = MEM_CAPACITY_IN_TRANSFERS * INGRESS_FULL_TRANSFER_SIZE_IN_128BIT_WORDS;
  localparam MEM_ADDR_LAST_32BIT = (8 * MEM_CAPACITY_IN_TRANSFERS * INGRESS_FULL_TRANSFER_SIZE_IN_128BIT_WORDS) - 8;   
  localparam MEM_ADDR_LAST = MEM_ADDR_LAST_32BIT[MEM_ADDR_WIDTH-1:0];  
  
  // Stream selector parameters.
  localparam STREAM_SELECT_WIDTH = 2;
  localparam STREAM0   = 2'd0;
  localparam STREAM1   = 2'd1;
  localparam STREAM2   = 2'd2;
  localparam NO_STREAM = 2'd3;
  localparam SELECT_HOLD_CYCLES = 5; // Hold the selection in IDLE state for SELECT_HOLD_CYCLES such that
                                     // a stream can get reselected if it deasserts valid between transfers.
                                     // This is necessary if that stream still has the highest fifo level.
  
  // Overflow risk thresholds.
  // "PER_STREAM_OVERFLOW_RISK_THRESHOLD" is the most basic threshold, intended to switch MEM_FSM to a memory write path when considering the streams independently.
  //                                      the idea is to allow a minimal spare, before the stream overflows.
  // "DOUBLE_SHARED_OVERFLOW_RISK_THRESHOLD" is a condition that can occur since memory writes always end on ingress transfer boarders and not before. 
  //                                         If, for example, stream0 is being written to memory, stream1 or stream2, can meanwhile fill up.
  //                                         Alternatively, stream0 may be bypassing the memory, but stream1 has got enough packets that it might
  //                                         overflow if we don't start writing both streams to the memory.
  //                                         The following diagram describes the worst scenario to find the maximum fifo level for S1, X, such that it
  //                                         will not overflow, if S0 is currently selected. 
  //                                         In the worst case, stream0 is selected for bypass, but the output buffer is almost full, so it stalls almost right away.
  //                                         This means that a complete stream0 transfer still has to finish before we can select stream1.
  //                                         In this case, we immediately start transfering stream0 to the memory and must finish before stream1 overflowed.
  //                                                      meaning                                                                                  example value                                                                                
  //                                         L - Stream FIFO depth in 32bit wide words                                                             16384
  //                                         S - Ingress transfer size composed of 32bit wide words                                                 4096
  //                                         M - Maximum incoming bit rate in any of the streams(32bit wide word/ns), @1280Mbits in 1s =               0.04(word/ns) 
  //                                         F - Memory user clk frequency(MHz)                                                                      100(MHz)
  //                                         U - Memory effective clk frequency factor (must be smaller than 1)                                        0.9
  //                                         P - Memory effective clk period(ns), P = 1e3/(U*F)                                                       11.11(ns)
  //                                         T - How long does a memory write of one full ingress transfer takes(ns), 
  //                                             Effectively we write 128bit (transfer is S/4), every 4 cycles (4*P), T = 4*P * S/4 = P*S          45512(ns)
  //                                         R - Safety margin from full in 32bit wide words                                                         400                            
  //                                         x - level before overflow risk, L > x+T*M => x = L-T*M-R                                              14164  
  //                                         y - Entries to full, y = L-x                                                                           2220      
  //                                   
  //                                         |      |___|    |   |
  //                                         |      |   |    |_y_|                                  
  //                                         L      |   |    | x |
  //                                         ~        ~        ~
  //                                         |      |___|    |___|
  //                                                 S0       S1
  //
  // "TRIPLE_SHARED_OVERFLOW_RISK_THRESHOLD" is a condition that can occur since memory writes always end on ingress transfer boarders and not before. 
  //                                         If, for example, stream0 is currently selected, we need be able to write stream1 and stream2 without overflowing them.
  //                                         In this case we need to double the double_shared threshold such that we'll get to the last stream in time.
  // Overflow variables (user can change).
  localparam real F_MEM_CLK_USER_APP_FREQ_MHZ = 100;
  localparam real U_MEM_CLK_EFFECTIVE_FREQ_FACTOR = 0.9;
  localparam R_SAFETY_MARGIN_IN_32BIT_WORDS = 400;
  
  // Overflow derivatives.
  localparam real M_MAX_INGRESS_BITRATE_IN_32BIT_WORDS_OVER_NS = (INGRESS_MAX_BITRATE_IN_MEGABIT_PER_SEC / 1e3) / 32;  
  localparam L_INGRESS_FIFO_DEPTH_IN_32BIT_WORDS = INGRESS_FIFO_DEPTH_IN_32BIT_WORDS;  
  localparam S_INGRESS_FULL_TRANSFER_SIZE_IN_32BIT_WORDS = INGRESS_FULL_TRANSFER_SIZE_IN_32BIT_WORDS; 
  localparam real P_MEM_CLK_EFFECTIVE_PERIOD_NS = (1e3/(U_MEM_CLK_EFFECTIVE_FREQ_FACTOR * F_MEM_CLK_USER_APP_FREQ_MHZ));
  localparam T_FULL_TRANSFER_MEM_WRITE_DURATION_NS = P_MEM_CLK_EFFECTIVE_PERIOD_NS * S_INGRESS_FULL_TRANSFER_SIZE_IN_32BIT_WORDS;
  
  // Overflow results.
  localparam integer X_LEVEL_BEFORE_DOUBLE_OVERFLOW_RISK = L_INGRESS_FIFO_DEPTH_IN_32BIT_WORDS - 
                                                           T_FULL_TRANSFER_MEM_WRITE_DURATION_NS * M_MAX_INGRESS_BITRATE_IN_32BIT_WORDS_OVER_NS - 
                                                           R_SAFETY_MARGIN_IN_32BIT_WORDS;
  localparam Y_ENTRIES_TO_FULL = L_INGRESS_FIFO_DEPTH_IN_32BIT_WORDS - X_LEVEL_BEFORE_DOUBLE_OVERFLOW_RISK;
  localparam X_LEVEL_BEFORE_TRIPLE_OVERFLOW_RISK = X_LEVEL_BEFORE_DOUBLE_OVERFLOW_RISK - Y_ENTRIES_TO_FULL;
  localparam X_LEVEL_BEFORE_PER_STREAM_OVERFLOW_RISK = L_INGRESS_FIFO_DEPTH_IN_32BIT_WORDS - R_SAFETY_MARGIN_IN_32BIT_WORDS;              
  localparam PER_STREAM_OVERFLOW_RISK_THRESHOLD    = X_LEVEL_BEFORE_PER_STREAM_OVERFLOW_RISK[14:0];
  localparam DOUBLE_SHARED_OVERFLOW_RISK_THRESHOLD = X_LEVEL_BEFORE_DOUBLE_OVERFLOW_RISK[14:0];
  localparam TRIPLE_SHARED_OVERFLOW_RISK_THRESHOLD = X_LEVEL_BEFORE_TRIPLE_OVERFLOW_RISK[14:0];
  
  // Output buffer access parameters.
  localparam OUTPUT_BUFFER_AT_ALMOST_WRITE_DEPTH = 2045;
  localparam OUTPUT_BUFFER_RD_USE_CNT_WIDTH = 12;
  localparam OUTPUT_BUFFER_WR_USE_CNT_WIDTH = OUTPUT_BUFFER_RD_USE_CNT_WIDTH;
  
  // Transfer size buffer access parameters.
  // Each entry of the transfer size buffer has the following structure:
  // NUM_TRANSFERS_SINCE_LAST_REGISTERED: The number of transfers, which were streamed and did not have an entry in the transfer size buffer, 
  //                                      counting from the last transfer that did have an entry. This field must be able to contain MAX_NUM_TRANSFERS_NOT_REGISTERED
  // TRANSFER_SIZE_32BIT_WORDS: The size of the transfer in 128bit wide words.
  localparam TRANSFER_SIZE_CNT_WIDTH = 15;
  localparam TRANSFERS_CNT_WIDTH = 9;      
  localparam TRANSFER_SIZE_BUFFER_WIDTH = TRANSFER_SIZE_CNT_WIDTH + TRANSFERS_CNT_WIDTH;
  localparam MAX_NUM_TRANSFERS_NOT_REGISTERED = 9'd500;
  `define NUM_TRANSFERS_SINCE_LAST_REGISTERED 23:15
  `define TRANSFER_SIZE_32BIT_WORDS 14:0
  
  // Egress parameters.
  localparam URGENCY_NONE    = 2'b11;  
  localparam URGENCY_MINIMAL = 2'b10;
  localparam URGENCY_LOW     = 2'b01;  
  localparam URGENCY_HIGH    = 2'b00;


  /////////////////////////////////////////////////
  //            SIGNAL DECLARATION               //
  /////////////////////////////////////////////////
  // To memory controller.
  wire sys_clk_gated;  
  
  // From memory controller.
  wire mem_clk;
  wire mem_init_done;
  
  // MEM FSM.
  reg  [MEM_FSM_WIDTH-1:0] mem_fsm_next_mclk;  
  reg  [MEM_FSM_WIDTH-1:0] mem_fsm_state_mclk_ff = MEM_FSM_IDLE;
  
  // Memory enable/disable on mclk.
  wire sys_clk_and_gclk_locked_mclk;
  wire mem_enable_mclk;
  wire mem_state_mclk;
  reg  trigger_mem_enable_flow_mclk;
  reg  trigger_mem_disable_flow_mclk;
  wire mem_disabled_mclk;
  
  // Stream select and overflow logic.
  reg  select_stream_en_mclk;
  reg  selected_stream_ready_mclk; 
  reg  selected_stream_valid_mclk;
  reg  selected_stream_last_mclk;
  reg  [31:0] selected_stream_data_mclk;
  reg  [STREAM_SELECT_WIDTH-1:0] selected_stream_mclk_ff = NO_STREAM;
  reg  s0_per_stream_overflow_risk_mclk_ff;
  reg  s1_per_stream_overflow_risk_mclk_ff;
  reg  s2_per_stream_overflow_risk_mclk_ff;  
  reg  s0_double_shared_overflow_risk_mclk_ff;
  reg  s1_double_shared_overflow_risk_mclk_ff;
  reg  s2_double_shared_overflow_risk_mclk_ff;
  reg  s0_triple_shared_overflow_risk_mclk_ff;
  reg  s1_triple_shared_overflow_risk_mclk_ff;
  reg  s2_triple_shared_overflow_risk_mclk_ff;     
  reg  overall_per_stream_overflow_risk_mclk_ff;
  reg  overall_double_shared_overflow_risk_mclk_ff;
  reg  overall_triple_shared_overflow_risk_mclk_ff;  
  reg  overall_overflow_risk_mclk_ff;
  wire overall_tvalid_mclk;    
  
  // Datapath on mclk.
  reg  ready_for_data_mclk;
  reg  splicing_register_load_mclk;
  reg  last_sample_registered_mclk;  
  reg  [127:0] splicing_register_mclk_ff;
  reg  splicing_register_has_last_mclk_ff = 1'b0; 
  reg  transfer_in_size_cnt_en_mclk;
  wire transfer_size_buffer_wren_mclk;
  wire [TRANSFERS_CNT_WIDTH-1:0] transfers_in_cnt_mclk;
  wire [TRANSFER_SIZE_CNT_WIDTH-1:0] transfer_in_size_cnt_mclk;
  wire [TRANSFER_SIZE_BUFFER_WIDTH-1:0] transfer_size_buffer_din_mclk;
  reg  output_buffer_wren_mclk;
  reg  output_buffer_lookahead_full_mclk_ff = 1'b0;
  wire output_buffer_full_mclk;
  reg  [127:0] output_buffer_din_mclk;    
  wire mem_adf_rdy_mclk;
  wire mem_wdf_rdy_mclk;
  reg  mem_wdf_wren_mclk;
  reg  mem_rden_mclk;
  wire mem_buffer_almost_empty_mclk;  
  wire mem_buffer_empty_mclk;
  wire mem_buffer_full_mclk;
  wire transfer_size_buffer_full_mclk;
  wire mem_rd_data_valid_mclk;
  wire no_pending_mem_rd_req_mclk;
  reg  read_all_memory_mclk;
  reg  read_all_memory_done_mclk;  
  wire [127:0] mem_rd_data_mclk;  
  reg  [MEM_CMD_WIDTH-1:0] mem_cmd_mclk;
  reg  [MEM_ADDR_WIDTH-1:0] mem_addr_mclk;
  wire [MEM_ADDR_WIDTH-1:0] mem_wr_addr_mclk;
  wire [MEM_ADDR_WIDTH-1:0] mem_rd_addr_mclk;
  wire [MEM_USE_CNT_WIDTH-1:0] mem_use_cnt_mclk;
  wire [MEM_PENDING_RD_REQ_CNT_WIDTH-1:0] mem_pending_rd_req_cnt_mclk;
  reg  read_all_memory_mclk_ff = 1'b0;         
  
  // Memory enable/disable on gclk.
  wire trigger_mem_disable_flow_gclk;
  wire trigger_mem_enable_flow_gclk;  
  reg  [2:0] hold_mem_in_reset_gclk_ff = 3'b111;
  
  // Datapath on gclk.
  wire egress_sample_shifted_gclk;
  wire last_egress_sample_shifted_gclk;
  wire has_at_least_one_egress_transfer_gclk;
  wire mem_buffer_empty_gclk;
  wire no_pending_mem_rd_req_gclk;
  wire transfer_size_buffer_empty_gclk;
  wire output_buffer_empty_gclk;
  reg  sample_valid_gclk_ff = 1'b0;  
  wire load_splitting_register_gclk;  
  wire [127:0] output_buffer_dout_gclk;
  wire [TRANSFER_SIZE_CNT_WIDTH-1:0] transfer_out_size_cnt_gclk;
  wire [TRANSFERS_CNT_WIDTH-1:0] transfers_out_cnt_gclk;
  wire [TRANSFER_SIZE_BUFFER_WIDTH-1:0] transfer_size_buffer_dout_gclk;  
  wire [OUTPUT_BUFFER_RD_USE_CNT_WIDTH-1:0] output_buffer_use_cnt_gclk;
  wire [OUTPUT_BUFFER_WR_USE_CNT_WIDTH-1:0] output_buffer_use_cnt_mclk;
  
  
  ////////////////////////////////////////////////////////////////////////////////////////////////////////////
  //                                            Design starts here                                          //
  ////////////////////////////////////////////////////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////////////////////////////
  //                                            MCLK DOMAIN                                                 //
  //////////////////////////////////////////////////////////////////////////////////////////////////////////// 
  // Synchronize mem_enable_async, long indication, to mclk, ingress, domain.
  // MEM_FSM uses the synchronized indication to trigger memory enable/disable flow when it is idle state.
  synchronizer_1bit mem_enable_sync (
   .clk(mclk),  
   .async_in(mem_enable_async), 
   .sync_out(mem_enable_mclk)
  );   
  
  
  // Synchronize the lock indication to mcl domain.
  synchronizer_1bit sys_clk_and_gclk_locked_sync (
   .clk(mclk),  
   .async_in(sys_clk_and_gclk_locked), 
   .sync_out(sys_clk_and_gclk_locked_mclk)
  );     
  
     
  // Valid if any of the steams is valid.
  assign overall_tvalid_mclk = s0_tvalid_mclk | s1_tvalid_mclk | s2_tvalid_mclk;  
  
  
  // Stream selector logic is based on ingress fill level and valid. 
  reg  [SELECT_HOLD_CYCLES-1:0] select_stream_en_mclk_ff = {SELECT_HOLD_CYCLES{1'b0}};
  always @(posedge mclk)
  begin : STREAM_MUX_SELECT  
    // Use a shift register to hold the next stream selection for #SELECT_HOLD_CYCLES cycles.
    select_stream_en_mclk_ff <= {select_stream_en_mclk_ff[SELECT_HOLD_CYCLES-2:0], select_stream_en_mclk};
    
    // First of all unselect the current stream.
    if (select_stream_en_mclk) begin
      selected_stream_mclk_ff <= NO_STREAM;    
    end
    
    // Then, hold for #SELECT_HOLD_CYCLES cycles and select a stream.
    if (select_stream_en_mclk_ff[SELECT_HOLD_CYCLES-1]) begin         
      // All streams are valid.
      if (s0_tvalid_mclk & s1_tvalid_mclk & s2_tvalid_mclk) begin         
        if (s0_fifo_level_mclk >= s1_fifo_level_mclk) begin
          if (s0_fifo_level_mclk >= s2_fifo_level_mclk) begin 
            selected_stream_mclk_ff <= STREAM0;
          end
          else begin
            selected_stream_mclk_ff <= STREAM2;
          end
        end
        else begin
          if (s1_fifo_level_mclk >= s2_fifo_level_mclk) begin         
            selected_stream_mclk_ff <= STREAM1;
          end
          else begin
            selected_stream_mclk_ff <= STREAM2;
          end
        end
      end
      
      // Only two streams are valid (S0 & S1, S0 & S2, S1 & S2).
      if (s0_tvalid_mclk & s1_tvalid_mclk & ~s2_tvalid_mclk) begin         
        if (s0_fifo_level_mclk >= s1_fifo_level_mclk) begin    
          selected_stream_mclk_ff <= STREAM0;
        end
        else begin
          selected_stream_mclk_ff <= STREAM1;
        end
      end
      if (s0_tvalid_mclk & s2_tvalid_mclk & ~s1_tvalid_mclk) begin         
        if (s0_fifo_level_mclk >= s2_fifo_level_mclk) begin    
          selected_stream_mclk_ff <= STREAM0;
        end
        else begin
          selected_stream_mclk_ff <= STREAM2;
        end
      end   
      if (s1_tvalid_mclk & s2_tvalid_mclk & ~s0_tvalid_mclk) begin         
        if (s1_fifo_level_mclk >= s2_fifo_level_mclk) begin    
          selected_stream_mclk_ff <= STREAM1;
        end
        else begin
          selected_stream_mclk_ff <= STREAM2;
        end
      end
    
      // Only one stream is valid.
      if (s0_tvalid_mclk & ~s1_tvalid_mclk & ~s2_tvalid_mclk) begin         
        selected_stream_mclk_ff <= STREAM0;
      end
      if (s1_tvalid_mclk & ~s0_tvalid_mclk & ~s2_tvalid_mclk) begin         
        selected_stream_mclk_ff <= STREAM1;
      end
      if (s2_tvalid_mclk & ~s0_tvalid_mclk & ~s1_tvalid_mclk) begin         
        selected_stream_mclk_ff <= STREAM2;
      end                 
    end                          
  end  
    
  
  // Connect the selected stream.              
  always @*
  begin : STREAM_MUX    
    case(selected_stream_mclk_ff)
      STREAM0:   begin 
                   selected_stream_valid_mclk = s0_tvalid_mclk;
                   selected_stream_data_mclk  = s0_tdata_mclk;
                   selected_stream_last_mclk  = s0_tlast_mclk;
                 end
      STREAM1:   begin 
                   selected_stream_valid_mclk = s1_tvalid_mclk;
                   selected_stream_data_mclk  = s1_tdata_mclk;
                   selected_stream_last_mclk  = s1_tlast_mclk;
                 end
      STREAM2:   begin 
                   selected_stream_valid_mclk = s2_tvalid_mclk;
                   selected_stream_data_mclk  = s2_tdata_mclk;
                   selected_stream_last_mclk  = s2_tlast_mclk;
                 end
      NO_STREAM: begin
                   selected_stream_valid_mclk = 1'b0;
                   selected_stream_data_mclk  = 32'b0;
                   selected_stream_last_mclk  = 1'b0; 
                 end                                      
    endcase
  end 
  assign s0_tready_mclk = (selected_stream_mclk_ff == STREAM0) ? selected_stream_ready_mclk : 1'b0;
  assign s1_tready_mclk = (selected_stream_mclk_ff == STREAM1) ? selected_stream_ready_mclk : 1'b0;   
  assign s2_tready_mclk = (selected_stream_mclk_ff == STREAM2) ? selected_stream_ready_mclk : 1'b0;       
   
  
  // Overflow indication.
  // There are three types:
  // 1.Per stream - A stream is getting close to overflow.
  // 2.Double shared - A stream is getting close to a level, where if we picked another stream, it will overflow.
  // 3.Triple shared - A stream is getting close to a level, where if we picked other streams twice in a row, it will overflow.
  always @(posedge mclk)
  begin : OVERALL_OVERFLOW_RISK_DECISION_LOGIC
    // Indicate when any of the streams satisfies this condition.
    s0_per_stream_overflow_risk_mclk_ff      <= (s0_fifo_level_mclk >= PER_STREAM_OVERFLOW_RISK_THRESHOLD);
    s1_per_stream_overflow_risk_mclk_ff      <= (s1_fifo_level_mclk >= PER_STREAM_OVERFLOW_RISK_THRESHOLD);
    s2_per_stream_overflow_risk_mclk_ff      <= (s2_fifo_level_mclk >= PER_STREAM_OVERFLOW_RISK_THRESHOLD);
    overall_per_stream_overflow_risk_mclk_ff <= s0_per_stream_overflow_risk_mclk_ff | 
                                                s1_per_stream_overflow_risk_mclk_ff |
                                                s2_per_stream_overflow_risk_mclk_ff;     
    
    // Indicate when any two streams satisfy this condition.
    s0_double_shared_overflow_risk_mclk_ff <= (s0_fifo_level_mclk >= DOUBLE_SHARED_OVERFLOW_RISK_THRESHOLD);          
    s1_double_shared_overflow_risk_mclk_ff <= (s1_fifo_level_mclk >= DOUBLE_SHARED_OVERFLOW_RISK_THRESHOLD);          
    s2_double_shared_overflow_risk_mclk_ff <= (s2_fifo_level_mclk >= DOUBLE_SHARED_OVERFLOW_RISK_THRESHOLD);
    overall_double_shared_overflow_risk_mclk_ff <= (s0_double_shared_overflow_risk_mclk_ff & s1_double_shared_overflow_risk_mclk_ff) | 
                                                   (s0_double_shared_overflow_risk_mclk_ff & s2_double_shared_overflow_risk_mclk_ff) | 
                                                   (s1_double_shared_overflow_risk_mclk_ff & s2_double_shared_overflow_risk_mclk_ff); 
    
    // Indicate when all streams satisfy this condition.
    s0_triple_shared_overflow_risk_mclk_ff <= (s0_fifo_level_mclk >= TRIPLE_SHARED_OVERFLOW_RISK_THRESHOLD);          
    s1_triple_shared_overflow_risk_mclk_ff <= (s1_fifo_level_mclk >= TRIPLE_SHARED_OVERFLOW_RISK_THRESHOLD);          
    s2_triple_shared_overflow_risk_mclk_ff <= (s2_fifo_level_mclk >= TRIPLE_SHARED_OVERFLOW_RISK_THRESHOLD);
    overall_triple_shared_overflow_risk_mclk_ff <= s0_triple_shared_overflow_risk_mclk_ff & s1_triple_shared_overflow_risk_mclk_ff & s2_triple_shared_overflow_risk_mclk_ff;  

    // Overall.
    overall_overflow_risk_mclk_ff <= overall_per_stream_overflow_risk_mclk_ff    |
                                     overall_double_shared_overflow_risk_mclk_ff |
                                     overall_triple_shared_overflow_risk_mclk_ff;                        
  end


  // MEM FSM control.
  always @*
  begin : MEM_FSM
    mem_fsm_next_mclk = MEM_FSM_IDLE;
    mem_cmd_mclk = MEM_CMD_IDLE;
    trigger_mem_enable_flow_mclk = 1'b0;
    trigger_mem_disable_flow_mclk = 1'b0;
    ready_for_data_mclk = 1'b0;
    splicing_register_load_mclk = 1'b0;
    mem_addr_mclk = mem_wr_addr_mclk;
    mem_wdf_wren_mclk = 1'b0;
    mem_rden_mclk = 1'b0;
    read_all_memory_mclk = 1'b0;
    read_all_memory_done_mclk = 1'b0;
    select_stream_en_mclk = 1'b0;
    selected_stream_ready_mclk = 1'b0;
    transfer_in_size_cnt_en_mclk = 1'b0;
    output_buffer_wren_mclk = mem_rd_data_valid_mclk & mem_enabled_mclk;    
    output_buffer_din_mclk = mem_rd_data_mclk;
    last_sample_registered_mclk = 1'b0;
    
    case(mem_fsm_state_mclk_ff)           
      MEM_FSM_IDLE:          begin
                              // Memory buffer can fill up with the end of the transfer, so we can already initiate a "read all memory"
                              // flow from here. 
                              if (mem_buffer_full_mclk) begin
                                read_all_memory_mclk = 1'b1;
                              end
                           
                               // State transitions:
                               // MEM_FSM_WAIT_ENABLE - If we got a memory enable request, and the memory is disabled, transition to here in
                               //                       order to wait for a safe mclk switch.                   
                               // MEM_FSM_WAIT_DISABLE - If we got a memory disable request, and the memory is enabled, transition to here in
                               //                       order to wait for a safe mclk switch.                                  
                               // MEM_FSM_BYPASS - If any of the streams has valid data, there is nothing in the memory or there are no pending
                               //                  read requests, and the output buffer is not full, bypass the memory and go straight to
                               //                  the output buffer.
                               // MEM_FSM_WR - If there is an overflow risk and valid data
                               // MEM_FSM_RD - If there is no overflow risk, the memory has data, and there is space available
                               //              in the output buffer, read in more data.    
                               // MEM_FSM_IDLE - Stay here, if there is no valid stream, or the output buffer is full and there is no overflow risk.
                               if (mem_enable_mclk & mem_disabled_mclk) begin                               
                                 trigger_mem_enable_flow_mclk = 1'b1;
                                                                          mem_fsm_next_mclk = MEM_FSM_WAIT_ENABLE;
                               end                                 
                               else if (~mem_enable_mclk & mem_enabled_mclk & mem_buffer_empty_mclk & no_pending_mem_rd_req_mclk) begin
                                 trigger_mem_disable_flow_mclk = 1'b1;
                                                                          mem_fsm_next_mclk = MEM_FSM_WAIT_DISABLE;                                                                                                 
                               end                                                                                                                     
                               else if (overall_tvalid_mclk & mem_buffer_empty_mclk & no_pending_mem_rd_req_mclk & ~output_buffer_full_mclk) begin
                                 select_stream_en_mclk = 1'b1;
                                                                          mem_fsm_next_mclk = MEM_FSM_BYPASS;
                               end
                               else if (overall_tvalid_mclk & overall_overflow_risk_mclk_ff & mem_enabled_mclk & ~read_all_memory_mclk) begin
                                 select_stream_en_mclk = 1'b1;
                                                                          mem_fsm_next_mclk = MEM_FSM_WR;
                               end
                               else if ((~mem_buffer_empty_mclk & ~output_buffer_full_mclk & ~overall_overflow_risk_mclk_ff) | read_all_memory_mclk) begin
                                                                          mem_fsm_next_mclk = MEM_FSM_RD;
                               end
                               else begin                                     
                                                                          mem_fsm_next_mclk = MEM_FSM_IDLE;
                               end
                             end
                             
      MEM_FSM_WAIT_ENABLE:   begin
                               // Hold the indication to make it long.
                               trigger_mem_enable_flow_mclk = 1'b1;      
      
                               // State transitions:
                               // MEM_FSM_IDLE - When the memory is enabled, we can safely transition back to MEM_FSM_IDLE.       
                               if (mem_enabled_mclk) begin    
                                 trigger_mem_enable_flow_mclk = 1'b0;                           
                                                                          mem_fsm_next_mclk = MEM_FSM_IDLE;
                               end 
                               else begin                                     
                                                                          mem_fsm_next_mclk = MEM_FSM_WAIT_ENABLE;
                               end                                                                                                              
                             end
                             
      MEM_FSM_WAIT_DISABLE:  begin
                               // Hold the indication to make it long.
                               trigger_mem_disable_flow_mclk = 1'b1;        
      
                               // State transitions:
                               // MEM_FSM_IDLE - When the memory is disabled, we can safely transition back to MEM_FSM_IDLE.       
                               if (mem_disabled_mclk) begin      
                                 trigger_mem_disable_flow_mclk = 1'b0;                                 
                                                                          mem_fsm_next_mclk = MEM_FSM_IDLE;
                               end 
                               else begin                                     
                                                                          mem_fsm_next_mclk = MEM_FSM_WAIT_DISABLE;
                               end                                                                                                              
                             end                             
                           
      MEM_FSM_BYPASS:        begin                                                                                                  
                               // Deassert ready when the output or transfer size buffers are full.
                               // Assert ready, when, and as long as one of the streams is selected.
                               ready_for_data_mclk = (~output_buffer_full_mclk & ~(transfer_size_buffer_full_mclk & selected_stream_last_mclk));                      
                               if (~ready_for_data_mclk | splicing_register_has_last_mclk_ff) begin
                                 selected_stream_ready_mclk = 1'b0;
                               end
                               else begin                                 
                                 selected_stream_ready_mclk = (selected_stream_mclk_ff != NO_STREAM);
                               end   
                               
                               // load the splicing register on a valid sample when ready is asserted.   
                               splicing_register_load_mclk = selected_stream_valid_mclk & ready_for_data_mclk & ~splicing_register_has_last_mclk_ff;
                               transfer_in_size_cnt_en_mclk = splicing_register_load_mclk; 
                               
                               // Write the splicing register to the output buffer when it was loaded with four samples, or on the last sample.                                                                                                                                                 
                               output_buffer_wren_mclk = (splicing_register_load_mclk & (transfer_in_size_cnt_mclk[1:0] == 2'd0) & transfer_in_size_cnt_mclk != {TRANSFER_SIZE_CNT_WIDTH{1'b0}}) |
                                                         (splicing_register_has_last_mclk_ff & ready_for_data_mclk);
                               output_buffer_din_mclk = splicing_register_mclk_ff;                                                                                                                        
                               
                               // State transitions:
                               // MEM_FSM_WR - If the selected stream is in an overflow risk (read side of output buffer
                               //              can't keep up and pressure is back propagated to here), stop waiting for
                               //              for pressure to release and go to memory, where full throughput is guaranteed.                               
                               // MEM_FSM_IDLE - We finished writing the packet to the output buffer, now we should 
                               //                arbitrate between the ingress streams again.
                               if (overall_overflow_risk_mclk_ff & mem_enabled_mclk) begin
                                                                          mem_fsm_next_mclk = MEM_FSM_WR;
                               end                                      
                               else if (splicing_register_has_last_mclk_ff & output_buffer_wren_mclk) begin
                                 last_sample_registered_mclk = 1'b1;
                                                                          mem_fsm_next_mclk = MEM_FSM_IDLE;                               
                               end                                                                                                            
                               else begin                             
                                                                          mem_fsm_next_mclk = MEM_FSM_BYPASS;
                               end
                             end
           
      MEM_FSM_WR:            begin
                               // Deassert ready when the memory or transfer buffers are full or not ready.
                               // Assert ready, when and as long as one of the streams is selected.
                               ready_for_data_mclk = (~mem_buffer_full_mclk & ~(transfer_size_buffer_full_mclk & selected_stream_last_mclk) & 
                                                      mem_wdf_rdy_mclk & mem_adf_rdy_mclk) ;                                                                                                                           
                               if (~ready_for_data_mclk | splicing_register_has_last_mclk_ff) begin
                                 selected_stream_ready_mclk = 1'b0; 
                               end
                               else begin
                                 selected_stream_ready_mclk = (selected_stream_mclk_ff != NO_STREAM);
                               end      
      
                               // load the splicing register on a valid sample when ready is asserted.   
                               splicing_register_load_mclk = selected_stream_valid_mclk & ready_for_data_mclk & ~splicing_register_has_last_mclk_ff;
                               transfer_in_size_cnt_en_mclk = splicing_register_load_mclk;                               
                               
                               // Write the splicing register to the memory when it was loaded with four samples, or on the last sample. 
                               // Address is manipulated by a linear counter which increments with every write.                                                                                                                                                                                   
                               mem_wdf_wren_mclk = (splicing_register_load_mclk & (transfer_in_size_cnt_mclk[1:0] == 2'd0) & transfer_in_size_cnt_mclk != {TRANSFER_SIZE_CNT_WIDTH{1'b0}}) |
                                                   (splicing_register_has_last_mclk_ff & ready_for_data_mclk);
                               mem_cmd_mclk = MEM_CMD_WR;
                               mem_addr_mclk = mem_wr_addr_mclk;                                                              
                               
                               // Memory or transfer buffer filled up, MEM_FSM will transition to MEM_FSM_RD and will stay there
                               // to empty the memory.
                               if (mem_buffer_full_mclk | transfer_size_buffer_full_mclk) begin
                                 read_all_memory_mclk = 1'b1;
                               end
                               
                               // State transitions:
                               // MEM_FSM_IDLE - We finished writing the packet to the memory buffer and should 
                               //                arbitrate between the ingress streams again.
                               // MEM_FSM_RD - If there is no more space in the memory, we try to keep
                               //              the pipe moving by waiting for the gclk side to start streaming,
                               //              and then removing some contents from the memory to the output buffer
                               //              so the transfer can finish.
                               //              In the "read all memory" flow we read 
                               //              ALL the memory before coming back directly to MEM_FSM_WR to finish 
                               //              the transfer for the stream which was pre-selected.
                               //              The implied assumption is that the ingress streams will wait
                               //              and finish the transfer to the arbiter after the read finished.
                               //              The arbiter applies back pressure, but never drops data!. 
                               if (splicing_register_has_last_mclk_ff & mem_wdf_wren_mclk) begin
                                 last_sample_registered_mclk = 1'b1;                               
                                                                          mem_fsm_next_mclk = MEM_FSM_IDLE;
                               end
                               else if (read_all_memory_mclk) begin
                                                                          mem_fsm_next_mclk = MEM_FSM_RD;
                               end                               
                               else begin
                                                                          mem_fsm_next_mclk = MEM_FSM_WR;
                               end
                             end

      MEM_FSM_RD:            begin
                               // Read path from the memory controller.
                               // Stall the read if the output buffer inclusive write count (used entries + #pending read requests) indicates full
                               // or the memory controller is not ready to accept a command. 
                               if ((~output_buffer_lookahead_full_mclk_ff) & (mem_adf_rdy_mclk)) begin
                                 mem_cmd_mclk = MEM_CMD_RD;
                                 mem_addr_mclk = mem_rd_addr_mclk;
                                 mem_rden_mclk = 1'b1;
                               end
                               
                               // State transitions:
                               // MEM_FSM_IDLE - Either the current read request will empty the memory or the read was aborted since an overflow  
                               //                risk condition occured. Either way, a read all memory request isn't asserted. 
                               // MEM_FSM_WR - Read all memory request was asserted and we finished the read. Go back to MEM_FSM_WR and re-open
                               //              the pipe to the pre-selected stream such that it can finish the transfer.
                               //              It is important that we go back to MEM_FSM_WR and not to MEM_FSM_BYPASS, because read requests
                               //              are still acknowledged after we leave this state. In MEM_FSM_BYPASS, the output buffer is
                               //              designated to the ingress streams and not to the memory buffer, therefore the read data
                               //              will be ignored.                             
                               if (((mem_buffer_almost_empty_mclk & mem_rden_mclk) | (overall_overflow_risk_mclk_ff)) & (~read_all_memory_mclk_ff)) begin
                                                                          mem_fsm_next_mclk = MEM_FSM_IDLE;
                               end
                               else if (mem_buffer_almost_empty_mclk & mem_rden_mclk & read_all_memory_mclk_ff) begin
                                 read_all_memory_done_mclk = 1'b1;                                                                  
                                                                          mem_fsm_next_mclk = MEM_FSM_WR;                                 
                               end
                               else begin
                                                                          mem_fsm_next_mclk = MEM_FSM_RD;
                               end
                             end                             
    endcase
  end
  always @(posedge mclk)
  begin : MEM_FSM_SEQ
     mem_fsm_state_mclk_ff <= mem_fsm_next_mclk;
  end
         
  
  // The splicing register is used to splice each ingress 32bit word to 128bit word for the output buffer or the memory
  always @(posedge mclk)
  begin : SPLICING_REGISTER_FF
    if (splicing_register_load_mclk) begin
      case (transfer_in_size_cnt_mclk[1:0])
        2'd0 : splicing_register_mclk_ff[ 31: 0] <= selected_stream_data_mclk;
        2'd1 : splicing_register_mclk_ff[ 63:32] <= selected_stream_data_mclk;
        2'd2 : splicing_register_mclk_ff[ 95:64] <= selected_stream_data_mclk;
        2'd3 : splicing_register_mclk_ff[127:96] <= selected_stream_data_mclk;
      endcase      
    end    
  end
      
  
  // Indicate that the splicing register has the last sample, such that the last write of the transfer
  // will happen whenever the output buffer or the memory are ready for the data.
  always @(posedge mclk)
  begin : SPLICING_REGISTER_HAS_LAST_FF
     if (splicing_register_load_mclk & selected_stream_last_mclk) begin
       splicing_register_has_last_mclk_ff <= 1'b1;
     end
     if (last_sample_registered_mclk) begin
       splicing_register_has_last_mclk_ff <= 1'b0;     
     end
  end  
  
  
  // Indicate when was the last sample registered so that the size of the transfer can also be registered. 
  reg  last_sample_registered_mclk_ff = 1'b0;
  always @(posedge mclk)
  begin : LAST_SAMPLE_REGISTERED_FF
    last_sample_registered_mclk_ff <= last_sample_registered_mclk;
  end
  
  
  // An inclusive full indication of the output buffer, which takes into account pending read requests from the memory.
  // Use "OUTPUT_BUFFER_AT_ALMOST_WRITE_DEPTH" instead of the theoretical "OUTPUT_BUFFER_WRITE_DEPTH" for robustness.
  always @(posedge mclk)
  begin : OUTPUT_BUFFER_LOOKAHEAD_FULL_FF
    output_buffer_lookahead_full_mclk_ff <= (({{(32-OUTPUT_BUFFER_WR_USE_CNT_WIDTH){1'b0}},output_buffer_use_cnt_mclk} + mem_pending_rd_req_cnt_mclk) >= OUTPUT_BUFFER_AT_ALMOST_WRITE_DEPTH);
  end
    
  
  // Count how many incoming 32bit samples are contained in each incoming transfer.
  // This count might be registered to the transfer size buffer after the last sample is registered.
  sync_upcnt #(
    .CNT_WIDTH(TRANSFER_SIZE_CNT_WIDTH),
    .INC_VALUE(1),                   
    .INC_WIDTH(1),
    .INIT_VALUE({TRANSFER_SIZE_CNT_WIDTH{1'b0}})        
  )
  transfer_in_size_counter (
    .clk(mclk),
    .ce(transfer_in_size_cnt_en_mclk),
    .sclr(last_sample_registered_mclk_ff),
    .q(transfer_in_size_cnt_mclk)
  );
  assign transfer_size_buffer_din_mclk[`TRANSFER_SIZE_32BIT_WORDS] = transfer_in_size_cnt_mclk;
  
  
  // Increment on the end of each transfer.
  // This count might be registered to the transfer size buffer after the last sample is registered.
  sync_upcnt #(
    .CNT_WIDTH(TRANSFERS_CNT_WIDTH),
    .INC_VALUE(1),                   
    .INC_WIDTH(1),
    .INIT_VALUE({{(TRANSFERS_CNT_WIDTH-1){1'b0}},1'b1})        
  )
  transfers_in_counter (
    .clk(mclk),
    .ce(last_sample_registered_mclk_ff),
    .sclr(transfer_size_buffer_wren_mclk),
    .q(transfers_in_cnt_mclk)
  );
  assign transfer_size_buffer_din_mclk[`NUM_TRANSFERS_SINCE_LAST_REGISTERED] = transfers_in_cnt_mclk;  
  
  
  // If we got a transfer which is not full, or have counted up to the maximum number of transfers 
  // without a registered entry, register the current transfer with the transfer size buffer.
  assign transfer_size_buffer_wren_mclk = last_sample_registered_mclk_ff & 
                                          ( (transfer_in_size_cnt_mclk != INGRESS_FULL_TRANSFER_SIZE_IN_32BIT_WORDS[TRANSFER_SIZE_CNT_WIDTH-1:0]) | 
                                            (transfers_in_cnt_mclk == MAX_NUM_TRANSFERS_NOT_REGISTERED)                                            );
      

  // Memory use counter.
  // Indicate memory fill state.
  // Increment on write, decrement on read.
  sync_upcnt_downcnt #(
    .CNT_WIDTH(MEM_USE_CNT_WIDTH),
    .INC_VALUE(1),                   
    .INC_WIDTH(1),
    .DEC_VALUE(1),
    .DEC_WIDTH(1),
    .INC_DEC_VALUE(0),
    .INC_DEC_WIDTH(1),
    .INIT_VALUE({MEM_USE_CNT_WIDTH{1'b0}})        
  )
  mem_use_counter (
    .clk(mclk),
    .inc(mem_wdf_wren_mclk),
    .dec(mem_rden_mclk),
    .sclr(),
    .q(mem_use_cnt_mclk)
  );
  assign mem_buffer_almost_empty_mclk = (mem_use_cnt_mclk <= {{(MEM_USE_CNT_WIDTH-1){1'b0}},1'b1});
  assign mem_buffer_empty_mclk = (mem_use_cnt_mclk == {MEM_USE_CNT_WIDTH{1'b0}});
  assign mem_buffer_full_mclk = (mem_use_cnt_mclk == MEM_CAPACITY_IN_128BIT_WORDS);
  assign mem_use_cnt_in_16bytes_mclk = mem_use_cnt_mclk;
         
    
  // Memory pending read requests counter.
  // Indicate how many read requests were issued and haven't been acknowledged yet.
  sync_upcnt_downcnt #(
    .CNT_WIDTH(MEM_PENDING_RD_REQ_CNT_WIDTH),
    .INC_VALUE(1),                   
    .INC_WIDTH(1),
    .DEC_VALUE(1),
    .DEC_WIDTH(1),
    .INC_DEC_VALUE(0),
    .INC_DEC_WIDTH(1),
    .INIT_VALUE({MEM_PENDING_RD_REQ_CNT_WIDTH{1'b0}})        
  )
  mem_pending_rd_counter (
    .clk(mclk),
    .inc(mem_rden_mclk),
    .dec(mem_rd_data_valid_mclk),
    .sclr(),
    .q(mem_pending_rd_req_cnt_mclk)
  );
  assign no_pending_mem_rd_req_mclk = (mem_pending_rd_req_cnt_mclk == {MEM_PENDING_RD_REQ_CNT_WIDTH{1'b0}});     

 
  // Memory write address counter.
  // Cyclic incremental linear addressing.
  wire mem_wr_last_addr_mclk;
  sync_upcnt #(
    .CNT_WIDTH(MEM_ADDR_WIDTH),
    .INC_VALUE(8),                   
    .INC_WIDTH(4),
    .INIT_VALUE({MEM_ADDR_WIDTH{1'b0}})        
  )
  mem_wr_addr_counter (
    .clk(mclk),
    .ce(mem_wdf_wren_mclk),
    .sclr(mem_wr_last_addr_mclk),
    .q(mem_wr_addr_mclk)
  );
  assign mem_wr_last_addr_mclk = (mem_wr_addr_mclk == MEM_ADDR_LAST) & mem_wdf_wren_mclk;
  
 
  // Memory read address counter.
  // Cyclic incremental linear addressing.
  wire mem_rd_last_addr_mclk;
  sync_upcnt #(
    .CNT_WIDTH(MEM_ADDR_WIDTH),
    .INC_VALUE(8),                   
    .INC_WIDTH(4),
    .INIT_VALUE({MEM_ADDR_WIDTH{1'b0}})        
  )
  mem_rd_addr_counter (
    .clk(mclk),
    .ce(mem_rden_mclk),
    .sclr(mem_rd_last_addr_mclk),
    .q(mem_rd_addr_mclk)
  );
  assign mem_rd_last_addr_mclk = (mem_rd_addr_mclk == MEM_ADDR_LAST) & mem_rden_mclk;
    
    
  // An indication which will stay asserted form the read all memory request, until the last memory read.
  always @(posedge mclk)
  begin :READ_ALL_MEMORY_FF
    if (read_all_memory_mclk) begin
      read_all_memory_mclk_ff <= 1'b1;
    end    
    if (read_all_memory_done_mclk) begin
      read_all_memory_mclk_ff <= 1'b0;
    end
  end 
    
  
  // Memory controller provides access to ddr memory.
  // Logic uses a linear addressing scheme, just like a fifo, with cyclic write and read pointers.
  ddr2 ddr2 (
    .ddr2_dq(ddr_dq),
    .ddr2_dqs_n(ddr_dqs_n),
    .ddr2_dqs_p(ddr_dqs_p),
    .ddr2_addr(ddr_a),
    .ddr2_ba(ddr_b),
    .ddr2_ras_n(ddr_ras),
    .ddr2_cas_n(ddr_cas),
    .ddr2_we_n(ddr_we),
    .ddr2_ck_p(ddr_clk_p),
    .ddr2_ck_n(ddr_clk_n),
    .ddr2_cke(ddr_ce),
    .ddr2_dm(ddr_dqm),
    .ddr2_odt(ddr_odt),
    .sys_clk_i(sys_clk_gated),
    .clk_ref_i(sys_clk_gated),
    .app_addr({1'b0, mem_addr_mclk}),
    .app_cmd(mem_cmd_mclk),
    .app_en(mem_rden_mclk | mem_wdf_wren_mclk),
    .app_wdf_data(splicing_register_mclk_ff),
    .app_wdf_end(mem_wdf_wren_mclk),
    .app_wdf_mask(16'b0),
    .app_wdf_wren(mem_wdf_wren_mclk),
    .app_rd_data(mem_rd_data_mclk),
    .app_rd_data_end(),
    .app_rd_data_valid(mem_rd_data_valid_mclk),
    .app_rdy(mem_adf_rdy_mclk),
    .app_wdf_rdy(mem_wdf_rdy_mclk),
    .app_sr_req(1'b0),
    .app_ref_req(1'b0),
    .app_zq_req(1'b0),
    .app_sr_active(),
    .app_ref_ack(),
    .app_zq_ack(),
    .ui_clk(mem_clk),
    .ui_clk_sync_rst(),
    .init_calib_complete(mem_init_done),
    .device_temp_i(12'b0),    
    .sys_rst(hold_mem_in_reset_gclk_ff[2])
  );       
  
  
  ////////////////////////////////////////////////////////////////////////////////////////////////////////////
  //                                            GCLK DOMAIN                                                 //
  ////////////////////////////////////////////////////////////////////////////////////////////////////////////     
  // Indication that the output buffer has one or more egress transfers ready.
  // Either the transfer size buffer is not empty and so does the memory (which means the output buffer has at least one transfer
  // that is not full), or the output buffer has at least one full transfer.
  // In the last case, the transfer size buffer may still be empty (see comment on the 
  // transfer_size_buffer next to its instantiation).
  assign has_at_least_one_egress_transfer_gclk = (~transfer_size_buffer_empty_gclk & mem_buffer_empty_gclk & no_pending_mem_rd_req_gclk) | 
                                                 ({{(32-OUTPUT_BUFFER_RD_USE_CNT_WIDTH){1'b0}},output_buffer_use_cnt_gclk} >= INGRESS_FULL_TRANSFER_SIZE_IN_128BIT_WORDS); 
    
    
  // Indication that the last sample from the output buffer was transmitted.
  assign last_egress_sample_shifted_gclk = m_tlast_gclk & m_tready_gclk;
  
  
  // One 32bit sample was shifted to the egress master.
  assign egress_sample_shifted_gclk = m_tready_gclk & sample_valid_gclk_ff;
  
  
  // Load the shift register with the next word from the output buffer as soon as valid asserts or when
  // finished shifting out 4 32bit wide, egress words (and not on the last one).
  assign load_splitting_register_gclk = (~sample_valid_gclk_ff & has_at_least_one_egress_transfer_gclk) | 
                                        (egress_sample_shifted_gclk & (transfer_out_size_cnt_gclk[1:0] == 2'd0) & ~(last_egress_sample_shifted_gclk));  
  
  
  // The splitting register is used to divide each ingress 128bit word stored in the output buffer to 4 egress 32 bit words,
  // which are transmitted to the egress AXI master. 
  reg  [127:0] splitting_register_gclk_ff;
  always @(posedge gclk)
  begin : SPLITTING_REGISTER_FF
    // Load (see comment above).
    if (load_splitting_register_gclk) begin
      splitting_register_gclk_ff <= output_buffer_dout_gclk;
    end    
    // Shift to the next 32bit word when the previous word was shifted to the egress AXI master.    
    else if (egress_sample_shifted_gclk) begin
      splitting_register_gclk_ff[127:0] <= {32'b0, splitting_register_gclk_ff[127:32]};
    end
  end
  
  
  // Assert valid only after we have full transfer ready.
  // Deassert with last rd, and assert one cycle after if there is another transfer pending and reset was not asserted.
  always @(posedge gclk)
  begin : SAMPLE_VALID_FF
    if (has_at_least_one_egress_transfer_gclk) begin
      sample_valid_gclk_ff <= 1'b1;
    end   
    if (last_egress_sample_shifted_gclk) begin
      sample_valid_gclk_ff <= 1'b0;
    end
  end
  
  
  // Urgency decision logic is based on the state of the output buffer and the memory fill level.
  reg  [1:0] urgency_level_gclk_ff = URGENCY_NONE;
  always @(posedge gclk)
  begin : URGENCY_LEVEL_FF
    if (has_at_least_one_egress_transfer_gclk) begin
      if (~mem_buffer_empty_gclk) begin
        urgency_level_gclk_ff <= URGENCY_HIGH;
      end
      else begin
        urgency_level_gclk_ff <= URGENCY_LOW;
      end
    end
    else begin
      urgency_level_gclk_ff <= URGENCY_NONE;       
    end
  end  
  
  
  // Count how many outgoing 32bit samples are contained in each outgoing transfer.
  sync_upcnt #(
    .CNT_WIDTH(TRANSFER_SIZE_CNT_WIDTH),
    .INC_VALUE(1),                   
    .INC_WIDTH(1),
    .INIT_VALUE({{(TRANSFER_SIZE_CNT_WIDTH-1){1'b0}},1'b1})        
  )
  transfer_out_size_counter (
    .clk(gclk),
    .ce(egress_sample_shifted_gclk),
    .sclr(last_egress_sample_shifted_gclk),
    .q(transfer_out_size_cnt_gclk)
  );
  
  
  // Count the number of transfers shifted out to the egress AXI master until we find a transfer with a valid entry in the
  // transfer size buffer. Wait until the end of that transfer and restart the count.
  wire found_registered_transfer_gclk;
  wire transfer_size_buffer_rden_gclk;
  sync_upcnt #(
    .CNT_WIDTH(TRANSFERS_CNT_WIDTH),
    .INC_VALUE(1),                   
    .INC_WIDTH(1),
    .INIT_VALUE({{(TRANSFERS_CNT_WIDTH-1){1'b0}},1'b1})        
  )
  transfers_out_counter (
    .clk(gclk),
    .ce(last_egress_sample_shifted_gclk),
    .sclr(transfer_size_buffer_rden_gclk),
    .q(transfers_out_cnt_gclk)
  );      
  assign found_registered_transfer_gclk = ~transfer_size_buffer_empty_gclk & (transfers_out_cnt_gclk == transfer_size_buffer_dout_gclk[`NUM_TRANSFERS_SINCE_LAST_REGISTERED]);
  assign transfer_size_buffer_rden_gclk = found_registered_transfer_gclk & last_egress_sample_shifted_gclk;
    
  
  // Output assignments.
  // Notice the last assignment, which asserts if we shifted out a full transfer or
  // we found a transfer with a registered entry in the transfer size buffer.
  assign m_tvalid_gclk = sample_valid_gclk_ff;
  assign m_tlast_gclk = m_tvalid_gclk & (
                        (transfer_out_size_cnt_gclk == INGRESS_FULL_TRANSFER_SIZE_IN_32BIT_WORDS) |
                        (found_registered_transfer_gclk & (transfer_out_size_cnt_gclk == transfer_size_buffer_dout_gclk[`TRANSFER_SIZE_32BIT_WORDS])) );
  assign m_tdata_gclk = splitting_register_gclk_ff[31:0];
  assign urgency_level_gclk = urgency_level_gclk_ff;
  
  
  // Synchronize mem_init_done, a long async indication, to gclk, in order to help control mclk mux
  // and tell if the memory is ready.
  synchronizer_1bit mem_init_done_sync (
    .clk(gclk),  
    .async_in(mem_init_done), 
    .sync_out(mem_init_done_gclk)
  );            
  
  
  // If a memory enable flow was initiated, wait for a rising edge on init done (calibration complete) indication 
  // to switch the mclk mux to the clock from the memory controller.
  // If a memory disable flow was initiated, we can switch to gclk immediately.
  // With the clock switch, we also indicate to the mclk side its current state.
  reg  mclk_mux_select_gclk_ff = SELECT_DCLK;
  reg [2:0] mem_state_gclk_ff = {MEM_DISABLED, MEM_DISABLED, MEM_DISABLED};
  reg  mem_init_done_gclk_ff = 1'b0;  
  always @(posedge gclk)
  begin : MCLK_MUX_SELECT_STATE_FF
    mem_init_done_gclk_ff <= mem_init_done_gclk;
    if (~mem_init_done_gclk_ff & mem_init_done_gclk) begin
      mclk_mux_select_gclk_ff <= SELECT_MEM_CLK;
      mem_state_gclk_ff[0] <= MEM_ENABLED;      
    end
    if (trigger_mem_disable_flow_gclk) begin
      mclk_mux_select_gclk_ff <= SELECT_DCLK;
      mem_state_gclk_ff[0] <= MEM_DISABLED;      
    end  
    mem_state_gclk_ff[1] <= mem_state_gclk_ff[0]; 
    mem_state_gclk_ff[2] <= mem_state_gclk_ff[1];                       
  end    
  
  
  // Egress clock domain is used to select how the ingress is clocked, from the memory clk or from the egress clk.
  BUFGMUX mclk_mux (
    .O(mclk),
    .I0(mem_clk),
    .I1(dclk),
    .S(mclk_mux_select_gclk_ff)
  );
  
  
  // Clk gate the memory controller clk if it is held in reset to save power.
  BUFGCE sys_clk_gate (
    .O(sys_clk_gated),
    .CE(~hold_mem_in_reset_gclk_ff[2]),
    .I(sys_clk) 
  );
         
  
  // Memory enable/disable logic is triggered by MEM_FSM in an idle state.
  // It is then synchronized to the egress gclk domain, which controls the memory
  // controller state.
  reg  vtt_en_gclk_ff = 1'b0;
  reg  ddr_cs_gclk_ff = MEM_DISABLED;   
  always @(posedge gclk)
  begin : MEM_ENABLE_DISABLE_LOGIC
    if (trigger_mem_enable_flow_gclk) begin 
      vtt_en_gclk_ff <= 1'b1;
      ddr_cs_gclk_ff <= MEM_ENABLED;      
      hold_mem_in_reset_gclk_ff[0] <= 1'b0;
    end     
    if (trigger_mem_disable_flow_gclk) begin
      vtt_en_gclk_ff <= 1'b0;
      ddr_cs_gclk_ff <= MEM_DISABLED;    
      hold_mem_in_reset_gclk_ff[0] <= 1'b1;
    end
    hold_mem_in_reset_gclk_ff[1] <= hold_mem_in_reset_gclk_ff[0];
    hold_mem_in_reset_gclk_ff[2] <= hold_mem_in_reset_gclk_ff[1];    
  end    
  
  // Include buffers, to be consistent with all other DDR2 signals which are buffered inside the mig.
  OBUF #(
    .DRIVE(12),   
    .IOSTANDARD("LVCMOS18"), 
    .SLEW("SLOW") 
  )
  obuf_ddr2_vtt_en (
    .O(vtt_en),     
    .I(vtt_en_gclk_ff)    
  );
  
  OBUF #(
    .DRIVE(12),   
    .IOSTANDARD("LVCMOS18"), 
    .SLEW("SLOW") 
  )
  obuf_ddr2_cs (
    .O(ddr_cs),     
    .I(ddr_cs_gclk_ff)    
  );          
    
  
  ////////////////////////////////////////////////////////////////////////////////////////////////////////////
  //                                            GCLK MCLK CDC                                               //
  ////////////////////////////////////////////////////////////////////////////////////////////////////////////   
  // Output buffer is used to cross between mclk domain and gclk domain.
  // Data directly from any ingress channel (memory bypass path) or from the memory will be stored
  // here for the egress master to read.
  // Since the ingress side is 128bits wide and the egress side is 32bits wide, the gclk side
  // is using a splitting register to slice the words from the output buffer.
  output_buffer output_buffer (
    .rst(1'b0),
    .wr_clk(mclk),        
    .rd_clk(gclk),               
    .din(output_buffer_din_mclk),     
    .wr_en(output_buffer_wren_mclk),                   
    .rd_en(load_splitting_register_gclk),            
    .dout(output_buffer_dout_gclk),           
    .full(),
    .prog_full(output_buffer_full_mclk),
    .empty(output_buffer_empty_gclk),
    .rd_data_count(output_buffer_use_cnt_gclk),
    .wr_data_count(output_buffer_use_cnt_mclk)
  );     
  
  
  // A fifo to efficiently contain the size of each transfer.
  // The idea is to register entries, only for transfers that are not full. Therefore, we store the #full transfers between non full transfers and their size.
  // We also register a transfer every MAX_NUM_TRANSFERS_NOT_REGISTERED, even if it is full, to constrain the number of #full transfers to store.
  // On the write side, we register the size of an incoming transfer whenever a it is smaller than a full size transfer or every MAX_NUM_TRANSFERS_NOT_REGISTERED.
  // This is an optimzation which is used instead of storing the size of every transfer.
  // On the read side, we count transfers using transfers_out_counter and the number of samples in each transfer using the egress_sample_out_counter.
  // Once the number of samples is equivalent to a full transfer, or we counted up to a transfer that was registered in the transfer size buffer and 
  // up to the corresponding number of samples, we indicate a last. 
  transfer_size_buffer transfer_size_buffer (
    .rst(1'b0),
    .wr_clk(mclk),        
    .rd_clk(gclk),               
    .din(transfer_size_buffer_din_mclk),     
    .wr_en(transfer_size_buffer_wren_mclk),                   
    .rd_en(transfer_size_buffer_rden_gclk),            
    .dout(transfer_size_buffer_dout_gclk),         
    .full(transfer_size_buffer_full_mclk),
    .empty(transfer_size_buffer_empty_gclk)
  );    
  
  
  // Synchronize mem_buffer_empty, a long indication, to egress clk domain.
  // The egress side is using the mem_buffer_empty indication to decide on the urgency level.
  synchronizer_1bit mem_buffer_empty_sync (
   .clk(gclk),  
   .async_in(mem_buffer_empty_mclk), 
   .sync_out(mem_buffer_empty_gclk)
  );
  
  
  // Synchronize no_pending_mem_rd_req, to the egress clk domain such that it can tell if all the requests
  // from the memory buffer were acknowledged. 
  synchronizer_1bit no_pending_mem_rd_req_sync (  
    .clk(gclk),
    .async_in(no_pending_mem_rd_req_mclk),
    .sync_out(no_pending_mem_rd_req_gclk)
  );
  
  
  // Synchronize trigger_mem_enable_flow_mclk to gclk domain which contains the enable/disable logic.
  synchronizer_1bit trigger_mem_enable_flow_sync (
    .clk(mclk),  
    .async_in(trigger_mem_enable_flow_mclk), 
    .sync_out(trigger_mem_enable_flow_gclk)
  );
  
  
  // Synchronize trigger_mem_enable_flow_mclk to gclk domain which contains the enable/disable logic. 
  synchronizer_1bit trigger_mem_disable_flow_sync (
    .clk(mclk),  
    .async_in(trigger_mem_disable_flow_mclk), 
    .sync_out(trigger_mem_disable_flow_gclk)
  );   
      
      
  // Synchronize the memory state indication which is controlled by gclk to the mclk domain.
  // This way, we can tell when is it safe to continue operation on mclk side. 
  synchronizer_1bit mem_state_sync (
    .clk(mclk),  
    .async_in(mem_state_gclk_ff[2]), 
    .sync_out(mem_state_mclk)
  );
  assign mem_enabled_mclk = (mem_state_mclk == MEM_ENABLED) & sys_clk_and_gclk_locked_mclk;
  assign mem_disabled_mclk = (mem_state_mclk == MEM_DISABLED) & sys_clk_and_gclk_locked_mclk;       
        
  
endmodule