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
use work.version.all;
use work.tdc_components.TDC;
use work.tdc_version.all;
use work.trb_net_gbe_components.all;

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
		CLK_EXT                                    : in    std_logic_vector(4 downto 3); --from RJ45
		CLK_GPLL_LEFT                              : in    std_logic; --Clock Manager 2/9, 200 MHz  <-- MAIN CLOCK
		CLK_GPLL_RIGHT                             : in    std_logic; --Clock Manager 1/9, 125 MHz  <-- for GbE
		CLK_PCLK_LEFT                              : in    std_logic; --Clock Fan-out, 200/400 MHz 
		CLK_PCLK_RIGHT                             : in    std_logic; --Clock Fan-out, 200/400 MHz 

		--Trigger
		TRIGGER_LEFT                               : in    std_logic; --left side trigger input from fan-out
		TRIGGER_RIGHT                              : in    std_logic; --right side trigger input from fan-out
		TRIGGER_EXT                                : in    std_logic_vector(4 downto 2); --additional trigger from RJ45
		TRIGGER_OUT                                : out   std_logic; --trigger to second input of fan-out
		TRIGGER_OUT2                               : out   std_logic;

		--Serdes
		CLK_SERDES_INT_LEFT                        : in    std_logic; --Clock Manager 2/0, 200 MHz, only in case of problems
		CLK_SERDES_INT_RIGHT                       : in    std_logic; --Clock Manager 1/0, off, 125 MHz possible

		--SFP
		SFP_RX_P                                   : in    std_logic_vector(9 downto 1);
		SFP_RX_N                                   : in    std_logic_vector(9 downto 1);
		SFP_TX_P                                   : out   std_logic_vector(9 downto 1);
		SFP_TX_N                                   : out   std_logic_vector(9 downto 1);
		SFP_TX_FAULT                               : in    std_logic_vector(8 downto 1); --TX broken
		SFP_RATE_SEL                               : out   std_logic_vector(8 downto 1); --not supported by our SFP
		SFP_LOS                                    : in    std_logic_vector(8 downto 1); --Loss of signal
		SFP_MOD0                                   : in    std_logic_vector(8 downto 1); --SFP present
		SFP_MOD1                                   : out   std_logic_vector(8 downto 1); --I2C interface
		SFP_MOD2                                   : inout std_logic_vector(8 downto 1); --I2C interface
		SFP_TXDIS                                  : out   std_logic_vector(8 downto 1); --disable TX

		--Clock and Trigger Control
		TRIGGER_SELECT                             : out   std_logic; --trigger select for fan-out. 0: external, 1: signal from FPGA5
		CLOCK_SELECT                               : out   std_logic; --clock select for fan-out. 0: 200MHz, 1: external from RJ45
		CLK_MNGR1_USER                             : inout std_logic_vector(3 downto 0); --I/O lines to clock manager 1
		CLK_MNGR2_USER                             : inout std_logic_vector(3 downto 0); --I/O lines to clock manager 1

		--Inter-FPGA Communication
		FPGA1_COMM                                 : inout std_logic_vector(11 downto 0);
		FPGA2_COMM                                 : inout std_logic_vector(11 downto 0);
		FPGA3_COMM                                 : inout std_logic_vector(11 downto 0);
		FPGA4_COMM                                 : inout std_logic_vector(11 downto 0);
		-- on all FPGAn_COMM:  --Bit 0/1 output, serial link TX active
		--Bit 2/3 input, serial link RX active
		--others yet undefined
		FPGA1_TTL                                  : inout std_logic_vector(3 downto 0);
		FPGA2_TTL                                  : inout std_logic_vector(3 downto 0);
		FPGA3_TTL                                  : inout std_logic_vector(3 downto 0);
		FPGA4_TTL                                  : inout std_logic_vector(3 downto 0);
		--only for not timing-sensitive signals

		--Communication to small addons
		FPGA1_CONNECTOR                            : inout std_logic_vector(7 downto 0); --Bit 2-3: LED for SFP3/4
		FPGA2_CONNECTOR                            : inout std_logic_vector(7 downto 0); --Bit 2-3: LED for SFP7/8
		FPGA3_CONNECTOR                            : inout std_logic_vector(7 downto 0); --Bit 0-1: LED for SFP5/6 
		FPGA4_CONNECTOR                            : inout std_logic_vector(7 downto 0); --Bit 0-1: LED for SFP1/2
		--Bit 0-3 connected to LED by default, two on each side

		--AddOn connector
		ECL_IN                                     : in    std_logic_vector(3 downto 0);
		NIM_IN                                     : in    std_logic_vector(1 downto 0);
		JIN1                                       : in    std_logic_vector(3 downto 0);
		JIN2                                       : in    std_logic_vector(3 downto 0);
		JINLVDS                                    : in    std_logic_vector(15 downto 0); --No LVDS, just TTL!

		DISCRIMINATOR_IN                           : in    std_logic_vector(1 downto 0);
		PWM_OUT                                    : out   std_logic_vector(1 downto 0);

		JOUT1                                      : out   std_logic_vector(3 downto 0);
		JOUT2                                      : out   std_logic_vector(3 downto 0);
		JOUTLVDS                                   : out   std_logic_vector(7 downto 0);
		JTTL                                       : inout std_logic_vector(15 downto 0);
		TRG_FANOUT_ADDON                           : out   std_logic;

		LED_BANK                                   : out   std_logic_vector(7 downto 0);
		LED_RJ_GREEN                               : out   std_logic_vector(5 downto 0);
		LED_RJ_RED                                 : out   std_logic_vector(5 downto 0);
		LED_FAN_GREEN                              : out   std_logic;
		LED_FAN_ORANGE                             : out   std_logic;
		LED_FAN_RED                                : out   std_logic;
		LED_FAN_YELLOW                             : out   std_logic;

		--Flash ROM & Reboot
		FLASH_CLK                                  : out   std_logic;
		FLASH_CS                                   : out   std_logic;
		FLASH_DIN                                  : out   std_logic;
		FLASH_DOUT                                 : in    std_logic;
		PROGRAMN                                   : out   std_logic := '1'; --reboot FPGA

		--Misc
		ENPIRION_CLOCK                             : out   std_logic; --Clock for power supply, not necessary, floating
		TEMPSENS                                   : inout std_logic; --Temperature Sensor
		LED_CLOCK_GREEN                            : out   std_logic;
		LED_CLOCK_RED                              : out   std_logic;
		LED_GREEN                                  : out   std_logic;
		LED_ORANGE                                 : out   std_logic;
		LED_RED                                    : out   std_logic;
		LED_TRIGGER_GREEN                          : out   std_logic;
		LED_TRIGGER_RED                            : out   std_logic;
		LED_YELLOW                                 : out   std_logic;

		--Test Connectors
		TEST_LINE                                  : out   std_logic_vector(31 downto 0);

		-- SODA pinout
		SODA_SRC_TXP_OUT, SODA_SRC_TXN_OUT         : out   std_logic;
		SODA_SRC_RXP_IN, SODA_SRC_RXN_IN           : in    std_logic;
		ENDP_RXP_IN, ENDP_RXN_IN                   : in    std_logic_vector(3 downto 0);
		ENDP_TXP_OUT, ENDP_TXN_OUT                 : out   std_logic_vector(3 downto 0);
		SODA_READOUT_TXP_OUT, SODA_READOUT_TXN_OUT : out   std_logic;

		CODE_LINE                                  : in    std_logic_vector(1 downto 0)
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
	constant SWITCHABLE_SODA     : boolean                       := false;
	constant EXTERNAL_SODA       : boolean                       := true;
	constant REGIO_INIT_ADDRESS  : std_logic_vector(15 downto 0) := x"f300";
	constant REGIO_NUM_STAT_REGS : integer                       := 2;
	constant REGIO_NUM_CTRL_REGS : integer                       := 2;

	attribute syn_keep : boolean;
	attribute syn_preserve : boolean;

	component CLKDIVB
		-- synthesis translate_off
		generic(
			GSR : in String);
		-- synthesis translate_on
		port(
			CLKI, RST, RELEASE         : IN  std_logic;
			CDIV1, CDIV2, CDIV4, CDIV8 : OUT std_logic);
	end component;

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

	--Media Interface
	--	signal med_stat_op        : std_logic_vector(c_DATA_WIDTH - 1 downto 0);
	--	signal med_ctrl_op        : std_logic_vector(c_DATA_WIDTH - 1 downto 0);
	--	signal med_stat_debug     : std_logic_vector(1 * 64 - 1 downto 0);
	--	signal med_ctrl_debug     : std_logic_vector(1 * 64 - 1 downto 0);
	--	signal med_data_out       : std_logic_vector(c_DATA_WIDTH - 1 downto 0);
	--	signal med_packet_num_out : std_logic_vector(1 * 3 - 1 downto 0);
	--	signal med_dataready_out  : std_logic;
	--	signal med_read_out       : std_logic;
	--	signal med_data_in        : std_logic_vector(c_DATA_WIDTH - 1 downto 0);
	--	signal med_packet_num_in  : std_logic_vector(1 * 3 - 1 downto 0);
	--	signal med_dataready_in   : std_logic;
	--	signal med_read_in        : std_logic;

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

	signal trigger_busy_i : std_logic;

	signal led_time_ref_i : std_logic;

	signal do_reboot_i : std_logic;
	-- soda signals

	signal reset_SODAclock_S      : std_logic;
	signal reset_fibers_S         : std_logic;
	signal fiber_txlocked_S       : std_logic_vector(0 to NROFFIBERS - 1) := (others => '0');
	signal fiber_rxlocked_S       : std_logic_vector(0 to NROFFIBERS - 1) := (others => '0');
	signal superburst_update_S    : std_logic;
	signal superburst_number_S    : std_logic_vector(30 downto 0);
	signal fiber_data32write_S    : std_logic_vector(0 to NROFFIBERS - 1) := (others => '0');
	signal fiber_data32out_S      : array_fiber32bits_type;
	signal fiber_data32fifofull_S : std_logic_vector(0 to NROFFIBERS - 1);
	signal fiber_data32read_S     : std_logic_vector(0 to NROFFIBERS - 1);
	signal fiber_data32present_S  : std_logic_vector(0 to NROFFIBERS - 1) := (others => '0');
	signal fiber_data32in_S       : array_fiber32bits_type;
	signal fiber_rxerror_S        : std_logic_vector(0 to NROFFIBERS - 1);

	signal TXfee_DLM_S      : std_logic_vector(0 to NROFFIBERS - 1);
	signal TXfee_DLM_word_S : array_fiber8bits_type;
	signal RXfee_DLM_S      : std_logic_vector(0 to NROFFIBERS - 1);
	signal RXfee_DLM_word_S : array_fiber8bits_type;

	signal RXBTM_DLM_S      : t_HUB_BIT;
	signal RXBTM_DLM_WORD_S : t_HUB_BYTE;
	signal TXBTM_DLM_S      : t_HUB_BIT;
	signal TXBTM_DLM_WORD_S : t_HUB_BYTE;

	signal RXtop_DLM_S      : std_logic;
	signal RXtop_DLM_word_S : std_logic_vector(7 downto 0) := (others => '0');
	signal TXtop_DLM_S      : std_logic;
	signal TXtop_DLM_word_S : std_logic_vector(7 downto 0) := (others => '0');

	signal soda_read_en  : std_logic;
	signal soda_write_en : std_logic;
	signal soda_ack      : std_logic;
	signal soda_addr     : std_logic_vector(3 downto 0);
	signal soda_data_in  : std_logic_vector(31 downto 0);
	signal soda_data_out : std_logic_vector(31 downto 0);

	signal common_stat_reg                                                                : std_logic_vector(std_COMSTATREG * 32 - 1 downto 0);
	signal common_ctrl_reg                                                                : std_logic_vector(std_COMCTRLREG * 32 - 1 downto 0);
	signal clk_80_i, clk_160_i, clk_160div3_i, PACKETIN_clock, PACKETOUT_clock, MUX_clock : std_logic;
	signal clk_SODA200_i                                                                  : std_logic;
	signal clk_200_i_S                                                                    : std_logic;
	signal SODA_clock_rx_S                                                                : std_logic;
	signal EnableExternalSODA_S                                                           : std_logic;
	signal SODA_clock_rx                                                                  : std_logic;
	signal EnableExternalSODAsync_S                                                       : std_logic;
	signal txpll_clocks_S                                                                 : std_logic_vector(3 downto 0);
	signal ext_sodasrc_TX_DLM_S                                                           : std_logic;
	signal ext_sodasrc_TX_DLM_WORD_S                                                      : std_logic_vector(7 downto 0);
	signal ext_sodasrc_TX_DLM_sync1_S                                                     : std_logic;
	signal ext_sodasrc_TX_DLM_word_sync1_S                                                : std_logic_vector(7 downto 0);
	signal ext_sodasrc_TX_DLM_sync2_S                                                     : std_logic;
	signal ext_sodasrc_TX_DLM_word_sync2_S                                                : std_logic_vector(7 downto 0);

	signal tx_data_ch3              : std_logic_vector(7 downto 0);
	signal tx_k_ch3                 : std_logic;
	signal tx_ready_ch3             : std_logic;
	signal data64b_muxed_allowed    : std_logic;
	signal data64b_muxed            : std_logic_vector(63 downto 0);
	signal data64b_muxed_write      : std_logic;
	signal data64b_muxed_first      : std_logic;
	signal data64b_muxed_last       : std_logic;
	signal data64b_muxed_error      : std_logic;
	signal data64b_muxed_error_S    : std_logic;
	signal data64b_muxed_allowed0_S : std_logic;
	signal data64b_muxed_allowed_S  : std_logic;
	signal data64b_muxed_busy_S     : std_logic;
	signal no_packet_limit_S        : std_logic;

	signal dc_read_en         : std_logic := '0';
	signal dc_write_en        : std_logic := '0';
	signal dc_busy            : std_logic := '0';
	signal dc_ack             : std_logic := '0';
	signal dc_addr            : std_logic_vector(1 downto 0);
	signal dc_data_in         : std_logic_vector(31 downto 0);
	signal dc_data_out        : std_logic_vector(31 downto 0);
	signal SODA_burst_pulse_S : std_logic;
	signal soda_40mhz_cycle_S : std_logic;

	signal sodasrc_read_en       : std_logic;
	signal sodasrc_write_en      : std_logic;
	signal sodasrc_ack           : std_logic;
	signal sodasrc_addr          : std_logic_vector(3 downto 0);
	signal sodasrc_data_in       : std_logic_vector(31 downto 0);
	signal sodasrc_data_out      : std_logic_vector(31 downto 0);
	signal sodasrc_TX_DLM_S      : std_logic;
	signal sodasrc_TX_DLM_word_S : std_logic_vector(7 downto 0);
	signal LEDs_link_ok_i        : std_logic_vector(0 to 3);

	signal sci2_ack      : std_logic;
	signal sci2_write    : std_logic;
	signal sci2_read     : std_logic;
	signal sci2_data_in  : std_logic_vector(7 downto 0);
	signal sci2_data_out : std_logic_vector(7 downto 0);
	signal sci2_addr     : std_logic_vector(8 downto 0);

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
			CLEAR_IN      => '0',       -- reset input (high active, async)
			CLEAR_N_IN    => '1',       -- reset input (low active, async)
			CLK_IN        => clk_200_i, -- raw master clock, NOT from PLL/DLL!
			SYSCLK_IN     => clk_100_i, -- PLL/DLL remastered clock
			PLL_LOCKED_IN => pll_lock,  -- master PLL lock signal (async)
			RESET_IN      => '0',       -- general reset signal (SYSCLK)
			TRB_RESET_IN  => med_stat_op(13), -- TRBnet reset signal (SYSCLK)
			CLEAR_OUT     => clear_i,   -- async reset out, USE WITH CARE!
			RESET_OUT     => reset_i,   -- synchronous reset out (SYSCLK)
			DEBUG_OUT     => open
		);

	---------------------------------------------------------------------------
	-- Clock Handling
	---------------------------------------------------------------------------

	THE_MAIN_PLL : pll_in200_out100
		port map(
			CLK   => CLK_GPLL_LEFT,     --CLK_GPLL_RIGHT,
			RESET => '0',
			CLKOP => clk_100_i,
			CLKOK => clk_200_i,
			LOCK  => pll_lock
		);

	THE_CLOCK80 : entity work.pll_in100_out80M
		port map(
			CLK    => clk_100_i,
			CLKOP  => clk_160_i,        -- 160MHz
			CLKOK  => clk_80_i,         -- 80MHz
			CLKOK2 => clk_160div3_i,    -- 160/3MHz
			LOCK   => open);

	PACKETIN_clock  <= clk_80_i;        -- clk_160div3_i;
	MUX_clock       <= clk_100_i;
	PACKETOUT_clock <= clk_80_i;

	clk_125_i <= CLK_GPLL_RIGHT;

	---------------------------------------------------------------------------
	-- SODA clock generation
	---------------------------------------------------------------------------
	gen_noclockswitch : if not SWITCHABLE_SODA generate
		gen_externalsoda : if EXTERNAL_SODA generate
			process(clk_SODA200_i)
			begin
				if (rising_edge(clk_SODA200_i)) then
					RXtop_DLM_S      <= ext_sodasrc_TX_DLM_S;
					RXtop_DLM_word_S <= ext_sodasrc_TX_DLM_word_S;
				end if;
			end process;
			clk_SODA200_i <= SODA_clock_rx;
		end generate;
		gen_internalsoda : if not EXTERNAL_SODA generate
			process(clk_SODA200_i)
			begin
				if (rising_edge(clk_SODA200_i)) then
					RXtop_DLM_S      <= sodasrc_TX_DLM_S;
					RXtop_DLM_word_S <= sodasrc_TX_DLM_word_S;
				end if;
			end process;
			clk_SODA200_i <= clk_200_i;
		end generate;
	end generate;

	gen_clockswitch : if SWITCHABLE_SODA generate
		RXtop_DLM_S      <= ext_sodasrc_TX_DLM_sync2_S when EnableExternalSODAsync_S = '1' else sodasrc_TX_DLM_S;
		RXtop_DLM_word_S <= ext_sodasrc_TX_DLM_word_sync2_S when EnableExternalSODAsync_S = '1' else sodasrc_TX_DLM_word_S;

		sync_EnableExternalSODA : entity work.sync_bit
			port map(
				clock    => clk_SODA200_i,
				data_in  => EnableExternalSODA_S,
				data_out => EnableExternalSODAsync_S
			);

		CLKDIVB1 : CLKDIVB
			port map(
				CLKI    => clk_200_i,
				RST     => '0',
				RELEASE => '1',
				CDIV1   => clk_200_i_S,
				CDIV2   => open,
				CDIV4   => open,
				CDIV8   => open
			);

		DLLl_in200M_out200M1 : entity work.DLLl_in200M_out200M
			port map(
				clki    => SODA_clock_rx,
				clkop   => open,
				clkos   => SODA_clock_rx_S,
				lock    => open,
				aluhold => '0'
			);

		process(SODA_clock_rx_S)
		begin
			if (rising_edge(SODA_clock_rx_S)) then
				ext_sodasrc_TX_DLM_sync1_S      <= ext_sodasrc_TX_DLM_S;
				ext_sodasrc_TX_DLM_word_sync1_S <= ext_sodasrc_TX_DLM_word_S;
			end if;
		end process;
		process(clk_SODA200_i)
		begin
			if (rising_edge(clk_SODA200_i)) then
				ext_sodasrc_TX_DLM_sync2_S      <= ext_sodasrc_TX_DLM_sync1_S;
				ext_sodasrc_TX_DLM_word_sync2_S <= ext_sodasrc_TX_DLM_word_sync1_S;
			end if;
		end process;

		SODAclockswitch : dcs
			-- synthesis translate_off
			generic map(
				DCSMODE => "POS")
			-- synthesis translate_on
			port map(
				clk0   => clk_200_i_S,
				clk1   => SODA_clock_rx_S,
				sel    => EnableExternalSODA_S,
				dcsout => clk_SODA200_i
			);

	end generate;

	---------------------------------------------------------------------------
	-- SODA connection to the source
	---------------------------------------------------------------------------
	THE_MEDIA_UPLINK : entity work.trb_net16_med_2sync_3_ecp3_sfp
		port map(
			CLK                => clk_200_i,
			SYSCLK             => clk_100_i,
			RESET              => reset_i,
			CLEAR              => clear_i,
			CLK_EN             => '1',

			--Internal Connection
			-- connected to the first port of the streaming hub
			MED_DATA_IN        => med_data_out(1 * 16 - 1 downto 0),
			MED_PACKET_NUM_IN  => med_packet_num_out(1 * 3 - 1 downto 0),
			MED_DATAREADY_IN   => med_dataready_out(0),
			MED_READ_OUT       => med_read_in(0),
			MED_DATA_OUT       => med_data_in(1 * 16 - 1 downto 0),
			MED_PACKET_NUM_OUT => med_packet_num_in(1 * 3 - 1 downto 0),
			MED_DATAREADY_OUT  => med_dataready_in(0),
			MED_READ_IN        => med_read_out(0),
			REFCLK2CORE_OUT    => open,
			CLK_RX_HALF_OUT    => open,
			CLK_RX_FULL_OUT    => open,

			--Control Interface
			SCI_DATA_IN        => (others => '0'),
			SCI_DATA_OUT       => open,
			SCI_ADDR           => (others => '0'),
			SCI_READ           => '0',
			SCI_WRITE          => '0',
			SCI_ACK            => open,
			SCI_NACK           => open,

			-- SODA serdes channel
			SODA_RXD_P_IN      => SODA_SRC_RXP_IN,
			SODA_RXD_N_IN      => SODA_SRC_RXN_IN,
			SODA_TXD_P_OUT     => SODA_SRC_TXP_OUT,
			SODA_TXD_N_OUT     => SODA_SRC_TXN_OUT,
			SODA_PRSNT_N_IN    => SFP_LOS(1),
			SODA_LOS_IN        => SFP_LOS(1),
			SODA_TXDIS_OUT     => SFP_TXDIS(1),
			SODA_DLM_IN        => TXtop_DLM_S,
			SODA_DLM_WORD_IN   => TXtop_DLM_word_S,
			SODA_DLM_OUT       => ext_sodasrc_TX_DLM_S,
			SODA_DLM_WORD_OUT  => ext_sodasrc_TX_DLM_WORD_S,
			SODA_CLOCK_OUT     => SODA_clock_rx,

			-- Connection to addon interface
			DATASFP_TXD_P_OUT  => SODA_READOUT_TXP_OUT,
			DATASFP_TXD_N_OUT  => SODA_READOUT_TXN_OUT,
			DATASFP_MOD0       => SFP_MOD0(2),
			DATASFP_LOS_IN     => SFP_LOS(2),
			DATASFP_READY_OUT  => tx_ready_ch3,
			DATASFP_DATA_IN    => tx_data_ch3,
			DATASFP_KCHAR_IN   => tx_k_ch3,

			-- Status and control port
			STAT_OP            => med_stat_op(1 * 16 - 1 downto 0),
			CTRL_OP            => med_ctrl_op(1 * 16 - 1 downto 0),
			STAT_DEBUG         => open,
			CTRL_DEBUG         => (others => '0')
		);

	sync_reset_SODAclock : entity work.sync_bit
		port map(
			clock    => clk_SODA200_i,
			data_in  => reset_i,
			data_out => reset_SODAclock_S
		);

	---------------------------------------------------------------------------
	-- Recover SODA superburst data 
	--------------------------------------------------------------------------- 

	soda_packet_handler1 : soda_packet_handler
		port map(
			SODACLK                  => clk_SODA200_i,
			RESET                    => reset_SODAclock_S,
			CLEAR                    => '0',
			CLK_EN                   => '1',
			--Internal Connection
			START_OF_SUPERBURST_OUT  => superburst_update_S,
			SUPER_BURST_NR_OUT       => superburst_number_S,
			START_OF_CALIBRATION_OUT => open,
			SODA_CMD_VALID_OUT       => open,
			SODA_CMD_WORD_OUT        => open,
			RX_DLM_IN                => RXtop_DLM_S, --TXfee_DLM_S(0),
			RX_DLM_WORD_IN           => RXtop_DLM_word_S --TXfee_DLM_word_S(0)
		);

	---------------------------------------------------------------------------
	-- Data Concentrator
	--------------------------------------------------------------------------- 

	THE_DATACONCENTRATOR_FROM_TDC : entity work.dc_module_trb_tdc
		port map(
			slowcontrol_clock    => clk_100_i,
			packet_in_clock      => PACKETIN_clock,
			MUX_clock            => MUX_clock,
			packet_out_clock     => PACKETOUT_clock,
			SODA_clock           => clk_SODA200_i,
			reset                => reset_i,

			-- Slave bus
			BUS_READ_IN          => dc_read_en,
			BUS_WRITE_IN         => dc_write_en,
			BUS_BUSY_OUT         => dc_busy,
			BUS_ACK_OUT          => dc_ack,
			BUS_ADDR_IN          => dc_addr,
			BUS_DATA_IN          => dc_data_in,
			BUS_DATA_OUT         => dc_data_out,

			-- fiber interface signals:
			fiber_txlocked       => fiber_txlocked_S,
			fiber_rxlocked       => fiber_rxlocked_S,
			reset_fibers         => reset_fibers_S,
			fiber_data32write    => fiber_data32write_S,
			fiber_data32out      => fiber_data32out_S,
			fiber_data32fifofull => fiber_data32fifofull_S,
			fiber_data32read     => fiber_data32read_S,
			fiber_data32present  => fiber_data32present_S,
			fiber_data32in       => fiber_data32in_S,
			fiber_rxerror        => fiber_rxerror_S,

			-- SODA signals
			superburst_number    => superburst_number_S,
			superburst_update    => superburst_update_S,
			SODA_enable          => open,
			EnableExternalSODA   => EnableExternalSODA_S,

			-- 64 bits data output
			data_out_allowed     => data64b_muxed_allowed_S,
			data_out             => data64b_muxed,
			data_out_write       => data64b_muxed_write,
			data_out_first       => data64b_muxed_first,
			data_out_last        => data64b_muxed_last,
			data_out_error       => data64b_muxed_error,
			no_packet_limit      => open,

			-- testpoints
			testword0            => open,
			testword0clock       => open,
			testword1            => open,
			testword2            => open
		);

	---------------------------------------------------------------------------
	-- Data preparation
	--------------------------------------------------------------------------- 

	dataconversion_for_serdes_inst : entity work.dataconversion_for_serdes
		port map(
			DATA_CLK        => PACKETOUT_clock,
			CLK             => clk_100_i,
			RESET           => reset_i,
			TX_READY        => tx_ready_ch3,
			SFP_MOD0        => SFP_MOD0(2),
			SFP_LOS         => SFP_LOS(2),
			TX_DATA         => tx_data_ch3,
			TX_K            => tx_k_ch3,
			DATA_IN_ALLOWED => data64b_muxed_allowed_S,
			DATA_IN         => data64b_muxed,
			DATA_IN_WRITE   => data64b_muxed_write,
			DATA_IN_FIRST   => data64b_muxed_first,
			DATA_IN_LAST    => data64b_muxed_last,
			DATA_IN_ERROR   => data64b_muxed_error
		);

	---------------------------------------------------------------------------
	-- The TrbNet media interface (to other FPGA)
	---------------------------------------------------------------------------
	THE_MEDIA_ONBOARD : trb_net16_med_ecp3_sfp_4
		generic map(
			FREQUENCY => MEDIA_FREQUENCY
		)
		port map(
			CLK                => clk_200_i,
			SYSCLK             => clk_100_i,
			RESET              => reset_i,
			CLEAR              => clear_i,
			CLK_EN             => '1',
			--Internal Connection
			MED_DATA_IN        => med_data_out(63 downto 0),
			MED_PACKET_NUM_IN  => med_packet_num_out(11 downto 0),
			MED_DATAREADY_IN   => med_dataready_out(3 downto 0),
			MED_READ_OUT       => med_read_in(3 downto 0),
			MED_DATA_OUT       => med_data_in(63 downto 0),
			MED_PACKET_NUM_OUT => med_packet_num_in(11 downto 0),
			MED_DATAREADY_OUT  => med_dataready_in(3 downto 0),
			MED_READ_IN        => med_read_out(3 downto 0),
			REFCLK2CORE_OUT    => open,
			--SFP Connection
			SD_RXD_P_IN        => ENDP_RXP_IN,
			SD_RXD_N_IN        => ENDP_RXN_IN,
			SD_TXD_P_OUT       => ENDP_TXP_OUT,
			SD_TXD_N_OUT       => ENDP_TXN_OUT,
			SD_REFCLK_P_IN     => open,
			SD_REFCLK_N_IN     => open,
			SD_PRSNT_N_IN(0)   => FPGA1_COMM(2),
			SD_PRSNT_N_IN(1)   => FPGA2_COMM(2),
			SD_PRSNT_N_IN(2)   => FPGA3_COMM(2),
			SD_PRSNT_N_IN(3)   => FPGA4_COMM(2),
			SD_LOS_IN(0)       => FPGA1_COMM(2),
			SD_LOS_IN(1)       => FPGA2_COMM(2),
			SD_LOS_IN(2)       => FPGA3_COMM(2),
			SD_LOS_IN(3)       => FPGA4_COMM(2),
			SD_TXDIS_OUT(0)    => FPGA1_COMM(0),
			SD_TXDIS_OUT(1)    => FPGA2_COMM(0),
			SD_TXDIS_OUT(2)    => FPGA3_COMM(0),
			SD_TXDIS_OUT(3)    => FPGA4_COMM(0),
			
			-- not connected to anything
			SCI_DATA_IN        => sci2_data_in,
			SCI_DATA_OUT       => sci2_data_out,
			SCI_ADDR           => sci2_addr,
			SCI_READ           => sci2_read,
			SCI_WRITE          => sci2_write,
			SCI_ACK            => sci2_ack,
			
			-- Status and control port
			STAT_OP            => med_stat_op(63 downto 0),
			CTRL_OP            => med_ctrl_op(63 downto 0),
			STAT_DEBUG         => med_stat_debug(3 * 64 + 63 downto 0 * 64),
			CTRL_DEBUG         => (others => '0')
		);

	---------------------------------------------------------------------------
	-- TrbNet HUB
	--------------------------------------------------------------------------- 

	THE_HUB : trb_net16_hub_streaming_port
		generic map(
			HUB_USED_CHANNELS      => USED_CHANNELS,
			INIT_ADDRESS           => INIT_ADDRESS,
			MII_NUMBER             => INTERFACE_NUM,
			MII_IS_UPLINK          => IS_UPLINK,
			MII_IS_DOWNLINK        => IS_DOWNLINK,
			MII_IS_UPLINK_ONLY     => IS_UPLINK_ONLY,
			USE_ONEWIRE            => c_YES,
			HARDWARE_VERSION       => HARDWARE_INFO,
			INCLUDED_FEATURES      => INCLUDED_FEATURES,
			INIT_ENDPOINT_ID       => x"0005",
			CLOCK_FREQUENCY        => CLOCK_FREQUENCY,
			BROADCAST_SPECIAL_ADDR => BROADCAST_SPECIAL_ADDR
		)
		port map(
			CLK                                    => clk_100_i,
			RESET                                  => reset_i,
			CLK_EN                                 => '1',

			--Media interfacces
			MED_DATAREADY_OUT(5 * 1 - 1 downto 0)  => med_dataready_out,
			MED_DATA_OUT(5 * 16 - 1 downto 0)      => med_data_out,
			MED_PACKET_NUM_OUT(5 * 3 - 1 downto 0) => med_packet_num_out,
			MED_READ_IN(5 * 1 - 1 downto 0)        => med_read_in,
			MED_DATAREADY_IN(5 * 1 - 1 downto 0)   => med_dataready_in,
			MED_DATA_IN(5 * 16 - 1 downto 0)       => med_data_in,
			MED_PACKET_NUM_IN(5 * 3 - 1 downto 0)  => med_packet_num_in,
			MED_READ_OUT(5 * 1 - 1 downto 0)       => med_read_out,
			MED_STAT_OP(5 * 16 - 1 downto 0)       => med_stat_op,
			MED_CTRL_OP(5 * 16 - 1 downto 0)       => med_ctrl_op,

			--Event information coming from CTSCTS_READOUT_TYPE_OUT
			CTS_NUMBER_OUT                         => open,
			CTS_CODE_OUT                           => open,
			CTS_INFORMATION_OUT                    => open,
			CTS_READOUT_TYPE_OUT                   => open,
			CTS_START_READOUT_OUT                  => open,
			--Information   sent to CTS
			--status data, equipped with DHDR
			CTS_DATA_IN                            => (others => '0'),
			CTS_DATAREADY_IN                       => '0',
			CTS_READOUT_FINISHED_IN                => '0',
			CTS_READ_OUT                           => open,
			CTS_LENGTH_IN                          => (others => '0'),
			CTS_STATUS_BITS_IN                     => (others => '0'),
			-- Data from Frontends
			FEE_DATA_OUT                           => open,
			FEE_DATAREADY_OUT                      => open,
			FEE_READ_IN                            => '1',
			FEE_STATUS_BITS_OUT                    => open,
			FEE_BUSY_OUT                           => open,
			MY_ADDRESS_IN                          => my_address,
			COMMON_STAT_REGS                       => common_stat_regs, --open,
			COMMON_CTRL_REGS                       => common_ctrl_regs, --open,
			ONEWIRE                                => TEMPSENS,
			ONEWIRE_MONITOR_IN                     => open,
			MY_ADDRESS_OUT                         => my_address,
			TIMER_TICKS_OUT                        => open,
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

	---------------------------------------------------------------------------
	-- Bus Handler
	---------------------------------------------------------------------------
	THE_BUS_HANDLER : trb_net16_regio_bus_handler
		generic map(
			PORT_NUMBER    => 5,
			PORT_ADDRESSES => (0 => x"d000", 1 => x"d100", 2 => x"e000", 3 => x"e100", 4 => x"e200", others => x"0000"),
			PORT_ADDR_MASK => (0 => 1, 1 => 6, 2 => 2, 3 => 4, 4 => 4, others => 0)
		--     PORT_MASK_ENABLE => 0
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
			BUS_READ_ENABLE_OUT(0)                      => spictrl_read_en,
			BUS_READ_ENABLE_OUT(1)                      => spimem_read_en,
			BUS_READ_ENABLE_OUT(2)                      => dc_read_en,
			BUS_READ_ENABLE_OUT(3)                      => soda_read_en,
			BUS_READ_ENABLE_OUT(4)                      => sodasrc_read_en,
			BUS_WRITE_ENABLE_OUT(0)                     => spictrl_write_en,
			BUS_WRITE_ENABLE_OUT(1)                     => spimem_write_en,
			BUS_WRITE_ENABLE_OUT(2)                     => dc_write_en,
			BUS_WRITE_ENABLE_OUT(3)                     => soda_write_en,
			BUS_WRITE_ENABLE_OUT(4)                     => sodasrc_write_en,
			BUS_DATA_OUT(0 * 32 + 31 downto 0 * 32)     => spictrl_data_in,
			BUS_DATA_OUT(1 * 32 + 31 downto 1 * 32)     => spimem_data_in,
			BUS_DATA_OUT(2 * 32 + 31 downto 2 * 32)     => dc_data_in,
			BUS_DATA_OUT(3 * 32 + 31 downto 3 * 32)     => soda_data_in,
			BUS_DATA_OUT(4 * 32 + 31 downto 4 * 32)     => sodasrc_data_in,
			BUS_ADDR_OUT(0 * 16)                        => spictrl_addr,
			BUS_ADDR_OUT(0 * 16 + 15 downto 0 * 16 + 1) => open,
			BUS_ADDR_OUT(1 * 16 + 5 downto 1 * 16)      => spimem_addr,
			BUS_ADDR_OUT(1 * 16 + 15 downto 1 * 16 + 6) => open,
			BUS_ADDR_OUT(2 * 16 + 1 downto 2 * 16)      => dc_addr,
			BUS_ADDR_OUT(2 * 16 + 15 downto 2 * 16 + 2) => open,
			BUS_ADDR_OUT(3 * 16 + 3 downto 3 * 16)      => soda_addr,
			BUS_ADDR_OUT(3 * 16 + 15 downto 3 * 16 + 4) => open,
			BUS_ADDR_OUT(4 * 16 + 3 downto 4 * 16)      => sodasrc_addr,
			BUS_ADDR_OUT(4 * 16 + 15 downto 4 * 16 + 4) => open,
			BUS_DATA_IN(0 * 32 + 31 downto 0 * 32)      => spictrl_data_out,
			BUS_DATA_IN(1 * 32 + 31 downto 1 * 32)      => spimem_data_out,
			BUS_DATA_IN(2 * 32 + 31 downto 2 * 32)      => dc_data_out,
			BUS_DATA_IN(3 * 32 + 31 downto 3 * 32)      => soda_data_out,
			BUS_DATA_IN(4 * 32 + 31 downto 4 * 32)      => sodasrc_data_out,
			BUS_DATAREADY_IN(0)                         => spictrl_ack,
			BUS_DATAREADY_IN(1)                         => spimem_ack,
			BUS_DATAREADY_IN(2)                         => dc_ack,
			BUS_DATAREADY_IN(3)                         => soda_ack,
			BUS_DATAREADY_IN(4)                         => sodasrc_ack,
			BUS_WRITE_ACK_IN(0)                         => spictrl_ack,
			BUS_WRITE_ACK_IN(1)                         => spimem_ack,
			BUS_WRITE_ACK_IN(2)                         => dc_ack,
			BUS_WRITE_ACK_IN(3)                         => soda_ack,
			BUS_WRITE_ACK_IN(4)                         => sodasrc_ack,
			BUS_NO_MORE_DATA_IN(0)                      => spictrl_busy,
			BUS_NO_MORE_DATA_IN(1)                      => '0',
			BUS_NO_MORE_DATA_IN(2)                      => dc_busy,
			BUS_NO_MORE_DATA_IN(3)                      => '0',
			BUS_NO_MORE_DATA_IN(4)                      => '0',
			BUS_UNKNOWN_ADDR_IN(0)                      => '0',
			BUS_UNKNOWN_ADDR_IN(1)                      => '0',
			BUS_UNKNOWN_ADDR_IN(2)                      => '0',
			BUS_UNKNOWN_ADDR_IN(3)                      => '0',
			BUS_UNKNOWN_ADDR_IN(4)                      => '0',
			BUS_TIMEOUT_OUT(0)                          => open,
			BUS_TIMEOUT_OUT(1)                          => open,
			BUS_TIMEOUT_OUT(2)                          => open,
			BUS_TIMEOUT_OUT(3)                          => open,
			BUS_TIMEOUT_OUT(4)                          => open,

			--Bus Handler (SPI CTRL)
			--Bus Handler (SPI Memory)
			--Bus Handler (test port)

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

	do_reboot_i <= common_ctrl_regs(15);

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
	LED_CLOCK_RED   <= '0';
	--   LED_GREEN                      <= not med_stat_op(9);
	--   LED_YELLOW                     <= not med_stat_op(10);
	--   LED_ORANGE                     <= not med_stat_op(11); 
	--   LED_RED                        <= '1';


	LED_GREEN  <= LEDs_link_ok_i(0);    -- debug(0);
	LED_ORANGE <= LEDs_link_ok_i(1);    -- debug(1);
	LED_RED    <= LEDs_link_ok_i(2);    -- debug(2);
	LED_YELLOW <= LEDs_link_ok_i(3);    -- link_ok;

	---------------------------------------------------------------------------
	-- Test Connector
	---------------------------------------------------------------------------    
	TEST_LINE <= (others => '0');

end architecture;
