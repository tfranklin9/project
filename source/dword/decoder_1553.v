// =============================================================================
//                           COPYRIGHT NOTICE
// Copyright 2004 (c) by Lattice Semiconductor Corporation
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
// functionality through the use of suitable verification methods. 
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
// File             : decoder_1553.v
// Title            :
// Dependencies     : 
// Description      : This module implements 1553 decoding logic. 
//                    Detects transitions on serial input.
//                    Detects sync patterns and data word boundaries.
//                    De-serializes and generates parallel data word.
//                    Checks parity.
// =============================================================================
// REVISION HISTORY
// Version          : 1.0
// =============================================================================

module decoder_1553 (
            // Clock and Reset
            dec_clk ,
            rst_n ,

            // Inputs
            rx_data ,

            // Outputs
            rx_dword , 
            rx_dval , 
            rx_csw ,
            rx_dw ,
            rx_perr
            ) ;


input          dec_clk ;   // 8Mhz decoder clock.
input          rst_n ;     // Asynchronous reset.

input          rx_data ;   // Serial transmit data input. 

output [0:15]  rx_dword ;  // Output data word receive.
output         rx_dval ;   // Indicates data on "rx_data" is valid.
output         rx_csw ;    // "rx_dword" has command or status word.
output         rx_dw ;     // "rx_dword" has data word.
output         rx_perr ;   // Indicates parity error in "rx_dword".

reg [0:15]     rx_dword ;
reg            rx_dval ;
reg            rx_csw ;
reg            rx_dw ;
reg            rx_perr ;

reg [0:23]     sync_sftreg ;
reg [0:4]      data_sftreg ;
reg            cnt_enb ;
reg [7:0]      cnt ;
reg [0:16]     dword_int ;
reg            sync_csw_reg ;
reg            sync_dw_reg ;

wire           sync_edge ;
wire           data_edge ;
wire           sync_csw ;
wire           sync_dw ;
wire           data_sample ;
wire           parity ;


// Shift in the serial data through shift registrs.
always @(posedge dec_clk or negedge rst_n) begin
   if (!rst_n ) begin   
      data_sftreg <= 5'd0 ;
      sync_sftreg <= 24'd0 ;
   end
   else  begin 
      data_sftreg <= {data_sftreg[1:4],rx_data} ;
      sync_sftreg <= {sync_sftreg[1:23],data_sftreg[0]} ;
   end
end


// Detect transitions.
assign data_edge =  data_sftreg[3] ^ data_sftreg[4] ;

// Detect sync pattern for command and status word
assign sync_csw = (sync_sftreg == 24'hFFF_000) & data_edge ;

// Detect sync pattern for data word
assign sync_dw =  (sync_sftreg == 24'h000_FFF) & data_edge ; 

// Count number of clocks to get complete word after 
// detecting the sync pattern
always @(posedge dec_clk or negedge rst_n) begin
   if (!rst_n )    
      cnt_enb <= 1'b0 ;
   else if (sync_csw || sync_dw)
      cnt_enb <= 1'b1 ;
   else if (cnt == 'd131)
      cnt_enb <= 1'b0 ;
   else 
      cnt_enb <= cnt_enb ;
end

always @(posedge dec_clk or negedge rst_n) begin
   if (!rst_n )    
      cnt <= 8'hFF ;
   else if (cnt_enb)
      cnt <= cnt + 1 ;
   else if (!cnt_enb)
      cnt <= 8'hFF ;
   else 
      cnt <= cnt ;
end

// Generate data sample points.
assign data_sample =  (~cnt[2] & ~cnt[1] & ~cnt[0]) ;

// register data at every sample point through shift register.
always @(posedge dec_clk or negedge rst_n) begin
   if (!rst_n )    
      dword_int <= 17'h0000 ;
   else if (data_sample && cnt_enb)
      dword_int <= {dword_int[1:16],~data_sftreg[2]} ;
   else if (!cnt_enb)
      dword_int <= 17'h0000 ;
   else 
      dword_int <= dword_int ;
end

// Register command and status sync patter type till the end 
// of data word.
always @(posedge dec_clk or negedge rst_n) begin
   if (!rst_n )    
      sync_csw_reg <= 1'b0 ;
   else if (sync_csw)
      sync_csw_reg <= 1'b1 ;
   else if (cnt == 'd132)
      sync_csw_reg <= 1'b0 ;
   else 
      sync_csw_reg <= sync_csw_reg ;
end

// Register data sync patter type till the end of data word.
always @(posedge dec_clk or negedge rst_n) begin
   if (!rst_n )    
      sync_dw_reg <= 1'b0 ;
   else if (sync_dw)
      sync_dw_reg <= 1'b1 ;
   else if (cnt == 'd132)
      sync_dw_reg <= 1'b0 ;
   else 
      sync_dw_reg <= sync_dw_reg ;
end

// Register the parallel data word and control outputs.
always @(posedge dec_clk or negedge rst_n) begin
   if (!rst_n ) begin    
      rx_dword <= 16'h0000 ;
      rx_dval  <= 1'b0 ;
      rx_perr  <= 1'b0 ;
      rx_csw   <= 1'b0 ;
      rx_dw    <= 1'b0 ;
   end
   else if (cnt == 'd131) begin
      rx_dword <= dword_int[0:15] ;
      rx_dval  <= 1'b1 ;
      rx_perr  <= ((^dword_int[0:15]) != dword_int[16]) ;
      rx_csw   <= sync_csw_reg ;
      rx_dw    <= sync_dw_reg ;
   end
   else  begin
      rx_dword <= 16'h0000 ;
      rx_dval  <= 1'b0 ;
      rx_perr  <= 1'b0 ;
      rx_csw   <= 1'b0 ;
      rx_dw    <= 1'b0 ;
   end
end

endmodule
// =============================================================================
