----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   11-08-2009
-- Module Name:   synchronize_to_other_clock
-- Description:   Synchronize parallel data to another clock
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

----------------------------------------------------------------------------------
-- Random_energy
-- Synchronise parallel data to a other clock.
-- Not all data is guaranteed to be passed through, but the output data is always valid.
-- 
-- Library
-- 
-- Generics:
--     DATA_WIDTH : width of data input/output data
--
-- Inputs:
--     data_in_clock : slower input clock 
--     data_in_clock : slower input clock 
--     data_out_clock : faster clock for output data
-- 
-- Outputs:
--     data_out : synchronised output data
-- 
-- Components:
--
----------------------------------------------------------------------------------

entity synchronize_to_other_clock is
    generic (
        DATA_WIDTH : natural := 8
    );
    port (
		data_in_clock : in std_logic;
		data_in : in std_logic_vector(DATA_WIDTH-1 downto 0);
		data_out_clock : in std_logic;
		data_out : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity;

architecture behavioral of synchronize_to_other_clock is
signal register1 : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
signal busy : std_logic := '0';
signal busy_clkin : std_logic := '0';
signal busy_clkout : std_logic := '0';
signal available : std_logic := '0';
signal available_clkin : std_logic := '0';
signal available_clkout : std_logic := '0';

begin

process (data_in_clock)
begin
	if rising_edge(data_in_clock) then
		if (busy_clkin='0') and (available_clkin='0') then
			available_clkin <= '1';
			register1 <= data_in;
		elsif busy_clkin='1' then
			available_clkin <= '0';
		end if;
		busy_clkin <= busy;
		available <= available_clkin;
	end if;
end process;

process (data_out_clock)
begin
	if rising_edge(data_out_clock) then
		if (available_clkout='1') and (busy_clkout='0') then
			busy_clkout <= '1';
			data_out <= register1;
		elsif available_clkout='0' then
			busy_clkout <= '0';
		end if;
		available_clkout <= available;
		busy <= busy_clkout;
	end if;
end process;



end architecture behavioral;


