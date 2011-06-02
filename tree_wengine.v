`timescale 1ns / 1ps

module tree_wengine( clk,
                     reset,
                     start,
                     msgIn,
                     blkBusy,
                     blkLastBusy,
                     w0,
                     w1,
                     w2,
                     w3
                   );

  input         clk;
  input         reset;
  input         start;
  input [511:0] msgIn;
  
  input  [3:0]  blkBusy;
  input  [2:0]  blkLastBusy; 
  
  output [31:0] w0;
  output [31:0] w1;
  output [31:0] w2;
  output [31:0] w3;

  wire  [543:0] w0tow1;
  wire  [543:0] w1tow2;
  wire  [543:0] w2tow3;

  wire          stage0;
      
twengine0 tweng0( .clk(clk),
                  .reset(reset),
                  .din(msgIn), 
                  .dout(w0tow1),
                  .stage(stage0),
                  .feed(start & ~blkBusy[0]),
                  .next(blkBusy[0]),
                  .wout(w0)
                );

wengine1 tweng1( .clk(clk),
                .reset(reset),
                .din(w0tow1), 
                .dout(w1tow2),
                .feed(blkLastBusy[0] & ~blkBusy[0]),
                .next(blkBusy[1]),
                .wout(w1)
              );

wengine1 tweng2( .clk(clk),
                .reset(reset),
                .din(w1tow2), 
                .dout(w2tow3),
                .feed(blkLastBusy[1] & ~blkBusy[1]),
                .next(blkBusy[2]),
                .wout(w2)
              );

wengine2 tweng3( .clk(clk),
                .reset(reset),
                .din(w2tow3), 
                .feed(blkLastBusy[2] & ~blkBusy[2]),
                .next(blkBusy[3]),
                .wout(w3)
              );

shifter tcnt_stage0( .clk(clk),
                    .reset(reset),
                    .load(start & ~blkBusy[0]),
                    .val(20'b11111000000000000000),
                    .out(stage0)
                  );
    
    
endmodule

