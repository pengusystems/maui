#ifdef _WIN32
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0xA00
#endif
#endif
#ifndef ASIO_STANDALONE
#define ASIO_STANDALONE
#endif
#ifdef __linux__
#include <sys/file.h>
#endif
#include <mutex>
#include <thread>
#include <memory>
#include <atomic>
#include <deque>
#include <chrono>
#include "asio/include/asio.hpp"
#include "asio/include/asio/serial_port.hpp"
#include "serialport.h"

struct serialport::impl {
	impl();
	~impl();
	void async_read_some();
	void configure();
	void stop();
	void on_receive(const std::error_code ec, size_t bytes_transferred);
	serialport::options m_options;
	std::string port_name;
	const int read_buf_size = 256;
	std::atomic<bool> running{false};
	asio::io_service io_service;
	std::thread io_service_thread;
	using serial_port_ptr = std::shared_ptr<asio::serial_port>;
	serial_port_ptr port;
	std::mutex mtx;
	u8 *read_buf_raw;
	cb_on_recv on_recv;
	using send_msg = struct{ std::shared_ptr<std::vector<u8>> payload; size_t len; };
	std::deque<send_msg> send_msgs_vec; // If we ever wanted buffering here, replace the deque with a producer consumer queue (handler which pops the queue is called from the io_service thread, while push_back is from the async_write call thread).
	std::deque<std::shared_ptr<std::string>> send_msgs_str; // If we ever wanted buffering here, replace the deque with a producer consumer queue (handler which pops the queue is called from the io_service thread, while push_back is from the async_write call thread).
	std::atomic<bool> async_write_in_progress{false};
	cb_on_async_send on_async_send;
};

serialport::impl::impl() {
	read_buf_raw = new u8[read_buf_size];
	on_recv = nullptr;
}

serialport::impl::~impl() {
	delete[] read_buf_raw;
}

void serialport::impl::async_read_some() {
	if (port.get() == NULL || !port->is_open()) {
		return;
	}

	port->async_read_some(
		asio::buffer(read_buf_raw, read_buf_size),
		std::bind(
			&serialport::impl::on_receive,
			this,
			std::placeholders::_1,
			std::placeholders::_2));
}

void serialport::impl::configure() {
	// Option settings (at some point we can expose more than just the baud rate).
	port->set_option(asio::serial_port_base::baud_rate(m_options.baud_rate));
	port->set_option(asio::serial_port_base::character_size(m_options.character_size));
	switch (m_options.stop_bits) {
		case serialport::options::stop_bits::one: port->set_option(asio::serial_port_base::stop_bits(asio::serial_port_base::stop_bits::one)); break;
		case serialport::options::stop_bits::onepointfive: port->set_option(asio::serial_port_base::stop_bits(asio::serial_port_base::stop_bits::onepointfive)); break;
		case serialport::options::stop_bits::two: port->set_option(asio::serial_port_base::stop_bits(asio::serial_port_base::stop_bits::two)); break;
		default: port->set_option(asio::serial_port_base::stop_bits(asio::serial_port_base::stop_bits::one)); break;
	}
	switch (m_options.parity) {
		case serialport::options::parity::none: port->set_option(asio::serial_port_base::parity(asio::serial_port_base::parity::none)); break;
		case serialport::options::parity::odd: port->set_option(asio::serial_port_base::parity(asio::serial_port_base::parity::odd)); break;
		case serialport::options::parity::even: port->set_option(asio::serial_port_base::parity(asio::serial_port_base::parity::even)); break;
		default: port->set_option(asio::serial_port_base::parity(asio::serial_port_base::parity::none)); break;
	}
	switch (m_options.flow_control) {
		case serialport::options::flow_control::none: port->set_option(asio::serial_port_base::flow_control(asio::serial_port_base::flow_control::none)); break;
		case serialport::options::flow_control::software: port->set_option(asio::serial_port_base::flow_control(asio::serial_port_base::flow_control::none)); break;
		case serialport::options::flow_control::hardware: port->set_option(asio::serial_port_base::flow_control(asio::serial_port_base::flow_control::none)); break;
		default: port->set_option(asio::serial_port_base::flow_control(asio::serial_port_base::flow_control::none));
	}
}

void serialport::impl::stop() {
	running = false;
	std::lock_guard<std::mutex> lock(mtx);
	if (port) {
		if (port->is_open()) {
			port->cancel();
#ifdef __linux__
			flock(port->native_handle(), LOCK_UN | LOCK_NB);
#endif
			port->close();
			port.reset();
		}
	}
	io_service.stop();
	io_service.reset();
}

void serialport::impl::on_receive(const std::error_code ec, size_t bytes_transferred) {
	std::lock_guard<std::mutex> lock(mtx);
	if (port.get() == NULL || !port->is_open()) {
		return;
	}
	if (on_recv) {
		on_recv(read_buf_raw, bytes_transferred, ec);
	}
	if (ec.value() != 0) {
		port->cancel();
		port->close();
		if (!m_options.auto_recover) {
			return;
		}
		while (running) {
			std::error_code e;
			port->open(port_name.c_str(), e);
			if (!e) {
				configure();
				break;
			}
			using namespace std::chrono_literals;
			std::this_thread::sleep_for(1s);
		}
	}
	async_read_some();
}

serialport::serialport() {
	m_pimpl = std::make_unique<impl>();
}

serialport::~serialport() {
	stop();
	if (m_pimpl->io_service_thread.joinable()) {
		m_pimpl->io_service_thread.join();
	}
}

serialport::operator bool() {
	if (!m_pimpl->running) {
		return false;
	}
	if (!m_pimpl->port->is_open()) {
		return false;
	}
	return true;
}

bool serialport::start(const std::string& port_name, const options& options) {
	std::error_code ec;
	if (m_pimpl->port) {
		return false;
	}

	m_pimpl->m_options = options;
	m_pimpl->port_name = std::string(port_name);
	m_pimpl->port = impl::serial_port_ptr(new asio::serial_port(m_pimpl->io_service));
	m_pimpl->port->open(port_name, ec);
	if (ec) {
		return false;
	}

#ifdef __linux__
	// Make sure no one else can open the serial port.
	auto ret = flock(m_pimpl->port->native_handle(), LOCK_EX | LOCK_NB);
	if (ret) return false;
#endif
	m_pimpl->configure();

	// First time is required to bind the handler.
	m_pimpl->running = true;
	m_pimpl->async_read_some();

	// IO service must be started after the read so the run call will block.
	// Note asio handlers are only invoked by the thread that is currently calling any overload of run(), run_one(), poll() or poll_one() for the io_service.
	m_pimpl->io_service_thread = std::thread([&]{m_pimpl->io_service.run(); });
	return true;
}

void serialport::stop() {
	m_pimpl->stop();
}

void serialport::set_cb_on_recv(const cb_on_recv& on_recv) {
	m_pimpl->on_recv = on_recv;
}

size_t serialport::send(const std::string& buf) {
	return send(buf.c_str(), buf.size());
}

size_t serialport::send(const char* buf, const size_t& size) {
	return send(reinterpret_cast<u8*>(const_cast<char*>(buf)), size);
}

size_t serialport::send(const u8* buf, const size_t& size) {
	if (!m_pimpl->running) {
		return -1;
	}
	if (!m_pimpl->port->is_open()) {
		return -1;
	}
	if (size == 0) {
		return 0;
	}
	try {
		return asio::write(*m_pimpl->port, asio::buffer(buf, size));
	}
	catch(const std::exception& e) {
		return -1;
	}
}

bool serialport::async_send(std::shared_ptr<std::vector<u8>> buf, const size_t& size, const cb_on_async_send& on_send) {
	if (!m_pimpl->running) {
		return false;
	}
	if (!m_pimpl->port->is_open() || m_pimpl->async_write_in_progress) {
		on_send(std::error_code(), 0);
		return false;
	}
	m_pimpl->async_write_in_progress = true;
	m_pimpl->on_async_send = on_send;
	m_pimpl->send_msgs_vec.push_back(serialport::impl::send_msg{buf, size});
	try {
		asio::async_write(*m_pimpl->port, asio::buffer(buf.get()->data(), size), [&](const std::error_code ec, std::size_t length) {
			if (!ec) {
				if (m_pimpl->on_async_send) m_pimpl->on_async_send(ec, length);
			}
			else {
				if (m_pimpl->on_async_send) m_pimpl->on_async_send(ec, length);
			}
			m_pimpl->send_msgs_vec.pop_front();
			m_pimpl->async_write_in_progress = false;
		});
		return true;
	}
	catch (const std::exception& e) {
		return false;
	}
}

bool serialport::async_send(std::shared_ptr<std::string> buf, const cb_on_async_send& on_send) {
	if (!m_pimpl->running) {
		return false;
	}
	if (!m_pimpl->port->is_open() || m_pimpl->async_write_in_progress) {
		on_send(std::error_code(), 0);
		return false;
	}
	m_pimpl->async_write_in_progress = true;
	m_pimpl->on_async_send = on_send;
	m_pimpl->send_msgs_str.push_back(buf);
	try {
		asio::async_write(*m_pimpl->port, asio::buffer(buf.get()->data(), buf.get()->size()), [&](const std::error_code ec, std::size_t length) {
			if (!ec) {
				if (m_pimpl->on_async_send) m_pimpl->on_async_send(ec, length);
			}
			else {
				if (m_pimpl->on_async_send) m_pimpl->on_async_send(ec, length);
			}
			m_pimpl->send_msgs_str.pop_front();
			m_pimpl->async_write_in_progress = false;
		});
		return true;
	}
	catch (const std::exception& e) {
		return false;
	}
}
