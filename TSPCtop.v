`timescale 1ns / 1ps

module TSPCtop( CLKBN,
                CLKBP,
                FPGAreset,
                //GMII signals 
                GMII_TXD_0,
                GMII_TX_EN_0,
                GMII_TX_ER_0,
                GMII_TX_CLK_0,
                GMII_RXD_0,
                GMII_RX_DV_0,
                GMII_RX_CLK_0,
                GMII_RESET_B,
                LED,
                LED_ERR
              );

  input         CLKBN;
  input         CLKBP;
  input         FPGAreset; //low true
  output [7:0]  LED;
  output [1:0]  LED_ERR;
  
  //GMII signals 
  output [7:0]  GMII_TXD_0;
  output        GMII_TX_EN_0;
  output        GMII_TX_ER_0;
  output        GMII_TX_CLK_0;  //to PHY. Made in ODDR
  input  [7:0]  GMII_RXD_0;
  input         GMII_RX_DV_0;
  input         GMII_RX_CLK_0; //from PHY. Goes through BUFG
  output        GMII_RESET_B; 
  
  //Clocks
  wire clockIn;
  wire MCLK; 
  wire MCLKx;
  wire clock;
  wire clockx;
  wire ethTXclock;
  wire ethTXclockx;
  wire PLLBfb;
  wire pllLock;
  wire ctrlLock;
  wire reset;

  //cache tree control module
  wire          isFailed;

  assign reset   = ~FPGAreset  | ~pllLock | ~ctrlLock;
  assign LED     = { 6'd0, !isFailed, !isFailed };
  assign LED_ERR = { isFailed, isFailed };

  //ethernet receiver and transimtter
  wire          firstFrame;
  wire          lastFrame;
  
  //transmitter data FIFO  
  wire   [7:0]  txFifoIn;  
  wire          txWrEn;    
  wire          txFifoFull;
  
  //transmitter data FIFO from cache tree
  wire   [7:0]  tcFifoIn;  
  wire          tcWrEn;    
  wire          tcFifoFull;
  
  //transmitter frame info FIFO  
  reg   [11:0]  tfFifoIn_w,    tfFifoIn_r;
  reg           tfWrEn_w,      tfWrEn_r;
  reg           is_both_out_w, is_both_out_r;
  wire          tfFifoFull; 
  wire          txStart_db;
  wire          txStart_tc;
  wire  [10:0]  txByteTotal_db;
  wire  [10:0]  txByteTotal_tc;

  //receiver data FIFO     
  wire  [31:0]  dataFifoOut;
  wire          dataFifoEmpty;
  wire          dataFifoValid;
  wire          dataRdEn;  
  
  //receiver inst FIFO     
  wire  [31:0]  instFifoOut;
  wire          instFifoEmpty;
  wire          instFifoValid;
  wire          instRdEn;  

  //receiver itp FIFO     
  wire  [ 7:0]  itpFifoOut;
  wire          itpFifoEmpty;
  wire          itpRdEn;  
  
//clocks generation
(* DIFF_TERM = "TRUE" *) 
IBUFGDS ClkBuf ( .O  ( clockIn ),
                 .I  ( CLKBP   ),
                 .IB ( CLKBN   )
               );

//Instantiate the Ethernet Controller
etherCtrl ethcon( .clk(clock),
                  .reset(reset),
                  .ethTXclock(ethTXclock),  //125 MHz 50% duty cycle clock
                  //GMII interface
                  .GMII_TXD_0(GMII_TXD_0),
                  .GMII_TX_EN_0(GMII_TX_EN_0),
                  .GMII_TX_ER_0(GMII_TX_ER_0),
                  .GMII_TX_CLK_0(GMII_TX_CLK_0), //to PHY. Made in ODDR
                  .GMII_RXD_0(GMII_RXD_0),
                  .GMII_RX_DV_0(GMII_RX_DV_0),
                  .GMII_RX_CLK_0(GMII_RX_CLK_0), //from PHY. Goes through BUFG
                  .GMII_RESET_B(GMII_RESET_B),
                  .txFifoIn(txFifoIn),
                  .txWrEn(txWrEn),
                  .txFifoFull(txFifoFull),
                  .tcFifoIn(tcFifoIn),
                  .tcWrEn(tcWrEn),
                  .tcFifoFull(tcFifoFull),
                  .tfFifoIn(tfFifoIn_r),
                  .tfWrEn(tfWrEn_r),
                  .tfFifoFull(tfFifoFull),
                  .dataFifoOut(dataFifoOut),
                  .dataFifoEmpty(dataFifoEmpty),
                  .dataFifoValid(dataFifoValid),
                  .dataRdEn(dataRdEn),
                  .instFifoOut(instFifoOut),
                  .instFifoEmpty(instFifoEmpty),
                  .instFifoValid(instFifoValid),
                  .instRdEn(instRdEn),
                  .itpFifoOut(itpFifoOut),
                  .itpFifoEmpty(itpFifoEmpty),
                  .itpRdEn(itpRdEn),
                  .firstFrame(firstFrame),
                  .lastFrame(lastFrame)
                );

//deal with the output of data hash blocks and the output of tree cache operations

always @ (*)
 begin
   tfFifoIn_w    = tfFifoIn_r;
   tfWrEn_w      = 1'b0;
   is_both_out_w = 1'b0;
   if( txStart_db )
    begin
      tfWrEn_w    = 1'b1;
      tfFifoIn_w  = { 1'b1, txByteTotal_db };
      if( txStart_tc )
       begin
         is_both_out_w = 1'b1;
       end
    end
   else if( txStart_tc | is_both_out_r )
    begin
      tfWrEn_w    = 1'b1;
      tfFifoIn_w  = { 1'b0, txByteTotal_tc };
    end
 end

//Instantiate the hash generate module
hashGen u_hash( .clk           ( clock          ),
                .reset         ( reset          ),
                .firstFrame    ( firstFrame     ),
                .lastFrame     ( lastFrame      ),
                .dataIn        ( dataFifoOut    ),
                .dataFifoEmpty ( dataFifoEmpty  ),
                .dataFifoValid ( dataFifoValid  ), 
                .dataRdEn      ( dataRdEn       ),
                .hashValueOut  ( txFifoIn       ),
                .hashWrEn      ( txWrEn         ),
                .hashFifoFull  ( txFifoFull     ),
                .txStart       ( txStart_db     ),
                .txByteTotal   ( txByteTotal_db )
              );

//Instantiate the tree cache control module
treeCacheCtrl tcc( .clk           ( clock          ),
                   .reset         ( reset          ),
                   .instIn        ( instFifoOut    ),
                   .instFifoEmpty ( instFifoEmpty  ),
                   .instFifoValid ( instFifoValid  ),
                   .instRdEn      ( instRdEn       ),
                   .itpIn         ( itpFifoOut     ),
                   .itpFifoEmpty  ( itpFifoEmpty   ),
                   .itpRdEn       ( itpRdEn        ),
                   .hashValueOut  ( tcFifoIn       ),
                   .hashWrEn      ( tcWrEn         ),
                   .txStart       ( txStart_tc     ),
                   .txByteTotal   ( txByteTotal_tc ),
                   .clear         ( isFailed       )
                 );

always @( posedge clock or posedge reset )
 begin
   if( reset)
    begin
      tfFifoIn_r    <= 12'd0;
      tfWrEn_r      <= 1'b0;
      is_both_out_r <= 1'b0;
    end
   else
    begin
      tfFifoIn_r    <= tfFifoIn_w;
      tfWrEn_r      <= tfWrEn_w;
      is_both_out_r <= is_both_out_w;
    end
 end
 
//PLL for clocks
PLL_BASE #(
            .BANDWIDTH("OPTIMIZED"), // "HIGH", "LOW" or "OPTIMIZED"
            .CLKFBOUT_MULT(20),      //1 GHz
            .CLKFBOUT_PHASE(0.0), 
            .CLKIN_PERIOD(5.0), 
            .CLKOUT0_DIVIDE(5),      //MCLK: 200 MHz
            .CLKOUT0_DUTY_CYCLE(0.5),
            .CLKOUT0_PHASE(0.0),
            .CLKOUT1_DIVIDE(10),     //clock: 100 MHz, 50% duty cycle
            .CLKOUT1_DUTY_CYCLE(0.5), 
            .CLKOUT1_PHASE(0.0), 
            .CLKOUT2_DIVIDE(8),      //ethTXclock: 125 MHz
            .CLKOUT2_DUTY_CYCLE(0.5),
            .CLKOUT2_PHASE(0.0),
            .COMPENSATION("SYSTEM_SYNCHRONOUS"), // "SYSTEM_SYNCHRONOUS",
            .DIVCLK_DIVIDE(4),       // Division factor for all clocks (1 to 52)
            .REF_JITTER(0.100)       // Input reference jitter (0.000 to 0.999 UI%)
          ) 
clkBPLL (
          .CLKFBOUT(PLLBfb), // General output feedback signal
          .CLKOUT0(MCLKx), 
          .CLKOUT1(clockx),
          .CLKOUT2(ethTXclockx),     
          .LOCKED (pllLock), // Active high PLL lock signal
          .CLKFBIN(PLLBfb),  // Clock feedback input
          .CLKIN(clockIn),   // Clock input
          .RST(1'b0)
        );

BUFG bufC   (.O(clock),      .I(clockx)     );
BUFG bufM   (.O(MCLK),       .I(MCLKx)      );
BUFG CKbuf  (.O(ethTXclock), .I(ethTXclockx));


//instantiate an idelayctrl.
IDELAYCTRL idelayctrl0 ( .RDY(ctrlLock),
                         .REFCLK(MCLK), 
                         .RST(~pllLock)
                       );

endmodule
