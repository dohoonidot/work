# Flutter vs React Web App - 기능 비교 분석

## 📊 전체 요약

### ✅ 구현 완료된 기능 (85%)
대부분의 핵심 기능이 React 웹앱에 성공적으로 구현되어 있습니다.

### ⚠️ 부분 구현 또는 누락된 기능 (15%)
일부 UI 컴포넌트와 고급 기능이 누락되었거나 간소화되어 있습니다.

---

## 1. 화면/페이지 비교

| 화면 | Flutter (lib/) | React (web_app/) | 상태 |
|------|----------------|------------------|------|
| **로그인** | ✅ login_page.dart | ✅ LoginPage.tsx | 완료 |
| **메인 채팅** | ✅ chat_home_page_v5.dart | ✅ ChatPage.tsx | 완료 (Desktop/Mobile 분리됨) |
| **코딩 어시스턴트** | ✅ coding_assistant_page.dart | ✅ CodingAssistantPage.tsx | 완료 |
| **AI 어시스턴트** | ✅ N/A (메인에 통합) | ✅ AiAssistantPage.tsx | 완료 |
| **SAP 페이지** | ✅ sap_main_page.dart | ✅ SapPage.tsx | 완료 |
| **휴가 관리** | ✅ leave_management_screen.dart | ✅ LeaveManagementPage.tsx | 완료 |
| **관리자 휴가 승인** | ✅ admin_leave_approval_page.dart | ✅ AdminLeaveApprovalPage.tsx | 완료 |
| **전자 결재** | ✅ signflow_screen.dart | ✅ ApprovalPage.tsx | 완료 |
| **선물 시스템** | ✅ gift_screen.dart | ✅ GiftPage.tsx | 완료 |
| **설정** | ✅ settings_page.dart | ✅ SettingsPage.tsx | 완료 |
| **투표/콘테스트** | ✅ voting_screen.dart | ✅ ContestPage.tsx | 완료 |
| **비밀번호 변경** | ✅ password_change_page.dart | ❌ 미구현 | 누락 |

---

## 2. 핵심 기능 비교

### 2.1 인증 시스템

| 기능 | Flutter | React | 차이점 |
|------|---------|-------|--------|
| **로그인** | ✅ | ✅ | 동일 |
| **자동 로그인** | ✅ rememberMeProvider | ✅ localStorage | 동일 |
| **토큰 관리** | ✅ SQLite | ✅ localStorage | 저장소 다름 |
| **이메일 도메인 고정** | ✅ EmailTextEditingController | ❓ 확인 필요 | 확인 필요 |
| **비밀번호 변경** | ✅ password_change_page | ❌ | **누락** |

### 2.2 채팅 시스템

| 기능 | Flutter | React | 상태 |
|------|---------|-------|------|
| **아카이브 관리** | ✅ | ✅ | 완료 |
| **메시지 스트리밍** | ✅ | ✅ SSE | 완료 |
| **AI 모델 선택** | ✅ | ✅ | 완료 |
| **마크다운 렌더링** | ✅ gpt_markdown | ✅ react-markdown | 완료 |
| **CoT 파싱** | ✅ cot_renderer.dart | ✅ `<think>` 태그 | 완료 |
| **코드 하이라이팅** | ✅ flutter_highlighting | ✅ react-syntax-highlighter | 완료 |
| **파일 첨부** | ✅ desktop_drop, file_picker | ✅ fileService | 완료 |
| **검색** | ✅ searchKeyword in state | ✅ SearchDialog | 완료 |
| **메시지 캐싱** | ✅ cache_manager.dart | ✅ IndexedDB | 완료 |

### 2.3 실시간 알림

| 기능 | Flutter | React | 차이점 |
|------|---------|-------|--------|
| **실시간 연결** | ✅ AMQP (RabbitMQ) | ✅ WebSocket | **프로토콜 다름** |
| **생일 알림** | ✅ | ✅ | 완료 |
| **선물 알림** | ✅ | ✅ | 완료 |
| **이벤트 알림** | ✅ | ✅ | 완료 |
| **결재 알림** | ✅ | ✅ | 완료 |
| **자동 재연결** | ✅ Exponential backoff | ✅ 8초 delay + backoff | 완료 |

### 2.4 UI 컴포넌트

| 컴포넌트 | Flutter | React | 상태 |
|----------|---------|-------|------|
| **사이드바** | ✅ sidebar.dart | ✅ ChatSidebar.tsx | 완료 |
| **채팅 영역** | ✅ chat_area_v3.dart | ✅ ChatArea.tsx | 완료 |
| **AI 모델 셀렉터** | ✅ ai_model_selector.dart | ✅ AiModelSelector.tsx | 완료 |
| **첨부파일 프리뷰** | ✅ attachment_preview.dart | ⚠️ 간소화됨 | 개선 필요 |
| **스크롤링 티커** | ✅ scrolling_ticker.dart | ❌ | **누락** |
| **도움말 가이드** | ✅ help_guide_dialog.dart | ❌ | **누락** |
| **윈도우 컨트롤** | ✅ window_controls.dart | ❌ (웹이라 불필요) | N/A |
| **결재 패널** | ✅ Slide-in panel | ❌ | **누락** |
| **Confetti 효과** | ✅ confetti package | ❌ | **누락** |

---

## 3. 상태 관리 비교

### Flutter (Riverpod)
```dart
// 46개 이상의 Provider
- userIdProvider
- chatProvider (ChatNotifier)
- selectedAiModelProvider
- themeProvider
- notificationNotifier
- attachmentProvider
- alertTickerProvider
- etc.
```

### React (Zustand)
```typescript
// 2개의 주요 Store
- chatStore (아카이브, 메시지, 스트리밍 상태)
- themeStore (테마, 색상 스킴)
```

**차이점:**
- Flutter: 더 세분화된 Provider 구조
- React: 더 단순한 Store 구조 (기능은 동일)

---

## 4. 데이터베이스 비교

| 항목 | Flutter | React |
|------|---------|-------|
| **기술** | SQLite (sqflite_ffi) | IndexedDB |
| **위치** | Documents/aspn_agent.db | 브라우저 IndexedDB |
| **스키마** | 9개 테이블 (archives, chats, users, leave_requests, approval_requests 등) | 3개 Store (archives, messages, settings) |
| **마이그레이션** | ✅ Version 9 migration | ❌ 미구현 |
| **오프라인** | ✅ | ✅ |

---

## 5. 서비스 레이어 비교

### Flutter Services (lib/services/)
```
1. api_service.dart - API 호출
2. amqp_service.dart - AMQP 실시간
3. stream_service.dart - 스트리밍
4. leave_api_service.dart - 휴가 API
5. gift_service.dart - 선물
6. contest_api_service.dart - 콘테스트
7. system_tray_service.dart - 시스템 트레이
8. clipboard_image_service.dart - 클립보드
9. background_init_service.dart - 백그라운드 초기화
10. update_service.dart - 자동 업데이트
```

### React Services (web_app/src/services/)
```
1. api.ts - Axios 인스턴스
2. authService.ts - 인증
3. chatService.ts - 채팅 (25개 메서드!)
4. leaveService.ts - 휴가 관리
5. giftService.ts - 선물
6. settingsService.ts - 설정
7. indexedDBService.ts - 로컬 DB
8. websocketService.ts - WebSocket 실시간
9. fileService.ts - 파일 업로드
```

**누락된 서비스:**
- ❌ 클립보드 이미지 서비스
- ❌ 백그라운드 초기화 (웹에서는 불필요)
- ❌ 시스템 트레이 (웹에서는 불가능)
- ❌ 자동 업데이트 (웹은 새로고침)

---

## 6. 테마 시스템 비교

### Flutter
```dart
// app_theme.dart + color_schemes.dart
- AppThemeMode: light, codingDark, system
- AppColorScheme: 46개 색상 속성
- Material Design 3
- Spoqa Han Sans Neo 폰트
```

### React
```typescript
// themeStore.ts + app_theme.ts
- AppThemeMode: LIGHT, CODING_DARK, SYSTEM
- AppColorScheme: 40개 색상 속성
- Material-UI Theme
- Spoqa Han Sans Neo 폰트
```

**상태:** ✅ 거의 동일

---

## 7. 반응형 디자인 상태

### 현재 구현 (문제점)
```typescript
// ChatPage.tsx - 별도 컴포넌트로 분리
{isMobile ? (
  <MobileChatPage />
) : (
  <DesktopChatPage />
)}
```

### 사용자 요구사항
> "모바일 웹 버전 데스크톱 웹버전 나누지말고, 그냥 데스크톱웹 버전의 크기를 모바일로 줄이게되면 모바일에서 보기편한 UI로 변하도록해"

**필요한 작업:**
1. DesktopChatPage와 MobileChatPage를 하나의 컴포넌트로 통합
2. CSS Grid/Flexbox + Media Query로 반응형 구현
3. Breakpoint (900px)에서 자동으로 레이아웃 변경
4. 조건부 렌더링 대신 CSS display 속성 활용

---

## 8. 누락된 기능 상세

### 8.1 알림 티커 (Notification Ticker)
**Flutter:**
```dart
// scrolling_ticker.dart
- 상단에 가로로 스크롤되는 알림 배너
- 자동 루프
- 메시지 타입별 색상
```

**React:** ❌ 미구현

**구현 방법:**
```typescript
// ScrollingTicker.tsx 생성
- CSS animation: marquee
- WebSocket 알림 메시지 연동
- 자동 사라짐 기능
```

---

### 8.2 결재 슬라이드 패널
**Flutter:**
```dart
// chat_home_page_v5.dart
- 우측에서 슬라이드인되는 결재 패널
- 접기/펼치기 토글
- Pin to keep open
```

**React:** ❌ 미구현

**구현 방법:**
```typescript
// ApprovalPanel.tsx 생성
- MUI Drawer 컴포넌트 사용
- Zustand store에 isApprovalPanelOpen 상태 추가
- 모바일에서는 전체 화면으로 표시
```

---

### 8.3 Confetti 효과
**Flutter:**
```dart
// confetti package
- 생일 알림 시 Confetti 애니메이션
- 선물 수령 시 축하 효과
```

**React:** ❌ 미구현

**구현 방법:**
```typescript
// npm install react-confetti
import Confetti from 'react-confetti'
// 생일/선물 알림 시 트리거
```

---

### 8.4 도움말 가이드
**Flutter:**
```dart
// help_guide_dialog.dart
- 키보드 단축키 가이드
- 기능 설명
- 검색 가능한 도움말
```

**React:** ❌ 미구현

**구현 방법:**
```typescript
// HelpDialog.tsx 생성
- MUI Dialog
- 단축키 목록 (Ctrl+K 검색, Ctrl+N 새 대화 등)
- 기능별 가이드 섹션
```

---

### 8.5 비밀번호 변경 페이지
**Flutter:**
```dart
// password_change_page.dart
- 현재 비밀번호 확인
- 새 비밀번호 입력 및 재확인
- 유효성 검사
```

**React:** ❌ 미구현

**구현 방법:**
```typescript
// PasswordChangePage.tsx 생성
// authService에 changePassword() 메서드 추가
POST /api/changePassword {
  userId, currentPassword, newPassword
}
```

---

### 8.6 파일 첨부 프리뷰 개선
**Flutter:**
```dart
// attachment_preview.dart
- 이미지 썸네일
- PDF 아이콘
- 파일명 및 크기 표시
- 제거 버튼
- 반응형 레이아웃
```

**React:** ⚠️ 기본적인 기능만 구현됨

**개선 방법:**
```typescript
// AttachmentPreview.tsx 개선
- 이미지 썸네일 생성 (FileReader API)
- PDF.js로 첫 페이지 미리보기
- 파일 타입별 아이콘
- Grid 레이아웃
```

---

## 9. 추가 개선 사항

### 9.1 키보드 단축키
**Flutter:** ✅ 구현됨
- Ctrl+V: 클립보드 붙여넣기
- Enter: 메시지 전송
- Shift+Enter: 줄바꿈

**React:** ⚠️ 부분 구현
- Enter: 메시지 전송
- Shift+Enter: 줄바꿈
- ❌ Ctrl+V 이미지 붙여넣기 미구현

---

### 9.2 로딩 상태 표시
**Flutter:**
```dart
// message_renderer.dart
- "생각 중..." 텍스트
- 회전하는 로딩 인디케이터
- 스트리밍 중 커서 표시
```

**React:** ✅ 구현됨
```typescript
// MessageRenderer.tsx
- isStreaming 상태에 따른 커서 표시
```

---

### 9.3 에러 핸들링
**Flutter:**
```dart
// api_service.dart
- 204 No Content 처리
- 400 Bad Request 처리
- 네트워크 오류 재시도
- 로컬 DB 폴백
```

**React:**
```typescript
// api.ts
- 401 Unauthorized → 로그인 페이지
- 30초 타임아웃
- ⚠️ 재시도 로직 미흡
```

---

## 10. 반응형 개선 계획

### 현재 문제점
1. Desktop/Mobile 컴포넌트가 완전히 분리됨
2. 코드 중복 (ChatArea, Sidebar 로직)
3. 화면 크기 변경 시 재마운트 발생

### 개선 방안

#### 1단계: 통합 컴포넌트 생성
```typescript
// ChatPage.tsx - 단일 컴포넌트
<Box sx={{
  display: 'grid',
  gridTemplateColumns: {
    xs: '1fr',           // 모바일: 전체 너비
    md: '280px 1fr'      // 데스크톱: 사이드바 + 채팅
  }
}}>
  <Sidebar />
  <ChatArea />
</Box>
```

#### 2단계: Breakpoint 기반 스타일링
```typescript
// 900px 미만: 모바일
// 900px 이상: 데스크톱
const theme = createTheme({
  breakpoints: {
    values: {
      xs: 0,
      sm: 600,
      md: 900,   // 주요 breakpoint
      lg: 1200,
      xl: 1536
    }
  }
})
```

#### 3단계: 조건부 렌더링 최소화
```typescript
// ❌ 나쁜 예
{isMobile ? <MobileChatPage /> : <DesktopChatPage />}

// ✅ 좋은 예
<ChatPage sx={{
  '& .sidebar': {
    display: { xs: 'none', md: 'block' }
  }
}} />
```

---

## 11. 우선순위 작업 목록

### 🔴 높음 (필수)
1. **Desktop/Mobile 통합** - 단일 반응형 컴포넌트로 변경
2. **비밀번호 변경 페이지** 구현
3. **파일 첨부 프리뷰** 개선

### 🟡 중간 (중요)
4. **알림 티커** 구현
5. **결재 슬라이드 패널** 구현
6. **Confetti 효과** 추가
7. **도움말 가이드** 구현

### 🟢 낮음 (개선)
8. Ctrl+V 이미지 붙여넣기
9. 에러 재시도 로직 개선
10. 키보드 단축키 확장

---

## 12. 결론

### ✅ 잘 구현된 부분
- 핵심 채팅 기능 (85% 완성도)
- 휴가/결재 시스템
- 실시간 알림 (프로토콜만 다름)
- 테마 시스템
- 데이터베이스 레이어

### ⚠️ 개선 필요
- **반응형 디자인** (Desktop/Mobile 통합 필요)
- **누락된 UI 컴포넌트** (티커, 패널, Confetti 등)
- **부가 기능** (비밀번호 변경, 도움말 등)

### 🎯 핵심 과제
**"Desktop/Mobile 분리 제거 → 완전한 반응형 통합"**
- 코드 중복 제거
- 더 나은 사용자 경험
- 유지보수 용이성 향상
