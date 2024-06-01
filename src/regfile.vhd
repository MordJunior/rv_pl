library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv_core_pkg.all;
use work.rv_util_pkg.all;

entity rv_pl_regfile is
	port (
		clk      : in  std_logic;
		res_n    : in  std_logic;
		stall    : in  std_logic;
		rd_addr1 : in  reg_address_t;
		rd_data1 : out word_t;
		rd_addr2 : in  reg_address_t;
		rd_data2 : out word_t;
		wr_addr  : in  reg_address_t;
		wr_data  : in  word_t;
		wr       : in  std_logic
	);
end entity;

architecture rtl of rv_pl_regfile is
	type rf_t is array (0 to REG_COUNT - 1) of data_t;

	signal rf : rf_t := (others => (others => '0'));
	signal rd_addr1_reg, rd_addr2_reg : reg_address_t;
begin
	process(clk, res_n)
	begin
		if res_n = '0' then
			rd_addr1_reg <= (others=>'0');
			rd_addr2_reg <= (others=>'0');
		elsif rising_edge(clk) then
			if stall = '0' then
				rd_addr1_reg <= rd_addr1;
				rd_addr2_reg <= rd_addr2;
			end if;
		end if;
	end process;

	process(rf, rd_addr1_reg, rd_addr2_reg, stall, wr, wr_addr, wr_data)
	begin
		rd_data1 <= rf(to_integer(unsigned(rd_addr1_reg)));
		if stall = '0' and rd_addr1_reg = wr_addr and wr = '1' and unsigned(wr_addr) /= 0 then
			rd_data1 <= wr_data;
		end if;
		rd_data2 <= rf(to_integer(unsigned(rd_addr2_reg)));
		if stall = '0' and rd_addr2_reg = wr_addr and wr = '1' and unsigned(wr_addr) /= 0 then
			rd_data2 <= wr_data;
		end if;
	end process;

	process (clk)
	begin
		if rising_edge(clk) then
			if wr = '1' and unsigned(wr_addr) /= 0 then
				report "REG [" & register_to_string (wr_addr) & "]: " & to_hstring (wr_data);
				rf(to_integer(unsigned(wr_addr))) <= wr_data;
			end if;
		end if;
	end process;
end architecture;

