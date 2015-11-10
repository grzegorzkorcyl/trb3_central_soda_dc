----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   24-01-2014
-- Module Name:   DC_timeshift_lookuptable
-- Description:   Look Up Table for timestamp correction
-- Modifications:
--   11-09-2014   Name change from timeshift_lookuptable to DC_timeshift_lookuptable
--   18-09-2014   different clock for loading
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

------------------------------------------------------------------------------------------------------
-- DC_timeshift_lookuptable
--     Look Up Table for timestamp fraction.
--     Writing of LUT : make 'loading' input 1, LUT address will start at 0
--     On each write signal the next position in the LUT is written.
--
-- Library
--     work.FEE_LUT_package :  for default LUT value
--
-- generics
--     LUT_ADDRWIDTH : number of bits for Look Up Table addresses : LUT depth
--     LUT_DATAWIDTH : number of bits for Look Up Table data : LUT width
--		
-- inputs
--     clock : clock for reading
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
--     blockmem_dualclk : memory with different clock for writing and reading
--
--
------------------------------------------------------------------------------------------------------

entity DC_timeshift_lookuptable is
	generic (
		LUT_ADDRWIDTH : natural := 5;
		LUT_DATAWIDTH  : natural := 31
		);
	port ( 
		clock                   : in std_logic;
		load_clock              : in std_logic;
		loading                 : in std_logic;
		lut_write               : in std_logic;
		address                 : in std_logic_vector (LUT_ADDRWIDTH-1 downto 0);
		data_in                 : in std_logic_vector (LUT_DATAWIDTH-1 downto 0);
		data_out                : out std_logic_vector (LUT_DATAWIDTH-1 downto 0));
end DC_timeshift_lookuptable;

architecture behavioral of DC_timeshift_lookuptable is

type timeshift_correction_lut_type is array (0 to 2**LUT_ADDRWIDTH-1) 
			of std_logic_vector (lut_datawidth-1 downto 0);
signal lut_S                  : timeshift_correction_lut_type := (others => (others => '0'));
signal load_address_S         : std_logic_vector (LUT_ADDRWIDTH-1 downto 0);
signal loading_S              : std_logic;

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
		if (loading_S='0') then
			load_address_S <= (others => '0');
		elsif (lut_write='1') then
			load_address_S <= load_address_S+1;
		end if;
		loading_S <= loading;
	end if;
end process;

end architecture behavioral;
