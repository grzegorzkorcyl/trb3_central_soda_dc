----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   15-09-2015
-- Module Name:   DC_wavemux_readfifo
-- Description:   Read 36-bits data from fifo and write to next module
-- Modifications:
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;
USE work.panda_package.all;

----------------------------------------------------------------------------------
-- DC_wavemux_readfifo
-- Read 36-bits data from fifo and write to next module.
--
-- Library:
--     work.panda_package: constants and types
--
-- Generics:
--
-- Inputs:
--     clock : ADC sampling clock 
--     reset : synchrounous reset
--     data_in : 36-bits input data from fifo
--     data_in_available : input fifo not empty
--     data_out_allowed : allowed to write output data data
-- 
-- Outputs:
--     data_in_read : read signal to input fifo
--     data_out : 36-bits output data
--     data_out_write : write signal for output data
--     data_out_inpipe : data available, in this module or in input fifo
-- 
-- Components:
--
--
--
----------------------------------------------------------------------------------

entity DC_wavemux_readfifo is
    Port ( 
		clock                   : in std_logic;
		reset                   : in std_logic;
		data_in                 : in std_logic_vector(35 downto 0);
		data_in_available       : in std_logic;
		data_in_read            : out std_logic;
		data_out                : out std_logic_vector(35 downto 0);
		data_out_write          : out std_logic;
		data_out_inpipe         : out std_logic;
		data_out_allowed        : in std_logic);
end DC_wavemux_readfifo;


architecture Behavioral of DC_wavemux_readfifo is

signal data_in_S                 : std_logic_vector(35 downto 0) := (others => '0');
signal data_out_S                : std_logic_vector(35 downto 0) := (others => '0');
signal data_out_write_S          : std_logic := '0';
signal data_in_saved_S           : std_logic := '0';
signal data_in_read_S            : std_logic := '0';
signal data_in_read_after1clk_S  : std_logic := '0';
signal data_out_trywrite_S       : std_logic := '0';

begin

data_out_inpipe <= '1' when (data_in_available='1') or (data_out_trywrite_S='1') or (data_in_saved_S='1') else '0';

data_in_read <= data_in_read_S;
data_in_read_S <= '1' when (data_out_allowed='1') and (data_in_available='1') and (data_in_saved_S='0') else '0';

data_out_write <= data_out_write_S;
data_out_write_S <= '1' when (data_out_trywrite_S='1') and (data_out_allowed='1') else '0';

data_out <= data_out_S;

process(clock)
begin
	if (rising_edge(clock)) then 
		if reset='1' then
			data_in_read_after1clk_S <= '0';
			data_out_trywrite_S <= '0';
			data_in_saved_S <= '0';
		else
			if (data_out_write_S='0') and (data_out_trywrite_S='1') then -- unsuccesfull try again
				data_out_trywrite_S <= '1';
				if data_in_read_after1clk_S='1' then
					data_in_S <= data_in;
					data_in_saved_S <= '1';
				end if;
			elsif data_in_saved_S='1' then -- write saved data
				data_out_S <= data_in_S;
				data_out_trywrite_S <= '1';
				if data_in_read_after1clk_S='1' then -- save next data
					data_in_S <= data_in;
					data_in_saved_S <= '1';
				else
					data_in_saved_S <= '0';
				end if;
			elsif data_in_read_after1clk_S='1' then -- next read
				data_out_S <= data_in;
				data_out_trywrite_S <= '1';
			else
				data_out_trywrite_S <= '0';
			end if;
			data_in_read_after1clk_S <= data_in_read_S;
		end if;
	end if;
end process;

		
end Behavioral;

