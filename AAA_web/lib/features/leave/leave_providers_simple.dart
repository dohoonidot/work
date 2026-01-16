import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'leave_models.dart';
import 'package:ASPN_AI_AGENT/shared/services/leave_api_service.dart';

// 휴가신청 내역 관리 Provider (원래 구조 유지)
class LeaveRequestHistoryNotifier
    extends StateNotifier<List<LeaveRequestHistory>> {
  LeaveRequestHistoryNotifier() : super([]);

  // API에서 데이터 로드
  Future<void> loadData(String userId, int year,
      {LeaveRequestStatus? status}) async {
    try {
      final requests = await LeaveApiService.getLeaveRequestHistory(
        userId: userId,
        year: year,
        status: status,
      );
      state = requests;
    } catch (e) {
      print('휴가 신청 내역 로드 실패: $e');
      state = [];
    }
  }

  void addLeaveRequest(LeaveRequestHistory request) {
    state = [request, ...state];
  }

  List<LeaveRequestHistory> getByStatus(LeaveRequestStatus? status) {
    if (status == null) return state;
    return state.where((request) => request.status == status).toList();
  }

  void cancelLeaveRequest(String requestId) {
    state = state.map((request) {
      if (request.id == requestId) {
        return LeaveRequestHistory(
          id: request.id,
          applicantName: request.applicantName,
          department: request.department,
          vacationType: request.vacationType,
          startDate: request.startDate,
          endDate: request.endDate,
          days: request.days,
          reason: request.reason,
          status: LeaveRequestStatus.cancelled,
          submittedDate: request.submittedDate,
          approverComment: request.approverComment,
        );
      }
      return request;
    }).toList();
  }

  // 상태 초기화 (로그아웃 시 사용)
  void resetState() {
    state = [];
  }
}

final leaveRequestHistoryProvider = StateNotifierProvider<
    LeaveRequestHistoryNotifier, List<LeaveRequestHistory>>((ref) {
  return LeaveRequestHistoryNotifier();
});

// 사이드바 상태 관리 Provider
final leaveSidebarStateProvider = StateProvider<bool>((ref) => false);

// 휴가 잔여량 Provider
final leaveBalanceProvider = Provider<List<LeaveBalance>>((ref) {
  return [
    LeaveBalance(
      type: '비례연차',
      total: 15,
      used: 5,
      remaining: 10,
    ),
    LeaveBalance(
      type: '보상휴가',
      total: 3,
      used: 1,
      remaining: 2,
    ),
    LeaveBalance(
      type: '특별휴가',
      total: 5,
      used: 0,
      remaining: 5,
    ),
  ];
});

// 부서원 목록 Provider
final departmentMembersProvider = Provider<List<DepartmentMember>>((ref) {
  return [
    DepartmentMember(
      id: '1',
      name: '홍길동',
      department: '개발팀',
      position: '주임',
    ),
    DepartmentMember(
      id: '2',
      name: '김철수',
      department: '개발팀',
      position: '대리',
    ),
    DepartmentMember(
      id: '3',
      name: '이영희',
      department: '개발팀',
      position: '과장',
    ),
    DepartmentMember(
      id: '4',
      name: '박민수',
      department: '개발팀',
      position: '주임',
    ),
    DepartmentMember(
      id: '5',
      name: '정수영',
      department: '개발팀',
      position: '사원',
    ),
  ];
});

// 부서원 휴가 내역 Provider
class DepartmentLeaveHistoryNotifier
    extends StateNotifier<Map<String, List<LeaveRequestHistory>>> {
  DepartmentLeaveHistoryNotifier() : super({});

  // API에서 데이터 로드
  Future<void> loadData(String userId, int year, {String? memberId}) async {
    try {
      final history = await LeaveApiService.getDepartmentLeaveHistory(
        userId: userId,
        year: year,
        memberId: memberId,
      );
      state = history;
    } catch (e) {
      print('부서원 휴가 내역 로드 실패: $e');
      state = {};
    }
  }

  List<LeaveRequestHistory> getLeaveHistoryByMember(String memberId) {
    return state[memberId] ?? [];
  }

  List<LeaveRequestHistory> getAllDepartmentLeaveHistory() {
    return state.values.expand((list) => list).toList();
  }

  List<LeaveRequestHistory> getFilteredLeaveHistory(
      DepartmentLeaveViewType viewType,
      {String? selectedMemberId}) {
    switch (viewType) {
      case DepartmentLeaveViewType.personal:
        return getLeaveHistoryByMember('1'); // 현재 사용자 ID
      case DepartmentLeaveViewType.department:
        if (selectedMemberId != null) {
          return getLeaveHistoryByMember(selectedMemberId);
        }
        return getAllDepartmentLeaveHistory();
    }
  }

  // 상태 초기화 (로그아웃 시 사용)
  void resetState() {
    state = {};
  }
}

final departmentLeaveHistoryProvider = StateNotifierProvider<
    DepartmentLeaveHistoryNotifier,
    Map<String, List<LeaveRequestHistory>>>((ref) {
  return DepartmentLeaveHistoryNotifier();
});

// 휴가 관리대장 Provider
final leaveManagementTableProvider =
    Provider<List<Map<String, dynamic>>>((ref) {
  return [
    {
      'leaveType': '연차',
      'allowedDays': 15,
      'usedByMonth': [2, 1, 0, 3, 2, 1, 2, 0, 1, 2, 0, 1],
      'totalUsed': 15,
    },
    {
      'leaveType': '병가',
      'allowedDays': 5,
      'usedByMonth': [0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0],
      'totalUsed': 2,
    },
    {
      'leaveType': '경조사',
      'allowedDays': 3,
      'usedByMonth': [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 2],
      'totalUsed': 3,
    },
  ];
});

// 현재 사용자 ID Provider (로그인 정보에서 가져오는 것으로 대체 예정)
final currentUserIdProvider = StateProvider<String>((ref) => 'user_001');

// 선택된 연도 Provider
final selectedYearProvider = StateProvider<int>((ref) => DateTime.now().year);

// 데이터 로딩 상태 Provider
final isLoadingDashboardProvider = StateProvider<bool>((ref) => false);

// 에러 메시지 Provider
final dashboardErrorProvider = StateProvider<String?>((ref) => null);
