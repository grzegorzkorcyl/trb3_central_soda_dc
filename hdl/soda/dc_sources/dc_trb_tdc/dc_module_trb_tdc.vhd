library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;
USE work.panda_package.all;

entity dc_module_trb_tdc is
	generic(
		NROFFIBERS            : natural                       := 4;
		NROFADCS              : natural                       := 16;
		ADCBITS               : natural                       := 14;
		ADCCLOCKFREQUENCY     : natural                       := 80000000;
		MAX_DIVIDERSCALEBITS  : natural                       := 12;
		MAX_LUTSIZEBITS       : natural                       := 8;
		MAX_LUTSCALEBITS      : natural                       := 14;
		MUXINFIFOSIZE         : natural                       := 9;
		TRANSFERFIFOSIZE      : natural                       := 14;
		CF_FRACTIONBIT        : natural                       := 11;
		TRANSITIONBUFFERBITS  : natural                       := 7;
		PANDAPACKETBUFFERBITS : natural                       := 13;
		ADCINDEXSHIFT         : natural                       := 1;
		ENERGYSCALINGBITS     : natural                       := 13;
		COMBINEPULSESMEMSIZE  : natural                       := 10;
		COMBINETIMEDIFFERENCE : natural                       := 5000;
		SYSTEM_ID             : std_logic_vector(15 downto 0) := x"5555"
	);
	port(
		slowcontrol_clock    : in  std_logic;
		packet_in_clock      : in  std_logic;
		MUX_clock            : in  std_logic;
		packet_out_clock     : in  std_logic;
		SODA_clock           : in  std_logic;
		reset                : in  std_logic;

		-- Slave bus
		BUS_READ_IN          : in  std_logic;
		BUS_WRITE_IN         : in  std_logic;
		BUS_BUSY_OUT         : out std_logic;
		BUS_ACK_OUT          : out std_logic;
		BUS_ADDR_IN          : in  std_logic_vector(1 downto 0);
		BUS_DATA_IN          : in  std_logic_vector(31 downto 0);
		BUS_DATA_OUT         : out std_logic_vector(31 downto 0);

		-- fiber interface signals:
		fiber_txlocked       : in  std_logic_vector(0 to NROFFIBERS - 1);
		fiber_rxlocked       : in  std_logic_vector(0 to NROFFIBERS - 1);
		reset_fibers         : out std_logic;
		fiber_data32write    : out std_logic_vector(0 to NROFFIBERS - 1);
		fiber_data32out      : out array_fiber32bits_type;
		fiber_data32fifofull : in  std_logic_vector(0 to NROFFIBERS - 1);
		fiber_data32read     : out std_logic_vector(0 to NROFFIBERS - 1);
		fiber_data32present  : in  std_logic_vector(0 to NROFFIBERS - 1);
		fiber_data32in       : in  array_fiber32bits_type;
		fiber_rxerror        : in  std_logic_vector(0 to NROFFIBERS - 1);

		-- SODA signals
		superburst_number    : in  std_logic_vector(30 downto 0);
		superburst_update    : in  std_logic;
		SODA_enable          : out std_logic;
		EnableExternalSODA   : out std_logic;

		-- 64 bits data output
		data_out_allowed     : in  std_logic;
		data_out             : out std_logic_vector(63 downto 0);
		data_out_write       : out std_logic;
		data_out_first       : out std_logic;
		data_out_last        : out std_logic;
		data_out_error       : out std_logic;
		no_packet_limit      : out std_logic;

		-- testpoints
		testword0            : out std_logic_vector(35 downto 0) := (others => '0');
		testword0clock       : out std_logic                     := '0';
		testword1            : out std_logic_vector(35 downto 0) := (others => '0');
		testword2            : out std_logic_vector(35 downto 0) := (others => '0')
	);
end dc_module_trb_tdc;

architecture Behavioral of dc_module_trb_tdc is
	component DC_posedge_to_pulse is
		port(
			clock_in  : in  std_logic;
			clock_out : in  std_logic;
			en_clk    : in  std_logic;
			signal_in : in  std_logic;
			pulse     : out std_logic);
	end component;

	type dummy_data_gen_states is (IDLE, WAIT_FOR_ALLOW, GEN_HDR1, GEN_HDR2, GEN_DATA_FEE1, GEN_DATA_FEE2, GEN_DATA_FEE3, GEN_DATA_FEE4, CLOSE);
	signal dummy_current_state, dummy_next_state : dummy_data_gen_states;

	signal reset_packet_in_clock_S  : std_logic;
	signal reset_packet_out_clock_S : std_logic;
	signal reset_SODAclock_S        : std_logic;

	signal latestsuperburst_write_S : std_logic                     := '0';
	signal latestsuperburstnumber_S : std_logic_vector(30 downto 0) := (others => '0');

	signal SODA_enable0_S           : std_logic;
	signal reset_slowcontrolclock_s : std_logic;

begin
	process(slowcontrol_clock)
	begin
		if (rising_edge(slowcontrol_clock)) then
			reset_slowcontrolclock_s <= reset;
		end if;
	end process;
	process(packet_in_clock)
	begin
		if (rising_edge(packet_in_clock)) then
			reset_packet_in_clock_S <= reset;
		end if;
	end process;
	process(packet_out_clock)
	begin
		if (rising_edge(packet_out_clock)) then
			reset_packet_out_clock_S <= reset;
		end if;
	end process;

	sync_superburstwrite : DC_posedge_to_pulse port map(
			clock_in  => SODA_clock,
			clock_out => packet_out_clock,
			en_clk    => '1',
			signal_in => superburst_update,
			pulse     => latestsuperburst_write_S);

	sync_superburstwrite_process : process(packet_out_clock)
	begin
		if (rising_edge(packet_out_clock)) then
			if latestsuperburst_write_S = '1' then
				latestsuperburstnumber_S <= superburst_number;
			end if;
		end if;
	end process;

	-- dummy data generation

	process(packet_out_clock)
	begin
		if rising_edge(packet_out_clock) then
			if (reset_packet_out_clock_S = '1') then
				dummy_current_state <= IDLE;
			else
				dummy_current_state <= dummy_next_state;
			end if;
		end if;
	end process;

	process(dummy_current_state, latestsuperburst_write_S, data_out_allowed)
	begin
		case dummy_current_state is
			when IDLE =>
				if (latestsuperburst_write_S = '1') then
					dummy_next_state <= WAIT_FOR_ALLOW;
				else
					dummy_next_state <= IDLE;
				end if;

			when WAIT_FOR_ALLOW =>
				if (data_out_allowed = '1') then
					dummy_next_state <= GEN_HDR1;
				else
					dummy_next_state <= WAIT_FOR_ALLOW;
				end if;

			when GEN_HDR1 =>
				dummy_next_state <= GEN_HDR2;

			when GEN_HDR2 =>
				dummy_next_state <= GEN_DATA_FEE1;

			when GEN_DATA_FEE1 =>
				dummy_next_state <= GEN_DATA_FEE2;

			when GEN_DATA_FEE2 =>
				dummy_next_state <= GEN_DATA_FEE3;

			when GEN_DATA_FEE3 =>
				dummy_next_state <= GEN_DATA_FEE4;

			when GEN_DATA_FEE4 =>
				dummy_next_state <= CLOSE;

			when CLOSE =>
				dummy_next_state <= IDLE;

		end case;
	end process;

	-- The 64 bits output packets, according to 32bits SODAnet specs:
	-- 32bits word1:   
	--        bit31      = last-packet flag
	--        bit30..16  = packet number
	--        bit15..0   = data size in bytes
	-- 32bits word2:   
	--        bit31..0   = Not used (same as HADES)
	-- 32bits word3:   
	--        bit31..16  = Status
	--           bit16=internal data-error
	--           bit17=internal error
	--           bit18=error in pulse-data/superburst number
	--           bit31=  0:pulse data packet, 1:waveform packet
	--        bit15..0   = System ID
	-- 32bits word4:   
	--        bit31      = 0
	--        bit30..0   = Super-burst number

	process(dummy_current_state, latestsuperburstnumber_S)
	begin
		case dummy_current_state is
			when GEN_HDR1 =>
				data_out       <= x"0000" & x"0030" & x"0000_0000";
				data_out_write <= '1';
				data_out_first <= '1';
				data_out_last  <= '0';
			when GEN_HDR2 =>
				data_out       <= x"0000" & x"abcd" & '0' & latestsuperburstnumber_S;
				data_out_write <= '1';
				data_out_first <= '0';
				data_out_last  <= '0';
			when GEN_DATA_FEE1 =>
				data_out       <= x"1111_0011_2233_4455";
				data_out_write <= '1';
				data_out_first <= '0';
				data_out_last  <= '0';
			when GEN_DATA_FEE2 =>
				data_out       <= x"2222_6677_8899_aabb";
				data_out_write <= '1';
				data_out_first <= '0';
				data_out_last  <= '0';
			when GEN_DATA_FEE3 =>
				data_out       <= x"3333_ccdd_eeff_0011";
				data_out_write <= '1';
				data_out_first <= '0';
				data_out_last  <= '0';
			when GEN_DATA_FEE4 =>
				data_out       <= x"4444_2233_4455_6677";
				data_out_write <= '1';
				data_out_first <= '0';
				data_out_last  <= '1';
			when others =>
				data_out       <= (others => '0');
				data_out_write <= '0';
				data_out_first <= '0';
				data_out_last  <= '0';
		end case;
	end process;

	data_out_error  <= '0';
	no_packet_limit <= '0';

end Behavioral;
