%.bin: %.asm
	lua ../asm/asm.lua $< $@

TARGETS := $(patsubst %.asm,%.bin,$(wildcard *.asm))

.PHONY: all
all: $(TARGETS)

clean:
	rm -f $(TARGETS)

# Run
#	lua ../cpu/cpu.lua 100 64 /dev/stdin /dev/stdout helloworld.bin
