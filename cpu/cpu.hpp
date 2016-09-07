#ifndef LVCPU_CPU_HPP_INCLUDED
#define LVCPU_CPU_HPP_INCLUDED

#include <cstdint>
#include <chrono>
#include <iostream>

#include "mem.hpp"

class CPU {
	void         clock_tick();
	std::uint8_t instruction_fetch();

	void raise_interrupt(std::uint8_t interrupt_code);

	void bad_op_code();
	void bad_parameter();

	std::uint8_t    get_g8(std::uint8_t code);
	void            set_g8(std::uint8_t code, std::uint8_t value);
	std::uint16_t & get_g16(std::uint8_t code);
	std::uint16_t & get_r16(std::uint8_t code);

	void set_zero_flag(bool state = true);
	void set_carry_flag(bool state = true);
	bool get_zero_flag();
	bool get_carry_flag();

	void byte_op_nop();
	void byte_op_add(std::uint8_t op_code);
	void byte_op_sub(std::uint8_t op_code);
	void byte_op_inc_dec(std::uint8_t op_code);
	void byte_op_neg();
	void byte_op_bin(std::uint8_t op_code);
	void byte_op_shift(std::uint8_t op_code);
	void byte_op_mul();
	void byte_op_mov(std::uint8_t op_code);
	void byte_op_swp();
	void byte_op_jp(std::uint8_t op_code);
	void byte_op_call(std::uint8_t op_code);
	void byte_op_interrupt();
	void byte_op_ret(std::uint8_t op_code);
	void byte_op_mode_change(std::uint8_t op_code);
	void byte_op_input_output(std::uint8_t op_code);
	void byte_op_stop();

	void nibble_op_mov(std::uint8_t op_nibble, std::uint8_t op_param);
	void nibble_op_push(std::uint8_t op_nibble, std::uint8_t op_param);
	void nibble_op_pop(std::uint8_t op_nibble, std::uint8_t op_param);
	void nibble_op_add(std::uint8_t op_nibble, std::uint8_t op_param);

	struct General_registers {
		std::uint16_t a = 0, c = 0;
		std::uint8_t f = 0;
		std::uint16_t sp = 0, bp = 0;
	} _primary, _shadow;
	std::uint16_t _ip = 0;
	std::uint8_t _ic = 0, _t = 0;
	std::uint8_t _interrupt_level = 0;
	bool _interrupt_handling = false;
	bool _clock_interrupt = false;
	std::chrono::microseconds _clock_period;
	unsigned _clock_multiplier;
	unsigned _clock_multiplier_stage = 0;
	std::chrono::high_resolution_clock::time_point _next_tick;
	bool _power_on = true;
	Mem *_mem;
	std::istream *_input;
	std::ostream *_output;

	friend std::ostream & operator << (std::ostream &out, const CPU &cpu);

public:
	CPU(Mem &mem, double rate, std::istream &input, std::ostream &output);
	void step();
	bool is_on() const;
};

std::ostream & operator << (std::ostream &out, const CPU &cpu);

#endif // LVCPU_CPU_HPP_INCLUDED
