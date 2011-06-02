`timescale 1ns / 1ps

module shifter( clk,
                reset,
                load,
                val,
                out
              );

input        clk;
input        reset;
input        load;
input [19:0] val;
output       out;

wire  [19:0] shiftregIn;
reg   [19:0] shiftreg;

assign out        = shiftreg[0];
assign shiftregIn = (load)? val : { 1'b0, shiftreg[19:1]};

always @ (posedge clk or posedge reset) 
 begin
   if( reset )
     shiftreg <= 20'd0;
   else 
     shiftreg <= shiftregIn;
 end

endmodule

