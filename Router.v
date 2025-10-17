

module Router (

input wire clk,

input wire [63:0] northIn, eastIn, southIn, westIn, 
						peIn, creditsIn,
						
output wire [63:0] northOut, eastOut, southOut, westOut, 
						peOut, creditsOut

);


wire [63:0] VCAtoNorth, NorthtoVCA,
     RCtoNorth, NorthtoRC,
	  CBAtoNorth, NorthtoCBA,
	  NorthtoCBS, CBStoNorth;


Buffer northBuffer (
	.dataIn(northIn),
	.in_VCA(VCAtoNorth),
	.in_RC(RCtoNorth),
	.in_CBA(CBAtoNorth),
	
	.out_CBS(NorthtoCBS),
	.out_VCA(NorthtoVCA),
	.out_RC(NorthtoRC),
	.out_CBA(NorthtoCBA)
);

Buffer eastBuffer();
Buffer southBuffer();
Buffer westBuffer();


RC RCunit (
	.in_northBuff(NorthtoRC),
	.in_eastBuff(EasttoRC),
	.in_southBuff(SouthtoRC),
	.in_westBuff(WesttoRC),
	
	.out_northBuff(RCtoNorth),
	.out_eastBuff(RCtoEast),
	.out_southBuff(RCtoSouth),
	.out_westBuff(RCtoWest)

);

VCA VCAunit (
	.creditsIn(creditsIn),
	
	.in_northBuff(VCAtoNorth),
	.in_eastBuff(VCAtoEast),
	.in_southBuff(VCAtoSouth),
	.in_westBuff(VCAtoWest),
	
	.creditsOut(creditsOut),
	
	.out_northBuff(NorthtoVCA),
	.out_eastBuff(EasttoVCA),
	.out_southBuff(SouthtoVCA),
	.out_westBuff(WesttoVCA),
);

CrossBarSwitch CBSunit (
	.northBuff(NorthtoCBS),
	.eastBuff(EasttoCBS),
	.southBuff(SouthtoCBS),
	.westBuff(WesttoCBS),
	
	.in_CBA(CBAtoCBS),
	
	.northOut(northOut),
	.eastOut(eastOut),
	.southOut(southOut),
	.westOut(westOut),
	
	.out_CBA(CBStoCBA)

);

CBA CBAunit (
	.in_northBuff(NorthtoCBA),
	.in_eastBuff(EasttoCBA),
	.in_southBuff(SouthtoCBA),
	.in_westBuff(WesttoCBA),
	
	.out_northBuff(CBAtoNorth),
	.out_eastBuff(CBAtoEast),
	.out_southBuff(CBAtoSouth),
	.out_westBuff(CBAtoWest)
	
	.CBS(CBAtoCBS)
);


endmodule