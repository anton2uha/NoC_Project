// ============================================================================
// NoC Testbench - Edge-to-Edge Packet Testing (03 -> 43) - 4-bit Serialized
// Tests packet routing from west edge to east edge through the mesh
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
	
	// 4-bit edge inputs
	reg [3:0] in_west, in_south, in_east, in_north;
	
	// Select signals (which of 3 ports per side)
	reg [1:0] west_sel, south_sel, east_sel, north_sel;
	
	// Valid and VC signals per side
	reg in_west_valid, in_south_valid, in_east_valid, in_north_valid;
	reg [1:0] in_west_vc, in_south_vc, in_east_vc, in_north_vc;
	
	// 4-bit edge outputs
	wire [3:0] out_west, out_south, out_east, out_north;
	wire out_west_valid, out_south_valid, out_east_valid, out_north_valid;
	wire [1:0] out_west_vc, out_south_vc, out_east_vc, out_north_vc;
	
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
	reg [63:0] expected_head, expected_body, expected_tail;
	reg head_received, body_received, tail_received;
	
	// Output reconstruction
	reg [63:0] output_buffer;
	reg [3:0] output_chunk_count;
	reg reconstructing;
	reg [63:0] completed_flit;
	reg flit_complete;
	
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
		input [8*20:1] label;
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
	// Helper Task: Serialize and inject 64-bit flit
	// ========================================================================
	task inject_flit;
		input [63:0] flit;
		input [1:0] vc;
		integer i;
		begin
			for (i = 0; i < 16; i = i + 1) begin
				@(posedge clk);
				in_west = flit[i*4 +: 4];
				in_west_valid = 1'b1;
				in_west_vc = vc;
			end
			@(posedge clk);
			in_west_valid = 1'b0;
		end
	endtask
	
	// ========================================================================
	// Output Deserializer: Reconstruct 64-bit flits from 4-bit output
	// ========================================================================
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			output_buffer <= 64'b0;
			output_chunk_count <= 4'b0;
			reconstructing <= 1'b0;
			completed_flit <= 64'b0;
			flit_complete <= 1'b0;
		end else begin
			flit_complete <= 1'b0;  // Default: no complete flit this cycle
			
			if (out_east_valid) begin
				// Accumulate 4-bit chunks
				output_buffer[output_chunk_count*4 +: 4] <= out_east;
				
				if (output_chunk_count == 4'd0) begin
					reconstructing <= 1'b1;
				end
				
				if (output_chunk_count == 4'd15) begin
					// Complete 64-bit flit reconstructed - combine all stored bits with final chunk
					// out_east has the MSBs (bits 63:60), output_buffer has bits 59:0
					completed_flit <= {out_east, output_buffer[59:0]};
					flit_complete <= 1'b1;
					reconstructing <= 1'b0;
					output_chunk_count <= 4'b0;
				end else begin
					output_chunk_count <= output_chunk_count + 1'b1;
				end
			end
		end
	end
	
	// Check received flits on the cycle after they're complete
	always @(posedge clk) begin
		if (!rst && flit_complete) begin
			if (!head_received && completed_flit == expected_head) begin
				head_received <= 1;
				$display("\n[CYCLE %0d] ✓ HEAD FLIT RECEIVED CORRECTLY at out43", cycle_count);
				display_flit(completed_flit, "  HEAD");
			end else if (head_received && !body_received && completed_flit == expected_body) begin
				body_received <= 1;
				$display("\n[CYCLE %0d] ✓ BODY FLIT RECEIVED CORRECTLY at out43", cycle_count);
				display_flit(completed_flit, "  BODY");
			end else if (body_received && !tail_received && completed_flit == expected_tail) begin
				tail_received <= 1;
				$display("\n[CYCLE %0d] ✓ TAIL FLIT RECEIVED CORRECTLY at out43", cycle_count);
				display_flit(completed_flit, "  TAIL");
				$display("\n========================================");
				$display("SUCCESS! Complete packet received!");
				$display("========================================\n");
			end
		end
	end
	
	// ========================================================================
	// Monitor: Track packet through intermediate routers (internal 64-bit)
	// ========================================================================
	always @(posedge clk) begin
		if (!rst) begin
			// Monitor Deserializer output (when 64-bit flit is complete)
			if (dut.deser_out03_valid) begin
				$display("[CYCLE %0d] Deserializer d03 completed 64-bit flit:", cycle_count);
				display_flit(dut.deser_out03, "  Flit");
			end
			
			// Monitor Router 13 (entry point)
			if (dut.r13.westIn_valid) begin
				$display("[CYCLE %0d] Router(1,3) received on WEST input:", cycle_count);
				display_flit(dut.r13.westIn, "  Flit");
			end
			
			// Monitor Router 13 -> 23 link
			if (dut.w_13to23_valid) begin
				$display("[CYCLE %0d] Link r13->r23 (EAST):", cycle_count);
				display_flit(dut.w_13to23, "  Flit");
			end
			
			// Monitor Router 23 (middle hop)
			if (dut.r23.westIn_valid) begin
				$display("[CYCLE %0d] Router(2,3) received on WEST input:", cycle_count);
				display_flit(dut.r23.westIn, "  Flit");
			end
			
			// Monitor Router 23 -> 33 link
			if (dut.w_23to33_valid) begin
				$display("[CYCLE %0d] Link r23->r33 (EAST):", cycle_count);
				display_flit(dut.w_23to33, "  Flit");
			end
			
			// Monitor Router 33 (exit point)
			if (dut.r33.westIn_valid) begin
				$display("[CYCLE %0d] Router(3,3) received on WEST input:", cycle_count);
				display_flit(dut.r33.westIn, "  Flit");
			end
			
			// Monitor Serializer input (when router outputs 64-bit flit)
			if (dut.ser_in43_valid) begin
				$display("[CYCLE %0d] Serializer s43 received 64-bit flit from router:", cycle_count);
				display_flit(dut.ser_in43, "  Flit");
			end
			
			// Monitor serialized output start
			if (out_east_valid && output_chunk_count == 4'd0) begin
				$display("[CYCLE %0d] *** OUTPUT at out43 (starting serialization) ***", cycle_count);
			end
			
			// Monitor when a complete flit is reconstructed from output
			if (flit_complete) begin
				$display("[CYCLE %0d] *** COMPLETE 64-bit flit reconstructed from out43 ***", cycle_count);
				display_flit(completed_flit, "  Reconstructed");
			end
		end
	end
	
	// ========================================================================
	// Main Test Sequence
	// ========================================================================
	initial begin
		// Initialize VCD dump for waveform viewing
		$dumpfile("noc_test_serialized.vcd");
		$dumpvars(0, NoC_tb);
		
		$display("\n================================================================================");
		$display("NoC Edge-to-Edge Test: 03 -> 43 (4-bit Serialized Interface)");
		$display("Test: Send 3-flit packet from west edge of router(1,3) to east edge of router(3,3)");
		$display("Expected path: in03 -> r13 -> r23 -> r33 -> out43");
		$display("Note: Each 64-bit flit is sent/received as 16 cycles of 4-bit chunks");
		$display("================================================================================\n");
		
		// ====================================================================
		// Phase 1: Reset and Initialization
		// ====================================================================
		$display("[PHASE 1] Reset and Initialization");
		$display("------------------------------------");
		
		cycle_count = 0;
		rst = 1;
		head_received = 0;
		body_received = 0;
		tail_received = 0;
		output_buffer = 64'b0;
		output_chunk_count = 4'b0;
		reconstructing = 1'b0;
		completed_flit = 64'b0;
		flit_complete = 1'b0;
		
		// Initialize all inputs to zero
		in_west = 4'b0;
		in_south = 4'b0;
		in_east = 4'b0;
		in_north = 4'b0;
		
		// Set select signals
		// west_sel = 2'b10 selects port 03 (third port on west side)
		// east_sel = 2'b10 selects port 43 (third port on east side)
		west_sel = 2'b10;   // Select port 03
		south_sel = 2'b00;  // Don't care (not used)
		east_sel = 2'b10;   // Select port 43
		north_sel = 2'b00;  // Don't care (not used)
		
		in_west_valid = 0;
		in_south_valid = 0;
		in_east_valid = 0;
		in_north_valid = 0;
		
		in_west_vc = 2'b00;
		in_south_vc = 2'b00;
		in_east_vc = 2'b00;
		in_north_vc = 2'b00;
		
		$display("All inputs initialized to 0");
		$display("Select signals configured: west_sel=2'b10 (port 03), east_sel=2'b10 (port 43)");
		
		// Hold reset for 5 cycles
		repeat(5) @(posedge clk);
		rst = 0;
		$display("Reset released at cycle %0d\n", cycle_count);
		
		// Wait a few cycles for initialization
		repeat(3) @(posedge clk);
		
		// ====================================================================
		// Phase 2: Create Packet
		// ====================================================================
		$display("\n[PHASE 2] Packet Creation");
		$display("------------------------------------");
		
		// Create 3-flit packet destined for (3,4) - beyond the mesh
		// This forces router(3,3) to forward east to out43
		expected_head = create_flit(3'd3, 3'd4, 3'b000, 7'd42, 48'hDEADBEEF0001);
		expected_body = create_flit(3'd3, 3'd4, 3'b001, 7'd42, 48'hCAFEBABE0002);
		expected_tail = create_flit(3'd3, 3'd4, 3'b010, 7'd42, 48'h123456789ABC);
		
		$display("Packet created with ID=42, destination (3,4):");
		display_flit(expected_head, "HEAD flit");
		display_flit(expected_body, "BODY flit");
		display_flit(expected_tail, "TAIL flit");
		$display("Each flit will be serialized into 16 cycles of 4-bit chunks");
		
		// ====================================================================
		// Phase 3: Inject HEAD Flit (16 cycles of 4-bit chunks)
		// ====================================================================
		$display("\n[PHASE 3] Injecting HEAD Flit at in03 (via in_west with west_sel=2'b10)");
		$display("------------------------------------");
		$display("[CYCLE %0d] Starting HEAD flit serialization (16 cycles)...", cycle_count);
		
		inject_flit(expected_head, 2'b00);
		$display("[CYCLE %0d] HEAD flit injection complete", cycle_count);
		
		// Wait for deserializer to accumulate
		repeat(2) @(posedge clk);
		
		// ====================================================================
		// Phase 4: Inject BODY Flit (16 cycles of 4-bit chunks)
		// ====================================================================
		$display("\n[PHASE 4] Injecting BODY Flit at in03");
		$display("------------------------------------");
		$display("[CYCLE %0d] Starting BODY flit serialization (16 cycles)...", cycle_count);
		
		inject_flit(expected_body, 2'b00);
		$display("[CYCLE %0d] BODY flit injection complete", cycle_count);
		
		// Wait for deserializer to accumulate
		repeat(2) @(posedge clk);
		
		// ====================================================================
		// Phase 5: Inject TAIL Flit (16 cycles of 4-bit chunks)
		// ====================================================================
		$display("\n[PHASE 5] Injecting TAIL Flit at in03");
		$display("------------------------------------");
		$display("[CYCLE %0d] Starting TAIL flit serialization (16 cycles)...", cycle_count);
		
		inject_flit(expected_tail, 2'b00);
		$display("[CYCLE %0d] TAIL flit injection complete", cycle_count);
		
		// ====================================================================
		// Phase 6: Wait for Packet to Traverse Network
		// ====================================================================
		$display("\n[PHASE 6] Waiting for packet to traverse network...");
		$display("------------------------------------");
		
		// Wait up to 500 cycles for packet to arrive (extra time to be certain)
		begin : wait_loop
			integer i;
			for (i = 0; i < 500; i = i + 1) begin
				@(posedge clk);
				if (tail_received) begin
					$display("\nPacket fully received after %0d cycles", cycle_count);
					disable wait_loop;
				end
			end
		end
		
		// ====================================================================
		// Phase 7: Results
		// ====================================================================
		$display("\n[PHASE 7] Test Results");
		$display("------------------------------------");
		
		if (tail_received) begin
			$display("TEST PASSED");
			$display("All flits received correctly at out43");
		end else begin
			$display("TEST FAILED");
			$display("Packet did not arrive within 500 cycles");
			$display("Head received: %0d", head_received);
			$display("Body received: %0d", body_received);
			$display("Tail received: %0d", tail_received);
			
			// Debug information
			$display("\n=== DEBUG INFORMATION ===");
			$display("Deserializer d03:");
			$display("  valid_out: %b", dut.d03.valid_out);
			$display("  data_out: 0x%016h", dut.d03.data_out);
			
			$display("\nRouter 13 state:");
			$display("  westIn_valid: %b", dut.r13.westIn_valid);
			$display("  westIn: 0x%016h", dut.r13.westIn);
			$display("  eastOut: 0x%016h", dut.r13.eastOut);
			
			$display("\nRouter 23 state:");
			$display("  westIn_valid: %b", dut.r23.westIn_valid);
			$display("  eastOut: 0x%016h", dut.r23.eastOut);
			
			$display("\nRouter 33 state:");
			$display("  westIn_valid: %b", dut.r33.westIn_valid);
			$display("  eastOut: 0x%016h", dut.r33.eastOut);
			
			$display("\nSerializer s43:");
			$display("  valid_in: %b", dut.s43.valid_in);
			$display("  data_in: 0x%016h", dut.s43.data_in);
			$display("  transmitting: %b", dut.s43.transmitting);
		end
		
		// ====================================================================
		// Finish Simulation
		// ====================================================================
		$display("\n================================================================================");
		$display("Simulation Complete");
		$display("================================================================================\n");
		
		#100;
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
		#100000;  // 100us timeout (longer for serialization overhead)
		$display("\nERROR: Simulation timeout after 100us");
		$display("Packet may be stuck in the network");
		$finish;
	end

endmodule