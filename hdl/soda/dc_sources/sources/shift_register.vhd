----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   22-02-2009
-- Module Name:   shift_register 
-- Description:   Shifts data for an adjustable number of clock cycles
----------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

------------------------------------------------------------------------------------------------------
-- shift_register
--		Shifts data for an adjustable number of clock cycles
--
-- generics
--		width : number of bits for the data to shift
--		depthbits : number of bits for the number of clock cycles to shift
--		
-- inputs
--		clock : ADC sampling clock 
--		reset : synchrounous reset
--		hold : hold all values
--		data_in : data to shift
--		depth : number of clock cycles to shift for
--
-- outputs
--		data_out : shifted data
--
------------------------------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity shift_register is
	generic (
		width                   : natural := 16;
		depthbits               : natural := 9
		);
    port (
		clock                   : in  std_logic; 
		reset                   : in  std_logic; 
		hold                    : in  std_logic; 
		data_in                 : in std_logic_vector((width-1) downto 0); 
		depth                   : in std_logic_vector((depthbits-1) downto 0);
		data_out                : out  std_logic_vector((width-1) downto 0));
end shift_register;

architecture behavior of shift_register is

type arrtype is array((2**depthbits-1) downto 0) of std_logic_vector((width-1) downto 0);
signal mem : arrtype; -- := (others => (others => '0'));
signal outptr : std_logic_vector((depthbits-1) downto 0) := (others => '0');
signal mem_out : std_logic_vector((width-1) downto 0) := (others => '0');
signal lastreset : std_logic := '0';

attribute syn_ramstyle : string; 
attribute syn_ramstyle of mem : signal is "block_ram"; 

begin

data_out <= mem_out;
process (clock)
begin
	if rising_edge(clock) then
		if hold='0' then
			mem(conv_integer(unsigned(outptr + depth))) <= data_in;
			if reset = '1' then
				mem_out <= (others => '0');
				if lastreset='0' then 
					outptr <= (others => '0');
				else
					outptr <= outptr+1;
				end if;
			else
				mem_out <= mem(conv_integer(unsigned(outptr)));
				outptr <= outptr+1;
			end if;		
			lastreset <= reset;
		end if;
	end if;
end process;

end behavior;
