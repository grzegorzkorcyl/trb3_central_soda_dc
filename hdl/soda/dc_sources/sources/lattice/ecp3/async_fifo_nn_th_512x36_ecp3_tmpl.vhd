-- VHDL module instantiation generated by SCUBA Diamond (64-bit) 3.2.0.134
-- Module  Version: 5.7
-- Thu Feb 26 14:21:00 2015

-- parameterized module component declaration
component async_fifo_nn_th_512x36_ecp3
    port (Data: in  std_logic_vector(35 downto 0); 
        WrClock: in  std_logic; RdClock: in  std_logic; 
        WrEn: in  std_logic; RdEn: in  std_logic; Reset: in  std_logic; 
        RPReset: in  std_logic; Q: out  std_logic_vector(35 downto 0); 
        RCNT: out  std_logic_vector(9 downto 0); Empty: out  std_logic; 
        Full: out  std_logic; AlmostEmpty: out  std_logic);
end component;

-- parameterized module component instance
__ : async_fifo_nn_th_512x36_ecp3
    port map (Data(35 downto 0)=>__, WrClock=>__, RdClock=>__, WrEn=>__, 
        RdEn=>__, Reset=>__, RPReset=>__, Q(35 downto 0)=>__, RCNT(9 downto 0)=>__, 
        Empty=>__, Full=>__, AlmostEmpty=>__);
