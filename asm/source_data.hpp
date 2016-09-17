#ifndef LVASM_SOURCE_DATA_HPP_INCLUDED
#define LVASM_SOURCE_DATA_HPP_INCLUDED

#include <cstddef>
#include <string>
#include <vector>
#include <deque>
#include <experimental/filesystem>
#include <utility>

class Source_data {
	using Source_line = std::pair<
		const std::experimental::filesystem::path *,
		std::string
	>;

	std::deque<std::experimental::filesystem::path> _source_paths;
	std::vector<Source_line>                        _lines;

	std::vector<Source_line> load_file(
		const std::experimental::filesystem::path &filename
	);

public:
	struct Position {
		std::size_t line_n, col_n;
	};
	struct Range {
		Position start, end;
	};

	Source_data(const std::string &root_filename);

	std::string         get_range(const Range &range) const;
	char                get_char(const Position &pos) const;
	const std::experimental::filesystem::path &
	                    get_path(const Position &pos) const;
	const std::string & get_line(std::size_t n_line) const;
	std::size_t         n_lines() const;
};

#endif // LVASM_SOURCE_DATA_HPP_INCLUDED
