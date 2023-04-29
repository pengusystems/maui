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
	${REPO_EXT_DIR}
	${REPO_EXT_DIR}/asio/include
)

# Link dependencies.
find_package(Threads)
target_link_libraries(serialport PRIVATE
	${CMAKE_THREAD_LIBS_INIT}
)

# Add the test executable
add_executable(serialport_test
	"serialport_test.cpp"
)
target_include_directories(serialport_test PRIVATE
	${REPO_LIBS_DIR}
)
target_link_libraries(serialport_test PRIVATE
	serialport
)