import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/services/leave_api_service.dart';
import 'package:ASPN_AI_AGENT/models/leave_management_models.dart';

// 관리자 관리 데이터 상태 클래스
class AdminManagementState {
  final bool isLoading;
  final AdminManagementResponse? data;
  final String? error;
  final DateTime lastUpdated;

  AdminManagementState({
    required this.isLoading,
    this.data,
    this.error,
    required this.lastUpdated,
  });

  AdminManagementState copyWith({
    bool? isLoading,
    AdminManagementResponse? data,
    String? error,
    DateTime? lastUpdated,
  }) {
    return AdminManagementState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error ?? this.error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

// 관리자 관리 데이터 Notifier
class AdminManagementNotifier extends StateNotifier<AdminManagementState> {
  final Ref ref;

  AdminManagementNotifier(this.ref)
      : super(AdminManagementState(
          isLoading: false,
          lastUpdated: DateTime.now(),
        ));

  /// 관리자 관리 데이터 로드
  Future<void> loadAdminManagementData({
    required String approverId,
    required String month,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final request = AdminManagementRequest(
        approverId: approverId,
        month: month,
      );

      print('🔍 [AdminManagement] API 요청 시작');
      print('🔍 [AdminManagement] approverId: $approverId');
      print('🔍 [AdminManagement] month: $month');
      print('🔍 [AdminManagement] 요청 데이터: ${request.toJson()}');

      final response = await LeaveApiService.getAdminManagementData(
        request: request,
      );

      print('🔍 [AdminManagement] API 응답 받음');
      print('🔍 [AdminManagement] 응답 데이터: $response');
      print('🔍 [AdminManagement] isSuccess: ${response.isSuccess}');
      print('🔍 [AdminManagement] error: ${response.error}');
      print('🔍 [AdminManagement] approvalStatus: ${response.approvalStatus}');
      print(
          '🔍 [AdminManagement] monthlyLeaves 개수: ${response.monthlyLeaves.length}');
      print(
          '🔍 [AdminManagement] waitingLeaves 개수: ${response.waitingLeaves.length}');

      if (response.isSuccess) {
        print('🔍 [AdminManagement] 성공적으로 데이터 로드됨');
        state = state.copyWith(
          isLoading: false,
          data: response,
          error: null,
          lastUpdated: DateTime.now(),
        );
      } else {
        print('🔍 [AdminManagement] 데이터 로드 실패: ${response.error}');
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? '데이터를 불러오는데 실패했습니다.',
        );
      }
    } catch (e) {
      print('🔍 [AdminManagement] API 호출 중 오류 발생: $e');
      state = state.copyWith(
        isLoading: false,
        error: '네트워크 오류가 발생했습니다: $e',
      );
    }
  }

  /// 관리 데이터 업데이트 (연도별 조회 등에서 사용)
  void updateManagementData(AdminManagementResponse response) {
    if (response.isSuccess) {
      state = state.copyWith(
        isLoading: false,
        data: response,
        error: null,
        lastUpdated: DateTime.now(),
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: response.error ?? '데이터를 불러오는데 실패했습니다.',
      );
    }
  }

  /// 상태 초기화
  void reset() {
    state = AdminManagementState(
      isLoading: false,
      lastUpdated: DateTime.now(),
    );
  }

  /// 승인/반려 처리
  Future<bool> processApproval({
    required int id,
    required String approverId,
    required bool isApproved,
    String? rejectMessage,
    int isCancel = 0, // 0: 일반 상신, 1: 취소 상신
    bool isCancelApproved = false, // true: CANCEL_APPROVED 전송
  }) async {
    try {
      print('🔍 [AdminManagement] ========== 승인/반려 처리 시작 ==========');
      print('🔍 [AdminManagement] 파라미터 - id: $id');
      print('🔍 [AdminManagement] 파라미터 - approverId: $approverId');
      print('🔍 [AdminManagement] 파라미터 - isApproved (bool): $isApproved');
      print('🔍 [AdminManagement] 파라미터 - isCancel: $isCancel');
      print('🔍 [AdminManagement] 파라미터 - isCancelApproved: $isCancelApproved');
      print('🔍 [AdminManagement] 파라미터 - rejectMessage: $rejectMessage');

      final isApprovedString = isCancelApproved
          ? 'CANCEL_APPROVED'
          : (isApproved ? 'APPROVED' : 'REJECTED');

      print('🔍 [AdminManagement] 최종 is_approved 문자열: $isApprovedString');

      final request = AdminApprovalRequest(
        id: id,
        approverId: approverId,
        isApproved: isApprovedString,
        rejectMessage: rejectMessage,
      );

      print('🔍 [AdminManagement] Request JSON: ${request.toJson()}');

      // is_cancel 값에 따라 다른 API 호출
      final response = isCancel == 1
          ? await LeaveApiService.processCancelApproval(
              request: request,
            )
          : await LeaveApiService.processAdminApproval(
              request: request,
            );

      print(
          '🔍 [AdminManagement] API 선택: ${isCancel == 1 ? "/leave/admin/approval/cancel" : "/leave/admin/approval"}');
      print('🔍 [AdminManagement] Response isSuccess: ${response.isSuccess}');
      print('🔍 [AdminManagement] Response error: ${response.error}');

      if (response.isSuccess) {
        // 성공 시 약간의 딜레이 후 데이터를 새로고침하여 DB 반영을 기다림
        await Future.delayed(const Duration(milliseconds: 500));

        await loadAdminManagementData(
          approverId: approverId,
          month: DateTime.now().toString().substring(0, 7), // YYYY-MM 형식
        );

        // 추가로 한번 더 확인 (캐싱 문제 대응)
        await Future.delayed(const Duration(milliseconds: 200));
        await loadAdminManagementData(
          approverId: approverId,
          month: DateTime.now().toString().substring(0, 7), // YYYY-MM 형식
        );

        // 휴가관리 페이지의 대기 건수도 업데이트 (배지용)
        await updateWaitingCount(approverId);

        print('🔍 [AdminManagement] 승인 처리 완료 - 최종 상태 확인');
        print(
            '🔍 [AdminManagement] 현재 waitingLeaves 개수: ${state.data?.waitingLeaves.length ?? 0}');

        return true;
      } else {
        state = state.copyWith(
          error: response.error ?? '승인/반려 처리에 실패했습니다.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        error: '네트워크 오류가 발생했습니다: $e',
      );
      return false;
    }
  }

  /// 대기 건수 업데이트 (휴가관리 페이지 배지용)
  Future<void> updateWaitingCount(String approverId) async {
    try {
      print('📊 [AdminManagement] 대기 건수 업데이트 시작');
      final waitingLeaves = await LeaveApiService.getAdminWaitingLeaves(
        approverId: approverId,
      );

      final count = waitingLeaves.length;
      print('📊 [AdminManagement] 업데이트된 대기 건수: $count');

      // adminWaitingCountProvider 업데이트
      ref.read(adminWaitingCountProvider.notifier).state = count;
    } catch (e) {
      print('📊 [AdminManagement] 대기 건수 업데이트 실패: $e');
    }
  }
}

// 관리자 관리 데이터 Provider
final adminManagementProvider =
    StateNotifierProvider<AdminManagementNotifier, AdminManagementState>(
  (ref) => AdminManagementNotifier(ref),
);

// 개별 데이터 접근을 위한 Provider들
final adminApprovalStatusProvider = Provider<AdminApprovalStatus?>((ref) {
  final state = ref.watch(adminManagementProvider);
  return state.data?.approvalStatus;
});

final adminWaitingLeavesProvider = Provider<List<AdminWaitingLeave>>((ref) {
  final state = ref.watch(adminManagementProvider);
  return state.data?.waitingLeaves ?? [];
});

final adminMonthlyLeavesProvider = Provider<List<AdminMonthlyLeave>>((ref) {
  final state = ref.watch(adminManagementProvider);
  return state.data?.monthlyLeaves ?? [];
});

// ===============================
// 관리자 부서별 달력 데이터 관리
// ===============================

// 부서별 달력 상태 클래스
class AdminDeptCalendarState {
  final bool isLoading;
  final AdminDeptCalendarResponse? data;
  final String? error;
  final DateTime lastUpdated;

  AdminDeptCalendarState({
    required this.isLoading,
    this.data,
    this.error,
    required this.lastUpdated,
  });

  AdminDeptCalendarState copyWith({
    bool? isLoading,
    AdminDeptCalendarResponse? data,
    String? error,
    DateTime? lastUpdated,
  }) {
    return AdminDeptCalendarState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error ?? this.error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

// 부서별 달력 Notifier
class AdminDeptCalendarNotifier extends StateNotifier<AdminDeptCalendarState> {
  AdminDeptCalendarNotifier()
      : super(AdminDeptCalendarState(
          isLoading: false,
          lastUpdated: DateTime.now(),
        ));

  /// 부서별 달력 데이터 로드
  Future<void> loadDeptCalendarData({
    required String approverId,
    required String month,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final request = AdminDeptCalendarRequest(
        approverId: approverId,
        month: month,
      );

      print('🗓️ [AdminDeptCalendar] API 요청 시작');
      print('🗓️ [AdminDeptCalendar] approverId: $approverId');
      print('🗓️ [AdminDeptCalendar] month: $month');

      final response = await LeaveApiService.getAdminDeptCalendar(
        request: request,
      );

      print('🗓️ [AdminDeptCalendar] API 응답 받음');
      print('🗓️ [AdminDeptCalendar] isSuccess: ${response.isSuccess}');
      print(
          '🗓️ [AdminDeptCalendar] monthlyLeaves 개수: ${response.monthlyLeaves.length}');

      if (response.isSuccess) {
        state = state.copyWith(
          isLoading: false,
          data: response,
          error: null,
          lastUpdated: DateTime.now(),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? '부서별 달력 데이터를 불러오는데 실패했습니다.',
        );
      }
    } catch (e) {
      print('🗓️ [AdminDeptCalendar] API 호출 중 오류 발생: $e');
      state = state.copyWith(
        isLoading: false,
        error: '네트워크 오류가 발생했습니다: $e',
      );
    }
  }

  /// 상태 초기화
  void reset() {
    state = AdminDeptCalendarState(
      isLoading: false,
      lastUpdated: DateTime.now(),
    );
  }
}

// 부서별 달력 Provider
final adminDeptCalendarProvider =
    StateNotifierProvider<AdminDeptCalendarNotifier, AdminDeptCalendarState>(
  (ref) => AdminDeptCalendarNotifier(),
);

// 부서별 달력 월별 휴가 목록 Provider
final adminDeptMonthlyLeavesProvider = Provider<List<AdminMonthlyLeave>>((ref) {
  final state = ref.watch(adminDeptCalendarProvider);
  return state.data?.monthlyLeaves ?? [];
});

// ===============================
// 관리자 대기 건수 관리 (휴가관리 페이지 배지용)
// ===============================

/// 관리자 대기 건수 Provider
final adminWaitingCountProvider = StateProvider<int>((ref) => 0);
