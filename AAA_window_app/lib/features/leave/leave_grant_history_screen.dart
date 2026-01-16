import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ASPN_AI_AGENT/features/leave/leave_models.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:ASPN_AI_AGENT/shared/services/leave_api_service.dart';

class LeaveGrantHistoryScreen extends ConsumerStatefulWidget {
  const LeaveGrantHistoryScreen({super.key});

  @override
  ConsumerState<LeaveGrantHistoryScreen> createState() =>
      _LeaveGrantHistoryScreenState();
}

class _LeaveGrantHistoryScreenState
    extends ConsumerState<LeaveGrantHistoryScreen> {
  static const String _fileApprovalType = 'hr_leave_grant';
  bool _isLoading = true;
  String? _errorMessage;
  List<LeaveGrantRequestItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadGrantHistory();
  }

  Future<void> _loadGrantHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final userId = ref.read(userIdProvider) ?? '';
    if (userId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = '로그인 정보를 찾을 수 없습니다. 다시 로그인해주세요.';
      });
      return;
    }

    final response = await LeaveApiService.getGrantRequestList(userId: userId);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (response.isSuccess) {
        _items = response.leaveGrants;
      } else {
        _errorMessage = response.error ?? '휴가 부여 내역을 불러오지 못했습니다.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('휴가 부여 내역'),
        backgroundColor:
            isDarkTheme ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5),
        foregroundColor: isDarkTheme ? Colors.white : const Color(0xFF374151),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadGrantHistory,
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        color: isDarkTheme ? const Color(0xFF1F1F1F) : const Color(0xFFF3F4F6),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, isDarkTheme),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadGrantHistory,
                  child: _buildBody(context, isDarkTheme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDarkTheme) {
    final totalCount = _items.length;
    final managerCount = _items.where((item) => item.isManager == 1).length;
    final approvedUserCount = _items.where((item) {
      return item.isManager == 0 && _isApprovedStatus(item.status);
    }).length;
    final pendingCount = _items.where((item) {
      final status = item.status.toLowerCase();
      return status.contains('pending') ||
          status.contains('대기') ||
          status.contains('process') ||
          status.contains('progress') ||
          status.contains('request') ||
          item.status.contains('상신') ||
          item.status.contains('진행') ||
          item.status.contains('요청') ||
          item.status.contains('신청');
    }).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: isDarkTheme
            ? const LinearGradient(
                colors: [Color(0xFF3B3F47), Color(0xFF1F2937)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF9333EA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkTheme ? 0.4 : 0.15),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '내 휴가 부여 내역',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '부여된 휴가 기록과 처리 상태를 한눈에 확인하세요.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildStatChip('전체', totalCount.toString()),
              _buildStatChip('대기', pendingCount.toString()),
              _buildStatChip('관리자 임의부여', managerCount.toString()),
              _buildStatChip('관리자 승인', approvedUserCount.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isDarkTheme) {
    if (_isLoading) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
          SizedBox(height: 12),
          Center(child: Text('휴가 부여 내역을 불러오는 중...')),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(
            Icons.error_outline,
            size: 48,
            color: isDarkTheme ? Colors.red[300] : Colors.red[400],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: isDarkTheme ? Colors.white70 : const Color(0xFF4B5563),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: _loadGrantHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(
            Icons.inbox_outlined,
            size: 52,
            color: isDarkTheme ? Colors.white38 : const Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '휴가 부여 내역이 없습니다.',
              style: TextStyle(
                color: isDarkTheme ? Colors.white70 : const Color(0xFF4B5563),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildGrantCard(_items[index], isDarkTheme);
      },
    );
  }

  Widget _buildGrantCard(LeaveGrantRequestItem item, bool isDarkTheme) {
    final statusColor = _statusColor(item.status);
    final statusLabel = _formatStatus(item.status);
    final managerLabel = item.isManager == 1 ? '관리자 부여' : '사용자 신청';
    final attachmentCount = _attachmentCount(item.attachmentsList);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showDetailDialog(item),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkTheme ? const Color(0xFF2B2B2B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkTheme ? 0.2 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color:
                isDarkTheme ? const Color(0xFF3A3A3A) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6,
              height: 90,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatusChip(statusLabel, statusColor),
                      _buildOutlineChip(managerLabel, isDarkTheme),
                      _buildOutlineChip(
                        item.leaveType.isEmpty ? '휴가' : item.leaveType,
                        isDarkTheme,
                      ),
                      if (item.grantDays > 0)
                        _buildOutlineChip(
                          '${_formatDays(item.grantDays)}일',
                          isDarkTheme,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.title.isEmpty ? '제목 없음' : item.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color:
                          isDarkTheme ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.reason.isEmpty ? '사유 없음' : item.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          isDarkTheme ? Colors.white70 : const Color(0xFF4B5563),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _buildMetaItem(
                        Icons.calendar_today,
                        '결재일',
                        _formatDate(item.approvalDate),
                        isDarkTheme,
                      ),
                      _buildMetaItem(
                        Icons.check_circle_outline,
                        '처리일',
                        _formatDate(item.procDate),
                        isDarkTheme,
                      ),
                      _buildMetaItem(
                        Icons.attach_file,
                        '첨부',
                        '$attachmentCount개',
                        isDarkTheme,
                      ),
                    ],
                  ),
                  if (item.comment.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDarkTheme
                            ? const Color(0xFF1F1F1F)
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 16,
                            color: isDarkTheme
                                ? Colors.blueGrey[200]
                                : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.comment,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkTheme
                                    ? Colors.white70
                                    : const Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildOutlineChip(String label, bool isDarkTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
              isDarkTheme ? const Color(0xFF475569) : const Color(0xFFCBD5F5),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDarkTheme ? Colors.white70 : const Color(0xFF4B5563),
        ),
      ),
    );
  }

  Widget _buildMetaItem(
    IconData icon,
    String label,
    String value,
    bool isDarkTheme,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isDarkTheme ? Colors.white54 : const Color(0xFF9CA3AF),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $value',
          style: TextStyle(
            fontSize: 11,
            color: isDarkTheme ? Colors.white70 : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  int _attachmentCount(dynamic attachments) {
    if (attachments is List) return attachments.length;
    if (attachments is Map) return attachments.length;
    return 0;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  String _formatDays(double days) {
    final formatted = days.toStringAsFixed(1);
    return formatted.endsWith('.0')
        ? formatted.substring(0, formatted.length - 2)
        : formatted;
  }

  String _formatStatus(String status) {
    if (status.isEmpty) return '알 수 없음';
    final lower = status.toLowerCase();
    if (lower.contains('complete') || lower.contains('done')) {
      return '완료';
    }
    if (lower.contains('process') || lower.contains('progress')) {
      return '진행중';
    }
    if (lower.contains('approved')) return '승인됨';
    if (lower.contains('rejected')) return '반려됨';
    if (lower.contains('pending')) return '대기중';
    if (lower.contains('cancel')) return '취소됨';
    if (lower.contains('request')) return '상신됨';
    if (status.contains('승인')) return '승인됨';
    if (status.contains('반려')) return '반려됨';
    if (status.contains('대기')) return '대기중';
    if (status.contains('취소')) return '취소됨';
    if (status.contains('진행')) return '진행중';
    if (status.contains('완료')) return '완료';
    if (status.contains('상신')) return '상신됨';
    if (status.contains('요청') || status.contains('신청')) return '상신됨';
    return status;
  }

  Color _statusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('complete') || lower.contains('done')) {
      return const Color(0xFF22C55E);
    }
    if (lower.contains('process') || lower.contains('progress')) {
      return const Color(0xFF3B82F6);
    }
    if (lower.contains('approved') || lower.contains('승인')) {
      return const Color(0xFF10B981);
    }
    if (lower.contains('rejected') || lower.contains('반려')) {
      return const Color(0xFFEF4444);
    }
    if (lower.contains('pending') || lower.contains('대기')) {
      return const Color(0xFF3B82F6);
    }
    if (lower.contains('cancel') || lower.contains('취소')) {
      return const Color(0xFF9CA3AF);
    }
    if (lower.contains('request')) {
      return const Color(0xFFF59E0B);
    }
    if (status.contains('완료')) {
      return const Color(0xFF22C55E);
    }
    if (status.contains('상신')) {
      return const Color(0xFFF59E0B);
    }
    if (status.contains('요청') || status.contains('신청')) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFFF59E0B);
  }

  bool _isApprovedStatus(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('approved')) return true;
    if (status.contains('승인')) return true;
    if (lower.contains('complete') || lower.contains('done')) return true;
    if (status.contains('완료')) return true;
    return false;
  }

  void _showDetailDialog(LeaveGrantRequestItem item) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        final statusColor = _statusColor(item.status);
        final statusLabel = _formatStatus(item.status);
        final attachments = _normalizeAttachments(item.attachmentsList);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 620),
            decoration: BoxDecoration(
              color: isDarkTheme ? const Color(0xFF1F1F1F) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: isDarkTheme
                        ? const LinearGradient(
                            colors: [Color(0xFF374151), Color(0xFF111827)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatusChip(statusLabel, statusColor),
                            const SizedBox(height: 10),
                            Text(
                              item.title.isEmpty ? '휴가 부여 상세' : item.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.leaveType.isEmpty
                                  ? '휴가 부여 내역'
                                  : item.leaveType,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildOutlineChip(
                              item.isManager == 1 ? '관리자 부여' : '사용자 신청',
                              isDarkTheme,
                            ),
                            if (item.grantDays > 0)
                              _buildOutlineChip(
                                '${_formatDays(item.grantDays)}일',
                                isDarkTheme,
                              ),
                            _buildOutlineChip('ID: ${item.id}', isDarkTheme),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          '결재일',
                          _formatDate(item.approvalDate),
                          isDarkTheme,
                        ),
                        _buildDetailRow(
                          '처리일',
                          _formatDate(item.procDate),
                          isDarkTheme,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '사유',
                          style: TextStyle(
                            color: isDarkTheme
                                ? Colors.white
                                : const Color(0xFF111827),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.reason.isEmpty ? '사유 없음' : item.reason,
                          style: TextStyle(
                            color: isDarkTheme
                                ? Colors.white70
                                : const Color(0xFF4B5563),
                            height: 1.4,
                          ),
                        ),
                        if (item.comment.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            '코멘트',
                            style: TextStyle(
                              color: isDarkTheme
                                  ? Colors.white
                                  : const Color(0xFF111827),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.comment,
                            style: TextStyle(
                              color: isDarkTheme
                                  ? Colors.white70
                                  : const Color(0xFF4B5563),
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          '첨부파일',
                          style: TextStyle(
                            color: isDarkTheme
                                ? Colors.white
                                : const Color(0xFF111827),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (attachments.isEmpty)
                          Text(
                            '첨부파일이 없습니다.',
                            style: TextStyle(
                              color: isDarkTheme
                                  ? Colors.white60
                                  : const Color(0xFF6B7280),
                            ),
                          )
                        else
                          Column(
                            children: attachments
                                .map((attachment) => _buildAttachmentTile(
                                      attachment,
                                      isDarkTheme,
                                    ))
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('닫기'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDarkTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: isDarkTheme ? Colors.white54 : const Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isDarkTheme ? Colors.white : const Color(0xFF111827),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentTile(
    Map<String, dynamic> attachment,
    bool isDarkTheme,
  ) {
    final fileName = (attachment['file_name'] ??
            attachment['name'] ??
            attachment['filename'] ??
            '첨부파일')
        .toString();
    final sizeValue = attachment['size'];
    final sizeText = sizeValue is num ? _formatBytes(sizeValue.toInt()) : null;
    final url = attachment['url']?.toString();

    return InkWell(
      onTap: () => _openAttachment(attachment),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDarkTheme ? const Color(0xFF2B2B2B) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isDarkTheme ? const Color(0xFF3A3A3A) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 18,
              color: isDarkTheme ? Colors.white70 : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                          isDarkTheme ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  if (sizeText != null || (url != null && url.isNotEmpty))
                    const SizedBox(height: 4),
                  if (sizeText != null)
                    Text(
                      sizeText,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkTheme
                            ? Colors.white60
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  if (url != null && url.isNotEmpty)
                    Text(
                      url,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkTheme
                            ? Colors.white54
                            : const Color(0xFF9CA3AF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.open_in_new,
              size: 16,
              color: isDarkTheme ? Colors.white54 : const Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _normalizeAttachments(dynamic attachments) {
    if (attachments == null) return [];
    if (attachments is List) {
      return attachments
          .map((entry) => _castAttachment(entry))
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    }
    if (attachments is Map<String, dynamic>) {
      return [attachments];
    }
    if (attachments is Map) {
      final mapped = _castAttachment(attachments);
      return mapped == null ? [] : [mapped];
    }
    if (attachments is String) {
      try {
        final decoded = jsonDecode(attachments);
        if (decoded is List) {
          return decoded
              .map((entry) => _castAttachment(entry))
              .whereType<Map<String, dynamic>>()
              .toList(growable: false);
        }
        if (decoded is Map<String, dynamic>) return [decoded];
        if (decoded is Map) {
          final mapped = _castAttachment(decoded);
          return mapped == null ? [] : [mapped];
        }
      } catch (_) {}
    }
    return [];
  }

  Map<String, dynamic>? _castAttachment(dynamic entry) {
    if (entry is Map<String, dynamic>) return entry;
    if (entry is Map) {
      return entry.map((key, value) => MapEntry('$key', value));
    }
    return null;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _openAttachment(Map<String, dynamic> attachment) async {
    final directUrl =
        attachment['url']?.toString() ?? attachment['file_url']?.toString();
    final fileName = (attachment['file_name'] ??
            attachment['name'] ??
            attachment['filename'])
        ?.toString();
    final prefix = attachment['prefix']?.toString();

    String? url = directUrl;
    if ((url == null || url.isEmpty) &&
        fileName != null &&
        fileName.isNotEmpty &&
        prefix != null &&
        prefix.isNotEmpty) {
      url = await LeaveApiService.getFileUrl(
        fileName: fileName,
        prefix: prefix,
        approvalType: _fileApprovalType,
        isDownload: 0,
      );
    }

    if (url == null || url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('첨부파일 URL을 가져오지 못했습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('유효하지 않은 URL입니다.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('첨부파일을 열 수 없습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
