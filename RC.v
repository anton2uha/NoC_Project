

// ============================================================================
// Packet Format Definition
// ============================================================================
// [63:56] - Destination Y coordinate
// [55:48] - Destination X coordinate
// [47:45] - Flit type (000=head, 001=body, 010=tail)
// [44:40] - Packet ID
// [39:0]  - Payload (40 bits)

// ============================================================================
// Route Computation Unit with West-First Adaptive Routing
// Computes route for HEAD flits only. Body/tail flits follow the head.
// ============================================================================
module RC (
	input wire [63:0] in_northBuf, in_eastBuf, in_southBuf, in_westBuf,
	input wire [1:0] north_vc_available,  // VC availability from VC allocator (2 VCs per port)
	input wire [1:0] east_vc_available,
	input wire [1:0] south_vc_available,
	input wire [1:0] west_vc_available,
	input wire [1:0] local_vc_available,
	
	output wire [3:0] out_northBuf, out_eastBuf, out_southBuf, out_westBuf, out_local,
	output wire [1:0] out_northBuf_vc, out_eastBuf_vc, out_southBuf_vc, out_westBuf_vc, out_local_vc
);

	// Extract routing information from packet header (head flits only)
	wire [7:0] dest_y_north, dest_x_north;
	wire [7:0] dest_y_east, dest_x_east;
	wire [7:0] dest_y_south, dest_x_south;
	wire [7:0] dest_y_west, dest_x_west;
	
	wire [2:0] flit_type_north, flit_type_east, flit_type_south, flit_type_west;
	
	assign dest_y_north = in_northBuf[63:56];
	assign dest_x_north = in_northBuf[55:48];
	assign flit_type_north = in_northBuf[47:45];
	
	assign dest_y_east = in_eastBuf[63:56];
	assign dest_x_east = in_eastBuf[55:48];
	assign flit_type_east = in_eastBuf[47:45];
	
	assign dest_y_south = in_southBuf[63:56];
	assign dest_x_south = in_southBuf[55:48];
	assign flit_type_south = in_southBuf[47:45];
	
	assign dest_y_west = in_westBuf[63:56];
	assign dest_x_west = in_westBuf[55:48];
	assign flit_type_west = in_westBuf[47:45];
	
	// ========================================================================
	// West-First Adaptive Routing Logic for each input port
	// Only routes HEAD flits. Body/tail flits handled separately.
	// ========================================================================
	
	// North input routing (head flit only)
	wire [3:0] route_north;
	route_computation_westfirst rc_north (
		.dest_y(dest_y_north), .dest_x(dest_x_north),
		.north_avail(north_vc_available),
		.east_avail(east_vc_available),
		.south_avail(south_vc_available),
		.west_avail(west_vc_available),
		.local_avail(local_vc_available),
		.route_out(route_north)
	);
	
	// East input routing (head flit only)
	wire [3:0] route_east;
	route_computation_westfirst rc_east (
		.dest_y(dest_y_east), .dest_x(dest_x_east),
		.north_avail(north_vc_available),
		.east_avail(east_vc_available),
		.south_avail(south_vc_available),
		.west_avail(west_vc_available),
		.local_avail(local_vc_available),
		.route_out(route_east)
	);
	
	// South input routing (head flit only)
	wire [3:0] route_south;
	route_computation_westfirst rc_south (
		.dest_y(dest_y_south), .dest_x(dest_x_south),
		.north_avail(north_vc_available),
		.east_avail(east_vc_available),
		.south_avail(south_vc_available),
		.west_avail(west_vc_available),
		.local_avail(local_vc_available),
		.route_out(route_south)
	);
	
	// West input routing (head flit only)
	wire [3:0] route_west;
	route_computation_westfirst rc_west (
		.dest_y(dest_y_west), .dest_x(dest_x_west),
		.north_avail(north_vc_available),
		.east_avail(east_vc_available),
		.south_avail(south_vc_available),
		.west_avail(west_vc_available),
		.local_avail(local_vc_available),
		.route_out(route_west)
	);
	
	// ========================================================================
	// Route Output Selection (decode routing to individual output ports)
	// Route encoding: [3:2] = output port, [1:0] = VC selected
	// 00 = North, 01 = East, 10 = South, 11 = West, X = Local
	// ========================================================================
	
	assign out_northBuf = (route_north[3:2] == 2'b00) ? in_northBuf :
	                       (route_east[3:2] == 2'b00) ? in_eastBuf :
	                       (route_south[3:2] == 2'b00) ? in_southBuf :
	                       (route_west[3:2] == 2'b00) ? in_westBuf : 64'b0;
	
	assign out_eastBuf = (route_north[3:2] == 2'b01) ? in_northBuf :
	                      (route_east[3:2] == 2'b01) ? in_eastBuf :
	                      (route_south[3:2] == 2'b01) ? in_southBuf :
	                      (route_west[3:2] == 2'b01) ? in_westBuf : 64'b0;
	
	assign out_southBuf = (route_north[3:2] == 2'b10) ? in_northBuf :
	                       (route_east[3:2] == 2'b10) ? in_eastBuf :
	                       (route_south[3:2] == 2'b10) ? in_southBuf :
	                       (route_west[3:2] == 2'b10) ? in_westBuf : 64'b0;
	
	assign out_westBuf = (route_north[3:2] == 2'b11) ? in_northBuf :
	                      (route_east[3:2] == 2'b11) ? in_eastBuf :
	                      (route_south[3:2] == 2'b11) ? in_southBuf :
	                      (route_west[3:2] == 2'b11) ? in_westBuf : 64'b0;
	
	assign out_local = (route_north[3:2] == 2'b00 && route_north[1:0] == 2'b00) ? in_northBuf :
	                    (route_east[3:2] == 2'b00 && route_east[1:0] == 2'b00) ? in_eastBuf :
	                    (route_south[3:2] == 2'b00 && route_south[1:0] == 2'b00) ? in_southBuf :
	                    (route_west[3:2] == 2'b00 && route_west[1:0] == 2'b00) ? in_westBuf : 64'b0;
	
	// VC selection for each output
	assign out_northBuf_vc = (route_north[3:2] == 2'b00) ? route_north[1:0] :
	                          (route_east[3:2] == 2'b00) ? route_east[1:0] :
	                          (route_south[3:2] == 2'b00) ? route_south[1:0] :
	                          (route_west[3:2] == 2'b00) ? route_west[1:0] : 2'b0;
	
	assign out_eastBuf_vc = (route_north[3:2] == 2'b01) ? route_north[1:0] :
	                         (route_east[3:2] == 2'b01) ? route_east[1:0] :
	                         (route_south[3:2] == 2'b01) ? route_south[1:0] :
	                         (route_west[3:2] == 2'b01) ? route_west[1:0] : 2'b0;
	
	assign out_southBuf_vc = (route_north[3:2] == 2'b10) ? route_north[1:0] :
	                          (route_east[3:2] == 2'b10) ? route_east[1:0] :
	                          (route_south[3:2] == 2'b10) ? route_south[1:0] :
	                          (route_west[3:2] == 2'b10) ? route_west[1:0] : 2'b0;
	
	assign out_westBuf_vc = (route_north[3:2] == 2'b11) ? route_north[1:0] :
	                         (route_east[3:2] == 2'b11) ? route_east[1:0] :
	                         (route_south[3:2] == 2'b11) ? route_south[1:0] :
	                         (route_west[3:2] == 2'b11) ? route_west[1:0] : 2'b0;
	
	assign out_local_vc = (route_north[1:0]) | (route_east[1:0]) | (route_south[1:0]) | (route_west[1:0]);

endmodule

// ============================================================================
// Route Computation - West-First Adaptive Routing Logic (HEAD FLITS ONLY)
// ============================================================================
module route_computation_westfirst (
	input wire [7:0] dest_y, dest_x,
	input wire [1:0] north_avail, east_avail, south_avail, west_avail, local_avail,
	output wire [3:0] route_out
);

	wire need_north, need_south, need_east, need_west, need_local;
	wire [1:0] selected_vc;
	wire [1:0] output_port;
	
	// Determine if we need to go in each direction
	// Current position is implicit - we just compare coordinates
	assign need_north = (dest_y > 0);  // Need to go north if dest_y > curr_y
	assign need_south = (dest_y < 0);  // Need to go south if dest_y < curr_y
	assign need_east = (dest_x > 0);   // Need to go east if dest_x > curr_x
	assign need_west = (dest_x < 0);   // Need to go west if dest_x < curr_x
	assign need_local = (dest_y == 0) && (dest_x == 0);
	
	// ====================================================================
	// West-First Algorithm:
	// 1. If need to go west, go west first (until X coordinate matches)
	// 2. Then adapt between North/South based on availability
	// 3. Finally go East if needed (but after resolving Y coordinate)
	// ====================================================================
	
	wire [1:0] primary_port, secondary_port;
	wire [1:0] primary_avail, secondary_avail;
	
	// Primary direction: West (highest priority in west-first)
	assign primary_port = need_west ? 2'b11 : 
	                       need_north ? 2'b00 :
	                       need_south ? 2'b10 :
	                       need_east ? 2'b01 :
	                       2'b00; // local (shouldn't happen if routed correctly)
	
	assign primary_avail = (primary_port == 2'b11) ? west_avail :
	                        (primary_port == 2'b00) ? north_avail :
	                        (primary_port == 2'b10) ? south_avail :
	                        (primary_port == 2'b01) ? east_avail : local_avail;
	
	// Adaptive secondary direction (if primary has no VC available)
	assign secondary_port = need_west ? 
	                         (need_north ? 2'b00 : need_south ? 2'b10 : 2'b11) :
	                         need_north ?
	                         (need_west ? 2'b11 : need_south ? 2'b10 : 2'b00) :
	                         need_south ?
	                         (need_west ? 2'b11 : need_north ? 2'b00 : 2'b10) :
	                         need_east ? 2'b01 : 2'b00;
	
	assign secondary_avail = (secondary_port == 2'b11) ? west_avail :
	                          (secondary_port == 2'b00) ? north_avail :
	                          (secondary_port == 2'b10) ? south_avail :
	                          (secondary_port == 2'b01) ? east_avail : local_avail;
	
	// Select output port and VC based on availability (adaptive)
	wire [1:0] selected_port;
	wire [1:0] selected_avail;
	
	assign selected_port = (primary_avail != 2'b00) ? primary_port : secondary_port;
	assign selected_avail = (primary_avail != 2'b00) ? primary_avail : secondary_avail;
	
	// Select lowest available VC (only 2 VCs now)
	assign selected_vc = selected_avail[0] ? 2'b00 :
	                      selected_avail[1] ? 2'b01 : 2'b00;
	
	assign route_out = {selected_port, selected_vc};

endmodule