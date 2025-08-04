#include <iostream>
#if defined(_WIN32)
#include <windows.h>
#elif defined(__APPLE__)
#include <mach-o/dyld.h>
#elif defined(__linux__)
#include <unistd.h>
#endif
#include "file_utils.h"

namespace core1::file_utils {
	std::string get_exec_path() {
		char path[2048];
#if defined(_WIN32)
	DWORD size = GetModuleFileNameA(NULL, path, sizeof(path));
	if (size == 0 || size == sizeof(path))
		return "";
#elif defined(__APPLE__)
	uint32_t size = sizeof(path);
	if (_NSGetExecutablePath(path, &size) != 0)
		return "";
#elif defined(__linux__)
		ssize_t size = readlink("/proc/self/exe", path, sizeof(path) - 1);
		if (size == -1) return "";
		path[size] = '\0';
#endif
		return std::string(path);
	}
}
