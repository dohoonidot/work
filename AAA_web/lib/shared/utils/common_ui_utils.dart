import 'package:flutter/material.dart';

/// 공통 UI 유틸리티 클래스
/// 여러 화면에서 중복되는 UI 로직을 통합하여 관리
class CommonUIUtils {
  /// 테마에 따른 스낵바 색상 결정
  static Color _getSnackBarBackgroundColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? const Color(0xFF475569) // Light 테마: 모던한 슬레이트 블루
        : const Color(0xFF94A3B8); // Dark 테마: 가시성 좋은 밝은 슬레이트
  }

  /// 테마에 따른 스낵바 텍스트 색상 결정
  static Color _getSnackBarTextColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light
        ? Colors.white // Light 테마: 흰색 글씨 (어두운 배경에 대비)
        : const Color(0xFF1E293B); // Dark 테마: 어두운 텍스트 (밝은 배경에 대비)
  }

  /// 에러 스낵바를 표시하는 공통 메서드
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: _getSnackBarTextColor(context)),
        ),
        backgroundColor: _getSnackBarBackgroundColor(context),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// 성공 스낵바를 표시하는 공통 메서드
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: _getSnackBarTextColor(context)),
        ),
        backgroundColor: _getSnackBarBackgroundColor(context),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// 정보 스낵바를 표시하는 공통 메서드
  static void showInfoSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: _getSnackBarTextColor(context)),
        ),
        backgroundColor: _getSnackBarBackgroundColor(context),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// 경고 스낵바를 표시하는 공통 메서드
  static void showWarningSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: _getSnackBarTextColor(context)),
        ),
        backgroundColor: _getSnackBarBackgroundColor(context),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// 확인 다이얼로그를 표시하는 공통 메서드
  static Future<bool?> showConfirmDialog(
    BuildContext context,
    String title,
    String message, {
    String confirmText = '확인',
    String cancelText = '취소',
    Color? confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          title: Text(
            title,
            style: TextStyle(
              color: isDarkTheme ? Colors.white : null,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              color: isDarkTheme ? Colors.grey[300] : null,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: confirmColor ?? Colors.red,
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  /// 삭제 확인 다이얼로그를 표시하는 공통 메서드
  static Future<bool?> showDeleteConfirmDialog(
    BuildContext context,
    String itemName,
  ) {
    return showConfirmDialog(
      context,
      '삭제 확인',
      '$itemName을(를) 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
      confirmText: '삭제',
      cancelText: '취소',
      confirmColor: Colors.red,
    );
  }

  /// 정보 다이얼로그를 표시하는 공통 메서드
  static void showInfoDialog(
    BuildContext context,
    String title,
    String message, {
    String buttonText = '확인',
  }) {
    showDialog(
      context: context,
      builder: (context) {
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          title: Text(
            title,
            style: TextStyle(
              color: isDarkTheme ? Colors.white : null,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              color: isDarkTheme ? Colors.grey[300] : null,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(buttonText),
            ),
          ],
        );
      },
    );
  }

  /// 로딩 다이얼로그를 표시하는 공통 메서드
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: TextStyle(
                      color: isDarkTheme ? Colors.grey[300] : null,
                    ),
                  ),
                ],
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  /// 로딩 다이얼로그를 닫는 공통 메서드
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  /// 텍스트 입력 다이얼로그를 표시하는 공통 메서드
  static Future<String?> showTextInputDialog(
    BuildContext context,
    String title,
    String hintText, {
    String? initialValue,
    String confirmText = '확인',
    String cancelText = '취소',
    int? maxLines = 1,
    TextInputType? keyboardType,
  }) {
    final controller = TextEditingController(text: initialValue);

    return showDialog<String>(
      context: context,
      builder: (context) {
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          title: Text(
            title,
            style: TextStyle(
              color: isDarkTheme ? Colors.white : null,
            ),
          ),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText,
              border: const OutlineInputBorder(),
            ),
            maxLines: maxLines,
            keyboardType: keyboardType,
            autofocus: true,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(cancelText),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.of(context).pop(text.isEmpty ? null : text);
              },
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  /// 공통 패딩 상수
  static const EdgeInsets defaultPadding = EdgeInsets.all(16.0);
  static const EdgeInsets smallPadding = EdgeInsets.all(8.0);
  static const EdgeInsets largePadding = EdgeInsets.all(24.0);

  /// 공통 보더 래디어스 상수
  static const double defaultBorderRadius = 8.0;
  static const double largeBorderRadius = 12.0;
  static const double smallBorderRadius = 4.0;

  /// 공통 애니메이션 지속시간 상수
  static const Duration shortDuration = Duration(milliseconds: 200);
  static const Duration mediumDuration = Duration(milliseconds: 300);
  static const Duration longDuration = Duration(milliseconds: 500);

  /// AI 메시지 정렬 방식 결정 (ChatGPT 스타일 중앙 정렬)
  static Alignment getAiMessageAlignment(Map<String, dynamic> message) {
    // ChatGPT 앱처럼 항상 중앙 정렬 유지
    return Alignment.center;
  }

  /// 리스트 구분선을 생성하는 헬퍼 메서드
  static Widget buildDivider({double height = 1.0, Color? color}) {
    return Divider(
      height: height,
      thickness: height,
      color: color ?? Colors.grey.withValues(alpha: 0.3),
    );
  }

  /// 빈 상태를 표시하는 위젯을 생성하는 헬퍼 메서드
  static Widget buildEmptyState({
    required String message,
    IconData? icon,
    Widget? action,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null)
            Icon(
              icon,
              size: 64,
              color: Colors.grey,
            ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action,
          ],
        ],
      ),
    );
  }
}
