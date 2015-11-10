----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   27-02-2012
-- Module Name:   DC_extract_data
-- Description:   Extract one data record from stream
-- Modifications:
--   30-07-2014   Timestamp from FEE is now timestamp counter within superburst, output word2 is the superburstnumber
--   27-10-2014   Fifo for all data members in parallel
--   21-05-2015   Additional clock synchronization
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;
USE work.panda_package.all;

----------------------------------------------------------------------------------
-- DC_extract_data
-- Extract one data record from stream.
-- The input pulse data consists of the following items (parallel)
--        channel : adc-index
--        statusbyte : 8 bit status information
--        energy : pulse energy
--        timefraction : fraction part of the timestamp
--        timestamp : 16 bits timestamp within superburst, synchronised to master SODA clock
--        superburstnumber : 31 bits superburst number
-- The output :
--        word0 : statusbyte & 00 & adcnumber
--        word1 : timefraction & energy
--        word2 : '0' & superburstnumber
--        word3 : 0000 & timestamp(15..0)
--
-- Library
--     work.panda_package :  for type declarations and constants
-- 
-- Generics:
-- 
-- Inputs:
--     write_clock : clock for incoming data
--     read_clock : clock for outgoing data
--     reset : reset of all components
--     start : start waiting for data and extract one data-pulse
--     make_selection : select one adcnumber from the stream, otherwise take the first arriving data
--     dualgain : select both high and low gain channels (discard lowest bit from adcnumber)
--     adcnumber : number of the adc to extract, if make_selection='1'
--     channel : data input : adc channel
--     statusbyte : data input : status
--     energy : data input : pulse energy
--     timefraction : data input : Constant Fraction time
--     timestamp : data input : time within superburst
--     superburstnumber : data input : superburst number
--     pulse_data_write : write signal for the pulse_data
--     pulse_data_select : select the 32-bits word index of the extracted data
-- 
-- Outputs:
--     ready : extracted pulse-data available
--     pulse_data_out : extracted pulse data (32 bits, select with pulse_data_select):
--        word0 : statusbyte & 00 & adcnumber
--        word1 : timefraction & energy
--        word2 : '0' & superburstnumber
--        word3 : 0000 & timestamp(15..0)
-- 
-- Components:
--     async_fifo_af_512x36 : Asynchronous fifo 36bits wide, 512 words deep
--     sync_bit : Synchronization for 1 bit cross clock signal
--
----------------------------------------------------------------------------------

entity DC_extract_data is
	port ( 
		write_clock             : in std_logic;
		read_clock              : in std_logic;
		reset                   : in std_logic;
		start                   : in std_logic;
		make_selection          : in std_logic;
		dualgain                : in std_logic;
		adcnumber               : in std_logic_vector(15 downto 0);		
		channel                 : in std_logic_vector(15 downto 0);
		statusbyte              : in std_logic_vector(7 downto 0);
		energy                  : in std_logic_vector(15 downto 0);
		timefraction            : in std_logic_vector(11 downto 0);
		timestamp               : in std_logic_vector(15 downto 0);
		superburstnumber        : in std_logic_vector(30 downto 0);		
		pulse_data_write        : in std_logic;
		ready                   : out std_logic;
		pulse_data_select       : in std_logic_vector(1 downto 0);
		pulse_data_out          : out std_logic_vector(31 downto 0);
		testword0               : out std_logic_vector(35 downto 0) := (others => '0')
		);
end DC_extract_data;

architecture Behavioral of DC_extract_data is

component async_fifo_512x99 is
	port (
		rst                     : in std_logic;
		wr_clk                  : in std_logic;
		rd_clk                  : in std_logic;
		din                     : in std_logic_vector(98 downto 0);
		wr_en                   : in std_logic;
		rd_en                   : in std_logic;
		dout                    : out std_logic_vector(98 downto 0);
		full                    : out std_logic;
		empty                   : out std_logic);
end component;

component sync_bit is
	port (
		clock       : in  std_logic;
		data_in     : in  std_logic;
		data_out    : out std_logic
	);
end component;

signal make_selection_S       : std_logic;
signal dualgain_S             : std_logic;
signal ready_S                : std_logic := '0';

signal adcnumber_S            : std_logic_vector(15 downto 0);
signal timestamp_S            : std_logic_vector(15 downto 0);
signal superburstnumber_S     : std_logic_vector(30 downto 0);
signal statusbyte_S           : std_logic_vector(7 downto 0);
signal channel_S              : std_logic_vector(15 downto 0);
signal timefraction_S         : std_logic_vector(11 downto 0);
signal energy_S               : std_logic_vector(15 downto 0);


signal fifo_write_S           : std_logic := '0';
signal fifo_read_S            : std_logic := '0';
signal fifo_full_S            : std_logic := '0';
signal fifo_empty_S           : std_logic := '0';

begin

asyncdatafifo: async_fifo_512x99 port map(
		rst => '0',
		wr_clk => write_clock,
		rd_clk => read_clock,
		din(15 downto 0) => channel,
		din(31 downto 16) => energy,
		din(47 downto 32) => timestamp,
		din(55 downto 48) => statusbyte,
		din(67 downto 56) => timefraction,
		din(98 downto 68) => superburstnumber,
		wr_en => fifo_write_S,
		rd_en => fifo_read_S,
		dout(15 downto 0) => channel_S,
		dout(31 downto 16) => energy_S,
		dout(47 downto 32) => timestamp_S,
		dout(55 downto 48) => statusbyte_S,
		dout(67 downto 56) => timefraction_S,
		dout(98 downto 68) => superburstnumber_S,
		full => fifo_full_S,
		empty => fifo_empty_S);
		
fifo_write_S <= '1' when ((pulse_data_write='1') and (fifo_full_S='0')) and
		((make_selection_S='0') or
			((channel=adcnumber_S) and (dualgain_S='0')) or
			((channel(15 downto 1)=adcnumber_S(15 downto 1)) and (dualgain_S='1')))
	else '0';

process(write_clock)
begin
	if (rising_edge(write_clock)) then 
		adcnumber_S <= adcnumber;
	end if;
end process;	
sync_make_selection: sync_bit port map(
	clock => write_clock,
	data_in => make_selection,
	data_out => make_selection_S);
sync_dualgain: sync_bit port map(
	clock => write_clock,
	data_in => dualgain,
	data_out => dualgain_S);
		
pulse_data_out <= 
	statusbyte_S & x"00" & channel_S when pulse_data_select="00" else
	"0000" & timefraction_S & energy_S when pulse_data_select="01" else
	'0' & superburstnumber_S when pulse_data_select="10" else
	x"0000" & timestamp_S; -- when pulse_data_select="11" else
	
ready <= ready_S;
process(read_clock)
begin
	if (rising_edge(read_clock)) then 
		fifo_read_S <= '0';
		if start='1' then
			ready_S <= '0';
		elsif ready_S='0' then
			if fifo_empty_S='0' then
				fifo_read_S <= '1';
				ready_S <= '1';
			end if;
		end if;
	end if;
end process;		


end Behavioral;