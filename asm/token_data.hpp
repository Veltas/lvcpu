#ifndef LVASM_TOKEN_DATA_HPP_INCLUDED
#define LVASM_TOKEN_DATA_HPP_INCLUDED

#include "source_data.hpp"

#include <string>
#include <cstddef>
#include <vector>
#include <unordered_map>

class Token_data: public Source_data {
public:
	class Syntax_error: std::runtime_error {
		Range _where;
	public:
		Syntax_error(const std::string &what, const Range &where);
		virtual const Range & where() const;
		~Syntax_error() override;
	};
	struct Token {
		enum class Type {
			punctuator,
			string,
			character,
			identifier,
			directive_name,
			integer
		} tag;
		union Contents {
			char punctuator = '0';
			std::string string;
			char character;
			std::string identifier;
			std::string directive_name;
			int integer;
			Contents();
			~Contents();
		} contents;
		Token();
		Token(const Token &tok);
		Token(Token &&tok);
		explicit Token(Type new_tag, char data);
		explicit Token(Type new_tag, int data);
		explicit Token(Type new_tag, const std::string &data);
		~Token();
	};

	using File_token = std::pair<Token, Range>;

private:
	std::vector<File_token> _tokens;

	void tidy_comments(std::vector<std::string> &source);
	void tidy_strings(
		std::vector<std::string>                     &source,
		std::unordered_map<std::size_t, std::size_t> &string_lines,
		std::vector<Range>                           &string_ranges
	);
	void process_line(const std::string &line, const std::size_t line_n);

public:
	Token_data(const std::string &root_filename);
	const Token & get_token(std::size_t n) const;
	const Range & get_token_range(std::size_t n) const;
	std::size_t   get_n_tokens() const;
};

#endif // LVASM_TOKEN_DATA_HPP_INCLUDED
