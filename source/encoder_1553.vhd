-- =============================================================================
-- Project          : core_1553
-- File             : encoder_1553.v
-- Title            :
-- Dependencies     : 
-- Description      : This module implements 1553 encoding logic. 
-- =============================================================================
-- REVISION HISTORY
-- Version          : 1.0
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- Generated from Verilog module encoder_1553 (encoder_1553.v:1)
entity encoder_1553 is
  port (
    -- clock and reset
    enc_clk : in std_logic; -- 2MHz encoder clock
    rst_n   : in std_logic; -- Asynchronous reset.

    -- Inputs
    tx_csw  : in std_logic; -- "tx_dword" has command or status word.
    tx_dw   : in std_logic; -- "tx_dword" has data word.
                           
    -- Outputs                                                      
    tx_busy     : out std_logic; -- Encoder is not ready to accept next word;
    tx_data     : out std_logic; -- Serial transmit data output.
    tx_data_n   : out std_logic; -- Serial transmit data output.  
    tx_dval_csw : out std_logic; -- Indicates data on "tx_data" is valid
    tx_dval     : out std_logic -- Indicates data on "tx_data" is valid.
  );
end entity; 

architecture behavioral of encoder_1553 is

  signal dwcnt           : std_logic_vector(5 downto 0);
  signal dword 	         : std_logic; 
  signal tx_dword        : std_logic_vector(15 downto 0);

  signal busy_cnt        : std_logic_vector(5 downto 0);
  signal busy_cnt_dummy  : std_logic_vector(5 downto 0);
  signal cnt_en           : std_logic;
  signal cnt_en_dummy     : std_logic;
  signal cnt_en_reg       : std_logic;
  signal cnt_en_reg_dummy : std_logic;
  signal endofpayload     : std_logic; 
  signal endofword        : std_logic;
  signal firstword 	  : std_logic;

  signal data_reg         : std_logic_vector(16 downto 0);
  signal enc_data         : std_logic_vector(40 downto 0);
  signal enc_data2        : std_logic_vector(40 downto 0); 

  signal is_csw           : std_logic;
  signal is_csw_reg       : std_logic;
  signal parity 	  : std_logic;
  signal sync_bits        : std_logic_vector(5 downto 0);
  signal sync_bits_n      : std_logic_vector(5 downto 0);

  -- Function xnor's vector
  function Reduce_XNOR(X : std_logic_vector) return std_logic is
    variable R : std_logic := '0';
  begin
    for I in X'Range loop
      R := X(I) xnor R;
    end loop;
    return R;
  end function;

begin

-- signal assignments
  tx_dword     <= X"0505";
  firstword    <= '1' when (tx_dw = '1' and dwcnt = 0) else '0';
  endofpayload <= '1' when (dwcnt = 32 and cnt_en = '0' and cnt_en_reg = '1') else '0';
  endofword    <= '1' when (cnt_en = '0' and cnt_en_reg = '1') else '0';
  dword        <= '1' when ((firstword = '1' or endofword = '1') and endofpayload = '0') else '0';

  parity <= not Reduce_XNOR(std_logic_vector(tx_dword));

  enc_data <= sync_bits & data_reg(0) & not(data_reg(0)) &
              data_reg(1)  & not(data_reg(1)) &
              data_reg(2)  & not(data_reg(2)) &
              data_reg(3)  & not(data_reg(3)) &
              data_reg(4)  & not(data_reg(4)) &
              data_reg(5)  & not(data_reg(5)) &
              data_reg(6)  & not(data_reg(6)) &
              data_reg(7)  & not(data_reg(7)) &
              data_reg(8)  & not(data_reg(8)) &
              data_reg(9)  & not(data_reg(9)) &
              data_reg(10) & not(data_reg(10)) &
              data_reg(11) & not(data_reg(11)) &
              data_reg(12) & not(data_reg(12)) &
              data_reg(13) & not(data_reg(13)) &
              data_reg(14) & not(data_reg(14)) &
              data_reg(15) & not(data_reg(15)) &
              data_reg(16) & not(data_reg(16)) & '0';

  enc_data2 <= sync_bits & not(data_reg(0)) & data_reg(0) &
              not(data_reg(1))  & data_reg(1) &
              not(data_reg(2))  & data_reg(2) &
              not(data_reg(3))  & data_reg(3) &
              not(data_reg(4))  & data_reg(4) &
              not(data_reg(5))  & data_reg(5) &
              not(data_reg(6))  & data_reg(6) &
              not(data_reg(7))  & data_reg(7) &
              not(data_reg(8))  & data_reg(8) &
              not(data_reg(9))  & data_reg(9) &
              not(data_reg(10)) & data_reg(10) &
              not(data_reg(11)) & data_reg(11) &
              not(data_reg(12)) & data_reg(12) &
              not(data_reg(13)) & data_reg(13) &
              not(data_reg(14)) & data_reg(14) &
              not(data_reg(15)) & data_reg(15) &
              not(data_reg(16)) & data_reg(16) & '1';
 
  -- Count the number of datawords
  wordcnt: process (enc_clk, rst_n)
  begin
    if (not rst_n) = '1' then
      dwcnt <= (others => '0');
    elsif rising_edge(enc_clk) then
      if (endofpayload = '1') or (tx_csw = '1') then
        dwcnt <= (others => '0');
      else
        if ((tx_dw = '1') and (dwcnt = "000000")) or (endofword = '1') then
          dwcnt <= dwcnt + 1;
        end if;
      end if;
    end if;
  end process;
  
  -- Count the number of clks required to encode and serialize input data 
  cnten: process (enc_clk, rst_n)
  begin
    if (not rst_n) = '1' then
      cnt_en <= '0';
    elsif rising_edge(enc_clk) then
      if (dword = '1') then
        cnt_en <= '1';
      elsif (busy_cnt = 38) then
        cnt_en <= '0';
      else
        cnt_en <= cnt_en;
      end if;
    end if;
  end process;
  
  cntendummy: process (enc_clk, rst_n, tx_csw)
  begin
    if (not rst_n) = '1' then
      cnt_en_dummy <= '0';
    elsif rising_edge(enc_clk) then
      if (tx_csw = '1') then
        cnt_en_dummy <= '1';
      elsif (busy_cnt_dummy = 38) then
        cnt_en_dummy <= '0';
      else
         cnt_en_dummy <= cnt_en_dummy;
      end if;
    end if;
  end process;
  
  iscsw: process (enc_clk, rst_n)
  begin
    if (not rst_n) = '1' then
      is_csw <= '0';
    elsif rising_edge(enc_clk) then
      if (tx_csw = '1') then
        is_csw <= '1';
      elsif (busy_cnt_dummy = 38) then
        is_csw <= '0';
      else
        is_csw <= is_csw;
      end if;
    end if;
  end process;
  
  cntenreg: process (enc_clk, rst_n)
  begin
    if (not rst_n) = '1' then
      cnt_en_reg <= '0';
    elsif rising_edge(enc_clk) then
      cnt_en_reg <= cnt_en;
    end if;
  end process;
  
  cntenregdummy: process (enc_clk, rst_n)
  begin
    if (not rst_n) = '1' then
      cnt_en_reg_dummy <= '0';
      is_csw_reg <= '0';
    elsif rising_edge(enc_clk) then
      cnt_en_reg_dummy <= cnt_en_dummy;
      is_csw_reg <= is_csw;
    end if;
  end process;
  
  busycnt: process (enc_clk, rst_n, cnt_en)
  begin
    if (not rst_n) = '1' then
      busy_cnt <= (others => '0');
    elsif rising_edge(enc_clk) then
      if (cnt_en = '1') then
        busy_cnt <= busy_cnt + 1;
      else
        busy_cnt <= (others => '0');
      end if;
    end if;
  end process;
  
  busycntdmy: process (enc_clk, rst_n, cnt_en_dummy)
  begin
    if (not rst_n) = '1' then
      busy_cnt_dummy <= (others => '0');
    elsif rising_edge(enc_clk) then
      if (cnt_en_dummy = '1') then
        busy_cnt_dummy <= busy_cnt_dummy + 1;
      else
        busy_cnt_dummy <= (others => '0');
      end if;
    end if;
  end process;
  
  -- Register input data word and parity
  datareg: process (enc_clk, rst_n)
  begin
    if (not rst_n) = '1' then
      data_reg <= (others => '1');
    elsif rising_edge(enc_clk) then
      if (dword = '1') and ((not cnt_en) = '1') then
        data_reg <= tx_dword & parity;
      elsif (not cnt_en) = '1' then
        data_reg <= (others => '0');
      else
        data_reg <= data_reg;
      end if;
    end if;
  end process;
  
  -- Determine the sync pattern
  syncbit: process (enc_clk, rst_n)
  begin
    if (not rst_n) = '1' then
      sync_bits <= (others => '0');
      sync_bits_n <= (others => '0');
    elsif rising_edge(enc_clk) then
      if (tx_csw = '1') then
        sync_bits <= "111000";
        sync_bits_n <= "000111";
      elsif (dword = '1') then
        sync_bits <= "000111";
        sync_bits_n <= "111000";
      else
        sync_bits <= sync_bits;
        sync_bits_n <= sync_bits_n;
      end if;
    end if;
  end process;
  
  -- Serialize the encoded data
  data_serialize: process (enc_clk, rst_n)
  begin
    if (not rst_n) = '1' then
      tx_dval   <= '0';
      tx_data   <= '0';
      tx_data_n <= '0';
    elsif rising_edge(enc_clk) then
      if (cnt_en = '1') or (cnt_en_reg = '1') then
        tx_dval   <= '1';
	tx_data   <= enc_data(To_Integer(unsigned(busy_cnt)));
        tx_data_n <= enc_data2(To_Integer(unsigned(busy_cnt)));
      elsif ((dwcnt >= 1) and ((not cnt_en) = '1' and ((not cnt_en_reg) = '1'))) then
        tx_data_n <= '1';
      else
        tx_dval   <= '0';
        tx_data   <= '0';
        tx_data_n <= '0';
      end if;
    end if;
  end process;
  
  -- Generate dvalid for csw
  dval_csw: process (enc_clk, rst_n)
  begin
    if (not rst_n) = '1' then
      tx_dval_csw <= '0';
    elsif rising_edge(enc_clk) then
      if (cnt_en_dummy = '1') or (cnt_en_reg_dummy = '1') then
        tx_dval_csw <= '1';
      else
        tx_dval_csw <= '0';
      end if;
    end if;
  end process;

end architecture;

