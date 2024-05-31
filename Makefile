VHDL_FILES = \
	../../../lib/math/src/math_pkg.vhd \
	../../../lib/sync/src/sync_pkg.vhd \
	../../../lib/sync/src/sync.vhd \
	../../../lib/tb_util/src/tb_util_pkg.vhd \
	../../../lib/mem/src/mem_pkg.vhd \
	../../../lib/mem/src/dp_ram_1c1r1w.vhd \
	../../../lib/mem/src/fifo_1c1r1w.vhd \
	../../../lib/mem/src/fifo_1c1r1w_fwft.vhd \
	../../../lib/mem/src/dp_ram_2c2rw.vhd \
	../../../lib/mem/src/dp_ram_2c2rw_byteen.vhd \
	../../../lib/rv_core/src/rv_core_pkg.vhd \
	../../../lib/rv_sys/src/rv_sys_pkg.vhd \
	../../../lib/rv_sys/src/delay.vhd \
	../../../lib/rv_sys/src/virtual_jtag_wrapper.vhd \
	../../../lib/rv_sys/src/sld_virtual_jtag_stub.vhd \
	../../../lib/rv_sys/src/memory_sim.vhd \
	../../../lib/rv_sys/src/memory_jtag.vhd \
	../../../lib/rv_sys/src/mm_serial_port.vhd \
	../../../lib/rv_sys/src/mm_counter.vhd \
	../../../lib/rv_sys/src/mm_gpio.vhd \
	../../../lib/rv_sys/src/rv_sys.vhd \
	../../../lib/rv_sys/src/memu.vhd \
	./src/rv_util_pkg.vhd \
	./src/rv_alu_pkg.vhd \
	./src/rv_alu.vhd \
	./src/op_pkg.vhd \
	./src/op_pkg.vhd \
	./src/ctrl.vhd \
	./src/regfile.vhd \
	./src/decode.vhd \
	./src/exec.vhd \
	./src/fetch.vhd \
	./src/mem.vhd \
	./src/wb.vhd \
	./src/rv_pl.vhd \
	./tb/rv_tb.vhd

TB=rv_tb
WAVE_FILE=

CLEAN_FILES=*.o

all: clean filter

include ../../../util/simple_flow.mk

pfx=/opt/ddca/riscv/bin/riscv32-unknown-elf
gcc=$(pfx)-gcc
obj=$(pfx)-objdump

LOG_DIR=./logs
LOG_FILE=$(LOG_DIR)/gsim.log

filter:
	@rm -rf $(LOG_DIR) && mkdir $(LOG_DIR)
	@echo "starting simulation"
	@$(MAKE) gsim > $(LOG_FILE)
	@echo "finished simulation"
	@echo -n "UART: "
	@grep --text "UART" $(LOG_FILE) | sed -e 's/^.*UART: //' | tr -d '\n' | tee $(LOG_DIR)/uart.log; echo
	@grep --text "GPIO" $(LOG_FILE) | sed -e 's/^.*GPIO//' > $(LOG_DIR)/gpio.log
	@grep --text "IMEM" $(LOG_FILE) | sed -e 's/^.*IMEM //' > $(LOG_DIR)/imem.log
	@grep --text "DMEM" $(LOG_FILE) | sed -e 's/^.*DMEM //' > $(LOG_DIR)/dmem.log
	@grep --text "REG" $(LOG_FILE) | sed -e 's/^.*REG //' > $(LOG_DIR)/reg.log
	@cat $(LOG_DIR)/imem.log | sed -e 's/^.*data=/.word /' > asm.S
	@$(gcc) -c asm.S; $(obj) -D asm.o | sed -e 's/^\s*[0-9a-f]*:\s*[0-9a-f]*\s*//' > asm.S
	@echo "finished filtering log"

