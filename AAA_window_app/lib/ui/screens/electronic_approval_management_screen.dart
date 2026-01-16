import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'approval_detail_modal.dart';
import 'vacation_management_webview_screen.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import '../../features/approval/common_electronic_approval_modal.dart';

// 더미 데이터 모델
class ApprovalDocument {
  final String documentNo;
  final String drafter;
  final String title;
  final DateTime draftDate;
  final DateTime? completionDate;
  final String status;
  final String type;

  ApprovalDocument({
    required this.documentNo,
    required this.drafter,
    required this.title,
    required this.draftDate,
    this.completionDate,
    required this.status,
    required this.type,
  });
}

// 사이드바 상태 관리
final sidebarExpandedProvider = StateProvider<bool>((ref) => false); // 기본적으로 접힘
final sidebarPinnedProvider = StateProvider<bool>((ref) => false); // 핀 고정 상태
final sidebarHoveredProvider = StateProvider<bool>((ref) => false); // 호버 상태
final selectedMenuProvider = StateProvider<String>((ref) => '전체');

// 하위 메뉴 확장 상태 관리
final menuExpandedProvider = StateProvider<Map<String, bool>>((ref) => {
      '전체': false,
      '결재진행': false,
      '참조문서': false,
      '환경설정': false,
      '휴가 부여': false,
    });

// 더미 데이터 Provider
final approvalDocumentsProvider = Provider<List<ApprovalDocument>>((ref) {
  return [
    ApprovalDocument(
      documentNo: 'EA-2025-002',
      drafter: '김도훈',
      title: 'Gemini API 사용을 위한 기안서',
      draftDate: DateTime(2025, 10, 17),
      completionDate: null,
      status: '진행중',
      type: '기본양식',
    ),
    ApprovalDocument(
      documentNo: 'EA-2025-001',
      drafter: '박민수',
      title: 'Claude API 사용 승인 요청',
      draftDate: DateTime(2025, 10, 15),
      completionDate: null,
      status: '검토중',
      type: '기본양식',
    ),
    ApprovalDocument(
      documentNo: 'DTE-2025-001',
      drafter: '최재선',
      title: '풍산홀딩스 Hello eProcurement 구축',
      draftDate: DateTime(2025, 9, 1),
      completionDate: DateTime(2025, 10, 1),
      status: '완료',
      type: '프로젝트승인',
    ),
    ApprovalDocument(
      documentNo: 'EA-2024-002',
      drafter: '이영희',
      title: '신규 직원 채용 승인서',
      draftDate: DateTime(2024, 1, 18),
      completionDate: null,
      status: '진행중',
      type: '인사승인',
    ),
    ApprovalDocument(
      documentNo: 'EA-2024-003',
      drafter: '박민수',
      title: '사무용품 구매 승인 요청',
      draftDate: DateTime(2024, 1, 20),
      completionDate: DateTime(2024, 1, 22),
      status: '완료',
      type: '구매승인',
    ),
    ApprovalDocument(
      documentNo: 'EA-2024-004',
      drafter: '최지연',
      title: '연차 휴가 신청서',
      draftDate: DateTime(2024, 1, 22),
      completionDate: null,
      status: '대기중',
      type: '휴가신청',
    ),
    ApprovalDocument(
      documentNo: 'EA-2024-005',
      drafter: '정우진',
      title: 'IT 장비 구매 승인서',
      draftDate: DateTime(2024, 1, 25),
      completionDate: null,
      status: '진행중',
      type: '구매승인',
    ),
    ApprovalDocument(
      documentNo: 'EA-2024-006',
      drafter: '홍길동',
      title: '출장비 정산 승인 요청',
      draftDate: DateTime(2024, 1, 28),
      completionDate: DateTime(2024, 1, 30),
      status: '완료',
      type: '정산승인',
    ),
    ApprovalDocument(
      documentNo: 'EA-2024-007',
      drafter: '김영수',
      title: '계약서 검토 및 승인 요청',
      draftDate: DateTime(2024, 2, 1),
      completionDate: null,
      status: '검토중',
      type: '계약승인',
    ),
    ApprovalDocument(
      documentNo: 'EA-2024-008',
      drafter: '송미경',
      title: '교육 프로그램 신청 승인서',
      draftDate: DateTime(2024, 2, 3),
      completionDate: null,
      status: '대기중',
      type: '교육승인',
    ),
  ];
});

/// 전자결재관리 메인 화면
class ElectronicApprovalManagementScreen extends ConsumerStatefulWidget {
  const ElectronicApprovalManagementScreen({super.key});

  @override
  ConsumerState<ElectronicApprovalManagementScreen> createState() =>
      _ElectronicApprovalManagementScreenState();
}

class _ElectronicApprovalManagementScreenState
    extends ConsumerState<ElectronicApprovalManagementScreen> {
  Timer? _hoverTimer;
  Timer? _exitTimer;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _exitTimer?.cancel();
    super.dispose();
  }

  /// 휴가부여 권한 체크 (permission 값이 0 또는 1인 경우)
  bool _hasVacationGrantPermission() {
    final permission = ref.read(permissionProvider);
    return permission == 0 || permission == 1;
  }

  /// 휴가 총괄 관리 페이지로 이동
  void _navigateToVacationManagement(BuildContext context) {
    const webUrl = 'http://210.107.96.193:9999/pages/vacation-admin.html';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VacationManagementWebViewScreen(
          webUrl: webUrl,
        ),
      ),
    );
  }

  /// 환경설정 메뉴 클릭 처리
  void _handleSettingsMenuClick(BuildContext context, String subItem) {
    switch (subItem) {
      case '결재선관리':
        _showApprovalLineManagement(context);
        break;
      case '개인설정':
        _showPersonalSettings(context);
        break;
      default:
        print('알 수 없는 환경설정 메뉴: $subItem');
    }
  }

  /// 결재선관리 화면 표시
  void _showApprovalLineManagement(BuildContext context) {
    // TODO: 결재선관리 화면 구현
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('결재선관리'),
          content: const Text('결재선관리 기능이 곧 구현될 예정입니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// 개인설정 화면 표시
  void _showPersonalSettings(BuildContext context) {
    // TODO: 개인설정 화면 구현
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('개인설정'),
          content: const Text('개인설정 기능이 곧 구현될 예정입니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// 새 결재 작성 모달 오픈 (양식 선택 안된 기본 상태)
  void _openNewApprovalModal(BuildContext context) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final modalWidth = screenWidth * 0.8; // 화면의 80%

    final result = await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (BuildContext context) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: modalWidth,
              child: const CommonElectronicApprovalModal(),
            ),
          ),
        );
      },
    );

    // 모달이 닫힌 후 스낵바 표시 (X 버튼으로 닫힌 경우)
    if (result == null || result == false) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('결재 상신이 취소되었습니다.'),
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

  void _handleMouseEnter() {
    try {
      final sidebarPinned = ref.read(sidebarPinnedProvider);
      if (!sidebarPinned && mounted) {
        _exitTimer?.cancel();
        _hoverTimer?.cancel();
        _hoverTimer = Timer(const Duration(milliseconds: 100), () {
          if (mounted) {
            try {
              ref.read(sidebarHoveredProvider.notifier).state = true;
            } catch (e) {
              // 상태 업데이트 실패 시 무시
            }
          }
        });
      }
    } catch (e) {
      // 오류 발생 시 무시
    }
  }

  void _handleMouseExit() {
    try {
      final sidebarPinned = ref.read(sidebarPinnedProvider);
      if (!sidebarPinned && mounted) {
        _hoverTimer?.cancel();
        _exitTimer?.cancel();
        _exitTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) {
            try {
              ref.read(sidebarHoveredProvider.notifier).state = false;
            } catch (e) {
              // 상태 업데이트 실패 시 무시
            }
          }
        });
      }
    } catch (e) {
      // 오류 발생 시 무시
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('전자결재관리'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D1F),
        elevation: 1,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () {
                _openNewApprovalModal(context);
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('새 결재 작성'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A6CF7),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // 동적 사이드바
          _buildSidebarContainer(context, ref),
          // 메인 콘텐츠 영역
          Expanded(
            child: _buildMainContent(context, ref),
          ),
        ],
      ),
    );
  }

  /// 사이드바 컨테이너 (호버 및 핀 로직 포함)
  Widget _buildSidebarContainer(BuildContext context, WidgetRef ref) {
    final sidebarPinned = ref.watch(sidebarPinnedProvider);
    final sidebarHovered = ref.watch(sidebarHoveredProvider);

    // 핀이 고정되어 있거나 호버 중이면 펼침
    final shouldExpand = sidebarPinned || sidebarHovered;

    return MouseRegion(
      onEnter: (_) => _handleMouseEnter(),
      onExit: (_) => _handleMouseExit(),
      child: ClipRect(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: shouldExpand ? 280 : 60,
          height: double.infinity,
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            maxWidth: 280,
            child: Container(
              width: 280,
              child: _buildSidebar(context, ref, shouldExpand),
            ),
          ),
        ),
      ),
    );
  }

  /// 사이드바 구현
  Widget _buildSidebar(BuildContext context, WidgetRef ref, bool isExpanded) {
    final selectedMenu = ref.watch(selectedMenuProvider);
    final menuExpanded = ref.watch(menuExpandedProvider);
    final sidebarPinned = ref.watch(sidebarPinnedProvider);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            right: BorderSide(color: Color(0xFFE9ECEF), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(2, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // 사이드바 헤더
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.dashboard_rounded,
                    color: Color(0xFF6C757D),
                    size: 24,
                  ),
                  if (isExpanded) ...[
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '결재 관리',
                        style: TextStyle(
                          color: Color(0xFF1A1D1F),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  // 핀 버튼 (펼쳐져 있을 때만 표시)
                  if (isExpanded)
                    IconButton(
                      icon: Icon(
                        sidebarPinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        color: sidebarPinned
                            ? const Color(0xFF4A6CF7)
                            : const Color(0xFF6C757D),
                        size: 18,
                      ),
                      onPressed: () {
                        ref.read(sidebarPinnedProvider.notifier).state =
                            !sidebarPinned;
                      },
                      tooltip: sidebarPinned ? '핀 고정 해제' : '핀 고정',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),

            // 메뉴 리스트
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                children: [
                  _buildMenuItem(
                    context,
                    ref,
                    '전체',
                    Icons.view_list_rounded,
                    ['전체문서', '본인기안', '본인결재'],
                    isExpanded,
                    selectedMenu,
                    menuExpanded,
                  ),
                  _buildMenuItem(
                    context,
                    ref,
                    '결재진행',
                    Icons.pending_actions_rounded,
                    ['전체', '결재상신', '결재하기', '결재전단계', '결재완료', '반려/회수'],
                    isExpanded,
                    selectedMenu,
                    menuExpanded,
                  ),
                  _buildMenuItem(
                    context,
                    ref,
                    '참조문서',
                    Icons.description_rounded,
                    ['참조문서', '열람획득문서', '열람부여문서'],
                    isExpanded,
                    selectedMenu,
                    menuExpanded,
                  ),
                  _buildMenuItem(
                    context,
                    ref,
                    '환경설정',
                    Icons.settings_rounded,
                    ['결재선관리', '개인설정'],
                    isExpanded,
                    selectedMenu,
                    menuExpanded,
                  ),
                  // 휴가부여 권한이 있는 경우에만 표시 (permission이 0 또는 1)
                  if (_hasVacationGrantPermission())
                    _buildMenuItem(
                      context,
                      ref,
                      '휴가 부여',
                      Icons.card_giftcard_rounded,
                      ['휴가 총괄 관리'],
                      isExpanded,
                      selectedMenu,
                      menuExpanded,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 메뉴 아이템 빌드
  Widget _buildMenuItem(
    BuildContext context,
    WidgetRef ref,
    String title,
    IconData icon,
    List<String> subItems,
    bool sidebarExpanded,
    String selectedMenu,
    Map<String, bool> menuExpanded,
  ) {
    final isSelected = selectedMenu == title;
    final isExpanded = menuExpanded[title] ?? false;

    // 접힌 상태에서는 아이콘 버튼만 표시
    if (!sidebarExpanded) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: IconButton(
          icon: Icon(
            icon,
            color:
                isSelected ? const Color(0xFF4A6CF7) : const Color(0xFF6C757D),
            size: 24,
          ),
          onPressed: () {
            ref.read(selectedMenuProvider.notifier).state = title;
          },
          tooltip: title,
          style: IconButton.styleFrom(
            backgroundColor: isSelected
                ? const Color(0xFF4A6CF7).withValues(alpha: 0.1)
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    // 펼쳐진 상태에서는 전체 메뉴 표시
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF4A6CF7).withValues(alpha: 0.1)
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF4A6CF7)
                  : const Color(0xFF6C757D),
              size: 20,
            ),
            title: Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF4A6CF7)
                    : const Color(0xFF1A1D1F),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            trailing: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: isSelected
                  ? const Color(0xFF4A6CF7)
                  : const Color(0xFF6C757D),
              size: 20,
            ),
            onTap: () {
              ref.read(selectedMenuProvider.notifier).state = title;

              final currentExpanded = {...menuExpanded};
              currentExpanded[title] = !isExpanded;
              ref.read(menuExpandedProvider.notifier).state = currentExpanded;
            },
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            minLeadingWidth: 0,
          ),
        ),

        // 하위 메뉴 아이템들
        if (isExpanded)
          ...subItems
              .map((subItem) => Container(
                    margin: const EdgeInsets.only(left: 24, right: 8),
                    child: ListTile(
                      leading: const Icon(
                        Icons.circle,
                        color: Color(0xFF8B95A1),
                        size: 8,
                      ),
                      title: Text(
                        subItem,
                        style: const TextStyle(
                          color: Color(0xFF6C757D),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        // 하위 메뉴 아이템 클릭 처리
                        if (title == '휴가 부여' && subItem == '휴가 총괄 관리') {
                          _navigateToVacationManagement(context);
                        } else if (title == '환경설정') {
                          _handleSettingsMenuClick(context, subItem);
                        } else {
                          print('하위 메뉴 클릭: $title > $subItem');
                        }
                      },
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      minLeadingWidth: 20,
                      dense: true,
                    ),
                  ))
              .toList(),
      ],
    );
  }

  /// 메인 콘텐츠 영역
  Widget _buildMainContent(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(approvalDocumentsProvider);

    return Container(
      color: const Color(0xFFF8F9FA),
      padding: const EdgeInsets.all(16),
      child:
          // 결재 내역 테이블
          Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // 검색 영역
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFBFC),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE9ECEF)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: '문서번호, 제목, 기안자로 검색',
                          hintStyle: const TextStyle(
                            color: Color(0xFF8B95A1),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF8B95A1),
                            size: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFFE9ECEF)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFFE9ECEF)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFF4A6CF7)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () {
                        // 검색 기능 구현
                        print('검색 실행');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A6CF7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('검색', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),

            // 테이블 헤더
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FA),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE9ECEF)),
                ),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      '문서번호',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1D1F),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '기안자',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1D1F),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      '제목',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1D1F),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '기안일',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1D1F),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '완료일',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1D1F),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 테이블 바디
            Expanded(
              child: ListView.builder(
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  final doc = documents[index];
                  return _buildTableRow(doc, index, context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 테이블 행 빌드
Widget _buildTableRow(ApprovalDocument doc, int index, BuildContext context) {
  return InkWell(
    onTap: () => _showApprovalDetailModal(doc, context),
    hoverColor: const Color(0xFF4A6CF7).withValues(alpha: 0.05),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFE9ECEF).withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              doc.documentNo,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF4A6CF7),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              doc.drafter,
              style: const TextStyle(
                color: Color(0xFF1A1D1F),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              doc.title,
              style: const TextStyle(
                color: Color(0xFF1A1D1F),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${doc.draftDate.year}.${doc.draftDate.month.toString().padLeft(2, '0')}.${doc.draftDate.day.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: Color(0xFF6C757D),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              doc.completionDate != null
                  ? '${doc.completionDate!.year}.${doc.completionDate!.month.toString().padLeft(2, '0')}.${doc.completionDate!.day.toString().padLeft(2, '0')}'
                  : '-',
              style: TextStyle(
                color: doc.completionDate != null
                    ? const Color(0xFF28A745)
                    : const Color(0xFF6C757D),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 결재 내역 상세 모달 표시
void _showApprovalDetailModal(ApprovalDocument doc, BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return ApprovalDetailModal(document: doc);
    },
  );
}
