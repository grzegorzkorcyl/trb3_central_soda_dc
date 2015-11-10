-----------------------------------------------------------------------------------
-- Wrapper for asynchronous FIFO : width 32, 8 deep
-----------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY async_fifo_FWFT_16x32 IS
	PORT
	(
		rst                     : in std_logic;
		wr_clk                  : in std_logic;
		rd_clk                  : in std_logic;
		din                     : in std_logic_vector(31 downto 0);
		wr_en                   : in std_logic;
		rd_en                   : in std_logic;
		dout                    : out std_logic_vector(31 downto 0);
		full                    : out std_logic;
		empty                   : out std_logic
	);
END async_fifo_FWFT_16x32;


ARCHITECTURE Behavioral OF async_fifo_FWFT_16x32 IS
component async_fifo_16x32_ecp3
    port (
        Data: in  std_logic_vector(31 downto 0); 
        WrClock: in  std_logic; 
        RdClock: in  std_logic; 
        WrEn: in  std_logic; 
        RdEn: in  std_logic; 
        Reset: in  std_logic; 
        RPReset: in  std_logic; 
        Q: out  std_logic_vector(31 downto 0); 
        Empty: out  std_logic; 
        Full: out  std_logic);
end component;

signal ff_data_out : std_logic_vector (31 DOWNTO 0) := (others => '0');
signal ff_read_request : std_logic := '0';
signal ff_read_request_i : std_logic := '0';
signal ff_read_request_final : std_logic := '0';
signal ff_empty : std_logic := '0';
signal data_available_i : std_logic := '0';

BEGIN
-- data_available <= data_available_i;
process (rd_clk)
begin
	if rising_edge(rd_clk) then
		ff_read_request <= '0';
		if rst='1' then
			data_available_i <= '0';
		else
			if (ff_empty='0') and (data_available_i='0') and (rd_en='0') then
				if ff_read_request_i='1' then
					ff_read_request <= '0';
					dout <= ff_data_out;
					data_available_i <= '1';
					empty <= '0';
				else 
					if ff_read_request='0' then
						ff_read_request <= '1';
					end if;
					data_available_i <= '0';
--					empty <= '0';
				end if;
			elsif (ff_empty='0') and (data_available_i='0') and (rd_en='1') then  -- ignore
				if ff_read_request_i='1' then
					ff_read_request <= '0';
					dout <= ff_data_out;
					data_available_i <= '1';
					empty <= '0';
				else 
					ff_read_request <= '1';
					data_available_i <= '0';
--					empty <= '0';
				end if;
				
			elsif (ff_empty='0') and (data_available_i='1') and (rd_en='0') then  
				if ff_read_request_i='1' then -- should not occur
					ff_read_request <= '0';
					dout <= ff_data_out;
					data_available_i <= '1';
					empty <= '0';
				else 
					ff_read_request <= '0';
					data_available_i <= '1';
					empty <= '0';
				end if;
			elsif (ff_empty='0') and (data_available_i='1') and (rd_en='1') then  
				if ff_read_request_i='1' then
					ff_read_request <= '1';
					dout <= ff_data_out;
					data_available_i <= '1';
					empty <= '0';
				else 
					ff_read_request <= '1';
					data_available_i <= '0';
					empty <= '0';
				end if;

			elsif (ff_empty='1') and (data_available_i='0') and (rd_en='0') then  
				if ff_read_request_i='1' then
					ff_read_request <= '0';
					dout <= ff_data_out;
					data_available_i <= '1';
					empty <= '0';
				else 
					ff_read_request <= '0';
					data_available_i <= '0';
					empty <= '1';
				end if;
			elsif (ff_empty='1') and (data_available_i='0') and (rd_en='1') then -- ignore rd
				if ff_read_request_i='1' then
					ff_read_request <= '0';
					dout <= ff_data_out;
					data_available_i <= '1';
					empty <= '0';
				else 
					ff_read_request <= '0';
					data_available_i <= '0';
					empty <= '1';
				end if;

			elsif (ff_empty='1') and (data_available_i='1') and (rd_en='0') then  
				if ff_read_request_i='1' then
					ff_read_request <= '0';
					dout <= ff_data_out;
					data_available_i <= '1';
					empty <= '0';
				else 
					ff_read_request <= '0';
					data_available_i <= '1';
					empty <= '0';
				end if;
			elsif (ff_empty='1') and (data_available_i='1') and (rd_en='1') then  
				if ff_read_request_i='1' then
					ff_read_request <= '0';
					dout <= ff_data_out;
					data_available_i <= '1';
					empty <= '0';
				else 
					ff_read_request <= '0';
					data_available_i <= '0';
					empty <= '1';
				end if;
			end if;
		end if;
		ff_read_request_i <= ff_read_request_final;
	end if;
end process;

async_fifo_FWFT_16x32_ecp3_1: async_fifo_16x32_ecp3 port map(
		Data => din,
		WrClock => wr_clk,
		RdClock => rd_clk,
		WrEn => wr_en,
		RdEn => ff_read_request_final,
		Reset => rst,
        RPReset => rst,
		Q => ff_data_out,
		Empty => ff_empty,
		Full => full);

ff_read_request_final <= '1' when
	((rd_en='1') and (ff_empty='0') and (data_available_i='1')) or
	((rd_en='0') and (ff_empty='0') and (data_available_i='0') and (ff_read_request_i='0'))
	else '0';



END Behavioral;
