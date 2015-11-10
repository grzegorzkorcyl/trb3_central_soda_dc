----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   11-09-2014
-- Module Name:   DC_CF_MAX_correction
-- Description:   Calculates energy and timestamp and performs correction with Look Up Table 
-- Modifications:
--   18-09-2014   different clock for loading
--   11-10-2014   Energy is measured with integral, not with the maximum, so maximum-correction part is not valid 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_ARITH.ALL;
use IEEE.std_logic_UNSIGNED.ALL;
library work;
USE work.panda_package.all;

------------------------------------------------------------------------------------------------------
-- DC_CF_MAX_correction
--     Calculates energy and timestamp and performs correction with Look Up Table 
--     Input data contains timestamp, adcnumber, status-byte, two sequential samples, containing the maximum and 
--     the Constant Fraction sample before and after the zero crossing.
--
--     The first part of the Constant Fraction is done in the ADC input modules:
--           CF_signal = -ADCvalue + 4*ADCvalue'delayed
--     This results in a signal that has a zero-crossing near the rising edge of the pulse.
--     The CF_signal before and after the zerocrossing is passed on and now used to calculate the fractional part of the timestamp:
--           timefraction = -CF_signal_before / (CF_signal_after - CF_signal_before) * 2^CF_FRACTIONBIT
--           with CF_FRACTIONBIT the number of bits of the calculated timefraction
--     After this the Constant Fraction fractional result is corrected for pulse shape with a Look Up Table:
--         correctedFraction = LUT[timefraction]
--
--
-- generics
--     ADCBITS : number of ADC-bits, input data is 2-complement representation: one additional bit
--     CF_FRACTIONBIT : number of bits for the calculated fraction of the precise timestamp
--     MAX_DIVIDERSCALEBITS : number of scaling bits for division two largest samples
--     MAX_LUTSIZEBITS : number of bits the maximum correction Look Up Table
--     MAX_LUTSCALEBITS : number of scaling bits for the correction on the maximum (energy)
--		
-- inputs
--     clock : clock
--     load_clock : clock for loading
--     reset : synchronous reset
--     pulse_superburst : lowest 16-bits of the superburstnumber of the hit
--     pulse_timestamp : 16-bits timestamp within superburst (time of sample before the CF zero crossing)
--     pulse_adcnumber : 16-bits adc channel number
--     pulse_statusbyte : 8-bits status
--     pulse_energy : energy of the pulse, calculated with scaled integral
--     pulse_CF_before : CF_signal value of the value before the zero-crossing (absolute value)
--     pulse_CF_after : CF_signal value of the value after the zero-crossing (absolute value)
--     pulse_write : write signal for pulsedata
--     max_correction : use correction on maximum value with Look Up Table
--     max_LUT_offset : offset for index in maximum correction Look Up Table
--     max_LUT_loading : set in mode for loading a new maximum correction Look Up Table
--     max_LUT_write : write next value in maximum correction Look Up Table
--     fraction_correction : use correction on timestamp fraction with Look Up Table
--     fraction_LUT_loading : set in mode for loading a new timestamp fraction correction Look Up Table
--     fraction_LUT_write : write next value in timestamp fraction correction Look Up Table
--     LUT_data_in : data for writing in the selected LUT : maximum correction or timestamp fraction correction
--     result_allowed : writing of results allowed 
--			  
-- outputs
--     pulse_allowed : allowed to write pulse data
--     result_write : write signal for results
--     adcnumber : 16-bits identification number of the adc
--     superburst : 16 bits of the superburstnumber
--     timestamp : 16 bits timestamp of the CF_signal before the zero-crossing
--     timefraction : calculated fraction of the time-stamp using constant fraction method
--     energy : energy, calculated maximum in waveform
--     statusbyte : 8-bits status
--
-- components
--     shift_register : shift register
--     div_r4_pipe : unsigned divider
--     DC_time_lookuptable : Look Up Table for timestamp fraction correction
--
--
------------------------------------------------------------------------------------------------------



entity DC_CF_MAX_correction is
	generic (
		ADCBITS                 : natural := 14;
		CF_FRACTIONBIT          : natural := 11;
		MAX_DIVIDERSCALEBITS    : natural := 12;
		MAX_LUTSIZEBITS         : natural := 8;
		MAX_LUTSCALEBITS        : natural := 14
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
end DC_CF_MAX_correction;

architecture Behavioral of DC_CF_MAX_correction is

component shift_register is
	generic (
		width                   : natural := 16; 
		depthbits               : natural := 5
		);
    port (
		clock                   : in  std_logic; 
		reset                   : in  std_logic; 
		hold                    : in  std_logic; 
		data_in                 : in std_logic_vector((width-1) downto 0); 
		depth                   : in std_logic_vector((depthbits-1) downto 0);
		data_out                : out  std_logic_vector((width-1) downto 0));
end component;

component div_r4_pipe -- pipeline length=XBITS/GRAIN/DEPTH + 1
	generic (
		XBITS : natural := 32;
		YBITS : natural := 32;
		GRAIN : natural := 2;
		DEPTH : natural := 1
		);
    port (
      a                       : in std_logic_vector(XBITS-1 downto 0);
      b                       : in std_logic_vector(YBITS-1 downto 0);
      clk                     : in std_logic;          
      q                       : out std_logic_vector(XBITS-1 downto 0);
      r                       : out std_logic_vector(YBITS-1 downto 0)
      );
end component;

component DC_time_lookuptable is
	generic (
		lut_addrwidth           : natural := CF_FRACTIONBIT;
		lut_datawidth           : natural := CF_FRACTIONBIT
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

constant zeros                     : std_logic_vector(31 downto 0) := (others => '0');
signal adcnumber_S                 : std_logic_vector(15 downto 0) := (others => '0');
signal superburst_S                : std_logic_vector(15 downto 0);
signal timestamp_S                 : std_logic_vector(15 downto 0);
signal CF_before_S                 : std_logic_vector(15 downto 0);
signal CF_after_S                  : std_logic_vector(15 downto 0);

signal fraction_correction_S       : std_logic;

signal cf_signal_before_S          : std_logic_vector(17 downto 0) := (others => '0');
signal cf_signal_before_scaled_S   : std_logic_vector(27 downto 0);
signal cf_signal_after_S           : std_logic_vector(17 downto 0) := (others => '0');
signal cf_sum_S                    : std_logic_vector(17 downto 0) := (others => '0');
signal timefraction28_S            : std_logic_vector(27 downto 0);

signal timefraction_S              : std_logic_vector(CF_FRACTIONBIT-1 downto 0) := (others => '0');
signal energy_S                    : std_logic_vector(15 downto 0) := (others => '0');
signal energy_out_S                : std_logic_vector(15 downto 0) := (others => '0');

signal statusbyte_S                : std_logic_vector(7 downto 0) := (others => '0');
signal result_write_S              : std_logic := '0';

signal result_shiftreg_in_S        : std_logic_vector(72 downto 0) := (others => '0');
signal result_shiftreg_out_S       : std_logic_vector(72 downto 0) := (others => '0');


signal timefraction_after1clk_S    : std_logic_vector(CF_FRACTIONBIT-1 downto 0) := (others => '0');
signal timefraction_corrected_S    : std_logic_vector(CF_FRACTIONBIT-1 downto 0) := (others => '0');

begin
		
superburst_S <= pulse_superburst;
timestamp_S <= pulse_timestamp;
adcnumber_S <= pulse_adcnumber;
statusbyte_S <= pulse_statusbyte;
energy_S <= pulse_energy;
CF_before_S <= pulse_CF_before;
CF_after_S <= pulse_CF_after;
pulse_allowed <= result_allowed;
result_write_S <= pulse_write;

cf_signal_before_S <= conv_std_logic_vector(conv_integer(unsigned(CF_before_S)),18);
cf_signal_after_S <= conv_std_logic_vector(conv_integer(unsigned(CF_after_S)),18);
						
cf_sum_S <= conv_std_logic_vector(conv_integer(unsigned(cf_signal_after_S))+conv_integer(unsigned(cf_signal_before_S)),18);

cf_signal_before_scaled_S(CF_FRACTIONBIT-1 downto 0) <= (others => '0');
cf_signal_before_scaled_S(27 downto CF_FRACTIONBIT) <= cf_signal_before_S(27-CF_FRACTIONBIT downto 0);
div_r4_pipe1: div_r4_pipe -- pipeline length=XBITS/GRAIN/DEPTH + 1 = 15
	generic map(
		XBITS => 28,
		YBITS => 18
		)
    port map (
      a => cf_signal_before_scaled_S,
      b => cf_sum_S,
      clk => clock,   
      q => timefraction28_S,
      r => open);
timefraction_S <= timefraction28_S(CF_FRACTIONBIT-1 downto 0);

DC_time_lookuptable1: DC_time_lookuptable
	generic map(
		lut_addrwidth => CF_FRACTIONBIT,
		lut_datawidth => CF_FRACTIONBIT
		)
	port map( 
		clock => clock,
		load_clock => load_clock,
		loading => fraction_LUT_loading,
		lut_write  => fraction_LUT_write,
		address => timefraction_S,
		data_in => LUT_data_in(CF_FRACTIONBIT-1 downto 0),
		data_out => timefraction_corrected_S);


result_shiftreg_in_S <=  result_write_S & energy_S & timestamp_S & superburst_S & adcnumber_S & statusbyte_S;
shiftregister2: shift_register 
	generic map(
		width => result_shiftreg_in_S'length, -- signed signal 
		depthbits => 5
		)
	port map(
		clock => clock,
		reset => '0', -- reset,
		hold => '0',
		data_in => result_shiftreg_in_S,
		depth => conv_std_logic_vector(16,5),
		data_out => result_shiftreg_out_S);


energy_out_S <= result_shiftreg_out_S(71 downto 56);

process(clock)
begin
	if (rising_edge(clock)) then 
		timefraction_after1clk_S <= timefraction_S;
		result_write <= result_shiftreg_out_S(72);
		adcnumber <= result_shiftreg_out_S(23 downto 8);
		superburst <= result_shiftreg_out_S(39 downto 24);
		timestamp <= result_shiftreg_out_S(55 downto 40);
		if fraction_correction_S='0' then
			timefraction <= timefraction_after1clk_S;
		else 
			timefraction <= timefraction_corrected_S;
		end if;
		energy <= energy_out_S;
		statusbyte <= result_shiftreg_out_S(7 downto 0);
		fraction_correction_S <= fraction_correction;
	end if;
end process;

		
testword0 <= (others => '0');
testword1 <= (others => '0');


end Behavioral;


