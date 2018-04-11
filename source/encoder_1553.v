// =============================================================================
// Project          : core_1553
// File             : encoder_1553.v
// Title            :
// Dependencies     : 
// Description      : This module implements 1553 encoding logic. 
// =============================================================================
// REVISION HISTORY
// Version          : 1.0
// =============================================================================

module encoder_1553 (
            // Clock and Reset
            enc_clk ,
            rst_n ,

            // Inputs
            tx_dword ,
            tx_csw ,
            tx_dw ,

            // Outputs
            tx_busy ,
            tx_data , 
            tx_dval 
            ) ;


input          enc_clk ;   // 2Mhz encoder clock.
input          rst_n ;     // Asynchronous reset.

input [0:15]   tx_dword ;  // Input data word transmit.
input          tx_csw ;    // "tx_dword" has command or status word.
input          tx_dw ;     // "tx_dword" has data word.

output         tx_busy ;   // Encoder is not ready to accept next word.
output         tx_data ;   // Serial transmit data output. 
output         tx_dval ;   // Indicates data on "tx_data" is valid.

reg            cnt_en ;
reg            cnt_en_reg ;
reg [5:0]      busy_cnt ;
reg [0:16]     data_reg ;
reg [5:0]      sync_bits ;
reg            tx_data ;
reg            tx_dval ;

wire           parity ;
wire [0:40]    enc_data ;
wire           data_out ;

// Count number of clocks required to encode and serialize
// the input data.
always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n)  
      cnt_en <= 1'b0 ;
   else if (tx_csw || tx_dw ) 
      cnt_en <= 1'b1 ;
   else if (busy_cnt == 'd38) 
      cnt_en <= 1'b0 ;
   else 
      cnt_en <= cnt_en ;
end

always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n)   
      cnt_en_reg <= 1'b0 ;
   else   
      cnt_en_reg <= cnt_en ;
end

always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n)  
      busy_cnt <= 'd0 ;
   else if (cnt_en) 
      busy_cnt  <= busy_cnt + 1 ;
   else 
      busy_cnt  <= 'd0 ;
end

// Generate busy signal for the user interface.
assign tx_busy = cnt_en ;

// Generate parity for the given 16 bit word data. 
assign parity = ^(tx_dword) ;

// Register input data word along with generated parity.
always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n)  
      data_reg <= 17'h0000 ;
   else if ((tx_csw || tx_dw) && !cnt_en) 
      data_reg <= {tx_dword, parity} ;
   else if (!cnt_en ) 
      data_reg <= 17'h0000 ;
   else  
      data_reg <= data_reg ;
end

// Determine the sync pattern based on word type.
always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n)  
      sync_bits <= 6'b000_000 ;
   else if (tx_csw) 
      sync_bits <= 6'b111_000 ;
   else if (tx_dw) 
      sync_bits <= 6'b000_111 ;
   else 
      sync_bits <= sync_bits ;
end

// Generate Manchester encoded data for combined sync pattern,
// data word and parity.
assign enc_data = { sync_bits,
                    data_reg[0], ~data_reg[0],
                    data_reg[1], ~data_reg[1],
                    data_reg[2], ~data_reg[2],
                    data_reg[3], ~data_reg[3],
                    data_reg[4], ~data_reg[4],
                    data_reg[5], ~data_reg[5],
                    data_reg[6], ~data_reg[6],
                    data_reg[7], ~data_reg[7],
                    data_reg[8], ~data_reg[8],
                    data_reg[9], ~data_reg[9],
                    data_reg[10], ~data_reg[10],
                    data_reg[11], ~data_reg[11],
                    data_reg[12], ~data_reg[12],
                    data_reg[13], ~data_reg[13],
                    data_reg[14], ~data_reg[14],
                    data_reg[15], ~data_reg[15],
                    data_reg[16], ~data_reg[16], 1'b0 } ;
                   

// Serialize the encoded data
always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n) begin   
      tx_dval <= 1'b0 ;
      tx_data <= 1'b0 ;
   end
   else if (cnt_en || cnt_en_reg) begin  
      tx_dval <= 1'b1 ;
      tx_data <= enc_data[busy_cnt] ;
   end
   else begin   
      tx_dval <= 1'b0 ;
      tx_data <= 1'b0 ;
   end
end

endmodule
// =============================================================================
