#ifndef _IO_RING_HPP__
#define _IO_RING_HPP__

#include <atomic>
#include <memory>
#include <thread>
#include <vector>
#include <functional>
#include "concurrentqueue/blockingconcurrentqueue.h"
#include "core0/event.h"

namespace core1::buffer_utils {
	enum class io_ring_mode {
		blocking,
		non_blocking
	};
	template <typename T, io_ring_mode I = io_ring_mode::blocking>
	class io_ring {
	public:
		io_ring(const size_t& ring_size, const unsigned char num_submit_thr = 1, const unsigned char num_complete_thr = 1) {
			m_queue_size = ring_size;
			if (m_queue_size == 0) m_queue_size = 1;
			m_submission_queue = std::make_unique<moodycamel::BlockingConcurrentQueue<std::shared_ptr<T>>>();
			m_completion_queue = std::make_unique<moodycamel::BlockingConcurrentQueue<std::shared_ptr<T>>>();
			m_num_submit_thr = num_submit_thr;
			m_num_complete_thr = num_complete_thr;
			m_submitter.resize(m_num_submit_thr);
			m_completer.resize(m_num_complete_thr);
		}
		~io_ring() {};

		using cb_on_submit = std::function<void(std::shared_ptr<T>&)>;
		using cb_on_complete = std::function<void(std::shared_ptr<T>&)>;

		// The ring is initially empty, It should be filled by sumitting items (up to its size).
		bool submit(std::shared_ptr<T> item) {
			return m_submission_queue->enqueue(item);
		}

		// Resets the ring to initial condition.
		bool reset() {
			this->stop();
			std::shared_ptr<T> item = nullptr;
			while (m_submission_queue->try_dequeue(item)) {};
			while (m_completion_queue->try_dequeue(item)) {};
			return true;
		}

		// Starts the ring.
		bool start(const cb_on_submit& on_submit, const cb_on_complete& on_complete) {
			if (m_run) return false;
			else m_run = true;
			core0::auto_reset_event evt_submit[m_num_submit_thr], evt_complete[m_num_complete_thr];

			// The submitter thread dequeues the submission queue, executes a user action and then enqueues to the completion queue.
			m_on_submit = on_submit;
			for (auto thr_index = 0; thr_index < m_num_submit_thr; thr_index++) {
				m_submitter[thr_index] = std::thread([&, thr_index]{
					evt_submit[thr_index].set();
					while(m_run) {
						// Get an item from the submission queue.
						if constexpr (I == io_ring_mode::blocking) {
							constexpr int64_t wait_timeout_usec = 10000;
							if (!m_submission_queue->wait_dequeue_timed(m_submitter_cur_item, wait_timeout_usec)) {
								if (m_run) continue;
								else break;
							}
						}
						else {
							if (!m_submission_queue->try_dequeue(m_submitter_cur_item)) {
								if (m_run) continue;
								else break;
							}
						}

						// Check if we are still running, call the user submission callback and enqueue the item to the completion queue.
						if (!m_run) break;
						m_on_submit(m_submitter_cur_item);
						m_completion_queue->enqueue(m_submitter_cur_item);
					}
				});
			}

			// The completer thread dequeues the completion queue, executes ua ser action and then enqueues to the submission queue.
			m_on_complete = on_complete;
			for (auto thr_index = 0; thr_index < m_num_complete_thr; thr_index++) {
				m_completer[thr_index] = std::thread([&, thr_index]{
					evt_complete[thr_index].set();
					while(m_run) {
						// Get an item from the completion queue.
						if constexpr (I == io_ring_mode::blocking) {
							constexpr int64_t wait_timeout_usec = 10000;
							if (!m_completion_queue->wait_dequeue_timed(m_completer_cur_item, wait_timeout_usec)) {
								if (m_run) continue;
								else break;
							}
						}
						else {
							if (!m_completion_queue->try_dequeue(m_completer_cur_item)) {
								if (m_run) continue;
								else break;
							}
						}

						// Check if we are still running, call the user completion callback and enqueue the item back to the submission queue.
						if (!m_run) break;
						m_on_complete(m_completer_cur_item);
						m_submission_queue->enqueue(m_completer_cur_item);
					}
				});
			}

			// Wait until all threads actually start before returning.
			for (auto thr_index = 0; thr_index < m_num_complete_thr; thr_index++) evt_complete[thr_index].wait();
			for (auto thr_index = 0; thr_index < m_num_submit_thr; thr_index++) evt_submit[thr_index].wait();
			return true;
		}

		// Stops the ring.
		void stop() {
			// Deassert the run flag and wait for the threads to finish.
			m_run = false;

			for (auto thr_index = 0; thr_index < m_num_submit_thr; thr_index++) {
				if (m_submitter[thr_index].joinable()) {
					m_submitter[thr_index].join();
				}
			}
			for (auto thr_index = 0; thr_index < m_num_complete_thr; thr_index++) {
				if (m_completer[thr_index].joinable()) {
					m_completer[thr_index].join();
				}
			}
		}

		// Returns an approximate number of items in the ring.
		size_t size_approx() {
			return m_submission_queue->size_approx() + m_completion_queue->size_approx();
		}

	private:
		std::atomic_bool m_run;
		size_t m_queue_size;
		std::vector<std::thread> m_submitter, m_completer;
		std::shared_ptr<T> m_submitter_cur_item, m_completer_cur_item;
		unsigned char m_num_submit_thr, m_num_complete_thr;
		std::unique_ptr<moodycamel::BlockingConcurrentQueue<std::shared_ptr<T>>> m_submission_queue, m_completion_queue;
		cb_on_submit m_on_submit = {};
		cb_on_complete m_on_complete = {};
	};
}
#endif
