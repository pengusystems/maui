# This is a static library.
file(GLOB SRC_FILES
	"uinput.*"
)
add_library(core2 ${SRC_FILES})

# Includes.
target_include_directories(core2
	PRIVATE ${REPO_LIBS_DIR}
)

# Link dependencies.
target_link_libraries(core2	PRIVATE
)
