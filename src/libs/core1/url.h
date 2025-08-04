#ifndef _URL_H
#define _URL_H

#include <string>

namespace core1::url {
	std::string encode(const std::string& s);
	std::string decode(const std::string& s);
}
#endif
