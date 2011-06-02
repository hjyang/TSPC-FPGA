`timescale 1ns / 1ps

module wengine( clk,
                reset,
                msgIn,
                feed,
                next,
                w0,
                w1,
                w2,
                w3
              );

  input         clk;
  input         reset;

  input [511:0] msgIn;
  
  input   [3:0] feed;
  input   [3:0] next; 
  
  output [31:0] w0;
  output [31:0] w1;
  output [31:0] w2;
  output [31:0] w3;

  wire  [543:0] w0tow1;
  wire  [543:0] w1tow2;
  wire  [543:0] w2tow3;

  wire          stage0;
      
wengine0 weng0( .clk(clk),
                .reset(reset),
                .din(msgIn), 
                .dout(w0tow1),
                .stage(stage0),
                .feed(feed[0]),
                .next(next[0]),
                .wout(w0)
              );

wengine1 weng1( .clk(clk),
                .reset(reset),
                .din(w0tow1), 
                .dout(w1tow2),
                .feed(feed[1]),
                .next(next[1]),
                .wout(w1)
              );

wengine1 weng2( .clk(clk),
                .reset(reset),
                .din(w1tow2), 
                .dout(w2tow3),
                .feed(feed[2]),
                .next(next[2]),
                .wout(w2)
              );

wengine2 weng3( .clk(clk),
                .reset(reset),
                .din(w2tow3), 
                .feed(feed[3]),
                .next(next[3]),
                .wout(w3)
              );

shifter cnt_stage0( .clk(clk),
                    .reset(reset),
                    .load(feed[0]),
                    .val(20'b11111000000000000000),
                    .out(stage0)
                  );
    
    
endmodule

