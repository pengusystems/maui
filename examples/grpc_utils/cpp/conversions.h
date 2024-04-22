#ifndef _GRPC_UTILS_CONVERSIONS_H
#define _GRPC_UTILS_CONVERSIONS_H

#include "google/protobuf/duration.pb.h"

namespace grpc_utils::conversions {
	inline int64_t to_ms(const google::protobuf::Duration& duration) {
		auto ms = duration.seconds()*1e3 + static_cast<double>(duration.nanos())/1e6;
		return static_cast<int64_t>(ms);
	}

	inline void to_duration(google::protobuf::Duration* mutable_duration, const int64_t& duration_ms) {
		const auto duration_s = static_cast<double>(duration_ms)/1e3;
		const auto duration_s_floored = static_cast<int64_t>(duration_s);
		const auto duration_ns = static_cast<int32_t>((duration_s - duration_s_floored) * 1e9);
		mutable_duration->set_seconds(duration_s_floored);
		mutable_duration->set_nanos(duration_ns);
	}
}

#endif