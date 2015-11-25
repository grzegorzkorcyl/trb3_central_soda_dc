library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb3_components.all;

entity tb_cts_soda_trigger is
end entity;

architecture arch1 of tb_cts_soda_trigger is
	signal clk_100_i, clk_200_i, clk_80_i, reset_i : std_logic;
	signal cts_ext_trigger                         : std_logic;
	signal cts_rdo_valid_notiming_trg              : std_logic;
	signal cts_rdo_trg_data_valid                  : std_logic;

	signal update_vec    : std_logic_vector(2 downto 0) := "000";
	signal update_toggle : std_logic                    := '0';
	signal update_synced, update_synced_q, update_synced_qq : std_logic                    := '0';

	signal superburst_update_S : std_logic;

	signal gbe_cts_number           : std_logic_vector(15 downto 0);
	signal gbe_cts_code             : std_logic_vector(7 downto 0);
	signal gbe_cts_information      : std_logic_vector(7 downto 0);
	signal gbe_cts_start_readout    : std_logic;
	signal gbe_cts_readout_type     : std_logic_vector(3 downto 0);
	signal gbe_cts_readout_finished : std_logic;
	signal gbe_cts_status_bits      : std_logic_vector(31 downto 0);
	signal gbe_fee_data             : std_logic_vector(15 downto 0);
	signal gbe_fee_dataready        : std_logic;
	signal gbe_fee_read             : std_logic;
	signal gbe_fee_status_bits      : std_logic_vector(31 downto 0);
	signal gbe_fee_busy             : std_logic;
	signal data64b_muxed_allowed_S  : std_logic;
	signal data64b_muxed            : std_logic_vector(63 downto 0);
	signal data64b_muxed_write      : std_logic;
	signal data64b_muxed_first      : std_logic;
	signal data64b_muxed_last       : std_logic;
	signal data64b_muxed_error      : std_logic;
	signal update_nr                : std_logic_vector(30 downto 0);
	signal sp_update : std_logic := '0';
	signal super_number_q : std_logic_vector(30 downto 0);
	signal nothing : std_logic;

begin
	process
	begin
		clk_80_i <= '1';
		wait for 6 ns;
		clk_80_i <= '0';
		wait for 6 ns;
	end process;

	process
	begin
		clk_100_i <= '1';
		wait for 5 ns;
		clk_100_i <= '0';
		wait for 5 ns;
	end process;

	process
	begin
		clk_200_i <= '1';
		wait for 2500 ps;
		clk_200_i <= '0';
		wait for 2500 ps;
	end process;

	process(clk_200_i)
	begin
		if rising_edge(clk_200_i) then
			sp_update <= superburst_update_S;
			
			update_toggle <= update_toggle xor sp_update;
		end if;
	end process;

	process(clk_100_i)
	begin
		if rising_edge(clk_100_i) then
			update_vec <= update_vec(1 downto 0) & update_toggle;
			
			update_synced_q <= update_synced;
			update_synced_qq <= update_synced_q;
		end if;
	end process;

	update_synced <= update_vec(2) xor update_vec(1);

	process
	begin
		superburst_update_S <= '0';
		wait for 1 us;
		wait until rising_edge(clk_200_i);
		wait for 1 ns;
		update_nr           <= "000" & x"b00f_001";
		superburst_update_S <= '1';
		wait until rising_edge(clk_200_i);
		wait for 1 ns;
		superburst_update_S <= '0';

		
		wait for 5 us;
		wait until rising_edge(clk_200_i);
		wait for 1 ns;
		superburst_update_S <= '1';
		update_nr           <= "000" & x"b00f_002";
		wait until rising_edge(clk_200_i);
		wait for 1 ns;
		superburst_update_S <= '0';

		wait for 5 us;
		wait until rising_edge(clk_200_i);
		wait for 1 ns;
		superburst_update_S <= '1';
		update_nr           <= "000" & x"b00f_003";
		wait until rising_edge(clk_200_i);
		wait for 1 ns;
		superburst_update_S <= '0';

		wait for 5 us;
		wait until rising_edge(clk_200_i);
		wait for 1 ns;
		superburst_update_S <= '1';
		update_nr           <= "000" & x"b00f_004";
		wait until rising_edge(clk_200_i);
		wait for 1 ns;
		superburst_update_S <= '0';

	end process;

	sb_number_fifo : entity work.async_fifo_16x32
		port map(
			rst               => reset_i,
			wr_clk            => clk_200_i,
			rd_clk            => clk_100_i,
			din(30 downto 0)  => update_nr,
			din(31)           => '0',
			wr_en             => sp_update,
			rd_en             => update_synced_qq,
			dout(30 downto 0) => super_number_q,
			dout(31)          => nothing,
			full              => open,
			empty             => open
		);

	process
	begin
		reset_i <= '1';
		wait for 100 ns;
		reset_i <= '0';
		wait;
	end process;

	process
	begin
		cts_rdo_trg_data_valid     <= '0';
		cts_rdo_valid_notiming_trg <= '0';
		wait until rising_edge(update_synced);
		wait for 100 ns;
		wait until rising_edge(clk_100_i);
		cts_rdo_trg_data_valid     <= '1';
		cts_rdo_valid_notiming_trg <= '1';
		wait until falling_edge(gbe_cts_start_readout);
		wait for 100 ns;
		wait until rising_edge(clk_100_i);
	end process;

	THE_CTS : entity work.CTS
		generic map(
			EXTERNAL_TRIGGER_ID  => x"60", -- fill in trigger logic enumeration id of external trigger logic

			TRIGGER_COIN_COUNT   => 0,  --TRIGGER_COIN_COUNT,
			TRIGGER_PULSER_COUNT => 2,  --TRIGGER_PULSER_COUNT,
			TRIGGER_RAND_PULSER  => 0,  --TRIGGER_RAND_PULSER,
			TRIGGER_INPUT_COUNT  => 0,  -- obsolete! now all inputs are routed via an input multiplexer!
			TRIGGER_ADDON_COUNT  => 1,  --TRIGGER_ADDON_COUNT,
			PERIPH_TRIGGER_COUNT => 0,  --PERIPH_TRIGGER_COUNT,
			OUTPUT_MULTIPLEXERS  => 0,  --CTS_OUTPUT_MULTIPLEXERS,
			ADDON_LINE_COUNT     => 38, --CTS_ADDON_LINE_COUNT,
			ADDON_GROUPS         => 7,
			ADDON_GROUP_UPPER    => (3, 7, 11, 15, 16, 17, others => 0)
		)
		port map(
			CLK                        => clk_100_i,
			RESET                      => reset_i,

			--TRIGGERS_IN => trigger_in_buf_i,
			TRIGGER_BUSY_OUT           => open,
			TIME_REFERENCE_OUT         => open,
			ADDON_TRIGGERS_IN          => (others => '0'), --cts_addon_triggers_in,
			ADDON_GROUP_ACTIVITY_OUT   => open,
			ADDON_GROUP_SELECTED_OUT   => open,
			EXT_TRIGGER_IN             => cts_ext_trigger,
			EXT_STATUS_IN              => x"0123_4567", --cts_ext_status,
			EXT_CONTROL_OUT            => open,
			EXT_HEADER_BITS_IN         => "00", --cts_ext_header,

			PERIPH_TRIGGER_IN          => (others => '0'), --cts_periph_trigger_i,
			OUTPUT_MULTIPLEXERS_OUT    => open,
			CTS_TRG_SEND_OUT           => open,
			CTS_TRG_TYPE_OUT           => open,
			CTS_TRG_NUMBER_OUT         => open,
			CTS_TRG_INFORMATION_OUT    => open,
			CTS_TRG_RND_CODE_OUT       => open,
			CTS_TRG_STATUS_BITS_IN     => (others => '0'), --cts_trg_status_bits,
			CTS_TRG_BUSY_IN            => '0', --cts_trg_busy,

			CTS_IPU_SEND_OUT           => open,
			CTS_IPU_TYPE_OUT           => open,
			CTS_IPU_NUMBER_OUT         => open,
			CTS_IPU_INFORMATION_OUT    => open,
			CTS_IPU_RND_CODE_OUT       => open,
			CTS_IPU_STATUS_BITS_IN     => (others => '0'), --cts_ipu_status_bits,
			CTS_IPU_BUSY_IN            => gbe_fee_busy, --'0', --cts_ipu_busy,

			CTS_REGIO_ADDR_IN          => (others => '0'), --cts_regio_addr,
			CTS_REGIO_DATA_IN          => (others => '0'), --cts_regio_data_out,
			CTS_REGIO_READ_ENABLE_IN   => '0', --cts_regio_read,
			CTS_REGIO_WRITE_ENABLE_IN  => '0', --cts_regio_write,
			CTS_REGIO_DATA_OUT         => open,
			CTS_REGIO_DATAREADY_OUT    => open,
			CTS_REGIO_WRITE_ACK_OUT    => open,
			CTS_REGIO_UNKNOWN_ADDR_OUT => open,
			LVL1_TRG_DATA_VALID_IN     => cts_rdo_trg_data_valid,
			LVL1_VALID_TIMING_TRG_IN   => '0', -- cts_rdo_valid_timing_trg,
			LVL1_VALID_NOTIMING_TRG_IN => cts_rdo_valid_notiming_trg,
			LVL1_INVALID_TRG_IN        => '0', --cts_rdo_invalid_trg,

			FEE_TRG_STATUSBITS_OUT     => open,
			FEE_DATA_OUT               => open,
			FEE_DATA_WRITE_OUT         => open,
			FEE_DATA_FINISHED_OUT      => open
		);

	soda_trigger : entity work.soda_cts_module
		port map(
			CLK            => clk_100_i,
			RESET_IN       => reset_i,
			EXT_TRG_IN     => update_synced,
			TRG_SYNC_OUT   => cts_ext_trigger,
			TRIGGER_IN     => cts_rdo_trg_data_valid,
			DATA_OUT       => open,
			WRITE_OUT      => open,
			FINISHED_OUT   => open,
			STATUSBIT_OUT  => open,
			CONTROL_REG_IN => (others => '0'),
			STATUS_REG_OUT => open,
			HEADER_REG_OUT => open,
			DEBUG          => open
		);

	dummy_inst : entity work.gbe_ipu_dummy
		generic map(DO_SIMULATION    => 1,
			        FIXED_SIZE_MODE  => 1,
			        FIXED_SIZE       => 10,
			        INCREMENTAL_MODE => 0,
			        UP_DOWN_MODE     => 0,
			        UP_DOWN_LIMIT    => 100,
			        FIXED_DELAY_MODE => 1,
			        FIXED_DELAY      => 50)
		port map(clk                     => clk_100_i,
			     rst                     => reset_i,
			     GBE_READY_IN            => '1',
			     CFG_EVENT_SIZE_IN       => x"0100",
			     CFG_TRIGGERED_MODE_IN   => '1',
			     TRIGGER_IN              => update_synced,
			     CTS_NUMBER_OUT          => gbe_cts_number,
			     CTS_CODE_OUT            => gbe_cts_code,
			     CTS_INFORMATION_OUT     => gbe_cts_information,
			     CTS_READOUT_TYPE_OUT    => gbe_cts_readout_type,
			     CTS_START_READOUT_OUT   => gbe_cts_start_readout,
			     CTS_DATA_IN             => (others => '0'),
			     CTS_DATAREADY_IN        => '0',
			     CTS_READOUT_FINISHED_IN => gbe_cts_readout_finished,
			     CTS_READ_OUT            => open,
			     CTS_LENGTH_IN           => (others => '0'),
			     CTS_ERROR_PATTERN_IN    => gbe_cts_status_bits,
			     FEE_DATA_OUT            => gbe_fee_data,
			     FEE_DATAREADY_OUT       => gbe_fee_dataready,
			     FEE_READ_IN             => gbe_fee_read,
			     FEE_STATUS_BITS_OUT     => gbe_fee_status_bits,
			     FEE_BUSY_OUT            => gbe_fee_busy
		);

	THE_DATACONCENTRATOR_FROM_TDC : entity work.dc_module_trb_tdc
		port map(
			slowcontrol_clock        => clk_100_i,
			packet_in_clock          => clk_100_i,
			MUX_clock                => clk_100_i,
			packet_out_clock         => clk_100_i,
			SODA_clock               => clk_200_i,
			reset                    => reset_i,

			-- Slave bus
			BUS_READ_IN              => '0',
			BUS_WRITE_IN             => '0',
			BUS_BUSY_OUT             => open,
			BUS_ACK_OUT              => open,
			BUS_ADDR_IN              => (others => '0'),
			BUS_DATA_IN              => (others => '0'),
			BUS_DATA_OUT             => open,

			--CTS interface
			CTS_NUMBER_IN            => gbe_cts_number,
			CTS_CODE_IN              => gbe_cts_code,
			CTS_INFORMATION_IN       => gbe_cts_information,
			CTS_READOUT_TYPE_IN      => gbe_cts_readout_type,
			CTS_START_READOUT_IN     => gbe_cts_start_readout,
			CTS_DATA_OUT             => open,
			CTS_DATAREADY_OUT        => open,
			CTS_READOUT_FINISHED_OUT => gbe_cts_readout_finished,
			CTS_READ_IN              => '1',
			CTS_LENGTH_OUT           => open,
			CTS_ERROR_PATTERN_OUT    => gbe_cts_status_bits,
			FEE_DATA_IN              => gbe_fee_data,
			FEE_DATAREADY_IN         => gbe_fee_dataready,
			FEE_READ_OUT             => gbe_fee_read,
			FEE_STATUS_BITS_IN       => gbe_fee_status_bits,
			FEE_BUSY_IN              => gbe_fee_busy,

			-- SODA signals
			superburst_number        => super_number_q,
			superburst_update        => update_synced,

			-- 64 bits data output
			data_out_allowed         => data64b_muxed_allowed_S,
			data_out                 => data64b_muxed,
			data_out_write           => data64b_muxed_write,
			data_out_first           => data64b_muxed_first,
			data_out_last            => data64b_muxed_last,
			data_out_error           => data64b_muxed_error,
			no_packet_limit          => open
		);

	dataconversion_for_serdes_inst : entity work.dataconversion_for_serdes
		generic map(
			CREATE_OWN_STIMULI => FALSE
		)
		port map(
			DATA_CLK        => clk_100_i,
			CLK             => clk_100_i,
			RESET           => reset_i,
			TX_READY        => '1',
			SFP_MOD0        => '0',
			SFP_LOS         => '0',
			TX_DATA         => open,
			TX_K            => open,
			DATA_IN_ALLOWED => data64b_muxed_allowed_S,
			DATA_IN         => data64b_muxed,
			DATA_IN_WRITE   => data64b_muxed_write,
			DATA_IN_FIRST   => data64b_muxed_first,
			DATA_IN_LAST    => data64b_muxed_last,
			DATA_IN_ERROR   => data64b_muxed_error
		);

end architecture;
