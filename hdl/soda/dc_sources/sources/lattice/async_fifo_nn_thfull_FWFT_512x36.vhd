-----------------------------------------------------------------------------------
-- Wrapper for asynchronous FIFO : width 32, 8 deep
-----------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY async_fifo_nn_thfull_FWFT_512x36 IS
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
		rd_data_count           : out std_logic_vector(8 downto 0);
		prog_full               : out std_logic
	);
END async_fifo_nn_thfull_FWFT_512x36;


ARCHITECTURE Behavioral OF async_fifo_nn_thfull_FWFT_512x36 IS
component async_fifo_nn_thfull_512x36_ecp3
    port (
        Data: in  std_logic_vector(35 downto 0); 
        WrClock: in  std_logic; 
        RdClock: in  std_logic; 
        WrEn: in  std_logic; 
        RdEn: in  std_logic; 
        Reset: in  std_logic; 
        RPReset: in  std_logic; 
        Q: out  std_logic_vector(35 downto 0); 
        RCNT: out  std_logic_vector(9 downto 0); 
        Empty: out  std_logic; 
        Full: out  std_logic; 
        AlmostFull: out  std_logic);
end component;


signal fifo_dout                      : std_logic_vector (35 downto 0) := (others => '0');
signal middle_dout                    : std_logic_vector (35 downto 0) := (others => '0');
signal rd_data_count_i                : std_logic_vector (9 downto 0) := (others => '0');
signal fifo_empty                     : std_logic := '0';
signal will_update_middle             : std_logic := '0';
signal will_update_dout               : std_logic := '0';
signal middle_valid                   : std_logic := '0';
signal fifo_valid                     : std_logic := '0';
signal dout_valid                     : std_logic := '0';
signal fifo_rd_en                     : std_logic := '0';

begin
	
async_fifo_nn_thfull_512x36_ecp3_1: async_fifo_nn_thfull_512x36_ecp3 port map(
		Data => din,
		WrClock => wr_clk,
		RdClock => rd_clk,
		WrEn => wr_en,
		RdEn => fifo_rd_en,
		Reset => rst,
        RPReset => rst,
		Q => fifo_dout,
        RCNT => rd_data_count_i, 
		Empty => fifo_empty,
		Full => full,
        AlmostFull => prog_full);
rd_data_count <= (others => '1') when rd_data_count_i(9)='1' else rd_data_count_i(8 downto 0);
 
will_update_middle <= '1' when (fifo_valid='1') and  (middle_valid=will_update_dout) else '0';
will_update_dout <= '1' when ((middle_valid='1') or  (fifo_valid='1')) and ((rd_en='1') or (dout_valid='0')) else '0';
fifo_rd_en <= '1' when (fifo_empty='0') and (not ((middle_valid='1') and (dout_valid='1') and (fifo_valid='1'))) else '0';
empty <= not dout_valid;
	
process (rd_clk)
begin
	if rising_edge(rd_clk) then
		if rst='1' then
			fifo_valid <= '0';
			middle_valid <= '0';
			dout_valid <= '0';
			dout <= (others => '0');
			middle_dout <= (others => '0');
		else
            if (will_update_middle='1') then
               middle_dout <= fifo_dout;
            end if;
            if (will_update_dout='1') then
				if middle_valid='1' then
					dout <= middle_dout;
				else
					dout <= fifo_dout;
				end if;
            end if;
            if (fifo_rd_en='1') then
               fifo_valid <= '1';
            elsif ((will_update_middle='1') or (will_update_dout='1')) then
               fifo_valid <= '0';
            end if;
            if (will_update_middle='1') then
               middle_valid <= '1';
            elsif (will_update_dout='1') then
               middle_valid <= '0';
            end if;
            if (will_update_dout='1') then
               dout_valid <= '1';
            elsif (rd_en='1') then
               dout_valid <= '0';
			end if;
		end if;
	end if;
end process;

end Behavioral;
