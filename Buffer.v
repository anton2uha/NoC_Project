

// ============================================================================
// Buffer Module - Stores flits in 2 VCs, each holding 4 flits
// ============================================================================
module Buffer (
	input wire clk,
	input wire rst,
	
	// Data input from upstream router
	input wire [63:0] dataIn,
	input wire dataIn_valid,
	input wire [1:0] dataIn_vc,  // Which VC to write to (from upstream)
	
	// From/To VC Allocator (VCA)
	output wire [1:0] vc_status,  // Status of each VC (available/full)
	input wire [1:0] vc_grant,    // VCA grants this VC for output
	
	// To Route Computation (RC)
	output wire [63:0] rc_flit_out,  // Head flit to RC for route computation
	output wire rc_valid,             // Valid head flit ready
	
	// From/To Crossbar Allocator (CBA)
	input wire cba_grant,          // Crossbar grants permission to send
	output wire cba_request,       // Request crossbar access
	
	// To Crossbar Switch (CBS)
	output wire [63:0] cbs_flit_out,  // Flit to send through crossbar
	output wire [1:0] cbs_vc_out,     // Which VC this flit belongs to
	output wire cbs_valid
);

	// ========================================================================
	// VC Storage: 2 VCs, each with 4 flit slots
	// ========================================================================
	reg [63:0] vc0_buffer [0:3];
	reg [63:0] vc1_buffer [0:3];
	
	reg [2:0] vc0_head, vc0_tail;  // Read/write pointers (0-3, wraps around)
	reg [2:0] vc1_head, vc1_tail;
	
	reg [2:0] vc0_count;  // Number of flits in VC0 (0-4)
	reg [2:0] vc1_count;  // Number of flits in VC1 (0-4)
	
	// ========================================================================
	// VC Status: Each VC is available if not full
	// ========================================================================
	wire vc0_full = (vc0_count == 3'd4);
	wire vc1_full = (vc1_count == 3'd4);
	wire vc0_empty = (vc0_count == 3'd0);
	wire vc1_empty = (vc1_count == 3'd0);
	
	assign vc_status[0] = ~vc0_full;  // VC0 available if not full
	assign vc_status[1] = ~vc1_full;  // VC1 available if not full
	
	// ========================================================================
	// Write Logic: Store incoming flits into specified VC
	// ========================================================================
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			vc0_head <= 0;
			vc0_tail <= 0;
			vc0_count <= 0;
			vc1_head <= 0;
			vc1_tail <= 0;
			vc1_count <= 0;
		end else begin
			// Write to VC0
			if (dataIn_valid && dataIn_vc == 2'b00 && !vc0_full) begin
				vc0_buffer[vc0_tail] <= dataIn;
				vc0_tail <= (vc0_tail + 1) % 4;
				vc0_count <= vc0_count + 1;
			end
			
			// Write to VC1
			if (dataIn_valid && dataIn_vc == 2'b01 && !vc1_full) begin
				vc1_buffer[vc1_tail] <= dataIn;
				vc1_tail <= (vc1_tail + 1) % 4;
				vc1_count <= vc1_count + 1;
			end
			
			// Read from VC0 (when granted by crossbar)
			if (cba_grant && cbs_vc_out == 2'b00 && !vc0_empty) begin
				vc0_head <= (vc0_head + 1) % 4;
				vc0_count <= vc0_count - 1;
			end
			
			// Read from VC1 (when granted by crossbar)
			if (cba_grant && cbs_vc_out == 2'b01 && !vc1_empty) begin
				vc1_head <= (vc1_head + 1) % 4;
				vc1_count <= vc1_count - 1;
			end
		end
	end
	
	// ========================================================================
	// Route Computation Output: Send head flit from whichever VC has one
	// ========================================================================
	wire [2:0] vc0_flit_type = vc0_buffer[vc0_head][47:45];
	wire [2:0] vc1_flit_type = vc1_buffer[vc1_head][47:45];
	
	wire vc0_has_head = !vc0_empty && (vc0_flit_type == 3'b000);
	wire vc1_has_head = !vc1_empty && (vc1_flit_type == 3'b000);
	
	assign rc_flit_out = vc0_has_head ? vc0_buffer[vc0_head] : 
	                     vc1_has_head ? vc1_buffer[vc1_head] : 64'b0;
	assign rc_valid = vc0_has_head || vc1_has_head;
	
	// ========================================================================
	// Crossbar Output: Send flit from granted VC
	// Priority: VC0 first, then VC1
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
	
	// Request crossbar if any VC has data and has been granted by VCA
	assign cba_request = (!vc0_empty && vc_grant[0]) || (!vc1_empty && vc_grant[1]);

endmodule

