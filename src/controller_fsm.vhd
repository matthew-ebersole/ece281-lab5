----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/18/2025 02:42:49 PM
-- Design Name: 
-- Module Name: controller_fsm - FSM
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity controller_fsm is
    Port ( i_reset : in STD_LOGIC;
           i_adv : in STD_LOGIC;
           o_cycle : out STD_LOGIC_VECTOR (3 downto 0));
end controller_fsm;

architecture FSM of controller_fsm is
    
    signal f_q : std_logic_vector(3 downto 0) := "0000";
    signal f_qnext : std_logic_vector(3 downto 0) := "0000";

begin

    f_qnext(0) <= f_q(3);
    f_qnext(1) <= f_q(0);
    f_qnext(2) <= f_q(1);
    f_qnext(3) <= f_q(2);
    
    o_cycle <= f_q;
    
    
    -- process for controller
    register_proc : process (i_adv, i_reset)
    begin
    if i_reset = '1' then
        f_q <= "0001";
    elsif i_adv = '1' then
        f_q <= f_qnext;
    end if;
    end process register_proc;

end FSM;














