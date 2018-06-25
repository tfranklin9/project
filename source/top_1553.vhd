-- =============================================================================
--                           COPYRIGHT NOTICE
-- =============================================================================
-- =============================================================================
-- Project          : core_1553
-- File             : top_1553.v
-- Title            : 
-- Dependencies     : encoder_1553.v
--                    core_1553.v 
--                    clock_module.v
-- Description      : 
-- =============================================================================
-- REVISION HISTORY
-- Version          : 1.0
-- =============================================================================
library ieee , UNISIM;
use ieee.std_logic_1164.all ;
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.ALL;
use STD.textio.all;
use ieee.std_logic_textio.all;

entity top_1553 is
generic (
            SIM_VIVADO : boolean := FALSE );
port (
            -- Clock and Reset
            clk       : in std_logic;   -- System clock.
            reset_n   : in std_logic;   -- Asynchronous reset.          

            -- Inputs
            --rx_data , 
            rxa_p_BC  : in std_logic;   -- Serial transmit data input. 
            rxa_n_BC  : in std_logic;   -- Serial transmit data input. 

            -- Outputs
            --tx_data , 
            txa_p_BC  : out std_logic;   -- Serial transmit data input. 
            txa_n_BC  : out std_logic;   -- Serial transmit data input. 
           
            tx_dval   : out std_logic;   -- Indicates data on "tx_data" is valid.      
            tx_busy   : out std_logic;   -- Indicates tx is busy

            -- Debug signals
            debug_out : out std_logic_vector(7 downto 0);  -- Debug signals for receive
            
            -- switches
            switch7   : in std_logic;
            switch8   : in std_logic;
            switch9   : in std_logic;
            switch10  : in std_logic;

            rxena     : out std_logic;
            rxenb     : out std_logic;
            stat0     : out std_logic;
            stat1     : out std_logic;
            stat2     : out std_logic;
            stat3     : out std_logic;

            -- capture signals 
            csw         : out std_logic;
            dw          : out std_logic;
            enc_data    : out std_logic;
            enc_data_en : out std_logic;

            -- capture signals 
           triggerA    : out std_logic ;                     
           triggerB    : out std_logic ;                     
           triggerC    : out std_logic                      

            );
end top_1553;
            
architecture behavioral of top_1553 is           

-- Trigger constants (these numbers are estimates 
-- These numbers are estimates based on a 20Hz(50ms) transaction period and each period containing ~34 words
-- with possible 12us gaps.
-- max wait  value is 32 us
-- max delay value is 1088 us (34 words + 34, 12us gaps (worse case))
-- max trigger hold  value is 49296 us (50ms - 34 words + 2*12 us gaps)
-- max trigger delay value is 49276 us (maxhold - 20us) ) 
-- units (microseconds), * zero not allowed.
-- Set the wait, delay, and trigger hld and delay values. 
constant WAIT_MAX  : positive := 32 ;
constant DELAY_MAX : positive := 1000 ;
constant HLD_MAXA  : positive := 1088 ; 
constant DLY_MAXA  : positive := 2 ; 
constant HLD_MAXB  : positive := 544 ; 
constant DLY_MAXB  : positive := 2 ; 
constant HLD_MAXC  : positive := 272 ; 
constant DLY_MAXC  : positive := 2 ;

-- specify when there is no hold or delay for trigger
constant NO_HLDA  : std_logic := '0'; 
constant NO_DLYA  : std_logic := '0'; 
constant NO_HLDB  : std_logic := '0'; 
constant NO_DLYB  : std_logic := '0'; 
constant NO_HLDC  : std_logic := '0'; 
constant NO_DLYC  : std_logic := '0';


-- Transmitt signals
signal tx_csw   :   std_logic;
signal tx_dw    :   std_logic;
signal rt_address  : std_logic_vector(4 downto 0);
signal sub_address : std_logic_vector(4 downto 0);
signal dwcnt_mcode : std_logic_vector(4 downto 0);
signal tr          : std_logic;
signal parity_bit  : std_logic;
signal rt_address_RT  : std_logic_vector(4 downto 0);
signal sub_address_RT : std_logic_vector(4 downto 0);
signal dwcnt_mcode_RT : std_logic_vector(4 downto 0);
signal tr_RT          : std_logic;
signal parity_bit_RT  : std_logic;

signal tx_data_BC   : std_logic;
signal tx_data_RT   : std_logic;
signal tx_data_n_BC : std_logic;
signal tx_data_n_RT : std_logic;
signal tx_dval_BC   : std_logic;
signal tx_dval_RT   : std_logic;

-- Encode signals
--signal tx_busy      : std_logic;
signal tx_data_dw   : std_logic;
signal tx_data_n_dw : std_logic;
signal tx_dval_csw  : std_logic;
signal tx_dval_enc  : std_logic;
signal txdval       : std_logic;

signal tx_data_delay   : std_logic_vector(40 downto 0);
signal tx_data_delay_n : std_logic_vector(40 downto 0);
signal dval_delay      : std_logic_vector(40 downto 0);

-- Receive Signals
signal rx_dword_RT : std_logic_vector(15 downto 0);
signal rx_dword_BC : std_logic_vector(15 downto 0);
signal rx_dval_BC  : std_logic;
signal rx_dval_RT  : std_logic;
signal rx_dw_BC    : std_logic;
signal rx_dw_RT    : std_logic;
signal rx_csw_BC   : std_logic;
signal rx_csw_RT   : std_logic;

signal rx_perr_BC  : std_logic;
signal rx_perr_RT  : std_logic;
signal rx_data_BC   : std_logic_vector(2 downto 0);  
signal rx_data_n_BC : std_logic_vector(2 downto 0);
signal rx_data_RT   : std_logic_vector(2 downto 0);
signal rx_data_n_RT : std_logic_vector(2 downto 0);

signal rxdw_edge    : std_logic;
signal rxcsw_edge   : std_logic;

signal rx_data_word : std_logic;
signal rx_cs_word   : std_logic;
signal rxdw      : std_logic_vector(5 downto 0);
signal rxdw_enc  : std_logic_vector(5 downto 0);
signal rxcsw     : std_logic_vector(5 downto 0);
signal rxcsw_enc : std_logic_vector(5 downto 0);

-- Clock and reset signals
signal sys_clk       : std_logic;
signal enc_clk       : std_logic;
signal enc_clk2      : std_logic;
signal dec_clk       : std_logic;
signal clk_16M       : std_logic;
signal LOCKED 	     : std_logic;
signal CLK_VALID     : std_logic;
signal clk_out 	     : std_logic;
signal clkcnt        : std_logic_vector(1 downto 0);
signal encclk_en     : std_logic;
signal reset 	     : std_logic;
signal reset_slow     : std_logic;
signal reset_slow_n   : std_logic;
signal reset_slow_buf : std_logic_vector(7 downto 0);

signal bypass      : std_logic;
signal bypass_BC   : std_logic;
signal bypass_RT   : std_logic;
signal serial_data   : std_logic;

-- Debug signals
--signal debug         : std_logic_vector(19 downto 0);
signal debug_core_BC   : std_logic_vector(7 downto 0);
signal debug_core_RT   : std_logic_vector(7 downto 0);

-- Filter signals
signal rtadd_match     : std_logic;
signal subadd_match    : std_logic;
signal tr_match        : std_logic;
signal rt_filter       : std_logic_vector(4 downto 0);
signal sub_filter      : std_logic_vector(4 downto 0);
signal tr_filter       : std_logic;
signal address_match   : std_logic;
signal filtermatch     : std_logic;
signal filter_match    : std_logic;
signal filtermatch_d   : std_logic;
signal filtermatch_dd  : std_logic;
signal filtermatch_ddd : std_logic;
signal end_of_payload  : std_logic;
signal lastword        : std_logic;
signal lastword_RT     : std_logic;
signal txdval_enc      : std_logic;
signal txdval_ddd,txdval_dd,txdval_d : std_logic;


-- Memory signals
signal first_wr  : std_logic;
signal mem_datin_BC : std_logic_vector(17 downto 0);
signal mem_datin_RT : std_logic_vector(17 downto 0);
signal mem_addra_BC : std_logic_vector(6 downto 0);
signal mem_addra_RT : std_logic_vector(6 downto 0);
signal mem_wea_BC   : std_logic_vector(0 downto 0);
signal mem_wea_RT   : std_logic_vector(0 downto 0);
type mem_type     is array (0 to 511) of std_logic_vector(17 downto 0);
type payload_type is array (0 to 511) of std_logic_vector(16 downto 0);
signal mem : mem_type := (others => (others => '0'));
signal payload_mem : payload_type := (others => (others => '0'));

-- BUFGCE component declaration 
component BUFGCE 
    port ( 
        I : in std_logic; 
        CE : in std_logic; 
        O : out std_logic); 
    end component; 

component core_1553
    generic (   BC      : std_logic );
    port    (
        dec_clk : in std_logic;  -- 8Mhz decoder clock.
        sys_clk : in std_logic;
        rst_n   : in std_logic;  -- async reset
        rx_data     : in std_logic;  --serial data input
        rx_data_n   : in std_logic;
        mem_wea     : in std_logic_vector(0 downto 0);
        mem_addra   : in std_logic_vector(6 downto 0);
        mem_datin   : in std_logic_vector(17 downto 0);
        bypass      : in std_logic;            
        lastword    : in std_logic;
        rx_dword    : out std_logic_vector(15 downto 0) ; 
        rx_dval     : out std_logic ;                     
        rx_csw      : out std_logic ;                     
        rx_dw       : out std_logic ;                     
        rx_perr     : out std_logic ;                     
        tx_data     : out std_logic ;
        tx_data_n   : out std_logic ;
        tx_dval     : out std_logic ;
        rt_address  : out std_logic_vector(4 downto 0);
        tr          : out std_logic ;
        sub_address : out std_logic_vector(4 downto 0);
        dwcnt_mcode : out std_logic_vector(4 downto 0);
        parity_bit  : out std_logic ;
        debug       : out std_logic_vector(7 downto 0);
        enc_data    : out std_logic;
        enc_data_en : out std_logic
        ) ;
end component;

component encoder_1553
    port    (
       	enc_clk         : in std_logic; -- 2MHz encode clock
    	rst_n           : in std_logic;
        filter_match    : in std_logic;
        tx_csw          : in std_logic; -- "tx_dword" has command or status word.
        tx_dw           : in std_logic; -- "tx_dword" has data word.
        rt_address      : in std_logic_vector(4 downto 0);
        tr              : in std_logic; 
        sub_address     : in std_logic_vector(4 downto 0); 
        dwcnt_mcode     : in std_logic_vector(4 downto 0); 
        parity_bit      : in std_logic; 
        end_of_payload  : out std_logic ;
        last_word       : out std_logic;
        tx_busy         : out std_logic;
        tx_data         : out std_logic;
        tx_data_n       : out std_logic;
        tx_dval_csw     : out std_logic;
        tx_dval         : out std_logic
    );
end component;

component trigger
    generic (
               WAIT_VALUE  : positive range 11 to 255 ;
               DELAY_VALUE : positive range 19 to 16383 ;
               DLY_VALUEA  : positive := 49276;
               HLD_VALUEA  : positive := 49276;
               DLY_VALUEB  : positive := 49276;
               HLD_VALUEB  : positive := 49276;
               DLY_VALUEC  : positive := 49276;
               HLD_VALUEC  : positive := 49276;
               NO_HLDA    : std_logic := '0';
               NO_DLYA    : std_logic := '0';
               NO_HLDB    : std_logic := '0';
               NO_DLYB    : std_logic := '0';
               NO_HLDC    : std_logic := '0';
               NO_DLYC    : std_logic := '0'
            );
    port    (
               -- Clock and Reset
               clk         : in std_logic;  -- 8Mhz decoder clock.
               rst_n       : in std_logic;  -- async reset
               -- Inputs
               serial_in   : in std_logic;
               csw_in      : in std_logic;
               -- Outputs
               triggerA    : out std_logic ;                     
               triggerB    : out std_logic ;                     
               triggerC    : out std_logic ;                     
               debug       : out std_logic_vector(9 downto 0)
    ) ;
end component;

component clock_module_vivado
    port (
        -- Clock out ports
        clk_out1          : out    std_logic;
        clk_out2          : out    std_logic;
        clk_out3          : out    std_logic;
        clk_out4          : out    std_logic;
        -- Status and control signals
        reset             : in     std_logic;
        locked            : out    std_logic;
        -- Clock in ports
        clk_in1           : in     std_logic
        );
end component;

component clock_module
    port (
        -- Clock in ports
        CLK_IN1           : in     std_logic;
        -- Clock out ports
        CLK_OUT1          : out    std_logic;
        CLK_OUT2          : out    std_logic;
        CLK_OUT3          : out    std_logic;
        -- Status and control signals
        RESET             : in     std_logic;
        LOCKED            : out    std_logic;
        CLK_VALID         : out    std_logic
        );
end component;

function Reduce_OR(arg : std_logic_vector) return std_logic is
  variable result : std_logic := '0';
begin
  result := '0';
  for i in arg'range loop
    result := arg(i) or result;
  end loop;
  return result;
end Reduce_OR;

function Reduce_AND(arg : std_logic_vector) return std_logic is
  variable result : std_logic := '0';
begin
  result := '1';
  for i in arg'range loop
    result := arg(i) and result;
  end loop;
  return result;
end Reduce_AND;

begin
    
----------------------------------------------------------------------
-- generate reset 
reset <= NOT reset_n;
reset_slow_n <= NOT reset_slow;

resetgen : process(sys_clk) 
begin
    if rising_edge(sys_clk) then
       if (reset_slow_buf /= x"00") then
          reset_slow <= '1';
       else 
          reset_slow <= '0';
       end if;
       reset_slow_buf(7 downto 1) <= reset_slow_buf(6 downto 0) ;
       reset_slow_buf(0) <= NOT LOCKED AND NOT CLK_VALID;
   end if;
end process;

-- Clock Generation

clk_gen_sim : if SIM_VIVADO generate 
clock_generation : clock_module_vivado
         port map (
            -- Clock out ports
            clk_out1  => enc_clk2,     -- 2MHz encode clock
            clk_out2  => dec_clk,     -- 8MHz decode clock
	        clk_out3  => clk_16M,
            clk_out4  => sys_clk,
            -- Status and control signals
            reset     => reset,       -- IN
            locked    => LOCKED,      -- OUT
            -- Clock in ports
            clk_in1   => clk         -- Input clock 48 MHz
         );   

    CLK_VALID <= '1';

-- generate slow count. Only needed for Vivado supported parts.
clkcntr: process(reset,enc_clk2)
begin
    if (reset = '1') then
       clkcnt <= (others => '0');
    elsif rising_edge(enc_clk2) then
       clkcnt <= clkcnt + 1 ;
    end if;
end process;
encclk_en <= Reduce_AND(clkcnt);

BUFGCE_inst : BUFGCE
    port map (
        O => enc_clk,    -- 1-bit output: Buffer
        CE => encclk_en, -- 1-bit input: Buffer enable
        I => enc_clk2    -- 1-bit input: Buffer
    );
-- End of BUFGCE_inst instantiation
end generate;

clk_gen : if not SIM_VIVADO generate 
clock_generation : clock_module 
         port map (
            -- Clock in ports
            CLK_IN1   => clk,         -- Input clock 48 MHz
            -- Clock out ports
            CLK_OUT1  => enc_clk,     --  2MHz encode clock
            CLK_OUT2  => dec_clk,     --  8MHz decode clock
	        CLK_OUT3  => sys_clk,     -- 48MHz system clock
            -- Status and control signals
            RESET     => reset,       -- IN
            LOCKED    => LOCKED,      -- OUT
            CLK_VALID => CLK_VALID    -- OUT	
         );   
end generate;

----------------------------------------------------------------------
-- Sync inputs
syncinputs: process(sys_clk,reset_slow)
begin
    if (reset_slow = '1') then 
        rx_data_BC   <= (others => '0'); 
        rx_data_n_BC <= (others => '0'); 
        rx_data_RT   <= (others => '0'); 
        rx_data_n_RT <= (others => '0'); 
    elsif rising_edge(sys_clk) then
        rx_data_BC(2 downto 1)   <= rx_data_BC(1 downto 0); 
	    rx_data_BC(0)            <= rxa_p_BC;
        rx_data_n_BC(2 downto 1) <= rx_data_n_BC(1 downto 0); 
	    rx_data_n_BC(0)          <= rxa_n_BC;
        rx_data_RT               <= (others => '0'); 
	    rx_data_n_RT             <= (others => '0');
    end if;
end process;

u1_core : core_1553
         generic map ( 
            BC => '1' )
         port map (
            -- Clock and Reset
            dec_clk    => dec_clk,
            sys_clk    => sys_clk,
            rst_n      => reset_slow_n,

            -- Inputs
            rx_data    => rx_data_BC(2),
            rx_data_n  => rx_data_n_BC(2),
            mem_wea    => mem_wea_BC,
            mem_addra  => mem_addra_BC,
            mem_datin  => mem_datin_BC,
            bypass     => bypass_BC,
            lastword   => lastword,

            -- Outputs
            rx_dword   => rx_dword_BC, 
            rx_dval    => rx_dval_BC,
            rx_csw     => rx_csw_BC,
            rx_dw      => rx_dw_BC,
            rx_perr    => rx_perr_BC,

            tx_data     => tx_data_BC,
            tx_data_n   => tx_data_n_BC,
            tx_dval     => tx_dval_BC,
            rt_address  => rt_address ,
            tr          => tr ,
            sub_address => sub_address ,
            dwcnt_mcode => dwcnt_mcode ,
            parity_bit  => parity_bit ,
            debug       => debug_core_BC,
            enc_data    => enc_data,
            enc_data_en => enc_data_en
         ) ;

u2_core : core_1553 
         generic map (
            BC => '0' )
         port map (
            -- Clock and Reset
            dec_clk    => dec_clk,
            sys_clk    => sys_clk,
            rst_n      => reset_slow_n,

            -- Inputs
            rx_data    => rx_data_RT(2),
            rx_data_n  => rx_data_n_RT(2),
            mem_wea    => mem_wea_RT,
            mem_addra  => mem_addra_RT,
            mem_datin  => mem_datin_RT,
            bypass     => bypass_RT,
            lastword   => lastword_RT,

            -- Outputs
            rx_dword   => rx_dword_RT, 
            rx_dval    => rx_dval_RT,
            rx_csw     => rx_csw_RT,
            rx_dw      => rx_dw_RT,
            rx_perr    => rx_perr_RT,

            tx_data    => tx_data_RT,
            tx_data_n  => tx_data_n_RT,
            tx_dval    => tx_dval_RT,
            rt_address  => open ,
            tr          => open ,
            sub_address => open ,
            dwcnt_mcode => open ,
            parity_bit  => open ,
            debug       => open ,
            enc_data    => open ,
            enc_data_en => open
         ) ;

----------------------------------------------------------------------
-- detect rising edge of dw and csw and pulse one enc_clk
dw_edge: process(reset_slow,dec_clk)
begin
    if (reset_slow = '1') then
       rxdw <= (others => '0');
    elsif rising_edge(dec_clk) then
       rxdw(5 downto 1) <= rxdw(4 downto 0);
       rxdw(0)          <= rx_dw_BC;
    end if;
end process;
rx_data_word <= Reduce_OR(rxdw);

dw_enc: process(reset_slow,enc_clk)
begin
    if (reset_slow = '1') then
       rxdw_enc <= (others => '0');
    elsif rising_edge(enc_clk) then
       rxdw_enc(3 downto 1) <= rxdw_enc(2 downto 0);
       rxdw_enc(0)          <= rx_data_word;
    end if;
end process;
rxdw_edge <= rxdw_enc(2) and not (rxdw_enc(3));

csw_edge: process(reset_slow,dec_clk)
begin
    if (reset_slow = '1') then
       rxcsw <= (others => '0');
    elsif rising_edge(dec_clk) then
       rxcsw(5 downto 1) <= rxcsw(4 downto 0);
       rxcsw(0)          <= rx_csw_BC;
    end if;
end process;
rx_cs_word <= Reduce_OR(rxcsw);

csw_enc: process(reset_slow,enc_clk)
begin
    if (reset_slow = '1') then
       rxcsw_enc <= (others => '0');
    elsif rising_edge(enc_clk) then
       rxcsw_enc(3 downto 1) <= rxcsw_enc(2 downto 0);
       rxcsw_enc(0)          <= rx_cs_word;
    end if;
end process;
rxcsw_edge <= rxcsw_enc(2) and not (rxcsw_enc(3));

----------------------------------------------------------------------
-- Filter matching logic

-- hardwire filters for now
rt_filter  <= "01011";
sub_filter <= "00001";
tr_filter  <= '1';

rtadd_match   <= '1' when (rt_address = rt_filter) else '0';
subadd_match  <= '1' when (sub_address = sub_filter) else '0';
tr_match      <= '1' when (tr = tr_filter) else '0';
address_match <= rtadd_match and subadd_match;  -- add direction later

filter_proc : process(enc_clk,reset_slow,address_match,end_of_payload)
    begin
        if ( reset_slow  = '1') then 
            filtermatch <= '0';
        elsif ( address_match = '1' ) then 
            filtermatch <= '1';
        elsif ( end_of_payload = '1' ) then 
            filtermatch <= '0'; 
        end if;
    end process;

filter : process(enc_clk,reset_slow)
    begin
        if ( reset_slow = '1' ) then 
          filtermatch_d  <= '0';
          filtermatch_dd <= '0';
          filtermatch_ddd <= '0';
        else 
          filtermatch_d  <= filtermatch;
          filtermatch_dd <= filtermatch_d;
          filtermatch_ddd <= filtermatch_dd;
        end if;
    end process;


filter_match <= filtermatch or filtermatch_d or filtermatch_dd or filtermatch_ddd;

dval : process(enc_clk,reset_slow)
    begin
        if ( reset_slow = '1' ) then 
          txdval_d   <= '0';
          txdval_dd  <= '0';
          txdval_ddd <= '0';
        else
          txdval_d  <= txdval;
          txdval_dd <= txdval_d;
          txdval_ddd <= txdval_dd;
        end if;
    end process;
txdval_enc <= txdval or txdval_d or txdval_dd or txdval_ddd;

----------------------------------------------------------------------
-- Encoder runs in parallel with core. 
u1_encoder : encoder_1553 
         port map (
            -- Clock and Reset
            enc_clk    => enc_clk,
            rst_n      => reset_slow_n,
            -- Inputs
            filter_match =>  filter_match ,
            tx_csw       =>  rxcsw_edge ,
            tx_dw        =>  rxdw_edge ,
            rt_address   =>  rt_address ,
            tr           =>  tr ,
            sub_address  =>  sub_address ,
            dwcnt_mcode  =>  dwcnt_mcode ,
            parity_bit   =>  parity_bit ,
            -- Outputs
            end_of_payload => end_of_payload ,
            last_word      => lastword ,
            tx_busy        => tx_busy ,
            tx_data        => tx_data_dw , 
            tx_data_n      => tx_data_n_dw , 
            tx_dval_csw    => tx_dval_csw ,
            tx_dval        => tx_dval_enc 
         );

----------------------------------------------------------------------
-- create encoded 1553 from delayed output from encode
dlyenc : process(sys_clk,reset_slow)
    begin
        if ( reset_slow = '1' ) then 
          dval_delay      <= (others => '0') ;
          tx_data_delay   <= (others => '0') ;
          tx_data_delay_n <= (others => '0') ;
        else
          dval_delay(40 downto 1)      <= dval_delay(39 downto 0);
          dval_delay(0)                <= tx_dval_enc;
          tx_data_delay(40 downto 1)   <= tx_data_delay(39 downto 0);
          tx_data_delay(0)             <= tx_data_dw;
          tx_data_delay_n(40 downto 1) <= tx_data_delay_n(39 downto 0);
          tx_data_delay_n(0)           <= tx_data_n_dw;
        end if;
    end process;

-- This logic handles the output muxing between the incoming 1553, command word, matching, bypass, etc
-- This needs to be rethought and corrected. Mainly using 48Mhz clock.
    txa_p_BC <= tx_data_BC when (bypass = '1') else 
                tx_data_BC when (tx_dval_csw = '1') else
                tx_data_BC when (not ((txdval_enc and filter_match) or (txdval_enc and not filter_match)) = '1') else
                tx_data_delay(13);
    txa_n_BC <= tx_data_n_BC when (bypass = '1') else 
                tx_data_n_BC when (tx_dval_csw = '1') else
                tx_data_n_BC when (not ((txdval_enc and filter_match) or (txdval_enc and not filter_match)) = '1') else
                tx_data_delay_n(13);

-- Assigns
-- Command word sync and Data Word sync used for scope captures.
csw <= rx_csw_BC;
dw  <= rx_dw_BC;

tx_dval <= tx_dval_enc;
txdval  <= dval_delay(13);

--------------------------------------------------------
-- Generate external triggers for Copilot
--------------------------------------------------------
trigger_module : trigger
    generic map (
        WAIT_VALUE  =>  WAIT_MAX,
        DELAY_VALUE =>  DELAY_MAX,
        DLY_VALUEA  =>  DLY_MAXA,
        HLD_VALUEA  =>  HLD_MAXA,
        DLY_VALUEB  =>  DLY_MAXB,
        HLD_VALUEB  =>  HLD_MAXB,
        DLY_VALUEC  =>  DLY_MAXC,
        HLD_VALUEC  =>  HLD_MAXC,
        NO_HLDA     =>  NO_HLDA,
        NO_DLYA     =>  NO_DLYA,
        NO_HLDB     =>  NO_HLDB,
        NO_DLYB     =>  NO_DLYB,
        NO_HLDC     =>  NO_HLDC,
        NO_DLYC     =>  NO_DLYC
    )
    port map (            
        -- Clock and Reset
        clk     =>  dec_clk,      -- 8Mhz decoder clock.
        rst_n   =>  reset_slow_n, -- async reset
        -- Inputs
        serial_in   =>  rx_data_BC(2),
        csw_in      =>  rxcsw_edge,
        -- Outputs
        triggerA    =>  triggerA,
        triggerB    =>  triggerB,
        triggerC    =>  triggerC,

        debug       =>  open
    );

--------------------------------------------------------
-- debug logic 
--------------------------------------------------------
debug_out <= (rxdw_edge or rxcsw_edge) & subadd_match & filter_match & txdval_enc & rtadd_match & tx_data_dw & tx_data_BC & lastword; --{rx_csw & rx_dw & rx_dval & rx_dword};          
--inputs
bypass <= switch7;
bypass_BC <= switch8 ;
bypass_RT <= switch9 ;
rxena <= switch9 AND '1';
rxenb <= switch10 AND '1';
--outputs
stat0 <= bypass;
stat1 <= '1';
stat2 <= '1';
stat3 <= '1';
--------------------------------------------------
-- This logic is just for testing.
-- Fill up the memory with test data.
--------------------------------------------------
process(clk_out)
    file mif_file : text open read_mode is "c:/Users/tfranklin9/projects/1553/sim/mem.data";
    variable mif_line : line;
    variable temp_bv : std_logic_vector(17 downto 0);
    variable temp_mem : mem_type;
begin
    for i in mem_type'range loop
        readline(mif_file, mif_line);
        read(mif_line, temp_bv);
        temp_mem(i) := (temp_bv);
    end loop;
end process;


process (clk_out)
begin
    if rising_edge(clk_out) then
	     mem_datin_BC <= mem(to_integer(unsigned(mem_addra_BC)));
    end if;
end process;

testrom : process(reset_slow,clk_out)
begin
    if (reset_slow = '0') then
       mem_addra_BC <= (others => '0');
       mem_wea_BC   <= "0";
       first_wr     <= '1';
    elsif rising_edge(clk_out) then
       if (first_wr = '1') then
          mem_addra_BC <= (others => '0');
          mem_wea_BC   <= "1";
          first_wr     <= '0';
       elsif (mem_addra_BC /= "1111111" ) then
          mem_addra_BC <= mem_addra_BC + 1;
          mem_wea_BC   <= "1";
          first_wr     <= '0';
       else
          mem_wea_BC      <= "0";
       end if;
    end if;
end process;

--mem_datin_BC <= mem_data(mem_addra_BC);
--------------------------------------------------------

end behavioral;
-- =============================================================================
