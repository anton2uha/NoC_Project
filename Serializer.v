// Serializer: 64-bit input → 4-bit output (16 cycles)
module Serializer (
    input wire clk,
    input wire rst,
    
    // 64-bit input interface (from router)
    input wire [63:0] data_in,
    input wire valid_in,
    input wire [1:0] vc_in,
    
    // 4-bit output interface
    output reg [3:0] data_out,
    output reg valid_out,
    output reg [1:0] vc_out
);
    reg [63:0] buffer;
    reg [3:0] count;  // 0-15 counter
    reg [1:0] vc_stored;
    reg transmitting;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            buffer <= 64'b0;
            count <= 4'b0;
            data_out <= 4'b0;
            valid_out <= 1'b0;
            vc_out <= 2'b0;
            vc_stored <= 2'b0;
            transmitting <= 1'b0;
        end else begin
            if (valid_in && !transmitting) begin
                // Load new flit
                buffer <= data_in;
                vc_stored <= vc_in;
                transmitting <= 1'b1;
                count <= 4'd1;  // FIX: Start at 1 since we output chunk 0 now
                
                // Start outputting first chunk immediately
                data_out <= data_in[3:0];
                valid_out <= 1'b1;
                vc_out <= vc_in;
            end else if (transmitting) begin
                // Continue serializing
                data_out <= buffer[count*4 +: 4];
                valid_out <= 1'b1;
                vc_out <= vc_stored;
                
                if (count == 4'd15) begin
                    // Finished transmitting
                    transmitting <= 1'b0;
                    count <= 4'b0;
                end else begin
                    count <= count + 1'b1;
                end
            end else begin
                valid_out <= 1'b0;
            end
        end
    end
endmodule