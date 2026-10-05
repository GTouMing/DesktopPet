#include "live2d_pal.h"

#include <windows.h>

#include <climits>
#include <cstdio>
#include <string>

namespace pet_live2d::pal {
namespace {

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) return {};
  const int length =
      MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, nullptr, 0);
  if (length <= 0) return {};
  std::wstring result(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, result.data(), length);
  result.resize(static_cast<size_t>(length - 1));
  return result;
}

/// Absolute paths pass through; relative ones resolve against the executable.
std::wstring ResolveFilePath(const std::string& file_path) {
  std::wstring path = Utf8ToWide(file_path);
  if (path.empty() || path.front() == L'\\' || path.front() == L'/' ||
      (path.size() >= 2 && path[1] == L':')) {
    return path;
  }

  wchar_t executable_path[MAX_PATH] = {};
  const DWORD length = GetModuleFileNameW(nullptr, executable_path, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) return path;
  std::wstring base(executable_path, length);
  const size_t separator = base.find_last_of(L"\\/");
  if (separator == std::wstring::npos) return path;
  base.resize(separator + 1);
  return base + path;
}

}  // namespace

Csm::csmByte* LoadFileAsBytes(std::string file_path,
                              Csm::csmSizeInt* out_size) {
  *out_size = 0;
  const std::wstring wide_path = ResolveFilePath(file_path);
  if (wide_path.empty()) return nullptr;

  FILE* file = nullptr;
  if (_wfopen_s(&file, wide_path.c_str(), L"rb") != 0 || !file) return nullptr;

  _fseeki64(file, 0, SEEK_END);
  const __int64 length = _ftelli64(file);
  _fseeki64(file, 0, SEEK_SET);
  if (length <= 0 || length > INT_MAX) {
    fclose(file);
    return nullptr;
  }

  auto* bytes = new Csm::csmByte[static_cast<size_t>(length)];
  const size_t read = fread(bytes, 1, static_cast<size_t>(length), file);
  fclose(file);
  if (read != static_cast<size_t>(length)) {
    delete[] bytes;
    return nullptr;
  }
  *out_size = static_cast<Csm::csmSizeInt>(length);
  return bytes;
}

void ReleaseBytes(Csm::csmByte* bytes) { delete[] bytes; }

}  // namespace pet_live2d::pal
