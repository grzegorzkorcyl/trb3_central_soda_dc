-- VHDL module instantiation generated by SCUBA Diamond (64-bit) 3.2.0.134
-- Module  Version: 5.7
-- Thu Sep 18 09:50:10 2014

-- parameterized module component declaration
component async_fifo_nn_4096x103_ecp3
    port (Data: in  std_logic_vector(102 downto 0); 
        WrClock: in  std_logic; RdClock: in  std_logic; 
        WrEn: in  std_logic; RdEn: in  std_logic; Reset: in  std_logic; 
        RPReset: in  std_logic; Q: out  std_logic_vector(102 downto 0); 
        WCNT: out  std_logic_vector(12 downto 0); Empty: out  std_logic; 
        Full: out  std_logic);
end component;

-- parameterized module component instance
__ : async_fifo_nn_4096x103_ecp3
    port map (Data(102 downto 0)=>__, WrClock=>__, RdClock=>__, WrEn=>__, 
        RdEn=>__, Reset=>__, RPReset=>__, Q(102 downto 0)=>__, WCNT(12 downto 0)=>__, 
        Empty=>__, Full=>__);
