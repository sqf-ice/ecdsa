----------------------------------------------------------------------------------------------------
--  ENTITY - Elliptic Curve Point Addition
--
--  Ports:
--   clk_i    - Clock
--   rst_i    - Reset flag
--   enable_i - Enable computation
--   x1_i     - X part of first point
--   y1_i     - Y part of first point
--   x2_i     - X part of seccond point
--   y2_i     - Y part of thirs point
--   x3_io    - X part of output point
--   y3_o     - Y part of output point
--   ready_o  - Ready flag
--
--  Math:
--   s = (py-qy)/(px-qx)
--   rx = s^2 - s - (px-qx)
--   ry = s * (px - rx) - rx - py
--
--  Based on:
--   http://arithmetic-circuits.org/finite-field/vhdl_Models/chapter10_codes/VHDL/K-163/K163_addition.vhd
--
--  Autor: Lennart Bublies (inf100434)
--  Date: 27.06.2017
----------------------------------------------------------------------------------------------------

------------------------------------------------------------
-- GF(2^M) elliptic curve point addition
------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.std_logic_arith.all;
USE IEEE.std_logic_unsigned.all;
USE work.tld_ecdsa_package.all;

ENTITY e_gf2m_point_addition IS
    GENERIC (
        MODULO : std_logic_vector(M DOWNTO 0) := ONE
    );
    PORT(
        -- Clock, reset, enable
        clk_i: IN std_logic; 
        rst_i: IN std_logic; 
        enable_i: IN std_logic;
        
        -- Input signals
        x1_i: IN std_logic_vector(M-1 DOWNTO 0);
        y1_i: IN std_logic_vector(M-1 DOWNTO 0); 
        x2_i: IN std_logic_vector(M-1 DOWNTO 0); 
        y2_i: IN std_logic_vector(M-1 DOWNTO 0);
        
        -- Output signals
        x3_io: INOUT std_logic_vector(M-1 DOWNTO 0);
        y3_o: OUT std_logic_vector(M-1 DOWNTO 0);
        ready_o: OUT std_logic
    );
END e_gf2m_point_addition;

ARCHITECTURE rtl of e_gf2m_point_addition IS
    -- Import entity e_gf2m_divider
    COMPONENT e_gf2m_divider IS
        GENERIC (
            MODULO : std_logic_vector(M DOWNTO 0)
        );
        PORT(
            clk_i: IN std_logic;  
            rst_i: IN std_logic;  
            enable_i: IN std_logic; 
            g_i: IN std_logic_vector(M-1 DOWNTO 0);  
            h_i: IN std_logic_vector(M-1 DOWNTO 0); 
            z_o: OUT std_logic_vector(M-1 DOWNTO 0);
            ready_o: OUT std_logic
        );
    end COMPONENT;
    
    -- Import entity e_gf2m_classic_squarer
    COMPONENT e_gf2m_classic_squarer IS
        GENERIC (
            MODULO : std_logic_vector(M-1 DOWNTO 0)
        );
        PORT(
            a_i: IN std_logic_vector(M-1 DOWNTO 0);
            c_o: OUT std_logic_vector(M-1 DOWNTO 0)
        );
    end COMPONENT;
    
    -- Import entity e_gf2m_interleaved_multiplier
    COMPONENT e_gf2m_interleaved_multiplier IS
        GENERIC (
            MODULO : std_logic_vector(M-1 DOWNTO 0)
        );
        PORT(
            clk_i: IN std_logic; 
            rst_i: IN std_logic; 
            enable_i: IN std_logic; 
            a_i: IN std_logic_vector (M-1 DOWNTO 0); 
            b_i: IN std_logic_vector (M-1 DOWNTO 0);
            z_o: OUT std_logic_vector (M-1 DOWNTO 0);
            ready_o: OUT std_logic
        );
    end COMPONENT;
    
    -- Temporary signals for divider and multiplier
    SIGNAL div_in1, div_in2, lambda, lambda_square, mult_in2, mult_out: std_logic_vector(M-1 DOWNTO 0);
    SIGNAL x3_tmp, y3_tmp, next_xq, next_yq: std_logic_vector(M-1 DOWNTO 0);
    
    -- Signals to switch between multiplier and divider
    SIGNAL start_div, div_done, start_mult, mult_done: std_logic;
    SIGNAL load, ch_q: std_logic;
    SIGNAL sel: std_logic_vector(1 DOWNTO 0);
    
    -- Define all available states
    subtype states IS natural RANGE 0 TO 10;
    SIGNAL current_state: states;
BEGIN
    -- Output register
    register_q: PROCESS(clk_i)
    BEGIN
        IF clk_i' event and clk_i = '1' THEN 
            IF load = '1' THEN 
                x3_io <= (OTHERS=>'1');
                y3_o <= (OTHERS=>'1');
            ELSIF ch_q = '1' THEN 
                x3_io <= next_xq; 
                y3_o <= next_yq;
            END IF;
        END IF;
    END PROCESS;

    -- Instantiate divider entity
    --  Calculate s = (py-qy)/(px-qx)
    divider: e_gf2m_divider GENERIC MAP (
            MODULO => MODULO
    ) PORT MAP( 
        clk_i => clk_i, 
        rst_i => rst_i, 
        enable_i => start_div,
        g_i => div_in1, 
        h_i => div_in2,  
        z_o => lambda, 
        ready_o => div_done
    );
    
    -- Instantiate squarer 
    --  Calculate s^2
    lambda_square_computation: e_gf2m_classic_squarer GENERIC MAP (
            MODULO => MODULO(M-1 DOWNTO 0)
    ) PORT MAP( 
        a_i => lambda, 
        c_o => lambda_square
    );
  
    -- Instantiate multiplier entity
    --  Calculate s * (px - rx)
    multiplier: e_gf2m_interleaved_multiplier GENERIC MAP (
        MODULO => MODULO(M-1 DOWNTO 0)
    ) PORT MAP( 
        clk_i => clk_i, 
        rst_i => rst_i, 
        enable_i => start_mult, 
        a_i => lambda, 
        b_i => mult_in2, 
        z_o => mult_out, 
        ready_o => mult_done
    );

    -- Set divider input from entity input
    --  Calculate (py-qy) and (px-qx)
    divider_inputs: FOR i IN 0 TO M-1 GENERATE 
        div_in1(i) <= y1_i(i) xor y2_i(i);
        div_in2(i) <= x1_i(i) xor x2_i(i);
    END GENERATE;

    -- Set multiplier input from entity input 
    --  Calculate (px - rx)
    multiplier_inputs: FOR i IN 0 TO M-1 GENERATE
        mult_in2(i) <= x1_i(i) xor x3_tmp(i);
    END GENERATE;

    -- Set x3(0)
    --x3_tmp(0) <= not(lambda_square(0) xor lambda(0) xor div_in2(0));

    -- Set output
    --  Calculate rx = s^2 - s - (px-qx)
    x_output: FOR i IN 0 TO M-1 GENERATE
        x3_tmp(i) <= lambda_square(i) xor lambda(i) xor div_in2(i) xor a(i);
    END GENERATE;

    --  Calculate ry = s * (px - rx) - rx - py
    y_output: FOR i IN 0 TO M-1 GENERATE
        y3_tmp(i) <= mult_out(i) xor x3_tmp(i) xor y1_i(i);
    END GENERATE;

    WITH sel SELECT next_yq <= y3_tmp WHEN "00", y1_i WHEN "01", y2_i WHEN OTHERS;
    WITH sel SELECT next_xq <= x3_tmp WHEN "00", x1_i WHEN "01", x2_i WHEN OTHERS;

    -- State machine
    control_unit: PROCESS(clk_i, rst_i, current_state)
    BEGIN
        -- Handle current state
        --  0,1   : Default state
        --  2,3   : Calculate s = (py-qy)/(px-qx), s^2
        --  4,5,6 : Calculate rx/ry 
        CASE current_state IS
            WHEN 0 TO 1 => load <= '0'; sel <= "00"; ch_q <= '0'; start_div <= '0'; start_mult <= '0'; ready_o <= '1';
            WHEN 2      => load <= '1'; sel <= "00"; ch_q <= '0'; start_div <= '0'; start_mult <= '0'; ready_o <= '0';
            WHEN 3      => load <= '0'; sel <= "00"; ch_q <= '0'; start_div <= '0'; start_mult <= '0'; ready_o <= '0';
            WHEN 4      => load <= '0'; sel <= "00"; ch_q <= '0'; start_div <= '1'; start_mult <= '0'; ready_o <= '0';
            WHEN 5      => load <= '0'; sel <= "00"; ch_q <= '0'; start_div <= '0'; start_mult <= '0'; ready_o <= '0';
            WHEN 6      => load <= '0'; sel <= "00"; ch_q <= '0'; start_div <= '0'; start_mult <= '1'; ready_o <= '0';
            WHEN 7      => load <= '0'; sel <= "00"; ch_q <= '0'; start_div <= '0'; start_mult <= '0'; ready_o <= '0';
            WHEN 8      => load <= '0'; sel <= "00"; ch_q <= '1'; start_div <= '0'; start_mult <= '0'; ready_o <= '0';
            WHEN 9      => load <= '0'; sel <= "11"; ch_q <= '1'; start_div <= '0'; start_mult <= '0'; ready_o <= '0';
            WHEN 10     => load <= '0'; sel <= "01"; ch_q <= '1'; start_div <= '0'; start_mult <= '0'; ready_o <= '0';
        END CASE;

        IF rst_i = '1' THEN 
            -- Reset state if reset is high
            current_state <= 0;
        ELSIF clk_i'event and clk_i = '1' THEN
            -- Set next state
            CASE current_state IS
                WHEN 0 => 
                    IF enable_i = '0' THEN 
                        current_state <= 1; 
                    END IF;
                WHEN 1 => 
                    IF enable_i = '1' THEN 
                        current_state <= 2; 
                    END IF; 
                WHEN 2 => 
                    current_state <= 3;
                WHEN 3 =>
                    IF (x1_i = ONES) OR (y1_i = ONES) THEN
                        current_state <= 9;
                    ELSIF (x2_i = ONES) OR (y2_i = ONES) THEN
                        current_state <= 10;                    
                    ELSE 
                        current_state <= 4;
                    END IF;
                WHEN 4 =>
                    current_state <= 5;
                WHEN 5 => 
                    IF div_done = '1' THEN 
                        current_state <= 6; 
                    END IF;
                WHEN 6 => 
                    current_state <= 7;
                WHEN 7 => 
                    IF mult_done = '1' THEN 
                        current_state <= 8; 
                    END IF;
                WHEN 8 => 
                    current_state <= 0;
                WHEN 9 =>
                    current_state <= 0;
                WHEN 10 =>
                    current_state <= 0;
            END CASE;
        END IF;
    END PROCESS;
END rtl;
