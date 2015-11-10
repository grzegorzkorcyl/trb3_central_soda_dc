-- VHDL netlist generated by SCUBA Diamond (64-bit) 3.2.0.134
-- Module  Version: 5.6
--C:\Lattice\diamond\3.2_x64\ispfpga\bin\nt64\scuba.exe -w -n pll_in125_out125_62M5 -lang vhdl -synth synplify -arch ep5c00 -type pll -fin 125 -phase_cntl STATIC -fclkop 125 -fclkop_tol 0.0 -fb_mode INTERNAL -noclkos -fclkok 62.5 -fclkok_tol 0.0 -clkoki 0 -norst -noclkok2 -bw 

-- Fri Aug 29 10:45:47 2014

library IEEE;
use IEEE.std_logic_1164.all;
-- synopsys translate_off
library ecp3;
use ecp3.components.all;
-- synopsys translate_on

entity pll_in125_out125_62M5 is
    port (
        CLK: in std_logic; 
        CLKOP: out std_logic; 
        CLKOK: out std_logic; 
        LOCK: out std_logic);
 attribute dont_touch : boolean;
 attribute dont_touch of pll_in125_out125_62M5 : entity is true;
end pll_in125_out125_62M5;

architecture Structure of pll_in125_out125_62M5 is

    -- internal signal declarations
    signal CLKOP_t: std_logic;
    signal CLKFB_t: std_logic;
    signal scuba_vlo: std_logic;

    -- local component declarations
    component EHXPLLF
        generic (FEEDBK_PATH : in String; CLKOK_INPUT : in String; 
                DELAY_PWD : in String; DELAY_VAL : in Integer; 
                CLKOS_TRIM_DELAY : in Integer; 
                CLKOS_TRIM_POL : in String; 
                CLKOP_TRIM_DELAY : in Integer; 
                CLKOP_TRIM_POL : in String; CLKOK_BYPASS : in String; 
                CLKOS_BYPASS : in String; CLKOP_BYPASS : in String; 
                PHASE_DELAY_CNTL : in String; DUTY : in Integer; 
                PHASEADJ : in String; CLKOK_DIV : in Integer; 
                CLKOP_DIV : in Integer; CLKFB_DIV : in Integer; 
                CLKI_DIV : in Integer; FIN : in String);
        port (CLKI: in std_logic; CLKFB: in std_logic; RST: in std_logic; 
            RSTK: in std_logic; WRDEL: in std_logic; DRPAI3: in std_logic; 
            DRPAI2: in std_logic; DRPAI1: in std_logic; DRPAI0: in std_logic; 
            DFPAI3: in std_logic; DFPAI2: in std_logic; DFPAI1: in std_logic; 
            DFPAI0: in std_logic; FDA3: in std_logic; FDA2: in std_logic; 
            FDA1: in std_logic; FDA0: in std_logic; CLKOP: out std_logic; 
            CLKOS: out std_logic; CLKOK: out std_logic; CLKOK2: out std_logic; 
            LOCK: out std_logic; CLKINTFB: out std_logic);
    end component;
    component VLO
        port (Z: out std_logic);
    end component;
    attribute FREQUENCY_PIN_CLKOP : string; 
    attribute FREQUENCY_PIN_CLKI : string; 
    attribute FREQUENCY_PIN_CLKOK : string; 
    attribute FREQUENCY_PIN_CLKOP of PLLInst_0 : label is "125.000000";
    attribute FREQUENCY_PIN_CLKI of PLLInst_0 : label is "125.000000";
    attribute FREQUENCY_PIN_CLKOK of PLLInst_0 : label is "62.500000";
    attribute syn_keep : boolean;
    attribute syn_noprune : boolean;
    attribute syn_noprune of Structure : architecture is true;
    attribute NGD_DRC_MASK : integer;
    attribute NGD_DRC_MASK of Structure : architecture is 1;

begin
    -- component instantiation statements
    scuba_vlo_inst: VLO
        port map (Z=>scuba_vlo);

    PLLInst_0: EHXPLLF
        generic map (FEEDBK_PATH=> "INTERNAL", CLKOK_BYPASS=> "DISABLED", 
        CLKOS_BYPASS=> "DISABLED", CLKOP_BYPASS=> "DISABLED", 
        CLKOK_INPUT=> "CLKOP", DELAY_PWD=> "DISABLED", DELAY_VAL=>  0, 
        CLKOS_TRIM_DELAY=>  0, CLKOS_TRIM_POL=> "RISING", 
        CLKOP_TRIM_DELAY=>  0, CLKOP_TRIM_POL=> "RISING", 
        PHASE_DELAY_CNTL=> "STATIC", DUTY=>  8, PHASEADJ=> "0.0", 
        CLKOK_DIV=>  2, CLKOP_DIV=>  8, CLKFB_DIV=>  1, CLKI_DIV=>  1, 
        FIN=> "125.000000")
        port map (CLKI=>CLK, CLKFB=>CLKFB_t, RST=>scuba_vlo, 
            RSTK=>scuba_vlo, WRDEL=>scuba_vlo, DRPAI3=>scuba_vlo, 
            DRPAI2=>scuba_vlo, DRPAI1=>scuba_vlo, DRPAI0=>scuba_vlo, 
            DFPAI3=>scuba_vlo, DFPAI2=>scuba_vlo, DFPAI1=>scuba_vlo, 
            DFPAI0=>scuba_vlo, FDA3=>scuba_vlo, FDA2=>scuba_vlo, 
            FDA1=>scuba_vlo, FDA0=>scuba_vlo, CLKOP=>CLKOP_t, 
            CLKOS=>open, CLKOK=>CLKOK, CLKOK2=>open, LOCK=>LOCK, 
            CLKINTFB=>CLKFB_t);

    CLKOP <= CLKOP_t;
end Structure;

-- synopsys translate_off
library ecp3;
configuration Structure_CON of pll_in125_out125_62M5 is
    for Structure
        for all:EHXPLLF use entity ecp3.EHXPLLF(V); end for;
        for all:VLO use entity ecp3.VLO(V); end for;
    end for;
end Structure_CON;

-- synopsys translate_on
