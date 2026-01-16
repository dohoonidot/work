// 휴가관리 관련 타입 정의 (Flutter 모델 기반)

export interface LeaveStatus {
  leaveType: string;
  totalDays: number;
  remainDays: number;
}

export interface ApprovalStatus {
  requested: number;
  approved: number;
  rejected: number;
}

export interface YearlyDetail {
  id: number;
  status: string;
  leaveType: string;
  startDate: string;
  endDate: string;
  workdaysCount: number;
  requestedDate: string;
  reason: string;
  rejectMessage: string;
  isCancel?: number; // 0: 일반 상신, 1: 취소 상신
}

export interface YearlyWholeStatus {
  leaveType: string;
  totalDays: number;
  m01: number;
  m02: number;
  m03: number;
  m04: number;
  m05: number;
  m06: number;
  m07: number;
  m08: number;
  m09: number;
  m10: number;
  m11: number;
  m12: number;
  remainDays: number;
}

export interface MonthlyLeave {
  status: string;
  leaveType: string;
  startDate: string;
  endDate: string;
  halfDaySlot: string;
  reason: string;
  rejectMessage: string;
}

export interface LeaveManagementData {
  leaveStatus: LeaveStatus[];
  approvalStatus: ApprovalStatus;
  yearlyDetails: YearlyDetail[];
  yearlyWholeStatus: YearlyWholeStatus[];
  monthlyLeaves: MonthlyLeave[];
}

// 휴가 신청 관련 타입
export interface CcPerson {
  name: string;
  department: string;
  userId?: string; // 참조자 ID (선택적)
}

// 순차결재 승인선 타입 (Flutter와 동일)
export interface LeaveRequestApprovalLine {
  approverId: string;
  nextApproverId: string; // 다음 승인자 ID (마지막은 빈 문자열)
  approvalSeq: number; // 순차 번호 (1부터 시작)
  approverName: string;
}

export interface LeaveRequestRequest {
  userId: string;
  leaveType: string;
  startDate: string;
  endDate: string;
  approverIds?: string[]; // 일반 승인자 ID 리스트 (순차결재가 아닐 때)
  approvalLine?: LeaveRequestApprovalLine[]; // 순차결재 승인선 (순차결재일 때)
  ccList: CcPerson[];
  reason: string;
  halfDaySlot?: string;
  isNextYear?: number;
}

export interface LeaveRequestResponse {
  error?: string;
}

// 휴가 취소 관련 타입
export interface LeaveCancelRequest {
  id: number;
  userId: string;
}

export interface LeaveCancelResponse {
  approvalStatus?: ApprovalStatus;
  error?: string;
  leaveStatus: LeaveStatus[];
  monthlyLeaves: MonthlyLeave[];
  yearlyDetails: YearlyDetail[];
  yearlyWholeStatus: YearlyWholeStatus[];
}

// 월별 달력 관련 타입
export interface MonthlyCalendarRequest {
  userId: string;
  month: string;
}

export interface MonthlyCalendarResponse {
  error?: string;
  monthlyLeaves: MonthlyLeave[];
}

// 연도별 휴가 내역 관련 타입
export interface YearlyLeaveRequest {
  userId: string;
  year: number; // 연도값 (API에서는 month 필드로 전송)
}

export interface YearlyLeaveResponse {
  error?: string;
  yearlyDetails: YearlyDetail[];
  yearlyWholeStatus: YearlyWholeStatus[];
}

// 부서 휴가 현황 관련 타입
export interface TotalCalendarLeave {
  name: string;
  department: string;
  startDate: string;
  endDate: string;
  leaveType: string;
}

export interface TotalCalendarResponse {
  error?: string;
  monthlyLeaves: TotalCalendarLeave[];
}

// 관리자 관련 타입
export interface AdminWaitingLeave {
  id: number;
  status: string;
  name: string;
  department: string;
  jobPosition: string;
  leaveType: string;
  startDate: string;
  endDate: string;
  halfDaySlot: string;
  totalDays: number;
  remainDays: number;
  workdaysCount: number;
  requestedDate: string;
  reason: string;
  joinDate: string;
  isCancel?: number; // 0: 일반 상신, 1: 취소 상신
}

export interface AdminMonthlyLeave {
  id: number;
  status: string;
  name: string;
  department: string;
  jobPosition: string;
  leaveType: string;
  startDate: string;
  endDate: string;
  halfDaySlot: string;
  totalDays: number;
  remainDays: number;
  workdaysCount: number;
  requestedDate: string;
  reason: string;
  joinDate: string;
}

export interface AdminApprovalStatus {
  requested: number;
  approved: number;
  rejected: number;
}

export interface AdminManagementRequest {
  approverId: string;
  month: string;
}

export interface AdminManagementResponse {
  error?: string;
  approvalStatus?: AdminApprovalStatus;
  monthlyLeaves: AdminMonthlyLeave[];
  waitingLeaves: AdminWaitingLeave[];
}

export interface AdminApprovalRequest {
  id: number;
  approverId: string;
  isApproved: string; // "APPROVED" or "REJECTED"
  rejectMessage?: string;
  isCancel?: number; // 0: 일반 승인/반려, 1: 취소 승인/반려
}

// 취소 승인 요청 (항상 승인만 가능)
export interface CancelApprovalRequest {
  id: number;
  approverId: string;
}

export interface AdminApprovalResponse {
  error?: string;
  monthlyLeaves: AdminMonthlyLeave[];
}

export interface AdminDeptCalendarRequest {
  approverId: string;
  month: string;
}

export interface AdminDeptCalendarResponse {
  error?: string;
  monthlyLeaves: AdminMonthlyLeave[];
}

export interface AdminYearlyLeaveRequest {
  approverId: string;
  year: number;
}

export interface AdminYearlyLeaveResponse {
  error?: string;
  approval_status: AdminApprovalStatus[];
  yearly_details: AdminWaitingLeave[];
}

// 휴가 신청 상태 타입 정의 (erasableSyntaxOnly 대응)
export const LeaveRequestStatus = {
  PENDING: 'REQUESTED',
  APPROVED: 'APPROVED',
  REJECTED: 'REJECTED',
  CANCELLED: 'CANCELLED',
} as const;

export type LeaveRequestStatusType = typeof LeaveRequestStatus[keyof typeof LeaveRequestStatus];

export const LeaveRequestStatusLabels: Record<LeaveRequestStatusType, string> = {
  [LeaveRequestStatus.PENDING]: '대기중',
  [LeaveRequestStatus.APPROVED]: '승인됨',
  [LeaveRequestStatus.REJECTED]: '반려됨',
  [LeaveRequestStatus.CANCELLED]: '취소됨',
};

export const LeaveRequestStatusColors: Record<LeaveRequestStatusType, string> = {
  [LeaveRequestStatus.PENDING]: '#2196F3',
  [LeaveRequestStatus.APPROVED]: '#4CAF50',
  [LeaveRequestStatus.REJECTED]: '#F44336',
  [LeaveRequestStatus.CANCELLED]: '#9E9E9E',
};

// 휴가 잔여량 정보 모델 (Flutter와 동일)
export interface LeaveBalance {
  type: string;
  total: number;
  used: number;
  remaining: number;
}

// 달력 관련 타입
export interface CalendarLeave {
  date: string;
  leaveType: string;
  status: string;
  reason?: string;
  halfDaySlot?: string;
}

export interface CalendarDay {
  date: Date;
  isCurrentMonth: boolean;
  isToday: boolean;
  leaves: MonthlyLeave[];
}

// 관리자 페이지용 타입 정의
export interface AdminLeaveRequest {
  request_id: string;
  user_id: string;
  user_name: string;
  leave_type: string;
  start_date: string;
  end_date: string;
  days: number;
  reason: string;
  status: 'REQUESTED' | 'APPROVED' | 'REJECTED';
  request_date: string;
  approver_id?: string;
  approver_name?: string;
  approval_date?: string;
  rejection_reason?: string;
}

export interface AdminManagementData {
  pending_requests: AdminLeaveRequest[];
  all_requests: AdminLeaveRequest[];
  department_members: Array<{
    user_id: string;
    user_name: string;
    department: string;
  }>;
  monthly_stats: {
    total_requests: number;
    approved_requests: number;
    rejected_requests: number;
    pending_requests: number;
  };
}

// 실제 API 응답 구조 (Flutter에서 받는 실제 데이터)
export interface AdminManagementApiResponse {
  approval_status: Array<{
    status: string;
    count: number;
  }>;
  error: string | null;
  monthly_leaves: AdminLeaveRequest[];
  waiting_leaves: AdminLeaveRequest[];
}

// 승인자 관련 타입 (Flutter와 동일)
export interface Approver {
  approverId: string;
  approverName: string;
  jobPosition: string;
  department: string;
}

export interface ApproverListResponse {
  approverList: Approver[];
  error?: string;
}

// 휴가 취소 상신 관련 타입
export interface LeaveCancelRequestPayload {
  id: number;
  userId: string;
  reason: string;
}

// 내년 정기휴가 관련 타입
export interface NextYearLeaveStatus {
  leaveType: string;
  totalDays: number;
  remainDays: number;
}

export interface NextYearLeaveStatusResponse {
  error?: string;
  leaveStatus: NextYearLeaveStatus[];
}

// 부서원 휴가 현황 관련 타입
export interface EmployeeLeaveStatus {
  id: number;
  status: string;
  name: string;
  department: string;
  jobPosition: string;
  leaveType: string;
  startDate: string;
  endDate: string;
  halfDaySlot: string;
  totalDays: number;
  usedDays: number;
  remainDays: number;
  workdaysCount: number;
  requestedDate: string;
  reason: string;
  joinDate: string;
}

export interface DepartmentLeaveStatusResponse {
  employees: EmployeeLeaveStatus[];
  error?: string;
}

// AI 휴가 추천 관련 타입 (Flutter 모델 기반)
export interface ConsecutivePeriod {
  startDate: string;
  endDate: string;
  days: number;
  description: string;
}

export interface LeavesData {
  monthlyUsage: Record<string, number>;
}

export interface WeekdayCountsData {
  counts: Record<string, number>;
}

export interface VacationRecommendationResponse {
  reasoningContents: string;
  finalResponseContents: string;
  recommendedDates: string[];
  monthlyDistribution: Record<string, number>;
  consecutivePeriods: ConsecutivePeriod[];
  isComplete: boolean;
  streamingProgress: number;
  leavesData?: LeavesData;
  weekdayCountsData?: WeekdayCountsData;
  holidayAdjacentUsageRate?: number;
  holidayAdjacentDays?: number;
  totalLeaveDays?: number;
  isAfterAnalysisMarker?: boolean;
  markdownBuffer?: string;
}

// 휴가 부여 내역 관련 타입 (Flutter 모델 기반)
export interface LeaveGrantRequestItem {
  id: number;
  title: string;
  reason: string;
  status: string;
  leaveType: string;
  grantDays: number;
  approvalDate: Date | null;
  procDate: Date | null;
  comment: string;
  isManager: number;
  attachmentsList: any[];
}

export interface LeaveGrantRequestListResponse {
  leaveGrants: LeaveGrantRequestItem[];
  error?: string;
}

