#include "lua.hpp"

#include <string>
#include <cassert>
#include <cstdlib>
#include <iostream>

extern "C" {
#include <lualib.h>
#include <lauxlib.h>
}

namespace lua {
	State::State() :
		_state{::luaL_newstate()}
	{}

	State::~State()
	{
		::lua_close(_state);
	}

	void State::open_libs()
	{
		::luaL_openlibs(_state);
	}

	Status State::load_string(const std::string &source)
	{
		return static_cast<Status>(
			::luaL_loadstring(_state, source.c_str())
		);
	}

	int State::load_file(const std::string &source)
	{
		return ::luaL_loadfile(_state, source.c_str());
	}

	int State::load_file()
	{
		return ::luaL_loadfile(_state, nullptr);
	}

	Status State::call(
		const int n_args,
		const int n_results)
	{
		#ifndef NDEBUG
			if (n_results == LUA_MULTRET) {
				std::cerr << "Use LUA_MULTRET with the State::call(int) overload";
				std::endl(std::cerr);
				std::abort();
			}
		#endif
		return static_cast<Status>(
			::lua_pcall(_state, n_args, n_results, 0)
		);
	}

	Status State::call(const int n_args)
	{
		return static_cast<Status>(
			::lua_pcall(_state, n_args, LUA_MULTRET, 0)
		);
	}

	Type State::get_global(const std::string &name)
	{
		return static_cast<Type>(
			::lua_getglobal(_state, name.c_str())
		);
	}

	Number State::to_number(const int stack_index)
	{
		return ::lua_tonumber(_state, stack_index);
	}

	Integer State::to_integer(const int stack_index)
	{
		return ::lua_tointeger(_state, stack_index);
	}

	bool State::is_integer(const int stack_index)
	{
		return ::lua_isinteger(_state, stack_index);
	}

	std::string State::to_string(const int stack_index)
	{
		return ::lua_tostring(_state, stack_index);
	}

	void State::pop(const int amount)
	{
		::lua_pop(_state, amount);
	}
}
