library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
library unisim;
use UNISIM.VComponents.all;
library work;
use work.trb_net_std.all;

entity trb_net_fifo_16bit_bram_dualport is
   generic(
     USE_STATUS_FLAGS : integer  := c_YES
     );
   port (
     read_clock_in:   IN  std_logic;
     write_clock_in:  IN  std_logic;
     read_enable_in:  IN  std_logic;
     write_enable_in: IN  std_logic;
     fifo_gsr_in:     IN  std_logic;
     write_data_in:   IN  std_logic_vector(17 downto 0);
     read_data_out:   OUT std_logic_vector(17 downto 0);
     full_out:        OUT std_logic;
     empty_out:       OUT std_logic;
     fifostatus_out:  OUT std_logic_vector(3 downto 0);
     valid_read_out:  OUT std_logic;
     almost_empty_out:OUT std_logic;
     almost_full_out :OUT std_logic
    );
end entity trb_net_fifo_16bit_bram_dualport;

architecture trb_net_fifo_16bit_bram_dualport_arch of trb_net_fifo_16bit_bram_dualport is

  signal buf_empty_out, buf_full_out : std_logic;

attribute box_type: string;
  component xilinx_fifo_dualport_18x1k
    port (
      din: IN std_logic_VECTOR(17 downto 0);
      rd_clk: IN std_logic;
      rd_en: IN std_logic;
      rst: IN std_logic;
      wr_clk: IN std_logic;
      wr_en: IN std_logic;
      dout: OUT std_logic_VECTOR(17 downto 0);
      empty: OUT std_logic;
      full: OUT std_logic;
      valid: OUT std_logic);
  end component;
attribute box_type of xilinx_fifo_dualport_18x1k : component is "black_box";

BEGIN
  FIFO_DP_BRAM : xilinx_fifo_dualport_18x1k
    port map (
      din => write_data_in,
      rd_clk => read_clock_in,
      rd_en => read_enable_in,
      rst => fifo_gsr_in,
      wr_clk => write_clock_in,
      wr_en => write_enable_in,
      dout => read_data_out,
      empty => buf_empty_out,
      full => buf_full_out,
      valid => valid_read_out
      );

empty_out <= buf_empty_out;
full_out  <= buf_full_out;
almost_full_out <= buf_full_out;
almost_empty_out <= buf_empty_out;
fifostatus_out <= (others => '0');
end architecture;

