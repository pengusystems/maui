add_executable(microcom
	"microcom.cpp"
)
target_include_directories(microcom PRIVATE
	${REPO_LIBS_DIR}
)
target_link_libraries(microcom PRIVATE
	serialport
)
