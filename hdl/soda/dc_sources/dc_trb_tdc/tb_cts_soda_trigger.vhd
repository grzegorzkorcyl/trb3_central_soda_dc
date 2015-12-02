library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;

-- synopsys translate_off
library ecp3;
use ecp3.components.all;
-- synopsys translate_on   
library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.trb_net16_hub_func.all;
use work.trb_net_gbe_components.all;
use work.cts_pkg.all;

--Configuration is done in this file:   
use work.config.all;
-- The description of hub ports is also there!

--Slow Control
--    0 -    7  Readout endpoint common status
--   80 -   AF  Hub status registers
--   C0 -   CF  Hub control registers
-- 4000 - 40FF  Hub status registers
-- 7000 - 72FF  Readout endpoint registers
-- 8100 - 83FF  GbE configuration & status
-- A000 - A7FF  CTS configuration & status
-- A800 - A9ff  CBMNet
-- C000 - CFFF  TDC configuration & status
-- D000 - D13F  Flash Programming


use work.soda_components.all;

entity tb_cts_soda_trigger is
end entity;

architecture arch1 of tb_cts_soda_trigger is
	signal clk_100_i, clk_200_i, clk_80_i, reset_i : std_logic;
	signal cts_ext_trigger                         : std_logic;
	signal cts_rdo_valid_notiming_trg              : std_logic;
	signal cts_rdo_trg_data_valid                  : std_logic;

	signal update_vec                                       : std_logic_vector(2 downto 0) := "000";
	signal update_toggle                                    : std_logic                    := '0';
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
	signal sp_update                : std_logic                     := '0';
	signal super_number_q           : std_logic_vector(30 downto 0);
	signal nothing                  : std_logic;
	signal SODA_burst_pulse_S       : std_logic;
	signal update_synced_qqq        : std_logic;
	signal event_size               : std_logic_vector(15 downto 0) := x"0000";
	signal tx_k                     : std_logic;
	signal tx_data                  : std_logic_vector(7 downto 0);
	signal start_ctr                : std_logic;
	signal data_ctr                 : natural                       := 0;
	signal current_size             : std_logic_vector(15 downto 0);

	signal cts_trg_send        : std_logic;
	signal cts_trg_type        : std_logic_vector(3 downto 0);
	signal cts_trg_number      : std_logic_vector(15 downto 0);
	signal cts_trg_information : std_logic_vector(23 downto 0);
	signal cts_trg_code        : std_logic_vector(7 downto 0);
	signal cts_trg_status_bits : std_logic_vector(31 downto 0);
	signal cts_trg_busy        : std_logic;

	signal cts_ipu_send        : std_logic;
	signal cts_ipu_type        : std_logic_vector(3 downto 0);
	signal cts_ipu_number      : std_logic_vector(15 downto 0);
	signal cts_ipu_information : std_logic_vector(7 downto 0);
	signal cts_ipu_code        : std_logic_vector(7 downto 0);
	signal cts_ipu_status_bits : std_logic_vector(31 downto 0);
	signal cts_ipu_busy        : std_logic;

	signal cts_rdo_trg_status_bits_cts        : std_logic_vector(31 downto 0)         := (others => '0');
	signal cts_rdo_data                       : std_logic_vector(31 downto 0);
	signal cts_rdo_write                      : std_logic;
	signal cts_rdo_finished                   : std_logic;
	signal cts_rdo_additional_data            : std_logic_vector(32 * 1 - 1 downto 0);
	signal cts_rdo_additional_write           : std_logic_vector(1 - 1 downto 0)      := (others => '0');
	signal cts_rdo_additional_finished        : std_logic_vector(1 - 1 downto 0)      := (others => '1');
	signal cts_rdo_trg_status_bits_additional : std_logic_vector(32 * 1 - 1 downto 0) := (others => '0');
	signal cts_rdo_trigger                    : std_logic;
	signal cts_rdo_valid_timing_trg           : std_logic;
	signal cts_rdo_invalid_trg                : std_logic;

	signal med_stat_op        : std_logic_vector(5 * 16 - 1 downto 0);
	signal med_ctrl_op        : std_logic_vector(5 * 16 - 1 downto 0);
	signal med_stat_debug     : std_logic_vector(5 * 64 - 1 downto 0);
	signal med_ctrl_debug     : std_logic_vector(5 * 64 - 1 downto 0);
	signal med_data_out       : std_logic_vector(5 * 16 - 1 downto 0);
	signal med_packet_num_out : std_logic_vector(5 * 3 - 1 downto 0);
	signal med_dataready_out  : std_logic_vector(5 * 1 - 1 downto 0);
	signal med_read_out       : std_logic_vector(5 * 1 - 1 downto 0);
	signal med_data_in        : std_logic_vector(5 * 16 - 1 downto 0);
	signal med_packet_num_in  : std_logic_vector(5 * 3 - 1 downto 0);
	signal med_dataready_in   : std_logic_vector(5 * 1 - 1 downto 0);
	signal med_read_in        : std_logic_vector(5 * 1 - 1 downto 0);

	signal cts_regio_addr         : std_logic_vector(15 downto 0);
	signal cts_regio_read         : std_logic;
	signal cts_regio_write        : std_logic;
	signal cts_regio_data_out     : std_logic_vector(31 downto 0);
	signal cts_regio_data_in      : std_logic_vector(31 downto 0);
	signal cts_regio_dataready    : std_logic;
	signal cts_regio_no_more_data : std_logic;
	signal cts_regio_write_ack    : std_logic;
	signal cts_regio_unknown_addr : std_logic;

	signal cts_ext_status  : std_logic_vector(31 downto 0) := (others => '0');
	signal cts_ext_control : std_logic_vector(31 downto 0);
	signal cts_ext_debug   : std_logic_vector(31 downto 0);
	signal cts_ext_header  : std_logic_vector(1 downto 0);
	signal periph_trigger : std_logic_vector(19 downto 0);

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
		wait for 1900 ps;
		clk_200_i <= '0';
		wait for 1900 ps;
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

			update_synced_q   <= update_synced;
			update_synced_qq  <= update_synced_q;
			update_synced_qqq <= update_synced_qq;
		end if;
	end process;

	update_synced <= update_vec(2) xor update_vec(1);

	THE_SOB_SOURCE : entity work.soda_start_of_burst_control
		generic map(
			CLOCK_PERIOD => cSODA_CLOCK_PERIOD, -- clock-period in ns
			CYCLE_PERIOD => cSODA_CYCLE_PERIOD, -- cycle-period in ns
			BURST_PERIOD => cBURST_PERIOD -- burst-period in ns
		)
		port map(
			SODA_CLK             => clk_200_i,
			RESET                => reset_i,
			SODA_BURST_PULSE_OUT => SODA_burst_pulse_S,
			SODA_40MHZ_CYCLE_OUT => open
		);

	superburst_gen : entity work.soda_superburst_generator
		generic map(BURST_COUNT => 16)
		port map(
			SODACLK                 => clk_200_i,
			RESET                   => reset_i,
			ENABLE                  => '1',
			SODA_BURST_PULSE_IN     => SODA_burst_pulse_S,
			START_OF_SUPERBURST_OUT => superburst_update_S,
			SUPER_BURST_NR_OUT      => update_nr,
			SODA_CMD_WINDOW_OUT     => open
		);

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

	event_size <= super_number_q(15 downto 0) + x"0010";

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
			TRIGGER_COIN_COUNT   => 4,
			TRIGGER_PULSER_COUNT => 2,
			TRIGGER_RAND_PULSER  => 1,
			TRIGGER_INPUT_COUNT  => 8,  -- obsolete! now all inputs are routed via an input multiplexer!
			TRIGGER_ADDON_COUNT  => 6,
			PERIPH_TRIGGER_COUNT => 2,
			OUTPUT_MULTIPLEXERS  => 0,  --CTS_OUTPUT_MULTIPLEXERS,
			ADDON_LINE_COUNT     => 38, --CTS_ADDON_LINE_COUNT,
			ADDON_GROUPS         => 7,
			ADDON_GROUP_UPPER    => (3, 7, 11, 15, 16, 17, others => 0)
		--			TRIGGER_COIN_COUNT   => 0,  --TRIGGER_COIN_COUNT,
		--			TRIGGER_PULSER_COUNT => 2,  --TRIGGER_PULSER_COUNT,
		--			TRIGGER_RAND_PULSER  => 0,  --TRIGGER_RAND_PULSER,
		--			TRIGGER_INPUT_COUNT  => 0,  -- obsolete! now all inputs are routed via an input multiplexer!
		--			TRIGGER_ADDON_COUNT  => 1,  --TRIGGER_ADDON_COUNT,
		--			PERIPH_TRIGGER_COUNT => 0,  --PERIPH_TRIGGER_COUNT,
		--			OUTPUT_MULTIPLEXERS  => 0,  --CTS_OUTPUT_MULTIPLEXERS,
		--			ADDON_LINE_COUNT     => 38, --CTS_ADDON_LINE_COUNT,
		--			ADDON_GROUPS         => 7,
		--			ADDON_GROUP_UPPER    => (3, 7, 11, 15, 16, 17, others => 0)
		)
		port map(
			--			CLK                        => clk_100_i,
			--			RESET                      => reset_i,
			--
			--			--TRIGGERS_IN => trigger_in_buf_i,
			--			TRIGGER_BUSY_OUT           => open,
			--			TIME_REFERENCE_OUT         => open,
			--			ADDON_TRIGGERS_IN          => (others => '0'), --cts_addon_triggers_in,
			--			ADDON_GROUP_ACTIVITY_OUT   => open,
			--			ADDON_GROUP_SELECTED_OUT   => open,
			--			EXT_TRIGGER_IN             => cts_ext_trigger,
			--			EXT_STATUS_IN              => x"0123_4567", --cts_ext_status,
			--			EXT_CONTROL_OUT            => open,
			--			EXT_HEADER_BITS_IN         => "00", --cts_ext_header,
			--
			--			PERIPH_TRIGGER_IN          => (others => '0'), --cts_periph_trigger_i,
			--			OUTPUT_MULTIPLEXERS_OUT    => open,
			--			CTS_TRG_SEND_OUT           => open,
			--			CTS_TRG_TYPE_OUT           => open,
			--			CTS_TRG_NUMBER_OUT         => open,
			--			CTS_TRG_INFORMATION_OUT    => open,
			--			CTS_TRG_RND_CODE_OUT       => open,
			--			CTS_TRG_STATUS_BITS_IN     => (others => '0'), --cts_trg_status_bits,
			--			CTS_TRG_BUSY_IN            => '0', --cts_trg_busy,
			--
			--			CTS_IPU_SEND_OUT           => open,
			--			CTS_IPU_TYPE_OUT           => open,
			--			CTS_IPU_NUMBER_OUT         => open,
			--			CTS_IPU_INFORMATION_OUT    => open,
			--			CTS_IPU_RND_CODE_OUT       => open,
			--			CTS_IPU_STATUS_BITS_IN     => (others => '0'), --cts_ipu_status_bits,
			--			CTS_IPU_BUSY_IN            => gbe_fee_busy, --'0', --cts_ipu_busy,
			--
			--			CTS_REGIO_ADDR_IN          => (others => '0'), --cts_regio_addr,
			--			CTS_REGIO_DATA_IN          => (others => '0'), --cts_regio_data_out,
			--			CTS_REGIO_READ_ENABLE_IN   => '0', --cts_regio_read,
			--			CTS_REGIO_WRITE_ENABLE_IN  => '0', --cts_regio_write,
			--			CTS_REGIO_DATA_OUT         => open,
			--			CTS_REGIO_DATAREADY_OUT    => open,
			--			CTS_REGIO_WRITE_ACK_OUT    => open,
			--			CTS_REGIO_UNKNOWN_ADDR_OUT => open,
			--			LVL1_TRG_DATA_VALID_IN     => cts_rdo_trg_data_valid,
			--			LVL1_VALID_TIMING_TRG_IN   => '0', -- cts_rdo_valid_timing_trg,
			--			LVL1_VALID_NOTIMING_TRG_IN => cts_rdo_valid_notiming_trg,
			--			LVL1_INVALID_TRG_IN        => '0', --cts_rdo_invalid_trg,
			--
			--			FEE_TRG_STATUSBITS_OUT     => open,
			--			FEE_DATA_OUT               => open,
			--			FEE_DATA_WRITE_OUT         => open,
			--			FEE_DATA_FINISHED_OUT      => open

			CLK                        => clk_100_i,
			RESET                      => reset_i,
			TRIGGER_BUSY_OUT           => open,
			TIME_REFERENCE_OUT         => cts_rdo_trigger,
			ADDON_TRIGGERS_IN          => (others => '0'),
			ADDON_GROUP_ACTIVITY_OUT   => open,
			ADDON_GROUP_SELECTED_OUT   => open,
			EXT_TRIGGER_IN             => '0', --cts_ext_trigger, -- my local trigger
			EXT_STATUS_IN              => cts_ext_status,
			EXT_CONTROL_OUT            => cts_ext_control,
			EXT_HEADER_BITS_IN         => cts_ext_header,
			PERIPH_TRIGGER_IN          => periph_trigger,
			OUTPUT_MULTIPLEXERS_OUT    => open,
			CTS_TRG_SEND_OUT           => cts_trg_send,
			CTS_TRG_TYPE_OUT           => cts_trg_type,
			CTS_TRG_NUMBER_OUT         => cts_trg_number,
			CTS_TRG_INFORMATION_OUT    => cts_trg_information,
			CTS_TRG_RND_CODE_OUT       => cts_trg_code,
			CTS_TRG_STATUS_BITS_IN     => cts_trg_status_bits,
			CTS_TRG_BUSY_IN            => cts_trg_busy,
			CTS_IPU_SEND_OUT           => cts_ipu_send,
			CTS_IPU_TYPE_OUT           => cts_ipu_type,
			CTS_IPU_NUMBER_OUT         => cts_ipu_number,
			CTS_IPU_INFORMATION_OUT    => cts_ipu_information,
			CTS_IPU_RND_CODE_OUT       => cts_ipu_code,
			CTS_IPU_STATUS_BITS_IN     => cts_ipu_status_bits,
			CTS_IPU_BUSY_IN            => cts_ipu_busy,
			CTS_REGIO_ADDR_IN          => cts_regio_addr,
			CTS_REGIO_DATA_IN          => cts_regio_data_out,
			CTS_REGIO_READ_ENABLE_IN   => cts_regio_read,
			CTS_REGIO_WRITE_ENABLE_IN  => cts_regio_write,
			CTS_REGIO_DATA_OUT         => cts_regio_data_in,
			CTS_REGIO_DATAREADY_OUT    => cts_regio_dataready,
			CTS_REGIO_WRITE_ACK_OUT    => cts_regio_write_ack,
			CTS_REGIO_UNKNOWN_ADDR_OUT => cts_regio_unknown_addr,
			LVL1_TRG_DATA_VALID_IN     => cts_rdo_trg_data_valid,
			LVL1_VALID_TIMING_TRG_IN   => cts_rdo_valid_timing_trg,
			LVL1_VALID_NOTIMING_TRG_IN => cts_rdo_valid_notiming_trg,
			LVL1_INVALID_TRG_IN        => cts_rdo_invalid_trg,
			FEE_TRG_STATUSBITS_OUT     => cts_rdo_trg_status_bits_cts,
			FEE_DATA_OUT               => cts_rdo_data,
			FEE_DATA_WRITE_OUT         => cts_rdo_write,
			FEE_DATA_FINISHED_OUT      => cts_rdo_finished
		);

	periph_trigger <= (others => update_synced_qqq);

	THE_HUB : entity work.trb_net16_hub_streaming_port_sctrl_cts
		generic map(
			INIT_ADDRESS                  => x"F3C0",
			MII_NUMBER                    => 5, --INTERFACE_NUM,
			MII_IS_UPLINK                 => (0 => 1, others => 0),
			MII_IS_DOWNLINK               => (0 => 0, others => 1),
			MII_IS_UPLINK_ONLY            => (0 => 1, others => 0),
			--			MII_NUMBER                    => INTERFACE_NUM,
			--			MII_IS_UPLINK                 => IS_UPLINK,
			--			MII_IS_DOWNLINK               => IS_DOWNLINK,
			--			MII_IS_UPLINK_ONLY            => IS_UPLINK_ONLY,
			--HARDWARE_VERSION              => HARDWARE_INFO,
			INIT_ENDPOINT_ID              => x"0005",
			BROADCAST_BITMASK             => x"7E",
			CLOCK_FREQUENCY               => 100,
			USE_ONEWIRE                   => c_YES,
			BROADCAST_SPECIAL_ADDR        => x"35",
			RDO_ADDITIONAL_PORT           => 1, --cts_rdo_additional_ports,
			RDO_DATA_BUFFER_DEPTH         => 9,
			RDO_DATA_BUFFER_FULL_THRESH   => 2 ** 9 - 128,
			RDO_HEADER_BUFFER_DEPTH       => 9,
			RDO_HEADER_BUFFER_FULL_THRESH => 2 ** 9 - 16
		)
		port map(
			CLK                                    => clk_100_i,
			RESET                                  => reset_i,
			CLK_EN                                 => '1',

			-- Media interfacces ---------------------------------------------------------------
			MED_DATAREADY_OUT(5 * 1 - 1 downto 0)  => med_dataready_out,
			MED_DATA_OUT(5 * 16 - 1 downto 0)      => med_data_out,
			MED_PACKET_NUM_OUT(5 * 3 - 1 downto 0) => med_packet_num_out,
			MED_READ_IN(5 * 1 - 1 downto 0)        => (others => '1'),
			MED_DATAREADY_IN(5 * 1 - 1 downto 0)   => (others => '0'),
			MED_DATA_IN(5 * 16 - 1 downto 0)       => (others => '0'),
			MED_PACKET_NUM_IN(5 * 3 - 1 downto 0)  => (others => '0'),
			MED_READ_OUT(5 * 1 - 1 downto 0)       => med_read_out,
			MED_STAT_OP(5 * 16 - 1 downto 0)       => med_stat_op,
			MED_CTRL_OP(5 * 16 - 1 downto 0)       => med_ctrl_op,

			-- Gbe Read-out Path ---------------------------------------------------------------
			--Event information coming from CTS for GbE
			GBE_CTS_NUMBER_OUT                     => gbe_cts_number,
			GBE_CTS_CODE_OUT                       => gbe_cts_code,
			GBE_CTS_INFORMATION_OUT                => gbe_cts_information,
			GBE_CTS_READOUT_TYPE_OUT               => gbe_cts_readout_type,
			GBE_CTS_START_READOUT_OUT              => gbe_cts_start_readout,
			--Information sent to CTS
			GBE_CTS_READOUT_FINISHED_IN            => gbe_cts_readout_finished,
			GBE_CTS_STATUS_BITS_IN                 => gbe_cts_status_bits,
			-- Data from Frontends
			GBE_FEE_DATA_OUT                       => gbe_fee_data,
			GBE_FEE_DATAREADY_OUT                  => gbe_fee_dataready,
			GBE_FEE_READ_IN                        => gbe_fee_read,
			GBE_FEE_STATUS_BITS_OUT                => gbe_fee_status_bits,
			GBE_FEE_BUSY_OUT                       => gbe_fee_busy,

			-- CTS Request Sending -------------------------------------------------------------
			--LVL1 trigger
			CTS_TRG_SEND_IN                        => cts_trg_send,
			CTS_TRG_TYPE_IN                        => cts_trg_type,
			CTS_TRG_NUMBER_IN                      => cts_trg_number,
			CTS_TRG_INFORMATION_IN                 => cts_trg_information,
			CTS_TRG_RND_CODE_IN                    => cts_trg_code,
			CTS_TRG_STATUS_BITS_OUT                => cts_trg_status_bits,
			CTS_TRG_BUSY_OUT                       => cts_trg_busy,
			--IPU Channel
			CTS_IPU_SEND_IN                        => cts_ipu_send,
			CTS_IPU_TYPE_IN                        => cts_ipu_type,
			CTS_IPU_NUMBER_IN                      => cts_ipu_number,
			CTS_IPU_INFORMATION_IN                 => cts_ipu_information,
			CTS_IPU_RND_CODE_IN                    => cts_ipu_code,
			-- Receiver port
			CTS_IPU_STATUS_BITS_OUT                => cts_ipu_status_bits,
			CTS_IPU_BUSY_OUT                       => cts_ipu_busy,

			-- CTS Data Readout ----------------------------------------------------------------
			--Trigger to CTS out
			RDO_TRIGGER_IN                         => cts_rdo_trigger,
			RDO_TRG_DATA_VALID_OUT                 => open, --cts_rdo_trg_data_valid,
			RDO_VALID_TIMING_TRG_OUT               => cts_rdo_valid_timing_trg,
			RDO_VALID_NOTIMING_TRG_OUT             => open, --cts_rdo_valid_notiming_trg,
			RDO_INVALID_TRG_OUT                    => cts_rdo_invalid_trg,
			RDO_TRG_TYPE_OUT                       => open, --cts_rdo_trg_type,
			RDO_TRG_CODE_OUT                       => open, --cts_rdo_trg_code,
			RDO_TRG_INFORMATION_OUT                => open, --cts_rdo_trg_information,
			RDO_TRG_NUMBER_OUT                     => open, --cts_rdo_trg_number,

			--Data from CTS in
			RDO_TRG_STATUSBITS_IN                  => cts_rdo_trg_status_bits_cts,
			RDO_DATA_IN                            => cts_rdo_data,
			RDO_DATA_WRITE_IN                      => cts_rdo_write,
			RDO_DATA_FINISHED_IN                   => cts_rdo_finished,
			--Data from additional modules
			RDO_ADDITIONAL_STATUSBITS_IN           => cts_rdo_trg_status_bits_additional,
			RDO_ADDITIONAL_DATA                    => cts_rdo_additional_data,
			RDO_ADDITIONAL_WRITE                   => cts_rdo_additional_write,
			RDO_ADDITIONAL_FINISHED                => cts_rdo_additional_finished,

			-- Slow Control --------------------------------------------------------------------
			COMMON_STAT_REGS                       => open,
			COMMON_CTRL_REGS                       => open,
			ONEWIRE                                => open,
			ONEWIRE_MONITOR_IN                     => '0',
			MY_ADDRESS_OUT                         => open,
			UNIQUE_ID_OUT                          => open,
			TIMER_TICKS_OUT                        => open,
			EXTERNAL_SEND_RESET                    => '0',
			REGIO_ADDR_OUT                         => open,
			REGIO_READ_ENABLE_OUT                  => open,
			REGIO_WRITE_ENABLE_OUT                 => open,
			REGIO_DATA_OUT                         => open,
			REGIO_DATA_IN                          => (others => '0'),
			REGIO_DATAREADY_IN                     => '1',
			REGIO_NO_MORE_DATA_IN                  => '0',
			REGIO_WRITE_ACK_IN                     => '0',
			REGIO_UNKNOWN_ADDR_IN                  => '0',
			REGIO_TIMEOUT_OUT                      => open,

			--Gbe Sctrl Input
			GSC_INIT_DATAREADY_IN                  => '0',
			GSC_INIT_DATA_IN                       => (others => '0'),
			GSC_INIT_PACKET_NUM_IN                 => (others => '0'),
			GSC_INIT_READ_OUT                      => open,
			GSC_REPLY_DATAREADY_OUT                => open,
			GSC_REPLY_DATA_OUT                     => open,
			GSC_REPLY_PACKET_NUM_OUT               => open,
			GSC_REPLY_READ_IN                      => '1',
			GSC_BUSY_OUT                           => open,

			--status and control ports
			HUB_STAT_CHANNEL                       => open,
			HUB_STAT_GEN                           => open,
			MPLEX_CTRL                             => (others => '0'),
			MPLEX_STAT                             => open,
			STAT_REGS                              => open,
			STAT_CTRL_REGS                         => open,

			--Fixed status and control ports
			STAT_DEBUG                             => open,
			CTRL_DEBUG                             => (others => '0')
		);

	soda_trigger : entity work.soda_cts_module
		port map(
			--			CLK            => clk_100_i,
			--			RESET_IN       => reset_i,
			--			EXT_TRG_IN     => update_synced,
			--			TRG_SYNC_OUT   => cts_ext_trigger,
			--			TRIGGER_IN     => cts_rdo_trg_data_valid,
			--			DATA_OUT       => open,
			--			WRITE_OUT      => open,
			--			FINISHED_OUT   => open,
			--			STATUSBIT_OUT  => open,
			--			CONTROL_REG_IN => (others => '0'),
			--			STATUS_REG_OUT => open,
			--			HEADER_REG_OUT => open,
			--			DEBUG          => open

			CLK            => clk_100_i,
			RESET_IN       => reset_i,
			EXT_TRG_IN     => update_synced_qqq,
			TRG_SYNC_OUT   => cts_ext_trigger,
			TRIGGER_IN     => cts_rdo_trg_data_valid,
			DATA_OUT       => cts_rdo_additional_data,
			WRITE_OUT      => cts_rdo_additional_write(0),
			FINISHED_OUT   => cts_rdo_additional_finished(0),
			STATUSBIT_OUT  => cts_rdo_trg_status_bits_additional,
			CONTROL_REG_IN => cts_ext_control,
			STATUS_REG_OUT => cts_ext_status,
			HEADER_REG_OUT => cts_ext_header,
			DEBUG          => cts_ext_debug
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
			     CFG_EVENT_SIZE_IN       => event_size, --x"0100",
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
			superburst_update        => update_synced_qqq,

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
			TX_DATA         => tx_data,
			TX_K            => tx_k,
			DATA_IN_ALLOWED => data64b_muxed_allowed_S,
			DATA_IN         => data64b_muxed,
			DATA_IN_WRITE   => data64b_muxed_write,
			DATA_IN_FIRST   => data64b_muxed_first,
			DATA_IN_LAST    => data64b_muxed_last,
			DATA_IN_ERROR   => data64b_muxed_error
		);

	process(clk_100_i)
	begin
		if rising_edge(clk_100_i) then
			if (reset_i = '1') then
				start_ctr <= '0';
			elsif (tx_k = '1' and tx_data = x"dc") then
				start_ctr <= '1';
			elsif (tx_k = '1' and tx_data = x"fc") then
				start_ctr <= '0';
				assert (std_logic_vector(to_unsigned(data_ctr, 16)) = current_size) report "DDAAAAMMNNNN" severity error;
			else
				start_ctr <= start_ctr;
			end if;
		end if;
	end process;

	process(clk_100_i)
	begin
		if rising_edge(clk_100_i) then
			if (start_ctr = '0') then
				data_ctr <= 0;
			else
				data_ctr <= data_ctr + 1;
			end if;
		end if;
	end process;

	process(clk_100_i)
	begin
		if rising_edge(clk_100_i) then
			if (start_ctr = '0') then
				current_size <= x"0000";
			elsif (data_ctr = 2) then
				current_size(15 downto 8) <= tx_data;
			elsif (data_ctr = 3) then
				current_size(7 downto 0) <= tx_data;
			else
				current_size <= current_size;
			end if;
		end if;
	end process;

end architecture;
