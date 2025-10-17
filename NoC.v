/*

04    14 24 34    44
    ------------
03  | 13 23 33 |  43
02  | 12 22 32 |  42
01  | 11 21 31 |  41
    ------------
00    10 20 30    40


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
	.peOut(out_pe13)

);

Router r33 ();
Router r12 ();
Router r22 ();
Router r32 ();
Router r11 ();
Router r21 ();
Router r31 ();



endmodule