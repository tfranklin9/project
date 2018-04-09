// =============================================================================
//                           COPYRIGHT NOTICE
// =============================================================================
// =============================================================================
// Project          : core_1553
// File             : top_1553.v
// Title            : 
// Dependencies     : encoder_1553.v
//                    core_1553.v 
//                    clock_module.v
// Description      : 
// =============================================================================
// REVISION HISTORY
// Version          : 1.0
// =============================================================================

module top_1553 (
            // Clock and Reset
            clk ,
            reset_n ,

            // Inputs
            rxa_p_BC ,
            rxa_n_BC ,
            rxa_p_RT ,
            rxa_n_RT ,
            
            // Outputs
            //tx_data , 
            txa_p_BC ,
            txa_n_BC ,
            txa_p_RT ,
            txa_n_RT ,
            tx_dval , 
            tx_busy ,
            
            // Debug signals
            debug_out ,
            
            // switches
            switch7,
            switch8,
            switch9,
            switch10,

            rxena,
            rxenb,
            stat0,
            stat1,
            stat2,
            stat3
            );
            
input          clk ;       // System clock.
input          reset_n ;     // Asynchronous reset.

input          rxa_p_BC ;   // Serial transmit data input. 
input          rxa_n_BC ;   // Serial transmit data input. 
input          rxa_p_RT ;   // Serial transmit data input. 
input          rxa_n_RT ;   // Serial transmit data input. 

output         txa_p_BC ;   // Serial transmit data input. 
output         txa_n_BC ;   // Serial transmit data input. 
output         txa_p_RT ;   // Serial transmit data input. 
output         txa_n_RT ;   // Serial transmit data input. 

output         tx_dval ;   // Indicates data on "tx_data" is valid.       
output         tx_busy ;   // Indicates tx is busy
output [7:0]   debug_out ;  // Debug signals for receive
input          switch7;
input          switch8;
input          switch9;
input          switch10;
output         rxena;
output         rxenb;
output         stat0;
output         stat1;
output         stat2;
output         stat3;



// Transmitt signals
reg [15:0]    tx_dword;
reg           tx_csw;
reg           tx_dw;

// Receive Signals
wire [15:0]   rx_dword_RT;
wire [15:0]   rx_dword_BC;
wire          rx_dval_BC;
wire          rx_dval_RT;
wire          rx_dw_BC;
wire          rx_dw_RT;
wire          rx_csw_BC;
wire          rx_csw_RT;

// misc
wire          enc_clk ;
wire          dec_clk ;
wire          serial_data ;
wire [19:0]   debug;
wire [9:0]    debug_core_BC;
wire [9:0]    debug_core_RT;

reg [7:0]     reset_slow_buf = 8'b0;
reg           reset_slow ;

wire          bypass_BC;
wire          bypass_RT;
wire          rxdw_edge;
wire          rxcsw_edge;
wire          tx_dval_csw;

// Memory signals
wire  [17:0] mem_datin_BC;
wire  [17:0] mem_datin_RT;
reg   [6:0]  mem_addra_BC;
reg   [6:0]  mem_addra_RT;
reg          mem_wea_BC;
reg          mem_wea_RT;

// inputs.
assign rx_data_BC   = rxa_p_BC; 
assign rx_data_n_BC = rxa_n_BC; 
assign rx_data_RT   = rxa_p_RT; 
assign rx_data_n_RT = rxa_n_RT; 
// outputs.
assign txa_p_BC = tx_dval ? tx_data_dw : tx_data_BC;
assign txa_n_BC = tx_dval ? tx_data_n_dw : (tx_dval_csw ? tx_data_n_BC : 1'b0);
//assign txa_n_BC = tx_dval ? tx_data_n_dw : tx_data_n_BC ;

//assign txa_p_BC = tx_data_BC;
//assign txa_n_BC = tx_data_n_BC;
assign txa_p_RT = tx_data_RT;
assign txa_n_RT = tx_data_n_RT;


// generate reset 
wire reset;
wire clk_out;
assign reset = !reset_n;
always @(posedge clk_out)
begin
    reset_slow_buf <= { (!LOCKED&&!CLK_VALID), reset_slow_buf[7:1] };
    reset_slow     <= reset_slow_buf != 8'd0;
end

reg [15:0] rxdata_BC;
reg [15:0] rxdata_RT;
reg rxcsw_BC, rxdw_BC, rxdval_BC;
reg rxcsw_RT, rxdw_RT, rxdval_RT;

encoder_1553 u1_encoder (
            // Clock and Reset
            .enc_clk    ( enc_clk ),
            .rst_n      ( !reset_slow ),

            // Inputs
//            .tx_dword   ( rxdata ),
            .tx_csw     ( rxcsw_edge ),
            .tx_dw      ( rxdw_edge ),

            // Outputs
            .tx_busy    ( tx_busy ),
            .tx_data    ( tx_data_dw ), 
            .tx_data_n  ( tx_data_n_dw ), 
            .tx_dval_csw( tx_dval_csw ),
            .tx_dval    ( tx_dval )
            ) ;

//assign serial_data = loopback ? (tx_data & tx_dval) : rx_data ;

core_1553 #( .BC(1))
         u1_core (
            // Clock and Reset
            .dec_clk    ( dec_clk ),
            .sys_clk    ( clk_out ),
            .rst_n      ( !reset_slow ),

            // Inputs
            .rx_data    ( rx_data_BC ),
            .rx_data_n  ( rx_data_n_BC ),
            .mem_wea    ( mem_wea_BC ),
            .mem_addra  ( mem_addra_BC ),
            .mem_datin  ( mem_datin_BC ),
            .bypass     ( bypass_BC ),

            // Outputs
            .rx_dword   ( rx_dword_BC ), 
            .rx_dval    ( rx_dval_BC ),
            .rx_csw     ( rx_csw_BC ),
            .rx_dw      ( rx_dw_BC ),
            .rx_perr    ( rx_perr_BC ),

            .tx_dval    ( tx_dval_BC),
            .tx_data    ( tx_data_BC),
            .tx_data_n  ( tx_data_n_BC),
            .debug      ( debug_core_BC)
            ) ;

core_1553 #( .BC(0))
         u2_core (
            // Clock and Reset
            .dec_clk    ( dec_clk ),
            .sys_clk    ( clk_out ),
            .rst_n      ( !reset_slow ),

            // Inputs
            .rx_data    ( rx_data_RT ),
            .rx_data_n  ( rx_data_n_RT ),
            .mem_wea    ( mem_wea_RT ),
            .mem_addra  ( mem_addra_RT ),
            .mem_datin  ( mem_datin_RT ),
            .bypass     ( bypass_RT ),

            // Outputs
            .rx_dword   ( rx_dword_RT ), 
            .rx_dval    ( rx_dval_RT ),
            .rx_csw     ( rx_csw_RT ),
            .rx_dw      ( rx_dw_RT ),
            .rx_perr    ( rx_perr_RT ),

            .tx_dval    ( tx_dval_RT),
            .tx_data    ( tx_data_RT),
            .tx_data_n  ( tx_data_n_RT),
            .debug      ( debug_core_RT)
            ) ;

clock_module clock_generation (
            // Clock in ports
            .CLK_IN1 ( clk ),     // Input clock 48 MHz
            // Clock out ports
            .CLK_OUT1( enc_clk ),     // 2MHz encode clock
            .CLK_OUT2( dec_clk ),     // 8MHz decode clock
            // Status and control signals
            .RESET( reset ),         // IN
            .LOCKED( LOCKED ),        // OUT
            .CLK_VALID( CLK_VALID ),   // OUT	
            .clk_out ( clk_out )   
            );   

// 1590 outputs
assign bypass_BC = switch7 ;
assign bypass_RT = switch8 ;
assign rxena  = switch9 && 1'b1;
assign rxenb  = switch10 && 1'b1;
assign stat0 = enc_cnt[0];
assign stat1 = enc_cnt[1];
assign stat2 = enc_cnt[2];
assign stat3 = enc_cnt[3];

// sync and stretch rx_signals
always @ (posedge dec_clk or posedge reset_slow)
    begin
	    if ( reset_slow ) begin
          rxdval_BC <= 1'd0;
//          rxcsw_BC  <= 1'b0;
//          rxdw_BC   <= 1'b0;
          rxdata_BC <= 16'd0;
	    end else if (rx_dval_BC) begin
          rxdval_BC <= 1'b1; 
//          rxcsw_BC  <= rx_csw_BC;
//          rxdw_BC   <= rx_dw_BC;
          rxdata_BC <= rx_dword_BC;
        end else if (dec_cnt == 4 && rxdval_BC == 1'b1) begin
          rxdval_BC <= 1'b0;
//          rxcsw_BC  <= 1'b0;
//          rxdw_BC   <= 1'b0;
          rxdata_BC <= 16'd0;
		end
end

wire rx_data_word; 
reg [0:4] rxdw; 
// register rx_dw signal
always @(posedge dec_clk or posedge reset_slow) begin
   if ( reset_slow ) begin   
      rxdw <= 5'd0 ;
   end
   else begin 
      rxdw <= {rxdw[1:4],rx_dw_BC} ;
   end
end
assign rx_data_word = |rxdw;

reg [0:2] rxdw_enc; 
// register rx_dw signal
always @(posedge enc_clk or posedge reset_slow) begin
   if ( reset_slow ) begin   
      rxdw_enc <= 3'd0 ;
   end
   else begin 
      rxdw_enc <= {rxdw_enc[1:2],rx_data_word} ;
   end
end

// Detect rising edge and pulse one enc_clk.
assign rxdw_edge =  rxdw_enc[1] && ~rxdw_enc[0] ;

wire rx_cs_word; 
reg [0:4] rxcsw; 
// register tx_dw signal
always @(posedge dec_clk or posedge reset_slow) begin
   if ( reset_slow ) begin   
      rxcsw <= 5'd0 ;
   end
   else begin 
      rxcsw <= {rxcsw[1:4],rx_csw_BC} ;
   end
end
assign rx_cs_word = |rxcsw;


// Detect rising edge and pulse one enc_clk.
assign rxcsw_edge =  rxcsw[1] && ~rxcsw[0] ;

// test data in            
//initial $readmemh("c:/Users/tfranklin9/projects/1553/source/rom.data", test_data);
//reg  [17:0] test_data [0:511];
//wire [19:0] datin;
//reg  [8:0]  rom_add;
//reg  wr_en, first_wr;
//wire loopback, test_mode;
//    
//assign test_mode = 1'b0;
//assign loopback = 1'b0;
//always @(posedge dec_clk or posedge reset_slow)
//begin
//    if (reset_slow) begin
//        rom_add <= 9'd0;
//        wr_en   <= 1'b0;
//        first_wr <= 1'b1;
//    end else if( FULL == 0 && rom_add != 9'd511 && WRERR == 0 && test_mode == 1 && first_wr == 1) begin
//        rom_add <= 9'd0;
//        wr_en   <= 1'b1;
//        first_wr <= 1'b0;
//    end else if( FULL == 0 && rom_add != 9'd511 && WRERR == 0 && test_mode == 1) begin
//        rom_add <= rom_add + 1;
//        wr_en   <= 1'b1;
//        first_wr <= 1'b0;
//    end else begin
//        wr_en   <= 1'b0;
//    end
//end
    
//assign txdword = passthru ? rx_dword : tx_dword;
//assign txcsw   = passthru ? rx_csw : tx_csw;
//assign txdw    = passthru ? rx_dw : tx_dw;

////////////////////////////////////////////////////////
// Debug logic
// heartbeat counters for debug
reg [5:0] dec_cnt, enc_cnt, sys_cnt;
always @(posedge enc_clk or posedge reset_slow)
begin
    if (reset_slow) begin
        enc_cnt <= 5'd0;
    end else begin
        enc_cnt <= enc_cnt + 1;
    end
end

always @(posedge dec_clk or posedge reset_slow)
begin
    if (reset_slow) begin
        dec_cnt <= 3'd0;
    end else if (rx_dval_BC) begin
        dec_cnt <= 3'd0;
    end else begin
        dec_cnt <= dec_cnt + 1;
    end
end

always @(posedge clk_out or posedge reset_slow)
begin
    if (reset_slow) begin
        sys_cnt <= 5'd0;
    end else begin
        sys_cnt <= sys_cnt + 1;
    end
end

reg [8:0] add;
always @(posedge dec_clk or posedge reset_slow)
begin
    if (reset_slow) begin
        add <= 9'd0;
    end else if ( rx_dval_BC == 1 ) begin
        add <= add + 1;
    end 
end

//wire   [17:0] rxbus;
//wire   error;
//assign rxbus = {rx_csw,rx_dw,rx_dword};
//assign error = rx_dval && !(rxbus == test_data[add]);

//assign debug_out = {rx_dval,enc_cnt[2],WRERR,RDERR,FULL,EMPTY};//{rx_csw,rx_dw,rx_dval,rx_dword};          
assign debug_out = {debug_core_BC[9],tx_data_n_BC,tx_data_n_dw,rxcsw_edge,rxdw_edge,tx_dval_csw,tx_data_BC,tx_data_dw};//{rx_csw,rx_dw,rx_dval,rx_dword};          

//////////////////////////////////////////////////
// This logic is just for testing.
// Fill up the memory with test data.
//////////////////////////////////////////////////
initial $readmemh("c:/Users/tfranklin9/projects/1553/source/mem.data", mem_data);
reg  [17:0] mem_data [0:511];
reg  first_wr;

always @(posedge clk_out or negedge reset_slow)
begin
    if (!reset_slow) begin
        mem_addra_BC <= 7'd0;
        mem_wea_BC   <= 1'b0;
        first_wr     <= 1'b1;
    end else if( first_wr == 1) begin
        mem_addra_BC <= 7'd0;
        mem_wea_BC   <= 1'b1;
        first_wr     <= 1'b0;
    end else if( mem_addra_BC != 511 ) begin
        mem_addra_BC <= mem_addra_BC + 1;
        mem_wea_BC   <= 1'b1;
        first_wr     <= 1'b0;
    end else begin
        mem_wea_BC      <= 1'b0;
    end
end

assign mem_datin_BC = mem_data[mem_addra_BC];

////////////////////////////////////////////////////////

endmodule
// =============================================================================