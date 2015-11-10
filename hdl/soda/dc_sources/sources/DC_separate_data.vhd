----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   04-03-2014
-- Module Name:   DC_separate_data 
-- Description:   Read and interprets data from Front End Electronics
-- Modifications:
--   30-07-2014   Timestamp from FEE is now composed by 16 bits superburstnumber and timestamp counter within superburst
--   11-09-2014   New fiber data structure; moved functionality to several modules
--   18-09-2014   different clock for loading
--   11-10-2014   Energy is measured with integral, not with the maximum
--   15-09-2015   First word in output waveform data contains now also 16 bits of the Superburstnumber
--   02-10-2015   Output data now with hit-data members instead of 36-bits data
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;
USE work.panda_package.all;

----------------------------------------------------------------------------------
-- DC_separate_data
-- Gets packet data from the fiber receive module and analyses them.
-- The hit data is processed: two CF-samples are used to calculate the time-fraction.
-- With a Look Up Table this timefraction is corrected for non-linearity.
--
-- The timestamp (superburst part, integer part and fraction) is corrected for the delay of SODA signals
-- and data transmission with a Look Up Table.
-- The energy is adjusted with for each ADC channel a gain and offset value in a Look Up Table.
-- Slowcontrol should fill in the two LUTs.
-- Each pulse is assigned to a superburst number, based on timestamp.
-- 
--
-- Three types of packets are possible:
--
-- The data packets : 4 32-bit words, with CRC8 in last word
--   0xDA ADCnumber(7..0) superburstnumber(15..0)
--   0000 energy(15..0)
--   CF_before(15..0) CF_after(15..0)
--   timestamp(15..0) statusbyte(7..0) CRC8(7..0)
--
-- The slow control packets : 2 32-bit words, with CRC8 in last word
--   0x5C address(7..0) replybit 0000000 data(31..24)
--   data(23..0) CRC8(7..0)
--
-- The waveform packets : 32-bit words, with CRC8 in last word
--   0xAF ADCnumber(7..0) superburstnumber(15..0)
--   timestamp(15..0) 0x00 statusbyte(7..0)
--   0 adc0(14..0) 0 adc1(14..0) : 2 adc-samples 15 bits signed
--   0 adc2(14..0) 0 adc3(14..0) : next 2 adc-samples 15 bits signed
--   .........
--   1 adcn(14..0) 1 00 CRC8(7..0) : last 32-bit word: last adc-sample 15 bits signed
--         or
--   0 0000 1 00 CRC8(7..0) : last 32-bit word: no sample--
--
-- The slow-control commands are written as parallel data and address. It should be connected to a fifo 
-- that is large enough to handle all slow-control data, otherwise commands will be lost.
-- The pulse-data in the data packets will be sent to a multiplexer (MUX).
--
-- The timeshift Look Up Table has 31 bits data:
--   bit 30.. 16 : correction for the integer part
--   bit CF_FRACTIONBIT-1..0 : correction for the fraction part
--
-- The Energy correction Look Up Table has 31 bits data:
--   bit 30..16 : offset correction (signed)
--   bit 15..0 : gain correction
--   equation:  energy = ((original_energy+offset) * gainfactor)>>scalingbits 
--
--
-- Library:
--     work.panda_package :  for type declarations and constants
-- 
-- Generics:
--     NROFADCS : number of ADCs in the FEE: total high and low gain ADCs 
--     ADCBITS : number of ADC-bits
--     ADCINDEXSHIFT : ADC channel numbers lowest bit indicates the high or low gain ADC, 0=high, 1=low
--     CF_FRACTIONBIT : number of valid constant fraction bits
--     ENERGYSCALINGBITS : number of scaling bits for energy adjustment: energy = (original_energy * gainfactor<<scalingbits)>>scalingbits
--     MAX_DIVIDERSCALEBITS : number of scaling bits for division two largest samples
--     MAX_LUTSIZEBITS : number of bits the maximum correction Look Up Table
--     MAX_LUTSCALEBITS : number of scaling bits for the correction on the maximum (energy)
-- 
-- Inputs:
--     clock : clock input : fiber receiver clock
--     load_clock : clock for loading
--     SODA_clock : clock SODA, used to update superburst
--     reset : synchronous reset
--     enable : enable datareading from receiver
--     timeshiftLUT_write : write signal for Look Up Table time-correction for each adc-channel
--     timeshiftLUT_loading : high : load LUT mode, low : normal correction mode
--     timeshiftLUT_data : correction data to be written in the LUT
--     energyLUT_write : write signal for Look Up Table energy adjustment for each adc-channel
--     energytLUT_loading : high : load LUT mode, low : normal correction mode
--     energyLUT_data : correction data to be written in the LUT: bit15..0=gainfactor(>>scalingbits), bit30..16=offset
--     max_correction : use correction on maximum value with Look Up Table
--     max_LUT_offset : offset for index in maximum correction Look Up Table
--     max_LUT_loading : set in mode for loading a new maximum correction Look Up Table
--     max_LUT_write : write next value in maximum correction Look Up Table
--     fraction_correction : use correction on timestamp fraction with Look Up Table
--     fraction_LUT_loading : set in mode for loading a new timestamp fraction correction Look Up Table
--     fraction_LUT_write : write next value in timestamp fraction correction Look Up Table
--     LUT_data_in : data for writing in the selected LUT : maximum correction or timestamp fraction correction
--     packet_data_in : 32 bits data input from fiber module
--     packet_data_present : data available from fiber module
--     pulse_data_allowed : output data writing allowed
--     pulse_data_almostfull : fifo-almostfull of connected fifo for output data 
--     wave_data_out_allowed : output of full waveform writing allowed : possible to write 254 samples!!
--     FEEboardnumber : number of the board, this will be added to the ADC channel number for the final ADC channel identification
--     superburst_number : most recent superburst-number
--     superburst_update : new most recent superburst-number+timestamp
-- 
-- Outputs:
--     packet_data_read : read signal to fiber module to read next data
--     channel_out : 16-bits identification number of the adc
--     statusbyte_out : 8 bits hit-status
--     energy_out : energy of the hit
--     timefraction_out : fractional part of the time within the superburst
--     timestamp_out : time within superburst
--     superburstnumber_out : superburstnumber
--     pulse_data_write :  hit data write signal
--     slowcontrol_data : slow-control command : data 32-bits 
--     slowcontrol_address : slow-control command : address 8-bits (only part for FEE)
--     slowcontrol_reply : indicates if the slow-control is a reply, or a independent message
--     slowcontrol_write : write of slow-control data/address/reply
--     wave_data_out : data with waveform: 36-bits words with bits 35..32 as index
--        	bits(35..32)="0000" : bits(31 downto 16)=Superburstnumber(15..0), bits(15..0)=timestamp within superburst of waveform
--        	bits(35..32)="0001" : bits(31)=0 bits(30..0)=SuperBurst number
--        	bits(35..32)="0010" : 
--              bits(31..24) = statusbyte (bit7=overflow) 
--              bits(23..16) = 00
--              bits(15..0) = adcnumber (channel identification)
--        	bits(35..32)="0011" : bits(31..16)=adc sample, bits(15..0)=next adc sample
--        	bits(35..32)="0100" : bits(31..16)=last adc sample, bits(15..0)=0
--        	bits(35..32)="0101" : bits(31..16)=last but one adc sample, bits(15..0)=last adc sample
--        	bits(35..32)="1111" : error: buffer full, waveform not valid
--     wave_data_write :  waveform data write signal
--     error : error in packet-data : CRC-error, error in data bits
--     pulse_data_skipped : data remove due to full connected fifo
--
-- Components:
--     DC_split_data : splits incoming packets into pulse data members, waveform packets and slow-control reply commands
--     DC_CF_MAX_correction : calculate the maximum and time-fraction with Look Up Tables
--     DC_time_energy_LUTs : correction for time and energy: offset for time and gain/offset for energy with LUTs
-- 
----------------------------------------------------------------------------------

entity DC_separate_data is
	generic (
		NROFADCS                : natural := 32;
		ADCBITS                 : natural := 14;
		ADCINDEXSHIFT           : natural := 1;
		CF_FRACTIONBIT          : natural := 11;
		ENERGYSCALINGBITS       : natural := 13;
		MAX_DIVIDERSCALEBITS    : natural := 12;
		MAX_LUTSIZEBITS         : natural := 8;
		MAX_LUTSCALEBITS        : natural := 14
	);
    Port ( 
		clock                   : in  std_logic;
		load_clock              : in std_logic;
		SODA_clock              : in  std_logic;
		reset                   : in  std_logic;
		enable                  : in  std_logic;
		
		timeshiftLUT_write      : in  std_logic;
		timeshiftLUT_loading    : in  std_logic;
		timeshiftLUT_data       : in  std_logic_vector (30 downto 0);
		
		energyLUT_write         : in  std_logic;
		energytLUT_loading      : in  std_logic;
		energyLUT_data          : in  std_logic_vector (30 downto 0);
		
		max_correction          : in std_logic;
		max_LUT_offset          : in std_logic_vector(MAX_LUTSIZEBITS-1 downto 0);
		max_LUT_loading         : in std_logic;
		max_LUT_write           : in std_logic;
		
		fraction_correction     : in std_logic;
		fraction_LUT_loading    : in std_logic;
		fraction_LUT_write      : in std_logic;
		LUT_data_in             : in std_logic_vector(CF_FRACTIONBIT-1 downto 0);
		
		packet_data_in          : in  std_logic_vector (31 downto 0);
		packet_data_present     : in  std_logic;
		packet_data_read        : out std_logic;
		
		channel_out             : out std_logic_vector(15 downto 0);
		statusbyte_out          : out std_logic_vector(7 downto 0);
		energy_out              : out std_logic_vector(15 downto 0);
		timefraction_out        : out std_logic_vector(11 downto 0);
		timestamp_out           : out std_logic_vector(15 downto 0);
		superburstnumber_out    : out std_logic_vector(30 downto 0);		
		pulse_data_write        : out std_logic;
		pulse_data_allowed      : in  std_logic;
		pulse_data_almostfull   : in  std_logic;
		
		slowcontrol_data        : out std_logic_vector (31 downto 0);
		slowcontrol_address     : out std_logic_vector (7 downto 0);
		slowcontrol_reply       : out std_logic;
		slowcontrol_write       : out std_logic;
		
		wave_data_out           : out std_logic_vector(35 downto 0);
		wave_data_write         : out std_logic;
		wave_data_out_allowed   : in std_logic;
		
		FEEboardnumber          : in std_logic_vector (15 downto 0);
		superburst_number       : in std_logic_vector(30 downto 0);
		superburst_update       : in std_logic;
		
		error                   : out std_logic;
		pulse_data_skipped      : out std_logic;
		testword0               : out std_logic_vector (35 downto 0) := (others => '0'));
end DC_separate_data;

architecture Behavioral of DC_separate_data is

component DC_split_data is
	generic (
		NROFADCS                : natural := NROFADCS;
		ADCINDEXSHIFT           : natural := ADCINDEXSHIFT;
		CF_FRACTIONBIT          : natural := CF_FRACTIONBIT
	);
    Port ( 
		clock                   : in std_logic;
		SODA_clock              : in  std_logic;
		reset                   : in std_logic;
		enable                  : in std_logic;
		FEEboardnumber          : in std_logic_vector (15 downto 0);
		packet_data_in          : in std_logic_vector (31 downto 0);
		packet_data_present     : in std_logic;
		packet_data_read        : out std_logic;
		pulse_superburst        : out std_logic_vector(15 downto 0);
		pulse_timestamp         : out std_logic_vector(15 downto 0);
		pulse_adcnumber         : out std_logic_vector(15 downto 0);
		pulse_statusbyte        : out std_logic_vector(7 downto 0);
		pulse_energy            : out std_logic_vector(15 downto 0);
		pulse_CF_before         : out std_logic_vector(15 downto 0);
		pulse_CF_after          : out std_logic_vector(15 downto 0);
		pulse_allowed           : in std_logic;
		pulse_write             : out std_logic;
		slowcontrol_data        : out std_logic_vector(31 downto 0);
		slowcontrol_address     : out std_logic_vector(7 downto 0);
		slowcontrol_reply       : out std_logic;
		slowcontrol_write       : out std_logic;			  
		wave_data_out           : out std_logic_vector(35 downto 0);
		wave_data_write         : out std_logic;
		wave_data_out_allowed   : in std_logic;
		superburst_number       : in std_logic_vector(30 downto 0);
		superburst_update       : in std_logic;
		pulse_data_skipped      : out std_logic;
		data_error              : out std_logic;
		testword0               : out std_logic_vector(35 downto 0) := (others => '0'));
end component;

component DC_CF_MAX_correction is
	generic (
		ADCBITS                 : natural := ADCBITS;
		CF_FRACTIONBIT          : natural := CF_FRACTIONBIT;
		MAX_DIVIDERSCALEBITS    : natural := MAX_DIVIDERSCALEBITS;
		MAX_LUTSIZEBITS         : natural := MAX_LUTSIZEBITS;
		MAX_LUTSCALEBITS        : natural := MAX_LUTSCALEBITS
		);
    Port (
		clock                   : in std_logic;
		load_clock              : in std_logic;
		reset                   : in std_logic;
		pulse_superburst        : in std_logic_vector(15 downto 0);
		pulse_timestamp         : in std_logic_vector(15 downto 0);
		pulse_adcnumber         : in std_logic_vector(15 downto 0);
		pulse_statusbyte        : in std_logic_vector(7 downto 0);
		pulse_energy            : in std_logic_vector(15 downto 0);
		pulse_CF_before         : in std_logic_vector(15 downto 0);
		pulse_CF_after          : in std_logic_vector(15 downto 0);
		pulse_allowed           : out std_logic;
		pulse_write             : in std_logic;
		max_correction          : in std_logic;
		max_LUT_offset          : in std_logic_vector(MAX_LUTSIZEBITS-1 downto 0);
		max_LUT_loading         : in std_logic;
		max_LUT_write           : in std_logic;
		fraction_correction     : in std_logic;
		fraction_LUT_loading    : in std_logic;
		fraction_LUT_write      : in std_logic;
		LUT_data_in             : in std_logic_vector(CF_FRACTIONBIT-1 downto 0);
		result_write            : out std_logic;
		result_allowed          : in std_logic;
		adcnumber               : out std_logic_vector(15 downto 0);
		superburst              : out std_logic_vector(15 downto 0);
		timestamp               : out std_logic_vector(15 downto 0);
		timefraction            : out std_logic_vector(CF_FRACTIONBIT-1 downto 0);
		energy                  : out std_logic_vector(15 downto 0);
		statusbyte              : out std_logic_vector(7 downto 0);
		testword0               : out std_logic_vector(35 downto 0) := (others => '0');
		testword1               : out std_logic_vector(35 downto 0) := (others => '0')
		);
end component;

component DC_time_energy_LUTs is
	generic (
		NROFADCS                : natural := NROFADCS;
		ADCINDEXSHIFT           : natural := ADCINDEXSHIFT;
		CF_FRACTIONBIT          : natural := CF_FRACTIONBIT;
		ENERGYSCALINGBITS       : natural := ENERGYSCALINGBITS
	);
    Port ( 
		clock                   : in  std_logic;
		load_clock              : in std_logic;
		SODA_clock              : in  std_logic;
		reset                   : in  std_logic;
		enable                  : in  std_logic;
		timeshiftLUT_write      : in  std_logic;
		timeshiftLUT_loading    : in  std_logic;
		timeshiftLUT_data       : in  std_logic_vector (30 downto 0);
		energyLUT_write         : in  std_logic;
		energytLUT_loading      : in  std_logic;
		energyLUT_data          : in  std_logic_vector (30 downto 0);
		
		datain_write            : in std_logic;
		datain_allowed          : out std_logic;
		adcnumber               : in std_logic_vector(15 downto 0); -- should be 1 clockcycle valid before datain_write
		superburst              : in std_logic_vector(15 downto 0);
		timestamp               : in std_logic_vector(15 downto 0);
		timefraction            : in std_logic_vector(CF_FRACTIONBIT-1 downto 0);
		energy                  : in std_logic_vector(15 downto 0);
		statusbyte              : in std_logic_vector(7 downto 0);

		channel_out             : out std_logic_vector(15 downto 0);
		statusbyte_out          : out std_logic_vector(7 downto 0);
		energy_out              : out std_logic_vector(15 downto 0);
		timefraction_out        : out std_logic_vector(11 downto 0);
		timestamp_out           : out std_logic_vector(15 downto 0);
		superburstnumber_out    : out std_logic_vector(30 downto 0);		
		pulse_data_write        : out std_logic;
		pulse_data_allowed      : in std_logic;
		pulse_data_skipped      : out std_logic;
		superburst_number       : in std_logic_vector(30 downto 0);
		superburst_update       : in std_logic;
		testword0               : out std_logic_vector (35 downto 0) := (others => '0'));
end component;

signal pulse_superburst_S      : std_logic_vector(15 downto 0);
signal pulse_timestamp_S       : std_logic_vector(15 downto 0);
signal pulse_adcnumber_S       : std_logic_vector(15 downto 0);
signal pulse_statusbyte_S      : std_logic_vector(7 downto 0);
signal pulse_energy_S          : std_logic_vector(15 downto 0);
signal pulse_CF_before_S       : std_logic_vector(15 downto 0);
signal pulse_CF_after_S        : std_logic_vector(15 downto 0);
signal pulse_allowed_S         : std_logic;
signal pulse_write_S           : std_logic;

signal pulse_data_skipped1_S   : std_logic;
signal pulse_data_skipped2_S   : std_logic;
signal data_error_S            : std_logic;

signal result_write_S          : std_logic;
signal result_allowed_S        : std_logic;
signal CFMAX_result_allowed_S  : std_logic;
signal result_adcnumber_S      : std_logic_vector(15 downto 0);
signal result_superburst_S     : std_logic_vector(15 downto 0);
signal result_timestamp_S      : std_logic_vector(15 downto 0);
signal result_timefraction_S   : std_logic_vector(CF_FRACTIONBIT-1 downto 0);
signal result_energy_S         : std_logic_vector(15 downto 0);
signal result_statusbyte_S     : std_logic_vector(7 downto 0);

begin

pulse_data_skipped <= '1' when (pulse_data_skipped1_S='1') or (pulse_data_skipped2_S='1') else '0';
error <= '1' when (data_error_S='1') else '0';


DC_split_data1: DC_split_data port map(
		clock => clock,
		SODA_clock => SODA_clock,
		reset => reset,
		enable => enable,
		FEEboardnumber => FEEboardnumber,
		packet_data_in => packet_data_in,
		packet_data_present => packet_data_present,
		packet_data_read => packet_data_read,
		pulse_superburst => pulse_superburst_S,
		pulse_timestamp => pulse_timestamp_S,
		pulse_adcnumber => pulse_adcnumber_S,
		pulse_statusbyte => pulse_statusbyte_S,
		pulse_energy => pulse_energy_S,
		pulse_CF_before => pulse_CF_before_S,
		pulse_CF_after => pulse_CF_after_S,
		pulse_allowed => pulse_allowed_S,
		pulse_write => pulse_write_S,
		slowcontrol_data => slowcontrol_data,
		slowcontrol_address => slowcontrol_address,
		slowcontrol_reply => slowcontrol_reply,
		slowcontrol_write => slowcontrol_write,		  
		wave_data_out => wave_data_out,
		wave_data_write => wave_data_write,
		wave_data_out_allowed => wave_data_out_allowed,
		superburst_number => superburst_number,
		superburst_update => superburst_update,
		pulse_data_skipped => pulse_data_skipped1_S,
		data_error => data_error_S,
		testword0 => open
	);

		
DC_CF_MAX_correction1: DC_CF_MAX_correction port map(
		clock => clock,
		load_clock => load_clock,
		reset => reset,
		pulse_superburst => pulse_superburst_S,
		pulse_timestamp => pulse_timestamp_S,
		pulse_adcnumber => pulse_adcnumber_S,
		pulse_statusbyte => pulse_statusbyte_S,
		pulse_energy => pulse_energy_S,
		pulse_CF_before => pulse_CF_before_S,
		pulse_CF_after => pulse_CF_after_S,
		pulse_allowed => pulse_allowed_S,
		pulse_write => pulse_write_S,
		max_correction => max_correction,
		max_LUT_offset => max_LUT_offset,
		max_LUT_loading => max_LUT_loading,
		max_LUT_write => max_LUT_write,
		fraction_correction => fraction_correction,
		fraction_LUT_loading => fraction_LUT_loading,
		fraction_LUT_write => fraction_LUT_write,
		LUT_data_in => LUT_data_in,
		result_write => result_write_S,
		result_allowed => CFMAX_result_allowed_S, -- allowed when fifo has enough space
		adcnumber => result_adcnumber_S,
		superburst => result_superburst_S,
		timestamp => result_timestamp_S,
		timefraction => result_timefraction_S,
		energy => result_energy_S,
		statusbyte => result_statusbyte_S,
		testword0 => open,
		testword1 => open
		);
CFMAX_result_allowed_S <= '1' when pulse_data_almostfull='0' else '0';
		
DC_time_energy_LUTs1: DC_time_energy_LUTs port map(
		clock => clock,
		load_clock => load_clock,
		SODA_clock => SODA_clock,
		reset => reset,
		enable => enable,
		timeshiftLUT_write => timeshiftLUT_write,
		timeshiftLUT_loading => timeshiftLUT_loading,
		timeshiftLUT_data => timeshiftLUT_data,
		energyLUT_write => energyLUT_write,
		energytLUT_loading => energytLUT_loading,
		energyLUT_data => energyLUT_data,
		
		datain_write => result_write_S,
		datain_allowed => result_allowed_S,
		adcnumber => result_adcnumber_S,
		superburst => result_superburst_S,
		timestamp => result_timestamp_S,
		timefraction => result_timefraction_S,
		energy => result_energy_S,
		statusbyte => result_statusbyte_S,

		channel_out => channel_out,
		statusbyte_out => statusbyte_out,
		energy_out => energy_out,
		timefraction_out => timefraction_out,
		timestamp_out => timestamp_out,
		superburstnumber_out => superburstnumber_out,	
		pulse_data_write => pulse_data_write,
		pulse_data_allowed => pulse_data_allowed,
		pulse_data_skipped => pulse_data_skipped2_S,
		superburst_number => superburst_number,
		superburst_update => superburst_update,
		testword0 => open
		);


end Behavioral;

