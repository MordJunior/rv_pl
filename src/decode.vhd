library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv_core_pkg.all;
use work.rv_sys_pkg.all;
use work.rv_util_pkg.all;

use work.rv_alu_pkg.all;
use work.rv_pl_op_pkg.all;

entity rv_pl_decode is
	port (
		clk   : in std_logic;
		res_n : in std_logic;

		ctrl : in  ctrl_t;  -- from ctrl unit
		f2d  : in  f2d_t;   -- from fetch stage
		w2d  : in  regwr_t; -- from writeback stage
		d2e  : out d2e_t;   -- to execute stage

		exc_dec : out std_logic -- decode exception
	);
end entity;

architecture rtl of rv_pl_decode is
	signal fetch : f2d_t := ((others => '0'), RISCV_NOP);

	signal exec : exec_op_t := EXEC_NOP;
	signal mem : mem_op_t := MEM_NOP;
	signal wb : wb_op_t := WB_NOP;
begin

	d2e.pc <= fetch.pc;
	d2e.exec_op <= EXEC_NOP when ctrl.flush else exec;
	d2e.mem_op <= MEM_NOP when ctrl.flush else mem;
	d2e.wb_op <= WB_NOP when ctrl.flush else wb;

	exec.rs1 <= get_rs1 (fetch.instr);
	exec.rs2 <= get_rs2 (fetch.instr);
	exec.imm <= get_immediate (fetch.instr);

	wb.rd <= get_rd (fetch.instr);

	process (clk, res_n)
	begin
		if not res_n then
			fetch <= ((others => '0'), RISCV_NOP);
		elsif rising_edge (clk) then
			if ctrl.flush then
				fetch <= (f2d.pc, RISCV_NOP);
			elsif ctrl.stall then
				fetch <= fetch;
			else
				fetch <= f2d;
			end if;
		end if;
	end process;

	process (all)
		variable opcode : opcode_t;
		variable funct3 : funct3_t;
		variable funct7 : funct7_t;
	begin
		opcode := get_opcode (fetch.instr);
		funct3 := get_funct3 (fetch.instr);
		funct7 := get_funct7 (fetch.instr);

		exec.alu_op <= ALU_ADD;
		exec.alu_a_src <= SEL_PC;
		exec.alu_b_src <= SEL_IMM;
		exec.brt_src <= SEL_PC_PLUS_IMM;

		mem <= MEM_NOP;
		wb.write <= '1';
		wb.src <= SEL_ALU_RESULT;

		exc_dec <= '0';

		case opcode is
			when OPCODE_LUI =>
				exec.alu_op <= ALU_NOP;

			when OPCODE_AUIPC =>
				null;

			when OPCODE_JAL =>
				exec.alu_b_src <= SEL_4;
				
				mem.branch_op <= BR_BRANCH;

			when OPCODE_JALR =>
				exec.alu_b_src <= SEL_4;

				exec.brt_src <= SEL_RS1_DATA_PLUS_IMM;

				mem.branch_op <= BR_BRANCH;

			when OPCODE_BRANCH =>
				exec.alu_a_src <= SEL_RS1_DATA;
				exec.alu_b_src <= SEL_RS2_DATA;

				if not funct3 (funct3'low) then
					mem.branch_op <= BR_BRANCH_IF_Z;
				else 
					mem.branch_op <= BR_BRANCH_IF_NOT_Z;
				end if;

				wb.write <= '0';

				if not funct3 (funct3'high) then
					exec.alu_op <= ALU_SUB;
				elsif not funct3 (funct3'high - 1) then
					exec.alu_op <= ALU_SLT;
				else
					exec.alu_op <= ALU_SLTU;
				end if;

			when OPCODE_LOAD =>
				exec.alu_a_src <= SEL_RS1_DATA;

				mem.memu_op <= ('1', '0', MEM_W);

				wb.src <= SEL_MEM_RESULT;

				if funct3 = "000" then
					mem.memu_op.access_type <= MEM_B;
				elsif funct3 = "001" then
					mem.memu_op.access_type <= MEM_H;
				elsif funct3 = "100" then
					mem.memu_op.access_type <= MEM_BU;
				elsif funct3 = "101" then
					mem.memu_op.access_type <= MEM_HU;
				end if;

			when OPCODE_STORE =>
				exec.alu_a_src <= SEL_RS1_DATA;

				mem.memu_op <= ('0', '1', MEM_W);

				wb.write <= '0';

				if funct3 = "000" then
					mem.memu_op.access_type <= MEM_B;
				elsif funct3 = "001" then
					mem.memu_op.access_type <= MEM_H;
				end if;

			when OPCODE_OP_IMM | OPCODE_OP =>
				exec.alu_a_src <= SEL_RS1_DATA;
				
				if opcode = OPCODE_OP_IMM then
					exec.alu_b_src <= SEL_IMM;
				else 
					exec.alu_b_src <= SEL_RS2_DATA;
				end if;

				if funct3 = "000" and opcode = OPCODE_OP and funct7 (5) = '1' then
					exec.alu_op <= ALU_SUB;
				elsif funct3 = "001" then
					exec.alu_op <= ALU_SLL;
				elsif funct3 = "010" then
					exec.alu_op <= ALU_SLT;
				elsif funct3 = "011" then
					exec.alu_op <= ALU_SLTU;
				elsif funct3 = "100" then
					exec.alu_op <= ALU_XOR;
				elsif funct3 = "101" then
					if funct7 (5) then
						exec.alu_op <= ALU_SRA;
					else
						exec.alu_op <= ALU_SRL;
					end if;
				elsif funct3 = "110" then
					exec.alu_op <= ALU_OR;
				elsif funct3 = "111" then
					exec.alu_op <= ALU_AND;
				end if;

			when others =>
				exc_dec <= '1';
		end case;
	end process;

	registers : entity work.rv_pl_regfile
	port map (
		clk, res_n,
		ctrl.stall,

		get_rs1 (f2d.instr),
		exec.rs1_data,

		get_rs2 (f2d.instr),
		exec.rs2_data,

		w2d.reg,
		w2d.data,
		w2d.write
	);
end architecture;
