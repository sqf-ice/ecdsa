----------------------------------------------------------------------------------------------------
--  ENTITY - Multiplexer for UART
--
--  Autor: Lennart Bublies (inf100434), Leander Schulz (inf102143)
--  Date: 29.06.2017
--  Last change:  22.10.2017
----------------------------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE work.tld_ecdsa_package.all;

ENTITY e_uart_transmit_mux IS
    PORT ( 
        -- Clock and reset
        clk_i : IN std_logic;
        rst_i : IN std_logic;
        
        -- ECDSA Mode (sign/verify)
        mode_i : IN std_logic;
        
        -- Enable flag
        enable_i : IN std_logic;
        
        -- Input
        r_i : IN std_logic_vector(M-1 DOWNTO 0);
        s_i : IN std_logic_vector(M-1 DOWNTO 0);
        v_i : IN std_logic;
        
        -- UART
        uart_o : OUT std_logic
    );
END e_uart_transmit_mux;

ARCHITECTURE rtl OF e_uart_transmit_mux IS
    -- Import entity e_posi_register 
    COMPONENT e_nm_piso_register  IS
        PORT(
            clk_i : IN std_logic;
            rst_i : IN std_logic;
            enable_i : IN std_logic;
            load_i : IN std_logic;
            data_i : IN std_logic_vector(M-1 DOWNTO 0);
            data_o : OUT std_logic_vector(U-1 DOWNTO 0)
        );
    END COMPONENT;

    -- IMPORT UART COMPONENT
    COMPONENT e_uart_transmit IS
        GENERIC(
            baud_rate : IN NATURAL RANGE 1200 TO 500000;
            M : integer 
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
            reg_ena_o : OUT std_logic );
    END COMPONENT e_uart_transmit;
    
    -- Internal signals
    SIGNAL s_uart_data_r: std_logic_vector(7 DOWNTO 0) := (OTHERS=>'0');
    SIGNAL s_uart_data_s: std_logic_vector(7 DOWNTO 0) := (OTHERS=>'0');
    SIGNAL s_enable_r, s_enable_s : std_logic := '0';
    
    SIGNAL s_reg_ctrl       : std_logic;
    SIGNAL s_reg_ena        : std_logic;
    SIGNAL s_uart_data      : std_logic_vector(7 DOWNTO 0) := (OTHERS=>'0');
    
    SIGNAL s_enable_i_curr  : std_logic;
    SIGNAL s_enable_i_next  : std_logic;
    SIGNAL s_enable_i       : std_logic;
    
BEGIN
    -- Instantiate sipo register entity for r register
    r_register: e_nm_piso_register PORT MAP(
        clk_i => clk_i, 
        rst_i => rst_i,
        enable_i => s_enable_r, 
        load_i => s_enable_i,         
        data_i => r_i, 
        data_o => s_uart_data_r
    );
        
    -- Instantiate sipo register entity for r register
    s_register: e_nm_piso_register PORT MAP(
        clk_i => clk_i, 
        rst_i => rst_i,
        enable_i => s_enable_s, 
        load_i => s_enable_i,         
        data_i => s_i, 
        data_o => s_uart_data_s
    );
    
    -- Instantiate uart transmitter
    transmit_instance : e_uart_transmit
        GENERIC MAP (
            baud_rate   => BAUD_RATE,
            M           => M
        ) PORT MAP ( 
            clk_i     => clk_i,
            rst_i     => rst_i,
            mode_i    => mode_i,
            verify_i  => v_i,
            start_i   => s_enable_i,
            data_i    => s_uart_data,
            tx_o      => uart_o,
            reg_o     => s_reg_ctrl,
            reg_ena_o => s_reg_ena
        );
        
    -- multiplexer to control register inputs
    s_uart_data <= s_uart_data_r WHEN (s_reg_ctrl = '0') ELSE s_uart_data_s;
    --s_reg_ena <= enable_r_register WHEN (s_reg_ctrl = '0') ELSE enable_s_register;
    
    -- demux for register enable port
    PROCESS(s_reg_ena,s_reg_ctrl)
    BEGIN
        CASE s_reg_ctrl is
          WHEN '0'    => s_enable_r <= s_reg_ena; 
                         s_enable_s <= '0';
          WHEN OTHERS => s_enable_r <= '0'; 
                         s_enable_s <= s_reg_ena;
        END CASE; 
    END PROCESS;
    
    
    -- detect rising edge of enable_i
    s_enable_i <= s_enable_i_next AND NOT s_enable_i_curr;
    
    p_rising_enable : PROCESS(clk_i,rst_i,enable_i,s_enable_i_next)
    BEGIN
        IF rst_i = '1' THEN
            s_enable_i_next <= '1';
            s_enable_i_curr <= '1';
        ELSIF rising_edge(clk_i) THEN
            s_enable_i_next <= enable_i;
            s_enable_i_curr <= s_enable_i_next;
        END IF;
    END PROCESS p_rising_enable;
    
    
END rtl;
