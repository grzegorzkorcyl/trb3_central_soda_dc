--Media interface for Xilinx Kintex7 using SFP at 2GHz
--One channel is used.
library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
--use work.med_sync_define.all;

entity trb_net16_med_sync_gtx2_kintex7_sfp is
  port(
    CLK                : in  std_logic; -- SerDes clock
    SYSCLK             : in  std_logic; -- fabric clock = 100MHz
    RESET              : in  std_logic; -- synchronous reset
    CLEAR              : in  std_logic; -- asynchronous reset
    CLK_EN             : in  std_logic;
	disable_GTX_reset  : in  std_logic;
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
	SODA_RXD_P_IN      : in  std_logic;
    SODA_RXD_N_IN      : in  std_logic;
    SODA_TXD_P_OUT     : out std_logic;
    SODA_TXD_N_OUT     : out std_logic;
    SODA_REFCLK_P_IN   : in  std_logic;
    SODA_REFCLK_N_IN   : in  std_logic;
    SODA_PRSNT_N_IN    : in  std_logic;  -- SFP Present ('0' = SFP in place, '1' = no SFP mounted)
    SODA_LOS_IN        : in  std_logic;  -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
    SODA_TXDIS_OUT     : out  std_logic; -- SFP disable	
	SODA_DLM_IN        : in  std_logic;
	SODA_DLM_WORD_IN   : in  std_logic_vector(7 downto 0);
	SODA_DLM_OUT       : out  std_logic;
	SODA_DLM_WORD_OUT  : out  std_logic_vector(7 downto 0);
    SODA_CLOCK_OUT     : out  std_logic; -- 200MHz
	SODA_LOCKED_OUT    : out  std_logic;

    -- Status and control port
    STAT_OP            : out std_logic_vector (15 downto 0);
    CTRL_OP            : in  std_logic_vector (15 downto 0);
    STAT_DEBUG         : out std_logic_vector (63 downto 0);
    CTRL_DEBUG         : in  std_logic_vector (63 downto 0)
   );
end entity;

architecture trb_net16_med_sync_gtx2_kintex7_sfp_arch of trb_net16_med_sync_gtx2_kintex7_sfp is

component GTX_trb3_sync_2gb_support
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
    GT0_TX_MMCM_LOCK_OUT                    : out  std_logic;
 
    GT0_TXUSRCLK_OUT                        : out  std_logic;
    GT0_TXUSRCLK2_OUT                       : out  std_logic;
    GT0_TXUSRCLKX2_OUT                      : out  std_logic; --// Modified
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
    ------------------------- Receive Ports - CDR Ports ------------------------
	GT0_RXCDRRESET_IN                       : in  std_logic; --// Modified
    GT0_RXCDRLOCK_OUT                       : out  std_logic; --// Modified
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
     GT0_QPLLOUTCLK_OUT  : out std_logic;
     GT0_QPLLOUTREFCLK_OUT : out std_logic;
        sysclk_in : in std_logic
);
end component;

component DC_data8to16 is
	port ( 
		clock_in                : in std_logic;
		data_in                 : in std_logic_vector(7 downto 0);
		kchar_in                : in std_logic;
		clock_out               : in std_logic;
		data_out                : out std_logic_vector(15 downto 0);
		kchar_out               : out std_logic_vector(1 downto 0)
	);
end component;

component DC_data16to8 is
	port ( 
		clock_in                : in std_logic;
        data_in                 : in std_logic_vector(15 downto 0);
        kchar_in                : in std_logic_vector(1 downto 0);
        notintable_in           : in std_logic_vector(1 downto 0);
        clock_out               : out std_logic;
        data_out                : out std_logic_vector(7 downto 0);
        kchar_out               : out std_logic;
        notintable_out          : out std_logic
	);
end component;

component DC_SODA_clockcrossing is
	port ( 
		write_clock             : in std_logic;
		read_clock              : in std_logic;
		DLM_in                  : in std_logic;
		DLM_WORD_in             : in std_logic_vector(7 downto 0);
		DLM_out                 : out std_logic;
		DLM_WORD_out            : out std_logic_vector(7 downto 0);
		error                   : out std_logic
	);
end component;

component DC_rxBitLock is
	port (
		clk                     : in  std_logic;
		reset                   : in  std_logic;
		resetDone               : in  std_logic;
		lossOfSync              : in  std_logic;
		rxPllLocked             : in  std_logic; 
		rxReset                 : out  std_logic;
		fsmStatus               : out  std_logic_vector (1 downto 0)
	);
end component;

component HUB_8to16_SODA is
	port ( 
		clock                   : in std_logic;
		reset                   : in std_logic;
		data_in                 : in std_logic_vector(7 downto 0);
		char_is_k               : in std_logic;
		fifo_data               : out std_logic_vector(17 downto 0);
		fifo_full               : in std_logic;
		fifo_write              : out std_logic;
		RX_DLM                  : out std_logic;
		RX_DLM_WORD             : out std_logic_vector(7 downto 0);
		error                   : out std_logic
	);
end component;

component HUB_16to8_SODA is
	port ( 
		clock                   : in std_logic;
		reset                   : in std_logic;
		fifo_data               : in std_logic_vector(15 downto 0);
		fifo_empty              : in std_logic;
		fifo_read               : out std_logic;
		TX_DLM                  : in std_logic;
		TX_DLM_WORD             : in std_logic_vector(7 downto 0);
		data_out                : out std_logic_vector(7 downto 0);
		char_is_k               : out std_logic;
		error                   : out std_logic
	);
end component;

component DC_posedge_to_pulse is
	port (
		clock_in                : in  std_logic;
		clock_out               : in  std_logic;
		en_clk                  : in  std_logic;
		signal_in               : in  std_logic;
		pulse                   : out std_logic
	);
end component;

component sync_bit is
	port (
		clock       : in  std_logic;
		data_in     : in  std_logic;
		data_out    : out std_logic
	);
end component;

signal refck2core                   : std_logic;
--serdes connections
signal txData16_S                   : std_logic_vector(15 downto 0);
signal txCharIsK16_S                : std_logic_vector(1 downto 0);
signal rxData16_S                   : std_logic_vector(15 downto 0);
signal rxCharIsK16_S                : std_logic_vector(1 downto 0);
signal rxNotInTable16_S             : std_logic_vector(1 downto 0);
signal rxNotInTable16_q             : std_logic_vector(1 downto 0);
signal txData8_S                    : std_logic_vector(7 downto 0);
signal txCharIsK8_S                 : std_logic;
signal rxData8_S                    : std_logic_vector(7 downto 0);
signal rxCharIsK8_S                 : std_logic;

signal ff_txhalfclk                 : std_logic;
signal ff_txfullclk                 : std_logic;
signal ff_rxhalfclk	                : std_logic;
signal ff_rxfullclk                 : std_logic;
--rx fifo signals
signal fifo_rx_rd_en                : std_logic;
signal fifo_rx_wr_en                : std_logic;
signal fifo_rx_reset                : std_logic;
signal fifo_rx_din                  : std_logic_vector(17 downto 0);
signal fifo_rx_dout                 : std_logic_vector(17 downto 0);
signal fifo_rx_full                 : std_logic;
signal fifo_rx_empty                : std_logic;
--tx fifo signals
signal fifo_tx_rd_en                : std_logic;
signal fifo_tx_wr_en                : std_logic;
signal fifo_tx_reset                : std_logic;
signal fifo_tx_din                  : std_logic_vector(17 downto 0);
signal fifo_tx_dout                 : std_logic_vector(17 downto 0);
signal fifo_tx_full                 : std_logic;
signal fifo_tx_empty                : std_logic;
signal fifo_tx_almost_full          : std_logic;
--rx path
signal rx_counter                   : std_logic_vector(c_NUM_WIDTH-1 downto 0);
signal buf_med_dataready_out        : std_logic;
signal buf_med_data_out             : std_logic_vector(c_DATA_WIDTH-1 downto 0);
signal buf_med_packet_num_out       : std_logic_vector(c_NUM_WIDTH-1 downto 0);
signal last_fifo_rx_empty           : std_logic;
--link status
signal quad_rst                     : std_logic;
signal quad_rst_S                   : std_logic;

signal tx_allow                     : std_logic;
signal rx_allow                     : std_logic;

signal rx_allow_q                   : std_logic; 
signal tx_allow_q                   : std_logic;
signal buf_stat_debug               : std_logic_vector(31 downto 0);

signal sfp_prsnt_n                  : std_logic; -- synchronized input signals
signal sfp_los                      : std_logic; -- synchronized input signals
signal buf_STAT_OP                  : std_logic_vector(15 downto 0);

signal pllLkDet_S                   : std_logic;
signal rxResetBitLock_S             : std_logic :='0';
signal sync_rxResetBitLock_S        : std_logic :='0';
signal prev_rxResetBitLock_S        : std_logic :='0';
signal rxLossOfSync1_S              : std_logic;
signal fsmStatus_S                  : std_logic_vector(1 downto 0);
signal rxPLLwrapper_reset_S         : std_logic :='0';
signal rxResetBitLock_pulse_S       : std_logic :='0';

signal rxReset_S                    : std_logic :='0';
signal resetDone_S                  : std_logic :='0';
signal rxCDRlock_S                  : std_logic :='0';
signal CDR_reset_S                  : std_logic :='0';
signal rxLocked0_S                  : std_logic;
signal rxLocked1_S                  : std_logic;
signal rxLocked2_S                  : std_logic;

signal SODA_DLM_IN_S                : std_logic;
signal SODA_DLM_WORD_IN_S           : std_logic_vector(7 downto 0);

		
signal drpaddr_in_S                 : std_logic_vector(8 downto 0);
signal drpdi_in_S                   : std_logic_vector(15 downto 0);
signal drpdo_out_S                  : std_logic_vector(15 downto 0);
signal drpen_in_S                   : std_logic;
signal drprdy_out_S                 : std_logic;
signal drpwe_in_S                   : std_logic;

signal comma_align_latency_S        : std_logic_vector(6 downto 0);
signal comma_align_latency0_valid_S : std_logic;
signal comma_align_latency_valid_S  : std_logic;
type drp_state_type is (initting, running, reading);
signal drp_state_S                  : drp_state_type := initting;	

signal led_counter                  : unsigned(16 downto 0);
signal rx_led                       : std_logic;
signal tx_led                       : std_logic;

signal reset_word_cnt               : unsigned(4 downto 0);
signal make_trbnet_reset            : std_logic;
signal make_trbnet_reset_q          : std_logic;
signal send_reset_words             : std_logic;
signal send_reset_words_q           : std_logic;
signal send_reset_in                : std_logic;
signal send_reset_in_qtx            : std_logic;
signal reset_i                      : std_logic;
signal reset_i_rx                   : std_logic;
signal pwr_up                       : std_logic;
signal clear_S                      : std_logic;


signal gt0_txfsmresetdone_i         : std_logic;
signal gt0_rxfsmresetdone_i         : std_logic;
signal gt0_txresetdone_i            : std_logic;
signal gt0_txfsmresetdone_q         : std_logic;
signal gt0_rxfsmresetdone_q         : std_logic;
signal gt0_txresetdone_q            : std_logic;

signal link_rx_error_S              : std_logic;
signal link_tx_error_S              : std_logic;
   
   
   
attribute mark_debug : string;
-- attribute mark_debug of txData16_S : signal is "true";
-- attribute mark_debug of txCharIsK16_S : signal is "true";
-- attribute mark_debug of rxNotInTable16_S : signal is "true";
-- attribute mark_debug of rxData16_S : signal is "true";
-- attribute mark_debug of rxCharIsK16_S : signal is "true";

-- attribute mark_debug of txData8_S : signal is "true";
-- attribute mark_debug of txCharIsK8_S : signal is "true";
-- attribute mark_debug of rxData8_S : signal is "true";
-- attribute mark_debug of rxCharIsK8_S : signal is "true";

-- attribute mark_debug of quad_rst : signal is "true";
-- attribute mark_debug of quad_rst_S : signal is "true";
-- attribute mark_debug of rxLocked2_S : signal is "true";
-- attribute mark_debug of sfp_los : signal is "true";
-- attribute mark_debug of tx_allow : signal is "true";
-- attribute mark_debug of rx_allow : signal is "true";
-- attribute mark_debug of link_rx_error_S : signal is "true";
-- attribute mark_debug of link_tx_error_S : signal is "true";

-- attribute mark_debug of fifo_rx_rd_en : signal is "true";
-- attribute mark_debug of fifo_rx_wr_en : signal is "true";
-- attribute mark_debug of fifo_rx_full : signal is "true";
-- attribute mark_debug of fifo_rx_empty : signal is "true";
-- attribute mark_debug of fifo_tx_rd_en : signal is "true";
-- attribute mark_debug of fifo_tx_wr_en : signal is "true";
-- attribute mark_debug of fifo_tx_full : signal is "true";
-- attribute mark_debug of fifo_tx_empty : signal is "true";

-- attribute mark_debug of make_trbnet_reset_q : signal is "true";
-- attribute mark_debug of send_reset_in : signal is "true";
-- attribute mark_debug of reset_i_rx : signal is "true";
-- attribute mark_debug of gt0_rxfsmresetdone_q : signal is "true";
-- attribute mark_debug of gt0_txfsmresetdone_q : signal is "true";
-- attribute mark_debug of gt0_txresetdone_q : signal is "true";

-- attribute mark_debug of pllLkDet_S : signal is "true";
-- attribute mark_debug of CDR_reset_S : signal is "true";
-- attribute mark_debug of rxCDRlock_S : signal is "true";
-- attribute mark_debug of rxReset_S : signal is "true";
-- attribute mark_debug of resetDone_S : signal is "true";
-- attribute mark_debug of rxLossOfSync1_S : signal is "true";
-- attribute mark_debug of rxResetBitLock_S : signal is "true";
-- attribute mark_debug of fsmStatus_S : signal is "true";

-- attribute mark_debug of rxResetBitLock_pulse_S : signal is "true";
-- attribute mark_debug of gt0_txresetdone_i : signal is "true";


	
  begin
  
SODA_CLOCK_OUT <= ff_rxfullclk;
--SODA_LOCKED_OUT <= rxLocked2_S;
SODA_LOCKED_OUT <= '1' when (tx_allow='1') and (rx_allow='1') else '0';
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
    DEPTH => 2,
    WIDTH => 2
    )
  port map(
    RESET    => '0',
    D_IN(0)  => SODA_PRSNT_N_IN,
    D_IN(1)  => SODA_LOS_IN,
    CLK0     => SYSCLK,
    CLK1     => SYSCLK,
    D_OUT(0) => sfp_prsnt_n,
    D_OUT(1) => sfp_los
    );


THE_SENDRESET_SYNC: signal_sync
	generic map(
		DEPTH => 1,
		WIDTH => 1
	)
	port map(
		RESET => reset_i,
		D_IN(0) => send_reset_words,
		CLK0 => SYSCLK,
		CLK1 => SYSCLK,
		D_OUT(0) => send_reset_words_q
	);

THE_RESET_SYNC: DC_posedge_to_pulse 
	port map(
		clock_in => ff_rxhalfclk,
		clock_out => SYSCLK,
		en_clk => '1',
		signal_in => make_trbnet_reset,
		pulse  => make_trbnet_reset_q
	);
	
THE_RX_RESET: signal_sync
  generic map(
    DEPTH => 1,
    WIDTH => 1
    )
  port map(
    RESET    => '0',
    D_IN(0)  => reset_i,
    CLK0     => ff_rxhalfclk,
    CLK1     => ff_rxhalfclk,
    D_OUT(0) => reset_i_rx
    );

-- Delay for ALLOW signals
THE_RX_ALLOW_SYNC: signal_sync
  generic map(
    DEPTH => 2,
    WIDTH => 2
    )
  port map(
    RESET    => '0',
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
    WIDTH => 1
    )
  port map(
    RESET    => '0',
    D_IN(0)  => send_reset_in,
    CLK0     => ff_txfullclk,
    CLK1     => ff_txfullclk,
    D_OUT(0) => send_reset_in_qtx
    );

THE_SFPSIGNALS_SYNC: signal_sync
  generic map(
    DEPTH => 1,
    WIDTH => 3
    )
  port map(
    RESET    => '0',
    D_IN(0)  => gt0_rxfsmresetdone_i,
    D_IN(1)  => gt0_txfsmresetdone_i,
    D_IN(2)  => gt0_txresetdone_i,
    CLK0     => SYSCLK,
    CLK1     => SYSCLK,
    D_OUT(0) => gt0_rxfsmresetdone_q,
    D_OUT(1) => gt0_txfsmresetdone_q,
    D_OUT(2) => gt0_txresetdone_q
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
      SD_LINK_OK_IN     => rxLocked2_S, -- apparently not used
      SD_LOS_IN         => '0', -- apparently not used
      SD_TXCLK_BAD_IN   => link_tx_error_S,
      SD_RXCLK_BAD_IN   => link_rx_error_S,
      SD_RETRY_IN       => '0', -- '0' = handle byte swapping in logic, '1' = simply restart link and hope
      SD_ALIGNMENT_IN	=> "01",
      SD_CV_IN          => rxNotInTable16_q,
      FULL_RESET_OUT    => quad_rst,
      LANE_RESET_OUT    => open, -- apparently not used
      TX_ALLOW_OUT      => tx_allow,
      RX_ALLOW_OUT      => rx_allow,
      SWAP_BYTES_OUT    => open,
      STAT_OP           => buf_stat_op,
      CTRL_OP           => ctrl_op,
      STAT_DEBUG        => buf_stat_debug
      );
SODA_TXDIS_OUT <= quad_rst or reset_i;
link_rx_error_S <= '1' when (gt0_rxfsmresetdone_q='0') or (rxLocked2_S='0') else '0'; -- loss of lock 
link_tx_error_S <= '1' when (gt0_txresetdone_q='0') or (gt0_txfsmresetdone_q='0') else '0';

process(SYSClk,quad_rst)
variable counter_V : std_logic_vector(23 downto 0) := (others => '0');
begin
	if quad_rst='1' then
		quad_rst_S	<= '1';
		counter_V := (others => '0');
	elsif rising_edge(sysClk) then
		quad_rst_S	<= '0';
		if counter_V(counter_V'left)='1' then
			if resetDone_S='0' then
				counter_V := (others => '0');
				quad_rst_S	<= '1';
			end if;
		else
			counter_V := counter_V+1;
		end if;
	end if;
end process;

--------------------------------------------------------------------------
--------------------------------------------------------------------------

-- SerDes clock output to FPGA fabric
REFCLK2CORE_OUT <= ff_rxhalfclk;
CLK_RX_HALF_OUT <= ff_rxhalfclk;
CLK_RX_FULL_OUT <= ff_rxfullclk;

THE_SERDES: GTX_trb3_sync_2gb_support port map
    (
        soft_reset_tx_in => quad_rst_S, -- quad_rst,
        soft_reset_rx_in => quad_rst_S, -- quad_rst,
		DONT_RESET_ON_DATA_ERROR_IN => '1',
		Q2_CLK0_GTREFCLK_PAD_N_IN => SODA_REFCLK_N_IN,
		Q2_CLK0_GTREFCLK_PAD_P_IN => SODA_REFCLK_P_IN,
		GT0_TX_FSM_RESET_DONE_OUT => gt0_txfsmresetdone_i,
		GT0_RX_FSM_RESET_DONE_OUT => gt0_rxfsmresetdone_i,
		GT0_DATA_VALID_IN => '1', -- tx_allow,
		GT0_TX_MMCM_LOCK_OUT => open,
 
		GT0_TXUSRCLK_OUT => open,
		GT0_TXUSRCLK2_OUT => ff_txhalfclk, -- clock for tx_data (100MHz)
		GT0_TXUSRCLKX2_OUT => ff_txfullclk, -- clock for 8 bits data (200MHz)
		GT0_RXUSRCLK_OUT => open,
		GT0_RXUSRCLK2_OUT => ff_rxhalfclk, -- clock for rx_data (100MHz)
        --_____________________________________________________________________
        --_____________________________________________________________________
        --GT0  (X1Y10)
        --------------------------------- CPLL Ports -------------------------------
        gt0_cpllfbclklost_out => open,
        gt0_cplllock_out => pllLkDet_S,
        gt0_cpllreset_in => '0',
        ---------------------------- Channel - DRP Ports  --------------------------
		gt0_drpaddr_in => drpaddr_in_S,
		gt0_drpdi_in => drpdi_in_S,
		gt0_drpdo_out => drpdo_out_S,
		gt0_drpen_in => drpen_in_S,
		gt0_drprdy_out => drprdy_out_S,
		gt0_drpwe_in => drpwe_in_S,
        --------------------------- Digital Monitor Ports --------------------------
        gt0_dmonitorout_out => open,
        --------------------- RX Initialization and Reset Ports --------------------
        gt0_eyescanreset_in => '0',
        gt0_rxuserrdy_in => '0',
        -------------------------- RX Margin Analysis Ports ------------------------
        gt0_eyescandataerror_out => open,
        gt0_eyescantrigger_in => '0',
		------------------------- Receive Ports - CDR Ports ------------------------
 		GT0_RXCDRRESET_IN => CDR_reset_S,
		GT0_RXCDRLOCK_OUT => rxCDRlock_S,
        ------------------ Receive Ports - FPGA RX interface Ports -----------------
        gt0_rxdata_out => rxData16_S,        
        ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
        gt0_rxdisperr_out => open,
        gt0_rxnotintable_out => rxNotInTable16_S,
        --------------------------- Receive Ports - RX AFE -------------------------
        gt0_gtxrxp_in => SODA_RXD_P_IN,
        ------------------------ Receive Ports - RX AFE Ports ----------------------
        gt0_gtxrxn_in => SODA_RXD_N_IN,
        ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
        gt0_rxphmonitor_out => open,
        gt0_rxphslipmonitor_out => open,
        --------------------- Receive Ports - RX Equalizer Ports -------------------
        gt0_rxdfelpmreset_in => '0',
        gt0_rxmonitorout_out => open,
        gt0_rxmonitorsel_in => "00",
        ------------- Receive Ports - RX Initialization and Reset Ports ------------
		gt0_gtrxreset_in => rxReset_S, --// => '0',
		gt0_rxpmareset_in => rxReset_S, --// => '0',
        ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        gt0_rxcharisk_out => rxCharIsK16_S, 
        -------------- Receive Ports -RX Initialization and Reset Ports ------------
        gt0_rxresetdone_out => resetDone_S, 
        --------------------- TX Initialization and Reset Ports --------------------
        gt0_gttxreset_in => '0',
        gt0_txuserrdy_in => '0',
        ------------------ Transmit Ports - TX Data Path interface -----------------
        gt0_txdata_in => txData16_S, 
        ---------------- Transmit Ports - TX Driver and OOB signaling --------------
        gt0_gtxtxn_out => SODA_TXD_N_OUT,
        gt0_gtxtxp_out => SODA_TXD_P_OUT,
        ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        gt0_txoutclkfabric_out => open,
        gt0_txoutclkpcs_out => open,
        --------------------- Transmit Ports - TX Gearbox Ports --------------------
        gt0_txcharisk_in => txCharIsK16_S,     
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

sync_notintable1: DC_posedge_to_pulse port map(
		clock_in => ff_rxhalfclk,
		clock_out => SYSCLK,
		en_clk => '1',
		signal_in => rxNotInTable16_S(0),
		pulse => rxNotInTable16_q(0));
sync_notintable2: DC_posedge_to_pulse port map(
		clock_in => ff_rxhalfclk,
		clock_out => SYSCLK,
		en_clk => '1',
		signal_in => rxNotInTable16_S(1),
		pulse => rxNotInTable16_q(1));


DC_data16to8_1: DC_data16to8 
	port map(
		clock_in => ff_rxhalfclk,
		data_in => rxData16_S,
		kchar_in => rxCharIsK16_S,
		notintable_in => rxNotInTable16_S,
		clock_out => ff_rxfullclk,
		data_out => rxData8_S,
		kchar_out => rxCharIsK8_S,
		notintable_out => open
	);

THE_FIFO_SFP_TO_FPGA: trb_net_fifo_16bit_bram_dualport
	generic map(
		USE_STATUS_FLAGS => c_NO
	)
	port map( read_clock_in  => SYSCLK,
		write_clock_in     => ff_rxfullclk,
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
HUB_8to16_SODA1: HUB_8to16_SODA
	port map(
		clock => ff_rxfullclk,
		reset => fifo_rx_reset,
		data_in => rxData8_S,
		char_is_k => rxCharIsK8_S,
		fifo_data => fifo_rx_din,
		fifo_full  => fifo_rx_full,
		fifo_write => fifo_rx_wr_en,
		RX_DLM => SODA_DLM_OUT,
		RX_DLM_WORD => SODA_DLM_WORD_OUT,
		error => open
	);
  	
buf_med_data_out          <= fifo_rx_dout(15 downto 0);
buf_med_dataready_out     <= not fifo_rx_dout(17) and not fifo_rx_dout(16) and not last_fifo_rx_empty and rx_allow_q;
buf_med_packet_num_out    <= rx_counter;
med_read_out              <= tx_allow_q and not fifo_tx_almost_full;

THE_CNT_RESET_PROC : process(ff_rxhalfclk)
begin
	if rising_edge(ff_rxhalfclk) then
		if reset_i_rx = '1' then
			send_reset_words  <= '0';
			make_trbnet_reset <= '0';
			reset_word_cnt <= (others => '0');
		else
			send_reset_words   <= '0';
			make_trbnet_reset  <= '0';
			if (rxCharIsK16_S="11") and (rxData16_S=x"FEFE") then
				if reset_word_cnt(4) = '0' then
					reset_word_cnt <= reset_word_cnt + 1;
				else
					send_reset_words <= '1';
				end if;
			else
				reset_word_cnt <= (others => '0');
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
THE_RX_PACKETS_PROC: process(SYSCLK)
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
					rx_counter <= rx_counter + 1;
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
	port map( 
		read_clock_in => ff_txfullclk,
		write_clock_in => SYSCLK,
		read_enable_in => fifo_tx_rd_en,
		write_enable_in => fifo_tx_wr_en,
		fifo_gsr_in => fifo_tx_reset,
		write_data_in => fifo_tx_din,
		read_data_out => fifo_tx_dout,
		full_out => open,
		empty_out => fifo_tx_empty,
		almost_full_out   => fifo_tx_almost_full
	);

fifo_tx_reset <= reset_i or not tx_allow_q;
fifo_tx_din   <= med_packet_num_in(2) & med_packet_num_in(0)& med_data_in;
fifo_tx_wr_en <= med_dataready_in and tx_allow_q;
 
HUB_16to8_SODA1: HUB_16to8_SODA
	port map(
		clock => ff_txfullclk,
		reset => send_reset_in_qtx,
		fifo_data => fifo_tx_dout(15 downto 0),
		fifo_empty => fifo_tx_empty,
		fifo_read => fifo_tx_rd_en,
		TX_DLM => SODA_DLM_IN_S,
		TX_DLM_WORD => SODA_DLM_WORD_IN_S,
		data_out => txData8_S,
		char_is_k => txCharIsK8_S,
		error => open
	);

DC_SODA_clockcrossing1: DC_SODA_clockcrossing
	port map(
		write_clock => ff_rxfullclk,
		read_clock => ff_txfullclk,
		DLM_in => SODA_DLM_IN,
		DLM_WORD_in => SODA_DLM_WORD_IN,
		DLM_out => SODA_DLM_IN_S,
		DLM_WORD_out => SODA_DLM_WORD_IN_S,
		error => open
	);
		
DC_data8to16_1: DC_data8to16
	port map( 
		clock_in => ff_txfullclk,
		data_in => txData8_S,
		kchar_in => txCharIsK8_S,
		clock_out => ff_txhalfclk,
		data_out => txData16_S,
		kchar_out => txCharIsK16_S
	);  
  
rxLossOfSync1_S <= '0' when (rxNotInTable16_S="00") or (disable_GTX_reset='1') else '1';
DC_rxBitLock1 : DC_rxBitLock port map (
		clk => ff_rxhalfclk,
		reset => quad_rst,
		resetDone => resetDone_S,
		lossOfSync => rxLossOfSync1_S,
		rxPllLocked => PllLkDet_S,
		rxReset => rxResetBitLock_S,
		fsmStatus => fsmStatus_S
	);
	

rxReset_S <= '1' when ((rxPLLwrapper_reset_S='1') or (quad_rst='1') or (rxResetBitLock_pulse_S='1')) and (disable_GTX_reset='0') else '0';

rxLocked0_S <= '1' when (resetDone_S='1') and (fsmStatus_S = "10") else '0';
sync_rx_locked: sync_bit port map(
	clock => SYSCLK,
	data_in => rxLocked0_S,
	data_out => rxLocked1_S);

process(SYSCLK) 
begin
	if rising_edge(SYSCLK) then
		if (sync_rxResetBitLock_S='1') and (prev_rxResetBitLock_S='0') then
			rxResetBitLock_pulse_S <= '1';
		else	
			rxResetBitLock_pulse_S <= '0';
		end if;
		sync_rxResetBitLock_S <= rxResetBitLock_S;
		prev_rxResetBitLock_S <= sync_rxResetBitLock_S;
	end if;
end process;
process(SYSCLK) 
variable counter_V : std_logic_vector(5 downto 0) := (others => '0');
variable timoutcounter_V : std_logic_vector(11 downto 0) := (others => '0');
begin
	if rising_edge(SYSCLK) then
		rxPLLwrapper_reset_S <= '0';
		CDR_reset_S <= '0';
		comma_align_latency0_valid_S <= '0';
		drpen_in_S <= '0';
		drpwe_in_S <= '0';
		drpdi_in_S <= (others => '0');
		case drp_state_S is
			when initting =>
				rxLocked2_S	<= '0';
				counter_V := (others => '0');
				if resetDone_S='1' then
					drp_state_S <= running;
				end if;
			when running =>
				if rxLocked1_S='0' then
					drp_state_S <= initting;
				else
					if counter_V(counter_V'left) = '1' then
						counter_V := (others => '0');
						timoutcounter_V := (others => '0');
						drpen_in_S <= '1';
						drpaddr_in_S <= "101001110"; -- x"14E";
						drp_state_S <= reading;
					else
						counter_V := counter_V+1;
					end if;
				end if;
			when reading =>
				if drprdy_out_S='1' then
					comma_align_latency_S <= drpdo_out_S(6 downto 0); --		COMMA_ALIGN_LATENCY
					comma_align_latency0_valid_S <= '1';
					if drpdo_out_S(6 downto 0)/="0000000" then
						CDR_reset_S <= '1'; --// rxPLLwrapper_reset_S <= '1';
						rxLocked2_S	<= '0';
					else 
						rxLocked2_S	<= '1';
					end if;
					drp_state_S <= running;
				elsif timoutcounter_V(timoutcounter_V'left)='1' then
					CDR_reset_S <= '1';
					rxPLLwrapper_reset_S <= '1';
					drp_state_S <= initting;
				else
					timoutcounter_V := timoutcounter_V+1;
				end if;
			when others =>
				drp_state_S <= initting;
		end case;
	end if;
end process;



--Generate LED signals
----------------------
process(SYSCLK)
begin
	if rising_edge(SYSCLK) then
		led_counter <= led_counter + 1;
		if buf_med_dataready_out = '1' then
			rx_led <= '1';
		elsif led_counter = 0 then
			rx_led <= '0';
		end if;
		if fifo_tx_wr_en = '1' then
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
stat_debug(15 downto 0)  <= rxData16_S;
stat_debug(17 downto 16) <= rxCharIsK16_S;
stat_debug(19 downto 18) <= (others => '0');
stat_debug(23 downto 20) <= buf_stat_debug(3 downto 0);
stat_debug(24)           <= fifo_rx_rd_en;
stat_debug(25)           <= fifo_rx_wr_en;
stat_debug(26)           <= fifo_rx_reset;
stat_debug(27)           <= fifo_rx_empty;
stat_debug(28)           <= fifo_rx_full;
stat_debug(29)           <= '0';
stat_debug(30)           <= rx_allow_q;
stat_debug(41 downto 31) <= (others => '0');
stat_debug(42)           <= SYSCLK;
stat_debug(43)           <= SYSCLK;
stat_debug(59 downto 44) <= (others => '0');
stat_debug(63 downto 60) <= buf_stat_debug(3 downto 0);

end architecture;