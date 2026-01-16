import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/providers/chat_notifier.dart'; // ChatNotifier와 ChatState 정의 파일 import
import 'package:ASPN_AI_AGENT/shared/providers/chat_state.dart';
import 'package:ASPN_AI_AGENT/shared/services/amqp_service.dart';
export 'chat_notifier.dart';
export 'attachment_provider.dart';
export 'notification_notifier.dart';
export 'theme_provider.dart';
export 'alert_ticker_provider.dart';
export 'admin_management_provider.dart';

// 사용자 ID 관리 프로바이더
final userIdProvider = StateProvider<String?>((ref) => null);

// 로그인 폼에서 사용하는 사용자 이름과 비밀번호 프로바이더
final usernameProvider = StateProvider<String>((ref) => '');
final passwordProvider = StateProvider<String>((ref) => '');

// 자동 로그인 상태 관리를 위한 Provider
final rememberMeProvider = StateProvider<bool>((ref) => false);

// ChatNotifier를 위한 StateNotifierProvider
final isDeleteModeProvider = StateProvider<bool>((ref) => false);
final selectedForDeleteProvider = StateProvider<Set<String>>((ref) => {});

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final userId = ref.watch(userIdProvider);

  // userId가 null인 경우 (로그아웃 상태) - 기본 상태로 초기화
  if (userId == null) {
    print('🔍 ChatProvider: User ID가 null입니다. 로그아웃 상태로 인식합니다.');
    return ChatNotifier(
      '', // 빈 문자열로 초기화
      ref.read(isDeleteModeProvider.notifier),
      ref.read(selectedForDeleteProvider.notifier),
    );
  }

  print('🔍 ChatProvider: User ID 설정됨 - $userId');
  return ChatNotifier(
    userId,
    ref.read(isDeleteModeProvider.notifier),
    ref.read(selectedForDeleteProvider.notifier),
  );
});

// 호버링된 아카이브 ID를 관리하는 provider
final hoveredArchiveIdProvider = StateProvider<String?>((ref) => null);
final selectedSapModuleProvider = StateProvider<String>((ref) => '');

// AI Chatbot에서 선택된 AI 모델을 관리하는 provider
final selectedAiModelProvider = StateProvider<String>(
  (ref) => 'gemini-pro-3',
);

// 웹검색 사용 여부 토글 상태 provider (withModel API 전용)

// 개인정보 동의 상태 관리 프로바이더
final privacyAgreementProvider = StateProvider<bool>((ref) => false);

// 승인자 상태 관리 프로바이더
final approverProvider = StateProvider<bool>((ref) => false);

// 권한 상태 관리 프로바이더 (휴가부여 권한)
final permissionProvider = StateProvider<int?>((ref) => null);

// 받은선물함 선물 개수 관리 프로바이더
final giftCountProvider = StateProvider<int>((ref) => 0);

final amqpServiceProvider = Provider<AmqpService>((ref) => amqpService);
