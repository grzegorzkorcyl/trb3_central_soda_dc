----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   18-07-2013
-- Module Name:   serdesQuadMUXwrapper
-- Description:   Module with a quad serdes/GTX with synchronized transmit frequency and 16 bits bus
-- Modifications:
--   29-08-2014   ADCCLOCKFREQUENCY added: SODA clock at 80MHz 
--   27-01-2015   SCI interface removed
--   29-02-2015   txUsrClkDiv2 removed
--   04-05-2015   version for Kintex7
--   26-05-2015   version with only two fibers
----------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

----------------------------------------------------------------------------------
-- serdesQuadMUXwrapper
-- Quad serdes/GTX tranceiver for PANDA Front End Electronics and Multiplexer with synchronised transmitted data.
--
--
--
--
-- Library
--     work.gtpBufLayer : for GTP/GTX constants
--
-- Generics:
-- 
-- Inputs:
--     refClk : Reference clock for the serdes, synchronous with transmitted data
--     refClk_P : differential input pad for Reference clock for GTP/GTX, if internal clock cannot be used (Xilinx), now used for one of the reference clocks
--     refClk_N : differential input pad for Reference clock for GTP/GTX, if internal clock cannot be used (Xilinx), now used for one of the reference clocks
--     sysClk : Local bus system clock for serdes control interface and LEDs
--     gtpReset : reset serdes
--     refClkIn : reference clock from other part of QUAD, for common GTX module
--     txUsrClk : clock for the synchronous data to be transmitted, SODA clock
--   For channel0 in quad serdes :
--     G0_txData : transmit data, clocked with refClk that is synchrouous with SODA
--     G0_rxP,G0_rxN :  differential input to the serdes
--     G0_LOS : no fiber signal detected
--     G0_txCharIsK0 : data is K-character
--   For channel1 in quad serdes :
--     G1_txData : transmit data, clocked with refClk that is synchrouous with SODA
--     G1_rxP,G0_rxN :  differential input to the serdes
--     G1_LOS : no fiber signal detected
--     G1_txCharIsK0 : data is K-character
--   For channel2 in quad serdes :
--     G2_txData : transmit data, clocked with refClk that is synchrouous with SODA
--     G2_rxP,G0_rxN :  differential input to the serdes
--     G2_LOS : no fiber signal detected
--     G2_txCharIsK0 : data is K-character
--   For channel3 in quad serdes :
--     G3_txData : transmit data, clocked with refClk that is synchrouous with SODA
--     G3_rxP,G0_rxN :  differential input to the serdes
--     G3_LOS : no fiber signal detected
--     G3_txCharIsK0 : data is K-character
--   GT0_QPLLOUTCLK_IN : QPLL reference clock, needed for Xilinx
--   GT0_QPLLOUTREFCLK_IN : QPLL reference clock, needed for Xilinx
-- 
-- Outputs:
--     refClkOut : reference clock output
--     refClk_OK : indicates if refClkOut is stable (PLL locked) (always 1 for Lattice serdes)
--     txpll_clocks : clock used at GTX transmitter
--   For channel0 in quad serdes  :
--     G0_rxData : Data received, clocked with G0_rxUsrClk
--     G0_txP,G0_txN : differential transmit outputs of the serdes
--     G0_rxUsrClk : clock for received data
--     G0_rxLocked : Receiver is locked to incomming data
--     G0_rxNotInTable : Error in received data
--     G0_txLocked : Transmitter is locked to reference clock (synchronous with SODA)
--     G0_rxCharIsK0 : received data is K-character
--   For channel1 in quad serdes :
--     G1_rxData : Data received, clocked with G1_rxUsrClk
--     G1_txP,G0_txN : differential transmit outputs of the serdes
--     G1_rxUsrClk : clock for received data
--     G1_rxLocked : Receiver is locked to incomming data
--     G1_rxNotInTable : Error in received data
--     G1_txLocked : Transmitter is locked to reference clock (synchronous with SODA)
--     G1_rxCharIsK0 : received data is K-character
--   For channel2 in quad serdes :
--     G2_rxData : Data received, clocked with G2_rxUsrClk
--     G2_txP,G0_txN : differential transmit outputs of the serdes
--     G2_rxUsrClk : clock for received data
--     G2_rxLocked : Receiver is locked to incomming data
--     G2_rxNotInTable : Error in received data
--     G2_txLocked : Transmitter is locked to reference clock (synchronous with SODA)
--     G2_rxCharIsK0 : received data is K-character
--   For channel3 in quad serdes :
--     G3_rxData : Data received, clocked with G3_rxUsrClk
--     G3_txP,G0_txN : differential transmit outputs of the serdes
--     G3_rxUsrClk : clock for received data
--     G3_rxLocked : Receiver is locked to incomming data
--     G3_rxNotInTable : Error in received data
--     G3_txLocked : Transmitter is locked to reference clock (synchronous with SODA)
--     G3_rxCharIsK0 : received data is K-character
--     LEDs_link_ok : serdes status for LED on extension board : link ok
--     LEDs_rx : serdes status for LED on extension board : receive
--     LEDs_tx : serdes status for LED on extension board : transmit
-- 
-- 
-- Components:
--     GTX_quadSODA_support : wrapper module for GTX, produced by IP core generator
--     DC_data8to16 : data from 8 bits to 16 bits on half clock speed
--     DC_data16to8 : data from 16 bits to 8 bits on double clock speed
--     clock100to200 : clock doubler : 100MHz to 200MHz
--     sync_bit : Synchronization for 1 bit cross clock signal
--
----------------------------------------------------------------------------------

entity serdesQuadMUXwrapper is 
	port ( 	
		refClk                  : in  std_logic;
		refClk_P                : in  std_logic := '0';
		refClk_N                : in  std_logic := '1';
		sysClk                  : in  std_logic;
		gtpReset                : in  std_logic;
		
		refClk_OK               : out std_logic;
		txpll_clocks            : out std_logic_vector(3 downto 0);
		
		G0_txData               : in  std_logic_vector (7 downto 0);
		G0_rxData               : out  std_logic_vector (7 downto 0);
		G0_txP                  : out  std_logic;
		G0_txN                  : out  std_logic;
		G0_rxP                  : in  std_logic;
		G0_rxN                  : in  std_logic;
		G0_LOS                  : in std_logic;
		G0_rxUsrClk             : out  std_logic; -- 200MHz
		G0_rxLocked             : out  std_logic;
		G0_rxNotInTable         : out  std_logic;
		G0_txLocked             : out  std_logic;
		G0_txCharIsK0           : in  std_logic;
		G0_rxCharIsK0           : out  std_logic;

		G1_txData               : in  std_logic_vector (7 downto 0);
		G1_rxData               : out  std_logic_vector (7 downto 0);
		G1_txP                  : out  std_logic;
		G1_txN                  : out  std_logic;
		G1_rxP                  : in  std_logic;
		G1_rxN                  : in  std_logic;
		G1_LOS                  : in std_logic;
		G1_rxUsrClk             : out  std_logic; -- 200MHz
		G1_rxLocked             : out  std_logic;
		G1_rxNotInTable         : out  std_logic;
		G1_txLocked             : out  std_logic;
		G1_txCharIsK0           : in  std_logic;
		G1_rxCharIsK0           : out  std_logic;
		
		G2_txData               : in  std_logic_vector (7 downto 0);
		G2_rxData               : out  std_logic_vector (7 downto 0);
		G2_txP                  : out  std_logic;
		G2_txN                  : out  std_logic;
		G2_rxP                  : in  std_logic;
		G2_rxN                  : in  std_logic;
		G2_LOS                  : in std_logic;
		G2_rxUsrClk             : out  std_logic; -- 200MHz
		G2_rxLocked             : out  std_logic;
		G2_rxNotInTable         : out  std_logic;
		G2_txLocked             : out  std_logic;
		G2_txCharIsK0           : in  std_logic;
		G2_rxCharIsK0           : out  std_logic;		
		
		G3_txData               : in  std_logic_vector (7 downto 0);
		G3_rxData               : out  std_logic_vector (7 downto 0);
		G3_txP                  : out  std_logic;
		G3_txN                  : out  std_logic;
		G3_rxP                  : in  std_logic;
		G3_rxN                  : in  std_logic;
		G3_LOS                  : in std_logic;
		G3_rxUsrClk             : out  std_logic; -- 200MHz
		G3_rxLocked             : out  std_logic;
		G3_rxNotInTable         : out  std_logic;
		G3_txLocked             : out  std_logic;
		G3_txCharIsK0           : in  std_logic;
		G3_rxCharIsK0           : out  std_logic;
		
		LEDs_link_ok            : out std_logic_vector(0 to 3);
		LEDs_rx                 : out std_logic_vector(0 to 3); 
		LEDs_tx                 : out std_logic_vector(0 to 3);

		GT0_QPLLOUTCLK_IN       : in std_logic := '0';
		GT0_QPLLOUTREFCLK_IN    : in std_logic := '0';
		testword0               : out std_logic_vector (35 downto 0) := (others => '0'); 
		testword0clock          : out std_logic := '0'
		);
end serdesQuadMUXwrapper;

architecture Behavioral of serdesQuadMUXwrapper is
		
component GTX_dualSODA_support
generic
(
    -- Simulation attributes
    EXAMPLE_SIM_GTRESET_SPEEDUP    : string    := "FALSE";    -- Set to TRUE to speed up sim reset
    STABLE_CLOCK_PERIOD            : integer   := 16 
);
port
(
    SOFT_RESET_TX_IN                        : in   std_logic;
    SOFT_RESET_RX_IN                        : in   std_logic;
    DONT_RESET_ON_DATA_ERROR_IN             : in   std_logic;
    Q2_CLK1_GTREFCLK_PAD_N_IN               : in   std_logic;
    Q2_CLK1_GTREFCLK_PAD_P_IN               : in   std_logic;

    GT0_TX_FSM_RESET_DONE_OUT               : out  std_logic;
    GT0_RX_FSM_RESET_DONE_OUT               : out  std_logic;
    GT0_DATA_VALID_IN                       : in   std_logic;
    GT1_TX_FSM_RESET_DONE_OUT               : out  std_logic;
    GT1_RX_FSM_RESET_DONE_OUT               : out  std_logic;
    GT1_DATA_VALID_IN                       : in   std_logic;
 
    GT0_TXUSRCLK_OUT                        : out  std_logic;
    GT0_TXUSRCLK2_OUT                       : out  std_logic;
    GT0_RXUSRCLK_OUT                        : out  std_logic;
    GT0_RXUSRCLK2_OUT                       : out  std_logic;
 
    GT1_TXUSRCLK_OUT                        : out  std_logic;
    GT1_TXUSRCLK2_OUT                       : out  std_logic;
    GT1_RXUSRCLK_OUT                        : out  std_logic;
    GT1_RXUSRCLK2_OUT                       : out  std_logic;

    --_________________________________________________________________________
        --GT0  (X1Y12)
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
   
    --_________________________________________________________________________
        --GT1  (X1Y13)
    --____________________________CHANNEL PORTS________________________________
    --------------------------------- CPLL Ports -------------------------------
    gt1_cpllfbclklost_out                   : out  std_logic;
    gt1_cplllock_out                        : out  std_logic;
    gt1_cpllreset_in                        : in   std_logic;
    ---------------------------- Channel - DRP Ports  --------------------------
    gt1_drpaddr_in                          : in   std_logic_vector(8 downto 0);
    gt1_drpdi_in                            : in   std_logic_vector(15 downto 0);
    gt1_drpdo_out                           : out  std_logic_vector(15 downto 0);
    gt1_drpen_in                            : in   std_logic;
    gt1_drprdy_out                          : out  std_logic;
    gt1_drpwe_in                            : in   std_logic;
    --------------------------- Digital Monitor Ports --------------------------
    gt1_dmonitorout_out                     : out  std_logic_vector(7 downto 0);
    --------------------- RX Initialization and Reset Ports --------------------
    gt1_eyescanreset_in                     : in   std_logic;
    gt1_rxuserrdy_in                        : in   std_logic;
    -------------------------- RX Margin Analysis Ports ------------------------
    gt1_eyescandataerror_out                : out  std_logic;
    gt1_eyescantrigger_in                   : in   std_logic;
    ------------------ Receive Ports - FPGA RX interface Ports -----------------
    gt1_rxdata_out                          : out  std_logic_vector(15 downto 0);
    ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
    gt1_rxdisperr_out                       : out  std_logic_vector(1 downto 0);
    gt1_rxnotintable_out                    : out  std_logic_vector(1 downto 0);
    --------------------------- Receive Ports - RX AFE -------------------------
    gt1_gtxrxp_in                           : in   std_logic;
    ------------------------ Receive Ports - RX AFE Ports ----------------------
    gt1_gtxrxn_in                           : in   std_logic;
    ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
    gt1_rxphmonitor_out                     : out  std_logic_vector(4 downto 0);
    gt1_rxphslipmonitor_out                 : out  std_logic_vector(4 downto 0);
    --------------------- Receive Ports - RX Equalizer Ports -------------------
    gt1_rxdfelpmreset_in                    : in   std_logic;
    gt1_rxmonitorout_out                    : out  std_logic_vector(6 downto 0);
    gt1_rxmonitorsel_in                     : in   std_logic_vector(1 downto 0);
    ------------- Receive Ports - RX Initialization and Reset Ports ------------
    gt1_gtrxreset_in                        : in   std_logic;
    gt1_rxpmareset_in                       : in   std_logic;
    ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    gt1_rxcharisk_out                       : out  std_logic_vector(1 downto 0);
    -------------- Receive Ports -RX Initialization and Reset Ports ------------
    gt1_rxresetdone_out                     : out  std_logic;
    --------------------- TX Initialization and Reset Ports --------------------
    gt1_gttxreset_in                        : in   std_logic;
    gt1_txuserrdy_in                        : in   std_logic;
    ------------------ Transmit Ports - TX Data Path interface -----------------
    gt1_txdata_in                           : in   std_logic_vector(15 downto 0);
    ---------------- Transmit Ports - TX Driver and OOB signaling --------------
    gt1_gtxtxn_out                          : out  std_logic;
    gt1_gtxtxp_out                          : out  std_logic;
    ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    gt1_txoutclkfabric_out                  : out  std_logic;
    gt1_txoutclkpcs_out                     : out  std_logic;
    --------------------- Transmit Ports - TX Gearbox Ports --------------------
    gt1_txcharisk_in                        : in   std_logic_vector(1 downto 0);
    ------------- Transmit Ports - TX Initialization and Reset Ports -----------
    gt1_txresetdone_out                     : out  std_logic;
   

    --____________________________COMMON PORTS________________________________
     GT0_QPLLOUTCLK_IN  : in std_logic;
     GT0_QPLLOUTREFCLK_IN : in std_logic;
		sysclk_in        : in std_logic;
		q2_clk1_gtrefclk : in std_logic;  --//modification
		q3_clk0_gtrefclk : in std_logic   --//modification
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

component clock100to200 is
	port
	(
		clk_in1                 : in std_logic;
		clk_out1                : out std_logic;
		reset                   : in std_logic;
		locked                  : out std_logic
	);
end component;

component sync_bit is
	port (
		clock       : in  std_logic;
		data_in     : in  std_logic;
		data_out    : out std_logic
	);
end component;

    constant DLY : time := 1 ns;
signal      gt0_txusrclkX2_i                        : std_logic;

signal      gt0_txusrclk2_i                         : std_logic;
signal      gt1_txusrclk2_i                         : std_logic;
signal      gt2_txusrclk2_i                         : std_logic;
signal      gt3_txusrclk2_i                         : std_logic;
signal      gt0_rxusrclk2_i                         : std_logic;
signal      gt1_rxusrclk2_i                         : std_logic;
signal      gt2_rxusrclk2_i                         : std_logic;
signal      gt3_rxusrclk2_i                         : std_logic;

signal      gt0_txdata_i                            : std_logic_vector(15 downto 0);
signal      gt1_txdata_i                            : std_logic_vector(15 downto 0);
signal      gt2_txdata_i                            : std_logic_vector(15 downto 0);
signal      gt3_txdata_i                            : std_logic_vector(15 downto 0);
signal      gt0_txcharisk_i                         : std_logic_vector(1 downto 0);
signal      gt1_txcharisk_i                         : std_logic_vector(1 downto 0);
signal      gt2_txcharisk_i                         : std_logic_vector(1 downto 0);
signal      gt3_txcharisk_i                         : std_logic_vector(1 downto 0);

signal      gt0_rxdata_i                            : std_logic_vector(15 downto 0);
signal      gt1_rxdata_i                            : std_logic_vector(15 downto 0);
signal      gt2_rxdata_i                            : std_logic_vector(15 downto 0);
signal      gt3_rxdata_i                            : std_logic_vector(15 downto 0);
signal      gt0_rxnotintable_i                      : std_logic_vector(1 downto 0);
signal      gt1_rxnotintable_i                      : std_logic_vector(1 downto 0);
signal      gt2_rxnotintable_i                      : std_logic_vector(1 downto 0);
signal      gt3_rxnotintable_i                      : std_logic_vector(1 downto 0);
signal      gt0_rxcharisk_i                         : std_logic_vector(1 downto 0);
signal      gt1_rxcharisk_i                         : std_logic_vector(1 downto 0);
signal      gt2_rxcharisk_i                         : std_logic_vector(1 downto 0);
signal      gt3_rxcharisk_i                         : std_logic_vector(1 downto 0);

signal      gt0_gtrxreset_i                         : std_logic;
signal      gt1_gtrxreset_i                         : std_logic;
signal      gt2_gtrxreset_i                         : std_logic;
signal      gt3_gtrxreset_i                         : std_logic;
signal      gt0_gttxreset_i                         : std_logic;
signal      gt1_gttxreset_i                         : std_logic;
signal      gt2_gttxreset_i                         : std_logic;
signal      gt3_gttxreset_i                         : std_logic;
signal      gt0_txresetdone_i                       : std_logic;
signal      gt1_txresetdone_i                       : std_logic;
signal      gt2_txresetdone_i                       : std_logic;
signal      gt3_txresetdone_i                       : std_logic;
	
signal      gt0_rxresetdone_i                       : std_logic;
signal      gt1_rxresetdone_i                       : std_logic;
signal      gt2_rxresetdone_i                       : std_logic;
signal      gt3_rxresetdone_i                       : std_logic;

	
--************************** Register Declarations ****************************
attribute   ASYNC_REG                               : string;
signal      gt_txfsmresetdone_i                     : std_logic;
signal      gt_txfsmresetdone_r                     : std_logic;
signal      gt_txfsmresetdone_r2                    : std_logic;
attribute   ASYNC_REG of gt_txfsmresetdone_r        : signal is "TRUE";
attribute   ASYNC_REG of gt_txfsmresetdone_r2       : signal is "TRUE";
signal      gt0_txfsmresetdone_i                    : std_logic;
signal      gt0_txfsmresetdone_r                    : std_logic;
signal      gt0_txfsmresetdone_r2                   : std_logic;
attribute   ASYNC_REG of gt0_txfsmresetdone_r       : signal is "TRUE";
attribute   ASYNC_REG of gt0_txfsmresetdone_r2      : signal is "TRUE";
signal      gt0_rxresetdone_r                       : std_logic;
signal      gt0_rxresetdone_r2                      : std_logic;
signal      gt0_rxresetdone_r3                      : std_logic;
attribute   ASYNC_REG of gt0_rxresetdone_r          : signal is "TRUE";
attribute   ASYNC_REG of gt0_rxresetdone_r2         : signal is "TRUE";
attribute   ASYNC_REG of gt0_rxresetdone_r3         : signal is "TRUE";
signal      gt1_txfsmresetdone_i                    : std_logic;
signal      gt1_txfsmresetdone_r                    : std_logic;
signal      gt1_txfsmresetdone_r2                   : std_logic;
attribute   ASYNC_REG of gt1_txfsmresetdone_r       : signal is "TRUE";
attribute   ASYNC_REG of gt1_txfsmresetdone_r2      : signal is "TRUE";
signal      gt1_rxresetdone_r                       : std_logic;
signal      gt1_rxresetdone_r2                      : std_logic;
signal      gt1_rxresetdone_r3                      : std_logic;
attribute   ASYNC_REG of gt1_rxresetdone_r          : signal is "TRUE";
attribute   ASYNC_REG of gt1_rxresetdone_r2         : signal is "TRUE";
attribute   ASYNC_REG of gt1_rxresetdone_r3         : signal is "TRUE";


       begin
G2_rxData <= (others => '0');
G2_txP <= '0';
G2_txN <= '0';
G2_rxUsrClk <= '0';
G2_rxLocked <= '0';
G2_rxNotInTable <= '0';
G2_txLocked <= '0';
G2_rxCharIsK0 <= '0';


G3_rxData <= (others => '0');
G3_txP <= '0';
G3_txN <= '0';
G3_rxUsrClk <= '0';
G3_rxLocked <= '0';
G3_rxNotInTable <= '0';
G3_txLocked <= '0';
G3_rxCharIsK0 <= '0';

		
txpll_clocks(0) <= gt0_txusrclkX2_i;
txpll_clocks(1) <= gt0_txusrclkX2_i;
txpll_clocks(2) <= gt0_txusrclkX2_i;
txpll_clocks(3) <= gt0_txusrclkX2_i;

clock100to200a: clock100to200 port map(
		clk_in1 => gt0_txusrclk2_i,
		clk_out1 => gt0_txusrclkX2_i,
		reset => '0',
		locked => open);


DC_data8to16_0: DC_data8to16 port map(
		clock_in => gt0_txusrclkX2_i,
		data_in => G0_txData,
		kchar_in => G0_txCharIsK0,
		clock_out => gt0_txusrclk2_i,
		data_out => gt0_txdata_i,
		kchar_out => gt0_txcharisk_i);
DC_data8to16_1: DC_data8to16 port map(
		clock_in => gt0_txusrclkX2_i,
		data_in => G1_txData,
		kchar_in => G1_txCharIsK0,
		clock_out => gt0_txusrclk2_i,
		data_out => gt1_txdata_i,
		kchar_out => gt1_txcharisk_i);

		
DC_data16to8_0: DC_data16to8 port map(
		clock_in => gt0_rxusrclk2_i,
		data_in => gt0_rxdata_i,
		kchar_in => gt0_rxcharisk_i,
		notintable_in => gt0_rxnotintable_i,
		clock_out => G0_rxUsrClk,
		data_out => G0_rxData,
		kchar_out => G0_rxCharIsK0,
		notintable_out => G0_rxNotInTable);
DC_data16to8_1: DC_data16to8 port map(
		clock_in => gt1_rxusrclk2_i,
		data_in => gt1_rxdata_i,
		kchar_in => gt1_rxcharisk_i,
		notintable_in => gt1_rxnotintable_i,
		clock_out => G1_rxUsrClk,
		data_out => G1_rxData,
		kchar_out => G1_rxCharIsK0,
		notintable_out => G1_rxNotInTable);

GTX_dualSODA_support1: GTX_dualSODA_support port map(
	SOFT_RESET_TX_IN => gtpReset,
	SOFT_RESET_RX_IN => gtpReset,
	DONT_RESET_ON_DATA_ERROR_IN => '0',
	Q2_CLK1_GTREFCLK_PAD_N_IN => '0', -- not used, IBUFDS_GTE2 buffer is at top level
	Q2_CLK1_GTREFCLK_PAD_P_IN => '0', -- not used, IBUFDS_GTE2 buffer is at top level
	
	GT0_TX_FSM_RESET_DONE_OUT => gt0_txfsmresetdone_i,
	GT0_RX_FSM_RESET_DONE_OUT => open,
	GT0_DATA_VALID_IN => '1',
	GT1_TX_FSM_RESET_DONE_OUT => gt1_txfsmresetdone_i,
	GT1_RX_FSM_RESET_DONE_OUT => open,
	GT1_DATA_VALID_IN => '1',
 
    GT0_TXUSRCLK_OUT => open,
    GT0_TXUSRCLK2_OUT => gt0_txusrclk2_i,
    GT0_RXUSRCLK_OUT => open,
    GT0_RXUSRCLK2_OUT => gt0_rxusrclk2_i,
 
    GT1_TXUSRCLK_OUT => open,
    GT1_TXUSRCLK2_OUT => gt1_txusrclk2_i,
    GT1_RXUSRCLK_OUT => open,
    GT1_RXUSRCLK2_OUT => gt1_rxusrclk2_i,
 
	--_____________________________________________________________________
	--_____________________________________________________________________
	--GT0  (X1Y12)

	--------------------------------- CPLL Ports -------------------------------
	gt0_cpllfbclklost_out => open,
	gt0_cplllock_out => refClk_OK,
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
	gt0_rxdata_out => gt0_rxdata_i,
	------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
	gt0_rxdisperr_out => open,
	gt0_rxnotintable_out => gt0_rxnotintable_i,
	--------------------------- Receive Ports - RX AFE -------------------------
	gt0_gtxrxp_in => G0_rxP,
	------------------------ Receive Ports - RX AFE Ports ----------------------
	gt0_gtxrxn_in => G0_rxN,
	------------------- Receive Ports - RX Buffer Bypass Ports -----------------
	gt0_rxphmonitor_out => open,
	gt0_rxphslipmonitor_out => open,
	--------------------- Receive Ports - RX Equalizer Ports -------------------
	gt0_rxdfelpmreset_in => '0',
	gt0_rxmonitorout_out => open,
	gt0_rxmonitorsel_in => "00",
	------------- Receive Ports - RX Initialization and Reset Ports ------------
	gt0_gtrxreset_in => gt0_gtrxreset_i,
	gt0_rxpmareset_in => '0',
	------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
	gt0_rxcharisk_out => gt0_rxcharisk_i,
	-------------- Receive Ports -RX Initialization and Reset Ports ------------
	gt0_rxresetdone_out => gt0_rxresetdone_i,
	--------------------- TX Initialization and Reset Ports --------------------
	gt0_gttxreset_in => gt0_gttxreset_i,
	gt0_txuserrdy_in => '0',
	------------------ Transmit Ports - TX Data Path interface -----------------
	gt0_txdata_in => gt0_txdata_i,
	---------------- Transmit Ports - TX Driver and OOB signaling --------------
	gt0_gtxtxn_out => G0_txN,
	gt0_gtxtxp_out => G0_txP,
	----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
	gt0_txoutclkfabric_out => testword0(35),
	gt0_txoutclkpcs_out => testword0(34),
	--------------------- Transmit Ports - TX Gearbox Ports --------------------
	gt0_txcharisk_in => gt0_txcharisk_i,
	------------- Transmit Ports - TX Initialization and Reset Ports -----------
	gt0_txresetdone_out => gt0_txresetdone_i,
	
	--_____________________________________________________________________
	--_____________________________________________________________________
	--GT1  (X1Y13)

	--------------------------------- CPLL Ports -------------------------------
	gt1_cpllfbclklost_out => open,
	gt1_cplllock_out => open,
	gt1_cpllreset_in => '0',
	---------------------------- Channel - DRP Ports  --------------------------
	gt1_drpaddr_in => (others => '0'),
	gt1_drpdi_in => (others => '0'),
	gt1_drpdo_out => open,
	gt1_drpen_in => '0',
	gt1_drprdy_out => open,
	gt1_drpwe_in => '0',
	--------------------------- Digital Monitor Ports --------------------------
	gt1_dmonitorout_out => open,
	--------------------- RX Initialization and Reset Ports --------------------
	gt1_eyescanreset_in => '0',
	gt1_rxuserrdy_in => '0',
	-------------------------- RX Margin Analysis Ports ------------------------
	gt1_eyescandataerror_out => open,
	gt1_eyescantrigger_in => '0',
	------------------ Receive Ports - FPGA RX interface Ports -----------------
	gt1_rxdata_out => gt1_rxdata_i,
	------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
	gt1_rxdisperr_out => open,
	gt1_rxnotintable_out => gt1_rxnotintable_i,
	--------------------------- Receive Ports - RX AFE -------------------------
	gt1_gtxrxp_in => G1_rxP,
	------------------------ Receive Ports - RX AFE Ports ----------------------
	gt1_gtxrxn_in => G1_rxN,
	------------------- Receive Ports - RX Buffer Bypass Ports -----------------
	gt1_rxphmonitor_out => open,
	gt1_rxphslipmonitor_out => open,
	--------------------- Receive Ports - RX Equalizer Ports -------------------
	gt1_rxdfelpmreset_in => '0',
	gt1_rxmonitorout_out => open,
	gt1_rxmonitorsel_in => "00",
	------------- Receive Ports - RX Initialization and Reset Ports ------------
	gt1_gtrxreset_in => gt1_gtrxreset_i,
	gt1_rxpmareset_in => '0',
	------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
	gt1_rxcharisk_out => gt1_rxcharisk_i,
	-------------- Receive Ports -RX Initialization and Reset Ports ------------
	gt1_rxresetdone_out => gt1_rxresetdone_i,
	--------------------- TX Initialization and Reset Ports --------------------
	gt1_gttxreset_in => gt1_gttxreset_i,
	gt1_txuserrdy_in => '0',
	------------------ Transmit Ports - TX Data Path interface -----------------
	gt1_txdata_in => gt1_txdata_i,
	---------------- Transmit Ports - TX Driver and OOB signaling --------------
	gt1_gtxtxn_out => G1_txN,
	gt1_gtxtxp_out => G1_txP,
	----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
	gt1_txoutclkfabric_out => open,
	gt1_txoutclkpcs_out => open,
	--------------------- Transmit Ports - TX Gearbox Ports --------------------
	gt1_txcharisk_in => gt1_txcharisk_i,
	------------- Transmit Ports - TX Initialization and Reset Ports -----------
	gt1_txresetdone_out => gt1_txresetdone_i,
    --____________________________COMMON PORTS________________________________
	GT0_QPLLOUTCLK_IN  => GT0_QPLLOUTCLK_IN,
	GT0_QPLLOUTREFCLK_IN => GT0_QPLLOUTREFCLK_IN,
	sysclk_in => sysClk,
	q2_clk1_gtrefclk => refClk_P,  --//modification
	q3_clk0_gtrefclk => refClk_N  --//modification
    );

    -------------------------- User Module Resets -----------------------------
    -- All the User Modules are held in reset till the RESETDONE goes high. 
    -- The RESETDONE is registered a couple of times on USRCLK2 and connected 
    -- to the reset of the modules
    
process(gt0_rxusrclk2_i,gt0_rxresetdone_i,G0_LOS)
    begin
        if(gt0_rxresetdone_i = '0') or (G0_LOS='1') then
            gt0_rxresetdone_r  <= '0'   after DLY;
            gt0_rxresetdone_r2 <= '0'   after DLY;
            gt0_rxresetdone_r3 <= '0'   after DLY;
elsif (gt0_rxusrclk2_i'event and gt0_rxusrclk2_i = '1') then
            gt0_rxresetdone_r  <= gt0_rxresetdone_i   after DLY;
            gt0_rxresetdone_r2 <= gt0_rxresetdone_r   after DLY;
            gt0_rxresetdone_r3  <= gt0_rxresetdone_r2   after DLY;
        end if;
    end process;
process(gt0_txusrclk2_i,gt0_txfsmresetdone_i,gt0_txresetdone_i)
    begin
        if(gt0_txfsmresetdone_i = '0') or (gt0_txresetdone_i='0')  then
            gt0_txfsmresetdone_r  <= '0'   after DLY;
            gt0_txfsmresetdone_r2 <= '0'   after DLY;
elsif (gt0_txusrclk2_i'event and gt0_txusrclk2_i = '1') then
            gt0_txfsmresetdone_r  <= gt0_txfsmresetdone_i   after DLY;
            gt0_txfsmresetdone_r2 <= gt0_txfsmresetdone_r   after DLY;
        end if;
    end process;
	
process(gt1_rxusrclk2_i,gt1_rxresetdone_i,G1_LOS)
    begin
        if(gt1_rxresetdone_i = '0') or (G1_LOS='1') then
            gt1_rxresetdone_r  <= '0'   after DLY;
            gt1_rxresetdone_r2 <= '0'   after DLY;
            gt1_rxresetdone_r3 <= '0'   after DLY;
elsif (gt1_rxusrclk2_i'event and gt1_rxusrclk2_i = '1') then
            gt1_rxresetdone_r  <= gt1_rxresetdone_i   after DLY;
            gt1_rxresetdone_r2 <= gt1_rxresetdone_r   after DLY;
            gt1_rxresetdone_r3  <= gt1_rxresetdone_r2   after DLY;
        end if;
    end process;
process(gt1_txusrclk2_i,gt1_txfsmresetdone_i,gt1_txresetdone_i)
    begin
        if(gt1_txfsmresetdone_i = '0') or (gt1_txresetdone_i='0')  then
            gt1_txfsmresetdone_r  <= '0'   after DLY;
            gt1_txfsmresetdone_r2 <= '0'   after DLY;
elsif (gt1_txusrclk2_i'event and gt1_txusrclk2_i = '1') then
            gt1_txfsmresetdone_r  <= gt1_txfsmresetdone_i   after DLY;
            gt1_txfsmresetdone_r2 <= gt1_txfsmresetdone_r   after DLY;
        end if;
    end process;
	

G0_rxLocked <= gt0_rxresetdone_r3;
G1_rxLocked <= gt1_rxresetdone_r3;

G0_rxLocked <= gt0_rxresetdone_r3;
G0_txLocked <= gt0_txfsmresetdone_r2;
G1_txLocked <= gt1_txfsmresetdone_r2;


gt0_gtrxreset_i <= '1' when (G0_LOS='1') or (gtpReset='1') else '0';
gt1_gtrxreset_i <= '1' when (G1_LOS='1') or (gtpReset='1') else '0';

gt0_gttxreset_i <= '1' when (G0_LOS='1') or (gtpReset='1') else '0';
gt1_gttxreset_i <= '1' when (G1_LOS='1') or (gtpReset='1') else '0';


LEDs_link_ok(0)  <= '1' when (gt0_rxresetdone_r3='1') and (gt0_txfsmresetdone_r2='1') else '0';
LEDs_link_ok(1)  <= '1' when (gt0_rxresetdone_r3='1') and (gt1_txfsmresetdone_r2='1') else '0';
LEDs_link_ok(2)  <= '0';
LEDs_link_ok(3)  <= '0';

LEDs_rx <= (others => '0');
LEDs_tx <= (others => '0');

			
end Behavioral;



