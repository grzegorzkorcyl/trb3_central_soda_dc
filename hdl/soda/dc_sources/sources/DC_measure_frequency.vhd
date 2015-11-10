----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   21-06-2011
-- Module Name:   DC_measure_frequency
-- Description:   Measures the frequency of pulses 
-- Modifications:
--    16-09-2014: name changed from MUX_measure_frequency to DC_measure_frequency
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;
USE work.panda_package.all;

----------------------------------------------------------------------------------
-- DC_measure_frequency
-- Measures the number of pulses in one second
--
-- Library
--     work.panda_package :  for type declarations and constants
-- 
-- Generics:
--     CLOCKFREQUENCY : frequency of the clock
-- 
-- Inputs:
--     clock : clock
--     pulse : pulse to count
-- 
-- Outputs:
--     frequency : number of pulses measured in one second
-- 
-- Components:
--
----------------------------------------------------------------------------------

entity DC_measure_frequency is
	generic (
		CLOCKFREQUENCY          : natural := 62500000
	);
	port ( 
		clock                   : in std_logic;
		pulse                   : in std_logic;
		frequency               : out std_logic_vector(31 downto 0)
	);
end DC_measure_frequency;

architecture Behavioral of DC_measure_frequency is

signal counter_S                  : std_logic_vector(31 downto 0) := (others => '0');
signal onesecondpulse_S           : std_logic := '0';


begin
process(clock)
variable counter : integer range 0 to CLOCKFREQUENCY-1 := 0;
begin
	if (rising_edge(clock)) then 
		if counter/=0 then
			counter := counter-1;
			onesecondpulse_S <= '0';
		else
			counter := CLOCKFREQUENCY-1;
			onesecondpulse_S <= '1';
		end if;
	end if;
end process;


process(clock)
begin
	if (rising_edge(clock)) then 
		if onesecondpulse_S='1' then
			frequency <= counter_S;
			if pulse='1' then
				counter_S <= x"00000001";
			else
				counter_S <= x"00000000";
			end if;
		else
			if pulse='1' then
				counter_S <= counter_S+1;
			end if;
		end if;
	end if;
end process;


end Behavioral;
