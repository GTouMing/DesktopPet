import 'dart:ui';

import 'package:desktop_pet/pet/pet_metrics.dart';
import 'package:desktop_pet/storage/models/pet_config.dart';
import 'package:desktop_pet/storage/models/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

PetConfig _pet({
  double scale = 1.0,
  double opacity = 1.0,
  double speed = 1.0,
}) =>
    PetConfig(id: 'p', name: 'p')
      ..scaleMultiplier = scale
      ..opacityMultiplier = opacity
      ..speedMultiplier = speed;

void main() {
  test('不透明度 / 速度 = 全局基础值 × 该宠乘数', () {
    final global = SettingsModel(baseOpacity: 0.8, baseSpeed: 2.0);
    final pet = _pet(opacity: 0.5, speed: 0.5);

    expect(petOpacity(global, pet), closeTo(0.4, 1e-9));
    expect(petSpeed(global, pet), closeTo(1.0, 1e-9));
  });

  test('缺少桌宠配置时乘数按 1.0', () {
    final global = SettingsModel(baseOpacity: 0.8, baseSpeed: 1.5);

    expect(petOpacity(global, null), closeTo(0.8, 1e-9));
    expect(petSpeed(global, null), closeTo(1.5, 1e-9));
  });

  test('渲染尺寸 = 基帧 × 最终缩放', () {
    final size = petRenderSize(
      baseFrame: const Size(100, 50),
      global: SettingsModel(baseScale: 2.0),
      pet: _pet(),
      screen: const Size(1000, 1000),
    );

    expect(size, const Size(200, 100));
  });

  test('最终缩放收敛到 maxFinalScale', () {
    // 2.0 × 3.0 = 6.0，应收敛到上限 3.0。
    final size = petRenderSize(
      baseFrame: const Size(100, 100),
      global: SettingsModel(baseScale: 2.0),
      pet: _pet(scale: 3.0),
      screen: const Size(1000, 1000),
    );

    expect(size, const Size(300, 300));
  });

  test('超出屏幕时等比缩小', () {
    final size = petRenderSize(
      baseFrame: const Size(2000, 1000),
      global: SettingsModel(),
      pet: null,
      screen: const Size(800, 800),
    );

    expect(size, const Size(800, 400));
  });
}
