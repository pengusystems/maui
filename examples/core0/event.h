#ifndef _EVENT_H
#define _EVENT_H

#include <thread>
#include <mutex>
#include <condition_variable>
#include <chrono>
#include <atomic>

namespace core0 {
	class manual_reset_event {
	public:
		operator bool() const { return this->test(); }

		void wait() {
			if (this->test()) { return; }  // Optimization to avoid lock.
			std::unique_lock<std::mutex> lck(this->mtx);
			this->cv.wait(lck, [this]() { return this->test(); });
		}

		// Returns true, if the event has been signaled, false if timeout.
		bool wait(const std::size_t timeout_usec) {
			if (this->test()) { return true; }  // Optimization to avoid lock.
			const auto wait_until = std::chrono::system_clock::now() + std::chrono::microseconds(timeout_usec);
			std::unique_lock<std::mutex> lck(this->mtx);
			return this->cv.wait_until(lck, wait_until, [this]() { return this->test(); });
		}

		void set() {
			{
				std::lock_guard<std::mutex> lck(this->mtx);
				this->signaled = true;
			}
			this->cv.notify_all();
		}

		void reset() {
			std::lock_guard<std::mutex> lck(this->mtx);
			this->signaled = false;
		}

	private:
		std::condition_variable cv;
		std::mutex mtx;
		bool signaled = false;
		bool test() const { return this->signaled; }
	};

	class auto_reset_event {
	public:
		operator bool() { return this->test_and_clear(); }

		void wait() {
			if (this->test_and_clear()) { return; } // Optimization to avoid lock.
			std::unique_lock<std::mutex> lck(this->mtx);
			this->cv.wait(lck, [this]() { return this->test_and_clear(); });
		}

		// Returns true, if the event has been signaled, false if timeout.
		bool wait(const std::size_t timeout_usec) {
			if (this->test_and_clear()) { return true; } // Optimization to avoid lock.
			const auto wait_until = std::chrono::system_clock::now() + std::chrono::microseconds(timeout_usec);
			std::unique_lock<std::mutex> lck(this->mtx);
			return this->cv.wait_until(lck, wait_until, [this]() { return this->test_and_clear(); });
		}

		void set() {
			{
				std::lock_guard<std::mutex> lck(this->mtx);
				this->signaled = true;
			}
			this->cv.notify_one();
		}

	private:
		std::condition_variable cv;
		std::mutex mtx;
		std::atomic<bool> signaled{false};
		bool test_and_clear() { return this->signaled.exchange(false); }
	};
}

#endif
