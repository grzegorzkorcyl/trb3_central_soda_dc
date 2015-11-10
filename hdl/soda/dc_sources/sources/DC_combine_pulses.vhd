----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   14-07-2014
-- Module Name:   DC_combine_pulses
-- Description:   Combine pulses (=hits) from corresponding ADC channels
-- Modifications:
--   26-03-2015   Check on fifo_almost_full_S for data_out_available
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;
USE work.panda_package.all;

------------------------------------------------------------------------------------------------------
-- DC_combine_pulses
--     Combine Feature Extraction data from corresponding ADC channels.
--
--     Each ADC has a corresponding channel: the one with the same index connected to the neighbour fiber.
--     The fiber nummer comes as separated input, the ADC index is determined by the lower few bits of the channel number.
--     If the ADCs are organised as high/low gain pairs then the last bit indicates low or high gain and in that case
--     both ADC channels are combined with the corresponding ADC low/high gain pair (see generic ADCINDEXSHIFT)
--
--     The input and output consist of the members that describe a hit : time&energy (plus status and superburst)
--     The sequence of the pulses is not changed, but the resulting combined hit will be placed on the first of the two hits
--
--     The conditions for combining: 
--     1) Hits are combined if time difference is below a fixed time (generic COMBINETIMEDIFFERENCE), within one superburst
--     2) The combined hit is placed at the position of the first hit. The timestamp is an average of both hits.
--     3) Hits are combined if their energy difference is within 25%: the check is ((a>b*0.75)&&(b>a*0.75))
--     4) If the energy difference is larger then 25% then only the smallest will be kept.
--     5) High and low gain channels can be combined. The correction gain must be calibrated beforehand.
--
--     With input combine_pulse it is possible to select which ADCs should be combined (calibration run)
--     Bit 7 of the statusbyte indicates that 2 channels where combined.
--     Bit 6 of the statusbyte indicates that the corresponding channel was discarded
--
--     Description of the algortithm:
--     Data is written in a fifo, and at the same time written in a block of memory that contains the latest data for each ADC index.
--     Before the data is written in the fifo it is compared with the latest data from the corresponding ADC.
--     If the time difference is small then the combined data or the new data (depending of the energy comparison)
--     will be written at the position of the corresponding data (that was written earlier in the fifo).
--     The block memory also contains the address in the fifo.
--     The data is read out of the fifo. This is done after some delay and some check on the amount of data in the fiber,
--     to prevent that data combining takes place after the data is already read from the fifo.
--     
--
-- Library
--     work.panda_package :  for type declarations and constants
--
-- generics
--     NROFFIBERS : number of fiber connection of the MUX board
--     NROFADCS : number of ADCs in each FEE
--     ADCINDEXSHIFT : ADC channel numbers lowest bit indicates the high or low gain ADC, 0=high, 1=low
--     COMBINEPULSESMEMSIZE : addressbits for the fifo buffer for combining hits
--     COMBINETIMEDIFFERENCE : largest time difference between hits to be combined, number of timefraction units
--     CF_FRACTIONBIT : number of valid constant fraction bits
--		
-- inputs
--     clock : clock
--     reset : synchronous reset
--     combine_pulse : enable combining if corresponding bit is set, only even fibernumbers; low or high gain bits are removed
--     fiber_index_in : index of the fiber
--     channel_in : data input : adc channel
--     statusbyte_in : data input : status
--     energy_in : data input : pulse energy
--     timefraction_in : data input : Constant Fraction time
--     timestamp_in : data input : time within superburst
--     superburstnumber_in : data input : superburst number
--     data_in_available : hit data is available
--     data_out_read : read signal to read from fifo output
--		
-- outputs
--     data_in_read : read signal for reading data at the input (from connected fifo)
--     channel_out : data output : adc channel
--     statusbyte_out : data output : status
--     energy_out : data output : pulse energy
--     timefraction_out : data output : Constant Fraction time
--     timestamp_out : data output : time within superburst
--     superburstnumber_out : data output : superburst number
--     data_out_available : hit data is available at the output of the fifo
--
-- components
--     blockmem : memory for the fifo and for saving the latest hit data
--
--
------------------------------------------------------------------------------------------------------

entity DC_combine_pulses is
	generic (
		NROFFIBERS              : natural := 4;
		NROFADCS                : natural := 32;
		ADCINDEXSHIFT           : natural := 1;
		COMBINEPULSESMEMSIZE    : natural := 10;
		COMBINETIMEDIFFERENCE   : natural := 5000;
		CF_FRACTIONBIT          : natural := 11
		);
	port ( 
		clock                   : in std_logic;
		reset                   : in std_logic;
		combine_pulse           : in std_logic_vector((NROFFIBERS*NROFADCS)/(2*(ADCINDEXSHIFT+1))-1 downto 0);
		fiber_index_in          : in std_logic_vector(3 downto 0);
		channel_in              : in std_logic_vector(15 downto 0);
		statusbyte_in           : in std_logic_vector(7 downto 0);
		energy_in               : in std_logic_vector(15 downto 0);
		timefraction_in         : in std_logic_vector(11 downto 0);
		timestamp_in            : in std_logic_vector(15 downto 0);
		superburstnumber_in     : in std_logic_vector(30 downto 0);
		data_in_read            : out std_logic;
		data_in_available       : in std_logic;

		channel_out             : out std_logic_vector(15 downto 0);
		statusbyte_out          : out std_logic_vector(7 downto 0);
		energy_out              : out std_logic_vector(15 downto 0);
		timefraction_out        : out std_logic_vector(11 downto 0);
		timestamp_out           : out std_logic_vector(15 downto 0);
		superburstnumber_out    : out std_logic_vector(30 downto 0);
		data_out_read           : in std_logic;
		data_out_available      : out std_logic
	);
end DC_combine_pulses;

architecture behavioral of DC_combine_pulses is

component blockmem is
	generic (
		ADDRESS_BITS : natural := 8;
		DATA_BITS  : natural := 18
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

constant COMBINETIMEDIFF         : std_logic_vector(CF_FRACTIONBIT+15 downto 0) := conv_std_logic_vector(COMBINETIMEDIFFERENCE,CF_FRACTIONBIT+16);
constant CHECK_FRACTIONTIME      : boolean := TRUE;
constant ZEROS                   : std_logic_vector (311 downto 0) := (others => '0');

type combine_type is (store,combine,overwrite,preserve);
signal combine_S                 : combine_type := store;

signal combine_pulse_S           : std_logic_vector((NROFFIBERS*NROFADCS)/(2*(ADCINDEXSHIFT+1))-1 downto 0);
-- register with newly arrived data
signal fiber_index1_S            : std_logic_vector(twologarray(NROFFIBERS)-1 downto 0);
signal channel1_S                : std_logic_vector(15 downto 0);
signal statusbyte1_S             : std_logic_vector(7 downto 0);
signal energy1_S                 : std_logic_vector(15 downto 0);
signal timefraction1_S           : std_logic_vector(11 downto 0) := (others => '0');
signal timestamp1_S              : std_logic_vector(15 downto 0);
signal superburstnumber1_S       : std_logic_vector(30 downto 0);

-- latest data in memory from the selected ADC:
signal fiber_indexL_S            : std_logic_vector(twologarray(NROFFIBERS)-1 downto 0);
signal channelL_S                : std_logic_vector(15 downto 0);
signal statusbyteL_S             : std_logic_vector(7 downto 0);
signal energyL_S                 : std_logic_vector(15 downto 0);
signal timefractionL_S           : std_logic_vector(11 downto 0) := (others => '0');
signal timestampL_S              : std_logic_vector(15 downto 0);
signal superburstnumberL_S       : std_logic_vector(30 downto 0);

-- combined data: newly arrived data and data from memory
signal fiber_indexC_S            : std_logic_vector(twologarray(NROFFIBERS)-1 downto 0);
signal channelC_S                : std_logic_vector(15 downto 0);
signal statusbyteC_S             : std_logic_vector(7 downto 0);
signal energyC_S                 : std_logic_vector(15 downto 0);
signal timefractionC_S           : std_logic_vector(11 downto 0) := (others => '0');
signal timestampC_S              : std_logic_vector(15 downto 0);
signal superburstnumberC_S       : std_logic_vector(30 downto 0);
signal energyCbf_S               : std_logic_vector(16 downto 0);
signal energy_diff_small_s       : std_logic;
signal data_validl_s             : std_logic;
		
signal hires_time1_s             : std_logic_vector(CF_FRACTIONBIT+15 downto 0) := (others => '0');
signal hires_timeL_s             : std_logic_vector(CF_FRACTIONBIT+15 downto 0) := (others => '0');
signal hires_diff_s              : std_logic_vector(CF_FRACTIONBIT+15 downto 0) := (others => '0');
signal time_diff_small_S         : std_logic := '0';

signal hires_diff_pos_S          : std_logic_vector(CF_FRACTIONBIT+15 downto 0) := (others => '0');
signal hires_diff_div2_S         : std_logic_vector(CF_FRACTIONBIT+15 downto 0) := (others => '0');
signal hires_meantime_S          : std_logic_vector(CF_FRACTIONBIT+15 downto 0) := (others => '0');

signal index_S                   : std_logic_vector(twologarray(NROFFIBERS/2)+twologarray(NROFADCS/(ADCINDEXSHIFT+1))-1 downto 0);
signal indexI_S                  : integer range 0 to (NROFFIBERS*NROFADCS)/(2*(ADCINDEXSHIFT+1))-1;
signal data_in_read_S            : std_logic := '0';
signal data_in_read1_S           : std_logic := '0';
signal data_in_read2_S           : std_logic := '0';


signal data_out_available_S      : std_logic;
signal fifo_write_S              : std_logic;
signal fifo_write_address_S      : std_logic_vector(COMBINEPULSESMEMSIZE-1 downto 0) := (others => '0');
signal fifo_data_in_S            : std_logic_vector(99 downto 0) := (others => '0');
signal fifo_read_address_S       : std_logic_vector(COMBINEPULSESMEMSIZE-1 downto 0) := (others => '1');
signal fifo_read_address0_S      : std_logic_vector(COMBINEPULSESMEMSIZE-1 downto 0) := (others => '1');
signal fifo_nextwriteaddress_S   : std_logic_vector(COMBINEPULSESMEMSIZE-1 downto 0) := (others => '0');
signal fifo_read_addressplus1_S  : std_logic_vector(COMBINEPULSESMEMSIZE-1 downto 0) := (others => '1');
signal fifo_nextwriteaddressplus1_S : std_logic_vector(COMBINEPULSESMEMSIZE-1 downto 0) := (others => '1');
signal fifo_nextwriteaddressplus2_S : std_logic_vector(COMBINEPULSESMEMSIZE-1 downto 0) := (others => '1');
signal fifo_out_valid_S          : std_logic;
signal fifo_almost_full_S        : std_logic;
signal fifoaddressl_s            : std_logic_vector(COMBINEPULSESMEMSIZE-1 downto 0) := (others => '0');

signal last_write_S              : std_logic;
signal last_write_address_S      : std_logic_vector(twologarray(NROFFIBERS)+twologarray(NROFADCS)-ADCINDEXSHIFT-1 downto 0);
signal last_data_in_S            : std_logic_vector(100+twologarray(NROFFIBERS)+COMBINEPULSESMEMSIZE-1 downto 0);
signal last_read_address_S       : std_logic_vector(twologarray(NROFFIBERS)+twologarray(NROFADCS)-ADCINDEXSHIFT-1 downto 0);

signal timeafterlastwrite_S      : integer range 0 to 2*NROFFIBERS*NROFADCS := 0;
signal wordsinbuffer0_S          : std_logic_vector(COMBINEPULSESMEMSIZE-1 downto 0) := (others => '0');
signal wordsinbuffer_S           : integer range 0 to 2*COMBINEPULSESMEMSIZE-1 := 0;


begin

process(clock)
begin
	if (rising_edge(clock)) then 
		combine_pulse_S <= combine_pulse;
	end if;
end process;

fifoblockmem: blockmem 
	generic map(
		ADDRESS_BITS => COMBINEPULSESMEMSIZE,
		DATA_BITS  => 100
	)
	port map(
		clock => clock,
		write_enable => fifo_write_S,
		write_address => fifo_write_address_S,
		data_in => fifo_data_in_S,
		read_address => fifo_read_address0_S,
		data_out(15 downto 0) => channel_out,
		data_out(23 downto 16) => statusbyte_out,
		data_out(39 downto 24) => energy_out,
		data_out(51 downto 40) => timefraction_out,
		data_out(67 downto 52) => timestamp_out,
		data_out(98 downto 68) => superburstnumber_out,
		data_out(99) => fifo_out_valid_S
		);
		
lastblockmem: blockmem
	generic map(
		ADDRESS_BITS => twologarray(NROFFIBERS)+twologarray(NROFADCS)-ADCINDEXSHIFT,
		DATA_BITS  => 100+twologarray(NROFFIBERS)+COMBINEPULSESMEMSIZE
	)
	port map(
		clock => clock,
		write_enable => last_write_S,
		write_address => last_write_address_S,
		data_in => last_data_in_S,
		read_address => last_read_address_S,
		data_out(15 downto 0) => channelL_S,
		data_out(23 downto 16) => statusbyteL_S,
		data_out(39 downto 24) => energyL_S,
		data_out(51 downto 40) => timefractionL_S,
		data_out(67 downto 52) => timestampL_S,
		data_out(98 downto 68) => superburstnumberL_S,
		data_out(99) => data_validL_S,
		data_out(twologarray(NROFFIBERS)+99 downto 100) => fiber_indexL_S,
		data_out(twologarray(NROFFIBERS)+COMBINEPULSESMEMSIZE+99 downto twologarray(NROFFIBERS)+100) => fifoaddressL_S
		);
last_read_address_S <= fiber_index_in(twologarray(NROFFIBERS)-1 downto 1) & (not fiber_index_in(0)) & (channel_in(twologarray(NROFADCS)-1 downto ADCINDEXSHIFT));
		
-- calculate if timedifference between pulses is small: ---------------------------------
hires_time1_S <= timestamp1_S & timefraction1_S(CF_FRACTIONBIT-1 downto 0);
hires_timeL_S <= timestampL_S & timefractionL_S(CF_FRACTIONBIT-1 downto 0);
hires_diff_S <= hires_timeL_S-hires_time1_S;
time_diff_small_S <= '1' when 
		(superburstnumber1_S=superburstnumberL_S) and
		(((hires_diff_S(CF_FRACTIONBIT+15)='0') and (hires_diff_S<COMBINETIMEDIFF)) or -- L newer than 1
		((hires_diff_S(CF_FRACTIONBIT+15)='1') and ((not hires_diff_S)<(COMBINETIMEDIFF-1)))) -- 1 newer than L
	else '0';
hires_diff_pos_S <= 
		hires_timeL_S-hires_time1_S when (hires_diff_S(CF_FRACTIONBIT+15)='0') else -- L newer than 1
		hires_time1_S-hires_timeL_S;
hires_diff_div2_S <= '0' & hires_diff_pos_S(CF_FRACTIONBIT+15 downto 1);	
hires_meantime_S <= 
	hires_time1_S + hires_diff_div2_S when (hires_diff_S(CF_FRACTIONBIT+15)='0') else -- L newer than 1
	hires_timeL_S + hires_diff_div2_S; -- L newer than 1

-- energy difference is small when a>b(1-b/4) and b>a(1-1/4)
energy_diff_small_S <= '1' when
	(energyL_S >= energy1_S-("00" & energy1_S(15 downto 2))) and 
	(energy1_S >= energyL_S-("00" & energyL_S(15 downto 2)))
	else '0';
	
-- Combined hit: time and energy averaged ----------------------------------------------------
fiber_indexC_S <= fiber_indexL_S;
channelC_S <= channelL_S;
statusbyteC_S <= (statusbyte1_S or statusbyteL_S) or STATBYTE_DCCOMBINEDHITS;
energyCbf_S <= ('0' & energy1_S) + ('0' & energyL_S);
energyC_S <= energyCbf_S(16 downto 1);
timefractionC_S(CF_FRACTIONBIT-1 downto 0) <= hires_meantime_S(CF_FRACTIONBIT-1 downto 0);
timestampC_S <= hires_meantime_S(CF_FRACTIONBIT+15 downto CF_FRACTIONBIT);
superburstnumberC_S <= superburstnumber1_S;
 
-- channel0=high gain, channel1=low gain
-- how to combine:
--   store=save new hit if time difference is large or combining is disabled
--   combine=save mean value of two hits in old fifo memory 
--   overwrite=save new hit at position of the corresponding channel
--   preserve=preserve the hit of the corresponding channel and discard new value
index_S <= fiber_indexL_S(twologarray(NROFFIBERS)-1 downto 1) & channelL_S(twologarray(NROFADCS)-1 downto ADCINDEXSHIFT);
indexI_S <= conv_integer(index_S);
combine_S <= 
	store when (combine_pulse_S(indexI_S)='0') else
	store when (data_validL_S='0') else
	combine when ((time_diff_small_S='1') and (energy_diff_small_S='1')) else
	overwrite when ((time_diff_small_S='1') and (energy_diff_small_S='0') and (energy1_S<energyL_S)) else
	preserve when ((time_diff_small_S='1') and (energy_diff_small_S='0') and (energy1_S>energyL_S)) 
	else store;

-- write data in memory block for latest data, organised for each ADC ------------------------
last_write_S <= '1' when data_in_read2_S='1' else '0';
last_write_address_S <=
	fiber_index1_S(twologarray(NROFFIBERS)-1 downto 0) & (channel1_S(twologarray(NROFADCS)-1 downto ADCINDEXSHIFT))
		when (combine_S=store) else
	fiber_index1_S(twologarray(NROFFIBERS)-1 downto 1) & (not fiber_index1_S(0)) & (channel1_S(twologarray(NROFADCS)-1 downto ADCINDEXSHIFT));
last_data_in_S <= -- save new hit in case of store, otherwise set corresponding data to invalid
	fifo_nextwriteaddress_S & fiber_index1_S & '1' & superburstnumber1_S & timestamp1_S & timefraction1_S & energy1_S & statusbyte1_S & channel1_S
		when (combine_S=store) else
	fifo_nextwriteaddress_S & fiber_index1_S & '0' & superburstnumber1_S & timestamp1_S & timefraction1_S & energy1_S & statusbyte1_S & channel1_S;
--maybe: additional write on next clock to make corresponding data invalid ?

-- write data in fifo (sequential) ------------------------------------------------------------
fifo_write_S <= '1' when data_in_read2_S='1' else '0';
fifo_write_address_S <=
	fifo_nextwriteaddress_S when combine_S=store else fifoaddressL_S;
fifo_data_in_S <=
	'1' & superburstnumber1_S & timestamp1_S & timefraction1_S & energy1_S & statusbyte1_S & channel1_S
		when (combine_S=store) else
	'1' & superburstnumber1_S & timestamp1_S & timefraction1_S & energy1_S & (statusbyte1_S or STATBYTE_DCCOMBINEDDISCARDED) & channel1_S
		when (combine_S=overwrite) else
	'1' & superburstnumberC_S & timestampC_S & timefractionC_S & energyC_S & statusbyteC_S & channelC_S
		when (combine_S=combine) else
	'1' & superburstnumberL_S & timestampL_S & timefractionL_S & energyL_S & (statusbyteL_S or STATBYTE_DCCOMBINEDDISCARDED) & channelL_S
		when (combine_S=preserve);
	
-- read data from moduel input -------------------------------------------------------------------
data_in_read <= data_in_read_S;
data_in_read_S <= '1' when (data_in_available='1') and (data_in_read1_S='0') and (fifo_almost_full_S='0') else '0';

read_data_process: process (clock)
begin
	if (rising_edge(clock)) then 
		if reset='1' then
			data_in_read1_S <= '0';
			data_in_read2_S <= '0';
			fifo_nextwriteaddress_S <= (others => '0');
		else
			if data_in_read1_S='1' then
				fiber_index1_S <= fiber_index_in(twologarray(NROFFIBERS)-1 downto 0);
				channel1_S <= channel_in;
				statusbyte1_S <= statusbyte_in;
				energy1_S <= energy_in;
				timefraction1_S <= timefraction_in;
				timestamp1_S <= timestamp_in;
				superburstnumber1_S <= superburstnumber_in;			
			end if;
			data_in_read1_S <= data_in_read_S;
			data_in_read2_S <= data_in_read1_S;
			if (data_in_read2_S='1') and (combine_S=store) then
				fifo_nextwriteaddress_S <= fifo_nextwriteaddress_S+1;
			end if;
		end if;
	end if;
end process;

-- read from fifo -----------------------------------------------------
fifo_read_address0_S <= fifo_read_addressplus1_S when data_out_read='1' else fifo_read_address_S;

fifo_read_addressplus1_S <= fifo_read_address_S+1;
fifo_nextwriteaddressplus1_S <= fifo_nextwriteaddress_S+1;
fifo_nextwriteaddressplus2_S <= fifo_nextwriteaddressplus1_S+1;
data_out_available <= data_out_available_S;
data_out_available_S <= '1' 
		when ((wordsinbuffer_S>NROFFIBERS*NROFADCS) or (fifo_almost_full_S='1')) or
			((timeafterlastwrite_S=2*NROFFIBERS*NROFADCS) and (fifo_read_addressplus1_S/=fifo_nextwriteaddress_S)) 
	else '0';

process (clock)
begin
	if (rising_edge(clock)) then 
		if reset='1' then
			fifo_read_address_S <= (others => '1');
			timeafterlastwrite_S <= 0;
		else
			if data_out_read='1' then
				fifo_read_address_S <= fifo_read_address_S+1;
			end if;
			if (fifo_read_address_S=fifo_nextwriteaddress_S) or (fifo_read_address_S=fifo_nextwriteaddressplus1_S) or (fifo_read_address_S=fifo_nextwriteaddressplus2_S) then
				fifo_almost_full_S <= '1';
			else
				fifo_almost_full_S <= '0';
			end if;
			
			if fifo_write_S='1' then
				timeafterlastwrite_S <= 0;
			else
				if timeafterlastwrite_S/=2*NROFFIBERS*NROFADCS then
					timeafterlastwrite_S <= timeafterlastwrite_S+1;
				end if;
			end if;
			wordsinbuffer0_S <= fifo_nextwriteaddress_S-fifo_read_addressplus1_S;
			wordsinbuffer_S <= conv_integer(wordsinbuffer0_S);
		end if;
	end if;
end process;



end architecture behavioral;
