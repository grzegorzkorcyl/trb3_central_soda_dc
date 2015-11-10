----------------------------------------------------------------------------------
-- Company: KVI/RUG/Groningen University
-- Engineer: Peter Schakel
-- Create Date:   05-02-2015
-- Module Name:   DC_SODAserdesWrapper
-- Description: GTP/GTX tranceiver for PANDA Front End Electronics on Kintex7 with clock synchronization
-- Modifications:
--   05-02-2015   Originally FEE_gtxWrapper_Virtex6
--   05-02-2015   Originally FEE_gtxWrapper_Kintex7
----------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;
library work;
use work.panda_package.all;
library UNISIM;
use UNISIM.VComponents.all;

----------------------------------------------------------------------------------
-- DC_SODAserdesWrapper
-- GTP/GTX tranceiver for PANDA Front End Electronics and Multiplexer with clock synchronization on a Virtex5.
--
-- Receiver makes recovered synchronous clock on incomming serial data (SODA). 
-- Data is 16-bits, synchronous to recovered clock.
-- Transmitter sends 16-bits data.
--
-- Only one channel of the dual GTP or GTX is used.
--
-- Library
--     work.gtpBufLayer : for GTP/GTX constants
--
-- Generics:
-- 
-- Inputs:
--     refClk : Reference clock for GTP/GTX, frequency must match expected SODA frequency 
--     refClk_P : Reference clock for GTP/GTX in case of differential input pins, frequency must match expected SODA frequency 
--     refClk_N : Reference clock for GTP/GTX in case of differential input pins, frequency must match expected SODA frequency 
--     sysClk : stable clock (80MHz)
--     asyncclk : clock for synchronous resetting
--     gtpReset : reset GTP/GTX
--     disable_GTX_reset : disable ressetting temporarely
--     txData : 16-bits input data to transmit
--     txCharIsK : data to transmit are K-characters
--     rxP,rxN : differential transmit inputs from the GTP/GTX
-- 
-- Outputs:
--     txP,txN : differential transmit outputs of the GTP/GTX
--     txUsrClk : clock for transmit data
--     txLocked :  transmitter locked
--     rxData : 16-bits received data
--     rxCharIsK : received 16-bits data (2 bytes) are K-characters
--     rxNotInTable : receiver data not valid
--     rxUsrClk : Recovered synchronous clock
--     rxLocked : receiver locked to incoming data
--     GT0_QPLLOUTCLK_OUT : QPLL reference clock, needed for Xilinx
--     GT0_QPLLOUTREFCLK_OUT : QPLL reference clock, needed for Xilinx
--     resetDone : resetting ready
-- 
-- Components:
--     GTXVIRTEX5FEE : Xilinx module for GTP or GTX, generated with the IP core generator with a few adjustments
--     FEE_rxBitLock : Module for checking and resetting the GTP/GTX to lock the receiver clock at the right phase
--     Clock_62M5_doubler : Clock doubler with PLL
--
----------------------------------------------------------------------------------

entity DC_SODAserdesWrapper is
	port (
		refClk                : in  std_logic;	
		refClk_P              : in  std_logic;	
		refClk_N              : in  std_logic;	
		sysClk                : in  std_logic;	
		asyncclk              : in  std_logic;
		gtpReset              : in  std_logic;
		disable_GTX_reset     : in  std_logic;
		
		txData                : in  std_logic_vector (7 downto 0);
		txCharIsK             : in  std_logic;
		txP                   : out  std_logic;
		txN                   : out  std_logic;
		txUsrClk              : out  std_logic;
		txLocked              : out  std_logic;
		
		rxData                : out  std_logic_vector (7 downto 0);
		rxCharIsK             : out  std_logic;
		rxNotInTable          : out  std_logic;
		rxP                   : in  std_logic;
		rxN                   : in  std_logic;
		rxUsrClk              : out std_logic;
		rxUsrClkdiv2          : out std_logic;
		rxLocked              : out  std_logic;
		
		GT0_QPLLOUTCLK_OUT    : out std_logic := '0';
		GT0_QPLLOUTREFCLK_OUT : out std_logic := '0';
		resetDone             : out  std_logic
	);
end DC_SODAserdesWrapper;

architecture Behavioral of DC_SODAserdesWrapper is

component GTX_SODAinput_support
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
    GT0_TXUSRCLKX2_OUT                      : out  std_logic; --// Modified
    GT0_RXUSRCLK_OUT                        : out  std_logic;
    GT0_RXUSRCLK2_OUT                       : out  std_logic;

    --_________________________________________________________________________
        --GT0  (X1Y15)
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
		GT0_QPLLOUTCLK_OUT    : out std_logic := '0';
		GT0_QPLLOUTREFCLK_OUT : out std_logic := '0';
        sysclk_in : in std_logic;
	   q2_clk1_gtrefclk : in std_logic;  --//modification
	   q3_clk0_gtrefclk : in std_logic  --//modification
);
end component;


component clock100to200 is
	port
	(
		clk_in1                 : in std_logic;
		clk_out1                : out std_logic;
		clk_out2                : out std_logic;
		reset                   : in std_logic;
		locked                  : out std_logic
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

signal gtpReset_S          : std_logic;
signal txReset_S           : std_logic;
signal txResetdone_S       : std_logic;
signal txUsrClkx2_S        : std_logic; -- tx clock at double tx speed

signal gtx0_txresetdone_r  : std_logic;
signal gtx0_txresetdone_r2 : std_logic;
signal txLocked_S          : std_logic;
signal txOutClk_S          : std_logic :='0';
signal txUsrClk_buf_S      : std_logic :='0';
signal txData16_S          : std_logic_vector(15 downto 0);
signal txCharIsK16_S       : std_logic_vector(1 downto 0);
signal txmmcm_lock_S       : std_logic;
signal txmmcm_reset_S      : std_logic;


signal rxRecClk_S          : std_logic :='0';
signal rxReset_S           : std_logic :='0';
signal rxData_S            : std_logic_vector(7 downto 0);
signal rxCharIsK_S         : std_logic;
signal rxNotInTable_S      : std_logic;
signal rxData16_S          : std_logic_vector(15 downto 0);
signal rxCharIsK16_S       : std_logic_vector(1 downto 0);
signal rxNotInTable16_S    : std_logic_vector(1 downto 0);
signal rxDispError16_S     : std_logic_vector(1 downto 0);
signal rxLocked0_S         : std_logic;
signal rxLocked1_S         : std_logic;
signal rxLocked2_S         : std_logic;
signal rxResetBitLock_S    : std_logic :='0';
signal sync_rxResetBitLock_S : std_logic :='0';
signal prev_rxResetBitLock_S : std_logic :='0';
signal rxLossOfSync1_S     : std_logic;
signal fsmStatus_S         : std_logic_vector(1 downto 0);
signal rxPLLwrapper_reset_S : std_logic :='0';
signal rxResetBitLock_pulse_S : std_logic :='0';

signal rxphmonitor_S       : std_logic_vector(4 downto 0);
signal rxphslipmonitor_S   : std_logic_vector(4 downto 0);

signal pllLkDet_S          : std_logic :='0';
signal resetDone_S         : std_logic :='0';

signal eyescandataerror_S  : std_logic :='0';
signal rxCDRlock_S         : std_logic :='0';
signal CDR_reset_S         : std_logic :='0';

signal drpaddr_in_S        : std_logic_vector(8 downto 0);
signal drpdi_in_S          : std_logic_vector(15 downto 0);
signal drpdo_out_S         : std_logic_vector(15 downto 0);
signal drpen_in_S          : std_logic;
signal drprdy_out_S        : std_logic;
signal drpwe_in_S          : std_logic;

signal comma_align_latency_S        : std_logic_vector(6 downto 0);
signal comma_align_latency0_valid_S : std_logic;
signal comma_align_latency_valid_S  : std_logic;


type drp_state_type is (initting, running, reading);
signal drp_state_S : drp_state_type := initting;	



begin
	resetDone <= resetDone_S;
	rxLocked <= rxLocked2_S;
	txLocked <= txLocked_S;	
	rxUsrClkdiv2 <= rxRecClk_S;
	txUsrClk <= txUsrClkx2_S;

	
process(txUsrClk_buf_S,txResetdone_S)
    begin
        if(txResetdone_S = '0') then
            gtx0_txresetdone_r  <= '0';
            gtx0_txresetdone_r2 <= '0';
        elsif(txUsrClk_buf_S'event and txUsrClk_buf_S = '1') then
            gtx0_txresetdone_r  <= txResetdone_S;
            gtx0_txresetdone_r2 <= gtx0_txresetdone_r;
        end if;
    end process;
txReset_S <= '0'; 
txLocked_S <= '1' when (gtx0_txresetdone_r2='1') else '0';			
	

DC_data8to16_1: DC_data8to16
	port map( 
		clock_in => txUsrClkx2_S,
		data_in => txData,
		kchar_in => txCharIsK,
		clock_out => txUsrClk_buf_S,
		data_out => txData16_S,
		kchar_out => txCharIsK16_S
	);

DC_data16to8_1: DC_data16to8 
	port map(
		clock_in => rxRecClk_S,
		data_in => rxData16_S,
		kchar_in => rxCharIsK16_S,
		notintable_in => rxNotInTable16_S,
		clock_out => rxUsrClk,
		data_out => rxData_S,
		kchar_out => rxCharIsK_S,
		notintable_out => rxNotInTable_S
	);
rxData <= rxData_S;
rxCharIsK <= rxCharIsK_S;
rxNotInTable <= rxNotInTable_S;


-- clock100to200a: clock100to200 port map(
		-- clk_in1 => txoutclk_S,
		-- clk_out1 => txUsrClk_buf_S,
		-- clk_out2 => txUsrClkx2_S,
		-- reset => gtpReset_S,
		-- locked => open);


--buf_rxclk: BUFG port map(I => rxRecClk_S, O => rxRecClk_buf_S);


 	
gtx_i : GTX_SODAinput_support 
	port map(
		SOFT_RESET_TX_IN => gtpReset_S,
		SOFT_RESET_RX_IN => gtpReset_S,
		DONT_RESET_ON_DATA_ERROR_IN => '1',
    Q3_CLK0_GTREFCLK_PAD_N_IN => '0', --// Modified
    Q3_CLK0_GTREFCLK_PAD_P_IN => '0', --// Modified
        GT0_TX_MMCM_LOCK_OUT => open,
		GT0_TX_FSM_RESET_DONE_OUT => open, --// txResetdone_S,
		GT0_RX_FSM_RESET_DONE_OUT => open, --// resetDone_S,
    GT0_DATA_VALID_IN => '1',
    GT0_TXUSRCLK_OUT => open,
    GT0_TXUSRCLK2_OUT => txoutclk_S,
    GT0_TXUSRCLKX2_OUT => txUsrClkx2_S,
    GT0_RXUSRCLK_OUT => open,
    GT0_RXUSRCLK2_OUT => rxRecClk_S,
        --_____________________________________________________________________
        --_____________________________________________________________________
        --GT0  (X1Y15)

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
 		gt0_eyescandataerror_out => eyescandataerror_S,
        gt0_eyescantrigger_in => '0',
        -------------------------- RX CDR Reset Ports ------------------------ // modified
 		GT0_RXCDRRESET_IN => CDR_reset_S,
		GT0_RXCDRLOCK_OUT => rxCDRlock_S,
       ------------------ Receive Ports - FPGA RX interface Ports -----------------
		gt0_rxdata_out => rxData16_S,
        ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
		gt0_rxdisperr_out => rxDispError16_S,
		gt0_rxnotintable_out => rxNotInTable16_S,
        --------------------------- Receive Ports - RX AFE -------------------------
		gt0_gtxrxp_in => rxP,
        ------------------------ Receive Ports - RX AFE Ports ----------------------
 		gt0_gtxrxn_in => rxN,
        ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
		gt0_rxphmonitor_out => rxphmonitor_S,
		gt0_rxphslipmonitor_out => rxphslipmonitor_S,
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
		gt0_gttxreset_in => txReset_S,
		gt0_txuserrdy_in => '0',
        ------------------ Transmit Ports - TX Data Path interface -----------------
		gt0_txdata_in => txData16_S,
        ---------------- Transmit Ports - TX Driver and OOB signaling --------------
		gt0_gtxtxn_out => txN,
		gt0_gtxtxp_out => txP,
        ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
		gt0_txoutclkfabric_out => open,
		gt0_txoutclkpcs_out => open,
        --------------------- Transmit Ports - TX Gearbox Ports --------------------
		gt0_txcharisk_in => txCharIsK16_S,
        ------------- Transmit Ports - TX Initialization and Reset Ports -----------
		gt0_txresetdone_out => txResetdone_S,
		GT0_QPLLOUTCLK_OUT  => GT0_QPLLOUTCLK_OUT,
		GT0_QPLLOUTREFCLK_OUT => GT0_QPLLOUTREFCLK_OUT,
		sysclk_in => sysClk,
		q2_clk1_gtrefclk => refClk_P,  --//modification
		q3_clk0_gtrefclk => refClk_N  --//modification
	);

rxLossOfSync1_S <= '0' when (rxNotInTable16_S="00") or (disable_GTX_reset='1') else '1';
DC_rxBitLock1 : DC_rxBitLock port map (
		clk => rxRecClk_S,
		reset => gtpReset_S,
		resetDone => resetDone_S,
		lossOfSync => rxLossOfSync1_S,
		rxPllLocked => PllLkDet_S,
		rxReset => rxResetBitLock_S,
		fsmStatus => fsmStatus_S
	);
	
process(sysClk,gtpReset)
variable counter_V : std_logic_vector(23 downto 0) := (others => '0');
begin
	if gtpReset='1' then
		gtpReset_S	<= '1';
		counter_V := (others => '0');
	elsif rising_edge(sysClk) then
		gtpReset_S	<= '0';
		if counter_V(counter_V'left)='1' then
			if resetDone_S='0' then
				counter_V := (others => '0');
				gtpReset_S	<= '1';
			end if;
		else
			counter_V := counter_V+1;
		end if;
	end if;
end process;

---- rxReset_S <= gtpReset;
rxReset_S <= '1' when ((rxPLLwrapper_reset_S='1') or (gtpReset_S='1') or (rxResetBitLock_pulse_S='1')) and (disable_GTX_reset='0') else '0';
--//rxLocked_S	<= '1' when (fsmStatus_S = "10")  else '0';
-- peter: gepulste reset (op refclk) voor zowel GTP als PLL
-- lengte van de reset-pulse varieert om te voorkomen dat de reset synchroon is met de GTP			
----rxPLLwrapper_reset_S <= '1' when (notPllLkDet_S='1') or (rxResetBitLock_pulse_S='1') else '0';


--//rxPLLwrapper_reset_S <= '0'; --// '1' when (rxResetBitLock_pulse_S='1') else '0';

rxLocked0_S <= '1' when (resetDone_S='1') and (fsmStatus_S = "10") else '0';
sync_rx_locked: sync_bit port map(
	clock => sysClk,
	data_in => rxLocked0_S,
	data_out => rxLocked1_S);

process(asyncclk) 
variable resetcounter_V : integer range 0 to 63 := 0;
variable lastresetcounter_V : integer range 0 to 63 := 10;
begin
	if rising_edge(asyncclk) then
		if (sync_rxResetBitLock_S='1') and (prev_rxResetBitLock_S='0') then
			rxResetBitLock_pulse_S <= '1';
			resetcounter_V := 0;
			if lastresetcounter_V<63 then
				lastresetcounter_V := lastresetcounter_V+1;
			else
				lastresetcounter_V := 10;
			end if;
		elsif resetcounter_V<lastresetcounter_V then
			rxResetBitLock_pulse_S <= '1';
			resetcounter_V := resetcounter_V+1;
		else
			rxResetBitLock_pulse_S <= '0';
		end if;
		sync_rxResetBitLock_S <= rxResetBitLock_S;
		prev_rxResetBitLock_S <= sync_rxResetBitLock_S;
	end if;
end process;
process(sysClk) 
variable counter_V : std_logic_vector(5 downto 0) := (others => '0');
variable timoutcounter_V : std_logic_vector(11 downto 0) := (others => '0');
begin
	if rising_edge(sysClk) then
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


pulse_comma_align_latency: DC_posedge_to_pulse port map(
		clock_in => sysClk,
		clock_out => rxRecClk_S,
		en_clk => '1',
		signal_in => comma_align_latency0_valid_S,
		pulse => comma_align_latency_valid_S);


end Behavioral;
