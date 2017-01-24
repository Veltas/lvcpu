CXX = g++
CXX_OPT = -O3
CXXFLAGS = -std=c++1z -Wall -W -pedantic $(CXX_OPT)

lvcpu: LDLIBS += -llua -ldl
lvcpu: lua.o cpu.o

.PHONY: clean
clean:
	rm -rf lvcpu *.o
