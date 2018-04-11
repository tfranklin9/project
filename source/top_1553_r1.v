// =============================================================================
//                           COPYRIGHT NOTICE
// =============================================================================
// =============================================================================
// Project          : 1553_enc_dec
// File             : top_1553.v
// Title            : 
// Dependencies     : encoder_1553.v
//                    decoder_1553.v 
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
            rxa_p ,
            rxa_n ,
            
            // Outputs
            //tx_data , 
            txa_p ,
            txa_n ,
            tx_dval , 
            tx_busy ,
            
            // Debug signals
            debug_out ,
            
            // switches
            switch7,
            switch8,
            switch9,
            switch10,
            //test_mode, // sw 9
            //loopback,  // sw 10

            txinha,
            txinhb,
            rxena,
            rxenb,
            stat0,
            stat1,
            stat2,
            stat3
            );
            
input          clk ;       // System clock.
input          reset_n ;     // Asynchronous reset.

input          rxa_p ;   // Serial transmit data input. 
input          rxa_n ;   // Serial transmit data input. 

output         txa_p ;   // Serial transmit data input. 
output         txa_n ;   // Serial transmit data input. 
output         tx_dval ;   // Indicates data on "tx_data" is valid.       
output         tx_busy ;   // Indicates tx is busy
//input  [19:0]  test_datin;
//input  [19:0]  debug_in ;  // Debug signals for transmit
//output         debug_out ;  // Debug signals for receive
output [5:0]   debug_out ;  // Debug signals for receive
//output [19:0]  test_datout;
input          switch7;
input          switch8;
input          switch9;
input          switch10;
//input          test_mode;
//input          loopback ;
//input          passthru ;
output         txinha;
output         txinhb;
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
wire [15:0]    rx_dword;
wire           rx_dval;
wire           rx_dw;
wire           rx_csw;

// misc
wire           enc_clk ;
wire           dec_clk ;
wire           serial_data ;
wire [19:0]   debug;

reg [7:0] reset_slow_buf = 8'b0;
reg reset_slow ;

// inputs.
//IBUFDS  #(.DIFF_TERM("TRUE")) inrx (.O (rx_data), .I (rxa_p), .IB (rxa_n)); 
assign rx_data = rxa_p; 
// outputs.
assign txa_p = tx_data;
assign txa_n = !tx_data;
//OBUFDS #(.IOSTANDARD("DEFAULT")) outtx (.O(txa_p), .OB(txa_n), .I(tx_data));


// generate reset 
wire reset;
wire clk_out;
assign reset = !reset_n;
always @(posedge clk_out)
begin
    reset_slow_buf <= { (!LOCKED&&!CLK_VALID), reset_slow_buf[7:1] };
    reset_slow     <= reset_slow_buf != 8'd0;
end
		
encoder_1553 u1_encoder (
            // Clock and Reset
            .enc_clk    ( enc_clk ),
            .rst_n      ( !reset_slow ),

            // Inputs
            .tx_dword   ( tx_dword ),
            .tx_csw     ( tx_csw ),
            .tx_dw      ( tx_dw ),

            // Outputs
            .tx_busy    ( tx_busy ),
            .tx_data    ( tx_data ), 
            .tx_dval    ( tx_dval )
            ) ;

assign serial_data = loopback ? (tx_data & tx_dval) : rx_data ;

decoder_1553 u1_decoder (
            // Clock and Reset
            .dec_clk    ( dec_clk ),
            .rst_n      ( !reset_slow ),

            // Inputs
            .rx_data    ( serial_data ),

            // Outputs
            .rx_dword   ( rx_dword ), 
            .rx_dval    ( rx_dval ),
            .rx_csw     ( rx_csw ),
            .rx_dw      ( rx_dw ),
            .rx_perr    ( rx_perr )
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
assign txinha = switch7 && 1'b1;
assign txinhb = switch8 && 1'b1;
assign rxena  = switch9 && 1'b1;
assign rxenb  = switch10 && 1'b1;
assign stat0 = switch7 && 1'b1;
assign stat1 = switch8 && 1'b1;
assign stat2 = switch9 && 1'b1;
assign stat3 = switch10 && 1'b1;
            
// test data in            
initial $readmemh("c:/Users/tfranklin9/projects/1553/source/rom.data", test_data);
reg  [17:0] test_data [0:511];
wire [19:0] datin;
reg  [8:0]  rom_add;
reg  wr_en, first_wr;
wire loopback, test_mode;
    
assign test_mode = 1'b0;
assign loopback = 1'b0;
always @(posedge dec_clk or posedge reset_slow)
begin
    if (reset_slow) begin
        rom_add <= 9'd0;
        wr_en   <= 1'b0;
        first_wr <= 1'b1;
    end else if( FULL == 0 && rom_add != 9'd511 && WRERR == 0 && test_mode == 1 && first_wr == 1) begin
        rom_add <= 9'd0;
        wr_en   <= 1'b1;
        first_wr <= 1'b0;
    end else if( FULL == 0 && rom_add != 9'd511 && WRERR == 0 && test_mode == 1) begin
    //end else if( FULL == 0 && WRERR == 0 && test_mode == 1) begin
        rom_add <= rom_add + 1;
        wr_en   <= 1'b1;
        first_wr <= 1'b0;
    end else begin
        wr_en   <= 1'b0;
    end
	 end
    
// Memory buffer.
   wire  RD_EN ;
   reg  [1:0] RDEN;
   reg  rd;
   wire RDERR;
   wire WRERR;
   wire FULL;
   wire EMPTY;
   wire [19:0] DO;
   wire [19:0] DI ;

   assign WREN = test_mode ? wr_en : rx_dval && !FULL;    
   assign datin = test_mode ? {2'b00,test_data[rom_add]} : {2'b00,rx_csw,rx_dw,rx_dword};
   bram_fifo bram_fifo_inst (
        .reset(reset_slow),
        // input fifo interface
        .DI( {2'b00,datin[17:0]} ), //{2'b00,DI[17:0]}),       			// must be hold while FULL is asserted
        .FULL(FULL),                    // 1-bit output: Full flag
        .WRERR(WRERR),                  // 1-bit output: Write error
        .WREN( WREN ), //DI[18]),                    // 1-bit input: Write enable
        .WRCLK(dec_clk),                  // 1-bit input: Rising edge write clock.
	    // output fifo interface
	    .DO(DO),
	    .EMPTY(EMPTY),                  // 1-bit output: Empty flag
        .RDERR(RDERR),                  // 1-bit output: Read error
        .RDCLK(enc_clk),                  // 1-bit input: Read clock
        .RDEN(RD_EN)                     // 1-bit input: Read enable
	// for debugging
    );

// generate Read enable
always @(posedge enc_clk or posedge reset_slow)
begin
    if(reset_slow)
        rd <= 1'b0;
    else if( tx_busy == 0 && EMPTY == 0)
        rd <= 1'b1;
    else
        rd <= 1'b0;
    end

always @ (posedge enc_clk or posedge reset_slow)
    begin
	    if ( reset_slow )
          RDEN <= 2'd0;
	    else
          RDEN <= {RDEN,rd}; 
		end


// read enable pulse
assign RD_EN = rd && ~RDEN[0];

// generate Read enable
always @(posedge enc_clk or posedge reset_slow)
begin
    if(reset_slow) begin
        tx_csw <= 1'b0;
        tx_dw <= 1'b0;
        tx_dword <= 15'b0;
    end else if( RD_EN ) begin
        tx_csw <= DO[17];
        tx_dw <= DO[16];
        tx_dword <= DO[15:0];
    end else begin
        tx_csw <= 1'b0;
        tx_dw <= 1'b0;
    end
end

//wire [15:0] txdword;
//wire txcsw, txdw;
//assign txdword = passthru ? rx_dword : tx_dword;
//assign txcsw   = passthru ? rx_csw : tx_csw;
//assign txdw    = passthru ? rx_dw : tx_dw;

////////////////////////////////////////////////////////
// Debug logic
// heartbeat counters for debug
reg [2:0] dec_cnt, enc_cnt, sys_cnt;
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
        dec_cnt <= 5'd0;
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
    end else if ( rx_dval == 1 ) begin
        add <= add + 1;
    end 
end

wire   [17:0] rxbus;
wire   error;
assign rxbus = {rx_csw,rx_dw,rx_dword};
assign error = rx_dval && !(rxbus == test_data[add]);

assign debug_out = {rx_dval,enc_cnt[2],WRERR,RDERR,FULL,EMPTY};//{rx_csw,rx_dw,rx_dval,rx_dword};          

////////////////////////////////////////////////////////

endmodule
// =============================================================================