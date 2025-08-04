# This is a static library.
file(GLOB SRC_FILES
	"*.cpp"
)
add_library(core1 ${SRC_FILES})

# Includes.
target_include_directories(core1
	PRIVATE ${REPO_LIBS_DIR}
	PUBLIC ${REPO_EXT_DIR}
)

# Link dependencies.
target_link_libraries(core1 PRIVATE
)
