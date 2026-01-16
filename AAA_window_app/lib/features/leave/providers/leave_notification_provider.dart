import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/features/leave/services/leave_realtime_service.dart';
import 'package:ASPN_AI_AGENT/features/leave/widgets/leave_notification_widgets.dart';

/// 휴가 알림 상태
class LeaveNotificationState {
  final List<LeaveAlertMessage> alertMessages;
  final List<LeaveCCMessage> ccMessages;
  final List<LeaveEApprovalMessage> eapprovalMessages;
  final List<LeaveEApprovalMessage> eapprovalCCMessages;
  final bool isListening;

  const LeaveNotificationState({
    this.alertMessages = const [],
    this.ccMessages = const [],
    this.eapprovalMessages = const [],
    this.eapprovalCCMessages = const [],
    this.isListening = false,
  });

  LeaveNotificationState copyWith({
    List<LeaveAlertMessage>? alertMessages,
    List<LeaveCCMessage>? ccMessages,
    List<LeaveEApprovalMessage>? eapprovalMessages,
    List<LeaveEApprovalMessage>? eapprovalCCMessages,
    bool? isListening,
  }) {
    return LeaveNotificationState(
      alertMessages: alertMessages ?? this.alertMessages,
      ccMessages: ccMessages ?? this.ccMessages,
      eapprovalMessages: eapprovalMessages ?? this.eapprovalMessages,
      eapprovalCCMessages: eapprovalCCMessages ?? this.eapprovalCCMessages,
      isListening: isListening ?? this.isListening,
    );
  }

  int get totalNotificationCount =>
      alertMessages.length +
      ccMessages.length +
      eapprovalMessages.length +
      eapprovalCCMessages.length;
}

/// 휴가 알림 관리 Notifier
class LeaveNotificationNotifier extends StateNotifier<LeaveNotificationState> {
  LeaveNotificationNotifier() : super(const LeaveNotificationState());

  StreamSubscription<LeaveAlertMessage>? _alertSubscription;
  StreamSubscription<LeaveCCMessage>? _ccSubscription;
  StreamSubscription<LeaveEApprovalMessage>? _eapprovalSubscription;

  /// 알림 스트림 구독 시작
  void startListening() {
    if (state.isListening) return;

    print('📱 휴가 알림 스트림 구독 시작');

    // 결재 결과 알림 구독
    _alertSubscription =
        LeaveApprovalRealtimeService.instance.alertMessageStream.listen(
      (alertMessage) {
        print('📱 새로운 결재 결과 알림 수신: ${alertMessage.status}');
        _addAlertMessage(alertMessage);
      },
      onError: (error) {
        print('❌ 결재 결과 알림 스트림 오류: $error');
      },
    );

    // 참조 알림 구독
    print('🔄 참조 알림 스트림 구독 시작...');
    _ccSubscription =
        LeaveApprovalRealtimeService.instance.ccMessageStream.listen(
      (ccMessage) {
        print(
            '📱📱📱 [UI Provider] 새로운 참조 알림 수신: ${ccMessage.name}님의 ${ccMessage.leaveType}');
        print('📱 [UI Provider] CC 메시지 상세:');
        print('   - 이름: ${ccMessage.name}');
        print('   - 부서: ${ccMessage.department}');
        print('   - 휴가 유형: ${ccMessage.leaveType}');
        print('   - 기간: ${ccMessage.formattedPeriod}');
        _addCCMessage(ccMessage);
        print('📱 [UI Provider] CC 메시지 Provider 추가 완료');
      },
      onError: (error) {
        print('❌ [UI Provider] 참조 알림 스트림 오류: $error');
      },
    );
    print('✅ 참조 알림 스트림 구독 완료');

    // 전자결재 알림 구독
    print('🔄 전자결재 알림 스트림 구독 시작...');
    _eapprovalSubscription =
        LeaveApprovalRealtimeService.instance.eapprovalMessageStream.listen(
      (eapprovalMessage) {
        print(
            '📱 [UI Provider] 새로운 전자결재 알림 수신: ${eapprovalMessage.name}님 - ${eapprovalMessage.title}');
        print('📱 [UI Provider] 전자결재 메시지 상세:');
        print('   - 이름: ${eapprovalMessage.name}');
        print('   - 부서: ${eapprovalMessage.department}');
        print('   - 제목: ${eapprovalMessage.title}');
        print('   - 타입: ${eapprovalMessage.approvalType}');
        _addEApprovalMessage(eapprovalMessage);
        print('📱 [UI Provider] 전자결재 메시지 Provider 추가 완료');
      },
      onError: (error) {
        print('❌ [UI Provider] 전자결재 알림 스트림 오류: $error');
      },
    );
    print('✅ 전자결재 알림 스트림 구독 완료');

    state = state.copyWith(isListening: true);
  }

  /// 알림 스트림 구독 중지
  void stopListening() {
    if (!state.isListening) return;

    print('📱 휴가 알림 스트림 구독 중지');

    // 안전한 구독 해제
    _alertSubscription?.cancel();
    _ccSubscription?.cancel();
    _eapprovalSubscription?.cancel();
    _alertSubscription = null;
    _ccSubscription = null;
    _eapprovalSubscription = null;

    // mounted 체크 후 상태 업데이트
    if (mounted) {
      state = state.copyWith(isListening: false);
    }
  }

  /// 결재 결과 알림 추가
  void _addAlertMessage(LeaveAlertMessage message) {
    final updatedMessages = [...state.alertMessages, message];
    state = state.copyWith(alertMessages: updatedMessages);
  }

  /// 참조 알림 추가
  void _addCCMessage(LeaveCCMessage message) {
    print('🔄 [UI Provider] CC 메시지 State에 추가 중...');
    print('   - 현재 CC 메시지 개수: ${state.ccMessages.length}');
    final updatedMessages = [...state.ccMessages, message];
    state = state.copyWith(ccMessages: updatedMessages);
    print('✅ [UI Provider] CC 메시지 State 업데이트 완료');
    print('   - 업데이트 후 CC 메시지 개수: ${state.ccMessages.length}');
    print('   - 전체 알림 개수: ${state.totalNotificationCount}');
  }

  /// 전자결재 알림 추가
  void _addEApprovalMessage(LeaveEApprovalMessage message) {
    print('🔄 [UI Provider] 전자결재 메시지 State에 추가 중...');
    print('   - approvalType: ${message.approvalType}');

    // approvalType이 'eapproval_cc'인 경우 별도 리스트에 추가
    if (message.approvalType == 'eapproval_cc') {
      print('   - eapproval.cc 메시지로 분류');
      print('   - 현재 eapprovalCC 메시지 개수: ${state.eapprovalCCMessages.length}');
      final updatedMessages = [...state.eapprovalCCMessages, message];
      state = state.copyWith(eapprovalCCMessages: updatedMessages);
      print('✅ [UI Provider] eapprovalCC 메시지 State 업데이트 완료');
      print('   - 업데이트 후 eapprovalCC 메시지 개수: ${state.eapprovalCCMessages.length}');
    } else {
      print('   - 일반 eapproval 메시지로 분류');
      print('   - 현재 eapproval 메시지 개수: ${state.eapprovalMessages.length}');
      final updatedMessages = [...state.eapprovalMessages, message];
      state = state.copyWith(eapprovalMessages: updatedMessages);
      print('✅ [UI Provider] eapproval 메시지 State 업데이트 완료');
      print('   - 업데이트 후 eapproval 메시지 개수: ${state.eapprovalMessages.length}');
    }
    print('   - 전체 알림 개수: ${state.totalNotificationCount}');
  }

  /// 결재 결과 알림 제거
  void removeAlertMessage(LeaveAlertMessage message) {
    final updatedMessages = state.alertMessages
        .where((m) =>
            m.status != message.status ||
            m.rejectMessage != message.rejectMessage)
        .toList();
    state = state.copyWith(alertMessages: updatedMessages);
  }

  /// 참조 알림 제거
  void removeCCMessage(LeaveCCMessage message) {
    final updatedMessages = state.ccMessages
        .where((m) =>
            m.name != message.name ||
            m.leaveType != message.leaveType ||
            m.startDate != message.startDate)
        .toList();
    state = state.copyWith(ccMessages: updatedMessages);
  }

  /// 전자결재 알림 제거
  void removeEApprovalMessage(LeaveEApprovalMessage message) {
    final updatedMessages = state.eapprovalMessages
        .where((m) =>
            m.name != message.name ||
            m.department != message.department ||
            m.title != message.title)
        .toList();
    state = state.copyWith(eapprovalMessages: updatedMessages);
  }

  /// 전자결재 참조(CC) 알림 제거
  void removeEApprovalCCMessage(LeaveEApprovalMessage message) {
    final updatedMessages = state.eapprovalCCMessages
        .where((m) =>
            m.name != message.name ||
            m.department != message.department ||
            m.title != message.title)
        .toList();
    state = state.copyWith(eapprovalCCMessages: updatedMessages);
  }

  /// 모든 알림 제거
  void clearAllNotifications() {
    state = state.copyWith(
      alertMessages: [],
      ccMessages: [],
      eapprovalMessages: [],
      eapprovalCCMessages: [],
    );
  }

  /// 결재 결과 알림만 제거
  void clearAlertMessages() {
    state = state.copyWith(alertMessages: []);
  }

  /// 참조 알림만 제거
  void clearCCMessages() {
    state = state.copyWith(ccMessages: []);
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}

/// 휴가 알림 Provider
final leaveNotificationProvider =
    StateNotifierProvider<LeaveNotificationNotifier, LeaveNotificationState>(
        (ref) {
  return LeaveNotificationNotifier();
});

/// 휴가 관리 페이지로 네비게이션하는 함수
typedef NavigateToLeaveManagement = void Function();

/// 휴가 알림 UI 관리자
class LeaveNotificationManager {
  static void showAlertDetail(
    BuildContext context,
    LeaveAlertMessage message,
    NavigateToLeaveManagement onNavigate,
  ) {
    showDialog(
      context: context,
      builder: (context) => LeaveAlertDetailDialog(
        alertMessage: message,
        onNavigateToLeaveManagement: onNavigate,
      ),
    );
  }

  static void showCCDetail(
    BuildContext context,
    LeaveCCMessage message,
    NavigateToLeaveManagement onNavigate,
  ) {
    showDialog(
      context: context,
      builder: (context) => LeaveCCDetailDialog(
        ccMessage: message,
        onNavigateToLeaveManagement: onNavigate,
      ),
    );
  }
}
