#include "cpu.hpp"
#include "bin_utils.hpp"

#include <cmath>
#include <algorithm>
#include <utility>
#include <stdexcept>
#include <thread>
#include <vector>
#include <array>
#include <unordered_set>

namespace {
	inline void sometimes_yield()
	{
		//TODO
	}
}

void CPU::clock_tick()
{
	if (_clock_multiplier_stage == _clock_multiplier - 1) {
		_clock_multiplier_stage = 0;
		auto now = std::chrono::high_resolution_clock::now();
		while (now < _next_tick) {
			sometimes_yield();
			now = std::chrono::high_resolution_clock::now();
		}
		_next_tick += _clock_period;
	} else {
		++_clock_multiplier_stage;
	}
}

std::uint8_t CPU::instruction_fetch()
{
	clock_tick();
	const auto fetched_byte = _mem->read(_ip);
	++_ip;
	return fetched_byte;
}

namespace {
	bool is_interrupt_code_error(const std::uint8_t interrupt_code)
	{
		static const std::unordered_set<std::uint8_t> error_codes = {
			0x0u, 0x2u, 0x3u
		};
		return error_codes.find(interrupt_code) == error_codes.end();
	}
}

void CPU::raise_interrupt(const std::uint8_t interrupt_code)
{
	if (_interrupt_handling) {
		if (_interrupt_level == 2) {
			_power_on = false;
			return;
		}
		_shadow.a = _ip;
		if (_interrupt_level == 1 && is_interrupt_code_error(interrupt_code)) {
			_ip = 16u * 0x3u + 2048u * _t;
		} else {
			_ip = 16u * interrupt_code + 2048u * _t;
		}
		++_interrupt_level;
	}
}

void CPU::bad_op_code()
{
	raise_interrupt(0x0);
}

void CPU::bad_parameter()
{
	raise_interrupt(0x0);
}

namespace {
	inline bool is_g8(const std::uint8_t code)
	{
		return code < 0x4u;
	}

	inline bool is_g16(const std::uint8_t code)
	{
		return code < 0x2u;
	}

	inline bool is_r16(const std::uint8_t code)
	{
		return code < 0x4u;
	}
}

void CPU::set_g8(const std::uint8_t code, const std::uint8_t value)
{
	switch (code) {
	case 0x0:
		_primary.a = make_word(value, get_high_byte(_primary.a));
		break;
	case 0x1:
		_primary.a = make_word(get_low_byte(_primary.a), value);
		break;
	case 0x2:
		_primary.c = make_word(value, get_high_byte(_primary.c));
		break;
	case 0x3:
		_primary.c = make_word(get_low_byte(_primary.c), value);
		break;
	default:
		throw std::domain_error{"set_g8() called with invalid register code"};
	}
}

std::uint8_t CPU::get_g8(const std::uint8_t code)
{
	switch (code) {
	case 0x0:
		return get_low_byte(_primary.a);
	case 0x1:
		return get_high_byte(_primary.a);
	case 0x2:
		return get_low_byte(_primary.c);
	case 0x3:
		return get_high_byte(_primary.a);
	}
	throw std::domain_error{"get_g8() called with invalid register code"};
}

std::uint16_t & CPU::get_g16(const std::uint8_t code)
{
	switch (code) {
	case 0x0:
		return _primary.a;
	case 0x1:
		return _primary.c;
	}
	throw std::domain_error{"get_g16() called with invalid register code"};
}

std::uint16_t & CPU::get_r16(const std::uint8_t code)
{
	switch (code) {
	case 0x0:
		return _primary.a;
	case 0x1:
		return _primary.c;
	case 0x2:
		return _primary.sp;
	case 0x3:
		return _primary.bp;
	}
	throw std::domain_error{"get_g16() called with invalid register code"};
}

void CPU::set_zero_flag(const bool state)
{
	if (state) {
		_primary.f |= 1u;
	} else {
		_primary.f &= 0xFFu ^ 1u;
	}
}

void CPU::set_carry_flag(const bool state)
{
	if (state) {
		_primary.f |= 2u;
	} else {
		_primary.f &= 0xFFu ^ 2u;
	}
}

bool CPU::get_zero_flag()
{
	return _primary.f & 1u;
}

bool CPU::get_carry_flag()
{
	return _primary.f & 2u;
}

void CPU::byte_op_nop()
{
}

namespace {
	bool n8_carry(const std::uint8_t p1, const std::uint8_t p2)
	{
		return static_cast<std::uint16_t>(p1) + p2 > 0xFFu;
	}

	bool n16_carry(std::uint16_t p1, std::uint16_t p2)
	{
		return static_cast<std::uint32_t>(p1) + p2 > 0xFFFFu;
	}
}

void CPU::byte_op_add(const std::uint8_t op_code)
{
	const auto params = instruction_fetch();
	const auto p1_code = get_high_nibble(params);
	const auto p2_code = get_low_nibble(params);
	if (op_code == 0x01) {
		if (is_g8(p1_code) && is_g8(p2_code)) {
			set_carry_flag(n8_carry(get_g8(p1_code), get_g8(p2_code)));
			set_g8(p1_code, get_g8(p1_code) + get_g8(p2_code));
			set_zero_flag(get_g8(p1_code) == 0);
		} else {
			bad_parameter();
		}
	} else if (op_code == 0x02) {
		if (is_r16(p1_code) && is_r16(p2_code)) {
			set_carry_flag(n16_carry(get_r16(p1_code), get_r16(p2_code)));
			get_r16(p1_code) += get_r16(p2_code);
			set_zero_flag(get_r16(p1_code) == 0);
		} else {
			bad_parameter();
		}
	} else {
		std::domain_error{"byte_op_add() called with wrong op code"};
	}
}

void CPU::byte_op_sub(const std::uint8_t op_code)
{
	const auto params = instruction_fetch();
	const auto p1_code = get_high_nibble(params);
	const auto p2_code = get_low_nibble(params);
	if (op_code == 0x03) {
		if (is_g8(p1_code) && is_g8(p2_code)) {
			set_g8(p1_code, get_g8(p1_code) - get_g8(p2_code));
			set_zero_flag(get_g8(p1_code) == 0);
		} else {
			bad_parameter();
		}
	} else if (op_code == 0x04) {
		if (is_r16(p1_code) && is_r16(p2_code)) {
			get_r16(p1_code) -= get_r16(p2_code);
			set_zero_flag(get_r16(p1_code) == 0);
		} else {
			bad_parameter();
		}
	} else {
		std::domain_error{"byte_op_sub() called with wrong op code"};
	}
}

void CPU::byte_op_inc_dec(const std::uint8_t op_code)
{
	if (op_code == 0x05) {
		++_primary.c;
	} else if (op_code == 0x06) {
		--_primary.c;
	} else {
		std::domain_error{"byte_op_inc_dec() called with wrong op code"};
	}
}

void CPU::byte_op_neg()
{
	const auto params = instruction_fetch();
	const auto p1_mode = get_high_nibble(params);
	const auto p2_code = get_low_nibble(params);
	if (p1_mode == 0) {
		if (is_g8(p2_code)) {
			set_g8(p2_code, -get_g8(p2_code));
		} else {
			bad_parameter();
		}
	} else if (p1_mode == 1) {
		if (is_g16(p2_code)) {
			get_g16(p2_code) *= -1;
		} else {
			bad_parameter();
		}
	} else {
		bad_parameter();
	}
}

void CPU::byte_op_bin(const std::uint8_t op_code)
{
	const auto params = instruction_fetch();
	const auto p1_code = get_high_nibble(params);
	const auto p2_code = get_low_nibble(params);
	if (is_g8(p1_code) && is_g8(p2_code)) {
		const auto p1 = get_g8(p1_code);
		const auto p2 = get_g8(p2_code);
		if (op_code == 0x08) {
			set_g8(p1_code, p1 & p2);
		} else if (op_code == 0x09) {
			set_g8(p1_code, p1 | p2);
		} else if (op_code == 0x0A) {
			set_g8(p1_code, p1 ^ p2);
		} else {
			throw std::domain_error{"byte_op_bin() called with incorrect op code"};
		}
	} else {
		bad_parameter();
	}
}

void CPU::byte_op_shift(const std::uint8_t op_code)
{
	const auto params = instruction_fetch();
	const auto p1_code = get_high_nibble(params);
	const auto p2_val = get_low_nibble(params);
	if (is_g8(p1_code)) {
		const auto p1 = get_g8(p1_code);
		if (op_code == 0x0B) {
			if (p2_val > 7) {
				bad_parameter();
			} else {
				set_g8(p1_code, (p1 << p2_val) | (p1 >> (8 - p2_val)));
			}
		} else if (op_code == 0x0C) {
			if (p2_val > 7) {
				set_g8(p1_code, p1 >> (16 - p2_val));
			} else {
				set_g8(p1_code, p1 << p2_val);
			}
		} else {
			throw std::domain_error{"byte_op_shift() called with incorrect op code"};
		}
	} else {
		bad_parameter();
	}
}

void CPU::byte_op_mul()
{
	const auto params = instruction_fetch();
	const auto p1_code = get_high_nibble(params);
	const auto p2_code = get_low_nibble(params);
	if (is_g8(p1_code) && is_g8(p2_code)) {
		set_carry_flag(get_g8(p1_code) * get_g8(p2_code) > 0xFF);
		set_g8(p1_code, get_g8(p1_code) * get_g8(p2_code));
	} else if (is_g8(p1_code) && p2_code == 0x4) {
		set_carry_flag(static_cast<std::uint32_t>(_primary.a) * get_g8(p1_code) > 0xFFFF);
		_primary.a *= p1_code;
	} else {
		bad_parameter();
	}
}

void CPU::byte_op_mov(const std::uint8_t op_code)
{
	switch (op_code) {
		case 0x20: {
			const auto params = instruction_fetch();
			const auto p1_code = get_high_nibble(params);
			const auto p2_code = get_low_nibble(params);
			if (is_g8(p1_code) && is_g8(p2_code)) {
				set_g8(p1_code, get_g8(p2_code));
			} else {
				bad_parameter();
			}
		} break;
		case 0x21: {
			const auto params = instruction_fetch();
			const auto p1_code = get_high_nibble(params);
			const auto p2_code = get_low_nibble(params);
			if (is_r16(p1_code) && is_r16(p2_code)) {
				get_r16(p1_code) = get_r16(p2_code);
			} else {
				bad_parameter();
			}
		} break;
		case 0x22: {
			const auto param = instruction_fetch();
			if (param == 0x01) {
				_primary.a = make_word(_primary.f, get_high_byte(_primary.a));
			} else if (param == 0x02) {
				_primary.a = make_word(_ic, get_high_byte(_primary.a));
			} else if (param == 0x03) {
				_primary.a = _ip;
			} else {
				bad_parameter();
			}
		} break;
		case 0x23: {
			const auto value = instruction_fetch();
			_primary.a = make_word(
				_mem->read(_primary.bp + static_cast<std::int8_t>(value)),
				get_high_byte(_primary.a)
			);
		} break;
		case 0x24: {
			_primary.a = make_word(
				_mem->read(_primary.c),
				get_high_byte(_primary.a)
			);
		} break;
		case 0x25: {
			const auto value = instruction_fetch();
			_mem->write(
				_primary.bp + static_cast<std::int8_t>(value),
				get_low_byte(_primary.a)
			);
		} break;
		case 0x26: {
			_mem->write(_primary.c, get_low_byte(_primary.a));
		} break;
		case 0x29: {
			const auto value = instruction_fetch();
			_primary.a = make_word(
				_mem->read(_primary.bp + static_cast<std::int8_t>(value)),
				_mem->read(_primary.bp + static_cast<std::int8_t>(value) + 1)
			);
		} break;
		case 0x2A: {
			_primary.a = make_word(
				_mem->read(_primary.c),
				_mem->read(_primary.c + 1)
			);
		} break;
		case 0x2B: {
			_primary.a = make_word(_t, get_high_byte(_primary.a));
		} break;
		case 0x2C: {
			_t = get_low_byte(_primary.a);
		} break;
		case 0x2D: {
			const auto value = instruction_fetch();
			_mem->write(
				_primary.bp + static_cast<std::int8_t>(value),
				get_low_byte(_primary.a)
			);
			_mem->write(
				_primary.bp + static_cast<std::int8_t>(value) + 1,
				get_high_byte(_primary.a)
			);
		} break;
		case 0x2E: {
			_mem->write(_primary.c, get_low_byte(_primary.a));
			_mem->write(_primary.c + 1, get_high_byte(_primary.a));
		} break;
		default: {
			throw std::domain_error{"byte_op_mov() called with bad op code"};
		} break;
	}
}

void CPU::byte_op_swp()
{
	std::swap(_primary, _shadow);
}

void CPU::byte_op_jp(const std::uint8_t op_code)
{
	const auto b1 = instruction_fetch();
	const auto b2 = instruction_fetch();
	const auto addr = make_word(b1, b2);
	switch (op_code) {
		case 0x40: {
			_ip = addr;
		} break;
		case 0x41: {
			if (get_zero_flag()) _ip = addr;
		} break;
		case 0x42: {
			if (get_carry_flag()) _ip = addr;
		} break;
		case 0x43: {
			if (!get_zero_flag()) _ip = addr;
		} break;
		case 0x44: {
			if (!get_carry_flag()) _ip = addr;
		} break;
		default: {
			throw std::domain_error{"byte_op_jp() called with bad op code"};
		} break;
	}
}

void CPU::byte_op_call(const std::uint8_t op_code)
{
	if (op_code == 0x48) {
		const auto b1 = instruction_fetch();
		const auto b2 = instruction_fetch();
		const auto addr = make_word(b1, b2);
		_ip = addr;
	} else if (op_code == 0x49) {
		_ip = _primary.a;
	} else {
		throw std::domain_error{"byte_op_call() called with bad op code"};
	}
}

void CPU::byte_op_interrupt()
{
	const auto interrupt_code = instruction_fetch();
	raise_interrupt(interrupt_code);
}

void CPU::byte_op_ret(const std::uint8_t op_code)
{
	if (op_code == 0x4B) {
		_ip = make_word(_mem->read(_primary.sp), _mem->read(_primary.sp + 1));
		_primary.sp += 2;
	} else if (op_code == 0x4C) {
		if (_interrupt_level > 0) {
			--_interrupt_level;
		} else {
			bad_parameter();
		}
		_ip = _shadow.a;
	} else {
		throw std::domain_error{"byte_op_ret() called with bad op code"};
	}
}

void CPU::byte_op_mode_change(const std::uint8_t op_code)
{
	switch (op_code) {
		case 0x50: {
			_interrupt_handling = true;
		} break;
		case 0x51: {
			_interrupt_handling = false;
		} break;
		case 0x52: {
			_clock_interrupt = true;
		} break;
		case 0x53: {
			_clock_interrupt = false;
		} break;
		case 0x54: {
			// not implemented
		} break;
		case 0x55: {
			// not implemented
		} break;
		default: {
			throw std::domain_error{
				"byte_op_mode_change() called with bad op code"
			};
		} break;
	}
}

void CPU::byte_op_input_output(const std::uint8_t op_code)
{
	if (op_code == 0x60) {
		char input_char;
		_input->get(input_char);
		_primary.a = make_word(input_char, get_high_byte(_primary.a));
	} else if (op_code == 0x61) {
		_output->put(get_low_byte(_primary.a));
	} else {
		bad_parameter();
	}
}

void CPU::byte_op_stop()
{
	_power_on = false;
}

void CPU::nibble_op_mov(const std::uint8_t op_nibble, const std::uint8_t op_param)
{
	if (op_nibble == 0x8) {
		const auto param = instruction_fetch();
		if (is_g8(op_param)) {
			set_g8(op_param, param);
		} else {
			bad_parameter();
		}
	} else if (op_nibble == 0x9) {
		const auto p1 = instruction_fetch();
		const auto p2 = instruction_fetch();
		if (is_r16(op_param)) {
			get_r16(op_param) = make_word(p1, p2);
		} else {
			bad_parameter();
		}
	} else {
		throw std::domain_error{"nibble_op_mov() has incorrect op nibble"};
	}
}

void CPU::nibble_op_push(const std::uint8_t op_nibble, const std::uint8_t op_param)
{
	if (op_nibble == 0xA) {
		if (is_g8(op_param)) {
			_primary.sp -= 1;
			_mem->write(_primary.sp, get_g8(op_param));
		} else {
			bad_parameter();
		}
	} else if (op_nibble == 0xB) {
		if (is_r16(op_param)) {
			_primary.sp -= 2;
			const auto &reg = get_r16(op_param);
			_mem->write(_primary.sp, get_low_byte(reg));
			_mem->write(_primary.sp + 1, get_high_byte(reg));
		} else {
			bad_parameter();
		}
	} else {
		throw std::domain_error{"nibble_op_push() has incorrect op nibble"};
	}
}

void CPU::nibble_op_pop(const std::uint8_t op_nibble, const std::uint8_t op_param)
{
	if (op_nibble == 0xC) {
		if (is_g8(op_param)) {
			set_g8(op_param, _mem->read(_primary.sp));
			_primary.sp += 1;
		} else {
			bad_parameter();
		}
	} else if (op_nibble == 0xD) {
		if (is_r16(op_param)) {
			get_r16(op_param) = make_word(
				_mem->read(_primary.sp),
				_mem->read(_primary.sp + 1)
			);
			_primary.sp += 2;
		} else {
			bad_parameter();
		}
	} else {
		throw std::domain_error{"nibble_op_pop() has incorrect op nibble"};
	}
}

void CPU::nibble_op_add(const std::uint8_t op_nibble, const std::uint8_t op_param)
{
	if (op_nibble == 0xE) {
		if (is_g8(op_param)) {
			const auto value = instruction_fetch();
			set_carry_flag(n8_carry(get_g8(op_param), value));
			set_g8(op_param, get_g8(op_param) + value);
			set_zero_flag(get_g8(op_param) == 0);
		} else {
			bad_parameter();
		}
	} else if (op_nibble == 0xF) {
		if (is_r16(op_param)) {
			const auto value_low = instruction_fetch();
			const auto value_high = instruction_fetch();
			const auto value = make_word(value_low, value_high);
			auto &reg = get_r16(op_param);
			set_carry_flag(n16_carry(get_r16(op_param), value));
			reg += value;
			set_zero_flag(reg == 0);
		} else {
			bad_parameter();
		}
	} else {
		throw std::domain_error{"nibble_op_add() has incorrect op nibble"};
	}
}

CPU::CPU(
	Mem          &mem,
	const double clock_rate,
	std::istream &input,
	std::ostream &output
) :
	_clock_period(
		std::max(
			static_cast<std::chrono::microseconds::rep>(
				1'000'000/clock_rate - std::fmod(1'000'000/clock_rate, 20000.)
			),
			std::chrono::microseconds::rep{20'000}
		)
	),
	_clock_multiplier(std::max(1., clock_rate / 50)),
	_next_tick(std::chrono::high_resolution_clock::now()),
	_mem(&mem),
	_input(&input),
	_output(&output)
{
	if (clock_rate <= 0) {
		throw std::out_of_range{"CPU clock_rate given not positive"};
	}
}

void CPU::step()
{
	if (_clock_interrupt && _ic == 0) {
		raise_interrupt(0x01);
	}
	const auto op_code = instruction_fetch();
	if (op_code <= 0x70) {
		switch(op_code) {
		case 0x00:
			byte_op_nop();
			break;
		case 0x01: case 0x02:
			byte_op_add(op_code);
			break;
		case 0x03: case 0x04:
			byte_op_sub(op_code);
			break;
		case 0x05: case 0x06:
			byte_op_inc_dec(op_code);
			break;
		case 0x07:
			byte_op_neg();
			break;
		case 0x08: case 0x09: case 0x0A:
			byte_op_bin(op_code);
			break;
		case 0x0B: case 0x0C:
			byte_op_shift(op_code);
			break;
		case 0x0D:
			byte_op_mul();
			break;
		case 0x20: case 0x21: case 0x22: case 0x23: case 0x24: case 0x25:
		case 0x26: case 0x29: case 0x2A: case 0x2B: case 0x2C: case 0x2D:
		case 0x2E:
			byte_op_mov(op_code);
			break;
		case 0x28:
			byte_op_swp();
			break;
		case 0x40: case 0x41: case 0x42: case 0x43: case 0x44:
			byte_op_jp(op_code);
			break;
		case 0x48: case 0x49:
			byte_op_call(op_code);
			break;
		case 0x4A:
			byte_op_interrupt();
			break;
		case 0x4B: case 0x4C:
			byte_op_ret(op_code);
			break;
		case 0x50: case 0x51: case 0x52: case 0x53: case 0x54: case 0x55:
			byte_op_mode_change(op_code);
			break;
		case 0x60: case 0x61:
			byte_op_input_output(op_code);
			break;
		case 0x70:
			byte_op_stop();
			break;
		default:
			bad_op_code();
			break;
		}
	} else {
		const auto op_nibble = get_high_nibble(op_code);
		const auto op_param = get_low_nibble(op_code);
		switch (op_nibble) {
		case 0x8: case 0x9:
			nibble_op_mov(op_nibble, op_param);
			break;
		case 0xA: case 0xB:
			nibble_op_push(op_nibble, op_param);
			break;
		case 0xC: case 0xD:
			nibble_op_pop(op_nibble, op_param);
			break;
		case 0xE: case 0xF:
			nibble_op_add(op_nibble, op_param);
			break;
		}
	}
	++_ic;
}

bool CPU::is_on() const
{
	return _power_on;
}

std::ostream & operator << (std::ostream &out, const CPU &cpu)
{
	out << "REGISTERS\n";
	out << "A:" << cpu._primary.a << "\tC:" << cpu._primary.c << "\n";
	out << "AL:" << (int)get_low_byte(cpu._primary.a) << "\tAH:" << (int)get_high_byte(cpu._primary.a);
	out << "\tCL:" << (int)get_low_byte(cpu._primary.c) << "\tCH:" << (int)get_high_byte(cpu._primary.c) << "\n";
	out << "F:" << (int)cpu._primary.f << "\tSP:" << cpu._primary.sp;
	out << "\tBP:" << cpu._primary.bp << "\n";
	out << "A':" << cpu._shadow.a << "\tC':" << cpu._shadow.c << "\n";
	out << "AL':" << (int)get_low_byte(cpu._shadow.a) << "\tAH':" << (int)get_high_byte(cpu._shadow.a);
	out << "\tCL':" << (int)get_low_byte(cpu._shadow.c) << "\tCH':" << (int)get_high_byte(cpu._shadow.c) << "\n";
	out << "F':" << (int)cpu._shadow.f << "\tSP':" << cpu._shadow.sp;
	out << "\tBP':" << cpu._shadow.bp << "\n";
	out << "IP:" << cpu._ip << "\tIC:" << (int)cpu._ic << "\tT:" << (int)cpu._t << "\n";
	out << "ih:" << (cpu._interrupt_handling?1:0) << "\til:" << (int)cpu._interrupt_level;
	out << "\tci:" << (cpu._clock_interrupt?1:0) << "\tpo:" << (cpu._power_on?1:0);
	return out;
}
