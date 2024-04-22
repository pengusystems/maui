#ifndef _GRPC_UTILS_SERVER_ASYNC_WRITER_HPP
#define _GRPC_UTILS_SERVER_ASYNC_WRITER_HPP

#include <memory>
#include <functional>
#include <atomic>
#include <mutex>
#include "grpcpp/grpcpp.h"
#include "grpcpp/support/server_callback.h"
#include "concurrentqueue/blockingconcurrentqueue.h"

// Usage example:
// 1. Override grpc function with:
// grpc::ServerWriteReactor<Foo>* server::ListenToFoo(grpc::CallbackServerContext* context, const ListenToFooRequest* req) {
// 	return writer_store_Foo->add_writer();
// }
//
// 2. Create an instance:
// writer_store_Foo = std::make_unique<grpc_utils::server::callback::async_writer_store<Foo>>(4);
//
// 3. Add messages asynchrnously from producers.
// writer_store_Foo->async_write(Foomsg);
namespace grpc_utils::server::callback {
	enum async_writer_state {
		stale,
		busy,
		cancelled,
		available
	};

	// Common producer - consumer implementation for a server write reactor.
	// The server needs to store a new reactor for each client which wants to read a grpc server side stream.
	template <typename T>
	class async_writer : public grpc::ServerWriteReactor<T> {
	public:
		using cb_on_done = std::function<void()>;
		using cb_on_cancel = std::function<void()>;
		async_writer(const cb_on_done& on_done, const cb_on_cancel& on_cancel, const int num_producers = 1, const int min_buffer_size = 32) : 
			m_on_cancel(on_cancel),
			m_on_done(on_done),
			m_msg_queue(std::make_unique<moodycamel::BlockingConcurrentQueue<T>>(min_buffer_size, 0, num_producers)),
			m_state(async_writer_state::available) {
		}

		async_writer_state get_state() {
			return m_state;
		}

		bool async_write(const T& msg) {
			// Enqueue a new message if the writer is not stale or cancelled.
			std::unique_lock<std::mutex> lock(m_write_mtx);
			if ((m_state == async_writer_state::stale) || (m_state == async_writer_state::cancelled)) {
				return false;
			}
			else {
				// If the writer is not busy give the message to grpc right away.
				// If we have multiple producers, we have to sync them, otherwise we could end up with multiples StartWrite() calls.
				if (m_state == async_writer_state::available) {
					m_state = async_writer_state::busy;
					m_msg = msg;
					this->StartWrite(&m_msg);
					return true;
				}
				else {
					// If the writer is busy, enqueue the new message.
					// Upon completion of transmitting the current message grpc will invoke OnWriteDone and the pending message
					// will be handled.
					// Note: since we will have a write reactor for each client, it DOES NOT make sense to include a thread
					//       that will monitor the msg_queue and send a msg over when the writer becomes available.
					return m_msg_queue->try_enqueue(msg);
				}
			}
		}

		void abort() {
			this->Finish(grpc::Status(grpc::StatusCode::ABORTED, "Writer aborted"));
		}

		void OnCancel() override {
			m_state = async_writer_state::cancelled;
			if (m_on_cancel) m_on_cancel();
			this->Finish(grpc::Status::CANCELLED);
		}

		void OnDone() override {
			m_state = async_writer_state::stale;
			if (m_on_done) m_on_done();
		}

		void OnWriteDone(bool ok) override {
			// We must synchronize this function with the write function because
			// the write function might be dealing with a new message (async) while a grpc thread invoked
			// this function. The write function could see a busy m_state, but this function has already polled the
			// message queue and is about to change m_state to available. In this state, the new message will not be streamed
			// until the next message is written by the write function.
			std::unique_lock<std::mutex> lock(m_write_mtx);
			if (ok) {
				if (m_msg_queue->try_dequeue(m_msg)) {
					this->StartWrite(&m_msg);
				}
				else {
					m_state = async_writer_state::available;
				}
			}
			else {
				this->Finish(grpc::Status::CANCELLED);
				m_state = async_writer_state::cancelled;
			}
		}

	private:
		cb_on_done m_on_done;
		cb_on_cancel m_on_cancel;
		std::unique_ptr<moodycamel::BlockingConcurrentQueue<T>> m_msg_queue;
		std::mutex m_write_mtx;
		T m_msg;
		std::atomic<async_writer_state> m_state;
	};

	// Data structure to store and manage multiple server writers.
	template <typename T>
	class async_writer_store {
	public:
		async_writer_store(const int num_producers = 1, const int min_buffer_size = 32) : m_num_producers(num_producers), m_min_buffer_size(min_buffer_size)
		{}

		// Generates and adds a new server writer.
		using cb_on_cancel = std::function<void()>;
		grpc::ServerWriteReactor<T>* add_writer(const cb_on_cancel& on_cancel = {}) {
			// Bind on_done to the function that will remove the writer from the list. A writer can only be removed after on_done was called and it is stale.
			// If the user provided a callback for on_cancel, forward it over to the writer.
			auto reactor = std::make_unique<async_writer<T>>(std::bind(&async_writer_store<T>::remove_stale_writers, this), on_cancel, m_num_producers, m_min_buffer_size);

			// Send initial meta data (otherwise it will be sent implicitly with the first write and that might not happen right away).
			reactor->StartSendInitialMetadata();

			// Lock the list of server writers and move the new writer to the list.
			std::unique_lock<std::mutex> lock(m_vec_mtx);
			m_vec.push_back(std::move(reactor));
			return m_vec.back().get();
		}

		grpc::ServerWriteReactor<T>* add_writer_with_initial_async_write(const T& init_msg, const cb_on_cancel& on_cancel = {}) {
			// Bind on_done to the function that will remove the writer from the list. A writer can only be removed after on_done was called and it is stale.
			// If the user provided a callback for on_cancel, forward it over to the writer.
			auto reactor = std::make_unique<async_writer<T>>(std::bind(&async_writer_store<T>::remove_stale_writers, this), on_cancel);

			// Send initial meta data (otherwise it will be sent implicitly with the first write and that might not happen right away).
			reactor->StartSendInitialMetadata();

			// Write the initial message only to the new writer.
			reactor->async_write(init_msg);

			// Lock the list of server writers and move the new writer to the list.
			std::unique_lock<std::mutex> lock(m_vec_mtx);
			m_vec.push_back(std::move(reactor));
			return m_vec.back().get();
		}

		// Removes stale server writer.
		void remove_stale_writers() {
			// Lock the list for adding writers, scan and remove stale writers (those which called OnDone and marked themselves as stale).
			std::unique_lock<std::mutex> lock(m_vec_mtx);
			for (auto it = m_vec.begin(); it != m_vec.end();) {
				if ((*it)->get_state() == async_writer_state::stale) {
					it = m_vec.erase(it);
				}
				else {
					it++;
				}
			}
		}

		// Scans through the list of server writers, writing a message for each one.
		void async_write(const T& msg) {
			// Lock the list for adding and removing writers.
			std::unique_lock<std::mutex> lock(m_vec_mtx);
			for (auto it = m_vec.begin(); it != m_vec.end(); it++) {
				(*it)->async_write(msg);
			}
		};

		// Aborts each writer in the list of server writers.
		void abort() {
			std::unique_lock<std::mutex> lock(m_vec_mtx);
			for (auto it = m_vec.begin(); it != m_vec.end(); it++) {
				(*it)->abort();
			}
		}

	private:
		std::vector<std::unique_ptr<async_writer<T>>> m_vec;
		std::mutex m_vec_mtx;
		int m_num_producers;
		int m_min_buffer_size;
	};
}

#endif
