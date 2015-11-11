----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   25-02-2014
-- Module Name:   DC_sorting_mux
-- Description:   Multiplexer for pulse (=hit) data, sorting on timestamp
-- Modifications:
--   30-07-2014   Timestamp is now the time within the superburst
--   26-02-2015   Larger input fifos
--   21-05-2015   Additional clock synchronization
--   02-10-2015   Input changed from 36 bits packets to hit-data members
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;
USE work.panda_package.all;

----------------------------------------------------------------------------------
-- DC_sorting_mux
-- Multiplexes multiple input pulse data stream to one stream.
-- The input contains hit data: channelnumber, superburstnumber, time and fractional part within superburst, energy and status.
-- The data is sorted based on the superburst number, the 16-bits timestamp within the superburst and the fractional part.
-- This sorting is done by comparing the time of 2 items; the first in time is passed on.
-- Multiple of these comparators are placed in a tree structure. The last segment provides the sorted data.
--
-- Library:
--     work.panda_package: constants and types
--
-- Generics:
--     NROFMUXINPUTS : number of input-channels
--     MUXINFIFOSIZE : size of the input fifos (in address-bits)
--     TRANSFERFIFOSIZE : size of the output fifo (in address-bits)
--     CF_FRACTIONBIT : number of valid constant fraction bits
--
-- Inputs:
--     inputclock : clock for input data (write side incomming fifo)
--     MUXclock : clock for multiplexer part, between the fifos
--     outputclock : clock for output data (read side outgoing fifo)
--     reset : reset, must be long enough for all clocks
--     channel_in : adc-channel number, for each connected FEE
--     statusbyte_in : 8 bits hit-status, for each connected FEE
--     energy_in : energy of the hit, for each connected FEE
--     timefraction_in : fractional part of the timestamp, for each connected FEE
--     timestamp_in : time within superburst, for each connected FEE
--     superburstnumber_in : superburstnumber, for each connected FEE
--     data_in_write : write signal for data_in (write into fifo)
--     data_out_read : read signal for outgoing data (read from fifo)
-- 
-- Outputs:
--     data_in_allowed : write to input data allowed (not full)
--     data_in_almostfull : inputfifo is almost full
--     fiber_index : index of the fiber
--     channel_out : pulse-data : adc channel number
--     statusbyte_out : pulse-data : status
--     energy_out : pulse-data : energy
--     timefraction_out : pulse-data : Constant Fraction time
--     timestamp_out : pulse-data : time (ADC-clock)
--     superburstnumber_out : pulse-data : superburstnumber
--     data_out_available : data_out available (output fifo not empty)
--     infifo_fullness : array with number of words in input fifo's
--     outfifo_fullness : number of words in output fifo
--     error : data error, index in data words incorrect
-- 
-- Components:
--     DC_mux2to1 : compares the data and passes the first in time on
--     async_fifo_nn_progfull512_progempty128_FWFT_1024x99 : asynchronous fifo with number of words in fifo
--     async_fifo_nn_4096x103 : large asynchronous fifo with number of words in fifo
--     sync_bit : Synchronization for 1 bit cross clock signal
--     DC_posedge_to_pulse : Makes a 1-clock pulse on rising edge from signal with different clock
--
--
----------------------------------------------------------------------------------

entity DC_sorting_mux is
	generic(
		NROFMUXINPUTS           : natural := 4;
		--GK: width problem
		--MUXINFIFOSIZE           : natural := 9;
		MUXINFIFOSIZE           : natural := 10;
		TRANSFERFIFOSIZE        : natural := 12;
		CF_FRACTIONBIT          : natural := 11
	);
    port ( 
		inputclock              : in std_logic;
		MUXclock                : in std_logic; 
		outputclock             : in std_logic; 
		reset                   : in std_logic;
		channel_in              : in array_fiber16bits_type;
		statusbyte_in           : in array_fiber8bits_type;
		energy_in               : in array_fiber16bits_type;
		timefraction_in         : in array_fiber12bits_type;
		timestamp_in            : in array_fiber16bits_type;
		superburstnumber_in     : in array_fiber31bits_type;		
		data_in_write           : in std_logic_vector(0 to NROFMUXINPUTS-1);
		data_in_allowed         : out std_logic_vector(0 to NROFMUXINPUTS-1);
		data_in_almostfull      : out std_logic_vector(0 to NROFMUXINPUTS-1);
		fiber_index_out         : out std_logic_vector(3 downto 0);
		channel_out             : out std_logic_vector(15 downto 0);
		statusbyte_out          : out std_logic_vector(7 downto 0);
		energy_out              : out std_logic_vector(15 downto 0);
		timefraction_out        : out std_logic_vector(11 downto 0);
		timestamp_out           : out std_logic_vector(15 downto 0);
		superburstnumber_out    : out std_logic_vector(30 downto 0);		
		data_out_read           : in std_logic;
		data_out_available      : out std_logic;
		infifo_fullness         : out array_fiber16bits_type;
		outfifo_fullness        : out std_logic_vector(15 downto 0);
		error                   : out std_logic;
		testword0               : out std_logic_vector(35 downto 0) := (others => '0');
		testword1               : out std_logic_vector(35 downto 0) := (others => '0'));
end DC_sorting_mux;


architecture Behavioral of DC_sorting_mux is

component DC_mux2to1 is
	generic (
		CF_FRACTIONBIT          : natural := CF_FRACTIONBIT
	);
	port (
		clock                   : in std_logic;
		reset                   : in std_logic;
		fiber_index1            : in std_logic_vector(3 downto 0);
		channel1                : in std_logic_vector(15 downto 0);
		statusbyte1             : in std_logic_vector(7 downto 0);
		energy1                 : in std_logic_vector(15 downto 0);
		timefraction1           : in std_logic_vector(11 downto 0);
		timestamp1              : in std_logic_vector(15 downto 0);
		superburstnumber1       : in std_logic_vector(30 downto 0);
		data1_in_write          : in std_logic;
		data1_in_inpipe         : in std_logic;
		data1_in_allowed        : out std_logic;
		fiber_index2            : in std_logic_vector(3 downto 0);
		channel2                : in std_logic_vector(15 downto 0);
		statusbyte2             : in std_logic_vector(7 downto 0);
		energy2                 : in std_logic_vector(15 downto 0);
		timefraction2           : in std_logic_vector(11 downto 0);
		timestamp2              : in std_logic_vector(15 downto 0);
		superburstnumber2       : in std_logic_vector(30 downto 0);
		data2_in_write          : in std_logic;
		data2_in_inpipe         : in std_logic;
		data2_in_allowed        : out std_logic;
		fiber_index             : out std_logic_vector(3 downto 0);
		channel                 : out std_logic_vector(15 downto 0);
		statusbyte              : out std_logic_vector(7 downto 0);
		energy                  : out std_logic_vector(15 downto 0);
		timefraction            : out std_logic_vector(11 downto 0);
		timestamp               : out std_logic_vector(15 downto 0);
		superburstnumber        : out std_logic_vector(30 downto 0);
		data_out_write          : out std_logic;
		data_out_inpipe         : out std_logic;
		data_out_allowed        : in std_logic;
		error                   : out std_logic;
		testword0               : out std_logic_vector(35 downto 0) := (others => '0')
		);
end component;

component async_fifo_nn_progfull512_progempty128_FWFT_1024x99 is
port (
		rst                     : in std_logic;
		wr_clk                  : in std_logic;
		rd_clk                  : in std_logic;
		din                     : in std_logic_vector(98 downto 0);
		wr_en                   : in std_logic;
		rd_en                   : in std_logic;
		dout                    : out std_logic_vector(98 downto 0);
		full                    : out std_logic;
		empty                   : out std_logic;
		rd_data_count           : out std_logic_vector(9 downto 0);
		prog_full               : out std_logic;
		prog_empty              : out std_logic
	);
end component;

component async_fifo_nn_4096x103
	port (
		rst                     : in std_logic;
		wr_clk                  : in std_logic;
		rd_clk                  : in std_logic;
		din                     : in std_logic_vector(102 downto 0);
		wr_en                   : in std_logic;
		rd_en                   : in std_logic;
		dout                    : out std_logic_vector(102 downto 0);
		full                    : out std_logic;
		empty                   : out std_logic;
		rd_data_count           : out std_logic_vector(11 downto 0));
end component;

component sync_bit is
	port (
		clock       : in  std_logic;
		data_in     : in  std_logic;
		data_out    : out std_logic
	);
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

constant mux2to1_gen_max      : integer := twologarray(NROFMUXINPUTS); 
constant INPIPE_DELAY         : integer := 255;
constant zeros                : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
constant ones                 : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '1');


type array_fiber99bits_type is array(0 to NROFFIBERS-1) of std_logic_vector(98 downto 0);
type fiber_index_type is array(0 to mux2to1_gen_max,0 to NROFMUXINPUTS-1) of std_logic_vector(3 downto 0);
type channel_type is array(0 to mux2to1_gen_max,0 to NROFMUXINPUTS-1) of std_logic_vector(15 downto 0);
type statusbyte_type is array(0 to mux2to1_gen_max,0 to NROFMUXINPUTS-1) of std_logic_vector(7 downto 0);
type energy_type is array(0 to mux2to1_gen_max,0 to NROFMUXINPUTS-1) of std_logic_vector(15 downto 0);
type timefraction_type is array(0 to mux2to1_gen_max,0 to NROFMUXINPUTS-1) of std_logic_vector(11 downto 0);
type timestamp_type is array(0 to mux2to1_gen_max,0 to NROFMUXINPUTS-1) of std_logic_vector(15 downto 0);
type superburstnumber_type is array(0 to mux2to1_gen_max,0 to NROFMUXINPUTS-1) of std_logic_vector(30 downto 0);
type singlebit_type is array(0 to mux2to1_gen_max,0 to NROFMUXINPUTS-1) of std_logic;

signal error_S                : std_logic := '0';
signal fiber_index_S          : fiber_index_type;
signal channel_S              : channel_type;
signal statusbyte_S           : statusbyte_type;
signal energy_S               : energy_type;
signal timefraction_S         : timefraction_type;
signal timestamp_S            : timestamp_type;
signal superburstnumber_S     : superburstnumber_type;

signal data_out_inpipe_S      : singlebit_type := (others => (others => '0'));
signal data_write_S           : singlebit_type := (others => (others => '0'));
signal data_allowed_S         : singlebit_type := (others => (others => '0'));
signal error_array_S          : singlebit_type := (others => (others => '0'));

signal reset_MUXclock_S       : std_logic := '0';

-- signals for fifo from adc-fe to adc-mux
signal dfifo_wr_S             : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal dfifo_rd_S             : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal dfifo_din_S            : array_fiber99bits_type;
signal dfifo_dout_S           : array_fiber99bits_type;
signal dfifo_full_S           : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal dfifo_empty_S          : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal data_in_available_S    : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal infifo_fullness_S      : array_fiber16bits_type;
signal dfifo_prog_full_S      : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal dfifo_prog_empty_S     : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');

signal delay_inpipe_S         : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal read36_inpipe_S        : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');
signal dfifo_wr_MUXclock_S    : std_logic_vector(0 to NROFMUXINPUTS-1) := (others => '0');


-- signals for fifo from adc-mux to packet-composer
signal tfifo_in_S             : std_logic_vector (102 downto 0);
signal tfifo_rd_S             : std_logic := '0';
signal tfifo_full_S           : std_logic := '0';
signal tfifo_empty_S          : std_logic := '0';

--type testword_type is array(0 to mux2to1_gen_max,0 to NROFMUXINPUTS-1) of std_logic_vector (35 downto 0);
--signal testword0_S            : testword_type;
signal time_error_S           : std_logic := '0';
signal idx_error_S            : std_logic := '0';

signal sorterror_S            : std_logic := '0';
signal lastsuperburst_S       : std_logic_vector (30 downto 0);
signal lasttimestamp_S        : std_logic_vector (15 downto 0);
	
attribute mark_debug : string;
attribute mark_debug of dfifo_empty_S : signal is "true";
attribute mark_debug of dfifo_prog_empty_S : signal is "true";
attribute mark_debug of dfifo_rd_S : signal is "true";
attribute mark_debug of dfifo_dout_S : signal is "true";
attribute mark_debug of data_write_S : signal is "true";
attribute mark_debug of tfifo_in_S : signal is "true";
attribute mark_debug of delay_inpipe_S : signal is "true";
attribute mark_debug of sorterror_S : signal is "true";


begin

error <= '1' when (error_S='1') else '0';


MUX_mux_inputs: for index in 0 to NROFMUXINPUTS-1 generate 

process(MUXclock)
type inpipe_counter_type is array(0 to NROFMUXINPUTS-1) of integer range 0 to INPIPE_DELAY;
variable inpipe_counter_V : inpipe_counter_type := (others => 0);
variable index_other : integer range 0 to NROFMUXINPUTS-1;
begin
	if rising_edge(MUXclock) then
		if reset_MUXclock_S='1' then
			inpipe_counter_V(index) := 0;
			delay_inpipe_S(index) <= '0';
--//			dfifo_wr_MUXclock_S(index) <= '0';
		else
			index_other := conv_integer(unsigned((conv_std_logic_vector(index,8) xor x"01")));
			if ((dfifo_wr_MUXclock_S(index)='1') and (dfifo_prog_empty_S(index)='1')) or
				((dfifo_wr_MUXclock_S(index_other)='1') and (dfifo_prog_empty_S(index_other)='1'))
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
--//			dfifo_wr_MUXclock_S(index) <= dfifo_wr_S(index);
		end if;
	end if;
end process;

sync_wr_dfifo: DC_posedge_to_pulse port map(
		clock_in => inputclock,
		clock_out => MUXclock,
		en_clk => '1',
		signal_in => dfifo_wr_S(index),
		pulse => dfifo_wr_MUXclock_S(index));
	

dfifo_din_S(index) <=
			superburstnumber_in(index) &              -- 98..68
			timestamp_in(index) &                     -- 67..52
			timefraction_in(index) &                  -- 51..40
			energy_in(index) &                        -- 39..24
			statusbyte_in(index) &                    -- 23..16
			channel_in(index);                        -- 15..0
dfifo: async_fifo_nn_progfull512_progempty128_FWFT_1024x99 port map(
		rst => reset, -- reset,
		wr_clk => inputclock,
		rd_clk => MUXclock,
		din => dfifo_din_S(index),
		wr_en => dfifo_wr_S(index),
		rd_en => dfifo_rd_S(index),
		dout => dfifo_dout_S(index),
		full => dfifo_full_S(index),
		empty => dfifo_empty_S(index),
		--GK: width problem
		--rd_data_count(9 downto 0) => infifo_fullness_S(index)(MUXINFIFOSIZE-1 downto 0),
		rd_data_count(9 downto 0) => infifo_fullness_S(index)(9 downto 0),
		prog_full => dfifo_prog_full_S(index),
		prog_empty => dfifo_prog_empty_S(index));
		
		
infifo_fullness_S(index)(15 downto MUXINFIFOSIZE) <= (others => '0');
infifo_fullness <= infifo_fullness_S;
dfifo_wr_S(index) <= '1' when (dfifo_full_S(index)='0') and (data_in_write(index)='1') else '0';
data_in_allowed(index) <= NOT dfifo_full_S(index);
data_in_almostfull(index) <= dfifo_prog_full_S(index);
data_in_available_S(index) <= '1' when dfifo_empty_S(index)='0' else '0';

channel_S(0,index) <= dfifo_dout_S(index)(15 downto 0);
statusbyte_S(0,index) <= dfifo_dout_S(index)(23 downto 16);
energy_S(0,index) <= dfifo_dout_S(index)(39 downto 24);
timefraction_S(0,index) <= dfifo_dout_S(index)(51 downto 40);
timestamp_S(0,index) <= dfifo_dout_S(index)(67 downto 52);
superburstnumber_S(0,index) <= dfifo_dout_S(index)(98 downto 68);
fiber_index_S(0,index) <= conv_std_logic_vector(index,4);


data_write_S(0,index) <= '1' when (data_allowed_S(0,index)='1') and (dfifo_empty_S(index)='0') else '0';
dfifo_rd_S(index) <= data_write_S(0,index);
data_in_available_S(index) <= '1' when dfifo_empty_S(index)='0' else '0';
read36_inpipe_S(index) <= '1' when (dfifo_empty_S(index)='0') else '0';
data_out_inpipe_S(0,index) <= '1' when (read36_inpipe_S(index)='1') or (delay_inpipe_S(index)='1') else '0';
	
end generate;


MUX_multiplex2to1_all: for i1 in 0 to mux2to1_gen_max-1 generate 

	MUX_multiplex2to1_i: for i2 in 0 to (2**(mux2to1_gen_max-i1-1))-1 generate 
	
		DC_mux2to1_1: DC_mux2to1 port map(
			clock => MUXclock,
			reset => reset_MUXclock_S,
			fiber_index1 => fiber_index_S(i1,i2*2),
			channel1 => channel_S(i1,i2*2),
			statusbyte1 => statusbyte_S(i1,i2*2),
			energy1 => energy_S(i1,i2*2),
			timefraction1 => timefraction_S(i1,i2*2),
			timestamp1 => timestamp_S(i1,i2*2),
			superburstnumber1 => superburstnumber_S(i1,i2*2),
			data1_in_write => data_write_S(i1,i2*2),
			data1_in_inpipe => data_out_inpipe_S(i1,i2*2),
			data1_in_allowed => data_allowed_S(i1,i2*2),
			fiber_index2 => fiber_index_S(i1,i2*2+1),
			channel2 => channel_S(i1,i2*2+1),
			statusbyte2 => statusbyte_S(i1,i2*2+1),
			energy2 => energy_S(i1,i2*2+1),
			timefraction2 => timefraction_S(i1,i2*2+1),
			timestamp2 => timestamp_S(i1,i2*2+1),
			superburstnumber2 => superburstnumber_S(i1,i2*2+1),
			data2_in_write => data_write_S(i1,i2*2+1),
			data2_in_inpipe => data_out_inpipe_S(i1,i2*2+1),
			data2_in_allowed => data_allowed_S(i1,i2*2+1),
			fiber_index => fiber_index_S(i1+1,i2),
			channel => channel_S(i1+1,i2),
			statusbyte => statusbyte_S(i1+1,i2),
			energy => energy_S(i1+1,i2),
			timefraction => timefraction_S(i1+1,i2),
			timestamp => timestamp_S(i1+1,i2),
			superburstnumber => superburstnumber_S(i1+1,i2),
			data_out_write => data_write_S(i1+1,i2),
			data_out_inpipe => data_out_inpipe_S(i1+1,i2),
			data_out_allowed => data_allowed_S(i1+1,i2),
			error => error_array_S(i1,i2),
			testword0 => open); -- testword0_S(i1,i2));

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

data_allowed_S(mux2to1_gen_max,0) <= '1' when (tfifo_full_S='0') else '0';

tfifo_in_S <= 
			fiber_index_S(mux2to1_gen_max,0) &        -- 102..99
			superburstnumber_S(mux2to1_gen_max,0) &   -- 98..68
			timestamp_S(mux2to1_gen_max,0) &          -- 67..52
			timefraction_S(mux2to1_gen_max,0) &       -- 51..40
			energy_S(mux2to1_gen_max,0) &             -- 39..24
			statusbyte_S(mux2to1_gen_max,0) &         -- 23..16
			channel_S(mux2to1_gen_max,0);             -- 15..0

tfifo: async_fifo_nn_4096x103 port map(
		rst => reset_MUXclock_S, --reset,
		wr_clk => MUXclock,
		rd_clk => outputclock,
		din => tfifo_in_S,
		wr_en => data_write_S(mux2to1_gen_max,0),
		rd_en => tfifo_rd_S,
		dout(15 downto 0) => channel_out,
		dout(23 downto 16) => statusbyte_out,
		dout(39 downto 24) => energy_out,
		dout(51 downto 40) => timefraction_out,
		dout(67 downto 52) => timestamp_out,
		dout(98 downto 68) => superburstnumber_out,
		dout(102 downto 99) => fiber_index_out,
		full => tfifo_full_S,
		empty => tfifo_empty_S,
		--GK: width problem
		--rd_data_count(11 downto 0) => outfifo_fullness(TRANSFERFIFOSIZE-1 downto 0));
		rd_data_count(11 downto 0) => outfifo_fullness(11 downto 0));
outfifo_fullness(15 downto TRANSFERFIFOSIZE) <= (others => '0');
		
tfifo_rd_S <= '1' when (data_out_read='1') and (tfifo_empty_S='0') else '0';
data_out_available <= '1' when tfifo_empty_S='0' else '0';


sync_reset_MUXclock: sync_bit port map(
	clock => MUXclock,
	data_in => reset,
	data_out => reset_MUXclock_S);

process(MUXclock)
begin
	if (rising_edge(MUXclock)) then 
		sorterror_S <= '0';
		if data_write_S(mux2to1_gen_max,0)='1' then
			if superburstnumber_S(mux2to1_gen_max,0)<lastsuperburst_S then
				sorterror_S <= '1';
			elsif superburstnumber_S(mux2to1_gen_max,0)=lastsuperburst_S then
				if timestamp_S(mux2to1_gen_max,0)<lasttimestamp_S then
					sorterror_S <= '1';
				end if;
			end if;
			lastsuperburst_S <= superburstnumber_S(mux2to1_gen_max,0);
			lasttimestamp_S <= timestamp_S(mux2to1_gen_max,0);
		end if;
	end if;
end process;

testword0(35 downto 0) <= (others => '0');
testword1(35 downto 0) <= (others => '0');

end Behavioral;

