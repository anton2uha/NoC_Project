
// ============================================================================
// Crossbar Switch (CBS) 
// ============================================================================
module CrossBarSwitch (
	// Input data
	input wire [63:0] northBuf, eastBuf, southBuf, westBuf, localBuf,
	
	// Input valid signals
	input wire northBuf_valid, eastBuf_valid, southBuf_valid, westBuf_valid, localBuf_valid,
	
	// Input VC signals 
	input wire [1:0] northBuf_vc, eastBuf_vc, southBuf_vc, westBuf_vc, localBuf_vc,
	
	// Select signals from CBA
	input wire [2:0] north_out_select,
	input wire [2:0] east_out_select,
	input wire [2:0] south_out_select,
	input wire [2:0] west_out_select,
	input wire [2:0] local_out_select,
	
	// Output data
	output wire [63:0] northOut, eastOut, southOut, westOut, localOut,
	
	// Output valid signals 
	output wire northOut_valid, eastOut_valid, southOut_valid, westOut_valid, localOut_valid,
	
	// Output VC signals
	output wire [1:0] northOut_vc, eastOut_vc, southOut_vc, westOut_vc, localOut_vc
);

	// ========================================================================
	// Data Routing 
	// ========================================================================
	assign northOut = (north_out_select == 3'b000) ? northBuf :
	                   (north_out_select == 3'b001) ? eastBuf :
	                   (north_out_select == 3'b010) ? southBuf :
	                   (north_out_select == 3'b011) ? westBuf :
	                   (north_out_select == 3'b100) ? localBuf : 64'b0;
	
	assign eastOut = (east_out_select == 3'b000) ? northBuf :
	                  (east_out_select == 3'b001) ? eastBuf :
	                  (east_out_select == 3'b010) ? southBuf :
	                  (east_out_select == 3'b011) ? westBuf :
	                  (east_out_select == 3'b100) ? localBuf : 64'b0;
	
	assign southOut = (south_out_select == 3'b000) ? northBuf :
	                   (south_out_select == 3'b001) ? eastBuf :
	                   (south_out_select == 3'b010) ? southBuf :
	                   (south_out_select == 3'b011) ? westBuf :
	                   (south_out_select == 3'b100) ? localBuf : 64'b0;
	
	assign westOut = (west_out_select == 3'b000) ? northBuf :
	                  (west_out_select == 3'b001) ? eastBuf :
	                  (west_out_select == 3'b010) ? southBuf :
	                  (west_out_select == 3'b011) ? westBuf :
	                  (west_out_select == 3'b100) ? localBuf : 64'b0;
	
	assign localOut = (local_out_select == 3'b000) ? northBuf :
	                   (local_out_select == 3'b001) ? eastBuf :
	                   (local_out_select == 3'b010) ? southBuf :
	                   (local_out_select == 3'b011) ? westBuf :
	                   (local_out_select == 3'b100) ? localBuf : 64'b0;
	
	// ========================================================================
	// Valid Signal Routing
	// ========================================================================
	assign northOut_valid = (north_out_select == 3'b000) ? northBuf_valid :
	                         (north_out_select == 3'b001) ? eastBuf_valid :
	                         (north_out_select == 3'b010) ? southBuf_valid :
	                         (north_out_select == 3'b011) ? westBuf_valid :
	                         (north_out_select == 3'b100) ? localBuf_valid : 1'b0;
	
	assign eastOut_valid = (east_out_select == 3'b000) ? northBuf_valid :
	                        (east_out_select == 3'b001) ? eastBuf_valid :
	                        (east_out_select == 3'b010) ? southBuf_valid :
	                        (east_out_select == 3'b011) ? westBuf_valid :
	                        (east_out_select == 3'b100) ? localBuf_valid : 1'b0;
	
	assign southOut_valid = (south_out_select == 3'b000) ? northBuf_valid :
	                         (south_out_select == 3'b001) ? eastBuf_valid :
	                         (south_out_select == 3'b010) ? southBuf_valid :
	                         (south_out_select == 3'b011) ? westBuf_valid :
	                         (south_out_select == 3'b100) ? localBuf_valid : 1'b0;
	
	assign westOut_valid = (west_out_select == 3'b000) ? northBuf_valid :
	                        (west_out_select == 3'b001) ? eastBuf_valid :
	                        (west_out_select == 3'b010) ? southBuf_valid :
	                        (west_out_select == 3'b011) ? westBuf_valid :
	                        (west_out_select == 3'b100) ? localBuf_valid : 1'b0;
	
	assign localOut_valid = (local_out_select == 3'b000) ? northBuf_valid :
	                         (local_out_select == 3'b001) ? eastBuf_valid :
	                         (local_out_select == 3'b010) ? southBuf_valid :
	                         (local_out_select == 3'b011) ? westBuf_valid :
	                         (local_out_select == 3'b100) ? localBuf_valid : 1'b0;
	
	// ========================================================================
	// VC Signal Routing
	// ========================================================================
	assign northOut_vc = (north_out_select == 3'b000) ? northBuf_vc :
	                      (north_out_select == 3'b001) ? eastBuf_vc :
	                      (north_out_select == 3'b010) ? southBuf_vc :
	                      (north_out_select == 3'b011) ? westBuf_vc :
	                      (north_out_select == 3'b100) ? localBuf_vc : 2'b0;
	
	assign eastOut_vc = (east_out_select == 3'b000) ? northBuf_vc :
	                     (east_out_select == 3'b001) ? eastBuf_vc :
	                     (east_out_select == 3'b010) ? southBuf_vc :
	                     (east_out_select == 3'b011) ? westBuf_vc :
	                     (east_out_select == 3'b100) ? localBuf_vc : 2'b0;
	
	assign southOut_vc = (south_out_select == 3'b000) ? northBuf_vc :
	                      (south_out_select == 3'b001) ? eastBuf_vc :
	                      (south_out_select == 3'b010) ? southBuf_vc :
	                      (south_out_select == 3'b011) ? westBuf_vc :
	                      (south_out_select == 3'b100) ? localBuf_vc : 2'b0;
	
	assign westOut_vc = (west_out_select == 3'b000) ? northBuf_vc :
	                     (west_out_select == 3'b001) ? eastBuf_vc :
	                     (west_out_select == 3'b010) ? southBuf_vc :
	                     (west_out_select == 3'b011) ? westBuf_vc :
	                     (west_out_select == 3'b100) ? localBuf_vc : 2'b0;
	
	assign localOut_vc = (local_out_select == 3'b000) ? northBuf_vc :
	                      (local_out_select == 3'b001) ? eastBuf_vc :
	                      (local_out_select == 3'b010) ? southBuf_vc :
	                      (local_out_select == 3'b011) ? westBuf_vc :
	                      (local_out_select == 3'b100) ? localBuf_vc : 2'b0;

endmodule