----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   25-02-2014
-- Module Name:   DC_pulse_cross_switch
-- Description:   Cross Switch to select which output should be connected to which input
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_ARITH.ALL;
use IEEE.std_logic_UNSIGNED.ALL;
USE work.panda_package.all;


------------------------------------------------------------------------------------------------------
-- DC_pulse_cross_switch
--	  Cross Switch to select which output should be connected to which input
--
--
-- generics
--     NROFMUXINPUTS : number of inputs and outputs
--     ADCINDEXSHIFT : ADC channel numbers lowest bit indicates the high or low gain ADC, 0=high, 1=low
--		
-- inputs
--		clock : clock 
--		pulse_data_in : array with 36-bits width pulse-data to be directed to selectable output
--		pulse_data_in_write : array with write for input pulse-data 
--		pulse_data_out_allowed : array with allow signals for pulse-data output
--		selections : select for each output where the input should come from
--			  
-- outputs
--		pulse_data_in_allowed : array with allow signals for pulse-data input
--		pulse_data_out : array with 36-bits width pulse-data directed from one input
--		pulse_data_out_write : array with write for output pulse-data 
--
-- components
--
------------------------------------------------------------------------------------------------------



entity DC_pulse_cross_switch is
	generic(
		NROFMUXINPUTS           : natural := 64;
		ADCINDEXSHIFT           : natural := 0
	);
    port ( 
		clock                   : in std_logic;
		pulse_data_in           : in array_fiberXadc36bits_type;
		pulse_data_in_write     : in std_logic_vector(0 to NROFMUXINPUTS-1);
		pulse_data_in_allowed   : out std_logic_vector(0 to NROFMUXINPUTS-1);
		pulse_data_out          : out array_fiberXadc36bits_type;
		pulse_data_out_write    : out std_logic_vector(0 to NROFMUXINPUTS-1);
		pulse_data_out_allowed  : in std_logic_vector(0 to NROFMUXINPUTS-1);
		selections              : in array_fiberXadcCrossSwitch_type;
		reverse_selections      : in array_fiberXadcCrossSwitch_type
	);	
end DC_pulse_cross_switch;


architecture Behavioral of DC_pulse_cross_switch is


type chooseADC_type is array(0 to NROFMUXINPUTS-1) of integer range 0 to NROFMUXINPUTS-1;
signal chooseADC_S               : chooseADC_type := (others => 0);
signal rev_chooseADC_S           : chooseADC_type := (others => 0); 


begin


process(clock)
begin
	if rising_edge(clock) then	
		for i in 0 to NROFMUXINPUTS-1 loop
			chooseADC_S(i) <= conv_integer(unsigned(selections(i)));
			rev_chooseADC_S(i) <= conv_integer(unsigned(reverse_selections(i)));
			-- for j in 0 to NROFMUXINPUTS-1 loop
				-- if conv_integer(unsigned(selections(j)))=i then
					-- rev_chooseADC_S(i) <= j; -- calculate the reverse number: input number that is connected to selected output
				-- end if;
			-- end loop;
		end loop;
	end if;
end process;

-- gen_selections: for i in 0 to NROFMUXINPUTS-1 generate
	-- pulse_data_out(i) <= pulse_data_in(chooseADC_S(i));
	-- pulse_data_out_write(i) <= pulse_data_in_write(chooseADC_S(i));
	-- pulse_data_in_allowed(i) <= pulse_data_out_allowed(rev_chooseADC_S(i));
-- end generate;

gen_selections: for i in 0 to NROFMUXINPUTS-1 generate
	pulse_data_out(i) <= pulse_data_in(i);
	pulse_data_out_write(i) <= pulse_data_in_write(i);
	pulse_data_in_allowed(i) <= pulse_data_out_allowed(i);
end generate;

end Behavioral;


