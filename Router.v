
// ============================================================================
// Router Top-Level Module - FIXED: Added vc_active signals
// ============================================================================
module Router (
	input wire clk,
	input wire rst,
	input wire [2:0] router_x,
	input wire [2:0] router_y,
	
	// Input ports with data, valid, and VC
	input wire [63:0] northIn, eastIn, southIn, westIn, peIn,
	input wire northIn_valid, eastIn_valid, southIn_valid, westIn_valid, peIn_valid,
	input wire [1:0] northIn_vc, eastIn_vc, southIn_vc, westIn_vc, peIn_vc,
	
	// Credit inputs
	input wire [1:0] north_credits_in,
	input wire [1:0] east_credits_in,
	input wire [1:0] south_credits_in,
	input wire [1:0] west_credits_in,
	input wire [1:0] local_credits_in,
	
	// Output ports with data, valid, and VC
	output wire [63:0] northOut, eastOut, southOut, westOut, peOut,
	output wire northOut_valid, eastOut_valid, southOut_valid, westOut_valid, peOut_valid,
	output wire [1:0] northOut_vc, eastOut_vc, southOut_vc, westOut_vc, peOut_vc,
	
	// Credit outputs
	output wire [1:0] north_credits_out,
	output wire [1:0] east_credits_out,
	output wire [1:0] south_credits_out,
	output wire [1:0] west_credits_out,
	output wire [1:0] local_credits_out
);

	// Internal wires from buffers to RC
	wire [63:0] north_buf_to_rc, east_buf_to_rc, south_buf_to_rc, west_buf_to_rc, local_buf_to_rc;
	wire north_rc_valid, east_rc_valid, south_rc_valid, west_rc_valid, local_rc_valid;
	
	// Which INPUT VC is at RC stage for each buffer
	wire [1:0] north_buf_rc_vc, east_buf_rc_vc, south_buf_rc_vc, west_buf_rc_vc, local_buf_rc_vc;
	
	// Which INPUT VC is at SA stage for each buffer
	wire [1:0] north_buf_sa_vc, east_buf_sa_vc, south_buf_sa_vc, west_buf_sa_vc, local_buf_sa_vc;
	
	// NEW: Is any VC currently granted and active?
	wire north_buf_vc_active, east_buf_vc_active, south_buf_vc_active, west_buf_vc_active, local_buf_vc_active;
	
	// VC status and grant signals
	wire [1:0] north_buf_vc_status, east_buf_vc_status, south_buf_vc_status, west_buf_vc_status, local_buf_vc_status;
	wire [1:0] north_buf_vc_grant, east_buf_vc_grant, south_buf_vc_grant, west_buf_vc_grant, local_buf_vc_grant;
	wire [1:0] north_vc_available, east_vc_available, south_vc_available, west_vc_available, local_vc_available;
	
	// Route information
	wire [4:0] north_route, east_route, south_route, west_route, local_route;
	
	// CBA request/grant signals
	wire north_buf_cba_request, east_buf_cba_request, south_buf_cba_request, west_buf_cba_request, local_buf_cba_request;
	wire north_buf_cba_grant, east_buf_cba_grant, south_buf_cba_grant, west_buf_cba_grant, local_buf_cba_grant;
	
	// Crossbar select signals
	wire [2:0] north_out_select, east_out_select, south_out_select, west_out_select, local_out_select;
	
	// Data, VC, and valid from buffers to crossbar
	wire [63:0] north_buf_to_cbs, east_buf_to_cbs, south_buf_to_cbs, west_buf_to_cbs, local_buf_to_cbs;
	wire [1:0] north_buf_vc_to_cbs, east_buf_vc_to_cbs, south_buf_vc_to_cbs, west_buf_vc_to_cbs, local_buf_vc_to_cbs;
	wire north_buf_cbs_valid, east_buf_cbs_valid, south_buf_cbs_valid, west_buf_cbs_valid, local_buf_cbs_valid;
	
	// Extract flit_type and pkt_id from buffer outputs for CBA
	wire [2:0] north_buf_flit_type = north_buf_to_cbs[57:55];
	wire [2:0] east_buf_flit_type = east_buf_to_cbs[57:55];
	wire [2:0] south_buf_flit_type = south_buf_to_cbs[57:55];
	wire [2:0] west_buf_flit_type = west_buf_to_cbs[57:55];
	wire [2:0] local_buf_flit_type = local_buf_to_cbs[57:55];
	
	wire [6:0] north_buf_pkt_id = north_buf_to_cbs[54:48];
	wire [6:0] east_buf_pkt_id = east_buf_to_cbs[54:48];
	wire [6:0] south_buf_pkt_id = south_buf_to_cbs[54:48];
	wire [6:0] west_buf_pkt_id = west_buf_to_cbs[54:48];
	wire [6:0] local_buf_pkt_id = local_buf_to_cbs[54:48];
	
	// ========================================================================
	// Input Buffers
	// ========================================================================
	Buffer northBuffer (
		.clk(clk), .rst(rst),
		.dataIn(northIn), .dataIn_valid(northIn_valid), .dataIn_vc(northIn_vc),
		.vc_status(north_buf_vc_status), .vc_grant(north_buf_vc_grant),
		.rc_flit_out(north_buf_to_rc), .rc_valid(north_rc_valid), .rc_vc_out(north_buf_rc_vc),
		.sa_vc_out(north_buf_sa_vc), .vc_active(north_buf_vc_active),
		.cba_grant(north_buf_cba_grant), .cba_request(north_buf_cba_request),
		.cbs_flit_out(north_buf_to_cbs), .cbs_vc_out(north_buf_vc_to_cbs), .cbs_valid(north_buf_cbs_valid)
	);
	
	Buffer eastBuffer (
		.clk(clk), .rst(rst),
		.dataIn(eastIn), .dataIn_valid(eastIn_valid), .dataIn_vc(eastIn_vc),
		.vc_status(east_buf_vc_status), .vc_grant(east_buf_vc_grant),
		.rc_flit_out(east_buf_to_rc), .rc_valid(east_rc_valid), .rc_vc_out(east_buf_rc_vc),
		.sa_vc_out(east_buf_sa_vc), .vc_active(east_buf_vc_active),
		.cba_grant(east_buf_cba_grant), .cba_request(east_buf_cba_request),
		.cbs_flit_out(east_buf_to_cbs), .cbs_vc_out(east_buf_vc_to_cbs), .cbs_valid(east_buf_cbs_valid)
	);
	
	Buffer southBuffer (
		.clk(clk), .rst(rst),
		.dataIn(southIn), .dataIn_valid(southIn_valid), .dataIn_vc(southIn_vc),
		.vc_status(south_buf_vc_status), .vc_grant(south_buf_vc_grant),
		.rc_flit_out(south_buf_to_rc), .rc_valid(south_rc_valid), .rc_vc_out(south_buf_rc_vc),
		.sa_vc_out(south_buf_sa_vc), .vc_active(south_buf_vc_active),
		.cba_grant(south_buf_cba_grant), .cba_request(south_buf_cba_request),
		.cbs_flit_out(south_buf_to_cbs), .cbs_vc_out(south_buf_vc_to_cbs), .cbs_valid(south_buf_cbs_valid)
	);
	
	Buffer westBuffer (
		.clk(clk), .rst(rst),
		.dataIn(westIn), .dataIn_valid(westIn_valid), .dataIn_vc(westIn_vc),
		.vc_status(west_buf_vc_status), .vc_grant(west_buf_vc_grant),
		.rc_flit_out(west_buf_to_rc), .rc_valid(west_rc_valid), .rc_vc_out(west_buf_rc_vc),
		.sa_vc_out(west_buf_sa_vc), .vc_active(west_buf_vc_active),
		.cba_grant(west_buf_cba_grant), .cba_request(west_buf_cba_request),
		.cbs_flit_out(west_buf_to_cbs), .cbs_vc_out(west_buf_vc_to_cbs), .cbs_valid(west_buf_cbs_valid)
	);
	
	Buffer localBuffer (
		.clk(clk), .rst(rst),
		.dataIn(peIn), .dataIn_valid(peIn_valid), .dataIn_vc(peIn_vc),
		.vc_status(local_buf_vc_status), .vc_grant(local_buf_vc_grant),
		.rc_flit_out(local_buf_to_rc), .rc_valid(local_rc_valid), .rc_vc_out(local_buf_rc_vc),
		.sa_vc_out(local_buf_sa_vc), .vc_active(local_buf_vc_active),
		.cba_grant(local_buf_cba_grant), .cba_request(local_buf_cba_request),
		.cbs_flit_out(local_buf_to_cbs), .cbs_vc_out(local_buf_vc_to_cbs), .cbs_valid(local_buf_cbs_valid)
	);
	
	// ========================================================================
	// Route Computation
	// ========================================================================
	RC RCunit (
		.clk(clk), .rst(rst),
		.curr_x(router_x), .curr_y(router_y),
		.in_northBuf(north_buf_to_rc), .in_eastBuf(east_buf_to_rc),
		.in_southBuf(south_buf_to_rc), .in_westBuf(west_buf_to_rc),
		.in_localBuf(local_buf_to_rc),
		.north_vc_available(north_vc_available), .east_vc_available(east_vc_available),
		.south_vc_available(south_vc_available), .west_vc_available(west_vc_available),
		.local_vc_available(local_vc_available),
		.out_northBuf(north_route), .out_eastBuf(east_route),
		.out_southBuf(south_route), .out_westBuf(west_route), .out_local(local_route),
		.out_northBuf_vc(), .out_eastBuf_vc(), .out_southBuf_vc(), .out_westBuf_vc(), .out_local_vc()
	);
	
	// ========================================================================
	// Virtual Channel Allocator
	// ========================================================================
	VCA VCAunit (
		.clk(clk), .rst(rst),
		.north_buf_vc_status(north_buf_vc_status), .east_buf_vc_status(east_buf_vc_status),
		.south_buf_vc_status(south_buf_vc_status), .west_buf_vc_status(west_buf_vc_status),
		.local_buf_vc_status(local_buf_vc_status),
		.north_buf_rc_vc(north_buf_rc_vc), .east_buf_rc_vc(east_buf_rc_vc),
		.south_buf_rc_vc(south_buf_rc_vc), .west_buf_rc_vc(west_buf_rc_vc),
		.local_buf_rc_vc(local_buf_rc_vc),
		.north_buf_sa_vc(north_buf_sa_vc), .east_buf_sa_vc(east_buf_sa_vc),
		.south_buf_sa_vc(south_buf_sa_vc), .west_buf_sa_vc(west_buf_sa_vc),
		.local_buf_sa_vc(local_buf_sa_vc),
		.north_buf_vc_active(north_buf_vc_active), .east_buf_vc_active(east_buf_vc_active),
		.south_buf_vc_active(south_buf_vc_active), .west_buf_vc_active(west_buf_vc_active),
		.local_buf_vc_active(local_buf_vc_active),
		.north_route(north_route), .east_route(east_route), .south_route(south_route),
		.west_route(west_route), .local_route(local_route),
		.north_route_valid(north_rc_valid), .east_route_valid(east_rc_valid),
		.south_route_valid(south_rc_valid), .west_route_valid(west_rc_valid),
		.local_route_valid(local_rc_valid),
		.north_out_credits(north_credits_in), .east_out_credits(east_credits_in),
		.south_out_credits(south_credits_in), .west_out_credits(west_credits_in),
		.local_out_credits(local_credits_in),
		.north_in_credits(north_credits_out), .east_in_credits(east_credits_out),
		.south_in_credits(south_credits_out), .west_in_credits(west_credits_out),
		.local_in_credits(local_credits_out),
		.north_buf_vc_grant(north_buf_vc_grant), .east_buf_vc_grant(east_buf_vc_grant),
		.south_buf_vc_grant(south_buf_vc_grant), .west_buf_vc_grant(west_buf_vc_grant),
		.local_buf_vc_grant(local_buf_vc_grant),
		.north_vc_available(north_vc_available), .east_vc_available(east_vc_available),
		.south_vc_available(south_vc_available), .west_vc_available(west_vc_available),
		.local_vc_available(local_vc_available)
	);
	
	// ========================================================================
	// Crossbar Allocator
	// ========================================================================
	CBA CBAunit (
		.clk(clk), .rst(rst),
		.router_x(router_x), .router_y(router_y),
		.north_buf_request(north_buf_cba_request), .east_buf_request(east_buf_cba_request),
		.south_buf_request(south_buf_cba_request), .west_buf_request(west_buf_cba_request),
		.local_buf_request(local_buf_cba_request),
		.north_route(north_route), .east_route(east_route), .south_route(south_route),
		.west_route(west_route), .local_route(local_route),
		.north_buf_flit_type(north_buf_flit_type), .east_buf_flit_type(east_buf_flit_type),
		.south_buf_flit_type(south_buf_flit_type), .west_buf_flit_type(west_buf_flit_type),
		.local_buf_flit_type(local_buf_flit_type),
		.north_buf_pkt_id(north_buf_pkt_id), .east_buf_pkt_id(east_buf_pkt_id),
		.south_buf_pkt_id(south_buf_pkt_id), .west_buf_pkt_id(west_buf_pkt_id),
		.local_buf_pkt_id(local_buf_pkt_id),
		.north_buf_grant(north_buf_cba_grant), .east_buf_grant(east_buf_cba_grant),
		.south_buf_grant(south_buf_cba_grant), .west_buf_grant(west_buf_cba_grant),
		.local_buf_grant(local_buf_cba_grant),
		.north_out_select(north_out_select), .east_out_select(east_out_select),
		.south_out_select(south_out_select), .west_out_select(west_out_select),
		.local_out_select(local_out_select)
	);
	
	// ========================================================================
	// Crossbar Switch
	// ========================================================================
	CrossBarSwitch CBSunit (
		.northBuf(north_buf_to_cbs), .eastBuf(east_buf_to_cbs),
		.southBuf(south_buf_to_cbs), .westBuf(west_buf_to_cbs), .localBuf(local_buf_to_cbs),
		.northBuf_valid(north_buf_cbs_valid), .eastBuf_valid(east_buf_cbs_valid),
		.southBuf_valid(south_buf_cbs_valid), .westBuf_valid(west_buf_cbs_valid), .localBuf_valid(local_buf_cbs_valid),
		.northBuf_vc(north_buf_vc_to_cbs), .eastBuf_vc(east_buf_vc_to_cbs),
		.southBuf_vc(south_buf_vc_to_cbs), .westBuf_vc(west_buf_vc_to_cbs), .localBuf_vc(local_buf_vc_to_cbs),
		.north_out_select(north_out_select), .east_out_select(east_out_select),
		.south_out_select(south_out_select), .west_out_select(west_out_select),
		.local_out_select(local_out_select),
		.northOut(northOut), .eastOut(eastOut), .southOut(southOut),
		.westOut(westOut), .localOut(peOut),
		.northOut_valid(northOut_valid), .eastOut_valid(eastOut_valid),
		.southOut_valid(southOut_valid), .westOut_valid(westOut_valid), .localOut_valid(peOut_valid),
		.northOut_vc(northOut_vc), .eastOut_vc(eastOut_vc),
		.southOut_vc(southOut_vc), .westOut_vc(westOut_vc), .localOut_vc(peOut_vc)
	);

endmodule