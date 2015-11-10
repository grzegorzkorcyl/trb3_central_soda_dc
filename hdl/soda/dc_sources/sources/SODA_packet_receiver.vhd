----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   04-03-2011
-- Module Name:   SODA_packet_receiver
-- Description:   Receives and checks SODA packets
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;
USE work.panda_package.all;

----------------------------------------------------------------------------------
-- SODA_packet_receiver
-- Receives SODA (Synchronization Of Data Acquisition) packets for Panda
-- These SODA commands are used to synchronize all modules and send time-information about the bundel
-- The packets are synchronised to a 155.52 MHz clock.
--
-- There are two types of SODA packets: a 32-bit one and a 64-bit one.
-- The first word contains Hamming code plus parity.
--
-- SODA 32-bit packet : Control packet = 4 bytes:
--   P32 JTAG_TMS JTAG_TCK JTAG_TDI spare spare id="00" 
--   spare(3..0) DisableDataTaking EnableDataTaking StopRun ResetToZero
--   P16 GatedReadOut NU StartSuperburst TimeOffset(3..0) 
--   P8 EndOfBurst StartOfBurst BufferReset P4 GlobalReset P2 P1
--
-- SODA 64-bit packet : Time Tag packet = 2 32-bits words:
--   P32 spare(4..0) id="01" TimeWithinBurst(7..0) P16 spare(6..0) P8 spare(2..0) P4 spare P2 P1
--   SuperBurstNumber(23..0) BurstNumber(7..0)
--
-- Library
--     work.panda_package :  for type declarations and constants
--
-- Generics:
--     SODACLOCKDIV : SODA Clock divider factor : 1,2 or 4 for 8,16 or 32 bits data
-- 
-- Inputs:
--     clock : clock input : SODA clock (155.52MHz divided by SODACLOCKDIV)
--     reset : reset
--     enable : enable sending of packets
--     SODA_data : SODA packet data received
--     SODA_kchar : SODA packet data is k-character
--     SODA_data_present : SODA packet data received
--     clear_hamming_corrections : clear the counter for the hamming-code corrections
-- 
-- Outputs:
--     JTAG_TMS : Jtag TMS signal
--     JTAG_TCK : Jtag TCK signal
--     JTAG_TDI : Jtag TDI signal
--     DisableDataTaking : Disable Data Taking signal
--     EnableDataTaking :  Enable Data Taking signal
--     StopRun :  Stop Run signal
--     ResetToZero :  Reset timepstamp clock to zero
--     GatedReadOut :  Gated Read Out signal
--     NU :  NU signal
--     StartSuperburst :  Start Super Burst signal
--     TimeOffset : Offset of SODA packet in actual burst
--     EndOfBurst : End of Burst signal
--     StartOfBurst : Start of Burst signal
--     BufferReset :  Bufer Reset
--     GlobalReset :  Global Reset
--     error :  error in SODA packet detected
--     TimeWithinBurst : number of clock cycles inside the burst
--     BurstNumber : Index of the burst within a superburst
--     SuperBurstNumber : Index of the Superbursts
--     TimeTagValid : Data from Time Tag Packet is valid : TimeWithinBurst,BurstNumber,SuperBurstNumber
--     hamming_correction : pulse that indicates successful correction by the Hamming code
--     hamming_corrections : number of successful correction by the Hamming code
-- 
-- Components:
--     HammingDecode26_32 : Decodes Hamming code, (not clocked)
--
----------------------------------------------------------------------------------

entity SODA_packet_receiver is
	generic (
		SODACLOCKDIV : natural  := 2 -- 1,2,4 : SODA clock divide factor
	);
	port ( 
		clock                   : in std_logic; -- 155.52 MHz divided by SODACLOCKDIV
		reset                   : in std_logic;
		enable                  : in std_logic;
		SODA_data               : in std_logic_vector(15 downto 0);
		SODA_kchar              : in std_logic;
		SODA_data_present       : in std_logic;
		JTAG_TMS                : out std_logic;
		JTAG_TCK                : out std_logic;
		JTAG_TDI                : out std_logic;
		DisableDataTaking       : out std_logic;
		EnableDataTaking        : out std_logic;
		StopRun                 : out std_logic;
		ResetToZero             : out std_logic;
		GatedReadOut            : out std_logic;
		NU                      : out std_logic;
		StartSuperburst         : out std_logic;
		TimeOffset              : out std_logic_vector(3 downto 0);
		EndOfBurst              : out std_logic;
		StartOfBurst            : out std_logic;
		BufferReset             : out std_logic;
		GlobalReset             : out std_logic;
		TimeWithinBurst         : out std_logic_vector(7 downto 0);
		BurstNumber             : out std_logic_vector(7 downto 0);
		SuperBurstNumber        : out std_logic_vector(23 downto 0);
		TimeTagValid            : out std_logic;
		hamming_correction      : out std_logic;
		hamming_corrections     : out std_logic_vector (15 downto 0);
		clear_hamming_corrections : in std_logic;
		error                   : out std_logic);
end SODA_packet_receiver;




architecture Behavioral of SODA_packet_receiver is

component HammingDecode26_32 is
    Port ( 
		data_in                 : in  std_logic_vector (31 downto 0);
		data_out                : out  std_logic_vector (31 downto 0);
		corrected               : out  std_logic;
		error                   : out  std_logic);
end component;


signal reset_S                      : std_logic;
signal data_hamming_S               : std_logic_vector (31 downto 0);
signal data_hamming_corrected_S     : std_logic;
signal data_hamming_error_S         : std_logic;
signal hamming_corrections_S        : std_logic_vector (15 downto 0) := (others => '0');

signal SODA_data_S                  : std_logic_vector (31 downto 0) := (others => '0');
signal SODA_data_present_S          : std_logic := '0';

signal SODA_data_LSB_S              : std_logic_vector (15 downto 0) := (others => '0');
signal SODA_data_second16_S         : std_logic := '0';

signal SODA32_S                     : std_logic_vector (31 downto 0) := (others => '0');
signal SODA32_valid_S               : std_logic := '0';
signal expectsecond_S               : std_logic := '0';
signal TimeWithinBurst_S            : std_logic_vector (7 downto 0) := (others => '0');

begin

hammingdecoder : HammingDecode26_32 port map(
		data_in      => SODA_data_S,
		data_out     => data_hamming_S,
		corrected    => data_hamming_corrected_S,
		error        => data_hamming_error_S);
		
process16to32: process(clock)
begin
	if rising_edge(clock) then
		if (reset_S='1') then
			SODA_data_second16_S <= '0';
		else
			if SODA_data_second16_S='0' then
				if (SODA_data_present='1') and (SODA_kchar='0') then
					SODA_data_second16_S <= '1';
					SODA_data_LSB_S <= SODA_data;
				else
					SODA_data_second16_S <= '0';
				end if;
				SODA_data_present_S <= '0';
			else
				if (SODA_data_present='1') and (SODA_kchar='0') then
					SODA_data_S <=  SODA_data & SODA_data_LSB_S;
					SODA_data_present_S <= '1';
				else
					SODA_data_present_S <= '0';
				end if;
				SODA_data_second16_S <= '0';
			end if;
		end if;
		reset_S <= reset;
	end if;
end process;


-- counter for number of hamming code corrections		
hamming_correction_counter: process(clock)
begin
	if rising_edge(clock) then
		if (reset_S='1') or (clear_hamming_corrections='1') then
			hamming_corrections_S <= (others => '0');
			hamming_correction <= '0';
		else
			if (SODA_data_present_S='1') and (enable='1') and (expectsecond_S='0')
						and (data_hamming_corrected_S='1') then
				if (hamming_corrections_S /= x"ffff") then
					hamming_corrections_S <= hamming_corrections_S+1;
				end if;
				hamming_correction <= '1';
			else
				hamming_correction <= '0';
			end if;
		end if;
	end if;
end process;
hamming_corrections <= hamming_corrections_S;		

bitset32process: process(clock)
begin
	if (rising_edge(clock)) then 
		if (reset_S = '1') then 
			JTAG_TMS <= '0';
			JTAG_TCK <= '0';
			JTAG_TDI <= '0';
			TimeOffset <= "0000";
		elsif SODA32_valid_S='1' then
			JTAG_TMS <= SODA32_S(30);
			JTAG_TCK <= SODA32_S(29);
			JTAG_TDI <= SODA32_S(28);
			TimeOffset <= SODA32_S(11 downto 8);
		end if;
	end if;
end process;

	DisableDataTaking <= SODA32_S(19) when SODA32_valid_S='1' else '0';
	EnableDataTaking <= SODA32_S(18) when SODA32_valid_S='1' else '0';
	StopRun <= SODA32_S(17) when SODA32_valid_S='1' else '0';
	ResetToZero <= SODA32_S(16) when SODA32_valid_S='1' else '0';
	GatedReadOut <= SODA32_S(14) when SODA32_valid_S='1' else '0';
	NU <= SODA32_S(13) when SODA32_valid_S='1' else '0';
	StartSuperburst <= SODA32_S(12) when SODA32_valid_S='1' else '0';
	EndOfBurst <= SODA32_S(6) when SODA32_valid_S='1' else '0';
	StartOfBurst <= SODA32_S(5) when SODA32_valid_S='1' else '0';
	BufferReset <= SODA32_S(4) when SODA32_valid_S='1' else '0';
	GlobalReset <= SODA32_S(2) when SODA32_valid_S='1' else '0';


set64process: process(clock)
begin
	if (rising_edge(clock)) then 
		if (reset_S = '1') then 
			JTAG_TMS <= '0';
			JTAG_TCK <= '0';
			JTAG_TDI <= '0';
			TimeOffset <= "0000";
		elsif SODA32_valid_S='1' then
			JTAG_TMS <= SODA32_S(30);
			JTAG_TCK <= SODA32_S(29);
			JTAG_TDI <= SODA32_S(28);
			TimeOffset <= SODA32_S(11 downto 8);
		end if;
	end if;
end process;



packetreceiveprocess: process(clock)
variable expectsecondcounter_V : integer range 0 to 7; -- timeout counter for second word
begin
	if (rising_edge(clock)) then 
		if (reset_S = '1') then 
			SODA32_valid_S <= '0';
			expectsecond_S <= '0';
			error <= '0';
		elsif enable='0' then
			expectsecond_S <= '0';
			SODA32_valid_S <= '0';
			TimeTagValid <= '0';
			error <= '0';
		else
			if SODA_data_present_S='1' then
				if expectsecond_S = '0' then
					TimeTagValid <= '0';
					if data_hamming_error_S='1' then
						SODA32_valid_S <= '0';
						error <= '1';
					else
						if data_hamming_S(25 downto 24) = "00" then -- SODA32
							SODA32_S <= data_hamming_S;
							SODA32_valid_S <= '1';
							error <= '0';
						elsif data_hamming_S(25 downto 24) = "01" then -- SODA64
							expectsecondcounter_V:=0; 
							expectsecond_S <= '1';
							TimeWithinBurst_S <= data_hamming_S(23 downto 16);
							SODA32_valid_S <= '0';
							error <= '0';
						else
							error <= '1';
						end if;
					end if;
				else -- second word
					SuperBurstNumber <= SODA_data_S(31 downto 8);
					BurstNumber <= SODA_data_S(7 downto 0);
					TimeWithinBurst <= TimeWithinBurst_S;
					TimeTagValid <= '1';
					SODA32_valid_S <= '0';
					expectsecond_S <= '0';
				end if;
			else
				TimeTagValid <= '0';
				SODA32_valid_S <= '0';
				if expectsecond_S='1' then
					if expectsecondcounter_V<7 then
						expectsecondcounter_V := expectsecondcounter_V+1;
					else
						error <= '1';
						expectsecond_S <= '0';
					end if;
				end if;
			end if;
		end if;
	end if;
end process;


end Behavioral;
