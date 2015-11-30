library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;

entity handler_trigger_and_data is
  generic(
    DATA_INTERFACE_NUMBER        : integer range 1 to 16         := 1;
    DATA_BUFFER_DEPTH            : integer range 9 to 14         := 9;
    DATA_BUFFER_WIDTH            : integer range 1 to 32         := 32;
    DATA_BUFFER_FULL_THRESH      : integer range 0 to 2**14-1    := 2**8;
    TRG_RELEASE_AFTER_DATA       : integer range 0 to 1          := c_YES;
    DATA_0_IS_STATUS             : integer range 0 to 1          := c_NO;
    HEADER_BUFFER_DEPTH          : integer range 9 to 14         := 9;
    HEADER_BUFFER_FULL_THRESH    : integer range 2**8 to 2**14-1 := 2**8
    );
  port(
    CLOCK                        : in  std_logic;
    RESET                        : in  std_logic;
    RESET_IPU                    : in  std_logic;

    --To Endpoint
    --Timing Trigger (registered)
    LVL1_VALID_TRIGGER_IN        : in  std_logic;
    LVL1_INT_TRG_NUMBER_IN       : in  std_logic_vector(15 downto 0);
    --LVL1_handler connection
    LVL1_TRG_DATA_VALID_IN       : in  std_logic;
    LVL1_TRG_TYPE_IN             : in  std_logic_vector(3 downto 0);
    LVL1_TRG_NUMBER_IN           : in  std_logic_vector(15 downto 0);
    LVL1_TRG_CODE_IN             : in  std_logic_vector(7 downto 0);
    LVL1_TRG_INFORMATION_IN      : in  std_logic_vector(23 downto 0);
    LVL1_ERROR_PATTERN_OUT       : out std_logic_vector(31 downto 0);
    LVL1_TRG_RELEASE_OUT         : out std_logic;

    --IPU channel
    IPU_NUMBER_IN                : in  std_logic_vector(15 downto 0);
    IPU_INFORMATION_IN           : in  std_logic_vector(7  downto 0);
    IPU_READOUT_TYPE_IN          : in  std_logic_vector(3  downto 0);
    IPU_START_READOUT_IN         : in  std_logic;
    IPU_DATA_OUT                 : out std_logic_vector(31 downto 0);
    IPU_DATAREADY_OUT            : out std_logic;
    IPU_READOUT_FINISHED_OUT     : out std_logic;
    IPU_READ_IN                  : in  std_logic;
    IPU_LENGTH_OUT               : out std_logic_vector(15 downto 0);
    IPU_ERROR_PATTERN_OUT        : out std_logic_vector(31 downto 0);

    --To FEE
    --FEE to Trigger
    FEE_TRG_RELEASE_IN           : in  std_logic_vector(DATA_INTERFACE_NUMBER-1 downto 0);
    FEE_TRG_STATUSBITS_IN        : in  std_logic_vector(DATA_INTERFACE_NUMBER*32-1 downto 0);

    --Data Input from FEE
    FEE_DATA_IN                  : in  std_logic_vector(DATA_INTERFACE_NUMBER*32-1 downto 0);
    FEE_DATA_WRITE_IN            : in  std_logic_vector(DATA_INTERFACE_NUMBER-1 downto 0);
    FEE_DATA_FINISHED_IN         : in  std_logic_vector(DATA_INTERFACE_NUMBER-1 downto 0);
    FEE_DATA_ALMOST_FULL_OUT     : out std_logic_vector(DATA_INTERFACE_NUMBER-1 downto 0);

    TMG_TRG_ERROR_IN             : in  std_logic;
    MAX_EVENT_SIZE_IN            : in  std_logic_vector(15 downto 0) := x"FFFF";
    --Status Registers
    STAT_DATA_BUFFER_LEVEL       : out std_logic_vector(DATA_INTERFACE_NUMBER*32-1 downto 0);
    STAT_HEADER_BUFFER_LEVEL     : out std_logic_vector(31 downto 0);
    STATUS_OUT                   : out std_logic_vector(127 downto 0);
    TIMER_TICKS_IN               : in  std_logic_vector(1 downto 0);
    STATISTICS_DATA_OUT          : out std_logic_vector(31 downto 0);
    STATISTICS_ADDR_IN           : in  std_logic_vector(4 downto 0);
    STATISTICS_READY_OUT         : out std_logic;
    STATISTICS_READ_IN           : in  std_logic;
    STATISTICS_UNKNOWN_OUT       : out std_logic;

    --Debug
    DEBUG_DATA_HANDLER_OUT       : out std_logic_vector(31 downto 0);
    DEBUG_IPU_HANDLER_OUT        : out std_logic_vector(31 downto 0)

    );
end entity;

--Data inputs are read from 0 to MAX - 0 will always come first, MAX is always last.
--To add debug information in front or behind the data, simply configure one more data port than needed for data

--data buffer threshold has to be set to fifo_depth - max_event_size - 2 when TRG_RELEASE_AFTER_DATA_FINISH = c_YES or
--fifo_depth - 2*max_event_size - 2 when TRG_RELEASE_AFTER_DATA_FINISH = c_NO

--STATUS_OUT(0): release status
--STATUS_OUT(1): data handler debug
--STATUS_OUT(2): ipu handler status

architecture handler_trigger_and_data_arch of handler_trigger_and_data is

  type cnt24_DAT_t        is array (DATA_INTERFACE_NUMBER-1 downto 0) of unsigned(23 downto 0);
  signal timer_fifo_almost_full    : cnt24_DAT_t;
  signal timer_ipu_idle         : unsigned(23 downto 0);
  signal timer_ipu_waiting      : unsigned(23 downto 0);
  signal timer_ipu_working      : unsigned(23 downto 0);
  signal timer_lvl1_almost_full : unsigned(23 downto 0);
  signal timer_lvl1_idle        : unsigned(23 downto 0);
  signal timer_lvl1_working     : unsigned(23 downto 0);

  signal fee_trg_statusbits      : std_logic_vector(31 downto 0);

  signal dat_lvl1_release        : std_logic;
  signal dat_lvl1_statusbits     : std_logic_vector(31 downto 0);

  signal ipu_data                : std_logic_vector(32*DATA_INTERFACE_NUMBER-1 downto 0);
  signal ipu_data_read           : std_logic_vector(DATA_INTERFACE_NUMBER-1 downto 0);
  signal ipu_data_empty          : std_logic_vector(DATA_INTERFACE_NUMBER-1 downto 0);
  signal ipu_data_flags          : std_logic_vector(4*DATA_INTERFACE_NUMBER-1 downto 0);
  signal ipu_data_length         : std_logic_vector(16*DATA_INTERFACE_NUMBER-1 downto 0);
  signal ipu_header              : std_logic_vector(31 downto 0);
  signal ipu_header_empty        : std_logic;
  signal ipu_header_read         : std_logic;

  signal fee_trg_release         : std_logic_vector(DATA_INTERFACE_NUMBER downto 0);
  signal buf_lvl1_trg_release    : std_logic;
  signal status_ipu_handler_i    : std_logic_vector(31 downto 0);
  signal debug_data_handler_i    : std_logic_vector(31 downto 0);
  signal reset_ipu_i             : std_logic;
  signal buf_STAT_DATA_BUFFER_LEVEL : std_logic_vector(DATA_INTERFACE_NUMBER*32-1 downto 0);
  signal buf_STAT_HEADER_BUFFER_LEVEL : std_logic_vector(31 downto 0);

begin

-----------------------------------------------------------------------
-- Combine all trg_release and trg_statusbits to one
-----------------------------------------------------------------------

  proc_trg_release : process(CLOCK)
    variable tmp_statusbits : std_logic_vector(31 downto 0);
    begin
      if rising_edge(CLOCK) then
        if RESET = '1' or buf_lvl1_trg_release = '1' or LVL1_VALID_TRIGGER_IN = '1' then
          fee_trg_statusbits     <= (others => '0');
          fee_trg_release        <= (others => '0');
        else
          fee_trg_release        <= fee_trg_release or (dat_lvl1_release & FEE_TRG_RELEASE_IN);

          tmp_statusbits         := fee_trg_statusbits;
          for i in 0 to DATA_INTERFACE_NUMBER-1 loop
            if FEE_TRG_RELEASE_IN(i) = '1' then
              tmp_statusbits     := tmp_statusbits  or FEE_TRG_STATUSBITS_IN(32*i+31 downto 32*i);
            end if;
          end loop;
          if dat_lvl1_release = '1' then
           tmp_statusbits        := tmp_statusbits or dat_lvl1_statusbits;
          end if;
          fee_trg_statusbits     <= tmp_statusbits;
        end if;
      end if;
    end process;

-----------------------------------------------------------------------
-- The data handler, containing all buffers
-----------------------------------------------------------------------

  THE_DATA_HANDLER : handler_data
    generic map(
      DATA_INTERFACE_NUMBER        => DATA_INTERFACE_NUMBER,
      DATA_BUFFER_DEPTH            => DATA_BUFFER_DEPTH,
      DATA_BUFFER_WIDTH            => DATA_BUFFER_WIDTH,
      DATA_BUFFER_FULL_THRESH      => DATA_BUFFER_FULL_THRESH,
      TRG_RELEASE_AFTER_DATA       => TRG_RELEASE_AFTER_DATA,
      HEADER_BUFFER_DEPTH          => HEADER_BUFFER_DEPTH,
      HEADER_BUFFER_FULL_THRESH    => HEADER_BUFFER_FULL_THRESH
      )
    port map(
      CLOCK                        => CLOCK,
      RESET                        => reset_ipu_i,

--       From LVL1 Handler
      LVL1_VALID_TRIGGER_IN        => LVL1_VALID_TRIGGER_IN,
      LVL1_TRG_DATA_VALID_IN       => LVL1_TRG_DATA_VALID_IN,
      LVL1_TRG_TYPE_IN             => LVL1_TRG_TYPE_IN,
      LVL1_TRG_INFO_IN             => LVL1_TRG_INFORMATION_IN,
      LVL1_TRG_CODE_IN             => LVL1_TRG_CODE_IN,
      LVL1_TRG_NUMBER_IN           => LVL1_INT_TRG_NUMBER_IN,  --internal number for flags
      LVL1_STATUSBITS_OUT          => dat_lvl1_statusbits,
      LVL1_TRG_RELEASE_OUT         => dat_lvl1_release,
--       From FEE
      FEE_DATA_IN                  => FEE_DATA_IN,
      FEE_DATA_WRITE_IN            => FEE_DATA_WRITE_IN,
      FEE_DATA_FINISHED_IN         => FEE_DATA_FINISHED_IN,
      FEE_DATA_ALMOST_FULL_OUT     => FEE_DATA_ALMOST_FULL_OUT,
--       To IPU Handler
      IPU_DATA_OUT                 => ipu_data,
      IPU_DATA_READ_IN             => ipu_data_read,
      IPU_DATA_EMPTY_OUT           => ipu_data_empty,
      IPU_DATA_LENGTH_OUT          => ipu_data_length,
      IPU_DATA_FLAGS_OUT           => ipu_data_flags,
      IPU_HDR_DATA_OUT             => ipu_header,
      IPU_HDR_DATA_READ_IN         => ipu_header_read,
      IPU_HDR_DATA_EMPTY_OUT       => ipu_header_empty,
      TMG_TRG_ERROR_IN             => TMG_TRG_ERROR_IN,
      MAX_EVENT_SIZE_IN            => MAX_EVENT_SIZE_IN,
--       Status
      STAT_DATA_BUFFER_LEVEL       => buf_STAT_DATA_BUFFER_LEVEL,
      STAT_HEADER_BUFFER_LEVEL     => buf_STAT_HEADER_BUFFER_LEVEL,
--       Debug
      DEBUG_OUT                    => debug_data_handler_i
      );


-----------------------------------------------------------------------
-- The IPU handler
-----------------------------------------------------------------------

  THE_IPU_HANDLER : handler_ipu
    generic map(
      DATA_INTERFACE_NUMBER      => DATA_INTERFACE_NUMBER
      )
    port map(
      CLOCK                      => CLOCK,
      RESET                      => reset_ipu_i,
      --From Data Handler
      DAT_DATA_IN                => ipu_data,
      DAT_DATA_READ_OUT          => ipu_data_read,
      DAT_DATA_EMPTY_IN          => ipu_data_empty,
      DAT_DATA_LENGTH_IN         => ipu_data_length,
      DAT_DATA_FLAGS_IN          => ipu_data_flags,
      DAT_HDR_DATA_IN            => ipu_header,
      DAT_HDR_DATA_READ_OUT      => ipu_header_read,
      DAT_HDR_DATA_EMPTY_IN      => ipu_header_empty,
      --To IPU Channel
      IPU_NUMBER_IN              => IPU_NUMBER_IN,
      IPU_INFORMATION_IN         => IPU_INFORMATION_IN,
      IPU_READOUT_TYPE_IN        => IPU_READOUT_TYPE_IN,
      IPU_START_READOUT_IN       => IPU_START_READOUT_IN,
      IPU_DATA_OUT               => IPU_DATA_OUT,
      IPU_DATAREADY_OUT          => IPU_DATAREADY_OUT,
      IPU_READOUT_FINISHED_OUT   => IPU_READOUT_FINISHED_OUT,
      IPU_READ_IN                => IPU_READ_IN,
      IPU_LENGTH_OUT             => IPU_LENGTH_OUT,
      IPU_ERROR_PATTERN_OUT      => IPU_ERROR_PATTERN_OUT,
      --Debug
      STATUS_OUT                 => status_ipu_handler_i
      );



-----------------------------------------------------------------------
-- Connect Outputs
-----------------------------------------------------------------------
  reset_ipu_i                    <= RESET or RESET_IPU;

  LVL1_TRG_RELEASE_OUT           <= buf_lvl1_trg_release;
  buf_lvl1_trg_release           <= and_all(fee_trg_release);
  LVL1_ERROR_PATTERN_OUT         <= fee_trg_statusbits;

  DEBUG_IPU_HANDLER_OUT          <= status_ipu_handler_i;
  DEBUG_DATA_HANDLER_OUT         <= debug_data_handler_i;


-----------------------------------------------------------------------
-- Statistics
-----------------------------------------------------------------------


    the_stat_proc : process(CLOCK)
      begin
        if rising_edge(CLOCK) then
          gen_buffer_stat : for i in 0 to DATA_INTERFACE_NUMBER-1 loop
            if buf_STAT_DATA_BUFFER_LEVEL(i*32+17) = '1' and TIMER_TICKS_IN(0) = '1' then
              timer_fifo_almost_full(i) <= timer_fifo_almost_full(i) + to_unsigned(1,1);
            end if;
          end loop;
          if buf_STAT_HEADER_BUFFER_LEVEL(17) = '1' and TIMER_TICKS_IN(0) = '1' then
            timer_lvl1_almost_full <= timer_lvl1_almost_full + to_unsigned(1,1);
          end if;
          if buf_STAT_HEADER_BUFFER_LEVEL(20) = '1' and TIMER_TICKS_IN(0) = '1' then
            timer_lvl1_idle <= timer_lvl1_idle + to_unsigned(1,1);
          end if;
          if (buf_STAT_HEADER_BUFFER_LEVEL(21) = '1' or buf_STAT_HEADER_BUFFER_LEVEL(22) = '1') and TIMER_TICKS_IN(0) = '1' then
            timer_lvl1_working <= timer_lvl1_working + to_unsigned(1,1);
          end if;
        end if;
      end process;

    the_ipu_stat_proc : process(CLOCK)
      begin
        if rising_edge(CLOCK) then
          if (status_ipu_handler_i(3 downto 0) = x"0")
              and TIMER_TICKS_IN(0) = '1' then
            timer_ipu_idle <= timer_ipu_idle + to_unsigned(1,1);
          end if;
          if (status_ipu_handler_i(3 downto 0) = x"2" or status_ipu_handler_i(3 downto 0) = x"3" or status_ipu_handler_i(3 downto 0) = x"4")
              and (status_ipu_handler_i(7) = '1' or status_ipu_handler_i(6) = '0')
              and TIMER_TICKS_IN(0) = '1' then
            timer_ipu_working <= timer_ipu_working + to_unsigned(1,1);
          end if;
          if status_ipu_handler_i(6) = '1' and status_ipu_handler_i(7) = '0' and TIMER_TICKS_IN(0) = '1' then
            timer_ipu_waiting <= timer_ipu_waiting + to_unsigned(1,1);
          end if;
        end if;
      end process;

  proc_read_stat : process(CLOCK)
    variable addr : integer range 0 to 31;
    begin
      if rising_edge(CLOCK) then
        addr := to_integer(unsigned(STATISTICS_ADDR_IN));
        if STATISTICS_READ_IN = '1' then
          if addr < DATA_INTERFACE_NUMBER then
            STATISTICS_DATA_OUT    <= x"00" & std_logic_vector(timer_fifo_almost_full(addr));
            STATISTICS_READY_OUT   <= '1';
            STATISTICS_UNKNOWN_OUT <= '0';
          elsif addr >= 16 and addr <= 22 then
            case addr is
              when 16 => STATISTICS_DATA_OUT    <= x"00" &  std_logic_vector(timer_lvl1_almost_full);
              when 17 => STATISTICS_DATA_OUT    <= x"00" &  std_logic_vector(timer_lvl1_idle);
              when 18 => STATISTICS_DATA_OUT    <= x"00" &  std_logic_vector(timer_lvl1_working);
              when 19 => STATISTICS_DATA_OUT    <= x"00" &  std_logic_vector(timer_ipu_idle);
              when 20 => STATISTICS_DATA_OUT    <= x"00" &  std_logic_vector(timer_ipu_working);
              when 21 => STATISTICS_DATA_OUT    <= x"00" &  std_logic_vector(timer_ipu_waiting);
              when 22 => STATISTICS_DATA_OUT    <= x"00" &  std_logic_vector(timer_ipu_waiting);
              when others => STATISTICS_DATA_OUT <= (others => '0');
            end case;
            STATISTICS_READY_OUT   <= '1';
            STATISTICS_UNKNOWN_OUT <= '0';
          else
            STATISTICS_READY_OUT   <= '0';
            STATISTICS_UNKNOWN_OUT <= '1';
          end if;
        else
          STATISTICS_READY_OUT <= '0';
          STATISTICS_UNKNOWN_OUT <= '0';
        end if;
      end if;
    end process;


-----------------------------------------------------------------------
-- Debug
-----------------------------------------------------------------------

  STAT_DATA_BUFFER_LEVEL   <= buf_STAT_DATA_BUFFER_LEVEL;
  STAT_HEADER_BUFFER_LEVEL <= buf_STAT_HEADER_BUFFER_LEVEL;

  STATUS_OUT(DATA_INTERFACE_NUMBER downto 0)     <= fee_trg_release;
  STATUS_OUT(31 downto DATA_INTERFACE_NUMBER+1)  <= (others => '1');

  STATUS_OUT(63 downto 32)                       <= debug_data_handler_i;
  STATUS_OUT(95 downto 64)                       <= status_ipu_handler_i;
  STATUS_OUT(127 downto 96)                      <= (others => '0');

end architecture;