helloworld.bin: helloworld.asm
	lua ../asm/asm.lua $< $@

.PHONY: run
run: helloworld.bin
	lua ../cpu/cpu.lua 100 64 /dev/stdin /dev/stdout helloworld.bin
