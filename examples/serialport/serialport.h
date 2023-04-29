#ifndef _SERIALPORT_H
#define _SERIALPORT_H

#include <functional>
#include <vector>
#include <string>
#include <memory>
#include <system_error>
#include "core0/types.h"
#include "core0/api_export.h"

// A self explanatory class to manage a serial port.
class serialport {
public:
	// Call back for async usage.
	using cb_on_recv = std::function<void(const u8* data_ptr, const size_t data_len, const std::error_code& e)>;
	using cb_on_async_send = std::function<void(const std::error_code& e, const size_t data_len)>;

	// Options for configuration.
	struct options {
		options() = default;
		options(unsigned int baudrate) : baud_rate(baudrate) {}
		enum class parity {
			none,
			odd,
			even
		};
		enum class stop_bits {
			one,
			onepointfive,
			two
		};
		enum class flow_control {
			none,
			software,
			hardware
		};
		unsigned int baud_rate = 9600;
		unsigned int character_size = 8;
		parity parity = parity::none;
		stop_bits stop_bits = stop_bits::one;
		flow_control flow_control = flow_control::none;
		bool auto_recover = true;
	};

	API_EXPORT serialport();
	API_EXPORT ~serialport();

	// Disable copy constructors.
	serialport(const serialport&p) = delete;
	serialport&operator=(const serialport&p) = delete;

	// Check if the port is initialized.
	API_EXPORT operator bool();

	// Opens the serial port and starts listening on it.
	// Under Linux port_name would usually look like: "/dev/ttyS0"
	// where 0 can be replaced with different serial port nodes.
	// If permission is denied: sudo chmod o+rw /dev/ttyS0
	bool API_EXPORT start(const std::string& port_name, const options& options);

	// Stops listening on the serial port and closes it.
	void API_EXPORT stop();

	// Sets a call back handler to be called when data is received.
	void API_EXPORT set_cb_on_recv(const cb_on_recv& on_recv);

	// Synchronous sending (returns upon completion).
	size_t API_EXPORT send(const std::string& buf);
	size_t API_EXPORT send(const char* buf, const size_t& size);
	size_t API_EXPORT send(const u8* buf, const size_t& size);

	// Async sending (returns immediately, useful for slow connections).
	// Usage example:
	//   auto to_send = std::make_shared<std::vector<u8>>();
	//   to_send->push_back(1);
	//   port.async_send(to_send, to_send->size(), [](const std::error_code e, const size_t len){
	//   	printf("sent %d bytes", len);
	//   });
	// This has no internal buffering and will drop a new message if the current one did not finish sending.
	bool API_EXPORT async_send(std::shared_ptr<std::vector<u8>> buf, const size_t& size, const cb_on_async_send& on_send);
	bool API_EXPORT async_send(std::shared_ptr<std::string> buf, const cb_on_async_send& on_send);

private:
	struct impl;
	std::unique_ptr<impl> m_pimpl;
};

#endif