#include <cstdarg>
#include <stdio.h>
#include <locale>
#include <sstream>
#include <iomanip>
#include <algorithm>
#include <vector>
#include <cctype>
#include "string_utils.h"

namespace core1::string_utils {
	bool iequals(const std::string& a, const std::string& b) {
		return std::equal(a.begin(), a.end(), b.begin(), b.end(),
			[](char a, char b) {
				return tolower(a) == tolower(b);
			});
	}

	void to_lower(std::string& s) {
		std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c){ return std::tolower(c); });
	}

	void to_upper(std::string& s) {
		std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c){ return std::toupper(c); });
	}

	std::string to_raw_string(const std::string& s) {
		std::string ret = s;
		std::vector<std::string> to_escape = {"\n", "\r"};
		std::vector<std::string> escape_with = {"\\n", "\\r"};
		int index = 0;
		for (auto& it : to_escape) {
			auto p = ret.find(it);
			while (p != std::string::npos) {
				ret.replace(p, 1, escape_with[index]);
				p = ret.find(it);
			}
			index++;
		}
		return ret;
	}

	double to_double(const std::string& s, const bool ignore_trailing_line_breaks) {
		auto str_to_convert = s;
		if (ignore_trailing_line_breaks) {
			while ((str_to_convert.back() == '\r') || (str_to_convert.back() == '\n')) {
				str_to_convert.erase(str_to_convert.size() - 1);
			}
		}
		std::size_t pos;
		auto ret = std::stod(str_to_convert, &pos);
		if (pos < str_to_convert.size()) {
			throw std::invalid_argument("Invalid string");
		}
		return ret;
	}

	std::vector<char> hex_to_bytes(const std::string& hex_string) {
		std::vector<char> byte_vec;
		constexpr auto chars_in_byte = 2;
		if ((hex_string.size() % chars_in_byte) != 0) {
			throw std::invalid_argument("Invalid string");
		}

		// If there is 0x at the beginning, skip it.
		size_t start_index = 0;
		if (hex_string.size() >= 2) {
			if ((hex_string[0] == '0') && (hex_string[1] == 'x')) {
				start_index = 2;
			}
		}

		for (auto ii = start_index; ii < hex_string.length(); ii = ii + chars_in_byte) {
			std::string temp_str = hex_string.substr(ii, chars_in_byte);
			constexpr auto hex_base = 16;
			char temp_byte = static_cast<char>(strtol(temp_str.c_str(), nullptr, hex_base));
			byte_vec.push_back(temp_byte);
		}
		return byte_vec;
	}

	std::string bytes_to_hex(const char* bytes, const size_t& len) {
		std::stringstream ss;
		for(size_t ii = 0; ii < len; ii++) {
			ss << std::hex << std::nouppercase << std::setw(2) << std::setfill('0') << (static_cast<unsigned int>(bytes[ii]) & 0xff);
		}
		return ss.str();
	}

	std::vector<std::string> split_string(const std::string& s, const std::string& delimiter) {
		std::vector<std::string> result;
		if (delimiter.empty()) return result;
		size_t start = 0, end;
		try {
			while ((end = s.find(delimiter, start)) != std::string::npos) {
				result.push_back(s.substr(start, end - start));
				start = end + delimiter.length();
			}
			result.push_back(s.substr(start)); // Add the last part.
		}
		catch (...) {
			// If an exception occurs, return what has been processed so far.
			return result;
		}
		return result;
	}
}
