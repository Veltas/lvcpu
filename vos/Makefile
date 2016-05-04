ASM = lua ../asm/asm.lua
CPU = lua ../cpu/cpu.lua
CPU_CLOCK = 1000000

.PHONY: all
all: vos.bin

vos.bin: vos.asm malloc.asm basic.asm
	$(ASM) $< $@

.PHONY: run
run: vos.bin
	$(CPU) $(CPU_CLOCK) 64 /dev/stdin /dev/stdout $<
