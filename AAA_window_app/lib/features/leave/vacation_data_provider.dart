import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 휴가 현황 데이터 모델
class LeaveStatusData {
  final String leaveType;
  final double totalDays;
  final double remainDays;

  const LeaveStatusData({
    required this.leaveType,
    required this.totalDays,
    required this.remainDays,
  });

  factory LeaveStatusData.fromJson(Map<String, dynamic> json) {
    return LeaveStatusData(
      leaveType: json['leave_type'] as String? ?? '',
      totalDays: (json['total_days'] as num?)?.toDouble() ?? 0.0,
      remainDays: (json['remain_days'] as num?)?.toDouble() ?? 0.0,
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

/// 승인자 정보 모델
class ApprovalLineData {
  final String approverName;
  final String approverId;
  final int approvalSeq;

  const ApprovalLineData({
    required this.approverName,
    required this.approverId,
    required this.approvalSeq,
  });

  factory ApprovalLineData.fromJson(Map<String, dynamic> json) {
    return ApprovalLineData(
      approverName: json['approver_name'] as String? ?? '',
      approverId: json['approver_id'] as String? ?? '',
      approvalSeq: json['approval_seq'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'approver_name': approverName,
      'approver_id': approverId,
      'approval_seq': approvalSeq,
    };
  }
}

/// 참조자 정보 모델 (새로운 구조)
class CcPersonData {
  final String name;
  final String userId;

  const CcPersonData({
    required this.name,
    required this.userId,
  });

  factory CcPersonData.fromJson(Map<String, dynamic> json) {
    return CcPersonData(
      name: json['name'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'user_id': userId,
    };
  }
}

/// 휴가 신청 데이터 모델
class VacationRequestData {
  final String? userId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? reason;
  final List<CcPersonData>? ccList;
  final List<ApprovalLineData>? approvalLine;
  final String? leaveType;
  final String? halfDaySlot;
  final List<LeaveStatusData>? leaveStatus;
  final Map<String, List<Map<String, dynamic>>>?
      organizationData; // 조직도 데이터 (기존 유지)

  const VacationRequestData({
    this.userId,
    this.startDate,
    this.endDate,
    this.reason,
    this.ccList,
    this.approvalLine,
    this.leaveType,
    this.halfDaySlot,
    this.leaveStatus,
    this.organizationData,
  });

  /// 빈 VacationRequestData 생성
  factory VacationRequestData.empty() {
    return const VacationRequestData();
  }

  VacationRequestData copyWith({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
    List<CcPersonData>? ccList,
    List<ApprovalLineData>? approvalLine,
    String? leaveType,
    String? halfDaySlot,
    List<LeaveStatusData>? leaveStatus,
    Map<String, List<Map<String, dynamic>>>? organizationData,
  }) {
    return VacationRequestData(
      userId: userId ?? this.userId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      ccList: ccList ?? this.ccList,
      approvalLine: approvalLine ?? this.approvalLine,
      leaveType: leaveType ?? this.leaveType,
      halfDaySlot: halfDaySlot ?? this.halfDaySlot,
      leaveStatus: leaveStatus ?? this.leaveStatus,
      organizationData: organizationData ?? this.organizationData,
    );
  }

  /// 서버에서 받은 JSON 데이터로부터 VacationRequestData 생성
  factory VacationRequestData.fromJson(Map<String, dynamic> json) {
    // 참조자 목록 파싱
    List<CcPersonData>? ccList;
    if (json['cc_list'] is List) {
      ccList = (json['cc_list'] as List)
          .map((item) => CcPersonData.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // 승인자 목록 파싱
    List<ApprovalLineData>? approvalLine;
    if (json['approval_line'] is List) {
      approvalLine = (json['approval_line'] as List)
          .map(
              (item) => ApprovalLineData.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // 휴가 현황 파싱
    List<LeaveStatusData>? leaveStatus;
    if (json['leave_status'] is List) {
      leaveStatus = (json['leave_status'] as List)
          .map((item) => LeaveStatusData.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // 조직도 데이터 파싱 (기존 구조 유지)
    Map<String, List<Map<String, dynamic>>>? organizationData;
    if (json['organization_data'] != null) {
      final orgData = json['organization_data'] as Map<String, dynamic>;
      organizationData = {};
      orgData.forEach((key, value) {
        if (value is List) {
          organizationData![key] = List<Map<String, dynamic>>.from(
              value.map((item) => Map<String, dynamic>.from(item as Map)));
        }
      });
    }

    return VacationRequestData(
      userId: json['user_id'] as String?,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'])
          : null,
      endDate:
          json['end_date'] != null ? DateTime.tryParse(json['end_date']) : null,
      reason: json['reason'] as String?,
      ccList: ccList,
      approvalLine: approvalLine,
      leaveType: json['leave_type'] as String?,
      halfDaySlot: json['half_day_slot'] as String?,
      leaveStatus: leaveStatus,
      organizationData: organizationData,
    );
  }

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'reason': reason,
      'cc_list': ccList?.map((cc) => cc.toJson()).toList(),
      'approval_line':
          approvalLine?.map((approval) => approval.toJson()).toList(),
      'leave_type': leaveType,
      'half_day_slot': halfDaySlot,
      'leave_status': leaveStatus?.map((status) => status.toJson()).toList(),
      'organization_data': organizationData,
    };
  }

  /// 데이터가 비어있는지 확인
  bool get isEmpty {
    return leaveType == null &&
        startDate == null &&
        endDate == null &&
        reason == null &&
        (approvalLine == null || approvalLine!.isEmpty) &&
        (ccList == null || ccList!.isEmpty);
  }

  /// 필수 데이터가 모두 있는지 확인
  bool get hasRequiredData {
    return leaveType != null &&
        startDate != null &&
        endDate != null &&
        reason != null &&
        reason!.isNotEmpty &&
        approvalLine != null &&
        approvalLine!.isNotEmpty;
  }
}

/// 휴가 신청 데이터 상태 관리
class VacationDataNotifier extends StateNotifier<VacationRequestData> {
  VacationDataNotifier() : super(const VacationRequestData());

  /// 서버에서 받은 JSON 데이터로 상태 업데이트
  void updateFromJson(Map<String, dynamic> json) {
    print('📝 휴가 데이터 업데이트: $json');
    try {
      final vacationData = VacationRequestData.fromJson(json);
      state = vacationData;
      print('✅ 휴가 데이터 업데이트 완료: ${vacationData.toJson()}');
    } catch (e) {
      print('❌ 휴가 데이터 파싱 실패: $e');
    }
  }

  /// 특정 필드 업데이트
  void updateField(String field, dynamic value) {
    switch (field) {
      case 'vacation_type':
        state = state.copyWith(leaveType: value as String?);
        break;
      case 'start_date':
        DateTime? date;
        if (value is String) {
          date = DateTime.tryParse(value);
        } else if (value is DateTime) {
          date = value;
        }
        state = state.copyWith(startDate: date);
        break;
      case 'end_date':
        DateTime? date;
        if (value is String) {
          date = DateTime.tryParse(value);
        } else if (value is DateTime) {
          date = value;
        }
        state = state.copyWith(endDate: date);
        break;
      case 'reason':
        state = state.copyWith(reason: value as String?);
        break;
      case 'approver':
        // approvalLine은 복잡한 구조이므로 단순 업데이트 불가
        break;
      case 'cc_list':
        List<CcPersonData>? ccList;
        if (value is List) {
          ccList = value
              .map(
                  (item) => CcPersonData.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        state = state.copyWith(ccList: ccList);
        break;
      case 'half_day_type':
        state = state.copyWith(halfDaySlot: value as String?);
        break;
      case 'use_next_year_leave':
        // VacationRequestData에 해당 필드가 없으므로 무시
        break;
      case 'leave_status':
        List<LeaveStatusData>? leaveStatus;
        if (value is List) {
          leaveStatus = value
              .map((item) =>
                  LeaveStatusData.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        state = state.copyWith(leaveStatus: leaveStatus);
        break;
      case 'organization_data':
        Map<String, List<Map<String, dynamic>>>? organizationData;
        if (value is Map<String, dynamic>) {
          organizationData = {};
          value.forEach((key, val) {
            if (val is List) {
              organizationData![key] = List<Map<String, dynamic>>.from(
                  val.map((item) => Map<String, dynamic>.from(item as Map)));
            }
          });
        }
        state = state.copyWith(organizationData: organizationData);
        break;
      case 'default_approver':
        // VacationRequestData에 해당 필드가 없으므로 무시
        break;
    }
  }

  /// 상태 초기화
  void clear() {
    state = const VacationRequestData();
  }
}

/// 휴가 신청 데이터 Provider
final vacationDataProvider =
    StateNotifierProvider<VacationDataNotifier, VacationRequestData>((ref) {
  return VacationDataNotifier();
});
