#ifndef _GRPC_SERVER_MACROS_H
#define _GRPC_SERVER_MACROS_H

#include "grpcpp/grpcpp.h"

// For unary rpc.
// These macros will only work with rpcs that convey to a specific naming convention: rpc Foo(FooRequest) returns (FooReply);
#define UnaryReactor_rpcRequest_rpcReply_header(rpc) grpc::ServerUnaryReactor* rpc(grpc::CallbackServerContext* context, const rpc ## Request* req, rpc ## Reply* rep) override
#define UnaryReactor_rpcRequest_rpcReply_impl(parent, rpc) grpc::ServerUnaryReactor* parent::rpc(grpc::CallbackServerContext* context, const rpc ## Request* req, rpc ## Reply* rep)

// For server streams.
// These macros will only work with rpcs that convey to a specific naming convention: rpc ListenToBar(ListenToBarRequest) returns (Bar);
#define ServerWriteReactor_stream_ListenTo_header(stream) grpc::ServerWriteReactor<stream>* ListenTo ## stream(grpc::CallbackServerContext* context, const ListenTo ## stream ## Request* req) override
#define ServerWriteReactor_stream_impl(parent, stream) grpc::ServerWriteReactor<stream>* parent::ListenTo ## stream(grpc::CallbackServerContext* context, const ListenTo ## stream ## Request* req)

#endif
