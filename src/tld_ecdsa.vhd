----------------------------------------------------------------------------------------------------
--  TOP LEVEL ENTITY - ECDSA
--  FPDA implementation of ECDSA algorithm  
--
--  Ports:
--   
--  Autor: Lennart Bublies (inf100434)
--  Date: 02.07.2017
----------------------------------------------------------------------------------------------------

------------------------------------------------------------
-- GF(2^M) ecdsa package
------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.std_logic_arith.all;
USE IEEE.std_logic_unsigned.all;
USE IEEE.numeric_std.ALL;

PACKAGE tld_k163_ecdsa_package IS
  CONSTANT M: natural := 163;
END tld_k163_ecdsa_package;

------------------------------------------------------------
-- GF(2^M) ecdsa top level entity
------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.std_logic_arith.all;
USE IEEE.std_logic_unsigned.all;
USE IEEE.numeric_std.ALL;
USE work.tld_k163_ecdsa_package.all;

ENTITY tld_ecdsa IS
    PORT (
        -- Clock and reset
        clk_i: IN std_logic; 
        rst_i: IN std_logic;
        
        -- Generate (private and) public key
        --gen_keys_i: IN std_logic;
        
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
END tld_ecdsa;

ARCHITECTURE rtl OF tld_ecdsa IS 
    -- Components -----------------------------------------
    
    -- Import entity sha256
    --COMPONENT sha256 IS
    --    PORT (
    --        clk : IN std_logic;
    --        reset : IN std_logic;
    --        enable : IN std_logic;
    --        ready : OUT std_logic;
    --        update : IN std_logic;
    --        word_address : OUT std_logic_vector(3 DOWNTO 0);
    --        word_input : IN std_logic_vector(31 DOWNTO 0);
    --        hash_output : OUT std_logic_vector(255 DOWNTO 0);
    --        debug_port : OUT std_logic_vector(31 DOWNTO 0)
    --    );
    --END COMPONENT;

    -- Import entity e_k163_point_multiplication
    COMPONENT e_k163_point_multiplication IS
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

    -- Import entity e_k163_point_addition
    COMPONENT e_k163_point_addition IS
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
    
    -- Import entity e_gf2m_binary_algorithm_polynomials
    COMPONENT e_gf2m_binary_algorithm_polynomials IS
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
    
    -- HASH Entity
    --SIGNAL sha256_enable, sha256_ready, sha256_update : std_logic := '0';
    --SIGNAL sha256_word_address : std_logic_vector(3 DOWNTO 0) := (OTHERS=>'0');
    --SIGNAL sha256_word_input, sha256_debug_port : std_logic_vector(31 DOWNTO 0) := (OTHERS=>'0');
    --SIGNAL sha256_hash_output : std_logic_vector(255 DOWNTO 0) := (OTHERS=>'0');    
    
    -- Elliptic curve parameter of sect163k1 and generated private and public key
    --  See http://www.secg.org/SEC2-Ver-1.0.pdf for more information
    SIGNAL xG : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');  -- X of generator point G = (x, y)
    SIGNAL yG : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');  -- Y of generator point G = (x, y)
    SIGNAL dA : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');  -- Private key dA = k
    SIGNAL xQA : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0'); -- X component of public key qA = dA.G = (xQA, yQA)
    SIGNAL yQA : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0'); -- Y component of public key qA = dA.G = (xQA, yQA)
    SIGNAL N : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');   -- Order of generator point G
    --SIGNAL done_gen_key: std_logic := '0';
    
    -- Parameter to sign a message, ONLY FOR TESTING!
    SIGNAL k : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');   -- k for point generator, should be cryptograic secure randum number!
    SIGNAL xQB : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0'); -- X component of public key qB = dB.G = (xQB, yQB)
    SIGNAL yQB : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0'); -- Y component of public key qB = dB.G = (xQB, yQB)

    -- MODE SIGN
    SIGNAL xR : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');  -- X component of point R
    SIGNAL yR : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');  -- Y component of point R
    SIGNAL tmp1, tmp2, tmp3 : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0'); -- Temporary results for signature computation
    SIGNAL enable_sign_r, done_sign_r: std_logic := '0';          -- Enable/Disable signature computation
    SIGNAL enable_sign_darx, done_sign_darx: std_logic := '0'; 
    SIGNAL enable_sign_z2k, done_sign_z2k: std_logic := '0';
    
    -- MODE VERIFY
    SIGNAL invs : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');
    SIGNAL tmp4, tmp5 : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0'); -- Temporary results for signature computation
    SIGNAL enable_verify_invs, done_verify_invs : std_logic := '0'; 
    SIGNAL enable_verify_u12, done_verify_u1, done_verify_u2 : std_logic := '0'; 
    SIGNAL enable_verify_u1gu2qb, enable_verify_u1gu2q, done_verify_u1g, done_verify_u2qb : std_logic := '0';
    SIGNAL enable_verify_P, done_verify_P : std_logic := '0';
    SIGNAL xU1G, yU1G : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');
    SIGNAL xU2QB, yU2QB : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');
    SIGNAL xP, yP : std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');
    SIGNAL valid : std_logic := '0';
    
    -- Constantsenable_verify_u12
    CONSTANT ZERO: std_logic_vector(M-1 DOWNTO 0) := (OTHERS=>'0');
    
    -- States for state machine
    subtype states IS natural RANGE 0 TO 15;
    SIGNAL current_state: states;
BEGIN
    -- generator point: 2fe13c0537bbc11acaa7d793de4e6d5e5c94ee, 2897fb05d38ff58321f2e80536d538ccdaa3
    -- private key: 2ac4d729602cbe5de8469692ddb6f49aad1ecf932
    -- public key:0166990bebc978a86a2a711d8ee44988c953ef354
    --            aeeb153e69f9b0c121871ced96b0b8cc4dc39ad81
    -- 

    -- Set parameter of sect163k1
    xG  <= "010" & x"FE13C0537BBC11ACAA07D793DE4E6D5E5C94EEE8";
    yG  <= "010" & x"89070FB05D38FF58321F2E800536D538CCDAA3D9";
    N   <= "100" & x"000000000000000000020108A2E0CC0D99f8A5EE";
    dA  <= "010" & x"AC4D729602CBE5DE8469692DDB6F49AAD1ECF932";
    xQA <= "000" & x"166990BEBC978A86A2A711D8EE44988C953EF354";
    yQA <= x"AEEB153E69F9B0C121871CED96B0B8CC4DC39AD8" & "001";
    xQB <= "000" & x"166990BEBC978A86A2A711D8EE44988C953EF354";
    yQB <= x"AEEB153E69F9B0C121871CED96B0B8CC4DC39AD8" & "001";
    k   <= "011" & x"355BF83C497F922FFAEC53C7315B348FAFB4DA2F";
 
    -- Instantiate sha256 entity to compute hashes
    --hash: sha256 PORT MAP(
    --    clk => clk_i,
    --    reset => rst_i,
    --    enable => sha256_enable, 
    --    ready => sha256_ready,
    --    update => sha256_update,
    --    word_address => sha256_word_address,
    --    word_input => sha256_word_input,
    --    hash_output => sha256_hash_output, -- ONLY 163 BIT ARE USED!
    --    debug_port => sha256_debug_port
    --);
    
    -- PUBLIC KEX -----------------------------------------------------------------
   
    -- Instantiate multiplier to generate private and public key
    --gen_key: e_k163_point_multiplication PORT MAP(
    --    clk_i => clk_i, 
    --    rst_i => rst_i, 
    --    enable_i => gen_keys_i, 
    --    xp_i => xG, 
    --    yp_i => yG, 
    --    k => dA,
    --    xq_io => xQA, 
    --    yq_io => yQA, 
    --    ready_o => done_gen_key 
    --);
    
    -- SIGN -----------------------------------------------------------------
    
    -- Instantiate multiplier to compute R = k.G = (xR, yR)
    sign_pmul_r: e_k163_point_multiplication PORT MAP(
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
    sign_mul_darx: e_gf2m_interleaved_multiplier PORT MAP( 
        clk_i => clk_i, 
        rst_i => rst_i, 
        enable_i => enable_sign_darx, 
        a_i => dA,
        b_i => xR,
        z_o => tmp1,
        ready_o => done_sign_darx
    );

    -- compute e + (dA * xR) 
    sign_add_edarx: FOR i IN 0 TO 162 GENERATE
        tmp2(i) <= tmp1(i) xor hash_i(i); -- TODO???
    END GENERATE;

    -- Instantiate divider entity to compute (e + dA*xR)/k
    divider: e_gf2m_binary_algorithm_polynomials PORT MAP( 
        clk_i => clk_i, 
        rst_i => rst_i, 
        enable_i => enable_sign_z2k,
        g_i => tmp2, 
        h_i => k,  
        z_o => tmp3, 
        ready_o => done_sign_z2k
    );
    
    sign_r_o <= xR;
    sign_s_o <= tmp3;
    
    -- VALIDATE -----------------------------------------------------------------

    -- Instantiate inversion entity to compute w = 1/s
    verify_invs: e_gf2m_eea_inversion PORT MAP (
        clk_i => clk_i, 
        rst_i => rst_i, 
        enable_i => enable_verify_invs,
        a_i => s_i,
        z_o => invs,
        ready_o => done_verify_invs
    );

    -- Instantiate multiplier entity to compute u1 = ew
    verify_mul_u1: e_gf2m_interleaved_multiplier PORT MAP( 
        clk_i => clk_i, 
        rst_i => rst_i, 
        enable_i => enable_verify_u12, 
        a_i => hash_i, --sha256_hash_output(M-1 DOWNTO 0),
        b_i => s_i,
        z_o => tmp4,
        ready_o => done_verify_u1
    );

    -- Instantiate multiplier entity to compute u2 = rw
    verify_mul_u2: e_gf2m_interleaved_multiplier PORT MAP( 
        clk_i => clk_i, 
        rst_i => rst_i, 
        enable_i => enable_verify_u12, 
        a_i => r_i,
        b_i => s_i,
        z_o => tmp5,
        ready_o => done_verify_u2
    );
    
    -- Instantiate multiplier to compute tmp6 = u1.G
    sign_pmul_u1gu2q: e_k163_point_multiplication PORT MAP(
        clk_i => clk_i, 
        rst_i => rst_i, 
        enable_i => enable_verify_u1gu2q, 
        xp_i => xG, 
        yp_i => yG, 
        k => tmp4,
        xq_io => xU1G, 
        yq_io => yU1G, 
        ready_o => done_verify_u1g
    );
    
    -- Instantiate multiplier to compute tmp7 = u2.QB
    sign_pmul_u1gu2qb: e_k163_point_multiplication PORT MAP(
        clk_i => clk_i, 
        rst_i => rst_i, 
        enable_i => enable_verify_u1gu2qb, 
        xp_i => xQB, 
        yp_i => yQB, 
        k => tmp5,
        xq_io => xU2QB, 
        yq_io => yU2QB, 
        ready_o => done_verify_u2qb
    );

    -- Instantiate point addition entity
    adder: e_k163_point_addition PORT MAP ( 
        clk_i => clk_i, 
        rst_i => rst_i, 
        enable_i => enable_verify_P,
        x1_i => xU1G, 
        y1_i => yU1G, 
        x2_i => xU2QB, 
        y2_i => yU2QB,
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
        --  4,5   : SIGN   -> compute tmp1 = dA*xR, tmp2 = e+tmp1
        --  6,7   : SIGN   -> compute S = tmp2/k
        --    ---> SIGN DONE
        --  8,9   : VERIFY -> compute 1/S
        --  10,11 : VERIFY -> compute u1 = ew und u2 = rw
        CASE current_state IS
            WHEN 0 TO 1 => enable_sign_r <= '0'; ready_o <= '1'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0'; 
            WHEN 2  => enable_sign_r <= '1'; ready_o <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0';
            WHEN 3  => enable_sign_r <= '0'; ready_o <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0';
            WHEN 4  => enable_sign_r <= '0'; ready_o <= '0'; enable_sign_darx <= '1'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0';
            WHEN 5  => enable_sign_r <= '0'; ready_o <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0';
            WHEN 6  => enable_sign_r <= '0'; ready_o <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '1'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0';
            WHEN 7  => enable_sign_r <= '0'; ready_o <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0';
            WHEN 8  => enable_sign_r <= '0'; ready_o <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '1'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0';
            WHEN 9  => enable_sign_r <= '0'; ready_o <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0';
            WHEN 10 => enable_sign_r <= '0'; ready_o <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '1'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0';
            WHEN 11 => enable_sign_r <= '0'; ready_o <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0';
            WHEN 12 => enable_sign_r <= '0'; ready_o <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '1'; enable_verify_P <= '0';
            WHEN 13 => enable_sign_r <= '0'; ready_o <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0';
            WHEN 14 => enable_sign_r <= '0'; ready_o <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '1';
            WHEN 15 => enable_sign_r <= '0'; ready_o <= '0'; enable_sign_darx <= '0'; enable_sign_z2k <= '0'; enable_verify_invs <= '0'; enable_verify_u12 <= '0'; enable_verify_u1gu2qb <= '0'; enable_verify_P <= '0';
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
                        current_state <= 8;
                    END IF;
                WHEN 2 =>
                    current_state <= 3;
                WHEN 3 => 
                    IF (done_sign_r = '1') THEN
                        -- Validate R: restart if R = 0
                        IF (tmp3 = ZERO) THEN
                            current_state <= 2;
                        ELSE
                            current_state <= 4;
                        END IF;
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
                        -- Validate S: restart if S = 0
                        IF (tmp3 = ZERO) THEN
                            current_state <= 2;
                        ELSE
                            current_state <= 0;
                        END IF;
					END IF;
                -- VALIDATE
                WHEN 8 =>
                    current_state <= 9;
                WHEN 9 =>
                    IF (done_verify_invs = '1') THEN
                        current_state <= 10;
                    END IF;
                WHEN 10 =>
                    current_state <= 11;
                WHEN 11 =>
                    IF (done_verify_u1 = '1' and done_verify_u2 = '1') THEN
                        current_state <= 12;
                    END IF;
                WHEN 12 =>
                    current_state <= 13;   
                WHEN 13 =>
                    IF (done_verify_u1g = '1' and done_verify_u2qb = '1') THEN
                        current_state <= 14;
                    END IF;
                WHEN 14 =>
                    current_state <= 15;    
                WHEN 15 =>
                    IF (done_verify_P = '1') THEN
                        current_state <= 0;
                        IF (xP = r_i) THEN
                            valid <= '1';
                        ELSE    
                            valid <= '0';
                        END IF;
                    END IF;
            END CASE;
        END IF;
    END PROCESS;
    
    valid_o <= valid;
END;
