// import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'leave_providers.dart';
import 'leave_models.dart';

/// 휴가관리 화면의 데이터 로딩 및 상태 관리를 담당하는 컨트롤러
class LeaveScreenController {
  static const String defaultUserId = 'user_001'; // 기본 사용자 ID

  /// 화면 초기화
  static void initializeData(WidgetRef ref) {
    // API 데이터 로드
    final userId = ref.read(currentUserIdProvider);
    final year = ref.read(selectedYearProvider);

    ref.read(leaveRequestHistoryProvider.notifier).loadData(userId, year);
    ref.read(departmentLeaveHistoryProvider.notifier).loadData(userId, year);

    print('Data initialized for user: $userId, year: $year');
  }

  /// API 데이터 로드
  static Future<void> loadApiData(WidgetRef ref,
      {String? userId, int? year}) async {
    final targetUserId = userId ?? ref.read(currentUserIdProvider);
    final targetYear = year ?? ref.read(selectedYearProvider);

    // null 체크 추가
    if (targetUserId != null && targetYear != null) {
      await ref
          .read(leaveRequestHistoryProvider.notifier)
          .loadData(targetUserId, targetYear);
      await ref
          .read(departmentLeaveHistoryProvider.notifier)
          .loadData(targetUserId, targetYear);
    }

    print('API data loaded for user: $targetUserId, year: $targetYear');
  }

  /// 대시보드 통합 데이터 로드
  static Future<void> loadDashboardData(WidgetRef ref,
      {String? userId, int? year}) async {
    await loadApiData(ref, userId: userId, year: year);
  }

  /// 데이터 새로고침
  static Future<void> refreshData(WidgetRef ref) async {
    try {
      await loadApiData(ref);
    } catch (e) {
      print('Refresh error: $e');
    }
  }

  /// 연도 변경 처리
  static void changeYear(WidgetRef ref, int newYear) {
    ref.read(selectedYearProvider.notifier).state = newYear;
    print('Year changed to: $newYear');
    refreshData(ref);
  }

  /// 휴가 신청 처리
  static Future<bool> submitLeaveRequest(
    WidgetRef ref, {
    required String vacationType,
    required DateTime startDate,
    required DateTime endDate,
    required double days,
    required String reason,
  }) async {
    try {
      final userId = ref.read(currentUserIdProvider);

      // 실제 API 호출
      await ref.read(leaveRequestHistoryProvider.notifier).addLeaveRequest(
            userId: userId,
            vacationType: vacationType,
            startDate: startDate,
            endDate: endDate,
            days: days,
            reason: reason,
          );

      print(
          'Leave request submitted: $vacationType from $startDate to $endDate');
      return true;
    } catch (e) {
      print('Submit leave request error: $e');
      return false;
    }
  }

  /// 휴가 취소 처리
  static Future<bool> cancelLeaveRequest(
      WidgetRef ref, String requestId) async {
    try {
      final userId = ref.read(currentUserIdProvider);

      // Provider에서 취소 처리
      await ref.read(leaveRequestHistoryProvider.notifier).cancelLeaveRequest(
            requestId: requestId,
            userId: userId,
          );

      return true;
    } catch (e) {
      print('Cancel leave request error: $e');
      return false;
    }
  }

  /// AsyncValue에서 데이터 추출 헬퍼
  static List<T> getAsyncValueData<T>(AsyncValue<List<T>> asyncValue) {
    return asyncValue.when(
      data: (data) => data,
      loading: () => [],
      error: (_, __) => [],
    );
  }

  /// 로딩 상태 확인
  static bool isAnyProviderLoading(WidgetRef ref) {
    // 현재는 로딩 상태가 없으므로 항상 false 반환
    return false;
  }

  /// 에러 상태 확인
  static String? getAnyProviderError(WidgetRef ref) {
    // 현재는 에러 상태 추적하지 않음
    return null;
  }
}

/// 휴가 화면용 확장 메소드
extension LeaveScreenExtensions on WidgetRef {
  /// 편의 메소드: 현재 사용자의 휴가 내역
  List<LeaveRequestHistory> get currentUserLeaveHistory {
    return watch(leaveRequestHistoryProvider).when(
      data: (data) => data,
      loading: () => [],
      error: (_, __) => [],
    );
  }

  /// 편의 메소드: 현재 사용자의 휴가 잔여량
  List<LeaveBalance> get currentUserLeaveBalance {
    return watch(leaveBalanceProvider).when(
      data: (data) => data,
      loading: () => [],
      error: (_, __) => [],
    );
  }

  /// 편의 메소드: 부서원 목록
  List<DepartmentMember> get departmentMembers {
    return watch(departmentMembersProvider).when(
      data: (data) => data,
      loading: () => [],
      error: (_, __) => [],
    );
  }

  /// 편의 메소드: 전체 로딩 상태 확인
  bool get isLeaveDataLoading {
    return LeaveScreenController.isAnyProviderLoading(this);
  }

  /// 편의 메소드: 에러 상태 확인
  String? get leaveDataError {
    return LeaveScreenController.getAnyProviderError(this);
  }
}
