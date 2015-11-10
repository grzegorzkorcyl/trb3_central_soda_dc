----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   22-05-2015
-- Module Name:   DC_SODA_clockcrossing
-- Description:   Transfer SODA signals to different clock domain
-- Modifications:
--   30-09-2015   input signals buffered with registers
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

----------------------------------------------------------------------------------
-- DC_SODA_clockcrossing
-- Transfer SODA signals to different clock domain
--
-- Library
--
-- Generics:
-- 
-- Inputs:
--     write_clock : clock for DLM input
--     read_clock : clock for DLM output
--     DLM_in : SODA DLM active input
--     DLM_WORD_in : 8-bits SODA DLM data (valid one clock cycle after DLM_in)
-- 
-- Outputs:
--     DLM_out : SODA DLM active output
--     RX_DLM_WORD : 8-bits SODA DLM data
--     error : error : fifo full
-- 
-- Components:
--     async_fifo_16x8 : 8-bits asynchronous fifo
--
----------------------------------------------------------------------------------


entity DC_SODA_clockcrossing is
	port ( 
		write_clock             : in std_logic;
		read_clock              : in std_logic;
		DLM_in                  : in std_logic;
		DLM_WORD_in             : in std_logic_vector(7 downto 0);
		DLM_out                 : out std_logic;
		DLM_WORD_out            : out std_logic_vector(7 downto 0);
		error                   : out std_logic
	);
end DC_SODA_clockcrossing;

architecture Behavioral of DC_SODA_clockcrossing is

component async_fifo_16x8
	port (
		rst                     : in std_logic;
		wr_clk                  : in std_logic;
		rd_clk                  : in std_logic;
		din                     : in std_logic_vector(7 downto 0);
		wr_en                   : in std_logic;
		rd_en                   : in std_logic;
		dout                    : out std_logic_vector(7 downto 0);
		full                    : out std_logic;
		empty                   : out std_logic);
end component;



signal DLM_in_S                 : std_logic;
signal DLM_in_aftr1clk_S        : std_logic;
signal DLM_WORD_in_S            : std_logic_vector(7 downto 0);
signal DLM_WORD_out_S           : std_logic_vector(7 downto 0);
signal fifo_read_S              : std_logic;
signal fifo_empty_S             : std_logic;
signal fifo_read_aftr1clk_S     : std_logic := '0';
signal DLM_reading_busy0_S      : std_logic := '0';
signal DLM_reading_busy1_S      : std_logic := '0';

begin

process(write_clock)
begin
	if rising_edge(write_clock) then
		DLM_in_S <= DLM_in;
		DLM_WORD_in_S <= DLM_WORD_in;
		DLM_in_aftr1clk_S <= DLM_in_S;
	end if;
end process; 

syncSODAfifo: async_fifo_16x8 port map(
		rst => '0',
		wr_clk => write_clock,
		rd_clk => read_clock,
		din => DLM_WORD_in_S,
		wr_en => DLM_in_aftr1clk_S,
		rd_en => fifo_read_S,
		dout => DLM_WORD_out_S,
		full => error,
		empty => fifo_empty_S);

fifo_read_S <= '1' when (DLM_reading_busy0_S='1') and (DLM_reading_busy1_S='1') and (fifo_empty_S='0') and (fifo_read_aftr1clk_S='0') else '0';

process(read_clock)
begin
	if rising_edge(read_clock) then
		if fifo_read_aftr1clk_S='1' then
			DLM_WORD_out <= DLM_WORD_out_S;
		end if;
		DLM_out <= fifo_read_aftr1clk_S;
	end if;
end process; 

process(read_clock)
begin
	if rising_edge(read_clock) then
		if DLM_reading_busy0_S='0' then
			if fifo_empty_S='0' then
				DLM_reading_busy0_S <= '1';
			end if;
		else
			if fifo_empty_S='1' then
				DLM_reading_busy0_S <= '0';
			end if;
		end if;
		fifo_read_aftr1clk_S <= fifo_read_S;
		DLM_reading_busy1_S <= DLM_reading_busy0_S;
	end if;
end process;  

end Behavioral;

