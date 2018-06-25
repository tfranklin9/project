-- =============================================================================
-- Project          : 1553
-- File             : trigger.vhd
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
use ieee.math_real.all;

entity trigger is
generic (
            WAIT_VALUE  : positive := 32;
            DELAY_VALUE : positive := 1088;
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
            clk     : in std_logic;  -- 8Mhz decoder clock.
            rst_n   : in std_logic;  -- async reset

            -- Inputs
            serial_in   : in std_logic;
            csw_in      : in std_logic;
   
            -- Outputs
            triggerA    : out std_logic ;                     
            triggerB    : out std_logic ;                     
            triggerC    : out std_logic ;                     

            debug       : out std_logic_vector(9 downto 0)
) ;
end trigger ;

architecture Behavioral of trigger is

constant NUM_WAIT_BITS : positive := integer(ceil(log2(real(WAIT_VALUE * 8))));
constant NUM_DLY_BITS  : positive := integer(ceil(log2(real(DELAY_VALUE * 8))));

constant WAIT_DLY      : positive := (WAIT_VALUE * 8) - 1;
constant DLY           : positive := (DELAY_VALUE * 8) - 1;
             
signal wait_cnt  : std_logic_vector(NUM_WAIT_BITS -1 downto 0) := (others => '1');
signal wait_tc   : std_logic;
signal delay_cnt : std_logic_vector(NUM_DLY_BITS - 1 downto 0) := (others => '1');
signal delay_tc  : std_logic;

signal start     : std_logic;
signal finish    : std_logic;
signal doneA     : std_logic;
signal doneB     : std_logic;
signal doneC     : std_logic;
signal trig_done : std_logic;

TYPE state_type IS (INIT,IDLE,CSW,DELAY,TRIG);
signal state : state_type ; 

component trigger_fsm
generic (
        HLD_VALUE : positive ;
        DLY_VALUE : positive ;
        NO_HLD    : std_logic;
        NO_DLY    : std_logic);
port (      
        clk         : in std_logic;
        rst_n       : in std_logic;

        start       : in std_logic;  
        finish      : in std_logic;  
    
        done        : out std_logic;
        trigger     : out std_logic                      
     );
end component;

begin

-- wait timer (7 bit counter gives max 16us wait)
waitcnt : process(rst_n,clk,state)
begin
    if (rst_n = '0') then
       wait_cnt <= (others => '1');
   elsif rising_edge(clk) then
       if (state = INIT) then 
       -- load counter with wait value
          wait_cnt <= std_logic_vector(to_unsigned(WAIT_DLY,wait_cnt'length)); 
       elsif (serial_in = '1') then
       -- if there is activity on the bus reload counter
          wait_cnt <= std_logic_vector(to_unsigned(WAIT_DLY,wait_cnt'length));
       elsif (state = IDLE) then
       -- count down while there is no 1553 
          wait_cnt <= wait_cnt - 1;
       end if;
    end if;
end process;

-- Wait counter counts down and terminates on 0
wait_tc <= '1' when ( to_integer(unsigned(wait_cnt)) = 0)  else '0';

-- Delay counter for transaction
dlycnt : process(rst_n,clk,state)
begin
    if (rst_n = '0') then
       delay_cnt <= (others => '1');
    elsif rising_edge(clk) then
       if (state = INIT) then 
          delay_cnt <= std_logic_vector(to_unsigned(DLY,delay_cnt'length)); 
       elsif (state = DELAY) then
          delay_cnt <= delay_cnt - 1;
       end if;
    end if;
end process;

--delay_tc <= '1' when (delay_cnt = "00" & x"000") else '0';
delay_tc <= '1' when ( to_integer(unsigned(delay_cnt)) = 0) else '0';

-- FSM to generate triggers
TRIGGERFSM : process(clk,rst_n,state,wait_tc,csw_in,delay_tc,trig_done)
begin 
   if (rst_n = '0') then
      state  <= INIT;
      start  <= '0';
      finish <= '0';
   elsif rising_edge(clk) then
      case (state) is
         WHEN INIT => 
            start <= '0';
            state <= IDLE;
            finish <= '0';

         WHEN IDLE => 
            start  <= '0';
            finish <= '0';

            if (wait_tc = '1') then
               state <= CSW;
            else
               state <= IDLE;
            end if;

         WHEN CSW =>
            if (csw_in = '1') then
               state <= DELAY;
            else
               state <= CSW;
            end if;

         WHEN DELAY => 
            if (delay_tc = '1') then
               state <= TRIG;
            else
               state <= DELAY;
            end if;

         WHEN TRIG => 
            start <= '1';

            if (trig_done = '1') then -- wait for the three triggers hold tc's
               state  <= IDLE ;
               finish <= '1';
            else                      -- back to idle to wait for next gap                        
               state <= TRIG;
               finish <= '0';
            end if;

         WHEN others => 
            state <= IDLE;
            
      end case;
    end if;
  end process;

Atrigger : trigger_fsm 
         generic map (
            HLD_VALUE => HLD_VALUEA,
            DLY_VALUE => DLY_VALUEA,
            NO_HLD    => NO_HLDA,
            NO_DLY    => NO_DLYA
         )
         port map (
            -- Clock and Reset
            clk    => clk,
            rst_n  => rst_n,

            -- Inputs
            start     => start,
            finish    => finish,

            -- Outputs
            done      => doneA,
            trigger   => triggerA 
         );

Btrigger : trigger_fsm 
         generic map (
            HLD_VALUE => HLD_VALUEB,
            DLY_VALUE => DLY_VALUEB,
            NO_HLD    => NO_HLDB,
            NO_DLY    => NO_DLYB
         )
         port map (
            -- Clock and Reset
            clk    => clk,
            rst_n  => rst_n,

            -- Inputs
            start     => start,
            finish    => finish,

            -- Outputs
            done      => doneB,
            trigger   => triggerB 
         );

Ctrigger : trigger_fsm 
         generic map (
            HLD_VALUE => HLD_VALUEC,
            DLY_VALUE => DLY_VALUEC,
            NO_HLD    => NO_HLDC,
            NO_DLY    => NO_DLYC
         )
         port map (
            -- Clock and Reset
            clk    => clk,
            rst_n  => rst_n,

            -- Inputs
            start     => start,
            finish    => finish,

            -- Outputs
            done      => doneC,
            trigger   => triggerC 
         );

-- all triggers have completed
trig_done <= doneA and doneB and doneC; 

debug <= "0000000000";

end Behavioral;

-- =============================================================================
