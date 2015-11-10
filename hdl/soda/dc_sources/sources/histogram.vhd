----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   05-04-2011
-- Module Name:   histogram
-- Description:   Puts values in a histogram
----------------------------------------------------------------------------------


library IEEE;
USE ieee.std_logic_1164.all ;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

----------------------------------------------------------------------------------
-- histogram
-- Module make a histogram of values. 
-- Successive values must be separated by at least one clock cycle.
-- Reading can be done when acquiring data is still in process.
--
-- Library
--     work.panda_package : for type declarations and constants
-- 
-- Generics:
--     HISTOGRAM_SIZEBITS : number of bits for the histogram x-axis, 2^HISTOGRAM_SIZEBITS=number of histogram channels
--     RANGEBITS : number of bits for counts (y-axis)
-- 
-- Inputs:
--     clock : clock
--     clear : starts clearing the histogram. Clearing takes 2^HISTOGRAM_SIZEBITS clockcycles
--     datain : values for the histogram
--     writerequest : write for the datain values
--     address : address (index in histogram) that has to be read
--     readrequest : request the histogram value at address
-- 
-- Outputs:
--     dataout : resulting histogram data, some time after the readrequest
--     dataout_valid : valid signal for dataout
-- 
-- Components:
--     blockram : memory for the histogram, located at the bottom of this vhdl-file
--
----------------------------------------------------------------------------------
entity histogram is
	generic (
		HISTOGRAM_SIZEBITS      : natural := 12;
		RANGEBITS               : natural := 32
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
end histogram;

architecture behavioral of histogram is

component blockram is
	generic (
		WIDTH	: natural := HISTOGRAM_SIZEBITS;
		RANGEBITS	: natural := RANGEBITS
	);
	port
	(
      reset : in  std_logic; 
		clock : in std_logic;
		write_enable : in std_logic;
		address : in std_logic_vector(width-1 downto 0);
		data_in : in std_logic_vector(rangebits-1 downto 0);
		data_out : out std_logic_vector(rangebits-1 downto 0)
	);
end component;


	signal ram_writeenable : std_logic;
	signal ram_writeaddress : std_logic_vector(HISTOGRAM_SIZEBITS-1 downto 0);
	signal ram_datain : std_logic_vector(rangebits-1 downto 0);
	signal ram_dataout : std_logic_vector(rangebits-1 downto 0);
	
	signal write_onnextclk : std_logic := '0';
	signal read_valid : std_logic := '0';
	signal doclearing : std_logic := '0';

begin

block_ram: blockram port map(
        reset => '0',
        clock => clock,
        write_enable => ram_writeenable,
        address => ram_writeaddress,
        data_in => ram_datain,
        data_out => ram_dataout);

ram_datain <= (others => '0') when doclearing='1' else ram_dataout+1;



	process (clock)
	variable clearcounter : integer range 0 to (2**HISTOGRAM_SIZEBITS-1);
	variable readrequest_pending : std_logic := '0';
	variable read_thedata : std_logic := '0';
	begin
		if (clock'event and clock = '1') then
			if (clear='1') then
				doclearing <= '1';
				clearcounter := 2**HISTOGRAM_SIZEBITS-1;
				ram_writeaddress <= (others => '0');
				ram_writeenable <= '1';
				write_onnextclk <= '0';
				readrequest_pending := '0';
				read_valid <= '0';
				read_thedata := '0';
				dataout_valid <= '0';
				dataout_valid <= '0';
				dataout <=  (others => '0');
			elsif doclearing='1' then
				ram_writeaddress <= conv_std_logic_vector(clearcounter,HISTOGRAM_SIZEBITS);
				if clearcounter=0 then
					ram_writeenable <= '0';
					doclearing <= '0';
				else
					ram_writeenable <= '1';
					clearcounter := clearcounter-1;
				end if;
				write_onnextclk <= '0';
				readrequest_pending := '0';
				read_valid <= '0';
				read_thedata := '0';
				dataout_valid <= '0';
				dataout <=  (others => '0');
			else
				if read_thedata = '1' then
					dataout <= ram_dataout;
					dataout_valid <= '1';
				end if;
				if read_valid = '1' then
					read_thedata := '1';
					readrequest_pending := '0';
				elsif readrequest = '1' then
					dataout_valid <= '0';
					read_thedata := '0';
					readrequest_pending := '1';					
				else 
					read_thedata := '0';
				end if;
				
				if write_onnextclk='1' then
					ram_writeenable <= '1';
					write_onnextclk <= '0';					
					read_valid <= '0';
				elsif (writerequest = '1') then
					ram_writeenable <= '0';
					ram_writeaddress <= datain;
					read_valid <= '0';
					write_onnextclk <= '1';
				elsif (readrequest_pending = '1') and (read_valid = '0') then
					ram_writeenable <= '0';
					ram_writeaddress <= address;
					read_valid <= '1';
					write_onnextclk <= '0';
				else
					ram_writeenable <= '0';
					read_valid <= '0';
					write_onnextclk <= '0';
				end if;
			end if;
		end if;
	end process;

end architecture behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity blockram is
	generic (
		WIDTH	: natural := 16;
		RANGEBITS	: natural := 24
	);
	port
	(
      reset : in  std_logic; 
		clock : in std_logic;
		write_enable : in std_logic;
		address : in std_logic_vector(WIDTH-1 downto 0);
		data_in : in std_logic_vector(RANGEBITS-1 downto 0);
		data_out : out std_logic_vector(RANGEBITS-1 downto 0)
	);
end blockram;

architecture behavioral of blockram is
	type arrtype is array(0 TO 2**WIDTH - 1) of std_logic_vector(RANGEBITS-1 downto 0);
	signal arr : arrtype;
begin
	process(clock)
	begin
		if rising_edge(clock) then
			if (write_enable = '1') then
			    arr(conv_integer(address)) <= data_in;
			end if;
			data_out <= arr(conv_integer(address));
		end if;
	end process;
end behavioral;