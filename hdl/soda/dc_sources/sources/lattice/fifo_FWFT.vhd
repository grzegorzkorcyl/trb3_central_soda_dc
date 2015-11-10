--------------------------------------------------------------------------------
--
-- File Type:    VHDL 
-- Tool Version: verilog2vhdl 18.00j
-- Input file was: fifo_FWFT.v.vpp
-- Command line was: verilog2vhdl fifo_FWFT.v
-- Date Created: Tue Aug 06 09:53:44 2013
--
--------------------------------------------------------------------------------



LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY ASC;
USE ASC.numeric_std.all;
ENTITY fwft_fifo IS	-- 
    PORT (
        SIGNAL rst : IN std_logic;	
        SIGNAL rd_clk : IN std_logic;	
        SIGNAL rd_en : IN std_logic;	
        SIGNAL dout : OUT std_logic_vector(35 DOWNTO 0);	
        SIGNAL empty : OUT std_logic;	
        SIGNAL wr_clk : IN std_logic;	
        SIGNAL wr_en : IN std_logic;	
        SIGNAL din : IN std_logic_vector(35 DOWNTO 0);	
        SIGNAL full : OUT std_logic;	
        SIGNAL prog_full : OUT std_logic);	
END fwft_fifo;



LIBRARY ASC;
ARCHITECTURE VeriArch OF fwft_fifo IS
    USE ASC.FUNCTIONS.ALL;
    USE ASC.timing.ALL;
-- Intermediate signal for empty
    SIGNAL V2V_empty : std_logic;	
-- Intermediate signal for full
    SIGNAL V2V_full : std_logic;	
-- Intermediate signal for prog_full
    SIGNAL V2V_prog_full : std_logic;	
-- Intermediate signal for dout
    SIGNAL V2V_dout : std_logic_vector(35 DOWNTO 0) REGISTER ;	

    SIGNAL fifo_valid : std_logic REGISTER ;	

    SIGNAL middle_valid : std_logic REGISTER ;	

    SIGNAL dout_valid : std_logic REGISTER ;	

    SIGNAL middle_dout : std_logic_vector(35 DOWNTO 0) REGISTER ;	

    SIGNAL fifo_dout : std_logic_vector(35 DOWNTO 0);	

    SIGNAL fifo_empty : std_logic;	

    SIGNAL fifo_rd_en : std_logic;	

    SIGNAL will_update_middle : std_logic;	

    SIGNAL will_update_dout : std_logic;	

    SIGNAL GUARD : boolean:= TRUE;	
BEGIN

    PROCESS 
    BEGIN
        WAIT UNTIL POSEDGE(rd_clk);

        IF to_boolean(rst) THEN

        ELSE

            IF to_boolean(will_update_middle) THEN
                middle_dout <= fifo_dout;	

            END IF;

            IF to_boolean(will_update_dout) THEN
                V2V_dout <= to_stdlogicvector(TERNARY(middle_valid, middle_dout, fifo_dout), 36);	

            END IF;

            IF to_boolean(fifo_rd_en) THEN
                fifo_valid <= to_stdlogic(1);	

            ELSIF to_boolean(To_bit(will_update_middle) /= '0' OR To_bit(will_update_dout) /= '0') THEN
                fifo_valid <= to_stdlogic(0);	

            END IF;

            IF to_boolean(will_update_middle) THEN
                middle_valid <= to_stdlogic(1);	

            ELSIF to_boolean(will_update_dout) THEN
                middle_valid <= to_stdlogic(0);	

            END IF;

            IF to_boolean(will_update_dout) THEN
                dout_valid <= to_stdlogic(1);	

            ELSIF to_boolean(rd_en) THEN
                dout_valid <= to_stdlogic(0);	

            END IF;
        END IF;
    END PROCESS;

    dout <= V2V_dout;	
    will_update_middle <= to_stdlogic(To_bit(fifo_valid) /= '0' AND middle_valid = will_update_dout);	
    will_update_dout <= to_stdlogic((To_bit(middle_valid) /= '0' OR To_bit(fifo_valid) /= '0') AND 
		(To_bit(rd_en) /= '0' OR NOT (To_bit(dout_valid) /= '0')));	
    fifo_rd_en <= to_stdlogic(NOT (To_bit(fifo_empty) /= '0') AND NOT (To_bit(middle_valid) /= '0' AND 
		To_bit(dout_valid) /= '0' AND To_bit(fifo_valid) /= '0'));	
    V2V_empty <= to_stdlogic(NOT (To_bit(dout_valid) /= '0'));	
    empty <= V2V_empty;	
    full <= V2V_full;	
    prog_full <= V2V_prog_full;	
END VeriArch;

