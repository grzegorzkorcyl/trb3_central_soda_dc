--Media interface for Lattice ECP3 using PCS at 2GHz


LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;

entity trb_net16_med_1_3_ecp3_sfp is
  generic(
    SERDES_NUM : integer range 0 to 3 := 0;
    EXT_CLOCK  : integer range 0 to 1 := c_NO;
    USE_200_MHZ: integer range 0 to 1 := c_YES;
    USE_125_MHZ: integer range 0 to 1 := c_NO;
    USE_CTC    : integer range 0 to 1 := c_YES;
    USE_SLAVE  : integer range 0 to 1 := c_NO
    );
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
    -- Connection to addon interface        
    SERDES_ADDON_TX    : out std_logic_vector(11 downto 8);
    SERDES_ADDON_RX    : in  std_logic_vector(11 downto 8);
    SFP_MOD0_5         : in  std_logic;
    SFP_MOD0_3         : in  std_logic;          
    SFP_LOS_5          : in  std_logic;          
    SFP_LOS_3          : in  std_logic;
	TX_PLL_LOL_QD      : out std_logic;
    TX_DATA_CH3        : in std_logic_vector(7 downto 0);
    TX_K_CH3           : in std_logic;
    -- Status and control port
    STAT_OP            : out std_logic_vector (15 downto 0);
    CTRL_OP            : in  std_logic_vector (15 downto 0);
    STAT_DEBUG         : out std_logic_vector (63 downto 0);
    CTRL_DEBUG         : in  std_logic_vector (63 downto 0)
   );
end entity;

architecture trb_net16_med_1_3_ecp3_sfp_arch of trb_net16_med_1_3_ecp3_sfp is


  -- Placer Directives
  attribute HGROUP : string;
  -- for whole architecture
  attribute HGROUP of trb_net16_med_1_3_ecp3_sfp_arch : architecture  is "media_interface_group";
  attribute syn_sharing : string;
  attribute syn_sharing of trb_net16_med_1_3_ecp3_sfp_arch : architecture is "off";

  component sfp_0_200_ctc
    port(
      HDINP_CH0          : in std_logic;
      HDINN_CH0          : in std_logic;
      HDOUTP_CH0         : out std_logic;
      HDOUTN_CH0         : out std_logic;
      
      RXICLK_CH0         : in std_logic;
      TXICLK_CH0         : in std_logic;
      FPGA_RXREFCLK_CH0  : in std_logic;
      FPGA_TXREFCLK      : in std_logic;
      RX_FULL_CLK_CH0    : out std_logic;
      RX_HALF_CLK_CH0    : out std_logic;
      TX_FULL_CLK_CH0    : out std_logic;
      TX_HALF_CLK_CH0    : out std_logic;

      TXDATA_CH0         : in std_logic_vector(15 downto 0);
      TX_K_CH0           : in std_logic_vector(1 downto 0);
      TX_FORCE_DISP_CH0  : in std_logic_vector(1 downto 0);
      TX_DISP_SEL_CH0    : in std_logic_vector(1 downto 0);
      
      SB_FELB_CH0_C      : in std_logic;
      SB_FELB_RST_CH0_C  : in std_logic;
      
      TX_PWRUP_CH0_C     : in std_logic;
      RX_PWRUP_CH0_C     : in std_logic;
      TX_DIV2_MODE_CH0_C : in std_logic;
      RX_DIV2_MODE_CH0_C : in std_logic;
      
      SCI_WRDATA         : in std_logic_vector(7 downto 0);
      SCI_RDDATA         : out std_logic_vector(7 downto 0);
      SCI_ADDR           : in std_logic_vector(5 downto 0);
      SCI_SEL_QUAD       : in std_logic;
      SCI_RD             : in std_logic;
      SCI_WRN            : in std_logic;
      SCI_SEL_CH0        : in std_logic;

      TX_SERDES_RST_C    : in std_logic;
      RST_N              : in std_logic;
      SERDES_RST_QD_C    : in std_logic;          
      
      RXDATA_CH0         : out std_logic_vector(15 downto 0);
      RX_K_CH0           : out std_logic_vector(1 downto 0);
      RX_DISP_ERR_CH0    : out std_logic_vector(1 downto 0);
      RX_CV_ERR_CH0      : out std_logic_vector(1 downto 0);
      
      RX_LOS_LOW_CH0_S   : out std_logic;
      LSM_STATUS_CH0_S   : out std_logic;
      RX_CDR_LOL_CH0_S   : out std_logic;
      TX_PLL_LOL_QD_S    : out std_logic
      );
  end component;  
  
  component sfp_0_200_int
    port(
      HDINP_CH0          : in std_logic;
      HDINN_CH0          : in std_logic;
      HDOUTP_CH0         : out std_logic;
      HDOUTN_CH0         : out std_logic;
      
      RXICLK_CH0         : in std_logic;
      TXICLK_CH0         : in std_logic;
      FPGA_RXREFCLK_CH0  : in std_logic;
      FPGA_TXREFCLK      : in std_logic;
      RX_FULL_CLK_CH0    : out std_logic;
      RX_HALF_CLK_CH0    : out std_logic;
      TX_FULL_CLK_CH0    : out std_logic;
      TX_HALF_CLK_CH0    : out std_logic;

      TXDATA_CH0         : in std_logic_vector(15 downto 0);
      TX_K_CH0           : in std_logic_vector(1 downto 0);
      TX_FORCE_DISP_CH0  : in std_logic_vector(1 downto 0);
      TX_DISP_SEL_CH0    : in std_logic_vector(1 downto 0);
      
      SB_FELB_CH0_C      : in std_logic;
      SB_FELB_RST_CH0_C  : in std_logic;
      
      TX_PWRUP_CH0_C     : in std_logic;
      RX_PWRUP_CH0_C     : in std_logic;
      TX_DIV2_MODE_CH0_C : in std_logic;
      RX_DIV2_MODE_CH0_C : in std_logic;
      
      SCI_WRDATA         : in std_logic_vector(7 downto 0);
      SCI_RDDATA         : out std_logic_vector(7 downto 0);
      SCI_ADDR           : in std_logic_vector(5 downto 0);
      SCI_SEL_QUAD       : in std_logic;
      SCI_RD             : in std_logic;
      SCI_WRN            : in std_logic;
      SCI_SEL_CH0        : in std_logic;

      TX_SERDES_RST_C    : in std_logic;
      RST_N              : in std_logic;
      SERDES_RST_QD_C    : in std_logic;          
      
      RXDATA_CH0         : out std_logic_vector(15 downto 0);
      RX_K_CH0           : out std_logic_vector(1 downto 0);
      RX_DISP_ERR_CH0    : out std_logic_vector(1 downto 0);
      RX_CV_ERR_CH0      : out std_logic_vector(1 downto 0);
      
      RX_LOS_LOW_CH0_S   : out std_logic;
      LSM_STATUS_CH0_S   : out std_logic;
      RX_CDR_LOL_CH0_S   : out std_logic;
      TX_PLL_LOL_QD_S    : out std_logic
      );
  end component;

  component sfp_1_200_int
    port(
      HDINP_CH1          : in std_logic;
      HDINN_CH1          : in std_logic;
      HDOUTP_CH1         : out std_logic;
      HDOUTN_CH1         : out std_logic;
      
      RXICLK_CH1         : in std_logic;
      TXICLK_CH1         : in std_logic;
      FPGA_RXREFCLK_CH1  : in std_logic;
      FPGA_TXREFCLK      : in std_logic;
      RX_FULL_CLK_CH1    : out std_logic;
      RX_HALF_CLK_CH1    : out std_logic;
      TX_FULL_CLK_CH1    : out std_logic;
      TX_HALF_CLK_CH1    : out std_logic;

      TXDATA_CH1         : in std_logic_vector(15 downto 0);
      TX_K_CH1           : in std_logic_vector(1 downto 0);
      TX_FORCE_DISP_CH1  : in std_logic_vector(1 downto 0);
      TX_DISP_SEL_CH1    : in std_logic_vector(1 downto 0);
      
      SB_FELB_CH1_C      : in std_logic;
      SB_FELB_RST_CH1_C  : in std_logic;
      
      TX_PWRUP_CH1_C     : in std_logic;
      RX_PWRUP_CH1_C     : in std_logic;
      TX_DIV2_MODE_CH1_C : in std_logic;
      RX_DIV2_MODE_CH1_C : in std_logic;
      
      SCI_WRDATA         : in std_logic_vector(7 downto 0);
      SCI_RDDATA         : out std_logic_vector(7 downto 0);
      SCI_ADDR           : in std_logic_vector(5 downto 0);
      SCI_SEL_QUAD       : in std_logic;
      SCI_RD             : in std_logic;
      SCI_WRN            : in std_logic;
      SCI_SEL_CH1        : in std_logic;

      TX_SERDES_RST_C    : in std_logic;
      RST_N              : in std_logic;
      SERDES_RST_QD_C    : in std_logic;          
      
      RXDATA_CH1         : out std_logic_vector(15 downto 0);
      RX_K_CH1           : out std_logic_vector(1 downto 0);
      RX_DISP_ERR_CH1    : out std_logic_vector(1 downto 0);
      RX_CV_ERR_CH1      : out std_logic_vector(1 downto 0);
      
      RX_LOS_LOW_CH1_S   : out std_logic;
      LSM_STATUS_CH1_S   : out std_logic;
      RX_CDR_LOL_CH1_S   : out std_logic;
      TX_PLL_LOL_QD_S    : out std_logic
      );
  end component;  
  
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

  signal sci_ch_i       : std_logic_vector(3 downto 0);
  signal sci_addr_i     : std_logic_vector(8 downto 0);
  signal sci_data_in_i  : std_logic_vector(7 downto 0);
  signal sci_data_out_i : std_logic_vector(7 downto 0);
  signal sci_read_i     : std_logic;
  signal sci_write_i    : std_logic;
  signal sci_write_shift_i : std_logic_vector(2 downto 0);
  signal sci_read_shift_i  : std_logic_vector(2 downto 0);  
  
  --OJK 13-dec-2013
  signal cnt             : integer range 0 to 10000;
  signal tx_pll_lol_qd_i : std_logic;
  
  attribute syn_keep : boolean;
  attribute syn_preserve : boolean;
  attribute syn_keep of led_counter : signal is true;
  attribute syn_keep of send_reset_in : signal is true;
  attribute syn_keep of reset_i : signal is true;
  attribute syn_preserve of reset_i : signal is true;

begin


--------------------------------------------------------------------------
-- Select proper clock configuration
--------------------------------------------------------------------------
gen_clocks_200_ctc : if USE_200_MHZ = c_YES and USE_CTC = c_YES and USE_SLAVE = c_NO generate
  clk_sys <= SYSCLK;
  clk_tx  <= SYSCLK;
  clk_rx  <= SYSCLK;
  clk_rxref <= CLK;
  clk_txref <= CLK;
end generate;


gen_clocks_200_noctc : if USE_200_MHZ = c_YES and USE_CTC = c_NO and USE_SLAVE = c_NO  generate --OJK <== We're using this one!
  clk_sys <= SYSCLK;
  clk_tx  <= SYSCLK;
  clk_rx  <= ff_rxhalfclk;
  clk_rxref <= CLK;
  clk_txref <= CLK;
end generate;


gen_clocks_200_ctc_sync : if USE_200_MHZ = c_YES and USE_CTC = c_YES and USE_SLAVE = c_YES generate
  clk_sys <= SYSCLK;
  clk_tx  <= ff_rxhalfclk;
  clk_rx  <= ff_rxhalfclk;
  clk_rxref <= CLK;
  clk_txref <= ff_rxfullclk;
end generate;


gen_clocks_200_noctc_sync : if USE_200_MHZ = c_YES and USE_CTC = c_NO and USE_SLAVE = c_YES  generate
  clk_sys <= SYSCLK;
  clk_tx  <= ff_rxhalfclk;
  clk_rx  <= ff_rxhalfclk;
  clk_rxref <= CLK;
  clk_txref <= ff_rxfullclk;
end generate;


gen_clocks_125_noctc : if USE_125_MHZ = c_YES and USE_CTC = c_NO and USE_SLAVE = c_NO  generate
  clk_sys <= SYSCLK;
  clk_tx  <= SYSCLK;
  clk_rx  <= ff_rxhalfclk;
  clk_rxref <= CLK;
  clk_txref <= CLK;
end generate;

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
      HIGHSPEED_STARTUP => c_YES
      )
    port map(
      SYSCLK            => clk_sys,
      RESET             => reset_i,
      CLEAR             => clear,
      SFP_MISSING_IN    => sfp_prsnt_n,
      SFP_LOS_IN        => sfp_los,
      SD_LINK_OK_IN     => link_ok(0),
      SD_LOS_IN         => link_error(8),
      SD_TXCLK_BAD_IN   => link_error(5),
      SD_RXCLK_BAD_IN   => link_error(4),
      SD_RETRY_IN       => '0', -- '0' = handle byte swapping in logic, '1' = simply restart link and hope
      SD_ALIGNMENT_IN	=> rx_k_q,
      SD_CV_IN          => link_error(7 downto 6),
      FULL_RESET_OUT    => quad_rst,
      LANE_RESET_OUT    => lane_rst,
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

ffc_quad_rst         <= quad_rst;
ffc_lane_tx_rst      <= lane_rst;


ffc_lane_rx_rst      <= lane_rst;

-- SerDes clock output to FPGA fabric
REFCLK2CORE_OUT <= ff_rxhalfclk;
CLK_RX_HALF_OUT <= ff_rxhalfclk;
CLK_RX_FULL_OUT <= ff_rxfullclk;


-- Instantiation of serdes module

  gen_serdes_0_200_ctc : if SERDES_NUM = 0 and EXT_CLOCK = c_NO and USE_200_MHZ = c_YES and USE_CTC = c_YES generate
    THE_SERDES: sfp_0_200_ctc
      port map(
        HDINP_CH0           => sd_rxd_p_in,
        HDINN_CH0           => sd_rxd_n_in,
        HDOUTP_CH0          => sd_txd_p_out,
        HDOUTN_CH0          => sd_txd_n_out,

        RXICLK_CH0          => clk_rx,
        TXICLK_CH0          => clk_tx,
        FPGA_RXREFCLK_CH0   => clk_rxref,
        FPGA_TXREFCLK       => clk_txref,
        RX_FULL_CLK_CH0     => ff_rxfullclk,
        RX_HALF_CLK_CH0     => ff_rxhalfclk,
        TX_FULL_CLK_CH0     => open,
        TX_HALF_CLK_CH0     => ff_txhalfclk,

        TXDATA_CH0          => tx_data,
        TX_K_CH0            => tx_k,
        TX_FORCE_DISP_CH0   => tx_correct,
        TX_DISP_SEL_CH0     => "00",

        SB_FELB_CH0_C       => '0', --loopback enable
        SB_FELB_RST_CH0_C   => '0', --loopback reset

        TX_PWRUP_CH0_C      => '1', --tx power up
        RX_PWRUP_CH0_C      => '1', --rx power up
        TX_DIV2_MODE_CH0_C  => '0', --full rate
        RX_DIV2_MODE_CH0_C  => '0', --full rate

        SCI_WRDATA          => sci_data_in_i,
        SCI_RDDATA          => sci_data_out_i,
        SCI_ADDR            => sci_addr_i(5 downto 0),
        SCI_SEL_QUAD        => sci_addr_i(8),
        SCI_SEL_CH0         => sci_ch_i(0),
        SCI_RD              => sci_read_i,
        SCI_WRN             => sci_write_i,

        TX_SERDES_RST_C     => CLEAR,
        RST_N               => '1',
        SERDES_RST_QD_C     => ffc_quad_rst,

        RXDATA_CH0          => comb_rx_data,
        RX_K_CH0            => comb_rx_k,
        RX_DISP_ERR_CH0     => open,
        RX_CV_ERR_CH0       => link_error(7 downto 6),

        RX_LOS_LOW_CH0_S    => link_error(8),
        LSM_STATUS_CH0_S    => link_ok(0),
        RX_CDR_LOL_CH0_S    => link_error(4),
        TX_PLL_LOL_QD_S     => link_error(5)    
        );
  end generate;

  gen_serdes_0_200 : if SERDES_NUM = 0 and EXT_CLOCK = c_NO and USE_200_MHZ = c_YES and USE_CTC = c_NO generate
    THE_SERDES: sfp_0_200_int
      port map(
        HDINP_CH0           => sd_rxd_p_in,
        HDINN_CH0           => sd_rxd_n_in,
        HDOUTP_CH0          => sd_txd_p_out,
        HDOUTN_CH0          => sd_txd_n_out,

        RXICLK_CH0          => clk_rx,
        TXICLK_CH0          => clk_tx,
        FPGA_RXREFCLK_CH0   => clk_rxref,
        FPGA_TXREFCLK       => clk_txref,
        RX_FULL_CLK_CH0     => ff_rxfullclk,
        RX_HALF_CLK_CH0     => ff_rxhalfclk,
        TX_FULL_CLK_CH0     => open,
        TX_HALF_CLK_CH0     => ff_txhalfclk,

        TXDATA_CH0          => tx_data,
        TX_K_CH0            => tx_k,
        TX_FORCE_DISP_CH0   => tx_correct,
        TX_DISP_SEL_CH0     => "00",

        SB_FELB_CH0_C       => '0', --loopback enable
        SB_FELB_RST_CH0_C   => '0', --loopback reset

        TX_PWRUP_CH0_C      => '1', --tx power up
        RX_PWRUP_CH0_C      => '1', --rx power up
        TX_DIV2_MODE_CH0_C  => '0', --full rate
        RX_DIV2_MODE_CH0_C  => '0', --full rate

        SCI_WRDATA          => sci_data_in_i,
        SCI_RDDATA          => sci_data_out_i,
        SCI_ADDR            => sci_addr_i(5 downto 0),
        SCI_SEL_QUAD        => sci_addr_i(8),
        SCI_SEL_CH0         => sci_ch_i(0),
        SCI_RD              => sci_read_i,
        SCI_WRN             => sci_write_i,

        TX_SERDES_RST_C     => CLEAR,
        RST_N               => '1',
        SERDES_RST_QD_C     => ffc_quad_rst,

        RXDATA_CH0          => comb_rx_data,
        RX_K_CH0            => comb_rx_k,
        RX_DISP_ERR_CH0     => open,
        RX_CV_ERR_CH0       => link_error(7 downto 6),

        RX_LOS_LOW_CH0_S    => link_error(8),
        LSM_STATUS_CH0_S    => link_ok(0),
        RX_CDR_LOL_CH0_S    => link_error(4),
        TX_PLL_LOL_QD_S     => link_error(5)    
        );
  end generate;

  gen_serdes_1_200 : if SERDES_NUM = 1 and EXT_CLOCK = c_NO and USE_200_MHZ = c_YES and USE_CTC = c_NO generate
    --OJK 29-nov-2013
    THE_SERDES: sfp_1_3_200_int port map(
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
      sb_felb_ch1_c      => '0',                   
      sb_felb_rst_ch1_c  => '0',                
      tx_pwrup_ch1_c     => '1',                   
      rx_pwrup_ch1_c     => '1',                   
      rx_los_low_ch1_s   => link_error(8),         
      lsm_status_ch1_s   => link_ok(0),            
      rx_cdr_lol_ch1_s   => link_error(4),         
      tx_div2_mode_ch1_c => '0',                   
      rx_div2_mode_ch1_c => '0',
      
      hdoutp_ch3         => SERDES_ADDON_TX(10),             
      hdoutn_ch3         => SERDES_ADDON_TX(11),             
      sci_sel_ch3        => '0', --disable access to channel 3 registers
      txiclk_ch3         => clk_tx,             
      tx_full_clk_ch3    => open,                
      tx_half_clk_ch3    => open,        
      fpga_rxrefclk_ch3  => clk_rxref,      
      txdata_ch3         => tx_data_ch3,             
      tx_k_ch3           => tx_k_ch3,
      tx_force_disp_ch3  => '0',      
      tx_disp_sel_ch3    => '0',        
      tx_pwrup_ch3_c     => '1',         
      tx_div2_mode_ch3_c => '1', 
      
      sci_wrdata         => sci_data_in_i,
      sci_addr           => sci_addr_i(5 downto 0),
      sci_rddata         => sci_data_out_i,
      sci_sel_quad       => sci_addr_i(8),
      sci_rd             => sci_read_i,
      sci_wrn            => sci_write_i,
      fpga_txrefclk      => clk_txref,               
      tx_serdes_rst_c    => CLEAR,          
      tx_pll_lol_qd_s    => tx_pll_lol_qd_i,          
      tx_sync_qd_c       => '0',             -- Multiple channel transmit synchronization is not needed?
      refclk2fpga        => open,              -- Not needed?
      rst_n              => '1',                   
      serdes_rst_qd_c    => ffc_quad_rst        
    );                     
	
    link_error(5) <= tx_pll_lol_qd_i;
	TX_PLL_LOL_QD <= tx_pll_lol_qd_i;
	
      -- THE_SERDES: sfp_1_200_int
      -- port map(
        -- HDINP_CH1           => sd_rxd_p_in,
        -- HDINN_CH1           => sd_rxd_n_in,
        -- HDOUTP_CH1          => sd_txd_p_out,
        -- HDOUTN_CH1          => sd_txd_n_out,

        -- RXICLK_CH1          => clk_rx,
        -- TXICLK_CH1          => clk_tx,
        -- FPGA_RXREFCLK_CH1   => clk_rxref,
        -- FPGA_TXREFCLK       => clk_txref,
        -- RX_FULL_CLK_CH1     => ff_rxfullclk,
        -- RX_HALF_CLK_CH1     => ff_rxhalfclk,
        -- TX_FULL_CLK_CH1     => open,
        -- TX_HALF_CLK_CH1     => ff_txhalfclk,

        -- TXDATA_CH1          => tx_data,
        -- TX_K_CH1            => tx_k,
        -- TX_FORCE_DISP_CH1   => tx_correct,
        -- TX_DISP_SEL_CH1     => "00",

        -- SB_FELB_CH1_C       => '0', --loopback enable
        -- SB_FELB_RST_CH1_C   => '0', --loopback reset

        -- TX_PWRUP_CH1_C      => '1', --tx power up
        -- RX_PWRUP_CH1_C      => '1', --rx power up
        -- TX_DIV2_MODE_CH1_C  => '0', --full rate
        -- RX_DIV2_MODE_CH1_C  => '0', --full rate

        -- SCI_WRDATA          => sci_data_in_i,
        -- SCI_RDDATA          => sci_data_out_i,
        -- SCI_ADDR            => sci_addr_i(5 downto 0),
        -- SCI_SEL_QUAD        => sci_addr_i(8),
        -- SCI_SEL_CH1         => sci_ch_i(1),
        -- SCI_RD              => sci_read_i,
        -- SCI_WRN             => sci_write_i,


        -- TX_SERDES_RST_C     => CLEAR,
        -- RST_N               => '1',
        -- SERDES_RST_QD_C     => ffc_quad_rst,

        -- RXDATA_CH1          => comb_rx_data,
        -- RX_K_CH1            => comb_rx_k,
        -- RX_DISP_ERR_CH1     => open,
        -- RX_CV_ERR_CH1       => link_error(7 downto 6),

        -- RX_LOS_LOW_CH1_S    => link_error(8),
        -- LSM_STATUS_CH1_S    => link_ok(0),
        -- RX_CDR_LOL_CH1_S    => link_error(4),
        -- TX_PLL_LOL_QD_S     => link_error(5)    
        -- );
  end generate;
  
  gen_serdes_1_125 : if SERDES_NUM = 1 and EXT_CLOCK = c_NO and USE_125_MHZ = c_YES and USE_CTC = c_NO generate
    THE_SERDES: entity work.sfp_1_125_int
      port map(
        HDINP_CH1           => sd_rxd_p_in,
        HDINN_CH1           => sd_rxd_n_in,
        HDOUTP_CH1          => sd_txd_p_out,
        HDOUTN_CH1          => sd_txd_n_out,

        RXICLK_CH1          => clk_rx,
        TXICLK_CH1          => clk_tx,
        FPGA_RXREFCLK_CH1   => clk_rxref,
        FPGA_TXREFCLK       => clk_txref,
        RX_FULL_CLK_CH1     => ff_rxfullclk,
        RX_HALF_CLK_CH1     => ff_rxhalfclk,
        TX_FULL_CLK_CH1     => open,
        TX_HALF_CLK_CH1     => ff_txhalfclk,

        TXDATA_CH1          => tx_data,
        TX_K_CH1            => tx_k,
        TX_FORCE_DISP_CH1   => tx_correct,
        TX_DISP_SEL_CH1     => "00",

        SB_FELB_CH1_C       => '0', --loopback enable
        SB_FELB_RST_CH1_C   => '0', --loopback reset

        TX_PWRUP_CH1_C      => '1', --tx power up
        RX_PWRUP_CH1_C      => '1', --rx power up
        TX_DIV2_MODE_CH1_C  => '0', --full rate
        RX_DIV2_MODE_CH1_C  => '0', --full rate

        SCI_WRDATA          => sci_data_in_i,
        SCI_RDDATA          => sci_data_out_i,
        SCI_ADDR            => sci_addr_i(5 downto 0),
        SCI_SEL_QUAD        => sci_addr_i(8),
        SCI_SEL_CH1         => sci_ch_i(1),
        SCI_RD              => sci_read_i,
        SCI_WRN             => sci_write_i,


        TX_SERDES_RST_C     => CLEAR,
        RST_N               => '1',
        SERDES_RST_QD_C     => ffc_quad_rst,

        RXDATA_CH1          => comb_rx_data,
        RX_K_CH1            => comb_rx_k,
        RX_DISP_ERR_CH1     => open,
        RX_CV_ERR_CH1       => link_error(7 downto 6),

        RX_LOS_LOW_CH1_S    => link_error(8),
        LSM_STATUS_CH1_S    => link_ok(0),
        RX_CDR_LOL_CH1_S    => link_error(4),
        TX_PLL_LOL_QD_S     => link_error(5)    
        );
  end generate;  
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
THE_BYTE_SWAP_PROC: process
  begin
    wait until rising_edge(clk_rx);  --CHANGED
    last_rx <= rx_k(1) & rx_data(15 downto 8);
    if( swap_bytes = '0' ) then
      fifo_rx_din   <= rx_k(1) & rx_k(0) & rx_data(15 downto 8) & rx_data(7 downto 0);
      fifo_rx_wr_en <= not rx_k(0) and rx_allow and link_ok(0);
    else
      fifo_rx_din   <= rx_k(0) & last_rx(8) & rx_data(7 downto 0) & last_rx(7 downto 0);
      fifo_rx_wr_en <= not last_rx(8) and rx_allow and link_ok(0);
    end if;
  end process THE_BYTE_SWAP_PROC;

buf_med_data_out          <= fifo_rx_dout(15 downto 0);
buf_med_dataready_out     <= not fifo_rx_dout(17) and not fifo_rx_dout(16) and not last_fifo_rx_empty and rx_allow_q;
buf_med_packet_num_out    <= rx_counter;
med_read_out              <= tx_allow_q and not fifo_tx_almost_full;


THE_CNT_RESET_PROC : process
  begin
    wait until rising_edge(clk_rx);  --CHANGED
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
  end process;


THE_SYNC_PROC: process
  begin
    wait until rising_edge(clk_sys);
    med_dataready_out     <= buf_med_dataready_out;
    med_data_out          <= buf_med_data_out;
    med_packet_num_out    <= buf_med_packet_num_out;
    if reset_i = '1' then
      med_dataready_out <= '0';
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

  
--SCI
----------------------
PROC_SCI : process begin
  wait until rising_edge(clk_sys);
  if SCI_READ = '1' or SCI_WRITE = '1' then
    sci_ch_i(0)   <= not SCI_ADDR(6) and not SCI_ADDR(7) and not SCI_ADDR(8);
    sci_ch_i(1)   <=     SCI_ADDR(6) and not SCI_ADDR(7) and not SCI_ADDR(8);
    sci_ch_i(2)   <= not SCI_ADDR(6) and     SCI_ADDR(7) and not SCI_ADDR(8);
    sci_ch_i(3)   <=     SCI_ADDR(6) and     SCI_ADDR(7) and not SCI_ADDR(8);
    sci_addr_i    <= SCI_ADDR;
    sci_data_in_i <= SCI_DATA_IN;
  end if;
  sci_read_shift_i  <= sci_read_shift_i(1 downto 0) & SCI_READ;
  sci_write_shift_i <= sci_write_shift_i(1 downto 0) & SCI_WRITE;
  SCI_DATA_OUT      <= sci_data_out_i;
end process;

sci_write_i <= or_all(sci_write_shift_i);
sci_read_i  <= or_all(sci_read_shift_i);
SCI_ACK     <= sci_write_shift_i(2) or sci_read_shift_i(2);
  
    
  

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

end architecture;