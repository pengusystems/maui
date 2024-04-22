#include <thread>
#include <chrono>
#include <atomic>
#include <mutex>
#include <functional>
#include "event.h"

namespace core0 {
	class timer {
	public:
		timer() = default;
		timer(const timer& t) = delete;
		timer& operator=(const timer& t) = delete;
		~timer() { this->stop_sync(); }

		// Example use:
		// core0::timer t;
		// t.start(1, [](){printf("hi\n"); });
		bool start(const double& period_sec, std::function<void()> on_timer, const bool auto_restart = true) {
			if (m_running) return false;
			else if (m_thread.joinable()) m_thread.join();
			m_expired = false;
			m_running = true;
			m_thread = std::thread([&, period_sec, on_timer, auto_restart] {
				do {
					if (!m_mtx.try_lock()) break;
					m_evt.reset();
					m_mtx.unlock();
					m_evt.wait( static_cast<size_t>(period_sec * 1e6));
					if (m_running) on_timer();
				} while (auto_restart && m_running);
				m_expired = true;
			});
			return true;
		};

		// This will stop the timer synchronously, however do not use it from the timer callback (use stop_async instead).
		// This is not permitted, and will hang:
		// core0::timer t;
		// t.start(1, [&](){printf("hi\n"); t.stop_sync();});
		// That's how it should be used:
		// core0::timer t;
		// t.start(1, [&](){printf("hi\n"); });
		// ...
		// t.stop_sync();
		void stop_sync() {
			m_running = false;
			m_mtx.lock();
			m_evt.set();
			if (m_thread.joinable()) m_thread.join();
			m_mtx.unlock();
		}

		// Use this to stop the timer from the callback:
		// core0::timer t;
		// t.start(1, [&](){static int cnt = 0; cnt++; printf("hi\n"); if (cnt == 5) t.stop_async();});
		void stop_async() {
			m_running = false;
		}

		// Checks if the timer expired (relevant when auto_restart is not set).
		bool is_expired() {
			return m_expired;
		}

		// Checks if the timer is running or not.
		// This will return true even if we stopped the timer if it still processing the callback in its last period.
		bool is_running() {
			return m_running;
		}

		// Restarting:
		// If we want to restart a timer with was started with auto_restart = false, use the following scheme:
		//   stop_sync()
		//   start()

	private:
		manual_reset_event m_evt;
		std::thread m_thread;
		std::timed_mutex m_mtx;
		std::atomic<bool> m_running{false};
		std::atomic<bool> m_expired{true};
	};
}
