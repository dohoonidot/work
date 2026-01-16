# ASPN AI Agent - Mobile WebView 구현 가이드

## 📋 목차

1. [프로젝트 개요](#1-프로젝트-개요)
2. [현재 Flutter 앱 분석](#2-현재-flutter-앱-분석)
3. [기술 스택 선정](#3-기술-스택-선정)
4. [아키텍처 설계](#4-아키텍처-설계)
5. [프로젝트 구조](#5-프로젝트-구조)
6. [핵심 기능 구현](#6-핵심-기능-구현)
7. [Flutter WebView 통합](#7-flutter-webview-통합)
8. [개발 로드맵](#8-개발-로드맵)
9. [배포 전략](#9-배포-전략)

---

## 1. 프로젝트 개요

### 1.1 목표
현재 Flutter Windows 데스크톱 앱을 **모바일 앱**으로 전환하기 위해:
- **모바일 웹 버전** 개발 (React + TypeScript)
- **Flutter 모바일 앱** 생성 (Android/iOS)
- **WebView**를 통해 웹 앱을 모바일 앱 안에 임베딩
- 네이티브 기능 (파일 선택, 카메라, 푸시 알림)은 Flutter ↔ WebView 브릿지로 연동

### 1.2 하이브리드 앱 접근 방식의 장단점

**장점:**
- ✅ 웹 코드 한 번 작성으로 웹/앱 모두 지원
- ✅ 빠른 업데이트 (앱스토어 승인 불필요)
- ✅ 개발/유지보수 비용 절감
- ✅ 기존 Flutter 코드베이스 재활용 가능

**단점:**
- ❌ 네이티브 앱 대비 성능 저하 가능
- ❌ 네이티브 기능 접근을 위한 브릿지 구현 필요
- ❌ 웹뷰 렌더링 엔진 차이로 인한 크로스 플랫폼 이슈

---

## 2. 현재 Flutter 앱 분석

### 2.1 핵심 기능

| 기능 카테고리 | 상세 기능 | 기술 스택 |
|-------------|---------|----------|
| **인증** | 로그인, 자동 로그인, 개인정보 동의 | HTTP API, SQLite |
| **AI 채팅** | ChatGPT, Claude, Gemini 다중 모델 지원 | HTTP Streaming |
| **실시간 메시징** | AMQP(RabbitMQ) 기반 알림/선물 | dart_amqp |
| **로컬 DB** | 채팅 히스토리 & 아카이브 관리 | sqflite |
| **파일 첨부** | 이미지/파일 업로드 | file_picker, desktop_drop |
| **테마** | 라이트/다크 모드 | Riverpod |
| **상태 관리** | 전역 상태 관리 | flutter_riverpod |
| **스트리밍** | AI 응답 실시간 스트리밍 | http (chunked) |
| **사내 업무** | 휴가 관리, 전자결재, SAP 연동 | HTTP API |

### 2.2 주요 패키지 의존성

```yaml
dependencies:
  http: ^1.2.2                      # HTTP 요청
  flutter_riverpod: ^2.6.1          # 상태 관리
  sqflite: ^2.4.2                   # 로컬 DB
  dart_amqp: ^0.3.1                 # AMQP 메시징
  gpt_markdown: ^1.0.20             # AI 마크다운 렌더링
  file_picker: ^10.1.9              # 파일 선택
  shared_preferences: ^2.0.0        # 로컬 저장소
  web_socket_channel: ^3.0.3        # WebSocket
```

### 2.3 서버 API 엔드포인트

**Base URL:** `AppConfig.baseUrl`

| API | Method | 용도 |
|-----|--------|------|
| `/api/login` | POST | 로그인 |
| `/getArchiveList` | POST | 아카이브 목록 조회 |
| `/getSingleArchive` | POST | 아카이브 상세 조회 |
| `/createArchive` | POST | 새 아카이브 생성 |
| `/updateArchive` | POST | 아카이브 이름 수정 |
| `/deleteArchive` | POST | 아카이브 삭제 |
| `/checkPrivacy` | POST | 개인정보 동의 상태 조회 |
| `/updatePrivacy` | POST | 개인정보 동의 상태 업데이트 |
| `/queue/checkGifts` | POST | 받은 선물함 조회 |
| `/queue/checkAlerts` | POST | 알림 목록 조회 |

---

## 3. 기술 스택 선정

### 3.1 선택: React + TypeScript

**선정 이유:**
1. **복잡한 상태 관리**: Riverpod 수준의 강력한 상태 관리 필요 → Zustand
2. **실시간 기능**: WebSocket, AMQP 연동 용이
3. **컴포넌트 재사용**: 모듈화된 UI 구조
4. **타입 안정성**: TypeScript로 Flutter의 타입 안전성 유지
5. **풍부한 생태계**: 마크다운, 파일 업로드, WebView 통신 라이브러리
6. **PWA 지원**: Progressive Web App 확장 가능
7. **개발 생산성**: Vite 기반 빠른 빌드 & HMR

### 3.2 전체 기술 스택

```
Frontend (Mobile Web):
├── React 18
├── TypeScript 5
├── Vite (빌드 도구)
├── Zustand (상태 관리)
├── Tailwind CSS (스타일링)
├── React Router v6 (라우팅)
├── Axios (HTTP)
├── react-markdown (마크다운)
├── react-syntax-highlighter (코드 하이라이팅)
├── Dexie.js (IndexedDB)
└── react-dropzone (파일 업로드)

Flutter Mobile App:
├── Flutter 3.5+
├── webview_flutter (WebView)
├── flutter_inappwebview (고급 WebView)
├── file_picker (파일 선택)
├── image_picker (카메라)
├── flutter_local_notifications (푸시 알림)
└── shared_preferences (로컬 저장소)
```

---

## 4. 아키텍처 설계

### 4.1 전체 시스템 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                  Flutter Mobile App                         │
│                  (Android / iOS)                            │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              WebView Container                        │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │         React Mobile Web App                    │  │  │
│  │  │         (Vite + React + TypeScript)             │  │  │
│  │  │                                                 │  │  │
│  │  │  ┌──────────────────────────────────────────┐  │  │  │
│  │  │  │  UI Components (Tailwind CSS)           │  │  │  │
│  │  │  └──────────────────────────────────────────┘  │  │  │
│  │  │  ┌──────────────────────────────────────────┐  │  │  │
│  │  │  │  State Management (Zustand)             │  │  │  │
│  │  │  └──────────────────────────────────────────┘  │  │  │
│  │  │  ┌──────────────────────────────────────────┐  │  │  │
│  │  │  │  Local Storage (IndexedDB via Dexie)    │  │  │  │
│  │  │  └──────────────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │     Flutter ↔ WebView Bridge (양방향 통신)      │  │  │
│  │  │  - postMessage (Web → Flutter)                  │  │  │
│  │  │  - evaluateJavaScript (Flutter → Web)           │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │           Native Features (Flutter)                   │  │
│  │  - File Picker (파일 선택)                            │  │
│  │  - Image Picker (카메라)                              │  │
│  │  - Local Notifications (푸시 알림)                    │  │
│  │  - Biometric Auth (생체 인증)                         │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                          ↕                    ↕
                    [Backend API]        [AMQP Server]
                    - REST API           - RabbitMQ
                    - WebSocket          - 211.43.205.49:5672
                    - File Upload
```

### 4.2 데이터 플로우

```
1. 사용자 로그인:
   User Input (React)
   → API Call (Axios)
   → Server Response
   → Zustand Store Update
   → IndexedDB Sync
   → UI Re-render

2. 채팅 메시지 전송:
   User Input (React)
   → Zustand Store (Optimistic Update)
   → API Call (Streaming)
   → Server SSE Stream
   → Real-time UI Update
   → IndexedDB Save

3. 파일 업로드:
   User Click
   → Flutter Bridge (postMessage)
   → Native File Picker (Flutter)
   → File Data to WebView
   → Upload to Server
   → UI Update

4. AMQP 알림:
   AMQP Server
   → WebSocket Connection
   → React Event Handler
   → Zustand Store Update
   → UI Notification
   → (Optional) Native Push via Flutter Bridge
```

---

## 5. 프로젝트 구조

### 5.1 모바일 웹 프로젝트 구조

```
mobile-web/
├── public/
│   ├── index.html
│   ├── manifest.json              # PWA 매니페스트
│   └── assets/
│       ├── icons/
│       └── images/
├── src/
│   ├── components/                # 재사용 가능 컴포넌트
│   │   ├── common/
│   │   │   ├── Button.tsx
│   │   │   ├── Input.tsx
│   │   │   ├── Modal.tsx
│   │   │   ├── Loading.tsx
│   │   │   └── ErrorBoundary.tsx
│   │   ├── layout/
│   │   │   ├── Header.tsx
│   │   │   ├── Sidebar.tsx
│   │   │   ├── BottomNav.tsx
│   │   │   └── Container.tsx
│   │   ├── chat/
│   │   │   ├── ChatList.tsx
│   │   │   ├── ChatMessage.tsx
│   │   │   ├── ChatInput.tsx
│   │   │   ├── ArchiveList.tsx
│   │   │   ├── AIModelSelector.tsx
│   │   │   └── MarkdownRenderer.tsx
│   │   ├── auth/
│   │   │   ├── LoginForm.tsx
│   │   │   ├── PrivacyAgreement.tsx
│   │   │   └── AutoLoginToggle.tsx
│   │   └── business/
│   │       ├── LeaveRequestForm.tsx
│   │       ├── ApprovalList.tsx
│   │       └── SAPModule.tsx
│   ├── pages/                     # 페이지 컴포넌트
│   │   ├── LoginPage.tsx
│   │   ├── ChatPage.tsx
│   │   ├── LeaveManagementPage.tsx
│   │   ├── ApprovalPage.tsx
│   │   ├── SettingsPage.tsx
│   │   └── NotFoundPage.tsx
│   ├── services/                  # 비즈니스 로직 & API
│   │   ├── api/
│   │   │   ├── apiClient.ts       # Axios 인스턴스
│   │   │   ├── authApi.ts
│   │   │   ├── chatApi.ts
│   │   │   ├── archiveApi.ts
│   │   │   ├── fileApi.ts
│   │   │   └── notificationApi.ts
│   │   ├── websocket/
│   │   │   ├── websocketManager.ts
│   │   │   └── amqpClient.ts
│   │   └── storage/
│   │       ├── indexedDB.ts       # Dexie 설정
│   │       ├── localStorage.ts
│   │       └── syncService.ts     # 서버 ↔ 로컬 동기화
│   ├── stores/                    # Zustand 상태 관리
│   │   ├── authStore.ts
│   │   ├── chatStore.ts
│   │   ├── themeStore.ts
│   │   ├── notificationStore.ts
│   │   ├── uiStore.ts
│   │   └── index.ts
│   ├── hooks/                     # Custom React Hooks
│   │   ├── useAuth.ts
│   │   ├── useChat.ts
│   │   ├── useWebSocket.ts
│   │   ├── useFileUpload.ts
│   │   └── useFlutterBridge.ts
│   ├── utils/                     # 유틸리티 함수
│   │   ├── formatDate.ts
│   │   ├── validateInput.ts
│   │   ├── errorHandler.ts
│   │   └── constants.ts
│   ├── types/                     # TypeScript 타입 정의
│   │   ├── auth.ts
│   │   ├── chat.ts
│   │   ├── api.ts
│   │   ├── bridge.ts
│   │   └── index.ts
│   ├── bridge/                    # Flutter ↔ Web 통신
│   │   ├── flutterBridge.ts
│   │   ├── messageTypes.ts
│   │   └── bridgeHandlers.ts
│   ├── styles/                    # 글로벌 스타일
│   │   ├── globals.css
│   │   └── tailwind.css
│   ├── App.tsx
│   ├── main.tsx
│   └── vite-env.d.ts
├── .env.development
├── .env.production
├── vite.config.ts
├── tailwind.config.js
├── tsconfig.json
├── package.json
└── README.md
```

### 5.2 Flutter 모바일 앱 구조

```
flutter-mobile-app/
├── android/
├── ios/
├── lib/
│   ├── main.dart
│   ├── screens/
│   │   └── webview_screen.dart
│   ├── services/
│   │   ├── file_picker_service.dart
│   │   ├── camera_service.dart
│   │   ├── notification_service.dart
│   │   └── bridge_service.dart
│   ├── models/
│   │   └── bridge_message.dart
│   └── utils/
│       └── constants.dart
├── pubspec.yaml
└── README.md
```

---

## 6. 핵심 기능 구현

### 6.1 프로젝트 초기 설정

#### 6.1.1 React 프로젝트 생성

```bash
# Vite로 React + TypeScript 프로젝트 생성
npm create vite@latest mobile-web -- --template react-ts
cd mobile-web
npm install

# 필수 패키지 설치
npm install zustand axios react-router-dom
npm install dexie react-markdown remark-gfm
npm install react-syntax-highlighter
npm install react-dropzone
npm install @types/react-syntax-highlighter -D

# Tailwind CSS 설치
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

#### 6.1.2 Tailwind 설정

```javascript
// tailwind.config.js
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: '#1D4487',
        secondary: '#F5F5F5',
      },
    },
  },
  plugins: [],
}
```

```css
/* src/styles/tailwind.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

/* 커스텀 유틸리티 */
@layer components {
  .btn-primary {
    @apply bg-primary text-white px-4 py-2 rounded-lg hover:bg-opacity-90 transition;
  }

  .input-field {
    @apply border border-gray-300 rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-primary;
  }
}
```

#### 6.1.3 Vite 설정

```typescript
// vite.config.ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    port: 5173,
    host: true, // Flutter에서 접근 가능하도록
    proxy: {
      '/api': {
        target: 'http://your-backend-server.com',
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
})
```

---

### 6.2 상태 관리 (Zustand)

#### 6.2.1 인증 스토어

```typescript
// src/stores/authStore.ts
import create from 'zustand';
import { persist } from 'zustand/middleware';
import { authApi } from '@/services/api/authApi';

export interface User {
  userId: string;
  privacyAgreed: boolean;
  isApprover: boolean;
  permission: number | null;
}

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;

  // Actions
  login: (userId: string, password: string) => Promise<void>;
  logout: () => void;
  autoLogin: () => Promise<boolean>;
  updatePrivacyAgreement: (agreed: boolean) => Promise<void>;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set, get) => ({
      user: null,
      isAuthenticated: false,
      isLoading: false,
      error: null,

      login: async (userId: string, password: string) => {
        set({ isLoading: true, error: null });

        try {
          const response = await authApi.login(userId, password);

          if (response.status_code === 200) {
            const user: User = {
              userId,
              privacyAgreed: response.is_agreed === 1,
              isApprover: response.is_approver === 1,
              permission: response.permission,
            };

            set({
              user,
              isAuthenticated: true,
              isLoading: false
            });

            // 로컬 스토리지에 토큰 저장 (자동 로그인용)
            localStorage.setItem('authToken', response.token || '');
          } else {
            throw new Error('Login failed');
          }
        } catch (error: any) {
          set({
            error: error.message || '로그인에 실패했습니다.',
            isLoading: false
          });
          throw error;
        }
      },

      logout: () => {
        localStorage.removeItem('authToken');
        set({ user: null, isAuthenticated: false });
      },

      autoLogin: async () => {
        const token = localStorage.getItem('authToken');
        if (!token) return false;

        try {
          const isValid = await authApi.validateToken(token);

          if (isValid) {
            // 토큰이 유효하면 사용자 정보 복원
            set({ isAuthenticated: true });
            return true;
          } else {
            localStorage.removeItem('authToken');
            return false;
          }
        } catch (error) {
          return false;
        }
      },

      updatePrivacyAgreement: async (agreed: boolean) => {
        const { user } = get();
        if (!user) return;

        try {
          await authApi.updatePrivacy(user.userId, agreed);
          set({
            user: {
              ...user,
              privacyAgreed: agreed,
            },
          });
        } catch (error) {
          console.error('Failed to update privacy agreement:', error);
          throw error;
        }
      },
    }),
    {
      name: 'auth-storage',
      partialize: (state) => ({
        user: state.user,
        isAuthenticated: state.isAuthenticated,
      }),
    }
  )
);
```

#### 6.2.2 채팅 스토어

```typescript
// src/stores/chatStore.ts
import create from 'zustand';
import { chatApi } from '@/services/api/chatApi';
import { archiveApi } from '@/services/api/archiveApi';
import { db } from '@/services/storage/indexedDB';

export interface Message {
  chat_id: number;
  archive_id: string;
  message: string;
  role: number; // 0: user, 1: assistant
  timestamp?: string;
}

export interface Archive {
  id?: number;
  archive_id: string;
  archive_name: string;
  archive_type: string;
  archive_time: string;
}

interface ChatState {
  archives: Archive[];
  currentArchive: Archive | null;
  messages: Message[];
  isStreaming: boolean;
  isLoading: boolean;
  selectedAiModel: string;

  // Actions
  loadArchives: (userId: string) => Promise<void>;
  selectArchive: (archiveId: string) => Promise<void>;
  createArchive: (userId: string, title: string, type: string) => Promise<void>;
  deleteArchive: (archiveId: string) => Promise<void>;
  updateArchiveTitle: (archiveId: string, newTitle: string) => Promise<void>;
  sendMessage: (text: string, files?: File[]) => Promise<void>;
  streamAIResponse: (prompt: string) => Promise<void>;
  setSelectedAiModel: (model: string) => void;
}

export const useChatStore = create<ChatState>((set, get) => ({
  archives: [],
  currentArchive: null,
  messages: [],
  isStreaming: false,
  isLoading: false,
  selectedAiModel: 'gemini-flash-2.5',

  loadArchives: async (userId: string) => {
    set({ isLoading: true });

    try {
      // 1. 로컬 DB에서 먼저 로드 (빠른 UI 표시)
      const localArchives = await db.archives
        .where('user_id')
        .equals(userId)
        .toArray();

      set({ archives: localArchives, isLoading: false });

      // 2. 서버에서 최신 데이터 가져오기 (백그라운드)
      const serverArchives = await archiveApi.getArchiveList(userId);

      // 3. 로컬 DB 업데이트
      for (const archive of serverArchives) {
        await db.archives.put({
          ...archive,
          user_id: userId,
        });
      }

      // 4. UI 업데이트
      set({ archives: serverArchives });
    } catch (error) {
      console.error('Failed to load archives:', error);
      set({ isLoading: false });
    }
  },

  selectArchive: async (archiveId: string) => {
    const { archives } = get();
    const archive = archives.find(a => a.archive_id === archiveId);

    if (!archive) return;

    set({ currentArchive: archive, isLoading: true });

    try {
      // 1. 로컬 DB에서 메시지 로드
      const localMessages = await db.messages
        .where('archive_id')
        .equals(archiveId)
        .toArray();

      set({ messages: localMessages, isLoading: false });

      // 2. 서버에서 최신 메시지 가져오기
      const maxChatId = localMessages.length > 0
        ? Math.max(...localMessages.map(m => m.chat_id))
        : 0;

      const serverMessages = await archiveApi.getArchiveDetail(
        archiveId,
        maxChatId
      );

      // 3. 새 메시지가 있으면 로컬 DB 업데이트
      if (serverMessages.length > 0) {
        for (const msg of serverMessages) {
          await db.messages.put(msg);
        }

        // 4. UI 업데이트
        const allMessages = [...localMessages, ...serverMessages];
        set({ messages: allMessages });
      }
    } catch (error) {
      console.error('Failed to load archive messages:', error);
      set({ isLoading: false });
    }
  },

  createArchive: async (userId: string, title: string, type: string) => {
    try {
      const response = await archiveApi.createArchive(userId, title, type);
      const newArchive = response.archive;

      // 로컬 DB에 저장
      await db.archives.add({
        ...newArchive,
        user_id: userId,
      });

      // 상태 업데이트
      set(state => ({
        archives: [newArchive, ...state.archives],
        currentArchive: newArchive,
        messages: [],
      }));
    } catch (error) {
      console.error('Failed to create archive:', error);
      throw error;
    }
  },

  deleteArchive: async (archiveId: string) => {
    try {
      await archiveApi.deleteArchive(archiveId);

      // 로컬 DB에서 삭제
      await db.archives.where('archive_id').equals(archiveId).delete();
      await db.messages.where('archive_id').equals(archiveId).delete();

      // 상태 업데이트
      set(state => ({
        archives: state.archives.filter(a => a.archive_id !== archiveId),
        currentArchive: state.currentArchive?.archive_id === archiveId
          ? null
          : state.currentArchive,
        messages: state.currentArchive?.archive_id === archiveId
          ? []
          : state.messages,
      }));
    } catch (error) {
      console.error('Failed to delete archive:', error);
      throw error;
    }
  },

  updateArchiveTitle: async (archiveId: string, newTitle: string) => {
    try {
      await archiveApi.updateArchive(archiveId, newTitle);

      // 로컬 DB 업데이트
      await db.archives
        .where('archive_id')
        .equals(archiveId)
        .modify({ archive_name: newTitle });

      // 상태 업데이트
      set(state => ({
        archives: state.archives.map(a =>
          a.archive_id === archiveId
            ? { ...a, archive_name: newTitle }
            : a
        ),
        currentArchive: state.currentArchive?.archive_id === archiveId
          ? { ...state.currentArchive, archive_name: newTitle }
          : state.currentArchive,
      }));
    } catch (error) {
      console.error('Failed to update archive title:', error);
      throw error;
    }
  },

  sendMessage: async (text: string, files?: File[]) => {
    const { currentArchive, messages } = get();
    if (!currentArchive) return;

    // 1. Optimistic UI Update (사용자 메시지 즉시 표시)
    const userMessage: Message = {
      chat_id: Date.now(), // 임시 ID
      archive_id: currentArchive.archive_id,
      message: text,
      role: 0,
      timestamp: new Date().toISOString(),
    };

    set({ messages: [...messages, userMessage] });

    // 2. 파일 업로드 (있는 경우)
    if (files && files.length > 0) {
      // TODO: 파일 업로드 로직
    }

    // 3. AI 응답 스트리밍
    await get().streamAIResponse(text);
  },

  streamAIResponse: async (prompt: string) => {
    const { currentArchive, messages, selectedAiModel } = get();
    if (!currentArchive) return;

    set({ isStreaming: true });

    try {
      // AI 응답 메시지 객체 생성
      const aiMessage: Message = {
        chat_id: Date.now() + 1,
        archive_id: currentArchive.archive_id,
        message: '',
        role: 1,
        timestamp: new Date().toISOString(),
      };

      // 메시지 리스트에 추가
      set(state => ({
        messages: [...state.messages, aiMessage],
      }));

      // 스트리밍 API 호출
      const response = await fetch('/api/chat/stream', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          prompt,
          archiveId: currentArchive.archive_id,
          model: selectedAiModel,
        }),
      });

      if (!response.body) {
        throw new Error('Response body is null');
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder();

      // 스트리밍 데이터 읽기
      while (true) {
        const { done, value } = await reader.read();

        if (done) break;

        const chunk = decoder.decode(value);
        aiMessage.message += chunk;

        // 실시간으로 UI 업데이트
        set(state => ({
          messages: state.messages.map((msg, idx) =>
            idx === state.messages.length - 1
              ? { ...msg, message: aiMessage.message }
              : msg
          ),
        }));
      }

      // 로컬 DB에 저장
      await db.messages.add(aiMessage);

      set({ isStreaming: false });
    } catch (error) {
      console.error('Failed to stream AI response:', error);
      set({ isStreaming: false });
      throw error;
    }
  },

  setSelectedAiModel: (model: string) => {
    set({ selectedAiModel: model });
  },
}));
```

#### 6.2.3 테마 스토어

```typescript
// src/stores/themeStore.ts
import create from 'zustand';
import { persist } from 'zustand/middleware';

type ThemeMode = 'light' | 'dark';

interface ThemeState {
  mode: ThemeMode;
  toggleTheme: () => void;
  setTheme: (mode: ThemeMode) => void;
}

export const useThemeStore = create<ThemeState>()(
  persist(
    (set) => ({
      mode: 'light',

      toggleTheme: () => {
        set((state) => ({
          mode: state.mode === 'light' ? 'dark' : 'light',
        }));
      },

      setTheme: (mode: ThemeMode) => {
        set({ mode });
      },
    }),
    {
      name: 'theme-storage',
    }
  )
);
```

---

### 6.3 API 서비스 레이어

#### 6.3.1 Axios 클라이언트 설정

```typescript
// src/services/api/apiClient.ts
import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse } from 'axios';
import { useAuthStore } from '@/stores/authStore';

const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000';

class ApiClient {
  private instance: AxiosInstance;

  constructor() {
    this.instance = axios.create({
      baseURL: BASE_URL,
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    this.setupInterceptors();
  }

  private setupInterceptors() {
    // 요청 인터셉터
    this.instance.interceptors.request.use(
      (config) => {
        // 토큰 추가 (필요한 경우)
        const token = localStorage.getItem('authToken');
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }

        return config;
      },
      (error) => {
        return Promise.reject(error);
      }
    );

    // 응답 인터셉터
    this.instance.interceptors.response.use(
      (response) => {
        return response;
      },
      (error) => {
        // 401 에러 시 로그아웃
        if (error.response?.status === 401) {
          useAuthStore.getState().logout();
          window.location.href = '/login';
        }

        return Promise.reject(error);
      }
    );
  }

  // GET 요청
  async get<T = any>(url: string, config?: AxiosRequestConfig): Promise<T> {
    const response: AxiosResponse<T> = await this.instance.get(url, config);
    return response.data;
  }

  // POST 요청
  async post<T = any>(
    url: string,
    data?: any,
    config?: AxiosRequestConfig
  ): Promise<T> {
    const response: AxiosResponse<T> = await this.instance.post(url, data, config);
    return response.data;
  }

  // PUT 요청
  async put<T = any>(
    url: string,
    data?: any,
    config?: AxiosRequestConfig
  ): Promise<T> {
    const response: AxiosResponse<T> = await this.instance.put(url, data, config);
    return response.data;
  }

  // DELETE 요청
  async delete<T = any>(url: string, config?: AxiosRequestConfig): Promise<T> {
    const response: AxiosResponse<T> = await this.instance.delete(url, config);
    return response.data;
  }
}

export const apiClient = new ApiClient();
```

#### 6.3.2 인증 API

```typescript
// src/services/api/authApi.ts
import { apiClient } from './apiClient';

export interface LoginResponse {
  status_code: number;
  is_agreed: number;
  is_approver: number;
  permission: number | null;
  token?: string;
}

export const authApi = {
  // 로그인
  login: async (userId: string, password: string): Promise<LoginResponse> => {
    return await apiClient.post('/api/login', {
      user_id: userId,
      password,
      version_info: '1.3.0', // 앱 버전
    });
  },

  // 토큰 유효성 검증
  validateToken: async (token: string): Promise<boolean> => {
    try {
      const response = await apiClient.post('/api/validate-token', { token });
      return response.valid === true;
    } catch (error) {
      return false;
    }
  },

  // 개인정보 동의 상태 조회
  checkPrivacy: async (userId: string): Promise<{ is_agreed: number }> => {
    return await apiClient.post('/checkPrivacy', { user_id: userId });
  },

  // 개인정보 동의 상태 업데이트
  updatePrivacy: async (userId: string, isAgreed: boolean): Promise<void> => {
    await apiClient.post('/updatePrivacy', {
      user_id: userId,
      is_agreed: isAgreed ? 1 : 0,
    });
  },
};
```

#### 6.3.3 아카이브 API

```typescript
// src/services/api/archiveApi.ts
import { apiClient } from './apiClient';
import { Archive, Message } from '@/stores/chatStore';

export const archiveApi = {
  // 아카이브 목록 조회
  getArchiveList: async (userId: string): Promise<Archive[]> => {
    const response = await apiClient.post<{ archive_list: Archive[] }>(
      '/getArchiveList',
      { user_id: userId }
    );
    return response.archive_list || [];
  },

  // 아카이브 상세 조회
  getArchiveDetail: async (
    archiveId: string,
    maxChatId: number = 0
  ): Promise<Message[]> => {
    const response = await apiClient.post<{ chats: Message[]; status_code: number }>(
      '/getSingleArchive',
      {
        archive_id: archiveId,
        max_chat_id: maxChatId,
      }
    );

    if (response.status_code === 204) {
      return [];
    }

    return response.chats || [];
  },

  // 아카이브 생성
  createArchive: async (
    userId: string,
    title: string,
    archiveType: string
  ): Promise<{ archive: Archive }> => {
    return await apiClient.post('/createArchive', {
      user_id: userId,
      archive_type: archiveType,
    });
  },

  // 아카이브 이름 수정
  updateArchive: async (archiveId: string, newName: string): Promise<void> => {
    await apiClient.post('/updateArchive', {
      archive_id: archiveId,
      archive_name: newName,
    });
  },

  // 아카이브 삭제
  deleteArchive: async (archiveId: string): Promise<void> => {
    await apiClient.post('/deleteArchive', {
      archive_id: archiveId,
    });
  },
};
```

---

### 6.4 로컬 저장소 (IndexedDB)

```typescript
// src/services/storage/indexedDB.ts
import Dexie, { Table } from 'dexie';

export interface Archive {
  id?: number;
  archive_id: string;
  archive_name: string;
  archive_type: string;
  archive_time: string;
  user_id: string;
}

export interface ChatMessage {
  id?: number;
  chat_id: number;
  archive_id: string;
  message: string;
  role: number;
  user_id: string;
  timestamp?: string;
}

export interface AutoLoginInfo {
  id?: number;
  user_id: string;
  token: string;
  created_at: string;
  expiration_date: string;
}

class AppDatabase extends Dexie {
  archives!: Table<Archive, number>;
  messages!: Table<ChatMessage, number>;
  autoLogin!: Table<AutoLoginInfo, number>;

  constructor() {
    super('ASPN_AI_Agent_DB');

    this.version(1).stores({
      archives: '++id, archive_id, user_id, archive_type',
      messages: '++id, chat_id, archive_id, user_id, role',
      autoLogin: '++id, user_id, token',
    });
  }

  // 데이터베이스 초기화
  async clearAllData() {
    await this.archives.clear();
    await this.messages.clear();
    await this.autoLogin.clear();
  }

  // 사용자 데이터 삭제
  async clearUserData(userId: string) {
    await this.archives.where('user_id').equals(userId).delete();
    await this.messages.where('user_id').equals(userId).delete();
    await this.autoLogin.where('user_id').equals(userId).delete();
  }
}

export const db = new AppDatabase();

// 유틸리티 함수들
export const dbUtils = {
  // 아카이브 저장
  async saveArchive(archive: Archive): Promise<number> {
    return await db.archives.put(archive);
  },

  // 사용자별 아카이브 조회
  async getArchivesByUserId(userId: string): Promise<Archive[]> {
    return await db.archives
      .where('user_id')
      .equals(userId)
      .sortBy('archive_time');
  },

  // 메시지 저장
  async saveMessage(message: ChatMessage): Promise<number> {
    return await db.messages.put(message);
  },

  // 아카이브별 메시지 조회
  async getMessagesByArchiveId(archiveId: string): Promise<ChatMessage[]> {
    return await db.messages
      .where('archive_id')
      .equals(archiveId)
      .sortBy('chat_id');
  },

  // 자동 로그인 정보 저장
  async saveAutoLoginInfo(info: AutoLoginInfo): Promise<number> {
    // 기존 정보 삭제
    await db.autoLogin.where('user_id').equals(info.user_id).delete();
    return await db.autoLogin.add(info);
  },

  // 자동 로그인 정보 조회
  async getAutoLoginInfo(userId: string): Promise<AutoLoginInfo | undefined> {
    return await db.autoLogin
      .where('user_id')
      .equals(userId)
      .first();
  },
};
```

---

### 6.5 WebSocket & AMQP

```typescript
// src/services/websocket/websocketManager.ts
import { useNotificationStore } from '@/stores/notificationStore';

type MessageHandler = (data: any) => void;

class WebSocketManager {
  private ws: WebSocket | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private reconnectDelay = 3000;
  private messageHandlers: Map<string, MessageHandler[]> = new Map();

  connect(userId: string) {
    const wsUrl = import.meta.env.VITE_WS_URL || 'ws://localhost:8000/ws';

    try {
      this.ws = new WebSocket(`${wsUrl}?userId=${userId}`);

      this.ws.onopen = () => {
        console.log('WebSocket connected');
        this.reconnectAttempts = 0;
      };

      this.ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          this.handleMessage(data);
        } catch (error) {
          console.error('Failed to parse WebSocket message:', error);
        }
      };

      this.ws.onerror = (error) => {
        console.error('WebSocket error:', error);
      };

      this.ws.onclose = () => {
        console.log('WebSocket disconnected');
        this.handleReconnect(userId);
      };
    } catch (error) {
      console.error('Failed to connect WebSocket:', error);
      this.handleReconnect(userId);
    }
  }

  disconnect() {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
    this.reconnectAttempts = 0;
  }

  private handleReconnect(userId: string) {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++;
      console.log(`Reconnecting... Attempt ${this.reconnectAttempts}`);

      setTimeout(() => {
        this.connect(userId);
      }, this.reconnectDelay);
    } else {
      console.error('Max reconnect attempts reached');
    }
  }

  private handleMessage(data: any) {
    const { type, payload } = data;

    // 타입별 핸들러 실행
    const handlers = this.messageHandlers.get(type);
    if (handlers) {
      handlers.forEach(handler => handler(payload));
    }
  }

  on(type: string, handler: MessageHandler) {
    if (!this.messageHandlers.has(type)) {
      this.messageHandlers.set(type, []);
    }
    this.messageHandlers.get(type)!.push(handler);
  }

  off(type: string, handler: MessageHandler) {
    const handlers = this.messageHandlers.get(type);
    if (handlers) {
      const index = handlers.indexOf(handler);
      if (index > -1) {
        handlers.splice(index, 1);
      }
    }
  }

  send(type: string, payload: any) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({ type, payload }));
    } else {
      console.warn('WebSocket is not connected');
    }
  }
}

export const wsManager = new WebSocketManager();
```

```typescript
// src/services/websocket/amqpClient.ts
import { wsManager } from './websocketManager';
import { useNotificationStore } from '@/stores/notificationStore';

export interface BirthdayMessage {
  id: number;
  user_id: string;
  message: string;
  tr_id?: string;
  pin_number?: string;
  coupon_img_url?: string;
  coupon_end_date?: string;
  coupon_status?: string;
  send_time?: string;
}

export interface AlertMessage {
  id: number;
  user_id: string;
  title: string;
  message: string;
  is_read: boolean;
  created_at: string;
}

class AMQPClient {
  initialize(userId: string) {
    // 생일 메시지 핸들러
    wsManager.on('birthday', (data: BirthdayMessage) => {
      console.log('Received birthday message:', data);
      useNotificationStore.getState().addBirthdayMessage(data);
    });

    // 일반 알림 핸들러
    wsManager.on('alert', (data: AlertMessage) => {
      console.log('Received alert message:', data);
      useNotificationStore.getState().addAlert(data);
    });

    // WebSocket 연결
    wsManager.connect(userId);
  }

  disconnect() {
    wsManager.disconnect();
  }
}

export const amqpClient = new AMQPClient();
```

---

### 6.6 UI 컴포넌트

#### 6.6.1 로그인 페이지

```tsx
// src/pages/LoginPage.tsx
import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '@/stores/authStore';

export const LoginPage: React.FC = () => {
  const navigate = useNavigate();
  const { login, autoLogin, isAuthenticated, isLoading, error } = useAuthStore();

  const [userId, setUserId] = useState('');
  const [password, setPassword] = useState('');
  const [rememberMe, setRememberMe] = useState(false);

  useEffect(() => {
    // 자동 로그인 시도
    const tryAutoLogin = async () => {
      const success = await autoLogin();
      if (success) {
        navigate('/chat');
      }
    };

    tryAutoLogin();
  }, []);

  useEffect(() => {
    // 로그인 성공 시 채팅 페이지로 이동
    if (isAuthenticated) {
      navigate('/chat');
    }
  }, [isAuthenticated, navigate]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!userId || !password) {
      return;
    }

    try {
      await login(userId, password);
    } catch (error) {
      console.error('Login failed:', error);
    }
  };

  return (
    <div className="min-h-screen bg-white flex items-center justify-center">
      <div className="w-full max-w-md px-6">
        {/* 로고 */}
        <div className="text-center mb-8">
          <img
            src="/assets/icons/ASPN_AAA_logo.png"
            alt="ASPN AI Agent"
            className="w-16 h-16 mx-auto mb-4"
          />
          <h1 className="text-xl font-bold text-primary">
            ASPN AI 에이전트
          </h1>
        </div>

        {/* 로그인 폼 */}
        <form onSubmit={handleSubmit} className="space-y-4">
          {/* 아이디 입력 */}
          <div>
            <label htmlFor="userId" className="block text-sm text-gray-700 mb-2">
              아이디
            </label>
            <div className="relative">
              <input
                id="userId"
                type="text"
                value={userId}
                onChange={(e) => setUserId(e.target.value)}
                className="input-field w-full pl-10"
                placeholder="아이디를 입력하세요"
                autoFocus
              />
              <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400">
                👤
              </span>
            </div>
          </div>

          {/* 비밀번호 입력 */}
          <div>
            <label htmlFor="password" className="block text-sm text-gray-700 mb-2">
              비밀번호
            </label>
            <div className="relative">
              <input
                id="password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="input-field w-full pl-10"
                placeholder="비밀번호를 입력하세요"
              />
              <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400">
                🔒
              </span>
            </div>
          </div>

          {/* 자동 로그인 체크박스 */}
          <div className="flex items-center">
            <input
              id="rememberMe"
              type="checkbox"
              checked={rememberMe}
              onChange={(e) => setRememberMe(e.target.checked)}
              className="w-4 h-4 text-primary border-gray-300 rounded focus:ring-primary"
            />
            <label htmlFor="rememberMe" className="ml-2 text-sm text-gray-700">
              자동 로그인
            </label>
          </div>

          {/* 에러 메시지 */}
          {error && (
            <div className="bg-red-50 border border-red-200 rounded-lg p-3">
              <p className="text-sm text-red-600">{error}</p>
            </div>
          )}

          {/* 로그인 버튼 */}
          <button
            type="submit"
            disabled={isLoading}
            className="btn-primary w-full py-3 text-base font-semibold disabled:opacity-50"
          >
            {isLoading ? '로그인 중...' : '로그인'}
          </button>

          {/* 비밀번호 변경 링크 */}
          <div className="text-center">
            <button
              type="button"
              className="text-sm text-gray-600 hover:text-primary"
            >
              비밀번호 변경
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
```

#### 6.6.2 채팅 페이지

```tsx
// src/pages/ChatPage.tsx
import React, { useEffect } from 'react';
import { useAuthStore } from '@/stores/authStore';
import { useChatStore } from '@/stores/chatStore';
import { ChatList } from '@/components/chat/ChatList';
import { ChatInput } from '@/components/chat/ChatInput';
import { ArchiveList } from '@/components/chat/ArchiveList';
import { Header } from '@/components/layout/Header';

export const ChatPage: React.FC = () => {
  const { user } = useAuthStore();
  const { loadArchives, currentArchive } = useChatStore();

  useEffect(() => {
    if (user) {
      loadArchives(user.userId);
    }
  }, [user]);

  return (
    <div className="h-screen flex flex-col bg-gray-50">
      {/* 헤더 */}
      <Header />

      {/* 메인 컨텐츠 */}
      <div className="flex-1 flex overflow-hidden">
        {/* 사이드바 (아카이브 리스트) */}
        <aside className="w-64 bg-white border-r border-gray-200 overflow-y-auto">
          <ArchiveList />
        </aside>

        {/* 채팅 영역 */}
        <main className="flex-1 flex flex-col">
          {currentArchive ? (
            <>
              {/* 채팅 메시지 리스트 */}
              <div className="flex-1 overflow-y-auto">
                <ChatList />
              </div>

              {/* 입력 영역 */}
              <div className="border-t border-gray-200 bg-white">
                <ChatInput />
              </div>
            </>
          ) : (
            <div className="flex-1 flex items-center justify-center">
              <p className="text-gray-500">아카이브를 선택하세요</p>
            </div>
          )}
        </main>
      </div>
    </div>
  );
};
```

#### 6.6.3 채팅 메시지 컴포넌트

```tsx
// src/components/chat/ChatMessage.tsx
import React from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { vscDarkPlus } from 'react-syntax-highlighter/dist/esm/styles/prism';
import { Message } from '@/stores/chatStore';

interface ChatMessageProps {
  message: Message;
}

export const ChatMessage: React.FC<ChatMessageProps> = ({ message }) => {
  const isUser = message.role === 0;

  return (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'} mb-4`}>
      <div
        className={`max-w-[80%] rounded-lg px-4 py-2 ${
          isUser
            ? 'bg-primary text-white'
            : 'bg-white border border-gray-200 text-gray-900'
        }`}
      >
        {isUser ? (
          <p className="whitespace-pre-wrap">{message.message}</p>
        ) : (
          <ReactMarkdown
            remarkPlugins={[remarkGfm]}
            components={{
              code({ node, inline, className, children, ...props }) {
                const match = /language-(\w+)/.exec(className || '');
                return !inline && match ? (
                  <SyntaxHighlighter
                    style={vscDarkPlus as any}
                    language={match[1]}
                    PreTag="div"
                    {...props}
                  >
                    {String(children).replace(/\n$/, '')}
                  </SyntaxHighlighter>
                ) : (
                  <code className={className} {...props}>
                    {children}
                  </code>
                );
              },
            }}
          >
            {message.message}
          </ReactMarkdown>
        )}
      </div>
    </div>
  );
};
```

---

## 7. Flutter WebView 통합

### 7.1 Flutter 프로젝트 생성

```bash
# Flutter 모바일 프로젝트 생성
flutter create flutter_mobile_app
cd flutter_mobile_app

# 필수 패키지 추가
flutter pub add webview_flutter
flutter pub add flutter_inappwebview
flutter pub add file_picker
flutter pub add image_picker
flutter pub add flutter_local_notifications
flutter pub add shared_preferences
```

### 7.2 pubspec.yaml 설정

```yaml
# pubspec.yaml
name: aspn_ai_agent_mobile
description: ASPN AI Agent Mobile App
version: 1.3.0

environment:
  sdk: ^3.5.4

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # WebView
  webview_flutter: ^4.4.2
  flutter_inappwebview: ^6.0.0

  # 파일 & 이미지
  file_picker: ^10.1.9
  image_picker: ^1.0.7

  # 로컬 스토리지
  shared_preferences: ^2.0.0

  # 푸시 알림
  flutter_local_notifications: ^17.0.0

  # 네트워크
  http: ^1.2.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true

  assets:
    - assets/
```

### 7.3 Flutter WebView 구현

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:aspn_ai_agent_mobile/screens/webview_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASPN AI Agent',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D4487),
        ),
        useMaterial3: true,
      ),
      home: const WebViewScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

```dart
// lib/screens/webview_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:aspn_ai_agent_mobile/services/bridge_service.dart';
import 'package:aspn_ai_agent_mobile/services/file_picker_service.dart';
import 'package:aspn_ai_agent_mobile/services/notification_service.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? webViewController;
  late BridgeService bridgeService;
  late FilePickerService filePickerService;
  late NotificationService notificationService;

  // 개발 환경: Vite 개발 서버
  // 프로덕션 환경: 빌드된 웹 앱 호스팅 URL
  static const String webUrl = String.fromEnvironment(
    'WEB_URL',
    defaultValue: 'http://10.0.2.2:5173', // Android 에뮬레이터용
    // defaultValue: 'http://localhost:5173', // iOS 시뮬레이터용
  );

  @override
  void initState() {
    super.initState();
    filePickerService = FilePickerService();
    notificationService = NotificationService();
    notificationService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(webUrl),
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
            databaseEnabled: true,
            allowFileAccess: true,
            allowContentAccess: true,
            useHybridComposition: true, // Android 성능 개선
            useShouldOverrideUrlLoading: true,
            mediaPlaybackRequiresUserGesture: false,
          ),
          onWebViewCreated: (controller) {
            webViewController = controller;

            // JavaScript 핸들러 등록
            _setupJavaScriptHandlers(controller);
          },
          onLoadStart: (controller, url) {
            debugPrint('🌐 WebView started loading: $url');
          },
          onLoadStop: (controller, url) async {
            debugPrint('🌐 WebView finished loading: $url');

            // 웹뷰가 로드되면 브릿지 초기화
            bridgeService = BridgeService(controller);
          },
          onLoadError: (controller, url, code, message) {
            debugPrint('🚨 WebView load error: $message');
          },
          onConsoleMessage: (controller, consoleMessage) {
            debugPrint('📱 WebView Console: ${consoleMessage.message}');
          },
        ),
      ),
    );
  }

  // JavaScript 핸들러 설정
  void _setupJavaScriptHandlers(InAppWebViewController controller) {
    // 파일 선택 핸들러
    controller.addJavaScriptHandler(
      handlerName: 'pickFile',
      callback: (args) async {
        final result = await filePickerService.pickFile();

        if (result != null) {
          // 웹으로 파일 정보 전달
          await bridgeService.sendToWeb('fileSelected', result);
        }

        return result;
      },
    );

    // 카메라 핸들러
    controller.addJavaScriptHandler(
      handlerName: 'openCamera',
      callback: (args) async {
        final result = await filePickerService.takePhoto();

        if (result != null) {
          await bridgeService.sendToWeb('photoTaken', result);
        }

        return result;
      },
    );

    // 네이티브 알림 핸들러
    controller.addJavaScriptHandler(
      handlerName: 'showNotification',
      callback: (args) async {
        if (args.isNotEmpty) {
          final data = args[0] as Map<String, dynamic>;
          final title = data['title'] as String? ?? '';
          final body = data['body'] as String? ?? '';

          await notificationService.showNotification(
            title: title,
            body: body,
          );
        }

        return {'success': true};
      },
    );

    // 로그 핸들러 (디버깅용)
    controller.addJavaScriptHandler(
      handlerName: 'log',
      callback: (args) {
        debugPrint('📱 Web Log: ${args.join(' ')}');
        return null;
      },
    );
  }
}
```

### 7.4 Flutter 브릿지 서비스

```dart
// lib/services/bridge_service.dart
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:convert';

class BridgeService {
  final InAppWebViewController controller;

  BridgeService(this.controller);

  /// 웹으로 메시지 전송
  Future<void> sendToWeb(String type, dynamic payload) async {
    final message = jsonEncode({
      'type': type,
      'payload': payload,
    });

    // JavaScript 함수 호출
    await controller.evaluateJavascript(source: '''
      if (window.FlutterBridge && window.FlutterBridge.receive) {
        window.FlutterBridge.receive($message);
      }
    ''');
  }

  /// 웹에서 메시지 수신 (JavaScript에서 호출)
  void receiveFromWeb(String message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'] as String;
      final payload = data['payload'];

      // 타입별 처리
      switch (type) {
        case 'log':
          print('📱 Web Log: $payload');
          break;
        default:
          print('📱 Unknown message type: $type');
      }
    } catch (e) {
      print('🚨 Failed to parse message from web: $e');
    }
  }
}
```

### 7.5 Flutter 파일 선택 서비스

```dart
// lib/services/file_picker_service.dart
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

class FilePickerService {
  final ImagePicker _imagePicker = ImagePicker();

  /// 파일 선택
  Future<Map<String, dynamic>?> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        return {
          'name': file.name,
          'path': file.path,
          'size': file.size,
          'extension': file.extension,
        };
      }

      return null;
    } catch (e) {
      print('🚨 File picker error: $e');
      return null;
    }
  }

  /// 카메라로 사진 촬영
  Future<Map<String, dynamic>?> takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        final File file = File(photo.path);
        final bytes = await file.readAsBytes();
        final base64Image = base64Encode(bytes);

        return {
          'name': photo.name,
          'path': photo.path,
          'base64': base64Image,
          'mimeType': photo.mimeType,
        };
      }

      return null;
    } catch (e) {
      print('🚨 Camera error: $e');
      return null;
    }
  }

  /// 갤러리에서 이미지 선택
  Future<Map<String, dynamic>?> pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final File file = File(image.path);
        final bytes = await file.readAsBytes();
        final base64Image = base64Encode(bytes);

        return {
          'name': image.name,
          'path': image.path,
          'base64': base64Image,
          'mimeType': image.mimeType,
        };
      }

      return null;
    } catch (e) {
      print('🚨 Image picker error: $e');
      return null;
    }
  }
}
```

### 7.6 Flutter 알림 서비스

```dart
// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'aspn_ai_agent_channel',
      'ASPN AI Agent',
      channelDescription: 'ASPN AI Agent notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('📱 Notification tapped: ${response.payload}');
    // TODO: 알림 탭 시 처리 로직
  }
}
```

### 7.7 React에서 Flutter 브릿지 사용

```typescript
// src/bridge/flutterBridge.ts

interface FlutterBridgeInterface {
  pickFile: () => Promise<any>;
  openCamera: () => Promise<any>;
  showNotification: (data: { title: string; body: string }) => Promise<any>;
  log: (message: string) => void;
  receive?: (message: any) => void;
}

class FlutterBridge {
  private isAvailable = false;
  private eventHandlers: Map<string, Function[]> = new Map();

  constructor() {
    this.checkAvailability();
    this.setupReceiver();
  }

  private checkAvailability() {
    // Flutter WebView에서 주입한 JavaScript 핸들러 확인
    this.isAvailable = !!(window as any).flutter_inappwebview;

    if (this.isAvailable) {
      console.log('✅ Flutter bridge available');
    } else {
      console.warn('⚠️ Flutter bridge not available (running in browser)');
    }
  }

  private setupReceiver() {
    // Flutter에서 웹으로 메시지 수신
    (window as any).FlutterBridge = {
      receive: (message: any) => {
        const { type, payload } = message;

        // 타입별 이벤트 핸들러 실행
        const handlers = this.eventHandlers.get(type);
        if (handlers) {
          handlers.forEach(handler => handler(payload));
        }
      },
    };
  }

  // 이벤트 핸들러 등록
  on(event: string, handler: Function) {
    if (!this.eventHandlers.has(event)) {
      this.eventHandlers.set(event, []);
    }
    this.eventHandlers.get(event)!.push(handler);
  }

  // 이벤트 핸들러 제거
  off(event: string, handler: Function) {
    const handlers = this.eventHandlers.get(event);
    if (handlers) {
      const index = handlers.indexOf(handler);
      if (index > -1) {
        handlers.splice(index, 1);
      }
    }
  }

  // 파일 선택
  async pickFile(): Promise<any> {
    if (!this.isAvailable) {
      console.warn('Flutter bridge not available');
      // 브라우저에서는 HTML input으로 폴백
      return this.browserFilePickerFallback();
    }

    try {
      const result = await (window as any).flutter_inappwebview.callHandler(
        'pickFile'
      );
      return result;
    } catch (error) {
      console.error('Failed to pick file:', error);
      return null;
    }
  }

  // 카메라 열기
  async openCamera(): Promise<any> {
    if (!this.isAvailable) {
      console.warn('Flutter bridge not available');
      return null;
    }

    try {
      const result = await (window as any).flutter_inappwebview.callHandler(
        'openCamera'
      );
      return result;
    } catch (error) {
      console.error('Failed to open camera:', error);
      return null;
    }
  }

  // 네이티브 알림 표시
  async showNotification(title: string, body: string): Promise<void> {
    if (!this.isAvailable) {
      console.warn('Flutter bridge not available');
      // 브라우저에서는 Notification API로 폴백
      if ('Notification' in window && Notification.permission === 'granted') {
        new Notification(title, { body });
      }
      return;
    }

    try {
      await (window as any).flutter_inappwebview.callHandler(
        'showNotification',
        { title, body }
      );
    } catch (error) {
      console.error('Failed to show notification:', error);
    }
  }

  // 로그 (디버깅용)
  log(message: string): void {
    if (this.isAvailable) {
      (window as any).flutter_inappwebview.callHandler('log', message);
    } else {
      console.log('[FlutterBridge]', message);
    }
  }

  // 브라우저 파일 선택 폴백
  private browserFilePickerFallback(): Promise<File | null> {
    return new Promise((resolve) => {
      const input = document.createElement('input');
      input.type = 'file';
      input.onchange = (e: any) => {
        const file = e.target?.files?.[0];
        resolve(file || null);
      };
      input.click();
    });
  }
}

export const flutterBridge = new FlutterBridge();

// 전역 타입 선언
declare global {
  interface Window {
    FlutterBridge?: FlutterBridgeInterface;
    flutter_inappwebview?: any;
  }
}
```

### 7.8 React 컴포넌트에서 Flutter 브릿지 사용 예시

```tsx
// src/components/chat/ChatInput.tsx
import React, { useState } from 'react';
import { flutterBridge } from '@/bridge/flutterBridge';
import { useChatStore } from '@/stores/chatStore';

export const ChatInput: React.FC = () => {
  const [message, setMessage] = useState('');
  const { sendMessage } = useChatStore();

  const handleFileSelect = async () => {
    try {
      const file = await flutterBridge.pickFile();

      if (file) {
        console.log('Selected file:', file);
        // TODO: 파일 업로드 처리
      }
    } catch (error) {
      console.error('Failed to select file:', error);
    }
  };

  const handleCameraOpen = async () => {
    try {
      const photo = await flutterBridge.openCamera();

      if (photo) {
        console.log('Captured photo:', photo);
        // TODO: 사진 업로드 처리
      }
    } catch (error) {
      console.error('Failed to open camera:', error);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (message.trim()) {
      await sendMessage(message);
      setMessage('');
    }
  };

  return (
    <form onSubmit={handleSubmit} className="p-4">
      <div className="flex items-center space-x-2">
        {/* 파일 첨부 버튼 */}
        <button
          type="button"
          onClick={handleFileSelect}
          className="p-2 text-gray-500 hover:bg-gray-100 rounded-full"
        >
          📎
        </button>

        {/* 카메라 버튼 */}
        <button
          type="button"
          onClick={handleCameraOpen}
          className="p-2 text-gray-500 hover:bg-gray-100 rounded-full"
        >
          📷
        </button>

        {/* 메시지 입력 */}
        <input
          type="text"
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          placeholder="메시지를 입력하세요..."
          className="flex-1 input-field"
        />

        {/* 전송 버튼 */}
        <button
          type="submit"
          disabled={!message.trim()}
          className="btn-primary px-6 disabled:opacity-50"
        >
          전송
        </button>
      </div>
    </form>
  );
};
```

---

## 8. 개발 로드맵

### Phase 1: 기본 인프라 구축 (1-2주)

**목표**: 프로젝트 초기 설정 및 개발 환경 구축

- [x] React + Vite 프로젝트 생성
- [x] Tailwind CSS 설정
- [x] 디렉토리 구조 설계
- [x] ESLint, Prettier 설정
- [x] TypeScript 타입 정의
- [x] Zustand 상태 관리 설정
- [x] React Router 라우팅 설정
- [x] IndexedDB (Dexie) 초기 설정
- [x] Axios 클라이언트 설정

**산출물**:
- 기본 프로젝트 구조
- 공통 컴포넌트 (Button, Input, Modal 등)
- 레이아웃 컴포넌트 (Header, Sidebar 등)

---

### Phase 2: 인증 & 사용자 관리 (1주)

**목표**: 로그인, 자동 로그인, 개인정보 동의 구현

- [x] 로그인 페이지 UI
- [x] 인증 API 연동
- [x] 로그인 상태 관리 (Zustand)
- [x] 자동 로그인 기능
- [x] 개인정보 동의 팝업
- [x] 로그아웃 기능
- [x] 토큰 관리

**산출물**:
- LoginPage 컴포넌트
- authStore
- authApi
- PrivacyAgreement 컴포넌트

---

### Phase 3: 채팅 기능 구현 (2-3주)

**목표**: 채팅 인터페이스, AI 응답, 로컬 DB 연동

- [x] 채팅 페이지 레이아웃
- [x] 아카이브 목록 UI
- [x] 채팅 메시지 리스트
- [x] 메시지 입력 & 전송
- [x] AI 응답 스트리밍
- [x] 마크다운 렌더링
- [x] 코드 블록 하이라이팅
- [x] 아카이브 생성/수정/삭제
- [x] 로컬 DB 저장
- [x] 서버 ↔ 로컬 동기화

**산출물**:
- ChatPage 컴포넌트
- ChatList, ChatMessage 컴포넌트
- ChatInput 컴포넌트
- ArchiveList 컴포넌트
- chatStore
- archiveApi
- IndexedDB 스키마

---

### Phase 4: 파일 첨부 기능 (1주)

**목표**: 파일 업로드, 이미지 미리보기

- [x] 파일 선택 UI
- [x] Drag & Drop 지원
- [x] 이미지 미리보기
- [x] 파일 업로드 API
- [x] 진행 상태 표시
- [x] 업로드된 파일 렌더링

**산출물**:
- FileUpload 컴포넌트
- AttachmentPreview 컴포넌트
- fileApi

---

### Phase 5: 실시간 기능 (1-2주)

**목표**: WebSocket, AMQP 연동, 알림

- [x] WebSocket 연결 관리
- [x] AMQP 브릿지 구현
- [x] 실시간 알림 수신
- [x] 생일 메시지 팝업
- [x] 알림 리스트
- [x] 푸시 알림 (Flutter 연동)

**산출물**:
- WebSocketManager
- AMQPClient
- NotificationStore
- BirthdayPopup 컴포넌트
- AlertList 컴포넌트

---

### Phase 6: Flutter 모바일 앱 통합 (2주)

**목표**: Flutter WebView, 네이티브 기능 연동

- [x] Flutter 프로젝트 생성
- [x] WebView 설정
- [x] JavaScript 브릿지 구현
- [x] 파일 선택 연동
- [x] 카메라 연동
- [x] 푸시 알림 연동
- [x] 양방향 통신 테스트

**산출물**:
- Flutter 모바일 앱
- WebViewScreen
- BridgeService
- FilePickerService
- NotificationService
- flutterBridge.ts

---

### Phase 7: 사내 업무 기능 (2-3주)

**목표**: 휴가 관리, 전자결재, SAP 연동

- [ ] 휴가 관리 페이지
- [ ] 휴가 신청 폼
- [ ] 전자결재 목록
- [ ] 결재 상세 보기
- [ ] SAP 모듈 연동
- [ ] 승인자 권한 관리

**산출물**:
- LeaveManagementPage
- ApprovalPage
- SAPModule 컴포넌트
- 관련 API 서비스

---

### Phase 8: 테마 & UI 개선 (1주)

**목표**: 다크 모드, 반응형 디자인

- [x] 라이트/다크 테마 전환
- [x] 테마 상태 관리
- [x] 모바일 반응형 레이아웃
- [x] 터치 제스처 최적화
- [x] 애니메이션 추가

**산출물**:
- ThemeStore
- 테마 CSS 변수
- 반응형 레이아웃 컴포넌트

---

### Phase 9: 테스트 & 최적화 (1-2주)

**목표**: 버그 수정, 성능 최적화

- [ ] 단위 테스트 (Jest)
- [ ] 통합 테스트
- [ ] E2E 테스트 (Playwright)
- [ ] 성능 프로파일링
- [ ] 번들 크기 최적화
- [ ] 코드 스플리팅
- [ ] 이미지 최적화
- [ ] 오프라인 지원 (PWA)

**산출물**:
- 테스트 커버리지 리포트
- 성능 최적화 리포트
- PWA 설정 (manifest.json, service-worker.js)

---

### Phase 10: 배포 & 모니터링 (1주)

**목표**: 프로덕션 배포, 모니터링 설정

- [ ] 웹 앱 빌드 & 배포
- [ ] Flutter 앱 빌드 (Android/iOS)
- [ ] 앱스토어 제출
- [ ] 에러 모니터링 (Sentry)
- [ ] 애널리틱스 (Google Analytics)
- [ ] 사용자 피드백 수집

**산출물**:
- 프로덕션 웹 앱 URL
- Android APK/AAB
- iOS IPA
- 모니터링 대시보드

---

## 9. 배포 전략

### 9.1 모바일 웹 배포

#### 개발 환경
```bash
# Vite 개발 서버 실행
npm run dev
# → http://localhost:5173
```

#### 프로덕션 빌드
```bash
# 빌드
npm run build

# 빌드 결과 프리뷰
npm run preview
```

#### 호스팅 옵션
1. **Vercel** (추천)
   - 자동 배포
   - 무료 SSL
   - CDN 제공

2. **Netlify**
   - 유사한 기능
   - 폼 처리 기능

3. **AWS S3 + CloudFront**
   - 완전한 커스터마이징
   - 높은 트래픽 처리

4. **자체 서버**
   - Nginx 또는 Apache
   - Docker 컨테이너

### 9.2 Flutter 앱 배포

#### Android 빌드
```bash
# APK 빌드 (테스트용)
flutter build apk --release

# AAB 빌드 (Google Play 제출용)
flutter build appbundle --release
```

#### iOS 빌드
```bash
# iOS 빌드
flutter build ios --release

# Xcode에서 Archive 생성
open ios/Runner.xcworkspace
```

#### 앱스토어 제출
1. **Google Play Store**
   - AAB 파일 업로드
   - 스크린샷, 설명 작성
   - 심사 제출

2. **Apple App Store**
   - App Store Connect에서 앱 등록
   - TestFlight 베타 테스트
   - 심사 제출

### 9.3 환경 변수 관리

```bash
# .env.development
VITE_API_BASE_URL=http://localhost:8000
VITE_WS_URL=ws://localhost:8000/ws
VITE_ENV=development

# .env.production
VITE_API_BASE_URL=https://api.yourserver.com
VITE_WS_URL=wss://api.yourserver.com/ws
VITE_ENV=production
```

### 9.4 CI/CD 파이프라인

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build

      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v20
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.ORG_ID }}
          vercel-project-id: ${{ secrets.PROJECT_ID }}
```

---

## 10. 참고 자료

### 공식 문서
- [React 공식 문서](https://react.dev/)
- [Vite 공식 문서](https://vitejs.dev/)
- [Flutter 공식 문서](https://flutter.dev/)
- [Zustand 문서](https://docs.pmnd.rs/zustand/getting-started/introduction)
- [Tailwind CSS 문서](https://tailwindcss.com/docs)
- [Dexie.js 문서](https://dexie.org/)

### 패키지 문서
- [webview_flutter](https://pub.dev/packages/webview_flutter)
- [flutter_inappwebview](https://pub.dev/packages/flutter_inappwebview)
- [react-markdown](https://github.com/remarkjs/react-markdown)
- [react-syntax-highlighter](https://github.com/react-syntax-highlighter/react-syntax-highlighter)

### 추가 참고
- [IndexedDB API](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API)
- [WebSocket API](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket)
- [Progressive Web Apps](https://web.dev/progressive-web-apps/)

---

## 부록: 트러블슈팅

### A. CORS 이슈
**문제**: 개발 환경에서 API 호출 시 CORS 에러

**해결**:
```typescript
// vite.config.ts
server: {
  proxy: {
    '/api': {
      target: 'http://your-backend-server.com',
      changeOrigin: true,
    },
  },
}
```

### B. WebView에서 로컬 스토리지 접근 불가
**문제**: Flutter WebView에서 localStorage가 작동하지 않음

**해결**:
```dart
// initialSettings 설정
domStorageEnabled: true,
databaseEnabled: true,
```

### C. Android에서 네트워크 보안 이슈
**문제**: Android에서 HTTP 연결이 차단됨

**해결**:
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<application
  android:usesCleartextTraffic="true">
</application>
```

### D. iOS에서 카메라/파일 접근 권한
**문제**: iOS에서 카메라나 파일에 접근할 수 없음

**해결**:
```xml
<!-- ios/Runner/Info.plist -->
<key>NSCameraUsageDescription</key>
<string>사진을 찍기 위해 카메라 접근이 필요합니다.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>사진을 선택하기 위해 갤러리 접근이 필요합니다.</string>
```

---

**문서 버전**: 1.0
**최종 업데이트**: 2025-10-20
**작성자**: Claude Code

이 문서는 ASPN AI Agent 모바일 WebView 앱 개발을 위한 완전한 가이드입니다. 실제 구현 시 이 문서를 참고하여 단계별로 진행하시면 됩니다.
