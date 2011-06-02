`timescale 1ns / 1ps

module top3( clk,    
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

assign aShift = { ra[26:0], ra[31:27] };
assign bShift = { rb[ 1:0], rb[31: 2] };

assign _aIn = w+32'hca62c1d6+re+(rb^rd^rc)+aShift;
assign _bIn = ra;
assign _cIn = bShift;
assign _dIn = rc;
assign _eIn = rd;

assign aIn = (feed)? ia : ( (next)? _aIn : ra );
assign bIn = (feed)? ib : ( (next)? _bIn : rb );
assign cIn = (feed)? ic : ( (next)? _cIn : rc );
assign dIn = (feed)? id : ( (next)? _dIn : rd );
assign eIn = (feed)? ie : ( (next)? _eIn : re );

assign a = _aIn;
assign b = _bIn;
assign c = _cIn;
assign d = _dIn;
assign e = _eIn;

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



