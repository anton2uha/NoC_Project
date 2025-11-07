// ============================================================================
// Crossbar Switch Allocator (CBA)
// ============================================================================
module CBA (
	input wire clk,
	input wire rst,
	
	// Router coordinates for debugging
	input wire [2:0] router_x,
	input wire [2:0] router_y,
	
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
	
	// Flit type information (000=HEAD, 001=BODY, 010=TAIL)
	input wire [2:0] north_buf_flit_type,
	input wire [2:0] east_buf_flit_type,
	input wire [2:0] south_buf_flit_type,
	input wire [2:0] west_buf_flit_type,
	input wire [2:0] local_buf_flit_type,
	
	// Packet ID information
	input wire [6:0] north_buf_pkt_id,
	input wire [6:0] east_buf_pkt_id,
	input wire [6:0] south_buf_pkt_id,
	input wire [6:0] west_buf_pkt_id,
	input wire [6:0] local_buf_pkt_id,
	
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
	// Wormhole Flow Control - Port Locking State
	// ========================================================================
	reg north_port_locked;
	reg east_port_locked;
	reg south_port_locked;
	reg west_port_locked;
	reg local_port_locked;
	
	reg [6:0] north_locked_pkt_id;
	reg [6:0] east_locked_pkt_id;
	reg [6:0] south_locked_pkt_id;
	reg [6:0] west_locked_pkt_id;
	reg [6:0] local_locked_pkt_id;

	// ========================================================================
	// Round-Robin State
	// ========================================================================
	reg [2:0] north_last_grant;
	reg [2:0] east_last_grant;
	reg [2:0] south_last_grant;
	reg [2:0] west_last_grant;
	reg [2:0] local_last_grant;
	
	// ========================================================================
	// Helper function for round-robin arbitration
	// ========================================================================
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
	wire west_req_south = west_buf_request && (west_route[4:2] == 3'b010);  // FIXED!
	wire west_req_west = west_buf_request && (west_route[4:2] == 3'b011);
	wire west_req_local = west_buf_request && (west_route[4:2] == 3'b100);
	
	wire local_req_north = local_buf_request && (local_route[4:2] == 3'b000);
	wire local_req_east = local_buf_request && (local_route[4:2] == 3'b001);
	wire local_req_south = local_buf_request && (local_route[4:2] == 3'b010);
	wire local_req_west = local_buf_request && (local_route[4:2] == 3'b011);
	wire local_req_local = local_buf_request && (local_route[4:2] == 3'b100);
	
	// ========================================================================
	// FILTERED Requests - Block requests to locked ports EXCEPT owner packet
	// ========================================================================
	wire north_req_north_filtered = north_req_north && 
	    (!north_port_locked || (north_port_locked && north_buf_pkt_id == north_locked_pkt_id));
	wire north_req_east_filtered = north_req_east && 
	    (!east_port_locked || (east_port_locked && north_buf_pkt_id == east_locked_pkt_id));
	wire north_req_south_filtered = north_req_south && 
	    (!south_port_locked || (south_port_locked && north_buf_pkt_id == south_locked_pkt_id));
	wire north_req_west_filtered = north_req_west && 
	    (!west_port_locked || (west_port_locked && north_buf_pkt_id == west_locked_pkt_id));
	wire north_req_local_filtered = north_req_local && 
	    (!local_port_locked || (local_port_locked && north_buf_pkt_id == local_locked_pkt_id));
	
	wire east_req_north_filtered = east_req_north && 
	    (!north_port_locked || (north_port_locked && east_buf_pkt_id == north_locked_pkt_id));
	wire east_req_east_filtered = east_req_east && 
	    (!east_port_locked || (east_port_locked && east_buf_pkt_id == east_locked_pkt_id));
	wire east_req_south_filtered = east_req_south && 
	    (!south_port_locked || (south_port_locked && east_buf_pkt_id == south_locked_pkt_id));
	wire east_req_west_filtered = east_req_west && 
	    (!west_port_locked || (west_port_locked && east_buf_pkt_id == west_locked_pkt_id));
	wire east_req_local_filtered = east_req_local && 
	    (!local_port_locked || (local_port_locked && east_buf_pkt_id == local_locked_pkt_id));
	
	wire south_req_north_filtered = south_req_north && 
	    (!north_port_locked || (north_port_locked && south_buf_pkt_id == north_locked_pkt_id));
	wire south_req_east_filtered = south_req_east && 
	    (!east_port_locked || (east_port_locked && south_buf_pkt_id == east_locked_pkt_id));
	wire south_req_south_filtered = south_req_south && 
	    (!south_port_locked || (south_port_locked && south_buf_pkt_id == south_locked_pkt_id));
	wire south_req_west_filtered = south_req_west && 
	    (!west_port_locked || (west_port_locked && south_buf_pkt_id == west_locked_pkt_id));
	wire south_req_local_filtered = south_req_local && 
	    (!local_port_locked || (local_port_locked && south_buf_pkt_id == local_locked_pkt_id));
	
	wire west_req_north_filtered = west_req_north && 
	    (!north_port_locked || (north_port_locked && west_buf_pkt_id == north_locked_pkt_id));
	wire west_req_east_filtered = west_req_east && 
	    (!east_port_locked || (east_port_locked && west_buf_pkt_id == east_locked_pkt_id));
	wire west_req_south_filtered = west_req_south && 
	    (!south_port_locked || (south_port_locked && west_buf_pkt_id == south_locked_pkt_id));
	wire west_req_west_filtered = west_req_west && 
	    (!west_port_locked || (west_port_locked && west_buf_pkt_id == west_locked_pkt_id));
	wire west_req_local_filtered = west_req_local && 
	    (!local_port_locked || (local_port_locked && west_buf_pkt_id == local_locked_pkt_id));
	
	wire local_req_north_filtered = local_req_north && 
	    (!north_port_locked || (north_port_locked && local_buf_pkt_id == north_locked_pkt_id));
	wire local_req_east_filtered = local_req_east && 
	    (!east_port_locked || (east_port_locked && local_buf_pkt_id == east_locked_pkt_id));
	wire local_req_south_filtered = local_req_south && 
	    (!south_port_locked || (south_port_locked && local_buf_pkt_id == south_locked_pkt_id));
	wire local_req_west_filtered = local_req_west && 
	    (!west_port_locked || (west_port_locked && local_buf_pkt_id == west_locked_pkt_id));
	wire local_req_local_filtered = local_req_local && 
	    (!local_port_locked || (local_port_locked && local_buf_pkt_id == local_locked_pkt_id));
	
	// ========================================================================
	// Round-Robin Arbitration
	// ========================================================================
	reg [2:0] north_winner, east_winner, south_winner, west_winner, local_winner;
	
	always @(*) begin
		north_winner = get_next_requester(north_last_grant, 
		                                  north_req_north_filtered, 
		                                  east_req_north_filtered, 
		                                  south_req_north_filtered, 
		                                  west_req_north_filtered, 
		                                  local_req_north_filtered);
		
		east_winner = get_next_requester(east_last_grant, 
		                                 north_req_east_filtered, 
		                                 east_req_east_filtered, 
		                                 south_req_east_filtered, 
		                                 west_req_east_filtered, 
		                                 local_req_east_filtered);
		
		south_winner = get_next_requester(south_last_grant, 
		                                  north_req_south_filtered, 
		                                  east_req_south_filtered, 
		                                  south_req_south_filtered, 
		                                  west_req_south_filtered, 
		                                  local_req_south_filtered);
		
		west_winner = get_next_requester(west_last_grant, 
		                                 north_req_west_filtered, 
		                                 east_req_west_filtered, 
		                                 south_req_west_filtered, 
		                                 west_req_west_filtered, 
		                                 local_req_west_filtered);
		
		local_winner = get_next_requester(local_last_grant, 
		                                  north_req_local_filtered, 
		                                  east_req_local_filtered, 
		                                  south_req_local_filtered, 
		                                  west_req_local_filtered, 
		                                  local_req_local_filtered);
	end
	
	
	
	// ========================================================================
	// Port Locking State Machine
	// ========================================================================
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			north_port_locked <= 1'b0;
			east_port_locked <= 1'b0;
			south_port_locked <= 1'b0;
			west_port_locked <= 1'b0;
			local_port_locked <= 1'b0;
			
			north_locked_pkt_id <= 7'b0;
			east_locked_pkt_id <= 7'b0;
			south_locked_pkt_id <= 7'b0;
			west_locked_pkt_id <= 7'b0;
			local_locked_pkt_id <= 7'b0;
			
			north_last_grant <= 3'd0;
			east_last_grant <= 3'd0;
			south_last_grant <= 3'd0;
			west_last_grant <= 3'd0;
			local_last_grant <= 3'd0;
		end else begin
			// ================================================================
			// NORTH Output Port Locking
			// ================================================================
			if (!north_port_locked) begin
				case (north_winner)
					3'd0: if (north_buf_flit_type == 3'b000) begin
						north_port_locked <= 1'b1;
						north_locked_pkt_id <= north_buf_pkt_id;
					end
					3'd1: if (east_buf_flit_type == 3'b000) begin
						north_port_locked <= 1'b1;
						north_locked_pkt_id <= east_buf_pkt_id;
					end
					3'd2: if (south_buf_flit_type == 3'b000) begin
						north_port_locked <= 1'b1;
						north_locked_pkt_id <= south_buf_pkt_id;
					end
					3'd3: if (west_buf_flit_type == 3'b000) begin
						north_port_locked <= 1'b1;
						north_locked_pkt_id <= west_buf_pkt_id;
					end
					3'd4: if (local_buf_flit_type == 3'b000) begin
						north_port_locked <= 1'b1;
						north_locked_pkt_id <= local_buf_pkt_id;
					end
				endcase
			end else begin
				case (north_winner)
					3'd0: if (north_buf_flit_type == 3'b010 && north_buf_pkt_id == north_locked_pkt_id) begin
						north_port_locked <= 1'b0;
					end
					3'd1: if (east_buf_flit_type == 3'b010 && east_buf_pkt_id == north_locked_pkt_id) begin
						north_port_locked <= 1'b0;
					end
					3'd2: if (south_buf_flit_type == 3'b010 && south_buf_pkt_id == north_locked_pkt_id) begin
						north_port_locked <= 1'b0;
					end
					3'd3: if (west_buf_flit_type == 3'b010 && west_buf_pkt_id == north_locked_pkt_id) begin
						north_port_locked <= 1'b0;
					end
					3'd4: if (local_buf_flit_type == 3'b010 && local_buf_pkt_id == north_locked_pkt_id) begin
						north_port_locked <= 1'b0;
					end
				endcase
			end
			
			// ================================================================
			// EAST Output Port Locking
			// ================================================================
			if (!east_port_locked) begin
				case (east_winner)
					3'd0: if (north_buf_flit_type == 3'b000) begin
						east_port_locked <= 1'b1;
						east_locked_pkt_id <= north_buf_pkt_id;
					end
					3'd1: if (east_buf_flit_type == 3'b000) begin
						east_port_locked <= 1'b1;
						east_locked_pkt_id <= east_buf_pkt_id;
					end
					3'd2: if (south_buf_flit_type == 3'b000) begin
						east_port_locked <= 1'b1;
						east_locked_pkt_id <= south_buf_pkt_id;
					end
					3'd3: if (west_buf_flit_type == 3'b000) begin
						east_port_locked <= 1'b1;
						east_locked_pkt_id <= west_buf_pkt_id;
					end
					3'd4: if (local_buf_flit_type == 3'b000) begin
						east_port_locked <= 1'b1;
						east_locked_pkt_id <= local_buf_pkt_id;
					end
				endcase
			end else begin
				case (east_winner)
					3'd0: if (north_buf_flit_type == 3'b010 && north_buf_pkt_id == east_locked_pkt_id) begin
						east_port_locked <= 1'b0;
					end
					3'd1: if (east_buf_flit_type == 3'b010 && east_buf_pkt_id == east_locked_pkt_id) begin
						east_port_locked <= 1'b0;
					end
					3'd2: if (south_buf_flit_type == 3'b010 && south_buf_pkt_id == east_locked_pkt_id) begin
						east_port_locked <= 1'b0;
					end
					3'd3: if (west_buf_flit_type == 3'b010 && west_buf_pkt_id == east_locked_pkt_id) begin
						east_port_locked <= 1'b0;
					end
					3'd4: if (local_buf_flit_type == 3'b010 && local_buf_pkt_id == east_locked_pkt_id) begin
						east_port_locked <= 1'b0;
					end
				endcase
			end
			
			// ================================================================
			// SOUTH Output Port Locking
			// ================================================================
			if (!south_port_locked) begin
				case (south_winner)
					3'd0: if (north_buf_flit_type == 3'b000) begin
						south_port_locked <= 1'b1;
						south_locked_pkt_id <= north_buf_pkt_id;
					end
					3'd1: if (east_buf_flit_type == 3'b000) begin
						south_port_locked <= 1'b1;
						south_locked_pkt_id <= east_buf_pkt_id;
					end
					3'd2: if (south_buf_flit_type == 3'b000) begin
						south_port_locked <= 1'b1;
						south_locked_pkt_id <= south_buf_pkt_id;
					end
					3'd3: if (west_buf_flit_type == 3'b000) begin
						south_port_locked <= 1'b1;
						south_locked_pkt_id <= west_buf_pkt_id;
					end
					3'd4: if (local_buf_flit_type == 3'b000) begin
						south_port_locked <= 1'b1;
						south_locked_pkt_id <= local_buf_pkt_id;
					end
				endcase
			end else begin
				case (south_winner)
					3'd0: if (north_buf_flit_type == 3'b010 && north_buf_pkt_id == south_locked_pkt_id) begin
						south_port_locked <= 1'b0;
					end
					3'd1: if (east_buf_flit_type == 3'b010 && east_buf_pkt_id == south_locked_pkt_id) begin
						south_port_locked <= 1'b0;
					end
					3'd2: if (south_buf_flit_type == 3'b010 && south_buf_pkt_id == south_locked_pkt_id) begin
						south_port_locked <= 1'b0;
					end
					3'd3: if (west_buf_flit_type == 3'b010 && west_buf_pkt_id == south_locked_pkt_id) begin
						south_port_locked <= 1'b0;
					end
					3'd4: if (local_buf_flit_type == 3'b010 && local_buf_pkt_id == south_locked_pkt_id) begin
						south_port_locked <= 1'b0;
					end
				endcase
			end
			
			// ================================================================
			// WEST Output Port Locking
			// ================================================================
			if (!west_port_locked) begin
				case (west_winner)
					3'd0: if (north_buf_flit_type == 3'b000) begin
						west_port_locked <= 1'b1;
						west_locked_pkt_id <= north_buf_pkt_id;
					end
					3'd1: if (east_buf_flit_type == 3'b000) begin
						west_port_locked <= 1'b1;
						west_locked_pkt_id <= east_buf_pkt_id;
					end
					3'd2: if (south_buf_flit_type == 3'b000) begin
						west_port_locked <= 1'b1;
						west_locked_pkt_id <= south_buf_pkt_id;
					end
					3'd3: if (west_buf_flit_type == 3'b000) begin
						west_port_locked <= 1'b1;
						west_locked_pkt_id <= west_buf_pkt_id;
					end
					3'd4: if (local_buf_flit_type == 3'b000) begin
						west_port_locked <= 1'b1;
						west_locked_pkt_id <= local_buf_pkt_id;
					end
				endcase
			end else begin
				case (west_winner)
					3'd0: if (north_buf_flit_type == 3'b010 && north_buf_pkt_id == west_locked_pkt_id) begin
						west_port_locked <= 1'b0;
					end
					3'd1: if (east_buf_flit_type == 3'b010 && east_buf_pkt_id == west_locked_pkt_id) begin
						west_port_locked <= 1'b0;
					end
					3'd2: if (south_buf_flit_type == 3'b010 && south_buf_pkt_id == west_locked_pkt_id) begin
						west_port_locked <= 1'b0;
					end
					3'd3: if (west_buf_flit_type == 3'b010 && west_buf_pkt_id == west_locked_pkt_id) begin
						west_port_locked <= 1'b0;
					end
					3'd4: if (local_buf_flit_type == 3'b010 && local_buf_pkt_id == west_locked_pkt_id) begin
						west_port_locked <= 1'b0;
					end
				endcase
			end
			
			// ================================================================
			// LOCAL Output Port Locking
			// ================================================================
			if (!local_port_locked) begin
				case (local_winner)
					3'd0: if (north_buf_flit_type == 3'b000) begin
						local_port_locked <= 1'b1;
						local_locked_pkt_id <= north_buf_pkt_id;
					end
					3'd1: if (east_buf_flit_type == 3'b000) begin
						local_port_locked <= 1'b1;
						local_locked_pkt_id <= east_buf_pkt_id;
					end
					3'd2: if (south_buf_flit_type == 3'b000) begin
						local_port_locked <= 1'b1;
						local_locked_pkt_id <= south_buf_pkt_id;
					end
					3'd3: if (west_buf_flit_type == 3'b000) begin
						local_port_locked <= 1'b1;
						local_locked_pkt_id <= west_buf_pkt_id;
					end
					3'd4: if (local_buf_flit_type == 3'b000) begin
						local_port_locked <= 1'b1;
						local_locked_pkt_id <= local_buf_pkt_id;
					end
				endcase
			end else begin
				case (local_winner)
					3'd0: if (north_buf_flit_type == 3'b010 && north_buf_pkt_id == local_locked_pkt_id) begin
						local_port_locked <= 1'b0;
					end
					3'd1: if (east_buf_flit_type == 3'b010 && east_buf_pkt_id == local_locked_pkt_id) begin
						local_port_locked <= 1'b0;
					end
					3'd2: if (south_buf_flit_type == 3'b010 && south_buf_pkt_id == local_locked_pkt_id) begin
						local_port_locked <= 1'b0;
					end
					3'd3: if (west_buf_flit_type == 3'b010 && west_buf_pkt_id == local_locked_pkt_id) begin
						local_port_locked <= 1'b0;
					end
					3'd4: if (local_buf_flit_type == 3'b010 && local_buf_pkt_id == local_locked_pkt_id) begin
						local_port_locked <= 1'b0;
					end
				endcase
			end
			
			// ================================================================
			// Update Round-Robin State
			// ================================================================
			if (north_out_select != 3'b111) north_last_grant <= north_out_select;
			if (east_out_select != 3'b111) east_last_grant <= east_out_select;
			if (south_out_select != 3'b111) south_last_grant <= south_out_select;
			if (west_out_select != 3'b111) west_last_grant <= west_out_select;
			if (local_out_select != 3'b111) local_last_grant <= local_out_select;
		end
	end
	
	// ========================================================================
	// Grant Signals
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
	// Output Select Signals
	// ========================================================================
	assign north_out_select = north_winner;
	assign east_out_select = east_winner;
	assign south_out_select = south_winner;
	assign west_out_select = west_winner;
	assign local_out_select = local_winner;
	
	/*
	always @(posedge clk) begin
    if (!rst) begin
        if (west_buf_grant) begin
            $display("[CBA @ (%0d,%0d)] Cycle %0d: WEST granted, route=%b, east_out_select will be=%b", 
                     router_x, router_y, $time/10, west_route, 
                     // Compute what east_out_select should be based on west_route
                     west_route[1] ? 3'b011 : 3'b111);
        end
    end
	end*/

endmodule