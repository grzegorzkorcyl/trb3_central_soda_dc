----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   19-11-2014
-- Module Name:   DC_fifo8to32_SODA
-- Description:   FIFO with 8 bits to 32 bits conversion and SODA
-- Modifications:
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library work;
use work.panda_package.all;

----------------------------------------------------------------------------------
-- DC_fifo8to32_SODA
-- FIFO with 8 bits to 32 bits conversion and SODA
-- Byte data is converted to 32-bits, alignment is done with check on first word after idles
-- The resulting 32-bits word is written in an asynchronous 32-bits fifo.
-- SODA signals (DLM) are passed on directly (highest priority).
--
-- Library
--     work.gtpBufLayer : for GTP/GTX/serdes constants
--
-- Generics:
-- 
-- Inputs:
--     write_clock : clock for the 32-bits input data
--     read_clock : clock for the 16-bits output data
--     reset : reset
--     data_in : 8-bits input data
--     char_is_k : corresponding byte in 16-bits data input is K-character
--     data_read : read signal for 32-bits output data
-- 
-- Outputs:
--     RX_DLM : SODA character received
--     RX_DLM_WORD : SODA character 
--     data_out : 32-bits output data (asynchrounous)
--     data_available : 32-bits output data available (fifo not empty)
--     overflow : fifo overflow : data has been thrown away
--     error : error in input data
-- 
-- Components:
--     async_fifo_512x32 : 32-bits asynchronous fifo
--
----------------------------------------------------------------------------------


entity DC_fifo8to32_SODA is
	port ( 
		write_clock             : in std_logic;
		read_clock              : in std_logic;
		reset                   : in std_logic;
		data_in                 : in std_logic_vector(7 downto 0);
		char_is_k               : in std_logic;
		RX_DLM                  : out std_logic;
		RX_DLM_WORD             : out std_logic_vector(7 downto 0);
		data_out                : out std_logic_vector(31 downto 0);
		data_read               : in std_logic;
		data_available          : out std_logic;
		overflow                : out std_logic;
		error                   : out std_logic		
	);
end DC_fifo8to32_SODA;

architecture Behavioral of DC_fifo8to32_SODA is

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

signal fifo_write_S             : std_logic;
signal fifo_datain_S            : std_logic_vector(31 downto 0);
signal fifo_full_S              : std_logic;
signal fifo_empty_S             : std_logic;
signal error_S                  : std_logic := '0';
signal RX_DLM0_S                : std_logic := '0';
signal RX_DLM_S                 : std_logic := '0';
signal RX_DLM_WORD_S            : std_logic_vector(7 downto 0) := (others => '0');
signal bytecounter_S            : integer range 0 to 3 := 0;

begin

error <= error_S;
RX_DLM_WORD <= RX_DLM_WORD_S;
RX_DLM <= RX_DLM_S;

fifo: async_fifo_512x32 port map(
		rst => reset,
		wr_clk => write_clock,
		rd_clk => read_clock,
		din => fifo_datain_S,
		wr_en => fifo_write_S, 
		rd_en => data_read,
		dout => data_out,
		full => fifo_full_S,
		empty => fifo_empty_S);
data_available <= '1' when fifo_empty_S='0' else '0';

overflow <= '1' when (fifo_write_S='1') and (fifo_full_S='1') else '0';

rx_process : process(write_clock)
variable idlecounter_V : integer range 0 to 4;
begin
	if rising_edge(write_clock) then
		RX_DLM_S <= '0';
		error_S <= '0';
		fifo_write_S <= '0';
		if reset='1' then
			RX_DLM0_S <= '0';
			bytecounter_S <= 0;
			idlecounter_V := 0;
		else
			if (char_is_k='1') and (data_in=KCHARSODA) then
				RX_DLM0_S <= '1';
				error_S <= RX_DLM0_S; -- not 2 DLM after each other
			elsif RX_DLM0_S='1' then
				RX_DLM0_S <= '0';
				RX_DLM_S <= '1';
				RX_DLM_WORD_S <= data_in; 
			elsif (char_is_k='1') then -- idle: ignore a few
				if idlecounter_V<4 then
					idlecounter_V := idlecounter_V+1;
				else
					bytecounter_S <= 0;
				end if;
			else -- data
				idlecounter_V := 0;
				fifo_datain_S(31 downto 24) <= fifo_datain_S(23 downto 16);
				fifo_datain_S(23 downto 16) <= fifo_datain_S(15 downto 8);
				fifo_datain_S(15 downto 8) <= fifo_datain_S(7 downto 0);
				fifo_datain_S(7 downto 0) <= data_in;
				if bytecounter_S=3 then
					bytecounter_S <= 0;
					fifo_write_S <= '1';
				else
					bytecounter_S <= bytecounter_S+1;
				end if;
			end if;
		end if;
	end if;
end process;


end Behavioral;

