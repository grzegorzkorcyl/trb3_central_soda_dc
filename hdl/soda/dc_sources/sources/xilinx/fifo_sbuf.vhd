LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;


entity fifo_sbuf is
port(
	Data: in  std_logic_vector(18 downto 0); 
	Clock: in  std_logic; 
	WrEn: in  std_logic; 
	RdEn: in  std_logic; 
	Reset: in  std_logic; 
	Q: out  std_logic_vector(18 downto 0); 
	Empty: out  std_logic; 
	Full: out  std_logic; 
	AlmostFull: out  std_logic
);
end entity;





architecture fifo_sbuf_arch of fifo_sbuf is



component xilinx_fifo_sbuf IS
port (
	din: IN std_logic_VECTOR(18 downto 0);
	clk: IN std_logic;
	wr_en: IN std_logic;
	rd_en: IN std_logic;
	rst: IN std_logic;
	dout: OUT std_logic_VECTOR(18 downto 0);
	empty: OUT std_logic;
	full: OUT std_logic;
	almost_full: OUT std_logic
);
end component;



begin


the_xilinx_fifo_sbuf: xilinx_fifo_sbuf
port map(
	din              => Data,
	clk              => Clock,
	wr_en            => WrEn,
	rd_en            => RdEn,
	rst              => Reset,
	dout             => Q,
	empty            => Empty,
	full             => Full,
	almost_full	     => AlmostFull
);

end architecture;
