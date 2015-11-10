----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   15-09-2015
-- Module Name:   DC_wavemux2to1
-- Description:   compare timestamp of 36bits data pass on first
-- Modifications:
--    25-09-2015: compare bug fixed at FFFF->0000 superburst change
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_ARITH.ALL;
use IEEE.std_logic_UNSIGNED.ALL;

------------------------------------------------------------------------------------------------------
-- DC_wavemux2to1
--	   Compare timestamp of 36bits data and pass on first
--    Timestamp is a combination of the superburst and a clockcounter
--    If data from only one is available then this is passed on directly
--    The 36-bits data contains waveforms in packets, starting with timestamp, ending with last sample:
--        	bits(35..32)="0000" : bits(31 downto 16)=Superburstnumber(15..0), bits(15..0)=timestamp of waveform within superburst
--        	bits(35..32)="0001" : bits(31)=0 bits(30..0)=SuperBurst number
--        	bits(35..32)="0010" : 
--              bits(31..24) = statusbyte (bit6=overflow) 
--              bits(23..16) = 00
--              bits(15..0) = adcnumber (channel identifaction)
--        	bits(35..32)="0011" : bits(31..16)=adc sample, bits(15..0)=next adc sample
--        	bits(35..32)="0100" : bits(31..16)=last adc sample, bits(15..0)=0
--        	bits(35..32)="0101" : bits(31..16)=last but one adc sample, bits(15..0)=last adc sample
--        	bits(35..32)="1111" : error: buffer full, waveform not valid
--
--
-- generics
--		
-- inputs
--		clock : ADC sampling clock 
--		reset : synchrounous reset
--		data1_in : data from first 36-bits input
--        	bits(35..32)="0000" : bits(31 downto 16)=Superburstnumber(15..0), bits(15..0)=timestamp of waveform within superburst
--        	bits(35..32)="0001" : bits(31)=0 bits(30..0)=SuperBurst number
--        	bits(35..32)="0010" : 
--              bits(31..24) = statusbyte (bit6=overflow) 
--              bits(23..16) = 00
--              bits(15..0) = adcnumber (channel identifaction)
--        	bits(35..32)="0011" : bits(31..16)=adc sample, bits(15..0)=next adc sample
--        	bits(35..32)="0100" : bits(31..16)=last adc sample, bits(15..0)=0
--        	bits(35..32)="0101" : bits(31..16)=last but one adc sample, bits(15..0)=last adc sample
--        	bits(35..32)="1111" : error: buffer full, waveform not valid
--    data1_in_write : write signal for data1_in
--    data1_in_available : more data available: wait with timestamp check until the timestamp is read
--		data2_in : data from second 36-bits input
--        	bits(35..32)="0000" : bits(31 downto 16)=Superburstnumber(15..0), bits(15..0)=timestamp of waveform within superburst
--        	bits(35..32)="0001" : bits(31)=0 bits(30..0)=SuperBurst number
--        	bits(35..32)="0010" : 
--              bits(31..24) = statusbyte (bit6=overflow) 
--              bits(23..16) = 00
--              bits(15..0) = adcnumber (channel identifaction)
--        	bits(35..32)="0011" : bits(31..16)=adc sample, bits(15..0)=next adc sample
--        	bits(35..32)="0100" : bits(31..16)=last adc sample, bits(15..0)=0
--        	bits(35..32)="0101" : bits(31..16)=last but one adc sample, bits(15..0)=last adc sample
--        	bits(35..32)="1111" : error: buffer full, waveform not valid
--    data2_in_write : write signal for data2_in
--    data2_in_available : more data available: wait with timestamp check until the timestamp is read
--		data_out_allowed : writing of resulting data allowed
--			  
-- outputs
--		data1_in_allowed : signal to allow data input 1
--		data2_in_allowed : signal to allow data input 2
--		data_out : 36-bits data with valid pulse waveform:
--        	bits(35..32)="0000" : bits(31 downto 16)=Superburstnumber(15..0), bits(15..0)=timestamp of waveform within superburst
--        	bits(35..32)="0001" : 
--              bits(31..24) = statusbyte (bit6=overflow) 
--              bits(23..8) = 0
--              bits(7..0) = adcnumber (channel identifaction)
--        	bits(35..32)="0010" : bits(31..16)=adc sample, bits(15..0)=next adc sample
--        	bits(35..32)="0100" : bits(31..16)=last adc sample, bits(15..0)=0
--        	bits(35..32)="0101" : bits(31..16)=last but one adc sample, bits(15..0)=last adc sample
--		data_out_write : write signal for 36-bits output data
--    data_out_available : data available: in this module or at the input
--    error : error in data bits 35..32
--
-- components
--
------------------------------------------------------------------------------------------------------



entity DC_wavemux2to1 is
	generic(
		TIMEOUTBITS             : natural := 6
	);
	Port (
		clock                   : in std_logic;
		reset                   : in std_logic;
		data1_in                : in std_logic_vector(35 downto 0); 
		data1_in_write          : in std_logic;
		data1_in_available      : in std_logic;
		data1_in_allowed        : out std_logic;
		data2_in                : in std_logic_vector(35 downto 0); 
		data2_in_write          : in std_logic;
		data2_in_available      : in std_logic;
		data2_in_allowed        : out std_logic;
		data_out                : out std_logic_vector(35 downto 0);
		data_out_write          : out std_logic;
		data_out_available      : out std_logic;
		data_out_allowed        : in std_logic;
		error                   : out std_logic;
		testword0               : out std_logic_vector(35 downto 0)
	);
end DC_wavemux2to1;


architecture Behavioral of DC_wavemux2to1 is

signal timeout_counter_S         : std_logic_vector(TIMEOUTBITS-1 downto 0) := (others => '0');

signal error_S                   : std_logic := '0';
signal read_pulse1_S             : std_logic := '0';
signal read_pulse2_S             : std_logic := '0';
signal data1_in_allowed_S        : std_logic := '0';
signal data2_in_allowed_S        : std_logic := '0';
signal data1_in_write_S          : std_logic := '0';
signal data2_in_write_S          : std_logic := '0';
signal data_out_trywrite_S       : std_logic := '0';
signal data_out_write_S          : std_logic := '0';
signal data_out_available_S      : std_logic := '0';
signal data_out_S                : std_logic_vector(35 downto 0) := (others => '0');
signal data1_timestamp_valid_S   : std_logic := '0';
signal data2_timestamp_valid_S   : std_logic := '0';

begin

error <= error_S;

data_out_available <= data_out_available_S;
data_out_available_S <= '1' when (data1_in_available='1') or (data2_in_available='1') 
		or (data_out_trywrite_S='1') 
		or (data1_timestamp_valid_S='1') or (data2_timestamp_valid_S='1')
	else '0';

data_out <= data_out_S;
data_out_write <= data_out_write_S;
data_out_write_S <= '1' when (data_out_trywrite_S='1') and (data_out_allowed='1') else '0';

data1_in_allowed <= data1_in_allowed_S;
data1_in_allowed_S <= '1' when (data_out_allowed='1')
	and ((read_pulse1_S='1') 
		or ((read_pulse1_S='0') and (read_pulse2_S='0') and (data1_timestamp_valid_S='0')))
	else '0';

data2_in_allowed <= data2_in_allowed_S;
data2_in_allowed_S <= '1' when (data_out_allowed='1')
	and ((read_pulse2_S='1') 
		or ((read_pulse1_S='0') and (read_pulse2_S='0') and (data2_timestamp_valid_S='0')))
	else '0';

--data2_in_allowed_S <= '1' when (data_out_allowed='1')
--	and ((read_pulse2_S='1') 
--		or (((read_pulse1_S='0') and (data1_timestamp_valid_S='0')) 
--			and ((read_pulse2_S='0') and (data2_timestamp_valid_S='0'))))
--	else '0';

data1_in_write_S <= '1' when (data1_in_write='1') and (data1_in_allowed_S='1') else '0';
data2_in_write_S <= '1' when (data2_in_write='1') and (data2_in_allowed_S='1') else '0';

readprocess: process(clock)
variable data1_timestamp_V       : std_logic_vector(31 downto 0) := (others => '0');
variable data2_timestamp_V       : std_logic_vector(31 downto 0) := (others => '0');
variable data1_timestamp_valid_V : std_logic := '0';
variable data2_timestamp_valid_V : std_logic := '0';
begin
	if rising_edge(clock) then
		if reset='1' then
			data_out_trywrite_S <= '0';
			read_pulse1_S <= '0';
			read_pulse2_S <= '0';
			data1_timestamp_valid_V := '0';
			data2_timestamp_valid_V := '0';
			data1_timestamp_valid_S <= '0';
			data2_timestamp_valid_S <= '0';
			timeout_counter_S <= (others => '0');
		else
			if (data_out_trywrite_S='1') and (data_out_write_S='0') then -- unsuccesful write
				data_out_trywrite_S <= '1'; -- try again
				timeout_counter_S <= (others => '0');
			else
				if read_pulse1_S='1' then
					data1_timestamp_valid_V := '0';
					if data1_in_write_S='1' then
						timeout_counter_S <= (others => '0');
						if (data1_in(35 downto 32)="0001") or (data1_in(35 downto 32)="0010") or (data1_in(35 downto 32)="0011")  then -- next data
							error_S <= '0';
							data_out_S <= data1_in;
							data_out_trywrite_S <= '1';
						elsif (data1_in(35 downto 33)="010") then -- last data
							error_S <= '0';
							data_out_S <= data1_in;
							read_pulse1_S <= '0';
							data_out_trywrite_S <= '1';
						else -- error
							error_S <= '1';
							read_pulse1_S <= '0';
							read_pulse2_S <= '0';
							data1_timestamp_valid_V := '0';
							data2_timestamp_valid_V := '0';
							data_out_trywrite_S <= '0';
						end if;
					else
						data_out_trywrite_S <= '0';
						if timeout_counter_S(TIMEOUTBITS-1)='1' then
							data_out_S <= "0100" & x"00000000"; -- force last data
							data_out_trywrite_S <= '1';
							error_S <= '1';
							read_pulse1_S <= '0';
							read_pulse2_S <= '0';
							data1_timestamp_valid_V := '0';
							data2_timestamp_valid_V := '0';
							timeout_counter_S <= (others => '0');
						else
							if data_out_allowed='1' then
								if data_out_write_S='1' then
									timeout_counter_S <= (others => '0');
								else
									timeout_counter_S <= timeout_counter_S+1;
								end if;
							end if;
							error_S <= '0';
						end if;
					end if;
				elsif read_pulse2_S='1' then
					data2_timestamp_valid_V := '0';
					if data2_in_write_S='1' then
						timeout_counter_S <= (others => '0');
						if (data2_in(35 downto 32)="0001") or (data2_in(35 downto 32)="0010") or (data2_in(35 downto 32)="0011")  then -- next data
							error_S <= '0';
							data_out_S <= data2_in;
							data_out_trywrite_S <= '1';
						elsif (data2_in(35 downto 33)="010") then -- last data
							error_S <= '0';
							data_out_S <= data2_in;
							read_pulse2_S <= '0';
							data_out_trywrite_S <= '1';
						else -- error
							error_S <= '1';
							read_pulse1_S <= '0';
							read_pulse2_S <= '0';
							data1_timestamp_valid_V := '0';
							data2_timestamp_valid_V := '0';
							data_out_trywrite_S <= '0';
						end if;
					else
						data_out_trywrite_S <= '0';
						if timeout_counter_S(TIMEOUTBITS-1)='1' then
							data_out_S <= "0100" & x"00000000"; -- force last data
							data_out_trywrite_S <= '1';
							error_S <= '1';
							read_pulse1_S <= '0';
							read_pulse2_S <= '0';
							data1_timestamp_valid_V := '0';
							data2_timestamp_valid_V := '0';
							timeout_counter_S <= (others => '0');
						else
							if data_out_allowed='1' then
								if data_out_write_S='1' then
									timeout_counter_S <= (others => '0');
								else
									timeout_counter_S <= timeout_counter_S+1;
								end if;
							end if;
							error_S <= '0';
						end if;
					end if;
				else
					timeout_counter_S <= (others => '0');
					if data1_in_write_S='1' then
						if (data1_in(35 downto 32)="0000") then
							data1_timestamp_V := data1_in(31 downto 0);
							data1_timestamp_valid_V := '1';
						else -- error
							error_S <= '1';
							read_pulse1_S <= '0';
							read_pulse2_S <= '0';
							data1_timestamp_valid_V := '0';
							data2_timestamp_valid_V := '0';
						end if;
					end if;
					if data2_in_write_S='1' then
						if (data2_in(35 downto 32)="0000") then
							data2_timestamp_V := data2_in(31 downto 0);
							data2_timestamp_valid_V := '1';
						else -- error
							error_S <= '1';
							read_pulse1_S <= '0';
							read_pulse2_S <= '0';
							data1_timestamp_valid_V := '0';
							data2_timestamp_valid_V := '0';
						end if;
					end if;
					if data1_timestamp_valid_V='1' then
						if data2_timestamp_valid_V='1' then
							if ((data1_timestamp_V(31 downto 0)<data2_timestamp_V(31 downto 0)) -- select 1
									or (((data1_timestamp_V(31 downto 30)="11") and (data2_timestamp_V(31 downto 30)="00")))) 
										and (not ((data1_timestamp_V(31 downto 30)="00") and (data2_timestamp_V(31 downto 30)="11"))) then
								read_pulse1_S <= '1';
								data1_timestamp_valid_V := '0';
								data_out_trywrite_S <= '1';						
								data_out_S <= "0000" & data1_timestamp_V;
							else -- select 2
								read_pulse2_S <= '1';
								data2_timestamp_valid_V := '0';
								data_out_trywrite_S <= '1';						
								data_out_S <= "0000" & data2_timestamp_V;
							end if;
						elsif data2_in_available='1' then -- data expected: wait
							data_out_trywrite_S <= '0';
						else -- write 1
							read_pulse1_S <= '1';
							data1_timestamp_valid_V := '0';
							data_out_trywrite_S <= '1';						
							data_out_S <= "0000" & data1_timestamp_V;							
						end if;
					elsif data2_timestamp_valid_V='1' then
						if data1_in_available='1' then -- data expected: wait
							data_out_trywrite_S <= '0';
						else -- write 2
							read_pulse2_S <= '1';
							data2_timestamp_valid_V := '0';
							data_out_trywrite_S <= '1';						
							data_out_S <= "0000" & data2_timestamp_V;							
						end if;
					else -- no valid timestamps
						data_out_trywrite_S <= '0';
					end if;
				end if;					
				data1_timestamp_valid_S <= data1_timestamp_valid_V;
				data2_timestamp_valid_S <= data2_timestamp_valid_V;
			end if;
		end if;
	end if;
end process;
						



-- testword0 <= (others => '0');

testword0(0) <= data1_in_write;
testword0(1) <= data1_in_available;
testword0(2) <= data1_in_allowed_S;
testword0(3) <= read_pulse1_S;
testword0(4) <= data1_in_write_S;
testword0(5) <= data1_timestamp_valid_S;
testword0(9 downto 6) <= data1_in(35 downto 32);

testword0(10) <= data2_in_write;
testword0(11) <= data2_in_available;
testword0(12) <= data2_in_allowed_S;
testword0(13) <= read_pulse2_S;
testword0(14) <= data2_in_write_S;
testword0(15) <= data2_timestamp_valid_S;
testword0(19 downto 16) <= data2_in(35 downto 32);


testword0(20) <= data_out_trywrite_S;
testword0(21) <= data_out_write_S;
testword0(22) <= data_out_available_S;
testword0(23) <= data_out_allowed;
testword0(27 downto 24) <= data_out_S(35 downto 32);
testword0(28) <= error_S;



testword0(33 downto 29) <= timeout_counter_S(TIMEOUTBITS-1 downto TIMEOUTBITS-5);
testword0(35 downto 34) <= (others => '0');


end Behavioral;


