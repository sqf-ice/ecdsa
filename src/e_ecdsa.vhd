----------------------------------------------------------------------------------------------------
--  TOP LEVEL ENTITY - ECDSA
--  FPDA implementation of ECDSA algorithm  
--
--  Ports:
--   clk_i     - Clock
--   rst_i     - Reset flag
--   enable_i  - Enable sign or verify
--   mode_i    - Switch between sign (0) and verify (1)
--   hash_i    - Input hash for sign/verify
--   r_i       - R part of signature for verify step
--   s_i       - S part of signature for verify step
--   ready_o   - Ready flag if sign or validation is complete
--   valid_o   - True if signature is valid
--   sign_r_o  - R part of signature after sign
--   sign_s_o  - S part of signature after sign
--
--  Autor: Lennart Bublies (inf100434)
--  Date: 02.07.2017
----------------------------------------------------------------------------------------------------

------------------------------------------------------------
-- GF(2^M) ecdsa top level entity
------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.std_logic_arith.all;
USE IEEE.std_logic_unsigned.all;
USE IEEE.numeric_std.ALL;
USE work.tld_ecdsa_package.all;

ENTITY e_ecdsa IS
    PORT (
        -- Clock and reset
        clk_i: IN std_logic; 
        rst_i: IN std_logic;

        -- Enable computation
        enable_i: IN std_logic;
        
        -- Switch between SIGN and VALIDATE
        mode_i: IN std_logic;

        -- Hash
        hash_i: IN std_logic_vector(M-1 DOWNTO 0);

        -- Signature
        r_i: IN std_logic_vector(M-1 DOWNTO 0);
        s_i: IN std_logic_vector(M-1 DOWNTO 0);
        
        -- Ready flag
        ready_o: OUT std_logic;
        
        -- Signature valid
        valid_o: OUT std_logic;
        
        -- Signature
        sign_r_o: OUT std_logic_vector(M-1 DOWNTO 0);
        sign_s_o: OUT std_logic_vector(M-1 DOWNTO 0)
    );
END e_ecdsa;

ARCHITECTURE rtl OF e_ecdsa IS 

    -- Components -----------------------------------------

    -- Import entity e_gf2m_doubleadd_point_multiplication
    --COMPONENT e_gf2m_point_multiplication IS
    COMPONENT e_gf2m_doubleadd_point_multiplication IS
        GENERIC (
            MODULO : std_logic_vector(M DOWNTO 0)
        );
        PORT (
            clk_i: IN std_logic; 
            rst_i: IN std_logic; 
            enable_i: IN std_logic;
            xp_i: IN std_logic_vector(M-1 DOWNTO 0); 
            yp_i: IN std_logic_vector(M-1 DOWNTO 0); 
            k: IN std_logic_vector(M-1 DOWNTO 0);
            xq_io: INOUT std_logic_vector(M-1 DOWNTO 0);
            yq_io: INOUT std_logic_vector(M-1 DOWNTO 0);
            ready_o: OUT std_logic
        );
    END COMPONENT;

    -- Import entity e_gf2m_point_addition
    COMPONENT e_gf2m_point_addition IS
        GENERIC (
            MODULO : std_logic_vector(M DOWNTO 0)
        );
        PORT(
            clk_i: IN std_logic; 
            rst_i: IN std_logic; 
            enable_i: IN std_logic;
            x1_i: IN std_logic_vector(M-1 DOWNTO 0);
            y1_i: IN std_logic_vector(M-1 DOWNTO 0); 
            x2_i: IN std_logic_vector(M-1 DOWNTO 0); 
            y2_i: IN std_logic_vector(M-1 DOWNTO 0);
            x3_io: INOUT std_logic_vector(M-1 DOWNTO 0);
            y3_o: OUT std_logic_vector(M-1 DOWNTO 0);
            ready_o: OUT std_logic
        );
    END COMPONENT;
    
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

    -- Import entity e_gf2m_eea_inversion
    COMPONENT e_gf2m_eea_inversion IS
        GENERIC (
            MODULO : std_logic_vector(M-1 DOWNTO 0)
        );
        PORT(
            clk_i: IN std_logic; 
            rst_i: IN std_logic; 
            enable_i: IN std_logic; 
            a_i: IN std_logic_vector (M-1 DOWNTO 0);
            z_o: OUT std_logic_vector (M-1 DOWNTO 0);
            ready_o: OUT std_logic
        );
    end COMPONENT;
    
    -- Internal signals -----------------------------------------

    --SIGNAL xG : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');  -- X of generator point G = (x, y)
    --SIGNAL yG : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');  -- Y of generator point G = (x, y)
    --SIGNAL dA : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');  -- Private key dA = k
 
    -- Parameter to sign a message, ONLY FOR TESTING!
    --SIGNAL k : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');   -- k for point generator, should be cryptograic secure randum number!
    --SIGNAL xQB : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0'); -- X component of public key qB = dB.G = (xQB, yQB)
    --SIGNAL yQB : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0'); -- Y component of public key qB = dB.G = (xQB, yQB)

    -- MODE SIGN
    SIGNAL xR : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');  -- X component of point R
    SIGNAL yR : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');  -- Y component of point R
    SIGNAL xrda, e_xrda, s : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0'); -- Temporary results for signature computation
    SIGNAL enable_sign_r, done_sign_r: std_logic := '0';          -- Enable/Disable signature computation
    SIGNAL enable_sign_darx, done_sign_darx: std_logic := '0'; 
    SIGNAL enable_sign_z2k, done_sign_z2k: std_logic := '0';

    -- MODE VERIFY
    SIGNAL w : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');
    SIGNAL U1, U2 : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');
    SIGNAL enable_verify_invs, done_verify_invs : std_logic := '0'; 
    SIGNAL enable_verify_u12, done_verify_u1, done_verify_u2 : std_logic := '0'; 
    SIGNAL enable_verify_u1gu2qb, done_verify_u1g, done_verify_u2qb : std_logic := '0';
    SIGNAL enable_verify_P, done_verify_P : std_logic := '0';
    SIGNAL xGU1, yGU1 : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');
    SIGNAL xQBU2, yQBU2 : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');
    SIGNAL xP, yP : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');

    -- Constantsenable_verify_u12
    CONSTANT ZERO: std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');
    
    -- States for state machine
    subtype states IS natural RANGE 0 TO 19;
    SIGNAL current_state: states;
BEGIN
    -- SIGN -----------------------------------------------------------------
    
    -- Instantiate multiplier to compute R = k.G = (xR, yR)
    --sign_pmul_r: e_gf2m_point_multiplication GENERIC MAP (
    sign_pmul_r: e_gf2m_doubleadd_point_multiplication GENERIC MAP (
            MODULO => P
    ) PORT MAP (
        clk_i => clk_i, 
        rst_i => rst_i, 
        enable_i => enable_sign_r, 
        xp_i => xG, 
        yp_i => yG, 
        k => k,
        xq_io => xR, 
        yq_io => yR, 
        ready_o => done_sign_r 
    );

    -- Instantiate multiplier entity to compute dA * xR
    sign_mul_darx: e_gf2m_interleaved_multiplier GENERIC MAP (
            MODULO => P(M-1 DOWNTO 0)
    ) PORT MAP( 
        clk_i => clk_i, 
        rst_i => rst_i,
        enable_i => enable_sign_darx, 
        a_i => dA,
        b_i => xR,
        z_o => xrda,
        ready_o => done_sign_darx
    );

    -- compute e + (dA * xR) 
    sign_add_edarx: FOR i IN 0 TO M-1 GENERATE
        e_xrda(i) <= xrda(i) xor hash_i(i);
    END GENERATE;

    -- Instantiate divider entity to compute (e + dA*xR)/k
    sign_divide_edarx_k: e_gf2m_divider GENERIC MAP (
            MODULO => P
    ) PORT MAP( 
        clk_i => clk_i, 
        rst_i => rst_i, 
        enable_i => enable_sign_z2k,
        g_i => e_xrda, 
        h_i => k,  
        z_o => s, 
        ready_o => done_sign_z2k
    );
    
    sign_r_o <= xR;
    sign_s_o <= s;
    
    -- VALIDATE -----------------------------------------------------------------

    -- Instantiate inversion entity to compute w = 1/s
    verify_invs: e_gf2m_eea_inversion GENERIC MAP (
            MODULO => P(M-1 DOWNTO 0)
    ) PORT MAP (
        clk_i => clk_i, 
        rst_i => rst_i, 
        enable_i => enable_verify_invs,
        a_i => s_i,
        z_o => w,
        ready_o => done_verify_invs
    );

    -- Instantiate multiplier entity to compute u1 = ew
    verify_mul_u1: e_gf2m_interleaved_multiplier GENERIC MAP (
            MODULO => P(M-1 DOWNTO 0)
    ) PORT MAP( 
        clk_i => clk_i, 
        rst_i => rst_i, 
        enable_i => enable_verify_u12, 
        a_i => hash_i,
        b_i => w,
        z_o => U1,
        ready_o => done_verify_u1
    );

    -- Instantiate multiplier entity to compute u2 = rw
    verify_mul_u2: e_gf2m_interleaved_multiplier GENERIC MAP (
            MODULO => P(M-1 DOWNTO 0)
    ) PORT MAP( 
        clk_i => clk_i, 
        rst_i => rst_i, 
        enable_i => enable_verify_u12, 
        a_i => r_i,
        b_i => w,
        z_o => U2,
        ready_o => done_verify_u2
    );
    
    -- Instantiate multiplier to compute tmp6 = u1.G
    --verify_pmul_u1gu2q: e_gf2m_point_multiplication GENERIC MAP (
    verify_pmul_u1gu2q: e_gf2m_doubleadd_point_multiplication GENERIC MAP (
            MODULO => P
    ) PORT MAP (
        clk_i => clk_i, 
        rst_i => rst_i, 
        enable_i => enable_verify_u1gu2qb, 
        xp_i => xG, 
        yp_i => yG, 
        k => U1,
        xq_io => xGU1, 
        yq_io => yGU1, 
        ready_o => done_verify_u1g
    );
    
    -- Instantiate multiplier to compute tmp7 = u2.QB
    --verify_pmul_u1gu2qb: e_gf2m_point_multiplication GENERIC MAP (
    verify_pmul_u1gu2qb: e_gf2m_doubleadd_point_multiplication GENERIC MAP (
            MODULO => P
    ) PORT MAP (
        clk_i => clk_i, 
        rst_i => rst_i, 
        enable_i => enable_verify_u1gu2qb, 
        xp_i => xQB, 
        yp_i => yQB, 
        k => U2,
        xq_io => xQBU2, 
        yq_io => yQBU2, 
        ready_o => done_verify_u2qb
    );

    -- Instantiate point addition entity to compute (xP, yP) = t1+t2
    verify_adder_u1gu2qb: e_gf2m_point_addition GENERIC MAP (
            MODULO => P
    ) PORT MAP ( 
        clk_i => clk_i, 
        rst_i => rst_i, 
        enable_i => enable_verify_P,
        x1_i => xGU1, 
        y1_i => yGU1, 
        x2_i => xQBU2, 
        y2_i => yQBU2,
        x3_io => xP, 
        y3_o => yP,
        ready_o => done_verify_P
    );
        
    -- State machine process
    control_unit: PROCESS(clk_i, rst_i, current_state)
    BEGIN
        -- Handle current state
        --  0,1   : Default state
        --  2,3   : SIGN   -> compute R = k.G = (xR, yR)
        --  4,5   : SIGN   -> compute xrda = dA*xR, e_xrda = e+xrda
        --  6-8   : SIGN   -> compute S = e_xrda/k
        --    ---> SIGN DONE
        --  9,10  : VERIFY -> compute 1/S
        --  11,12 : VERIFY -> compute u1 = ew and u2 = rw
        --  13,14 : VERIFY -> compute z1=u1.G and z2=u2.xQB
        --  15-17 : VERFIY -> compute v=z1+z2, valid if v=r
        --  18,19 : VERIFY SUCCESSFULL 
        CASE current_state IS
            WHEN 0 TO 1   => enable_sign_r <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0'; ready_o <= '1'; valid_o <= '0';
            WHEN 2        => enable_sign_r <= '1'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0'; ready_o <= '0'; valid_o <= '0';
            WHEN 3        => enable_sign_r <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0'; ready_o <= '0'; valid_o <= '0';
            WHEN 4        => enable_sign_r <= '0'; enable_sign_darx <= '1'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0'; ready_o <= '0'; valid_o <= '0';
            WHEN 5        => enable_sign_r <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0'; ready_o <= '0'; valid_o <= '0';
            WHEN 6        => enable_sign_r <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '1'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0'; ready_o <= '0'; valid_o <= '0';
            WHEN 7 TO 8   => enable_sign_r <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0'; ready_o <= '0'; valid_o <= '0';
            WHEN 9        => enable_sign_r <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '1'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0'; ready_o <= '0'; valid_o <= '0';
            WHEN 10       => enable_sign_r <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0'; ready_o <= '0'; valid_o <= '0';
            WHEN 11       => enable_sign_r <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '1'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0'; ready_o <= '0'; valid_o <= '0';
            WHEN 12       => enable_sign_r <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0'; ready_o <= '0'; valid_o <= '0';
            WHEN 13       => enable_sign_r <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '1'; enable_verify_P <= '0'; ready_o <= '0'; valid_o <= '0';
            WHEN 14       => enable_sign_r <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0'; ready_o <= '0'; valid_o <= '0';
            WHEN 15       => enable_sign_r <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '1'; ready_o <= '0'; valid_o <= '0';
            WHEN 16 TO 17 => enable_sign_r <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0'; ready_o <= '0'; valid_o <= '0';
            WHEN 18 TO 19 => enable_sign_r <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0'; ready_o <= '1'; valid_o <= '1'; 
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
                -- SIGN
                WHEN 1 => 
                    IF (enable_i = '1' and mode_i = '0') THEN 
                        current_state <= 2; 
                    ELSIF (enable_i = '1' and mode_i = '1') THEN
                        current_state <= 9;
                    END IF;
                WHEN 2 =>
                    current_state <= 3;
                WHEN 3 => 
                    IF (done_sign_r = '1') THEN
                        -- Validate R: restart if R = 0
                        --IF (xR = ZERO) THEN            -- NECESSARY IF K IS RANDOM VALUE!
                        --    current_state <= 2;
                        --ELSE
                            current_state <= 4;
                        --END IF;
					END IF;
                WHEN 4 =>
                    current_state <= 5;
                WHEN 5 => 
                    IF (done_sign_darx = '1') THEN
                        current_state <= 6;
                    END IF;
                WHEN 6 =>
                    current_state <= 7;
                WHEN 7 => 
                    IF (done_sign_z2k = '1') THEN
                        current_state <= 8;
					END IF;
                WHEN 8 => 
                    -- Validate S: restart if S = 0
                    --IF (s = ZERO) THEN
                    --    current_state <= 2;
                    --ELSE
                        current_state <= 0;
                    --END IF;
                -- VALIDATE
                WHEN 9 =>
                    current_state <= 10;
                WHEN 10 =>
                    IF (done_verify_invs = '1') THEN
                        current_state <= 11;
                    END IF;
                WHEN 11 =>
                    current_state <= 12;
                WHEN 12 =>
                    IF (done_verify_u1 = '1' and done_verify_u2 = '1') THEN
                        current_state <= 13;
                    END IF;
                WHEN 13 =>
                    current_state <= 14;   
                WHEN 14 =>
                    IF (done_verify_u1g = '1' and done_verify_u2qb = '1') THEN
                        current_state <= 15;
                    END IF;
                WHEN 15 =>
                    current_state <= 16;    
                WHEN 16 =>
                    IF (done_verify_P = '1') THEN
                        current_state <= 17;
                    END IF;
                WHEN 17 =>
                    IF (xP = r_i) THEN
                        current_state <= 18;
                    ELSE    
                        current_state <= 0;
                    END IF;
                -- Valid
                WHEN 18 =>
                    IF enable_i = '0' THEN 
                        current_state <= 19; 
                    END IF;
                WHEN 19 => 
                    IF (enable_i = '1' and mode_i = '0') THEN 
                        current_state <= 2; 
                    ELSIF (enable_i = '1' and mode_i = '1') THEN
                        current_state <= 9;
                    END IF;
            END CASE;
        END IF;
    END PROCESS;
END;