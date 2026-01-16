import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:ASPN_AI_AGENT/features/leave/leave_request_sidebar.dart';
import 'package:ASPN_AI_AGENT/features/leave/leave_models.dart';
import 'package:ASPN_AI_AGENT/features/leave/full_calendar_modal.dart';
import 'package:ASPN_AI_AGENT/features/leave/leave_request_manual_modal.dart';
import 'package:ASPN_AI_AGENT/ui/screens/admin_leave_approval_screen.dart'
    as admin_leave_approval_screen;
import 'package:ASPN_AI_AGENT/provider/leave_management_provider.dart';
import 'package:ASPN_AI_AGENT/models/leave_management_models.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:ASPN_AI_AGENT/shared/services/leave_api_service.dart';
import 'package:ASPN_AI_AGENT/shared/services/api_service.dart';
import 'package:ASPN_AI_AGENT/features/leave/widgets/vacation_recommendation_popup.dart';
import 'package:ASPN_AI_AGENT/features/leave/providers/vacation_recommendation_provider.dart';
import 'package:ASPN_AI_AGENT/shared/utils/common_ui_utils.dart';
import 'package:ASPN_AI_AGENT/ui/screens/chat_home_page_v5.dart';

// Main Screen
class LeaveManagementScreen extends ConsumerStatefulWidget {
  const LeaveManagementScreen({super.key});

  @override
  ConsumerState<LeaveManagementScreen> createState() =>
      _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends ConsumerState<LeaveManagementScreen>
    with TickerProviderStateMixin {
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();

  bool _isSidebarExpanded = false;
  bool _isSidebarPinned = false;
  bool _isTableExpanded = false;

  // 달력 관련 상태
  DateTime _selectedDate = DateTime.now();
  DateTime _currentCalendarDate = DateTime.now();
  List<Map<String, Object>> _selectedDateDetails = [];
  late PageController _pageController;

  // 공휴일 데이터
  List<Holiday> _holidays = [];

  // 슬라이드 패널 상태
  bool _isDetailPanelVisible = false;

  // 휴가 상세내역 모달 상태
  bool _isLeaveDetailModalVisible = false;
  LeaveRequestHistory? _selectedLeaveDetail;

  // 연도 필터 상태
  int _selectedYear = DateTime.now().year;

  // 사용자 변경 감지를 위한 이전 사용자 ID
  String? _previousUserId;

  // 페이지네이션 상태
  int _personalLeavePage = 0; // 개인별 휴가내역 현재 페이지
  final int _itemsPerPage = 10; // 페이지당 항목 수

  @override
  void initState() {
    super.initState();
    // 2020년 1월부터 현재 월까지의 개월 수 계산
    final monthsFromBase = (_currentCalendarDate.year - 2020) * 12 +
        (_currentCalendarDate.month - 1);
    _pageController = PageController(initialPage: monthsFromBase);
    _updateSelectedDateDetails();

    // 휴가관리 데이터 로드 (현재 로그인된 사용자의 ID 사용)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUserId = ref.read(userIdProvider);

      if (currentUserId != null) {
        _previousUserId = currentUserId; // 이전 사용자 ID 초기화
        ref
            .read(leaveManagementProvider.notifier)
            .loadLeaveManagementData(currentUserId);

        // 관리자 대기 건수 조회
        _loadAdminWaitingCount(currentUserId);

        // 공휴일 데이터 로드
        _loadHolidays(_currentCalendarDate.year, _currentCalendarDate.month);
      } else {
        print('⚠️ 로그인된 사용자 ID가 없습니다. 휴가관리 데이터를 로드할 수 없습니다.');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 사용자 ID 변경 감지 및 상태 초기화
    final currentUserId = ref.read(userIdProvider);

    // 이전 사용자 ID와 현재 사용자 ID가 다르면 상태 초기화
    if (_previousUserId != null &&
        currentUserId != null &&
        _previousUserId != currentUserId) {
      print('🔄 사용자 변경 감지: $_previousUserId -> $currentUserId');
      print('🔄 휴가관리 상태 초기화 및 새 데이터 로드 시작');

      // 상태 초기화 후 새 데이터 로드
      ref.read(leaveManagementProvider.notifier).resetState();
      ref
          .read(leaveManagementProvider.notifier)
          .loadLeaveManagementData(currentUserId);

      // 이전 사용자 ID 업데이트
      _previousUserId = currentUserId;
    } else if (_previousUserId == null && currentUserId != null) {
      // 첫 로드 시 이전 사용자 ID 설정
      _previousUserId = currentUserId;
    }
  }

  // 관리자 대기 건수 조회
  Future<void> _loadAdminWaitingCount(String approverId) async {
    try {
      print('📊 [LeaveManagement] 관리자 대기 건수 조회 시작');
      final waitingLeaves = await LeaveApiService.getAdminWaitingLeaves(
        approverId: approverId,
      );

      final count = waitingLeaves.length;
      print('📊 [LeaveManagement] 대기 건수: $count');

      // Provider에 대기 건수 업데이트
      ref.read(adminWaitingCountProvider.notifier).state = count;
    } catch (e) {
      print('📊 [LeaveManagement] 대기 건수 조회 실패: $e');
      // 실패 시 0으로 설정
      ref.read(adminWaitingCountProvider.notifier).state = 0;
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // 반응형 폰트 크기 계산 함수
  double _getResponsiveFontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    // 1280px 기준으로 계산, 최소 0.8배, 최대 1.2배
    final scaleFactor = (width / 1280).clamp(0.8, 1.2);
    return baseSize * scaleFactor;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        _exitToChatHome();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor:
              isDarkTheme ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5),
          foregroundColor: isDarkTheme ? Colors.white : const Color(0xFF374151),
          elevation: 0,
          title: Text(
            '휴가관리',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: _getResponsiveFontSize(context, 18),
            ),
          ),
          actions: [
            _buildToolbarButtons(),
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
              child: _buildMainContent(),
            ),

          // Dynamic sidebar positioned on the left
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: LeaveRequestSidebar(
              isExpanded: _isSidebarExpanded,
              isPinned: _isSidebarPinned,
              selectedDate: _selectedDate,
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = date;
                  _updateSelectedDateDetails();
                });
              },
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

          // 패널 외부 클릭 감지 (패널이 열려있을 때만) - 달력 영역 제외
          if (_isDetailPanelVisible)
            Positioned.fill(
              child: Stack(
                children: [
                  // 왼쪽 영역 (개인별 휴가내역)
                  Positioned(
                    left: _isSidebarExpanded ? 285 : 50,
                    top: 0,
                    bottom: 0,
                    width: MediaQuery.of(context).size.width * 0.5 -
                        (_isSidebarExpanded ? 285 : 50) -
                        24,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isDetailPanelVisible = false;
                        });
                      },
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                  // 오른쪽 상단 영역 (결재진행현황)
                  Positioned(
                    right: 0,
                    top: 0,
                    height: 118, // 헤더 높이
                    width: MediaQuery.of(context).size.width * 0.5 - 24,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isDetailPanelVisible = false;
                        });
                      },
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 휴가 상세내역 모달
          if (_isLeaveDetailModalVisible)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isLeaveDetailModalVisible = false;
                  });
                },
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ),
            ),

          // 슬라이드 인 모달
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: 0,
            bottom: 0,
            right: _isLeaveDetailModalVisible ? 0 : -500,
            width: 500,
            child: _buildLeaveDetailModal(),
          ),
          ],
        ),
      ),
    );
  }

  // 연도별 휴가 데이터 로드
  Future<void> _loadYearlyData(int year) async {
    try {
      final currentUserId = ref.read(userIdProvider) ?? '';
      if (currentUserId.isEmpty) return;

      final request = YearlyLeaveRequest(
        userId: currentUserId,
        month: year.toString(), // API 명세에 따라 month 필드에 연도값 전송
      );

      final response =
          await LeaveApiService.getYearlyLeaveData(request: request);

      if (response.isSuccess) {
        // 성공 시 휴가관리 데이터 업데이트 (부분 업데이트)
        final currentData = ref.read(leaveManagementProvider).data;
        if (currentData != null) {
          final updatedData = LeaveManagementData(
            leaveStatus: currentData.leaveStatus, // 기존 데이터 유지
            approvalStatus: currentData.approvalStatus, // 기존 데이터 유지
            yearlyDetails: response.yearlyDetails, // 새로운 연도별 데이터로 교체
            yearlyWholeStatus: response.yearlyWholeStatus, // 새로운 연도별 데이터로 교체
            monthlyLeaves: currentData.monthlyLeaves, // 기존 데이터 유지
          );

          // 프로바이더 상태 직접 업데이트
          ref.read(leaveManagementProvider.notifier).updateData(updatedData);
        }
      } else {
        // 실패 시 에러 메시지 표시
        CommonUIUtils.showErrorSnackBar(
            context, response.error ?? '연도별 데이터 로드에 실패했습니다.');
      }
    } catch (e) {
      // 예외 발생 시 에러 메시지 표시
      CommonUIUtils.showErrorSnackBar(context, '연도별 데이터 로드 중 오류가 발생했습니다: $e');
    }
  }

  /// 휴가 취소 상신 다이얼로그 (LeaveRequestHistory용)
  void _showCancelRequestDialogFromHistory(LeaveRequestHistory request) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: const [
            Icon(
              Icons.cancel_outlined,
              color: Color(0xFFE53E3E),
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              '휴가 취소 상신',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 휴가 정보
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event,
                          size: 16, color: Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Text(
                        request.vacationType,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Text(
                        '${DateFormat('yyyy-MM-dd').format(request.startDate)} ~ ${DateFormat('yyyy-MM-dd').format(request.endDate)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 16, color: Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Text(
                        '${request.days}일',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '취소 사유를 입력해주세요:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '예: 일정 변경으로 인한 휴가 취소',
                contentPadding: EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '※ 취소 상신 후 결재자의 승인이 필요합니다.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                CommonUIUtils.showWarningSnackBar(context, '취소 사유를 입력해주세요.');
                return;
              }

              Navigator.pop(context);

              // API 호출
              try {
                final userId = ref.read(userIdProvider) ?? '';
                final result = await LeaveApiService.requestLeaveCancel(
                  id: int.parse(request.id),
                  userId: userId,
                  reason: reasonController.text.trim(),
                );

                if (result.isSuccess) {
                  // ✅ 로컬 상태를 즉시 취소 상신 대기중으로 반영
                  ref
                      .read(leaveManagementProvider.notifier)
                      .markCancelRequestPending(int.parse(request.id));

                  setState(() {
                    _isLeaveDetailModalVisible = false; // 상세 모달 닫기
                  });
                  CommonUIUtils.showSuccessSnackBar(
                      context, '휴가 취소 상신이 완료되었습니다.');
                  // 데이터 새로고침
                  final currentUserId = ref.read(userIdProvider) ?? '';
                  ref
                      .read(leaveManagementProvider.notifier)
                      .loadLeaveManagementData(currentUserId);
                } else {
                  CommonUIUtils.showErrorSnackBar(
                      context, '취소 상신 실패: ${result.error}');
                }
              } catch (e) {
                CommonUIUtils.showErrorSnackBar(
                    context, '취소 상신 중 오류가 발생했습니다: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53E3E),
            ),
            child: const Text('상신'),
          ),
        ],
      ),
    );
  }

  // 관리자 화면으로 이동
  void _navigateToAdminScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) =>
              const admin_leave_approval_screen.AdminLeaveApprovalScreen()),
    );
  }

  void _exitToChatHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const ChatHomePage()),
      (route) => false,
    );
  }

  // 휴가 작성 모달 표시
  void _showLeaveRequestModal() {
    final userId = ref.read(userIdProvider);

    if (userId == null || userId.isEmpty) {
      CommonUIUtils.showErrorSnackBar(context, '사용자 정보를 불러올 수 없습니다.');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => LeaveRequestManualModal(),
    );
  }

  Widget _buildAdminButton() {
    // 승인자 여부 확인 - 승인자만 버튼 표시
    final isApprover = ref.read(approverProvider);

    if (!isApprover) {
      return const SizedBox.shrink(); // 일반사용자는 버튼 숨김
    }

    final waitingCount = ref.watch(adminWaitingCountProvider);

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Badge(
        label: Text(
          waitingCount.toString(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.red,
        isLabelVisible: waitingCount > 0,
        offset: const Offset(8, -8),
        child: ElevatedButton.icon(
          onPressed: _navigateToAdminScreen,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6F42C1),
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.admin_panel_settings, size: 18),
          label: Text(
            '관리자용 결재',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 13),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarButtons() {
    final leaveState = ref.watch(leaveManagementProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 관리자용 결재 버튼
        _buildAdminButton(),
        const SizedBox(width: 8),
        // 취소건 숨김 버튼
        TextButton.icon(
          onPressed: () {
            print('🔘 취소건 숨김 버튼 클릭됨');
            ref
                .read(leaveManagementProvider.notifier)
                .toggleHideCanceledRecords();
            print(
                '🔘 취소건 숨김 상태: ${ref.read(leaveManagementProvider).hideCanceledRecords}');
          },
          icon: Icon(
            leaveState.hideCanceledRecords
                ? Icons.visibility
                : Icons.visibility_off,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF1A1D1F),
          ),
          label: Text(
            '취소건 숨김',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF1A1D1F),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // 휴가 작성 버튼
        ElevatedButton.icon(
          onPressed: _showLeaveRequestModal,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.edit_calendar, size: 18),
          label: Text(
            '휴가 작성',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 13),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMainContent() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 상단 영역: 휴가 현황과 결재진행 현황을 나란히 배치
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 왼쪽: 내 휴가 현황 (더 얇게)
              Expanded(
                flex: 1,
                child: _buildLeaveBalanceHeader(),
              ),
              const SizedBox(width: 16),
              // 오른쪽: 결재진행 현황 헤더와 통계 (더 얇게)
              Expanded(
                flex: 1,
                child: _buildApprovalStatusHeader(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 하단: 개인별 휴가 내역과 휴가 관리 대장을 나란히 배치
          Expanded(
            child: _isTableExpanded
                ? _buildExpandedLeaveManagementTable()
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 왼쪽: 개인별 휴가 내역 (50%)
                      Expanded(
                        flex: 1,
                        child: _buildPersonalLeaveHistory(),
                      ),
                      const SizedBox(width: 16),
                      // 오른쪽: 달력과 휴가 관리 대장 (50%)
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            // 위: 휴가 일정 달력 (60% of remaining space)
                            Expanded(
                              flex: 6,
                              child: _buildCalendarSection(),
                            ),
                            // 아래: 휴가 관리 대장과 슬라이드 패널 (40% of remaining space)
                            Expanded(
                              flex: 4,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // 기본 휴가 관리 대장 - 상단 여백을 Container로 처리
                                  Positioned.fill(
                                    child: Column(
                                      children: [
                                        const SizedBox(height: 20), // 상단 여백
                                        Expanded(
                                            child:
                                                _buildLeaveManagementTable()),
                                      ],
                                    ),
                                  ),
                                  // 슬라이드 패널
                                  AnimatedPositioned(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    top: 0,
                                    bottom: 0,
                                    right: _isDetailPanelVisible ? 0 : -600,
                                    width: 400,
                                    child: _buildDetailPanel(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalStatusHeader() {
    final leaveManagementState = ref.watch(leaveManagementProvider);
    final approvalStatus = leaveManagementState.data?.approvalStatus;
    final totalCount = (approvalStatus?.requested ?? 0) +
        (approvalStatus?.approved ?? 0) +
        (approvalStatus?.rejected ?? 0);
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 102, // 22px 증가
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color:
                isDarkTheme ? const Color(0xFF505050) : const Color(0xFFE8F4FD),
            width: 1),
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
              Icons.assignment_turned_in,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '결재 진행 현황',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 14),
              fontWeight: FontWeight.w700,
              color: isDarkTheme ? Colors.white : const Color(0xFF1E2B3C),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildCompactStatusCard(
                    '대기중',
                    approvalStatus?.requested ?? 0,
                    const Color(0xFFFF8C00),
                    Icons.schedule,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactStatusCard(
                    '승인됨',
                    approvalStatus?.approved ?? 0,
                    const Color(0xFF20C997),
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactStatusCard(
                    '반려됨',
                    approvalStatus?.rejected ?? 0,
                    const Color(0xFFDC3545),
                    Icons.cancel,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '총 ${totalCount}건',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 10),
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E88E5),
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatusCard(
      String title, int count, Color color, IconData icon) {
    final width = MediaQuery.of(context).size.width;
    final scaleFactor = (width / 1280).clamp(0.8, 1.2);

    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 8 * scaleFactor.clamp(0.9, 1.0), // 패딩 축소
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 14 * scaleFactor.clamp(0.9, 1.0),
          ),
          SizedBox(height: 5 * scaleFactor.clamp(0.8, 1.0)),
          Flexible(
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 18),
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: -0.2,
                height: 1.0,
              ),
              maxLines: 1,
            ),
          ),
          SizedBox(height: 4 * scaleFactor.clamp(0.8, 1.0)),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 11),
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.8),
                letterSpacing: -0.1,
                height: 1.0,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalLeaveHistory() {
    final leaveManagementState = ref.watch(leaveManagementProvider);
    final yearlyDetails = leaveManagementState.data?.yearlyDetails ?? [];
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // 취소건 숨김 필터 적용
    final filteredYearlyDetails = leaveManagementState.hideCanceledRecords
        ? yearlyDetails
            .where((detail) =>
                detail.status.toUpperCase() != 'CANCELLED' &&
                detail.status != '취소' &&
                detail.status != '취소됨')
            .toList()
        : yearlyDetails;

    print('\n🔍 [CANCEL_DEBUG] ========== 리스트 필터링 상태 ==========');
    print('📊 전체 휴가내역: ${yearlyDetails.length}개');
    print('📊 필터링된 휴가내역: ${filteredYearlyDetails.length}개');
    print('📊 취소건 숨김 상태: ${leaveManagementState.hideCanceledRecords}');

    // 🔍 [CANCEL_DEBUG] 모든 항목의 is_cancel 값 확인
    if (yearlyDetails.isNotEmpty) {
      print('\n🔍 [CANCEL_DEBUG] === 전체 항목 is_cancel 값 확인 ===');
      for (int i = 0; i < yearlyDetails.length; i++) {
        final detail = yearlyDetails[i];
        print(
            '🔍 [CANCEL_DEBUG] 항목 #${i + 1}: ID=${detail.id}, status=${detail.status}, isCancel=${detail.isCancel}, isCancelRequest=${detail.isCancelRequest}');
        if (detail.isCancelRequest) {
          print('🔍 [CANCEL_DEBUG]   ⭐⭐⭐ 취소상신 발견! ⭐⭐⭐');
        }
      }
    }
    print('🔍 [CANCEL_DEBUG] ========================================\n');

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
            padding: const EdgeInsets.all(16),
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
                  '개인별 휴가 내역',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 16),
                    fontWeight: FontWeight.w600,
                    color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
                  ),
                ),
                const Spacer(),
                // AI 휴가 추천 버튼
                ElevatedButton.icon(
                  onPressed: () => _showVacationRecommendationModal(),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: Text(
                    '내 휴가계획 AI 추천',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 12),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 2,
                  ),
                ),
                const SizedBox(width: 12),
                // 연도 선택 드롭다운
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDarkTheme
                        ? const Color(0xFF3A3A3A)
                        : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: isDarkTheme
                            ? const Color(0xFF505050)
                            : const Color(0xFFE9ECEF)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedYear,
                      isDense: true,
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        size: 14,
                        color: isDarkTheme
                            ? Colors.grey[400]
                            : const Color(0xFF6C757D),
                      ),
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 12),
                        fontWeight: FontWeight.w500,
                        color: isDarkTheme
                            ? Colors.white
                            : const Color(0xFF495057),
                      ),
                      onChanged: (int? newYear) async {
                        if (newYear != null && newYear != _selectedYear) {
                          setState(() {
                            _selectedYear = newYear;
                          });

                          // 연도별 휴가 데이터 로드
                          await _loadYearlyData(newYear);
                        }
                      },
                      items: _getAvailableYears()
                          .map<DropdownMenuItem<int>>((int year) {
                        return DropdownMenuItem<int>(
                          value: year,
                          child: Text('${year}년'),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredYearlyDetails.isEmpty
                ? _buildEmptyLeaveHistoryState()
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount:
                              _getPagedItems(filteredYearlyDetails).length,
                          itemBuilder: (context, index) {
                            final pagedItems =
                                _getPagedItems(filteredYearlyDetails);
                            final detail = pagedItems[index];
                            return _buildYearlyDetailItem(detail);
                          },
                        ),
                      ),
                      _buildPagination(filteredYearlyDetails.length),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveManagementTable() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            border: Border.all(
                color: isDarkTheme
                    ? const Color(0xFF505050)
                    : const Color(0xFFE8F4FD),
                width: 1),
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
              Text(
                '휴가 관리 대장',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isTableExpanded = true;
                  });
                },
                icon: const Icon(Icons.open_in_full),
                iconSize: 16,
                color: isDarkTheme ? Colors.grey[400] : const Color(0xFF6B7280),
                tooltip: '넓게 보기',
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        // 테이블 영역
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border(
                left: BorderSide(
                    color: isDarkTheme
                        ? const Color(0xFF505050)
                        : const Color(0xFFE8F4FD),
                    width: 1),
                right: BorderSide(
                    color: isDarkTheme
                        ? const Color(0xFF505050)
                        : const Color(0xFFE8F4FD),
                    width: 1),
                bottom: BorderSide(
                    color: isDarkTheme
                        ? const Color(0xFF505050)
                        : const Color(0xFFE8F4FD),
                    width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(alpha: isDarkTheme ? 0.3 : 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: max(300.0, constraints.maxWidth), // 최소 300픽셀 보장
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFFE8F4FD), width: 1),
                        ),
                        child: _buildDataTable(
                            isCompact: true, showSubtotal: false),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedLeaveManagementTable() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.all(4),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border.all(
                  color: isDarkTheme
                      ? const Color(0xFF505050)
                      : const Color(0xFFE8F4FD),
                  width: 1),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(alpha: isDarkTheme ? 0.3 : 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  '휴가 관리 대장 (전체 보기)',
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 16),
                    fontWeight: FontWeight.w700,
                    color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isTableExpanded = false;
                    });
                  },
                  icon: const Icon(Icons.close_fullscreen),
                  iconSize: 18,
                  color:
                      isDarkTheme ? Colors.grey[400] : const Color(0xFF6B7280),
                  tooltip: '닫기',
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          // 테이블 영역
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                  8, 16, 24, 16), // 왼쪽 패딩 줄이고 오른쪽 패딩 늘림
              decoration: BoxDecoration(
                color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(
                  left: BorderSide(
                      color: isDarkTheme
                          ? const Color(0xFF505050)
                          : const Color(0xFFE8F4FD),
                      width: 1),
                  right: BorderSide(
                      color: isDarkTheme
                          ? const Color(0xFF505050)
                          : const Color(0xFFE8F4FD),
                      width: 1),
                  bottom: BorderSide(
                      color: isDarkTheme
                          ? const Color(0xFF505050)
                          : const Color(0xFFE8F4FD),
                      width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isDarkTheme ? 0.3 : 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width:
                              max(300.0, constraints.maxWidth), // 최소 300픽셀 보장
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: isDarkTheme
                                    ? const Color(0xFF505050)
                                    : const Color(0xFFE8F4FD),
                                width: 1),
                          ),
                          child: _buildDataTable(
                              isCompact: false, showSubtotal: false),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable({bool isCompact = true, bool showSubtotal = true}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 사용 가능한 너비 계산 - 헤더 컬럼 너비 증가 반영
        final otherColumnsWidth = (isCompact ? 50 : 80) +
            (isCompact ? 55 : 70) +
            (isCompact ? 55 : 70);
        // 최소 너비를 보장하여 음수 방지
        final calculatedWidth = constraints.maxWidth > otherColumnsWidth
            ? constraints.maxWidth -
                otherColumnsWidth -
                (isCompact ? 80 : 120) // 전체보기에서 더 많은 여백
            : (isCompact ? 20 : 30) * 12.0;
        final availableWidth =
            max(240.0, calculatedWidth); // 최소 240픽셀 보장 (12개월 * 20픽셀)
        final monthWidth = availableWidth / 12;

        return _buildDataTableContent(
            isCompact: isCompact,
            showSubtotal: showSubtotal,
            monthWidth: monthWidth,
            totalMonthWidth: availableWidth);
      },
    );
  }

  Widget _buildDataTableContent(
      {required bool isCompact,
      required bool showSubtotal,
      required double monthWidth,
      required double totalMonthWidth}) {
    final leaveManagementState = ref.watch(leaveManagementProvider);
    final yearlyWholeStatus =
        leaveManagementState.data?.yearlyWholeStatus ?? [];
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return DataTable(
      headingRowHeight: isCompact ? 45 : 85,
      dataRowMinHeight: isCompact ? 32 : 48,
      dataRowMaxHeight: isCompact ? 36 : 52,
      columnSpacing: isCompact ? 6 : 14,
      horizontalMargin: isCompact ? 10 : 8, // 전체보기에서 좌측 여백 줄임
      headingRowColor: WidgetStateProperty.all(
          isDarkTheme ? const Color(0xFF3A3A3A) : const Color(0xFFF8FAFC)),
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color:
                isDarkTheme ? const Color(0xFF505050) : const Color(0xFFE5E7EB),
            width: 1),
      ),
      columns: [
        DataColumn(
          label: Container(
            width: isCompact ? 50 : 80,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                    color: isDarkTheme
                        ? const Color(0xFF505050)
                        : const Color(0xFFE5E7EB),
                    width: 1),
              ),
            ),
            child: Text(
              '휴가명',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isCompact ? 11 : 14,
                color: isDarkTheme ? Colors.white : const Color(0xFF374151),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        DataColumn(
          label: Container(
            width: isCompact ? 55 : 70,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                    color: isDarkTheme
                        ? const Color(0xFF505050)
                        : const Color(0xFFE5E7EB),
                    width: 1),
              ),
            ),
            child: Text(
              '허용일수',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isCompact ? 11 : 14,
                color: isDarkTheme ? Colors.white : const Color(0xFF374151),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // 월별 사용일수 헤더
        DataColumn(
          label: Container(
            width: totalMonthWidth,
            padding: EdgeInsets.symmetric(vertical: isCompact ? 2 : 4),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                    color: isDarkTheme
                        ? const Color(0xFF505050)
                        : const Color(0xFFE5E7EB),
                    width: 1),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isCompact) ...[
                  // 기본 휴가관리대장에서는 "사용일수" 제목 숨김
                  Text(
                    '월별 사용 현황',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: _getResponsiveFontSize(context, 14),
                      color:
                          isDarkTheme ? Colors.white : const Color(0xFF374151),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  children: List.generate(12, (index) {
                    return Expanded(
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(vertical: isCompact ? 1 : 2),
                        child: Text(
                          '${index + 1}월',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: isCompact ? 10 : 15,
                            color: isDarkTheme
                                ? Colors.grey[400]
                                : const Color(0xFF6B7280),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        DataColumn(
          label: Container(
            width: isCompact ? 55 : 70,
            child: Text(
              '잔여일수',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isCompact ? 11 : 14,
                color: isDarkTheme ? Colors.white : const Color(0xFF374151),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
      rows: [
        // 데이터 행들 - 연차 데이터 표시
        ...yearlyWholeStatus
            .where((data) => data.leaveType != '총계')
            .map((data) {
          final monthlyUsage = [
            data.m01,
            data.m02,
            data.m03,
            data.m04,
            data.m05,
            data.m06,
            data.m07,
            data.m08,
            data.m09,
            data.m10,
            data.m11,
            data.m12,
          ];
          final remaining = data.remainDays;

          return DataRow(
            color: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.hovered)) {
                return isDarkTheme
                    ? const Color(0xFF4A4A4A)
                    : const Color(0xFFF3F4F6);
              }
              return Colors.transparent;
            }),
            cells: [
              DataCell(
                Container(
                  width: isCompact ? 50 : 80,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                          color: isDarkTheme
                              ? const Color(0xFF505050)
                              : const Color(0xFFE5E7EB),
                          width: 1),
                    ),
                  ),
                  child: Text(
                    data.leaveType,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isCompact ? 11 : 14,
                      color:
                          isDarkTheme ? Colors.white : const Color(0xFF374151),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              DataCell(
                Container(
                  width: isCompact ? 55 : 70,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                          color: isDarkTheme
                              ? const Color(0xFF505050)
                              : const Color(0xFFE5E7EB),
                          width: 1),
                    ),
                  ),
                  child: Text(
                    '${data.totalDays}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isCompact ? 11 : 14,
                      color:
                          isDarkTheme ? Colors.white : const Color(0xFF374151),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              // 월별 사용일수를 하나의 셀로
              DataCell(
                Container(
                  width: totalMonthWidth,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                          color: isDarkTheme
                              ? const Color(0xFF505050)
                              : const Color(0xFFE5E7EB),
                          width: 1),
                    ),
                  ),
                  child: Row(
                    children: monthlyUsage.asMap().entries.map((entry) {
                      final days = entry.value;

                      return Expanded(
                        child: Text(
                          days > 0 ? '$days' : '-',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isCompact ? 10 : 12,
                            color: days > 0
                                ? (isDarkTheme
                                    ? Colors.white
                                    : const Color(0xFF374151))
                                : (isDarkTheme
                                    ? Colors.grey[500]
                                    : const Color(0xFF9CA3AF)),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              DataCell(
                Container(
                  width: isCompact ? 55 : 70,
                  child: Text(
                    '$remaining',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isCompact ? 11 : 14,
                      color: remaining > 0
                          ? (isDarkTheme
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFF059669))
                          : (isDarkTheme
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFDC2626)),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        }),
        // 소계 행 (조건부 표시)
        if (showSubtotal)
          DataRow(
            color: WidgetStateProperty.all(isDarkTheme
                ? const Color(0xFF3A3A3A)
                : const Color(0xFFF9FAFB)),
            cells: [
              DataCell(
                Container(
                  width: isCompact ? 50 : 80,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                          color: isDarkTheme
                              ? const Color(0xFF505050)
                              : const Color(0xFFE5E7EB),
                          width: 1),
                    ),
                  ),
                  child: Text(
                    '소계',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: isCompact ? 11 : 14,
                      color: const Color(0xFF374151),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              DataCell(
                Container(
                  width: isCompact ? 55 : 70,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                          color: isDarkTheme
                              ? const Color(0xFF505050)
                              : const Color(0xFFE5E7EB),
                          width: 1),
                    ),
                  ),
                  child: Text(
                    '${yearlyWholeStatus.fold<double>(0, (sum, data) => sum + data.totalDays)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: isCompact ? 11 : 14,
                      color: const Color(0xFF1E88E5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              // 월별 소계를 하나의 셀로
              DataCell(
                Container(
                  width: totalMonthWidth,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                          color: isDarkTheme
                              ? const Color(0xFF505050)
                              : const Color(0xFFE5E7EB),
                          width: 1),
                    ),
                  ),
                  child: Row(
                    children: List.generate(12, (monthIndex) {
                      final monthTotal =
                          yearlyWholeStatus.fold<double>(0, (sum, data) {
                        final monthlyUsage = [
                          data.m01,
                          data.m02,
                          data.m03,
                          data.m04,
                          data.m05,
                          data.m06,
                          data.m07,
                          data.m08,
                          data.m09,
                          data.m10,
                          data.m11,
                          data.m12,
                        ];
                        return sum + monthlyUsage[monthIndex];
                      });
                      return Expanded(
                        child: Text(
                          monthTotal > 0 ? '$monthTotal' : '-',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: isCompact ? 10 : 13,
                            color: monthTotal > 0
                                ? const Color(0xFF374151)
                                : const Color(0xFF9CA3AF),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }),
                  ),
                ),
              ),
              DataCell(
                Container(
                  width: isCompact ? 55 : 70,
                  child: Text(
                    '${yearlyWholeStatus.fold<double>(0, (sum, data) => sum + data.remainDays)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: isCompact ? 11 : 14,
                      color: const Color(0xFF059669),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        // 총계 행 - 서버에서 보내주는 총계 데이터 사용
        ...yearlyWholeStatus
            .where((data) => data.leaveType == '총계')
            .map((data) {
          final monthlyUsage = [
            data.m01,
            data.m02,
            data.m03,
            data.m04,
            data.m05,
            data.m06,
            data.m07,
            data.m08,
            data.m09,
            data.m10,
            data.m11,
            data.m12,
          ];
          final remaining = data.remainDays;

          return DataRow(
            color: WidgetStateProperty.all(isDarkTheme
                ? const Color(0xFF4A4A4A)
                : const Color(0xFFF1F5F9)),
            cells: [
              DataCell(
                Container(
                  width: isCompact ? 50 : 80,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                          color: isDarkTheme
                              ? const Color(0xFF505050)
                              : const Color(0xFFE5E7EB),
                          width: 1),
                    ),
                  ),
                  child: Text(
                    '총계',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: isCompact ? 11 : 14,
                      color: isDarkTheme
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFF1E40AF),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              DataCell(
                Container(
                  width: isCompact ? 55 : 70,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                          color: isDarkTheme
                              ? const Color(0xFF505050)
                              : const Color(0xFFE5E7EB),
                          width: 1),
                    ),
                  ),
                  child: Text(
                    '${data.totalDays}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: isCompact ? 11 : 14,
                      color: isDarkTheme
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFF1E40AF),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              // 월별 총계를 하나의 셀로
              DataCell(
                Container(
                  width: totalMonthWidth,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                          color: isDarkTheme
                              ? const Color(0xFF505050)
                              : const Color(0xFFE5E7EB),
                          width: 1),
                    ),
                  ),
                  child: Row(
                    children: monthlyUsage.asMap().entries.map((entry) {
                      final days = entry.value;

                      return Expanded(
                        child: Text(
                          days > 0 ? '$days' : '-',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: isCompact ? 10 : 13,
                            color: days > 0
                                ? (isDarkTheme
                                    ? const Color(0xFF60A5FA)
                                    : const Color(0xFF1E40AF))
                                : (isDarkTheme
                                    ? Colors.grey[500]
                                    : const Color(0xFF9CA3AF)),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              DataCell(
                Container(
                  width: isCompact ? 55 : 70,
                  child: Text(
                    '$remaining',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: isCompact ? 11 : 14,
                      color: isDarkTheme
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFF059669),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildYearlyDetailItem(YearlyDetail detail) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // 🔍 [CANCEL_DEBUG] UI 렌더링 시작
    print('\n🔍 [CANCEL_DEBUG] ========== UI 렌더링 시작 ==========');
    print('🔍 [CANCEL_DEBUG] 휴가 항목 ID: ${detail.id}');
    print('🔍 [CANCEL_DEBUG] leave_type: ${detail.leaveType}');
    print('🔍 [CANCEL_DEBUG] status: ${detail.status}');
    print('🔍 [CANCEL_DEBUG] isCancel 값: ${detail.isCancel}');
    print('🔍 [CANCEL_DEBUG] isCancelRequest 값: ${detail.isCancelRequest}');
    print(
        '🔍 [CANCEL_DEBUG] 취소상신 배지 표시 여부: ${detail.isCancelRequest ? "✅ 표시됨" : "❌ 표시 안 됨"}');
    if (detail.isCancelRequest) {
      print('🔍 [CANCEL_DEBUG] ⭐⭐⭐ 취소상신 배지가 화면에 표시되어야 합니다! ⭐⭐⭐');
    }
    print('🔍 [CANCEL_DEBUG] ========== UI 렌더링 종료 ==========\n');

    // 취소 상신 대기 중인 경우 다른 색상 적용
    final Color statusColor;
    if (detail.isCancelRequest &&
        (detail.status.toUpperCase() == 'REQUESTED' ||
            detail.status.toUpperCase() == 'PENDING')) {
      statusColor = const Color(0xFFE53E3E); // 취소 상신 대기: 빨간색
    } else {
      final statusColorMap = {
        'REQUESTED': const Color(0xFFFF8C00),
        'PENDING': const Color(0xFFFF8C00),
        'APPROVED': const Color(0xFF20C997),
        'REJECTED': const Color(0xFFDC3545),
        'CANCELLED': const Color(0xFF6C757D),
        'CANCEL_REQUESTED': const Color(0xFFFF6B00), // 취소 대기: 진한 오렌지색
        'HOLIDAY': const Color(0xFFE53E3E), // 공휴일: 빨간색
      };
      statusColor = statusColorMap[detail.status.toUpperCase()] ??
          const Color(0xFF1E88E5);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLeaveDetail = _convertToLeaveRequestHistory(detail);
          _isLeaveDetailModalVisible = true;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDarkTheme ? const Color(0xFF3A3A3A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isDarkTheme ? const Color(0xFF505050) : const Color(0xFFE8F4FD),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _getStatusTextForDetail(detail),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                // 취소 상신 배지
                if (detail.isCancelRequest) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                          size: 10,
                          color: const Color(0xFFE53E3E),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '취소 상신',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFE53E3E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  detail.leaveType,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDarkTheme ? Colors.white : const Color(0xFF1E2B3C),
                  ),
                ),
                const Spacer(),
                Text(
                  '${detail.workdaysCount}일',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDarkTheme
                        ? const Color(0xFF64B5F6)
                        : const Color(0xFF1E88E5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color:
                      isDarkTheme ? Colors.grey[400] : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Text(
                  '${DateFormat('MM/dd').format(detail.startDate)} ~ ${DateFormat('MM/dd').format(detail.endDate)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkTheme
                        ? Colors.grey[400]
                        : const Color(0xFF6B7280),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MM/dd').format(detail.requestedDate),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkTheme
                        ? Colors.grey[500]
                        : const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
            // reason 표시 (취소사유가 있으면 특별한 UI로 표시)
            if (detail.reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildReasonText(detail.reason),
            ],

            // 반려 사유 표시
            if (detail.rejectMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '반려 사유: ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color:
                          isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      detail.rejectMessage,
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
          ],
        ),
      ),
    );
  }

  /// 취소사유가 포함된 reason을 파싱하여 표시 (관리자 화면과 동일한 로직)
  Widget _buildReasonText(String reason) {
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
                          fontSize: 11,
                          color: isDarkTheme
                              ? Colors.grey[300]
                              : const Color(0xFF495057),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 원래 신청 사유가 있으면 표시
          if (originalReason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkTheme
                    ? const Color(0xFF404040)
                    : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '원래 신청 사유',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDarkTheme ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    originalReason,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkTheme ? Colors.grey[400] : Colors.grey[700],
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    } else {
      // 일반 사유
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              isDarkTheme ? const Color(0xFF404040) : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          reason,
          style: TextStyle(
            fontSize: 11,
            color: isDarkTheme ? Colors.grey[400] : const Color(0xFF6B7280),
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
  }

  LeaveRequestHistory _convertToLeaveRequestHistory(YearlyDetail detail) {
    // YearlyDetail을 기존 LeaveRequestHistory로 변환하여 기존 모달을 재사용
    return LeaveRequestHistory(
      id: detail.id.toString(),
      applicantName: '사용자', // 기본값 설정
      department: '개발팀', // 기본값 설정
      vacationType: detail.leaveType,
      startDate: detail.startDate,
      endDate: detail.endDate,
      days: detail.workdaysCount,
      reason: detail.reason,
      status: _convertStatusToEnum(detail.status),
      submittedDate: detail.requestedDate,
      approverComment:
          detail.rejectMessage.isNotEmpty ? detail.rejectMessage : null,
    );
  }

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
      case 'CANCEL_REQUESTED':
      case '취소 대기':
      case '🔄 취소 대기':
        return LeaveRequestStatus.cancelRequested;
      case 'CANCEL_PENDING':
      case '연차 취소 대기':
        // 취소 대기 상태는 pending으로 표시하되, UI에서는 별도로 표시
        return LeaveRequestStatus.pending;
      default:
        print('⚠️ 알 수 없는 상태값: $status, PENDING으로 설정');
        return LeaveRequestStatus.pending;
    }
  }

  String _getStatusText(String status) {
    switch (status.toUpperCase()) {
      case 'REQUESTED':
      case 'PENDING':
        return '대기';
      case 'APPROVED':
        return '승인';
      case 'REJECTED':
        return '반려';
      case 'CANCELLED':
        return '취소';
      case 'CANCEL_PENDING':
        return '연차 취소 대기';
      case 'CANCEL_REQUESTED':
        return '🔄 취소 대기';
      default:
        return status;
    }
  }

  /// YearlyDetail에 대한 상태 텍스트 (취소 상신 구분)
  String _getStatusTextForDetail(YearlyDetail detail) {
    // 취소 상신 대기 중인 경우
    if (detail.isCancelRequest &&
        (detail.status.toUpperCase() == 'REQUESTED' ||
            detail.status.toUpperCase() == 'PENDING')) {
      return '취소 상신 대기';
    }
    // 일반 상태
    return _getStatusText(detail.status);
  }

  // Widget _buildApprovalItem(LeaveRequestHistory request) {
  //   // 토스 스타일 결재 항목 - 블루 톤으로 통일, 컴팩트하게 수정
  //   final statusColorMap = {
  //     LeaveRequestStatus.pending: const Color(0xFFFF8C00),
  //     LeaveRequestStatus.approved: const Color(0xFF20C997),
  //     LeaveRequestStatus.rejected: const Color(0xFFDC3545),
  //     LeaveRequestStatus.cancelled: const Color(0xFF6C757D),
  //   };

  //   final statusColor =
  //       statusColorMap[request.status] ?? const Color(0xFF1E88E5);
  //   final isRecent =
  //       DateTime.now().difference(request.submittedDate).inDays < 7;

  //   return GestureDetector(
  //     onTap: () {
  //       setState(() {
  //         _selectedLeaveDetail = request;
  //         _isLeaveDetailModalVisible = true;
  //       });
  //     },
  //     child: Container(
  //       margin: const EdgeInsets.only(bottom: 8),
  //       padding: const EdgeInsets.all(12),
  //       decoration: BoxDecoration(
  //         color: Colors.white,
  //         borderRadius: BorderRadius.circular(12),
  //         border: Border.all(
  //           color: const Color(0xFFE8F4FD),
  //           width: 1,
  //         ),
  //       ),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           // 메인 정보를 한 줄에 배치
  //           Row(
  //             children: [
  //               Container(
  //                 padding:
  //                     const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  //                 decoration: BoxDecoration(
  //                   color: statusColor.withValues(alpha:0.1),
  //                   borderRadius: BorderRadius.circular(16),
  //                 ),
  //                 child: Text(
  //                   request.status.label,
  //                   style: TextStyle(
  //                     fontSize: 11,
  //                     fontWeight: FontWeight.w600,
  //                     color: statusColor,
  //                     letterSpacing: -0.1,
  //                   ),
  //                 ),
  //               ),
  //               const SizedBox(width: 6),
  //               Container(
  //                 padding:
  //                     const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  //                 decoration: BoxDecoration(
  //                   color: const Color(0xFF1E88E5).withValues(alpha:0.08),
  //                   borderRadius: BorderRadius.circular(8),
  //                 ),
  //                 child: Text(
  //                   request.vacationType,
  //                   style: const TextStyle(
  //                     fontSize: 10,
  //                     fontWeight: FontWeight.w500,
  //                     color: Color(0xFF1E88E5),
  //                     letterSpacing: -0.1,
  //                   ),
  //                 ),
  //               ),
  //               const SizedBox(width: 8),
  //               Icon(
  //                 Icons.calendar_today_outlined,
  //                 size: 13,
  //                 color: const Color(0xFF1E2B3C).withValues(alpha:0.6),
  //               ),
  //               const SizedBox(width: 4),
  //               Text(
  //                 '${DateFormat('MM.dd').format(request.startDate)} - ${DateFormat('MM.dd').format(request.endDate)}',
  //                 style: const TextStyle(
  //                   fontSize: 14,
  //                   fontWeight: FontWeight.w700,
  //                   color: Colors.black,
  //                   letterSpacing: -0.1,
  //                 ),
  //               ),
  //               const SizedBox(width: 8),
  //               if (request.reason.isNotEmpty) ...[
  //                 Icon(
  //                   Icons.description_outlined,
  //                   size: 11,
  //                   color: const Color(0xFF1E2B3C).withValues(alpha:0.5),
  //                 ),
  //                 const SizedBox(width: 4),
  //                 Expanded(
  //                   child: Text(
  //                     request.reason,
  //                     style: TextStyle(
  //                       fontSize: 11,
  //                       fontWeight: FontWeight.w400,
  //                       color: const Color(0xFF1E2B3C).withValues(alpha:0.7),
  //                       height: 1.3,
  //                       letterSpacing: -0.1,
  //                     ),
  //                     maxLines: 1,
  //                     overflow: TextOverflow.ellipsis,
  //                   ),
  //                 ),
  //                 const SizedBox(width: 8),
  //               ] else ...[
  //                 const Spacer(),
  //               ],
  //               Icon(
  //                 Icons.access_time_outlined,
  //                 size: 11,
  //                 color: const Color(0xFF1E2B3C).withValues(alpha:0.5),
  //               ),
  //               const SizedBox(width: 3),
  //               Text(
  //                 '신청: ${DateFormat('MM.dd').format(request.submittedDate)}',
  //                 style: TextStyle(
  //                   fontSize: 10,
  //                   fontWeight: FontWeight.w500,
  //                   color: const Color(0xFF1E2B3C).withValues(alpha:0.5),
  //                 ),
  //               ),
  //               const SizedBox(width: 8),
  //               if (isRecent)
  //                 Container(
  //                   padding:
  //                       const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  //                   decoration: BoxDecoration(
  //                     color: const Color(0xFF1E88E5).withValues(alpha:0.1),
  //                     borderRadius: BorderRadius.circular(8),
  //                   ),
  //                   child: const Text(
  //                     'NEW',
  //                     style: TextStyle(
  //                       fontSize: 9,
  //                       fontWeight: FontWeight.w700,
  //                       color: Color(0xFF1E88E5),
  //                       letterSpacing: 0.2,
  //                     ),
  //                   ),
  //                 ),
  //               if (isRecent) const SizedBox(width: 6),
  //               Container(
  //                 padding:
  //                     const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  //                 decoration: BoxDecoration(
  //                   color: const Color(0xFF1E88E5),
  //                   borderRadius: BorderRadius.circular(6),
  //                 ),
  //                 child: Text(
  //                   '${request.days}일',
  //                   style: const TextStyle(
  //                     fontSize: 11,
  //                     fontWeight: FontWeight.w700,
  //                     color: Colors.white,
  //                   ),
  //                 ),
  //               ),
  //             ],
  //           ),
  //           // 관리자 메시지는 반려됨 상태일 때만 표시 (아래 줄에)
  //           if (request.status == LeaveRequestStatus.rejected &&
  //               request.approverComment != null &&
  //               request.approverComment!.isNotEmpty) ...[
  //             const SizedBox(height: 8),
  //             Container(
  //               padding: const EdgeInsets.all(8),
  //               decoration: BoxDecoration(
  //                 color: const Color(0xFFDC3545).withValues(alpha:0.05),
  //                 borderRadius: BorderRadius.circular(8),
  //                 border: Border.all(
  //                   color: const Color(0xFFDC3545).withValues(alpha:0.1),
  //                   width: 1,
  //                 ),
  //               ),
  //               child: Row(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Icon(
  //                     Icons.comment_outlined,
  //                     size: 13,
  //                     color: const Color(0xFFDC3545),
  //                   ),
  //                   const SizedBox(width: 6),
  //                   Expanded(
  //                     child: Text(
  //                       request.approverComment!,
  //                       style: const TextStyle(
  //                         fontSize: 11,
  //                         fontWeight: FontWeight.w500,
  //                         color: Color(0xFFDC3545),
  //                         height: 1.3,
  //                         letterSpacing: -0.1,
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildLeaveBalanceHeader() {
    // 휴가 잔여량 헤더
    final leaveManagementState = ref.watch(leaveManagementProvider);
    final leaveBalances = leaveManagementState.data?.leaveStatus ?? [];
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 102, // 22px 증가
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color:
                isDarkTheme ? const Color(0xFF505050) : const Color(0xFFE8F4FD),
            width: 1),
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
          // 아이콘과 제목
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '내 휴가 현황',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDarkTheme ? Colors.white : const Color(0xFF1E2B3C),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 16),

          // 휴가 잔여량 카드들
          Expanded(
            child: Row(
              children: [
                // 최대 3개까지만 표시
                ...leaveBalances.take(3).map((balance) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDarkTheme
                            ? const Color(0xFF3A3A3A)
                            : const Color(0xFFF3F8FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isDarkTheme
                                ? const Color(0xFF505050)
                                : const Color(0xFF1E88E5)
                                    .withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            balance.leaveType,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDarkTheme
                                  ? Colors.grey[400]
                                  : const Color(0xFF1E2B3C)
                                      .withValues(alpha: 0.6),
                              letterSpacing: -0.1,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${balance.remainDays}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E88E5),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Text(
                                '/${balance.totalDays}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDarkTheme
                                      ? Colors.grey[400]
                                      : const Color(0xFF1E2B3C)
                                          .withValues(alpha: 0.5),
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: balance.totalDays > 0
                                ? balance.remainDays / balance.totalDays
                                : 0,
                            backgroundColor: const Color(0xFFE3F2FD),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF1E88E5)),
                            minHeight: 3,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                // 4개 이상일 때 "+n개 더보기" 버튼 표시
                if (leaveBalances.length > 3)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showAllLeaveBalancesModal(leaveBalances),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDarkTheme
                              ? const Color(0xFF3A3A3A)
                              : const Color(0xFFF3F8FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: isDarkTheme
                                  ? const Color(0xFF505050)
                                  : const Color(0xFF1E88E5)
                                      .withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              color: const Color(0xFF1E88E5),
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '+${leaveBalances.length - 3}개',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E88E5),
                                letterSpacing: -0.1,
                              ),
                            ),
                            Text(
                              '더보기',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: isDarkTheme
                                    ? Colors.grey[400]
                                    : const Color(0xFF1E2B3C)
                                        .withValues(alpha: 0.6),
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 오늘 날짜
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              DateFormat('MM.dd').format(DateTime.now()),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E88E5),
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 달력 섹션 위젯
  Widget _buildCalendarSection() {
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
          // 달력 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_month,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '휴가 일정 달력',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color:
                          isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
                    ),
                  ),
                ),
                // 넓게보기 버튼 추가
                IconButton(
                  onPressed: _showFullCalendarModal,
                  icon: Icon(
                    Icons.fullscreen,
                    color: isDarkTheme
                        ? const Color(0xFF64B5F6)
                        : const Color(0xFF1E88E5),
                    size: 18,
                  ),
                  tooltip: '넓게보기',
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          // 달력 본문
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildCalendar(),
            ),
          ),
        ],
      ),
    );
  }

  // 달력 위젯
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
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                final baseDate = DateTime(2020, 1);
                _currentCalendarDate =
                    DateTime(baseDate.year, baseDate.month + index);
                _updateSelectedDateDetails();

                // 해당 월의 달력 데이터만 로드
                final currentUserId = ref.read(userIdProvider);

                if (currentUserId != null) {
                  final monthString =
                      '${_currentCalendarDate.year}-${_currentCalendarDate.month.toString().padLeft(2, '0')}';
                  ref
                      .read(leaveManagementProvider.notifier)
                      .loadMonthlyCalendarData(currentUserId, monthString);
                } else {
                  print('⚠️ 로그인된 사용자 ID가 없습니다. 월별 달력 데이터를 로드할 수 없습니다.');
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

  // 월별 달력 빌더
  Widget _buildMonthCalendar(DateTime monthDate) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
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
                                : (isDarkTheme
                                    ? Colors.grey[400]
                                    : const Color(0xFF6C757D)
                                        .withValues(alpha: 0.8)),
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

    // API 데이터 사용
    final leaveManagementState = ref.watch(leaveManagementProvider);
    final monthlyLeaves = leaveManagementState.data?.monthlyLeaves ?? [];

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
        monthlyLeaves: monthlyLeaves,
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
        monthlyLeaves: monthlyLeaves,
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
  }

  // 날짜 셀 생성
  Widget _buildDateCell(
    int day,
    DateTime date, {
    required bool isCurrentMonth,
    required DateTime today,
    required List<MonthlyLeave> monthlyLeaves,
  }) {
    // 화면 크기에 따른 점 크기 계산
    final screenWidth = MediaQuery.of(context).size.width;
    final dotSize = screenWidth > 1600
        ? 5.0
        : screenWidth > 1200
            ? 4.5
            : 4.0;
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final isSelected = date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day;

    // 해당 날짜의 휴가 정보들 수집 (날짜 부분만 비교)
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

    // 상태별 개수 계산 (대소문자 무관)
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

    // 휴가 상태에 따른 색상 결정 (우선순위: pending > approved > rejected > cancelled)
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
            // 패널을 항상 열기 (이미 열려있으면 내용만 업데이트)
            _isDetailPanelVisible = true;
          });
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
                    ],
                  ),
                ),
                if (hasLeave && isCurrentMonth)
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
        ),
      ),
    );
  }

  // 빈 상세 정보 상태
  Widget _buildEmptyDetailsState() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 24,
              color: isDarkTheme ? Colors.grey[500] : Colors.grey[400],
            ),
            const SizedBox(height: 6),
            Text(
              '선택된 날짜에\n휴가 일정이 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 빈 휴가 내역 상태
  Widget _buildEmptyLeaveHistoryState() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkTheme
                    ? const Color(0xFF3A3A3A)
                    : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.event_busy_outlined,
                size: 32,
                color: isDarkTheme ? Colors.grey[500] : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${_selectedYear}년 휴가 내역이 없습니다.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkTheme ? Colors.grey[300] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '다른 연도를 선택하시거나\n새로운 휴가를 신청해보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkTheme ? Colors.grey[400] : Colors.grey[500],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 상세 항목
  Widget _buildDetailItem(Map<String, Object> detail) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final statusString = (detail['status'] as String?) ?? 'REQUESTED';
    print('📝 휴가내역 상태: $statusString');

    // 공휴일 상태 특별 처리
    if (statusString == 'HOLIDAY') {
      final statusColor = const Color(0xFFE53E3E); // 공휴일: 빨간색

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
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Text(
                  '공휴일',
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
          ));
    }

    final status = _convertStatusToEnum(statusString);
    // 취소 대기 상태는 별도 색상 처리
    final isCancelPending = statusString.toUpperCase() == 'CANCEL_PENDING' ||
        statusString.toUpperCase() == '취소 대기' ||
        statusString.toUpperCase() == '연차 취소 대기';
    final finalStatusColor = isCancelPending
        ? const Color(0xFFFF9800) // 취소 대기 상태 색상
        : {
              LeaveRequestStatus.pending: const Color(0xFFFF8C00),
              LeaveRequestStatus.approved: const Color(0xFF20C997),
              LeaveRequestStatus.rejected: const Color(0xFFDC3545),
              LeaveRequestStatus.cancelled: const Color(0xFF6C757D),
            }[status] ??
            const Color(0xFF1E88E5);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkTheme
            ? finalStatusColor.withValues(alpha: 0.1)
            : finalStatusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: finalStatusColor.withValues(alpha: isDarkTheme ? 0.3 : 0.2)),
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
                  color: finalStatusColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  isCancelPending ? '연차 취소 대기' : status.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              // 취소 상신 배지
              if (detail['is_cancel'] == 1 || detail['isCancel'] == 1) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                        size: 10,
                        color: const Color(0xFFE53E3E),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '취소 상신',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE53E3E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
          if ((detail['reason'] as String?) != null &&
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
          // 반려 사유 표시
          if (detail['reject_message'] != null &&
              detail['reject_message'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '반려 사유: ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
                  ),
                ),
                Expanded(
                  child: Text(
                    detail['reject_message'].toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDarkTheme
                          ? Colors.grey[400]
                          : const Color(0xFF6C757D),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (detail['startDate'] != null && detail['endDate'] != null) ...[
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

  // 선택된 날짜의 상세정보 업데이트
  void _updateSelectedDateDetails() {
    final leaveManagementState = ref.read(leaveManagementProvider);
    final monthlyLeaves = leaveManagementState.data?.monthlyLeaves ?? [];

    _selectedDateDetails = monthlyLeaves
        .where((leave) {
          // 날짜 부분만 비교하여 정확한 범위 계산
          final startDateLocal = DateTime(
              leave.startDate.year, leave.startDate.month, leave.startDate.day);
          final endDateLocal = DateTime(
              leave.endDate.year, leave.endDate.month, leave.endDate.day);
          final selectedDateLocal = DateTime(
              _selectedDate.year, _selectedDate.month, _selectedDate.day);

          // endDate까지 포함하여 표시 (inclusive)
          return (selectedDateLocal.isAtSameMomentAs(startDateLocal) ||
              selectedDateLocal.isAtSameMomentAs(endDateLocal) ||
              (selectedDateLocal.isAfter(startDateLocal) &&
                  selectedDateLocal.isBefore(endDateLocal)));
        })
        .map((leave) => <String, Object>{
              'status': leave.status,
              'vacationType': leave.leaveType,
              'employeeName': '신청자', // 실제 구현에서는 실제 직원 이름 사용
              'department': '',
              'jobPosition': '',
              'reason': leave.reason,
              'startDate': leave.startDate,
              'endDate': leave.endDate,
              'halfDaySlot': '',
            })
        .toList();

    // 상태별 우선순위에 따라 정렬: 대기중 → 승인됨 → 반려됨 → 취소됨
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

  // 사용 가능한 연도 목록 반환
  List<int> _getAvailableYears() {
    final currentYear = DateTime.now().year;
    // 2020년부터 2026년까지의 목록 생성 (최대 2026년까지)
    final maxYear = currentYear > 2026 ? currentYear : 2026;
    return List.generate(
      maxYear - 2019,
      (index) => 2020 + index,
    ).reversed.toList(); // 최신 연도부터 표시
  }

  // 선택된 연도에 따른 휴가 내역 필터링
  // List<LeaveRequestHistory> _getFilteredLeaveHistory(
  //     List<LeaveRequestHistory> allHistory) {
  //   return allHistory.where((history) {
  //     return history.startDate.year == _selectedYear;
  //   }).toList();
  // }

  // 넓게보기 모달 표시 (관리자 화면과 동일한 모달 재사용)
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
                      Colors.black.withValues(alpha: isDarkTheme ? 0.4 : 0.1),
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

  // 슬라이드 디테일 패널
  Widget _buildDetailPanel() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkTheme ? 0.3 : 0.1),
            blurRadius: 20,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 패널 헤더 (더 컴팩트하게)
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
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.event_note,
                    color: Color(0xFF1E88E5),
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isDetailPanelVisible = false;
                    });
                  },
                  icon: Icon(
                    Icons.close,
                    color: isDarkTheme
                        ? Colors.grey[400]
                        : const Color(0xFF6C757D),
                    size: 16,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 20, minHeight: 20),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          // 패널 내용
          Expanded(
            child: _selectedDateDetails.isEmpty
                ? _buildEmptyDetailsState()
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
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

  // 휴가 상세내역 모달
  Widget _buildLeaveDetailModal() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    if (_selectedLeaveDetail == null) {
      return Container();
    }

    final request = _selectedLeaveDetail!;
    final statusColorMap = {
      LeaveRequestStatus.pending: const Color(0xFFFF8C00),
      LeaveRequestStatus.approved: const Color(0xFF20C997),
      LeaveRequestStatus.rejected: const Color(0xFFDC3545),
      LeaveRequestStatus.cancelled: const Color(0xFF6C757D),
      LeaveRequestStatus.cancelRequested:
          const Color(0xFFFF6B00), // 취소 대기: 진한 오렌지색
    };
    final statusColor =
        statusColorMap[request.status] ?? const Color(0xFF1E88E5);

    return Container(
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkTheme ? 0.3 : 0.15),
            blurRadius: 30,
            offset: const Offset(-8, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  statusColor.withValues(alpha: 0.1),
                  isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.event_note,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '휴가 상세내역',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: isDarkTheme
                                  ? Colors.white
                                  : const Color(0xFF1A1D29),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  request.status.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                              // 취소 상신 배지 (YearlyDetail에서 변환된 경우)
                              if (_selectedLeaveDetail != null &&
                                  _selectedLeaveDetail!.id.isNotEmpty) ...[
                                Builder(
                                  builder: (context) {
                                    // YearlyDetail에서 변환된 경우 isCancel 정보 확인
                                    final detailId =
                                        int.tryParse(_selectedLeaveDetail!.id);
                                    if (detailId != null) {
                                      final leaveManagementState =
                                          ref.watch(leaveManagementProvider);
                                      final yearlyDetails = leaveManagementState
                                              .data?.yearlyDetails ??
                                          [];
                                      final detail = yearlyDetails.firstWhere(
                                        (d) => d.id == detailId,
                                        orElse: () => YearlyDetail(
                                          id: 0,
                                          status: '',
                                          leaveType: '',
                                          startDate: DateTime.now(),
                                          endDate: DateTime.now(),
                                          workdaysCount: 0,
                                          requestedDate: DateTime.now(),
                                          reason: '',
                                          rejectMessage: '',
                                        ),
                                      );
                                      if (detail.id != 0 &&
                                          detail.isCancelRequest) {
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(left: 8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE53E3E)
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color(0xFFE53E3E)
                                                    .withValues(alpha: 0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.cancel_outlined,
                                                  size: 12,
                                                  color:
                                                      const Color(0xFFE53E3E),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '취소 상신',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        const Color(0xFFE53E3E),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isLeaveDetailModalVisible = false;
                        });
                      },
                      icon: Icon(
                        Icons.close,
                        color: isDarkTheme
                            ? Colors.grey[400]
                            : const Color(0xFF6C757D),
                        size: 24,
                      ),
                      tooltip: '닫기',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 내용
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 기본 정보
                  _buildDetailSection(
                    '기본 정보',
                    Icons.info_outline,
                    [
                      _buildDetailRow('휴가 유형', request.vacationType),
                      _buildDetailRow('휴가 기간',
                          '${DateFormat('yyyy년 MM월 dd일').format(request.startDate)} - ${DateFormat('yyyy년 MM월 dd일').format(request.endDate)}'),
                      _buildDetailRow('신청 일수', '${request.days}일'),
                      _buildDetailRow(
                          '신청일',
                          DateFormat('yyyy년 MM월 dd일')
                              .format(request.submittedDate)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 신청 사유
                  if (request.reason.isNotEmpty) ...[
                    _buildDetailSection(
                      '신청 사유',
                      Icons.description_outlined,
                      [
                        Container(
                          width: double.infinity,
                          constraints: BoxConstraints(
                            maxHeight: 120,
                          ),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDarkTheme
                                ? const Color(0xFF3A3A3A)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isDarkTheme
                                    ? const Color(0xFF505050)
                                    : Colors.grey.shade200),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              request.reason,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: isDarkTheme
                                    ? Colors.grey[300]
                                    : const Color(0xFF374151),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 반려 사유 (rejectMessage가 있는 경우)
                  if (request.approverComment != null &&
                      request.approverComment!.isNotEmpty) ...[
                    _buildDetailSection(
                      '반려 사유',
                      Icons.comment_outlined,
                      [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC3545)
                                .withValues(alpha: isDarkTheme ? 0.1 : 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFDC3545).withValues(
                                    alpha: isDarkTheme ? 0.3 : 0.2)),
                          ),
                          child: Text(
                            request.approverComment!,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Color(0xFFDC3545),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 하단 버튼 영역 (승인된 건에 대해서만 취소 상신 버튼 표시)
          if (request.status == LeaveRequestStatus.approved)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color:
                    isDarkTheme ? const Color(0xFF3A3A3A) : Colors.grey.shade50,
                border: Border(
                  top: BorderSide(
                      color: isDarkTheme
                          ? const Color(0xFF505050)
                          : Colors.grey.shade200),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () =>
                            _showCancelRequestDialogFromHistory(request),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDarkTheme
                                  ? [
                                      const Color(0xFFEF4444),
                                      const Color(0xFFDC2626),
                                    ]
                                  : [
                                      const Color(0xFFEF4444),
                                      const Color(0xFFDC2626),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: isDarkTheme ? 0.4 : 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cancel_outlined,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '휴가 취소 상신',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isLeaveDetailModalVisible = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkTheme
                            ? const Color(0xFF4B5563)
                            : const Color(0xFF6B7280),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text(
                        '닫기',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(
      String title, IconData icon, List<Widget> children) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon,
                size: 20,
                color:
                    isDarkTheme ? Colors.grey[400] : const Color(0xFF6B7280)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDarkTheme ? Colors.grey[400] : const Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkTheme ? Colors.grey[200] : const Color(0xFF1A1D29),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 전체 휴가 현황 모달 표시
  void _showAllLeaveBalancesModal(List<LeaveStatus> leaveBalances) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '내 휴가 현황',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color:
                          isDarkTheme ? Colors.white : const Color(0xFF1E2B3C),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 휴가 목록
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  child: Column(
                    children: leaveBalances.map((balance) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkTheme
                              ? const Color(0xFF3A3A3A)
                              : const Color(0xFFF3F8FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkTheme
                                ? const Color(0xFF505050)
                                : const Color(0xFF1E88E5)
                                    .withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            // 휴가 종류
                            Expanded(
                              flex: 2,
                              child: Text(
                                balance.leaveType,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkTheme
                                      ? Colors.white
                                      : const Color(0xFF1E2B3C),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // 잔여/전체 일수
                            Expanded(
                              flex: 1,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${balance.remainDays}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E88E5),
                                    ),
                                  ),
                                  Text(
                                    '/${balance.totalDays}일',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDarkTheme
                                          ? Colors.grey[400]
                                          : const Color(0xFF1E2B3C)
                                              .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // 프로그레스바
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${((balance.totalDays > 0 ? balance.remainDays / balance.totalDays : 0) * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1E88E5),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  LinearProgressIndicator(
                                    value: balance.totalDays > 0
                                        ? balance.remainDays / balance.totalDays
                                        : 0,
                                    backgroundColor: const Color(0xFFE3F2FD),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Color(0xFF1E88E5)),
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 닫기 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    '닫기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 페이지네이션: 현재 페이지의 항목들 반환
  List<T> _getPagedItems<T>(List<T> items) {
    final startIndex = _personalLeavePage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, items.length);

    if (startIndex >= items.length) {
      return [];
    }

    return items.sublist(startIndex, endIndex);
  }

  /// 페이지네이션: 총 페이지 수 계산
  int _getTotalPages(int totalItems) {
    return (totalItems / _itemsPerPage).ceil();
  }

  /// 페이지네이션 UI 빌드
  Widget _buildPagination(int totalItems) {
    final totalPages = _getTotalPages(totalItems);

    if (totalPages <= 1) {
      return const SizedBox.shrink(); // 페이지가 1개 이하면 표시 안함
    }

    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
        border: Border(
          top: BorderSide(
            color:
                isDarkTheme ? const Color(0xFF505050) : const Color(0xFFE0E0E0),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 이전 버튼
          IconButton(
            onPressed: _personalLeavePage > 0
                ? () {
                    setState(() {
                      _personalLeavePage--;
                    });
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
            color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
          ),
          const SizedBox(width: 16),

          // 페이지 번호들
          ...List.generate(totalPages, (index) {
            final isCurrentPage = index == _personalLeavePage;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _personalLeavePage = index;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCurrentPage
                        ? const Color(0xFF4A6CF7)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCurrentPage
                          ? const Color(0xFF4A6CF7)
                          : (isDarkTheme
                              ? const Color(0xFF505050)
                              : const Color(0xFFE0E0E0)),
                    ),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isCurrentPage
                          ? Colors.white
                          : (isDarkTheme
                              ? Colors.white
                              : const Color(0xFF1A1D29)),
                      fontWeight:
                          isCurrentPage ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(width: 16),
          // 다음 버튼
          IconButton(
            onPressed: _personalLeavePage < totalPages - 1
                ? () {
                    setState(() {
                      _personalLeavePage++;
                    });
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
            color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
          ),
        ],
      ),
    );
  }

  /// AI 휴가 추천 모달 표시
  Future<void> _showVacationRecommendationModal() async {
    final userId = ref.read(userIdProvider);

    if (userId == null) {
      // 로그인 필요 에러 표시
      if (mounted) {
        CommonUIUtils.showErrorSnackBar(context, '로그인이 필요합니다.');
      }
      return;
    }

    // API 호출 시작 (즉시 호출)
    ref
        .read(vacationRecommendationProvider.notifier)
        .fetchRecommendation(userId, _selectedYear);

    // 모달 표시 (로딩 상태부터 시작)
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => VacationRecommendationPopup(year: _selectedYear),
      );
    }
  }
}
