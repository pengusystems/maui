#ifndef _UINPUT_H___
#define _UINPUT_H___

#ifdef __linux__
#include <memory>
#include <linux/input-event-codes.h>

namespace core2::input {
	// Generic class to interface to /dev/uinput
	class uinput {
	public:
		uinput();
		~uinput();

		// Send keystroke.
		void send_key(const unsigned short key);

	private:
		struct impl;
		std::unique_ptr<impl> m_pimpl;
	};
}

#endif
#endif
