CXX = g++
CXX_OPT = -O3
CXXFLAGS = -std=c++1z -Wall -W -pedantic $(CXX_OPT)

lvcpu: lua.o cpu.o -llua -ldl

.PHONY: clean
clean:
	rm -rf lvcpu *.o
