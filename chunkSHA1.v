`timescale 1ns / 1ps

module chunkSHA1( clk,
                  reset,
                  start,
                  first_chunk,
                  msgIn_cnt,
                  msgOut_cnt,
                  msg,
                  hash_out,
                  ready,
                  busy
                );

  input          clk;
  input          reset;
  input          start;
  input          first_chunk;
  input    [1:0] msgIn_cnt;
  input    [1:0] msgOut_cnt; 
  input  [511:0] msg;
  output [159:0] hash_out;
  output         ready;
  output         busy;

  wire   [31:0]  w0;
  wire   [31:0]  w1;
  wire   [31:0]  w2;
  wire   [31:0]  w3;
  
  wire           busy0;
  wire           busy1;
  wire           busy2;
  wire           busy3; 
  wire           final_stage;
  
  reg            lastBusy0;
  reg            lastBusy1;
  reg            lastBusy2;
  reg            lastBusy3;

  reg     [3:0]  to_feed_w,  to_feed_r;
  reg     [3:0]  blkFeed;
  
assign busy        = busy0; 
assign final_stage = lastBusy3 & ~busy3;

always @ ( posedge clk or posedge reset)
 begin
   if(reset)
    begin
      lastBusy0 <= 1'b0;
      lastBusy1 <= 1'b0;
      lastBusy2 <= 1'b0;
      lastBusy3 <= 1'b0;
      to_feed_r <= 4'd0;
    end
   else
    begin
      lastBusy0 <= busy0;
      lastBusy1 <= busy1;
      lastBusy2 <= busy2;
      lastBusy3 <= busy3;
      to_feed_r <= to_feed_w;      
    end
 end


always @ (*)
 begin
   if(final_stage)
    begin
      to_feed_w[0] = (  start    & ~busy0 )? 1'b1 :  to_feed_r[0];
      to_feed_w[1] = ( lastBusy0 & ~busy0 )? 1'b1 :  to_feed_r[1];
      to_feed_w[2] = ( lastBusy1 & ~busy1 )? 1'b1 :  to_feed_r[2];
      to_feed_w[3] = ( lastBusy2 & ~busy2 )? 1'b1 :  to_feed_r[3];
      blkFeed[3:0] = 4'd0; 
    end
   else
    begin
      to_feed_w[3:0] = 4'd0;
      blkFeed[0] = (  start    & ~busy0 )? 1'b1 :  to_feed_r[0];      
      blkFeed[1] = ( lastBusy0 & ~busy0 )? 1'b1 :  to_feed_r[1];
      blkFeed[2] = ( lastBusy1 & ~busy1 )? 1'b1 :  to_feed_r[2];
      blkFeed[3] = ( lastBusy2 & ~busy2 )? 1'b1 :  to_feed_r[3]; 
    end
 end

 
op opBlock( .clk( clk ),
            .reset( reset ),
            .first_chunk( first_chunk ),
            .feed( blkFeed ),
            .next( {busy3, busy2, busy1, busy0} ),
            .msgIn_cnt( msgIn_cnt ),
            .msgOut_cnt( msgOut_cnt ),
            .finalStage( final_stage ),            
            .w0( w0 ),
            .w1( w1 ),
            .w2( w2 ),
            .w3( w3 ),            
            .ready( ready ),
            .hash( hash_out )
          );

wengine wpBlock( .clk( clk ),
                 .reset( reset ),
                 .msgIn( msg ),
                 .feed( blkFeed ),
                 .next( {busy3, busy2, busy1, busy0} ),                 
                 .w0( w0 ),
                 .w1( w1 ),
                 .w2( w2 ),
                 .w3( w3 )                 
               );

shifter cnt_busy0 ( .clk(clk),
                    .reset(reset),
                    .load(blkFeed[0]),
                    .val(20'b01111111111111111111),
                    .out(busy0)
                  );

shifter cnt_busy1( .clk(clk),
                   .reset(reset),
                   .val(20'b01111111111111111111),
                   .load(blkFeed[1]),
                   .out(busy1)
                 );

shifter cnt_busy2( .clk(clk),
                   .reset(reset),
                   .val(20'b01111111111111111111),
                   .load(blkFeed[2]),
                   .out(busy2)
                 );

shifter cnt_busy3( .clk(clk),
                   .reset(reset),
                   .val(20'b01111111111111111111),
                   .load(blkFeed[3]),
                   .out(busy3)
                 );

endmodule
