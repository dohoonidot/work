import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 휴가 상신 모달의 표시 상태
enum LeaveModalDisplayState {
  hidden, // 완전히 숨김
  collapsed, // 접힌 상태 (오른쪽 끝에 탭만 보임)
  expanded, // 펼쳐진 상태 (전체 모달 보임)
}

/// 휴가 상신 모달의 상태를 관리하는 Provider
/// 모달의 표시/숨김, 접힌/펼쳐진 상태, 호버 상태, 애니메이션 제어를 담당
class LeaveModalState {
  final LeaveModalDisplayState displayState;
  final bool isHovered;
  final bool isAnimating;
  final bool hasDraft; // 작성 중인 초안이 있는지 여부
  final bool isPinned; // 핀으로 고정되었는지 여부
  final bool allowAutoClose; // 자동 닫힘 허용 여부
  final bool isLoadingVacationData; // 휴가 데이터 로딩 중인지 여부
  final double? customWidth; // 커스텀 폭 (로딩 중 40%, 완료 후 60%)

  const LeaveModalState({
    this.displayState = LeaveModalDisplayState.hidden,
    this.isHovered = false,
    this.isAnimating = false,
    this.hasDraft = false,
    this.isPinned = false,
    this.allowAutoClose = false, // 기본적으로 자동 닫힘 비허용
    this.isLoadingVacationData = false,
    this.customWidth,
  });

  LeaveModalState copyWith({
    LeaveModalDisplayState? displayState,
    bool? isHovered,
    bool? isAnimating,
    bool? hasDraft,
    bool? isPinned,
    bool? allowAutoClose,
    bool? isLoadingVacationData,
    double? customWidth,
  }) {
    return LeaveModalState(
      displayState: displayState ?? this.displayState,
      isHovered: isHovered ?? this.isHovered,
      isAnimating: isAnimating ?? this.isAnimating,
      hasDraft: hasDraft ?? this.hasDraft,
      isPinned: isPinned ?? this.isPinned,
      allowAutoClose: allowAutoClose ?? this.allowAutoClose,
      isLoadingVacationData:
          isLoadingVacationData ?? this.isLoadingVacationData,
      customWidth: customWidth ?? this.customWidth,
    );
  }

  // 편의 속성들
  bool get isVisible => displayState != LeaveModalDisplayState.hidden;
  bool get isCollapsed => displayState == LeaveModalDisplayState.collapsed;
  bool get isExpanded => displayState == LeaveModalDisplayState.expanded;
}

class LeaveModalNotifier extends StateNotifier<LeaveModalState> {
  LeaveModalNotifier() : super(const LeaveModalState());

  /// 모달을 펼쳐서 표시
  void showModal() {
    state = state.copyWith(
      displayState: LeaveModalDisplayState.expanded,
      isAnimating: true,
      hasDraft: true, // 모달을 표시할 때 초안이 있다고 간주
    );
  }

  /// 모달을 완전히 숨김 (자동 닫힘 차단됨)
  void hideModal() {
    print('[DEBUG] hideModal 호출됨 - allowAutoClose: ${state.allowAutoClose}');
    if (!state.allowAutoClose) {
      print('[DEBUG] hideModal 차단됨 - 자동 닫힘 비허용');
      return;
    }
    state = state.copyWith(
      displayState: LeaveModalDisplayState.hidden,
      isAnimating: true,
      hasDraft: false,
    );
  }

  /// 모달을 접힌 상태로 변경 (자동 닫힘 차단됨)
  void collapseModal() {
    print(
        '[DEBUG] collapseModal 호출됨 - allowAutoClose: ${state.allowAutoClose}');
    if (!state.allowAutoClose) {
      print('[DEBUG] collapseModal 차단됨 - 자동 닫힘 비허용');
      return;
    }
    if (state.hasDraft) {
      state = state.copyWith(
        displayState: LeaveModalDisplayState.collapsed,
        isAnimating: true,
      );
    } else {
      hideModal();
    }
  }

  /// 접힌 모달을 펼침
  void expandModal() {
    if (state.isCollapsed) {
      state = state.copyWith(
        displayState: LeaveModalDisplayState.expanded,
        isAnimating: true,
      );
    }
  }

  /// 호버 상태 설정
  void setHovered(bool hovered) {
    state = state.copyWith(isHovered: hovered);
  }

  /// 애니메이션 완료 처리
  void onAnimationComplete() {
    state = state.copyWith(isAnimating: false);
  }

  /// 초안 존재 여부 설정
  void setHasDraft(bool hasDraft) {
    state = state.copyWith(hasDraft: hasDraft);
  }

  /// 핀 상태 토글
  void togglePin() {
    state = state.copyWith(isPinned: !state.isPinned);
  }

  /// 핀 상태 설정
  void setPinned(bool pinned) {
    state = state.copyWith(isPinned: pinned);
  }

  /// 명시적으로 모달 닫기 (닫기 버튼에서만 호출)
  void forceHideModal() {
    print('[DEBUG] forceHideModal 호출됨 - 강제 닫기');
    state = state.copyWith(
      displayState: LeaveModalDisplayState.hidden,
      isAnimating: true,
      hasDraft: false,
    );
  }

  /// 명시적으로 모달 접기 (접어두기 화살표 버튼에서만 호출)
  void forceCollapseModal() {
    print('[DEBUG] forceCollapseModal 호출됨 - 강제 접기');
    if (state.hasDraft) {
      state = state.copyWith(
        displayState: LeaveModalDisplayState.collapsed,
        isAnimating: true,
      );
    } else {
      forceHideModal();
    }
  }

  /// 자동 접기 기능 완전 비활성화
  void scheduleAutoCollapse() {
    // 완전히 비활성화 - 자동으로 닫히지 않음
    print('[DEBUG] scheduleAutoCollapse 호출됨 - 무시됨');
  }

  /// 마우스 나감 이벤트도 완전 비활성화
  void onMouseExit() {
    // 완전히 비활성화 - 마우스가 나가도 닫히지 않음
    print('[DEBUG] onMouseExit 호출됨 - 무시됨');
  }

  /// 폼 제출 완료 후 모달 닫기
  void onFormSubmitted() {
    state = state.copyWith(
      displayState: LeaveModalDisplayState.hidden,
      hasDraft: false,
      isAnimating: true,
    );
  }

  /// 휴가 데이터 로딩 시작
  void setLoadingVacationData(bool loading) {
    state = state.copyWith(isLoadingVacationData: loading);
  }
}

/// 휴가 상신 모달 상태 Provider
final leaveModalProvider =
    StateNotifierProvider<LeaveModalNotifier, LeaveModalState>((ref) {
  return LeaveModalNotifier();
});
