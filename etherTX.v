`timescale 1ns / 1ps

//Ethernet Transmiter

//state definition for transmiter
`define T_IDLE        3'd0
`define T_FIRST_SEND  3'd1
`define T_DST_ADDR    3'd2
`define T_SRC_ADDR    3'd3
`define T_LEN_TYPE    3'd4
`define T_DATA        3'd5

module etherTX( ethTXclock,
                reset,
                frameInfoLoad,
                srcMacAddr,
                dstMacAddr,
                etherType,
                txFifoOut,
                txFifoEmpty,
                txRdEn,
                tcFifoOut,
                tcFifoEmpty,
                tcRdEn,
                tfFifoOut,
                tfFifoEmpty,
                tfRdEn,
                TXack,
                TXdata,
                TXdataValid
              );

  input         ethTXclock;
  input         reset;
  
  //frame info
  input         frameInfoLoad;
  input  [47:0] srcMacAddr;
  input  [47:0] dstMacAddr;
  input  [15:0] etherType;

  //transmitter data FIFO
  input   [7:0] txFifoOut;
  input         txFifoEmpty;
  output        txRdEn;

  //transmitter data FIFO from cache tree
  input   [7:0] tcFifoOut;
  input         tcFifoEmpty;
  output        tcRdEn;  

  //transmitter frame info FIFO
  input  [11:0] tfFifoOut;
  input         tfFifoEmpty;
  output        tfRdEn;
  
  //data to/from MAC
  input         TXack;
  output  [7:0] TXdata;
  output        TXdataValid;
  
  //states and counters
  reg  [2:0]  t_current_state,  t_next_state;
  
  //transmitter data FIFO
  reg         txRdEn_w,         txRdEn_r;

  //transmitter data FIFO
  reg         tcRdEn_w,         tcRdEn_r;
  
  //transmitter frame info FIFO
  reg         tfRdEn_w,         tfRdEn_r;
  
  //data to MAC
  reg   [7:0] TXdata_w,         TXdata_r;
  reg         TXdataValid_w,    TXdataValid_r;
  
  reg  [10:0] byteToSend_w,     byteToSend_r;
  reg  [3:0]  addr_cnt_w,       addr_cnt_r;
  reg  [47:0] srcMacAddr_w,     srcMacAddr_r;
  reg  [47:0] dstMacAddr_w,     dstMacAddr_r;
  reg  [15:0] etherType_w,      etherType_r;
  reg         is_tree_w,        is_tree_r;
  
  assign txRdEn      = txRdEn_r;
  assign tfRdEn      = tfRdEn_r;
  assign tcRdEn      = tcRdEn_r;
  assign TXdata      = TXdata_r;
  assign TXdataValid = TXdataValid_r;
  
  
//transmiter state transition
always @ (*)
begin
  t_next_state  = t_current_state;
  byteToSend_w  = byteToSend_r;
  addr_cnt_w    = addr_cnt_r;
  TXdata_w      = TXdata_r;
  TXdataValid_w = TXdataValid_r;
  tfRdEn_w      = 1'b0;
  is_tree_w     = is_tree_r;
  
 case(t_current_state)
    `T_IDLE:
      begin
        addr_cnt_w = 4'd0;
        if(!tfFifoEmpty)
         begin
           t_next_state  = `T_FIRST_SEND;
           TXdataValid_w = 1'b1;
           TXdata_w      = dstMacAddr_w[47:40];           
         end
      end
    `T_FIRST_SEND:
      begin
        if(TXack)
         begin
           t_next_state = `T_DST_ADDR;
           TXdata_w     = dstMacAddr_w[39:32];
           addr_cnt_w   = 4'd1;
         end
      end
    `T_DST_ADDR:
      begin
        addr_cnt_w   = addr_cnt_r + 1'b1;
        TXdata_w     = dstMacAddr_r[31:24];
        if( addr_cnt_r == 4'd3 )
         begin
           tfRdEn_w = 1'b1;
         end
        else if( addr_cnt_r == 4'd5 )
         begin
           t_next_state = `T_SRC_ADDR;
           TXdata_w     = srcMacAddr_r[47:40];
           byteToSend_w = tfFifoOut[10:0];
           is_tree_w    = !tfFifoOut[11];
         end
      end
    `T_SRC_ADDR:
      begin
        addr_cnt_w   = addr_cnt_r + 1'b1;
        TXdata_w     = srcMacAddr_r[47:40];
        if( addr_cnt_r == 4'd11 )
         begin
           t_next_state  = `T_LEN_TYPE;
           TXdata_w      = etherType_r[15:8];
         end
      end
    `T_LEN_TYPE:
      begin
        addr_cnt_w   = addr_cnt_r + 1'b1;
        TXdata_w     = etherType_r[7:0];
        if( addr_cnt_r == 4'd13 )
         begin
           t_next_state  = `T_DATA;
           addr_cnt_w    = 4'd0;
           if(is_tree_r)
             TXdata_w      = tcFifoOut;
           else
             TXdata_w      = txFifoOut;
         end
      end
    `T_DATA:
      begin
        byteToSend_w = byteToSend_r - 1'b1;
        if(is_tree_r)
          TXdata_w   = tcFifoOut;
        else
          TXdata_w   = txFifoOut;
        if( byteToSend_r == 11'd1 )
         begin
           TXdataValid_w = 1'b0;
           t_next_state = `T_IDLE;
         end
      end
    default:;
  endcase
end

//read transmitter data FIFO
always @ (*)
begin
  txRdEn_w  = txRdEn_r;
  tcRdEn_w  = tcRdEn_r;
  if( ( t_current_state == `T_SRC_ADDR ) && ( addr_cnt_r == 4'd11 ) )
   begin
     if(is_tree_r)
       tcRdEn_w = 1'b1;
     else
       txRdEn_w = 1'b1;
   end
  else if( ( t_current_state == `T_DATA ) && ( byteToSend_r == 11'd3 ) )
   begin
     tcRdEn_w = 1'b0;
     txRdEn_w = 1'b0;
   end
end
  
 
//store and output source and destination address
always @ (*)
begin
  srcMacAddr_w = srcMacAddr_r;
  dstMacAddr_w = dstMacAddr_r;
  etherType_w  = etherType_r; 
  case( t_current_state )
    `T_IDLE:
      begin
        if(frameInfoLoad)
         begin
           srcMacAddr_w = dstMacAddr;
           dstMacAddr_w = srcMacAddr;
           etherType_w  = etherType;
         end
      end
    `T_DST_ADDR:
      begin
        dstMacAddr_w = { dstMacAddr_r[39:0], dstMacAddr_r[47:40] };
        if( addr_cnt_r == 4'd5 )
         begin
           srcMacAddr_w = { srcMacAddr_r[39:0], srcMacAddr_r[47:40] };
         end
      end
    `T_SRC_ADDR:
      begin
        if( addr_cnt_r == 4'd6 )
         begin
           dstMacAddr_w = { dstMacAddr_r[39:0], dstMacAddr_r[47:40] };
         end
        if( addr_cnt_r < 4'd11 )
         begin
           srcMacAddr_w = { srcMacAddr_r[39:0], srcMacAddr_r[47:40] };
         end
      end
    default:;
  endcase
end

  
  
always @ ( posedge ethTXclock or posedge reset )
 begin
   if(reset)
    begin
      t_current_state <= `T_IDLE;
      txRdEn_r        <= 1'b0;
      tcRdEn_r        <= 1'b0;
      tfRdEn_r        <= 1'b0;
      byteToSend_r    <= 11'd0;
      addr_cnt_r      <= 4'd0;
      srcMacAddr_r    <= 48'd0;
      dstMacAddr_r    <= 48'd0;
      etherType_r     <= 16'd0;
      TXdata_r        <= 8'd0;
      TXdataValid_r   <= 1'b0;
      is_tree_r       <= 1'b0;
    end
   else
    begin
      t_current_state <= t_next_state;
      txRdEn_r        <= txRdEn_w;
      tcRdEn_r        <= tcRdEn_w;
      tfRdEn_r        <= tfRdEn_w;
      byteToSend_r    <= byteToSend_w;
      addr_cnt_r      <= addr_cnt_w;
      srcMacAddr_r    <= srcMacAddr_w;
      dstMacAddr_r    <= dstMacAddr_w;
      etherType_r     <= etherType_w;
      TXdata_r        <= TXdata_w;
      TXdataValid_r   <= TXdataValid_w;
      is_tree_r       <= is_tree_w;
    end
 end


endmodule
