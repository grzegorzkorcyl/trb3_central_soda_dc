library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;

entity dc_module_trb_tdc is
	generic(
		DO_SIMULATION : integer range 0 to 1 := 0
	);
	port(
		slowcontrol_clock        : in  std_logic;
		packet_in_clock          : in  std_logic;
		MUX_clock                : in  std_logic;
		packet_out_clock         : in  std_logic;
		SODA_clock               : in  std_logic;
		reset                    : in  std_logic;

		-- Slave bus
		BUS_READ_IN              : in  std_logic;
		BUS_WRITE_IN             : in  std_logic;
		BUS_BUSY_OUT             : out std_logic;
		BUS_ACK_OUT              : out std_logic;
		BUS_ADDR_IN              : in  std_logic_vector(1 downto 0);
		BUS_DATA_IN              : in  std_logic_vector(31 downto 0);
		BUS_DATA_OUT             : out std_logic_vector(31 downto 0);

		-- IPU interface directed toward the CTS
		CTS_NUMBER_IN            : in  std_logic_vector(15 downto 0);
		CTS_CODE_IN              : in  std_logic_vector(7 downto 0);
		CTS_INFORMATION_IN       : in  std_logic_vector(7 downto 0);
		CTS_READOUT_TYPE_IN      : in  std_logic_vector(3 downto 0);
		CTS_START_READOUT_IN     : in  std_logic;
		CTS_READ_IN              : in  std_logic;
		CTS_DATA_OUT             : out std_logic_vector(31 downto 0);
		CTS_DATAREADY_OUT        : out std_logic;
		CTS_READOUT_FINISHED_OUT : out std_logic; --no more data, end transfer, send TRM
		CTS_LENGTH_OUT           : out std_logic_vector(15 downto 0);
		CTS_ERROR_PATTERN_OUT    : out std_logic_vector(31 downto 0);
		-- Data from Frontends
		FEE_DATA_IN              : in  std_logic_vector(15 downto 0);
		FEE_DATAREADY_IN         : in  std_logic;
		FEE_READ_OUT             : out std_logic;
		FEE_BUSY_IN              : in  std_logic;
		FEE_STATUS_BITS_IN       : in  std_logic_vector(31 downto 0);

		-- SODA signals
		superburst_number        : in  std_logic_vector(30 downto 0);
		superburst_update        : in  std_logic;
		SODA_enable              : out std_logic;
		EnableExternalSODA       : out std_logic;

		-- 64 bits data output
		data_out_allowed         : in  std_logic;
		data_out                 : out std_logic_vector(63 downto 0);
		data_out_write           : out std_logic;
		data_out_first           : out std_logic;
		data_out_last            : out std_logic;
		data_out_error           : out std_logic;
		no_packet_limit          : out std_logic
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

	type saveStates is (IDLE, SAVE_EVT_ADDR, WAIT_FOR_DATA, SAVE_DATA, ADD_SUBSUB1, ADD_SUBSUB2, ADD_SUBSUB3, ADD_SUBSUB4, SAVE_PADDING, TERMINATE, SEND_TERM_PULSE, CLOSE, CLEANUP);
	signal save_current_state, save_next_state : saveStates;

	type loadStates is (IDLE, WAIT_FOR_SUBS, WAIT_FOR_LOAD, LOAD_HDR1, LOAD_HDR2, LOAD, CLOSE_SUB, CLOSE_QUEUE_IMMEDIATELY);
	signal load_current_state, load_next_state : loadStates;

	type dummy_data_gen_states is (IDLE, WAIT_FOR_ALLOW, GEN_HDR1, GEN_HDR2, GEN_DATA_FEE1, GEN_DATA_FEE2, GEN_DATA_FEE3, GEN_DATA_FEE4, CLOSE);
	signal dummy_current_state, dummy_next_state : dummy_data_gen_states;

	signal reset_packet_in_clock_S  : std_logic;
	signal reset_packet_out_clock_S : std_logic;
	signal reset_SODAclock_S        : std_logic;

	signal latestsuperburst_write_S : std_logic                     := '0';
	signal latestsuperburstnumber_S : std_logic_vector(30 downto 0) := (others => '0');

	signal SODA_enable0_S           : std_logic;
	signal reset_slowcontrolclock_s : std_logic;
	signal sf_data                  : std_logic_vector(15 downto 0);
	signal sf_wr_en, sf_rd_en       : std_logic;
	signal saved_size               : std_logic_vector(16 downto 0);
	signal cts_rnd                  : std_logic_vector(15 downto 0);
	signal save_eod                 : std_logic;
	signal cts_trg                  : std_logic_vector(15 downto 0);
	signal save_ctr                 : std_logic_vector(15 downto 0);

	signal sf_q                                       : std_logic_vector(63 downto 0);
	signal sf_eos, sf_nothing                         : std_logic_vector(3 downto 0);
	signal saved_events_ctr                           : std_logic_vector(31 downto 0);
	signal loaded_events_ctr                          : std_logic_vector(31 downto 0);
	signal saved_events_ctr_sync                      : std_logic_vector(31 downto 0);
	signal loaded_words_ctr                           : std_logic_vector(15 downto 0);
	signal subevent_size                              : std_logic_vector(17 downto 0);
	signal packet_size                                : std_logic_vector(15 downto 0);
	signal saved_bytes, save_ctr_sync                 : std_logic_vector(15 downto 0);
	signal sf_rd_en_q                                 : std_logic;
	signal event_ready, event_ready_q, event_ready_qq : std_logic;

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

	--*********
	-- RECEIVING PART
	--*********

	SAVE_MACHINE_PROC : process(reset_slowcontrolclock_s, slowcontrol_clock)
	begin
		if reset_slowcontrolclock_s = '1' then
			save_current_state <= IDLE;
		elsif rising_edge(slowcontrol_clock) then
			save_current_state <= save_next_state;
		end if;
	end process SAVE_MACHINE_PROC;

	SAVE_MACHINE : process(save_current_state, CTS_START_READOUT_IN, save_ctr, FEE_BUSY_IN, CTS_READ_IN)
	begin
		case (save_current_state) is
			when IDLE =>
				if (CTS_START_READOUT_IN = '1') then
					save_next_state <= SAVE_EVT_ADDR;
				else
					save_next_state <= IDLE;
				end if;

			when SAVE_EVT_ADDR =>
				save_next_state <= WAIT_FOR_DATA;

			when WAIT_FOR_DATA =>
				if (FEE_BUSY_IN = '1') then
					save_next_state <= SAVE_DATA;
				else
					save_next_state <= WAIT_FOR_DATA;
				end if;

			when SAVE_DATA =>
				if (FEE_BUSY_IN = '0') then
					save_next_state <= TERMINATE;
				else
					save_next_state <= SAVE_DATA;
				end if;

			when TERMINATE =>
				if (CTS_READ_IN = '1') then
					save_next_state <= SEND_TERM_PULSE;
				else
					save_next_state <= TERMINATE;
				end if;

			when SEND_TERM_PULSE =>
				save_next_state <= CLOSE;

			when CLOSE =>
				if (CTS_START_READOUT_IN = '0') then
					save_next_state <= ADD_SUBSUB1;
				else
					save_next_state <= CLOSE;
				end if;

			when ADD_SUBSUB1 =>
				save_next_state <= ADD_SUBSUB2;

			when ADD_SUBSUB2 =>
				save_next_state <= ADD_SUBSUB3;

			when ADD_SUBSUB3 =>
				save_next_state <= ADD_SUBSUB4;

			when ADD_SUBSUB4 =>
				if (save_ctr(1 downto 0) /= "10") then
					save_next_state <= SAVE_PADDING;
				else
					save_next_state <= CLEANUP;
				end if;

			when SAVE_PADDING =>
				if (save_ctr(1 downto 0) = "10") then
					save_next_state <= CLEANUP;
				else
					save_next_state <= SAVE_PADDING;
				end if;

			when CLEANUP =>
				save_next_state <= IDLE;

			when others => save_next_state <= IDLE;

		end case;
	end process SAVE_MACHINE;

	SF_DATA_EOD_PROC : process(slowcontrol_clock)
	begin
		if rising_edge(slowcontrol_clock) then
			case (save_current_state) is
				when SAVE_EVT_ADDR =>
					sf_data(3 downto 0)  <= CTS_INFORMATION_IN(3 downto 0);
					sf_data(7 downto 4)  <= CTS_READOUT_TYPE_IN;
					sf_data(15 downto 8) <= x"ab";
					save_eod             <= '0';

				when SAVE_DATA =>
					sf_data  <= FEE_DATA_IN;
					save_eod <= '0';

				when ADD_SUBSUB1 =>
					sf_data  <= x"0001";
					save_eod <= '0';

				when ADD_SUBSUB2 =>
					sf_data  <= x"5555";
					save_eod <= '0';

				when ADD_SUBSUB3 =>
					sf_data  <= FEE_STATUS_BITS_IN(31 downto 16);
					save_eod <= '0';

				when ADD_SUBSUB4 =>
					sf_data <= FEE_STATUS_BITS_IN(15 downto 0);
					if (save_ctr(1 downto 0) = "10") then
						save_eod <= '1';
					else
						save_eod <= '0';
					end if;

				when SAVE_PADDING =>
					sf_data <= x"abcd";
					if (save_ctr(1 downto 0) = "10") then
						save_eod <= '1';
					else
						save_eod <= '0';
					end if;

				when others => sf_data <= sf_data;
					save_eod <= '0';

			end case;
		end if;
	end process SF_DATA_EOD_PROC;

	CTS_DATAREADY_PROC : process(slowcontrol_clock)
	begin
		if rising_edge(slowcontrol_clock) then
			if (save_current_state = SAVE_DATA and FEE_BUSY_IN = '0') then
				CTS_DATAREADY_OUT <= '1';
			elsif (save_current_state = TERMINATE) then
				CTS_DATAREADY_OUT <= '1';
			else
				CTS_DATAREADY_OUT <= '0';
			end if;
		end if;
	end process CTS_DATAREADY_PROC;

	CTS_READOUT_FINISHED_PROC : process(slowcontrol_clock)
	begin
		if rising_edge(slowcontrol_clock) then
			if (save_current_state = SEND_TERM_PULSE) then
				CTS_READOUT_FINISHED_OUT <= '1';
			else
				CTS_READOUT_FINISHED_OUT <= '0';
			end if;
		end if;
	end process CTS_READOUT_FINISHED_PROC;

	CTS_LENGTH_OUT        <= (others => '0');
	CTS_ERROR_PATTERN_OUT <= (others => '0');

	CTS_DATA_PROC : process(slowcontrol_clock)
	begin
		if rising_edge(slowcontrol_clock) then
			CTS_DATA_OUT <= "0001" & cts_rnd(11 downto 0) & cts_trg;
		end if;
	end process CTS_DATA_PROC;

	CTS_RND_TRG_PROC : process(slowcontrol_clock)
	begin
		if rising_edge(slowcontrol_clock) then
			if (save_current_state = SAVE_DATA and save_ctr = x"0000") then
				cts_rnd <= sf_data;
				cts_trg <= cts_trg;
			elsif (save_current_state = SAVE_DATA and save_ctr = x"0001") then
				cts_rnd <= cts_rnd;
				cts_trg <= sf_data;
			else
				cts_rnd <= cts_rnd;
				cts_trg <= cts_trg;
			end if;
		end if;
	end process CTS_RND_TRG_PROC;

	SAVE_CTR_PROC : process(slowcontrol_clock)
	begin
		if rising_edge(slowcontrol_clock) then
			if (save_current_state = IDLE) then
				save_ctr <= (others => '0');
			elsif (sf_wr_en = '1') then
				save_ctr <= save_ctr + x"1";
			else
				save_ctr <= save_ctr;
			end if;
		end if;
	end process SAVE_CTR_PROC;

	FEE_READ_PROC : process(slowcontrol_clock)
	begin
		if rising_edge(slowcontrol_clock) then
			if (save_current_state = SAVE_DATA) then
				FEE_READ_OUT <= '1';
			else
				FEE_READ_OUT <= '1';
			end if;
		end if;
	end process FEE_READ_PROC;

	process(slowcontrol_clock)
	begin
		if rising_edge(slowcontrol_clock) then
			if (save_current_state = SAVE_DATA and FEE_DATAREADY_IN = '1') then
				sf_wr_en <= '1';
			elsif (save_current_state = ADD_SUBSUB1 or save_current_state = ADD_SUBSUB2 or save_current_state = ADD_SUBSUB3 or save_current_state = ADD_SUBSUB4) then
				sf_wr_en <= '1';
			elsif (save_current_state = SAVE_PADDING) then -- and save_ctr(1 downto 0) /= "10") then
				sf_wr_en <= '1';
			else
				sf_wr_en <= '0';
			end if;
		end if;
	end process;

	THE_SPLIT_FIFO : entity work.fifo_16kx16x64
		port map(
			Data(15 downto 0) => sf_data,
			Data(16)          => '0',
			Data(17)          => save_eod,
			WrClock           => slowcontrol_clock,
			RdClock           => packet_out_clock,
			WrEn              => sf_wr_en,
			RdEn              => sf_rd_en,
			Reset             => reset_slowcontrolclock_s,
			RPReset           => reset_packet_out_clock_S,
			Q(15 downto 0)    => sf_q(15 downto 0),
			Q(16)             => sf_nothing(0),
			Q(17)             => sf_eos(0),
			Q(33 downto 18)   => sf_q(31 downto 16),
			Q(34)             => sf_nothing(0),
			Q(35)             => sf_eos(1),
			Q(51 downto 36)   => sf_q(47 downto 32),
			Q(52)             => sf_nothing(0),
			Q(53)             => sf_eos(2),
			Q(69 downto 54)   => sf_q(63 downto 48),
			Q(70)             => sf_nothing(0),
			Q(71)             => sf_eos(3),
			Empty             => open,
			Full              => open
		);

	SAVED_EVENTS_CTR_PROC : process(reset_slowcontrolclock_s, slowcontrol_clock)
	begin
		if (reset_slowcontrolclock_s = '1') then
			saved_events_ctr <= (others => '0');
		elsif rising_edge(slowcontrol_clock) then
			event_ready_q  <= event_ready;
			event_ready_qq <= event_ready_q;
			if (save_current_state = CLEANUP) then
				event_ready <= '1';
			else
				event_ready <= '0';
			end if;

			if (event_ready_qq = '1') then
				saved_events_ctr <= saved_events_ctr + x"1";
			else
				saved_events_ctr <= saved_events_ctr;
			end if;

		end if;
	end process SAVED_EVENTS_CTR_PROC;

	--	saved_ctr_sync : entity work.signal_sync
	--		generic map(
	--			WIDTH => 32,
	--			DEPTH => 2
	--		)
	--		port map(
	--			RESET => reset_packet_out_clock_S,
	--			CLK0  => packet_out_clock,
	--			CLK1  => packet_out_clock,
	--			D_IN  => saved_events_ctr,
	--			D_OUT => saved_events_ctr_sync
	--		);
	--
	--	saved_size_sync : entity work.signal_sync
	--		generic map(
	--			WIDTH => 16,
	--			DEPTH => 2
	--		)
	--		port map(
	--			RESET => reset_packet_out_clock_S,
	--			CLK0  => packet_out_clock,
	--			CLK1  => packet_out_clock,
	--			D_IN  => save_ctr,
	--			D_OUT => save_ctr_sync
	--		);

	saved_events_ctr_sync <= saved_events_ctr;
	save_ctr_sync         <= save_ctr;

	LOAD_MACHINE_PROC : process(RESET, packet_out_clock)
	begin
		if RESET = '1' then
			load_current_state <= IDLE;
		elsif rising_edge(packet_out_clock) then
			load_current_state <= load_next_state;
		end if;
	end process LOAD_MACHINE_PROC;

	LOAD_MACHINE : process(load_current_state, saved_events_ctr_sync, loaded_events_ctr, loaded_words_ctr, data_out_allowed, sf_eos, subevent_size)
	begin
		case (load_current_state) is
			when IDLE =>
				load_next_state <= WAIT_FOR_SUBS;

			when WAIT_FOR_SUBS =>
				if (saved_events_ctr_sync /= loaded_events_ctr) then
					load_next_state <= WAIT_FOR_LOAD;
				else
					load_next_state <= WAIT_FOR_SUBS;
				end if;

			when WAIT_FOR_LOAD =>
				if (data_out_allowed = '1') then
					load_next_state <= LOAD_HDR1;
				else
					load_next_state <= WAIT_FOR_LOAD;
				end if;

			when LOAD_HDR1 =>
				load_next_state <= LOAD_HDR2;

			when LOAD_HDR2 =>
				load_next_state <= LOAD;

			when LOAD =>
				if (sf_eos /= "0000" and loaded_words_ctr /= x"0000") then
					load_next_state <= CLOSE_SUB;
				else
					load_next_state <= LOAD;
				end if;

			when CLOSE_SUB =>
				load_next_state <= CLOSE_QUEUE_IMMEDIATELY;

			when CLOSE_QUEUE_IMMEDIATELY =>
				load_next_state <= WAIT_FOR_SUBS;

			when others => load_next_state <= IDLE;

		end case;
	end process LOAD_MACHINE;

	SF_RD_EN_PROC : process(packet_out_clock)
	begin
		if rising_edge(packet_out_clock) then
			if (load_current_state = LOAD) then
				sf_rd_en <= '1';
			else
				sf_rd_en <= '0';
			end if;
		end if;
	end process SF_RD_EN_PROC;

	LOADED_BYTES_CTR_PROC : process(packet_out_clock)
	begin
		if rising_edge(packet_out_clock) then
			if (load_current_state = WAIT_FOR_SUBS) then
				loaded_words_ctr <= (others => '0');
			elsif (sf_rd_en = '1') then
				if (load_current_state = LOAD) then
					loaded_words_ctr <= loaded_words_ctr + x"1";
				else
					loaded_words_ctr <= loaded_words_ctr;
				end if;
			else
				loaded_words_ctr <= loaded_words_ctr;
			end if;

			sf_rd_en_q <= sf_rd_en;
		end if;
	end process LOADED_BYTES_CTR_PROC;

	process(packet_out_clock)
	begin
		if rising_edge(packet_out_clock) then
			packet_size <= saved_bytes + x"10";

			if (event_ready = '1') then
				saved_bytes <= save_ctr_sync(14 downto 0) & "0";
			else
				saved_bytes <= saved_bytes;
			end if;
		end if;
	end process;

	process(packet_out_clock)
	begin
		if rising_edge(packet_out_clock) then
			case load_current_state is
				when LOAD_HDR1 =>
					data_out       <= x"0000" & packet_size & x"0000_0000";
					data_out_write <= '1';
					data_out_first <= '1';
					data_out_last  <= '0';
				when LOAD_HDR2 =>
					data_out       <= x"0000" & x"abcd" & '0' & latestsuperburstnumber_S;
					data_out_write <= '1';
					data_out_first <= '0';
					data_out_last  <= '0';
				when LOAD =>
					data_out       <= sf_q;
					data_out_write <= sf_rd_en_q; --'1';
					data_out_first <= '0';
					if (sf_eos = "0000") then
						data_out_last <= '0';
					else
						data_out_last <= '1';
					end if;
				when others =>
					data_out       <= (others => '0');
					data_out_write <= '0';
					data_out_first <= '0';
					data_out_last  <= '0';
			end case;
		end if;
	end process;

	LOADED_EVENTS_CTR_PROC : process(reset_packet_out_clock_S, packet_out_clock)
	begin
		if (reset_packet_out_clock_S = '1') then
			loaded_events_ctr <= (others => '0');
		elsif rising_edge(packet_out_clock) then
			if (load_current_state = CLOSE_QUEUE_IMMEDIATELY) then
				loaded_events_ctr <= loaded_events_ctr + x"1";
			else
				loaded_events_ctr <= loaded_events_ctr;
			end if;
		end if;
	end process LOADED_EVENTS_CTR_PROC;

	--*******************
	-- dummy stuff

	--	process(packet_out_clock)
	--	begin
	--		if rising_edge(packet_out_clock) then
	--			if (reset_packet_out_clock_S = '1') then
	--				dummy_current_state <= IDLE;
	--			else
	--				dummy_current_state <= dummy_next_state;
	--			end if;
	--		end if;
	--	end process;
	--
	--	process(dummy_current_state, saved_events_ctr_sync, loaded_events_ctr, data_out_allowed)
	--	begin
	--		case dummy_current_state is
	--			when IDLE =>
	--				if (saved_events_ctr_sync /= loaded_events_ctr) then
	--					dummy_next_state <= WAIT_FOR_ALLOW;
	--				else
	--					dummy_next_state <= IDLE;
	--				end if;
	--
	--			when WAIT_FOR_ALLOW =>
	--				if (data_out_allowed = '1') then
	--					dummy_next_state <= GEN_HDR1;
	--				else
	--					dummy_next_state <= WAIT_FOR_ALLOW;
	--				end if;
	--
	--			when GEN_HDR1 =>
	--				dummy_next_state <= GEN_HDR2;
	--
	--			when GEN_HDR2 =>
	--				dummy_next_state <= GEN_DATA_FEE1;
	--
	--			when GEN_DATA_FEE1 =>
	--				dummy_next_state <= GEN_DATA_FEE2;
	--
	--			when GEN_DATA_FEE2 =>
	--				dummy_next_state <= GEN_DATA_FEE3;
	--
	--			when GEN_DATA_FEE3 =>
	--				dummy_next_state <= GEN_DATA_FEE4;
	--
	--			when GEN_DATA_FEE4 =>
	--				dummy_next_state <= CLOSE;
	--
	--			when CLOSE =>
	--				dummy_next_state <= IDLE;
	--
	--		end case;
	--	end process;

	--	LOADED_EVENTS_CTR_PROC : process(reset_packet_out_clock_S, packet_out_clock)
	--	begin
	--		if (reset_packet_out_clock_S = '1') then
	--			loaded_events_ctr <= (others => '0');
	--		elsif rising_edge(packet_out_clock) then
	--			if (dummy_current_state = CLOSE) then
	--				loaded_events_ctr <= loaded_events_ctr + x"1";
	--			else
	--				loaded_events_ctr <= loaded_events_ctr;
	--			end if;
	--		end if;
	--	end process LOADED_EVENTS_CTR_PROC;

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

	--	process(dummy_current_state, latestsuperburstnumber_S)
	--	begin
	--		case dummy_current_state is
	--			when GEN_HDR1 =>
	--				data_out       <= x"0000" & x"0030" & x"0000_0000";
	--				data_out_write <= '1';
	--				data_out_first <= '1';
	--				data_out_last  <= '0';
	--			when GEN_HDR2 =>
	--				data_out       <= x"0000" & x"abcd" & '0' & latestsuperburstnumber_S;
	--				data_out_write <= '1';
	--				data_out_first <= '0';
	--				data_out_last  <= '0';
	--			when GEN_DATA_FEE1 =>
	--				data_out       <= x"1111_0011_2233_4455";
	--				data_out_write <= '1';
	--				data_out_first <= '0';
	--				data_out_last  <= '0';
	--			when GEN_DATA_FEE2 =>
	--				data_out       <= x"2222_6677_8899_aabb";
	--				data_out_write <= '1';
	--				data_out_first <= '0';
	--				data_out_last  <= '0';
	--			when GEN_DATA_FEE3 =>
	--				data_out       <= x"3333_ccdd_eeff_0011";
	--				data_out_write <= '1';
	--				data_out_first <= '0';
	--				data_out_last  <= '0';
	--			when GEN_DATA_FEE4 =>
	--				data_out       <= x"4444_2233_4455_6677";
	--				data_out_write <= '1';
	--				data_out_first <= '0';
	--				data_out_last  <= '1';
	--			when others =>
	--				data_out       <= (others => '0');
	--				data_out_write <= '0';
	--				data_out_first <= '0';
	--				data_out_last  <= '0';
	--		end case;
	--	end process;

	data_out_error  <= '0';
	no_packet_limit <= '0';

end Behavioral;
