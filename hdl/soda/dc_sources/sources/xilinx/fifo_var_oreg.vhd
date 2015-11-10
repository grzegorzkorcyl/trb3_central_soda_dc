library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;

entity fifo_var_oreg is
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
end entity;

architecture fifo_var_oreg_arch of fifo_var_oreg is

component fifo_18x512_oreg
  port (
    clk               : in std_logic;
    din               : in std_logic_vector(17 downto 0);
    prog_full_thresh  : in std_logic_vector(8 downto 0);
    rd_en             : in std_logic;
    rst               : in std_logic;
    wr_en             : in std_logic;
    data_count        : out std_logic_vector(8 downto 0);
    dout              : out std_logic_vector(17 downto 0);
    empty             : out std_logic;
    full              : out std_logic;
    prog_full         : out std_logic
    );
end component;

component fifo_36x512_oreg
  port (
    clk               : in std_logic;
    din               : in std_logic_vector(35 downto 0);
    prog_full_thresh  : in std_logic_vector(8 downto 0);
    rd_en             : in std_logic;
    rst               : in std_logic;
    wr_en             : in std_logic;
    data_count        : out std_logic_vector(8 downto 0);
    dout              : out std_logic_vector(35 downto 0);
    empty             : out std_logic;
    full              : out std_logic;
    prog_full         : out std_logic
    );
end component;


component fifo_36x16k_oreg
  port (
    clk               : in std_logic;
    din               : in std_logic_vector(35 downto 0);
    prog_full_thresh  : in std_logic_vector(13 downto 0);
    rd_en             : in std_logic;
    rst               : in std_logic;
    wr_en             : in std_logic;
    data_count        : out std_logic_vector(13 downto 0);
    dout              : out std_logic_vector(35 downto 0);
    empty             : out std_logic;
    full              : out std_logic;
    prog_full         : out std_logic
    );
end component;

component fifo_36x32k_oreg
  port (
    clk               : in std_logic;
    din               : in std_logic_vector(35 downto 0);
    prog_full_thresh  : in std_logic_vector(14 downto 0);
    rd_en             : in std_logic;
    rst               : in std_logic;
    wr_en             : in std_logic;
    data_count        : out std_logic_vector(14 downto 0);
    dout              : out std_logic_vector(35 downto 0);
    empty             : out std_logic;
    full              : out std_logic;
    prog_full         : out std_logic
    );
end component;

begin

assert    (FIFO_DEPTH >= 13 and FIFO_DEPTH <= 14 and FIFO_WIDTH = 36)
       or (FIFO_DEPTH >= 9 and FIFO_DEPTH <= 9 and FIFO_WIDTH = 18)
       or (FIFO_DEPTH >= 9 and FIFO_DEPTH <= 9 and FIFO_WIDTH = 36)
          report "Selected data buffer size not implemented: depth - "&integer'image(FIFO_DEPTH)& ", width + 4 : " &integer'image(FIFO_WIDTH) severity error;



  gen_36_16k : if FIFO_WIDTH = 36 and FIFO_DEPTH = 14  generate
    THE_FIFO :  fifo_36x16k_oreg
      port map(
        din                    =>  Data,
        clk                    =>  Clock,
        wr_en                  =>  WrEn,
        rd_en                  =>  RdEn,
        rst                    =>  Reset,
        prog_full_thresh       =>  AmFullThresh,
        dout                   =>  Q,
        data_count             =>  WCNT(13 downto 0),
        empty                  =>  Empty,
        full                   =>  Full,
        prog_full              =>  AlmostFull
        );
  end generate;


  gen_36_32k : if FIFO_WIDTH = 36 and FIFO_DEPTH = 15  generate
    THE_FIFO :  fifo_36x32k_oreg
      port map(
        din                    =>  Data,
        clk                    =>  Clock,
        wr_en                  =>  WrEn,
        rd_en                  =>  RdEn,
        rst                    =>  Reset,
        prog_full_thresh       =>  AmFullThresh,
        dout                   =>  Q,
        data_count             =>  WCNT(14 downto 0),
        empty                  =>  Empty,
        full                   =>  Full,
        prog_full              =>  AlmostFull
        );
  end generate;

  gen_36_512 : if FIFO_WIDTH = 36 and FIFO_DEPTH = 9  generate
    THE_FIFO :  fifo_36x512_oreg
      port map(
        din                    =>  Data,
        clk                    =>  Clock,
        wr_en                  =>  WrEn,
        rd_en                  =>  RdEn,
        rst                    =>  Reset,
        prog_full_thresh       =>  AmFullThresh,
        dout                   =>  Q,
        data_count             =>  WCNT(8 downto 0),
        empty                  =>  Empty,
        full                   =>  Full,
        prog_full              =>  AlmostFull
        );
  end generate;

  gen_18_512 : if FIFO_WIDTH = 18 and FIFO_DEPTH = 9  generate
    THE_FIFO :  fifo_18x512_oreg
      port map(
        din                    =>  Data,
        clk                    =>  Clock,
        wr_en                  =>  WrEn,
        rd_en                  =>  RdEn,
        rst                    =>  Reset,
        prog_full_thresh       =>  AmFullThresh,
        dout                   =>  Q,
        data_count             =>  WCNT(8 downto 0),
        empty                  =>  Empty,
        full                   =>  Full,
        prog_full              =>  AlmostFull
        );
  end generate;



end architecture;
