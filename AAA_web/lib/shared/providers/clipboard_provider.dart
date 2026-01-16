import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/services/clipboard_image_service.dart';
import 'package:ASPN_AI_AGENT/shared/providers/attachment_provider.dart';

// 클립보드 처리 상태
enum ClipboardStatus {
  idle,
  loading,
  success,
  error,
}

// 클립보드 상태 클래스
class ClipboardState {
  final ClipboardStatus status;
  final String? message;
  final bool isProcessing;

  const ClipboardState({
    this.status = ClipboardStatus.idle,
    this.message,
    this.isProcessing = false,
  });

  ClipboardState copyWith({
    ClipboardStatus? status,
    String? message,
    bool? isProcessing,
  }) {
    return ClipboardState(
      status: status ?? this.status,
      message: message ?? this.message,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

// 클립보드 상태 관리 Notifier
class ClipboardNotifier extends StateNotifier<ClipboardState> {
  final Ref ref;

  ClipboardNotifier(this.ref) : super(const ClipboardState());

  /// 🚀 통합된 클립보드 처리 - 텍스트 우선, 이미지 후순위
  Future<void> handleClipboardPaste() async {
    if (state.isProcessing) return;

    state = state.copyWith(
      status: ClipboardStatus.loading,
      isProcessing: true,
      message: '클립보드 확인 중...',
    );

    try {
      // 1. 먼저 텍스트 데이터 확인
      final textData = await ClipboardImageService.getClipboardText();
      if (textData != null && textData.isNotEmpty) {
        // 텍스트가 있으면 이미지 처리 건너뛰기
        state = state.copyWith(
          status: ClipboardStatus.idle,
          isProcessing: false,
          message: null,
        );
        return;
      }

      // 2. 텍스트가 없으면 이미지 처리 시도
      final clipboardFile = await ClipboardImageService.getClipboardImage();

      if (clipboardFile != null) {
        // AttachmentProvider에 파일 추가
        final attachmentNotifier = ref.read(attachmentProvider.notifier);
        attachmentNotifier.addCustomFile(clipboardFile);

        state = state.copyWith(
          status: ClipboardStatus.success,
          isProcessing: false,
          message: '이미지가 성공적으로 첨부되었습니다! (${clipboardFile.name})',
        );
      } else {
        // 텍스트도 이미지도 없는 경우
        state = state.copyWith(
          status: ClipboardStatus.idle,
          isProcessing: false,
          message: null,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: ClipboardStatus.error,
        isProcessing: false,
        message: '클립보드 처리 중 오류가 발생했습니다: $e',
      );
    }

    // 3초 후 상태 초기화
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        state = const ClipboardState();
      }
    });
  }

  /// 🔧 기존 이미지 전용 처리 메서드 (하위 호환성)
  Future<void> handleClipboardImage() async {
    await handleClipboardPaste();
  }

  /// 상태 초기화
  void reset() {
    state = const ClipboardState();
  }

  /// 임시 파일 정리
  Future<void> cleanupTempFiles() async {
    try {
      await ClipboardImageService.cleanupTempImages();
    } catch (e) {
      print('임시 파일 정리 오류: $e');
    }
  }
}

// 클립보드 프로바이더
final clipboardProvider =
    StateNotifierProvider<ClipboardNotifier, ClipboardState>((ref) {
  return ClipboardNotifier(ref);
});

// 클립보드 처리 헬퍼 함수들
class ClipboardHelper {
  /// 키 이벤트가 Ctrl+V인지 확인
  static bool isCtrlV(String key, bool isControlPressed) {
    return key.toLowerCase() == 'v' && isControlPressed;
  }

  /// 플랫폼별 스크린샷 키 조합 가져오기
  static String getScreenshotKeyInfo() {
    return ClipboardImageService.defaultScreenshotKey;
  }

  /// 지원되는 이미지 형식 목록
  static List<String> get supportedFormats => ['PNG', 'JPEG', 'JPG'];

  /// 파일 크기를 사람이 읽기 쉬운 형태로 변환
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
