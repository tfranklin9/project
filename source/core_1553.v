// =============================================================================
// Project          : 1553
// File             : core_1553.v
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

module core_1553 (
            // Clock and Reset
            dec_clk ,
            sys_clk ,
            rst_n ,

            // Inputs
            rx_data,
            rx_data_n,
            mem_wea,
            mem_addra,
            mem_datin,
            bypass,            
            lastword,

            // Outputs
            rx_dword , 
            rx_dval , 
            rx_csw ,
            rx_dw ,
            rx_perr, 
            
            tx_data,
            tx_data_n,
            tx_dval,
            rt_address,
            tr,
            sub_address,
            dwcnt_mcode,
            parity_bit,
            debug,
            enc_data,
            enc_data_en
            ) ;

parameter      BC = 1'b1;     // BC->RT BC == 1, RT->BC BC == 0
input          dec_clk ;   // 8Mhz decoder clock.
input          sys_clk ;
input          rst_n ;     // Asynchronous reset.

input          rx_data ;   // Serial transmit data input. 
input          rx_data_n ;   // Serial transmit data input. 
input  [0:0]   mem_wea ;
input  [6:0]   mem_addra ;
input  [17:0]  mem_datin ;
input          bypass ;
input          lastword ;

output [0:15]  rx_dword ;  // Output data word receive.
output         rx_dval ;   // Indicates data on "rx_data" is valid.
output         rx_csw ;    // "rx_dword" has command or status word.
output         rx_dw ;     // "rx_dword" has data word.
output         rx_perr ;   // Indicates parity error in "rx_dword".
output         tx_data;
output         tx_data_n;
output         tx_dval;
output [0:4]   rt_address;
output         tr;
output [0:4]   sub_address;
output [0:4]   dwcnt_mcode;
output         parity_bit;
output [7:0]   debug;
output         enc_data;
output         enc_data_en;

reg [0:15]     rx_dword ;
reg            rx_dval ;
//reg            rx_csw ;
//reg            rx_dw ;
reg            rx_perr ;

reg [0:23]     sync_sftreg ;
reg [0:4]      data_sftreg ;
reg [0:23]     sync_sftreg_n ;
reg [0:4]      data_sftreg_n ;
reg            cnt_enb ;
reg [7:0]      cnt ;
reg [4:0]      bit_cnt ;
reg [0:16]     dword_int ;
reg            sync_csw_reg ;
reg            sync_dw_reg ;

wire           data_edge ;
wire           sync_csw ;
wire           sync_dw ;
wire           sync_found ;
wire           data_sample ;
wire           parity ;

// Bit fields 
wire       is_cw;
wire       is_sw;
wire       is_dw;
reg [0:4]  dword1;
reg        dword2;
reg [0:4]  dword3;
reg [0:4]  dword4;
reg [0:15] dword;
reg [0:4]  rtaddress;
reg [0:4]  subaddress;
reg [0:4]  dwcntmcode;
reg        tr_reg;
reg        paritybit ;
reg [0:2]  rsvd;
reg        message_error;
reg        inst;
reg        srv_rqst;
reg        bc_rcvd;
reg        busy;
reg        sub_flag;
reg        dbctrl_acc;
reg        term_flag;

// serial manchester out
reg [0:31]     data_sftreg_out ;
reg [0:31]     data_sftreg_out_n ;
reg            cw ;
reg            dw ;
reg            sw ;
wire [0:16]    passthru;

reg            start_shift;
reg            shift_data;
reg [4:0]      bitcnt;
reg            enc_bit;
reg            change;
reg [2:0]      samplecnt;
reg            txdval;
reg            txdata;
reg            txdata_n;
wire [3:0]     select;
reg            enb;
wire [16:0]    data_reg;
wire [6:0]     mem_addrb;         

parameter SIZE = 4;
parameter IDLE = 4'b0001;
parameter READ = 4'b0010;
parameter SHIFT1 = 4'b0100;
parameter SHIFT2 = 4'b1000;
reg   [SIZE-1:0]          state        ; // FSM vector

// Shift in the serial data through shift registrs.
always @(posedge dec_clk or negedge rst_n) begin
   if ( !rst_n ) begin   
      data_sftreg <= 5'd0 ;
      sync_sftreg <= 24'd0 ;
   end
   else  begin 
      data_sftreg <= {data_sftreg[1:4],rx_data} ;
      sync_sftreg <= {sync_sftreg[1:23],data_sftreg[0]} ;
   end
end

// Shift the negative end.
always @(posedge dec_clk or negedge rst_n) begin
   if ( !rst_n ) begin   
      data_sftreg_n <= 5'd0 ;
      sync_sftreg_n <= 24'd0 ;
   end
   else  begin 
      data_sftreg_n <= {data_sftreg_n[1:4],rx_data_n} ;
      sync_sftreg_n <= {sync_sftreg_n[1:23],data_sftreg_n[0]} ;
   end
end

// Detect transitions.
assign data_edge =  data_sftreg[3] ^ data_sftreg[4] ;

wire synccsw, syncdw, syncdword, synccsword;
reg  syncdw_d, synccsw_d;
assign synccsw = (sync_sftreg == 24'h7FF_000) || (sync_sftreg == 24'h7FF_800) || (sync_sftreg == 24'hFFE_001) || (sync_sftreg == 24'hFFF_000) ;
assign syncdw  = (sync_sftreg == 24'h000_7FF) || (sync_sftreg == 24'h001_FFF) || (sync_sftreg == 24'h000_FFF) || (sync_sftreg == 24'h000_FFF) ;
//assign sync_found = (sync_sftreg == 24'hFFF_000) || (sync_sftreg == 24'h000_FFF);
assign sync_found = synccsw || syncdw;

always @(posedge dec_clk or negedge rst_n) begin
   if ( !rst_n ) begin   
      syncdw_d <= 1'b0 ;
      synccsw_d <= 1'b0 ;
      end
   else  begin 
      syncdw_d <= syncdw;
      synccsw_d <= synccsw ;
   end
end
assign syncdword = syncdw || syncdw_d;
assign synccsword = synccsw || synccsw_d;

// Detect sync pattern for command and status word
//assign sync_csw = (sync_sftreg == 24'hFFF_000) & data_edge ;
//assign sync_csw = synccsw && data_edge ;
assign sync_csw = synccsword && data_edge ;

// Detect sync pattern for data word
//assign sync_dw =  (sync_sftreg == 24'h000_FFF) & data_edge ; 
assign sync_dw = syncdword && data_edge ; 


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
assign enc_data = dword_int[16];

// Send serial stream of encoded data out
reg encdata_en;
always @(posedge dec_clk or negedge rst_n) begin
   if (!rst_n )    
      encdata_en <= 1'b0;
   else
      encdata_en <= data_sample;
end 
assign enc_data_en = encdata_en;

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
//      rx_csw   <= 1'b0 ;
//      rx_dw    <= 1'b0 ;
   end
   else if (cnt == 'd131) begin
      rx_dword <= dword_int[0:15] ;
      rx_dval  <= 1'b1 ;
      rx_perr  <= dword_int[16] ;  // parity bit.
//      rx_perr  <= ((^dword_int[0:15]) != dword_int[16]) ;
//      rx_csw   <= sync_csw_reg ;
//      rx_dw    <= sync_dw_reg ;
   end
   else  begin
      rx_dword <= 16'h0000 ;
      rx_dval  <= 1'b0 ;
      rx_perr  <= 1'b0 ;
//      rx_csw   <= 1'b0 ;
//      rx_dw    <= 1'b0 ;
   end
end

assign rx_dw  = sync_dw_reg;
assign rx_csw = sync_csw_reg;

// Bit counter for 1553 Word fields
always @(posedge dec_clk or negedge rst_n) begin
   if (!rst_n )    
      bit_cnt <= 5'h00 ;
   else if (cnt_enb && data_sample)
      bit_cnt <= bit_cnt + 1 ;
   else if (!cnt_enb)
      bit_cnt <= 5'h00 ;
   else 
      bit_cnt <= bit_cnt ;
end

//////////////////////////////////////////////////
// register data at sample points for 1553 fields.
//////////////////////////////////////////////////
// Command word fields
//////////////////////////////////////////////////
// Create RAM address for lookup
assign mem_addrb = {1'b0,rtaddress};

// RT Address
always @(posedge dec_clk or negedge rst_n) begin
   if (!rst_n )    
      rtaddress <= 5'h00 ;
   else if ( lastword ) 
      rtaddress <= 5'h00 ;
   else if ( (is_cw || is_sw) && data_sample && bit_cnt < 5)
      rtaddress <= {rtaddress[1:4],~data_sftreg[2]} ;
   end

assign rt_address = rtaddress;

// Generate Transmit/Receive
always @(posedge dec_clk or negedge rst_n) begin
   if (!rst_n )    
      tr_reg <= 1'b0 ;
   else if ( lastword ) 
      tr_reg <= 1'b0 ;
   else if ( is_cw && data_sample && bit_cnt == 5)
      tr_reg <=  ~data_sftreg[2] ;
   end

assign tr = tr_reg;

// Sub Address
always @(posedge dec_clk or negedge rst_n) begin
   if (!rst_n )    
      subaddress <= 5'h00 ;
   else if ( lastword ) 
      subaddress <= 5'h00 ;
   else if ( is_cw && data_sample && ( bit_cnt > 5 && bit_cnt <= 10 ) )
      subaddress <= {subaddress[1:4],~data_sftreg[2]} ;
   end

assign sub_address = subaddress;

// Data Word Count/Mode Code 
always @(posedge dec_clk or negedge rst_n) begin
   if (!rst_n )    
      dwcntmcode <= 5'h00 ;
   else if ( is_cw && data_sample && ( bit_cnt > 10 && bit_cnt <= 15 ) )
      dwcntmcode <= {dwcntmcode[1:4],~data_sftreg[2]} ;
   end

assign dwcnt_mcode = dwcntmcode;

// Parity bit in
always @(posedge dec_clk or negedge rst_n) begin
   if (!rst_n )    
      paritybit <= 1'b0 ;
   else if ( data_sample && bit_cnt == 16 )
      paritybit <= ~data_sftreg[2] ;
   end

assign parity_bit = paritybit;

//////////////////////////////////////////////////
// Status word fields
//////////////////////////////////////////////////
// Generate Status Word Fields 
always @(posedge dec_clk or negedge rst_n) begin
   if (!rst_n ) begin   
      message_error <= 1'b0;
      inst <= 1'b0 ;
      srv_rqst <= 1'b0 ;
      rsvd <= 3'b000 ;
      bc_rcvd <= 1'b0;
      busy <= 1'b0;
      sub_flag <= 1'b0;
      dbctrl_acc <= 1'b0;
      term_flag <= 1'b0;
   end else if ( is_sw && data_sample && bit_cnt == 5) begin
      message_error <= ~data_sftreg[2] ;
   end else if ( is_sw && data_sample && bit_cnt == 6) begin
      inst <=  ~data_sftreg[2];
   end else if ( is_sw && data_sample && bit_cnt == 7) begin
      srv_rqst <=  ~data_sftreg[2];
   end else if ( is_sw && data_sample && ( bit_cnt > 7 && bit_cnt < 11 ) ) begin
      rsvd <=  {rsvd[1:2],~data_sftreg[2]} ;
   end else if ( is_sw && data_sample && bit_cnt == 11) begin
      bc_rcvd <= ~data_sftreg[2] ;
   end else if ( is_sw && data_sample && bit_cnt == 12) begin
      busy <= ~data_sftreg[2] ;
   end else if ( is_sw && data_sample && bit_cnt == 13) begin
      sub_flag <= ~data_sftreg[2] ;
   end else if ( is_sw && data_sample && bit_cnt == 14) begin
      dbctrl_acc <= ~data_sftreg[2] ;
   end else if ( is_sw && data_sample && bit_cnt == 15) begin
      term_flag <= ~data_sftreg[2] ;
   end else if ( !cnt_enb || !is_sw ) begin
      message_error <= 1'b0;
      inst <= 1'b0 ;
      srv_rqst <= 1'b0 ;
      rsvd <= 3'b000 ;
      bc_rcvd <= 1'b0;
      busy <= 1'b0;
      sub_flag <= 1'b0;
      dbctrl_acc <= 1'b0;
      term_flag <= 1'b0;
   end 
end

//////////////////////////////////////////////////
// Data Word fields
//////////////////////////////////////////////////
// Data Payload
always @(posedge dec_clk or negedge rst_n) begin
   if ( !rst_n ) 
      dword1 <= 5'h00;
   else if ( is_dw && data_sample && bit_cnt < 5 )
      dword1 <= {dword1[1:4],~data_sftreg[2]} ;
end
always @(posedge dec_clk or negedge rst_n) begin
   if ( !rst_n ) begin
      dword2 <= 1'b0;
   end else if ( is_dw && data_sample && bit_cnt == 5 ) begin
      dword2 <= ~data_sftreg[2];
   end
end
always @(posedge dec_clk or negedge rst_n) begin
   if ( !rst_n ) begin
      dword3 <= 5'h00;
   end else if ( is_dw && data_sample && ( bit_cnt > 5 && bit_cnt <= 10 ) ) begin
      dword3 <= {dword3[1:4],~data_sftreg[2]} ;
   end
end
always @(posedge dec_clk or negedge rst_n) begin
   if ( !rst_n ) begin
      dword4 <= 5'h00;
   end else if ( is_dw && data_sample && ( bit_cnt > 10 && bit_cnt <= 15 ) ) begin
      dword4 <= {dword4[1:4],~data_sftreg[2]} ;
   end
end

assign is_cw = sync_csw_reg && BC;
assign is_sw = sync_csw_reg && BC;
assign is_dw = sync_dw_reg;

// Capture complete word
//always @(posedge dec_clk or negedge rst_n) begin
//   if ( !rst_n ) begin
//      dword <= 16'h0000;
//   end else if ( data_sample && ( bit_cnt <= 15 ) ) begin
//      dword <= {dword[1:15],~data_sftreg[2]} ;
//   end
//end

//////////////////////////////////////////////////
// Line up outgoing 1553 with dec clock generate delayed edges.
//////////////////////////////////////////////////
// Shift in the serial data through shift registers.
// to delay incoming serial stream
always @(posedge dec_clk or negedge rst_n) begin
   if ( !rst_n ) begin   
      data_sftreg_out <= 32'd0 ;
   end
   else  begin 
      data_sftreg_out <= {data_sftreg_out[1:31],sync_sftreg[0]} ;
   end
end
// negative side
always @(posedge dec_clk or negedge rst_n) begin
   if ( !rst_n ) begin   
      data_sftreg_out_n <= 32'd0 ;
   end
   else  begin 
      data_sftreg_out_n <= {data_sftreg_out_n[1:31],sync_sftreg_n[0]} ;
   end
end

// Detect delayed sync.
always @(posedge dec_clk or negedge rst_n) begin
   if ( !rst_n ) begin   
      start_shift <= 1'b0;
   end else if (bit_cnt == 5 && samplecnt == 0) begin
      start_shift <= 1'b1;
   end else if (bitcnt == 16 && samplecnt == 7) begin
      start_shift <= 1'b0;
   end
end

// Delayed bit time count. Incoming stream is delayed 6 bit times.
always @(posedge dec_clk or negedge rst_n) begin
   if ( !rst_n ) begin   
      bitcnt <= 5'd0;
   end else if (bit_cnt == 5 || bitcnt == 17 || !shift_data) begin
      bitcnt <= 5'd0;
   end else if (samplecnt == 7) begin
      bitcnt <= bitcnt + 1;
   end
end

// Register command and status sync patter type till the end 
// of data word.
always @(posedge dec_clk or negedge rst_n) begin
   if (!rst_n ) begin  
      cw <= 1'b0 ;
      sw <= 1'b0 ;
      dw <= 1'b0 ;
   end else if (bitcnt == 0) begin
      cw <= is_cw ;
      dw <= is_dw ;
      sw <= is_sw ;
   end else if (bitcnt == 'd17) begin
      cw <= 1'b0 ;
      sw <= 1'b0 ;
      dw <= 1'b0 ; 
   end
end

// Sample counter for manchester coding and FSM
always @(posedge dec_clk or negedge rst_n) begin
   if ( !rst_n ) begin   
      samplecnt <= 3'b000;
   end else if (bit_cnt == 5) begin
      samplecnt <= 3'b000;
   end else if (READ || SHIFT1 || SHIFT2 ) begin
      samplecnt <=  samplecnt + 1;
   end
end

//assign mem_dat = 17'd0;
   
// FSM to shift data out encoded
always @(posedge dec_clk or negedge rst_n) begin
   begin : FSM
      if (!rst_n) begin
         state <= IDLE;
      end else
         case(state)
            IDLE : begin
                      if (start_shift) begin
                        state <=  READ;
                      end else begin
                        state <= IDLE;
                      end
                      shift_data <= 1'b0;
                      enc_bit <= 1'b0;
                      change  <= 1'b0;
                   end
            READ : begin
                     change  <= 1'b0;
                     state <=  SHIFT1;
                   end
            SHIFT1 : begin
                      if (samplecnt < 3) begin
                         if (data_reg[bitcnt] == 0) begin
                            enc_bit <= passthru[bitcnt];
                         end else begin
                            enc_bit <= ~passthru[bitcnt];
                            change  <= 1'b1;
                         end
                      end else begin
                         state <=  SHIFT2;
                      end
                      shift_data <= 1'b1;
                   end
            SHIFT2 : begin
                     if (samplecnt < 7) begin
                        if (data_reg[bitcnt] == 0) begin
                           enc_bit <= ~passthru[bitcnt];
                        end else begin
                           change  <= 1'b1;
                           enc_bit <= passthru[bitcnt];
                        end
                     end else if (bitcnt < 16 && samplecnt == 7) begin
                        state <= SHIFT1;
                     end else if (bitcnt == 16 && samplecnt == 7) begin
                        state <= IDLE;
                     end    
                     shift_data <= 1'b1;
                  end
            default : begin 
                      state <= IDLE;
                  end 
          endcase
	   end 
  end
  
  assign enc_bit_n = ~enc_bit;
  assign select   = {BC,cw,dw,sw};
  assign passthru =  ({BC,cw,dw,sw} == 4'b1100) ? {rtaddress,tr_reg,subaddress,dwcntmcode,paritybit} :  // BC->RT CW
                     ({BC,cw,dw,sw} == 4'b1010) ? {dword1,dword2,dword3,dword4,paritybit} :   // BC->RT DW
                     ({BC,cw,dw,sw} == 4'b0010) ? {dword1,dword2,dword3,dword4,paritybit} :   // RT->BC DW
                     ({BC,cw,dw,sw} == 4'b0001) ?                        // RT->BC SW
                             {rtaddress,message_error,inst,srv_rqst,rsvd,bc_rcvd,busy,sub_flag,dbctrl_acc,term_flag,paritybit}:
                             17'd0;

wire nodata;
assign nodata = (bit_cnt == 0 && bitcnt == 17) || (bit_cnt == 0 && bitcnt == 0) || (bit_cnt == 1 && bitcnt == 0)
                || (bit_cnt == 2 && bitcnt == 0);
                             
// Serialize the encoded data
always @(posedge dec_clk or negedge rst_n) begin
   if (!rst_n) begin   
      txdval   <= 1'b0 ;
      txdata   <= 1'b0 ;
      txdata_n <= 1'b0 ;
//   end else if (nodata) begin
//      txdata   <= data_sftreg_out[12] ;
//      txdata_n <= 1'b0;
   end else if (bypass == 1) begin
      txdval   <= 1'b0 ;
      txdata   <= data_sftreg_out[17] ;
      txdata_n <= data_sftreg_out_n[17] ;
   end else if (bit_cnt >= 3 && bit_cnt <= 5)  begin   
      txdval   <= 1'b0 ;
      txdata   <= data_sftreg_out[17] ;
      txdata_n <= data_sftreg_out_n[17] ;
   end else if (bit_cnt == 6 && samplecnt < 2 )  begin   
      txdval   <= 1'b0 ;
      txdata   <= data_sftreg_out[17] ;
      txdata_n <= data_sftreg_out_n[17] ;
   end else if (shift_data || bit_cnt >= 6) begin  
      txdval   <= 1'b1 ;
      txdata   <= enc_bit ;
      txdata_n <= enc_bit_n ;
   end else begin   
      txdval   <= 1'b0 ;
      txdata   <= data_sftreg_out[17] ;
      txdata_n   <= data_sftreg_out_n[17] ;
   end
end

assign tx_dval   = txdval;
//assign tx_data   = txdata;
assign tx_data_n = data_sftreg_out_n[16];

assign tx_data = data_sftreg_out[16];

// Memory RAM control signals
always @(posedge dec_clk or negedge rst_n) begin
   if (!rst_n) begin   
      enb <= 1'b0 ;
   end else if (bit_cnt == 5 && cnt == 33)  begin   
      enb <= 1'b1 ;
   end else begin   
      enb <= 1'b0 ;
   end
end

blk_mem_1553 blk_mem_1553_INST (
  .clka(sys_clk), // input clka
  .wea(mem_wea), // input [0 : 0] wea
  .addra(mem_addra), // input [6 : 0] addra
  .dina(mem_datin), // input [17 : 0] dina
  .clkb(dec_clk), // input clkb
  .enb(enb), // input enb
  .addrb(mem_addrb), // input [6 : 0] addrb
  .doutb(data_reg) // output [17 : 0] doutb
);

assign debug = {synccsword,syncdword,sync_found,sync_dw,data_edge,bitcnt[2:0]};

endmodule

// =============================================================================
