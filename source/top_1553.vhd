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

library ieee ;
use ieee.std_logic_1164.all ;
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.ALL;

entity top_1553 is
port (
            -- Clock and Reset
            clk       : in std_logic;   -- System clock.
            reset_n   : in std_logic;   -- Asynchronous reset.          

            -- Inputs
            rxa_p_BC  : in std_logic;   -- Serial transmit data input. 
            rxa_n_BC  : in std_logic;   -- Serial transmit data input. 
            rxa_p_RT  : in std_logic;   -- Serial transmit data input. 
            rxa_n_RT  : in std_logic;   -- Serial transmit data input.          
            -- Outputs
            --tx_data , 
            txa_p_BC  : out std_logic;   -- Serial transmit data input. 
            txa_n_BC  : out std_logic;   -- Serial transmit data input. 
            txa_p_RT  : out std_logic;   -- Serial transmit data input. 
            txa_n_RT  : out std_logic;   -- Serial transmit data input. 
           
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
            stat3     : out std_logic
            );
end top_1553;
            
architecture behavioral of top_1553 is           

-- Transmitt signals
signal tx_dword   :   std_logic_vector(15 downto 0);
signal tx_csw   :   std_logic;
signal tx_dw   :   std_logic;
signal tx_dval_BC   :   std_logic;
signal tx_dval_RT   :   std_logic;

-- Receive Signals
signal rx_dword_RT :   std_logic_vector(15 downto 0);
signal rx_dword_BC :   std_logic_vector(15 downto 0);
signal rx_dval_BC  :   std_logic;
signal rx_dval_RT  :   std_logic;
signal rx_dw_BC    :   std_logic;
signal rx_dw_RT    :   std_logic;
signal rx_csw_BC   :   std_logic;
signal rx_csw_RT   :   std_logic;
signal rx_data_BC   : std_logic;  
signal rx_data_n_BC : std_logic;
signal rx_data_RT   : std_logic;
signal rx_data_n_RT : std_logic;

-- misc
signal enc_clk       :   std_logic;
signal dec_clk       :   std_logic;
signal serial_data   :   std_logic;
signal debug         :   std_logic_vector(19 downto 0);
signal debug_core_BC :   std_logic_vector(9 downto 0);
signal debug_core_RT :   std_logic_vector(9 downto 0);

signal reset_slow_buf :   std_logic_vector(7 downto 0);
signal reset_slow     :   std_logic;
signal reset_slow_n   :   std_logic;

signal bypass_BC   :   std_logic;
signal bypass_RT   :   std_logic;

-- Memory signals
signal mem_datin_BC :   std_logic_vector(17 downto 0);
signal mem_datin_RT :   std_logic_vector(17 downto 0);
signal mem_addra_BC :   std_logic_vector(6 downto 0);
signal mem_addra_RT :   std_logic_vector(6 downto 0);
signal mem_wea_BC   :   std_logic_vector(0 downto 0);
signal mem_wea_RT   :   std_logic_vector(0 downto 0);
 
-- misc
signal reset : std_logic;
signal LOCKED : std_logic;
signal CLK_VALID : std_logic;
signal clk_out : std_logic;
signal rxdata_BC : std_logic_vector(15 downto 0);
signal rxdata_RT : std_logic_vector(15 downto 0);
signal rxcsw_BC, rxdw_BC, rxdval_BC : std_logic;
signal rxcsw_RT, rxdw_RT, rxdval_RT : std_logic;
signal dec_cnt, enc_cnt : std_logic_vector(2 downto 0);
signal sys_cnt : std_logic_vector(4 downto 0);
signal add : std_logic_vector(8 downto 0);
signal first_wr : std_logic;

type mem_type is array (0 to 511) of std_logic_vector(17 downto 0);
--constant mem : mem_type := init_mem("mem_init_vhd.mif");

signal mem : mem_type := (others => (others => '0'));

component clock_module
port
 (      -- Clock in ports
        CLK_IN1           : in     std_logic;
        -- Clock out ports
        CLK_OUT1          : out    std_logic;
        CLK_OUT2          : out    std_logic;
        -- Status and control signals
        RESET             : in     std_logic;
        LOCKED            : out    std_logic;
        CLK_VALID         : out    std_logic;
        CLK_OUT           : out    std_logic
        );
end component;

component core_1553
generic (   BC      : integer );
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
            rx_dword    : out std_logic_vector(15 downto 0) ; 
            rx_dval     : out std_logic ;                     
            rx_csw      : out std_logic ;                     
            rx_dw       : out std_logic ;                     
            rx_perr     : out std_logic ;                     
            tx_data     : out std_logic ;
            tx_data_n   : out std_logic ;
            tx_dval     : out std_logic ;
            debug       : out std_logic_vector(9 downto 0)
) ;
end component;

begin

-- inputs.
rx_data_BC   <= rxa_p_BC; 
rx_data_n_BC <= rxa_n_BC; 
rx_data_RT   <= rxa_p_RT; 
rx_data_n_RT <= rxa_n_RT; 


-- generate reset 
reset <= NOT reset_n;
reset_slow_n <= NOT reset_slow;

resetgen : process(clk_out) 
begin
    if rising_edge(clk_out) then
       if (reset_slow_buf /= x"00") then
          reset_slow <= '1';
       else 
          reset_slow <= '0';
       end if;
       reset_slow_buf(7 downto 1) <= reset_slow_buf(6 downto 0) ;
       reset_slow_buf(0) <= NOT LOCKED AND NOT CLK_VALID;
   end if;
end process;


u1_core : core_1553
         generic map ( 
            BC => 1 )
         port map (
            -- Clock and Reset
            dec_clk    => dec_clk,
            sys_clk    => clk_out,
            rst_n      => reset_slow_n,

            -- Inputs
            rx_data    => rx_data_BC,
            rx_data_n  => rx_data_n_BC,
            mem_wea    => mem_wea_BC,
            mem_addra  => mem_addra_BC,
            mem_datin  => mem_datin_BC,
            bypass     => bypass_BC,

            -- Outputs
            rx_dword   => rx_dword_BC, 
            rx_dval    => rx_dval_BC,
            rx_csw     => rx_csw_BC,
            rx_dw      => rx_dw_BC,
            rx_perr    => open ,

            tx_dval    => tx_dval_BC,
            tx_data    => txa_p_BC,
            tx_data_n  => txa_n_BC,
            debug      => debug_core_BC
         ) ;

u2_core : core_1553 
         generic map (
            BC => 0 )
         port map (
            -- Clock and Reset
            dec_clk    => dec_clk,
            sys_clk    => clk_out,
            rst_n      => reset_slow_n,

            -- Inputs
            rx_data    => rx_data_RT,
            rx_data_n  => rx_data_n_RT,
            mem_wea    => mem_wea_RT,
            mem_addra  => mem_addra_RT,
            mem_datin  => mem_datin_RT,
            bypass     => bypass_RT,

            -- Outputs
            rx_dword   => rx_dword_RT, 
            rx_dval    => rx_dval_RT,
            rx_csw     => rx_csw_RT,
            rx_dw      => rx_dw_RT,
            rx_perr    => open ,

            tx_dval    => tx_dval_RT,
            tx_data    => txa_p_RT,
            tx_data_n  => txa_n_RT,
            debug      => debug_core_RT
         ) ;

clock_generation : clock_module 
         port map (
            -- Clock in ports
            CLK_IN1   => clk,         -- Input clock 48 MHz
            -- Clock out ports
            CLK_OUT1  => enc_clk,     -- 2MHz encode clock
            CLK_OUT2  => dec_clk,     -- 8MHz decode clock
            -- Status and control signals
            RESET     => reset,       -- IN
            LOCKED    => LOCKED,      -- OUT
            CLK_VALID => CLK_VALID,   -- OUT	
            CLK_OUT   => clk_out    
         );   

-- 1590 outputs
bypass_BC <= switch7 ;
bypass_RT <= switch8 ;
rxena <= switch9 AND '1';
rxenb <= switch10 AND '1';
stat0 <= switch7 ;
stat1 <= switch8 ;
stat2 <= switch9 ;
stat3 <= switch10 ;

-- sync and stretch rx_signals
rxsigs : process(dec_clk,reset_slow,rx_dval_BC,dec_cnt,rxdval_BC)
begin
	if (reset_slow = '1') then
       rxdval_BC <= '0';
       rxcsw_BC  <= '0';
       rxdw_BC   <= '0';
       rxdata_BC <= (others => '0');
    elsif rising_edge(dec_clk) then
	   if (rx_dval_BC = '1') then
          rxdval_BC <= '1'; 
          rxcsw_BC  <= rx_csw_BC;
          rxdw_BC   <= rx_dw_BC;
          rxdata_BC <= rx_dword_BC;
       elsif (dec_cnt = 4 AND rxdval_BC = '1') then
          rxdval_BC <= '0';
          rxcsw_BC  <= '0';
          rxdw_BC   <= '0';
          rxdata_BC <= (others => '0');
       end if;
	end if;
end process;

deccnt : process (reset_slow,dec_clk,rx_dval_BC)
begin
    if (reset_slow = '1') then
        dec_cnt <= (others => '0');
    elsif rising_edge(dec_clk) then
       if (rx_dval_BC = '1') then
          dec_cnt <= (others => '0');
       else
          dec_cnt <= dec_cnt + 1;
       end if;
    end if;
end process;

--------------------------------------------------------
-- Debug logic
-- heartbeat counters for debug
enccnt : process(reset_slow,dec_clk)
begin
    if (reset_slow = '1') then
       enc_cnt <= (others => '0');
    elsif rising_edge(dec_clk) then
       enc_cnt <= enc_cnt + 1;
    end if;
end process;


syscnt : process(reset_slow,dec_clk)
begin
    if (reset_slow = '1') then
        sys_cnt <= (others => '0');
    elsif rising_edge(dec_clk) then
        sys_cnt <= sys_cnt + 1;
    end if;
end process;


addd : process(reset_slow,dec_clk) 
begin
    if (reset_slow = '1') then
        add <= (others => '0');
    elsif rising_edge(dec_clk) then
       if ( rx_dval_BC = '1' ) then
          add <= add + 1;
       end if;
    end if;
end process;

debug_out <= debug_core_BC(9) & debug_core_BC(8) & tx_dval_BC & "000" & bypass_RT & bypass_BC;

--------------------------------------------------
-- This logic is just for testing.
-- Fill up the memory with test data.
--------------------------------------------------
process(clk_out)
    file mif_file : text open read_mode is "c:/Users/tfranklin9/projects/1553/source/mem.data";
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