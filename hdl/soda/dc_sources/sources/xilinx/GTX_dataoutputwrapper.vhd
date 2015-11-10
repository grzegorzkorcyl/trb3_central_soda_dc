----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   10-06-2015
-- Module Name:   GTX_dataoutputwrapper
-- Description:   GTX data output module : 1Gbit/s
-- Modifications:
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;
library UNISIM;
use UNISIM.VComponents.all;

----------------------------------------------------------------------------------
-- GTX_dataoutputwrapper
-- GTX data output module : 1Gbit/s
--
-- Library
-- 
-- Generics:
-- 
-- Inputs:
--     clock_in : input clock
--     data_in : 8 bits input data
--     kchar_in : corresponding k-character
-- 
-- Outputs:
--     clock_out : output clock at half speed
--     data_out : 16 bits output data at half speed
--     kchar_out : corresponding k-character (one for each byte)
-- 
-- Components:
--
----------------------------------------------------------------------------------

entity GTX_dataoutputwrapper is
	port ( 
		sysClk                  : in std_logic;
		refClk_P                : in std_logic;
		refClk_N                : in std_logic;
		clock_out               : out std_logic;
		reset                   : in std_logic;
		data_in                 : in std_logic_vector(15 downto 0);
		kchar_in                : in std_logic_vector(1 downto 0);
		G0_txP                  : out  std_logic;
		G0_txN                  : out  std_logic;
		G0_rxP                  : in  std_logic;
		G0_rxN                  : in  std_logic;
		G0_LOS                  : in std_logic;
		tx_locked               : out std_logic;
		GT0_QPLLOUTCLK_IN       : in std_logic; 
		GT0_QPLLOUTREFCLK_IN    : in std_logic
	);
end GTX_dataoutputwrapper;

architecture Behavioral of GTX_dataoutputwrapper is

component GTX_dataoutput_support
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
    Q3_CLK0_GTREFCLK_PAD_N_IN               : in   std_logic;
    Q3_CLK0_GTREFCLK_PAD_P_IN               : in   std_logic;

    GT0_TX_FSM_RESET_DONE_OUT               : out  std_logic;
    GT0_RX_FSM_RESET_DONE_OUT               : out  std_logic;
    GT0_DATA_VALID_IN                       : in   std_logic;
    GT0_TX_MMCM_LOCK_OUT                    : out  std_logic;
 
    GT0_TXUSRCLK_OUT                        : out  std_logic;
    GT0_TXUSRCLK2_OUT                       : out  std_logic;
    GT0_RXUSRCLK_OUT                        : out  std_logic;
    GT0_RXUSRCLK2_OUT                       : out  std_logic;

    --_________________________________________________________________________
        --GT0  (X1Y14)
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
     GT0_QPLLOUTCLK_IN  : in std_logic;  --//modification
     GT0_QPLLOUTREFCLK_IN : in std_logic;  --//modification
        sysclk_in : in std_logic;
	q2_clk1_gtrefclk : in std_logic;  --//modification
	q3_clk0_gtrefclk : in std_logic  --//modification
);
end component;


signal gt0_txusrclk2_i          : std_logic;
signal gt0_rxusrclk2_i          : std_logic;
signal gt0_txdata_i             : std_logic_vector(15 downto 0);
signal gt0_txcharisk_i          : std_logic_vector(1 downto 0);

--***********************************Parameter Declarations********************

    constant DLY : time := 1 ns;
    -------------- Receive Ports -RX Initialization and Reset Ports ------------
    signal  gt0_rxresetdone_i               : std_logic;
    ------------- Transmit Ports - TX Initialization and Reset Ports -----------
    signal  gt0_txresetdone_i               : std_logic;

--************************** Register Declarations ****************************
attribute ASYNC_REG                        : string;
    signal   gt_txfsmresetdone_i             : std_logic;
signal   gt_rxfsmresetdone_i             : std_logic;
    signal   gt_txfsmresetdone_r             : std_logic;
    signal   gt_txfsmresetdone_r2            : std_logic;
attribute ASYNC_REG of gt_txfsmresetdone_r     : signal is "TRUE";
attribute ASYNC_REG of gt_txfsmresetdone_r2     : signal is "TRUE";

    signal   gt0_txfsmresetdone_i            : std_logic;
signal   gt0_rxfsmresetdone_i            : std_logic;
    signal   gt0_txfsmresetdone_r            : std_logic;
    signal   gt0_txfsmresetdone_r2           : std_logic;
attribute ASYNC_REG of gt0_txfsmresetdone_r     : signal is "TRUE";
attribute ASYNC_REG of gt0_txfsmresetdone_r2     : signal is "TRUE";
signal   gt0_rxresetdone_r               : std_logic;
signal   gt0_rxresetdone_r2              : std_logic;
signal   gt0_rxresetdone_r3              : std_logic;
attribute ASYNC_REG of gt0_rxresetdone_r     : signal is "TRUE";
attribute ASYNC_REG of gt0_rxresetdone_r2     : signal is "TRUE";
attribute ASYNC_REG of gt0_rxresetdone_r3     : signal is "TRUE";

attribute mark_debug : string;
-- attribute mark_debug of gt0_txdata_i : signal is "true";
-- attribute mark_debug of gt0_txcharisk_i : signal is "true";
-- attribute mark_debug of gt0_txfsmresetdone_i : signal is "true";
-- attribute mark_debug of gt0_txfsmresetdone_r2 : signal is "true";
-- attribute mark_debug of gt_txfsmresetdone_r2 : signal is "true";

begin

clock_out <= gt0_txusrclk2_i;
gt0_txdata_i <= data_in;
gt0_txcharisk_i <= kchar_in;
		
    ----------------------------- The GT Wrapper -----------------------------
    
    -- Use the instantiation template in the example directory to add the GT wrapper to your design.
    -- In this example, the wrapper is wired up for basic operation with a frame generator and frame 
    -- checker. The GTs will reset, then attempt to align and transmit data. If channel bonding is 
    -- enabled, bonding should occur after alignment.

    
    GTX_dataoutput_support_i : GTX_dataoutput_support
    port map
    (
	SOFT_RESET_TX_IN => reset,
	SOFT_RESET_RX_IN => reset,
	DONT_RESET_ON_DATA_ERROR_IN => '0',
    Q3_CLK0_GTREFCLK_PAD_N_IN => '0', --// Modified, not used
    Q3_CLK0_GTREFCLK_PAD_P_IN => '0', --// Modified, not used
	GT0_TX_MMCM_LOCK_OUT => open,
	GT0_TX_FSM_RESET_DONE_OUT => gt0_txfsmresetdone_i,
	GT0_RX_FSM_RESET_DONE_OUT => gt0_rxfsmresetdone_i,
	GT0_DATA_VALID_IN => '1',
 
    GT0_TXUSRCLK_OUT => open,
    GT0_TXUSRCLK2_OUT => gt0_txusrclk2_i,
    GT0_RXUSRCLK_OUT => open,
    GT0_RXUSRCLK2_OUT => gt0_rxusrclk2_i,

 

        --_____________________________________________________________________
        --_____________________________________________________________________
        --GT0  (X1Y14)

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
        gt0_rxdata_out => open,
        ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
        gt0_rxdisperr_out => open,
        gt0_rxnotintable_out => open,
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
        gt0_gtrxreset_in => '0',
        gt0_rxpmareset_in => '0',
        ------------------- Receive Ports - RX8B/10B Decoder Ports -----------------
        gt0_rxcharisk_out => open,
        -------------- Receive Ports -RX Initialization and Reset Ports ------------
        gt0_rxresetdone_out => gt0_rxresetdone_i,
        --------------------- TX Initialization and Reset Ports --------------------
        gt0_gttxreset_in => '0',
        gt0_txuserrdy_in => '0',
        ------------------ Transmit Ports - TX Data Path interface -----------------
        gt0_txdata_in => gt0_txdata_i,
        ---------------- Transmit Ports - TX Driver and OOB signaling --------------
        gt0_gtxtxn_out => G0_txN,
        gt0_gtxtxp_out => G0_txP,
        ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
        gt0_txoutclkfabric_out => open,
        gt0_txoutclkpcs_out => open,
        --------------------- Transmit Ports - TX Gearbox Ports --------------------
        gt0_txcharisk_in => gt0_txcharisk_i,
        ------------- Transmit Ports - TX Initialization and Reset Ports -----------
        gt0_txresetdone_out => gt0_txresetdone_i,



    --____________________________COMMON PORTS________________________________
     GT0_QPLLOUTCLK_IN  => GT0_QPLLOUTCLK_IN,  --//modification
     GT0_QPLLOUTREFCLK_IN => GT0_QPLLOUTREFCLK_IN,  --//modification
         sysclk_in => sysClk,
	q2_clk1_gtrefclk => refClk_P,  --//modification
	q3_clk0_gtrefclk => refClk_N  --//modification
    );

	
    -------------------------- User Module Resets -----------------------------
    -- All the User Modules i.e. FRAME_GEN, FRAME_CHECK and the sync modules
    -- are held in reset till the RESETDONE goes high. 
    -- The RESETDONE is registered a couple of times on USRCLK2 and connected 
    -- to the reset of the modules
    
process(gt0_rxusrclk2_i,gt0_rxresetdone_i)
    begin
        if(gt0_rxresetdone_i = '0') then
            gt0_rxresetdone_r  <= '0'   after DLY;
            gt0_rxresetdone_r2 <= '0'   after DLY;
            gt0_rxresetdone_r3 <= '0'   after DLY;
elsif (gt0_rxusrclk2_i'event and gt0_rxusrclk2_i = '1') then
            gt0_rxresetdone_r  <= gt0_rxresetdone_i   after DLY;
            gt0_rxresetdone_r2 <= gt0_rxresetdone_r   after DLY;
            gt0_rxresetdone_r3  <= gt0_rxresetdone_r2   after DLY;
        end if;
    end process;

process(gt0_txusrclk2_i,gt0_txfsmresetdone_i)
    begin
        if(gt0_txfsmresetdone_i = '0') then
            gt0_txfsmresetdone_r  <= '0'   after DLY;
            gt0_txfsmresetdone_r2 <= '0'   after DLY;
elsif (gt0_txusrclk2_i'event and gt0_txusrclk2_i = '1') then
            gt0_txfsmresetdone_r  <= gt0_txfsmresetdone_i   after DLY;
            gt0_txfsmresetdone_r2 <= gt0_txfsmresetdone_r   after DLY;
        end if;
    end process;

tx_locked <= '1' when (gt0_txfsmresetdone_r2='1') and (gt0_txresetdone_i='1') else '0';

end Behavioral;
