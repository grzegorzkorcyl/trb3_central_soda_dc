LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;


entity fifo_19x16_obuf is
port(
	Data          : in  std_logic_vector(18 downto 0);
	Clock         : in  std_logic;
	WrEn          : in  std_logic;
	RdEn          : in  std_logic;
	Reset         : in  std_logic;
	AmFullThresh  : in  std_logic_vector(3 downto 0);
	Q             : out std_logic_vector(18 downto 0);
	WCNT          : out std_logic_vector(4 downto 0);
	Empty         : out std_logic;
	Full          : out std_logic;
	AlmostFull    : out std_logic
);
end entity;





architecture fifo_19x16_obuf_arch of fifo_19x16_obuf is



component xilinx_fifo_19x16_obuf IS
port (
	clk: IN std_logic;
	din: IN std_logic_VECTOR(18 downto 0);
	prog_full_thresh: IN std_logic_VECTOR(3 downto 0);
	rd_en: IN std_logic;
	rst: IN std_logic;
	wr_en: IN std_logic;
	data_count: OUT std_logic_VECTOR(3 downto 0);
	dout: OUT std_logic_VECTOR(18 downto 0);
	empty: OUT std_logic;
	full: OUT std_logic;
	prog_full: OUT std_logic
);
end component;



begin

WCNT(4) <= '0';

the_xilinx_fifo_19x16_obuf: xilinx_fifo_19x16_obuf
port map(
	clk              => Clock,
	din              => Data,
	prog_full_thresh => AmFullThresh,
	rd_en            => RdEn,
	rst              => Reset,
	wr_en            => WrEn,
	data_count       => WCNT(3 downto 0),
	dout             => Q,
	empty            => Empty,
	full             => Full,
	prog_full        => AlmostFull
);

end architecture;
