library ieee;
use ieee.std_logic_1164.all;
use work.math_pkg.all;
use work.rv_sys_pkg.all;


architecture top_arch_rv_pl of top is
	signal res_n, cpu_reset_n : std_logic;
	signal rv_clk : std_logic;

	signal imem_in, dmem_in : mem_in_t;
	signal imem_out, dmem_out : mem_out_t;

	constant GPIO_ADDR_WIDTH : natural := 3;
	signal gp_out : mem_data_array_t(2**GPIO_ADDR_WIDTH-1 downto 0);
	signal gp_in  : mem_data_array_t(2**GPIO_ADDR_WIDTH-1 downto 0);
begin

	res_n <= keys(0);

	pll_inst : entity work.rv_pl_pll
	port map(
		inclk0 => clk,
		c0     => rv_clk
	);

	core_inst : entity work.rv_pl
	port map(
		clk      => rv_clk,
		res_n    => cpu_reset_n,
		imem_out => imem_out,
		imem_in  => imem_in,
		dmem_out => dmem_out,
		dmem_in  => dmem_in
	);

	rv_sys_inst : entity work.rv_sys
	generic map (
		BAUD_RATE => 9600,
		CLK_FREQ => 75_000_000,
		GPIO_ADDR_WIDTH => GPIO_ADDR_WIDTH
	)
	port map (
		clk         => rv_clk,
		res_n       => res_n,
		cpu_reset_n => cpu_reset_n,
		tx          => tx,
		rx          => rx,
		gp_out      => gp_out,
		gp_in       => gp_in,
		imem_out    => imem_out,
		imem_in     => imem_in,
		dmem_out    => dmem_out,
		dmem_in     => dmem_in
	);

	process (all)
	begin
		for i in 0 to 2**GPIO_ADDR_WIDTH-1 loop
			gp_in(i) <= (others=>'0');
		end loop;
		gp_in(0)(keys'range) <= keys;
		gp_in(1)(switches'range) <= switches;
		
		ledg <= gp_out(0)(ledg'range);
		ledr <= gp_out(1)(ledr'range);
		hex0 <= gp_out(2)(6 downto 0);
		hex1 <= gp_out(2)(14 downto 8);
		hex2 <= gp_out(2)(22 downto 16);
		hex3 <= gp_out(2)(30 downto 24);
		hex4 <= gp_out(3)(6 downto 0);
		hex5 <= gp_out(3)(14 downto 8);
		hex6 <= gp_out(3)(22 downto 16);
		hex7 <= gp_out(3)(30 downto 24);
		
		-- loop back to unused outputs
		gp_in(4) <= gp_out(4);
		gp_in(5) <= gp_out(5);
		gp_in(6) <= gp_out(6);
		gp_in(7) <= gp_out(7);
	end process;
	
end architecture;
