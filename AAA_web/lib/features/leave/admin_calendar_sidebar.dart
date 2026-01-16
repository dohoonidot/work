import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/services/leave_api_service.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:ASPN_AI_AGENT/features/leave/leave_models.dart';

class AdminCalendarSidebar extends ConsumerStatefulWidget {
  final bool isExpanded;
  final VoidCallback onHover;
  final VoidCallback onExit;
  final bool isPinned;
  final VoidCallback onPinToggle;

  const AdminCalendarSidebar({
    super.key,
    required this.isExpanded,
    required this.onHover,
    required this.onExit,
    required this.isPinned,
    required this.onPinToggle,
  });

  @override
  ConsumerState<AdminCalendarSidebar> createState() =>
      _AdminCalendarSidebarState();
}

class _AdminCalendarSidebarState extends ConsumerState<AdminCalendarSidebar>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _widthAnimation = Tween<double>(
      begin: 50,
      end: 285,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AdminCalendarSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: widget.isPinned ? null : (_) => widget.onHover(),
      onExit: widget.isPinned ? null : (_) => widget.onExit(),
      child: AnimatedBuilder(
        animation: _widthAnimation,
        builder: (context, child) {
          return Container(
            width: _widthAnimation.value,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: isDarkTheme
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2D2D2D),
                        Color(0xFF1A1A1A),
                      ],
                    )
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF8F9FA),
                        Color(0xFFFFFFFF),
                      ],
                    ),
              border: Border.all(
                color: isDarkTheme
                    ? const Color(0xFF404040)
                    : const Color(0xFFE9ECEF),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(alpha: isDarkTheme ? 0.3 : 0.1),
                  blurRadius: 20,
                  offset: const Offset(4, 0),
                ),
              ],
            ),
            child: widget.isExpanded
                ? _buildExpandedContent()
                : _buildCollapsedContent(),
          );
        },
      ),
    );
  }

  Widget _buildCollapsedContent() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF9C88D4).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.admin_panel_settings,
            color: Color(0xFF9C88D4),
            size: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedContent() {
    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        // 사이드바가 충분히 확장되었을 때만 전체 헤더 표시
        final isFullyExpanded = _widthAnimation.value > 200;
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더 with pin button
              if (isFullyExpanded)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C88D4).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings,
                        color: Color(0xFF9C88D4),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '관리자 메뉴',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDarkTheme
                              ? Colors.white
                              : const Color(0xFF495057),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Pin button
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: IconButton(
                        onPressed: widget.onPinToggle,
                        icon: Icon(
                          widget.isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          size: 14,
                          color: widget.isPinned
                              ? const Color(0xFF9C88D4)
                              : (isDarkTheme
                                  ? Colors.grey[400]
                                  : Colors.grey[600]),
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: widget.isPinned ? '사이드바 고정 해제' : '사이드바 고정',
                      ),
                    ),
                  ],
                )
              else
                // 애니메이션 중에는 아이콘만 표시
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C88D4).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Color(0xFF9C88D4),
                      size: 16,
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // 부서원 휴가 현황 버튼 (충분히 확장되었을 때만 표시)
              if (isFullyExpanded) _buildLeaveStatusButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaveStatusButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showLeaveStatusModal(),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9C88D4),
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(
          Icons.people_alt_outlined,
          size: 18,
        ),
        label: const Text(
          '부서원 휴가 현황',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }

  void _showLeaveStatusModal() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(40),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.8,
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
            child: LeaveStatusModal(),
          ),
        );
      },
    );
  }
}

// 부서원 휴가 현황 모달
class LeaveStatusModal extends ConsumerStatefulWidget {
  const LeaveStatusModal({super.key});

  @override
  ConsumerState<LeaveStatusModal> createState() => _LeaveStatusModalState();
}

class _LeaveStatusModalState extends ConsumerState<LeaveStatusModal> {
  bool _isLoading = true;
  List<EmployeeLeaveStatus> _employees = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLeaveStatusData();
  }

  Future<void> _loadLeaveStatusData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = ref.read(userIdProvider);
      if (userId == null || userId.isEmpty) {
        setState(() {
          _error = '사용자 정보를 찾을 수 없습니다.';
          _isLoading = false;
        });
        return;
      }

      final response = await LeaveApiService.getDepartmentLeaveStatus(
        approverId: userId,
      );

      if (response.error != null) {
        setState(() {
          _error = response.error;
          _isLoading = false;
        });
      } else {
        setState(() {
          _employees = response.employees;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '데이터 로딩 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDarkTheme ? const Color(0xFF2D2D2D) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            border: Border(
              bottom: BorderSide(
                  color: isDarkTheme
                      ? const Color(0xFF404040)
                      : const Color(0xFFE5E7EB),
                  width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDarkTheme
                      ? const Color(0xFF3A3A3A)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.people_alt_outlined,
                  color:
                      isDarkTheme ? Colors.grey[400] : const Color(0xFF6B7280),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '부서원 휴가 현황',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDarkTheme ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: isDarkTheme
                      ? const Color(0xFF3A3A3A)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: isDarkTheme
                        ? Colors.grey[400]
                        : const Color(0xFF9CA3AF),
                    size: 20,
                  ),
                  splashRadius: 20,
                ),
              ),
            ],
          ),
        ),
        // 메인 콘텐츠
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            color:
                isDarkTheme ? const Color(0xFF2D2D2D) : const Color(0xFFFAFAFA),
            child: Column(
              children: [
                // 테이블 헤더
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  decoration: BoxDecoration(
                    color: isDarkTheme
                        ? const Color(0xFF3A3A3A)
                        : const Color(0xFFF8F9FA),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    border: Border.all(
                        color: isDarkTheme
                            ? const Color(0xFF505050)
                            : const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          '부서',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkTheme
                                ? Colors.grey[300]
                                : const Color(0xFF374151),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '이름',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkTheme
                                ? Colors.grey[300]
                                : const Color(0xFF374151),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '입사일',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkTheme
                                ? Colors.grey[300]
                                : const Color(0xFF374151),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '휴가종류',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkTheme
                                ? Colors.grey[300]
                                : const Color(0xFF374151),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '총일수',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkTheme
                                ? Colors.grey[300]
                                : const Color(0xFF374151),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '사용일수',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkTheme
                                ? Colors.grey[300]
                                : const Color(0xFF374151),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '잔여일수',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkTheme
                                ? Colors.grey[300]
                                : const Color(0xFF374151),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                // 테이블 내용
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          isDarkTheme ? const Color(0xFF1A1A1A) : Colors.white,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      border: Border.all(
                          color: isDarkTheme
                              ? const Color(0xFF505050)
                              : const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDarkTheme ? 0.2 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _buildContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: isDarkTheme ? Colors.grey[400] : const Color(0xFF6B7280),
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 20),
            Text(
              '부서원 휴가 현황을 불러오는 중...',
              style: TextStyle(
                fontSize: 15,
                color: isDarkTheme ? Colors.grey[400] : const Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkTheme
                      ? const Color(0xFF3A2020)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Color(0xFFEF4444),
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 15,
                  color:
                      isDarkTheme ? Colors.grey[400] : const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadLeaveStatusData,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('다시 시도'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkTheme
                      ? const Color(0xFF4A4A4A)
                      : const Color(0xFF6B7280),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_employees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkTheme
                    ? const Color(0xFF3A3A3A)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.people_outline,
                color: isDarkTheme ? Colors.grey[500] : const Color(0xFF9CA3AF),
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '부서원 휴가 현황 데이터가 없습니다.',
              style: TextStyle(
                fontSize: 15,
                color: isDarkTheme ? Colors.grey[400] : const Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return _buildEmployeeTable();
  }

  // 직원 데이터를 그룹화하여 테이블로 렌더링
  Widget _buildEmployeeTable() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // 같은 이름/부서를 가진 직원들을 그룹화
    final Map<String, List<EmployeeLeaveStatus>> groupedEmployees = {};
    for (var employee in _employees) {
      final key = '${employee.department}_${employee.name}';
      if (!groupedEmployees.containsKey(key)) {
        groupedEmployees[key] = [];
      }
      groupedEmployees[key]!.add(employee);
    }

    // 그룹화된 데이터를 순회하며 그룹별 위젯 생성
    final List<Widget> groupWidgets = [];
    int globalIndex = 0;

    groupedEmployees.forEach((key, employees) {
      groupWidgets.add(_buildEmployeeGroup(
        employees,
        globalIndex,
        isDarkTheme,
      ));
      globalIndex += employees.length;
    });

    return ListView(
      children: groupWidgets,
    );
  }

  // 같은 부서/이름을 가진 직원 그룹을 렌더링 (병합된 셀 + 중앙 정렬)
  Widget _buildEmployeeGroup(
    List<EmployeeLeaveStatus> employees,
    int startIndex,
    bool isDarkTheme,
  ) {
    final isEven = startIndex % 2 == 0;

    return Container(
      decoration: BoxDecoration(
        color: isDarkTheme
            ? (isEven ? const Color(0xFF1A1A1A) : const Color(0xFF2D2D2D))
            : (isEven ? Colors.white : const Color(0xFFFAFAFA)),
        border: Border(
          bottom: BorderSide(
            color:
                isDarkTheme ? const Color(0xFF404040) : const Color(0xFFF1F3F5),
            width: 0.8,
          ),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 부서 (병합, 세로 중앙 정렬)
            Expanded(
              flex: 2,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  employees[0].department,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDarkTheme
                        ? Colors.grey[400]
                        : const Color(0xFF4B5563),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // 이름 (병합, 세로 중앙 정렬)
            Expanded(
              flex: 2,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  employees[0].name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDarkTheme ? Colors.white : const Color(0xFF111827),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // 나머지 컬럼들 (각 leave_type별 행)
            Expanded(
              flex: 10, // 2+2+2+2+2 = 10
              child: Column(
                children: employees.asMap().entries.map((entry) {
                  final employee = entry.value;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          // 입사일
                          Expanded(
                            flex: 2,
                            child: Text(
                              employee.joinDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkTheme
                                    ? Colors.grey[500]
                                    : const Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // 휴가종류
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDarkTheme
                                    ? const Color(0xFF3A3A5A)
                                    : const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                employee.leaveType,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkTheme
                                      ? Colors.blue[200]
                                      : const Color(0xFF4F46E5),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          // 총일수
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDarkTheme
                                    ? const Color(0xFF3A3A3A)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${employee.totalDays.toStringAsFixed(1)}일',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkTheme
                                      ? Colors.white
                                      : const Color(0xFF374151),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          // 사용일수
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDarkTheme
                                    ? const Color(0xFF2A3A2A)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${employee.usedDays.toStringAsFixed(1)}일',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkTheme
                                      ? Colors.grey[300]
                                      : const Color(0xFF475569),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          // 잔여일수
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDarkTheme
                                    ? const Color(0xFF3A2A3A)
                                    : const Color(0xFFE5E7EB),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${employee.remainDays.toStringAsFixed(1)}일',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkTheme
                                      ? Colors.white
                                      : const Color(0xFF1F2937),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
