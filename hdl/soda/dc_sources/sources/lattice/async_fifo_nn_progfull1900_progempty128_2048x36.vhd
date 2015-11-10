-----------------------------------------------------------------------------------
-- Wrapper for asynchronous FIFO : width 32, 8 deep
-----------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY async_fifo_nn_progfull1900_progempty128_2048x36 IS
	PORT
	(
		rst                     : in std_logic;
		wr_clk                  : in std_logic;
		rd_clk                  : in std_logic;
		din                     : in std_logic_vector(35 downto 0);
		wr_en                   : in std_logic;
		rd_en                   : in std_logic;
		dout                    : out std_logic_vector(35 downto 0);
		full                    : out std_logic;
		empty                   : out std_logic;
		rd_data_count           : out std_logic_vector(10 downto 0);
		prog_full               : out std_logic;
		prog_empty              : out std_logic
	);
END async_fifo_nn_progfull1900_progempty128_2048x36;


ARCHITECTURE Behavioral OF async_fifo_nn_progfull1900_progempty128_2048x36 IS
component async_fifo_nn_progfull1900_progempty128_2048x36_ecp3 is
    port (
        Data: in  std_logic_vector(35 downto 0); 
        WrClock: in  std_logic; 
        RdClock: in  std_logic; 
        WrEn: in  std_logic; 
        RdEn: in  std_logic; 
        Reset: in  std_logic; 
        RPReset: in  std_logic; 
        Q: out  std_logic_vector(35 downto 0); 
        RCNT: out  std_logic_vector(11 downto 0); 
        Empty: out  std_logic; 
        Full: out  std_logic; 
        AlmostEmpty: out  std_logic; 
        AlmostFull: out  std_logic);
end component;


signal rd_data_count_i                : std_logic_vector (11 downto 0) := (others => '0');

begin
	
async_fifo_nn_progfull1900_progempty128_2048x36_ecp3_1: async_fifo_nn_progfull1900_progempty128_2048x36_ecp3 port map(
		Data => din,
		WrClock => wr_clk,
		RdClock => rd_clk,
		WrEn => wr_en,
		RdEn => rd_en,
		Reset => rst,
        RPReset => rst,
		Q => dout,
        RCNT => rd_data_count_i, 
		Empty => empty,
		Full => full,
        AlmostEmpty => prog_empty ,
        AlmostFull => prog_full);
rd_data_count <= (others => '1') when rd_data_count_i(11)='1' else rd_data_count_i(10 downto 0);
 

end Behavioral;
