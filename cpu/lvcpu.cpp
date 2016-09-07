#include <iostream>
#include <cstdlib>
#include <fstream>
#include <string>
#include <utility>
#include <stdexcept>

#include "lua.hpp"
#include "mem.hpp"
#include "cpu.hpp"

#ifndef LVCPU_SYSCONF_PATH
	#define LVCPU_SYSCONF_PATH "/etc/lvcpu/conf"
#endif

using namespace std::string_literals;

namespace {
	struct Program_mode {
		double clock_rate;
		int memory_size;
		std::string input_path;
		std::string output_path;
		std::string bin_path;
		bool debug_mode;
		bool no_io_buff;
	};

	[[noreturn]] void conf_error(
		const std::string &reason,
		const std::string &lua_error = "",
		bool              abort = false)
	{
		std::cerr << "conf: " << reason;
		if (!lua_error.empty()) {
			std::cerr << "\nlua_error";
		}
		std::endl(std::cerr);
		if (abort) {
			std::abort();
		} else {
			std::exit(EXIT_FAILURE);
		}
	}

	bool conf_file_load(lua::State &lua_state, const std::string &conf)
	{
		const auto load_result = lua_state.load_file(conf);
		switch (load_result) {
		case static_cast<int>(lua::Status::ok):
			return true;
		case static_cast<int>(lua::Status::error_syntax):
			conf_error("Syntax error compiling " + conf);
		case static_cast<int>(lua::Status::error_mem):
			conf_error("Lua compiler ran out of memory", "", true);
		case static_cast<int>(lua::Status::error_gcmm):
			conf_error("Error in __gc metamethod during compilation");
		default:
			return false;
		}
	}

	std::string concat_args(const int argc, const char *const *const argv)
	{
		std::string cat_args;
		for (int i = 1; i < argc; ++i) {
			cat_args += argv[i];
			cat_args += " ";
		}
		return std::move(cat_args);
	}

	void args_load(
		lua::State               &lua_state,
		const int                argc,
		const char *const *const argv)
	{
		const auto args = concat_args(argc, argv);
		const auto load_result = lua_state.load_string(args);
		if (load_result != lua::Status::ok) {
			switch (load_result) {
			case lua::Status::error_syntax:
				conf_error("Syntax error");
			case lua::Status::error_mem:
				conf_error("Lua compiler ran out of memory", "", true);
			case lua::Status::error_gcmm:
				conf_error("Error in __gc metamethod during compilation");
			default:
				conf_error("Unrecognised compiler error", "", true);
			}
		}
	}

	void conf_run(lua::State &lua_state)
	{
		const auto call_result = lua_state.call(0, 0);
		if (call_result != lua::Status::ok) {
			const auto err = lua_state.to_string(-1);
			switch (call_result) {
			case lua::Status::error_runtime:
				conf_error("Runtime error", err);
			case lua::Status::error_mem:
				conf_error("Lua ran out of memory", err);
			case lua::Status::error_gcmm:
				conf_error("Error in __gc metamethod", err);
			default:
				conf_error("Unrecognised error", err, true);
			}
		}
	}

	double state_read_number(lua::State &lua_state, const std::string &name)
	{
		if (lua_state.get_global(name) == lua::Type::number) {
			double result = lua_state.to_number(-1);
			lua_state.pop();
			return result;
		}
		conf_error(name + " must be number");
	}

	int state_read_integer(lua::State &lua_state, const std::string &name)
	{
		if (lua_state.get_global(name) == lua::Type::number) {
			if (lua_state.is_integer(-1)) {
				int result = lua_state.to_integer(-1);
				lua_state.pop();
				return result;
			}
		}
		conf_error(name + " must be integer");
	}

	std::string state_read_string(lua::State &lua_state, const std::string &name)
	{
		if (lua_state.get_global(name) == lua::Type::string) {
			std::string result = lua_state.to_string(-1);
			lua_state.pop();
			return std::move(result);
		}
		conf_error(name + " must be string");
	}

	bool state_read_boolean(lua::State &lua_state, const std::string &name)
	{
		if (lua_state.get_global(name) == lua::Type::boolean) {
			bool result = lua_state.to_boolean(-1);
			lua_state.pop();
			return result;
		}
		conf_error(name + " must be boolean");
	}

	Program_mode state_read_mode(lua::State &lua_state)
	{
		Program_mode mode;
		mode.clock_rate  = state_read_number(lua_state, "clock_rate");
		mode.memory_size = state_read_integer(lua_state, "memory_size");
		mode.input_path  = state_read_string(lua_state, "input_path");
		mode.output_path = state_read_string(lua_state, "output_path");
		mode.bin_path    = state_read_string(lua_state, "bin_path");
		mode.debug_mode  = state_read_boolean(lua_state, "debug_mode");
		return std::move(mode);
	}

	Program_mode load_mode(const int argc, const char *const *const argv)
	{
		lua::State lua_state;
		lua_state.open_libs();
		if (!conf_file_load(lua_state, "lvcpu.conf") && !conf_file_load(lua_state, LVCPU_SYSCONF_PATH)) {
			std::cerr << "Warning: did not find any configuration files";
			std::endl(std::cerr);
		} else {
			conf_run(lua_state);
		}
		args_load(lua_state, argc, argv);
		conf_run(lua_state);
		return state_read_mode(lua_state);
	}

	void read_bin_file(Mem &system_mem, std::istream &bin_file)
	{
		for (std::uint16_t addr = 0; bin_file; ++addr) {
			char input_char;
			bin_file.get(input_char);
			system_mem.write(addr, input_char);
		}
	}
}

int main(const int argc, const char *const *const argv)
{
	Program_mode program_mode = load_mode(argc, argv);
	Mem system_mem;
	std::ifstream binary_file{program_mode.bin_path};
	if (!binary_file) {
		std::cerr << "Could not open binary file!";
		std::endl(std::cerr);
		return EXIT_FAILURE;
	}
	read_bin_file(system_mem, binary_file);
	binary_file.close();
	std::ifstream input_file{program_mode.input_path};
	std::ofstream output_file{program_mode.output_path};
	if (!input_file) {
		std::cerr << "Could not open input file!";
		std::endl(std::cerr);
		return EXIT_FAILURE;
	} else if (!output_file) {
		std::cerr << "Could not open output file!";
		std::endl(std::cerr);
		return EXIT_FAILURE;
	}
	CPU CPU_state{system_mem, program_mode.clock_rate, input_file, output_file};
	if (program_mode.debug_mode) {
		std::cerr << CPU_state;
		std::endl(std::cerr);
	}
	while (CPU_state.is_on()) {
		CPU_state.step();
		if (program_mode.debug_mode) {
			std::cerr << CPU_state;
			std::endl(std::cerr);
		}
		if (program_mode.no_io_buff) {
			std::flush(output_file);
		}
	}
}
