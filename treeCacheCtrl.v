`timescale 1ns / 1ps

//HashTreeCache control

//state definition for hash tree cache controller
`define TCC_RESET_CACHE  5'd0
`define TCC_IDLE         5'd1
`define TCC_LOAD         5'd2   //load instruction
`define TCC_LOAD_TYPE    5'd3   //load instruction type
`define TCC_EXECUTE_L    5'd4   //execute load
`define TCC_CHECK_V      5'd5   //check verify conmand
`define TCC_EXECUTE_V    5'd6   //execute verify
`define TCC_WRITE_V      5'd7   //update verify bits in cache
`define TCC_EXECUTE_RT   5'd8   //execute load root hash
`define TCC_HMAC         5'd9   //execute HMAC -> h(session key||msg)
`define TCC_OUT_HMAC     5'd10  //output HMAC value
`define TCC_U_HASH_L     5'd11  //store new hash values into cache ( for update commands )
`define TCC_CHECK_U_1    5'd12  //check update command (for first round)
`define TCC_CHECK_U_2    5'd13  //check update command (for non first round)
`define TCC_EXECUTE_U    5'd14  //execute update
`define TCC_U_LOAD_1     5'd15  //rest load for update command (for first round)
`define TCC_U_LOAD_2     5'd16  //rest load for update command (for non first round)

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
`define INST_TYPE_WIDTH    8
`define INST_LENGTH        288
`define LOAD_CYCLE_L       7  //load inst.      cur_entry(16), par_entry(16), nodeid(24), hash(160), dummy(8) 
`define LOAD_CYCLE_V1      2  //verify inst.    right_entry(16), left_entry(16), par_entry(16)
`define LOAD_CYCLE_V2      3  //                2{right_entry(16), left_entry(16), par_entry(16)}
`define LOAD_CYCLE_V3      5  //                3{right_entry(16), left_entry(16), par_entry(16)}
`define LOAD_CYCLE_V4      6  //                4{right_entry(16), left_entry(16), par_entry(16)}
`define LOAD_CYCLE_RT      5  //load root inst. hash(160)
`define LOAD_CYCLE_HMAC    9  //HMAC inst.      entry(16), section key(128), nonce(128), dummy(16)
`define LOAD_CYCLE_U       7   //update inst.    cur_entry(32), neighbor_entry(16), par_entry(16), hash(160)
  
module treeCacheCtrl( clk,
                      reset,
                      instIn,
                      instFifoEmpty,
                      instFifoValid,
                      instRdEn,
                      itpIn,
                      itpFifoEmpty,
                      itpRdEn,      
                      hashValueOut,
                      hashWrEn,
                      txStart,
                      txByteTotal,
                      clear
                    );

parameter CACHE_ADDR_WIDTH  = 6 ;
parameter CACHE_DEPTH       = 1<<CACHE_ADDR_WIDTH;
parameter CACHE_ADDR_UNUSE  = 16-CACHE_ADDR_WIDTH;
parameter NODE_ID_WIDTH     = 21 ;
parameter NODE_ID_UNUSE     = 24-NODE_ID_WIDTH;
parameter DATA_WIDTH        = NODE_ID_WIDTH+160+3;
                   
input          clk;
input          reset;
input  [31:0]  instIn;
input          instFifoEmpty;
input          instFifoValid;
output         instRdEn;
input  [ 7:0]  itpIn;
input          itpFifoEmpty;
output         itpRdEn;
output  [7:0]  hashValueOut;
output         hashWrEn;
output         txStart;
output [10:0]  txByteTotal;
output         clear;

reg [4:0]              tcc_current_state,  tcc_next_state;
reg [`INST_LENGTH-1:0] inst_r,             inst_w;
reg [7:0]              inst_type_r,        inst_type_w;
reg [3:0]              load_cnt_r,         load_cnt_w;
reg [1:0]              exe_cnt_r,          exe_cnt_w;
reg [1:0]              exe_bnd_r,          exe_bnd_w;
reg                    instRdEn_r,         instRdEn_w;
reg                    itpRdEn_r,          itpRdEn_w;
reg                    clear_r,            clear_w;

//tree cache engine
reg                         tCache_ena_w,   tCache_ena_r;  
reg                         tCache_wea_w,   tCache_wea_r;  
reg  [CACHE_ADDR_WIDTH-1:0] tCache_addra;
reg  [DATA_WIDTH-1:0]       tCache_dina; 
wire [DATA_WIDTH-1:0]       tCache_douta;
                            
reg                         tCache_enb_w,   tCache_enb_r;   
reg                         tCache_web_w,   tCache_web_r;   
reg  [CACHE_ADDR_WIDTH-1:0] tCache_addrb;
reg  [DATA_WIDTH-1:0]       tCache_dinb;
wire [DATA_WIDTH-1:0]       tCache_doutb;

reg  [DATA_WIDTH-1:0]       cache_p_w,      cache_p_r;
reg  [DATA_WIDTH-1:0]       cache_l_w,      cache_l_r;
reg  [DATA_WIDTH-1:0]       cache_r_w,      cache_r_r;
reg  [CACHE_ADDR_WIDTH-1:0] addr_cnt_w,     addr_cnt_r;
reg                         load_done_w,    load_done_r;
reg                         write_done_w,   write_done_r;
reg  [1:0]                  inst_load1_w,   inst_load1_r;
reg  [1:0]                  inst_load2_w,   inst_load2_r;

//tree sha1 engine
reg           tsha1_start_i;
reg  [511:0]  tsha1_data_r,    tsha1_data_w;
wire [159:0]  tsha1_hash_o;
wire          tsha1_ready_o;
wire          tsha1_busy_o;

reg           txStart_w,       txStart_r;
reg           hashWrEn_w,      hashWrEn_r;
reg   [159:0] hash_value_w,    hash_value_r;
reg     [4:0] output_cnt_w,    output_cnt_r;  

assign clear        = clear_r;
assign instRdEn     = instRdEn_w;
assign itpRdEn      = itpRdEn_r;
assign txByteTotal  = 11'd20;
assign hashValueOut = hash_value_r[159:152];
assign hashWrEn     = hashWrEn_r;
assign txStart      = txStart_r;

// for load command
wire [CACHE_ADDR_WIDTH-1:0]  load_cur_entry;
wire [CACHE_ADDR_WIDTH-1:0]  load_par_entry;
wire [NODE_ID_WIDTH-1:0]     load_node_id;
wire [159:0]                 load_node_hash;
wire                         check_node_id;
wire                         check_load_cur_entry;
wire                         check_load_par_entry;
wire [DATA_WIDTH-1:0]        old_cache_content;
wire [NODE_ID_WIDTH-1:0]     old_node_id;
wire                         check_load_parent;
wire                         load_check_1;
wire                         load_check_2;

// for verify command
wire [CACHE_ADDR_WIDTH-1:0]  verify_p_entry1;
wire [CACHE_ADDR_WIDTH-1:0]  verify_l_entry1;
wire [CACHE_ADDR_WIDTH-1:0]  verify_r_entry1;
wire [CACHE_ADDR_WIDTH-1:0]  verify_p_entry2;
wire [CACHE_ADDR_WIDTH-1:0]  verify_l_entry2;
wire [CACHE_ADDR_WIDTH-1:0]  verify_r_entry2;
wire [CACHE_ADDR_WIDTH-1:0]  verify_p_entry3;
wire [CACHE_ADDR_WIDTH-1:0]  verify_l_entry3;
wire [CACHE_ADDR_WIDTH-1:0]  verify_r_entry3;
wire [CACHE_ADDR_WIDTH-1:0]  verify_p_entry4;
wire [CACHE_ADDR_WIDTH-1:0]  verify_l_entry4;
wire [CACHE_ADDR_WIDTH-1:0]  verify_r_entry4;

wire                         check_verify_p_entry1;
wire                         check_verify_l_entry1;
wire                         check_verify_r_entry1;
wire                         check_verify_p_entry2;
wire                         check_verify_l_entry2;
wire                         check_verify_r_entry2;
wire                         check_verify_p_entry3;
wire                         check_verify_l_entry3;
wire                         check_verify_r_entry3;
wire                         check_verify_p_entry4;
wire                         check_verify_l_entry4;
wire                         check_verify_r_entry4;
wire                         check_verify_entry1;
wire                         check_verify_entry2;
wire                         check_verify_entry3;
wire                         check_verify_entry4;

wire [DATA_WIDTH-1:0]        verify_p_cache;
wire [DATA_WIDTH-1:0]        verify_l_cache;
wire [DATA_WIDTH-1:0]        verify_r_cache;

wire                         verify_check_1;
wire                         verify_check_2;
wire                         verify_check_3;
wire                         verify_check_total;
reg                          check_verify_entry;
reg  [CACHE_ADDR_WIDTH-1:0]  verify_p_entry;
reg  [CACHE_ADDR_WIDTH-1:0]  verify_l_entry;
reg  [CACHE_ADDR_WIDTH-1:0]  verify_r_entry;
reg  [CACHE_ADDR_WIDTH-1:0]  w_verify_p_entry;
reg  [CACHE_ADDR_WIDTH-1:0]  w_verify_l_entry;
reg  [CACHE_ADDR_WIDTH-1:0]  w_verify_r_entry;

//load root hash
wire [DATA_WIDTH-1:0]        root_cache;

//hmac
wire                         check_hmac_entry;
wire                         check_hmac_verify;
wire [DATA_WIDTH-1:0]        hmac_cache;
wire [23:0]                  hmac_node_id;

//update
wire [DATA_WIDTH-1:0]        update_par_cache;
wire [DATA_WIDTH-1:0]        update_cur_cache;
wire [DATA_WIDTH-1:0]        update_nei_cache;
wire                         check_update_par_entry1;
wire                         check_update_cur_entry1;
wire                         check_update_nei_entry1;
wire                         check_update_par_entry2;
wire                         check_update_cur_entry2;
wire                         check_update_nei_entry2;
wire [CACHE_ADDR_WIDTH-1:0]  update_par_entry1;
wire [CACHE_ADDR_WIDTH-1:0]  update_nei_entry1;
wire [CACHE_ADDR_WIDTH-1:0]  update_cur_entry1;
wire [CACHE_ADDR_WIDTH-1:0]  update_par_entry2;
wire [CACHE_ADDR_WIDTH-1:0]  update_nei_entry2;
wire [CACHE_ADDR_WIDTH-1:0]  update_cur_entry2;
wire                         update_verify_check;
wire                         update_path_check;
wire                         update_entry1_check;
wire                         update_entry2_check;
wire                         update_cur_is_right;
wire                         update_check_total;
wire                         update_check_common;
wire [159:0]                 update_cur_hash1;
wire [159:0]                 update_cur_hash2;
reg  [ 1:0]                  update_next_exe;
reg                          end_of_update_w,          end_of_update_r;
reg  [63:0]                  update_par_entry_buf_w,   update_par_entry_buf_r;
reg   [2:0]                  update_merge_w,           update_merge_r;
reg   [1:0]                  update_cnt_w,             update_cnt_r;
reg   [1:0]                  pre_update_cnt_w,         pre_update_cnt_r;
reg   [1:0]                  update_wait_w,            update_wait_r;
reg   [1:0]                  update_exe_cnt_w,         update_exe_cnt_r;
reg                          update_is_merged;

// for load command
assign load_cur_entry       = inst_r[ 208 + CACHE_ADDR_WIDTH-1 : 208 ];
assign load_par_entry       = inst_r[ 192 + CACHE_ADDR_WIDTH-1 : 192 ];
assign load_node_id         = inst_r[ 168 + NODE_ID_WIDTH-1    : 168 ];
assign load_node_hash       = inst_r[167:8];
assign check_node_id        = (load_node_id != {NODE_ID_WIDTH{1'b0}}) && ( inst_r[191:168+NODE_ID_WIDTH] == {NODE_ID_UNUSE{1'b0}} );
assign check_load_cur_entry = (CACHE_ADDR_UNUSE!=0)? ( inst_r[223: 208+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1;
assign check_load_par_entry = (CACHE_ADDR_UNUSE!=0)? ( inst_r[207: 192+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1; 
assign old_cache_content    = cache_r_r;
assign old_node_id          = old_cache_content[163+NODE_ID_WIDTH-1:163];
assign check_load_parent    = ( cache_p_r[163+NODE_ID_WIDTH-1:163] == { 1'b0, old_node_id[NODE_ID_WIDTH-1:1] } );
assign load_check_1         = (check_node_id & check_load_cur_entry);
assign load_check_2         = (check_load_par_entry & check_load_parent & !old_cache_content[1] & !old_cache_content[0]); //parent is valid and no DuplicateChild


// for verify command
assign verify_p_entry1 = inst_r[  0+CACHE_ADDR_WIDTH-1:  0]; 
assign verify_l_entry1 = inst_r[ 16+CACHE_ADDR_WIDTH-1: 16]; 
assign verify_r_entry1 = inst_r[ 32+CACHE_ADDR_WIDTH-1: 32]; 
assign verify_p_entry2 = inst_r[ 48+CACHE_ADDR_WIDTH-1: 48]; 
assign verify_l_entry2 = inst_r[ 64+CACHE_ADDR_WIDTH-1: 64]; 
assign verify_r_entry2 = inst_r[ 80+CACHE_ADDR_WIDTH-1: 80]; 
assign verify_p_entry3 = inst_r[ 96+CACHE_ADDR_WIDTH-1: 96]; 
assign verify_l_entry3 = inst_r[112+CACHE_ADDR_WIDTH-1:112]; 
assign verify_r_entry3 = inst_r[128+CACHE_ADDR_WIDTH-1:128]; 
assign verify_p_entry4 = inst_r[144+CACHE_ADDR_WIDTH-1:144]; 
assign verify_l_entry4 = inst_r[160+CACHE_ADDR_WIDTH-1:160]; 
assign verify_r_entry4 = inst_r[176+CACHE_ADDR_WIDTH-1:176]; 

assign check_verify_p_entry1 = (CACHE_ADDR_UNUSE!=0)? ( inst_r[ 15:  0+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1;
assign check_verify_l_entry1 = (CACHE_ADDR_UNUSE!=0)? ( inst_r[ 31: 16+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1;
assign check_verify_r_entry1 = (CACHE_ADDR_UNUSE!=0)? ( inst_r[ 47: 32+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1;
assign check_verify_p_entry2 = (CACHE_ADDR_UNUSE!=0)? ( inst_r[ 63: 48+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1;
assign check_verify_l_entry2 = (CACHE_ADDR_UNUSE!=0)? ( inst_r[ 79: 64+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1;
assign check_verify_r_entry2 = (CACHE_ADDR_UNUSE!=0)? ( inst_r[ 95: 80+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1;
assign check_verify_p_entry3 = (CACHE_ADDR_UNUSE!=0)? ( inst_r[111: 96+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1;
assign check_verify_l_entry3 = (CACHE_ADDR_UNUSE!=0)? ( inst_r[127:112+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1;
assign check_verify_r_entry3 = (CACHE_ADDR_UNUSE!=0)? ( inst_r[143:128+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1;
assign check_verify_p_entry4 = (CACHE_ADDR_UNUSE!=0)? ( inst_r[159:144+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1;
assign check_verify_l_entry4 = (CACHE_ADDR_UNUSE!=0)? ( inst_r[175:160+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1;
assign check_verify_r_entry4 = (CACHE_ADDR_UNUSE!=0)? ( inst_r[191:176+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1;

assign check_verify_entry1 = check_verify_p_entry1 & check_verify_l_entry1 & check_verify_r_entry1;
assign check_verify_entry2 = check_verify_p_entry2 & check_verify_l_entry2 & check_verify_r_entry2;
assign check_verify_entry3 = check_verify_p_entry3 & check_verify_l_entry3 & check_verify_r_entry3;
assign check_verify_entry4 = check_verify_p_entry4 & check_verify_l_entry4 & check_verify_r_entry4; 

assign verify_p_cache = cache_p_r;
assign verify_l_cache = cache_l_r;
assign verify_r_cache = cache_r_r;

assign verify_check_1     = verify_p_cache[2]; //Parent entry are validated
assign verify_check_2     = ( {verify_p_cache[163+NODE_ID_WIDTH-2:163],1'b0} == verify_l_cache[163+NODE_ID_WIDTH-1:163] ) && ( {verify_p_cache[163+NODE_ID_WIDTH-2:163],1'b1} == verify_r_cache[163+NODE_ID_WIDTH-1:163] ); //Correct child entry
assign verify_check_3     = ( verify_p_cache[0] == verify_r_cache[2] ) && ( verify_p_cache[1] == verify_l_cache[2] ); //No duplicate right/left child node
assign verify_check_total = check_verify_entry & verify_check_1 & verify_check_2 & verify_check_3;


//assign and check verify entry
always @ (*)
 begin
   check_verify_entry = check_verify_entry1;
   verify_p_entry     = verify_p_entry1;
   verify_l_entry     = verify_l_entry1;
   verify_r_entry     = verify_r_entry1;
   w_verify_p_entry   = verify_p_entry1;
   w_verify_l_entry   = verify_l_entry1;
   w_verify_r_entry   = verify_r_entry1; 

   case( exe_cnt_r )
     2'd0:
      begin
        case(inst_type_r)
          `TC_VERIFY2:
            begin
              check_verify_entry = check_verify_entry2;
              verify_p_entry     = verify_p_entry2;
              verify_l_entry     = verify_l_entry2;
              verify_r_entry     = verify_r_entry2;
            end
          `TC_VERIFY3:
            begin
              check_verify_entry = check_verify_entry3;
              verify_p_entry     = verify_p_entry3;
              verify_l_entry     = verify_l_entry3;
              verify_r_entry     = verify_r_entry3;
            end
          `TC_VERIFY4:
            begin
              check_verify_entry = check_verify_entry4;
              verify_p_entry     = verify_p_entry4;
              verify_l_entry     = verify_l_entry4;
              verify_r_entry     = verify_r_entry4;
              w_verify_p_entry   = verify_p_entry3;
              w_verify_l_entry   = verify_l_entry3;
              w_verify_r_entry   = verify_r_entry3; 
            end
          default:;
        endcase
      end
     2'd1:
      begin
        case(inst_type_r)   
          `TC_VERIFY2:
            begin
              w_verify_p_entry   = verify_p_entry2;
              w_verify_l_entry   = verify_l_entry2;
              w_verify_r_entry   = verify_r_entry2; 
            end
          `TC_VERIFY3:
            begin
              w_verify_p_entry   = verify_p_entry3;
              w_verify_l_entry   = verify_l_entry3;
              w_verify_r_entry   = verify_r_entry3;
            end
          `TC_VERIFY4:
            begin
              w_verify_p_entry   = verify_p_entry4;
              w_verify_l_entry   = verify_l_entry4;
              w_verify_r_entry   = verify_r_entry4;
            end
          default:;
        endcase 
      end
     2'd2:
      begin
        check_verify_entry = check_verify_entry2;
        verify_p_entry     = verify_p_entry2;
        verify_l_entry     = verify_l_entry2;
        verify_r_entry     = verify_r_entry2;
      end
     2'd3:
      begin
        check_verify_entry = check_verify_entry3;
        verify_p_entry     = verify_p_entry3;
        verify_l_entry     = verify_l_entry3;
        verify_r_entry     = verify_r_entry3;
        w_verify_p_entry   = verify_p_entry2;
        w_verify_l_entry   = verify_l_entry2;
        w_verify_r_entry   = verify_r_entry2; 
      end
   endcase
 end

//for load root hash command
assign root_cache      = { {{(NODE_ID_WIDTH-1){1'b0}},1'b1}, inst_r[159:0], 3'b100 };

//for hmac command
assign check_hmac_entry  = (CACHE_ADDR_UNUSE!=0)? ( inst_r[287:272+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1;
assign check_hmac_verify = hmac_cache[2];
assign hmac_cache        = cache_r_r;
assign hmac_node_id      = { {NODE_ID_UNUSE{1'b0}}, hmac_cache[163+NODE_ID_WIDTH-1:163] };

//for update command
assign update_par_cache    = cache_p_r;
assign update_cur_cache    = cache_r_r;
assign update_nei_cache    = cache_l_r;
assign update_verify_check = update_par_cache[2] & update_cur_cache[2] & update_nei_cache[2];
assign update_path_check   = ( update_par_cache[163+NODE_ID_WIDTH-2:163] == update_cur_cache[163+NODE_ID_WIDTH-1:164] ) 
                          && ( update_par_cache[163+NODE_ID_WIDTH-2:163] == update_nei_cache[163+NODE_ID_WIDTH-1:164] )
                          && ( update_cur_cache[163+NODE_ID_WIDTH-1:163] ^ update_nei_cache[163+NODE_ID_WIDTH-1:163] == {{(NODE_ID_WIDTH-1){1'b0}},1'b1} );
assign update_cur_is_right = update_cur_cache[163];
assign update_entry1_check = check_update_par_entry1 & check_update_nei_entry1 & check_update_cur_entry1;
assign update_entry2_check = check_update_par_entry2 & check_update_nei_entry2 & check_update_cur_entry2;
assign update_check_total  = update_entry1_check & update_entry2_check & update_verify_check & update_path_check;
assign update_check_common = (update_par_entry1 == update_par_entry2) && (update_cur_entry1 == update_nei_entry2);

//define and check update entry
assign check_update_par_entry1 = (CACHE_ADDR_UNUSE!=0)? ( inst_r[ 159: 144+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1;
assign check_update_nei_entry1 = (CACHE_ADDR_UNUSE!=0)? ( inst_r[ 175: 160+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1;
assign check_update_cur_entry1 = (CACHE_ADDR_UNUSE!=0)? ( inst_r[ 191: 176+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1;
assign check_update_par_entry2 = (CACHE_ADDR_UNUSE!=0)? ( inst_r[ 111:  96+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1;
assign check_update_nei_entry2 = (CACHE_ADDR_UNUSE!=0)? ( inst_r[ 127: 112+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1;
assign check_update_cur_entry2 = (CACHE_ADDR_UNUSE!=0)? ( inst_r[ 143: 128+CACHE_ADDR_WIDTH] == {CACHE_ADDR_UNUSE{1'b0}} ): 1'b1;
assign update_par_entry1       = inst_r[ 144 + CACHE_ADDR_WIDTH - 1: 144];
assign update_nei_entry1       = inst_r[ 160 + CACHE_ADDR_WIDTH - 1: 160];
assign update_cur_entry1       = inst_r[ 176 + CACHE_ADDR_WIDTH - 1: 176];
assign update_par_entry2       = inst_r[  96 + CACHE_ADDR_WIDTH - 1:  96];
assign update_nei_entry2       = inst_r[ 112 + CACHE_ADDR_WIDTH - 1: 112];
assign update_cur_entry2       = inst_r[ 128 + CACHE_ADDR_WIDTH - 1: 128];
assign update_cur_hash1        = cache_r_r[162: 3];
assign update_cur_hash2        = cache_l_r[162: 3];

//update_next_exe
always @ (*)
 begin
   update_next_exe = 2'd1;
   case( exe_cnt_r )
    2'd0: 
     begin
       case( update_merge_r[1:0] )
        2'b00: update_next_exe = 2'd1;
        2'b01: update_next_exe = 2'd2;
        2'b10: update_next_exe = 2'd1;
        2'b11: update_next_exe = 2'd3;
       endcase
     end
    2'd1:
     begin
       if( update_merge_r[1] )
         update_next_exe = 2'd3;
       else
         update_next_exe = 2'd2;
     end
    2'd2:
     begin
       update_next_exe = 2'd3;
     end
    default:; 
   endcase
 end

 //determine the current set is merged or not
 always @ (*)
  begin
    case( exe_cnt_r )
     2'd0: update_is_merged = 1'b0;
     2'd1: update_is_merged = update_merge_r[0];
     2'd2: update_is_merged = update_merge_r[1];
     2'd3: update_is_merged = update_merge_r[2];
    endcase
  end

  
always @ (*)
 begin
   tcc_next_state         = tcc_current_state;
   load_cnt_w             = load_cnt_r;
   instRdEn_w             = instRdEn_r;
   itpRdEn_w              = 1'b0;
   inst_w                 = inst_r;
   exe_cnt_w              = exe_cnt_r;
   exe_bnd_w              = exe_bnd_r;
   clear_w                = clear_r;
   tsha1_start_i          = 1'b0;
   tsha1_data_w           = tsha1_data_r;
   hash_value_w           = hash_value_r;
   hashWrEn_w             = hashWrEn_r;
   txStart_w              = 1'b0;
   output_cnt_w           = output_cnt_r;
   inst_type_w            = inst_type_r;
   update_par_entry_buf_w = update_par_entry_buf_r;
   update_merge_w         = update_merge_r;
   update_cnt_w           = update_cnt_r;
   pre_update_cnt_w       = pre_update_cnt_r;
   update_wait_w          = update_wait_r;
   update_exe_cnt_w       = update_exe_cnt_r;
   end_of_update_w        = end_of_update_r;
   
   case(tcc_current_state)
     `TCC_RESET_CACHE:
      begin
        if( addr_cnt_r == { 1'b0, {(CACHE_ADDR_WIDTH-1){1'b1}} } )
         begin
           if( !itpFifoEmpty )
            begin
              itpRdEn_w      = 1'b1;
              tcc_next_state = `TCC_LOAD_TYPE;
            end
           else
            begin
              tcc_next_state = `TCC_IDLE;
            end
         end
      end
     `TCC_IDLE:
      begin
        if( !itpFifoEmpty )
         begin
           itpRdEn_w      = 1'b1;
           tcc_next_state = `TCC_LOAD_TYPE;
         end          
      end
     `TCC_LOAD_TYPE:
      begin
        clear_w            = 1'b0;
        if( !itpRdEn_r )
          begin
            inst_type_w    = itpIn;
            tcc_next_state = `TCC_LOAD;
            instRdEn_w     = 1'b1;
            case( itpIn )
              `TC_LOAD   : load_cnt_w       = `LOAD_CYCLE_L;   
              `TC_VERIFY1: begin load_cnt_w = `LOAD_CYCLE_V1; exe_bnd_w = 2'd0; end
              `TC_VERIFY2: begin load_cnt_w = `LOAD_CYCLE_V2; exe_bnd_w = 2'd1; end
              `TC_VERIFY3: begin load_cnt_w = `LOAD_CYCLE_V3; exe_bnd_w = 2'd2; end
              `TC_VERIFY4: begin load_cnt_w = `LOAD_CYCLE_V4; exe_bnd_w = 2'd3; end
              `TC_LOAD_RT: load_cnt_w       = `LOAD_CYCLE_RT;
              `TC_HMAC:    load_cnt_w       = `LOAD_CYCLE_HMAC;
              `TC_UPDATE1: begin load_cnt_w = `LOAD_CYCLE_U; exe_bnd_w = 2'd0; end
              `TC_UPDATE2: begin load_cnt_w = `LOAD_CYCLE_U; exe_bnd_w = 2'd1; end
              `TC_UPDATE3: begin load_cnt_w = `LOAD_CYCLE_U; exe_bnd_w = 2'd2; end
              `TC_UPDATE4: begin load_cnt_w = `LOAD_CYCLE_U; exe_bnd_w = 2'd3; end              
              default:;
            endcase
          end      
      end
     `TCC_LOAD:
      begin
        if( instFifoValid )
         begin
           load_cnt_w = load_cnt_r - 1'b1 ;
           inst_w     = {inst_r[`INST_LENGTH-33:0], instIn};
           if( load_cnt_r == 4'd1 )
            begin
              instRdEn_w   = 1'b0;
              case( inst_type_r )
                `TC_LOAD   : tcc_next_state = `TCC_EXECUTE_L;
                `TC_VERIFY1: begin tcc_next_state = `TCC_CHECK_V; inst_w = {inst_r[`INST_LENGTH-17:0], instIn[31:16]}; end
                `TC_VERIFY2: tcc_next_state = `TCC_CHECK_V;
                `TC_VERIFY3: begin tcc_next_state = `TCC_CHECK_V; inst_w = {inst_r[`INST_LENGTH-17:0], instIn[31:16]}; end
                `TC_VERIFY4: tcc_next_state = `TCC_CHECK_V;
                `TC_LOAD_RT: tcc_next_state = `TCC_EXECUTE_RT;
                `TC_HMAC:    tcc_next_state = `TCC_HMAC;
                `TC_UPDATE1: tcc_next_state = `TCC_U_HASH_L;
                `TC_UPDATE2: tcc_next_state = `TCC_U_HASH_L;
                `TC_UPDATE3: tcc_next_state = `TCC_U_HASH_L;
                `TC_UPDATE4: tcc_next_state = `TCC_U_HASH_L;
                default:;
              endcase
            end
         end
      end
     `TCC_EXECUTE_L:
      begin
        if( !load_check_1 )
         begin
           clear_w        = 1'b1;
           tcc_next_state = `TCC_RESET_CACHE;
         end
        else if( old_cache_content[2] & !load_check_2 ) //verified & parent is not valid or DuplicateChild
         begin
           clear_w        = 1'b1;
           tcc_next_state = `TCC_RESET_CACHE;
         end
        else
         begin
           if( !itpFifoEmpty )
            begin
              itpRdEn_w      = 1'b1;
              tcc_next_state = `TCC_LOAD_TYPE;
            end
           else
            begin
              tcc_next_state = `TCC_IDLE;
            end
         end
      end
     `TCC_CHECK_V:
      begin
        if( !tsha1_busy_o & load_done_r )
         begin
           if( !verify_check_total ) //entries not valid or content not valid
            begin
              clear_w        = 1'b1;
              tcc_next_state = `TCC_RESET_CACHE;
            end
           else
            begin
              tsha1_start_i = 1'b1;
              tsha1_data_w  = { verify_l_cache[162:3], verify_r_cache[162:3], 192'h800000000000000000000000000000000000000000000140 };
              if( exe_cnt_r == exe_bnd_r )
                begin
                  tcc_next_state = `TCC_EXECUTE_V;
                  exe_cnt_w = 2'd0;
                end
              else
                begin
                  exe_cnt_w = exe_cnt_r + 1'b1;
                end
            end
         end
      end
     `TCC_EXECUTE_V:
      begin
        if( tsha1_ready_o )
         begin
           if( tsha1_hash_o == verify_p_cache[162:3] )
             begin
               exe_cnt_w = exe_cnt_r + 1'b1;
               if( exe_cnt_r == exe_bnd_r )
                begin
                  tcc_next_state = `TCC_WRITE_V;
                end
              end
           else
            begin
              exe_cnt_w      = 2'd0;
              tcc_next_state = `TCC_RESET_CACHE;
              clear_w        = 1'b1;
            end
         end
      end
     `TCC_WRITE_V:
      begin
        if( addr_cnt_r != {CACHE_ADDR_WIDTH{1'b0}} )
         begin
           exe_cnt_w      = 2'd0; 
           if( !itpFifoEmpty )
            begin
              itpRdEn_w      = 1'b1;
              tcc_next_state = `TCC_LOAD_TYPE;
            end
           else
            begin
              tcc_next_state = `TCC_IDLE;
            end         
         end
      end
     `TCC_EXECUTE_RT:
      begin
        if( !itpFifoEmpty )
          begin
            itpRdEn_w      = 1'b1;
            tcc_next_state = `TCC_LOAD_TYPE;
          end
         else
          begin
            tcc_next_state = `TCC_IDLE;
          end             
      end
     `TCC_HMAC:
      begin
        if( !tsha1_busy_o )
         begin
           if( !check_hmac_entry | !check_hmac_verify )
            begin
              clear_w        = 1'b1;
              tcc_next_state = `TCC_RESET_CACHE;
            end
           else
            begin
              tsha1_start_i = 1'b1;
              tsha1_data_w  = { inst_r[271:16], hmac_node_id, hmac_cache[162:3], 8'h80, 64'h00000000000001B8 };
              tcc_next_state = `TCC_OUT_HMAC;
            end
         end
      end
     `TCC_OUT_HMAC:
      begin
        if( tsha1_ready_o )
         begin
           hash_value_w = tsha1_hash_o;
           hashWrEn_w   = 1'b1;
           output_cnt_w = output_cnt_r + 1'b1;
         end
        else if( output_cnt_r != 5'd0 )
         begin
           output_cnt_w = output_cnt_r + 1'b1;
           hash_value_w = { hash_value_r[151:0], 8'd0 };
           if( output_cnt_r == 5'd10 )
            begin
              txStart_w  = 1'b1;
            end
           else if( output_cnt_r == 5'd20 )
            begin
              output_cnt_w   = 5'd0;
              hashWrEn_w     = 1'b0;
              if( !itpFifoEmpty )
               begin
                 itpRdEn_w      = 1'b1;
                 tcc_next_state = `TCC_LOAD_TYPE;
               end
              else
               begin
                 tcc_next_state = `TCC_IDLE;
               end                   
            end
         end
      end
     `TCC_U_HASH_L:
      begin
        if( exe_cnt_r == exe_bnd_r )
         begin
           if( load_done_r == 1'b1 )
            begin
              case( exe_cnt_r )
               2'd0: inst_w = { {(`INST_LENGTH-192){1'b0}}, inst_r[207:160], 144'd0 };
               2'd1: inst_w = { {(`INST_LENGTH-192){1'b0}}, inst_r[ 95:  0],  96'd0 };
               2'd2: inst_w = { {(`INST_LENGTH-192){1'b0}}, inst_r[143:  0],  48'd0 };
               2'd3: inst_w = { {(`INST_LENGTH-192){1'b0}}, inst_r[191:  0]         };
              endcase
              if( exe_bnd_r == 2'd0 )
               begin
                 tcc_next_state   = `TCC_CHECK_U_1;
                 update_cnt_w     = 2'd0;
               end
            end
           else if( addr_cnt_r == { {(CACHE_ADDR_WIDTH-2){1'b0}}, 2'd2 } )
            begin
              tcc_next_state   = `TCC_CHECK_U_1;
              exe_cnt_w        = 2'd0;
              update_cnt_w     = 2'd0;
            end
         end
        else
         begin
           exe_cnt_w      = exe_cnt_r + 1'b1;
           tcc_next_state = `TCC_U_LOAD_1;
           instRdEn_w     = 1'b1;
           load_cnt_w     = `LOAD_CYCLE_U;
           if( exe_cnt_r == 2'd0 )
            begin
              inst_w      = { {(`INST_LENGTH-48){1'b0}}, inst_r[207:160]};
            end
         end
      end
     `TCC_CHECK_U_1:
      begin
        if( !tsha1_busy_o )
         begin
           if( exe_cnt_r == exe_bnd_r )
            begin
              if( !update_verify_check | !update_entry1_check | !update_path_check )
               begin
                 clear_w        = 1'b1;
                 tcc_next_state = `TCC_RESET_CACHE;
                 exe_cnt_w      = 2'd0;
               end
              else
               begin
                 tsha1_start_i  = 1'b1;
                 case( update_cnt_r )
                  2'd0: update_par_entry_buf_w = { {CACHE_ADDR_UNUSE{1'b0}}, update_par_entry1, 48'd0 };
                  2'd1: update_par_entry_buf_w = { update_par_entry_buf_r[15:0], {CACHE_ADDR_UNUSE{1'b0}}, update_par_entry1, 32'd0 };
                  2'd2: update_par_entry_buf_w = { update_par_entry_buf_r[31:0], {CACHE_ADDR_UNUSE{1'b0}}, update_par_entry1, 16'd0 };
                  2'd3: update_par_entry_buf_w = { update_par_entry_buf_r[47:0], {CACHE_ADDR_UNUSE{1'b0}}, update_par_entry1 };
                 endcase
                 instRdEn_w     = 1'b1;
                 tcc_next_state = `TCC_U_LOAD_2;
                 exe_cnt_w      = 2'd0;
                 if( update_cur_is_right )
                   tsha1_data_w  = { update_nei_cache[162:3], update_cur_hash1, 192'h800000000000000000000000000000000000000000000140 };
                 else
                   tsha1_data_w  = { update_cur_hash1, update_nei_cache[162:3], 192'h800000000000000000000000000000000000000000000140 };
               end
            end
           else //there are at least 2 sets left
            begin
              if( !update_check_total )
               begin
                 clear_w        = 1'b1;
                 tcc_next_state = `TCC_RESET_CACHE;
                 exe_cnt_w      = 2'd0;
               end
              else if( update_nei_entry1 == update_cur_entry2 )  //common parent
               begin
                 if( !update_check_common )
                  begin
                    clear_w        = 1'b1;
                    tcc_next_state = `TCC_RESET_CACHE;
                    exe_cnt_w      = 2'd0;
                  end
                 else
                  begin
                    tsha1_start_i  = 1'b1;
                    if( update_cur_is_right )
                      tsha1_data_w  = { update_cur_hash2, update_cur_hash1, 192'h800000000000000000000000000000000000000000000140 };
                    else
                      tsha1_data_w  = { update_cur_hash1, update_cur_hash2, 192'h800000000000000000000000000000000000000000000140 };
                    case( exe_cnt_r )  //position of the merged set - 1
                     2'd0: update_merge_w[0] = 1'b1;
                     2'd1: update_merge_w[1] = 1'b1;
                     2'd2: update_merge_w[2] = 1'b1;
                     default:; 
                    endcase
                    if( exe_cnt_r == (exe_bnd_r - 1'b1) ) // no set left
                     begin
                       instRdEn_w     = 1'b1;
                       tcc_next_state = `TCC_U_LOAD_2;
                       exe_cnt_w      = 2'd0;
                       case( update_cnt_r )
                         2'd0: update_par_entry_buf_w = { {CACHE_ADDR_UNUSE{1'b0}}, update_par_entry1, 48'd0 };
                         2'd1: update_par_entry_buf_w = { update_par_entry_buf_r[15:0], {CACHE_ADDR_UNUSE{1'b0}}, update_par_entry1, 32'd0 };
                         2'd2: update_par_entry_buf_w = { update_par_entry_buf_r[31:0], {CACHE_ADDR_UNUSE{1'b0}}, update_par_entry1, 16'd0 };
                         2'd3: update_par_entry_buf_w = { update_par_entry_buf_r[47:0], {CACHE_ADDR_UNUSE{1'b0}}, update_par_entry1 };
                       endcase
                     end
                    else
                     begin
                       update_cnt_w             = update_cnt_r + 1'b1;
                       update_par_entry_buf_w   = { update_par_entry_buf_r[47:0], {CACHE_ADDR_UNUSE{1'b0}}, update_par_entry1 };
                       exe_cnt_w                = exe_cnt_r + 2'd2;
                       inst_w                   = { {(`INST_LENGTH-192){1'b0}}, inst_r[ 95:  0],  96'd0 };
                     end
                  end
               end
              else //no common parents
               begin
                 tsha1_start_i          = 1'b1;
                 update_cnt_w           = update_cnt_r + 1'b1; 
                 update_par_entry_buf_w = { update_par_entry_buf_r[47:0],{CACHE_ADDR_UNUSE{1'b0}}, update_par_entry1 };
                 exe_cnt_w              = exe_cnt_r + 1'b1;
                 inst_w                 = { {(`INST_LENGTH-192){1'b0}}, inst_r[143:  0],  48'd0 };
                 if( update_cur_is_right )
                   tsha1_data_w  = { update_nei_cache[162:3], update_cur_hash1, 192'h800000000000000000000000000000000000000000000140 };
                 else
                   tsha1_data_w  = { update_cur_hash1, update_nei_cache[162:3], 192'h800000000000000000000000000000000000000000000140 };
               end              
            end
         end
      end
     `TCC_EXECUTE_U:
      begin
        if( tsha1_ready_o )
         begin
           if( end_of_update_r )  
            begin
              end_of_update_w   = 1'b0;
              update_merge_w    = 2'd0;
              if( !itpFifoEmpty )
               begin
                 itpRdEn_w      = 1'b1;
                 tcc_next_state = `TCC_LOAD_TYPE;
               end
              else
               begin
                 tcc_next_state = `TCC_IDLE;
               end
            end
           else
            begin
              tcc_next_state = `TCC_CHECK_U_2;
              if( update_wait_r == 2'd1 )
               begin
                 update_wait_w   = 2'd2;
               end
            end
         end
      end
     `TCC_U_LOAD_1:
      begin
        if( instFifoValid )
         begin
           load_cnt_w = load_cnt_r - 1'b1 ;
           if( load_cnt_r == 4'd7 )
             inst_w  = {inst_r[`INST_LENGTH-17:0], instIn[15:0] };
           else if( load_cnt_r == 4'd6 )
             inst_w  = {inst_r[`INST_LENGTH-33:0], instIn};
           else
            begin
              hash_value_w = {hash_value_r[127:0], instIn};
              if( load_cnt_r == 4'd1 )
               begin
                 instRdEn_w     = 1'b0;
                 tcc_next_state = `TCC_U_HASH_L;
               end
            end
         end
      end
     `TCC_U_LOAD_2:
      begin
        if( end_of_update_r )
         begin
           tcc_next_state = `TCC_EXECUTE_U;
         end
        else if( exe_cnt_r == 2'd0 )
         begin
           pre_update_cnt_w = update_cnt_r;           
         end
        if( instFifoValid )
         begin
           exe_cnt_w  = exe_cnt_r + 1'b1;
           if( exe_cnt_r == exe_bnd_r )
            begin
              instRdEn_w     = 1'b0;
              tcc_next_state = `TCC_EXECUTE_U;
              update_cnt_w   = 2'd0;
              exe_cnt_w      = 2'd0;
              if( update_is_merged )
               begin
                 case( update_cnt_r )
                   2'd0: begin update_par_entry_buf_w = { update_par_entry_buf_r[15:0], 48'd0 }; inst_w = { {(`INST_LENGTH-192){1'b0}}, inst_r[ 47:0], 144'd0 }; end
                   2'd1: begin update_par_entry_buf_w = { update_par_entry_buf_r[31:0], 32'd0 }; inst_w = { {(`INST_LENGTH-192){1'b0}}, inst_r[ 95:0],  96'd0 }; end
                   2'd2: begin update_par_entry_buf_w = { update_par_entry_buf_r[47:0], 16'd0 }; inst_w = { {(`INST_LENGTH-192){1'b0}}, inst_r[143:0],  48'd0 }; end
                   2'd3: begin update_par_entry_buf_w = { update_par_entry_buf_r[47:0], 16'd0 }; inst_w = { {(`INST_LENGTH-192){1'b0}}, inst_r[191:0]         }; end                   
                   default:;
                 endcase
               end
              else
               begin
                 case( update_cnt_r )
                   2'd0: begin update_par_entry_buf_w = { update_par_entry_buf_r[63:48], 48'd0 };                                 inst_w = { {(`INST_LENGTH-192){1'b0}},                update_par_entry_buf_r[63:48], instIn, 144'd0 }; end
                   2'd1: begin update_par_entry_buf_w = { update_par_entry_buf_r[15: 0], update_par_entry_buf_r[63:48], 32'd0 };  inst_w = { {(`INST_LENGTH-192){1'b0}}, inst_r[ 47:0], update_par_entry_buf_r[63:48], instIn,  96'd0 }; end
                   2'd2: begin update_par_entry_buf_w = { update_par_entry_buf_r[31: 0], update_par_entry_buf_r[63:48], 16'd0 };  inst_w = { {(`INST_LENGTH-192){1'b0}}, inst_r[ 95:0], update_par_entry_buf_r[63:48], instIn,  48'd0 }; end
                   2'd3: begin update_par_entry_buf_w = { update_par_entry_buf_r[47: 0], update_par_entry_buf_r[63:48] };         inst_w = { {(`INST_LENGTH-192){1'b0}}, inst_r[143:0], update_par_entry_buf_r[63:48], instIn         }; end
                 endcase
               end
            end
           else if( !update_is_merged )
            begin
              inst_w = {inst_r[`INST_LENGTH-49:0], update_par_entry_buf_r[63:48], instIn};
              update_par_entry_buf_w = { update_par_entry_buf_r[47:0], update_par_entry_buf_r[63:48] };
            end
         end
      end      
     `TCC_CHECK_U_2:
      begin
        if( update_is_merged )
         begin
           exe_cnt_w  = update_next_exe;
         end
        else if( !tsha1_busy_o )
         begin
           if( update_exe_cnt_r == pre_update_cnt_r )
            begin
              if( !update_verify_check | !update_entry1_check | !update_path_check )
               begin
                 clear_w          = 1'b1;
                 tcc_next_state   = `TCC_RESET_CACHE;
                 exe_cnt_w        = 2'd0;
                 update_exe_cnt_w = 2'd0;
               end
              else
               begin
                 tsha1_start_i   = 1'b1;
                 case( update_cnt_r )
                  2'd0: update_par_entry_buf_w = { {CACHE_ADDR_UNUSE{1'b0}}, update_par_entry1, 48'd0 };
                  2'd1: update_par_entry_buf_w = { update_par_entry_buf_r[15:0], {CACHE_ADDR_UNUSE{1'b0}}, update_par_entry1, 32'd0 };
                  2'd2: update_par_entry_buf_w = { update_par_entry_buf_r[31:0], {CACHE_ADDR_UNUSE{1'b0}}, update_par_entry1, 16'd0 };
                  2'd3: update_par_entry_buf_w = { update_par_entry_buf_r[47:0], {CACHE_ADDR_UNUSE{1'b0}}, update_par_entry1 };
                 endcase
                 if( update_par_entry1 == 16'd0 ) //reach root hash
                  begin
                    end_of_update_w = 1'b1;
                  end
                 else
                  begin
                    instRdEn_w       = 1'b1;
                  end
                 tcc_next_state   = `TCC_U_LOAD_2;                  
                 exe_cnt_w        = 2'd0;
                 update_exe_cnt_w = 2'd0;
                 
                 if( update_cur_is_right )
                   tsha1_data_w  = { update_nei_cache[162:3], update_cur_hash1, 192'h800000000000000000000000000000000000000000000140 };
                 else
                   tsha1_data_w  = { update_cur_hash1, update_nei_cache[162:3], 192'h800000000000000000000000000000000000000000000140 };
               end
            end
           else //there are at least 2 sets left
            begin
              if( !update_check_total )
               begin
                 clear_w          = 1'b1;
                 tcc_next_state   = `TCC_RESET_CACHE;
                 exe_cnt_w        = 2'd0;
                 update_exe_cnt_w = 2'd0;                 
               end
              else if( update_nei_entry1 == update_cur_entry2 )  //common parent
               begin
                 if( !update_check_common )
                  begin
                    clear_w          = 1'b1;
                    tcc_next_state   = `TCC_RESET_CACHE;
                    exe_cnt_w        = 2'd0;
                    update_exe_cnt_w = 2'd0;                    
                  end
                 else
                  begin
                    if( update_wait_r == 2'd0 )
                     begin
                       tcc_next_state  = `TCC_EXECUTE_U;
                       update_wait_w   = 2'd1;
                     end
                    else if( update_wait_r == 2'd2 )
                     begin
                       update_wait_w  = 2'd0;
                       tsha1_start_i  = 1'b1;
                       if( update_cur_is_right )
                         tsha1_data_w  = { update_cur_hash2, update_cur_hash1, 192'h800000000000000000000000000000000000000000000140 };
                       else
                         tsha1_data_w  = { update_cur_hash1, update_cur_hash2, 192'h800000000000000000000000000000000000000000000140 };
                       case( update_next_exe )  //position of the merged set - 1
                        2'd1: update_merge_w[0] = 1'b1;
                        2'd2: update_merge_w[1] = 1'b1;
                        2'd3: update_merge_w[2] = 1'b1;
                        default:; 
                       endcase
                       if( update_exe_cnt_r  == ( pre_update_cnt_r - 1'b1 ) ) // no set left
                        begin
                          if( update_par_entry1 == 16'd0 ) //reach root hash
                           begin
                             end_of_update_w = 1'b1;
                           end
                          else
                           begin
                             instRdEn_w       = 1'b1;
                           end                        
                          tcc_next_state   = `TCC_U_LOAD_2;
                          exe_cnt_w        = 2'd0;
                          update_exe_cnt_w = 2'd0;
                          case( update_cnt_r )
                           2'd0: update_par_entry_buf_w = { {CACHE_ADDR_UNUSE{1'b0}}, update_par_entry1, 48'd0 };
                           2'd1: update_par_entry_buf_w = { update_par_entry_buf_r[15:0], {CACHE_ADDR_UNUSE{1'b0}}, update_par_entry1, 32'd0 };
                           2'd2: update_par_entry_buf_w = { update_par_entry_buf_r[31:0], {CACHE_ADDR_UNUSE{1'b0}}, update_par_entry1, 16'd0 };
                           2'd3: update_par_entry_buf_w = { update_par_entry_buf_r[47:0], {CACHE_ADDR_UNUSE{1'b0}}, update_par_entry1 };
                          endcase
                        end
                       else
                        begin
                          update_par_entry_buf_w   = { update_par_entry_buf_r[47:0], {CACHE_ADDR_UNUSE{1'b0}}, update_par_entry1 };
                          update_cnt_w             = update_cnt_r + 1'b1;
                          update_exe_cnt_w         = update_exe_cnt_r + 2'd2;
                          exe_cnt_w                = update_next_exe;
                          inst_w                   = { {(`INST_LENGTH-192){1'b0}}, inst_r[95:0],  96'd0 };
                          tcc_next_state           = `TCC_EXECUTE_U;
                        end
                     end

                  end
               end
              else //no common parents
               begin
                 update_cnt_w           = update_cnt_r + 1'b1;
                 update_exe_cnt_w       = update_exe_cnt_r + 1'b1;
                 exe_cnt_w              = update_next_exe;
                 update_par_entry_buf_w = { update_par_entry_buf_r[47:0], {CACHE_ADDR_UNUSE{1'b0}}, update_par_entry1 };
                 inst_w                 = { {(`INST_LENGTH-192){1'b0}}, inst_r[143:0],  48'd0 };
                 tcc_next_state         = `TCC_EXECUTE_U;
                 tsha1_start_i   = 1'b1;
                 if( update_cur_is_right )
                   tsha1_data_w  = { update_nei_cache[162:3], update_cur_hash1, 192'h800000000000000000000000000000000000000000000140 };
                 else
                   tsha1_data_w  = { update_cur_hash1, update_nei_cache[162:3], 192'h800000000000000000000000000000000000000000000140 };
               end
            end
         end
      end
     default:;
   endcase 
 end


//read and write the cache memory
always @ (*)
 begin
   tCache_wea_w = tCache_wea_r;
   tCache_web_w = tCache_web_r;
   tCache_ena_w = tCache_ena_r;
   tCache_enb_w = tCache_enb_r;
   tCache_addra = {CACHE_ADDR_WIDTH{1'b0}};
   tCache_addrb = {CACHE_ADDR_WIDTH{1'b0}};
   tCache_dina  = {DATA_WIDTH{1'b0}};
   tCache_dinb  = {DATA_WIDTH{1'b0}};   
   addr_cnt_w   = addr_cnt_r;
   cache_p_w    = cache_p_r;
   cache_l_w    = cache_l_r;
   cache_r_w    = cache_r_r;
   load_done_w  = load_done_r;
   write_done_w = write_done_r;
   inst_load1_w = inst_load1_r;
   inst_load2_w = inst_load2_r;   
   
   case(tcc_current_state)
     `TCC_RESET_CACHE:
      begin
        tCache_wea_w = 1'b1;
        tCache_web_w = 1'b1;
        tCache_ena_w = 1'b1;
        tCache_enb_w = 1'b1;
        addr_cnt_w   = addr_cnt_r + 1'b1;
        tCache_addra = { addr_cnt_r[CACHE_ADDR_WIDTH-2:0], 1'b0 };
        tCache_addrb = { addr_cnt_r[CACHE_ADDR_WIDTH-2:0], 1'b1 };
        if( addr_cnt_r == { 1'b0, {(CACHE_ADDR_WIDTH-1){1'b1}} } )
         begin
           addr_cnt_w = {CACHE_ADDR_WIDTH{1'b0}};
         end
      end
     `TCC_IDLE:
      begin
        tCache_wea_w = 1'b0;
        tCache_web_w = 1'b0;
        tCache_ena_w = 1'b0;
        tCache_enb_w = 1'b0;
        inst_load1_w = 2'd0;
        inst_load2_w = 2'd0;
      end
     `TCC_LOAD_TYPE:
      begin
        tCache_wea_w = 1'b0;
        tCache_web_w = 1'b0;
        tCache_ena_w = 1'b0;
        tCache_enb_w = 1'b0;
        inst_load1_w = 2'd0;
        inst_load2_w = 2'd0;
      end
     `TCC_LOAD:
      begin
        case( inst_type_r )
          `TC_LOAD:
           begin
             if( load_cnt_r == 4'd6 && inst_load1_r == 2'd0 )
              begin
                tCache_ena_w = 1'b1;
                tCache_enb_w = 1'b1;
                tCache_addra = inst_r[16+CACHE_ADDR_WIDTH-1:16];
                tCache_addrb = inst_r[   CACHE_ADDR_WIDTH-1: 0];
                inst_load1_w = 2'd1;
              end
             if( inst_load1_r == 2'd1 )
              begin
                cache_r_w    = tCache_douta;
                cache_p_w    = tCache_doutb;
                tCache_ena_w = 1'b0;
                tCache_enb_w = 1'b0;
                inst_load1_w = 2'd2;
              end
           end
          `TC_VERIFY1: 
            begin
             if( load_cnt_r == 4'd1 && inst_load1_r == 2'd0 )
              begin
                tCache_ena_w = 1'b1;
                tCache_enb_w = 1'b1;
                tCache_addra = inst_r[16+CACHE_ADDR_WIDTH-1:16];
                tCache_addrb = inst_r[   CACHE_ADDR_WIDTH-1: 0];
                load_done_w  = 1'b0;
                inst_load1_w = 2'd1;
              end
             if( inst_load1_r == 2'd1 )
              begin
                cache_r_w    = tCache_douta;
                cache_l_w    = tCache_doutb;
                tCache_ena_w = 1'b0;
                tCache_enb_w = 1'b0;
                inst_load1_w = 2'd2;
              end
            end
          `TC_VERIFY2:
            begin
             if( load_cnt_r == 4'd2 && inst_load1_r == 2'd0  )
              begin
                tCache_ena_w = 1'b1;
                tCache_enb_w = 1'b1;
                tCache_addra = inst_r[16+CACHE_ADDR_WIDTH-1:16];
                tCache_addrb = inst_r[   CACHE_ADDR_WIDTH-1: 0];
                inst_load1_w = 2'd1;
              end
             else if( load_cnt_r == 4'd1 && inst_load2_r == 2'd0 )
              begin
                if( inst_load1_r == 2'd2 )
                 begin
                   tCache_ena_w = 1'b1;
                 end
                tCache_addra = inst_r[16+CACHE_ADDR_WIDTH-1:16];
                load_done_w  = 1'b0;
                inst_load2_w = 2'd1;
              end
             if( inst_load1_r == 2'd1 )
              begin
                cache_r_w    = tCache_douta;
                cache_l_w    = tCache_doutb;
                if( load_cnt_r != 4'd1 )
                 begin
                   tCache_ena_w = 1'b0;
                 end
                tCache_enb_w = 1'b0;
                inst_load1_w = 2'd2;
              end
             else if( inst_load2_r == 2'd1 )
              begin
                tCache_ena_w = 1'b0;
                cache_p_w    = tCache_douta;
                inst_load2_w = 2'd2;
              end
            end
          `TC_VERIFY3:
            begin
             if( load_cnt_r == 4'd4  && inst_load1_r == 2'd0 )
              begin
                tCache_ena_w = 1'b1;
                tCache_enb_w = 1'b1;
                tCache_addra = inst_r[16+CACHE_ADDR_WIDTH-1:16];
                tCache_addrb = inst_r[   CACHE_ADDR_WIDTH-1: 0];
                inst_load1_w = 2'd1;                
              end
             else if( load_cnt_r == 4'd3 && inst_load2_r == 2'd0  )
              begin
                if( inst_load1_r == 2'd2 )
                 begin
                   tCache_ena_w = 1'b1;
                 end              
                tCache_addra = inst_r[16+CACHE_ADDR_WIDTH-1:16]; 
                inst_load2_w = 2'd1;                
              end
             if( inst_load1_r == 2'd1 )
              begin
                cache_r_w    = tCache_douta;
                cache_l_w    = tCache_doutb;
                if( load_cnt_r != 4'd3 )
                 begin
                   tCache_ena_w = 1'b0;
                 end
                tCache_enb_w = 1'b0;
                inst_load1_w = 2'd2;
              end
             else if( inst_load2_r == 2'd1 )
              begin
                tCache_ena_w = 1'b0;
                cache_p_w    = tCache_douta;
                inst_load2_w = 2'd2;
                load_done_w  = 1'b1;
              end
            end
          `TC_VERIFY4:
            begin
             if( load_cnt_r == 4'd5  && inst_load1_r == 2'd0 )
              begin
                tCache_ena_w = 1'b1;
                tCache_enb_w = 1'b1;
                tCache_addra = inst_r[16+CACHE_ADDR_WIDTH-1:16];
                tCache_addrb = inst_r[   CACHE_ADDR_WIDTH-1: 0];
                inst_load1_w = 2'd1;                
              end
             else if( load_cnt_r == 4'd4 && inst_load2_r == 2'd0  )
              begin
                if( inst_load1_r == 2'd2 )
                 begin
                   tCache_ena_w = 1'b1;
                 end              
                tCache_addra = inst_r[16+CACHE_ADDR_WIDTH-1:16]; 
                inst_load2_w = 2'd1;                
              end
             if( inst_load1_r == 2'd1 )
              begin
                cache_r_w    = tCache_douta;
                cache_l_w    = tCache_doutb;
                if( load_cnt_r != 4'd4 )
                 begin
                   tCache_ena_w = 1'b0;
                 end
                tCache_enb_w = 1'b0;
                inst_load1_w = 2'd2;
              end
             else if( inst_load2_r == 2'd1 )
              begin
                tCache_ena_w = 1'b0;
                cache_p_w    = tCache_douta;
                inst_load2_w = 2'd2;
                load_done_w  = 1'b1;
              end              
            end            
          `TC_HMAC:
            begin
             if( load_cnt_r == 4'd8 && inst_load1_r == 2'd0 )
              begin
                tCache_ena_w = 1'b1;
                tCache_addra = inst_r[16+CACHE_ADDR_WIDTH-1:16];
                inst_load1_w = 2'd1; 
              end
             if( inst_load1_r == 2'd1 )
              begin
                tCache_ena_w = 1'b0;
                cache_r_w    = tCache_douta;
                inst_load1_w = 2'd2;
              end
            end
          `TC_UPDATE1:
           begin
             if( load_cnt_r == 4'd6  && inst_load1_r == 2'd0 )
              begin
                tCache_ena_w = 1'b1;
                tCache_addra = inst_r[   CACHE_ADDR_WIDTH-1: 0]; 
                inst_load1_w = 2'd1;                
              end
             else if( load_cnt_r == 4'd5 && inst_load2_r == 2'd0  )
              begin
                if( inst_load1_r == 2'd2 )
                 begin
                   tCache_ena_w = 1'b1;
                 end              
                tCache_enb_w = 1'b1;
                tCache_addra = inst_r[   CACHE_ADDR_WIDTH-1: 0];
                tCache_addrb = inst_r[16+CACHE_ADDR_WIDTH-1:16];
                inst_load2_w = 2'd1;                
              end
             if( inst_load1_r == 2'd1 )
              begin
                cache_r_w    = tCache_douta;
                if( load_cnt_r != 4'd5 )
                 begin
                   tCache_ena_w = 1'b0;
                 end
                inst_load1_w = 2'd2;
              end
             else if( inst_load2_r == 2'd1 )
              begin
                cache_p_w    = tCache_douta;
                cache_l_w    = tCache_doutb;
                tCache_ena_w = 1'b0;
                tCache_enb_w = 1'b0;
                inst_load2_w = 2'd2;
                load_done_w  = 1'b1;
              end
           end
          `TC_UPDATE2:
           begin
             if( load_cnt_r == 4'd6  && inst_load1_r == 2'd0 )
              begin
                tCache_ena_w = 1'b1;
                tCache_addra = inst_r[   CACHE_ADDR_WIDTH-1: 0]; 
                inst_load1_w = 2'd1;                
              end
             else if( load_cnt_r == 4'd5 && inst_load2_r == 2'd0  )
              begin
                if( inst_load1_r == 2'd2 )
                 begin
                   tCache_ena_w = 1'b1;
                 end              
                tCache_enb_w = 1'b1;
                tCache_addra = inst_r[   CACHE_ADDR_WIDTH-1: 0];
                tCache_addrb = inst_r[16+CACHE_ADDR_WIDTH-1:16];
                inst_load2_w = 2'd1;                
              end
             if( inst_load1_r == 2'd1 )
              begin
                cache_r_w    = tCache_douta;
                if( load_cnt_r != 4'd5 )
                 begin
                   tCache_ena_w = 1'b0;
                 end
                inst_load1_w = 2'd2;
              end
             else if( inst_load2_r == 2'd1 )
              begin
                cache_p_w    = tCache_douta;
                cache_l_w    = tCache_doutb;
                tCache_ena_w = 1'b0;
                tCache_enb_w = 1'b0;
                inst_load2_w = 2'd2;
                load_done_w  = 1'b1;
              end
           end
          `TC_UPDATE3:
           begin
             if( load_cnt_r == 4'd6  && inst_load1_r == 2'd0 )
              begin
                tCache_ena_w = 1'b1;
                tCache_addra = inst_r[   CACHE_ADDR_WIDTH-1: 0]; 
                inst_load1_w = 2'd1;                
              end
             else if( load_cnt_r == 4'd5 && inst_load2_r == 2'd0  )
              begin
                if( inst_load1_r == 2'd2 )
                 begin
                   tCache_ena_w = 1'b1;
                 end              
                tCache_enb_w = 1'b1;
                tCache_addra = inst_r[   CACHE_ADDR_WIDTH-1: 0];
                tCache_addrb = inst_r[16+CACHE_ADDR_WIDTH-1:16];
                inst_load2_w = 2'd1;                
              end
             if( inst_load1_r == 2'd1 )
              begin
                cache_r_w    = tCache_douta;
                if( load_cnt_r != 4'd5 )
                 begin
                   tCache_ena_w = 1'b0;
                 end
                inst_load1_w = 2'd2;
              end
             else if( inst_load2_r == 2'd1 )
              begin
                cache_p_w    = tCache_douta;
                cache_l_w    = tCache_doutb;
                tCache_ena_w = 1'b0;
                tCache_enb_w = 1'b0;
                inst_load2_w = 2'd2;
                load_done_w  = 1'b1;
              end
           end
          `TC_UPDATE4:
           begin
             if( load_cnt_r == 4'd6  && inst_load1_r == 2'd0 )
              begin
                tCache_ena_w = 1'b1;
                tCache_addra = inst_r[   CACHE_ADDR_WIDTH-1: 0]; 
                inst_load1_w = 2'd1;                
              end
             else if( load_cnt_r == 4'd5 && inst_load2_r == 2'd0  )
              begin
                if( inst_load1_r == 2'd2 )
                 begin
                   tCache_ena_w = 1'b1;
                 end              
                tCache_enb_w = 1'b1;
                tCache_addra = inst_r[   CACHE_ADDR_WIDTH-1: 0];
                tCache_addrb = inst_r[16+CACHE_ADDR_WIDTH-1:16];
                inst_load2_w = 2'd1;                
              end
             if( inst_load1_r == 2'd1 )
              begin
                cache_r_w    = tCache_douta;
                if( load_cnt_r != 4'd5 )
                 begin
                   tCache_ena_w = 1'b0;
                 end
                inst_load1_w = 2'd2;
              end
             else if( inst_load2_r == 2'd1 )
              begin
                cache_p_w    = tCache_douta;
                cache_l_w    = tCache_doutb;
                tCache_ena_w = 1'b0;
                tCache_enb_w = 1'b0;
                inst_load2_w = 2'd2;
                load_done_w  = 1'b1;
              end
           end
           default:;
         endcase
      end
     `TCC_EXECUTE_L:
      begin
        if( load_check_1 )
         begin
           tCache_wea_w = 1'b1;
           tCache_ena_w = 1'b1;
           tCache_addra = load_cur_entry;
           tCache_dina  = { load_node_id, load_node_hash, 3'd0 };
           if( old_cache_content[2] ) //verified
            begin
              if( load_check_2 )
               begin
                 tCache_web_w = 1'b1;
                 tCache_enb_w = 1'b1;
                 tCache_addrb = load_par_entry;
                 if( old_node_id[0] ) //right_child
                  begin
                    tCache_dinb = { cache_p_r[DATA_WIDTH-1:1], 1'b0 };
                  end
                 else //left_child
                  begin
                    tCache_dinb = { cache_p_r[DATA_WIDTH-1:2], 1'b0, cache_p_r[0] };
                  end
               end
            end
         end
      end
     `TCC_CHECK_V:
      begin
        write_done_w = 1'b1;
        if( load_done_r == 1'b0 )
         begin
           if( exe_cnt_r == 2'd0 )
            begin
              if( inst_type_r == `TC_VERIFY1 )
               begin
                 if( addr_cnt_r == {CACHE_ADDR_WIDTH{1'b0}} )
                  begin
                    if( inst_load1_r == 2'd1 )
                     begin
                       cache_r_w    = tCache_douta;
                       cache_l_w    = tCache_doutb;
                       tCache_enb_w = 1'b0;
                     end
                    else
                     begin
                       tCache_ena_w = 1'b1;
                     end
                    tCache_addra = verify_p_entry1;
                    addr_cnt_w   = addr_cnt_r + 1'b1;
                  end
                 else
                  begin
                    tCache_ena_w = 1'b0;
                    cache_p_w    = tCache_douta;
                    load_done_w  = 1'b1;
                    addr_cnt_w   = {CACHE_ADDR_WIDTH{1'b0}};
                  end
               end
              else if( inst_type_r == `TC_VERIFY2 )
               begin
                 if( inst_load2_r == 2'd1 )
                  begin
                    tCache_ena_w = 1'b0;
                    cache_p_w    = tCache_douta;
                  end
                 load_done_w  = 1'b1;
               end
            end
           else
            begin
              addr_cnt_w = addr_cnt_r + 1'b1;
              if( addr_cnt_r == {CACHE_ADDR_WIDTH{1'b0}} )
               begin
                 tCache_ena_w = 1'b1;
                 tCache_enb_w = 1'b1;
                 tCache_addra = verify_r_entry;
                 tCache_addrb = verify_l_entry;
               end
              else if( addr_cnt_r == { {(CACHE_ADDR_WIDTH-1){1'b0}}, 1'b1 } )
               begin
                 cache_r_w    = tCache_douta;
                 cache_l_w    = tCache_doutb;
                 tCache_enb_w = 1'b0;
                 tCache_addra = verify_p_entry;             
               end
              else if( addr_cnt_r == { {(CACHE_ADDR_WIDTH-2){1'b0}}, 2'd2 } )
               begin
                 tCache_ena_w = 1'b0;
                 cache_p_w    = tCache_douta;
                 load_done_w  = 1'b1;
                 addr_cnt_w   = {CACHE_ADDR_WIDTH{1'b0}};
               end
            end
         end
        else if( !tsha1_busy_o )
         begin
           if( verify_check_total )
            begin
              load_done_w = 1'b0;
            end
         end
      end
     `TCC_EXECUTE_V:
      begin
        if( load_done_r == 1'b0 )
         begin
           tCache_wea_w = 1'b0;
           addr_cnt_w = addr_cnt_r + 1'b1;
           if( addr_cnt_r == {CACHE_ADDR_WIDTH{1'b0}} )
            begin
              tCache_ena_w = 1'b1;
              tCache_enb_w = 1'b1;
              tCache_addra = verify_r_entry;
              tCache_addrb = verify_l_entry;
            end
           else if( addr_cnt_r == { {(CACHE_ADDR_WIDTH-1){1'b0}}, 1'b1 } )
            begin
              cache_r_w    = tCache_douta;
              cache_l_w    = tCache_doutb;
              tCache_enb_w = 1'b0;
              tCache_addra = verify_p_entry;             
            end
           else if( addr_cnt_r == { {(CACHE_ADDR_WIDTH-2){1'b0}}, 2'd2 } )
            begin
              tCache_ena_w = 1'b0;
              cache_p_w    = tCache_douta;
              load_done_w  = 1'b1;
              addr_cnt_w   = {CACHE_ADDR_WIDTH{1'b0}};
            end
         end
        else if( tsha1_ready_o )
         begin
           if( tsha1_hash_o == verify_p_cache[162:3] )
            begin
              write_done_w = 1'b0;
            end
         end
        else if( write_done_r == 1'b0 )
         begin
           if( addr_cnt_r == {CACHE_ADDR_WIDTH{1'b0}} )
            begin
              addr_cnt_w   = addr_cnt_r + 1'b1;
              tCache_wea_w = 1'b1;
              tCache_web_w = 1'b1;
              tCache_ena_w = 1'b1;
              tCache_enb_w = 1'b1;
              tCache_addra = w_verify_r_entry;
              tCache_addrb = w_verify_l_entry;
              tCache_dina  = { cache_r_r[DATA_WIDTH-1:3], 1'b1, cache_r_r[1:0] };
              tCache_dinb  = { cache_l_r[DATA_WIDTH-1:3], 1'b1, cache_l_r[1:0] };
            end
           else
            begin
              addr_cnt_w   = {CACHE_ADDR_WIDTH{1'b0}};
              tCache_web_w = 1'b0;
              tCache_enb_w = 1'b0;
              tCache_wea_w = 1'b1;
              tCache_ena_w = 1'b1;
              tCache_addra = w_verify_p_entry;
              tCache_dina  = { cache_p_r[DATA_WIDTH-1:2], 2'b11 };
              write_done_w = 1'b1;
              load_done_w  = 1'b0;
            end
         end
      end
     `TCC_WRITE_V:
      begin
        if( addr_cnt_r == {CACHE_ADDR_WIDTH{1'b0}} )
         begin
           addr_cnt_w   = addr_cnt_r + 1'b1;
           tCache_wea_w = 1'b1;
           tCache_web_w = 1'b1;
           tCache_ena_w = 1'b1;
           tCache_enb_w = 1'b1;
           tCache_addra = w_verify_r_entry;
           tCache_addrb = w_verify_l_entry;
           tCache_dina  = { cache_r_r[DATA_WIDTH-1:3], 1'b1, cache_r_r[1:0] };
           tCache_dinb  = { cache_l_r[DATA_WIDTH-1:3], 1'b1, cache_l_r[1:0] };
         end
        else
         begin
           addr_cnt_w   = {CACHE_ADDR_WIDTH{1'b0}};
           tCache_web_w = 1'b0;
           tCache_enb_w = 1'b0;
           tCache_wea_w = 1'b1;
           tCache_ena_w = 1'b1;
           tCache_addra = w_verify_p_entry;
           tCache_dina  = { cache_p_r[DATA_WIDTH-1:2], 2'b11 };
           write_done_w = 1'b1;
         end
      end      
     `TCC_EXECUTE_RT:
      begin
        tCache_wea_w = 1'b1;
        tCache_ena_w = 1'b1;
        tCache_dina  = root_cache;
      end
     `TCC_U_HASH_L:
      begin
        inst_load1_w = 2'd0;
        inst_load2_w = 2'd0;
        if( load_done_r == 1'b0 )
         begin
           if( addr_cnt_r == {CACHE_ADDR_WIDTH{1'b0}} )
            begin
              tCache_wea_w = 1'b0;
              write_done_w = 1'b0;
              tCache_ena_w = 1'b1;
              tCache_addra = update_cur_entry1;
              addr_cnt_w   = addr_cnt_r + 1'b1;
            end
           else if( addr_cnt_r == { {(CACHE_ADDR_WIDTH-1){1'b0}}, 1'b1 } )
            begin
              cache_r_w    = tCache_douta;
              tCache_enb_w = 1'b1;
              tCache_addra = update_nei_entry1;
              tCache_addrb = update_par_entry1;
              addr_cnt_w   = addr_cnt_r + 1'b1;
            end
           else if( addr_cnt_r == { {(CACHE_ADDR_WIDTH-2){1'b0}}, 2'd2 } )
            begin
              tCache_ena_w = 1'b0;
              tCache_enb_w = 1'b0;
              cache_l_w    = tCache_douta;
              cache_p_w    = tCache_doutb;
              load_done_w  = 1'b1;
              addr_cnt_w   = {CACHE_ADDR_WIDTH{1'b0}};
            end
         end
        else if( exe_cnt_r == 2'd0 )
         begin
           tCache_wea_w = 1'b1;
           tCache_ena_w = 1'b1;
           write_done_w = 1'b1;
           tCache_addra = inst_r[ 192+CACHE_ADDR_WIDTH-1: 192];
           tCache_dina  = { cache_r_r[DATA_WIDTH-1:163], inst_r[ 159: 0], cache_r_r[2:0] };
           if( exe_cnt_r == exe_bnd_r )
            begin
              cache_r_w = { cache_r_r[DATA_WIDTH-1:163], inst_r[ 159: 0], cache_r_r[2:0] };
            end
         end
        else
         begin
           tCache_wea_w = 1'b1;
           tCache_ena_w = 1'b1;
           write_done_w = 1'b1;
           tCache_addra = inst_r[ 32+CACHE_ADDR_WIDTH-1: 32];
           tCache_dina  = { cache_r_r[DATA_WIDTH-1:163], hash_value_r, cache_r_r[2:0] };
           if( exe_cnt_r == exe_bnd_r )
            begin
              load_done_w = 1'b0;
            end
         end
      end
     `TCC_CHECK_U_1:
      begin
        if( write_done_r == 1'b1 )
         begin
           tCache_wea_w  = 1'b0;
           tCache_ena_w  = 1'b0;
           write_done_w  = 1'b0;
         end
        if( !tsha1_busy_o )
         begin
           load_done_w  = 1'b0;
         end
        else if( load_done_r == 1'b0 )
         begin
           if( addr_cnt_r == {CACHE_ADDR_WIDTH{1'b0}} )
            begin
              tCache_ena_w = 1'b1;
              tCache_addra = update_cur_entry1;
              addr_cnt_w   = addr_cnt_r + 1'b1;
            end
           else if( addr_cnt_r == { {(CACHE_ADDR_WIDTH-1){1'b0}}, 1'b1 } )
            begin
              cache_r_w    = tCache_douta;
              tCache_enb_w = 1'b1;
              tCache_addra = update_nei_entry1;
              tCache_addrb = update_par_entry1;
              addr_cnt_w   = addr_cnt_r + 1'b1;
            end
           else if( addr_cnt_r == { {(CACHE_ADDR_WIDTH-2){1'b0}}, 2'd2 } )
            begin
              tCache_ena_w = 1'b0;
              tCache_enb_w = 1'b0;
              cache_l_w    = tCache_douta;
              cache_p_w    = tCache_doutb;
              load_done_w  = 1'b1;
              addr_cnt_w   = {CACHE_ADDR_WIDTH{1'b0}};
            end
         end
      end
     `TCC_EXECUTE_U:
      begin
        if( load_done_r == 1'b0 && addr_cnt_r == { {(CACHE_ADDR_WIDTH-1){1'b0}}, 1'b1 } )
         begin
           addr_cnt_w   = addr_cnt_r + 1'b1;
           tCache_ena_w = 1'b0;
           cache_r_w    = tCache_douta;
           load_done_w  = 1'b1;
         end
        else if( addr_cnt_r == { {(CACHE_ADDR_WIDTH-2){1'b0}}, 2'd2 } )
         begin
           addr_cnt_w   = addr_cnt_r + 1'b1;
           tCache_ena_w = 1'b1;
           tCache_enb_w = 1'b1;
           tCache_addra = update_par_entry1;
           tCache_addrb = update_nei_entry1;
         end
        else if( addr_cnt_r == { {(CACHE_ADDR_WIDTH-2){1'b0}}, 2'd3 } )
         begin
           addr_cnt_w   = {CACHE_ADDR_WIDTH{1'b0}};
           tCache_ena_w = 1'b0;
           tCache_enb_w = 1'b0;
           cache_p_w    = tCache_douta;
           cache_l_w    = tCache_doutb;
         end
        else if( tsha1_ready_o )
         begin
           tCache_wea_w = 1'b1;
           tCache_ena_w = 1'b1;
           if( update_wait_r == 2'd1 )
            begin
              tCache_addra = update_nei_entry1;
              tCache_dina  = { cache_l_r[DATA_WIDTH-1:163], tsha1_hash_o, cache_l_r[2:0] };
              cache_l_w    = { cache_l_r[DATA_WIDTH-1:163], tsha1_hash_o, cache_l_r[2:0] };
            end
           else
            begin
              if( end_of_update_r )
                tCache_addra = update_par_entry1;
              else
                tCache_addra = update_cur_entry1;
              tCache_dina  = { cache_r_r[DATA_WIDTH-1:163], tsha1_hash_o, cache_r_r[2:0] };
              cache_r_w    = { cache_r_r[DATA_WIDTH-1:163], tsha1_hash_o, cache_r_r[2:0] };
            end
         end
      end
     `TCC_U_LOAD_1:
      begin
        if( write_done_r )
         begin
           tCache_ena_w = 1'b0;
           tCache_wea_w = 1'b0;
           write_done_w = 1'b0;
         end
        else
         begin
           if( load_cnt_r == 4'd6  && inst_load1_r == 2'd0 )
            begin
              tCache_ena_w = 1'b1;
              inst_load1_w = 2'd1;
              tCache_addra = inst_r[    CACHE_ADDR_WIDTH-1:   0];
            end
           else if( load_cnt_r == 4'd5 && inst_load2_r == 2'd0  )
            begin
              if( inst_load1_r == 2'd2 )
               begin
                 tCache_ena_w = 1'b1;
               end              
              tCache_enb_w = 1'b1;
              tCache_addra = inst_r[    CACHE_ADDR_WIDTH-1:   0];
              tCache_addrb = inst_r[ 16+CACHE_ADDR_WIDTH-1:  16];
              inst_load2_w = 2'd1;
            end
           if( inst_load1_r == 2'd1 )
            begin
              cache_r_w    = tCache_douta;
              if( load_cnt_r != 4'd5 )
               begin
                 tCache_ena_w = 1'b0;
               end
              inst_load1_w = 2'd2;
            end
           else if( inst_load2_r == 2'd1 )
            begin
              cache_p_w    = tCache_douta;
              cache_l_w    = tCache_doutb;
              tCache_ena_w = 1'b0;
              tCache_enb_w = 1'b0;
              inst_load2_w = 2'd2;
              load_done_w  = 1'b1;
            end
         end
      end
     `TCC_U_LOAD_2:
      begin
        if( load_done_r == 1'b0 )
         begin
           if( addr_cnt_r == {CACHE_ADDR_WIDTH{1'b0}} )
            begin
              addr_cnt_w   = addr_cnt_r + 1'b1;
              tCache_ena_w = 1'b1;
              tCache_addra = update_par_entry_buf_r[48+CACHE_ADDR_WIDTH-1:48];
            end
           else
            begin
              addr_cnt_w   = addr_cnt_r + 1'b1;
              tCache_ena_w = 1'b0;
              cache_r_w    = tCache_douta;
              load_done_w  = 1'b1;
            end
         end
      end
     `TCC_CHECK_U_2:
      begin
        tCache_wea_w = 1'b0;
        tCache_ena_w = 1'b0;
        if( update_is_merged == 1'b0 && tsha1_busy_o == 1'b0 )
         begin
           if( update_exe_cnt_r == pre_update_cnt_r )  //go to `TCC_U_LOAD_2
            begin
              load_done_w  = 1'b0;
            end
           else
            begin
              if( update_nei_entry1 == update_cur_entry2 ) //common parent
               begin
                 if( update_wait_r == 2'd2 )
                  begin
                    if( update_exe_cnt_r  == ( pre_update_cnt_r - 1'b1 ) ) //go to `TCC_U_LOAD_2
                     begin
                       load_done_w  = 1'b0;
                     end
                    else //go to `TCC_EXECUTE_U
                     begin
                       if( update_check_total & update_check_common )
                        begin
                         addr_cnt_w   = addr_cnt_r + 1'b1;
                         tCache_ena_w = 1'b1;
                         tCache_addra = inst_r[ 80 + CACHE_ADDR_WIDTH - 1 : 80];
                         load_done_w  = 1'b0;
                       end
                     end
                  end
               end
              else if( update_check_total ) //no common parents -> go to `TCC_EXECUTE_U
               begin
                 addr_cnt_w   = addr_cnt_r + 1'b1;
                 tCache_ena_w = 1'b1;
                 tCache_addra = update_cur_entry2;
                 load_done_w  = 1'b0;
               end         
            end
         end
      end
     default:;
   endcase
 end
 
 
always @ ( posedge clk or posedge reset )
 begin
   if(reset)
    begin
      tcc_current_state       <= `TCC_RESET_CACHE;
      inst_type_r             <= 8'd0;
      load_cnt_r              <= 4'd0;
      exe_cnt_r               <= 2'd0;
      exe_bnd_r               <= 2'd0;
      instRdEn_r              <= 1'b0;
      itpRdEn_r               <= 1'b0;
      inst_r                  <= `INST_LENGTH'd0; 
      tsha1_data_r            <= 512'd0;
      txStart_r               <= 1'b0;
      hashWrEn_r              <= 1'b0;
      hash_value_r            <= 160'd0;
      output_cnt_r            <= 5'd0;
      clear_r                 <= 1'b0;
      cache_p_r               <= {DATA_WIDTH{1'b0}};
      cache_l_r               <= {DATA_WIDTH{1'b0}};
      cache_r_r               <= {DATA_WIDTH{1'b0}};
      addr_cnt_r              <= {CACHE_ADDR_WIDTH{1'b0}};
      load_done_r             <= 1'b0;
      write_done_r            <= 1'b0;
      tCache_wea_r            <= 1'b0;
      tCache_web_r            <= 1'b0;
      tCache_ena_r            <= 1'b0;
      tCache_enb_r            <= 1'b0;
      inst_load1_r            <= 2'd0;
      inst_load2_r            <= 2'd0;
      update_par_entry_buf_r  <= 64'd0;
      update_merge_r          <= 3'd0;
      update_cnt_r            <= 2'd0;
      pre_update_cnt_r        <= 2'd0;
      update_wait_r           <= 2'd0;
      update_exe_cnt_r        <= 2'd0;
      end_of_update_r         <= 1'b0;      
    end
   else
    begin
      tcc_current_state       <= tcc_next_state;
      inst_type_r             <= inst_type_w;
      load_cnt_r              <= load_cnt_w;
      exe_cnt_r               <= exe_cnt_w;
      exe_bnd_r               <= exe_bnd_w;
      instRdEn_r              <= instRdEn_w;
      itpRdEn_r               <= itpRdEn_w;
      inst_r                  <= inst_w;
      tsha1_data_r            <= tsha1_data_w;
      txStart_r               <= txStart_w;
      hashWrEn_r              <= hashWrEn_w;
      hash_value_r            <= hash_value_w;
      output_cnt_r            <= output_cnt_w;
      clear_r                 <= clear_w;
      cache_p_r               <= cache_p_w;
      cache_l_r               <= cache_l_w;
      cache_r_r               <= cache_r_w;
      addr_cnt_r              <= addr_cnt_w;
      load_done_r             <= load_done_w;
      write_done_r            <= write_done_w;
      tCache_wea_r            <= tCache_wea_w;
      tCache_web_r            <= tCache_web_w;
      tCache_ena_r            <= tCache_ena_w;
      tCache_enb_r            <= tCache_enb_w;
      inst_load1_r            <= inst_load1_w;
      inst_load2_r            <= inst_load2_w;
      update_par_entry_buf_r  <= update_par_entry_buf_w;
      update_merge_r          <= update_merge_w;
      update_cnt_r            <= update_cnt_w;
      pre_update_cnt_r        <= pre_update_cnt_w;
      update_wait_r           <= update_wait_w;
      update_exe_cnt_r        <= update_exe_cnt_w;
      end_of_update_r         <= end_of_update_w;
    end
 end


treeSHA1 tsha1_gen( .clk    ( clk           ), 
                    .reset  ( reset         ), 
                    .start  ( tsha1_start_i ),
                    .msg    ( tsha1_data_w  ),
                    .hash   ( tsha1_hash_o  ),
                    .ready  ( tsha1_ready_o ),
                    .busy   ( tsha1_busy_o  )
                  );


treeCache u_cache( .clka       ( clk              ), 
                   .ena        ( tCache_ena_w     ), 
                   .wea        ( tCache_wea_w     ), 
                   .addra      ( tCache_addra     ), 
                   .dina       ( tCache_dina      ), 
                   .douta      ( tCache_douta     ),
                   .clkb       ( clk              ), 
                   .enb        ( tCache_enb_w     ), 
                   .web        ( tCache_web_w     ), 
                   .addrb      ( tCache_addrb     ), 
                   .dinb       ( tCache_dinb      ), 
                   .doutb      ( tCache_doutb     )
                 );
                  
endmodule
