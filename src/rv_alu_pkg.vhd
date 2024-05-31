package rv_alu_pkg is
	type rv_alu_op_t is (
		ALU_NOP,
		ALU_SLT,
		ALU_SLTU,
		ALU_SLL,
		ALU_SRL,
		ALU_SRA,
		ALU_ADD,
		ALU_SUB,
		ALU_AND,
		ALU_OR,
		ALU_XOR
	);
end package;
