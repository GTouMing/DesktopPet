#pragma once

#include <d3d11.h>
#include <wrl/client.h>

#include <memory>
#include <string>
#include <vector>

namespace pet_live2d {

/// Decodes a model's PNG textures into D3D11 and hands the views to the Cubism
/// D3D11 renderer. Ported from live2d_flutter's texture manager.
class Live2DTextureManager {
 public:
  struct TextureInfo {
    Microsoft::WRL::ComPtr<ID3D11Texture2D> texture;
    Microsoft::WRL::ComPtr<ID3D11ShaderResourceView> texture_view;
    int width = 0;
    int height = 0;
    std::string file_name;
  };

  explicit Live2DTextureManager(ID3D11Device* device);
  ~Live2DTextureManager();

  Live2DTextureManager(const Live2DTextureManager&) = delete;
  Live2DTextureManager& operator=(const Live2DTextureManager&) = delete;

  /// Cached by path: loading the same model twice reuses the decoded texture.
  TextureInfo* CreateTextureFromPngFile(const std::string& file_path);
  void ReleaseTextures();

 private:
  Microsoft::WRL::ComPtr<ID3D11Device> device_;
  std::vector<std::unique_ptr<TextureInfo>> textures_;
};

}  // namespace pet_live2d
