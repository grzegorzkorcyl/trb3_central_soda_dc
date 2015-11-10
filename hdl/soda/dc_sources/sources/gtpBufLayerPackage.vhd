--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions 


library IEEE;
use IEEE.STD_LOGIC_1164.all;

package gtpBufLayer is

constant KCHAR280        : std_logic_vector(7 downto 0) := "00011100"; -- 1C
constant KCHAR281        : std_logic_vector(7 downto 0) := "00111100"; -- 3C
constant KCHAR285        : std_logic_vector(7 downto 0) := "10111100"; -- BC
--constant KCHAR277        : std_logic_vector(7 downto 0) := "11111011"; -- FB
constant KCHAR286        : std_logic_vector(7 downto 0) := x"DC";

constant KCHARIDLE       : std_logic_vector(15 downto 0) := KCHAR281 & KCHAR285;  -- 3CBC peter: bytes different for word sync
constant KCHARSODASTART  : std_logic_vector(15 downto 0) := KCHAR280 & KCHAR280;  -- 1C1C
constant KCHARSODASTOP   : std_logic_vector(15 downto 0) := KCHAR281 & KCHAR281;  -- 3C3C
constant KCHARSODA       : std_logic_vector(7 downto 0) := KCHAR286;  -- DC


end gtpBufLayer;
