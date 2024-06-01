library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv_util_pkg.all;

use work.rv_alu_pkg.all;

entity rv_alu is
	port (
		op   : in  rv_alu_op_t;
		A, B : in  word_t;
		R    : out word_t := (others => '0');
		Z    : out std_logic := '0'
	);
end entity;

architecture rtl of rv_alu is
begin
	Z <= R(0) when op = ALU_SLT or op = ALU_SLTU else
		 '1' when op = ALU_SUB and signed (A) = signed (B) else
		 '0' when op = ALU_SUB else
		 '0';

	process (all)
		variable sig_A, sig_B : signed (word_t'range);
		variable uns_A, uns_B : unsigned (word_t'range);

		variable shift : natural;
	begin
		sig_A := signed (A);
		sig_B := signed (B);
		uns_A := unsigned (A);
		uns_B := unsigned (B);

		shift := to_integer (unsigned (B (4 downto 0)));

		case op is
			when ALU_NOP =>	R <= B;
			
			when ALU_AND =>	R <= A and B;

			when ALU_OR => R <= A or B;

			when ALU_XOR => R <= A xor B;

			when ALU_ADD => R <= std_logic_vector (sig_A + sig_B);

			when ALU_SUB => R <= std_logic_vector (uns_A - uns_B);

			when ALU_SLL => R <= std_logic_vector (shift_left (uns_A, shift));

			when ALU_SRL => R <= std_logic_vector (shift_right (uns_A, shift));

			when ALU_SRA => R <= std_logic_vector (shift_right (sig_A, shift));

			when ALU_SLT => 
				R <= (others => '0');

				if sig_A < sig_B then
					R (0) <= '1';
				end if;
			
			when ALU_SLTU => 
				R <= (others => '0');

				if uns_A < uns_B then
					R (0) <= '1';
				end if;
		
			when others =>
				R <= (others => '0');
		end case;
	end process;

end architecture;
