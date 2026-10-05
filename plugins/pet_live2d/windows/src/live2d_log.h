#pragma once

#include <string>

namespace pet_live2d {

/// Appends one line to `l2d_native.log` next to the executable.
///
/// Deliberately a file rather than stdout: it lets the renderer be verified on a
/// normally-launched app (no output redirection, no detached process that the
/// user cannot close).
void LogLine(const std::string& message);

/// Absolute path of [file_name] beside the executable. Diagnostic artefacts
/// (logs, dumps) live there so they are easy to find and never mixed with user
/// data.
std::wstring PathBesideExecutable(const wchar_t* file_name);

}  // namespace pet_live2d
