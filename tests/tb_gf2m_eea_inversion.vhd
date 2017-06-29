----------------------------------------------------------------------------------------------------
--  Testbench - GF(2^M) Extended Euclidean Inversion
--
--  Autor: Lennart Bublies (inf100434)
--  Date: 22.06.2017
----------------------------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE IEEE.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.ALL;
USE ieee.std_logic_textio.ALL;
USE ieee.math_real.all; -- FOR UNIFORM, TRUNC

USE std.textio.ALL;
USE work.p_gf2m_eea_inversion_package.all;

ENTITY tb_eea_inversion IS
END test_eea_inversion;

ARCHITECTURE behavior OF test_eea_inversion IS 
    -- Internal signals
    SIGNAL x, z, z_by_x :  std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');
    SIGNAL clk, reset, start, done: std_logic;
    CONSTANT ZERO: std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');
    CONSTANT ONE: std_logic_vector(M-1 DOWNTO 0) := (0 => '1', OTHERS=>'0');
    CONSTANT DELAY : time := 100 ns;
    CONSTANT PERIOD : time := 200 ns;
    CONSTANT DUTY_CYCLE : real := 0.5;
    CONSTANT OFFSET : time := 0 ns;
    CONSTANT NUMBER_TESTS: natural := 10;
BEGIN
    -- Instantiate eea inversion
    uut1: work.e_gf2m_eea_inversion PORT MAP(
            a => x, 
            clk => clk, 
            reset => reset, 
            start => start,
            z => z, 
            ready => done
        );
                          
    -- Instantiate classic multiplication                        
    uut2: work.e_classic_gf2m_multiplier PORT MAP(
            a => x, 
            b => z, 
            c => z_by_x 
        );

    -- Create clock signal
    PROCESS -- clock process FOR clk
    BEGIN
        WAIT FOR OFFSET;
        CLOCK_LOOP : LOOP
            clk <= '0';
            WAIT FOR (PERIOD *(1.0 - DUTY_CYCLE));
            clk <= '1';
            WAIT FOR (PERIOD * DUTY_CYCLE);
        END LOOP CLOCK_LOOP;
    END PROCESS;

    -- Generate Values
    tb_proc : PROCESS 
        PROCEDURE gen_random(X : OUT std_logic_vector (M-1 DOWNTO 0); w: natural; s1, s2: inout Natural) IS
            VARIABLE i_x, aux: integer;
            VARIABLE rand: real;
        BEGIN
            aux := W/16;
            FOR i IN 1 TO aux LOOP
                UNIFORM(s1, s2, rand);
                i_x := INTEGER(TRUNC(rand * real(2**16)));
                x(i*16-1 DOWNTO (i-1)*16) := CONV_STD_LOGIC_VECTOR (i_x, 16);
            END LOOP;
                UNIFORM(s1, s2, rand);
                i_x := INTEGER(TRUNC(rand * real(2**(w-aux*16))));
                x(w-1 DOWNTO aux*16) := CONV_STD_LOGIC_VECTOR (i_x, (w-aux*16));
        END PROCEDURE;

        VARIABLE TX_LOC : LINE;
        VARIABLE TX_STR : String(1 TO 4096);
        VARIABLE seed1, seed2: positive; 
        VARIABLE i_x, i_y, i_p, i_z, i_yz_modp: integer;
        VARIABLE cycles, max_cycles, min_cycles, total_cycles: integer := 0;
        VARIABLE avg_cycles: real;
        VARIABLE initial_time, final_time: time;
        VARIABLE xx: std_logic_vector (M-1 DOWNTO 0) ;
    BEGIN
        min_cycles:= 2**20;
        start <= '0'; reset <= '1';
        WAIT FOR PERIOD;
        reset <= '0';
        WAIT FOR PERIOD;

        FOR I IN 1 TO NUMBER_TESTS LOOP
            gen_random(xx, M, seed1, seed2);
            WHILE (xx = ZERO) LOOP 
                gen_random(xx, M, seed1, seed2); 
            END LOOP;
            x <= xx;

            start <= '1'; initial_time := now;
            WAIT FOR PERIOD;
            start <= '0';
            WAIT UNTIL done = '1';
            final_time := now;
            cycles := (final_time - initial_time)/PERIOD;
            total_cycles := total_cycles+cycles;
            --ASSERT (FALSE) REPORT "Number of Cycles: " & integer'image(cycles) & "  TotalCycles: " & integer'image(total_cycles) SEVERITY WARNING;
            
            IF cycles > max_cycles THEN     
                max_cycles:= cycles; 
            END IF;
            IF cycles < min_cycles THEN  
                min_cycles:= cycles; 
            END IF;

            WAIT FOR 2*PERIOD;

            IF ( ONE /= z_by_x) THEN 
                write(TX_LOC,string'("ERROR!!! z_by_x=")); write(TX_LOC, z_by_x);
                write(TX_LOC,string'("/= ONE=")); 
                write(TX_LOC,string'("( z=")); write(TX_LOC, z);
                write(TX_LOC,string'(") using: ( A =")); write(TX_LOC, x);
                write(TX_LOC, string'(", F = 1")); write(TX_LOC, F);
                write(TX_LOC, string'(" )"));
                TX_STR(TX_LOC.all'range) := TX_LOC.all;
                Deallocate(TX_LOC);
                ASSERT (FALSE) REPORT TX_STR SEVERITY ERROR;
            END IF;  
        END LOOP;
        
        WAIT FOR DELAY;
        
        avg_cycles := real(total_cycles)/real(NUMBER_TESTS);
        
        ASSERT (FALSE) REPORT
            "Simulation successful!.  MinCycles: " & integer'image(min_cycles) &
            "  MaxCycles: " & integer'image(max_cycles) & "  TotalCycles: " & integer'image(total_cycles) &
            "  AvgCycles: " & real'image(avg_cycles)
            SEVERITY FAILURE;
    END PROCESS;
END;