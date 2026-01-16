// 휴가신청 관련 모델 정의

// 휴가신청 내역 데이터 모델
class LeaveRequestHistory {
  final String id;
  final String applicantName;
  final String department;
  final String vacationType;
  final DateTime startDate;
  final DateTime endDate;
  final double days;
  final String reason;
  final LeaveRequestStatus status;
  final DateTime submittedDate;
  final String? approverComment;

  LeaveRequestHistory({
    required this.id,
    required this.applicantName,
    required this.department,
    required this.vacationType,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.reason,
    required this.status,
    required this.submittedDate,
    this.approverComment,
  });
}

// 휴가신청 상태 enum
enum LeaveRequestStatus {
  pending('대기중', 0xFF2196F3),
  approved('승인됨', 0xFF4CAF50),
  rejected('반려됨', 0xFFF44336),
  cancelled('취소됨', 0xFF9E9E9E),
  cancelRequested('🔄 취소 대기', 0xFFFF6B00); // 진한 오렌지색 + 아이콘

  const LeaveRequestStatus(this.label, this.colorValue);
  final String label;
  final int colorValue;
}

// 부서원 정보 모델
class DepartmentMember {
  final String id;
  final String name;
  final String department;
  final String position;
  final String? profileImageUrl;

  DepartmentMember({
    required this.id,
    required this.name,
    required this.department,
    required this.position,
    this.profileImageUrl,
  });
}

// 휴가 잔여량 정보 모델
class LeaveBalance {
  final String type;
  final double total;
  final double used;
  final double remaining;

  LeaveBalance({
    required this.type,
    required this.total,
    required this.used,
    required this.remaining,
  });
}

// 부서 휴가 현황 뷰 타입
enum DepartmentLeaveViewType {
  personal('내 휴가만'),
  department('부서 전체');

  const DepartmentLeaveViewType(this.label);
  final String label;
}

// 관리자용 부서원 휴가 현황 모델
class EmployeeLeaveStatus {
  final int id;
  final String status;
  final String name;
  final String department;
  final String jobPosition;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String halfDaySlot;
  final double totalDays;
  final double usedDays;
  final double remainDays;
  final int workdaysCount;
  final DateTime requestedDate;
  final String reason;
  final String joinDate;

  EmployeeLeaveStatus({
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
    required this.usedDays,
    required this.remainDays,
    required this.workdaysCount,
    required this.requestedDate,
    required this.reason,
    required this.joinDate,
  });

  factory EmployeeLeaveStatus.fromJson(Map<String, dynamic> json) {
    return EmployeeLeaveStatus(
      id: json['id'] ?? 0,
      status: json['status'] ?? '',
      name: json['name'] ?? '',
      department: json['department'] ?? '',
      jobPosition: json['job_position'] ?? '',
      leaveType: json['leave_type'] ?? '',
      startDate:
          DateTime.tryParse(json['start_date'] ?? '') ?? DateTime(1, 1, 1),
      endDate: DateTime.tryParse(json['end_date'] ?? '') ?? DateTime(1, 1, 1),
      halfDaySlot: json['half_day_slot'] ?? '',
      totalDays: (json['total_days'] ?? 0).toDouble(),
      usedDays: (json['used_days'] ?? 0).toDouble(),
      remainDays: (json['remain_days'] ?? 0).toDouble(),
      workdaysCount: json['workdays_count'] ?? 0,
      requestedDate:
          DateTime.tryParse(json['requested_date'] ?? '') ?? DateTime(1, 1, 1),
      reason: json['reason'] ?? '',
      joinDate: json['join_date'] ?? '',
    );
  }
}

// 부서원 휴가 현황 API 응답 모델
class DepartmentLeaveStatusResponse {
  final List<EmployeeLeaveStatus> employees;
  final String? error;

  DepartmentLeaveStatusResponse({
    required this.employees,
    this.error,
  });

  factory DepartmentLeaveStatusResponse.fromJson(Map<String, dynamic> json) {
    return DepartmentLeaveStatusResponse(
      employees: (json['employees'] as List<dynamic>?)
              ?.map((e) =>
                  EmployeeLeaveStatus.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      error: json['error'],
    );
  }
}

// ===============================
// 휴가 부여 상신 관련 모델
// ===============================

/// 휴가 부여 상신 요청 모델
///
/// 참고:
/// - `CcPerson` 타입은 `lib/models/leave_management_models.dart` 에 정의되어 있음.
class LeaveGrantRequest {
  final String userId; // 로그인한 유저의 ID
  final String department;
  final String name;
  final String jobPosition;
  final String status;
  final String approvalDate;
  final String approvalType;
  final List<ApprovalLineItem> approvalLine;
  final String title;
  final String leaveType;
  final String? startDate;
  final String? endDate;
  final String? halfDaySlot;
  final double grantDays;
  final String reason;
  final List<AttachmentItem> attachmentsList;

  /// 참조자 목록 (옵션)
  /// - 서버에는 `cc_list` 필드로 전달
  /// - 휴가 상신(`LeaveRequestRequest`)의 `ccList` 구조와 맞추기 위해 `CcPerson` 사용
  /// - `CcPerson` 타입은 `lib/models/leave_management_models.dart` 에 정의되어 있음
  final List<dynamic /* CcPerson */ >? ccList;

  LeaveGrantRequest({
    required this.userId,
    required this.department,
    required this.name,
    required this.jobPosition,
    required this.status,
    required this.approvalDate,
    required this.approvalType,
    required this.approvalLine,
    required this.title,
    required this.leaveType,
    this.startDate,
    this.endDate,
    this.halfDaySlot,
    required this.grantDays,
    required this.reason,
    required this.attachmentsList,
    this.ccList,
  });

  Map<String, dynamic> toJson() {
    return {
      'department': department,
      'user_id': userId, // 로그인한 유저의 ID
      'approval_date': approvalDate,
      'approval_type': approvalType,
      'approval_line': approvalLine.map((item) => item.toJson()).toList(),
      'title': title,
      'leave_type': leaveType,
      'grant_days': grantDays,
      'reason': reason,
      'attachments_list': attachmentsList.map((item) => item.toJson()).toList(),
      'start_date': startDate,
      'end_date': endDate,
      'half_day_slot': halfDaySlot,
      if (ccList != null && ccList!.isNotEmpty)
        'cc_list': ccList!
            .map((cc) =>
                cc is Map<String, dynamic> ? cc : (cc as dynamic).toJson())
            .toList(),
    };
  }
}

/// 결재선 아이템 모델
///
/// 서버 Go 코드에서 ApprovalLine.approval_line.cc_list 타입이 handlers.CCObj 이므로
/// 여기서는 Map<String, dynamic> 리스트로 표현해 준다.
class ApprovalLineItem {
  final String userId;
  final String department;
  final String jobPosition;
  final String approverId;
  final String nextApproverId;
  final int approvalSeq;
  final String approverName;
  final List<Map<String, dynamic>>? ccList;

  ApprovalLineItem({
    required this.userId,
    required this.department,
    required this.jobPosition,
    required this.approverId,
    required this.nextApproverId,
    required this.approvalSeq,
    required this.approverName,
    this.ccList,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'department': department,
      'job_position': jobPosition,
      'approver_id': approverId,
      'next_approver_id': nextApproverId,
      'approval_seq': approvalSeq,
      'approver_name': approverName,
      'cc_list': ccList,
    };
  }
}

/// 첨부파일 아이템 모델
class AttachmentItem {
  final String fileName;
  final int size;
  final String url;
  final String prefix;

  AttachmentItem({
    required this.fileName,
    required this.size,
    required this.url,
    required this.prefix,
  });

  Map<String, dynamic> toJson() {
    return {
      'file_name': fileName,
      'size': size,
      'url': url,
      'prefix': prefix,
    };
  }
}

/// 휴가 부여 상신 응답 모델
class LeaveGrantResponse {
  final String? error;
  final int? id;

  LeaveGrantResponse({
    this.error,
    this.id,
  });

  factory LeaveGrantResponse.fromJson(Map<String, dynamic> json) {
    return LeaveGrantResponse(
      error: json['error'],
      id: json['id'],
    );
  }
}

// ===============================
// 휴가 부여 내역 조회 모델
// ===============================

class LeaveGrantRequestItem {
  final int id;
  final String leaveType;
  final String title;
  final String status;
  final DateTime? approvalDate;
  final DateTime? procDate;
  final String reason;
  final double grantDays;
  final String comment;
  final dynamic attachmentsList;
  final int isManager;

  LeaveGrantRequestItem({
    required this.id,
    required this.leaveType,
    required this.title,
    required this.status,
    required this.approvalDate,
    required this.procDate,
    required this.reason,
    required this.grantDays,
    required this.comment,
    required this.attachmentsList,
    required this.isManager,
  });

  factory LeaveGrantRequestItem.fromJson(Map<String, dynamic> json) {
    return LeaveGrantRequestItem(
      id: json['id'] ?? 0,
      leaveType: json['leave_type'] ?? '',
      title: json['title'] ?? '',
      status: json['status'] ?? '',
      approvalDate: _parseOptionalDate(json['approval_date']),
      procDate: _parseOptionalDate(json['proc_date']),
      reason: json['reason'] ?? '',
      grantDays: (json['grant_days'] ?? 0).toDouble(),
      comment: json['comment'] ?? '',
      attachmentsList: json['attachments_list'],
      isManager: json['is_manager'] ?? 0,
    );
  }

  static DateTime? _parseOptionalDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}

class LeaveGrantRequestListResponse {
  final List<LeaveGrantRequestItem> leaveGrants;
  final String? error;

  LeaveGrantRequestListResponse({
    required this.leaveGrants,
    this.error,
  });

  bool get isSuccess => error == null;

  factory LeaveGrantRequestListResponse.fromJson(Map<String, dynamic> json) {
    return LeaveGrantRequestListResponse(
      leaveGrants: (json['leave_grants'] as List<dynamic>?)
              ?.map((e) =>
                  LeaveGrantRequestItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      error: json['error'],
    );
  }
}

/// 내년 정기휴가 상태 모델
class NextYearLeaveStatus {
  final String leaveType;
  final double totalDays;
  final double remainDays;

  NextYearLeaveStatus({
    required this.leaveType,
    required this.totalDays,
    required this.remainDays,
  });

  factory NextYearLeaveStatus.fromJson(Map<String, dynamic> json) {
    return NextYearLeaveStatus(
      leaveType: json['leave_type'] as String,
      totalDays: (json['total_days'] as num).toDouble(),
      remainDays: (json['remain_days'] as num).toDouble(),
    );
  }
}

/// 내년 정기휴가 조회 응답 모델
class NextYearLeaveStatusResponse {
  final String? error;
  final List<NextYearLeaveStatus> leaveStatus;

  NextYearLeaveStatusResponse({
    this.error,
    required this.leaveStatus,
  });

  factory NextYearLeaveStatusResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> leaveStatusList = json['leave_status'] ?? [];
    return NextYearLeaveStatusResponse(
      error: json['error'],
      leaveStatus: leaveStatusList
          .map((item) =>
              NextYearLeaveStatus.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
