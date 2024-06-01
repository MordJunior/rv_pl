library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv_core_pkg.all;
use work.rv_sys_pkg.all;
use work.rv_pl_op_pkg.all;

entity rv_pl_wb is
	port (
		clk   : in std_logic;
		res_n : in std_logic;

		ctrl : in  ctrl_t; -- from control unit
		m2w  : in  m2w_t;  -- from memory stage
		w2de : out regwr_t -- to decode stage and execute stage (fowarding)
	);
end entity;

architecture rtl of rv_pl_wb is
	signal mem : m2w_t;
begin
	w2de.write <= mem.wb_op.write;
	w2de.reg <= mem.wb_op.rd;
	w2de.data <= mem.alu_result when mem.wb_op.src = SEL_ALU_RESULT else mem.mem_result;

	process (clk, res_n)
	begin
		if not res_n then
			mem <= ((others => '0'), WB_NOP, (others => '0'), (others => '0'));
		elsif rising_edge (clk) then
			if ctrl.flush then
				mem <= ((others => '0'), WB_NOP, (others => '0'), (others => '0'));
			elsif ctrl.stall then
				mem <= mem;
			else
				mem <= m2w;
			end if;
		end if;
	end process;
end architecture;
