library ieee;
use ieee.std_logic_1164.all;
-- synopsys translate_off
library ecp3;
use ecp3.components.all;
-- synopsys translate_on

entity sync_bit is
	port (
		clock       : in  std_logic;
		data_in     : in  std_logic;
		data_out    : out std_logic
	);
end sync_bit;


architecture structural of sync_bit is

    component FD1S3AX
        port (D: in  std_logic; CK: in  std_logic;
            Q: out  std_logic);
    end component;
  signal dsync1 : std_logic;
  signal dsync2 : std_logic;
  
begin
  -- dsync_reg1 : FD1S3AX
  -- port map (
    -- CK    => clock,
    -- D    => data_in,
    -- Q    => dsync1
  -- );
  -- dsync_reg1 : FD1S3DX
  -- port map (
    -- CK    => clock,
    -- D    => data_in,
	-- CD   => '0',
    -- Q    => dsync1
  -- );
			
  dsync_reg1 : FD1S3AX
  port map (
    CK    => clock,
    D    => data_in,
    Q    => dsync1
  );

 dsync_reg2 : FD1S3AX
  port map (
    CK    => clock,
    D    => dsync1,
    Q    => dsync2
  );

 dsync_reg3 : FD1S3AX
  port map (
    CK    => clock,
    D    => dsync2,
    Q    => data_out
  );

-- synopsys translate_off
library ecp3;
configuration Structure_CON of sync_bit is
    for Structure
        for all:FD1S3AX use entity ecp3.FD1S3AX(V); end for;
    end for;
end Structure_CON;

-- synopsys translate_on

end structural;



