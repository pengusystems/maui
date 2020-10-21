module sreg #(
	parameter WIDTH  = 4,
	parameter DEPTH = 3,
)
(
	input clk,
	input ce,
	input sclr,
	input [WIDTH-1:0] d,
	output [WIDTH-1:0] q
);

	/////////////////////////////////////////////////
	//               PARAMETERS                    //
	///////////////////////////////////////////////// 

	/////////////////////////////////////////////////
	//            SIGNAL DECLARATION               //
	/////////////////////////////////////////////////
	reg [WIDTH-1:0] sr[DEPTH-1:0];

	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//                                            Design starts here                                          //
	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Input.
	assign sr[0] = d;

	// The shift register.
	always @(posedge clk)
	begin
		if (sclr) begin
			for (integer ii = 1; ii < DEPTH; ii = ii+1) begin
				sr[ii] <= {WIDTH{1'b0}};
			end
		end
		else if (ce) begin
			for (integer ii = 1; ii < DEPTH; ii = ii+1) begin
				sr[ii] <= sr[ii-1];
			end
		end
	end

	// Output.
	assign q = sr[DEPTH-1];

endmodule
