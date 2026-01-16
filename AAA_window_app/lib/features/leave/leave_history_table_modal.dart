import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/features/leave/leave_models.dart';
import 'package:ASPN_AI_AGENT/features/leave/leave_providers_simple.dart';
import 'package:intl/intl.dart';

enum SortColumn {
  startDate,
  endDate,
  vacationType,
  status,
  approvalDate,
}

enum SortDirection {
  ascending,
  descending,
}

class LeaveHistoryTableModal extends ConsumerStatefulWidget {
  const LeaveHistoryTableModal({super.key});

  @override
  ConsumerState<LeaveHistoryTableModal> createState() =>
      _LeaveHistoryTableModalState();
}

class _LeaveHistoryTableModalState
    extends ConsumerState<LeaveHistoryTableModal> {
  SortColumn _sortColumn = SortColumn.startDate;
  SortDirection _sortDirection = SortDirection.descending;
  LeaveRequestStatus? _filterStatus;

  // 사이드바의 기본 색상
  static const Color _primaryColor = Color(0xFF2D3748);

  @override
  Widget build(BuildContext context) {
    final leaveHistory = ref.watch(leaveRequestHistoryProvider);
    final sortedHistory = _getSortedAndFilteredHistory(leaveHistory);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 900,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: _primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '휴가 사용 내역',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const Spacer(),
                // 상태 필터
                DropdownButton<LeaveRequestStatus?>(
                  value: _filterStatus,
                  hint: const Text('전체 상태'),
                  items: [
                    const DropdownMenuItem<LeaveRequestStatus?>(
                      value: null,
                      child: Text('전체 상태'),
                    ),
                    ...LeaveRequestStatus.values.map((status) {
                      return DropdownMenuItem<LeaveRequestStatus?>(
                        value: status,
                        child: _buildStatusChip(status, forDropdown: true),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterStatus = value;
                    });
                  },
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 통계 카드
            Row(
              children: [
                _buildStatCard('총 휴가일', _getTotalDays(sortedHistory)),
                const SizedBox(width: 16),
                _buildStatCard('승인된 휴가', _getApprovedDays(sortedHistory)),
                const SizedBox(width: 16),
                _buildStatCard('대기중', _getPendingCount(sortedHistory)),
                const SizedBox(width: 16),
                _buildStatCard('반려됨', _getRejectedCount(sortedHistory)),
              ],
            ),
            const SizedBox(height: 24),

            // 테이블
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // 헤더
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildHeaderCell('시작일', SortColumn.startDate,
                              flex: 2),
                          _buildHeaderCell('종료일', SortColumn.endDate, flex: 2),
                          _buildHeaderCell('휴가명', SortColumn.vacationType,
                              flex: 2),
                          _buildHeaderCell('승인상태', SortColumn.status, flex: 2),
                          _buildHeaderCell('승인일자', SortColumn.approvalDate,
                              flex: 2),
                          const Expanded(child: SizedBox()), // 여백
                        ],
                      ),
                    ),

                    // 데이터 행들
                    Expanded(
                      child: sortedHistory.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inbox_outlined,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    '휴가 사용 내역이 없습니다',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: sortedHistory.length,
                              itemBuilder: (context, index) {
                                final history = sortedHistory[index];
                                return _buildDataRow(history, index);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),

            // 하단 정보
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '총 ${sortedHistory.length}건의 휴가 신청 내역',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _exportData(sortedHistory),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('내보내기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, dynamic value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _primaryColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: const TextStyle(
                color: _primaryColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String title, SortColumn column, {int flex = 1}) {
    final isSelected = _sortColumn == column;

    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => _onSort(column),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSelected ? _primaryColor : Colors.grey[700],
                ),
              ),
              const SizedBox(width: 4),
              if (isSelected)
                Icon(
                  _sortDirection == SortDirection.ascending
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 16,
                  color: _primaryColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(LeaveRequestHistory history, int index) {
    final isEven = index % 2 == 0;

    return Container(
      decoration: BoxDecoration(
        color: isEven ? Colors.white : Colors.grey[50],
      ),
      child: InkWell(
        onTap: () => _showDetailModal(history),
        child: Row(
          children: [
            // 시작일
            Expanded(
              flex: 2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Text(
                  DateFormat('yyyy.MM.dd').format(history.startDate),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),

            // 종료일
            Expanded(
              flex: 2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Text(
                  DateFormat('yyyy.MM.dd').format(history.endDate),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),

            // 휴가명
            Expanded(
              flex: 2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Row(
                  children: [
                    Text(
                      history.vacationType,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${history.days}일)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 승인상태
            Expanded(
              flex: 2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: _buildStatusChip(history.status),
              ),
            ),

            // 승인일자
            Expanded(
              flex: 2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Text(
                  history.status == LeaveRequestStatus.approved
                      ? DateFormat('yyyy.MM.dd').format(
                          history.submittedDate.add(const Duration(days: 1)))
                      : '-',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),

            // 액션 버튼
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(LeaveRequestStatus status,
      {bool forDropdown = false}) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case LeaveRequestStatus.approved:
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green[800]!;
        break;
      case LeaveRequestStatus.pending:
        backgroundColor = Colors.blue.withValues(alpha: 0.1);
        textColor = Colors.blue[800]!;
        break;
      case LeaveRequestStatus.rejected:
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        textColor = Colors.red[800]!;
        break;
      case LeaveRequestStatus.cancelled:
        backgroundColor = Colors.grey.withValues(alpha: 0.1);
        textColor = Colors.grey[700]!;
        break;
      case LeaveRequestStatus.cancelRequested:
        backgroundColor =
            const Color(0xFFFF6B00).withValues(alpha: 0.1); // 진한 오렌지
        textColor = const Color(0xFFFF6B00);
        break;
    }

    if (forDropdown) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(status.label),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  List<LeaveRequestHistory> _getSortedAndFilteredHistory(
      List<LeaveRequestHistory> history) {
    // 필터링
    var filtered = history;
    if (_filterStatus != null) {
      filtered = history.where((h) => h.status == _filterStatus).toList();
    }

    // 정렬
    filtered.sort((a, b) {
      int comparison = 0;

      switch (_sortColumn) {
        case SortColumn.startDate:
          comparison = a.startDate.compareTo(b.startDate);
          break;
        case SortColumn.endDate:
          comparison = a.endDate.compareTo(b.endDate);
          break;
        case SortColumn.vacationType:
          comparison = a.vacationType.compareTo(b.vacationType);
          break;
        case SortColumn.status:
          comparison = a.status.label.compareTo(b.status.label);
          break;
        case SortColumn.approvalDate:
          comparison = a.submittedDate.compareTo(b.submittedDate);
          break;
      }

      return _sortDirection == SortDirection.ascending
          ? comparison
          : -comparison;
    });

    return filtered;
  }

  void _onSort(SortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortDirection = _sortDirection == SortDirection.ascending
            ? SortDirection.descending
            : SortDirection.ascending;
      } else {
        _sortColumn = column;
        _sortDirection = SortDirection.ascending;
      }
    });
  }

  double _getTotalDays(List<LeaveRequestHistory> history) {
    return history.fold(0.0, (sum, h) => sum + h.days);
  }

  double _getApprovedDays(List<LeaveRequestHistory> history) {
    return history
        .where((h) => h.status == LeaveRequestStatus.approved)
        .fold(0.0, (sum, h) => sum + h.days);
  }

  int _getPendingCount(List<LeaveRequestHistory> history) {
    return history.where((h) => h.status == LeaveRequestStatus.pending).length;
  }

  int _getRejectedCount(List<LeaveRequestHistory> history) {
    return history.where((h) => h.status == LeaveRequestStatus.rejected).length;
  }

  void _showDetailModal(LeaveRequestHistory history) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: _primaryColor),
            const SizedBox(width: 8),
            const Text('휴가 상세 정보'),
          ],
        ),
        content: Container(
          width: 400,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('휴가 종류', history.vacationType),
                _buildDetailRow('기간',
                    '${DateFormat('yyyy.MM.dd').format(history.startDate)} ~ ${DateFormat('yyyy.MM.dd').format(history.endDate)}'),
                _buildDetailRow('사용 일수', '${history.days}일'),
                _buildDetailRow(
                    '신청일',
                    DateFormat('yyyy.MM.dd HH:mm')
                        .format(history.submittedDate)),
                _buildDetailRow('상태', history.status.label,
                    statusWidget: _buildStatusChip(history.status)),
                _buildDetailRow('휴가 사유', history.reason, isMultiLine: true),
                if (history.approverComment != null)
                  _buildDetailRow('승인자 코멘트', history.approverComment!,
                      isMultiLine: true),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {Widget? statusWidget, bool isMultiLine = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          statusWidget ??
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: isMultiLine ? 120 : 20,
                ),
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 14),
                  maxLines: isMultiLine ? 6 : 1,
                  overflow: isMultiLine
                      ? TextOverflow.ellipsis
                      : TextOverflow.ellipsis,
                ),
              ),
        ],
      ),
    );
  }

  void _exportData(List<LeaveRequestHistory> history) {
    // CSV 내보내기 기능 스텁
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('데이터 내보내기'),
        content: const Text('CSV 파일로 내보내기 기능은 추후 구현 예정입니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
