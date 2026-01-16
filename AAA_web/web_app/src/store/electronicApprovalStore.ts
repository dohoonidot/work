import { create } from 'zustand';
import type { EApprovalDraftData } from '../types/eapproval';

interface ElectronicApprovalState {
  isOpen: boolean;
  isLoading: boolean;
  pendingData: EApprovalDraftData | null;
  openPanel: (data?: EApprovalDraftData) => void;
  closePanel: () => void;
  setLoading: (loading: boolean) => void;
  clearPendingData: () => void;
}

export const useElectronicApprovalStore = create<ElectronicApprovalState>((set) => ({
  isOpen: false,
  isLoading: false,
  pendingData: null,
  openPanel: (data) => {
    set({
      isOpen: true,
      isLoading: !!data,
      pendingData: data ?? null,
    });

    if (data) {
      setTimeout(() => set({ isLoading: false }), 10000);
    }
  },
  closePanel: () => {
    set({ isOpen: false, isLoading: false });
    setTimeout(() => set({ pendingData: null }), 300);
  },
  setLoading: (loading) => set({ isLoading: loading }),
  clearPendingData: () => set({ pendingData: null }),
}));
