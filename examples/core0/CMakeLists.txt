# This is an interface library.
file(GLOB SRC_FILES
	"*.h"
	"*.cpp"
)
add_library(core0 INTERFACE
	${SRC_FILES}
)