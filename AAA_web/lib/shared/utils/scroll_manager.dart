import 'package:flutter/material.dart';
import 'dart:async';

class ScrollManager {
  final ScrollController scrollController = ScrollController();

  // Function 타입으로 정의 (null일 수 있음을 명시적으로 처리)
  final void Function(bool)? _onScrollPositionChanged;

  // 스크롤 제어를 위한 변수들
  bool _userScrollActive = false; // 사용자가 스크롤 중인지 여부
  bool _isAtBottom = true; // 스크롤이 맨 아래에 있는지 여부
  bool _isUserScrolling = false; // 사용자가 실제로 스크롤하고 있는지 여부
  Timer? _userScrollTimer; // 사용자 스크롤 타이머

  // 스트리밍 자동 스크롤 관련 변수들
  bool _isStreaming = false; // 현재 스트리밍 중인지 여부
  Timer? _streamScrollTimer; // 스트리밍 스크롤 타이머
  bool _wasAtBottomBeforeStream = true; // 스트리밍 시작 전 맨 아래 위치 여부

  // 빠른 스트리밍 대응용 디바운싱/스로틀링
  Timer? _scrollDebounceTimer;
  DateTime? _lastScrollTime;
  bool _isScrolling = false;

  // 생성자
  ScrollManager({void Function(bool)? onScrollPositionChanged})
      : _onScrollPositionChanged = onScrollPositionChanged {
    // 스크롤 리스너 추가
    scrollController.addListener(_scrollListener);
  }

  // 스크롤 리스너 함수
  void _scrollListener() {
    if (!scrollController.hasClients ||
        scrollController.position.maxScrollExtent == 0) return;

    // 스크롤 위치 계산
    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = scrollController.position.pixels;
    final distanceFromBottom = maxScroll - currentScroll;

    // 맨 아래에서 10px 이내면 '맨 아래'로 간주 (더 엄격하게 조정)
    final bool isAtBottom = distanceFromBottom < 10;

    // 이전 상태와 다른 경우에만 콜백 실행 및 상태 업데이트
    if (isAtBottom != _isAtBottom) {
      _isAtBottom = isAtBottom;

      // 콜백이 있으면 실행
      if (_onScrollPositionChanged != null) {
        try {
          _onScrollPositionChanged(isAtBottom);
        } catch (e) {
          print('스크롤 위치 콜백 오류: $e');
        }
      }

      // 맨 아래에 도달하면 사용자 스크롤 모드 비활성화
      if (isAtBottom) {
        _userScrollActive = false;
        _isUserScrolling = false;
      }
    }
  }

  // 사용자 스크롤 감지를 위한 NotificationListener 콜백
  bool onUserScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      // 사용자가 실제로 스크롤하고 있음을 표시
      _isUserScrolling = true;

      // 스크롤 방향 감지
      final ScrollMetrics metrics = notification.metrics;
      final double currentPosition = metrics.pixels;
      final double maxScroll = metrics.maxScrollExtent;
      final double distanceFromBottom = maxScroll - currentPosition;

      // 사용자가 위로 스크롤하면 즉시 자동 스크롤 비활성화
      if (distanceFromBottom > 50 && !_userScrollActive) {
        _userScrollActive = true;
      }

      // 사용자가 아래로 스크롤해서 맨 아래 근처에 왔으면 자동 스크롤 재활성화 (더 엄격한 조건)
      if (distanceFromBottom < 10 && _userScrollActive) {
        _userScrollActive = false;
        _isUserScrolling = false;
      }

      // 기존 타이머 취소
      _userScrollTimer?.cancel();

      // 1초 후에 사용자 스크롤 상태 해제
      _userScrollTimer = Timer(const Duration(seconds: 1), () {
        _isUserScrolling = false;
      });
    }

    return false; // 다른 리스너들도 처리할 수 있도록 false 반환
  }

  // 새 메시지가 추가되었을 때 호출되는 메서드
  void handleNewMessage() {
    // 사용자가 스크롤 중이 아니고 맨 아래에 있을 때만 자동 스크롤
    if (!_userScrollActive && _isAtBottom) {
      scrollToBottom();
    } else if (_userScrollActive) {
      // 사용자가 스크롤 중이므로 자동 스크롤 건너뜀
    }
  }

  // 스트림 완료 시 호출될 메서드
  void onStreamComplete() {
    // 사용자가 스크롤 중이 아니고 스트리밍 시작 전에 맨 아래에 있었을 때만 자동 스크롤
    if (!_userScrollActive && _wasAtBottomBeforeStream) {
      scrollToBottom();
    } else if (_userScrollActive) {
      // 사용자가 스크롤 중이므로 자동 스크롤 건너뜀
    }
  }

  // 맨 아래로 스크롤
  void scrollToBottom() {
    if (!scrollController.hasClients ||
        scrollController.position.maxScrollExtent <= 0) return;

    // UI 스레드에 예약
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;

      try {
        // 현재 위치가 이미 맨 아래 근처인지 확인
        final currentPosition = scrollController.position.pixels;
        final maxScroll = scrollController.position.maxScrollExtent;
        final distanceFromBottom = maxScroll - currentPosition;

        // 스트리밍 중일 때는 더 적극적으로 스크롤
        final threshold = _isStreaming ? 10.0 : 50.0;

        // 이미 맨 아래 threshold 이내에 있으면 스크롤하지 않음
        if (distanceFromBottom <= threshold) {
          return;
        }

        // ChatGPT 스타일 애니메이션 - 스트리밍/일반 상관없이 일관된 경험
        final duration = const Duration(milliseconds: 200);
        final curve = Curves.easeOut;

        scrollController.animateTo(
          maxScroll,
          duration: duration,
          curve: curve,
        );
      } catch (e) {
        print('scrollToBottom 오류: $e');
      }
    });
  }

  // 특정 인덱스로 스크롤 (특정 메시지가 있는 위치로 스크롤)
  void scrollToIndex(int index) {
    if (!scrollController.hasClients) return;

    // UI 스레드에 예약
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 스크롤 위치 계산 (대략적인 추정)
      // 평균 메시지 높이를 100으로 가정
      const double averageMessageHeight = 100.0;
      final double targetPosition = index * averageMessageHeight;

      // 스크롤 범위를 넘지 않게 조정
      final double maxScroll = scrollController.position.maxScrollExtent;
      final double adjustedPosition =
          targetPosition < maxScroll ? targetPosition : maxScroll;

      // 스크롤 애니메이션
      scrollController.animateTo(
        adjustedPosition,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );

      // 사용자 스크롤 모드 활성화 (자동 스크롤 방지)
      _userScrollActive = true;
    });
  }

  // 사용자 스크롤 상태 확인하는 getter
  bool get isUserScrollActive => _userScrollActive;

  // 현재 스크롤이 맨 아래인지 확인하는 getter
  bool get isAtBottom => _isAtBottom;

  // 사용자가 실제로 스크롤하고 있는지 확인하는 getter
  bool get isUserScrolling => _isUserScrolling;

  // 사용자가 직접 맨 아래로 스크롤 버튼을 눌렀을 때
  void userScrollToBottom() {
    if (!scrollController.hasClients ||
        scrollController.position.maxScrollExtent <= 0) return;

    // UI 스레드에 예약
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;

      try {
        // 즉시 맨 아래로 이동 (애니메이션 없이)
        scrollController.jumpTo(scrollController.position.maxScrollExtent);

        // 상태 업데이트
        _userScrollActive = false;
        _isUserScrolling = false;
        _isAtBottom = true;
      } catch (e) {
        print('userScrollToBottom 오류: $e');
      }
    });
  }

  // 사용자 메시지 전송 시 맨 아래로 스크롤 (사용자 메시지와 AI 응답이 잘 보이도록)
  void onUserMessageSent() {
    print('사용자 메시지 전송: 맨 아래로 스크롤하여 대화 흐름 확보');

    // 사용자 스크롤 모드 해제하고 자동 스크롤 활성화
    _userScrollActive = false;
    _isUserScrolling = false;

    // 부드럽게 맨 아래로 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;

      try {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } catch (e) {
        print('onUserMessageSent 스크롤 오류: $e');
      }
    });
  }

  // 스트리밍 시작 - ChatGPT 스타일 자동 스크롤 활성화
  void startStreaming() {
    print('스트리밍 시작: 자동 스크롤 활성화');
    _wasAtBottomBeforeStream = _isAtBottom;
    _isStreaming = true;

    // 사용자가 스크롤 중이 아니고 맨 아래에 있을 때만 자동 스크롤 활성화
    if (_wasAtBottomBeforeStream && !_userScrollActive) {
      // ChatGPT 앱처럼 스트리밍 중 주기적으로 맨 아래 추적
      _streamScrollTimer?.cancel();
      _streamScrollTimer =
          Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (_isStreaming && !_userScrollActive && _wasAtBottomBeforeStream) {
          _smoothScrollToBottom();
        }
      });
    } else {
      print('사용자가 스크롤 중이거나 맨 아래가 아님: 자동 스크롤 비활성화');
    }
  }

  // 스트리밍 종료
  void stopStreaming() {
    print('스트리밍 종료: 자동 스크롤 비활성화');
    _isStreaming = false;
    _streamScrollTimer?.cancel();
  }

  // 스트리밍 중 텍스트 청크 업데이트 시 호출 - ChatGPT 스타일 + 줄바꿈 미리 감지 + 빠른 스트리밍 대응
  void onStreamingTextUpdate({
    bool hasCodeBlock = false,
    String? textChunk,
    String? accumulatedText,
  }) {
    // 사용자가 스크롤 중이 아니고 스트리밍 시작 전에 맨 아래에 있었을 때만 자동 스크롤
    if (_isStreaming && !_userScrollActive && _wasAtBottomBeforeStream) {
      // 빠른 스트리밍 대응: 스로틀링으로 과도한 호출 방지
      final now = DateTime.now();
      if (_lastScrollTime != null &&
          now.difference(_lastScrollTime!).inMilliseconds < 50) {
        // 50ms 이내 연속 호출은 디바운싱
        _scheduleScrollUpdate(hasCodeBlock, textChunk);
        return;
      }

      _lastScrollTime = now;
      _performScrollUpdate(hasCodeBlock, textChunk);
    }
  }

  // 스크롤 업데이트 스케줄링 (디바운싱)
  void _scheduleScrollUpdate(bool hasCodeBlock, String? textChunk) {
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 50), () {
      if (_isStreaming && !_userScrollActive && _wasAtBottomBeforeStream) {
        _performScrollUpdate(hasCodeBlock, textChunk);
      }
    });
  }

  // 실제 스크롤 업데이트 수행
  void _performScrollUpdate(bool hasCodeBlock, String? textChunk) {
    // 이미 스크롤 중이면 중복 실행 방지
    if (_isScrolling) return;

    // 🎯 코드블록 + 사용자 스크롤 중이면 자동 스크롤 건너뛰기
    if (hasCodeBlock && _isUserScrolling) {
      print('코드블록 + 사용자 스크롤 감지: 자동 스크롤 건너뜀');
      return;
    }

    // 줄바꿈 감지 로직 - 새 청크에서 줄바꿈이 발생하면 미리 스크롤
    bool shouldPreScroll = false;
    if (textChunk != null && textChunk.contains('\n')) {
      final newLineCount = '\n'.allMatches(textChunk).length;
      // 2개 이상의 줄바꿈이 있으면 미리 스크롤 공간 확보
      shouldPreScroll = newLineCount >= 2;
    }

    if (shouldPreScroll) {
      // 줄바꿈 발생 시 미리 스크롤하여 공간 확보
      _preScrollForNewLines();
    }

    // ChatGPT 앱처럼 코드 블록도 즉시 반응하되, 약간의 지연으로 안정성 확보
    if (hasCodeBlock) {
      Future.delayed(const Duration(milliseconds: 30), () {
        if (_isStreaming && !_userScrollActive && scrollController.hasClients) {
          _smoothScrollToBottomForStreaming();
        }
      });
    } else {
      // 일반 텍스트는 즉시 스크롤
      _smoothScrollToBottomForStreaming();
    }
  }

  // 줄바꿈 발생 시 미리 스크롤하여 공간 확보
  void _preScrollForNewLines() {
    if (!scrollController.hasClients ||
        scrollController.position.maxScrollExtent <= 0) return;

    try {
      // 현재 위치에서 약간 아래로 미리 스크롤 (약 50px)
      final currentPosition = scrollController.position.pixels;
      final maxScroll = scrollController.position.maxScrollExtent;
      final targetPosition = (currentPosition + 50.0).clamp(0.0, maxScroll);

      scrollController.animateTo(
        targetPosition,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } catch (e) {
      // 스크롤 오류 시 무시
    }
  }

  // ChatGPT 앱 스타일 스트리밍 스크롤 - 항상 맨 아래 추적 (빠른 스트리밍 대응)
  void _smoothScrollToBottomForStreaming() {
    if (!scrollController.hasClients ||
        scrollController.position.maxScrollExtent <= 0 ||
        _isScrolling) return;

    _isScrolling = true;

    try {
      final maxScroll = scrollController.position.maxScrollExtent;
      final currentPosition = scrollController.position.pixels;
      final distanceFromBottom = maxScroll - currentPosition;

      // ChatGPT 앱처럼 항상 맨 아래로 스크롤 (여백 없이)
      // 5px 이상 차이날 때만 스크롤하여 불필요한 애니메이션 방지
      if (distanceFromBottom > 5.0) {
        scrollController
            .animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 100), // 빠른 응답성
          curve: Curves.easeOut,
        )
            .then((_) {
          _isScrolling = false; // 스크롤 완료 후 플래그 해제
        }).catchError((e) {
          _isScrolling = false; // 오류 시에도 플래그 해제
        });
      } else {
        _isScrolling = false; // 스크롤 불필요 시 즉시 플래그 해제
      }
    } catch (e) {
      _isScrolling = false; // 예외 시 플래그 해제
      print('_smoothScrollToBottomForStreaming 오류: $e');
    }
  }

  // ChatGPT 스타일 일반 스크롤 - 자연스러운 맨 아래 스크롤
  void _smoothScrollToBottom() {
    if (!scrollController.hasClients ||
        scrollController.position.maxScrollExtent <= 0) return;

    try {
      final maxScroll = scrollController.position.maxScrollExtent;
      final currentPosition = scrollController.position.pixels;
      final distanceFromBottom = maxScroll - currentPosition;

      // 10px 이상 차이날 때만 스크롤
      if (distanceFromBottom > 10.0) {
        scrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      print('_smoothScrollToBottom 오류: $e');
    }
  }

  // 스트리밍 상태 getter
  bool get isStreaming => _isStreaming;

  // 리소스 해제
  void dispose() {
    try {
      _userScrollTimer?.cancel();
      _streamScrollTimer?.cancel();
      _scrollDebounceTimer?.cancel();
      scrollController.removeListener(_scrollListener);
      if (scrollController.hasClients) {
        scrollController.dispose();
      }
    } catch (e) {
      print('ScrollManager dispose 중 오류: $e');
    }
  }

  // 특정 채팅 ID를 기반으로 스크롤 위치 찾기
  Future<void> scrollToChatId(
      int? chatId, List<Map<String, dynamic>> messages) async {
    if (chatId == null ||
        !scrollController.hasClients ||
        scrollController.position.maxScrollExtent == 0) return;

    print('scrollToChatId 호출: 메시지 ID $chatId 찾기');

    // 해당 ID의 메시지 인덱스 찾기
    int targetIndex = -1;
    for (int i = 0; i < messages.length; i++) {
      if (messages[i]['chat_id'] == chatId) {
        targetIndex = i;
        print('메시지 ID $chatId를 인덱스 $i에서 찾았습니다');
        break;
      }
    }

    if (targetIndex == -1) {
      print('메시지 ID $chatId에 해당하는 메시지를 찾지 못했습니다');
      return;
    }

    // 메시지가 마지막 메시지인 경우 맨 아래로 스크롤
    if (targetIndex == messages.length - 1) {
      print('대상 메시지가 마지막 메시지이므로 맨 아래로 스크롤합니다');
      scrollToBottom();
      return;
    }

    // UI 스레드에 예약
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 각 메시지의 높이를 정확히 알 수 없으므로, 대략적인 위치로 스크롤
      double estimatedPosition = 0;

      // 각 메시지에 대한 대략적인 높이 계산
      for (int i = 0; i < targetIndex; i++) {
        final message = messages[i];
        final String content = message['message'] as String? ?? '';

        // 메시지 길이, 역할 등에 따라 예상 높이 조정
        double messageHeight = 80.0; // 기본 높이

        // 텍스트 길이에 따라 높이 추가
        messageHeight += content.length * 0.2;

        // 코드 블록이 있는 경우 추가 높이
        if (content.contains('```')) {
          messageHeight += 100.0;
        }

        estimatedPosition += messageHeight;
      }

      // 메시지가 화면 상단이 아닌 중앙에 오도록 조정
      if (scrollController.position.viewportDimension > 0) {
        // 화면 높이의 절반만큼 빼서 메시지가 화면 중앙에 오도록 조정
        double viewportOffset = scrollController.position.viewportDimension / 2;
        estimatedPosition = estimatedPosition > viewportOffset
            ? estimatedPosition - viewportOffset
            : 0;
      }

      // 스크롤 애니메이션 수행
      print('메시지 ID $chatId를 찾았습니다. 스크롤 위치: $estimatedPosition');
      try {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            estimatedPosition,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
          );
        }
      } catch (e) {
        print('스크롤 애니메이션 중 오류: $e');
      }
    });
  }

  // 사용자가 아래쪽에 있는지 확인하는 메서드 (자동 스크롤 여부 결정용)
  bool isUserNearBottom() {
    if (!scrollController.hasClients ||
        scrollController.position.maxScrollExtent <= 0) return true;

    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = scrollController.position.pixels;
    final distanceFromBottom = maxScroll - currentScroll;

    // 맨 아래에서 10px 이내면 '아래쪽'으로 간주 (더 엄격하게 조정)
    return distanceFromBottom < 10;
  }

  // 스트리밍 중 자동 스크롤 (사용자가 아래쪽에 있을 때만)
  void handleStreamingMessage() {
    if (isUserNearBottom() && !_userScrollActive) {
      scrollToBottom();
    }
  }
}
