--Media interface for Lattice ECP3 using PCS at 2GHz


LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
--USE IEEE.numeric_std.all;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.med_sync_define.all;

entity med_ecp3_quad_sfp_sync is
	generic (
		RX_CLOCK_FROM_FABRIC    : boolean := TRUE
	);
	port(
		CLOCK              : in  std_logic; -- serdes reference clock
		SYSCLK             : in  std_logic; -- 100 MHz main clock net
		RESET              : in  std_logic; -- synchronous reset
		CLEAR              : in  std_logic; -- asynchronous reset

		TX_DATA0           : in std_logic_vector(7 downto 0); -- clock on CLOCK
		TX_DATA1           : in std_logic_vector(7 downto 0);      
		TX_DATA2           : in std_logic_vector(7 downto 0);      
		TX_DATA3           : in std_logic_vector(7 downto 0);	
		TX_CHAR_K0         : in std_logic;
		TX_CHAR_K1         : in std_logic;
		TX_CHAR_K2         : in std_logic;
		TX_CHAR_K3         : in std_logic;
		TX_CLOCK0          : out std_logic;
		TX_CLOCK1          : out std_logic;
		TX_CLOCK2          : out std_logic;
		TX_CLOCK3          : out std_logic;
		RX_DATA0           : out std_logic_vector(7 downto 0); -- clock on CLOCK
		RX_DATA1           : out std_logic_vector(7 downto 0);      
		RX_DATA2           : out std_logic_vector(7 downto 0);      
		RX_DATA3           : out std_logic_vector(7 downto 0);	
		RX_CHAR_K0         : out std_logic;
		RX_CHAR_K1         : out std_logic;
		RX_CHAR_K2         : out std_logic;
		RX_CHAR_K3         : out std_logic;
		RX_ERROR0          : out std_logic;
		RX_ERROR1          : out std_logic;
		RX_ERROR2          : out std_logic;
		RX_ERROR3          : out std_logic;
		RX_CLOCK0          : out std_logic;
		RX_CLOCK1          : out std_logic;
		RX_CLOCK2          : out std_logic;
		RX_CLOCK3          : out std_logic;

		--SFP Connection
		SD_RXD_P_IN        : in std_logic_vector(0 to 3);
		SD_RXD_N_IN        : in std_logic_vector(0 to 3);
		SD_TXD_P_OUT       : out std_logic_vector(0 to 3);
		SD_TXD_N_OUT       : out std_logic_vector(0 to 3);
		SD_LOS_IN          : in std_logic_vector(0 to 3);  -- SFP Loss Of Signal ('0' = OK, '1' = no signal)
		SD_TXDIS_OUT       : out std_logic_vector(0 to 3); -- SFP disable

		-- Status and control port
		RESET_DONE         : out std_logic_vector (0 to 3);
		RX_ALLOW           : out std_logic_vector (0 to 3);
		TX_ALLOW           : out std_logic_vector (0 to 3);
		LEDs_link_ok       : out std_logic_vector(0 to 3);
		LEDs_rx            : out std_logic_vector(0 to 3); 
		LEDs_tx            : out std_logic_vector(0 to 3);
		STAT_OP            : out std_logic_vector (15 downto 0);
		CTRL_OP            : in  std_logic_vector (15 downto 0) := (others => '0')
	);
end entity;


architecture med_ecp3_quad_sfp_sync_arch of med_ecp3_quad_sfp_sync is

component serdes_sync_200_full is
   GENERIC (USER_CONFIG_FILE    :  String := "serdes_sync_200_full.txt");
 port (
-- CH0 --
    hdinp_ch0, hdinn_ch0    :   in std_logic;
    hdoutp_ch0, hdoutn_ch0   :   out std_logic;
    sci_sel_ch0    :   in std_logic;
    rxiclk_ch0    :   in std_logic;
    txiclk_ch0    :   in std_logic;
    rx_full_clk_ch0   :   out std_logic;
    rx_half_clk_ch0   :   out std_logic;
    tx_full_clk_ch0   :   out std_logic;
    tx_half_clk_ch0   :   out std_logic;
    fpga_rxrefclk_ch0    :   in std_logic;
    txdata_ch0    :   in std_logic_vector (7 downto 0);
    tx_k_ch0    :   in std_logic;
    tx_force_disp_ch0    :   in std_logic;
    tx_disp_sel_ch0    :   in std_logic;
    rxdata_ch0   :   out std_logic_vector (7 downto 0);
    rx_k_ch0   :   out std_logic;
    rx_disp_err_ch0   :   out std_logic;
    rx_cv_err_ch0   :   out std_logic;
    rx_serdes_rst_ch0_c    :   in std_logic;
    sb_felb_ch0_c    :   in std_logic;
    sb_felb_rst_ch0_c    :   in std_logic;
    tx_pcs_rst_ch0_c    :   in std_logic;
    tx_pwrup_ch0_c    :   in std_logic;
    rx_pcs_rst_ch0_c    :   in std_logic;
    rx_pwrup_ch0_c    :   in std_logic;
    rx_los_low_ch0_s   :   out std_logic;
    lsm_status_ch0_s   :   out std_logic;
    rx_cdr_lol_ch0_s   :   out std_logic;
    tx_div2_mode_ch0_c   : in std_logic;
    rx_div2_mode_ch0_c   : in std_logic;
-- CH1 --
    hdinp_ch1, hdinn_ch1    :   in std_logic;
    hdoutp_ch1, hdoutn_ch1   :   out std_logic;
    sci_sel_ch1    :   in std_logic;
    rxiclk_ch1    :   in std_logic;
    txiclk_ch1    :   in std_logic;
    rx_full_clk_ch1   :   out std_logic;
    rx_half_clk_ch1   :   out std_logic;
    tx_full_clk_ch1   :   out std_logic;
    tx_half_clk_ch1   :   out std_logic;
    fpga_rxrefclk_ch1    :   in std_logic;
    txdata_ch1    :   in std_logic_vector (7 downto 0);
    tx_k_ch1    :   in std_logic;
    tx_force_disp_ch1    :   in std_logic;
    tx_disp_sel_ch1    :   in std_logic;
    rxdata_ch1   :   out std_logic_vector (7 downto 0);
    rx_k_ch1   :   out std_logic;
    rx_disp_err_ch1   :   out std_logic;
    rx_cv_err_ch1   :   out std_logic;
    rx_serdes_rst_ch1_c    :   in std_logic;
    sb_felb_ch1_c    :   in std_logic;
    sb_felb_rst_ch1_c    :   in std_logic;
    tx_pcs_rst_ch1_c    :   in std_logic;
    tx_pwrup_ch1_c    :   in std_logic;
    rx_pcs_rst_ch1_c    :   in std_logic;
    rx_pwrup_ch1_c    :   in std_logic;
    rx_los_low_ch1_s   :   out std_logic;
    lsm_status_ch1_s   :   out std_logic;
    rx_cdr_lol_ch1_s   :   out std_logic;
    tx_div2_mode_ch1_c   : in std_logic;
    rx_div2_mode_ch1_c   : in std_logic;
-- CH2 --
    hdinp_ch2, hdinn_ch2    :   in std_logic;
    hdoutp_ch2, hdoutn_ch2   :   out std_logic;
    sci_sel_ch2    :   in std_logic;
    rxiclk_ch2    :   in std_logic;
    txiclk_ch2    :   in std_logic;
    rx_full_clk_ch2   :   out std_logic;
    rx_half_clk_ch2   :   out std_logic;
    tx_full_clk_ch2   :   out std_logic;
    tx_half_clk_ch2   :   out std_logic;
    fpga_rxrefclk_ch2    :   in std_logic;
    txdata_ch2    :   in std_logic_vector (7 downto 0);
    tx_k_ch2    :   in std_logic;
    tx_force_disp_ch2    :   in std_logic;
    tx_disp_sel_ch2    :   in std_logic;
    rxdata_ch2   :   out std_logic_vector (7 downto 0);
    rx_k_ch2   :   out std_logic;
    rx_disp_err_ch2   :   out std_logic;
    rx_cv_err_ch2   :   out std_logic;
    rx_serdes_rst_ch2_c    :   in std_logic;
    sb_felb_ch2_c    :   in std_logic;
    sb_felb_rst_ch2_c    :   in std_logic;
    tx_pcs_rst_ch2_c    :   in std_logic;
    tx_pwrup_ch2_c    :   in std_logic;
    rx_pcs_rst_ch2_c    :   in std_logic;
    rx_pwrup_ch2_c    :   in std_logic;
    rx_los_low_ch2_s   :   out std_logic;
    lsm_status_ch2_s   :   out std_logic;
    rx_cdr_lol_ch2_s   :   out std_logic;
    tx_div2_mode_ch2_c   : in std_logic;
    rx_div2_mode_ch2_c   : in std_logic;
-- CH3 --
    hdinp_ch3, hdinn_ch3    :   in std_logic;
    hdoutp_ch3, hdoutn_ch3   :   out std_logic;
    sci_sel_ch3    :   in std_logic;
    rxiclk_ch3    :   in std_logic;
    txiclk_ch3    :   in std_logic;
    rx_full_clk_ch3   :   out std_logic;
    rx_half_clk_ch3   :   out std_logic;
    tx_full_clk_ch3   :   out std_logic;
    tx_half_clk_ch3   :   out std_logic;
    fpga_rxrefclk_ch3    :   in std_logic;
    txdata_ch3    :   in std_logic_vector (7 downto 0);
    tx_k_ch3    :   in std_logic;
    tx_force_disp_ch3    :   in std_logic;
    tx_disp_sel_ch3    :   in std_logic;
    rxdata_ch3   :   out std_logic_vector (7 downto 0);
    rx_k_ch3   :   out std_logic;
    rx_disp_err_ch3   :   out std_logic;
    rx_cv_err_ch3   :   out std_logic;
    rx_serdes_rst_ch3_c    :   in std_logic;
    sb_felb_ch3_c    :   in std_logic;
    sb_felb_rst_ch3_c    :   in std_logic;
    tx_pcs_rst_ch3_c    :   in std_logic;
    tx_pwrup_ch3_c    :   in std_logic;
    rx_pcs_rst_ch3_c    :   in std_logic;
    rx_pwrup_ch3_c    :   in std_logic;
    rx_los_low_ch3_s   :   out std_logic;
    lsm_status_ch3_s   :   out std_logic;
    rx_cdr_lol_ch3_s   :   out std_logic;
    tx_div2_mode_ch3_c   : in std_logic;
    rx_div2_mode_ch3_c   : in std_logic;
---- Miscillaneous ports
    sci_wrdata    :   in std_logic_vector (7 downto 0);
    sci_addr    :   in std_logic_vector (5 downto 0);
    sci_rddata   :   out std_logic_vector (7 downto 0);
    sci_sel_quad    :   in std_logic;
    sci_rd    :   in std_logic;
    sci_wrn    :   in std_logic;
    fpga_txrefclk  :   in std_logic;
    tx_serdes_rst_c    :   in std_logic;
    tx_pll_lol_qd_s   :   out std_logic;
    tx_sync_qd_c    :   in std_logic;
    rst_qd_c    :   in std_logic;
    serdes_rst_qd_c    :   in std_logic);
end component;

component async_fifo_16x9 is
port (
		rst                     : in std_logic;
		wr_clk                  : in std_logic;
		rd_clk                  : in std_logic;
		din                     : in std_logic_vector(8 downto 0);
		wr_en                   : in std_logic;
		rd_en                   : in std_logic;
		dout                    : out std_logic_vector(8 downto 0);
		full                    : out std_logic;
		empty                   : out std_logic
	);
end component;


-- Placer Directives
attribute HGROUP : string;
-- for whole architecture
attribute HGROUP of med_ecp3_quad_sfp_sync_arch : architecture  is "media_interface_group";
attribute syn_sharing : string;
attribute syn_sharing of med_ecp3_quad_sfp_sync_arch : architecture is "off";
attribute syn_keep     : boolean;
attribute syn_preserve : boolean;

type array_4x2_type is array(0 to 3) of std_logic_vector(1 downto 0);
type array_4x4_type is array(0 to 3) of std_logic_vector(3 downto 0);
type array_4x8_type is array(0 to 3) of std_logic_vector(7 downto 0);
type array_4x16_type is array(0 to 3) of std_logic_vector(15 downto 0);
type array_4x19_type is array(0 to 3) of std_logic_vector(18 downto 0);


signal clk_rx_full       : std_logic_vector(0 to 3);
signal clk_tx_full       : std_logic_vector(0 to 3);

signal rx_rst_n          : std_logic_vector(0 to 3);
signal tx_rst_n          : std_logic_vector(0 to 3);
signal rx_serdes_rst     : std_logic_vector(0 to 3);
signal tx_serdes_rst     : std_logic;
signal tx_pcs_rst        : std_logic_vector(0 to 3);
signal rx_pcs_rst        : std_logic_vector(0 to 3);
signal rst_qd            : std_logic;
signal rst_qd_S          : std_logic_vector(0 to 3);
signal serdes_rst_qd     : std_logic;
signal sd_los_i          : std_logic_vector(0 to 3);
signal sd_los_q          : std_logic_vector(0 to 3);

signal rx_los_low        : std_logic_vector(0 to 3);
signal lsm_status        : std_logic_vector(0 to 3);
signal rx_cdr_lol        : std_logic_vector(0 to 3);
signal tx_pll_lol        : std_logic;

signal tx_allow_i         : std_logic_vector(0 to 3);
signal rx_allow_i         : std_logic_vector(0 to 3);
signal tx_allow_q         : std_logic_vector(0 to 3);
signal rx_allow_q         : std_logic_vector(0 to 3);

signal rx_fsm_state       : array_4x4_type;
signal tx_fsm_state       : array_4x4_type;
signal debug_reg          : std_logic_vector(63 downto 0);
signal start_timer        : array_4x19_type := (others => (others => '0'));

signal led_ok                 : std_logic_vector(0 to 3);
signal led_tx, last_led_tx    : std_logic_vector(0 to 3);
signal led_rx, last_led_rx    : std_logic_vector(0 to 3);
signal timer    : unsigned(20 downto 0);

signal tx_char_k              : std_logic_vector(0 to 3) := (others => '0');
signal tx_data_i              : array_4x8_type;
signal tx_sync_qd_c           : std_logic;
signal tx_sync_qd_c_S         : std_logic := '0';
		
signal rx_char_k              : std_logic_vector(0 to 3) := (others => '0');
signal rx_data_i              : array_4x8_type;
signal rx_error_i             : std_logic_vector(0 to 3) := (others => '0');

signal txdelaycounter_i       : array_4x8_type := (others => (others => '0'));

attribute syn_keep of tx_sync_qd_c     : signal is true; 
attribute syn_preserve of tx_sync_qd_c     : signal is true; 

attribute syn_keep of clk_tx_full     : signal is true; 
attribute syn_preserve of clk_tx_full     : signal is true; 


begin

TX_CLOCK0 <= clk_tx_full(0);
TX_CLOCK1 <= clk_tx_full(1);
TX_CLOCK2 <= clk_tx_full(2);
TX_CLOCK3 <= clk_tx_full(3);

RX_CLOCK0 <= clk_rx_full(0);
RX_CLOCK1 <= clk_rx_full(1);
RX_CLOCK2 <= clk_rx_full(2);
RX_CLOCK3 <= clk_rx_full(3);


SD_TXDIS_OUT <= "0000"; 
RX_ALLOW <= rx_allow_q;
TX_ALLOW <= tx_allow_q;

process(clk_tx_full(0))
begin
	if (rising_edge(clk_tx_full(0))) then 
		tx_data_i(0) <= TX_DATA0;
		tx_char_k(0) <= TX_CHAR_K0;
	end if;
end process;
process(clk_tx_full(1))
begin
	if (rising_edge(clk_tx_full(1))) then 
		tx_data_i(1) <= TX_DATA1;
		tx_char_k(1) <= TX_CHAR_K1;
	end if;
end process;
process(clk_tx_full(2))
begin
	if (rising_edge(clk_tx_full(2))) then 
		tx_data_i(2) <= TX_DATA2;
		tx_char_k(2) <= TX_CHAR_K2;
	end if;
end process;
process(clk_tx_full(3))
begin
	if (rising_edge(clk_tx_full(3))) then 
		tx_data_i(3) <= TX_DATA3;
		tx_char_k(3) <= TX_CHAR_K3;
	end if;
end process;		

process(clk_rx_full(0))
begin
	if (rising_edge(clk_rx_full(0))) then
		RX_CHAR_K0 <= rx_char_k(0);
		RX_DATA0 <= rx_data_i(0);
		RX_ERROR0 <= rx_error_i(0);
	end if;
end process;
process(clk_rx_full(1))
begin
	if (rising_edge(clk_rx_full(1))) then
		RX_CHAR_K1 <= rx_char_k(1);
		RX_DATA1 <= rx_data_i(1);
		RX_ERROR1 <= rx_error_i(1);
	end if;
end process;
process(clk_rx_full(2))
begin
	if (rising_edge(clk_rx_full(2))) then
		RX_CHAR_K2 <= rx_char_k(2);
		RX_DATA2 <= rx_data_i(2);
		RX_ERROR2 <= rx_error_i(2);
	end if;
end process;
process(clk_rx_full(3))
begin
	if (rising_edge(clk_rx_full(3))) then
		RX_CHAR_K3 <= rx_char_k(3);
		RX_DATA3 <= rx_data_i(3);
		RX_ERROR3 <= rx_error_i(3);
	end if;
end process;
		


-------------------------------------------------      
-- Serdes
-------------------------------------------------      

THE_SERDES : serdes_sync_200_full 
  port map(
    hdinp_ch0            => SD_RXD_P_IN(0),
    hdinn_ch0            => SD_RXD_N_IN(0),
    hdoutp_ch0           => SD_TXD_P_OUT(0),
    hdoutn_ch0           => SD_TXD_N_OUT(0),
    rxiclk_ch0           => clk_rx_full(0),
    txiclk_ch0           => clk_tx_full(0),
    rx_full_clk_ch0      => clk_rx_full(0),
    rx_half_clk_ch0      => open,
    tx_full_clk_ch0      => clk_tx_full(0),
    tx_half_clk_ch0      => open,
    fpga_rxrefclk_ch0    => CLOCK,
    txdata_ch0           => tx_data_i(0),
    tx_k_ch0             => tx_char_k(0),
    tx_force_disp_ch0    => '0',
    tx_disp_sel_ch0      => '0',
    rxdata_ch0           => rx_data_i(0),
    rx_k_ch0             => rx_char_k(0),
    rx_disp_err_ch0      => open,
    rx_cv_err_ch0        => rx_error_i(0),
    rx_serdes_rst_ch0_c  => rx_serdes_rst(0),
    sb_felb_ch0_c        => '0',
    sb_felb_rst_ch0_c    => '0',
    tx_pcs_rst_ch0_c     => tx_pcs_rst(0),
    tx_pwrup_ch0_c       => '1',
    rx_pcs_rst_ch0_c     => rx_pcs_rst(0),
    rx_pwrup_ch0_c       => '1',
    rx_los_low_ch0_s     => rx_los_low(0),
    lsm_status_ch0_s     => lsm_status(0),
    rx_cdr_lol_ch0_s     => rx_cdr_lol(0),
    tx_div2_mode_ch0_c   => '0',
    rx_div2_mode_ch0_c   => '0',
    
    hdinp_ch1            => SD_RXD_P_IN(1),
    hdinn_ch1            => SD_RXD_N_IN(1),
    hdoutp_ch1           => SD_TXD_P_OUT(1),
    hdoutn_ch1           => SD_TXD_N_OUT(1),
    rxiclk_ch1           => clk_rx_full(1),
    txiclk_ch1           => clk_tx_full(1),
    rx_full_clk_ch1      => clk_rx_full(1),
    rx_half_clk_ch1      => open,
    tx_full_clk_ch1      => clk_tx_full(1),
    tx_half_clk_ch1      => open,
    fpga_rxrefclk_ch1    => CLOCK,
    txdata_ch1           => tx_data_i(1),
    tx_k_ch1             => tx_char_k(1),
    tx_force_disp_ch1    => '0',
    tx_disp_sel_ch1      => '0',
    rxdata_ch1           => rx_data_i(1),
    rx_k_ch1             => rx_char_k(1),
    rx_disp_err_ch1      => open,
    rx_cv_err_ch1        => rx_error_i(1),
    rx_serdes_rst_ch1_c  => rx_serdes_rst(1),
    sb_felb_ch1_c        => '0',
    sb_felb_rst_ch1_c    => '0',
    tx_pcs_rst_ch1_c     => tx_pcs_rst(1),
    tx_pwrup_ch1_c       => '1',
    rx_pcs_rst_ch1_c     => rx_pcs_rst(1),
    rx_pwrup_ch1_c       => '1',
    rx_los_low_ch1_s     => rx_los_low(1),
    lsm_status_ch1_s     => lsm_status(1),
    rx_cdr_lol_ch1_s     => rx_cdr_lol(1),
    tx_div2_mode_ch1_c   => '0',
    rx_div2_mode_ch1_c   => '0',

    hdinp_ch2            => SD_RXD_P_IN(2),
    hdinn_ch2            => SD_RXD_N_IN(2),
    hdoutp_ch2           => SD_TXD_P_OUT(2),
    hdoutn_ch2           => SD_TXD_N_OUT(2),
    rxiclk_ch2           => clk_rx_full(2),
    txiclk_ch2           => clk_tx_full(2),
    rx_full_clk_ch2      => clk_rx_full(2),
    rx_half_clk_ch2      => open,
    tx_full_clk_ch2      => clk_tx_full(2),
    tx_half_clk_ch2      => open,
    fpga_rxrefclk_ch2    => CLOCK,
    txdata_ch2           => tx_data_i(2),
    tx_k_ch2             => tx_char_k(2),
    tx_force_disp_ch2    => '0',
    tx_disp_sel_ch2      => '0',
    rxdata_ch2           => rx_data_i(2),
    rx_k_ch2             => rx_char_k(2),
    rx_disp_err_ch2      => open,
    rx_cv_err_ch2        => rx_error_i(2),
    rx_serdes_rst_ch2_c  => rx_serdes_rst(2),
    sb_felb_ch2_c        => '0',
    sb_felb_rst_ch2_c    => '0',
    tx_pcs_rst_ch2_c     => tx_pcs_rst(2),
    tx_pwrup_ch2_c       => '1',
    rx_pcs_rst_ch2_c     => rx_pcs_rst(2),
    rx_pwrup_ch2_c       => '1',
    rx_los_low_ch2_s     => rx_los_low(2),
    lsm_status_ch2_s     => lsm_status(2),
    rx_cdr_lol_ch2_s     => rx_cdr_lol(2),
    tx_div2_mode_ch2_c   => '0',
    rx_div2_mode_ch2_c   => '0',
    
    hdinp_ch3            => SD_RXD_P_IN(3),
    hdinn_ch3            => SD_RXD_N_IN(3),
    hdoutp_ch3           => SD_TXD_P_OUT(3),
    hdoutn_ch3           => SD_TXD_N_OUT(3),
    rxiclk_ch3           => clk_rx_full(3),
    txiclk_ch3           => clk_tx_full(3),
    rx_full_clk_ch3      => clk_rx_full(3),
    rx_half_clk_ch3      => open,
    tx_full_clk_ch3      => clk_tx_full(3),
    tx_half_clk_ch3      => open,
    fpga_rxrefclk_ch3    => CLOCK,
    txdata_ch3           => tx_data_i(3),
    tx_k_ch3             => tx_char_k(3),
    tx_force_disp_ch3    => '0',
    tx_disp_sel_ch3      => '0',
    rxdata_ch3           => rx_data_i(3),
    rx_k_ch3             => rx_char_k(3),
    rx_disp_err_ch3      => open,
    rx_cv_err_ch3        => rx_error_i(3),
    rx_serdes_rst_ch3_c  => rx_serdes_rst(3),
    sb_felb_ch3_c        => '0',
    sb_felb_rst_ch3_c    => '0',
    tx_pcs_rst_ch3_c     => tx_pcs_rst(3),
    tx_pwrup_ch3_c       => '1',
    rx_pcs_rst_ch3_c     => rx_pcs_rst(3),
    rx_pwrup_ch3_c       => '1',
    rx_los_low_ch3_s     => rx_los_low(3),
    lsm_status_ch3_s     => lsm_status(3),
    rx_cdr_lol_ch3_s     => rx_cdr_lol(3),
    tx_div2_mode_ch3_c   => '0',
    rx_div2_mode_ch3_c   => '0', 
    
    SCI_WRDATA           => (others => '0'),
    SCI_ADDR             => (others => '0'),
    SCI_RDDATA           => open,
    SCI_SEL_QUAD         => '0',
    SCI_SEL_CH0          => '0',
    SCI_SEL_CH1          => '0',
    SCI_SEL_CH2          => '0',
    SCI_SEL_CH3          => '0',
    SCI_RD               => '0',
    SCI_WRN              => '0',
    
    fpga_txrefclk        => CLOCK,
    tx_serdes_rst_c      => tx_serdes_rst,
    tx_pll_lol_qd_s      => tx_pll_lol,
    tx_sync_qd_c         => tx_sync_qd_c, -- ?? Multiple channel transmit synchronization
    rst_qd_c             => rst_qd,
    serdes_rst_qd_c      => serdes_rst_qd

    );
--	rst_qd <= CLEAR;
    tx_serdes_rst <= '0'; --no function
    serdes_rst_qd <= '0'; --included in rst_qd

    
-------------------------------------------------      
-- Reset FSM & Link states
-------------------------------------------------
synctox2: process(CLOCK)
begin
	if (rising_edge(CLOCK)) then 
		if rst_qd_S/="0000" then
			rst_qd <= '1';
		else
			rst_qd <= '0';
		end if;
		tx_sync_qd_c <= tx_sync_qd_c_S;
	end if;
end process;

process(CLOCK)
variable prev_state_ok : std_logic_vector(0 to 3) := "0000";
variable cntr : std_logic_vector(3 downto 0) := "0000";
begin
	if (rising_edge(CLOCK)) then 
		if ((tx_fsm_state(0)=x"5") and (prev_state_ok(0)='0')) or
		   ((tx_fsm_state(1)=x"5") and (prev_state_ok(1)='0')) or
		   ((tx_fsm_state(2)=x"5") and (prev_state_ok(2)='0')) or
		   ((tx_fsm_state(3)=x"5") and (prev_state_ok(3)='0')) then
			tx_sync_qd_c_S <= not tx_sync_qd_c_S;
			cntr := (others => '0');
		else -- double toggle, necessary?
			if cntr="1110" then
				tx_sync_qd_c_S <= not tx_sync_qd_c_S;
			end if;
			if cntr/="1111" then
				cntr := cntr+1;
			end if;			
		end if;
		for i in 0 to 3 loop
			if (tx_fsm_state(i)=x"5") then
				prev_state_ok(i) := '1';
			else
				prev_state_ok(i) := '0';
			end if;
		end loop;
	end if;
end process;

GENERATE_RESET_FSM: for i in 0 to 3 generate  

THE_SFP_CLOCK_SYNC: signal_sync
	generic map(
		DEPTH => 1,
		WIDTH => 1
	)
	port map(
		RESET => '0',
		D_IN(0) => SD_LOS_IN(i),
		CLK0 => CLOCK,
		CLK1 => CLOCK,
		D_OUT(0) => sd_los_i(i)
	);
	
THE_SFP_SYSCLK_SYNC: signal_sync
	generic map(
		DEPTH => 1,
		WIDTH => 3
	)
	port map(
		RESET => '0',
		D_IN(0) => SD_LOS_IN(i),
		D_IN(1) => rx_allow_i(i),
		D_IN(2) => tx_allow_i(i),
		CLK0 => SYSCLK,
		CLK1 => SYSCLK,
		D_OUT(0) => sd_los_q(i),
		D_OUT(1) => rx_allow_q(i),
		D_OUT(2) => tx_allow_q(i)
	);

process(CLOCK)
begin
	if (rising_edge(CLOCK)) then 
		tx_rst_n(i) <= not (CLEAR);
		rx_rst_n(i) <= not (CLEAR or sd_los_i(i));
	end if;
end process;


PROC_ALLOW_TX : process(CLOCK)
begin
	if (rising_edge(CLOCK)) then 
		tx_allow_i(i) <= '0';
		if tx_fsm_state(i) = x"5" then
			RESET_DONE(i) <= '1';
			if txdelaycounter_i(i)(txdelaycounter_i(i)'left)='0' then
				txdelaycounter_i(i) <= txdelaycounter_i(i)+1;
			else
				tx_allow_i(i) <= '1';
			end if;
		else
			txdelaycounter_i(i) <= (others => '0');
			RESET_DONE(i) <= '0';
		end if;
	end if;
end process;

THE_RX_FSM : rx_reset_fsm
  port map(
    RST_N               => rx_rst_n(i),
    RX_REFCLK           => CLOCK,
    TX_PLL_LOL_QD_S     => tx_pll_lol,
    RX_SERDES_RST_CH_C  => rx_serdes_rst(i),
    RX_CDR_LOL_CH_S     => rx_cdr_lol(i),
    RX_LOS_LOW_CH_S     => rx_los_low(i),
    RX_PCS_RST_CH_C     => rx_pcs_rst(i),
    WA_POSITION         => "0000", -- for master
    STATE_OUT           => rx_fsm_state(i) -- ready when x"6"
    );

THE_TX_FSM : tx_reset_fsm
  port map(
    RST_N           => tx_rst_n(i),
    TX_REFCLK       => CLOCK,
    TX_PLL_LOL_QD_S => tx_pll_lol,
    RST_QD_C        => rst_qd_S(i), -- //
    TX_PCS_RST_CH_C => tx_pcs_rst(i),
    STATE_OUT       => tx_fsm_state(i) -- ready when x"5"
    );

--Slave enables RX/TX when sync is done, Master waits additional time to make sure link is stable
PROC_ALLOW : process(CLOCK)
begin
	if (rising_edge(CLOCK)) then 
		if rx_fsm_state(i) = x"6" and (start_timer(i)(start_timer(i)'left) = '1') then
			rx_allow_i(i) <= '1';
		else
			rx_allow_i(i) <= '0';
		end if;
		if rx_fsm_state(i) = x"6" and (start_timer(i)(start_timer(i)'left) = '1') then
--			tx_allow_i(i) <= '1';
		else
--			tx_allow_i(i) <= '0';
		end if;
	end if;
end process;

PROC_START_TIMER : process(CLOCK)
begin
	if (rising_edge(CLOCK)) then 
		if (rx_fsm_state(i) = x"6") then
			if start_timer(i)(start_timer(i)'left) = '0' then
				start_timer(i) <= start_timer(i) + 1;
			end if;  
		else
			start_timer(i) <= (others => '0');
		end if;
	end if;
end process;

end generate;
    

-------------------------------------------------      
-- Generate LED signals
------------------------------------------------- 


-- GENERATE_LED_SIGNALS: for i in 0 to 3 generate  
-- led_ok(i) <= rx_allow_i(i) and tx_allow_i(i); --  when rising_edge(SYSCLK); 
-- led_rx(i) <= ((not rx_char_k(i)) or led_rx(i)) and not timer(20); --  when rising_edge(SYSCLK);
-- led_tx(i) <= ((not tx_char_k(i)) or led_tx(i) or sd_los_i(i))  and not timer(20) when rising_edge(SYSCLK);
-- -- led_dlm <= (led_dlm or rx_dlm_i) and not timer(20) when rising_edge(SYSCLK);
-- LEDs_link_ok(i) <= not led_ok(i);
-- LEDs_rx(i) <= not led_rx(i);
-- LEDs_tx(i) <= not led_tx(i);
-- end generate;

-- rx_allow_q <= rx_allow_i when rising_edge(SYSCLK);
-- tx_allow_q <= tx_allow_i when rising_edge(SYSCLK);

-- ROC_TIMER : process begin
  -- wait until rising_edge(SYSCLK);
  -- timer <= timer + 1 ;
  -- if timer(20) = '1' then
    -- timer <= (others => '0');
    -- last_led_rx <= led_rx ;
    -- last_led_tx <= led_tx;
  -- end if;
-- end process;


process(SYSCLK)
begin
	if rising_edge(SYSCLK) then
		for i in 0 to 3 loop
			led_ok(i) <= rx_allow_q(i) and tx_allow_q(i);
			led_rx(i) <= ((not rx_char_k(i)) or led_rx(i)) and not timer(20); 
			led_tx(i) <= ((not tx_char_k(i)) or led_tx(i) or sd_los_q(i))  and not timer(20);
			-- led_dlm <= (led_dlm or rx_dlm_i) and not timer(20);
			LEDs_link_ok(i) <= not led_ok(i);
			LEDs_rx(i) <= not led_rx(i);
			LEDs_tx(i) <= not led_tx(i);
		end loop;
	
		timer <= timer + 1 ;
		if timer(20) = '1' then
			timer <= (others => '0');
			last_led_rx <= led_rx ;
			last_led_tx <= led_tx;
		end if;
	end if;
end process;

-------------------------------------------------      
-- Debug Registers
-------------------------------------------------            
debug_reg(2 downto 0)   <= rx_fsm_state(0)(2 downto 0);
debug_reg(3)            <= rx_serdes_rst(0);
debug_reg(4)            <= CLEAR;
debug_reg(5)            <= tx_allow_q(0);
debug_reg(6)            <= rx_los_low(0);
debug_reg(7)            <= rx_cdr_lol(0);

debug_reg(8)            <= RESET;
debug_reg(9)            <= tx_pll_lol;
debug_reg(10)           <= rx_allow_q(0);
debug_reg(11)           <= CTRL_OP(15);
debug_reg(12)           <= '0';
debug_reg(13)           <= '0';
debug_reg(14)           <= sd_los_i(0);
debug_reg(15)           <= rx_pcs_rst(0);
-- debug_reg(31 downto 24) <= tx_data;

debug_reg(16)           <= '0';
debug_reg(17)           <= tx_allow_i(0);
debug_reg(18)           <= RESET;
debug_reg(19)           <= CLEAR;
debug_reg(31 downto 20) <= (others => '0');

debug_reg(35 downto 32) <= (others => '0');
debug_reg(36)           <= '0';
debug_reg(39 downto 37) <= "000";
debug_reg(63 downto 40) <= (others => '0');

STAT_OP(15) <= '0';
STAT_OP(14) <= '0';
STAT_OP(13) <= '0';
STAT_OP(12) <= '0'; -- led_dlm or last_led_dlm;
STAT_OP(11) <= led_tx(0) or last_led_tx(0);
STAT_OP(10) <= led_rx(0) or last_led_rx(0);
STAT_OP(9)  <= led_ok(0);
STAT_OP(8 downto 4) <= (others => '0');
STAT_OP(3 downto 0) <= x"0" when rx_allow_q(0) = '1' and tx_allow_q(0) = '1' else x"7";
--STAT_OP(3 downto 0) <= x"0" when rx_allow_q = '1' and tx_allow_q = '1' else ("01" & tx_pll_lol & rx_cdr_lol);
end architecture;

