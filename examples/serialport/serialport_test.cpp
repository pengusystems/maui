#include <iostream>
#include <thread>
#include "serialport.h"

using namespace std::chrono_literals;

int main(int argc, char *argv[]) {
	// Get command line arguments.
	if (argc == 1) {
		std::cout << "Usage: serialport_test <port name> [baud_rate = 115200]" << std::endl;
		return 1;
	}
	auto baudrate = 115200;
	if (argc > 2) {
		try {
			auto user_baudrate = atoi(argv[2]);
			baudrate = user_baudrate;
		}
		catch(...) {
			std::cout << "Illegal baud rate, using 115200" << std::endl;
		}
	}

	// The async receive callback
	const auto on_recv = [&](const u8* data_ptr, const size_t data_len, const std::error_code& e) {
		if (e.value() != 0) {
			printf("Unexpected error: %s\n", e.message().c_str());
			return;
		}
		for (size_t ii = 0; ii < data_len; ++ii) {
			std::cout << data_ptr[ii];
		}
	};

	// Start the serial port and occasionally send stuff.
	serialport port;
	port.set_cb_on_recv(on_recv);
	if (!port.start(argv[1], serialport::options(baudrate))) {
		std::cout << "Cannot open " << argv[1] << ", check permissions and port name" << std::endl;
		std::cout << "Exiting" << std::endl;
		return 1;
	}
	std::cout << "Successfully opened " << argv[1] << std::endl;
	while(1) {
		std::this_thread::sleep_for(0.5s);
		port.send("test");
	}
	return 0;
}