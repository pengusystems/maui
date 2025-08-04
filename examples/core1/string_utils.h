#ifndef _STRING_UTILS_H
#define _STRING_UTILS_H

#include <stdio.h>
#include <stdexcept>
#include <string>
#include <string_view>
#include <tuple>
#include <vector>
#include <memory>

namespace core1::string_utils {
	// Formats string like C printf but also works with std::string and std::string_view.
	// Disables format-security so we can have dynamic formats without warnings:
	// std::string fmt = get_user_input();
	// str_format(fmt.c_str(), foo, bar);
#ifdef __linux__
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wformat-security"
#endif
	template <typename... Args>
	std::string str_format(const std::string& fmt, Args&&... args) {
		// Make owned copies for string_view.
		auto owned = std::make_tuple(
			[&]() -> decltype(auto) {
				using T = std::decay_t<decltype(args)>;
				if constexpr (std::is_same_v<T, std::string_view>) return std::string(args);
				else return std::forward<Args>(args);
			}()...);

		// Map to printf-compatible types.
		auto to_printf_args = [](auto&&... vals) {
			return std::make_tuple(
				[](auto&& v) -> decltype(auto) {
					using T = std::decay_t<decltype(v)>;
					if constexpr (std::is_same_v<T, std::string>) return v.c_str();
					else return v;
				}(vals)...);
		};
		auto printf_args = std::apply(to_printf_args, owned);

		// Find the size (add 1 for '\0').
		size_t size = std::apply([&](auto&&... a) { return std::snprintf(nullptr, 0, fmt.c_str(), a...) + 1; }, printf_args);
		if (size <= 0) {
#if defined(WIN32) || defined(__linux__)
			throw std::runtime_error("Error during formatting.");
#endif
		}

		// The actual formatting.
		std::unique_ptr<char[]> buf(new char[size]);
		std::apply([&](auto&&... a) { std::snprintf(buf.get(), size, fmt.c_str(), a...); }, printf_args);

		// We don't want the '\0' inside.
		return std::string(buf.get(), buf.get() + size - 1);
	}
#ifdef __linux__
#pragma GCC diagnostic pop
#endif

	// Case insensitive string comparison.
	bool iequals(const std::string& a, const std::string& b);

	// Change string to lower case.
	void to_lower(std::string& s);

	// Change string to upper case.
	void to_upper(std::string& s);

	// Convert string to raw string.
	std::string to_raw_string(const std::string& s);

	// Convert string to double (throws if the input string is invalid).
	double to_double(const std::string& s, const bool ignore_trailing_line_breaks = true);

	// Convert a string of bytes in hex format to a vector byte array. Each byte must be formatted with exactly to characters (throws if the input string is invalid).
	// For example: "4869" will return a vector of chars which contains {0x48, 0x69} (Hi in ascii).
	std::vector<char> hex_to_bytes(const std::string& hex_string);

	// Convert an array of bytes to string in hex format.
	std::string bytes_to_hex(const char* bytes, const size_t& len);

	// Splits a delimited string to a vector of strings.
	std::vector<std::string> split_string(const std::string& s, const std::string& delimiter);
}
#endif
