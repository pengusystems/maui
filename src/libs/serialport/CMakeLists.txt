# This is a shared library.
file(GLOB LIB_SRC_FILES
	"serialport.h"
	"serialport.cpp"
)
add_library(serialport SHARED
	${LIB_SRC_FILES}
)

# Includes.
target_include_directories(serialport PRIVATE
	${REPO_LIBS_DIR}
	${REPO_EXT_BUILD_DIR}/asio/
	${REPO_EXT_BUILD_DIR}/asio/asio/include/
)

# Link dependencies.
find_package(Threads)
target_link_libraries(serialport PRIVATE
	${CMAKE_THREAD_LIBS_INIT}
)

# Micro utility for interfacing a serial port.
add_executable(attocom
	"attocom.cpp"
)
target_include_directories(attocom PRIVATE
	${REPO_LIBS_DIR}
)
target_link_libraries(attocom PRIVATE
	serialport
)
