----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel / Michel Hevinga
-- Create Date:   18-07-2013
-- Module Name:   serdesQuadBufLayerMUX
-- Description:   Interface module for Quad GTP/GTX/serdes with synchronized transmit frequency
-- Modifications:
--   29-08-2014   ADCCLOCKFREQUENCY added: SODA clock at 80MHz 
--   20-11-2014   Data width to/from serdesQuadMUXwrapper
--   27-01-2015   SCI interface removed
--   29-02-2015   txUsrClkDiv2 removed
--   12-05-2015   status output replaced by individual signals
--   21-05-2015   now also used for Kintex7
--   22-05-2015   DLM clock output added
--   08-06-2015   QPLL ref clock signals for Xilinx Kintex7 added
----------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
USE work.gtpBufLayer.all;

----------------------------------------------------------------------------------
-- serdesQuadBufLayerMUX
-- Quad GTP/GTX/serdes tranceiver for PANDA Front End Electronics and Multiplexer with synchronised transmitted data.
--
-- Synchronous data (SODA) is combined with asynchrounous data (used for Slow-control) and transmitted.
-- Synchronous data will always be passed on immediately. (DLM signals).
-- Asynchronous data is buffered in a 32-bits wide fifo first, both sending and received.
--
--
--
-- Library
--     work.gtpBufLayer : for GTP/GTX constants
--
-- Generics:
-- 
-- Inputs:
--     refClk : Reference clock for GTP/GTX, synchronous with transmitted data
--     refClk_P : differential input pad for Reference clock for GTP/GTX, if internal clock cannot be used (Xilinx)
--     refClk_N : differential input pad for Reference clock for GTP/GTX, if internal clock cannot be used (Xilinx)
--     sysClk : Local bus system clock for serdes control interface and LEDs
--     reset : reset
--     reset_fibers : reset fiber connections (serdes or GTP/GTX)
--     clk_SODA200 : SODA clock, 200MHz
--     txAsyncClk : clock for the asynchronous 32-bits data to be transmitted
--     rxAsyncClk : Clock for the asynchronous (32-bits) received data
--   For channel0 in quad serdes :
--     G0_txAsyncData : asynchronous 32-bits data to be transmitted
--     G0_txAsyncDataWrite : write signal for asynchronous 32-bits data to be transmitted
--     G0_rxAsyncDataRead : read signal for asynchronous 32-bits received data
--     G0_TX_DLM : transmit SODA character
--     G0_TX_DLM_WORD : SODA character to be transmitted
--     G0_LOS : no fiber signal detected
--     G0_rxP,G0_rxN :  differential input to the serdes
--   For channel1 in quad serdes :
--     G1_txAsyncData : asynchronous 32-bits data to be transmitted
--     G1_txAsyncDataWrite : write signal for asynchronous 32-bits data to be transmitted
--     G1_rxAsyncDataRead : read signal for asynchronous 32-bits received data
--     G1_TX_DLM : transmit SODA character
--     G1_TX_DLM_WORD : SODA character to be transmitted
--     G1_LOS : no fiber signal detected
--     G1_rxP,G1_rxN :  differential input to the serdes
--   For channel2 in quad serdes :
--     G2_txAsyncData : asynchronous 32-bits data to be transmitted
--     G2_txAsyncDataWrite : write signal for asynchronous 32-bits data to be transmitted
--     G2_rxAsyncDataRead : read signal for asynchronous 32-bits received data
--     G2_TX_DLM : transmit SODA character
--     G2_TX_DLM_WORD : SODA character to be transmitted
--     G2_LOS : no fiber signal detected
--     G2_rxP,G1_rxN :  differential input to the serdes
--   For channel3 in quad serdes :
--     G3_txAsyncData : asynchronous 32-bits data to be transmitted
--     G3_txAsyncDataWrite : write signal for asynchronous 32-bits data to be transmitted
--     G3_rxAsyncDataRead : read signal for asynchronous 32-bits received data
--     G3_TX_DLM : transmit SODA character
--     G3_TX_DLM_WORD : SODA character to be transmitted
--     G3_LOS : no fiber signal detected
--     G3_rxP,G1_rxN :  differential input to the serdes
--   GT0_QPLLOUTCLK_IN : QPLL reference clock, needed for Xilinx
--   GT0_QPLLOUTREFCLK_IN : QPLL reference clock, needed for Xilinx
-- 
-- Outputs:
--     refClkOut : buffered reference clock from the GP/GTX
--     refClk_OK : indicates if refClkOut is stable (PLL locked)
--     txpll_clocks : clock from serdes for transmit data, not used for synchronous output
--   For channel0 in dual GTP/GTX  :
--     G0_txAsyncFifoFull : Fifo buffer for asynchronous 32-bits data is full
--     G0_rxAsyncData : Received 32-bits asynchronous data
--     G0_rxAsyncDataOverflow : Overflow in fifo for received 32-bits asynchronous data: error, data lost
--     G0_rxAsyncDataPresent : Received 32-bits asynchronous data is available
--     G0_txLocked : Transmitter locked
--     G0_rxLocked : Receiver locked
--     G0_error : Received character is invalid (not in table) or unexpected
--     G0_RX_DLM : SODA character received
--     G0_RX_DLM_WORD : SODA character 
--     G0_txP,G0_txN : differential transmit outputs of the serdes
--   For channel1 in dual serdes  :
--     G1_txAsyncFifoFull : Fifo buffer for asynchronous 32-bits data is full
--     G1_rxAsyncData : Received 32-bits asynchronous data
--     G1_rxAsyncDataOverflow : Overflow in fifo for received 32-bits asynchronous data: error, data lost
--     G1_rxAsyncDataPresent : Received 32-bits asynchronous data is available
--     G1_txLocked : Transmitter locked
--     G1_rxLocked : Receiver locked
--     G1_error : Received character is invalid (not in table) or unexpected
--     G1_RX_DLM : SODA character received
--     G1_RX_DLM_WORD : SODA character 
--     G1_txP,G1_txN : differential transmit outputs of the serdes
--   For channel2 in dual serdes  :
--     G2_txAsyncFifoFull : Fifo buffer for asynchronous 32-bits data is full
--     G2_rxAsyncData : Received 32-bits asynchronous data
--     G2_rxAsyncDataOverflow : Overflow in fifo for received 32-bits asynchronous data: error, data lost
--     G2_rxAsyncDataPresent : Received 32-bits asynchronous data is available
--     G2_txLocked : Transmitter locked
--     G2_rxLocked : Receiver locked
--     G2_error : Received character is invalid (not in table) or unexpected
--     G2_RX_DLM : SODA character received
--     G2_RX_DLM_WORD : SODA character 
--     G2_txP,G2_txN : differential transmit outputs of the serdes
--   For channel3 in dual serdes  :
--     G3_txAsyncFifoFull : Fifo buffer for asynchronous 32-bits data is full
--     G3_rxAsyncData : Received 32-bits asynchronous data
--     G3_rxAsyncDataOverflow : Overflow in fifo for received 32-bits asynchronous data: error, data lost
--     G3_rxAsyncDataPresent : Received 32-bits asynchronous data is available
--     G3_txLocked : Transmitter locked
--     G3_rxLocked : Receiver locked
--     G3_error : Received character is invalid (not in table) or unexpected
--     G3_RX_DLM : SODA character received
--     G3_RX_DLM_WORD : SODA character 
--     G3_txP,G3_txN : differential transmit outputs of the serdes
--     LEDs_link_ok : serdes status for LED on extension board : link ok
--     LEDs_rx : serdes status for LED on extension board : receive
--     LEDs_tx : serdes status for LED on extension board : transmit
-- 
-- Components:
--     serdesQuadMUXwrapper : module with the quad serdes interface
--     DC_fifo32to8_SODA : fifo for data to be transmitted, converts data from 32-bits to 8-bits
--     DC_fifo8to32_SODA : fifo for received asynchronous data, converts data from 8-bits to 32-bits
--
----------------------------------------------------------------------------------

entity serdesQuadBufLayerMUX is 
	port (
		refClk                  : in std_logic;
		refClk_P                : in  std_logic := '0';
		refClk_N                : in  std_logic := '1';
		sysClk                  : in  std_logic;
		reset                   : in std_logic;
		reset_fibers            : in std_logic;
		clk_SODA200             : in std_logic;
		txAsyncClk              : in std_logic;
		rxAsyncClk              : in std_logic;
		txpll_clocks            : out std_logic_vector(3 downto 0) := (others => '0');

		G0_txAsyncData          : in std_logic_vector (31 downto 0);
		G0_txAsyncDataWrite     : in std_logic;
		G0_txAsyncFifoFull      : out std_logic;
		G0_rxAsyncData          : out std_logic_vector (31 downto 0);
		G0_rxAsyncDataRead      : in std_logic;
		G0_rxAsyncDataOverflow  : out std_logic;
		G0_rxAsyncDataPresent   : out std_logic;
		G0_txLocked             : out std_logic;
		G0_rxLocked             : out std_logic;
		G0_error                : out std_logic;
		G0_TX_DLM               : in  std_logic;
		G0_TX_DLM_WORD          : in  std_logic_vector(7 downto 0); 
		G0_RX_DLM               : out std_logic;
		G0_RX_DLM_WORD          : out std_logic_vector(7 downto 0);
		G0_LOS                  : in std_logic;
		G0_txP                  : out std_logic;
		G0_txN                  : out std_logic;
		G0_rxP                  : in std_logic;
		G0_rxN                  : in std_logic;
  
		G1_txAsyncData          : in std_logic_vector (31 downto 0);
		G1_txAsyncDataWrite     : in std_logic;
		G1_txAsyncFifoFull      : out std_logic;
		G1_rxAsyncData          : out std_logic_vector (31 downto 0);
		G1_rxAsyncDataRead      : in std_logic;
		G1_rxAsyncDataOverflow  : out std_logic;
		G1_rxAsyncDataPresent   : out std_logic;
		G1_txLocked             : out std_logic;
		G1_rxLocked             : out std_logic;
		G1_error                : out std_logic;
		G1_TX_DLM               : in  std_logic;
		G1_TX_DLM_WORD          : in  std_logic_vector(7 downto 0);   
		G1_RX_DLM               : out std_logic;
		G1_RX_DLM_WORD          : out std_logic_vector(7 downto 0);
		G1_LOS                  : in std_logic;
		G1_txP                  : out std_logic;
		G1_txN                  : out std_logic;
		G1_rxP                  : in std_logic;
		G1_rxN                  : in std_logic;

		G2_txAsyncData          : in std_logic_vector (31 downto 0);
		G2_txAsyncDataWrite     : in std_logic;
		G2_txAsyncFifoFull      : out std_logic;
		G2_rxAsyncData          : out std_logic_vector (31 downto 0);
		G2_rxAsyncDataRead      : in std_logic;
		G2_rxAsyncDataOverflow  : out std_logic;
		G2_rxAsyncDataPresent   : out std_logic;
		G2_txLocked             : out std_logic;
		G2_rxLocked             : out std_logic;
		G2_error                : out std_logic;
		G2_TX_DLM               : in  std_logic;
		G2_TX_DLM_WORD          : in  std_logic_vector(7 downto 0);  
		G2_RX_DLM               : out std_logic;
		G2_RX_DLM_WORD          : out std_logic_vector(7 downto 0);
		G2_LOS                  : in std_logic;
		G2_txP                  : out std_logic;
		G2_txN                  : out std_logic;
		G2_rxP                  : in std_logic;
		G2_rxN                  : in std_logic;

		G3_txAsyncData          : in std_logic_vector (31 downto 0);
		G3_txAsyncDataWrite     : in std_logic;
		G3_txAsyncFifoFull      : out std_logic;
		G3_rxAsyncData          : out std_logic_vector (31 downto 0);
		G3_rxAsyncDataRead      : in std_logic;
		G3_rxAsyncDataOverflow  : out std_logic;
		G3_rxAsyncDataPresent   : out std_logic;
		G3_txLocked             : out std_logic;
		G3_rxLocked             : out std_logic;
		G3_error                : out std_logic;
		G3_TX_DLM               : in  std_logic;
		G3_TX_DLM_WORD          : in  std_logic_vector(7 downto 0);   
		G3_RX_DLM               : out std_logic;
		G3_RX_DLM_WORD          : out std_logic_vector(7 downto 0);
		G3_LOS                  : in std_logic;
		G3_txP                  : out std_logic;
		G3_txN                  : out std_logic;
		G3_rxP                  : in std_logic;
		G3_rxN                  : in std_logic;

		LEDs_link_ok            : out std_logic_vector(0 to 3);
		LEDs_rx                 : out std_logic_vector(0 to 3); 
		LEDs_tx                 : out std_logic_vector(0 to 3);
		GT0_QPLLOUTCLK_IN       : in std_logic := '0';
		GT0_QPLLOUTREFCLK_IN    : in std_logic := '0';

		testPin                 : out  std_logic_vector(3 downto 0);
		testword0               : out std_logic_vector (35 downto 0) := (others => '0'); 
		testword0clock          : out std_logic := '0'
	);
end serdesQuadBufLayerMUX;

architecture Behavioral of serdesQuadBufLayerMUX is

component serdesQuadMUXwrapper is
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
		G0_rxUsrClk             : out  std_logic;
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
		G1_rxUsrClk             : out  std_logic;
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
		G2_rxUsrClk             : out  std_logic;
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
		G3_rxUsrClk             : out  std_logic;
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
end component;

component DC_fifo8to32_SODA is
	port ( 
		write_clock             : in std_logic;
		read_clock              : in std_logic;
		reset                   : in std_logic;
		data_in                 : in std_logic_vector(7 downto 0);
		char_is_k               : in std_logic;
		RX_DLM                  : out std_logic;
		RX_DLM_WORD             : out std_logic_vector(7 downto 0);
		data_out                : out std_logic_vector(31 downto 0);
		data_read               : in std_logic;
		data_available          : out std_logic;
		overflow                : out std_logic;
		error                   : out std_logic		
	);
end component;

component DC_fifo32to8_SODA is
	port ( 
		write_clock             : in std_logic;
		read_clock              : in std_logic;
		reset                   : in std_logic;
		data_in                 : in std_logic_vector(31 downto 0);
		data_write              : in std_logic;
		full                    : out std_logic;
		TX_DLM                  : in std_logic;
		TX_DLM_WORD             : in std_logic_vector(7 downto 0);
		data_out                : out std_logic_vector(7 downto 0);
		char_is_k               : out std_logic
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

component sync_bit is
	port (
		clock       : in  std_logic;
		data_in     : in  std_logic;
		data_out    : out std_logic
	);
end component;

signal reset_S                   : std_logic;

signal txpll_clocks_S            : std_logic_vector(3 downto 0);

signal G0_txData_S               : std_logic_vector(7 downto 0);
signal G0_rxData_S               : std_logic_vector(7 downto 0);
signal G0_rxUsrClk_S             : std_logic;
signal G0_rxLocked_S             : std_logic := '0';
signal G0_txLocked_S             : std_logic := '0';
signal G0_rxNotInTable_S         : std_logic := '0';
signal G0_txCharIsK0_S           : std_logic;
signal G0_rxCharIsK0_S           : std_logic;
signal G0_error_S                : std_logic := '0';
signal G0_RX_DLM_WORD_S          : std_logic_vector(7 downto 0);
signal G0_RX_DLM_S               : std_logic;
signal G0_TX_DLM_WORD_S          : std_logic_vector(7 downto 0);
signal G0_TX_DLM_S               : std_logic;
signal fifo8to32_reset0_S        : std_logic;

signal G1_txData_S               : std_logic_vector(7 downto 0);
signal G1_rxData_S               : std_logic_vector(7 downto 0);
signal G1_rxUsrClk_S             : std_logic;
signal G1_rxLocked_S             : std_logic := '0';
signal G1_txLocked_S             : std_logic := '0';
signal G1_rxNotInTable_S         : std_logic := '0'; 
signal G1_txCharIsK0_S           : std_logic;
signal G1_rxCharIsK0_S           : std_logic;
signal G1_error_S                : std_logic := '0';
signal G1_RX_DLM_WORD_S          : std_logic_vector(7 downto 0);
signal G1_RX_DLM_S               : std_logic;
signal G1_TX_DLM_WORD_S          : std_logic_vector(7 downto 0);
signal G1_TX_DLM_S               : std_logic;
signal fifo8to32_reset1_S        : std_logic;
	
signal G2_txData_S               : std_logic_vector(7 downto 0);
signal G2_rxData_S               : std_logic_vector(7 downto 0);
signal G2_rxUsrClk_S             : std_logic;
signal G2_rxLocked_S             : std_logic := '0';
signal G2_txLocked_S             : std_logic := '0';
signal G2_rxNotInTable_S         : std_logic := '0'; 
signal G2_txCharIsK0_S           : std_logic;
signal G2_rxCharIsK0_S           : std_logic;
signal G2_error_S                : std_logic := '0';
signal G2_RX_DLM_WORD_S          : std_logic_vector(7 downto 0);
signal G2_RX_DLM_S               : std_logic;
signal G2_TX_DLM_WORD_S          : std_logic_vector(7 downto 0);
signal G2_TX_DLM_S               : std_logic;
signal fifo8to32_reset2_S        : std_logic;
	
signal G3_txData_S               : std_logic_vector(7 downto 0);
signal G3_rxData_S               : std_logic_vector(7 downto 0);
signal G3_rxUsrClk_S             : std_logic;
signal G3_rxLocked_S             : std_logic := '0';
signal G3_txLocked_S             : std_logic := '0';
signal G3_rxNotInTable_S         : std_logic := '0'; 
signal G3_txCharIsK0_S           : std_logic;
signal G3_rxCharIsK0_S           : std_logic;
signal G3_error_S                : std_logic := '0';
signal G3_RX_DLM_WORD_S          : std_logic_vector(7 downto 0);
signal G3_RX_DLM_S               : std_logic;
signal G3_TX_DLM_WORD_S          : std_logic_vector(7 downto 0);
signal G3_TX_DLM_S               : std_logic;
signal fifo8to32_reset3_S        : std_logic;
	

attribute mark_debug : string;
-- attribute mark_debug of G0_txData_S : signal is "true";
-- attribute mark_debug of G0_rxData_S : signal is "true";
-- attribute mark_debug of G0_rxLocked_S : signal is "true";
-- attribute mark_debug of G0_txLocked_S : signal is "true";
-- attribute mark_debug of G0_txCharIsK0_S : signal is "true";
-- attribute mark_debug of G0_rxCharIsK0_S : signal is "true";
-- attribute mark_debug of G0_error_S : signal is "true";
-- attribute mark_debug of fifo8to32_reset0_S : signal is "true";
-- attribute mark_debug of G1_txData_S : signal is "true";
-- attribute mark_debug of G1_rxData_S : signal is "true";
-- attribute mark_debug of G1_rxLocked_S : signal is "true";
-- attribute mark_debug of G1_txLocked_S : signal is "true";
-- attribute mark_debug of G1_rxNotInTable_S : signal is "true";
-- attribute mark_debug of G1_txCharIsK0_S : signal is "true";
-- attribute mark_debug of G1_rxCharIsK0_S : signal is "true";
-- attribute mark_debug of G1_error_S : signal is "true";
-- attribute mark_debug of fifo8to32_reset1_S : signal is "true";


		
begin

reset_S <= '1' when (reset_fibers='1') or (reset='1') else '0';
txpll_clocks <= txpll_clocks_S;

serdesQuadMUXwrapper1: serdesQuadMUXwrapper port map(
		refClk => refClk,
		refClk_P => refClk_P,
		refClk_N => refClk_N,
		sysClk => sysClk,
		gtpReset => reset_S,
		txpll_clocks => txpll_clocks_S,
		
		G0_txData => G0_txData_S,
		G0_rxData => G0_rxData_S,
		G0_txP => G0_txP,
		G0_txN => G0_txN,
		G0_rxP => G0_rxP,
		G0_rxN => G0_rxN,
		G0_LOS => G0_LOS,
		G0_rxUsrClk => G0_rxUsrClk_S,
		G0_rxLocked => G0_rxLocked_S,
		G0_rxNotInTable => G0_rxNotInTable_S,
		G0_txLocked => G0_txLocked_S,
		G0_txCharIsK0 => G0_txCharIsK0_S,
		G0_rxCharIsK0 => G0_rxCharIsK0_S,

		G1_txData => G1_txData_S,
		G1_rxData => G1_rxData_S,
		G1_txP => G1_txP,
		G1_txN => G1_txN,
		G1_rxP => G1_rxP,
		G1_rxN => G1_rxN,
		G1_LOS => G1_LOS,
		G1_rxUsrClk => G1_rxUsrClk_S,
		G1_rxLocked => G1_rxLocked_S,
		G1_rxNotInTable => G1_rxNotInTable_S,
		G1_txLocked => G1_txLocked_S,
		G1_txCharIsK0 => G1_txCharIsK0_S,
		G1_rxCharIsK0 => G1_rxCharIsK0_S,

		G2_txData => G2_txData_S,
		G2_rxData => G2_rxData_S,
		G2_txP => G2_txP,
		G2_txN => G2_txN,
		G2_rxP => G2_rxP,
		G2_rxN => G2_rxN,
		G2_LOS => G2_LOS,
		G2_rxUsrClk => G2_rxUsrClk_S,
		G2_rxLocked => G2_rxLocked_S,
		G2_rxNotInTable => G2_rxNotInTable_S,
		G2_txLocked => G2_txLocked_S,
		G2_txCharIsK0 => G2_txCharIsK0_S,
		G2_rxCharIsK0 => G2_rxCharIsK0_S,

		G3_txData => G3_txData_S,
		G3_rxData => G3_rxData_S,
		G3_txP => G3_txP,
		G3_txN => G3_txN,
		G3_rxP => G3_rxP,
		G3_rxN => G3_rxN,
		G3_LOS => G3_LOS,
		G3_rxUsrClk => G3_rxUsrClk_S,
		G3_rxLocked => G3_rxLocked_S,
		G3_rxNotInTable => G3_rxNotInTable_S,
		G3_txLocked => G3_txLocked_S,
		G3_txCharIsK0 => G3_txCharIsK0_S,
		G3_rxCharIsK0 => G3_rxCharIsK0_S,
		
		LEDs_link_ok => LEDs_link_ok,
		LEDs_rx => LEDs_rx,
		LEDs_tx => LEDs_tx,

		GT0_QPLLOUTCLK_IN => GT0_QPLLOUTCLK_IN,
		GT0_QPLLOUTREFCLK_IN => GT0_QPLLOUTREFCLK_IN,
		testword0 => open,
		testword0clock => testword0clock
		);

	G0_txLocked <= G0_txLocked_S; -- '1' => OK
	G0_rxLocked <= G0_rxLocked_S; -- '1' => OK
	G0_error <= '1' when (G0_rxNotInTable_S='1') or (G0_error_S='1') else '0'; -- '1' => error

	G1_txLocked <= G1_txLocked_S; -- '1' => OK
	G1_rxLocked <= G1_rxLocked_S; -- '1' => OK
	G1_error <= '1' when (G1_rxNotInTable_S='1') or (G1_error_S='1') else '0'; -- '1' => error

	G2_txLocked <= G2_txLocked_S; -- '1' => OK
	G2_rxLocked <= G2_rxLocked_S; -- '1' => OK
	G2_error <= '1' when (G2_rxNotInTable_S='1') or (G2_error_S='1') else '0'; -- '1' => error

	G3_txLocked <= G3_txLocked_S; -- '1' => OK
	G3_rxLocked <= G3_rxLocked_S; -- '1' => OK
	G3_error <= '1' when (G3_rxNotInTable_S='1') or (G3_error_S='1') else '0'; -- '1' => error

	testPin(0) <= G0_txCharIsK0_S;
	testPin(1) <= G0_rxCharIsK0_S;
	testPin(2) <= '0';
	testPin(3) <= '0';

DC_fifo32to8_SODA0: DC_fifo32to8_SODA port map(
		write_clock => txAsyncClk,
		read_clock => txpll_clocks_S(0),
		reset => reset,
		data_in => G0_txAsyncData,
		data_write => G0_txAsyncDataWrite,
		full => G0_txAsyncFifoFull,
		TX_DLM => G0_TX_DLM_S,
		TX_DLM_WORD => G0_TX_DLM_WORD_S,
		data_out => G0_txData_S,
		char_is_k => G0_txCharIsK0_S);
DC_fifo32to8_SODA1: DC_fifo32to8_SODA port map(
		write_clock => txAsyncClk,
		read_clock => txpll_clocks_S(1),
		reset => reset,
		data_in => G1_txAsyncData,
		data_write => G1_txAsyncDataWrite,
		full => G1_txAsyncFifoFull,
		TX_DLM => G1_TX_DLM_S,
		TX_DLM_WORD => G1_TX_DLM_WORD_S,
		data_out => G1_txData_S,
		char_is_k => G1_txCharIsK0_S);
DC_fifo32to8_SODA2: DC_fifo32to8_SODA port map(
		write_clock => txAsyncClk,
		read_clock => txpll_clocks_S(2),
		reset => reset,
		data_in => G2_txAsyncData,
		data_write => G2_txAsyncDataWrite,
		full => G2_txAsyncFifoFull,
		TX_DLM => G2_TX_DLM_S,
		TX_DLM_WORD => G2_TX_DLM_WORD_S,
		data_out => G2_txData_S,
		char_is_k => G2_txCharIsK0_S);
DC_fifo32to8_SODA3: DC_fifo32to8_SODA port map(
		write_clock => txAsyncClk,
		read_clock => txpll_clocks_S(3),
		reset => reset,
		data_in => G3_txAsyncData,
		data_write => G3_txAsyncDataWrite,
		full => G3_txAsyncFifoFull,
		TX_DLM => G3_TX_DLM_S,
		TX_DLM_WORD => G3_TX_DLM_WORD_S,
		data_out => G3_txData_S,
		char_is_k => G3_txCharIsK0_S);
		

DC_fifo8to32_SODA0: DC_fifo8to32_SODA port map(
		write_clock => G0_rxUsrClk_S,
		read_clock => rxAsyncClk,
		reset => fifo8to32_reset0_S,
		data_in => G0_rxData_S,
		char_is_k => G0_rxCharIsK0_S,
		RX_DLM => G0_RX_DLM_S,
		RX_DLM_WORD => G0_RX_DLM_WORD_S,
		data_out => G0_rxAsyncData,
		data_read => G0_rxAsyncDataRead,
		data_available => G0_rxAsyncDataPresent,
		overflow => G0_rxAsyncDataOverflow,
		error => G0_error_S);
DC_fifo8to32_SODA1: DC_fifo8to32_SODA port map(
		write_clock => G1_rxUsrClk_S,
		read_clock => rxAsyncClk,
		reset => fifo8to32_reset1_S,
		data_in => G1_rxData_S,
		char_is_k => G1_rxCharIsK0_S,
		RX_DLM => G1_RX_DLM_S,
		RX_DLM_WORD => G1_RX_DLM_WORD_S,
		data_out => G1_rxAsyncData,
		data_read => G1_rxAsyncDataRead,
		data_available => G1_rxAsyncDataPresent,
		overflow => G1_rxAsyncDataOverflow,
		error => G1_error_S);
DC_fifo8to32_SODA2: DC_fifo8to32_SODA port map(
		write_clock => G2_rxUsrClk_S,
		read_clock => rxAsyncClk,
		reset => fifo8to32_reset2_S,
		data_in => G2_rxData_S,
		char_is_k => G2_rxCharIsK0_S,
		RX_DLM => G2_RX_DLM_S,
		RX_DLM_WORD => G2_RX_DLM_WORD_S,
		data_out => G2_rxAsyncData,
		data_read => G2_rxAsyncDataRead,
		data_available => G2_rxAsyncDataPresent,
		overflow => G2_rxAsyncDataOverflow,
		error => G2_error_S);
DC_fifo8to32_SODA3: DC_fifo8to32_SODA port map(
		write_clock => G3_rxUsrClk_S,
		read_clock => rxAsyncClk,
		reset => fifo8to32_reset3_S,
		data_in => G3_rxData_S,
		char_is_k => G3_rxCharIsK0_S,
		RX_DLM => G3_RX_DLM_S,
		RX_DLM_WORD => G3_RX_DLM_WORD_S,
		data_out => G3_rxAsyncData,
		data_read => G3_rxAsyncDataRead,
		data_available => G3_rxAsyncDataPresent,
		overflow => G3_rxAsyncDataOverflow,
		error => G3_error_S);

fifo8to32_reset0_S <= not G0_rxLocked_S;
fifo8to32_reset1_S <= not G1_rxLocked_S;
fifo8to32_reset2_S <= not G2_rxLocked_S;
fifo8to32_reset3_S <= not G3_rxLocked_S;

		
DC_SODA_clockcrossing_rx0: DC_SODA_clockcrossing port map(
		write_clock => G0_rxUsrClk_S,
		read_clock => clk_SODA200,
		DLM_in => G0_RX_DLM_S,
		DLM_WORD_in => G0_RX_DLM_WORD_S,
		DLM_out => G0_RX_DLM,
		DLM_WORD_out => G0_RX_DLM_WORD,
		error => open);
DC_SODA_clockcrossing_rx1: DC_SODA_clockcrossing port map(
		write_clock => G1_rxUsrClk_S,
		read_clock => clk_SODA200,
		DLM_in => G1_RX_DLM_S,
		DLM_WORD_in => G1_RX_DLM_WORD_S,
		DLM_out => G1_RX_DLM,
		DLM_WORD_out => G1_RX_DLM_WORD,
		error => open);
DC_SODA_clockcrossing_rx2: DC_SODA_clockcrossing port map(
		write_clock => G2_rxUsrClk_S,
		read_clock => clk_SODA200,
		DLM_in => G2_RX_DLM_S,
		DLM_WORD_in => G2_RX_DLM_WORD_S,
		DLM_out => G2_RX_DLM,
		DLM_WORD_out => G2_RX_DLM_WORD,
		error => open);
DC_SODA_clockcrossing_rx3: DC_SODA_clockcrossing port map(
		write_clock => G3_rxUsrClk_S,
		read_clock => clk_SODA200,
		DLM_in => G3_RX_DLM_S,
		DLM_WORD_in => G3_RX_DLM_WORD_S,
		DLM_out => G3_RX_DLM,
		DLM_WORD_out => G3_RX_DLM_WORD,
		error => open);

DC_SODA_clockcrossing_tx0: DC_SODA_clockcrossing port map(
		write_clock => clk_SODA200,
		read_clock => txpll_clocks_S(0),
		DLM_in => G0_TX_DLM,
		DLM_WORD_in => G0_TX_DLM_WORD,
		DLM_out => G0_TX_DLM_S,
		DLM_WORD_out => G0_TX_DLM_WORD_S,
		error => open);
DC_SODA_clockcrossing_tx1: DC_SODA_clockcrossing port map(
		write_clock => clk_SODA200,
		read_clock => txpll_clocks_S(1),
		DLM_in => G1_TX_DLM,
		DLM_WORD_in => G1_TX_DLM_WORD,
		DLM_out => G1_TX_DLM_S,
		DLM_WORD_out => G1_TX_DLM_WORD_S,
		error => open);
DC_SODA_clockcrossing_tx2: DC_SODA_clockcrossing port map(
		write_clock => clk_SODA200,
		read_clock => txpll_clocks_S(2),
		DLM_in => G2_TX_DLM,
		DLM_WORD_in => G2_TX_DLM_WORD,
		DLM_out => G2_TX_DLM_S,
		DLM_WORD_out => G2_TX_DLM_WORD_S,
		error => open);
DC_SODA_clockcrossing_tx3: DC_SODA_clockcrossing port map(
		write_clock => clk_SODA200,
		read_clock => txpll_clocks_S(3),
		DLM_in => G3_TX_DLM,
		DLM_WORD_in => G3_TX_DLM_WORD,
		DLM_out => G3_TX_DLM_S,
		DLM_WORD_out => G3_TX_DLM_WORD_S,
		error => open);
		
-- testword0clock <= G0_rxUsrClk_S;
testword0 <= (others => '0');

end Behavioral;



