#ifndef RUNNER_CRASH_HANDLER_H_
#define RUNNER_CRASH_HANDLER_H_

namespace crash_handler {

// Installs a process-wide unhandled-exception handler that writes a crash log
// to %LOCALAPPDATA%\desktop_pet\crash-<timestamp>.log containing the exception
// code, faulting address and, for each stack frame, the owning module name and
// offset. A minidump (.dmp) is written alongside it when dbghelp is available.
//
// This exists because Windows Error Reporting is disabled on the target
// machine, so native crashes otherwise leave no trace. Call once, early in
// wWinMain (before the Flutter engine is created).
void Install();

}  // namespace crash_handler

#endif  // RUNNER_CRASH_HANDLER_H_
