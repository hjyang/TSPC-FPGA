`timescale 1ns / 1ps

module wengine1( clk,
                 reset,
                 din,
                 dout,
                 feed,
                 next,
                 wout
               );

  input          clk;
  input          reset;
  input  [543:0] din;
  input          feed;
  input          next;

  output  [31:0] wout; 
  output [543:0] dout;
 
  reg  [31:0] rW01;
  reg  [31:0] rW02;
  reg  [31:0] rW03;
  reg  [31:0] rW04;
  reg  [31:0] rW05;
  reg  [31:0] rW06;
  reg  [31:0] rW07;
  reg  [31:0] rW08;
  reg  [31:0] rW09;
  reg  [31:0] rW010;
  reg  [31:0] rW011;
  reg  [31:0] rW012;
  reg  [31:0] rW013;
  reg  [31:0] rW014;
  reg  [31:0] rW015;
       
  reg  [31:0] pipeXor0;
  reg  [31:0] pipeXor1;
  
  wire [31:0] _pipeXor0In;
  wire [31:0] _pipeXor1In;
  wire [31:0] pipeXor0In;
  wire [31:0] pipeXor1In;
  wire [31:0] _newOut;
  wire [31:0] newOut;
  
  wire [31:0] rW01In;
  wire [31:0] rW02In;
  wire [31:0] rW03In;
  wire [31:0] rW04In;
  wire [31:0] rW05In;
  wire [31:0] rW06In;
  wire [31:0] rW07In;
  wire [31:0] rW08In;
  wire [31:0] rW09In;
  wire [31:0] rW010In;
  wire [31:0] rW011In;
  wire [31:0] rW012In;
  wire [31:0] rW013In;
  wire [31:0] rW014In;
  wire [31:0] rW015In;
  
  assign _pipeXor0In = rW09^rW014;
  assign _pipeXor1In = rW01^rW03;
  assign pipeXor0In  = (feed)? din[543:512]: ( (next)? _pipeXor0In  : pipeXor0  );
  assign pipeXor1In  = (feed)? din[511:480]: ( (next)? _pipeXor1In  : pipeXor1  );
  assign _newOut     = pipeXor0 ^ pipeXor1;
  assign newOut      = {_newOut[30:0],_newOut[31]};
  
  assign wout = rW015;
  assign dout = {_pipeXor0In, _pipeXor1In, rW02,rW03,rW04,rW05,rW06,rW07,rW08,rW09,rW010,rW011,rW012,rW013,rW014,rW015,newOut};
  
  assign rW01In  = (feed)? din[479:448] : ( (next)? rW02   : rW01  );
  assign rW02In  = (feed)? din[447:416] : ( (next)? rW03   : rW02  );
  assign rW03In  = (feed)? din[415:384] : ( (next)? rW04   : rW03  );
  assign rW04In  = (feed)? din[383:352] : ( (next)? rW05   : rW04  );
  assign rW05In  = (feed)? din[351:320] : ( (next)? rW06   : rW05  );
  assign rW06In  = (feed)? din[319:288] : ( (next)? rW07   : rW06  );
  assign rW07In  = (feed)? din[287:256] : ( (next)? rW08   : rW07  );
  assign rW08In  = (feed)? din[255:224] : ( (next)? rW09   : rW08  );
  assign rW09In  = (feed)? din[223:192] : ( (next)? rW010  : rW09  );
  assign rW010In = (feed)? din[191:160] : ( (next)? rW011  : rW010 );
  assign rW011In = (feed)? din[159:128] : ( (next)? rW012  : rW011 );
  assign rW012In = (feed)? din[127: 96] : ( (next)? rW013  : rW012 );
  assign rW013In = (feed)? din[ 95: 64] : ( (next)? rW014  : rW013 );
  assign rW014In = (feed)? din[ 63: 32] : ( (next)? rW015  : rW014 );
  assign rW015In = (feed)? din[ 31:  0] : ( (next)? newOut : rW015 ); 

always @ ( posedge clk or posedge reset )
 begin
   if(reset)
    begin
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
