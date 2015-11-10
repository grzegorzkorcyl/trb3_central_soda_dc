----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   04-03-2011
-- Module Name:   SODA command generator
-- Description:   Generates Panda SODA commands for testing and simulations
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;
USE ieee.math_real.all;
USE work.panda_package.all;

----------------------------------------------------------------------------------
-- SODA_packet_generator
-- Generates SODA (Synchronization Of Data Acquisition) packets for Panda
-- These commands are used to synchronize all modules and send time-information about the bundel
-- The packets will be synchronised to a 155.52 MHz clock.
-- Because the data is normally 16-bits and the final ADC-clock will be the SODA clock divided by 3
-- the generated packets are put on multiple of 6-clock cycles.
-- The SODA packets includes begin and end k-characters (see work.panda_package).
-- The width is 16 bits data and a bit that indicates the k-character is also sent.
--
-- There are two types of SODA packets: a 32-bit one and a 64-bit one.
-- The first word contains Hamming code plus parity.
--
-- SODA 32-bit packet : Control packet = 4 bytes:
--   P32 JTAG_TMS JTAG_TCK JTAG_TDI spare spare id="00" 
--   spare(3..0) DisableDataTaking EnableDataTaking StopRun ResetToZero
--   P16 GatedReadOut NU StartSuperburst TimeOffset(3..0) 
--   P8 EndOfBurst StartOfBurst P4 GlobalReset P2 P1
--
-- SODA 64-bit packet : Time Tag packet = 2 32-bits words:
--   P32 spare(4..0) id="01" TimeWithinBurst(7..0) P16 spare(6..0) P8 spare(2..0) P4 spare P2 P1
--   SuperBurstNumber(23..0) BurstNumber(7..0)
--
-- Library
--     work.panda_package :  for type declarations and constants
--
-- Generics:
--     SUPERBURSTTIME : period time in us, must be larger than 615
--     SODAPERIOD_IN_PS : Clock period of SODA clock in ps
--     SODACLOCKDIV : SODA Clock divider factor : 1,2 or 4 for 8,16 or 32 bits data
-- 
-- Inputs:
--     clock : clock input : SODA clock (155.52MHz divided by SODACLOCKDIV)
--     reset : synchronous reset
--     enable : enable sending of packets
--     reset_timestampcounter : sets the timestamp to zero
--     EnableDataTaking : sends packet with EnableDataTaking bit set
--     DisableDataTaking : sends packet with DisableDataTaking bit set
-- 
-- Outputs:
--     SMAs : test pins on SMA connector
--     packet_data_out : packet data 16 bits
--     packet_data_kchar : k-character data
--     packet_data_out_write : packet_data_out valid
--     packet_data_last :  last packet data word
-- 
-- Components:
--
----------------------------------------------------------------------------------

entity SODA_packet_generator is
	generic (
		SUPERBURSTTIME          : integer := 1000; -- time in us, must be larger than 615
		SODAPERIOD_IN_PS        : natural := 8000; -- SODA clock period in ps 155.52MHz=6430, 125MHz=8000
		SODACLOCKDIV            : natural := 2 -- 1,2,4 : SODA clock divide factor
	);
	port ( 
		clock                   : in std_logic; -- 155.52 MHz divided by SODACLOCKDIV
		reset                   : in std_logic;
		enable                  : in std_logic;
		reset_timestampcounter  : in std_logic;
		EnableDataTaking        : in std_logic;
		DisableDataTaking       : in std_logic;	
		SMAs                    : out std_logic_vector (1 downto 0);
		packet_data_out         : out std_logic_vector(15 downto 0);
		packet_data_kchar       : out std_logic;
		packet_data_out_write   : out std_logic;
		packet_data_last        : out std_logic
	);		
end SODA_packet_generator;

architecture Behavioral of SODA_packet_generator is

signal clock12_S              : std_logic := '0';
signal InitStartSuperBurst_S  : std_logic := '0';
signal StartSuperBurst_S      : std_logic := '0';
signal SuperBurstFinished_S   : std_logic := '0';
signal Burst_S                : std_logic := '0';
signal prev_Burst_S           : std_logic := '0';
signal SuperBurstNumber_S     : std_logic_vector(23 downto 0) := (others => '0');
signal BurstNumber_S          : std_logic_vector(7 downto 0) := (others => '0');
signal request_SODA64_packet1_S : std_logic := '0';

signal SODA64word1_S           : std_logic_vector(31 downto 0) := (others => '0');
signal SODA64word2_S           : std_logic_vector(31 downto 0) := (others => '0');
signal SODA32word_S            : std_logic_vector(31 downto 0) := (others => '0');

signal JTAG_TMS_S             : std_logic := '0';
signal JTAG_TCK_S             : std_logic := '0';
signal JTAG_TDI_S             : std_logic := '0';
signal StopRun_S              : std_logic := '0';
signal GatedReadOut_S         : std_logic := '0';
signal NU_S                   : std_logic := '0';
signal BufferReset_S          : std_logic := '0';
signal GlobalReset_S          : std_logic := '0';

signal TimeOffset_S           : std_logic_vector(8 downto 0) := (others => '0');

begin


div12process: process(clock)
variable counter12_V : integer range 0 to (12/SODACLOCKDIV)-1;
begin
	if (rising_edge(clock)) then 
		if (reset = '1') then 
			counter12_V := 0;
			clock12_S <= '0';
		else
			if counter12_V<((12/SODACLOCKDIV)-1) then
				counter12_V := counter12_V+1;
				clock12_S <= '0';
			else
				counter12_V := 0;
				clock12_S <= '1';
			end if;
		end if;
	end if;
end process;


superburstprocess: process(clock)
variable timecounter_V : integer := 0;
variable uscounter_V : integer := 0;
variable SODA64_delaycounter_V : integer range 0 to 31 := 31;
begin
	if (rising_edge(clock)) then 
		InitStartSuperBurst_S <= '0';
		if (reset = '1') then 
			timecounter_V := 0;
			uscounter_V := SUPERBURSTTIME;
			request_SODA64_packet1_S <= '0';
			SODA64_delaycounter_V := 31;
		elsif enable='1' then
		   timecounter_V := timecounter_V+(SODACLOCKDIV*SODAPERIOD_IN_PS); -- increment with ps
			if timecounter_V>=1000000 then -- after 2us
				timecounter_V := timecounter_V-1000000;
				if uscounter_V=SUPERBURSTTIME then
					InitStartSuperBurst_S <= '1';
					uscounter_V := 0;
				else
					uscounter_V := uscounter_V+1;
				end if;
			end if;
			if InitStartSuperBurst_S = '1' then
				SODA64_delaycounter_V := 0;
				request_SODA64_packet1_S <= '0';
			else
				if SODA64_delaycounter_V<30 then
					SODA64_delaycounter_V:=SODA64_delaycounter_V+1;
					request_SODA64_packet1_S <= '0';
				elsif SODA64_delaycounter_V=30 then
					request_SODA64_packet1_S <= '1';
					SODA64_delaycounter_V := 31;
				else
					SODA64_delaycounter_V := 31;
					request_SODA64_packet1_S <= '0';
				end if;
			end if;
		end if;
	end if;
end process;

burstprocess: process(clock)
variable timecounter_V : integer;
begin
	if (rising_edge(clock)) then 
		if (reset = '1') then 
			timecounter_V := 0;
			SuperBurstFinished_S <= '1';
			Burst_S <= '0';
			StartSuperBurst_S <= '0';
			BurstNumber_S <= (others => '0');
			SuperBurstNumber_S <= (others => '0');
		elsif InitStartSuperBurst_S='1' then
			timecounter_V := 0;
			BurstNumber_S <= (others => '0');
			SuperBurstNumber_S <= SuperBurstNumber_S+1;
			SuperBurstFinished_S <= '0';
			Burst_S <= '1';
			StartSuperBurst_S <= '1';
		elsif SuperBurstFinished_S='0' then
			StartSuperBurst_S <= '0';
		   timecounter_V := timecounter_V+(SODACLOCKDIV*SODAPERIOD_IN_PS); -- increment with ps
			if Burst_S = '1' then
				if timecounter_V>=2000000 then -- after 2us
					timecounter_V := timecounter_V-2000000;
					Burst_S <= '0';
				end if;
			else
				if timecounter_V>=400000 then -- after 0.4us
					timecounter_V := timecounter_V-400000;
					if BurstNumber_S=x"ff" then
						SuperBurstFinished_S <= '1';
						BurstNumber_S <= (others => '0');
						Burst_S <= '0';
					else
						BurstNumber_S <= BurstNumber_S+1;
						Burst_S <= '1';
					end if;
				end if;				
			end if;
		else -- wait for next
			StartSuperBurst_S <= '0';
			Burst_S <= '0';
		end if;
	end if;
end process;

makepacketprocess: process(clock)
variable pckt_V : std_logic_vector(31 downto 0);
variable make_SODA32_packet_V : integer range 0 to 5;
variable make_SODA64_packet_V : integer range 0 to 7;
variable StartOfBurst_V : std_logic := '0';
variable EndOfBurst_V : std_logic := '0';
variable ResetToZero_V : std_logic := '0';
variable DisableDataTaking_V : std_logic := '0';
variable EnableDataTaking_V : std_logic := '0';
variable StartSuperburst_V : std_logic := '0';
begin
	if (rising_edge(clock)) then 
		if (reset = '1') then 
			prev_Burst_S <= '0';
			StartOfBurst_V := '0';
			EndOfBurst_V := '0';
			make_SODA32_packet_V := 0;
			make_SODA64_packet_V := 0;
			packet_data_kchar <= '0';
			EnableDataTaking_V := '0';
			DisableDataTaking_V := '0';
			packet_data_out_write <= '0';
			TimeOffset_S <= (others => '0');
		else
			SMAs <= (others => '0');
			if (prev_Burst_S='0') and (Burst_S='1') and (enable='1') then -- start burst
				make_SODA32_packet_V := 1;
				StartSuperburst_V := StartSuperburst_S;
				StartOfBurst_V := '1';
				TimeOffset_S <= (others => '0');
			elsif (prev_Burst_S='1') and (Burst_S='0') and (enable='1') then -- end burst
				make_SODA32_packet_V := 1;
				EndOfBurst_V := '1';
				StartOfBurst_V := '0';
				TimeOffset_S <= TimeOffset_S+1;
			end if;
			if (request_SODA64_packet1_S='1') and  (enable='1') then
				make_SODA64_packet_V := 1;
			end if;
			if (reset_timestampcounter='1') and (enable='1') then
				make_SODA32_packet_V := 1;
				ResetToZero_V := '1';
			end if;
			if (EnableDataTaking = '1') and (enable='1') then
				make_SODA32_packet_V := 1;
				EnableDataTaking_V := '1';
			end if;
			if (DisableDataTaking = '1') and (enable='1') then
				make_SODA32_packet_V := 1;
				DisableDataTaking_V := '1';
			end if;
			if make_SODA64_packet_V=2 then
				packet_data_out <= SODA64word1_S(15 downto 0);
				packet_data_kchar <= '0';
				packet_data_out_write <= '1';		
				packet_data_last <= '0';
				make_SODA64_packet_V := 3;
			elsif make_SODA64_packet_V=3 then
				packet_data_out <= SODA64word1_S(31 downto 16);
				packet_data_kchar <= '0';
				packet_data_out_write <= '1';		
				packet_data_last <= '0';
				make_SODA64_packet_V := 4;
			elsif make_SODA64_packet_V=4 then
				packet_data_out <= SODA64word2_S(15 downto 0);
				packet_data_kchar <= '0';
				packet_data_out_write <= '1';		
				packet_data_last <= '0';
				make_SODA64_packet_V := 5;
			elsif make_SODA64_packet_V=5 then
				packet_data_out <= SODA64word2_S(31 downto 16);
				packet_data_kchar <= '0';
				packet_data_out_write <= '1';		
				packet_data_last <= '0';
				make_SODA64_packet_V := 6;
			elsif make_SODA64_packet_V=6 then
				packet_data_out <= KCHARSODASTOP;
				packet_data_kchar <= '1';
				packet_data_out_write <= '1';		
				packet_data_last <= '1';
				make_SODA64_packet_V := 7;
			elsif make_SODA64_packet_V=7 then
				packet_data_out <= (others => '0');
				packet_data_kchar <= '0';
				packet_data_out_write <= '0';		
				packet_data_last <= '0';
				make_SODA64_packet_V := 0;
			elsif make_SODA32_packet_V=2 then
				packet_data_out <= SODA32word_S(15 downto 0);
				packet_data_kchar <= '0';
				packet_data_out_write <= '1';		
				packet_data_last <= '0';
				make_SODA32_packet_V := 3;
			elsif make_SODA32_packet_V=3 then
				packet_data_out <= SODA32word_S(31 downto 16);
				packet_data_kchar <= '0';
				packet_data_out_write <= '1';					
				packet_data_last <= '0';
				make_SODA32_packet_V := 4;
			elsif make_SODA32_packet_V=4 then
				packet_data_out <= KCHARSODASTOP;  
				packet_data_kchar <= '1';
				packet_data_out_write <= '1';		
				packet_data_last <= '1';
				make_SODA32_packet_V := 5;
			elsif make_SODA32_packet_V=5 then
				packet_data_out <= (others => '0');  
				packet_data_kchar <= '0';
				packet_data_out_write <= '0';		
				packet_data_last <= '0';
				make_SODA32_packet_V := 0;
			elsif clock12_S='1' then
				if make_SODA32_packet_V=1 then
					pckt_V(31 downto 24) := "0" & JTAG_TMS_S & JTAG_TCK_S & JTAG_TDI_S & "00" & "00"; 
					pckt_V(23 downto 16) := "0000" & DisableDataTaking_V & EnableDataTaking_V & StopRun_S & ResetToZero_V; 
					pckt_V(15 downto 8) := "0" & GatedReadOut_S & NU_S & StartSuperburst_V &  TimeOffset_S(3 downto 0);
					pckt_V(7 downto 0) := "0" & EndOfBurst_V & StartOfBurst_V & BufferReset_S & "0" & GlobalReset_S & "00";
					SODA32word_S <= add_hamming_code_26_32(pckt_V);
					SMAs(0) <= StartOfBurst_V;
					SMAs(1) <= StartSuperburst_V; -- EndOfBurst_V;
					packet_data_out <= KCHARSODASTART;  
					packet_data_kchar <= '1';
					packet_data_out_write <= '1';
					packet_data_last <= '0';
					packet_data_last <= '1';
					EnableDataTaking_V := '0';
					DisableDataTaking_V := '0';
					StartOfBurst_V := '0';
					StartSuperburst_V := '0';
					EndOfBurst_V := '0';
					StartOfBurst_V := '0';
					ResetToZero_V := '0';
					make_SODA32_packet_V := 2;
				elsif make_SODA64_packet_V=1 then
					pckt_V(31 downto 24) := "0" & "00000" & "01"; 
					pckt_V(23 downto 16) := TimeOffset_S(8 downto 1); -- TimeOffset_S ; 
					pckt_V(15 downto 8) := "0" & "0000000";
					pckt_V(7 downto 0) := "0" & "000" & "0" & "0" & "00";
					SODA64word1_S <= add_hamming_code_26_32(pckt_V);
					SODA64word2_S(31 downto 8) <= SuperBurstNumber_S;
					SODA64word2_S(7 downto 0) <= BurstNumber_S;
					packet_data_out <= KCHARSODASTART;
					packet_data_kchar <= '1';
					packet_data_out_write <= '1';
					packet_data_last <= '0';
					packet_data_last <= '0';
					make_SODA64_packet_V := 2;
				else
					packet_data_kchar <= '0';
					packet_data_out_write <= '0';		
					packet_data_last <= '0';
				end if;
			else
				packet_data_kchar <= '0';
				packet_data_out_write <= '0';		
				packet_data_last <= '0';
			end if;
			prev_Burst_S <= Burst_S;
		end if;
	end if;
end process;

end Behavioral;
