#ifndef _MEMORY_ALIGNED_TRANSFER_H
#define _MEMORY_ALIGNED_TRANSFER_H

#include <utility>
#include <string.h>
#include "posix_memalign_xp.h"

namespace core1::memory {
	template <bool COPYABLE = false>
	struct aligned_transfer {
		aligned_transfer() noexcept {};
		aligned_transfer(const size_t capacity, const size_t alignment = 0) noexcept : capacity(capacity), alignment(alignment) {
			if (!alignment) {
				buffer = (unsigned char*)malloc(capacity * sizeof(char));
				if (!buffer) this->capacity = 0;
				else memset(buffer, 0x0, capacity);
			}
			else {
				auto rv = posix_memalign((void **)&buffer, alignment , capacity + alignment);
				if (rv) this->capacity = 0;
				else memset(buffer, 0x0, capacity + alignment);
			}
		}

		aligned_transfer(const aligned_transfer& other) requires (COPYABLE) : aligned_transfer(other.capacity, other.alignment) {
			memcpy(this->buffer, other.buffer, capacity);
		}
		aligned_transfer& operator=(const aligned_transfer& other) requires (COPYABLE) {
			return aligned_transfer(other.capacity, other.alignment);
		}

		aligned_transfer(aligned_transfer&& other) noexcept : buffer(std::move(other.buffer)) {
			used = other.used;
			capacity = other.capacity;
			alignment = other.alignment;
			other.buffer = nullptr;
		};
		aligned_transfer& operator=(aligned_transfer&& other) noexcept {
			buffer = std::move(other.buffer);
			used = other.used;
			capacity = other.capacity;
			alignment = other.alignment;
			other.buffer = nullptr;
			return *this;
		};

		virtual ~aligned_transfer() {
			if (buffer && capacity) free(buffer);
		}

		unsigned char* buffer = nullptr;
		ssize_t used = 0;
		size_t capacity = 0;
		size_t alignment;
	};
}
#endif
