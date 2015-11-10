----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   22-02-2011
-- Module Name:   crc8_add_check64 
-- Description:   Add and checks a CRC8 code to a stream of 64 bits data words
----------------------------------------------------------------------------------
                   
LIBRARY IEEE ;
USE ieee.std_logic_1164.all ;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;

----------------------------------------------------------------------------------
-- crc8_add_check64
-- Checks and adds a CRC8 code to a stream of 64 bits data words.
-- This module can be used to add a CRC8 code and/or checks the CRC8 code.
-- 
-- The last byte (that is LSB of the 64-bits word) filled with the CRC8 code,
-- overwriting the original data, and this original data is compared with the
-- CRC8 code. If they are not the same the crc_error output bit is high.
-- The CRC8 is calculated on all 64-bits data words, with the LSB of the last word
-- set to "00000000";
-- The CRC8 code is calculated with initialize code "00000000".
-- An explanation can be found at www.ElectronicDesignworks.com
--
-- Library:
-- 
-- Generics:
-- 
-- Inputs:
--     clock : one clock is used
--     reset : synchronous reset
--     data_in : 64 bits data input, LSB last byte is CRC8 or becomes CRC8
--     data_in_valid : data_in word is valid
--     data_in_last : last data in the 64-bits stream; contains or will contain CRC8
-- 
-- Outputs:
--     data_out : 64 bits data output, LSB last byte is CRC8
--     data_out_valid : data_in word is valid
--     data_out_last : last data in the 64-bits stream; contains CRC8
--     crc_error : CRC8 code in original data_in was wrong, 
--                 can be ignored if the module is used to add a CRC8
-- 
----------------------------------------------------------------------------------
entity crc8_add_check64 is 
   port(           
		clock                   : in  std_logic; 
		reset                   : in  std_logic; 
		data_in                 : in  std_logic_vector(63 downto 0); 
		data_in_valid           : in  std_logic; 
		data_in_last            : in  std_logic; 
		data_out                : out std_logic_vector(63 downto 0); 
		data_out_valid          : out std_logic;
		data_out_last           : out std_logic;
		crc_error               : out std_logic
	);
end crc8_add_check64; 

architecture behaviour OF crc8_add_check64 IS 
	constant	CRC_INIT          : std_logic_vector(7 downto 0) := "00000000"; 
	signal crc_S               : std_logic_vector(7 downto 0) := "00000000";
	signal crc_aftr1clk_S      : std_logic_vector(7 downto 0) := "00000000";
	signal crc_feedback_S      : std_logic_vector(7 downto 0) := "00000000";
	signal start_on_next_S     : std_logic := '0'; 
	signal din_S               : std_logic_vector(63 downto 0);
	
begin 

crc_feedback_S <= CRC_INIT when ((start_on_next_S='1') and (data_in_valid='1')) else crc_aftr1clk_S;

din_S(63 downto 8) <= data_in(63 downto 8);
din_S(7 downto 0) <= data_in(7 downto 0) when data_in_last='0' else (others => '0');



crc_S(0) <= din_S(0) XOR din_S(1) XOR din_S(9) XOR din_S(18) XOR din_S(27) XOR din_S(36) XOR 
	din_S(45) XOR din_S(54) XOR din_S(63) XOR crc_feedback_S(7) XOR din_S(10) XOR din_S(19) XOR 
	din_S(28) XOR din_S(37) XOR din_S(46) XOR din_S(55); 
crc_S(1) <= din_S(0) XOR din_S(2) XOR din_S(11) XOR din_S(20) XOR din_S(29) XOR din_S(38) XOR 
	din_S(47) XOR din_S(56) XOR crc_feedback_S(0) XOR din_S(9) XOR din_S(18) XOR din_S(27) XOR 
	din_S(36) XOR din_S(45) XOR din_S(54) XOR din_S(63) XOR crc_feedback_S(7); 
crc_S(2) <= din_S(0) XOR din_S(3) XOR din_S(12) XOR din_S(21) XOR din_S(30) XOR din_S(39) XOR 
	din_S(48) XOR din_S(57) XOR crc_feedback_S(1) XOR din_S(9) XOR din_S(18) XOR din_S(27) XOR 
	din_S(36) XOR din_S(45) XOR din_S(54) XOR din_S(63) XOR crc_feedback_S(7); 
crc_S(3) <= din_S(0) XOR din_S(4) XOR din_S(13) XOR din_S(22) XOR din_S(31) XOR din_S(40) XOR 
	din_S(49) XOR din_S(58) XOR crc_feedback_S(2) XOR din_S(9) XOR din_S(18) XOR din_S(27) XOR 
	din_S(36) XOR din_S(45) XOR din_S(54) XOR din_S(63) XOR crc_feedback_S(7); 
crc_S(4) <= din_S(0) XOR din_S(5) XOR din_S(14) XOR din_S(23) XOR din_S(32) XOR din_S(41) XOR 
	din_S(50) XOR din_S(59) XOR crc_feedback_S(3) XOR din_S(9) XOR din_S(18) XOR din_S(27) XOR 
	din_S(36) XOR din_S(45) XOR din_S(54) XOR din_S(63) XOR crc_feedback_S(7); 
crc_S(5) <= din_S(0) XOR din_S(6) XOR din_S(15) XOR din_S(24) XOR din_S(33) XOR din_S(42) XOR 
	din_S(51) XOR din_S(60) XOR crc_feedback_S(4) XOR din_S(9) XOR din_S(18) XOR din_S(27) XOR 
	din_S(36) XOR din_S(45) XOR din_S(54) XOR din_S(63) XOR crc_feedback_S(7); 
crc_S(6) <= din_S(0) XOR din_S(7) XOR din_S(16) XOR din_S(25) XOR din_S(34) XOR din_S(43) XOR 
	din_S(52) XOR din_S(61) XOR crc_feedback_S(5) XOR din_S(9) XOR din_S(18) XOR din_S(27) XOR 
	din_S(36) XOR din_S(45) XOR din_S(54) XOR din_S(63) XOR crc_feedback_S(7); 
crc_S(7) <= din_S(0) XOR din_S(8) XOR din_S(17) XOR din_S(26) XOR din_S(35) XOR din_S(44) XOR 
	din_S(53) XOR din_S(62) XOR crc_feedback_S(6) XOR din_S(9) XOR din_S(18) XOR din_S(27) XOR 
	din_S(36) XOR din_S(45) XOR din_S(54) XOR din_S(63) XOR crc_feedback_S(7); 


crc_process : process(clock, reset) 
begin
	if (rising_edge(clock)) then 
		if (reset = '1') then 
			crc_error <= '0';                             
			start_on_next_S <= '1';
			data_out_valid <= '0';
			data_out_last <= '0';
			crc_aftr1clk_S <= "00000000" ;
		else
			if (data_in_valid = '1') then
				crc_aftr1clk_S <= crc_S;
				data_out_valid <= '1';
				if (data_in_last = '1') then 
					start_on_next_S <= '1';
					data_out_last <= '1';
					data_out(63 downto 8) <= data_in(63 downto 8);
					data_out(7 downto 0) <= crc_S;
					if crc_S/=data_in(7 downto 0) then
						crc_error <= '1';
					else
						crc_error <= '0';                             
					end if;
				else
					data_out(63 downto 0) <= data_in(63 downto 0);
					start_on_next_S <= '0';     
					crc_error <= '0';                             
					data_out_last <= '0';
				end if;
			else
				crc_error <= '0';                             
				data_out_valid <= '0';
				data_out_last <= '0';
			end if; 
		end if;
	end if;    
end process crc_process; 


end behaviour;
                      





 



