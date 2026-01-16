import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/features/leave/providers/leave_notification_provider.dart';
import 'package:ASPN_AI_AGENT/features/leave/widgets/leave_notification_widgets.dart';

/// 휴가 알림 오버레이 위젯
class LeaveNotificationOverlay extends ConsumerWidget {
  final NavigateToLeaveManagement onNavigateToLeaveManagement;

  const LeaveNotificationOverlay({
    Key? key,
    required this.onNavigateToLeaveManagement,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationState = ref.watch(leaveNotificationProvider);
    final notificationNotifier = ref.read(leaveNotificationProvider.notifier);

    // 알림이 없으면 빈 위젯 반환
    if (notificationState.totalNotificationCount == 0) {
      return const SizedBox.shrink();
    }

    print('🔔 [LeaveNotificationOverlay] 알림 표시 시작');

    return Positioned.fill(
      child: GestureDetector(
        // 배경 클릭 시 모든 알림 닫기
        onTap: () {
          notificationNotifier.clearAllNotifications();
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Positioned(
              top: 60, // 상단 여백 (앱바 아래)
              right: 0,
              child: IgnorePointer(
                ignoring: false, // 알림은 클릭 가능하게 변경
                child: SafeArea(
                  child: SizedBox(
                    width: 380,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 결재 결과 알림들 (최대 3개만 표시)
                        ...(() {
                          if (notificationState.alertMessages.isNotEmpty) {
                            print(
                                '📋 [LeaveNotificationOverlay] 결재 결과 알림 ${notificationState.alertMessages.take(3).length}개 표시');
                          }
                          return notificationState.alertMessages
                              .take(3)
                              .map((message) {
                            return IgnorePointer(
                              ignoring: false, // 알림 카드는 클릭 가능
                              child: LeaveAlertNotificationWidget(
                                alertMessage: message,
                                onTap: () {
                                  // 클릭 시 바로 닫기
                                  notificationNotifier
                                      .removeAlertMessage(message);
                                },
                                onDismiss: () {
                                  notificationNotifier
                                      .removeAlertMessage(message);
                                },
                              ),
                            );
                          }).toList();
                        })(),

                        // 참조 알림들 (최대 3개만 표시)
                        ...(() {
                          if (notificationState.ccMessages.isNotEmpty) {
                            print(
                                '👥 [LeaveNotificationOverlay] 참조 알림 ${notificationState.ccMessages.take(3).length}개 표시');
                          }
                          return notificationState.ccMessages
                              .take(3)
                              .map((message) {
                            return IgnorePointer(
                              ignoring: false, // 알림 카드는 클릭 가능
                              child: LeaveCCNotificationWidget(
                                ccMessage: message,
                                onTap: () {
                                  // 클릭 시 바로 닫기
                                  notificationNotifier.removeCCMessage(message);
                                },
                                onDismiss: () {
                                  notificationNotifier.removeCCMessage(message);
                                },
                              ),
                            );
                          }).toList();
                        })(),

                        // 일반 전자결재 알림은 표시하지 않음 (요청사항)
                        ...(() {
                          if (notificationState.eapprovalMessages.isNotEmpty) {
                            print(
                                '🚫 [LeaveNotificationOverlay] 일반 전자결재 알림 ${notificationState.eapprovalMessages.length}개 있지만 표시하지 않음');
                          }
                          return [];
                        })(),

                        // 전자결재 참조(CC) 알림들 (최대 3개만 표시)
                        ...(() {
                          if (notificationState
                              .eapprovalCCMessages.isNotEmpty) {
                            print(
                                '🟠 [LeaveNotificationOverlay] 전자결재 CC 알림 ${notificationState.eapprovalCCMessages.take(3).length}개 표시');
                          }
                          return notificationState.eapprovalCCMessages
                              .take(3)
                              .map((message) {
                            return IgnorePointer(
                              ignoring: false, // 알림 카드는 클릭 가능
                              child: EApprovalCCNotificationWidget(
                                ccMessage: message,
                                onTap: () {
                                  // 클릭 시 바로 닫기
                                  notificationNotifier
                                      .removeEApprovalCCMessage(message);
                                },
                                onDismiss: () {
                                  notificationNotifier
                                      .removeEApprovalCCMessage(message);
                                },
                              ),
                            );
                          }).toList();
                        })(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 알림 개수 배지
class NotificationBadge extends ConsumerWidget {
  final Widget child;

  const NotificationBadge({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationCount = ref.watch(leaveNotificationProvider
        .select((state) => state.totalNotificationCount));

    if (notificationCount == 0) {
      return child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(
              minWidth: 20,
              minHeight: 20,
            ),
            child: Text(
              notificationCount > 99 ? '99+' : notificationCount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

/// 알림 센터 드로어 (선택적)
class LeaveNotificationCenter extends ConsumerWidget {
  final NavigateToLeaveManagement onNavigateToLeaveManagement;

  const LeaveNotificationCenter({
    Key? key,
    required this.onNavigateToLeaveManagement,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationState = ref.watch(leaveNotificationProvider);
    final notificationNotifier = ref.read(leaveNotificationProvider.notifier);

    return Container(
      width: 400,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: const Border(
                bottom: BorderSide(color: Colors.grey, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications, size: 24),
                const SizedBox(width: 12),
                const Text(
                  '휴가 알림',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (notificationState.totalNotificationCount > 0) ...[
                  TextButton(
                    onPressed: () {
                      notificationNotifier.clearAllNotifications();
                    },
                    child: const Text('모두 지우기'),
                  ),
                ],
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // 알림 목록
          Expanded(
            child: notificationState.totalNotificationCount == 0
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '새로운 알림이 없습니다',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      // 결재 결과 알림들
                      if (notificationState.alertMessages.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            '결재 결과',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        ...notificationState.alertMessages.map((message) {
                          return LeaveAlertNotificationWidget(
                            alertMessage: message,
                            onTap: () {
                              // 클릭 시 바로 닫기
                              notificationNotifier.removeAlertMessage(message);
                            },
                            onDismiss: () {
                              notificationNotifier.removeAlertMessage(message);
                            },
                          );
                        }).toList(),
                      ],

                      // 참조 알림들
                      if (notificationState.ccMessages.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            '참조 알림',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        ...notificationState.ccMessages.map((message) {
                          return LeaveCCNotificationWidget(
                            ccMessage: message,
                            onTap: () {
                              // 클릭 시 바로 닫기
                              notificationNotifier.removeCCMessage(message);
                            },
                            onDismiss: () {
                              notificationNotifier.removeCCMessage(message);
                            },
                          );
                        }).toList(),
                      ],

                      // 전자결재 참조(CC) 알림들
                      if (notificationState.eapprovalCCMessages.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            '전자결재 참조 알림',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        ...notificationState.eapprovalCCMessages.map((message) {
                          return EApprovalCCNotificationWidget(
                            ccMessage: message,
                            onTap: () {
                              // 클릭 시 바로 닫기
                              notificationNotifier
                                  .removeEApprovalCCMessage(message);
                            },
                            onDismiss: () {
                              notificationNotifier
                                  .removeEApprovalCCMessage(message);
                            },
                          );
                        }).toList(),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
