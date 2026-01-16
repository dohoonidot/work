import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowControls extends StatelessWidget {
  final Color? iconColor;

  const WindowControls({super.key, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 최소화 버튼
        IconButton(
          icon: Icon(Icons.minimize,
              size: 16, color: iconColor ?? Colors.white70),
          onPressed: () => windowManager.minimize(),
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          splashRadius: 20,
        ),
        // 최대화/복원 버튼
        IconButton(
          icon: Icon(Icons.crop_square,
              size: 16, color: iconColor ?? Colors.white70),
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          splashRadius: 20,
        ),
        // 종료 버튼
        IconButton(
          icon: Icon(Icons.close, size: 16, color: iconColor ?? Colors.white70),
          onPressed: () => windowManager.close(),
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          splashRadius: 20,
        ),
      ],
    );
  }
}
