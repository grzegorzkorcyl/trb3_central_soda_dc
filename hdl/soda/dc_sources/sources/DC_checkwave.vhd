----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   16-06-2012
-- Module Name:   DC_checkwave
-- Description:   Checks waveform data
-- Modifications:
--    16-09-2014: name changed from MUX_checkwave to DC_checkwave
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;
USE work.panda_package.all;

------------------------	----------------------------------------------------------
-- DC_checkwave
-- Checks waveform data
--
-- Input data:
--        	bits(35..32)="0000" : bits(31..0)=timestamp of maximum value in waveform
--        	bits(35..32)="0001" : bits(31..24)=00 bits(23..0)=SuperBurst number
--        	bits(35..32)="0010" : 
--              bits(31..24) = statusbyte (bit6=overflow) 
--              bits(23..16) = 00
--              bits(15..0) = adcnumber (channel identification)
--        	bits(35..32)="0011" : bits(31..16)=adc sample, bits(15..0)=next adc sample
--        	bits(35..32)="0100" : bits(31..16)=last adc sample, bits(15..0)=0
--        	bits(35..32)="0101" : bits(31..16)=last but one adc sample, bits(15..0)=last adc sample
--        	bits(35..32)="1111" : error: buffer full, waveform not valid
--
-- 
--
--
--
-- Library:
--     work.panda_package: types and constants
--
-- Generics:
--
-- Inputs:
--     clock : clock for input and output data
--     reset : reset
--     wave_in : waveform input data, 36-bits stream
--        	bits(35..32)="0000" : bits(31..0)=timestamp of maximum value in waveform
--        	bits(35..32)="0001" : bits(31..24)=00 bits(23..0)=SuperBurst number
--        	bits(35..32)="0010" : 
--              bits(31..24) = statusbyte (bit6=overflow) 
--              bits(23..16) = 00
--              bits(15..0) = adcnumber (channel identification)
--        	bits(35..32)="0011" : bits(31..16)=adc sample, bits(15..0)=next adc sample
--        	bits(35..32)="0100" : bits(31..16)=last adc sample, bits(15..0)=0
--        	bits(35..32)="0101" : bits(31..16)=last but one adc sample, bits(15..0)=last adc sample
--        	bits(35..32)="1111" : error: buffer full, waveform not valid
--     wave_in_write : waveform data is availabe
-- 
-- Outputs:
--     error : error
-- 
-- Components:
--
----------------------------------------------------------------------------------

entity DC_checkwave is
    Port ( 
		clock                   : in std_logic;
		reset                   : in std_logic;
		wave_in                 : in std_logic_vector(35 downto 0);
		wave_in_write           : in std_logic;
		error                   : out std_logic
	);    
end DC_checkwave;


architecture Behavioral of DC_checkwave is

signal wave_prev_S                : std_logic_vector(3 downto 0) := "0100";
signal error_S                    : std_logic := '0';

begin

error <= error_S;


writeprocess: process(clock)
begin
	if (rising_edge(clock)) then 
		if (reset = '1') then 
			wave_prev_S <= "0100";
			error_S <= '0';
		else
			if wave_in_write='1' then
				case wave_prev_S is
					when "0000"  =>
						if wave_in(35 downto 32)="0001" then
							error_S <= '0';
						else
							error_S <= '1';
						end if;
					when "0001" => 
						if wave_in(35 downto 32)="0010" then
							error_S <= '0';
						else
							error_S <= '1';
						end if;
					when "0010" => 
						if wave_in(35 downto 32)="0011" then
							error_S <= '0';
						else
							error_S <= '1';
						end if;
					when "0011" => 
						if (wave_in(35 downto 32)="0011") or (wave_in(35 downto 32)="0101") or (wave_in(35 downto 32)="0100") then
							error_S <= '0';
						else
							error_S <= '1';
						end if;
					when "0100" => 
						if (wave_in(35 downto 32)="0000") then
							error_S <= '0';
						else
							error_S <= '1';
						end if;
					when "0101" => 
						if (wave_in(35 downto 32)="0000") then
							error_S <= '0';
						else
							error_S <= '1';
						end if;
					when others => 
						error_S <= '1';
				end case;
				wave_prev_S <= wave_in(35 downto 32);
			end if;
		end if;
	end if;
end process;





end Behavioral;

