
# RISC-V Pipeline
**Points:** 2 ` | ` **Keywords:** RISC-V, Pipeline


In this task you will take the first step towards implementing a pipelined five-stage RISC-V core.
However, we don't yet deal with [pipeline hazards](https://en.wikipedia.org/wiki/Hazard_(computer_architecture)).
Hence, the pipeline only executes one instruction at a time, similar to the processor implemented in the [`rv_fsm`](../rv_fsm/task.md) task.
The internal structure is quite different form this previous task though, such that hazard handling, necessary for for a fully pipelined operation, can be added in a later task.

Again, we do not recommend starting with this task, but to first complete [`rv_sim`](../rv_sim/task.md) and/or [`rv_fsm`](../rv_fsm/task.md).

[[_TOC_]]

## Task

The figure below shows an overview of the `rv_pl` core you have to implement in this task.
It contains the five pipeline stages (i.e., fetch, decode, execute, memory and writeback) as well as the control unit.
The control unit is responsible to selectively stall and flush pipeline stages, in order to make sure that branches, pipeline hazards and stalls caused by memory accesses are handled correctly.

![RISC-V pipeline overview](.mdata/pl_overview.svg)

The labels on the connections refer to record types defined in the [`rv_pl_op_pkg`](src/op_pkg.vhd).
Start by going through these types to see which signals are passed between the pipeline stages

**Remarks**:

 * Note that, with the exception of `regwr_t`, the record type names always indicate between which stages the data is being passed.
 * The type `ctrl_t` simply contains two signals, `flush` and `stall`. Each stage has its own pair of control signals (drawn in orange), such that it can be stalled/flushed independently form the other stages.
 * The `flush` signal shall **not** be treated as (another) asynchronous reset input.
 * Generally, the control unit does not need access to all the signals contained in the various records at its inputs. However, for the sake of simplicity and maintainability we decided connecting it to the full record types, as unused signal connections will be removed during synthesis anyway.
 * The blue signals paths are not needed for this task, as they are used to implement forwarding.
 * The single wires connecting the fetch/memory stage to the control unit are the busy signals of the instruction/data memory.
 * Notice that the types `f2d_t`, `d2e_t`, `e2m_t` and `m2w_t` all have a `pc` field, meaning that the program counter, associated with the instruction currently being executed in the respective pipeline stage, is always passed along through the pipeline. However, it is actually not needed after the execute stage, but can be useful while debugging.


The figure below shows the data path through the pipeline stages in a little bit more detail.

![RISC-V pipeline overview](.mdata/datapath.svg)

**Remarks**:
 * The figure **only** shows the data path. It does not show the control signals or the reset.
 * The registers of the individual stages must be placed exactly where they are shown in the figure!
 * The figure does not show the signal paths required to implement forwarding.
 * The bold connections indicate multi-bit signals, but do not directly correspond to the data types introduced in the previous figure.

In the following we will explain the individual pipeline stages and the control unit.

### Fetch Stage

#### Interface

```vhdl
entity rv_pl_fetch is
	port (
		clk   : in std_logic;
		res_n : in std_logic;

		ctrl : in  ctrl_t; -- from control unit
		m2f  : in  m2f_t;  -- from memory stage
		f2d  : out f2d_t;  -- to decode stage

		mem_out : out mem_out_t; -- to rv_sys
		mem_in  : in  mem_in_t;  -- from rv_sys

		mem_busy : out std_logic
	);
end entity;
```

#### Description
In the fetch stage, the instruction memory is read, and the next value of the program counter is computed.
After a reset, the fetch stage shall return the instruction located at address 0 in the instruction memory (Hint: Think about an appropriate reset value for the internal PC register to achieve that). 
In this regard, make sure that after a reset the correct instruction is fetched and no unwanted instructions enter the pipeline.
Additionally, take care that no instruction is unintentionally skipped or executed multiple times.

In case `ctrl.flush` is asserted, insert a `nop` instruction into the pipeline.
The `ctrl.stall` signal causes the fetch stage not to change internal registers, i.e., the program counter must not change while `ctrl.stall` is asserted.
If the fetch stage is not stalled and `m2f.branch` is asserted, the next program counter shall be `m2f.branch_target`
If `m2f.branch` is zero, it shall be the current program counter incremented by 4.

Note that the read port of the instruction memory is registered!
This means that the block labeled IMEM in the data path figure actually also contains a register, which is the reason why it is drawn with the same horizontal alignment as the program counter register.
Hence, it must be connected to the next program counter in order to output the instruction that corresponds to the current program counter value in the register.
The program counter is also passed on to the decode stage.
Further note, that the program counter holds a byte address, while the instruction memory is word-addressed.
However, you should already know how to deal with that from the previous RV tasks.

For this exercise, it can be assumed that a read access to the instruction memory always returns a value in the next cycle.
Therefore, `mem_in.busy` will always be `’0’`.
Nevertheless, connect `mem_in.busy` to `mem_busy` to be able to correctly react to the busy signal in later tasks.
Think about an appropriate value for `mem_out.rd` (`mem_out.wr` will always be zero).

### Decode Stage

#### Interface

```vhdl
entity rv_pl_decode is
	port (
		clk   : in std_logic;
		res_n : in std_logic;

		ctrl : in  ctrl_t;  -- from ctrl unit
		f2d  : in  f2d_t;   -- from fetch stage
		w2d  : in  regwr_t; -- from writeback stage
		d2e  : out d2e_t;   -- to execute stage

		exc_dec : out std_logic -- decode exception
	);
end entity;
```

#### Description

The decode stage contains the register file and translates the raw instructions to signals that are subsequently used in the pipeline.
Note that more than one instruction may be mapped to an operation of a functional unit such as the ALU.
For example, an addition of two registers, of a register and an immediate and calculations for memory accesses all make use of the ALU operation `ALU_ADD`.

Asserting `ctrl.stall` causes the stage not to transfer inputs into its internal registers; asserting `ctrl.flush` causes the unit to store a `nop` to its internal instruction register.
The decoding exception signal `exc_dec` shall be asserted if an instruction cannot be found in the respective table of [rv_core](../../../lib/rv_core/doc.md).


**Remarks and Hints**:
 * The inputs to the register file are registered! This is also indicated in the data path figure. Hence, **don't'** place an additional register in front of it!
 * Use `x0`/`zero` to mark unused registers in `d2e`.
 * You should be able to reuse some of the code from the previous RV tasks here.

#### Register File
You are already provided with an appropriate register file for this task in [`regfile.vhd`](src/regfile.vhd).
```vhdl
entity rv_pl_regfile is
	port (
		clk      : in  std_logic;
		res_n    : in  std_logic;
		stall    : in  std_logic;
		rd_addr1 : in  reg_address_t;
		rd_data1 : out data_t;
		rd_addr2 : in  reg_address_t;
		rd_data2 : out data_t;
		wr_addr  : in  reg_address_t;
		wr_data  : in  data_t;
		wr       : in  std_logic
	);
end entity;
```

The register file is a memory with two read ports and one write port, consisting of 32 words, each 32-bits wide.
The `clk` signal has the usual meaning and causes the circuit to record the read and write addresses and data.
The reset signal `res_n` is active-low and resets internal registers, but not the contents of the register file.
The signal `stall` causes the circuit not to observe input values such that old values are kept in all registers.
However, this does not apply to writes to the register file, which are also executed when it is stalled!
Reads from address 0 always return 0.
When reading from a register that is written in the same cycle, the new value is returned.

As explained in the Computer Architecture lecture, for many implementations of register files it is assumed that writing takes place in the first half of the clock cycle while reading is performed in the second half.
This way writes to the register file are guaranteed to be finished, before the reads take place, ensuring that the most up-to-date values are being read.
However, this approach is not supported by the hardware inside the FPGAs used during this lab course.
Therefore, the required behavior has to be implemented differently: If the internal register for a read address matches `wr_addr` and `wr` is asserted, the register file returns `wr_data` through some appropriate pass-through logic.

The figure below shows an example timing diagram demonstrating the behavior of the register file.

![RISC-V pipeline overview](.mdata/regfile_timing_examples.svg)


### Execute Stage

#### Interface

```vhdl
entity rv_pl_exec is
	port (
		clk    : in  std_logic;
		res_n  : in  std_logic;

		ctrl : in  ctrl_t;  -- from ctrl unit
		d2e  : in  d2e_t;   -- from decode stage
		e2m  : out e2m_t;   -- to memory stage
		m2e  : in  regwr_t; -- form memory stage (forwarding)
		w2e  : in  regwr_t  -- form writeback stage (forwarding)
	);
end entity;
```

#### Description

The execute stage contains the ALU, therefore "executing" the arithmetic and logic instructions.
Furthermore, the ALU is used to compute the addresses for memory accesses.
The addition required for calculating the destination address for branches, relative to the program counter, is also computed in this stage.

Asserting `ctrl.stall` causes the stage not to save inputs into its internal registers; asserting `ctrl.flush` causes the unit to store a `nop` to the pipeline registers.
The information in `d2e.exec_op` coming from the decode stage, is meant to be used for controlling the ALU and feeding it with the correct input values in order to produce the required result.
The ALU result is passed to the next pipeline stage via `e2m.alu_result` and `e2m.alu_z`.
Note that for this pipeline implementation, the ALU cannot be used to perform all arithmetic (and logic operations) required to execute an instruction, as was the case for the `rv_fsm` task.
One example are branch instructions, where the ALU is used to perform the comparison (with the result being provided via the zero flag), while the branch target address (i.e., `e2m.branch_target`) must be calculated in parallel by a separate adder, because both results are needed in the next stage in the next clock cycle.

Be sure to pass on the necessary signals contained in `d2e` to the next stage (i.e., to `e2m`).
The data to be written to memory has to be made available to the memory stage using the `e2m.mem_data` signal.
The inputs `m2e` and `w2e` are irrelevant for this assignment and can thus be ignored for now.
They will be used for forwarding the correct data to the ALU in a following task.

The file [`rv_alu`](src/rv_alu.vhd) already provides an entity declaration for the ALU.
You can copy your architecture from the [`alu`](../../level1/alu/task.md) task to this file.

### Memory Stage

#### Interface

```vhdl
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
```

#### Description

Most of the data memory-related functionality is already provided by the memory unit (`memu`).
Therefore, the implementation of this stage mainly consists of registering the inputs and passing them to the memory unit.

Despite its name, the memory stage does not only contain the memory unit, but is also used to evaluate and pass on the branch decision (taken/not taken via `m2f.branch`) as well as the branch target address (via `m2f.branch_target`) to the fetch stage.

Asserting `ctrl.flush` causes the unit to store a `nop` to the pipeline registers.
Asserting `ctrl.stall` causes the stage not to transfer inputs into its internal registers; additionally, neither `op.rd` nor `op.wr` of the memory unit must be asserted while the `ctrl.stall` signal is asserted.
Be sure to pass on the necessary signals, contained in `e2m`, to the next stage (i.e., to `m2w`).

In this exercise it can be assumed that the memory read result is available at the next clock cycle. 
Therefore, the `memu`’s `busy` signal is high for exactly one cycle per **read** access.
This signal must be connected to `mem_busy` output of the memory stage itself, as it is needed by the control unit.

### Writeback Stage

#### Interface

```vhdl
entity rv_pl_wb is
	port (
		clk   : in std_logic;
		res_n : in std_logic;

		ctrl : in  ctrl_t; -- from control unit
		m2w  : in  m2w_t;  -- from memory stage
		w2de : out regwr_t -- to decode stage and execute stage (fowarding)
	);
end entity;
```

#### Description

The purpose of the writeback stage is to decide which value (i.e., `m2w.alu_result` or `m2w.mem_result`) is written back to register file.
This task could also be carried out by the memory stage, however, with the writeback stage in place, it is possible to relax a critical timing path in the pipeline.

Again, be sure not to register new inputs when `ctrl.stall` is asserted and to store a `nop` when `ctrl.flush`is asserted.

### Control Unit
You are already provided with a simple control unit architecture in [`ctrl.vhd`](src/ctrl.vhd) (called `simple`), that enables the pipeline to execute arbitrary code.
By appropriately stalling and flushing the fetch stage, it ensures new instructions only enter the pipeline every fourth cycle.
This effectively circumvents problems caused by pipeline hazards (i.e., dependencies between successive instructions).
Hence, from the point of view of the other stages, every (actual) instruction is always followed by three `nop` instructions.

## Testbench and Hardware Test
Simulation and hardware testing work exactly as described in the [`rv_fsm`](../rv_fsm/task.md) task.



