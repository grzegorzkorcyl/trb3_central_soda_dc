----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   11-09-2014
-- Module Name:   DC_time_energy_LUTs 
-- Description:   Performs correction on time and energy of pulses
-- Modifications:
--   18-09-2014   different clock for loading LUTs
--   21-05-2015   Additional clock synchronization for superburst
--   02-10-2015   Output data now with hit-data members instead of 36-bits data
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;
USE work.panda_package.all;

----------------------------------------------------------------------------------
-- DC_time_energy_LUTs
-- Performs correction on time and energy of pulses: 
--    offset for time (timestamp+fraction) of each ADC-channel
--    offset and gain (scaling) for energy of each ADC-channel
--
-- The hits are assigned to a superburst number, based on timestamp/timefraction.
-- The SODA superburstnumbers and duration from a few superburst in the past are stored to 
-- make this possible if the hits arrive late due to buffering.
-- If the hit arrive too late then the hit is skipped. This is reported on the next hit and status bit.
-- 
--
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
--     ADCINDEXSHIFT : ADC channel numbers lowest bit indicates the high or low gain ADC, 0=high, 1=low
--     CF_FRACTIONBIT : number of valid constant fraction bits
--     ENERGYSCALINGBITS : number of scaling bits for energy adjustment: energy = (original_energy * gainfactor<<scalingbits)>>scalingbits
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
--     datain_write : write signal for the pulse data
--     adcnumber : 16-bits identification number of the adc
--     superburst : lowest 16 bits of the superburstnumber
--     timestamp : 16 bits timestamp of the CF_signal before the zero-crossing
--     timefraction : calculated fraction of the time-stamp using constant fraction method
--     energy : energy, calculated maximum in waveform
--     statusbyte : 8-bits status
--     pulse_data_allowed : output data writing (4 words) allowed  : not fifo-almostfull of connected fifo
--     superburst_number : most recent superburst-number
--     superburst_update : new most recent superburst-number+timestamp
-- 
-- Outputs:
--     datain_allowed : allowed to write pulse data members
--     channel_out : 16-bits identification number of the adc
--     statusbyte_out : 8 bits hit-status
--     energy_out : energy of the hit
--     timefraction_out : fractional part of the time within the superburst
--     timestamp_out : time within superburst
--     superburstnumber_out : superburstnumber
--     pulse_data_write :  pulse data write signal
--     slowcontrol_data : slow-control command : data 32-bits 
--     slowcontrol_address : slow-control command : address 24-bits 
--     slowcontrol_reply : indicates if the slow-control is a reply, or a independent message
--     slowcontrol_write : write of slow-control data/address/reply
--     wave_data_out : data with waveform: 36-bits words with bits 35..32 as index
--        	bits(35..32)="0000" : bits(15..0)=timestamp within superburst of maximum value in waveform
--        	bits(35..32)="0001" : bits(31)=0 bits(30..0)=SuperBurst number
--        	bits(35..32)="0010" : 
--              bits(31..24) = statusbyte (bit7=overflow) 
--              bits(23..16) = 00
--              bits(15..0) = adcnumber (channel identification)
--        	bits(35..32)="0011" : bits(31..16)=adc sample, bits(15..0)=next adc sample
--        	bits(35..32)="0100" : bits(31..16)=last adc sample, bits(15..0)=0
--        	bits(35..32)="0101" : bits(31..16)=last but one adc sample, bits(15..0)=last adc sample
--        	bits(35..32)="1111" : error: buffer full, waveform not valid
--     data_error : error
--     pulse_data_skipped : data remove due to full connected fifo
--
-- Components:
--     DC_timeshift_lookuptable : Look Up Table with time delay values for each ADC channel
--     DC_energy_correction : Look Up Table with offset and gain for each ADC channel
--     DC_posedge_to_pulse : Makes a 1-clock pulse on rising edge from signal with different clock
-- 
----------------------------------------------------------------------------------

entity DC_time_energy_LUTs is
	generic (
		NROFADCS                : natural := 32;
		ADCINDEXSHIFT           : natural := 1;
		CF_FRACTIONBIT          : natural := 11;
		ENERGYSCALINGBITS       : natural := 13
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
end DC_time_energy_LUTs;

architecture Behavioral of DC_time_energy_LUTs is

component DC_timeshift_lookuptable is
	generic (
		lut_addrwidth : natural := twologarray(NROFADCS);
		lut_datawidth  : natural := 31
		);
	port ( 
		clock                   : in std_logic;
		load_clock              : in std_logic;
		loading                 : in std_logic;
		lut_write               : in std_logic;
		address                 : in std_logic_vector (lut_addrwidth-1 downto 0);
		data_in                 : in std_logic_vector (lut_datawidth-1 downto 0);
		data_out                : out std_logic_vector (lut_datawidth-1 downto 0));
end component;

component DC_energy_correction is
	generic (
		SCALINGBITS : natural := ENERGYSCALINGBITS;
		LUT_ADDRWIDTH : natural := twologarray(NROFADCS);
		LUT_DATAWIDTH  : natural := 31
		);
	port ( 
		clock                   : in std_logic;
		load_clock              : in std_logic;
		loading                 : in std_logic;
		lut_write               : in std_logic;
		address                 : in std_logic_vector (LUT_ADDRWIDTH-1 downto 0);
		data_in                 : in std_logic_vector (LUT_DATAWIDTH-1 downto 0);
		energy_in               : in std_logic_vector (15 downto 0);
		energy_out              : out std_logic_vector (15 downto 0));
end component;

component DC_posedge_to_pulse is
	port (
		clock_in     : in  std_logic;
		clock_out     : in  std_logic;
		en_clk    : in  std_logic;
		signal_in : in  std_logic;
		pulse     : out std_logic);
end component;

--     PASTSUPERBURSTBITS : number of bits for data array remembering previous SUPERBURSTS, depends on data latency from FEE
constant PASTSUPERBURSTBITS         : natural := 3;
constant zeros                      : std_logic_vector(31 downto 0) := (others => '0');
 
type superbursttime_type is array (0 to 2**PASTSUPERBURSTBITS-1) of std_logic_vector (15 downto 0);
type superbursts_type is array (0 to 2**PASTSUPERBURSTBITS-1) of std_logic_vector (30 downto 0);

signal superbursbufferindex_S       : integer range 0 to 2**PASTSUPERBURSTBITS-1;
signal timeshift_data_s             : std_logic_vector (30 downto 0);
signal energy_corrected_S           : std_logic_vector (15 downto 0);

signal pulse_data_skipped_S         : std_logic := '0';
signal superburst_missed_S          : std_logic := '0';

signal pulse_data_write_S           : std_logic := '0';

signal timestampcounter_S           : std_logic_vector (15 downto 0) := (others => '0');
signal superburst_timestamps_S      : superbursttime_type := (others => (others => '0'));
signal superburst_numbers_S         : superbursts_type := (others => (others => '0'));
signal superburst_update0_S         : std_logic;
signal superburst_update1_S         : std_logic;
signal timestampcounter0_S          : std_logic_vector (15 downto 0);
signal timestampcounter1_S          : std_logic_vector (15 downto 0);
signal superburst_number0_S         : std_logic_vector (30 downto 0);
signal superburst_number1_S         : std_logic_vector (30 downto 0);


signal superburst_timestamps0_S            : std_logic_vector (15 downto 0);
signal superburst_timestamps1_S            : std_logic_vector (15 downto 0);
signal superburst_timestamps2_S            : std_logic_vector (15 downto 0);
signal superburst_timestamps3_S            : std_logic_vector (15 downto 0);
signal superburst_timestamps4_S            : std_logic_vector (15 downto 0);
signal superburst_timestamps5_S            : std_logic_vector (15 downto 0);
signal superburst_timestamps6_S            : std_logic_vector (15 downto 0);
signal superburst_timestamps7_S            : std_logic_vector (15 downto 0);
signal superburst_numbers0_S               : std_logic_vector (30 downto 0);
signal superburst_numbers1_S               : std_logic_vector (30 downto 0);
signal superburst_numbers2_S               : std_logic_vector (30 downto 0);
signal superburst_numbers3_S               : std_logic_vector (30 downto 0);
signal superburst_numbers4_S               : std_logic_vector (30 downto 0);
signal superburst_numbers5_S               : std_logic_vector (30 downto 0);
signal superburst_numbers6_S               : std_logic_vector (30 downto 0);
signal superburst_numbers7_S               : std_logic_vector (30 downto 0);
									
begin

datain_allowed <= '1' when (pulse_data_allowed='1') else '0';
					
pulse_data_skipped <= '1' when (pulse_data_skipped_S='1') and (enable='1') else '0';

process(SODA_clock)
begin
	if rising_edge(SODA_clock) then
		if superburst_update='1' then
			timestampcounter_S <= x"0001"; --(others => '0');
		else
			timestampcounter_S <= timestampcounter_S+1;
		end if;
	end if;
end process;

process(SODA_clock)
begin
	if rising_edge(SODA_clock) then
		if (superburst_update='1') then
			timestampcounter0_S <= timestampcounter_S;
			superburst_number0_S <= superburst_number;
		end if;
	end if;
end process;

sync_superburst_update: DC_posedge_to_pulse port map(
		clock_in => SODA_clock,
		clock_out => clock,
		en_clk => '1',
		signal_in => superburst_update,
		pulse => superburst_update0_S);

process(clock)  --//? needed?
begin
	if rising_edge(clock) then
		superbursbufferindex_S <= conv_integer(unsigned(superburst_number1_S(PASTSUPERBURSTBITS-1 downto 0)));
		superburst_number1_S <= superburst_number0_S;
		timestampcounter1_S <= timestampcounter0_S;
		superburst_update1_S <= superburst_update0_S;
	end if;
end process;
	
generate_buffers: for i in 0 to 2**PASTSUPERBURSTBITS-1 generate
process(clock)
	begin
		if rising_edge(clock) then
			if (superburst_update1_S='1') and (i=superbursbufferindex_S) then
				superburst_timestamps_S(i) <= timestampcounter1_S;
				superburst_numbers_S(i) <= superburst_number1_S;
			end if;
		end if;
	end process;
end generate;

pulse_data_write <= '1' when (pulse_data_write_S='1') and (pulse_data_allowed='1') and (enable='1') else '0';


DC_timeshift_lookuptable1: DC_timeshift_lookuptable port map(
		clock => clock,
		load_clock => load_clock,
		loading => timeshiftLUT_loading,
		lut_write => timeshiftLUT_write,
		address => adcnumber(twologarray(NROFADCS)-1 downto 0),
		data_in => timeshiftLUT_data,
		data_out => timeshift_data_S);

DC_energy_correction1: DC_energy_correction port map(
		clock => clock,
		load_clock => load_clock,
		loading => energytLUT_loading,
		lut_write => energyLUT_write,
		address => adcnumber(twologarray(NROFADCS)-1 downto 0),
		data_in => energyLUT_data,
		energy_in => energy,
		energy_out => energy_corrected_S);

datapackethandling: process(clock)
variable precise_time_vector_V    : std_logic_vector(CF_FRACTIONBIT+15 downto 0);
variable precise_time_V           : integer range -2**(CF_FRACTIONBIT+15) to 2**(CF_FRACTIONBIT+15)-1;
variable timeshift_vector_V       : std_logic_vector(CF_FRACTIONBIT+15 downto 0);
variable timeshift_V              : integer range -2**(CF_FRACTIONBIT+15) to 2**(CF_FRACTIONBIT+15)-1;
variable precise_shifted_time_V   : std_logic_vector(CF_FRACTIONBIT+15 downto 0);
variable precise_superburst_timevctr_V: std_logic_vector(CF_FRACTIONBIT+15 downto 0);
variable precise_superburst_time_V: integer range -2**(CF_FRACTIONBIT+15) to 2**(CF_FRACTIONBIT+15)-1;
variable precise_shifted_time_pr_V : std_logic_vector(CF_FRACTIONBIT+15 downto 0);
variable superburstidx_V          : integer range 0 to 2**PASTSUPERBURSTBITS-1;
variable superburstidx_pr_vector_V : std_logic_vector(PASTSUPERBURSTBITS-1 downto 0);
variable superburstidx_pr_V       : integer range 0 to 2**PASTSUPERBURSTBITS-1;

variable timestamp_V              : std_logic_vector(15 downto 0);
variable timefraction_V           : std_logic_vector(11 downto 0);
variable superburstnr_V           : std_logic_vector(30 downto 0);
variable superburstnr_error_V     : boolean;

variable superburstidx_nx_vector_V : std_logic_vector(PASTSUPERBURSTBITS-1 downto 0);
variable superburstidx_nx_V       : integer range 0 to 2**PASTSUPERBURSTBITS-1;
variable precise_superburst_timevctr_nx_V: std_logic_vector(CF_FRACTIONBIT+15 downto 0);
variable precise_superburst_time_nx_V: integer range -2**(CF_FRACTIONBIT+15) to 2**(CF_FRACTIONBIT+15)-1;
variable precise_shifted_time_nx_V : std_logic_vector(CF_FRACTIONBIT+15 downto 0);

variable statusbyte_V              : std_logic_vector(7 downto 0);

begin
	if rising_edge(clock) then
		if reset='1' then
			pulse_data_write_S <= '0';
			pulse_data_skipped_S <= '0';
			superburst_missed_S <= '0';
		else
			if (pulse_data_write_S='1') and (pulse_data_allowed='0') then -- write unsuccessful
				if datain_write='1' then
					pulse_data_skipped_S <= '1';
				end if;
			else
				if datain_write='1' then
					if (pulse_data_allowed='1') then 
						precise_time_vector_V := timestamp & timefraction;
						precise_time_V := conv_integer(signed(precise_time_vector_V));
						
						timeshift_vector_V := '0' & timeshift_data_S(30 downto 16) & timeshift_data_S(CF_FRACTIONBIT-1 downto 0);
						timeshift_V := conv_integer(signed(timeshift_vector_V));
						
						superburstidx_V := conv_integer(unsigned(superburst(PASTSUPERBURSTBITS-1 downto 0)));
						superburstidx_pr_vector_V := superburst(PASTSUPERBURSTBITS-1 downto 0)-"01"; -- index for previous superburst
						superburstidx_pr_V := conv_integer(unsigned(superburstidx_pr_vector_V)); -- index for previous superburst (integer)
						superburstidx_nx_vector_V := superburst(PASTSUPERBURSTBITS-1 downto 0)+"01"; -- index for next superburst
						superburstidx_nx_V := conv_integer(unsigned(superburstidx_nx_vector_V)); -- index for next superburst (integer)
						
						precise_shifted_time_V := conv_std_logic_vector(precise_time_V - timeshift_V,CF_FRACTIONBIT+16);
						precise_superburst_timevctr_V := superburst_timestamps_S(superburstidx_pr_V) & zeros(CF_FRACTIONBIT-1 downto 0);
						precise_superburst_time_V := conv_integer(unsigned(precise_superburst_timevctr_V));
						precise_shifted_time_pr_V := conv_std_logic_vector( -- precision time in respect to previous superburst
								precise_superburst_time_V + precise_time_V - timeshift_V,CF_FRACTIONBIT+16);

						precise_superburst_timevctr_nx_V := superburst_timestamps_S(superburstidx_V) & zeros(CF_FRACTIONBIT-1 downto 0);
						precise_superburst_time_nx_V := conv_integer(unsigned(precise_superburst_timevctr_nx_V));
						precise_shifted_time_nx_V := conv_std_logic_vector( -- precision time in respect to next superburst
								(precise_time_V - timeshift_V) - precise_superburst_time_nx_V,CF_FRACTIONBIT+16);
								
						superburstnr_error_V := false;
						if precise_shifted_time_V(CF_FRACTIONBIT+15)='1' then -- negative: decrease superburst
							timestamp_V := precise_shifted_time_pr_V(CF_FRACTIONBIT+15 downto CF_FRACTIONBIT);
							superburstnr_V := superburst_numbers_S(superburstidx_pr_V);
							if superburst_numbers_S(superburstidx_V)(15 downto 0) /= superburst then
								superburstnr_error_V := true;
							end if;
--										if superburstnr_V(15 downto 0) /= superburst-x"0001") then
--											superburstnr_error_V := true;
--										end if;
							timefraction_V(CF_FRACTIONBIT-1 downto 0) := precise_shifted_time_pr_V(CF_FRACTIONBIT-1 downto 0);
						elsif (precise_shifted_time_V>=precise_superburst_time_nx_V) and -- check if hit-time is beyond superburst
							(superburst_numbers_S(superburstidx_nx_V)(15 downto 0)=(superburst+x"0001")) then -- check if next superburst is already valid
							timestamp_V := precise_shifted_time_nx_V(CF_FRACTIONBIT+15 downto CF_FRACTIONBIT);
							superburstnr_V := superburst_numbers_S(superburstidx_nx_V);
							if superburst_numbers_S(superburstidx_V)(15 downto 0) /= superburst then
								superburstnr_error_V := true;
							end if;
							timefraction_V(CF_FRACTIONBIT-1 downto 0) := precise_shifted_time_nx_V(CF_FRACTIONBIT-1 downto 0);
						else
							timestamp_V := precise_shifted_time_V(CF_FRACTIONBIT+15 downto CF_FRACTIONBIT);										
							superburstnr_V := superburst_numbers_S(superburstidx_V);
							if superburstnr_V(15 downto 0) /= superburst then
								superburstnr_error_V := true;
							end if;
							timefraction_V(CF_FRACTIONBIT-1 downto 0) := precise_shifted_time_V(CF_FRACTIONBIT-1 downto 0);
						end if;
						timefraction_V(11 downto CF_FRACTIONBIT) := (others => '0');
						if superburstnr_error_V then
							superburst_missed_S <= '1';
							pulse_data_skipped_S <= '1';
							pulse_data_write_S <= '0';
						else
							statusbyte_V := statusbyte;
							if superburst_missed_S='1' then
								statusbyte_V := statusbyte or STATBYTE_DCSUPERBURSTMISSED;
							end if;
							if pulse_data_skipped_S='1' then
								statusbyte_V := statusbyte or STATBYTE_DCPULSESKIPPED;
							end if;
							channel_out <= adcnumber;
							statusbyte_out <= statusbyte_V;
							energy_out <= energy_corrected_S;
							timefraction_out <= timefraction_V;
							timestamp_out <= timestamp_V;
							superburstnumber_out <= superburstnr_V;		
							pulse_data_write_S <= '1';
							pulse_data_skipped_S <= '0';
							superburst_missed_S <= '0';
						end if;
					else 
						pulse_data_skipped_S <= '1';
						pulse_data_write_S <= '0';
					end if;
				else
					pulse_data_skipped_S <= '0';
					pulse_data_write_S <= '0';
				end if;
			end if;
		end if;
	end if;
end process datapackethandling;

testword0 <= (others => '0');

end Behavioral;

