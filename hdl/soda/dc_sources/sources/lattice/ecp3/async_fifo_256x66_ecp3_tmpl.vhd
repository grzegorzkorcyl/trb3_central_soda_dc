-- VHDL module instantiation generated by SCUBA Diamond (64-bit) 3.2.0.134
-- Module  Version: 5.7
-- Tue Sep 23 15:56:44 2014

-- parameterized module component declaration
component async_fifo_256x66_ecp3
    port (Data: in  std_logic_vector(65 downto 0); 
        WrClock: in  std_logic; RdClock: in  std_logic; 
        WrEn: in  std_logic; RdEn: in  std_logic; Reset: in  std_logic; 
        RPReset: in  std_logic; Q: out  std_logic_vector(65 downto 0); 
        Empty: out  std_logic; Full: out  std_logic);
end component;

-- parameterized module component instance
__ : async_fifo_256x66_ecp3
    port map (Data(65 downto 0)=>__, WrClock=>__, RdClock=>__, WrEn=>__, 
        RdEn=>__, Reset=>__, RPReset=>__, Q(65 downto 0)=>__, Empty=>__, 
        Full=>__);
