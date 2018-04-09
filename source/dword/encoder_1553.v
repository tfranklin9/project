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
            //tx_dword ,  // Hardwire Dataword to pattern
            tx_csw ,    // Only used when a DW is being passed.
            tx_dw ,

            // Outputs
            tx_busy ,
            tx_data , 
            tx_data_n , 
            tx_dval_csw ,
            tx_dval 
            ) ;


input          enc_clk ;   // 2Mhz encoder clock.
input          rst_n ;     // Asynchronous reset.

//input [0:15]   tx_dword ;  // Input data word transmit.
input          tx_csw ;    // "tx_dword" has command or status word.
input          tx_dw ;     // "tx_dword" has data word.

output         tx_busy ;   // Encoder is not ready to accept next word.
output         tx_data ;   // Serial transmit data output. 
output         tx_data_n ;   // Serial transmit data output. 
output         tx_dval_csw ;   // Indicates data on "tx_data" is valid.
output         tx_dval ;   // Indicates data on "tx_data" is valid.

reg            cnt_en ;
reg            cnt_en_reg ;
reg [5:0]      busy_cnt ;
reg [0:16]     data_reg ;
reg [5:0]      sync_bits ;
reg [5:0]      sync_bits_n ;
reg            tx_data ;
reg            tx_data_n ;
reg            tx_dval ;
reg            tx_dval_csw ;

wire           parity ;
wire [0:40]    enc_data ;
wire [0:40]    enc_data2 ;
wire           data_out ;

wire [0:15]    tx_dword ;
reg  is_csw;
reg  is_csw_reg;
wire dword;
wire endofpayload;
wire endofword, firstword;
assign tx_dword = 16'h0505;

// Count number of datawords
reg [5:0] dwcnt;
always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n) begin  
      dwcnt <= 5'd0 ;
   end else if (endofpayload || tx_csw) begin
      dwcnt <= 5'd0 ;
   end else if ( (tx_dw && dwcnt == 0) || endofword ) begin
      dwcnt <= dwcnt + 1 ;
   end
end
assign firstword = tx_dw && dwcnt == 0;
assign endofpayload = (dwcnt == 32 ) && ~cnt_en && cnt_en_reg;
assign endofword = ~cnt_en && cnt_en_reg;
assign dword = (firstword || endofword) && !endofpayload;

// Count number of clocks required to encode and serialize
// the input data.
always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n) begin  
      cnt_en <= 1'b0 ;
   end else if ( dword ) begin //tx_dw ) begin
      cnt_en <= 1'b1 ;
   end else if (busy_cnt == 'd38) begin
      cnt_en <= 1'b0 ;
   end else begin
      cnt_en <= cnt_en ;
   end
end

reg cnt_en_dummy;
// Count number of clocks required to encode and serialize
// the input data.
always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n) begin  
      cnt_en_dummy <= 1'b0 ;
   end else if (tx_csw ) begin
      cnt_en_dummy <= 1'b1 ;
   end else if (busy_cnt_dummy == 'd38) begin
      cnt_en_dummy <= 1'b0 ;
   end else begin
      cnt_en_dummy <= cnt_en_dummy ;
   end
end

always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n) begin  
      is_csw <= 1'b0 ;
   end else if (tx_csw) begin
      is_csw <= 1'b1 ;
   end else if (busy_cnt_dummy == 'd38) begin
      is_csw <= 1'b0 ;
   end else begin
      is_csw <= is_csw ;
   end
end

always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n) begin
      cnt_en_reg <= 1'b0 ;
   end else begin   
      cnt_en_reg <= cnt_en ;
	end
end

reg cnt_en_reg_dummy;
always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n) begin
      cnt_en_reg_dummy <= 1'b0 ;
      is_csw_reg <= 1'b0 ;
   end else begin   
      cnt_en_reg_dummy <= cnt_en_dummy ;
      is_csw_reg <= is_csw ;
	end
end

always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n)  
      busy_cnt <= 'd0 ;
   else if (cnt_en) 
      busy_cnt  <= busy_cnt + 1 ;
   else 
      busy_cnt  <= 'd0 ;
end

reg [5:0] busy_cnt_dummy;
always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n)  
      busy_cnt_dummy <= 'd0 ;
   else if (cnt_en_dummy) 
      busy_cnt_dummy  <= busy_cnt_dummy + 1 ;
   else 
      busy_cnt_dummy  <= 'd0 ;
end

// Generate busy signal for the user interface.
assign tx_busy = cnt_en ;

// Generate parity for the given 16 bit word data. 
assign parity = ^~(tx_dword) ;

// Register input data word along with generated parity.
always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n)  
      data_reg <= 17'h0000 ;
   //else if ( tx_dw && !cnt_en) 
   else if ( dword && !cnt_en) 
      data_reg <= {tx_dword, parity} ;
   else if (!cnt_en ) 
      data_reg <= 17'h0000 ;
   else  
      data_reg <= data_reg ;
end

// Determine the sync pattern based on word type.
always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n) begin 
      sync_bits <= 6'b000_000 ;
      sync_bits_n <= 6'b000_000 ;
   end else if (tx_csw) begin
      sync_bits <= 6'b111_000 ;
      sync_bits_n <= 6'b000_111 ;
   //end else if (tx_dw) begin
   end else if (dword) begin
      sync_bits <= 6'b000_111 ;
      sync_bits_n <= 6'b111_000 ;
   end else begin
      sync_bits <= sync_bits ;
      sync_bits_n <= sync_bits_n ;
   end 
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
                   
assign enc_data2 = { sync_bits_n,
                    ~data_reg[0], data_reg[0],
                    ~data_reg[1], data_reg[1],
                    ~data_reg[2], data_reg[2],
                    ~data_reg[3], data_reg[3],
                    ~data_reg[4], data_reg[4],
                    ~data_reg[5], data_reg[5],
                    ~data_reg[6], data_reg[6],
                    ~data_reg[7], data_reg[7],
                    ~data_reg[8], data_reg[8],
                    ~data_reg[9], data_reg[9],
                    ~data_reg[10], data_reg[10],
                    ~data_reg[11], data_reg[11],
                    ~data_reg[12], data_reg[12],
                    ~data_reg[13], data_reg[13],
                    ~data_reg[14], data_reg[14],
                    ~data_reg[15], data_reg[15],
                    ~data_reg[16], data_reg[16], 1'b1 } ;

// Serialize the encoded data
always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n) begin   
      tx_dval   <= 1'b0 ;
      tx_data   <= 1'b0 ;
      tx_data_n <= 1'b0 ;
   end
   else if ((cnt_en || cnt_en_reg)) begin  
      tx_dval   <= 1'b1 ;
      tx_data   <= enc_data[busy_cnt] ;
      tx_data_n <= enc_data2[busy_cnt] ;
   end
   //else if ( (dwcnt >= 1) && ~(cnt_en || cnt_en_reg)) begin  
   else if ( (dwcnt >= 1) && (!cnt_en && !cnt_en_reg)) begin  
      //tx_dval   <= 1'b0 ;
      //tx_data   <= 1'b0 ;
      tx_data_n <= 1'b1 ;
   end
   else begin   
      tx_dval   <= 1'b0 ;
      tx_data   <= 1'b0 ;
      tx_data_n <= 1'b0 ;
   end
end

// generate dvalid for csw
always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n) begin   
      tx_dval_csw <= 1'b0 ;
   end
   //--else if (is_csw || is_csw_reg) begin  
   else if (cnt_en_dummy || cnt_en_reg_dummy) begin  
      tx_dval_csw <= 1'b1 ;
   end
   else begin   
      tx_dval_csw <= 1'b0 ;
   end
end

//assign tx_data_n = tx_dval ? ~tx_data : 1'b0;

endmodule
// =============================================================================
