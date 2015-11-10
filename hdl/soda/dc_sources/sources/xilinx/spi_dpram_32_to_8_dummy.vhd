library IEEE;
use IEEE.std_logic_1164.all;
-- dummy unit
entity spi_dpram_32_to_8 is
    port (
        DataInA: in  std_logic_vector(31 downto 0); 
        DataInB: in  std_logic_vector(7 downto 0); 
        AddressA: in  std_logic_vector(5 downto 0); 
        AddressB: in  std_logic_vector(7 downto 0); 
        ClockA: in  std_logic; 
        ClockB: in  std_logic; 
        ClockEnA: in  std_logic; 
        ClockEnB: in  std_logic; 
        WrA: in  std_logic; 
        WrB: in  std_logic; 
        ResetA: in  std_logic; 
        ResetB: in  std_logic; 
        QA: out  std_logic_vector(31 downto 0); 
        QB: out  std_logic_vector(7 downto 0));
end spi_dpram_32_to_8;

architecture Structure of spi_dpram_32_to_8 is

begin
        QA <= (others => '0');
        QB <= (others => '0');


end Structure;

