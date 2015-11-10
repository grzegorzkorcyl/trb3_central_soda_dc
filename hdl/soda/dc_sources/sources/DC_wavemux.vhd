----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   12-03-2012
-- Module Name:   DC_wavemux
-- Description:   Multiplexer for pileup waveform data, non sorting
-- Modifications:
--   26-11-2014   name changed from MUX_wavemux to DC_wavemux
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;
USE work.panda_package.all;

----------------------------------------------------------------------------------
-- DC_wavemux
-- Multiplexes multiple input data with waveforms to one stream.
-- The data width is 36-bits, 32 bits valid data and the highest bits for 
-- word identification : first and last word in waveform packets.
-- The data is not sorted; each time the next data input is chosen
-- if data is available.
-- There are fifo's for each input and one for the output.
-- 
--
--
--
-- Library:
--     work.panda_package:
--        function calc_next_channel : calculate the next channel that has data available
--
-- Generics:
--     NROFMUXINPUTS : number of input-channels
--
-- Inputs:
--     inputclock : clock for input data (write side incomming fifo)
--     MUXclock : clock for multiplexer part, between the fifos
--     outputclock : clock for output data (read side outgoing fifo)
--     reset : reset, must be long enough for all clocks
--     data_in : input data :
--        	bits(35..32)="0000" : bits(31..0)=timestamp of maximum value in waveform
--        	bits(35..32)="0001" : bits(31)=0 bits(30..0)=SuperBurst number
--        	bits(35..32)="0010" : 
--              bits(31..24) = statusbyte (bit6=overflow) 
--              bits(23..16) = 00
--              bits(15..0) = adcnumber (channel identification)
--        	bits(35..32)="0011" : bits(31..16)=adc sample, bits(15..0)=next adc sample
--        	bits(35..32)="0100" : bits(31..16)=last adc sample, bits(15..0)=0
--        	bits(35..32)="0101" : bits(31..16)=last but one adc sample, bits(15..0)=last adc sample
--        	bits(35..32)="1111" : error: buffer full, waveform not valid
--     data_in_write : write signal for data_in (write into fifo)
--     data_out_read : read signal for outgoing data (read from fifo)
-- 
-- Outputs:
--     data_in_wave_allowed : writing of a full waveform (max 254 samples) to input allowed
--     data_out : output data
--        	bits(35..32)="0000" : bits(31..0)=timestamp of maximum value in waveform
--        	bits(35..32)="0001" : bits(31)=0 bits(30..0)=SuperBurst number
--        	bits(35..32)="0010" : 
--              bits(31..24) = statusbyte (bit6=overflow) 
--              bits(23..16) = 00
--              bits(15..0) = adcnumber (channel identification)
--        	bits(35..32)="0011" : bits(31..16)=adc sample, bits(15..0)=next adc sample
--        	bits(35..32)="0100" : bits(31..16)=last adc sample, bits(15..0)=0
--        	bits(35..32)="0101" : bits(31..16)=last but one adc sample, bits(15..0)=last adc sample
--        	bits(35..32)="1111" : error: buffer full, waveform not valid
--     data_out_available : data_out available (output fifo not empty)
--     infifo_fullness : array with number of words in input fifo's
--     outfifo_fullness : number of words in output fifo
--     error : data error
-- 
-- Components:
--     async_fifo_nn_FWFT_512x36 : asynchronous fifo with number of words and First Word Fall Through
--     async_fifo_nn_4096x36 : asynchronous fifo with number of words available in fifo
--
--
----------------------------------------------------------------------------------

entity DC_wavemux is
	generic(
		NROFMUXINPUTS           : natural := 4
	);
    Port ( 
		inputclock              : in std_logic;
		MUXclock                : in std_logic; 
		outputclock             : in std_logic; 
		reset                   : in std_logic;
		data_in                 : in array_fiber36bits_type;
		data_in_write           : in std_logic_vector(0 to NROFMUXINPUTS-1);
		data_in_wave_allowed    : out std_logic_vector(0 to NROFMUXINPUTS-1);
		data_out                : out std_logic_vector(35 downto 0);
		data_out_read           : in std_logic;
		data_out_available      : out std_logic;
		infifo_fullness         : out array_fiber16bits_type;
		outfifo_fullness        : out std_logic_vector(15 downto 0);
		testword0               : out std_logic_vector(35 downto 0) := (others => '0');
		testword1               : out std_logic_vector(35 downto 0) := (others => '0');
		error                   : out std_logic);
end DC_wavemux;


architecture Behavioral of DC_wavemux is

component async_fifo_nn_thfull_FWFT_512x36
	port (
		rst                     : in std_logic;
		wr_clk                  : in std_logic;
		rd_clk                  : in std_logic;
		din                     : in std_logic_vector(35 downto 0);
		wr_en                   : in std_logic;
		rd_en                   : in std_logic;
		dout                    : out std_logic_vector(35 downto 0);
		full                    : out std_logic;
		empty                   : out std_logic;
		rd_data_count           : out std_logic_vector(8 downto 0);
		prog_full               : out std_logic); -- at 378 words
end component;

component async_fifo_nn_thfull_FWFT_2048x36
	port (
		rst                     : in std_logic;
		wr_clk                  : in std_logic;
		rd_clk                  : in std_logic;
		din                     : in std_logic_vector(35 downto 0);
		wr_en                   : in std_logic;
		rd_en                   : in std_logic;
		dout                    : out std_logic_vector(35 downto 0);
		full                    : out std_logic;
		empty                   : out std_logic;
		rd_data_count           : out std_logic_vector(10 downto 0);
		prog_full               : out std_logic); -- at 1914 words
end component;

--component async_fifo_nn_512x36
component async_fifo_nn_4096x36
	port (
		rst                     : in std_logic;
		wr_clk                  : in std_logic;
		rd_clk                  : in std_logic;
		din                     : in std_logic_vector(35 downto 0);
		wr_en                   : in std_logic;
		rd_en                   : in std_logic;
		dout                    : out std_logic_vector(35 downto 0);
		full                    : out std_logic;
		empty                   : out std_logic;
		rd_data_count           : out std_logic_vector(11 downto 0));
end component;


component async_fifo_nn_512x36to18
	port (
		rst                     : in std_logic;
		wr_clk                  : in std_logic;
		rd_clk                  : in std_logic;
		din                     : in std_logic_vector(35 downto 0);
		wr_en                   : in std_logic;
		rd_en                   : in std_logic;
		dout                    : out std_logic_vector(17 downto 0);
		full                    : out std_logic;
		empty                   : out std_logic;
		wr_data_count           : out std_logic_vector(8 downto 0));
end component;

signal reset_MUXclock_S       : std_logic;

signal adcreading_S           : integer range 0 to NROFMUXINPUTS-1 := 0;

signal error_S                : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');


-- signals for fifo from adc-fe to adc-mux
signal dfifo_wr_S             : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal dfifo_rd_S             : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal dfifo_out_S            : array_fiber36bits_type;
signal dfifo_full_S           : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal dfifo_prog_full_S      : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal dfifo_empty_S          : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');

-- signals for fifo from adc-mux to packet-composer
signal tfifo_in_S             : std_logic_vector (35 downto 0);
signal tfifo_wr_S             : std_logic := '0';
signal tfifo_rd_S             : std_logic := '0';
signal tfifo_full_S           : std_logic := '0';
signal tfifo_empty_S          : std_logic := '0';

signal waitfordata_S          : std_logic := '1';
signal timeoutcounter_S       : std_logic_vector(15 downto 0) := (others => '0');

constant zeros                : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
begin

error <= '1' when (error_S(0 to NROFMUXINPUTS-1)/=zeros(0 to NROFMUXINPUTS-1)) else '0';

inputfifos: for index in 0 to NROFMUXINPUTS-1 generate

dfifo: async_fifo_nn_thfull_FWFT_2048x36 port map(
		rst => reset,
		wr_clk => inputclock,
		rd_clk => MUXclock,
		din => data_in(index),
		wr_en => dfifo_wr_S(index),
		rd_en => dfifo_rd_S(index),
		dout => dfifo_out_S(index),
		full => dfifo_full_S(index),
		empty => dfifo_empty_S(index),
		rd_data_count => infifo_fullness(index)(10 downto 0),
		prog_full => dfifo_prog_full_S(index));
data_in_wave_allowed(index) <= '1' when dfifo_prog_full_S(index)='0' else '0';
infifo_fullness(index)(15 downto 11) <= (others => '0');
dfifo_wr_S(index) <= '1' when (dfifo_full_S(index)='0') and (data_in_write(index)='1') else '0';
error_S(index) <= '1' when (dfifo_full_S(index)='1') and (data_in_write(index)='1') else '0';

dfifo_rd_S(index) <= '1' when 
		(tfifo_full_S='0')  
		and (index=adcreading_S)
		and (dfifo_empty_S(index)='0')
		else '0';
			
end generate;


process(MUXclock)
constant ones : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '1');
begin
	if (rising_edge(MUXclock)) then 
		if (reset_MUXclock_S = '1') then 
			adcreading_S <= 0;
			waitfordata_S <= '0';
		else
			if ((dfifo_out_S(adcreading_S)(35 downto 33)="010") 
						or (dfifo_out_S(adcreading_S)(35 downto 32)="1111")) -- error
				and dfifo_rd_S(adcreading_S)='1' then ----
				waitfordata_S <= '1';
				timeoutcounter_S <= (others => '0');
				adcreading_S <= calc_next_channel(adcreading_S,dfifo_empty_S);
			else
				if waitfordata_S='1' then
					if (dfifo_empty_S /= ones) then -- data available
						if dfifo_rd_S(adcreading_S)='0' then
							adcreading_S <= calc_next_channel(adcreading_S,dfifo_empty_S);
						end if;
						waitfordata_S <= '0';
						timeoutcounter_S <= (others => '0');
					end if;
				else
					if timeoutcounter_S(timeoutcounter_S'length-1)='1' then
						if (dfifo_empty_S /= ones) then -- data available
							if dfifo_rd_S(adcreading_S)='0' then
								adcreading_S <= calc_next_channel(adcreading_S,dfifo_empty_S);
							end if;
							timeoutcounter_S <= (others => '0');
						end if;
					else
						timeoutcounter_S <= timeoutcounter_S+1;
					end if;
				end if;
			end if;
		end if;
		reset_MUXclock_S <= reset;
	end if;
end process;


tfifo_wr_S <= '1' when (tfifo_full_S='0') and (dfifo_empty_S(adcreading_S)='0') else '0';
tfifo_in_S <= dfifo_out_S(adcreading_S);
tfifo: async_fifo_nn_4096x36 port map(
		rst => reset,
		wr_clk => MUXclock,
		rd_clk => outputclock,
		din => tfifo_in_S,
		wr_en => tfifo_wr_S,
		rd_en => tfifo_rd_S,
		dout => data_out,
		full => tfifo_full_S,
		empty => tfifo_empty_S,
		rd_data_count => outfifo_fullness(11 downto 0));
outfifo_fullness(15 downto 12) <= (others => '0');

tfifo_rd_S <= '1' when (data_out_read='1') and (tfifo_empty_S='0') else '0';
data_out_available <= '1' when tfifo_empty_S='0' else '0';
		
testword0(35 downto 0) <= (others => '0');

		
end Behavioral;

