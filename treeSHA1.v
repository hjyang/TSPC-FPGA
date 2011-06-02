`timescale 1ns / 1ps

module treeSHA1( clk,
                 start,
                 reset,
                 msg,
                 hash,
                 ready,
                 busy
               );

  input          clk;
  input          start;
  input  [511:0] msg;
  input          reset;
  output [159:0] hash;
  output         ready;
  output         busy;

  wire   [31:0]  init_ha;
  wire   [31:0]  init_hb;
  wire   [31:0]  init_hc;
  wire   [31:0]  init_hd;
  wire   [31:0]  init_he;
  
  wire   [31:0]  w0;
  wire   [31:0]  w1;
  wire   [31:0]  w2;
  wire   [31:0]  w3;
  
  wire           busy0;
  wire           busy1;
  wire           busy2;
  wire           busy3; 
  
  reg            lastBusy0;
  reg            lastBusy1;
  reg            lastBusy2;
  reg            lastBusy3;

  
assign init_ha = 32'h67452301;
assign init_hb = 32'hefcdab89;
assign init_hc = 32'h98badcfe;
assign init_hd = 32'h10325476;
assign init_he = 32'hc3d2e1f0;
  

assign busy = busy0; 

always @ ( posedge clk or posedge reset)
 begin
   if(reset)
    begin
      lastBusy0 <= 1'b0;
      lastBusy1 <= 1'b0;
      lastBusy2 <= 1'b0;
      lastBusy3 <= 1'b0;
    end
   else
    begin
      lastBusy0 <= busy0;
      lastBusy1 <= busy1;
      lastBusy2 <= busy2;
      lastBusy3 <= busy3;   
    end
 end
  
tree_op tree_opBlock( .clk( clk ),
                      .reset( reset ),
                      .start( start ),
                      .blkBusy( {busy3, busy2, busy1, busy0} ),
                      .blkLastBusy( {lastBusy3, lastBusy2, lastBusy1, lastBusy0} ),            
                      .iha( init_ha ),
                      .ihb( init_hb ),
                      .ihc( init_hc ),
                      .ihd( init_hd ),
                      .ihe( init_he ),
                      .w0( w0 ),
                      .w1( w1 ),
                      .w2( w2 ),
                      .w3( w3 ),            
                      .ready( ready ),
                      .hash( hash )
                    );

tree_wengine twpBlock( .clk( clk ),
                       .reset( reset ),
                       .start( start ),
                       .msgIn( msg ),
                       .blkBusy( {busy3, busy2, busy1, busy0} ),
                       .blkLastBusy( {lastBusy2, lastBusy1, lastBusy0} ),
                       .w0( w0 ),
                       .w1( w1 ),
                       .w2( w2 ),
                       .w3( w3 )                 
                     );

shifter tcnt_busy0 ( .clk(clk),
                     .reset(reset),
                     .load(start & ~busy0),
                     .val(20'b01111111111111111111),
                     .out(busy0)
                   );

shifter tcnt_busy1( .clk(clk),
                    .reset(reset),
                    .val(20'b01111111111111111111),
                    .load(lastBusy0 & ~busy0),
                    .out(busy1)
                  );

shifter tcnt_busy2( .clk(clk),
                    .reset(reset),
                    .val(20'b01111111111111111111),
                    .load(lastBusy1 & ~busy1),
                    .out(busy2)
                  );

shifter tcnt_busy3( .clk(clk),
                    .reset(reset),
                    .val(20'b01111111111111111111),
                    .load(lastBusy2 & ~busy2),
                    .out(busy3)
                  );

endmodule
