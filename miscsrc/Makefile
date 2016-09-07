%.bin: %.asm
	lua ../asm/asm.lua $< $@

.PHONY: all
all: helloworld.bin long_loop.bin

# Run
#	lua ../cpu/cpu.lua 100 64 /dev/stdin /dev/stdout helloworld.bin
