----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   06-02-2015
-- Module Name:   DC_data8to16
-- Description:   Converts 8 bits data at 200MHz to 16 bits data at 100MHz
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
-- DC_data8to16
-- Converts 8 bits data at 200MHz to 16 bits data at 100MHz
--
-- Library
-- 
-- Generics:
-- 
-- Inputs:
--     clock_in : input clock
--     data_in : 8 bits input data
--     kchar_in : corresponding k-character
-- 
-- Outputs:
--     clock_out : output clock at half speed
--     data_out : 16 bits output data at half speed
--     kchar_out : corresponding k-character (one for each byte)
-- 
-- Components:
--
----------------------------------------------------------------------------------

entity DC_data8to16 is
	port ( 
		clock_in                : in std_logic;
		data_in                 : in std_logic_vector(7 downto 0);
		kchar_in                : in std_logic;
		clock_out               : in std_logic;
		data_out                : out std_logic_vector(15 downto 0);
		kchar_out               : out std_logic_vector(1 downto 0)
	);
end DC_data8to16;

architecture Behavioral of DC_data8to16 is

signal clock_in_S               : std_logic;
signal data_in0_S               : std_logic_vector(7 downto 0);
signal kchar_in0_S              : std_logic;
signal data_in1_S               : std_logic_vector(7 downto 0);
signal kchar_in1_S              : std_logic;
signal data_out_S               : std_logic_vector(15 downto 0);
signal kchar_out_S              : std_logic_vector(1 downto 0);

begin

clock_in_S <= clock_in;

	
process(clock_in_S)
begin
	if (rising_edge(clock_in_S)) then
		data_in0_S <= data_in;
		kchar_in0_S <= kchar_in;
		data_in1_S <= data_in0_S;
		kchar_in1_S <= kchar_in0_S;
	end if;
end process;

process(clock_out)
begin
	if (rising_edge(clock_out)) then
		data_out_S <= data_in0_S & data_in1_S;
		kchar_out_S <= kchar_in0_S & kchar_in1_S;
		data_out <= data_out_S;
		kchar_out <= kchar_out_S;
	end if;
end process;

end Behavioral;
