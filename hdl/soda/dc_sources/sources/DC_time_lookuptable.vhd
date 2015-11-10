----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   08-05-2012
-- Module Name:   DC_time_lookuptable
-- Description:   Look Up Table with default value for timestamp fraction correction
-- Modifications:
--   11-09-2014   Name change from time_lookuptable to DC_time_lookuptable
--   18-09-2014   different clock for loading
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.DC_LUT_package.all;

------------------------------------------------------------------------------------------------------
-- DC_time_lookuptable
--     Look Up Table with default value for timestamp fraction.
--     Look Up Table can be written with different values
--
-- Library
--     work.FEE_LUT_package :  for default LUT value
--
-- generics
--     LUT_ADDRWIDTH : number of bits for Look Up Table addresses : LUT depth
--     LUT_DATAWIDTH : number of bits for Look Up Table data : LUT width
--		
-- inputs
--     clock : clock
--     load_clock : clock for loading
--     loading : mode loading new LUT data, 0 means start next on position 0
--     lut_write : write signal for writing new data to LUT, on each write the next index is selected
--     address : index of LUT : gives corresponding value on data_out
--     data_in : new data for LUT
--		
-- outputs
--     data_out : resulting data
--
-- components
--
--
------------------------------------------------------------------------------------------------------

entity DC_time_lookuptable is
	generic (
		lut_addrwidth : natural := 11;
		lut_datawidth  : natural := 11
		);
	port ( 
		clock                   : in std_logic;
		load_clock              : in std_logic;
		loading                 : in std_logic;
		lut_write               : in std_logic;
		address                 : in std_logic_vector (lut_addrwidth-1 downto 0);
		data_in                 : in std_logic_vector (lut_datawidth-1 downto 0);
		data_out                : out std_logic_vector (lut_datawidth-1 downto 0));
end DC_time_lookuptable;

architecture behavioral of DC_time_lookuptable is

signal lut_S                  : time_correction_lut_type := DEFAULTTIMECORRLUT;
signal load_address_S         : std_logic_vector (lut_addrwidth-1 downto 0);
signal loading0_S             : std_logic;
signal loading1_S             : std_logic;

begin


process(load_clock)
begin
	if (rising_edge(load_clock)) then 
		if (lut_write = '1') then
			lut_S(conv_integer(load_address_S)) <= data_in;
		end if;
	end if;
end process;

process(clock)
begin
	if (rising_edge(clock)) then
		data_out <= lut_S(conv_integer(address));
	end if;
end process;


process (load_clock)
begin
	if (rising_edge(load_clock)) then 
		if (loading0_S='1') and (loading1_S='0') then
			load_address_S <= (others => '0');
		elsif (lut_write='1') and (loading1_S='1') then
			load_address_S <= load_address_S+1;
		end if;
		loading1_S <= loading0_S;
		loading0_S <= loading;
	end if;
end process;


end architecture behavioral;
