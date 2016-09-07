#ifndef LVCPU_MEM_HPP_INCLUDED
#define LVCPU_MEM_HPP_INCLUDED

#include <cstddef>
#include <cstdint>
#include <vector>

class Mem {
	std::vector<std::uint8_t> _contents;
public:
	inline              Mem();
	inline std::uint8_t read(std::uint16_t address);
	inline void         write(std::uint16_t address, std::uint8_t value);
};

Mem::Mem() :
	_contents(0x10000, 0)
{}

std::uint8_t Mem::read(const std::uint16_t address)
{
	return _contents[address];
}

void Mem::write(const std::uint16_t address, const std::uint8_t value)
{
	_contents[address] = value;
}

#endif // LVCPU_MEM_HPP_INCLUDED
