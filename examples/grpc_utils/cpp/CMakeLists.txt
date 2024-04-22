# Configure grpc stuff.
include(${REPO_CMAKE_SCRIPTS_DIR}/grpc_config.cmake)
grpc_config()

# This is an interface library.
file(GLOB SRC_FILES
	"*.h"
	"*.hpp"
)
add_library(grpc_utils INTERFACE
	${SRC_FILES}
)

# Includes.
target_include_directories(grpc_utils INTERFACE
	${GRPC_INCLUDE_DIRS}
	${REPO_LIBS_DIR}
	${REPO_EXT_DIR}
)
