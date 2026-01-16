import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'leave_models.dart';
import 'package:ASPN_AI_AGENT/shared/services/leave_api_service.dart';
import 'package:ASPN_AI_AGENT/models/leave_management_models.dart';

// 휴가신청 내역 관리 Provider
class LeaveRequestHistoryNotifier
    extends StateNotifier<AsyncValue<List<LeaveRequestHistory>>> {
  LeaveRequestHistoryNotifier() : super(const AsyncValue.loading()) {
    // 초기 로딩은 외부에서 loadData 호출로 처리
  }

  // API에서 데이터 로드
  Future<void> loadData(String userId, int year,
      {LeaveRequestStatus? status}) async {
    state = const AsyncValue.loading();

    try {
      final requests = await LeaveApiService.getLeaveRequestHistory(
        userId: userId,
        year: year,
        status: status,
      );
      state = AsyncValue.data(requests);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  // 휴가 신청 추가
  Future<void> addLeaveRequest({
    required String userId,
    required String vacationType,
    required DateTime startDate,
    required DateTime endDate,
    required double days,
    required String reason,
  }) async {
    try {
      await LeaveApiService.submitLeaveRequest(
        userId: userId,
        vacationType: vacationType,
        startDate: startDate,
        endDate: endDate,
        days: days,
        reason: reason,
      );
      // 신청 후 데이터 새로고침
      await loadData(userId, DateTime.now().year);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  // 휴가 신청 취소
  Future<void> cancelLeaveRequest({
    required String requestId,
    required String userId,
  }) async {
    try {
      await LeaveApiService.cancelLeaveRequest(
        requestId: requestId,
        userId: userId,
      );
      // 취소 후 데이터 새로고침
      await loadData(userId, DateTime.now().year);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  // 상태 초기화 (로그아웃 시 사용)
  void resetState() {
    state = const AsyncValue.loading();
  }
}

final leaveRequestHistoryProvider = StateNotifierProvider<
    LeaveRequestHistoryNotifier, AsyncValue<List<LeaveRequestHistory>>>((ref) {
  return LeaveRequestHistoryNotifier();
});

// 휴가 잔여량 관리 Provider
class LeaveBalanceNotifier
    extends StateNotifier<AsyncValue<List<LeaveBalance>>> {
  LeaveBalanceNotifier() : super(const AsyncValue.loading());

  // API에서 데이터 로드
  Future<void> loadData(String userId) async {
    state = const AsyncValue.loading();

    try {
      final balances = await LeaveApiService.getLeaveBalance(userId: userId);
      state = AsyncValue.data(balances);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  // 상태 초기화 (로그아웃 시 사용)
  void resetState() {
    state = const AsyncValue.loading();
  }
}

final leaveBalanceProvider =
    StateNotifierProvider<LeaveBalanceNotifier, AsyncValue<List<LeaveBalance>>>(
        (ref) {
  return LeaveBalanceNotifier();
});

// 부서원 목록 관리 Provider
class DepartmentMembersNotifier
    extends StateNotifier<AsyncValue<List<DepartmentMember>>> {
  DepartmentMembersNotifier() : super(const AsyncValue.loading());

  // API에서 데이터 로드
  Future<void> loadData(String userId) async {
    state = const AsyncValue.loading();

    try {
      final members =
          await LeaveApiService.getDepartmentMembers(userId: userId);
      state = AsyncValue.data(members);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  // 상태 초기화 (로그아웃 시 사용)
  void resetState() {
    state = const AsyncValue.loading();
  }
}

final departmentMembersProvider = StateNotifierProvider<
    DepartmentMembersNotifier, AsyncValue<List<DepartmentMember>>>((ref) {
  return DepartmentMembersNotifier();
});

// 부서 전체 휴가 내역 관리 Provider
class DepartmentLeaveHistoryNotifier
    extends StateNotifier<AsyncValue<Map<String, List<LeaveRequestHistory>>>> {
  DepartmentLeaveHistoryNotifier() : super(const AsyncValue.loading());

  // API에서 데이터 로드
  Future<void> loadData(String userId, int year, {String? memberId}) async {
    state = const AsyncValue.loading();

    try {
      final history = await LeaveApiService.getDepartmentLeaveHistory(
        userId: userId,
        year: year,
        memberId: memberId,
      );
      state = AsyncValue.data(history);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  // 상태 초기화 (로그아웃 시 사용)
  void resetState() {
    state = const AsyncValue.loading();
  }
}

final departmentLeaveHistoryProvider = StateNotifierProvider<
    DepartmentLeaveHistoryNotifier,
    AsyncValue<Map<String, List<LeaveRequestHistory>>>>((ref) {
  return DepartmentLeaveHistoryNotifier();
});

// 휴가 관리 대장 데이터 Provider
class LeaveManagementTableNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  LeaveManagementTableNotifier() : super(const AsyncValue.loading());

  // API에서 데이터 로드
  Future<void> loadData(String userId, int year) async {
    state = const AsyncValue.loading();

    try {
      final tableData = await LeaveApiService.getLeaveManagementTable(
        userId: userId,
        year: year,
      );
      state = AsyncValue.data(tableData);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  // 상태 초기화 (로그아웃 시 사용)
  void resetState() {
    state = const AsyncValue.loading();
  }
}

final leaveManagementTableProvider = StateNotifierProvider<
    LeaveManagementTableNotifier,
    AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return LeaveManagementTableNotifier();
});

// 관리자용 승인 대기 목록 Provider
class PendingApprovalsNotifier
    extends StateNotifier<AsyncValue<List<LeaveRequestHistory>>> {
  PendingApprovalsNotifier() : super(const AsyncValue.loading());

  // API에서 데이터 로드
  Future<void> loadData(String managerId) async {
    state = const AsyncValue.loading();

    try {
      final approvals = await LeaveApiService.getPendingApprovals(
        managerId: managerId,
      );
      state = AsyncValue.data(approvals);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  // 휴가 승인/반려
  Future<void> approveLeaveRequest({
    required String requestId,
    required String managerId,
    required bool isApproved,
    String? comment,
  }) async {
    try {
      final request = AdminApprovalRequest(
        id: int.parse(requestId),
        approverId: managerId,
        isApproved: isApproved ? 'APPROVED' : 'REJECTED',
        rejectMessage: isApproved ? null : comment,
      );

      await LeaveApiService.processAdminApproval(request: request);
      // 승인/반려 후 데이터 새로고침
      await loadData(managerId);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  // 상태 초기화 (로그아웃 시 사용)
  void resetState() {
    state = const AsyncValue.loading();
  }
}

final pendingApprovalsProvider = StateNotifierProvider<PendingApprovalsNotifier,
    AsyncValue<List<LeaveRequestHistory>>>((ref) {
  return PendingApprovalsNotifier();
});

// 사이드바 상태 관리 Provider
final leaveSidebarStateProvider = StateProvider<bool>((ref) => false);

// 현재 사용자 ID Provider (로그인 정보에서 가져오는 것으로 대체 예정)
final currentUserIdProvider = StateProvider<String>((ref) => 'user_001');

// 선택된 연도 Provider
final selectedYearProvider = StateProvider<int>((ref) => DateTime.now().year);

// 데이터 로딩 상태 Provider
final isLoadingDashboardProvider = StateProvider<bool>((ref) => false);

// 에러 메시지 Provider
final dashboardErrorProvider = StateProvider<String?>((ref) => null);
