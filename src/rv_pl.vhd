library ieee;
use ieee.std_logic_1164.all;

use work.rv_core_pkg.all;
use work.rv_sys_pkg.all;
use work.rv_pl_op_pkg.all;

entity rv_pl is
	port (
		clk    : in  std_logic;
		res_n  : in  std_logic;

		-- instruction interface
		imem_out    : out mem_out_t;
		imem_in     : in  mem_in_t;

		-- data interface
		dmem_out    : out mem_out_t;
		dmem_in     : in  mem_in_t
	);
end entity;

architecture arch of rv_pl is
	signal imem_busy, dmem_busy : std_logic;
	signal exc_dec, exc_load, exc_store : std_logic;

	signal f2d : f2d_t;
	signal d2e : d2e_t;
	signal e2m : e2m_t;
	signal m2f : m2f_t;
	signal m2w : m2w_t;
	signal w2de : regwr_t; -- normal writeback and forwarding
	signal m2e  : regwr_t; -- forwarding

	signal c2f, c2d, c2e, c2m, c2w : ctrl_t; -- control unit
begin
	ctrl_unit : entity work.rv_pl_ctrl (rtl)
	port map (
		clk, res_n,

		c2f,
		c2d,
		c2e,
		c2m,
		c2w,

		f2d,
		d2e,
		e2m,
		m2f,
		m2w,

		imem_busy,
		dmem_busy
	);

	fetch_stage : entity work.rv_pl_fetch
	port map (
		clk, res_n,

		c2f,
		m2f,
		f2d,
		
		imem_out,
		imem_in,

		imem_busy
	);

	decode_stage : entity work.rv_pl_decode
	port map (
		clk, res_n,
		
		c2d,
		f2d,
		w2de,
		d2e,

		exc_dec
	);

	exec_stage : entity work.rv_pl_exec
	port map (
		clk, res_n,

		c2e,
		d2e,
		e2m,
		m2e,
		w2de
	);

	memory_stage : entity work.rv_pl_mem
	port map (
		clk, res_n,

		c2m,
		e2m,
		m2f,
		m2w,
		m2e,

		dmem_out,
		dmem_in,

		dmem_busy,

		exc_load,
		exc_store
	);

	writeback_stage : entity work.rv_pl_wb
	port map (
		clk, res_n,

		c2w,
		m2w,
		w2de
	);

end architecture;
