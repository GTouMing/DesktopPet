#ifndef FLUTTER_PLUGIN_PET_LIVE2D_PLUGIN_C_API_H_
#define FLUTTER_PLUGIN_PET_LIVE2D_PLUGIN_C_API_H_

#include <flutter_plugin_registrar.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

// Spelling matches `pluginClass` in pubspec.yaml: the Flutter tool generates the
// call site from that identifier, so it has to be byte-identical.
FLUTTER_PLUGIN_EXPORT void PetLive2dPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_PET_LIVE2D_PLUGIN_C_API_H_
