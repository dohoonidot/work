// 공통 타입 정의
export interface User {
  userId: string;
  email: string;
  department: string;
  position: string;
  privacyAgreed: boolean;
  isApprover: boolean;
  permission: number | null;
}

export interface ApiResponse<T = any> {
  status_code: number;
  data?: T;
  message?: string;
}

// 채팅 관련 타입
export interface Archive {
  id?: number;
  archive_id: string;
  archive_name: string;
  summary_name?: string;
  archive_time: string;
  archive_type: string;
}

export interface ChatMessage {
  chat_id: number;
  archive_id: string;
  message: string;
  role: number; // 0: user, 1: assistant
  timestamp?: string;
}

// 휴가 관리 관련 타입
export interface LeaveRequest {
  id: string;
  type: string;
  startDate: string;
  endDate: string;
  days: number;
  reason: string;
  status: 'pending' | 'approved' | 'rejected';
  createdAt: string;
  submittedAt?: string;
  approvedAt?: string;
  approver?: string;
  comments?: string;
}

export interface LeaveType {
  value: string;
  label: string;
}

// 전자결재 관련 타입
export interface ApprovalRequest {
  id: string;
  title: string;
  type: string;
  content: string;
  amount?: number;
  status: 'draft' | 'pending' | 'approved' | 'rejected';
  createdAt: string;
  submittedAt?: string;
  approvedAt?: string;
  approver?: string;
  comments?: string;
}

export interface ApprovalType {
  value: string;
  label: string;
}

// 기프트 관련 타입
export interface Gift {
  id: string;
  title: string;
  type: string;
  description: string;
  points: number;
  image?: string;
  status: 'available' | 'out_of_stock' | 'discontinued';
  category: string;
}

export interface GiftRequest {
  id: string;
  giftId: string;
  gift: Gift;
  recipient: string;
  message: string;
  status: 'pending' | 'approved' | 'shipped' | 'delivered' | 'cancelled';
  requestedAt: string;
  approvedAt?: string;
  shippedAt?: string;
  deliveredAt?: string;
  trackingNumber?: string;
}

export interface GiftCategory {
  value: string;
  label: string;
}

// SAP 관련 타입
export interface SapModule {
  id: string;
  name: string;
  code: string;
  description: string;
  icon: React.ReactNode;
  color: string;
}

export interface SapQuery {
  id: string;
  module: string;
  question: string;
  answer: string;
  timestamp: string;
  status: 'pending' | 'completed' | 'error';
}

// 설정 관련 타입
export interface AppSettings {
  notifications: {
    email: boolean;
    push: boolean;
    sms: boolean;
  };
  privacy: {
    profileVisible: boolean;
    activityVisible: boolean;
  };
  appearance: {
    theme: 'light' | 'dark' | 'auto';
    language: 'ko' | 'en';
    fontSize: 'small' | 'medium' | 'large';
  };
  account: {
    autoLogin: boolean;
    twoFactor: boolean;
  };
}

// 알림 관련 타입
export interface Notification {
  id: string;
  title: string;
  message: string;
  type: 'info' | 'success' | 'warning' | 'error';
  timestamp: string;
  read: boolean;
  actionUrl?: string;
}

// 파일 첨부 관련 타입
export interface FileAttachment {
  id: string;
  name: string;
  size: number;
  type: string;
  url: string;
  uploadedAt: string;
}

// 검색 관련 타입
export interface SearchResult {
  id: string;
  title: string;
  content: string;
  type: 'chat' | 'document' | 'user' | 'gift' | 'approval';
  score: number;
  timestamp: string;
}

// 통계 관련 타입
export interface Statistics {
  totalChats: number;
  totalMessages: number;
  totalUsers: number;
  activeUsers: number;
  totalApprovals: number;
  pendingApprovals: number;
  totalGifts: number;
  totalPoints: number;
}
