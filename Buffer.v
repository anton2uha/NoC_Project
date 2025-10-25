
// ============================================================================
// Buffer Module
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
	// Round-Robin Selection for Fair VC Access
	// ========================================================================
	reg last_vc_served;  // 0 = VC0 was last, 1 = VC1 was last
	
	// ========================================================================
	// FIXED: Simultaneous Read/Write without Race Conditions
	// ========================================================================
	wire vc0_enqueue = dataIn_valid && (dataIn_vc == 2'b00) && !vc0_full;
	wire vc1_enqueue = dataIn_valid && (dataIn_vc == 2'b01) && !vc1_full;
	wire vc0_dequeue = cba_grant && (cbs_vc_out == 2'b00) && !vc0_empty;
	wire vc1_dequeue = cba_grant && (cbs_vc_out == 2'b01) && !vc1_empty;
	
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			vc0_head <= 3'd0;
			vc0_tail <= 3'd0;
			vc0_count <= 3'd0;
			vc1_head <= 3'd0;
			vc1_tail <= 3'd0;
			vc1_count <= 3'd0;
			last_vc_served <= 1'b0;
		end else begin
			// ====================================================================
			// VC0 Buffer Management with Race Condition Fix
			// ====================================================================
			case ({vc0_enqueue, vc0_dequeue})
				2'b00: begin
					// No operation
					vc0_count <= vc0_count;
				end
				2'b01: begin
					// Dequeue only
					vc0_head <= (vc0_head == 3'd3) ? 3'd0 : vc0_head + 3'd1;
					vc0_count <= vc0_count - 3'd1;
				end
				2'b10: begin
					// Enqueue only
					vc0_buffer[vc0_tail] <= dataIn;
					vc0_tail <= (vc0_tail == 3'd3) ? 3'd0 : vc0_tail + 3'd1;
					vc0_count <= vc0_count + 3'd1;
				end
				2'b11: begin
					// Both enqueue and dequeue - count stays same
					vc0_buffer[vc0_tail] <= dataIn;
					vc0_tail <= (vc0_tail == 3'd3) ? 3'd0 : vc0_tail + 3'd1;
					vc0_head <= (vc0_head == 3'd3) ? 3'd0 : vc0_head + 3'd1;
					vc0_count <= vc0_count;  // No change
				end
			endcase
			
			// ====================================================================
			// VC1 Buffer Management with Race Condition Fix
			// ====================================================================
			case ({vc1_enqueue, vc1_dequeue})
				2'b00: begin
					// No operation
					vc1_count <= vc1_count;
				end
				2'b01: begin
					// Dequeue only
					vc1_head <= (vc1_head == 3'd3) ? 3'd0 : vc1_head + 3'd1;
					vc1_count <= vc1_count - 3'd1;
				end
				2'b10: begin
					// Enqueue only
					vc1_buffer[vc1_tail] <= dataIn;
					vc1_tail <= (vc1_tail == 3'd3) ? 3'd0 : vc1_tail + 3'd1;
					vc1_count <= vc1_count + 3'd1;
				end
				2'b11: begin
					// Both enqueue and dequeue - count stays same
					vc1_buffer[vc1_tail] <= dataIn;
					vc1_tail <= (vc1_tail == 3'd3) ? 3'd0 : vc1_tail + 3'd1;
					vc1_head <= (vc1_head == 3'd3) ? 3'd0 : vc1_head + 3'd1;
					vc1_count <= vc1_count;  // No change
				end
			endcase
			
			// ====================================================================
			// Update Round-Robin State
			// ====================================================================
			if (cba_grant) begin
				last_vc_served <= cbs_vc_out[0];  // Remember which VC was served
			end
		end
	end
	
	// ========================================================================
	// Route Computation Interface - Fair VC Selection with Round-Robin
	// ========================================================================
	// FIXED: Fair selection using round-robin
	// Priority depends on which VC was served last
	wire select_vc0 = !vc0_empty && (vc1_empty || (last_vc_served == 1'b1));
	wire select_vc1 = !vc1_empty && (vc0_empty || (last_vc_served == 1'b0));
	
	assign rc_flit_out = select_vc0 ? vc0_buffer[vc0_head] : 
	                     select_vc1 ? vc1_buffer[vc1_head] : 64'b0;
	assign rc_valid = !vc0_empty || !vc1_empty;
	
	// ========================================================================
	// Crossbar Switch Interface
	// ========================================================================
	reg [1:0] active_vc;
	
	always @(*) begin
		if (!vc0_empty && vc_grant[0])
			active_vc = 2'b00;
		else if (!vc1_empty && vc_grant[1])
			active_vc = 2'b01;
		else
			active_vc = 2'b00;
	end
	
	assign cbs_flit_out = (active_vc == 2'b00) ? vc0_buffer[vc0_head] : vc1_buffer[vc1_head];
	assign cbs_vc_out = active_vc;
	assign cbs_valid = (active_vc == 2'b00 && !vc0_empty) || (active_vc == 2'b01 && !vc1_empty);
	
	assign cba_request = (!vc0_empty && vc_grant[0]) || (!vc1_empty && vc_grant[1]);

endmodule


