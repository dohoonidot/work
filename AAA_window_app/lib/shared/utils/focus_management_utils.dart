import 'package:flutter/material.dart';

/// 포커스 관리 관련 공통 유틸리티 클래스
/// 텍스트 필드 포커스 제어의 중복 로직을 통합하여 관리
class FocusManagementUtils {
  /// 지연된 포커스 요청
  /// 파일 첨부, 모달 닫기 등의 작업 후 텍스트 필드로 포커스를 이동할 때 사용
  static void requestFocusDelayed(
    FocusNode focusNode, {
    int delayMs = 100,
  }) {
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (focusNode.canRequestFocus) {
        focusNode.requestFocus();
      }
    });
  }

  /// 즉시 포커스 요청 (안전한 포커스 요청)
  static void requestFocusIfPossible(FocusNode focusNode) {
    if (focusNode.canRequestFocus) {
      focusNode.requestFocus();
    }
  }

  /// 포커스 해제
  static void unfocus(FocusNode focusNode) {
    if (focusNode.hasFocus) {
      focusNode.unfocus();
    }
  }

  /// 여러 포커스 노드 일괄 해제
  static void unfocusAll(List<FocusNode> focusNodes) {
    for (final focusNode in focusNodes) {
      unfocus(focusNode);
    }
  }

  /// 조건부 포커스 요청
  /// 특정 조건을 만족할 때만 포커스를 요청
  static void requestFocusIf(
    FocusNode focusNode,
    bool condition, {
    int delayMs = 0,
  }) {
    if (!condition) return;

    if (delayMs > 0) {
      requestFocusDelayed(focusNode, delayMs: delayMs);
    } else {
      requestFocusIfPossible(focusNode);
    }
  }

  /// 포커스 요청과 동시에 커서를 텍스트 끝으로 이동
  /// TextEditingController가 있는 경우 커서 위치를 텍스트의 맨 끝으로 설정
  static void requestFocusWithCursorAtEnd(
    FocusNode focusNode,
    TextEditingController controller, {
    int delayMs = 100,
  }) {
    Future.delayed(Duration(milliseconds: delayMs), () {
      // dispose 체크 추가 - try-catch로 안전하게 처리
      if (focusNode.canRequestFocus) {
        try {
          focusNode.requestFocus();
          // 포커스 후 커서를 텍스트 끝으로 이동 (dispose 체크 후)
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
        } catch (e) {
          // dispose된 경우 조용히 무시
          print('⚠️ TextEditingController가 이미 dispose됨: $e');
        }
      }
    });
  }

  /// 즉시 포커스 요청과 커서 위치 설정
  static void requestFocusWithCursorAtEndImmediate(
    FocusNode focusNode,
    TextEditingController controller,
  ) {
    if (focusNode.canRequestFocus) {
      try {
        focusNode.requestFocus();
        // 포커스 후 커서를 텍스트 끝으로 이동 (dispose 체크 후)
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      } catch (e) {
        // dispose된 경우 조용히 무시
        print('⚠️ TextEditingController가 이미 dispose됨: $e');
      }
    }
  }

  /// 다음 포커스로 이동
  static void nextFocus(BuildContext context) {
    FocusScope.of(context).nextFocus();
  }

  /// 이전 포커스로 이동
  static void previousFocus(BuildContext context) {
    FocusScope.of(context).previousFocus();
  }

  /// 포커스 스코프 해제
  static void unfocusScope(BuildContext context) {
    FocusScope.of(context).unfocus();
  }
}
