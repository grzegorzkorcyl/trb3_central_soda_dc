----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Michel Hevinga / Peter Schakel
-- Create Date:   2010
-- Module Name:   DC_rxBitLock
-- Description:   Module to lock receiving clock of GTP/GTX at the right phase
-- Modifications:
--   18-11-2014   8 bits data instead of 16 bits
--   19-11-2014   name changed from rxBitLock to FEE_rxBitLock
--   26-05-2015   name changed from FEE_rxBitLock to DC_rxBitLock
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all ;
USE ieee.std_logic_arith.all ;
--use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;

----------------------------------------------------------------------------------
-- DC_rxBitLock
-- Module to lock receiving clock of GTP/GTX at the right phase.
-- First is checked if the resetDone input is high, (resetting is done)
-- then if lossOfSync is low ('0'), (GTP/GTX loss of sync signal)
-- If all these checks are allright the fmstatus will show that the GTP/GTX is locked on th incomming data.
-- If one of these checks are not reached within a certain time (TIME_OUT_SYNC_MAX constant)
-- the rxReset output is activated and checking is started again.
-- Also, the lossOfSync is always checked during operation.
--
-- Library
--
-- Generics:
-- 
-- Inputs:
--     clk : recovered clock from the GTP/GTX
--     reset : reset
--     resetDone : Reset is done, ready to check lock & synchronisation
--     lossOfSync : Loss of Sync: "00" means synchronised
--     rxPllLocked : Receiver PLL locked, not used at the moment
-- 
-- Outputs:
--     rxReset : Reset GTP/GTX to try another lock
--     fsmStatus : Status of the state machine:
--        00 : WAIT_RESET_DONE : waiting until ResetDone
--        01 : WAIT_TIME_OUT_SYNC : waiting for word aligned
--        10 : CHECK_LOSS_SYNC : running state : keep on checking for Loss of sync and bytes swapped
--        11 : RX_RESET : resetting for a new lock attempt
-- 
-- Components:
--
----------------------------------------------------------------------------------
entity DC_rxBitLock is
	port (
		clk                     : in std_logic;
		reset                   : in std_logic;
		resetDone               : in std_logic;
		lossOfSync              : in std_logic;
		rxPllLocked             : in std_logic;
		rxReset                 : out std_logic;
		fsmStatus               : out std_logic_vector (1 downto 0));
end DC_rxBitLock;

architecture Behavioral of DC_rxBitLock is

constant TIME_OUT_SYNC_MAX	: integer range 0 to 500 := 500;

signal rxReset_S              : std_logic :='0';
signal fsmStatus_S            : std_logic_vector (1 downto 0) :="00";
signal timeOutSynFlag_S       : std_logic :='0';
signal timeOutSyncCounter_I   : integer range 0 to TIME_OUT_SYNC_MAX :=0;

signal resettimeFlag_S        : std_logic :='0'; -- counter & flag for reset extender
signal resettimeCounter_I     : integer range 0 to 15 :=0; -- counter & flag for reset extender


type state_T is (WAIT_RESET_DONE, WAIT_TIME_OUT_SYNC, CHECK_LOSS_SYNC, RX_RESET);
signal currentState_S,nextState_S : state_T := WAIT_RESET_DONE;	

begin

rxReset <= rxReset_S;
fsmStatus <= fsmStatus_S;

fsmClk: process(clk, reset)
begin
	if (reset = '1')then
		currentState_S <= RX_RESET;
	else
		if rising_edge(clk) then
			currentState_S <= nextState_S;
		end if;
	end if;
end process;

fsmInput: process (currentState_S,resetDone, timeOutSynFlag_S, 
			lossOfSync, rxPllLocked, timeOutSynFlag_S, resettimeFlag_S)
begin
	case currentState_S is
		when WAIT_RESET_DONE 	=> if(resetDone = '1') then
												nextState_S <= WAIT_TIME_OUT_SYNC;
											else
												nextState_S <= WAIT_RESET_DONE;
											end if;
		when WAIT_TIME_OUT_SYNC	=> if (timeOutSynFlag_S = '1') then
												nextState_S <= RX_RESET;
											else
												if (lossOfSync = '0') then
													nextState_S <= CHECK_LOSS_SYNC;
												else
													nextState_S <= WAIT_TIME_OUT_SYNC;
												end if;
											end if;
		when CHECK_LOSS_SYNC		=> if (lossOfSync /= '0') then
												nextState_S <= RX_RESET;
											else
												nextState_S <= CHECK_LOSS_SYNC;
											end if;
		when RX_RESET				=>	if (resettimeFlag_S = '1') then  -- reset long to prevent that resetDone signal is missed
												nextState_S <= WAIT_RESET_DONE;
											else
												nextState_S <= RX_RESET;
											end if;
		when others					=> nextState_S <= RX_RESET;
	end case;
end process;

fsmOutput: process (clk)
begin
if rising_edge(clk) then
	case currentState_S is
		when WAIT_RESET_DONE 	=> fsmStatus_S <= "00";
											rxReset_S <= '0';
											timeOutSyncCounter_I <= 0;
											timeOutSynFlag_S <= '0';
											resettimeFlag_S <= '0';
											resettimeCounter_I <= 0;
		when WAIT_TIME_OUT_SYNC	=> fsmStatus_S <= "01";
											rxReset_S <= '0';
											resettimeFlag_S <= '0';
											resettimeCounter_I <= 0;
											if (timeOutSyncCounter_I < TIME_OUT_SYNC_MAX) then
												timeOutSyncCounter_I <= timeOutSyncCounter_I+1;
												timeOutSynFlag_S <= '0';
											else
												timeOutSyncCounter_I <= 0;
												timeOutSynFlag_S <= '1';
											end if;		
		when CHECK_LOSS_SYNC		=> fsmStatus_S <= "10";
											rxReset_S <= '0';
											timeOutSyncCounter_I <= 0;
											timeOutSynFlag_S <= '0';
											resettimeFlag_S <= '0';
											resettimeCounter_I <= 0;
		
		when RX_RESET				=>	fsmStatus_S <= "11";
											rxReset_S <= '1';
											timeOutSyncCounter_I <= 0;
											timeOutSynFlag_S <= '0';
											if resettimeCounter_I<8 then  -- peter : reset langer gemaakt om te voorkomen dat resetDone signaal wordt gemist
												resettimeCounter_I <= resettimeCounter_I+1;
												resettimeFlag_S <= '0';
											else
												resettimeCounter_I <= 0;
												resettimeFlag_S <= '1';
											end if;
		
		when others					=> 
	end case;
end if;	
end process;


end Behavioral;

