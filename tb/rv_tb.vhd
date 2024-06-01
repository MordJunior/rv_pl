library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;
use std.textio.all;

use work.rv_sys_pkg.all;
use work.rv_util_pkg.all;

use work.tb_util_pkg.all;

entity rv_tb is
	generic (
		-- ELF_FILE : string := "../../../lib/rv_sys/software/asm/send_uart/send_uart.elf";
		ELF_FILE : string := "../../../lib/rv_sys/software/c/md5/md5.elf";
		SIM_TIMEOUT : time := 2 ms
	);
end rv_tb;

architecture arch of rv_tb is

	constant CLK_PERIOD : time := 20 ns;
	constant CLOCK_FREQUENCY : natural := 1 sec / CLK_PERIOD;
	
	constant BAUD_RATE : natural := 1_000_000;

	signal cpu_res_n : std_logic;
	signal clk, res_n : std_logic := '0';

	signal imem_in, dmem_in : mem_in_t;
	signal imem_out, dmem_out : mem_out_t;
	signal rx, tx : std_logic;

	constant GPIO_ADDR_WIDTH : natural := 3;
	signal gp_out : mem_data_array_t(2 ** GPIO_ADDR_WIDTH - 1 downto 0);
	signal gp_in  : mem_data_array_t(2 ** GPIO_ADDR_WIDTH - 1 downto 0);
	
	procedure print_line(s : string) is
	begin
		report s;
	end procedure;
begin

	--TODO: add RISC-V core instance
	rv_core : entity work.rv_pl
	port map (
		clk, cpu_res_n,

		-- instruction memory interface
		imem_out, imem_in,
		-- data memory interface
		dmem_out, dmem_in
	);
	
	rv_sys_inst : entity work.rv_sys
	generic map (
		BAUD_RATE => BAUD_RATE,
		CLK_FREQ => CLOCK_FREQUENCY,
		SIMULATE_ELF_FILE => ELF_FILE,
		GPIO_ADDR_WIDTH => GPIO_ADDR_WIDTH,
		IMEM_DELAY => 0,
		DMEM_DELAY => 0
	)
	port map (
		clk => clk,
		res_n => res_n,

		cpu_reset_n => cpu_res_n,

		imem_out => imem_out,
		imem_in => imem_in,
		dmem_out => dmem_out,
		dmem_in => dmem_in,

		gp_out => gp_out,
		gp_in => gp_in,

		rx => rx,
		tx => tx
	);

	main : process is
	begin
		gp_in <= (others => (others => '0'));
		res_n <= '0';

		wait until rising_edge(clk);
		wait until rising_edge(clk);

		res_n <= '1';

		wait until rising_edge(clk);
		
		wait for SIM_TIMEOUT;
		print_line("Simulation done");

		std.env.stop;
	end process;

	gpio_printer : process (gp_out)
	begin
		for i in 0 to 2 ** GPIO_ADDR_WIDTH-1 loop
			print_line("GPIO["  & to_string(i) & "]: " & to_hstring(gp_out(i)));
		end loop;
	end process;

	uart_tx : process
	begin
		rx <= '1';
		wait until res_n = '1';

		uart_transmit(rx, BAUD_RATE, x"55");
		uart_transmit(rx, BAUD_RATE, x"41");
		uart_transmit(rx, BAUD_RATE, x"52");
		uart_transmit(rx, BAUD_RATE, x"54");

		wait;
	end process;

	uart_rx_printer : process
		variable uart_data : std_logic_vector(7 downto 0);
	begin
		loop
			uart_receive(tx, BAUD_RATE, uart_data);
			print_line("UART: " & to_string(to_character(uart_data)));
		end loop;
		wait;
	end process;

	dmem_printer : process
	begin
		if (dmem_out.wr = '1') then
			print_line(
				"DMEM write: " & 
				"addr=0x" & to_hstring(dmem_out.address) & ", " &
				"data=0x" & to_hstring(dmem_out.wrdata) & ", " &
				"byteen=" & to_string(unsigned(dmem_out.byteena))
			);
		end if;

		if (dmem_out.rd = '1') then
			loop
				if (dmem_in.busy = '0') then
					print_line(
						"DMEM read: " &
						"addr=0x" & to_hstring(dmem_out.address) & ", " &
						"data=0x" & to_hstring(dmem_in.rddata)
					);

					exit;
				end if;
				
				wait for CLK_PERIOD;
			end loop;
		end if;

		wait for CLK_PERIOD;
	end process;

	imem_printer : process
	begin
		if (imem_out.rd = '1') then
			loop
				if (imem_in.busy = '0') then
					print_line(
						"IMEM read: " &
						"addr=0x" & to_hstring( to_byte_address (imem_out.address)) & ", " &
						"data=0x" & to_hstring( swap_endianness (imem_in.rddata))
					);

					exit;
				end if;
				
				wait for CLK_PERIOD;
			end loop;
		end if;

		wait for CLK_PERIOD;
	end process;

	clk_gen: process is
	begin
		clk <= '1';
		wait for CLK_PERIOD / 2;
		clk <= '0';
		wait for CLK_PERIOD / 2;
	end process;

end architecture;
