#ifndef _INCL_COLANDREAS
#define _INCL_COLANDREAS

#ifdef _MSC_VER
#pragma warning (disable:4005 700 996)
#endif
#if (defined(WIN32) || defined(_WIN32) || defined(_WIN64))
#include <windows.h>
#else
#include "pthread.h"
#endif
#include "sstream"
#if defined(LINUX) || defined(FREEBSD) || defined(__FreeBSD__) || defined(__OpenBSD__)
#include "stdarg.h"
#endif

#ifndef WIN32
typedef unsigned long DWORD;
#define MAX_PATH 250
#endif

typedef void(*logprintf_t)(char* format, ...);
#include <amx/amx.h>
#if defined(LINUX)
#include <alloca.h>
#endif

#undef amx_StrParam
#define amx_StrParam(amx, param, result) \
	do \
	{ \
		cell* amx_cstr_; \
		int amx_length_; \
		amx_GetAddr((amx), (param), &amx_cstr_); \
		amx_StrLen(amx_cstr_, &amx_length_); \
		if (amx_length_ > 0 && ((result) = static_cast<char*>(alloca((amx_length_ + 1) * sizeof(*(result))))) != NULL) \
			amx_GetString(static_cast<char*>(result), amx_cstr_, sizeof(*(result)) > 1, amx_length_ + 1); \
		else \
			(result) = NULL; \
	} while (0)

#include <vector>

extern bool colInit;
extern bool colDataLoaded;
extern cell nullAddress;
extern logprintf_t				logprintf;

#endif