#ifndef _GRPC_UTILS_CLIENT_LISTENER_HPP
#define _GRPC_UTILS_CLIENT_LISTENER_HPP

#include <atomic>
#include "grpcpp/grpcpp.h"
#include "grpcpp/support/client_callback.h"
#include "core0/event.h"

// Reference:
// https://lastviking.eu/fun_with_gRPC_and_C++/callback-client.html
// https://github.com/jgaa/fun-with-gRPC/blob/main/src/callback-client/callback-client-impl.hpp
// Usage example:
// grpc::Status ListenToFoo(const ListenToFooRequest& req, const cb_on_stream_msg<Foo>& on_msg, const cb_on_stream_done& on_stream_done = {}) {
// 	listener_Foo = std::make_unique<grpc_utils::client::callback::listener<Foo>>(grpc_utils::client::create_context({.set_deadline = false}), on_msg_int, std::bind(&client::on_stream_done_int, m_client.get(), on_stream_done, "Foo", channel_id, std::placeholders::_1));
// 	stub->async()->ListenToFoo(listener_Foo->get_context(), &req, listener_Foo.get());
// 	listener_Foo->start();
// }
namespace grpc_utils::client::callback {
	enum listener_state {
		stale,
		busy,
		available
	};

	template <typename T>
	class listener : public grpc::ClientReadReactor<T> {
	public:
		using cb_on_msg = std::function<void(T*)>;
		using cb_on_done = std::function<void(const grpc::Status&)>;
		listener(std::unique_ptr<grpc::ClientContext> context, const cb_on_msg& on_msg, const cb_on_done& on_done = {}) : 
			m_state(listener_state::available),
			m_context(std::move(context)),
			m_cb_on_msg(on_msg),
			m_cb_on_done(on_done) {
		}

		grpc::Status start(const bool wait_for_initial_metadata = true) {
			// Initiate the first (by adding StartCall) async read into m_msg.
			grpc::ClientReadReactor<T>::StartRead(&m_msg);
			grpc::ClientReadReactor<T>::StartCall();
			m_state = listener_state::busy;
			if (wait_for_initial_metadata) {
				constexpr auto wait_for_conn_evt_usec = 100000;
				auto evt_triggered = m_wait_for_initial_metadata.wait(wait_for_conn_evt_usec);
				if (evt_triggered) return grpc::Status::OK;
				return grpc::Status(grpc::StatusCode::FAILED_PRECONDITION, "Initial metadata was not received");
			}
			else {
				return grpc::Status::OK;
			}
		}

		listener_state get_state() {
			return m_state;
		}

		grpc::ClientContext* get_context() {
			return m_context.get();
		}

		void OnReadDone(bool ok) override {
			// Keep reading as long as everything is ok.
			if (ok) {
				m_cb_on_msg(&m_msg);
				m_msg.Clear();
				grpc::ClientReadReactor<T>::StartRead(&m_msg);
			}
			else {
				// Read failed.
				m_state = listener_state::stale;
			}
		}

		void OnDone(const grpc::Status& s) override {
			if (m_cb_on_done) m_cb_on_done(s);
			m_state = listener_state::available;
			m_cancel_evt.set();
		}

		grpc::Status cancel() {
			if (m_state == listener_state::available) return grpc::Status(grpc::StatusCode::FAILED_PRECONDITION, "Not running");
			m_context->TryCancel();
			constexpr auto wait_for_cancel_evt_usec = 100000;
			auto evt_triggered = m_cancel_evt.wait(wait_for_cancel_evt_usec);
			if (evt_triggered) return grpc::Status::CANCELLED;
			return grpc::Status(grpc::StatusCode::FAILED_PRECONDITION, "Failed to cancel");
		}

		void OnReadInitialMetadataDone(bool ok) override {
			m_wait_for_initial_metadata.set();
		}

	private:
		T m_msg;
		std::atomic<listener_state> m_state;
		std::unique_ptr<grpc::ClientContext> m_context;
		core0::auto_reset_event m_wait_for_initial_metadata;
		core0::auto_reset_event m_cancel_evt;
		cb_on_msg m_cb_on_msg;
		cb_on_done m_cb_on_done;
	};

	template <typename T>
	grpc::Status check_listener_active(T* listener) {
		if (listener) {
			if (listener->get_state() == grpc_utils::client::callback::listener_state::busy) {
				constexpr auto error_msg = "Listener is already active and must be stopped before it is restarted";
				return grpc::Status(grpc::StatusCode::ALREADY_EXISTS, error_msg);
			}
		}
		return grpc::Status::OK;
	}

	template <typename T>
	grpc::Status cancel_listener(std::unique_ptr<listener<T>>& listener) {
		if (listener) {
			return listener->cancel();
		}
		constexpr auto error_msg = "Listener has not been started";
		return grpc::Status(grpc::StatusCode::UNAVAILABLE, error_msg);
	}
}

#endif
