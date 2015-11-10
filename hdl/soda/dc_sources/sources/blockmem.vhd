----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   31-01-2012
-- Module Name:   blockmem
-- Description:   Generic memory block
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

------------------------------------------------------------------------------------------------------
-- blockmem
--		Generic memory block with separated addresses for reading and writing
--
--
-- generics
--    ADDRESS_BITS : Number of bits for the address
--    DATA_BITS : number of bits for data
--		
-- inputs
--		clock : clock 
--		write_enable : write to memory
--		write_address : address to write to
--		data_in : data to write into memory
--		read_address : address to read from
--			  
-- outputs
--		data_out : data from memory
--
-- components
--
------------------------------------------------------------------------------------------------------

entity blockmem is
	generic (
		ADDRESS_BITS : natural := 8;
		DATA_BITS  : natural := 18
		);
	port (
		clock                   : in  std_logic; 
		write_enable            : in std_logic;
		write_address           : in std_logic_vector(ADDRESS_BITS-1 downto 0);
		data_in                 : in std_logic_vector(DATA_BITS-1 downto 0);
		read_address            : in std_logic_vector(ADDRESS_BITS-1 downto 0);
		data_out                : out std_logic_vector(DATA_BITS-1 downto 0)
	);
end blockmem;

architecture behavioral of blockmem is
	type mem_type is array (2**ADDRESS_BITS-1 downto 0) of std_logic_vector (DATA_BITS-1 downto 0);
	signal mem_S : mem_type := (others => (others => '0'));
									 
begin

	process (clock)
	begin
		if (clock'event and clock = '1') then
			if (write_enable = '1') then
				mem_S(conv_integer(write_address)) <= data_in;
			end if;
			data_out <= mem_S(conv_integer(read_address));			
		end if;
	end process;
	

end architecture behavioral;