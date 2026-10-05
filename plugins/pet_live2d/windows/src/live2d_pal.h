#pragma once

#include <CubismFramework.hpp>

#include <string>

namespace pet_live2d::pal {

/// Cubism file-loading callbacks. Paths handed to us are UTF-8; the CRT wants
/// wide chars on Windows, and relative paths are resolved against the app exe.
Csm::csmByte* LoadFileAsBytes(std::string file_path, Csm::csmSizeInt* out_size);
void ReleaseBytes(Csm::csmByte* bytes);

}  // namespace pet_live2d::pal
