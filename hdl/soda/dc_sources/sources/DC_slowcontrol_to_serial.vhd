----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   07-03-2012
-- Module Name:   DC_slowcontrol_to_serial
-- Description:   Module to send slowcontrol data serially to the soft-core cpu
-- Modifications:
--    16-09-2014: name changed from MUX_slowcontrol_to_serial to DC_slowcontrol_to_serial
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;

----------------------------------------------------------------------------------
-- DC_slowcontrol_to_serial
-- Module to transfer slowcontrol serially to the soft-core cpu.
-- The slowcontrol data input is parallel data: address, data and reply bit.
-- The serials data starts if the first IO_byte bit 7 is 1 and 
-- bits 3..0 corresponds with the channel number.
-- Then 32 bits data will be returned to the cpu, MSB first.
-- Slowcontrol address and data are sent after each other.
-- The address word has bit 30..28 set to 101 as check
-- Bit 31 of the address word is the slow control reply bit.
--
-- Library:
-- 
-- Generics:
-- 
-- Inputs:
--     write_clock : clock for the slowcontrol data from the GTP receiver module
--     read_clock : clock for the slowcontrol serial data
--     reset : reset
--     channel : index of the fiber
--     slowcontrol_data : slowcontrol data; 32bits
--     slowcontrol_address : slowcontrol address; 24bits
--     slowcontrol_reply : slowcontrol reply bit
--     slowcontrol_write : write signals for the slowcontrol data/address/reply	  
--     IO_byte : 5-byte slowcontrol:
--         Byte0 : Read bit , "000", index of the fiber 
--         Byte1,2,3,4 : alternating: 
--                     request-bit 101 xxxx 24-bits_address(MSB first)
--                     32-bits_data, MSB first
--     IO_write : write signal for byte-data, only selected fiber (with index in first byte equals channel) should read
-- 
-- Outputs:
--     IO_serialdata : serial data : 32 bits:
--          bit31..0 : data, MSB first
--     IO_serialavailable : data is available
--     error : error is a slowcontrol command is skipped
-- 
-- Components:
--     async_fifo_512x32 : Fifo with 32-bits input and output
--
----------------------------------------------------------------------------------

entity DC_slowcontrol_to_serial is
	port ( 
		write_clock             : in std_logic;
		read_clock              : in std_logic;
		reset                   : in std_logic;
		channel                 : in std_logic_vector (3 downto 0);
		slowcontrol_data        : in std_logic_vector (31 downto 0);
		slowcontrol_address     : in std_logic_vector (23 downto 0);
		slowcontrol_reply       : in std_logic;
		slowcontrol_write       : in std_logic;			  
		IO_byte                 : in std_logic_vector (7 downto 0);
		IO_write                : in std_logic;
		IO_serialdata           : out std_logic;
		IO_serialavailable      : out std_logic;
		error                   : out std_logic
		);
end DC_slowcontrol_to_serial;

architecture Behavioral of DC_slowcontrol_to_serial is

component async_fifo_512x32
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


signal reset_write_clock_S    : std_logic;
signal reset_read_clock_S     : std_logic;
signal sfifo_data_in_S        : std_logic_vector(31 downto 0);
signal sfifo_data_out_S       : std_logic_vector(31 downto 0);
signal sfifo_write_S          : std_logic;
signal sfifo_read_S           : std_logic;
signal sfifo_full_S           : std_logic;
signal sfifo_empty_S          : std_logic;

signal skipped_S              : std_logic;
signal writefifo_S            : std_logic;
signal write_seconddata_S     : std_logic;

signal secondword_S           : std_logic_vector(31 downto 0);
signal buffer_firstword_S     : std_logic_vector(31 downto 0);
signal buffer_secondword_S    : std_logic_vector(31 downto 0);
signal buffer_written_S       : std_logic;

signal bit_idx_S              : integer range 0 to 31 := 0;
signal byte_idx_S             : integer range 0 to 4 := 0;

signal IO_serialdata_S        : std_logic;
signal error1_S               : std_logic;

begin

error <= '1' when (skipped_S='1') or (error1_S='1') else '0';
IO_serialavailable <= '1' when sfifo_empty_S='0' else '0';

async_outfifo: async_fifo_512x32 port map(
	rst => reset_write_clock_S,
	wr_clk => write_clock,
	rd_clk => read_clock,
	din => sfifo_data_in_S,
	wr_en => sfifo_write_S,
	rd_en => sfifo_read_S,
	dout => sfifo_data_out_S,
	full => sfifo_full_S,
	empty => sfifo_empty_S);
sfifo_write_S <= '1' when (writefifo_S='1') and (sfifo_full_S='0') else '0';
	
process(write_clock)
begin
	if (rising_edge(write_clock)) then 
		if (reset_write_clock_S = '1') then
			write_seconddata_S <= '0';
			skipped_S <= '0';
			writefifo_S <= '0';
			buffer_written_S <= '0';
		else
			if write_seconddata_S='1' then
				if (writefifo_S='1') and (sfifo_write_S='0') then -- unsuccessfull write
					write_seconddata_S <= '1';
					writefifo_S <= '1'; -- keep trying
				else 
					sfifo_data_in_S <= secondword_S;
					writefifo_S <= '1';
					write_seconddata_S <= '0';
				end if;
				if slowcontrol_write='1' then
					if buffer_written_S = '1' then
						skipped_S <= '1';
					else
						buffer_firstword_S <= slowcontrol_reply & "101000" & skipped_S & slowcontrol_address;
						buffer_secondword_S <= slowcontrol_data;
						buffer_written_S <= '1';
					end if;
				end if;
			else
				if (writefifo_S='1') and (sfifo_write_S='0') then -- unsuccessfull write
					writefifo_S <= '1'; -- keep trying
					write_seconddata_S <= '0';
					if slowcontrol_write='1' then
						if buffer_written_S = '1' then
							skipped_S <= '1';
						else
							buffer_firstword_S <= slowcontrol_reply & "101000" & skipped_S & slowcontrol_address;
							buffer_secondword_S <= slowcontrol_data;
							buffer_written_S <= '1';
						end if;
					end if;
				else 
					if buffer_written_S='1' then
						if slowcontrol_write='1' then
							sfifo_data_in_S <= buffer_firstword_S(31 downto 25) & '1' & buffer_firstword_S(23 downto 0);							
						else
							sfifo_data_in_S <= buffer_firstword_S(31 downto 25) & skipped_S & buffer_firstword_S(23 downto 0);							
						end if;
						writefifo_S <= '1';
						write_seconddata_S <= '1';
						skipped_S <= '0';				
					elsif slowcontrol_write='1' then
						sfifo_data_in_S <= slowcontrol_reply & "101000" & skipped_S & slowcontrol_address;
						secondword_S <= slowcontrol_data;
						writefifo_S <= '1';
						write_seconddata_S <= '1';
						skipped_S <= '0';
					else
						write_seconddata_S <= '0';
						writefifo_S <= '0';
					end if;
					buffer_written_S <= '0';
				end if;
			end if;
		end if;
		reset_write_clock_S <= reset;
	end if;
end process;


sfifo_read_S <= '1' when (byte_idx_S=0) and (IO_write='1') and (IO_byte(7)='1') and 
		(IO_byte(3 downto 0)=channel) and (sfifo_empty_S='0') 
	else '0';
	
process(read_clock) -- one additional clockcycle to meet constraint
begin
	if (rising_edge(read_clock)) then 
		if (bit_idx_S=1) then
			IO_serialdata <= sfifo_data_out_S(31);
		else
			IO_serialdata <= IO_serialdata_S;
		end if;
	end if;
end process;

--	IO_serialdata <= sfifo_data_out_S(31) when (bit_idx_S=1) else IO_serialdata_S;

rd_process: process(read_clock)
begin
	if (rising_edge(read_clock)) then 
		if reset_read_clock_S='1' then
			bit_idx_S <= 0;
			IO_serialdata_S <= '0';
		else
			if bit_idx_S=0 then
				if sfifo_read_S='1' then
					bit_idx_S <= 1;
				else
					IO_serialdata_S <= '0';
				end if;
			else 
				IO_serialdata_S <= sfifo_data_out_S(31-bit_idx_S);				
				if bit_idx_S<31 then 
					bit_idx_S <= bit_idx_S+1;
				else
					bit_idx_S <= 0;					
				end if;
			end if;
		end if;
		reset_read_clock_S <= reset;
	end if;
end process;

rdbyte_process: process(read_clock)
begin
	if (rising_edge(read_clock)) then 
		if reset_read_clock_S='1' then
			byte_idx_S <= 0;
			error1_S <= '0';
		else
			if byte_idx_S=0 then
				error1_S <= '0';
				if (IO_write='1') then
					if (IO_byte(7)='0') then
						byte_idx_S <= 1;
					end if;
				end if;
			else
				if (IO_write='1')  then
					error1_S <= '0';
					if byte_idx_S<4 then
						byte_idx_S <= byte_idx_S + 1;
					else
						byte_idx_S <= 0;
					end if;
				else -- error
					error1_S <= '1';
					byte_idx_S <= 0;
				end if;
			end if;
		end if;
	end if;
end process;



end Behavioral;
