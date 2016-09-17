CXX = g++
CXX_OPT = -O3
CXXFLAGS = -std=c++1z -Wall -W -pedantic $(CXX_OPT)

lvasm: source_data.o -lstdc++fs

.PHONY: clean
clean:
	rm -rf lvasm *.o
