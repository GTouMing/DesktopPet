enum PetPackSource { asset, filesystem }

/// 宠物包的渲染类型。
///
/// - [sprite]：精灵图逐帧包（`animations` + 帧图片），见 `SpritePetPack`；
/// - [live2d]：Live2D Cubism 模型包（`.model3.json` + moc3/贴图/动作），
///   见 `Live2DPetPack`。
enum PetPackType { sprite, live2d }