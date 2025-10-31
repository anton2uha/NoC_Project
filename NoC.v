
// Network-on-Chip Top-Level Module - 3x3 Mesh with Router Coordinates

/*
04    14 24 34    44
    ------------
03  | 13 23 33 |  43
02  | 12 22 32 |  42
01  | 11 21 31 |  41
    ------------
00    10 20 30    40
*/
module NoC (
    input wire clk,
    input wire rst,
    
    // 4-bit external interfaces (one per side)
    input wire [3:0] in_west,
    input wire [3:0] in_south,
    input wire [3:0] in_east,
    input wire [3:0] in_north,
    
    // Select which of 3 ports per side (00=port1, 01=port2, 10=port3)
    input wire [1:0] west_sel,   // Select 01, 02, or 03
    input wire [1:0] south_sel,  // Select 10, 20, or 30
    input wire [1:0] east_sel,   // Select 41, 42, or 43
    input wire [1:0] north_sel,  // Select 14, 24, or 34
    
    // Valid and VC signals per side
    input wire in_west_valid,
    input wire in_south_valid,
    input wire in_east_valid,
    input wire in_north_valid,
    
    input wire [1:0] in_west_vc,
    input wire [1:0] in_south_vc,
    input wire [1:0] in_east_vc,
    input wire [1:0] in_north_vc,
    
    // 4-bit external outputs
    output wire [3:0] out_west,
    output wire [3:0] out_south,
    output wire [3:0] out_east,
    output wire [3:0] out_north,
    
    output wire out_west_valid,
    output wire out_south_valid,
    output wire out_east_valid,
    output wire out_north_valid,
    
    output wire [1:0] out_west_vc,
    output wire [1:0] out_south_vc,
    output wire [1:0] out_east_vc,
    output wire [1:0] out_north_vc
);

    parameter FLIT_W = 64;
    
    // ========================================================================
    // Internal 64-bit signals to/from edge deserializers/serializers since 
	 // we are limited to 60 input pins 
    // ========================================================================
    
    // Deserializer outputs (to routers)
    wire [63:0] deser_out01, deser_out02, deser_out03;
    wire [63:0] deser_out10, deser_out20, deser_out30;
    wire [63:0] deser_out14, deser_out24, deser_out34;
    wire [63:0] deser_out41, deser_out42, deser_out43;
    
    wire deser_out01_valid, deser_out02_valid, deser_out03_valid;
    wire deser_out10_valid, deser_out20_valid, deser_out30_valid;
    wire deser_out14_valid, deser_out24_valid, deser_out34_valid;
    wire deser_out41_valid, deser_out42_valid, deser_out43_valid;
    
    wire [1:0] deser_out01_vc, deser_out02_vc, deser_out03_vc;
    wire [1:0] deser_out10_vc, deser_out20_vc, deser_out30_vc;
    wire [1:0] deser_out14_vc, deser_out24_vc, deser_out34_vc;
    wire [1:0] deser_out41_vc, deser_out42_vc, deser_out43_vc;
    
    // Serializer inputs (from routers)
    wire [63:0] ser_in01, ser_in02, ser_in03;
    wire [63:0] ser_in10, ser_in20, ser_in30;
    wire [63:0] ser_in14, ser_in24, ser_in34;
    wire [63:0] ser_in41, ser_in42, ser_in43;
    
    wire ser_in01_valid, ser_in02_valid, ser_in03_valid;
    wire ser_in10_valid, ser_in20_valid, ser_in30_valid;
    wire ser_in14_valid, ser_in24_valid, ser_in34_valid;
    wire ser_in41_valid, ser_in42_valid, ser_in43_valid;
    
    wire [1:0] ser_in01_vc, ser_in02_vc, ser_in03_vc;
    wire [1:0] ser_in10_vc, ser_in20_vc, ser_in30_vc;
    wire [1:0] ser_in14_vc, ser_in24_vc, ser_in34_vc;
    wire [1:0] ser_in41_vc, ser_in42_vc, ser_in43_vc;
    
    // Serializer outputs (4-bit)
    wire [3:0] ser_out01, ser_out02, ser_out03;
    wire [3:0] ser_out10, ser_out20, ser_out30;
    wire [3:0] ser_out14, ser_out24, ser_out34;
    wire [3:0] ser_out41, ser_out42, ser_out43;
    
    wire ser_out01_valid, ser_out02_valid, ser_out03_valid;
    wire ser_out10_valid, ser_out20_valid, ser_out30_valid;
    wire ser_out14_valid, ser_out24_valid, ser_out34_valid;
    wire ser_out41_valid, ser_out42_valid, ser_out43_valid;
    
    wire [1:0] ser_out01_vc, ser_out02_vc, ser_out03_vc;
    wire [1:0] ser_out10_vc, ser_out20_vc, ser_out30_vc;
    wire [1:0] ser_out14_vc, ser_out24_vc, ser_out34_vc;
    wire [1:0] ser_out41_vc, ser_out42_vc, ser_out43_vc;
    
    // ========================================================================
    // Input Demux: Route 4-bit inputs to correct deserializer
    // ========================================================================
    
    // West side demux
    wire [3:0] deser_in01, deser_in02, deser_in03;
    wire deser_in01_valid, deser_in02_valid, deser_in03_valid;
    
    assign deser_in01 = (west_sel == 2'b00) ? in_west : 4'b0;
    assign deser_in02 = (west_sel == 2'b01) ? in_west : 4'b0;
    assign deser_in03 = (west_sel == 2'b10) ? in_west : 4'b0;
    
    assign deser_in01_valid = (west_sel == 2'b00) && in_west_valid;
    assign deser_in02_valid = (west_sel == 2'b01) && in_west_valid;
    assign deser_in03_valid = (west_sel == 2'b10) && in_west_valid;
    
    // South side demux
    wire [3:0] deser_in10, deser_in20, deser_in30;
    wire deser_in10_valid, deser_in20_valid, deser_in30_valid;
    
    assign deser_in10 = (south_sel == 2'b00) ? in_south : 4'b0;
    assign deser_in20 = (south_sel == 2'b01) ? in_south : 4'b0;
    assign deser_in30 = (south_sel == 2'b10) ? in_south : 4'b0;
    
    assign deser_in10_valid = (south_sel == 2'b00) && in_south_valid;
    assign deser_in20_valid = (south_sel == 2'b01) && in_south_valid;
    assign deser_in30_valid = (south_sel == 2'b10) && in_south_valid;
    
    // East side demux
    wire [3:0] deser_in41, deser_in42, deser_in43;
    wire deser_in41_valid, deser_in42_valid, deser_in43_valid;
    
    assign deser_in41 = (east_sel == 2'b00) ? in_east : 4'b0;
    assign deser_in42 = (east_sel == 2'b01) ? in_east : 4'b0;
    assign deser_in43 = (east_sel == 2'b10) ? in_east : 4'b0;
    
    assign deser_in41_valid = (east_sel == 2'b00) && in_east_valid;
    assign deser_in42_valid = (east_sel == 2'b01) && in_east_valid;
    assign deser_in43_valid = (east_sel == 2'b10) && in_east_valid;
    
    // North side demux
    wire [3:0] deser_in14, deser_in24, deser_in34;
    wire deser_in14_valid, deser_in24_valid, deser_in34_valid;
    
    assign deser_in14 = (north_sel == 2'b00) ? in_north : 4'b0;
    assign deser_in24 = (north_sel == 2'b01) ? in_north : 4'b0;
    assign deser_in34 = (north_sel == 2'b10) ? in_north : 4'b0;
    
    assign deser_in14_valid = (north_sel == 2'b00) && in_north_valid;
    assign deser_in24_valid = (north_sel == 2'b01) && in_north_valid;
    assign deser_in34_valid = (north_sel == 2'b10) && in_north_valid;
    
    // ========================================================================
    // Output Mux: Select which serializer outputs to external pins
    // ========================================================================
    
    assign out_west = (west_sel == 2'b00) ? ser_out01 :
                      (west_sel == 2'b01) ? ser_out02 :
                      (west_sel == 2'b10) ? ser_out03 : 4'b0;
    
    assign out_west_valid = (west_sel == 2'b00) ? ser_out01_valid :
                            (west_sel == 2'b01) ? ser_out02_valid :
                            (west_sel == 2'b10) ? ser_out03_valid : 1'b0;
    
    assign out_west_vc = (west_sel == 2'b00) ? ser_out01_vc :
                         (west_sel == 2'b01) ? ser_out02_vc :
                         (west_sel == 2'b10) ? ser_out03_vc : 2'b0;
    
    assign out_south = (south_sel == 2'b00) ? ser_out10 :
                       (south_sel == 2'b01) ? ser_out20 :
                       (south_sel == 2'b10) ? ser_out30 : 4'b0;
    
    assign out_south_valid = (south_sel == 2'b00) ? ser_out10_valid :
                             (south_sel == 2'b01) ? ser_out20_valid :
                             (south_sel == 2'b10) ? ser_out30_valid : 1'b0;
    
    assign out_south_vc = (south_sel == 2'b00) ? ser_out10_vc :
                          (south_sel == 2'b01) ? ser_out20_vc :
                          (south_sel == 2'b10) ? ser_out30_vc : 2'b0;
    
    assign out_east = (east_sel == 2'b00) ? ser_out41 :
                      (east_sel == 2'b01) ? ser_out42 :
                      (east_sel == 2'b10) ? ser_out43 : 4'b0;
    
    assign out_east_valid = (east_sel == 2'b00) ? ser_out41_valid :
                            (east_sel == 2'b01) ? ser_out42_valid :
                            (east_sel == 2'b10) ? ser_out43_valid : 1'b0;
    
    assign out_east_vc = (east_sel == 2'b00) ? ser_out41_vc :
                         (east_sel == 2'b01) ? ser_out42_vc :
                         (east_sel == 2'b10) ? ser_out43_vc : 2'b0;
    
    assign out_north = (north_sel == 2'b00) ? ser_out14 :
                       (north_sel == 2'b01) ? ser_out24 :
                       (north_sel == 2'b10) ? ser_out34 : 4'b0;
    
    assign out_north_valid = (north_sel == 2'b00) ? ser_out14_valid :
                             (north_sel == 2'b01) ? ser_out24_valid :
                             (north_sel == 2'b10) ? ser_out34_valid : 1'b0;
    
    assign out_north_vc = (north_sel == 2'b00) ? ser_out14_vc :
                          (north_sel == 2'b01) ? ser_out24_vc :
                          (north_sel == 2'b10) ? ser_out34_vc : 2'b0;
    
    // ========================================================================
    // Deserializer Instantiations (12 total)
    // ========================================================================
    
    Deserializer d01 (.clk(clk), .rst(rst), .data_in(deser_in01), .valid_in(deser_in01_valid), .vc_in(in_west_vc),
                      .data_out(deser_out01), .valid_out(deser_out01_valid), .vc_out(deser_out01_vc));
    
    Deserializer d02 (.clk(clk), .rst(rst), .data_in(deser_in02), .valid_in(deser_in02_valid), .vc_in(in_west_vc),
                      .data_out(deser_out02), .valid_out(deser_out02_valid), .vc_out(deser_out02_vc));
    
    Deserializer d03 (.clk(clk), .rst(rst), .data_in(deser_in03), .valid_in(deser_in03_valid), .vc_in(in_west_vc),
                      .data_out(deser_out03), .valid_out(deser_out03_valid), .vc_out(deser_out03_vc));
    
    Deserializer d10 (.clk(clk), .rst(rst), .data_in(deser_in10), .valid_in(deser_in10_valid), .vc_in(in_south_vc),
                      .data_out(deser_out10), .valid_out(deser_out10_valid), .vc_out(deser_out10_vc));
    
    Deserializer d20 (.clk(clk), .rst(rst), .data_in(deser_in20), .valid_in(deser_in20_valid), .vc_in(in_south_vc),
                      .data_out(deser_out20), .valid_out(deser_out20_valid), .vc_out(deser_out20_vc));
    
    Deserializer d30 (.clk(clk), .rst(rst), .data_in(deser_in30), .valid_in(deser_in30_valid), .vc_in(in_south_vc),
                      .data_out(deser_out30), .valid_out(deser_out30_valid), .vc_out(deser_out30_vc));
    
    Deserializer d14 (.clk(clk), .rst(rst), .data_in(deser_in14), .valid_in(deser_in14_valid), .vc_in(in_north_vc),
                      .data_out(deser_out14), .valid_out(deser_out14_valid), .vc_out(deser_out14_vc));
    
    Deserializer d24 (.clk(clk), .rst(rst), .data_in(deser_in24), .valid_in(deser_in24_valid), .vc_in(in_north_vc),
                      .data_out(deser_out24), .valid_out(deser_out24_valid), .vc_out(deser_out24_vc));
    
    Deserializer d34 (.clk(clk), .rst(rst), .data_in(deser_in34), .valid_in(deser_in34_valid), .vc_in(in_north_vc),
                      .data_out(deser_out34), .valid_out(deser_out34_valid), .vc_out(deser_out34_vc));
    
    Deserializer d41 (.clk(clk), .rst(rst), .data_in(deser_in41), .valid_in(deser_in41_valid), .vc_in(in_east_vc),
                      .data_out(deser_out41), .valid_out(deser_out41_valid), .vc_out(deser_out41_vc));
    
    Deserializer d42 (.clk(clk), .rst(rst), .data_in(deser_in42), .valid_in(deser_in42_valid), .vc_in(in_east_vc),
                      .data_out(deser_out42), .valid_out(deser_out42_valid), .vc_out(deser_out42_vc));
    
    Deserializer d43 (.clk(clk), .rst(rst), .data_in(deser_in43), .valid_in(deser_in43_valid), .vc_in(in_east_vc),
                      .data_out(deser_out43), .valid_out(deser_out43_valid), .vc_out(deser_out43_vc));
    
    // ========================================================================
    // Serializer Instantiations (12 total)
    // ========================================================================
    
    Serializer s01 (.clk(clk), .rst(rst), .data_in(ser_in01), .valid_in(ser_in01_valid), .vc_in(ser_in01_vc),
                    .data_out(ser_out01), .valid_out(ser_out01_valid), .vc_out(ser_out01_vc));
    
    Serializer s02 (.clk(clk), .rst(rst), .data_in(ser_in02), .valid_in(ser_in02_valid), .vc_in(ser_in02_vc),
                    .data_out(ser_out02), .valid_out(ser_out02_valid), .vc_out(ser_out02_vc));
    
    Serializer s03 (.clk(clk), .rst(rst), .data_in(ser_in03), .valid_in(ser_in03_valid), .vc_in(ser_in03_vc),
                    .data_out(ser_out03), .valid_out(ser_out03_valid), .vc_out(ser_out03_vc));
    
    Serializer s10 (.clk(clk), .rst(rst), .data_in(ser_in10), .valid_in(ser_in10_valid), .vc_in(ser_in10_vc),
                    .data_out(ser_out10), .valid_out(ser_out10_valid), .vc_out(ser_out10_vc));
    
    Serializer s20 (.clk(clk), .rst(rst), .data_in(ser_in20), .valid_in(ser_in20_valid), .vc_in(ser_in20_vc),
                    .data_out(ser_out20), .valid_out(ser_out20_valid), .vc_out(ser_out20_vc));
    
    Serializer s30 (.clk(clk), .rst(rst), .data_in(ser_in30), .valid_in(ser_in30_valid), .vc_in(ser_in30_vc),
                    .data_out(ser_out30), .valid_out(ser_out30_valid), .vc_out(ser_out30_vc));
    
    Serializer s14 (.clk(clk), .rst(rst), .data_in(ser_in14), .valid_in(ser_in14_valid), .vc_in(ser_in14_vc),
                    .data_out(ser_out14), .valid_out(ser_out14_valid), .vc_out(ser_out14_vc));
    
    Serializer s24 (.clk(clk), .rst(rst), .data_in(ser_in24), .valid_in(ser_in24_valid), .vc_in(ser_in24_vc),
                    .data_out(ser_out24), .valid_out(ser_out24_valid), .vc_out(ser_out24_vc));
    
    Serializer s34 (.clk(clk), .rst(rst), .data_in(ser_in34), .valid_in(ser_in34_valid), .vc_in(ser_in34_vc),
                    .data_out(ser_out34), .valid_out(ser_out34_valid), .vc_out(ser_out34_vc));
    
    Serializer s41 (.clk(clk), .rst(rst), .data_in(ser_in41), .valid_in(ser_in41_valid), .vc_in(ser_in41_vc),
                    .data_out(ser_out41), .valid_out(ser_out41_valid), .vc_out(ser_out41_vc));
    
    Serializer s42 (.clk(clk), .rst(rst), .data_in(ser_in42), .valid_in(ser_in42_valid), .vc_in(ser_in42_vc),
                    .data_out(ser_out42), .valid_out(ser_out42_valid), .vc_out(ser_out42_vc));
    
    Serializer s43 (.clk(clk), .rst(rst), .data_in(ser_in43), .valid_in(ser_in43_valid), .vc_in(ser_in43_vc),
                    .data_out(ser_out43), .valid_out(ser_out43_valid), .vc_out(ser_out43_vc));
    
    // ========================================================================
    // PE inputs (internal to chip - connect directly to routers)
    // ========================================================================
    wire [63:0] in_pe11, in_pe12, in_pe13, in_pe21, in_pe22, in_pe23, in_pe31, in_pe32, in_pe33;
    wire in_pe11_valid, in_pe12_valid, in_pe13_valid, in_pe21_valid, in_pe22_valid, in_pe23_valid;
    wire in_pe31_valid, in_pe32_valid, in_pe33_valid;
    wire [1:0] in_pe11_vc, in_pe12_vc, in_pe13_vc, in_pe21_vc, in_pe22_vc, in_pe23_vc;
    wire [1:0] in_pe31_vc, in_pe32_vc, in_pe33_vc;
    
    wire [63:0] out_pe11, out_pe12, out_pe13, out_pe21, out_pe22, out_pe23, out_pe31, out_pe32, out_pe33;
    
    // TODO: Connect these to actual PE modules when you add them
    assign in_pe11 = 64'b0; assign in_pe11_valid = 1'b0; assign in_pe11_vc = 2'b0;
    assign in_pe12 = 64'b0; assign in_pe12_valid = 1'b0; assign in_pe12_vc = 2'b0;
    assign in_pe13 = 64'b0; assign in_pe13_valid = 1'b0; assign in_pe13_vc = 2'b0;
    assign in_pe21 = 64'b0; assign in_pe21_valid = 1'b0; assign in_pe21_vc = 2'b0;
    assign in_pe22 = 64'b0; assign in_pe22_valid = 1'b0; assign in_pe22_vc = 2'b0;
    assign in_pe23 = 64'b0; assign in_pe23_valid = 1'b0; assign in_pe23_vc = 2'b0;
    assign in_pe31 = 64'b0; assign in_pe31_valid = 1'b0; assign in_pe31_vc = 2'b0;
    assign in_pe32 = 64'b0; assign in_pe32_valid = 1'b0; assign in_pe32_vc = 2'b0;
    assign in_pe33 = 64'b0; assign in_pe33_valid = 1'b0; assign in_pe33_vc = 2'b0;
    
    // ========================================================================
    // Inter-router wires (all internal 64-bit connections)
    // ========================================================================
    
    wire [FLIT_W-1:0] w_13to12, w_12to13, w_13to23, w_23to13,
                       w_22to12, w_12to22, w_22to21, w_21to22, w_22to23, w_23to22, w_22to32, w_32to22,
                       w_11to12, w_12to11, w_11to21, w_21to11,
                       w_21to31, w_31to21,
                       w_31to32, w_32to31,
                       w_32to33, w_33to32, w_23to33, w_33to23;
    
    wire w_13to12_valid, w_12to13_valid, w_13to23_valid, w_23to13_valid,
         w_22to12_valid, w_12to22_valid, w_22to21_valid, w_21to22_valid, w_22to23_valid, w_23to22_valid, w_22to32_valid, w_32to22_valid,
         w_11to12_valid, w_12to11_valid, w_11to21_valid, w_21to11_valid,
         w_21to31_valid, w_31to21_valid,
         w_31to32_valid, w_32to31_valid,
         w_32to33_valid, w_33to32_valid, w_23to33_valid, w_33to23_valid;
    
    wire [1:0] w_13to12_vc, w_12to13_vc, w_13to23_vc, w_23to13_vc,
               w_22to12_vc, w_12to22_vc, w_22to21_vc, w_21to22_vc, w_22to23_vc, w_23to22_vc, w_22to32_vc, w_32to22_vc,
               w_11to12_vc, w_12to11_vc, w_11to21_vc, w_21to11_vc,
               w_21to31_vc, w_31to21_vc,
               w_31to32_vc, w_32to31_vc,
               w_32to33_vc, w_33to32_vc, w_23to33_vc, w_33to23_vc;
    
    wire [1:0] c_13to12, c_12to13, c_13to23, c_23to13,
               c_22to12, c_12to22, c_22to21, c_21to22, c_22to23, c_23to22, c_22to32, c_32to22,
               c_11to12, c_12to11, c_11to21, c_21to11,
               c_21to31, c_31to21,
               c_31to32, c_32to31,
               c_32to33, c_33to32, c_23to33, c_33to23;
    
    wire [1:0] edge_credits = 2'b11;
    
    // ========================================================================
    // Router Instantiations (all connections now 64-bit internal)
    // ========================================================================
    
    // Router (1,1)
    Router r11 (
        .clk(clk), .rst(rst), 
        .router_x(3'd1), .router_y(3'd1),
        
        .northIn(w_12to11), .northIn_valid(w_12to11_valid), .northIn_vc(w_12to11_vc),
        .eastIn(w_21to11), .eastIn_valid(w_21to11_valid), .eastIn_vc(w_21to11_vc),
        .southIn(deser_out10), .southIn_valid(deser_out10_valid), .southIn_vc(deser_out10_vc),
        .westIn(deser_out01), .westIn_valid(deser_out01_valid), .westIn_vc(deser_out01_vc),
        .peIn(in_pe11), .peIn_valid(in_pe11_valid), .peIn_vc(in_pe11_vc),
        
        .north_credits_in(c_12to11), .east_credits_in(c_21to11),
        .south_credits_in(edge_credits), .west_credits_in(edge_credits), .local_credits_in(2'b11),
        
        .northOut(w_11to12), .northOut_valid(w_11to12_valid), .northOut_vc(w_11to12_vc),
        .eastOut(w_11to21), .eastOut_valid(w_11to21_valid), .eastOut_vc(w_11to21_vc),
        .southOut(ser_in10), .southOut_valid(ser_in10_valid), .southOut_vc(ser_in10_vc),
        .westOut(ser_in01), .westOut_valid(ser_in01_valid), .westOut_vc(ser_in01_vc),
        .peOut(out_pe11), .peOut_valid(), .peOut_vc(),
        
        .north_credits_out(c_11to12), .east_credits_out(c_11to21),
        .south_credits_out(), .west_credits_out(), .local_credits_out()
    );
    
    // Router (1,2)
    Router r12 (
        .clk(clk), .rst(rst), .router_x(3'd1), .router_y(3'd2),
        .northIn(w_13to12), .northIn_valid(w_13to12_valid), .northIn_vc(w_13to12_vc),
        .eastIn(w_22to12), .eastIn_valid(w_22to12_valid), .eastIn_vc(w_22to12_vc),
        .southIn(w_11to12), .southIn_valid(w_11to12_valid), .southIn_vc(w_11to12_vc),
        .westIn(deser_out02), .westIn_valid(deser_out02_valid), .westIn_vc(deser_out02_vc),
        .peIn(in_pe12), .peIn_valid(in_pe12_valid), .peIn_vc(in_pe12_vc),
        .north_credits_in(c_13to12), .east_credits_in(c_22to12),
        .south_credits_in(c_11to12), .west_credits_in(edge_credits), .local_credits_in(2'b11),
        .northOut(w_12to13), .northOut_valid(w_12to13_valid), .northOut_vc(w_12to13_vc),
        .eastOut(w_12to22), .eastOut_valid(w_12to22_valid), .eastOut_vc(w_12to22_vc),
        .southOut(w_12to11), .southOut_valid(w_12to11_valid), .southOut_vc(w_12to11_vc),
        .westOut(ser_in02), .westOut_valid(ser_in02_valid), .westOut_vc(ser_in02_vc),
        .peOut(out_pe12), .peOut_valid(), .peOut_vc(),
        .north_credits_out(c_12to13), .east_credits_out(c_12to22),
        .south_credits_out(c_12to11), .west_credits_out(), .local_credits_out()
    );
    
    // Router (1,3)
    Router r13 (
        .clk(clk), .rst(rst), .router_x(3'd1), .router_y(3'd3),
        .northIn(deser_out14), .northIn_valid(deser_out14_valid), .northIn_vc(deser_out14_vc),
        .eastIn(w_23to13), .eastIn_valid(w_23to13_valid), .eastIn_vc(w_23to13_vc),
        .southIn(w_12to13), .southIn_valid(w_12to13_valid), .southIn_vc(w_12to13_vc),
        .westIn(deser_out03), .westIn_valid(deser_out03_valid), .westIn_vc(deser_out03_vc),
        .peIn(in_pe13), .peIn_valid(in_pe13_valid), .peIn_vc(in_pe13_vc),
        .north_credits_in(edge_credits), .east_credits_in(c_23to13),
        .south_credits_in(c_12to13), .west_credits_in(edge_credits), .local_credits_in(2'b11),
        .northOut(ser_in14), .northOut_valid(ser_in14_valid), .northOut_vc(ser_in14_vc),
        .eastOut(w_13to23), .eastOut_valid(w_13to23_valid), .eastOut_vc(w_13to23_vc),
        .southOut(w_13to12), .southOut_valid(w_13to12_valid), .southOut_vc(w_13to12_vc),
        .westOut(ser_in03), .westOut_valid(ser_in03_valid), .westOut_vc(ser_in03_vc),
        .peOut(out_pe13), .peOut_valid(), .peOut_vc(),
        .north_credits_out(), .east_credits_out(c_13to23),
        .south_credits_out(c_13to12), .west_credits_out(), .local_credits_out()
    );
    
    // Router (2,1)
    Router r21 (
        .clk(clk), .rst(rst), .router_x(3'd2), .router_y(3'd1),
        .northIn(w_22to21), .northIn_valid(w_22to21_valid), .northIn_vc(w_22to21_vc),
        .eastIn(w_31to21), .eastIn_valid(w_31to21_valid), .eastIn_vc(w_31to21_vc),
        .southIn(deser_out20), .southIn_valid(deser_out20_valid), .southIn_vc(deser_out20_vc),
        .westIn(w_11to21), .westIn_valid(w_11to21_valid), .westIn_vc(w_11to21_vc),
        .peIn(in_pe21), .peIn_valid(in_pe21_valid), .peIn_vc(in_pe21_vc),
        .north_credits_in(c_22to21), .east_credits_in(c_31to21),
        .south_credits_in(edge_credits), .west_credits_in(c_11to21), .local_credits_in(2'b11),
        .northOut(w_21to22), .northOut_valid(w_21to22_valid), .northOut_vc(w_21to22_vc),
        .eastOut(w_21to31), .eastOut_valid(w_21to31_valid), .eastOut_vc(w_21to31_vc),
        .southOut(ser_in20), .southOut_valid(ser_in20_valid), .southOut_vc(ser_in20_vc),
        .westOut(w_21to11), .westOut_valid(w_21to11_valid), .westOut_vc(w_21to11_vc),
        .peOut(out_pe21), .peOut_valid(), .peOut_vc(),
        .north_credits_out(c_21to22), .east_credits_out(c_21to31),
        .south_credits_out(), .west_credits_out(c_21to11), .local_credits_out()
    );
    
    // Router (2,2)
    Router r22 (
        .clk(clk), .rst(rst), .router_x(3'd2), .router_y(3'd2),
        .northIn(w_23to22), .northIn_valid(w_23to22_valid), .northIn_vc(w_23to22_vc),
        .eastIn(w_32to22), .eastIn_valid(w_32to22_valid), .eastIn_vc(w_32to22_vc),
        .southIn(w_21to22), .southIn_valid(w_21to22_valid), .southIn_vc(w_21to22_vc),
        .westIn(w_12to22), .westIn_valid(w_12to22_valid), .westIn_vc(w_12to22_vc),
        .peIn(in_pe22), .peIn_valid(in_pe22_valid), .peIn_vc(in_pe22_vc),
        .north_credits_in(c_23to22), .east_credits_in(c_32to22),
        .south_credits_in(c_21to22), .west_credits_in(c_12to22), .local_credits_in(2'b11),
        .northOut(w_22to23), .northOut_valid(w_22to23_valid), .northOut_vc(w_22to23_vc),
        .eastOut(w_22to32), .eastOut_valid(w_22to32_valid), .eastOut_vc(w_22to32_vc),
        .southOut(w_22to21), .southOut_valid(w_22to21_valid), .southOut_vc(w_22to21_vc),
        .westOut(w_22to12), .westOut_valid(w_22to12_valid), .westOut_vc(w_22to12_vc),
        .peOut(out_pe22), .peOut_valid(), .peOut_vc(),
        .north_credits_out(c_22to23), .east_credits_out(c_22to32),
        .south_credits_out(c_22to21), .west_credits_out(c_22to12), .local_credits_out()
    );
    
    // Router (2,3)
    Router r23 (
        .clk(clk), .rst(rst), .router_x(3'd2), .router_y(3'd3),
        .northIn(deser_out24), .northIn_valid(deser_out24_valid), .northIn_vc(deser_out24_vc),
        .eastIn(w_33to23), .eastIn_valid(w_33to23_valid), .eastIn_vc(w_33to23_vc),
        .southIn(w_22to23), .southIn_valid(w_22to23_valid), .southIn_vc(w_22to23_vc),
        .westIn(w_13to23), .westIn_valid(w_13to23_valid), .westIn_vc(w_13to23_vc),
        .peIn(in_pe23), .peIn_valid(in_pe23_valid), .peIn_vc(in_pe23_vc),
        .north_credits_in(edge_credits), .east_credits_in(c_33to23),
        .south_credits_in(c_22to23), .west_credits_in(c_13to23), .local_credits_in(2'b11),
        .northOut(ser_in24), .northOut_valid(ser_in24_valid), .northOut_vc(ser_in24_vc),
        .eastOut(w_23to33), .eastOut_valid(w_23to33_valid), .eastOut_vc(w_23to33_vc),
        .southOut(w_23to22), .southOut_valid(w_23to22_valid), .southOut_vc(w_23to22_vc),
        .westOut(w_23to13), .westOut_valid(w_23to13_valid), .westOut_vc(w_23to13_vc),
        .peOut(out_pe23), .peOut_valid(), .peOut_vc(),
        .north_credits_out(), .east_credits_out(c_23to33),
        .south_credits_out(c_23to22), .west_credits_out(c_23to13), .local_credits_out()
    );
    
    // Router (3,1)
    Router r31 (
        .clk(clk), .rst(rst), .router_x(3'd3), .router_y(3'd1),
        .northIn(w_32to31), .northIn_valid(w_32to31_valid), .northIn_vc(w_32to31_vc),
        .eastIn(deser_out41), .eastIn_valid(deser_out41_valid), .eastIn_vc(deser_out41_vc),
        .southIn(deser_out30), .southIn_valid(deser_out30_valid), .southIn_vc(deser_out30_vc),
        .westIn(w_21to31), .westIn_valid(w_21to31_valid), .westIn_vc(w_21to31_vc),
        .peIn(in_pe31), .peIn_valid(in_pe31_valid), .peIn_vc(in_pe31_vc),
        .north_credits_in(c_32to31), .east_credits_in(edge_credits),
        .south_credits_in(edge_credits), .west_credits_in(c_21to31), .local_credits_in(2'b11),
        .northOut(w_31to32), .northOut_valid(w_31to32_valid), .northOut_vc(w_31to32_vc),
        .eastOut(ser_in41), .eastOut_valid(ser_in41_valid), .eastOut_vc(ser_in41_vc),
        .southOut(ser_in30), .southOut_valid(ser_in30_valid), .southOut_vc(ser_in30_vc),
        .westOut(w_31to21), .westOut_valid(w_31to21_valid), .westOut_vc(w_31to21_vc),
        .peOut(out_pe31), .peOut_valid(), .peOut_vc(),
        .north_credits_out(c_31to32), .east_credits_out(),
        .south_credits_out(), .west_credits_out(c_31to21), .local_credits_out()
    );
    
    // Router (3,2)
    Router r32 (
        .clk(clk), .rst(rst), .router_x(3'd3), .router_y(3'd2),
        .northIn(w_33to32), .northIn_valid(w_33to32_valid), .northIn_vc(w_33to32_vc),
        .eastIn(deser_out42), .eastIn_valid(deser_out42_valid), .eastIn_vc(deser_out42_vc),
        .southIn(w_31to32), .southIn_valid(w_31to32_valid), .southIn_vc(w_31to32_vc),
        .westIn(w_22to32), .westIn_valid(w_22to32_valid), .westIn_vc(w_22to32_vc),
        .peIn(in_pe32), .peIn_valid(in_pe32_valid), .peIn_vc(in_pe32_vc),
        .north_credits_in(c_33to32), .east_credits_in(edge_credits),
        .south_credits_in(c_31to32), .west_credits_in(c_22to32), .local_credits_in(2'b11),
        .northOut(w_32to33), .northOut_valid(w_32to33_valid), .northOut_vc(w_32to33_vc),
        .eastOut(ser_in42), .eastOut_valid(ser_in42_valid), .eastOut_vc(ser_in42_vc),
        .southOut(w_32to31), .southOut_valid(w_32to31_valid), .southOut_vc(w_32to31_vc),
        .westOut(w_32to22), .westOut_valid(w_32to22_valid), .westOut_vc(w_32to22_vc),
        .peOut(out_pe32), .peOut_valid(), .peOut_vc(),
        .north_credits_out(c_32to33), .east_credits_out(),
        .south_credits_out(c_32to31), .west_credits_out(c_32to22), .local_credits_out()
    );
    
    // Router (3,3)
    Router r33 (
        .clk(clk), .rst(rst), .router_x(3'd3), .router_y(3'd3),
        .northIn(deser_out34), .northIn_valid(deser_out34_valid), .northIn_vc(deser_out34_vc),
        .eastIn(deser_out43), .eastIn_valid(deser_out43_valid), .eastIn_vc(deser_out43_vc),
        .southIn(w_32to33), .southIn_valid(w_32to33_valid), .southIn_vc(w_32to33_vc),
        .westIn(w_23to33), .westIn_valid(w_23to33_valid), .westIn_vc(w_23to33_vc),
        .peIn(in_pe33), .peIn_valid(in_pe33_valid), .peIn_vc(in_pe33_vc),
        .north_credits_in(edge_credits), .east_credits_in(edge_credits),
        .south_credits_in(c_32to33), .west_credits_in(c_23to33), .local_credits_in(2'b11),
        .northOut(ser_in34), .northOut_valid(ser_in34_valid), .northOut_vc(ser_in34_vc),
        .eastOut(ser_in43), .eastOut_valid(ser_in43_valid), .eastOut_vc(ser_in43_vc),
        .southOut(w_33to32), .southOut_valid(w_33to32_valid), .southOut_vc(w_33to32_vc),
        .westOut(w_33to23), .westOut_valid(w_33to23_valid), .westOut_vc(w_33to23_vc),
        .peOut(out_pe33), .peOut_valid(), .peOut_vc(),
        .north_credits_out(), .east_credits_out(),
        .south_credits_out(c_33to32), .west_credits_out(c_33to23), .local_credits_out()
    );
	 
	 // DEBUG: Monitor east output
always @(posedge clk) begin
    if (!rst) begin
        if (ser_out43_valid) begin
            $display("[NOC OUTPUT] Cycle %0d: ser_out43_valid=1, ser_out43=0x%h, east_sel=%b, out_east_valid=%b", 
                     $time/10, ser_out43, east_sel, out_east_valid);
        end
    end
end

endmodule