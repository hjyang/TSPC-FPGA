`timescale 1ns / 1ps

module twengine0( clk,
                  reset,
                  din,
                  dout,
                  stage,
                  feed,
                  next,
                  wout
                );

  input          clk;
  input          reset;
  input  [511:0] din;
  input          stage;
  input          feed;
  input          next;

  output [543:0] dout;
  output  [31:0] wout;
 
  reg     [31:0] rW00;
  reg     [31:0] rW01;
  reg     [31:0] rW02;
  reg     [31:0] rW03;
  reg     [31:0] rW04;
  reg     [31:0] rW05;
  reg     [31:0] rW06;
  reg     [31:0] rW07;
  reg     [31:0] rW08;
  reg     [31:0] rW09;
  reg     [31:0] rW010;
  reg     [31:0] rW011;
  reg     [31:0] rW012;
  reg     [31:0] rW013;
  reg     [31:0] rW014;
  reg     [31:0] rW015;
        
  reg     [31:0] pipeXor0;
  reg     [31:0] pipeXor1;
  
  wire    [31:0] pipeXor0In;
  wire    [31:0] pipeXor1In;
  wire    [31:0] secondOut;
  wire    [31:0] _secondOut;
  wire    [31:0] firstOut;
  wire    [31:0] newOut;
  
  wire    [31:0] rW00In;
  wire    [31:0] rW01In;
  wire    [31:0] rW02In;
  wire    [31:0] rW03In;
  wire    [31:0] rW04In;
  wire    [31:0] rW05In;
  wire    [31:0] rW06In;
  wire    [31:0] rW07In;
  wire    [31:0] rW08In;
  wire    [31:0] rW09In;
  wire    [31:0] rW010In;
  wire    [31:0] rW011In;
  wire    [31:0] rW012In;
  wire    [31:0] rW013In;
  wire    [31:0] rW014In;
  wire    [31:0] rW015In;

  assign pipeXor0In = rW09^rW014;
  assign pipeXor1In = rW01^rW03;
  assign _secondOut = pipeXor0^pipeXor1;
  assign secondOut  = {_secondOut[30:0],_secondOut[31]};
  assign firstOut   = rW00;
  assign newOut     = (stage)? secondOut : firstOut;

  assign wout = rW015;
  assign dout = {pipeXor0In,pipeXor1In,rW02,rW03,rW04,rW05,rW06,rW07,rW08,rW09,rW010,rW011,rW012,rW013,rW014,rW015,secondOut};

  assign rW015In = (feed)? din[511:480] : ( (next)? newOut : rW015 );
  assign rW00In  = (feed)? din[479:448] : ( (next)? rW01   : rW00  );
  assign rW01In  = (feed)? din[447:416] : ( (next)? rW02   : rW01  );
  assign rW02In  = (feed)? din[415:384] : ( (next)? rW03   : rW02  );
  assign rW03In  = (feed)? din[383:352] : ( (next)? rW04   : rW03  );
  assign rW04In  = (feed)? din[351:320] : ( (next)? rW05   : rW04  );
  assign rW05In  = (feed)? din[319:288] : ( (next)? rW06   : rW05  );
  assign rW06In  = (feed)? din[287:256] : ( (next)? rW07   : rW06  );
  assign rW07In  = (feed)? din[255:224] : ( (next)? rW08   : rW07  );
  assign rW08In  = (feed)? din[223:192] : ( (next)? rW09   : rW08  );
  assign rW09In  = (feed)? din[191:160] : ( (next)? rW010  : rW09  );
  assign rW010In = (feed)? din[159:128] : ( (next)? rW011  : rW010 );
  assign rW011In = (feed)? din[127: 96] : ( (next)? rW012  : rW011 );
  assign rW012In = (feed)? din[ 95: 64] : ( (next)? rW013  : rW012 );
  assign rW013In = (feed)? din[ 63: 32] : ( (next)? rW014  : rW013 );
  assign rW014In = (feed)? din[ 31:  0] : ( (next)? rW015  : rW014 );

always @ ( posedge clk or posedge reset )
 begin
   if( reset )
    begin
      rW00     <=  32'd0;
      rW01     <=  32'd0;
      rW02     <=  32'd0;
      rW03     <=  32'd0;
      rW04     <=  32'd0;
      rW05     <=  32'd0;
      rW06     <=  32'd0;
      rW07     <=  32'd0;
      rW08     <=  32'd0;
      rW09     <=  32'd0;
      rW010    <=  32'd0;
      rW011    <=  32'd0;
      rW012    <=  32'd0;
      rW013    <=  32'd0;
      rW014    <=  32'd0;
      rW015    <=  32'd0;
      pipeXor0 <=  32'd0;
      pipeXor1 <=  32'd0;  
    end
   else 
    begin
      rW00     <=  rW00In;
      rW01     <=  rW01In;
      rW02     <=  rW02In;
      rW03     <=  rW03In;
      rW04     <=  rW04In;
      rW05     <=  rW05In;
      rW06     <=  rW06In;
      rW07     <=  rW07In;
      rW08     <=  rW08In;
      rW09     <=  rW09In;
      rW010    <=  rW010In;
      rW011    <=  rW011In;
      rW012    <=  rW012In;
      rW013    <=  rW013In;
      rW014    <=  rW014In;
      rW015    <=  rW015In;
      pipeXor0 <=  pipeXor0In;
      pipeXor1 <=  pipeXor1In;  
    end
 end

endmodule
