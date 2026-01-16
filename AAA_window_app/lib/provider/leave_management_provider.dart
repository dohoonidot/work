// import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/models/leave_management_models.dart';
import 'package:ASPN_AI_AGENT/shared/services/leave_api_service.dart';
import 'package:intl/intl.dart';

class LeaveManagementState {
  final LeaveManagementData? data;
  final bool isLoading;
  final String? error;
  final String currentMonth;
  final bool hideCanceledRecords;

  LeaveManagementState({
    this.data,
    this.isLoading = false,
    this.error,
    required this.currentMonth,
    this.hideCanceledRecords = false,
  });

  LeaveManagementState copyWith({
    LeaveManagementData? data,
    bool? isLoading,
    String? error,
    String? currentMonth,
    bool? hideCanceledRecords,
  }) {
    return LeaveManagementState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      currentMonth: currentMonth ?? this.currentMonth,
      hideCanceledRecords: hideCanceledRecords ?? this.hideCanceledRecords,
    );
  }

  // 상태 초기화를 위한 팩토리 메서드
  LeaveManagementState reset() {
    return LeaveManagementState(
      data: null,
      isLoading: false,
      error: null,
      currentMonth: DateFormat('yyyy-MM').format(DateTime.now()),
      hideCanceledRecords: false,
    );
  }
}

class LeaveManagementNotifier extends StateNotifier<LeaveManagementState> {
  LeaveManagementNotifier()
      : super(LeaveManagementState(
          currentMonth: DateFormat('yyyy-MM').format(DateTime.now()),
        ));

  Future<void> loadLeaveManagementData(String userId, [String? month]) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await LeaveApiService.getLeaveManagement(userId);
      state = state.copyWith(
        data: data,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void setCurrentMonth(String month) {
    state = state.copyWith(currentMonth: month);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  // 데이터 직접 업데이트 (연도별 데이터 갱신용)
  void updateData(LeaveManagementData data) {
    state = state.copyWith(data: data);
  }

  // 월별 달력 데이터만 업데이트
  Future<void> loadMonthlyCalendarData(String userId, String month) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final request = MonthlyCalendarRequest(
        userId: userId,
        month: month,
      );
      
      final response = await LeaveApiService.getMonthlyCalendar(request: request);
      
      if (response.isSuccess) {
        // 기존 데이터가 있으면 monthly_leaves만 업데이트
        if (state.data != null) {
          final updatedData = LeaveManagementData(
            leaveStatus: state.data!.leaveStatus,
            approvalStatus: state.data!.approvalStatus,
            yearlyDetails: state.data!.yearlyDetails,
            yearlyWholeStatus: state.data!.yearlyWholeStatus,
            monthlyLeaves: response.monthlyLeaves, // 새로운 월별 데이터로 교체
          );
          
          state = state.copyWith(
            data: updatedData,
            isLoading: false,
          );
        } else {
          // 기존 데이터가 없으면 기본값으로 생성
          final newData = LeaveManagementData(
            leaveStatus: [],
            approvalStatus: ApprovalStatus(requested: 0, approved: 0, rejected: 0),
            yearlyDetails: [],
            yearlyWholeStatus: [],
            monthlyLeaves: response.monthlyLeaves,
          );
          
          state = state.copyWith(
            data: newData,
            isLoading: false,
          );
        }
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? '월별 달력 데이터 로드 실패',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // 취소건 숨김 토글
  void toggleHideCanceledRecords() {
    state = state.copyWith(hideCanceledRecords: !state.hideCanceledRecords);
  }

  /// 🔄 AMQP 메시지로 특정 휴가 항목의 is_cancel 상태 업데이트
  void updateCancelStatus(int leaveId, int isCancel) {
    print('🔄 [AMQP_UPDATE] updateCancelStatus 시작');
    print('🔄 [AMQP_UPDATE]   - leaveId: $leaveId');
    print('🔄 [AMQP_UPDATE]   - isCancel: $isCancel');

    if (state.data == null) {
      print('⚠️ [AMQP_UPDATE] state.data가 null입니다. 업데이트 건너뜀');
      return;
    }

    // yearlyDetails에서 해당 ID의 항목 찾아서 업데이트
    final updatedYearlyDetails = state.data!.yearlyDetails.map((detail) {
      if (detail.id == leaveId) {
        print('🔄 [AMQP_UPDATE] ID $leaveId 항목 발견!');
        print('🔄 [AMQP_UPDATE]   - 기존 isCancel: ${detail.isCancel}');
        print('🔄 [AMQP_UPDATE]   - 새로운 isCancel: $isCancel');

        // YearlyDetail은 불변 객체이므로 새로 생성
        return YearlyDetail(
          id: detail.id,
          status: detail.status,
          leaveType: detail.leaveType,
          startDate: detail.startDate,
          endDate: detail.endDate,
          workdaysCount: detail.workdaysCount,
          requestedDate: detail.requestedDate,
          reason: detail.reason,
          rejectMessage: detail.rejectMessage,
          isCancel: isCancel, // ⭐ 업데이트된 값
        );
      }
      return detail;
    }).toList();

    // 업데이트된 데이터로 상태 변경
    final updatedData = LeaveManagementData(
      leaveStatus: state.data!.leaveStatus,
      approvalStatus: state.data!.approvalStatus,
      yearlyDetails: updatedYearlyDetails,
      yearlyWholeStatus: state.data!.yearlyWholeStatus,
      monthlyLeaves: state.data!.monthlyLeaves,
    );

    state = state.copyWith(data: updatedData);
    print('✅ [AMQP_UPDATE] 휴가 항목 업데이트 완료!');
    print('✅ [AMQP_UPDATE] UI가 자동으로 새로고침됩니다.');
  }

  /// ✅ 사용자가 취소 상신을 보낸 직후 UI를 즉시 갱신 (대기 상태 + 취소 상신 플래그)
  void markCancelRequestPending(int leaveId) {
    print('🔄 [CANCEL_PENDING] markCancelRequestPending 시작 - leaveId: $leaveId');

    if (state.data == null) {
      print('⚠️ [CANCEL_PENDING] state.data가 null입니다. 건너뜀');
      return;
    }

    final updatedYearlyDetails = state.data!.yearlyDetails.map((detail) {
      if (detail.id == leaveId) {
        print('🔄 [CANCEL_PENDING] ID $leaveId 항목 대기 상태로 업데이트');
        return YearlyDetail(
          id: detail.id,
          status: 'REQUESTED', // 취소 상신 대기 상태로 표시
          leaveType: detail.leaveType,
          startDate: detail.startDate,
          endDate: detail.endDate,
          workdaysCount: detail.workdaysCount,
          requestedDate: detail.requestedDate,
          reason: detail.reason,
          rejectMessage: detail.rejectMessage,
          isCancel: 1, // 취소 상신 플래그 설정
        );
      }
      return detail;
    }).toList();

    final updatedData = LeaveManagementData(
      leaveStatus: state.data!.leaveStatus,
      approvalStatus: state.data!.approvalStatus,
      yearlyDetails: updatedYearlyDetails,
      yearlyWholeStatus: state.data!.yearlyWholeStatus,
      monthlyLeaves: state.data!.monthlyLeaves,
    );

    state = state.copyWith(data: updatedData);
    print('✅ [CANCEL_PENDING] UI 갱신 완료 (연차 취소 상신 대기중)');
  }

  // 로그아웃 시 상태 초기화
  void resetState() {
    print('🔄 휴가관리 상태 초기화 중...');
    state = state.reset();
    print('✅ 휴가관리 상태 초기화 완료');
  }
}

final leaveManagementProvider =
    StateNotifierProvider<LeaveManagementNotifier, LeaveManagementState>(
  (ref) => LeaveManagementNotifier(),
);
