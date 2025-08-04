#pragma once
#ifndef _POSIX_MEMALIGN_XP_H
#define _POSIX_MEMALIGN_XP_H

#include <stdlib.h>

namespace core1::memory {
#ifdef _WIN32
#define posix_memalign(p, a, s) (((*(p)) = _aligned_malloc((s), (a))), *(p) ?0 :errno)
#else
#define posix_memalign posix_memalign
#endif
}
#endif
