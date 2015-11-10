----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   04-02-2015
-- Module Name:   DC_data16to8
-- Description:   Converts 16 bits data at 100MHz to 8 bits data at 200MHz
-- Modifications:
--   04-05-2015   version Data Concentrator instead of Front End Electronics
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;
library UNISIM;
use UNISIM.VComponents.all;

----------------------------------------------------------------------------------
-- DC_data16to8
-- Converts 16 bits data at 100MHz to 8 bits data at 200MHz
--
-- Library
-- 
-- Generics:
-- 
-- Inputs:
--     clock_in : input clock at single 
--     data_in : 16 bits input data
--     kchar_in : corresponding k-character (one for each input byte)
--     notintable_in : error, signal not in 10/8 decoder table
-- 
-- Outputs:
--     clock_out : output clock at double speed
--     data_out : 8 bits output data at double speed
--     kchar_out : corresponding k-character
--     notintable_out : error, signal not in 10/8 decoder table
-- 
-- Components:
--     clock100to200 : clock doubler : 100MHz -> 200MHz
--
----------------------------------------------------------------------------------

entity DC_data16to8 is
	port ( 
		clock_in                : in std_logic;
		data_in                 : in std_logic_vector(15 downto 0);
		kchar_in                : in std_logic_vector(1 downto 0);
		notintable_in           : in std_logic_vector(1 downto 0);
		clock_out               : out std_logic;
		data_out                : out std_logic_vector(7 downto 0);
		kchar_out               : out std_logic;
		notintable_out          : out std_logic
	);
end DC_data16to8;

architecture Behavioral of DC_data16to8 is

component clock100to200 is
	port
	(
		clk_in1                 : in std_logic;
		clk_out1                : out std_logic;
		reset                   : in std_logic;
		locked                  : out std_logic
	);
end component;

signal clock_out_S              : std_logic;
signal phase_S                  : std_logic;
signal kchar_in_S               : std_logic_vector(1 downto 0);

begin

clock100to200_1: clock100to200 port map(
		clk_in1 => clock_in,
		clk_out1 => clock_out_S,
		reset => '0',
		locked => open);
clock_out <= clock_out_S;

process(clock_out_S)
begin
	if (rising_edge(clock_out_S)) then
		kchar_in_S <= kchar_in;
	end if;
end process;
	
process(clock_out_S)
begin
	if (rising_edge(clock_out_S)) then
		if kchar_in_S/=kchar_in then
			phase_S <= '0';
		else
			phase_S <= not phase_S;
		end if;
	end if;
end process;

process(clock_out_S)
begin
	if (rising_edge(clock_out_S)) then
		if phase_S='1' then
			data_out <= data_in(7 downto 0);
			kchar_out <= kchar_in(0);
			notintable_out <= notintable_in(0);
		else
			data_out <= data_in(15 downto 8);
			kchar_out <= kchar_in(1);
			notintable_out <= notintable_in(1);
		end if;
	end if;
end process;

end Behavioral;
