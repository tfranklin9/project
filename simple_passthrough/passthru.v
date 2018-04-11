/*%
   passthru.v -- Just a simple passthru
%*/

module passthru (
    input fxclk,
    input reset_n,

    // rx data in
	input rxa_n,
	input rxa_p,
	input rxb_n,
	input rxb_p,

    // tx data in
	output txa_n,
	output txa_p,
	output txb_n,
	output txb_p,

    output [9:0] led1,
    output [9:0] led2,
    output [9:0] led3
    );

    wire rst_out;
    wire enc_clk;
    wire dec_clk;
    wire LOCKED;
    wire CLK_VALID;

    reg [2:0] tx_a_p;
    reg [2:0] tx_b_p;
    reg [2:0] tx_a_n;
    reg [2:0] tx_b_n;
    reg [9:0] cnt2;
    reg [9:0] cnt3;
    reg [9:0] led2_cnt;
    reg [9:0] led3_cnt;
    
    clock_module clock_generation (
            // Clock in ports
            .CLK_IN1 ( fxclk ),     // Input clock 48 MHz
            // Clock out ports
            .CLK_OUT1( enc_clk ),     // 2MHz encode clock
            .CLK_OUT2( dec_clk ),     // 8MHz decode clock
            // Status and control signals
            .RESET( ~reset_n ),       // IN
            .LOCKED( LOCKED ),        // OUT
            .CLK_VALID( CLK_VALID )   // OUT	
            );   

    always @ (posedge enc_clk or negedge reset_n)
    begin
	   if ( !reset_n ) 
         cnt2 <= 10'd0;
	   else 
         cnt2 <= cnt2 + 1;
    end

    always @ (posedge enc_clk or negedge reset_n)
    begin
	   if ( !reset_n ) 
         led2_cnt <= 10'd0;
	   else if (cnt2 == 1023)
         led2_cnt <= led2_cnt + 1;
    end

    always @ (posedge dec_clk or negedge reset_n)
    begin
	   if ( !reset_n ) 
         cnt3 <= 10'd0;
	   else 
         cnt3 <= cnt3 + 1;
    end

    always @ (posedge dec_clk or negedge reset_n)
    begin
	   if ( !reset_n ) 
         led3_cnt <= 10'd0;
	   else if (cnt3 == 1023)
         led3_cnt <= led3_cnt + 1;
    end
            
    // always @ (posedge fx_clk or negedge reset_n)
    // begin
	  // if ( reset_n ) 
         // tx_a <= 3'd0;
         // tx_b <= 3'd0;
	  // else 
         // tx_a <= {tx_a[2:1],rxa_p}; 
         // tx_b <= {tx_b[2:1],rxb_p}; 
    // end

//    assign txa_p = tx_a[2];
//    assign txb_p = tx_b[2];
//    assign txa_n = ~tx_a[2];
//    assign txb_n = ~tx_b[2];


/*    always @ (posedge enc_clk or negedge reset_n)
    begin
	  if ( !reset_n ) begin
         tx_a_p <= 3'd0;
         tx_b_p <= 3'd0;
         tx_a_n <= 3'd0;
         tx_b_n <= 3'd0;
	  end else begin
         tx_a_p <= {tx_a_p[1:0],rxa_p}; 
         tx_b_p <= {tx_b_p[1:0],rxb_p}; 
         tx_a_n <= {tx_a_n[1:0],rxa_n}; 
         tx_b_n <= {tx_b_n[1:0],rxb_n}; 
     end
    end

    assign txa_p = tx_a_p[2];
    assign txb_p = tx_b_p[2];
    assign txa_n = tx_a_n[2];
    assign txb_n = tx_b_n[2]; */

    assign txa_p = rxa_p && 1'b1;
    assign txb_p = rxb_p && 1'b1;
    assign txa_n = rxa_n && 1'b1;
    assign txb_n = rxb_n && 1'b1;
//    assign rst_out = reset_n;
    
    assign led1 = {CLK_VALID,LOCKED,txa_p,txa_n,txb_p,txb_n,rxa_p,rxa_n,rxb_p,rxb_n};
    assign led2 = {led2_cnt};
    assign led3 = {led3_cnt};

endmodule

