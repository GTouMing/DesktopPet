import 'dart:io';

import 'package:desktop_pet/l10n/app_localizations.dart';
import 'package:desktop_pet/platform/windows/settings_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Windows 窗口框架组件。
///
/// 包裹在所有页面的最外层，提供自定义标题栏（关闭按钮）。
/// 移动端不使用此组件。
///
/// 它只出现在**设置窗口**里（悬浮窗不渲染任何窗口装饰），因此关闭即"隐藏回
/// 托盘"，由 [SettingsWindow] 直接作用于本窗口。
///
/// 职责划分：本组件只管那颗自定义的 X 按钮；系统级关闭（Alt+F4 / WM_CLOSE）由
/// `SettingsWindowRoot` 的 WindowListener 统一处理——两处都注册 `onWindowClose`
/// 只会让同一次关闭走两遍 `hide()`。
class WindowFrame extends StatelessWidget {
  const WindowFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) return child;

    return Column(
      children: [
        _buildTitleBar(context),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onPanStart: (_) => windowManager.startDragging(),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context).appName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              _WindowButton(
                icon: Icons.close,
                onPressed: () async {
                  await SettingsWindow.hide();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 40,
      child: InkWell(
        onTap: onPressed,
        hoverColor:
            Colors.red.withValues(alpha: 0.15),
        child: Center(
          child: Icon(
            icon,
            size: 16,
            color: Colors.red.shade400,
          ),
        ),
      ),
    );
  }
}
