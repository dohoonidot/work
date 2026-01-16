import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:ASPN_AI_AGENT/features/leave/leave_models.dart';
import 'package:ASPN_AI_AGENT/provider/leave_management_provider.dart';
import 'package:ASPN_AI_AGENT/models/leave_management_models.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:ASPN_AI_AGENT/shared/services/leave_api_service.dart';
import 'package:ASPN_AI_AGENT/shared/services/api_service.dart';

// 넓게보기 달력 모달 클래스
class FullCalendarModal extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const FullCalendarModal({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  ConsumerState<FullCalendarModal> createState() => _FullCalendarModalState();
}

class _FullCalendarModalState extends ConsumerState<FullCalendarModal> {
  late DateTime _selectedDate;
  late DateTime _currentCalendarDate;
  late PageController _pageController;
  List<Map<String, Object>> _selectedDateDetails = [];

  // 공휴일 데이터
  List<Holiday> _holidays = [];

  // 뷰 모드 관리
  bool _isMyVacationView = true; // true: 내 휴가 내역, false: 부서 휴가 현황
  Set<String> _selectedDepartments = {}; // 선택된 부서들
  Set<String> _selectedEmployees = {}; // 선택된 개별 직원들 (userId 저장)
  Set<String> _expandedDepartments = {}; // 확장된 부서들 (드롭다운용)

  // 부서 휴가 현황 데이터
  List<TotalCalendarLeave> _totalCalendarLeaves = [];
  Map<String, List<Map<String, String>>> _departmentEmployees =
      {}; // 부서별 직원 맵 {'userId': 'xxx', 'name': 'yyy'}
  bool _isDepartmentDataLoading = false;

  // 슬라이드 패널 관리
  bool _isDetailPanelVisible = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    _currentCalendarDate = DateTime(_selectedDate.year, _selectedDate.month);
    final monthsFromBase = (_currentCalendarDate.year - 2020) * 12 +
        (_currentCalendarDate.month - 1);
    _pageController = PageController(initialPage: monthsFromBase);

    // 초기 로드 시 현재 월의 달력 데이터와 공휴일 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMonthlyCalendarData(_currentCalendarDate);
      _loadHolidays(_currentCalendarDate.year, _currentCalendarDate.month);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 프로바이더에 안전하게 접근할 수 있는 시점에서 초기화
    _updateSelectedDateDetails();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '휴가 일정 달력 (전체보기)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDarkTheme
                            ? Colors.white
                            : const Color(0xFF1A1D29),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // 뷰 모드 전환 버튼
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkTheme
                            ? const Color(0xFF3A3A3A)
                            : const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isDarkTheme
                                ? const Color(0xFF505050)
                                : const Color(0xFFE9ECEF)),
                      ),
                      child: Row(
                        children: [
                          _buildViewModeButton('내 휴가 내역', true),
                          _buildViewModeButton('부서 휴가 현황', false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close,
                  color:
                      isDarkTheme ? Colors.grey[400] : const Color(0xFF6C757D),
                  size: 24,
                ),
              ),
            ],
          ),
        ),
        Divider(
            height: 1,
            color: isDarkTheme
                ? const Color(0xFF404040)
                : const Color(0xFFF1F3F5)),
        // 메인 콘텐츠
        Expanded(
          child: Row(
            children: [
              // 달력 영역 (기존 크기 유지)
              Expanded(
                flex: 7,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // 현재 월 표시 및 네비게이션
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            icon: Icon(Icons.chevron_left,
                                color: isDarkTheme
                                    ? Colors.grey[400]
                                    : const Color(0xFF6C757D),
                                size: 32),
                            constraints: const BoxConstraints(
                                minWidth: 48, minHeight: 48),
                            tooltip: '이전 달',
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: _showDatePicker,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDarkTheme
                                          ? const Color(0xFF3A3A3A)
                                          : const Color(0xFFF8F9FA),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDarkTheme
                                            ? const Color(0xFF505050)
                                            : const Color(0xFFE9ECEF),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${_currentCalendarDate.year}년 ${_currentCalendarDate.month}월',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w600,
                                            color: isDarkTheme
                                                ? Colors.white
                                                : const Color(0xFF495057),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.calendar_month,
                                          color: isDarkTheme
                                              ? Colors.grey[400]
                                              : const Color(0xFF6C757D),
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: _goToToday,
                                  icon: const Icon(Icons.today, size: 16),
                                  label: const Text('오늘'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDarkTheme
                                        ? const Color(0xFF3A3A3A)
                                        : const Color(0xFF1E88E5),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            icon: Icon(Icons.chevron_right,
                                color: isDarkTheme
                                    ? Colors.grey[400]
                                    : const Color(0xFF6C757D),
                                size: 32),
                            constraints: const BoxConstraints(
                                minWidth: 48, minHeight: 48),
                            tooltip: '다음 달',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const BouncingScrollPhysics(),
                          onPageChanged: (index) async {
                            setState(() {
                              final baseDate = DateTime(2020, 1);
                              _currentCalendarDate = DateTime(
                                baseDate.year,
                                baseDate.month + index,
                              );
                            });

                            // 해당 월의 달력 데이터 로드
                            // 부서휴가현황 모드에서는 totalCalendar, 내 휴가 모드에서는 myCalendar 호출
                            if (_isMyVacationView) {
                              await _loadMonthlyCalendarData(
                                  _currentCalendarDate);
                            } else {
                              await _loadDepartmentCalendarData(
                                  _currentCalendarDate);
                            }

                            // 공휴일 데이터 로드
                            await _loadHolidays(_currentCalendarDate.year,
                                _currentCalendarDate.month);
                          },
                          itemBuilder: (context, index) {
                            final baseDate = DateTime(2020, 1);
                            final monthDate = DateTime(
                              baseDate.year,
                              baseDate.month + index,
                            );
                            return _buildFullMonthCalendar(monthDate);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              VerticalDivider(
                  width: 1,
                  color: isDarkTheme
                      ? const Color(0xFF404040)
                      : const Color(0xFFF1F3F5)),
              // 우측 영역 (부서 선택 또는 내 휴가 내역)
              Expanded(
                flex: 3,
                child: _isMyVacationView
                    ? Container(
                        padding: const EdgeInsets.all(20),
                        child: _buildModalDateDetails(),
                      )
                    : _buildRightPanel(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 날짜 피커 표시
  Future<void> _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _currentCalendarDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null && picked != _currentCalendarDate) {
      setState(() {
        _currentCalendarDate = DateTime(picked.year, picked.month);
      });

      // 해당 월로 페이지 이동
      final monthsFromBase = (_currentCalendarDate.year - 2020) * 12 +
          (_currentCalendarDate.month - 1);
      _pageController.animateToPage(
        monthsFromBase,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      // 해당 월의 달력 데이터 로드
      await _loadMonthlyCalendarData(_currentCalendarDate);
    }
  }

  // 오늘로 이동
  void _goToToday() async {
    final today = DateTime.now();
    final monthsFromBase = (today.year - 2020) * 12 + (today.month - 1);
    _pageController.animateToPage(
      monthsFromBase,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _selectedDate = today;
      _currentCalendarDate = DateTime(today.year, today.month);
      _updateSelectedDateDetails();
    });
    widget.onDateSelected(_selectedDate);

    // 해당 월의 달력 데이터 로드
    await _loadMonthlyCalendarData(today);
  }

  // 월별 달력 데이터 로드 (API 호출)
  Future<void> _loadMonthlyCalendarData(DateTime monthDate) async {
    try {
      // 현재 로그인된 사용자 ID 가져오기
      final currentUserId = ref.read(userIdProvider);
      if (currentUserId == null) {
        print('⚠️ 로그인된 사용자 ID가 없습니다. 월별 달력 데이터를 로드할 수 없습니다.');
        return;
      }

      // 월 형식을 '2025-09' 형태로 변환
      final monthString =
          '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}';

      final request = MonthlyCalendarRequest(
        userId: currentUserId,
        month: monthString,
      );

      print('📅 전체보기 달력 월별 데이터 로드: $monthString');

      final response =
          await LeaveApiService.getMonthlyCalendar(request: request);

      if (response.isSuccess) {
        // 성공 시 휴가관리 데이터 업데이트 (부분 업데이트)
        final currentData = ref.read(leaveManagementProvider).data;
        if (currentData != null) {
          final updatedData = LeaveManagementData(
            leaveStatus: currentData.leaveStatus, // 기존 데이터 유지
            approvalStatus: currentData.approvalStatus, // 기존 데이터 유지
            yearlyDetails: currentData.yearlyDetails, // 기존 데이터 유지
            yearlyWholeStatus: currentData.yearlyWholeStatus, // 기존 데이터 유지
            monthlyLeaves: response.monthlyLeaves, // 새로운 월별 데이터로 교체
          );

          // 프로바이더 상태 직접 업데이트
          ref.read(leaveManagementProvider.notifier).updateData(updatedData);

          print('✅ 전체보기 달력 월별 데이터 로드 완료: ${response.monthlyLeaves.length}개 휴가');

          // UI 즉시 업데이트를 위한 setState 호출
          if (mounted) {
            setState(() {
              // 달력 UI 강제 업데이트
            });
          }
        }
      } else {
        print('❌ 전체보기 달력 월별 데이터 로드 실패: ${response.error}');
      }
    } catch (e) {
      print('❌ 전체보기 달력 월별 데이터 로드 중 오류: $e');
    }
  }

  // 공휴일 데이터 로드
  Future<void> _loadHolidays(int year, int month) async {
    try {
      final response = await ApiService.getHolidays(year: year, month: month);
      if (response.isSuccess) {
        setState(() {
          _holidays = response.holidays;
        });
        print('🏝️ 전체보기 달력 공휴일 데이터 로드 완료: ${_holidays.length}개');
      } else {
        print('🏝️ 전체보기 달력 공휴일 데이터 로드 실패: ${response.error}');
      }
    } catch (e) {
      print('🏝️ 전체보기 달력 공휴일 데이터 로드 중 오류: $e');
    }
  }

  // 부서 휴가 현황 데이터 로드 (API 호출)
  Future<void> _loadDepartmentCalendarData(DateTime monthDate) async {
    setState(() {
      _isDepartmentDataLoading = true;
    });

    try {
      // 월 형식을 '2025-09' 형태로 변환
      final monthString =
          '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}';

      print('🏢 부서 휴가 현황 데이터 로드: $monthString');

      final response =
          await LeaveApiService.getTotalCalendar(month: monthString);

      if (response.isSuccess) {
        setState(() {
          _totalCalendarLeaves = response.monthlyLeaves;
          _departmentEmployees.clear();

          // 부서별 직원 그룹핑 (userId 기반으로 중복 제거)
          for (final leave in response.monthlyLeaves) {
            if (!_departmentEmployees.containsKey(leave.department)) {
              _departmentEmployees[leave.department] = [];
            }
            // userId가 있으면 userId로, 없으면 name으로 중복 체크
            final uniqueKey = leave.userId.isNotEmpty
                ? leave.userId
                : '${leave.name}|${leave.department}';
            final existingEmployee = _departmentEmployees[leave.department]!
                .any((emp) => emp['userId'] == uniqueKey);
            if (!existingEmployee) {
              _departmentEmployees[leave.department]!.add({
                'userId': uniqueKey,
                'name': leave.name,
              });
            }
          }

          // 부서별 직원 이름으로 정렬
          for (final dept in _departmentEmployees.keys) {
            _departmentEmployees[dept]!
                .sort((a, b) => a['name']!.compareTo(b['name']!));
          }
        });

        print('✅ 부서 휴가 현황 데이터 로드 완료: ${response.monthlyLeaves.length}개 휴가');
        print('📊 부서 수: ${_departmentEmployees.length}개');
        for (final entry in _departmentEmployees.entries) {
          final employeeNames =
              entry.value.map((emp) => emp['name']).join(", ");
          print('  ${entry.key}: $employeeNames');
        }
      } else {
        print('❌ 부서 휴가 현황 데이터 로드 실패: ${response.error}');
      }
    } catch (e) {
      print('❌ 부서 휴가 현황 데이터 로드 중 오류: $e');
    } finally {
      setState(() {
        _isDepartmentDataLoading = false;
      });
    }
  }

  // 공휴일인지 확인
  bool _isHoliday(DateTime date) {
    return _holidays.any((holiday) =>
        holiday.locDate.year == date.year &&
        holiday.locDate.month == date.month &&
        holiday.locDate.day == date.day);
  }

  // 공휴일 이름 가져오기
  String? _getHolidayName(DateTime date) {
    final holiday = _holidays.firstWhere(
      (h) =>
          h.locDate.year == date.year &&
          h.locDate.month == date.month &&
          h.locDate.day == date.day,
      orElse: () => Holiday(dateName: '', locDate: DateTime.now()),
    );
    return holiday.dateName.isNotEmpty ? holiday.dateName : null;
  }

  // 날짜 텍스트 색상 결정 (주말 및 공휴일 색상 적용)
  Color _getDateTextColor(DateTime date) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final weekday = date.weekday;

    // 공휴일은 빨간색으로 표시
    if (_isHoliday(date)) {
      return const Color(0xFFE53E3E); // 공휴일 빨간색
    } else if (weekday == DateTime.sunday) {
      return const Color(0xFFE53E3E); // 일요일 빨간색
    } else if (weekday == DateTime.saturday) {
      return const Color(0xFF3182CE); // 토요일 파란색
    } else {
      return isDarkTheme ? Colors.white : const Color(0xFF495057); // 평일 기본 색상
    }
  }

  Widget _buildFullMonthCalendar(DateTime monthDate) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF3A3A3A) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDarkTheme
                ? const Color(0xFF505050)
                : const Color(0xFFE9ECEF)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 요일 헤더
          Row(
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
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSunday
                          ? const Color(0xFFE53E3E) // 일요일 빨간색
                          : isSaturday
                              ? const Color(0xFF3182CE) // 토요일 파란색
                              : (isDarkTheme
                                  ? Colors.grey[400]
                                  : const Color(0xFF6C757D)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _buildFullMonthGrid(monthDate),
          ),
        ],
      ),
    );
  }

  Widget _buildFullMonthGrid(DateTime monthDate) {
    return Consumer(
      builder: (context, ref, child) {
        final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);
        final lastDayOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0);
        final firstDayWeekday = (firstDayOfMonth.weekday % 7);
        final today = DateTime.now();

        // 필터링된 휴가 데이터 사용 (프로바이더 상태 변화 감지)
        // _getFilteredMonthlyLeaves() 함수를 사용하여 일관된 필터링 적용
        final monthlyLeaves = _getFilteredMonthlyLeaves();

        List<List<Widget>> weeks = [];
        List<Widget> currentWeek = [];

        final prevMonthLastDay = DateTime(monthDate.year, monthDate.month, 0);
        for (int i = firstDayWeekday - 1; i >= 0; i--) {
          final day = prevMonthLastDay.day - i;
          currentWeek.add(_buildFullDateCell(
            day,
            DateTime(prevMonthLastDay.year, prevMonthLastDay.month, day),
            isCurrentMonth: false,
            today: today,
            monthlyLeaves: monthlyLeaves,
          ));
        }

        for (int day = 1; day <= lastDayOfMonth.day; day++) {
          final date = DateTime(monthDate.year, monthDate.month, day);
          currentWeek.add(_buildFullDateCell(
            day,
            date,
            isCurrentMonth: true,
            today: today,
            monthlyLeaves: monthlyLeaves,
          ));

          if (currentWeek.length == 7) {
            weeks.add(List.from(currentWeek));
            currentWeek.clear();
          }
        }

        if (currentWeek.isNotEmpty) {
          final nextMonth = DateTime(monthDate.year, monthDate.month + 1, 1);
          int nextDay = 1;
          while (currentWeek.length < 7) {
            currentWeek.add(_buildFullDateCell(
              nextDay,
              DateTime(nextMonth.year, nextMonth.month, nextDay),
              isCurrentMonth: false,
              today: today,
              monthlyLeaves: monthlyLeaves,
            ));
            nextDay++;
          }
          weeks.add(currentWeek);
        }

        return Column(
          children: weeks.map((week) {
            return Expanded(
              child: Row(
                children: week,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFullDateCell(
    int day,
    DateTime date, {
    required bool isCurrentMonth,
    required DateTime today,
    required List<MonthlyLeave> monthlyLeaves,
  }) {
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final isSelected = date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day;

    // 해당 날짜의 휴가 정보들 수집 (end_date를 포함하지 않는 날짜 범위로 비교)
    final dayLeaves = monthlyLeaves.where((leave) {
      // UTC 시간을 로컬 날짜로 변환하여 비교
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

    final hasLeave = dayLeaves.isNotEmpty;

    // 상태별 개수 계산 (대소문자 무관 - 메인달력과 동일)
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

    // 휴가 상태에 따른 색상 결정 (우선순위: pending > approved > rejected > cancelled - 메인달력과 동일)
    Color? leaveColor;
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

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDate = date;
            _updateSelectedDateDetails();
            // 부서 현황 모드에서는 슬라이드 패널 표시
            if (!_isMyVacationView) {
              _isDetailPanelVisible = true;
            }
          });
          widget.onDateSelected(date);
        },
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            margin: const EdgeInsets.all(0.5),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF1E88E5)
                  : isToday
                      ? const Color(0xFF1E88E5).withValues(alpha: 0.3)
                      : (hasLeave && isCurrentMonth && leaveColor != null)
                          ? leaveColor.withValues(alpha: 0.15)
                          : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              children: [
                // 중앙에 날짜 텍스트 및 공휴일 정보
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Builder(
                        builder: (context) {
                          final isDarkTheme =
                              Theme.of(context).brightness == Brightness.dark;
                          return Text(
                            day.toString(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected || isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: !isCurrentMonth
                                  ? (isDarkTheme
                                      ? Colors.grey[500]
                                      : Colors.grey[400])
                                  : isSelected
                                      ? Colors.white
                                      : isToday
                                          ? Colors.white
                                          : _getDateTextColor(date),
                            ),
                          );
                        },
                      ),
                      // 공휴일 이름 표시 (현재 월이고 공휴일인 경우)
                      if (isCurrentMonth && _isHoliday(date))
                        Builder(
                          builder: (context) {
                            final isDarkTheme =
                                Theme.of(context).brightness == Brightness.dark;
                            return Text(
                              _getHolidayName(date) ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: !isCurrentMonth
                                    ? (isDarkTheme
                                        ? Colors.grey[500]
                                        : Colors.grey[400])
                                    : isSelected
                                        ? Colors.white.withValues(alpha: 0.8)
                                        : isToday
                                            ? Colors.white
                                                .withValues(alpha: 0.8)
                                            : _getDateTextColor(date)
                                                .withValues(alpha: 0.8),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                    ],
                  ),
                ),
                // 휴가인 인원 이름 표시 (하단에 작은 글자로)
                if (hasLeave && isCurrentMonth)
                  Positioned(
                    left: 2,
                    right: 2,
                    bottom: 2,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 40),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: dayLeaves.map((leave) {
                            // 승인된 건만 표시
                            if (leave.status.toUpperCase() != 'APPROVED')
                              return const SizedBox.shrink();

                            final isDarkTheme =
                                Theme.of(context).brightness == Brightness.dark;
                            final nameColor = (isSelected || isToday)
                                ? Colors.white
                                : (isDarkTheme
                                    ? Colors.white
                                    : Colors.black); // 다크테마일 때 흰색, 라이트테마일 때 검정색

                            // 모드에 따라 다른 방식으로 이름과 부서 정보 표시
                            String displayText;
                            if (_isMyVacationView) {
                              // 내 휴가 내역 모드: reason 필드 사용
                              displayText = leave.reason;
                            } else {
                              // 부서 휴가 현황 모드: reason 필드에서 이름과 부서 추출
                              // 형식: "홍길동님의 연차 (부서명)" 또는 "홍길동님의 연차"
                              final reasonText = leave.reason;
                              final nameMatch =
                                  RegExp(r'^(.+?)님의').firstMatch(reasonText);
                              final deptMatch =
                                  RegExp(r'\(([^)]+)\)').firstMatch(reasonText);

                              if (nameMatch != null) {
                                final name = nameMatch.group(1) ?? '알 수 없음';
                                String department = '';

                                // 부서 정보가 reason에 포함되어 있으면 사용
                                if (deptMatch != null) {
                                  department = deptMatch.group(1) ?? '';
                                } else {
                                  // 부서 정보가 없으면 날짜와 이름으로 정확히 매칭
                                  final matchingLeave =
                                      _totalCalendarLeaves.firstWhere(
                                    (totalLeave) =>
                                        totalLeave.name == name &&
                                        totalLeave.startDate ==
                                            leave.startDate &&
                                        totalLeave.endDate == leave.endDate,
                                    orElse: () => TotalCalendarLeave(
                                      userId: '',
                                      name: name,
                                      department: '',
                                      startDate: leave.startDate,
                                      endDate: leave.endDate,
                                      leaveType: leave.leaveType,
                                    ),
                                  );
                                  department = matchingLeave.department;
                                }

                                displayText = department.isNotEmpty
                                    ? '${name}(${department})'
                                    : name;
                              } else {
                                displayText = reasonText;
                              }
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 1),
                              child: Text(
                                displayText,
                                style: TextStyle(
                                  fontSize: 10, // 글자 크기 증가 (9 -> 10)
                                  fontWeight: FontWeight.w500,
                                  color: nameColor,
                                  height: 1.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalDateDetails() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.event_note,
                color: Color(0xFF1E88E5),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _selectedDateDetails.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '선택된 날짜에\n휴가 일정이 없습니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color:
                              isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _selectedDateDetails.length,
                  itemBuilder: (context, index) {
                    final detail = _selectedDateDetails[index];
                    return _buildModalDetailItem(detail);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildModalDetailItem(Map<String, Object> detail) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final statusString = (detail['status'] as String?) ?? 'REQUESTED';
    print('📝 휴가내역 상태: $statusString');
    final statusColor = statusString == 'HOLIDAY'
        ? const Color(0xFFE53E3E) // 공휴일: 빨간색
        : {
              LeaveRequestStatus.pending: const Color(0xFFFF8C00),
              LeaveRequestStatus.approved: const Color(0xFF20C997),
              LeaveRequestStatus.rejected: const Color(0xFFDC3545),
              LeaveRequestStatus.cancelled: const Color(0xFF6C757D),
            }[_convertStatusToEnum(statusString)] ??
            const Color(0xFF1E88E5);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkTheme
            ? statusColor.withValues(alpha: 0.1)
            : statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: statusColor.withValues(alpha: isDarkTheme ? 0.3 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  statusString == 'HOLIDAY'
                      ? (detail['employeeName'] as String?) ?? '공휴일'
                      : _convertStatusToEnum(statusString).label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (detail['vacationType'] as String?) ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
                  ),
                ),
              ),
            ],
          ),
          if (statusString != 'HOLIDAY' &&
              (detail['reason'] as String?) != null &&
              (detail['reason'] as String).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '사유: ${detail['reason'] as String}',
              style: TextStyle(
                fontSize: 10,
                color: isDarkTheme ? Colors.grey[400] : const Color(0xFF6C757D),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (statusString != 'HOLIDAY' &&
              detail['startDate'] != null &&
              detail['endDate'] != null) ...[
            const SizedBox(height: 4),
            Text(
              '기간: ${DateFormat('yyyy.MM.dd').format(detail['startDate'] as DateTime)} ~ ${DateFormat('yyyy.MM.dd').format(detail['endDate'] as DateTime)}',
              style: TextStyle(
                fontSize: 10,
                color: isDarkTheme ? Colors.grey[400] : const Color(0xFF6C757D),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 뷰 모드 전환 버튼 빌더
  Widget _buildViewModeButton(String title, bool isMyVacation) {
    final isSelected = _isMyVacationView == isMyVacation;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isMyVacationView = isMyVacation;
          if (!isMyVacation) {
            // 부서 현황 모드로 전환할 때 초기화 및 API 호출
            _selectedDepartments.clear();
            _selectedEmployees.clear();
            _expandedDepartments.clear();
            _loadDepartmentCalendarData(_currentCalendarDate);
          }
          _updateSelectedDateDetails();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkTheme
                  ? const Color(0xFF4A4A4A)
                  : const Color(0xFF1E88E5))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDarkTheme ? Colors.grey[400] : const Color(0xFF6C757D)),
          ),
        ),
      ),
    );
  }

  // 부서 선택 위젯
  Widget _buildDepartmentSelector() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkTheme
                  ? const Color(0xFF3A3A3A)
                  : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(
                    color: isDarkTheme
                        ? const Color(0xFF505050)
                        : const Color(0xFFE2E8F0),
                    width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: Color(0xFF1E88E5),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '부서 선택',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkTheme ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          // 컨텐츠
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // 조직도 체크박스들
                  Expanded(child: _buildDepartmentCheckboxes()),
                  const SizedBox(height: 16),
                  // 전체 선택/해제 버튼
                  Row(
                    children: [
                      _buildSelectAllButton(),
                      const SizedBox(width: 12),
                      _buildSelectNoneButton(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 부서 체크박스 리스트 (동적으로 생성)
  Widget _buildDepartmentCheckboxes() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    if (_isDepartmentDataLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_departmentEmployees.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            '부서 데이터를 불러오는 중...\n또는 휴가 일정이 없습니다.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: isDarkTheme ? Colors.grey[400] : Colors.grey),
          ),
        ),
      );
    }

    // 부서 목록을 알파벳 순으로 정렬
    final sortedDepartments = _departmentEmployees.keys.toList()..sort();

    return SingleChildScrollView(
      child: Column(
        children: sortedDepartments.map((deptName) {
          final employees = _departmentEmployees[deptName]!;
          final isDeptSelected = _selectedDepartments.contains(deptName);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isDeptSelected
                  ? const Color(0xFF1E88E5).withValues(alpha: 0.08)
                  : (isDarkTheme
                      ? const Color(0xFF3A3A3A)
                      : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDeptSelected
                    ? const Color(0xFF1E88E5).withValues(alpha: 0.3)
                    : (isDarkTheme
                        ? const Color(0xFF505050)
                        : const Color(0xFFE2E8F0)),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                // 부서 헤더
                Row(
                  children: [
                    // 체크박스 영역 (전체 선택/해제)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                        onTap: () {
                          _toggleDepartmentSelection(deptName);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isDeptSelected
                                  ? const Color(0xFF1E88E5)
                                  : Colors.transparent,
                              border: Border.all(
                                color: isDeptSelected
                                    ? const Color(0xFF1E88E5)
                                    : (isDarkTheme
                                        ? Colors.grey.shade500
                                        : const Color(0xFFCBD5E1)),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: isDeptSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 14,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    // 부서 정보 영역 (드롭다운 토글)
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          onTap: () {
                            _toggleDepartmentExpansion(deptName);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                // 부서 아이콘
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: (isDarkTheme
                                            ? Colors.grey.shade600
                                            : const Color(0xFF64748B))
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.business_center,
                                    color: isDarkTheme
                                        ? Colors.grey[300]
                                        : const Color(0xFF64748B),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // 부서 정보
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        deptName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDeptSelected
                                              ? const Color(0xFF1E88E5)
                                              : (isDarkTheme
                                                  ? Colors.white
                                                  : const Color(0xFF334155)),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${employees.length}명',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDarkTheme
                                              ? Colors.grey[400]
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // 확장/축소 아이콘
                                Icon(
                                  _isDepartmentExpanded(deptName)
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: isDarkTheme
                                      ? Colors.grey[400]
                                      : const Color(0xFF64748B),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // 직원 목록 (부서가 확장된 경우에만 표시)
                if (_isDepartmentExpanded(deptName))
                  ...employees.map((employee) {
                    final userId = employee['userId']!;
                    final employeeName = employee['name']!;
                    final isEmpSelected = _selectedEmployees.contains(userId);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          _toggleEmployeeSelection(userId);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isEmpSelected
                                ? const Color(0xFF1E88E5)
                                    .withValues(alpha: 0.05)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 32), // 들여쓰기
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: isEmpSelected
                                      ? const Color(0xFF1E88E5)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isEmpSelected
                                        ? const Color(0xFF1E88E5)
                                        : (isDarkTheme
                                            ? const Color(0xFF505050)
                                            : const Color(0xFFCBD5E1)),
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: isEmpSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 10,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.person,
                                color: isDarkTheme
                                    ? Colors.grey[400]
                                    : const Color(0xFF64748B),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                employeeName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isEmpSelected
                                      ? const Color(0xFF1E88E5)
                                      : (isDarkTheme
                                          ? Colors.grey[300]
                                          : const Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // 부서 선택/해제 처리
  void _toggleDepartmentSelection(String deptName) {
    setState(() {
      if (_selectedDepartments.contains(deptName)) {
        _selectedDepartments.remove(deptName);
        // 부서 해제 시 해당 부서 직원들도 모두 해제
        final employees = _departmentEmployees[deptName] ?? [];
        for (final emp in employees) {
          _selectedEmployees.remove(emp['userId']!);
        }
      } else {
        _selectedDepartments.add(deptName);
        // 부서 선택 시 해당 부서 직원들도 모두 선택
        final employees = _departmentEmployees[deptName] ?? [];
        _selectedEmployees.addAll(employees.map((emp) => emp['userId']!));
      }
      _updateSelectedDateDetails();
    });
  }

  // 부서 확장/축소 처리
  void _toggleDepartmentExpansion(String deptName) {
    setState(() {
      if (_expandedDepartments.contains(deptName)) {
        _expandedDepartments.remove(deptName);
      } else {
        _expandedDepartments.add(deptName);
      }
    });
  }

  // 부서 확장 상태 확인
  bool _isDepartmentExpanded(String deptName) {
    return _expandedDepartments.contains(deptName);
  }

  // 개별 직원 선택/해제 처리 (userId 기반)
  void _toggleEmployeeSelection(String userId) {
    setState(() {
      if (_selectedEmployees.contains(userId)) {
        _selectedEmployees.remove(userId);
      } else {
        _selectedEmployees.add(userId);
      }
      _updateSelectedDateDetails();
    });
  }

  // 선택된 직원들의 휴가 데이터만 필터링해서 반환
  List<MonthlyLeave> _getFilteredMonthlyLeaves() {
    if (_isMyVacationView) {
      // 내 휴가 내역 모드: 프로바이더에서 데이터를 watch하여 실시간 업데이트
      final leaveManagementState = ref.watch(leaveManagementProvider);
      return leaveManagementState.data?.monthlyLeaves ?? [];
    } else {
      // 부서 휴가 현황 모드: 선택된 직원들의 휴가만 반환
      if (_selectedEmployees.isEmpty) {
        return []; // 선택된 직원이 없으면 빈 목록
      }

      return _totalCalendarLeaves
          .where((leave) {
            // userId가 있으면 userId로, 없으면 name|department 조합으로 비교
            final uniqueKey = leave.userId.isNotEmpty
                ? leave.userId
                : '${leave.name}|${leave.department}';
            return _selectedEmployees.contains(uniqueKey);
          })
          .map((totalLeave) => _convertToMonthlyLeave(totalLeave))
          .toList();
    }
  }

  // TotalCalendarLeave를 MonthlyLeave로 변환
  MonthlyLeave _convertToMonthlyLeave(TotalCalendarLeave totalLeave) {
    return MonthlyLeave(
      status: 'APPROVED', // 부서 현황에서는 승인된 휴가만 표시
      leaveType: totalLeave.leaveType,
      startDate: totalLeave.startDate,
      endDate: totalLeave.endDate,
      halfDaySlot: '', // 부서 현황에서는 반차 정보 없음
      // 부서 정보를 포함하여 동명이인 구분 (형식: "홍길동님의 연차 (부서명)")
      reason:
          '${totalLeave.name}님의 ${totalLeave.leaveType} (${totalLeave.department})',
      rejectMessage: '', // 부서 현황에서는 반려 메시지 없음
    );
  }

  // 전체 선택 버튼
  Widget _buildSelectAllButton() {
    return Expanded(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                _selectedDepartments = Set.from(_departmentEmployees.keys);
                _selectedEmployees.clear();
                for (final employees in _departmentEmployees.values) {
                  _selectedEmployees
                      .addAll(employees.map((emp) => emp['userId']!));
                }
                _updateSelectedDateDetails();
              });
            },
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '전체 선택',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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

  // 선택 해제 버튼
  Widget _buildSelectNoneButton() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color:
              isDarkTheme ? const Color(0xFF3A3A3A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isDarkTheme ? const Color(0xFF505050) : const Color(0xFFCBD5E1),
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                _selectedDepartments.clear();
                _selectedEmployees.clear(); // 직원 선택도 모두 해제
                _updateSelectedDateDetails();
              });
            },
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.remove_circle_outline_rounded,
                    color: isDarkTheme
                        ? Colors.grey[400]
                        : const Color(0xFF64748B),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '선택 해제',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDarkTheme
                          ? Colors.grey[400]
                          : const Color(0xFF64748B),
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

  // 우측 패널 (부서 현황 모드)
  Widget _buildRightPanel() {
    return ClipRect(
      child: Stack(
        children: [
          // 부서 선택 패널 (항상 표시)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: _isDetailPanelVisible ? -350 : 0, // 슬라이드 패널이 보이면 왼쪽으로 이동
            right: 0,
            top: 0,
            bottom: 0,
            child: ClipRect(child: _buildDepartmentSelector()),
          ),
          // 상세 내역 패널 (필요할 때만 생성)
          if (_isDetailPanelVisible)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: 0, // 슬라이드 인
              right: 0,
              top: 0,
              bottom: 0,
              child: ClipRect(child: _buildSlideDetailPanel()),
            ),
        ],
      ),
    );
  }

  // 슬라이드 상세 패널 (부서 현황 모드 전용)
  Widget _buildSlideDetailPanel() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return ClipRect(
      child: Container(
        decoration: BoxDecoration(
          color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkTheme ? 0.3 : 0.1),
              blurRadius: 10,
              offset: const Offset(-2, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // 패널 헤더
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkTheme
                    ? const Color(0xFF3A3A3A)
                    : const Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(
                      color: isDarkTheme
                          ? const Color(0xFF505050)
                          : const Color(0xFFE2E8F0),
                      width: 1),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 매우 좁은 공간 (50px 미만) - 아이콘과 닫기 버튼만
                  if (constraints.maxWidth < 50) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF1E88E5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.event_note_rounded,
                            color: Color(0xFF1E88E5),
                            size: 12,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isDetailPanelVisible = false;
                            });
                          },
                          child: Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.close_rounded,
                              color: isDarkTheme
                                  ? Colors.grey[400]
                                  : const Color(0xFF64748B),
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  // 좁은 공간 (150px 미만) - 간소한 레이아웃
                  if (constraints.maxWidth < 150) {
                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF1E88E5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.event_note_rounded,
                            color: Color(0xFF1E88E5),
                            size: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '휴가',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDarkTheme
                                  ? Colors.white
                                  : Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isDetailPanelVisible = false;
                            });
                          },
                          child: Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.close_rounded,
                              color: isDarkTheme
                                  ? Colors.grey[400]
                                  : const Color(0xFF64748B),
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  // 중간 공간 (250px 미만) - 한 줄 레이아웃
                  if (constraints.maxWidth < 250) {
                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF1E88E5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.event_note_rounded,
                            color: Color(0xFF1E88E5),
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '휴가 내역',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDarkTheme
                                  ? Colors.white
                                  : Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isDetailPanelVisible = false;
                            });
                          },
                          child: Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.close_rounded,
                              color: isDarkTheme
                                  ? Colors.grey[400]
                                  : const Color(0xFF64748B),
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  // 넓은 공간 - 일반적인 레이아웃
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.event_note_rounded,
                          color: Color(0xFF1E88E5),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '휴가 상세 내역',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDarkTheme
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkTheme
                                    ? Colors.grey[400]
                                    : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isDetailPanelVisible = false;
                          });
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDarkTheme
                              ? Colors.grey[400]
                              : const Color(0xFF64748B),
                          size: 20,
                        ),
                        tooltip: '패널 닫기',
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  );
                },
              ),
            ),
            // 패널 내용
            Expanded(
              child: ClipRect(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: _buildSlideDetailContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 슬라이드 패널 내용
  Widget _buildSlideDetailContent() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        // 너무 좁거나 높이가 부족한 경우 최소 내용만 표시
        if (constraints.maxWidth < 100 || constraints.maxHeight < 100) {
          return const Center(
            child: Icon(
              Icons.more_horiz,
              color: Color(0xFF94A3B8),
              size: 24,
            ),
          );
        }

        if (_selectedDateDetails.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkTheme
                        ? const Color(0xFF3A3A3A)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_today_outlined,
                    size: constraints.maxHeight < 200 ? 32 : 48,
                    color: isDarkTheme
                        ? Colors.grey[500]
                        : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  constraints.maxWidth < 200
                      ? '휴가 없음'
                      : '선택된 날짜에\n휴가 일정이 없습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: constraints.maxWidth < 200 ? 12 : 14,
                    color: isDarkTheme
                        ? Colors.grey[400]
                        : const Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: _selectedDateDetails.length,
          separatorBuilder: (context, index) => SizedBox(
            height: constraints.maxHeight < 300 ? 8 : 12,
          ),
          itemBuilder: (context, index) {
            final detail = _selectedDateDetails[index];
            return _buildSlideDetailCard(detail);
          },
        );
      },
    );
  }

  // 슬라이드 패널용 상세 카드
  Widget _buildSlideDetailCard(Map<String, dynamic> detail) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    // 부서휴가현황 모드에서는 승인됨 상태 배지를 제거하고 더 깔끔하게 표시
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            const Color(0xFF1E88E5).withValues(alpha: isDarkTheme ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF1E88E5)
                .withValues(alpha: isDarkTheme ? 0.3 : 0.2),
            width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 첫 번째 줄: 신청자명과 휴가 유형
          Row(
            children: [
              // 신청자명 (실제 API에서 받은 이름)
              Text(
                (detail['employeeName'] as String?) ?? '알 수 없음',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDarkTheme ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 8),
              // 부서 정보 (이름 오른쪽)
              if ((detail['department'] as String?) != null &&
                  (detail['department'] as String).isNotEmpty)
                Text(
                  '(${detail['department'] as String})',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkTheme
                        ? Colors.grey[400]
                        : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const Spacer(),
              // 휴가 유형
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  (detail['vacationType'] as String?) ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF1E88E5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 두 번째 줄: 기간 정보 (더 크고 굵게)
          if (detail['startDate'] != null && detail['endDate'] != null)
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_formatDateFull(detail['startDate'] as DateTime)} ~ ${_formatDateFull(detail['endDate'] as DateTime)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDarkTheme
                        ? Colors.grey[300]
                        : const Color(0xFF374151),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // 날짜 포맷팅 헬퍼 함수 (전체 형태 - 년월일 + 요일)
  String _formatDateFull(dynamic date) {
    if (date == null) return '';

    DateTime dateTime;
    if (date is DateTime) {
      dateTime = date;
    } else if (date is String) {
      try {
        dateTime = DateTime.parse(date);
      } catch (e) {
        return date.toString();
      }
    } else {
      return date.toString();
    }

    // 요일 배열
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday =
        weekdays[dateTime.weekday - 1]; // DateTime.weekday는 1(월요일)부터 7(일요일)

    return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')} ($weekday)';
  }

  void _updateSelectedDateDetails() {
    final monthlyLeaves = _getFilteredMonthlyLeaves();

    _selectedDateDetails = monthlyLeaves.where((leave) {
      // 날짜 부분만 비교하여 정확한 범위 계산
      final startDateLocal = DateTime(
          leave.startDate.year, leave.startDate.month, leave.startDate.day);
      final endDateLocal =
          DateTime(leave.endDate.year, leave.endDate.month, leave.endDate.day);
      final selectedDateLocal =
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

      // endDate까지 포함하여 표시 (inclusive)
      return (selectedDateLocal.isAtSameMomentAs(startDateLocal) ||
          selectedDateLocal.isAtSameMomentAs(endDateLocal) ||
          (selectedDateLocal.isAfter(startDateLocal) &&
              selectedDateLocal.isBefore(endDateLocal)));
    }).map((leave) {
      // 부서 휴가 현황 모드에서는 이미 변환된 데이터에서 이름과 부서 정보 추출
      String employeeName = '신청자';
      String department = '';
      if (!_isMyVacationView) {
        // reason 필드에서 이름과 부서 추출
        // 형식: "홍길동님의 연차 (부서명)" 또는 "홍길동님의 연차"
        final reasonText = leave.reason;
        final nameMatch = RegExp(r'^(.+?)님의').firstMatch(reasonText);
        final deptMatch = RegExp(r'\(([^)]+)\)').firstMatch(reasonText);

        if (nameMatch != null) {
          employeeName = nameMatch.group(1) ?? '신청자';
        }

        // 부서 정보가 reason에 포함되어 있으면 사용
        if (deptMatch != null) {
          department = deptMatch.group(1) ?? '';
        } else {
          // 부서 정보가 없으면 날짜와 이름으로 정확히 매칭
          final matchingLeave = _totalCalendarLeaves.firstWhere(
            (totalLeave) =>
                totalLeave.name == employeeName &&
                totalLeave.startDate == leave.startDate &&
                totalLeave.endDate == leave.endDate,
            orElse: () => TotalCalendarLeave(
              userId: '',
              name: employeeName,
              department: '',
              startDate: leave.startDate,
              endDate: leave.endDate,
              leaveType: leave.leaveType,
            ),
          );
          department = matchingLeave.department;
        }

        print(
            '🔍 부서 휴가 현황 매칭: $employeeName (${department}) - ${leave.leaveType}');
      }

      return <String, Object>{
        'status': leave.status,
        'vacationType': leave.leaveType,
        'employeeName': employeeName, // 실제 API에서 받은 이름 사용
        'department': department, // 부서 정보 추가
        'reason': leave.reason,
        'startDate': leave.startDate,
        'endDate': leave.endDate,
        'halfDaySlot': '',
        'jobPosition': '',
      };
    }).toList();

    // 상태별 우선순위에 따라 정렬: 대기중 → 승인됨 → 반려됨 → 취소됨 (메인달력과 동일)
    _selectedDateDetails.sort((a, b) {
      final statusPriority = {
        'REQUESTED': 1,
        'PENDING': 1,
        '대기': 1,
        '대기중': 1,
        'APPROVED': 2,
        '승인': 2,
        '승인됨': 2,
        'REJECTED': 3,
        '반려': 3,
        '반려됨': 3,
        'CANCELLED': 4,
        '취소': 4,
        '취소됨': 4,
      };

      final statusA = a['status']?.toString().toUpperCase() ?? '';
      final statusB = b['status']?.toString().toUpperCase() ?? '';

      final priorityA = statusPriority[statusA] ?? 5;
      final priorityB = statusPriority[statusB] ?? 5;

      return priorityA.compareTo(priorityB);
    });

    // 선택된 날짜가 공휴일인 경우 공휴일 정보 추가
    final holidayName = _getHolidayName(_selectedDate);
    if (holidayName != null && holidayName.isNotEmpty) {
      _selectedDateDetails.insert(0, <String, Object>{
        'status': 'HOLIDAY',
        'vacationType': '공휴일',
        'employeeName': holidayName,
        'department': '',
        'jobPosition': '',
        'reason': '공휴일',
        'startDate': _selectedDate,
        'endDate': _selectedDate,
        'halfDaySlot': '',
      });
    }
  }

  // 메인달력과 동일한 상태 변환 함수
  LeaveRequestStatus _convertStatusToEnum(String status) {
    print('🔍 상태 변환: $status');
    switch (status.toUpperCase()) {
      case 'REQUESTED':
      case 'PENDING':
      case '대기':
      case '대기중':
        return LeaveRequestStatus.pending;
      case 'APPROVED':
      case '승인':
      case '승인됨':
        return LeaveRequestStatus.approved;
      case 'REJECTED':
      case '반려':
      case '반려됨':
        return LeaveRequestStatus.rejected;
      case 'CANCELLED':
      case '취소':
      case '취소됨':
        return LeaveRequestStatus.cancelled;
      default:
        print('⚠️ 알 수 없는 상태값: $status, PENDING으로 설정');
        return LeaveRequestStatus.pending;
    }
  }
}
