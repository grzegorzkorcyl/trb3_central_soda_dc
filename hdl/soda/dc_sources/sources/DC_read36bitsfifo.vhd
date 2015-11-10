----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   25-02-2014
-- Module Name:   DC_read36bitsfifo
-- Description:   Breaks 36-bit data stream into its members
-- Modifications:
--   30-07-2014   Timestamp is now the time within the superburst
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;
USE work.panda_package.all;

----------------------------------------------------------------------------------
-- DC_read36bitsfifo
-- The 36-bits input data is translated to its members as parallel data:
--   channel : adc-index
--   statusbyte : 8 bit status information
--   energy : pulse energy
--   timefraction : fraction part of the timestamp
--   timestamp : 16 bits time within superburst, synchronised to master SODA clock
--   superburstnumber : 31 bits superburstnumber, assigned by DC, based on time
--
-- The data is double buffered so that the next data can be read while the data is being processed.
-- A signal that indicates if more data is in the buffer is passed on.
--
--
-- Library:
--     work.panda_package: types and constants
--
-- Generics:
--
-- Inputs:
--     clock : clock for input and output data
--     reset : reset
--     data_in : input data :
--        word0 : 0 & 0000 & timestamp(15..0)
--        word1 : 1 & 0 & superburstnumber(30..0)
--        word2 : 2 & statusbyte & 00 & adcnumber
--        word3 : 3 & timefraction & energy
--     data_in_available : input data available (NOT fifo-empty from connected fifo)
--     data_out_allowed : allowed to write output data
-- 
-- Outputs:
--     data_in_read : read signal for input data (read for connected fifo)
--     channel : adc-index
--     statusbyte : 8 bit status information
--     energy : pulse energy
--     timefraction : fraction part of the timestamp
--     timestamp : 16 bits timestamp within superburst, synchronised to master SODA clock
--     superburstnumber : superburst index number where the data is assigned to
--     data_out_write : write signal for output data
--     data_out_trywrite : output is trying to write data, but data_out_allowed is preventing this
--     data_out_inpipe : more data available in near future
--     error : data error
-- 
-- Components:
--
--
--
----------------------------------------------------------------------------------

entity DC_read36bitsfifo is
	port ( 
		clock                   : in std_logic;
		reset                   : in std_logic;
		data_in                 : in std_logic_vector(35 downto 0);
		data_in_available       : in std_logic;
		data_in_read            : out std_logic;
		channel                 : out std_logic_vector(15 downto 0);
		statusbyte              : out std_logic_vector(7 downto 0);
		energy                  : out std_logic_vector(15 downto 0);
		timefraction            : out std_logic_vector(11 downto 0);
		timestamp               : out std_logic_vector(15 downto 0);
		superburstnumber        : out std_logic_vector(30 downto 0);
		data_out_write          : out std_logic;
		data_out_trywrite       : out std_logic;
		data_out_inpipe         : out std_logic;
		data_out_allowed        : in std_logic;
		error                   : out std_logic);
end DC_read36bitsfifo;


architecture Behavioral of DC_read36bitsfifo is

attribute syn_keep     : boolean;
attribute syn_preserve : boolean;

signal data_in_available_S    : std_logic := '0';
signal data_in_read_S         : std_logic := '0';
signal data_in_read_prev_S    : std_logic := '0';
signal data_out_inpipe_S      : std_logic := '0';
signal data_out_write_S       : std_logic := '0';
signal data_out_trywrite_S    : std_logic := '0';
signal data_out_allowed_S     : std_logic := '0';
signal error_S                : std_logic := '0';
signal data_in_index_S        : integer range 0 to 3 := 0;
signal writebuf_S             : std_logic := '0';
signal try_writebuf_S         : std_logic := '0';
signal buf_filled_S           : std_logic := '0';
signal channel_S              : std_logic_vector(15 downto 0);
signal statusbyte_S           : std_logic_vector(7 downto 0);
signal energy_S               : std_logic_vector(15 downto 0);
signal timefraction_S         : std_logic_vector(11 downto 0);
signal timestamp_S            : std_logic_vector(15 downto 0) := (others => '0');
signal timestamp_out_S        : std_logic_vector(15 downto 0) := (others => '0');
signal superburstnumber_S     : std_logic_vector(30 downto 0);

begin

data_in_available_S <= data_in_available;
data_in_read <= data_in_read_S;
data_out_inpipe <= data_out_inpipe_S;
data_out_write <= data_out_write_S;
data_out_allowed_S <= data_out_allowed;

error <= error_S;
timestamp <= timestamp_out_S;
data_out_trywrite <= data_out_trywrite_S;

data_in_read_S <= '1' when 
		(((try_writebuf_S='1') and (writebuf_S='1')) or
		((data_in_index_S=1) or (data_in_index_S=2)) or
		((data_in_index_S=3) and (buf_filled_S='0')) or
		((data_in_index_S=0) and (buf_filled_S='0'))) and
		(data_in_available_S='1') 
	else '0';
		
process(clock)
begin
	if (rising_edge(clock)) then
		if (data_in_available_S='1') or (data_in_read_prev_S='1') or (buf_filled_S='1') or (data_in_read_S='1') or (data_in_index_S/=0) then
			data_out_inpipe_S <= '1';
		else
			data_out_inpipe_S <= '0';
		end if;
	end if;
end process;
	
-- data_out_inpipe_S <= '1' when (data_in_available_S='1') or (data_in_read_prev_S='1') or (buf_filled_S='1') or
	-- (data_in_read_S='1') or (data_in_index_S/=0) else '0';

data_out_write_S <= '1' when (data_out_allowed_S='1') and (data_out_trywrite_S='1') else '0';

writebuf_S <= '1' when 
		((try_writebuf_S='1') and (buf_filled_S='0')) or 
		((try_writebuf_S='1') and (data_out_write_S='1')) 		
	else '0';

process(clock)
begin
	if (rising_edge(clock)) then 
		if (reset = '1') then 
			buf_filled_S <= '0';
			timestamp_out_S <= (others => '0');
		else
			if writebuf_S='1' then
				buf_filled_S <= '1';
				channel <= channel_S;
				statusbyte <= statusbyte_S;
				energy <= energy_S;
				timefraction <= timefraction_S;
				timestamp_out_S <= timestamp_S;
				superburstnumber <= superburstnumber_S;
				data_out_trywrite_S <= '1';
			else
				if data_out_write_S='1' then
					buf_filled_S <= '0';
					data_out_trywrite_S <= '0';
				end if;
			end if;		
		end if;
	end if;
end process;


process(clock)
begin
	if (rising_edge(clock)) then 
		data_in_read_prev_S <= data_in_read_S;
		if (reset = '1') then 
			error_S <= '0';
			data_in_index_S <= 0;
			try_writebuf_S <= '0';
			timestamp_S <= (others => '0');
		else
			if data_in_read_prev_S='1' then
				case data_in_index_S is
					when 0 => --        word0 : 0 & 0000 & timestamp(15..0)
						try_writebuf_S <= '0';
						if data_in(35 downto 32) /= "0000" then
							error_S <= '1';
							data_in_index_S <= 0;
						else
							timestamp_S(15 downto 0) <= data_in(15 downto 0);
							error_S <= '0';
							data_in_index_S <= 1;
						end if;
					when 1 => --        word1 : 1 & 00 & superburstnumber(30..0)
						try_writebuf_S <= '0';
						if data_in(35 downto 32) /= "0001" then
							error_S <= '1';
							data_in_index_S <= 0;
						else
							error_S <= '0';
							superburstnumber_S <= data_in(30 downto 0);
							data_in_index_S <= 2;
						end if;
					when 2 => --        word2 : 2 & statusbyte & 00 & adcnumber
						try_writebuf_S <= '0';
						if data_in(35 downto 32) /= "0010" then
							error_S <= '1';
							data_in_index_S <= 0;
						else
							channel_S <= data_in(15 downto 0);
							statusbyte_S <= data_in(31 downto 24);
							error_S <= '0';
							data_in_index_S <= 3;
						end if;
					when 3 => --        word3 : 3 & timefraction & energy
						if data_in(35 downto 32) /= "0011" then
							try_writebuf_S <= '0';
							error_S <= '1';
							data_in_index_S <= 0;
						else
							energy_S <= data_in(15 downto 0);
							timefraction_S <= data_in(27 downto 16);
							error_S <= '0';
							data_in_index_S <= 0;
							try_writebuf_S <= '1';
						end if;
					when others => 
				end case;
			else
				if (try_writebuf_S='1') and (writebuf_S='1') then
					try_writebuf_S <= '0';
				end if;
			end if;
		end if;
	end if;
end process;

end Behavioral;

