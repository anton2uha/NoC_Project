// ============================================================================
// Buffer Module - With Debug Statements
// ============================================================================
module Buffer (
	input wire clk,
	input wire rst,
	
	input wire [63:0] dataIn,
	input wire dataIn_valid,
	input wire [1:0] dataIn_vc,
	
	output wire [1:0] vc_status,
	input wire [1:0] vc_grant,
	
	output wire [63:0] rc_flit_out,
	output wire rc_valid,
	output wire [1:0] rc_vc_out,
	
	input wire cba_grant,
	output wire cba_request,
	
	output wire [63:0] cbs_flit_out,
	output wire [1:0] cbs_vc_out,
	output wire cbs_valid
);
	// ========================================================================
	// Buffer Storage
	// ========================================================================
	reg [63:0] vc0_buffer [0:3];
	reg [63:0] vc1_buffer [0:3];
	
	reg [2:0] vc0_head, vc0_tail;
	reg [2:0] vc1_head, vc1_tail;
	
	reg [2:0] vc0_count;
	reg [2:0] vc1_count;
	
	wire vc0_full = (vc0_count == 3'd4);
	wire vc1_full = (vc1_count == 3'd4);
	wire vc0_empty = (vc0_count == 3'd0);
	wire vc1_empty = (vc1_count == 3'd0);
	
	assign vc_status[0] = ~vc0_full;
	assign vc_status[1] = ~vc1_full;
	
	// ========================================================================
	// Round-Robin Selection
	// ========================================================================
	reg last_vc_served;
	
	// ========================================================================
	// VC Grant Latching
	// ========================================================================
	reg vc0_granted;
	reg vc1_granted;
	
	// ========================================================================
	// Dequeue happens IMMEDIATELY when CBA grants
	// ========================================================================
	wire vc0_dequeue = cba_grant && vc0_granted && !vc0_empty;
	wire vc1_dequeue = cba_grant && vc1_granted && !vc1_empty;
	
	wire vc0_enqueue = dataIn_valid && (dataIn_vc == 2'b00) && !vc0_full;
	wire vc1_enqueue = dataIn_valid && (dataIn_vc == 2'b01) && !vc1_full;
	
	// ========================================================================
	// Sample flit type being dequeued THIS cycle (for debugging)
	// ========================================================================
	reg [2:0] vc0_last_dequeued_type;
	reg [2:0] vc1_last_dequeued_type;
	reg vc0_dequeued_last_cycle;
	reg vc1_dequeued_last_cycle;
	
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			vc0_head <= 3'd0;
			vc0_tail <= 3'd0;
			vc0_count <= 3'd0;
			vc1_head <= 3'd0;
			vc1_tail <= 3'd0;
			vc1_count <= 3'd0;
			last_vc_served <= 1'b0;
			vc0_granted <= 1'b0;
			vc1_granted <= 1'b0;
			vc0_dequeued_last_cycle <= 1'b0;
			vc1_dequeued_last_cycle <= 1'b0;
			vc0_last_dequeued_type <= 3'b000;
			vc1_last_dequeued_type <= 3'b000;
		end else begin
			// ================================================================
			// Sample dequeue info THIS cycle for debugging
			// ================================================================
			vc0_dequeued_last_cycle <= vc0_dequeue;
			vc1_dequeued_last_cycle <= vc1_dequeue;
			
			if (vc0_dequeue) begin
				vc0_last_dequeued_type <= vc0_buffer[vc0_head][57:55];
			end
			if (vc1_dequeue) begin
				vc1_last_dequeued_type <= vc1_buffer[vc1_head][57:55];
			end
			
			// ================================================================
			// VC Grant Management - FIXED: Independent clear and set
			// ================================================================
			// Clear grant SAME cycle as tail dequeue
			if (vc0_dequeue && vc0_buffer[vc0_head][57:55] == 3'b010) begin
				vc0_granted <= 1'b0;
			end
			
			// Set grant when VA grants (can override clear in same cycle)
			if (vc_grant[0]) begin
				vc0_granted <= 1'b1;
			end
			
			// Same for VC1
			if (vc1_dequeue && vc1_buffer[vc1_head][57:55] == 3'b010) begin
				vc1_granted <= 1'b0;
			end
			
			if (vc_grant[1]) begin
				vc1_granted <= 1'b1;
			end
			
			// ================================================================
			// VC0 Buffer Management - Dequeue happens IMMEDIATELY
			// ================================================================
			case ({vc0_enqueue, vc0_dequeue})
				2'b00: vc0_count <= vc0_count;
				2'b01: begin
					vc0_head <= (vc0_head == 3'd3) ? 3'd0 : vc0_head + 3'd1;
					vc0_count <= vc0_count - 3'd1;
				end
				2'b10: begin
					vc0_buffer[vc0_tail] <= dataIn;
					vc0_tail <= (vc0_tail == 3'd3) ? 3'd0 : vc0_tail + 3'd1;
					vc0_count <= vc0_count + 3'd1;
				end
				2'b11: begin
					vc0_buffer[vc0_tail] <= dataIn;
					vc0_tail <= (vc0_tail == 3'd3) ? 3'd0 : vc0_tail + 3'd1;
					vc0_head <= (vc0_head == 3'd3) ? 3'd0 : vc0_head + 3'd1;
					vc0_count <= vc0_count;
				end
			endcase
			
			// ================================================================
			// VC1 Buffer Management
			// ================================================================
			case ({vc1_enqueue, vc1_dequeue})
				2'b00: vc1_count <= vc1_count;
				2'b01: begin
					vc1_head <= (vc1_head == 3'd3) ? 3'd0 : vc1_head + 3'd1;
					vc1_count <= vc1_count - 3'd1;
				end
				2'b10: begin
					vc1_buffer[vc1_tail] <= dataIn;
					vc1_tail <= (vc1_tail == 3'd3) ? 3'd0 : vc1_tail + 3'd1;
					vc1_count <= vc1_count + 3'd1;
				end
				2'b11: begin
					vc1_buffer[vc1_tail] <= dataIn;
					vc1_tail <= (vc1_tail == 3'd3) ? 3'd0 : vc1_tail + 3'd1;
					vc1_head <= (vc1_head == 3'd3) ? 3'd0 : vc1_head + 3'd1;
					vc1_count <= vc1_count;
				end
			endcase
			
			// ================================================================
			// Update Round-Robin State
			// ================================================================
			if (cba_grant) begin
				last_vc_served <= cbs_vc_out[0];
			end
		end
	end
	
	// ========================================================================
	// Debug Statements
	// ========================================================================
	always @(posedge clk) begin
		if (!rst) begin
			// Debug VC0 enqueue
			if (vc0_enqueue) begin
				$display("[BUFFER DEBUG @ %m] Cycle %0d: VC0 ENQUEUE flit_type=%s, pkt_id=%0d, count_will_be=%0d", 
				         $time/10, 
				         dataIn[57:55] == 3'b000 ? "HEAD" : dataIn[57:55] == 3'b001 ? "BODY" : "TAIL",
				         dataIn[54:48],
				         vc0_count + (vc0_dequeue ? 0 : 1));
			end
			
			// Debug VC0 dequeue
			if (vc0_dequeue) begin
				$display("[BUFFER DEBUG @ %m] Cycle %0d: VC0 DEQUEUE flit_type=%s, pkt_id=%0d, count_will_be=%0d", 
				         $time/10,
				         vc0_buffer[vc0_head][57:55] == 3'b000 ? "HEAD" : vc0_buffer[vc0_head][57:55] == 3'b001 ? "BODY" : "TAIL",
				         vc0_buffer[vc0_head][54:48],
				         vc0_count - (vc0_enqueue ? 0 : 1));
			end
			
			// Debug VC0 grant status
			if (vc0_granted && !vc0_empty) begin
				$display("[BUFFER DEBUG @ %m] Cycle %0d: VC0 GRANTED=%b, head_flit_type=%s, pkt_id=%0d, cba_request=%b, cba_grant=%b", 
				         $time/10, vc0_granted,
				         vc0_buffer[vc0_head][57:55] == 3'b000 ? "HEAD" : vc0_buffer[vc0_head][57:55] == 3'b001 ? "BODY" : "TAIL",
				         vc0_buffer[vc0_head][54:48],
				         cba_request, cba_grant);
			end
			
			// Debug VC0 grant changes
			if (vc_grant[0]) begin
				$display("[BUFFER DEBUG @ %m] Cycle %0d: VC0 VA_GRANT asserted, vc0_granted will be 1", $time/10);
			end
			if (vc0_dequeue && vc0_buffer[vc0_head][57:55] == 3'b010) begin
				$display("[BUFFER DEBUG @ %m] Cycle %0d: VC0 GRANT CLEARING (TAIL dequeued)", $time/10);
			end
			
			// Debug VC1 enqueue
			if (vc1_enqueue) begin
				$display("[BUFFER DEBUG @ %m] Cycle %0d: VC1 ENQUEUE flit_type=%s, pkt_id=%0d, count_will_be=%0d", 
				         $time/10, 
				         dataIn[57:55] == 3'b000 ? "HEAD" : dataIn[57:55] == 3'b001 ? "BODY" : "TAIL",
				         dataIn[54:48],
				         vc1_count + (vc1_dequeue ? 0 : 1));
			end
			
			// Debug VC1 dequeue
			if (vc1_dequeue) begin
				$display("[BUFFER DEBUG @ %m] Cycle %0d: VC1 DEQUEUE flit_type=%s, pkt_id=%0d, count_will_be=%0d", 
				         $time/10,
				         vc1_buffer[vc1_head][57:55] == 3'b000 ? "HEAD" : vc1_buffer[vc1_head][57:55] == 3'b001 ? "BODY" : "TAIL",
				         vc1_buffer[vc1_head][54:48],
				         vc1_count - (vc1_enqueue ? 0 : 1));
			end
			
			// Debug VC1 grant status
			if (vc1_granted && !vc1_empty) begin
				$display("[BUFFER DEBUG @ %m] Cycle %0d: VC1 GRANTED=%b, head_flit_type=%s, pkt_id=%0d, cba_request=%b, cba_grant=%b", 
				         $time/10, vc1_granted,
				         vc1_buffer[vc1_head][57:55] == 3'b000 ? "HEAD" : vc1_buffer[vc1_head][57:55] == 3'b001 ? "BODY" : "TAIL",
				         vc1_buffer[vc1_head][54:48],
				         cba_request, cba_grant);
			end
			
			// Debug VC1 grant changes
			if (vc_grant[1]) begin
				$display("[BUFFER DEBUG @ %m] Cycle %0d: VC1 VA_GRANT asserted, vc1_granted will be 1", $time/10);
			end
			if (vc1_dequeue && vc1_buffer[vc1_head][57:55] == 3'b010) begin
				$display("[BUFFER DEBUG @ %m] Cycle %0d: VC1 GRANT CLEARING (TAIL dequeued)", $time/10);
			end
		end
	end
	
	// ========================================================================
	// Route Computation Interface
	// ========================================================================
	wire select_vc0_rc = !vc0_empty && (vc1_empty || (last_vc_served == 1'b1));
	wire select_vc1_rc = !vc1_empty && (vc0_empty || (last_vc_served == 1'b0));
	
	assign rc_flit_out = select_vc0_rc ? vc0_buffer[vc0_head] : 
	                     select_vc1_rc ? vc1_buffer[vc1_head] : 64'b0;
	assign rc_valid = !vc0_empty || !vc1_empty;
	assign rc_vc_out = select_vc0_rc ? 2'b00 : 
	                   select_vc1_rc ? 2'b01 : 2'b00;
	
	// ========================================================================
	// Crossbar Switch Interface
	// ========================================================================
	assign cbs_flit_out = (vc0_granted && !vc0_empty) ? vc0_buffer[vc0_head] : 
	                      (vc1_granted && !vc1_empty) ? vc1_buffer[vc1_head] : 64'b0;
	
	assign cbs_vc_out = (vc0_granted && !vc0_empty) ? 2'b00 : 
	                    (vc1_granted && !vc1_empty) ? 2'b01 : 2'b00;
	
	assign cbs_valid = (vc0_granted && !vc0_empty) || (vc1_granted && !vc1_empty);
	
	assign cba_request = (vc0_granted && !vc0_empty) || (vc1_granted && !vc1_empty);

endmodule


