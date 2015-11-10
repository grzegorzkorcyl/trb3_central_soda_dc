----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   19-11-2014
-- Module Name:   DC_fifo32to8_SODA
-- Description:   FIFO with 32 bits to 8 bits conversion and SODA
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;
library work;
use work.panda_package.all;

----------------------------------------------------------------------------------
-- DC_fifo32to8_SODA
-- FIFO with 32 bits to 8 bits conversion and additional K-character
-- Data is written in asynchronous 32-bits fifo
-- After reading the data is splitted in bytes.
-- If no data is available an Idle is put on the output (BC and the K-character signal).
-- SODA signals (DLM) are passed on directly (highest priority).
--
-- Library
--     work.panda_package : for GTP/GTX/serdes constants
--
-- Generics:
-- 
-- Inputs:
--     write_clock : clock for the 32-bits input data
--     read_clock : clock for the 16-bits output data
--     reset : reset
--     data_in : 32-bits input data
--     data_write : write signal for 32-bits input data
--     TX_DLM : transmit SODA character
--     TX_DLM_WORD : SODA character to be transmitted
-- 
-- Outputs:
--     full : fifo is full
--     data_out : 16-bits output data
--     char_is_k : corresponding byte in 16-bits output data is K-character
-- 
-- Components:
--     async_fifo_512x32 : 32-bits asynchronous fifo
--
----------------------------------------------------------------------------------


entity DC_fifo32to8_SODA is
	port ( 
		write_clock             : in std_logic;
		read_clock              : in std_logic;
		reset                   : in std_logic;
		data_in                 : in std_logic_vector(31 downto 0);
		data_write              : in std_logic;
		full                    : out std_logic;
		TX_DLM                  : in std_logic;
		TX_DLM_WORD             : in std_logic_vector(7 downto 0);
		data_out                : out std_logic_vector(7 downto 0);
		char_is_k               : out std_logic
	);
end DC_fifo32to8_SODA;

architecture Behavioral of DC_fifo32to8_SODA is

component async_fifo_512x32
	port (
		rst                     : in std_logic;
		wr_clk                  : in std_logic;
		rd_clk                  : in std_logic;
		din                     : in std_logic_vector(31 downto 0);
		wr_en                   : in std_logic;
		rd_en                   : in std_logic;
		dout                    : out std_logic_vector(31 downto 0);
		full                    : out std_logic;
		empty                   : out std_logic);
end component;

signal fifo_read_S              : std_logic;
signal fifo_read0_S             : std_logic;
signal fifo_dataout_S           : std_logic_vector(31 downto 0);
signal fifo_databuf_S           : std_logic_vector(31 downto 0);
signal data_out_S               : std_logic_vector(7 downto 0);
signal char_is_k_S              : std_logic;
signal fifo_empty_S             : std_logic;

signal fifo_buffilled_S         : std_logic := '0';
signal fifo_read_after1clk_S    : std_logic := '0';
signal TX_DLM_S                 : std_logic;
signal TX_DLM_WORD_S            : std_logic_vector(7 downto 0);
signal bytecounter_S            : integer range 0 to 3 := 0;
signal write_data_S             : std_logic;
signal lastbytefilled_S         : std_logic;
signal lastbyte_S               : std_logic_vector(7 downto 0);


begin

process (read_clock)
begin
	if rising_edge(read_clock) then
		data_out <= data_out_S;
		char_is_k <= char_is_k_S;
	end if;
end process;

	
fifo: async_fifo_512x32 port map(
		rst => reset,
		wr_clk => write_clock,
		rd_clk => read_clock,
		din => data_in,
		wr_en => data_write, 
		rd_en => fifo_read_S,
		dout => fifo_dataout_S,
		full => full,
		empty => fifo_empty_S);

fifo_read_S <= '1' when (fifo_empty_S='0') and (TX_DLM='0') and 
		(fifo_read0_S='1')
--//		(fifo_read_after1clk_S='0') and (lastbytefilled_S='0') and 
--//		(((bytecounter_S=0)  and (fifo_buffilled_S='0')) or ((bytecounter_S=3) and (fifo_buffilled_S='0')))
	else '0';
	
data_out_S <= 
	KCHARSODA when TX_DLM='1' else
	TX_DLM_WORD when (TX_DLM_S='1') else
	KCHAR285 when (write_data_S='0') else
	lastbyte_S when (lastbytefilled_S='1') else
	fifo_dataout_S(31 downto 24) when (fifo_read_after1clk_S='1') else
	fifo_databuf_S((3-bytecounter_S)*8+7 downto (3-bytecounter_S)*8);
	
char_is_k_S <=
	'1' when TX_DLM='1' else
	'0' when (TX_DLM_S='1') else
	'1' when (write_data_S='0') else
	'0' when fifo_read_after1clk_S='1' else 
	'0';

write_data_S <= '1' when ((TX_DLM='0') and (TX_DLM_S='0')) and 
	((fifo_read_after1clk_S='1') or (bytecounter_S/=0) or (fifo_buffilled_S='1') or (lastbytefilled_S='1')) else '0';

tx_process : process (read_clock)
variable lastbytefilled_V : std_logic;
variable fifo_buffilled_V : std_logic;
variable bytecounter_V : integer range 0 to 3 := 0;
begin
	if rising_edge(read_clock) then
		-- if reset='1' then
			-- fifo_read_after1clk_S <= '0';
			-- TX_DLM_S <= '0';
			-- lastbytefilled_S <= '0';
			-- bytecounter_S <= 0;
		-- else
			TX_DLM_S <= TX_DLM;
			if TX_DLM='1' then
				TX_DLM_WORD_S <= TX_DLM_WORD;
			end if;
			fifo_read_after1clk_S <= fifo_read_S;
			if (TX_DLM='1') and (fifo_buffilled_S='0') and (bytecounter_S=3) then 
				lastbytefilled_V := '1'; --// lastbytefilled_S <= '1';
				lastbyte_S <= fifo_databuf_S(7 downto 0);
			elsif not ((TX_DLM='1') or (TX_DLM_S='1') or (write_data_S='0')) then
				lastbytefilled_V := '0'; --// lastbytefilled_S <= '0';
			end if;
			if (fifo_read_after1clk_S='1') then
				fifo_databuf_S <= fifo_dataout_S;
			end if;	
			if (TX_DLM='1') or (TX_DLM_S='1') then
				if (fifo_read_after1clk_S='1') then
					fifo_buffilled_V := '1'; --// fifo_buffilled_S <= '1';
				end if;	
			elsif lastbytefilled_S='1' then
				bytecounter_V := 0; --// bytecounter_S <= 0;
				if (fifo_read_after1clk_S='1') then
					fifo_buffilled_V := '1'; --// fifo_buffilled_S <= '1';
				end if;	
			else
				case bytecounter_S is
					when 0 =>
						if (fifo_buffilled_S='1') or (fifo_read_after1clk_S='1') then
							fifo_buffilled_V := '1'; --// fifo_buffilled_S <= '1';
							bytecounter_V := 1; --// bytecounter_S <= 1;
						end if;
					when 1 =>
						fifo_buffilled_V := '1'; --// fifo_buffilled_S <= '1';
						bytecounter_V := 2; --// bytecounter_S <= 2;
					when 2 =>
						fifo_buffilled_V := '0'; --// fifo_buffilled_S <= '0';
						bytecounter_V := 3; --// bytecounter_S <= 3;
					when 3 =>
						fifo_buffilled_V := '0'; --// fifo_buffilled_S <= '0';
						bytecounter_V := 0; --// bytecounter_S <= 0;
					when others =>
						fifo_buffilled_V := '0'; --// fifo_buffilled_S <= '0';
						bytecounter_V := 0; --// bytecounter_S <= 0;
				end case;
			end if;
			lastbytefilled_S <= lastbytefilled_V;
			fifo_buffilled_S <= fifo_buffilled_V;
			bytecounter_S <= bytecounter_V;
			if (fifo_read_S='0') and (lastbytefilled_V='0') and 
				(((bytecounter_V=0) and (fifo_buffilled_V='0')) or ((bytecounter_V=3) and (fifo_buffilled_V='0'))) then
				fifo_read0_S <= '1';
			else
				fifo_read0_S <= '0';
			end if;

--		end if;
	end if;
end process;


end Behavioral;

