import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:ASPN_AI_AGENT/features/leave/leave_models.dart';
import 'package:ASPN_AI_AGENT/features/leave/leave_providers_simple.dart';
import 'package:ASPN_AI_AGENT/features/leave/admin_calendar_sidebar.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:ASPN_AI_AGENT/shared/services/leave_api_service.dart';
import 'package:ASPN_AI_AGENT/shared/services/api_service.dart';
import 'package:ASPN_AI_AGENT/models/leave_management_models.dart';
import 'package:ASPN_AI_AGENT/ui/screens/leave_management_screen.dart'; // 일반사용자 휴가관리 화면 추가
import 'package:ASPN_AI_AGENT/ui/screens/chat_home_page_v5.dart';

// PageController dispose를 위한 mixin
mixin PageControllerDisposeMixin {
  late PageController _pageController;

  void initializePageController(int initialPage) {
    _pageController = PageController(initialPage: initialPage);
  }

  void disposePageController() {
    _pageController.dispose();
  }
}

class AdminLeaveApprovalScreen extends ConsumerStatefulWidget {
  const AdminLeaveApprovalScreen({super.key});

  @override
  ConsumerState<AdminLeaveApprovalScreen> createState() =>
      _AdminLeaveApprovalScreenState();
}

class _AdminLeaveApprovalScreenState
    extends ConsumerState<AdminLeaveApprovalScreen>
    with TickerProviderStateMixin {
  String _selectedTab = 'pending'; // 'pending', 'all'
  String? _statusFilter; // 'REQUESTED', 'APPROVED', 'REJECTED', null for all
  int _selectedYear = DateTime.now().year; // 선택된 연도

  DateTime _selectedDate = DateTime.now();
  DateTime _currentCalendarDate = DateTime.now();
  List<Map<String, Object>> _selectedDateDetails = [];
  late PageController _pageController;

  // 공휴일 데이터
  List<Holiday> _holidays = [];

  bool _isSidebarExpanded = false;
  bool _isSidebarPinned = false;
  bool _isInitialLoad = true; // 초기 로드인지 구분하는 플래그
  bool _hideCancelledItems = false; // 취소건 숨기기 여부

  // 페이지네이션 관련 변수
  int _currentPage = 0;
  static const int _itemsPerPage = 5;

  @override
  void initState() {
    super.initState();
    // 2020년 1월부터 현재 월까지의 개월 수 계산
    final monthsFromBase = (_currentCalendarDate.year - 2020) * 12 +
        (_currentCalendarDate.month - 1);
    _pageController = PageController(initialPage: monthsFromBase);
    _updateSelectedDateDetails();

    // 관리자 관리 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUserId =
          ref.read(userIdProvider) ?? 'user_001'; // 실제 로그인된 사용자 ID 사용
      ref.read(adminManagementProvider.notifier).loadAdminManagementData(
            approverId: currentUserId, // 현재 로그인한 사용자 ID 사용
            month: DateTime.now().toString().substring(0, 7), // YYYY-MM 형식
          );

      // 공휴일 데이터 로드
      _loadHolidays(_currentCalendarDate.year, _currentCalendarDate.month);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 연도별 데이터 로드
  Future<void> _loadApprovalDataByYear(int year) async {
    try {
      final currentUserId = ref.read(userIdProvider) ?? 'user_001';

      print('🔍 [Admin Screen] 연도별 데이터 로드 시작: $year');

      final response = await LeaveApiService.getAdminYearlyData(
        approverId: currentUserId,
        year: year.toString(),
      );

      if (response.error == null) {
        print('🔍 [Admin Screen] 연도별 데이터 로드 성공');
        // Provider를 통해 상태 업데이트
        ref
            .read(adminManagementProvider.notifier)
            .updateManagementData(response);
      } else {
        print('🔍 [Admin Screen] 연도별 데이터 로드 실패: ${response.error}');
      }
    } catch (e) {
      print('🔍 [Admin Screen] 연도별 데이터 로드 중 오류 발생: $e');
    }
  }

  // Korean day name formatter helper method
  String _formatDateWithKoreanDay(DateTime date) {
    const koreanDays = ['일', '월', '화', '수', '목', '금', '토'];
    final day = koreanDays[date.weekday % 7];
    return '${DateFormat('MM.dd').format(date)}($day)';
  }

  // 연도 선택 드롭다운 위젯
  Widget _buildYearDropdown() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // 2026년부터 5년 전까지의 연도 목록 생성 (2026, 2025, 2024, 2023, 2022, 2021)
    final years = List.generate(6, (index) => 2026 - index);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      constraints: const BoxConstraints(maxHeight: 28),
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF404040) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color:
              isDarkTheme ? const Color(0xFF555555) : const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: DropdownButton<int>(
        value: _selectedYear,
        isDense: true,
        isExpanded: false,
        items: years.map((year) {
          return DropdownMenuItem<int>(
            value: year,
            child: Text(
              '$year년',
              style: TextStyle(
                fontSize: 12,
                color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
              ),
            ),
          );
        }).toList(),
        onChanged: (int? newValue) async {
          if (newValue != null) {
            setState(() {
              _selectedYear = newValue;
            });
            // 연도별 데이터 로드
            await _loadApprovalDataByYear(newValue);
          }
        },
        underline: const SizedBox(),
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
          size: 16,
        ),
        style: TextStyle(
          fontSize: 12,
          color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // 승인자 여부 확인 - 일반사용자는 접근 불가
    final isApprover = ref.read(approverProvider);

    if (!isApprover) {
      // 일반사용자인 경우 일반 휴가관리 화면으로 리다이렉트
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LeaveManagementScreen(),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('관리자 권한이 필요합니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      });
      // 리다이렉트 중 로딩 화면 표시
      return Scaffold(
        appBar: AppBar(
          title: const Text('관리자 - 휴가 결재 관리'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        _exitToChatHome();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor:
              isDarkTheme ? const Color(0xFF2D2D2D) : const Color(0xFF9C88D4),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            '관리자 - 휴가 결재 관리',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          actions: [
            _buildFilterButtons(),
          ],
        ),
        body: Stack(
          children: [
            // Main content with dynamic padding for sidebar
            AnimatedPadding(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: EdgeInsets.only(
                left: _isSidebarExpanded ? 285 : 50,
              ),
              child: Container(
                color: isDarkTheme
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFFF8F9FA),
                child: Column(
                  children: [
                    // 상단 통계 카드
                    _buildStatsHeader(),
                    // 메인 컨텐츠 영역 (50:50 분할)
                    Expanded(
                      child: Row(
                        children: [
                          // 왼쪽: 결재 목록 (50%)
                          Expanded(
                            flex: 1,
                            child: Container(
                              margin:
                                  const EdgeInsets.only(left: 16, bottom: 16),
                              child: _buildApprovalList(),
                            ),
                          ),
                          // 오른쪽: 달력 영역 (50%)
                          Expanded(
                            flex: 1,
                            child: Container(
                              margin: const EdgeInsets.only(
                                  left: 8, right: 16, bottom: 16),
                              child: _buildCalendarSection(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Dynamic sidebar positioned on the left
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: AdminCalendarSidebar(
                isExpanded: _isSidebarExpanded,
                isPinned: _isSidebarPinned,
                onHover: () {
                  setState(() {
                    _isSidebarExpanded = true;
                  });
                },
                onExit: () {
                  if (!_isSidebarPinned) {
                    setState(() {
                      _isSidebarExpanded = false;
                    });
                  }
                },
                onPinToggle: () {
                  setState(() {
                    _isSidebarPinned = !_isSidebarPinned;
                    if (_isSidebarPinned) {
                      _isSidebarExpanded = true;
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exitToChatHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const ChatHomePage()),
      (route) => false,
    );
  }

  Widget _buildFilterButtons() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 휴가관리 버튼 (일반사용자 화면으로 이동)
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const LeaveManagementScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkTheme
                  ? Colors.grey.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.2),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(
              Icons.beach_access,
              size: 16,
            ),
            label: const Text(
              '휴가관리',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildTabButton('대기 중', 'pending'),
          const SizedBox(width: 8),
          _buildTabButton('전체', 'all'),
          const SizedBox(width: 8),
          // 취소건 숨기기 토글 버튼
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _hideCancelledItems = !_hideCancelledItems;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _hideCancelledItems
                  ? (isDarkTheme ? const Color(0xFF3A3A3A) : Colors.white)
                  : (isDarkTheme
                      ? Colors.grey.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.2)),
              foregroundColor: _hideCancelledItems
                  ? (isDarkTheme ? Colors.white : const Color(0xFF9C88D4))
                  : Colors.white,
              elevation: _hideCancelledItems ? 2 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: Icon(
              _hideCancelledItems ? Icons.visibility_off : Icons.visibility,
              size: 16,
            ),
            label: const Text(
              '취소건 숨기기',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, String tabKey) {
    final isSelected = _selectedTab == tabKey;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedTab = tabKey;
          // 탭 변경 시 상태 필터 초기화
          if (tabKey == 'pending') {
            _statusFilter = 'REQUESTED'; // 대기중 탭일 때는 REQUESTED 필터
          } else {
            _statusFilter = null; // 전체 탭일 때는 필터 해제
          }
          _currentPage = 0; // 페이지네이션 초기화
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? (isDarkTheme ? const Color(0xFF3A3A3A) : Colors.white)
            : (isDarkTheme
                ? Colors.grey.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.2)),
        foregroundColor: isSelected
            ? (isDarkTheme ? Colors.white : const Color(0xFF9C88D4))
            : Colors.white,
        elevation: isSelected ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    final adminManagement = ref.watch(adminManagementProvider);
    final leaveHistory = ref.watch(leaveRequestHistoryProvider);
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // API 응답의 approval_status 사용 (없으면 기존 방식으로 폴백)
    int pendingCount = 0;
    int approvedCount = 0;
    int rejectedCount = 0;

    if (adminManagement.data?.approvalStatus != null) {
      pendingCount = adminManagement.data!.approvalStatus!.requested;
      approvedCount = adminManagement.data!.approvalStatus!.approved;
      rejectedCount = adminManagement.data!.approvalStatus!.rejected;
    } else {
      // 폴백: 기존 방식으로 계산
      pendingCount = leaveHistory
          .where((h) => h.status == LeaveRequestStatus.pending)
          .length;
      approvedCount = leaveHistory
          .where((h) => h.status == LeaveRequestStatus.approved)
          .length;
      rejectedCount = leaveHistory
          .where((h) => h.status == LeaveRequestStatus.rejected)
          .length;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkTheme ? 0.3 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 헤더 섹션
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9C88D4), Color(0xFF8A72C8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.assignment_turned_in,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '결재 대기 현황',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
                ),
              ),
            ],
          ),
          const Spacer(),

          // 상태 카드 섹션 - 가로 배치
          Row(
            children: [
              _buildCompactAdminStatusCard('결재 대기', pendingCount,
                  const Color(0xFFFF8C00), Icons.schedule, 'REQUESTED'),
              const SizedBox(width: 12),
              _buildCompactAdminStatusCard('승인 완료', approvedCount,
                  const Color(0xFF20C997), Icons.check_circle, 'APPROVED'),
              const SizedBox(width: 12),
              _buildCompactAdminStatusCard('반려 처리', rejectedCount,
                  const Color(0xFFDC3545), Icons.cancel, 'REJECTED'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactAdminStatusCard(
      String title, int count, Color color, IconData icon, String status) {
    final isActive = _statusFilter == status;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (status == 'REQUESTED') {
            // 결재대기 클릭 시: 대기중 탭으로 변경
            _selectedTab = 'pending';
            _statusFilter = 'REQUESTED';
          } else {
            // 승인완료 또는 반려처리 클릭 시: 전체 탭으로 변경하고 해당 상태 필터 적용
            _selectedTab = 'all';
            if (_statusFilter == status) {
              // 이미 선택된 상태를 다시 클릭하면 필터 해제
              _statusFilter = null;
            } else {
              // 새로운 상태 선택
              _statusFilter = status;
            }
          }
          _currentPage = 0; // 페이지네이션 초기화
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.15)
              : color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isActive
                  ? color.withValues(alpha: 0.3)
                  : color.withValues(alpha: 0.1),
              width: isActive ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withValues(alpha: 0.2)
                    : color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 1,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive ? color : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalList() {
    final adminManagement = ref.watch(adminManagementProvider);
    final waitingLeaves = adminManagement.data?.waitingLeaves ?? [];
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // 상태 필터와 탭 필터를 모두 적용
    List<AdminWaitingLeave> filteredHistory = waitingLeaves;

    // 탭 필터 적용 - REQUESTED가 포함된 모든 상태 (예: REQUESTED, CANCEL_REQUESTED 등)
    if (_selectedTab == 'pending') {
      filteredHistory = filteredHistory
          .where((h) => h.status.toUpperCase().contains('REQUESTED'))
          .toList();
    }

    // 상태 필터 적용 - REQUESTED가 포함된 경우도 포함
    if (_statusFilter != null) {
      if (_statusFilter == 'REQUESTED') {
        // REQUESTED 필터일 때는 REQUESTED가 포함된 모든 상태 포함
        filteredHistory = filteredHistory
            .where((h) => h.status.toUpperCase().contains('REQUESTED'))
            .toList();
      } else {
        filteredHistory =
            filteredHistory.where((h) => h.status == _statusFilter).toList();
      }
    }

    // 취소건 숨기기 필터 적용
    if (_hideCancelledItems) {
      filteredHistory = filteredHistory
          .where((h) => h.status.toUpperCase() != 'CANCELLED')
          .toList();
    }

    return Container(
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkTheme ? 0.3 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: isDarkTheme
                        ? const Color(0xFF404040)
                        : const Color(0xFFF1F3F5),
                    width: 1),
              ),
            ),
            child: Row(
              children: [
                Text(
                  _getListTitle(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
                  ),
                ),
                const SizedBox(width: 16),
                _buildYearDropdown(),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getFilterColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${filteredHistory.length}건 ${_getFilterLabel()}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getFilterColor(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredHistory.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount:
                              _getCurrentPageItems(filteredHistory).length,
                          itemBuilder: (context, index) {
                            final currentPageItems =
                                _getCurrentPageItems(filteredHistory);
                            final request = currentPageItems[index];
                            return InkWell(
                              onTap: () => _showLeaveDetailModal(request),
                              borderRadius: BorderRadius.circular(16),
                              child: _buildAdminApprovalItem(request),
                            );
                          },
                        ),
                      ),
                      _buildPaginationControls(filteredHistory),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // 현재 페이지의 아이템들을 가져오는 함수
  List<AdminWaitingLeave> _getCurrentPageItems(
      List<AdminWaitingLeave> allItems) {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return allItems.sublist(
      startIndex,
      endIndex > allItems.length ? allItems.length : endIndex,
    );
  }

  // 총 페이지 수 계산
  int _getTotalPages(List<AdminWaitingLeave> allItems) {
    return (allItems.length / _itemsPerPage).ceil();
  }

  // 표시할 페이지 번호들 계산 (현재 페이지 주변 번호들)
  List<int?> _getVisiblePageNumbers(List<AdminWaitingLeave> allItems) {
    final totalPages = _getTotalPages(allItems);
    if (totalPages <= 7) {
      // 7페이지 이하: 모든 페이지 표시
      return List.generate(totalPages, (i) => i);
    }

    final current = _currentPage;
    final pages = <int?>[];

    // 항상 첫 페이지 표시
    pages.add(0);

    if (current > 3) {
      // 현재 페이지가 4페이지 이후면 ... 표시
      pages.add(null); // null은 ...을 의미
    }

    // 현재 페이지 주변 2개씩 표시
    final start = (current - 2).clamp(1, totalPages - 4);
    final end = (current + 2).clamp(3, totalPages - 2);

    for (var i = start; i <= end; i++) {
      if (!pages.contains(i)) {
        pages.add(i);
      }
    }

    if (current < totalPages - 4) {
      // 현재 페이지가 끝에서 4페이지 이전이면 ... 표시
      pages.add(null);
    }

    // 항상 마지막 페이지 표시 (중복 방지)
    if (!pages.contains(totalPages - 1)) {
      pages.add(totalPages - 1);
    }

    return pages;
  }

  // 이전 페이지로 이동
  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
    }
  }

  // 다음 페이지로 이동
  void _nextPage(List<AdminWaitingLeave> allItems) {
    final totalPages = _getTotalPages(allItems);
    if (_currentPage < totalPages - 1) {
      setState(() {
        _currentPage++;
      });
    }
  }

  // 특정 페이지로 이동
  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  // 페이지네이션 컨트롤 UI
  Widget _buildPaginationControls(List<AdminWaitingLeave> allItems) {
    final totalPages = _getTotalPages(allItems);
    if (totalPages <= 1) return const SizedBox.shrink();

    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final visiblePages = _getVisiblePageNumbers(allItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
        border: Border(
          top: BorderSide(
            color:
                isDarkTheme ? const Color(0xFF404040) : const Color(0xFFE9ECEF),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 이전 버튼
          IconButton(
            onPressed: _currentPage > 0 ? _previousPage : null,
            icon: const Icon(Icons.chevron_left, size: 20),
            color: _currentPage > 0
                ? (isDarkTheme ? Colors.grey[300] : Colors.grey[600])
                : Colors.grey[300],
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),

          // 페이지 번호들
          ...visiblePages.map((pageNumber) {
            if (pageNumber == null) {
              // ... 표시
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDarkTheme ? Colors.grey[500] : Colors.grey[400],
                  ),
                ),
              );
            } else {
              // 페이지 번호 버튼
              final isCurrentPage = pageNumber == _currentPage;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                child: TextButton(
                  onPressed: () => _goToPage(pageNumber),
                  style: TextButton.styleFrom(
                    backgroundColor: isCurrentPage
                        ? (isDarkTheme
                            ? const Color(0xFF9C88D4)
                            : const Color(0xFF9C88D4))
                        : Colors.transparent,
                    foregroundColor: isCurrentPage
                        ? Colors.white
                        : (isDarkTheme ? Colors.grey[300] : Colors.grey[700]),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(40, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    '${pageNumber + 1}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isCurrentPage ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }
          }),

          // 다음 버튼
          IconButton(
            onPressed: _currentPage < totalPages - 1
                ? () => _nextPage(allItems)
                : null,
            icon: const Icon(Icons.chevron_right, size: 20),
            color: _currentPage < totalPages - 1
                ? (isDarkTheme ? Colors.grey[300] : Colors.grey[600])
                : Colors.grey[300],
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _getEmptyStateTitle(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '새로운 휴가 신청이 있을 때 이곳에 표시됩니다.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// half_day_slot 값을 사용자 친화적인 라벨로 변환
  String _getHalfDaySlotLabel(String? halfDaySlot,
      {bool withParenthesis = true}) {
    if (halfDaySlot == null || halfDaySlot.isEmpty) return '';
    String label;
    switch (halfDaySlot.toUpperCase()) {
      case 'AM':
        label = '오전반차';
        break;
      case 'PM':
        label = '오후반차';
        break;
      case 'ALL':
        label = '연차';
        break;
      default:
        return '';
    }
    return withParenthesis ? ' ($label)' : label;
  }

  Widget _buildAdminApprovalItem(AdminWaitingLeave request) {
    final statusColorMap = {
      'REQUESTED': const Color(0xFFFF8C00),
      'CANCEL_REQUESTED': const Color(0xFFE53E3E), // 취소 상신 대기
      'APPROVED': const Color(0xFF20C997),
      'REJECTED': const Color(0xFFDC3545),
      'CANCELLED': const Color(0xFF6C757D),
    };
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // CANCEL_REQUESTED인 경우 빨간색, 그 외는 기본 맵 사용
    final statusColor = request.status.toUpperCase().contains('CANCEL') &&
            request.status.toUpperCase().contains('REQUESTED')
        ? const Color(0xFFE53E3E)
        : (statusColorMap[request.status] ?? const Color(0xFF9C88D4));
    // REQUESTED가 포함된 상태면 대기중으로 간주 (예: REQUESTED, CANCEL_REQUESTED)
    final isPending = request.status.toUpperCase().contains('REQUESTED');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF3A3A3A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? const Color(0xFFFF8C00).withValues(alpha: 0.2)
              : (isDarkTheme
                  ? const Color(0xFF505050)
                  : const Color(0xFFE8F4FD)),
          width: isPending ? 2 : 1,
        ),
        boxShadow: [
          if (isPending)
            BoxShadow(
              color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusLabel(request.status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              // 취소 상신 배지
              if (request.isCancelRequest) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53E3E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE53E3E).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        size: 12,
                        color: const Color(0xFFE53E3E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '취소 상신',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE53E3E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C88D4).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  request.leaveType,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9C88D4),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C88D4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.workdaysCount % 1 == 0
                      ? '${request.workdaysCount.toInt()}일'
                      : '${request.workdaysCount}일',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 신청자 정보
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkTheme
                  ? const Color(0xFF2A2A2A)
                  : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C88D4).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF9C88D4),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkTheme
                            ? Colors.white
                            : const Color(0xFF1A1D29),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${request.department} | ${request.jobPosition}',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                '${DateFormat('MM.dd').format(request.startDate)} - ${DateFormat('MM.dd').format(request.endDate)}${_getHalfDaySlotLabel(request.halfDaySlot)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.access_time_outlined,
                size: 14,
                color: isDarkTheme ? Colors.grey[400] : Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Text(
                '신청: ${DateFormat('MM.dd HH:mm').format(request.requestedDate)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkTheme ? Colors.grey[400] : Colors.grey[500],
                ),
              ),
            ],
          ),

          if (request.reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildReasonText(
              request.reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // 반려 사유 표시
          if (request.rejectMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '반려 사유: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
                  ),
                ),
                Expanded(
                  child: Text(
                    request.rejectMessage,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkTheme
                          ? Colors.grey[300]
                          : const Color(0xFF6C757D),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          if (isPending) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            // CANCEL_REQUESTED인 경우 취소승인 버튼만 표시
            request.status.toUpperCase().contains('CANCEL')
                ? SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _approveCancelRequest(request),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF20C997),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text(
                        '취소 승인',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _rejectRequest(request),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC3545),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.cancel, size: 18),
                          label: const Text(
                            '반려',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approveRequest(request),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF20C997),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text(
                            '승인',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
          ],
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    final upperStatus = status.toUpperCase();
    if (upperStatus.contains('CANCEL') && upperStatus.contains('REQUESTED')) {
      return '취소 상신 대기';
    }
    switch (upperStatus) {
      case 'REQUESTED':
        return '대기중';
      case 'APPROVED':
        return '승인됨';
      case 'REJECTED':
        return '반려됨';
      case 'CANCELLED':
        return '취소됨';
      default:
        return status;
    }
  }

  String _getListTitle() {
    if (_statusFilter != null) {
      switch (_statusFilter) {
        case 'REQUESTED':
          return '결재 대기 목록';
        case 'APPROVED':
          return '승인 완료 목록';
        case 'REJECTED':
          return '반려 처리 목록';
        default:
          return '전체 내역';
      }
    }
    return _selectedTab == 'pending' ? '결재 대기 목록' : '전체 신청 내역';
  }

  Color _getFilterColor() {
    if (_statusFilter != null) {
      switch (_statusFilter) {
        case 'REQUESTED':
          return const Color(0xFFFF8C00);
        case 'APPROVED':
          return const Color(0xFF20C997);
        case 'REJECTED':
          return const Color(0xFFDC3545);
        default:
          return const Color(0xFF9C88D4);
      }
    }
    return const Color(0xFFFF8C00);
  }

  String _getFilterLabel() {
    if (_statusFilter != null) {
      switch (_statusFilter) {
        case 'REQUESTED':
          return '대기중';
        case 'APPROVED':
          return '승인됨';
        case 'REJECTED':
          return '반려됨';
        default:
          return '전체';
      }
    }
    return _selectedTab == 'pending' ? '대기중' : '전체';
  }

  String _getEmptyStateTitle() {
    if (_statusFilter != null) {
      switch (_statusFilter) {
        case 'REQUESTED':
          return '결재 대기 중인 항목이 없습니다.';
        case 'APPROVED':
          return '승인된 항목이 없습니다.';
        case 'REJECTED':
          return '반려된 항목이 없습니다.';
        default:
          return '내역이 없습니다.';
      }
    }
    return _selectedTab == 'pending' ? '결재 대기 중인 항목이 없습니다.' : '신청 내역이 없습니다.';
  }

  void _approveRequest(AdminWaitingLeave request) {
    _showApprovalDialog(request, true);
  }

  void _rejectRequest(AdminWaitingLeave request) {
    _showApprovalDialog(request, false);
  }

  /// 취소 승인 처리 (CANCEL_REQUESTED인 경우)
  void _approveCancelRequest(AdminWaitingLeave request) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkTheme ? const Color(0xFF2D2D2D) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF20C997).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF20C997),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '휴가 취소 승인',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkTheme ? Colors.white : null,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkTheme
                        ? const Color(0xFF3A3A3A)
                        : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${request.leaveType} (${request.workdaysCount % 1 == 0 ? request.workdaysCount.toInt() : request.workdaysCount}일)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkTheme ? Colors.white : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('yyyy.MM.dd').format(request.startDate)} - ${DateFormat('yyyy.MM.dd').format(request.endDate)}',
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '이 휴가 신청의 취소를 승인하시겠습니까?',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkTheme ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '취소',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await _processCancelApproval(request);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20C997),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '승인',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showApprovalDialog(AdminWaitingLeave request, bool isApproval) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkTheme ? const Color(0xFF2D2D2D) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isApproval
                          ? const Color(0xFF20C997)
                          : const Color(0xFFDC3545))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isApproval ? Icons.check_circle : Icons.cancel,
                  color: isApproval
                      ? const Color(0xFF20C997)
                      : const Color(0xFFDC3545),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isApproval ? '휴가 승인' : '휴가 반려',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkTheme ? Colors.white : null,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkTheme
                        ? const Color(0xFF3A3A3A)
                        : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.workdaysCount % 1 == 0
                            ? '${request.leaveType} (${request.workdaysCount.toInt()}일)'
                            : '${request.leaveType} (${request.workdaysCount}일)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkTheme ? Colors.white : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('yyyy.MM.dd').format(request.startDate)} - ${DateFormat('yyyy.MM.dd').format(request.endDate)}',
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '결재 의견 ${isApproval ? '(선택사항)' : '(필수)'}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkTheme ? Colors.white : null,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  style: TextStyle(color: isDarkTheme ? Colors.white : null),
                  decoration: InputDecoration(
                    hintText:
                        isApproval ? '승인 사유나 참고사항을 입력해주세요.' : '반려 사유를 입력해주세요.',
                    hintStyle:
                        TextStyle(color: isDarkTheme ? Colors.grey[500] : null),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: isDarkTheme
                              ? Colors.grey[600]!
                              : Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isApproval
                            ? const Color(0xFF20C997)
                            : const Color(0xFFDC3545),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '취소',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!isApproval && commentController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('반려 사유를 입력해주세요.'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  return;
                }

                await _processApproval(
                    request, isApproval, commentController.text.trim());
                Navigator.of(context).pop();
                // 결재 처리 후 다이얼로그만 닫고 관리자 화면 유지
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isApproval
                    ? const Color(0xFF20C997)
                    : const Color(0xFFDC3545),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                isApproval ? '승인' : '반려',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _processApproval(
      AdminWaitingLeave request, bool isApproval, String comment) async {
    try {
      final currentUserId = ref.read(userIdProvider) ?? 'user_001';

      // CANCEL_REQUESTED인 경우 취소 승인/반려 API 사용
      final isCancelRequest = request.status.toUpperCase().contains('CANCEL') &&
          request.status.toUpperCase().contains('REQUESTED');

      final success = await ref
          .read(adminManagementProvider.notifier)
          .processApproval(
            id: request.id,
            approverId: currentUserId,
            isApproved: isApproval,
            rejectMessage: isApproval ? null : comment,
            isCancel: isCancelRequest ? 1 : 0, // CANCEL_REQUESTED인 경우 취소 API 사용
            isCancelApproved:
                isCancelRequest && isApproval, // CANCEL_APPROVED 전송
          );

      if (success) {
        final statusText = isCancelRequest && isApproval
            ? '취소 승인'
            : (isApproval ? '승인' : '반려');

        // 승인/반려 후 탭을 '전체'로 변경하고 해당 상태 필터 적용
        setState(() {
          _selectedTab = 'all';
          _statusFilter = isCancelRequest && isApproval
              ? 'CANCELLED'
              : (isApproval ? 'APPROVED' : 'REJECTED');
          _currentPage = 0; // 페이지네이션 초기화
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('휴가 신청이 ${statusText}되었습니다.'),
            backgroundColor:
                isApproval ? const Color(0xFF20C997) : const Color(0xFFDC3545),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('처리 중 오류가 발생했습니다.'),
            backgroundColor: Color(0xFFDC3545),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return success;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류: $e'),
          backgroundColor: const Color(0xFFDC3545),
          duration: Duration(seconds: 1),
        ),
      );
      return false;
    }
  }

  /// 취소 승인 처리 (CANCEL_APPROVED만 전송)
  Future<bool> _processCancelApproval(AdminWaitingLeave request) async {
    try {
      final currentUserId = ref.read(userIdProvider) ?? 'user_001';

      final success =
          await ref.read(adminManagementProvider.notifier).processApproval(
                id: request.id,
                approverId: currentUserId,
                isApproved: true,
                rejectMessage: null,
                isCancel: 1, // 취소 승인 API 사용
                isCancelApproved: true, // CANCEL_APPROVED 전송
              );

      if (success) {
        // 승인 후 탭을 '전체'로 변경하고 해당 상태 필터 적용
        setState(() {
          _selectedTab = 'all';
          _statusFilter = 'CANCELLED';
          _currentPage = 0; // 페이지네이션 초기화
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('휴가 취소가 승인되었습니다.'),
            backgroundColor: Color(0xFF20C997),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('처리 중 오류가 발생했습니다.'),
            backgroundColor: Color(0xFFDC3545),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return success;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류: $e'),
          backgroundColor: const Color(0xFFDC3545),
          duration: Duration(seconds: 1),
        ),
      );
      return false;
    }
  }

  // 새로운 달력 섹션 위젯
  Widget _buildCalendarSection() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // 달력 컨테이너 (60% 비율)
        Expanded(
          flex: 6, // 60% 비율
          child: Container(
            decoration: BoxDecoration(
              color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(alpha: isDarkTheme ? 0.3 : 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // 달력 헤더
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                          color: isDarkTheme
                              ? const Color(0xFF404040)
                              : const Color(0xFFF1F3F5),
                          width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9C88D4), Color(0xFF8A72C8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.calendar_month,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '부서원 휴가 일정',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDarkTheme
                                ? Colors.white
                                : const Color(0xFF1A1D29),
                          ),
                        ),
                      ),
                      // 넓게보기 버튼 추가
                      IconButton(
                        onPressed: _showFullCalendarModal,
                        icon: const Icon(
                          Icons.fullscreen,
                          color: Color(0xFF9C88D4),
                          size: 16,
                        ),
                        tooltip: '넓게보기',
                        constraints:
                            const BoxConstraints(minWidth: 26, minHeight: 26),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                // 달력 본문
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: _buildCalendar(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // 선택된 날짜의 상세 정보 컨테이너 (40% 비율)
        Expanded(
          flex: 4, // 40% 비율
          child: _buildSelectedDateDetails(),
        ),
      ],
    );
  }

  // 달력 위젯 (스크롤 가능한 달력으로 변경)
  Widget _buildCalendar() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // 월 네비게이션 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color:
                isDarkTheme ? const Color(0xFF3A3A3A) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isDarkTheme
                    ? const Color(0xFF505050)
                    : const Color(0xFFE9ECEF)),
          ),
          child: Row(
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
                    size: 18),
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                padding: EdgeInsets.zero,
              ),
              Text(
                '${_currentCalendarDate.year}년 ${_currentCalendarDate.month}월',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkTheme ? Colors.white : const Color(0xFF495057),
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
                    size: 18),
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 스크롤 가능한 달력
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(), // 스와이프 활성화
            onPageChanged: (index) {
              setState(() {
                // 2020년 1월부터 시작해서 index개월 후
                final baseDate = DateTime(2020, 1);
                _currentCalendarDate =
                    DateTime(baseDate.year, baseDate.month + index);
                _updateSelectedDateDetails();

                // 초기 로드가 아닌 경우에만 부서별 달력 API 호출
                if (!_isInitialLoad) {
                  final currentUserId = ref.read(userIdProvider) ?? 'user_001';
                  ref
                      .read(adminDeptCalendarProvider.notifier)
                      .loadDeptCalendarData(
                        approverId: currentUserId,
                        month: _currentCalendarDate
                            .toString()
                            .substring(0, 7), // YYYY-MM 형식
                      );
                } else {
                  _isInitialLoad = false; // 첫 번째 이후부터는 월 변경으로 처리
                }

                // 공휴일 데이터 로드
                _loadHolidays(
                    _currentCalendarDate.year, _currentCalendarDate.month);
              });
            },
            itemBuilder: (context, index) {
              final baseDate = DateTime(2020, 1);
              final monthDate = DateTime(baseDate.year, baseDate.month + index);
              return _buildMonthCalendar(monthDate);
            },
          ),
        ),
      ],
    );
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
    final weekday = date.weekday;

    // 공휴일은 빨간색으로 표시
    if (_isHoliday(date)) {
      return const Color(0xFFE53E3E); // 공휴일 빨간색
    } else if (weekday == DateTime.sunday) {
      return const Color(0xFFE53E3E); // 일요일 빨간색
    } else if (weekday == DateTime.saturday) {
      return const Color(0xFF3182CE); // 토요일 파란색
    } else {
      return const Color(0xFF495057); // 평일 기본 색상
    }
  }

  // 월별 달력 빌더
  Widget _buildMonthCalendar(DateTime monthDate) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          // 요일 헤더
          Container(
            height: 20,
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
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSunday
                            ? const Color(0xFFE53E3E) // 일요일 빨간색
                            : isSaturday
                                ? const Color(0xFF3182CE) // 토요일 파란색
                                : const Color(0xFF6C757D)
                                    .withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          // 달력 그리드
          Expanded(
            child: _buildMonthGrid(monthDate),
          ),
        ],
      ),
    );
  }

  // 월별 그리드 생성
  Widget _buildMonthGrid(DateTime monthDate) {
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);
    final lastDayOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0);
    final firstDayWeekday = (firstDayOfMonth.weekday % 7);
    final today = DateTime.now();

    // 초기 로드시에는 관리자 관리 데이터, 월 변경시에는 부서별 달력 데이터 사용
    final adminManagement = ref.watch(adminManagementProvider);
    final adminDeptCalendar = ref.watch(adminDeptCalendarProvider);

    List<AdminMonthlyLeave> monthlyLeaves;
    if (_isInitialLoad && adminManagement.data != null) {
      monthlyLeaves = adminManagement.data!.monthlyLeaves;
    } else {
      monthlyLeaves = adminDeptCalendar.data?.monthlyLeaves ?? [];
    }

    // 달력 그리드 생성
    List<List<Widget>> weeks = [];
    List<Widget> currentWeek = [];

    // 이전 달의 마지막 날짜들로 첫 주 시작 부분 채우기
    final prevMonthLastDay = DateTime(monthDate.year, monthDate.month, 0);
    for (int i = firstDayWeekday - 1; i >= 0; i--) {
      final day = prevMonthLastDay.day - i;
      currentWeek.add(_buildDateCell(
        day,
        DateTime(prevMonthLastDay.year, prevMonthLastDay.month, day),
        isCurrentMonth: false,
        today: today,
        leaveHistory: monthlyLeaves,
      ));
    }

    // 현재 달의 날짜들
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(monthDate.year, monthDate.month, day);
      currentWeek.add(_buildDateCell(
        day,
        date,
        isCurrentMonth: true,
        today: today,
        leaveHistory: monthlyLeaves,
      ));

      // 주말이면 새로운 주 시작
      if (currentWeek.length == 7) {
        weeks.add(List.from(currentWeek));
        currentWeek.clear();
      }
    }

    // 마지막 주의 남은 부분을 다음 달 날짜로 채우기
    if (currentWeek.isNotEmpty) {
      final nextMonth = DateTime(monthDate.year, monthDate.month + 1, 1);
      int nextDay = 1;
      while (currentWeek.length < 7) {
        currentWeek.add(_buildDateCell(
          nextDay,
          DateTime(nextMonth.year, nextMonth.month, nextDay),
          isCurrentMonth: false,
          today: today,
          leaveHistory: monthlyLeaves,
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
  }

  // 날짜 셀 생성
  Widget _buildDateCell(
    int day,
    DateTime date, {
    required bool isCurrentMonth,
    required DateTime today,
    required List<AdminMonthlyLeave> leaveHistory,
  }) {
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final isSelected = date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day;

    // 해당 날짜의 휴가 정보들 수집
    final dayLeaves = leaveHistory.where((leave) {
      // endDate를 포함하여 기간 전체를 표시
      final startDateLocal = DateTime(
          leave.startDate.year, leave.startDate.month, leave.startDate.day);
      final endDateLocal =
          DateTime(leave.endDate.year, leave.endDate.month, leave.endDate.day);
      final dateLocal = DateTime(date.year, date.month, date.day);

      return !dateLocal.isBefore(startDateLocal) &&
          !dateLocal.isAfter(endDateLocal);
    }).toList();

    final hasLeave = dayLeaves.isNotEmpty;

    // 휴가 상태에 따른 색상 결정
    Color? leaveColor;
    if (hasLeave) {
      // 부서원 휴가 일정은 항상 승인된 건만 오므로 초록색으로 표시
      leaveColor = const Color(0xFF20C997); // 승인됨 (초록색)
    }

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDate = date;
            _updateSelectedDateDetails();
          });
        },
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            margin: const EdgeInsets.all(0.5),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF9C88D4)
                  : isToday
                      ? const Color(0xFF9C88D4).withValues(alpha: 0.3)
                      : (hasLeave && isCurrentMonth && leaveColor != null)
                          ? leaveColor.withValues(alpha: 0.15)
                          : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    day.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected || isToday
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: !isCurrentMonth
                          ? Colors.grey[400]
                          : isSelected
                              ? Colors.white
                              : isToday
                                  ? Colors.white
                                  : _getDateTextColor(date),
                    ),
                  ),
                  // 공휴일 이름 표시 (현재 월이고 공휴일인 경우)
                  if (isCurrentMonth && _isHoliday(date))
                    Text(
                      _getHolidayName(date) ?? '',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: !isCurrentMonth
                            ? Colors.grey[400]
                            : isSelected
                                ? Colors.white.withValues(alpha: 0.8)
                                : isToday
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : _getDateTextColor(date)
                                        .withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (hasLeave &&
                      !isSelected &&
                      !isToday &&
                      isCurrentMonth &&
                      leaveColor != null)
                    Positioned(
                      bottom: 2,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 부서원 휴가 일정은 항상 승인된 건만 있으므로 초록색 점만 표시
                          Container(
                            width: 2,
                            height: 2,
                            decoration: const BoxDecoration(
                              color: Color(0xFF20C997),
                              shape: BoxShape.circle,
                            ),
                          )
                        ],
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

  // 선택된 날짜의 상세 정보
  Widget _buildSelectedDateDetails() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkTheme ? 0.3 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: isDarkTheme
                        ? const Color(0xFF404040)
                        : const Color(0xFFF1F3F5),
                    width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C88D4).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.event_note,
                    color: Color(0xFF9C88D4),
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일 상세정보',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // 상세 내용
          Expanded(
            child: _selectedDateDetails.isEmpty
                ? _buildEmptyDetailsState()
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _selectedDateDetails.length,
                    itemBuilder: (context, index) {
                      final detail = _selectedDateDetails[index];
                      return _buildDetailItem(detail);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 빈 상세 정보 상태
  Widget _buildEmptyDetailsState() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: isDarkTheme ? Colors.grey[500] : Colors.grey[400],
              ),
              const SizedBox(height: 4),
              Text(
                '선택된 날짜에\n휴가 일정이 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                  height: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.visible,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 상세 항목
  Widget _buildDetailItem(Map<String, Object> detail) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final status = (detail['status'] as String?) ?? 'REQUESTED';

    // 공휴일 상태 특별 처리
    if (status == 'HOLIDAY') {
      final statusColor = const Color(0xFFE53E3E); // 공휴일: 빨간색

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: isDarkTheme ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: statusColor.withValues(alpha: isDarkTheme ? 0.3 : 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Text(
                'HOLIDAY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                (detail['employeeName'] as String?) ?? '공휴일',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkTheme ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final statusColor = {
          'REQUESTED': const Color(0xFFFF8C00),
          'APPROVED': const Color(0xFF20C997),
          'REJECTED': const Color(0xFFDC3545),
          'CANCELLED': const Color(0xFF6C757D),
        }[status] ??
        const Color(0xFF9C88D4);

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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusLabel(status),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                (detail['vacationType'] as String?) ?? '',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDarkTheme ? Colors.white : const Color(0xFF495057),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '신청자: ${(detail['employeeName'] as String?) ?? '알 수 없음'} (${(detail['department'] as String?) ?? ''} | ${(detail['jobPosition'] as String?) ?? ''})',
            style: TextStyle(
              fontSize: 11,
              color: isDarkTheme ? Colors.grey[300] : const Color(0xFF6C757D),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '휴가기간: ${_formatDateWithKoreanDay(detail['startDate'] as DateTime)} - ${_formatDateWithKoreanDay(detail['endDate'] as DateTime)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDarkTheme ? Colors.grey[200] : const Color(0xFF495057),
            ),
          ),
          if (detail['halfDaySlot'] != null &&
              detail['halfDaySlot'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '유형: ${_getHalfDaySlotLabel(detail['halfDaySlot'] as String, withParenthesis: false)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDarkTheme ? Colors.grey[200] : const Color(0xFF495057),
              ),
            ),
          ],
          if (status != 'HOLIDAY' &&
              (detail['reason'] as String?) != null &&
              (detail['reason'] as String).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '사유: ${detail['reason'] as String}',
              style: TextStyle(
                fontSize: 11,
                color: isDarkTheme ? Colors.grey[300] : const Color(0xFF6C757D),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // 선택된 날짜의 상세정보 업데이트
  void _updateSelectedDateDetails() {
    // 초기 로드시에는 관리자 관리 데이터, 월 변경시에는 부서별 달력 데이터 사용
    final adminManagement = ref.read(adminManagementProvider);
    final adminDeptCalendar = ref.read(adminDeptCalendarProvider);

    List<AdminMonthlyLeave> monthlyLeaves;
    if (_isInitialLoad && adminManagement.data != null) {
      monthlyLeaves = adminManagement.data!.monthlyLeaves;
    } else {
      monthlyLeaves = adminDeptCalendar.data?.monthlyLeaves ?? [];
    }

    _selectedDateDetails = monthlyLeaves
        .where((leave) {
          // endDate를 포함하여 기간 전체를 표시
          final startDateLocal = DateTime(
              leave.startDate.year, leave.startDate.month, leave.startDate.day);
          final endDateLocal = DateTime(
              leave.endDate.year, leave.endDate.month, leave.endDate.day);
          final selectedDateLocal = DateTime(
              _selectedDate.year, _selectedDate.month, _selectedDate.day);

          return !selectedDateLocal.isBefore(startDateLocal) &&
              !selectedDateLocal.isAfter(endDateLocal);
        })
        .map((leave) => <String, Object>{
              'status': leave.status,
              'vacationType': leave.leaveType,
              'employeeName': leave.name,
              'department': leave.department,
              'jobPosition': leave.jobPosition,
              'reason': leave.reason,
              'startDate': leave.startDate,
              'endDate': leave.endDate,
              'halfDaySlot': leave.halfDaySlot,
            })
        .toList();

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

  // 공휴일 데이터 로드
  Future<void> _loadHolidays(int year, int month) async {
    try {
      final response = await ApiService.getHolidays(year: year, month: month);
      if (response.isSuccess) {
        setState(() {
          _holidays = response.holidays;
        });
        print('🏝️ 공휴일 데이터 로드 완료: ${_holidays.length}개');
      } else {
        print('🏝️ 공휴일 데이터 로드 실패: ${response.error}');
      }
    } catch (e) {
      print('🏝️ 공휴일 데이터 로드 중 오류: $e');
    }
  }

  // 넓게보기 모달 표시
  void _showFullCalendarModal() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(alpha: isDarkTheme ? 0.3 : 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: FullCalendarModal(
              selectedDate: _selectedDate,
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = date;
                  _updateSelectedDateDetails();
                });
              },
            ),
          ),
        );
      },
    );
  }

  /// 휴가 신청 상세 정보 모달
  void _showLeaveDetailModal(AdminWaitingLeave request) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final isPending = request.status.toUpperCase().contains('REQUESTED');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.5,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 모달 헤더
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF9C88D4),
                        const Color(0xFF9C88D4).withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.description,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '휴가 신청 상세',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              request.leaveType,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                        tooltip: '닫기',
                      ),
                    ],
                  ),
                ),

                // 모달 본문
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 신청자 정보
                        _buildDetailSection(
                          '신청자 정보',
                          Icons.person,
                          [
                            _buildDetailRow('이름', request.name),
                            _buildDetailRow('부서', request.department),
                            _buildDetailRow('직급', request.jobPosition),
                          ],
                          isDarkTheme,
                        ),
                        const SizedBox(height: 20),

                        // 휴가 정보
                        _buildDetailSection(
                          '휴가 정보',
                          Icons.calendar_today,
                          [
                            _buildDetailRow('휴가 유형', request.leaveType),
                            _buildDetailRow(
                              '휴가 기간',
                              '${DateFormat('yyyy.MM.dd').format(request.startDate)} - ${DateFormat('yyyy.MM.dd').format(request.endDate)}',
                            ),
                            _buildDetailRow(
                              '휴가 일수',
                              request.workdaysCount % 1 == 0
                                  ? '${request.workdaysCount.toInt()}일'
                                  : '${request.workdaysCount}일',
                            ),
                            if (request.halfDaySlot.isNotEmpty)
                              _buildDetailRow(
                                '반차 구분',
                                _getHalfDaySlotLabel(request.halfDaySlot),
                              ),
                            _buildDetailRow(
                              '신청일시',
                              DateFormat('yyyy.MM.dd HH:mm')
                                  .format(request.requestedDate),
                            ),
                          ],
                          isDarkTheme,
                        ),
                        const SizedBox(height: 20),

                        // 신청 사유
                        if (request.reason.isNotEmpty)
                          _buildDetailSection(
                            '신청 사유',
                            Icons.comment,
                            [
                              _buildReasonText(request.reason),
                            ],
                            isDarkTheme,
                          ),
                        const SizedBox(height: 20),

                        // 반려 사유
                        if (request.rejectMessage.isNotEmpty)
                          _buildDetailSection(
                            '반려 사유',
                            Icons.cancel_outlined,
                            [
                              Text(
                                request.rejectMessage,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkTheme
                                      ? Colors.white
                                      : const Color(0xFF1A1D1F),
                                ),
                              ),
                            ],
                            isDarkTheme,
                          ),
                        const SizedBox(height: 20),

                        // 상태 정보
                        _buildDetailSection(
                          '처리 상태',
                          Icons.info_outline,
                          [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(request.status)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _getStatusColor(request.status)
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    _getStatusLabel(request.status),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _getStatusColor(request.status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          isDarkTheme,
                        ),
                      ],
                    ),
                  ),
                ),

                // 모달 하단 버튼 (대기 중인 경우만)
                if (isPending)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDarkTheme
                          ? const Color(0xFF1A1A1A)
                          : const Color(0xFFF8F9FA),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      border: Border(
                        top: BorderSide(
                          color: isDarkTheme
                              ? const Color(0xFF404040)
                              : const Color(0xFFE9ECEF),
                        ),
                      ),
                    ),
                    child: request.status.toUpperCase().contains('CANCEL')
                        ? SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _approveCancelRequest(request);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF20C997),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.check_circle, size: 20),
                              label: const Text(
                                '취소 승인',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _rejectRequest(request);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC3545),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.cancel, size: 20),
                                  label: const Text(
                                    '반려',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _approveRequest(request);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF20C997),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon:
                                      const Icon(Icons.check_circle, size: 20),
                                  label: const Text(
                                    '승인',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 상세 섹션 빌드
  Widget _buildDetailSection(
    String title,
    IconData icon,
    List<Widget> children,
    bool isDarkTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: const Color(0xFF9C88D4),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:
                isDarkTheme ? const Color(0xFF3A3A3A) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkTheme
                  ? const Color(0xFF505050)
                  : const Color(0xFFE9ECEF),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  /// 상세 정보 행 빌드
  Widget _buildDetailRow(String label, String value) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkTheme ? Colors.grey[400] : const Color(0xFF6C757D),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    final upperStatus = status.toUpperCase();
    if (upperStatus.contains('CANCEL') && upperStatus.contains('REQUESTED')) {
      return const Color(0xFFE53E3E);
    }
    switch (upperStatus) {
      case 'REQUESTED':
        return const Color(0xFFFF8C00);
      case 'APPROVED':
        return const Color(0xFF20C997);
      case 'REJECTED':
        return const Color(0xFFDC3545);
      case 'CANCELLED':
        return const Color(0xFF6C757D);
      default:
        return const Color(0xFF9C88D4);
    }
  }

  /// 취소사유가 포함된 reason을 파싱하여 표시
  Widget _buildReasonText(String reason,
      {int? maxLines, TextOverflow? overflow}) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // "취소사유:"가 포함되어 있는지 확인
    if (reason.contains('취소사유:')) {
      final parts = reason.split('취소사유:');
      final cancelReason = parts.length > 1 ? parts[1].trim() : '';

      // "\n\n\n"으로 구분되는 원래 사유 분리
      final cancelParts = cancelReason.split('\n\n\n');
      final actualCancelReason = cancelParts[0].trim();
      final originalReason =
          cancelParts.length > 1 ? cancelParts[1].trim() : '';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 취소사유 섹션
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFDC3545).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFDC3545).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Color(0xFFDC3545),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '취소사유',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC3545),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        actualCancelReason,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkTheme
                              ? Colors.grey[300]
                              : const Color(0xFF495057),
                          height: 1.4,
                        ),
                        maxLines: maxLines,
                        overflow: overflow,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 원래 신청 사유가 있으면 표시
          if (originalReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '원래 신청 사유',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDarkTheme ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              originalReason,
              style: TextStyle(
                fontSize: 13,
                color: isDarkTheme ? Colors.grey[400] : Colors.grey[700],
                height: 1.4,
              ),
              maxLines: maxLines,
              overflow: overflow,
            ),
          ],
        ],
      );
    } else {
      // 일반 사유
      return Text(
        reason,
        style: TextStyle(
          fontSize: 14,
          color: isDarkTheme ? Colors.grey[300] : Colors.grey[700],
          height: 1.4,
        ),
        maxLines: maxLines,
        overflow: overflow,
      );
    }
  }
}

// 넓게보기 달력 모달
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

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    _currentCalendarDate = DateTime(_selectedDate.year, _selectedDate.month);
    // 2020년 1월부터 현재 월까지의 개월 수 계산
    final monthsFromBase = (_currentCalendarDate.year - 2020) * 12 +
        (_currentCalendarDate.month - 1);
    _pageController = PageController(initialPage: monthsFromBase);
    _updateSelectedDateDetails();

    // 모달 열릴 때 현재 월 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUserId = ref.read(userIdProvider) ?? 'user_001';
      ref.read(adminDeptCalendarProvider.notifier).loadDeptCalendarData(
            approverId: currentUserId,
            month:
                _currentCalendarDate.toString().substring(0, 7), // YYYY-MM 형식
          );

      // 공휴일 데이터 로드
      _loadHolidays(_currentCalendarDate.year, _currentCalendarDate.month);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Full date formatter with Korean day name for modal
  String _formatFullDateWithKoreanDay(DateTime date) {
    const koreanDays = ['일', '월', '화', '수', '목', '금', '토'];
    final day = koreanDays[date.weekday % 7];
    return '${DateFormat('yyyy.MM.dd').format(date)}($day)';
  }

  /// half_day_slot 값을 사용자 친화적인 라벨로 변환
  String _getHalfDaySlotLabel(String? halfDaySlot,
      {bool withParenthesis = true}) {
    if (halfDaySlot == null || halfDaySlot.isEmpty) return '';
    String label;
    switch (halfDaySlot.toUpperCase()) {
      case 'AM':
        label = '오전반차';
        break;
      case 'PM':
        label = '오후반차';
        break;
      case 'ALL':
        label = '연차';
        break;
      default:
        return '';
    }
    return withParenthesis ? ' ($label)' : label;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.transparent,
            borderRadius: const BorderRadius.only(
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
                    colors: [Color(0xFF9C88D4), Color(0xFF8A72C8)],
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
                child: Text(
                  '부서원 휴가 일정 (전체보기)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
                  ),
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
              // 달력 영역 (70%)
              Expanded(
                flex: 7,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDarkTheme
                        ? const Color(0xFF2D2D2D)
                        : Colors.transparent,
                  ),
                  child: Column(
                    children: [
                      // 현재 월 표시 및 네비게이션
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 좌측 화살표
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
                          // 중앙 영역
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
                                        ? const Color(0xFF4A4A4A)
                                        : const Color(0xFF9C88D4),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 우측 화살표
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
                      // 달력
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const BouncingScrollPhysics(), // 스와이프 활성화
                          onPageChanged: (index) {
                            setState(() {
                              final baseDate = DateTime(2020, 1);
                              _currentCalendarDate = DateTime(
                                baseDate.year,
                                baseDate.month + index,
                              );

                              // 부서별 달력 데이터 로드
                              final currentUserId =
                                  ref.read(userIdProvider) ?? 'user_001';
                              ref
                                  .read(adminDeptCalendarProvider.notifier)
                                  .loadDeptCalendarData(
                                    approverId: currentUserId,
                                    month: _currentCalendarDate
                                        .toString()
                                        .substring(0, 7), // YYYY-MM 형식
                                  );

                              // 공휴일 데이터 로드
                              _loadHolidays(_currentCalendarDate.year,
                                  _currentCalendarDate.month);
                            });
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
              // 상세정보 영역 (30%)
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDarkTheme
                        ? const Color(0xFF2D2D2D)
                        : Colors.transparent,
                  ),
                  child: _buildModalDateDetails(),
                ),
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

      // 부서별 달력 데이터 로드
      final currentUserId = ref.read(userIdProvider) ?? 'user_001';
      final monthString =
          '${_currentCalendarDate.year}-${_currentCalendarDate.month.toString().padLeft(2, '0')}';
      ref.read(adminDeptCalendarProvider.notifier).loadDeptCalendarData(
            approverId: currentUserId,
            month: monthString,
          );
    }
  }

  // 오늘로 이동
  void _goToToday() {
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
      return isDarkTheme
          ? Colors.grey[300]!
          : const Color(0xFF495057); // 평일 기본 색상
    }
  }

  // 전체 달력 월별 뷰
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
          // 달력 그리드
          Expanded(
            child: _buildFullMonthGrid(monthDate),
          ),
        ],
      ),
    );
  }

  // 전체 달력 월별 그리드
  Widget _buildFullMonthGrid(DateTime monthDate) {
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);
    final lastDayOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0);
    final firstDayWeekday = (firstDayOfMonth.weekday % 7);
    final today = DateTime.now();

    // 전체보기 달력에서는 항상 부서별 달력 데이터 사용
    final adminDeptCalendar = ref.watch(adminDeptCalendarProvider);
    final monthlyLeaves = adminDeptCalendar.data?.monthlyLeaves ?? [];

    List<List<Widget>> weeks = [];
    List<Widget> currentWeek = [];

    // 이전 달의 마지막 날짜들
    final prevMonthLastDay = DateTime(monthDate.year, monthDate.month, 0);
    for (int i = firstDayWeekday - 1; i >= 0; i--) {
      final day = prevMonthLastDay.day - i;
      currentWeek.add(_buildFullDateCell(
        day,
        DateTime(prevMonthLastDay.year, prevMonthLastDay.month, day),
        isCurrentMonth: false,
        today: today,
        leaveHistory: monthlyLeaves,
      ));
    }

    // 현재 달의 날짜들
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(monthDate.year, monthDate.month, day);
      currentWeek.add(_buildFullDateCell(
        day,
        date,
        isCurrentMonth: true,
        today: today,
        leaveHistory: monthlyLeaves,
      ));

      if (currentWeek.length == 7) {
        weeks.add(List.from(currentWeek));
        currentWeek.clear();
      }
    }

    // 다음 달 날짜로 마지막 주 채우기
    if (currentWeek.isNotEmpty) {
      final nextMonth = DateTime(monthDate.year, monthDate.month + 1, 1);
      int nextDay = 1;
      while (currentWeek.length < 7) {
        currentWeek.add(_buildFullDateCell(
          nextDay,
          DateTime(nextMonth.year, nextMonth.month, nextDay),
          isCurrentMonth: false,
          today: today,
          leaveHistory: monthlyLeaves,
        ));
        nextDay++;
      }
      weeks.add(currentWeek);
    }

    return Column(
      children: weeks.map((week) {
        return Expanded(
          child: Row(
            children: week.map((cell) => Expanded(child: cell)).toList(),
          ),
        );
      }).toList(),
    );
  }

  // 전체 달력 날짜 셀
  Widget _buildFullDateCell(
    int day,
    DateTime date, {
    required bool isCurrentMonth,
    required DateTime today,
    required List<AdminMonthlyLeave> leaveHistory,
  }) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final isSelected = date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day;

    // 해당 날짜의 휴가 정보들 수집 (전체 달력용)
    final dayLeaves = leaveHistory.where((leave) {
      // endDate까지 포함하여 표시 (inclusive)
      final startDateLocal = DateTime(
          leave.startDate.year, leave.startDate.month, leave.startDate.day);
      final endDateLocal =
          DateTime(leave.endDate.year, leave.endDate.month, leave.endDate.day);
      final dateLocal = DateTime(date.year, date.month, date.day);

      return (dateLocal.isAtSameMomentAs(startDateLocal) ||
          dateLocal.isAtSameMomentAs(endDateLocal) ||
          (dateLocal.isAfter(startDateLocal) &&
              dateLocal.isBefore(endDateLocal)));
    }).toList();

    final hasLeave = dayLeaves.isNotEmpty;

    // 휴가 상태에 따른 색상 결정
    Color? leaveColor;
    if (hasLeave) {
      // 부서원 휴가 일정은 항상 승인된 건만 오므로 초록색으로 표시
      leaveColor = const Color(0xFF20C997); // 승인됨 (초록색)
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = date;
          _updateSelectedDateDetails();
        });
        widget.onDateSelected(date);
      },
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF9C88D4)
              : isToday
                  ? const Color(0xFF9C88D4).withValues(alpha: 0.3)
                  : (hasLeave && isCurrentMonth && leaveColor != null)
                      ? leaveColor.withValues(alpha: 0.1)
                      : (isDarkTheme ? Colors.transparent : Colors.white),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF9C88D4).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    day.toString(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected || isToday
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: !isCurrentMonth
                          ? Colors.grey[400]
                          : isSelected
                              ? Colors.white
                              : isToday
                                  ? Colors.white
                                  : _getDateTextColor(date),
                    ),
                  ),
                  // 공휴일 이름 표시 (현재 월이고 공휴일인 경우)
                  if (isCurrentMonth && _isHoliday(date))
                    Text(
                      _getHolidayName(date) ?? '',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: !isCurrentMonth
                            ? Colors.grey[400]
                            : isSelected
                                ? Colors.white.withValues(alpha: 0.8)
                                : isToday
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : _getDateTextColor(date)
                                        .withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              if (hasLeave &&
                  !isSelected &&
                  !isToday &&
                  isCurrentMonth &&
                  leaveColor != null)
                Positioned(
                  bottom: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 부서원 휴가 일정은 항상 승인된 건만 있으므로 초록색 점만 표시
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF20C997),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 모달용 상세정보
  Widget _buildModalDateDetails() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF9C88D4).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.event_note,
                color: Color(0xFF9C88D4),
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
        // 상세 내용
        Expanded(
          child: _selectedDateDetails.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 64,
                        color:
                            isDarkTheme ? Colors.grey[500] : Colors.grey[400],
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

  // 모달용 상세 항목
  Widget _buildModalDetailItem(Map<String, dynamic> detail) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final status = (detail['status'] as String?) ?? 'REQUESTED';

    // 공휴일 상태 특별 처리
    if (status == 'HOLIDAY') {
      final statusColor = const Color(0xFFE53E3E); // 공휴일: 빨간색

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: isDarkTheme ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: statusColor.withValues(alpha: isDarkTheme ? 0.3 : 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Text(
                'HOLIDAY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                (detail['employeeName'] as String?) ?? '공휴일',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkTheme ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final statusColor = {
          'REQUESTED': const Color(0xFFFF8C00),
          'APPROVED': const Color(0xFF20C997),
          'REJECTED': const Color(0xFFDC3545),
          'CANCELLED': const Color(0xFF6C757D),
        }[status] ??
        const Color(0xFF9C88D4);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkTheme
            ? statusColor.withValues(alpha: 0.1)
            : statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: statusColor.withValues(alpha: isDarkTheme ? 0.3 : 0.2),
            width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  {
                        'REQUESTED': '대기중',
                        'APPROVED': '승인됨',
                        'REJECTED': '반려됨',
                        'CANCELLED': '취소됨',
                      }[status] ??
                      status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  (detail['vacationType'] as String?) ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkTheme ? Colors.white : const Color(0xFF495057),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '신청자: ${detail['employeeName'] ?? '알 수 없음'}',
            style: TextStyle(
              fontSize: 14,
              color: isDarkTheme ? Colors.grey[200] : const Color(0xFF6C757D),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '휴가기간: ${_formatFullDateWithKoreanDay(detail['startDate'] as DateTime)} - ${_formatFullDateWithKoreanDay(detail['endDate'] as DateTime)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDarkTheme ? Colors.grey[100] : const Color(0xFF495057),
            ),
          ),
          if (detail['halfDaySlot'] != null &&
              detail['halfDaySlot'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '유형: ${_getHalfDaySlotLabel(detail['halfDaySlot'] as String, withParenthesis: false)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDarkTheme ? Colors.grey[100] : const Color(0xFF495057),
              ),
            ),
          ],
          if (detail['reason'] != null &&
              detail['reason'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildReasonText(detail['reason'].toString(), isDarkTheme, status),
          ],
        ],
      ),
    );
  }

  // 사유 텍스트 빌드 (취소사유 강조)
  Widget _buildReasonText(String reason, bool isDarkTheme, String status) {
    final label = status == 'CANCELLED' ? '취소사유' : '사유';
    final fullText = '$label: $reason';

    // "취소사유"가 포함되어 있는지 확인
    final cancelReasonIndex = reason.toLowerCase().indexOf('취소사유');

    if (cancelReasonIndex != -1) {
      // "취소사유"가 포함된 경우 RichText로 표시
      final labelText = '$label: ';
      final beforeCancel = reason.substring(0, cancelReasonIndex);
      final cancelPart =
          reason.substring(cancelReasonIndex, cancelReasonIndex + 4); // "취소사유"
      final afterCancel = reason.substring(cancelReasonIndex + 4);

      return RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: labelText + beforeCancel,
              style: TextStyle(
                fontSize: 14,
                color: isDarkTheme ? Colors.grey[200] : const Color(0xFF6C757D),
                fontWeight: FontWeight.normal,
              ),
            ),
            TextSpan(
              text: cancelPart,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFDC3545), // 취소사유는 빨간색으로 강조
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: afterCancel,
              style: TextStyle(
                fontSize: 14,
                color: isDarkTheme ? Colors.grey[200] : const Color(0xFF6C757D),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    } else {
      // 일반적인 경우 기존 방식으로 표시
      return Text(
        fullText,
        style: TextStyle(
          fontSize: 14,
          color: status == 'CANCELLED'
              ? const Color(0xFFDC3545)
              : (isDarkTheme ? Colors.grey[200] : const Color(0xFF6C757D)),
          fontWeight:
              status == 'CANCELLED' ? FontWeight.w500 : FontWeight.normal,
        ),
      );
    }
  }

  // 선택된 날짜의 상세정보 업데이트
  void _updateSelectedDateDetails() {
    // 전체보기 모달에서는 항상 부서별 달력 데이터 사용
    final adminDeptCalendar = ref.read(adminDeptCalendarProvider);
    final monthlyLeaves = adminDeptCalendar.data?.monthlyLeaves ?? [];

    _selectedDateDetails = monthlyLeaves
        .where((leave) {
          // endDate를 포함하여 기간 전체를 표시
          final startDateLocal = DateTime(
              leave.startDate.year, leave.startDate.month, leave.startDate.day);
          final endDateLocal = DateTime(
              leave.endDate.year, leave.endDate.month, leave.endDate.day);
          final selectedDateLocal = DateTime(
              _selectedDate.year, _selectedDate.month, _selectedDate.day);

          return !selectedDateLocal.isBefore(startDateLocal) &&
              !selectedDateLocal.isAfter(endDateLocal);
        })
        .map((leave) => {
              'status': leave.status,
              'vacationType': leave.leaveType,
              'employeeName': leave.name,
              'department': leave.department,
              'jobPosition': leave.jobPosition,
              'reason': leave.reason,
              'startDate': leave.startDate,
              'endDate': leave.endDate,
              'halfDaySlot': leave.halfDaySlot,
            })
        .toList();

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

  // 공휴일 데이터 로드
  Future<void> _loadHolidays(int year, int month) async {
    try {
      final response = await ApiService.getHolidays(year: year, month: month);
      if (response.isSuccess) {
        setState(() {
          _holidays = response.holidays;
        });
        print('🏝️ 부서원 전체보기 달력 공휴일 데이터 로드 완료: ${_holidays.length}개');
      } else {
        print('🏝️ 부서원 전체보기 달력 공휴일 데이터 로드 실패: ${response.error}');
      }
    } catch (e) {
      print('🏝️ 부서원 전체보기 달력 공휴일 데이터 로드 중 오류: $e');
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

  /// 페이지네이션 UI 빌드 (결재목록용)
}
