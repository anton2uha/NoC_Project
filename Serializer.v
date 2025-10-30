module Serializer (
    input wire clk,
    input wire rst,
    input wire [63:0] data_in,
    input wire valid_in,
    input wire [1:0] vc_in,
    output reg [3:0] data_out,
    output reg valid_out,
    output reg [1:0] vc_out
);
    reg [63:0] buffer;
    reg [3:0] count;
    reg [1:0] vc_stored;
    reg transmitting;
    
    // 2-deep FIFO
    reg [63:0] fifo [0:1];
    reg [1:0] fifo_vc [0:1];
    reg [1:0] fifo_count;
    
    wire will_enqueue = valid_in && (fifo_count < 2'd2);
    wire will_dequeue = (fifo_count > 0) && !transmitting;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            buffer <= 64'b0;
            count <= 4'b0;
            data_out <= 4'b0;
            valid_out <= 1'b0;
            vc_out <= 2'b0;
            vc_stored <= 2'b0;
            transmitting <= 1'b0;
            fifo_count <= 2'b0;
        end else begin
            // Handle enqueue (only if not simultaneously dequeuing with count==1)
            if (will_enqueue && !(will_dequeue && fifo_count == 2'd1)) begin
                fifo[fifo_count] <= data_in;
                fifo_vc[fifo_count] <= vc_in;
                $display("[SERIALIZER @ %m] Cycle %0d: BUFFERED flit=0x%h, vc=%0d", 
                         $time/10, data_in, vc_in);
            end
            
            // Handle dequeue and start transmitting
            if (will_dequeue) begin
                buffer <= fifo[0];
                vc_stored <= fifo_vc[0];
                transmitting <= 1'b1;
                count <= 4'd1;
                
                data_out <= fifo[0][3:0];
                valid_out <= 1'b1;
                vc_out <= fifo_vc[0];
                
                // Handle FIFO shift logic
                if (will_enqueue && fifo_count == 2'd1) begin
                    // Special case: simultaneous enqueue+dequeue with 1 item
                    // New data should go directly to fifo[0]
                    fifo[0] <= data_in;
                    fifo_vc[0] <= vc_in;
                    $display("[SERIALIZER @ %m] Cycle %0d: BUFFERED flit=0x%h, vc=%0d", 
                             $time/10, data_in, vc_in);
                end else begin
                    // Normal case: shift fifo[1] to fifo[0]
                    fifo[0] <= fifo[1];
                    fifo_vc[0] <= fifo_vc[1];
                end
                
                $display("[SERIALIZER @ %m] Cycle %0d: LOADING flit=0x%h, vc=%0d", 
                         $time/10, fifo[0], fifo_vc[0]);
            end else if (transmitting) begin
                // Continue transmitting
                data_out <= buffer[count*4 +: 4];
                valid_out <= 1'b1;
                vc_out <= vc_stored;
                
                if (count == 4'd15) begin
                    transmitting <= 1'b0;
                    count <= 4'b0;
                end else begin
                    count <= count + 1'b1;
                end
                
                $display("[SERIALIZER @ %m] Cycle %0d: TRANSMITTING chunk[%0d]=0x%h", 
                         $time/10, (count == 4'd1) ? 0 : count-1, data_out);
            end else begin
                valid_out <= 1'b0;
            end
            
            // Update fifo_count based on both operations
            if (will_enqueue && will_dequeue) begin
                // Both happen: count stays same
                fifo_count <= fifo_count;
            end else if (will_enqueue) begin
                // Only enqueue
                fifo_count <= fifo_count + 1'b1;
            end else if (will_dequeue) begin
                // Only dequeue
                fifo_count <= fifo_count - 1'b1;
            end
        end
    end
endmodule