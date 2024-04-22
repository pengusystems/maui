#ifndef _GRPC_UTILS_SERVER_UNARY_REACTOR_H
#define _GRPC_UTILS_SERVER_UNARY_REACTOR_H

#include "grpcpp/grpcpp.h"

namespace grpc_utils::server {
	inline grpc::ServerUnaryReactor* set_unary_reactor_success(grpc::ServerUnaryReactor* reactor) {
		reactor->Finish(grpc::Status::OK);
		return reactor;
	}

	inline grpc::ServerUnaryReactor* set_unary_reactor_fail(grpc::ServerUnaryReactor* reactor, const grpc::Status& on_fail) {
		reactor->Finish(on_fail);
		return reactor;
	}

	template <typename T>
	grpc::ServerUnaryReactor* set_unary_reactor(grpc::ServerUnaryReactor* reactor, const T success_or_code, const grpc::Status& on_fail, const grpc::Status& on_success = grpc::Status::OK) {
		// This works for bool, where success_or_code == true invokes on_success
		// and also for return codes where success_or_code == 0 invokes on_success
		if constexpr (std::is_same_v<bool, T>) {
			if (success_or_code) reactor->Finish(on_success);
			else reactor->Finish(on_fail);
		}
		else {
			if (success_or_code == 0) reactor->Finish(on_success);
			else reactor->Finish(on_fail);
		}
		return reactor;
	}
}

#endif
