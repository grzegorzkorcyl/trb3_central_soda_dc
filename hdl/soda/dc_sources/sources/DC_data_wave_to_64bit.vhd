----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   27-02-2014
-- Module Name:   DC_data_wave_to_64bit
-- Description:   Transfer pulse-data and waveforms as packets with 64-bits width
-- Modifications:
--   17-07-2014   buffer_almost_full_S in clocked process
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;

----------------------------------------------------------------------------------
-- DC_data_wave_to_64bit
-- Transfer pulse-data and waveforms as packets with 64-bits width
--
-- The input pulse data consists of the following items (parallel)
--        channel : adc-index
--        statusbyte : 8 bit status information
--        energy : pulse energy
--        timefraction : fraction part of the timestamp
--        timestamp : 16 bits timestamp, synchronised to master SODA clock
--        superburstnumber : 31 bits superburst number
--
-- All the pulse data from one superburst is put in one data-packet.
-- The first word-64 contains the superburst number and the timestamp of the first pulse.
-- The superburst are sequential. If there is no data in a superburst then the packet 
-- contains only the superburst and zero for the timestamp.
-- For each pulse a 64-bits word is written with measured data.
-- The time offset in respect to the first pulse is part of this 64-bits word
--
-- The input waveform consist of 36-bit data:
--        bits(35..32)="0000" : 0000 & bits(15..0)=timestamp of maximum value in waveform
--        bits(35..32)="0001" : bits(314)=0 bits(30..0)=SuperBurst number
--        bits(35..32)="0010" : 
--        bits(31..24) = statusbyte (bit6=overflow) 
--        bits(23..16) = 00
--        bits(15..0) = adcnumber (channel identification)
--        bits(35..32)="0011" : bits(31..16)=adc sample, bits(15..0)=next adc sample
--        bits(35..32)="0100" : bits(31..16)=last adc sample, bits(15..0)=0
--        bits(35..32)="0101" : bits(31..16)=last but one adc sample, bits(15..0)=last adc sample
--        bits(35..32)="1111" : error: buffer full, waveform not valid
--
-- The 64 bits output packets, according to 32bits SODAnet specs:
-- 32bits word1:   
--        bit31      = last-packet flag
--        bit30..16  = packet number
--        bit15..0   = data size in bytes
-- 32bits word2:   
--        bit31..0   = Not used (same as HADES)
-- 32bits word3:   
--        bit31..16  = Status
--           bit16=internal data-error
--           bit17=internal error
--           bit18=error in pulse-data/superburst number
--           bit31=  0:pulse data packet, 1:waveform packet
--        bit15..0   = System ID
-- 32bits word4:   
--        bit31      = 0
--        bit30..0   = Super-burst number
--
--    for pulse data
-- 32bits word5,7,9,11.. ,odd, for each pulse:   
--        bit31..19  = offset in respect to superburst
--        bit18..8   = Time fraction (11 bits used)
--        bit7..0    = status byte
-- 32bits word6,8,10,12.. ,even, for each pulse:   
--        bit31..16  = adc channel
--        bit15..0   = Energy (pulse height)
--
--    for wave data
-- 32bits word5:
--        bit31..24  = status byte
--        bit23..8   = adc channel
--        bit7..0    = number of samples in wave
-- 32bits word6:
--        bit15..0  = timestamp in respect to superburst of sample on the top of the waveform
-- 32bits word7..lastsample : next_adcsample(15:0) next_adcsample(15:0) ....
-- 
--
--
-- Library:
--
-- Generics:
--     TRANSITIONBUFFERBITS : number of bits for the buffer that stores data from the next superburst
--     PANDAPACKETBUFFERBITS : number of bits for the buffer to store packet for size calculation
--     CF_FRACTIONBIT : number of valid constant fraction bits
--     SYSTEM_ID : ID number of this Data Concentrator
--
-- Inputs:
--     clock : clock for 36-bits input data 
--     reset : reset
--     latestsuperburstnumber : latest superburst number that has been issued by SODA
--     channel : pulse-data : adc channel number
--     statusbyte : pulse-data : status
--     energy : pulse-data : energy
--     timefraction : pulse-data : Constant Fraction time
--     timestamp : pulse-data : time (ADC-clock)
--     superburstnumber : pulse-data : superburstnumber
--     data_in_available : input data available (NOT fifo-empty from connected fifo)
--     wave_in : input data :
--        bits(35..32)="0000" : 0000 & bits(15..0)=timestamp of maximum value in waveform
--        bits(35..32)="0001" : bits(31)=0 bits(30..0)=SuperBurst number
--        bits(35..32)="0010" : 
--        bits(31..24) = statusbyte (bit6=overflow) 
--        bits(23..16) = 00
--        bits(15..0) = adcnumber (channel identification)
--        bits(35..32)="0011" : bits(31..16)=adc sample, bits(15..0)=next adc sample
--        bits(35..32)="0100" : bits(31..16)=last adc sample, bits(15..0)=0
--        bits(35..32)="0101" : bits(31..16)=last but one adc sample, bits(15..0)=last adc sample
--        bits(35..32)="1111" : error: buffer full, waveform not valid
--     wave_in_available : input data available (NOT fifo-empty from connected fifo)
--     data_out_allowed : allowed to write 64-bits output data (normally:: fifo not empty)
-- 
-- Outputs:
--     data_in_read : read signal for pulse data
--     wave_in_read : read signal for waveform data
--     data_out : 64 bits data output
--     data_out_write : write signal for 64 bits output data
--     data_out_first : indicates first 64-bits data in packet
--     data_out_last : indicates last 64-bits data in packet
--     error : error in data
-- 
-- Components:
--     DC_superburst2packet64 : Put Pulse data from one superburst into packets with 64-bits width data
--     DC_wave2packet64 : Put waveform data into packets with 64-bits width data
--     blockmem : memory for saving packets temporarily to calculate the packetsize and add a header
--
----------------------------------------------------------------------------------

entity DC_data_wave_to_64bit is
	generic (
		TRANSITIONBUFFERBITS    : natural := 7;
		PANDAPACKETBUFFERBITS   : natural := 13;
		CF_FRACTIONBIT          : natural := 11;
		SYSTEM_ID : std_logic_vector(15 downto 0) := x"5555"
	);
    Port ( 
		clock                   : in std_logic;
		reset                   : in std_logic;
		latestsuperburstnumber  : in std_logic_vector(30 downto 0);
		channel                 : in std_logic_vector(15 downto 0);
		statusbyte              : in std_logic_vector(7 downto 0);
		energy                  : in std_logic_vector(15 downto 0);
		timefraction            : in std_logic_vector(11 downto 0);
		timestamp               : in std_logic_vector(15 downto 0);
		superburstnumber        : in std_logic_vector(30 downto 0);		
		data_in_available       : in std_logic;
		data_in_read            : out std_logic;
		wave_in                 : in std_logic_vector(35 downto 0);
		wave_in_available       : in std_logic;
		wave_in_read            : out std_logic;
		data_out_allowed        : in std_logic;
		data_out                : out std_logic_vector(63 downto 0);
		data_out_write          : out std_logic;
		data_out_first          : out std_logic;
		data_out_last           : out std_logic;
		error                   : out std_logic;
		testword0               : out std_logic_vector(35 downto 0);
		testword1               : out std_logic_vector(35 downto 0)
		);
end DC_data_wave_to_64bit;

architecture Behavioral of DC_data_wave_to_64bit is

component DC_superburst2packet64 is
	generic (
		TRANSITIONBUFFERBITS : natural := TRANSITIONBUFFERBITS;
		CF_FRACTIONBIT       : natural := CF_FRACTIONBIT
	);
    Port ( 
		clock                   : in std_logic;
		reset                   : in std_logic;
		channel                 : in std_logic_vector(15 downto 0);
		statusbyte              : in std_logic_vector(7 downto 0);
		energy                  : in std_logic_vector(15 downto 0);
		timefraction            : in std_logic_vector(11 downto 0);
		timestamp               : in std_logic_vector(15 downto 0);
		superburstnumber        : in std_logic_vector(30 downto 0);
		data_in_read            : out std_logic;
		data_in_available       : in std_logic;
		latestsuperburstnumber  : in std_logic_vector(30 downto 0);
		data64_out              : out std_logic_vector(63 downto 0);
		data64_out_write        : out std_logic;
		data64_out_first        : out std_logic;
		data64_out_last         : out std_logic;
		data64_out_allowed      : in std_logic;
		error                   : out std_logic;
		testword0               : out std_logic_vector(35 downto 0) := (others => '0')
	);    
end component;

component DC_wave2packet64 is
	generic (
		BUFFER_BITS : natural := 9
	);
    Port ( 
		clock                   : in std_logic;
		reset                   : in std_logic;
		wave_in                 : in std_logic_vector(35 downto 0);
		wave_in_read            : out std_logic;
		wave_in_available       : in std_logic;
		wave64_out              : out std_logic_vector(63 downto 0);
		wave64_out_write        : out std_logic;
		wave64_out_first        : out std_logic;
		wave64_out_last         : out std_logic;
		wave64_out_allowed      : in std_logic;
		error                   : out std_logic;
		testword0               : out std_logic_vector(35 downto 0) := (others => '0')
	);    
end component;

component blockmem is
	generic (
		ADDRESS_BITS : natural := PANDAPACKETBUFFERBITS;
		DATA_BITS  : natural := 66
		);
	port (
		clock                   : in  std_logic; 
		write_enable            : in std_logic;
		write_address           : in std_logic_vector(ADDRESS_BITS-1 downto 0);
		data_in                 : in std_logic_vector(DATA_BITS-1 downto 0);
		read_address            : in std_logic_vector(ADDRESS_BITS-1 downto 0);
		data_out                : out std_logic_vector(DATA_BITS-1 downto 0)
	);
end component;

attribute syn_keep     : boolean;
attribute syn_preserve : boolean;

type readmode_type is (waitforfirst,writeemptypulsepacket1,writepulseheader,writepulsedata,
		finishpulseheader,preparenextheader,writewaveheader,writewavedata,finishwaveheader);
signal readmode_S             : readmode_type := waitforfirst;

signal wave_in_read_S         : std_logic := '0';

signal pulse64_S              : std_logic_vector(63 downto 0) := (others => '0');
signal pulse64_write_S        : std_logic := '0';
signal pulse64_first_S        : std_logic := '0';
signal pulse64_last_S         : std_logic := '0';
signal pulse64_allowed_S      : std_logic := '0';
signal pulse64_error_S        : std_logic := '0';

signal wave64_S               : std_logic_vector(63 downto 0) := (others => '0');
signal wave64_write_S         : std_logic := '0';
signal wave64_first_S         : std_logic := '0';
signal wave64_last_S          : std_logic := '0';
signal wave64_allowed_S       : std_logic := '0';
signal wave64_error_S         : std_logic := '0';

signal mem_write_S            : std_logic := '0';
signal mem_datain_S           : std_logic_vector(65 downto 0) := (others => '0');
signal mem_dataout_S          : std_logic_vector(65 downto 0) := (others => '0');
signal mem_writeaddress_S     : std_logic_vector(PANDAPACKETBUFFERBITS-1 downto 0) := (others => '0');
signal mem_readaddress_S      : std_logic_vector(PANDAPACKETBUFFERBITS-1 downto 0) := (others => '0');
signal mem_readaddress0_S     : std_logic_vector(PANDAPACKETBUFFERBITS-1 downto 0) := (others => '0');
signal mem_readaddress_saved_S  : std_logic_vector(PANDAPACKETBUFFERBITS-1 downto 0) := (others => '0');
signal mem_startpacketaddress_S : std_logic_vector(PANDAPACKETBUFFERBITS-1 downto 0) := (others => '0');
signal mem_startpacketaddress_after1clk_S : std_logic_vector(PANDAPACKETBUFFERBITS-1 downto 0) := (others => '0');
signal mem_endpacketaddress_S : std_logic_vector(PANDAPACKETBUFFERBITS-1 downto 0) := (others => '0');
signal data_w64_counter_S     : std_logic_vector(12 downto 0) := (others => '0');

signal pulse_buffer_s         : std_logic_vector(63 downto 0) := (others => '0');

signal buffer_almost_full_s   : std_logic := '0';
signal wavemode_S             : std_logic := '0';
signal clear_pulse64_error_s  : std_logic := '0';
signal pulse64_erroroccurred_s: std_logic := '0';
signal error_occurred_s       : std_logic := '0';
signal datavalid_S            : std_logic := '0';
signal decrement_address_S    : std_logic := '0';


signal pulse_superburstnr_S   : std_logic_vector(30 downto 0) := (others => '0');
signal wave_superburstnr_S    : std_logic_vector(30 downto 0) := (others => '0');
signal prioritytopulsedata_S  : std_logic := '0';
signal data_out_write_S       : std_logic := '0';
signal data_out_write0_S      : std_logic := '0';

signal debug_samesuperburstnumber_S      : std_logic := '0';
signal debug_superburstnumber_S   : std_logic_vector(30 downto 0) := (others => '0');
attribute syn_keep of debug_samesuperburstnumber_S : signal is true;
attribute syn_preserve of debug_samesuperburstnumber_S : signal is true;
attribute syn_keep of debug_superburstnumber_S : signal is true;
attribute syn_preserve of debug_superburstnumber_S : signal is true;

signal testword0_S            : std_logic_vector(35 downto 0) := (others => '0');
signal testword1_S            : std_logic_vector(35 downto 0) := (others => '0');

begin


process(clock)
begin
	if (rising_edge(clock)) then
		if (pulse64_error_S='1') or (wave64_error_S='1') then
			error <= '1';
		else
			error <= '0';
		end if;
	end if;
end process;


DC_superburst2packet641: DC_superburst2packet64 port map(
		clock => clock,
		reset => reset,
		channel => channel,
		statusbyte => statusbyte,
		energy => energy,
		timefraction => timefraction,
		timestamp => timestamp,
		superburstnumber => superburstnumber,
		data_in_read => data_in_read,
		data_in_available => data_in_available,
		latestsuperburstnumber => latestsuperburstnumber,
		data64_out => pulse64_S,
		data64_out_write => pulse64_write_S,
		data64_out_first => pulse64_first_S,
		data64_out_last => pulse64_last_S,
		data64_out_allowed => pulse64_allowed_S,
		error => pulse64_error_S,
		testword0 => testword1_S);  


		
DC_wave2packet641: DC_wave2packet64 port map(
		clock => clock,
		reset => reset,
		wave_in => wave_in,
		wave_in_read => wave_in_read_S,
		wave_in_available => wave_in_available,
		wave64_out => wave64_S,
		wave64_out_write => wave64_write_S,
		wave64_out_first => wave64_first_S,
		wave64_out_last => wave64_last_S,
		wave64_out_allowed => wave64_allowed_S,
		error => wave64_error_S,
		testword0 => open);    
wave_in_read <= wave_in_read_S;

blockmem1: blockmem port map(
		clock => clock,
		write_enable => mem_write_S,
		write_address => mem_writeaddress_S,
		data_in => mem_datain_S,
		read_address => mem_readaddress_S,
		data_out => mem_dataout_S);

process(clock)
begin
	if (rising_edge(clock)) then		
		if ((mem_readaddress_S=mem_writeaddress_S+1) or 
			(mem_readaddress_S=mem_writeaddress_S+2) or 
			(mem_readaddress_S=mem_writeaddress_S+3) or 
			(mem_readaddress_S=mem_writeaddress_S+4)) then
			buffer_almost_full_S <= '1';
		else
			buffer_almost_full_S <= '0';
		end if;
	end if;
end process;
		
pulse64_allowed_S <= '1' when (buffer_almost_full_S='0') and
		(((readmode_S=waitforfirst) and ((prioritytopulsedata_S='1') or ((wave64_write_S='0') and (wave_in_available='0')))) or ---- wave highest priority ?
		((readmode_S=writepulsedata) and (wavemode_S='0'))) 
	else '0';
wave64_allowed_S <= '1' when (buffer_almost_full_S='0') and
		(((readmode_S=waitforfirst) and ((prioritytopulsedata_S='0') or (pulse64_write_S='0'))) or 
		((readmode_S=writewaveheader) and (wavemode_S='1')) or 
		((readmode_S=writewavedata) and (wavemode_S='1')))
	else '0';


superburstcompare_process: process(clock)
begin
	if (rising_edge(clock)) then
		if readmode_S=writepulseheader then
			prioritytopulsedata_S <= '0';
		else
			if pulse_superburstnr_S<wave_superburstnr_S then
				prioritytopulsedata_S <= '1';
			else
				prioritytopulsedata_S <= '0';
			end if;
		end if;
	end if;
end process;

	
writetomem_process: process(clock)
variable status_V : std_logic_vector(15 downto 0);
begin
	if (rising_edge(clock)) then 
		mem_write_S <= '0';
		clear_pulse64_error_S <= '0';
		if reset='1' then
			pulse64_erroroccurred_S <= '0';
			mem_writeaddress_S <= (others => '0');
			mem_startpacketaddress_S <= (others => '0');
			readmode_S <= waitforfirst;
		else
			if (pulse64_error_S='1') or (wave64_error_S='1') then
				pulse64_erroroccurred_S <= '1';
			elsif clear_pulse64_error_S='1' then
				pulse64_erroroccurred_S <= '0';
			end if;
			case readmode_S is
				when waitforfirst =>
					mem_startpacketaddress_S <= mem_writeaddress_S;
					if pulse64_write_S='1' then
						wavemode_S <= '0';
						if pulse64_first_S='1' then
							pulse_buffer_S <= pulse64_S(63 downto 0);
							if pulse64_last_S='1' then -- empty packet
								mem_datain_S <= '1' & '0' & x"8000" & x"0010" & x"00000000"; -- w64:1 last packet flag, packet nr=0, size=16 bytes , 32bits not used
								mem_write_S <= '1';
--								mem_writeaddress_S <= mem_writeaddress_S+1;
--								mem_startpacketaddress_S <= mem_writeaddress_S+1;
								readmode_S <= writeemptypulsepacket1;
							else
								status_V := x"0000";
								status_V(0) := pulse64_S(63); -- error, bit 63 must be 0
								status_V(1) := error_occurred_S;
								status_V(2) := pulse64_erroroccurred_S;
								status_V(15) := '0'; -- indicates packet with pulse data
								error_occurred_S <= '0';
								clear_pulse64_error_S <= '1';
								mem_datain_S <= '0' & '0' & status_V & SYSTEM_ID & '0' & pulse64_S(62 downto 32); -- w64:2  status, system_id and superburstntr
								pulse_superburstnr_S <= pulse64_S(62 downto 32);
								mem_write_S <= '1';
--								mem_startpacketaddress_S <= mem_writeaddress_S+1;
								mem_writeaddress_S <= mem_writeaddress_S+1; -- write second word
								readmode_S <= writepulseheader;
							end if;
						else -- not first : error, cleanup
							error_occurred_S <= '1';
						end if;
					elsif wave64_write_S='1' then
						if (wave64_first_S='1') and (wave64_last_S='0') then
							wavemode_S <= '1';
							pulse_buffer_S <= wave64_S(63 downto 0);
							status_V := x"0000";
							if wave64_S(63 downto 56)/=x"dd" then
								status_V(0) := '1'; -- error, must be DD
							end if;
							status_V(1) := error_occurred_S;
							status_V(15) := '1'; -- packet containing waveform
							error_occurred_S <= '0';
							mem_datain_S <= '0' & '0' & status_V & SYSTEM_ID & '0' & wave64_S(30 downto 0); -- w64:2 status, system_id and superburstntr
							wave_superburstnr_S <= wave64_S(30 downto 0);
							mem_write_S <= '1';
--							mem_startpacketaddress_S <= mem_writeaddress_S+1;
							mem_writeaddress_S <= mem_writeaddress_S+1; -- write second word
							readmode_S <= writewaveheader;
						else -- not first : error, cleanup
							error_occurred_S <= '1';
						end if;
					else
					end if;
				when writeemptypulsepacket1 =>
					if buffer_almost_full_S='0' then
						status_V := x"0000";
						status_V(0) := pulse_buffer_S(63); -- error, bit 63 must be 0
						status_V(1) := error_occurred_S;
						status_V(2) := pulse64_erroroccurred_S;
						status_V(15) := '0'; -- indicates packet with pulse data
						error_occurred_S <= '0';
						clear_pulse64_error_S <= '1';
						mem_datain_S <= '0' & '1' & status_V & SYSTEM_ID & '0' & pulse_buffer_S(62 downto 32); -- w64:2 status, system_id and superburstntr
						pulse_superburstnr_S <= pulse_buffer_S(62 downto 32);
						mem_write_S <= '1';
						mem_writeaddress_S <= mem_writeaddress_S+1;
						mem_endpacketaddress_S <= mem_writeaddress_S+1;
						readmode_S <= preparenextheader;
					end if;
				when writepulseheader => -- do not write, wait for allowed, set counter
					data_w64_counter_S <= '0' & x"002";
					if buffer_almost_full_S='0' then
						readmode_S <= writepulsedata;
					end if;
				when writepulsedata => 
					if pulse64_write_S='1' then
						data_w64_counter_S <= data_w64_counter_S+1;
						if pulse64_first_S='1' then -- error
							error_occurred_S <= '1';
							mem_writeaddress_S <= mem_startpacketaddress_S;
							readmode_S <= waitforfirst;
						else
							mem_datain_S <= '0' & pulse64_last_S & pulse64_S; -- w64:4..  : pulse data
							mem_write_S <= '1';
							if pulse64_last_S='1' then
								mem_endpacketaddress_S <= mem_writeaddress_S+1;
								readmode_S <= finishpulseheader;
							end if;
							mem_writeaddress_S <= mem_writeaddress_S+1;
						end if;
					end if;
				when finishpulseheader =>
					if buffer_almost_full_S='0' then
						mem_writeaddress_S <= mem_startpacketaddress_S;
						mem_datain_S <= '1' & '0' & x"8000" & data_w64_counter_S & "000" & x"00000000"; -- w64:1  1 last packet flag, packet nr=0, size(bytes), 32bits not used
						mem_write_S <= '1';
						readmode_S <= preparenextheader;
					end if;
				when preparenextheader =>
					mem_writeaddress_S <= mem_endpacketaddress_S+1;
					mem_startpacketaddress_S <= mem_endpacketaddress_S+1;
					readmode_S <= waitforfirst;
					
				when writewaveheader =>
					if wave64_write_S='1' then -- second wave word 
						mem_writeaddress_S <= mem_writeaddress_S+1;
						mem_datain_S <= '0' & '0' & pulse_buffer_S(55 downto 48) & pulse_buffer_S(47 downto 32) & wave64_S(15 downto 8) & wave64_S(47 downto 16); -- w64:3 status, adc-channel, nrofsamples and timestamp
						mem_write_S <= '1';
						data_w64_counter_S <= '0' & x"003";
						readmode_S <= writewavedata;
					end if;
				when writewavedata =>
					if wave64_write_S='1' then -- second wave word 
						data_w64_counter_S <= data_w64_counter_S+1;
						if wave64_first_S='1' then -- error
							error_occurred_S <= '1';
							mem_writeaddress_S <= mem_startpacketaddress_S;
							readmode_S <= waitforfirst;
						else
							mem_datain_S <= '0' & wave64_last_S & wave64_S; 
							mem_write_S <= '1';
							if wave64_last_S='1' then
								mem_endpacketaddress_S <= mem_writeaddress_S+1;
								readmode_S <= finishwaveheader;
							end if;
							mem_writeaddress_S <= mem_writeaddress_S+1;
						end if;
					end if;
				when finishwaveheader =>
					if buffer_almost_full_S='0' then
						mem_writeaddress_S <= mem_startpacketaddress_S;
						mem_datain_S <= '1' & '0' & x"8000" & data_w64_counter_S & "000" & x"00000000"; -- w64:1 last packet flag, packet nr=0, size=16 bytes , 32bits not used
						mem_write_S <= '1';
						readmode_S <= preparenextheader;
					end if;
			end case;
		end if;
	end if;
end process;

data_out <= mem_dataout_S(63 downto 0);
data_out_first <= mem_dataout_S(65);
data_out_last <= mem_dataout_S(64);
data_out_write <= data_out_write_S;
data_out_write_S <= '1' when (data_out_allowed='1') and (datavalid_S='1') and (decrement_address_S='0') else '0';

data_out_write0_S <= '1' when (mem_readaddress_S/=mem_startpacketaddress_after1clk_S) else '0';
mem_readaddress_S <= mem_readaddress_saved_S when (datavalid_S='1') and (data_out_allowed='0') else mem_readaddress0_S;

readfrommem_process: process(clock)
begin
	if (rising_edge(clock)) then 
		if reset='1' then
			mem_readaddress0_S <= (others => '0');
			mem_readaddress_saved_S <= (others => '0');
			mem_startpacketaddress_after1clk_S <= (others => '0');
			decrement_address_S <= '0';
		else
			if data_out_allowed='1' then
				if (data_out_write0_S='1') then
					mem_readaddress0_S <= mem_readaddress0_S+1;
					mem_readaddress_saved_S <= mem_readaddress0_S;
					datavalid_S <= '1';
				else
					datavalid_S <= '0';
				end if;
				decrement_address_S <= '0';
			else
				if (datavalid_S='1') then -- retry
					datavalid_S <= '1';
					if (decrement_address_S='0') then
						mem_readaddress0_S <= mem_readaddress0_S-1;
						decrement_address_S <= '1';
					end if;
				end if;
			end if;
		end if;
--		if data_out_allowed='1' then
			mem_startpacketaddress_after1clk_S <= mem_startpacketaddress_S;
--		end if;
	end if;
end process;


		
process(clock)
begin
	if (rising_edge(clock)) then
		debug_samesuperburstnumber_S <= '0';
		if (pulse64_write_S='1') and (pulse64_first_S='1') then
			if debug_superburstnumber_S=pulse64_S(62 downto 32) then
				debug_samesuperburstnumber_S <= '1';
			end if;
			debug_superburstnumber_S <= pulse64_S(62 downto 32);
		end if;
	end if;
end process;

testword0 <= (others => '0');
testword1 <= (others => '0');



end Behavioral;

