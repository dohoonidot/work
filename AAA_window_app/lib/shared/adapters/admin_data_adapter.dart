import 'package:ASPN_AI_AGENT/models/leave_management_models.dart';
import 'package:ASPN_AI_AGENT/features/leave/leave_models.dart';

/// 관리자 API 데이터를 기존 UI 모델로 변환하는 어댑터 클래스
class AdminDataAdapter {
  /// AdminWaitingLeave를 LeaveRequestHistory로 변환
  static LeaveRequestHistory waitingLeaveToHistory(AdminWaitingLeave waitingLeave) {
    return LeaveRequestHistory(
      id: waitingLeave.id.toString(),
      applicantName: waitingLeave.name,
      department: waitingLeave.department,
      vacationType: waitingLeave.leaveType,
      startDate: waitingLeave.startDate,
      endDate: waitingLeave.endDate,
      days: waitingLeave.workdaysCount,
      reason: waitingLeave.reason,
      status: _mapStatusToEnum(waitingLeave.status),
      submittedDate: waitingLeave.requestedDate,
      approverComment: null, // API 응답에 없음
    );
  }

  /// AdminMonthlyLeave를 LeaveRequestHistory로 변환
  static LeaveRequestHistory monthlyLeaveToHistory(AdminMonthlyLeave monthlyLeave) {
    return LeaveRequestHistory(
      id: monthlyLeave.id.toString(),
      applicantName: monthlyLeave.name,
      department: monthlyLeave.department,
      vacationType: monthlyLeave.leaveType,
      startDate: monthlyLeave.startDate,
      endDate: monthlyLeave.endDate,
      days: monthlyLeave.workdaysCount,
      reason: monthlyLeave.reason,
      status: _mapStatusToEnum(monthlyLeave.status),
      submittedDate: monthlyLeave.requestedDate,
      approverComment: null, // API 응답에 없음
    );
  }

  /// AdminWaitingLeave 리스트를 LeaveRequestHistory 리스트로 변환
  static List<LeaveRequestHistory> waitingLeavesToHistories(
      List<AdminWaitingLeave> waitingLeaves) {
    return waitingLeaves.map((leave) => waitingLeaveToHistory(leave)).toList();
  }

  /// AdminMonthlyLeave 리스트를 LeaveRequestHistory 리스트로 변환
  static List<LeaveRequestHistory> monthlyLeavesToHistories(
      List<AdminMonthlyLeave> monthlyLeaves) {
    return monthlyLeaves.map((leave) => monthlyLeaveToHistory(leave)).toList();
  }

  /// @deprecated 더 이상 사용하지 않음. getAllLeaves 또는 monthlyLeavesToHistories 사용
  /// 모든 휴가 데이터를 하나의 LeaveRequestHistory 리스트로 합침 
  static List<LeaveRequestHistory> combineAllLeaves({
    required List<AdminWaitingLeave> waitingLeaves,
    required List<AdminMonthlyLeave> monthlyLeaves,
  }) {
    final List<LeaveRequestHistory> allLeaves = [];
    
    // 대기 중인 휴가 추가
    allLeaves.addAll(waitingLeavesToHistories(waitingLeaves));
    
    // 월별 휴가 추가
    allLeaves.addAll(monthlyLeavesToHistories(monthlyLeaves));
    
    // 신청 날짜 기준으로 정렬 (최신순)
    allLeaves.sort((a, b) => b.submittedDate.compareTo(a.submittedDate));
    
    return allLeaves;
  }

  /// 대기중 탭용: waiting_leaves에서 REQUESTED 상태만 필터링
  static List<LeaveRequestHistory> getPendingLeaves({
    required List<AdminWaitingLeave> waitingLeaves,
  }) {
    final List<LeaveRequestHistory> pendingLeaves = [];
    
    // REQUESTED 상태인 대기 중인 휴가만 추가
    final requestedWaitingLeaves = waitingLeaves
        .where((leave) => leave.status.toUpperCase() == 'REQUESTED')
        .toList();
    pendingLeaves.addAll(waitingLeavesToHistories(requestedWaitingLeaves));
    
    // 신청 날짜 기준으로 정렬 (최신순)
    pendingLeaves.sort((a, b) => b.submittedDate.compareTo(a.submittedDate));
    
    return pendingLeaves;
  }

  /// 전체 탭용: waiting_leaves의 모든 상태 표시
  static List<LeaveRequestHistory> getAllLeaves({
    required List<AdminWaitingLeave> waitingLeaves,
  }) {
    final allLeaves = waitingLeavesToHistories(waitingLeaves);
    
    // 신청 날짜 기준으로 정렬 (최신순)
    allLeaves.sort((a, b) => b.submittedDate.compareTo(a.submittedDate));
    
    return allLeaves;
  }

  /// API 상태 문자열을 LeaveRequestStatus enum으로 변환
  static LeaveRequestStatus _mapStatusToEnum(String? status) {
    // getAdminManagementData API의 monthly_leaves는 status가 없고 전부 승인된 데이터
    if (status == null || status.isEmpty) {
      return LeaveRequestStatus.approved;
    }
    
    switch (status.toUpperCase()) {
      case 'REQUESTED':
        return LeaveRequestStatus.pending;
      case 'APPROVED':
        return LeaveRequestStatus.approved;
      case 'REJECTED':
        return LeaveRequestStatus.rejected;
      case 'CANCELLED':
        return LeaveRequestStatus.cancelled;
      default:
        return LeaveRequestStatus.pending;
    }
  }

  /// AdminApprovalStatus를 개별 카운트로 추출
  /// approval_status가 없는 경우 waiting_leaves에서 계산
  static Map<String, int> extractApprovalCounts(
    AdminApprovalStatus? approvalStatus,
    List<AdminWaitingLeave>? waitingLeaves,
  ) {
    if (approvalStatus != null) {
      return {
        'pending': approvalStatus.requested,
        'approved': approvalStatus.approved,
        'rejected': approvalStatus.rejected,
      };
    }

    // approval_status가 없는 경우 waiting_leaves에서 직접 계산 (CANCELLED 제외)
    if (waitingLeaves != null) {
      int pending = 0;
      int approved = 0;
      int rejected = 0;

      for (var leave in waitingLeaves) {
        switch (leave.status.toUpperCase()) {
          case 'REQUESTED':
            pending++;
            break;
          case 'APPROVED':
            approved++;
            break;
          case 'REJECTED':
            rejected++;
            break;
          // CANCELLED는 카운트에서 제외
          case 'CANCELLED':
            break;
        }
      }

      return {
        'pending': pending,
        'approved': approved,
        'rejected': rejected,
      };
    }

    return {
      'pending': 0,
      'approved': 0,
      'rejected': 0,
    };
  }

  /// 달력용 선택된 날짜 상세 정보 추출
  static List<Map<String, dynamic>> extractSelectedDateDetails({
    required DateTime selectedDate,
    required List<AdminMonthlyLeave> monthlyLeaves,
  }) {
    return monthlyLeaves
        .where((leave) =>
            selectedDate.isAfter(leave.startDate.subtract(const Duration(days: 1))) &&
            selectedDate.isBefore(leave.endDate.add(const Duration(days: 1))))
        .map((leave) => {
              'id': leave.id,
              'status': _mapStatusToEnum(leave.status),
              'vacationType': leave.leaveType,
              'employeeName': leave.name,
              'department': leave.department,
              'jobPosition': leave.jobPosition,
              'reason': leave.reason,
              'startDate': leave.startDate,
              'endDate': leave.endDate,
            })
        .toList();
  }
}