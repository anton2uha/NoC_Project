// ============================================================================
// NoC Testbench - Enhanced with Complete Flit Verification
// ============================================================================
`timescale 1ns/1ps

module NoC_tb;

	// ========================================================================
	// Clock and Reset
	// ========================================================================
	reg clk;
	reg rst;
	
	parameter CLK_PERIOD = 10;  // 10ns = 100MHz
	
	initial begin
		clk = 0;
		forever #(CLK_PERIOD/2) clk = ~clk;
	end
	
	// ========================================================================
	// NoC Interface Signals (4-bit serialized)
	// ========================================================================
	reg [3:0] in_west, in_south, in_east, in_north;
	reg [1:0] west_sel, south_sel, east_sel, north_sel;
	reg in_west_valid, in_south_valid, in_east_valid, in_north_valid;
	reg in_west_vc, in_south_vc, in_east_vc, in_north_vc;
	
	wire [3:0] out_west, out_south, out_east, out_north;
	wire out_west_valid, out_south_valid, out_east_valid, out_north_valid;
	wire out_west_vc, out_south_vc, out_east_vc, out_north_vc;
	
	// ========================================================================
	// DUT Instantiation
	// ========================================================================
	NoC dut (
		.clk(clk), .rst(rst),
		.in_west(in_west), .in_south(in_south), .in_east(in_east), .in_north(in_north),
		.west_sel(west_sel), .south_sel(south_sel), .east_sel(east_sel), .north_sel(north_sel),
		.in_west_valid(in_west_valid), .in_south_valid(in_south_valid),
		.in_east_valid(in_east_valid), .in_north_valid(in_north_valid),
		.in_west_vc(in_west_vc), .in_south_vc(in_south_vc),
		.in_east_vc(in_east_vc), .in_north_vc(in_north_vc),
		.out_west(out_west), .out_south(out_south), .out_east(out_east), .out_north(out_north),
		.out_west_valid(out_west_valid), .out_south_valid(out_south_valid),
		.out_east_valid(out_east_valid), .out_north_valid(out_north_valid),
		.out_west_vc(out_west_vc), .out_south_vc(out_south_vc),
		.out_east_vc(out_east_vc), .out_north_vc(out_north_vc)
	);
	
	// ========================================================================
	// Test Variables
	// ========================================================================
	integer cycle_count;
	
	// Output reconstruction for each side
	reg [63:0] west_out_buffer, south_out_buffer, east_out_buffer, north_out_buffer;
	reg [63:0] pe_head, pe_body, pe_tail;
	reg [3:0] west_out_count, south_out_count, east_out_count, north_out_count;
	reg [63:0] west_completed, south_completed, east_completed, north_completed;
	reg west_complete, south_complete, east_complete, north_complete;
	
	// Acknowledgment signals to clear sticky completion flags
	reg west_complete_ack, south_complete_ack, east_complete_ack, north_complete_ack;
	
	// Previous state of completion flags (for edge detection)
	reg west_complete_prev, south_complete_prev, east_complete_prev, north_complete_prev;
	
	// Packet tracking
	integer packets_sent;
	integer packets_received;
	integer packets_verified;
	integer packets_failed;
	
	// Enhanced verification
	reg [63:0] expected_flits [0:2];
	reg [63:0] received_flits [0:2];
	
	// Debug control
	reg enable_debug_monitor;
	
	// ========================================================================
	// Port Name Lookup (for debug messages)
	// ========================================================================
	function [8*4:1] get_port_name;
		input [1:0] side;      // 0=west, 1=south, 2=east, 3=north
		input [1:0] position;  // 0=first, 1=middle, 2=last
		begin
			case ({side, position})
				{2'd0, 2'd0}: get_port_name = "01";
				{2'd0, 2'd1}: get_port_name = "02";
				{2'd0, 2'd2}: get_port_name = "03";
				{2'd1, 2'd0}: get_port_name = "10";
				{2'd1, 2'd1}: get_port_name = "20";
				{2'd1, 2'd2}: get_port_name = "30";
				{2'd2, 2'd0}: get_port_name = "41";
				{2'd2, 2'd1}: get_port_name = "42";
				{2'd2, 2'd2}: get_port_name = "43";
				{2'd3, 2'd0}: get_port_name = "14";
				{2'd3, 2'd1}: get_port_name = "24";
				{2'd3, 2'd2}: get_port_name = "34";
				default: get_port_name = "??";
			endcase
		end
	endfunction
	
	function [8*8:1] get_side_name;
		input [1:0] side;
		begin
			case (side)
				2'd0: get_side_name = "WEST";
				2'd1: get_side_name = "SOUTH";
				2'd2: get_side_name = "EAST";
				2'd3: get_side_name = "NORTH";
				default: get_side_name = "UNKNOWN";
			endcase
		end
	endfunction
	
	// ========================================================================
	// Helper Function: Create Packet Flit
	// ========================================================================
	function [63:0] create_flit;
		input [2:0] dest_y;
		input [2:0] dest_x;
		input [2:0] flit_type;  // 000=head, 001=body, 010=tail
		input [6:0] packet_id;
		input [47:0] payload;
		begin
			create_flit = {dest_y, dest_x, flit_type, packet_id, payload};
		end
	endfunction
	
	// ========================================================================
	// Helper Task: Display Flit Information
	// ========================================================================
	task display_flit;
		input [63:0] flit;
		input [8*30:1] label;
		begin
			$display("  %s:", label);
			$display("    Dest: (%0d,%0d) | Type: %s | ID: %0d | Payload: 0x%012h",
				flit[63:61], flit[60:58],
				(flit[57:55] == 3'b000) ? "HEAD" :
				(flit[57:55] == 3'b001) ? "BODY" :
				(flit[57:55] == 3'b010) ? "TAIL" : "UNKNOWN",
				flit[54:48], flit[47:0]);
		end
	endtask
	
	// ========================================================================
	// TASK: Configure Active Ports (Set Select Signals)
	// ========================================================================
	task configure_ports;
		input [1:0] west_port;   // 0=port01, 1=port02, 2=port03
		input [1:0] south_port;  // 0=port10, 1=port20, 2=port30
		input [1:0] east_port;   // 0=port41, 1=port42, 2=port43
		input [1:0] north_port;  // 0=port14, 1=port24, 2=port34
		begin
			west_sel = west_port;
			south_sel = south_port;
			east_sel = east_port;
			north_sel = north_port;
			$display("[CONFIG] Active ports: West=%s, South=%s, East=%s, North=%s",
				get_port_name(2'd0, west_port),
				get_port_name(2'd1, south_port),
				get_port_name(2'd2, east_port),
				get_port_name(2'd3, north_port));
		end
	endtask
	
	// ========================================================================
	// TASK: Inject Single Flit (Serialized over 16 cycles)
	// ========================================================================
	task inject_flit_on_side;
		input [1:0] side;        // 0=west, 1=south, 2=east, 3=north
		input [63:0] flit;
		input vc;
		integer i;
		begin
			for (i = 0; i < 16; i = i + 1) begin
				@(posedge clk);
				case (side)
					2'd0: begin  // West
						in_west = flit[i*4 +: 4];
						in_west_valid = 1'b1;
						in_west_vc = vc;
					end
					2'd1: begin  // South
						in_south = flit[i*4 +: 4];
						in_south_valid = 1'b1;
						in_south_vc = vc;
					end
					2'd2: begin  // East
						in_east = flit[i*4 +: 4];
						in_east_valid = 1'b1;
						in_east_vc = vc;
					end
					2'd3: begin  // North
						in_north = flit[i*4 +: 4];
						in_north_valid = 1'b1;
						in_north_vc = vc;
					end
				endcase
			end
			@(posedge clk);
			// Deassert valid
			case (side)
				2'd0: in_west_valid = 1'b0;
				2'd1: in_south_valid = 1'b0;
				2'd2: in_east_valid = 1'b0;
				2'd3: in_north_valid = 1'b0;
			endcase
		end
	endtask
	
	// ========================================================================
	// TASK: Send Complete 3-Flit Packet
	// ========================================================================
	task send_packet;
		input [1:0] src_side;
		input [1:0] src_position;
		input [1:0] dst_side;
		input [1:0] dst_position;
		input [6:0] pkt_id;
		input [47:0] payload_head;
		input [47:0] payload_body;
		input [47:0] payload_tail;
		input vc;
		
		reg [2:0] dest_x, dest_y;
		reg [63:0] head_flit, body_flit, tail_flit;
		begin
			// Calculate destination coordinates
			case ({dst_side, dst_position})
				{2'd0, 2'd0}: begin dest_x = 3'd0; dest_y = 3'd1; end
				{2'd0, 2'd1}: begin dest_x = 3'd0; dest_y = 3'd2; end
				{2'd0, 2'd2}: begin dest_x = 3'd0; dest_y = 3'd3; end
				{2'd1, 2'd0}: begin dest_x = 3'd1; dest_y = 3'd0; end
				{2'd1, 2'd1}: begin dest_x = 3'd2; dest_y = 3'd0; end
				{2'd1, 2'd2}: begin dest_x = 3'd3; dest_y = 3'd0; end
				{2'd2, 2'd0}: begin dest_x = 3'd4; dest_y = 3'd1; end
				{2'd2, 2'd1}: begin dest_x = 3'd4; dest_y = 3'd2; end
				{2'd2, 2'd2}: begin dest_x = 3'd4; dest_y = 3'd3; end
				{2'd3, 2'd0}: begin dest_x = 3'd1; dest_y = 3'd4; end
				{2'd3, 2'd1}: begin dest_x = 3'd2; dest_y = 3'd4; end
				{2'd3, 2'd2}: begin dest_x = 3'd3; dest_y = 3'd4; end
				default: begin dest_x = 3'd0; dest_y = 3'd0; end
			endcase
			
			// Create flits
			head_flit = create_flit(dest_y, dest_x, 3'b000, pkt_id, payload_head);
			body_flit = create_flit(dest_y, dest_x, 3'b001, pkt_id, payload_body);
			tail_flit = create_flit(dest_y, dest_x, 3'b010, pkt_id, payload_tail);
			
			$display("\n[CYCLE %0d] Sending packet from %s (port %s) to %s (port %s)",
				cycle_count,
				get_side_name(src_side), get_port_name(src_side, src_position),
				get_side_name(dst_side), get_port_name(dst_side, dst_position));
			$display("  Packet ID: %0d, VC: %0d", pkt_id, vc);
			display_flit(head_flit, "HEAD");
			display_flit(body_flit, "BODY");
			display_flit(tail_flit, "TAIL");
			
			// Configure ports
			case (src_side)
				2'd0: configure_ports(src_position, south_sel, east_sel, north_sel);
				2'd1: configure_ports(west_sel, src_position, east_sel, north_sel);
				2'd2: configure_ports(west_sel, south_sel, src_position, north_sel);
				2'd3: configure_ports(west_sel, south_sel, east_sel, src_position);
			endcase
			case (dst_side)
				2'd0: configure_ports(dst_position, south_sel, east_sel, north_sel);
				2'd1: configure_ports(west_sel, dst_position, east_sel, north_sel);
				2'd2: configure_ports(west_sel, south_sel, dst_position, north_sel);
				2'd3: configure_ports(west_sel, south_sel, east_sel, dst_position);
			endcase
			
			// Clear completion flags
			case (dst_side)
				2'd0: begin west_complete_ack = 1; @(posedge clk); west_complete_ack = 0; end
				2'd1: begin south_complete_ack = 1; @(posedge clk); south_complete_ack = 0; end
				2'd2: begin east_complete_ack = 1; @(posedge clk); east_complete_ack = 0; end
				2'd3: begin north_complete_ack = 1; @(posedge clk); north_complete_ack = 0; end
			endcase
			
			// Inject flits
			$display("  [CYCLE %0d] Injecting HEAD flit...", cycle_count);
			inject_flit_on_side(src_side, head_flit, vc);
			repeat(2) @(posedge clk);
			
			$display("  [CYCLE %0d] Injecting BODY flit...", cycle_count);
			inject_flit_on_side(src_side, body_flit, vc);
			repeat(2) @(posedge clk);
			
			$display("  [CYCLE %0d] Injecting TAIL flit...", cycle_count);
			inject_flit_on_side(src_side, tail_flit, vc);
			
			$display("  [CYCLE %0d] Packet injection complete\n", cycle_count);
		end
	endtask
	
	// ========================================================================
	// TASK: Send Packet - Side Specific (West)
	// ========================================================================
	task send_packet_west;
		input [1:0] src_position;
		input [1:0] dst_side;
		input [1:0] dst_position;
		input [6:0] pkt_id;
		input [47:0] payload_head;
		input [47:0] payload_body;
		input [47:0] payload_tail;
		input vc;
		
		reg [2:0] dest_x, dest_y;
		reg [63:0] head_flit, body_flit, tail_flit;
		integer i;
		begin
			// Calculate destination
			case ({dst_side, dst_position})
				{2'd0, 2'd0}: begin dest_x = 3'd0; dest_y = 3'd1; end
				{2'd0, 2'd1}: begin dest_x = 3'd0; dest_y = 3'd2; end
				{2'd0, 2'd2}: begin dest_x = 3'd0; dest_y = 3'd3; end
				{2'd1, 2'd0}: begin dest_x = 3'd1; dest_y = 3'd0; end
				{2'd1, 2'd1}: begin dest_x = 3'd2; dest_y = 3'd0; end
				{2'd1, 2'd2}: begin dest_x = 3'd3; dest_y = 3'd0; end
				{2'd2, 2'd0}: begin dest_x = 3'd4; dest_y = 3'd1; end
				{2'd2, 2'd1}: begin dest_x = 3'd4; dest_y = 3'd2; end
				{2'd2, 2'd2}: begin dest_x = 3'd4; dest_y = 3'd3; end
				{2'd3, 2'd0}: begin dest_x = 3'd1; dest_y = 3'd4; end
				{2'd3, 2'd1}: begin dest_x = 3'd2; dest_y = 3'd4; end
				{2'd3, 2'd2}: begin dest_x = 3'd3; dest_y = 3'd4; end
				default: begin dest_x = 3'd0; dest_y = 3'd0; end
			endcase
			
			head_flit = create_flit(dest_y, dest_x, 3'b000, pkt_id, payload_head);
			body_flit = create_flit(dest_y, dest_x, 3'b001, pkt_id, payload_body);
			tail_flit = create_flit(dest_y, dest_x, 3'b010, pkt_id, payload_tail);
			
			// Inject HEAD
			for (i = 0; i < 16; i = i + 1) begin
				@(posedge clk);
				in_west = head_flit[i*4 +: 4];
				in_west_valid = 1'b1;
				in_west_vc = vc;
			end
			@(posedge clk);
			in_west_valid = 1'b0;
			in_west = 4'b0;
			repeat(2) @(posedge clk);
			
			// Inject BODY
			for (i = 0; i < 16; i = i + 1) begin
				@(posedge clk);
				in_west = body_flit[i*4 +: 4];
				in_west_valid = 1'b1;
				in_west_vc = vc;
			end
			@(posedge clk);
			in_west_valid = 1'b0;
			in_west = 4'b0;
			repeat(2) @(posedge clk);
			
			// Inject TAIL
			for (i = 0; i < 16; i = i + 1) begin
				@(posedge clk);
				in_west = tail_flit[i*4 +: 4];
				in_west_valid = 1'b1;
				in_west_vc = vc;
			end
			@(posedge clk);
			in_west_valid = 1'b0;
			in_west = 4'b0;
		end
	endtask
	
	// ========================================================================
	// TASK: Send Packet - Side Specific (South)
	// ========================================================================
	task send_packet_south;
		input [1:0] src_position;
		input [1:0] dst_side;
		input [1:0] dst_position;
		input [6:0] pkt_id;
		input [47:0] payload_head;
		input [47:0] payload_body;
		input [47:0] payload_tail;
		input vc;
		
		reg [2:0] dest_x, dest_y;
		reg [63:0] head_flit, body_flit, tail_flit;
		integer i;
		begin
			// Calculate destination
			case ({dst_side, dst_position})
				{2'd0, 2'd0}: begin dest_x = 3'd0; dest_y = 3'd1; end
				{2'd0, 2'd1}: begin dest_x = 3'd0; dest_y = 3'd2; end
				{2'd0, 2'd2}: begin dest_x = 3'd0; dest_y = 3'd3; end
				{2'd1, 2'd0}: begin dest_x = 3'd1; dest_y = 3'd0; end
				{2'd1, 2'd1}: begin dest_x = 3'd2; dest_y = 3'd0; end
				{2'd1, 2'd2}: begin dest_x = 3'd3; dest_y = 3'd0; end
				{2'd2, 2'd0}: begin dest_x = 3'd4; dest_y = 3'd1; end
				{2'd2, 2'd1}: begin dest_x = 3'd4; dest_y = 3'd2; end
				{2'd2, 2'd2}: begin dest_x = 3'd4; dest_y = 3'd3; end
				{2'd3, 2'd0}: begin dest_x = 3'd1; dest_y = 3'd4; end
				{2'd3, 2'd1}: begin dest_x = 3'd2; dest_y = 3'd4; end
				{2'd3, 2'd2}: begin dest_x = 3'd3; dest_y = 3'd4; end
				default: begin dest_x = 3'd0; dest_y = 3'd0; end
			endcase
			
			head_flit = create_flit(dest_y, dest_x, 3'b000, pkt_id, payload_head);
			body_flit = create_flit(dest_y, dest_x, 3'b001, pkt_id, payload_body);
			tail_flit = create_flit(dest_y, dest_x, 3'b010, pkt_id, payload_tail);
			
			// Inject HEAD
			for (i = 0; i < 16; i = i + 1) begin
				@(posedge clk);
				in_south = head_flit[i*4 +: 4];
				in_south_valid = 1'b1;
				in_south_vc = vc;
			end
			@(posedge clk);
			in_south_valid = 1'b0;
			in_south = 4'b0;
			repeat(2) @(posedge clk);
			
			// Inject BODY
			for (i = 0; i < 16; i = i + 1) begin
				@(posedge clk);
				in_south = body_flit[i*4 +: 4];
				in_south_valid = 1'b1;
				in_south_vc = vc;
			end
			@(posedge clk);
			in_south_valid = 1'b0;
			in_south = 4'b0;
			repeat(2) @(posedge clk);
			
			// Inject TAIL
			for (i = 0; i < 16; i = i + 1) begin
				@(posedge clk);
				in_south = tail_flit[i*4 +: 4];
				in_south_valid = 1'b1;
				in_south_vc = vc;
			end
			@(posedge clk);
			in_south_valid = 1'b0;
			in_south = 4'b0;
		end
	endtask
	
	// ========================================================================
	// TASK: Send packet with MULTIPLE body flits
	// ========================================================================
	task send_packet_west_multi_body;
		input [1:0] src_position;
		input [1:0] dst_side;
		input [1:0] dst_position;
		input [6:0] pkt_id;
		input [47:0] payload_head;
		input [47:0] payload_tail;
		input vc;
		input integer num_body_flits;
		
		reg [2:0] dest_x, dest_y;
		reg [63:0] head_flit, body_flit, tail_flit;
		integer i, b;
		begin
			// Calculate destination
			case ({dst_side, dst_position})
				{2'd0, 2'd0}: begin dest_x = 3'd0; dest_y = 3'd1; end
				{2'd0, 2'd1}: begin dest_x = 3'd0; dest_y = 3'd2; end
				{2'd0, 2'd2}: begin dest_x = 3'd0; dest_y = 3'd3; end
				{2'd1, 2'd0}: begin dest_x = 3'd1; dest_y = 3'd0; end
				{2'd1, 2'd1}: begin dest_x = 3'd2; dest_y = 3'd0; end
				{2'd1, 2'd2}: begin dest_x = 3'd3; dest_y = 3'd0; end
				{2'd2, 2'd0}: begin dest_x = 3'd4; dest_y = 3'd1; end
				{2'd2, 2'd1}: begin dest_x = 3'd4; dest_y = 3'd2; end
				{2'd2, 2'd2}: begin dest_x = 3'd4; dest_y = 3'd3; end
				{2'd3, 2'd0}: begin dest_x = 3'd1; dest_y = 3'd4; end
				{2'd3, 2'd1}: begin dest_x = 3'd2; dest_y = 3'd4; end
				{2'd3, 2'd2}: begin dest_x = 3'd3; dest_y = 3'd4; end
				default: begin dest_x = 3'd0; dest_y = 3'd0; end
			endcase
			
			head_flit = create_flit(dest_y, dest_x, 3'b000, pkt_id, payload_head);
			tail_flit = create_flit(dest_y, dest_x, 3'b010, pkt_id, payload_tail);
			
			$display("[CYCLE %0d] Injecting HEAD flit (West, multi-body packet)...", cycle_count);
			// Inject HEAD
			for (i = 0; i < 16; i = i + 1) begin
				@(posedge clk);
				in_west = head_flit[i*4 +: 4];
				in_west_valid = 1'b1;
				in_west_vc = vc;
			end
			@(posedge clk);
			in_west_valid = 1'b0;
			in_west = 4'b0;
			repeat(2) @(posedge clk);
			
			// Inject MULTIPLE BODY flits
			$display("[CYCLE %0d] Injecting %0d BODY flits (West)...", cycle_count, num_body_flits);
			for (b = 0; b < num_body_flits; b = b + 1) begin
				body_flit = create_flit(dest_y, dest_x, 3'b001, pkt_id, {40'hB0D0_000000, b[7:0]});
				
				for (i = 0; i < 16; i = i + 1) begin
					@(posedge clk);
					in_west = body_flit[i*4 +: 4];
					in_west_valid = 1'b1;
					in_west_vc = vc;
				end
				@(posedge clk);
				in_west_valid = 1'b0;
				in_west = 4'b0;
				repeat(2) @(posedge clk);
			end
			
			// Inject TAIL
			$display("[CYCLE %0d] Injecting TAIL flit (West)...", cycle_count);
			for (i = 0; i < 16; i = i + 1) begin
				@(posedge clk);
				in_west = tail_flit[i*4 +: 4];
				in_west_valid = 1'b1;
				in_west_vc = vc;
			end
			@(posedge clk);
			in_west_valid = 1'b0;
			in_west = 4'b0;
		end
	endtask
	
	// ========================================================================
	// TASK: Verify Complete Packet
	// ========================================================================
	task verify_complete_packet;
    input [1:0] exp_side;
    input [63:0] exp_head;
    input [63:0] exp_body;
    input [63:0] exp_tail;
    input integer max_cycles;
    
    integer flits_received;
    integer i;
    reg [63:0] received_flit;
    reg all_match;
    reg [63:0] last_seen_flit;  // Track the last flit we counted
    begin
        flits_received = 0;
        all_match = 1;
        last_seen_flit = 64'hFFFFFFFFFFFFFFFF;  // Initialize to impossible value
        
        $display("[CYCLE %0d] Waiting & verifying complete packet (3 flits) on %s side (max %0d cycles)...",
            cycle_count, get_side_name(exp_side), max_cycles);
        
        // Store expected flits
        expected_flits[0] = exp_head;
        expected_flits[1] = exp_body;
        expected_flits[2] = exp_tail;
        
        for (i = 0; i < max_cycles && flits_received < 3; i = i + 1) begin
            @(posedge clk);
            
            // Check if there's a NEW completed flit (different from last one we saw)
            case (exp_side)
                2'd0: begin
                    if (west_complete && west_completed !== last_seen_flit) begin
                        received_flit = west_completed;
                        last_seen_flit = west_completed;
                        
                        // Verify this flit
                        if (received_flit !== expected_flits[flits_received]) begin
                            $display("[CYCLE %0d] FLIT MISMATCH", cycle_count);
                            $display("  Flit %0d/3:", flits_received + 1);
                            $display("    Expected: 0x%016h", expected_flits[flits_received]);
                            $display("    Received: 0x%016h", received_flit);
                            display_flit(expected_flits[flits_received], "Expected");
                            display_flit(received_flit, "Received");
                            all_match = 0;
                            packets_failed = packets_failed + 1;
                        end else begin
                            $display("[CYCLE %0d]   Flit %0d/3 received and verified", cycle_count, flits_received + 1);
                        end
                        flits_received = flits_received + 1;
                    end
                end
                2'd1: begin
                    if (south_complete && south_completed !== last_seen_flit) begin
                        received_flit = south_completed;
                        last_seen_flit = south_completed;
                        
                        if (received_flit !== expected_flits[flits_received]) begin
                            $display("[CYCLE %0d] FLIT MISMATCH", cycle_count);
                            $display("  Flit %0d/3:", flits_received + 1);
                            $display("    Expected: 0x%016h", expected_flits[flits_received]);
                            $display("    Received: 0x%016h", received_flit);
                            display_flit(expected_flits[flits_received], "Expected");
                            display_flit(received_flit, "Received");
                            all_match = 0;
                            packets_failed = packets_failed + 1;
                        end else begin
                            $display("[CYCLE %0d]   Flit %0d/3 received and verified", cycle_count, flits_received + 1);
                        end
                        flits_received = flits_received + 1;
                    end
                end
                2'd2: begin
                    if (east_complete && east_completed !== last_seen_flit) begin
                        received_flit = east_completed;
                        last_seen_flit = east_completed;
                        
                        if (received_flit !== expected_flits[flits_received]) begin
                            $display("[CYCLE %0d] FLIT MISMATCH ", cycle_count);
                            $display("  Flit %0d/3:", flits_received + 1);
                            $display("    Expected: 0x%016h", expected_flits[flits_received]);
                            $display("    Received: 0x%016h", received_flit);
                            display_flit(expected_flits[flits_received], "Expected");
                            display_flit(received_flit, "Received");
                            all_match = 0;
                            packets_failed = packets_failed + 1;
                        end else begin
                            $display("[CYCLE %0d]    Flit %0d/3 received and verified", cycle_count, flits_received + 1);
                        end
                        flits_received = flits_received + 1;
                    end
                end
                2'd3: begin
                    if (north_complete && north_completed !== last_seen_flit) begin
                        received_flit = north_completed;
                        last_seen_flit = north_completed;
                        
                        if (received_flit !== expected_flits[flits_received]) begin
                            $display("[CYCLE %0d]  FLIT MISMATCH ", cycle_count);
                            $display("  Flit %0d/3:", flits_received + 1);
                            $display("    Expected: 0x%016h", expected_flits[flits_received]);
                            $display("    Received: 0x%016h", received_flit);
                            display_flit(expected_flits[flits_received], "Expected");
                            display_flit(received_flit, "Received");
                            all_match = 0;
                            packets_failed = packets_failed + 1;
                        end else begin
                            $display("[CYCLE %0d]    Flit %0d/3 received and verified", cycle_count, flits_received + 1);
                        end
                        flits_received = flits_received + 1;
                    end
                end
            endcase
        end
        
        if (flits_received < 3) begin
            $display("[CYCLE %0d] INCOMPLETE PACKET: only %0d/3 flits received on %s side",
                cycle_count, flits_received, get_side_name(exp_side));
            all_match = 0;
            packets_failed = packets_failed + 1;
        end else if (all_match) begin
            $display("[CYCLE %0d] Complete packet received and VERIFIED on %s side ", 
                cycle_count, get_side_name(exp_side));
            packets_received = packets_received + 1;
            packets_verified = packets_verified + 1;
        end else begin
            $display("[CYCLE %0d] Packet received but CONTENT MISMATCH on %s side",
                cycle_count, get_side_name(exp_side));
        end
    end
endtask


	task clear_all_complete_flags;
    begin
        east_complete_ack = 1;
        west_complete_ack = 1;
        north_complete_ack = 1;
        south_complete_ack = 1;
        @(posedge clk);
        east_complete_ack = 0;
        west_complete_ack = 0;
        north_complete_ack = 0;
        south_complete_ack = 0;
        repeat(3) @(posedge clk);
    end
endtask
	
	// ========================================================================
	// Output Deserializers (Reconstruct 64-bit flits from 4-bit outputs)
	// ========================================================================
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			west_out_buffer <= 64'b0;
			west_out_count <= 4'b0;
			west_completed <= 64'b0;
			west_complete <= 1'b0;
		end else begin
			if (west_complete_ack) begin
				west_complete <= 1'b0;
			end
			
			if (out_west_valid) begin
				west_out_buffer[west_out_count*4 +: 4] <= out_west;
				if (west_out_count == 4'd15) begin
					west_completed <= {out_west, west_out_buffer[59:0]};
					west_complete <= 1'b1;
					west_out_count <= 4'b0;
				end else begin
					west_out_count <= west_out_count + 1'b1;
				end
			end
		end
	end
	
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			south_out_buffer <= 64'b0;
			south_out_count <= 4'b0;
			south_completed <= 64'b0;
			south_complete <= 1'b0;
		end else begin
			if (south_complete_ack) begin
				south_complete <= 1'b0;
			end
			
			if (out_south_valid) begin
				south_out_buffer[south_out_count*4 +: 4] <= out_south;
				if (south_out_count == 4'd15) begin
					south_completed <= {out_south, south_out_buffer[59:0]};
					south_complete <= 1'b1;
					south_out_count <= 4'b0;
				end else begin
					south_out_count <= south_out_count + 1'b1;
				end
			end
		end
	end
	
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			east_out_buffer <= 64'b0;
			east_out_count <= 4'b0;
			east_completed <= 64'b0;
			east_complete <= 1'b0;
		end else begin
			if (east_complete_ack) begin
				east_complete <= 1'b0;
			end
			
			if (out_east_valid) begin
				east_out_buffer[east_out_count*4 +: 4] <= out_east;
				if (east_out_count == 4'd15) begin
					east_completed <= {out_east, east_out_buffer[59:0]};
					east_complete <= 1'b1;
					east_out_count <= 4'b0;
				end else begin
					east_out_count <= east_out_count + 1'b1;
				end
			end
		end
	end
	
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			north_out_buffer <= 64'b0;
			north_out_count <= 4'b0;
			north_completed <= 64'b0;
			north_complete <= 1'b0;
		end else begin
			if (north_complete_ack) begin
				north_complete <= 1'b0;
			end
			
			if (out_north_valid) begin
				north_out_buffer[north_out_count*4 +: 4] <= out_north;
				if (north_out_count == 4'd15) begin
					north_completed <= {out_north, north_out_buffer[59:0]};
					north_complete <= 1'b1;
					north_out_count <= 4'b0;
				end else begin
					north_out_count <= north_out_count + 1'b1;
				end
			end
		end
	end
	
	// ========================================================================
	// Monitor: Display when packets are received (only on rising edge)
	// ========================================================================
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			west_complete_prev <= 1'b0;
			south_complete_prev <= 1'b0;
			east_complete_prev <= 1'b0;
			north_complete_prev <= 1'b0;
		end else begin
			west_complete_prev <= west_complete;
			south_complete_prev <= south_complete;
			east_complete_prev <= east_complete;
			north_complete_prev <= north_complete;
			
			if (west_complete && !west_complete_prev && enable_debug_monitor) begin
				$display("[CYCLE %0d] *** Packet received on WEST side ***", cycle_count);
				display_flit(west_completed, "Received");
			end
			if (south_complete && !south_complete_prev && enable_debug_monitor) begin
				$display("[CYCLE %0d] *** Packet received on SOUTH side ***", cycle_count);
				display_flit(south_completed, "Received");
			end
			if (east_complete && !east_complete_prev && enable_debug_monitor) begin
				$display("[CYCLE %0d] *** Packet received on EAST side ***", cycle_count);
				display_flit(east_completed, "Received");
			end
			if (north_complete && !north_complete_prev && enable_debug_monitor) begin
				$display("[CYCLE %0d] *** Packet received on NORTH side ***", cycle_count);
				display_flit(north_completed, "Received");
			end
		end
	end
	
	// ========================================================================
	// Main Test Sequence
	// ========================================================================
	initial begin
		$dumpfile("noc_test_verified.vcd");
		$dumpvars(0, NoC_tb);
		
		$display("\n================================================================================");
		$display("NoC Enhanced Testbench with Complete Flit Verification");
		$display("================================================================================\n");
		
		// ====================================================================
		// Initialization
		// ====================================================================
		cycle_count = 0;
		rst = 1;
		packets_sent = 0;
		packets_received = 0;
		packets_verified = 0;
		packets_failed = 0;
		enable_debug_monitor = 0;  // Disable for cleaner output
		
		in_west = 4'b0;
		in_south = 4'b0;
		in_east = 4'b0;
		in_north = 4'b0;
		
		west_sel = 2'b00;
		south_sel = 2'b00;
		east_sel = 2'b00;
		north_sel = 2'b00;
		
		in_west_valid = 0;
		in_south_valid = 0;
		in_east_valid = 0;
		in_north_valid = 0;
		
		in_west_vc = 1'b0;
		in_south_vc = 1'b0;
		in_east_vc = 1'b0;
		in_north_vc = 1'b0;
		
		west_complete_ack = 0;
		south_complete_ack = 0;
		east_complete_ack = 0;
		north_complete_ack = 0;
		
		west_complete_prev = 0;
		south_complete_prev = 0;
		east_complete_prev = 0;
		north_complete_prev = 0;
		
		repeat(5) @(posedge clk);
		rst = 0;
		$display("[CYCLE %0d] Reset released\n", cycle_count);
		repeat(3) @(posedge clk);
		
		// ====================================================================
		// TEST CASE 1: West to East (Port 03 → Port 43)
		// ====================================================================
		$display("\n========================================");
		$display("TEST CASE 1: West to East");
		$display("========================================");
			
		fork
			begin
				send_packet(2'd0, 2'd2, 2'd2, 2'd2, 7'd1, 48'hABCD_1111_0001, 48'hABCD_1111_0002, 48'hABCD_1111_0003, 1'b1);  // Changed to 1'b1
				packets_sent = packets_sent + 1;
		end
		begin
				#10; // Small delay to let send_packet start
				verify_complete_packet(2'd2, 
				create_flit(3'd3, 3'd4, 3'b000, 7'd1, 48'hABCD_1111_0001),
				create_flit(3'd3, 3'd4, 3'b001, 7'd1, 48'hABCD_1111_0002),
				create_flit(3'd3, 3'd4, 3'b010, 7'd1, 48'hABCD_1111_0003),
				250);
		end
		join	
		
		repeat(10) @(posedge clk);
		
		// ====================================================================
		// TEST CASE 2: South to North (Port 20 → Port 24)
		// ====================================================================
		$display("\n========================================");
		$display("TEST CASE 2: South to North");
		$display("========================================");
		send_packet(2'd1, 2'd1, 2'd3, 2'd1, 7'd2, 48'hBEEF_2222_0001, 48'hBEEF_2222_0002, 48'hBEEF_2222_0003, 1'b0);  // Changed to 1'b0
		packets_sent = packets_sent + 1;
		verify_complete_packet(2'd3,
			create_flit(3'd4, 3'd2, 3'b000, 7'd2, 48'hBEEF_2222_0001),
			create_flit(3'd4, 3'd2, 3'b001, 7'd2, 48'hBEEF_2222_0002),
			create_flit(3'd4, 3'd2, 3'b010, 7'd2, 48'hBEEF_2222_0003),
			250);
		repeat(10) @(posedge clk);
		
		// ====================================================================
		// TEST CASE 3: East to West (Port 41 → Port 01)
		// ====================================================================
		$display("\n========================================");
		$display("TEST CASE 3: East to West");
		$display("========================================");
		send_packet(2'd2, 2'd0, 2'd0, 2'd0, 7'd3, 48'hCAFE_3333_0001, 48'hCAFE_3333_0002, 48'hCAFE_3333_0003, 1'b0);  // Changed to 1'b0
		packets_sent = packets_sent + 1;
		verify_complete_packet(2'd0,
			create_flit(3'd1, 3'd0, 3'b000, 7'd3, 48'hCAFE_3333_0001),
			create_flit(3'd1, 3'd0, 3'b001, 7'd3, 48'hCAFE_3333_0002),
			create_flit(3'd1, 3'd0, 3'b010, 7'd3, 48'hCAFE_3333_0003),
			250);
		repeat(10) @(posedge clk);
		
		// ====================================================================
		// TEST CASE 4: North to South (Port 34 → Port 30)
		// ====================================================================
		$display("\n========================================");
		$display("TEST CASE 4: North to South");
		$display("========================================");
		send_packet(2'd3, 2'd2, 2'd1, 2'd2, 7'd4, 48'hDEAD_4444_0001, 48'hDEAD_4444_0002, 48'hDEAD_4444_0003, 1'b0);  // Changed to 1'b0
		packets_sent = packets_sent + 1;
		verify_complete_packet(2'd1,
			create_flit(3'd0, 3'd3, 3'b000, 7'd4, 48'hDEAD_4444_0001),
			create_flit(3'd0, 3'd3, 3'b001, 7'd4, 48'hDEAD_4444_0002),
			create_flit(3'd0, 3'd3, 3'b010, 7'd4, 48'hDEAD_4444_0003),
			250);
		repeat(10) @(posedge clk);
		
		// ====================================================================
		// TEST CASE 5: Overlapping Traffic - West->East + South->North
		// ====================================================================
		$display("\n========================================");
		$display("TEST CASE 5: Overlapping Traffic (Same VC)");
		$display("Path 1: West(02) -> East(42) via (1,2)->(2,2)->(3,2)");
		$display("Path 2: South(20) -> North(24) via (2,1)->(2,2)->(2,3)");
		$display("*** Paths intersect at router (2,2) ***");
		$display("========================================");
		
		configure_ports(2'd1, 2'd1, 2'd1, 2'd1);
		
		
		clear_all_complete_flags();
		
		fork
			begin
				#10
				verify_complete_packet(2'd2,
				create_flit(3'd2, 3'd4, 3'b000, 7'd5, 48'hAAAA_5555_0001),
				create_flit(3'd2, 3'd4, 3'b001, 7'd5, 48'hAAAA_5555_0002),
				create_flit(3'd2, 3'd4, 3'b010, 7'd5, 48'hAAAA_5555_0003),
				250);
			end
			begin
				#10
				verify_complete_packet(2'd3,
				create_flit(3'd4, 3'd2, 3'b000, 7'd6, 48'hBBBB_6666_0001),
				create_flit(3'd4, 3'd2, 3'b001, 7'd6, 48'hBBBB_6666_0002),
				create_flit(3'd4, 3'd2, 3'b010, 7'd6, 48'hBBBB_6666_0003),
				250);
			end
			begin
				$display("\n[CYCLE %0d] [Packet #5] Starting injection: West(02) -> East(42), VC=0", cycle_count);
				send_packet_west(2'd1, 2'd2, 2'd1, 7'd5, 48'hAAAA_5555_0001, 48'hAAAA_5555_0002, 48'hAAAA_5555_0003, 1'b0);  // Changed to 1'b0
				packets_sent = packets_sent + 1;
				$display("[CYCLE %0d] [Packet #5] Injection complete", cycle_count);
			end
			begin
				repeat(10) @(posedge clk);
				$display("\n[CYCLE %0d] [Packet #6] Starting injection: South(20) -> North(24), VC=0", cycle_count);
				send_packet_south(2'd1, 2'd3, 2'd1, 7'd6, 48'hBBBB_6666_0001, 48'hBBBB_6666_0002, 48'hBBBB_6666_0003, 1'b0);  // Changed to 1'b0
				packets_sent = packets_sent + 1;
				$display("[CYCLE %0d] [Packet #6] Injection complete", cycle_count);
			end
		
		
		
		join
		repeat(10) @(posedge clk);
		
		// ====================================================================
		// TEST CASE 6: Intersecting Paths
		// ====================================================================
		$display("\n========================================");
		$display("TEST CASE 6: Intersecting Paths (Same VC)");
		$display("Path 1: West(01) -> East(43) via (1,1)->(2,1)->(3,1)->(3,2)->(3,3)");
		$display("Path 2: South(30) -> North(14) via (3,1)->(2,1)->(1,1)->(1,2)->(1,3)");
		$display("*** Paths intersect at routers (1,1), (2,1), and (3,1) ***");
		$display("========================================");
		
		configure_ports(2'd0, 2'd2, 2'd2, 2'd0);
		clear_all_complete_flags();
		fork
			begin
				#10
				verify_complete_packet(2'd2,
				create_flit(3'd3, 3'd4, 3'b000, 7'd7, 48'hCCCC_7777_0001),
				create_flit(3'd3, 3'd4, 3'b001, 7'd7, 48'hCCCC_7777_0002),
				create_flit(3'd3, 3'd4, 3'b010, 7'd7, 48'hCCCC_7777_0003),
				250);
			end
			begin
				#10
				verify_complete_packet(2'd3,
				create_flit(3'd4, 3'd1, 3'b000, 7'd8, 48'hDDDD_8888_0001),
				create_flit(3'd4, 3'd1, 3'b001, 7'd8, 48'hDDDD_8888_0002),
				create_flit(3'd4, 3'd1, 3'b010, 7'd8, 48'hDDDD_8888_0003),
				250);
			end

			begin
				$display("\n[CYCLE %0d] [Packet #7] Starting injection: West(01) -> East(43), VC=0", cycle_count);
				send_packet_west(2'd0, 2'd2, 2'd2, 7'd7, 48'hCCCC_7777_0001, 48'hCCCC_7777_0002, 48'hCCCC_7777_0003, 1'b0);  // Changed to 1'b0
				packets_sent = packets_sent + 1;
				$display("[CYCLE %0d] [Packet #7] Injection complete", cycle_count);
			end
			begin
				repeat(10) @(posedge clk);
				$display("\n[CYCLE %0d] [Packet #8] Starting injection: South(30) -> North(14), VC=0", cycle_count);
				send_packet_south(2'd2, 2'd3, 2'd0, 7'd8, 48'hDDDD_8888_0001, 48'hDDDD_8888_0002, 48'hDDDD_8888_0003, 1'b0);  // Changed to 1'b0
				packets_sent = packets_sent + 1;
				$display("[CYCLE %0d] [Packet #8] Injection complete", cycle_count);
			end
		join
		
		repeat(10) @(posedge clk);
		
		// ====================================================================
		// TEST CASE 7: TRUE Contention - Same Output Port (same VC)
		// ====================================================================
		$display("\n========================================");
		$display("TEST CASE 7: TRUE Contention - Same Output Port");
		$display("Packet #9:  West(02) -> East(42), VC=0, 5 BODY flits (LONG)");
		$display("Packet #10: South(20) -> East(42), VC=0, 1 BODY flit (NORMAL)");
		$display("*** BOTH packets need to exit EAST from router (2,2) ***");
		$display("========================================");
		
		configure_ports(2'd1, 2'd1, 2'd1, 2'd1);
		
		// Enable debug for this test
		enable_debug_monitor = 1;
		clear_all_complete_flags();
		fork
    
		// Injection threads
		begin
        $display("\n[CYCLE %0d] [Packet #9] Starting injection: West(02) -> East(42), VC=0, EXTENDED", cycle_count);
        send_packet_west_multi_body(2'd1, 2'd2, 2'd1, 7'd9, 48'hAAAA_9999_0001, 48'hAAAA_9999_FFFF, 1'b0, 5);  // Changed to 1'b0
        packets_sent = packets_sent + 1;
        $display("[CYCLE %0d] [Packet #9] Injection complete (LONG)", cycle_count);
		  
		  repeat(50) @(posedge clk);
		  
		  $display("\n[CYCLE %0d] Now verifying packet #10...", cycle_count);
        verify_complete_packet(2'd2,
            create_flit(3'd2, 3'd4, 3'b000, 7'd10, 48'hBBBB_AAAA_0001),
            create_flit(3'd2, 3'd4, 3'b001, 7'd10, 48'hBBBB_AAAA_0002),
            create_flit(3'd2, 3'd4, 3'b010, 7'd10, 48'hBBBB_AAAA_0003),
            500);
        
        packets_received = packets_received + 1;  // Manually count packet #9
        packets_verified = packets_verified + 1;
		end
		begin
        repeat(10) @(posedge clk);
        $display("\n[CYCLE %0d] [Packet #10] Starting injection: South(20) -> East(42), VC=0, NORMAL", cycle_count);
        send_packet_south(2'd1, 2'd2, 2'd1, 7'd10, 48'hBBBB_AAAA_0001, 48'hBBBB_AAAA_0002, 48'hBBBB_AAAA_0003, 1'b0);  // Changed to 1'b0
        packets_sent = packets_sent + 1;
        $display("[CYCLE %0d] [Packet #10] Injection complete (NORMAL)", cycle_count);
		  
		  
		  
		end
		join
		
		enable_debug_monitor = 0;
		repeat(10) @(posedge clk);
		
		// ====================================================================
		// TEST CASE 8: Intersecting Paths
		// ====================================================================
		$display("\n========================================");
		$display("TEST CASE 8: Intersecting Paths (Different VC)");
		$display("Path 1: West(01) -> East(43) via (1,1)->(2,1)->(3,1)->(3,2)->(3,3)");
		$display("Path 2: South(30) -> North(14) via (3,1)->(2,1)->(1,1)->(1,2)->(1,3)");
		$display("*** Paths intersect at routers (1,1), (2,1), and (3,1) ***");
		$display("========================================");
		
		configure_ports(2'd0, 2'd2, 2'd2, 2'd0);
		clear_all_complete_flags();
		fork
			begin
				#10
				verify_complete_packet(2'd2,
				create_flit(3'd3, 3'd4, 3'b000, 7'd7, 48'hCCCC_7777_0001),
				create_flit(3'd3, 3'd4, 3'b001, 7'd7, 48'hCCCC_7777_0002),
				create_flit(3'd3, 3'd4, 3'b010, 7'd7, 48'hCCCC_7777_0003),
				250);
			end
			begin
				#10
				verify_complete_packet(2'd3,
				create_flit(3'd4, 3'd1, 3'b000, 7'd8, 48'hDDDD_8888_0001),
				create_flit(3'd4, 3'd1, 3'b001, 7'd8, 48'hDDDD_8888_0002),
				create_flit(3'd4, 3'd1, 3'b010, 7'd8, 48'hDDDD_8888_0003),
				250);
			end

			begin
				$display("\n[CYCLE %0d] [Packet #7] Starting injection: West(01) -> East(43), VC=0", cycle_count);
				send_packet_west(2'd0, 2'd2, 2'd2, 7'd7, 48'hCCCC_7777_0001, 48'hCCCC_7777_0002, 48'hCCCC_7777_0003, 1'b0);  // Changed to 1'b0
				packets_sent = packets_sent + 1;
				$display("[CYCLE %0d] [Packet #7] Injection complete", cycle_count);
			end
			begin
				repeat(10) @(posedge clk);
				$display("\n[CYCLE %0d] [Packet #8] Starting injection: South(30) -> North(14), VC=0", cycle_count);
				send_packet_south(2'd2, 2'd3, 2'd0, 7'd8, 48'hDDDD_8888_0001, 48'hDDDD_8888_0002, 48'hDDDD_8888_0003, 1'b1);  // Changed to 1'b1
				packets_sent = packets_sent + 1;
				$display("[CYCLE %0d] [Packet #8] Injection complete", cycle_count);
			end
		join
		
		repeat(10) @(posedge clk);
		
		
		// ====================================================================
		// TEST CASE 9: TRUE Contention - Same Output Port (different VC)
		// ====================================================================
		$display("\n========================================");
		$display("TEST CASE 9: TRUE Contention - Same Output Port (Different VC)");
		$display("Packet #9:  West(02) -> East(42), VC=0, 5 BODY flits (LONG)");
		$display("Packet #10: South(20) -> East(42), VC=1, 1 BODY flit (NORMAL)");
		$display("*** BOTH packets need to exit EAST from router (2,2) ***");
		$display("========================================");
		
		configure_ports(2'd1, 2'd1, 2'd1, 2'd1);
		
		// Enable debug for this test
		enable_debug_monitor = 1;
		clear_all_complete_flags();
		fork
    
		// Injection threads
		begin
        $display("\n[CYCLE %0d] [Packet #9] Starting injection: West(02) -> East(42), VC=0, EXTENDED", cycle_count);
        send_packet_west_multi_body(2'd1, 2'd2, 2'd1, 7'd9, 48'hAAAA_9999_0001, 48'hAAAA_9999_FFFF, 1'b0, 5);  // Changed to 1'b0
        packets_sent = packets_sent + 1;
        $display("[CYCLE %0d] [Packet #9] Injection complete (LONG)", cycle_count);
		  
		  repeat(50) @(posedge clk);
		  
		  $display("\n[CYCLE %0d] Now verifying packet #10...", cycle_count);
        verify_complete_packet(2'd2,
            create_flit(3'd2, 3'd4, 3'b000, 7'd10, 48'hBBBB_AAAA_0001),
            create_flit(3'd2, 3'd4, 3'b001, 7'd10, 48'hBBBB_AAAA_0002),
            create_flit(3'd2, 3'd4, 3'b010, 7'd10, 48'hBBBB_AAAA_0003),
            500);
        
        packets_received = packets_received + 1;  // Manually count packet #9
        packets_verified = packets_verified + 1;
		end
		begin
        repeat(10) @(posedge clk);
        $display("\n[CYCLE %0d] [Packet #10] Starting injection: South(20) -> East(42), VC=1, NORMAL", cycle_count);
        send_packet_south(2'd1, 2'd2, 2'd1, 7'd10, 48'hBBBB_AAAA_0001, 48'hBBBB_AAAA_0002, 48'hBBBB_AAAA_0003, 1'b1);  // Changed to 1'b1
        packets_sent = packets_sent + 1;
        $display("[CYCLE %0d] [Packet #10] Injection complete (NORMAL)", cycle_count);
		  
		  
		  
		end
		join
		
		enable_debug_monitor = 0;
		repeat(10) @(posedge clk);
		
		
		
		
		
		
		// ====================================================================
		// Final Results
		// ====================================================================
		repeat(5) @(posedge clk);
		
		$display("\n================================================================================");
		$display("Test Results");
		$display("================================================================================");
		$display("Packets sent:     %0d", packets_sent);
		$display("Packets received: %0d", packets_received);
		$display("Packets verified: %0d", packets_verified);
		$display("Packets failed:   %0d", packets_failed);
		
		if (packets_sent == packets_verified && packets_failed == 0) begin
			$display("\nALL TESTS PASSED");
			$display("All %0d packets successfully routed and verified!", packets_sent);
		end else begin
			$display("\nSOME TESTS FAILED");
			if (packets_received != packets_sent)
				$display("%0d packets lost!", packets_sent - packets_received);
			if (packets_failed > 0)
				$display("%0d packets had content mismatches!", packets_failed);
		end
		
		$display("\n================================================================================");
		$display("Simulation Complete");
		$display("================================================================================\n");
		
		// Clear all input signals
		in_west_valid = 0;
		in_south_valid = 0;
		in_east_valid = 0;
		in_north_valid = 0;
		
		repeat(50) @(posedge clk);
		$finish;
	end
	
	// ========================================================================
	// Cycle Counter
	// ========================================================================
	always @(posedge clk) begin
		if (!rst) cycle_count = cycle_count + 1;
	end
	
	// ========================================================================
	// Timeout Watchdog
	// ========================================================================
	initial begin
		#300000;  // 300us timeout
		$display("\nERROR: Simulation timeout");
		$finish;
	end

endmodule