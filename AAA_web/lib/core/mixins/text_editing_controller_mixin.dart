import 'package:flutter/material.dart';

mixin TextEditingControllerMixin<T extends StatefulWidget> on State<T> {
  final Map<String, TextEditingController> _controllers = {};

  TextEditingController getController(String key, {String? text}) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: text);
    }
    return _controllers[key]!;
  }

  void disposeController(String key) {
    try {
      _controllers[key]?.dispose();
    } catch (e) {
      // 이미 dispose된 컨트롤러는 무시
      print('disposeController 중 오류 무시: $e');
    }
    _controllers.remove(key);
  }

  @override
  void dispose() {
    _controllers.forEach((key, controller) {
      try {
        controller.dispose();
      } catch (e) {
        // 이미 dispose된 컨트롤러는 무시
        print('TextEditingController dispose 중 오류 무시: $e');
      }
    });
    _controllers.clear();
    super.dispose();
  }
}
