----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   25-02-2014
-- Module Name:   DC_mux2to1
-- Description:   compare timestamp of two hits and pass data on in right order
-- Modifications:
--   30-07-2014   Timestamp is now the time within the superburst
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_ARITH.ALL;
use IEEE.std_logic_UNSIGNED.ALL;


------------------------------------------------------------------------------------------------------
-- DC_mux2to1
--    Compare timestamp of two hits and pass data on in right order.
--    If data from only one is available then this data is passed on directly
--    The data consists of the members of a hit :
--        fiber_index : index of the fiber from where the hit came from
--        channel : number of the ADC
--        statusbyte : 8 bits with status
--        energy : energy (top value) of a hit
--        timefraction : fractional part of the timestamp of a hit
--        timestamp : integer part of the timestamp of a hit within the superburst, unit: sample-clock cycles
--        superburstnumber : number of the superburst to which the hit belongs
--
--
-- generics
--     CF_FRACTIONBIT : number of valid constant fraction bits
--		
-- inputs
--    clock : ADC sampling clock 
--    reset : synchronous reset
--    fiber_index1 : index of the fiber
--    channel1 : data input 1 : adc channel
--    statusbyte1 : data input 1 : status
--    energy1 : data input 1 : pulse energy
--    timefraction1 : data input 1 : Constant Fraction time
--    timestamp1 : data input 1 : time
--    superburstnumber1 : data input 1 : superburst number
--    data1_in_write : write signal for data1_in
--    data1_in_inpipe : more data available: wait with timestamp check until the timestamp is read
--    fiber_index2 : index of the fiber
--    channel2 : data input 2 : adc channel
--    statusbyte2 : data input 2 : status
--    energy2 : data input 2 : pulse energy
--    timefraction2 : data input 2 : Constant Fraction time
--    timestamp2 : data input 2 : time
--    superburstnumber2 : data input 2 : superburst number
--    data2_in_write : write signal for data2_in
--    data2_in_inpipe : more data available: wait with timestamp check until the timestamp is read
--    data_out_allowed : writing of resulting data allowed
--			  
-- outputs
--    data1_in_allowed : signal to allow data input 1
--    data2_in_allowed : signal to allow data input 2
--    fiber_index : index of the fiber
--    channel : data output : adc channel
--    statusbyte : data output : status
--    energy : data output : pulse energy
--    timefraction : data output : Constant Fraction time
--    timestamp : data output : time
--    superburstnumber : data output : superburst number
--    data_out_write : write signal for 36-bits output data
--    data_out_inpipe : data available: in this module or at the input
--    error : error in data bits 35..32
--
-- components
--
------------------------------------------------------------------------------------------------------



entity DC_mux2to1 is
 	generic (
		CF_FRACTIONBIT          : natural := 11
	);
   port (
		clock                   : in std_logic;
		reset                   : in std_logic;
		fiber_index1            : in std_logic_vector(3 downto 0);
		channel1                : in std_logic_vector(15 downto 0);
		statusbyte1             : in std_logic_vector(7 downto 0);
		energy1                 : in std_logic_vector(15 downto 0);
		timefraction1           : in std_logic_vector(11 downto 0);
		timestamp1              : in std_logic_vector(15 downto 0);
		superburstnumber1       : in std_logic_vector(30 downto 0);
		data1_in_write          : in std_logic;
		data1_in_inpipe         : in std_logic;
		data1_in_allowed        : out std_logic;
		fiber_index2            : in std_logic_vector(3 downto 0);
		channel2                : in std_logic_vector(15 downto 0);
		statusbyte2             : in std_logic_vector(7 downto 0);
		energy2                 : in std_logic_vector(15 downto 0);
		timefraction2           : in std_logic_vector(11 downto 0);
		timestamp2              : in std_logic_vector(15 downto 0);
		superburstnumber2       : in std_logic_vector(30 downto 0);
		data2_in_write          : in std_logic;
		data2_in_inpipe         : in std_logic;
		data2_in_allowed        : out std_logic;
		fiber_index             : out std_logic_vector(3 downto 0);
		channel                 : out std_logic_vector(15 downto 0);
		statusbyte              : out std_logic_vector(7 downto 0);
		energy                  : out std_logic_vector(15 downto 0);
		timefraction            : out std_logic_vector(11 downto 0);
		timestamp               : out std_logic_vector(15 downto 0);
		superburstnumber        : out std_logic_vector(30 downto 0);
		data_out_write          : out std_logic;
		data_out_inpipe         : out std_logic;
		data_out_allowed        : in std_logic;
		error                   : out std_logic;
		testword0               : out std_logic_vector(35 downto 0) := (others => '0')
		);
end DC_mux2to1;


architecture Behavioral of DC_mux2to1 is

attribute syn_keep     : boolean;
attribute syn_preserve : boolean;

constant CHECK_FRACTIONTIME      : boolean := TRUE;
constant TIMEOUTBITS             : integer := 12;
signal timeout_counter_S         : std_logic_vector(TIMEOUTBITS-1 downto 0) := (others => '0');
signal clear_timeout_counter_S   : std_logic := '0';
signal inc_timeout_counter_S     : std_logic := '0';


		
signal error_S                   : std_logic;
signal data1_in_write_S          : std_logic;
signal data2_in_write_S          : std_logic;
signal data_out_write_S          : std_logic;
signal data1_in_inpipe_S         : std_logic;
signal data2_in_inpipe_S         : std_logic;
signal data_out_inpipe_S         : std_logic;
signal data1_in_allowed_S        : std_logic;
signal data2_in_allowed_S        : std_logic;
signal data_out_allowed_S        : std_logic;
signal data1_timestamp_valid_S   : std_logic := '0';
signal data2_timestamp_valid_S   : std_logic := '0';
signal timestamp_S               : std_logic_vector(15 downto 0) := (others => '0');
signal timefraction_S            : std_logic_vector(11 downto 0) := (others => '0');


signal outreg_filled_S           : std_logic := '0';

signal time1equalorlarger_S      : std_logic := '0';
signal time2equalorlarger_S      : std_logic := '0';

attribute syn_keep of data1_in_write_S     : signal is true;
attribute syn_preserve of data1_in_write_S : signal is true;
attribute syn_keep of data2_in_write_S     : signal is true;
attribute syn_preserve of data2_in_write_S : signal is true;
attribute syn_keep of data_out_write_S     : signal is true;
attribute syn_preserve of data_out_write_S : signal is true;

attribute syn_keep of data1_in_inpipe_S     : signal is true;
attribute syn_preserve of data1_in_inpipe_S : signal is true;
attribute syn_keep of data2_in_inpipe_S     : signal is true;
attribute syn_preserve of data2_in_inpipe_S : signal is true;
attribute syn_keep of data_out_inpipe_S     : signal is true;
attribute syn_preserve of data_out_inpipe_S : signal is true;

attribute syn_keep of data1_in_allowed_S     : signal is true;
attribute syn_preserve of data1_in_allowed_S : signal is true;
attribute syn_keep of data2_in_allowed_S     : signal is true;
attribute syn_preserve of data2_in_allowed_S : signal is true;
attribute syn_keep of data_out_allowed_S     : signal is true;
attribute syn_preserve of data_out_allowed_S : signal is true;


begin

data1_in_allowed <= data1_in_allowed_S;
data2_in_allowed <= data2_in_allowed_S;
data_out_allowed_S <= data_out_allowed;
data1_in_write_S <= data1_in_write;
data2_in_write_S <= data2_in_write;
data_out_write <= data_out_write_S;
data1_in_inpipe_S <= data1_in_inpipe;
data2_in_inpipe_S <= data2_in_inpipe;
data_out_inpipe <= data_out_inpipe_S;

error <= error_S;
timestamp <= timestamp_S;
timefraction <= timefraction_S;

data_out_write_S <= '1' when (outreg_filled_S='1') and (data_out_allowed_S='1') else '0';

data_out_inpipe_S <= '1' when 
		(data1_in_inpipe_S='1') or (data2_in_inpipe_S='1')  or
		(outreg_filled_S='1') 
	else '0';
	
--data1_in_allowed_S <= '1' when
--		((data_out_allowed_S='1') or (outreg_filled_S='0')) and
--		(data1_timestamp_valid_S='1')
--	else '0';
data1_in_allowed_S <= '1' when
		(outreg_filled_S='0') and
		(data1_timestamp_valid_S='1')
	else '0';

	
--data2_in_allowed_S <= '1' when
--		((data_out_allowed_S='1') or (outreg_filled_S='0')) and
--		(data2_timestamp_valid_S='1') and
--		(data1_in_write_S='0')
--	else '0';
data2_in_allowed_S <= '1' when
		(outreg_filled_S='0') and
		(data2_timestamp_valid_S='1') and
		(data1_in_write_S='0')
	else '0';


gencomparetimeCF: if CHECK_FRACTIONTIME generate
	time1equalorlarger_S <= '1' when 
			(superburstnumber1>superburstnumber2) or
			((superburstnumber1=superburstnumber2) and 
				(timestamp1 & timefraction1(CF_FRACTIONBIT-1 downto 0)>=timestamp2 & timefraction2(CF_FRACTIONBIT-1 downto 0)))
		else '0';
	time2equalorlarger_S <= '1' when 
			(superburstnumber2>superburstnumber1) or
			((superburstnumber2=superburstnumber1) and 
				(timestamp2 & timefraction2(CF_FRACTIONBIT-1 downto 0)>=timestamp1 & timefraction1(CF_FRACTIONBIT-1 downto 0)))
		else '0';
end generate;
gencomparetime: if not CHECK_FRACTIONTIME generate
	time1equalorlarger_S <= '1' when 
			(superburstnumber1>superburstnumber2) or
			((superburstnumber1=superburstnumber2) and 
				(timestamp1>=timestamp2))
		else '0';
	time2equalorlarger_S <= '1' when 
			(superburstnumber2>superburstnumber1) or
			((superburstnumber2=superburstnumber1) and 
				(timestamp2>=timestamp1))
		else '0';
end generate;


data1_timestamp_valid_S <= '1' when -- when timestamp1<=timestamp2
		((time2equalorlarger_S='1') and (data1_in_inpipe_S='1')) or 
		(data2_in_inpipe_S='0') 
	else '0';
data2_timestamp_valid_S <= '1' when -- when timestamp2<=timestamp1
		((time1equalorlarger_S='1') and (data2_in_inpipe_S='1')) or
		(data1_in_inpipe_S='0') 
	else '0';

process(clock)
begin
	if rising_edge(clock) then	
		clear_timeout_counter_S <= '0';
		inc_timeout_counter_S <= '0';
		if reset='1' then
			error_S <= '0';
			timestamp_S <= (others => '0');
			timefraction_S <= (others => '0');
		else
			if data1_in_write_S='1' then
				clear_timeout_counter_S <= '1';
				fiber_index <= fiber_index1;
				channel <= channel1;
				statusbyte <= statusbyte1;
				energy <= energy1;
				timefraction_S <= timefraction1;
				timestamp_S <= timestamp1;
				superburstnumber <= superburstnumber1;
				outreg_filled_S <= '1';
				error_S <= '0';
			elsif data2_in_write_S='1' then
				clear_timeout_counter_S <= '1';
				fiber_index <= fiber_index2;
				channel <= channel2;
				statusbyte <= statusbyte2;
				energy <= energy2;
				timefraction_S <= timefraction2;
				timestamp_S <= timestamp2;
				superburstnumber <= superburstnumber2;
				outreg_filled_S <= '1';
				error_S <= '0';
			else
				if data_out_write_S='1' then
					outreg_filled_S <= '0';
					clear_timeout_counter_S <= '1';
				elsif outreg_filled_S='1' then
					if timeout_counter_S(TIMEOUTBITS-1)='1' then
						error_S <= '1';
						outreg_filled_S <= '0';
					else
						inc_timeout_counter_S <= '1';
					end if;
				else
					clear_timeout_counter_S <= '1';
				end if;
			end if;
		end if;
	end if;
end process;


process(clock)
begin
	if rising_edge(clock) then	
		if (reset='1') or (clear_timeout_counter_S='1') then
			timeout_counter_S <= (others => '0');
		elsif inc_timeout_counter_S='1' then
			timeout_counter_S <= timeout_counter_S+1;
		end if;
	end if;
end process;

testword0(35 downto 0) <= (others => '0');


end Behavioral;


