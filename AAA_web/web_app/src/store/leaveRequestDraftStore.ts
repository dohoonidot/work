/**
 * 휴가 신청 초안 팝업 상태 관리
 * Flutter의 leave_modal_provider.dart와 vacation_data_provider.dart 참조
 */

import { create } from 'zustand';
import type {
  VacationRequestData,
  ApprovalLineData,
  CcPersonData,
  LeaveStatusData,
} from '../types/leaveRequest';

interface LeaveRequestDraftState {
  // 패널 표시 상태
  isOpen: boolean;
  isLoading: boolean; // AI 작성중 로딩 상태

  // 폼 데이터
  formData: VacationRequestData | null;

  // UI 상태
  isLeaveBalanceExpanded: boolean; // 휴가 현황 섹션 확장 여부
  isSequentialApproval: boolean; // 순차결재 여부

  // Actions
  openPanel: (data: VacationRequestData) => void;
  closePanel: () => void;
  setLoading: (loading: boolean) => void;
  updateFormData: (data: Partial<VacationRequestData>) => void;
  toggleLeaveBalance: () => void;
  setSequentialApproval: (isSequential: boolean) => void;

  // 승인자/참조자 관리
  setApprovalLine: (approvers: ApprovalLineData[]) => void;
  setCcList: (ccList: CcPersonData[]) => void;

  // 초기화
  reset: () => void;
}

const initialFormData: VacationRequestData = {
  userId: '',
  startDate: '',
  endDate: '',
  reason: '',
  leaveType: '',
  halfDaySlot: 'ALL',
  approvalLine: [],
  ccList: [],
  leaveStatus: [],
  useNextYearLeave: false,
};

export const useLeaveRequestDraftStore = create<LeaveRequestDraftState>((set, get) => ({
  isOpen: false,
  isLoading: false,
  formData: null,
  isLeaveBalanceExpanded: true,
  isSequentialApproval: false,

  openPanel: (data) => {
    console.log('[Leave Draft Store] 패널 열기:', data);
    set({
      isOpen: true,
      isLoading: true, // Flutter처럼 처음엔 로딩 상태
      formData: {
        ...initialFormData,
        ...data,
      },
    });

    // Flutter처럼 2초 후 로딩 완료
    setTimeout(() => {
      set({ isLoading: false });
    }, 2000);
  },

  closePanel: () => {
    console.log('[Leave Draft Store] 패널 닫기');
    set({
      isOpen: false,
      isLoading: false,
    });

    // 패널이 완전히 닫힌 후 폼 데이터 초기화 (애니메이션 고려)
    setTimeout(() => {
      set({ formData: null });
    }, 300);
  },

  setLoading: (loading) => {
    set({ isLoading: loading });
  },

  updateFormData: (data) => {
    const currentFormData = get().formData;
    if (currentFormData) {
      set({
        formData: {
          ...currentFormData,
          ...data,
        },
      });
    }
  },

  toggleLeaveBalance: () => {
    set((state) => ({
      isLeaveBalanceExpanded: !state.isLeaveBalanceExpanded,
    }));
  },

  setSequentialApproval: (isSequential) => {
    set({ isSequentialApproval: isSequential });
  },

  setApprovalLine: (approvers) => {
    const currentFormData = get().formData;
    if (currentFormData) {
      set({
        formData: {
          ...currentFormData,
          approvalLine: approvers,
        },
      });
    }
  },

  setCcList: (ccList) => {
    const currentFormData = get().formData;
    if (currentFormData) {
      set({
        formData: {
          ...currentFormData,
          ccList,
        },
      });
    }
  },

  reset: () => {
    set({
      isOpen: false,
      isLoading: false,
      formData: null,
      isLeaveBalanceExpanded: true,
      isSequentialApproval: false,
    });
  },
}));
