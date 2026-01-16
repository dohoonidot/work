import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/features/leave/leave_modal_provider.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';

/// 접힌 상태의 휴가 상신 탭 위젯
/// 오른쪽 끝에 세로로 표시되며, 마우스 호버 시 모달을 펼침
class LeaveCollapsedTab extends ConsumerStatefulWidget {
  const LeaveCollapsedTab({super.key});

  @override
  ConsumerState<LeaveCollapsedTab> createState() => _LeaveCollapsedTabState();
}

class _LeaveCollapsedTabState extends ConsumerState<LeaveCollapsedTab>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // 슬라이드 애니메이션 컨트롤러 초기화
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // 오른쪽에서 시작 (숨김)
      end: const Offset(0.0, 0.0), // 중앙으로 이동 (보임)
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));

    // 접힌 상태가 되면 슬라이드 인 애니메이션 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  /// 탭 클릭 또는 호버 시 모달 펼치기
  void _expandModal() {
    ref.read(leaveModalProvider.notifier).expandModal();

    // 모달이 펼쳐질 때 사이드바 다시 열기
    final chatNotifier = ref.read(chatProvider.notifier);
    final chatState = ref.read(chatProvider);
    if (!chatState.isSidebarVisible) {
      chatNotifier.toggleSidebarVisibility();
      print('✅ [LeaveCollapsedTab] 모달 펼침: 사이드바 다시 열림');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return SlideTransition(
      position: _slideAnimation,
      child: MouseRegion(
        onEnter: (_) {
          ref.read(leaveModalProvider.notifier).setHovered(true);
          _expandModal();
        },
        child: GestureDetector(
          onTap: _expandModal,
          child: Container(
            width: 60,
            height: double.infinity,
            decoration: BoxDecoration(
              color: isDarkTheme ? const Color(0xFF1A1D1F) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              border: Border.all(
                color: isDarkTheme
                    ? const Color(0xFF4A6CF7).withValues(alpha: 0.3)
                    : const Color(0xFF4A6CF7).withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(alpha: isDarkTheme ? 0.3 : 0.1),
                  blurRadius: 20,
                  offset: const Offset(-2, 0),
                ),
                BoxShadow(
                  color: const Color(0xFF4A6CF7)
                      .withValues(alpha: isDarkTheme ? 0.2 : 0.1),
                  blurRadius: 8,
                  offset: const Offset(-1, 0),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 휴가 아이콘
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkTheme
                        ? const Color(0xFF4A6CF7).withValues(alpha: 0.2)
                        : const Color(0xFF4A6CF7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.beach_access_outlined,
                    color: isDarkTheme
                        ? const Color(0xFF4A6CF7).withValues(alpha: 0.8)
                        : const Color(0xFF4A6CF7),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),

                // 세로 텍스트
                RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    '휴가 상신',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDarkTheme
                          ? const Color(0xFF4A6CF7).withValues(alpha: 0.8)
                          : const Color(0xFF4A6CF7),
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 초안 표시
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDarkTheme
                        ? const Color(0xFFFF6B6B).withValues(alpha: 0.2)
                        : const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.edit_note,
                    color: isDarkTheme
                        ? const Color(0xFFFF6B6B).withValues(alpha: 0.8)
                        : const Color(0xFFFF6B6B),
                    size: 16,
                  ),
                ),
                const SizedBox(height: 4),
                RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    '초안',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDarkTheme
                          ? const Color(0xFFFF6B6B).withValues(alpha: 0.8)
                          : const Color(0xFFFF6B6B),
                    ),
                  ),
                ),

                const Spacer(),

                // 펼치기 화살표
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.keyboard_arrow_left,
                    color: isDarkTheme
                        ? const Color(0xFFA0AEC0)
                        : const Color(0xFF8B95A1),
                    size: 20,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
