import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

// Alert Ticker 상태 클래스
class AlertTickerState {
  final String message;
  final bool isVisible;
  final DateTime? showTime;

  AlertTickerState({
    this.message = '',
    this.isVisible = false,
    this.showTime,
  });

  AlertTickerState copyWith({
    String? message,
    bool? isVisible,
    DateTime? showTime,
  }) {
    return AlertTickerState(
      message: message ?? this.message,
      isVisible: isVisible ?? this.isVisible,
      showTime: showTime ?? this.showTime,
    );
  }
}

// Alert Ticker 상태 관리 Notifier
class AlertTickerNotifier extends StateNotifier<AlertTickerState> {
  Timer? _hideTimer;

  AlertTickerNotifier() : super(AlertTickerState());

  // 메시지 표시
  void showMessage(String message, {Duration? displayDuration}) {
    print('🎪 [ALERT_TICKER] ===== showMessage 호출 =====');
    print('🎪 [ALERT_TICKER] 입력 메시지: "$message"');
    print('🎪 [ALERT_TICKER] 메시지 길이: ${message.length}');
    print('🎪 [ALERT_TICKER] displayDuration: $displayDuration');

    if (message.isEmpty) {
      print('❌ [ALERT_TICKER] 메시지가 비어있어서 표시하지 않습니다.');
      return;
    }

    // 기존 타이머 취소
    _hideTimer?.cancel();

    // 새 메시지 설정
    state = state.copyWith(
      message: message,
      isVisible: true,
      showTime: DateTime.now(),
    );

    print('🎪 [ALERT_TICKER] 상태 업데이트 완료:');
    print('   - message: "${state.message}"');
    print('   - isVisible: ${state.isVisible}');
    print('   - showTime: ${state.showTime}');

    // 자동 숨김 타이머 설정 (기본 5초)
    Duration duration = displayDuration ?? const Duration(seconds: 5);
    print('🎪 [ALERT_TICKER] 자동 숨김 타이머 설정: $duration');

    _hideTimer = Timer(duration, () {
      print('🎪 [ALERT_TICKER] 자동 숨김 타이머 실행');
      hideMessage();
    });

    print('🎪 [ALERT_TICKER] ===== showMessage 완료 =====');
  }

  // 메시지 숨김
  void hideMessage() {
    _hideTimer?.cancel();
    state = state.copyWith(
      message: '',
      isVisible: false,
      showTime: null,
    );
    print('🎪 Alert Ticker: 메시지 숨김');
  }

  // 즉시 메시지 변경 (기존 타이머 유지)
  void updateMessage(String message) {
    if (state.isVisible) {
      state = state.copyWith(message: message);
      print('🎪 Alert Ticker: 메시지 업데이트 - "$message"');
    }
  }

  // 현재 표시 중인지 확인
  bool get isShowing => state.isVisible && state.message.isNotEmpty;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }
}

// Alert Ticker Provider
final alertTickerProvider =
    StateNotifierProvider<AlertTickerNotifier, AlertTickerState>((ref) {
  return AlertTickerNotifier();
});

// 메시지만 간단히 접근할 수 있는 Provider
final alertTickerMessageProvider = Provider<String>((ref) {
  final tickerState = ref.watch(alertTickerProvider);
  return tickerState.isVisible ? tickerState.message : '';
});

// 표시 상태만 확인할 수 있는 Provider
final alertTickerVisibilityProvider = Provider<bool>((ref) {
  final tickerState = ref.watch(alertTickerProvider);
  return tickerState.isVisible;
});
