-- VHDL module instantiation generated by SCUBA Diamond (64-bit) 3.6.0.83.4
-- Module  Version: 5.8
-- Fri Nov 20 10:59:46 2015

-- parameterized module component declaration
component fifo_16kx16x64
    port (Data: in  std_logic_vector(17 downto 0); 
        WrClock: in  std_logic; RdClock: in  std_logic; 
        WrEn: in  std_logic; RdEn: in  std_logic; Reset: in  std_logic; 
        RPReset: in  std_logic; Q: out  std_logic_vector(71 downto 0); 
        Empty: out  std_logic; Full: out  std_logic);
end component;

-- parameterized module component instance
__ : fifo_16kx16x64
    port map (Data(17 downto 0)=>__, WrClock=>__, RdClock=>__, WrEn=>__, 
        RdEn=>__, Reset=>__, RPReset=>__, Q(71 downto 0)=>__, Empty=>__, 
        Full=>__);
