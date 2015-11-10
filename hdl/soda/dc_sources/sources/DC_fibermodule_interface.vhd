----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   05-03-2014
-- Module Name:   DC_fibermodule_interface
-- Description:   Module for connection between fiber module to/from FEE and MUX board
-- Modifications:
--   30-07-2014   Timestamp from FEE is now composed by 16 bits superburstnumber and timestamp counter within superburst
--   16-09-2014   New data format between FEE and DC, correction LUTs are now in DC
--   18-09-2014   different clock for loading
--   28-01-2015   clear errors output added
--   21-05-2015   Additional clock synchronization
--   02-10-2015   Output data now with hit-data members instead of 36-bits data
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;
USE work.panda_package.all;

----------------------------------------------------------------------------------
-- DC_fibermodule_interface
-- Module for connection between fiber module to/from FEE and multiplexer and CPU slowcontrol modules on
-- the Panda Data collector board:
-- Slowcontrol commands from the control system are put in packets and sent to the fiber module.
-- SODA packets are passed through to the fiber.
-- Data packets are received from the fiber, analysed and translated to Pulse-data, Pileup Waveforms and slowcontrol data.
-- This module can also send some slowcontrol commands to the CPU by itself, see work.panda_package for constants:
--     ADDRESS_BOARDNUMBER :
--         bit11..0 = sets the unique boardnumber
--         bit31 = initialize all FEE registers that have been set
--     ADDRESS_MUX_MAXCFLUTS : 
--         bit15..0 : data for the CF or MAX Look Up Table
--         bit25..16 :offset for maximum correction LUT
--         bit26 : write signal for maximum LUT
--         bit27 : loading maximum correction LUT
--         bit28 : enable maximum correction
--         bit29 : write signal for Constant Fraction LUT
--         bit30 : loading CF correction LUT
--         bit31 : enable CF correction
--     ADDRESS_MUX_FIBERMODULE_STATUS :
--         command: clear error bits, pulse skipped counter
--         request : request status; Reply, or in case of error: Status of the fibermodule:
--         bit0 : error in slowcontrol to cpu occured
--         bit1 : error in slowcontrol transmit data
--         bit2 : error in fiber receive data
--         bit3 : pulse data skipped due to full multiplexer fifo
--         bit4 : receiver locked
--         bit15..8 : number of pulse data packets skipped due to full buffers
--     ADDRESS_MUX_MULTIPLEXER_STATUS :  status/fullness of the multiplexer
--         bit 15..0 : number of words in input fifo of the multiplexer
--         bit 15..0 : number of words in output fifo of the multiplexer, only for fiber index 0
--     ADDRESS_MUX_TIMESTAMP_ERRORS
--         bit 9..0 : number of timestamp mismatches
--         bit 19..10 : number of skipped pulses
--         bit 29..20 : number of data errors
--     ADDRESS_MUX_TIMESHIFT
--       number of  clockcycles (incl. constant fraction) to compensate for delay SODA to FEE
--         bit 10..0 : compensation time, fractional part; number of bits for constant fraction, see CF_FRACTIONBIT
--         bit 30..16 : compensation time, integer part
--         bit 31 : load mode, after set to 1 starts with ADC0 on each write, and so on
--     ADDRESS_MUX_ENERGYCORRECTION
--       energy correction Look Up Table
--         bit 15..0 : gain correction (multiplying factor shifted by number of scalingsbits)
--         bit 30..16 : offset for energy
--         bit 31 : loading LUT mode, after set to 1 starts with ADC0 on each write, and so on
--
-- Library
--     work.panda_package :  for type declarations and constants
-- 
-- Generics:
--     NROFADCS : number of ADCs per FEE
--     ADCBITS : number of ADC-bits
--     ADCINDEXSHIFT : ADC channel numbers lowest bit indicates the high or low gain ADC, 0=high, 1=low
--     CF_FRACTIONBIT : number of valid constant fraction bits
--     ENERGYSCALINGBITS : number of scaling bits for energy adjustment
--     MAX_DIVIDERSCALEBITS : number of scaling bits for division two largest samples
--     MAX_LUTSIZEBITS : number of bits the maximum correction Look Up Table
--     MAX_LUTSCALEBITS : number of scaling bits for the correction on the maximum (energy)
-- 
-- Inputs:
--     slowcontrol_clock : clock for the slowcontrol input/output
--     packet_clock : clock for data from the fiber module
--     MUX_clock : clock from multiplexer, only used for multiplexer status
--     SODA_clock : clock SODA, used to update superburst
--     reset : reset of all components
--     channel : index of the fiber
--     superburst_number : most recent superburst-number
--     superburst_update : new most recent superburst-number+timestamp
--     IO_byte : 5-bits slowcontrol data from CPU
--         Byte0 : Read bit , "000", index of the fiber 
--         Byte1,2,3,4 : alternating: 
--                     request-bit 101 xxxx 24-bits_address(MSB first)
--                     32-bits_data, MSB first
--     IO_write : write signal for byte-data, only selected fiber (with index in first byte) should react
--     muxstat_infifo_fullness : number of words in multiplexer input fifo, report to slowcontrol
--     muxstat_outfifo_fullness : number of words in multiplexer output fifo, report to slowcontrol
--     timestamp_errors : number of timestamp-errors in data stream, report to slowcontrol
--     skipped_pulses : number of pulses skipped due to buffer overflow, report to slowcontrol
--     dataerrors : number of errors in data stream, report to slowcontrol
--     pulse_data_allowed : allowed to write pulse data
--     pulse_data_almostfull : fifo almost full signal from connected fifo
--     wave_data_out_allowed : allowed to write full pileup waveform data (not fifo-full signal from connected fifo)
--     txAsyncFifoFull : fifo-full signal from fiber async data fifo
--     txLocked : signal that transmitter clock is locked
--     rxAsyncDataPresent : receive data available
--     rxAsyncData : receive data 
--     rxNotInTable : received 10 bits was not in conversion table to 8 bits: error!
--     rxLocked : signal that the receiver clock is locked
--
-- Outputs:
--     IO_serialdata : Serial slowcontrol: request&address or data alternating
--     IO_serialavailable : Slowcontrol data is available
--     clearerrors : clear error counters
--     channel_out : 16-bits identification number of the adc
--     statusbyte_out : 8 bits hit-status
--     energy_out : energy of the hit
--     timefraction_out : fractional part of the time within the superburst
--     timestamp_out : time within superburst
--     superburstnumber_out : superburstnumber
--     pulse_data_write :  hit data write signal
--     wave_data_out : 36 bits data with pileup waveforms:
--        	bits(35..32)="0000" : bits(31 downto 16)=Superburstnumber(15..0), bits(15..0)=timestamp of waveform
--        	bits(35..32)="0001" : bits(31)=0 bits(30..0)=SuperBurst number
--        	bits(35..32)="0010" : 
--              bits(31..24) = statusbyte (bit7=overflow) 
--              bits(23..16) = 00
--              bits(15..0) = adcnumber (channel identification)
--        	bits(35..32)="0011" : bits(31..16)=adc sample, bits(15..0)=next adc sample
--        	bits(35..32)="0100" : bits(31..16)=last adc sample, bits(15..0)=0
--        	bits(35..32)="0101" : bits(31..16)=last but one adc sample, bits(15..0)=last adc sample
--        	bits(35..32)="1111" : error: buffer full, waveform not valid
--     wave_data_write : write signal for ileup waveform data
--     txAsyncDataWrite : async data write signal
--     txAsyncData : async data to GTP/GTX/serdes (32 bits)
--     txEndOfAsyncData : indicates last data word
--     rxAsyncClk : clock for async data
--     rxAsyncDataRead : read signal for reading async data from the receiver fifo

-- 
-- Components:
--     DC_slowcontrol_packetbuilder : makes fiber-packet from slowcontrol command
--     DC_slowcontrol_receive_from_cpu : receive byte-wise data from CPU and translate to parallel slowcontrol
--     DC_slowcontrol_to_serial : sends slow control data serially to the CPU
--     DC_separate_data : translate received fiber packets to slowcontrol data, pulse data or waveform
--     synchronize_to_other_clock : synchronize data to other clock
--     DC_measure_frequency : Measure the frequency of the pulses from one fiber
--     DC_posedge_to_pulse : Makes a 1-clock pulse on rising edge from signal with different clock
--     sync_bit : Synchronization for 1 bit cross clock signal
--
----------------------------------------------------------------------------------

entity DC_fibermodule_interface is
	generic (
		NROFADCS                : natural := 16;
		ADCINDEXSHIFT           : natural := 1;
		ADCBITS                 : natural := 14;
		CF_FRACTIONBIT          : natural := 11;
		ENERGYSCALINGBITS       : natural := 13;
		MAX_DIVIDERSCALEBITS    : natural := 12;
		MAX_LUTSIZEBITS         : natural := 8;
		MAX_LUTSCALEBITS        : natural := 14
	);
	port ( 
		slowcontrol_clock       : in std_logic;
		packet_clock            : in std_logic;
		MUX_clock               : in std_logic;
		SODA_clock              : in std_logic;
		reset                   : in std_logic;
		channel                 : in std_logic_vector (3 downto 0);
		superburst_number       : in std_logic_vector(30 downto 0);
		superburst_update       : in std_logic;

-- SlowControl to/from cpu
		IO_byte                 : in std_logic_vector(7 downto 0);
		IO_write                : in std_logic;
		IO_serialdata           : out std_logic;
		IO_serialavailable      : out std_logic;
		
-- multiplexer status
		muxstat_infifo_fullness : in std_logic_vector (15 downto 0);
		muxstat_outfifo_fullness : in std_logic_vector (15 downto 0);
		timestamp_errors        : in std_logic_vector(9 downto 0);
		skipped_pulses          : in std_logic_vector(9 downto 0);
		dataerrors              : in std_logic_vector(9 downto 0);
		clearerrors             : out std_logic;
		
-- Pulse data
		channel_out             : out std_logic_vector(15 downto 0);
		statusbyte_out          : out std_logic_vector(7 downto 0);
		energy_out              : out std_logic_vector(15 downto 0);
		timefraction_out        : out std_logic_vector(11 downto 0);
		timestamp_out           : out std_logic_vector(15 downto 0);
		superburstnumber_out    : out std_logic_vector(30 downto 0);		
		pulse_data_write        : out std_logic;
		pulse_data_allowed      : in std_logic;
		pulse_data_almostfull   : in std_logic;

-- Wave data
		wave_data_out           : out std_logic_vector(35 downto 0);
		wave_data_write         : out std_logic;
		wave_data_out_allowed   : in std_logic;

-- MUX tx interface signals:
		txAsyncDataWrite        : out std_logic;
		txAsyncData             : out std_logic_vector(31 downto 0);
		txEndOfAsyncData        : out std_logic;
		txAsyncFifoFull         : in std_logic;
		txLocked                : in std_logic;

-- MUX rx interface signals:
		rxAsyncClk              : out std_logic;
		rxAsyncDataRead         : out std_logic;
		rxAsyncDataPresent      : in std_logic;
		rxAsyncData             : in std_logic_vector(31 downto 0);
		rxNotInTable            : in std_logic;
		rxLocked                : in std_logic;
		
-- Testpoints
		testword0               : out std_logic_vector (35 downto 0) := (others => '0');
		testword1               : out std_logic_vector (35 downto 0) := (others => '0')
		);
end DC_fibermodule_interface;

architecture Behavioral of DC_fibermodule_interface is

component DC_slowcontrol_packetbuilder is
	port ( 
		clock                   : in std_logic;
		reset                   : in std_logic;
		init_FEE                : in  std_logic; 
		slowcontrol_data        : in std_logic_vector (31 downto 0);
		slowcontrol_address     : in std_logic_vector (23 downto 0);
		slowcontrol_request     : in std_logic;
		slowcontrol_write       : in std_logic; 
		slowcontrol_allowed     : out std_logic; 
		packet_data_out         : out std_logic_vector (31 downto 0);
		packet_lastword         : out std_logic;
		packet_datawrite        : out std_logic;
		packet_fifofull         : in std_logic
	);		
end component;

component DC_slowcontrol_receive_from_cpu is
	port ( 
		clock                   : in std_logic;
		reset                   : in std_logic;
		channel                 : in std_logic_vector (3 downto 0);
		IO_byte                 : in std_logic_vector(7 downto 0);
		IO_write                : in std_logic;
		slowcontrol_data        : out std_logic_vector (31 downto 0);
		slowcontrol_address     : out std_logic_vector (23 downto 0);
		slowcontrol_request     : out std_logic;
		slowcontrol_write       : out std_logic; 
		slowcontrol_fifofull    : in std_logic; 
		error                   : out std_logic
		);
end component;

component DC_slowcontrol_to_serial is
	port ( 
		write_clock             : in std_logic;
		read_clock              : in std_logic;
		reset                   : in std_logic;
		channel                 : in std_logic_vector (3 downto 0);
		slowcontrol_data        : in std_logic_vector (31 downto 0);
		slowcontrol_address     : in std_logic_vector (23 downto 0);
		slowcontrol_reply       : in std_logic;
		slowcontrol_write       : in std_logic;			  
		IO_byte                 : in std_logic_vector (7 downto 0);
		IO_write                : in std_logic;
		IO_serialdata           : out std_logic;
		IO_serialavailable      : out std_logic;
		error                   : out std_logic
		);
end component;

component DC_separate_data is
	generic (
		NROFADCS                : natural := NROFADCS;
		ADCBITS                 : natural := ADCBITS;
		ADCINDEXSHIFT           : natural := ADCINDEXSHIFT;
		CF_FRACTIONBIT          : natural := CF_FRACTIONBIT;
		ENERGYSCALINGBITS       : natural := ENERGYSCALINGBITS;
		MAX_DIVIDERSCALEBITS    : natural := MAX_DIVIDERSCALEBITS;
		MAX_LUTSIZEBITS         : natural := MAX_LUTSIZEBITS;
		MAX_LUTSCALEBITS        : natural := MAX_LUTSCALEBITS
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
		testword0               : out std_logic_vector (35 downto 0));
end component;
		
component synchronize_to_other_clock is
    generic (
        DATA_WIDTH            : natural := 16
    );
    port (
		data_in_clock : in std_logic;
		data_in : in std_logic_vector(DATA_WIDTH-1 downto 0);
		data_out_clock : in std_logic;
		data_out : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end component;

component DC_measure_frequency is
	generic (
		CLOCKFREQUENCY          : natural := 125000000
	);
	port ( 
		clock                   : in std_logic;
		pulse                   : in std_logic;
		frequency               : out std_logic_vector(31 downto 0)
	);
end component;

component MUX_check_timestamp is
	port ( 
		clock                   : in std_logic;
		reset                   : in std_logic;
		clear                   : in std_logic;
		pulse_data              : in std_logic_vector(35 downto 0);
		pulse_data_write        : in std_logic;
		timestamp_errors        : out std_logic_vector(9 downto 0);
		skipped_pulses          : out std_logic_vector(9 downto 0);
		dataerrors              : out std_logic_vector(9 downto 0)
		);
end component;

component DC_posedge_to_pulse is
	port (
		clock_in                : in  std_logic;
		clock_out               : in  std_logic;
		en_clk                  : in  std_logic;
		signal_in               : in  std_logic;
		pulse                   : out std_logic);
end component;

component sync_bit is
	port (
		clock       : in  std_logic;
		data_in     : in  std_logic;
		data_out    : out std_logic
	);
end component;

constant zeros : std_logic_vector(0 to NROFADCS/(ADCINDEXSHIFT+1)-1) := (others => '0');
signal reset_packetclock_S              : std_logic := '0';
signal reset_slowcontrolclock_S         : std_logic := '0';

signal txLocked_S                       : std_logic;
signal rxLocked_S                       : std_logic;

signal boardnumber_S                    : std_logic_vector (15 downto 0) := (others => '0');
signal init_FEE_registers_S             : std_logic := '0';
signal request_init_FEE_registers_S     : std_logic;
signal cmd_init_FEE_registers_S         : std_logic := '0';

signal slowcontrol_tx_data_S            : std_logic_vector (31 downto 0) := (others => '0');
signal slowcontrol_tx_address_S         : std_logic_vector (23 downto 0) := (others => '0');
signal slowcontrol_tx_request_S         : std_logic := '0';
signal slowcontrol_tx_write_S           : std_logic := '0';
signal slowcontrol_tx_write_checked_S   : std_logic := '0';
signal slowcontrol_tx_fifofull_S        : std_logic := '0';
signal slowcontrol_tx_allowed_S         : std_logic := '0';
signal slowcontrol_tx_error_S           : std_logic := '0';
signal slowcontrol_tx_error_async_S     : std_logic := '0';

signal slowcontrol_to_cpu_data_S        : std_logic_vector (31 downto 0) := (others => '0');
signal slowcontrol_to_cpu_address_S     : std_logic_vector (23 downto 0) := (others => '0');
signal slowcontrol_to_cpu_reply_S       : std_logic := '0';
signal slowcontrol_to_cpu_write_S       : std_logic := '0';
signal slowcontrol_to_cpu_error_S       : std_logic := '0';
signal slowcontrol_to_cpu_error_async_S : std_logic := '0';

signal slowcontrol_rx_data_S            : std_logic_vector (31 downto 0) := (others => '0');
signal slowcontrol_rx_address_S         : std_logic_vector (7 downto 0) := (others => '0');
signal slowcontrol_rx_reply_S           : std_logic := '0';
signal slowcontrol_rx_write_S           : std_logic := '0';
signal slowcontrol_tx_enable_S          : std_logic := '0';

signal slowcontrol_insert_data_S        : std_logic_vector (31 downto 0) := (others => '0');
signal slowcontrol_insert_address_S     : std_logic_vector (23 downto 0) := (others => '0');
signal slowcontrol_insert_reply_S       : std_logic := '0';
signal slowcontrol_insert_write_S       : std_logic := '0';

signal IO_serialdata_S                  : std_logic := '0';
signal IO_serialavailable_S             : std_logic := '0';

signal rxAsyncDataRead_S                : std_logic := '0';
signal fiber_data_error_S               : std_logic := '0';
signal fiber_data_error_async_S         : std_logic := '0';

signal rxNotInTable_S                   : std_logic := '0';

signal pulse_skipped_counter_S          : std_logic_vector (7 downto 0) := (others => '0');
signal prev_pulse_skipped_S             : std_logic := '0';

signal pulse_data_write_S               : std_logic := '0';
signal pulse_data_skipped_S             : std_logic := '0';
signal pulse_data_skipped_delayed_S     : std_logic := '0';
signal prev_pulse_data_skipped_S        : std_logic := '0';
signal prev_slowcontrol_tx_error_S      : std_logic := '0';
signal prev_slowcontrol_to_cpu_error_S  : std_logic := '0';
signal prev_fiber_data_error_S          : std_logic := '0';
signal prev_rxNotInTable_S              : std_logic := '0';


signal request_boardnumber_S            : std_logic := '0';
signal request_boardnumber_async_S      : std_logic := '0';
signal prev_request_boardnumber_S       : std_logic := '0';

signal request_status_S                 : std_logic := '0';
signal request_status_async_S           : std_logic := '0';
signal prev_request_status_S            : std_logic := '0';

signal request_muxstat_S                : std_logic := '0';
signal request_muxstat_async_S          : std_logic := '0';
signal prev_request_muxstat_S           : std_logic := '0';

signal request_measurefrequency_S       : std_logic := '0';
signal request_measurefrequency_async_S : std_logic := '0';
signal prev_request_measurefrequency_S  : std_logic := '0';

signal request_timestamperrors_S        : std_logic := '0';
signal request_timestamperrors_async_S  : std_logic := '0';
signal prev_request_timestamperrors_S   : std_logic := '0';

signal clear_errors_async_S             : std_logic := '0';
signal clear_errors_S                   : std_logic := '0';

signal muxstat_infifo_fullness_S        : std_logic_vector(15 downto 0) := (others => '0');
signal muxstat_outfifo_fullness_S       : std_logic_vector(15 downto 0) := (others => '0');

signal pulse_S                          : std_logic := '0';
signal measurefrequency_S               : std_logic_vector(31 downto 0) := (others => '0');
signal measurefrequency_sync_S          : std_logic_vector(31 downto 0) := (others => '0');

signal txAsyncData_S                    : std_logic_vector(31 downto 0) := (others => '0');
signal txAsyncDataWrite_S               : std_logic := '0';
signal txEndOfAsyncData_S               : std_logic := '0';

signal LUT_data_in_S                    : std_logic_vector(CF_FRACTIONBIT-1 downto 0);
signal max_LUT_offset_S                 : std_logic_vector(MAX_LUTSIZEBITS-1 downto 0);
signal max_correction_S                 : std_logic := '0';
signal max_LUT_loading_S                : std_logic := '0';
signal max_LUT_write_S                  : std_logic;
signal fraction_correction_S            : std_logic := '0';
signal fraction_LUT_loading_S           : std_logic := '0';
signal fraction_LUT_write_S             : std_logic;

signal timeshiftLUT_write_S             : std_logic := '0';
signal timeshiftLUT_loading_S           : std_logic := '0';
signal energyLUT_write_S                : std_logic := '0';
signal energyLUT_loading_S              : std_logic := '0';

signal timestamperrors_S                : std_logic_vector(9 downto 0) := (others => '0');
signal timestamperrors_sync_S           : std_logic_vector(9 downto 0) := (others => '0');
signal skipped_pulses_S                 : std_logic_vector(9 downto 0) := (others => '0');
signal skipped_pulses_sync_S            : std_logic_vector(9 downto 0) := (others => '0');
signal dataerrors_S                     : std_logic_vector(9 downto 0) := (others => '0');
signal dataerrors_sync_S                : std_logic_vector(9 downto 0) := (others => '0');


begin

IO_serialdata <= IO_serialdata_S;
IO_serialavailable <= IO_serialavailable_S;
clearerrors <= clear_errors_async_S;


DC_slowcontrol_receive_from_cpu1: DC_slowcontrol_receive_from_cpu port map(
		clock => slowcontrol_clock,
		reset => reset_slowcontrolclock_S,
		channel => channel,
		IO_byte => IO_byte,
		IO_write => IO_write,
		slowcontrol_data => slowcontrol_tx_data_S,
		slowcontrol_address => slowcontrol_tx_address_S,
		slowcontrol_request => slowcontrol_tx_request_S,
		slowcontrol_write => slowcontrol_tx_write_S,
		slowcontrol_fifofull => slowcontrol_tx_fifofull_S,
		error => slowcontrol_tx_error_async_S);
slowcontrol_tx_fifofull_S <= '1' when slowcontrol_tx_allowed_S <= '0' else '0';

DC_slowcontrol_packetbuilder1: DC_slowcontrol_packetbuilder port map(
		clock => slowcontrol_clock,
		reset => reset_slowcontrolclock_S,
		init_FEE => init_FEE_registers_S,
		slowcontrol_data => slowcontrol_tx_data_S,
		slowcontrol_address => slowcontrol_tx_address_S,
		slowcontrol_request => slowcontrol_tx_request_S,
		slowcontrol_write => slowcontrol_tx_write_checked_S,
		slowcontrol_allowed => slowcontrol_tx_allowed_S,
		packet_data_out => txAsyncData_S,
		packet_lastword => txEndOfAsyncData_S,
		packet_datawrite => txAsyncDataWrite_S,
		packet_fifofull => txAsyncFifoFull);
txAsyncData <= txAsyncData_S;
txEndOfAsyncData <= txEndOfAsyncData_S;
txAsyncDataWrite <= txAsyncDataWrite_S;
slowcontrol_tx_write_checked_S <= '1' when 
	(slowcontrol_tx_address_S(23)='0') and (slowcontrol_tx_enable_S='1') and
	(slowcontrol_tx_write_S='1') else '0';

request_init_FEE_registers_S <= '1' when 
		((slowcontrol_rx_address_S=ADDRESS_FEE_REQUESTALLREGISTERS) and 
		(slowcontrol_rx_reply_S='1') and 
		(slowcontrol_rx_write_S='1')) or
		(cmd_init_FEE_registers_S='1')
	else '0';
	
sinc_initFEE1: DC_posedge_to_pulse port map(
	clock_in => packet_clock,
	clock_out => slowcontrol_clock,
	en_clk => '1',
	signal_in => request_init_FEE_registers_S,
	pulse => init_FEE_registers_S);

sync_bit_txLocked: sync_bit port map(
    clock => slowcontrol_clock,
    data_in => txLocked,
    data_out => txLocked_S);

sync_reset_slowcontrolclock: sync_bit port map(
    clock => slowcontrol_clock,
    data_in => reset,
    data_out => reset_slowcontrolclock_S);

process(slowcontrol_clock)
begin
	if rising_edge(slowcontrol_clock) then
		if reset_slowcontrolclock_S='1' then
			slowcontrol_tx_enable_S <= '0';
		else
			if txLocked_S='1' then
				slowcontrol_tx_enable_S <= '1';
			else
				slowcontrol_tx_enable_S <= '0';
			end if;
		end if;
	end if;
end process;

DC_slowcontrol_to_serial1: DC_slowcontrol_to_serial port map(
		write_clock => packet_clock,
		read_clock => slowcontrol_clock,
		reset => reset_packetclock_S,
		channel => channel,
		slowcontrol_data => slowcontrol_to_cpu_data_S,
		slowcontrol_address => slowcontrol_to_cpu_address_S,
		slowcontrol_reply => slowcontrol_to_cpu_reply_S,
		slowcontrol_write => slowcontrol_to_cpu_write_S,
		IO_byte => IO_byte,
		IO_write => IO_write,
		IO_serialdata => IO_serialdata_S,
		IO_serialavailable => IO_serialavailable_S,
		error => slowcontrol_to_cpu_error_async_S);
		

slowcontrol_to_cpu_data_S <= slowcontrol_rx_data_S 
	when (slowcontrol_rx_write_S='1') and (slowcontrol_insert_write_S='0') else 
	slowcontrol_insert_data_S;
		
slowcontrol_to_cpu_address_S <= x"0000" & slowcontrol_rx_address_S 
	when (slowcontrol_rx_write_S='1') and (slowcontrol_insert_write_S='0') else 
	slowcontrol_insert_address_S;
		
slowcontrol_to_cpu_reply_S <= slowcontrol_rx_reply_S 
	when (slowcontrol_rx_write_S='1') and (slowcontrol_insert_write_S='0') else 
	slowcontrol_insert_reply_S;
		
slowcontrol_to_cpu_write_S <= '1' 
	when (slowcontrol_rx_write_S='1') or (slowcontrol_insert_write_S='1') else 
	'0';

sync_muxstat1: synchronize_to_other_clock 
    generic map (
        DATA_WIDTH => 16
    )
	port map(
		data_in_clock => MUX_clock,
		data_in => muxstat_infifo_fullness,
		data_out_clock => packet_clock,
		data_out => muxstat_infifo_fullness_S);
		
--sync_measurefrequency: synchronize_to_other_clock 
--	generic map ( DATA_WIDTH => 32 )
--	port map(
--		data_in_clock => packet_clock,
--		data_in => measurefrequency_S,
--		data_out_clock => packet_clock,
--		data_out => measurefrequency_sync_S);
measurefrequency_sync_S <= measurefrequency_S;

sync_muxstat2: synchronize_to_other_clock 
    generic map (
        DATA_WIDTH => 16
    )
	port map(
		data_in_clock => MUX_clock,
		data_in => muxstat_outfifo_fullness,
		data_out_clock => packet_clock,
		data_out => muxstat_outfifo_fullness_S);

timestamperrors_S <= timestamp_errors;
sync_timestamperrors: synchronize_to_other_clock 
    generic map (
        DATA_WIDTH => 10
    )
	port map(
		data_in_clock => packet_clock,
		data_in => timestamperrors_S,
		data_out_clock => slowcontrol_clock,
		data_out => timestamperrors_sync_S);

skipped_pulses_S <= skipped_pulses;
sync_skipped_pulses: synchronize_to_other_clock 
    generic map (
        DATA_WIDTH => 10
    )
	port map(
		data_in_clock => packet_clock,
		data_in => skipped_pulses_S,
		data_out_clock => slowcontrol_clock,
		data_out => skipped_pulses_sync_S);

dataerrors_S <= dataerrors;
sync_dataerrors: synchronize_to_other_clock 
	generic map ( DATA_WIDTH => 10 )
	port map(
		data_in_clock => packet_clock,
		data_in => dataerrors_S,
		data_out_clock => slowcontrol_clock,
		data_out => dataerrors_sync_S);

sync_bit_rxLocked: sync_bit port map(
    clock => packet_clock,
    data_in => rxLocked,
    data_out => rxLocked_S);

rxAsyncClk <= packet_clock;
pulse_data_write <= pulse_data_write_S;
DC_separate_data1: DC_separate_data port map(
		clock => packet_clock,
		load_clock => slowcontrol_clock,
		SODA_clock => SODA_clock,
		reset => reset_packetclock_S,
		enable => rxLocked_S,
		max_correction => max_correction_S,
		max_LUT_offset => max_LUT_offset_S,
		max_LUT_loading => max_LUT_loading_S,
		max_LUT_write => max_LUT_write_S,
		fraction_correction => fraction_correction_S,
		fraction_LUT_loading => fraction_LUT_loading_S,
		fraction_LUT_write => fraction_LUT_write_S,
		LUT_data_in => LUT_data_in_S,
		timeshiftLUT_write => timeshiftLUT_write_S,
		timeshiftLUT_loading => timeshiftLUT_loading_S,
		timeshiftLUT_data => slowcontrol_tx_data_S(30 downto 0),
		energyLUT_write => energyLUT_write_S,
		energytLUT_loading => energyLUT_loading_S,
		energyLUT_data => slowcontrol_tx_data_S(30 downto 0),
		packet_data_in => rxAsyncData,
		packet_data_present => rxAsyncDataPresent,
		packet_data_read => rxAsyncDataRead_S,
		channel_out => channel_out,
		statusbyte_out => statusbyte_out,
		energy_out => energy_out,
		timefraction_out => timefraction_out,
		timestamp_out => timestamp_out,
		superburstnumber_out => superburstnumber_out,		
		pulse_data_write => pulse_data_write_S,
		pulse_data_allowed => pulse_data_allowed,
		pulse_data_almostfull => pulse_data_almostfull,
		slowcontrol_data => slowcontrol_rx_data_S,
		slowcontrol_address => slowcontrol_rx_address_S,
		slowcontrol_reply => slowcontrol_rx_reply_S,
		slowcontrol_write => slowcontrol_rx_write_S,	  
		wave_data_out => wave_data_out,
		wave_data_write => wave_data_write,
		wave_data_out_allowed => wave_data_out_allowed,
		FEEboardnumber => boardnumber_S,
		superburst_number => superburst_number,
		superburst_update => superburst_update,
		error => fiber_data_error_async_S,
		pulse_data_skipped => pulse_data_skipped_S,
		testword0 => testword1);
rxAsyncDataRead <= rxAsyncDataRead_S;
	 
slowcontrol_check_process: process(slowcontrol_clock)
variable clear_errors_V : std_logic := '0';
begin
	if rising_edge(slowcontrol_clock) then
		timeshiftLUT_write_S <= '0';
		fraction_LUT_write_S <= '0';
		energyLUT_write_S <= '0';
		max_LUT_write_S <= '0';
		cmd_init_FEE_registers_S <= '0';
		if reset_slowcontrolclock_S='1' then
			request_boardnumber_async_S <= '0';
			request_status_async_S <= '0';
			request_muxstat_async_S <= '0';
			request_timestamperrors_async_S <= '0';
			request_measurefrequency_async_S <= '0';
			clear_errors_V := '0';
		else
			if (slowcontrol_tx_write_S='1') and 
					(slowcontrol_tx_address_S=ADDRESS_BOARDNUMBER) and 
					(slowcontrol_tx_request_S='0') then
				boardnumber_S <= slowcontrol_tx_data_S(11 downto 0) & "0000";
				cmd_init_FEE_registers_S <= slowcontrol_tx_data_S(31);
			elsif (slowcontrol_tx_write_S='1') and 
					(slowcontrol_tx_address_S=ADDRESS_BOARDNUMBER) and 
					(slowcontrol_tx_request_S='1') then
				request_boardnumber_async_S <= '1';
			elsif (slowcontrol_tx_write_S='1') and 
					(slowcontrol_tx_address_S=ADDRESS_MUX_FIBERMODULE_STATUS) then
				if (slowcontrol_tx_request_S='1') then
					request_status_async_S <= '1';
				else
					clear_errors_async_S <= '1';
				end if;
			elsif (slowcontrol_tx_write_S='1') and 
					(slowcontrol_tx_address_S=ADDRESS_MUX_MAXCFLUTS) and 
					(slowcontrol_tx_request_S='0') then
				LUT_data_in_S <= slowcontrol_tx_data_S(CF_FRACTIONBIT-1 downto 0);
				if slowcontrol_tx_data_S(26)='1' then 
					max_LUT_write_S <= '1';
				end if;
				max_LUT_loading_S <= slowcontrol_tx_data_S(27);
				max_correction_S <= slowcontrol_tx_data_S(28);
				max_LUT_offset_S <= slowcontrol_tx_data_S(MAX_LUTSIZEBITS+15 downto 16);
				if slowcontrol_tx_data_S(29)='1' then 
					fraction_LUT_write_S <= '1';
				end if;
				fraction_LUT_loading_S <= slowcontrol_tx_data_S(30);
				fraction_correction_S <= slowcontrol_tx_data_S(31);
			elsif (slowcontrol_tx_write_S='1') and 
					(slowcontrol_tx_address_S=ADDRESS_MUX_MULTIPLEXER_STATUS) and 
					(slowcontrol_tx_request_S='1') then
				request_muxstat_async_S <= '1';
			elsif (slowcontrol_tx_write_S='1') and 
					(slowcontrol_tx_address_S=ADDRESS_FEE_MEASURE_FREQUENCY) and 
					(slowcontrol_tx_request_S='1') then
				request_measurefrequency_async_S <= '1';
			elsif (slowcontrol_tx_write_S='1') and 
					(slowcontrol_tx_address_S=ADDRESS_MUX_TIMESTAMP_ERRORS) and 
					(slowcontrol_tx_request_S='1') then
				request_timestamperrors_async_S <= '1';
			elsif (slowcontrol_tx_write_S='1') and 
					(slowcontrol_tx_address_S=ADDRESS_MUX_TIMESHIFT) and 
					(slowcontrol_tx_request_S='0') then
				timeshiftLUT_loading_S <= slowcontrol_tx_data_S(31);
				if (slowcontrol_tx_data_S(31)='1') and (timeshiftLUT_loading_S='1') then
					timeshiftLUT_write_S <= '1';
				end if;
			elsif (slowcontrol_tx_write_S='1') and 
					(slowcontrol_tx_address_S=ADDRESS_MUX_ENERGYCORRECTION) and 
					(slowcontrol_tx_request_S='0') then
				energyLUT_loading_S <= slowcontrol_tx_data_S(31);
				if (slowcontrol_tx_data_S(31)='1') and (energyLUT_loading_S='1') then
					energyLUT_write_S <= '1';
				end if;
			else
				if request_boardnumber_S='1' then
					request_boardnumber_async_S <= '0';
				end if;
				if request_status_S='1' then 
					request_status_async_S <= '0';
				end if;
				if request_muxstat_S='1' then 
					request_muxstat_async_S <= '0';
				end if;
				if request_measurefrequency_S='1' then 
					request_measurefrequency_async_S <= '0';
				end if;
				if request_timestamperrors_S='1' then 
					request_timestamperrors_async_S <= '0';
				end if;
			end if;
			if clear_errors_V='1' then
				clear_errors_async_S <= '0';
			end if;
			clear_errors_V := clear_errors_S;
		end if;
	end if;
end process;

sync_reset_packetclock: sync_bit port map(
	clock => packet_clock,
	data_in => reset,
	data_out => reset_packetclock_S);

pulse_skip_process: process(packet_clock)
begin
	if rising_edge(packet_clock) then
		if (reset_packetclock_S='1') or (clear_errors_S='1') then
			pulse_skipped_counter_S <= (others => '0');
			prev_pulse_skipped_S <= '0';
		else
			if (pulse_data_skipped_S='1') and (prev_pulse_skipped_S='0') then
				if pulse_skipped_counter_S/=x"ff" then
					pulse_skipped_counter_S <= pulse_skipped_counter_S+1;
				end if;
			end if;
			prev_pulse_skipped_S <= pulse_data_skipped_S;
		end if;
	end if;
end process;

sync_bit_rxNotInTable: sync_bit port map(
    clock => packet_clock,
    data_in => rxNotInTable,
    data_out => rxNotInTable_S);
	
slowcontrol_insert_process: process(packet_clock)
variable send_boardnumber_V               : std_logic := '0';
variable send_error_V                     : std_logic := '0';
variable send_muxstat_V                   : std_logic := '0';
variable send_measurefrequency_V          : std_logic := '0';
variable send_timestamperrors_V           : std_logic := '0';
variable pulse_data_skipped_sent_V        : std_logic := '0';
variable slowcontrol_tx_error_sent_V      : std_logic := '0';
variable slowcontrol_to_cpu_error_sent_V  : std_logic := '0';
variable fiber_data_error_sent_V          : std_logic := '0';
variable rxNotInTable_sent_V              : std_logic := '0';
variable request_boardnumber_sent_V       : std_logic := '0';
variable request_status_sent_V            : std_logic := '0';
variable request_muxstat_sent_V           : std_logic := '0';
variable request_measurefrequency_sent_V  : std_logic := '0';
variable request_timestamperrors_sent_V   : std_logic := '0';
begin
	if rising_edge(packet_clock) then
		if (slowcontrol_insert_write_S='1') and (slowcontrol_rx_write_S='1') then -- unsuccessful write
			slowcontrol_insert_write_S <= '1';
		else
			send_error_V := '0';
			if (pulse_data_skipped_delayed_S='1') and (prev_pulse_data_skipped_S='0') and (pulse_data_skipped_sent_V='0') then
				pulse_data_skipped_sent_V := '1';
				send_error_V := '1';
			end if;
			if (slowcontrol_tx_error_S='1') and (prev_slowcontrol_tx_error_S='0') and (slowcontrol_tx_error_sent_V='0') then
				slowcontrol_tx_error_sent_V := '1';
				send_error_V := '1';
			end if;
			if (slowcontrol_to_cpu_error_S='1') and (prev_slowcontrol_to_cpu_error_S='0') and (slowcontrol_to_cpu_error_sent_V='0') then
				slowcontrol_to_cpu_error_sent_V := '1';
				send_error_V := '1';
			end if;
			if (fiber_data_error_S='1') and (prev_fiber_data_error_S='0') and (fiber_data_error_sent_V='0') then
				fiber_data_error_sent_V := '1';
				send_error_V := '1';
			end if;
			if (rxNotInTable_S='1') and (prev_rxNotInTable_S='0') and (rxNotInTable_sent_V='0') then
				rxNotInTable_sent_V := '1';
				send_error_V := '1';
			end if;
			if (request_boardnumber_S='1') and (prev_request_boardnumber_S='0') and (request_boardnumber_sent_V='0') then
				request_boardnumber_sent_V := '1';
				send_boardnumber_V := '1';
			end if;
			if (request_status_S='1') and (prev_request_status_S='0') and (request_status_sent_V='0') then
				request_status_sent_V := '1';
				send_error_V := '1';
			end if;
			if (request_muxstat_S='1') and (prev_request_muxstat_S='0') and (request_muxstat_sent_V='0') then
				request_muxstat_sent_V := '1';
				send_muxstat_V := '1';
			end if;
			if (request_measurefrequency_S='1') and (prev_request_measurefrequency_S='0') and (request_measurefrequency_sent_V='0') then
				request_measurefrequency_sent_V := '1';
				send_measurefrequency_V := '1';
			end if;
			if (request_timestamperrors_S='1') and (prev_request_timestamperrors_S='0') and (request_timestamperrors_sent_V='0') then
				request_timestamperrors_sent_V := '1';
				send_timestamperrors_V := '1';
			end if;				
			if send_error_V='1' then			
				slowcontrol_insert_data_S(0) <= slowcontrol_to_cpu_error_sent_V;
				slowcontrol_insert_data_S(1) <= slowcontrol_tx_error_sent_V;
				slowcontrol_insert_data_S(2) <= fiber_data_error_sent_V;
				slowcontrol_insert_data_S(3) <= rxNotInTable_sent_V;
				slowcontrol_insert_data_S(4) <= pulse_data_skipped_sent_V;
				slowcontrol_insert_data_S(5) <= rxLocked_S;					
				slowcontrol_insert_data_S(7 downto 6) <= (others => '0');
				slowcontrol_insert_data_S(15 downto 8) <= pulse_skipped_counter_S;
				slowcontrol_insert_data_S(31 downto 16) <= (others => '0');
				slowcontrol_insert_address_S <= ADDRESS_MUX_FIBERMODULE_STATUS;
				slowcontrol_insert_reply_S <= request_status_S or request_status_sent_V;
				slowcontrol_insert_write_S <= '1';
				request_status_sent_V := '0';
			elsif send_boardnumber_V='1' then
				slowcontrol_insert_data_S(31 downto 12) <= (others => '0');
				slowcontrol_insert_data_S(11 downto 0) <= boardnumber_S(15 downto 4);
				slowcontrol_insert_address_S <= ADDRESS_BOARDNUMBER;
				slowcontrol_insert_reply_S <= '1';
				slowcontrol_insert_write_S <= '1';				
				request_boardnumber_sent_V := '0';
				send_boardnumber_V := '0';
			elsif send_muxstat_V='1' then			
				slowcontrol_insert_data_S(31 downto 16) <= muxstat_outfifo_fullness_S;
				slowcontrol_insert_data_S(15 downto 0) <= muxstat_infifo_fullness_S;
				slowcontrol_insert_address_S <= ADDRESS_MUX_MULTIPLEXER_STATUS;
				slowcontrol_insert_reply_S <= '1';
				slowcontrol_insert_write_S <= '1';				
				request_muxstat_sent_V := '0';
				send_muxstat_V := '0';
			elsif send_measurefrequency_V='1' then			
				slowcontrol_insert_data_S(31 downto 0) <= measurefrequency_sync_S;
				slowcontrol_insert_address_S <= x"0000" & ADDRESS_FEE_MEASURE_FREQUENCY;
				slowcontrol_insert_reply_S <= '1';
				slowcontrol_insert_write_S <= '1';				
				request_measurefrequency_sent_V := '0';
				send_measurefrequency_V := '0';
			elsif send_timestamperrors_V='1' then			
				slowcontrol_insert_data_S(31 downto 0) <= "00" & dataerrors_sync_S & skipped_pulses_sync_S & timestamperrors_sync_S;
				slowcontrol_insert_address_S <= ADDRESS_MUX_TIMESTAMP_ERRORS;
				slowcontrol_insert_reply_S <= '1';
				slowcontrol_insert_write_S <= '1';				
				request_timestamperrors_sent_V := '0';					
				send_timestamperrors_V := '0';
			else
				slowcontrol_insert_write_S <= '0';
				if clear_errors_S='1' then
					slowcontrol_to_cpu_error_sent_V := '0';
					slowcontrol_tx_error_sent_V := '0';
					fiber_data_error_sent_V := '0';
					rxNotInTable_sent_V := '0';
					pulse_data_skipped_sent_V := '0';
				end if;
			end if;
			request_boardnumber_S <= request_boardnumber_async_S;
			request_status_S <= request_status_async_S;
			request_muxstat_S <= request_muxstat_async_S;
			request_measurefrequency_S <= request_measurefrequency_async_S;
			request_timestamperrors_S <= request_timestamperrors_async_S;
			slowcontrol_tx_error_S <= slowcontrol_tx_error_async_S;
			slowcontrol_to_cpu_error_S <= slowcontrol_to_cpu_error_async_S;
			fiber_data_error_S <= fiber_data_error_async_S;
			
			prev_slowcontrol_to_cpu_error_S <= slowcontrol_to_cpu_error_S;
			prev_pulse_data_skipped_S <= pulse_data_skipped_delayed_S;
			pulse_data_skipped_delayed_S <= pulse_data_skipped_S; -- delay one clock cycle to allow the proper count-value to be sent
			prev_slowcontrol_tx_error_S <= slowcontrol_tx_error_S;
			prev_fiber_data_error_S <= fiber_data_error_S;
			prev_rxNotInTable_S <= rxNotInTable_S;
			prev_request_boardnumber_S <= request_boardnumber_S;
			prev_request_status_S <= request_status_S;
			prev_request_muxstat_S <= request_muxstat_S;
			prev_request_measurefrequency_S <= request_measurefrequency_S;
			prev_request_timestamperrors_S <= request_timestamperrors_S;
			clear_errors_S <= clear_errors_async_S;
		end if;
	end if;
end process;

DC_measure_frequency1: DC_measure_frequency port map(
		clock => packet_clock,
		pulse => pulse_S,
		frequency => measurefrequency_S);
pulse_S  <= '1' when (pulse_data_write_S='1') and (pulse_data_allowed='1') else '0';
	
testword0(31 downto 0) <= rxAsyncData;
testword0(32) <= rxAsyncDataPresent;
testword0(33) <= rxAsyncDataRead_S;
testword0(34) <= rxLocked_S;
testword0(35) <= wave_data_out_allowed;



end Behavioral;
