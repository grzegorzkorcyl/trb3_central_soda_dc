----------------------------------------------------------------------------------
-- Company:       KVI/RUG/Groningen University
-- Engineer:      Peter Schakel
-- Create Date:   16-04-2012
-- Module Name:   DC_wave2packet64
-- Description:   Put waveform data in 64 bits packets
-- Modifications:
--   17-07-2014   buffer_full_S in clocked process
--   07-10-2014   buffer_full_S removed from clocked process, depending on mem64_unequal_S
--   26-11-2014   name changed from DC_wave2packet64 to DC_wave2packet64
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.std_logic_arith.all;
USE work.panda_package.all;

------------------------	----------------------------------------------------------
-- DC_wave2packet64
-- The waveform data is transferred to 64bits data.
-- The incoming waveform data is 36 bits. The waveform length is variable.
-- The output data is 64 bits. A has a small header and 8-bits CRC check.
--
-- Input data:
--        	bits(35..32)="0000" : bits(31..0)=timestamp of maximum value in waveform
--        	bits(35..32)="0001" : bits(31)=0 bits(30..0)=SuperBurst number
--        	bits(35..32)="0010" : 
--              bits(31..24) = statusbyte (bit6=overflow) 
--              bits(23..16) = 00
--              bits(15..0) = adcnumber (channel identification)
--        	bits(35..32)="0011" : bits(31..16)=adc sample, bits(15..0)=next adc sample
--        	bits(35..32)="0100" : bits(31..16)=last adc sample, bits(15..0)=0
--        	bits(35..32)="0101" : bits(31..16)=last but one adc sample, bits(15..0)=last adc sample
--        	bits(35..32)="1111" : error: buffer full, waveform not valid
--
-- Output data 64 bits:
--          U64_0 : 0xdd  status(7:0) ADCchannel(15:0) '0' SuperburstNr
--          U64_1 : Time(47:0) NumberOfSamples(7:0) CRC(7:0)
--          U64_2 : adcsample(15:0) next_adcsample(15:0) next_adcsample(15:0) next_adcsample(15:0)
-- 
--
--
--
-- Library:
--     work.panda_package: types and constants
--
-- Generics:
--     BUFFER_BITS : number of bits for address for buffer-memory 
--
-- Inputs:
--     clock : clock for input and output data
--     reset : reset
--     wave_in : waveform input data, 36-bits stream
--        	bits(35..32)="0000" : bits(31..0)=timestamp of maximum value in waveform
--        	bits(35..32)="0001" : bits(31)=0 bits(30..0)=SuperBurst number
--        	bits(35..32)="0010" : 
--              bits(31..24) = statusbyte (bit6=overflow) 
--              bits(23..16) = 00
--              bits(15..0) = adcnumber (channel identification)
--        	bits(35..32)="0011" : bits(31..16)=adc sample, bits(15..0)=next adc sample
--        	bits(35..32)="0100" : bits(31..16)=last adc sample, bits(15..0)=0
--        	bits(35..32)="0101" : bits(31..16)=last but one adc sample, bits(15..0)=last adc sample
--        	bits(35..32)="1111" : error: buffer full, waveform not valid
--     wave_in_available : waveform data is availabe
--     wave64_out_allowed : allowed to write 64 output data (connecting fifo not full)
-- 
-- Outputs:
--     wave_in_read : read signal for input waveform data
--     wave64_out : 64 bits data
--     wave64_out_write : write signal for 64 bits data
--     wave64_out_first : first 64-bits word in packet
--     wave64_out_last : last 64-bits word in packet
--     error : error
-- 
-- Components:
--     crc8_add_check64 : adds 8 bit crc to last 64-word in packet
--     blockmem : memory block to buffer a packet before transmitting
--
----------------------------------------------------------------------------------

entity DC_wave2packet64 is
	generic (
		BUFFER_BITS : natural := 9
	);
    Port ( 
		clock                   : in std_logic;
		reset                   : in std_logic;
		wave_in                 : in std_logic_vector(35 downto 0);
		wave_in_read            : out std_logic;
		wave_in_available       : in std_logic;
		wave64_out              : out std_logic_vector(63 downto 0);
		wave64_out_write        : out std_logic;
		wave64_out_first        : out std_logic;
		wave64_out_last         : out std_logic;
		wave64_out_allowed      : in std_logic;
		error                   : out std_logic;
		testword0               : out std_logic_vector(35 downto 0) := (others => '0')
	);    
end DC_wave2packet64;


architecture Behavioral of DC_wave2packet64 is

component crc8_add_check64 is 
   port(           
		clock                   : in  std_logic; 
		reset                   : in  std_logic; 
		data_in                 : in  std_logic_vector(63 downto 0); 
		data_in_valid           : in  std_logic; 
		data_in_last            : in  std_logic; 
		data_out                : out std_logic_vector(63 downto 0); 
		data_out_valid          : out std_logic;
		data_out_last           : out std_logic;
		crc_error               : out std_logic
	);
end component; 

component blockmem is
	generic (
		ADDRESS_BITS : natural := BUFFER_BITS;
		DATA_BITS  : natural := 66
		);
	port (
		clock                   : in  std_logic; 
		write_enable            : in std_logic;
		write_address           : in std_logic_vector(ADDRESS_BITS-1 downto 0);
		data_in                 : in std_logic_vector(DATA_BITS-1 downto 0);
		read_address            : in std_logic_vector(ADDRESS_BITS-1 downto 0);
		data_out                : out std_logic_vector(DATA_BITS-1 downto 0)
	);
end component;


signal wave_in_read_S             : std_logic := '0';
signal wave_in_read_after1clk_S   : std_logic := '0';
signal expect_S                   : std_logic_vector(3 downto 0) := "0000"; 

signal crc_data_in_S              : std_logic_vector(63 downto 0); 
signal crc_data_in_valid_S        : std_logic := '0'; 
signal crc_data_in_last_S         : std_logic := '0'; 
signal crc_data_out_S             : std_logic_vector(63 downto 0); 
signal crc_data_out_valid_S       : std_logic := '0';
signal crc_data_out_first_S       : std_logic := '0';
signal crc_data_out_last_S        : std_logic := '0';
signal crc_data_out_ready_S       : std_logic := '0';
signal crc_reset_s                : std_logic := '0';

signal mem_write_enable_S         : std_logic;
signal mem_write_address_S        : std_logic_vector(BUFFER_BITS-1 downto 0);
signal mem_data_in_S              : std_logic_vector(65 downto 0);
signal mem_read_address_S         : std_logic_vector(BUFFER_BITS-1 downto 0);
signal mem_data_out_S             : std_logic_vector(65 downto 0);
signal memdata_in_first_S         : std_logic := '0';
signal memdata_in_last_S          : std_logic := '0';

signal mem64_writeaddress_S       : std_logic_vector(BUFFER_BITS-1 downto 0) := (others => '0');
signal mem64_writeaddress0_S      : std_logic_vector(BUFFER_BITS-1 downto 0) := (others => '0');
signal mem64_writeaddresslast_S   : std_logic_vector(BUFFER_BITS-1 downto 0) := (others => '1');
signal mem64_readaddress_S        : std_logic_vector(BUFFER_BITS-1 downto 0) := (others => '0');
signal mem64_readaddressprev_S    : std_logic_vector(BUFFER_BITS-1 downto 0) := (others => '0');
signal mem64_writeaddress_next_S  : std_logic_vector(BUFFER_BITS-1 downto 0) := (others => '0');
signal mem64_unequal_S            : std_logic := '0';
signal mem64_unequal_prev_S       : std_logic := '0';


signal buffer_full_S              : std_logic := '0';

signal wave64_out_write0_S        : std_logic := '0';
signal wave64_out_write_S         : std_logic := '0';
signal wave64_out_first_S         : std_logic := '0';
signal wave64_out_last_S          : std_logic := '0';

signal write_adress1_S            : std_logic := '0';
signal samplephase_S              : std_logic := '0';
signal wavesize_S                 : integer range 0 to 255;
signal crc_data_in_high_S         : std_logic_vector(31 downto 0);
signal timestamp_S                : std_logic_vector(15 downto 0);
signal superburstnr_S             : std_logic_vector(30 downto 0);
signal statusbyte_S               : std_logic_vector(7 downto 0);
signal adcnumber_S                : std_logic_vector(15 downto 0);
signal error_S                    : std_logic := '0';


begin

error <= error_S;
wave_in_read <= wave_in_read_S;

wave_in_read_S <= '1' when 
	(reset = '0') and (buffer_full_S='0') and (wave_in_available='1') 
and (wave64_out_allowed='1')
	else '0';
	
-- process(clock)
-- begin
	-- if (rising_edge(clock)) then 
		-- if ((write_adress1_S='0') and
				-- ((mem64_writeaddress_S=mem_read_address_S) or
				-- (mem64_writeaddress_S+1=mem_read_address_S) or
				-- (mem64_writeaddress_S+2=mem_read_address_S) or
				-- (mem64_writeaddress_S+3=mem_read_address_S))) or
			-- ((write_adress1_S='1') and
				-- ((mem64_writeaddress_next_S=mem_read_address_S) or
				-- (mem64_writeaddress_next_S+1=mem_read_address_S) or
				-- (mem64_writeaddress_next_S+2=mem_read_address_S) or
				-- (mem64_writeaddress_next_S+3=mem_read_address_S))) then
			-- buffer_full_S <= '1';
		-- else
			-- buffer_full_S <= '0';
		-- end if;
	-- end if;
-- end process;


buffer_full_S <= '1'
		when (mem64_unequal_S='1') and 
			(((write_adress1_S='0') and
				((mem64_writeaddress_S=mem_read_address_S) or
				(mem64_writeaddress_S+1=mem_read_address_S) or
				(mem64_writeaddress_S+2=mem_read_address_S) or
				(mem64_writeaddress_S+3=mem_read_address_S))) or
			((write_adress1_S='1') and
				((mem64_writeaddress_next_S=mem_read_address_S) or
				(mem64_writeaddress_next_S+1=mem_read_address_S) or
				(mem64_writeaddress_next_S+2=mem_read_address_S) or
				(mem64_writeaddress_next_S+3=mem_read_address_S))))
		else '0';


crc8_add_check64_comp: crc8_add_check64 port map(
		clock => clock,
		reset => crc_reset_S,
		data_in => crc_data_in_S, 
		data_in_valid => crc_data_in_valid_S,
		data_in_last => crc_data_in_last_S,
		data_out => crc_data_out_S, 
		data_out_valid => crc_data_out_valid_S,
		data_out_last => crc_data_out_last_S,
		crc_error => open);
		
process(clock)
begin
	if (rising_edge(clock)) then 
		if reset='1' then
			crc_data_out_ready_S <= '1';
		else
			if (crc_data_out_valid_S='1') and (crc_data_out_last_S='1') then
				crc_data_out_ready_S <= '1';
			elsif (crc_data_out_valid_S='1') then
				crc_data_out_ready_S <= '0';
			end if;	
		end if;
	end if;
end process;
crc_data_out_first_S <= '1' when (crc_data_out_valid_S='1') and (crc_data_out_ready_S='1') else '0';

blockmem1: blockmem port map(
		clock => clock,
		write_enable => mem_write_enable_S,
		write_address => mem_write_address_S,
		data_in => mem_data_in_S,
		read_address => mem_read_address_S,
		data_out => mem_data_out_S);
mem_data_in_S(63 downto 0) <= crc_data_out_S;
mem_write_enable_S <= crc_data_out_valid_S;

process(clock)
begin
	if (rising_edge(clock)) then 
		mem_write_address_S <= mem64_writeaddress_S;
		mem_data_in_S(64) <= memdata_in_first_S;
		mem_data_in_S(65) <= memdata_in_last_S;
	end if;
end process;
		

writeprocess: process(clock)
begin
	if (rising_edge(clock)) then 
		if (reset = '1') then 
			crc_data_in_valid_S <= '0';
			crc_data_in_last_S <= '0';
			crc_reset_S <= '1';
			wave_in_read_after1clk_S <= '0';
			mem64_writeaddress_next_S <= (others => '0');
			mem64_writeaddress0_S <= (others => '0');
			mem64_writeaddress_S <= (others => '0');
			mem64_writeaddresslast_S <= (others => '1');
			memdata_in_first_S <= '0';
			memdata_in_last_S <= '0';
			write_adress1_S <= '0';
			wavesize_S <= 0;
			samplephase_S <= '0';
			expect_S <= "0000";
		else
			if wave_in_read_after1clk_S='1' then
				case expect_S is
					when "0000"  =>
						if write_adress1_S='1' then
							crc_data_in_S <= x"00000000" & timestamp_S & conv_std_logic_vector(wavesize_S,8) & x"00"; --48+8+8
							mem64_writeaddress_S <= mem64_writeaddress0_S+1;
							mem64_writeaddresslast_S <= mem64_writeaddress_next_S-1;
							crc_data_in_valid_S <= '1';
							crc_data_in_last_S <= '1';
							write_adress1_S <= '0';
						else
							crc_data_in_valid_S <= '0';
							crc_data_in_last_S <= '0';
							crc_reset_S <= '1';
						end if;
						if wave_in(35 downto 32)=expect_S then
							error_S <= '0';
							timestamp_S <= wave_in(15 downto 0);
							memdata_in_last_S <= '0';
							memdata_in_first_S <= '0';
							wavesize_S <= 0;
							mem64_writeaddress0_S <= mem64_writeaddress_next_S;
							expect_S <= "0001";
						else -- error
							error_S <= '1';
						end if;
						write_adress1_S <= '0';
					
					when "0001" => 
						if wave_in(35 downto 32)=expect_S then
							superburstnr_S <= wave_in(30 downto 0);
							crc_reset_S <= '0';
							expect_S <= "0010";
						else
							crc_reset_S <= '1';
							error_S <= '1';
							expect_S <= "0000";
						end if;
						memdata_in_first_S <= '0';
						memdata_in_last_S <= '0';
						crc_data_in_valid_S <= '0';
						crc_data_in_last_S <= '0';
						wavesize_S <= 0;
						write_adress1_S <= '0';
					when "0010" => 
						if wave_in(35 downto 32)=expect_S then
							statusbyte_S <= wave_in(31 downto 24);
							adcnumber_S <= wave_in(15 downto 0);
							crc_data_in_S <= x"dd" & wave_in(31 downto 24) & wave_in(15 downto 0) & '0' & superburstnr_S; --8+8+16+32
							crc_data_in_valid_S <= '1';
							memdata_in_first_S <= '1';
							memdata_in_last_S <= '0';
							mem64_writeaddress_S <= mem64_writeaddress0_S;
							crc_reset_S <= '0';
							expect_S <= "0011";
						else
							crc_reset_S <= '1';
							error_S <= '1';
							expect_S <= "0000";
						end if;
						wavesize_S <= 0;
						samplephase_S <= '0';
						write_adress1_S <= '0';
					when "0011" => 
						if wave_in(35 downto 32)="0011" then
							crc_data_in_last_S <= '0';
							memdata_in_first_S <= '0';
							memdata_in_last_S <= '0';
							if samplephase_S='0' then
								crc_data_in_high_S <= wave_in(31 downto 16) & wave_in(15 downto 0);
								crc_data_in_valid_S <= '0';
								if wavesize_S=0 then
									mem64_writeaddress_S <= mem64_writeaddress0_S+1;
								end if;
								samplephase_S <= '1';
								wavesize_S <= wavesize_S+2;
							else
								crc_data_in_S <= crc_data_in_high_S & wave_in(31 downto 16) & wave_in(15 downto 0); --32+16+16
								crc_data_in_valid_S <= '1';
								mem64_writeaddress_S <= mem64_writeaddress_S+1;
								wavesize_S <= wavesize_S+2;
								samplephase_S <= '0';
							end if;
							write_adress1_S <= '0';
							crc_reset_S <= '0';
							expect_S <= "0011";
						elsif wave_in(35 downto 32)="0100" then
							crc_data_in_last_S <= '0';
							memdata_in_first_S <= '0';
							memdata_in_last_S <= '1';
							if samplephase_S='0' then
								crc_data_in_S <= wave_in(31 downto 16) & x"000000000000";
								crc_data_in_valid_S <= '1';
								mem64_writeaddress_S <= mem64_writeaddress_S+1;
								mem64_writeaddress_next_S <= mem64_writeaddress_S+2;
								write_adress1_S <= '1';
								wavesize_S <= wavesize_S+1;
							else
								crc_data_in_S <= crc_data_in_high_S & wave_in(31 downto 16) & x"0000";
								crc_data_in_valid_S <= '1';
								mem64_writeaddress_S <= mem64_writeaddress_S+1;
								mem64_writeaddress_next_S <= mem64_writeaddress_S+2;
								write_adress1_S <= '1';
								wavesize_S <= wavesize_S+1;
							end if;
							crc_reset_S <= '0';
							expect_S <= "0000";
						elsif wave_in(35 downto 32)="0101" then
							crc_data_in_last_S <= '0';
							memdata_in_first_S <= '0';
							memdata_in_last_S <= '1';
							if samplephase_S='0' then
								crc_data_in_S <= wave_in(31 downto 16) & wave_in(15 downto 0) & x"00000000";
								crc_data_in_valid_S <= '1';
								mem64_writeaddress_S <= mem64_writeaddress_S+1;
								mem64_writeaddress_next_S <= mem64_writeaddress_S+2;
								write_adress1_S <= '1';
								wavesize_S <= wavesize_S+2;
							else
								crc_data_in_S <= crc_data_in_high_S & wave_in(31 downto 16) & wave_in(15 downto 0);
								crc_data_in_valid_S <= '1';
								mem64_writeaddress_S <= mem64_writeaddress_S+1;
								mem64_writeaddress_next_S <= mem64_writeaddress_S+2;
								write_adress1_S <= '1';
								wavesize_S <= wavesize_S+2;
							end if;
							crc_reset_S <= '0';
							expect_S <= "0000";
						elsif wave_in(35 downto 32)="1111" then
							crc_reset_S <= '1';
							crc_data_in_last_S <= '0';
							crc_data_in_valid_S <= '0';
							memdata_in_first_S <= '0';
							expect_S <= "0000";
						else -- error
							error_S <= '1';
							crc_reset_S <= '1';
							crc_data_in_last_S <= '0';
							crc_data_in_valid_S <= '0';
							memdata_in_first_S <= '0';
							expect_S <= "0000";
						end if;
					when others => 
						error_S <= '1';
						crc_reset_S <= '1';
						crc_data_in_last_S <= '0';
						crc_data_in_valid_S <= '0';
						memdata_in_first_S <= '0';
						expect_S <= "0000";
				end case;
			else
				if write_adress1_S='1' then
					crc_data_in_S <= x"00000000" & timestamp_S & conv_std_logic_vector(wavesize_S,8) & x"00"; --48+8+8
					mem64_writeaddress_S <= mem64_writeaddress0_S+1;
					mem64_writeaddresslast_S <= mem64_writeaddress_next_S-1;
					memdata_in_first_S <= '0';
					memdata_in_last_S <= '0';
					crc_data_in_valid_S <= '1';
					crc_data_in_last_S <= '1';
				else
					memdata_in_first_S <= '0';
					memdata_in_last_S <= '0';
					crc_data_in_valid_S <= '0';
					crc_data_in_last_S <= '0';
				end if;
				write_adress1_S <= '0';
			end if;
			wave_in_read_after1clk_S <= wave_in_read_S;
		end if;
	end if;
end process;


wave64_out <= mem_data_out_S(63 downto 0);  
wave64_out_first_S <= mem_data_out_S(64);
wave64_out_first <= wave64_out_first_S;
wave64_out_last_S <= mem_data_out_S(65);
wave64_out_last <= wave64_out_last_S;


wave64_out_write_S <= '1' when (wave64_out_write0_S='1') and (wave64_out_allowed='1') else '0'; 
wave64_out_write <= wave64_out_write_S;
mem_read_address_S <= mem64_readaddressprev_S when (wave64_out_write_S='0') and (wave64_out_write0_S='1') else mem64_readaddress_S;
mem64_unequal_S <= '1' when (mem64_readaddress_S/=mem64_writeaddresslast_S) else '0';
readprocess: process(clock)
begin
	if (rising_edge(clock)) then 
		if (reset = '1') then 
			mem64_readaddress_S <= (others => '1');
			mem64_readaddressprev_S <= (others => '1');
			mem64_unequal_prev_S <= '0';
		else
			if (wave64_out_write0_S='1') and (wave64_out_write_S='0') then -- unsucessfull write
				wave64_out_write0_S <= '1';
				mem64_unequal_prev_S <= '0';
				mem64_readaddress_S <= mem64_readaddressprev_S; -- keep same address
			else
				mem64_readaddressprev_S <= mem64_readaddress_S;
				if (wave64_out_allowed='1') then
					if (mem64_unequal_S='1') then 
						mem64_readaddress_S <= mem64_readaddress_S+1;
						mem64_unequal_prev_S <= '1';
					else
						mem64_unequal_prev_S <= '0';
					end if;
					if mem64_unequal_prev_S='1' then
						wave64_out_write0_S <= '1';
					else
						wave64_out_write0_S <= '0';
					end if;
				else
				end if;
			end if;
		end if;
	end if;
end process;



testword0(7 downto 0) <= mem_data_out_S(63 downto 56);
testword0(15 downto 8) <= mem_read_address_S(7 downto 0);
testword0(23 downto 16) <= mem_write_address_S(7 downto 0);

testword0(24) <= wave64_out_write_S;
testword0(25) <= wave64_out_write0_S;
testword0(26) <= wave64_out_first_S;
testword0(27) <= wave64_out_last_S;
testword0(28) <= wave64_out_allowed;
testword0(29) <= wave_in_read_S;
testword0(30) <= wave_in_available;
testword0(31) <= wave_in_read_after1clk_S;
testword0(32) <= crc_data_in_valid_S;
testword0(33) <= crc_data_in_last_S;

testword0(34) <= mem_write_enable_S;
testword0(35) <= buffer_full_S;





end Behavioral;

