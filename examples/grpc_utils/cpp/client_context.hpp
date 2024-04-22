#ifndef _GRPC_UTILS_CLIENT_CONTEXT_HPP
#define _GRPC_UTILS_CLIENT_CONTEXT_HPP

#include <chrono>
#include <memory>
#include "grpcpp/grpcpp.h"
#include "core0/types.h"

namespace grpc_utils::client {
	struct context_cfg {
		bool set_deadline = true;
		u64 deadline_ms = 500;
	};
	inline std::unique_ptr<grpc::ClientContext> create_context(const context_cfg& cfg = {}) {
		// ClientContext instances should not be reused across rpcs!!
		// The ClientContext instance used for creating an rpc must remain alive and valid for the lifetime of the rpc.
		// This is based on https://grpc.github.io/grpc/cpp/classgrpc_1_1_client_context.html
		auto context = std::make_unique<grpc::ClientContext>();
		if (cfg.set_deadline) context->set_deadline(std::chrono::system_clock::now() + std::chrono::milliseconds(cfg.deadline_ms));
		return std::move(context);
	}
}

#endif