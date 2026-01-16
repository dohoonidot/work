# 아카이브 기능 비교 분석 (Flutter vs React)

## 개요
Flutter Window App (`lib`)과 React Web App (`web_app/src`)의 채팅 아카이브 관련 기능을 비교 분석합니다.

---

## 1. 아카이브 생성 (Create Archive)

### Flutter (`lib/shared/providers/chat_notifier.dart`)
- **함수**: `createNewArchive({String archiveType = '', bool shouldUpdateUI = true})`
- **기능**:
  - 아카이브 타입에 따라 자동 타이틀 설정
    - `code` → "코딩 어시스턴트"
    - `sap` → "SAP 어시스턴트"
    - 기타 → "new chat ${state.arvChatHistory.length - 2}"
  - 서버에 아카이브 생성 요청 (`ApiService.createArchive`)
  - 로컬 DB에 저장
  - UI 업데이트 옵션 (`shouldUpdateUI`)
  - 새 아카이브 선택 및 상세 정보 로드

### React (`web_app/src/services/chatService.ts`, `web_app/src/pages/ChatPage.tsx`)
- **함수**: `createArchive(userId: string, archiveType: string)`
- **기능**:
  - 기본 아카이브 타입 중복 체크 (이미 존재하면 선택만)
  - 서버에 아카이브 생성 요청
  - 타입에 따라 이름 자동 설정 및 업데이트
  - 목록에 추가 및 정렬
  - 새 아카이브 선택

### 비교 결과
✅ **구현됨**: React에도 아카이브 생성 기능이 구현되어 있음
- Flutter의 `shouldUpdateUI` 옵션은 React에 없지만, 필요 시 추가 가능
- 기본 아카이브 중복 체크 로직이 React에 추가로 구현됨

---

## 2. 아카이브 삭제 (Delete Archive)

### Flutter (`lib/shared/providers/chat_notifier.dart`)
- **함수**: 
  - `deleteArchive(BuildContext context, String archiveId, {bool notifyUI = true})`
  - `deleteSelectedArchives(BuildContext context, Set<String> archiveIds)`
- **기능**:
  - 서버 DB에서 먼저 삭제 (`ApiService.deleteArchive`)
  - 로컬 DB에서 삭제
  - 삭제된 아카이브가 현재 선택된 아카이브였다면 최상단 아카이브로 자동 선택
  - 전체 삭제 시 상태 초기화
  - UI 업데이트 옵션 (`notifyUI`)
  - 스낵바 알림 표시

### React (`web_app/src/services/chatService.ts`, `web_app/src/pages/ChatPage.tsx`)
- **함수**: `deleteArchive(archiveId: string)`
- **기능**:
  - 서버에 삭제 요청
  - 아카이브 목록 새로고침
  - 삭제된 아카이브가 현재 선택된 아카이브였다면 첫 번째 아카이브 선택
  - 스낵바 알림 표시

### 비교 결과
✅ **구현됨**: React에도 아카이브 삭제 기능이 구현되어 있음
- Flutter의 `deleteSelectedArchives` (다중 삭제) 기능은 React에 없음
- Flutter의 `notifyUI` 옵션은 React에 없지만, 필요 시 추가 가능
- 로컬 DB 삭제는 Flutter만 수행 (React는 서버 기반)

---

## 3. 아카이브 타이틀 수정 (Edit Archive Title)

### Flutter (`lib/shared/providers/chat_notifier.dart`)
- **함수**: `editArchiveTitle(String archiveId, String newTitle, {bool updateUI = true})`
- **기능**:
  - 기본 아카이브 이름 제한 로직 제거됨 (주석 처리)
  - 서버 API 호출 (`ApiService.updateArchive`)
  - 로컬 DB 업데이트
  - UI 상태 업데이트 옵션 (`updateUI`)
  - 선택된 토픽 제목도 함께 업데이트

### React (`web_app/src/services/chatService.ts`, `web_app/src/pages/ChatPage.tsx`)
- **함수**: `updateArchive(userId: string, archiveId: string, newName: string)`
- **기능**:
  - 기본 아카이브 이름 제한 로직 있음 (사내업무, AI Chatbot, 코딩어시스턴트, SAP 어시스턴트)
  - 서버 API 호출
  - 아카이브 목록 새로고침
  - 현재 선택된 아카이브의 이름도 업데이트
  - 스낵바 알림 표시

### 비교 결과
✅ **구현됨**: React에도 아카이브 타이틀 수정 기능이 구현되어 있음
- React에는 기본 아카이브 이름 제한이 있지만, Flutter는 제거됨 (차이점)
- Flutter의 `updateUI` 옵션은 React에 없지만, 필요 시 추가 가능
- 로컬 DB 업데이트는 Flutter만 수행 (React는 서버 기반)

---

## 4. 기본 아카이브 초기화 (Reset Archive)

### Flutter (`lib/shared/providers/chat_notifier.dart`)
- **함수**: `resetArchive(BuildContext context, String archiveId, String archiveType, String archiveName)`
- **기능**:
  1. 기존 아카이브 정보 저장
  2. 백엔드에서 아카이브 삭제 (UI 업데이트 없이)
  3. 동일한 타입의 새 아카이브 생성 (UI 업데이트 없이)
  4. UI 상태 업데이트 (기존 아카이브 정보에 새 ID 반영)
  5. 상태 업데이트 (selectedTopic, currentArchiveId)
  6. 기본 아카이브인 경우 제목 변경 (백엔드만 업데이트)
  7. 새 아카이브 선택

### React (`web_app/src/services/chatService.ts`)
- **함수**: `resetArchive(userId: string, archiveId: string, archiveType: string, archiveName: string)`
- **기능**:
  1. 기존 아카이브 삭제
  2. 동일한 타입의 새 아카이브 생성
  3. 기본 아카이브인 경우 제목 변경
  4. 새 아카이브 ID 반환

### 비교 결과
✅ **구현됨**: React에도 기본 아카이브 초기화 기능이 구현되어 있음
- Flutter는 UI 상태를 직접 업데이트하지만, React는 새 아카이브 ID만 반환
- React는 `ChatPage`에서 초기화 후 목록 새로고침 및 선택 처리

---

## 5. 아카이브 초기화 (Initialize Archive)

### Flutter (`lib/shared/providers/chat_notifier.dart`)
- **함수**: `_initializeArchive()`
- **기능**:
  - userId가 비어있으면 건너뜀 (로그아웃 상태)
  - 아카이브 목록 불러오기 (`getArchiveListAll`)
  - 아카이브가 있으면 첫 번째 아카이브 선택
  - 선택된 아카이브의 상세 정보 로드

### React (`web_app/src/pages/ChatPage.tsx`)
- **함수**: `createDefaultArchive()`
- **기능**:
  - 기본 아카이브 4개 생성 (사내업무, AI Chatbot, 코딩어시스턴트, SAP 어시스턴트)
  - 아카이브 목록 새로고침
  - 첫 번째 아카이브 선택

### 비교 결과
⚠️ **차이점**: Flutter는 기존 아카이브를 로드하고 선택하지만, React는 기본 아카이브를 생성함
- Flutter: 기존 아카이브가 있으면 로드, 없으면 빈 상태
- React: 기본 아카이브가 없으면 생성

---

## 6. 아카이브 목록 조회 (Get Archive List)

### Flutter (`lib/shared/providers/chat_notifier.dart`)
- **함수**: `getArchiveListAll(String userId)`
- **기능**:
  - 로컬 DB에서 아카이브 조회
  - 로컬 DB에 없으면 서버와 동기화 (`DatabaseHelper.syncArchivesWithDetails`)
  - 아카이브 정렬 및 포맷팅 (`_processArchives`)
  - 기본 아카이브 우선 정렬 (사내업무, 코딩어시스턴트, SAP 어시스턴트, AI Chatbot)

### React (`web_app/src/services/chatService.ts`)
- **함수**: `getArchiveList(userId: string)`
- **기능**:
  - 서버에서 아카이브 목록 조회
  - 204 응답 시 빈 배열 반환
  - 500 에러 시 빈 배열 반환 (에러 처리)

### 비교 결과
✅ **구현됨**: React에도 아카이브 목록 조회 기능이 구현되어 있음
- Flutter는 로컬 DB 우선, React는 서버 직접 조회
- Flutter의 정렬 로직은 React에도 구현되어 있음 (`ChatPage.tsx`의 `getArchiveOrder`)

---

## 7. 사이드바 UI 기능

### Flutter
- 아카이브 목록 표시
- 아카이브 선택
- 아카이브 생성 버튼
- 아카이브 메뉴 (이름 변경, 삭제/초기화)
- 기본 아카이브 아이콘 및 색상 구분

### React (`web_app/src/components/chat/ChatSidebar.tsx`)
- 아카이브 목록 표시
- 아카이브 선택
- 아카이브 생성 버튼
- 아카이브 메뉴 (이름 변경, 삭제/초기화)
- 기본 아카이브 아이콘 및 색상 구분

### 비교 결과
✅ **구현됨**: React에도 사이드바 UI 기능이 모두 구현되어 있음

---

## 종합 비교 결과

### ✅ 구현 완료된 기능
1. ✅ 아카이브 생성
2. ✅ 아카이브 삭제
3. ✅ 아카이브 타이틀 수정
4. ✅ 기본 아카이브 초기화
5. ✅ 아카이브 목록 조회
6. ✅ 사이드바 UI 기능

### ⚠️ 차이점 및 개선 사항

1. **다중 삭제 기능**
   - Flutter: `deleteSelectedArchives`로 여러 아카이브 동시 삭제 가능
   - React: 단일 삭제만 지원
   - **권장**: React에도 다중 삭제 기능 추가 고려

2. **로컬 DB 사용**
   - Flutter: 로컬 DB 우선 사용, 서버와 동기화
   - React: 서버 직접 조회 (로컬 DB 없음)
   - **현황**: 웹 앱 특성상 로컬 DB가 없어도 문제없음

3. **기본 아카이브 이름 제한**
   - Flutter: 제한 로직 제거됨 (주석 처리)
   - React: 제한 로직 있음
   - **권장**: Flutter와 동일하게 제한 로직 제거 고려

4. **UI 업데이트 옵션**
   - Flutter: `shouldUpdateUI`, `notifyUI`, `updateUI` 옵션 제공
   - React: 항상 UI 업데이트
   - **현황**: React는 단순한 구조로 충분

5. **아카이브 초기화 로직**
   - Flutter: 기존 아카이브 로드 후 선택
   - React: 기본 아카이브 생성
   - **권장**: React의 `createDefaultArchive` 로직을 Flutter와 동일하게 수정 고려

---

## 결론

**React 웹 앱의 아카이브 관련 기능은 Flutter 앱과 대부분 동일하게 구현되어 있습니다.**

주요 기능(생성, 삭제, 타이틀 수정, 초기화)이 모두 구현되어 있으며, UI도 Flutter와 유사하게 구성되어 있습니다.

다만, 다중 삭제 기능과 기본 아카이브 이름 제한 로직의 차이점이 있으므로, 필요 시 개선을 고려할 수 있습니다.

