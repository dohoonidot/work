// filepath: /c:/AI_Agent/AI_Agent/Agent_APP/Desktop_App_v6/lib/provider/notification_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'dart:async';
// import 'dart:math';
import 'dart:typed_data';
import 'package:ASPN_AI_AGENT/shared/services/api_service.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart'; // amqpServiceProvider import 추가
// import '../local/database_helper.dart';
import 'package:flutter/widgets.dart'; // BuildContext import 추가
import 'package:ASPN_AI_AGENT/features/gift/select_gift.dart'; // SelectGift import 추가

// 알림 메시지 데이터 모델
class NotificationMessage {
  final String id;
  final String userId;
  final String topic;
  final String title;
  final String summary;
  final String? fullContent;
  final MessageType type;
  final MessageStatus status;
  final MessagePriority priority;
  final DateTime receivedAt;
  final DateTime? readAt;
  // 생일 메시지 관련 필드
  final Uint8List? couponImage; // 쿠폰 이미지 바이트 데이터
  final bool isBirthMessage; // 생일 메시지 여부
  final String? couponImgUrl; // 쿠폰 이미지 URL
  final String? sendTime; // 전송 시간 (원본 형식)
  final String? couponEndDate; // 쿠폰 만료 기간
  final bool isNew; // NEW 표시 여부 (새로 추가)

  NotificationMessage({
    required this.id,
    required this.userId,
    required this.topic,
    required this.title,
    required this.summary,
    this.fullContent,
    required this.type,
    this.status = MessageStatus.unread,
    this.priority = MessagePriority.normal,
    required this.receivedAt,
    this.readAt,
    this.couponImage,
    this.isBirthMessage = false,
    this.couponImgUrl,
    this.sendTime,
    this.couponEndDate,
    this.isNew = false, // 새로 추가
  });

  // JSON 변환
  factory NotificationMessage.fromJson(Map<String, dynamic> json) {
    return NotificationMessage(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      topic: json['topic'] ?? '',
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      fullContent: json['full_content'],
      type: MessageType.values.firstWhere(
        (e) => e.name == json['message_type'],
        orElse: () => MessageType.system,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.unread,
      ),
      priority: MessagePriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => MessagePriority.normal,
      ),
      receivedAt: DateTime.parse(json['received_at']),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      // 생일 메시지 관련 필드들 추가
      isBirthMessage:
          json['topic'] == 'birthday' || json['isBirthMessage'] == true,
      couponImgUrl: json['couponImgUrl'],
      sendTime: json['send_time'],
      couponEndDate: json['coupon_end_date'],
      isNew: json['is_new'] ?? false, // 새로 추가
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'topic': topic,
      'title': title,
      'summary': summary,
      'full_content': fullContent,
      'message_type': type.name,
      'status': status.name,
      'priority': priority.name,
      'received_at': receivedAt.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
      'is_new': isNew, // 새로 추가
    };
  }

  // 복사본 생성 (상태 변경용)
  NotificationMessage copyWith({
    String? id,
    String? userId,
    String? topic,
    String? title,
    String? summary,
    String? fullContent,
    MessageType? type,
    MessageStatus? status,
    MessagePriority? priority,
    DateTime? receivedAt,
    DateTime? readAt,
    Uint8List? couponImage,
    bool? isBirthMessage,
    String? couponImgUrl,
    String? sendTime,
    String? couponEndDate,
    bool? isNew, // 새로 추가
  }) {
    return NotificationMessage(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      topic: topic ?? this.topic,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      fullContent: fullContent ?? this.fullContent,
      type: type ?? this.type,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      receivedAt: receivedAt ?? this.receivedAt,
      readAt: readAt ?? this.readAt,
      couponImage: couponImage ?? this.couponImage,
      isBirthMessage: isBirthMessage ?? this.isBirthMessage,
      couponImgUrl: couponImgUrl ?? this.couponImgUrl,
      sendTime: sendTime ?? this.sendTime,
      couponEndDate: couponEndDate ?? this.couponEndDate,
      isNew: isNew ?? this.isNew, // 새로 추가
    );
  }
}

// 메시지 타입 열거형
enum MessageType {
  birthday, // 생일 알림
  gift, // 선물 메시지
  system, // 시스템 알림
  event, // 이벤트 알림
  reminder, // 리마인더
  announcement // 공지사항
}

// 메시지 상태 열거형
enum MessageStatus {
  unread, // 미읽음
  read, // 읽음
  deleted // 삭제됨
}

// 메시지 우선순위 열거형
enum MessagePriority {
  normal, // 보통
  important, // 중요
  urgent // 긴급
}

// 알림 상태 클래스
class NotificationState {
  final List<NotificationMessage> notifications;
  final List<Map<String, dynamic>> serverAlerts; // 서버에서 받아온 알림 데이터
  final bool isConnected; // AMQP 연결 상태 (bool 값)
  final int unreadCount;
  final bool isModalVisible;
  final NotificationMessage? selectedMessage; // 선택된 메시지
  final bool isDetailModalVisible; // 메시지 상세 모달 표시 여부
  final bool hasNewGift; // 새 선물 표시 여부

  NotificationState({
    this.notifications = const [],
    this.serverAlerts = const [],
    this.isConnected = false, // 초기값: 연결되지 않음
    this.unreadCount = 0,
    this.isModalVisible = false,
    this.selectedMessage,
    this.isDetailModalVisible = false,
    this.hasNewGift = false,
  });

  NotificationState copyWith({
    List<NotificationMessage>? notifications,
    List<Map<String, dynamic>>? serverAlerts,
    bool? isConnected, // bool 타입으로 변경
    int? unreadCount,
    bool? isModalVisible,
    NotificationMessage? selectedMessage,
    bool? isDetailModalVisible,
    bool? hasNewGift,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      serverAlerts: serverAlerts ?? this.serverAlerts,
      isConnected: isConnected ?? this.isConnected, // 필드명 변경
      unreadCount: unreadCount ?? this.unreadCount,
      isModalVisible: isModalVisible ?? this.isModalVisible,
      selectedMessage: selectedMessage ?? this.selectedMessage,
      isDetailModalVisible: isDetailModalVisible ?? this.isDetailModalVisible,
      hasNewGift: hasNewGift ?? this.hasNewGift,
    );
  }
}

// 알림 Notifier
class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier() : super(NotificationState());

  // 서버에서 받아온 알림 데이터 업데이트
  void updateServerAlerts(List<Map<String, dynamic>> alerts) {
    // is_read가 false이고 is_deleted가 false인 알림만 카운트
    final unreadCount = alerts
        .where(
            (alert) => alert['is_read'] != true && alert['is_deleted'] != true)
        .length;

    state = state.copyWith(
      serverAlerts: alerts,
      unreadCount: unreadCount,
    );
    print('📊 서버 알림 데이터 업데이트: ${alerts.length}개, 읽지 않음: $unreadCount개');
  }

  // 서버 API를 통한 알림 읽음 처리
  Future<void> markAsReadWithAPI(String userId, int alertId) async {
    try {
      // 서버 API 호출하여 읽음 처리
      final response = await ApiService.updateAlerts(userId, alertId);

      // 서버에서 업데이트된 알림 데이터 받기
      final alerts = response['alerts'] as List<dynamic>? ?? [];
      final alertsList = alerts.cast<Map<String, dynamic>>();

      // 서버 알림 데이터 업데이트 (읽지 않은 수 자동 재계산)
      updateServerAlerts(alertsList);

      print('✅ 알림 읽음 처리 완료: $alertId');
    } catch (e) {
      print('❌ 알림 읽음 처리 실패: $e');
      throw e;
    }
  }

  // 서버 API를 통한 알림 삭제
  Future<void> deleteAlertWithAPI(String userId, int alertId) async {
    try {
      // 서버 API 호출하여 삭제 처리
      final response = await ApiService.deleteAlerts(userId, alertId);

      // 서버에서 업데이트된 알림 데이터 받기
      final alerts = response['alerts'] as List<dynamic>? ?? [];
      final alertsList = alerts.cast<Map<String, dynamic>>();

      // 서버 알림 데이터 업데이트 (읽지 않은 수 자동 재계산)
      updateServerAlerts(alertsList);

      print('✅ 알림 삭제 완료: $alertId');
    } catch (e) {
      print('❌ 알림 삭제 실패: $e');
      throw e;
    }
  }

  // 모든 알림 삭제
  void clearAllNotifications() {
    state = state.copyWith(
      serverAlerts: [],
      unreadCount: 0,
    );
    print('🗑️ 모든 알림 삭제 완료');
  }

  // 새 선물 표시 설정
  void setNewGiftIndicator(bool hasNew) {
    state = state.copyWith(hasNewGift: hasNew);
  }

  // 선물함 클릭 시 새 선물 표시 제거
  void clearNewGiftIndicator() {
    state = state.copyWith(hasNewGift: false);
  }

  // 알림함에서 선물 고르기 버튼 클릭 시 호출되는 메서드
  void showGiftSelectionFromAlert(
      BuildContext context, String userId, int alertId, String queueName,
      {int? realTimeId}) {
    print('🔔 [NOTIFICATION] ===== 알림함에서 선물 고르기 시작 =====');
    print('🔔 [NOTIFICATION] 입력 파라미터:');
    print('   - userId: $userId');
    print('   - alertId: $alertId (타입: ${alertId.runtimeType})');
    print('   - realTimeId: $realTimeId (타입: ${realTimeId.runtimeType})');
    print('   - queueName: $queueName');
    print('🔔 [NOTIFICATION] 알림함에서 alertId로 선물 고르기 - alertId: $alertId');
    print('🔔 [NOTIFICATION] SelectGift.showGiftSelectionModal 호출');
    SelectGift.showGiftSelectionModal(context, userId,
        alertId: alertId, realTimeId: realTimeId, queueName: queueName);
    print('🔔 [NOTIFICATION] ===== 알림함에서 선물 고르기 완료 =====');
  }

  // 특정 선물의 NEW 표시 제거 (기존 로컬 알림용 - 현재 사용되지 않음)
  void removeNewLabel(String messageId) {
    final updatedNotifications = state.notifications.map((notification) {
      if (notification.id == messageId) {
        return notification.copyWith(isNew: false);
      }
      return notification;
    }).toList();

    state = state.copyWith(notifications: updatedNotifications);
  }

  // 알림 모달 표시/숨김
  void toggleModal() {
    state = state.copyWith(
      isModalVisible: !state.isModalVisible,
    );
  }

  // 메시지 클릭 시 읽음 처리 + 상세 모달 표시
  void showMessageDetail(String messageId) {
    // 해당 메시지 찾기
    final message = state.notifications.firstWhere(
      (notification) => notification.id == messageId,
      orElse: () => throw Exception('메시지를 찾을 수 없습니다: $messageId'),
    );

    // 읽음 처리
    final updatedNotifications = state.notifications.map((notification) {
      if (notification.id == messageId &&
          notification.status == MessageStatus.unread) {
        return notification.copyWith(
          status: MessageStatus.read,
          readAt: DateTime.now(),
        );
      }
      return notification;
    }).toList();

    final unreadCount = updatedNotifications
        .where((n) => n.status == MessageStatus.unread)
        .length;

    // 상태 업데이트 (읽음 처리 + 상세 모달 표시)
    state = state.copyWith(
      notifications: updatedNotifications,
      unreadCount: unreadCount,
      selectedMessage: message.copyWith(
        status: MessageStatus.read,
        readAt: DateTime.now(),
      ),
      isDetailModalVisible: true,
    );

    print('메시지 상세 보기: ${message.title}');
  }

  // 메시지 상세 모달 닫기
  void hideMessageDetail() {
    state = state.copyWith(
      selectedMessage: null,
      isDetailModalVisible: false,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// Provider 정의
final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>(
  (ref) => NotificationNotifier(),
);

// 읽지 않은 알림 수 Provider
final unreadCountProvider = Provider<int>((ref) {
  final notificationState = ref.watch(notificationProvider);
  return notificationState.unreadCount;
});

final connectionStatusProvider = Provider<bool>((ref) {
  // amqpService의 연결 상태를 직접 watch하여 제공합니다.
  final isConnected = ref.watch(amqpServiceProvider).isConnected;
  return isConnected;
});

// 전체 읽지 않은 알림 수 (일반 알림 + 생일 메시지)
final totalUnreadCountProvider = Provider<int>((ref) {
  final notificationState = ref.watch(notificationProvider);
  return notificationState.unreadCount;
});

// 선택된 메시지 Provider
final selectedMessageProvider = Provider<NotificationMessage?>((ref) {
  final notificationState = ref.watch(notificationProvider);
  return notificationState.selectedMessage;
});

// 메시지 상세 모달 표시 여부 Provider
final isDetailModalVisibleProvider = Provider<bool>((ref) {
  final notificationState = ref.watch(notificationProvider);
  return notificationState.isDetailModalVisible;
});
