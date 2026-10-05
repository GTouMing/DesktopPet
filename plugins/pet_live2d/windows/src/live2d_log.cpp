#include "live2d_log.h"

#include <windows.h>

#include <cstdio>
#include <mutex>

namespace pet_live2d {
namespace {

std::mutex g_log_mutex;

}  // namespace

std::wstring PathBesideExecutable(const wchar_t* file_name) {
  wchar_t executable_path[MAX_PATH] = {};
  const DWORD length = GetModuleFileNameW(nullptr, executable_path, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) return file_name;
  std::wstring path(executable_path, length);
  const size_t separator = path.find_last_of(L"\\/");
  if (separator == std::wstring::npos) return file_name;
  path.resize(separator + 1);
  path += file_name;
  return path;
}

void LogLine(const std::string& message) {
  std::lock_guard<std::mutex> lock(g_log_mutex);
  FILE* file = nullptr;
  if (_wfopen_s(&file, PathBesideExecutable(L"l2d_native.log").c_str(), L"ab") !=
          0 ||
      !file) {
    return;
  }
  fwrite(message.data(), 1, message.size(), file);
  fputc('\n', file);
  fclose(file);
}

}  // namespace pet_live2d
