TLC = tlc
TLC_FLAGS = -swc

cpu.lua: cpu.tl
	$(TLC) $(TLC_FLAGS) -o $@ $^

clean:
	rm -f cpu.lua

