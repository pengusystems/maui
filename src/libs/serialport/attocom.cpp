#include <iostream>
#include "serialport.h"

int main(int argc, char *argv[]) {
	// Get command line arguments.
	if (argc == 1) {
		std::cout << "Usage: attocom <port name> [baud rate = 115200] [terminator = \\r\\n]" << std::endl;
		std::cout << "       output data will be transmitted with the given terminator when enter is pressed" << std::endl;
		std::cout << "       input data will be printed to stdout" << std::endl;
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
	std::string tx_terminator = "\r\n";
	if (argc > 3) {
		tx_terminator = argv[3];
	}

	// The async receive callback
	const auto on_recv = [&](const u8* data_ptr, const size_t data_len, const std::error_code& e) {
		if (e.value() != 0) {
			printf("Unexpected error: %s\n", e.message().c_str());
			return;
		}
		for (size_t ii = 0; ii < data_len; ++ii) {
			printf("%c", data_ptr[ii]);
		}
		fflush(stdout);
	};

	// Start the serial port and send when the user presses return.
	serialport port;
	port.set_cb_on_recv(on_recv);
	if (!port.start(argv[1], serialport::options(baudrate))) {
		std::cout << "Cannot open " << argv[1] << ", check permissions and port name" << std::endl;
		std::cout << "Exiting" << std::endl;
		return 1;
	}
	std::cout << "Successfully opened " << argv[1] << std::endl;
	while(1) {
		std::string message;
		std::cin >> message;
		port.send(message + tx_terminator);
	}
	return 0;
}
