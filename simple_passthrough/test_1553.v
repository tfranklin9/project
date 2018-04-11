// =============================================================================
//                           COPYRIGHT NOTICE
// Copyright 2000-2001 (c) Lattice Semiconductor Corporation
//
// Permission :
// 
// Lattice Semiconductor grants permission to use this code for use in synthesis
// for Lattice programmable logic product. Other use of this code, including 
// the selling or duplication of any portion ia strictly prohibited.
// 
// Disclaimer :
//
// This VHDL or Verilog source code is intended as a design reference which
// illustrares how these types of functions can be implemeted. It is the 
// user's responsibility to verify their design for consistency and 
// functionality through the use of formal verification methods. 
// Lattice Semiconductor provides no waranty regarding the use or 
// functionality of this code. 
// =============================================================================
//
//                     Lattice Semiconductor Corporation    
//                     5555 NE Moore Court                    
//                     Hillsboro, OR 97124                  
//                     U.S.A                               
//
//                     TEL : 1-800-Lattice (USA and Canada)
//                           408-826-6000 (other locations)
//                     web  : http://www.latticesemi.com/
//                     email: techsupport@latticesemi.com
// =============================================================================
// Project          : 1553_enc_dec
// File             : test_1553.v
// Title            : 
// Dependencies     : encoder_1553.v
//                    decoder_1553.v 
// Description      : This is a simple non-automated test bench to test
//                    1553 encoder and decoder connected to eachother.
//                    Look for generated waveform file "test_1553.trn" 
// =============================================================================
// REVISION HISTORY
// Version          : 1.0
// =============================================================================
`timescale 1ns/1ps
 
module test_1553 ();

reg clk ;       //  encoder clock.
reg dec_clk ;       //  encoder clock.
reg sysclk ;    // System clock.
reg rst_n ;     // Asynchronous reset.

wire rxa_p;   // Serial transmit data input. 
wire rxa_n ;   // Serial transmit data input. 

wire txa_p;   // Serial transmit data input. 
wire txa_n;   // Serial transmit data input. 
wire tx_dval;   // Indicates data on "tx_data" is valid.       
wire tx_busy;   // Indicates encoder is busy.       
wire tx_busy_test;   // Indicates encoder is busy.       

wire [19:0]  debug_in ;   // Debug signals for transmit
wire [5:0]   debug_out ;  // Debug signals for receive
wire [19:0]  test_datout; // test bus

wire loopback;

assign debug_in = 20'd0;

reg [15:0] tx_dword = 16'd0;
reg        tx_csw ;
reg        tx_dw ;

wire       serial_data ;
reg        tx_write ;

passthru DUT(
            // Clock and Reset
            .fxclk     ( sysclk ),
            .reset_n ( rst_n ),

            // Inputs
            .rxa_p ( rxa_p ),
            .rxa_n ( !rxa_p ),
            .rxb_p ( rxa_p ),
            .rxb_n ( !rxa_p ),

            // Outputs
            .txa_p ( txa_p ), 
            .txa_n ( txa_n ), 
            .txb_p (  ), 
            .txb_n (  ), 
            
            // Debug signals
            .led1 (  ),
            .led2 (  ),
            .led3 (  )
            );
            

// test data in            
initial $readmemh("c:/Users/tfranklin9/projects/1553/source/rom.data", test_data);
reg  [17:0] test_data [0:511];
wire [19:0] datin;
reg  [8:0]  rom_add;
reg  wr_en, first_wr;
wire [15:0] test_dword;
wire test_csw;
wire test_dw;

assign test_csw = WR ? test_data[rom_add][17] : 0;
assign test_dw = WR ? test_data[rom_add][16] : 0;
assign test_dword = WR ? test_data[rom_add] : 16'd0;
encoder_1553 encoder_IN (             
            // Clock and Reset
            .enc_clk    ( clk ),
            .rst_n      ( rst_n ),

            // Inputs
            .tx_dword   ( test_dword ),
            .tx_csw     ( test_csw ),
            .tx_dw      ( test_dw ),

            // Outputs
            .tx_busy    ( tx_busy_test ),
            .tx_data    ( rxa_p ), 
            .tx_dval    ( tx_dval_test )
            ) ;
            
decoder_1553 decoder_out (
            // Clock and Reset
            .dec_clk    ( dec_clk ),
            .rst_n      ( rst_n ),

            // Inputs
            .rx_data    ( txa_p ),

            // Outputs
            .rx_dword   ( ), 
            .rx_dval    ( ),
            .rx_csw     ( ),
            .rx_dw      ( ),
            .rx_perr    ( )
            ) ;


always @(posedge clk or negedge rst_n)
begin
    if (!rst_n) begin
        rom_add <= 9'd0;
        wr_en   <= 1'b0;
        first_wr <= 1'b1;
    end else if( busy_i == 0 && first_wr == 1) begin
        rom_add <= 9'd0;
        wr_en   <= 1'b1;
        first_wr <= 1'b0;
    //end else if( tx_busy_test == 0 ) begin
    end else if( busy_i == 1 ) begin
        rom_add <= rom_add + 1;
        wr_en   <= 1'b1;
        first_wr <= 1'b0;
    end else begin
        wr_en   <= 1'b0;
    end
end
reg [1:0] WREN; 
wire WR;
reg [1:0] busy; 
wire busy_i;
reg [1:0] first; 
wire first_i;
always @ (posedge clk or negedge rst_n)
    begin
	    if ( !rst_n ) begin
          WREN <= 2'd0;
          busy <= 2'd0;
	    end else begin
          WREN <= {WREN,wr_en}; 
          busy <= {busy,tx_busy_test}; 
	end	
    end

// read enable pulse
assign WR = wr_en && ~WREN[0];
assign busy_i = ~tx_busy_test && busy[0];
            

initial begin
   clk      <= 1'b0 ;
   dec_clk  <= 1'b0 ;
   sysclk   <= 1'b0 ;
   rst_n    <= 1'b0 ;
   tx_dword <= 16'd0 ;
   tx_csw   <= 1'b0 ;
   tx_dw    <= 1'b0 ;
   tx_write <= 1'b0 ;
   //test_mode <= 1'b0;
   end

always #249.984 clk = ~clk ;
always #62.5 dec_clk = ~dec_clk;
always #10.416 sysclk = ~sysclk ;

initial begin
   repeat (2230) @(posedge clk) ;
   rst_n   <= 1'b1 ;
   tx_write <= 1'b0 ;

   repeat (39) @(posedge clk) ;
   tx_dword <= 16'h5555 ;
   tx_csw   <= 1'b1 ;
   tx_dw    <= 1'b0 ;
   tx_write <= 1'b1 ;
   repeat (1) @(posedge clk) ;
   tx_dword <= 16'h0000 ;
   tx_csw   <= 1'b0 ;
   tx_dw    <= 1'b0 ;
   tx_write <= 1'b0 ;

   repeat (39) @(posedge clk) ;
   tx_dword <= 16'hABCD ;
   tx_csw   <= 1'b1 ;
   tx_dw    <= 1'b0 ;
   tx_write <= 1'b1 ;
   repeat (1) @(posedge clk) ;
   tx_dword <= 16'h0000 ;
   tx_csw   <= 1'b0 ;
   tx_dw    <= 1'b0 ;
   tx_write <= 1'b0 ;

   repeat (39) @(posedge clk) ;
   tx_dword <= 16'hFFFF ;
   tx_csw   <= 1'b0 ;
   tx_dw    <= 1'b1 ;
   tx_write <= 1'b1 ;
   repeat (1) @(posedge clk) ;
   tx_dword <= 16'h0000 ;
   tx_csw   <= 1'b0 ;
   tx_dw    <= 1'b0 ;
   tx_write <= 1'b0 ;

   repeat (39) @(posedge clk) ;
   tx_dword <= 16'h1234 ;
   tx_csw   <= 1'b0 ;
   tx_dw    <= 1'b1 ;
   tx_write <= 1'b1 ;
   repeat (1) @(posedge clk) ;
   tx_dword <= 16'h0000 ;
   tx_csw   <= 1'b0 ;
   tx_dw    <= 1'b0 ;
   tx_write <= 1'b0 ;

   repeat (5) @(posedge clk) ;
   repeat (39) @(posedge clk) ;
   tx_dword <= 16'h5678 ;
   tx_csw   <= 1'b1 ;
   tx_dw    <= 1'b0 ;
   tx_write <= 1'b1 ;
   repeat (1) @(posedge clk) ;
   tx_dword <= 16'h0000 ;
   tx_csw   <= 1'b0 ;
   tx_dw    <= 1'b0 ;
   tx_write <= 1'b0 ;

   repeat (5) @(posedge clk) ;
   repeat (39) @(posedge clk) ;
   tx_dword <= 16'hAAAA ;
   tx_csw   <= 1'b0 ;
   tx_dw    <= 1'b1 ;
   tx_write <= 1'b1 ;

   repeat (1) @(posedge clk) ;
   tx_dword <= 16'h0000 ;
   tx_csw   <= 1'b0 ;
   tx_dw    <= 1'b0 ;
   tx_write <= 1'b0 ;

   repeat (20000) @(posedge clk) ;
   $display("---INFO : Simulation Ended, Check waveform");
  $finish ;
end

/*
initial begin
   $recordfile ("test_1553.trn");
   $recordvars ();
end
*/

endmodule



