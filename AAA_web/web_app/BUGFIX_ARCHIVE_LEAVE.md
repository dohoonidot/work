# 버그 수정: 기본 아카이브 중복 및 휴가 관리 페이지 에러

## 개요
두 가지 중요한 버그를 수정했습니다:
1. **기본 아카이브 중복 생성 문제** - 하나씩만 존재하도록 수정
2. **휴가 관리 페이지 React 에러** - 로딩/에러 처리 추가

---

## 1. 기본 아카이브 중복 생성 문제

### 문제 상황
- **기본 아카이브**: 사내업무, 코딩어시스턴트, SAP 어시스턴트, AI Chatbot
- **증상**: 같은 타입의 아카이브가 여러 개 생성됨
- **원인**: `handleCreateArchive` 함수에서 기존 아카이브 존재 여부를 확인하지 않고 무조건 새로 생성

### Flutter 앱 동작
Flutter 앱에서는 기본 아카이브가 **단 하나씩만** 존재:
- 사내업무 (`archive_type: ''`): 1개
- 코딩어시스턴트 (`archive_type: 'code'`): 1개
- SAP 어시스턴트 (`archive_type: 'sap'`): 1개
- AI Chatbot (`archive_type: ''`): 1개

### 해결 방법

**파일**: `web_app/src/pages/ChatPage.tsx`

#### Before (문제 코드):
```typescript
const handleCreateArchive = async (archiveType: string = '') => {
  const currentUser = authService.getCurrentUser();
  if (!currentUser) return;

  try {
    // 무조건 새 아카이브 생성
    const response = await chatService.createArchive(currentUser.userId, archiveType);
    const newArchive = response.archive;
    // ...
  }
}
```

#### After (수정 코드):
```typescript
const handleCreateArchive = async (archiveType: string = '') => {
  const currentUser = authService.getCurrentUser();
  if (!currentUser) return;

  try {
    // ✅ 기본 아카이브 타입인 경우, 이미 존재하는지 확인
    if (archiveType === 'code' || archiveType === 'sap' || archiveType === '') {
      const existingArchive = archives.find(archive => {
        if (archiveType === 'code') {
          return archive.archive_type === 'code' || archive.archive_name === ARCHIVE_NAMES.CODE;
        } else if (archiveType === 'sap') {
          return archive.archive_type === 'sap' || archive.archive_name === ARCHIVE_NAMES.SAP;
        } else if (archiveType === '') {
          // 사내업무 또는 AI Chatbot 체크
          return archive.archive_name === ARCHIVE_NAMES.WORK ||
                 archive.archive_name === ARCHIVE_NAMES.CHATBOT;
        }
        return false;
      });

      // ✅ 이미 존재하면 기존 아카이브 선택
      if (existingArchive) {
        console.log('이미 존재하는 기본 아카이브:', existingArchive.archive_name);
        selectArchive(existingArchive);
        return; // 생성하지 않고 종료
      }
    }

    // ✅ 존재하지 않을 때만 새로 생성
    const response = await chatService.createArchive(currentUser.userId, archiveType);
    const newArchive = response.archive;
    // ...
  }
}
```

### 개선 사항

#### 1. 중복 방지 로직
```typescript
// 아카이브 타입별 체크
if (archiveType === 'code') {
  // archive_type이 'code'이거나 archive_name이 '코딩어시스턴트'인 아카이브 찾기
  return archive.archive_type === 'code' || archive.archive_name === '코딩어시스턴트';
}
```

#### 2. 기존 아카이브 재사용
```typescript
if (existingArchive) {
  console.log('이미 존재하는 기본 아카이브:', existingArchive.archive_name);
  selectArchive(existingArchive); // 기존 것 선택
  return; // 함수 종료
}
```

#### 3. 아카이브 이름 매칭
```typescript
export const ARCHIVE_NAMES = {
  WORK: '사내업무',
  CODE: '코딩어시스턴트',
  SAP: 'SAP어시스턴트',
  CHATBOT: 'AI Chatbot',
} as const;
```

---

## 2. 휴가 관리 페이지 React 에러

### 문제 상황
**에러 메시지**:
```
An error occurred in the <LeaveManagementPage> component.
Consider adding an error boundary to your tree to customize error handling behavior.
```

### 원인 분석
1. **데스크톱 UI 조건부 렌더링 문제**:
   - `if (!isMobile && leaveData && !loading && !error)` 조건 사용
   - 로딩 중이거나 에러 발생 시 아무것도 렌더링하지 않음
   - React가 undefined를 반환하면 에러 발생

2. **누락된 케이스**:
   - 로딩 중 상태 처리 없음
   - 에러 상태 처리 없음
   - 데이터가 없는 상태 처리 없음

### 해결 방법

**파일**: `web_app/src/pages/LeaveManagementPage.tsx`

#### Before (문제 코드):
```typescript
// 데스크톱 UI (Flutter와 동일)
if (!isMobile && leaveData && !loading && !error) {
  return <DesktopLeaveManagement leaveData={leaveData} onRefresh={loadLeaveData} />;
}

// 모바일 UI (기존 코드)
return (
  <MobileMainLayout>
    {/* ... */}
  </MobileMainLayout>
);
```

**문제점**:
- 데스크톱 모드에서 로딩/에러 상태일 때 아무것도 반환하지 않음
- React는 컴포넌트가 항상 JSX를 반환해야 함

#### After (수정 코드):
```typescript
// 데스크톱 UI (Flutter와 동일)
if (!isMobile) {
  // ✅ 1. 로딩 중 처리
  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
        <CircularProgress />
      </Box>
    );
  }

  // ✅ 2. 에러 발생 처리
  if (error) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh', p: 3 }}>
        <Alert severity="error" sx={{ maxWidth: 600 }}>
          {error}
          <Button onClick={loadLeaveData} sx={{ mt: 2 }}>
            다시 시도
          </Button>
        </Alert>
      </Box>
    );
  }

  // ✅ 3. 데이터가 있을 때만 UI 렌더링
  if (leaveData) {
    return <DesktopLeaveManagement leaveData={leaveData} onRefresh={loadLeaveData} />;
  }

  // ✅ 4. 데이터가 없는 경우 처리
  return (
    <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
      <Typography>휴가 관리 데이터를 불러오는 중...</Typography>
    </Box>
  );
}

// 모바일 UI (기존 코드)
return (
  <MobileMainLayout>
    {/* ... */}
  </MobileMainLayout>
);
```

### 개선 사항

#### 1. 완전한 상태 처리
```typescript
// 모든 가능한 상태를 처리
- loading: true → CircularProgress 표시
- error: 있음 → Alert + 재시도 버튼
- leaveData: 있음 → DesktopLeaveManagement 렌더링
- 기타: 로딩 메시지 표시
```

#### 2. 사용자 경험 개선
```typescript
// 에러 발생 시 재시도 기능 제공
<Button onClick={loadLeaveData} sx={{ mt: 2 }}>
  다시 시도
</Button>
```

#### 3. 명확한 피드백
```typescript
// 각 상태에 맞는 UI 표시
- 로딩: CircularProgress (스피너)
- 에러: Alert (빨간색 경고)
- 데이터 없음: 안내 메시지
```

---

## 3. 초기화(Reset) 기능

### Flutter와 동일한 동작
기본 아카이브는 **삭제 불가**, **초기화만 가능**:
1. 기존 아카이브 삭제
2. 동일한 타입의 새 아카이브 생성
3. 아카이브 이름 설정

**구현 위치**: `chatService.ts`
```typescript
async resetArchive(
  userId: string,
  archiveId: string,
  archiveType: string,
  archiveName: string
): Promise<string> {
  // 1. 기존 아카이브 삭제
  await this.deleteArchive(archiveId);

  // 2. 동일한 타입의 새 아카이브 생성
  const response = await this.createArchive(userId, '', archiveType);
  const newArchiveId = response.archive.archive_id;

  // 3. 기본 아카이브인 경우 제목 변경
  if (archiveType === '' && archiveName === '사내업무') {
    await this.updateArchive(userId, newArchiveId, '사내업무');
  } else if (archiveType === '' && archiveName === 'AI Chatbot') {
    await this.updateArchive(userId, newArchiveId, 'AI Chatbot');
  }

  return newArchiveId;
}
```

---

## 4. 테스트 방법

### 4.1 기본 아카이브 중복 방지 테스트
```bash
cd web_app
npm run dev
```

**테스트 시나리오**:
1. 로그인
2. 채팅 페이지 접속
3. "코딩어시스턴트" 버튼 여러 번 클릭
4. ✅ 확인: 코딩어시스턴트 아카이브가 **1개만** 존재
5. "SAP 어시스턴트" 버튼 여러 번 클릭
6. ✅ 확인: SAP 어시스턴트 아카이브가 **1개만** 존재

**콘솔 로그**:
```
이미 존재하는 기본 아카이브: 코딩어시스턴트
```

### 4.2 휴가 관리 페이지 에러 수정 테스트
```bash
# 브라우저에서:
1. /leave 페이지 접속
2. ✅ 확인: 로딩 스피너 표시
3. ✅ 확인: 데이터 로드 후 정상 표시
4. ✅ 확인: 에러 없음 (콘솔 체크)
```

**데스크톱 모드 (≥900px)**:
- 로딩: CircularProgress 표시
- 에러: Alert + 재시도 버튼
- 성공: DesktopLeaveManagement 표시

**모바일 모드 (<900px)**:
- 기존 모바일 UI 정상 동작

---

## 5. 파일 변경 사항 요약

### 수정된 파일

1. **`web_app/src/pages/ChatPage.tsx`**
   - `handleCreateArchive` 함수에 중복 체크 로직 추가
   - 기본 아카이브가 이미 존재하면 새로 생성하지 않고 기존 것 선택

2. **`web_app/src/pages/LeaveManagementPage.tsx`**
   - 데스크톱 UI 렌더링 시 모든 상태 처리 추가
   - 로딩/에러/데이터 없음 케이스 처리

### 새로 생성된 파일
- **`web_app/BUGFIX_ARCHIVE_LEAVE.md`** (이 문서)

---

## 6. 기본 아카이브 정책

### 기본 아카이브 목록
| 아카이브 이름 | archive_type | 개수 | 삭제 가능 | 초기화 가능 |
|--------------|-------------|------|---------|----------|
| 사내업무 | `''` | 1개 | ❌ | ✅ |
| 코딩어시스턴트 | `'code'` | 1개 | ❌ | ✅ |
| SAP 어시스턴트 | `'sap'` | 1개 | ❌ | ✅ |
| AI Chatbot | `''` | 1개 | ❌ | ✅ |

### 정책
1. **생성**: 각 타입당 최대 1개만 존재
2. **삭제**: 기본 아카이브는 삭제 불가
3. **초기화**: `resetArchive` 함수로 내용만 리셋
4. **이름 변경**: 불가 (고정된 이름 사용)

---

## 7. 주요 개선 사항

### ✅ 기본 아카이브 중복 방지
- 중복 체크 로직 추가로 Flutter 앱과 동일한 동작
- 기존 아카이브 재사용으로 데이터 일관성 유지

### ✅ 휴가 관리 페이지 안정성
- 모든 상태에 대한 완전한 처리
- 에러 발생 시 사용자에게 명확한 피드백
- 재시도 기능 제공

### ✅ 사용자 경험 개선
- 불필요한 중복 아카이브 방지
- 에러 발생 시 복구 가능
- 명확한 로딩 상태 표시

---

## 결론

✅ **완료된 작업**:
1. 기본 아카이브 중복 생성 문제 해결 (하나씩만 존재)
2. 휴가 관리 페이지 React 에러 수정 (완전한 상태 처리)

**결과**:
- Flutter Windows 앱과 동일한 아카이브 관리
- 안정적인 휴가 관리 페이지 동작
- 향상된 사용자 경험
