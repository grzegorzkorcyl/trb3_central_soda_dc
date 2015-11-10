----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   15-09-2015
-- Module Name:   DC_sorting_wavemux
-- Description:   Multiplexer for waveform data, sorting on superburst-number and timestamp
-- Modifications:
--   23-09-2014   single clock, remove fullness fifo, 
--   16-10-2014   inpipe signals 
--   21-07-2015   data_out_inpipe clocked
--   15-09-2015   Version for Data Concentrator
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;
USE work.panda_package.all;

----------------------------------------------------------------------------------
-- DC_sorting_wavemux
-- Multiplexes multiple input pulse data stream with waveform data to one stream.
-- Both consists of packets of 36-bits words: 32 bits data and 4 bits for index/check
-- The data is sorted based on the lower 16 bits of the superburst number and the 16-bits timestamp within the superburst.
-- This sorting is done by comparing the time of 2 waveforms; the first in time is passed on.
-- Multiple of these comparators are placed in a tree structure. The last segment provides the sorted data.
--
-- Library:
--     work.panda_package: constants and types
--
-- Generics:
--     NROFMUXINPUTS : number of input-channels
--
-- Inputs:
--     inputclock : clock for input data (write side incomming fifo)
--     MUXclock : clock for multiplexer part, between the fifos
--     outputclock : clock for output data (read side outgoing fifo)
--     reset : reset, must be long enough for all clocks
--     data_in : array of input data streams, structure of each:
--        	bits(35..32)="0000" : bits(31 downto 16)=Superburstnumber(15..0), bits(15..0)=timestamp of waveform within superburst
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
--        	bits(35..32)="0000" : bits(31 downto 16)=Superburstnumber(15..0), bits(15..0)=timestamp of waveform within superburst
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
--     data_out_inpipe : more data on its way
--     infifo_fullness : array with number of words in input fifo's
--     outfifo_fullness : number of words in output fifo
--     error : data error, index in data words incorrect
-- 
-- Components:
--     DC_wavemux_readfifo : read data from fifo and writes to next level
--     DC_wavemux2to1 : compares the data and passes the first in time on
--     async_fifo_nn_progfull1900_progempty128_2048x36 : asynchronous fifo with programmable full and empty
--     async_fifo_nn_4096x36 : asynchronous fifo
--     DC_posedge_to_pulse : Makes a 1-clock pulse on rising edge from signal with different clock
--
--
--
----------------------------------------------------------------------------------

entity DC_sorting_wavemux is
	generic(
		NROFMUXINPUTS           : natural := 16
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
		data_out_inpipe         : out std_logic;
		infifo_fullness         : out array_fiber16bits_type;
		outfifo_fullness        : out std_logic_vector(15 downto 0);
		error                   : out std_logic;
		testword0               : out std_logic_vector(35 downto 0);
		testword1               : out std_logic_vector(35 downto 0)
);
end DC_sorting_wavemux;


architecture Behavioral of DC_sorting_wavemux is

component DC_wavemux2to1 is
	generic(
		TIMEOUTBITS             : natural := 6
	);
	Port (
		clock                   : in std_logic;
		reset                   : in std_logic;
		data1_in                : in std_logic_vector(35 downto 0); 
		data1_in_write          : in std_logic;
		data1_in_available      : in std_logic;
		data1_in_allowed        : out std_logic;
		data2_in                : in std_logic_vector(35 downto 0); 
		data2_in_write          : in std_logic;
		data2_in_available      : in std_logic;
		data2_in_allowed        : out std_logic;
		data_out                : out std_logic_vector(35 downto 0);
		data_out_write          : out std_logic;
		data_out_available      : out std_logic;
		data_out_allowed        : in std_logic;
		error                   : out std_logic;
		testword0               : out std_logic_vector(35 downto 0)
	);
end component;

component DC_wavemux_readfifo is
	port (
		clock                   : in std_logic;
		reset                   : in std_logic;
		data_in                 : in std_logic_vector(35 downto 0);
		data_in_available       : in std_logic;
		data_in_read            : out std_logic;
		data_out                : out std_logic_vector(35 downto 0);
		data_out_write          : out std_logic;
		data_out_inpipe         : out std_logic;
		data_out_allowed        : in std_logic);
end component;

component async_fifo_nn_progfull1900_progempty128_2048x36
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
		prog_full               : out std_logic;
		prog_empty              : out std_logic);
end component;

component async_fifo_nn_4096x36
	port (
		rst                    : in std_logic;
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

component DC_posedge_to_pulse is
	port (
		clock_in                : in  std_logic;
		clock_out               : in  std_logic;
		en_clk                  : in  std_logic;
		signal_in               : in  std_logic;
		pulse                   : out std_logic);
end component;

type twologarray_type is array(0 to 63) of natural;
constant twologarray : twologarray_type :=
(0,0,1,1,2,2,2,2,3,3,3,3,3,3,3,3,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5);

constant mux2to1_gen_max      : integer := twologarray(NROFMUXINPUTS); -- -1;
constant INPIPE_DELAY         : integer := 2047;
constant zeros                : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
constant ones                 : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '1');

--type mux2to1_gen_type is array(0 to mux2to1_gen_max-1) of integer;
--constant mux2to1_gen          : mux2to1_gen_type := (8,4,2,1);

type data_type is array(0 to mux2to1_gen_max,0 to NROFMUXINPUTS-1) of std_logic_vector(35 downto 0);
type singlebit_type is array(0 to mux2to1_gen_max,0 to NROFMUXINPUTS-1) of std_logic;

signal error_S                : std_logic := '0';

signal data_S                 : data_type;
signal data_out_inpipe_S      : singlebit_type := (others => (others => '0'));
signal data_write_S           : singlebit_type := (others => (others => '0'));
signal data_allowed_S         : singlebit_type := (others => (others => '0'));
signal error_array_S          : singlebit_type := (others => (others => '0'));

-- signals for fifo from adc-fe to adc-mux
signal dfifo_wr_S             : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal dfifo_wr_muxclk_S      : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal dfifo_rd_S             : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal dfifo_out_S            : array_fiber36bits_type := (others => (others => '0'));
signal dfifo_full_S           : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal dfifo_prog_full_S      : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal dfifo_prog_full_muxclk_S : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal dfifo_empty_S          : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal data_in_available_S    : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal dfifo_prog_empty_S     : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');

signal delay_inpipe_S         : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal read36_inpipe_S        : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');

-- signals for fifo from adc-mux to packet-composer
signal tfifo_in_S             : std_logic_vector (35 downto 0);
signal tfifo_rd_S             : std_logic := '0';
signal tfifo_full_S           : std_logic := '0';
signal tfifo_empty_S          : std_logic := '0';
signal sorterror_S            : std_logic := '0';
signal prevtime_S             : std_logic_vector(35 downto 0) := (others => '0');
signal prevSB_S               : std_logic_vector(35 downto 0) := (others => '0');



-- signal debug_dfifo_out0       : std_logic_vector(35 downto 0) := (others => '0');
-- signal debug_dfifo_out1       : std_logic_vector(35 downto 0) := (others => '0');
-- signal debug_dfifo_rd         : std_logic_vector(3 downto 0) := (others => '0');
-- signal debug_dfifo_empty      : std_logic_vector(3 downto 0) := (others => '0');
-- signal debug_dfifo_prog_empty : std_logic_vector(3 downto 0) := (others => '0');
-- signal debug_data_wr0         : std_logic_vector(3 downto 0) := (others => '0');
-- signal debug_data_wr1         : std_logic_vector(1 downto 0) := (others => '0');
-- signal debug_data_wr2         : std_logic;
-- signal debug_data00           : std_logic_vector(35 downto 0) := (others => '0');
-- signal debug_data01           : std_logic_vector(35 downto 0) := (others => '0');
--signal debug_data02           : std_logic_vector(35 downto 0) := (others => '0');
--signal debug_data03           : std_logic_vector(35 downto 0) := (others => '0');
-- signal debug_data10           : std_logic_vector(35 downto 0) := (others => '0');
-- signal debug_data11           : std_logic_vector(35 downto 0) := (others => '0');
-- signal debug_data20           : std_logic_vector(35 downto 0) := (others => '0');
-- signal debug_tfifo_rw         : std_logic;
-- signal debug_sorterror        : std_logic := '0';


	
type testword_type is array(0 to mux2to1_gen_max,0 to NROFMUXINPUTS-1) of std_logic_vector (35 downto 0);
signal testword0_S            : testword_type;
  attribute syn_keep     : boolean;
  attribute syn_preserve : boolean;
  -- attribute syn_keep of debug_dfifo_out0 : signal is true;
  -- attribute syn_preserve of debug_dfifo_out0 : signal is true;
  -- attribute syn_keep of debug_dfifo_out1 : signal is true;
  -- attribute syn_preserve of debug_dfifo_out1 : signal is true;
  -- attribute syn_keep of debug_dfifo_rd : signal is true;
  -- attribute syn_preserve of debug_dfifo_rd : signal is true;
  -- attribute syn_keep of debug_dfifo_empty : signal is true;
  -- attribute syn_preserve of debug_dfifo_empty : signal is true;
  -- attribute syn_keep of debug_dfifo_prog_empty : signal is true;
  -- attribute syn_preserve of debug_dfifo_prog_empty : signal is true;
  -- attribute syn_preserve of sorterror_S : signal is true;
  -- attribute syn_keep of debug_data_wr0 : signal is true;
  -- attribute syn_preserve of debug_data_wr0 : signal is true;
  -- attribute syn_keep of debug_data_wr1 : signal is true;
  -- attribute syn_preserve of debug_data_wr1 : signal is true;
  -- attribute syn_keep of debug_data_wr2 : signal is true;
  -- attribute syn_preserve of debug_data_wr2 : signal is true;
  -- attribute syn_keep of debug_data00 : signal is true;
  -- attribute syn_preserve of debug_data00 : signal is true;
  -- attribute syn_keep of debug_data01 : signal is true;
  -- attribute syn_preserve of debug_data01 : signal is true;
  -- attribute syn_keep of debug_data10 : signal is true;
  -- attribute syn_preserve of debug_data10 : signal is true;
  -- attribute syn_keep of debug_data11 : signal is true;
  -- attribute syn_preserve of debug_data11 : signal is true;
  -- attribute syn_keep of debug_data20 : signal is true;
  -- attribute syn_preserve of debug_data20 : signal is true;
  -- attribute syn_keep of debug_tfifo_rw : signal is true;
  -- attribute syn_preserve of debug_tfifo_rw : signal is true;
  -- attribute syn_keep of debug_sorterror : signal is true;
  -- attribute syn_preserve of debug_sorterror : signal is true;



-- attribute mark_debug : string;
-- attribute mark_debug of dfifo_wr_muxclk_S : signal is "true";
-- attribute mark_debug of dfifo_rd_S : signal is "true";
-- attribute mark_debug of dfifo_out_S : signal is "true";
-- attribute mark_debug of dfifo_prog_full_muxclk_S : signal is "true";
-- attribute mark_debug of dfifo_empty_S : signal is "true";
-- attribute mark_debug of dfifo_prog_empty_S : signal is "true";
-- attribute mark_debug of delay_inpipe_S : signal is "true";
-- attribute mark_debug of read36_inpipe_S : signal is "true";
-- attribute mark_debug of sorterror_S : signal is "true";
-- attribute mark_debug of prevtime_S : signal is "true";



begin

--data_out_inpipe <= '1' 
--	when (dfifo_empty_S/=ones(0 to NROFMUXINPUTS-1)) or (tfifo_empty_S='0') or (data_out_inpipe_S(mux2to1_gen_max,0)='1')
--	else '0';
process(MUXclock)
begin
	if (rising_edge(MUXclock)) then 
		if (dfifo_empty_S/=ones(0 to NROFMUXINPUTS-1)) 
				or (tfifo_empty_S='0') 
				or (data_out_inpipe_S(mux2to1_gen_max,0)='1') 
		then
			data_out_inpipe <= '1';
		else
			data_out_inpipe <= '0';
		end if;
	end if;
end process;

DC_mux_inputs: for index in 0 to NROFMUXINPUTS-1 generate 

process(MUXclock)
type inpipe_counter_type is array(0 to NROFMUXINPUTS-1) of integer range 0 to INPIPE_DELAY;
variable inpipe_counter_V : inpipe_counter_type := (others => 0);
variable index_other : integer range 0 to NROFMUXINPUTS-1;
begin
	if rising_edge(MUXclock) then
		if reset='1' then
			inpipe_counter_V(index) := 0;
			delay_inpipe_S(index) <= '0';
		else
			index_other := conv_integer(unsigned((conv_std_logic_vector(index,8) xor x"01")));
			if (dfifo_prog_full_muxclk_S(index_other)='1') and (dfifo_prog_empty_S(index)='1') and (dfifo_empty_S(index)='1') and (dfifo_wr_muxclk_S(index)='0') then
				inpipe_counter_V(index) := 0;
				delay_inpipe_S(index) <= '0';			
			elsif ((dfifo_wr_muxclk_S(index)='1') and (dfifo_prog_empty_S(index)='1')) or
				((dfifo_wr_muxclk_S(index_other)='1') and (dfifo_prog_empty_S(index_other)='1'))
				then
				inpipe_counter_V(index) := INPIPE_DELAY;
				delay_inpipe_S(index) <= '1';
			else			
				if inpipe_counter_V(index)/=0 then
					inpipe_counter_V(index) := inpipe_counter_V(index)-1;
					delay_inpipe_S(index) <= '1';
				else
					delay_inpipe_S(index) <= '0';
				end if;
			end if;
		end if;
		dfifo_prog_full_muxclk_S(index) <= dfifo_prog_full_S(index);
	end if;
end process;

sync_wr_dfifo: DC_posedge_to_pulse port map(
		clock_in => inputclock,
		clock_out => MUXclock,
		en_clk => '1',
		signal_in => dfifo_wr_S(index),
		pulse => dfifo_wr_muxclk_S(index));

		
dfifo: async_fifo_nn_progfull1900_progempty128_2048x36 port map(
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
		prog_full => dfifo_prog_full_S(index),
		prog_empty => dfifo_prog_empty_S(index));
infifo_fullness(index)(15 downto 11) <= (others => '0');
dfifo_wr_S(index) <= '1' when (dfifo_full_S(index)='0') and (data_in_write(index)='1') else '0';
data_in_wave_allowed(index) <= '1' when dfifo_prog_full_S(index)='0' else '0';

data_in_available_S(index) <= '1' when dfifo_empty_S(index)='0' else '0';

DC_wavemux_readfifo1: DC_wavemux_readfifo port map(
		clock => MUXclock,
		reset => '0',
		data_in => dfifo_out_S(index),
		data_in_available => data_in_available_S(index),
		data_in_read => dfifo_rd_S(index),
		data_out => data_S(0,index),
		data_out_write => data_write_S(0,index),
		data_out_inpipe => read36_inpipe_S(index),
		data_out_allowed => data_allowed_S(0,index));
	
process(data_out_inpipe_S(0,index),read36_inpipe_S(index),delay_inpipe_S(index),dfifo_wr_muxclk_S(index)) -- ,dfifo_prog_empty_S)
--variable index_other : integer range 0 to NROFMUXINPUTS-1;
begin
--	index_other := conv_integer(unsigned((conv_std_logic_vector(index,16) xor x"0001")));
--	if (read36_inpipe_S(index)='1') or ((dfifo_prog_empty_S(index_other)='1') and (delay_inpipe_S(index)='1')) or
--		(dfifo_wr_occuredrecently_S(index)='1') or -- was there a write recently (time: one datapacket plus a few slowcontrols ?
 	if (read36_inpipe_S(index)='1') or (delay_inpipe_S(index)='1') or
		(dfifo_wr_muxclk_S(index)='1') then
		data_out_inpipe_S(0,index) <= '1';
	else
		data_out_inpipe_S(0,index) <= '0';
	end if;
end process;
			
end generate;


DC_multiplex2to1_all: for i1 in 0 to mux2to1_gen_max-1 generate 

	DC_multiplex2to1_i: for i2 in 0 to (2**(mux2to1_gen_max-i1-1))-1 generate 
	
		DC_wavemux2to1_1: DC_wavemux2to1 port map(
			clock => MUXclock,
			reset => '0',
			data1_in => data_S(i1,i2*2),
			data1_in_write => data_write_S(i1,i2*2),
			data1_in_available => data_out_inpipe_S(i1,i2*2),
			data1_in_allowed => data_allowed_S(i1,i2*2),
			data2_in => data_S(i1,i2*2+1),
			data2_in_write => data_write_S(i1,i2*2+1),
			data2_in_available => data_out_inpipe_S(i1,i2*2+1),
			data2_in_allowed => data_allowed_S(i1,i2*2+1),
			data_out => data_S(i1+1,i2),
			data_out_write => data_write_S(i1+1,i2),
			data_out_available => data_out_inpipe_S(i1+1,i2),
			data_out_allowed => data_allowed_S(i1+1,i2),
			error => error_array_S(i1,i2),
			testword0 => testword0_S(i1,i2));
			
	end generate;
end generate;

process(MUXclock)
begin
	if (rising_edge(MUXclock)) then 
		error_S <= '0';
		for i1 in 0 to mux2to1_gen_max-1 loop 
			for i2 in 0 to (2**(mux2to1_gen_max-i1-1))-1 loop 
				if error_array_S(i1,i2)='1' then
					error_S <= '1';
				end if;
			end loop;
		end loop;
	end if;
end process;
error <= error_S;

data_allowed_S(mux2to1_gen_max,0) <= '1' when (tfifo_full_S='0') else '0';
tfifo_in_S <= data_S(mux2to1_gen_max,0);
tfifo: async_fifo_nn_4096x36 port map(
		rst => reset,
		wr_clk => MUXclock,
		rd_clk => outputclock,
		din => tfifo_in_S,
		wr_en => data_write_S(mux2to1_gen_max,0),
		rd_en => tfifo_rd_S,
		dout => data_out,
		full => tfifo_full_S,
		empty => tfifo_empty_S,
		rd_data_count => outfifo_fullness(11 downto 0));
outfifo_fullness(15 downto 12) <= (others => '0');
tfifo_rd_S <= '1' when (data_out_read='1') and (tfifo_empty_S='0') else '0';
data_out_available <= '1' when tfifo_empty_S='0' else '0';

process(MUXclock)
begin
	if (rising_edge(MUXclock)) then 
		sorterror_S <= '0';
		if (data_write_S(mux2to1_gen_max,0)='1') then
			if (tfifo_in_S(35 downto 32)="0000") then
				if (tfifo_in_S(31 downto 16)=prevtime_S(31 downto 16)) and (tfifo_in_S(15 downto 0)<prevtime_S(15 downto 0)) then
					sorterror_S <= '1';
				end if;
				prevtime_S <= tfifo_in_S;
			elsif (tfifo_in_S(35 downto 32)="0001") then
				if (tfifo_in_S(31 downto 0)<prevSB_S(31 downto 0)) then
					sorterror_S <= '1';
				end if;
				prevSB_S <= tfifo_in_S;
			end if;
		end if;
	end if;
end process;

testword0 <= (others => '0');
testword1 <= (others => '0');

-- process(MUXclock)
-- begin
	-- if (rising_edge(MUXclock)) then 
-- debug_dfifo_out0 <= dfifo_out_S(0);
-- debug_dfifo_out1 <= dfifo_out_S(1);
-- debug_dfifo_rd <= dfifo_rd_S;
-- debug_dfifo_empty <= dfifo_empty_S;
-- debug_dfifo_prog_empty <= dfifo_prog_empty_S;

-- debug_data_wr0(0) <= data_write_S(0,0);
-- debug_data_wr0(1) <= data_write_S(0,1);
-- debug_data_wr0(2) <= data_write_S(0,2);
-- debug_data_wr0(3) <= data_write_S(0,3);
-- debug_data_wr1(0) <= data_write_S(1,0);
-- debug_data_wr1(1) <= data_write_S(1,1);
-- debug_data_wr2 <= data_write_S(2,0);
-- debug_data00 <= data_S(0,0);
-- debug_data01 <= data_S(0,1);
-- debug_data10 <= data_S(1,0);
-- debug_data11 <= data_S(1,1);
-- debug_data20 <= data_S(2,0);
-- debug_tfifo_rw <= data_write_S(mux2to1_gen_max,0);
-- debug_sorterror <= sorterror_S;
	-- end if;
-- end process;
		
	
end Behavioral;
