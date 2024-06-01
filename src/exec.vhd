library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv_core_pkg.all;
use work.rv_sys_pkg.all;
use work.rv_util_pkg.all;

use work.rv_alu_pkg.all;
use work.rv_pl_op_pkg.all;

entity rv_pl_exec is
	port (
		clk    : in  std_logic;
		res_n  : in  std_logic;

		ctrl : in  ctrl_t;  -- from ctrl unit
		d2e  : in  d2e_t;   -- from decode stage
		e2m  : out e2m_t;   -- to memory stage
		m2e  : in  regwr_t; -- form memory stage (forwarding)
		w2e  : in  regwr_t  -- form writeback stage (forwarding)
	);
end entity;

architecture rtl of rv_pl_exec is
	signal dec : d2e_t;

	signal alu_a, alu_b : word_t;
begin
	e2m.pc <= dec.pc;
	e2m.mem_op <= dec.mem_op;
	e2m.wb_op <= dec.wb_op;

	process (clk, res_n)
	begin
		if not res_n then
			dec <= ((others => '0'), EXEC_NOP, MEM_NOP, WB_NOP);
		elsif rising_edge (clk) then
			if ctrl.flush then
				dec <= ((others => '0'), EXEC_NOP, MEM_NOP, WB_NOP);
			elsif ctrl.stall then
				dec <= dec;
			else
				dec <= d2e;
			end if;
		end if;
	end process;

	process (all)		
		variable rs1, rs2 : reg_address_t;
	begin
		rs1 := dec.exec_op.rs1;
		rs2 := dec.exec_op.rs2;

		case dec.exec_op.brt_src is
			when SEL_PC_PLUS_IMM =>
				e2m.branch_target <= std_logic_vector (unsigned (dec.pc) + unsigned (dec.exec_op.imm));

			when others =>
				e2m.branch_target <= std_logic_vector (unsigned (dec.exec_op.rs1_data) + unsigned (dec.exec_op.imm));

				if not is_zero (rs1) then
					if rs1 = w2e.reg and w2e.write = '1' then
						e2m.branch_target <= std_logic_vector (unsigned (w2e.data) + unsigned (dec.exec_op.imm));
					end if;

					if rs1 = m2e.reg and m2e.write = '1' then
						e2m.branch_target <= std_logic_vector (unsigned (m2e.data) + unsigned (dec.exec_op.imm));
					end if;
				end if;
		end case;

		e2m.mem_data <= dec.exec_op.rs2_data;

		if not is_zero (rs2) then
			if rs2 = w2e.reg and w2e.write = '1' then
				e2m.mem_data <= w2e.data;
			end if;

			if rs2 = m2e.reg and m2e.write = '1' then
				e2m.mem_data <= m2e.data;
			end if;
		end if;
	end process;

	process (all)		
		variable rs1, rs2 : reg_address_t;
	begin
		rs1 := dec.exec_op.rs1;
		rs2 := dec.exec_op.rs2;

		case dec.exec_op.alu_a_src is
			when SEL_PC =>
				alu_a <= dec.pc;

			when others =>
				alu_a <= dec.exec_op.rs1_data;

				if not is_zero (rs1) then
					if rs1 = w2e.reg and w2e.write = '1' then
						alu_a <= w2e.data;
					end if;

					if rs1 = m2e.reg and m2e.write = '1' then
						alu_a <= m2e.data;
					end if;
				end if;
		end case;

		case dec.exec_op.alu_b_src is
			when SEL_IMM =>
				alu_b <= dec.exec_op.imm;

			when SEL_4 =>
				alu_b <= 32x"4";

			when others =>
				alu_b <= dec.exec_op.rs2_data;

				if not is_zero (rs2) then
					if rs2 = w2e.reg and w2e.write = '1' then
						alu_b <= w2e.data;
					end if;
					
					if rs2 = m2e.reg and m2e.write = '1' then
						alu_b <= m2e.data;
					end if;
				end if;
		end case;
	end process;

	alu : entity work.rv_alu
	port map (
		dec.exec_op.alu_op,
		alu_a,
		alu_b,
		e2m.alu_result,
		e2m.alu_zero
	);

end architecture;
