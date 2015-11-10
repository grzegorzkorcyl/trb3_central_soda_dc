	----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   21-03-2011
-- Module Name:   DC_slowcontrol_receive_from_cpu
-- Description:   Module to receive slowcontrol data from soft-core cpu to fiber modules
-- Modifications:
--   12-09-2014   Name changed to DC_slowcontrol_receive_from_cpu
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;

----------------------------------------------------------------------------------
-- DC_slowcontrol_receive_from_cpu
-- Module to receive byte-wise data from soft-core cpu and translates it into parallel slowcontrol data.
-- The byte-wise input data is sent to all fibermodules as packets of 8 bytes.
-- The first packet determines which fiber should sent this data and if it is a read action:
--         Byte0 : Read bit , "000", index of the fiber 
--         Byte1,2,3,4 : alternating: 
--                     request-bit 101 xxxx 24-bits_address(MSB first)
--                     32-bits_data, MSB first
-- The output of the module is parallel slowcontrol address and data and request bit
--
-- Library:
-- 
-- Generics:
-- 
-- Inputs:
--     clock : clock input and output
--     reset : synchronous reset 
--     channel : index of the fiber
--     IO_byte : 5-byte slowcontrol:
--         Byte0 : Read bit , "000", index of the fiber 
--         Byte1,2,3,4 : alternating: 
--                     request-bit 101 xxxx 24-bits_address(MSB first)
--                     32-bits_data, MSB first
--     IO_write : write signal for byte-data, only selected fiber (with index in first byte equals channel) should read
--     slowcontrol_fifofull : fifofull signal for slow-control write to fibermodule
-- 
-- Outputs:
--     slowcontrol_data : slowcontrol parallel command : data (32 bits)
--     slowcontrol_address : slowcontrol parallel command : address (24 bits)
--     slowcontrol_request : slowcontrol parallel command : request (1 bit)
--     slowcontrol_write : write signal for slowcontrol parallel command
--     error : error: connected fifo full, or incomplete data burst
-- 
-- Components:
--
----------------------------------------------------------------------------------

entity DC_slowcontrol_receive_from_cpu is
	port ( 
		clock                   : in std_logic;
		reset                   : in std_logic;
		channel                 : in std_logic_vector (3 downto 0);
		IO_byte                 : in std_logic_vector(7 downto 0);
		IO_write                : in std_logic;
		slowcontrol_data        : out std_logic_vector (31 downto 0);
		slowcontrol_address     : out std_logic_vector (23 downto 0);
		slowcontrol_request     : out std_logic;
		slowcontrol_write       : out std_logic; 
		slowcontrol_fifofull    : in std_logic; 
		error                   : out std_logic
		);
end DC_slowcontrol_receive_from_cpu;

architecture Behavioral of DC_slowcontrol_receive_from_cpu is

type array8bits_type is array(0 to 3) of std_logic_vector(7 downto 0);

signal bytedata_S             : array8bits_type := (others => (others => '0'));
signal byteaddress_S          : array8bits_type := (others => (others => '0'));
signal byte_idx_S             : integer range 0 to 4 := 0;
signal selected_S             : std_logic := '0';
signal slowcontrol_write_S    : std_logic := '0';
signal expect_data_S          : std_logic := '0';
signal error1_S               : std_logic := '0';

begin

slowcontrol_write <= slowcontrol_write_S;
error <= '1' when ((slowcontrol_write_S='1') and (slowcontrol_fifofull='1')) or (error1_S='1') else '0';

slowcontrol_request <= byteaddress_S(0)(7);
slowcontrol_address <= byteaddress_S(1) & byteaddress_S(2) & byteaddress_S(3);
slowcontrol_data <=  bytedata_S(0) & bytedata_S(1) & bytedata_S(2)& bytedata_S(3);

rd_process: process(clock)
begin
	if (rising_edge(clock)) then 
		if reset='1' then
			byte_idx_S <= 0;
			slowcontrol_write_S <= '0';
			selected_S <= '0';
			expect_data_S <= '0';
			error1_S <= '0';
		else
			if byte_idx_S=0 then
				slowcontrol_write_S <= '0';
				error1_S <= '0';
				if (IO_write='1') and (IO_byte(7)='0') then
					if (IO_byte(3 downto 0)=channel) then
						selected_S <= '1';
						bytedata_S(0) <= IO_byte;
					else
						selected_S <= '0';
					end if;
					byte_idx_S <= 1;
				else
					selected_S <= '0';
				end if;
			else
				if (IO_write='1')  then
					error1_S <= '0';
					if selected_S='1' then
						if expect_data_S='1' then
							bytedata_S(byte_idx_S-1) <= IO_byte;
						else
							byteaddress_S(byte_idx_S-1) <= IO_byte;
						end if;
					end if;
					if byte_idx_S<4 then
						byte_idx_S <= byte_idx_S + 1;
						slowcontrol_write_S <= '0';
					else
						if expect_data_S='1' then
							slowcontrol_write_S <= selected_S;
							expect_data_S <= '0';
						else
							if byteaddress_S(0)(6 downto 4)="101" then
								expect_data_S <= '1';
							else -- error
								expect_data_S <= '0';
							end if;
						end if;
						byte_idx_S <= 0;
					end if;
				else -- error
					error1_S <= '1';
					slowcontrol_write_S <= '0';
					expect_data_S <= '0';
					byte_idx_S <= 0;
				end if;
			end if;
		end if;
	end if;
end process;
					
end Behavioral;
