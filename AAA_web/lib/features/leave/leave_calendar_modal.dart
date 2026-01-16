import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/features/leave/leave_models.dart';
import 'package:ASPN_AI_AGENT/provider/leave_management_provider.dart';
import 'package:ASPN_AI_AGENT/models/leave_management_models.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:intl/intl.dart';

class LeaveCalendarModal extends ConsumerStatefulWidget {
  const LeaveCalendarModal({super.key});

  @override
  ConsumerState<LeaveCalendarModal> createState() => _LeaveCalendarModalState();
}

class _LeaveCalendarModalState extends ConsumerState<LeaveCalendarModal> {
  DateTime _selectedDate = DateTime.now();
  late DateTime _currentMonth;
  DepartmentLeaveViewType _viewType = DepartmentLeaveViewType.personal;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
  }

  // 월 변경 시 API 호출
  void _loadMonthData(DateTime newMonth) {
    final currentUserId = ref.read(userIdProvider);
    if (currentUserId != null) {
      final monthString =
          '${newMonth.year}-${newMonth.month.toString().padLeft(2, '0')}';
      ref
          .read(leaveManagementProvider.notifier)
          .loadMonthlyCalendarData(currentUserId, monthString);
    } else {
      print('⚠️ 로그인된 사용자 ID가 없습니다. 월별 달력 데이터를 로드할 수 없습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaveManagementState = ref.watch(leaveManagementProvider);
    final monthlyLeaves = leaveManagementState.data?.monthlyLeaves ?? [];

    // 개인 휴가 보기인지 부서 휴가 보기인지에 따라 데이터 선택
    final displayData = _viewType == DepartmentLeaveViewType.personal
        ? monthlyLeaves
        : <MonthlyLeave>[]; // 부서 휴가 보기는 나중에 구현

    // 디버깅: 데이터 확인
    print('📅 Calendar Modal - displayData length: ${displayData.length}');
    if (displayData.isNotEmpty) {
      print(
          '📅 First leave: ${displayData.first.leaveType} (${displayData.first.status})');
      print(
          '📅 Date range: ${displayData.first.startDate} ~ ${displayData.first.endDate}');
    }

    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: screenSize.width * 0.8,
        height: screenSize.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D3748),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  '휴가 달력',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3748),
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                // 뷰 타입 선택 버튼들
                Row(
                  children: DepartmentLeaveViewType.values.map((type) {
                    final isSelected = _viewType == type;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _viewType = type;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF2D3748)
                                : const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF2D3748)
                                  : const Color(0xFFE1E5E9),
                            ),
                          ),
                          child: Text(
                            type.label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF4A5568),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Color(0xFF718096),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 월 네비게이션
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 연도 변경
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        final newMonth = DateTime(
                            _currentMonth.year - 1, _currentMonth.month, 1);
                        setState(() {
                          _currentMonth = newMonth;
                        });
                        _loadMonthData(newMonth);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE1E5E9)),
                        ),
                        child: const Icon(
                          Icons.keyboard_double_arrow_left,
                          color: Color(0xFF4A5568),
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        final newMonth = DateTime(
                            _currentMonth.year, _currentMonth.month - 1, 1);
                        setState(() {
                          _currentMonth = newMonth;
                        });
                        _loadMonthData(newMonth);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE1E5E9)),
                        ),
                        child: const Icon(
                          Icons.chevron_left,
                          color: Color(0xFF4A5568),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),

                // 현재 연월 표시
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE1E5E9)),
                  ),
                  child: Text(
                    DateFormat('yyyy년 M월').format(_currentMonth),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D3748),
                      letterSpacing: -0.4,
                    ),
                  ),
                ),

                // 연도 변경
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        final newMonth = DateTime(
                            _currentMonth.year, _currentMonth.month + 1, 1);
                        setState(() {
                          _currentMonth = newMonth;
                        });
                        _loadMonthData(newMonth);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE1E5E9)),
                        ),
                        child: const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF4A5568),
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        final newMonth = DateTime(
                            _currentMonth.year + 1, _currentMonth.month, 1);
                        setState(() {
                          _currentMonth = newMonth;
                        });
                        _loadMonthData(newMonth);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE1E5E9)),
                        ),
                        child: const Icon(
                          Icons.keyboard_double_arrow_right,
                          color: Color(0xFF4A5568),
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 달력
            Expanded(
              child: _buildCalendar(displayData),
            ),

            // 범례
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE1E5E9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '범례',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF2D3748),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 20,
                    runSpacing: 10,
                    children: [
                      _buildLegendItem('승인됨', _getStatusColor('APPROVED')),
                      _buildLegendItem('대기중', _getStatusColor('PENDING')),
                      _buildLegendItem('반려됨', _getStatusColor('REJECTED')),
                      _buildLegendItem('취소됨', _getStatusColor('CANCELLED')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(List<MonthlyLeave> monthlyLeaves) {
    final firstDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstDayOfWeek = firstDayOfMonth.weekday % 7; // 일요일을 0으로 만들기
    final daysInMonth = lastDayOfMonth.day;

    return Column(
      children: [
        // 요일 헤더
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: ['일', '월', '화', '수', '목', '금', '토']
                .asMap()
                .entries
                .map((entry) {
              final index = entry.key;
              final day = entry.value;
              final isSunday = index == 0;
              final isSaturday = index == 6;

              return Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isSunday
                          ? const Color(0xFFE53E3E)
                          : isSaturday
                              ? const Color(0xFF3182CE)
                              : const Color(0xFF4A5568),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),

        // 달력 그리드
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.43,
            ),
            itemCount: 42, // 6주 * 7일
            itemBuilder: (context, index) {
              final dayOffset = index - firstDayOfWeek;

              if (dayOffset < 0 || dayOffset >= daysInMonth) {
                return const SizedBox(); // 빈 셀
              }

              final day = dayOffset + 1;
              final date =
                  DateTime(_currentMonth.year, _currentMonth.month, day);
              final dayLeaves = _getLeavesForDate(date, monthlyLeaves);

              return _buildCalendarDay(date, dayLeaves);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarDay(DateTime date, List<MonthlyLeave> dayLeaves) {
    final isToday = DateTime.now().day == date.day &&
        DateTime.now().month == date.month &&
        DateTime.now().year == date.year;

    final isWeekend = date.weekday == 6 || date.weekday == 7; // 토요일(6), 일요일(7)
    final isSunday = date.weekday == 7;

    final isSelected = _selectedDate.day == date.day &&
        _selectedDate.month == date.month &&
        _selectedDate.year == date.year;

    // 화면 크기에 따른 점 크기 계산
    final screenWidth = MediaQuery.of(context).size.width;
    final dotSize = screenWidth > 1600
        ? 6.0
        : screenWidth > 1200
            ? 5.0
            : 4.5;

    // 상태별 개수 계산 (메인 달력과 동일한 로직)
    final pendingCount = dayLeaves
        .where((l) =>
            l.status.toUpperCase() == 'PENDING' ||
            l.status.toUpperCase() == 'REQUESTED')
        .length;
    final approvedCount =
        dayLeaves.where((l) => l.status.toUpperCase() == 'APPROVED').length;
    final rejectedCount =
        dayLeaves.where((l) => l.status.toUpperCase() == 'REJECTED').length;
    final cancelledCount =
        dayLeaves.where((l) => l.status.toUpperCase() == 'CANCELLED').length;

    // 디버깅: 해당 날짜에 휴가가 있는지 확인
    if (dayLeaves.isNotEmpty && date.day <= 5) {
      // 월 초 5일만 로그 출력
      print(
          '📅 ${date.day}일: ${dayLeaves.length}개 휴가 (P:$pendingCount, A:$approvedCount, R:$rejectedCount, C:$cancelledCount)');
    }

    // 휴가 상태에 따른 배경색 결정 (우선순위: pending > approved > rejected > cancelled)
    Color? leaveColor;
    final hasLeave = dayLeaves.isNotEmpty;
    if (hasLeave) {
      if (pendingCount > 0) {
        leaveColor = const Color(0xFFFF8C00); // 대기중
      } else if (approvedCount > 0) {
        leaveColor = const Color(0xFF20C997); // 승인됨
      } else if (rejectedCount > 0) {
        leaveColor = const Color(0xFFDC3545); // 반려됨
      } else if (cancelledCount > 0) {
        leaveColor = const Color(0xFF6C757D); // 취소됨 (회색, 최하 우선순위)
      }
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = date;
        });
        if (dayLeaves.isNotEmpty) {
          _showDayDetail(date, dayLeaves);
        }
      },
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2D3748)
              : isToday
                  ? const Color(0xFF1E88E5).withValues(alpha: 0.3)
                  : (hasLeave && leaveColor != null)
                      ? leaveColor.withValues(alpha: 0.15)
                      : Colors.white,
          border: isToday
              ? Border.all(color: const Color(0xFF4299E1), width: 2)
              : isSelected
                  ? Border.all(color: const Color(0xFF2D3748), width: 2)
                  : Border.all(color: const Color(0xFFE1E5E9), width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // 중앙에 날짜 텍스트
            Center(
              child: Text(
                date.day.toString(),
                style: TextStyle(
                  fontWeight: (isToday || isSelected)
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : isSunday
                          ? const Color(0xFFE53E3E)
                          : isWeekend
                              ? const Color(0xFF3182CE)
                              : const Color(0xFF2D3748),
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            // 왼쪽 상단에 상태별 점들 표시 (메인 달력과 동일한 로직)
            if (dayLeaves.isNotEmpty)
              Positioned(
                left: 1,
                top: 1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 대기중 점들
                    ...List.generate(
                        pendingCount,
                        (index) => Container(
                              width: dotSize,
                              height: dotSize,
                              margin: const EdgeInsets.only(bottom: 0.5),
                              decoration: BoxDecoration(
                                color: (isSelected || isToday)
                                    ? Colors.white
                                    : const Color(0xFFFF8C00),
                                shape: BoxShape.circle,
                              ),
                            )),
                    // 승인됨 점들
                    ...List.generate(
                        approvedCount,
                        (index) => Container(
                              width: dotSize,
                              height: dotSize,
                              margin: const EdgeInsets.only(bottom: 0.5),
                              decoration: BoxDecoration(
                                color: (isSelected || isToday)
                                    ? Colors.white
                                    : const Color(0xFF20C997),
                                shape: BoxShape.circle,
                              ),
                            )),
                    // 반려됨 점들
                    ...List.generate(
                        rejectedCount,
                        (index) => Container(
                              width: dotSize,
                              height: dotSize,
                              margin: const EdgeInsets.only(bottom: 0.5),
                              decoration: BoxDecoration(
                                color: (isSelected || isToday)
                                    ? Colors.white
                                    : const Color(0xFFDC3545),
                                shape: BoxShape.circle,
                              ),
                            )),
                    // 취소됨 점들 (최하 우선순위)
                    ...List.generate(
                        cancelledCount,
                        (index) => Container(
                              width: dotSize,
                              height: dotSize,
                              margin: const EdgeInsets.only(bottom: 0.5),
                              decoration: BoxDecoration(
                                color: (isSelected || isToday)
                                    ? Colors.white
                                    : const Color(0xFF6C757D),
                                shape: BoxShape.circle,
                              ),
                            )),
                  ].take(6).toList(), // 최대 6개까지만 표시
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4A5568),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  List<MonthlyLeave> _getLeavesForDate(
      DateTime date, List<MonthlyLeave> monthlyLeaves) {
    return monthlyLeaves.where((leave) {
      // UTC 시간을 로컬 날짜로 변환하여 비교 (메인 달력과 동일한 로직)
      final startDateLocal = DateTime(
          leave.startDate.year, leave.startDate.month, leave.startDate.day);
      final endDateLocal =
          DateTime(leave.endDate.year, leave.endDate.month, leave.endDate.day);
      final currentDate = DateTime(date.year, date.month, date.day);

      // endDate까지 포함하여 표시 (inclusive)
      return (currentDate.isAtSameMomentAs(startDateLocal) ||
          currentDate.isAtSameMomentAs(endDateLocal) ||
          (currentDate.isAfter(startDateLocal) &&
              currentDate.isBefore(endDateLocal)));
    }).toList();
  }

  void _showDayDetail(DateTime date, List<MonthlyLeave> dayLeaves) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${DateFormat('M월 d일').format(date)} 휴가 내역'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: dayLeaves.map((leave) {
            final statusColor = _getStatusColor(leave.status);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _getStatusLabel(leave.status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        leave.leaveType,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('M/d').format(leave.startDate)} ~ ${DateFormat('M/d').format(leave.endDate)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (leave.halfDaySlot.isNotEmpty)
                    Text(
                      '반차: ${leave.halfDaySlot}',
                      style: const TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  Text(
                    leave.reason,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (leave.rejectMessage.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '반려 사유: ${leave.rejectMessage}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
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

  // 상태에 따른 색상 반환
  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return const Color(0xFF38A169); // 녹색
      case 'PENDING':
      case 'REQUESTED':
        return const Color(0xFFED8936); // 주황색
      case 'REJECTED':
        return const Color(0xFFE53E3E); // 빨간색
      case 'CANCELLED':
        return const Color(0xFF718096); // 회색
      default:
        return const Color(0xFF4A5568); // 기본 회색
    }
  }

  // 상태에 따른 라벨 반환
  String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return '승인됨';
      case 'PENDING':
      case 'REQUESTED':
        return '대기중';
      case 'REJECTED':
        return '반려됨';
      case 'CANCELLED':
        return '취소됨';
      default:
        return status;
    }
  }
}
