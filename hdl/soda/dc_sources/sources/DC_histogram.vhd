----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   05-03-2012
-- Module Name:   DC_histogram
-- Description:   Puts the results in a histogram
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;
USE work.panda_package.all;

----------------------------------------------------------------------------------
-- DC_histogram
-- Module make a histogram of the energies of the results of one adc-channel.
-- The input pulse data consists of the following items (parallel)
--        channel : adc-index
--        statusbyte : 8 bit status information
--        energy : pulse energy
--        timefraction : fraction part of the timestamp
--        timestamp : 15 bits timestamp, synchronised to master SODA clock
--        superburstnumber : 31 bits superburst number
-- Only the energy from the data from the selected adcnumber (16 bits) is taken into account.
--
-- Library
--     work.panda_package :  for type declarations and constants
-- 
-- Generics:
--     HISTOGRAM_SIZEBITS : number of bits for the histogram x-axis, 2^HISTOGRAM_SIZEBITS=number of histogram channels
-- 
-- Inputs:
--     write_clock : clock for incoming data
--     read_clock : clock for outgoing data
--     reset : reset of all components
--     adcnumber : unique number of the adc
--     clear : starts clearing the histogram
--     binning : scale the histogram : 
--            000 = no scaling
--            001 = div 2
--            010 = div 4
--            011 = div 8
--            100 = div 16
--            101 = div 32
--            110 = div 64
--            111 = div 128
--     pulse_data : 36 bits data with Feature Extraction Results, each 4*36-bits:
--        word0 : 0 & 0000 & timestamp(15..0)
--        word1 : 1 & 00 & superburstnumber(23..0)
--        word2 : 2 & statusbyte & 00 & adcnumber
--        word3 : 3 & timefraction & energy
--     pulse_data_write : write signal for the pulse_data
--     histogram_startreading : start reading the histogram data
--     histogram_read : read signak for the histogram buffer fifo
-- 
-- Outputs:
--     histogram_data : resulting histogram data: on every read the next value
--     histogram_available : histogram_data available (not empty from fifo)
-- 
-- Components:
--     histogram : Module for histogram 
--     async_fifo_af_512x32 : fifo with almost_full for histogram data
--
----------------------------------------------------------------------------------

entity DC_histogram is
	generic (
		HISTOGRAM_SIZEBITS : natural := 12
	);
	port ( 
		write_clock             : in std_logic;
		read_clock              : in std_logic;
		reset                   : in std_logic;
		testword0               : out std_logic_vector (35 downto 0);
		adcnumber               : in std_logic_vector(15 downto 0);
		clear                   : in std_logic;
		binning                 : in std_logic_vector(2 downto 0);
		channel                 : in std_logic_vector(15 downto 0);
		statusbyte              : in std_logic_vector(7 downto 0);
		energy                  : in std_logic_vector(15 downto 0);
		timefraction            : in std_logic_vector(11 downto 0);
		timestamp               : in std_logic_vector(15 downto 0);
		superburstnumber        : in std_logic_vector(30 downto 0);		
		pulse_data_write        : in std_logic;
		histogram_startreading  : in std_logic;
		histogram_data          : out std_logic_vector(31 downto 0);
		histogram_read          : in std_logic;
		histogram_available     : out std_logic		
		);
end DC_histogram;

architecture Behavioral of DC_histogram is

component histogram is
	generic (
		HISTOGRAM_SIZEBITS      : natural := HISTOGRAM_SIZEBITS;
		rangebits  : natural    := 32
		);
	port (
		clock                   : in std_logic;
		clear                   : in std_logic;
		datain                  : in std_logic_vector(HISTOGRAM_SIZEBITS-1 downto 0);
		writerequest            : in std_logic;
		address                 : in std_logic_vector(HISTOGRAM_SIZEBITS-1 downto 0);
		readrequest             : in std_logic;
		dataout                 : out std_logic_vector(rangebits-1 downto 0);
		dataout_valid           : out std_logic
		);
end component;

component async_fifo_af_512x32
	port (
		rst                     : in std_logic;
		wr_clk                  : in std_logic;
		rd_clk                  : in std_logic;
		din                     : in std_logic_vector(31 downto 0);
		wr_en                   : in std_logic;
		rd_en                   : in std_logic;
		dout                    : out std_logic_vector(31 downto 0);
		full                    : out std_logic;
		almost_full             : out std_logic;
		empty                   : out std_logic);
end component;

signal reset_writeclock_S     : std_logic := '0';
signal clear_S                : std_logic := '0';
signal pulsevalue_S           : std_logic_vector(HISTOGRAM_SIZEBITS-1 downto 0) := (others => '0');
signal pulsevalue_write_S     : std_logic := '0';
signal pulsevalue_address_S   : std_logic_vector(HISTOGRAM_SIZEBITS-1 downto 0) := (others => '0');
signal histogram_read_S       : std_logic := '0';
signal histogram_data_S       : std_logic_vector(31 downto 0) := (others => '0');
signal histogram_data_valid_S : std_logic := '0';
signal fifoempty_S            : std_logic := '0';
signal fifo_write_S           : std_logic := '0';
signal fifofull_S             : std_logic := '0';
signal fifoalmost_full        : std_logic := '0';

signal fifo_data_in_S         : std_logic_vector(31 downto 0) := (others => '0');

signal histogram_startreading_S : std_logic := '0';
signal reading_s              : std_logic := '0';


begin

fifo: async_fifo_af_512x32 port map(
		rst => histogram_startreading,
		wr_clk => write_clock,
		rd_clk => read_clock,
		din => fifo_data_in_S,
		wr_en => fifo_write_S,
		rd_en => histogram_read,
		dout => histogram_data,
		full => fifofull_S,
		almost_full => fifoalmost_full,
		empty => fifoempty_S);
histogram_available <= '1' when fifoempty_S='0' else '0';

process(write_clock)
constant ones  : std_logic_vector(HISTOGRAM_SIZEBITS-1 downto 0) := (others => '1');
begin
	if (rising_edge(write_clock)) then 
		if (reset_writeclock_S = '1') then
			histogram_startreading_S <= '0';
			reading_S <= '0';
			histogram_read_S <= '0';
			fifo_write_S <= '0';
		else
			if (histogram_startreading='1') and (histogram_startreading_S='0') then
				reading_S <= '1';
				pulsevalue_address_S <= (others => '0');
				histogram_read_S <= '1';
			elsif reading_S='1' then
				if (histogram_data_valid_S='1') and (histogram_read_S/='1') then -- check also on read
					fifo_data_in_S <= histogram_data_S;
					if fifoalmost_full='0' then
						fifo_write_S <= '1';
						if pulsevalue_address_S /= ones then
							pulsevalue_address_S <= pulsevalue_address_S+1;
							histogram_read_S <= '1';
						else
							reading_S <= '0';
							histogram_read_S <= '0';
						end if;
					else
						fifo_write_S <= '0';				
						histogram_read_S <= '0';
					end if;
				else
					fifo_write_S <= '0';
					histogram_read_S <= '0';
				end if;
			else
				fifo_write_S <= '0';
				histogram_read_S <= '0';
			end if;
			histogram_startreading_S <= histogram_startreading;
		end if;
		reset_writeclock_S <= reset;
	end if;
end process;

histogram1: histogram port map(
		clock => write_clock,
		clear => clear_S,
		datain => pulsevalue_S,
		writerequest => pulsevalue_write_S,
		address => pulsevalue_address_S,
		readrequest => histogram_read_S,
		dataout => histogram_data_S,
		dataout_valid => histogram_data_valid_S);

process(write_clock)
constant zeros  : std_logic_vector(15 downto 0) := (others => '0');
variable val_V : std_logic_vector(15 downto 0);
variable his_V : std_logic_vector(15 downto 0);
begin
	if (rising_edge(write_clock)) then 
		if (reset_writeclock_S = '1') then
			clear_S <= '1';
			pulsevalue_write_S <= '0';
		else
			clear_S <= clear;
			if pulse_data_write='1' then
				val_V := energy;
				case binning is 
					when "000" => his_V := val_V;
					when "001" => his_V := '0' & val_V(15 downto 1);
					when "010" => his_V := "00" & val_V(15 downto 2);
					when "011" => his_V := "000" & val_V(15 downto 3);
					when "100" => his_V := "0000" & val_V(15 downto 4);
					when "101" => his_V := "00000" & val_V(15 downto 5);
					when "110" => his_V := "000000" & val_V(15 downto 6);
					when "111" => his_V := "0000000" & val_V(15 downto 7);
					when others => his_V := val_V;
				end case;
				if channel=adcnumber then
					if (HISTOGRAM_SIZEBITS<16) and (his_V(15 downto HISTOGRAM_SIZEBITS)/=zeros(15 downto HISTOGRAM_SIZEBITS)) then
--							if conv_integer(unsigned(his_V))>2**HISTOGRAM_SIZEBITS-1 then
						pulsevalue_S <= (others => '1');
					else
						pulsevalue_S <= his_V(HISTOGRAM_SIZEBITS-1 downto 0);
					end if;
					pulsevalue_write_S <= '1';
				end if;
			else
				pulsevalue_write_S <= '0';
			end if;
		end if;
	end if;
end process;

testword0(12 downto 0) <= histogram_data_S(12 downto 0); -- pulsevalue_S(HISTOGRAM_SIZEBITS-1 downto 0);
testword0(13) <= clear_S;
testword0(14) <= pulsevalue_write_S;
testword0(15) <= histogram_read_S;
testword0(16) <= histogram_data_valid_S;
testword0(17) <= fifoempty_S;
testword0(18) <= fifo_write_S;
testword0(19) <= fifofull_S;
testword0(20) <= fifoalmost_full;
testword0(21) <= histogram_startreading_S;
testword0(22) <= reading_s;
testword0(23) <= '0';
testword0(35 downto 24) <= pulsevalue_address_S;







end Behavioral;
