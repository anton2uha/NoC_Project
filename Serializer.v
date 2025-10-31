module Serializer #(
    parameter FIFO_DEPTH = 4,
    parameter FIFO_ADDRW = 4
) (
    input  wire        clk,
    input  wire        rst,
    input  wire [63:0] data_in,
    input  wire        valid_in,
    input  wire [1:0]  vc_in,
    output reg  [3:0]  data_out,
    output reg         valid_out,
    output reg  [1:0]  vc_out
);
    reg [63:0] buffer;
    reg [3:0]  count;
    reg [1:0]  vc_stored;
    reg        transmitting;

    // force into registers (no RAM)
    (* ramstyle = "logic" *) reg [63:0] fifo_data [0:FIFO_DEPTH-1];
    (* ramstyle = "logic" *) reg [1:0]  fifo_vc   [0:FIFO_DEPTH-1];

    reg [FIFO_ADDRW-1:0] head;
    reg [FIFO_ADDRW-1:0] tail;
    reg [FIFO_ADDRW:0]   fifo_count;

    wire fifo_full  = (fifo_count == FIFO_DEPTH);
    wire fifo_empty = (fifo_count == 0);

    wire do_enqueue = valid_in && !fifo_full;
    wire do_dequeue = !transmitting && !fifo_empty;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            buffer      <= 64'b0;
            count       <= 4'b0;
            data_out    <= 4'b0;
            valid_out   <= 1'b0;
            vc_out      <= 2'b0;
            vc_stored   <= 2'b0;
            transmitting<= 1'b0;
            head        <= {FIFO_ADDRW{1'b0}};
            tail        <= {FIFO_ADDRW{1'b0}};
            fifo_count  <= { (FIFO_ADDRW+1){1'b0} };
        end else begin
            // enqueue
            if (do_enqueue) begin
                fifo_data[tail] <= data_in;
                fifo_vc  [tail] <= vc_in;
                tail <= (tail == FIFO_DEPTH-1) ? {FIFO_ADDRW{1'b0}} : tail + 1'b1;
            end

            // dequeue → start tx
            if (do_dequeue) begin
                buffer      <= fifo_data[head];
                vc_stored   <= fifo_vc[head];
                transmitting<= 1'b1;
                count       <= 4'd1;

                data_out    <= fifo_data[head][3:0];
                valid_out   <= 1'b1;
                vc_out      <= fifo_vc[head];

                head <= (head == FIFO_DEPTH-1) ? {FIFO_ADDRW{1'b0}} : head + 1'b1;
            end else if (transmitting) begin
                data_out  <= buffer[count*4 +: 4];
                valid_out <= 1'b1;
                vc_out    <= vc_stored;

                if (count == 4'd15) begin
                    transmitting <= 1'b0;
                    count        <= 4'd0;
                end else begin
                    count <= count + 1'b1;
                end
            end else begin
                valid_out <= 1'b0;
            end

            // count
            case ({do_enqueue, do_dequeue})
                2'b10: fifo_count <= fifo_count + 1'b1;
                2'b01: fifo_count <= fifo_count - 1'b1;
                default: fifo_count <= fifo_count;
            endcase
        end
    end
endmodule