----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   27-01-2014
-- Module Name:   DC_superburst2packet64
-- Description:   Put pulse data in 64-bits packets, based on Superburstnumber
-- Modifications:
--     18-07-2014 Check for too many superburst without data, see MAXSUPERBURSTBEHIND
--     08-04-2015 Check for new superburst too much behind (2*MAXSUPERBURSTBEHIND)
--     09-04-2015 Check for superburstnumber decreased
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;
USE work.panda_package.all;

----------------------------------------------------------------------------------
-- DC_superburst2packet64
-- The pulse data members are transferred to 64bits data for fiber connection
-- The incomming pulse data is passed on as packets with 64-bits width data.
-- All the data from one superburst is put in one data-packet.
-- The first word-64 contains the superburst number and the timestamp of the first pulse.
-- The superburst are sequential. If there is no data in a superburst then the packet 
-- contains only the superburst and zero for the timestamp.
-- For each pulse a 64-bits word is written with measured data.
-- The highest byte gives the number of ADC-clockcycles after the first pulse (for the first pulse this is 0)
-- If a pulse from the next superburst is received then it is stored temporarily and 
-- sent after a timeout, if data from a even more recent superburst is received, or if the buffer is full.
-- The first and last 64-bits words of a packet are marked with separated signals.
-- An empty packet has both first and last signal assigned at the same time.
--
-- Input data:
--   channel : adc-index
--   statusbyte : 8 bit status information
--   energy : pulse energy
--   timefraction : fraction part of the timestamp
--   timestamp : 48 bits timestamp, synchronised to master SODA clock
--
-- Output data 64 bits: (for CF_FRACTIONBIT=11)
--   U64_0 : bit63=0 SuperburstNumber(30 downto 0) 0x00000000
--   U64_1 : offsettime(12:0) TimeFraction(10:0) status(7:0) ADCchannel(15:0) Energy(15:0) 
--   U64_2 : offsettime(12:0) TimeFraction(10:0) status(7:0) ADCchannel(15:0) Energy(15:0)
--   ..         ..          ..             ..                  ..            ..
--
--
--
-- Library:
--     work.panda_package: types and constants
--
-- Generics:
--     TRANSITIONBUFFERBITS : number of bits for the buffer that stores data from the next supreburst
--     CF_FRACTIONBIT : number of valid constant fraction bits
--
-- Inputs:
--     clock : clock for input and output data
--     reset : reset
--     channel : adc-index
--     statusbyte : 8 bit status information
--     energy : pulse energy
--     timefraction : fraction part of the timestamp
--     timestamp : 16 bits timestamp within superburst, synchronised to master SODA clock
--     superburstnumber : superburst index number where the data is assigned to
--     data_in_available : input data available (NOT fifo-empty from connected fifo)
--     latestsuperburstnumber : latest superburst number that has been issued by SODA
--     data64_out_allowed : allowed to write 64 output data (connecting fifo not full)
-- 
-- Outputs:
--     data_in_read : read signal for input data
--     data64_out : 64 bits data
--     data64_out_write : write signal for 64 bits data
--     data64_out_first : first 64-bits word in packet
--     data64_out_last : last 64-bits word in packet
--     error : error reading or writing or superburstnumber
-- 
-- Components:
--     blockmem : memory block to buffer a packet before transmitting
--
----------------------------------------------------------------------------------

entity DC_superburst2packet64 is
	generic (
		TRANSITIONBUFFERBITS    : natural := 9;
		CF_FRACTIONBIT          : natural := 11
	);
    Port ( 
		clock                   : in std_logic;
		reset                   : in std_logic;
		channel                 : in std_logic_vector(15 downto 0);
		statusbyte              : in std_logic_vector(7 downto 0);
		energy                  : in std_logic_vector(15 downto 0);
		timefraction            : in std_logic_vector(11 downto 0);
		timestamp               : in std_logic_vector(15 downto 0);
		superburstnumber        : in std_logic_vector(30 downto 0);
		data_in_read            : out std_logic;
		data_in_available       : in std_logic;
		latestsuperburstnumber  : in std_logic_vector(30 downto 0);
		data64_out              : out std_logic_vector(63 downto 0);
		data64_out_write        : out std_logic;
		data64_out_first        : out std_logic;
		data64_out_last         : out std_logic;
		data64_out_allowed      : in std_logic;
		error                   : out std_logic;
		testword0               : out std_logic_vector(35 downto 0) := (others => '0')
	);    
end DC_superburst2packet64;


architecture Behavioral of DC_superburst2packet64 is

component blockmem is
	generic (
		ADDRESS_BITS : natural := TRANSITIONBUFFERBITS;
		DATA_BITS  : natural := 64
		);
	port (
		clock                   : in  std_logic; 
		write_enable            : in std_logic;
		write_address           : in std_logic_vector(ADDRESS_BITS-1 downto 0);
		data_in                 : in std_logic_vector(DATA_BITS-1 downto 0);
		read_address            : in std_logic_vector(ADDRESS_BITS-1 downto 0);
		data_out                : out std_logic_vector(DATA_BITS-1 downto 0)
	);
end component;


constant ones                     : std_logic_vector(31 downto 0) := (others => '1');
constant zeros                    : std_logic_vector(31 downto 0) := (others => '0');
constant MAXWAITTIIMEBITS         : integer := 14;
constant MAXSUPERBURSTBEHIND      : std_logic_vector(30 downto 0) := conv_std_logic_vector(16,31);
type readinmode_type is (initialize,waitforfirstpacket,writesomemissingpackets,writemissingpackets,writefirstpacket,waitfornextdata,waitforallowed,
				waitforcleanupallowed,cleanupmemoryzero,cleanupmemoryfirst,cleanupmemorynext,
				writelastdatafrommemory);
signal readinmode_S               : readinmode_type := initialize;


signal data_in_read_S             : std_logic := '0';
signal data_in_read_after1clk_S   : std_logic := '0';
signal data64_out_write_S         : std_logic := '0';
signal data64_out_S               : std_logic_vector(63 downto 0) := (others => '0');
signal data64_out_write_retry_S   : std_logic := '0';
signal data64_out_write_final_S   : std_logic := '0';
signal blockmem_datatin_S         : std_logic_vector(63 downto 0) := (others => '0');
	
signal mem_write_enable_S         : std_logic := '0';
signal mem_write_address_S        : std_logic_vector(TRANSITIONBUFFERBITS-1 downto 0) := (others => '0');
signal mem_read_address_S         : std_logic_vector(TRANSITIONBUFFERBITS-1 downto 0) := (others => '0');
signal mem_read_address_p1_S      : std_logic_vector(TRANSITIONBUFFERBITS-1 downto 0) := (others => '0');
signal mem_read_address_now_S     : std_logic_vector(TRANSITIONBUFFERBITS-1 downto 0) := (others => '0');
signal mem_read_address_plus1_S   : std_logic_vector(TRANSITIONBUFFERBITS-1 downto 0) := (others => '0');

signal timefraction_corr_S        : std_logic_vector(CF_FRACTIONBIT-1 downto 0) := (others => '0');
signal timestamp_corr_S           : std_logic_vector(23-CF_FRACTIONBIT downto 0) := (others => '0');
signal channel_S                  : std_logic_vector(15 downto 0) := (others => '0');
signal statusbyte_S               : std_logic_vector(7 downto 0) := (others => '0');
signal energy_S                   : std_logic_vector(15 downto 0) := (others => '0');
signal timefraction_S             : std_logic_vector(CF_FRACTIONBIT-1 downto 0) := (others => '0');
signal timestamp_S                : std_logic_vector(23-CF_FRACTIONBIT downto 0) := (others => '0');
signal superburstnumber_S         : std_logic_vector(30 downto 0) := (others => '0');
signal actual_superburstnumber_S  : std_logic_vector(30 downto 0) := (others => '0');
signal actual_superburstnumber_ahead_S : std_logic_vector(30 downto 0) := (others => '0');

signal actual_superburstnumber_p1_S  : std_logic_vector(30 downto 0);
signal actual_superburstnumber_p2_S  : std_logic_vector(30 downto 0);
signal superburstnumberrewind_S   : std_logic := '0';
signal latestsuperburstnumber_S   : std_logic_vector(30 downto 0);

signal actual_superburstnumberplusMAX_S  : std_logic_vector(30 downto 0);


signal mem_channel_S              : std_logic_vector(15 downto 0);
signal mem_statusbyte_S           : std_logic_vector(7 downto 0);
signal mem_energy_S               : std_logic_vector(15 downto 0);
signal mem_timefraction_S         : std_logic_vector(CF_FRACTIONBIT-1 downto 0);
signal mem_timestamp_S            : std_logic_vector(23-CF_FRACTIONBIT downto 0);
signal data64frommem_S            : std_logic := '0';

signal superburst_new_error_S     : std_logic := '0';
signal superburst_old_error_S     : std_logic := '0';
				
signal data64buf_S                : std_logic_vector(63 downto 0) := (others => '0');

signal data64buf_available_S      : std_logic := '0';
signal data_in_memory_S           : std_logic := '0';
signal newdataavailable_S         : std_logic := '0';
signal error_S                    : std_logic := '0';
signal timeoutcounter_S           : std_logic_vector(MAXWAITTIIMEBITS-1 downto 0) := (others => '0');

attribute syn_keep     : boolean;
attribute syn_preserve : boolean;

type readinmode_array is array(0 to 7) of std_logic_vector(3 downto 0);
signal debug_readinmodes_S : readinmode_array;
signal debug_readinmode_S : std_logic_vector(3 downto 0);
attribute syn_keep of debug_readinmodes_S : signal is true;
attribute syn_preserve of debug_readinmodes_S : signal is true;
attribute syn_keep of debug_readinmode_S : signal is true;
attribute syn_preserve of debug_readinmode_S : signal is true;

begin

timefraction_corr_S <= timefraction(CF_FRACTIONBIT-1 downto 0);
timestamp_corr_S <= ones(23-CF_FRACTIONBIT downto 0) when timestamp>ones(23-CF_FRACTIONBIT downto 0)
	else timestamp(23-CF_FRACTIONBIT downto 0);

process(clock)
begin
	if (rising_edge(clock)) then 
		error <= error_S;
	end if;
end process;

error_S <= '1' when
	((data64_out_write_final_S='1') and (data64_out_allowed='0')) or
	((data_in_read_after1clk_S='1') and (not ((readinmode_S=waitforfirstpacket) or (readinmode_S=waitfornextdata)))) or
	(superburst_new_error_S='1') or
	(superburst_old_error_S='1')
	else '0';
	
blockmem1: blockmem port map(
		clock => clock,
		write_enable => mem_write_enable_S,
		write_address => mem_write_address_S,
		data_in => blockmem_datatin_S,
		read_address => mem_read_address_S,
		data_out(15 downto 0) => mem_channel_S,
		data_out(31 downto 16) => mem_energy_S,
		data_out(39 downto 32) => mem_statusbyte_S,
		data_out(CF_FRACTIONBIT+39 downto 40) => mem_timefraction_S,
		data_out(63 downto CF_FRACTIONBIT+40) => mem_timestamp_S
		);
blockmem_datatin_S <= timestamp_S & timefraction_S & statusbyte_S & energy_S & channel_S; -- (24-CF_FRACTIONBIT)+CF_FRACTIONBIT+8+16+16 = 24+8+16+16

data_in_read <= data_in_read_S;
data_in_read_S <= '1' when 
	((data_in_available='1') and (reset='0') and (data64_out_allowed='1') and (data64_out_write_retry_S='0')) and
	(
		(
			(readinmode_S=waitforfirstpacket) and
			(data_in_read_after1clk_S='0')
		) or
		(
			(readinmode_S=waitfornextdata) and
			((data_in_read_after1clk_S='0') or (superburstnumber=actual_superburstnumber_S)) and
			((data_in_read_after1clk_S='0') or 
				((superburstnumber=actual_superburstnumber_p1_S) and 
					(mem_write_address_S(TRANSITIONBUFFERBITS-1 downto 1)=ones(TRANSITIONBUFFERBITS-1 downto 1)))) 
		)
	)
	else '0';



data64_out_write <= data64_out_write_final_S;
data64_out_write_final_S <= '1' when ((data64_out_write_S='1') and (data64_out_allowed='1')) or 
	((data64_out_write_retry_S='1') and (data64_out_allowed='1'))
	else '0';
	
process(clock)
begin
	if (rising_edge(clock)) then 
		if (data64_out_write_S='1') and (data64_out_allowed='0') then
			data64_out_write_retry_S <= '1';
		elsif data64_out_allowed='1' then
			data64_out_write_retry_S <= '0';
		end if;
	end if;
end process;

mem_read_address_S <= 
	(others => '0') when ((readinmode_S/=cleanupmemorynext) and (readinmode_S/=writelastdatafrommemory)) else
	mem_read_address_plus1_S when (data64_out_allowed='1') else
	mem_read_address_now_S;
			
data64_out <= data64_out_S when data64frommem_S='0' else 
	mem_timestamp_S & mem_timefraction_S & mem_statusbyte_S & mem_channel_S & mem_energy_S; -- = 13+11+8+16+16
		
superburst_new_error_S <= '1' when
	((data_in_read_after1clk_S='1') and (superburstnumber<actual_superburstnumber_S)) or
	((data_in_read_after1clk_S='1') and (superburstnumber>latestsuperburstnumber)) -- or 
--	((data_in_read_after1clk_S='1') and (superburstnumber+(MAXSUPERBURSTBEHIND(28 downto 0)&"00")<actual_superburstnumber_S))
	else '0';
	
actual_superburstnumber_ahead_S <= actual_superburstnumber_S+(MAXSUPERBURSTBEHIND(28 downto 0)&"00");
process(clock)
begin
	if (rising_edge(clock)) then 
		if (latestsuperburstnumber_S>latestsuperburstnumber) 
			or (actual_superburstnumber_S>latestsuperburstnumber)  -- check if superburstnumber is decreased or too far ahead: then initialize
			or (latestsuperburstnumber>actual_superburstnumber_ahead_S) then
			superburstnumberrewind_S <= '1';
		elsif superburstnumberrewind_S='1' then
			if readinmode_S=initialize then
				superburstnumberrewind_S <= '0';
			end if;			
		end if;
		latestsuperburstnumber_S <= latestsuperburstnumber;
	end if;
end process;

process(clock)
begin
	if (rising_edge(clock)) then 
		if (data_in_read_after1clk_S='1') and (superburst_new_error_S='0') then
			channel_S <= channel;
			statusbyte_S <= statusbyte;
			energy_S <= energy;
			timefraction_S <= timefraction_corr_S;
			timestamp_S <= timestamp_corr_S;
			superburstnumber_S <= superburstnumber;
		end if;
	end if;
end process;

process(clock)
begin
	if (rising_edge(clock)) then 
		if (reset='1') or (readinmode_S=initialize) then
			mem_write_address_S <= (others => '0');
		else
			if (readinmode_S=writelastdatafrommemory) or
				(readinmode_S=waitforfirstpacket) then
					mem_write_address_S <= (others => '0');
			else
				if mem_write_enable_S='1' then -- increase address automatically after write
					mem_write_address_S <= mem_write_address_S+1;
				end if;
			end if;
		end if;
	end if;
end process;

					
actual_superburstnumberplusMAX_S <= actual_superburstnumber_S+MAXSUPERBURSTBEHIND;
actual_superburstnumber_p1_S <= actual_superburstnumber_S+1;
actual_superburstnumber_p2_S <= actual_superburstnumber_S+2;
mem_read_address_p1_S <= mem_read_address_S+1;
process(clock)
begin
	if (rising_edge(clock)) then 
		superburst_old_error_S <= '0';
		data64_out_write_S <= '0';
		mem_write_enable_S <= '0';
		if reset='1' then
			readinmode_S <= initialize;
		else
			data_in_read_after1clk_S <= data_in_read_S;
			case readinmode_S is
				when initialize =>
					data_in_read_after1clk_S <= '0';
					data64_out_first <= '0';
					data64_out_last <= '0';
					data64buf_available_S <= '0';
					data_in_memory_S <= '0';
					if superburstnumber>=(MAXSUPERBURSTBEHIND(28 downto 0)&"00") then
						actual_superburstnumber_S <= latestsuperburstnumber-(MAXSUPERBURSTBEHIND(28 downto 0)&"00");
					else
						actual_superburstnumber_S <= (others => '0');
					end if;		
					data64frommem_S <= '0';
					newdataavailable_S <= '0';
					mem_read_address_plus1_S <= (others => '0');
					mem_read_address_now_S <= (others => '0');
					readinmode_S <= waitforfirstpacket;
				when waitforfirstpacket =>
					data64frommem_S <= '0';
					data_in_memory_S <= '0';
					timeoutcounter_S <= (others => '0');
					if data_in_read_after1clk_S='1' then
						if (superburst_new_error_S='0') then
							if (superburstnumber>actual_superburstnumber_p1_S) then
								if superburstnumberrewind_S='1' then
									readinmode_S <= initialize;
								else
									readinmode_S <= writemissingpackets;
								end if;
							elsif (superburstnumber=actual_superburstnumber_p1_S) or (actual_superburstnumber_S=zeros(30 downto 0)) then
								data64_out_S <= '0' & superburstnumber & x"00000000";
								data64_out_write_S <= '1';
								data64_out_first <= '1';
								data64_out_last <= '0';
								data64buf_S <= timestamp_corr_S & timefraction_corr_S & statusbyte & channel & energy; -- = 13+11+8+16+16
								data64buf_available_S <= '1';
								actual_superburstnumber_S <= superburstnumber;
								readinmode_S <= waitfornextdata;
							else
								superburst_old_error_S <= '1';
							end if;
						end if;
					else -- no hit, check superburstnumber
						if superburstnumberrewind_S='1' then
							readinmode_S <= initialize;
						else
							if (actual_superburstnumberplusMAX_S<latestsuperburstnumber) and
									(data_in_available='0') and
									(data_in_read_S='0') then --//necessary?
								readinmode_S <= writesomemissingpackets;
							end if;
						end if;
					end if;
				when writesomemissingpackets => -- write all missing packets 
					data64frommem_S <= '0';
					if data64_out_allowed='1' then -- check if allowed
						data64_out_S <= '0' & actual_superburstnumber_p1_S & x"00000000";
						data64_out_write_S <= '1';
						data64_out_first <= '1';
						data64_out_last <= '1';
						if (actual_superburstnumberplusMAX_S<latestsuperburstnumber) then
							if superburstnumberrewind_S='1' then
								readinmode_S <= initialize;
							else
								readinmode_S <= writesomemissingpackets;
							end if;
						else
							if superburstnumberrewind_S='1' then
								readinmode_S <= initialize;
							else
								readinmode_S <= waitforfirstpacket;
							end if;
						end if;
						-- if actual_superburstnumber_S+(MAXSUPERBURSTBEHIND(28 downto 0)&"00") < latestsuperburstnumber then  -- skip superburstnumbers if they are too far behind
							-- if latestsuperburstnumber>=(MAXSUPERBURSTBEHIND(28 downto 0)&"00") then
								-- actual_superburstnumber_S <= latestsuperburstnumber-(MAXSUPERBURSTBEHIND(28 downto 0)&"00");
							-- else
								-- actual_superburstnumber_S <= (others => '0');
							-- end if;
						-- else
							actual_superburstnumber_S <= actual_superburstnumber_p1_S;
						-- end if;
					end if;
				when writemissingpackets => -- write all missing packets 
					data64frommem_S <= '0';
					if data64_out_allowed='1' then -- check if allowed
						data64_out_S <= '0' & actual_superburstnumber_p1_S & x"00000000";
						data64_out_write_S <= '1';
						data64_out_first <= '1';
						data64_out_last <= '1';
						if superburstnumberrewind_S='1' then
							readinmode_S <= initialize;
						else
							if (actual_superburstnumber_p2_S>=superburstnumber_S) then --//
								readinmode_S <= writefirstpacket; -- write the first data of the new packet
							else
								readinmode_S <= writemissingpackets;
							end if;
						end if;
						-- if actual_superburstnumber_S+(MAXSUPERBURSTBEHIND(28 downto 0)&"00") < latestsuperburstnumber then  -- skip superburstnumbers if they are too far behind
							-- if latestsuperburstnumber>=(MAXSUPERBURSTBEHIND(28 downto 0)&"00") then
								-- actual_superburstnumber_S <= latestsuperburstnumber-(MAXSUPERBURSTBEHIND(28 downto 0)&"00");
							-- else
								-- actual_superburstnumber_S <= (others => '0');
							-- end if;
						-- else
							actual_superburstnumber_S <= actual_superburstnumber_p1_S;
--						end if;
					end if;
				when writefirstpacket => -- write first data in packet
					data64frommem_S <= '0';
					if data64_out_allowed='1' then -- check if allowed
						data64_out_S <= '0' & superburstnumber_S & x"00000000";
						data64_out_write_S <= '1';
						data64_out_first <= '1';
						data64_out_last <= '0';
						data64buf_S <= timestamp_S & timefraction_S & statusbyte_S & channel_S & energy_S; -- = 13+11+8+16+16
						data64buf_available_S <= '1';
						actual_superburstnumber_S <= superburstnumber_S;
						readinmode_S <= waitfornextdata;				
					end if;
				when waitfornextdata =>
					data64frommem_S <= '0';
					if data_in_read_after1clk_S='1' then
						if (superburst_new_error_S='0') then
							if superburstnumber=actual_superburstnumber_S then
								if data64buf_available_S='1' then
									if data64_out_allowed='1' then -- check if allowed
										data64_out_S <= data64buf_S;
										data64_out_write_S <= '1';
										data64_out_first <= '0';
										data64_out_last <= '0';
										data64buf_S <= timestamp_corr_S & timefraction_corr_S & statusbyte & channel & energy; -- = 13+11+8+16+16
										data64buf_available_S <= '1';
									else
										readinmode_S <= waitforallowed;
									end if;
								else
									data64buf_S <= timestamp_corr_S & timefraction_corr_S & statusbyte & channel & energy; -- = 13+11+8+16+16
									data64buf_available_S <= '1';
								end if;
							elsif superburstnumber=actual_superburstnumber_p1_S then -- write im mem
								data_in_memory_S <= '1';
								mem_write_enable_S <= '1';
								if mem_write_address_S(TRANSITIONBUFFERBITS-1 downto 1)=ones(TRANSITIONBUFFERBITS-1 downto 1) then -- cleanup all if memory full
									newdataavailable_S <= '1'; 
									if data64_out_allowed='1' then
										data64_out_S <= data64buf_S;
										data64_out_write_S <= '1';
										data64_out_first <= '0';
										data64_out_last <= '1';
										data64buf_available_S <= '0';
										readinmode_S <= cleanupmemoryfirst;
									else
										readinmode_S <= cleanupmemoryzero;
									end if;
								end if;
							elsif superburstnumber>actual_superburstnumber_p1_S then -- new superburst: cleanup all
								if data64buf_available_S='1' then
									newdataavailable_S <= '1'; 
									if data64_out_allowed='1' then
										data64_out_S <= data64buf_S;
										data64_out_write_S <= '1';
										data64_out_first <= '0';
										data64_out_last <= '1';
										data64buf_available_S <= '0';
										if data_in_memory_S='1' then
											readinmode_S <= cleanupmemoryfirst;
										else
											if superburstnumberrewind_S='1' then
												readinmode_S <= initialize;
											else
												readinmode_S <= waitforfirstpacket;
											end if;
										end if;
									else
										if data_in_memory_S='1' then
											readinmode_S <= cleanupmemoryzero;
										else
											readinmode_S <= waitforcleanupallowed;
										end if;
									end if;
								else
									if data_in_memory_S='1' then
										readinmode_S <= cleanupmemoryfirst;
									else
										if superburstnumberrewind_S='1' then
											readinmode_S <= initialize;
										else
											readinmode_S <= waitforfirstpacket;
										end if;
									end if;
								end if;
							end if;
						-- else
							-- if superburstnumber>=(MAXSUPERBURSTBEHIND(28 downto 0)&"00") then
								-- actual_superburstnumber_S <= latestsuperburstnumber-(MAXSUPERBURSTBEHIND(28 downto 0)&"00");
							-- else
								-- actual_superburstnumber_S <= (others => '0');
							-- end if;
						end if;
					else -- not data_in_read_after1clk_S
						if data64_out_allowed = '1' then
							if timeoutcounter_S(timeoutcounter_S'left)='1' then
								timeoutcounter_S <= (others => '0');
								if data64buf_available_S='1' then
									data64_out_S <= data64buf_S;
									data64_out_write_S <= '1';
									data64_out_first <= '0';
									data64_out_last <= '1';
									newdataavailable_S <= '0'; 
									data64buf_available_S <= '0';
								end if;
								if data_in_memory_S='1' then
									readinmode_S <= cleanupmemoryfirst;
								else
									if superburstnumberrewind_S='1' then
										readinmode_S <= initialize;
									else
										readinmode_S <= waitforfirstpacket;
									end if;
								end if;
							else						
								timeoutcounter_S <= timeoutcounter_S+1;
							end if;
						end if;
					end if;
				when waitforallowed =>
					data64frommem_S <= '0';
					if data64_out_allowed='1' then -- check if allowed
						data64_out_S <= data64buf_S;
						data64_out_write_S <= '1';
						data64_out_first <= '0';
						data64_out_last <= '0';
						data64buf_S <= timestamp_S & timefraction_S & statusbyte_S & channel_S & energy_S; -- = 13+11+8+16+16
						data64buf_available_S <= '1';
						readinmode_S <= waitfornextdata;
					end if;
				when waitforcleanupallowed =>
					data64frommem_S <= '0';
					if data64_out_allowed='1' then
						data64_out_S <= data64buf_S;
						data64_out_write_S <= '1';
						data64_out_first <= '0';
						data64_out_last <= '1';
						data64buf_available_S <= '0';
						if superburstnumberrewind_S='1' then
							readinmode_S <= initialize;
						else
							readinmode_S <= waitforfirstpacket;
						end if;
					end if;
				when cleanupmemoryzero =>
					data64frommem_S <= '0';
					if data64_out_allowed='1' then
						data64_out_S <= data64buf_S;
						data64_out_write_S <= '1';
						data64_out_first <= '0';
						data64_out_last <= '1';
						data64buf_available_S <= '0';
						readinmode_S <= cleanupmemoryfirst;
					end if;
				when cleanupmemoryfirst =>
					data64frommem_S <= '0';
					timeoutcounter_S <= (others => '0');
					data_in_memory_S <= '0';
					if data64_out_allowed = '1' then
						data64_out_S <= '0' & actual_superburstnumber_p1_S & x"00000000";
						data64_out_write_S <= '1';
						data64_out_first <= '1';
						data64_out_last <= '0';
						actual_superburstnumber_S <= actual_superburstnumber_p1_S;
						mem_read_address_now_S <= (others => '0');
						mem_read_address_plus1_S <= (others => '0');
						readinmode_S <= cleanupmemorynext;
					end if;
				when cleanupmemorynext =>
					mem_read_address_now_S <= mem_read_address_S;
					timeoutcounter_S <= (others => '0');
					data_in_memory_S <= '0';
					if data64_out_allowed = '1' then
						if mem_read_address_p1_S=mem_write_address_S then
							data64frommem_S <= '0';
							readinmode_S <= writelastdatafrommemory;
						else
							data64frommem_S <= '1';
							data64_out_write_S <= '1';
							data64_out_first <= '0';
							data64_out_last <= '0';
							mem_read_address_plus1_S <= mem_read_address_p1_S;
						end if;
					end if;
				when writelastdatafrommemory =>
					if newdataavailable_S='1' then
						if superburstnumber_S=actual_superburstnumber_p1_S then -- write new data in memory
							data64buf_S <= mem_timestamp_S & mem_timefraction_S & mem_statusbyte_S & mem_channel_S & mem_energy_S; -- = 13+11+8+16+16
							data64frommem_S <= '0';
							data64buf_available_S <= '1';	
							mem_write_enable_S <= '1';
							data_in_memory_S <= '1';
							newdataavailable_S <= '0';
							readinmode_S <= waitfornextdata;
						elsif superburstnumber_S=actual_superburstnumber_S then -- continue with current superburst
							data64buf_S <= mem_timestamp_S & mem_timefraction_S & mem_statusbyte_S & mem_channel_S & mem_energy_S; -- = 13+11+8+16+16
							data64frommem_S <= '0';
							data64buf_available_S <= '1';	
							mem_write_enable_S <= '0';
							data_in_memory_S <= '0';
							newdataavailable_S <= '0';
							readinmode_S <= waitfornextdata;
						else -- write last data in superburst packet
							if data64_out_allowed = '1' then
								data64frommem_S <= '1';
								data64_out_write_S <= '1';
								data64_out_first <= '0';
								data64_out_last <= '1';
								-- if (actual_superburstnumber_p2_S=superburstnumber_S) and (actual_superburstnumber_p2_S<=latestsuperburstnumber) then
									-- readinmode_S <= writefirstpacket; -- write the first data of the new packet
								-- else
									-- readinmode_S <= waitforfirstpacket;
								-- end if;
								readinmode_S <= writemissingpackets;
							end if;
						end if;
					else
						data64buf_S <= mem_timestamp_S & mem_timefraction_S & mem_statusbyte_S & mem_channel_S & mem_energy_S; -- = 13+11+8+16+16
						data64frommem_S <= '0';
						data64buf_available_S <= '1';	
						data_in_memory_S <= '0';
						readinmode_S <= waitfornextdata;
					end if;
			end case;
		end if;
	end if;
end process;	

debug_readinmode_S <=
	"0000" when readinmode_S=waitforfirstpacket else
	"0001" when readinmode_S=writesomemissingpackets else
	"0010" when readinmode_S=writemissingpackets else
	"0011" when readinmode_S=writefirstpacket else
	"0100" when readinmode_S=waitfornextdata else
	"0101" when readinmode_S=waitforallowed else
	"0110" when readinmode_S=waitforcleanupallowed else
	"0111" when readinmode_S=cleanupmemoryzero else
	"1000" when readinmode_S=cleanupmemoryfirst else
	"1001" when readinmode_S=cleanupmemorynext else
	"1010" when readinmode_S=writelastdatafrommemory else
	"1111";

	
process(clock)
begin
	if (rising_edge(clock)) then 
			
		if debug_readinmode_S/=debug_readinmodes_S(0) then
			for i in 1 to 7 loop
				debug_readinmodes_S(i) <= debug_readinmodes_S(i-1);
			end loop;
			debug_readinmodes_S(0) <= debug_readinmode_S;
		end if;
	end if;
end process;
			
testword0(35 downto 0) <= (others => '0');

end Behavioral;

