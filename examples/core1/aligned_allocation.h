#ifndef _MEMORY_ALIGNED_ALLOCATION_H
#define _MEMORY_ALIGNED_ALLOCATION_H

#include <utility>
#include <string.h>
#include <memory>
#include "posix_memalign_xp.h"

namespace core1 {
	namespace memory {
		template <class T>
		struct delete_aligned {
			void operator()(T *data) const {
				free(data);
			}
		};

		template <class T>
		std::unique_ptr<T[], delete_aligned<T>> allocate_aligned(const size_t length, const size_t alignment) {
			T *raw = 0;
			if (alignment < 1) return nullptr;
			int error = posix_memalign((void **)&raw, alignment, sizeof(T) * length);
			return std::unique_ptr<T[], delete_aligned<T>>{raw};
		}
	}
}
#endif
