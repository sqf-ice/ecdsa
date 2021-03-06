-------------------------------------------------------------------------------
-- Module:       e_uart_transmit 
-- Purpose:      Transmits Key when a message will be signed or
--               1 Byte True/False when a message will be verified
--               
-- GENERIC:
--  baud_rate - baud rate of uart transmission
--  M         - Key length in Bit
-- PORT:
--  clk_i     - global clock signal
--  rst_i     - global low active async reset
--  mode_i    - ecdsa mode (sign/verify)
--  start_i   - starts the transmission of ascii char
--  data_i    - data byte to send
--  tx_o      - sequential transmission signal
--  reg_o     - switch between registers
--  reg_ena_o - register enable
--
-- Author:       Leander Schulz (inf102143@fh-wedel.de)
-- Date:         01.09.2017
-- Last change:  22.10.2017
-------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;

ENTITY e_uart_transmit IS
    GENERIC(
        baud_rate : IN NATURAL RANGE 1200 TO 500000;
        M         : integer 
    );
    PORT( 
        clk_i     : IN std_logic;
        rst_i     : IN std_logic;
        mode_i    : IN std_logic;
        verify_i  : IN std_logic;
        start_i   : IN std_logic;
        data_i    : IN std_logic_vector (7 DOWNTO 0);
        tx_o      : OUT std_logic; 
        reg_o     : OUT std_logic;
        reg_ena_o : OUT std_logic);
END ENTITY e_uart_transmit;

ARCHITECTURE td_arch OF e_uart_transmit IS
    -- import e_baud_clock
    -- clock signal from baud rate used to transmit data
    COMPONENT e_baud_clock IS
        GENERIC(baud_rate : IN NATURAL RANGE 1200 TO 500000);
        PORT(   clk_i       : IN std_logic;     
                rst_i       : IN std_logic;     
                baud_clk_o  : OUT std_logic);   
    END COMPONENT e_baud_clock;
    
    TYPE state_type IS (idle, start, transmit, stop); -- wait_edge
    SIGNAL s_curr, s_next : state_type := idle;
    
    SIGNAL s_iter : natural range 0 TO 9 := 0;
    
    SIGNAL s_baud_clk : std_logic;
    SIGNAL s_baud_rst : std_logic := '1';
    
    SIGNAL s_data_i   : std_logic_vector (7 DOWNTO 0);
    
    -- reg_o, reg_ena_o
    -- p_calc_bytes
    CONSTANT  param_bytes_a : NATURAL RANGE 1 TO 128 := M / 8;
    CONSTANT  param_bytes_b : NATURAL RANGE 0 TO 7 := M MOD 8; -- for check if M is byte aligned
    SIGNAL    param_bytes   : NATURAL RANGE 1 TO 128;
    
    TYPE phase_state_type IS (idle, phase1, phase2, stop);
	SIGNAL s_phase, s_phase_next : phase_state_type;
    
    SIGNAL s_cnt_phas1 : NATURAL RANGE 0 TO 128;
    SIGNAL s_phas1_tmp : NATURAL RANGE 0 TO 128;
    SIGNAL s_cnt_phas2 : NATURAL RANGE 0 TO 128;
    SIGNAL s_phas2_tmp : NATURAL RANGE 0 TO 128;
    
    -- verify signals
    SIGNAL s_verify : std_logic := '0';
    
BEGIN 

    -- save data to send
    p_store_data_i : PROCESS(clk_i,rst_i,s_next,data_i)
    BEGIN
        IF rst_i = '1' THEN 
            s_data_i <= "00000000";
        ELSIF rising_edge(clk_i) THEN
            IF s_curr = start THEN
                s_verify <= verify_i;
                IF mode_i = '0' THEN
                    s_data_i <= data_i;
                ELSE 
                    s_data_i <= "00000000";
                END IF;
            END IF;
        END IF;
    END PROCESS p_store_data_i;
    
    -- tx output
    p_transmit_byte : PROCESS(clk_i,rst_i,s_curr,s_baud_clk,s_iter,s_verify)
    BEGIN
        IF rst_i = '1' THEN 
            tx_o <= '1';
            s_iter <= 0;
            reg_ena_o <= '0';
        ELSIF rising_edge(clk_i) THEN
        
            IF s_curr = idle THEN
                tx_o <= '1';
                reg_ena_o <= '0';
            ELSIF s_curr = start THEN
                tx_o <= '0';
                reg_ena_o <= '1';
            ELSIF s_curr = transmit THEN
                reg_ena_o <= '0';
                IF s_baud_clk = '1' THEN
                    IF s_iter < 8 THEN
                        -- -- -- TX OUTPUT HERE -- -- -->
                        IF mode_i = '0' THEN
                            tx_o <= s_data_i(s_iter);
                        ELSE
                            tx_o <= s_verify;
                        END IF;
                        -- <-- -- TX OUTPUT HERE -- -- --
                    END IF;
                    s_iter <= s_iter + 1;
                END IF;
            ELSIF s_curr = stop THEN
                reg_ena_o <= '0';
                tx_o <= '1';
                s_iter <= 0;
            END IF;
        
        END IF;
    END PROCESS p_transmit_byte;

    p_fsm_transition : PROCESS(rst_i,s_curr,start_i,s_baud_clk,s_iter,s_phase,s_cnt_phas2)
    BEGIN
        s_next <= s_curr;
        s_baud_rst <= '0';
        CASE s_curr IS
            WHEN idle => 
                IF rst_i = '0' AND (start_i = '1' OR s_phase = phase1 OR (s_phase = phase2 AND s_cnt_phas2 /= 0)) THEN
                    s_baud_rst <= '1';
                    s_next <= start;
                END IF;
            WHEN start =>
                    s_baud_rst <= '0';
                    s_next <= transmit;
            WHEN transmit =>
                IF s_iter = 9 THEN 
                    s_next <= stop;
                END IF;
            WHEN stop => 
                IF s_baud_clk = '1' THEN
                    s_next <= idle;
                END IF;
        END CASE;
    END PROCESS p_fsm_transition;
    
    p_fsm_store : PROCESS(clk_i,rst_i,s_next)
    BEGIN
        IF rst_i = '1' THEN
            s_curr <= idle;
        ELSIF rising_edge(clk_i) THEN
            s_curr <= s_next;
        END IF;
    END PROCESS p_fsm_store;
            
    baud_clock_inst : e_baud_clock 
        GENERIC MAP(baud_rate => baud_rate)
        PORT MAP( clk_i       => clk_i, 
                  rst_i       => s_baud_rst, 
                  baud_clk_o  => s_baud_clk
        );  
        
    -- calculate bytes to read
    p_calc_bytes : PROCESS(param_bytes)
    BEGIN
        IF (param_bytes_b = 0) THEN
            param_bytes <= param_bytes_a;
        ELSE
            param_bytes <= param_bytes_a+1;
        END IF;
    END PROCESS p_calc_bytes; 
    
    -- register control -----------------------------------------
    -- fsm
    p_reg_fsm : PROCESS(rst_i,s_phase,start_i,mode_i,s_curr,s_next,param_bytes,s_cnt_phas1,s_cnt_phas2,s_phas1_tmp,s_phas2_tmp)
    BEGIN
        s_phase_next <= s_phase;
        s_cnt_phas1  <= s_phas1_tmp;
        s_cnt_phas2  <= s_phas2_tmp;
        CASE s_phase IS
            WHEN idle =>
                s_cnt_phas1 <= param_bytes;
                s_cnt_phas2 <= param_bytes;
                IF rst_i = '0' AND start_i = '1'  AND mode_i = '0' THEN
                    s_phase_next <= phase1;
                END IF;
            WHEN phase1 =>
                IF s_cnt_phas1 = 0 THEN
                    s_phase_next <= phase2;
                END IF;
                IF s_curr = stop AND s_next = idle THEN
                    s_cnt_phas1 <= s_phas1_tmp - 1;
                END IF;
            WHEN phase2 => 
                IF s_cnt_phas2 = 0 THEN
                    s_phase_next <= stop;
                END IF;
                IF s_curr = stop AND s_next = idle THEN
                    s_cnt_phas2 <= s_phas2_tmp - 1;
                END IF;
            WHEN stop => 
                s_phase_next <= idle;
        END CASE;    
    
    END PROCESS p_reg_fsm;

    p_reg_store : PROCESS(rst_i,clk_i,s_phas1_tmp) --ALL)
    BEGIN
        IF rst_i = '1' THEN
            s_phase <= idle;
        ELSIF rising_edge(clk_i) THEN
            s_phase <= s_phase_next;
            s_phas1_tmp <= s_cnt_phas1;
            s_phas2_tmp <= s_cnt_phas2;
        END IF;
    END PROCESS p_reg_store;
    
    p_reg_output : PROCESS(clk_i,rst_i,s_phase)
    BEGIN
        IF rst_i = '1' THEN
            reg_o   <= '0';
        ELSIF rising_edge(clk_i) THEN
            IF s_phase = idle THEN
                reg_o   <= '0';
            ELSIF s_phase = phase1 THEN
                reg_o   <= '0';
            ELSIF s_phase = phase2 THEN
                reg_o   <= '1';
            ELSIF s_phase = stop THEN
                reg_o   <= '0';
            END IF;               
        END IF;  
    END PROCESS p_reg_output;
    
    
END ARCHITECTURE td_arch; -----------------------------------------------------
