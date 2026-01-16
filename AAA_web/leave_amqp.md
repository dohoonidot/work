# 휴가 결재 시스템 & AMQP 알림 구현 가이드 📋

## 📋 개요

현재 휴가관리 시스템에 관리자용 결재 화면과 AMQP 기반 실시간 알림 시스템을 추가하는 구현 가이드입니다.
부서장은 실시간으로 부서원의 휴가 신청 알림을 받고, 승인/반려 처리할 수 있습니다.

## 🎯 구현 목표

- ✅ 관리자용 휴가 결재 화면 구현
- ✅ AMQP를 통한 실시간 알림 시스템
- ✅ 휴가 신청 → 부서장 알림 → 승인/반려 프로세스
- ✅ UI/UX가 통일된 결재 관리 인터페이스

---

## 🏗️ Step 1: AMQP 서비스 확장

### 1.1 amqp_service.dart 수정

**파일**: `lib/shared/services/amqp_service.dart`

#### 큐 설정 확장

```dart
// 기존 _setupQueuesAndConsumers() 메서드 수정
Future<void> _setupQueuesAndConsumers() async {
  print('🔧 [AMQP] _setupQueuesAndConsumers() 시작');

  if (_channel == null || _currentUserId == null) {
    print('❌ [AMQP] 채널 또는 사용자 ID가 없어 큐 설정을 건너뜁니다.');
    return;
  }

  // 기본적으로 alert 큐는 항상 생성
  final queuesToCreate = ['alert'];
  
  // 🆕 관리자 권한이 있는 경우 leave_approval 큐 추가
  if (await _checkManagerPermission(_currentUserId!)) {
    queuesToCreate.add('leave_approval');
  }

  // 개인정보 동의 시에만 gift와 birthday 큐 추가
  if (_isPrivacyAgreed) {
    queuesToCreate.addAll(['gift', 'birthday']);
  }

  print('🎯 [AMQP] 생성할 큐 목록: $queuesToCreate (관리자 권한 확인됨)');
  for (final queueType in queuesToCreate) {
    print('🔧 [AMQP] 큐 설정 시작: $queueType');
    await _createSingleConsumer(queueType);
  }

  // alert 큐를 broadcast exchange에 바인딩
  print('🔧 [AMQP] alert 큐 broadcast 바인딩 시작');
  await _bindAlertQueueToBroadcast();
  print('✅ [AMQP] _setupQueuesAndConsumers() 완료');
}

// 🆕 관리자 권한 확인 메서드 추가
Future<bool> _checkManagerPermission(String userId) async {
  try {
    // 실제로는 API를 호출하여 확인하지만, 임시로 간단한 로직 사용
    // TODO: 실제 API 연동 필요
    return userId.contains('manager') || userId.contains('admin');
  } catch (e) {
    print('⚠️ [AMQP] 관리자 권한 확인 실패: $e');
    return false;
  }
}
```

#### 메시지 핸들러 확장

```dart
// _handleMessage() 메서드에 새로운 케이스 추가
void _handleMessage(amqp.AmqpMessage message, String queueType) {
  // ... 기존 코드 ...
  
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
    case 'leave_approval': // 🆕 새로 추가
      print('📝 [AMQP] 휴가 결재 메시지 처리로 분기');
      _handleLeaveApprovalMessage(messageData, message);
      break;
    // ... 기존 코드 ...
  }
}

// 🆕 휴가 결재 메시지 핸들러 추가
void _handleLeaveApprovalMessage(
  Map<String, dynamic> data, 
  amqp.AmqpMessage originalMessage
) async {
  print('📝 [AMQP] _handleLeaveApprovalMessage() 시작');

  try {
    print('📝 [AMQP] 휴가 결재 메시지 처리 시작: $data');

    // 알림 표시
    print('📝 [AMQP] 휴가 결재 알림 표시');
    _showLeaveApprovalNotification(data);

    // 관리자 화면 업데이트 알림
    print('📝 [AMQP] 관리자 화면 업데이트');
    _notifyApprovalScreenUpdate(data);

    print('✅ [AMQP] 휴가 결재 메시지 처리 완료');
    originalMessage.ack();
  } catch (e) {
    print('❌ [AMQP] 휴가 결재 메시지 처리 실패: $e');
    originalMessage.reject(true);
  }
}
```

#### 스트림 컨트롤러 추가

```dart
class AmqpService {
  // 기존 스트림 컨트롤러들과 함께 추가
  final StreamController<Map<String, dynamic>> _leaveApprovalController =
      StreamController.broadcast();

  // 스트림 게터 추가
  Stream<Map<String, dynamic>> get leaveApprovalStream => 
      _leaveApprovalController.stream;

  // 알림 전송 메서드
  void _notifyApprovalScreenUpdate(Map<String, dynamic> data) {
    if (!_leaveApprovalController.isClosed) {
      _leaveApprovalController.add(data);
    }
  }

  // dispose에 스트림 컨트롤러 정리 추가
  Future<void> dispose() async {
    // ... 기존 dispose 코드 ...
    await _leaveApprovalController.close();
  }
}
```

---

## 🏗️ Step 2: 데이터 모델 생성

### 2.1 새 파일 생성: `lib/models/leave_approval_models.dart`

```dart
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

/// 휴가 결재 요청 모델
class LeaveApprovalRequest {
  final String id;
  final String applicantId;
  final String applicantName;
  final String department;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final double days;
  final String reason;
  final DateTime requestedDate;
  final LeaveApprovalStatus status;
  final String? rejectReason;
  final DateTime? processedDate;
  final String approverId;
  final String? approverName;

  LeaveApprovalRequest({
    required this.id,
    required this.applicantId,
    required this.applicantName,
    required this.department,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.reason,
    required this.requestedDate,
    required this.status,
    this.rejectReason,
    this.processedDate,
    required this.approverId,
    this.approverName,
  });

  factory LeaveApprovalRequest.fromJson(Map<String, dynamic> json) {
    return LeaveApprovalRequest(
      id: json['id'] ?? '',
      applicantId: json['applicant_id'] ?? '',
      applicantName: json['applicant_name'] ?? '',
      department: json['department'] ?? '',
      leaveType: json['leave_type'] ?? '',
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      days: (json['days'] ?? 0.0).toDouble(),
      reason: json['reason'] ?? '',
      requestedDate: DateTime.parse(json['requested_date']),
      status: LeaveApprovalStatus.fromString(json['status']),
      rejectReason: json['reject_reason'],
      processedDate: json['processed_date'] != null 
          ? DateTime.parse(json['processed_date']) 
          : null,
      approverId: json['approver_id'] ?? '',
      approverName: json['approver_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'applicant_id': applicantId,
      'applicant_name': applicantName,
      'department': department,
      'leave_type': leaveType,
      'start_date': DateFormat('yyyy-MM-dd').format(startDate),
      'end_date': DateFormat('yyyy-MM-dd').format(endDate),
      'days': days,
      'reason': reason,
      'requested_date': requestedDate.toIso8601String(),
      'status': status.value,
      'reject_reason': rejectReason,
      'processed_date': processedDate?.toIso8601String(),
      'approver_id': approverId,
      'approver_name': approverName,
    };
  }

  // 승인/반려 처리를 위한 copyWith 메서드
  LeaveApprovalRequest copyWith({
    LeaveApprovalStatus? status,
    String? rejectReason,
    DateTime? processedDate,
  }) {
    return LeaveApprovalRequest(
      id: id,
      applicantId: applicantId,
      applicantName: applicantName,
      department: department,
      leaveType: leaveType,
      startDate: startDate,
      endDate: endDate,
      days: days,
      reason: reason,
      requestedDate: requestedDate,
      status: status ?? this.status,
      rejectReason: rejectReason ?? this.rejectReason,
      processedDate: processedDate ?? this.processedDate,
      approverId: approverId,
      approverName: approverName,
    );
  }
}

/// 결재 상태 열거형
enum LeaveApprovalStatus {
  pending('PENDING', '대기'),
  approved('APPROVED', '승인'),
  rejected('REJECTED', '반려');

  const LeaveApprovalStatus(this.value, this.label);

  final String value;
  final String label;

  static LeaveApprovalStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PENDING':
        return LeaveApprovalStatus.pending;
      case 'APPROVED':
        return LeaveApprovalStatus.approved;
      case 'REJECTED':
        return LeaveApprovalStatus.rejected;
      default:
        return LeaveApprovalStatus.pending;
    }
  }

  Color get statusColor {
    switch (this) {
      case LeaveApprovalStatus.pending:
        return const Color(0xFFFF8C00);
      case LeaveApprovalStatus.approved:
        return const Color(0xFF20C997);
      case LeaveApprovalStatus.rejected:
        return const Color(0xFFDC3545);
    }
  }
}

/// AMQP 알림 메시지 모델
class LeaveApprovalNotification {
  final String type; // 'leave_request', 'approval_result'
  final LeaveApprovalRequest request;
  final DateTime timestamp;
  final String? message;

  LeaveApprovalNotification({
    required this.type,
    required this.request,
    required this.timestamp,
    this.message,
  });

  factory LeaveApprovalNotification.fromJson(Map<String, dynamic> json) {
    return LeaveApprovalNotification(
      type: json['type'] ?? '',
      request: LeaveApprovalRequest.fromJson(json['data'] ?? {}),
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      message: json['message'],
    );
  }

  String get notificationTitle {
    switch (type) {
      case 'leave_request':
        return '새로운 휴가 신청';
      case 'approval_result':
        return '휴가 결재 결과';
      default:
        return '휴가 관련 알림';
    }
  }

  String get notificationMessage {
    if (message != null) return message!;
    
    switch (type) {
      case 'leave_request':
        return '${request.applicantName}님이 ${request.leaveType}을 신청했습니다.';
      case 'approval_result':
        return '휴가 신청이 ${request.status.label}되었습니다.';
      default:
        return '휴가 관련 업데이트가 있습니다.';
    }
  }
}
```

---

## 🔌 Step 3: API 서비스 구현

### 3.1 새 파일 생성: `lib/services/leave_approval_api_service.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ASPN_AI_AGENT/core/config/app_config.dart';
import 'package:ASPN_AI_AGENT/models/leave_approval_models.dart';

class LeaveApprovalApiService {
  static String get serverUrl => AppConfig.baseUrl;

  /// 관리자용 결재 대기 목록 조회
  static Future<List<LeaveApprovalRequest>> getPendingApprovals(
    String managerId
  ) async {
    final url = Uri.parse('$serverUrl/api/leave/approvals/pending');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'manager_id': managerId});

    try {
      print('📝 결재 대기 목록 API 요청: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('📝 결재 대기 목록 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final List<dynamic> requestList = data['requests'] ?? [];

        return requestList
            .map((json) => LeaveApprovalRequest.fromJson(json))
            .toList();
      } else {
        throw Exception('결재 대기 목록 조회 실패. 상태 코드: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ 결재 대기 목록 API 호출 실패: $e');
      throw Exception('결재 대기 목록 조회 실패: $e');
    }
  }

  /// 휴가 승인/반려 처리
  static Future<bool> processLeaveApproval({
    required String requestId,
    required String managerId,
    required String action, // 'APPROVE' | 'REJECT'
    String? rejectReason,
  }) async {
    final url = Uri.parse('$serverUrl/api/leave/approvals/process');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'request_id': requestId,
      'manager_id': managerId,
      'action': action,
      if (rejectReason != null) 'reject_reason': rejectReason,
    });

    try {
      print('📝 휴가 결재 처리 API 요청: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('📝 휴가 결재 처리 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data['success'] == true;
      } else {
        throw Exception('휴가 결재 처리 실패. 상태 코드: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ 휴가 결재 처리 API 호출 실패: $e');
      throw Exception('휴가 결재 처리 실패: $e');
    }
  }

  /// 부서원 휴가 내역 조회 (관리자용)
  static Future<List<LeaveApprovalRequest>> getDepartmentLeaveHistory({
    required String managerId,
    required int year,
    String? status,
  }) async {
    final url = Uri.parse('$serverUrl/api/leave/approvals/history');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'manager_id': managerId,
      'year': year,
      if (status != null) 'status': status,
    });

    try {
      print('📝 부서원 휴가 내역 API 요청: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('📝 부서원 휴가 내역 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final List<dynamic> requestList = data['requests'] ?? [];

        return requestList
            .map((json) => LeaveApprovalRequest.fromJson(json))
            .toList();
      } else {
        throw Exception('부서원 휴가 내역 조회 실패. 상태 코드: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ 부서원 휴가 내역 API 호출 실패: $e');
      throw Exception('부서원 휴가 내역 조회 실패: $e');
    }
  }

  /// 관리자 권한 확인
  static Future<bool> checkManagerPermission(String userId) async {
    final url = Uri.parse('$serverUrl/api/user/permissions');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'user_id': userId});

    try {
      final response = await http.post(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data['is_manager'] == true;
      } else {
        return false;
      }
    } catch (e) {
      print('⚠️ 관리자 권한 확인 실패: $e');
      return false;
    }
  }
}
```

---

## 📊 Step 4: 상태 관리 구현

### 4.1 새 파일 생성: `lib/providers/leave_approval_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/models/leave_approval_models.dart';
import 'package:ASPN_AI_AGENT/services/leave_approval_api_service.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';

/// 결재 요청 목록 상태
class LeaveApprovalState {
  final List<LeaveApprovalRequest> pendingRequests;
  final List<LeaveApprovalRequest> processedRequests;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  LeaveApprovalState({
    this.pendingRequests = const [],
    this.processedRequests = const [],
    this.isLoading = false,
    this.error,
    this.lastUpdated,
  });

  LeaveApprovalState copyWith({
    List<LeaveApprovalRequest>? pendingRequests,
    List<LeaveApprovalRequest>? processedRequests,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return LeaveApprovalState(
      pendingRequests: pendingRequests ?? this.pendingRequests,
      processedRequests: processedRequests ?? this.processedRequests,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // 모든 요청 목록 (결합)
  List<LeaveApprovalRequest> get allRequests => [
    ...pendingRequests,
    ...processedRequests,
  ];

  // 상태별 필터링
  List<LeaveApprovalRequest> getRequestsByStatus(LeaveApprovalStatus status) {
    return allRequests.where((req) => req.status == status).toList();
  }
}

/// 결재 요청 관리 Notifier
class LeaveApprovalNotifier extends StateNotifier<LeaveApprovalState> {
  LeaveApprovalNotifier() : super(LeaveApprovalState());

  /// 결재 대기 목록 로드
  Future<void> loadPendingApprovals(String managerId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final pendingRequests = await LeaveApprovalApiService.getPendingApprovals(managerId);
      
      state = state.copyWith(
        pendingRequests: pendingRequests,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 부서원 휴가 내역 로드
  Future<void> loadDepartmentHistory(String managerId, int year) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final processedRequests = await LeaveApprovalApiService.getDepartmentLeaveHistory(
        managerId: managerId,
        year: year,
      );
      
      state = state.copyWith(
        processedRequests: processedRequests,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 휴가 승인 처리
  Future<bool> approveLeaveRequest(String requestId, String managerId) async {
    try {
      final success = await LeaveApprovalApiService.processLeaveApproval(
        requestId: requestId,
        managerId: managerId,
        action: 'APPROVE',
      );

      if (success) {
        // 로컬 상태 업데이트
        _updateRequestStatus(requestId, LeaveApprovalStatus.approved);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// 휴가 반려 처리
  Future<bool> rejectLeaveRequest(
    String requestId, 
    String managerId, 
    String rejectReason
  ) async {
    try {
      final success = await LeaveApprovalApiService.processLeaveApproval(
        requestId: requestId,
        managerId: managerId,
        action: 'REJECT',
        rejectReason: rejectReason,
      );

      if (success) {
        // 로컬 상태 업데이트
        _updateRequestStatus(requestId, LeaveApprovalStatus.rejected, rejectReason);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// 새로운 결재 요청 추가 (AMQP를 통한 실시간 업데이트)
  void addNewRequest(LeaveApprovalRequest request) {
    final updatedPendingRequests = [request, ...state.pendingRequests];
    state = state.copyWith(
      pendingRequests: updatedPendingRequests,
      lastUpdated: DateTime.now(),
    );
  }

  /// 로컬 상태에서 요청 상태 업데이트
  void _updateRequestStatus(
    String requestId, 
    LeaveApprovalStatus newStatus, 
    [String? rejectReason]
  ) {
    // pending 목록에서 해당 요청 찾기
    final pendingIndex = state.pendingRequests.indexWhere((req) => req.id == requestId);
    if (pendingIndex != -1) {
      final updatedRequest = state.pendingRequests[pendingIndex].copyWith(
        status: newStatus,
        rejectReason: rejectReason,
        processedDate: DateTime.now(),
      );

      // pending에서 제거하고 processed에 추가
      final updatedPendingRequests = List<LeaveApprovalRequest>.from(state.pendingRequests)
        ..removeAt(pendingIndex);
      final updatedProcessedRequests = [updatedRequest, ...state.processedRequests];

      state = state.copyWith(
        pendingRequests: updatedPendingRequests,
        processedRequests: updatedProcessedRequests,
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// 상태 초기화
  void resetState() {
    state = LeaveApprovalState();
  }
}

/// Provider 정의
final leaveApprovalProvider = StateNotifierProvider<LeaveApprovalNotifier, LeaveApprovalState>(
  (ref) => LeaveApprovalNotifier(),
);

/// 관리자 권한 확인 Provider
final managerPermissionProvider = FutureProvider.family<bool, String>((ref, userId) async {
  return await LeaveApprovalApiService.checkManagerPermission(userId);
});

/// 현재 로그인한 사용자의 관리자 권한 Provider
final currentUserManagerPermissionProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(userIdProvider);
  if (userId == null) return false;
  
  return await LeaveApprovalApiService.checkManagerPermission(userId);
});
```

---

## 🎨 Step 5: UI 컴포넌트 구현

### 5.1 알림 배너: `lib/widgets/leave_approval_notification_banner.dart`

```dart
import 'package:flutter/material.dart';
import 'package:ASPN_AI_AGENT/models/leave_approval_models.dart';
import 'package:intl/intl.dart';

class LeaveApprovalNotificationBanner extends StatefulWidget {
  final LeaveApprovalNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final Duration displayDuration;

  const LeaveApprovalNotificationBanner({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismiss,
    this.displayDuration = const Duration(seconds: 5),
  });

  @override
  State<LeaveApprovalNotificationBanner> createState() => 
      _LeaveApprovalNotificationBannerState();
}

class _LeaveApprovalNotificationBannerState 
    extends State<LeaveApprovalNotificationBanner>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    // 애니메이션 시작
    _animationController.forward();

    // 자동 숨김 타이머
    Future.delayed(widget.displayDuration, () {
      if (mounted) {
        _animationController.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 100),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1E88E5),
                      const Color(0xFF1976D2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 알림 아이콘
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getNotificationIcon(),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // 알림 내용
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.notification.notificationTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.notification.notificationMessage,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(widget.notification.request.startDate),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 닫기 버튼
                    IconButton(
                      onPressed: () {
                        _animationController.reverse().then((_) {
                          widget.onDismiss();
                        });
                      },
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getNotificationIcon() {
    switch (widget.notification.type) {
      case 'leave_request':
        return Icons.assignment;
      case 'approval_result':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MM/dd (E)', 'ko').format(date);
  }
}
```

### 5.2 결재 요청 카드: `lib/widgets/leave_approval_request_card.dart`

```dart
import 'package:flutter/material.dart';
import 'package:ASPN_AI_AGENT/models/leave_approval_models.dart';
import 'package:intl/intl.dart';

class LeaveApprovalRequestCard extends StatelessWidget {
  final LeaveApprovalRequest request;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onTap;
  final bool showActions;

  const LeaveApprovalRequestCard({
    super.key,
    required this.request,
    this.onApprove,
    this.onReject,
    this.onTap,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더 행
              Row(
                children: [
                  // 신청자 정보
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF1E88E5).withOpacity(0.1),
                          child: Text(
                            request.applicantName.isNotEmpty 
                                ? request.applicantName.substring(0, 1)
                                : '?',
                            style: const TextStyle(
                              color: Color(0xFF1E88E5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.applicantName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              request.department,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // 상태 배지
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: request.status.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      request.status.label,
                      style: TextStyle(
                        color: request.status.statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 휴가 정보
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.event_note,
                          color: Colors.grey[600],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${request.leaveType} (${request.days}일)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Colors.grey[600],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_formatDate(request.startDate)} ~ ${_formatDate(request.endDate)}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (request.reason.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.comment,
                            color: Colors.grey[600],
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              request.reason,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 신청일
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    color: Colors.grey[500],
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '신청일: ${_formatDateTime(request.requestedDate)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              // 액션 버튼들 (대기 상태일 때만 표시)
              if (showActions && request.status == LeaveApprovalStatus.pending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('승인'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF20C997),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('반려'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC3545),
                          side: const BorderSide(color: Color(0xFFDC3545)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // 반려 사유 (반려된 경우에만 표시)
              if (request.status == LeaveApprovalStatus.rejected && 
                  request.rejectReason?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC3545).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFDC3545).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '반려 사유',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Color(0xFFDC3545),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request.rejectReason!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFDC3545),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy.MM.dd (E)', 'ko').format(date);
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy.MM.dd HH:mm', 'ko').format(dateTime);
  }
}
```

---

## 🏢 Step 6: 관리자 화면 완성

### 6.1 관리자 결재 화면: `lib/ui/screens/admin_leave_approval_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:ASPN_AI_AGENT/models/leave_approval_models.dart';
import 'package:ASPN_AI_AGENT/providers/leave_approval_provider.dart';
import 'package:ASPN_AI_AGENT/widgets/leave_approval_request_card.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:ASPN_AI_AGENT/shared/services/amqp_service.dart';
import 'dart:async';

class AdminLeaveApprovalScreen extends ConsumerStatefulWidget {
  const AdminLeaveApprovalScreen({super.key});

  @override
  ConsumerState<AdminLeaveApprovalScreen> createState() =>
      _AdminLeaveApprovalScreenState();
}

class _AdminLeaveApprovalScreenState
    extends ConsumerState<AdminLeaveApprovalScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true; // 상태 유지

  String _selectedTab = 'pending'; // 'pending', 'approved', 'rejected', 'all'
  StreamSubscription? _approvalNotificationSubscription;

  // 반려 사유 입력을 위한 컨트롤러
  final TextEditingController _rejectReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // 초기 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      _setupNotificationListener();
    });
  }

  @override
  void dispose() {
    _approvalNotificationSubscription?.cancel();
    _rejectReasonController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    final currentUserId = ref.read(userIdProvider);
    if (currentUserId != null) {
      ref.read(leaveApprovalProvider.notifier).loadPendingApprovals(currentUserId);
      ref.read(leaveApprovalProvider.notifier).loadDepartmentHistory(
        currentUserId,
        DateTime.now().year,
      );
    }
  }

  void _setupNotificationListener() {
    // AMQP 알림 구독
    _approvalNotificationSubscription = ref
        .read(amqpServiceProvider)
        .leaveApprovalStream
        .listen(_handleApprovalNotification);
  }

  void _handleApprovalNotification(Map<String, dynamic> data) {
    try {
      final notification = LeaveApprovalNotification.fromJson(data);
      
      // 새로운 결재 요청인 경우 목록에 추가
      if (notification.type == 'leave_request') {
        ref.read(leaveApprovalProvider.notifier).addNewRequest(notification.request);
        
        // 사용자에게 알림 표시
        _showNotificationSnackBar(notification);
      }
    } catch (e) {
      print('❌ 결재 알림 처리 실패: $e');
    }
  }

  void _showNotificationSnackBar(LeaveApprovalNotification notification) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.assignment, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(notification.notificationMessage),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E88E5),
        action: SnackBarAction(
          label: '확인',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _selectedTab = 'pending';
            });
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        foregroundColor: const Color(0xFF374151),
        elevation: 0,
        title: const Text(
          '휴가 결재 관리',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          // 탭 바
          _buildTabBar(),
          
          // 탭 내용
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final approvalState = ref.watch(leaveApprovalProvider);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        border: Border(bottom: BorderSide(color: Color(0xFFE9ECEF))),
      ),
      child: Row(
        children: [
          _buildTabButton(
            'pending',
            '대기',
            approvalState.pendingRequests.length,
            Icons.schedule,
          ),
          _buildTabButton(
            'approved',
            '승인',
            approvalState.getRequestsByStatus(LeaveApprovalStatus.approved).length,
            Icons.check_circle,
          ),
          _buildTabButton(
            'rejected',
            '반려',
            approvalState.getRequestsByStatus(LeaveApprovalStatus.rejected).length,
            Icons.cancel,
          ),
          _buildTabButton(
            'all',
            '전체',
            approvalState.allRequests.length,
            Icons.list,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tabId, String label, int count, IconData icon) {
    final isSelected = _selectedTab == tabId;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = tabId;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E88E5) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Colors.white.withOpacity(0.2) 
                        : const Color(0xFF1E88E5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    final approvalState = ref.watch(leaveApprovalProvider);

    if (approvalState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (approvalState.error != null) {
      return _buildErrorWidget(approvalState.error!);
    }

    List<LeaveApprovalRequest> requests;
    switch (_selectedTab) {
      case 'pending':
        requests = approvalState.pendingRequests;
        break;
      case 'approved':
        requests = approvalState.getRequestsByStatus(LeaveApprovalStatus.approved);
        break;
      case 'rejected':
        requests = approvalState.getRequestsByStatus(LeaveApprovalStatus.rejected);
        break;
      case 'all':
        requests = approvalState.allRequests;
        break;
      default:
        requests = [];
    }

    if (requests.isEmpty) {
      return _buildEmptyWidget();
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return LeaveApprovalRequestCard(
            request: request,
            showActions: _selectedTab == 'pending',
            onApprove: () => _approveRequest(request),
            onReject: () => _rejectRequest(request),
            onTap: () => _showRequestDetail(request),
          );
        },
      ),
    );
  }

  Widget _buildEmptyWidget() {
    String message;
    IconData icon;
    
    switch (_selectedTab) {
      case 'pending':
        message = '대기 중인 결재 요청이 없습니다.';
        icon = Icons.schedule;
        break;
      case 'approved':
        message = '승인된 요청이 없습니다.';
        icon = Icons.check_circle;
        break;
      case 'rejected':
        message = '반려된 요청이 없습니다.';
        icon = Icons.cancel;
        break;
      default:
        message = '결재 요청이 없습니다.';
        icon = Icons.list;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            '데이터를 불러오는 중 오류가 발생했습니다.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _refreshData,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshData() async {
    final currentUserId = ref.read(userIdProvider);
    if (currentUserId != null) {
      await ref.read(leaveApprovalProvider.notifier).loadPendingApprovals(currentUserId);
      await ref.read(leaveApprovalProvider.notifier).loadDepartmentHistory(
        currentUserId,
        DateTime.now().year,
      );
    }
  }

  void _approveRequest(LeaveApprovalRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('휴가 승인'),
        content: Text('${request.applicantName}님의 휴가 신청을 승인하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _processApproval(request.id, true);
            },
            child: const Text('승인'),
          ),
        ],
      ),
    );
  }

  void _rejectRequest(LeaveApprovalRequest request) {
    _rejectReasonController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('휴가 반려'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${request.applicantName}님의 휴가 신청을 반려합니다.'),
            const SizedBox(height: 16),
            const Text(
              '반려 사유를 입력해주세요:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _rejectReasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '반려 사유를 입력하세요...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_rejectReasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('반려 사유를 입력해주세요.')),
                );
                return;
              }
              Navigator.pop(context);
              await _processApproval(request.id, false, _rejectReasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('반려'),
          ),
        ],
      ),
    );
  }

  Future<void> _processApproval(String requestId, bool isApproved, [String? rejectReason]) async {
    final currentUserId = ref.read(userIdProvider);
    if (currentUserId == null) return;

    bool success;
    if (isApproved) {
      success = await ref.read(leaveApprovalProvider.notifier).approveLeaveRequest(requestId, currentUserId);
    } else {
      success = await ref.read(leaveApprovalProvider.notifier).rejectLeaveRequest(
        requestId,
        currentUserId,
        rejectReason ?? '',
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (isApproved ? '휴가를 승인했습니다.' : '휴가를 반려했습니다.')
                : '처리 중 오류가 발생했습니다.',
          ),
          backgroundColor: success
              ? (isApproved ? Colors.green : Colors.orange)
              : Colors.red,
        ),
      );
    }
  }

  void _showRequestDetail(LeaveApprovalRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${request.applicantName}님의 휴가 신청'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('부서', request.department),
            _buildDetailRow('휴가 종류', request.leaveType),
            _buildDetailRow('기간', '${_formatDate(request.startDate)} ~ ${_formatDate(request.endDate)}'),
            _buildDetailRow('일수', '${request.days}일'),
            _buildDetailRow('신청일', _formatDateTime(request.requestedDate)),
            _buildDetailRow('상태', request.status.label),
            if (request.reason.isNotEmpty)
              _buildDetailRow('사유', request.reason),
            if (request.rejectReason?.isNotEmpty == true)
              _buildDetailRow('반려 사유', request.rejectReason!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy.MM.dd (E)', 'ko').format(date);
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy.MM.dd HH:mm', 'ko').format(dateTime);
  }
}
```

---

## 🔔 Step 7: 알림 시스템 통합

### 7.1 전역 알림 서비스: `lib/services/global_notification_service.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/models/leave_approval_models.dart';
import 'package:ASPN_AI_AGENT/widgets/leave_approval_notification_banner.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';

class GlobalNotificationService {
  static GlobalNotificationService? _instance;
  static GlobalNotificationService get instance => _instance ??= GlobalNotificationService._();
  GlobalNotificationService._();

  OverlayEntry? _currentOverlay;

  void showLeaveApprovalNotification({
    required BuildContext context,
    required LeaveApprovalNotification notification,
    VoidCallback? onTap,
  }) {
    // 기존 오버레이 제거
    _currentOverlay?.remove();

    // 새 오버레이 생성
    _currentOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 0,
        right: 0,
        child: LeaveApprovalNotificationBanner(
          notification: notification,
          onTap: () {
            _currentOverlay?.remove();
            _currentOverlay = null;
            onTap?.call();
          },
          onDismiss: () {
            _currentOverlay?.remove();
            _currentOverlay = null;
          },
        ),
      ),
    );

    // 오버레이 표시
    Overlay.of(context).insert(_currentOverlay!);
  }

  void hideNotification() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}

// Provider로 관리
final globalNotificationServiceProvider = Provider<GlobalNotificationService>(
  (ref) => GlobalNotificationService.instance,
);
```

### 7.2 AMQP 서비스에 전역 알림 연결

**기존 파일 수정**: `lib/shared/services/amqp_service.dart`

```dart
import 'package:ASPN_AI_AGENT/services/global_notification_service.dart';
import 'package:ASPN_AI_AGENT/models/leave_approval_models.dart';
import 'package:ASPN_AI_AGENT/ui/screens/admin_leave_approval_screen.dart';

// _handleLeaveApprovalMessage 메서드에 전역 알림 추가
void _handleLeaveApprovalMessage(
  Map<String, dynamic> data, 
  amqp.AmqpMessage originalMessage
) async {
  print('📝 [AMQP] _handleLeaveApprovalMessage() 시작');

  try {
    print('📝 [AMQP] 휴가 결재 메시지 처리 시작: $data');

    // 알림 객체 생성
    final notification = LeaveApprovalNotification.fromJson(data);

    // 전역 알림 표시 (UI 컨텍스트가 있을 때만)
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      GlobalNotificationService.instance.showLeaveApprovalNotification(
        context: context,
        notification: notification,
        onTap: () {
          // 관리자 결재 화면으로 이동
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AdminLeaveApprovalScreen(),
            ),
          );
        },
      );
    }

    // 스트림으로 데이터 전송 (관리자 화면에서 구독)
    _notifyApprovalScreenUpdate(data);

    print('✅ [AMQP] 휴가 결재 메시지 처리 완료');
    originalMessage.ack();
  } catch (e) {
    print('❌ [AMQP] 휴가 결재 메시지 처리 실패: $e');
    originalMessage.reject(true);
  }
}
```

### 7.3 메인 앱에 관리자 메뉴 추가

**기존 파일 수정**: `lib/ui/screens/chat_home_page_v5.dart` (또는 메인 네비게이션)

```dart
// 관리자 메뉴 추가 (사이드바 또는 메뉴에)
Consumer(
  builder: (context, ref, child) {
    final managerPermissionAsync = ref.watch(currentUserManagerPermissionProvider);
    
    return managerPermissionAsync.when(
      data: (isManager) => isManager 
          ? ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('휴가 결재 관리'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminLeaveApprovalScreen(),
                  ),
                );
              },
            )
          : const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  },
),
```

---

## 📋 AMQP 메시지 구조

### 휴가 신청 알림 메시지

```json
{
  "type": "leave_request",
  "timestamp": "2025-01-10T09:00:00Z",
  "data": {
    "id": "REQ_001",
    "applicant_id": "user123",
    "applicant_name": "홍길동",
    "department": "개발팀",
    "leave_type": "연차",
    "start_date": "2025-01-15",
    "end_date": "2025-01-17",
    "days": 3.0,
    "reason": "개인 휴가",
    "requested_date": "2025-01-10T09:00:00Z",
    "approver_id": "manager001",
    "status": "PENDING"
  }
}
```

### 결재 결과 알림 메시지

```json
{
  "type": "approval_result",
  "timestamp": "2025-01-10T15:30:00Z",
  "data": {
    "id": "REQ_001",
    "applicant_id": "user123",
    "applicant_name": "홍길동",
    "department": "개발팀",
    "leave_type": "연차",
    "start_date": "2025-01-15",
    "end_date": "2025-01-17",
    "days": 3.0,
    "reason": "개인 휴가",
    "requested_date": "2025-01-10T09:00:00Z",
    "approver_id": "manager001",
    "status": "APPROVED",
    "processed_date": "2025-01-10T15:30:00Z",
    "reject_reason": null
  }
}
```

---

## 🎯 구현 순서 요약

1. **Step 1**: AMQP 서비스에 `leave_approval` 큐 추가 및 메시지 핸들러 확장
2. **Step 2**: 데이터 모델 생성 (`LeaveApprovalRequest`, `LeaveApprovalNotification`)
3. **Step 3**: API 서비스로 서버 연동 (결재 대기 목록, 승인/반려 처리)
4. **Step 4**: Riverpod으로 상태 관리 구현
5. **Step 5**: UI 컴포넌트 구현 (알림 배너, 결재 요청 카드)
6. **Step 6**: 관리자 화면 완성 (탭 기반 UI, 승인/반려 기능)
7. **Step 7**: 전역 알림 시스템으로 실시간 알림 통합

---

## ✅ 완성된 기능

- ✅ **실시간 AMQP 알림**: 휴가 신청 시 부서장에게 즉시 알림
- ✅ **관리자 결재 화면**: 탭 기반의 직관적인 결재 관리 UI
- ✅ **승인/반려 처리**: 원클릭 승인, 사유 입력을 통한 반려
- ✅ **상태별 필터링**: 대기, 승인, 반려, 전체 탭으로 구분
- ✅ **실시간 UI 업데이트**: AMQP를 통한 자동 화면 갱신
- ✅ **반응형 알림 배너**: 애니메이션이 적용된 알림 UI
- ✅ **권한 기반 접근**: 관리자만 결재 화면 접근 가능

이 구현을 통해 **완전한 휴가 결재 시스템과 실시간 알림 기능**이 구축됩니다.