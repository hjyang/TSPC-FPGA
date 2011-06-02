`timescale 1ns / 1ps

`define HASH_IDLE   3'd0
`define HASH_INIT   3'd1
`define HASH_MID    3'd2
`define HASH_LAST5  3'd3
`define HASH_FINAL  3'd4

`define FIFO_IDLE   1'b0
`define FIFO_READ   1'b1

module hashGen( clk,
                reset,
                firstFrame,
                lastFrame,
                dataIn,
                dataFifoEmpty,
                dataFifoValid,
                dataRdEn,
                hashValueOut,
                hashWrEn,
                hashFifoFull,
                txStart,
                txByteTotal
              );
                 
  input         clk; 
  input         reset;
  input         firstFrame;
  input         lastFrame;
  input  [31:0] dataIn;
  input         dataFifoEmpty;
  input         dataFifoValid;
  input         hashFifoFull;
  
  output        dataRdEn;                 
  output  [7:0] hashValueOut;
  output        hashWrEn;
  output        txStart;
  output [10:0] txByteTotal;
  
  
  reg     [2:0] h_current_state,  h_next_state;
  reg           fifo_state_w,     fifo_state_r;
  reg     [1:0] msg_cnt_w,        msg_cnt_r; 
  reg    [14:0] chunk_cnt_w,      chunk_cnt_r;
  reg   [511:0] hash_data_in_w,   hash_data_in_r;
  reg     [3:0] read_cnt_w,       read_cnt_r;      //one chunk: 16 x 32 = 512
  reg     [4:0] f_chunk_cnt_w,    f_chunk_cnt_r;
  reg     [4:0] output_cnt_w,     output_cnt_r;  
  reg           dataReady_w,      dataReady_r;
  reg           dataHold_w,       dataHold_r;
  reg           dataRdEn_w,       dataRdEn_r;
  reg           txStart_w,        txStart_r;
  reg           hashWrEn_w,       hashWrEn_r;
  reg   [159:0] hash_value_w,     hash_value_r;
  
  //sha1 engine
  reg           sha1_start_w,     sha1_start_r;
  reg           sha1_start_d1;
  reg           sha1_start_d2;
  reg           is_first_w,       is_first_r;
  reg           is_last_w,        is_last_r;
  wire  [159:0] sha1_hash_o;
  wire          sha1_busy_o;
  wire          hash_done_o;
  
  wire  [511:0] last_chunk_data;
  assign last_chunk_data = { 1'b1, 489'd0, chunk_cnt_r, 7'd0 };

  assign dataRdEn     = dataRdEn_w;
  assign txByteTotal  = 11'd80;
  assign hashValueOut = hash_value_r[159:152];
  assign hashWrEn     = hashWrEn_r;
  assign txStart      = txStart_r;
  
always @ (*)
 begin
   h_next_state  = h_current_state;
   sha1_start_w  = 1'b0;
   chunk_cnt_w   = chunk_cnt_r;
   f_chunk_cnt_w = f_chunk_cnt_r;
   is_first_w    = 1'b0;
   is_last_w     = 1'b0;
   
   case(h_current_state)
     `HASH_IDLE:
       begin
         if( !dataFifoEmpty )
          begin
            if(firstFrame)
             begin
               h_next_state = `HASH_INIT;
             end
            else if(lastFrame)
             begin
               h_next_state = `HASH_LAST5;
             end
            else
             begin
               h_next_state = `HASH_MID;
             end
          end
       end
     `HASH_INIT:
       begin
         if( dataReady_w & !sha1_busy_o )
          begin
            sha1_start_w  = 1'b1;
            chunk_cnt_w   = chunk_cnt_r + 1'b1;
            f_chunk_cnt_w = f_chunk_cnt_r + 1'b1;
            if( f_chunk_cnt_r == 5'd0 )
             begin
               is_first_w = 1'b1;
             end
            else if( f_chunk_cnt_r == 5'd19 )
             begin
               h_next_state  = `HASH_IDLE;
               f_chunk_cnt_w = 5'd0;
             end
          end
       end
     `HASH_MID:
       begin
         if( dataReady_w & !sha1_busy_o )
          begin
            sha1_start_w  = 1'b1;
            chunk_cnt_w   = chunk_cnt_r + 1'b1;
            f_chunk_cnt_w = f_chunk_cnt_r + 1'b1;
            if( f_chunk_cnt_r == 5'd19 )
             begin
               h_next_state  = `HASH_IDLE;
               f_chunk_cnt_w = 5'd0;
             end
          end
       end
     `HASH_LAST5:
       begin
         if( dataReady_w & !sha1_busy_o )
          begin
            sha1_start_w  = 1'b1;
            chunk_cnt_w   = chunk_cnt_r + 1'b1;
            f_chunk_cnt_w = f_chunk_cnt_r + 1'b1;
            if( f_chunk_cnt_r == 5'd19 )
             begin
               h_next_state  = `HASH_FINAL;
               f_chunk_cnt_w = 5'd0;
             end
          end
       end
     `HASH_FINAL:
       begin
         if( !sha1_start_r & !sha1_busy_o )
          begin
            sha1_start_w  = 1'b1;
            f_chunk_cnt_w = f_chunk_cnt_r + 1'b1;
            if( f_chunk_cnt_r == 5'd0 )
             begin
               is_last_w = 1'b1;
             end
            else if( f_chunk_cnt_r == 5'd3 )
             begin
               h_next_state  = `HASH_IDLE;
               f_chunk_cnt_w = 5'd0;
               chunk_cnt_w   = 15'd0;
             end
          end
       end
   endcase
 end



//read data fifo 
always @ (*)
 begin
   read_cnt_w   = read_cnt_r;
   fifo_state_w = fifo_state_r;
   dataRdEn_w   = dataRdEn_r;
   case(fifo_state_r)
    `FIFO_IDLE:
      begin
        if(!dataFifoEmpty & !dataHold_r)
         begin
           dataRdEn_w   = 1'b1;
           fifo_state_w = `FIFO_READ;
         end
      end
    `FIFO_READ:
      begin
        if( dataFifoValid )
         begin
           read_cnt_w = read_cnt_r + 1'b1 ;
           if( read_cnt_r == 4'd15 )
            begin
              dataRdEn_w   = 1'b0;
              fifo_state_w = `FIFO_IDLE;
            end
         end
      end
   endcase
 end

//dataHold
always @ (*)
begin
  dataHold_w = dataHold_r;
  if( read_cnt_r == 4'd15 )
   begin
     dataHold_w = 1'b1;
   end
  else if( sha1_start_d2 == 1'b1 && h_current_state != `HASH_FINAL )
   begin
     dataHold_w = 1'b0;
   end
end

//dataReady
always @ (*)
begin
  dataReady_w = dataReady_r;
  if( read_cnt_r == 4'd15 && dataFifoValid == 1'b1 )
   begin
     dataReady_w = 1'b1;
   end
  else if( sha1_start_r )
   begin
     dataReady_w = 1'b0;
   end
end

//hash data in
always @ (*)
 begin
   hash_data_in_w = hash_data_in_r;
   if( dataFifoValid )
    begin
      hash_data_in_w = { hash_data_in_r[479:0], dataIn };
    end
   else if( h_current_state == `HASH_FINAL )
    begin
      if( sha1_start_d2 )
        hash_data_in_w = last_chunk_data;
    end
 end

 
//output hash_value
always @ (*)
 begin
   msg_cnt_w    = msg_cnt_r;
   hash_value_w = hash_value_r;
   hashWrEn_w   = hashWrEn_r;
   output_cnt_w = output_cnt_r;
   txStart_w    = 1'b0;
   if( hash_done_o )
    begin
      msg_cnt_w    = msg_cnt_r + 1'b1;
      hash_value_w = sha1_hash_o;
      output_cnt_w = output_cnt_r + 1'b1;
      hashWrEn_w = 1'b1;
      if( msg_cnt_r == 2'd1 )
       begin
         txStart_w  = 1'b1;
       end
    end
   else if( output_cnt_r != 5'd0 )
    begin
      output_cnt_w = output_cnt_r + 1'b1;
      hash_value_w = { hash_value_r[151:0], 8'd0 };
      if( output_cnt_r == 5'd20 )
       begin
         output_cnt_w = 5'd0;
         hashWrEn_w   = 1'b0;
       end
    end 
 end
 
always @ ( posedge clk or posedge reset )
 begin
   if(reset)
    begin
      h_current_state <= `HASH_IDLE;
      fifo_state_r    <= `FIFO_IDLE;
      msg_cnt_r       <= 2'd0;
      chunk_cnt_r     <= 15'd0;
      hash_data_in_r  <= 512'd0;
      read_cnt_r      <= 4'd0;
      f_chunk_cnt_r   <= 5'd0;
      output_cnt_r    <= 5'd0;
      dataReady_r     <= 1'b0;
      dataHold_r      <= 1'b0;
      dataRdEn_r      <= 1'b0;
      sha1_start_r    <= 1'b0;
      sha1_start_d1   <= 1'b0;
      sha1_start_d2   <= 1'b0;
      is_first_r      <= 1'b0;
      is_last_r       <= 1'b0;
      txStart_r       <= 1'b0;
      hashWrEn_r      <= 1'b0;
      hash_value_r    <= 160'd0;
    end
   else
    begin
      h_current_state <= h_next_state;
      fifo_state_r    <= fifo_state_w;
      msg_cnt_r       <= msg_cnt_w;
      chunk_cnt_r     <= chunk_cnt_w;
      hash_data_in_r  <= hash_data_in_w;
      read_cnt_r      <= read_cnt_w;
      f_chunk_cnt_r   <= f_chunk_cnt_w;
      output_cnt_r    <= output_cnt_w;
      dataReady_r     <= dataReady_w;
      dataHold_r      <= dataHold_w;
      dataRdEn_r      <= dataRdEn_w;
      sha1_start_r    <= sha1_start_w;
      sha1_start_d1   <= sha1_start_r;
      sha1_start_d2   <= sha1_start_d1;
      is_first_r      <= is_first_w;
      is_last_r       <= is_last_w;
      txStart_r       <= txStart_w;
      hashWrEn_r      <= hashWrEn_w;
      hash_value_r    <= hash_value_w;
    end
 end


  
topSHA1 sha1_gen ( .clk           ( clk             ), 
                   .reset         ( reset           ), 
                   .start_i       ( sha1_start_r    ),
                   .msg_i         ( hash_data_in_r  ),
                   .is_first_i    ( is_first_r      ),
                   .is_last_i     ( is_last_r       ),
                   .hash_o        ( sha1_hash_o     ),
                   .busy_o        ( sha1_busy_o     ),
                   .hash_done_o   ( hash_done_o     )
                 );
  
endmodule
