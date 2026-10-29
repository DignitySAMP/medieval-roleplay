// Copyright (c) 2013-2015 Zeex
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#if defined CRASHDETECT_INC
	#endinput
#endif
#define CRASHDETECT_INC

native PrintBacktrace();
native PrintNativeBacktrace();

native GetBacktrace(string[], size = sizeof(string));
native GetNativeBacktrace(string[], size = sizeof(string));

#pragma deprecated Use `PrintBacktrace`
native PrintAmxBacktrace() = PrintBacktrace;

#pragma deprecated Use `GetBacktrace`
native GetAmxBacktrace(string[], size = sizeof(string)) = GetBacktrace;

forward OnRuntimeError(code, &bool:suppress);

stock bool:IsCrashDetectPresent() {
	#emit zero.pri
	#emit lctrl 0xFF
	#emit not
	#emit not
	#emit retn
	return false;
}

stock SetCrashDetectLongCallTime(us_time) {
	#emit load.s.pri us_time
	#emit sctrl 0xFE
}

stock GetCrashDetectLongCallTime() {
	#emit zero.pri
	#emit lctrl 0xFE
	#emit retn
	return 0;
}

stock DisableCrashDetectLongCall() {
	#emit const.pri 32
	#emit sctrl 0xFF
}

stock EnableCrashDetectLongCall() {
	#emit const.pri 34
	#emit sctrl 0xFF
}

stock ResetCrashDetectLongCallTime() {
	#emit const.pri 36
	#emit sctrl 0xFF
}

stock RestartCrashDetectLongCall() {
	#emit const.pri 40
	#emit sctrl 0xFF
}

stock bool:IsCrashDetectLongCallEnabled() {
	#emit zero.pri
	#emit lctrl 0xFF
	#emit shr.c.pri 1
	#emit const.alt 1
	#emit and
	#emit retn
	return false;
}

stock bool:HasCrashDetectLongCall() {
	#emit zero.pri
	#emit lctrl 0xFF
	#emit shr.c.pri 5
	#emit const.alt 1
	#emit and
	#emit retn
	return false;
}

stock GetCrashDetectDefaultTime() {
	#emit lctrl 0xFE
	#emit move.alt
	#emit const.pri 36
	#emit sctrl 0xFF
	#emit lctrl 0xFE
	#emit xchg
	#emit sctrl 0xFE
	#emit move.pri
	#emit retn
	return 0;
}

stock DisableCrashDetectAddr0() {
	#emit const.pri 64
	#emit sctrl 0xFF
}

stock EnableCrashDetectAddr0() {
	#emit const.pri 192
	#emit sctrl 0xFF
}

stock bool:IsCrashDetectAddr0Enabled() {
	#emit zero.pri
	#emit lctrl 0xFF
	#emit shr.c.pri 7
	#emit const.alt 1
	#emit and
	#emit retn
	return false;
}

stock bool:HasCrashDetectAddr0() {
	#emit zero.pri
	#emit lctrl 0xFF
	#emit shr.c.pri 6
	#emit const.alt 1
	#emit and
	#emit retn
	return false;
}
