#include "mem.hpp"

Mem::Mem(const std::size_t size) :
	_contents(size, 0)
{}

bool Mem::is_valid(const std::uint16_t address)
{
	return address < _contents.size();
}

std::uint8_t Mem::read(const std::uint16_t address)
{
	if (is_valid(address)) {
		return _contents[address];
	}
	return 0;
}

void Mem::write(const std::uint16_t address, const std::uint8_t value)
{
	if (is_valid(address)) {
		_contents[address] = value;
	}
}
