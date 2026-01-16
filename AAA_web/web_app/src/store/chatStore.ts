import { create } from 'zustand';
import type { Archive, ChatMessage } from '../types';
import chatService from '../services/chatService';
import authService from '../services/authService';

// 아카이브 타입 정의
export type ArchiveType = '' | 'code' | 'sap';

// 채팅방 종류
export const ARCHIVE_NAMES = {
  WORK: '사내업무',
  CODE: '코딩어시스턴트',
  SAP: 'SAP어시스턴트',
  CHATBOT: 'AI Chatbot',
} as const;

// 아카이브 순서
export const getArchiveOrder = (archive: Archive): number => {
  const name = archive.archive_name;
  const type = archive.archive_type;

  if (name === ARCHIVE_NAMES.WORK || (type === '' && name.includes('사내업무'))) {
    return 1;
  } else if (name === ARCHIVE_NAMES.CODE || type === 'code') {
    return 2;
  } else if (name === ARCHIVE_NAMES.SAP || type === 'sap') {
    return 3;
  } else if (name === ARCHIVE_NAMES.CHATBOT) {
    return 4;
  }
  return 5; // 일반 아카이브
};

// 아카이브 아이콘 가져오기
export const getArchiveIcon = (archive: Archive): string => {
  const name = archive.archive_name;
  const type = archive.archive_type;

  if (type === 'code' || name === ARCHIVE_NAMES.CODE) {
    return 'code';
  } else if (type === 'sap' || name === ARCHIVE_NAMES.SAP) {
    return 'business';
  } else if (name === ARCHIVE_NAMES.CHATBOT) {
    return 'auto_awesome';
  } else if (name === ARCHIVE_NAMES.WORK) {
    return 'lock';
  }
  return 'chat';
};

// 아카이브 색상 가져오기
export const getArchiveColor = (archive: Archive, isDark: boolean = false): string => {
  const name = archive.archive_name;
  const type = archive.archive_type;

  if (!isDark) {
    // Light theme
    if (type === 'code' || name === ARCHIVE_NAMES.CODE) {
      return '#10B981'; // 에메랄드 그린
    } else if (type === 'sap' || name === ARCHIVE_NAMES.SAP) {
      return '#3B82F6'; // 밝은 블루
    } else if (name === ARCHIVE_NAMES.CHATBOT) {
      return '#6B46C1'; // 딥 퍼플
    } else if (name === ARCHIVE_NAMES.WORK) {
      return '#F59E0B'; // 앰버 오렌지
    }
    return '#A855F7'; // 보라색
  } else {
    // Dark theme
    if (type === 'code' || name === ARCHIVE_NAMES.CODE) {
      return '#10B981'; // 그린
    } else if (type === 'sap' || name === ARCHIVE_NAMES.SAP) {
      return '#3B82F6'; // 블루
    } else if (name === ARCHIVE_NAMES.CHATBOT) {
      return '#E879F9'; // 밝은 핫 핑크
    } else if (name === ARCHIVE_NAMES.WORK) {
      return '#FB923C'; // 오렌지
    }
    return '#A855F7'; // 보라색
  }
};

// 아카이브 태그 가져오기
export const getArchiveTag = (archive: Archive): string => {
  const name = archive.archive_name;
  const type = archive.archive_type;

  if (type === 'code' || name === ARCHIVE_NAMES.CODE) {
    return 'CODE';
  } else if (type === 'sap' || name === ARCHIVE_NAMES.SAP) {
    return 'SAP';
  } else if (name === ARCHIVE_NAMES.CHATBOT) {
    return ''; // PRO 태그 제거
  } else if (name === ARCHIVE_NAMES.WORK) {
    return '기본';
  }
  return '';
};

// 기본 아카이브 여부 확인
export const isDefaultArchive = (archive: Archive): boolean => {
  const name = archive.archive_name;
  const type = archive.archive_type;

  if (type === 'code' || type === 'sap') {
    return true;
  }
  if (name === ARCHIVE_NAMES.WORK || name === ARCHIVE_NAMES.CHATBOT) {
    return true;
  }
  return false;
};

// 아카이브 설명
export const getArchiveDescription = (archive: Archive): string => {
  const type = archive.archive_type;

  if (type === 'code') {
    return '개발자를 위한 AI 도우미, 코드 작성, 디버깅, 최적화 지원';
  } else if (type === 'sap') {
    return 'SAP 시스템 관련 질문에 모듈별 최적화된 답변 제공';
  }
  return '';
};

// ChatState 인터페이스 (Flutter ChatState와 동일)
interface ChatState {
  // 데이터
  archives: Archive[];
  currentArchive: Archive | null;
  messages: ChatMessage[];

  // UI 상태
  isSidebarVisible: boolean;
  isDashboardVisible: boolean;

  // 스트리밍 상태
  isStreaming: boolean;
  streamingMessage: string;

  // 입력 상태
  inputMessage: string;
  selectedModel: string;
  isWebSearchEnabled: boolean;
  selectedSapModule: string;

  // 검색 상태
  searchKeyword: string | null;
  highlightedChatId: number | null;

  // Actions
  setArchives: (archives: Archive[]) => void;
  setCurrentArchive: (archive: Archive | null) => void;
  setMessages: (messages: ChatMessage[]) => void;
  addMessage: (message: ChatMessage) => void;
  loadArchives: () => Promise<void>;

  setSidebarVisible: (visible: boolean) => void;
  setDashboardVisible: (visible: boolean) => void;

  setStreaming: (streaming: boolean) => void;
  setStreamingMessage: (message: string | ((prev: string) => string)) => void;
  appendStreamingMessage: (chunk: string) => void;

  setInputMessage: (message: string) => void;
  setSelectedModel: (model: string) => void;
  setWebSearchEnabled: (enabled: boolean) => void;
  setSelectedSapModule: (module: string) => void;

  setSearchKeyword: (keyword: string | null) => void;
  setHighlightedChatId: (chatId: number | null) => void;

  // 아카이브 관리 함수들
  selectArchive: (archive: Archive) => void;
  createArchive: (userId: string, title: string, archiveType: string) => Promise<void>;
  deleteArchive: (archiveId: string) => Promise<void>;
  renameArchive: (userId: string, archiveId: string, newName: string) => Promise<void>;

  // 복합 액션
  clearMessages: () => void;
  reset: () => void;
}

export const useChatStore = create<ChatState>((set, get) => ({
  // 초기 상태
  archives: [],
  currentArchive: null,
  messages: [],

  isSidebarVisible: true,
  isDashboardVisible: true,

  isStreaming: false,
  streamingMessage: '',

  inputMessage: '',
  selectedModel: 'gemini-pro-3',

  // 웹검색 토글 상태 (Flutter와 동일)
  isWebSearchEnabled: false,

  // SAP 모듈 선택 상태
  selectedSapModule: '',

  searchKeyword: null,
  highlightedChatId: null,

  // Actions
  setArchives: (archives) => set({ archives }),
  setCurrentArchive: (archive) => {
    console.log('setCurrentArchive 호출:', archive?.archive_name);
    // SAP 아카이브가 아닌 다른 아카이브로 변경 시 모듈 선택 초기화
    const isSapArchive = archive?.archive_type === 'sap' || archive?.archive_name === ARCHIVE_NAMES.SAP;
    set({
      currentArchive: archive,
      selectedSapModule: isSapArchive ? get().selectedSapModule : '' // SAP가 아니면 초기화
    });
    console.log('setCurrentArchive 완료');
  },
  setMessages: (messages) => set({ messages }),
  addMessage: (message) => set((state) => ({
    messages: [...state.messages, message]
  })),
  loadArchives: async () => {
    const user = authService.getCurrentUser();
    if (!user) return;

    try {
      const archiveList = await chatService.getArchiveList(user.userId);
      const uniqueArchives = archiveList.filter((archive, index, self) =>
        index === self.findIndex((a) => a.archive_id === archive.archive_id)
      );

      const sorted = [...uniqueArchives].sort((a, b) => {
        const orderA = getArchiveOrder(a);
        const orderB = getArchiveOrder(b);
        if (orderA !== orderB) return orderA - orderB;
        return new Date(b.archive_time).getTime() - new Date(a.archive_time).getTime();
      });

      set({ archives: sorted });
    } catch (error) {
      console.error('Failed to load archives:', error);
    }
  },

  setSidebarVisible: (visible) => set({ isSidebarVisible: visible }),
  setDashboardVisible: (visible) => set({ isDashboardVisible: visible }),

  setStreaming: (streaming) => set({ isStreaming: streaming }),
  setStreamingMessage: (message) => set({ streamingMessage: message }),
  appendStreamingMessage: (chunk) => set((state) => ({
    streamingMessage: state.streamingMessage + chunk
  })),

  setInputMessage: (message) => set({ inputMessage: message }),
  setSelectedModel: (model) => set({ selectedModel: model }),

  // 웹검색 토글 액션 (Flutter와 동일)
  setWebSearchEnabled: (enabled) => set({ isWebSearchEnabled: enabled }),

  // SAP 모듈 선택 액션
  setSelectedSapModule: (module) => set({ selectedSapModule: module }),

  setSearchKeyword: (keyword) => set({ searchKeyword: keyword }),
  setHighlightedChatId: (chatId) => set({ highlightedChatId: chatId }),

  // 아카이브 관리 함수들
  selectArchive: (archive) => {
    set({ currentArchive: archive });
  },

  createArchive: async (userId, title, archiveType) => {
    try {
      const response = await chatService.createArchive(userId, title, archiveType);
      // 아카이브 목록 새로고침
      await get().loadArchives();
    } catch (error) {
      console.error('아카이브 생성 실패:', error);
      throw error;
    }
  },

  deleteArchive: async (archiveId) => {
    try {
      await chatService.deleteArchive(archiveId);
      // 아카이브 목록 새로고침
      await get().loadArchives();

      // 삭제된 아카이브가 현재 선택된 아카이브였다면 첫 번째 아카이브 선택
      const state = get();
      if (state.currentArchive?.archive_id === archiveId && state.archives.length > 0) {
        set({ currentArchive: state.archives[0] });
      }
    } catch (error) {
      console.error('아카이브 삭제 실패:', error);
      throw error;
    }
  },

  renameArchive: async (userId, archiveId, newName) => {
    try {
      await chatService.updateArchive(userId, archiveId, newName);
      // 아카이브 목록 새로고침
      await get().loadArchives();

      // 현재 선택된 아카이브의 이름도 업데이트
      const state = get();
      if (state.currentArchive?.archive_id === archiveId) {
        set({
          currentArchive: {
            ...state.currentArchive,
            archive_name: newName
          }
        });
      }
    } catch (error) {
      console.error('아카이브 이름 변경 실패:', error);
      throw error;
    }
  },

  clearMessages: () => set({ messages: [], streamingMessage: '' }),
  reset: () => set({
    archives: [],
    currentArchive: null,
    messages: [],
    isSidebarVisible: true,
    isDashboardVisible: true,
    isStreaming: false,
    streamingMessage: '',
    inputMessage: '',
    selectedSapModule: '',
    searchKeyword: null,
    highlightedChatId: null,
  }),
}));
