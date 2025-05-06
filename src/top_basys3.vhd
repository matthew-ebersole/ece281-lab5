--+----------------------------------------------------------------------------
--|
--| NAMING CONVENSIONS :
--|
--|    xb_<port name>           = off-chip bidirectional port ( _pads file )
--|    xi_<port name>           = off-chip input port         ( _pads file )
--|    xo_<port name>           = off-chip output port        ( _pads file )
--|    b_<port name>            = on-chip bidirectional port
--|    i_<port name>            = on-chip input port
--|    o_<port name>            = on-chip output port
--|    c_<signal name>          = combinatorial signal
--|    f_<signal name>          = synchronous signal
--|    ff_<signal name>         = pipeline stage (ff_, fff_, etc.)
--|    <signal name>_n          = active low signal
--|    w_<signal name>          = top level wiring signal
--|    g_<generic name>         = generic
--|    k_<constant name>        = constant
--|    v_<variable name>        = variable
--|    sm_<state machine type>  = state machine type definition
--|    s_<signal name>          = state name
--|
--+----------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;


entity top_basys3 is
    port(
        -- inputs
        clk     :   in std_logic; -- native 100MHz FPGA clock
        sw      :   in std_logic_vector(7 downto 0); -- operands and opcode
        btnU    :   in std_logic; -- reset
        btnC    :   in std_logic; -- fsm cycle
        btnL    :   in std_logic;
        
        -- outputs
        led :   out std_logic_vector(15 downto 0);
        -- 7-segment display segments (active-low cathodes)
        seg :   out std_logic_vector(6 downto 0);
        -- 7-segment display active-low enables (anodes)
        an  :   out std_logic_vector(3 downto 0)
    );
end top_basys3;

architecture top_basys3_arch of top_basys3 is 
  
	-- declare components and signals
    signal w_clk,w_clk2 : std_logic;
    signal cpu_state : std_logic_vector(3 downto 0);
    signal w_clk_reset, w_fsm_reset : std_logic;
    signal w_input : std_logic_vector(7 downto 0);
    signal w_A : std_logic_vector(7 downto 0);
    signal w_B : std_logic_vector(7 downto 0);
    signal w_op : std_logic_vector(2 downto 0);
    signal w_result : std_logic_vector(7 downto 0);
    signal w_hex : std_logic_vector(3 downto 0);
    signal w_sign : std_logic;
    signal w_sign2 : std_logic_vector(3 downto 0);
    signal w_hund, w_tens, w_ones : std_logic_vector(3 downto 0);
    signal w_seg : std_logic_vector(6 downto 0);
    constant k_clk_period : time := 20 ns;
    
    component clock_divider is
        generic ( k_DIV : natural := 2 );
        port(
            i_clk : in std_logic;
            i_reset : in std_logic;
            o_clk : out std_logic
        );
    end component;
    
    component controller_fsm is
        port (
            i_adv, i_reset  : in    std_logic;
            o_cycle         : out   std_logic_vector(3 downto 0)
        );
    end component;
    
    component ALU is
        port (
            i_A, i_B    : in    std_logic_vector(7 downto 0);
            i_op : in STD_LOGIC_VECTOR (2 downto 0);
            o_result : out STD_LOGIC_VECTOR (7 downto 0);
            o_flags : out STD_LOGIC_VECTOR (3 downto 0)
        );
    end component;
    
    component TDM4 is
        generic (k_WIDTH : natural := 4 );
        port (
            i_clk		: in  STD_LOGIC;
            i_reset		: in  STD_LOGIC; -- asynchronous
            i_D3 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		    i_D2 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		    i_D1 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		    i_D0 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		    o_data		: out STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		    o_sel		: out STD_LOGIC_VECTOR (3 downto 0)	-- selected data line (one-cold)
        );
    end component;
    
    component twos_comp is
        port (
            i_bin: in std_logic_vector(7 downto 0);
            o_sign: out std_logic;
            o_hund: out std_logic_vector(3 downto 0);
            o_tens: out std_logic_vector(3 downto 0);
            o_ones: out std_logic_vector(3 downto 0)
        );
    end component;
    
    component sevenseg_decoder is
        port (
            i_Hex : in STD_LOGIC_VECTOR (3 downto 0);
            o_seg_n : out STD_LOGIC_VECTOR (6 downto 0)
        );
    end component;
    
    component full_adder is
        port ( 
           A     : in std_logic;
           B     : in std_logic;
           Cin   : in std_logic;
           S     : out std_logic;
           Cout  : out std_logic
           );
        end component full_adder;
  
begin
	-- PORT MAPS ----------------------------------------
    w_clk_reset <= btnL;
    w_fsm_reset <= btnU;
    
    
    clk_div_inst: clock_divider
        generic map (k_DIV => 2)
        port map(
            i_clk => clk,
            i_reset => w_clk_reset,
            o_clk => w_clk2
        );
    clk_process: process
    begin
		w_clk <= '0';
		wait for k_clk_period/2;
		
		w_clk <= '1';
		wait for k_clk_period/2;
    end process clk_process;
    
    fsm: controller_fsm
        port map(
            i_reset => w_fsm_reset,
            i_adv => btnC,
            o_cycle => cpu_state
        );
    
    process( cpu_state, w_input)
    begin
        if cpu_state = "0010" then
            w_A(0) <= sw(0);
            w_A(1) <= sw(1);
            w_A(2) <= sw(2);
            w_A(3) <= sw(3);
            w_A(4) <= sw(4);
            w_A(5) <= sw(5);
            w_A(6) <= sw(6);
            w_A(7) <= sw(7);
        elsif cpu_state = "0100" then
            w_B(0) <= sw(0);
            w_B(1) <= sw(1);
            w_B(2) <= sw(2);
            w_B(3) <= sw(3);
            w_B(4) <= sw(4);
            w_B(5) <= sw(5);
            w_B(6) <= sw(6);
            w_B(7) <= sw(7);
        elsif cpu_state = "1000" then
            w_op(0) <= sw(0);
            w_op(1) <= sw(1);
            w_op(2) <= sw(2);
        else
        end if;
    end process;
    
    alu_inst: ALU
        port map(
            i_A => w_A,
            i_B => w_B,
            i_op => w_op,
            o_result => w_result,
            o_flags(0) => led(12),
            o_flags(1) => led(13),
            o_flags(2) => led(14),
            o_flags(3) => led(15)
        );
        
    twoComp: twos_comp
        port map(
            i_bin => w_result,
            o_sign => w_sign,
            o_hund => w_hund,
            o_tens => w_tens,
            o_ones => w_ones
        );
    
    w_sign2 <= "1111" when (w_sign = '1') else
               "1110";
    tdm: TDM4
        port map(
            i_reset => w_clk_reset,
            i_clk => w_clk2,
            i_D3 => w_sign2,
            i_D2 => w_hund,
            i_D1 => w_tens,
            i_D0 => w_ones,
            o_sel => an,
            o_data => w_hex
        );
    
    sevenseg1: sevenseg_decoder
        port map(
            i_Hex => w_hex,
            o_seg_n => seg
        );
	
	
	-- CONCURRENT STATEMENTS ----------------------------
	
	
	
end top_basys3_arch;
