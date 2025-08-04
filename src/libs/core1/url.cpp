#include <sstream>
#include <iomanip>
#include "url.h"

namespace core1::url {
	std::string encode(const std::string& str) {
		std::ostringstream encoded;
		for (char c : str) {
			if (std::isalnum(static_cast<unsigned char>(c)) || c == '-' || c == '_' || c == '.' || c == '~') {
				// Unreserved characters are added as-is.
				encoded << c;
			}
			else if (c == ' ') {
				// Space is converted to '+'.
				encoded << '+';
			}
			else {
				// All other characters are percent-encoded.
				encoded << '%' << std::uppercase << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(static_cast<unsigned char>(c));
			}
		}
		return encoded.str();
	}

	std::string decode(const std::string& str) {
		std::string result;
		size_t i = 0;
		while (i < str.length()) {
			if (str[i] == '%') {
				// Ensure there are at least two characters following the '%'.
				if (i + 2 >= str.length()) {
					return "";
				}

				// Extract the next two characters.
				char hex_char1 = str[i + 1];
				char hex_char2 = str[i + 2];

				// Ensure both characters are valid hex digits.
				if (!std::isxdigit(hex_char1) || !std::isxdigit(hex_char2)) {
					return "";
				}

				// Convert the hex pair to a single character.
				int decoded_char = std::stoi(str.substr(i + 1, 2), nullptr, 16);
				result += static_cast<char>(decoded_char);

				// Skip the percent and the two hex digits.
				i += 3;
			}
			else if (str[i] == '+') {
				// Replace '+' with space.
				result += ' ';
				++i;
			}
			else {
				// Append the character as is.
				result += str[i];
				++i;
			}
		}
		return result;
	}
}
