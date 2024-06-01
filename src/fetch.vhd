library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv_core_pkg.all;
use work.rv_sys_pkg.all;
use work.rv_util_pkg.all;

use work.rv_pl_op_pkg.all;

entity rv_pl_fetch is
	port (
		clk   : in std_logic;
		res_n : in std_logic;

		ctrl : in  ctrl_t; -- from control unit
		m2f  : in  m2f_t;  -- from memory stage
		f2d  : out f2d_t;  -- to decode stage
		
		mem_out : out mem_out_t; -- to rv_sys
		mem_in  : in  mem_in_t;  -- from rv_sys

		mem_busy : out std_logic
	);
end entity;

architecture rtl of rv_pl_fetch is
	signal pc, pc_next, pc_calc : word_t := (others => '0');

	signal flush : std_logic;
begin
	pc_calc <= std_logic_vector (unsigned (pc) + 4);
	pc_next <= m2f.branch_target when m2f.branch else pc_calc;

	mem_out.rd <= res_n and not ctrl.stall;
	mem_out.byteena <= x"F";
	mem_out.address <= to_word_address (pc_next) when not ctrl.stall else to_word_address (pc);

	mem_out.wr <= '0';
	mem_out.wrdata <= (others => '0');

	mem_busy <= mem_in.busy;

	f2d.pc <= pc;
	f2d.instr <= swap_endianness (mem_in.rddata) when not flush else RISCV_NOP;

	process (clk, res_n)
	begin
		if not res_n then
			pc <= std_logic_vector (to_signed (-4, WORD_WIDTH)); -- -4 because we want to read from 0
		elsif rising_edge (clk) then
			flush <= ctrl.flush;

			if ctrl.stall then
				pc <= pc;
			else
				pc <= pc_next;
			end if;
		end if;
	end process;
	
end architecture;
