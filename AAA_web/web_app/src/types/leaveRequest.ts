/**
 * 휴가 신청 관련 타입 정의
 * Flutter의 vacation_data_provider.dart 참조
 */

// 승인자 정보
export interface ApprovalLineData {
  approverName: string;
  approverId: string;
  approvalSeq: number; // 순차결재 순서 (1부터 시작)
}

// 참조자 정보
export interface CcPersonData {
  name: string;
  userId: string;
  department?: string;
}

// 휴가 잔여 현황
export interface LeaveStatusData {
  leaveType: string; // 휴가 종류
  totalDays: number; // 총 일수
  remainDays: number; // 남은 일수
}

// 휴가 신청 데이터 (Flutter의 VacationRequestData)
export interface VacationRequestData {
  userId: string; // 신청자 ID
  startDate: string; // 시작일 (ISO 형식: YYYY-MM-DD)
  endDate: string; // 종료일 (ISO 형식: YYYY-MM-DD)
  reason: string; // 사유
  leaveType: string; // 휴가 종류
  halfDaySlot?: 'ALL' | 'AM' | 'PM'; // 반차 여부 (전일/오전/오후)
  approvalLine?: ApprovalLineData[]; // 승인자 목록
  ccList?: CcPersonData[]; // 참조자 목록
  leaveStatus?: LeaveStatusData[]; // 휴가 잔여 현황
  useNextYearLeave?: boolean; // 내년 정기휴가 사용 여부
}

// 휴가 종류 옵션
export interface LeaveTypeOption {
  value: string; // 휴가 종류 값
  label: string; // 표시 이름
  remainDays?: number; // 남은 일수
  totalDays?: number; // 총 일수
}

// 서버 트리거 데이터 (SSE에서 수신)
export interface LeaveTriggerData {
  user_id: string;
  start_date: string;
  end_date: string;
  leave_type: string;
  reason?: string;
  half_day_slot?: string;
  cc_list?: Array<{
    name: string;
    user_id: string;
  }>;
  approval_line?: Array<{
    approver_id: string;
    approver_name: string;
    approval_seq: number;
    next_approver_id: string;
  }>;
  leave_status?: Array<{
    leave_type: string;
    total_days: number;
    remain_days: number;
  }>;
  partial_data?: boolean;
  follow_up_required?: boolean;
  follow_up_message?: string;
}
