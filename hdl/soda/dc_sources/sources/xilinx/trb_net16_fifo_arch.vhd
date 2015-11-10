library ieee;

use ieee.std_logic_1164.all;
USE ieee.std_logic_signed.ALL;
USE IEEE.numeric_std.ALL;
use work.trb_net_std.all;

entity trb_net16_fifo is
    generic (
      USE_VENDOR_CORES : integer range 0 to 1 := c_YES;
      USE_DATA_COUNT   : integer range 0 to 1 := c_NO;
      DEPTH      : integer := 6
      );
    port (
      CLK    : in std_logic;
      RESET  : in std_logic;
      CLK_EN : in std_logic;
      DATA_IN         : in  std_logic_vector(c_DATA_WIDTH - 1 downto 0);
      PACKET_NUM_IN   : in  std_logic_vector(1 downto 0);
      WRITE_ENABLE_IN : in  std_logic;
      DATA_OUT        : out std_logic_vector(c_DATA_WIDTH - 1 downto 0);
      PACKET_NUM_OUT  : out std_logic_vector(1 downto 0);
      READ_ENABLE_IN  : in  std_logic;
      DATA_COUNT_OUT  : out std_logic_vector(10 downto 0);
      FULL_OUT        : out std_logic;
      EMPTY_OUT       : out std_logic
      );
end entity;

architecture arch_trb_net16_fifo of trb_net16_fifo is
-- attribute box_type: string;

  component xilinx_fifo_18x1k
    port (
    clk: IN std_logic;
    din: IN std_logic_VECTOR(17 downto 0);
    rd_en: IN std_logic;
    rst: IN std_logic;
    wr_en: IN std_logic;
    dout: OUT std_logic_VECTOR(17 downto 0);
    empty: OUT std_logic;
    full: OUT std_logic);
  end component;
-- attribute box_type of xilinx_fifo_18x1k : component is "black_box";


  component xilinx_fifo_18x16
  port (
  clk: IN std_logic;
  din: IN std_logic_VECTOR(17 downto 0);
  rd_en: IN std_logic;
  rst: IN std_logic;
  wr_en: IN std_logic;
  dout: OUT std_logic_VECTOR(17 downto 0);
  empty: OUT std_logic;
  full: OUT std_logic);
  end component;
-- attribute box_type of xilinx_fifo_18x16 : component is "black_box";

  component xilinx_fifo_18x32
    port (
      clk: IN std_logic;
      sinit: IN std_logic;
      din: IN std_logic_VECTOR(17 downto 0);
      wr_en: IN std_logic;
      rd_en: IN std_logic;
      dout: OUT std_logic_VECTOR(17 downto 0);
      full: OUT std_logic;
      empty: OUT std_logic
      );
  end component;
-- attribute box_type of xilinx_fifo_18x32 : component is "black_box";

  component xilinx_fifo_18x64
    port (
      clk: IN std_logic;
      sinit: IN std_logic;
      din: IN std_logic_VECTOR(17 downto 0);
      wr_en: IN std_logic;
      rd_en: IN std_logic;
      dout: OUT std_logic_VECTOR(17 downto 0);
      full: OUT std_logic;
      empty: OUT std_logic
      );
  end component;
-- attribute box_type of xilinx_fifo_18x64 : component is "black_box";

  component xilinx_fifo_lut
    generic (
      WIDTH : integer := 18;
      DEPTH : integer := 3
      );
    port (
      clk: IN std_logic;
      sinit: IN std_logic;
      din: IN std_logic_VECTOR(17 downto 0);
      wr_en: IN std_logic;
      rd_en: IN std_logic;
      dout: OUT std_logic_VECTOR(17 downto 0);
      full: OUT std_logic;
      empty: OUT std_logic
      );
  end component;

  component xilinx_fifo_18x1k_datacount is
    port (
      clk: IN std_logic;
      din: IN std_logic_VECTOR(17 downto 0);
      rd_en: IN std_logic;
      rst: IN std_logic;
      wr_en: IN std_logic;
      data_count: OUT std_logic_VECTOR(9 downto 0);
      dout: OUT std_logic_VECTOR(17 downto 0);
      empty: OUT std_logic;
      full: OUT std_logic
      );
  end component;
-- attribute box_type of xilinx_fifo_18x1k_datacount : component is "black_box";

  signal din, dout : std_logic_vector(c_DATA_WIDTH + 2-1 downto 0);
  signal data_counter : std_logic_vector(9 downto 0);

begin
  din(c_DATA_WIDTH - 1 downto 0) <= DATA_IN;
  din(c_DATA_WIDTH + 2 -1 downto c_DATA_WIDTH) <= PACKET_NUM_IN;
  DATA_OUT <= dout(c_DATA_WIDTH - 1 downto 0);
  PACKET_NUM_OUT <= dout(c_DATA_WIDTH + 2 - 1 downto c_DATA_WIDTH);
  DATA_COUNT_OUT <= '0' & data_counter;

  gen_FIFO6_Count : if DEPTH = 6 and USE_DATA_COUNT = 1 generate
    fifo:xilinx_fifo_18x1k_datacount
      port map (
        clk     => CLK,
        rd_en   => READ_ENABLE_IN,
        wr_en   => WRITE_ENABLE_IN,
        din     => din,
        rst     => RESET,
        data_count => data_counter,
        dout    => dout,
        full    => FULL_OUT,
        empty   => EMPTY_OUT
        );

  end generate;

  gen_FIFO6 : if DEPTH = 6 and USE_DATA_COUNT = 0 generate
    fifo:xilinx_fifo_18x1k
      port map (
        clk     => CLK,
        rd_en   => READ_ENABLE_IN,
        wr_en   => WRITE_ENABLE_IN,
        din     => din,
        rst     => RESET,
        dout    => dout,
        full    => FULL_OUT,
        empty   => EMPTY_OUT
        );
    data_counter <= (others => '0');
  end generate;

  gen_OWN_CORES : if USE_VENDOR_CORES = c_NO generate
    gen_FIFO_LUT : if DEPTH < 6 generate
      fifo:xilinx_fifo_lut
        generic map (
          WIDTH => c_DATA_WIDTH + 2,
          DEPTH => ((DEPTH+3))
          )
        port map (
          clk     => CLK,
          rd_en   => READ_ENABLE_IN,
          wr_en   => WRITE_ENABLE_IN,
          din     => din,
          sinit   => RESET,
          dout    => dout,
          full    => FULL_OUT,
          empty   => EMPTY_OUT
          );
      data_counter <= (others => '0');
    end generate;
  end generate;

  gen_XILINX_CORES : if USE_VENDOR_CORES = c_YES generate
    gen_FIFO1 : if DEPTH = 1  generate
      fifo:xilinx_fifo_18x16
        port map (
          clk     => CLK,
          rd_en   => READ_ENABLE_IN,
          wr_en   => WRITE_ENABLE_IN,
          din     => din,
          rst   => RESET,
          dout    => dout,
          full    => FULL_OUT,
          empty   => EMPTY_OUT
          );
      data_counter <= (others => '0');
    end generate;

    gen_FIFO2 : if DEPTH = 2  generate
      fifo:xilinx_fifo_18x32
        port map (
          clk     => CLK,
          rd_en   => READ_ENABLE_IN,
          wr_en   => WRITE_ENABLE_IN,
          din     => din,
          sinit   => RESET,
          dout    => dout,
          full    => FULL_OUT,
          empty   => EMPTY_OUT
          );
      data_counter <= (others => '0');
    end generate;


    gen_FIFO3 : if DEPTH = 3  generate
      fifo:xilinx_fifo_18x64
        port map (
          clk     => CLK,
          rd_en   => READ_ENABLE_IN,
          wr_en   => WRITE_ENABLE_IN,
          din     => din,
          sinit   => RESET,
          dout    => dout,
          full    => FULL_OUT,
          empty   => EMPTY_OUT
          );
      data_counter <= (others => '0');
    end generate;
  end generate;


end architecture;


