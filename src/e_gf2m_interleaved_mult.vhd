----------------------------------------------------------------------------------------------------
--  ENTITY - GF(2^M) Interleaved Multiplier
--  Computes the polynomial multiplication a*b mod F IN GF(2**M) (LSB first)
--
--  Ports:
--   clk_i    - Clock
--   rst_i    - Reset flag
--   enable_i - Enable computation
--   a_i      - First input value
--   b_i      - Seccond input value
--   z_o      - Output value
--   ready_o  - Ready flag after computation
--
--  Example:
--   (x^2+x+1)*(x^2+1) = x^4+x^3+x+1
--    1 1 1   * 1 0 1  = 11011 (bit-shift and XOR, shifts 2*M-2 bits)
--                 
--   BIT-SHIFT and XOR:        
--    11100 <- [1] 0  1   shift 2 bits
--      111 <-  1  0 [1]  shift 0 bits
--    11011 <-            XOR result
--
--    -> Result has more then M bits, so we've to reduce it by irreducible polynomial like 1011
--       11011 
--       1011  <- shift 1 bits (degree 4 - degree 3)
--        1101 <- shift 0 bits (degree 3 - degree 3)
--        1011
--         110
--
--  Based on:
--   http://arithmetic-circuits.org/finite-field/vhdl_Models/chapter10_codes/VHDL/K-163/interleaved_mult.vhd
--
--  Autor: Lennart Bublies (inf100434)
--  Date: 22.06.2017
----------------------------------------------------------------------------------------------------

-----------------------------------
-- GF(2^M) interleaved MSB-first multipication data path
-----------------------------------
LIBRARY ieee; 
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;
USE work.tld_ecdsa_package.all;

ENTITY e_gf2m_interleaved_data_path IS
    GENERIC (
        MODULO : std_logic_vector(M-1 DOWNTO 0)
    );
    PORT (
        -- Clock and reset signals
        clk_i: IN std_logic; 
        rst_i: IN std_logic;
        
        -- Input signals
        a_i: IN std_logic_vector(M-1 DOWNTO 0);
        b_i: IN std_logic_vector(M-1 DOWNTO 0);
        
        -- Load input, shift right and ???
        inic_i: IN std_logic; 
        shiftr_i: IN std_logic;  
        cec_i: IN std_logic;

        -- Output signals
        z_o: OUT std_logic_vector(M-1 DOWNTO 0)
    );
END e_gf2m_interleaved_data_path;

ARCHITECTURE rtl OF e_gf2m_interleaved_data_path IS
    -- Internal signals
    SIGNAL aa, bb, cc: std_logic_vector(M-1 DOWNTO 0);
    SIGNAL new_a, new_c: std_logic_vector(M-1 DOWNTO 0);
BEGIN
    -- Register and multiplexer
    register_a: PROCESS(clk_i, rst_i)
    BEGIN
        IF rst_i = '1' THEN 
            aa <= (OTHERS => '0');
        ELSIF clk_i'event and clk_i = '1' THEN
            IF inic_i = '1' THEN
                -- Load register a
                aa <= a_i;
            ELSE
                -- Override register a with ???
                aa <= new_a;
            END IF;
        END IF;
    END PROCESS register_a;

    shift_register_b: PROCESS(clk_i, rst_i)
    BEGIN
        IF rst_i = '1' THEN 
            bb <= (OTHERS => '0');
        ELSIF clk_i'event and clk_i = '1' THEN
            IF inic_i = '1' THEN 
                -- Load register b
                bb <= b_i;
            END IF;
            IF shiftr_i = '1' THEN 
                -- Shift input of register b
                bb <= '0' & bb(M-1 DOWNTO 1);
            END IF;
        END IF;
    END PROCESS shift_register_b;

    register_c: PROCESS(inic_i, clk_i, rst_i)
    BEGIN
        IF inic_i = '1' or rst_i = '1' THEN 
            cc <= (OTHERS => '0');
        ELSIF clk_i'event and clk_i = '1' THEN
            IF cec_i = '1' THEN 
                -- Set output register
                cc <= new_c; 
            END IF;
        END IF;
    END PROCESS register_c;
    
    -- Calculate next value for register a and c
    new_a(0) <= aa(M-1) and MODULO(0);
    new_a_calc: FOR i IN 1 TO M-1 GENERATE
        new_a(i) <= aa(i-1) xor (aa(M-1) and MODULO(i));
    END GENERATE;

    new_c_calc: FOR i IN 0 TO M-1 GENERATE
        new_c(i) <= cc(i) xor (aa(i) and bb(0));
    END GENERATE;

    -- Set output 
    z_o <= cc;    
END rtl;

-----------------------------------
-- GF(2^M) interleaved multiplication
-----------------------------------
LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.std_logic_arith.all;
USE IEEE.std_logic_unsigned.all;
USE work.tld_ecdsa_package.all;

ENTITY e_gf2m_interleaved_multiplier IS
    GENERIC (
        MODULO : std_logic_vector(M-1 DOWNTO 0) := ONE(M-1 DOWNTO 0)
    );
    PORT (
        -- Clock, reset, enable
        clk_i: IN std_logic; 
        rst_i: IN std_logic; 
        enable_i: IN std_logic; 
        
        -- Input signals
        a_i: IN std_logic_vector (M-1 DOWNTO 0); 
        b_i: IN std_logic_vector (M-1 DOWNTO 0);
        
        -- Output signals
        z_o: OUT std_logic_vector (M-1 DOWNTO 0);
        ready_o: OUT std_logic
    );
END e_gf2m_interleaved_multiplier;

ARCHITECTURE rtl OF e_gf2m_interleaved_multiplier IS    
    -- Import entity e_gf2m_interleaved_data_path
    COMPONENT e_gf2m_interleaved_data_path IS
        GENERIC (
            MODULO : std_logic_vector(M-1 DOWNTO 0)
        );
        PORT(
            clk_i: IN std_logic; 
            rst_i: IN std_logic;
            a_i: IN std_logic_vector(M-1 DOWNTO 0);
            b_i: IN std_logic_vector(M-1 DOWNTO 0);
            inic_i: IN std_logic; 
            shiftr_i: IN std_logic;  
            cec_i: IN std_logic;
            z_o: OUT std_logic_vector(M-1 DOWNTO 0)
        );
    END COMPONENT;

    SIGNAL inic, shiftr, cec: std_logic;
    SIGNAL count: natural RANGE 0 TO M;
    
    -- Define all available states
    type states IS RANGE 0 TO 3;
    SIGNAL current_state: states;
BEGIN
    -- Instantiate interleaved data path
    -- Used to computes the polynomial multiplication mod F in one step
    data_path: e_gf2m_interleaved_data_path GENERIC MAP (
            MODULO => MODULO
        ) PORT MAP (
            clk_i => clk_i,  
            rst_i => rst_i, 
            a_i => a_i, 
            b_i => b_i,
            inic_i => inic, 
            shiftr_i => shiftr,
            cec_i => cec,
            z_o => z_o
        );

    -- Clock signals
    counter: PROCESS(rst_i, clk_i)
    BEGIN
        IF rst_i = '1' THEN 
            count <= 0;
        ELSIF clk_i' event and clk_i = '1' THEN
            -- Shift until all input bits are proceeds
            IF inic = '1' THEN 
                count <= 0;
            ELSIF shiftr = '1' THEN
                count <= count+1; 
            END IF;
        END IF;
    END PROCESS counter;

    -- State machine
    control_unit: PROCESS(clk_i, rst_i, current_state)
    BEGIN
        -- Handle current state
        --  0,1   : Default state
        --  2     : Load input arguments (initialize registers)
        --  3     : Shift and add
        CASE current_state IS
            WHEN 0 TO 1 => inic <= '0'; shiftr <= '0'; cec <= '0'; ready_o <= '1';
            WHEN 2      => inic <= '1'; shiftr <= '0'; cec <= '0'; ready_o <= '0';
            WHEN 3      => inic <= '0'; shiftr <= '1'; cec <= '1'; ready_o <= '0';
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
                    IF count = M-1 THEN 
                        current_state <= 0; 
                    END IF;
            END CASE;
        END IF;
    END PROCESS control_unit;
END rtl;