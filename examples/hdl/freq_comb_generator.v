`timescale 1ns / 1ps
module freq_comb_generator (
	(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
	(* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axis_config:m_axis_freq_comb_data" *)
	input aclk,
	(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_config TVALID" *)
	(* X_INTERFACE_PARAMETER = "CLK_DOMAIN aclk" *)
	input s_axis_config_tvalid,
	(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_config TDATA" *)
	input [31:0] s_axis_config_tdata,
	(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis_config TREADY" *)
	output s_axis_config_tready,
	(* X_INTERFACE_PARAMETER = "CLK_DOMAIN aclk" *)	
	output m_axis_freq_comb_data_tvalid,
	output [31:0] m_axis_freq_comb_data_tdata
);

	/////////////////////////////////////////////////
	//                PARAMETERS                   //
	/////////////////////////////////////////////////
	localparam CONFIG_FSM_WIDTH = 3;
	localparam CONFIG_FSM_WAIT_START = 3'd0;
	localparam CONFIG_FSM_ADDRESS = 3'd1;
	localparam CONFIG_FSM_DATA = 3'd2;
	localparam CONFIG_FSM_STOP = 3'd3;
	localparam NUM_HARMONICS = 256;
	localparam CONFIG_FSM_START_WORD = 32'd511;
	localparam CONFIG_FSM_STOP_WORD = 32'd512;

	/////////////////////////////////////////////////
	//              SIGNAL DECLARATION             //
	/////////////////////////////////////////////////

	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//                                       Design starts here                                               //
	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// config FSM control.
	reg [CONFIG_FSM_WIDTH-1:0] config_fsm_next;
	reg [CONFIG_FSM_WIDTH-1:0] config_fsm_state_ff = CONFIG_FSM_WAIT_START;
	reg wait_for_address;
	reg wait_for_data;
	reg register_config_store;
	reg reset_config_store;
	always @*
	begin : CONFIG_FSM
		config_fsm_next = CONFIG_FSM_WAIT_START;
		wait_for_address = 1'b0;
		wait_for_data = 1'b0;
		register_config_store = 1'b0;
		reset_config_store = 1'b0;

		case(config_fsm_state_ff)
			CONFIG_FSM_WAIT_START: begin
				if (s_axis_config_tvalid & (s_axis_config_tdata == CONFIG_FSM_START_WORD)) begin
					config_fsm_next = CONFIG_FSM_ADDRESS;
				end
				else begin
					config_fsm_next = CONFIG_FSM_WAIT_START;
				end
			end

			CONFIG_FSM_ADDRESS: begin
				wait_for_address = 1'b1;
				if (s_axis_config_tvalid) begin
					if (s_axis_config_tdata == CONFIG_FSM_STOP_WORD) begin
						register_config_store = 1'b1;
						config_fsm_next = CONFIG_FSM_STOP;
					end
					else begin
						config_fsm_next = CONFIG_FSM_DATA;
					end
				end
				else begin
					config_fsm_next = CONFIG_FSM_ADDRESS;
				end
			end

			CONFIG_FSM_DATA: begin
				wait_for_data = 1'b1;
				if (s_axis_config_tvalid) begin
					config_fsm_next = CONFIG_FSM_ADDRESS;
				end
				else begin
					config_fsm_next = CONFIG_FSM_DATA;
				end
			end
			
			CONFIG_FSM_STOP: begin
				reset_config_store = 1'b1;
				config_fsm_next = CONFIG_FSM_WAIT_START;
			end
		endcase
	end

	// config FSM sequential.
	always @(posedge aclk)
	begin : CONFIG_FSM_STATE_FF
		config_fsm_state_ff <= config_fsm_next;
	end

	wire signed [15:0] i_channel[NUM_HARMONICS-1:0];
	wire signed [15:0] q_channel[NUM_HARMONICS-1:0];
	wire [NUM_HARMONICS-1:0] m_axis_data_tvalid;
	wire [NUM_HARMONICS-1:0] address_config_valid;
	reg [NUM_HARMONICS-1:0] config_valid_store_1;
	reg [NUM_HARMONICS-1:0] next_address_to_write = {NUM_HARMONICS{1'b0}};
	reg [31:0] config_data_store_1 [NUM_HARMONICS-1:0]; 
	reg [NUM_HARMONICS-1:0] config_valid_store_2 = {NUM_HARMONICS{1'b0}};
	genvar i;
	generate
	for (i = 0; i < NUM_HARMONICS; i = i + 1) begin : dds_generator
		// Decode addressing.
		assign address_config_valid[i] = wait_for_address & s_axis_config_tvalid & (s_axis_config_tdata == i);

		// Store configuration address & data (which appear at different stages) to synchronize the configuration.
		// Reset after registering the configuration to get ready for another synchronized configuration cycle.
		always @(posedge aclk)
		begin : CONFIG_STORE_FF
			if (address_config_valid[i]) begin
				config_valid_store_1[i] <= address_config_valid[i];
				next_address_to_write[i] <= address_config_valid[i];
			end
			if (wait_for_data & s_axis_config_tvalid & next_address_to_write[i]) begin
				config_data_store_1[i] <= s_axis_config_tdata;
				next_address_to_write[i] <= 1'b0;
			end
			if (register_config_store) begin
				config_valid_store_2[i] <= config_valid_store_1[i];
			end
			if (reset_config_store) begin
				config_data_store_1[i] <= 32'b0;
				config_valid_store_2[i] <= {NUM_HARMONICS{1'b0}};
			end
		end

		// DDS instances.
		dds_compiler_multi dds (
			//.aresetn(1'b1),
			.aclk(aclk),
			.s_axis_config_tvalid(config_valid_store_2[i]),
			.s_axis_config_tdata(config_data_store_1[i]),
			.m_axis_data_tvalid(m_axis_data_tvalid[i]),
			.m_axis_data_tdata({q_channel[i], i_channel[i]}),
			.m_axis_phase_tvalid(),
			.m_axis_phase_tdata()
		);
	end
	endgenerate

	reg signed [16:0] add_result_i_0 [127:0];
	reg signed [17:0] add_result_i_1 [63:0];
	reg signed [18:0] add_result_i_2 [31:0];
	reg signed [19:0] add_result_i_3 [15:0];
	reg signed [20:0] add_result_i_4 [7:0];
	reg signed [21:0] add_result_i_5 [3:0];
	reg signed [22:0] add_result_i_6 [1:0];
	reg signed [23:0] add_result_i_7;
	reg signed [16:0] add_result_q_0 [127:0];
	reg signed [17:0] add_result_q_1 [63:0];
	reg signed [18:0] add_result_q_2 [31:0];
	reg signed [19:0] add_result_q_3 [15:0];
	reg signed [20:0] add_result_q_4 [7:0];
	reg signed [21:0] add_result_q_5 [3:0];
	reg signed [22:0] add_result_q_6 [1:0];
	reg signed [23:0] add_result_q_7;
	reg [127:0] add_result_valid_0;
	reg [63:0] add_result_valid_1;
	reg [31:0] add_result_valid_2;
	reg [15:0] add_result_valid_3;
	reg [7:0] add_result_valid_4;
	reg [3:0] add_result_valid_5;
	reg [1:0] add_result_valid_6;
	reg add_result_valid_7;
	genvar g;
	generate
	for (g = 0; g < (NUM_HARMONICS-1); g = g + 2) begin : adder_generator
		always @(posedge aclk)
		begin : ADD_RESULT_0
			add_result_i_0[g/2] <= i_channel[g] + i_channel[g+1];
			add_result_q_0[g/2] <= q_channel[g] + q_channel[g+1];
			add_result_valid_0[g/2] <= m_axis_data_tvalid[g] & m_axis_data_tvalid[g+1];
		end

		if (g < 127)
			always @(posedge aclk)
			begin : ADD_RESULT_1
				add_result_i_1[g/2] <= add_result_i_0[g] + add_result_i_0[g+1];
				add_result_q_1[g/2] <= add_result_q_0[g] + add_result_q_0[g+1];
				add_result_valid_1[g/2] <= add_result_valid_0[g] & add_result_valid_0[g+1];
			end

		if (g < 63)
			always @(posedge aclk)
			begin : ADD_RESULT_2
				add_result_i_2[g/2] <= add_result_i_1[g] + add_result_i_1[g+1];
				add_result_q_2[g/2] <= add_result_q_1[g] + add_result_q_1[g+1];
				add_result_valid_2[g/2] <= add_result_valid_1[g] & add_result_valid_1[g+1];
			end

		if (g < 31)
			always @(posedge aclk)
			begin : ADD_RESULT_3
				add_result_i_3[g/2] <= add_result_i_2[g] + add_result_i_2[g+1];
				add_result_q_3[g/2] <= add_result_q_2[g] + add_result_q_2[g+1];
				add_result_valid_3[g/2] <= add_result_valid_2[g] & add_result_valid_2[g+1];
			end

		if (g < 15)
			always @(posedge aclk)
			begin : ADD_RESULT_4
				add_result_i_4[g/2] <= add_result_i_3[g] + add_result_i_3[g+1];
				add_result_q_4[g/2] <= add_result_q_3[g] + add_result_q_3[g+1];
				add_result_valid_4[g/2] <= add_result_valid_3[g] & add_result_valid_3[g+1];
			end

		if (g < 7)
			always @(posedge aclk)
			begin : ADD_RESULT_5
				add_result_i_5[g/2] <= add_result_i_4[g] + add_result_i_4[g+1];
				add_result_q_5[g/2] <= add_result_q_4[g] + add_result_q_4[g+1];
				add_result_valid_5[g/2] <= add_result_valid_4[g] & add_result_valid_4[g+1];
			end

		if (g < 3)
			always @(posedge aclk)
			begin : ADD_RESULT_6
				add_result_i_6[g/2] <= add_result_i_5[g] + add_result_i_5[g+1];
				add_result_q_6[g/2] <= add_result_q_5[g] + add_result_q_5[g+1];
				add_result_valid_6[g/2] <= add_result_valid_5[g] & add_result_valid_5[g+1];
			end

		if (g < 1)
			always @(posedge aclk)
			begin : ADD_RESULT_7
				add_result_i_7 <= add_result_i_6[g] + add_result_i_6[g+1];
				add_result_q_7 <= add_result_q_6[g] + add_result_q_6[g+1];
				add_result_valid_7 <= add_result_valid_6[g] & add_result_valid_6[g+1];
			end
	end
	endgenerate
	assign m_axis_freq_comb_data_tdata = {add_result_q_7[23:8] ,add_result_i_7[23:8]};
	assign m_axis_freq_comb_data_tvalid = add_result_valid_7;
	
	// The configuration interface is always ready to accept data.
	assign s_axis_config_tready = 1'b1;
endmodule

