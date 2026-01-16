import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:ASPN_AI_AGENT/core/config/app_config.dart';
import 'package:ASPN_AI_AGENT/features/leave/leave_models.dart';
import 'package:ASPN_AI_AGENT/models/leave_management_models.dart';

/// 휴가 관련 API 서비스
///
/// **중요**: 모든 API 엔드포인트는 AppConfig.baseUrl을 사용합니다.
/// - 개발 환경: ${AppConfig.baseUrl}
/// - 운영 환경: ${AppConfig.baseUrl}
///
/// **API 카테고리**:
/// 1. 휴가관리 화면 API - 사용자 휴가 조회/관리
/// 2. 휴가 신청/취소 API - 휴가 상신 및 취소 처리
/// 3. 관리자용 API - 승인/반려 처리
///
/// **에러 처리**:
/// - 성공: 해당 Response 객체 반환
/// - 실패: Response 객체의 error 필드에 메시지 포함
class LeaveApiService {
  static String get serverUrl => AppConfig.baseUrl;

  // ===============================
  // 휴가관리 화면 API
  // ===============================

  /// 휴가관리 데이터 조회 (휴가관리 화면용)
  ///
  /// **반환 데이터**:
  /// - leaveStatus: 휴가 현황 (총일수, 잔여일수)
  /// - approvalStatus: 결재 진행 현황 (대기/승인/반려 건수)
  /// - yearlyDetails: 연도별 휴가 내역
  /// - yearlyWholeStatus: 월별 사용 현황
  /// - monthlyLeaves: 이번 달 휴가 일정
  static Future<LeaveManagementData> getLeaveManagement(String userId) async {
    final url = Uri.parse('$serverUrl/leave/user/management');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'user_id': userId,
    });

    try {
      print('휴가관리 데이터 API 요청: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('휴가관리 데이터 응답 상태 코드: ${response.statusCode}');
      print('휴가관리 데이터 응답: ${response.body}');

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        // 🔍 [CANCEL_DEBUG] 서버 응답 상세 로그
        print('\n🔍 ========== [CANCEL_DEBUG] 서버 응답 분석 시작 ==========');
        final yearlyDetails = data['yearlyDetails'] as List<dynamic>?;
        if (yearlyDetails != null && yearlyDetails.isNotEmpty) {
          print('🔍 [CANCEL_DEBUG] yearlyDetails 개수: ${yearlyDetails.length}개');
          for (int i = 0; i < yearlyDetails.length; i++) {
            final detail = yearlyDetails[i] as Map<String, dynamic>;
            print('\n🔍 [CANCEL_DEBUG] === 휴가 항목 #${i + 1} ===');
            print('🔍 [CANCEL_DEBUG]   - id: ${detail['id']}');
            print('🔍 [CANCEL_DEBUG]   - leave_type: ${detail['leave_type']}');
            print('🔍 [CANCEL_DEBUG]   - status: ${detail['status']}');
            print(
                '🔍 [CANCEL_DEBUG]   - is_cancel: ${detail['is_cancel']} (타입: ${detail['is_cancel'].runtimeType})');
            print('🔍 [CANCEL_DEBUG]   - start_date: ${detail['start_date']}');
            if (detail['is_cancel'] == 1) {
              print('🔍 [CANCEL_DEBUG]   ⭐⭐⭐ 취소상신 건 발견! ⭐⭐⭐');
            }
          }
        } else {
          print('🔍 [CANCEL_DEBUG] yearlyDetails가 비어있거나 null입니다.');
        }
        print('🔍 ========== [CANCEL_DEBUG] 서버 응답 분석 종료 ==========\n');

        return LeaveManagementData.fromJson(data);
      } else {
        throw Exception('휴가관리 데이터 로드 실패. 상태 코드: ${response.statusCode}');
      }
    } catch (e) {
      print('휴가관리 데이터 API 호출 실패: $e');
      throw Exception('휴가관리 데이터 로드 실패: $e');
    }
  }

  /// 월별 달력 조회 (휴가 일정 달력 월 변경용)
  static Future<MonthlyCalendarResponse> getMonthlyCalendar({
    required MonthlyCalendarRequest request,
  }) async {
    final url = Uri.parse('$serverUrl/leave/user/management/myCalendar');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode(request.toJson());

    try {
      print('월별 달력 데이터 API 요청: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('월별 달력 데이터 응답 상태 코드: ${response.statusCode}');
      print('월별 달력 데이터 응답: ${response.body}');

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return MonthlyCalendarResponse.fromJson(data);
      } else {
        throw Exception('월별 달력 데이터 로드 실패. 상태 코드: ${response.statusCode}');
      }
    } catch (e) {
      print('월별 달력 데이터 API 호출 실패: $e');
      throw Exception('월별 달력 데이터 로드 실패: $e');
    }
  }

  /// 연도별 휴가 내역 조회 (개인별 휴가 내역 연도 필터용)
  static Future<YearlyLeaveResponse> getYearlyLeaveData({
    required YearlyLeaveRequest request,
  }) async {
    final url = Uri.parse('$serverUrl/leave/user/management/yearly');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode(request.toJson());

    try {
      print('연도별 휴가 데이터 API 요청: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('연도별 휴가 데이터 응답 상태 코드: ${response.statusCode}');
      print('연도별 휴가 데이터 응답: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return YearlyLeaveResponse.fromJson(data);
      } else {
        // 서버 에러인 경우에도 응답 파싱 시도
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          return YearlyLeaveResponse.fromJson(data);
        } catch (e) {
          return YearlyLeaveResponse(
            error: '연도별 휴가 데이터 조회에 실패했습니다. 상태 코드: ${response.statusCode}',
            yearlyDetails: [],
            yearlyWholeStatus: [],
          );
        }
      }
    } catch (e) {
      print('연도별 휴가 데이터 API 호출 실패: $e');
      return YearlyLeaveResponse(
        error: '연도별 휴가 데이터 조회에 실패했습니다: $e',
        yearlyDetails: [],
        yearlyWholeStatus: [],
      );
    }
  }

  // ===============================
  // 대시보드 통합 API
  // ===============================

  /// 내 휴가 현황 조회
  static Future<List<LeaveBalance>> getLeaveBalance({
    required String userId,
  }) async {
    final url = Uri.parse('$serverUrl/api/leave/balance/$userId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> balanceList = data['leaveBalances'] ?? [];

        return balanceList
            .map((balance) => LeaveBalance(
                  type: balance['type'] ?? '',
                  total: balance['total'] ?? 0,
                  used: balance['used'] ?? 0,
                  remaining: balance['remaining'] ?? 0,
                ))
            .toList();
      } else {
        throw Exception(
            'Failed to load leave balance. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get leave balance: $e');
    }
  }

  /// 휴가 신청 내역 조회
  static Future<List<LeaveRequestHistory>> getLeaveRequestHistory({
    required String userId,
    required int year,
    LeaveRequestStatus? status,
  }) async {
    final url = Uri.parse('$serverUrl/api/leave/requests/$userId');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'year': year,
      if (status != null) 'status': status.name,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> requestList = data['requests'] ?? [];

        return requestList
            .map((request) => LeaveRequestHistory(
                  id: request['id'] ?? '',
                  applicantName: request['applicantName'] ?? '',
                  department: request['department'] ?? '',
                  vacationType: request['vacationType'] ?? '',
                  startDate: DateTime.parse(request['startDate']),
                  endDate: DateTime.parse(request['endDate']),
                  days: (request['days'] ?? 0).toDouble(),
                  reason: request['reason'] ?? '',
                  status: LeaveRequestStatus.values.firstWhere(
                    (s) => s.name == request['status'],
                    orElse: () => LeaveRequestStatus.pending,
                  ),
                  submittedDate: DateTime.parse(request['submittedDate']),
                  approverComment: request['approverComment'],
                ))
            .toList();
      } else {
        throw Exception(
            'Failed to load leave requests. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get leave requests: $e');
    }
  }

  /// 부서원 목록 조회
  static Future<List<DepartmentMember>> getDepartmentMembers({
    required String userId,
  }) async {
    final url = Uri.parse('$serverUrl/api/leave/department/members');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'userId': userId});

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> memberList = data['members'] ?? [];

        return memberList
            .map((member) => DepartmentMember(
                  id: member['id'] ?? '',
                  name: member['name'] ?? '',
                  department: member['department'] ?? '',
                  position: member['position'] ?? '',
                  profileImageUrl: member['profileImageUrl'],
                ))
            .toList();
      } else {
        throw Exception(
            'Failed to load department members. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get department members: $e');
    }
  }

  /// 부서 전체 휴가 내역 조회
  static Future<Map<String, List<LeaveRequestHistory>>>
      getDepartmentLeaveHistory({
    required String userId,
    required int year,
    String? memberId,
  }) async {
    final url = Uri.parse('$serverUrl/api/leave/department/history');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'userId': userId,
      'year': year,
      if (memberId != null) 'memberId': memberId,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final Map<String, dynamic> historyMap = data['departmentHistory'] ?? {};

        final Map<String, List<LeaveRequestHistory>> result = {};

        historyMap.forEach((memberId, requests) {
          if (requests is List) {
            result[memberId] = requests
                .map<LeaveRequestHistory>((request) => LeaveRequestHistory(
                      id: request['id'] ?? '',
                      applicantName: request['applicantName'] ?? '',
                      department: request['department'] ?? '',
                      vacationType: request['vacationType'] ?? '',
                      startDate: DateTime.parse(request['startDate']),
                      endDate: DateTime.parse(request['endDate']),
                      days: (request['days'] ?? 0).toDouble(),
                      reason: request['reason'] ?? '',
                      status: LeaveRequestStatus.values.firstWhere(
                        (s) => s.name == request['status'],
                        orElse: () => LeaveRequestStatus.pending,
                      ),
                      submittedDate: DateTime.parse(request['submittedDate']),
                      approverComment: request['approverComment'],
                    ))
                .toList();
          }
        });

        return result;
      } else {
        throw Exception(
            'Failed to load department history. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get department history: $e');
    }
  }

  /// 휴가 관리 대장 데이터 조회
  static Future<List<Map<String, dynamic>>> getLeaveManagementTable({
    required String userId,
    required int year,
  }) async {
    final url = Uri.parse('$serverUrl/api/leave/management-table');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'userId': userId,
      'year': year,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> tableData = data['managementTable'] ?? [];

        return tableData
            .map<Map<String, dynamic>>((item) => {
                  'leaveType': item['leaveType'] ?? '',
                  'allowedDays': item['allowedDays'] ?? 0,
                  'usedByMonth':
                      List<int>.from(item['usedByMonth'] ?? List.filled(12, 0)),
                  'totalUsed': item['totalUsed'] ?? 0,
                })
            .toList();
      } else {
        throw Exception(
            'Failed to load management table. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get management table: $e');
    }
  }

  // ===============================
  // 휴가 신청/수정/취소 API
  // ===============================

  /// 휴가 상신 (새로운 API)
  static Future<LeaveRequestResponse> submitLeaveRequestNew({
    required LeaveRequestRequest request,
  }) async {
    final url = Uri.parse('$serverUrl/leave/user/request');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode(request.toJson());

    try {
      // 상세 요청 로그 (디버깅용)
      final prettyBody = const JsonEncoder.withIndent('  ')
          .convert(jsonDecode(body) as Map<String, dynamic>);
      final timestamp = DateTime.now().toIso8601String();
      print('\n🏖️ [LeaveApiService] ===== 휴가 상신 API 요청 =====');
      print('  - URL: $url');
      print('  - Headers: $headers');
      print('  - Time: $timestamp');
      print('  - user_id: ${request.userId}');
      print(
          '  - approval_line: ${request.approvalLine.map((a) => '${a.approverName}(seq:${a.approvalSeq})').join(' -> ')}');
      print('  - leave_type: ${request.leaveType}');
      print('  - start_date: ${request.startDate.toIso8601String()}');
      print('  - end_date: ${request.endDate.toIso8601String()}');
      print('  - cc_list.length: ${request.ccList.length}');
      print('  - reason.length: ${request.reason.length}');
      print('  - half_day_slot: ${request.halfDaySlot}');
      print('  - is_next_year: ${request.isNextYear}');
      print('  - Body (raw): $body');
      print('  - Body (pretty):\n$prettyBody');
      final response = await http.post(url, headers: headers, body: body);
      print('휴가 상신 응답 상태 코드: ${response.statusCode}');
      print('휴가 상신 응답: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return LeaveRequestResponse.fromJson(data);
      } else {
        // 서버 에러인 경우에도 응답 파싱 시도
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          return LeaveRequestResponse.fromJson(data);
        } catch (e) {
          return LeaveRequestResponse(
              error: '휴가 상신에 실패했습니다. 상태 코드: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('휴가 상신 API 호출 실패: $e');
      return LeaveRequestResponse(error: '휴가 상신에 실패했습니다: $e');
    }
  }

  /// 휴가 상신 (Raw Body 전달 - cc_list를 {name, user_id}로 보낼 때 사용)
  static Future<LeaveRequestResponse> submitLeaveRequestNewBody(
      Map<String, dynamic> bodyMap) async {
    final url = Uri.parse('$serverUrl/leave/user/request');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode(bodyMap);

    try {
      // 상세 요청 로그
      final prettyBody = const JsonEncoder.withIndent('  ').convert(bodyMap);
      print('\n🏖️ [LeaveApiService] ===== 휴가 상신 API 요청 (Raw Body) =====');
      print('  - URL: $url');
      print('  - Headers: $headers');
      print('  - Request Body:\n$prettyBody');

      final response = await http.post(url, headers: headers, body: body);
      print('  - Response Status: ${response.statusCode}');
      print('  - Response Body: ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return LeaveRequestResponse.fromJson(data);
      } else {
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          return LeaveRequestResponse.fromJson(data);
        } catch (e) {
          return LeaveRequestResponse(
              error: '휴가 상신에 실패했습니다. 상태 코드: ${response.statusCode}');
        }
      }
    } catch (e) {
      return LeaveRequestResponse(error: '휴가 상신에 실패했습니다: $e');
    }
  }

  /// 휴가 신청 (기존 API - 호환성 유지)
  static Future<Map<String, dynamic>> submitLeaveRequest({
    required String userId,
    required String vacationType,
    required DateTime startDate,
    required DateTime endDate,
    required double days,
    required String reason,
  }) async {
    final url = Uri.parse('$serverUrl/api/leave/requests');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'userId': userId,
      'vacationType': vacationType,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'days': days,
      'reason': reason,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data;
      } else {
        throw Exception(
            'Failed to submit leave request. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to submit leave request: $e');
    }
  }

  /// 휴가 취소 (새로운 API)
  static Future<LeaveCancelResponse> cancelLeaveRequestNew({
    required LeaveCancelRequest request,
  }) async {
    final url = Uri.parse('$serverUrl/leave/user/cancel');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode(request.toJson());

    try {
      print('휴가 취소 API 요청: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('휴가 취소 응답 상태 코드: ${response.statusCode}');
      print('휴가 취소 응답: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return LeaveCancelResponse.fromJson(data);
      } else {
        // 서버 에러인 경우에도 응답 파싱 시도
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          return LeaveCancelResponse.fromJson(data);
        } catch (e) {
          return LeaveCancelResponse(
            error: '휴가 취소에 실패했습니다. 상태 코드: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      print('휴가 취소 API 호출 실패: $e');
      return LeaveCancelResponse(
        error: '휴가 취소에 실패했습니다: $e',
      );
    }
  }

  /// 휴가 신청 취소 (기존 API - 호환성 유지)
  static Future<Map<String, dynamic>> cancelLeaveRequest({
    required String requestId,
    required String userId,
  }) async {
    final url = Uri.parse('$serverUrl/api/leave/requests/$requestId/cancel');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'userId': userId});

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data;
      } else {
        throw Exception(
            'Failed to cancel leave request. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to cancel leave request: $e');
    }
  }

  // ===============================
  // 관리자용 API (admin_leave_approval_screen용)
  // ===============================

  /// 관리자용 승인 대기 목록 조회
  static Future<List<LeaveRequestHistory>> getPendingApprovals({
    required String managerId,
  }) async {
    final url = Uri.parse('$serverUrl/api/leave/admin/pending');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'managerId': managerId});

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> requestList = data['pendingRequests'] ?? [];

        return requestList
            .map((request) => LeaveRequestHistory(
                  id: request['id'] ?? '',
                  applicantName: request['applicantName'] ?? '',
                  department: request['department'] ?? '',
                  vacationType: request['vacationType'] ?? '',
                  startDate: DateTime.parse(request['startDate']),
                  endDate: DateTime.parse(request['endDate']),
                  days: (request['days'] ?? 0).toDouble(),
                  reason: request['reason'] ?? '',
                  status: LeaveRequestStatus.values.firstWhere(
                    (s) => s.name == request['status'],
                    orElse: () => LeaveRequestStatus.pending,
                  ),
                  submittedDate: DateTime.parse(request['submittedDate']),
                  approverComment: request['approverComment'],
                ))
            .toList();
      } else {
        throw Exception(
            'Failed to load pending approvals. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get pending approvals: $e');
    }
  }

  /// 전체 부서 휴가 현황 조회 (부서 휴가 현황 탭용)
  static Future<TotalCalendarResponse> getTotalCalendar({
    required String month,
  }) async {
    final url = Uri.parse('$serverUrl/leave/user/management/totalCalendar');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'month': month});

    try {
      print('부서 휴가 현황 API 요청: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('부서 휴가 현황 응답 상태 코드: ${response.statusCode}');
      print('부서 휴가 현황 응답: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return TotalCalendarResponse.fromJson(data);
      } else {
        throw Exception('부서 휴가 현황 로드 실패. 상태 코드: ${response.statusCode}');
      }
    } catch (e) {
      print('부서 휴가 현황 API 호출 실패: $e');
      throw Exception('부서 휴가 현황 로드 실패: $e');
    }
  }

  /// 관리자용 부서원 휴가 현황 조회 (관리자 사이드바용)
  static Future<DepartmentLeaveStatusResponse> getDepartmentLeaveStatus({
    required String approverId,
  }) async {
    final url = Uri.parse('$serverUrl/leave/admin/status');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'approver_id': approverId,
    });

    try {
      print('부서원 휴가 현황 API 요청: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('부서원 휴가 현황 응답 상태 코드: ${response.statusCode}');
      print('부서원 휴가 현황 응답: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return DepartmentLeaveStatusResponse.fromJson(data);
      } else {
        // 서버 에러인 경우에도 응답 파싱 시도
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          return DepartmentLeaveStatusResponse.fromJson(data);
        } catch (e) {
          return DepartmentLeaveStatusResponse(
            employees: [],
            error: '부서원 휴가 현황 조회에 실패했습니다. 상태 코드: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      print('부서원 휴가 현황 API 호출 실패: $e');
      return DepartmentLeaveStatusResponse(
        employees: [],
        error: '부서원 휴가 현황 조회에 실패했습니다: $e',
      );
    }
  }

  /// 내년 정기휴가 조회 API
  static Future<NextYearLeaveStatusResponse> getNextYearLeaveStatus({
    required String userId,
  }) async {
    final url = Uri.parse('$serverUrl/leave/user/management/nextYear');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'user_id': userId,
    });

    try {
      print('📅 [LeaveApiService] 내년 정기휴가 조회 API 요청 시작');
      print('📅 [LeaveApiService] URL: $url');
      print('📅 [LeaveApiService] Request Body: $body');

      final response = await http.post(url, headers: headers, body: body);

      print('📅 [LeaveApiService] 응답 상태 코드: ${response.statusCode}');
      print('📅 [LeaveApiService] 응답 바디: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return NextYearLeaveStatusResponse.fromJson(data);
      } else {
        // 서버 에러인 경우에도 응답 파싱 시도
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          return NextYearLeaveStatusResponse.fromJson(data);
        } catch (e) {
          return NextYearLeaveStatusResponse(
            leaveStatus: [],
            error: '내년 정기휴가 조회에 실패했습니다. 상태 코드: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      print('📅 [LeaveApiService] 내년 정기휴가 조회 API 호출 실패: $e');
      return NextYearLeaveStatusResponse(
        leaveStatus: [],
        error: '내년 정기휴가 조회에 실패했습니다: $e',
      );
    }
  }

  // ===============================
  // 휴가 부여 상신 API (전자결재 상신 모달용)
  // ===============================

  /// 휴가 부여 내역 조회 API
  static Future<LeaveGrantRequestListResponse> getGrantRequestList({
    required String userId,
  }) async {
    final url = Uri.parse('$serverUrl/leave/user/getGrantRequestList');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'user_id': userId,
    });

    try {
      print('📋 [LeaveApiService] 휴가 부여 내역 조회 API 요청: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('📋 [LeaveApiService] 휴가 부여 내역 응답 상태: ${response.statusCode}');
      print('📋 [LeaveApiService] 휴가 부여 내역 응답: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return LeaveGrantRequestListResponse.fromJson(data);
      } else {
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          return LeaveGrantRequestListResponse.fromJson(data);
        } catch (e) {
          return LeaveGrantRequestListResponse(
            leaveGrants: [],
            error: '휴가 부여 내역 조회에 실패했습니다. 상태 코드: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      print('📋 [LeaveApiService] 휴가 부여 내역 조회 API 호출 실패: $e');
      return LeaveGrantRequestListResponse(
        leaveGrants: [],
        error: '휴가 부여 내역 조회에 실패했습니다: $e',
      );
    }
  }

  /// 파일 URL 조회 API 호출
  ///
  /// [fileName] 파일명
  /// [prefix] 파일 경로 prefix
  /// [approvalType] 승인 타입
  /// [isDownload] 다운로드 여부 (0: 미리보기, 1: 다운로드)
  static Future<String?> getFileUrl({
    required String fileName,
    required String prefix,
    required String approvalType,
    int isDownload = 0,
  }) async {
    final url = Uri.parse('$serverUrl/api/getFileUrl');

    try {
      print('📎 [LeaveApiService] 파일 URL 조회 요청');
      print('  - file_name: $fileName');
      print('  - prefix: $prefix');
      print('  - approval_type: $approvalType');
      print('  - is_download: $isDownload');

      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({
        'file_name': fileName,
        'prefix': prefix,
        'approval_type': approvalType,
        'is_download': isDownload,
      });

      final response = await http.post(url, headers: headers, body: body);
      print('  - Status Code: ${response.statusCode}');
      print('  - Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = response.body.trim();
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data is Map<String, dynamic>) {
            return data['url'] as String? ?? data['file_url'] as String?;
          }
          if (data is String && data.isNotEmpty) return data;
        } catch (_) {
          if (responseBody.isNotEmpty) return responseBody;
        }
      } else {
        print('❌ [LeaveApiService] 파일 URL 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [LeaveApiService] 파일 URL 조회 중 오류 발생: $e');
    }
    return null;
  }

  /// 휴가 부여 상신 API
  static Future<LeaveGrantResponse> submitLeaveGrantRequest({
    required LeaveGrantRequest request,
  }) async {
    final url = Uri.parse('$serverUrl/leave/grant/request');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode(request.toJson());

    try {
      print('🏢 [LeaveApiService] 휴가 부여 상신 API 요청 시작');
      print('🏢 [LeaveApiService] URL: $url');
      print('🏢 [LeaveApiService] Headers: $headers');
      print('🏢 [LeaveApiService] Request Body: $body');

      final response = await http.post(url, headers: headers, body: body);

      print('🏢 [LeaveApiService] 응답 상태 코드: ${response.statusCode}');
      print('🏢 [LeaveApiService] 응답 헤더: ${response.headers}');
      print('🏢 [LeaveApiService] 응답 바디: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        print('🏢 [LeaveApiService] 파싱된 JSON 데이터: $data');
        print('🏢 [LeaveApiService] error: ${data['error']}');
        print('🏢 [LeaveApiService] id: ${data['id']}');

        final result = LeaveGrantResponse.fromJson(data);
        print('🏢 [LeaveApiService] 변환된 응답 객체: $result');
        return result;
      } else {
        // 서버 에러인 경우에도 응답 파싱 시도
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          print('🏢 [LeaveApiService] 서버 에러 응답 파싱: $data');
          return LeaveGrantResponse.fromJson(data);
        } catch (e) {
          print('🏢 [LeaveApiService] 서버 에러 응답 파싱 실패: $e');
          return LeaveGrantResponse(
            error: '휴가 부여 상신에 실패했습니다. 상태 코드: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      print('🏢 [LeaveApiService] 휴가 부여 상신 API 호출 실패: $e');
      return LeaveGrantResponse(
        error: '휴가 부여 상신에 실패했습니다: $e',
      );
    }
  }

  /// 휴가 부여 상신 (multipart/form-data)
  ///
  /// 채팅에서 트리거된 첨부파일(attachments_list)과 모달에서 직접 첨부한 파일(files)을
  /// 구분하여 전송합니다.
  static Future<LeaveGrantResponse> submitLeaveGrantRequestMultipart({
    required String userId,
    required String department,
    required String approvalDate,
    required String approvalType,
    required List<ApprovalLineItem> approvalLine,
    required String title,
    required String leaveType,
    required double grantDays,
    required String reason,
    required List<AttachmentItem> attachmentsList,
    String? startDate,
    String? endDate,
    String? halfDaySlot,
    List<CcPerson>? ccList,
    List<Uint8List>? files,
    List<String>? fileNames,
  }) async {
    final url = Uri.parse('$serverUrl/leave/grant/request');

    try {
      print('🏢 [LeaveApiService] 휴가 부여 상신 Multipart API 요청 시작');
      print('🏢 [LeaveApiService] URL: $url');

      final request = http.MultipartRequest('POST', url);

      // Text fields
      request.fields['user_id'] = userId;
      request.fields['department'] = department;
      request.fields['approval_date'] = approvalDate;
      request.fields['approval_type'] = approvalType;
      request.fields['title'] = title;
      request.fields['leave_type'] = leaveType;
      request.fields['grant_days'] = grantDays.toString();
      request.fields['reason'] = reason;

      if (startDate != null) request.fields['start_date'] = startDate;
      if (endDate != null) request.fields['end_date'] = endDate;
      if (halfDaySlot != null) request.fields['half_day_slot'] = halfDaySlot;

      // JSON fields
      request.fields['approval_line'] = jsonEncode(
        approvalLine.map((item) => item.toJson()).toList(),
      );
      request.fields['attachments_list'] = jsonEncode(
        attachmentsList.map((item) => item.toJson()).toList(),
      );

      if (ccList != null && ccList.isNotEmpty) {
        request.fields['cc_list'] = jsonEncode(
          ccList.map((p) => {'user_id': p.userId, 'name': p.name}).toList(),
        );
      }

      // 필드 값 로그 출력
      print('📋 [LeaveApiService] 전송 필드 값:');
      request.fields.forEach((key, value) {
        if (value.length > 100) {
          print('  - $key: ${value.substring(0, 100)}...');
        } else {
          print('  - $key: $value');
        }
      });

      // File attachments (모달에서 직접 첨부한 파일)
      if (files != null && files.isNotEmpty) {
        print('📁 [LeaveApiService] 첨부 파일 ${files.length}개 처리 시작');
        for (int i = 0; i < files.length; i++) {
          final filename = (fileNames != null && i < fileNames.length)
              ? fileNames[i]
              : 'file_$i';

          // MIME type 추정
          final mimeType = _detectMimeType(files[i], filename);

          request.files.add(
            http.MultipartFile.fromBytes(
              'files',
              files[i],
              filename: filename,
              contentType: MediaType.parse(mimeType),
            ),
          );
          print('  - 파일 #${i + 1}: $filename ($mimeType, ${files[i].length} bytes)');
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('🏢 [LeaveApiService] Multipart 응답 상태 코드: ${response.statusCode}');
      print('🏢 [LeaveApiService] Multipart 응답 바디: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return LeaveGrantResponse.fromJson(data);
      } else {
        // 서버 에러인 경우에도 응답 파싱 시도
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          return LeaveGrantResponse.fromJson(data);
        } catch (e) {
          return LeaveGrantResponse(
            error: '휴가 부여 상신에 실패했습니다. 상태 코드: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      print('🏢 [LeaveApiService] 휴가 부여 상신 Multipart API 호출 실패: $e');
      return LeaveGrantResponse(
        error: '휴가 부여 상신에 실패했습니다: $e',
      );
    }
  }

  /// MIME 타입 감지 헬퍼
  static String _detectMimeType(Uint8List bytes, String filename) {
    final ext = filename.split('.').last.toLowerCase();

    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'txt':
        return 'text/plain';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  // ===============================
  // 관리자용 관리 페이지 API (관리자 페이지 초기 로드용)
  // ===============================

  /// 관리자 관리 페이지 초기 데이터 조회
  static Future<AdminManagementResponse> getAdminManagementData({
    required AdminManagementRequest request,
  }) async {
    final url = Uri.parse('$serverUrl/leave/admin/management');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode(request.toJson());

    try {
      print('🔍 [LeaveApiService] 관리자 관리 데이터 API 요청 시작');
      print('🔍 [LeaveApiService] URL: $url');
      print('🔍 [LeaveApiService] Headers: $headers');
      print('🔍 [LeaveApiService] Request Body: $body');

      final response = await http.post(url, headers: headers, body: body);

      print('🔍 [LeaveApiService] 응답 상태 코드: ${response.statusCode}');
      print('🔍 [LeaveApiService] 응답 헤더: ${response.headers}');
      print('🔍 [LeaveApiService] 응답 바디: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        print('🔍 [LeaveApiService] 파싱된 JSON 데이터: $data');
        print(
            '🔍 [LeaveApiService] approval_status: ${data['approval_status']}');
        print('🔍 [LeaveApiService] monthly_leaves: ${data['monthly_leaves']}');
        print('🔍 [LeaveApiService] waiting_leaves: ${data['waiting_leaves']}');
        print('🔍 [LeaveApiService] error: ${data['error']}');

        final result = AdminManagementResponse.fromJson(data);
        print('🔍 [LeaveApiService] 변환된 응답 객체: $result');
        return result;
      } else {
        // 서버 에러인 경우에도 응답 파싱 시도
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          print('🔍 [LeaveApiService] 서버 에러 응답 파싱: $data');
          return AdminManagementResponse.fromJson(data);
        } catch (e) {
          print('🔍 [LeaveApiService] 서버 에러 응답 파싱 실패: $e');
          return AdminManagementResponse(
            error: '관리자 관리 데이터 조회에 실패했습니다. 상태 코드: ${response.statusCode}',
            approvalStatus:
                AdminApprovalStatus(requested: 0, approved: 0, rejected: 0),
            monthlyLeaves: [],
            waitingLeaves: [],
          );
        }
      }
    } catch (e) {
      print('🔍 [LeaveApiService] 관리자 관리 데이터 API 호출 실패: $e');
      return AdminManagementResponse(
        error: '관리자 관리 데이터 조회에 실패했습니다: $e',
        approvalStatus:
            AdminApprovalStatus(requested: 0, approved: 0, rejected: 0),
        monthlyLeaves: [],
        waitingLeaves: [],
      );
    }
  }

  /// 관리자 연도별 데이터 조회 (결재대기목록 연도 변경 시)
  static Future<AdminManagementResponse> getAdminYearlyData({
    required String approverId,
    required String year,
  }) async {
    final url = Uri.parse('$serverUrl/leave/admin/management/yearly');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'approver_id': approverId,
      'month': year, // API 스펙상 'month' 키를 사용하지만 연도값을 전달
    });

    try {
      print('🔍 [LeaveApiService] 관리자 연도별 데이터 API 요청 시작');
      print('🔍 [LeaveApiService] URL: $url');
      print('🔍 [LeaveApiService] Request Body: $body');

      final response = await http.post(url, headers: headers, body: body);
      print(
          '🔍 [LeaveApiService] 관리자 연도별 데이터 응답 상태 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        print('🔍 [LeaveApiService] 관리자 연도별 데이터 응답 파싱 성공');

        final result = AdminManagementResponse.fromJson(data);
        return result;
      } else {
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          return AdminManagementResponse.fromJson(data);
        } catch (e) {
          return AdminManagementResponse(
            error: '관리자 연도별 데이터 조회에 실패했습니다. 상태 코드: ${response.statusCode}',
            approvalStatus:
                AdminApprovalStatus(requested: 0, approved: 0, rejected: 0),
            monthlyLeaves: [],
            waitingLeaves: [],
          );
        }
      }
    } catch (e) {
      print('🔍 [LeaveApiService] 관리자 연도별 데이터 API 호출 실패: $e');
      return AdminManagementResponse(
        error: '관리자 연도별 데이터 조회에 실패했습니다: $e',
        approvalStatus:
            AdminApprovalStatus(requested: 0, approved: 0, rejected: 0),
        monthlyLeaves: [],
        waitingLeaves: [],
      );
    }
  }

  /// 관리자 승인/반려 처리 (일반 휴가)
  static Future<AdminApprovalResponse> processAdminApproval({
    required AdminApprovalRequest request,
  }) async {
    final url = Uri.parse('$serverUrl/leave/admin/approval');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode(request.toJson());

    try {
      print('관리자 승인/반려 API 요청 URL: $url');
      print('관리자 승인/반려 API 요청 헤더: $headers');
      print('관리자 승인/반려 API 요청 바디: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('관리자 승인/반려 응답 상태 코드: ${response.statusCode}');
      print('관리자 승인/반려 응답: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return AdminApprovalResponse.fromJson(data);
      } else {
        // 서버 에러인 경우에도 응답 파싱 시도
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;

          // 서버 에러 메시지가 있으면 해당 메시지 사용
          final serverError = data['error'] as String?;
          if (serverError != null) {
            return AdminApprovalResponse(
              error: '서버 오류: $serverError',
              monthlyLeaves: [],
            );
          }

          return AdminApprovalResponse.fromJson(data);
        } catch (e) {
          return AdminApprovalResponse(
            error:
                '승인/반려 처리에 실패했습니다. 상태 코드: ${response.statusCode}\n응답: ${response.body}',
            monthlyLeaves: [],
          );
        }
      }
    } catch (e) {
      print('관리자 승인/반려 API 호출 실패: $e');
      return AdminApprovalResponse(
        error: '승인/반려 처리에 실패했습니다: $e',
        monthlyLeaves: [],
      );
    }
  }

  /// 관리자 취소 승인/반려 처리 (휴가 취소)
  static Future<AdminApprovalResponse> processCancelApproval({
    required AdminApprovalRequest request,
  }) async {
    final url = Uri.parse('$serverUrl/leave/admin/approval/cancel');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode(request.toJson());

    try {
      print('관리자 취소 승인/반려 API 요청 URL: $url');
      print('관리자 취소 승인/반려 API 요청 헤더: $headers');
      print('관리자 취소 승인/반려 API 요청 바디: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('관리자 취소 승인/반려 응답 상태 코드: ${response.statusCode}');
      print('관리자 취소 승인/반려 응답: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return AdminApprovalResponse.fromJson(data);
      } else {
        // 서버 에러인 경우에도 응답 파싱 시도
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;

          // 서버 에러 메시지가 있으면 해당 메시지 사용
          final serverError = data['error'] as String?;
          if (serverError != null) {
            return AdminApprovalResponse(
              error: '서버 오류: $serverError',
              monthlyLeaves: [],
            );
          }

          return AdminApprovalResponse.fromJson(data);
        } catch (e) {
          return AdminApprovalResponse(
            error:
                '취소 승인/반려 처리에 실패했습니다. 상태 코드: ${response.statusCode}\n응답: ${response.body}',
            monthlyLeaves: [],
          );
        }
      }
    } catch (e) {
      print('관리자 취소 승인/반려 API 호출 실패: $e');
      return AdminApprovalResponse(
        error: '취소 승인/반려 처리에 실패했습니다: $e',
        monthlyLeaves: [],
      );
    }
  }

  /// 관리자 부서별 달력 조회 (넓게보기)
  static Future<AdminDeptCalendarResponse> getAdminDeptCalendar({
    required AdminDeptCalendarRequest request,
  }) async {
    final url = Uri.parse('$serverUrl/leave/admin/management/deptCalendar');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode(request.toJson());

    try {
      print('관리자 부서별 달력 API 요청: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('관리자 부서별 달력 응답 상태 코드: ${response.statusCode}');
      print('관리자 부서별 달력 응답: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return AdminDeptCalendarResponse.fromJson(data);
      } else {
        // 서버 에러인 경우에도 응답 파싱 시도
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          return AdminDeptCalendarResponse.fromJson(data);
        } catch (e) {
          return AdminDeptCalendarResponse(
            error: '부서별 달력 조회에 실패했습니다. 상태 코드: ${response.statusCode}',
            monthlyLeaves: [],
          );
        }
      }
    } catch (e) {
      print('관리자 부서별 달력 API 호출 실패: $e');
      return AdminDeptCalendarResponse(
        error: '부서별 달력 조회에 실패했습니다: $e',
        monthlyLeaves: [],
      );
    }
  }

  /// 관리자 결재 대기 목록 조회 (모달용)
  ///
  /// **사용 시점**: leave.approval 큐 알림 클릭 시
  /// **반환 데이터**: 현재 대기 중인 결재 건만 조회
  static Future<List<AdminWaitingLeave>> getAdminWaitingLeaves({
    required String approverId,
  }) async {
    final url = Uri.parse('$serverUrl/leave/admin/management/waitingLeaves');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'approver_id': approverId,
    });

    try {
      print('🔍 [LeaveApiService] 관리자 결재 대기 목록 API 요청 시작');
      print('🔍 [LeaveApiService] 전달받은 approverId 파라미터: $approverId');
      print('🔍 [LeaveApiService] URL: $url');
      print('🔍 [LeaveApiService] Request Headers: $headers');
      print('🔍 [LeaveApiService] Request Body: $body');

      final response = await http.post(url, headers: headers, body: body);

      print('🔍 [LeaveApiService] 응답 상태 코드: ${response.statusCode}');
      print('🔍 [LeaveApiService] 응답 바디: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        print('🔍 [LeaveApiService] 파싱된 JSON 데이터: $data');

        final waitingLeaves = data['waiting_leaves'] as List<dynamic>?;
        if (waitingLeaves != null) {
          print('🔍 [LeaveApiService] 대기 중인 결재 건: ${waitingLeaves.length}개');
          return waitingLeaves
              .map((item) => AdminWaitingLeave.fromJson(item))
              .toList();
        } else {
          print('⚠️ [LeaveApiService] waiting_leaves가 null입니다.');
          return [];
        }
      } else {
        print('⚠️ [LeaveApiService] 서버 에러: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ [LeaveApiService] 관리자 결재 대기 목록 API 호출 실패: $e');
      return [];
    }
  }

  // ===============================
  // 사용자 휴가 취소 상신 API
  // ===============================

  /// 사용자 휴가 취소 상신
  ///
  /// **사용 시점**: 승인된 휴가를 취소하고 싶을 때
  /// **처리 과정**: 취소 사유를 입력하여 결재자에게 취소 상신
  static Future<LeaveCancelResponse> requestLeaveCancel({
    required int id,
    required String userId,
    required String reason,
  }) async {
    final url = Uri.parse('$serverUrl/leave/user/cancel/request');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'id': id,
      'user_id': userId,
      'reason': reason,
    });

    try {
      print('휴가 취소 상신 API 요청 URL: $url');
      print('휴가 취소 상신 API 요청 바디: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('휴가 취소 상신 응답 상태 코드: ${response.statusCode}');
      print('휴가 취소 상신 응답: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return LeaveCancelResponse.fromJson(data);
      } else {
        // 서버 에러인 경우에도 응답 파싱 시도
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          return LeaveCancelResponse.fromJson(data);
        } catch (e) {
          return LeaveCancelResponse(
            error: '휴가 취소 상신에 실패했습니다. 상태 코드: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      print('휴가 취소 상신 API 호출 실패: $e');
      return LeaveCancelResponse(
        error: '휴가 취소 상신에 실패했습니다: $e',
      );
    }
  }

  // ===============================
  // 승인자 관련 API
  // ===============================

  /// 승인자 목록 조회
  ///
  /// **API 정보**:
  /// - URL: /leave/user/getApprover
  /// - Method: POST
  /// - Request Body: 없음
  ///
  /// **반환 데이터**:
  /// - approverList: 승인자 목록 (approver_id, approver_name, job_position, department)
  static Future<ApproverListResponse> getApprover() async {
    final url = Uri.parse('$serverUrl/leave/user/getApprover');
    final headers = {'Content-Type': 'application/json'};

    try {
      print('승인자 목록 API 요청 시작');
      final response = await http.post(url, headers: headers);
      print('승인자 목록 응답 상태 코드: ${response.statusCode}');
      print('승인자 목록 응답: ${response.body}');

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return ApproverListResponse.fromJson(data);
      } else {
        return ApproverListResponse(
          approverList: [],
          error: '승인자 목록 조회 실패. 상태 코드: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('승인자 목록 API 호출 실패: $e');
      return ApproverListResponse(
        approverList: [],
        error: '승인자 목록 조회 실패: $e',
      );
    }
  }

  /// 결재라인 저장
  ///
  /// **API 정보**:
  /// - URL: /leave/user/setApprovalLine
  /// - Method: POST
  /// - Request Body: {user_id, approval_line, cc_list}
  ///
  /// **반환 데이터**:
  /// - error: 에러 메시지 (성공 시 null)
  static Future<ApprovalLineSaveResponse> saveApprovalLine({
    required ApprovalLineSaveRequest request,
  }) async {
    final url = Uri.parse('$serverUrl/leave/user/setApprovalLine');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode(request.toJson());

    try {
      print('결재라인 저장 API 요청: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('결재라인 저장 응답 상태 코드: ${response.statusCode}');
      print('결재라인 저장 응답: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return ApprovalLineSaveResponse.fromJson(data);
      } else {
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          return ApprovalLineSaveResponse.fromJson(data);
        } catch (e) {
          return ApprovalLineSaveResponse(
            error: '결재라인 저장에 실패했습니다. 상태 코드: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      print('결재라인 저장 API 호출 실패: $e');
      return ApprovalLineSaveResponse(
        error: '결재라인 저장에 실패했습니다: $e',
      );
    }
  }

  /// 결재라인 불러오기
  ///
  /// **API 정보**:
  /// - URL: /leave/user/getApprovalLine
  /// - Method: POST
  /// - Request Body: {user_id}
  ///
  /// **반환 데이터**:
  /// - approval_line: 저장된 결재라인 목록
  /// - cc_list: 저장된 참조자 목록
  /// - error: 에러 메시지 (성공 시 null)
  static Future<ApprovalLineLoadResponse> loadApprovalLine({
    required String userId,
  }) async {
    final url = Uri.parse('$serverUrl/leave/user/getApprovalLine');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'user_id': userId});

    try {
      print('💾 결재라인 불러오기 API 요청 시작');
      print('💾 userId: $userId');

      final response = await http.post(url, headers: headers, body: body);
      print('💾 결재라인 불러오기 응답 상태 코드: ${response.statusCode}');
      print('💾 결재라인 불러오기 응답: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return ApprovalLineLoadResponse.fromJson(data);
      } else {
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          return ApprovalLineLoadResponse.fromJson(data);
        } catch (e) {
          return ApprovalLineLoadResponse(
            approvalLine: [],
            ccList: [],
            error: '결재라인 불러오기에 실패했습니다. 상태 코드: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      print('💾 결재라인 불러오기 API 호출 실패: $e');
      return ApprovalLineLoadResponse(
        approvalLine: [],
        ccList: [],
        error: '결재라인 불러오기에 실패했습니다: $e',
      );
    }
  }

  // ===============================
  // 전자결재 결재라인 API (CommonElectronicApprovalModal용)
  // ===============================

  /// 전자결재용 결재라인 저장
  ///
  /// **API 정보**:
  /// - URL: /eapproval/setApprovalLine
  /// - Method: POST
  /// - Request Body: {user_id, approval_type, approval_line, cc_list}
  ///
  /// **반환 데이터**:
  /// - error: 에러 메시지 (성공 시 null)
  static Future<ApprovalLineSaveResponse> saveEApprovalLine({
    required String userId,
    required String approvalType,
    required List<SaveApprovalLineData> approvalLine,
    required List<CcListItem> ccList,
  }) async {
    final url = Uri.parse('$serverUrl/eapproval/setApprovalLine');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'user_id': userId,
      'approval_type': approvalType,
      'approval_line': approvalLine.map((item) => item.toJson()).toList(),
      'cc_list': ccList.map((item) => item.toJson()).toList(),
    });

    try {
      print('📋 [전자결재] 결재라인 저장 API 요청: $body');
      final response = await http.post(url, headers: headers, body: body);
      print('📋 [전자결재] 결재라인 저장 응답 상태 코드: ${response.statusCode}');
      print('📋 [전자결재] 결재라인 저장 응답: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return ApprovalLineSaveResponse.fromJson(data);
      } else {
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          return ApprovalLineSaveResponse.fromJson(data);
        } catch (e) {
          return ApprovalLineSaveResponse(
            error: '전자결재 결재라인 저장에 실패했습니다. 상태 코드: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      print('📋 [전자결재] 결재라인 저장 API 호출 실패: $e');
      return ApprovalLineSaveResponse(
        error: '전자결재 결재라인 저장에 실패했습니다: $e',
      );
    }
  }

  /// 전자결재용 결재라인 불러오기
  ///
  /// **API 정보**:
  /// - URL: /eapproval/getApprovalLine
  /// - Method: POST
  /// - Request Body: {user_id, approval_type}
  ///
  /// **반환 데이터**:
  /// - approval_line: 저장된 결재라인 목록
  /// - cc_list: 저장된 참조자 목록
  /// - error: 에러 메시지 (성공 시 null)
  static Future<ApprovalLineLoadResponse> loadEApprovalLine({
    required String userId,
    required String approvalType,
  }) async {
    final url = Uri.parse('$serverUrl/eapproval/getApprovalLine');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'user_id': userId,
      'approval_type': approvalType,
    });

    try {
      print('📋 [전자결재] 결재라인 불러오기 API 요청 시작');
      print('📋 [전자결재] userId: $userId, approvalType: $approvalType');

      final response = await http.post(url, headers: headers, body: body);
      print('📋 [전자결재] 결재라인 불러오기 응답 상태 코드: ${response.statusCode}');
      print('📋 [전자결재] 결재라인 불러오기 응답: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return ApprovalLineLoadResponse.fromJson(data);
      } else {
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          return ApprovalLineLoadResponse.fromJson(data);
        } catch (e) {
          return ApprovalLineLoadResponse(
            approvalLine: [],
            ccList: [],
            error: '전자결재 결재라인 불러오기에 실패했습니다. 상태 코드: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      print('📋 [전자결재] 결재라인 불러오기 API 호출 실패: $e');
      return ApprovalLineLoadResponse(
        approvalLine: [],
        ccList: [],
        error: '전자결재 결재라인 불러오기에 실패했습니다: $e',
      );
    }
  }
}

/// 휴가 취소 상신 응답 모델
class LeaveCancelResponse {
  final String? error;

  LeaveCancelResponse({
    this.error,
  });

  factory LeaveCancelResponse.fromJson(Map<String, dynamic> json) {
    return LeaveCancelResponse(
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'error': error,
    };
  }

  bool get isSuccess => error == null || error!.isEmpty;
}

/// 결재라인 저장 요청 모델
class ApprovalLineSaveRequest {
  final String userId;
  final List<SaveApprovalLineData> approvalLine;
  final List<CcListItem> ccList;

  ApprovalLineSaveRequest({
    required this.userId,
    required this.approvalLine,
    required this.ccList,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'approval_line': approvalLine.map((item) => item.toJson()).toList(),
      'cc_list': ccList.map((item) => item.toJson()).toList(),
    };
  }
}

/// 결재라인 저장용 항목 모델
class SaveApprovalLineData {
  final String approverId;
  final String nextApproverId;
  final int approvalSeq;
  final String approverName;

  SaveApprovalLineData({
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

/// 참조자 항목 모델
class CcListItem {
  final String userId;
  final String name;
  final String department;
  final String jobPosition;

  CcListItem({
    required this.userId,
    required this.name,
    required this.department,
    required this.jobPosition,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'department': department,
      'job_position': jobPosition,
    };
  }
}

/// 결재라인 저장 응답 모델
class ApprovalLineSaveResponse {
  final String? error;

  ApprovalLineSaveResponse({
    this.error,
  });

  factory ApprovalLineSaveResponse.fromJson(Map<String, dynamic> json) {
    return ApprovalLineSaveResponse(
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'error': error,
    };
  }

  bool get isSuccess => error == null || error!.isEmpty;
}

/// 결재라인 불러오기 응답 모델
class ApprovalLineLoadResponse {
  final List<LoadedApprovalLineData> approvalLine;
  final List<LoadedCcListItem> ccList;
  final String? error;

  ApprovalLineLoadResponse({
    required this.approvalLine,
    required this.ccList,
    this.error,
  });

  factory ApprovalLineLoadResponse.fromJson(Map<String, dynamic> json) {
    return ApprovalLineLoadResponse(
      approvalLine: (json['approval_line'] as List<dynamic>?)
              ?.map((item) =>
                  LoadedApprovalLineData.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      ccList: (json['cc_list'] as List<dynamic>?)
              ?.map((item) =>
                  LoadedCcListItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      error: json['error'] as String?,
    );
  }

  bool get isSuccess => error == null || error!.isEmpty;
}

/// 불러온 결재라인 항목 모델
class LoadedApprovalLineData {
  final String approverName;
  final String approverId;
  final int approvalSeq;
  final String nextApproverId;

  LoadedApprovalLineData({
    required this.approverName,
    required this.approverId,
    required this.approvalSeq,
    required this.nextApproverId,
  });

  factory LoadedApprovalLineData.fromJson(Map<String, dynamic> json) {
    return LoadedApprovalLineData(
      approverName: json['approver_name'] as String? ?? '',
      approverId: json['approver_id'] as String? ?? '',
      approvalSeq: json['approval_seq'] as int? ?? 0,
      nextApproverId: json['next_approver_id'] as String? ?? '',
    );
  }
}

/// 불러온 참조자 항목 모델
class LoadedCcListItem {
  final String name;
  final String userId;
  final String department;
  final String jobPosition;

  LoadedCcListItem({
    required this.name,
    required this.userId,
    required this.department,
    required this.jobPosition,
  });

  factory LoadedCcListItem.fromJson(Map<String, dynamic> json) {
    return LoadedCcListItem(
      name: json['name'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      department: json['department'] as String? ?? '',
      jobPosition: json['job_position'] as String? ?? '',
    );
  }
}
