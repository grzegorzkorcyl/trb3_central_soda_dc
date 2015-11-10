----------------------------------------------------------------------------------
-- Company:       KVI-CART/RUG/Groningen University
-- Engineer:      Oscar Kuiken
-- Create Date:   04-feb-2014
-- Module Name:   dataconversion_for_serdes
-- Description:   Converts the 64-bits data from MUX to 8-bit data suitable for 
--                SERDES communication. Control signals from MUX are transformed
--                into k-characters.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;

entity dataconversion_for_serdes16 is
  generic(
    CREATE_OWN_STIMULI : BOOLEAN := FALSE);
  port(
    DATA_CLK        : in  std_logic;
	CLK             : in  std_logic;
    RESET           : in  std_logic;
    TX_READY        : in  std_logic;
    SFP_MOD0        : in  std_logic;
    SFP_LOS         : in  std_logic;
    TX_DATA         : out std_logic_vector(15 downto 0);
    TX_K            : out std_logic_vector(1 downto 0);
    DATA_IN_ALLOWED : out std_logic;
    DATA_IN         : in  std_logic_vector(63 downto 0);
    DATA_IN_WRITE   : in  std_logic;
    DATA_IN_FIRST   : in  std_logic;
    DATA_IN_LAST    : in  std_logic;
    DATA_IN_ERROR   : in  std_logic);
end dataconversion_for_serdes16;

architecture behaviour of dataconversion_for_serdes16 is

component fifo_8x66
port (
		DATA    : in  std_logic_vector(65 downto 0);
		CLOCK   : in  std_logic; 
		WREN    : in  std_logic;
		RDEN    : in  std_logic;
		RESET   : in  std_logic;
		Q       : out  std_logic_vector(65 downto 0);
		EMPTY   : out  std_logic; 
		FULL    : out  std_logic);
end component;

component async_fifo_256x66 is
port (
		rst                     : in std_logic;
		wr_clk                  : in std_logic;
		rd_clk                  : in std_logic;
		din                     : in std_logic_vector(65 downto 0);
		wr_en                   : in std_logic;
		rd_en                   : in std_logic;
		dout                    : out std_logic_vector(65 downto 0);
		full                    : out std_logic;
		empty                   : out std_logic
	);
end component;

  signal fifo_rden                : std_logic;
  signal fifo_rden_d1             : std_logic;
  signal fifo_data_out            : std_logic_vector(65 downto 0);
  signal fifo_data_out_d1         : std_logic_vector(65 downto 0);
  signal fifo_empty               : std_logic;
  signal fifo_full                : std_logic;
  
  signal word_cnt                 : integer range 0 to 15;
  signal break_cnt                : integer range 0 to 16383;
  signal no_packet_send           : std_logic;
  signal stimuli                  : std_logic_vector(63 downto 0);
  
  signal data_in_generated        : std_logic_vector(63 downto 0);
  signal data_in_first_generated  : std_logic;
  signal data_in_last_generated   : std_logic;
  signal data_in_write_generated  : std_logic;
  
  signal reset_everything         : std_logic;
  signal reset_everything_dataclk : std_logic;
  
  
  type state_type is (idle, send8b_1_or_send_firstflag, send8b_1, send8b_2, send8b_3, send8b_4, send_lastflag);
  signal current_state : state_type;

begin

  reset_everything <= '1' when (RESET = '1') or (TX_READY = '0') or (SFP_MOD0 = '1') or (SFP_LOS = '1') else '0';

  local_stimuli: if CREATE_OWN_STIMULI = TRUE generate
  
--    tx_fifo : fifo_8x66
--      port map(
--        DATA(65)           => data_in_first_generated,
--        DATA(64)           => data_in_last_generated,
--        DATA(63 downto 0)  => data_in_generated,
--        CLOCK              => CLK,
--        WREN               => data_in_write_generated,
--        RDEN               => fifo_rden,
--        RESET              => reset_everything,
--        Q                  => fifo_data_out,
--        EMPTY              => fifo_empty,
--        FULL               => fifo_full);

		  
tx_fifo: async_fifo_256x66 
	port map(
		rst => reset_everything,
		wr_clk => CLK,
		rd_clk => CLK,
		din(65) => data_in_first_generated,
		din(64) => data_in_last_generated,
		din(63 downto 0)  => data_in_generated,
		wr_en => data_in_write_generated,
		rd_en => fifo_rden,
		dout => fifo_data_out,
		full => fifo_full,
		empty => fifo_empty);


    process(reset_everything, CLK)
    begin
      if reset_everything = '1' then
        word_cnt       <= 0;
        break_cnt      <= 0;
        no_packet_send <= '1';
        stimuli(31 downto 0)  <= x"00000000";
        stimuli(63 downto 32) <= x"FFFFFFFF";
      elsif rising_edge(CLK) then
        if not (stimuli(31 downto 0) = x"00000000" and no_packet_send = '0' and break_cnt = 500) then
          -- If we haven't send every 32-bit number once, then we're not finished yet
          if word_cnt < 8 then
            word_cnt              <= word_cnt + 1;
            stimuli(31 downto 0)  <= stimuli(31 downto 0)  + 1;
            stimuli(63 downto 32) <= stimuli(63 downto 32) - 1;
          elsif break_cnt < 500 then
            break_cnt <= break_cnt + 1;
          else
            word_cnt  <= 0;
            break_cnt <= 0;
          end if;
        end if;
      end if;
    end process;
    
    data_in_generated         <= stimuli;
    data_in_first_generated   <= '1' when word_cnt = 0 else '0';
    data_in_last_generated    <= '1' when word_cnt = 7 else '0';
    data_in_write_generated   <= '1' when word_cnt < 8 else '0';
    
  end generate;
  
  external_stimuli: if CREATE_OWN_STIMULI = FALSE generate
  
	tx_fifo : async_fifo_256x66
		port map (
			rst => reset_everything,
			wr_clk => DATA_CLK,
			rd_clk => CLK,
			din(65) => DATA_IN_FIRST,
			din(64) => DATA_IN_LAST,
			din(63 downto 0)  => DATA_IN,
			wr_en => DATA_IN_WRITE,
			rd_en => fifo_rden,
			dout => fifo_data_out,
			full => fifo_full,
			empty => fifo_empty
		);
	
   end generate;
 
  DATA_IN_ALLOWED <= '1' when (fifo_full='0') and (reset_everything_dataclk='0') else '0';
	process(DATA_CLK)
    begin
      if rising_edge(DATA_CLK) then
		reset_everything_dataclk <= reset_everything;
	  end if;
	end process;
		
 
process(reset_everything, CLK)
	begin
		if reset_everything = '1' then
			fifo_data_out_d1 <= (others => '0');
			fifo_rden_d1     <= '0';
		elsif rising_edge(CLK) then
			fifo_rden_d1 <= fifo_rden;
			if fifo_rden_d1 = '1' then
				fifo_data_out_d1 <= fifo_data_out;
			end if;
		end if;
end process;

fifo_rden <= '1' when ((fifo_empty='0') and (fifo_rden_d1='0')) and
	((current_state=idle)  or 
--	((current_state=send8b_3) and (fifo_data_out_d1(64)='0')) or
	((current_state=send8b_4) and (fifo_data_out_d1(64)='0')) or
	(current_state=send_lastflag)) else '0';
	
process(reset_everything, CLK)
begin
	if reset_everything = '1' then
		current_state   <= idle;
	elsif rising_edge(CLK) then
		TX_DATA <= x"BCBC";
		TX_K <= "11";

		case current_state is
			when idle =>
				if fifo_rden='1' then
					current_state <= send8b_1_or_send_firstflag;
				end if;

			when send8b_1_or_send_firstflag =>
				if fifo_data_out(65) = '1' then
					-- Before sending the first data of a set, k-character DC must be send
					current_state <= send8b_1;
					TX_DATA <= x"DCBC"; -- LSB byte first
					TX_K <= "11";
				else
					current_state <= send8b_2;
					TX_DATA <= fifo_data_out(55 downto 48) & fifo_data_out(63 downto 56);
					TX_K <= "00";
				end if;

			when send8b_1 =>
				current_state <= send8b_2;
				TX_DATA <= fifo_data_out_d1(55 downto 48) & fifo_data_out(63 downto 56);
				TX_K <= "00";

			when send8b_2 =>
				current_state <= send8b_3;
				TX_DATA <= fifo_data_out_d1(39 downto 32) & fifo_data_out_d1(47 downto 40);
				TX_K <= "00";

			when send8b_3 =>
				current_state <= send8b_4;
				TX_DATA <= fifo_data_out_d1(23 downto 16) & fifo_data_out_d1(31 downto 24);
				TX_K <= "00";

			when send8b_4 =>
				if fifo_rden='1' then
					current_state <= send8b_1_or_send_firstflag;
				elsif fifo_data_out_d1(64) = '0' then -- Apparently this is not the last data of this set 
					current_state <= idle;
				else -- Apparently this is the last data of this set
					current_state <= send_lastflag;
				end if;
				TX_DATA <= fifo_data_out_d1(7 downto 0) & fifo_data_out_d1(15 downto 8);
				TX_K <= "00";

			when send_lastflag =>
				if fifo_rden='1' then
					current_state <= send8b_1_or_send_firstflag;
				else
					current_state <= idle;
				end if;
				TX_DATA <= x"BCFC";
				TX_K <= "11";
		end case;
	end if;
end process;
  
end behaviour;