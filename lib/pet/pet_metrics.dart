import 'dart:ui';

import '../core/constants.dart';
import '../storage/models/pet_config.dart';
import '../storage/models/settings_model.dart';
import 'pet_size.dart';

/// 桌宠渲染值的派生：**全局基础值 × 该宠乘数**。
///
/// 全是纯函数——不读存储、不碰窗口。"最终值怎么算"只有这一处：桌宠运行时、
/// Android 窗口创建、编辑页校验共用同一套（缩放上限见 [finalScaleOf]）。

/// 最终不透明度。
double petOpacity(SettingsModel global, PetConfig? pet) =>
    global.baseOpacity * (pet?.opacityMultiplier ?? 1.0);

/// 最终动画播放速度。
double petSpeed(SettingsModel global, PetConfig? pet) =>
    global.baseSpeed * (pet?.speedMultiplier ?? 1.0);

/// 最终渲染尺寸：基帧 × 最终缩放（收敛到 [maxFinalScale]），再等比收敛到
/// [screen] 内（见 [fitPetSize]）。
///
/// [pet] 为 null（尚未落库）时乘数按 1.0。
Size petRenderSize({
  required Size baseFrame,
  required SettingsModel global,
  required PetConfig? pet,
  required Size screen,
}) {
  final scale = finalScaleOf(global.baseScale, pet?.scaleMultiplier ?? 1.0);
  final wanted = Size(baseFrame.width * scale, baseFrame.height * scale);
  return fitPetSize(spriteSize: wanted, maxSize: screen);
}
