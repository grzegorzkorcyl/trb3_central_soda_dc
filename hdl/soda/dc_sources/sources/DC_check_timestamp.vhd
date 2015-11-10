----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   27-02-2014
-- Module Name:   DC_check_timestamp
-- Description:   Checks pulse data on consistently increased timestamp and the skipped pulses 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;
USE work.panda_package.all;

----------------------------------------------------------------------------------
-- DC_check_timestamp
-- Checks the timestamp and timestamp fraction of hit-data and counts the number of skipped pulses;
-- The timestamps/superburst should be sorted. The errors are counted in a 32-bit register.
-- The input pulse data consists of the following items (parallel)
--        channel : adc-index
--        statusbyte : 8 bit status information
--        energy : pulse energy
--        timefraction : fraction part of the timestamp
--        timestamp : 32 bits timestamp, synchronised to master SODA clock
--        superburstnumber : 31 bits superburst number
--
-- Library
--     work.panda_package :  for type declarations and constants
-- 
-- Generics:
-- 
-- Inputs:
--     clock : clock for incoming data
--     reset : reset of all components
--     clear : clears the error counter
--     channel : adc-channel number of hit-data to be checked
--     statusbyte : 8 bits status of hit-data to be checked
--     energy : energy of hit-data to be checked
--     timefraction : fraction part of time of hit-data to be checked
--     timestamp : time within superburst of hit-data to be checked
--     superburstnumber : superburst of hit-data to be checked
--     pulse_data_write : write signal for the pulse_data
--     multiplexer_error : error in multiplexer : count as data error
-- 
-- Outputs:
--     timestamp_errors : number of timestamp errors occurred
--     skipped_pulses : number of pulses skipped in FEE
--     dataerrors : number of errors in data plus number of errors in multiplexer
-- 
-- Components:
--
----------------------------------------------------------------------------------

entity DC_check_timestamp is
	port ( 
		clock                   : in std_logic;
		reset                   : in std_logic;
		clear                   : in std_logic;
		channel                 : in std_logic_vector(15 downto 0);
		statusbyte              : in std_logic_vector(7 downto 0);
		energy                  : in std_logic_vector(15 downto 0);
		timefraction            : in std_logic_vector(11 downto 0);
		timestamp               : in std_logic_vector(15 downto 0);
		superburstnumber        : in std_logic_vector(30 downto 0);		
		pulse_data_write        : in std_logic;
		multiplexer_error       : in std_logic;
		timestamp_errors        : out std_logic_vector(9 downto 0);	
		skipped_pulses          : out std_logic_vector(9 downto 0);
		dataerrors              : out std_logic_vector(9 downto 0)
		);
end DC_check_timestamp;



architecture Behavioral of DC_check_timestamp is

signal clear_S                    : std_logic := '0';
signal statusbyte_S               : std_logic_vector(7 downto 0) := (others => '0');
signal superburstnumber_prev_S    : std_logic_vector(30 downto 0) := (others => '0');
signal timestamp_prev_S           : std_logic_vector(15 downto 0) := (others => '0');
signal timefraction_prev_S        : std_logic_vector(11 downto 0) := (others => '0');

signal timestampsmaller_S         : std_logic := '0';
signal timestampsmaller1_S        : std_logic := '0';

signal timestamp_errors_S         : std_logic_vector(9 downto 0) := (others => '0');
signal skipped_pulses_S           : std_logic_vector(9 downto 0) := (others => '0');
signal dataerrors_S               : std_logic_vector(9 downto 0) := (others => '0');

signal multiplexer_error_S        : std_logic := '0';
signal prev_multiplexer_error_S   : std_logic := '0';

-- attribute mark_debug : string;
-- attribute mark_debug of superburstnumber : signal is "true";
-- attribute mark_debug of timestamp : signal is "true";
-- attribute mark_debug of timefraction : signal is "true";
-- attribute mark_debug of pulse_data_write : signal is "true";
-- attribute mark_debug of timestampsmaller_S : signal is "true";
-- attribute mark_debug of timestampsmaller1_S : signal is "true";

begin
timestampsmaller1_S <= '1' when (timestampsmaller_S='1') and (pulse_data_write='1') else '0';
timestamp_errors <= timestamp_errors_S;
skipped_pulses <= skipped_pulses_S;
dataerrors <= dataerrors_S;

process(clock)
begin
	if (rising_edge(clock)) then 
		if (reset = '1') then
			clear_S <= '1';
		else
			clear_S <= clear;
		end if;
	end if;
end process;

timestampsmaller_S <= '1' when 
		(superburstnumber_prev_S>superburstnumber) or
		((superburstnumber_prev_S=superburstnumber) and (timestamp_prev_S>timestamp)) -- or
--		((superburstnumber_prev_S=superburstnumber) and (timestamp_prev_S=timestamp) and (timefraction_prev_S>timefraction))
	else '0';

process(clock)
begin
	if (rising_edge(clock)) then 
		if (clear_S='1') then
			timestamp_errors_S <= (others => '0');
		elsif (pulse_data_write = '1') then
			if timestampsmaller_S='1' then 
				if timestamp_errors_S/="1111111111" then
					timestamp_errors_S <= timestamp_errors_S+1;
				end if;
			end if;
			superburstnumber_prev_S <= superburstnumber;
			timestamp_prev_S <= timestamp;
			timefraction_prev_S <= timefraction;
		end if;
	end if;
end process;

process(clock)
begin
	if (rising_edge(clock)) then 
		if clear_S='1' then
			skipped_pulses_S <= (others => '0');
		elsif (pulse_data_write = '1') then
			if statusbyte(7)='1' then 
				if skipped_pulses_S/="1111111111" then
					skipped_pulses_S <= skipped_pulses_S+1;
				end if;
			end if;
		end if;
	end if;
end process;

process(clock)
begin
	if (rising_edge(clock)) then 
		if clear_S='1' then
			dataerrors_S <= (others => '0');
		elsif (multiplexer_error_S = '1') then
			if dataerrors_S/="1111111111" then
				dataerrors_S <= dataerrors_S+1;
			end if;
		end if;
		if (multiplexer_error='1') and (prev_multiplexer_error_S='0') then
			multiplexer_error_S <= '1';
		else
			multiplexer_error_S <= '0';
		end if;
		prev_multiplexer_error_S <= multiplexer_error;
	end if;
end process;


end Behavioral;
