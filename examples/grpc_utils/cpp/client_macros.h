#ifndef _GRPC_CLIENT_MACROS_H
#define _GRPC_CLIENT_MACROS_H

#include <functional>
#include "grpcpp/grpcpp.h"
#include "core0/api_export.h"

// For unary rpc.
// These macros will only work with rpcs that convey to a specific naming convention: rpc Foo(FooRequest) returns (FooReply);
template<typename T>
using cb_on_unary = std::function<void(const grpc::Status&, const T&)>;
#define Unary_rpcRequest_rpcReply_header(rpc, deadline) void API_EXPORT rpc(const rpc ## Request& req, const bool sync = false, const cb_on_unary<rpc ## Reply>& cb = {}, const unsigned int deadline_ms = deadline, const int channel_id = 0)
#define Unary_rpcRequest_rpcReply_impl(parent, rpc) void parent::rpc(const rpc ## Request& req, const bool sync, const cb_on_unary<rpc ## Reply>& cb, const unsigned int deadline_ms, const int channel_id)

// For server streams.
// These macros will only work with rpcs that convey to a specific naming convention: rpc ListenToBar(ListenToBarRequest) returns (Bar);
template<typename T>
using cb_on_stream_msg = std::function<void(const T*)>;
using cb_on_stream_done = std::function<void(const grpc::Status&)>;
#define ServerStream_ListenTo_header(stream) grpc::Status API_EXPORT ListenTo ## stream(const ListenTo ## stream ## Request& req, const cb_on_stream_msg<stream>& on_msg, const cb_on_stream_done& on_stream_done = {}, const int channel_id = 0)
#define ServerStream_ListenTo_impl(parent, stream) grpc::Status parent::ListenTo ## stream(const ListenTo ## stream ## Request& req, const cb_on_stream_msg<stream>& on_msg, const cb_on_stream_done& on_stream_done, const int channel_id)
#define ServerStream_ListenTo_cancel_header(stream) grpc::Status API_EXPORT cancel_ListenTo ## stream(const int channel_id = 0)
#define ServerStream_ListenTo_cancel_impl(parent, stream) grpc::Status parent::cancel_ListenTo ## stream(const int channel_id)

#endif
