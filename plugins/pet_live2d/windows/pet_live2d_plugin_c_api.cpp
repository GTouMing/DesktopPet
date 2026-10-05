#include "include/pet_live2d/pet_live2d_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "pet_live2d_plugin.h"

void PetLive2dPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  pet_live2d::PetLive2DPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
