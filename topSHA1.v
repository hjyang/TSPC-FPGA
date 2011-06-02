`timescale 1ns / 1ps

module topSHA1( clk,
                reset,
                start_i,
                msg_i,
                is_first_i,
                is_last_i,
                hash_o,
                busy_o,
                hash_done_o
             ) ;

  input          clk;
  input          reset;
  input          start_i;
  
  input  [511:0] msg_i;
  input          is_first_i;
  input          is_last_i;

  output [159:0] hash_o;
  output         busy_o;
  output         hash_done_o;
  
  wire           chunk_done_o;
  wire           chunk_busy;

  reg     [1:0]  msg_cnt_in_w,    msg_cnt_in_r;   //for hash into first stage 
  reg     [1:0]  msg_cnt_out_w,   msg_cnt_out_r;  //for storing the output hash
  reg            busy_w,          busy_r;
  reg            first_chunk_w,   first_chunk_r;
  reg            last_chunk_w,    last_chunk_r;
  reg            to_be_last_w,    to_be_last_r;
  reg            start_i_delay;
  
assign hash_done_o = last_chunk_r & chunk_done_o;
assign busy_o      = busy_w;

always @ (*)
 begin
   if( start_i_delay )
     msg_cnt_in_w = msg_cnt_in_r + 1'b1;
   else
     msg_cnt_in_w = msg_cnt_in_r;
 end

always @ (*)
 begin
   if( chunk_done_o )
     msg_cnt_out_w = msg_cnt_out_r + 1'b1;
   else
     msg_cnt_out_w = msg_cnt_out_r;
 end

always @ (*)
 begin
   if( ( msg_cnt_out_r == msg_cnt_in_r )&( !first_chunk_w|(first_chunk_w&last_chunk_r) ) )
    begin
      busy_w = chunk_busy|busy_r;
      if( chunk_done_o & !chunk_busy )
       begin
         busy_w = 1'b0;
       end
    end
   else
    begin
      busy_w = chunk_busy;    
    end
 end

 always @ (*)
  begin
    first_chunk_w = first_chunk_r;
    if( is_first_i )
     begin
       first_chunk_w = 1'b1;
     end
    else if( msg_cnt_in_r == 2'd3 && start_i_delay )
     begin
       first_chunk_w = 1'b0;
     end  
  end
 
 always @ (*)
  begin
    to_be_last_w = to_be_last_r;
    last_chunk_w = last_chunk_r;
    if( is_last_i )
     begin
       to_be_last_w = 1'b1;
     end
    else if( to_be_last_r )
     begin
       if( msg_cnt_out_r == 2'd0 )
        begin
          last_chunk_w = 1'b1;
          to_be_last_w = 1'b0;
        end
     end
    else if( chunk_done_o == 1'b1 && msg_cnt_out_r == 2'd3 )
     begin
       last_chunk_w = 1'b0;
     end
  end
 
always @ ( posedge clk or posedge reset )
 begin
   if( reset )
    begin
      msg_cnt_in_r   <= 2'd0;
      msg_cnt_out_r  <= 2'd0;
      start_i_delay  <= 1'b0;
      busy_r         <= 1'b0;
      first_chunk_r  <= 1'b0;
      last_chunk_r   <= 1'b0;
      to_be_last_r   <= 1'b0;
    end
   else
    begin
      msg_cnt_in_r   <= msg_cnt_in_w;
      msg_cnt_out_r  <= msg_cnt_out_w;
      start_i_delay  <= start_i;
      busy_r         <= busy_w;
      first_chunk_r  <= first_chunk_w;
      last_chunk_r   <= last_chunk_w;
      to_be_last_r   <= to_be_last_w;
    end
 end
  
chunkSHA1 chunk_hash( .clk         ( clk           ),
                      .reset       ( reset         ),
                      .start       ( start_i       ),
                      .first_chunk ( first_chunk_w ),
                      .msgIn_cnt   ( msg_cnt_in_r  ),
                      .msgOut_cnt  ( msg_cnt_out_r ),                     
                      .msg         ( msg_i         ),
                      .hash_out    ( hash_o        ),
                      .ready       ( chunk_done_o  ),
                      .busy        ( chunk_busy    )
                    );


endmodule
