#ifndef _GRPC_UTILS_CLIENT_UNARY_ASYNC_HPP
#define _GRPC_UTILS_CLIENT_UNARY_ASYNC_HPP

#include <chrono>
#include <memory>
#include "grpcpp/grpcpp.h"
#include "core0/types.h"

namespace grpc_utils::client::callback {
	template <typename Treq, typename Trep>
	class unary_async {
	public:
		using user_cb = std::function<void(const grpc::Status&, const Trep& rep)>;
		unary_async(std::unique_ptr<grpc::ClientContext> context, const Treq& req, const user_cb& cb) : m_context(std::move(context)), m_req(req), m_cb(cb) {}

		std::unique_ptr<grpc::ClientContext> m_context;
		Treq m_req;
		Trep m_rep;
		user_cb m_cb;
	};
}

#endif