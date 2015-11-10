--Media interface for Lattice ECP3 using PCS at 2GHz
--Three channels are used:
--  ch1 : for TRBnet at 200MHz (2 Gbit/s fiber speed)
--  ch2 : SODA, synchronized on incoming fiber-bits, 200MHz (2 Gbit/s fiber speed)
--  ch3 : fiber to UDP converter, only output, 100MHz with 200MHz reference clock  (1 Gbit/s fiber speed)

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.med_sync_define.all;

entity trb_net16_med_1_2sync_3_ecp3_sfp is
  port(
    CLK                : in  std_logic; -- SerDes clock
    SYSCLK             : in  std_logic; -- fabric clock
    RESET              : in  std_logic; -- synchronous reset
    CLEAR              : in  std_logic; -- asynchronous reset
    CLK_EN             : in  std_logic;
    --Internal Connection
    MED_DATA_IN        : in  std_logic_vector(c_DATA_WIDTH-1 downto 0);
    MED_PACKET_NUM_IN  : in  std_logic_vector(c_NUM_WIDTH-1 downto 0);
    MED_DATAREADY_IN   : in  std_logic;
    MED_READ_OUT       : out std_logic;
    MED_DATA_OUT       : out std_logic_vector(c_DATA_WIDTH-1 downto 0);
    MED_PACKET_NUM_OUT : out std_logic_vector(c_NUM_WIDTH-1 downto 0);
    MED_DATAREADY_OUT  : out std_logic;
    MED_READ_IN        : in  std_logic;
    REFCLK2CORE_OUT    : out std_logic;
    CLK_RX_HALF_OUT    : out std_logic;
    CLK_RX_FULL_OUT    : out std_logic;
    --SFP Connection
    SD_RXD_P_IN        : in  std_logic;
    SD_RXD_N_IN        : in  std_logic;
    SD_TXD_P_OUT       : out std_logic;
    SD_TXD_N_OUT       : out std_logic;
    SD_REFCLK_P_IN     : in  std_logic;
    SD_REFCLK_N_IN     : in  std_logic;
    SD_PRSNT_N_IN      : in  std_logic;  -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
    SD_LOS_IN          : in  std_logic;  -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
    SD_TXDIS_OUT       : out  std_logic; -- SFP disable
    --Control Interface
    SCI_DATA_IN        : in  std_logic_vector(7 downto 0) := (others => '0');
    SCI_DATA_OUT       : out std_logic_vector(7 downto 0) := (others => '0');
    SCI_ADDR           : in  std_logic_vector(8 downto 0) := (others => '0');
    SCI_READ           : in  std_logic := '0';
    SCI_WRITE          : in  std_logic := '0';
    SCI_ACK            : out std_logic := '0';
    SCI_NACK           : out std_logic := '0';
	-- SODA serdes channel
    SODA_RXD_P_IN      : in  std_logic;
    SODA_RXD_N_IN      : in  std_logic;
    SODA_TXD_P_OUT     : out std_logic;
    SODA_TXD_N_OUT     : out std_logic;
	SODA_DLM_IN        : in  std_logic;
	SODA_DLM_WORD_IN   : in  std_logic_vector(7 downto 0);
	SODA_DLM_OUT       : out  std_logic;
	SODA_DLM_WORD_OUT  : out  std_logic_vector(7 downto 0);
    SODA_CLOCK_OUT     : out  std_logic; -- 200MHz
	
    -- Connection to addon interface        
    DOUT_TXD_P_OUT     : out  std_logic;
    DOUT_TXD_N_OUT     : out  std_logic;
    SFP_MOD0_5         : in  std_logic;
    SFP_MOD0_3         : in  std_logic;          
    SFP_LOS_5          : in  std_logic;          
    SFP_LOS_3          : in  std_logic;
	TX_READY_CH3       : out std_logic;
    TX_DATA_CH3        : in std_logic_vector(7 downto 0);
    TX_K_CH3           : in std_logic;
    -- Status and control port
    STAT_OP            : out std_logic_vector (15 downto 0);
    CTRL_OP            : in  std_logic_vector (15 downto 0);
    STAT_DEBUG         : out std_logic_vector (63 downto 0);
    CTRL_DEBUG         : in  std_logic_vector (63 downto 0)
   );
end entity;

architecture trb_net16_med_1_2sync_3_ecp3_sfp_arch of trb_net16_med_1_2sync_3_ecp3_sfp is


  -- Placer Directives
  attribute HGROUP : string;
  -- for whole architecture
  attribute HGROUP of trb_net16_med_1_2sync_3_ecp3_sfp_arch : architecture  is "media_interface_group";
  attribute syn_sharing : string;
  attribute syn_sharing of trb_net16_med_1_2sync_3_ecp3_sfp_arch : architecture is "off";

  --OJK 29-nov-2013
	component sfp_1_3_200_int
	port(
		hdinp_ch1          : IN std_logic;
		hdinn_ch1          : IN std_logic;
		sci_sel_ch1        : IN std_logic;
		rxiclk_ch1         : IN std_logic;
		txiclk_ch1         : IN std_logic;
		fpga_rxrefclk_ch1  : IN std_logic;
		txdata_ch1         : IN std_logic_vector(15 downto 0);
		tx_k_ch1           : IN std_logic_vector(1 downto 0);
		tx_force_disp_ch1  : IN std_logic_vector(1 downto 0);
		tx_disp_sel_ch1    : IN std_logic_vector(1 downto 0);
		sb_felb_ch1_c      : IN std_logic;
		sb_felb_rst_ch1_c  : IN std_logic;
		tx_pwrup_ch1_c     : IN std_logic;
		rx_pwrup_ch1_c     : IN std_logic;
		tx_div2_mode_ch1_c : IN std_logic;
		rx_div2_mode_ch1_c : IN std_logic;
		sci_sel_ch3        : IN std_logic;
		txiclk_ch3         : IN std_logic;
		fpga_rxrefclk_ch3  : IN std_logic;
		txdata_ch3         : IN std_logic_vector(7 downto 0);
		tx_k_ch3           : IN std_logic;
		tx_force_disp_ch3  : IN std_logic;
		tx_disp_sel_ch3    : IN std_logic;
		tx_pwrup_ch3_c     : IN std_logic;
		tx_div2_mode_ch3_c : IN std_logic;
		sci_wrdata         : IN std_logic_vector(7 downto 0);
		sci_addr           : IN std_logic_vector(5 downto 0);
		sci_sel_quad       : IN std_logic;
		sci_rd             : IN std_logic;
		sci_wrn            : IN std_logic;
		fpga_txrefclk      : IN std_logic;
		tx_serdes_rst_c    : IN std_logic;
		tx_sync_qd_c       : IN std_logic;
		rst_n              : IN std_logic;
		serdes_rst_qd_c    : IN std_logic;          
		hdoutp_ch1         : OUT std_logic;
		hdoutn_ch1         : OUT std_logic;
		rx_full_clk_ch1    : OUT std_logic;
		rx_half_clk_ch1    : OUT std_logic;
		tx_full_clk_ch1    : OUT std_logic;
		tx_half_clk_ch1    : OUT std_logic;
		rxdata_ch1         : OUT std_logic_vector(15 downto 0);
		rx_k_ch1           : OUT std_logic_vector(1 downto 0);
		rx_disp_err_ch1    : OUT std_logic_vector(1 downto 0);
		rx_cv_err_ch1      : OUT std_logic_vector(1 downto 0);
		rx_los_low_ch1_s   : OUT std_logic;
		lsm_status_ch1_s   : OUT std_logic;
		rx_cdr_lol_ch1_s   : OUT std_logic;
		hdoutp_ch3         : OUT std_logic;
		hdoutn_ch3         : OUT std_logic;
		tx_full_clk_ch3    : OUT std_logic;
		tx_half_clk_ch3    : OUT std_logic;
		sci_rddata         : OUT std_logic_vector(7 downto 0);
		tx_pll_lol_qd_s    : OUT std_logic;
		refclk2fpga        : OUT std_logic
			);
	end component;
  
-- Peter Schakel 02-12-14
component sfp_1_2sync_3_200_int is
 port (
------------------
-- CH0 --
-- CH1 --
    hdinp_ch1, hdinn_ch1    :   in std_logic;
    hdoutp_ch1, hdoutn_ch1   :   out std_logic;
    sci_sel_ch1    :   in std_logic;
    rxiclk_ch1    :   in std_logic;
    txiclk_ch1    :   in std_logic;
    rx_full_clk_ch1   :   out std_logic;
    rx_half_clk_ch1   :   out std_logic;
    tx_full_clk_ch1   :   out std_logic;
    tx_half_clk_ch1   :   out std_logic;
    fpga_rxrefclk_ch1    :   in std_logic;
    txdata_ch1    :   in std_logic_vector (15 downto 0);
    tx_k_ch1    :   in std_logic_vector (1 downto 0);
    tx_force_disp_ch1    :   in std_logic_vector (1 downto 0);
    tx_disp_sel_ch1    :   in std_logic_vector (1 downto 0);
    rxdata_ch1   :   out std_logic_vector (15 downto 0);
    rx_k_ch1   :   out std_logic_vector (1 downto 0);
    rx_disp_err_ch1   :   out std_logic_vector (1 downto 0);
    rx_cv_err_ch1   :   out std_logic_vector (1 downto 0);
    rx_serdes_rst_ch1_c    :   in std_logic;
    sb_felb_ch1_c    :   in std_logic;
    sb_felb_rst_ch1_c    :   in std_logic;
    tx_pcs_rst_ch1_c    :   in std_logic;
    tx_pwrup_ch1_c    :   in std_logic;
    rx_pcs_rst_ch1_c    :   in std_logic;
    rx_pwrup_ch1_c    :   in std_logic;
    rx_los_low_ch1_s   :   out std_logic;
    lsm_status_ch1_s   :   out std_logic;
    rx_cdr_lol_ch1_s   :   out std_logic;
    tx_div2_mode_ch1_c   : in std_logic;
    rx_div2_mode_ch1_c   : in std_logic;
-- CH2 --
    hdinp_ch2, hdinn_ch2    :   in std_logic;
    hdoutp_ch2, hdoutn_ch2   :   out std_logic;
    sci_sel_ch2    :   in std_logic;
    rxiclk_ch2    :   in std_logic;
    txiclk_ch2    :   in std_logic;
    rx_full_clk_ch2   :   out std_logic;
    rx_half_clk_ch2   :   out std_logic;
    tx_full_clk_ch2   :   out std_logic;
    tx_half_clk_ch2   :   out std_logic;
    fpga_rxrefclk_ch2    :   in std_logic;
    txdata_ch2    :   in std_logic_vector (7 downto 0);
    tx_k_ch2    :   in std_logic;
    tx_force_disp_ch2    :   in std_logic;
    tx_disp_sel_ch2    :   in std_logic;
    rxdata_ch2   :   out std_logic_vector (7 downto 0);
    rx_k_ch2   :   out std_logic;
    rx_disp_err_ch2   :   out std_logic;
    rx_cv_err_ch2   :   out std_logic;
    rx_serdes_rst_ch2_c    :   in std_logic;
    sb_felb_ch2_c    :   in std_logic;
    sb_felb_rst_ch2_c    :   in std_logic;
    tx_pcs_rst_ch2_c    :   in std_logic;
    tx_pwrup_ch2_c    :   in std_logic;
    rx_pcs_rst_ch2_c    :   in std_logic;
    rx_pwrup_ch2_c    :   in std_logic;
    rx_los_low_ch2_s   :   out std_logic;
    lsm_status_ch2_s   :   out std_logic;
    rx_cdr_lol_ch2_s   :   out std_logic;
    tx_div2_mode_ch2_c   : in std_logic;
    rx_div2_mode_ch2_c   : in std_logic;
-- CH3 --
    hdoutp_ch3, hdoutn_ch3   :   out std_logic;
    sci_sel_ch3    :   in std_logic;
    txiclk_ch3    :   in std_logic;
    tx_full_clk_ch3   :   out std_logic;
    tx_half_clk_ch3   :   out std_logic;
    txdata_ch3    :   in std_logic_vector (7 downto 0);
    tx_k_ch3    :   in std_logic;
    tx_force_disp_ch3    :   in std_logic;
    tx_disp_sel_ch3    :   in std_logic;
    tx_pcs_rst_ch3_c    :   in std_logic;
    tx_pwrup_ch3_c    :   in std_logic;
    tx_div2_mode_ch3_c   : in std_logic;
---- Miscillaneous ports
    sci_wrdata    :   in std_logic_vector (7 downto 0);
    sci_addr    :   in std_logic_vector (5 downto 0);
    sci_rddata   :   out std_logic_vector (7 downto 0);
    sci_sel_quad    :   in std_logic;
    sci_rd    :   in std_logic;
    sci_wrn    :   in std_logic;
    fpga_txrefclk  :   in std_logic;
    tx_serdes_rst_c    :   in std_logic;
    tx_pll_lol_qd_s   :   out std_logic;
    tx_sync_qd_c    :   in std_logic;
    rst_qd_c    :   in std_logic;
    serdes_rst_qd_c    :   in std_logic);

end component;

component serdes_rx_reset_sm is
port (
	rst_n			: in std_logic;
	refclkdiv2        : in std_logic;
	tx_pll_lol_qd_s	: in std_logic;
	rx_serdes_rst_ch_c: out std_logic;
	rx_cdr_lol_ch_s	: in std_logic;
	rx_los_low_ch_s	: in std_logic;
	rx_pcs_rst_ch_c	: out std_logic;
    STATE_OUT         : out std_logic_vector(3 downto 0));
end component ;
component serdes_tx_reset_sm is
port (
	rst_n 			: in std_logic;
	refclkdiv2      : in std_logic;
	tx_pll_lol_qd_s : in std_logic;
	rst_qd_c		: out std_logic;
	tx_pcs_rst_ch_c : out std_logic_vector(3 downto 0);
	STATE_OUT       : out std_logic_vector(3 downto 0)
	);
end component;
  
  signal refck2core             : std_logic;
--  signal clock                  : std_logic;
  --reset signals
  signal ffc_quad_rst           : std_logic;
  signal ffc_lane_tx_rst        : std_logic;
  signal ffc_lane_rx_rst        : std_logic;
  --serdes connections
  signal tx_data                : std_logic_vector(15 downto 0);
  signal tx_k                   : std_logic_vector(1 downto 0);
  signal rx_data                : std_logic_vector(15 downto 0); -- delayed signals
  signal rx_k                   : std_logic_vector(1 downto 0);  -- delayed signals
  signal comb_rx_data           : std_logic_vector(15 downto 0); -- original signals from SFP
  signal comb_rx_k              : std_logic_vector(1 downto 0);  -- original signals from SFP
  signal link_ok                : std_logic_vector(1 downto 0); -- OJK 02-dec-2013: Changed width from 1 bit to 2 bits
  signal link_error             : std_logic_vector(10 downto 0);-- OJK 02-dec-2013: Changed width from 10 bits to 11 bits
  signal ff_txhalfclk           : std_logic;
  signal ff_rxhalfclk			      : std_logic;
  signal ff_rxfullclk           : std_logic;
  --rx fifo signals
  signal fifo_rx_rd_en          : std_logic;
  signal fifo_rx_wr_en          : std_logic;
  signal fifo_rx_reset          : std_logic;
  signal fifo_rx_din            : std_logic_vector(17 downto 0);
  signal fifo_rx_dout           : std_logic_vector(17 downto 0);
  signal fifo_rx_full           : std_logic;
  signal fifo_rx_empty          : std_logic;
  --tx fifo signals
  signal fifo_tx_rd_en          : std_logic;
  signal fifo_tx_wr_en          : std_logic;
  signal fifo_tx_reset          : std_logic;
  signal fifo_tx_din            : std_logic_vector(17 downto 0);
  signal fifo_tx_dout           : std_logic_vector(17 downto 0);
  signal fifo_tx_full           : std_logic;
  signal fifo_tx_empty          : std_logic;
  signal fifo_tx_almost_full    : std_logic;
  --rx path
  signal rx_counter             : std_logic_vector(c_NUM_WIDTH-1 downto 0);
  signal buf_med_dataready_out  : std_logic;
  signal buf_med_data_out       : std_logic_vector(c_DATA_WIDTH-1 downto 0);
  signal buf_med_packet_num_out : std_logic_vector(c_NUM_WIDTH-1 downto 0);
  signal last_rx                : std_logic_vector(8 downto 0);
  signal last_fifo_rx_empty     : std_logic;
  --tx path
  signal last_fifo_tx_empty     : std_logic;
  --link status
  signal rx_k_q                 : std_logic_vector(1 downto 0);

  signal quad_rst               : std_logic;
  signal lane_rst               : std_logic;
  signal tx_allow               : std_logic;
  signal tx_allow0              : std_logic;
  signal rx_allow               : std_logic;
  signal tx_allow_qtx           : std_logic;

  signal rx_allow_q             : std_logic; -- clock domain changed signal
  signal tx_allow_q             : std_logic;
  signal swap_bytes             : std_logic;
  signal buf_stat_debug         : std_logic_vector(31 downto 0);

  -- status inputs from SFP
  signal sfp_prsnt_n            : std_logic; -- synchronized input signals
  signal sfp_los                : std_logic; -- synchronized input signals

  signal buf_STAT_OP            : std_logic_vector(15 downto 0);

  signal led_counter            : unsigned(16 downto 0);
  signal rx_led                 : std_logic;
  signal tx_led                 : std_logic;


  signal tx_correct             : std_logic_vector(1 downto 0); -- GbE mode SERDES: automatic IDLE2 -> IDLE1 conversion
  signal first_idle             : std_logic; -- tag the first IDLE2 after data

  signal reset_word_cnt    : unsigned(4 downto 0);
  signal make_trbnet_reset : std_logic;
  signal make_trbnet_reset_q : std_logic;
  signal send_reset_words  : std_logic;
  signal send_reset_words_q : std_logic;
  signal send_reset_in      : std_logic;
  signal send_reset_in_qtx  : std_logic;
  signal reset_i                : std_logic;
  signal reset_i_rx             : std_logic;
  signal pwr_up                 : std_logic;
  signal clear_n   : std_logic;

  signal clk_sys : std_logic;
  signal clk_tx  : std_logic;
  signal clk_rx  : std_logic;
  signal clk_rxref : std_logic;
  signal clk_txref : std_logic;

type sci_ctrl is (IDLE, SCTRL, SCTRL_WAIT, SCTRL_WAIT2, SCTRL_FINISH, GET_WA, GET_WA_WAIT, GET_WA_WAIT2, GET_WA_FINISH);
signal sci_state         : sci_ctrl;
  signal sci_ch_i        : std_logic_vector(3 downto 0);
  signal sci_qd_i        : std_logic;
  signal sci_reg_i       : std_logic;
  signal sci_addr_i      : std_logic_vector(8 downto 0);
  signal sci_data_in_i   : std_logic_vector(7 downto 0);
  signal sci_data_out_i  : std_logic_vector(7 downto 0);
  signal sci_read_i      : std_logic;
  signal sci_write_i     : std_logic;
--  signal sci_write_shift_i : std_logic_vector(2 downto 0);
--  signal sci_read_shift_i  : std_logic_vector(2 downto 0);  
  
  --OJK 13-dec-2013
  signal cnt             : integer range 0 to 10000;
  signal tx_pll_lol_qd_i : std_logic;
  -- Peter Schakel 3-dec-2014
 	
  signal sci_timer            : unsigned(12 downto 0) := (others => '0');
  signal trb_reset_n          : std_logic;
  signal sync_reset_n         : std_logic;
  signal CH3_reset_n          : std_logic;
  signal trb_rx_serdes_rst    : std_logic;
  signal trb_rx_cdr_lol       : std_logic;
  signal trb_rx_los_low       : std_logic;
  signal trb_rx_pcs_rst       : std_logic;
  signal trb_tx_pcs_rst       : std_logic;
  signal trb_tx_pcs_rst_all   : std_logic_vector(3 downto 0);
  signal rst_qd               : std_logic;
  signal link_RXOK_S          : std_logic;
  signal link_TXOK_S          : std_logic;
  signal trb_rx_fsm_state     : std_logic_vector(3 downto 0);
  signal trb_tx_fsm_state     : std_logic_vector(3 downto 0);
  
  signal sync_clk_rx_full     : std_logic;
  signal sync_clk_rx_half     : std_logic;
  signal sync_clk_tx_full     : std_logic;
  signal sync_clk_tx_half     : std_logic;
  signal sync_tx_k            : std_logic;
  signal sync_tx_data         : std_logic_vector(7 downto 0);

  signal syncfifo_din         : std_logic_vector(17 downto 0);
  signal syncfifo_dout        : std_logic_vector(17 downto 0);
	  
  signal sync_rx_k            : std_logic;
  signal sync_rx_data         : std_logic_vector(7 downto 0);
  signal sync_rx_serdes_rst   : std_logic;
  signal sync_rx_cdr_lol      : std_logic;
  signal sync_tx_pcs_rst      : std_logic;
  signal sync_rx_pcs_rst      : std_logic;
  signal sync_rx_los_low      : std_logic;
  signal sync_lsm_status      : std_logic;
  signal SD_tx_pcs_rst        : std_logic;
  signal DLM_fifo_rd_en       : std_logic;
  signal DLM_fifo_empty       : std_logic;
  signal DLM_fifo_reading     : std_logic := '0';  
  signal SODA_dlm_word_S      : std_logic_vector(7 downto 0);
  signal DLM_received_S       : std_logic;
  signal sync_wa_position_rx  : std_logic_vector(15 downto 0) := x"FFFF";
  signal wa_position          : std_logic_vector(15 downto 0) := x"FFFF";
  signal sync_rx_fsm_state    : std_logic_vector(3 downto 0);
  signal sync_tx_fsm_state    : std_logic_vector(3 downto 0);
  signal CH3_tx_fsm_state     : std_logic_vector(3 downto 0);

  signal CLKdiv100_S          : std_logic;
  signal sync_clk_rx_fulldiv100_S     : std_logic;

  attribute syn_keep : boolean;
  attribute syn_preserve : boolean;
  attribute syn_keep of led_counter : signal is true;
  attribute syn_keep of send_reset_in : signal is true;
  attribute syn_keep of reset_i : signal is true;
  attribute syn_preserve of reset_i : signal is true;
  attribute syn_keep of clk_rx : signal is true;
  attribute syn_preserve of clk_rx : signal is true;
  attribute syn_keep of sync_clk_rx_full : signal is true;
  attribute syn_preserve of sync_clk_rx_full : signal is true;
  attribute syn_keep of SCI_READ : signal is true;
  attribute syn_preserve of SCI_READ : signal is true;

begin

--------------------------------------------------------------------------
-- Select proper clock configuration
--------------------------------------------------------------------------
  clk_sys <= SYSCLK;
  clk_tx  <= SYSCLK;
  clk_rx  <= ff_rxhalfclk;
  clk_rxref <= CLK;
  clk_txref <= CLK;




--------------------------------------------------------------------------
-- Internal Lane Resets
--------------------------------------------------------------------------
  clear_n <= not clear;


  PROC_RESET : process(clk_sys)
    begin
      if rising_edge(clk_sys) then
        reset_i <= RESET;
        send_reset_in <= ctrl_op(15);
        pwr_up  <= '1'; --not CTRL_OP(i*16+14);
      end if;
    end process;

--------------------------------------------------------------------------
-- Synchronizer stages
--------------------------------------------------------------------------

-- Input synchronizer for SFP_PRESENT and SFP_LOS signals (external signals from SFP)
THE_SFP_STATUS_SYNC: signal_sync
  generic map(
    DEPTH => 3,
    WIDTH => 2
    )
  port map(
    RESET    => '0',
    D_IN(0)  => sd_prsnt_n_in,
    D_IN(1)  => sd_los_in,
    CLK0     => clk_sys,
    CLK1     => clk_sys,
    D_OUT(0) => sfp_prsnt_n,
    D_OUT(1) => sfp_los
    );


THE_RX_K_SYNC: signal_sync
  generic map(
    DEPTH => 1,
    WIDTH => 4
    )
  port map(
    RESET             => reset_i,
    D_IN(1 downto 0)  => comb_rx_k,
    D_IN(2)           => send_reset_words,
    D_IN(3)           => make_trbnet_reset,
    CLK0              => clk_rx, -- CHANGED
    CLK1              => clk_sys,
    D_OUT(1 downto 0) => rx_k_q,
    D_OUT(2)          => send_reset_words_q,
    D_OUT(3)          => make_trbnet_reset_q
    );

THE_RX_DATA_DELAY: signal_sync
  generic map(
    DEPTH => 2,
    WIDTH => 16
    )
  port map(
    RESET    => reset_i,
    D_IN     => comb_rx_data,
    CLK0     => clk_rx,
    CLK1     => clk_rx,
    D_OUT    => rx_data
    );

THE_RX_K_DELAY: signal_sync
  generic map(
    DEPTH => 2,
    WIDTH => 2
    )
  port map(
    RESET    => reset_i,
    D_IN     => comb_rx_k,
    CLK0     => clk_rx,
    CLK1     => clk_rx,
    D_OUT    => rx_k
    );

THE_RX_RESET: signal_sync
  generic map(
    DEPTH => 1,
    WIDTH => 1
    )
  port map(
    RESET    => '0',
    D_IN(0)  => reset_i,
    CLK0     => clk_rx,
    CLK1     => clk_rx,
    D_OUT(0) => reset_i_rx
    );

-- Delay for ALLOW signals
THE_RX_ALLOW_SYNC: signal_sync
  generic map(
    DEPTH => 2,
    WIDTH => 2
    )
  port map(
    RESET    => reset_i,
    D_IN(0)  => rx_allow,
    D_IN(1)  => tx_allow,
    CLK0     => clk_sys,
    CLK1     => clk_sys,
    D_OUT(0) => rx_allow_q,
    D_OUT(1) => tx_allow_q
    );

THE_TX_SYNC: signal_sync
  generic map(
    DEPTH => 1,
    WIDTH => 2
    )
  port map(
    RESET    => '0',
    D_IN(0)  => send_reset_in,
    D_IN(1)  => tx_allow,
    CLK0     => clk_tx,
    CLK1     => clk_tx,
    D_OUT(0) => send_reset_in_qtx,
    D_OUT(1) => tx_allow_qtx
    );


--------------------------------------------------------------------------
-- Main control state machine, startup control for SFP
--------------------------------------------------------------------------

THE_SFP_LSM: trb_net16_lsm_sfp
    generic map (
      CHECK_FOR_CV => c_YES,
      HIGHSPEED_STARTUP => c_YES
      )
    port map(
      SYSCLK            => clk_sys,
      RESET             => reset_i,
      CLEAR             => clear,
      SFP_MISSING_IN    => sfp_prsnt_n,
      SFP_LOS_IN        => sfp_los,
      SD_LINK_OK_IN     => link_ok(0), -- apparently not used
      SD_LOS_IN         => link_error(8), -- apparently not used
      SD_TXCLK_BAD_IN   => link_error(5),
      SD_RXCLK_BAD_IN   => link_error(4),
      SD_RETRY_IN       => '0', -- '0' = handle byte swapping in logic, '1' = simply restart link and hope
      SD_ALIGNMENT_IN	=> rx_k_q,
      SD_CV_IN          => link_error(7 downto 6),
      FULL_RESET_OUT    => quad_rst,
      LANE_RESET_OUT    => lane_rst, -- apparently not used
      TX_ALLOW_OUT      => tx_allow,
      RX_ALLOW_OUT      => rx_allow,
      SWAP_BYTES_OUT    => swap_bytes,
      STAT_OP           => buf_stat_op,
      CTRL_OP           => ctrl_op,
      STAT_DEBUG        => buf_stat_debug
      );
sd_txdis_out <= quad_rst or reset_i;

--------------------------------------------------------------------------
--------------------------------------------------------------------------

--//?? ffc_quad_rst         <= quad_rst;
ffc_lane_tx_rst      <= lane_rst;
ffc_lane_rx_rst      <= lane_rst;

-- SerDes clock output to FPGA fabric
REFCLK2CORE_OUT <= ff_rxhalfclk;
CLK_RX_HALF_OUT <= ff_rxhalfclk;
CLK_RX_FULL_OUT <= ff_rxfullclk;

THE_SERDES: sfp_1_2sync_3_200_int port map(
------------------
-- CH0 --
		-- not used
-- CH1 --
		hdinp_ch1          => sd_rxd_p_in,                
		hdinn_ch1          => sd_rxd_n_in,                
		hdoutp_ch1         => sd_txd_p_out,              
		hdoutn_ch1         => sd_txd_n_out,              

		sci_sel_ch1        => sci_ch_i(1),
		rxiclk_ch1         => clk_rx,                
		txiclk_ch1         => clk_tx,                
		rx_full_clk_ch1    => ff_rxfullclk,          
		rx_half_clk_ch1    => ff_rxhalfclk,          
		tx_full_clk_ch1    => open,                  
		tx_half_clk_ch1    => ff_txhalfclk,          
		fpga_rxrefclk_ch1  => clk_rxref,             
		txdata_ch1         => tx_data,               
		tx_k_ch1           => tx_k,                  
		tx_force_disp_ch1  => tx_correct,            
		tx_disp_sel_ch1    => "00",                  
		rxdata_ch1         => comb_rx_data,          
		rx_k_ch1           => comb_rx_k,             
		rx_disp_err_ch1    => open,            
		rx_cv_err_ch1      => link_error(7 downto 6),
		rx_serdes_rst_ch1_c => trb_rx_serdes_rst,
		sb_felb_ch1_c      => '0',                   
		sb_felb_rst_ch1_c  => '0',                
		tx_pcs_rst_ch1_c   => trb_tx_pcs_rst,
		tx_pwrup_ch1_c     => '1',                   
		rx_pcs_rst_ch1_c   => trb_rx_pcs_rst,
		rx_pwrup_ch1_c     => '1',                   
		rx_los_low_ch1_s   => trb_rx_los_low, -- link_error(8),         
		lsm_status_ch1_s   => link_ok(0),  --//link_ok0, --//           
		rx_cdr_lol_ch1_s   => trb_rx_cdr_lol, -- link_error(4),         
		tx_div2_mode_ch1_c => '0',                   
		rx_div2_mode_ch1_c => '0',

-- CH2 --
		hdinp_ch2            => SODA_RXD_P_IN,
		hdinn_ch2            => SODA_RXD_N_IN,
		hdoutp_ch2           => SODA_TXD_P_OUT,
		hdoutn_ch2           => SODA_TXD_N_OUT,
		sci_sel_ch2          => sci_ch_i(2),
		rxiclk_ch2           => sync_clk_rx_full, -- ?? CLK,
		txiclk_ch2           => sync_clk_tx_full, -- ??CLK, --????? clk_txref
		rx_full_clk_ch2      => sync_clk_rx_full,
		rx_half_clk_ch2      => sync_clk_rx_half,
		tx_full_clk_ch2      => sync_clk_tx_full,
		tx_half_clk_ch2      => sync_clk_tx_half,
		fpga_rxrefclk_ch2    => CLK,
		txdata_ch2           => sync_tx_data,
		tx_k_ch2             => sync_tx_k,
		tx_force_disp_ch2    => '0',
		tx_disp_sel_ch2      => '0',
		rxdata_ch2           => sync_rx_data,
		rx_k_ch2             => sync_rx_k,
		rx_disp_err_ch2      => open,
		rx_cv_err_ch2        => open,
		rx_serdes_rst_ch2_c  => sync_rx_serdes_rst,
		sb_felb_ch2_c        => '0',
		sb_felb_rst_ch2_c    => '0',
		tx_pcs_rst_ch2_c     => sync_tx_pcs_rst,
		tx_pwrup_ch2_c       => '1',
		rx_pcs_rst_ch2_c     => sync_rx_pcs_rst,
		rx_pwrup_ch2_c       => '1',
		rx_los_low_ch2_s     => sync_rx_los_low,
		lsm_status_ch2_s     => sync_lsm_status,
		rx_cdr_lol_ch2_s     => sync_rx_cdr_lol,
		tx_div2_mode_ch2_c   => '0',
		rx_div2_mode_ch2_c   => '0',
		
-- CH3 --
		hdoutp_ch3         => DOUT_TXD_P_OUT,             
		hdoutn_ch3         => DOUT_TXD_N_OUT,             
		sci_sel_ch3        => '0', --disable access to channel 3 registers
		txiclk_ch3         => clk_tx,             
		tx_full_clk_ch3    => open,                
		tx_half_clk_ch3    => open,        
		txdata_ch3         => tx_data_ch3,             
		tx_k_ch3           => tx_k_ch3,
		tx_force_disp_ch3  => '0',      
		tx_disp_sel_ch3    => '0',        
		tx_pcs_rst_ch3_c   => SD_tx_pcs_rst,
		tx_pwrup_ch3_c     => '1',         
		tx_div2_mode_ch3_c => '1', 

		---- Miscillaneous ports
		sci_wrdata         => sci_data_in_i,
		sci_addr           => sci_addr_i(5 downto 0),
		sci_rddata         => sci_data_out_i,
		sci_sel_quad       => sci_qd_i,
		sci_rd             => sci_read_i,
		sci_wrn            => sci_write_i,
		fpga_txrefclk      => clk_txref,               
		tx_serdes_rst_c    => CLEAR,          
		tx_pll_lol_qd_s    => tx_pll_lol_qd_i,          
		tx_sync_qd_c       => '0',             -- Multiple channel transmit synchronization is not needed
		rst_qd_c => rst_qd,
		serdes_rst_qd_c    => ffc_quad_rst        
	);
--//link_ok(0) <= '1' when (link_RXOK_S='1') and (link_ok0='1') else '0'; --//
--------------------------------------------------------------------------
-- FIFO and additional logic to synchronize SODA (DLM signals) to the transceiver clock
--------------------------------------------------------------------------
syncfifo_din(7 downto 0)  <= SODA_DLM_WORD_IN;
syncfifo_din(17 downto 8) <= (others => '0');
SODA_dlm_word_S <= syncfifo_dout(7 downto 0);

sync_DLM_tx: trb_net_fifo_16bit_bram_dualport
	generic map(
		USE_STATUS_FLAGS => c_NO
       )
	port map( 
		read_clock_in  => sync_clk_tx_full,
		write_clock_in     => sync_clk_rx_full, 
		read_enable_in     => DLM_fifo_rd_en,
		write_enable_in    => SODA_DLM_IN,
		fifo_gsr_in        => reset,
		write_data_in      => syncfifo_din,
		read_data_out      => syncfifo_dout,
		full_out           => open,
		empty_out          => DLM_fifo_empty
	);

-- write DLM data in fifo
process(sync_clk_rx_full)
begin
  if rising_edge(sync_clk_rx_full) then
	SODA_DLM_OUT <= '0';
	if DLM_received_S='1' then
		DLM_received_S <= '0';
		SODA_DLM_OUT <= '1';
		SODA_DLM_WORD_OUT <= sync_rx_data;
	elsif (sync_rx_data=x"DC") and (sync_rx_k='1') then
		DLM_received_S <= '1';
	end if;
  end if;
end process;  

-- read DLM data from fifo and pass on as k-character 28.6 (0xDC) followed by DLM databyte
-- no other data, only idles (k-character 2.85)
-- First DLM in burst is delayed to prevent missing DLMs due to asynchronous clock
process(sync_clk_tx_full)
begin
  if rising_edge(sync_clk_tx_full) then
	if DLM_fifo_rd_en='1' then
		DLM_fifo_rd_en <= '0';
		sync_tx_data <= SODA_dlm_word_S;
		sync_tx_k <= '0';
	elsif (DLM_fifo_empty='0') and (DLM_fifo_reading='1') then
		DLM_fifo_rd_en <= '1';
		sync_tx_data <= x"DC";
		sync_tx_k <= '1';
	elsif DLM_fifo_empty='0' then
		DLM_fifo_reading <= '1';
		DLM_fifo_rd_en <= '0';
		sync_tx_data <= x"BC"; -- idle
		sync_tx_k <= '1';		
	else
		DLM_fifo_reading <= '0';
		DLM_fifo_rd_en <= '0';
		sync_tx_data <= x"BC"; -- idle
		sync_tx_k <= '1';
	end if;
  end if;
end process;  
SODA_CLOCK_OUT <= sync_clk_rx_full;


-------------------------------------------------      
-- Error and status signal from serdes
------------------------------------------------- 
link_error(8) <= trb_rx_los_low; -- loss of signal
link_error(4) <= '1' when (trb_rx_cdr_lol='1') or (link_RXOK_S='0') else '0'; -- loss of lock 
link_error(5) <= '1' when (tx_pll_lol_qd_i='1') or (link_TXOK_S='0') else '0';

trb_reset_n <= '0' when (RESET='1') or (CLEAR='1') else '1';
ffc_quad_rst <= quad_rst;
-------------------------------------------------      
-- Reset FSM & Link states
------------------------------------------------- 
THE_RX_FSM1:  serdes_rx_reset_sm   -- original from Lattice
  port map(
    RST_N               => trb_reset_n,
	refclkdiv2          => SYSCLK,
    TX_PLL_LOL_QD_S     => tx_pll_lol_qd_i,
    RX_SERDES_RST_CH_C  => trb_rx_serdes_rst,
    RX_CDR_LOL_CH_S     => trb_rx_cdr_lol,
    RX_LOS_LOW_CH_S     => trb_rx_los_low,
    RX_PCS_RST_CH_C     => trb_rx_pcs_rst,
    STATE_OUT           => trb_rx_fsm_state
	);


-- THE_RX_FSM1: rx_reset_fsm -- reset FSM for receiver channel 1 (TRBnet)
  -- port map(
    -- RST_N               => trb_reset_n,
    -- RX_REFCLK           => CLK,
    -- TX_PLL_LOL_QD_S     => tx_pll_lol_qd_i,
    -- RX_SERDES_RST_CH_C  => trb_rx_serdes_rst,
    -- RX_CDR_LOL_CH_S     => trb_rx_cdr_lol,
    -- RX_LOS_LOW_CH_S     => trb_rx_los_low,
    -- RX_PCS_RST_CH_C     => trb_rx_pcs_rst,
    -- WA_POSITION         => "0000",
    -- STATE_OUT           => trb_rx_fsm_state
    -- );
link_RXOK_S <= '1' when (trb_rx_fsm_state = x"6") else '0';

THE_TX_FSM1: serdes_tx_reset_sm   -- original from Lattice
  port map(
    RST_N           => trb_reset_n,
	refclkdiv2      => SYSCLK,
    TX_PLL_LOL_QD_S => tx_pll_lol_qd_i,
    RST_QD_C        => rst_qd,
    TX_PCS_RST_CH_C => trb_tx_pcs_rst_all,
    STATE_OUT       => trb_tx_fsm_state);
trb_tx_pcs_rst <= trb_tx_pcs_rst_all(1);

-- THE_TX_FSM1: tx_reset_fsm -- reset FSM for transmit channel 1 (TRBnet)
  -- port map(
    -- RST_N           => trb_reset_n,
    -- TX_REFCLK       => CLK,
    -- TX_PLL_LOL_QD_S => tx_pll_lol_qd_i,
    -- RST_QD_C        => rst_qd,
    -- TX_PCS_RST_CH_C => trb_tx_pcs_rst,
    -- STATE_OUT       => trb_tx_fsm_state
    -- );
link_TXOK_S <= '1' when (trb_tx_fsm_state = x"5") else '0';

sync_reset_n <= '0' when (RESET='1') or (CLEAR='1') else '1';
THE_RX_FSM2: rx_reset_fsm -- reset FSM for receiver channel 2 (SODA), synchronize to fiber bit with wa_position
  port map(
    RST_N               => sync_reset_n,
    RX_REFCLK           => sync_clk_rx_full, --??CLK,
    TX_PLL_LOL_QD_S     => tx_pll_lol_qd_i,
    RX_SERDES_RST_CH_C  => sync_rx_serdes_rst,
    RX_CDR_LOL_CH_S     => sync_rx_cdr_lol,
    RX_LOS_LOW_CH_S     => sync_rx_los_low,
    RX_PCS_RST_CH_C     => sync_rx_pcs_rst,
    WA_POSITION         => sync_wa_position_rx(11 downto 8),
    STATE_OUT           => sync_rx_fsm_state
    );
SYNC_WA_POSITION : process(sync_clk_rx_full) --??CLK)
begin
  if rising_edge(sync_clk_rx_full) then
    sync_wa_position_rx <= wa_position;
  end if;
end process;
    
THE_TX_FSM2: tx_reset_fsm -- reset FSM for transmit channel 2 (SODA)
  port map(
    RST_N           => sync_reset_n,
    TX_REFCLK       => CLK,
    TX_PLL_LOL_QD_S => tx_pll_lol_qd_i,
    RST_QD_C        => open, --??
    TX_PCS_RST_CH_C => sync_tx_pcs_rst,
    STATE_OUT       => sync_tx_fsm_state
    );
	
CH3_reset_n <= '0' when (RESET='1') or (CLEAR='1') else '1';
THE_TX_FSM3 : tx_reset_fsm -- reset FSM for transmit channel 3 (data to UDP core)
  port map(
    RST_N           => CH3_reset_n,
    TX_REFCLK       => CLK,
    TX_PLL_LOL_QD_S => tx_pll_lol_qd_i,
    RST_QD_C        => open, --??
    TX_PCS_RST_CH_C => SD_tx_pcs_rst,
    STATE_OUT       => CH3_tx_fsm_state
    );
TX_READY_CH3 <= '1' when (CH3_tx_fsm_state=x"5") and (tx_pll_lol_qd_i='0') else '0';
	
	
-------------------------------------------------------------------------
-- RX Fifo & Data output
-------------------------------------------------------------------------
THE_FIFO_SFP_TO_FPGA: trb_net_fifo_16bit_bram_dualport
generic map(
  USE_STATUS_FLAGS => c_NO
       )
port map( read_clock_in  => clk_sys,
      write_clock_in     => clk_rx, -- CHANGED
      read_enable_in     => fifo_rx_rd_en,
      write_enable_in    => fifo_rx_wr_en,
      fifo_gsr_in        => fifo_rx_reset,
      write_data_in      => fifo_rx_din,
      read_data_out      => fifo_rx_dout,
      full_out           => fifo_rx_full,
      empty_out          => fifo_rx_empty
    );

fifo_rx_reset <= reset_i or not rx_allow_q;
fifo_rx_rd_en <= not fifo_rx_empty;

-- Received bytes need to be swapped if the SerDes is "off by one" in its internal 8bit path
THE_BYTE_SWAP_PROC: process(clk_rx)
  begin
    if rising_edge(clk_rx) then
		last_rx <= rx_k(1) & rx_data(15 downto 8);
		if( swap_bytes = '0' ) then
		  fifo_rx_din   <= rx_k(1) & rx_k(0) & rx_data(15 downto 8) & rx_data(7 downto 0);
		  fifo_rx_wr_en <= not rx_k(0) and rx_allow and link_ok(0);
		else
		  fifo_rx_din   <= rx_k(0) & last_rx(8) & rx_data(7 downto 0) & last_rx(7 downto 0);
		  fifo_rx_wr_en <= not last_rx(8) and rx_allow and link_ok(0);
		end if;
	end if;
  end process THE_BYTE_SWAP_PROC;

buf_med_data_out          <= fifo_rx_dout(15 downto 0);
buf_med_dataready_out     <= not fifo_rx_dout(17) and not fifo_rx_dout(16) and not last_fifo_rx_empty and rx_allow_q;
buf_med_packet_num_out    <= rx_counter;
med_read_out              <= tx_allow_q and not fifo_tx_almost_full;


THE_CNT_RESET_PROC : process(clk_rx)
  begin
    if rising_edge(clk_rx) then
		if reset_i_rx = '1' then
		  send_reset_words  <= '0';
		  make_trbnet_reset <= '0';
		  reset_word_cnt    <= (others => '0');
		else
		  send_reset_words   <= '0';
		  make_trbnet_reset  <= '0';
		  if fifo_rx_din = "11" & x"FEFE" then
			if reset_word_cnt(4) = '0' then
			  reset_word_cnt <= reset_word_cnt + to_unsigned(1,1);
			else
			  send_reset_words <= '1';
			end if;
		  else
			reset_word_cnt    <= (others => '0');
			make_trbnet_reset <= reset_word_cnt(4);
		  end if;
		end if;
	end if;
  end process;


THE_SYNC_PROC: process(clk_sys)
  begin
    if rising_edge(clk_sys) then
		med_dataready_out     <= buf_med_dataready_out;
		med_data_out          <= buf_med_data_out;
		med_packet_num_out    <= buf_med_packet_num_out;
		if reset_i = '1' then
		  med_dataready_out <= '0';
		end if;
	end if;
  end process;


--rx packet counter
---------------------
THE_RX_PACKETS_PROC: process( clk_sys )
  begin
    if( rising_edge(clk_sys) ) then
      last_fifo_rx_empty <= fifo_rx_empty;
      if reset_i = '1' or rx_allow_q = '0' then
        rx_counter <= c_H0;
      else
        if( buf_med_dataready_out = '1' ) then
          if( rx_counter = c_max_word_number ) then
            rx_counter <= (others => '0');
          else
            rx_counter <= std_logic_vector(unsigned(rx_counter) + to_unsigned(1,1));
          end if;
        end if;
      end if;
    end if;
  end process;

--TX Fifo & Data output to Serdes
---------------------
THE_FIFO_FPGA_TO_SFP: trb_net_fifo_16bit_bram_dualport
  generic map(
    USE_STATUS_FLAGS => c_NO
        )
  port map( read_clock_in => clk_tx,
        write_clock_in    => clk_sys,
        read_enable_in    => fifo_tx_rd_en,
        write_enable_in   => fifo_tx_wr_en,
        fifo_gsr_in       => fifo_tx_reset,
        write_data_in     => fifo_tx_din,
        read_data_out     => fifo_tx_dout,
        full_out          => fifo_tx_full,
        empty_out         => fifo_tx_empty,
        almost_full_out   => fifo_tx_almost_full
      );

fifo_tx_reset <= reset_i or not tx_allow_q;
fifo_tx_din   <= med_packet_num_in(2) & med_packet_num_in(0)& med_data_in;
fifo_tx_wr_en <= med_dataready_in and tx_allow_q;
fifo_tx_rd_en <= tx_allow_qtx;


THE_SERDES_INPUT_PROC: process( clk_tx )
  begin
    if( rising_edge(clk_tx) ) then
      last_fifo_tx_empty <= fifo_tx_empty;
      first_idle <= not last_fifo_tx_empty and fifo_tx_empty;
      if send_reset_in = '1' then
        tx_data <= x"FEFE";
        tx_k <= "11";
      elsif( (last_fifo_tx_empty = '1') or (tx_allow_qtx = '0') ) then
        tx_data <= x"50bc";
        tx_k <= "01";
        tx_correct <= first_idle & '0';
      else
        tx_data <= fifo_tx_dout(15 downto 0);
        tx_k <= "00";
        tx_correct <= "00";
      end if;
    end if;
  end process THE_SERDES_INPUT_PROC;

-------------------------------------------------      
-- SCI
-------------------------------------------------      
--gives access to serdes config port from slow control and reads word alignment every ~ 40 us
PROC_SCI_CTRL: process(clk_sys)
  variable cnt : integer range 0 to 4 := 0;
begin
  if( rising_edge(clk_sys) ) then
	  SCI_ACK <= '0';
	  case sci_state is
		when IDLE =>
		  sci_ch_i        <= x"0";
		  sci_qd_i        <= '0';
		  sci_reg_i       <= '0';
		  sci_read_i      <= '0';
		  sci_write_i     <= '0';
		  sci_timer       <= sci_timer + 1;
		  if SCI_READ = '1' or SCI_WRITE = '1' then
			sci_ch_i(0)   <= not SCI_ADDR(6) and not SCI_ADDR(7) and not SCI_ADDR(8);
			sci_ch_i(1)   <=     SCI_ADDR(6) and not SCI_ADDR(7) and not SCI_ADDR(8);
			sci_ch_i(2)   <= not SCI_ADDR(6) and     SCI_ADDR(7) and not SCI_ADDR(8);
			sci_ch_i(3)   <=     SCI_ADDR(6) and     SCI_ADDR(7) and not SCI_ADDR(8);
			sci_qd_i      <= not SCI_ADDR(6) and not SCI_ADDR(7) and     SCI_ADDR(8);
			sci_reg_i     <=     SCI_ADDR(6) and not SCI_ADDR(7) and     SCI_ADDR(8);
			sci_addr_i    <= SCI_ADDR;
			sci_data_in_i <= SCI_DATA_IN;
			sci_read_i    <= SCI_READ  and not (SCI_ADDR(6) and not SCI_ADDR(7) and     SCI_ADDR(8));
			sci_write_i   <= SCI_WRITE and not (SCI_ADDR(6) and not SCI_ADDR(7) and     SCI_ADDR(8));
			sci_state     <= SCTRL;
		  elsif sci_timer(sci_timer'left) = '1' then
			sci_timer     <= (others => '0');
			sci_state     <= GET_WA;
		  end if;      
		when SCTRL =>
		  if sci_reg_i = '1' then
--//			SCI_DATA_OUT  <= debug_reg(8*(to_integer(unsigned(SCI_ADDR(3 downto 0))))+7 downto 8*(to_integer(unsigned(SCI_ADDR(3 downto 0)))));
			SCI_DATA_OUT  <= (others => '0');
			SCI_ACK       <= '1';
			sci_write_i   <= '0';
			sci_read_i    <= '0';
			sci_state     <= IDLE;
		  else
			sci_state     <= SCTRL_WAIT;
		  end if;
		when SCTRL_WAIT   =>
		  sci_state       <= SCTRL_WAIT2;
		when SCTRL_WAIT2  =>
		  sci_state       <= SCTRL_FINISH;
		when SCTRL_FINISH =>
		  SCI_DATA_OUT    <= sci_data_out_i;
		  SCI_ACK         <= '1';
		  sci_write_i     <= '0';
		  sci_read_i      <= '0';
		  sci_state       <= IDLE;
		
		when GET_WA =>
		  if cnt = 4 then
			cnt           := 0;
			sci_state     <= IDLE;
		  else
			sci_state     <= GET_WA_WAIT;
			sci_addr_i    <= '0' & x"22";
			sci_ch_i      <= x"0";
			sci_ch_i(cnt) <= '1';
			sci_read_i    <= '1';
		  end if;
		when GET_WA_WAIT  =>
		  sci_state       <= GET_WA_WAIT2;
		when GET_WA_WAIT2 =>
		  sci_state       <= GET_WA_FINISH;
		when GET_WA_FINISH =>
		  wa_position(cnt*4+3 downto cnt*4) <= sci_data_out_i(3 downto 0);
		  sci_state       <= GET_WA;    
		  cnt             := cnt + 1;
	  end case;
	  
	  if (SCI_READ = '1' or SCI_WRITE = '1') and sci_state /= IDLE then
		SCI_NACK <= '1';
	  else
		SCI_NACK <= '0';
	  end if;
  end if;
end process;
    
  

--Generate LED signals
----------------------
process( clk_sys )
  begin
    if rising_edge(clk_sys) then
      led_counter <= led_counter + to_unsigned(1,1);

      if buf_med_dataready_out = '1' then
        rx_led <= '1';
      elsif led_counter = 0 then
        rx_led <= '0';
      end if;

      if tx_k(0) = '0' then
        tx_led <= '1';
      elsif led_counter = 0 then
        tx_led <= '0';
      end if;

    end if;
  end process;

stat_op(15)           <= send_reset_words_q;
stat_op(14)           <= buf_stat_op(14);
stat_op(13)           <= make_trbnet_reset_q;
stat_op(12)           <= '0';
stat_op(11)           <= tx_led; --tx led
stat_op(10)           <= rx_led; --rx led
stat_op(9 downto 0)   <= buf_stat_op(9 downto 0);

-- Debug output
stat_debug(15 downto 0)  <= rx_data;
stat_debug(17 downto 16) <= rx_k;
stat_debug(19 downto 18) <= (others => '0');
stat_debug(23 downto 20) <= buf_stat_debug(3 downto 0);
stat_debug(24)           <= fifo_rx_rd_en;
stat_debug(25)           <= fifo_rx_wr_en;
stat_debug(26)           <= fifo_rx_reset;
stat_debug(27)           <= fifo_rx_empty;
stat_debug(28)           <= fifo_rx_full;
stat_debug(29)           <= last_rx(8);
stat_debug(30)           <= rx_allow_q;
stat_debug(41 downto 31) <= (others => '0');
stat_debug(42)           <= clk_sys;
stat_debug(43)           <= clk_sys;
stat_debug(59 downto 44) <= (others => '0');
stat_debug(63 downto 60) <= buf_stat_debug(3 downto 0);

--stat_debug(3 downto 0)   <= buf_stat_debug(3 downto 0); -- state_bits
--stat_debug(4)            <= buf_stat_debug(4); -- alignme
--stat_debug(5)            <= sfp_prsnt_n;
--stat_debug(6)            <= tx_k(0);
--stat_debug(7)            <= tx_k(1);
--stat_debug(8)            <= rx_k_q(0);
--stat_debug(9)            <= rx_k_q(1);
--stat_debug(18 downto 10) <= link_error;
--stat_debug(19)           <= '0';
--stat_debug(20)           <= link_ok(0);
--stat_debug(38 downto 21) <= fifo_rx_din;
--stat_debug(39)           <= swap_bytes;
--stat_debug(40)           <= buf_stat_debug(7); -- sfp_missing_in
--stat_debug(41)           <= buf_stat_debug(8); -- sfp_los_in
--stat_debug(42)           <= buf_stat_debug(6); -- resync
--stat_debug(59 downto 43) <= (others => '0');
--stat_debug(63 downto 60) <= link_error(3 downto 0);

CLKdiv100_process: process(CLK)
variable counter_V : integer range 0 to 99 := 0;
begin
	if (rising_edge(CLK)) then 
		if counter_V<49 then -- 99 for 125MHz
			counter_V := counter_V+1;
		else
			counter_V := 0;
			CLKdiv100_S <= not CLKdiv100_S;
		end if;
	end if;
end process;
sync_clk_rx_fulldiv100_process: process(sync_clk_rx_full)
variable counter_V : integer range 0 to 99 := 0;
begin
	if (rising_edge(sync_clk_rx_full)) then 
		if counter_V<49 then -- 99 for 125MHz
			counter_V := counter_V+1;
		else
			counter_V := 0;
			sync_clk_rx_fulldiv100_S <= not sync_clk_rx_fulldiv100_S;
		end if;
	end if;
end process;

end architecture;