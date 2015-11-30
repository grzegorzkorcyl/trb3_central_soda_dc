LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE IEEE.std_logic_UNSIGNED.ALL;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb_net16_hub_func.all;

--Ports:
--        LVL1/IPU       SCtrl
--  0     FPGA 1         FPGA 1
--  1     FPGA 2         FPGA 2
--  2     FPGA 3         FPGA 3
--  3     FPGA 4         FPGA 4
--  4     opt. link      opt. link
--  5     CTS read-out   internal         0 1 -   X X O   --downlink only
--  6     CTS TRG        Sctrl GbE        2 3 4   X X X   --uplink only

-- MII_NUMBER        => 5,
-- INT_NUMBER        => 5,
-- INT_CHANNELS      => (0,1,0,1,3),

-- No trigger sent to optical link, slow control receiving possible
-- MII_IS_UPLINK        => (0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0);
-- MII_IS_DOWNLINK      => (1,1,1,1,0,1,0,0,0,0,0,0,0,0,0,0,0);
-- MII_IS_UPLINK_ONLY   => (0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0);

-- Trigger sent to optical link, slow control receiving possible
-- MII_IS_UPLINK        => (0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0);
-- MII_IS_DOWNLINK      => (1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0);
-- MII_IS_UPLINK_ONLY   => (0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0);
-- & disable port 4 in c0 and c1 -- no triggers from/to optical link

--Slow Control
--    0 -    7  Readout endpoint common status
--   80 -   AF  Hub status registers
--   C0 -   CF  Hub control registers
-- 4000 - 40FF  Hub status registers
-- 7000 - 72FF  Readout endpoint registers
-- 8100 - 83FF  GbE configuration & status
-- A000 - A1FF  CTS configuration & status
-- D000 - D13F  Flash Programming



entity trb_net16_hub_streaming_port_sctrl_cts is
  generic(
  --hub control
    INIT_ADDRESS            : std_logic_vector(15 downto 0) := x"F3C0";
    INIT_UNIQUE_ID          : std_logic_vector(63 downto 0) := (others => '0');
    COMPILE_TIME            : std_logic_vector(31 downto 0) := x"00000000";
    INCLUDED_FEATURES       : std_logic_vector(63 downto 0) := (others => '0');
    HARDWARE_VERSION        : std_logic_vector(31 downto 0) := x"9000CE00";
    INIT_ENDPOINT_ID        : std_logic_vector(15 downto 0) := x"0005";
    BROADCAST_BITMASK       : std_logic_vector(7 downto 0)  := x"7E";
    CLOCK_FREQUENCY         : integer range 1 to 200 := 100;
    USE_ONEWIRE             : integer range 0 to 2 := c_YES;
    BROADCAST_SPECIAL_ADDR  : std_logic_vector(7 downto 0) := x"FF";
    RDO_ADDITIONAL_PORT     : integer range 1 to 7 := 2; -- real limit to be explored
    RDO_DATA_BUFFER_DEPTH            : integer range 9 to 14         := 9;
    RDO_DATA_BUFFER_FULL_THRESH      : integer range 0 to 2**14-2    := 2**8;
    RDO_HEADER_BUFFER_DEPTH          : integer range 9 to 14         := 9;
    RDO_HEADER_BUFFER_FULL_THRESH    : integer range 2**8 to 2**14-2 := 2**8;
    --media interfaces & hub ports
    MII_NUMBER              : integer range 2 to c_MAX_MII_PER_HUB := 5;
    MII_IS_UPLINK           : hub_mii_config_t := (0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0);
    MII_IS_DOWNLINK         : hub_mii_config_t := (1,1,1,1,0,1,0,0,0,0,0,0,0,0,0,0,0);
    MII_IS_UPLINK_ONLY      : hub_mii_config_t := (0,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,0);
    INIT_CTRL_REGS          : std_logic_vector(2**(4)*32-1 downto 0) :=
                                         x"00000000_00000000_00000000_00000000" &
                                         x"00000000_00000000_00000000_00000000" &
                                         x"00000000_00000000_00003077_00000000" &
                                         x"FFFFFFFF_00000000_FFFFFFFF_FFFFFFFF"    
    );

  port(
    CLK                          : in std_logic;
    RESET                        : in std_logic;
    CLK_EN                       : in std_logic;

-- Media Interfaces ----------------------------------------------------------------
    MED_DATAREADY_OUT            : out std_logic_vector (MII_NUMBER-1 downto 0);
    MED_DATA_OUT                 : out std_logic_vector (MII_NUMBER*16-1 downto 0);
    MED_PACKET_NUM_OUT           : out std_logic_vector (MII_NUMBER*3-1 downto 0);
    MED_READ_IN                  : in  std_logic_vector (MII_NUMBER-1 downto 0);
    MED_DATAREADY_IN             : in  std_logic_vector (MII_NUMBER-1 downto 0);
    MED_DATA_IN                  : in  std_logic_vector (MII_NUMBER*16-1 downto 0);
    MED_PACKET_NUM_IN            : in  std_logic_vector (MII_NUMBER*3-1 downto 0);
    MED_READ_OUT                 : out std_logic_vector (MII_NUMBER-1 downto 0);
    MED_STAT_OP                  : in  std_logic_vector (MII_NUMBER*16-1 downto 0);
    MED_CTRL_OP                  : out std_logic_vector (MII_NUMBER*16-1 downto 0);

-- Gbe Read-out Path ---------------------------------------------------------------
    --Event information coming from CTS for GbE
    GBE_CTS_NUMBER_OUT             : out std_logic_vector (15 downto 0);
    GBE_CTS_CODE_OUT               : out std_logic_vector (7  downto 0);
    GBE_CTS_INFORMATION_OUT        : out std_logic_vector (7  downto 0);
    GBE_CTS_READOUT_TYPE_OUT       : out std_logic_vector (3  downto 0);
    GBE_CTS_START_READOUT_OUT      : out std_logic;
    --Information sent to CTS
    GBE_CTS_READOUT_FINISHED_IN    : in  std_logic;      --no more data, end transfer, send TRM
    GBE_CTS_STATUS_BITS_IN         : in  std_logic_vector (31 downto 0);
    -- Data from Frontends
    GBE_FEE_DATA_OUT               : out std_logic_vector (15 downto 0);
    GBE_FEE_DATAREADY_OUT          : out std_logic;
    GBE_FEE_READ_IN                : in  std_logic;  --must be high when idle, otherwise you will never get a dataready
    GBE_FEE_STATUS_BITS_OUT        : out std_logic_vector (31 downto 0);
    GBE_FEE_BUSY_OUT               : out std_logic;

-- Gbe Sctrl Input -----------------------------------------------------------------
    GSC_INIT_DATAREADY_IN          : in  std_logic;
    GSC_INIT_DATA_IN               : in  std_logic_vector (15 downto 0);
    GSC_INIT_PACKET_NUM_IN         : in  std_logic_vector (2  downto 0);
    GSC_INIT_READ_OUT              : out std_logic;
    GSC_REPLY_DATAREADY_OUT        : out std_logic;
    GSC_REPLY_DATA_OUT             : out std_logic_vector (15 downto 0);
    GSC_REPLY_PACKET_NUM_OUT       : out std_logic_vector (2  downto 0);
    GSC_REPLY_READ_IN              : in  std_logic;
    GSC_BUSY_OUT                   : out std_logic;

-- CTS Request Sending -------------------------------------------------------------
    --LVL1 trigger
    CTS_TRG_SEND_IN                : in  std_logic;
    CTS_TRG_TYPE_IN                : in  std_logic_vector (3  downto 0);
    CTS_TRG_NUMBER_IN              : in  std_logic_vector (15 downto 0);
    CTS_TRG_INFORMATION_IN         : in  std_logic_vector (23 downto 0);
    CTS_TRG_RND_CODE_IN            : in  std_logic_vector (7  downto 0);
    CTS_TRG_STATUS_BITS_OUT        : out std_logic_vector (31 downto 0);
    CTS_TRG_BUSY_OUT               : out std_logic;
    --IPU Channel
    CTS_IPU_SEND_IN                : in  std_logic;
    CTS_IPU_TYPE_IN                : in  std_logic_vector (3  downto 0);
    CTS_IPU_NUMBER_IN              : in  std_logic_vector (15 downto 0);
    CTS_IPU_INFORMATION_IN         : in  std_logic_vector (7  downto 0);
    CTS_IPU_RND_CODE_IN            : in  std_logic_vector (7  downto 0);
    -- Receiver port
    CTS_IPU_STATUS_BITS_OUT        : out std_logic_vector (31 downto 0);
    CTS_IPU_BUSY_OUT               : out std_logic;
    
-- CTS Data Readout ----------------------------------------------------------------
    --Trigger In
    RDO_TRIGGER_IN                 : in  std_logic;
    RDO_TRG_DATA_VALID_OUT         : out std_logic;
    RDO_VALID_TIMING_TRG_OUT       : out std_logic;
    RDO_VALID_NOTIMING_TRG_OUT     : out std_logic;
    RDO_INVALID_TRG_OUT            : out std_logic;
    
    RDO_TRG_TYPE_OUT               : out std_logic_vector(3 downto 0);
    RDO_TRG_CODE_OUT               : out std_logic_vector(7 downto 0);
    RDO_TRG_INFORMATION_OUT        : out std_logic_vector(23 downto 0);
    RDO_TRG_NUMBER_OUT             : out std_logic_vector(15 downto 0);
      
    --Data out
    RDO_TRG_STATUSBITS_IN          : in  std_logic_vector (31 downto 0) := (others => '0');
    RDO_DATA_IN                    : in  std_logic_vector (31 downto 0) := (others => '0');
    RDO_DATA_WRITE_IN              : in  std_logic := '0';
    RDO_DATA_FINISHED_IN           : in  std_logic := '0'; 
    
    RDO_ADDITIONAL_DATA            : in  std_logic_vector(RDO_ADDITIONAL_PORT*32-1 downto 0);
    RDO_ADDITIONAL_WRITE           : in  std_logic_vector(RDO_ADDITIONAL_PORT-1 downto 0);
    RDO_ADDITIONAL_FINISHED        : in  std_logic_vector(RDO_ADDITIONAL_PORT-1 downto 0);
    RDO_ADDITIONAL_STATUSBITS_IN   : in  std_logic_vector(RDO_ADDITIONAL_PORT*32-1 downto 0) := (others => '0');
    
-- Slow Control --------------------------------------------------------------------
    COMMON_STAT_REGS               : out std_logic_vector (std_COMSTATREG*32-1 downto 0);  --Status of common STAT regs
    COMMON_CTRL_REGS               : out std_logic_vector (std_COMCTRLREG*32-1 downto 0);  --Status of common STAT regs
    ONEWIRE                        : inout std_logic;
    ONEWIRE_MONITOR_IN             : in  std_logic;
    ONEWIRE_MONITOR_OUT            : out std_logic;
    MY_ADDRESS_OUT                 : out std_logic_vector (15 downto 0);
    UNIQUE_ID_OUT                  : out std_logic_vector (63 downto 0);
    --REGIO INTERFACE  (0x8000 - 0xFFFF)
    REGIO_ADDR_OUT                 : out std_logic_vector (16-1 downto 0);
    REGIO_READ_ENABLE_OUT          : out std_logic;
    REGIO_WRITE_ENABLE_OUT         : out std_logic;
    REGIO_DATA_OUT                 : out std_logic_vector (32-1 downto 0);
    REGIO_DATA_IN                  : in  std_logic_vector (32-1 downto 0) := (others => '0');
    REGIO_DATAREADY_IN             : in  std_logic := '0';
    REGIO_NO_MORE_DATA_IN          : in  std_logic := '0';
    REGIO_WRITE_ACK_IN             : in  std_logic := '0';
    REGIO_UNKNOWN_ADDR_IN          : in  std_logic := '0';
    REGIO_TIMEOUT_OUT              : out std_logic;
    EXTERNAL_SEND_RESET            : in  std_logic := '0';
    TIMER_TICKS_OUT                : out std_logic_vector(1 downto 0);
    
-- Debug and Status Ports ----------------------------------------------------------
    HUB_STAT_CHANNEL               : out std_logic_vector (4*16-1 downto 0);
    HUB_STAT_GEN                   : out std_logic_vector (31 downto 0);
    MPLEX_CTRL                     : in  std_logic_vector (MII_NUMBER*32-1 downto 0);
    MPLEX_STAT                     : out std_logic_vector (MII_NUMBER*32-1 downto 0);
    STAT_REGS                      : out std_logic_vector (8*32-1 downto 0);  --Status of custom STAT regs
    STAT_CTRL_REGS                 : out std_logic_vector (8*32-1 downto 0);  --Status of custom CTRL regs
    --Debugging registers
    STAT_DEBUG                     : out std_logic_vector (31 downto 0);      --free status regs for debugging
    CTRL_DEBUG                     : in  std_logic_vector (31 downto 0)       --free control regs for debugging
    );
end entity;


architecture trb_net16_hub_streaming_arch of trb_net16_hub_streaming_port_sctrl_cts is

constant mii : integer := MII_NUMBER;
constant DATA_INTERFACE_NUMBER : integer := RDO_ADDITIONAL_PORT + 1;
  
signal hub_init_dataready_out    : std_logic_vector(5 downto 0);
signal hub_reply_dataready_out   : std_logic_vector(5 downto 0);
signal hub_init_dataready_in     : std_logic_vector(5 downto 0);
signal hub_reply_dataready_in    : std_logic_vector(5 downto 0);
signal hub_init_read_out         : std_logic_vector(5 downto 0);
signal hub_reply_read_out        : std_logic_vector(5 downto 0);
signal hub_init_read_in          : std_logic_vector(5 downto 0);
signal hub_reply_read_in         : std_logic_vector(5 downto 0);
signal hub_init_data_out         : std_logic_vector(80 downto 0);
signal hub_reply_data_out        : std_logic_vector(80 downto 0);
signal hub_init_data_in          : std_logic_vector(80 downto 0);
signal hub_reply_data_in         : std_logic_vector(80 downto 0);
signal hub_init_packet_num_out   : std_logic_vector(15 downto 0);
signal hub_reply_packet_num_out  : std_logic_vector(15 downto 0);
signal hub_init_packet_num_in    : std_logic_vector(15 downto 0);
signal hub_reply_packet_num_in   : std_logic_vector(15 downto 0);

-- signal cts_init_data_out       : std_logic_vector(15 downto 0);
-- signal cts_init_dataready_out  : std_logic;
-- signal cts_init_packet_num_out : std_logic_vector(2 downto 0);
-- signal cts_init_read_in        : std_logic;

-- signal cts_reply_data_in       : std_logic_vector(15 downto 0);
-- signal cts_reply_dataready_in  : std_logic;
-- signal cts_reply_packet_num_in : std_logic_vector(2 downto 0);
-- signal cts_reply_read_out      : std_logic;

signal common_ctrl             : std_logic_vector(std_COMCTRLREG*32-1 downto 0);
signal common_stat             : std_logic_vector(std_COMSTATREG*32-1 downto 0);
signal common_ctrl_strobe      : std_logic_vector(std_COMCTRLREG-1 downto 0);
signal common_stat_strobe      : std_logic_vector(std_COMSTATREG-1 downto 0);
signal my_address              : std_logic_vector(15 downto 0);

-- signal io_dataready_out  : std_logic_vector(7 downto 0);
-- signal io_data_out       : std_logic_vector(127 downto 0);
-- signal io_packet_num_out : std_logic_vector(23 downto 0);
-- signal io_read_in        : std_logic_vector(7 downto 0);
-- 
-- signal io_dataready_in   : std_logic_vector(3 downto 0);
-- signal io_read_out       : std_logic_vector(3 downto 0);
-- signal io_data_in        : std_logic_vector(4*16-1 downto 0);
-- signal io_packet_num_in  : std_logic_vector(4*3-1 downto 0);

signal reset_i : std_logic;

signal HUB_MED_CTRL_OP   : std_logic_vector(mii*16-1 downto 0);
signal reset_i_mux_io    : std_logic;

signal hub_make_network_reset : std_logic;
-- signal hub_got_network_reset  : std_logic;
signal timer_ticks            : std_logic_vector(1 downto 0);
signal hub_ctrl_debug         : std_logic_vector(31 downto 0);
signal buf_HUB_STAT_GEN       : std_logic_vector(31 downto 0);

signal trg_apl_data_out         : std_logic_vector(15 downto 0);
signal trg_apl_dataready_out    : std_logic;
signal trg_apl_error_pattern_in : std_logic_vector(31 downto 0);
signal trg_apl_packet_num_out   : std_logic_vector(2 downto 0);
signal trg_apl_read_in          : std_logic;
signal trg_apl_run_out          : std_logic;
signal trg_apl_typ_out          : std_logic_vector(2 downto 0);
signal tmp_hub_init_data_in     : std_logic_vector(15 downto 0);
signal reg_ext_trg_information  : std_logic_vector(15 downto 0);

signal lvl1_error_pattern   : std_logic_vector(31 downto 0);
signal lvl1_handler_error_pattern : std_logic_vector(31 downto 0);
signal lvl1_trg_code        : std_logic_vector(7 downto 0);
signal lvl1_trg_information : std_logic_vector(23 downto 0);
signal lvl1_trg_number      : std_logic_vector(15 downto 0);
signal lvl1_trg_received    : std_logic;
signal lvl1_trg_release     : std_logic;
signal lvl1_handler_trg_release : std_logic;
signal lvl1_trg_type        : std_logic_vector(3 downto 0);
signal lvl1_valid_i         : std_logic;
signal lvl1_valid_notiming_i: std_logic;
signal lvl1_valid_timing_i  : std_logic;
signal lvl1_invalid_i       : std_logic;
signal lvl1_data_valid_i    : std_logic;
signal reset_ipu_i  : std_logic;

-- signal int_spike_detected         : std_logic;
-- signal int_lvl1_spurious_trg      : std_logic;
-- signal int_lvl1_timeout_detected  : std_logic;
-- signal int_multiple_trg           : std_logic;
-- signal int_lvl1_missing_tmg_trg   : std_logic;
-- signal int_lvl1_long_trg          : std_logic;
signal int_trigger_num            : std_logic_vector(15 downto 0);
signal int_lvl1_delay             : std_logic_vector(15 downto 0);
signal stat_lvl1_handler          : std_logic_vector(63 downto 0);
signal stat_counters_lvl1_handler : std_logic_vector(79 downto 0);

signal dummy                   : std_logic_vector(300 downto 0);
signal write_enable            : std_logic_vector(6 downto 0);
signal read_enable             : std_logic_vector(6 downto 0);
signal last_write_enable       : std_logic_vector(6 downto 0);
signal last_read_enable        : std_logic_vector(6 downto 0);   

signal stat_buffer_i       : std_logic_vector(31 downto 0);
signal stat_buffer_unknown : std_logic;
signal stat_buffer_read    : std_logic;
signal stat_buffer_ready   : std_logic;
signal stat_buffer_address : std_logic_vector(4 downto 0);
signal stat_handler_i : std_logic_vector(127 downto 0);
signal stat_data_buffer_level  : std_logic_vector (DATA_INTERFACE_NUMBER*32-1 downto 0);
signal stat_header_buffer_level: std_logic_vector (31 downto 0); 

signal ipu_number_i            : std_logic_vector (15 downto 0);
signal ipu_readout_type_i      : std_logic_vector ( 3 downto 0);
signal ipu_information_i       : std_logic_vector ( 7 downto 0);
signal ipu_start_readout_i     : std_logic;
signal ipu_data_i              : std_logic_vector (31 downto 0);
signal ipu_dataready_i         : std_logic;
signal ipu_readout_finished_i  : std_logic;
signal ipu_read_i              : std_logic;
signal ipu_length_i            : std_logic_vector (15 downto 0);
signal ipu_error_pattern_i     : std_logic_vector (31 downto 0);


signal rdo_apl_data_in           : std_logic_vector(15 downto 0);
signal rdo_apl_packet_num_in     : std_logic_vector(2 downto 0);
signal rdo_apl_dataready_in      : std_logic;
signal rdo_apl_read_out          : std_logic;
signal rdo_apl_short_transfer_in : std_logic;
signal rdo_apl_dtype_in          : std_logic_vector(3 downto 0);
signal rdo_apl_error_pattern_in  : std_logic_vector(31 downto 0);
signal rdo_apl_send_in           : std_logic;
signal rdo_apl_data_out          : std_logic_vector(15 downto 0);
signal rdo_apl_packet_num_out    : std_logic_vector(2 downto 0);
signal rdo_apl_typ_out           : std_logic_vector(2 downto 0);
signal rdo_apl_dataready_out     : std_logic;
signal rdo_apl_read_in           : std_logic;
signal rdo_apl_run_out           : std_logic;
signal rdo_apl_seqnr_out         : std_logic_vector(7 downto 0);
signal rdo_apl_length_in         : std_logic_vector(15 downto 0);


signal dbuf_addr         : std_logic_vector(3 downto 0);
signal dbuf_data_in      : std_logic_vector(31 downto 0);
signal dbuf_dataready    : std_logic;
signal dbuf_read_enable  : std_logic;
signal dbuf_unknown_addr : std_logic;
signal tbuf_dataready    : std_logic;
signal tbuf_read_enable  : std_logic;

signal regio_addr_i        : std_logic_vector(15 downto 0);
signal regio_data_out_i    : std_logic_vector(31 downto 0);
signal regio_data_in_i     : std_logic_vector(31 downto 0);
signal regio_read_enable_i : std_logic;
signal regio_write_enable_i: std_logic;
signal regio_timeout_i     : std_logic;
signal regio_dataready_i   : std_logic;
signal regio_write_ack_i   : std_logic;
signal regio_no_more_data_i: std_logic;
signal regio_unknown_addr_i: std_logic;
signal external_send_reset_long  : std_logic;
signal external_send_reset_timer : std_logic;
begin

---------------------------------------------------------------------
-- Reset
---------------------------------------------------------------------
--13: reset sequence received
--14: not connected
--15: send reset sequence

  SYNC_RESET_MUX_IO : process(CLK)
    begin
      if rising_edge(CLK) then
        reset_i        <= RESET;
        reset_i_mux_io <= RESET; --MED_STAT_OP(mii*16+14) or 
      end if;
    end process;


--generate media resync
  gen_resync : for i in 0 to mii-1 generate
    MED_CTRL_OP(14+i*16 downto i*16) <= HUB_MED_CTRL_OP(14+i*16 downto i*16);
    MED_CTRL_OP(15+i*16) <= hub_make_network_reset or HUB_MED_CTRL_OP(15+i*16);
  end generate;
--     MED_CTRL_OP(13+mii*16 downto mii*16) <= (others => '0');
--     MED_CTRL_OP(14+mii*16) <= '0';
--     MED_CTRL_OP(15+mii*16) <= hub_make_network_reset;


  hub_make_network_reset <= external_send_reset_long or MED_STAT_OP(15+4*16); --MED_STAT_OP(15) or MED_STAT_OP(15+(mii-1)*16);

  make_gbe_reset : process begin
    wait until rising_edge(CLK);
    if(EXTERNAL_SEND_RESET = '1') then
      external_send_reset_long <= '1';
      external_send_reset_timer <= '1';
    end if;
    if timer_ticks(0) = '1' then
      external_send_reset_timer <= '0';
      external_send_reset_long  <= external_send_reset_timer;
    end if;
  end process;  
  
---------------------------------------------------------------------
-- Connecting I/O
---------------------------------------------------------------------

  COMMON_CTRL_REGS <= common_ctrl;
  MY_ADDRESS_OUT  <= my_address;


---------------------------------------------------------------------
-- The Hub
---------------------------------------------------------------------
  THE_HUB : trb_net16_hub_base
    generic map (
    --hub control
      HUB_CTRL_CHANNELNUM        => c_SLOW_CTRL_CHANNEL,
      HUB_CTRL_DEPTH             => c_FIFO_BRAM,
      HUB_USED_CHANNELS          => (c_YES,c_YES,c_NO,c_YES),
      USE_CHECKSUM               => (c_NO,c_YES,c_YES,c_YES),
      USE_VENDOR_CORES           => c_YES,
      IBUF_SECURE_MODE           => c_NO,
      INIT_ADDRESS               => INIT_ADDRESS,
      INIT_UNIQUE_ID             => INIT_UNIQUE_ID,
      INIT_CTRL_REGS             => INIT_CTRL_REGS,
      COMPILE_TIME               => COMPILE_TIME,
      INCLUDED_FEATURES          => INCLUDED_FEATURES,
      HARDWARE_VERSION           => HARDWARE_VERSION,
      HUB_CTRL_BROADCAST_BITMASK => BROADCAST_BITMASK,
      CLOCK_FREQUENCY            => CLOCK_FREQUENCY,
      USE_ONEWIRE                => USE_ONEWIRE,
      BROADCAST_SPECIAL_ADDR     => BROADCAST_SPECIAL_ADDR,
      MII_NUMBER                 => mii,
      MII_IBUF_DEPTH             => std_HUB_IBUF_DEPTH,
      MII_IS_UPLINK              => MII_IS_UPLINK,
      MII_IS_DOWNLINK            => MII_IS_DOWNLINK,
      MII_IS_UPLINK_ONLY         => MII_IS_UPLINK_ONLY,
      INIT_ENDPOINT_ID           => INIT_ENDPOINT_ID,
      INT_NUMBER                 => 5,
      INT_CHANNELS               => (0=>0,1=>1,2=>0,3=>1,4=>3,others=>0)
      )
    port map (
      CLK    => CLK,
      RESET  => reset_i,
      CLK_EN => CLK_EN,

      --Media interfacces
      MED_DATAREADY_OUT => med_dataready_out(mii-1 downto 0),
      MED_DATA_OUT      => med_data_out(mii*16-1 downto 0),
      MED_PACKET_NUM_OUT=> med_packet_num_out(mii*3-1 downto 0),
      MED_READ_IN       => med_read_in(mii-1 downto 0),
      MED_DATAREADY_IN  => med_dataready_in(mii-1 downto 0),
      MED_DATA_IN       => med_data_in(mii*16-1 downto 0),
      MED_PACKET_NUM_IN => med_packet_num_in(mii*3-1 downto 0),
      MED_READ_OUT      => med_read_out(mii-1 downto 0),
      MED_STAT_OP       => med_stat_op(mii*16-1 downto 0),
      MED_CTRL_OP       => HUB_MED_CTRL_OP(mii*16-1 downto 0),

      INT_INIT_DATAREADY_OUT    => hub_init_dataready_out,
      INT_INIT_DATA_OUT         => hub_init_data_out,
      INT_INIT_PACKET_NUM_OUT   => hub_init_packet_num_out,
      INT_INIT_READ_IN          => hub_init_read_in,
      INT_INIT_DATAREADY_IN     => hub_init_dataready_in,
      INT_INIT_DATA_IN          => hub_init_data_in,
      INT_INIT_PACKET_NUM_IN    => hub_init_packet_num_in,
      INT_INIT_READ_OUT         => hub_init_read_out,
      INT_REPLY_DATAREADY_OUT   => hub_reply_dataready_out,
      INT_REPLY_DATA_OUT        => hub_reply_data_out,
      INT_REPLY_PACKET_NUM_OUT  => hub_reply_packet_num_out,
      INT_REPLY_READ_IN         => hub_reply_read_in,
      INT_REPLY_DATAREADY_IN    => hub_reply_dataready_in,
      INT_REPLY_DATA_IN         => hub_reply_data_in,
      INT_REPLY_PACKET_NUM_IN   => hub_reply_packet_num_in,
      INT_REPLY_READ_OUT        => hub_reply_read_out,
      --REGIO INTERFACE
      REGIO_ADDR_OUT            => regio_addr_i,
      REGIO_READ_ENABLE_OUT     => regio_read_enable_i,
      REGIO_WRITE_ENABLE_OUT    => regio_write_enable_i,
      REGIO_DATA_OUT            => regio_data_out_i,
      REGIO_DATA_IN             => regio_data_in_i,
      REGIO_DATAREADY_IN        => regio_dataready_i,
      REGIO_NO_MORE_DATA_IN     => regio_no_more_data_i,
      REGIO_WRITE_ACK_IN        => regio_write_ack_i,
      REGIO_UNKNOWN_ADDR_IN     => regio_unknown_addr_i,
      REGIO_TIMEOUT_OUT         => regio_timeout_i,
      TIMER_TICKS_OUT           => timer_ticks,
      ONEWIRE            => ONEWIRE,
      ONEWIRE_MONITOR_IN => ONEWIRE_MONITOR_IN,
      ONEWIRE_MONITOR_OUT=> ONEWIRE_MONITOR_OUT,
      MY_ADDRESS_OUT     => my_address,
      UNIQUE_ID_OUT      => UNIQUE_ID_OUT,
      COMMON_CTRL_REGS   => common_ctrl,
      COMMON_STAT_REGS   => common_stat,
      COMMON_CTRL_REG_STROBE => common_ctrl_strobe,
      COMMON_STAT_REG_STROBE => common_stat_strobe,
      MPLEX_CTRL         => (others => '0'),
      CTRL_DEBUG         => hub_ctrl_debug,
      STAT_DEBUG         => STAT_DEBUG,
      HUB_STAT_GEN       => buf_HUB_STAT_GEN
      );

  hub_ctrl_debug(2 downto 0) <= not ERROR_OK;
  hub_ctrl_debug(31 downto 3) <= (others => '0');
  HUB_STAT_GEN <= buf_HUB_STAT_GEN;


 ---------------------------------------------------------------------
-- Trigger Channel Sender
--------------------------------------------------------------------- 
  TRG_CHANNEL_API: trb_net16_api_base
    generic map (
      API_TYPE          => c_API_ACTIVE,
      FIFO_TO_INT_DEPTH => 6,
      FIFO_TO_APL_DEPTH => 6,
      FORCE_REPLY       => 1,
      SBUF_VERSION      => 0,
      USE_VENDOR_CORES   => c_YES,
      SECURE_MODE_TO_APL => c_YES,
      SECURE_MODE_TO_INT => c_YES,
      APL_WRITE_ALL_WORDS=> c_YES
      )
    port map (
      --  Misc
      CLK    => CLK,
      RESET  => reset_i,
      CLK_EN => CLK_EN,
      -- APL Transmitter port
      APL_DATA_IN           => (others =>  '0'),
      APL_PACKET_NUM_IN     => "000",
      APL_DATAREADY_IN      => '0',
      APL_READ_OUT          => open,
      APL_SHORT_TRANSFER_IN => '1',
      APL_DTYPE_IN          => CTS_TRG_TYPE_IN,
      APL_ERROR_PATTERN_IN  => trg_apl_error_pattern_in(31 downto 0),
      APL_SEND_IN           => CTS_TRG_SEND_IN,
      APL_TARGET_ADDRESS_IN => (others => '0'),
      -- Receiver port
      APL_DATA_OUT      => trg_apl_data_out(15 downto 0),
      APL_PACKET_NUM_OUT=> trg_apl_packet_num_out(2 downto 0),
      APL_TYP_OUT       => trg_apl_typ_out(2 downto 0),
      APL_DATAREADY_OUT => trg_apl_dataready_out,
      APL_READ_IN       => trg_apl_read_in,
      -- APL Control port
      APL_RUN_OUT       => trg_apl_run_out,
      APL_MY_ADDRESS_IN => my_address,
      APL_SEQNR_OUT     => open,
      APL_LENGTH_IN     => (others => '0'),
      -- Internal direction port
      INT_MASTER_DATAREADY_OUT => hub_init_dataready_in(2),
      INT_MASTER_DATA_OUT      => tmp_hub_init_data_in,
      INT_MASTER_PACKET_NUM_OUT=> hub_init_packet_num_in(8 downto 6),
      INT_MASTER_READ_IN       => hub_init_read_out(2),
      INT_MASTER_DATAREADY_IN  => '0',
      INT_MASTER_DATA_IN       => (others => '0'),
      INT_MASTER_PACKET_NUM_IN => "000",
      INT_MASTER_READ_OUT      => open,
      INT_SLAVE_DATAREADY_OUT  => open,
      INT_SLAVE_DATA_OUT       => open,
      INT_SLAVE_PACKET_NUM_OUT => open,
      INT_SLAVE_READ_IN        => '1',
      INT_SLAVE_DATAREADY_IN => hub_reply_dataready_out(2),
      INT_SLAVE_DATA_IN      => hub_reply_data_out(47 downto 32),
      INT_SLAVE_PACKET_NUM_IN=> hub_reply_packet_num_out(8 downto 6),
      INT_SLAVE_READ_OUT     => hub_reply_read_in(2),
      -- Status and control port
      CTRL_SEQNR_RESET =>  common_ctrl(10),
      STAT_FIFO_TO_INT => open,
      STAT_FIFO_TO_APL => open
      );

  trg_apl_error_pattern_in(15 downto  0) <= CTS_TRG_NUMBER_IN;
  trg_apl_error_pattern_in(23 downto 16) <= CTS_TRG_RND_CODE_IN;
  trg_apl_error_pattern_in(31 downto 24) <= CTS_TRG_INFORMATION_IN(7 downto 0);
  CTS_TRG_BUSY_OUT          <= trg_apl_run_out;
  
  hub_reply_dataready_in(2) <= '0';
  hub_reply_data_in(47 downto 32) <= (others => '0');
  hub_reply_packet_num_in(8 downto 6) <= (others => '0');
  hub_init_read_in(2) <= '0';

  trg_apl_read_in <= '1';

  PROC_TRG_STATUS_BITS : process(CLK)
    begin
      if rising_edge(CLK) then
        if trg_apl_packet_num_out = c_F1 and trg_apl_typ_out = TYPE_TRM then
          CTS_TRG_STATUS_BITS_OUT(31 downto 16) <= trg_apl_data_out;
        end if;
        if trg_apl_packet_num_out = c_F2 and trg_apl_typ_out = TYPE_TRM then
          CTS_TRG_STATUS_BITS_OUT(15 downto 0) <= trg_apl_data_out;
        end if;
      end if;
    end process;

  proc_add_trigger_info : process(hub_init_packet_num_in, reg_ext_trg_information, tmp_hub_init_data_in)
    begin
      if hub_init_packet_num_in(8 downto 6) = c_F0 then
        hub_init_data_in(47 downto 32) <= reg_ext_trg_information;
      else
        hub_init_data_in(47 downto 32) <= tmp_hub_init_data_in;
      end if;
    end process;

  proc_save_trigger_info : process(CLK)
    begin
      if rising_edge(CLK) then
        if CTS_TRG_SEND_IN = '1' then
          reg_ext_trg_information <= CTS_TRG_INFORMATION_IN(23 downto 8);
        end if;
      end if;
    end process;
      
      

---------------------------------------------------------------------
-- IPU Channel Sender
---------------------------------------------------------------------

  hub_reply_data_in(63 downto 48)     <= (others => '0');
  hub_reply_packet_num_in(11 downto 9) <= (others => '0');
  hub_reply_dataready_in(3)           <= '0';
  hub_init_read_in(3)                 <= '1';

  THE_STREAMING : trb_net16_api_ipu_streaming_internal
    port map(
      CLK    => CLK,
      RESET  => reset_i,
      CLK_EN => CLK_EN,

      -- Internal direction port
      FEE_INIT_DATA_OUT         => hub_init_data_in(63 downto 48),
      FEE_INIT_DATAREADY_OUT    => hub_init_dataready_in(3),
      FEE_INIT_PACKET_NUM_OUT   => hub_init_packet_num_in(11 downto 9),
      FEE_INIT_READ_IN          => hub_init_read_out(3),
      FEE_REPLY_DATA_IN         => hub_reply_data_out(63 downto 48),
      FEE_REPLY_DATAREADY_IN    => hub_reply_dataready_out(3),
      FEE_REPLY_PACKET_NUM_IN   => hub_reply_packet_num_out(11 downto 9),
      FEE_REPLY_READ_OUT        => hub_reply_read_in(3),

      --from CTS
      CTS_SEND_IN              => CTS_IPU_SEND_IN,
      CTS_NUMBER_IN            => CTS_IPU_NUMBER_IN,
      CTS_CODE_IN              => CTS_IPU_RND_CODE_IN,
      CTS_INFORMATION_IN       => CTS_IPU_INFORMATION_IN,
      CTS_READOUT_TYPE_IN      => CTS_IPU_TYPE_IN,
      
      --to CTS
      CTS_STATUS_BITS_OUT      => CTS_IPU_STATUS_BITS_OUT,
      CTS_BUSY_OUT             => CTS_IPU_BUSY_OUT,
      
      --from APL to GbE
      GBE_FEE_DATA_OUT         => GBE_FEE_DATA_OUT,       
      GBE_FEE_DATAREADY_OUT    => GBE_FEE_DATAREADY_OUT,  
      GBE_FEE_READ_IN          => GBE_FEE_READ_IN,        
      GBE_FEE_STATUS_BITS_OUT  => GBE_FEE_STATUS_BITS_OUT,
      GBE_FEE_BUSY_OUT         => GBE_FEE_BUSY_OUT,       

      GBE_CTS_NUMBER_OUT           => GBE_CTS_NUMBER_OUT,
      GBE_CTS_CODE_OUT             => GBE_CTS_CODE_OUT,
      GBE_CTS_INFORMATION_OUT      => GBE_CTS_INFORMATION_OUT,
      GBE_CTS_READOUT_TYPE_OUT     => GBE_CTS_READOUT_TYPE_OUT,
      GBE_CTS_START_READOUT_OUT    => GBE_CTS_START_READOUT_OUT,

      --from GbE to CTS
      GBE_READOUT_FINISHED_IN      => GBE_CTS_READOUT_FINISHED_IN,
      GBE_STATUS_BITS_IN           => GBE_CTS_STATUS_BITS_IN,

      MY_ADDRESS_IN              => my_address,
      CTRL_SEQNR_RESET           => common_ctrl(10)
      );

      
      
---------------------------------------------------------------------
-- Trigger Channel read-out
---------------------------------------------------------------------      
  RDO_READOUT_TRG : trb_net16_trigger
    port map(
      CLK    => CLK,
      RESET  => reset_i,
      CLK_EN => CLK_EN,
      INT_DATAREADY_OUT     => hub_reply_dataready_in(0),
      INT_DATA_OUT          => hub_reply_data_in(15 downto 0),
      INT_PACKET_NUM_OUT    => hub_reply_packet_num_in(2 downto 0),
      INT_READ_IN           => hub_reply_read_out(0),
      INT_DATAREADY_IN      => hub_init_dataready_out(0),
      INT_DATA_IN           => hub_init_data_out(15 downto 0),
      INT_PACKET_NUM_IN     => hub_init_packet_num_out(2 downto 0),
      INT_READ_OUT          => hub_init_read_in(0),
      TRG_RECEIVED_OUT      => lvl1_trg_received,
      TRG_TYPE_OUT          => lvl1_trg_type,
      TRG_NUMBER_OUT        => lvl1_trg_number,
      TRG_CODE_OUT          => lvl1_trg_code,
      TRG_INFORMATION_OUT   => lvl1_trg_information,
      TRG_RELEASE_IN        => lvl1_handler_trg_release,
      TRG_ERROR_PATTERN_IN  => lvl1_handler_error_pattern
      );      

  hub_init_dataready_in(0) <= '0';
  hub_init_data_in(15 downto 0) <= (others => '0');
  hub_init_packet_num_in(2 downto 0) <= (others => '0');
  hub_reply_read_in(0) <= '0';

  RDO_LVL1_HANDLER : handler_lvl1
    generic map (
      TIMING_TRIGGER_RAW           => c_NO
    )
    port map(
      RESET                        => reset_i,
      RESET_FLAGS_IN               => common_ctrl(4),
      RESET_STATS_IN               => common_ctrl(5),
      CLOCK                        => CLK,
      --Timing Trigger
      LVL1_TIMING_TRG_IN           => RDO_TRIGGER_IN,
      LVL1_PSEUDO_TMG_TRG_IN       => common_ctrl(16),
      --LVL1_handler connection
      LVL1_TRG_RECEIVED_IN         => lvl1_trg_received,
      LVL1_TRG_TYPE_IN             => lvl1_trg_type,
      LVL1_TRG_NUMBER_IN           => lvl1_trg_number,
      LVL1_TRG_CODE_IN             => lvl1_trg_code,
      LVL1_TRG_INFORMATION_IN      => lvl1_trg_information,
      LVL1_ERROR_PATTERN_OUT       => lvl1_handler_error_pattern,
      LVL1_TRG_RELEASE_OUT         => lvl1_handler_trg_release,

      LVL1_INT_TRG_NUMBER_OUT      => int_trigger_num,
      LVL1_INT_TRG_LOAD_IN         => common_ctrl_strobe(1),
      LVL1_INT_TRG_COUNTER_IN      => common_ctrl(47 downto 32),

      --FEE logic / Data Handler
      LVL1_TRG_DATA_VALID_OUT      => lvl1_data_valid_i,
      LVL1_VALID_TIMING_TRG_OUT    => lvl1_valid_timing_i,
      LVL1_VALID_NOTIMING_TRG_OUT  => lvl1_valid_notiming_i,
      LVL1_INVALID_TRG_OUT         => lvl1_invalid_i,
      LVL1_DELAY_OUT               => int_lvl1_delay,

      LVL1_ERROR_PATTERN_IN        => lvl1_error_pattern,
      LVL1_TRG_RELEASE_IN          => lvl1_trg_release,

      --Stat/Control
      STATUS_OUT                   => stat_lvl1_handler,
      TRG_ENABLE_IN                => '1',
      TRG_INVERT_IN                => '0',
      COUNTERS_STATUS_OUT          => stat_counters_lvl1_handler,
      --Debug
      DEBUG_OUT                    => open
    );

    
---------------------------------------------------------------------
-- IPU Channel read-out
---------------------------------------------------------------------    

  RDO_IPU_API : trb_net16_api_base
    generic map (
      API_TYPE               => c_API_PASSIVE,
      APL_WRITE_ALL_WORDS    => c_YES,
      ADDRESS_MASK           => x"FFFF",
      BROADCAST_BITMASK      => BROADCAST_BITMASK,
      BROADCAST_SPECIAL_ADDR => BROADCAST_SPECIAL_ADDR
      )
    port map (
      --  Misc
      CLK    => CLK,
      RESET  => reset_i,
      CLK_EN => CLK_EN,
      -- APL Transmitter port
      APL_DATA_IN           => rdo_apl_data_in,
      APL_PACKET_NUM_IN     => rdo_apl_packet_num_in,
      APL_DATAREADY_IN      => rdo_apl_dataready_in,
      APL_READ_OUT          => rdo_apl_read_out,
      APL_SHORT_TRANSFER_IN => rdo_apl_short_transfer_in,
      APL_DTYPE_IN          => rdo_apl_dtype_in,
      APL_ERROR_PATTERN_IN  => rdo_apl_error_pattern_in,
      APL_SEND_IN           => rdo_apl_send_in,
      APL_TARGET_ADDRESS_IN => (others => '0'),
      -- Receiver port
      APL_DATA_OUT      => rdo_apl_data_out,
      APL_PACKET_NUM_OUT=> rdo_apl_packet_num_out,
      APL_TYP_OUT       => rdo_apl_typ_out,
      APL_DATAREADY_OUT => rdo_apl_dataready_out,
      APL_READ_IN       => rdo_apl_read_in,
      -- APL Control port
      APL_RUN_OUT       => rdo_apl_run_out,
      APL_MY_ADDRESS_IN => my_address,
      APL_SEQNR_OUT     => rdo_apl_seqnr_out,
      APL_LENGTH_IN     => rdo_apl_length_in,
      -- Internal direction port
      INT_MASTER_DATAREADY_OUT => hub_reply_dataready_in(1),
      INT_MASTER_DATA_OUT      => hub_reply_data_in(31 downto 16),
      INT_MASTER_PACKET_NUM_OUT=> hub_reply_packet_num_in(5 downto 3),
      INT_MASTER_READ_IN       => hub_reply_read_out(1),
      INT_MASTER_DATAREADY_IN  => '0',
      INT_MASTER_DATA_IN       => (others => '0'),
      INT_MASTER_PACKET_NUM_IN => (others => '0'),
      INT_MASTER_READ_OUT      => open,
      INT_SLAVE_DATAREADY_OUT  => open,
      INT_SLAVE_DATA_OUT       => open,
      INT_SLAVE_PACKET_NUM_OUT => open,
      INT_SLAVE_READ_IN        => '1',
      INT_SLAVE_DATAREADY_IN => hub_init_dataready_out(1),
      INT_SLAVE_DATA_IN      => hub_init_data_out(31 downto 16),
      INT_SLAVE_PACKET_NUM_IN=> hub_init_packet_num_out(5 downto 3),
      INT_SLAVE_READ_OUT     => hub_init_read_in(1),
      -- Status and control port
      CTRL_SEQNR_RESET =>  common_ctrl(10),
      STAT_FIFO_TO_INT => open,
      STAT_FIFO_TO_APL => open
      );

  hub_init_dataready_in(1) <= '0';
  hub_init_data_in(31 downto 16) <= (others => '0');
  hub_init_packet_num_in(5 downto 3) <= (others => '0');
  hub_reply_read_in(1) <= '0';

  RDO_IPUDATA_APL : trb_net16_ipudata
    port map(
      CLK    => CLK,
      RESET  => RESET,
      CLK_EN => CLK_EN,
      API_DATA_OUT           => rdo_apl_data_in,
      API_PACKET_NUM_OUT     => rdo_apl_packet_num_in,
      API_DATAREADY_OUT      => rdo_apl_dataready_in,
      API_READ_IN            => rdo_apl_read_out,
      API_SHORT_TRANSFER_OUT => rdo_apl_short_transfer_in,
      API_DTYPE_OUT          => rdo_apl_dtype_in,
      API_ERROR_PATTERN_OUT  => rdo_apl_error_pattern_in,
      API_SEND_OUT           => rdo_apl_send_in,
      API_DATA_IN            => rdo_apl_data_out,
      API_PACKET_NUM_IN      => rdo_apl_packet_num_out,
      API_TYP_IN             => rdo_apl_typ_out,
      API_DATAREADY_IN       => rdo_apl_dataready_out,
      API_READ_OUT           => rdo_apl_read_in,
      API_RUN_IN             => rdo_apl_run_out,
      API_SEQNR_IN           => rdo_apl_seqnr_out,
      API_LENGTH_OUT         => rdo_apl_length_in,
      MY_ADDRESS_IN          => my_address,
      IPU_NUMBER_OUT         => ipu_number_i,
      IPU_READOUT_TYPE_OUT   => ipu_readout_type_i,
      IPU_INFORMATION_OUT    => ipu_information_i,
      IPU_START_READOUT_OUT  => ipu_start_readout_i,
      IPU_DATA_IN            => ipu_data_i,
      IPU_DATAREADY_IN       => ipu_dataready_i,
      IPU_READOUT_FINISHED_IN=> ipu_readout_finished_i,
      IPU_READ_OUT           => ipu_read_i,
      IPU_LENGTH_IN          => ipu_length_i,
      IPU_ERROR_PATTERN_IN   => ipu_error_pattern_i,
      STAT_DEBUG             => open
      );

      
---------------------------------------------------------------------
-- Read-out data handler
---------------------------------------------------------------------   

  RDO_HANDLER_TRIGGER_DATA : handler_trigger_and_data
    generic map(
      DATA_INTERFACE_NUMBER      => DATA_INTERFACE_NUMBER,
      DATA_BUFFER_DEPTH          => RDO_DATA_BUFFER_DEPTH,
      DATA_BUFFER_WIDTH          => 32,
      DATA_BUFFER_FULL_THRESH    => RDO_DATA_BUFFER_FULL_THRESH,
      TRG_RELEASE_AFTER_DATA     => c_YES,
      HEADER_BUFFER_DEPTH        => RDO_HEADER_BUFFER_DEPTH,
      HEADER_BUFFER_FULL_THRESH  => RDO_HEADER_BUFFER_FULL_THRESH
      )
    port map(
      CLOCK                      => CLK,
      RESET                      => reset_i,
      RESET_IPU                  => reset_ipu_i,
      --LVL1 channel
      LVL1_VALID_TRIGGER_IN      => lvl1_valid_i,
      LVL1_INT_TRG_NUMBER_IN     => int_trigger_num,
      LVL1_TRG_DATA_VALID_IN     => lvl1_data_valid_i,
      LVL1_TRG_TYPE_IN           => lvl1_trg_type,
      LVL1_TRG_NUMBER_IN         => lvl1_trg_number,
      LVL1_TRG_CODE_IN           => lvl1_trg_code,
      LVL1_TRG_INFORMATION_IN    => lvl1_trg_information,
      LVL1_ERROR_PATTERN_OUT     => lvl1_error_pattern,
      LVL1_TRG_RELEASE_OUT       => lvl1_trg_release,

      --IPU channel
      IPU_NUMBER_IN              => ipu_number_i,
      IPU_INFORMATION_IN         => ipu_information_i,                     
      IPU_READOUT_TYPE_IN        => ipu_readout_type_i,
      IPU_START_READOUT_IN       => ipu_start_readout_i,
      IPU_DATA_OUT               => ipu_data_i,
      IPU_DATAREADY_OUT          => ipu_dataready_i,
      IPU_READOUT_FINISHED_OUT   => ipu_readout_finished_i,
      IPU_READ_IN                => ipu_read_i,
      IPU_LENGTH_OUT             => ipu_length_i,
      IPU_ERROR_PATTERN_OUT      => ipu_error_pattern_i,

      --FEE Input
      FEE_TRG_RELEASE_IN(0)                                      => RDO_DATA_FINISHED_IN,
      FEE_TRG_RELEASE_IN(RDO_ADDITIONAL_PORT downto 1)           => RDO_ADDITIONAL_FINISHED,
      FEE_TRG_STATUSBITS_IN(31 downto 0)                         => RDO_TRG_STATUSBITS_IN,
      FEE_TRG_STATUSBITS_IN(RDO_ADDITIONAL_PORT*32+31 downto 32) => RDO_ADDITIONAL_STATUSBITS_IN,
      FEE_DATA_IN(31 downto 0)                                   => RDO_DATA_IN,
      FEE_DATA_IN(RDO_ADDITIONAL_PORT*32+31 downto 32)           => RDO_ADDITIONAL_DATA,
      FEE_DATA_WRITE_IN(0)                                       => RDO_DATA_WRITE_IN,
      FEE_DATA_WRITE_IN(RDO_ADDITIONAL_PORT downto 1)            => RDO_ADDITIONAL_WRITE,
      FEE_DATA_FINISHED_IN(0)                                    => RDO_DATA_FINISHED_IN,
      FEE_DATA_FINISHED_IN(RDO_ADDITIONAL_PORT downto 1)         => RDO_ADDITIONAL_FINISHED,
      FEE_DATA_ALMOST_FULL_OUT                                   => open,

      TMG_TRG_ERROR_IN           => '0',
      --Status Registers
      STAT_DATA_BUFFER_LEVEL     => stat_data_buffer_level,
      STAT_HEADER_BUFFER_LEVEL   => stat_header_buffer_level,
      STATUS_OUT                 => stat_handler_i,
      TIMER_TICKS_IN             => timer_ticks,
      STATISTICS_DATA_OUT        => stat_buffer_i,
      STATISTICS_UNKNOWN_OUT     => stat_buffer_unknown,
      STATISTICS_READY_OUT       => stat_buffer_ready,
      STATISTICS_READ_IN         => stat_buffer_read,
      STATISTICS_ADDR_IN         => stat_buffer_address,
      --Debug
      DEBUG_DATA_HANDLER_OUT     => open,
      DEBUG_IPU_HANDLER_OUT      => open

      );

  reset_ipu_i                  <= reset_i or common_ctrl(2);
  lvl1_valid_i                 <= lvl1_valid_timing_i or lvl1_valid_notiming_i or lvl1_invalid_i;
  
  RDO_VALID_TIMING_TRG_OUT   <= lvl1_valid_timing_i;
  RDO_VALID_NOTIMING_TRG_OUT <= lvl1_valid_notiming_i;
  RDO_INVALID_TRG_OUT        <= lvl1_invalid_i;
  RDO_TRG_DATA_VALID_OUT     <= lvl1_data_valid_i;

  RDO_TRG_TYPE_OUT           <= lvl1_trg_type;
  RDO_TRG_CODE_OUT           <= lvl1_trg_code;
  RDO_TRG_INFORMATION_OUT    <= lvl1_trg_information;
  RDO_TRG_NUMBER_OUT         <= lvl1_trg_number;
  
  
  proc_buf_status : process(CLK)
    variable tmp : integer range 0 to 15;
    begin
      if rising_edge(CLK) then
        dbuf_unknown_addr        <= '0';
        dbuf_dataready           <= '0';
        tbuf_dataready           <= tbuf_read_enable;
        if dbuf_read_enable = '1' then
          tmp := to_integer(unsigned(dbuf_addr));
          if tmp < DATA_INTERFACE_NUMBER then
            dbuf_data_in         <= stat_data_buffer_level(tmp*32+31 downto tmp*32);
            dbuf_dataready       <= '1';
          else
            dbuf_data_in         <= (others => '0');
            dbuf_unknown_addr    <= '1';
          end if;
        end if;
      end if;
    end process;
  
  
--     process(REGIO_COMMON_STAT_REG_IN, debug_ipu_handler_i,common_ctrl_reg_i, common_stat_reg_i)
--     begin
--       common_stat_reg_i(8 downto 0) <= REGIO_COMMON_STAT_REG_IN(8 downto 0);
--       common_stat_reg_i(47 downto 12) <= REGIO_COMMON_STAT_REG_IN(47 downto 12);
--       common_stat_reg_i(6)       <= debug_ipu_handler_i(15) or REGIO_COMMON_STAT_REG_IN(6);
-- 
--       if rising_edge(CLK) then
--         if common_ctrl_reg_i(4) = '1' then 
--           common_stat_reg_i(11 downto 9) <= "000";
--         else 
--           common_stat_reg_i(9)       <= debug_ipu_handler_i(12) or REGIO_COMMON_STAT_REG_IN(9) or common_stat_reg_i(9);
--           common_stat_reg_i(10)      <= debug_ipu_handler_i(13) or REGIO_COMMON_STAT_REG_IN(10) or common_stat_reg_i(10);
--           common_stat_reg_i(11)      <= debug_ipu_handler_i(14) or REGIO_COMMON_STAT_REG_IN(11) or common_stat_reg_i(11);      
--         end if;
--       end if;
--       common_stat_reg_i(159 downto 64) <= REGIO_COMMON_STAT_REG_IN(159 downto 64);
--     end process;
-- 
--   process(CLK)
--     begin
--       if rising_edge(CLK) then
--         if ipu_start_readout_i = '1' then
--           common_stat_reg_i(63 downto 48) <= ipu_number_i;
--         end if;
--       end if;
--     end process;
 
---------------------------------------------------------------------
-- Slowcontrol injection via GbE
---------------------------------------------------------------------
    hub_init_dataready_in(4)              <= GSC_INIT_DATAREADY_IN;   
    hub_init_data_in(79 downto 64)        <= GSC_INIT_DATA_IN;
    hub_init_packet_num_in(14 downto 12)  <= GSC_INIT_PACKET_NUM_IN;  
    GSC_INIT_READ_OUT                     <= hub_init_read_out(4);
    GSC_REPLY_DATAREADY_OUT               <= hub_reply_dataready_out(4);
    GSC_REPLY_DATA_OUT                    <= hub_reply_data_out(79 downto 64);
    GSC_REPLY_PACKET_NUM_OUT              <= hub_reply_packet_num_out(14 downto 12);
    hub_reply_read_in(4)                  <= GSC_REPLY_READ_IN;       
    GSC_BUSY_OUT                          <= buf_HUB_STAT_GEN(3);

    hub_reply_dataready_in(4) <= '0';
    hub_reply_data_in(79 downto 64) <= (others => '0');
    hub_reply_packet_num_in(14 downto 12) <= (others => '0');
    hub_init_read_in(4) <= '1';


-------------------------------------------------
-- Common Status Register
-------------------------------------------------
  proc_gen_common_stat_regs : process(stat_lvl1_handler, lvl1_trg_information, 
                                      lvl1_trg_type, lvl1_trg_number, lvl1_trg_code, 
                                      stat_counters_lvl1_handler, int_trigger_num)
    begin
      common_stat(47 downto 0)                    <= (others => '0');
      common_stat(std_COMSTATREG*32-1 downto 64)  <= (others => '0');

      common_stat(4)            <= stat_lvl1_handler(12);
      common_stat(13)           <= stat_lvl1_handler(7);
      common_stat(47 downto 32)   <= int_trigger_num;
      common_stat(127 downto 64)  <= stat_lvl1_handler;
      common_stat(175 downto 160) <= lvl1_trg_information(15 downto 0);
      common_stat(179 downto 176) <= lvl1_trg_type;
      common_stat(183 downto 180) <= lvl1_trg_number(3 downto 0);
      common_stat(191 downto 184) <= lvl1_trg_code;
      common_stat(271 downto 192) <= stat_counters_lvl1_handler;
    end process;    
    
  process(CLK)
    begin
      if rising_edge(CLK) then
        if ipu_start_readout_i = '1' then
          common_stat(63 downto 48) <= ipu_number_i;
        end if;
      end if;
    end process;    
    
COMMON_STAT_REGS <= common_stat;    
---------------------------------------------------------------------------
-- RegIO Bus Handler
---------------------------------------------------------------------------
  THE_INTERNAL_BUS_HANDLER : trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER                => 7,
      PORT_ADDRESSES             => (0 => x"8000", 1 => x"7100", 2 => x"7110", 3 => x"7200", 4 => x"7201", 5 => x"7202", 6 => x"7300", others => x"0000"),
      PORT_ADDR_MASK             => (0 => 15,      1 => 4,       2 => 0,       3 => 0,       4 => 0,       5 => 0,       6 => 5,       others => 0)
      )
    port map(
      CLK                        => CLK,
      RESET                      => reset_i,

      DAT_ADDR_IN                => regio_addr_i,
      DAT_DATA_IN                => regio_data_out_i,
      DAT_DATA_OUT               => regio_data_in_i,
      DAT_READ_ENABLE_IN         => regio_read_enable_i,
      DAT_WRITE_ENABLE_IN        => regio_write_enable_i,
      DAT_TIMEOUT_IN             => regio_timeout_i,
      DAT_DATAREADY_OUT          => regio_dataready_i,
      DAT_WRITE_ACK_OUT          => regio_write_ack_i,
      DAT_NO_MORE_DATA_OUT       => regio_no_more_data_i,
      DAT_UNKNOWN_ADDR_OUT       => regio_unknown_addr_i,
--Fucking Modelsim wants it like this...
      BUS_READ_ENABLE_OUT(0)     => REGIO_READ_ENABLE_OUT,
      BUS_READ_ENABLE_OUT(1)     => dbuf_read_enable,
      BUS_READ_ENABLE_OUT(2)     => tbuf_read_enable,
      BUS_READ_ENABLE_OUT(3)     => read_enable(3),
      BUS_READ_ENABLE_OUT(4)     => read_enable(4),
      BUS_READ_ENABLE_OUT(5)     => read_enable(5),
      BUS_READ_ENABLE_OUT(6)     => stat_buffer_read,
      BUS_WRITE_ENABLE_OUT(0)    => REGIO_WRITE_ENABLE_OUT,
      BUS_WRITE_ENABLE_OUT(1)    => dummy(0),
      BUS_WRITE_ENABLE_OUT(2)    => write_enable(2),
      BUS_WRITE_ENABLE_OUT(3)    => write_enable(3),
      BUS_WRITE_ENABLE_OUT(4)    => write_enable(4),
      BUS_WRITE_ENABLE_OUT(5)    => write_enable(5),
      BUS_WRITE_ENABLE_OUT(6)    => write_enable(6),
      BUS_DATA_OUT(31 downto 0)  => REGIO_DATA_OUT,
      BUS_DATA_OUT(63 downto 32) => dummy(33 downto 2),
      BUS_DATA_OUT(95 downto 64) => dummy(65 downto 34),
      BUS_DATA_OUT(191 downto 96) => dummy(191 downto 96),
      BUS_DATA_OUT(223 downto 192)=> dummy(291 downto 260),
      BUS_ADDR_OUT(15 downto 0)  => REGIO_ADDR_OUT,
      BUS_ADDR_OUT(19 downto 16) => dbuf_addr,
      BUS_ADDR_OUT(31 downto 20) => dummy(77 downto 66),
      BUS_ADDR_OUT(47 downto 32) => dummy(93 downto 78),
      BUS_ADDR_OUT(95 downto 48) => dummy(242 downto 195),
      BUS_ADDR_OUT(100 downto 96)=> stat_buffer_address,
      BUS_ADDR_OUT(111 downto 101)=> dummy(259 downto 249),
      BUS_TIMEOUT_OUT(0)         => REGIO_TIMEOUT_OUT,
      BUS_TIMEOUT_OUT(1)         => dummy(94),
      BUS_TIMEOUT_OUT(2)         => dummy(95),
      BUS_TIMEOUT_OUT(3)         => dummy(192),
      BUS_TIMEOUT_OUT(4)         => dummy(193),
      BUS_TIMEOUT_OUT(5)         => dummy(194),
      BUS_TIMEOUT_OUT(6)         => dummy(243),
      BUS_DATA_IN(31 downto 0)   => REGIO_DATA_IN,
      BUS_DATA_IN(63 downto 32)  => dbuf_data_in,
      BUS_DATA_IN(95 downto 64)  => stat_header_buffer_level,
      BUS_DATA_IN(191 downto 96) => stat_handler_i(95 downto 0),
      BUS_DATA_IN(223 downto 192)=> stat_buffer_i,
      BUS_DATAREADY_IN(0)        => REGIO_DATAREADY_IN,
      BUS_DATAREADY_IN(1)        => dbuf_dataready,
      BUS_DATAREADY_IN(2)        => tbuf_dataready,
      BUS_DATAREADY_IN(3)        => last_read_enable(3),
      BUS_DATAREADY_IN(4)        => last_read_enable(4),
      BUS_DATAREADY_IN(5)        => last_read_enable(5),
      BUS_DATAREADY_IN(6)        => stat_buffer_ready,
      BUS_WRITE_ACK_IN(0)        => REGIO_WRITE_ACK_IN,
      BUS_WRITE_ACK_IN(1)        => '0',
      BUS_WRITE_ACK_IN(2)        => '0',
      BUS_WRITE_ACK_IN(3)        => '0',
      BUS_WRITE_ACK_IN(4)        => '0',
      BUS_WRITE_ACK_IN(5)        => '0',
      BUS_WRITE_ACK_IN(6)        => '0',
      BUS_NO_MORE_DATA_IN(0)     => REGIO_NO_MORE_DATA_IN,
      BUS_NO_MORE_DATA_IN(1)     => '0',
      BUS_NO_MORE_DATA_IN(2)     => '0',
      BUS_NO_MORE_DATA_IN(3)     => '0',
      BUS_NO_MORE_DATA_IN(4)     => '0',
      BUS_NO_MORE_DATA_IN(5)     => '0',
      BUS_NO_MORE_DATA_IN(6)     => '0',
      BUS_UNKNOWN_ADDR_IN(0)     => REGIO_UNKNOWN_ADDR_IN,
      BUS_UNKNOWN_ADDR_IN(1)     => dbuf_unknown_addr,
      BUS_UNKNOWN_ADDR_IN(2)     => last_write_enable(2),
      BUS_UNKNOWN_ADDR_IN(3)     => last_write_enable(3),
      BUS_UNKNOWN_ADDR_IN(4)     => last_write_enable(4),
      BUS_UNKNOWN_ADDR_IN(5)     => last_write_enable(5),
      BUS_UNKNOWN_ADDR_IN(6)     => stat_buffer_unknown
      );

  last_write_enable <= write_enable when rising_edge(CLK);
  last_read_enable  <= read_enable when rising_edge(CLK);
  
  TIMER_TICKS_OUT <= timer_ticks;
  
---------------------------------------------------------------------
-- Debug
---------------------------------------------------------------------
-- STAT_DEBUG(0) <= cts_reply_dataready_in;
-- STAT_DEBUG(1) <= cts_reply_read_out;
-- STAT_DEBUG(2) <= cts_init_dataready_out;
-- STAT_DEBUG(3) <= cts_reply_read_out;
-- STAT_DEBUG(4) <= io_dataready_out(2);
-- STAT_DEBUG(5) <= io_dataready_out(3);
-- STAT_DEBUG(6) <= '0';
-- STAT_DEBUG(7) <= '0';


end architecture;