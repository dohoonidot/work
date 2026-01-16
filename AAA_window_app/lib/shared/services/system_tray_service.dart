import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class SystemTrayService {
  final SystemTray _systemTray = SystemTray();
  final WindowManager _windowManager = WindowManager.instance;

  Future<void> initialize() async {
    try {
      // 시스템 트레이 아이콘 설정
      String iconPath = Platform.isWindows
          ? 'assets/icon/ASPN_AAA_logo.png'
          : 'assets/icon/ASPN_AAA_logo.png';

      await _systemTray.initSystemTray(
        title: "ASPN AI Agent",
        iconPath: iconPath,
        toolTip: "ASPN AI Agent",
      );

      // 메뉴 생성
      final Menu menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(
          label: '앱 표시',
          onClicked: (menuItem) => _showApp(),
        ),
        MenuItemLabel(
          label: '앱 숨기기',
          onClicked: (menuItem) => _hideApp(),
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: '앱 종료',
          onClicked: (menuItem) => _exitApp(),
        ),
      ]);

      // 메뉴 설정
      await _systemTray.setContextMenu(menu);

      // 시스템 트레이 클릭 이벤트 설정
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          _systemTray.popUpContextMenu();
        }
      });
    } catch (e) {
      debugPrint('SystemTray initialization error: $e');
    }
  }

  Future<void> _showApp() async {
    await _windowManager.show();
    await _windowManager.focus();
  }

  Future<void> _hideApp() async {
    await _windowManager.hide();
  }

  Future<void> _exitApp() async {
    await _windowManager.close();
  }
}
