#include "crash_handler.h"

#include <windows.h>

#include <dbghelp.h>
#include <strsafe.h>

#include <cstdint>

namespace crash_handler {
namespace {

constexpr int kMaxFrames = 62;

// Builds "<LOCALAPPDATA>\desktop_pet\crash-<yyyyMMdd-HHmmss>".
bool BuildBasePath(wchar_t* out_path, size_t out_chars) {
  wchar_t local_app_data[MAX_PATH] = {};
  const DWORD len =
      GetEnvironmentVariableW(L"LOCALAPPDATA", local_app_data, MAX_PATH);
  if (len == 0 || len >= MAX_PATH) {
    return false;
  }

  wchar_t dir[MAX_PATH] = {};
  if (FAILED(StringCchPrintfW(dir, ARRAYSIZE(dir), L"%s\\desktop_pet",
                              local_app_data))) {
    return false;
  }
  CreateDirectoryW(dir, nullptr);

  SYSTEMTIME st{};
  GetLocalTime(&st);
  return SUCCEEDED(StringCchPrintfW(
      out_path, out_chars, L"%s\\crash-%04u%02u%02u-%02u%02u%02u", dir,
      static_cast<unsigned>(st.wYear), static_cast<unsigned>(st.wMonth),
      static_cast<unsigned>(st.wDay), static_cast<unsigned>(st.wHour),
      static_cast<unsigned>(st.wMinute), static_cast<unsigned>(st.wSecond)));
}

void WriteText(HANDLE file, const wchar_t* text) {
  if (file == INVALID_HANDLE_VALUE || text == nullptr) {
    return;
  }
  const int chars = lstrlenW(text);
  if (chars <= 0) {
    return;
  }
  DWORD written = 0;
  WriteFile(file, text, static_cast<DWORD>(chars) * sizeof(wchar_t), &written,
            nullptr);
}

// Writes "<label> <address>  <module>+0x<offset>".
void WriteModuleOf(HANDLE file, const void* address, const wchar_t* label) {
  wchar_t line[MAX_PATH * 2] = {};
  HMODULE module = nullptr;
  const BOOL found = GetModuleHandleExW(
      GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
          GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
      reinterpret_cast<LPCWSTR>(address), &module);
  if (found && module != nullptr) {
    wchar_t module_path[MAX_PATH] = {};
    GetModuleFileNameW(module, module_path, ARRAYSIZE(module_path));
    const wchar_t* base_name = module_path;
    for (const wchar_t* p = module_path; *p != L'\0'; ++p) {
      if (*p == L'\\' || *p == L'/') {
        base_name = p + 1;
      }
    }
    const unsigned long long offset =
        static_cast<unsigned long long>(reinterpret_cast<uintptr_t>(address) -
                                        reinterpret_cast<uintptr_t>(module));
    StringCchPrintfW(line, ARRAYSIZE(line), L"%s %p  %s+0x%llX\r\n", label,
                     address, base_name, offset);
  } else {
    StringCchPrintfW(line, ARRAYSIZE(line), L"%s %p  <unknown module>\r\n",
                     label, address);
  }
  WriteText(file, line);
}

using MiniDumpWriteDumpFn = BOOL(WINAPI*)(HANDLE, DWORD, HANDLE, MINIDUMP_TYPE,
                                          PMINIDUMP_EXCEPTION_INFORMATION,
                                          PMINIDUMP_USER_STREAM_INFORMATION,
                                          PMINIDUMP_CALLBACK_INFORMATION);

void WriteMiniDump(const wchar_t* path, EXCEPTION_POINTERS* exception) {
  HMODULE dbghelp = LoadLibraryW(L"dbghelp.dll");
  if (dbghelp == nullptr) {
    return;
  }
  const auto write_dump = reinterpret_cast<MiniDumpWriteDumpFn>(
      GetProcAddress(dbghelp, "MiniDumpWriteDump"));
  if (write_dump == nullptr) {
    return;
  }

  HANDLE file = CreateFileW(path, GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
                            FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return;
  }

  MINIDUMP_EXCEPTION_INFORMATION info{};
  info.ThreadId = GetCurrentThreadId();
  info.ExceptionPointers = exception;
  info.ClientPointers = FALSE;

  const auto type = static_cast<MINIDUMP_TYPE>(
      MiniDumpWithDataSegs | MiniDumpWithHandleData | MiniDumpWithThreadInfo |
      MiniDumpWithUnloadedModules);
  write_dump(GetCurrentProcess(), GetCurrentProcessId(), file, type, &info,
             nullptr, nullptr);
  CloseHandle(file);
}

LONG WINAPI Handler(EXCEPTION_POINTERS* exception) {
  wchar_t base_path[MAX_PATH] = {};
  if (!BuildBasePath(base_path, ARRAYSIZE(base_path))) {
    return EXCEPTION_EXECUTE_HANDLER;
  }

  wchar_t log_path[MAX_PATH] = {};
  if (SUCCEEDED(
          StringCchPrintfW(log_path, ARRAYSIZE(log_path), L"%s.log", base_path))) {
    HANDLE log = CreateFileW(log_path, GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
                             FILE_ATTRIBUTE_NORMAL, nullptr);
    if (log != INVALID_HANDLE_VALUE) {
      // UTF-16LE BOM so the log opens correctly in editors.
      const wchar_t bom = L'\uFEFF';
      DWORD bom_written = 0;
      WriteFile(log, &bom, sizeof(bom), &bom_written, nullptr);

      const DWORD code =
          (exception != nullptr && exception->ExceptionRecord != nullptr)
              ? exception->ExceptionRecord->ExceptionCode
              : 0;
      wchar_t line[MAX_PATH * 2] = {};
      StringCchPrintfW(line, ARRAYSIZE(line),
                       L"desktop_pet crash\r\nexception code: 0x%08lX\r\n\r\n",
                       static_cast<unsigned long>(code));
      WriteText(log, line);

      if (exception != nullptr && exception->ExceptionRecord != nullptr) {
        WriteModuleOf(log, exception->ExceptionRecord->ExceptionAddress,
                      L"fault address:");
      }

      void* frames[kMaxFrames] = {};
      const USHORT count = CaptureStackBackTrace(0, kMaxFrames, frames, nullptr);
      StringCchPrintfW(line, ARRAYSIZE(line), L"\r\nstack (%u frames):\r\n",
                       static_cast<unsigned>(count));
      WriteText(log, line);
      for (USHORT i = 0; i < count; ++i) {
        wchar_t label[16] = {};
        StringCchPrintfW(label, ARRAYSIZE(label), L"#%02u",
                         static_cast<unsigned>(i));
        WriteModuleOf(log, frames[i], label);
      }
      FlushFileBuffers(log);
      CloseHandle(log);
    }
  }

  wchar_t dump_path[MAX_PATH] = {};
  if (SUCCEEDED(StringCchPrintfW(dump_path, ARRAYSIZE(dump_path), L"%s.dmp",
                                 base_path))) {
    WriteMiniDump(dump_path, exception);
  }

  return EXCEPTION_EXECUTE_HANDLER;
}

}  // namespace

void Install() { SetUnhandledExceptionFilter(Handler); }

}  // namespace crash_handler
