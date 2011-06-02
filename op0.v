`timescale 1ns / 1ps

module op0( clk,
            reset,
            feed,
            next,
            w,
            ia,
            ib,
            ic,
            id,
            ie,
            a,
            b,
            c,
            d,
            e
          );

  input         clk;
  input         reset;
  input         feed;
  input         next;
  
  input  [31:0] w;
  input  [31:0] ia;
  input  [31:0] ib;
  input  [31:0] ic;
  input  [31:0] id;
  input  [31:0] ie;
  
  output [31:0] a;
  output [31:0] b;
  output [31:0] c;
  output [31:0] d;
  output [31:0] e;
  
  
  reg  [31:0] ra;
  reg  [31:0] rb;
  reg  [31:0] rc;
  reg  [31:0] rd;
  reg  [31:0] re;
  wire [31:0] _aIn;
  wire [31:0] _bIn;
  wire [31:0] _cIn;
  wire [31:0] _dIn;
  wire [31:0] _eIn;
  wire [31:0] aIn;
  wire [31:0] bIn;
  wire [31:0] cIn;
  wire [31:0] dIn;
  wire [31:0] eIn;
  
  wire [31:0] aShift;
  wire [31:0] bShift;
  
assign _aIn = (feed)? ia : ra;
assign _bIn = (feed)? ib : rb;
assign _cIn = (feed)? ic : rc;
assign _dIn = (feed)? id : rd;
assign _eIn = (feed)? ie : re;

assign aShift = { _aIn[26:0], _aIn[31:27]};
assign bShift = { _bIn[ 1:0], _bIn[31: 2]};

assign a = w + 32'h5a827999 + _eIn + ((_bIn&_cIn)^(~_bIn&_dIn)) + aShift;
assign b = _aIn;
assign c = bShift;
assign d = _cIn;
assign e = _dIn;

assign aIn = (next)? a : ra;
assign bIn = (next)? b : rb;
assign cIn = (next)? c : rc;
assign dIn = (next)? d : rd;
assign eIn = (next)? e : re;

always @ ( posedge clk or posedge reset ) 
 begin
   if ( reset ) 
    begin
      ra <= 32'd0;
      rb <= 32'd0;
      rc <= 32'd0;
      rd <= 32'd0;
      re <= 32'd0;
    end 
   else
    begin
      ra <= aIn;
      rb <= bIn;
      rc <= cIn;
      rd <= dIn;
      re <= eIn;    	
    end
 end
 
endmodule

