#ifndef __API_EXPORT_H__
#define __API_EXPORT_H__

#if defined(WIN32) || defined(_WIN32)
#ifdef DLL_EXPORT
	#define API_EXPORT __declspec(dllexport)
#else
	#define API_EXPORT __declspec(dllimport)
#endif
#else
	#define API_EXPORT
#endif

#endif
