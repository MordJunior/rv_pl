library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rv_sys_pkg.all;
use work.rv_core_pkg.all;

package rv_util_pkg is

	constant HALF_WORD_WIDTH : natural := 16;
	constant WORD_WIDTH : natural := 32;
	
	subtype word_t is std_logic_vector (WORD_WIDTH - 1 downto 0);
	subtype hword_t is std_logic_vector (HALF_WORD_WIDTH - 1 downto 0);
	subtype byte_t is std_logic_vector (BYTE_WIDTH - 1 downto 0);
	
	constant RISCV_NOP : word_t := 32x"13";

	function is_zero (data : std_logic_vector) return std_logic;
	
	function get_instr_format (instr : instr_t) return instr_format_t;
	function get_immediate (instr : instr_t) return word_t;

	function to_word_address (data : word_t) return mem_address_t;
	function to_byte_address (data : mem_address_t) return word_t;

	function register_to_string (reg : reg_address_t) return String;

end rv_util_pkg;

package body rv_util_pkg is

	function is_zero (
		data : std_logic_vector
	) return std_logic is
	begin
		if unsigned (data) = 0 then
			return '1';
		end if;

		return '0';
	end function is_zero;

	function get_instr_format (instr : instr_t)
	return instr_format_t is
	begin
		case get_opcode (instr) is
			when OPCODE_OP =>
				return FORMAT_R;

			when OPCODE_JALR | OPCODE_LOAD | OPCODE_OP_IMM | OPCODE_FENCE => -- I
				return FORMAT_I;

			when OPCODE_STORE => -- S
				return FORMAT_S;

			when OPCODE_BRANCH => -- B
				return FORMAT_B;

			when OPCODE_LUI | OPCODE_AUIPC => -- U
				return FORMAT_U;

			when OPCODE_JAL => -- J
				return FORMAT_J;

			when others =>
				return FORMAT_INVALID;
		end case;
	end function;

	function get_immediate (instr : instr_t) 
	return word_t is
		constant format : instr_format_t := get_instr_format (instr);
		
		variable result : word_t := (others => '0');
	begin
		case format is
			when FORMAT_I => -- I
				result (31 downto 11) := (others => instr (31));
				result (10 downto 0) := instr (30 downto 20);

			when FORMAT_S => -- S
				result (31 downto 11) := (others => instr (31));
				result (10 downto 5) := instr (30 downto 25);
				result (4 downto 0) := instr (11 downto 7);

			when FORMAT_B => -- B
				result (31 downto 12) := (others => instr (31));
				result (11) := instr (7);
				result (10 downto 5) := instr (30 downto 25);
				result (4 downto 1) := instr (11 downto 8);

			when FORMAT_U => -- U
				result (31 downto 12) := instr (31 downto 12);

			when FORMAT_J => -- J
				result (31 downto 20) := (others => instr (31));
				result (19 downto 12) := instr (19 downto 12);
				result (11) := instr (20);
				result (10 downto 1) := instr (30 downto 21);

			when others =>
				null;
		end case;
		
		return result;
	end function;

	function to_word_address (data : word_t) 
	return mem_address_t is
	begin
		return data (RV_SYS_ADDR_WIDTH + 1 downto 2);
	end function;

	function to_byte_address (data : mem_address_t) 
	return word_t is
		variable result : word_t := (others => '0');
	begin
		result (RV_SYS_ADDR_WIDTH + 1 downto 2) := data;
		return result;
	end function;

	function register_to_string (reg : reg_address_t)
	return String is
		constant address : natural := to_integer (unsigned (reg));
	begin
		case address is
			when 0 => 
				return "zero (0)";

			when 1 =>
				return "ra (1)";

			when 2 =>
				return "sp (2)";

			when 3 =>
				return "gp (3)";

			when 4 =>
				return "tp (4)";

			when 5 | 6 | 7 =>
				return "t" & integer'image (address - 5) & " (" & integer'image (address) & ")";

			when 8 | 9 =>
				return "s" & integer'image (address - 8) & " (" & integer'image (address) & ")";

			when 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 =>
				return "a" & integer'image (address - 10) & " (" & integer'image (address) & ")";

			when 18 | 19 | 20 | 21 | 22 | 23 | 24 | 25 | 26 | 27 =>
				return "s" & integer'image (address - 16) & " (" & integer'image (address) & ")";

			when 28 | 29 | 30 | 31 =>
				return "t" & integer'image (address - 25) & " (" & integer'image (address) & ")";

			when others =>
				return "NaN";
		end case;
	end function;

end rv_util_pkg;




