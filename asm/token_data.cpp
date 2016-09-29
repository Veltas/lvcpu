#include "token_data.hpp"

#include <memory>
#include <stdexcept>
#include <unordered_set>
#include <regex>

using namespace std::string_literals;

Token_data::Syntax_error::Syntax_error(
	const std::string &what,
	const Token_data::Range &where
) :
	runtime_error(what),
	_where(where)
{}

const Token_data::Range & Token_data::Syntax_error::where() const
{
	return _where;
}

Token_data::Syntax_error::~Syntax_error()
{}

Token_data::Token::Contents::Contents()
{}

Token_data::Token::Contents::~Contents()
{}

Token_data::Token::Token()
{}

namespace {
	template <class T>
	inline void placement_destroy(T &obj)
	{
		obj.~T();
	}
}

Token_data::Token::Token(const Token &tok)
{
	if (tok.tag == Type::punctuator) {
		contents.punctuator = tok.contents.punctuator;
	} else {
		placement_destroy(contents.punctuator);
		switch (tok.tag) {
		case Type::string:
			new (&contents.string) std::string(tok.contents.string);
			break;
		case Type::character:
			new (&contents.character) char(tok.contents.character);
			break;
		case Type::identifier:
			new (&contents.identifier) std::string(tok.contents.identifier);
			break;
		case Type::directive_name:
			new (&contents.directive_name) std::string(tok.contents.directive_name);
			break;
		case Type::integer:
			new (&contents.integer) int(tok.contents.integer);
			break;
		case Type::punctuator:
			throw std::logic_error("Token::Token unreachable line");
		}
		tag = tok.tag;
	}
}

Token_data::Token::Token(Token &&tok)
{
	if (tok.tag == Type::punctuator) {
		contents.punctuator = tok.contents.punctuator;
	} else {
		placement_destroy(contents.punctuator);
		switch (tok.tag) {
		case Type::string:
			new (&contents.string) std::string(std::move(tok.contents.string));
			break;
		case Type::character:
			new (&contents.character) char(std::move(tok.contents.character));
			break;
		case Type::identifier:
			new (&contents.identifier) std::string(
				std::move(tok.contents.identifier)
			);
			break;
		case Type::directive_name:
			new (&contents.directive_name) std::string(
				std::move(tok.contents.directive_name)
			);
			break;
		case Type::integer:
			new (&contents.integer) int(std::move(tok.contents.integer));
		case Type::punctuator:
			throw std::logic_error("Token::Token unreachable line");
		}
		tag = tok.tag;
	}
}

Token_data::Token::Token(const Type new_tag, const char data)
{
	if (new_tag == Type::punctuator) {
		contents.punctuator = data;
	} else if (new_tag == Type::character) {
		placement_destroy(contents.punctuator);
		new (&contents.character) char(data);
	} else {
		throw std::domain_error("Token_data::Token(Type,char): bad tag");
	}
}

Token_data::Token::Token(const Type new_tag, const int data)
{
	if (new_tag == Type::integer) {
		placement_destroy(contents.punctuator);
		new (&contents.integer) int(data);
	} else {
		throw std::domain_error("Token_data::Token(Type,int): bad tag");
	}
}

Token_data::Token::Token(const Type new_tag, const std::string &data)
{
	if (new_tag == Type::string) {
		placement_destroy(contents.punctuator);
		new (&contents.string) std::string(data);
	} else if (new_tag == Type::identifier) {
		placement_destroy(contents.punctuator);
		new (&contents.identifier) std::string(data);
	} else if (new_tag == Type::directive_name) {
		placement_destroy(contents.punctuator);
		new (&contents.directive_name) std::string(data);
	} else {
		throw std::domain_error("Token_data::Token(Type,string): bad tag");
	}
}

Token_data::Token::~Token()
{
	switch (tag) {
	case Type::string:
		placement_destroy(contents.string);
		break;
	case Type::identifier:
		placement_destroy(contents.identifier);
		break;
	case Type::directive_name:
		placement_destroy(contents.directive_name);
		break;
	case Type::punctuator:
		break;
	case Type::character:
		break;
	case Type::integer:
		break;
	}
}

void Token_data::tidy_comments(std::vector<std::string> &source)
{
	for (auto &line: source) {
		static const std::regex comment_regex(";.*");
		std::smatch comment_match;
		if (std::regex_search(line, comment_match, comment_regex)) {
			static const std::regex replace_regex("\\S");
			std::string result(line.size(), ' ');
			std::regex_replace(
				result.begin(),
				comment_match[0].first,
				line.cend(),
				replace_regex,
				" "
			);
			line = result;
		}
	}
}

namespace {
	Token_data::File_token process_directive(
		const std::size_t line_n,
		const std::string &line,
		const std::smatch &match)
	{
		const std::string directive_name(match[1].first, match[1].second);
		static const std::unordered_set<std::string> directive_names = {
			"org",
			"absolute",
			"include"
		};
		if (directive_names.count(directive_name)) {
			const Token_data::Range where = {
				{line_n, (std::size_t)(match[1].first - line.begin() - 1)},
				{line_n, (std::size_t)(match[1].second - line.begin() - 1)}
			};
			return {
				Token_data::Token(
					Token_data::Token::Type::directive_name,
					directive_name
				),
				where
			};
		} else {
			const Token_data::Range where = {
				{line_n, (std::size_t)(match[1].first - line.begin())},
				{line_n, (std::size_t)(match[1].second - line.begin() - 1)}
			};
			throw Token_data::Syntax_error("Unrecognized directive", where);
		}
	}

	Token_data::File_token process_identifier(
		const std::size_t line_n,
		const std::string &line,
		const std::smatch &match)
	{
		const std::string identifier(match[2].first, match[2].second);
		const Token_data::Range where = {
			{line_n, (std::size_t)(match[2].first - line.begin())},
			{line_n, (std::size_t)(match[2].second - line.begin() - 1)}
		};
		return {
			Token_data::Token(Token_data::Token::Type::identifier, identifier),
			where
		};
	}

	Token_data::File_token process_integer(
		const std::size_t line_n,
		const std::string &line,
		const std::smatch &match)
	{
		const std::string integer_string(match[3].first, match[3].second);
		const Token_data::Range where = {
			{line_n, (std::size_t)(match[3].first - line.begin())},
			{line_n, (std::size_t)(match[3].second - line.begin() - 1)}
		};
		if (match[4].matched) {
			return {
				Token_data::Token(
					Token_data::Token::Type::integer,
					std::stoi(integer_string, nullptr, 0)
				),
				where
			};
		} else if (match[5].matched) {
			return {
				Token_data::Token(
					Token_data::Token::Type::integer,
					std::stoi(integer_string)
				),
				where
			};
		} else {
			throw std::invalid_argument("process_integer: bad argument");
		}
	}

	Token_data::File_token process_char(
		const std::size_t line_n,
		const std::string &line,
		const std::smatch &match)
	{
		if (match[6].matched) {
			const Token_data::Range where = {
				{line_n, (std::size_t)(match[6].first - line.begin() - 2)},
				{line_n, (std::size_t)(match[6].second - line.begin())}
			};
			const char matched_char = *match[6].first;
			static const std::unordered_map<char, char> replace_chars = {
				{'n', '\n'},
				{'t', '\t'},
				{'b', '\b'},
				{'\\', '\\'}
			};
			const auto found_char = replace_chars.find(matched_char);
			if (found_char != replace_chars.end()) {
				return {
					Token_data::Token(
						Token_data::Token::Type::character,
						found_char->second
					),
					where
				};
			} else {
				throw Token_data::Syntax_error(
					"Unrecognized escape sequence in character literal",
					where
				);
			}
		} else if (match[7].matched) {
			const Token_data::Range where = {
				{line_n, (std::size_t)(match[7].first - line.begin() - 1)},
				{line_n, (std::size_t)(match[7].second - line.begin())}
			};
			const char matched_char = *match[7].first;
			return {
				Token_data::Token(Token_data::Token::Type::character, matched_char),
				where
			};
		} else {
			throw std::invalid_argument("process_char: bad argument");
		}
	}

	Token_data::File_token process_string(
		const std::size_t line_n,
		const std::string &line,
		const std::smatch &match)
	{
		const Token_data::Range where = {
			{line_n, (std::size_t)(match[8].first - line.begin() - 1)},
			{line_n, (std::size_t)(match[8].second - line.begin())}
		};
		static const std::regex escape_regex("\\\\(.)");
		std::match_results<std::string::iterator> escape_match;
		auto line_c = line;
		auto search_pos = line_c.begin() + where.start.col_n + 1;
		auto escape_count = 0;
		while (std::regex_search(
			line_c.begin() + (match[8].first - line.begin()),
			line_c.end(),
			escape_match,
			escape_regex
		)) {
			const auto escape_char = *escape_match[1].first;
			static const std::unordered_map<char, char> replace_chars = {
				{'n', '\n'},
				{'t', '\t'},
				{'b', '\b'},
				{'\\', '\\'}
			};
			const auto replace_char = replace_chars.find(escape_char);
			if (replace_char != replace_chars.end()) {
				*escape_match[1].first = replace_char->second;
			} else {
				const Token_data::Range where = {
					{line_n, (std::size_t)(escape_match[1].first - line_c.begin() - 2)},
					{line_n, (std::size_t)(escape_match[1].second - line_c.begin())}
				};
				throw Token_data::Syntax_error(
					"Unrecognized character escape `\\"s + replace_char->second + "`",
					where
				);
			}
			search_pos = escape_match[1].second;
			++escape_count;
		}
		static const std::regex slash_regex("\\\\(.)");
		const auto plain_string = std::regex_replace(line_c, slash_regex, "\\1");
		return {
			Token_data::Token(
				Token_data::Token::Type::string,
				std::string(
					plain_string.begin() + where.start.col_n,
					plain_string.begin() + where.end.col_n - escape_count
				)
			),
			where
		};
	}

	Token_data::File_token process_punctuator(
		const std::size_t line_n,
		const std::string &line,
		const std::smatch &match)
	{
		const Token_data::Range where = {
			{line_n, (std::size_t)(match[9].first - line.begin())},
			{line_n, (std::size_t)(match[9].second - line.begin() - 1)}
		};
		const auto character = *match[9].first;
		return {
			Token_data::Token(Token_data::Token::Type::punctuator, character),
			where
		};
	}

	[[noreturn]] Token_data::File_token process_illegal(
		const std::size_t line_n,
		const std::string &line,
		const std::smatch &match)
	{
		const Token_data::Range where = {
			{line_n, (std::size_t)(match[10].first - line.begin())},
			{line_n, (std::size_t)(match[10].first - line.begin())}
		};
		throw Token_data::Syntax_error(
			"Unexpected character `"s + *match[10].first + "`",
			where
		);
	}
}

void Token_data::process_line(
	const std::string &line,
	const std::size_t line_n)
{
	static const std::regex token_regex(
		"^\\s*(?:"
			"\\.([_[:alpha:]]\\w*)|"             // match directive:  1
			"([_[:alpha:]]\\w*)|"                // match identifier: 2
			"((0[xX][a-fA-F0-9]+)|([1-9]\\d*))|" // match integer:    3, 4, 5
			"'(?:\\\\(.)|([^']))'|"              // match char:       6, 7
			"\"((?:\\\\.|[^\"])*)\"|"            // match string:     8
			"([\\[\\],+\\-])|"                   // match punctuator: 9
			"(\\S)"                              // match illegal:    10
		")"
	);
	std::smatch match;
	auto search_pos = line.begin();
	while (std::regex_search(search_pos, line.end(), match, token_regex)) {
		if (match[1].matched) {
			_tokens.emplace_back(process_directive(line_n, line, match));
		} else if (match[2].matched) {
			_tokens.emplace_back(process_identifier(line_n, line, match));
		} else if (match[3].matched || match[4].matched || match[5].matched) {
			_tokens.emplace_back(process_integer(line_n, line, match));
		} else if (match[6].matched || match[7].matched) {
			_tokens.emplace_back(process_char(line_n, line, match));
		} else if (match[8].matched) {
			_tokens.emplace_back(process_string(line_n, line, match));
		} else if (match[9].matched) {
			_tokens.emplace_back(process_punctuator(line_n, line, match));
		} else if (match[10].matched) {
			_tokens.emplace_back(process_illegal(line_n, line, match));
		} else {
			throw std::logic_error("Token_data::process_line unreachable logic");
		}
		search_pos = match[1].second;
	}
}

Token_data::Token_data(const std::string &root_filename) :
	Source_data(root_filename)
{
	// Working on local copy of source
	std::vector<std::string> source(get_source());
	const auto n_lines = source.size();
	tidy_comments(source);
	// Generate token data
	for (std::size_t line_n = 0; line_n < n_lines; ++line_n) {
		process_line(source[line_n], line_n);
	}
}

const Token_data::Token & Token_data::get_token(std::size_t n) const
{
	return _tokens.at(n).first;
}

const Token_data::Range & Token_data::get_token_range(std::size_t n) const
{
	return _tokens.at(n).second;
}

std::size_t Token_data::get_n_tokens() const
{
	return _tokens.size();
}
