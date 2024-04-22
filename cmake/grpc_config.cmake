function(grpc_config)
	find_package(Threads REQUIRED)

	# Find Protobuf installation
	# Looks for protobuf-config.cmake file installed by Protobuf's cmake installation.
	option(protobuf_MODULE_COMPATIBLE TRUE)
	find_package(absl CONFIG REQUIRED PATHS ${REPO_EXT_BUILD_DIR}/grpc/build/install/lib/cmake/absl NO_DEFAULT_PATH)
	find_package(utf8_range CONFIG REQUIRED PATHS ${REPO_EXT_BUILD_DIR}/grpc/build/install/lib/cmake/utf8_range NO_DEFAULT_PATH)
	find_package(Protobuf CONFIG REQUIRED PATHS ${REPO_EXT_BUILD_DIR}/grpc/build/install/lib/cmake/protobuf NO_DEFAULT_PATH)
	message(STATUS "Using protobuf ${Protobuf_VERSION}")
	if(CMAKE_CROSSCOMPILING)
		find_program(_PROTOBUF_PROTOC protoc)
	else()
		set(_PROTOBUF_PROTOC $<TARGET_FILE:protobuf::protoc>)
	endif()

	# Find gRPC installation
	# Looks for gRPCConfig.cmake file installed by gRPC's cmake installation.
	find_package(gRPC CONFIG REQUIRED PATHS ${REPO_EXT_BUILD_DIR}/grpc/build/install/lib/cmake/grpc NO_DEFAULT_PATH)
	message(STATUS "Using gRPC ${gRPC_VERSION}")

	# Provide access to the parent scope.
	set(GRPC_INCLUDE_DIRS "${REPO_EXT_BUILD_DIR}/grpc/build/install/include" PARENT_SCOPE)
	set(PROTOBUF_LIBPROTOBUF protobuf::libprotobuf PARENT_SCOPE)
	set(GRPC_GRPCPP gRPC::grpc++ PARENT_SCOPE)
	set(GRPC_REFLECTION gRPC::grpc++_reflection PARENT_SCOPE)

	# Proto-gen.
	if (${ARGC} GREATER 0)
		set(PROTO_FILENAME ${ARGV0})
		get_filename_component(PROTO_NAME_NO_EXT ${PROTO_FILENAME} NAME_WLE)
		get_filename_component(PROTO_FILE ${PROTO_FILENAME} ABSOLUTE)
		get_filename_component(PROTO_FILE_PATH "${PROTO_FILE}" PATH)

		# Protoc-gen c++ plugin.
		if(CMAKE_CROSSCOMPILING)
			find_program(_GRPC_CPP_PLUGIN_EXECUTABLE grpc_cpp_plugin)
		else()
			set(_GRPC_CPP_PLUGIN_EXECUTABLE $<TARGET_FILE:gRPC::grpc_cpp_plugin>)
		endif()

		# Generated sources.
		set(PROTO_SRCS_INT "${CMAKE_CURRENT_BINARY_DIR}/${PROTO_NAME_NO_EXT}.pb.cc")
		set(PROTO_HDRS_INT "${CMAKE_CURRENT_BINARY_DIR}/${PROTO_NAME_NO_EXT}.pb.h")
		set(GRPC_SRCS_INT "${CMAKE_CURRENT_BINARY_DIR}/${PROTO_NAME_NO_EXT}.grpc.pb.cc")
		set(GRPC_HDRS_INT "${CMAKE_CURRENT_BINARY_DIR}/${PROTO_NAME_NO_EXT}.grpc.pb.h")
		add_custom_command(
			OUTPUT "${PROTO_SRCS_INT}" "${PROTO_HDRS_INT}" "${GRPC_SRCS_INT}" "${GRPC_HDRS_INT}"
			COMMAND ${_PROTOBUF_PROTOC}
			ARGS --grpc_out "${CMAKE_CURRENT_BINARY_DIR}"
				--cpp_out "${CMAKE_CURRENT_BINARY_DIR}"
				-I "${PROTO_FILE_PATH}"
				--plugin=protoc-gen-grpc="${_GRPC_CPP_PLUGIN_EXECUTABLE}"
				"${PROTO_FILE}"
			DEPENDS "${PROTO_FILE}"
		)

		# Provide access to the parent scope.
		set(PROTO_SRCS "${PROTO_SRCS_INT}" PARENT_SCOPE)
		set(PROTO_HDRS "${PROTO_HDRS_INT}" PARENT_SCOPE)
		set(GRPC_SRCS "${GRPC_SRCS_INT}" PARENT_SCOPE)
		set(GRPC_HDRS "${GRPC_HDRS_INT}" PARENT_SCOPE)
		set(GRPC_INCLUDE_DIRS "${REPO_EXT_BUILD_DIR}/grpc/build/install/include" "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>" PARENT_SCOPE)
	endif()
endfunction()
