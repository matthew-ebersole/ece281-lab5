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
        an      :   out std_logic_vector(3 downto 0);
        seg     :   out std_logic_vector(6 downto 0);
		clk     :   in std_logic; -- native 100MHz FPGA clock
		sw  	:   in std_logic_vector(7 downto 0); -- sw(15) = left; sw(0) = right
		led 	:   out std_logic_vector(15 downto 0);  -- led(3:0) = states, led(15:13) = flags
		btnC	:	in	std_logic;
		btnU	:	in	std_logic
	);
end top_basys3;

architecture top_basys3_arch of top_basys3 is 
  
	-- declare components and signals
    component ALU is
    Port( i_regA : in std_logic_vector(7 downto 0);
          i_regB : in std_logic_vector(7 downto 0);
          i_op : in std_logic_vector(2 downto 0);
          o_result : out std_logic_vector(7 downto 0);
          o_flags : out std_logic_vector(2 downto 0));
   end component;
   
   component TDM4 is 
   generic ( constant k_WIDTH : natural  := 4);
   Port ( i_clk		: in  STD_LOGIC;
          i_reset        : in  STD_LOGIC; -- asynchronous
          i_D3         : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
          i_D2         : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
          i_D1         : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
          i_D0         : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
          o_data        : out STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
          o_sel        : out STD_LOGIC_VECTOR (3 downto 0));
   end component;    
   
   component twoscomp_decimal is
   Port (i_binary: in std_logic_vector(7 downto 0);
             o_negative: out std_logic_vector(3 downto 0);
             o_hundreds: out std_logic_vector(3 downto 0);
             o_tens: out std_logic_vector(3 downto 0);
             o_ones: out std_logic_vector(3 downto 0));
   end component;
  
   component clock_divider is
   generic ( constant k_DIV : natural := 2    ); -- How many clk cycles until slow clock toggles
   Port (i_clk    : in std_logic;
             i_reset  : in std_logic;           -- asynchronous
             o_clk    : out std_logic);
   end component;
   
   component sevenSegDecoder is 
   Port(i_D : in std_logic_vector(3 downto 0);
        o_S : out std_logic_vector(6 downto 0));
   end component;

--   component reg is
--   Port ( LD, CLK : in std_logic;
--         D_IN : in std_logic_vector(7 downto 0);
--         D_OUT : out std_logic_vector(7 downto 0));
--   end component; 
   
   component controller_fsm is
     Port (i_reset : in std_logic;
           i_adv   : in std_logic;
           i_clk   : in std_logic;
           o_cycle : out std_logic_vector(3 downto 0)
      );
   end component;

  component reg is
    Port ( LD, CLK : in std_logic;
         D_IN : in std_logic_vector(7 downto 0);
         D_OUT : out std_logic_vector(7 downto 0));
    end component;


   signal w_clk : std_logic;
   signal w_clk2 : std_logic;
   signal w_regA : std_logic_vector(7 downto 0);
   signal w_regB : std_logic_vector(7 downto 0);
   signal w_op   : std_logic_vector(2 downto 0);
   signal w_cycle : std_logic_vector(3 downto 0);
   signal w_flags : std_logic_vector(2 downto 0);
   signal w_result : std_logic_vector(7 downto 0);
   signal w_sign : std_logic_vector(3 downto 0);
   signal w_hund : std_logic_vector(3 downto 0);
   signal w_tens : std_logic_vector(3 downto 0);
   signal w_ones : std_logic_vector(3 downto 0);
   signal w_TDM4 : std_logic_vector(3 downto 0);
   signal w_reset: std_logic;
   signal w_seg : std_logic;
   signal w_mux : std_logic_vector(7 downto 0);
   signal w_an : std_logic_vector(3 downto 0);
  
   
begin
    
	-- PORT MAPS ----------------------------------------
      clkdiv_inst : clock_divider 		--instantiation of clock_divider for TDM4 
            generic map ( k_DIV => 1000 )
            port map (                          
                i_clk   => clk,
                i_reset => '0',
                o_clk   => w_clk
            );    
      
      clkdiv_inst2 : clock_divider 		--instantiation of clock_divider for controller_fsm
                        generic map ( k_DIV => 9375000 )
                        port map (                          
                            i_clk   => clk,
                            i_reset => '0',
                            o_clk   => w_clk2
                        );    
      
      regA_inst : reg 
            Port map(
            D_IN => sw(7 downto 0),
            D_OUT => w_regA,
            LD => w_cycle(3),
            CLK => w_clk
            );
      
      regB_inst : reg
            Port map(
            D_IN => sw(7 downto 0),
            D_OUT => w_regB,
            LD => w_cycle(0),
            CLK => w_clk
            );
      
      controller_inst : controller_fsm
            Port map(i_reset => btnU,
                     i_adv => btnC,
                     o_cycle => w_cycle,
                     i_clk => w_clk2
            );
      alu_inst : ALU 
            Port map(
                     i_regA => w_regA,
                     i_regB => w_regB,
                     i_op => sw(2 downto 0),
                     o_flags => w_flags,
                     o_result => w_result
            );
      
    twoscomp_decimal_inst : twoscomp_decimal
               Port map( i_binary => w_mux,
                         o_negative => w_sign,
                         o_hundreds => w_hund,
                         o_tens => w_tens,
                         o_ones => w_ones
                        );          
      
	TDM4_inst : TDM4
               Port map( i_clk => w_clk,
                         i_reset => w_reset,
                         i_D3 => w_sign,
                         i_D2 => w_hund,
                         i_D1 => w_tens,
                         i_D0 => w_ones,
                         o_data => w_TDM4,
                         o_sel => w_an
                        );    
    
     sevenSegDecoder_inst : sevenSegDecoder 
                Port map(i_D => w_TDM4,
                         o_S => seg
                         );
                         
	w_mux <= w_regA when w_cycle = "0001" else
	         w_regB when w_cycle = "0010" else
--	         "00000"&sw(2 downto 0) when w_cycle = "0010" else
	         w_result when w_cycle = "0100";        
                  
	
--	--if CPU zero
	w_flags(1) <= '1' when w_result = x"00" else
                         '0';                
                     
    --if CPU sign
    w_flags(2) <= w_result(7);             
	
	--led behavior
	--CPU sign
	led(15) <= w_result(7);
	--CPU zero
    led(14) <= '1' when w_result = x"00" else
                             '0';
    --Cout
    led(13) <= w_flags(0);
        
	led(3) <= w_cycle(3); --clear state
	led(2) <= w_cycle(2); -- execute
	led(1) <= w_cycle(1); --load B
	led(0) <= w_cycle(0); --load A
    led(12 downto 4) <= "000000000";
    
    an(3) <= '1' when w_cycle = "1000" else w_an(3);
    an(2) <= '1' when w_cycle = "1000" else w_an(2);
    an(1) <= '1' when w_cycle = "1000" else w_an(1);
    an(0) <= '1' when w_cycle = "1000" else w_an(0);
    
end top_basys3_arch;
