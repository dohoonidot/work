import 'dart:async';
import 'dart:convert';

import 'package:ASPN_AI_AGENT/core/config/messageq_config.dart';
import 'package:ASPN_AI_AGENT/main.dart' show navigatorKey;
import 'package:ASPN_AI_AGENT/shared/providers/alert_ticker_provider.dart';
import 'package:ASPN_AI_AGENT/shared/providers/notification_notifier.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:ASPN_AI_AGENT/shared/services/api_service.dart';
import 'package:ASPN_AI_AGENT/shared/utils/amqp_logger.dart';
import 'package:ASPN_AI_AGENT/features/gift/gift_arrival_popup.dart';
import 'package:ASPN_AI_AGENT/features/gift/birthday_popup.dart';
import 'package:ASPN_AI_AGENT/features/gift/event_popup.dart';
import 'package:ASPN_AI_AGENT/features/leave/leave_draft_modal.dart';
import 'package:ASPN_AI_AGENT/features/leave/vacation_data_provider.dart';
import 'package:ASPN_AI_AGENT/features/approval/approval_alert_popup.dart';
import 'package:dart_amqp/dart_amqp.dart' as amqp;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AMQP 서비스의 연결 상태 (bool 값으로 단순화)
/// true: 연결됨, false: 연결되지 않음

class AmqpService {
  /// 로그 레벨 설정 (운영환경용)
  static void setProductionLogLevel() {
    AmqpLogger.setProductionLevel(); // ERROR, WARN만 출력
  }

  /// 로그 레벨 설정 (개발환경용)
  static void setDevelopmentLogLevel() {
    AmqpLogger.setDevelopmentLevel(); // 모든 로그 출력
  }

  /// 로그 레벨 설정 (테스트환경용)
  static void setTestLogLevel() {
    AmqpLogger.setTestLevel(); // INFO, WARN, ERROR 출력
  }

  /// 현재 로그 레벨 확인
  static String getCurrentLogLevel() {
    switch (AmqpLogger.getCurrentLevel()) {
      case AmqpLogger.LEVEL_ERROR:
        return 'ERROR';
      case AmqpLogger.LEVEL_WARN:
        return 'WARN';
      case AmqpLogger.LEVEL_INFO:
        return 'INFO';
      case AmqpLogger.LEVEL_DEBUG:
        return 'DEBUG';
      default:
        return 'UNKNOWN';
    }
  }

  // AMQP 클라이언트 및 채널 리소스
  amqp.Client? _client;
  amqp.Channel? _channel;

  // 활성화된 Consumer 관리 (큐 이름 -> Consumer)
  final Map<String, amqp.Consumer> _consumers = {};

  // --- 상태 관리 ---
  bool _isConnected = false;
  String? _currentUserId;
  bool _isPrivacyAgreed = false;
  int _reconnectAttempts = 0;

  // --- 동시성 제어 강화 (Mutex 패턴) ---
  bool _isConnecting = false; // 연결 작업 진행 중 플래그
  bool _isDisconnecting = false; // 연결 해제 작업 진행 중 플래그
  bool _isReconnecting = false; // 재연결 작업 진행 중 플래그
  final List<Completer<bool>> _connectQueue = []; // 연결 요청 대기열

  // --- 재연결 전략 강화 ---
  Timer? _reconnectTimer; // 지연 재연결 타이머
  Timer? _healthCheckTimer; // 헬스체크 타이머
  int _consecutiveFailures = 0; // 연속 실패 횟수

  // --- 리소스 정리 동시 실행 방지 ---
  bool _isCleaningUp = false;
  Completer<void>? _cleanupCompleter;

  // --- 상태 모니터링 타이머 ---
  Timer? _statusMonitorTimer;

  // --- 외부 모듈 참조 (Notifier, Callbacks) ---
  NotificationNotifier? _notificationNotifier;
  dynamic _chatNotifier;
  AlertTickerNotifier? _alertTickerNotifier;
  dynamic _leaveManagementNotifier; // ⭐ LeaveManagementNotifier 추가
  VoidCallback? _onGiftConfirm;
  VoidCallback? _onGiftCountUpdate; // 선물 개수 업데이트 콜백 추가

  // --- 스트림 컨트롤러 (UI 업데이트용) ---
  final StreamController<Map<String, dynamic>> _giftMessageController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _alertMessageController =
      StreamController.broadcast();

  // --- Public-facing Properties ---
  bool get isConnected {
    // 실제 연결 리소스 상태를 확인하여 동기화
    return _client != null && _channel != null && _isConnected;
  }

  Stream<Map<String, dynamic>> get giftMessages =>
      _giftMessageController.stream;
  Stream<Map<String, dynamic>> get alertMessages =>
      _alertMessageController.stream;

  // --- AMQP 서버 설정 ---
  String get _host => MessageQConfig.rabbitmqHost;
  int get _port => MessageQConfig.rabbitmqPort;
  String get _username => MessageQConfig.rabbitmqUsername;
  String get _password => MessageQConfig.rabbitmqPassword;

  // --- 상태 변경 메서드 (로깅 포함) ---
  void _setConnected(bool connected, [String? reason]) {
    final oldState = _isConnected;
    _isConnected = connected;

    // 상태 변경만 INFO 레벨로 로그
    AmqpLogger.state(
        '연결 상태: $oldState → $connected${reason != null ? ' ($reason)' : ''}');

    // 상세 정보는 DEBUG 레벨에서만 출력
    AmqpLogger.debug(
        '상태 세부정보: 사용자=${_currentUserId ?? "없음"}, 개인정보동의=$_isPrivacyAgreed, Consumer=${_consumers.length}개');
  }

  // --- 상태 모니터링 시작/중지 ---
  // void _startStatusMonitoring() {
  //   _statusMonitorTimer?.cancel();
  //   _statusMonitorTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
  //     print('📊 [AMQP] === 상태 모니터링 (10초마다) ===');
  //     print('   - 연결 상태: $_isConnected');
  //     print('   - 사용자 ID: $_currentUserId');
  //     print('   - 개인정보 동의: $_isPrivacyAgreed');
  //     print('   - 재연결 시도 횟수: $_reconnectAttempts');
  //     print('   - 연속 실패 횟수: $_consecutiveFailures');
  //     print('   - 활성 Consumer 수: ${_consumers.length}');
  //     print('   - 클라이언트 연결: ${_client != null ? "✅" : "❌"}');
  //     print('   - 채널 연결: ${_channel != null ? "✅" : "❌"}');
  //     print('   - Consumer 목록: ${_consumers.keys.toList()}');
  //     print('   - 연결 작업 진행 중: $_isConnecting');
  //     print('📊 [AMQP] === 상태 모니터링 완료 ===');
  //   });
  //   print('✅ [AMQP] 상태 모니터링 시작 (10초마다)');
  // }

  void _stopStatusMonitoring() {
    _statusMonitorTimer?.cancel();
    _statusMonitorTimer = null;
    print('⏹️ [AMQP] 상태 모니터링 중지');
  }

  // --- 외부 모듈 설정 메서드 ---
  void setNotifiers({
    required NotificationNotifier notificationNotifier,
    required dynamic chatNotifier,
    required AlertTickerNotifier alertTickerNotifier,
    dynamic leaveManagementNotifier, // ⭐ 선택적 파라미터로 추가
  }) {
    print('🔄 [AMQP] Notifier 설정 시작');
    _notificationNotifier = notificationNotifier;
    _chatNotifier = chatNotifier;
    _alertTickerNotifier = alertTickerNotifier;
    _leaveManagementNotifier = leaveManagementNotifier; // ⭐ 설정
    print('✅ [AMQP] 모든 Notifier 설정 완료');
    if (_leaveManagementNotifier != null) {
      print('✅ [AMQP] LeaveManagementNotifier 연결됨');
    }
  }

  void setOnGiftConfirm(VoidCallback onGiftConfirm) {
    print('🔄 [AMQP] 선물 확인 콜백 설정');
    _onGiftConfirm = onGiftConfirm;
  }

  void setOnGiftCountUpdate(VoidCallback onGiftCountUpdate) {
    print('🔄 [AMQP] 선물 개수 업데이트 콜백 설정');
    _onGiftCountUpdate = onGiftCountUpdate;
  }

  /// 개인정보 동의 후 즉시 birthday와 gift 큐를 생성합니다.
  Future<void> createQueuesImmediately() async {
    print('🎯 [AMQP] createQueuesImmediately() 시작');
    try {
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        print('⚠️ [AMQP] 사용자 ID가 없어 큐 생성할 수 없습니다.');
        return;
      }

      if (!_isConnected) {
        print('⚠️ [AMQP] 연결되지 않은 상태입니다. 연결을 시도합니다.');
        final connected = await connect(_currentUserId!);
        if (!connected) {
          print('❌ [AMQP] 연결 실패로 큐 생성할 수 없습니다.');
          return;
        }
      }

      if (_channel == null) {
        print('❌ [AMQP] 채널이 없어 큐 생성할 수 없습니다.');
        return;
      }

      final userId = _currentUserId!;
      final queuesToCreate = ['birthday', 'gift'];

      print('🎯 [AMQP] 개인정보 동의 후 즉시 큐 생성 시작: $queuesToCreate');

      for (String queueType in queuesToCreate) {
        final queueName = '$queueType.$userId';

        // 이미 존재하는 큐인지 확인
        if (_consumers.containsKey(queueName)) {
          print('✅ [AMQP] 큐가 이미 존재합니다: $queueName');
          continue;
        }

        try {
          print('🔧 [AMQP] 큐 생성 시도: $queueName');
          // 큐 생성
          final queue = await _channel!.queue(queueName, durable: true);
          print('✅ [AMQP] 큐 생성 완료: $queueName');

          // Consumer 생성 및 구독
          AmqpLogger.debug('Consumer 생성 시도: $queueName');
          final consumer = await queue.consume(noAck: false);
          consumer.listen(
            (amqp.AmqpMessage message) {
              AmqpLogger.message('메시지 수신: $queueName');
              _handleMessage(message, queueType);
            },
            onError: (error) {
              AmqpLogger.error('Consumer 에러: $queueType', error);
              _handleDisconnection('CONSUMER_ERROR');
            },
            onDone: () {
              AmqpLogger.warn('Consumer 종료됨: $queueType');
              _handleDisconnection('CONSUMER_DONE');
            },
          );

          _consumers[queueName] = consumer;
          AmqpLogger.success('Consumer 생성 완료: $queueName');
        } catch (e) {
          print('❌ [AMQP] 큐 생성/구독 실패 ($queueName): $e');
        }
      }

      print('✅ [AMQP] 개인정보 동의 후 큐 생성 완료');
    } catch (e) {
      print('❌ [AMQP] 즉시 큐 생성 중 오류: $e');
    }
  }

  /// 개인정보 동의 상태가 변경되었을 때 호출되는 메서드
  Future<void> onPrivacyAgreementChanged(String userId, bool isAgreed) async {
    print('🔒 [AMQP] onPrivacyAgreementChanged() 시작: $userId → $isAgreed');

    if (_currentUserId != userId) {
      print('⚠️ [AMQP] 다른 사용자입니다. 전체 재연결을 진행합니다.');
      await connect(userId);
      return;
    }

    _isPrivacyAgreed = isAgreed;

    if (isAgreed) {
      // 개인정보 동의 시 즉시 큐 생성
      print('🔒 [AMQP] 개인정보 동의됨 - 즉시 큐 생성 시작');
      await createQueuesImmediately();
    } else {
      // 개인정보 동의 해제 시 gift, birthday 큐 제거 (event는 유지)
      print('🔒 [AMQP] 개인정보 동의 해제됨 - gift, birthday 큐 제거');
      await _removeConsumer('gift.$_currentUserId');
      await _removeConsumer('birthday.$_currentUserId');
    }
    print('🔒 [AMQP] onPrivacyAgreementChanged() 완료');
  }

  /// 특정 큐의 Consumer를 제거합니다.
  Future<void> _removeConsumer(String queueName) async {
    print('🔒 [AMQP] Consumer 제거 시도: $queueName');
    final consumer = _consumers[queueName];
    if (consumer != null) {
      try {
        await consumer.cancel();
        _consumers.remove(queueName);
        print('✅ [AMQP] Consumer 제거 완료: $queueName');
      } catch (e) {
        print('❌ [AMQP] Consumer 제거 실패 ($queueName): $e');
      }
    } else {
      print('⚠️ [AMQP] 제거할 Consumer가 없습니다: $queueName');
    }
  }

  // --- Public Core Methods ---

  /// AMQP 서버에 연결을 시도하고 사용자 큐 구독을 시작합니다.
  /// Mutex 패턴으로 동시 접근을 방지하여 안정성을 보장합니다.
  Future<bool> connect(String userId) async {
    print('🔒 [AMQP] ===== connect() 호출 - 순차 처리 시작 =====');
    print('🔒 [AMQP] 호출 정보:');
    print('   - 사용자 ID: $userId');
    print('   - 현재 연결 상태: $_isConnected');
    print('   - 연결 작업 진행 중: $_isConnecting');
    print('   - 재연결 작업 진행 중: $_isReconnecting');
    print('   - 연결 해제 작업 진행 중: $_isDisconnecting');
    print('   - 대기열 크기: ${_connectQueue.length}');

    // === Mutex 패턴: 동시 접근 방지 ===
    if (_isConnecting || _isDisconnecting || _isReconnecting) {
      final completer = Completer<bool>();
      _connectQueue.add(completer);
      print('⏳ [AMQP] 다른 연결 작업 진행 중 - 대기열에 추가 (${_connectQueue.length}번째)');
      return await completer.future;
    }

    // === 실제 연결 프로세스 시작 ===
    _isConnecting = true;
    try {
      final result = await _performSequentialConnect(userId);

      // 대기 중인 요청들 처리
      _processConnectQueue(result);
      return result;
    } finally {
      _isConnecting = false;
    }
  }

  /// 대기열에 있는 연결 요청들을 처리합니다.
  void _processConnectQueue(bool result) {
    if (_connectQueue.isEmpty) return;

    print('📋 [AMQP] 대기열 처리 시작 (${_connectQueue.length}개 요청)');
    final queueToProcess = List.of(_connectQueue);
    _connectQueue.clear();

    for (final completer in queueToProcess) {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }
    print('✅ [AMQP] 대기열 처리 완료');
  }

  /// 순차적 연결 프로세스 수행 (각 단계별 안정화 시간 포함)
  Future<bool> _performSequentialConnect(String userId) async {
    print('🔧 [AMQP] ===== 순차적 연결 프로세스 시작 =====');
    _currentUserId = userId;

    try {
      // === 1단계: 기존 리소스 완전 정리 ===
      print('🧹 [AMQP] 1단계: 기존 리소스 완전 정리');
      await _ensureCleanState();
      await Future.delayed(Duration(milliseconds: 500)); // 안정화 대기
      print('✅ [AMQP] 1단계 완료 - 500ms 안정화 대기');

      // === 2단계: 개인정보 동의 상태 확인 ===
      print('🔒 [AMQP] 2단계: 개인정보 동의 상태 확인');
      await _checkPrivacyAgreement(userId);
      await Future.delayed(Duration(milliseconds: 200)); // DB 안정화 대기
      print('✅ [AMQP] 2단계 완료 - 200ms DB 안정화 대기');

      // === 3단계: 클라이언트 연결 ===
      print('🌐 [AMQP] 3단계: 클라이언트 연결');
      await _establishClientConnection();
      await Future.delayed(Duration(milliseconds: 300)); // 네트워크 안정화 대기
      print('✅ [AMQP] 3단계 완료 - 300ms 네트워크 안정화 대기');

      // === 4단계: 채널 생성 ===
      print('📡 [AMQP] 4단계: 채널 생성');
      await _createChannel();
      await Future.delayed(Duration(milliseconds: 200)); // 채널 안정화 대기
      print('✅ [AMQP] 4단계 완료 - 200ms 채널 안정화 대기');

      // === 5단계: 큐 및 Consumer 설정 ===
      print('🎯 [AMQP] 5단계: 큐 및 Consumer 설정');
      await _setupQueuesSequentially();
      await Future.delayed(Duration(milliseconds: 400)); // Consumer 안정화 대기
      print('✅ [AMQP] 5단계 완료 - 400ms Consumer 안정화 대기');

      // === 6단계: 연결 완료 검증 ===
      print('🔍 [AMQP] 6단계: 연결 상태 최종 검증');
      final isValid = await _verifyConnectionState();
      await Future.delayed(Duration(milliseconds: 100)); // 최종 안정화
      print('✅ [AMQP] 6단계 완료 - 연결 검증 결과: $isValid');

      if (isValid) {
        _setConnected(true, '순차적 연결 프로세스 완료');
        _reconnectAttempts = 0; // 성공 시 재연결 카운터 리셋
        _consecutiveFailures = 0; // 연속 실패 카운터 리셋

        // 헬스체크 및 상태 모니터링 시작
        _startHealthCheck();
        // _startStatusMonitoring();

        print('🎉 [AMQP] === 연결 성공: 총 1.8초 안정화 시간 확보 ===');
        return true;
      } else {
        throw Exception('연결 상태 검증 실패');
      }
    } catch (e) {
      print('❌ [AMQP] 순차적 연결 프로세스 실패: $e');
      _setConnected(false, '연결 프로세스 실패');
      await _ensureCleanState(); // 실패 시 리소스 정리
      return false;
    }
  }

  /// 기존 리소스 완전 정리 (연결 전 상태 초기화)
  Future<void> _ensureCleanState() async {
    print('🧹 [AMQP] 기존 리소스 완전 정리 시작');

    try {
      await _cleanupResources();
      _setConnected(false, '리소스 정리 완료');
      print('✅ [AMQP] 기존 리소스 완전 정리 완료');
    } catch (e) {
      print('⚠️ [AMQP] 리소스 정리 중 오류 (무시): $e');
    }
  }

  /// 개인정보 동의 상태 설정 (외부에서 호출)
  void setPrivacyAgreement(bool isAgreed) {
    _isPrivacyAgreed = isAgreed;
    print('✅ [AMQP] 개인정보 동의 상태 설정: $_isPrivacyAgreed');
  }

  /// 개인정보 동의 상태 확인 (독립 메서드) - 외부에서 설정된 상태 사용
  Future<void> _checkPrivacyAgreement(String userId) async {
    try {
      // 외부에서 설정된 개인정보 동의 상태를 사용 (서버에서 받은 값)
      print('✅ [AMQP] 외부에서 설정된 개인정보 동의 상태 사용: $_isPrivacyAgreed');

      // _isPrivacyAgreed는 bool 타입이므로 이미 setPrivacyAgreement()에서 설정됨
      // 서버 DB 기본값: 0 (비동의) → false로 변환되어 설정됨
    } catch (e) {
      print('❌ [AMQP] 개인정보 동의 상태 확인 실패: $e');
      print('❌ [AMQP] 기본값 false로 설정');
      _isPrivacyAgreed = false;
    }
  }

  /// 클라이언트 연결 수행 (독립 메서드)
  Future<void> _establishClientConnection() async {
    try {
      print('🔧 [AMQP] ConnectionSettings 객체 생성 시작');
      final settings = amqp.ConnectionSettings(
        tuningSettings:
            amqp.TuningSettings(heartbeatPeriod: Duration(seconds: 30)),
        host: _host,
        port: _port,
        authProvider: amqp.PlainAuthenticator(_username, _password),
      );
      print('✅ [AMQP] ConnectionSettings 객체 생성 완료');

      print('🔧 [AMQP] AMQP 클라이언트 객체 생성 시작');
      _client = amqp.Client(settings: settings);
      print('✅ [AMQP] AMQP 클라이언트 객체 생성 완료');

      print('🔌 [AMQP] 서버 연결 시도 시작');
      await _client!.connect();

      print('✅ [AMQP] 서버 연결 성공');
    } catch (e) {
      print('❌ [AMQP] 클라이언트 연결 실패');
      print('❌ [AMQP] 에러 상세 정보:');
      print('   - 에러 타입: ${e.runtimeType}');
      print('   - 에러 메시지: $e');
      print('   - 호스트: $_host');
      print('   - 포트: $_port');
      print('   - 사용자명: $_username');
      throw Exception('클라이언트 연결 실패: $e');
    }
  }

  /// 채널 생성 수행 (독립 메서드) - 무조건 기존 리소스 정리 후 새 채널 생성
  Future<void> _createChannel() async {
    try {
      // === 새 채널 생성 전 무조건 기존 리소스 완전 정리 ===
      print('🧹 [AMQP] 새 채널 생성 전 기존 리소스 무조건 정리 시작');
      print(
          '🧹 [AMQP] 현재 상태: 채널=${_channel != null ? "있음" : "없음"}, Consumer=${_consumers.length}개');

      // 1단계: 모든 Consumer 강제 정리 (stale consumer 방지)
      await _forceCleanupAllConsumers();

      // 2단계: 채널 강제 정리 (stale channel 방지)
      await _forceCleanupChannel();

      // 3단계: 서버 측 리소스 정리 완료 대기
      await Future.delayed(Duration(milliseconds: 800));

      print('✅ [AMQP] 기존 리소스 무조건 정리 완료');

      // === 새로운 채널 생성 ===
      print('🔧 [AMQP] 새로운 AMQP 채널 생성 시도');
      _channel = await _client!.channel();
      print('✅ [AMQP] 새로운 AMQP 채널 생성 성공');
      print('✅ [AMQP] 채널 정보:');
      print('   - 채널 존재: ${_channel != null ? "있음" : "없음"}');
    } catch (e) {
      print('❌ [AMQP] 채널 생성 실패');
      print('❌ [AMQP] 에러 상세 정보:');
      print('   - 에러 타입: ${e.runtimeType}');
      print('   - 에러 메시지: $e');
      print('   - 클라이언트 상태: ${_client != null ? "존재함" : "존재하지 않음"}');
      throw Exception('채널 생성 실패: $e');
    }
  }

  /// 큐 및 Consumer를 순차적으로 설정 (기존 로직 재사용)
  Future<void> _setupQueuesSequentially() async {
    try {
      await _setupQueuesAndConsumers();

      // Consumer 생성 검증
      if (_consumers.isEmpty) {
        throw Exception('Consumer 생성에 실패했습니다. 생성된 Consumer가 없습니다.');
      }

      print('✅ [AMQP] 큐 및 Consumer 설정 완료');
      print('✅ [AMQP] 최종 Consumer 수: ${_consumers.length}');
      print('✅ [AMQP] Consumer 목록: ${_consumers.keys.toList()}');
    } catch (e) {
      print('❌ [AMQP] 큐 및 Consumer 설정 실패: $e');
      throw Exception('큐 및 Consumer 설정 실패: $e');
    }
  }

  /// 연결 상태 완전 검증 (실제 네트워크 테스트 포함)
  Future<bool> _verifyConnectionState() async {
    print('🔍 [AMQP] 연결 상태 완전 검증 시작');

    try {
      // 1. 기본 리소스 존재 확인
      if (_client == null || _channel == null) {
        print(
            '❌ [AMQP] 기본 리소스 누락 (client: ${_client != null}, channel: ${_channel != null})');
        return false;
      }

      // 2. Consumer 상태 확인
      if (_consumers.isEmpty) {
        print('❌ [AMQP] Consumer가 없음');
        return false;
      }

      // 3. Consumer 활성 상태 확인
      for (final entry in _consumers.entries) {
        print('✅ [AMQP] Consumer 활성 확인: ${entry.key}');
      }

      print('✅ [AMQP] 연결 상태 완전 검증 성공');
      return true;
    } catch (e) {
      print('❌ [AMQP] 연결 상태 검증 중 예외: $e');
      return false;
    }
  }

  /// 헬스체크 시작 (heartbeat로 대체하여 간소화)
  void _startHealthCheck() {
    AmqpLogger.info('헬스체크 비활성화 - heartbeat로 연결 관리');

    // heartbeat가 연결 끊김을 자동으로 감지하므로 별도 헬스체크 불필요
    // 필요시 Consumer 상태만 확인하는 간단한 체크로 대체 가능
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  /// 헬스체크 중지
  void _stopHealthCheck() {
    AmqpLogger.info('헬스체크 중지');
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  /// 확실한 재연결 보장 (다중 전략 사용)
  void _ensureReconnection(String reason) {
    AmqpLogger.reconnect('재연결 보장 시작: $reason');

    // 1. 즉시 상태 동기화
    _setConnected(false, reason);
    _stopAllConsumersImmediately();
    _stopHealthCheck(); // 기존 헬스체크 중지
    _stopStatusMonitoring(); // 상태 모니터링 중지

    // 2. 기존 재연결 타이머들 취소
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // 3. 다중 재연결 전략 시작
    _startMultipleReconnectStrategies(reason);

    AmqpLogger.debug('다중 재연결 전략 설정 완료');
  }

  /// 다중 재연결 전략 시작
  void _startMultipleReconnectStrategies(String reason) {
    AmqpLogger.debug('다중 재연결 전략 시작: $reason');

    // 전략 1: 즉시 재연결 시도 (실패해도 계속 진행)
    _attemptImmediateReconnect(reason);

    // 전략 2: 지연 재연결 (타이머 기반, 더 안전)
    _scheduleEnhancedDelayedReconnect(reason);

    AmqpLogger.debug('다중 재연결 전략 설정 완료');
  }

  /// 전략 1: 즉시 재연결 시도
  Future<void> _attemptImmediateReconnect(String reason) async {
    AmqpLogger.debug('즉시 재연결 시도: $reason');

    try {
      // 최소 안정화 시간
      await Future.delayed(Duration(milliseconds: 1000));

      if (_currentUserId != null && !_isConnected && !_isConnecting) {
        AmqpLogger.debug('즉시 재연결 실행');
        final success = await connect(_currentUserId!);
        if (success) {
          AmqpLogger.success('즉시 재연결 성공!');
          _cancelAllReconnectStrategies(); // 다른 전략 중단
          return;
        } else {
          AmqpLogger.debug('즉시 재연결 실패 (백업 전략 실행)');
        }
      } else {
        AmqpLogger.debug('즉시 재연결 조건 불만족 (백업 전략 실행)');
      }
    } catch (e) {
      AmqpLogger.debug('즉시 재연결 중 예외 (백업 전략 실행)');
    }
  }

  /// 전략 2: 향상된 지연 재연결 (포기하지 않는 재연결)
  void _scheduleEnhancedDelayedReconnect(String reason) {
    final baseDelay = 8; // 기본 8초
    final additionalDelay = _consecutiveFailures * 2; // 실패할수록 더 길게
    final totalDelay = baseDelay + additionalDelay;

    AmqpLogger.reconnect(
        '지연 재연결 예약: ${totalDelay}초 후 (연속실패: $_consecutiveFailures회)');

    _reconnectTimer = Timer(Duration(seconds: totalDelay), () async {
      AmqpLogger.reconnect('지연 재연결 시작');

      if (!_isConnected && _currentUserId != null && !_isConnecting) {
        try {
          AmqpLogger.debug('지연 재연결 시도 중...');
          final success = await connect(_currentUserId!);

          if (success) {
            AmqpLogger.success('지연 재연결 성공!');
            _consecutiveFailures = 0; // 성공 시 실패 카운터 리셋
            _cancelAllReconnectStrategies();
          } else {
            _consecutiveFailures++;
            AmqpLogger.warn('지연 재연결 실패 (연속 ${_consecutiveFailures}회)');

            // 실패 시 다시 스케줄링 (최대 15회까지 포기하지 않음)
            if (_consecutiveFailures < 15) {
              AmqpLogger.reconnect('재연결 재시도 예약 (${_consecutiveFailures}/15)');
              _scheduleEnhancedDelayedReconnect(
                  '지연재연결실패_${_consecutiveFailures}회');
            } else {
              AmqpLogger.error('최대 재연결 시도 횟수 초과 - 포기');
              _setConnected(false, '최대 재연결 시도 초과');
            }
          }
        } catch (e) {
          _consecutiveFailures++;
          AmqpLogger.error('지연 재연결 중 예외 (연속 ${_consecutiveFailures}회)', e);

          // 예외 발생 시에도 재시도
          if (_consecutiveFailures < 15) {
            _scheduleEnhancedDelayedReconnect(
                '지연재연결예외_${_consecutiveFailures}회');
          }
        }
      } else {
        print('ℹ️ [AMQP] 지연 재연결 조건 불만족');
      }
    });
  }

  /// 모든 재연결 전략 중단 (연결 성공 시)
  void _cancelAllReconnectStrategies() {
    print('🛑 [AMQP] 모든 재연결 전략 중단 (연결 성공)');

    // 재연결 타이머 중단
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // 실패 카운터 리셋
    _consecutiveFailures = 0;

    print('✅ [AMQP] 재연결 전략 중단 완료');
  }

  /// AMQP 연결을 안전하게 종료하고 모든 리소스를 정리합니다.
  /// 순차 처리로 개선됨 (Mutex 패턴 적용)
  Future<void> disconnect() async {
    print('🔌 [AMQP] ===== disconnect() 순차 처리 시작 =====');

    // Mutex 패턴: 연결 해제 중복 방지
    if (_isDisconnecting) {
      print('⏳ [AMQP] 이미 연결 해제 작업이 진행 중입니다.');
      return;
    }

    if (!_isConnected &&
        _consumers.isEmpty &&
        _client == null &&
        _channel == null) {
      print('⚠️ [AMQP] 이미 연결 종료된 상태입니다.');
      return;
    }

    _isDisconnecting = true;
    try {
      print('🔌 [AMQP] 순차적 연결 해제 프로세스 시작');

      // === 1단계: 모든 재연결 전략 중단 ===
      print('🛑 [AMQP] 1단계: 재연결 전략 중단');
      _cancelAllReconnectStrategies();
      _stopHealthCheck();
      await Future.delayed(Duration(milliseconds: 200)); // 안정화 대기
      print('✅ [AMQP] 1단계 완료 - 200ms 안정화 대기');

      // === 2단계: 헬스체크 및 상태 모니터링 중지 ===
      print('⏹️ [AMQP] 2단계: 헬스체크 및 상태 모니터링 중지');
      _stopHealthCheck();
      _stopStatusMonitoring();
      await Future.delayed(Duration(milliseconds: 100)); // 안정화 대기
      print('✅ [AMQP] 2단계 완료 - 100ms 안정화 대기');

      // === 3단계: 연결 상태 false로 설정 ===
      print('🔄 [AMQP] 3단계: 연결 상태 false로 설정');
      _setConnected(false, '순차적 연결 해제 시작');
      await Future.delayed(Duration(milliseconds: 100)); // 안정화 대기
      print('✅ [AMQP] 3단계 완료 - 100ms 안정화 대기');

      // === 4단계: 리소스 완전 정리 ===
      print('🧹 [AMQP] 4단계: 리소스 완전 정리');
      await _cleanupResources();
      await Future.delayed(Duration(milliseconds: 300)); // 리소스 정리 안정화 대기
      print('✅ [AMQP] 4단계 완료 - 300ms 리소스 정리 안정화 대기');

      // === 5단계: 상태 완전 초기화 ===
      print('🔄 [AMQP] 5단계: 상태 완전 초기화');
      _currentUserId = null;
      _isPrivacyAgreed = false;
      _reconnectAttempts = 0;
      _consecutiveFailures = 0;
      await Future.delayed(Duration(milliseconds: 100)); // 최종 안정화
      print('✅ [AMQP] 5단계 완료 - 100ms 최종 안정화 대기');

      _setConnected(false, '순차적 연결 해제 완료');
      print('🎉 [AMQP] === 순차적 연결 해제 성공: 총 800ms 안정화 시간 확보 ===');
    } catch (e) {
      print('❌ [AMQP] 순차적 연결 해제 중 오류: $e');
    } finally {
      _isDisconnecting = false;
    }

    print('✅ [AMQP] ===== disconnect() 순차 처리 완료 =====');
  }

  /// 앱 종료 시 모든 AMQP 관련 리소스를 정리합니다.
  Future<void> dispose() async {
    print('🧹 [AMQP] dispose() 시작');
    print('🧹 [AMQP] 서비스 전체 리소스 정리 시작...');

    // 상태 모니터링 중지
    _stopStatusMonitoring();

    await disconnect();
    _giftMessageController.close();
    _alertMessageController.close();
    print('🧹 [AMQP] 서비스 전체 리소스 정리 완료.');
  }

  // --- Private Core Logic ---

  /// 어떤 이유로든 연결이 끊겼을 때 호출되는 통합 에러 핸들러.
  void _handleDisconnection(String reason) {
    print('🚨 [AMQP] ===== _handleDisconnection() 호출 =====');
    print('🚨 [AMQP] 호출 정보:');
    print('   - 사유: $reason');
    print('   - 현재 연결 상태: $_isConnected');
    print('   - 현재 사용자 ID: $_currentUserId');
    print('   - 재연결 시도 횟수: $_reconnectAttempts');
    print('   - 활성 Consumer 수: ${_consumers.length}');
    print('   - 클라이언트 존재: ${_client != null ? "있음" : "없음"}');
    print('   - 채널 존재: ${_channel != null ? "있음" : "없음"}');

    if (!_isConnected) {
      print('⚠️ [AMQP] 이미 연결되지 않은 상태 - 재연결 건너뜀');
      print('⚠️ [AMQP] 무한루프 방지: 즉시 return');
      return;
    }

    print('🚨 [AMQP] 연결 끊김 감지! 사유: $reason');
    print('🚨 [AMQP] 재연결 프로세스 시작');
    _setConnected(false, '연결 끊김 감지 - 재연결 시작');
    _attemptReconnect();
    print('🚨 [AMQP] ===== _handleDisconnection() 완료 =====');
  }

  /// 🚨 메시지 reject 후 Consumer 정지 및 확실한 재연결 보장
  /// 무한루프 방지를 위한 핵심 메서드 (개선됨)
  void _handleMessageRejectAndStop(String reason) {
    print('🚨 [AMQP] _handleMessageRejectAndStop() 시작: $reason');

    // 새로운 확실한 재연결 보장 시스템 사용
    _ensureReconnection('메시지처리실패_' + reason);

    print('🚨 [AMQP] _handleMessageRejectAndStop() 완료 - 확실한 재연결 보장 적용');
  }

  /// 🚨 모든 Consumer를 즉시 정지 (추가 메시지 수신 방지)
  void _stopAllConsumersImmediately() {
    print('🛑 [AMQP] _stopAllConsumersImmediately() 시작');

    final consumersToStop = List.of(_consumers.values);
    _consumers.clear(); // Map을 즉시 비워서 참조 제거

    for (final consumer in consumersToStop) {
      try {
        // Consumer 리스너를 즉시 취소하여 메시지 수신 중단
        consumer.cancel().catchError((e) {
          print('⚠️ [AMQP] Consumer 정지 중 오류 (무시): $e');
          return consumer; // Consumer 반환
        });
      } catch (e) {
        print('⚠️ [AMQP] Consumer 정지 실패 (무시): $e');
      }
    }

    print('🛑 [AMQP] 모든 Consumer 정지 완료 (${consumersToStop.length}개)');
  }

  /// 구 방식 재연결 시스템 (신규 _ensureReconnection으로 대체됨)
  /// 호환성을 위해 새로운 시스템으로 리다이렉트
  Future<void> _attemptReconnect() async {
    print('🔄 [AMQP] _attemptReconnect() 호출됨 - 새로운 재연결 시스템으로 리다이렉트');
    _ensureReconnection('레거시_attemptReconnect_호출');
  }

  /// AMQP 리소스를 안전하게 정리합니다. (중복 실행 방지, 순차적 처리)
  Future<void> _cleanupResources() async {
    print('🧹 [AMQP] _cleanupResources() 호출됨');

    // === 중복 실행 방지 로직 ===
    if (_isCleaningUp) {
      print('⏳ [AMQP] 이미 리소스 정리가 진행 중입니다. 최대 5초 대기합니다.');
      if (_cleanupCompleter != null) {
        try {
          await _cleanupCompleter!.future.timeout(Duration(seconds: 5));
          print('✅ [AMQP] 기존 리소스 정리 작업 완료 대기 완료');
        } catch (e) {
          print('⚠️ [AMQP] 기존 리소스 정리 대기 타임아웃 - 강제 진행: $e');
          _isCleaningUp = false;
          _cleanupCompleter = null;
        }
      }

      // 여전히 정리 중이면 포기하고 리턴
      if (_isCleaningUp) {
        print('⚠️ [AMQP] 리소스 정리 중복 실행 방지를 위해 건너뜁니다.');
        return;
      }
    }

    // === 정리 작업 시작 ===
    _isCleaningUp = true;
    _cleanupCompleter = Completer<void>();

    try {
      print('🧹 [AMQP] 리소스 정리 시작 (순차적 처리)');
      await _performCleanupSequentially().timeout(Duration(seconds: 15));
      print('✅ [AMQP] 리소스 정리 완료');
    } catch (e) {
      print('❌ [AMQP] 리소스 정리 중 예외 발생: $e');
      // 예외 발생 시에도 강제 정리
      await _forceCleanupResources();
    } finally {
      // === 정리 작업 완료 ===
      _isCleaningUp = false;
      _cleanupCompleter?.complete();
      _cleanupCompleter = null;
      print('🔚 [AMQP] 리소스 정리 작업 종료');
    }
  }

  /// 실제 리소스 정리를 순차적으로 수행합니다.
  Future<void> _performCleanupSequentially() async {
    print('🔄 [AMQP] 순차적 리소스 정리 시작');

    // === 1단계: Consumer 정리 ===
    await _cleanupConsumersSequentially();

    // === 2단계: 중간 대기 (Consumer 완전 종료 대기) ===
    print('⏳ [AMQP] Consumer 완전 종료 대기 (500ms)');
    await Future.delayed(Duration(milliseconds: 500));

    // === 3단계: 채널 정리 ===
    await _cleanupChannelSequentially();

    // === 4단계: 중간 대기 (채널 완전 종료 대기) ===
    print('⏳ [AMQP] 채널 완전 종료 대기 (100ms)');
    await Future.delayed(Duration(milliseconds: 100));

    // === 5단계: 클라이언트 정리 ===
    await _cleanupClientSequentially();

    // === 6단계: 최종 검증 ===
    await _verifyCleanupCompletion();
  }

  /// Consumer들을 순차적으로 안전하게 정리합니다.
  Future<void> _cleanupConsumersSequentially() async {
    print('🔒 [AMQP] Consumer 순차 정리 시작 (${_consumers.length}개)');

    if (_consumers.isEmpty) {
      print('ℹ️ [AMQP] 정리할 Consumer가 없습니다.');
      return;
    }

    // Consumer 리스트 복사 후 맵 즉시 클리어
    final consumersToCancel = List.of(_consumers.values);
    final consumerNames = List.of(_consumers.keys);
    _consumers.clear();

    // 각 Consumer를 순차적으로 정리
    for (int i = 0; i < consumersToCancel.length; i++) {
      final consumer = consumersToCancel[i];
      final name = consumerNames[i];

      await _cancelSingleConsumerSafely(consumer, name);

      // Consumer 간 짧은 대기 (안정성 확보)
      if (i < consumersToCancel.length - 1) {
        await Future.delayed(Duration(milliseconds: 50));
      }
    }

    print('✅ [AMQP] 모든 Consumer 순차 정리 완료');
  }

  /// 단일 Consumer를 안전하게 취소합니다. (재시도 포함)
  Future<void> _cancelSingleConsumerSafely(
      amqp.Consumer consumer, String name) async {
    const maxRetries = 3;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('🔒 [AMQP] Consumer 취소 시도 ($attempt/$maxRetries): $name');

        await consumer.cancel().timeout(
          Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('Consumer 취소 타임아웃', Duration(seconds: 5));
          },
        );

        print('✅ [AMQP] Consumer 취소 성공: $name');
        return; // 성공 시 함수 종료
      } catch (e) {
        print('⚠️ [AMQP] Consumer 취소 실패 ($attempt/$maxRetries): $name - $e');

        if (attempt < maxRetries) {
          // 재시도 전 대기 (Exponential Backoff)
          final waitMs = 100 * attempt;
          await Future.delayed(Duration(milliseconds: waitMs));
        } else {
          print('❌ [AMQP] Consumer 취소 최종 실패: $name');
        }
      }
    }
  }

  /// 채널을 순차적으로 안전하게 정리합니다.
  Future<void> _cleanupChannelSequentially() async {
    if (_channel == null) {
      print('ℹ️ [AMQP] 정리할 채널이 없습니다.');
      return;
    }

    const maxRetries = 2;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('🔧 [AMQP] 채널 정리 시도 ($attempt/$maxRetries)');

        await _channel!.close().timeout(
          Duration(seconds: 3),
          onTimeout: () {
            print('⚠️ [AMQP] 채널 정리 타임아웃 - 강제 정리');
            throw TimeoutException('채널 정리 타임아웃', Duration(seconds: 3));
          },
        );

        print('✅ [AMQP] 채널 정리 성공');
        break;
      } catch (e) {
        print('⚠️ [AMQP] 채널 정리 실패 ($attempt/$maxRetries): $e');

        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 100));
        } else {
          print('❌ [AMQP] 채널 정리 최종 실패 - 강제 정리 진행');
        }
      }
    }

    _channel = null;
    print('🔧 [AMQP] 채널 참조 제거 완료');
  }

  /// 클라이언트를 순차적으로 안전하게 정리합니다.
  Future<void> _cleanupClientSequentially() async {
    if (_client == null) {
      print('ℹ️ [AMQP] 정리할 클라이언트가 없습니다.');
      return;
    }

    const maxRetries = 3;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('🔧 [AMQP] 클라이언트 정리 시도 ($attempt/$maxRetries)');

        await _client!.close().timeout(
          Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException('클라이언트 정리 타임아웃', Duration(seconds: 15));
          },
        );

        print('✅ [AMQP] 클라이언트 정리 성공');
        break;
      } catch (e) {
        print('⚠️ [AMQP] 클라이언트 정리 실패 ($attempt/$maxRetries): $e');

        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        } else {
          print('❌ [AMQP] 클라이언트 정리 최종 실패');
        }
      }
    }

    _client = null;
    print('🔧 [AMQP] 클라이언트 참조 제거 완료');
  }

  /// 리소스 정리 완료를 검증합니다.
  Future<void> _verifyCleanupCompletion() async {
    print('🔍 [AMQP] 리소스 정리 완료 검증 시작');

    final hasCleanupIssues =
        _consumers.isNotEmpty || _channel != null || _client != null;

    if (hasCleanupIssues) {
      print('⚠️ [AMQP] 리소스 정리 불완전 감지:');
      print('   - Consumer 수: ${_consumers.length}');
      print('   - 채널: ${_channel != null ? "존재" : "null"}');
      print('   - 클라이언트: ${_client != null ? "존재" : "null"}');

      print('🔧 [AMQP] 강제 정리 수행');
      await _forceCleanupResources();
    } else {
      print('✅ [AMQP] 리소스 정리 완료 검증 성공');
    }
  }

  /// 모든 Consumer를 강제로 즉시 정리합니다 (stale consumer 방지용)
  Future<void> _forceCleanupAllConsumers() async {
    print('⚡ [AMQP] 모든 Consumer 강제 정리 시작');

    if (_consumers.isEmpty) {
      print('ℹ️ [AMQP] 정리할 Consumer가 없습니다.');
      return;
    }

    final consumersToCancel = List.of(_consumers.values);
    final consumerNames = List.of(_consumers.keys);
    _consumers.clear(); // 맵 즉시 비우기

    print('⚡ [AMQP] ${consumersToCancel.length}개 Consumer 강제 취소 시작');

    for (int i = 0; i < consumersToCancel.length; i++) {
      final consumer = consumersToCancel[i];
      final name = consumerNames[i];

      try {
        // 타임아웃 짧게 설정하여 빠른 정리
        await consumer.cancel().timeout(Duration(seconds: 2));
        print('✅ [AMQP] Consumer 강제 취소 성공: $name');
      } catch (e) {
        print('⚠️ [AMQP] Consumer 강제 취소 실패 (무시): $name - $e');
      }
    }

    print('✅ [AMQP] 모든 Consumer 강제 정리 완료');
  }

  /// 채널을 강제로 즉시 정리합니다 (stale channel 방지용)
  Future<void> _forceCleanupChannel() async {
    print('⚡ [AMQP] 채널 강제 정리 시작');

    if (_channel == null) {
      print('ℹ️ [AMQP] 정리할 채널이 없습니다.');
      return;
    }

    try {
      // 타임아웃 짧게 설정하여 빠른 정리
      await _channel!.close().timeout(Duration(seconds: 2));
      print('✅ [AMQP] 채널 강제 닫기 성공');
    } catch (e) {
      print('⚠️ [AMQP] 채널 강제 닫기 실패 (무시): $e');
    }

    _channel = null;
    print('✅ [AMQP] 채널 강제 정리 완료');
  }

  /// 모든 재시도가 실패했을 때 강제로 리소스를 정리합니다.
  Future<void> _forceCleanupResources() async {
    print('⚡ [AMQP] 강제 리소스 정리 시작');

    // Consumer 강제 정리
    if (_consumers.isNotEmpty) {
      print('⚡ [AMQP] Consumer 맵 강제 초기화 (${_consumers.length}개)');
      _consumers.clear();
    }

    // 채널 강제 정리
    if (_channel != null) {
      print('⚡ [AMQP] 채널 강제 null 설정');
      _channel = null;
    }

    // 클라이언트 강제 정리
    if (_client != null) {
      print('⚡ [AMQP] 클라이언트 강제 null 설정');
      _client = null;
    }

    // 메모리 정리 힌트
    await Future.delayed(Duration(milliseconds: 100));

    print('✅ [AMQP] 강제 리소스 정리 완료');
  }

  // --- Consumer & Queue Management ---

  /// 필요한 큐를 생성하고 Consumer를 설정합니다.
  Future<void> _setupQueuesAndConsumers() async {
    print('🔧 [AMQP] _setupQueuesAndConsumers() 시작');

    if (_channel == null || _currentUserId == null) {
      print('❌ [AMQP] 채널 또는 사용자 ID가 없어 큐 설정을 건너뜁니다.');
      return;
    }

    // 기본적으로 alert, event, eapproval, leave.draft 큐는 항상 생성
    final queuesToCreate = ['alert', 'event', 'eapproval.alert', 'leave.draft'];

    // 개인정보 동의 시에만 gift, birthday 큐 추가
    if (_isPrivacyAgreed) {
      queuesToCreate.addAll(['gift', 'birthday']);
    }

    print('🎯 [AMQP] 생성할 큐 목록: $queuesToCreate (개인정보 동의: $_isPrivacyAgreed)');
    for (final queueType in queuesToCreate) {
      print('🔧 [AMQP] 큐 설정 시작: $queueType');
      await _createSingleConsumer(queueType);
    }

    // alert 큐를 broadcast exchange에 바인딩
    print('🔧 [AMQP] alert 큐 broadcast 바인딩 시작');
    await _bindAlertQueueToBroadcast();
    print('✅ [AMQP] _setupQueuesAndConsumers() 완료');
  }

  /// 단일 큐와 Consumer를 생성하고 리스너를 연결합니다.
  Future<void> _createSingleConsumer(String queueType) async {
    print('🔧 [AMQP] _createSingleConsumer() 시작: $queueType');

    if (_channel == null || _currentUserId == null) {
      print('❌ [AMQP] 채널 또는 사용자 ID가 없어 Consumer 생성을 건너뜁니다.');
      return;
    }

    final queueName = '$queueType.$_currentUserId';
    print('🔧 [AMQP] 큐 이름: $queueName');

    // 기존 Consumer가 있고 유효한지 확인
    if (_consumers.containsKey(queueName)) {
      print('🔍 [AMQP] 기존 Consumer 존재 확인: $queueName');
      final existingConsumer = _consumers[queueName];
      if (existingConsumer != null) {
        try {
          // Consumer가 여전히 유효한지 간단한 테스트 (cancel 시도 후 즉시 복원하지 않음)
          print('✅ [AMQP] 기존 Consumer가 유효함 - 재사용: $queueName');
          return;
        } catch (e) {
          print('⚠️ [AMQP] 기존 Consumer가 무효함 - 새로 생성: $queueName');
          _consumers.remove(queueName);
        }
      }
    }

    // === 1단계: 큐 생성 ===
    amqp.Queue? queue;
    try {
      print('🔧 [AMQP] 1단계: 큐 생성 시도: $queueName');
      queue = await _channel!.queue(queueName, durable: true);
      print('✅ [AMQP] 1단계 완료: 큐 생성 성공: $queueName');
    } catch (e) {
      print('❌ [AMQP] 1단계 실패: 큐 생성 실패 ($queueName)');
      print('   - 에러: $e');
      return; // 큐 생성 실패 시 Consumer 생성 건너뜀
    }

    // === 2단계: Consumer 생성 ===
    amqp.Consumer? consumer;
    try {
      print('🔧 [AMQP] 2단계: Consumer 생성 시도: $queueName');
      consumer = await queue.consume(noAck: false);

      print('✅ [AMQP] 2단계 완료: Consumer 생성 성공: $queueName');
    } catch (e) {
      print('❌ [AMQP] 2단계 실패: Consumer 생성 실패 ($queueName)');
      print('   - 에러: $e');
      return; // Consumer 생성 실패 시 리스너 설정 건너뜀
    }

    // === 3단계: Consumer 리스너 설정 ===
    try {
      print('🔧 [AMQP] 3단계: Consumer 리스너 설정: $queueName');
      consumer.listen(
        (message) {
          print('📨 [AMQP] 메시지 수신: $queueName');
          _handleMessage(message, queueType);
        },
        // onError, onDone 제거 - 무한루프 방지
      );

      _consumers[queueName] = consumer;
      print('✅ [AMQP] 3단계 완료: Consumer 리스너 설정 성공: $queueName');
      print('✅ [AMQP] Consumer 생성 및 구독 완료: $queueName');
    } catch (e) {
      print('❌ [AMQP] 3단계 실패: Consumer 리스너 설정 실패 ($queueName)');
      print('   - 에러: $e');
      // Consumer는 생성되었지만 리스너 설정 실패
      try {
        await consumer.cancel();
      } catch (cancelError) {
        print('⚠️ [AMQP] Consumer 취소 실패: $cancelError');
      }
    }
  }

  /// alert 큐를 broadcast exchange에 바인딩합니다.
  Future<void> _bindAlertQueueToBroadcast() async {
    print('🔧 [AMQP] _bindAlertQueueToBroadcast() 시작');

    if (_channel == null || _currentUserId == null) {
      print('❌ [AMQP] 채널 또는 사용자 ID가 없어 바인딩을 건너뜁니다.');
      return;
    }

    // 채널 상태 확인 - 더 안전한 방법 사용
    try {
      // 채널의 기본 속성에 접근해서 상태 확인
      if (_channel == null) {
        print('❌ [AMQP] 채널이 null이어서 바인딩을 건너뜁니다.');
        return;
      }
    } catch (e) {
      print('❌ [AMQP] 채널 상태 확인 실패로 바인딩을 건너뜁니다: $e');
      return;
    }

    final queueName = 'alert.$_currentUserId';
    final exchangeName = 'alert.broadcast';

    print('🔧 [AMQP] 바인딩 정보:');
    print('   - 큐 이름: $queueName');
    print('   - Exchange 이름: $exchangeName');

    try {
      // exchange 선언 (fanout 타입)
      print('🔧 [AMQP] Exchange 선언 시도: $exchangeName');
      final exchange = await _channel!
          .exchange(exchangeName, amqp.ExchangeType.FANOUT, durable: true);
      print('✅ [AMQP] Exchange 선언 완료: $exchangeName');

      // 큐를 exchange에 바인딩
      print('🔧 [AMQP] 큐 바인딩 시도: $queueName -> $exchangeName');
      final queue = await _channel!.queue(queueName, durable: true);
      await queue.bind(exchange, '');
      print('✅ [AMQP] 큐 바인딩 완료: $queueName -> $exchangeName');
    } catch (e) {
      print('❌ [AMQP] alert 큐 broadcast 바인딩 실패: $e');
      print('❌ [AMQP] 실패 상세 정보:');
      print('   - 큐 이름: $queueName');
      print('   - Exchange 이름: $exchangeName');
      print('   - 에러 타입: ${e.runtimeType}');
      print('   - 에러 메시지: $e');
      // 바인딩 실패는 치명적이지 않으므로 예외를 다시 던지지 않음
    }
  }

  // --- Message Handling ---

  /// 모든 큐 메시지의 중앙 처리 지점.
  void _handleMessage(amqp.AmqpMessage message, String queueType) {
    print('📨 [AMQP] _handleMessage() 시작: $queueType');

    try {
      print('🔔 [AMQP] 메시지 페이로드 디코딩 시작');

      // payload null 체크
      if (message.payload == null) {
        print('⚠️ [AMQP] 메시지 payload가 null입니다. 빈 메시지로 처리');
        try {
          message.ack();
        } catch (ackError) {
          print('⚠️ [AMQP] null payload 메시지 ACK 실패: $ackError');
        }
        return;
      }

      final messageBody = utf8.decode(message.payload!);
      print('🔔 [AMQP] 원본 메시지 수신 ($queueType): $messageBody');

      // 메시지 형식에 따라 처리
      print('🔧 [AMQP] JSON 파싱 시도');
      dynamic data;
      try {
        data = json.decode(messageBody);
        print('🔔 [AMQP] 파싱된 메시지 ($queueType): $data');
      } catch (parseError) {
        print('ℹ️ [AMQP] JSON 파싱 실패, 원본 메시지를 문자열로 처리');
        // JSON이 아닌 경우 원본 메시지를 문자열로 처리
        data = {'message': messageBody, 'title': '메시지'};
      }

      // Map<String, dynamic>으로 변환
      print('🔧 [AMQP] 메시지 데이터 변환');
      Map<String, dynamic> messageData;
      if (data is Map<String, dynamic>) {
        messageData = data;
      } else if (data is Map) {
        messageData = Map<String, dynamic>.from(data);
      } else {
        // 다른 타입의 경우 기본 형식으로 변환
        messageData = {
          'message': data.toString(),
          'title': '메시지',
          'type': queueType,
        };
      }

      print('🔧 [AMQP] 메시지 타입별 처리 시작: $queueType');
      switch (queueType) {
        case 'gift':
          print('🎁 [AMQP] 선물 메시지 처리로 분기');
          _handleGiftMessage(messageData, message);
          break;
        case 'alert':
          print('🔔 [AMQP] 알림 메시지 처리로 분기');
          _handleAlertMessage(messageData, message);
          break;
        case 'birthday':
          print('🎂 [AMQP] 생일 메시지 처리로 분기');
          _handleBirthdayMessage(messageData, message);
          break;
        case 'event':
          print('🎁 [AMQP] 이벤트 메시지 처리로 분기');
          _handleEventMessage(messageData, message);
          break;
        case 'eapproval.alert':
          print('📋 [AMQP] 전자결재 알림 메시지 처리로 분기');
          _handleEapprovalMessage(messageData, message);
          break;
        case 'leave.draft':
          print('📋 [AMQP] 휴가 초안 메시지 처리로 분기');
          _handleLeaveDraftMessage(messageData, message);
          break;
        default:
          print('🔔 [AMQP] 알 수 없는 큐 타입 ($queueType), 메시지: $messageData');
          try {
            message.ack();
          } catch (ackError) {
            print('⚠️ [AMQP] 메시지 ack 실패 (채널이 닫혔을 수 있음): $ackError');
          }
      }
    } catch (e) {
      print('❌ [AMQP] 메시지 처리 중 오류 발생: $e');
      print('❌ [AMQP] 오류 상세 정보:');
      print('   - 큐 타입: $queueType');
      print('   - 에러 타입: ${e.runtimeType}');
      print('   - 에러 메시지: $e');
      print(
          '❌ [AMQP] 원본 메시지: ${message.payload != null ? utf8.decode(message.payload!) : "null"}');
      // 🚨 무한루프 방지: reject 후 Consumer 즉시 정지 및 딜레이 적용
      print('🚨 [AMQP] 메시지 파싱 실패 - reject 후 Consumer 정지');
      message.reject(true); // 메시지를 큐로 재전송
      _handleMessageRejectAndStop(
          'MESSAGE_PARSING_ERROR'); // Consumer 정지 후 딜레이 재연결
    }
  }

  /// 선물 메시지를 처리합니다.
  void _handleGiftMessage(
      Map<String, dynamic> data, amqp.AmqpMessage originalMessage) async {
    print('🎁 [AMQP] _handleGiftMessage() 시작');

    try {
      print('🎁 [AMQP] 선물 메시지 처리 시작: $data');

      // UI에 표시
      print('🎁 [AMQP] 선물 도착 팝업 표시 시도');
      _showNewGiftArrivalPopup(data);
      print('✅ [AMQP] 선물 도착 팝업 표시 완료');

      // 채팅 메시지 추가 기능 제거 (팝업만 표시)
      // print('🎁 [AMQP] 채팅 메시지 추가 시도');
      // _addGiftArrivalChatMessage(data);
      // print('✅ [AMQP] 채팅 메시지 추가 완료');

      print('🎁 [AMQP] 알림 인디케이터 설정');
      _notificationNotifier?.setNewGiftIndicator(true);
      print('✅ [AMQP] 알림 인디케이터 설정 완료');

      // 선물 개수 업데이트 콜백 호출
      if (_onGiftCountUpdate != null) {
        print('🎁 [AMQP] 선물 개수 업데이트 콜백 호출');
        _onGiftCountUpdate!();
        print('✅ [AMQP] 선물 개수 업데이트 콜백 완료');
      }

      // 서버 알림 데이터 업데이트
      if (_currentUserId != null) {
        print('🎁 [AMQP] 서버 알림 데이터 업데이트 시도');
        final response = await ApiService.checkAlerts(_currentUserId!);
        final alerts = response['alerts'] as List<dynamic>? ?? [];
        _notificationNotifier
            ?.updateServerAlerts(alerts.cast<Map<String, dynamic>>());
        print('✅ [AMQP] 서버 알림 데이터 업데이트 완료');
      }

      // UI 표시 완료 후 ACK
      print('🔧 [AMQP] 메시지 ACK 처리');
      try {
        originalMessage.ack();
        print('✅ [AMQP] 선물 메시지 UI 표시 완료, ACK 처리');
      } catch (ackError) {
        print('⚠️ [AMQP] 메시지 ACK 실패 (채널이 닫혔을 수 있음): $ackError');
      }
    } catch (e) {
      print('⚠️ [AMQP] 선물 메시지 처리 중 오류: $e');
      print('⚠️ [AMQP] 오류 상세 정보:');
      print('   - 에러 타입: ${e.runtimeType}');
      print('   - 에러 메시지: $e');
      // 🚨 무한루프 방지: reject 후 Consumer 즉시 정지 및 딜레이 적용
      print('🚨 [AMQP] 선물 메시지 처리 실패 - reject 후 Consumer 정지');
      try {
        originalMessage.reject(true); // 메시지를 큐로 재전송
      } catch (rejectError) {
        print('⚠️ [AMQP] 메시지 reject 실패 (채널이 닫혔을 수 있음): $rejectError');
      }
      _handleMessageRejectAndStop('GIFT_UI_ERROR'); // Consumer 정지 후 딜레이 재연결
    }
  }

  /// 일반 알림 메시지를 처리합니다.
  void _handleAlertMessage(
      Map<String, dynamic> data, amqp.AmqpMessage originalMessage) async {
    print('🔔 [AMQP] _handleAlertMessage() 시작');

    try {
      print('🔔 [AMQP] 일반 알림 메시지 처리 시작: $data');

      // Header에서 render_type 확인
      String renderType = 'text'; // 기본값
      try {
        final headers = originalMessage.properties?.headers;
        if (headers != null && headers['render_type'] != null) {
          renderType = headers['render_type'].toString();
          print('🔔 [AMQP] render_type: $renderType');
        }
      } catch (e) {
        print('⚠️ [AMQP] header 파싱 실패, 기본값 사용: $e');
      }

      final alertMessage = data['message'] as String? ?? '';
      final alertTitle = data['title'] as String? ?? '알림';

      // contest_detail 타입인 경우 추가 정보 추출
      int? contestId;
      String? contestType;
      if (renderType == 'contest_detail') {
        contestId = data['contest_id'] as int?;
        contestType = data['contest_type'] as String?;
        print(
            '🔔 [AMQP] contest_detail 타입 - contestId: $contestId, contestType: $contestType');
      }

      // UI에 표시 (2초 지연)
      if (alertMessage.isNotEmpty) {
        // 🔔 로그인 후 너무 빠른 알림 표시 방지를 위해 2초 지연 추가
        Future.delayed(const Duration(seconds: 2), () {
          print('🔔 [AMQP] ===== 전광판 메시지 표시 시작 =====');
          print('🔔 [AMQP] 전광판 메시지: "$alertMessage"');
          print(
              '🔔 [AMQP] _alertTickerNotifier 상태: ${_alertTickerNotifier != null ? "연결됨" : "연결되지 않음"}');

          if (_alertTickerNotifier != null) {
            print('🔔 [AMQP] 알림 티커 메시지 표시 (2초 지연 후)');
            _alertTickerNotifier!.showMessage(alertMessage,
                displayDuration: const Duration(seconds: 30));
            print('✅ [AMQP] 알림 티커 메시지 표시 완료');
          } else {
            print('❌ [AMQP] _alertTickerNotifier가 null입니다. 전광판 메시지 표시 실패');
          }

          print('🔔 [AMQP] 공지사항 채팅 메시지 추가 (2초 지연 후)');
          _addAnnouncementChatMessage(
            alertTitle,
            alertMessage,
            renderType: renderType,
            contestId: contestId,
            contestType: contestType,
          );
          print('✅ [AMQP] 공지사항 채팅 메시지 추가 완료');
          print('🔔 [AMQP] ===== 전광판 메시지 표시 완료 =====');
        });
      } else {
        print('⚠️ [AMQP] alertMessage가 비어있어서 전광판에 표시하지 않습니다.');
      }

      // 서버 알림 데이터 업데이트
      if (_currentUserId != null) {
        print('🔔 [AMQP] 서버 알림 데이터 업데이트 시도');
        final response = await ApiService.checkAlerts(_currentUserId!);
        final alerts = response['alerts'] as List<dynamic>? ?? [];
        _notificationNotifier
            ?.updateServerAlerts(alerts.cast<Map<String, dynamic>>());
        print('✅ [AMQP] 서버 알림 데이터 업데이트 완료');
      }

      // UI 표시 완료 후 ACK
      print('🔧 [AMQP] 메시지 ACK 처리');
      try {
        originalMessage.ack();
        print('✅ [AMQP] 일반 알림 메시지 UI 표시 완료, ACK 처리');
      } catch (ackError) {
        print('⚠️ [AMQP] 메시지 ACK 실패 (채널이 닫혔을 수 있음): $ackError');
      }
    } catch (e) {
      print('⚠️ [AMQP] 일반 알림 메시지 처리 중 오류: $e');
      print('⚠️ [AMQP] 오류 상세 정보:');
      print('   - 에러 타입: ${e.runtimeType}');
      print('   - 에러 메시지: $e');
      // 🚨 무한루프 방지: reject 후 Consumer 즉시 정지 및 딜레이 적용
      print('🚨 [AMQP] 알림 메시지 처리 실패 - reject 후 Consumer 정지');
      try {
        originalMessage.reject(true); // 메시지를 큐로 재전송
      } catch (rejectError) {
        print('⚠️ [AMQP] 메시지 reject 실패 (채널이 닫혔을 수 있음): $rejectError');
      }
      _handleMessageRejectAndStop('ALERT_UI_ERROR'); // Consumer 정지 후 딜레이 재연결
    }
  }

  /// 생일 메시지를 처리합니다.
  void _handleBirthdayMessage(
      Map<String, dynamic> data, amqp.AmqpMessage originalMessage) async {
    print('🎂 [AMQP] ===== 생일 메시지 처리 시작 =====');
    print('🎂 [AMQP] 원본 AMQP 메시지 데이터: $data');

    try {
      print('🎂 [AMQP] 생일 메시지 처리 시작: $data');

      final birthdayMessage = data['message'] as String? ?? '생일을 축하합니다! 🎉';
      final birthdayTitle = data['title'] as String? ?? '생일 축하';
      final realTimeId = data['id'] as String?; // ✅ 서버에서 보낸 id 값 추출

      print('🔍 [AMQP] ===== ID 추출 결과 =====');
      print('🔍 [AMQP] 서버에서 받은 realTimeId: $realTimeId');
      print('🔍 [AMQP] realTimeId 타입: ${realTimeId.runtimeType}');
      print('🔍 [AMQP] realTimeId null 여부: ${realTimeId == null}');

      // 생일 축하 팝업 표시
      print('🎂 [AMQP] 생일 축하 팝업 표시');
      _showBirthdayPopup(birthdayMessage, realTimeId: realTimeId);
      print('✅ [AMQP] 생일 축하 팝업 표시 완료');

      // 알림 티커에도 표시 (2초 지연)
      Future.delayed(const Duration(seconds: 2), () {
        print('🎂 [AMQP] ===== 생일 전광판 메시지 표시 시작 =====');
        print('🎂 [AMQP] 생일 전광판 메시지: "$birthdayMessage"');
        print(
            '🎂 [AMQP] _alertTickerNotifier 상태: ${_alertTickerNotifier != null ? "연결됨" : "연결되지 않음"}');

        if (_alertTickerNotifier != null) {
          print('🎂 [AMQP] 알림 티커에 생일 메시지 표시 (2초 지연 후)');
          _alertTickerNotifier!.showMessage(birthdayMessage,
              displayDuration: const Duration(seconds: 30));
          print('✅ [AMQP] 알림 티커 메시지 표시 완료');
        } else {
          print('❌ [AMQP] _alertTickerNotifier가 null입니다. 생일 전광판 메시지 표시 실패');
        }
        print('🎂 [AMQP] ===== 생일 전광판 메시지 표시 완료 =====');
      });

      // 채팅창에 생일 메시지 추가 (realTimeId 포함)
      print('🎂 [AMQP] 채팅창에 생일 메시지 추가 시작');
      _addBirthdayChatMessage(birthdayTitle, birthdayMessage, realTimeId);
      print('✅ [AMQP] 채팅창 생일 메시지 추가 완료');

      // 서버 알림 데이터 업데이트
      if (_currentUserId != null) {
        print('🎂 [AMQP] 서버 알림 데이터 업데이트 시도');
        final response = await ApiService.checkAlerts(_currentUserId!);
        final alerts = response['alerts'] as List<dynamic>? ?? [];
        _notificationNotifier
            ?.updateServerAlerts(alerts.cast<Map<String, dynamic>>());
        print('✅ [AMQP] 서버 알림 데이터 업데이트 완료');
      }

      // UI 표시 완료 후 ACK
      print('🔧 [AMQP] 메시지 ACK 처리');
      try {
        originalMessage.ack();
        print('✅ [AMQP] 생일 메시지 UI 표시 완료, ACK 처리');
      } catch (ackError) {
        print('⚠️ [AMQP] 메시지 ACK 실패 (채널이 닫혔을 수 있음): $ackError');
      }

      print('🎂 [AMQP] ===== 생일 메시지 처리 완료 =====');
    } catch (e) {
      print('⚠️ [AMQP] 생일 메시지 처리 중 오류: $e');
      print('⚠️ [AMQP] 오류 상세 정보:');
      print('   - 에러 타입: ${e.runtimeType}');
      print('   - 에러 메시지: $e');
      // 🚨 무한루프 방지: reject 후 Consumer 즉시 정지 및 딜레이 적용
      print('🚨 [AMQP] 생일 메시지 처리 실패 - reject 후 Consumer 정지');
      try {
        originalMessage.reject(true); // 메시지를 큐로 재전송
      } catch (rejectError) {
        print('⚠️ [AMQP] 메시지 reject 실패 (채널이 닫혔을 수 있음): $rejectError');
      }
      _handleMessageRejectAndStop('BIRTHDAY_UI_ERROR'); // Consumer 정지 후 딜레이 재연결
    }
  }

  /// 이벤트 메시지를 처리합니다.
  void _handleEventMessage(
      Map<String, dynamic> data, amqp.AmqpMessage originalMessage) async {
    print('🎁 [AMQP] ===== 이벤트 메시지 처리 시작 =====');
    print('🎁 [AMQP] 원본 AMQP 메시지 데이터: $data');

    try {
      print('🎁 [AMQP] 이벤트 메시지 처리 시작: $data');

      final eventMessage = data['message'] as String? ?? '이벤트 메시지입니다! 🎁';
      final eventTitle = data['title'] as String? ?? '';
      final realTimeId = data['id'] as String?; // ✅ 서버에서 보낸 id 값 추출

      print('🔍 [AMQP] ===== ID 추출 결과 =====');
      print('🔍 [AMQP] 서버에서 받은 realTimeId: $realTimeId');
      print('🔍 [AMQP] realTimeId 타입: ${realTimeId.runtimeType}');
      print('🔍 [AMQP] realTimeId null 여부: ${realTimeId == null}');

      // 이벤트 팝업 표시
      print('🎁 [AMQP] 이벤트 팝업 표시');
      _showEventPopup(eventTitle, eventMessage, realTimeId: realTimeId);
      print('✅ [AMQP] 이벤트 팝업 표시 완료');

      // 알림 티커에도 표시 (2초 지연)
      Future.delayed(const Duration(seconds: 2), () {
        print('🎁 [AMQP] ===== 이벤트 전광판 메시지 표시 시작 =====');
        print('🎁 [AMQP] 이벤트 전광판 메시지: "$eventMessage"');
        print(
            '🎁 [AMQP] _alertTickerNotifier 상태: ${_alertTickerNotifier != null ? "연결됨" : "연결되지 않음"}');

        if (_alertTickerNotifier != null) {
          print('🎁 [AMQP] 알림 티커에 이벤트 메시지 표시 (2초 지연 후)');
          _alertTickerNotifier!.showMessage(eventMessage,
              displayDuration: const Duration(seconds: 30));
          print('✅ [AMQP] 알림 티커 메시지 표시 완료');
        } else {
          print('❌ [AMQP] _alertTickerNotifier가 null입니다. 이벤트 전광판 메시지 표시 실패');
        }
        print('🎁 [AMQP] ===== 이벤트 전광판 메시지 표시 완료 =====');
      });

      // 이벤트 메시지는 채팅창에 표시하지 않음 (birthday만 채팅창에 표시)
      print('🎁 [AMQP] 이벤트 메시지는 채팅창에 표시하지 않음');

      // 서버 알림 데이터 업데이트
      if (_currentUserId != null) {
        print('🎁 [AMQP] 서버 알림 데이터 업데이트 시도');
        final response = await ApiService.checkAlerts(_currentUserId!);
        final alerts = response['alerts'] as List<dynamic>? ?? [];
        _notificationNotifier
            ?.updateServerAlerts(alerts.cast<Map<String, dynamic>>());
        print('✅ [AMQP] 서버 알림 데이터 업데이트 완료');
      }

      // UI 표시 완료 후 ACK
      print('🔧 [AMQP] 메시지 ACK 처리');
      try {
        originalMessage.ack();
        print('✅ [AMQP] 이벤트 메시지 UI 표시 완료, ACK 처리');
      } catch (ackError) {
        print('⚠️ [AMQP] 메시지 ACK 실패 (채널이 닫혔을 수 있음): $ackError');
      }

      print('🎁 [AMQP] ===== 이벤트 메시지 처리 완료 =====');
    } catch (e) {
      print('⚠️ [AMQP] 이벤트 메시지 처리 중 오류: $e');
      print('⚠️ [AMQP] 오류 상세 정보:');
      print('   - 에러 타입: ${e.runtimeType}');
      print('   - 에러 메시지: $e');
      // 🚨 무한루프 방지: reject 후 Consumer 즉시 정지 및 딜레이 적용
      print('🚨 [AMQP] 이벤트 메시지 처리 실패 - reject 후 Consumer 정지');
      try {
        originalMessage.reject(true); // 메시지를 큐로 재전송
      } catch (rejectError) {
        print('⚠️ [AMQP] 메시지 reject 실패 (채널이 닫혔을 수 있음): $rejectError');
      }
      _handleMessageRejectAndStop('EVENT_UI_ERROR'); // Consumer 정지 후 딜레이 재연결
    }
  }

  /// 전자결재 승인/반려 알림 메시지를 처리합니다.
  void _handleEapprovalMessage(
      Map<String, dynamic> data, amqp.AmqpMessage originalMessage) async {
    print('📋 [AMQP] ===== 전자결재 알림 메시지 처리 시작 =====');
    print('📋 [AMQP] 원본 AMQP 메시지 데이터: $data');

    try {
      print('📋 [AMQP] 전자결재 알림 메시지 처리 시작: $data');

      final title = data['title'] as String? ?? '전자결재 알림';
      final status = data['status'] as String? ?? 'UNKNOWN';
      final approvalType =
          data['approval_type'] as String?; // hr_leave_grant 또는 eapproval
      final comment = data['comment'] as String?;

      // 🔍 [CANCEL_DEBUG] AMQP 메시지 전체 확인
      print('\n🔍 [CANCEL_DEBUG] ========== AMQP 메시지 전체 확인 ==========');
      print('🔍 [CANCEL_DEBUG] 전체 메시지 데이터: $data');
      print(
          '🔍 [CANCEL_DEBUG] 메시지에 is_cancel 필드 있는지: ${data.containsKey('is_cancel')}');
      if (data.containsKey('is_cancel')) {
        print('🔍 [CANCEL_DEBUG] ⭐⭐⭐ is_cancel 값: ${data['is_cancel']} ⭐⭐⭐');
      }
      print('🔍 [CANCEL_DEBUG] 메시지에 id 필드 있는지: ${data.containsKey('id')}');
      if (data.containsKey('id')) {
        print('🔍 [CANCEL_DEBUG] id 값: ${data['id']}');
      }
      print('🔍 [CANCEL_DEBUG] ==========================================\n');

      print('📋 [AMQP] 메시지 파싱 결과:');
      print('   - title: $title');
      print('   - status: $status');
      print('   - comment: $comment');

      // 전자결재 승인/반려 알림 표시 (SnackBar)
      print('📋 [AMQP] 전자결재 알림 표시');
      _showEapprovalAlert(title, status, comment, approvalType: approvalType);
      print('✅ [AMQP] 전자결재 알림 표시 완료');

      // 🔄 [CANCEL_DEBUG] 휴가 관련 알림이면 데이터 자동 새로고침
      if (approvalType == 'hr_leave' ||
          approvalType == 'hr_leave_grant' ||
          title.contains('휴가') ||
          title.contains('연차')) {
        print('🔄 [CANCEL_DEBUG] 휴가 관련 알림 감지 - 데이터 새로고침 트리거');
        // 서버 알림 데이터 업데이트 (기존 로직 활용)
        if (_currentUserId != null) {
          print('🔄 [CANCEL_DEBUG] 서버 알림 데이터 업데이트 시도');
          try {
            final response = await ApiService.checkAlerts(_currentUserId!);
            final alerts = response['alerts'] as List<dynamic>? ?? [];
            _notificationNotifier
                ?.updateServerAlerts(alerts.cast<Map<String, dynamic>>());
            print('✅ [CANCEL_DEBUG] 서버 알림 데이터 업데이트 완료');
          } catch (e) {
            print('⚠️ [CANCEL_DEBUG] 서버 알림 데이터 업데이트 실패: $e');
          }
        }
      }

      // UI 표시 완료 후 ACK
      print('🔧 [AMQP] 메시지 ACK 처리');
      try {
        originalMessage.ack();
        print('✅ [AMQP] 전자결재 알림 메시지 UI 표시 완료, ACK 처리');
      } catch (ackError) {
        print('⚠️ [AMQP] 메시지 ACK 실패 (채널이 닫혔을 수 있음): $ackError');
      }

      print('📋 [AMQP] ===== 전자결재 알림 메시지 처리 완료 =====');
    } catch (e) {
      print('⚠️ [AMQP] 전자결재 알림 메시지 처리 중 오류: $e');
      print('⚠️ [AMQP] 오류 상세 정보:');
      print('   - 에러 타입: ${e.runtimeType}');
      print('   - 에러 메시지: $e');
      // 🚨 무한루프 방지: reject 후 Consumer 즉시 정지 및 딜레이 적용
      print('🚨 [AMQP] 전자결재 알림 메시지 처리 실패 - reject 후 Consumer 정지');
      try {
        originalMessage.reject(true); // 메시지를 큐로 재전송
      } catch (rejectError) {
        print('⚠️ [AMQP] 메시지 reject 실패 (채널이 닫혔을 수 있음): $rejectError');
      }
      _handleMessageRejectAndStop(
          'EAPPROVAL_UI_ERROR'); // Consumer 정지 후 딜레이 재연결
    }
  }

  /// 휴가 초안 메시지를 처리합니다.
  void _handleLeaveDraftMessage(
      Map<String, dynamic> data, amqp.AmqpMessage originalMessage) async {
    print('📋 [AMQP] ===== 휴가 초안 메시지 처리 시작 =====');
    print('📋 [AMQP] 원본 AMQP 메시지 데이터: $data');

    try {
      print('📋 [AMQP] 휴가 초안 메시지 처리 시작: $data');

      // 메시지 데이터를 VacationRequestData로 변환
      final leaveType = data['leave_type'] as String? ?? '';
      final startDateStr = data['start_date'] as String? ?? '';
      final endDateStr = data['end_date'] as String? ?? '';
      final approverName = data['approver_name'] as String? ?? '';
      final approverId = data['approver_id'] as String? ?? '';
      final reason = data['reason'] as String? ?? '';
      final halfDaySlot = data['half_day_slot'] as String?;
      final isNextYear = data['is_next_year'] as int? ?? 0;

      // cc_list 파싱 (서버 데이터 형식: [{name: "name", userId: "김영우"}, ...])
      List<CcPersonData> ccList = [];
      if (data['cc_list'] != null) {
        final ccListData = data['cc_list'] as List?;
        if (ccListData != null) {
          for (var item in ccListData) {
            if (item is Map) {
              // 서버에서 userId 필드에 실제 이름이 들어옴
              final userIdField = item['userId'] as String? ?? '';
              final nameField = item['name'] as String? ?? '';

              // name 필드에 "name"이라는 값이 들어오면 userId 값을 name으로 사용
              final actualName = (nameField == 'name' && userIdField.isNotEmpty)
                  ? userIdField
                  : nameField;

              // userId는 이름 + @aspnc.com 형식으로 생성
              // 만약 이미 @이 포함되어 있으면 그대로 사용
              final actualUserId = actualName.contains('@')
                  ? actualName
                  : '$actualName@aspnc.com';

              ccList.add(CcPersonData(name: actualName, userId: actualUserId));
              print(
                  '📋 [AMQP] cc_list 파싱: name="$actualName", userId="$actualUserId"');
            }
          }
        }
      }

      // 날짜 파싱
      DateTime? startDate;
      DateTime? endDate;
      try {
        if (startDateStr.isNotEmpty && !startDateStr.contains('0001-01-01')) {
          final parsedStartDate = DateTime.parse(startDateStr);
          // 잘못된 날짜 체크
          if (parsedStartDate.year >= 2000) {
            startDate = parsedStartDate;
          } else {
            print('⚠️ [AMQP] 잘못된 시작일: $startDateStr');
          }
        }
        if (endDateStr.isNotEmpty && !endDateStr.contains('0001-01-01')) {
          final parsedEndDate = DateTime.parse(endDateStr);
          // 잘못된 날짜 체크
          if (parsedEndDate.year >= 2000) {
            endDate = parsedEndDate;
          } else {
            print('⚠️ [AMQP] 잘못된 종료일: $endDateStr');
          }
        }
      } catch (e) {
        print('⚠️ [AMQP] 날짜 파싱 실패: $e');
      }

      print('📋 [AMQP] 메시지 파싱 결과:');
      print('   - leave_type: $leaveType (빈값: ${leaveType.isEmpty})');
      print(
          '   - start_date: "$startDateStr" → $startDate (null여부: ${startDate == null})');
      print(
          '   - end_date: "$endDateStr" → $endDate (null여부: ${endDate == null})');
      print(
          '   - approver_name: "$approverName" (빈값: ${approverName.isEmpty})');
      print('   - approver_id: "$approverId" (빈값: ${approverId.isEmpty})');
      print('   - reason: "$reason" (빈값: ${reason.isEmpty})');
      print('   - half_day_slot: "$halfDaySlot"');
      print('   - is_next_year: $isNextYear');
      print('   - cc_list: ${ccList.length}명');
      if (ccList.isNotEmpty) {
        for (var i = 0; i < ccList.length; i++) {
          print(
              '      cc[$i]: name="${ccList[i].name}", userId="${ccList[i].userId}"');
        }
      }

      // leave_status 파싱 (서버에서 보내주는 데이터)
      List<LeaveStatusData>? leaveStatus;
      if (data['leave_status'] != null && data['leave_status'] is List) {
        final leaveStatusList = data['leave_status'] as List;
        leaveStatus = leaveStatusList
            .map((item) =>
                LeaveStatusData.fromJson(item as Map<String, dynamic>))
            .toList();
        print('📋 [AMQP] leave_status 파싱 완료: ${leaveStatus.length}개');
        for (var i = 0; i < leaveStatus.length; i++) {
          print(
              '      leaveStatus[$i]: ${leaveStatus[i].leaveType} - ${leaveStatus[i].remainDays}/${leaveStatus[i].totalDays}일');
        }
      } else {
        print('📋 [AMQP] leave_status가 없거나 null입니다');
      }

      // VacationRequestData 생성
      final vacationData = VacationRequestData(
        userId: data['user_id'] as String? ?? _currentUserId ?? '',
        leaveType: leaveType.isNotEmpty ? leaveType : null,
        startDate: startDate,
        endDate: endDate,
        reason: reason.isNotEmpty ? reason : null,
        halfDaySlot: halfDaySlot,
        ccList: ccList.isNotEmpty ? ccList : null,
        approvalLine: approverName.isNotEmpty
            ? [
                ApprovalLineData(
                  approverName: approverName,
                  approverId: approverId,
                  approvalSeq: 1,
                )
              ]
            : null,
        leaveStatus: leaveStatus, // ✅ 서버에서 받은 휴가 현황 데이터
      );

      print('✅ [AMQP] VacationRequestData 생성 완료:');
      print('   - userId: ${vacationData.userId}');
      print('   - leaveType: ${vacationData.leaveType}');
      print('   - startDate: ${vacationData.startDate}');
      print('   - endDate: ${vacationData.endDate}');
      print('   - reason: ${vacationData.reason}');
      print('   - halfDaySlot: ${vacationData.halfDaySlot}');
      print('   - ccList: ${vacationData.ccList?.length ?? 0}명');
      print('   - approvalLine: ${vacationData.approvalLine?.length ?? 0}명');
      print('   - leaveStatus: ${vacationData.leaveStatus?.length ?? 0}개');
      if (vacationData.approvalLine != null &&
          vacationData.approvalLine!.isNotEmpty) {
        print(
            '      승인자: ${vacationData.approvalLine!.first.approverName} (${vacationData.approvalLine!.first.approverId})');
      }

      // 휴가 초안 모달 표시
      print('📋 [AMQP] 휴가 초안 모달 표시');
      _showLeaveDraftModal(vacationData);
      print('✅ [AMQP] 휴가 초안 모달 표시 완료');

      // UI 표시 완료 후 ACK
      print('🔧 [AMQP] 메시지 ACK 처리');
      try {
        originalMessage.ack();
        print('✅ [AMQP] 휴가 초안 메시지 UI 표시 완료, ACK 처리');
      } catch (ackError) {
        print('⚠️ [AMQP] 메시지 ACK 실패 (채널이 닫혔을 수 있음): $ackError');
      }

      print('📋 [AMQP] ===== 휴가 초안 메시지 처리 완료 =====');
    } catch (e) {
      print('⚠️ [AMQP] 휴가 초안 메시지 처리 중 오류: $e');
      print('⚠️ [AMQP] 오류 상세 정보:');
      print('   - 에러 타입: ${e.runtimeType}');
      print('   - 에러 메시지: $e');
      // 🚨 무한루프 방지: reject 후 Consumer 즉시 정지 및 딜레이 적용
      print('🚨 [AMQP] 휴가 초안 메시지 처리 실패 - reject 후 Consumer 정지');
      try {
        originalMessage.reject(true); // 메시지를 큐로 재전송
      } catch (rejectError) {
        print('⚠️ [AMQP] 메시지 reject 실패 (채널이 닫혔을 수 있음): $rejectError');
      }
      _handleMessageRejectAndStop(
          'LEAVE_DRAFT_UI_ERROR'); // Consumer 정지 후 딜레이 재연결
    }
  }

  // --- UI Helper Methods ---

  void _showNewGiftArrivalPopup(Map<String, dynamic> giftData) {
    print('🔧 [AMQP] _showNewGiftArrivalPopup() 시작');

    // 🎁 로그인 후 너무 빠른 팝업 생성 방지를 위해 2초 지연 추가
    Future.delayed(const Duration(seconds: 2), () {
      _waitForStableUIContext().then((context) {
        if (context != null && context.mounted) {
          print('🎁 [AMQP] 선물 도착 팝업 다이얼로그 표시 (2초 지연 후)');
          showDialog(
            context: context,
            builder: (dialogContext) => GiftArrivalPopup.fromServerData(
              giftData: giftData,
              onConfirm: _navigateToGiftBox,
            ),
          );
          print('✅ [AMQP] 선물 도착 팝업 다이얼로그 표시 완료');
        } else {
          print('⚠️ [AMQP] UI 컨텍스트가 없어 팝업을 표시할 수 없습니다.');
        }
      });
    });
  }

  void _addAnnouncementChatMessage(
    String title,
    String message, {
    String renderType = 'text',
    int? contestId,
    String? contestType,
  }) {
    print('🔧 [AMQP] _addAnnouncementChatMessage() 시작');
    print('🔧 [AMQP] renderType: $renderType, contestId: $contestId');
    try {
      _chatNotifier?.addAnnouncementMessage(
        title,
        message,
        renderType: renderType,
        contestId: contestId,
        contestType: contestType,
      );
      print('✅ [AMQP] 채팅창에 공지사항 메시지 추가 완료');
    } catch (e) {
      print('❌ [AMQP] 채팅창에 공지사항 메시지 추가 실패: $e');
    }
  }

  void _showBirthdayPopup(String message, {String? realTimeId}) {
    print('🔧 [AMQP] _showBirthdayPopup() 시작');
    print('🔧 [AMQP] realTimeId: $realTimeId');

    // 🎂 로그인 후 너무 빠른 팝업 생성 방지를 위해 2초 지연 추가
    Future.delayed(const Duration(seconds: 2), () {
      _waitForStableUIContext().then((context) {
        if (context != null && context.mounted) {
          print('🎂 [AMQP] 생일 축하 팝업 다이얼로그 표시 (2초 지연 후)');
          showDialog(
            context: context,
            barrierDismissible: false, // 외부 클릭으로 닫기 방지
            builder: (dialogContext) =>
                BirthdayPopup(message: message, realTimeId: realTimeId),
          );
          print('✅ [AMQP] 생일 축하 팝업 다이얼로그 표시 완료');
        } else {
          print('⚠️ [AMQP] UI 컨텍스트가 없어 팝업을 표시할 수 없습니다.');
        }
      });
    });
  }

  void _showEventPopup(String title, String message, {String? realTimeId}) {
    print('🔧 [AMQP] _showEventPopup() 시작');
    print(
        '🔧 [AMQP] title: $title, message: $message, realTimeId: $realTimeId');

    // 🎁 로그인 후 너무 빠른 팝업 생성 방지를 위해 2초 지연 추가
    Future.delayed(const Duration(seconds: 2), () {
      _waitForStableUIContext().then((context) {
        if (context != null && context.mounted) {
          print('🎁 [AMQP] 이벤트 팝업 다이얼로그 표시 (2초 지연 후)');
          showDialog(
            context: context,
            barrierDismissible: false, // 외부 클릭으로 닫기 방지
            builder: (dialogContext) => EventPopup(
                title: title, message: message, realTimeId: realTimeId),
          );
          print('✅ [AMQP] 이벤트 팝업 다이얼로그 표시 완료');
        } else {
          print('⚠️ [AMQP] UI 컨텍스트가 없어 팝업을 표시할 수 없습니다.');
        }
      });
    });
  }

  void _showEapprovalAlert(String title, String status, String? comment,
      {String? approvalType}) {
    print('🔧 [AMQP] _showEapprovalAlert() 시작');
    print(
        '🔧 [AMQP] title: $title, status: $status, comment: $comment, approvalType: $approvalType');

    // 📋 로그인 직후 UI 안정화 대기 후 컴팩트 알림 표시 (오른쪽 상단)
    Future.delayed(const Duration(seconds: 2), () {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        showGeneralDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.transparent, // 투명한 배리어
          pageBuilder: (context, animation, secondaryAnimation) {
            return SafeArea(
              child: Align(
                alignment: Alignment.topRight, // 오른쪽 상단에 정렬
                child: Material(
                  type: MaterialType.transparency,
                  child: ApprovalAlertPopup(
                    title: title,
                    status: status,
                    comment: comment,
                    approvalType: approvalType,
                    onDismiss: () {
                      // 알림이 닫힐 때 처리할 내용이 있다면 여기에 추가
                    },
                  ),
                ),
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        );
      } else {
        print('⚠️ [AMQP] UI 컨텍스트 없음 - 알림 표시 실패');
      }
    });
  }

  void _addBirthdayChatMessage(
      String title, String message, String? realTimeId) {
    print('🎂 [AMQP] ===== 채팅 메시지 생성 시작 =====');
    print('🎂 [AMQP] 입력 파라미터:');
    print('   - title: $title');
    print('   - message: $message');
    print('   - realTimeId: $realTimeId');

    Future.delayed(const Duration(seconds: 2), () {
      try {
        final chatMessage = {
          'id': realTimeId, // ✅ 서버에서 받은 realTimeId를 id 필드에 저장
          'content': message,
          'type': 'birthday',
          'timestamp': DateTime.now().toIso8601String(),
          'isUser': false,
          'title': title,
          'role': 1, // AI 메시지
          'isBirthdayMessage': true, // 생일 메시지 식별자
          'hasGiftButton': true, // 선물 고르러가기 버튼 표시
          'archive_id': _chatNotifier?.state.currentArchiveId ?? '',
          'user_id': _currentUserId ?? '',
          'chat_time': DateTime.now().toString(),
        };

        print('🎂 [AMQP] ===== 생성된 채팅 메시지 =====');
        print('🎂 [AMQP] chatMessage 전체: $chatMessage');
        print('🎂 [AMQP] chatMessage["id"]: ${chatMessage['id']}');
        print(
            '🎂 [AMQP] chatMessage["id"] 타입: ${chatMessage['id'].runtimeType}');

        _chatNotifier?.addBirthdayMessage(chatMessage);
        print('✅ [AMQP] 채팅창에 생일 메시지 추가 완료 (2초 지연 후)');
        print('🔍 [AMQP] realTimeId 설정 완료: $realTimeId');
        print('🎂 [AMQP] ===== 채팅 메시지 생성 완료 =====');
      } catch (e) {
        print('❌ [AMQP] 채팅창에 생일 메시지 추가 실패: $e');
        print('❌ [AMQP] 오류 상세 정보:');
        print('   - 에러 타입: ${e.runtimeType}');
        print('   - 에러 메시지: $e');
      }
    });
  }

  void _navigateToGiftBox() {
    print('�� [AMQP] _navigateToGiftBox() 시작');
    _notificationNotifier?.clearNewGiftIndicator();
    _onGiftConfirm?.call();
    print('✅ [AMQP] 선물함으로 이동 완료');
  }

  void _showLeaveDraftModal(VacationRequestData vacationData) {
    print('🔧 [AMQP] _showLeaveDraftModal() 시작');

    // 📋 데이터를 먼저 업데이트하고, 그 다음 모달 표시
    print('📋 [AMQP] Provider에 데이터 전달 시작');
    print('📋 [AMQP] 전달할 데이터 JSON: ${vacationData.toJson()}');
    try {
      final currentContext = navigatorKey.currentContext;
      if (currentContext != null && currentContext.mounted) {
        // Provider를 통해 데이터 업데이트 (모달 표시 전에 먼저 실행)
        final container =
            ProviderScope.containerOf(currentContext, listen: false);
        container
            .read(vacationDataProvider.notifier)
            .updateFromJson(vacationData.toJson());
        print('✅ [AMQP] 휴가 초안 데이터 업데이트 완료');
      } else {
        print('⚠️ [AMQP] 컨텍스트가 마운트되지 않아 데이터 업데이트 실패');
      }
    } catch (e) {
      print('⚠️ [AMQP] 휴가 초안 데이터 업데이트 실패: $e');
      print('   - 에러: $e');
      print('   - 에러 스택: ${StackTrace.current}');
    }

    // 📋 모달 표시를 1.5초 지연 (데이터 업데이트 후 충분한 시간 확보)
    Future.delayed(const Duration(milliseconds: 1500), () {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        print('📋 [AMQP] 휴가 초안 모달 표시 (1.5초 지연 후)');

        // ProviderScope를 통해 모달 표시 (데이터는 이미 업데이트됨)
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (dialogContext) => Material(
            type: MaterialType.transparency,
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.6,
                height: MediaQuery.of(context).size.height * 0.9,
                constraints: const BoxConstraints(
                  maxWidth: 800,
                  minWidth: 600,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1A1D1F)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ProviderScope(
                  child: LeaveDraftModal(
                    onClose: () {
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        print('✅ [AMQP] 휴가 초안 모달 표시 완료');
      } else {
        print('⚠️ [AMQP] UI 컨텍스트가 없어 모달을 표시할 수 없습니다.');
        // 컨텍스트를 다시 시도
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 500), () {
            final retryContext = navigatorKey.currentContext;
            if (retryContext != null && retryContext.mounted) {
              print('📋 [AMQP] 휴가 초안 모달 재시도 표시');
              showDialog(
                context: retryContext,
                barrierDismissible: true,
                builder: (dialogContext) => Material(
                  type: MaterialType.transparency,
                  child: Center(
                    child: Container(
                      width: MediaQuery.of(retryContext).size.width * 0.6,
                      height: MediaQuery.of(retryContext).size.height * 0.9,
                      constraints: const BoxConstraints(
                        maxWidth: 800,
                        minWidth: 600,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(dialogContext).brightness ==
                                Brightness.dark
                            ? const Color(0xFF1A1D1F)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ProviderScope(
                        child: LeaveDraftModal(
                          onClose: () {
                            Navigator.of(dialogContext).pop();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
              print('✅ [AMQP] 휴가 초안 모달 재시도 완료');
            } else {
              print('⚠️ [AMQP] 재시도 후에도 컨텍스트가 없습니다.');
            }
          });
        });
      }
    });
  }

  Future<BuildContext?> _waitForStableUIContext() async {
    print('🔧 [AMQP] _waitForStableUIContext() 시작');
    final completer = Completer<BuildContext?>();
    if (navigatorKey.currentContext == null) {
      print('⚠️ [AMQP] 현재 UI 컨텍스트가 없습니다.');
      completer.complete(null);
      return completer.future;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Timer(const Duration(milliseconds: 500), () {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          print('✅ [AMQP] 안정적인 UI 컨텍스트 획득');
          completer.complete(context);
        } else {
          print('⚠️ [AMQP] UI 컨텍스트가 마운트되지 않았습니다.');
          completer.complete(null);
        }
      });
    });
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        print('⚠️ [AMQP] UI Context 대기 시간 초과');
        return null;
      },
    );
  }
}

final amqpService = AmqpService();
