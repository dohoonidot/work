# React 웹앱 로컬 DB 구현 가이드

## 📌 개요

Flutter 앱의 SQLite 로컬 DB 방식을 React 웹앱에 구현한 가이드입니다.
브라우저의 **IndexedDB**를 사용하여 채팅방 목록과 대화내역을 로컬에 저장하고, 필요시 서버와 동기화합니다.

### Flutter vs React 비교

| 항목 | Flutter (Desktop) | React (Web) |
|-----|------------------|-------------|
| **로컬 DB** | SQLite | IndexedDB (Dexie.js) |
| **데이터 구조** | `local_archives`, `local_archive_details` | 동일한 구조 |
| **동기화 방식** | 로그인 시 + 증분 동기화 | 동일 |
| **오프라인 지원** | ✅ 지원 | ✅ 지원 |
| **용량** | 무제한 | ~50MB+ (브라우저별 상이) |

## 🚀 설치 방법

### 1. Dexie.js 설치

```bash
cd web_app
npm install dexie
```

### 2. 타입 정의 (선택 사항)

```bash
npm install --save-dev @types/dexie
```

## 📁 파일 구조

```
web_app/src/
├── services/
│   ├── localDbService.ts      # ✅ 새로 생성 - IndexedDB CRUD
│   ├── syncService.ts         # ✅ 새로 생성 - 서버-로컬 동기화
│   └── chatService.ts         # 기존 유지
├── store/
│   └── chatStore.ts           # ✅ 수정 - 로컬 DB 통합
└── types/
    └── index.ts               # ChatMessage, Archive 타입 정의
```

## 🔧 주요 컴포넌트

### 1. LocalDbService (`localDbService.ts`)

IndexedDB CRUD 작업을 담당합니다.

**주요 메서드:**

```typescript
// 아카이브 목록 조회
await localDbService.getArchiveListByUserId(userId);

// 채팅 내역 조회
await localDbService.getSingleArchive(archiveId);

// 아카이브 추가/업데이트
await localDbService.upsertArchives(archives);

// 메시지 추가
await localDbService.insertMessages(messages);

// 검색
await localDbService.searchArchiveContent(searchText, userId);

// DB 초기화 (개발용)
await localDbService.clearAllData();
```

### 2. SyncService (`syncService.ts`)

서버-로컬 동기화를 담당합니다.

**주요 메서드:**

```typescript
// 통합 동기화 (아카이브 목록 + 상세 정보)
await syncService.syncArchivesWithDetails(userId);

// 로컬 DB 비어있는지 확인
await syncService.isLocalDbEmpty(userId);

// 강제 전체 동기화
await syncService.forceFullSync(userId);

// 동기화 상태 조회
await syncService.getSyncStatus(userId);
```

### 3. ChatStore (`chatStore.ts`)

Zustand 상태 관리 + 로컬 DB 통합

**주요 변경사항:**

```typescript
// 기존: 서버에서만 조회
const archives = await chatService.getArchiveList(userId);

// 변경: 로컬 DB 우선, 없으면 동기화
const localArchives = await localDbService.getArchiveListByUserId(userId);
if (localArchives.length === 0) {
  await syncService.syncArchivesWithDetails(userId);
}
```

## 📊 데이터 흐름

### 로그인 시

```
┌──────────┐
│  로그인  │
└────┬─────┘
     │
     v
┌──────────────────┐
│ loadArchives()   │ ← chatStore.ts
└────┬─────────────┘
     │
     v
┌──────────────────┐      ┌─────────────┐
│ 로컬 DB 조회     │ ──── │ IndexedDB   │
└────┬─────────────┘      └─────────────┘
     │
     ├─ 데이터 있음 ─→ ✅ 로컬 DB 사용 (서버 호출 없음)
     │
     └─ 데이터 없음 ─→ 🔄 서버 동기화
                        │
                        v
                 ┌─────────────────┐
                 │ syncService     │
                 │ .syncArchives   │
                 │ WithDetails()   │
                 └────┬────────────┘
                      │
                      v
                 ┌─────────────────┐
                 │ 서버 API 호출   │
                 │ + IndexedDB 저장│
                 └─────────────────┘
```

### 채팅방 클릭 시

```
┌──────────────────┐
│ 채팅방 클릭      │
└────┬─────────────┘
     │
     v
┌──────────────────┐
│ loadChatDetail() │ ← chatStore.ts
└────┬─────────────┘
     │
     v
┌──────────────────┐      ┌─────────────┐
│ 로컬 DB 조회     │ ──── │ IndexedDB   │
│ (서버 호출 없음) │      └─────────────┘
└────┬─────────────┘
     │
     v
✅ 채팅 내역 표시
```

### 새 메시지 전송 시

```
┌──────────────────┐
│ 메시지 전송      │
└────┬─────────────┘
     │
     v
┌──────────────────┐      ┌─────────────┐
│ 서버 API 호출    │ ───→ │ Backend     │
│ (스트리밍)       │      └─────────────┘
└────┬─────────────┘
     │
     v
┌──────────────────┐      ┌─────────────┐
│ 로컬 DB 저장     │ ───→ │ IndexedDB   │
└────┬─────────────┘      └─────────────┘
     │
     v
✅ UI 업데이트
```

## 🎯 사용 예시

### 로그인 후 아카이브 로드

```typescript
// ChatHomePage.tsx 또는 App.tsx
import { useChatStore } from './store/chatStore';

function ChatHomePage() {
  const { loadArchives } = useChatStore();

  useEffect(() => {
    loadArchives(); // 로컬 DB 우선, 없으면 서버 동기화
  }, []);

  // ...
}
```

### 채팅방 클릭

```typescript
// Sidebar.tsx
import { useChatStore } from '../store/chatStore';

function Sidebar() {
  const { loadChatDetail, setCurrentArchive } = useChatStore();

  const handleArchiveClick = async (archive: Archive) => {
    setCurrentArchive(archive);
    await loadChatDetail(archive.archive_id); // 로컬 DB에서 조회
  };

  // ...
}
```

### 메시지 전송 후 로컬 DB 저장

```typescript
// ChatArea.tsx
import localDbService from '../services/localDbService';

async function sendMessage(message: string) {
  const user = authService.getCurrentUser();
  if (!user) return;

  // 1. 사용자 메시지를 로컬 DB에 저장
  const userChatId = await localDbService.insertUserMessage(
    currentArchive.archive_id,
    message,
    user.userId
  );

  // 2. 서버로 메시지 전송 (스트리밍)
  const response = await chatService.sendMessage({
    userId: user.userId,
    archiveId: currentArchive.archive_id,
    message: message,
    aiModel: selectedModel,
    onChunk: (chunk) => {
      // 스트리밍 청크 처리
    },
  });

  // 3. AI 응답을 로컬 DB에 저장
  await localDbService.insertAgentMessage(
    currentArchive.archive_id,
    response,
    user.userId
  );

  // 4. UI 업데이트
  await loadChatDetail(currentArchive.archive_id);
}
```

### 검색 기능 (로컬 DB)

```typescript
// SearchDialog.tsx
import localDbService from '../services/localDbService';

async function performSearch(keyword: string) {
  const user = authService.getCurrentUser();
  if (!user) return;

  // 로컬 DB에서 검색 (서버 호출 없음)
  const results = await localDbService.searchArchiveContent(
    keyword,
    user.userId
  );

  setSearchResults(results);
}
```

## 🛠️ 개발자 도구

### IndexedDB 확인 (Chrome DevTools)

1. `F12` → Application 탭
2. Storage → IndexedDB → `aspn_agent_db`
3. 테이블 확인:
   - `archives` - 채팅방 목록
   - `archiveDetails` - 대화내역
   - `syncMetadata` - 동기화 정보

### 로컬 DB 초기화

```typescript
import localDbService from './services/localDbService';

// 개발 중 DB 초기화
await localDbService.clearAllData();
```

### 동기화 상태 확인

```typescript
import syncService from './services/syncService';

const status = await syncService.getSyncStatus(userId);
console.log('동기화 상태:', status);
// {
//   lastSyncTime: "2025-01-15T10:30:00.000Z",
//   maxSerial: 42,
//   localArchiveCount: 10,
//   localMessageCount: 150
// }
```

### DB 통계 조회

```typescript
import localDbService from './services/localDbService';

const stats = await localDbService.getDatabaseStats();
console.log('DB 통계:', stats);
// {
//   archiveCount: 10,
//   messageCount: 150,
//   totalSize: 5242880  // bytes (약 5MB)
// }
```

## ⚠️ 주의사항

### 1. 브라우저 호환성

- **Chrome/Edge**: ✅ 완벽 지원
- **Firefox**: ✅ 완벽 지원
- **Safari**: ✅ 지원 (일부 제한)
- **IE**: ❌ 지원 안 함

### 2. 용량 제한

- Chrome/Edge: ~50MB (요청 시 더 늘릴 수 있음)
- Firefox: ~50MB
- Safari: ~50MB
- 용량 초과 시 자동으로 오래된 데이터 삭제 로직 필요

### 3. 프라이빗 브라우징 모드

- IndexedDB가 제한되거나 작동하지 않을 수 있음
- 세션 종료 시 데이터 삭제됨

### 4. 동기화 주기

- 현재: 로그인 시 + 로컬 DB 비어있을 때만
- 향후: 백그라운드 주기적 동기화 추가 고려

## 🔄 Flutter 앱과의 차이점

| 기능 | Flutter | React |
|-----|---------|-------|
| **로컬 DB** | SQLite | IndexedDB |
| **동기화** | 백그라운드 서비스 | 프론트엔드에서 처리 |
| **용량** | 무제한 | 브라우저별 제한 (~50MB) |
| **오프라인** | 완전 지원 | 브라우저 캐시 의존 |
| **백그라운드 동기화** | ✅ 지원 | ⚠️ Service Worker 필요 |

## 📝 향후 개선 사항

1. **Service Worker 통합**
   - 백그라운드 동기화 지원
   - 오프라인 모드 개선

2. **캐시 관리**
   - 오래된 데이터 자동 삭제
   - 용량 제한 대응

3. **동기화 전략**
   - 백그라운드 주기적 동기화
   - 웹소켓 기반 실시간 동기화

4. **성능 최적화**
   - 가상 스크롤링 (대화 내역이 많을 때)
   - 청크 로딩 (메시지 페이지네이션)

## 🐛 문제 해결

### 로컬 DB가 비어있을 때

```typescript
// 강제 전체 동기화
import syncService from './services/syncService';
await syncService.forceFullSync(userId);
```

### 동기화 오류 발생 시

```typescript
// 로컬 DB 초기화 후 재동기화
import localDbService from './services/localDbService';
import syncService from './services/syncService';

await localDbService.clearAllData();
await syncService.syncArchivesWithDetails(userId);
```

### IndexedDB 지원 확인

```typescript
if (!window.indexedDB) {
  console.error('브라우저가 IndexedDB를 지원하지 않습니다.');
  // fallback: 서버 API만 사용
}
```

## 📚 참고 자료

- [Dexie.js 공식 문서](https://dexie.org/)
- [IndexedDB API (MDN)](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API)
- [Flutter DatabaseHelper 구현](../lib/core/database/database_helper.dart)

---

**구현 완료!** 이제 React 웹앱도 Flutter 앱처럼 로컬 DB를 사용하여 서버 부하를 줄이고 오프라인 지원을 제공합니다. 🎉
