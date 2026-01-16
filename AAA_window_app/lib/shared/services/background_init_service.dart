import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/services/amqp_service.dart';
import 'package:ASPN_AI_AGENT/shared/services/api_service.dart';
import 'package:ASPN_AI_AGENT/core/database/database_helper.dart';
import 'package:ASPN_AI_AGENT/features/auth/login_progress_indicator.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';

/// 백그라운드 초기화 상태
enum BackgroundInitStatus {
  pending, // 대기 중
  running, // 실행 중
  completed, // 완료
  failed, // 실패
}

/// 백그라운드 초기화 결과
class BackgroundInitResult {
  final BackgroundInitStatus status;
  final String? error;
  final Map<String, dynamic>? data;

  const BackgroundInitResult({
    required this.status,
    this.error,
    this.data,
  });

  bool get isSuccess => status == BackgroundInitStatus.completed;
  bool get isRunning => status == BackgroundInitStatus.running;
  bool get hasFailed => status == BackgroundInitStatus.failed;
}

/// 백그라운드 초기화 서비스
class BackgroundInitService {
  static final BackgroundInitService _instance =
      BackgroundInitService._internal();
  factory BackgroundInitService() => _instance;
  BackgroundInitService._internal();

  final StreamController<BackgroundInitResult> _statusController =
      StreamController<BackgroundInitResult>.broadcast();

  Stream<BackgroundInitResult> get statusStream => _statusController.stream;

  BackgroundInitResult _currentStatus = const BackgroundInitResult(
    status: BackgroundInitStatus.pending,
  );

  BackgroundInitResult get currentStatus => _currentStatus;

  /// 백그라운드에서 전체 초기화 실행
  Future<BackgroundInitResult> performBackgroundInit({
    required String userId,
    required WidgetRef ref,
    Function(LoginStep)? onStepChange,
  }) async {
    try {
      _updateStatus(BackgroundInitStatus.running);

      print('🚀 [BGInit] 백그라운드 초기화 시작: $userId');

      // 1단계: AMQP 연결
      onStepChange?.call(LoginStep.connectingAmqp);
      final amqpResult = await _connectAmqpAsync(userId, ref);

      // 2단계: 데이터 동기화 (순차 처리 - 중요!)
      onStepChange?.call(LoginStep.syncingData);
      final syncResult = await _syncDataAsync(userId, ref);

      // 3단계: UI 사전 로딩 (동기화 후 수행)
      final uiResult = await _preloadUIAsync(userId, ref);

      // 결과 검증
      final results = [amqpResult, syncResult, uiResult];
      bool allSuccess = true;
      String? firstError;

      for (int i = 0; i < results.length; i++) {
        if (!results[i]['success']) {
          allSuccess = false;
          firstError ??= results[i]['error'];
        }
      }

      if (allSuccess) {
        onStepChange?.call(LoginStep.completed);

        final result = BackgroundInitResult(
          status: BackgroundInitStatus.completed,
          data: {
            'amqp': results[0],
            'sync': results[1],
            'ui': results[2],
            'duration': DateTime.now().millisecondsSinceEpoch,
          },
        );

        _updateStatus(BackgroundInitStatus.completed, result: result);
        print('✅ [BGInit] 백그라운드 초기화 완료 (순차적 수행)');
        return result;
      } else {
        throw Exception('초기화 실패: $firstError');
      }
    } catch (e) {
      print('❌ [BGInit] 백그라운드 초기화 실패: $e');

      final result = BackgroundInitResult(
        status: BackgroundInitStatus.failed,
        error: e.toString(),
      );

      _updateStatus(BackgroundInitStatus.failed, result: result);
      return result;
    }
  }

  /// AMQP 연결 (비동기)
  Future<Map<String, dynamic>> _connectAmqpAsync(
      String userId, WidgetRef ref) async {
    try {
      print('🔌 [BGInit] AMQP 연결 시작');

      final startTime = DateTime.now();

      // 🔧 1단계: AMQP 서비스 Notifier 설정 (연결 전 필수!)
      try {
        print('🔧 [BGInit] AMQP 서비스 Notifier 설정 시작');

        amqpService.setNotifiers(
          notificationNotifier: ref.read(notificationProvider.notifier),
          chatNotifier: ref.read(chatProvider.notifier),
          alertTickerNotifier: ref.read(alertTickerProvider.notifier),
        );

        print('✅ [BGInit] AMQP 서비스 Notifier 설정 완료');
      } catch (notifierError) {
        print('❌ [BGInit] AMQP 서비스 Notifier 설정 실패: $notifierError');
        // Notifier 설정 실패시 AMQP 연결 중단
        throw Exception('AMQP Notifier 설정 실패: $notifierError');
      }

      // 🔒 2단계: 개인정보 동의 상태 설정
      try {
        // Provider에서 실제 개인정보 동의 상태 가져오기
        final privacyAgreed = ref.read(privacyAgreementProvider);
        amqpService.setPrivacyAgreement(privacyAgreed);
        print('🔒 [BGInit] AMQP 서비스에 개인정보 동의 상태 설정: $privacyAgreed');
      } catch (privacyError) {
        print('⚠️ [BGInit] 개인정보 동의 상태 설정 실패 (기본값 true 사용): $privacyError');
        amqpService.setPrivacyAgreement(true);
      }

      final success = await amqpService.connect(userId);
      final duration = DateTime.now().difference(startTime);

      if (success) {
        print('✅ [BGInit] AMQP 연결 성공 (${duration.inMilliseconds}ms)');
        return {
          'success': true,
          'duration': duration.inMilliseconds,
          'message': 'AMQP 연결 성공',
        };
      } else {
        throw Exception('AMQP 연결 실패');
      }
    } catch (e) {
      print('❌ [BGInit] AMQP 연결 실패: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'AMQP 연겴 실패',
      };
    }
  }

  /// 데이터 동기화 (비동기)
  Future<Map<String, dynamic>> _syncDataAsync(
      String userId, WidgetRef ref) async {
    try {
      print('📊 [BGInit] 데이터 동기화 시작');

      final startTime = DateTime.now();

      // 서버-로컬 동기화
      final syncResult = await DatabaseHelper.syncArchivesWithDetails(userId);

      if (syncResult['success']) {
        // ref 사용 전 안전성 체크
        try {
          // 아카이브 목록 업데이트 (ref가 유효한 경우에만)
          await ref.read(chatProvider.notifier).getArchiveListAll(userId);
        } catch (refError) {
          print('⚠️ [BGInit] ref 사용 실패 (위젯 dispose됨): $refError');
          // ref 에러는 무시하고 계속 진행 (백그라운드이므로)
        }

        final duration = DateTime.now().difference(startTime);
        print('✅ [BGInit] 데이터 동기화 성공 (${duration.inMilliseconds}ms)');

        return {
          'success': true,
          'duration': duration.inMilliseconds,
          'syncResult': syncResult,
          'message': '데이터 동기화 완료',
        };
      } else {
        throw Exception('동기화 실패: ${syncResult['error']}');
      }
    } catch (e) {
      print('❌ [BGInit] 데이터 동기화 실패: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': '데이터 동기화 실패',
      };
    }
  }

  /// UI 사전 로딩 (비동기)
  Future<Map<String, dynamic>> _preloadUIAsync(
      String userId, WidgetRef ref) async {
    try {
      print('🎨 [BGInit] UI 사전 로딩 시작');

      final startTime = DateTime.now();

      // 기본 아카이브 확인 및 생성
      await _ensureDefaultArchives(userId, ref);

      // ref 사용 전 안전성 체크
      try {
        // 첫 번째 아카이브 선택 준비 (ref가 유효한 경우에만)
        final chatState = ref.read(chatProvider);
        if (chatState.arvChatHistory.isNotEmpty) {
          final firstArchive = chatState.arvChatHistory.first;
          await ref
              .read(chatProvider.notifier)
              .selectTopic(firstArchive['archive_id']);
        }
      } catch (refError) {
        print('⚠️ [BGInit] ref 사용 실패 (위젯 dispose됨): $refError');
        // ref 에러는 무시하고 계속 진행 (백그라운드이므로)
      }

      final duration = DateTime.now().difference(startTime);
      print('✅ [BGInit] UI 사전 로딩 완료 (${duration.inMilliseconds}ms)');

      return {
        'success': true,
        'duration': duration.inMilliseconds,
        'message': 'UI 준비 완료',
      };
    } catch (e) {
      print('❌ [BGInit] UI 사전 로딩 실패: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'UI 준비 실패',
      };
    }
  }

  /// 기본 아카이브 보장 (서버 아카이브 존재 여부 확인 포함)
  Future<void> _ensureDefaultArchives(String userId, WidgetRef ref) async {
    try {
      // 1. 로컬 DB에서 아카이브 확인
      final db = await DatabaseHelper().database;
      final localArchives = await db.query(
        'local_archives',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      print('📋 [BGInit] 로컬 아카이브 확인: ${localArchives.length}개 발견');

      // 2. 서버에서 아카이브 확인
      List<Map<String, dynamic>> serverArchives = [];
      try {
        serverArchives = await ApiService.getArchiveListFromServer(userId);
        print('☁️ [BGInit] 서버 아카이브 확인: ${serverArchives.length}개 발견');
      } catch (e) {
        print('⚠️ [BGInit] 서버 아카이브 조회 실패: $e (신규 사용자일 가능성)');
        serverArchives = [];
      }

      // 3. 진짜 첫 로그인 여부 판단 (로컬도 비어있고 서버도 비어있어야 함)
      final isRealFirstLogin = localArchives.isEmpty && serverArchives.isEmpty;

      if (isRealFirstLogin) {
        print('🆕 [BGInit] 진짜 신규 사용자 - 기본 아카이브 생성 필요');
        await _createDefaultArchives(userId, ref);
      } else if (localArchives.isEmpty && serverArchives.isNotEmpty) {
        print('📥 [BGInit] 로컬 비어있음, 서버에 아카이브 존재 - 동기화만 수행 (기본 아카이브 생성 안함)');
        // 동기화는 _syncDataAsync에서 이미 처리됨
      } else {
        print(
            '📋 [BGInit] 기존 사용자 - 아카이브가 이미 존재함 (로컬: ${localArchives.length}개, 서버: ${serverArchives.length}개)');

        // 동기화 후에도 여전히 아카이브가 없다면 기본 아카이브 생성
        final updatedLocalArchives = await db.query(
          'local_archives',
          where: 'user_id = ?',
          whereArgs: [userId],
        );

        if (updatedLocalArchives.isEmpty) {
          print('⚠️ [BGInit] 동기화 후에도 아카이브가 없음 - 기본 아카이브 생성');
          await _createDefaultArchives(userId, ref);
        } else {
          // 4. 빠진 디폴트 아카이브 확인 및 선택적 생성
          await _createMissingDefaultArchives(
              userId, ref, updatedLocalArchives);
        }
      }
    } catch (e) {
      print('❌ [BGInit] 기본 아카이브 확인 중 오류: $e');
      // 치명적이지 않은 오류이므로 계속 진행
    }
  }

  /// 기본 아카이브 생성 (직접 구현)
  Future<void> _createDefaultArchives(String userId, WidgetRef ref) async {
    try {
      print('====== [BGInit] 디폴트 아카이브 생성 시작 ======');

      // 기본 아카이브 생성
      final archivesToCreate = [
        {'title': '사내업무', 'type': ''},
        {'title': '코딩어시스턴트', 'type': 'code'},
        {'title': 'SAP 어시스턴트', 'type': 'sap'},
        {'title': 'AI Chatbot', 'type': ''},
      ];

      for (var archive in archivesToCreate) {
        try {
          final archiveId =
              await ref.read(chatProvider.notifier).createNewArchive(
                    archiveType: archive['type'] ?? '',
                  );

          if (archive['type'] == '') {
            await ref
                .read(chatProvider.notifier)
                .editArchiveTitle(archiveId, archive['title'] ?? '');
          }

          print('✅ [BGInit] ${archive['title']} 아카이브 생성 완료: $archiveId');
        } catch (e) {
          print('❌ [BGInit] ${archive['title']} 아카이브 생성 실패: $e');
        }
      }

      // 아카이브 목록 갱신
      await ref.read(chatProvider.notifier).getArchiveListAll(userId);

      print('====== [BGInit] 디폴트 아카이브 생성 완료 ======');
    } catch (e) {
      print('❌ [BGInit] 디폴트 아카이브 생성 중 오류: $e');
    }
  }

  /// 상태 업데이트
  void _updateStatus(BackgroundInitStatus status,
      {BackgroundInitResult? result}) {
    final newResult = result ?? BackgroundInitResult(status: status);
    _currentStatus = newResult;
    _statusController.add(newResult);
  }

  /// 리셋
  void reset() {
    _currentStatus =
        const BackgroundInitResult(status: BackgroundInitStatus.pending);
    _updateStatus(BackgroundInitStatus.pending);
  }

  /// 리소스 정리
  void dispose() {
    _statusController.close();
  }
}

/// Provider를 통한 서비스 접근
final backgroundInitServiceProvider = Provider<BackgroundInitService>((ref) {
  return BackgroundInitService();
});

/// 빠진 디폴트 아카이브만 선택적으로 생성
Future<void> _createMissingDefaultArchives(String userId, WidgetRef ref,
    List<Map<String, dynamic>> existingArchives) async {
  try {
    print('🔍 [BGInit] 빠진 디폴트 아카이브 확인 중...');

    // 필요한 디폴트 아카이브 정의
    final requiredDefaultArchives = [
      {'title': '사내업무', 'type': '', 'identifier': 'business'},
      {'title': '코딩어시스턴트', 'type': 'code', 'identifier': 'code'},
      {'title': 'SAP 어시스턴트', 'type': 'sap', 'identifier': 'sap'},
      {'title': 'AI Chatbot', 'type': '', 'identifier': 'ai_chatbot'},
    ];

    // 기존 아카이브에서 디폴트 아카이브 확인
    final existingDefaultArchives = <String, Map<String, dynamic>>{};

    for (var archive in existingArchives) {
      final archiveName = archive['archive_name']?.toString() ?? '';
      final archiveType = archive['archive_type']?.toString() ?? '';

      // 사내업무 확인 (이름 또는 빈 타입)
      if (archiveName == '사내업무' ||
          (archiveType == '' && archiveName.contains('사내'))) {
        existingDefaultArchives['business'] = archive;
      }
      // 코딩어시스턴트 확인 (이름 또는 code 타입)
      else if (archiveName == '코딩어시스턴트' || archiveType == 'code') {
        existingDefaultArchives['code'] = archive;
      }
      // SAP 어시스턴트 확인 (이름 또는 sap 타입)
      else if (archiveName == 'SAP 어시스턴트' || archiveType == 'sap') {
        existingDefaultArchives['sap'] = archive;
      }
      // AI Chatbot 확인 (이름)
      else if (archiveName == 'AI Chatbot') {
        existingDefaultArchives['ai_chatbot'] = archive;
      }
    }

    // 빠진 디폴트 아카이브 확인
    final missingArchives = <Map<String, dynamic>>[];

    for (var required in requiredDefaultArchives) {
      final identifier = required['identifier'] as String;
      if (!existingDefaultArchives.containsKey(identifier)) {
        missingArchives.add(required);
        print('⚠️ [BGInit] 빠진 디폴트 아카이브 발견: ${required['title']}');
      } else {
        print('✅ [BGInit] 디폴트 아카이브 존재: ${required['title']}');
      }
    }

    // 빠진 디폴트 아카이브가 있으면 생성
    if (missingArchives.isNotEmpty) {
      print('🔄 [BGInit] 빠진 디폴트 아카이브 ${missingArchives.length}개 생성 시작');
      await _createSpecificDefaultArchives(userId, ref, missingArchives);
    } else {
      print('✅ [BGInit] 모든 디폴트 아카이브가 존재함');
    }
  } catch (e) {
    print('❌ [BGInit] 빠진 디폴트 아카이브 확인 중 오류: $e');
  }
}

/// 특정 디폴트 아카이브만 생성
Future<void> _createSpecificDefaultArchives(String userId, WidgetRef ref,
    List<Map<String, dynamic>> archivesToCreate) async {
  try {
    print('====== [BGInit] 선택적 디폴트 아카이브 생성 시작 ======');

    for (var archive in archivesToCreate) {
      try {
        final archiveId =
            await ref.read(chatProvider.notifier).createNewArchive(
                  archiveType: archive['type'] ?? '',
                );

        if (archive['type'] == '') {
          await ref
              .read(chatProvider.notifier)
              .editArchiveTitle(archiveId, archive['title'] ?? '');
        }

        print('✅ [BGInit] ${archive['title']} 아카이브 생성 완료: $archiveId');
      } catch (e) {
        print('❌ [BGInit] ${archive['title']} 아카이브 생성 실패: $e');
      }
    }

    // 아카이브 목록 갱신
    await ref.read(chatProvider.notifier).getArchiveListAll(userId);

    print('====== [BGInit] 선택적 디폴트 아카이브 생성 완료 ======');
  } catch (e) {
    print('❌ [BGInit] 선택적 디폴트 아카이브 생성 중 오류: $e');
  }
}
