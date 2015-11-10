	----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   04-03-2011
-- Module Name:   DC_slowcontrol_packetbuilder
-- Description:   Puts the slow control command in packets for the fiber module
-- Modifications:
--   12-09-2014   New dataformat, name changed to DC_slowcontrol_packetbuilder, no boardnumber
--   08-10-2014   Initialize FEE registers, ending with status register read request
--   08-10-2014   Input-FIFO for slow control commands
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;
USE work.panda_package.all;

----------------------------------------------------------------------------------
-- DC_slowcontrol_packetbuilder
-- Makes a packet from a slowcontrol command
--
-- The slow control packets : 2 32-bit words, with CRC8 in last word
--   0x5C address(7..0) replybit 0000000 data(31..24)
--   data(23..0) CRC8(7..0)
-- The address is the lowest 8 bits of the 24-bits slowcontrol address, the other bits must by 0 for FEE access.
-- The request bit indicates that the FEE should replay with the contents of the sent address.
-- The command bit sends a data to the specified address
--
-- Library:
--     work.panda_package :  for type declarations and constants
--
-- Generics:
-- 
-- Inputs:
--     clock : clock input
--     reset : synchronous reset
--     init_FEE : start sending all stored commands to FEE
--     slowcontrol_data : slow-control command : data
--     slowcontrol_address : slow-control command : address
--     slowcontrol_request : indicates if this is a request for the contents of the specified address
--     slowcontrol_write : slow-control command : address
--     packet_fifofull : full signal from connected packet fifo
-- 
-- Outputs:
--     slowcontrol_allowed : module can accept data
--     packet_data_out : packet data 32 bits
--     packet_lastword :  last packet data word
--     packet_datawrite : packet_data_out valid
-- 
-- Components:
--     crc8_add_check32 : add (and checks) a CRC8 code to a stream of 32 bits data words
--     blockmem : memory to store slowcontrol commands
--     sync_fifo_512x41 : input fifo for slow control commands
--
----------------------------------------------------------------------------------

entity DC_slowcontrol_packetbuilder is
	port ( 
		clock                   : in std_logic;
		reset                   : in std_logic;
		init_FEE                : in  std_logic; 
		slowcontrol_data        : in std_logic_vector (31 downto 0);
		slowcontrol_address     : in std_logic_vector (23 downto 0);
		slowcontrol_request     : in std_logic;
		slowcontrol_write       : in std_logic; 
		slowcontrol_allowed     : out std_logic; 
		packet_data_out         : out std_logic_vector (31 downto 0);
		packet_lastword         : out std_logic;
		packet_datawrite        : out std_logic;
		packet_fifofull         : in std_logic
	);		
end DC_slowcontrol_packetbuilder;

architecture Behavioral of DC_slowcontrol_packetbuilder is

component crc8_add_check32 is 
   PORT(           
		clock              : in  std_logic; 
		reset              : in  std_logic; 
		data_in            : in  std_logic_vector(31 DOWNTO 0); 
		data_in_valid      : in  std_logic; 
		data_in_last       : in  std_logic; 
		data_out           : out std_logic_vector(31 DOWNTO 0); 
		data_out_valid     : out std_logic;
		data_out_last      : out std_logic;
		crc_error          : out std_logic
	);
end component; 

component blockmem is
	generic (
		ADDRESS_BITS : natural := 8;
		DATA_BITS  : natural := 34
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

component sync_fifo_512x41 is
port (
		rst                     : in std_logic;
		clk                     : in std_logic;
		din                     : in std_logic_vector(40 downto 0);
		wr_en                   : in std_logic;
		rd_en                   : in std_logic;
		dout                    : out std_logic_vector(40 downto 0);
		full                    : out std_logic;
		empty                   : out std_logic
	);
end component;

type tx_state_type is (init,idle,slow1,init_FEE0,init_FEE1,init_FEE2,init_FEE3,init_FEE4,init_FEE5);
signal tx_state_S                   : tx_state_type := init;

signal slowcontrol_data_S           : std_logic_vector (31 downto 0);
signal slowcontrol_data_buf_S       : std_logic_vector (31 downto 0);
signal slowcontrol_address_S        : std_logic_vector (7 downto 0);
signal slowcontrol_request_S        : std_logic := '0';
signal fifo_write_S                 : std_logic := '0';
signal fifo_read_S                  : std_logic := '0';
signal fifo_full_S                  : std_logic := '0';
signal fifo_empty_S                 : std_logic := '0';
signal fifo_read_aftr1clk_S         : std_logic := '0';

signal crc8_data_in_S               : std_logic_vector (31 downto 0);
signal crc8_reset_S                 : std_logic := '0';
signal crc8_clear_S                 : std_logic := '0';
signal crc8_data_in_valid_S         : std_logic := '0';
signal crc8_data_in_last_S          : std_logic := '0';
signal crc8_writeword_S             : std_logic := '0';
signal crc8_data_out_valid_S        : std_logic := '0';
signal prev_crc8_data_out_valid_S   : std_logic := '0';
signal crc8_data_out_last_S         : std_logic := '0';
signal prev_crc8_data_out_last_S    : std_logic := '0';

signal init_FEE_S                   : std_logic := '0';
signal start_init_FEE_S             : std_logic := '0';
signal mem_write_S                  : std_logic := '0';
signal mem_data_in_S                : std_logic_vector (33 downto 0);
signal mem_data_out_S               : std_logic_vector (33 downto 0);
signal mem_read_address_S           : std_logic_vector (7 downto 0);


begin

slowcontrol_allowed <= '1' when fifo_full_S='0' else '0';
		
inputfifo: sync_fifo_512x41 port map(
		rst => reset,
		clk => clock,
		din(31 downto 0) => slowcontrol_data,
		din(39 downto 32) => slowcontrol_address(7 downto 0),
		din(40) => slowcontrol_request,
		wr_en => fifo_write_S,
		rd_en => fifo_read_S,
		dout(31 downto 0) => slowcontrol_data_S,
		dout(39 downto 32) => slowcontrol_address_S,
		dout(40) => slowcontrol_request_S,
		full => fifo_full_S,
		empty => fifo_empty_S);
fifo_write_S <= '1' when (slowcontrol_write='1') and (slowcontrol_address(23 downto 8)=x"0000") else '0';
fifo_read_S <= '1' when  (tx_state_S=idle) and (fifo_empty_S='0') else '0';

crc8_data_in_valid_S <= '1' when (crc8_writeword_S='1') and (packet_fifofull='0') else '0';
crc8_reset_S <= '1' when (crc8_clear_S='1') or (reset='1') else '0';
crc8check: crc8_add_check32 port map(
	clock => clock,
	reset => crc8_reset_S,
	data_in => crc8_data_in_S,
	data_in_valid => crc8_data_in_valid_S,
	data_in_last => crc8_data_in_last_S, 
	data_out => packet_data_out,
	data_out_valid => crc8_data_out_valid_S,
	data_out_last => crc8_data_out_last_S,
	crc_error => open); -- only generate, no check

	  
packet_datawrite <= '1' when ((crc8_data_out_valid_S='1') and (packet_fifofull='0')) or 
		((prev_crc8_data_out_valid_S='1') and (packet_fifofull='0')) else '0';
packet_lastword <= '1' when (crc8_data_out_last_S='1') or (prev_crc8_data_out_last_S='1') else '0';

crc8_process: process(clock) -- process to freeze output of crc8 in case of packet_fifofull
begin
	if rising_edge(clock) then
		if reset='1' then
			prev_crc8_data_out_valid_S <= '0';
			prev_crc8_data_out_last_S <= '0';
		else
			if ((crc8_data_out_valid_S='1') and (packet_fifofull='1')) then
				prev_crc8_data_out_valid_S <= '1';
				prev_crc8_data_out_last_S <= crc8_data_out_last_S;
			elsif ((crc8_data_out_valid_S='1') and (packet_fifofull='0')) then
				prev_crc8_data_out_valid_S <= '0';
				prev_crc8_data_out_last_S <= '0';
			elsif ((crc8_data_out_valid_S='0') and (packet_fifofull='0')) then
				prev_crc8_data_out_last_S <= '0';
				prev_crc8_data_out_valid_S <= '0';
			elsif ((crc8_data_out_valid_S='0') and (packet_fifofull='1')) then
			end if;				
		end if;
	end if;
end process;

blockmem1: blockmem port map(
	clock => clock,
	write_enable => mem_write_S,
	write_address => slowcontrol_address_S(7 downto 0),
	data_in => mem_data_in_S,
	read_address => mem_read_address_S,
	data_out => mem_data_out_S);
	
mem_write_S <= fifo_read_aftr1clk_S;
mem_data_in_S(33) <= '1';
mem_data_in_S(32) <= slowcontrol_request_S;
mem_data_in_S(31 downto 0) <= slowcontrol_data_S;

slowcontrolhandling_process: process(clock)
variable counter_V : integer range 0 to 3;
begin
	if (rising_edge(clock)) then 
		if (reset = '1') then 
			crc8_data_in_last_S <= '0';
			crc8_writeword_S <= '0';
			crc8_clear_S <= '1'; -- clear crc
			tx_state_S <= idle;
		else
			if (init_FEE='1') and (init_FEE_S='0') then
				start_init_FEE_S <= '1';
			end if;
			case tx_state_S is
				when init =>
					crc8_data_in_last_S <= '0';
					crc8_writeword_S <= '0';
					crc8_clear_S <= '1'; -- clear crc
					tx_state_S <= idle;
				when idle =>
					mem_read_address_S <= (others => '0');
					if (crc8_writeword_S='1') and (crc8_data_in_valid_S='0') then -- unsuccessfull write
						crc8_writeword_S <= '1';
						tx_state_S <= idle;
						crc8_clear_S <= '0';
					else
						if (fifo_read_aftr1clk_S='1') then -- only addresses 0..255
							crc8_clear_S <= '0';
							slowcontrol_data_buf_S <= slowcontrol_data_S;
							crc8_data_in_S <= x"5c" & slowcontrol_address_S & slowcontrol_request_S & "0000000" & slowcontrol_data_S(31 downto 24);
							crc8_data_in_last_S <= '0';
							crc8_writeword_S <= '1';
							tx_state_S <= slow1;
						else
							crc8_clear_S <= '0'; -- no clear crc ??????????
							crc8_data_in_last_S <= '0';
							crc8_writeword_S <= '0';
							if start_init_FEE_S='1' then
								tx_state_S <= init_FEE0;
								start_init_FEE_S <= '0';
							else
								tx_state_S <= idle;			
							end if;
						end if;
					end if;
				when slow1 =>
					crc8_clear_S <= '0';
					if (crc8_writeword_S='1') and (crc8_data_in_valid_S='0') then -- unsuccessfull write
						crc8_writeword_S <= '1';
					else
						crc8_data_in_S <= slowcontrol_data_buf_S(23 downto 0) & x"00";
						crc8_data_in_last_S <= '1';
						crc8_writeword_S <= '1';
						tx_state_S <= idle;
					end if;
				when init_FEE0 =>
					crc8_clear_S <= '0';
					if (crc8_writeword_S='1') and (crc8_data_in_valid_S='0') then -- unsuccessfull write
						crc8_writeword_S <= '1';
						tx_state_S <= idle;
					else
						if (mem_data_out_S(33)='1') then -- address valid then
							crc8_data_in_S <= x"5c" & mem_read_address_S & x"00" & mem_data_out_S(31 downto 24); -- no request
							crc8_data_in_last_S <= '0';
							crc8_writeword_S <= '1';
							tx_state_S <= init_FEE1;
						else
							crc8_writeword_S <= '0';
							if conv_integer(unsigned(mem_read_address_S))<FEESLOWCONTROLADRESSES then
								mem_read_address_S <= mem_read_address_S+1;
								tx_state_S <= init_FEE3;
							else
								tx_state_S <= init_FEE4;
							end if;
						end if;
					end if;
				when init_FEE1 =>
					crc8_clear_S <= '0';
					if (crc8_writeword_S='1') and (crc8_data_in_valid_S='0') then -- unsuccessfull write
						crc8_writeword_S <= '1';
					else
						crc8_data_in_S <= mem_data_out_S(23 downto 0) & x"00";
						crc8_data_in_last_S <= '1';
						crc8_writeword_S <= '1';
						if conv_integer(unsigned(mem_read_address_S))<FEESLOWCONTROLADRESSES then
							mem_read_address_S <= mem_read_address_S+1;
							tx_state_S <= init_FEE2;
						else
							tx_state_S <= init_FEE4;
						end if;
					end if;
					counter_V := 0;
				when init_FEE2 => -- wait 1 clock for memory output
					crc8_clear_S <= '0';
					if (crc8_writeword_S='1') and (crc8_data_in_valid_S='0') then -- unsuccessfull write
						crc8_writeword_S <= '1';
					else
						crc8_writeword_S <= '0';
					end if;
					if counter_V<3 then
						counter_V := counter_V+1;
					else
						tx_state_S <= init_FEE0;
					end if;
				when init_FEE3 => -- wait 1 clock for memory output
					crc8_clear_S <= '0';
					if (crc8_writeword_S='1') and (crc8_data_in_valid_S='0') then -- unsuccessfull write
						crc8_writeword_S <= '1';
					else
						crc8_writeword_S <= '0';
					end if;
					tx_state_S <= init_FEE0;
				when init_FEE4 => 
					crc8_clear_S <= '0';
					if (crc8_writeword_S='1') and (crc8_data_in_valid_S='0') then -- unsuccessfull write
						crc8_writeword_S <= '1';
					else
						crc8_data_in_S <= x"5c" & ADDRESS_FEE_STATUS & x"80" & x"00"; -- request
						crc8_data_in_last_S <= '0';
						crc8_writeword_S <= '1';
						tx_state_S <= init_FEE5;
					end if;
				when init_FEE5 => 
					crc8_clear_S <= '0';
					if (crc8_writeword_S='1') and (crc8_data_in_valid_S='0') then -- unsuccessfull write
						crc8_writeword_S <= '1';
					else
						crc8_data_in_S <= x"00000000"; -- data=0
						crc8_data_in_last_S <= '1';
						crc8_writeword_S <= '1';
						tx_state_S <= idle;
					end if;
				when others =>
					crc8_clear_S <= '0';
					crc8_data_in_last_S <= '0';
					crc8_writeword_S <= '0';
					tx_state_S <= init;
			end case;
			fifo_read_aftr1clk_S <= fifo_read_S;
			init_FEE_S <= init_FEE;
		end if;
	end if;
end process;

end Behavioral;
