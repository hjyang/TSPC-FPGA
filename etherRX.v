`timescale 1ns / 1ps

//Ethernet Receiver

//state definition for receiver
`define R_IDLE        3'd0
`define R_DST_ADDR    3'd1
`define R_SRC_ADDR    3'd2
`define R_LEN_TYPE    3'd3
`define R_DATA        3'd4
`define R_FAIL        3'd5

`define FPGA_ADDR     48'h001122334455
`define ETHER_TYPE    16'h88B5

`define SHA1_INIT     8'haa
`define SHA1_FINAL    8'hcc

//////////////////////////definition for tree cache control/////////////////////////////////////////////////////////////////

//definition for instructions
`define TC_LOAD       8'd0
`define TC_VERIFY1    8'd1
`define TC_VERIFY2    8'd2
`define TC_VERIFY3    8'd3
`define TC_VERIFY4    8'd4
`define TC_LOAD_RT    8'd5
`define TC_HMAC       8'd6
`define TC_UPDATE1    8'd7
`define TC_UPDATE2    8'd8
`define TC_UPDATE3    8'd9
`define TC_UPDATE4    8'd10


//definition for length of variables
`define LOAD_CYCLE_L       7  //load inst.      cur_entry(16), par_entry(16), nodeid(24), hash(160), dummy(8) 
`define LOAD_CYCLE_V1      2  //verify inst.    right_entry(16), left_entry(16), par_entry(16)
`define LOAD_CYCLE_V2      3  //                2{right_entry(16), left_entry(16), par_entry(16)}
`define LOAD_CYCLE_V3      5  //                3{right_entry(16), left_entry(16), par_entry(16)}
`define LOAD_CYCLE_V4      6  //                4{right_entry(16), left_entry(16), par_entry(16)}
`define LOAD_CYCLE_RT      5  //load root inst. hash(160)
`define LOAD_CYCLE_HMAC    9  //HMAC inst.      entry(16), section key(128), nonce(128), dummy(16)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

module etherRX( clientRXclock,
                reset,
                dataFifoFull,
                dataFifoIn,
                dataWrEn,
                instFifoFull,
                instFifoIn,
                instWrEn,
                itpFifoFull,
                itpFifoIn,
                itpWrEn,
                RXdata,
                RXdataValid,
                RXgoodFrame,
                RXbadFrame,
                frameInfoLoad,
                srcMacAddr,
                dstMacAddr,
                etherType,
                firstFrame,
                lastFrame,
                rPackCnt
              );

  input          clientRXclock;
  input          reset;

  //data FIFO
  input          dataFifoFull;
  output  [31:0] dataFifoIn;
  output         dataWrEn;

  //inst FIFO
  input          instFifoFull;
  output  [31:0] instFifoIn;
  output         instWrEn;

  //inst type FIFO
  input          itpFifoFull;
  output  [ 7:0] itpFifoIn;
  output         itpWrEn;

  // MAC signals
  input   [7:0]  RXdata;          //received data from MAC
  input          RXdataValid;     //received data valid
  input          RXgoodFrame;
  input          RXbadFrame;

  output         frameInfoLoad;
  output [47:0]  srcMacAddr;
  output [47:0]  dstMacAddr;
  output [15:0]  etherType;
  output         firstFrame;
  output         lastFrame;
  output  [7:0]  rPackCnt;

  //states and counters
  reg  [2:0]  r_current_state,  r_next_state;
  reg  [3:0]  r_byte_cnt_w,     r_byte_cnt_r;
  reg  [7:0]  r_pack_cnt_w,     r_pack_cnt_r;
  reg  [7:0]  r_inst_bnd_w,     r_inst_bnd_r;
  reg  [7:0]  r_inst_cnt_w,     r_inst_cnt_r;
  reg         r_update_load_w,  r_update_load_r;
  
  
  //FIFOs
  reg         dataWrEn_w,       dataWrEn_r;
  reg         instWrEn_w,       instWrEn_r;
  reg         itpWrEn_w,        itpWrEn_r;
  reg  [31:0] rdata_w,          rdata_r;
  reg   [7:0] inst_type_r;
  reg         is_tree_w,        is_tree_r;
  
  
  //frame info  
  reg         f_info_load_w,    f_info_load_r;
  reg  [47:0] srcMacAddr_w,     srcMacAddr_r;
  reg  [47:0] dstMacAddr_w,     dstMacAddr_r;
  reg  [15:0] etherType_w,      etherType_r;
 
  //sha1 frame type
  reg         is_first_w,       is_first_r;
  reg         is_last_w,        is_last_r;
 
  assign rPackCnt      = r_pack_cnt_r;
  assign dataFifoIn    = rdata_r;
  assign dataWrEn      = dataWrEn_r;
  assign instFifoIn    = rdata_r;
  assign instWrEn      = instWrEn_r;
  assign itpFifoIn     = inst_type_r;
  assign itpWrEn       = itpWrEn_r;

  assign frameInfoLoad = f_info_load_r;
  assign srcMacAddr    = srcMacAddr_r;
  assign dstMacAddr    = dstMacAddr_r;
  assign etherType     = etherType_r;
  assign firstFrame    = is_first_r;
  assign lastFrame     = is_last_r;

//receiver state transition
always @ (*)
 begin
   r_next_state    = r_current_state;
   r_byte_cnt_w    = r_byte_cnt_r;
   r_pack_cnt_w    = r_pack_cnt_r;
   srcMacAddr_w    = srcMacAddr_r;
   dstMacAddr_w    = dstMacAddr_r;
   etherType_w     = etherType_r;
   is_first_w      = is_first_r;
   is_last_w       = is_last_r;
   rdata_w         = rdata_r;
   f_info_load_w   = f_info_load_r;
   is_tree_w       = is_tree_r;
   itpWrEn_w       = 1'b0;
   r_inst_bnd_w    = r_inst_bnd_r;
   r_update_load_w = r_update_load_r;
   
   if( RXdataValid )
    begin
      if( dataFifoFull | instFifoFull )
        r_next_state = `R_FAIL;
      else
        r_byte_cnt_w = r_byte_cnt_r + 1'b1;
    end
   else if( RXgoodFrame | RXbadFrame ) // end of the frame
    begin
      r_next_state = `R_IDLE;
      case(r_byte_cnt_r[1:0])
        2'd0: rdata_w = rdata_r;
        2'd1: rdata_w = {rdata_r[ 7:0], 24'd0};
        2'd2: rdata_w = {rdata_r[15:0], 16'd0};
        2'd3: rdata_w = {rdata_r[23:0],  8'd0};
      endcase
    end
   case( r_current_state )
     `R_IDLE: 
       begin
         r_byte_cnt_w  = 4'd0;
         is_first_w    = 1'b0;
         is_last_w     = 1'b0;
         f_info_load_w = 1'b0;
         if(RXdataValid)
          begin
            r_byte_cnt_w = r_byte_cnt_r + 1'b1;
            r_next_state = `R_DST_ADDR;
            dstMacAddr_w = { dstMacAddr_r[39:0], RXdata };
          end
       end
     `R_DST_ADDR:
       begin
         if( r_byte_cnt_r == 4'd6 )
          begin
            if( dstMacAddr_r != `FPGA_ADDR )
             begin
               r_next_state = `R_FAIL;
               r_byte_cnt_w = 4'd0;
             end
            else
             begin
               r_next_state = `R_SRC_ADDR;
               srcMacAddr_w = { srcMacAddr_r[39:0], RXdata };
             end
          end
         else //r_byte_cnt_r <4'd6
          begin
            dstMacAddr_w = { dstMacAddr_r[39:0], RXdata };
          end
       end
     `R_SRC_ADDR:
       begin
         if( r_byte_cnt_r == 4'd12 )
          begin
            r_next_state = `R_LEN_TYPE;
            etherType_w  = { etherType_r[7:0], RXdata };
          end
         else //r_byte_cnt_r <4'd12
          begin
            srcMacAddr_w = { srcMacAddr_r[39:0], RXdata };
          end
       end
     `R_LEN_TYPE:
       begin
         if( r_byte_cnt_r == 4'd14 )
          begin
            r_byte_cnt_w  = 11'd0;
            if( etherType_r == `ETHER_TYPE )
             begin
               r_next_state  = `R_DATA;
               r_pack_cnt_w  = r_pack_cnt_r + 1'b1;
               r_byte_cnt_w  = 4'd0;
               f_info_load_w = 1'b1;
               if( RXdata[7] == 1'b1 )   //for hash data blocks
                begin
                  is_tree_w = 1'b0;
                  if( RXdata == `SHA1_INIT )
                    is_first_w = 1'b1;
                  else if( RXdata == `SHA1_FINAL )
                    is_last_w  = 1'b1;
                end
               else  //for tree cache commands
                begin
                  is_tree_w = 1'b1;
                  itpWrEn_w = 1'b1;
                  case( RXdata )
                   `TC_LOAD   : r_inst_bnd_w    = `LOAD_CYCLE_L;   
                   `TC_VERIFY1: r_inst_bnd_w    = `LOAD_CYCLE_V1;
                   `TC_VERIFY2: r_inst_bnd_w    = `LOAD_CYCLE_V2;
                   `TC_VERIFY3: r_inst_bnd_w    = `LOAD_CYCLE_V3;
                   `TC_VERIFY4: r_inst_bnd_w    = `LOAD_CYCLE_V4;
                   `TC_LOAD_RT: r_inst_bnd_w    = `LOAD_CYCLE_RT;
                   `TC_HMAC:    r_inst_bnd_w    = `LOAD_CYCLE_HMAC;
                   `TC_UPDATE1: r_update_load_w = 1'b1;
                   `TC_UPDATE2: r_update_load_w = 1'b1;
                   `TC_UPDATE3: r_update_load_w = 1'b1;
                   `TC_UPDATE4: r_update_load_w = 1'b1;
                   default:;
                  endcase
                end
             end
            else
             begin
               r_next_state = `R_FAIL;
             end             
          end
         else
          begin
            etherType_w  = { etherType_r[7:0], RXdata };
          end
       end
     `R_FAIL:
       begin
         r_byte_cnt_w = 4'd0;
       end
     `R_DATA:
       begin
         if( RXdataValid )
          begin
            rdata_w = { rdata_r[23:0], RXdata };
            if( r_update_load_r )
             begin
               r_update_load_w = 1'b0;
               r_inst_bnd_w    = RXdata;
             end
          end
       end
     default:;
    endcase
  end
  
//write data & inst fifo
always @ (*)
 begin
   dataWrEn_w   = 1'b0;
   instWrEn_w   = 1'b0;
   r_inst_cnt_w = r_inst_cnt_r;
   
   if( dataFifoFull == 1'b0 && r_current_state == `R_DATA && RXdataValid == 1'b1 )
    begin
      if( r_byte_cnt_r[1:0] == 2'd3 )
       begin
         if(is_tree_r)
          begin
            if( r_inst_cnt_r < r_inst_bnd_r )
             begin
               r_inst_cnt_w = r_inst_cnt_r + 1'b1;     
               instWrEn_w   = 1'b1; 
             end
          end
         else
          begin
            dataWrEn_w = 1'b1;
          end
       end
    end
   else if( RXgoodFrame | RXbadFrame )
    begin
      r_inst_cnt_w = 4'd0;
      if( r_byte_cnt_r[1:0] != 2'd0 )
       begin
         if(is_tree_r)
          begin
            if( r_inst_cnt_r < r_inst_bnd_r )
             begin
               instWrEn_w   = 1'b1; 
             end
          end
         else
          begin
            dataWrEn_w = 1'b1;
          end       
       end
    end
 end

always @ ( posedge clientRXclock or posedge reset )
 begin
   if(reset)
    begin
      r_current_state <= `R_IDLE;
      dataWrEn_r      <= 1'b0;
      instWrEn_r      <= 1'b0;
      itpWrEn_r       <= 1'b0;
      r_byte_cnt_r    <= 4'd0;
      rdata_r         <= 32'd0;
      inst_type_r     <= 8'd0;
      r_pack_cnt_r    <= 8'd0;
      f_info_load_r   <= 1'b0;
      srcMacAddr_r    <= 48'd0;
      dstMacAddr_r    <= 48'd0;
      etherType_r     <= 16'd0;
      is_first_r      <= 1'b0;
      is_last_r       <= 1'b0;
      is_tree_r       <= 1'b0;
      r_inst_bnd_r    <= 4'd0;
      r_inst_cnt_r    <= 4'd0;
      r_update_load_r <= 1'b0;
    end
   else
    begin
      r_current_state <= r_next_state;
      dataWrEn_r      <= dataWrEn_w;
      instWrEn_r      <= instWrEn_w;
      itpWrEn_r       <= itpWrEn_w;
      r_byte_cnt_r    <= r_byte_cnt_w;
      rdata_r         <= rdata_w;
      inst_type_r     <= RXdata;
      r_pack_cnt_r    <= r_pack_cnt_w;
      f_info_load_r   <= f_info_load_w;
      srcMacAddr_r    <= srcMacAddr_w;
      dstMacAddr_r    <= dstMacAddr_w;
      etherType_r     <= etherType_w;
      is_first_r      <= is_first_w;
      is_last_r       <= is_last_w;
      is_tree_r       <= is_tree_w;
      r_inst_bnd_r    <= r_inst_bnd_w;
      r_inst_cnt_r    <= r_inst_cnt_w;
      r_update_load_r <= r_update_load_w;
    end
 end
 
endmodule
