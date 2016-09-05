CXX = g++
CXXFLAGS = -std=c++1z -Wall -W -pedantic -O3

lvcpu: lua.o mem.o cpu.o /usr/local/lib/liblua.a -ldl

.PHONY: clean
clean:
	rm -rf lvcpu *.o
