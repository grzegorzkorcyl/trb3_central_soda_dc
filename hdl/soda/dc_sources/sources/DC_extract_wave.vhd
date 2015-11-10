----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   13-03-2012
-- Module Name:   DC_extract_wave
-- Description:   Extract one waveform from stream
-- Modifications:
--    16-09-2014: name changed from MUX_extract_wave to DC_extract_wave
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;
USE work.panda_package.all;

----------------------------------------------------------------------------------
-- DC_extract_wave
-- Extract one data record from stream.
-- The input data consists of 36 bits words, same format as used in waveform multiplexer.
-- The output is 32 bits wide, adc-samples are truncated to 15 bit (signed).
--
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
--     wave_data_in : 36 bits data with Feature Extraction Results, each 4*36-bits:
--        	bits(35..32)="0000" : bits(31..0)=timestamp of maximum value in waveform
--        	bits(35..32)="0001" : bits(31..24)=00 bits(23..0)=SuperBurst number
--        	bits(35..32)="0010" : 
--              bits(31..24) = statusbyte (bit6=overflow) 
--              bits(23..16) = 00
--              bits(15..0) = adcnumber (channel identification)
--        	bits(35..32)="0011" : bits(31..16)=adc sample, bits(15..0)=next adc sample
--        	bits(35..32)="0100" : bits(31..16)=last adc sample, bits(15..0)=0
--        	bits(35..32)="0101" : bits(31..16)=last but one adc sample, bits(15..0)=last adc sample
--        	bits(35..32)="1111" : error: buffer full, waveform not valid
--     wave_data_in_write : write signal for 36-bits input data
--     wave_data_out_read : read signal for extracted waveform
-- 
-- Outputs:
--     ready : extracted pulse-data available
--     wave_data_read : read 36-bits wave data
--     wave_data_out : extracted pulse data (32 bits, sequential with each wave_data_out_read):
--        	word0: bits(31..0)=timestamp of maximum value in waveform
--        	word1: bits(31..24)=00, bits(23..0)=SuperBurst number
--        	word2: bits(31..24) = statusbyte, bits(23..16) = 00, bits(15..0) = adcnumber (channel identification)
--        	word3..n: bit(31)=0, bits(30..16)=adc sample, bit(15)=0, bits(14..0)=next adc sample
--        	last word (1sample): bits(31)=1, bits(30..16)=last adc sample, bit(15)=0, bits(14..0)=0
--        	last word (2samples): bits(31)=0, bits(30..16)=adc sample, bit15=1, bits(14..0)=last adc sample
--        	last word (error): bits(31)=1, bits(30..16)=don't care, bit15=1, bits(14..0)=don't care
-- 
-- Components:
--     async_fifo_af_512x36 : Asynchronous fifo 36bits wide, 512 words deep
--     DC_posedge_to_pulse : Makes a 1-clock pulse on rising edge from signal with different clock
--
----------------------------------------------------------------------------------

entity DC_extract_wave is
	port ( 
		write_clock             : in std_logic;
		read_clock              : in std_logic;
		reset                   : in std_logic;
		start                   : in std_logic;
		make_selection          : in std_logic;
		dualgain                : in std_logic;
		adcnumber               : in std_logic_vector(15 downto 0);		
		wave_data_in            : in std_logic_vector(35 downto 0);
		wave_data_in_write      : in std_logic;
		ready                   : out std_logic;
		wave_data_out           : out std_logic_vector(31 downto 0);
		wave_data_out_read      : in std_logic;
		testword0               : out std_logic_vector(35 downto 0) := (others => '0')
		);
end DC_extract_wave;


architecture Behavioral of DC_extract_wave is

component async_fifo_512x32 is
	port (
		rst                     : in std_logic;
		wr_clk                  : in std_logic;
		rd_clk                  : in std_logic;
		din                     : in std_logic_vector(31 downto 0);
		wr_en                   : in std_logic;
		rd_en                   : in std_logic;
		dout                    : out std_logic_vector(31 downto 0);
		full                    : out std_logic;
		empty                   : out std_logic);
end component;

component DC_posedge_to_pulse is
	port (
		clock_in                : in  std_logic;
		clock_out               : in  std_logic;
		en_clk                  : in  std_logic;
		signal_in               : in  std_logic;
		pulse                   : out std_logic);
end component;

signal reset_wrclk_S          : std_logic := '0';
signal ready_S                : std_logic := '0';


signal fifo_reset_S           : std_logic := '0';
signal fifo_reset0_S          : std_logic := '0';
signal fifo_resetting_S       : std_logic := '0';
signal fifo_write_S           : std_logic := '0';
signal fifo_read_S            : std_logic := '0';
signal fifo_empty_S           : std_logic := '0';
signal fifo_data_in_S         : std_logic_vector(31 downto 0) := (others => '0');
signal fifo_data_out_S        : std_logic_vector(31 downto 0) := (others => '0');

signal startpulse_S           : std_logic := '0';
signal fifo_writing_S         : std_logic := '0';
signal fifo_writing0_S        : std_logic := '0';
signal started_S              : std_logic := '0';

signal error1_S               : std_logic := '0';
signal error2_S               : std_logic := '0';
signal readcount_S            : integer range 0 to 255 := 0;

begin

process(read_clock)
begin
	if (rising_edge(read_clock)) then 
		ready <= ready_S;
	end if;
end process;


makestartepulse: DC_posedge_to_pulse port map(
		clock_in => read_clock,
		clock_out => write_clock,
		en_clk => '1',
		signal_in => start,
		pulse => startpulse_S);

asyncdatafifo: async_fifo_512x32 port map(
		rst => fifo_reset_S,
		wr_clk => write_clock,
		rd_clk => read_clock,
		din => fifo_data_in_S,
		wr_en => fifo_write_S,
		rd_en => fifo_read_S,
		dout => fifo_data_out_S,
		full => open,
		empty => fifo_empty_S);
		
fifo_reset_S <= '1' when (startpulse_S='1') or (reset_wrclk_S='1') or (fifo_reset0_S='1') else '0';
fifo_write_S <= '1' when (wave_data_in_write='1') and (fifo_writing_S='1') 
		and ((fifo_resetting_S='0') and (fifo_reset_S='0')) 
	else '0';
fifo_writing_S <= '1' when (fifo_writing0_S='1')
		or ((wave_data_in(35 downto 32)="0000") and (wave_data_in_write='1') and (started_S='1'))
	else '0';

fifo_data_in_S <= 
		wave_data_in(31 downto 0) 
			when ((wave_data_in(35 downto 32)="0000") or (wave_data_in(35 downto 32)="0001") or (wave_data_in(35 downto 32)="0010")) else
		'0' & wave_data_in(30 downto 16) & '0' & wave_data_in(14 downto 0) 
			when (wave_data_in(35 downto 32)="0011") else
		'0' & wave_data_in(30 downto 16) & '1' & wave_data_in(14 downto 0) 
			when (wave_data_in(35 downto 32)="0101") else
		'1' & wave_data_in(30 downto 16) & '0' & "000000000000000" 
			when (wave_data_in(35 downto 32)="0100") else
		'1' & "000000000000000" & '1' & "000000000000000";
		
wave_data_out <= fifo_data_out_S;
fifo_read_S <= wave_data_out_read;


process(write_clock)
variable resetcounter_V : integer range 0 to 3 := 0;
begin
	if (rising_edge(write_clock)) then 
		if fifo_reset_S='1' then
			resetcounter_V := 0;
			fifo_resetting_S <= '1';
		elsif resetcounter_V<3 then
			resetcounter_V := resetcounter_V+1;
			fifo_resetting_S <= '1';
		else
			fifo_resetting_S <= '0';
		end if;
		if (reset_wrclk_S = '1') then
			fifo_writing0_S <= '0';
			started_S <= '0';
			ready_S <= '0';
			fifo_reset0_S <= '0';
		else
			if started_S='1' then
				if fifo_writing0_S='0' then
					if (wave_data_in(35 downto 32)="0000") and (fifo_write_S='1') then 
						fifo_writing0_S <= '1';
					end if;
					fifo_reset0_S <= '0';
				else
					if wave_data_in_write='1' then
						if (wave_data_in(35 downto 32)="0010") then
							if  (make_selection='0') or 
								((adcnumber(15 downto 0)=wave_data_in(15 downto 0)) and (dualgain='0')) or
								((adcnumber(15 downto 1)=wave_data_in(15 downto 1)) and (dualgain='1')) then
								fifo_reset0_S <= '0';
							else
								fifo_writing0_S <= '0';
								ready_S <= '0';
								fifo_reset0_S <= '1';
							end if;
						elsif (wave_data_in(35 downto 32)="0000") or (wave_data_in(35 downto 32)="0001")  or (wave_data_in(35 downto 32)="0011") then
							fifo_reset0_S <= '0';
						elsif (wave_data_in(35 downto 32)="1111") then
							fifo_writing0_S <= '0';
							ready_S <= '0';
							fifo_reset0_S <= '1';
						else
							fifo_reset0_S <= '0';
							fifo_writing0_S <= '0';
							started_S <= '0';
							ready_S <= '1';
						end if;
					else
						fifo_reset0_S <= '0';
					end if;
				end if;
			else
				fifo_reset0_S <= '0';
				if startpulse_S='1' then
					fifo_writing0_S <= '0';
					started_S <= '1';
					ready_S <= '0';
				end if;					
			end if;
		end if;
		reset_wrclk_S <= reset;
	end if;
end process;


process(write_clock)
variable last_tfifo_in_V : std_logic_vector(3 downto 0) := "0100";
begin
	if (rising_edge(write_clock)) then 
		error1_S <= '0';
		if (wave_data_in_write='1') then
			case last_tfifo_in_V is
				when "0000" =>
					if wave_data_in(35 downto 32)/="0001" then
						error1_S <= '1';
					elsif wave_data_in(31 downto 24)/=x"00" then
						error1_S <= '1';
					end if;
				when "0001" =>
					if wave_data_in(35 downto 32)/="0010" then
						error1_S <= '1';
					elsif wave_data_in(15 downto 4)/=x"111" then
						error1_S <= '1';
					end if;
				when "0010" =>
					if wave_data_in(35 downto 32)/="0011" then
						error1_S <= '1';
					end if;
				when "0011" =>
					if (wave_data_in(35 downto 32)/="0011") and (wave_data_in(35 downto 33)/="010") then
						error1_S <= '1';
					end if;
				when "0100" =>
					if (wave_data_in(35 downto 32)/="0000") then
						error1_S <= '1';
					end if;
				when "0101" =>
					if (wave_data_in(35 downto 32)/="0000") then
						error1_S <= '1';
					end if;
				when others =>
					error1_S <= '1';
			end case;
			last_tfifo_in_V := wave_data_in(35 downto 32);
		end if;
	end if;
end process;



process(read_clock)
variable last_tfifo_in_V : std_logic_vector(31 downto 0) := (others => '0');
variable fifo_read_V : std_logic := '0';
variable resetted_V : integer range 0 to 3 := 0;
variable last_V : std_logic := '0';
begin
	if (rising_edge(read_clock)) then 
		error2_S <= '0';
		if fifo_reset_S='1' then
			resetted_V := 0;
			last_V := '0';
			readcount_S <= 0;
		else
			if fifo_read_V='1' then
				readcount_S <= readcount_S+1;
				if resetted_V<3 then
					if resetted_V=0 then -- timestamp
					elsif resetted_V=1 then -- burst
						if fifo_data_out_S(31 downto 24)/=x"00" then
							error2_S <= '1';
						end if;
					elsif resetted_V=2 then -- adcnr
						if fifo_data_out_S(15 downto 4)/=x"111" then
							error2_S <= '1';
						end if;
					end if;
					resetted_V := resetted_V+1;
					last_V := '0';
				else
					if last_V='1' then
						error2_S <= '1';
					else					
						if (fifo_data_out_S(31)='0') and (fifo_data_out_S(15)='0') then
						elsif (fifo_data_out_S(31)='0') and (fifo_data_out_S(15)='1') then
							last_V := '1';
						elsif (fifo_data_out_S(31)='1') and (fifo_data_out_S(15)='0') then
							last_V := '1';
						else 
							last_V := '1';
							error2_S <= '1';
						end if;
					end if;
				end if;
			end if;
		end if;
		fifo_read_V := fifo_read_S;
	end if;
end process;

testword0(7 downto 0) <= conv_std_logic_vector(readcount_S,8); -- fifo_data_in_S(11 downto 4);
testword0(8) <= fifo_data_in_S(15);
testword0(9) <= fifo_data_in_S(31);
testword0(10) <= fifo_write_S;
testword0(11) <= fifo_writing_S;
testword0(12) <= fifo_writing0_S;

testword0(13) <= fifo_reset_S;
testword0(14) <= fifo_reset0_S;

testword0(15) <= ready_S;
testword0(16) <= startpulse_S;
testword0(17) <= started_S;

testword0(18) <= fifo_empty_S;
testword0(19) <= fifo_read_S;
testword0(27 downto 20) <= fifo_data_out_S(11 downto 4);
testword0(28) <= fifo_data_out_S(15);
testword0(29) <= fifo_data_out_S(31);
testword0(30) <= error1_S;
testword0(31) <= error2_S;
testword0(32) <= fifo_resetting_S;
testword0(33) <= '1' when (started_S='1') and (fifo_writing0_S='0') and (wave_data_in(35 downto 32)="0000") and (fifo_write_S='1') else '0';

testword0(35 downto 34) <= (others => '0');



end Behavioral;
