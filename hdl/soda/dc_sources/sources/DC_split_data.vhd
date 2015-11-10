----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   04-03-2014
-- Module Name:   DC_split_data 
-- Description:   Read and interprets data from Front End Electronics
-- Modifications:
--   30-07-2014   Timestamp from FEE is now composed by 16 bits superburstnumber and timestamp counter within superburst
--   11-09-2014   New name, new fiber data structure; removed correction LUTs (will be done separately)
--   11-10-2014   Energy is measured with integral, not with the maximum
--   15-09-2015   First word in output waveform data contains now also 16 bits of the Superburstnumber
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;
USE work.panda_package.all;

----------------------------------------------------------------------------------
-- DC_split_data
-- Gets packet data from the fiber receive module and separate pulse-data, waveforms and slowcontrol.
-- The waveforms are assigned to a superburst number, based on timestamp.
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
--
--
--
-- Library:
--     work.panda_package :  for type declarations and constants
-- 
-- Generics:
--     NROFADCS : number of ADCs in the FEE: total high and low gain ADCs 
--     ADCINDEXSHIFT : ADC channel numbers lowest bit indicates the high or low gain ADC, 0=high, 1=low
--     CF_FRACTIONBIT : number of valid constant fraction bits
-- 
-- Inputs:
--     clock : clock input : fiber receiver clock
--     SODA_clock : clock SODA, used for superburstnumber
--     reset : synchronous reset
--     enable : enable datareading from receiver
--     FEEboardnumber : number of the board, this is added to the ADC channel number for the final ADC channel identification
--     packet_data_in : 32 bits data input from fiber module
--     packet_data_present : data available from fiber module
--     pulse_allowed : output data writing allowed  : not fifo-almostfull of connected fifo
--     wave_data_out_allowed : output of full waveform writing allowed : possible to write 254 samples!!
--     superburst_number : most recent superburst-number
--     superburst_update : new most recent superburst-number+timestamp
-- 
-- Outputs:
--     packet_data_read : read signal to fiber module to read next data
--     pulse_superburst : lowest 16-bits of the superburstnumber of the hit
--     pulse_timestamp : 16-bits timestamp within superburst (time of sample before the CF zero crossing)
--     pulse_adcnumber : 16-bits adc channel number
--     pulse_statusbyte : 8-bits status
--     pulse_energy : energy of the pulse, measured with scaled integral
--     pulse_CF_before : CF_signal value of the value before the zero-crossing (absolute value)
--     pulse_CF_after : CF_signal value of the value after the zero-crossing (absolute value)
--     pulse_write : write signal for pulsedata
--     slowcontrol_data : slow-control command : data 32-bits 
--     slowcontrol_address : slow-control command : only FEE part: address 8-bits 
--     slowcontrol_reply : indicates if the slow-control is a reply, or a independent message
--     slowcontrol_write : write of slow-control data/address/reply
--     wave_data_out : data with waveform: 36-bits words with bits 35..32 as index
--        	bits(35..32)="0000" : bits(31 downto 16)=Superburstnumber(15..0), bits(15..0)=timestamp within superburst in waveform
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
--     pulse_data_skipped : data remove due to full connected fifo
--     data_error : error in packet-data : CRC-error, hamming-code error, error in data bits
--
-- Components:
--     crc8_add_check32 : add and checks a CRC8 code to a stream of 32 bits data words
-- 
----------------------------------------------------------------------------------

entity DC_split_data is
	generic (
		NROFADCS                : natural := 32;
		ADCINDEXSHIFT           : natural := 1;
		CF_FRACTIONBIT          : natural := 11
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
end DC_split_data;

architecture Behavioral of DC_split_data is

component crc8_add_check32 is 
   port(           
		clock                   : in  std_logic; 
		reset                   : in  std_logic; 
		data_in                 : in  std_logic_vector(31 DOWNTO 0); 
		data_in_valid           : in  std_logic; 
		data_in_last            : in  std_logic; 
		data_out                : out std_logic_vector(31 DOWNTO 0); 
		data_out_valid          : out std_logic;
		data_out_last           : out std_logic;
		crc_error               : out std_logic
       );
end component; 

--     PASTSUPERBURSTBITS : number of bits for data array remembering previous SUPERBURSTS, depends on data latency from FEE
constant PASTSUPERBURSTBITS         : natural := 3;
constant zeros                      : std_logic_vector(31 downto 0) := (others => '0');

type superbursttime_type is array (0 to 2**PASTSUPERBURSTBITS-1) of std_logic_vector (15 downto 0);
type superbursts_type is array (0 to 2**PASTSUPERBURSTBITS-1) of std_logic_vector (30 downto 0);
 
type rec_state_type is (init,expect_first,data1,data2,data3,slow1,wave1,wave2,wave3,wave4,wave5);
signal rec_state_S                  : rec_state_type := init;

signal superburst_numbers0_S        : superbursts_type := (others => (others => '0'));
signal superburst_numbers_S         : superbursts_type;

signal FEEboardnumber_S             : std_logic_vector (15 downto 0);
signal reset_S                      : std_logic := '0';
signal error_S                      : std_logic := '0';
signal enable_S                     : std_logic := '0';
signal packet_data_read_S           : std_logic := '0';
signal packet_data_valid_S          : std_logic := '0';

signal crc8_data_in_S               : std_logic_vector (31 downto 0) := (others => '0');
signal crc8_data_in_valid_S         : std_logic := '0';
signal crc8_data_in_last_S          : std_logic := '0';
signal crc8_data_out_S              : std_logic_vector (31 downto 0) := (others => '0');
signal crc8_data_out_valid_S        : std_logic := '0';
signal crc8_data_out_last_S         : std_logic := '0';
signal crc8_error_S                 : std_logic := '0';
signal crc8_dataerror_S             : std_logic := '0';
signal datapacketcounter_S          : integer range 0 to 3 := 0; 
signal slowpacketvalid_S            : std_logic := '0';
signal crc8_slowerror_S             : std_logic := '0';
	
signal pulse_superburst16_S         : std_logic_vector (15 downto 0);
signal pulse_timestamp_S            : std_logic_vector (15 downto 0);
signal pulse_adc_number_S           : std_logic_vector (15 downto 0);
signal pulse_energy_S               : std_logic_vector (15 downto 0);
signal pulse_CF_before_S            : std_logic_vector (15 downto 0);
signal pulse_CF_after_S             : std_logic_vector (15 downto 0);
signal pulse_statusbyte_S           : std_logic_vector (7 downto 0);

signal wave_superburst16_S          : std_logic_vector (15 downto 0);
signal wave_adc_number_S            : std_logic_vector (15 downto 0);
signal wave_statusbyte_S            : std_logic_vector (7 downto 0);

signal pulse_valid_S                : std_logic;
signal pulse_data_write_S           : std_logic;
signal pulse_data_skipped_S         : std_logic := '0';

signal wave_data_out_S              : std_logic_vector (35 downto 0);
signal wave_data_write_S            : std_logic := '0';
signal wave_overflow_S              : std_logic := '0';
signal wave_valid_S                 : std_logic := '0';
signal wave_allow_write_S           : std_logic := '1';
signal wave_last_singledata_S       : std_logic := '0';
signal wave_overflow_occurred_S     : std_logic := '0';
signal wave_superburstmissed_S      : std_logic := '0';
signal wave_superburstnr_S          : std_logic_vector (30 downto 0);

signal adcsample0_S                 : std_logic_vector (15 downto 0);
signal adcsample1_S                 : std_logic_vector (15 downto 0);


begin

pulse_data_skipped <= '1' when (pulse_data_skipped_S='1') or (wave_overflow_S='1') else '0';
data_error <= '1' when (error_S='1') else '0';

process(SODA_clock)
begin
	if rising_edge(SODA_clock) then
		if superburst_update='1' then
			superburst_numbers0_S(conv_integer(unsigned(superburst_number(PASTSUPERBURSTBITS-1 downto 0)))) <= superburst_number;
		end if;
	end if;
end process;

process(clock)
begin
	if rising_edge(clock) then
		superburst_numbers_S <= superburst_numbers0_S;
		reset_S <= reset;
		FEEboardnumber_S <= FEEboardnumber;
	end if;
end process;
			

packet_data_read <= packet_data_read_S;
packet_data_read_S <= '1' when (packet_data_present='1') and (rec_state_S/=init) and (rec_state_S/=wave2) else '0';

crc8_data_in_S <= packet_data_in;
crc8_data_in_valid_S <= '1' when (packet_data_valid_S='1') or (rec_state_S=init) else '0';
crc8_data_in_last_S <= 
	'1' when (rec_state_S=data3)
			or (rec_state_S=slow1) 
			or (rec_state_S=init) 
			or ((rec_state_S=wave5) and (packet_data_valid_S='1') and (packet_data_in(15)='1'))
		else '0';

crc8check: crc8_add_check32 port map(
	  clock          => clock,
	  reset          => reset_S,
	  data_in        => crc8_data_in_S,
	  data_in_valid  => crc8_data_in_valid_S,
	  data_in_last   => crc8_data_in_last_S, 
	  data_out       => crc8_data_out_S,
	  data_out_valid => crc8_data_out_valid_S,
	  data_out_last  => crc8_data_out_last_S,
	  crc_error      => crc8_error_S);

wave_data_out <= wave_data_out_S;
wave_data_write <= wave_data_write_S;

inputdatahandling: process(clock)
variable timeoutcounter_V        : integer range 0 to 15 := 0;
variable superburstnr_V          : std_logic_vector(30 downto 0);
variable statusbyte_V            : std_logic_vector(7 downto 0);
begin
	if rising_edge(clock) then
		pulse_valid_S <= '0';
		if reset_S='1' then
			error_S <= '0';
			pulse_valid_S <= '0';
			rec_state_S <= init;
			wave_valid_S <= '0';
			wave_allow_write_S <= '1';
			wave_last_singledata_S <= '0';
			wave_overflow_S <= '0';
			wave_overflow_occurred_S <= '0'; 
			wave_superburstmissed_S <= '0';
		elsif (crc8_dataerror_S='1') or (crc8_slowerror_S='1') then
			error_S <= '1';
			rec_state_S <= init;
		else
			case rec_state_S is
				when init =>
					timeoutcounter_V := 0;
					error_S <= '0';
					if wave_valid_S='1' then
						wave_valid_S <= '0';
						if error_S='1' then
							wave_data_out_S <= "1111" & x"00000000";
							wave_data_write_S <= wave_allow_write_S;
						else
							wave_data_write_S <= '0';
						end if;
					else
						wave_data_write_S <= '0';
					end if;
					if enable_S ='1' then
						rec_state_S <= expect_first;
					end if;
				when expect_first =>
					if wave_valid_S='1' then
						wave_valid_S <= '0';
						if (crc8_data_out_valid_S='1') and (crc8_data_out_last_S='1') and (crc8_error_S='0') then -- everything ok
							if wave_last_singledata_S='1' then
								wave_data_out_S <= "0100" & adcsample0_S & x"0000";
								wave_data_write_S <= wave_allow_write_S;
							else
								wave_data_write_S <= wave_allow_write_S;
							end if;
						else
							wave_data_out_S <= "1111" & x"00000000";
							wave_data_write_S <= wave_allow_write_S;
						end if;
					else
						wave_data_write_S <= '0';
					end if;					
					timeoutcounter_V := 0;
					if enable_S='0' then
						rec_state_S <= init;
					else
						if packet_data_valid_S='1' then
							if packet_data_in(31 downto 24)=x"DA" then -- pulse data
								pulse_adc_number_S <= (x"00" & packet_data_in(23 downto 16)) + FEEboardnumber_S;
								pulse_superburst16_S <= packet_data_in(15 downto 0);
								error_S <= '0';
								wave_overflow_S <= '0';
								rec_state_S <= data1;
							elsif packet_data_in(31 downto 24)=x"AF" then -- waveform
								wave_adc_number_S <= (x"00" & packet_data_in(23 downto 16)) + FEEboardnumber_S;
								wave_superburst16_S <= packet_data_in(15 downto 0);
								wave_allow_write_S <= wave_data_out_allowed;
								if wave_data_out_allowed='1' then
									wave_overflow_S <= '0';
								else
									wave_overflow_occurred_S <= '1';
									wave_overflow_S <= '1';
								end if;
								error_S <= '0';
								rec_state_S <= wave1;
							elsif packet_data_in(31 downto 24)=x"5C" then -- slowcontrol
								slowcontrol_address <= packet_data_in(23 downto 16);
								slowcontrol_reply <= packet_data_in(15);
								slowcontrol_data(31 downto 24) <= packet_data_in(7 downto 0);
								error_S <= '0';
								rec_state_S <= slow1;
							else -- error
								error_S <= '1';
								rec_state_S <= init;
							end if;
						else
							rec_state_S <= expect_first;
						end if;
					end if;
				when data1 =>
					wave_valid_S <= '0';
					wave_data_write_S <= '0';
					if packet_data_valid_S='1' then
						timeoutcounter_V := 0;
						pulse_energy_S <= packet_data_in(15 downto 0);
						rec_state_S <= data2;
					else
						if timeoutcounter_V=15 then
							error_S <= '1';
							rec_state_S <= init;
						else
							timeoutcounter_V := timeoutcounter_V+1;
							rec_state_S <= data1;
						end if;
					end if;
				when data2 =>
					wave_valid_S <= '0';
					wave_data_write_S <= '0';
					if packet_data_valid_S='1' then
						timeoutcounter_V := 0;
						pulse_CF_before_S <= packet_data_in(31 downto 16);
						pulse_CF_after_S <= packet_data_in(15 downto 0);
						rec_state_S <= data3;
					else
						if timeoutcounter_V=15 then
							error_S <= '1';
							rec_state_S <= init;
						else
							timeoutcounter_V := timeoutcounter_V+1;
							rec_state_S <= data2;
						end if;
					end if;
				when data3 =>
					wave_data_write_S <= '0';
					wave_valid_S <= '0';
					if packet_data_valid_S='1' then
						timeoutcounter_V := 0;
						pulse_timestamp_S <= packet_data_in(31 downto 16);
						pulse_valid_S <= '1';
						statusbyte_V := packet_data_in(15 downto 8);
						if pulse_data_skipped_S='1' then
							statusbyte_V := statusbyte_V or STATBYTE_DCPULSESKIPPED;
						end if;
						if wave_overflow_occurred_S='1' then
							statusbyte_V := statusbyte_V or STATBYTE_DCWAVESKIPPED;
							wave_overflow_occurred_S <= '0';
						end if;
						if wave_superburstmissed_S='1' then
							statusbyte_V := statusbyte_V or STATBYTE_DCSUPERBURSTMISSED;
							wave_superburstmissed_S <= '0';
						end if;
						pulse_statusbyte_S <= statusbyte_V;
						rec_state_S <= expect_first;
					else
						if timeoutcounter_V=15 then
							error_S <= '1';
							rec_state_S <= init;
						else
							timeoutcounter_V := timeoutcounter_V+1;
							rec_state_S <= data3;
						end if;
					end if;
					
				when slow1 =>
					wave_data_write_S <= '0';
					wave_valid_S <= '0';
					if packet_data_valid_S='1' then
						timeoutcounter_V := 0;
						slowcontrol_data(23 downto 0) <= packet_data_in(31 downto 8);
						rec_state_S <= expect_first;
					else
						if timeoutcounter_V=15 then
							error_S <= '1';
							rec_state_S <= init;
						else
							timeoutcounter_V := timeoutcounter_V+1;
							rec_state_S <= slow1;
						end if;
					end if;

				when wave1 =>
					if packet_data_valid_S='1' then
						wave_valid_S <= '0';
						timeoutcounter_V := 0;
						superburstnr_V := superburst_numbers_S(conv_integer(unsigned(wave_superburst16_S(PASTSUPERBURSTBITS-1 downto 0))));						
						wave_data_out_S <= "0000" & superburstnr_V(15 downto 0) & packet_data_in(31 downto 16); -- timestamp 16 bits
						if (wave_overflow_occurred_S='1') and (wave_allow_write_S='1') then
							wave_statusbyte_S(7 downto 0) <= packet_data_in(7 downto 0) or STATBYTE_DCWAVESKIPPED;
							wave_overflow_occurred_S <= '0';
						else
							wave_statusbyte_S <= packet_data_in(7 downto 0);
						end if;
						wave_superburstnr_S <= superburstnr_V;
						if superburstnr_V(15 downto 0) /= wave_superburst16_S then
							wave_data_write_S <= '0';
							wave_allow_write_S <= '0';
							wave_superburstmissed_S <= '1';
							wave_overflow_occurred_S <= '1';
							wave_overflow_S <= '1';
							rec_state_S <= wave2;
						else
							wave_data_write_S <= wave_allow_write_S;
							rec_state_S <= wave2;
						end if;
					else
						wave_data_write_S <= '0';
						if timeoutcounter_V=15 then
							wave_valid_S <= '1';
							error_S <= '1';
							rec_state_S <= init;
						else
							wave_valid_S <= '0';
							timeoutcounter_V := timeoutcounter_V+1;
						end if;
					end if;
				when wave2 =>
					wave_data_out_S <= "0001" & '0' & wave_superburstnr_S;
					wave_data_write_S <= wave_allow_write_S;
					wave_valid_S <= '0';
					timeoutcounter_V := 0;
					if packet_data_valid_S='1' then
						adcsample0_S <= packet_data_in(30) & packet_data_in(30 downto 16);
						adcsample1_S <= packet_data_in(14) & packet_data_in(14 downto 0);
						rec_state_S <= wave3;
					else
						rec_state_S <= wave4;
					end if;
				when wave3 =>
					wave_data_out_S <= "0010" & wave_statusbyte_S & x"00" & wave_adc_number_S;
					wave_data_write_S <= wave_allow_write_S;
					wave_valid_S <= '0';
					timeoutcounter_V := 0;
					rec_state_S <= wave5;
				when wave4 =>
					if packet_data_valid_S='1' then
						wave_valid_S <= '0';
						timeoutcounter_V := 0;
						adcsample0_S <= packet_data_in(30) & packet_data_in(30 downto 16);
						adcsample1_S <= packet_data_in(14) & packet_data_in(14 downto 0);
						wave_data_out_S <= "0010" & wave_statusbyte_S & x"00" & wave_adc_number_S;
						wave_data_write_S <= wave_allow_write_S;
						wave_valid_S <= '0';
						timeoutcounter_V := 0;
						rec_state_S <= wave5;
					else
						wave_data_write_S <= '0';
						if timeoutcounter_V=15 then
							wave_valid_S <= '1';
							error_S <= '1';
							rec_state_S <= init;
						else
							wave_valid_S <= '0';
							timeoutcounter_V := timeoutcounter_V+1;
						end if;
					end if;
				when wave5 =>
					if packet_data_valid_S='1' then
						timeoutcounter_V := 0;
						if (packet_data_in(31)='0') and (packet_data_in(15)='0') then -- 2 samples
							wave_data_out_S <= "0011" & adcsample0_S & adcsample1_S;
							wave_data_write_S <= wave_allow_write_S;
							adcsample0_S <= packet_data_in(30) & packet_data_in(30 downto 16);
							adcsample1_S <= packet_data_in(14) & packet_data_in(14 downto 0);
						elsif (packet_data_in(31)='1') and (packet_data_in(15)='1') then -- 1 sample and CRC
							wave_data_out_S <= "0011" & adcsample0_S & adcsample1_S;
							wave_data_write_S <= wave_allow_write_S;
							adcsample0_S <= packet_data_in(30) & packet_data_in(30 downto 16);
							wave_last_singledata_S <= '1';
							wave_valid_S <= '1';
							rec_state_S <= expect_first;
						elsif (packet_data_in(31)='0') and (packet_data_in(15)='1') then -- 0 samples and CRC
							wave_data_out_S <= "0101" & adcsample0_S & adcsample1_S;
							wave_data_write_S <= '0'; -- check CRC first
							wave_last_singledata_S <= '0';
							wave_valid_S <= '1';
							rec_state_S <= expect_first;
						else -- error
							wave_valid_S <= '1';
							error_S <= '1';
							rec_state_S <= init;
						end if;
					else
						wave_data_write_S <= '0';
						if timeoutcounter_V=15 then
							wave_valid_S <= '1';
							error_S <= '1';
							rec_state_S <= init;
						else
							wave_valid_S <= '0';
							timeoutcounter_V := timeoutcounter_V+1;
						end if;
					end if;
			end case;
		end if;
		enable_S <= enable;
		packet_data_valid_S <= packet_data_read_S;
	end if;
end process inputdatahandling;


pulse_superburst <= pulse_superburst16_S;
pulse_timestamp <= pulse_timestamp_S;
pulse_adcnumber <= pulse_adc_number_S;
pulse_statusbyte <= pulse_statusbyte_S;
pulse_energy <= pulse_energy_S;
pulse_CF_before <= pulse_CF_before_S;
pulse_CF_after <= pulse_CF_after_S;

pulse_write <= '1' when (pulse_data_write_S='1') and (pulse_allowed='1') else '0';
pulse_data_write_S <= '1' when (pulse_valid_S='1') and (crc8_data_out_valid_S='1') and (crc8_data_out_last_S='1') and (crc8_error_S='0') else '0';
crc8_dataerror_S <= '1' when (pulse_valid_S='1') and (pulse_data_write_S='0') else '0';

pulseskippedhandling: process(clock)								
begin
	if rising_edge(clock) then
		if reset_S='1' then
			pulse_data_skipped_S <= '0';
		else
			if (pulse_data_write_S='1') and (pulse_allowed='0') then
				pulse_data_skipped_S <= '1';
			elsif (pulse_data_write_S='1') and (pulse_allowed='1') then
				pulse_data_skipped_S <= '0';
			end if;
		end if;
	end if;
end process;

slowcontrolpackethandling: process(clock)
begin
	if rising_edge(clock) then
		if reset_S='1' then
			slowcontrol_write <= '0';
			slowpacketvalid_S <= '0';
			crc8_slowerror_S <= '0';
		else
			if slowpacketvalid_S='0' then
				slowcontrol_write <= '0';
				crc8_slowerror_S <= '0';
				if (rec_state_S=slow1) and (packet_data_valid_S='1') then
					slowpacketvalid_S <= '1';			
				end if;
			else
				slowpacketvalid_S <= '0';
				if (crc8_data_out_valid_S='1') and (crc8_data_out_last_S='1') and (crc8_error_S='0') then -- everything ok
					slowcontrol_write <= '1';
					crc8_slowerror_S <= '0';
				else
					slowcontrol_write <= '0';
					crc8_slowerror_S <= '1';
				end if;
			end if;
		end if;
	end if;
end process slowcontrolpackethandling;


testword0 <= (others => '0');


end Behavioral;

