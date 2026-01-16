// ===============================
// 공통 유틸리티 함수
// ===============================

/// 날짜 파싱 헬퍼 함수
/// 다양한 형식의 날짜 데이터를 DateTime으로 변환
/// - ISO 8601 문자열 (예: "2024-01-01T00:00:00Z")
/// - Unix timestamp (초 단위, int 또는 String)
/// - null 또는 파싱 실패 시 epoch(1970-01-01) 반환하여 명확히 표시
DateTime parseDateTimeValue(dynamic dateValue, String context) {
  if (dateValue == null) {
    print('⚠️ [$context] 날짜 값이 null입니다. 기본값(epoch)을 사용합니다.');
    return DateTime.fromMillisecondsSinceEpoch(0); // 1970-01-01
  }

  if (dateValue is String) {
    // ISO 문자열 형태로 오는 경우
    if (dateValue.contains('T')) {
      try {
        // 서버에서 이미 한국시간으로 보내므로 변환하지 않음
        return DateTime.parse(dateValue);
      } catch (e) {
        print('⚠️ [$context] ISO 날짜 파싱 실패: $dateValue, 에러: $e');
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
    // Unix timestamp 문자열로 오는 경우
    final timestamp = int.tryParse(dateValue);
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    }
  } else if (dateValue is int) {
    // Unix timestamp로 오는 경우
    return DateTime.fromMillisecondsSinceEpoch(dateValue * 1000);
  }

  print('⚠️ [$context] 날짜 파싱 실패: $dateValue (타입: ${dateValue.runtimeType})');
  return DateTime.fromMillisecondsSinceEpoch(0);
}

// ===============================
// 데이터 모델
// ===============================

class LeaveStatus {
  final String leaveType;
  final double totalDays;
  final double remainDays;

  LeaveStatus({
    required this.leaveType,
    required this.totalDays,
    required this.remainDays,
  });

  factory LeaveStatus.fromJson(Map<String, dynamic> json) {
    return LeaveStatus(
      leaveType: json['leave_type'] ?? '',
      totalDays: (json['total_days'] ?? 0.0).toDouble(),
      remainDays: (json['remain_days'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'leave_type': leaveType,
      'total_days': totalDays,
      'remain_days': remainDays,
    };
  }
}

class ApprovalStatus {
  final int requested;
  final int approved;
  final int rejected;

  ApprovalStatus({
    required this.requested,
    required this.approved,
    required this.rejected,
  });

  factory ApprovalStatus.fromJson(Map<String, dynamic> json) {
    return ApprovalStatus(
      requested: json['REQUESTED'] ?? 0,
      approved: json['APPROVED'] ?? 0,
      rejected: json['REJECTED'] ?? 0,
    );
  }

  // 배열 형태의 approval_status를 처리하는 팩토리 메서드
  factory ApprovalStatus.fromJsonArray(List<dynamic> jsonArray) {
    int requested = 0;
    int approved = 0;
    int rejected = 0;

    for (var item in jsonArray) {
      if (item is Map<String, dynamic>) {
        final status = item['status'] as String?;
        final count = item['count'] as int? ?? 0;

        switch (status) {
          case 'REQUESTED':
            requested = count;
            break;
          case 'APPROVED':
            approved = count;
            break;
          case 'REJECTED':
            rejected = count;
            break;
        }
      }
    }

    return ApprovalStatus(
      requested: requested,
      approved: approved,
      rejected: rejected,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'REQUESTED': requested,
      'APPROVED': approved,
      'REJECTED': rejected,
    };
  }
}

class YearlyDetail {
  final int id;
  final String status;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final double workdaysCount;
  final DateTime requestedDate;
  final String reason;
  final String rejectMessage;
  final int isCancel; // 0: 일반 상신, 1: 취소 상신

  YearlyDetail({
    required this.id,
    required this.status,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.workdaysCount,
    required this.requestedDate,
    required this.reason,
    required this.rejectMessage,
    this.isCancel = 0,
  });

  factory YearlyDetail.fromJson(Map<String, dynamic> json) {
    // 🔍 [CANCEL_DEBUG] 모델 파싱 전 원본 데이터 확인
    final isCancelValue = json['is_cancel'];
    print('🔍 [CANCEL_DEBUG] YearlyDetail.fromJson 시작');
    print(
        '🔍 [CANCEL_DEBUG]   - 원본 is_cancel 값: $isCancelValue (타입: ${isCancelValue?.runtimeType ?? 'null'})');

    final parsedIsCancel = json['is_cancel'] ?? 0;
    print(
        '🔍 [CANCEL_DEBUG]   - 파싱된 isCancel 값: $parsedIsCancel (타입: ${parsedIsCancel.runtimeType})');

    final detail = YearlyDetail(
      id: int.tryParse(json['id'].toString()) ?? 0,
      status: json['status'] ?? '',
      leaveType: json['leave_type'] ?? '',
      startDate:
          parseDateTimeValue(json['start_date'], 'YearlyDetail.startDate'),
      endDate: parseDateTimeValue(json['end_date'], 'YearlyDetail.endDate'),
      workdaysCount: (json['workdays_count'] ?? 0.0).toDouble(),
      requestedDate: parseDateTimeValue(
          json['requested_date'], 'YearlyDetail.requestedDate'),
      reason: json['reason'] ?? '',
      rejectMessage: json['reject_message'] ?? '',
      isCancel: parsedIsCancel,
    );

    // 🔍 [CANCEL_DEBUG] 모델 객체 생성 후 확인
    print('🔍 [CANCEL_DEBUG]   - 생성된 객체의 isCancel: ${detail.isCancel}');
    print(
        '🔍 [CANCEL_DEBUG]   - 생성된 객체의 isCancelRequest: ${detail.isCancelRequest}');
    if (detail.isCancelRequest) {
      print('🔍 [CANCEL_DEBUG]   ⭐⭐⭐ 취소상신 객체 생성됨! (ID: ${detail.id}) ⭐⭐⭐');
    }

    return detail;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'leave_type': leaveType,
      'start_date': startDate.millisecondsSinceEpoch ~/ 1000,
      'end_date': endDate.millisecondsSinceEpoch ~/ 1000,
      'workdays_count': workdaysCount,
      'requested_date': requestedDate.millisecondsSinceEpoch ~/ 1000,
      'reason': reason,
      'reject_message': rejectMessage,
      'is_cancel': isCancel,
    };
  }

  /// 취소 상신 여부 확인
  bool get isCancelRequest => isCancel == 1;
}

class YearlyWholeStatus {
  final String leaveType;
  final double totalDays;
  final double m01;
  final double m02;
  final double m03;
  final double m04;
  final double m05;
  final double m06;
  final double m07;
  final double m08;
  final double m09;
  final double m10;
  final double m11;
  final double m12;
  final double remainDays;

  YearlyWholeStatus({
    required this.leaveType,
    required this.totalDays,
    required this.m01,
    required this.m02,
    required this.m03,
    required this.m04,
    required this.m05,
    required this.m06,
    required this.m07,
    required this.m08,
    required this.m09,
    required this.m10,
    required this.m11,
    required this.m12,
    required this.remainDays,
  });

  factory YearlyWholeStatus.fromJson(Map<String, dynamic> json) {
    return YearlyWholeStatus(
      leaveType: json['leave_type'] ?? '',
      totalDays: (json['total_days'] ?? 0.0).toDouble(),
      m01: (json['m01'] ?? 0.0).toDouble(),
      m02: (json['m02'] ?? 0.0).toDouble(),
      m03: (json['m03'] ?? 0.0).toDouble(),
      m04: (json['m04'] ?? 0.0).toDouble(),
      m05: (json['m05'] ?? 0.0).toDouble(),
      m06: (json['m06'] ?? 0.0).toDouble(),
      m07: (json['m07'] ?? 0.0).toDouble(),
      m08: (json['m08'] ?? 0.0).toDouble(),
      m09: (json['m09'] ?? 0.0).toDouble(),
      m10: (json['m10'] ?? 0.0).toDouble(),
      m11: (json['m11'] ?? 0.0).toDouble(),
      m12: (json['m12'] ?? 0.0).toDouble(),
      remainDays: (json['remain_days'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'leave_type': leaveType,
      'total_days': totalDays,
      'm01': m01,
      'm02': m02,
      'm03': m03,
      'm04': m04,
      'm05': m05,
      'm06': m06,
      'm07': m07,
      'm08': m08,
      'm09': m09,
      'm10': m10,
      'm11': m11,
      'm12': m12,
      'remain_days': remainDays,
    };
  }
}

class MonthlyLeave {
  final String status;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String halfDaySlot;
  final String reason;
  final String rejectMessage;

  MonthlyLeave({
    required this.status,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.halfDaySlot,
    required this.reason,
    required this.rejectMessage,
  });

  factory MonthlyLeave.fromJson(Map<String, dynamic> json) {
    return MonthlyLeave(
      status: json['status'] ?? '',
      leaveType: json['leave_type'] ?? '',
      startDate:
          parseDateTimeValue(json['start_date'], 'MonthlyLeave.startDate'),
      endDate: parseDateTimeValue(json['end_date'], 'MonthlyLeave.endDate'),
      halfDaySlot: json['half_day_slot'] ?? '',
      reason: json['reason'] ?? '',
      rejectMessage: json['reject_message'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'leave_type': leaveType,
      'start_date': startDate.millisecondsSinceEpoch ~/ 1000,
      'end_date': endDate.millisecondsSinceEpoch ~/ 1000,
      'half_day_slot': halfDaySlot,
      'reason': reason,
      'reject_message': rejectMessage,
    };
  }
}

class LeaveManagementData {
  final List<LeaveStatus> leaveStatus;
  final ApprovalStatus approvalStatus;
  final List<YearlyDetail> yearlyDetails;
  final List<YearlyWholeStatus> yearlyWholeStatus;
  final List<MonthlyLeave> monthlyLeaves;

  LeaveManagementData({
    required this.leaveStatus,
    required this.approvalStatus,
    required this.yearlyDetails,
    required this.yearlyWholeStatus,
    required this.monthlyLeaves,
  });

  factory LeaveManagementData.fromJson(Map<String, dynamic> json) {
    // approval_status가 배열인지 Map인지 확인하여 처리
    ApprovalStatus approvalStatus;
    final approvalStatusData = json['approval_status'];

    if (approvalStatusData is List) {
      // 배열 형태로 오는 경우
      approvalStatus = ApprovalStatus.fromJsonArray(approvalStatusData);
    } else if (approvalStatusData is Map<String, dynamic>) {
      // Map 형태로 오는 경우
      approvalStatus = ApprovalStatus.fromJson(approvalStatusData);
    } else {
      // null이거나 다른 형태인 경우 기본값
      approvalStatus = ApprovalStatus(requested: 0, approved: 0, rejected: 0);
    }

    return LeaveManagementData(
      leaveStatus: (json['leave_status'] as List?)
              ?.map((item) => LeaveStatus.fromJson(item))
              .toList() ??
          [],
      approvalStatus: approvalStatus,
      yearlyDetails: (json['yearly_details'] as List?)
              ?.map((item) => YearlyDetail.fromJson(item))
              .toList() ??
          [],
      yearlyWholeStatus: (json['yearly_whole_status'] as List?)
              ?.map((item) => YearlyWholeStatus.fromJson(item))
              .toList() ??
          [],
      monthlyLeaves: (json['monthly_leaves'] as List?)
              ?.map((item) => MonthlyLeave.fromJson(item))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'leave_status': leaveStatus.map((item) => item.toJson()).toList(),
      'approval_status': approvalStatus.toJson(),
      'yearly_details': yearlyDetails.map((item) => item.toJson()).toList(),
      'yearly_whole_status':
          yearlyWholeStatus.map((item) => item.toJson()).toList(),
      'monthly_leaves': monthlyLeaves.map((item) => item.toJson()).toList(),
    };
  }
}

// ===============================
// 휴가 상신 API 모델
// ===============================

class CcPerson {
  final String name;
  final String department;
  final String? userId; // 동명이인 구별을 위한 userId 추가

  CcPerson({
    required this.name,
    required this.department,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'department': department,
      if (userId != null) 'user_id': userId,
    };
  }

  factory CcPerson.fromJson(Map<String, dynamic> json) {
    return CcPerson(
      name: json['name'] ?? '',
      department: json['department'] ?? '',
      userId: json['user_id'],
    );
  }

  // 동명이인 구별을 위한 고유 키 생성
  String get uniqueKey => userId ?? '$name|$department';
}

/// 휴가 신청용 결재선 아이템
class LeaveRequestApprovalLine {
  final String approverId;
  final String nextApproverId;
  final int approvalSeq;
  final String approverName;

  LeaveRequestApprovalLine({
    required this.approverId,
    required this.nextApproverId,
    required this.approvalSeq,
    required this.approverName,
  });

  Map<String, dynamic> toJson() {
    return {
      'approver_id': approverId,
      'next_approver_id': nextApproverId,
      'approval_seq': approvalSeq,
      'approver_name': approverName,
    };
  }
}

class LeaveRequestRequest {
  final String userId;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final List<LeaveRequestApprovalLine> approvalLine; // approval_line 배열로 변경
  final List<CcPerson> ccList;
  final String reason;
  final String? halfDaySlot;
  final int isNextYear;

  LeaveRequestRequest({
    required this.userId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.approvalLine,
    required this.ccList,
    required this.reason,
    this.halfDaySlot,
    this.isNextYear = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'leave_type': leaveType,
      'start_date': _formatDateForApi(startDate),
      'end_date': _formatDateForApi(endDate),
      'approval_line': approvalLine.map((item) => item.toJson()).toList(),
      'cc_list': ccList.map((cc) => cc.toJson()).toList(),
      'reason': reason,
      'half_day_slot': halfDaySlot,
      'is_next_year': isNextYear,
    };
  }

  /// API 서버에서 요구하는 날짜 형식으로 변환
  String _formatDateForApi(DateTime date) {
    // 서버가 한국시간을 기대하므로 로컬 시간을 ISO 8601 형식으로 변환
    // 밀리초 없이 Z 접미사 포함하여 반환
    final isoString = date.toIso8601String();
    if (isoString.endsWith('Z')) {
      return isoString.replaceAll('.000Z', 'Z');
    } else {
      return isoString.replaceAll('.000', 'Z');
    }
  }
}

class LeaveRequestResponse {
  final String? error;

  LeaveRequestResponse({
    this.error,
  });

  factory LeaveRequestResponse.fromJson(Map<String, dynamic> json) {
    return LeaveRequestResponse(
      error: json['error'] as String?,
    );
  }

  bool get isSuccess => error == null;
}


// ===============================
// 휴가 취소 API 모델
// ===============================

class LeaveCancelRequest {
  final int id;
  final String userId;

  LeaveCancelRequest({
    required this.id,
    required this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
    };
  }
}

class LeaveCancelResponse {
  final ApprovalStatus? approvalStatus;
  final String? error;
  final List<LeaveStatus> leaveStatus;
  final List<MonthlyLeave> monthlyLeaves;
  final List<YearlyDetail> yearlyDetails;
  final List<YearlyWholeStatus> yearlyWholeStatus;

  LeaveCancelResponse({
    this.approvalStatus,
    this.error,
    required this.leaveStatus,
    required this.monthlyLeaves,
    required this.yearlyDetails,
    required this.yearlyWholeStatus,
  });

  factory LeaveCancelResponse.fromJson(Map<String, dynamic> json) {
    // approval_status가 배열인지 Map인지 확인하여 처리
    ApprovalStatus? approvalStatus;
    final approvalStatusData = json['approval_status'];

    if (approvalStatusData != null) {
      if (approvalStatusData is List) {
        // 배열 형태로 오는 경우
        approvalStatus = ApprovalStatus.fromJsonArray(approvalStatusData);
      } else if (approvalStatusData is Map<String, dynamic>) {
        // Map 형태로 오는 경우
        approvalStatus = ApprovalStatus.fromJson(approvalStatusData);
      }
    }

    return LeaveCancelResponse(
      approvalStatus: approvalStatus,
      error: json['error'] as String?,
      leaveStatus: (json['leave_status'] as List?)
              ?.map((item) => LeaveStatus.fromJson(item))
              .toList() ??
          [],
      monthlyLeaves: (json['monthly_leaves'] as List?)
              ?.map((item) => MonthlyLeave.fromJson(item))
              .toList() ??
          [],
      yearlyDetails: (json['yearly_details'] as List?)
              ?.map((item) => YearlyDetail.fromJson(item))
              .toList() ??
          [],
      yearlyWholeStatus: (json['yearly_whole_status'] as List?)
              ?.map((item) => YearlyWholeStatus.fromJson(item))
              .toList() ??
          [],
    );
  }

  bool get isSuccess => error == null;
}


// ===============================
// 월별 달력 조회 API 모델
// ===============================

class MonthlyCalendarRequest {
  final String userId;
  final String month;

  MonthlyCalendarRequest({
    required this.userId,
    required this.month,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'month': month,
    };
  }
}

class MonthlyCalendarResponse {
  final String? error;
  final List<MonthlyLeave> monthlyLeaves;

  MonthlyCalendarResponse({
    this.error,
    required this.monthlyLeaves,
  });

  factory MonthlyCalendarResponse.fromJson(Map<String, dynamic> json) {
    return MonthlyCalendarResponse(
      error: json['error'] as String?,
      monthlyLeaves: (json['monthly_leaves'] as List?)
              ?.map((item) => MonthlyLeave.fromJson(item))
              .toList() ??
          [],
    );
  }

  bool get isSuccess => error == null;
}


// ===============================
// 연도별 휴가 내역 조회 API 모델
// ===============================

class YearlyLeaveRequest {
  final String userId;
  final String month; // 실제로는 연도값이 들어감 (API 명세에 따라)

  YearlyLeaveRequest({
    required this.userId,
    required this.month,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'month': month,
    };
  }
}

class YearlyLeaveResponse {
  final String? error;
  final List<YearlyDetail> yearlyDetails;
  final List<YearlyWholeStatus> yearlyWholeStatus;

  YearlyLeaveResponse({
    this.error,
    required this.yearlyDetails,
    required this.yearlyWholeStatus,
  });

  factory YearlyLeaveResponse.fromJson(Map<String, dynamic> json) {
    return YearlyLeaveResponse(
      error: json['error'] as String?,
      yearlyDetails: (json['yearly_details'] as List?)
              ?.map((item) => YearlyDetail.fromJson(item))
              .toList() ??
          [],
      yearlyWholeStatus: (json['yearly_whole_status'] as List?)
              ?.map((item) => YearlyWholeStatus.fromJson(item))
              .toList() ??
          [],
    );
  }

  bool get isSuccess => error == null;
}


// ===============================
// 전체 부서 휴가 현황 API 모델 (부서 휴가 현황 탭용)
// ===============================

class TotalCalendarLeave {
  final String userId; // 사용자 ID (동명이인 구분용)
  final String name;
  final String department;
  final DateTime startDate;
  final DateTime endDate;
  final String leaveType;

  TotalCalendarLeave({
    required this.userId,
    required this.name,
    required this.department,
    required this.startDate,
    required this.endDate,
    required this.leaveType,
  });

  factory TotalCalendarLeave.fromJson(Map<String, dynamic> json) {
    return TotalCalendarLeave(
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      department: json['department'] as String? ?? '',
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      leaveType: json['leave_type'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'department': department,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'leave_type': leaveType,
    };
  }
}

class TotalCalendarResponse {
  final String? error;
  final List<TotalCalendarLeave> monthlyLeaves;

  TotalCalendarResponse({
    this.error,
    required this.monthlyLeaves,
  });

  factory TotalCalendarResponse.fromJson(Map<String, dynamic> json) {
    return TotalCalendarResponse(
      error: json['error'] as String?,
      monthlyLeaves: (json['monthly_leaves'] as List?)
              ?.map((item) => TotalCalendarLeave.fromJson(item))
              .toList() ??
          [],
    );
  }

  bool get isSuccess => error == null;
}


// ===============================
// 관리자 관리 페이지 API 모델
// ===============================

class AdminWaitingLeave {
  final int id;
  final String status;
  final String name;
  final String department;
  final String jobPosition;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String halfDaySlot;
  final int totalDays;
  final int remainDays;
  final double workdaysCount;
  final DateTime requestedDate;
  final String reason;
  final String rejectMessage; // 반려 사유
  final String joinDate;
  final int isCancel; // 0: 일반 상신, 1: 취소 상신

  AdminWaitingLeave({
    required this.id,
    required this.status,
    required this.name,
    required this.department,
    required this.jobPosition,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.halfDaySlot,
    required this.totalDays,
    required this.remainDays,
    required this.workdaysCount,
    required this.requestedDate,
    required this.reason,
    this.rejectMessage = '',
    required this.joinDate,
    this.isCancel = 0,
  });

  factory AdminWaitingLeave.fromJson(Map<String, dynamic> json) {
    return AdminWaitingLeave(
      id: json['id'] as int? ?? 0,
      status: json['status'] as String? ?? '',
      name: json['name'] as String? ?? '',
      department: json['department'] as String? ?? '',
      jobPosition: json['job_position'] as String? ?? '',
      leaveType: json['leave_type'] as String? ?? '',
      startDate:
          parseDateTimeValue(json['start_date'], 'AdminWaitingLeave.startDate'),
      endDate:
          parseDateTimeValue(json['end_date'], 'AdminWaitingLeave.endDate'),
      halfDaySlot: json['half_day_slot'] as String? ?? '',
      totalDays: json['total_days'] as int? ?? 0,
      remainDays: json['remain_days'] as int? ?? 0,
      workdaysCount: (json['workdays_count'] as num? ?? 0).toDouble(),
      requestedDate: json['requested_date'] != null
          ? parseDateTimeValue(
              json['requested_date'], 'AdminWaitingLeave.requestedDate')
          : DateTime.now(),
      reason: json['reason'] as String? ?? '',
      rejectMessage: json['reject_message'] as String? ?? '',
      joinDate: json['join_date'] as String? ?? '',
      isCancel: json['is_canceled'] as int? ??
          0, // API 필드명 변경: is_cancel → is_canceled
    );
  }

  /// 취소 상신 여부 확인 (is_canceled == 1이면 취소 상신)
  bool get isCancelRequest => isCancel == 1;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'name': name,
      'department': department,
      'job_position': jobPosition,
      'leave_type': leaveType,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'half_day_slot': halfDaySlot,
      'total_days': totalDays,
      'remain_days': remainDays,
      'workdays_count': workdaysCount,
      'requested_date': requestedDate.toIso8601String(),
      'reason': reason,
      'reject_message': rejectMessage,
      'join_date': joinDate,
      'is_canceled': isCancel, // API 필드명 통일: is_cancel → is_canceled
    };
  }
}

class AdminMonthlyLeave {
  final int id;
  final String status;
  final String name;
  final String department;
  final String jobPosition;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String halfDaySlot;
  final int totalDays;
  final int remainDays;
  final double workdaysCount;
  final DateTime requestedDate;
  final String reason;
  final String joinDate;

  AdminMonthlyLeave({
    required this.id,
    required this.status,
    required this.name,
    required this.department,
    required this.jobPosition,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.halfDaySlot,
    required this.totalDays,
    required this.remainDays,
    required this.workdaysCount,
    required this.requestedDate,
    required this.reason,
    required this.joinDate,
  });

  factory AdminMonthlyLeave.fromJson(Map<String, dynamic> json) {
    // reason 필드에서 "nan |" 부분 제거
    String _cleanReason(String reason) {
      if (reason.startsWith('nan |')) {
        return reason.substring(5).trim();
      }
      return reason;
    }

    // start_date와 end_date 파싱 (null 체크)
    DateTime parseStartDate() {
      final startDateStr = json['start_date'];
      if (startDateStr == null) {
        return DateTime.now();
      }
      try {
        return DateTime.parse(startDateStr.toString());
      } catch (e) {
        return DateTime.now();
      }
    }

    DateTime parseEndDate() {
      final endDateStr = json['end_date'];
      if (endDateStr == null) {
        return DateTime.now();
      }
      try {
        return DateTime.parse(endDateStr.toString());
      } catch (e) {
        return DateTime.now();
      }
    }

    // requested_date 파싱 (null 체크)
    DateTime parseRequestedDate() {
      final requestedDateStr = json['requested_date'];
      if (requestedDateStr == null) {
        return DateTime.now();
      }
      try {
        return DateTime.parse(requestedDateStr.toString());
      } catch (e) {
        return DateTime.now();
      }
    }

    return AdminMonthlyLeave(
      id: json['id'] as int? ?? 0,
      status: json['status'] as String? ?? '',
      name: json['name'] as String? ?? '',
      department: json['department'] as String? ?? '',
      jobPosition: json['job_position'] as String? ?? '',
      leaveType: json['leave_type'] as String? ?? '',
      startDate: parseStartDate(),
      endDate: parseEndDate(),
      halfDaySlot: json['half_day_slot'] as String? ?? '',
      totalDays: json['total_days'] as int? ?? 0,
      remainDays: json['remain_days'] as int? ?? 0,
      workdaysCount: (json['workdays_count'] as num? ?? 0).toDouble(),
      requestedDate: parseRequestedDate(),
      reason: _cleanReason(json['reason'] as String? ?? ''),
      joinDate: json['join_date'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'name': name,
      'department': department,
      'job_position': jobPosition,
      'leave_type': leaveType,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'half_day_slot': halfDaySlot,
      'total_days': totalDays,
      'remain_days': remainDays,
      'workdays_count': workdaysCount,
      'requested_date': requestedDate.toIso8601String(),
      'reason': reason,
      'join_date': joinDate,
    };
  }
}

class AdminApprovalStatus {
  final int requested;
  final int approved;
  final int rejected;

  AdminApprovalStatus({
    required this.requested,
    required this.approved,
    required this.rejected,
  });

  factory AdminApprovalStatus.fromJson(Map<String, dynamic> json) {
    return AdminApprovalStatus(
      requested: json['REQUESTED'] as int? ?? 0,
      approved: json['APPROVED'] as int? ?? 0,
      rejected: json['REJECTED'] as int? ?? 0,
    );
  }

  // 새로운 배열 형태의 approval_status를 처리하는 팩토리 메서드
  factory AdminApprovalStatus.fromJsonArray(List<dynamic> jsonArray) {
    int requested = 0;
    int approved = 0;
    int rejected = 0;

    for (var item in jsonArray) {
      if (item is Map<String, dynamic>) {
        final status = item['status'] as String?;
        final count = item['count'] as int? ?? 0;

        switch (status) {
          case 'REQUESTED':
          case 'CANCEL_REQUESTED':
            // REQUESTED와 CANCEL_REQUESTED 모두 결재 대기로 카운트
            requested += count;
            break;
          case 'APPROVED':
            approved = count;
            break;
          case 'REJECTED':
            rejected = count;
            break;
        }
      }
    }

    return AdminApprovalStatus(
      requested: requested,
      approved: approved,
      rejected: rejected,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'REQUESTED': requested,
      'APPROVED': approved,
      'REJECTED': rejected,
    };
  }
}

class AdminManagementRequest {
  final String approverId;
  final String month;

  AdminManagementRequest({
    required this.approverId,
    required this.month,
  });

  Map<String, dynamic> toJson() {
    return {
      'approver_id': approverId,
      'month': month,
    };
  }
}

class AdminManagementResponse {
  final String? error;
  final AdminApprovalStatus? approvalStatus;
  final List<AdminMonthlyLeave> monthlyLeaves;
  final List<AdminWaitingLeave> waitingLeaves;

  AdminManagementResponse({
    this.error,
    this.approvalStatus,
    required this.monthlyLeaves,
    required this.waitingLeaves,
  });

  factory AdminManagementResponse.fromJson(Map<String, dynamic> json) {
    AdminApprovalStatus? approvalStatus;
    final approvalStatusData = json['approval_status'];

    if (approvalStatusData != null) {
      if (approvalStatusData is List) {
        // 새로운 배열 형태의 approval_status 처리
        approvalStatus = AdminApprovalStatus.fromJsonArray(approvalStatusData);
      } else if (approvalStatusData is Map<String, dynamic>) {
        // 기존 Map 형태 처리
        approvalStatus = AdminApprovalStatus.fromJson(approvalStatusData);
      }
    }

    // yearly API 응답 처리 (yearly_details를 waitingLeaves로 매핑)
    List<AdminWaitingLeave> waitingLeaves;
    if (json.containsKey('yearly_details')) {
      print('🔍 [AdminManagementResponse] yearly API 응답 감지 - yearly_details를 waitingLeaves로 매핑');
      waitingLeaves = (json['yearly_details'] as List?)
              ?.map((item) => AdminWaitingLeave.fromJson(item))
              .toList() ??
          [];
      print('🔍 [AdminManagementResponse] yearly_details 파싱 완료: ${waitingLeaves.length}개');
    } else {
      // 일반 management API 응답 처리
      waitingLeaves = (json['waiting_leaves'] as List?)
              ?.map((item) => AdminWaitingLeave.fromJson(item))
              .toList() ??
          [];
    }

    return AdminManagementResponse(
      error: json['error'] as String?,
      approvalStatus: approvalStatus,
      monthlyLeaves: (json['monthly_leaves'] as List?)
              ?.map((item) => AdminMonthlyLeave.fromJson(item))
              .toList() ??
          [],
      waitingLeaves: waitingLeaves,
    );
  }

  bool get isSuccess => error == null;
}


// ===============================
// 관리자 승인/반려 처리 API 모델
// ===============================

class AdminApprovalRequest {
  final int id;
  final String approverId;
  final String isApproved; // "APPROVED" or "REJECTED"
  final String? rejectMessage;

  AdminApprovalRequest({
    required this.id,
    required this.approverId,
    required this.isApproved,
    this.rejectMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'approver_id': approverId,
      'is_approved': isApproved,
      // 승인이 아닐 때(반려일 때)만 reject_message 포함
      if (isApproved != 'APPROVED' && rejectMessage != null)
        'reject_message': rejectMessage,
    };
  }
}

class AdminApprovalResponse {
  final String? error;
  final List<AdminMonthlyLeave> monthlyLeaves;

  AdminApprovalResponse({
    this.error,
    required this.monthlyLeaves,
  });

  factory AdminApprovalResponse.fromJson(Map<String, dynamic> json) {
    return AdminApprovalResponse(
      error: json['error'] as String?,
      monthlyLeaves: (json['monthly_leaves'] as List?)
              ?.map((item) => AdminMonthlyLeave.fromJson(item))
              .toList() ??
          [],
    );
  }

  bool get isSuccess => error == null;
}


// ===============================
// 관리자 부서별 달력 API 모델
// ===============================

class AdminDeptCalendarRequest {
  final String approverId;
  final String month;

  AdminDeptCalendarRequest({
    required this.approverId,
    required this.month,
  });

  Map<String, dynamic> toJson() {
    return {
      'approver_id': approverId,
      'month': month,
    };
  }
}

class AdminDeptCalendarResponse {
  final String? error;
  final List<AdminMonthlyLeave> monthlyLeaves;

  AdminDeptCalendarResponse({
    this.error,
    required this.monthlyLeaves,
  });

  factory AdminDeptCalendarResponse.fromJson(Map<String, dynamic> json) {
    return AdminDeptCalendarResponse(
      error: json['error'] as String?,
      monthlyLeaves: (json['monthly_leaves'] as List?)
              ?.map((item) => AdminMonthlyLeave.fromJson(item))
              .toList() ??
          [],
    );
  }

  bool get isSuccess => error == null;
}


// ===============================
// 승인자 관련 모델
// ===============================

class Approver {
  final String approverId;
  final String approverName;
  final String jobPosition;
  final String department;

  Approver({
    required this.approverId,
    required this.approverName,
    required this.jobPosition,
    required this.department,
  });

  factory Approver.fromJson(Map<String, dynamic> json) {
    return Approver(
      approverId: json['approver_id'] ?? '',
      approverName: json['approver_name'] ?? '',
      jobPosition: json['job_position'] ?? '',
      department: json['department'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'approver_id': approverId,
      'approver_name': approverName,
      'job_position': jobPosition,
      'department': department,
    };
  }
}

class ApproverListResponse {
  final List<Approver> approverList;
  final String? error;

  ApproverListResponse({
    required this.approverList,
    this.error,
  });

  factory ApproverListResponse.fromJson(Map<String, dynamic> json) {
    return ApproverListResponse(
      error: json['error'] as String?,
      approverList: (json['approver_list'] as List?)
              ?.map((item) => Approver.fromJson(item))
              .toList() ??
          [],
    );
  }

  bool get isSuccess => error == null;
}

// ===============================
// 공휴일 API 모델
// ===============================

class Holiday {
  final String dateName;
  final DateTime locDate;

  Holiday({
    required this.dateName,
    required this.locDate,
  });

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      dateName: json['date_name'] as String? ?? '',
      locDate: DateTime.parse(json['loc_date'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date_name': dateName,
      'loc_date': locDate.toIso8601String(),
    };
  }
}

class HolidayResponse {
  final String? error;
  final List<Holiday> holidays;

  HolidayResponse({
    this.error,
    required this.holidays,
  });

  factory HolidayResponse.fromJson(Map<String, dynamic> json) {
    return HolidayResponse(
      error: json['error'] as String?,
      holidays: (json['holidays'] as List?)
              ?.map((item) => Holiday.fromJson(item))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'error': error,
      'holidays': holidays.map((item) => item.toJson()).toList(),
    };
  }

  bool get isSuccess => error == null;
}

