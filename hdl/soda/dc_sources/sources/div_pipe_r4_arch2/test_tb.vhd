--------------------------------------------------------------------
-- VHDL Test Bench for sequential divider
--
-- Notes: 
-- Exhaustive testbench. 
-- Only for small values of XBITS and YBITS
--------------------------------------------------------------------

LIBRARY  IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.std_logic_arith.all;
USE IEEE.std_logic_unsigned.all;

LIBRARY ieee;
USE IEEE.STD_LOGIC_TEXTIO.ALL;
USE STD.TEXTIO.ALL;

ENTITY testb_tb_pipe IS
END testb_tb_pipe;

ARCHITECTURE pruebas OF testb_tb_pipe IS 
FILE RESULTS: TEXT OPEN WRITE_MODE IS "results.txt";
   constant XBITS :INTEGER := 28; 
   constant YBITS :INTEGER := 16;
   constant GRAIN :INTEGER := 2; --Allways in 2!!!!
   constant DEPTH :INTEGER := 1; --Every how much steps register
	
	
   COMPONENT div_r4_pipe
	generic (
		XBITS : natural := XBITS;
		YBITS : natural := YBITS;
		GRAIN : natural := GRAIN;
		DEPTH : natural := DEPTH
	);
   PORT(
      a : IN std_logic_vector(XBITS-1 downto 0);
      b : IN std_logic_vector(YBITS-1 downto 0);
      clk : IN std_logic;          
      q : OUT std_logic_vector(XBITS-1 downto 0);
      r : OUT std_logic_vector(YBITS-1 downto 0)
      );
   END COMPONENT;

   SIGNAL x :  std_logic_vector(XBITS-1 downto 0);
   SIGNAL y :  std_logic_vector(YBITS-1 downto 0);
   SIGNAL clk :  std_logic;
   SIGNAL q :  std_logic_vector(XBITS-1 downto 0);
   SIGNAL r :  std_logic_vector(YBITS-1 downto 0);
   constant PERIOD: time := 10 ns;   

BEGIN

   uut: div_r4_pipe PORT MAP(
      a => x, 
		b => y,
      clk => clk,
      q => q, 
		r => r
   );

   PROCESS -- clock process (drives clk),
   BEGIN
      clk <= '0';
      WAIT FOR PERIOD/2;
      clk <= '1';
      WAIT FOR PERIOD/2;
   END PROCESS;


tb_gen : PROCESS --generate values
   VARIABLE TX_LOC : LINE;
   VARIABLE TX_STR : String(1 to 4096);
   BEGIN
			x <= CONV_STD_LOGIC_VECTOR (200, XBITS);
			y <= CONV_STD_LOGIC_VECTOR (10, YBITS);
			WAIT FOR PERIOD*(YBITS+4);
			x <= CONV_STD_LOGIC_VECTOR (4364537, XBITS);
			y <= CONV_STD_LOGIC_VECTOR (4325, YBITS);
			WAIT FOR PERIOD*(YBITS+4);

			x <= CONV_STD_LOGIC_VECTOR (83456342, XBITS);
			y <= CONV_STD_LOGIC_VECTOR (6545, YBITS);
			WAIT FOR PERIOD*(YBITS+4);
			for i in 0 to 20 loop
				x <= CONV_STD_LOGIC_VECTOR (100+i*2000, XBITS);
				y <= CONV_STD_LOGIC_VECTOR (2000, YBITS);
				WAIT FOR PERIOD;
			end loop;
			
   END PROCESS;
	
--   tb_gen : PROCESS --generate values
--   VARIABLE TX_LOC : LINE;
--   VARIABLE TX_STR : String(1 to 4096);
--   BEGIN
--      for I in 0  to 2**XBITS -1 loop
--         for J in 1 to 2**YBITS -1 loop
--            x <= CONV_STD_LOGIC_VECTOR (I, XBITS);
--            y <= CONV_STD_LOGIC_VECTOR (J, YBITS);
--            WAIT FOR PERIOD;
--         end loop;
--      end loop;
--
--      WAIT FOR 3 * PERIOD;
--
--   END PROCESS;
--
--   tb_test : PROCESS --test the correctness of data
--   VARIABLE TX_LOC : LINE;
--   VARIABLE TX_STR : String(1 to 4096);
--   BEGIN
--      WAIT FOR (XBITS/GRAIN/DEPTH)*PERIOD;
--      
--      Wait for PERIOD; --Only if you produce the result one cycle later
--      
--      for I in 0 to 2**XBITS -1 loop
--         for J in 1 to 2**YBITS -1 loop
--            WAIT FOR PERIOD;
--            IF ( I /= (J * CONV_INTEGER(Q)) + CONV_INTEGER(R)) THEN 
--               write(TX_LOC,string'("ERROR!!! X=")); write(TX_LOC, X);
--               write(TX_LOC,string'(" Y=")); write(TX_LOC, Y);
--               write(TX_LOC,string'(" Q=")); write(TX_LOC, Q);
--               write(TX_LOC,string'(" R=")); write(TX_LOC, R);
--               write(TX_LOC, string'(" "));
--               write(TX_LOC,string'(" (i=")); write(TX_LOC, i);
--               write(TX_LOC,string'(" j=")); write(TX_LOC, j); 
--               write(TX_LOC, string'(")"));
--               TX_STR(TX_LOC.all'range) := TX_LOC.all;
--               writeline(results, TX_LOC);
--               Deallocate(TX_LOC);
--               ASSERT (FALSE) REPORT TX_STR SEVERITY FAILURE;
--            ELSIF (J < CONV_INTEGER(R)) THEN 
--                  write(TX_LOC,string'("--> Error Resto Mayor que Y =")); write(TX_LOC, 0.0);
--                  write(TX_LOC,string'("ns X=")); write(TX_LOC, X);
--                  write(TX_LOC,string'(" Y=")); write(TX_LOC, Y);
--                  write(TX_LOC,string'(" Q=")); write(TX_LOC, Q);
--                  write(TX_LOC,string'(" R=")); write(TX_LOC, R);
--                  write(TX_LOC, string'(" "));
--                  TX_STR(TX_LOC.all'range) := TX_LOC.all;		
--                  writeline(results, TX_LOC);
--                  Deallocate(TX_LOC);
--                  ASSERT (FALSE) REPORT TX_STR SEVERITY ERROR;
----            ELSE -- print if everything is ok
----              write(TX_LOC,string'("OK -> X=")); write(TX_LOC, X);
----              write(TX_LOC,string'(" Y=")); write(TX_LOC, Y);
----              write(TX_LOC,string'(" Q=")); write(TX_LOC, Q);
----              write(TX_LOC,string'(" R=")); write(TX_LOC, R);
----              write(TX_LOC, string'(" "));
----              TX_STR(TX_LOC.all'range) := TX_LOC.all;
----              writeline(results, TX_LOC);
----              Deallocate(TX_LOC);
----              ASSERT (FALSE) REPORT TX_STR SEVERITY WARNING;
--
--            END IF;
--
--         end loop;
--      end loop;
--      ASSERT (FALSE) REPORT
--      "Simulation successful (not a failure).  No problems detected. "
--      SEVERITY FAILURE;
--      --wait; -- will wait forever
--   END PROCESS;

END;
