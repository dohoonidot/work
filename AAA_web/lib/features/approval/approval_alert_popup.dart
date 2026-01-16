import 'package:flutter/material.dart';
import 'package:ASPN_AI_AGENT/ui/screens/electronic_approval_management_screen.dart';
import 'package:ASPN_AI_AGENT/ui/screens/vacation_management_webview_screen.dart';

/// 컴팩트한 전자결재 알림 위젯
class ApprovalAlertPopup extends StatefulWidget {
  final String title;
  final String status; // APPROVED 또는 REJECTED
  final String? comment; // 반려 시 코멘트 (optional)
  final String? approvalType; // eapproval.userId 큐의 approval_type
  final VoidCallback? onDismiss; // 닫기 콜백 추가

  const ApprovalAlertPopup({
    super.key,
    required this.title,
    required this.status,
    this.comment,
    this.approvalType,
    this.onDismiss,
  });

  @override
  State<ApprovalAlertPopup> createState() => _ApprovalAlertPopupState();
}

class _ApprovalAlertPopupState extends State<ApprovalAlertPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // 오른쪽에서 시작
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse();
    if (mounted) {
      Navigator.of(context).pop();
      widget.onDismiss?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isApproved = widget.status == 'APPROVED';

    // 밝은 색상으로 변경
    final backgroundColor = isApproved
        ? const Color(0xFFD1F2EB) // 밝은 민트색 (승인)
        : const Color(0xFFF8D7DA); // 밝은 분홍색 (반려)

    final iconColor = isApproved
        ? const Color(0xFF0F9D58) // 진한 초록 (승인)
        : const Color(0xFFD32F2F); // 진한 빨강 (반려)

    final statusText = isApproved ? '결재 승인' : '결재 반려';
    final icon = isApproved ? Icons.check_circle : Icons.cancel;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: _dismiss, // 클릭 시 바로 닫기
          child: Container(
            margin: const EdgeInsets.only(top: 8, right: 16, left: 16),
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
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // 아이콘
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
                  // 텍스트
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(
                            color: iconColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: iconColor.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // 닫기 버튼
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _dismiss,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 전자결재 알림 상세 다이얼로그
class ApprovalAlertDetailDialog extends StatelessWidget {
  final String title;
  final String status;
  final String? comment;
  final String? approvalType;

  const ApprovalAlertDetailDialog({
    Key? key,
    required this.title,
    required this.status,
    this.comment,
    this.approvalType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isApproved = status == 'APPROVED';
    final Color themeColor = isApproved
        ? const Color(0xFF0F9D58) // 진한 초록
        : const Color(0xFFD32F2F); // 진한 빨강
    final IconData statusIcon = isApproved ? Icons.check_circle : Icons.cancel;
    final String statusText = isApproved ? '승인됨' : '반려됨';

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
                color: themeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    statusIcon,
                    color: themeColor,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: themeColor,
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
                  // 오른쪽 상단 이동 버튼
                  Row(
                    children: [
                      const Spacer(),
                      if (approvalType == 'hr_leave_grant')
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const VacationManagementWebViewScreen(
                                        webUrl:
                                            'http://210.107.96.193:9999/pages/vacation-admin.html',
                                      )),
                            );
                          },
                          icon: const Icon(
                            Icons.open_in_new,
                            size: 16,
                            color: Colors.blue,
                          ),
                          label: const Text(
                            '휴가총괄관리(웹)로 이동',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else if (approvalType == 'eapproval')
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const ElectronicApprovalManagementScreen()),
                            );
                          },
                          icon: const Icon(
                            Icons.open_in_new,
                            size: 16,
                            color: Colors.blue,
                          ),
                          label: const Text(
                            '전자결재관리로 이동',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  // 결재건 제목
                  Row(
                    children: [
                      Icon(
                        Icons.description,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 반려 시 코멘트 표시
                  if (!isApproved &&
                      comment != null &&
                      comment!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Divider(
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.comment,
                          size: 20,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '반려 사유',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                comment!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 25),

            // 확인 버튼
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 20,
                ),
                label: const Text(
                  '확인',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
