-- VHDL module instantiation generated by SCUBA Diamond (64-bit) 3.2.0.134
-- Module  Version: 5.6
-- Thu Nov 20 10:46:29 2014

-- parameterized module component declaration
component pll_in100_out80M
    port (CLK: in std_logic; CLKOP: out std_logic; CLKOK: out std_logic; 
        CLKOK2: out std_logic; LOCK: out std_logic);
end component;

-- parameterized module component instance
__ : pll_in100_out80M
    port map (CLK=>__, CLKOP=>__, CLKOK=>__, CLKOK2=>__, LOCK=>__);
