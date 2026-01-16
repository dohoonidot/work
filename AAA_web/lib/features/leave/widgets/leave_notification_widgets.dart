import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ASPN_AI_AGENT/features/leave/services/leave_realtime_service.dart';

/// 휴가 결재 결과 알림 위젯 (승인/반려)
class LeaveAlertNotificationWidget extends StatefulWidget {
  final LeaveAlertMessage alertMessage;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  const LeaveAlertNotificationWidget({
    Key? key,
    required this.alertMessage,
    required this.onTap,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<LeaveAlertNotificationWidget> createState() =>
      _LeaveAlertNotificationWidgetState();
}

class _LeaveAlertNotificationWidgetState
    extends State<LeaveAlertNotificationWidget> {
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    // 5초 후 자동으로 사라짐
    _autoCloseTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && widget.onDismiss != null) {
        widget.onDismiss!();
      }
    });
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isApproved = widget.alertMessage.isApproved;
    final isCancelResult = widget.alertMessage.isCancelResult;

    // 밝은 색상으로 변경
    final backgroundColor = isApproved
        ? const Color(0xFFD1F2EB) // 밝은 민트색 (승인)
        : const Color(0xFFF8D7DA); // 밝은 분홍색 (반려)

    final iconColor = isApproved
        ? const Color(0xFF0F9D58) // 진한 초록 (승인)
        : const Color(0xFFD32F2F); // 진한 빨강 (반려)

    // 취소 상신 결과인지 일반 결재 결과인지에 따라 타이틀 변경
    final title = isCancelResult
        ? (isApproved ? '휴가 취소 승인' : '휴가 취소 반려')
        : (isApproved ? '휴가 승인' : '휴가 반려');

    final icon = isApproved ? Icons.check_circle : Icons.cancel;

    return GestureDetector(
      // 어디를 눌러도 닫히도록 onDismiss 우선 호출, 없으면 onTap 호출
      onTap: () {
        if (widget.onDismiss != null) {
          widget.onDismiss!();
        } else {
          widget.onTap();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(
          maxWidth: 360, // 최대 너비 제한
          minHeight: 70, // 최소 높이 축소
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!isApproved &&
                      widget.alertMessage.rejectMessage != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.alertMessage.rejectMessage!,
                      style: TextStyle(
                        color: iconColor.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (widget.onDismiss != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onDismiss,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    color: iconColor.withValues(alpha: 0.5),
                    size: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 휴가 참조 알림 위젯
class LeaveCCNotificationWidget extends StatefulWidget {
  final LeaveCCMessage ccMessage;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  const LeaveCCNotificationWidget({
    Key? key,
    required this.ccMessage,
    required this.onTap,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<LeaveCCNotificationWidget> createState() =>
      _LeaveCCNotificationWidgetState();
}

class _LeaveCCNotificationWidgetState extends State<LeaveCCNotificationWidget> {
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    // 5초 후 자동으로 사라짐
    _autoCloseTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && widget.onDismiss != null) {
        widget.onDismiss!();
      }
    });
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 밝은 보라색으로 변경
    const backgroundColor = Color(0xFFEDE7F6); // 밝은 보라색 배경
    const iconColor = Color(0xFF673AB7); // 진한 보라색 아이콘

    return GestureDetector(
      // 어디를 눌러도 닫히도록 onDismiss 우선 호출, 없으면 onTap 호출
      onTap: () {
        if (widget.onDismiss != null) {
          widget.onDismiss!();
        } else {
          widget.onTap();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(
          maxWidth: 360, // 최대 너비 제한
          minHeight: 70, // 최소 높이 축소
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.notifications_active,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '참조자 알림',
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.ccMessage.name} • ${widget.ccMessage.leaveType}',
                    style: TextStyle(
                      color: iconColor.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.ccMessage.formattedPeriod.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.ccMessage.formattedPeriod,
                      style: TextStyle(
                        color: iconColor.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (widget.onDismiss != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onDismiss,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    color: iconColor.withValues(alpha: 0.5),
                    size: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 전자결재 참조(CC) 알림 위젯
class EApprovalCCNotificationWidget extends StatefulWidget {
  final LeaveEApprovalMessage ccMessage;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  const EApprovalCCNotificationWidget({
    Key? key,
    required this.ccMessage,
    required this.onTap,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<EApprovalCCNotificationWidget> createState() =>
      _EApprovalCCNotificationWidgetState();
}

class _EApprovalCCNotificationWidgetState
    extends State<EApprovalCCNotificationWidget> {
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    // 5초 후 자동으로 사라짐
    _autoCloseTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && widget.onDismiss != null) {
        widget.onDismiss!();
      }
    });
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 밝은 오렌지색으로 변경
    const backgroundColor = Color(0xFFFFF3E0); // 밝은 오렌지 배경
    const iconColor = Color(0xFFFF9800); // 진한 오렌지 아이콘

    return GestureDetector(
      onTap: () {
        if (widget.onDismiss != null) {
          widget.onDismiss!();
        } else {
          widget.onTap();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(
          maxWidth: 360,
          minHeight: 70,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.mark_email_read,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '결재 참조 알림',
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.ccMessage.name} • ${widget.ccMessage.department}',
                    style: TextStyle(
                      color: iconColor.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.ccMessage.title.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.ccMessage.title,
                      style: TextStyle(
                        color: iconColor.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (widget.onDismiss != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onDismiss,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    color: iconColor.withValues(alpha: 0.5),
                    size: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 휴가 결재 결과 상세 다이얼로그
class LeaveAlertDetailDialog extends StatelessWidget {
  final LeaveAlertMessage alertMessage;
  final VoidCallback onNavigateToLeaveManagement;

  const LeaveAlertDetailDialog({
    Key? key,
    required this.alertMessage,
    required this.onNavigateToLeaveManagement,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isApproved = alertMessage.isApproved;
    final isCancelResult = alertMessage.isCancelResult;

    final backgroundColor =
        isApproved ? const Color(0xFF20C997) : const Color(0xFFDC3545);

    // 취소 상신 결과인지 일반 결재 결과인지에 따라 타이틀 변경
    final title = isCancelResult
        ? (isApproved ? '휴가 취소 승인됨' : '휴가 취소 반려됨')
        : (isApproved ? '휴가 승인됨' : '휴가 반려됨');

    final icon = isApproved ? Icons.check_circle : Icons.cancel;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 아이콘과 제목
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    color: backgroundColor,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      color: backgroundColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 상세 정보
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isApproved)
                    Text(
                      isCancelResult ? '휴가 취소 신청이 승인되었습니다.' : '휴가 신청이 승인되었습니다.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    )
                  else if (alertMessage.rejectMessage != null) ...[
                    const Text(
                      '반려 사유:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alertMessage.rejectMessage!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 버튼들
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      '닫기',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onNavigateToLeaveManagement();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: backgroundColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '휴가관리 페이지',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 휴가 참조 알림 상세 다이얼로그
class LeaveCCDetailDialog extends StatelessWidget {
  final LeaveCCMessage ccMessage;
  final VoidCallback onNavigateToLeaveManagement;

  const LeaveCCDetailDialog({
    Key? key,
    required this.ccMessage,
    required this.onNavigateToLeaveManagement,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 아이콘과 제목
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.notifications_active,
                    color: Color(0xFF6C5CE7),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '참조자 알림',
                    style: TextStyle(
                      color: Color(0xFF6C5CE7),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 상세 정보
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('신청자', ccMessage.name),
                  const SizedBox(height: 8),
                  _buildInfoRow('부서', ccMessage.department),
                  const SizedBox(height: 8),
                  _buildInfoRow('휴가 유형', ccMessage.leaveType),
                  const SizedBox(height: 8),
                  _buildInfoRow('휴가 기간', ccMessage.formattedPeriod),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 버튼들
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      '닫기',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onNavigateToLeaveManagement();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '휴가관리 페이지',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
