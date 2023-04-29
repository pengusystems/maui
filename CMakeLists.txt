cmake_minimum_required(VERSION 3.20)
project(maui)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_DEBUG_POSTFIX "" CACHE STRING "" FORCE)
mark_as_advanced(CMAKE_DEBUG_POSTFIX)
#set(CMAKE_FIND_DEBUG_MODE TRUE) # uncomment to show path included in search of popular find_* commands, requires cmake 3.18 or newer.

# Append __cplusplus to correctly identify c++ version in msvc.
# In debug mode only (msvc), replace Debug information flag /Zi with /ZI to allow Edit & Continue (C++ & x86/x64 only): https://docs.microsoft.com/en-us/cpp/build/reference/z7-zi-zi-debug-information-format?view=msvc-160
if(MSVC)
	string(APPEND CMAKE_CXX_FLAGS " /Zc:__cplusplus")
	string(REPLACE "/Zi" "/ZI" CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG}")
endif()

# Disable -Wlogical-op-parentheses, it's vioated all the time
# Add color diagnostics--for some reason this isn't the default for ninja generators
# Add -fPIC to allow linking a static library into a shared one (https://wiki.gentoo.org/wiki/Project:AMD64/Fixing_-fPIC_Errors_Guide).
# Add thread library.
if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-logical-op-parentheses -fcolor-diagnostics")
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC")
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pthread")
endif()
if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fdiagnostics-color=always")
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC")
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pthread")
endif()

# Be pedantic with warnings and errors (in practice this is very difficult to achieve).
if (MSVC)
	#add_compile_options(/W4 /WX)
else()
	#add_compile_options(-Wall -Wextra -Wpedantic -Werror)
endif()

# Configure output directories.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_NO_CONFIG ${CMAKE_BINARY_DIR}/x64/)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/x64/$<CONFIG>)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/x64/$<CONFIG>)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/x64/$<CONFIG>)
set(CMAKE_INSTALL_PREFIX ${CMAKE_BINARY_DIR}/install)

# Add custom cmake functions.
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

# On Linux, set the linux run path to be relative and at the same path of the executable.
# https://gitlab.kitware.com/cmake/community/-/wikis/doc/cmake/RPATH-handling
# https://stackoverflow.com/questions/57915564/cmake-how-to-set-rpath-to-origin-with-cmake
if (UNIX)
	set(CMAKE_SKIP_BUILD_RPATH FALSE)
	set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE)
	set(CMAKE_INSTALL_RPATH "$\{ORIGIN\}")
endif (UNIX)

# Repo global path directories
set(REPO_EXT_DIR ${CMAKE_SOURCE_DIR}/ext)
set(REPO_LIBS_DIR ${CMAKE_SOURCE_DIR}/examples)
set(REPO_EXT_BUILD_DIR ${CMAKE_BINARY_DIR}/../../ext)

# This will export functions to shared libraries (only relevant on Windows)
add_compile_definitions(
	DLL_EXPORT
)

# Add subdirectories.
add_subdirectory(./examples)
add_subdirectory(./ext)
