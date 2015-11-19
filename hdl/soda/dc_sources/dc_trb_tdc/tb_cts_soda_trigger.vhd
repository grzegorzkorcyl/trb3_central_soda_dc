library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb3_components.all;

entity tb_cts_soda_trigger is
end entity;

architecture arch1 of tb_cts_soda_trigger is
	signal clk_100_i, reset_i : std_logic;
	signal cts_ext_trigger : std_logic;
	signal cts_rdo_valid_notiming_trg : std_logic;
	signal cts_rdo_trg_data_valid : std_logic;

begin
	process
	begin
		clk_100_i <= '1';
		wait for 5 ns;
		clk_100_i <= '0';
		wait for 5 ns;
	end process;

	process
	begin
		reset_i <= '1';
		
		cts_rdo_trg_data_valid <= '0';
		cts_rdo_valid_notiming_trg <= '0';
		cts_ext_trigger <= '0';
		
		wait for 100 ns;
		reset_i <= '0';
		
		wait for 1 us;
		cts_ext_trigger <= '1';
		wait for 100 ns;
		cts_ext_trigger <= '0';
		wait for 20 ns;
		wait until rising_edge(clk_100_i);
		cts_rdo_valid_notiming_trg <= '1';
		wait until rising_edge(clk_100_i);
		cts_rdo_valid_notiming_trg <= '0';
		wait for 100 ns;
		wait until rising_edge(clk_100_i);
		cts_rdo_trg_data_valid <= '1';
		
		wait;
	end process;

	THE_CTS : entity work.CTS
		generic map(
			EXTERNAL_TRIGGER_ID  => x"60", -- fill in trigger logic enumeration id of external trigger logic

			TRIGGER_COIN_COUNT   => 1, --TRIGGER_COIN_COUNT,
			TRIGGER_PULSER_COUNT => 1, --TRIGGER_PULSER_COUNT,
			TRIGGER_RAND_PULSER  => 1, --TRIGGER_RAND_PULSER,
			TRIGGER_INPUT_COUNT  => 1,  -- obsolete! now all inputs are routed via an input multiplexer!
			TRIGGER_ADDON_COUNT  => 1, --TRIGGER_ADDON_COUNT,
			PERIPH_TRIGGER_COUNT => 1, --PERIPH_TRIGGER_COUNT,
			OUTPUT_MULTIPLEXERS  => 0, --CTS_OUTPUT_MULTIPLEXERS,
			ADDON_LINE_COUNT     => 1, --CTS_ADDON_LINE_COUNT,
			ADDON_GROUPS         => 1,
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
			CTS_IPU_BUSY_IN            => '0', --cts_ipu_busy,
			
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

end architecture;
