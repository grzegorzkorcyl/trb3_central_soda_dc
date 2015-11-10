----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   18-07-2013
-- Module Name:   serdesQuadMUXwrapper
-- Description:   Module with a quad serdes with synchronized transmit frequency and 16 bits bus
-- Modifications:
--   29-08-2014   ADCCLOCKFREQUENCY added: SODA clock at 80MHz 
--   27-01-2015   SCI interface removed
--   29-02-2015   txUsrClkDiv2 removed
----------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

----------------------------------------------------------------------------------
-- serdesQuadMUXwrapper
-- Quad serdes tranceiver for PANDA Front End Electronics and Multiplexer with synchronised transmitted data.
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
--     refClk_P : differential input pad for Reference clock for GTP/GTX, if internal clock cannot be used (Xilinx)
--     refClk_N : differential input pad for Reference clock for GTP/GTX, if internal clock cannot be used (Xilinx)
--     sysClk : Local bus system clock for serdes control interface and LEDs
--     gtpReset : reset serdes
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
--   GT0_QPLLOUTCLK_IN : unused input to be compatible with Xilinx version
--   GT0_QPLLOUTREFCLK_IN : unused input to be compatible with Xilinx version
-- 
-- Outputs:
--     refClkOut : reference clock output
--     refClk_OK : indicates if refClkOut is stable (PLL locked) (always 1 for Lattice serdes)
--   For channel0 in quad serdes  :
--     G0_rxData : Data received, clocked with G0_rxUsrClk
--     G0_txP,G0_txN : differential transmit outputs of the serdes
--     G0_rxUsrClk : clock for received data
--     G0_resetDone : Resetting is finished
--     G0_rxLocked : Receiver is locked to incomming data
--     G0_rxNotInTable : Error in received data
--     G0_txLocked : Transmitter is locked to reference clock (synchronous with SODA)
--     G0_rxCharIsK0 : received data is K-character
--     G1_rxData : Data received, clocked with G1_rxUsrClk
--     G1_txP,G0_txN : differential transmit outputs of the serdes
--     G1_rxUsrClk : clock for received data
--     G1_resetDone : Resetting is finished
--     G1_rxLocked : Receiver is locked to incomming data
--     G1_rxNotInTable : Error in received data
--     G1_txLocked : Transmitter is locked to reference clock (synchronous with SODA)
--     G1_rxCharIsK0 : received data is K-character
--     G2_rxData : Data received, clocked with G2_rxUsrClk
--     G2_txP,G0_txN : differential transmit outputs of the serdes
--     G2_rxUsrClk : clock for received data
--     G2_resetDone : Resetting is finished
--     G2_rxLocked : Receiver is locked to incomming data
--     G2_rxNotInTable : Error in received data
--     G2_txLocked : Transmitter is locked to reference clock (synchronous with SODA)
--     G2_rxCharIsK0 : received data is K-character
--     G3_rxData : Data received, clocked with G3_rxUsrClk
--     G3_txP,G0_txN : differential transmit outputs of the serdes
--     G3_rxUsrClk : clock for received data
--     G3_resetDone : Resetting is finished
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
--     med_ecp3_quad_sfp_sync : module with the quad serdes interface
--
----------------------------------------------------------------------------------

entity serdesQuadMUXwrapper is 
	port ( 	
		refClk                  : in  std_logic := '0';
		refClk_P                : in  std_logic := '0';
		refClk_N                : in  std_logic := '1';
		sysClk                  : in  std_logic;
		gtpReset                : in  std_logic;
		
		refClkOut               : out std_logic;
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
		G0_resetDone            : out  std_logic;
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
		G1_resetDone            : out  std_logic;
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
		G2_resetDone            : out  std_logic;
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
		G3_resetDone            : out  std_logic;
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
		testword0               : out std_logic_vector (35 downto 0); 
		testword0clock          : out std_logic
		);
end serdesQuadMUXwrapper;

architecture Behavioral of serdesQuadMUXwrapper is

component med_ecp3_quad_sfp_sync is
  port(
		CLOCK              : in  std_logic; -- serdes reference clock
		SYSCLK             : in  std_logic; -- 100 MHz main clock net
		RESET              : in  std_logic; -- synchronous reset
		CLEAR              : in  std_logic; -- asynchronous reset

		TX_DATA0           : in std_logic_vector(7 downto 0); -- clock on CLOCK
		TX_DATA1           : in std_logic_vector(7 downto 0);      
		TX_DATA2           : in std_logic_vector(7 downto 0);      
		TX_DATA3           : in std_logic_vector(7 downto 0);	
		TX_CHAR_K0         : in std_logic;
		TX_CHAR_K1         : in std_logic;
		TX_CHAR_K2         : in std_logic;
		TX_CHAR_K3         : in std_logic;
		TX_CLOCK0          : out std_logic;
		TX_CLOCK1          : out std_logic;
		TX_CLOCK2          : out std_logic;
		TX_CLOCK3          : out std_logic;
		RX_DATA0           : out std_logic_vector(7 downto 0); -- clock on CLOCK
		RX_DATA1           : out std_logic_vector(7 downto 0);      
		RX_DATA2           : out std_logic_vector(7 downto 0);      
		RX_DATA3           : out std_logic_vector(7 downto 0);	
		RX_CHAR_K0         : out std_logic;
		RX_CHAR_K1         : out std_logic;
		RX_CHAR_K2         : out std_logic;
		RX_CHAR_K3         : out std_logic;
		RX_ERROR0          : out std_logic;
		RX_ERROR1          : out std_logic;
		RX_ERROR2          : out std_logic;
		RX_ERROR3          : out std_logic;
		RX_CLOCK0          : out std_logic;
		RX_CLOCK1          : out std_logic;
		RX_CLOCK2          : out std_logic;
		RX_CLOCK3          : out std_logic;

		--SFP Connection
		SD_RXD_P_IN        : in std_logic_vector(0 to 3);
		SD_RXD_N_IN        : in std_logic_vector(0 to 3);
		SD_TXD_P_OUT       : out std_logic_vector(0 to 3);
		SD_TXD_N_OUT       : out std_logic_vector(0 to 3);
		SD_LOS_IN          : in std_logic_vector(0 to 3);  -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
		SD_TXDIS_OUT       : out std_logic_vector(0 to 3); -- SFP disable

		-- Status and control port
		RESET_DONE         : out std_logic_vector (0 to 3);
		RX_ALLOW           : out std_logic_vector (0 to 3);
		TX_ALLOW           : out std_logic_vector (0 to 3);
		LEDs_link_ok       : out std_logic_vector(0 to 3);
		LEDs_rx            : out std_logic_vector(0 to 3); 
		LEDs_tx            : out std_logic_vector(0 to 3);
		STAT_OP            : out std_logic_vector (15 downto 0);
		CTRL_OP            : in  std_logic_vector (15 downto 0) := (others => '0')
   );
end component;

signal tx_allow_i      : std_logic_vector (0 to 3);
signal rx_allow_i      : std_logic_vector (0 to 3);

signal rxUsrClk_i      : std_logic_vector (0 to 3);

	
begin

refClkOut <= refClk;
refClk_OK <= '1';

med_ecp3_quad_sfp_sync1: med_ecp3_quad_sfp_sync port map(
    CLOCK => refClk,
    SYSCLK => sysClk,
    RESET => gtpReset,
    CLEAR => gtpReset,
		
    TX_DATA0 => G0_txData,
    TX_DATA1 => G1_txData,
    TX_DATA2 => G2_txData,  
    TX_DATA3 => G3_txData,  
    TX_CHAR_K0 => G0_txCharIsK0,
    TX_CHAR_K1 => G1_txCharIsK0,
    TX_CHAR_K2 => G2_txCharIsK0,
    TX_CHAR_K3 => G3_txCharIsK0,
	TX_CLOCK0 => txpll_clocks(0),
	TX_CLOCK1 => txpll_clocks(1),
	TX_CLOCK2 => txpll_clocks(2),
	TX_CLOCK3 => txpll_clocks(3),
    RX_DATA0 => G0_rxData,
    RX_DATA1 => G1_rxData,   
    RX_DATA2 => G2_rxData,    
    RX_DATA3 => G3_rxData,
    RX_CHAR_K0 => G0_rxCharIsK0,
    RX_CHAR_K1 => G1_rxCharIsK0,
    RX_CHAR_K2 => G2_rxCharIsK0,
    RX_CHAR_K3 => G3_rxCharIsK0,
    RX_ERROR0 => G0_rxNotInTable,
    RX_ERROR1 => G1_rxNotInTable,
    RX_ERROR2 => G2_rxNotInTable,
    RX_ERROR3 => G3_rxNotInTable,
	RX_CLOCK0 => G0_rxUsrClk,
	RX_CLOCK1 => G1_rxUsrClk,
	RX_CLOCK2 => G2_rxUsrClk,
	RX_CLOCK3 => G3_rxUsrClk,

    --SFP Connection
    SD_RXD_P_IN(0) => G0_rxP,
    SD_RXD_P_IN(1) => G1_rxP,
    SD_RXD_P_IN(2) => G2_rxP,
    SD_RXD_P_IN(3) => G3_rxP,
    SD_RXD_N_IN(0) => G0_rxN,
    SD_RXD_N_IN(1) => G1_rxN,
    SD_RXD_N_IN(2) => G2_rxN,
    SD_RXD_N_IN(3) => G3_rxN,
	
    SD_TXD_P_OUT(0) => G0_txP,
    SD_TXD_P_OUT(1) => G1_txP,
    SD_TXD_P_OUT(2) => G2_txP,
    SD_TXD_P_OUT(3) => G3_txP,
    SD_TXD_N_OUT(0) => G0_txN,
    SD_TXD_N_OUT(1) => G1_txN,
    SD_TXD_N_OUT(2) => G2_txN,
    SD_TXD_N_OUT(3) => G3_txN,
	
    SD_LOS_IN(0) => G0_LOS,
    SD_LOS_IN(1) => G1_LOS,
    SD_LOS_IN(2) => G2_LOS,
    SD_LOS_IN(3) => G3_LOS,
	SD_TXDIS_OUT => open,
	
    -- Status and control port
	RESET_DONE(0) => G0_resetDone,
	RESET_DONE(1) => G1_resetDone,
	RESET_DONE(2) => G2_resetDone,
	RESET_DONE(3) => G3_resetDone,
	RX_ALLOW => rx_allow_i,
	TX_ALLOW => tx_allow_i,
	LEDs_link_ok => LEDs_link_ok,
	LEDs_rx => LEDs_rx,
	LEDs_tx => LEDs_tx,
    STAT_OP => open,
    CTRL_OP => x"0000"
   );


G0_rxLocked <= '1' when rx_allow_i(0)='1' else '0';
G1_rxLocked <= '1' when rx_allow_i(1)='1' else '0';
G2_rxLocked <= '1' when rx_allow_i(2)='1' else '0';
G3_rxLocked <= '1' when rx_allow_i(3)='1' else '0';
G0_txLocked <= '1' when tx_allow_i(0)='1' else '0';
G1_txLocked <= '1' when tx_allow_i(1)='1' else '0';
G2_txLocked <= '1' when tx_allow_i(2)='1' else '0';
G3_txLocked <= '1' when tx_allow_i(3)='1' else '0';

testword0clock <= rxUsrClk_i(0);
testword0 <= (others => '0');
		
end Behavioral;



