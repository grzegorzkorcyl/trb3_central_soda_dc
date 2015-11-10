----------------------------------------------------------------------------------
-- Company: KVI/RUG/Groningen University
-- Engineer: Peter Schakel
-- Create Date:   04-03-2011
-- Module Name:   panda_package
-- Description: Package with constants and function for Panda
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.std_logic_ARITH.ALL;
use IEEE.std_logic_UNSIGNED.ALL;

package panda_package is

	constant NROFADCS : natural := 32;
	constant NROFFIBERS : natural := 4;
	constant ADCINDEXSHIFT : natural := 1;
	constant NROFMUXREGS : natural := 14;
	constant ADCBITS : natural := 14;
	constant ADCCLOCKFREQUENCY : natural := 80000000; -- 80000000; -- 62500000;
	constant FEESLOWCONTROLADRESSES : natural := 2*NROFADCS/(ADCINDEXSHIFT+1)+4;
	constant FEESLOWCONTROLBOARDADDRESS : natural := 2*NROFADCS/(ADCINDEXSHIFT+1);
	
-- statusbyte in data stream :
    constant STATBYTE_DCPULSESKIPPED     : std_logic_vector(7 downto 0) := "00000100";
    constant STATBYTE_DCWAVESKIPPED      : std_logic_vector(7 downto 0) := "00000100";
    constant STATBYTE_DCCOMBINEDHITS     : std_logic_vector(7 downto 0) := "00000001";
    constant STATBYTE_DCCOMBINEDDISCARDED : std_logic_vector(7 downto 0) := "00000010";
    constant STATBYTE_DCSUPERBURSTMISSED : std_logic_vector(7 downto 0) := "00001100";

    constant STATBYTE_FEEPULSESKIPPED    : std_logic_vector(7 downto 0) := "01000000";
    constant STATBYTE_FEECFNOZEROCROSS   : std_logic_vector(7 downto 0) := "00100000";
    constant STATBYTE_FEECFERROR         : std_logic_vector(7 downto 0) := "00010000";

-- fiber constants
constant KCHAR280        : std_logic_vector(7 downto 0) := "00011100"; -- 1C
constant KCHAR281        : std_logic_vector(7 downto 0) := "00111100"; -- 3C
constant KCHAR285        : std_logic_vector(7 downto 0) := "10111100"; -- BC
-- constant KCHAR277        : std_logic_vector(7 downto 0) := "11111011"; -- FB
constant KCHAR286        : std_logic_vector(7 downto 0) := x"DC";

constant KCHARIDLE       : std_logic_vector(15 downto 0) := KCHAR281 & KCHAR285;  -- 3CBC peter: bytes different for word sync
constant KCHARSODASTART  : std_logic_vector(15 downto 0) := KCHAR280 & KCHAR280;  -- 1C1C
constant KCHARSODASTOP   : std_logic_vector(15 downto 0) := KCHAR281 & KCHAR281;  -- 3C3C
constant KCHARSODA       : std_logic_vector(7 downto 0) := KCHAR286;  -- DC
	
-- addresses slowcontrol commands for Multiplexer board
	constant ADDRESS_MUX_FIBERMODULE_STATUS : std_logic_vector(23 downto 0) := x"800000";
--       request : request status
--       command: clear error bits, pulse skipped counter
--       Reply, or in case of error: Status of the fibermodule:
--         bit0 : error in slowcontrol to cpu occured
--         bit1 : error if slowcontrol transmit data
--         bit2 : error if fiber receive data
--         bit3 : received character not in table: fiber error
--         bit4 : pulse data skipped due to full multiplexer fifo
--         bit5 : receiver locked
--         bit15..8 : number of pulse data packets skipped due to full buffers
--         bit31..16 : number of successful hamming code corrections
	constant ADDRESS_MUX_MAXCFLUTS : std_logic_vector(23 downto 0) := x"800001";
--         bit15..0 : data for the CF or MAX Look Up Table
--         bit25..16 :offset for maximum correction LUT
--         bit26 : write signal for maximum LUT
--         bit27 : loading maximum correction LUT
--         bit28 : enable maximum correction
--         bit29 : write signal for Constant Fraction LUT
--         bit30 : loading CF correction LUT
--         bit31 : enable CF correction
	constant ADDRESS_MUX_MULTIPLEXER_STATUS : std_logic_vector(23 downto 0) := x"800002";
--       status/fullness of the multiplexer:
--         bit 15..0 : number of words in input fifo of the multiplexer
--         bit 15..0 : number of words in output fifo of the multiplexer, only for fiber index 0
	constant ADDRESS_MUX_SODA_CONTROL : std_logic_vector(23 downto 0) := x"800003";
--       settings for the SODA : 
--         bit0 : enable SODA packets
--         bit1 : reset timestamp counters
--         bit2 : Enable data taking 
--         bit3 : Disable data taking
--         bit4 : Enable data to Compute Node
--         bit5 : Enable waveforms to Compute Node
--         bit6 : Select multiplexer status from waveform instead of pulses
--         bit7 : Enable external SODA
--         bit8 : Reset fibers to FEE
--         bit9 : Disable packet limit (minimum time for one packet to prevent UDP buffer overrun)
	constant ADDRESS_MUX_HISTOGRAM : std_logic_vector(23 downto 0) := x"800004"; --(disabled)
--       settings for the histogram : 
--         bit0 : clear the histogram
--         bit1 : start reading of the histogram
--         bit10..8 : Binning of the histogram channels, scaling x-axis :
--            000 = no scaling
--            001 = div 2
--            010 = div 4
--            011 = div 8
--            100 = div 16
--            101 = div 32
--            110 = div 64
--            111 = div 128
--         bit31..16 : Selected unique adc-number
	constant ADDRESS_MUX_TIMESTAMP_ERRORS : std_logic_vector(23 downto 0) := x"800005";
--       number of errors:
--         bit 9..0 : number of timestamp mismatches
--         bit 19..10 : number of skipped pulses
--         bit 29..20 : number of data errors
	constant ADDRESS_MUX_TIMESHIFT : std_logic_vector(23 downto 0) := x"800006";
--       number of  clockcycles (incl. constant fraction) to compensate for delay SODA to FEE
--         bit 10..0 : compensation time, fractional part; number of bits for constant fraction, see CF_FRACTIONBIT
--         bit 30..16 : compensation time, integer part
--         bit 31 : load LUT mode, after set to 1 starts with ADC0 on each write, and so on
	constant ADDRESS_MUX_EXTRACTWAVE : std_logic_vector(23 downto 0) := x"800007";
--       start extracting waveform of 1 pileup pulse:
--         bit 15..0 : selected adcnumber
--         bit 16 : select 1 adc, otherwise take first data arriving
--         bit 17 : select 1 low/high combination instead of 1 adc channel
	constant ADDRESS_MUX_EXTRACTDATA : std_logic_vector(23 downto 0) := x"800008";
--       start extracting data of 1 pulse:
--         bit 15..0 : selected adcnumber
--         bit 16 : select 1 adc, otherwise take first data arriving
--         bit 17 : select 1 low/high combination instead of 1 adc channel
	constant ADDRESS_MUX_SYSMON : std_logic_vector(23 downto 0) := x"80000c";
--       write to FPGA system monitor
--         bit 31 : select read/write, write='0', read='1'
--         bit 30 : reset/reconfigure FPGA system monitor
--         bit 22..16 : 7-bits address of FPGA system monitor
--         bit 15..0 : 16-bits data for FPGA system monitor
--       read from FPGA system monitor, effective address is the last address at data bits 30..16 that was written
--         bit 30..16 : 7-bits effective address of FPGA system monitor
--         bit 15..0 : data from FPGA system monitor
	constant ADDRESS_MUX_CROSSSWITCH : std_logic_vector(23 downto 0) := x"80000d";
--       write to cross switch configuration
--         bit 31..0 : corresponding ADC input will be combined with the same ADC input channel on the neighbouring ADC board
	constant ADDRESS_MUX_ENERGYCORRECTION : std_logic_vector(23 downto 0) := x"80000e";
--       energy correction Look Up Table
--         bit 15..0 : gain correction (multiplying factor shifted by number of scalingsbits)
--         bit 30..16 : offset for energy
--         bit 31 : loading LUT mode, after set to 1 starts with ADC0 on each write, and so on

-- addresses slowcontrol commands for Multiplexer
	constant ADDRESS_BOARDNUMBER : std_logic_vector(23 downto 0) := x"002000";
--         bit11..0 = sets the unique boardnumber
--         bit31 = initialize all FEE registers that have been set from the shadow registers in the Data Concentrator

-- addresses slowcontrol commands for Front End Electronics board
--   address 0..FEESLOWCONTROLBOARDADDRESS-1 are the addresses for each ADC channel.
--   even numbered addresses contains register_A, odd numbered registers contains register_B
--       board_register A: write
--         register_A(7..0) = threshold High
--         register_A(15..8) = threshold Low
--         register_A(16) = disable High
--         register_A(17) = disable Low
--         register_A(23..18) = I/Max discard
--         register_A(29..24) = I/Max pileup
--       board_register B: write
--         register_B(7..0) = minimum pulselength
--         register_B(15..8) = pileup length
--         register_B(23..16) = maximum wavelength
--         register_B(24) = fullsize High
--         register_B(25) = fullsize Low
--         register_B(29..26) = CF delay
	constant ADDRESS_FEE_CONTROL : std_logic_vector(7 downto 0) := conv_std_logic_vector(FEESLOWCONTROLBOARDADDRESS,8);
--         bit0: reset all
--         bit2: clear errors
--         bit3: enable waveforms
--         bit20..16 = select channel for frequency measurement
--         bit 21 = reset/initializes FPGA System monitor
--         bit 23..22 = ADC index from FPGA System monitor: 0=temp, 1=VCCint, 2=VCCaux, 3=spare, change activates read
	constant ADDRESS_FEE_STATUS : std_logic_vector(7 downto 0) := conv_std_logic_vector(FEESLOWCONTROLBOARDADDRESS+1,8);
--       write:
--         bit4..0 : MWD width, depends on MWD_WIDTHBITS
--         bit26..16 : lowest part of MWD tau factor, depends on MWD_TAUBITS
--       read:
--         bit1 : Data Taken enabled (enable and disabled is done with SODA packets)
--         bit 5..4 = ADC index from FPGA System monitor: 0=temp, 1=VCCint, 2=VCCaux, 3=spare
--         bit 15..6 = ADC value from FPGA System monitor
--         bit23..16 : error occurred bits: in case of error a bit is set. Clearing is done with ADDRESS_FEE_CONTROL
--            bit16 : error : NotInTable
--            bit17 : error : receive data error (slowcontrol)
--            bit18 : error : slowcontrol buffer overrun
--            bit19 : error : not used
--            bit20 : error : transmit data error, multiplexer error
--            bit21 : error : receive data buffer overrun
--            bit22 : error : adc data buffer overrun
--            bit23 : error : receive fiber not locked
	constant ADDRESS_FEE_SLOWCONTROLERROR : std_logic_vector(7 downto 0) := conv_std_logic_vector(FEESLOWCONTROLBOARDADDRESS+2,8);
--            data not important; this slowcontrol command indicates buffer full
	constant ADDRESS_FEE_MEASURE_FREQUENCY : std_logic_vector(7 downto 0) := conv_std_logic_vector(FEESLOWCONTROLBOARDADDRESS+3,8);
--            bit31..0 : number of hits in one second
	constant ADDRESS_FEE_REQUESTALLREGISTERS : std_logic_vector(7 downto 0) := conv_std_logic_vector(FEESLOWCONTROLBOARDADDRESS+4,8);

	type array_muxregister_type is array(0 to NROFMUXREGS-1) of std_logic_vector(31 downto 0);
	
	type array_adc_type is array(0 to NROFADCS-1) of std_logic_vector(ADCBITS-1 downto 0);
	type array_adc64bits_type is array(0 to NROFADCS-1) of std_logic_vector(63 downto 0);
	type array_adc48bits_type is array(0 to NROFADCS-1) of std_logic_vector(47 downto 0);
	type array_adc36bits_type is array(0 to NROFADCS-1) of std_logic_vector(35 downto 0);
	type array_adc32bits_type is array(0 to NROFADCS-1) of std_logic_vector(31 downto 0);
	type array_adc24bits_type is array(0 to NROFADCS-1) of std_logic_vector(23 downto 0);
	type array_adc16bits_type is array(0 to NROFADCS-1) of std_logic_vector(15 downto 0);
	type array_adc9bits_type is array(0 to NROFADCS-1) of std_logic_vector(8 downto 0);
	type array_adc8bits_type is array(0 to NROFADCS-1) of std_logic_vector(7 downto 0);
	type array_adc4bits_type is array(0 to NROFADCS-1) of std_logic_vector(3 downto 0);

	type array_halfadc36bits_type is array(0 to NROFADCS/2-1) of std_logic_vector(35 downto 0);
	type array_halfadc32bits_type is array(0 to NROFADCS/2-1) of std_logic_vector(31 downto 0);
	type array_halfadc16bits_type is array(0 to NROFADCS/2-1) of std_logic_vector(15 downto 0);
	type array_halfadc9bits_type is array(0 to NROFADCS/2-1) of std_logic_vector(8 downto 0);
	type array_halfadc8bits_type is array(0 to NROFADCS/2-1) of std_logic_vector(7 downto 0);
	
	type array_fiber64bits_type is array(0 to NROFFIBERS-1) of std_logic_vector(63 downto 0);
	type array_fiber48bits_type is array(0 to NROFFIBERS-1) of std_logic_vector(47 downto 0);
	type array_fiber36bits_type is array(0 to NROFFIBERS-1) of std_logic_vector(35 downto 0);
	type array_fiber32bits_type is array(0 to NROFFIBERS-1) of std_logic_vector(31 downto 0);
	type array_fiber31bits_type is array(0 to NROFFIBERS-1) of std_logic_vector(30 downto 0);
	type array_fiber24bits_type is array(0 to NROFFIBERS-1) of std_logic_vector(23 downto 0);
	type array_fiber16bits_type is array(0 to NROFFIBERS-1) of std_logic_vector(15 downto 0);
	type array_fiber12bits_type is array(0 to NROFFIBERS-1) of std_logic_vector(11 downto 0);
	type array_fiber10bits_type is array(0 to NROFFIBERS-1) of std_logic_vector(9 downto 0);
	type array_fiber9bits_type is array(0 to NROFFIBERS-1) of std_logic_vector(8 downto 0);
	type array_fiber8bits_type is array(0 to NROFFIBERS-1) of std_logic_vector(7 downto 0);
	type array_fiber4bits_type is array(0 to NROFFIBERS-1) of std_logic_vector(3 downto 0);

	type array_DCadc36bits_type is array(0 to NROFADCS/(ADCINDEXSHIFT+1)-1) of std_logic_vector(35 downto 0);
	type array_fiberXadc36bits_type is array(0 to NROFFIBERS*(NROFADCS/(ADCINDEXSHIFT+1))-1) of std_logic_vector(35 downto 0);
	type array_fiberXadc16bits_type is array(0 to NROFFIBERS*(NROFADCS/(ADCINDEXSHIFT+1))-1) of std_logic_vector(15 downto 0);
	type twologarray_type is array(0 to 128) of natural;
	constant twologarray : twologarray_type :=
(0,0,1,1,2,2,2,2,3,3,3,3,3,3,3,3,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,
6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,7);
	type array_fiberXadcCrossSwitch_type is array(0 to NROFFIBERS*NROFADCS/(ADCINDEXSHIFT+1)-1) of std_logic_vector(twologarray(NROFFIBERS*NROFADCS/(ADCINDEXSHIFT+1))-1 downto 0);

----------------------------------------------------------------------------------
-- add_hamming_code_26_32
-- Fills in Hamming code bits on positions 0,1,3,7,15,31 of a 32-bits word.
-- The Hamming code is calculated with additional parity to be able to detect
-- an error in 2 bits.
-- 
-- Inputs:
--     data_in : 32 bits data input, with 26 bits real data, the others will be filled with Hamming code
-- 
-- Return:
--     32 bits data output, 26 bits original data and bits 0,1,3,7,15,31 filled with Hamming code
-- 
----------------------------------------------------------------------------------
	function add_hamming_code_26_32 (data_in : in std_logic_vector) return std_logic_vector;
	

----------------------------------------------------------------------------------
-- calc_next_channel
-- Calculates the next index in a std_logic_vector that has value '0';
-- Used to determine the next ADC-channel to select in a multiplexer.
-- If all values are '1' then the same index is returned.
-- 
-- Inputs:
--     adcreading : starting index in the std_logic_vector
--     dfifo_empty : std_logic_vector to select the next index with value '0'
-- 
-- Return:
--     Next index in std_logic_vector with '0'
-- 
----------------------------------------------------------------------------------
	function calc_next_channel(adcreading : integer; dfifo_empty : std_logic_vector) return integer;


----------------------------------------------------------------------------------
-- calc_next_channel
-- Calculates the next index in a std_logic_vector that has value '1';
-- Used to determine the next ADC-channel to select in a multiplexer.
-- If all values are '0' then the same index is returned.
-- 
-- Inputs:
--     adcreading : starting index in the std_logic_vector
--     data_available : std_logic_vector to select the next index with value '1'
-- 
-- Return:
--     Next index in std_logic_vector with '1'
-- 
----------------------------------------------------------------------------------
	function calc_next_channel_set(adcreading : integer; data_available : std_logic_vector) return integer;


----------------------------------------------------------------------------------
-- std_logic_vector_valid
-- Checks if all bits in std_logic_vector are valid (0 or 1) to suppress conv_integer warnings during simulation
-- 
-- Inputs:
--     data : std_logic_vector to check
-- 
-- Return:
--     true if the std_logic_vector data is valid (only '0' and '1')
-- 
----------------------------------------------------------------------------------
	function std_logic_vector_valid(data : in std_logic_vector) return boolean;


end panda_package;


package body panda_package is

function calc_next_channel(adcreading : integer; dfifo_empty : std_logic_vector) return integer is
variable i : integer range 0 to dfifo_empty'high+1;
variable c : integer range 0 to dfifo_empty'high;
begin
	i := 0;
	if adcreading=dfifo_empty'high then
		c := 0;
	else
		c := adcreading+1;
	end if;
	while (i/=dfifo_empty'high+1) and (dfifo_empty(c)='1') loop
		i := i+1;
		if (c<dfifo_empty'high) then 
			c := c+1;
		else
			c:=0;
		end if;
	end loop;
	return c;
end function;

function calc_next_channel_set(adcreading : integer; data_available : std_logic_vector) return integer is
variable i : integer range 0 to data_available'high+1;
variable c : integer range 0 to data_available'high;
begin
	i := 0;
	if adcreading=data_available'high then
		c := 0;
	else
		c := adcreading+1;
	end if;
	while (i/=data_available'high+1) and (data_available(c)='0') loop
		i := i+1;
		if (c<data_available'high) then 
			c := c+1;
		else
			c:=0;
		end if;
	end loop;
	return c;
end function;


function add_hamming_code_26_32 (data_in : in std_logic_vector) return std_logic_vector is
variable din_S : std_logic_vector(25 downto 0);
variable parity_S : std_logic_vector(5 downto 0);
variable dout_S : std_logic_vector(31 downto 0);
begin
	din_S(0) := data_in(2);
	din_S(1) := data_in(4);
	din_S(2) := data_in(5);
	din_S(3) := data_in(6);
	din_S(4) := data_in(8);
	din_S(5) := data_in(9);
	din_S(6) := data_in(10);
	din_S(7) := data_in(11);
	din_S(8) := data_in(12);
	din_S(9) := data_in(13);
	din_S(10) := data_in(14);
	din_S(11) := data_in(16);
	din_S(12) := data_in(17);
	din_S(13) := data_in(18);
	din_S(14) := data_in(19);
	din_S(15) := data_in(20);
	din_S(16) := data_in(21);
	din_S(17) := data_in(22);
	din_S(18) := data_in(23);
	din_S(19) := data_in(24);
	din_S(20) := data_in(25);
	din_S(21) := data_in(26);
	din_S(22) := data_in(27);
	din_S(23) := data_in(28);
	din_S(24) := data_in(29);
	din_S(25) := data_in(30);

-- calculates the Hamming code parity bits
parity_S(0) := din_S(0) xor din_S(1) xor din_S(3) xor din_S(4) xor din_S(6) xor din_S(8) xor din_S(10) xor din_S(11) 
			xor din_S(13) xor din_S(15) xor din_S(17) xor din_S(19) xor din_S(21) xor din_S(23) xor din_S(25);
parity_S(1) := din_S(0) xor din_S(2) xor din_S(3) xor din_S(5) xor din_S(6) xor din_S(9) xor din_S(10) xor din_S(12) 
			xor din_S(13) xor din_S(16) xor din_S(17) xor din_S(20) xor din_S(21) xor din_S(24) xor din_S(25);
parity_S(2) := din_S(1) xor din_S(2) xor din_S(3) xor din_S(7) xor din_S(8) xor din_S(9) xor din_S(10) xor din_S(14) 
			xor din_S(15) xor din_S(16) xor din_S(17) xor din_S(22) xor din_S(23) xor din_S(24) xor din_S(25);
parity_S(3) := din_S(4) xor din_S(5) xor din_S(6) xor din_S(7) xor din_S(8) xor din_S(9) xor din_S(10) xor din_S(18) 
			xor din_S(19) xor din_S(20) xor din_S(21) xor din_S(22) xor din_S(23) xor din_S(24) xor din_S(25);
parity_S(4) := din_S(11) xor din_S(12) xor din_S(13) xor din_S(14) xor din_S(15) xor din_S(16) xor din_S(17) xor din_S(18) 
			xor din_S(19) xor din_S(20) xor din_S(21) xor din_S(22) xor din_S(23) xor din_S(24) xor din_S(25);
parity_S(5) := din_S(0) xor din_S(1) xor din_S(2) xor din_S(3) xor din_S(4) xor din_S(5) xor din_S(6) xor din_S(7) 
			xor din_S(8) xor din_S(9) xor din_S(10) xor din_S(11) xor din_S(12) xor din_S(13) xor din_S(14) 
			xor din_S(15) xor din_S(16) xor din_S(17) xor din_S(18) xor din_S(19) xor din_S(20) xor din_S(21) 
			xor din_S(22) xor din_S(23) xor din_S(24) xor din_S(25) xor parity_S(0) xor parity_S(1) xor parity_S(2) 
			xor parity_S(3) xor parity_S(4);

-- collect the right bits
	dout_S(0) := parity_S(0);
	dout_S(1) := parity_S(1);
	dout_S(3) := parity_S(2);
	dout_S(7) := parity_S(3);
	dout_S(15) := parity_S(4);
	dout_S(31) := parity_S(5);

	dout_S(2) := din_S(0);
	dout_S(4) := din_S(1);
	dout_S(5) := din_S(2);
	dout_S(6) := din_S(3);
	dout_S(8) := din_S(4);
	dout_S(9) := din_S(5);
	dout_S(10) := din_S(6);
	dout_S(11) := din_S(7);
	dout_S(12) := din_S(8);
	dout_S(13) := din_S(9);
	dout_S(14) := din_S(10);
	dout_S(16) := din_S(11);
	dout_S(17) := din_S(12);
	dout_S(18) := din_S(13);
	dout_S(19) := din_S(14);
	dout_S(20) := din_S(15);
	dout_S(21) := din_S(16);
	dout_S(22) := din_S(17);
	dout_S(23) := din_S(18);
	dout_S(24) := din_S(19);
	dout_S(25) := din_S(20);
	dout_S(26) := din_S(21);
	dout_S(27) := din_S(22);
	dout_S(28) := din_S(23);
	dout_S(29) := din_S(24);
	dout_S(30) := din_S(25);
	return dout_S;
end function;


function std_logic_vector_valid(data : in std_logic_vector) return boolean is
variable i : integer range 0 to data'high;
variable b : boolean;
begin
	i := 0;
	b := true;
   while i<data'high loop
		if (data(i)='0') or (data(i)='1') then
		else
			b := false;
		end if;
		i := i+1;
	end loop;
	return b;
end function;


end panda_package;
