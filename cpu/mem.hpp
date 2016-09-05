#ifndef LVCPU_MEM_HPP_INCLUDED
#define LVCPU_MEM_HPP_INCLUDED

#include <cstddef>
#include <cstdint>
#include <vector>

class Mem {
	bool is_valid(std::uint16_t address);
	std::vector<std::uint8_t> _contents;
public:
	Mem(std::size_t size);
	std::uint8_t read(std::uint16_t address);
	void         write(std::uint16_t address, std::uint8_t value);
};

#endif // LVCPU_MEM_HPP_INCLUDED
