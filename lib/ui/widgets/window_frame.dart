import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Windows 窗口框架组件。
///
/// 包裹在所有页面的最外层，提供自定义标题栏（最小化/最大化/关闭按钮）。
/// 移动端不使用此组件。
class WindowFrame extends StatefulWidget {
  final Widget child;

  const WindowFrame({super.key, required this.child});

  @override
  State<StatefulWidget> createState() => _WindowFrameState();
}

class _WindowFrameState extends State<WindowFrame>
with WindowListener {

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() {
    windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) return widget.child;

    return Column(
      children: [
        _buildTitleBar(context),
        Expanded(child: widget.child),
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
              const Text('Desktop Pet',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              _WindowButton(
                icon: Icons.close,
                onPressed: () async {
                  await windowManager.hide();
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
