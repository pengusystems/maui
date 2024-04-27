#ifdef __linux__
#include <stdexcept>
#include <cstring>
#include <fcntl.h>
#include <unistd.h>
#include <linux/input.h>
#include <linux/uinput.h>
#include "core0/types.h"
#include "uinput.h"

namespace core2::input {
	struct uinput::impl {
		int fd;
		void syn();
	};

	void uinput::impl::syn() {
		input_event ev = {.type = EV_SYN, .code = SYN_REPORT, .value = 0};
		gettimeofday(&ev.time, nullptr);
		write(fd, &ev, sizeof(input_event));
	}

	uinput::uinput() {
		m_pimpl = std::make_unique<impl>();
		m_pimpl->fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
		if(m_pimpl->fd < 0) throw std::runtime_error("Can't open /dev/uinput/ - check permissions");
		ioctl(m_pimpl->fd, UI_SET_EVBIT, EV_KEY);
		constexpr auto last_key_code_supported = 255;
		for (auto ii = 0; ii <= last_key_code_supported; ii++) ioctl(m_pimpl->fd, UI_SET_KEYBIT, ii);
		ioctl(m_pimpl->fd, UI_SET_EVBIT, EV_SYN);
		uinput_user_dev uidev;
		std::memset(&uidev, 0, sizeof(uidev));
		snprintf(uidev.name, UINPUT_MAX_NAME_SIZE, "uinput-kbd");
		uidev.id.bustype = BUS_USB;
		uidev.id.vendor  = 0x1;
		uidev.id.product = 0x1;
		uidev.id.version = 1;
		write(m_pimpl->fd, &uidev, sizeof(uidev));
		ioctl(m_pimpl->fd, UI_DEV_CREATE);
	}

	uinput::~uinput() {
		ioctl(m_pimpl->fd, UI_DEV_DESTROY);
		close(m_pimpl->fd);
	}

	void uinput::send_key(const unsigned short key) {
		input_event ev = {.type = EV_KEY, .code = key, .value = 1};
		gettimeofday(&ev.time, nullptr);
		write(m_pimpl->fd, &ev, sizeof(input_event));
		m_pimpl->syn();
		ev.value = 0;
		write(m_pimpl->fd, &ev, sizeof(input_event));
		m_pimpl->syn();
	}
}
#endif
