library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;

package lattice_ecp2m_fifo is

  component fifo_var_oreg is
    generic(
      FIFO_WIDTH                   : integer range 1 to 64 := 36;
      FIFO_DEPTH                   : integer range 1 to 16 := 8
      );
    port(
      Data                         : in  std_logic_vector(FIFO_WIDTH-1 downto 0);
      Clock                        : in  std_logic;
      WrEn                         : in  std_logic;
      RdEn                         : in  std_logic;
      Reset                        : in  std_logic;
      AmFullThresh                 : in  std_logic_vector(FIFO_DEPTH-1 downto 0);
      Q                            : out std_logic_vector(FIFO_WIDTH-1 downto 0);
      WCNT                         : out std_logic_vector(FIFO_DEPTH downto 0);
      Empty                        : out std_logic;
      Full                         : out std_logic;
      AlmostFull                   : out std_logic
      );
  end component;

end package;
