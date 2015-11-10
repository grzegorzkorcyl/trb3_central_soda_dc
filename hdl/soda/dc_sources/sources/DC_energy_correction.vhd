----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   14-03-2014
-- Module Name:   DC_energy_correction
-- Description:   Look Up Table for energy correction
-- Modifications:
--   18-09-2014   different clock for loading
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;
USE work.panda_package.all;

------------------------------------------------------------------------------------------------------
-- DC_energy_correction
--     Look Up Table 
--     Energy correction with offset and linair gain factor in Look Up Table for each ADC (address). 
--     Writing of LUT : make loading input 1, LUT address will start at 0
--     On each write signal the next position in the LUT is written.
--     The data in the LUT: bits 15..0 : gain correction, bits 30..16 : offset correction
--     The offset is signed (15 bits), the output is clipped between 0 and 65535
--     The equation: energy = ((original_energy+offset) * gainfactor)>>scalingbits
--     with gainfactor scaled by scaling bits: if the requested gainfactor is 4 and SCALINGBITS=13, then the gainfactor is 32768 (4*2^13)
--     
--
-- Library
--     work.panda_package :  for type declarations and constants
--
-- generics
--     SCALINGBITS : number of bits for scaling the gain correction
--     LUT_ADDRWIDTH : number of bits for Look Up Table addresses : LUT depth
--     LUT_DATAWIDTH : number of bits for Look Up Table data : LUT width
--		
-- inputs
--     clock : clock
--     loading : mode loading new LUT data, 0 means start next on position 0
--     lut_write : write signal for writing new data to LUT, on each write the next index is selected
--     address : index of LUT : gives corresponding value on data_out
--     data_in : new data for LUT : bit15..0=gainfactor(>>scalingbits), bit30..16=offset
--     energy_in : energy input
--		
-- outputs
--     energy_out : corrected energy:  energy = ((original_energy+offset) * gainfactor)>>scalingbits
--
-- components
--
--
------------------------------------------------------------------------------------------------------

entity DC_energy_correction is
	generic (
		SCALINGBITS : natural := 13;
		LUT_ADDRWIDTH : natural := 5;
		LUT_DATAWIDTH  : natural := 30
		);
	port ( 
		clock                   : in std_logic;
		load_clock              : in std_logic;
		loading                 : in std_logic;
		lut_write               : in std_logic;
		address                 : in std_logic_vector (LUT_ADDRWIDTH-1 downto 0);
		data_in                 : in std_logic_vector (LUT_DATAWIDTH-1 downto 0);
		energy_in               : in std_logic_vector (15 downto 0);
		energy_out              : out std_logic_vector (15 downto 0));
end DC_energy_correction;

architecture behavioral of DC_energy_correction is

constant ZEROS                : std_logic_vector (311 downto 0) := (others => '0');
type energy_correction_lut_type is array (0 to 2**LUT_ADDRWIDTH-1) 
			of std_logic_vector (LUT_DATAWIDTH-1 downto 0);
signal lut_S                  : energy_correction_lut_type := (others => (others => '0'));
signal data_out_S             : std_logic_vector (LUT_DATAWIDTH-1 downto 0);
signal load_address_S         : std_logic_vector (LUT_ADDRWIDTH-1 downto 0);
signal loading_S              : std_logic;
signal energy_corrected_S     : std_logic_vector (31 downto 0);

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
		data_out_S <= lut_S(conv_integer(address));
	end if;
end process;

process (load_clock)
begin
	if (rising_edge(load_clock)) then 
		if loading_S='0' then
			load_address_S <= (others => '0');
		else
			if (lut_write='1') then
				load_address_S <= load_address_S+1;
			end if;
		end if;
		loading_S <= loading;
	end if;
end process;

process (clock)
variable energy_V : integer range -65536 to 65535;
variable energy_offsetted_V : std_logic_vector(15 downto 0);
begin
	if (rising_edge(clock)) then 
		energy_V := conv_integer(signed(energy_in)) + conv_integer(signed(data_out_S(30 downto 16)));
		if energy_V<0 then
			energy_offsetted_V := (others => '0');
		else
			energy_offsetted_V := conv_std_logic_vector(energy_V,16);
		end if;
		energy_corrected_S <= energy_offsetted_V * data_out_S(15 downto 0);
	end if;
end process;

energy_out <= energy_corrected_S(SCALINGBITS+15 downto SCALINGBITS) 
		when energy_corrected_S(31 downto SCALINGBITS+16) = ZEROS(31 downto SCALINGBITS+16)
	else (others => '1');

end architecture behavioral;
