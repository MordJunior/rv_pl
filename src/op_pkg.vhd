library ieee;
use ieee.std_logic_1164.all;

use work.rv_sys_pkg.all;
use work.rv_core_pkg.all;
use work.rv_alu_pkg.all;

package rv_pl_op_pkg is

	type alu_a_src_t is (SEL_PC, SEL_RS1_DATA);
	type alu_b_src_t is (SEL_IMM, SEL_RS2_DATA, SEL_4);
	type brt_src_t is (SEL_PC_PLUS_IMM, SEL_RS1_DATA_PLUS_IMM);


	type exec_op_t is record
		alu_op    : rv_alu_op_t;
		alu_a_src : alu_a_src_t;
		alu_b_src : alu_b_src_t;
		brt_src   : brt_src_t;
		rs1       : reg_address_t;
		rs2       : reg_address_t;
		rs1_data  : data_t;
		rs2_data  : data_t;
		imm       : data_t;
	end record;

	constant EXEC_NOP : exec_op_t := (
		alu_op    => ALU_NOP,
		alu_a_src => SEL_PC,
		alu_b_src => SEL_IMM,
		brt_src   => SEL_PC_PLUS_IMM,
		rs1       => (others => '0'),
		rs2       => (others => '0'),
		rs1_data  => (others => '0'),
		rs2_data  => (others => '0'),
		imm       => (others => '0')
	);

	type branch_op_t is (
		BR_NOP,
		BR_BRANCH,
		BR_BRANCH_IF_Z,
		BR_BRANCH_IF_NOT_Z
	);

	type mem_op_t is record
		branch_op : branch_op_t;
		memu_op   : memu_op_t;
	end record;

	constant MEM_NOP : mem_op_t := (
		branch_op => BR_NOP,
		memu_op   => MEMU_NOP
	);

	type wb_src_t is (SEL_ALU_RESULT, SEL_MEM_RESULT);

	type wb_op_t is record
		rd    : reg_address_t;
		write : std_logic;
		src   : wb_src_t;
	end record;

	constant WB_NOP : wb_op_t := (
		rd    => ZERO_REG,
		write => '0',
		src   => SEL_ALU_RESULT
	);

	type f2d_t is record
		pc    : data_t;
		instr : instr_t;
	end record;

	type d2e_t is record
		pc      : data_t;
		exec_op : exec_op_t;
		mem_op  : mem_op_t;
		wb_op   : wb_op_t;
	end record;

	type e2m_t is record
		pc            : data_t;
		branch_target : data_t;
		alu_result    : data_t;
		alu_zero      : std_logic;
		mem_data      : data_t;
		mem_op        : mem_op_t;
		wb_op         : wb_op_t;
	end record;

	type regwr_t is record
		write : std_logic;
		reg   : reg_address_t;
		data  : data_t;
	end record;

	type m2f_t is record
		branch_target : data_t;
		branch        : std_logic;
	end record;
	
	type m2w_t is record
		pc         : data_t;
		wb_op      : wb_op_t;
		alu_result : data_t;
		mem_result : data_t;
	end record;

	type ctrl_t is record
		stall : std_logic;
		flush : std_logic;
	end record;

end package;
