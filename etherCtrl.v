`timescale 1ns / 1ps

//1Gbit full-duplex Ethernet controller using the embedded MAC.

module etherCtrl( clk,
                  reset,
                  ethTXclock,
                  GMII_TXD_0,
                  GMII_TX_EN_0,
                  GMII_TX_ER_0,
                  GMII_TX_CLK_0, 
                  GMII_RXD_0,
                  GMII_RX_DV_0,
                  GMII_RX_CLK_0, 
                  GMII_RESET_B,
                  txFifoIn,
                  txWrEn,
                  txFifoFull,
                  tcFifoIn,
                  tcWrEn,
                  tcFifoFull,
                  tfFifoIn,
                  tfWrEn,
                  tfFifoFull,
                  dataFifoOut,
                  dataFifoEmpty,
                  dataFifoValid,
                  dataRdEn,
                  instFifoOut,
                  instFifoEmpty,
                  instFifoValid,
                  instRdEn,
                  itpFifoOut,
                  itpFifoEmpty,
                  itpRdEn,
                  firstFrame,
                  lastFrame
                );
  
  input         clk;
  input         reset;
  input         ethTXclock;
 
  //transmitter data FIFO  
  input  [7:0]  txFifoIn;  
  input         txWrEn;    
  output        txFifoFull;
  
  //transmitter data FIFO from cache tree 
  input  [7:0]  tcFifoIn;  
  input         tcWrEn;    
  output        tcFifoFull;  

  //transmitter frame info FIFO  
  input [11:0]  tfFifoIn;  
  input         tfWrEn;    
  output        tfFifoFull;  

  //receiver data FIFO     
  output [31:0] dataFifoOut;
  output        dataFifoEmpty;
  output        dataFifoValid;
  input         dataRdEn;  
  
  //receiver inst FIFO     
  output [31:0] instFifoOut;
  output        instFifoEmpty;
  output        instFifoValid;
  input         instRdEn;  
  
  //receiver inst type FIFO
  output [7:0]  itpFifoOut;
  output        itpFifoEmpty;
  input         itpRdEn;  

  //sha1 frame type
  output        firstFrame;
  output        lastFrame;
  
  //GMII signals 
  output [7:0]  GMII_TXD_0;
  output        GMII_TX_EN_0;
  output        GMII_TX_ER_0;
  output        GMII_TX_CLK_0;  //to PHY. Made in ODDR
  input  [7:0]  GMII_RXD_0;
  input         GMII_RX_DV_0;
  input         GMII_RX_CLK_0;  //from PHY. Goes through BUFG
  output        GMII_RESET_B;

  wire   [7:0]  preGMII_TXD_0;
  wire          preGMII_TX_EN_0;
  wire          preGMII_TX_ER_0;
  reg    [7:0]  GMII_TXD_0_r;
  reg           GMII_TX_EN_0_r;
  reg           GMII_TX_ER_0_r;
  
  assign GMII_TXD_0   = GMII_TXD_0_r;
  assign GMII_TX_EN_0 = GMII_TX_EN_0_r;
  assign GMII_TX_ER_0 = GMII_TX_ER_0_r;

  wire          clientRXclock;
  wire          RXclockDelay;
  wire   [7:0]  RXdataDelay;
  reg    [7:0]  RXdataDelayReg;
  wire          RXdvDelay;
  reg           RXdvDelayReg;
  
  //frame info
  wire          frameInfoLoad;
  wire  [47:0]  srcMacAddr;
  wire  [47:0]  dstMacAddr;
  wire  [15:0]  etherType;

//---------------------------------- Ethernet Receiver -----------------------------------

  //data FIFO  ---> store data blocks to hash
  wire [31:0] dataFifoIn;
  wire        dataWrEn;  
  wire        dataFifoFull;
  
  //inst FIFO  ---> store commands for tree cache operations
  wire [31:0] instFifoIn;
  wire        instWrEn;  
  wire        instFifoFull;
  
  //inst FIFO  ---> store tree cache command types
  wire [7:0]  itpFifoIn;
  wire        itpWrEn;  
  wire        itpFifoFull;
  
  // MAC signals
  wire [7:0]  RXdata;          //received data from MAC
  wire        RXdataValid;     //received data valid
  wire        RXgoodFrame;
  wire        RXbadFrame;
  
  etherRX erx ( .clientRXclock ( clientRXclock ),
                .reset         ( reset         ),
                .dataFifoFull  ( dataFifoFull  ),
                .dataFifoIn    ( dataFifoIn    ),
                .dataWrEn      ( dataWrEn      ),
                .instFifoFull  ( instFifoFull  ),
                .instFifoIn    ( instFifoIn    ),
                .instWrEn      ( instWrEn      ),
                .itpFifoFull   ( itpFifoFull   ),
                .itpFifoIn     ( itpFifoIn     ),
                .itpWrEn       ( itpWrEn       ),
                .RXdata        ( RXdata        ), 
                .RXdataValid   ( RXdataValid   ),
                .RXgoodFrame   ( RXgoodFrame   ),
                .RXbadFrame    ( RXbadFrame    ),
                .frameInfoLoad ( frameInfoLoad ),
                .srcMacAddr    ( srcMacAddr    ),
                .dstMacAddr    ( dstMacAddr    ),
                .etherType     ( etherType     ),
                .firstFrame    ( firstFrame    ),
                .lastFrame     ( lastFrame     ),
                .rPackCnt      ( rPackCnt      )
              );

//-------------------------------- Ethernet Transmiter -----------------------------------

  
  //data to/from MAC
  wire          TXack;
  wire    [7:0] TXdata;
  wire          TXdataValid;
  
  //transmitter data FIFO
  wire    [7:0] txFifoOut;
  wire          txFifoEmpty;
  wire          txRdEn;  
  
  //transmitter data FIFO from cache tree
  wire    [7:0] tcFifoOut;
  wire          tcFifoEmpty;
  wire          tcRdEn;  

  //transmitter frame info FIFO
  wire   [11:0] tfFifoOut;
  wire          tfFifoEmpty;
  wire          tfRdEn;    

  etherTX etx ( .ethTXclock    ( ethTXclock    ), 
                .reset         ( reset         ),
                .frameInfoLoad ( frameInfoLoad ),
                .srcMacAddr    ( srcMacAddr    ),
                .dstMacAddr    ( dstMacAddr    ),
                .etherType     ( etherType     ),
                .txFifoOut     ( txFifoOut     ),
                .txFifoEmpty   ( txFifoEmpty   ),
                .txRdEn        ( txRdEn        ),
                .tcFifoOut     ( tcFifoOut     ),
                .tcFifoEmpty   ( tcFifoEmpty   ),
                .tcRdEn        ( tcRdEn        ),
                .tfFifoOut     ( tfFifoOut     ),
                .tfFifoEmpty   ( tfFifoEmpty   ),
                .tfRdEn        ( tfRdEn        ),
                .TXack         ( TXack         ),
                .TXdata        ( TXdata        ),
                .TXdataValid   ( TXdataValid   )
              );



//------------------------------- GMII Interface Signals ---------------------------------


//Reg buffers for Transmit data
always @(posedge ethTXclock) 
 begin
   GMII_TXD_0_r   <= preGMII_TXD_0;
   GMII_TX_EN_0_r <= preGMII_TX_EN_0;
   GMII_TX_ER_0_r <= preGMII_TX_ER_0;
 end
    
assign GMII_RESET_B = ~reset;
 
//ODDR for Phy Clock
ODDR GMIIoddr ( .Q(GMII_TX_CLK_0),
                .C(ethTXclock),
                .CE(1'b1),
                .D1(1'b0), 
                .D2(1'b1), 
                .R(reset), 
                .S(1'b0)
              );
  
//IDELAYs and BUFG for the Receive data and clock

IDELAY #( .IOBDELAY_TYPE("FIXED"), // "DEFAULT", "FIXED" or "VARIABLE"
          .IOBDELAY_VALUE(0) // Any value from 0 to 63
        ) 
RXclockBlk( .I(GMII_RX_CLK_0),
            .O(RXclockDelay),
            .C(1'b0),
            .CE(1'b0), 
            .INC(1'b0),
            .RST(1'b0)
          );

BUFG bufgClientRx (.I(RXclockDelay), .O(clientRXclock));
     
IDELAY #( .IOBDELAY_TYPE("FIXED"), // "DEFAULT", "FIXED" or "VARIABLE"
          .IOBDELAY_VALUE(20)      // Any value from 0 to 63
        ) 
RXdvBlock( .I(GMII_RX_DV_0), 
           .O(RXdvDelay), 
           .C(1'b0),
           .CE(1'b0), 
           .INC(1'b0),
           .RST(1'b0)
         );

always @(posedge clientRXclock) //register the delayed RXdata.
begin  
  RXdataDelayReg <= RXdataDelay;
  RXdvDelayReg   <= RXdvDelay;
end

genvar idly;
generate
  for(idly = 0; idly < 8; idly = idly + 1)
  begin: dlyBlock
     IDELAY #( .IOBDELAY_TYPE("FIXED"), // "DEFAULT", "FIXED" or "VARIABLE"
               .IOBDELAY_VALUE(20) // Any value from 0 to 63
             ) 
     RXdataBlock( .I(GMII_RXD_0[idly]), 
                  .O(RXdataDelay[idly]), 
                  .C(1'b0),
                  .CE(1'b0), 
                  .INC(1'b0),
                  .RST(1'b0)
                );
  end
endgenerate  

//Instantiate the MAC
MAC etherMAC( // Client Receiver Interface
              .RXclockOut(),                    //output
              .RXclockIn(clientRXclock),        //input
              .RXdata(RXdata),                  //output   [7:0]
              .RXdataValid(RXdataValid),        //output
              .RXgoodFrame(RXgoodFrame),        //output
              .RXbadFrame(RXbadFrame),          //output
              .TXclockIn(ethTXclock),           //input
              .TXdata(TXdata),                  //input    [7:0]
              .TXdataValid(TXdataValid),        //input
              .TXdataValidMSW(1'b0),            //input
              .TXack(TXack),                    //output
              .TXfirstByte(1'b0),               //input
              .TXunderrun(1'b0),                //input

              // MAC Control Interface
              .PauseRequest(1'b0),
              .PauseValue(16'b0),

              // Clock Signals
              .TXgmiiMiiClockIn(ethTXclock),
              .MIItxClock(1'b0),

              // GMII Interface
              .GMIItxData(preGMII_TXD_0),          //output   [7:0]
              .GMIItxEnable(preGMII_TX_EN_0),      //output
              .GMIItxError(preGMII_TX_ER_0),       //output
              .GMIIrxData(RXdataDelayReg),         //input    [7:0]  
              .GMIIrxDataValid(RXdvDelayReg),      //input
              .GMIIrxClock(clientRXclock),         //input
              .DCMlocked(1'b1),
              
              // Asynchronous Reset
              .Reset(reset)
            );

rdataFifo etherdFifo( .rst   ( reset          ),
                      .wr_clk( clientRXclock  ),
                      .rd_clk( clk            ),
                      .din   ( dataFifoIn     ),  
                      .wr_en ( dataWrEn       ),
                      .rd_en ( dataRdEn       ),
                      .dout  ( dataFifoOut    ), 
                      .full  ( dataFifoFull   ),
                      .empty ( dataFifoEmpty  ),
                      .valid ( dataFifoValid  )
                    ); 

instFifo etherinFifo( .rst   ( reset          ),
                      .wr_clk( clientRXclock  ),
                      .rd_clk( clk            ),
                      .din   ( instFifoIn     ),  
                      .wr_en ( instWrEn       ),
                      .rd_en ( instRdEn       ),
                      .dout  ( instFifoOut    ), 
                      .full  ( instFifoFull   ),
                      .empty ( instFifoEmpty  ),
                      .valid ( instFifoValid  )
                    ); 

instTypeFifo etheritpFifo( .rst   ( reset          ),
                           .wr_clk( clientRXclock  ),
                           .rd_clk( clk            ),
                           .din   ( itpFifoIn      ),  
                           .wr_en ( itpWrEn        ),
                           .rd_en ( itpRdEn        ),
                           .dout  ( itpFifoOut     ), 
                           .full  ( itpFifoFull    ),
                           .empty ( itpFifoEmpty   )
                         ); 

txFifo ethetxFifo( .rst   ( reset        ),
                   .wr_clk( clk          ),
                   .rd_clk( ethTXclock   ),
                   .din   ( txFifoIn     ),  
                   .wr_en ( txWrEn       ),
                   .rd_en ( txRdEn       ),
                   .dout  ( txFifoOut    ), 
                   .full  ( txFifoFull   ),
                   .empty ( txFifoEmpty  )
                 ); 
 
tcFifo ethetcFifo( .rst   ( reset        ),
                   .wr_clk( clk          ),
                   .rd_clk( ethTXclock   ),
                   .din   ( tcFifoIn     ),  
                   .wr_en ( tcWrEn       ),
                   .rd_en ( tcRdEn       ),
                   .dout  ( tcFifoOut    ), 
                   .full  ( tcFifoFull   ),
                   .empty ( tcFifoEmpty  )
                 ); 

txFrameFifo ethertfFifo( .rst   ( reset        ),
                         .wr_clk( clk          ),
                         .rd_clk( ethTXclock   ),
                         .din   ( tfFifoIn     ),  
                         .wr_en ( tfWrEn       ),
                         .rd_en ( tfRdEn       ),
                         .dout  ( tfFifoOut    ), 
                         .full  ( tfFifoFull   ),
                         .empty ( tfFifoEmpty  )
                       ); 

endmodule
