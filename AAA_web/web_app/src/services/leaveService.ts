import axios from 'axios';
import api from './api';
import { API_BASE_URL } from '../utils/apiConfig';
import { createLogger } from '../utils/logger';
import type {
  LeaveManagementData,
  LeaveRequestRequest,
  LeaveRequestResponse,
  LeaveCancelRequest,
  LeaveCancelResponse,
  MonthlyCalendarRequest,
  MonthlyCalendarResponse,
  YearlyLeaveRequest,
  YearlyLeaveResponse,
  TotalCalendarResponse,
  AdminManagementRequest,
  AdminManagementApiResponse,
  AdminApprovalRequest,
  AdminApprovalResponse,
  CancelApprovalRequest,
  AdminDeptCalendarRequest,
  AdminDeptCalendarResponse,
  AdminYearlyLeaveRequest,
  AdminYearlyLeaveResponse,
  LeaveBalance,
  ApproverListResponse,
  LeaveCancelRequestPayload,
  DepartmentLeaveStatusResponse,
  AdminWaitingLeave,
} from '../types/leave';

const logger = createLogger('LeaveService');

class LeaveService {
  // ===============================
  // 휴가관리 화면 API (Flutter와 동일)
  // ===============================

  /**
   * 휴가관리 데이터 조회 (휴가관리 화면용) - Flutter와 동일
   */
  async getLeaveManagement(userId: string): Promise<LeaveManagementData> {
    try {
      // Flutter와 완전히 동일한 URL 사용
      const response = await axios.post<LeaveManagementData>(
        `${API_BASE_URL}/leave/user/management`,
        {
          user_id: userId,
        },
        {
          headers: {
            'Content-Type': 'application/json',
          },
          timeout: 30000,
        }
      );

      return response.data;
    } catch (error: any) {
      logger.error('휴가관리 데이터 조회 실패:', error.message);
      throw error;
    }
  }

  /**
   * 월별 달력 조회 (휴가 일정 달력 월 변경용) - Flutter와 동일
   */
  async getMonthlyCalendar(request: MonthlyCalendarRequest): Promise<MonthlyCalendarResponse> {
    logger.dev('월별 달력 API 요청:', request);

    const response = await api.post<any>('/leave/user/management/myCalendar', {
      user_id: request.userId,
      month: request.month,
    });

    logger.dev('월별 달력 응답:', response.data);

    // API 응답이 snake_case로 오므로 camelCase로 변환
    const data = response.data;
    const monthlyLeaves = (data.monthly_leaves || data.monthlyLeaves || []).map((item: any) => ({
      status: item.status || '',
      leaveType: item.leave_type || item.leaveType || '',
      startDate: item.start_date || item.startDate || '',
      endDate: item.end_date || item.endDate || '',
      halfDaySlot: item.half_day_slot || item.halfDaySlot || '',
      reason: item.reason || '',
      rejectMessage: item.reject_message || item.rejectMessage || '',
    }));

    return {
      error: data.error || undefined,
      monthlyLeaves: monthlyLeaves,
    };
  }

  /**
   * 연도별 휴가 내역 조회 - Flutter와 동일
   */
  async getYearlyLeave(request: YearlyLeaveRequest): Promise<YearlyLeaveResponse> {
    logger.dev('연도별 휴가 데이터 API 요청:', request);

    try {
      // Flutter와 동일한 snake_case 형식으로 변환
      const flutterRequest = {
        user_id: request.userId,
        month: request.year.toString(), // API 명세에 따라 month 필드에 연도값 전송
      };

      const response = await api.post<any>('/leave/user/management/yearly', flutterRequest);

      logger.dev('연도별 휴가 데이터 응답:', response.data);

      // API 응답이 snake_case로 오므로 camelCase로 변환
      const data = response.data;

      // yearly_details 매핑 (snake_case -> camelCase)
      const yearlyDetails = (data.yearly_details || data.yearlyDetails || []).map((item: any) => ({
        id: item.id || 0,
        status: item.status || '',
        leaveType: item.leave_type || item.leaveType || '',
        startDate: item.start_date || item.startDate || '',
        endDate: item.end_date || item.endDate || '',
        workdaysCount: item.workdays_count || item.workdaysCount || 0,
        requestedDate: item.requested_date || item.requestedDate || '',
        reason: item.reason || '',
        rejectMessage: item.reject_message || item.rejectMessage || '',
        isCancel: item.is_cancel || item.isCancel || 0,
      }));

      // yearly_whole_status 매핑
      const yearlyWholeStatus = (data.yearly_whole_status || data.yearlyWholeStatus || []).map((item: any) => ({
        leaveType: item.leave_type || item.leaveType || '',
        totalDays: item.total_days || item.totalDays || 0,
        m01: item.m01 || 0,
        m02: item.m02 || 0,
        m03: item.m03 || 0,
        m04: item.m04 || 0,
        m05: item.m05 || 0,
        m06: item.m06 || 0,
        m07: item.m07 || 0,
        m08: item.m08 || 0,
        m09: item.m09 || 0,
        m10: item.m10 || 0,
        m11: item.m11 || 0,
        m12: item.m12 || 0,
        remainDays: item.remain_days || item.remainDays || 0,
      }));

      const result: YearlyLeaveResponse = {
        error: data.error || undefined,
        yearlyDetails: yearlyDetails,
        yearlyWholeStatus: yearlyWholeStatus,
      };

      return result;
    } catch (err: any) {
      logger.error('연도별 휴가 내역 API 호출 실패:', err);
      // 에러 발생 시 빈 응답 반환 (에러를 throw하지 않음)
      return {
        error: err.response?.data?.error || err.message || '연도별 휴가 내역 조회에 실패했습니다.',
        yearlyDetails: [],
        yearlyWholeStatus: [],
      };
    }
  }

  /**
   * 전체 부서 휴가 현황 조회 (부서 휴가 현황 탭용) - Flutter와 동일
   */
  async getTotalCalendar(month: string): Promise<TotalCalendarResponse> {
    logger.dev('부서 휴가 현황 API 요청:', { month });

    const response = await api.post<any>('/leave/user/management/totalCalendar', {
      month: month,
    });

    logger.dev('부서 휴가 현황 응답:', response.data);

    // API 응답이 snake_case로 오므로 camelCase로 변환
    const data = response.data;
    const monthlyLeaves = (data.monthlyLeaves || data.monthly_leaves || []).map((item: any) => ({
      name: item.name || '',
      department: item.department || '',
      startDate: item.start_date || item.startDate || '',
      endDate: item.end_date || item.endDate || '',
      leaveType: item.leave_type || item.leaveType || '',
    }));

    return {
      error: data.error,
      monthlyLeaves: monthlyLeaves,
    };
  }

  // ===============================
  // 대시보드 통합 API (Flutter와 동일)
  // ===============================

  /**
   * 내 휴가 현황 조회 - Flutter와 동일 (GET 요청)
   * 주의: 이 API는 실제로 존재하지 않을 수 있음. 메인 API의 leaveStatus 사용 권장
   */
  async getLeaveBalance(userId: string): Promise<LeaveBalance[]> {
    logger.dev('내 휴가 현황 API 요청:', userId);

    const response = await api.get<{ leaveBalances: LeaveBalance[] }>(`/api/leave/balance/${userId}`);

    logger.dev('내 휴가 현황 응답:', response.data);
    return response.data.leaveBalances || [];
  }

  /**
   * 부서 휴가 내역 조회 - Flutter와 동일
   */
  async getDepartmentHistory(userId: string, month: string): Promise<any[]> {
    logger.dev('부서 휴가 내역 API 요청:', { user_id: userId, month });

    const response = await api.post<{ departmentHistory: any[] }>('/leave/user/management/departmentHistory', {
      user_id: userId,
      month: month,
    });

    logger.dev('부서 휴가 내역 응답:', response.data);
    return response.data.departmentHistory || [];
  }

  /**
   * 휴가 관리 대장 데이터 조회 - Flutter와 동일
   */
  async getLeaveManagementTable(userId: string, year: number): Promise<any[]> {
    logger.dev('휴가 관리 대장 API 요청:', { userId, year });

    try {
      const response = await api.post<any>('/api/leave/management-table', {
        userId: userId,
        year: year,
      });

      logger.dev('휴가 관리 대장 응답:', response.data);

      // API 응답 구조 확인 (managementTable 또는 management_table)
      const tableData = response.data.managementTable || response.data.management_table || [];

      // 데이터 매핑 (snake_case -> camelCase)
      return tableData.map((item: any) => ({
        leaveType: item.leaveType || item.leave_type || '',
        allowedDays: item.allowedDays || item.allowed_days || 0,
        usedByMonth: item.usedByMonth || item.used_by_month || Array(12).fill(0),
        totalUsed: item.totalUsed || item.total_used || 0,
      }));
    } catch (err: any) {
      logger.error('휴가 관리 대장 API 호출 실패:', err);
      // API가 없거나 실패한 경우 빈 배열 반환 (에러를 throw하지 않음)
      return [];
    }
  }

  // ===============================
  // 휴가 신청/수정/취소 API (Flutter와 동일)
  // ===============================

  /**
   * 휴가 상신 (새로운 API) - Flutter와 동일
   * 순차결재 지원 (approvalLine)
   */
  async submitLeaveRequest(request: LeaveRequestRequest): Promise<LeaveRequestResponse> {
    logger.dev('휴가 상신 API 요청 (원본):', request);

    // half_day_slot이 'ALL'이거나 undefined인 경우 null로 처리 (Flutter와 동일)
    const halfDaySlot = request.halfDaySlot && request.halfDaySlot !== 'ALL'
      ? request.halfDaySlot
      : null;

    const flutterRequest: any = {
      user_id: request.userId,
      leave_type: request.leaveType,
      start_date: request.startDate,
      end_date: request.endDate,
      cc_list: request.ccList.map(cc => ({
        name: cc.name,
        department: cc.department
      })),
      reason: request.reason,
      is_next_year: request.isNextYear || 0,
    };

    // 순차결재 모드인 경우 approval_line 사용
    if (request.approvalLine && request.approvalLine.length > 0) {
      flutterRequest.approval_line = request.approvalLine.map((line) => ({
        approver_id: line.approverId,
        next_approver_id: line.nextApproverId,
        approval_seq: line.approvalSeq,
        approver_name: line.approverName,
      }));
      logger.dev('순차결재 모드 - approval_line:', flutterRequest.approval_line);
    } else {
      // 일반 모드: approver_ids 사용
      const approverIds = request.approverIds && request.approverIds.length > 0
        ? request.approverIds
        : [request.userId];
      flutterRequest.approver_ids = approverIds;
      logger.dev('일반 모드 - approver_ids:', flutterRequest.approver_ids);
    }

    // half_day_slot이 null이 아닐 때만 추가 (Flutter와 동일)
    if (halfDaySlot !== null) {
      flutterRequest.half_day_slot = halfDaySlot;
    }

    logger.dev('휴가 상신 API 요청 (Flutter 형식):', flutterRequest);

    try {
      const response = await api.post<LeaveRequestResponse>('/leave/user/request', flutterRequest);
      logger.dev('휴가 상신 응답:', response.data);
      return response.data;
    } catch (error: any) {
      logger.error('휴가 상신 API 에러:', error);
      logger.error('에러 응답 데이터:', error.response?.data);
      logger.error('에러 응답 본문 (전체):', error.response?.data ? JSON.stringify(error.response.data, null, 2) : '없음');
      logger.error('에러 상태 코드:', error.response?.status);
      logger.error('에러 헤더:', error.response?.headers);
      logger.error('요청 URL:', error.config?.url);
      logger.error('요청 데이터:', JSON.stringify(flutterRequest, null, 2));
      logger.error('요청 헤더:', error.config?.headers);

      // 서버 에러 메시지 추출
      const errorMessage = error.response?.data?.error
        || error.response?.data?.message
        || error.response?.data?.detail
        || error.message
        || '휴가 신청에 실패했습니다.';

      logger.error('서버 에러 메시지:', errorMessage);

      // 에러 객체에 메시지 추가
      const enhancedError = new Error(errorMessage);
      (enhancedError as any).response = error.response;
      (enhancedError as any).config = error.config;
      throw enhancedError;
    }
  }

  /**
   * 휴가 취소 - Flutter와 동일
   */
  async cancelLeave(request: LeaveCancelRequest): Promise<LeaveCancelResponse> {
    logger.dev('휴가 취소 API 요청:', request);

    const response = await api.post<LeaveCancelResponse>('/leave/user/cancel', request);

    logger.dev('휴가 취소 응답:', response.data);
    return response.data;
  }

  // ===============================
  // 관리자용 API (Flutter와 동일)
  // ===============================

  /**
   * 관리자용 부서원 휴가 현황 조회 (관리자 사이드바용) - Flutter와 동일
   */
  async getDepartmentLeaveStatus(approverId: string): Promise<DepartmentLeaveStatusResponse> {
    logger.dev('관리자 부서원 휴가 현황 API 요청:', { approver_id: approverId });

    try {
      const response = await api.post<any>('/leave/admin/status', {
        approver_id: approverId,
      });

      logger.dev('관리자 부서원 휴가 현황 응답:', response.data);

      // API 응답이 snake_case로 오므로 camelCase로 변환
      const data = response.data;
      const employees = (data.employees || []).map((item: any) => ({
        id: item.id || 0,
        status: item.status || '',
        name: item.name || '',
        department: item.department || '',
        jobPosition: item.job_position || item.jobPosition || '',
        leaveType: item.leave_type || item.leaveType || '',
        startDate: item.start_date || item.startDate || '',
        endDate: item.end_date || item.endDate || '',
        halfDaySlot: item.half_day_slot || item.halfDaySlot || '',
        totalDays: item.total_days || item.totalDays || 0,
        usedDays: item.used_days || item.usedDays || 0,
        remainDays: item.remain_days || item.remainDays || 0,
        workdaysCount: item.workdays_count || item.workdaysCount || 0,
        requestedDate: item.requested_date || item.requestedDate || '',
        reason: item.reason || '',
        joinDate: item.join_date || item.joinDate || '',
      }));

      return {
        employees: employees,
        error: data.error || undefined,
      };
    } catch (err: any) {
      logger.error('부서원 휴가 현황 API 호출 실패:', err);
      return {
        employees: [],
        error: err.response?.data?.error || err.message || '부서원 휴가 현황 조회에 실패했습니다.',
      };
    }
  }

  /**
   * 관리자 관리 페이지 초기 데이터 조회 - Flutter와 동일
   */
  async getAdminManagementData(request: AdminManagementRequest): Promise<AdminManagementApiResponse> {
    logger.dev('관리자 관리 데이터 API 요청:', request);

    // Flutter와 동일하게 snake_case로 변환
    const snakeCaseRequest = {
      approver_id: request.approverId,
      month: request.month,
    };

    logger.dev('관리자 관리 데이터 API 요청 (snake_case):', snakeCaseRequest);

    const response = await api.post<AdminManagementApiResponse>('/leave/admin/management', snakeCaseRequest);

    logger.dev('관리자 관리 데이터 응답:', response.data);
    return response.data;
  }

  /**
   * 관리자용 휴가 승인/반려 처리 - Flutter와 동일
   */
  async processAdminApproval(request: AdminApprovalRequest): Promise<AdminApprovalResponse> {
    logger.dev('관리자 승인/반려 처리 API 요청:', request);

    // Flutter와 동일하게 snake_case로 변환
    const snakeCaseRequest: any = {
      id: request.id,
      approver_id: request.approverId,
      is_approved: request.isApproved,
    };

    // 반려일 때만 reject_message 포함
    if (request.isApproved !== 'APPROVED' && request.rejectMessage) {
      snakeCaseRequest.reject_message = request.rejectMessage;
    }

    logger.dev('관리자 승인/반려 처리 API 요청 (snake_case):', snakeCaseRequest);

    // 취소 상신 여부에 따라 API 엔드포인트 결정 (Flutter와 동일)
    const isCancelRequest = request.isCancel === 1;
    const apiEndpoint = isCancelRequest ? '/leave/admin/approval/cancel' : '/leave/admin/approval';

    logger.dev('API 엔드포인트 선택:', { isCancelRequest, apiEndpoint });

    const response = await api.post<AdminApprovalResponse>(apiEndpoint, snakeCaseRequest);

    logger.dev('관리자 승인/반려 처리 응답:', response.data);
    return response.data;
  }

  /**
   * 관리자용 부서별 달력 조회 - Flutter와 동일
   */
  async getAdminDeptCalendar(request: AdminDeptCalendarRequest): Promise<AdminDeptCalendarResponse> {
    logger.dev('관리자 부서별 달력 API 요청:', request);

    // Flutter와 동일하게 snake_case로 변환
    const snakeCaseRequest = {
      approver_id: request.approverId,
      month: request.month,
    };

    logger.dev('관리자 부서별 달력 API 요청 (snake_case):', snakeCaseRequest);

    const response = await api.post<AdminDeptCalendarResponse>('/leave/admin/management/deptCalendar', snakeCaseRequest);

    logger.dev('관리자 부서별 달력 응답:', response.data);
    return response.data;
  }

  /**
   * 관리자용 연도별 결재 내역 조회 - Flutter와 동일
   */
  async getAdminYearlyLeave(request: AdminYearlyLeaveRequest): Promise<AdminYearlyLeaveResponse> {
    logger.dev('관리자 연도별 결재 데이터 API 요청:', request);

    // Flutter와 동일하게 snake_case로 변환
    const snakeCaseRequest = {
      approver_id: request.approverId,
      month: request.year.toString(), // year를 month로 변경하고 string으로 변환
    };

    logger.dev('관리자 연도별 결재 데이터 API 요청 (snake_case):', snakeCaseRequest);
    logger.dev('서버에 보낼 request body:', JSON.stringify(snakeCaseRequest, null, 2));

    const response = await api.post<AdminYearlyLeaveResponse>('/leave/admin/management/yearly', snakeCaseRequest);

    logger.dev('관리자 연도별 결재 데이터 응답:', response.data);
    return response.data;
  }

  /**
   * 내년 정기휴가 조회 - Flutter와 동일
   */
  async getNextYearLeaveStatus(userId: string): Promise<any> {
    logger.dev('📅 [LeaveService] 내년 정기휴가 조회 API 요청:', { user_id: userId });

    try {
      const response = await api.post('/leave/user/management/nextYear', {
        user_id: userId,
      });

      logger.dev('📅 [LeaveService] 내년 정기휴가 조회 응답:', response.data);
      return response.data;
    } catch (error: any) {
      logger.error('📅 [LeaveService] 내년 정기휴가 조회 실패:', error);
      // Flutter와 동일하게 빈 배열 반환
      return { leaveStatus: [], error: '내년 정기휴가 조회에 실패했습니다.' };
    }
  }

  /**
   * 휴가 부여 상신 - Flutter와 동일
   */
  async submitLeaveGrantRequest(request: {
    userId: string;
    approverId: string;
    targetUserId: string;
    targetUserName: string;
    targetUserDept: string;
    leaveType: string;
    days: number;
    reason: string;
    ccList: { name: string; department: string }[];
  }): Promise<any> {
    logger.dev('🏢 [LeaveService] 휴가 부여 상신 API 요청:', request);

    try {
      // Flutter와 동일한 snake_case 형식으로 변환
      const flutterRequest = {
        user_id: request.userId,
        approver_id: request.approverId,
        target_user_id: request.targetUserId,
        target_user_name: request.targetUserName,
        target_user_dept: request.targetUserDept,
        leave_type: request.leaveType,
        days: request.days,
        reason: request.reason,
        cc_list: request.ccList.map(cc => ({
          name: cc.name,
          department: cc.department
        })),
      };

      const response = await api.post('/leave/grant/request', flutterRequest);

      logger.dev('🏢 [LeaveService] 휴가 부여 상신 응답:', response.data);
      return response.data;
    } catch (error: any) {
      logger.error('🏢 [LeaveService] 휴가 부여 상신 실패:', error);
      throw new Error(`휴가 부여 상신 실패: ${error.message}`);
    }
  }

  /**
   * 휴가 부여 상신 (multipart/form-data) - Flutter CommonElectronicApprovalModal 대응
   */
  async submitLeaveGrantRequestMultipart(request: {
    userId: string;
    department: string;
    approvalDate: string;
    approvalType: string;
    approvalLine: Array<{
      approverId: string;
      approverName: string;
      approvalSeq: number;
    }>;
    title: string;
    leaveType: string;
    grantDays: number;
    reason: string;
    attachmentsList: Array<{ file_name: string; size?: number; url?: string; prefix?: string }>;
    startDate?: string;
    endDate?: string;
    halfDaySlot?: string;
    ccList?: Array<{ user_id?: string; name: string }>;
    files?: File[];
  }): Promise<any> {
    logger.dev('🏢 [LeaveService] 휴가 부여 상신 Multipart 요청:', request);

    const formData = new FormData();
    formData.append('user_id', request.userId);
    formData.append('department', request.department);
    formData.append('approval_date', request.approvalDate);
    formData.append('approval_type', request.approvalType);
    formData.append('title', request.title);
    formData.append('leave_type', request.leaveType);
    formData.append('grant_days', String(request.grantDays));
    formData.append('reason', request.reason);

    if (request.startDate) formData.append('start_date', request.startDate);
    if (request.endDate) formData.append('end_date', request.endDate);
    if (request.halfDaySlot) formData.append('half_day_slot', request.halfDaySlot);

    formData.append('approval_line', JSON.stringify(
      request.approvalLine.map((item) => ({
        approver_id: item.approverId,
        approver_name: item.approverName,
        approval_seq: item.approvalSeq,
      }))
    ));

    formData.append('attachments_list', JSON.stringify(
      request.attachmentsList.map((item) => ({
        file_name: item.file_name,
        size: item.size,
        url: item.url,
        prefix: item.prefix,
      }))
    ));

    if (request.ccList && request.ccList.length > 0) {
      formData.append('cc_list', JSON.stringify(
        request.ccList.map((item) => ({
          user_id: item.user_id,
          name: item.name,
        }))
      ));
    }

    if (request.files && request.files.length > 0) {
      request.files.forEach((file) => {
        formData.append('files', file);
      });
    }

    const response = await axios.post(`${API_BASE_URL}/leave/grant/request`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
      timeout: 30000,
    });

    logger.dev('🏢 [LeaveService] 휴가 부여 상신 Multipart 응답:', response.data);
    return response.data;
  }

  /**
   * 휴가 신청 승인 - Flutter와 동일
   */
  async approveLeaveRequest(requestId: string, approvalData: { approver_id: string; approval_date: string }): Promise<void> {
    logger.dev('✅ [LeaveService] 휴가 신청 승인 API 요청:', { requestId, approvalData });

    try {
      const response = await axios.post(
        `${API_BASE_URL}/leave/admin/approval`,
        {
          id: parseInt(requestId),
          approver_id: approvalData.approver_id,
          is_approved: 'APPROVED',
        },
        {
          headers: {
            'Content-Type': 'application/json',
          },
          timeout: 30000,
        }
      );

      logger.dev('✅ [LeaveService] 휴가 신청 승인 응답:', response.data);

      if (response.status !== 200 && response.status !== 201) {
        throw new Error(`휴가 신청 승인 실패. 상태 코드: ${response.status}`);
      }
    } catch (error: any) {
      logger.error('✅ [LeaveService] 휴가 신청 승인 API 호출 실패:', error);
      throw new Error(`휴가 신청 승인 실패: ${error.message}`);
    }
  }

  /**
   * 휴가 신청 반려 - Flutter와 동일
   */
  async rejectLeaveRequest(requestId: string, rejectionData: { approver_id: string; rejection_reason: string; rejection_date: string }): Promise<void> {
    logger.dev('❌ [LeaveService] 휴가 신청 반려 API 요청:', { requestId, rejectionData });

    try {
      const response = await axios.post(
        `${API_BASE_URL}/leave/admin/approval`,
        {
          id: parseInt(requestId),
          approver_id: rejectionData.approver_id,
          is_approved: 'REJECTED',
          reject_message: rejectionData.rejection_reason,
        },
        {
          headers: {
            'Content-Type': 'application/json',
          },
          timeout: 30000,
        }
      );

      logger.dev('❌ [LeaveService] 휴가 신청 반려 응답:', response.data);

      if (response.status !== 200 && response.status !== 201) {
        throw new Error(`휴가 신청 반려 실패. 상태 코드: ${response.status}`);
      }
    } catch (error: any) {
      logger.error('❌ [LeaveService] 휴가 신청 반려 API 호출 실패:', error);
      throw new Error(`휴가 신청 반려 실패: ${error.message}`);
    }
  }

  // ===============================
  // 승인자 관련 API (Flutter와 동일)
  // ===============================

  /**
   * 승인자 목록 조회 - Flutter와 동일
   */
  async getApproverList(): Promise<ApproverListResponse> {
    logger.dev('승인자 목록 API 요청 시작');

    try {
      // 개발 모드에서도 전체 URL 사용
      const response = await axios.post<any>(
        `${API_BASE_URL}/leave/user/getApprover`,
        {},
        {
          headers: {
            'Content-Type': 'application/json',
          },
          timeout: 30000,
        }
      );
      logger.dev('승인자 목록 응답:', response.data);

      // API 응답이 snake_case로 오므로 camelCase로 변환
      const data = response.data;
      const approverList = (data.approver_list || data.approverList || []).map((item: any) => ({
        approverId: item.approver_id || item.approverId || '',
        approverName: item.approver_name || item.approverName || '',
        jobPosition: item.job_position || item.jobPosition || '',
        department: item.department || '',
      }));

      return {
        approverList: approverList,
        error: data.error,
      };
    } catch (error: any) {
      logger.error('승인자 목록 API 호출 실패:', error);
      return {
        approverList: [],
        error: `승인자 목록 조회 실패: ${error.message}`,
      };
    }
  }

  // ===============================
  // 휴가 취소 상신 API (Flutter와 동일)
  // ===============================

  /**
   * 사용자 휴가 취소 상신 - Flutter와 동일
   *
   * 사용 시점: 승인된 휴가를 취소하고 싶을 때
   * 처리 과정: 취소 사유를 입력하여 결재자에게 취소 상신
   */
  async requestLeaveCancel(request: LeaveCancelRequestPayload): Promise<LeaveCancelResponse> {
    logger.dev('휴가 취소 상신 API 요청:', request);

    try {
      const response = await api.post<LeaveCancelResponse>('/leave/user/cancel/request', {
        id: request.id,
        user_id: request.userId,
        reason: request.reason,
      });

      logger.dev('휴가 취소 상신 응답:', response.data);
      return response.data;
    } catch (error: any) {
      logger.error('휴가 취소 상신 API 호출 실패:', error);
      return {
        error: `휴가 취소 상신에 실패했습니다: ${error.message}`,
        leaveStatus: [],
        monthlyLeaves: [],
        yearlyDetails: [],
        yearlyWholeStatus: [],
      };
    }
  }

  /**
   * 관리자용 취소 승인 처리 (항상 CANCEL_APPROVED 전송)
   */
  async processCancelApproval(request: CancelApprovalRequest): Promise<AdminApprovalResponse> {
    logger.dev('관리자 취소 승인 처리 API 요청:', request);

    try {
      // 항상 CANCEL_APPROVED로 전송
      const snakeCaseRequest = {
        id: request.id,
        approver_id: request.approverId,
        is_approved: 'CANCEL_APPROVED',
      };

      logger.dev('관리자 취소 승인 처리 API 요청 (snake_case):', snakeCaseRequest);

      const response = await api.post<AdminApprovalResponse>('/leave/admin/approval/cancel', snakeCaseRequest);
      logger.dev('관리자 취소 승인 처리 응답:', response.data);
      return response.data;
    } catch (error: any) {
      logger.error('관리자 취소 승인 처리 API 호출 실패:', error);
      return {
        error: `취소 승인 처리에 실패했습니다: ${error.message}`,
        monthlyLeaves: [],
      };
    }
  }

  // ===============================
  // 기존 API (호환성 유지용)
  // ===============================

  /**
   * 휴가 신청 내역 조회 (기존 API) - Flutter와 동일
   */
  async getLeaveRequestHistory(userId: string, year: number, status?: string): Promise<any[]> {
    logger.dev('휴가 신청 내역 API 요청:', { userId, year, status });

    try {
      const response = await api.post<any>(`/api/leave/requests/${userId}`, {
        year: year,
        ...(status && { status: status }),
      });

      logger.dev('휴가 신청 내역 응답:', response.data);

      // API 응답이 snake_case로 오므로 camelCase로 변환
      const requests = (response.data.requests || []).map((item: any) => ({
        id: item.id || '',
        applicantName: item.applicant_name || item.applicantName || '',
        department: item.department || '',
        vacationType: item.vacation_type || item.vacationType || '',
        startDate: item.start_date || item.startDate || '',
        endDate: item.end_date || item.endDate || '',
        days: item.days || 0,
        reason: item.reason || '',
        status: item.status || '',
        submittedDate: item.submitted_date || item.submittedDate || '',
        approverComment: item.approver_comment || item.approverComment || '',
      }));

      return requests;
    } catch (error: any) {
      logger.error('휴가 신청 내역 API 호출 실패:', error);
      return [];
    }
  }

  /**
   * 부서원 목록 조회 (기존 API) - Flutter와 동일
   */
  async getDepartmentMembers(userId: string): Promise<any[]> {
    logger.dev('부서원 목록 API 요청:', { userId });

    try {
      const response = await api.post<any>('/api/leave/department/members', {
        userId: userId,
      });

      logger.dev('부서원 목록 응답:', response.data);

      // API 응답이 snake_case로 오므로 camelCase로 변환
      const members = (response.data.members || []).map((item: any) => ({
        id: item.id || '',
        name: item.name || '',
        department: item.department || '',
        position: item.position || '',
        profileImageUrl: item.profile_image_url || item.profileImageUrl || '',
      }));

      return members;
    } catch (error: any) {
      logger.error('부서원 목록 API 호출 실패:', error);
      return [];
    }
  }

  /**
   * 부서 휴가 내역 조회 (기존 API) - Flutter와 동일
   */
  async getDepartmentLeaveHistory(userId: string, year: number, memberId?: string): Promise<Record<string, any[]>> {
    logger.dev('부서 휴가 내역 API 요청:', { userId, year, memberId });

    try {
      const response = await api.post<any>('/api/leave/department/history', {
        userId: userId,
        year: year,
        ...(memberId && { memberId: memberId }),
      });

      logger.dev('부서 휴가 내역 응답:', response.data);

      // API 응답이 snake_case로 오므로 camelCase로 변환
      const departmentHistory = response.data.departmentHistory || {};
      const result: Record<string, any[]> = {};

      Object.keys(departmentHistory).forEach((memberId) => {
        const requests = (departmentHistory[memberId] || []).map((item: any) => ({
          id: item.id || '',
          applicantName: item.applicant_name || item.applicantName || '',
          department: item.department || '',
          vacationType: item.vacation_type || item.vacationType || '',
          startDate: item.start_date || item.startDate || '',
          endDate: item.end_date || item.endDate || '',
          days: item.days || 0,
          reason: item.reason || '',
          status: item.status || '',
          submittedDate: item.submitted_date || item.submittedDate || '',
          approverComment: item.approver_comment || item.approverComment || '',
        }));
        result[memberId] = requests;
      });

      return result;
    } catch (error: any) {
      logger.error('부서 휴가 내역 API 호출 실패:', error);
      return {};
    }
  }

  /**
   * 휴가 신청 (기존 API - 호환성 유지) - Flutter와 동일
   */
  async submitLeaveRequestLegacy(request: {
    userId: string;
    vacationType: string;
    startDate: string;
    endDate: string;
    days: number;
    reason: string;
  }): Promise<any> {
    logger.dev('휴가 신청 (기존 API) 요청:', request);

    try {
      const response = await api.post<any>('/api/leave/requests', {
        userId: request.userId,
        vacationType: request.vacationType,
        startDate: request.startDate,
        endDate: request.endDate,
        days: request.days,
        reason: request.reason,
      });

      logger.dev('휴가 신청 (기존 API) 응답:', response.data);
      return response.data;
    } catch (error: any) {
      logger.error('휴가 신청 (기존 API) 호출 실패:', error);
      throw error;
    }
  }

  /**
   * 휴가 취소 (새로운 API) - Flutter와 동일
   */
  async cancelLeaveRequestNew(request: LeaveCancelRequest): Promise<LeaveCancelResponse> {
    logger.dev('휴가 취소 API 요청:', request);

    const flutterRequest: any = {
      id: request.id,
      user_id: request.userId,
    };

    logger.dev('휴가 취소 API 요청 (Flutter 형식):', flutterRequest);

    try {
      const response = await api.post<LeaveCancelResponse>('/leave/user/cancel', flutterRequest);
      logger.dev('휴가 취소 응답:', response.data);
      return response.data;
    } catch (error: any) {
      logger.error('휴가 취소 API 에러:', error);

      // 서버 에러 메시지 추출
      const errorMessage = error.response?.data?.error
        || error.response?.data?.message
        || error.response?.data?.detail
        || error.message
        || '휴가 취소에 실패했습니다.';

      logger.error('휴가 취소 서버 에러 메시지:', errorMessage);

      // 에러 객체에 메시지 추가
      const enhancedError = new Error(errorMessage);
      (enhancedError as any).response = error.response;
      (enhancedError as any).config = error.config;
      throw enhancedError;
    }
  }

  /**
   * 휴가 취소 (기존 API - 호환성 유지) - Flutter와 동일
   */
  async cancelLeaveRequestLegacy(requestId: string, userId: string): Promise<any> {
    logger.dev('휴가 취소 (기존 API) 요청:', { requestId, userId });

    try {
      const response = await api.post<any>(`/api/leave/requests/${requestId}/cancel`, {
        userId: userId,
      });

      logger.dev('휴가 취소 (기존 API) 응답:', response.data);
      return response.data;
    } catch (error: any) {
      logger.error('휴가 취소 (기존 API) 호출 실패:', error);
      throw error;
    }
  }

  /**
   * 관리자 승인 대기 목록 조회 (기존 API) - Flutter와 동일
   */
  async getPendingApprovals(managerId: string): Promise<any[]> {
    logger.dev('관리자 승인 대기 목록 API 요청:', { managerId });

    try {
      const response = await api.post<any>('/api/leave/admin/pending', {
        managerId: managerId,
      });

      logger.dev('관리자 승인 대기 목록 응답:', response.data);

      // API 응답이 snake_case로 오므로 camelCase로 변환
      const requests = (response.data.requests || response.data || []).map((item: any) => ({
        id: item.id || '',
        applicantName: item.applicant_name || item.applicantName || '',
        department: item.department || '',
        vacationType: item.vacation_type || item.vacationType || '',
        startDate: item.start_date || item.startDate || '',
        endDate: item.end_date || item.endDate || '',
        days: item.days || 0,
        reason: item.reason || '',
        status: item.status || '',
        submittedDate: item.submitted_date || item.submittedDate || '',
        approverComment: item.approver_comment || item.approverComment || '',
      }));

      return requests;
    } catch (error: any) {
      logger.error('관리자 승인 대기 목록 API 호출 실패:', error);
      return [];
    }
  }

  /**
   * 관리자 결재 대기 목록 조회 (모달용) - Flutter와 동일
   * 
   * 사용 시점: leave.approval 큐 알림 클릭 시
   * 반환 데이터: 현재 대기 중인 결재 건만 조회
   */
  async getAdminWaitingLeaves(approverId: string): Promise<AdminWaitingLeave[]> {
    logger.dev('🔍 [LeaveService] 관리자 결재 대기 목록 API 요청 시작');
    logger.dev('🔍 [LeaveService] 전달받은 approverId 파라미터:', approverId);

    try {
      const response = await api.post<any>('/leave/admin/management/waitingLeaves', {
        approver_id: approverId,
      });

      logger.dev('🔍 [LeaveService] 응답 상태 코드:', response.status);
      logger.dev('🔍 [LeaveService] 응답 바디:', response.data);

      const data = response.data;
      const waitingLeaves = data.waiting_leaves || data.waitingLeaves || [];

      if (waitingLeaves && waitingLeaves.length > 0) {
        logger.dev('🔍 [LeaveService] 대기 중인 결재 건:', waitingLeaves.length, '개');
      } else {
        logger.dev('⚠️ [LeaveService] waiting_leaves가 null이거나 비어있습니다.');
      }

      // API 응답이 snake_case로 오므로 camelCase로 변환
      return waitingLeaves.map((item: any): AdminWaitingLeave => ({
        id: item.id || 0,
        status: item.status || '',
        name: item.name || '',
        department: item.department || '',
        jobPosition: item.job_position || item.jobPosition || '',
        leaveType: item.leave_type || item.leaveType || '',
        startDate: item.start_date || item.startDate || '',
        endDate: item.end_date || item.endDate || '',
        halfDaySlot: item.half_day_slot || item.halfDaySlot || '',
        totalDays: item.total_days || item.totalDays || 0,
        remainDays: item.remain_days || item.remainDays || 0,
        workdaysCount: item.workdays_count || item.workdaysCount || 0,
        requestedDate: item.requested_date || item.requestedDate || '',
        reason: item.reason || '',
        joinDate: item.join_date || item.joinDate || '',
        isCancel: item.is_cancel || item.isCancel || 0,
      }));
    } catch (error: any) {
      logger.error('❌ [LeaveService] 관리자 결재 대기 목록 API 호출 실패:', error);
      logger.error('❌ [LeaveService] 에러 응답:', error.response?.data);
      return [];
    }
  }

  // ===============================
  // 결재라인 저장/불러오기 API (Flutter와 동일)
  // ===============================

  /**
   * 결재라인 저장
   * URL: https://ai2great.com:8060/leave/user/setApprovalLine
   */
  async saveApprovalLine(request: {
    userId: string;
    approvalLine: Array<{
      approverId: string;
      nextApproverId: string;
      approvalSeq: number;
      approverName: string;
    }>;
    ccList: Array<{
      name: string;
      userId: string;
      department?: string;
      jobPosition?: string;
    }>;
  }): Promise<{ error?: string }> {
    try {
      // snake_case로 변환
      const requestBody = {
        user_id: request.userId,
        approval_line: request.approvalLine.map((item) => ({
          approver_id: item.approverId,
          next_approver_id: item.nextApproverId,
          approval_seq: item.approvalSeq,
          approver_name: item.approverName,
        })),
        cc_list: request.ccList.map((item) => ({
          user_id: item.userId,
          name: item.name,
          department: item.department || '',
          job_position: item.jobPosition || '',
        })),
      };

      const url = `${API_BASE_URL}/leave/user/setApprovalLine`;
      logger.dev('💾 결재라인 저장 API 호출');
      logger.dev('  - URL:', url);
      logger.dev('  - Request:', JSON.stringify(requestBody, null, 2));

      const response = await axios.post<{ error?: string }>(
        url,
        requestBody,
        {
          headers: {
            'Content-Type': 'application/json',
          },
          timeout: 30000,
        }
      );

      logger.dev('✅ 결재라인 저장 성공');
      logger.dev('  - Response:', response.data);
      return response.data;
    } catch (error: any) {
      logger.error('결재라인 저장 실패:', error.message);
      return {
        error: `결재라인 저장에 실패했습니다: ${error.message}`,
      };
    }
  }

  /**
   * 결재라인 불러오기
   * URL: https://ai2great.com:8060/leave/user/getApprovalLine
   */
  async loadApprovalLine(userId: string): Promise<{
    approvalLine?: Array<{
      approverId: string;
      nextApproverId: string;
      approvalSeq: number;
      approverName: string;
    }>;
    ccList?: Array<{
      name: string;
      userId: string;
    }>;
    error?: string;
  }> {
    const url = `${API_BASE_URL}/leave/user/getApprovalLine`;
    logger.dev('🔍 결재라인 불러오기 API 호출');
    logger.dev('  - URL:', url);
    logger.dev('  - user_id:', userId);

    try {
      const response = await axios.post<any>(
        url,
        {
          user_id: userId,
        },
        {
          headers: {
            'Content-Type': 'application/json',
          },
          timeout: 30000,
        }
      );

      logger.dev('✅ 결재라인 불러오기 성공');
      logger.dev('  - Response:', response.data);

      const data = response.data;

      // snake_case를 camelCase로 변환
      const approvalLine = (data.approval_line || []).map((item: any) => ({
        approverId: item.approver_id || item.approverId || '',
        nextApproverId: item.next_approver_id || item.nextApproverId || '',
        approvalSeq: item.approval_seq || item.approvalSeq || 0,
        approverName: item.approver_name || item.approverName || '',
      }));

      const ccList = (data.cc_list || []).map((item: any) => ({
        name: item.name || '',
        userId: item.user_id || item.userId || '',
      }));

      return {
        approvalLine,
        ccList,
        error: data.error,
      };
    } catch (error: any) {
      // 404는 저장된 결재라인이 없는 정상 케이스
      if (error.response?.status === 404) {
        logger.dev('⚠️ 404: 저장된 결재라인이 없습니다 (서버에 데이터 없음)');
        return { approvalLine: [], ccList: [] };
      }
      logger.error('❌ 결재라인 불러오기 실패');
      logger.error('  - Status:', error.response?.status);
      logger.error('  - Message:', error.message);
      logger.error('  - Response:', error.response?.data);
      return {
        error: `결재라인 불러오기에 실패했습니다: ${error.message}`,
      };
    }
  }

  /**
   * 전자결재 결재라인 저장 - Flutter /eapproval/setApprovalLine 대응
   */
  async saveEApprovalLine(request: {
    userId: string;
    approvalType: string;
    approvalLine: Array<{
      userId?: string;
      approverId: string;
      approverName: string;
      department?: string;
      jobPosition?: string;
      approvalSeq: number;
    }>;
    ccList?: Array<{ user_id?: string; name: string }>;
  }): Promise<any> {
    const url = `${API_BASE_URL}/eapproval/setApprovalLine`;

    const response = await axios.post(url, {
      user_id: request.userId,
      approval_type: request.approvalType,
      approval_line: request.approvalLine.map((item) => ({
        user_id: item.userId,
        approver_id: item.approverId,
        approver_name: item.approverName,
        department: item.department,
        job_position: item.jobPosition,
        approval_seq: item.approvalSeq,
      })),
      cc_list: request.ccList || [],
    }, {
      headers: { 'Content-Type': 'application/json' },
      timeout: 30000,
    });

    return response.data;
  }

  /**
   * 전자결재 결재라인 조회 - Flutter /eapproval/getApprovalLine 대응
   */
  async loadEApprovalLine(userId: string, approvalType: string): Promise<{
    approvalLine: Array<{
      approverId: string;
      approverName: string;
      approvalSeq: number;
      department?: string;
      jobPosition?: string;
      userId?: string;
    }>;
    ccList: Array<{ user_id?: string; name: string }>;
  }> {
    const url = `${API_BASE_URL}/eapproval/getApprovalLine`;

    const response = await axios.post(url, {
      user_id: userId,
      approval_type: approvalType,
    }, {
      headers: { 'Content-Type': 'application/json' },
      timeout: 30000,
    });

    const data = response.data || {};
    return {
      approvalLine: (data.approval_line || []).map((item: any) => ({
        approverId: item.approver_id || item.approverId || '',
        approverName: item.approver_name || item.approverName || '',
        approvalSeq: item.approval_seq || item.approvalSeq || 0,
        department: item.department,
        jobPosition: item.job_position || item.jobPosition,
        userId: item.user_id || item.userId,
      })),
      ccList: (data.cc_list || []).map((item: any) => ({
        user_id: item.user_id || item.userId,
        name: item.name,
      })),
    };
  }

  /**
   * 관리자 대기 휴가 건수 조회
   */
  async getWaitingLeavesCount(approverId: string): Promise<number> {
    try {
      logger.dev('[LeaveService] 대기 건수 조회 API 호출:', {
        url: `${API_BASE_URL}/leave/admin/management/waitingLeaves`,
        approverId,
      });

      const response = await axios.post<{ waiting_leaves: AdminWaitingLeave[]; error?: string }>(
        `${API_BASE_URL}/leave/admin/management/waitingLeaves`,
        {
          approver_id: approverId,
        },
        {
          headers: {
            'Content-Type': 'application/json',
          },
          timeout: 10000,
        }
      );

      logger.dev('[LeaveService] 대기 건수 API 응답:', response.data);

      const data = response.data;
      if (data.error) {
        logger.error('[LeaveService] 대기 건수 조회 에러:', data.error);
        return 0;
      }

      const waitingLeaves = data.waiting_leaves || (data as any).waitingLeaves;
      logger.dev('[LeaveService] waiting_leaves 데이터:', waitingLeaves);

      const count = waitingLeaves?.length || 0;
      logger.dev('[LeaveService] 최종 대기 건수:', count);
      return count;
    } catch (error: any) {
      logger.error('[LeaveService] 대기 건수 조회 실패:', error);
      logger.error('[LeaveService] 에러 상세:', error.response?.data);
      return 0;
    }
  }

  /**
   * 휴가 부여 내역 조회 - Flutter와 동일
   */
  async getGrantRequestList(userId: string): Promise<any> {
    logger.dev('휴가 부여 내역 API 요청:', { user_id: userId });

    try {
      const response = await api.post<any>('/leave/user/getGrantRequestList', {
        user_id: userId,
      });

      logger.dev('휴가 부여 내역 응답:', response.data);

      const data = response.data;
      const leaveGrants = (data.leave_grants || data.leaveGrants || []).map((item: any) => ({
        id: item.id || 0,
        title: item.title || '',
        reason: item.reason || '',
        status: item.status || '',
        leaveType: item.leave_type || item.leaveType || '',
        grantDays: item.grant_days || item.grantDays || 0,
        approvalDate: item.approval_date ? new Date(item.approval_date) : null,
        procDate: item.proc_date ? new Date(item.proc_date) : null,
        comment: item.comment || '',
        isManager: item.is_manager || item.isManager || 0,
        attachmentsList: item.attachments_list || item.attachmentsList || [],
      }));

      return {
        leaveGrants: leaveGrants,
        error: data.error || undefined,
      };
    } catch (err: any) {
      logger.error('휴가 부여 내역 API 호출 실패:', err);
      return {
        leaveGrants: [],
        error: err.response?.data?.error || err.message || '휴가 부여 내역 조회에 실패했습니다.',
      };
    }
  }
}

export default new LeaveService();
