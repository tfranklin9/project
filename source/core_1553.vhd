-- =============================================================================
-- Project          : 1553
-- File             : core_1553.v
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
--use ieee.std_logic_arith.all ;
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.ALL;

entity core_1553 is
generic (
            BC      : std_logic
);
port (
            -- Clock and Reset
            dec_clk : in std_logic;  -- 8Mhz decoder clock.
            sys_clk : in std_logic;
            rst_n   : in std_logic;  -- async reset

            -- Inputs
            rx_data     : in std_logic;  --serial data input
            rx_data_n   : in std_logic;
            mem_wea     : in std_logic_vector(0 downto 0);
            mem_addra   : in std_logic_vector(6 downto 0);
            mem_datin   : in std_logic_vector(17 downto 0);
            bypass      : in std_logic;            
            
            -- Outputs
            rx_dword    : out std_logic_vector(15 downto 0) ; -- Output data word receive.
            rx_dval     : out std_logic ;                     -- Indicates data on "rx_data" is valid.
            rx_csw      : out std_logic ;                     -- "rx_dword" has command or status word.
            rx_dw       : out std_logic ;                     -- "rx_dword" has data word.
            rx_perr     : out std_logic ;                     -- Indicates parity error in "rx_dword".
            
            tx_data     : out std_logic ;
            tx_data_n   : out std_logic ;
            tx_dval     : out std_logic ;
            debug       : out std_logic_vector(9 downto 0)
) ;
end core_1553 ;

architecture Behavioral of core_1553 is


--signal rx_dword : std_logic_vector(15 downto 0);
--signal rx_dval  : std_logic ;
--signal rx_csw   : std_logic ;
--signal rx_dw    : std_logic ;
--signal rx_perr  : std_logic ;

signal data_sftreg      : std_logic_vector(0 to 5);
signal data_sftreg_n    : std_logic_vector(0 to 5);
signal sync_sftreg      : std_logic_vector(0 to 23) ;
signal sync_sftreg_n    : std_logic_vector(0 to 23) ;
signal sync_sftsignal   : std_logic_vector(23 downto 0) ;
signal data_sftsignal   : std_logic_vector(4 downto 0) ;
signal sync_sftsignal_n : std_logic_vector(23 downto 0) ;
signal data_sftsignal_n : std_logic_vector(4 downto 0) ;
signal data_sftreg_out  : std_logic_vector(0 to 31);
signal data_sftreg_out_n : std_logic_vector(0 to 31);
signal cnt_enb          : std_logic ;
signal cnt              : std_logic_vector(7 downto 0) ;
signal bit_cnt          : std_logic_vector(4 downto 0) ;
signal dword_int        : std_logic_vector(16 downto 0) ;
signal sync_csw_signal  : std_logic ;
signal sync_dw_signal   : std_logic ;

signal data_edge        : std_logic ;
signal sync_csw         : std_logic ;
signal sync_csw_reg     : std_logic ;
signal sync_dw_reg      : std_logic ;
signal sync_dw          : std_logic ;
signal csw_sync         : std_logic ;
signal dw_sync          : std_logic ;
signal data_sample      : std_logic ;
signal parity           : std_logic ;
signal parity_bit       : std_logic ;

-- Bit fields 
signal is_cw         : std_logic;
signal is_sw         : std_logic;
signal is_dw         : std_logic;
signal dword1        : std_logic_vector(4 downto 0);
signal dword2        : std_logic;
signal dword3        : std_logic_vector(4 downto 0);
signal dword4        : std_logic_vector(4 downto 0);
signal rt_address    : std_logic_vector(4 downto 0);
signal sub_address   : std_logic_vector(4 downto 0);
signal dwcnt_mcode   : std_logic_vector(4 downto 0);
signal tr            : std_logic;
signal rsvd          : std_logic_vector(2 downto 0);
signal message_error : std_logic;
signal inst          : std_logic;
signal srv_rqst      : std_logic;
signal bc_rcvd       : std_logic;
signal busy          : std_logic;
signal sub_flag      : std_logic;
signal dbctrl_acc    : std_logic;
signal term_flag     : std_logic;

-- serial manchester out
signal data_sftsignal_out   : std_logic_vector(31 downto 0);
signal data_sftsignal_out_n : std_logic_vector(31 downto 0);
signal cw                   : std_logic;
signal dw                   : std_logic;
signal sw                   : std_logic;
signal passthru             : std_logic_vector(17 downto 0);

signal start_shift          : std_logic;
signal shift_data           : std_logic;
--signal bitcnt               : std_logic_vector(4 downto 0);
signal bitcnt               : integer range 0 to 17;
signal enc_bit              : std_logic;
signal enc_bit_n            : std_logic;
signal change               : std_logic;
signal samplecnt            : std_logic_vector(2 downto 0);
signal txdval               : std_logic;
signal txdata               : std_logic;
signal txdata_n             : std_logic;
signal select_a             : std_logic_vector(3 downto 0);
signal enb                  : std_logic;
signal data_signal          : std_logic_vector(16 downto 0);
signal mem_addrb            : std_logic_vector(6 downto 0);         
signal data_reg             : std_logic_vector(17 downto 0);         
signal nodata               : std_logic;

CONSTANT SIZE   : integer := 4;
CONSTANT IDLE   : std_logic_vector(3 downto 0) := "0001";
CONSTANT READa  : std_logic_vector(3 downto 0) := "0010";
CONSTANT SHIFT1 : std_logic_vector(3 downto 0) := "0100";
CONSTANT SHIFT2 : std_logic_vector(3 downto 0) := "1000";
signal   state  : std_logic_vector(SIZE-1 downto 0); -- FSM vector

COMPONENT blk_mem_1553
  PORT (
    clka  : IN STD_LOGIC;
    wea   : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
    dina  : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
    clkb  : IN STD_LOGIC;
    enb   : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(6 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(17 DOWNTO 0)
  );
END COMPONENT;

begin

-- Shift in the serial data through shift registrs.
sftreg : process (dec_clk,rst_n)
begin 
   if ( rst_n = '0' ) then
      data_sftreg <= (others => '0');
      sync_sftreg <= (others => '0');
   elsif rising_edge(dec_clk) then 
      data_sftreg(0 to 4) <= data_sftreg(1 to 5) ;
      data_sftreg(5) <= rx_data;
      sync_sftreg(0 to 22) <= sync_sftreg(1 to 23) ;
      sync_sftreg(23) <= data_sftreg(0) ;
   end if;
end process;

-- Shift the negative end.
sftreg_n : process(dec_clk,rst_n)
begin
   if ( rst_n = '0' ) then
      data_sftreg_n <= (others => '0') ;
      sync_sftreg_n <= (others => '0') ;
   elsif rising_edge(dec_clk) then
      data_sftreg_n(0 to 4) <= data_sftreg_n(1 to 5) ;
      data_sftreg_n(5) <= rx_data_n;
      sync_sftreg_n(0 to 22) <= sync_sftreg_n(1 to 23) ;
      sync_sftreg_n(23) <= data_sftreg_n(0) ;
   end if;
end process;

-- Detect transitions.
data_edge <= data_sftreg(3) XOR data_sftreg(4) ;

-- Detect sync pattern for command and status word
--sync_csw <= (sync_sftreg = x"FFF000") AND data_edge ;
csw_sync <= '1' when sync_sftreg = x"FFF000" else '0';
sync_csw <= csw_sync AND data_edge ;

-- Detect sync pattern for data word
--sync_dw  <= (sync_sftreg = x"000FFF") AND data_edge ; 
dw_sync  <= '1' when sync_sftreg = x"000FFF" else '0';
sync_dw  <= dw_sync AND data_edge ; 

-- Count number of clocks to get complete word after 
-- detecting the sync pattern
count_enable : process(dec_clk,rst_n,sync_csw,sync_dw,cnt)
begin
   if (rst_n = '0' ) then    
      cnt_enb <= '0' ;
   elsif rising_edge(dec_clk) then
      if (sync_csw = '1' OR sync_dw = '1') then
         cnt_enb <= '1' ;
      elsif (cnt = 131) then
         cnt_enb <= '0' ;
      end if;
   end if;
end process;

count : process(dec_clk,rst_n,cnt_enb)
begin
   if (rst_n = '0') then    
      cnt <= (others => '1') ;
   elsif rising_edge(dec_clk) then
      if (cnt_enb = '1') then
         cnt <= cnt + 1 ;
      elsif (cnt_enb = '0') then
         cnt <= (others => '1') ;
      end if;
   end if;
end process;

-- Generate data sample points.
--assign data_sample =  (~cnt[2] & ~cnt[1] & ~cnt[0]) ;
data_sample <= not(cnt(2)) AND not(cnt(1)) AND not(cnt(0));

-- register data at every sample point through shift register.
data_word : process(dec_clk,rst_n,data_sample,cnt_enb)
begin
   if (rst_n = '0' ) then   
      dword_int <= (others => '0');
   elsif rising_edge(dec_clk) then
      if (data_sample = '1' AND cnt_enb = '1') then
         dword_int <= dword_int(1 to 16) & not data_sftreg(2);
      elsif (cnt_enb = '0') then
         dword_int <= (others => '0') ;
      end if;
   end if;
end process;

-- Register command and status sync patter type till the end 
-- of data word.
csw_type : process(dec_clk,rst_n,sync_csw,cnt)
begin
   if (rst_n = '0' ) then   
      sync_csw_reg <= '0' ;
   elsif rising_edge(dec_clk) then
      if (sync_csw = '1') then
         sync_csw_reg <= '1' ;
      elsif (cnt = 132) then
         sync_csw_reg <= '0' ;
      end if;
   end if;
end process;

-- Register data sync patter type till the end of data word.
dw_type : process(dec_clk,rst_n,cnt,sync_dw)
begin
   if (rst_n = '0') then    
      sync_dw_reg <= '0' ;
   elsif rising_edge(dec_clk) then
      if (sync_dw = '1') then
         sync_dw_reg <= '1' ;
      elsif (cnt = 132) then
         sync_dw_reg <= '0' ;
      end if;
   end if;
end process;

-- Register the parallel data word and control outputs.
parallel_rx_out : process(dec_clk,rst_n,cnt,dword_int)
variable parity_rx : std_logic;
begin
   if (rst_n = '0' ) then
      rx_dword <= (others => '0') ;
      rx_dval  <= '0' ;
      rx_perr  <= '0' ;
      rx_csw   <= '0' ;
      rx_dw    <= '0' ;
   elsif rising_edge(dec_clk) then
      if (cnt = 131) then
         rx_dword <= dword_int(0 to 15) ;
         rx_dval  <= '1' ;
         rx_csw   <= sync_csw_reg ;
         rx_dw    <= sync_dw_reg ;
         for i in dword_int'range loop
            parity_rx := parity_rx xor dword_int(i);
         end loop;
         rx_perr <= parity_rx;
      else
         rx_dword <= (others => '0') ;
         rx_dval  <= '0' ;
         rx_perr  <= '0' ;
         rx_csw   <= '0' ;
         rx_dw    <= '0' ;
      end if;
   end if;
end process;
   
-- Bit counter for 1553 Word fields
bit_counter : process(dec_clk,rst_n,cnt_enb,data_sample)
begin
   if (rst_n = '0') then   
      bit_cnt <= (others => '0');
   elsif rising_edge(dec_clk) then
      if (cnt_enb = '1' AND data_sample = '1') then
         bit_cnt <= bit_cnt + 1 ;
      elsif (cnt_enb = '0') then
         bit_cnt <= (others => '0') ;
      end if;
   end if;
end process;

--------------------------------------------------
-- register data at sample points for 1553 fields.
--------------------------------------------------
-- Command word fields
--------------------------------------------------
-- Create RAM address for lookup
mem_addrb <= '0' & rt_address;

-- RT Address
rtadd : process(dec_clk,rst_n,is_cw,is_sw,data_sample,bit_cnt)
begin
   if (rst_n = '0') then    
      rt_address <= (others => '0') ;
   elsif rising_edge(dec_clk) then
      if ( (is_cw = '1' OR is_sw = '1') AND data_sample = '1' AND bit_cnt < 5) then
         rt_address <= rt_address(1 to 4) & NOT data_sftreg(2) ;
      end if;   
   end if;
end process;
   
-- Generate Transmit/Receive
txrx : process(dec_clk,rst_n,is_cw,data_sample,bit_cnt)
begin
   if (rst_n = '0') then   
      tr <= '0' ;
   elsif ( is_cw = '1' AND data_sample = '1' AND bit_cnt = 5) then
      tr <=  NOT data_sftreg(2) ;
   end if;
end process;

-- Sub Address
sub : process(dec_clk,rst_n,is_cw,data_sample,bit_cnt)
begin
   if (rst_n = '0' ) then
      sub_address <= (others => '0') ;
   elsif ( is_cw = '1' AND data_sample = '1' AND ( bit_cnt > 5 AND bit_cnt <= 10 ) ) then
      sub_address <= sub_address(1 to 4) & NOT data_sftreg(2) ;
   end if;
end process;

-- Data Word Count/Mode Code 
dwcnt : process(dec_clk,rst_n,is_cw,data_sample,bit_cnt)
begin
   if (rst_n = '0') then
      dwcnt_mcode <= (others => '0') ;
   elsif ( is_cw = '1' AND data_sample = '1' AND ( bit_cnt > 10 AND bit_cnt <= 15 ) ) then
      dwcnt_mcode <= dwcnt_mcode(1 to 4) & NOT data_sftreg(2) ;
   end if;
end process;

-- Parity bit in
paritybitin : process(dec_clk,rst_n,data_sample,bit_cnt)
begin
   if (rst_n = '0' ) then   
      parity_bit <= '0' ;
   elsif ( data_sample = '1' AND bit_cnt = 16 ) then
      parity_bit <= NOT data_sftreg(2) ;
   end if;
end process;

--------------------------------------------------
-- Status word fields
--------------------------------------------------
-- Generate Status Word Fields 
stat_fields : process(dec_clk,rst_n,is_sw,data_sample,bit_cnt)
begin
   if (rst_n = '0' ) then
      message_error <= '0';
      inst <= '0' ;
      srv_rqst <= '0' ;
      rsvd <= (others => '0') ;
      bc_rcvd <= '0';
      busy <= '0';
      sub_flag <= '0';
      dbctrl_acc <= '0';
      term_flag <= '0';
   elsif ( is_sw = '1' AND data_sample = '1' AND bit_cnt = 5) then
      message_error <= NOT data_sftreg(2) ;
   elsif ( is_sw = '1' AND data_sample = '1' AND bit_cnt = 6) then
      inst <= NOT data_sftreg(2);
   elsif ( is_sw = '1' AND data_sample = '1' AND bit_cnt = 7) then
      srv_rqst <= NOT data_sftreg(2);
   elsif ( is_sw = '1' AND data_sample = '1' AND ( bit_cnt > 7 AND bit_cnt < 11 ) ) then
      rsvd <= rsvd(1 to 2) & NOT data_sftreg(2) ;
   elsif ( is_sw = '1' AND data_sample = '1' AND bit_cnt = 11) then
      bc_rcvd <= NOT data_sftreg(2) ;
   elsif ( is_sw = '1' AND data_sample = '1' AND bit_cnt = 12) then
      busy <= NOT data_sftreg(2) ;
   elsif ( is_sw = '1' AND data_sample = '1' AND bit_cnt = 13) then
      sub_flag <= NOT data_sftreg(2) ;
   elsif ( is_sw = '1' AND data_sample = '1' AND bit_cnt = 14) then
      dbctrl_acc <= NOT data_sftreg(2) ;
   elsif ( is_sw = '1' AND data_sample = '1' AND bit_cnt = 15) then
      term_flag <= NOT data_sftreg(2) ;
   elsif ( cnt_enb = '0' OR is_sw = '0' ) then
      message_error <= '0';
      inst <= '0' ;
      srv_rqst <= '0' ;
      rsvd <= (others => '0') ;
      bc_rcvd <= '0';
      busy <= '0';
      sub_flag <= '0';
      dbctrl_acc <= '0';
      term_flag <= '0';
   end if;
end process;

--------------------------------------------------
-- Data Word fields
--------------------------------------------------
-- Data Payload
payload : process(dec_clk,rst_n,is_dw,data_sample,bit_cnt)
begin
   if ( rst_n = '0' ) then 
      dword1 <= (others => '0') ;
   elsif ( is_dw = '1' AND data_sample = '1' AND bit_cnt < 5 ) then
      dword1 <= dword1(1 to 4) & NOT data_sftreg(2) ;
   end if;
end process;

payload2: process(dec_clk,rst_n,is_dw,data_sample,bit_cnt)
begin
   if ( rst_n = '0') then
      dword2 <= '0';
   elsif ( is_dw = '1' AND data_sample = '1' AND bit_cnt = 5 ) then
      dword2 <= NOT data_sftreg(2);
   end if;
end process;

payload3 : process(dec_clk,rst_n,is_dw,data_sample,bit_cnt)
begin
   if ( rst_n = '0' ) then
      dword3 <= (others => '0');
   elsif ( is_dw = '1' AND data_sample = '1' AND ( bit_cnt > 5 AND bit_cnt <= 10 ) ) then
      dword3 <= dword3(1 to 4) & NOT data_sftreg(2) ;
   end if;
end process;

payload4 : process(dec_clk,rst_n,is_dw,data_sample,bit_cnt)
begin
   if ( rst_n = '0' ) then
      dword4 <= (others => '0');
   elsif ( is_dw  = '1' AND data_sample = '1' AND ( bit_cnt > 10 AND bit_cnt <= 15 ) ) then
      dword4 <= dword4(1 to 4) & NOT data_sftreg(2) ;
   end if;
end process;

is_cw <= sync_csw_reg AND BC;
is_sw <= sync_csw_reg AND NOT BC;
is_dw <= sync_dw_reg;


--------------------------------------------------
-- Line up outgoing 1553 with dec clock generate delayed edges.
--------------------------------------------------
-- Shift in the serial data through shift registers.
-- to delay incoming serial stream
sftreg_out : process(dec_clk,rst_n)
begin
   if ( rst_n = '0' ) then
      data_sftreg_out <= (others => '0') ;
   elsif rising_edge(dec_clk) then
      data_sftreg_out <= data_sftreg_out(1 to 31) & sync_sftreg(0) ;
   end if;
end process;

-- negative side
sftreg_out_n : process(dec_clk,rst_n)
begin
   if ( rst_n = '0' ) then
      data_sftreg_out_n <= (others => '0') ;  
   elsif rising_edge(dec_clk) then
      data_sftreg_out_n <= data_sftreg_out_n(1 to 31) & sync_sftreg_n(0) ;
   end if;
end process;

-- Detect delayed sync.
startshift : process(dec_clk,rst_n,bit_cnt,bitcnt,samplecnt)
begin
   if ( rst_n = '0' ) then
      start_shift <= '0';
   elsif rising_edge(dec_clk) then
      if (bit_cnt = 5 AND samplecnt = 0) then
         start_shift <= '1';
      elsif (bitcnt = 16 AND samplecnt = 7) then
         start_shift <= '0';
      end if;
   end if;
end process;

-- Delayed bit time count. Incoming stream is delayed 6 bit times.
bitcntr : process(dec_clk,rst_n,bit_cnt,bitcnt,samplecnt,shift_data)
begin
   if ( rst_n = '0' ) then
      bitcnt <= 0; -- (others => '0') ;
   elsif rising_edge(dec_clk) then
      if (bit_cnt = 5 OR bitcnt = 17 OR shift_data = '0') then
         bitcnt <= 0; -- (others => '0') ;
      elsif (samplecnt = 7) then
         bitcnt <= bitcnt + 1;
      end if;
   end if;
end process;

-- Register command and status sync patter type till the end 
-- of data word.
csw_dw_type : process(dec_clk,rst_n,bitcnt)
begin
   if (rst_n = '0') then  
      cw <= '0' ;
      sw <= '0' ;
      dw <= '0' ;
   elsif rising_edge(dec_clk) then
      if (bitcnt = 0) then
         cw <= is_cw ;
         dw <= is_dw ;
         sw <= is_sw ;
      elsif (bitcnt = 17) then
         cw <= '0' ;
         sw <= '0' ;
         dw <= '0' ; 
      end if;
   end if;
end process;

-- Sample counter for manchester coding and FSM
sample_cntr : process(dec_clk,rst_n)
begin
   if ( rst_n = '0' ) then   
      samplecnt <= (others => '0') ;
   elsif rising_edge(dec_clk) then
      if (bit_cnt = 5) then
         samplecnt <= (others => '0');
      elsif (READa = x"0010" OR SHIFT1 = x"0100" OR SHIFT2 = "1000" ) then
         samplecnt <=  samplecnt + 1;
      end if;
   end if;
end process;
   
-- FSM to shift data out encoded
manchester_FSM : process(dec_clk,rst_n,state,start_shift,samplecnt,data_reg)
begin 
   if (rst_n = '0') then
      state <= IDLE;
      enc_bit <= '0';
      enc_bit_n <= '0';
      shift_data <= '0';
      change <= '0';
   elsif rising_edge(dec_clk) then
      case (state) is
         WHEN IDLE => 
            if (start_shift = '1') then
               state <=  READa;
            else
               state <= IDLE;
            end if;

            shift_data <= '0';
            enc_bit <= '0';
            change  <= '0';

         WHEN READa =>
            change  <= '0';
            state <=  SHIFT1;

         WHEN SHIFT1 => 
            if (samplecnt < 3) then
               if (data_reg(bitcnt) = '0') then
                  enc_bit <= passthru(bitcnt);
               else
                  enc_bit <= NOT passthru(bitcnt);
                  change  <= '1';
               end if;
            else
               state <=  SHIFT2;
            end if;

            shift_data <= '1';

         WHEN SHIFT2 => 
            if (samplecnt < 7) then
               if (data_reg(bitcnt) = '0') then
                  enc_bit <= NOT passthru(bitcnt);
               else 
                  change  <= '1';
                  enc_bit <= passthru(bitcnt);
               end if;
            elsif (bitcnt < 16 AND samplecnt = 7) then
               state <= SHIFT1;
            elsif (bitcnt = 16 AND samplecnt = 7) then
               state <= IDLE;
            end if;    

            shift_data <= '1';

         WHEN others => 
            state <= IDLE;
            
      end case;
    end if;
  end process;
  
enc_bit_n <= NOT enc_bit;
select_a  <= BC & cw & dw & sw;
passthru  <= ('0' & rt_address & tr & sub_address & dwcnt_mcode & parity_bit) when select_a = "1100" else
             ('0' & dword1 & dword2 & dword3 & dword4 & parity_bit) when select_a = "1010" else
             ('0' & dword1 & dword2 & dword3 & dword4 & parity_bit) when select_a = "0010" else
             ('0' & rt_address & message_error & inst & srv_rqst & rsvd & bc_rcvd & busy & sub_flag & dbctrl_acc & term_flag & parity_bit) 
                when select_a = "0001" else (others => '0');

--nodata    <= ((bit_cnt = "00000") and (bitcnt = 17)) OR ((bit_cnt = "00000") and (bitcnt = 0)) OR ((bit_cnt = "00001") and (bitcnt = 0)) 
--               OR ((bit_cnt = "00010") and (bitcnt = 0));
                
-- Serialize the encoded data
txsigs: process(dec_clk,rst_n,bypass,bit_cnt,samplecnt,shift_data)
begin
   if (rst_n = '0') then   
      txdval   <= '0' ;
      txdata   <= '0' ;
      txdata_n <= '0' ;
   elsif (bypass = '1') then
      txdval   <= '0' ;
      txdata   <= data_sftreg_out(12) ;
      txdata_n <= data_sftreg_out_n(12) ;
   elsif (bit_cnt >= 3 AND bit_cnt <= 5) then   
      txdval   <= '0' ;
      txdata   <= data_sftreg_out(12) ;
      txdata_n <= data_sftreg_out_n(12) ;
   elsif (bit_cnt = 6 AND samplecnt < 2 ) then   
      txdval   <= '0' ;
      txdata   <= data_sftreg_out(12) ;
      txdata_n <= data_sftreg_out_n(12) ;
   elsif (shift_data = '1' OR bit_cnt >= 6) then  
      txdval   <= '1' ;
      txdata   <= enc_bit ;
      txdata_n <= enc_bit_n ;
   else
      txdval   <= '0' ;
      txdata   <= data_sftreg_out(12) ;
      txdata_n   <= data_sftreg_out_n(12) ;
   end if;
end process;

tx_dval   <= txdval;
tx_data   <= txdata;
tx_data_n <= txdata_n;

-- Memory RAM control signals
lookup_en: process(dec_clk,rst_n,bit_cnt,cnt)
begin
   if (rst_n = '0') then   
      enb <= '0' ;
   elsif (bit_cnt = 5 AND cnt = 33) then   
      enb <= '1' ;
   else
      enb <= '0' ;
   end if;
end process;

blk_mem_1553_inst : blk_mem_1553
  PORT MAP (
    clka  => sys_clk,
    wea   => mem_wea,
    addra => mem_addra,
    dina  => mem_datin,
    clkb  => dec_clk,
    enb   => enb,
    addrb => mem_addrb,
    doutb => data_reg
  );
  
debug <= start_shift & data_sftreg_out(13) & cw & dw & sw & std_logic_vector(to_unsigned(bitcnt,5));

end Behavioral;

-- =============================================================================
