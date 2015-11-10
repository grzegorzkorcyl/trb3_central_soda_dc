
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;

entity data_readout_wrapper is
	generic (
		DO_SIMULATION : integer range 0 to 1		
	);
	port ( 
		RESET_IN : in std_logic;
		SYSCLK_IN : in std_logic;
		
		
		-- output to the transceiver
		TX_DATA_OUT : out std_logic_vector(7 downto 0);
		TX_DATA_VALID_OUT : out std_logic;
		TX_DATA_KCHAR_OUT : out std_logic;
		TX_SFP_MOD0_IN : in std_logic;
		TX_SFP_LOS_IN : in std_logic;
		
		
		
		

	);
end data_readout_wrapper;

architecture Behavioral of data_readout_wrapper is



begin

end Behavioral;


