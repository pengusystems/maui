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
	${REPO_EXT_BUILD_DIR}/grpc/build/install/include
	${REPO_LIBS_DIR}
	${REPO_EXT_DIR}
)
