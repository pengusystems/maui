`timescale 1ns / 1ps
module sreg_tb;

  	reg clk = 1'b0;
  	always
  	begin
  	  #50 clk = ~clk;
  	end
  
  	sreg #(
		.WIDTH(4),
		.DEPTH(10)
	)
	uut (
		.clk(clk),
		.ce(1'b1),
		.sclr(1'b0),
		.d(4'b1),
		.q()
	);

endmodule
