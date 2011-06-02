`timescale 1ns / 1ps

module tree_op( clk,
                reset,
                start,
                blkBusy,
                blkLastBusy,
                iha,
                ihb,
                ihc,
                ihd,
                ihe,
                w0,
                w1,
                w2,
                w3,
                hash,
                ready
              );


  input          clk;
  input          reset;
  input          start;
  
  input   [3:0]  blkBusy;
  input   [3:0]  blkLastBusy; 
  
  input   [31:0] iha;
  input   [31:0] ihb;
  input   [31:0] ihc;
  input   [31:0] ihd;
  input   [31:0] ihe;
  
  input   [31:0] w0;
  input   [31:0] w1;
  input   [31:0] w2;
  input   [31:0] w3;
  
  output [159:0] hash;
  output         ready;
  
  
  wire  [31:0] a0to1;
  wire  [31:0] a1to2;
  wire  [31:0] a2to3;
  wire  [31:0] b0to1;
  wire  [31:0] b1to2;
  wire  [31:0] b2to3;
  wire  [31:0] c0to1;
  wire  [31:0] c1to2;
  wire  [31:0] c2to3;
  wire  [31:0] d0to1;
  wire  [31:0] d1to2;
  wire  [31:0] d2to3;
  wire  [31:0] e0to1;
  wire  [31:0] e1to2;
  wire  [31:0] e2to3;
        
  wire  [31:0] aout;
  wire  [31:0] bout;
  wire  [31:0] cout;
  wire  [31:0] dout;
  wire  [31:0] eout;
        
  wire  [31:0] hina;
  wire  [31:0] hinb;
  wire  [31:0] hinc;
  wire  [31:0] hind;
  wire  [31:0] hine;
  
  reg  [159:0] hash_r,  hash_w;
  reg          ardy_r,  ardy_w;
  reg          hrdy_r,  hrdy_w;
  reg          feed0;
 
  assign hina  = hash_r[159:128] + iha;
  assign hinb  = hash_r[127: 96] + ihb;
  assign hinc  = hash_r[ 95: 64] + ihc;
  assign hind  = hash_r[ 63: 32] + ihd;
  assign hine  = hash_r[ 31:  0] + ihe;
  
  assign hash  = hash_r;
  assign ready = hrdy_r;


always @ (*)
 begin
   hash_w = hash_r;
   ardy_w = ardy_r;
   hrdy_w = hrdy_r;  
   if(blkLastBusy[3] & ~blkBusy[3])
    begin
      hash_w = {aout,bout,cout,dout,eout};
      ardy_w = 1'b1;
    end
   else
    begin
      if( ardy_r )
       begin
         hash_w = {hina,hinb,hinc,hind,hine};
         ardy_w = 1'b0;
         hrdy_w = 1'b1;
       end
      else
       begin
         hrdy_w = 1'b0;
       end
    end
 end
  
  
op0 tblock0( .clk(clk),
             .reset(reset),
             .feed(feed0),
             .next(blkBusy[0]),
             .w(w0),
             .ia(iha),
             .ib(ihb),
             .ic(ihc),
             .id(ihd),
             .ie(ihe),
             .a(a0to1),
             .b(b0to1),
             .c(c0to1),
             .d(d0to1),
             .e(e0to1)
           );
          
op1 tblock1( .clk(clk),
             .reset(reset),
             .feed(blkLastBusy[0] & ~blkBusy[0]),
             .next(blkBusy[1]),
             .w(w1),
             .ia(a0to1),
             .ib(b0to1),
             .ic(c0to1),
             .id(d0to1),
             .ie(e0to1),
             .a(a1to2),
             .b(b1to2),
             .c(c1to2),
             .d(d1to2),
             .e(e1to2)
           );
          
op2 tblock2( .clk(clk),
             .reset(reset),
             .feed(blkLastBusy[1] & ~blkBusy[1]),
             .next(blkBusy[2]),
             .w(w2),
             .ia(a1to2),
             .ib(b1to2),
             .ic(c1to2),
             .id(d1to2),
             .ie(e1to2),
             .a(a2to3),
             .b(b2to3),
             .c(c2to3),
             .d(d2to3),
             .e(e2to3)
           );

top3 tblock3( .clk(clk),
              .reset(reset),
              .feed(blkLastBusy[2] & ~blkBusy[2]),
              .next(blkBusy[3]),
              .w(w3),
              .ia(a2to3),
              .ib(b2to3),
              .ic(c2to3),
              .id(d2to3),
              .ie(e2to3),
              .a(aout),
              .b(bout),
              .c(cout),
              .d(dout),
              .e(eout)
            );    

    
always @ ( posedge clk or posedge reset )
 begin
   if ( reset )
    begin
      ardy_r  <= 1'b0;
      hrdy_r  <= 1'b0;
      feed0   <= 1'b0;
      hash_r  <= 160'd0;
    end 
   else 
    begin
      ardy_r  <= ardy_w;
      hrdy_r  <= hrdy_w;
      feed0   <= start & ~blkBusy[0];
      hash_r  <= hash_w;
    end
end

endmodule
