#ifndef LVCPU_BIN_UTILS_HPP_INCLUDED
#define LVCPU_BIN_UTILS_HPP_INCLUDED

#include <cstdint>

inline std::uint16_t make_word(const std::uint8_t low_byte, const std::uint8_t high_byte)
{
	return
		static_cast<std::uint16_t>(low_byte)
		| static_cast<std::uint16_t>(high_byte) << 8;
}

inline std::uint8_t get_high_byte(const std::uint16_t word)
{
	return static_cast<std::uint8_t>(word >> 8);
}

inline std::uint8_t get_low_byte(const std::uint16_t word)
{
	return static_cast<std::uint8_t>(word);
}

inline std::uint8_t make_byte(const std::uint8_t low_nibble, const std::uint8_t high_nibble)
{
	return (low_nibble & 0x0F) | (high_nibble << 4);
}

inline std::uint8_t get_high_nibble(const std::uint8_t byte)
{
	return byte >> 4;
}

inline std::uint8_t get_low_nibble(const std::uint8_t byte)
{
	return byte & 0x0F;
}

#endif // LVCPU_BIN_UTILS_HPP_INCLUDED
