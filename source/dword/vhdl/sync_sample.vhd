-- =============================================================================
-- Project          : 1553
-- File             : sync_sample.v
-- Title            :
-- Dependencies     : 
-- Description      : This module implements 1553 decoding logic. 
--                    Detects transitions on serial input.
--                    Detects sync patterns and data word boundaries.
--                    De-serializes and generates parallel data word.
--                    Checks parity.
-- =============================================================================
-- REVISION HISTORY
-- Version          : 1.0
-- =============================================================================
library ieee ;
use ieee.std_logic_1164.all ;
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.ALL;

entity sync_sample is
port (
            -- Clock and Reset
            dec_clk : in std_logic;  -- 8Mhz decoder clock.
            sys_clk : in std_logic;  -- 48MHz system clock
            rst_n   : in std_logic;  -- async reset

            -- Inputs
            rx_data     : in std_logic;  --serial data input
            rx_data_n   : in std_logic;
            
            -- Outputs
            sample      : out std_logic ;                     -- Indicates data on "rx_data" is valid.
            
            rx_sync     : out std_logic_vector(2 downto 0) ;
            rx_sync_n   : out std_logic_vector(2 downto 0)
) ;
end sync_sample;

architecture Behavioral of sync_sampele is

signal sft_rx_data      : std_logic_vector(2 downto 0);
signal sft_rx_data_n    : std_logic_vector(2 downto 0);
signal cnt              : std_logic_vector(2 downto 0) ;

signal data_edge        : std_logic ;

begin

-- Shift in the serial data through shift registrs.
shftreg : process (rst_n,sys_clk)
begin
	    if ( reset_slow ) then
            sft_rx_data   = (others => '0');
            sft_rx_data_n = (others => '0');
        elsif rising_edge(sys_clk)
            sft_rx_data(2 downto 1)   = sft_rx_data(1 downto 0);
            sft_rx_data(0)            = rx_data;
            sft_rx_data_n(2 downto 1) = sft_rx_data_n(1 downto 0);
            sft_rx_data_n(0)          = rx_data_n;
		end if;
end process;

-- Detect transitions.
data_edge <= sft_rx_data(2) XOR sft_rx_data(1) ;

-- sampling counter
count : process(dec_clk,rst_n,data_edge)
begin
   if (rst_n = '0' or data_edge = '1') then    
      cnt <= (others => '0') ;
   elsif rising_edge(dec_clk) then
      cnt <= cnt + 1 ;
   end if;
end process;

sample <= '1' when cnt = "011" else '0';

rx_sync   <= sft_rx_data;
rx_sync_n <= sft_rx_data_n;

end Behavioral;

-- =============================================================================
