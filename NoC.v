/*

04    14 24 34    44
    ------------
03  | 13 23 33 |  43
02  | 12 22 32 |  42
01  | 11 21 31 |  41
    ------------
00	  10 20 30    40


*/

//bottom left corner of network is 0,0 (corners not used)

module NoC (
input wire clk,

input wire [63:0] in01, in02, in03, in14, in24, in34,
			  in43, in42, in41, in30, in20, in10,
				
output wire [63:0] out01, out02, out03, out14, out24, out34,
				out43, out42, out41, out30, out20, out10
);

parameter FLIT_W = 64;

wire [FLIT_W - 1:0] w_23to13, w_13to23;

Router r13 (
	.clk(clk),
	
	.northIn(in14),
	.northOut(out14),
	
	.eastIn(w_23to13),
	.eastOut(w_13to23),
	
	.southIn(w_12to23),
	.southOut(w_13to12),
	
	.westIn(in03),
	.westOut(out03),

	.peIn(in_pe13),
	.peOut(out_pe13)
);


Router r23 (
	.clk(clk),

	.northIn(in24),
	.northOut(out24),
	
	.eastIn(w_33to23),
	.eastOut(w_23to33),
	
	.southIn(w_22to23),
	.southOut(w_23to22),
	
	.westIn(w_13to23),
	.westOut(w_23to13),

	.peIn(in_pe23),
	.peOut(out_pe23)

);

Router r33 (
	.clk(clk),

	.northIn(in34),
	.northOut(out34),
	
	.eastIn(in43),
	.eastOut(out43),
	
	.southIn(w_32to33),
	.southOut(w_33to32),
	
	.westIn(w_23to33),
	.westOut(w_33to23),

	.peIn(in_pe33),
	.peOut(out_pe33)
);

Router r12 (
	.clk(clk),

	.northIn(w_13to12),
	.northOut(w_12to13),
	
	.eastIn(w_22to12),
	.eastOut(w_12to22),
	
	.southIn(w_11to12),
	.southOut(w_12to11),
	
	.westIn(in02),
	.westOut(out02),

	.peIn(in_pe12),
	.peOut(out_pe12)
);

Router r22 (
	.clk(clk),

	.northIn(w_23to22),
	.northOut(w_22to23),
	
	.eastIn(w_32to22),
	.eastOut(w_22to32),
	
	.southIn(w_21to22),
	.southOut(w_22to21),
	
	.westIn(w_12to22),
	.westOut(w_22to12),

	.peIn(in_pe22),
	.peOut(out_pe22)
);

Router r32 (
	.clk(clk),

	.northIn(w_33to32),
	.northOut(w_32to33),
	
	.eastIn(in42),
	.eastOut(out42),
	
	.southIn(w_31to32),
	.southOut(w_32to31),
	
	.westIn(w_22to32),
	.westOut(w_32to22),

	.peIn(in_pe32),
	.peOut(out_pe32)
);

Router r11 (
	.clk(clk),

	.northIn(w_12to11),
	.northOut(w_11to12),
	
	.eastIn(w_21to11),
	.eastOut(w_11to21),
	
	.southIn(in10),
	.southOut(out10),
	
	.westIn(in01),
	.westOut(out01),

	.peIn(in_pe11),
	.peOut(out_pe11)
);

Router r21 (
	.clk(clk),

	.northIn(w_22to21),
	.northOut(w_21to22),
	
	.eastIn(w_31to21),
	.eastOut(w_21to31),
	
	.southIn(in20),
	.southOut(out20),
	
	.westIn(w_11to21),
	.westOut(w_21to11),

	.peIn(in_pe21),
	.peOut(out_pe21)
);

Router r31 (
	.clk(clk),

	.northIn(w_32to31),
	.northOut(w_31to32),
	
	.eastIn(in41),
	.eastOut(out41),
	
	.southIn(in30),
	.southOut(out30),
	
	.westIn(w_21to31),
	.westOut(w_31to21),

	.peIn(in_pe31),
	.peOut(out_pe31)
);




endmodule