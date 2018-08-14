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
            filter_match ,
            tx_csw ,    // Only used when a DW is being passed.
            tx_dw ,
            rt_address ,
            tr ,
            sub_address ,
            dwcnt_mcode ,
            parity_bit ,

            // Outputs
            end_of_payload,
            last_word,
            tx_busy ,
            tx_data , 
            tx_data_n , 
            tx_dval_csw ,
            tx_dval 
            ) ;


input          enc_clk ;   // 2Mhz encoder clock.
input          rst_n ;     // Asynchronous reset.

//input [0:15]   tx_dword ;  // Input data word transmit.
input          filter_match ;
input          tx_csw ;    // "tx_dword" has command or status word.
input          tx_dw ;     // "tx_dword" has data word.
input [0:4]    rt_address;
input          tr;
input [0:4]    sub_address;
input [0:4]    dwcnt_mcode;
input          parity_bit;

output         end_of_payload;
output         last_word;
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

reg [0:15]    tx_dword ;
reg  is_csw;
reg  is_csw_reg;
wire dword;
wire endofpayload;
wire endofword, firstword;
//assign tx_dword = 16'h0505;

// Hardwired ROM
always @(dwcnt)
begin
    case (dwcnt)
        5'd0: tx_dword <= 16'h0000;
        5'd1: tx_dword <= 16'h0000;
        5'd2: tx_dword <= 16'h0000;
        5'd3: tx_dword <= 16'h0000;
        5'd4: tx_dword <= 16'h0000;
        5'd5: tx_dword <= 16'h0000;
        5'd6: tx_dword <= 16'h0000;
        5'd7: tx_dword <= 16'h0000;
        5'd8: tx_dword <= 16'h0000;
        5'd9: tx_dword <= 16'h0000;
        5'd10: tx_dword <= 16'hEB60;  //Radar altitude
        5'd11: tx_dword <= 16'h0000;
        5'd12: tx_dword <= 16'h0000;
        5'd13: tx_dword <= 16'h0000;
        5'd14: tx_dword <= 16'h0000;
        5'd15: tx_dword <= 16'h3FFF;  //Engine Torque 1
        5'd16: tx_dword <= 16'hBFFF;  //Engine Torque 2
        5'd17: tx_dword <= 16'h0000;  //Engine Temp 1
        5'd18: tx_dword <= 16'h0020;  //Engine Temp 2
        5'd19: tx_dword <= 16'h0000;
        5'd20: tx_dword <= 16'h0000;
        5'd21: tx_dword <= 16'h0000;
        5'd22: tx_dword <= 16'h0000;
        5'd23: tx_dword <= 16'h0000;
        5'd24: tx_dword <= 16'h0000;
        5'd25: tx_dword <= 16'h0000;
        5'd26: tx_dword <= 16'h0000;
        5'd27: tx_dword <= 16'h0000;
        5'd28: tx_dword <= 16'h0000;
        5'd29: tx_dword <= 16'h0000;
        5'd30: tx_dword <= 16'h0000;
        5'd31: tx_dword <= 16'h0000;
    endcase
end

// register data word conut
reg [0:5] dwcnt_mcode_reg;
always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n) begin  
      dwcnt_mcode_reg <= 5'd0 ;
   end else begin
      dwcnt_mcode_reg <= 5'd22; //dwcnt_mcode ;
   end
end

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
assign endofpayload = (dwcnt == dwcnt_mcode_reg) && ~cnt_en && cnt_en_reg;
assign endofword = ~cnt_en && cnt_en_reg;
assign dword = (firstword || endofword) && !endofpayload;
assign last_word = (dwcnt == dwcnt_mcode_reg); 

reg end_of_payload_d;
always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n) begin  
      end_of_payload_d <= 1'b0 ;
   end else begin 
      end_of_payload_d <= (dwcnt == dwcnt_mcode_reg) && endofword ;
   end
end
assign end_of_payload = end_of_payload_d;

// Count number of clocks required to encode and serialize
// the input data.
always @(posedge enc_clk or negedge rst_n) begin
   if (!rst_n) begin  
      cnt_en <= 1'b0 ;
   end else if ( dword ) begin
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
