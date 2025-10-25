// ============================================================================
// Crossbar Switch Allocator (CBA)
// ============================================================================
module CBA (
	input wire clk,
	input wire rst,
	
	input wire north_buf_request,
	input wire east_buf_request,
	input wire south_buf_request,
	input wire west_buf_request,
	input wire local_buf_request,
	
	input wire [4:0] north_route,
	input wire [4:0] east_route,
	input wire [4:0] south_route,
	input wire [4:0] west_route,
	input wire [4:0] local_route,
	
	output wire north_buf_grant,
	output wire east_buf_grant,
	output wire south_buf_grant,
	output wire west_buf_grant,
	output wire local_buf_grant,
	
	output wire [2:0] north_out_select,
	output wire [2:0] east_out_select,
	output wire [2:0] south_out_select,
	output wire [2:0] west_out_select,
	output wire [2:0] local_out_select
);

	// ========================================================================
	// Round-Robin State - Track last granted input for each output
	// ========================================================================
	reg [2:0] north_last_grant;  // Which input (0-4) was last granted to north output
	reg [2:0] east_last_grant;
	reg [2:0] south_last_grant;
	reg [2:0] west_last_grant;
	reg [2:0] local_last_grant;
	
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			north_last_grant <= 3'd0;
			east_last_grant <= 3'd0;
			south_last_grant <= 3'd0;
			west_last_grant <= 3'd0;
			local_last_grant <= 3'd0;
		end else begin
			// Update last grant for each output port
			if (north_out_select != 3'b111) north_last_grant <= north_out_select;
			if (east_out_select != 3'b111) east_last_grant <= east_out_select;
			if (south_out_select != 3'b111) south_last_grant <= south_out_select;
			if (west_out_select != 3'b111) west_last_grant <= west_out_select;
			if (local_out_select != 3'b111) local_last_grant <= local_out_select;
		end
	end
	
	// ========================================================================
	// Request Signals
	// ========================================================================
	wire north_req_north = north_buf_request && (north_route[4:2] == 3'b000);
	wire north_req_east = north_buf_request && (north_route[4:2] == 3'b001);
	wire north_req_south = north_buf_request && (north_route[4:2] == 3'b010);
	wire north_req_west = north_buf_request && (north_route[4:2] == 3'b011);
	wire north_req_local = north_buf_request && (north_route[4:2] == 3'b100);
	
	wire east_req_north = east_buf_request && (east_route[4:2] == 3'b000);
	wire east_req_east = east_buf_request && (east_route[4:2] == 3'b001);
	wire east_req_south = east_buf_request && (east_route[4:2] == 3'b010);
	wire east_req_west = east_buf_request && (east_route[4:2] == 3'b011);
	wire east_req_local = east_buf_request && (east_route[4:2] == 3'b100);
	
	wire south_req_north = south_buf_request && (south_route[4:2] == 3'b000);
	wire south_req_east = south_buf_request && (south_route[4:2] == 3'b001);
	wire south_req_south = south_buf_request && (south_route[4:2] == 3'b010);
	wire south_req_west = south_buf_request && (south_route[4:2] == 3'b011);
	wire south_req_local = south_buf_request && (south_route[4:2] == 3'b100);
	
	wire west_req_north = west_buf_request && (west_route[4:2] == 3'b000);
	wire west_req_east = west_buf_request && (west_route[4:2] == 3'b001);
	wire west_req_south = west_buf_request && (west_route[4:2] == 3'b010);
	wire west_req_west = west_buf_request && (west_route[4:2] == 3'b011);
	wire west_req_local = west_buf_request && (west_route[4:2] == 3'b100);
	
	wire local_req_north = local_buf_request && (local_route[4:2] == 3'b000);
	wire local_req_east = local_buf_request && (local_route[4:2] == 3'b001);
	wire local_req_south = local_buf_request && (local_route[4:2] == 3'b010);
	wire local_req_west = local_buf_request && (local_route[4:2] == 3'b011);
	wire local_req_local = local_buf_request && (local_route[4:2] == 3'b100);
	
	// ========================================================================
	// FIXED: Round-Robin Arbitration
	// Select winner based on last grant to ensure fairness
	// ========================================================================
	
	// Helper function to get next requester in round-robin order
	function [2:0] get_next_requester;
		input [2:0] last_grant;
		input north_req, east_req, south_req, west_req, local_req;
		begin
			// Try inputs in order starting from the one after last_grant
			case (last_grant)
				3'd0: begin  // Last was north (input 0), try east->south->west->local->north
					if (east_req) get_next_requester = 3'd1;
					else if (south_req) get_next_requester = 3'd2;
					else if (west_req) get_next_requester = 3'd3;
					else if (local_req) get_next_requester = 3'd4;
					else if (north_req) get_next_requester = 3'd0;
					else get_next_requester = 3'd7;  // No request
				end
				3'd1: begin  // Last was east (input 1)
					if (south_req) get_next_requester = 3'd2;
					else if (west_req) get_next_requester = 3'd3;
					else if (local_req) get_next_requester = 3'd4;
					else if (north_req) get_next_requester = 3'd0;
					else if (east_req) get_next_requester = 3'd1;
					else get_next_requester = 3'd7;
				end
				3'd2: begin  // Last was south (input 2)
					if (west_req) get_next_requester = 3'd3;
					else if (local_req) get_next_requester = 3'd4;
					else if (north_req) get_next_requester = 3'd0;
					else if (east_req) get_next_requester = 3'd1;
					else if (south_req) get_next_requester = 3'd2;
					else get_next_requester = 3'd7;
				end
				3'd3: begin  // Last was west (input 3)
					if (local_req) get_next_requester = 3'd4;
					else if (north_req) get_next_requester = 3'd0;
					else if (east_req) get_next_requester = 3'd1;
					else if (south_req) get_next_requester = 3'd2;
					else if (west_req) get_next_requester = 3'd3;
					else get_next_requester = 3'd7;
				end
				default: begin  // Last was local (input 4) or initial state
					if (north_req) get_next_requester = 3'd0;
					else if (east_req) get_next_requester = 3'd1;
					else if (south_req) get_next_requester = 3'd2;
					else if (west_req) get_next_requester = 3'd3;
					else if (local_req) get_next_requester = 3'd4;
					else get_next_requester = 3'd7;
				end
			endcase
		end
	endfunction
	
	reg [2:0] north_winner, east_winner, south_winner, west_winner, local_winner;
	
	always @(*) begin
		// Use round-robin to select winner for each output port
		north_winner = get_next_requester(north_last_grant, north_req_north, east_req_north, 
		                                   south_req_north, west_req_north, local_req_north);
		
		east_winner = get_next_requester(east_last_grant, north_req_east, east_req_east, 
		                                  south_req_east, west_req_east, local_req_east);
		
		south_winner = get_next_requester(south_last_grant, north_req_south, east_req_south, 
		                                   south_req_south, west_req_south, local_req_south);
		
		west_winner = get_next_requester(west_last_grant, north_req_west, east_req_west, 
		                                  south_req_west, west_req_west, local_req_west);
		
		local_winner = get_next_requester(local_last_grant, north_req_local, east_req_local, 
		                                   south_req_local, west_req_local, local_req_local);
	end
	
	// ========================================================================
	// Grant Signals - Indicate which input buffers got a grant
	// ========================================================================
	assign north_buf_grant = (north_winner == 3'd0) || (east_winner == 3'd0) || 
	                          (south_winner == 3'd0) || (west_winner == 3'd0) ||
	                          (local_winner == 3'd0);
	
	assign east_buf_grant = (north_winner == 3'd1) || (east_winner == 3'd1) || 
	                         (south_winner == 3'd1) || (west_winner == 3'd1) ||
	                         (local_winner == 3'd1);
	
	assign south_buf_grant = (north_winner == 3'd2) || (east_winner == 3'd2) || 
	                          (south_winner == 3'd2) || (west_winner == 3'd2) ||
	                          (local_winner == 3'd2);
	
	assign west_buf_grant = (north_winner == 3'd3) || (east_winner == 3'd3) || 
	                         (south_winner == 3'd3) || (west_winner == 3'd3) ||
	                         (local_winner == 3'd3);
	
	assign local_buf_grant = (north_winner == 3'd4) || (east_winner == 3'd4) || 
	                          (south_winner == 3'd4) || (west_winner == 3'd4) ||
	                          (local_winner == 3'd4);
	
	// ========================================================================
	// Output Select Signals - Tell crossbar which input to route to each output
	// ========================================================================
	assign north_out_select = north_winner;
	assign east_out_select = east_winner;
	assign south_out_select = south_winner;
	assign west_out_select = west_winner;
	assign local_out_select = local_winner;

endmodule