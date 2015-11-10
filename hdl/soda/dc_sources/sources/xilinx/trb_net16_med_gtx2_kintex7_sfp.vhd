--Media interface for Xilinx Kintex7 using SFP at 2GHz
--One channel is used.

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
--use work.med_sync_define.all;

entity trb_net16_med_gtx2_kintex7_sfp is
  port(
    CLK                : in  std_logic; -- SerDes clock
    SYSCLK             : in  std_logic; -- fabric clock = 100MHz
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
    -- Status and control port
    STAT_OP            : out std_logic_vector (15 downto 0);
    CTRL_OP            : in  std_logic_vector (15 downto 0);
    STAT_DEBUG         : out std_logic_vector (63 downto 0);
    CTRL_DEBUG         : in  std_logic_vector (63 downto 0)
   );
end entity;

architecture trb_net16_med_gtx2_kintex7_sfp_arch of trb_net16_med_gtx2_kintex7_sfp is

component GTX_trb3_2gb_wrapper
generic
(
    -- Simulation attributes
    EXAMPLE_SIM_GTRESET_SPEEDUP    : string    := "FALSE";    -- Set to TRUE to speed up sim reset
    STABLE_CLOCK_PERIOD            : integer   := 10 
);
port
(
    SOFT_RESET_TX_IN                        : in   std_logic;
    SOFT_RESET_RX_IN                        : in   std_logic;
    DONT_RESET_ON_DATA_ERROR_IN             : in   std_logic;
    Q2_CLK0_GTREFCLK_PAD_N_IN               : in   std_logic;
    Q2_CLK0_GTREFCLK_PAD_P_IN               : in   std_logic;

    GT0_TX_FSM_RESET_DONE_OUT               : out  std_logic;
    GT0_RX_FSM_RESET_DONE_OUT               : out  std_logic;
    GT0_DATA_VALID_IN                       : in   std_logic;
 
    GT0_TXUSRCLK_OUT                        : out  std_logic;
    GT0_TXUSRCLK2_OUT                       : out  std_logic;
    GT0_RXUSRCLK_OUT                        : out  std_logic;
    GT0_RXUSRCLK2_OUT                       : out  std_logic;

    --_________________________________________________________________________
        --GT0  (X1Y10)
    --____________________________CHANNEL PORTS________________________________
    --------------------------------- CPLL Ports -------------------------------
    gt0_cpllfbclklost_out                   : out  std_logic;
    gt0_cplllock_out                        : out  std_logic;
    gt0_cpllreset_in                        : in   std_logic;
    ---------------------------- Channel - DRP Ports  --------------------------
    gt0_drpaddr_in                          : in   std_logic_vector(8 downto 0);
    gt0_drpdi_in                            : in   std_logic_vector(15 downto 0);
    gt0_drpdo_out                           : out  std_logic_vector(15 downto 0);
    gt0_drpen_in                            : in   std_logic;
    gt0_drprdy_out                          : out  std_logic;
    gt0_drpwe_in                            : in   std_logic;
    --------------------------- Digital Monitor Ports --------------------------
    gt0_dmonitorout_out                     : out  std_logic_vector(7 downto 0);
    --------------------- RX Initialization and Reset Ports --------------------
    gt0_eyescanreset_in                     : in   std_logic;
    gt0_rxuserrdy_in                        : in   std_logic;
    -------------------------- RX Margin Analysis Ports ------------------------
    gt0_eyescandataerror_out                : out  std_logic;
    gt0_eyescantrigger_in                   : in   std_logic;
    ------------------ Receive Ports - FPGA RX interface Ports -----------------
    gt0_rxdata_out                          : out  std_logic_vector(15 downto 0);
    ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
    gt0_rxdisperr_out                       : out  std_logic_vector(1 downto 0);
    gt0_rxnotintable_out                    : out  std_logic_vector(1 downto 0);
    --------------------------- Receive Ports - RX AFE -------------------------
    gt0_gtxrxp_in                           : in   std_logic;
    ------------------------ Receive Ports - RX AFE Ports ----------------------
    gt0_gtxrxn_in                           : in   std_logic;
    ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
    gt0_rxphmonitor_out                     : out  std_logic_vector(4 downto 0);
    gt0_rxphslipmonitor_out                 : out  std_logic_vector(4 downto 0);
    --------------------- Receive Ports - RX Equalizer Ports -------------------
    gt0_rxdfelpmreset_in                    : in   std_logic;
    gt0_rxmonitorout_out                    : out  std_logic_vector(6 downto 0);
    gt0_rxmonitorsel_in                     : in   std_logic_vector(1 downto 0);
    ------------- Receive Ports - RX Initialization and Reset Ports ------------
    gt0_gtrxreset_in                        : in   std_logic;
    gt0_rxpmareset_in                       : in   std_logic;
    ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    gt0_rxcharisk_out                       : out  std_logic_vector(1 downto 0);
    -------------- Receive Ports -RX Initialization and Reset Ports ------------
    gt0_rxresetdone_out                     : out  std_logic;
    --------------------- TX Initialization and Reset Ports --------------------
    gt0_gttxreset_in                        : in   std_logic;
    gt0_txuserrdy_in                        : in   std_logic;
    ------------------ Transmit Ports - TX Data Path interface -----------------
    gt0_txdata_in                           : in   std_logic_vector(15 downto 0);
    ---------------- Transmit Ports - TX Driver and OOB signaling --------------
    gt0_gtxtxn_out                          : out  std_logic;
    gt0_gtxtxp_out                          : out  std_logic;
    ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    gt0_txoutclkfabric_out                  : out  std_logic;
    gt0_txoutclkpcs_out                     : out  std_logic;
    --------------------- Transmit Ports - TX Gearbox Ports --------------------
    gt0_txcharisk_in                        : in   std_logic_vector(1 downto 0);
    ------------- Transmit Ports - TX Initialization and Reset Ports -----------
    gt0_txresetdone_out                     : out  std_logic;
   

    --____________________________COMMON PORTS________________________________
     GT0_QPLLOUTCLK_OUT                     : out std_logic;
     GT0_QPLLOUTREFCLK_OUT                  : out std_logic;
     SYSCLK_IN                              : in   std_logic
);
end component;

  
  signal refck2core             : std_logic;
  --serdes connections
  signal tx_data                : std_logic_vector(15 downto 0);
  signal tx_k                   : std_logic_vector(1 downto 0);
  signal rx_data                : std_logic_vector(15 downto 0); -- delayed signals
  signal rx_k                   : std_logic_vector(1 downto 0);  -- delayed signals
  signal comb_rx_data           : std_logic_vector(15 downto 0); -- original signals from SFP
  signal comb_rx_k              : std_logic_vector(1 downto 0);  -- original signals from SFP
  signal link_ok                : std_logic; 
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

  signal reset_word_cnt         : unsigned(4 downto 0);
  signal make_trbnet_reset      : std_logic;
  signal make_trbnet_reset_q    : std_logic;
  signal send_reset_words       : std_logic;
  signal send_reset_words_q     : std_logic;
  signal send_reset_in          : std_logic;
  signal send_reset_in_qtx      : std_logic;
  signal reset_i                : std_logic;
  signal reset_i_rx             : std_logic;
  signal pwr_up                 : std_logic;
  signal clear_S                : std_logic;

  signal clk_tx                 : std_logic;
  signal clk_rx                 : std_logic;

  signal gt0_txfsmresetdone_i   : std_logic;
  signal gt0_rxfsmresetdone_i   : std_logic;
  signal gt0_txresetdone_i      : std_logic;

  signal gt0_rxnotintable_S     : std_logic_vector(1 downto 0);
  signal link_rx_error_S        : std_logic;
  signal link_tx_error_S        : std_logic;
   
-- attribute mark_debug : string;
-- attribute mark_debug of tx_data : signal is "true";
-- attribute mark_debug of tx_k : signal is "true";
-- attribute mark_debug of rx_data : signal is "true";
-- attribute mark_debug of rx_k : signal is "true";
-- attribute mark_debug of quad_rst : signal is "true";

-- attribute mark_debug of link_ok : signal is "true";
-- attribute mark_debug of rx_k_q : signal is "true";
-- attribute mark_debug of sfp_prsnt_n : signal is "true";
-- attribute mark_debug of tx_allow : signal is "true";
-- attribute mark_debug of rx_allow : signal is "true";
-- attribute mark_debug of swap_bytes : signal is "true";
-- attribute mark_debug of gt0_rxnotintable_S : signal is "true";
-- attribute mark_debug of link_rx_error_S : signal is "true";
-- attribute mark_debug of link_tx_error_S : signal is "true";
-- attribute mark_debug of ctrl_op : signal is "true";
-- attribute mark_debug of buf_stat_debug : signal is "true";

-- attribute mark_debug of make_trbnet_reset : signal is "true";
-- attribute mark_debug of send_reset_in : signal is "true";
-- attribute mark_debug of reset_i_rx : signal is "true";
-- attribute mark_debug of gt0_txfsmresetdone_i : signal is "true";
-- attribute mark_debug of gt0_rxfsmresetdone_i : signal is "true";
-- attribute mark_debug of gt0_txresetdone_i : signal is "true";

  begin

--------------------------------------------------------------------------
-- Select proper clock configuration
--------------------------------------------------------------------------
  clk_rx  <= ff_rxhalfclk;

--------------------------------------------------------------------------
-- Internal Lane Resets
--------------------------------------------------------------------------
  clear_S <= clear;


  PROC_RESET : process(SYSCLK)
    begin
      if rising_edge(SYSCLK) then
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
    CLK0     => SYSCLK,
    CLK1     => SYSCLK,
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
    CLK1              => SYSCLK,
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
    CLK0     => SYSCLK,
    CLK1     => SYSCLK,
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
      SYSCLK            => SYSCLK,
      RESET             => reset_i,
      CLEAR             => clear_S,
      SFP_MISSING_IN    => sfp_prsnt_n,
      SFP_LOS_IN        => sfp_los,
      SD_LINK_OK_IN     => link_ok, -- apparently not used
      SD_LOS_IN         => '0', -- apparently not used
      SD_TXCLK_BAD_IN   => link_tx_error_S,
      SD_RXCLK_BAD_IN   => link_rx_error_S,
      SD_RETRY_IN       => '0', -- '0' = handle byte swapping in logic, '1' = simply restart link and hope
      SD_ALIGNMENT_IN	=> rx_k_q,
      SD_CV_IN          => gt0_rxnotintable_S,
      FULL_RESET_OUT    => quad_rst,
      LANE_RESET_OUT    => open, -- apparently not used
      TX_ALLOW_OUT      => tx_allow,
      RX_ALLOW_OUT      => rx_allow,
      SWAP_BYTES_OUT    => swap_bytes,
      STAT_OP           => buf_stat_op,
      CTRL_OP           => ctrl_op,
      STAT_DEBUG        => buf_stat_debug
      );
sd_txdis_out <= quad_rst or reset_i;
link_rx_error_S <= '1' when (gt0_rxfsmresetdone_i='0')  else '0'; -- loss of lock 
link_tx_error_S <= '1' when (gt0_txresetdone_i='0') or (gt0_txfsmresetdone_i='0') else '0';

--------------------------------------------------------------------------
--------------------------------------------------------------------------

-- SerDes clock output to FPGA fabric
REFCLK2CORE_OUT <= ff_rxhalfclk;
CLK_RX_HALF_OUT <= ff_rxhalfclk;
CLK_RX_FULL_OUT <= ff_rxfullclk;

THE_SERDES: GTX_trb3_2gb_wrapper port map
    (
        soft_reset_tx_in => quad_rst,
        soft_reset_rx_in => quad_rst,
		DONT_RESET_ON_DATA_ERROR_IN => '0',
		Q2_CLK0_GTREFCLK_PAD_N_IN => SD_REFCLK_N_IN,
		Q2_CLK0_GTREFCLK_PAD_P_IN => SD_REFCLK_P_IN,
		GT0_TX_FSM_RESET_DONE_OUT => gt0_txfsmresetdone_i,
		GT0_RX_FSM_RESET_DONE_OUT => gt0_rxfsmresetdone_i,
		GT0_DATA_VALID_IN => '1', -- tx_allow,
 
		GT0_TXUSRCLK_OUT => open,
		GT0_TXUSRCLK2_OUT => clk_tx, -- clock for tx_data (100MHz)
		GT0_RXUSRCLK_OUT => ff_rxfullclk,
		GT0_RXUSRCLK2_OUT => ff_rxhalfclk, -- clock for rx_data (100MHz)
        --_____________________________________________________________________
        --_____________________________________________________________________
        --GT0  (X1Y10)
        --------------------------------- CPLL Ports -------------------------------
        gt0_cpllfbclklost_out => open,
        gt0_cplllock_out => open,
        gt0_cpllreset_in => '0',
        ---------------------------- Channel - DRP Ports  --------------------------
        gt0_drpaddr_in => (others => '0'),
        gt0_drpdi_in => (others => '0'),
        gt0_drpdo_out => open,
        gt0_drpen_in => '0',
        gt0_drprdy_out => open,
        gt0_drpwe_in => '0',
        --------------------------- Digital Monitor Ports --------------------------
        gt0_dmonitorout_out => open,
        --------------------- RX Initialization and Reset Ports --------------------
        gt0_eyescanreset_in => '0',
        gt0_rxuserrdy_in => '0',
        -------------------------- RX Margin Analysis Ports ------------------------
        gt0_eyescandataerror_out => open,
        gt0_eyescantrigger_in => '0',
        ------------------ Receive Ports - FPGA RX interface Ports -----------------
        gt0_rxdata_out => comb_rx_data,        
        ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
        gt0_rxdisperr_out => open,
        gt0_rxnotintable_out => gt0_rxnotintable_S,
        --------------------------- Receive Ports - RX AFE -------------------------
        gt0_gtxrxp_in => sd_rxd_p_in,
        ------------------------ Receive Ports - RX AFE Ports ----------------------
        gt0_gtxrxn_in => sd_rxd_n_in,
        ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
        gt0_rxphmonitor_out => open,
        gt0_rxphslipmonitor_out => open,
        --------------------- Receive Ports - RX Equalizer Ports -------------------
        gt0_rxdfelpmreset_in => '0',
        gt0_rxmonitorout_out => open,
        gt0_rxmonitorsel_in => "00",
        ------------- Receive Ports - RX Initialization and Reset Ports ------------
        gt0_gtrxreset_in => '0',
        gt0_rxpmareset_in => '0',
        ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        gt0_rxcharisk_out => comb_rx_k, 
        -------------- Receive Ports -RX Initialization and Reset Ports ------------
        gt0_rxresetdone_out => link_ok, 
        --------------------- TX Initialization and Reset Ports --------------------
        gt0_gttxreset_in => '0',
        gt0_txuserrdy_in => '0',
        ------------------ Transmit Ports - TX Data Path interface -----------------
        gt0_txdata_in => tx_data,
        ---------------- Transmit Ports - TX Driver and OOB signaling --------------
        gt0_gtxtxn_out => sd_txd_n_out,
        gt0_gtxtxp_out => sd_txd_p_out,
        ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        gt0_txoutclkfabric_out => open,
        gt0_txoutclkpcs_out => open,
        --------------------- Transmit Ports - TX Gearbox Ports --------------------
        gt0_txcharisk_in => tx_k,     
        ------------- Transmit Ports - TX Initialization and Reset Ports -----------
        gt0_txresetdone_out => gt0_txresetdone_i,

    --____________________________COMMON PORTS________________________________
		GT0_QPLLOUTCLK_OUT  => open,
		GT0_QPLLOUTREFCLK_OUT => open,
		SYSCLK_IN => SYSCLK
    );


-------------------------------------------------------------------------
-- RX Fifo & Data output
-------------------------------------------------------------------------
THE_FIFO_SFP_TO_FPGA: trb_net_fifo_16bit_bram_dualport
generic map(
  USE_STATUS_FLAGS => c_NO
       )
port map( read_clock_in  => SYSCLK,
      write_clock_in     => clk_rx,
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
		  fifo_rx_wr_en <= not rx_k(0) and rx_allow and link_ok;
		else
		  fifo_rx_din   <= rx_k(0) & last_rx(8) & rx_data(7 downto 0) & last_rx(7 downto 0);
		  fifo_rx_wr_en <= not last_rx(8) and rx_allow and link_ok;
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


THE_SYNC_PROC: process(SYSCLK)
  begin
    if rising_edge(SYSCLK) then
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
THE_RX_PACKETS_PROC: process( SYSCLK )
  begin
    if( rising_edge(SYSCLK) ) then
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
        write_clock_in    => SYSCLK,
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
        tx_correct <= first_idle & '0'; -- ???????????
      else
        tx_data <= fifo_tx_dout(15 downto 0);
        tx_k <= "00";
        tx_correct <= "00"; -- ???????????
      end if;
    end if;
  end process THE_SERDES_INPUT_PROC;



--Generate LED signals
----------------------
process( SYSCLK )
  begin
    if rising_edge(SYSCLK) then
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
stat_debug(42)           <= SYSCLK;
stat_debug(43)           <= SYSCLK;
stat_debug(59 downto 44) <= (others => '0');
stat_debug(63 downto 60) <= buf_stat_debug(3 downto 0);

end architecture;