library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_ARITH.ALL;
use IEEE.std_logic_UNSIGNED.ALL;

entity sync_fifo_512x41 is
port (
		rst                     : in std_logic;
		clk                     : in std_logic;
		din                     : in std_logic_vector(40 downto 0);
		wr_en                   : in std_logic;
		rd_en                   : in std_logic;
		dout                    : out std_logic_vector(40 downto 0);
		full                    : out std_logic;
		empty                   : out std_logic
	);
end sync_fifo_512x41;
	
architecture Behavioral of sync_fifo_512x41 is

component sync_fifo_512x41_ecp3 is
    port (
        Data: in  std_logic_vector(40 downto 0); 
        Clock: in  std_logic; 
        WrEn: in  std_logic; 
        RdEn: in  std_logic; 
        Reset: in  std_logic; 
        Q: out  std_logic_vector(40 downto 0); 
        Empty: out  std_logic; 
        Full: out  std_logic);
end component;

begin

sync_fifo_512x41_ecp3_1: sync_fifo_512x41_ecp3 port map(
        Data => din,
        Clock => clk,
        WrEn => wr_en,
        RdEn => rd_en,
        Reset => rst,
        Q => dout,
        Empty => empty,
        Full => full);

end Behavioral;

