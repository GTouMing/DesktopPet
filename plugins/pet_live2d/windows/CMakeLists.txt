# In-repo Live2D (Cubism) renderer.
#
# Deliberately not a copy of live2d_flutter's architecture: the model lifecycle
# is owned by a process-wide runtime keyed by `petId`, render targets are
# allocated once at a fixed capacity, and the visible region is reported via the
# descriptor's visible_width/visible_height - so resizing a pet neither
# recreates the shared texture nor reloads the model.
#
# The Cubism SDK subset is fetched (never committed) by:
#   powershell -ExecutionPolicy Bypass -File tool/fetch_live2d_sdk.ps1

cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "pet_live2d")
project(${PROJECT_NAME} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(PLUGIN_NAME "pet_live2d_plugin")

# ---- Cubism SDK subset (gitignored, fetched at setup) ----------------------
# Flutter symlinks this plugin into windows/flutter/ephemeral/.plugin_symlinks/,
# so resolve the real path before walking up to the repo root - a plain
# ABSOLUTE would resolve against the symlink and land inside that mirror dir.
get_filename_component(PLUGIN_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/.." REALPATH)
get_filename_component(REPO_ROOT "${PLUGIN_ROOT}/../.." REALPATH)
set(LIVE2D_ROOT "${REPO_ROOT}/third_party/live2d")
set(CORE_INCLUDE_PATH "${LIVE2D_ROOT}/android/src/main/cpp/CubismCore/include")
set(FRAMEWORK_PATH "${LIVE2D_ROOT}/android/src/main/cpp/CubismFramework")
set(CORE_LIBRARY_PATH "${LIVE2D_ROOT}/windows/libs/x86_64/143")

if(NOT EXISTS "${FRAMEWORK_PATH}/CubismFramework.hpp")
  message(FATAL_ERROR
    "Cubism SDK subset missing at ${LIVE2D_ROOT}.\n"
    "Fetch it first:  powershell -ExecutionPolicy Bypass -File tool/fetch_live2d_sdk.ps1")
endif()

add_library(Live2DCubismCore STATIC IMPORTED)
# The app declares CMAKE_CONFIGURATION_TYPES as Debug;Profile;Release, so every
# one of those needs a location: a missing PROFILE would fail a
# `flutter build windows --profile` (that is what CMake's CMP0111 warns about).
# Debug links the debug CRT build of the Core (MDd), the others link MD.
set_target_properties(Live2DCubismCore PROPERTIES
  IMPORTED_LOCATION_DEBUG          "${CORE_LIBRARY_PATH}/Live2DCubismCore_MDd.lib"
  IMPORTED_LOCATION_RELEASE        "${CORE_LIBRARY_PATH}/Live2DCubismCore_MD.lib"
  IMPORTED_LOCATION_PROFILE        "${CORE_LIBRARY_PATH}/Live2DCubismCore_MD.lib"
  IMPORTED_LOCATION_RELWITHDEBINFO "${CORE_LIBRARY_PATH}/Live2DCubismCore_MD.lib"
  IMPORTED_LOCATION_MINSIZEREL     "${CORE_LIBRARY_PATH}/Live2DCubismCore_MD.lib"
  INTERFACE_INCLUDE_DIRECTORIES    "${CORE_INCLUDE_PATH}"
)

# Only the D3D11 renderer backend is needed on Windows.
file(GLOB_RECURSE FRAMEWORK_SOURCES CONFIGURE_DEPENDS
  "${FRAMEWORK_PATH}/*.cpp"
)
list(FILTER FRAMEWORK_SOURCES EXCLUDE REGEX ".*/Rendering/D3D9/.*")
list(FILTER FRAMEWORK_SOURCES EXCLUDE REGEX ".*/Rendering/OpenGL/.*")
list(FILTER FRAMEWORK_SOURCES EXCLUDE REGEX ".*/Rendering/Metal/.*")
list(FILTER FRAMEWORK_SOURCES EXCLUDE REGEX ".*/Rendering/Vulkan/.*")

add_library(CubismFramework STATIC ${FRAMEWORK_SOURCES})
target_include_directories(CubismFramework
  PUBLIC "${FRAMEWORK_PATH}"
  PRIVATE "${CORE_INCLUDE_PATH}"
)
target_compile_options(CubismFramework PRIVATE /MP)
target_link_libraries(CubismFramework
  PUBLIC Live2DCubismCore
  PRIVATE d3d11.lib d3dcompiler.lib
)

# ---- plugin ---------------------------------------------------------------
add_library(${PLUGIN_NAME} SHARED
  "include/pet_live2d/pet_live2d_plugin_c_api.h"
  "pet_live2d_plugin_c_api.cpp"
  "pet_live2d_plugin.cpp"
  "pet_live2d_plugin.h"
  "src/live2d_allocator.cpp"
  "src/live2d_allocator.h"
  "src/live2d_instance.cpp"
  "src/live2d_instance.h"
  "src/live2d_log.cpp"
  "src/live2d_log.h"
  "src/live2d_model.cpp"
  "src/live2d_model.h"
  "src/live2d_pal.cpp"
  "src/live2d_pal.h"
  "src/live2d_runtime.cpp"
  "src/live2d_runtime.h"
  "src/live2d_texture_manager.cpp"
  "src/live2d_texture_manager.h"
)

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE
  FLUTTER_PLUGIN_IMPL
  _CRT_SECURE_NO_WARNINGS
)
target_include_directories(${PLUGIN_NAME}
  INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include"
  PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${CORE_INCLUDE_PATH}"
    "${FRAMEWORK_PATH}"
    # stb_image.h ships at the SDK's cpp root (the old plugin did the same).
    "${LIVE2D_ROOT}/android/src/main/cpp"
)
target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  flutter_wrapper_plugin
  CubismFramework
  Live2DCubismCore
  d3d11.lib
  d3dcompiler.lib
  dxgi.lib
)

# CubismRenderer_D3D11 loads its HLSL effect files from disk at runtime, next to
# the binary (and next to the runner, which is where the app exe lives).
add_custom_command(TARGET ${PLUGIN_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    "${FRAMEWORK_PATH}/Rendering/D3D11/Shaders"
    "$<TARGET_FILE_DIR:${PLUGIN_NAME}>/FrameworkShaders"
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    "${FRAMEWORK_PATH}/Rendering/D3D11/Shaders"
    "${CMAKE_BINARY_DIR}/runner/$<CONFIG>/FrameworkShaders"
)

set(pet_live2d_bundled_libraries "" PARENT_SCOPE)
