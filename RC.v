
// Packet Format Definition
// ============================================================================
// [63:61] - Destination Y coordinate (3 bits: 0-3)
// [60:58] - Destination X coordinate (3 bits: 0-3)
// [57:55] - Flit type (000=head, 001=body, 010=tail)
// [54:48] - Packet ID (7 bits)
// [47:0]  - Payload (48 bits)

// Route Encoding
// ============================================================================
// [4:2] - Output port (000=North, 001=East, 010=South, 011=West, 100=Local)
// [1:0] - VC number (00=VC0, 01=VC1)

module RC (
	input wire clk,
	input wire rst,
	input wire [2:0] curr_x,  // Current router X position
	input wire [2:0] curr_y,  // Current router Y position
	
	input wire [63:0] in_northBuf, in_eastBuf, in_southBuf, in_westBuf,
	input wire [63:0] in_localBuf,  // FIXED: Added local buffer input
	
	input wire [1:0] north_vc_available,
	input wire [1:0] east_vc_available,
	input wire [1:0] south_vc_available,
	input wire [1:0] west_vc_available,
	input wire [1:0] local_vc_available,
	
	output wire [4:0] out_northBuf, out_eastBuf, out_southBuf, out_westBuf, out_local,
	output wire [1:0] out_northBuf_vc, out_eastBuf_vc, out_southBuf_vc, out_westBuf_vc, out_local_vc
);

	// ========================================================================
	// Extract routing information from packet headers
	// ========================================================================
	wire [2:0] dest_y_north, dest_x_north, flit_type_north;
	wire [2:0] dest_y_east, dest_x_east, flit_type_east;
	wire [2:0] dest_y_south, dest_x_south, flit_type_south;
	wire [2:0] dest_y_west, dest_x_west, flit_type_west;
	wire [2:0] dest_y_local, dest_x_local, flit_type_local;  // FIXED: Added local
	wire [6:0] pkt_id_north, pkt_id_east, pkt_id_south, pkt_id_west, pkt_id_local;
	
	assign dest_y_north = in_northBuf[63:61];
	assign dest_x_north = in_northBuf[60:58];
	assign flit_type_north = in_northBuf[57:55];
	assign pkt_id_north = in_northBuf[54:48];
	
	assign dest_y_east = in_eastBuf[63:61];
	assign dest_x_east = in_eastBuf[60:58];
	assign flit_type_east = in_eastBuf[57:55];
	assign pkt_id_east = in_eastBuf[54:48];
	
	assign dest_y_south = in_southBuf[63:61];
	assign dest_x_south = in_southBuf[60:58];
	assign flit_type_south = in_southBuf[57:55];
	assign pkt_id_south = in_southBuf[54:48];
	
	assign dest_y_west = in_westBuf[63:61];
	assign dest_x_west = in_westBuf[60:58];
	assign flit_type_west = in_westBuf[57:55];
	assign pkt_id_west = in_westBuf[54:48];
	
	// FIXED: Added local buffer extraction
	assign dest_y_local = in_localBuf[63:61];
	assign dest_x_local = in_localBuf[60:58];
	assign flit_type_local = in_localBuf[57:55];
	assign pkt_id_local = in_localBuf[54:48];
	
	// ========================================================================
	// Route storage for packet tracking (stores routes for body/tail flits)
	// ========================================================================
	reg [4:0] route_table [0:7];  // Store routes indexed by packet_id[2:0]
	reg [7:0] route_valid;         // Valid bits for each stored route
	
	integer i;
	initial begin
		route_valid = 8'b0;
		for (i = 0; i < 8; i = i + 1) begin
			route_table[i] = 5'b0;
		end
	end
	
	// ========================================================================
	// Route Computation for HEAD flits
	// ========================================================================
	
	// North input routing
	wire [4:0] route_north_computed;
	wire is_head_north = (flit_type_north == 3'b000);
	
	route_computation_westfirst rc_north (
		.curr_x(curr_x), .curr_y(curr_y),
		.dest_y(dest_y_north), .dest_x(dest_x_north),
		.north_avail(north_vc_available),
		.east_avail(east_vc_available),
		.south_avail(south_vc_available),
		.west_avail(west_vc_available),
		.local_avail(local_vc_available),
		.route_out(route_north_computed)
	);
	
	// East input routing
	wire [4:0] route_east_computed;
	wire is_head_east = (flit_type_east == 3'b000);
	
	route_computation_westfirst rc_east (
		.curr_x(curr_x), .curr_y(curr_y),
		.dest_y(dest_y_east), .dest_x(dest_x_east),
		.north_avail(north_vc_available),
		.east_avail(east_vc_available),
		.south_avail(south_vc_available),
		.west_avail(west_vc_available),
		.local_avail(local_vc_available),
		.route_out(route_east_computed)
	);
	
	// South input routing
	wire [4:0] route_south_computed;
	wire is_head_south = (flit_type_south == 3'b000);
	
	route_computation_westfirst rc_south (
		.curr_x(curr_x), .curr_y(curr_y),
		.dest_y(dest_y_south), .dest_x(dest_x_south),
		.north_avail(north_vc_available),
		.east_avail(east_vc_available),
		.south_avail(south_vc_available),
		.west_avail(west_vc_available),
		.local_avail(local_vc_available),
		.route_out(route_south_computed)
	);
	
	// West input routing
	wire [4:0] route_west_computed;
	wire is_head_west = (flit_type_west == 3'b000);
	
	route_computation_westfirst rc_west (
		.curr_x(curr_x), .curr_y(curr_y),
		.dest_y(dest_y_west), .dest_x(dest_x_west),
		.north_avail(north_vc_available),
		.east_avail(east_vc_available),
		.south_avail(south_vc_available),
		.west_avail(west_vc_available),
		.local_avail(local_vc_available),
		.route_out(route_west_computed)
	);
	
	// FIXED: Local input routing (was missing)
	wire [4:0] route_local_computed;
	wire is_head_local = (flit_type_local == 3'b000);
	
	route_computation_westfirst rc_local (
		.curr_x(curr_x), .curr_y(curr_y),
		.dest_y(dest_y_local), .dest_x(dest_x_local),
		.north_avail(north_vc_available),
		.east_avail(east_vc_available),
		.south_avail(south_vc_available),
		.west_avail(west_vc_available),
		.local_avail(local_vc_available),
		.route_out(route_local_computed)
	);
	
	// ========================================================================
	// Route Table Management
	// Store routes when head flits pass through
	// ========================================================================
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			route_valid <= 8'b0;
			for (i = 0; i < 8; i = i + 1) begin
				route_table[i] <= 5'b0;
			end
		end else begin
			// Store routes for head flits
			if (is_head_north && in_northBuf != 64'b0) begin
				route_table[pkt_id_north[2:0]] <= route_north_computed;
				route_valid[pkt_id_north[2:0]] <= 1'b1;
			end
			
			if (is_head_east && in_eastBuf != 64'b0) begin
				route_table[pkt_id_east[2:0]] <= route_east_computed;
				route_valid[pkt_id_east[2:0]] <= 1'b1;
			end
			
			if (is_head_south && in_southBuf != 64'b0) begin
				route_table[pkt_id_south[2:0]] <= route_south_computed;
				route_valid[pkt_id_south[2:0]] <= 1'b1;
			end
			
			if (is_head_west && in_westBuf != 64'b0) begin
				route_table[pkt_id_west[2:0]] <= route_west_computed;
				route_valid[pkt_id_west[2:0]] <= 1'b1;
			end
			
			if (is_head_local && in_localBuf != 64'b0) begin
				route_table[pkt_id_local[2:0]] <= route_local_computed;
				route_valid[pkt_id_local[2:0]] <= 1'b1;
			end
			
		end
	end
	
	// ========================================================================
	// Route Output Selection
	// For head flits: use computed route
	// For body/tail flits: use stored route from table
	// ========================================================================
	
	assign out_northBuf = is_head_north ? route_north_computed : 
	                      route_valid[pkt_id_north[2:0]] ? route_table[pkt_id_north[2:0]] : 5'b0;
	
	assign out_eastBuf = is_head_east ? route_east_computed : 
	                     route_valid[pkt_id_east[2:0]] ? route_table[pkt_id_east[2:0]] : 5'b0;
	
	assign out_southBuf = is_head_south ? route_south_computed : 
	                      route_valid[pkt_id_south[2:0]] ? route_table[pkt_id_south[2:0]] : 5'b0;
	
	assign out_westBuf = is_head_west ? route_west_computed : 
	                     route_valid[pkt_id_west[2:0]] ? route_table[pkt_id_west[2:0]] : 5'b0;
	
	assign out_local = is_head_local ? route_local_computed : 
	                   route_valid[pkt_id_local[2:0]] ? route_table[pkt_id_local[2:0]] : 5'b0;
	
	// VC selection - extract from routes
	assign out_northBuf_vc = out_northBuf[1:0];
	assign out_eastBuf_vc = out_eastBuf[1:0];
	assign out_southBuf_vc = out_southBuf[1:0];
	assign out_westBuf_vc = out_westBuf[1:0];
	assign out_local_vc = out_local[1:0];

endmodule

// ============================================================================
// Route Computation - West-First Adaptive Routing Logic
// ============================================================================
module route_computation_westfirst (
	input wire [2:0] curr_x, curr_y,  // Current router position
	input wire [2:0] dest_y, dest_x,
	input wire [1:0] north_avail, east_avail, south_avail, west_avail, local_avail,
	output wire [4:0] route_out
);

	wire need_north, need_south, need_east, need_west, need_local;
	wire [1:0] selected_vc;
	wire [2:0] output_port;
	
	// Determine if we need to go in each direction based on current position
	assign need_north = (dest_y > curr_y);
	assign need_south = (dest_y < curr_y);
	assign need_east = (dest_x > curr_x);
	assign need_west = (dest_x < curr_x);
	assign need_local = (dest_y == curr_y) && (dest_x == curr_x);
	
	// ====================================================================
	// West-First Algorithm:
	// 1. If at destination, route to local PE
	// 2. If need to go west, go west first
	// 3. Then adapt between North/South based on availability
	// 4. Finally go East if needed
	// ====================================================================
	
	wire [2:0] primary_port, secondary_port;
	wire [1:0] primary_avail, secondary_avail;
	
	// Primary direction
	assign primary_port = need_local ? 3'b100 :
	                       need_west ? 3'b011 : 
	                       need_north ? 3'b000 :
	                       need_south ? 3'b010 :
	                       need_east ? 3'b001 :
	                       3'b100;
	
	assign primary_avail = (primary_port == 3'b100) ? local_avail :
	                        (primary_port == 3'b011) ? west_avail :
	                        (primary_port == 3'b000) ? north_avail :
	                        (primary_port == 3'b010) ? south_avail :
	                        (primary_port == 3'b001) ? east_avail : local_avail;
	
	// Adaptive secondary direction
	assign secondary_port = need_west ? 
	                         (need_north ? 3'b000 : need_south ? 3'b010 : 3'b011) :
	                         need_north ?
	                         (need_west ? 3'b011 : need_south ? 3'b010 : 3'b000) :
	                         need_south ?
	                         (need_west ? 3'b011 : need_north ? 3'b000 : 3'b010) :
	                         need_east ? 3'b001 : 3'b100;
	
	assign secondary_avail = (secondary_port == 3'b100) ? local_avail :
	                          (secondary_port == 3'b011) ? west_avail :
	                          (secondary_port == 3'b000) ? north_avail :
	                          (secondary_port == 3'b010) ? south_avail :
	                          (secondary_port == 3'b001) ? east_avail : local_avail;
	
	// Select output port and VC based on availability
	wire [2:0] selected_port;
	wire [1:0] selected_avail;
	
	assign selected_port = (primary_avail != 2'b00) ? primary_port : secondary_port;
	assign selected_avail = (primary_avail != 2'b00) ? primary_avail : secondary_avail;
	
	// Select lowest available VC
	assign selected_vc = selected_avail[0] ? 2'b00 :
	                      selected_avail[1] ? 2'b01 : 2'b00;
	
	assign route_out = {selected_port, selected_vc};

endmodule