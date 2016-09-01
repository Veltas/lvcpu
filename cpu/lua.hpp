#ifndef LVCPU_LUA_HPP_INCLUDED
#define LVCPU_LUA_HPP_INCLUDED

#include <string>

extern "C" {
#include <lua.h>
}

namespace lua {
	typedef ::lua_Integer Integer;
	typedef ::lua_Number Number;

	enum class Status {
		ok = LUA_OK,
		error_syntax = LUA_ERRSYNTAX,
		error_runtime = LUA_ERRRUN,
		error_mem = LUA_ERRMEM,
		error_gcmm = LUA_ERRGCMM
	};

	enum class Type {
		none = LUA_TNONE,
		nil = LUA_TNIL,
		number = LUA_TNUMBER,
		boolean = LUA_TBOOLEAN,
		string = LUA_TSTRING,
		table = LUA_TTABLE,
		function = LUA_TFUNCTION,
		userdata = LUA_TUSERDATA,
		thread = LUA_TTHREAD,
		light_userdata = LUA_TLIGHTUSERDATA
	};

	class State {
		::lua_State *_state;
	public:
		State();
		~State();
		void open_libs();
		Status load_string(const std::string &source);
		int load_file(const std::string &source);
		int load_file();
		Status call(int n_args, int n_results);
		Status call(int n_args);
		Type get_global(const std::string &name);
		Number to_number(int stack_index);
		Integer to_integer(int stack_index);
		bool is_integer(int stack_index);
		std::string to_string(int stack_index);
		void pop(int amount = 1);
	};
}

#endif // LVCPU_LUA_HPP_INCLUDED
