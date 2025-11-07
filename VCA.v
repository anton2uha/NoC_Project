// ============================================================================
// Virtual Channel Allocator (VCA)
// ============================================================================
module VCA (
	input wire clk,
	input wire rst,
	
	input wire [1:0] north_buf_vc_status,
	input wire [1:0] east_buf_vc_status,
	input wire [1:0] south_buf_vc_status,
	input wire [1:0] west_buf_vc_status,
	input wire [1:0] local_buf_vc_status,
	
	// Which INPUT VC is at RC stage for each buffer
	input wire [1:0] north_buf_rc_vc,
	input wire [1:0] east_buf_rc_vc,
	input wire [1:0] south_buf_rc_vc,
	input wire [1:0] west_buf_rc_vc,
	input wire [1:0] local_buf_rc_vc,
	
	// Which INPUT VC is at SA stage for each buffer
	input wire [1:0] north_buf_sa_vc,
	input wire [1:0] east_buf_sa_vc,
	input wire [1:0] south_buf_sa_vc,
	input wire [1:0] west_buf_sa_vc,
	input wire [1:0] local_buf_sa_vc,
	
	// NEW: Is any VC currently granted and active?
	input wire north_buf_vc_active,
	input wire east_buf_vc_active,
	input wire south_buf_vc_active,
	input wire west_buf_vc_active,
	input wire local_buf_vc_active,
	
	input wire [4:0] north_route,
	input wire [4:0] east_route,
	input wire [4:0] south_route,
	input wire [4:0] west_route,
	input wire [4:0] local_route,
	input wire north_route_valid,
	input wire east_route_valid,
	input wire south_route_valid,
	input wire west_route_valid,
	input wire local_route_valid,
	
	input wire [1:0] north_out_credits,
	input wire [1:0] east_out_credits,
	input wire [1:0] south_out_credits,
	input wire [1:0] west_out_credits,
	input wire [1:0] local_out_credits,
	
	output wire [1:0] north_in_credits,
	output wire [1:0] east_in_credits,
	output wire [1:0] south_in_credits,
	output wire [1:0] west_in_credits,
	output wire [1:0] local_in_credits,
	
	output wire [1:0] north_buf_vc_grant,
	output wire [1:0] east_buf_vc_grant,
	output wire [1:0] south_buf_vc_grant,
	output wire [1:0] west_buf_vc_grant,
	output wire [1:0] local_buf_vc_grant,
	
	output wire [1:0] north_vc_available,
	output wire [1:0] east_vc_available,
	output wire [1:0] south_vc_available,
	output wire [1:0] west_vc_available,
	output wire [1:0] local_vc_available
);

	// ========================================================================
	// Credit Tracking Registers
	// ========================================================================
	reg [2:0] north_vc0_credits, north_vc1_credits;
	reg [2:0] east_vc0_credits, east_vc1_credits;
	reg [2:0] south_vc0_credits, south_vc1_credits;
	reg [2:0] west_vc0_credits, west_vc1_credits;
	reg [2:0] local_vc0_credits, local_vc1_credits;
	
	// ========================================================================
	// Round-Robin Priority State for Each Output Port
	// ========================================================================
	reg [2:0] north_last_grant;
	reg [2:0] east_last_grant;
	reg [2:0] south_last_grant;
	reg [2:0] west_last_grant;
	reg [2:0] local_last_grant;
	
	wire north_vc0_inc = north_out_credits[0];
	wire north_vc0_dec = north_buf_vc_grant[0];
	wire north_vc1_inc = north_out_credits[1];
	wire north_vc1_dec = north_buf_vc_grant[1];
	
	wire east_vc0_inc = east_out_credits[0];
	wire east_vc0_dec = east_buf_vc_grant[0];
	wire east_vc1_inc = east_out_credits[1];
	wire east_vc1_dec = east_buf_vc_grant[1];
	
	wire south_vc0_inc = south_out_credits[0];
	wire south_vc0_dec = south_buf_vc_grant[0];
	wire south_vc1_inc = south_out_credits[1];
	wire south_vc1_dec = south_buf_vc_grant[1];
	
	wire west_vc0_inc = west_out_credits[0];
	wire west_vc0_dec = west_buf_vc_grant[0];
	wire west_vc1_inc = west_out_credits[1];
	wire west_vc1_dec = west_buf_vc_grant[1];
	
	wire local_vc0_inc = local_out_credits[0];
	wire local_vc0_dec = local_buf_vc_grant[0];
	wire local_vc1_inc = local_out_credits[1];
	wire local_vc1_dec = local_buf_vc_grant[1];
	
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			north_vc0_credits <= 3'd4;
			north_vc1_credits <= 3'd4;
			east_vc0_credits <= 3'd4;
			east_vc1_credits <= 3'd4;
			south_vc0_credits <= 3'd4;
			south_vc1_credits <= 3'd4;
			west_vc0_credits <= 3'd4;
			west_vc1_credits <= 3'd4;
			local_vc0_credits <= 3'd4;
			local_vc1_credits <= 3'd4;
			
			north_last_grant <= 3'd0;
			east_last_grant <= 3'd0;
			south_last_grant <= 3'd0;
			west_last_grant <= 3'd0;
			local_last_grant <= 3'd0;
		end else begin
			// ================================================================
			// Handle simultaneous credit increment/decrement
			// ================================================================
			// North VC0
			case ({north_vc0_inc, north_vc0_dec})
				2'b00: north_vc0_credits <= north_vc0_credits;
				2'b01: north_vc0_credits <= north_vc0_credits - 3'd1;
				2'b10: north_vc0_credits <= north_vc0_credits + 3'd1;
				2'b11: north_vc0_credits <= north_vc0_credits;
			endcase
			
			// North VC1
			case ({north_vc1_inc, north_vc1_dec})
				2'b00: north_vc1_credits <= north_vc1_credits;
				2'b01: north_vc1_credits <= north_vc1_credits - 3'd1;
				2'b10: north_vc1_credits <= north_vc1_credits + 3'd1;
				2'b11: north_vc1_credits <= north_vc1_credits;
			endcase
			
			// East VC0
			case ({east_vc0_inc, east_vc0_dec})
				2'b00: east_vc0_credits <= east_vc0_credits;
				2'b01: east_vc0_credits <= east_vc0_credits - 3'd1;
				2'b10: east_vc0_credits <= east_vc0_credits + 3'd1;
				2'b11: east_vc0_credits <= east_vc0_credits;
			endcase
			
			// East VC1
			case ({east_vc1_inc, east_vc1_dec})
				2'b00: east_vc1_credits <= east_vc1_credits;
				2'b01: east_vc1_credits <= east_vc1_credits - 3'd1;
				2'b10: east_vc1_credits <= east_vc1_credits + 3'd1;
				2'b11: east_vc1_credits <= east_vc1_credits;
			endcase
			
			// South VC0
			case ({south_vc0_inc, south_vc0_dec})
				2'b00: south_vc0_credits <= south_vc0_credits;
				2'b01: south_vc0_credits <= south_vc0_credits - 3'd1;
				2'b10: south_vc0_credits <= south_vc0_credits + 3'd1;
				2'b11: south_vc0_credits <= south_vc0_credits;
			endcase
			
			// South VC1
			case ({south_vc1_inc, south_vc1_dec})
				2'b00: south_vc1_credits <= south_vc1_credits;
				2'b01: south_vc1_credits <= south_vc1_credits - 3'd1;
				2'b10: south_vc1_credits <= south_vc1_credits + 3'd1;
				2'b11: south_vc1_credits <= south_vc1_credits;
			endcase
			
			// West VC0
			case ({west_vc0_inc, west_vc0_dec})
				2'b00: west_vc0_credits <= west_vc0_credits;
				2'b01: west_vc0_credits <= west_vc0_credits - 3'd1;
				2'b10: west_vc0_credits <= west_vc0_credits + 3'd1;
				2'b11: west_vc0_credits <= west_vc0_credits;
			endcase
			
			// West VC1
			case ({west_vc1_inc, west_vc1_dec})
				2'b00: west_vc1_credits <= west_vc1_credits;
				2'b01: west_vc1_credits <= west_vc1_credits - 3'd1;
				2'b10: west_vc1_credits <= west_vc1_credits + 3'd1;
				2'b11: west_vc1_credits <= west_vc1_credits;
			endcase
			
			// Local VC0
			case ({local_vc0_inc, local_vc0_dec})
				2'b00: local_vc0_credits <= local_vc0_credits;
				2'b01: local_vc0_credits <= local_vc0_credits - 3'd1;
				2'b10: local_vc0_credits <= local_vc0_credits + 3'd1;
				2'b11: local_vc0_credits <= local_vc0_credits;
			endcase
			
			// Local VC1
			case ({local_vc1_inc, local_vc1_dec})
				2'b00: local_vc1_credits <= local_vc1_credits;
				2'b01: local_vc1_credits <= local_vc1_credits - 3'd1;
				2'b10: local_vc1_credits <= local_vc1_credits + 3'd1;
				2'b11: local_vc1_credits <= local_vc1_credits;
			endcase
			
			// ================================================================
			// Update Round-Robin State
			// ================================================================
			if (north_buf_vc_grant != 2'b00 && north_route[4:2] == 3'b000) north_last_grant <= 3'd0;
			else if (east_buf_vc_grant != 2'b00 && east_route[4:2] == 3'b000) north_last_grant <= 3'd1;
			else if (south_buf_vc_grant != 2'b00 && south_route[4:2] == 3'b000) north_last_grant <= 3'd2;
			else if (west_buf_vc_grant != 2'b00 && west_route[4:2] == 3'b000) north_last_grant <= 3'd3;
			else if (local_buf_vc_grant != 2'b00 && local_route[4:2] == 3'b000) north_last_grant <= 3'd4;
			
			if (north_buf_vc_grant != 2'b00 && north_route[4:2] == 3'b001) east_last_grant <= 3'd0;
			else if (east_buf_vc_grant != 2'b00 && east_route[4:2] == 3'b001) east_last_grant <= 3'd1;
			else if (south_buf_vc_grant != 2'b00 && south_route[4:2] == 3'b001) east_last_grant <= 3'd2;
			else if (west_buf_vc_grant != 2'b00 && west_route[4:2] == 3'b001) east_last_grant <= 3'd3;
			else if (local_buf_vc_grant != 2'b00 && local_route[4:2] == 3'b001) east_last_grant <= 3'd4;
			
			if (north_buf_vc_grant != 2'b00 && north_route[4:2] == 3'b010) south_last_grant <= 3'd0;
			else if (east_buf_vc_grant != 2'b00 && east_route[4:2] == 3'b010) south_last_grant <= 3'd1;
			else if (south_buf_vc_grant != 2'b00 && south_route[4:2] == 3'b010) south_last_grant <= 3'd2;
			else if (west_buf_vc_grant != 2'b00 && west_route[4:2] == 3'b010) south_last_grant <= 3'd3;
			else if (local_buf_vc_grant != 2'b00 && local_route[4:2] == 3'b010) south_last_grant <= 3'd4;
			
			if (north_buf_vc_grant != 2'b00 && north_route[4:2] == 3'b011) west_last_grant <= 3'd0;
			else if (east_buf_vc_grant != 2'b00 && east_route[4:2] == 3'b011) west_last_grant <= 3'd1;
			else if (south_buf_vc_grant != 2'b00 && south_route[4:2] == 3'b011) west_last_grant <= 3'd2;
			else if (west_buf_vc_grant != 2'b00 && west_route[4:2] == 3'b011) west_last_grant <= 3'd3;
			else if (local_buf_vc_grant != 2'b00 && local_route[4:2] == 3'b011) west_last_grant <= 3'd4;
			
			if (north_buf_vc_grant != 2'b00 && north_route[4:2] == 3'b100) local_last_grant <= 3'd0;
			else if (east_buf_vc_grant != 2'b00 && east_route[4:2] == 3'b100) local_last_grant <= 3'd1;
			else if (south_buf_vc_grant != 2'b00 && south_route[4:2] == 3'b100) local_last_grant <= 3'd2;
			else if (west_buf_vc_grant != 2'b00 && west_route[4:2] == 3'b100) local_last_grant <= 3'd3;
			else if (local_buf_vc_grant != 2'b00 && local_route[4:2] == 3'b100) local_last_grant <= 3'd4;
		end
	end
	
	// ========================================================================
	// Credit Availability
	// ========================================================================
	assign north_vc_available[0] = (north_vc0_credits > 3'd0);
	assign north_vc_available[1] = (north_vc1_credits > 3'd0);
	assign east_vc_available[0] = (east_vc0_credits > 3'd0);
	assign east_vc_available[1] = (east_vc1_credits > 3'd0);
	assign south_vc_available[0] = (south_vc0_credits > 3'd0);
	assign south_vc_available[1] = (south_vc1_credits > 3'd0);
	assign west_vc_available[0] = (west_vc0_credits > 3'd0);
	assign west_vc_available[1] = (west_vc1_credits > 3'd0);
	assign local_vc_available[0] = (local_vc0_credits > 3'd0);
	assign local_vc_available[1] = (local_vc1_credits > 3'd0);
	
	assign north_in_credits = north_buf_vc_status;
	assign east_in_credits = east_buf_vc_status;
	assign south_in_credits = south_buf_vc_status;
	assign west_in_credits = west_buf_vc_status;
	assign local_in_credits = local_buf_vc_status;
	
	// ========================================================================
	// Request Signals
	// ========================================================================
	wire north_req_north = north_route_valid && (north_route[4:2] == 3'b000);
	wire north_req_east = north_route_valid && (north_route[4:2] == 3'b001);
	wire north_req_south = north_route_valid && (north_route[4:2] == 3'b010);
	wire north_req_west = north_route_valid && (north_route[4:2] == 3'b011);
	wire north_req_local = north_route_valid && (north_route[4:2] == 3'b100);
	
	wire east_req_north = east_route_valid && (east_route[4:2] == 3'b000);
	wire east_req_east = east_route_valid && (east_route[4:2] == 3'b001);
	wire east_req_south = east_route_valid && (east_route[4:2] == 3'b010);
	wire east_req_west = east_route_valid && (east_route[4:2] == 3'b011);
	wire east_req_local = east_route_valid && (east_route[4:2] == 3'b100);
	
	wire south_req_north = south_route_valid && (south_route[4:2] == 3'b000);
	wire south_req_east = south_route_valid && (south_route[4:2] == 3'b001);
	wire south_req_south = south_route_valid && (south_route[4:2] == 3'b010);
	wire south_req_west = south_route_valid && (south_route[4:2] == 3'b011);
	wire south_req_local = south_route_valid && (south_route[4:2] == 3'b100);
	
	wire west_req_north = west_route_valid && (west_route[4:2] == 3'b000);
	wire west_req_east = west_route_valid && (west_route[4:2] == 3'b001);
	wire west_req_south = west_route_valid && (west_route[4:2] == 3'b010);
	wire west_req_west = west_route_valid && (west_route[4:2] == 3'b011);
	wire west_req_local = west_route_valid && (west_route[4:2] == 3'b100);
	
	wire local_req_north = local_route_valid && (local_route[4:2] == 3'b000);
	wire local_req_east = local_route_valid && (local_route[4:2] == 3'b001);
	wire local_req_south = local_route_valid && (local_route[4:2] == 3'b010);
	wire local_req_west = local_route_valid && (local_route[4:2] == 3'b011);
	wire local_req_local = local_route_valid && (local_route[4:2] == 3'b100);
	
	// ========================================================================
	// Round-Robin Arbitration
	// ========================================================================
	reg [1:0] north_grant, east_grant, south_grant, west_grant, local_grant;
	
	function [2:0] get_next_requester;
		input [2:0] last_grant;
		input north_req, east_req, south_req, west_req, local_req;
		begin
			case (last_grant)
				3'd0: begin
					if (east_req) get_next_requester = 3'd1;
					else if (south_req) get_next_requester = 3'd2;
					else if (west_req) get_next_requester = 3'd3;
					else if (local_req) get_next_requester = 3'd4;
					else if (north_req) get_next_requester = 3'd0;
					else get_next_requester = 3'd7;
				end
				3'd1: begin
					if (south_req) get_next_requester = 3'd2;
					else if (west_req) get_next_requester = 3'd3;
					else if (local_req) get_next_requester = 3'd4;
					else if (north_req) get_next_requester = 3'd0;
					else if (east_req) get_next_requester = 3'd1;
					else get_next_requester = 3'd7;
				end
				3'd2: begin
					if (west_req) get_next_requester = 3'd3;
					else if (local_req) get_next_requester = 3'd4;
					else if (north_req) get_next_requester = 3'd0;
					else if (east_req) get_next_requester = 3'd1;
					else if (south_req) get_next_requester = 3'd2;
					else get_next_requester = 3'd7;
				end
				3'd3: begin
					if (local_req) get_next_requester = 3'd4;
					else if (north_req) get_next_requester = 3'd0;
					else if (east_req) get_next_requester = 3'd1;
					else if (south_req) get_next_requester = 3'd2;
					else if (west_req) get_next_requester = 3'd3;
					else get_next_requester = 3'd7;
				end
				default: begin
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
	
	wire [2:0] north_winner, east_winner, south_winner, west_winner, local_winner;
	
	assign north_winner = get_next_requester(north_last_grant, north_req_north, east_req_north, 
	                                          south_req_north, west_req_north, local_req_north);
	assign east_winner = get_next_requester(east_last_grant, north_req_east, east_req_east, 
	                                         south_req_east, west_req_east, local_req_east);
	assign south_winner = get_next_requester(south_last_grant, north_req_south, east_req_south, 
	                                          south_req_south, west_req_south, local_req_south);
	assign west_winner = get_next_requester(west_last_grant, north_req_west, east_req_west, 
	                                         south_req_west, west_req_west, local_req_west);
	assign local_winner = get_next_requester(local_last_grant, north_req_local, east_req_local, 
	                                          south_req_local, west_req_local, local_req_local);
	
	// ========================================================================
	// Grant Generation - FIXED: Use rc_vc for NEW, sa_vc for CONTINUING
	// ========================================================================
	always @(*) begin
		north_grant = 2'b00;
		east_grant = 2'b00;
		south_grant = 2'b00;
		west_grant = 2'b00;
		local_grant = 2'b00;
		
		// For each output, check if requested OUTPUT VC is available
		// Grant the INPUT VC: use rc_vc if NEW (no VC active), sa_vc if CONTINUING (VC active)
		if (north_winner == 3'd0 && north_vc_available[north_route[1:0]]) 
			north_grant = 2'b01 << (north_buf_vc_active ? north_buf_sa_vc[0] : north_buf_rc_vc[0]);
		else if (north_winner == 3'd1 && north_vc_available[east_route[1:0]]) 
			north_grant = 2'b01 << (east_buf_vc_active ? east_buf_sa_vc[0] : east_buf_rc_vc[0]);
		else if (north_winner == 3'd2 && north_vc_available[south_route[1:0]]) 
			north_grant = 2'b01 << (south_buf_vc_active ? south_buf_sa_vc[0] : south_buf_rc_vc[0]);
		else if (north_winner == 3'd3 && north_vc_available[west_route[1:0]]) 
			north_grant = 2'b01 << (west_buf_vc_active ? west_buf_sa_vc[0] : west_buf_rc_vc[0]);
		else if (north_winner == 3'd4 && north_vc_available[local_route[1:0]]) 
			north_grant = 2'b01 << (local_buf_vc_active ? local_buf_sa_vc[0] : local_buf_rc_vc[0]);
		
		if (east_winner == 3'd0 && east_vc_available[north_route[1:0]]) 
			east_grant = 2'b01 << (north_buf_vc_active ? north_buf_sa_vc[0] : north_buf_rc_vc[0]);
		else if (east_winner == 3'd1 && east_vc_available[east_route[1:0]]) 
			east_grant = 2'b01 << (east_buf_vc_active ? east_buf_sa_vc[0] : east_buf_rc_vc[0]);
		else if (east_winner == 3'd2 && east_vc_available[south_route[1:0]]) 
			east_grant = 2'b01 << (south_buf_vc_active ? south_buf_sa_vc[0] : south_buf_rc_vc[0]);
		else if (east_winner == 3'd3 && east_vc_available[west_route[1:0]]) 
			east_grant = 2'b01 << (west_buf_vc_active ? west_buf_sa_vc[0] : west_buf_rc_vc[0]);
		else if (east_winner == 3'd4 && east_vc_available[local_route[1:0]]) 
			east_grant = 2'b01 << (local_buf_vc_active ? local_buf_sa_vc[0] : local_buf_rc_vc[0]);
		
		if (south_winner == 3'd0 && south_vc_available[north_route[1:0]]) 
			south_grant = 2'b01 << (north_buf_vc_active ? north_buf_sa_vc[0] : north_buf_rc_vc[0]);
		else if (south_winner == 3'd1 && south_vc_available[east_route[1:0]]) 
			south_grant = 2'b01 << (east_buf_vc_active ? east_buf_sa_vc[0] : east_buf_rc_vc[0]);
		else if (south_winner == 3'd2 && south_vc_available[south_route[1:0]]) 
			south_grant = 2'b01 << (south_buf_vc_active ? south_buf_sa_vc[0] : south_buf_rc_vc[0]);
		else if (south_winner == 3'd3 && south_vc_available[west_route[1:0]]) 
			south_grant = 2'b01 << (west_buf_vc_active ? west_buf_sa_vc[0] : west_buf_rc_vc[0]);
		else if (south_winner == 3'd4 && south_vc_available[local_route[1:0]]) 
			south_grant = 2'b01 << (local_buf_vc_active ? local_buf_sa_vc[0] : local_buf_rc_vc[0]);
		
		if (west_winner == 3'd0 && west_vc_available[north_route[1:0]]) 
			west_grant = 2'b01 << (north_buf_vc_active ? north_buf_sa_vc[0] : north_buf_rc_vc[0]);
		else if (west_winner == 3'd1 && west_vc_available[east_route[1:0]]) 
			west_grant = 2'b01 << (east_buf_vc_active ? east_buf_sa_vc[0] : east_buf_rc_vc[0]);
		else if (west_winner == 3'd2 && west_vc_available[south_route[1:0]]) 
			west_grant = 2'b01 << (south_buf_vc_active ? south_buf_sa_vc[0] : south_buf_rc_vc[0]);
		else if (west_winner == 3'd3 && west_vc_available[west_route[1:0]]) 
			west_grant = 2'b01 << (west_buf_vc_active ? west_buf_sa_vc[0] : west_buf_rc_vc[0]);
		else if (west_winner == 3'd4 && west_vc_available[local_route[1:0]]) 
			west_grant = 2'b01 << (local_buf_vc_active ? local_buf_sa_vc[0] : local_buf_rc_vc[0]);
		
		if (local_winner == 3'd0 && local_vc_available[north_route[1:0]]) 
			local_grant = 2'b01 << (north_buf_vc_active ? north_buf_sa_vc[0] : north_buf_rc_vc[0]);
		else if (local_winner == 3'd1 && local_vc_available[east_route[1:0]]) 
			local_grant = 2'b01 << (east_buf_vc_active ? east_buf_sa_vc[0] : east_buf_rc_vc[0]);
		else if (local_winner == 3'd2 && local_vc_available[south_route[1:0]]) 
			local_grant = 2'b01 << (south_buf_vc_active ? south_buf_sa_vc[0] : south_buf_rc_vc[0]);
		else if (local_winner == 3'd3 && local_vc_available[west_route[1:0]]) 
			local_grant = 2'b01 << (west_buf_vc_active ? west_buf_sa_vc[0] : west_buf_rc_vc[0]);
		else if (local_winner == 3'd4 && local_vc_available[local_route[1:0]]) 
			local_grant = 2'b01 << (local_buf_vc_active ? local_buf_sa_vc[0] : local_buf_rc_vc[0]);
	end
	
	// ========================================================================
	// Map grants back to buffers
	// ========================================================================
	assign north_buf_vc_grant = (north_winner == 3'd0) ? north_grant :
	                             (east_winner == 3'd0) ? east_grant :
	                             (south_winner == 3'd0) ? south_grant :
	                             (west_winner == 3'd0) ? west_grant :
	                             (local_winner == 3'd0) ? local_grant : 2'b00;
	
	assign east_buf_vc_grant = (north_winner == 3'd1) ? north_grant :
	                            (east_winner == 3'd1) ? east_grant :
	                            (south_winner == 3'd1) ? south_grant :
	                            (west_winner == 3'd1) ? west_grant :
	                            (local_winner == 3'd1) ? local_grant : 2'b00;
	
	assign south_buf_vc_grant = (north_winner == 3'd2) ? north_grant :
	                             (east_winner == 3'd2) ? east_grant :
	                             (south_winner == 3'd2) ? south_grant :
	                             (west_winner == 3'd2) ? west_grant :
	                             (local_winner == 3'd2) ? local_grant : 2'b00;
	
	assign west_buf_vc_grant = (north_winner == 3'd3) ? north_grant :
	                            (east_winner == 3'd3) ? east_grant :
	                            (south_winner == 3'd3) ? south_grant :
	                            (west_winner == 3'd3) ? west_grant :
	                            (local_winner == 3'd3) ? local_grant : 2'b00;
	
	assign local_buf_vc_grant = (north_winner == 3'd4) ? north_grant :
	                             (east_winner == 3'd4) ? east_grant :
	                             (south_winner == 3'd4) ? south_grant :
	                             (west_winner == 3'd4) ? west_grant :
	                             (local_winner == 3'd4) ? local_grant : 2'b00;

endmodule