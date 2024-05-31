library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv_core_pkg.all;
use work.rv_sys_pkg.all;
use work.rv_util_pkg.all;

use work.rv_pl_op_pkg.all;

entity rv_pl_mem is
	port (
		clk   : in  std_logic;
		res_n : in  std_logic;

		ctrl : in  ctrl_t;  -- from control unit
		e2m  : in  e2m_t;   -- from execute stage
		m2f  : out m2f_t;   -- to fetch stage
		m2w  : out m2w_t;   -- to writeback stage
		m2e  : out regwr_t; -- to execute stage (forwarding)

		mem_out : out mem_out_t; -- to rv_sys 
		mem_in  : in  mem_in_t;  -- from rv_sys

		mem_busy : out std_logic; -- to control unit

		exc_load  : out std_logic; -- load exception
		exc_store : out std_logic  -- store exception
	);
end entity;

architecture rtl of rv_pl_mem is
	signal memu_op : memu_op_t := MEMU_NOP;
	signal memu_rddata : word_t;

	signal exec : e2m_t;
	signal new_exec : std_logic;
begin
	mem_busy <= mem_in.busy;

	-- memu_op <= MEMU_NOP when ctrl.stall else exec.mem_op.memu_op;
	memu_op <= exec.mem_op.memu_op;

	m2f.branch_target <= exec.branch_target;

	with exec.mem_op.branch_op select
	m2f.branch <= '0' when BR_NOP,
		'1' when BR_BRANCH,
		exec.alu_zero when BR_BRANCH_IF_Z,
		not exec.alu_zero when BR_BRANCH_IF_NOT_Z;

	m2w.pc <= exec.pc;
	m2w.alu_result <= exec.alu_result;
	m2w.wb_op <= exec.wb_op;
	m2w.mem_result <= memu_rddata;

	m2e.reg <= exec.wb_op.rd;
	m2e.write <= exec.wb_op.write;
	m2e.data <= exec.alu_result when exec.wb_op.src = SEL_ALU_RESULT else memu_rddata;

	process (clk, res_n)
	begin
		if not res_n then
			exec <= ((others => '0'), (others => '0'), (others => '0'), '0', (others => '0'), MEM_NOP, WB_NOP);
		elsif rising_edge (clk) then
			if ctrl.flush then
				exec <= ((others => '0'), (others => '0'), (others => '0'), '0', (others => '0'), MEM_NOP, WB_NOP);
			elsif not ctrl.stall then
				exec <= e2m;
				new_exec <= '1';
			else
				exec <= exec;
				new_exec <= '0';
			end if;
		end if;
	end process;

	memu_inst : memu
	port map (
		memu_op,
		exec.alu_result,
		exec.mem_data,
		memu_rddata,

		open,
		exc_load,
		exc_store,

		mem_in,
		mem_out
	);
end architecture;
