#include "source_data.hpp"

#include <list>
#include <iostream>
#include <fstream>
#include <stdexcept>
#include <regex>

namespace fs = std::experimental::filesystem;

std::vector<Source_data::Source_line> Source_data::load_file(
	const fs::path &file_path)
{
	// Avoid nesting
	if (
		std::find(_source_paths.begin(), _source_paths.end(), file_path)
		!= _source_paths.end()
	) {
		return {};
	}
	_source_paths.emplace_back(file_path);
	const auto *const file_p = &_source_paths.back();
	// Open file
	std::ifstream in_file(file_path.native());
	if (!in_file.is_open()) {
		throw std::runtime_error{"Unable to load " + file_path.native()};
	}
	// Collect lines
	std::vector<Source_line> result;
	while (in_file) {
		std::string current_line;
		std::getline(in_file, current_line);
		const std::regex include_regex(
			"^\\s*\\.include\\s*\"([^\"]+)\"\\s*(?:;.*|)$"
		);
		std::smatch include_match;
		// Handle .include lines recursively
		if (std::regex_match(current_line, include_match, include_regex)) {
			const std::string filename(
				include_match[1].first,
				include_match[1].second
			);
			auto included_source = load_file(
				fs::absolute(file_path.parent_path() / filename)
			);
			result.reserve(result.size() + included_source.size());
			for (auto &included_line: included_source) {
				result.emplace_back(std::move(included_line));
			}
		} else {
			result.emplace_back(file_p, std::move(current_line));
		}
	}
	return result;
}

Source_data::Source_data(const std::string &root_filename) :
	_lines(load_file(fs::current_path() / root_filename))
{}

namespace {
	void source_range_check(const std::size_t index, const std::size_t size)
	{
		if (index >= size)
			throw std::out_of_range{"Source_data logic error, range check failed"};
	}

	std::string get_substring(
		const std::string &str,
		const std::size_t i1)
	{
		source_range_check(i1, str.size());
		return std::string(str.begin() + i1, str.end());
	}

	std::string get_substring(
		const std::string &str,
		const std::size_t i1,
		const std::size_t i2)
	{
		source_range_check(i1, str.size());
		source_range_check(i2, str.size());
		return std::string(str.begin() + i1, str.begin() + i2 + 1);
	}
}

std::string Source_data::get_range(const Range &range) const
{
	const auto &start = range.start, &end = range.end;
	if (
		start.line_n > end.line_n ||
		(start.line_n == end.line_n && start.col_n > end.col_n)
	) {
		return std::string();
	} else if (start.line_n == end.line_n) {
		const auto &line = _lines.at(start.line_n).second;
		return get_substring(line, start.col_n, end.col_n);
	} else {
		std::string result;
		result += get_substring(_lines.at(start.line_n).second, start.col_n);
		for (std::size_t i = 1; i < end.line_n - start.line_n; ++i) {
			result += '\n' + _lines.at(start.line_n).second;
		}
		result += '\n' + get_substring(_lines.at(end.line_n).second, 0, end.col_n);
		return result;
	}
}

char Source_data::get_char(const Position &pos) const
{
	return _lines.at(pos.line_n).second.at(pos.col_n);
}

const fs::path & Source_data::get_path(const Position &pos) const
{
	return *_lines.at(pos.line_n).first;
}

const std::string & Source_data::get_line(const std::size_t line_n) const
{
	return _lines.at(line_n).second;
}

std::vector<std::string> Source_data::get_source() const
{
	std::vector<std::string> result;
	result.reserve(_lines.size());
	for (auto &line: _lines) {
		result.emplace_back(line.second);
	}
	return result;
}

std::size_t Source_data::n_lines() const
{
	return _lines.size();
}
