----------------------------------------------------------------------------------
-- Company:       KVIcart/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   17-04-2014
-- Module Name:   DC_slow_control_TRB3
-- Description:   Slow control : TRBnet local bus to Data Concentrator registers/status
-- Modifications:
--   26-11-2014   name changed from MUX_slow_control_TRB3 to DC_slow_control_TRB3
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;

----------------------------------------------------------------------------------
-- DC_slow_control_TRB3
-- Module to translate TRBnet commands/reads to Panda Data Concentrator and Front End Electronics slowcontrol.
-- The Data Concentrator slowcontrol was previously done with a soft-core CPU (ZPU).
-- This is replaced by a TRBnet slave module, but the register access is still the same:
--    from processor (TRBnet or CPU)
--       write :
--          first 32 bits  = selection/address word : request-bit, "101", 4-bits fiber-indexnumber, 24 bits address 
--          second 32 bits = data word : 32 bits data 
--       read :
--          first 32 bits  = selection/address word : reply-bit, "101", 4-bits fiber-indexnumber, 24 bits address 
--          second 32 bits = data word : 32 bits data 
-- 
-- For TRBnet this implemented by using 4 TRBnet addresses :
--     bit(1..0)=00 write/read DC internal address, bit31=request, bit30..28=101, bit 27..24=fiber
--     bit(1..0)=01 write/read DC internal data
--     bit(1..0)=10 read status: bit0=readfifo data available, bit1= readfifo full
--     bit(1..0)=11 read fifo address or data
--
-- Writing slowcontrol to FEE and fiber connection parts are done byte wise.
-- Reading is initiated by the same byte command, but the data is returned serially, from each fiber.
-- The byte-wise data is sent to all fiber-modules, 2 times 5 bytes
-- The first byte of each 5 determines which fiber should accept this data and if it is a read action:
--         Byte0 : Read bit , "000", index of the fiber 
--         Byte1,2,3,4 : alternating: 
--                     request-bit 101 xxxx 24-bits_address(MSB first)
--                     32-bits_data, MSB first
-- The serials data that is returned will contain alternating adddress information and data information.
-- The transmission starts after the first IO_byte bit 7 is 1 and bits 3..0 corresponds with the channel number.
-- Then 32 bits data will be returned to the cpu, MSB first
--     first 5 bytes:
--       byte1=fibernumber
--       byte3..1, second address 
-- The address word has bit 30..28 set to 101 as check
--
-- Additional to the FEE and fiber slowcontrol there are several (NROFMUXREGS) 32-bits registers.
-- These registers are used for setting and reading the parameters in the Data Concentrator.
--
-- Library
--     work.panda_package :  for type declarations and constants
-- 
-- Generics:
-- 
-- Inputs:
--     rst : reset of all components
--     clk : clock input
--     BUS_READ_IN : TRBnet local bus read signal
--     BUS_WRITE_IN : TRBnet local bus write signal
--     BUS_ADDR_IN : TRBnet local bus address
--     BUS_DATA_IN : TRBnet local bus data
--     io_data_in : serial data : 32 bits:  bit31..0 : data, MSB first
--     IO_data_in_available : serial data is available
--     extract_data_available : pulse data is available for reading, used to set a status bit
--     extract_wave_available : waveform data is available for reading, used to set a status bit
--     board_status : registers contents from the Data Concentrator
-- 
-- Outputs:
--     BUS_BUSY_OUT : TRBnet local bus busy signal
--     BUS_ACK_OUT : TRBnet local bus acknowledge signal
--     BUS_DATA_OUT : TRBnet local bus data
--     io_data_out : 5-byte slowcontrol to fiber modules:
--         Byte0 : Read bit , "000", index of the fiber 
--         Byte1,2,3,4 : alternating: 
--                     request-bit 101 xxxx 24-bits_address(MSB first)
--                     32-bits_data, MSB first
--     io_write_out : write signal for byte-data, only selected fiber (with index in first byte equals channel) should read
--     board_status_read : read signals to read the registers contents from the Data Concentrator
--     board_control : registers for the parameters in the Data Concentrator
--     board_control_write : write signals to write to the registers in the Data Concentrator
-- 
-- Components:
--     async_fifo_512x32 : fifo buffer for the data from Data Concentrator to TRBnet
--
----------------------------------------------------------------------------------

library work;
use work.panda_package.all;

entity DC_slow_control_TRB3 is
	port(	
		rst                     : in std_logic;
		clk                     : in std_logic;
-- Slave bus
		BUS_READ_IN             : in   std_logic;
		BUS_WRITE_IN            : in   std_logic;
		BUS_BUSY_OUT            : out  std_logic;
		BUS_ACK_OUT             : out  std_logic;
		BUS_ADDR_IN             : in   std_logic_vector(1 downto 0);
		BUS_DATA_IN             : in   std_logic_vector(31 downto 0);
		BUS_DATA_OUT            : out  std_logic_vector(31 downto 0);

		io_data_in              : in std_logic_vector(0 to NROFFIBERS-1);
		IO_data_in_available    : in std_logic_vector(0 to NROFFIBERS-1);
		io_data_out             : out std_logic_vector(7 downto 0);
		io_write_out            : out std_logic;

		extract_data_available  : in std_logic;
		extract_wave_available  : in std_logic;

		board_status            : in array_muxregister_type;
		board_status_read       : out std_logic_vector(0 to NROFMUXREGS-1);
		board_control           : out array_muxregister_type;
		board_control_write     : out std_logic_vector(0 to NROFMUXREGS-1);
		testword0               : out std_logic_vector (35 downto 0) := (others => '0')
		);
end DC_slow_control_TRB3;

architecture Behavioral of DC_slow_control_TRB3 is

component async_fifo_512x32 is
port (
		rst                     : in std_logic;
		wr_clk                  : in std_logic;
		rd_clk                  : in std_logic;
		din                     : in std_logic_vector(31 downto 0);
		wr_en                   : in std_logic;
		rd_en                   : in std_logic;
		dout                    : out std_logic_vector(31 downto 0);
		full                    : out std_logic;
		empty                   : out std_logic
	);
end component;

-- Signals
type STATES is (SLEEP,RD_RDY,WR_RDY,RD_ACK,WR_ACK,DONE);
signal CURRENT_STATE, NEXT_STATE: STATES;

-- slave bus signals
signal bus_ack_x                     : std_logic;
signal bus_ack                       : std_logic;
signal store_wr_x                    : std_logic;
signal store_wr                      : std_logic;
signal store_rd_x                    : std_logic;
signal store_rd                      : std_logic;
signal buf_bus_data_out              : std_logic_vector(31 downto 0);

signal board_control_S               : array_muxregister_type := (others => (others => '0'));
signal address_register_i            : std_logic_vector(31 downto 0);
signal address_register_copy_i       : std_logic_vector(31 downto 0);
signal data_register_i               : std_logic_vector(31 downto 0);
signal board_status_read_i           : std_logic_vector(0 to NROFMUXREGS-1) := (others => '0');
signal board_status_read7_i          : std_logic;
signal extractwave_requested_i       : std_logic;
signal extractdata_requested_i       : std_logic;
signal read_histogram_requested_i    : std_logic;
signal sysmon_requested_i            : std_logic;
signal start_write_byte_i            : std_logic;
signal clear_extractwave_requested_i : std_logic;
signal clear_extractdata_requested_i : std_logic;
signal clear_histogram_requested_i   : std_logic;
signal clear_sysmon_requested_i      : std_logic;
signal io_data_in_S                  : std_logic_vector(0 to NROFFIBERS-1);

signal io_byte_out_S                 : std_logic_vector(7 downto 0);
signal io_byte_request_S             : std_logic_vector(7 downto 0);
signal io_write_out_S                : std_logic;
signal io_request_out_S              : std_logic;
signal byte_index_S                  : integer range 0 to 10 := 0;
signal io_data_idx_i                 : integer range 0 to 63 := 0;
signal io_data_par_S                 : std_logic_vector(31 downto 0) := (others => '0');
signal extractdata_idx_i             : integer range 0 to 7 := 0;
signal extractwave_idx_i             : integer range 0 to 4 := 0;
signal read_histogram_idx_i          : integer range 0 to 4096 := 0;
signal read_sysmon_idx_i             : std_logic := '0';
signal addresscycle_i                : std_logic;
signal fibernr_i                     : integer range 0 to NROFFIBERS-1 := 0;
signal skipfirstread_i               : std_logic := '0';
signal rdhistophase_S                : integer range 0 to 7 := 0;

signal readfifo_write_i              : std_logic;
signal readfifo_write_bf_i           : std_logic;
signal readfifo_datain_i             : std_logic_vector(31 downto 0);
signal readfifo_read_i               : std_logic;
signal readfifo_dataout_i            : std_logic_vector(31 downto 0);
signal readfifo_full_i               : std_logic;
signal readfifo_empty_i              : std_logic;

begin

board_control <= board_control_S;

---------------------------------------------------------
-- Statemachine                                        --
---------------------------------------------------------
  STATE_MEM: process(clk)
    begin
      if( rising_edge(clk) ) then
        if( rst = '1' ) then
          CURRENT_STATE <= SLEEP;
          bus_ack       <= '0';
          store_wr      <= '0';
          store_rd      <= '0';
        else
          CURRENT_STATE <= NEXT_STATE;
          bus_ack       <= bus_ack_x;
          store_wr      <= store_wr_x;
          store_rd      <= store_rd_x;
        end if;
      end if;
    end process STATE_MEM;

-- Transition matrix
  TRANSFORM: process(CURRENT_STATE, BUS_read_in, BUS_write_in )
    begin
      NEXT_STATE <= SLEEP;
      bus_ack_x  <= '0';
      store_wr_x <= '0';
      store_rd_x <= '0';
      case CURRENT_STATE is
        when SLEEP    =>
          if   ( (BUS_read_in = '1') ) then
            NEXT_STATE <= RD_RDY;
            store_rd_x <= '1';
          elsif( (BUS_write_in = '1') ) then
            NEXT_STATE <= WR_RDY;
            store_wr_x <= '1';
          else
            NEXT_STATE <= SLEEP;
          end if;

        when RD_RDY    =>
          NEXT_STATE <= RD_ACK;

        when WR_RDY    =>
          NEXT_STATE <= WR_ACK;

        when RD_ACK    =>
          if( BUS_read_in = '0' ) then
            NEXT_STATE <= DONE;
            bus_ack_x  <= '1';
          else
            NEXT_STATE <= RD_ACK;
            bus_ack_x  <= '1';
          end if;

        when WR_ACK    =>
          if( BUS_write_in = '0' ) then
            NEXT_STATE <= DONE;
            bus_ack_x  <= '1';
          else
            NEXT_STATE <= WR_ACK;
            bus_ack_x  <= '1';
          end if;

        when DONE    =>
          NEXT_STATE <= SLEEP;

        when others    =>
          NEXT_STATE <= SLEEP;
  end case;
end process TRANSFORM;


---------------------------------------------------------
-- data handling                                       --
---------------------------------------------------------

-- register write
THE_WRITE_REG_PROC: process(clk)
	begin
		if rising_edge(clk) then
			if (rst='1') then
				address_register_i <= (others => '0');
			elsif ( (store_wr = '1') and (bus_addr_in = "00") ) then
				address_register_i <= bus_data_in;
			elsif ( (store_wr = '1') and (bus_addr_in = "01") ) then
				data_register_i <= bus_data_in;
			end if;
		end if;
	end process THE_WRITE_REG_PROC;
  
  
THE_WRITE_PROC: process(clk)
	begin
		if rising_edge(clk) then
			if (rst='1') then
				board_control_write <= (others => '0');
				extractwave_requested_i <= '0';
				extractdata_requested_i <= '0';
				read_histogram_requested_i <= '0';
				sysmon_requested_i <= '0';
				start_write_byte_i <= '0';
			else
				board_control_write <= (others => '0');
				start_write_byte_i <= '0';
				if clear_extractwave_requested_i='1' then
					extractwave_requested_i <= '0';
				end if;
				if clear_extractdata_requested_i='1' then
					extractdata_requested_i <= '0';
				end if;		
				if clear_histogram_requested_i='1' then
					read_histogram_requested_i <= '0';
				end if;		
				if clear_sysmon_requested_i='1' then
					sysmon_requested_i <= '0';
				end if;		
				if ((store_wr='1') and (bus_addr_in="01")) and (address_register_i(30 downto 28)="101") then -- act when writing data register
					if (address_register_i(23 downto 0)=ADDRESS_MUX_SODA_CONTROL) and (address_register_i(31)='0') then
						board_control_S(3) <= bus_data_in;
						board_control_write(3) <= '1';
					elsif (address_register_i(23 downto 0)=ADDRESS_MUX_HISTOGRAM) then
						board_control_S(4) <= bus_data_in;
						board_control_write(4) <= '1';
						if (address_register_i(31)='0') and (bus_data_in(1)='1') then
							read_histogram_requested_i <= '1';
						end if;
					elsif (address_register_i(23 downto 0)=ADDRESS_MUX_EXTRACTWAVE) and (address_register_i(31)='1') then
						board_control_S(7) <= bus_data_in;
						board_control_write(7) <= '1';
						extractwave_requested_i <= '1';
					elsif (address_register_i(23 downto 0)=ADDRESS_MUX_EXTRACTDATA) and (address_register_i(31)='1') then
						board_control_S(8) <= bus_data_in;
						board_control_write(8) <= '1';
						extractdata_requested_i <= '1';
					elsif (address_register_i(23 downto 0)=ADDRESS_MUX_CROSSSWITCH) and (address_register_i(31)='0') then
						board_control_S(13) <= bus_data_in;
						board_control_write(13) <= '1';
					elsif (address_register_i(23 downto 0)=ADDRESS_MUX_SYSMON) and (address_register_i(31)='1') then
						board_control_S(12) <= bus_data_in;
						board_control_write(12) <= '1';
						sysmon_requested_i <= '1';
					else -- IO
						address_register_copy_i <= address_register_i;	
						start_write_byte_i <= '1';						
					end if;
				end if;
			end if;
		end if;
	end process THE_WRITE_PROC;

THE_BYTE_WRITE_PROC: process(clk)
	begin
		if rising_edge(clk) then
			if (rst='1') then
			else
				case byte_index_S is 
					when 1 => 
						io_byte_out_S <= address_register_copy_i(31 downto 24);
						io_write_out_S <= '1';
						byte_index_S <= byte_index_S+1;
					when 2 => 
						io_byte_out_S <= address_register_copy_i(23 downto 16);
						io_write_out_S <= '1';
						byte_index_S <= byte_index_S+1;
					when 3 => 
						io_byte_out_S <= address_register_copy_i(15 downto 8);
						io_write_out_S <= '1';
						byte_index_S <= byte_index_S+1;
					when 4 => 
						io_byte_out_S <= address_register_copy_i(7 downto 0);	
						io_write_out_S <= '1';
						byte_index_S <= byte_index_S+1;
					when 5 => 
						io_write_out_S <= '0';
						byte_index_S <= byte_index_S+1;
					when 6 => 
						io_byte_out_S <= "0000" & address_register_copy_i(27 downto 24);
						io_write_out_S <= '1';
						byte_index_S <= byte_index_S+1;
					when 7 => 
						io_byte_out_S <= data_register_i(31 downto 24);
						io_write_out_S <= '1';
						byte_index_S <= byte_index_S+1;
					when 8 => 
						io_byte_out_S <= data_register_i(23 downto 16);
						io_write_out_S <= '1';
						byte_index_S <= byte_index_S+1;
					when 9 => 
						io_byte_out_S <= data_register_i(15 downto 8);
						io_write_out_S <= '1';
						byte_index_S <= byte_index_S+1;
					when 10 => 
						io_byte_out_S <= data_register_i(7 downto 0);	
						io_write_out_S <= '1';
						byte_index_S <= 0;
					when others =>
						if start_write_byte_i='1' then
							io_byte_out_S <= "0000" & address_register_copy_i(27 downto 24);
							io_write_out_S <= '1';
							byte_index_S <= 1;
						else
							io_write_out_S <= '0';
						end if;
				end case;
			end if;
		end if;
	end process THE_BYTE_WRITE_PROC;
	
board_status_read_i(7) <= '1' when (extractwave_idx_i/=0) and (readfifo_full_i='0') else '0';


THE_READ_IO_PROC: process(clk)
constant zeros : std_logic_vector(0 to NROFFIBERS-1) := (others => '0');
variable fibernr : integer range 0 to NROFFIBERS-1 := 0;
	begin
		if( rising_edge(clk) ) then
			io_request_out_S <= '0';
			skipfirstread_i <= '0';
			board_status_read_i(4) <= '0';
			board_status_read_i(8) <= '0';
			clear_extractwave_requested_i <= '0';
			clear_extractdata_requested_i <= '0';
			clear_histogram_requested_i <= '0';
			readfifo_write_i <= '0';
			io_data_par_S <= io_data_par_S(30 downto 0) & io_data_in_S(fibernr_i);
			io_data_in_S <= io_data_in;
			if (rst='1') then
				clear_sysmon_requested_i <= '0';
				io_data_idx_i <= 0;
				extractdata_idx_i <= 0;
				read_sysmon_idx_i <= '0';
				addresscycle_i <= '0';
			else
				if io_data_idx_i/=0 then
					if io_data_idx_i<36 then
						io_data_idx_i <= io_data_idx_i+1;
					elsif io_data_idx_i=36 then
						readfifo_write_i <= '1';
						if (addresscycle_i='1') and (io_data_par_S(29 downto 27)="101") then -- dataword
							readfifo_datain_i <= io_data_par_S(30 downto 27) & conv_std_logic_vector(fibernr_i,4) & io_data_par_S(22 downto 0) & io_data_in_S(fibernr_i);
							io_data_idx_i <= io_data_idx_i+1;
						else
							readfifo_datain_i <= io_data_par_S(30 downto 0) & io_data_in_S(fibernr_i);
							io_data_idx_i <= 0;
						end if;
						addresscycle_i <= '0';
					elsif io_data_idx_i=37 then 
						io_data_idx_i <= io_data_idx_i+1;
						addresscycle_i <= '0';
					else
						io_byte_request_S <= "10" & conv_std_logic_vector(fibernr_i,6);
						io_request_out_S <= '1';
						io_data_idx_i <= 1;
						addresscycle_i <= '0';
					end if;
--					io_data_par_S <= io_data_par_S(30 downto 0) & io_data_in_S(fibernr_i);
				elsif extractdata_idx_i/=0 then
					if readfifo_full_i='0' then
						case extractdata_idx_i is
							when 1 => 
								readfifo_datain_i <= board_status(8);
								extractdata_idx_i <= extractdata_idx_i+1;
								board_status_read_i(8) <= '1'; -- next word
							when 2 => 
								readfifo_datain_i <= (x"d0" & ADDRESS_MUX_EXTRACTDATA)+1;
								extractdata_idx_i <= extractdata_idx_i+1;
							when 3 => 
								readfifo_datain_i <= board_status(8);
								extractdata_idx_i <= extractdata_idx_i+1;
								board_status_read_i(8) <= '1'; -- next word
							when 4 => 
								readfifo_datain_i <= (x"d0" & ADDRESS_MUX_EXTRACTDATA)+2;
								extractdata_idx_i <= extractdata_idx_i+1;
							when 5 => 
								readfifo_datain_i <= board_status(8);
								extractdata_idx_i <= extractdata_idx_i+1;
								board_status_read_i(8) <= '1'; -- next word
							when 6 => 
								readfifo_datain_i <= (x"d0" & ADDRESS_MUX_EXTRACTDATA)+3;
								extractdata_idx_i <= extractdata_idx_i+1;
							when 7 => 
								readfifo_datain_i <= board_status(8);
								extractdata_idx_i <= 0;
							when others =>
								extractdata_idx_i <= 0;
						end case;
						readfifo_write_i <= '1';
					else
						readfifo_write_i <= '1';
					end if;
				elsif extractwave_idx_i/=0 then
					if readfifo_full_i='0' then
						if skipfirstread_i='0' then
							readfifo_write_i <= '1';
							readfifo_datain_i <= board_status(7);	
							if ((board_status(7)(31)='1') or (board_status(7)(15)='1')) and (extractwave_idx_i>3) then
								extractwave_idx_i <= 0; -- stop reading waveform
							else
								if extractwave_idx_i<4 then
									extractwave_idx_i <= extractwave_idx_i+1;
								end if;
							end if;
						end if;
					else -- full
						readfifo_write_i <= '1';
					end if;
				elsif read_histogram_idx_i/=0 then
					if skipfirstread_i='1' then -- second word always 0x00000000
						rdhistophase_S <= 0;
						if readfifo_full_i='0' then
							readfifo_write_i <= '1';
							readfifo_datain_i <= (others => '0');
						else
							skipfirstread_i <= '1';
						end if;
					else
						if rdhistophase_S=0 then
							board_status_read_i(4) <= '1';
							rdhistophase_S <= rdhistophase_S+1;
						elsif rdhistophase_S=1 then
							if readfifo_full_i='0' then
								readfifo_write_i <= '1';
								readfifo_datain_i <= board_status(4);
								rdhistophase_S <= rdhistophase_S+1;
								if read_histogram_idx_i<=4096 then
									read_histogram_idx_i <= read_histogram_idx_i+1;
								else
									read_histogram_idx_i <= 0;
								end if;
							end if;
						elsif rdhistophase_S<7 then
							rdhistophase_S <= rdhistophase_S+1;
						else
							rdhistophase_S <= 0;							
						end if;
					end if;
				elsif read_sysmon_idx_i='1' then
					if readfifo_full_i='0' then
						readfifo_datain_i <= board_status(12);
						read_sysmon_idx_i <= '0';
						readfifo_write_i <= '1';
					else -- full
						readfifo_write_i <= '1';
					end if;
				elsif (extractdata_requested_i='1') and (extract_data_available='1') and (readfifo_full_i='0') then -- (board_status(8)/=x"ffffffff") then
					clear_extractdata_requested_i <= '1';
					readfifo_write_i <= '1';
					readfifo_datain_i <= (x"d0" & ADDRESS_MUX_EXTRACTDATA)+0;
					extractdata_idx_i <= 1;
				elsif (extractwave_requested_i='1') and (extract_wave_available='1') and (readfifo_full_i='0') then -- and (board_status(7)/=x"ffffffff") then
					clear_extractwave_requested_i <= '1';
					readfifo_write_i <= '1';
					readfifo_datain_i <= x"d0" & ADDRESS_MUX_EXTRACTWAVE;
					extractwave_idx_i <= 1;
					skipfirstread_i <= '1';
				elsif (sysmon_requested_i='1') and (readfifo_full_i='0') then 
					clear_sysmon_requested_i <= '1';
					readfifo_write_i <= '1';
					readfifo_datain_i <= (x"d0" & ADDRESS_MUX_SYSMON);
					read_sysmon_idx_i <= '1';					
				elsif IO_data_in_available/=zeros(0 to NROFFIBERS-1) then
					fibernr := 0;
					for i in 0 to NROFFIBERS-1 loop
						if IO_data_in_available(i)='1' then
							fibernr := i;
						end if;
					end loop;
					io_byte_request_S <= "10" & conv_std_logic_vector(fibernr,6);
					fibernr_i <= fibernr;
					io_request_out_S <= '1';
					io_data_idx_i <= 1;
					addresscycle_i <= '1';
				elsif (read_histogram_requested_i='1') and (readfifo_full_i='0') then
					clear_histogram_requested_i <= '1';
					read_histogram_idx_i <= 1;
					readfifo_write_i <= '1';
					readfifo_datain_i <= x"d0" & ADDRESS_MUX_HISTOGRAM;
					skipfirstread_i <= '1';
				else				
				end if;
			end if;
		end if;
	end process THE_READ_IO_PROC;
	
board_status_read <= board_status_read_i;
--io_write_out <= '1' when (io_write_out_S='1') or (io_request_out_S='1') else '0';
--io_data_out <= io_byte_request_S when (io_request_out_S='1') else io_byte_out_S;

process(clk)
begin
	if rising_edge(clk) then
		if (io_write_out_S='1') or (io_request_out_S='1') then
			io_write_out <= '1';
		else
			io_write_out <= '0';
		end if;
		if (io_request_out_S='1') then
			io_data_out <= io_byte_request_S;
		else
			io_data_out <= io_byte_out_S;
		end if;
	end if;
end process;

readfifo: async_fifo_512x32 port map(
	rst => rst,
	wr_clk => clk,
	rd_clk => clk,
	din => readfifo_datain_i,
	wr_en => readfifo_write_i,
	rd_en => readfifo_read_i,
	dout => readfifo_dataout_i,
	full => readfifo_full_i,
	empty => readfifo_empty_i);
readfifo_write_bf_i <= '1' when (readfifo_write_i='1') and (readfifo_full_i='0') else '0';
	
readfifo_read_i <= '1' when (CURRENT_STATE=SLEEP) and (BUS_read_in='1') and (bus_addr_in="11") 
	and (readfifo_empty_i='0') else '0';
		  
					
-- register read
THE_READ_REG_PROC: process(clk)
	begin
		if rising_edge(clk) then
			if (rst='1') then
				buf_bus_data_out <= (others => '0');
			elsif( (store_rd = '1') and (bus_addr_in = "00") ) then
				buf_bus_data_out <= address_register_i;
			elsif( (store_rd = '1') and (bus_addr_in = "01") ) then
				buf_bus_data_out <= data_register_i;
			elsif( (store_rd = '1') and (bus_addr_in = "10") ) then
				buf_bus_data_out(0) <= not readfifo_empty_i;
				buf_bus_data_out(1) <= readfifo_full_i;
				buf_bus_data_out(31 downto 2) <= (others => '0');
			elsif( (store_rd = '1') and (bus_addr_in = "11") ) then
				buf_bus_data_out <= readfifo_dataout_i;
			end if;
		end if;
	end process THE_READ_REG_PROC;
 

-- output signals
BUS_DATA_OUT <= buf_bus_data_out;
BUS_ACK_OUT  <= bus_ack;
BUS_BUSY_OUT <= '0';

testword0 <= (others => '0');

	
end Behavioral;

