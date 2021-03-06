-- VHDL netlist generated by SCUBA Diamond (64-bit) 3.2.0.134
-- Module  Version: 5.7
--C:\Lattice\diamond\3.2_x64\ispfpga\bin\nt64\scuba.exe -w -n async_fifo_16x8_ecp3 -lang vhdl -synth synplify -bus_exp 7 -bb -arch ep5c00 -type ebfifo -pfu_fifo -depth 8 -width 8 -depth 8 -rdata_width 8 -no_enable -pe -1 -pf -1 

-- Wed Aug 12 10:43:52 2015

library IEEE;
use IEEE.std_logic_1164.all;
-- synopsys translate_off
library ecp3;
use ecp3.components.all;
-- synopsys translate_on

entity async_fifo_16x8_ecp3 is
    port (
        Data: in  std_logic_vector(7 downto 0); 
        WrClock: in  std_logic; 
        RdClock: in  std_logic; 
        WrEn: in  std_logic; 
        RdEn: in  std_logic; 
        Reset: in  std_logic; 
        RPReset: in  std_logic; 
        Q: out  std_logic_vector(7 downto 0); 
        Empty: out  std_logic; 
        Full: out  std_logic);
end async_fifo_16x8_ecp3;

architecture Structure of async_fifo_16x8_ecp3 is

    -- internal signal declarations
    signal invout_1: std_logic;
    signal invout_0: std_logic;
    signal w_gdata_0: std_logic;
    signal w_gdata_1: std_logic;
    signal w_gdata_2: std_logic;
    signal wptr_3: std_logic;
    signal r_gdata_0: std_logic;
    signal r_gdata_1: std_logic;
    signal r_gdata_2: std_logic;
    signal rptr_3: std_logic;
    signal w_gcount_0: std_logic;
    signal w_gcount_1: std_logic;
    signal w_gcount_2: std_logic;
    signal w_gcount_3: std_logic;
    signal r_gcount_0: std_logic;
    signal r_gcount_1: std_logic;
    signal r_gcount_2: std_logic;
    signal r_gcount_3: std_logic;
    signal w_gcount_r20: std_logic;
    signal w_gcount_r0: std_logic;
    signal w_gcount_r21: std_logic;
    signal w_gcount_r1: std_logic;
    signal w_gcount_r22: std_logic;
    signal w_gcount_r2: std_logic;
    signal w_gcount_r23: std_logic;
    signal w_gcount_r3: std_logic;
    signal r_gcount_w20: std_logic;
    signal r_gcount_w0: std_logic;
    signal r_gcount_w21: std_logic;
    signal r_gcount_w1: std_logic;
    signal r_gcount_w22: std_logic;
    signal r_gcount_w2: std_logic;
    signal r_gcount_w23: std_logic;
    signal r_gcount_w3: std_logic;
    signal empty_i: std_logic;
    signal rRst: std_logic;
    signal full_i: std_logic;
    signal iwcount_0: std_logic;
    signal iwcount_1: std_logic;
    signal w_gctr_ci: std_logic;
    signal iwcount_2: std_logic;
    signal iwcount_3: std_logic;
    signal co1: std_logic;
    signal co0: std_logic;
    signal wcount_3: std_logic;
    signal scuba_vhi: std_logic;
    signal ircount_0: std_logic;
    signal ircount_1: std_logic;
    signal r_gctr_ci: std_logic;
    signal ircount_2: std_logic;
    signal ircount_3: std_logic;
    signal co1_1: std_logic;
    signal co0_1: std_logic;
    signal rcount_3: std_logic;
    signal rden_i: std_logic;
    signal cmp_ci: std_logic;
    signal w_g2b_xor_cluster_0: std_logic;
    signal wcount_r1: std_logic;
    signal rcount_0: std_logic;
    signal rcount_1: std_logic;
    signal co0_2: std_logic;
    signal wcount_r2: std_logic;
    signal empty_cmp_clr: std_logic;
    signal rcount_2: std_logic;
    signal empty_cmp_set: std_logic;
    signal empty_d: std_logic;
    signal empty_d_c: std_logic;
    signal wren_i: std_logic;
    signal cmp_ci_1: std_logic;
    signal r_g2b_xor_cluster_0: std_logic;
    signal rcount_w1: std_logic;
    signal wcount_0: std_logic;
    signal wcount_1: std_logic;
    signal co0_3: std_logic;
    signal rcount_w2: std_logic;
    signal full_cmp_clr: std_logic;
    signal wcount_2: std_logic;
    signal full_cmp_set: std_logic;
    signal full_d: std_logic;
    signal full_d_c: std_logic;
    signal rdataout7: std_logic;
    signal rdataout6: std_logic;
    signal rdataout5: std_logic;
    signal rdataout4: std_logic;
    signal rdataout3: std_logic;
    signal rdataout2: std_logic;
    signal rdataout1: std_logic;
    signal rdataout0: std_logic;
    signal rptr_2: std_logic;
    signal rptr_1: std_logic;
    signal rptr_0: std_logic;
    signal dec0_wre3: std_logic;
    signal scuba_vlo: std_logic;
    signal wptr_2: std_logic;
    signal wptr_1: std_logic;
    signal wptr_0: std_logic;

    -- local component declarations
    component AGEB2
        port (A0: in  std_logic; A1: in  std_logic; B0: in  std_logic; 
            B1: in  std_logic; CI: in  std_logic; GE: out  std_logic);
    end component;
    component AND2
        port (A: in  std_logic; B: in  std_logic; Z: out  std_logic);
    end component;
    component CU2
        port (CI: in  std_logic; PC0: in  std_logic; PC1: in  std_logic; 
            CO: out  std_logic; NC0: out  std_logic; NC1: out  std_logic);
    end component;
    component FADD2B
        port (A0: in  std_logic; A1: in  std_logic; B0: in  std_logic; 
            B1: in  std_logic; CI: in  std_logic; COUT: out  std_logic; 
            S0: out  std_logic; S1: out  std_logic);
    end component;
    component FD1P3BX
        port (D: in  std_logic; SP: in  std_logic; CK: in  std_logic; 
            PD: in  std_logic; Q: out  std_logic);
    end component;
    component FD1P3DX
        port (D: in  std_logic; SP: in  std_logic; CK: in  std_logic; 
            CD: in  std_logic; Q: out  std_logic);
    end component;
    component FD1S3BX
        port (D: in  std_logic; CK: in  std_logic; PD: in  std_logic; 
            Q: out  std_logic);
    end component;
    component FD1S3DX
        port (D: in  std_logic; CK: in  std_logic; CD: in  std_logic; 
            Q: out  std_logic);
    end component;
    component INV
        port (A: in  std_logic; Z: out  std_logic);
    end component;
    component OR2
        port (A: in  std_logic; B: in  std_logic; Z: out  std_logic);
    end component;
    component ROM16X1A
        generic (INITVAL : in std_logic_vector(15 downto 0));
        port (AD3: in  std_logic; AD2: in  std_logic; AD1: in  std_logic; 
            AD0: in  std_logic; DO0: out  std_logic);
    end component;
    component DPR16X4C
        generic (INITVAL : in String);
        port (DI0: in  std_logic; DI1: in  std_logic; DI2: in  std_logic; 
            DI3: in  std_logic; WCK: in  std_logic; WRE: in  std_logic; 
            RAD0: in  std_logic; RAD1: in  std_logic; 
            RAD2: in  std_logic; RAD3: in  std_logic; 
            WAD0: in  std_logic; WAD1: in  std_logic; 
            WAD2: in  std_logic; WAD3: in  std_logic; 
            DO0: out  std_logic; DO1: out  std_logic; 
            DO2: out  std_logic; DO3: out  std_logic);
    end component;
    component VHI
        port (Z: out  std_logic);
    end component;
    component VLO
        port (Z: out  std_logic);
    end component;
    component XOR2
        port (A: in  std_logic; B: in  std_logic; Z: out  std_logic);
    end component;
    attribute GSR : string; 
    attribute MEM_INIT_FILE : string; 
    attribute MEM_LPC_FILE : string; 
    attribute COMP : string; 
    attribute GSR of FF_49 : label is "ENABLED";
    attribute GSR of FF_48 : label is "ENABLED";
    attribute GSR of FF_47 : label is "ENABLED";
    attribute GSR of FF_46 : label is "ENABLED";
    attribute GSR of FF_45 : label is "ENABLED";
    attribute GSR of FF_44 : label is "ENABLED";
    attribute GSR of FF_43 : label is "ENABLED";
    attribute GSR of FF_42 : label is "ENABLED";
    attribute GSR of FF_41 : label is "ENABLED";
    attribute GSR of FF_40 : label is "ENABLED";
    attribute GSR of FF_39 : label is "ENABLED";
    attribute GSR of FF_38 : label is "ENABLED";
    attribute GSR of FF_37 : label is "ENABLED";
    attribute GSR of FF_36 : label is "ENABLED";
    attribute GSR of FF_35 : label is "ENABLED";
    attribute GSR of FF_34 : label is "ENABLED";
    attribute GSR of FF_33 : label is "ENABLED";
    attribute GSR of FF_32 : label is "ENABLED";
    attribute GSR of FF_31 : label is "ENABLED";
    attribute GSR of FF_30 : label is "ENABLED";
    attribute GSR of FF_29 : label is "ENABLED";
    attribute GSR of FF_28 : label is "ENABLED";
    attribute GSR of FF_27 : label is "ENABLED";
    attribute GSR of FF_26 : label is "ENABLED";
    attribute GSR of FF_25 : label is "ENABLED";
    attribute GSR of FF_24 : label is "ENABLED";
    attribute GSR of FF_23 : label is "ENABLED";
    attribute GSR of FF_22 : label is "ENABLED";
    attribute GSR of FF_21 : label is "ENABLED";
    attribute GSR of FF_20 : label is "ENABLED";
    attribute GSR of FF_19 : label is "ENABLED";
    attribute GSR of FF_18 : label is "ENABLED";
    attribute GSR of FF_17 : label is "ENABLED";
    attribute GSR of FF_16 : label is "ENABLED";
    attribute GSR of FF_15 : label is "ENABLED";
    attribute GSR of FF_14 : label is "ENABLED";
    attribute GSR of FF_13 : label is "ENABLED";
    attribute GSR of FF_12 : label is "ENABLED";
    attribute GSR of FF_11 : label is "ENABLED";
    attribute GSR of FF_10 : label is "ENABLED";
    attribute GSR of FF_9 : label is "ENABLED";
    attribute GSR of FF_8 : label is "ENABLED";
    attribute GSR of FF_7 : label is "ENABLED";
    attribute GSR of FF_6 : label is "ENABLED";
    attribute GSR of FF_5 : label is "ENABLED";
    attribute GSR of FF_4 : label is "ENABLED";
    attribute GSR of FF_3 : label is "ENABLED";
    attribute GSR of FF_2 : label is "ENABLED";
    attribute GSR of FF_1 : label is "ENABLED";
    attribute GSR of FF_0 : label is "ENABLED";
    attribute MEM_INIT_FILE of fifo_pfu_0_0 : label is "(0-7)(0-3)";
    attribute MEM_LPC_FILE of fifo_pfu_0_0 : label is "async_fifo_16x8_ecp3.lpc";
    attribute COMP of fifo_pfu_0_0 : label is "fifo_pfu_0_0";
    attribute MEM_INIT_FILE of fifo_pfu_0_1 : label is "(0-7)(4-7)";
    attribute MEM_LPC_FILE of fifo_pfu_0_1 : label is "async_fifo_16x8_ecp3.lpc";
    attribute COMP of fifo_pfu_0_1 : label is "fifo_pfu_0_1";
    attribute syn_keep : boolean;
    attribute NGD_DRC_MASK : integer;
    attribute NGD_DRC_MASK of Structure : architecture is 1;

begin
    -- component instantiation statements
    AND2_t8: AND2
        port map (A=>WrEn, B=>invout_1, Z=>wren_i);

    INV_1: INV
        port map (A=>full_i, Z=>invout_1);

    AND2_t7: AND2
        port map (A=>RdEn, B=>invout_0, Z=>rden_i);

    INV_0: INV
        port map (A=>empty_i, Z=>invout_0);

    OR2_t6: OR2
        port map (A=>Reset, B=>RPReset, Z=>rRst);

    XOR2_t5: XOR2
        port map (A=>wcount_0, B=>wcount_1, Z=>w_gdata_0);

    XOR2_t4: XOR2
        port map (A=>wcount_1, B=>wcount_2, Z=>w_gdata_1);

    XOR2_t3: XOR2
        port map (A=>wcount_2, B=>wcount_3, Z=>w_gdata_2);

    XOR2_t2: XOR2
        port map (A=>rcount_0, B=>rcount_1, Z=>r_gdata_0);

    XOR2_t1: XOR2
        port map (A=>rcount_1, B=>rcount_2, Z=>r_gdata_1);

    XOR2_t0: XOR2
        port map (A=>rcount_2, B=>rcount_3, Z=>r_gdata_2);

    LUT4_10: ROM16X1A
        generic map (initval=> X"8000")
        port map (AD3=>scuba_vhi, AD2=>wren_i, AD1=>scuba_vhi, 
            AD0=>scuba_vhi, DO0=>dec0_wre3);

    LUT4_9: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>w_gcount_r20, AD2=>w_gcount_r21, 
            AD1=>w_gcount_r22, AD0=>w_gcount_r23, 
            DO0=>w_g2b_xor_cluster_0);

    LUT4_8: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>w_gcount_r22, AD2=>w_gcount_r23, AD1=>scuba_vlo, 
            AD0=>scuba_vlo, DO0=>wcount_r2);

    LUT4_7: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>w_gcount_r21, AD2=>w_gcount_r22, 
            AD1=>w_gcount_r23, AD0=>scuba_vlo, DO0=>wcount_r1);

    LUT4_6: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>r_gcount_w20, AD2=>r_gcount_w21, 
            AD1=>r_gcount_w22, AD0=>r_gcount_w23, 
            DO0=>r_g2b_xor_cluster_0);

    LUT4_5: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>r_gcount_w22, AD2=>r_gcount_w23, AD1=>scuba_vlo, 
            AD0=>scuba_vlo, DO0=>rcount_w2);

    LUT4_4: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>r_gcount_w21, AD2=>r_gcount_w22, 
            AD1=>r_gcount_w23, AD0=>scuba_vlo, DO0=>rcount_w1);

    LUT4_3: ROM16X1A
        generic map (initval=> X"0410")
        port map (AD3=>rptr_3, AD2=>rcount_3, AD1=>w_gcount_r23, 
            AD0=>scuba_vlo, DO0=>empty_cmp_set);

    LUT4_2: ROM16X1A
        generic map (initval=> X"1004")
        port map (AD3=>rptr_3, AD2=>rcount_3, AD1=>w_gcount_r23, 
            AD0=>scuba_vlo, DO0=>empty_cmp_clr);

    LUT4_1: ROM16X1A
        generic map (initval=> X"0140")
        port map (AD3=>wptr_3, AD2=>wcount_3, AD1=>r_gcount_w23, 
            AD0=>scuba_vlo, DO0=>full_cmp_set);

    LUT4_0: ROM16X1A
        generic map (initval=> X"4001")
        port map (AD3=>wptr_3, AD2=>wcount_3, AD1=>r_gcount_w23, 
            AD0=>scuba_vlo, DO0=>full_cmp_clr);

    FF_49: FD1P3BX
        port map (D=>iwcount_0, SP=>wren_i, CK=>WrClock, PD=>Reset, 
            Q=>wcount_0);

    FF_48: FD1P3DX
        port map (D=>iwcount_1, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wcount_1);

    FF_47: FD1P3DX
        port map (D=>iwcount_2, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wcount_2);

    FF_46: FD1P3DX
        port map (D=>iwcount_3, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wcount_3);

    FF_45: FD1P3DX
        port map (D=>w_gdata_0, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>w_gcount_0);

    FF_44: FD1P3DX
        port map (D=>w_gdata_1, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>w_gcount_1);

    FF_43: FD1P3DX
        port map (D=>w_gdata_2, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>w_gcount_2);

    FF_42: FD1P3DX
        port map (D=>wcount_3, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>w_gcount_3);

    FF_41: FD1P3DX
        port map (D=>wcount_0, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wptr_0);

    FF_40: FD1P3DX
        port map (D=>wcount_1, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wptr_1);

    FF_39: FD1P3DX
        port map (D=>wcount_2, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wptr_2);

    FF_38: FD1P3DX
        port map (D=>wcount_3, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wptr_3);

    FF_37: FD1P3BX
        port map (D=>ircount_0, SP=>rden_i, CK=>RdClock, PD=>rRst, 
            Q=>rcount_0);

    FF_36: FD1P3DX
        port map (D=>ircount_1, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rcount_1);

    FF_35: FD1P3DX
        port map (D=>ircount_2, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rcount_2);

    FF_34: FD1P3DX
        port map (D=>ircount_3, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rcount_3);

    FF_33: FD1P3DX
        port map (D=>r_gdata_0, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>r_gcount_0);

    FF_32: FD1P3DX
        port map (D=>r_gdata_1, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>r_gcount_1);

    FF_31: FD1P3DX
        port map (D=>r_gdata_2, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>r_gcount_2);

    FF_30: FD1P3DX
        port map (D=>rcount_3, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>r_gcount_3);

    FF_29: FD1P3DX
        port map (D=>rcount_0, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rptr_0);

    FF_28: FD1P3DX
        port map (D=>rcount_1, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rptr_1);

    FF_27: FD1P3DX
        port map (D=>rcount_2, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rptr_2);

    FF_26: FD1P3DX
        port map (D=>rcount_3, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rptr_3);

    FF_25: FD1P3DX
        port map (D=>rdataout0, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>Q(0));

    FF_24: FD1P3DX
        port map (D=>rdataout1, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>Q(1));

    FF_23: FD1P3DX
        port map (D=>rdataout2, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>Q(2));

    FF_22: FD1P3DX
        port map (D=>rdataout3, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>Q(3));

    FF_21: FD1P3DX
        port map (D=>rdataout4, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>Q(4));

    FF_20: FD1P3DX
        port map (D=>rdataout5, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>Q(5));

    FF_19: FD1P3DX
        port map (D=>rdataout6, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>Q(6));

    FF_18: FD1P3DX
        port map (D=>rdataout7, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>Q(7));

    FF_17: FD1S3DX
        port map (D=>w_gcount_0, CK=>RdClock, CD=>Reset, Q=>w_gcount_r0);

    FF_16: FD1S3DX
        port map (D=>w_gcount_1, CK=>RdClock, CD=>Reset, Q=>w_gcount_r1);

    FF_15: FD1S3DX
        port map (D=>w_gcount_2, CK=>RdClock, CD=>Reset, Q=>w_gcount_r2);

    FF_14: FD1S3DX
        port map (D=>w_gcount_3, CK=>RdClock, CD=>Reset, Q=>w_gcount_r3);

    FF_13: FD1S3DX
        port map (D=>r_gcount_0, CK=>WrClock, CD=>rRst, Q=>r_gcount_w0);

    FF_12: FD1S3DX
        port map (D=>r_gcount_1, CK=>WrClock, CD=>rRst, Q=>r_gcount_w1);

    FF_11: FD1S3DX
        port map (D=>r_gcount_2, CK=>WrClock, CD=>rRst, Q=>r_gcount_w2);

    FF_10: FD1S3DX
        port map (D=>r_gcount_3, CK=>WrClock, CD=>rRst, Q=>r_gcount_w3);

    FF_9: FD1S3DX
        port map (D=>w_gcount_r0, CK=>RdClock, CD=>Reset, 
            Q=>w_gcount_r20);

    FF_8: FD1S3DX
        port map (D=>w_gcount_r1, CK=>RdClock, CD=>Reset, 
            Q=>w_gcount_r21);

    FF_7: FD1S3DX
        port map (D=>w_gcount_r2, CK=>RdClock, CD=>Reset, 
            Q=>w_gcount_r22);

    FF_6: FD1S3DX
        port map (D=>w_gcount_r3, CK=>RdClock, CD=>Reset, 
            Q=>w_gcount_r23);

    FF_5: FD1S3DX
        port map (D=>r_gcount_w0, CK=>WrClock, CD=>rRst, Q=>r_gcount_w20);

    FF_4: FD1S3DX
        port map (D=>r_gcount_w1, CK=>WrClock, CD=>rRst, Q=>r_gcount_w21);

    FF_3: FD1S3DX
        port map (D=>r_gcount_w2, CK=>WrClock, CD=>rRst, Q=>r_gcount_w22);

    FF_2: FD1S3DX
        port map (D=>r_gcount_w3, CK=>WrClock, CD=>rRst, Q=>r_gcount_w23);

    FF_1: FD1S3BX
        port map (D=>empty_d, CK=>RdClock, PD=>rRst, Q=>empty_i);

    FF_0: FD1S3DX
        port map (D=>full_d, CK=>WrClock, CD=>Reset, Q=>full_i);

    w_gctr_cia: FADD2B
        port map (A0=>scuba_vlo, A1=>scuba_vhi, B0=>scuba_vlo, 
            B1=>scuba_vhi, CI=>scuba_vlo, COUT=>w_gctr_ci, S0=>open, 
            S1=>open);

    w_gctr_0: CU2
        port map (CI=>w_gctr_ci, PC0=>wcount_0, PC1=>wcount_1, CO=>co0, 
            NC0=>iwcount_0, NC1=>iwcount_1);

    w_gctr_1: CU2
        port map (CI=>co0, PC0=>wcount_2, PC1=>wcount_3, CO=>co1, 
            NC0=>iwcount_2, NC1=>iwcount_3);

    scuba_vhi_inst: VHI
        port map (Z=>scuba_vhi);

    r_gctr_cia: FADD2B
        port map (A0=>scuba_vlo, A1=>scuba_vhi, B0=>scuba_vlo, 
            B1=>scuba_vhi, CI=>scuba_vlo, COUT=>r_gctr_ci, S0=>open, 
            S1=>open);

    r_gctr_0: CU2
        port map (CI=>r_gctr_ci, PC0=>rcount_0, PC1=>rcount_1, CO=>co0_1, 
            NC0=>ircount_0, NC1=>ircount_1);

    r_gctr_1: CU2
        port map (CI=>co0_1, PC0=>rcount_2, PC1=>rcount_3, CO=>co1_1, 
            NC0=>ircount_2, NC1=>ircount_3);

    empty_cmp_ci_a: FADD2B
        port map (A0=>scuba_vlo, A1=>rden_i, B0=>scuba_vlo, B1=>rden_i, 
            CI=>scuba_vlo, COUT=>cmp_ci, S0=>open, S1=>open);

    empty_cmp_0: AGEB2
        port map (A0=>rcount_0, A1=>rcount_1, B0=>w_g2b_xor_cluster_0, 
            B1=>wcount_r1, CI=>cmp_ci, GE=>co0_2);

    empty_cmp_1: AGEB2
        port map (A0=>rcount_2, A1=>empty_cmp_set, B0=>wcount_r2, 
            B1=>empty_cmp_clr, CI=>co0_2, GE=>empty_d_c);

    a0: FADD2B
        port map (A0=>scuba_vlo, A1=>scuba_vlo, B0=>scuba_vlo, 
            B1=>scuba_vlo, CI=>empty_d_c, COUT=>open, S0=>empty_d, 
            S1=>open);

    full_cmp_ci_a: FADD2B
        port map (A0=>scuba_vlo, A1=>wren_i, B0=>scuba_vlo, B1=>wren_i, 
            CI=>scuba_vlo, COUT=>cmp_ci_1, S0=>open, S1=>open);

    full_cmp_0: AGEB2
        port map (A0=>wcount_0, A1=>wcount_1, B0=>r_g2b_xor_cluster_0, 
            B1=>rcount_w1, CI=>cmp_ci_1, GE=>co0_3);

    full_cmp_1: AGEB2
        port map (A0=>wcount_2, A1=>full_cmp_set, B0=>rcount_w2, 
            B1=>full_cmp_clr, CI=>co0_3, GE=>full_d_c);

    a1: FADD2B
        port map (A0=>scuba_vlo, A1=>scuba_vlo, B0=>scuba_vlo, 
            B1=>scuba_vlo, CI=>full_d_c, COUT=>open, S0=>full_d, 
            S1=>open);

    fifo_pfu_0_0: DPR16X4C
        generic map (initval=> "0x0000000000000000")
        port map (DI0=>Data(4), DI1=>Data(5), DI2=>Data(6), DI3=>Data(7), 
            WCK=>WrClock, WRE=>dec0_wre3, RAD0=>rptr_0, RAD1=>rptr_1, 
            RAD2=>rptr_2, RAD3=>scuba_vlo, WAD0=>wptr_0, WAD1=>wptr_1, 
            WAD2=>wptr_2, WAD3=>scuba_vlo, DO0=>rdataout4, 
            DO1=>rdataout5, DO2=>rdataout6, DO3=>rdataout7);

    scuba_vlo_inst: VLO
        port map (Z=>scuba_vlo);

    fifo_pfu_0_1: DPR16X4C
        generic map (initval=> "0x0000000000000000")
        port map (DI0=>Data(0), DI1=>Data(1), DI2=>Data(2), DI3=>Data(3), 
            WCK=>WrClock, WRE=>dec0_wre3, RAD0=>rptr_0, RAD1=>rptr_1, 
            RAD2=>rptr_2, RAD3=>scuba_vlo, WAD0=>wptr_0, WAD1=>wptr_1, 
            WAD2=>wptr_2, WAD3=>scuba_vlo, DO0=>rdataout0, 
            DO1=>rdataout1, DO2=>rdataout2, DO3=>rdataout3);

    Empty <= empty_i;
    Full <= full_i;
end Structure;

-- synopsys translate_off
library ecp3;
configuration Structure_CON of async_fifo_16x8_ecp3 is
    for Structure
        for all:AGEB2 use entity ecp3.AGEB2(V); end for;
        for all:AND2 use entity ecp3.AND2(V); end for;
        for all:CU2 use entity ecp3.CU2(V); end for;
        for all:FADD2B use entity ecp3.FADD2B(V); end for;
        for all:FD1P3BX use entity ecp3.FD1P3BX(V); end for;
        for all:FD1P3DX use entity ecp3.FD1P3DX(V); end for;
        for all:FD1S3BX use entity ecp3.FD1S3BX(V); end for;
        for all:FD1S3DX use entity ecp3.FD1S3DX(V); end for;
        for all:INV use entity ecp3.INV(V); end for;
        for all:OR2 use entity ecp3.OR2(V); end for;
        for all:ROM16X1A use entity ecp3.ROM16X1A(V); end for;
        for all:DPR16X4C use entity ecp3.DPR16X4C(V); end for;
        for all:VHI use entity ecp3.VHI(V); end for;
        for all:VLO use entity ecp3.VLO(V); end for;
        for all:XOR2 use entity ecp3.XOR2(V); end for;
    end for;
end Structure_CON;

-- synopsys translate_on
