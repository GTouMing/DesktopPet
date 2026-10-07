import 'dart:io';

import 'package:desktop_pet/l10n/app_localizations.dart';
import 'package:desktop_pet/platform/windows/settings_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/app_theme.dart';

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

  static const double _titleBarHeight = 44;

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      child: GestureDetector(
        onPanStart: (_) => windowManager.startDragging(),
        child: Container(
          height: _titleBarHeight,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Row(
            children: [
              const SizedBox(width: Insets.md),
              Icon(Icons.pets_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: Insets.sm),
              Text(
                AppLocalizations.of(context).appName,
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              _CloseButton(onPressed: () => SettingsWindow.hide()),
            ],
          ),
        ),
      ),
    );
  }
}

/// 关闭键：悬停时转成危险色，明确"这一下会关掉窗口"。
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: const Icon(Icons.close_rounded, size: 16),
      onPressed: onPressed,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll<Size>(
          Size(WindowFrame._titleBarHeight, WindowFrame._titleBarHeight),
        ),
        padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.zero),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(),
        ),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.hovered)
              ? scheme.error
              : scheme.onSurfaceVariant;
        }),
        overlayColor: WidgetStatePropertyAll<Color>(
          scheme.error.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}
