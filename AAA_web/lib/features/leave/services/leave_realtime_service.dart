import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dart_amqp/dart_amqp.dart' as amqp;
import 'package:ASPN_AI_AGENT/core/config/messageq_config.dart';
import 'package:ASPN_AI_AGENT/provider/leave_management_provider.dart';

/// 휴가 실시간 알림 서비스
/// - leave.approval.user_id: 결재 요청 (승인자만)
/// - leave.alert.user_id: 결재 결과 알림 (모든 사용자)
/// - leave.cc.user_id: 참조 알림 (모든 사용자)
class LeaveApprovalRealtimeService {
  static LeaveApprovalRealtimeService? _instance;
  static LeaveApprovalRealtimeService get instance {
    _instance ??= LeaveApprovalRealtimeService._();
    return _instance!;
  }

  /// eapproval.cc.user_id 큐 구독 (전자결재 CC 알림)
  Future<void> _subscribeToEApprovalCCQueue() async {
    if (_channel == null) {
      print('❌ [EAPPROVAL.CC 큐] AMQP 채널이 없음');
      _isConnected = false;
      return;
    }

    try {
      final queueName = 'eapproval.cc.$_currentUserId';
      print('🔄 [EAPPROVAL.CC 큐] 큐 생성 시작: $queueName');
      final queue = await _channel!.queue(queueName, durable: true);
      print('✅ [EAPPROVAL.CC 큐] 큐 생성 완료: $queueName');

      final consumerTag =
          'eapproval_cc_${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}';
      print('🔄 [EAPPROVAL.CC 큐] Consumer 생성 시작: $consumerTag');

      _eapprovalCcConsumer = await queue.consume(
        consumerTag: consumerTag,
        noAck: false,
      );
      print('✅ [EAPPROVAL.CC 큐] Consumer 생성 완료: $consumerTag');

      print('🔄 [EAPPROVAL.CC 큐] Consumer 리스너 등록 중...');
      _eapprovalCcConsumer!.listen(
        (message) {
          print('📨 [EAPPROVAL.CC 큐] 새 메시지 수신됨!');
          _handleEApprovalCCMessage(message);
        },
        onError: (error) {
          print('❌ [EAPPROVAL.CC 큐] Consumer 에러: $error. 재연결을 시도합니다.');
          _isConnected = false;
          _eapprovalCcConsumer = null;
        },
        onDone: () {
          print('ℹ️ [EAPPROVAL.CC 큐] Consumer 종료됨 (onDone). 재연결을 시도합니다.');
          _isConnected = false;
          _eapprovalCcConsumer = null;
        },
      );

      print('📩✅ [EAPPROVAL.CC 큐] 전자결재 CC 알림 큐 구독 완료: $queueName (하트비트: 30초)');
      print(
          '🔍 [EAPPROVAL.CC 큐] Consumer 상태: ${_eapprovalCcConsumer != null ? "활성" : "비활성"}');
    } catch (e) {
      print('❌ [EAPPROVAL.CC 큐] 전자결재 CC 알림 큐 구독 실패: $e');
      _isConnected = false;
      _eapprovalCcConsumer = null;
      rethrow;
    }
  }

  LeaveApprovalRealtimeService._();

  // AMQP 리소스
  amqp.Client? _client;
  amqp.Channel? _channel;
  amqp.Consumer? _approvalConsumer; // 결재 요청 컴슈머
  amqp.Consumer? _alertConsumer; // 결재 결과 알림 컴슈멨
  amqp.Consumer? _ccConsumer; // 참조 알림 컴슈멨
  amqp.Consumer? _eapprovalConsumer; // 전자결재 알림 컴슈머 (모든 사용자)
  amqp.Consumer? _eapprovalCcConsumer; // 전자결재 CC 알림 컴슈머 (모든 사용자)

  // --- 상태 관리 ---
  bool _isConnected = false;
  String? _currentUserId;
  ProviderContainer? _container;
  bool _isApprover = false;

  // --- 재연결 및 헬스체크 상태 ---
  Timer? _healthCheckTimer;
  bool _isReconnecting = false;

  // 스트림 컨트롤러
  final StreamController<LeaveApprovalRequest> _approvalRequestController =
      StreamController<LeaveApprovalRequest>.broadcast();
  final StreamController<LeaveAlertMessage> _alertMessageController =
      StreamController<LeaveAlertMessage>.broadcast();
  final StreamController<LeaveCCMessage> _ccMessageController =
      StreamController<LeaveCCMessage>.broadcast();
  final StreamController<LeaveEApprovalMessage> _eapprovalMessageController =
      StreamController<LeaveEApprovalMessage>.broadcast();

  /// 결재 요청 스트림 (채팅화면에서 구독)
  Stream<LeaveApprovalRequest> get approvalRequestStream =>
      _approvalRequestController.stream;

  /// 결재 결과 알림 스트림
  Stream<LeaveAlertMessage> get alertMessageStream =>
      _alertMessageController.stream;

  /// 참조 알림 스트림
  Stream<LeaveCCMessage> get ccMessageStream => _ccMessageController.stream;

  /// 전자결재 알림 스트림
  Stream<LeaveEApprovalMessage> get eapprovalMessageStream =>
      _eapprovalMessageController.stream;

  bool get isConnected => _isConnected;
  String? get currentUserId => _currentUserId;

  /// 모든 사용자에게 3개 큐 생성 (alert, cc는 모두, approval은 승인자만)
  Future<void> startListening(String userId, ProviderContainer container,
      {bool isApprover = false}) async {
    _currentUserId = userId;
    _container = container;
    _isApprover = isApprover;

    try {
      await _connectToAmqp();

      // 모든 사용자에게 alert, cc, eapproval, eapproval.cc 큐 생성
      await _subscribeToAlertQueue();
      await _subscribeToCCQueue();
      await _subscribeToEApprovalQueue();
      await _subscribeToEApprovalCCQueue();

      // 승인자에게만 approval 큐 생성
      if (isApprover) {
        await _subscribeToApprovalQueue();
        print('✅ 결재 요청 큐 생성 완료: 승인자 모드');
      } else {
        print('🚫 결재 요청 큐 생성 건너뛴: 승인자가 아님');
      }

      _startHealthCheck(); // 헬스체크 시작
    } catch (e) {
      print('❌ 휴가 실시간 서비스 시작 실패: $e');
      // 실패 시 재연결 로직이 처리하도록 상태 설정
      _isConnected = false;
      _approvalConsumer = null;
      _alertConsumer = null;
      _ccConsumer = null;
    }
  }

  /// 연결 해제
  Future<void> stopListening() async {
    print('🔌 결재 요청 서비스 연결 해제 중...');
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    try {
      await _approvalConsumer?.cancel();
      await _alertConsumer?.cancel();
      await _ccConsumer?.cancel();
      await _eapprovalConsumer?.cancel();
      await _eapprovalCcConsumer?.cancel();
      await _channel?.close();
      await _client?.close();
    } catch (e) {
      print('❌ 휴가 실시간 서비스 연결 해제 오류: $e');
    }

    _approvalConsumer = null;
    _alertConsumer = null;
    _ccConsumer = null;
    _eapprovalConsumer = null;
    _eapprovalCcConsumer = null;
    _channel = null;
    _client = null;
    _isConnected = false;
    // 재연결을 위해 사용자 정보는 유지
    // _currentUserId = null;
    // _container = null;

    print('🔌 휴가 실시간 서비스 연결 해제 완료');
  }

  /// AMQP 서버 연결
  Future<void> _connectToAmqp() async {
    try {
      _client = amqp.Client(
        settings: amqp.ConnectionSettings(
          host: MessageQConfig.rabbitmqHost,
          port: MessageQConfig.rabbitmqPort,
          authProvider: amqp.PlainAuthenticator(
            MessageQConfig.rabbitmqUsername,
            MessageQConfig.rabbitmqPassword,
          ),
          tuningSettings: amqp.TuningSettings(
            heartbeatPeriod: Duration(seconds: 30),
          ),
        ),
      );

      await _client!.connect();
      _channel = await _client!.channel();
      _isConnected = true;

      print('✅ 휴가 실시간 서비스 AMQP 연결 성공');
    } catch (e) {
      print('❌ 휴가 실시간 서비스 AMQP 연결 실패: $e');
      _isConnected = false;
      rethrow;
    }
  }

  /// leave.approval.user_id 큐 구독
  Future<void> _subscribeToApprovalQueue() async {
    if (_channel == null) {
      print('❌ AMQP 채널이 없음');
      _isConnected = false;
      return;
    }

    try {
      final queueName = 'leave.approval.$_currentUserId';
      final queue = await _channel!.queue(queueName, durable: true);

      // 하트비트 모니터링을 위한 consumer 설정
      _approvalConsumer = await queue.consume(
        consumerTag:
            'approval_${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}',
        noAck: false, // ACK 필수로 설정하여 메시지 안정성 보장
      );
      _approvalConsumer!.listen(
        (message) {
          _handleApprovalMessage(message);
        },
        onError: (error) {
          print('❌ 결재 요청 Consumer 에러: $error. 재연결을 시도합니다.');
          _isConnected = false;
          _approvalConsumer = null;
        },
        onDone: () {
          print('ℹ️ 결재 요청 Consumer 종료됨 (onDone). 재연결을 시도합니다.');
          _isConnected = false;
          _approvalConsumer = null;
        },
      );

      print('📩 결재 요청 큐 구독 시작: $queueName (하트비트: 30초)');
    } catch (e) {
      print('❌ 결재 요청 큐 구독 실패: $e');
      _isConnected = false;
      _approvalConsumer = null;
      rethrow;
    }
  }

  /// leave.alert.user_id 큐 구독 (결재 결과 알림)
  Future<void> _subscribeToAlertQueue() async {
    if (_channel == null) {
      print('❌ AMQP 채널이 없음');
      _isConnected = false;
      return;
    }

    try {
      final queueName = 'leave.alert.$_currentUserId';
      final queue = await _channel!.queue(queueName, durable: true);

      // 하트비트 모니터링을 위한 consumer 설정
      _alertConsumer = await queue.consume(
        consumerTag:
            'alert_${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}',
        noAck: false, // ACK 필수로 설정하여 메시지 안정성 보장
      );
      _alertConsumer!.listen(
        (message) {
          _handleAlertMessage(message);
        },
        onError: (error) {
          print('❌ 결재 결과 알림 Consumer 에러: $error. 재연결을 시도합니다.');
          _isConnected = false;
          _alertConsumer = null;
        },
        onDone: () {
          print('ℹ️ 결재 결과 알림 Consumer 종료됨 (onDone). 재연결을 시도합니다.');
          _isConnected = false;
          _alertConsumer = null;
        },
      );

      print('📩 결재 결과 알림 큐 구독 시작: $queueName (하트비트: 30초)');
    } catch (e) {
      print('❌ 결재 결과 알림 큐 구독 실패: $e');
      _isConnected = false;
      _alertConsumer = null;
      rethrow;
    }
  }

  /// leave.cc.user_id 큐 구독 (참조 알림)
  Future<void> _subscribeToCCQueue() async {
    if (_channel == null) {
      print('❌ [CC 큐] AMQP 채널이 없음');
      _isConnected = false;
      return;
    }

    try {
      final queueName = 'leave.cc.$_currentUserId';
      print('🔄 [CC 큐] 큐 생성 시작: $queueName');
      final queue = await _channel!.queue(queueName, durable: true);
      print('✅ [CC 큐] 큐 생성 완료: $queueName');

      // 하트비트 모니터링을 위한 consumer 설정
      final consumerTag =
          'cc_${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}';
      print('🔄 [CC 큐] Consumer 생성 시작: $consumerTag');

      _ccConsumer = await queue.consume(
        consumerTag: consumerTag,
        noAck: false, // ACK 필수로 설정하여 메시지 안정성 보장
      );
      print('✅ [CC 큐] Consumer 생성 완료: $consumerTag');

      print('🔄 [CC 큐] Consumer 리스너 등록 중...');
      _ccConsumer!.listen(
        (message) {
          print('📨 [CC 큐] 새 메시지 수신됨!');
          _handleCCMessage(message);
        },
        onError: (error) {
          print('❌ [CC 큐] Consumer 에러: $error. 재연결을 시도합니다.');
          _isConnected = false;
          _ccConsumer = null;
        },
        onDone: () {
          print('ℹ️ [CC 큐] Consumer 종료됨 (onDone). 재연결을 시도합니다.');
          _isConnected = false;
          _ccConsumer = null;
        },
      );

      print('📩✅ [CC 큐] 참조 알림 큐 구독 완료: $queueName (하트비트: 30초)');
      print('🔍 [CC 큐] Consumer 상태: ${_ccConsumer != null ? "활성" : "비활성"}');
    } catch (e) {
      print('❌ [CC 큐] 참조 알림 큐 구독 실패: $e');
      print('❌ [CC 큐] 에러 상세: ${e.toString()}');
      print('❌ [CC 큐] 스택트레이스: ${StackTrace.current}');
      _isConnected = false;
      _ccConsumer = null;
      rethrow;
    }
  }

  /// eapproval.user_id 큐 구독 (전자결재 일반 알림 - 모든 사용자)
  Future<void> _subscribeToEApprovalQueue() async {
    if (_channel == null) {
      print('❌ [EAPPROVAL 큐] AMQP 채널이 없음');
      _isConnected = false;
      return;
    }

    try {
      final queueName = 'eapproval.$_currentUserId';
      print('🔄 [EAPPROVAL 큐] 큐 생성 시작: $queueName');
      final queue = await _channel!.queue(queueName, durable: true);
      print('✅ [EAPPROVAL 큐] 큐 생성 완료: $queueName');

      // 하트비트 모니터링을 위한 consumer 설정
      final consumerTag =
          'eapproval_${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}';
      print('🔄 [EAPPROVAL 큐] Consumer 생성 시작: $consumerTag');

      _eapprovalConsumer = await queue.consume(
        consumerTag: consumerTag,
        noAck: false,
      );
      print('✅ [EAPPROVAL 큐] Consumer 생성 완료: $consumerTag');

      print('🔄 [EAPPROVAL 큐] Consumer 리스너 등록 중...');
      _eapprovalConsumer!.listen(
        (message) {
          print('📨 [EAPPROVAL 큐] 새 메시지 수신됨!');
          _handleEApprovalMessage(message);
        },
        onError: (error) {
          print('❌ [EAPPROVAL 큐] Consumer 에러: $error. 재연결을 시도합니다.');
          _isConnected = false;
          _eapprovalConsumer = null;
        },
        onDone: () {
          print('ℹ️ [EAPPROVAL 큐] Consumer 종료됨 (onDone). 재연결을 시도합니다.');
          _isConnected = false;
          _eapprovalConsumer = null;
        },
      );

      print('📩✅ [EAPPROVAL 큐] 전자결재 알림 큐 구독 완료: $queueName (하트비트: 30초)');
      print(
          '🔍 [EAPPROVAL 큐] Consumer 상태: ${_eapprovalConsumer != null ? "활성" : "비활성"}');
    } catch (e) {
      print('❌ [EAPPROVAL 큐] 전자결재 알림 큐 구독 실패: $e');
      _isConnected = false;
      _eapprovalConsumer = null;
      rethrow;
    }
  }

  /// 결재 요청 메시지 처리
  void _handleApprovalMessage(amqp.AmqpMessage message) {
    try {
      final messageBody = utf8.decode(message.payload!);
      final data = jsonDecode(messageBody) as Map<String, dynamic>;
      print('📨 결재 요청 메시지 수신 (원본): $data');
      print('📨 데이터 키 목록: ${data.keys.toList()}');
      print('📨 ID 관련 필드 체크:');
      print('   - id: ${data['id']}');
      print('   - requestId: ${data['requestId']}');
      print('   - request_id: ${data['request_id']}');
      print('   - leave_id: ${data['leave_id']}');
      print('   - leave_request_id: ${data['leave_request_id']}');
      print('🔍 [CANCEL_DEBUG] ========== AMQP 메시지 전체 확인 ==========');
      print('🔍 [CANCEL_DEBUG] is_cancel 값: ${data['is_cancel']}');
      print('🔍 [CANCEL_DEBUG] ============================================');

      final approvalRequest = LeaveApprovalRequest.fromJson(data);
      _approvalRequestController.add(approvalRequest);
      _showApprovalNotification(approvalRequest);

      // 🔄 AMQP 메시지에 is_cancel이 있으면 LeaveManagementProvider 업데이트
      if (data.containsKey('is_cancel') && data.containsKey('id')) {
        final leaveId = data['id'];
        final isCancel = data['is_cancel'];

        print('🔄 [AMQP_UPDATE] is_cancel 업데이트 시도');
        print('🔄 [AMQP_UPDATE]   - leaveId: $leaveId');
        print('🔄 [AMQP_UPDATE]   - isCancel: $isCancel');

        if (_container != null) {
          try {
            final leaveManagementNotifier =
                _container!.read(leaveManagementProvider.notifier);
            final leaveIdInt = int.tryParse(leaveId.toString()) ??
                (leaveId is int ? leaveId : 0);
            final isCancelInt =
                isCancel is int ? isCancel : (isCancel == 1 ? 1 : 0);

            if (leaveIdInt > 0) {
              leaveManagementNotifier.updateCancelStatus(
                  leaveIdInt, isCancelInt);
              print('✅ [AMQP_UPDATE] LeaveManagementProvider 업데이트 완료');
            } else {
              print('⚠️ [AMQP_UPDATE] 유효하지 않은 leaveId: $leaveId');
            }
          } catch (e) {
            print('❌ [AMQP_UPDATE] LeaveManagementProvider 업데이트 실패: $e');
          }
        } else {
          print('⚠️ [AMQP_UPDATE] ProviderContainer가 null입니다.');
        }
      }

      message.ack();
    } catch (e) {
      print('❌ 결재 요청 메시지 처리 오류: $e');
      message.reject(true);
    }
  }

  /// 결재 결과 알림 메시지 처리
  void _handleAlertMessage(amqp.AmqpMessage message) {
    try {
      // 원본 바이트 데이터 확인
      print('📨 [LEAVE.ALERT] 원본 바이트 데이터 길이: ${message.payload?.length}');

      final messageBody = utf8.decode(message.payload!);
      print('📄 [LEAVE.ALERT] UTF-8 디코딩된 메시지:');
      print('--- 메시지 시작 ---');
      print(messageBody);
      print('--- 메시지 끝 ---');
      print('📏 메시지 길이: ${messageBody.length}');

      // JSON 파싱 시도
      try {
        // 서버에서 보내는 JSON에 문제가 있는 경우 수정
        String fixedMessageBody = messageBody;

        // 1. ID 필드가 있으면 제거 (더 이상 사용하지 않음)
        fixedMessageBody =
            fixedMessageBody.replaceAll(RegExp(r'"id":\s*\d+,?\s*\n?\s*'), '');

        // 2. 연속된 쉼표 제거
        fixedMessageBody = fixedMessageBody.replaceAll(RegExp(r',\s*,'), ',');

        // 3. 첫 번째 필드 앞의 쉼표 제거
        fixedMessageBody = fixedMessageBody.replaceAll(RegExp(r'{\s*,'), '{');

        if (fixedMessageBody != messageBody) {
          print('🔧 JSON 형식 수정됨 (ID 필드 제거):');
          print('--- 수정된 메시지 시작 ---');
          print(fixedMessageBody);
          print('--- 수정된 메시지 끝 ---');
        }

        final data = jsonDecode(fixedMessageBody) as Map<String, dynamic>;
        print('📨📨📨 [LEAVE.ALERT] 결재 결과 알림 메시지 수신 📨📨📨');
        print('📄 원본 데이터: $data');
        print('🔍 데이터 분석:');
        print('   - Status: ${data['status']}');
        print('   - Reject Message: ${data['reject_message']}');
        print('   - 데이터 타입: ${data.runtimeType}');
        print('   - 키 목록: ${data.keys.toList()}');

        final alertMessage = LeaveAlertMessage.fromJson(data);
        print('📋 파싱 결과:');
        print('   - Parsed Status: ${alertMessage.status}');
        print('   - Is Approved: ${alertMessage.isApproved}');
        print('   - Is Rejected: ${alertMessage.isRejected}');
        print('   - Reject Message: ${alertMessage.rejectMessage}');

        _alertMessageController.add(alertMessage);
        _showAlertNotification(alertMessage);
        message.ack();
        print('✅ 결재 결과 알림 메시지 처리 완료');
        return;
      } catch (parseError) {
        // JSON이 아닌 경우 원문 메시지를 그대로 표시
        print('ℹ️ [LEAVE.ALERT] JSON 파싱 실패 - 원문 메시지를 그대로 표시: "$messageBody"');
        final plainText = messageBody.trim();
        final fallbackMessage = LeaveAlertMessage(
          status: 'MESSAGE',
          rejectMessage: plainText,
        );
        _alertMessageController.add(fallbackMessage);
        _showAlertNotification(fallbackMessage);
        message.ack();
        print('✅ [LEAVE.ALERT] 원문 메시지 처리 완료');
        return;
      }
    } catch (e) {
      print('❌ 결재 결과 알림 메시지 처리 오류: $e');
      print('📄 에러 발생 시 원본 바이트: ${message.payload}');
      // 최종 예외도 ACK 처리하여 재시도 방지
      try {
        message.ack();
      } catch (_) {}
    }
  }

  /// 참조 알림 메시지 처리
  void _handleCCMessage(amqp.AmqpMessage message) {
    try {
      final String messageBody = utf8.decode(message.payload ?? []);

      print('📨 [CC 큐] 원본 메시지 수신: $messageBody');
      print('📨 [CC 큐] 메시지 길이: ${messageBody.length}');

      // 최소 보정 후 JSON 파싱 시도
      final String fixed = messageBody
          .replaceAll(RegExp(r'"id":\s*\d+,?\s*\n?\s*'), '')
          .replaceAll(RegExp(r',\s*,'), ',')
          .replaceAll(RegExp(r'{\s*,'), '{');

      print('📨 [CC 큐] 수정된 메시지: $fixed');

      try {
        final Map<String, dynamic> data =
            jsonDecode(fixed) as Map<String, dynamic>;

        print('📨 [CC 큐] JSON 파싱 성공');
        print('📨 [CC 큐] 파싱된 데이터: $data');
        print('📨 [CC 큐] 데이터 타입 확인:');
        print('   - name: ${data['name']} (${data['name'].runtimeType})');
        print(
            '   - department: ${data['department']} (${data['department'].runtimeType})');
        print(
            '   - leave_type: ${data['leave_type']} (${data['leave_type'].runtimeType})');
        print(
            '   - start_date: ${data['start_date']} (${data['start_date'].runtimeType})');
        print(
            '   - end_date: ${data['end_date']} (${data['end_date'].runtimeType})');

        final LeaveCCMessage ccMessage = LeaveCCMessage.fromJson(data);
        print('📨 [CC 큐] LeaveCCMessage 객체 생성 성공');
        print(
            '📨 [CC 큐] 변환된 날짜: start=${ccMessage.startDate}, end=${ccMessage.endDate}');
        print('📨 [CC 큐] 포맷된 기간: ${ccMessage.formattedPeriod}');

        _ccMessageController.add(ccMessage);
        _showCCNotification(ccMessage);
        message.ack();
        print('📨 [CC 큐] 메시지 처리 완료');
        return;
      } catch (e) {
        print('❌ [CC 큐] JSON 파싱 실패: $e');
        print('❌ [CC 큐] 원본 메시지: $messageBody');
        print('❌ [CC 큐] 수정된 메시지: $fixed');

        // JSON이 아니면 원문 텍스트를 그대로 보여주기
        final String plainText = messageBody.trim();
        final LeaveCCMessage fallback = LeaveCCMessage(
          name: '참조 알림',
          department: '',
          leaveType: plainText,
          startDate: '',
          endDate: '',
        );
        _ccMessageController.add(fallback);
        _showCCNotification(fallback);
        message.ack();
        print('📨 [CC 큐] Fallback 메시지 처리 완료');
        return;
      }
    } catch (e) {
      print('❌ [CC 큐] 최종 예외 발생: $e');
      // 최종 예외도 조용히 ACK하여 재시도 루프 방지
      try {
        message.ack();
      } catch (_) {}
    }
  }

  /// 전자결재 알림 메시지 처리
  void _handleEApprovalMessage(amqp.AmqpMessage message) {
    String messageBody = '';
    try {
      messageBody = utf8.decode(message.payload ?? []);
      print('📨 [EAPPROVAL 큐] 원본 메시지 수신: $messageBody');
    } catch (decodeError) {
      print('❌ [EAPPROVAL 큐] UTF-8 디코딩 실패: $decodeError');
      try {
        message.ack();
      } catch (_) {}
      return;
    }

    // JSON 파싱 시도
    try {
      final Map<String, dynamic> data = jsonDecode(messageBody);
      final LeaveEApprovalMessage eMsg = LeaveEApprovalMessage.fromJson(data);
      _eapprovalMessageController.add(eMsg);
      _showEApprovalNotification(eMsg);
      message.ack();
      print('📨 [EAPPROVAL 큐] 메시지 처리 완료');
    } catch (parseError) {
      // JSON이 아닌 경우 원문 메시지를 그대로 표시
      print('ℹ️ [EAPPROVAL 큐] JSON 파싱 실패 - 원문 메시지를 그대로 표시: "$messageBody"');
      print('ℹ️ [EAPPROVAL 큐] 파싱 에러: $parseError');
      final plainText = messageBody.trim();
      final fallbackMessage = LeaveEApprovalMessage(
        name: '알림',
        department: '',
        title: plainText,
      );
      try {
        _eapprovalMessageController.add(fallbackMessage);
        _showEApprovalNotification(fallbackMessage);
        message.ack();
        print('✅ [EAPPROVAL 큐] 원문 메시지 처리 완료');
      } catch (e) {
        print('❌ [EAPPROVAL 큐] Fallback 메시지 처리 오류: $e');
        try {
          message.ack();
        } catch (_) {}
      }
    }
  }

  /// 전자결재 CC 알림 메시지 처리
  void _handleEApprovalCCMessage(amqp.AmqpMessage message) {
    String messageBody = '';
    try {
      messageBody = utf8.decode(message.payload ?? []);
      print('📨 [EAPPROVAL.CC 큐] 원본 메시지 수신: $messageBody');
    } catch (decodeError) {
      print('❌ [EAPPROVAL.CC 큐] UTF-8 디코딩 실패: $decodeError');
      try {
        message.ack();
      } catch (_) {}
      return;
    }

    try {
      final Map<String, dynamic> data = jsonDecode(messageBody);
      final LeaveEApprovalMessage ccMsg = LeaveEApprovalMessage(
        name: data['name']?.toString() ?? '',
        department: data['department']?.toString() ?? '',
        title: data['title']?.toString() ?? '',
        approvalType: 'eapproval_cc',
        status: data['status']?.toString(),
      );
      _eapprovalMessageController.add(ccMsg);
      _showEApprovalNotification(ccMsg);
      message.ack();
      print('📨 [EAPPROVAL.CC 큐] 메시지 처리 완료');
    } catch (parseError) {
      print('ℹ️ [EAPPROVAL.CC 큐] JSON 파싱 실패 - 원문 메시지를 그대로 표시: "$messageBody"');
      print('ℹ️ [EAPPROVAL.CC 큐] 파싱 에러: $parseError');
      final fallbackMessage = LeaveEApprovalMessage(
        name: '알림',
        department: '',
        title: messageBody.trim(),
        approvalType: 'eapproval_cc',
      );
      try {
        _eapprovalMessageController.add(fallbackMessage);
        _showEApprovalNotification(fallbackMessage);
        message.ack();
        print('✅ [EAPPROVAL.CC 큐] 원문 메시지 처리 완료');
      } catch (e) {
        print('❌ [EAPPROVAL.CC 큐] Fallback 메시지 처리 오류: $e');
        try {
          message.ack();
        } catch (_) {}
      }
    }
  }

  /// 결재 요청 알림 표시
  void _showApprovalNotification(LeaveApprovalRequest request) {
    if (_container == null) return;
    try {
      if (request.isCancelRequest) {
        // 취소 상신인 경우
        print('🔔 취소 상신 알림: ${request.name}님의 ${request.leaveType} 취소 상신');
        print('   - 부서: ${request.department}');
        print('   - 기간: ${request.formattedPeriod}');
        print('   - 취소 사유: ${request.reason}');
        print('   - 상신 유형: 취소 상신 (is_cancel=1)');
      } else {
        // 일반 결재인 경우
        print('🔔 결재 요청 알림: ${request.name}님의 ${request.leaveType} 결재 요청');
        print('   - 부서: ${request.department}');
        print('   - 기간: ${request.formattedPeriod}');
        print('   - 사유: ${request.reason}');
      }
    } catch (e) {
      print('❌ 결재 요청 알림 표시 오류: $e');
    }
  }

  /// 결재 결과 알림 표시
  void _showAlertNotification(LeaveAlertMessage alertMessage) {
    if (_container == null) return;
    try {
      if (alertMessage.isCancelResult) {
        // 취소 상신 결과인 경우
        final statusText = alertMessage.isApproved ? '승인' : '반려';
        print('🔔 취소 상신 결과 알림: 휴가 취소 상신이 ${statusText}되었습니다.');
        print('   - 상태: ${alertMessage.status}');
        print('   - 결과 유형: 취소 상신 결과 (is_cancel=1)');
        if (alertMessage.rejectMessage != null) {
          print('   - 반려 사유: ${alertMessage.rejectMessage}');
        }
      } else {
        // 일반 결재 결과인 경우
        final statusText = alertMessage.isApproved ? '승인' : '반려';
        print('🔔 결재 결과 알림: 휴가 신청이 ${statusText}되었습니다.');
        print('   - 상태: ${alertMessage.status}');
        if (alertMessage.rejectMessage != null) {
          print('   - 반려 사유: ${alertMessage.rejectMessage}');
        }
      }
    } catch (e) {
      print('❌ 결재 결과 알림 표시 오류: $e');
    }
  }

  /// 참조 알림 표시
  void _showCCNotification(LeaveCCMessage ccMessage) {
    if (_container == null) return;
    try {
      print('🔔 참조 알림: ${ccMessage.name}님의 ${ccMessage.leaveType} 신청');
      print('   - 부서: ${ccMessage.department}');
      print('   - 기간: ${ccMessage.formattedPeriod}');
    } catch (e) {
      print('❌ 참조 알림 표시 오류: $e');
    }
  }

  /// 전자결재 알림 표시
  void _showEApprovalNotification(LeaveEApprovalMessage message) {
    if (_container == null) return;
    try {
      print('🔔 전자결재 알림: ${message.title}');
      print('   - 신청자: ${message.name}');
      print('   - 부서: ${message.department}');
      if (message.status != null && message.status!.isNotEmpty) {
        print('   - 상태: ${message.status}');
      }
    } catch (e) {
      print('❌ 전자결재 알림 표시 오류: $e');
    }
  }

  // --- Health Check & Reconnect Logic ---

  void _startHealthCheck() {
    print('🩺 휴가 실시간 서비스 헬스체크 시작 (10초 주기)');
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _performHealthCheck();
    });
  }

  void _performHealthCheck() {
    if (_isReconnecting) {
      print('🩺 헬스체크: 현재 재연결 작업 진행 중... 건너뜁니다.');
      return;
    }

    final isConnectionLost = !_isConnected ||
        (_isApprover && _approvalConsumer == null) ||
        _alertConsumer == null ||
        _ccConsumer == null ||
        _eapprovalConsumer == null ||
        _eapprovalCcConsumer == null;
    if (isConnectionLost) {
      print('🩺 헬스체크: 연결상태=$_isConnected');
      print(
          '   - Approval Consumer: ${_approvalConsumer != null} (승인자: $_isApprover)');
      print('   - Alert Consumer: ${_alertConsumer != null}');
      print('   - CC Consumer: ${_ccConsumer != null}');
      print('   - EApproval Consumer: ${_eapprovalConsumer != null}');
      print('   - EApproval CC Consumer: ${_eapprovalCcConsumer != null}');
    }

    if (isConnectionLost && _currentUserId != null) {
      print('⚠️ 헬스체크: 연결 끊김 감지! 재연결을 시작합니다.');
      _reconnect();
    } else if (!isConnectionLost) {
      // print('🩺 헬스체크: 연결 양호.');
    }
  }

  Future<void> _reconnect() async {
    if (_isReconnecting) return;

    _isReconnecting = true;
    print('🔄 결재 요청 서비스 재연결 시작...');

    // 기존 리소스를 정리하되, 사용자 정보는 유지
    await stopListening();

    // 재연결 시도 전 잠시 대기 (서버 부하 방지)
    await Future.delayed(Duration(seconds: 5));

    try {
      if (_currentUserId != null && _container != null) {
        print('🔄 재연결: startListening 재호출...');
        // startListening을 다시 호출하여 전체 프로세스 재시작
        await startListening(_currentUserId!, _container!,
            isApprover: _isApprover);
        print('✅ 결재 요청 서비스 재연결 성공!');
      } else {
        print('⚠️ 재연결 정보(사용자 ID, 컨테이너)가 없어 재연결을 중단합니다.');
      }
    } catch (e) {
      print('❌ 결재 요청 서비스 재연결 실패: $e');
    } finally {
      _isReconnecting = false;
      print('🔄 결재 요청 서비스 재연결 프로세스 종료.');
    }
  }

  /// 리소스 정리
  void dispose() {
    _approvalRequestController.close();
    _alertMessageController.close();
    _ccMessageController.close();
    // dispose 시 모든 리소스 정리
    _currentUserId = null;
    _container = null;
    stopListening();
  }
}

/// 결재 요청 데이터 모델
class LeaveApprovalRequest {
  final String? id; // 휴가 신청 ID 추가
  final String name;
  final String department;
  final String leaveType;
  final String startDate; // 2025-09-03 형식
  final String endDate; // 2025-09-03 형식
  final double workdaysCount;
  final String reason;
  final int isCancel; // 0: 일반 결재, 1: 취소 상신

  LeaveApprovalRequest({
    this.id,
    required this.name,
    required this.department,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.workdaysCount,
    required this.reason,
    this.isCancel = 0,
  });

  factory LeaveApprovalRequest.fromJson(Map<String, dynamic> json) {
    return LeaveApprovalRequest(
      id: json['id']?.toString() ??
          json['requestId']?.toString() ??
          json['request_id']?.toString() ??
          json['leave_id']?.toString() ??
          json['leave_request_id']?.toString(),
      name: json['name'] ?? '',
      department: json['department'] ?? '',
      leaveType: json['leave_type'] ?? '',
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      workdaysCount: (json['workdays_count'] ?? 0).toDouble(),
      reason: json['reason'] ?? '',
      isCancel: json['is_cancel'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'department': department,
      'leave_type': leaveType,
      'start_date': startDate,
      'end_date': endDate,
      'workdays_count': workdaysCount,
      'reason': reason,
      'is_cancel': isCancel,
    };
  }

  /// 취소 상신 여부 확인
  bool get isCancelRequest => isCancel == 1;

  /// 휴가 기간 포맷 (예: 2025.09.03 - 2025.09.03)
  String get formattedPeriod {
    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);

      if (start.isAtSameMomentAs(end)) {
        return '${start.year}.${start.month.toString().padLeft(2, '0')}.${start.day.toString().padLeft(2, '0')}';
      } else {
        return '${start.year}.${start.month.toString().padLeft(2, '0')}.${start.day.toString().padLeft(2, '0')} - ${end.year}.${end.month.toString().padLeft(2, '0')}.${end.day.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '$startDate - $endDate';
    }
  }
}

/// 휴가 결재 결과 알림 데이터 모델
class LeaveAlertMessage {
  final String status; // "APPROVED" 또는 "REJECTED"
  final String? rejectMessage; // 반려 사유 (반려시에만)
  final int isCancel; // 0: 일반 결재 결과, 1: 취소 상신 결과

  LeaveAlertMessage({
    required this.status,
    this.rejectMessage,
    this.isCancel = 0,
  });

  factory LeaveAlertMessage.fromJson(Map<String, dynamic> json) {
    return LeaveAlertMessage(
      status: json['status']?.toString() ?? '',
      rejectMessage: json['reject_message']?.toString(),
      isCancel: json['is_cancel'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      if (rejectMessage != null) 'reject_message': rejectMessage,
      'is_cancel': isCancel,
    };
  }

  bool get isApproved => status == 'APPROVED' || status == 'CANCEL_APPROVED';
  bool get isRejected => status == 'REJECTED' || status == 'CANCEL_REJECTED';

  /// 취소 상신 결과 여부 확인
  bool get isCancelResult => isCancel == 1;
}

/// 휴가 참조 알림 데이터 모델
class LeaveCCMessage {
  final String name; // 신청자 이름
  final String department; // 소속 부서
  final String leaveType; // 휴가 종류
  final String startDate; // 시작일
  final String endDate; // 종료일

  LeaveCCMessage({
    required this.name,
    required this.department,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
  });

  factory LeaveCCMessage.fromJson(Map<String, dynamic> json) {
    return LeaveCCMessage(
      name: json['name'] ?? '',
      department: json['department'] ?? '',
      leaveType: json['leave_type'] ?? '',
      startDate: _parseDateField(json['start_date']),
      endDate: _parseDateField(json['end_date']),
    );
  }

  /// 날짜 필드 파싱 (문자열 또는 숫자 모두 처리)
  static String _parseDateField(dynamic dateValue) {
    if (dateValue == null) return '';

    // 문자열인 경우 그대로 반환
    if (dateValue is String) {
      return dateValue;
    }

    // 숫자인 경우 문자열로 변환
    if (dateValue is int) {
      return dateValue.toString();
    }

    // 기타 타입인 경우 문자열로 변환
    return dateValue.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'department': department,
      'leave_type': leaveType,
      'start_date': startDate,
      'end_date': endDate,
    };
  }

  /// 휴가 기간 포맷 (예: 2025.09.03 - 2025.09.03)
  String get formattedPeriod {
    try {
      // 날짜 문자열을 다양한 형식으로 파싱 시도
      DateTime? start = _parseFlexibleDate(startDate);
      DateTime? end = _parseFlexibleDate(endDate);

      if (start == null || end == null) {
        return '$startDate - $endDate';
      }

      if (start.isAtSameMomentAs(end)) {
        return '${start.year}.${start.month.toString().padLeft(2, '0')}.${start.day.toString().padLeft(2, '0')}';
      } else {
        return '${start.year}.${start.month.toString().padLeft(2, '0')}.${start.day.toString().padLeft(2, '0')} - ${end.year}.${end.month.toString().padLeft(2, '0')}.${end.day.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '$startDate - $endDate';
    }
  }

  /// 다양한 날짜 형식을 파싱하는 헬퍼 메서드
  DateTime? _parseFlexibleDate(String dateStr) {
    if (dateStr.isEmpty) return null;

    try {
      // 1. ISO 형식 (2025-09-03)
      if (dateStr.contains('-')) {
        return DateTime.parse(dateStr);
      }

      // 2. 숫자 형식 (20250903)
      if (RegExp(r'^\d{8}$').hasMatch(dateStr)) {
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));
        return DateTime(year, month, day);
      }

      // 3. 숫자 형식 (2025-09-03에서 하이픈 제거)
      if (RegExp(r'^\d{4}\d{2}\d{2}$').hasMatch(dateStr)) {
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));
        return DateTime(year, month, day);
      }

      // 4. 기본 파싱 시도
      return DateTime.parse(dateStr);
    } catch (e) {
      print('⚠️ 날짜 파싱 실패: $dateStr, 오류: $e');
      return null;
    }
  }
}

/// 전자결재 일반 알림 데이터 모델
class LeaveEApprovalMessage {
  final String name; // 신청자 이름
  final String department; // 부서
  final String title; // 제목
  final String? approvalType; // hr_leave_grant 또는 eapproval
  final String? status; // 승인, 반려 등

  LeaveEApprovalMessage({
    required this.name,
    required this.department,
    required this.title,
    this.approvalType,
    this.status,
  });

  factory LeaveEApprovalMessage.fromJson(Map<String, dynamic> json) {
    return LeaveEApprovalMessage(
      name: json['name']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      approvalType: json['approval_type']?.toString(),
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'department': department,
      'title': title,
      'approval_type': approvalType,
      if (status != null) 'status': status,
    };
  }
}

/// Provider
final leaveApprovalRealtimeServiceProvider =
    Provider<LeaveApprovalRealtimeService>((ref) {
  return LeaveApprovalRealtimeService.instance;
});

/// 결재 요청 상태 관리
class LeaveApprovalNotifier extends StateNotifier<List<LeaveApprovalRequest>> {
  LeaveApprovalNotifier() : super([]);

  void addApprovalRequest(LeaveApprovalRequest request) {
    state = [...state, request];
  }

  void clearApprovalRequests() {
    state = [];
  }
}

final leaveApprovalRequestsProvider =
    StateNotifierProvider<LeaveApprovalNotifier, List<LeaveApprovalRequest>>(
        (ref) {
  return LeaveApprovalNotifier();
});
