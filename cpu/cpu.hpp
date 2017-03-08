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
	void byte_op_add_g8();
	void byte_op_add_r16();
	void byte_op_sub_g8();
	void byte_op_sub_r16();
	void byte_op_inc();
	void byte_op_dec();
	void byte_op_neg();
	void byte_op_and();
	void byte_op_or();
	void byte_op_xor();
	void byte_op_shift();
	void byte_op_rotate();
	void byte_op_mul();
	void byte_op_mov_g8_g8();
	void byte_op_mov_r16_r16();
	void byte_op_mov_getmisc();
	void byte_op_mov_al_bp_ptr();
	void byte_op_mov_al_c_ptr();
	void byte_op_mov_bp_ptr_al();
	void byte_op_mov_c_ptr_al();
	void byte_op_mov_a_bp_ptr();
	void byte_op_mov_a_c_ptr();
	void byte_op_mov_al_t();
	void byte_op_mov_t_al();
	void byte_op_mov_bp_ptr_a();
	void byte_op_mov_c_ptr_a();
	void byte_op_swp();
	void byte_op_jp();
	void byte_op_jz();
	void byte_op_jc();
	void byte_op_jnz();
	void byte_op_jnc();
	void byte_op_call_n16();
	void byte_op_call_a();
	void byte_op_interrupt();
	void byte_op_ret();
	void byte_op_reti();
	void byte_op_eih();
	void byte_op_dih();
	void byte_op_eci();
	void byte_op_dci();
	void byte_op_esi();
	void byte_op_dsi();
	void byte_op_in();
	void byte_op_out();
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
