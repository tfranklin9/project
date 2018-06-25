-- =============================================================================
-- Project          : 1553
-- File             : trigger_fsm.vhd
-- Title            :
-- Dependencies     : 
-- Description      : This module implements the trigger state machine.
-- =============================================================================
-- REVISION HISTORY
-- Version          : 1.0
-- =============================================================================
library ieee ;
use ieee.std_logic_1164.all ;
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.ALL;
use ieee.math_real.all;

entity trigger_fsm is
generic ( 
            HLD_VALUE : positive ;
            DLY_VALUE : positive ;
            NO_HLD    : std_logic := '0';
            NO_DLY    : std_logic := '0'
        );
port (
            -- Clock and Reset
            clk     : in std_logic;  -- 8Mhz decoder clock.
            rst_n   : in std_logic;  -- async reset

            -- Inputs
            start       : in std_logic;  
            finish      : in std_logic;  
            
            -- Outputs
            done        : out std_logic;
            trigger     : out std_logic                      
) ;
end trigger_fsm ;

architecture Behavioral of trigger_fsm is

constant NUM_HLD_BITS : positive := positive(ceil(log2(real(HLD_VALUE * 8))));
constant NUM_DLY_BITS : positive := positive(ceil(log2(real(DLY_VALUE * 8))));

constant HLDVALUE     : positive := (HLD_VALUE * 8) - 1;
constant DLYVALUE     : positive := (DLY_VALUE * 8) - 1;

signal hld_cnt : std_logic_vector(NUM_HLD_BITS - 1 downto 0);
signal dly_cnt : std_logic_vector(NUM_DLY_BITS - 1 downto 0);

signal hld_tc : std_logic;
signal dly_tc : std_logic;

signal trig   : std_logic;

TYPE state_type IS (IDLE,DLY,HLD,FIN);
signal state : state_type ; 

begin

-- Delay counter for triggers
dlycnt : process(rst_n,clk,state)
begin
    if (rst_n = '0') then
       dly_cnt <= (others => '1');
    elsif rising_edge(clk) then
       if (state = IDLE) then 
          dly_cnt <= std_logic_vector(to_unsigned(DLYVALUE,dly_cnt'length)); 
       elsif (state = DLY) then
          dly_cnt <= dly_cnt - 1;
       end if;
    end if;
end process;

dly_tc <= '1' when (to_integer(unsigned(dly_cnt)) = 0) else '0';
   
-- Hold counter for triggers
hldcnt : process(rst_n,clk,state)
begin
    if (rst_n = '0') then
       hld_cnt <= (others => '1');
    elsif rising_edge(clk) then
       if (state = IDLE ) then 
          hld_cnt <= std_logic_vector(to_unsigned(HLDVALUE,hld_cnt'length)); 
       elsif (state = HLD) then
          hld_cnt <= hld_cnt - 1;
       end if;
    end if;
end process;

hld_tc <= '1' when (to_integer(unsigned(hld_cnt)) = 0) else '0';

-- FSM to generate triggers
FSM : process(clk,rst_n,start,dly_tc,hld_tc,finish)
begin 
   if (rst_n = '0') then
      state <= IDLE;
      done  <= '0';
      trig  <= '0';
   elsif rising_edge(clk) then
      case (state) is
         -- wait for main SM wait and delay
         WHEN IDLE => 
            done <= '0';
            trig <= '0';

            if (start = '0') then
               state <= IDLE;
            else
               if (NO_HLD = '1') then
               -- No trigger. Goto Fin and wait for other triggers to be done
                   state <= FIN;
               else 
               -- Go to Delay state
                   state <= DLY;
               end if;
            end if;

         WHEN DLY =>
            trig <= '0';

            if (NO_DLY = '1') then
               state <= HLD;
            else 
               if (dly_tc = '1') then 
                   state <= HLD;
               else 
                   state <= DLY;
               end if;
            end if;

         WHEN HLD => 
            if (NO_HLD = '1') then -- No trigger. goto FIN.
               state <= FIN;
            else 
               trig <= '1';
               if (hld_tc = '1') then 
                   state <= FIN;
               else 
                   state <= HLD;
               end if;
            end if;

         WHEN FIN => 
            trig <= '0';
            done <= '1';

            if (finish = '1') then -- all triggers done.
               state <= IDLE;
            else 
               state <= FIN;
            end if;

         WHEN others => 
            state <= IDLE;
            done <= '0';
            trig <= '0';
            
      end case;
    end if;
end process;

-- Drive trigger to ground when trigger is enabled. Float when it's disabled
trigger <= '0' when (trig = '1') else 'Z';
--trigger <= trig ;

end Behavioral;

-- =============================================================================
