library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv_core_pkg.all;
use work.rv_util_pkg.all;

use work.rv_pl_op_pkg.all;

entity rv_pl_ctrl is
	port (
		clk   : in std_logic;
		res_n : in std_logic;

		fe   : out ctrl_t;
		dec  : out ctrl_t;
		exec : out ctrl_t;
		mem  : out ctrl_t;
		wb   : out ctrl_t;

		f2d : in f2d_t; -- from fetch stage
		d2e : in d2e_t; -- from decode stage
		e2m : in e2m_t; -- from execute stage
		m2f : in m2f_t; -- from memory stage
		m2w : in m2w_t; -- from memory stage

		imem_busy : std_logic; -- from fetch stage
		dmem_busy : std_logic  -- from memory stage
	);
end entity;

architecture simple of rv_pl_ctrl is
	signal state : std_logic_vector(4 downto 0);
	signal stall : std_logic;
begin
	stall <= imem_busy or dmem_busy;

	sync : process(clk, res_n)
	begin
		if res_n = '0' then
			state <= ('1', others => '0');
		elsif rising_edge(clk) then
			if stall = '0' then
				state <= state(0) & state(4 downto 1);
			end if;
		end if;
	end process;

	process(all)
	begin
		fe.flush <= '1';
		fe.stall <= '1';

		if stall = '0' then
			if state(0) = '1' then
				fe.stall <= '0'; 
				fe.flush <= '0';
			end if;

			if m2f.branch = '1' then
				fe.stall <= '0';
			end if; -- */
		end if;
	end process;

	dec.stall  <= stall;
	exec.stall <= stall;
	mem.stall  <= stall;
	wb.stall   <= stall;

	dec.flush  <= '0';
	exec.flush <= '0';
	mem.flush  <= '0';
	wb.flush   <= '0';
end architecture;

architecture rtl of rv_pl_ctrl is
	signal state : std_logic_vector(4 downto 0);
	signal stall : std_logic;

	signal stall_mem, stall_mem_nxt, stall_mem_next : std_logic;
begin
	stall <= imem_busy or dmem_busy;

	sync : process(clk, res_n)
	begin
		if res_n = '0' then
			state <= ('1', others => '0');
			stall_mem <= '0';
		elsif rising_edge(clk) then
			if stall = '0' then
				state <= state(0) & state(4 downto 1);
				stall_mem <= stall_mem_next;
			end if;
		end if;
	end process;

	process(all)
	begin
		fe.flush <= '1';
		fe.stall <= '1';

		stall_mem_next <= '0';

		if stall = '0' then
			if state(0) = '1' then
				fe.stall <= '0'; 
				fe.flush <= '0';
			end if;

			if m2f.branch = '1' then
				fe.stall <= '0';
			end if; -- */
		end if;

		if e2m.mem_op.memu_op.rd = '1' and -- not 
			e2m.alu_result (word_t'high downto word_t'high - 1) = "00" -- */
		then
			stall_mem_next <= '1';
		end if;
	end process;

	dec.stall  <= stall;
	exec.stall <= stall;
	mem.stall  <= stall or stall_mem;
	wb.stall   <= stall or stall_mem;

	dec.flush  <= '0';
	exec.flush <= '0';
	mem.flush  <= '0';
	wb.flush   <= '0';
end rtl;