----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   21-05-2015
-- Module Name:   sync_bit
-- Description:   Synchronization for 1 bit cross clock signal
-- Modifications:
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

----------------------------------------------------------------------------------
-- sync_bit
-- Synchronize a signal to a different clock by passing through several registers.
-- This is the Xilinx version with Xilinx specific registers and attributes
--
-- Library
-- 
-- Generics:
-- 
-- Inputs:
--     clock : clock to synchronize to
--     data_in : signal from different clock
-- 
-- Outputs:
--     data_out : synchronized signal
-- 
-- Components:
--
----------------------------------------------------------------------------------


entity sync_bit is
	port (
		clock       : in  std_logic;
		data_in     : in  std_logic;
		data_out    : out std_logic
	);
end sync_bit;


architecture structural of sync_bit is

  signal dsync1 : std_logic;
  signal dsync2 : std_logic;

  -- These attributes will stop timing errors being reported in back annotated
  -- SDF simulation.
  attribute ASYNC_REG                       : string;
  attribute ASYNC_REG of dsync_reg1    : label is "true";
  attribute ASYNC_REG of dsync_reg2    : label is "true";
  attribute ASYNC_REG of dsync_reg3    : label is "true";

  -- These attributes will stop XST translating the desired flip-flops into an
  -- SRL based shift register.
  attribute shreg_extract                   : string;
  attribute shreg_extract of dsync_reg1 : label is "no";
  attribute shreg_extract of dsync_reg2 : label is "no";
  attribute shreg_extract of dsync_reg3 : label is "no";

  
begin

  dsync_reg1 : FD
  port map (
    C    => clock,
    D    => data_in,
    Q    => dsync1
  );

 dsync_reg2 : FD
  port map (
    C    => clock,
    D    => dsync1,
    Q    => dsync2
  );

 dsync_reg3 : FD
  port map (
    C    => clock,
    D    => dsync2,
    Q    => data_out
  );



end structural;


