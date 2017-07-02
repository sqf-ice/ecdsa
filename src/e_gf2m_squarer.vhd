----------------------------------------------------------------------------------------------------
--  ENTITY - GF(2^M) Classic Squaring
--  Computes the polynomial multiplication A.A mod f IN GF(2**m)
--
--  Its IS based on classic modular multiplier, but USE the fact that
--  squaring a polinomial IS simplier than multiply.
--
--  Ports:
--   a_i : Input to square
--   c_o : Square of input
-- 
--  Source:
--   http://arithmetic-circuits.org/finite-field/vhdl_Models/chapter10_codes/VHDL/K-163/classic_squarer.vhd
--
--  Autor: Lennart Bublies (inf100434)
--  Date: 26.06.2017
----------------------------------------------------------------------------------------------------

------------------------------------------------------------
-- GF(2^M) classic squaring package
------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.std_logic_arith.all;
USE IEEE.std_logic_unsigned.all;

PACKAGE p_gf2m_classic_squarer_parameters IS
    -- Constants
    CONSTANT M: integer := 8;
    CONSTANT F: std_logic_vector(M-1 DOWNTO 0):= "00011011";
    --CONSTANT F: std_logic_vector(M-1 DOWNTO 0):= "000"&x"00000000000000000000000000000000000000C9"; --FOR M=163

    -- Types
    TYPE matrix_reductionR IS ARRAY (0 TO M-1) OF STD_LOGIC_VECTOR(M-2 DOWNTO 0);
    
    -- Functions
    FUNCTION reduction_matrix_R RETURN matrix_reductionR;
END p_gf2m_classic_squarer_parameters;

PACKAGE BODY p_gf2m_classic_squarer_parameters IS
    FUNCTION reduction_matrix_R RETURN matrix_reductionR IS
    VARIABLE R: matrix_reductionR;
    BEGIN
        -- Initialise matrix WITH zeros
        --   000000
        --   000000
        --   000000
        --   000000
        --   000000
        --   000000
        --   000000
        --   000000
        FOR j IN 0 TO M-1 LOOP
            FOR i IN 0 TO M-2 LOOP
                R(j)(i) := '0'; 
            END LOOP;
        END LOOP;
        
        -- Copy F polynomial "00011011" TO array 
        --   000001
        --   000001
        --   000000
        --   000001
        --   000001
        --   000000
        --   000000
        --   000000
        FOR j IN 0 TO M-1 LOOP
            R(j)(0) := F(j);
        END LOOP;
        
        -- Compute .... (after first round)
        --   0000 0 1
        --   0000 1 1
        --   0000 1 0     
        --   0000 1 1     
        --   0000 1 1     
        --   0000 1 0     
        --   0000 1 0     
        --   0000 1 0     
        FOR i IN 1 TO M-2 LOOP
            FOR j IN 0 TO M-1 LOOP
                IF j = 0 THEN 
                    R(j)(i) := R(M-1)(i-1) and R(j)(0);
                ELSE
                    R(j)(i) := R(j-1)(i-1) xor (R(M-1)(i-1) and R(j)(0)); 
                END IF;
            END LOOP;
        END LOOP;
        
        RETURN R;
    END reduction_matrix_R;
END p_gf2m_classic_squarer_parameters;

------------------------------------------------------------
-- GF(2^M) polynomial reduction
------------------------------------------------------------
LIBRARY ieee; 
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;
USE work.p_gf2m_classic_squarer_parameters.all;

ENTITY e_gf2m_reducer IS
    PORT (
        -- Input SIGNAL
        d: IN std_logic_vector(2*M-2 DOWNTO 0);
        
        -- Output SIGNAL
        c: OUT std_logic_vector(M-1 DOWNTO 0)
    );
END e_gf2m_reducer;

ARCHITECTURE rtl OF e_gf2m_reducer IS
    -- Initial reduction matrix from polynomial F
    CONSTANT R: matrix_reductionR := reduction_matrix_R;
    -- Temporary SIGNAL, neccessary?
    SIGNAL S: matrix_reductionR;
BEGIN
    S <= R; -- TODO: neccessary?
    
    -- GENERATE M-1 XORs FOR each redcutions matrix row
    gen_xors: FOR j IN 0 TO M-1 GENERATE
        l1: PROCESS(d) 
            VARIABLE aux: std_logic;
            BEGIN
                -- Store j-bit from input
                aux := d(j);
                
                -- Compute target bit FOR each reduction matrix column
                FOR i IN 0 TO M-2 LOOP 
                    aux := aux xor (d(M+i) and R(j)(i)); 
                END LOOP;
                c(j) <= aux;
        END PROCESS;
    END GENERATE;
END rtl;

------------------------------------------------------------
-- GF(2^M) classic squaring entity
------------------------------------------------------------
LIBRARY ieee; 
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;
USE work.p_gf2m_classic_squarer_parameters.all;

ENTITY e_classic_gf2m_squarer IS
    PORT (
        -- Input SIGNAL
        a_i: IN std_logic_vector(M-1 DOWNTO 0);
        
        -- Output SIGNAL
        c_o: OUT std_logic_vector(M-1 DOWNTO 0)
    );
END e_classic_gf2m_squarer;

ARCHITECTURE rtl OF e_classic_gf2m_squarer IS
    -- Import entity e_gf2m_reducer
    COMPONENT e_gf2m_reducer IS
        PORT(
            d: IN std_logic_vector(2*M-2 DOWNTO 0);
            c: OUT std_logic_vector(M-1 DOWNTO 0)
        );
    end COMPONENT;

    SIGNAL b: std_logic_vector(2*M-2 DOWNTO 0);
BEGIN
    b(0) <= a_i(0);

    -- TODO - WHY IS IT CORRECT?
    square: FOR i IN 1 TO M-1 GENERATE
        b(2*i-1) <= '0';
        b(2*i) <= a_i(i);
    END GENERATE;

    -- Instantiate polynomial reducer
    reducer: e_gf2m_reducer PORT MAP(
            d => b, 
            c => c_o
        );
END rtl;