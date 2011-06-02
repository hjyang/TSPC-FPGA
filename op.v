`timescale 1ns / 1ps

`define INIT_HA 32'h67452301
`define INIT_HB 32'hefcdab89
`define INIT_HC 32'h98badcfe
`define INIT_HD 32'h10325476
`define INIT_HE 32'hc3d2e1f0

module op( clk,
           reset,
           first_chunk,
           feed,
           next,
           msgIn_cnt,
           msgOut_cnt,
           finalStage,
           w0,
           w1,
           w2,
           w3,
           hash,
           ready
         );


  input          clk;
  input          reset;
  input          first_chunk;
  
  input   [3:0]  feed;
  input   [3:0]  next;
  input   [1:0]  msgIn_cnt;
  input   [1:0]  msgOut_cnt;
  input          finalStage;
  
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
         
  reg  [159:0] hash1_w,  hash1_r;
  reg  [159:0] hash2_w,  hash2_r;
  reg  [159:0] hash3_w,  hash3_r;
  reg  [159:0] hash4_w,  hash4_r;
  
  reg          ardy_r,   ardy_w;
  reg          hrdy_r,   hrdy_w;
  reg          feed0;
 
  wire [159:0] hash_init;
  assign hash_init = { `INIT_HA, `INIT_HB, `INIT_HC, `INIT_HD, `INIT_HE };
  
  wire  [31:0] hina;
  wire  [31:0] hinb;
  wire  [31:0] hinc;
  wire  [31:0] hind;
  wire  [31:0] hine;
  
  reg   [31:0] preha;
  reg   [31:0] prehb;
  reg   [31:0] prehc;
  reg   [31:0] prehd;
  reg   [31:0] prehe;

  reg   [31:0] iha;
  reg   [31:0] ihb;
  reg   [31:0] ihc;
  reg   [31:0] ihd;
  reg   [31:0] ihe;
 
  assign hina  = aout + preha;
  assign hinb  = bout + prehb;
  assign hinc  = cout + prehc;
  assign hind  = dout + prehd;
  assign hine  = eout + prehe;
  
  assign hash  = {preha,prehb,prehc,prehd,prehe};
  assign ready = hrdy_r;

always @ (*)
begin
  case( msgOut_cnt )
    2'd0: {preha,prehb,prehc,prehd,prehe} = hash1_r;
    2'd1: {preha,prehb,prehc,prehd,prehe} = hash2_r;
    2'd2: {preha,prehb,prehc,prehd,prehe} = hash3_r;
    2'd3: {preha,prehb,prehc,prehd,prehe} = hash4_r;
  endcase
end

always @ (*)
begin
  case( msgIn_cnt )
    2'd0: {iha,ihb,ihc,ihd,ihe} = hash1_r;
    2'd1: {iha,ihb,ihc,ihd,ihe} = hash2_r;
    2'd2: {iha,ihb,ihc,ihd,ihe} = hash3_r;
    2'd3: {iha,ihb,ihc,ihd,ihe} = hash4_r;
  endcase
end

  
always @ (*)
 begin
   hash1_w = hash1_r;
   hash2_w = hash2_r;
   hash3_w = hash3_r;
   hash4_w = hash4_r;
   ardy_w  = ardy_r;
   hrdy_w  = hrdy_r;
   
   if( feed[0] & first_chunk )  //new start
    begin
      case( msgIn_cnt )
        2'd0: hash1_w = hash_init;
        2'd1: hash2_w = hash_init;
        2'd2: hash3_w = hash_init;
        2'd3: hash4_w = hash_init;
      endcase
    end  

   if(finalStage)
    begin
      ardy_w = 1'b1;
    end
   else
    begin
      if( ardy_r )
       begin
         case( msgOut_cnt )
           2'd0: hash1_w = {hina,hinb,hinc,hind,hine};
           2'd1: hash2_w = {hina,hinb,hinc,hind,hine};
           2'd2: hash3_w = {hina,hinb,hinc,hind,hine};
           2'd3: hash4_w = {hina,hinb,hinc,hind,hine};
         endcase
         ardy_w = 1'b0;
         hrdy_w = 1'b1;
       end
      else
       begin
         hrdy_w = 1'b0;
       end
    end

 end
  
  
op0 block0( .clk(clk),
            .reset(reset),
            .feed(feed0),
            .next(next[0]),
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
          
op1 block1( .clk(clk),
            .reset(reset),
            .feed(feed[1]),
            .next(next[1]),
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
          
op2 block2( .clk(clk),
            .reset(reset),
            .feed(feed[2]),
            .next(next[2]),
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

op3 block3( .clk(clk),
            .reset(reset),
            .feed(feed[3]),
            .next(next[3]|finalStage),
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
      ardy_r   <= 1'b0;
      hrdy_r   <= 1'b0;
      feed0    <= 1'b0;
      hash1_r  <= hash_init;
      hash2_r  <= hash_init;
      hash3_r  <= hash_init;
      hash4_r  <= hash_init;
    end 
   else 
    begin
      ardy_r   <= ardy_w;
      hrdy_r   <= hrdy_w;
      feed0    <= feed[0];
      hash1_r  <= hash1_w;
      hash2_r  <= hash2_w;
      hash3_r  <= hash3_w;
      hash4_r  <= hash4_w;
    end
end

endmodule
