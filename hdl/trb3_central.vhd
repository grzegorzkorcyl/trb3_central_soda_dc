library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

-- synopsys translate_off
library ecp3;
use ecp3.components.all;
-- synopsys translate_on   
library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.trb_net16_hub_func.all;
use work.version.all;
use work.tdc_components.TDC;
use work.tdc_version.all;
use work.trb_net_gbe_components.all;

use work.cbmnet_interface_pkg.all;

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
use work.panda_package.all;

entity trb3_central is
	port(
		--Clocks
		CLK_EXT                              : in    std_logic_vector(4 downto 3); --from RJ45
		CLK_GPLL_LEFT                        : in    std_logic; --Clock Manager 2/9, 200 MHz  <-- MAIN CLOCK
		CLK_GPLL_RIGHT                       : in    std_logic; --Clock Manager 1/9, 125 MHz  <-- for GbE
		CLK_PCLK_LEFT                        : in    std_logic; --Clock Fan-out, 200/400 MHz 
		CLK_PCLK_RIGHT                       : in    std_logic; --Clock Fan-out, 200/400 MHz 

		--Trigger
		TRIGGER_LEFT                         : in    std_logic; --left side trigger input from fan-out
		TRIGGER_RIGHT                        : in    std_logic; --right side trigger input from fan-out
		TRIGGER_EXT                          : in    std_logic_vector(4 downto 2); --additional trigger from RJ45
		TRIGGER_OUT                          : out   std_logic; --trigger to second input of fan-out
		TRIGGER_OUT2                         : out   std_logic;

		--Serdes
		CLK_SERDES_INT_LEFT                  : in    std_logic; --Clock Manager 2/0, 200 MHz, only in case of problems
		CLK_SERDES_INT_RIGHT                 : in    std_logic; --Clock Manager 1/0, off, 125 MHz possible

		--SFP
		SFP_RX_P                             : in    std_logic_vector(9 downto 1);
		SFP_RX_N                             : in    std_logic_vector(9 downto 1);
		SFP_TX_P                             : out   std_logic_vector(9 downto 1);
		SFP_TX_N                             : out   std_logic_vector(9 downto 1);
		SFP_TX_FAULT                         : in    std_logic_vector(8 downto 1); --TX broken
		SFP_RATE_SEL                         : out   std_logic_vector(8 downto 1); --not supported by our SFP
		SFP_LOS                              : in    std_logic_vector(8 downto 1); --Loss of signal
		SFP_MOD0                             : in    std_logic_vector(8 downto 1); --SFP present
		SFP_MOD1                             : out   std_logic_vector(8 downto 1); --I2C interface
		SFP_MOD2                             : inout std_logic_vector(8 downto 1); --I2C interface
		SFP_TXDIS                            : out   std_logic_vector(8 downto 1); --disable TX

		--Clock and Trigger Control
		TRIGGER_SELECT                       : out   std_logic; --trigger select for fan-out. 0: external, 1: signal from FPGA5
		CLOCK_SELECT                         : out   std_logic; --clock select for fan-out. 0: 200MHz, 1: external from RJ45
		CLK_MNGR1_USER                       : inout std_logic_vector(3 downto 0); --I/O lines to clock manager 1
		CLK_MNGR2_USER                       : inout std_logic_vector(3 downto 0); --I/O lines to clock manager 1

		--Inter-FPGA Communication
		FPGA1_COMM                           : inout std_logic_vector(11 downto 0);
		FPGA2_COMM                           : inout std_logic_vector(11 downto 0);
		FPGA3_COMM                           : inout std_logic_vector(11 downto 0);
		FPGA4_COMM                           : inout std_logic_vector(11 downto 0);
		-- on all FPGAn_COMM:  --Bit 0/1 output, serial link TX active
		--Bit 2/3 input, serial link RX active
		--others yet undefined
		FPGA1_TTL                            : inout std_logic_vector(3 downto 0);
		FPGA2_TTL                            : inout std_logic_vector(3 downto 0);
		FPGA3_TTL                            : inout std_logic_vector(3 downto 0);
		FPGA4_TTL                            : inout std_logic_vector(3 downto 0);
		--only for not timing-sensitive signals

		--Communication to small addons
		FPGA1_CONNECTOR                      : inout std_logic_vector(7 downto 0); --Bit 2-3: LED for SFP3/4
		FPGA2_CONNECTOR                      : inout std_logic_vector(7 downto 0); --Bit 2-3: LED for SFP7/8
		FPGA3_CONNECTOR                      : inout std_logic_vector(7 downto 0); --Bit 0-1: LED for SFP5/6 
		FPGA4_CONNECTOR                      : inout std_logic_vector(7 downto 0); --Bit 0-1: LED for SFP1/2
		--Bit 0-3 connected to LED by default, two on each side

		--AddOn connector
		ECL_IN                               : in    std_logic_vector(3 downto 0);
		NIM_IN                               : in    std_logic_vector(1 downto 0);
		JIN1                                 : in    std_logic_vector(3 downto 0);
		JIN2                                 : in    std_logic_vector(3 downto 0);
		JINLVDS                              : in    std_logic_vector(15 downto 0); --No LVDS, just TTL!

		DISCRIMINATOR_IN                     : in    std_logic_vector(1 downto 0);
		PWM_OUT                              : out   std_logic_vector(1 downto 0);

		JOUT1                                : out   std_logic_vector(3 downto 0);
		JOUT2                                : out   std_logic_vector(3 downto 0);
		JOUTLVDS                             : out   std_logic_vector(7 downto 0);
		JTTL                                 : inout std_logic_vector(15 downto 0);
		TRG_FANOUT_ADDON                     : out   std_logic;

		LED_BANK                             : out   std_logic_vector(7 downto 0);
		LED_RJ_GREEN                         : out   std_logic_vector(5 downto 0);
		LED_RJ_RED                           : out   std_logic_vector(5 downto 0);
		LED_FAN_GREEN                        : out   std_logic;
		LED_FAN_ORANGE                       : out   std_logic;
		LED_FAN_RED                          : out   std_logic;
		LED_FAN_YELLOW                       : out   std_logic;

		--Flash ROM & Reboot
		FLASH_CLK                            : out   std_logic;
		FLASH_CS                             : out   std_logic;
		FLASH_DIN                            : out   std_logic;
		FLASH_DOUT                           : in    std_logic;
		PROGRAMN                             : out   std_logic := '1'; --reboot FPGA

		--Misc
		ENPIRION_CLOCK                       : out   std_logic; --Clock for power supply, not necessary, floating
		TEMPSENS                             : inout std_logic; --Temperature Sensor
		LED_CLOCK_GREEN                      : out   std_logic;
		LED_CLOCK_RED                        : out   std_logic;
		LED_GREEN                            : out   std_logic;
		LED_ORANGE                           : out   std_logic;
		LED_RED                              : out   std_logic;
		LED_TRIGGER_GREEN                    : out   std_logic;
		LED_TRIGGER_RED                      : out   std_logic;
		LED_YELLOW                           : out   std_logic;

		--Test Connectors
		TEST_LINE                            : out   std_logic_vector(31 downto 0);

		-- SODA pinout
		SODA_SRC_TXP_OUT, SODA_SRC_TXN_OUT   : out   std_logic;
		SODA_SRC_RXP_IN, SODA_SRC_RXN_IN     : in    std_logic;
		SODA_ENDP_RXP_IN, SODA_ENDP_RXN_IN   : in    std_logic_vector(3 downto 0);
		SODA_ENDP_TXP_OUT, SODA_ENDP_TXN_OUT : out   std_logic_vector(3 downto 0);

		CODE_LINE                            : in    std_logic_vector(1 downto 0)
	);

	attribute syn_useioff : boolean;
	--no IO-FF for LEDs relaxes timing constraints
	attribute syn_useioff of LED_CLOCK_GREEN : signal is false;
	attribute syn_useioff of LED_CLOCK_RED : signal is false;
	attribute syn_useioff of LED_TRIGGER_GREEN : signal is false;
	attribute syn_useioff of LED_TRIGGER_RED : signal is false;
	attribute syn_useioff of LED_GREEN : signal is false;
	attribute syn_useioff of LED_ORANGE : signal is false;
	attribute syn_useioff of LED_RED : signal is false;
	attribute syn_useioff of LED_YELLOW : signal is false;
	attribute syn_useioff of LED_FAN_GREEN : signal is false;
	attribute syn_useioff of LED_FAN_ORANGE : signal is false;
	attribute syn_useioff of LED_FAN_RED : signal is false;
	attribute syn_useioff of LED_FAN_YELLOW : signal is false;
	attribute syn_useioff of LED_BANK : signal is false;
	attribute syn_useioff of LED_RJ_GREEN : signal is false;
	attribute syn_useioff of LED_RJ_RED : signal is false;
	attribute syn_useioff of FPGA1_TTL : signal is false;
	attribute syn_useioff of FPGA2_TTL : signal is false;
	attribute syn_useioff of FPGA3_TTL : signal is false;
	attribute syn_useioff of FPGA4_TTL : signal is false;
	attribute syn_useioff of SFP_TXDIS : signal is false;
	attribute syn_useioff of PROGRAMN : signal is false;

	--important signals _with_ IO-FF
	attribute syn_useioff of FLASH_CLK : signal is true;
	attribute syn_useioff of FLASH_CS : signal is true;
	attribute syn_useioff of FLASH_DIN : signal is true;
	attribute syn_useioff of FLASH_DOUT : signal is true;
	attribute syn_useioff of FPGA1_COMM : signal is true;
	attribute syn_useioff of FPGA2_COMM : signal is true;
	attribute syn_useioff of FPGA3_COMM : signal is true;
	attribute syn_useioff of FPGA4_COMM : signal is true;
	attribute syn_useioff of CLK_MNGR1_USER : signal is false;
	attribute syn_useioff of CLK_MNGR2_USER : signal is false;
	attribute syn_useioff of TRIGGER_SELECT : signal is false;
	attribute syn_useioff of CLOCK_SELECT : signal is false;

	attribute syn_useioff of CLK_EXT : signal is false;

	-- no FF for CTS addon ... relax timing
	attribute syn_useioff of ECL_IN : signal is false;
	attribute syn_useioff of NIM_IN : signal is false;
	attribute syn_useioff of JIN1 : signal is false;
	attribute syn_useioff of JIN2 : signal is false;
	attribute syn_useioff of JINLVDS : signal is false;
	attribute syn_useioff of DISCRIMINATOR_IN : signal is false;
	attribute syn_useioff of PWM_OUT : signal is false;
	attribute syn_useioff of JOUT1 : signal is false;
	attribute syn_useioff of JOUT2 : signal is false;
	attribute syn_useioff of JOUTLVDS : signal is false;
	attribute syn_useioff of JTTL : signal is false;
	attribute syn_useioff of TRG_FANOUT_ADDON : signal is false;
	attribute syn_useioff of LED_BANK : signal is false;
	attribute syn_useioff of LED_RJ_GREEN : signal is false;
	attribute syn_useioff of LED_RJ_RED : signal is false;
	attribute syn_useioff of LED_FAN_GREEN : signal is false;
	attribute syn_useioff of LED_FAN_ORANGE : signal is false;
	attribute syn_useioff of LED_FAN_RED : signal is false;
	attribute syn_useioff of LED_FAN_YELLOW : signal is false;

	attribute syn_keep : boolean;
	attribute syn_keep of CLK_EXT : signal is true;
	attribute syn_keep of CLK_GPLL_LEFT : signal is true;
	attribute syn_keep of CLK_GPLL_RIGHT : signal is true;
	attribute syn_keep of CLK_PCLK_LEFT : signal is true;
	attribute syn_keep of CLK_PCLK_RIGHT : signal is true;
	attribute syn_keep of TRIGGER_LEFT : signal is true;
	attribute syn_keep of TRIGGER_RIGHT : signal is true;
	attribute syn_keep of TRIGGER_EXT : signal is true;
	attribute syn_keep of TRIGGER_OUT : signal is true;
	attribute syn_keep of TRIGGER_OUT2 : signal is true;
	attribute syn_keep of CLK_SERDES_INT_LEFT : signal is true;
	attribute syn_keep of CLK_SERDES_INT_RIGHT : signal is true;
	attribute syn_keep of SFP_RX_P : signal is true;
	attribute syn_keep of SFP_RX_N : signal is true;
	attribute syn_keep of SFP_TX_P : signal is true;
	attribute syn_keep of SFP_TX_N : signal is true;
	attribute syn_keep of SFP_TX_FAULT : signal is true;
	attribute syn_keep of SFP_RATE_SEL : signal is true;
	attribute syn_keep of SFP_LOS : signal is true;
	attribute syn_keep of SFP_MOD0 : signal is true;
	attribute syn_keep of SFP_MOD1 : signal is true;
	attribute syn_keep of SFP_MOD2 : signal is true;
	attribute syn_keep of SFP_TXDIS : signal is true;
	attribute syn_keep of TRIGGER_SELECT : signal is true;
	attribute syn_keep of CLOCK_SELECT : signal is true;
	attribute syn_keep of CLK_MNGR1_USER : signal is true;
	attribute syn_keep of CLK_MNGR2_USER : signal is true;
	attribute syn_keep of FPGA1_COMM : signal is true;
	attribute syn_keep of FPGA2_COMM : signal is true;
	attribute syn_keep of FPGA3_COMM : signal is true;
	attribute syn_keep of FPGA4_COMM : signal is true;
	attribute syn_keep of FPGA1_TTL : signal is true;
	attribute syn_keep of FPGA2_TTL : signal is true;
	attribute syn_keep of FPGA3_TTL : signal is true;
	attribute syn_keep of FPGA4_TTL : signal is true;
	attribute syn_keep of FPGA1_CONNECTOR : signal is true;
	attribute syn_keep of FPGA2_CONNECTOR : signal is true;
	attribute syn_keep of FPGA3_CONNECTOR : signal is true;
	attribute syn_keep of FPGA4_CONNECTOR : signal is true;
	attribute syn_keep of ECL_IN : signal is true;
	attribute syn_keep of NIM_IN : signal is true;
	attribute syn_keep of JIN1 : signal is true;
	attribute syn_keep of JIN2 : signal is true;
	attribute syn_keep of JINLVDS : signal is true;
	attribute syn_keep of DISCRIMINATOR_IN : signal is true;
	attribute syn_keep of PWM_OUT : signal is true;
	attribute syn_keep of JOUT1 : signal is true;
	attribute syn_keep of JOUT2 : signal is true;
	attribute syn_keep of JOUTLVDS : signal is true;
	attribute syn_keep of JTTL : signal is true;
	attribute syn_keep of TRG_FANOUT_ADDON : signal is true;
	attribute syn_keep of LED_BANK : signal is true;
	attribute syn_keep of LED_RJ_GREEN : signal is true;
	attribute syn_keep of LED_RJ_RED : signal is true;
	attribute syn_keep of LED_FAN_GREEN : signal is true;
	attribute syn_keep of LED_FAN_ORANGE : signal is true;
	attribute syn_keep of LED_FAN_RED : signal is true;
	attribute syn_keep of LED_FAN_YELLOW : signal is true;
	attribute syn_keep of FLASH_CLK : signal is true;
	attribute syn_keep of FLASH_CS : signal is true;
	attribute syn_keep of FLASH_DIN : signal is true;
	attribute syn_keep of FLASH_DOUT : signal is true;
	attribute syn_keep of PROGRAMN : signal is true;
	attribute syn_keep of ENPIRION_CLOCK : signal is true;
	attribute syn_keep of TEMPSENS : signal is true;
	attribute syn_keep of LED_CLOCK_GREEN : signal is true;
	attribute syn_keep of LED_CLOCK_RED : signal is true;
	attribute syn_keep of LED_GREEN : signal is true;
	attribute syn_keep of LED_ORANGE : signal is true;
	attribute syn_keep of LED_RED : signal is true;
	attribute syn_keep of LED_TRIGGER_GREEN : signal is true;
	attribute syn_keep of LED_TRIGGER_RED : signal is true;
	attribute syn_keep of LED_YELLOW : signal is true;
	attribute syn_keep of TEST_LINE : signal is true;
end entity;

architecture trb3_central_arch of trb3_central is
	attribute syn_keep : boolean;
	attribute syn_preserve : boolean;

	signal clk_100_i : std_logic;       --clock for main logic, 100 MHz, via Clock Manager and internal PLL
	signal clk_200_i : std_logic;       --clock for logic at 200 MHz, via Clock Manager and bypassed PLL
	signal clk_125_i : std_logic;       --125 MHz, via Clock Manager and bypassed PLL
	signal osc_int   : std_logic;       -- clock for calibrating the tdc, 2.5 MHz, via internal osscilator
	signal pll_lock  : std_logic;       --Internal PLL locked. E.g. used to reset all internal logic.
	signal clear_i   : std_logic;
	signal reset_i   : std_logic;
	signal GSR_N     : std_logic;
	attribute syn_keep of GSR_N : signal is true;
	attribute syn_preserve of GSR_N : signal is true;

	--FPGA Test
	signal time_counter, time_counter2 : unsigned(31 downto 0);

	--Media Interface
	signal med_stat_op        : std_logic_vector(7 * 16 - 1 downto 0);
	signal med_ctrl_op        : std_logic_vector(7 * 16 - 1 downto 0);
	signal med_stat_debug     : std_logic_vector(7 * 64 - 1 downto 0);
	signal med_ctrl_debug     : std_logic_vector(7 * 64 - 1 downto 0);
	signal med_data_out       : std_logic_vector(7 * 16 - 1 downto 0);
	signal med_packet_num_out : std_logic_vector(7 * 3 - 1 downto 0);
	signal med_dataready_out  : std_logic_vector(7 * 1 - 1 downto 0);
	signal med_read_out       : std_logic_vector(7 * 1 - 1 downto 0);
	signal med_data_in        : std_logic_vector(7 * 16 - 1 downto 0);
	signal med_packet_num_in  : std_logic_vector(7 * 3 - 1 downto 0);
	signal med_dataready_in   : std_logic_vector(7 * 1 - 1 downto 0);
	signal med_read_in        : std_logic_vector(7 * 1 - 1 downto 0);

	--Hub
	signal common_stat_regs       : std_logic_vector(std_COMSTATREG * 32 - 1 downto 0);
	signal common_ctrl_regs       : std_logic_vector(std_COMCTRLREG * 32 - 1 downto 0);
	signal my_address             : std_logic_vector(16 - 1 downto 0);
	signal regio_addr_out         : std_logic_vector(16 - 1 downto 0);
	signal regio_read_enable_out  : std_logic;
	signal regio_write_enable_out : std_logic;
	signal regio_data_out         : std_logic_vector(32 - 1 downto 0);
	signal regio_data_in          : std_logic_vector(32 - 1 downto 0);
	signal regio_dataready_in     : std_logic;
	signal regio_no_more_data_in  : std_logic;
	signal regio_write_ack_in     : std_logic;
	signal regio_unknown_addr_in  : std_logic;
	signal regio_timeout_out      : std_logic;

	signal spictrl_read_en  : std_logic;
	signal spictrl_write_en : std_logic;
	signal spictrl_data_in  : std_logic_vector(31 downto 0);
	signal spictrl_addr     : std_logic;
	signal spictrl_data_out : std_logic_vector(31 downto 0);
	signal spictrl_ack      : std_logic;
	signal spictrl_busy     : std_logic;
	signal spimem_read_en   : std_logic;
	signal spimem_write_en  : std_logic;
	signal spimem_data_in   : std_logic_vector(31 downto 0);
	signal spimem_addr      : std_logic_vector(5 downto 0);
	signal spimem_data_out  : std_logic_vector(31 downto 0);
	signal spimem_ack       : std_logic;

	signal spi_bram_addr : std_logic_vector(7 downto 0);
	signal spi_bram_wr_d : std_logic_vector(7 downto 0);
	signal spi_bram_rd_d : std_logic_vector(7 downto 0);
	signal spi_bram_we   : std_logic;

	signal hub_cts_number           : std_logic_vector(15 downto 0);
	signal hub_cts_code             : std_logic_vector(7 downto 0);
	signal hub_cts_information      : std_logic_vector(7 downto 0);
	signal hub_cts_start_readout    : std_logic;
	signal hub_cts_readout_type     : std_logic_vector(3 downto 0);
	signal hub_cts_readout_finished : std_logic;
	signal hub_cts_status_bits      : std_logic_vector(31 downto 0);
	signal hub_fee_data             : std_logic_vector(15 downto 0);
	signal hub_fee_dataready        : std_logic;
	signal hub_fee_read             : std_logic;
	signal hub_fee_status_bits      : std_logic_vector(31 downto 0);
	signal hub_fee_busy             : std_logic;

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

	signal stage_stat_regs : std_logic_vector(31 downto 0);
	signal stage_ctrl_regs : std_logic_vector(31 downto 0) := (others => '0');

	signal mb_stat_reg_data_wr : std_logic_vector(31 downto 0);
	signal mb_stat_reg_data_rd : std_logic_vector(31 downto 0);
	signal mb_stat_reg_read    : std_logic;
	signal mb_stat_reg_write   : std_logic;
	signal mb_stat_reg_ack     : std_logic;
	signal mb_ip_mem_addr      : std_logic_vector(15 downto 0); -- only [7:0] in used
	signal mb_ip_mem_data_wr   : std_logic_vector(31 downto 0);
	signal mb_ip_mem_data_rd   : std_logic_vector(31 downto 0);
	signal mb_ip_mem_read      : std_logic;
	signal mb_ip_mem_write     : std_logic;
	signal mb_ip_mem_ack       : std_logic;
	signal ip_cfg_mem_clk      : std_logic;
	signal ip_cfg_mem_addr     : std_logic_vector(7 downto 0);
	signal ip_cfg_mem_data     : std_logic_vector(31 downto 0) := (others => '0');
	signal ctrl_reg_addr       : std_logic_vector(15 downto 0);
	signal gbe_stp_reg_addr    : std_logic_vector(15 downto 0);
	signal gbe_stp_data        : std_logic_vector(31 downto 0);
	signal gbe_stp_reg_ack     : std_logic;
	signal gbe_stp_reg_data_wr : std_logic_vector(31 downto 0);
	signal gbe_stp_reg_read    : std_logic;
	signal gbe_stp_reg_write   : std_logic;
	signal gbe_stp_reg_data_rd : std_logic_vector(31 downto 0);

	signal debug : std_logic_vector(63 downto 0);

	signal next_reset, make_reset_via_network_q : std_logic;
	signal reset_counter                        : std_logic_vector(11 downto 0);
	signal link_ok                              : std_logic;

	signal gsc_init_data, gsc_reply_data             : std_logic_vector(15 downto 0);
	signal gsc_init_read, gsc_reply_read             : std_logic;
	signal gsc_init_dataready, gsc_reply_dataready   : std_logic;
	signal gsc_init_packet_num, gsc_reply_packet_num : std_logic_vector(2 downto 0);
	signal gsc_busy                                  : std_logic;
	signal mc_unique_id                              : std_logic_vector(63 downto 0);
	signal trb_reset_in                              : std_logic;
	signal reset_via_gbe                             : std_logic;
	signal reset_via_gbe_delayed                     : std_logic_vector(2 downto 0);
	signal reset_i_temp                              : std_logic;

	signal cts_rdo_trigger            : std_logic;
	signal cts_rdo_trg_data_valid     : std_logic;
	signal cts_rdo_valid_timing_trg   : std_logic;
	signal cts_rdo_valid_notiming_trg : std_logic;
	signal cts_rdo_invalid_trg        : std_logic;

	signal cts_rdo_trg_status_bits, cts_rdo_trg_status_bits_cts : std_logic_vector(31 downto 0) := (others => '0');
	signal cts_rdo_data                                         : std_logic_vector(31 downto 0);
	signal cts_rdo_write                                        : std_logic;
	signal cts_rdo_finished                                     : std_logic;

	signal cts_ext_trigger : std_logic;
	signal cts_ext_status  : std_logic_vector(31 downto 0) := (others => '0');
	signal cts_ext_control : std_logic_vector(31 downto 0);
	signal cts_ext_debug   : std_logic_vector(31 downto 0);
	signal cts_ext_header  : std_logic_vector(1 downto 0);

	signal cts_rdo_additional_data            : std_logic_vector(32 * cts_rdo_additional_ports - 1 downto 0);
	signal cts_rdo_additional_write           : std_logic_vector(cts_rdo_additional_ports - 1 downto 0)      := (others => '0');
	signal cts_rdo_additional_finished        : std_logic_vector(cts_rdo_additional_ports - 1 downto 0)      := (others => '1');
	signal cts_rdo_trg_status_bits_additional : std_logic_vector(32 * cts_rdo_additional_ports - 1 downto 0) := (others => '0');

	signal cts_rdo_additional : readout_tx_array_t(0 to cts_rdo_additional_ports - 1);

	signal cts_rdo_trg_type        : std_logic_vector(3 downto 0);
	signal cts_rdo_trg_code        : std_logic_vector(7 downto 0);
	signal cts_rdo_trg_information : std_logic_vector(23 downto 0);
	signal cts_rdo_trg_number      : std_logic_vector(15 downto 0);

	constant CTS_ADDON_LINE_COUNT    : integer := 38;
	constant CTS_OUTPUT_MULTIPLEXERS : integer := 8;
	constant CTS_OUTPUT_INPUTS       : integer := 16;

	signal cts_addon_triggers_in                      : std_logic_vector(CTS_ADDON_LINE_COUNT - 1 downto 0);
	signal cts_addon_activity_i, cts_addon_selected_i : std_logic_vector(6 downto 0);

	signal cts_periph_trigger_i      : std_logic_vector(19 downto 0);
	signal cts_output_multiplexers_i : std_logic_vector(CTS_OUTPUT_MULTIPLEXERS - 1 downto 0);

	signal cts_periph_lines_i : std_logic_vector(CTS_OUTPUT_INPUTS - 1 downto 0);

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

	signal cts_regio_addr         : std_logic_vector(15 downto 0);
	signal cts_regio_read         : std_logic;
	signal cts_regio_write        : std_logic;
	signal cts_regio_data_out     : std_logic_vector(31 downto 0);
	signal cts_regio_data_in      : std_logic_vector(31 downto 0);
	signal cts_regio_dataready    : std_logic;
	signal cts_regio_no_more_data : std_logic;
	signal cts_regio_write_ack    : std_logic;
	signal cts_regio_unknown_addr : std_logic;

	signal cts_trigger_out     : std_logic;
	signal external_send_reset : std_logic;
	--bit 1 ms-tick, 0 us-tick
	signal timer_ticks         : std_logic_vector(1 downto 0);

	signal trigger_busy_i : std_logic;
	signal tdc_inputs     : std_logic_vector(TDC_CHANNEL_NUMBER - 1 downto 1);

	signal select_tc_i       : std_logic_vector(31 downto 0);
	signal select_tc_reset_i : std_logic;

	signal hitreg_read_en    : std_logic;
	signal hitreg_write_en   : std_logic;
	signal hitreg_data_in    : std_logic_vector(31 downto 0);
	signal hitreg_addr       : std_logic_vector(6 downto 0);
	signal hitreg_data_out   : std_logic_vector(31 downto 0) := (others => '0');
	signal hitreg_data_ready : std_logic;
	signal hitreg_invalid    : std_logic;

	signal srb_read_en    : std_logic;
	signal srb_write_en   : std_logic;
	signal srb_data_in    : std_logic_vector(31 downto 0);
	signal srb_addr       : std_logic_vector(6 downto 0);
	signal srb_data_out   : std_logic_vector(31 downto 0) := (others => '0');
	signal srb_data_ready : std_logic;
	signal srb_invalid    : std_logic;

	signal esb_read_en    : std_logic;
	signal esb_write_en   : std_logic;
	signal esb_data_in    : std_logic_vector(31 downto 0);
	signal esb_addr       : std_logic_vector(6 downto 0);
	signal esb_data_out   : std_logic_vector(31 downto 0) := (others => '0');
	signal esb_data_ready : std_logic;
	signal esb_invalid    : std_logic;

	signal fwb_read_en    : std_logic;
	signal fwb_write_en   : std_logic;
	signal fwb_data_in    : std_logic_vector(31 downto 0);
	signal fwb_addr       : std_logic_vector(6 downto 0);
	signal fwb_data_out   : std_logic_vector(31 downto 0) := (others => '0');
	signal fwb_data_ready : std_logic;
	signal fwb_invalid    : std_logic;

	signal tdc_ctrl_read      : std_logic;
	signal last_tdc_ctrl_read : std_logic;
	signal tdc_ctrl_write     : std_logic;
	signal tdc_ctrl_addr      : std_logic_vector(2 downto 0);
	signal tdc_ctrl_data_in   : std_logic_vector(31 downto 0);
	signal tdc_ctrl_data_out  : std_logic_vector(31 downto 0) := (others => '0');
	signal tdc_ctrl_reg       : std_logic_vector(8 * 32 - 1 downto 0);
	signal tdc_debug          : std_logic_vector(15 downto 0);

	signal sfp_ddm_ctrl_read      : std_logic;
	signal last_sfp_ddm_ctrl_read : std_logic;
	signal sfp_ddm_ctrl_write     : std_logic;
	signal sfp_ddm_ctrl_addr      : std_logic_vector(1 downto 0);
	signal sfp_ddm_ctrl_data_in   : std_logic_vector(31 downto 0);
	signal sfp_ddm_ctrl_data_out  : std_logic_vector(31 downto 0) := (others => '0');
	signal sfp_ddm_ctrl_reg       : std_logic_vector(4 * 32 - 1 downto 0);

	signal led_time_ref_i : std_logic;

	signal do_reboot_i         : std_logic;
	signal killswitch_reboot_i : std_logic;

	-- cbmnet  
	signal cbm_clk_i         : std_logic;
	signal cbm_reset_i       : std_logic;
	signal cbm_etm_trigger_i : std_logic;

	signal cbm_phy_led_rx_i : std_logic;
	signal cbm_phy_led_tx_i : std_logic;
	signal cbm_phy_led_ok_i : std_logic;

	signal cbm_link_active_i         : std_logic;
	signal cbm_sync_dlm_sensed_i     : std_logic;
	signal cbm_sync_pulser_i         : std_logic;
	signal cbm_sync_timing_trigger_i : std_logic;

	signal cbm_regio_rx, bustc_rx : CTRLBUS_RX;
	signal cbm_regio_tx, bustc_tx : CTRLBUS_TX;

	-- soda signals
	signal rx_clock_100, rx_clock_200 : std_logic;

	signal DLM_to_uplink_S        : std_logic;
	signal DLM_WORD_to_uplink_S   : std_logic_vector(7 downto 0);
	signal DLM_from_uplink_S      : std_logic;
	signal DLM_WORD_from_uplink_S : std_logic_vector(7 downto 0);

	signal DLM_from_downlink_S      : std_logic_vector(3 downto 0);
	signal DLM_WORD_from_downlink_S : std_logic_vector(8 * 4 - 1 downto 0);
	signal DLM_to_downlink_S        : std_logic_vector(3 downto 0);
	signal DLM_WORD_to_downlink_S   : std_logic_vector(8 * 4 - 1 downto 0);

	signal sci1_ack      : std_logic;
	signal sci1_write    : std_logic;
	signal sci1_read     : std_logic;
	signal sci1_data_in  : std_logic_vector(7 downto 0);
	signal sci1_data_out : std_logic_vector(7 downto 0);
	signal sci1_addr     : std_logic_vector(8 downto 0);

	signal sci2_ack      : std_logic;
	signal sci2_write    : std_logic;
	signal sci2_read     : std_logic;
	signal sci2_data_in  : std_logic_vector(7 downto 0);
	signal sci2_data_out : std_logic_vector(7 downto 0);
	signal sci2_addr     : std_logic_vector(8 downto 0);

	signal soda_read_en  : std_logic;
	signal soda_write_en : std_logic;
	signal soda_ack      : std_logic;
	signal soda_addr     : std_logic_vector(3 downto 0);
	signal soda_data_in  : std_logic_vector(31 downto 0);
	signal soda_data_out : std_logic_vector(31 downto 0);

	signal common_stat_reg : std_logic_vector(std_COMSTATREG * 32 - 1 downto 0);
	signal common_ctrl_reg : std_logic_vector(std_COMCTRLREG * 32 - 1 downto 0);

begin

	---------------------------------------------------------------------------
	-- Reset Generation
	---------------------------------------------------------------------------
	GSR_N <= pll_lock;

	THE_RESET_HANDLER : trb_net_reset_handler
		generic map(
			RESET_DELAY => x"FEEE"
		)
		port map(
			CLEAR_IN      => select_tc_reset_i, -- reset input (high active, async)
			CLEAR_N_IN    => '1',       -- reset input (low active, async)
			CLK_IN        => clk_200_i, -- raw master clock, NOT from PLL/DLL!
			SYSCLK_IN     => clk_100_i, -- PLL/DLL remastered clock
			PLL_LOCKED_IN => pll_lock,  -- master PLL lock signal (async)
			RESET_IN      => '0',       -- general reset signal (SYSCLK)
			TRB_RESET_IN  => trb_reset_in, -- TRBnet reset signal (SYSCLK)
			CLEAR_OUT     => clear_i,   -- async reset out, USE WITH CARE!
			RESET_OUT     => reset_i_temp, -- synchronous reset out (SYSCLK)
			DEBUG_OUT     => open
		);

	trb_reset_in <= reset_via_gbe or MED_STAT_OP(4 * 16 + 13); --_delayed(2)
	reset_i      <= reset_i_temp;       -- or trb_reset_in;

	---------------------------------------------------------------------------
	-- Clock Handling
	---------------------------------------------------------------------------
	THE_MAIN_PLL : pll_in200_out100
		port map(
			CLK   => CLK_GPLL_LEFT,
			RESET => '0',
			CLKOP => clk_100_i,
			CLKOK => clk_200_i,
			LOCK  => pll_lock
		);

	clk_125_i <= CLK_GPLL_RIGHT;

	---------------------------------------------------------------------------
	-- SODA connection to the source
	---------------------------------------------------------------------------
	THE_MEDIA_UPLINK : entity work.trb_net16_med_sync3_ecp3_sfp
		port map(
			CLK                => clk_200_i,
			SYSCLK             => clk_100_i,
			RESET              => reset_i,
			CLEAR              => clear_i,
			CLK_EN             => '1',

			--Internal Connection
			MED_DATA_IN        => med_data_out(15 downto 0),
			MED_PACKET_NUM_IN  => med_packet_num_out(2 downto 0),
			MED_DATAREADY_IN   => med_dataready_out(0),
			MED_READ_OUT       => med_read_in(0),
			MED_DATA_OUT       => med_data_in(15 downto 0),
			MED_PACKET_NUM_OUT => med_packet_num_in(2 downto 0),
			MED_DATAREADY_OUT  => med_dataready_in(0),
			MED_READ_IN        => med_read_out(0),
			REFCLK2CORE_OUT    => open,
			CLK_RX_HALF_OUT    => rx_clock_100,
			CLK_RX_FULL_OUT    => rx_clock_200,

			--SFP Connection
			SD_RXD_P_IN        => SODA_SRC_RXP_IN, --SERDES_ADDON_RX(8),
			SD_RXD_N_IN        => SODA_SRC_RXN_IN, --SERDES_ADDON_RX(9),
			SD_TXD_P_OUT       => SODA_SRC_TXP_OUT, --SERDES_ADDON_TX(8),
			SD_TXD_N_OUT       => SODA_SRC_TXN_OUT, --SERDES_ADDON_TX(9),

			SD_DLM_IN          => DLM_to_uplink_S,
			SD_DLM_WORD_IN     => DLM_WORD_to_uplink_S,
			SD_DLM_OUT         => DLM_from_uplink_S,
			SD_DLM_WORD_OUT    => DLM_WORD_from_uplink_S,

			--SFP1, PCSA, ch0 
			SD_PRSNT_N_IN      => SFP_LOS(1),
			SD_LOS_IN          => SFP_LOS(1),
			SD_TXDIS_OUT       => SFP_TXDIS(1),
			SCI_DATA_IN        => sci1_data_in,
			SCI_DATA_OUT       => sci1_data_out,
			SCI_ADDR           => sci1_addr,
			SCI_READ           => sci1_read,
			SCI_WRITE          => sci1_write,
			SCI_ACK            => sci1_ack,

			-- Status and control port
			STAT_OP            => med_stat_op(15 downto 0),
			CTRL_OP            => med_ctrl_op(15 downto 0),
			STAT_DEBUG         => med_stat_debug(63 downto 0),
			CTRL_DEBUG         => (others => '0')
		);

	---------------------------------------------------------------------------
	-- SODA connections to the endpoints 
	---------------------------------------------------------------------------
	THE_MEDIA_DOWNLINK : entity work.trb_net16_med_syncfull_ecp3_sfp
		port map(
			CLK                                        => rx_clock_200,
			SYSCLK                                     => clk_100_i,
			RESET                                      => reset_i,
			CLEAR                                      => clear_i,
			CLK_EN                                     => '1',

			--Internal Connection
			MED_DATA_IN(0 * 16 + 15 downto 0 * 16)     => med_data_out(1 * 16 + 15 downto 1 * 16),
			MED_DATA_IN(1 * 16 + 15 downto 1 * 16)     => med_data_out(6 * 16 + 15 downto 6 * 16),
			MED_DATA_IN(2 * 16 + 15 downto 2 * 16)     => med_data_out(2 * 16 + 15 downto 2 * 16),
			MED_DATA_IN(3 * 16 + 15 downto 3 * 16)     => med_data_out(4 * 16 + 15 downto 4 * 16),
			MED_PACKET_NUM_IN(0 * 3 + 2 downto 0 * 3)  => med_packet_num_out(1 * 3 + 2 downto 1 * 3),
			MED_PACKET_NUM_IN(1 * 3 + 2 downto 1 * 3)  => med_packet_num_out(6 * 3 + 2 downto 6 * 3),
			MED_PACKET_NUM_IN(2 * 3 + 2 downto 2 * 3)  => med_packet_num_out(2 * 3 + 2 downto 2 * 3),
			MED_PACKET_NUM_IN(3 * 3 + 2 downto 3 * 3)  => med_packet_num_out(4 * 3 + 2 downto 4 * 3),
			MED_DATAREADY_IN(0)                        => med_dataready_out(1),
			MED_DATAREADY_IN(1)                        => med_dataready_out(6),
			MED_DATAREADY_IN(2)                        => med_dataready_out(2),
			MED_DATAREADY_IN(3)                        => med_dataready_out(4),
			MED_READ_OUT(0)                            => med_read_in(1),
			MED_READ_OUT(1)                            => med_read_in(6),
			MED_READ_OUT(2)                            => med_read_in(2),
			MED_READ_OUT(3)                            => med_read_in(4),
			MED_DATA_OUT(0 * 16 + 15 downto 0 * 16)    => med_data_in(1 * 16 + 15 downto 1 * 16),
			MED_DATA_OUT(1 * 16 + 15 downto 1 * 16)    => med_data_in(6 * 16 + 15 downto 6 * 16),
			MED_DATA_OUT(2 * 16 + 15 downto 2 * 16)    => med_data_in(2 * 16 + 15 downto 2 * 16),
			MED_DATA_OUT(3 * 16 + 15 downto 3 * 16)    => med_data_in(4 * 16 + 15 downto 4 * 16),
			MED_PACKET_NUM_OUT(0 * 3 + 2 downto 0 * 3) => med_packet_num_in(1 * 3 + 2 downto 1 * 3),
			MED_PACKET_NUM_OUT(1 * 3 + 2 downto 1 * 3) => med_packet_num_in(6 * 3 + 2 downto 6 * 3),
			MED_PACKET_NUM_OUT(2 * 3 + 2 downto 2 * 3) => med_packet_num_in(2 * 3 + 2 downto 2 * 3),
			MED_PACKET_NUM_OUT(3 * 3 + 2 downto 3 * 3) => med_packet_num_in(4 * 3 + 2 downto 4 * 3),
			MED_DATAREADY_OUT(0)                       => med_dataready_in(1),
			MED_DATAREADY_OUT(1)                       => med_dataready_in(6),
			MED_DATAREADY_OUT(2)                       => med_dataready_in(2),
			MED_DATAREADY_OUT(3)                       => med_dataready_in(4),
			MED_READ_IN(0)                             => med_read_out(1),
			MED_READ_IN(1)                             => med_read_out(6),
			MED_READ_IN(2)                             => med_read_out(2),
			MED_READ_IN(3)                             => med_read_out(4),
			REFCLK2CORE_OUT                            => open,

			--SFP Connection
			SD_RXD_P_IN                                => SODA_ENDP_RXP_IN, --SERDES_ADDON_RX(3 downto 0),
			SD_RXD_N_IN                                => SODA_ENDP_RXN_IN, --SERDES_ADDON_RX(7 downto 4),
			SD_TXD_P_OUT                               => SODA_ENDP_TXP_OUT, --SERDES_ADDON_TX(3 downto 0),
			SD_TXD_N_OUT                               => SODA_ENDP_TXN_OUT, --SERDES_ADDON_TX(7 downto 4),
			SD_REFCLK_P_IN                             => '0',
			SD_REFCLK_N_IN                             => '0',
			SD_PRSNT_N_IN(0)                           => FPGA1_COMM(2),
			SD_PRSNT_N_IN(1)                           => FPGA2_COMM(2),
			SD_PRSNT_N_IN(2)                           => FPGA3_COMM(2),
			SD_PRSNT_N_IN(3)                           => FPGA4_COMM(2),
			SD_LOS_IN(0)                               => FPGA1_COMM(2),
			SD_LOS_IN(1)                               => FPGA2_COMM(2),
			SD_LOS_IN(2)                               => FPGA3_COMM(2),
			SD_LOS_IN(3)                               => FPGA4_COMM(2),
			SD_TXDIS_OUT(0)                            => FPGA1_COMM(0),
			SD_TXDIS_OUT(1)                            => FPGA2_COMM(0),
			SD_TXDIS_OUT(2)                            => FPGA3_COMM(0),
			SD_TXDIS_OUT(3)                            => FPGA4_COMM(0),
			--			SD_PRSNT_N_IN(0)                           => SFP_MOD0(1),
			--			SD_PRSNT_N_IN(1)                           => SFP_MOD0(6),
			--			SD_PRSNT_N_IN(2)                           => SFP_MOD0(2),
			--			SD_PRSNT_N_IN(3)                           => SFP_MOD0(4),
			--			SD_LOS_IN(0)                               => SFP_LOS(1),
			--			SD_LOS_IN(1)                               => SFP_LOS(6),
			--			SD_LOS_IN(2)                               => SFP_LOS(2),
			--			SD_LOS_IN(3)                               => SFP_LOS(4),
			--			SD_TXDIS_OUT(0)                            => SFP_TXDIS(1),
			--			SD_TXDIS_OUT(1)                            => SFP_TXDIS(6),
			--			SD_TXDIS_OUT(2)                            => SFP_TXDIS(2),
			--			SD_TXDIS_OUT(3)                            => SFP_TXDIS(4),

			--Synchronous signals
			RX_DLM                                     => DLM_from_downlink_S,
			RX_DLM_WORD                                => DLM_WORD_from_downlink_S,
			TX_DLM                                     => DLM_to_downlink_S,
			TX_DLM_WORD                                => DLM_WORD_to_downlink_S,

			--Control Interface
			SCI_DATA_IN                                => sci2_data_in,
			SCI_DATA_OUT                               => sci2_data_out,
			SCI_ADDR                                   => sci2_addr,
			SCI_READ                                   => sci2_read,
			SCI_WRITE                                  => sci2_write,
			SCI_ACK                                    => sci2_ack,

			-- Status and control port
			STAT_OP(0 * 16 + 15 downto 0 * 16)         => med_stat_op(1 * 16 + 15 downto 1 * 16),
			STAT_OP(1 * 16 + 15 downto 1 * 16)         => med_stat_op(6 * 16 + 15 downto 6 * 16),
			STAT_OP(2 * 16 + 15 downto 2 * 16)         => med_stat_op(2 * 16 + 15 downto 2 * 16),
			STAT_OP(3 * 16 + 15 downto 3 * 16)         => med_stat_op(4 * 16 + 15 downto 4 * 16),
			CTRL_OP(0 * 16 + 15 downto 0 * 16)         => med_ctrl_op(1 * 16 + 15 downto 1 * 16),
			CTRL_OP(1 * 16 + 15 downto 1 * 16)         => med_ctrl_op(6 * 16 + 15 downto 6 * 16),
			CTRL_OP(2 * 16 + 15 downto 2 * 16)         => med_ctrl_op(2 * 16 + 15 downto 2 * 16),
			CTRL_OP(3 * 16 + 15 downto 3 * 16)         => med_ctrl_op(4 * 16 + 15 downto 4 * 16),
			STAT_DEBUG                                 => open,
			CTRL_DEBUG                                 => (others => '0')
		);

	---------------------------------------------------------------------------
	-- SODA
	--------------------------------------------------------------------------- 
	THE_SODA_HUB : entity work.soda_hub
		port map(
			SYSCLK               => clk_100_i,
			SODACLK              => rx_clock_200,
			RESET                => reset_i,
			CLEAR                => '0',
			CLK_EN               => '1',

			--	SINGLE DUBPLEX UP-LINK TO THE TOP
			RXUP_DLM_IN          => DLM_from_uplink_S,
			RXUP_DLM_WORD_IN     => DLM_WORD_from_uplink_S,
			TXUP_DLM_OUT         => DLM_to_uplink_S,
			TXUP_DLM_WORD_OUT    => DLM_WORD_to_uplink_S,
			TXUP_DLM_PREVIEW_OUT => open,
			UPLINK_PHASE_IN      => c_PHASE_H,

			--	MULTIPLE DUPLEX DOWN-LINKS TO THE BOTTOM
			RXDN_DLM_IN(0)       => DLM_from_downlink_S(0),
			RXDN_DLM_IN(1)       => DLM_from_downlink_S(1),
			RXDN_DLM_IN(2)       => DLM_from_downlink_S(2),
			RXDN_DLM_IN(3)       => DLM_from_downlink_S(3),
			RXDN_DLM_WORD_IN(0)  => DLM_WORD_from_downlink_S(0 * 8 + 7 downto 0 * 8),
			RXDN_DLM_WORD_IN(1)  => DLM_WORD_from_downlink_S(1 * 8 + 7 downto 1 * 8),
			RXDN_DLM_WORD_IN(2)  => DLM_WORD_from_downlink_S(2 * 8 + 7 downto 2 * 8),
			RXDN_DLM_WORD_IN(3)  => DLM_WORD_from_downlink_S(3 * 8 + 7 downto 3 * 8),
			TXDN_DLM_OUT(0)      => DLM_to_downlink_S(0),
			TXDN_DLM_OUT(1)      => DLM_to_downlink_S(1),
			TXDN_DLM_OUT(2)      => DLM_to_downlink_S(2),
			TXDN_DLM_OUT(3)      => DLM_to_downlink_S(3),
			TXDN_DLM_WORD_OUT(0) => DLM_WORD_to_downlink_S(0 * 8 + 7 downto 0 * 8),
			TXDN_DLM_WORD_OUT(1) => DLM_WORD_to_downlink_S(1 * 8 + 7 downto 1 * 8),
			TXDN_DLM_WORD_OUT(2) => DLM_WORD_to_downlink_S(2 * 8 + 7 downto 2 * 8),
			TXDN_DLM_WORD_OUT(3) => DLM_WORD_to_downlink_S(3 * 8 + 7 downto 3 * 8),
			TXDN_DLM_PREVIEW_OUT => open,
			DNLINK_PHASE_IN      => (others => c_PHASE_H),
			SODA_DATA_IN         => soda_data_in,
			SODA_DATA_OUT        => soda_data_out,
			SODA_ADDR_IN         => soda_addr,
			SODA_READ_IN         => soda_read_en,
			SODA_WRITE_IN        => soda_write_en,
			SODA_ACK_OUT         => soda_ack,
			LEDS_OUT             => open,
			LINK_DEBUG_IN        => (others => '0')
		);

	---------------------------------------------------------------------------
	-- TrbNEt HUB
	--------------------------------------------------------------------------- 
	THE_HUB : trb_net16_hub_base
		generic map(
			HUB_USED_CHANNELS      => (c_YES, c_YES, c_NO, c_YES),
			IBUF_SECURE_MODE       => c_YES,
			MII_NUMBER             => 7,
			MII_IS_UPLINK          => (0 => 1, others => 0),
			MII_IS_DOWNLINK        => (0 => 0, others => 1),
			MII_IS_UPLINK_ONLY     => (0 => 1, others => 0),
			INT_NUMBER             => 0,
			--     INT_CHANNELS      => (0,1,3,3,3,3,3,3),
			USE_ONEWIRE            => c_YES,
			COMPILE_TIME           => std_logic_vector(to_unsigned(VERSION_NUMBER_TIME, 32)),
			HARDWARE_VERSION       => x"91003200",
			INIT_ENDPOINT_ID       => x"0000",
			INIT_ADDRESS           => x"F300",
			USE_VAR_ENDPOINT_ID    => c_YES,
			BROADCAST_SPECIAL_ADDR => x"45"
		)
		port map(
			CLK                                    => clk_100_i,
			RESET                                  => reset_i,
			CLK_EN                                 => '1',

			--Media interfacces
			MED_DATAREADY_OUT(7 * 1 - 1 downto 0)  => med_dataready_out,
			MED_DATA_OUT(7 * 16 - 1 downto 0)      => med_data_out,
			MED_PACKET_NUM_OUT(7 * 3 - 1 downto 0) => med_packet_num_out,
			MED_READ_IN(7 * 1 - 1 downto 0)        => med_read_in,
			MED_DATAREADY_IN(7 * 1 - 1 downto 0)   => med_dataready_in,
			MED_DATA_IN(7 * 16 - 1 downto 0)       => med_data_in,
			MED_PACKET_NUM_IN(7 * 3 - 1 downto 0)  => med_packet_num_in,
			MED_READ_OUT(7 * 1 - 1 downto 0)       => med_read_out,
			MED_STAT_OP(7 * 16 - 1 downto 0)       => med_stat_op,
			MED_CTRL_OP(7 * 16 - 1 downto 0)       => med_ctrl_op,
			COMMON_STAT_REGS                       => common_stat_reg,
			COMMON_CTRL_REGS                       => common_ctrl_reg,
			MY_ADDRESS_OUT                         => my_address,
			--REGIO INTERFACE
			REGIO_ADDR_OUT                         => regio_addr_out,
			REGIO_READ_ENABLE_OUT                  => regio_read_enable_out,
			REGIO_WRITE_ENABLE_OUT                 => regio_write_enable_out,
			REGIO_DATA_OUT                         => regio_data_out,
			REGIO_DATA_IN                          => regio_data_in,
			REGIO_DATAREADY_IN                     => regio_dataready_in,
			REGIO_NO_MORE_DATA_IN                  => regio_no_more_data_in,
			REGIO_WRITE_ACK_IN                     => regio_write_ack_in,
			REGIO_UNKNOWN_ADDR_IN                  => regio_unknown_addr_in,
			REGIO_TIMEOUT_OUT                      => regio_timeout_out,
			REGIO_VAR_ENDPOINT_ID(1 downto 0)      => CODE_LINE,
			REGIO_VAR_ENDPOINT_ID(15 downto 2)     => (others => '0'),
			ONEWIRE                                => TEMPSENS,
			ONEWIRE_MONITOR_OUT                    => open,
			--Status ports (for debugging)
			MPLEX_CTRL                             => (others => '0'),
			CTRL_DEBUG                             => (others => '0'),
			STAT_DEBUG                             => open
		);
	---------------------------------------------------------------------------
	-- Bus Handler
	---------------------------------------------------------------------------
	THE_BUS_HANDLER : trb_net16_regio_bus_handler
		generic map(
			PORT_NUMBER    => 5,
			PORT_ADDRESSES => (0 => x"d000", 1 => x"d100", 2 => x"b000", 3 => x"b200", 4 => x"e100", others => x"0000"),
			PORT_ADDR_MASK => (0 => 1, 1 => 6, 2 => 9, 3 => 9, 4 => 4, others => 0)
		)
		port map(
			CLK                                         => clk_100_i,
			RESET                                       => reset_i,
			DAT_ADDR_IN                                 => regio_addr_out,
			DAT_DATA_IN                                 => regio_data_out,
			DAT_DATA_OUT                                => regio_data_in,
			DAT_READ_ENABLE_IN                          => regio_read_enable_out,
			DAT_WRITE_ENABLE_IN                         => regio_write_enable_out,
			DAT_TIMEOUT_IN                              => regio_timeout_out,
			DAT_DATAREADY_OUT                           => regio_dataready_in,
			DAT_WRITE_ACK_OUT                           => regio_write_ack_in,
			DAT_NO_MORE_DATA_OUT                        => regio_no_more_data_in,
			DAT_UNKNOWN_ADDR_OUT                        => regio_unknown_addr_in,

			--Bus Handler (SPI CTRL)
			--Bus Handler (SPI Memory)
			--SCI first Media Interface
			--SCI second Media Interface
			--SODA
			BUS_READ_ENABLE_OUT(0)                      => spictrl_read_en,
			BUS_READ_ENABLE_OUT(1)                      => spimem_read_en,
			BUS_READ_ENABLE_OUT(2)                      => sci1_read,
			BUS_READ_ENABLE_OUT(3)                      => sci2_read,
			BUS_READ_ENABLE_OUT(4)                      => soda_read_en,
			BUS_WRITE_ENABLE_OUT(0)                     => spictrl_write_en,
			BUS_WRITE_ENABLE_OUT(1)                     => spimem_write_en,
			BUS_WRITE_ENABLE_OUT(2)                     => sci1_write,
			BUS_WRITE_ENABLE_OUT(3)                     => sci2_write,
			BUS_WRITE_ENABLE_OUT(4)                     => soda_write_en,
			BUS_DATA_OUT(0 * 32 + 31 downto 0 * 32)     => spictrl_data_in,
			BUS_DATA_OUT(1 * 32 + 31 downto 1 * 32)     => spimem_data_in,
			BUS_DATA_OUT(2 * 32 + 7 downto 2 * 32)      => sci1_data_in,
			BUS_DATA_OUT(2 * 32 + 31 downto 2 * 32 + 8) => open,
			BUS_DATA_OUT(3 * 32 + 7 downto 3 * 32)      => sci2_data_in,
			BUS_DATA_OUT(3 * 32 + 31 downto 3 * 32 + 8) => open,
			BUS_DATA_OUT(4 * 32 + 31 downto 4 * 32)     => soda_data_in,
			BUS_ADDR_OUT(0 * 16)                        => spictrl_addr,
			BUS_ADDR_OUT(0 * 16 + 15 downto 0 * 16 + 1) => open,
			BUS_ADDR_OUT(1 * 16 + 5 downto 1 * 16)      => spimem_addr,
			BUS_ADDR_OUT(1 * 16 + 15 downto 1 * 16 + 6) => open,
			BUS_ADDR_OUT(2 * 16 + 8 downto 2 * 16)      => sci1_addr,
			BUS_ADDR_OUT(2 * 16 + 15 downto 2 * 16 + 9) => open,
			BUS_ADDR_OUT(3 * 16 + 8 downto 3 * 16)      => sci2_addr,
			BUS_ADDR_OUT(3 * 16 + 15 downto 3 * 16 + 9) => open,
			BUS_ADDR_OUT(4 * 16 + 3 downto 4 * 16)      => soda_addr,
			BUS_ADDR_OUT(4 * 16 + 15 downto 4 * 16 + 4) => open,
			BUS_TIMEOUT_OUT(0)                          => open,
			BUS_TIMEOUT_OUT(1)                          => open,
			BUS_TIMEOUT_OUT(2)                          => open,
			BUS_TIMEOUT_OUT(3)                          => open,
			BUS_TIMEOUT_OUT(4)                          => open,
			BUS_DATA_IN(0 * 32 + 31 downto 0 * 32)      => spictrl_data_out,
			BUS_DATA_IN(1 * 32 + 31 downto 1 * 32)      => spimem_data_out,
			BUS_DATA_IN(2 * 32 + 7 downto 2 * 32)       => sci1_data_out,
			BUS_DATA_IN(2 * 32 + 31 downto 2 * 32 + 8)  => (others => '0'),
			BUS_DATA_IN(3 * 32 + 7 downto 3 * 32)       => sci2_data_out,
			BUS_DATA_IN(3 * 32 + 31 downto 3 * 32 + 8)  => (others => '0'),
			BUS_DATA_IN(4 * 32 + 31 downto 4 * 32)      => soda_data_out,
			BUS_DATAREADY_IN(0)                         => spictrl_ack,
			BUS_DATAREADY_IN(1)                         => spimem_ack,
			BUS_DATAREADY_IN(2)                         => sci1_ack,
			BUS_DATAREADY_IN(3)                         => sci2_ack,
			BUS_DATAREADY_IN(4)                         => soda_ack,
			BUS_WRITE_ACK_IN(0)                         => spictrl_ack,
			BUS_WRITE_ACK_IN(1)                         => spimem_ack,
			BUS_WRITE_ACK_IN(2)                         => sci1_ack,
			BUS_WRITE_ACK_IN(3)                         => sci2_ack,
			BUS_WRITE_ACK_IN(4)                         => soda_ack,
			BUS_NO_MORE_DATA_IN(0)                      => spictrl_busy,
			BUS_NO_MORE_DATA_IN(1)                      => '0',
			BUS_NO_MORE_DATA_IN(2)                      => '0',
			BUS_NO_MORE_DATA_IN(3)                      => '0',
			BUS_NO_MORE_DATA_IN(4)                      => '0',
			BUS_UNKNOWN_ADDR_IN(0)                      => '0',
			BUS_UNKNOWN_ADDR_IN(1)                      => '0',
			BUS_UNKNOWN_ADDR_IN(2)                      => '0',
			BUS_UNKNOWN_ADDR_IN(3)                      => '0',
			BUS_UNKNOWN_ADDR_IN(4)                      => '0',
			STAT_DEBUG                                  => open
		);

	---------------------------------------------------------------------------
	-- SPI / Flash
	---------------------------------------------------------------------------
	THE_SPI_MASTER : spi_master
		port map(
			CLK_IN         => clk_100_i,
			RESET_IN       => reset_i,
			-- Slave bus
			BUS_READ_IN    => spictrl_read_en,
			BUS_WRITE_IN   => spictrl_write_en,
			BUS_BUSY_OUT   => spictrl_busy,
			BUS_ACK_OUT    => spictrl_ack,
			BUS_ADDR_IN(0) => spictrl_addr,
			BUS_DATA_IN    => spictrl_data_in,
			BUS_DATA_OUT   => spictrl_data_out,
			-- SPI connections
			SPI_CS_OUT     => FLASH_CS,
			SPI_SDI_IN     => FLASH_DOUT,
			SPI_SDO_OUT    => FLASH_DIN,
			SPI_SCK_OUT    => FLASH_CLK,
			-- BRAM for read/write data
			BRAM_A_OUT     => spi_bram_addr,
			BRAM_WR_D_IN   => spi_bram_wr_d,
			BRAM_RD_D_OUT  => spi_bram_rd_d,
			BRAM_WE_OUT    => spi_bram_we,
			-- Status lines
			STAT           => open
		);

	-- data memory for SPI accesses
	THE_SPI_MEMORY : spi_databus_memory
		port map(
			CLK_IN        => clk_100_i,
			RESET_IN      => reset_i,
			-- Slave bus
			BUS_ADDR_IN   => spimem_addr,
			BUS_READ_IN   => spimem_read_en,
			BUS_WRITE_IN  => spimem_write_en,
			BUS_ACK_OUT   => spimem_ack,
			BUS_DATA_IN   => spimem_data_in,
			BUS_DATA_OUT  => spimem_data_out,
			-- state machine connections
			BRAM_ADDR_IN  => spi_bram_addr,
			BRAM_WR_D_OUT => spi_bram_wr_d,
			BRAM_RD_D_IN  => spi_bram_rd_d,
			BRAM_WE_IN    => spi_bram_we,
			-- Status lines
			STAT          => open
		);

	---------------------------------------------------------------------------
	-- Reboot FPGA
	---------------------------------------------------------------------------
	THE_FPGA_REBOOT : fpga_reboot
		port map(
			CLK       => clk_100_i,
			RESET     => reset_i,
			DO_REBOOT => do_reboot_i,
			PROGRAMN  => PROGRAMN
		);

	do_reboot_i <= common_ctrl_regs(15); -- or killswitch_reboot_i;

	-- if jttl(15) is stabily high for 1.28us: issue reboot
	THE_KILLSWITCH_PROC : process
		variable stab_counter   : unsigned(7 downto 0);
		variable inp, inp_delay : std_logic := '0';
	begin
		wait until rising_edge(clk_100_i);

		if inp_delay = inp then
			stab_counter := stab_counter + 1;
		else
			stab_counter := 0;
		end if;

		inp_delay           := inp;
		inp                 := JTTL(15);
		killswitch_reboot_i <= stab_counter(stab_counter'high) and inp;
	end process;

	THE_CLOCK_SWITCH : entity work.clock_switch
		generic map(
			DEFAULT_INTERNAL_TRIGGER => c_YES
		)
		port map(
			INT_CLK_IN     => CLK_GPLL_RIGHT,
			SYS_CLK_IN     => clk_100_i,
			BUS_RX         => bustc_rx,
			BUS_TX         => bustc_tx,
			PLL_LOCK       => pll_lock,
			RESET_IN       => reset_i,
			RESET_OUT      => open,
			CLOCK_SELECT   => CLOCK_SELECT,
			TRIG_SELECT    => TRIGGER_SELECT,
			CLK_MNGR1_USER => CLK_MNGR1_USER,
			CLK_MNGR2_USER => CLK_MNGR2_USER,
			DEBUG_OUT      => open
		);

	cts_rdo_trigger <= cts_trigger_out;

	process is
	begin
		-- output time reference synchronously to the 200MHz clock
		-- in order to reduce jitter
		wait until rising_edge(clk_200_i);
		TRIGGER_OUT      <= cts_trigger_out;
		TRIGGER_OUT2     <= cts_trigger_out;
		TRG_FANOUT_ADDON <= cts_trigger_out;
	end process;

	process is
	begin
		wait until rising_edge(clk_100_i);
		if timer_ticks(0) = '1' then
			led_time_ref_i <= '0';
		else
			led_time_ref_i <= led_time_ref_i or cts_trigger_out;
		end if;
	end process;

	---------------------------------------------------------------------------
	-- FPGA communication
	---------------------------------------------------------------------------
	--   FPGA1_COMM <= (others => 'Z');
	--   FPGA2_COMM <= (others => 'Z');
	--   FPGA3_COMM <= (others => 'Z');
	--   FPGA4_COMM <= (others => 'Z');

	FPGA1_TTL <= (others => 'Z');
	FPGA2_TTL <= (others => 'Z');
	FPGA3_TTL <= (others => 'Z');
	FPGA4_TTL <= (others => 'Z');

	FPGA1_CONNECTOR <= (others => 'Z');
	FPGA2_CONNECTOR <= (others => 'Z');
	FPGA3_CONNECTOR <= (others => 'Z');
	FPGA4_CONNECTOR <= (others => 'Z');

	---------------------------------------------------------------------------
	-- AddOn Connector
	---------------------------------------------------------------------------
	PWM_OUT <= "00";

	--  JOUT1                          <= x"0";
	--  JOUT2                          <= x"0";
	--  JOUTLVDS                       <= x"00";
	JTTL <= (others => 'Z');

	LED_BANK(5 downto 0) <= (others => '0');
	LED_FAN_GREEN        <= led_time_ref_i;
	LED_FAN_ORANGE       <= '0';
	LED_FAN_RED          <= trigger_busy_i;
	LED_FAN_YELLOW       <= '0';

	---------------------------------------------------------------------------
	-- LED
	---------------------------------------------------------------------------
	LED_CLOCK_GREEN <= not med_stat_op(15);
	LED_CLOCK_RED   <= not reset_via_gbe;
	--   LED_GREEN                      <= not med_stat_op(9);
	--   LED_YELLOW                     <= not med_stat_op(10);
	--   LED_ORANGE                     <= not med_stat_op(11); 
	--   LED_RED                        <= '1';


	LED_GREEN  <= debug(0);
	LED_ORANGE <= debug(1);
	LED_RED    <= debug(2);
	LED_YELLOW <= link_ok;

	---------------------------------------------------------------------------
	-- Test Connector
	---------------------------------------------------------------------------    
	TEST_LINE <= (others => '0');

end architecture;
