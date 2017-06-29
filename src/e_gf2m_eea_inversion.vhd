----------------------------------------------------------------------------------------------------
--  Entity - GF(2^M) Extended Euclidean Inversion
--  Computes the 1/x mod F IN GF(2**M)
--
--  Ports:
-- 
--  Autor: Lennart Bublies (inf100434)
--  Date: 26.06.2017
----------------------------------------------------------------------------------------------------

------------------------------------------------------------
-- GF(2^M) eea inversion package
------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.std_logic_arith.all;
USE IEEE.std_logic_unsigned.all;

PACKAGE p_gf2m_eea_inversion_package IS
    -- Constants
    CONSTANT M: integer := 8;
    CONSTANT logM: integer := 3;
    CONSTANT F: std_logic_vector(M-1 DOWNTO 0):= "00011011"; --for M=8 bits
    --CONSTANT F: std_logic_vector(M-1 DOWNTO 0):= "000"&x"00000000000000000000000000000000000000C9"; --for M=163
END p_gf2m_eea_inversion_package;


------------------------------------------------------------
-- GF(2^M) eea inversion data path
------------------------------------------------------------

LIBRARY ieee; 
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;
USE work.p_gf2m_eea_inversion_package.all;

ENTITY e_gf2m_eea_inversion_data_path IS
    PORT (
        -- Input signals
        r, s: IN std_logic_vector(M DOWNTO 0);
        u, v: IN std_logic_vector(M DOWNTO 0);
        d: IN STD_LOGIC_VECTOR (logM DOWNTO 0);

        -- Output signals
        new_r, new_s: OUT std_logic_vector(M DOWNTO 0);
        new_u, new_v: OUT std_logic_vector(M DOWNTO 0);
        new_d: OUT STD_LOGIC_VECTOR (logM DOWNTO 0)
    );
END e_gf2m_eea_inversion_data_path;

ARCHITECTURE rtl of e_gf2m_eea_inversion_data_path IS
    CONSTANT zero: std_logic_vector(logM DOWNTO 0):= (OTHERS => '0');
BEGIN
    PROCESS(r,s,u,v,d)
    BEGIN
        IF R(m) = '0' THEN
            new_R <= R(M-1 DOWNTO 0) & '0';
            new_U <= U(M-1 DOWNTO 0) & '0';
            new_S <= S;
            new_V <= V;
            new_d <= d + 1;
        ELSE
            IF d = ZERO THEN
                IF S(m) = '1' THEN
                    new_R <= (S(M-1 DOWNTO 0) xor R(M-1 DOWNTO 0)) & '0';
                    new_U <= (V(M-1 DOWNTO 0) xor U(M-1 DOWNTO 0)) & '0';
                ELSE
                    new_R <= S(M-1 DOWNTO 0) & '0';
                    new_U <= V(M-1 DOWNTO 0) & '0';
                END IF;
                new_S <= R;
                new_V <= U;
                new_d <= (0=> '1', OTHERS => '0');
            ELSE
                new_R <= R;
                new_U <= '0' & U(M DOWNTO 1);
                IF S(m) = '1' THEN
                     new_S <= (S(M-1 DOWNTO 0) xor R(M-1 DOWNTO 0)) & '0';
                     new_V <= (V xor U);
                ELSE
                    new_S <= S(M-1 DOWNTO 0) & '0';
                    new_V <= V;
                END IF;
                new_d <= d - 1;
            END IF;
        END IF;
    END PROCESS;
END rtl;

------------------------------------------------------------
-- GF(2^M) eea inversion
------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.std_logic_arith.all;
USE IEEE.std_logic_unsigned.all;
USE work.p_gf2m_eea_inversion_package.all;

ENTITY e_gf2m_eea_inversion IS
PORT (
    -- Input signals
    A: IN std_logic_vector (M-1 DOWNTO 0);
    clk, rst, start: IN std_logic; 

    -- Output signals
    Z: OUT std_logic_vector (M-1 DOWNTO 0);
    ready: OUT std_logic
);
END e_gf2m_eea_inversion;

ARCHITECTURE rtl of e_gf2m_eea_inversion IS
    COMPONENT e_gf2m_eea_inversion_data_path
        PORT(
            r, s : IN std_logic_vector(M DOWNTO 0);
            u, v : IN std_logic_vector(M DOWNTO 0);
            d : IN std_logic_vector(logM DOWNTO 0);

            new_r, new_s : OUT std_logic_vector(M DOWNTO 0);
            new_u, new_v : OUT std_logic_vector(M DOWNTO 0);
            new_d : OUT std_logic_vector(logM DOWNTO 0)
        );
    END COMPONENT;

    SIGNAL count: natural RANGE 0 TO 2*M;
    TYPE states IS RANGE 0 TO 3;
    SIGNAL current_state: states;

    SIGNAL first_step, capture: std_logic; 
    SIGNAL r, s, new_r, new_s : std_logic_vector(M DOWNTO 0);
    SIGNAL u, v, new_u, new_v: std_logic_vector(M DOWNTO 0);
    SIGNAL d, new_d: std_logic_vector(logM DOWNTO 0);
BEGIN
    -- Instantiate inversion data path
    data_path_block: eea_inversion_data_path PORT MAP(
        r => r, s => s,
        u => u, v => v, d => d, 
        new_r => new_r, new_s => new_s,
        new_u => new_u, new_v => new_v, new_d => new_d 
    );

    z <= u(M-1 DOWNTO 0);

    PROCESS(clk, rst)
    BEGIN
        -- Reset entity on reset
        IF rst = '1' or first_step = '1' THEN 
            r <= ('0' & A); s <= ('1' & F);
            u <= (0 => '1', OTHERS => '0'); v <= (OTHERS => '0');
            d <= (OTHERS => '0');
        ELSIF clk'event and clk = '1' THEN
            IF capture = '1' THEN
                r <= new_r; s <= new_s;
                u <= new_u; v <= new_v;
                d <= new_d; 
            END IF;
        END IF;
    END PROCESS;

    counter: PROCESS(rst, clk)
    BEGIN
        IF rst = '1' THEN 
            count <= 0;
        ELSIF clk'event and clk = '1' THEN
            IF first_step = '1' THEN 
                count <= 0;
            ELSIF capture = '1' THEN
                count <= count+1; 
            END IF;
        END IF;
    END PROCESS counter;

    control_unit: PROCESS(clk, rst, current_state, count)
    BEGIN
        CASE current_state IS
            WHEN 0 TO 1 => first_step <= '0'; ready <= '1'; capture <= '0';
            WHEN 2 => first_step <= '1'; ready <= '0'; capture <= '0';
            WHEN 3 => first_step <= '0'; ready <= '0'; capture <= '1';
        END CASE;

        IF rst = '1' THEN 
            current_state <= 0;
        ELSIF clk'event and clk = '1' THEN
            CASE current_state IS
                WHEN 0 => IF start = '0' THEN current_state <= 1; END IF;
                WHEN 1 => IF start = '1' THEN current_state <= 2; END IF;
                WHEN 2 => current_state <= 3;
            WHEN 3 => IF count = 2*M-1 THEN current_state <= 0; END IF;
            END CASE;
        END IF;
    END PROCESS control_unit;
END rtl;