
// ============================================================================
// Deserializer: 4-bit input → 64-bit output (16 cycles)
// ============================================================================
module Deserializer (
    input wire clk,
    input wire rst,
    
    // 4-bit input interface
    input wire [3:0] data_in,
    input wire valid_in,
    input wire [1:0] vc_in,
    
    // 64-bit output interface (to router)
    output reg [63:0] data_out,
    output reg valid_out,
    output reg [1:0] vc_out
);
    reg [63:0] buffer;
    reg [3:0] count;  // 0-15 counter
    reg [1:0] vc_stored;
    reg receiving;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            buffer <= 64'b0;
            count <= 4'b0;
            data_out <= 64'b0;
            valid_out <= 1'b0;
            vc_out <= 2'b0;
            vc_stored <= 2'b0;
            receiving <= 1'b0;
        end else begin
            valid_out <= 1'b0;  // Default: no output
            
            if (valid_in) begin
                // Store the 4-bit chunk
                buffer[count*4 +: 4] <= data_in;
                
                // Store VC on first cycle
                if (count == 4'b0) begin
                    vc_stored <= vc_in;
                    receiving <= 1'b1;
                end
                
                // Increment counter
                if (count == 4'd15) begin
                    // Complete flit received
                    data_out <= {data_in, buffer[59:0]};  // Include this last chunk
                    valid_out <= 1'b1;
                    vc_out <= vc_stored;
                    count <= 4'b0;
                    receiving <= 1'b0;
                end else begin
                    count <= count + 1'b1;
                end
            end else if (receiving && count != 4'b0) begin
                // Continue counting even without valid (timeout protection)
                count <= count + 1'b1;
            end
        end
    end
endmodule