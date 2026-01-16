# 아카이브 관리 기능 테스트 가이드

## 개요
이 문서는 아카이브 삭제/초기화/이름변경 기능의 모든 버그 수정을 검증하기 위한 테스트 가이드입니다.

---

## 수정된 버그 목록

### 1. ✅ 메뉴 아이콘 호버링 문제
- **문제**: 사이드바 아이템에 마우스를 올려도 메뉴 아이콘(⋮)이 표시되지 않음
- **수정**: IconButton을 ListItemButton 밖으로 이동하고 absolute positioning 적용
- **파일**: `src/components/chat/ChatSidebar.tsx`

### 2. ✅ 삭제/초기화/이름변경 기능 미작동
- **문제**: 다이얼로그는 열리지만 확인 버튼을 눌러도 아무 동작 안 함
- **원인**: `handleMenuClose()`가 `setSelectedArchive(null)`을 호출해 아카이브 참조 손실
- **수정**: 메뉴 닫기 전에 아카이브 참조를 임시 변수에 저장
- **파일**: `src/pages/ChatPage.tsx`

### 3. ✅ Aria-hidden 포커스 충돌 에러
- **에러**: `Blocked aria-hidden on an element because its descendant retained focus`
- **원인**: 메뉴 버튼이 포커스를 유지한 채로 Dialog가 열림
- **수정**:
  - `document.activeElement.blur()` 추가
  - `disableEnforceFocus` 속성 추가
  - setTimeout을 300ms로 증가
- **파일**: `src/pages/ChatPage.tsx`

### 4. ✅ 초기화 후 아카이브 자동 선택 안 됨
- **문제**: 초기화 후 수동으로 새 아카이브를 선택해야 함
- **원인**: Flutter의 `selectTopic(newArchiveId)` 로직 누락
- **수정**: `handleResetConfirm`에서 새 아카이브 자동 선택 로직 추가
- **파일**: `src/pages/ChatPage.tsx`

### 5. ✅ 초기화 후 잘못된 아카이브 이름
- **문제**: 초기화된 아카이브의 이름이 빈 문자열이거나 잘못된 이름
- **원인**: Flutter는 archiveType에 따라 적절한 타이틀 설정, 웹은 빈 문자열로 생성
- **수정**: `resetArchive` 함수에서 archiveType 기반 타이틀 설정 로직 추가
- **파일**: `src/services/chatService.ts`

---

## 테스트 환경 설정

### 1. 개발 서버 실행
```bash
cd web_app
npm run dev
```

### 2. 브라우저 개발자 도구 열기
- **Chrome/Edge**: F12 또는 Ctrl+Shift+I
- **Console 탭** 열기 (로그 확인용)

### 3. 테스트 계정으로 로그인
- 로그인 페이지에서 유효한 계정으로 로그인

---

## 테스트 시나리오

### 테스트 1: 메뉴 아이콘 호버링

**목적**: 사이드바 아이템에 마우스를 올렸을 때 메뉴 아이콘이 표시되는지 확인

**단계**:
1. 채팅 페이지 사이드바에서 아카이브 목록 확인
2. 각 아카이브 아이템에 마우스를 올림

**예상 결과**:
- ✅ 마우스를 올리면 오른쪽에 메뉴 아이콘(⋮) 표시됨
- ✅ 마우스를 내리면 메뉴 아이콘이 사라짐
- ✅ 현재 선택된 아카이브는 항상 메뉴 아이콘 표시
- ✅ 메뉴 아이콘에 부드러운 fade-in/out 애니메이션

**실패 케이스**:
- ❌ 메뉴 아이콘이 아예 표시되지 않음
- ❌ 애니메이션 없이 갑자기 나타남/사라짐

---

### 테스트 2: 커스텀 아카이브 삭제

**목적**: 커스텀 아카이브 삭제 기능이 정상 작동하는지 확인

**전제 조건**: 커스텀 아카이브(기본 아카이브가 아닌 것) 1개 이상 존재

**단계**:
1. 커스텀 아카이브 아이템에 마우스 올림
2. 메뉴 아이콘(⋮) 클릭
3. "삭제" 옵션 클릭
4. 삭제 확인 다이얼로그에서 "삭제" 버튼 클릭

**예상 결과**:
- ✅ 메뉴가 올바르게 열림
- ✅ "삭제" 옵션 표시됨
- ✅ 삭제 확인 다이얼로그가 열림
- ✅ "삭제" 버튼 클릭 시 아카이브가 목록에서 사라짐
- ✅ "아카이브가 삭제되었습니다." 스낵바 표시
- ✅ **Console에 aria-hidden 에러 없음**

**Console 로그 예시**:
```
handleMenuOpen 호출됨: {archive_id: "...", archive_name: "..."}
handleDeleteClick 호출됨, selectedArchive: {...}
isDefault: false
삭제 다이얼로그 열기
handleDeleteConfirm 호출됨, selectedArchive: {...}
아카이브 삭제 시작: ...
아카이브 삭제 완료, 목록 새로고침
```

**실패 케이스**:
- ❌ "삭제" 버튼을 눌러도 아무 일도 일어나지 않음
- ❌ Console에 `Blocked aria-hidden` 에러 표시
- ❌ 삭제 후 목록이 새로고침되지 않음

---

### 테스트 3: 기본 아카이브 초기화 (사내업무)

**목적**: 기본 아카이브 초기화 기능이 Flutter와 동일하게 작동하는지 확인

**대상 아카이브**: "사내업무" (archive_type: '')

**단계**:
1. "사내업무" 아카이브에 몇 개의 메시지 전송 (대화 내용 생성)
2. "사내업무" 아카이브 아이템에 마우스 올림
3. 메뉴 아이콘(⋮) 클릭
4. "초기화" 옵션 클릭
5. 초기화 확인 다이얼로그에서 "초기화" 버튼 클릭

**예상 결과**:
- ✅ "초기화" 옵션 표시 (삭제가 아님)
- ✅ 초기화 확인 다이얼로그 열림
- ✅ "초기화" 버튼 클릭 시:
  - 기존 대화 내용이 모두 사라짐
  - 아카이브 이름은 "사내업무"로 유지
  - **새로 생성된 아카이브가 자동으로 선택됨**
- ✅ "대화 내용이 초기화되었습니다." 스낵바 표시
- ✅ **Console에 aria-hidden 에러 없음**

**Console 로그 예시**:
```
handleDeleteClick 호출됨, selectedArchive: {archive_name: "사내업무", ...}
isDefault: true
초기화 다이얼로그 열기
handleResetConfirm 호출됨
🔄 아카이브 초기화 시작: {userId: "...", archiveId: "...", archiveType: "", archiveName: "사내업무"}
1️⃣ 기존 아카이브 삭제 중...
✅ 아카이브 삭제 완료
2️⃣ 새 아카이브 생성 중... {archiveType: "", newTitle: ""}
✅ 새 아카이브 생성 완료: ...
3️⃣ 아카이브 이름을 "사내업무"로 변경 중...
✅ 이름 변경 완료
🎉 아카이브 초기화 완료: ... -> ...
새로 생성된 아카이브 선택: {archive_id: "...", archive_name: "사내업무"}
```

**실패 케이스**:
- ❌ "삭제" 옵션이 표시됨 (초기화여야 함)
- ❌ 초기화 후 아카이브 이름이 빈 문자열로 변경됨
- ❌ 초기화 후 수동으로 아카이브를 선택해야 함
- ❌ Console에 `Blocked aria-hidden` 에러 표시
- ❌ Console에 emoji 로그(🔄, 1️⃣, 2️⃣, 3️⃣, 🎉)가 표시되지 않음

---

### 테스트 4: 기본 아카이브 초기화 (코딩어시스턴트)

**목적**: archiveType='code'인 기본 아카이브 초기화 검증

**대상 아카이브**: "코딩어시스턴트" (archive_type: 'code')

**단계**:
1. 사이드바에서 "코딩어시스턴트" 버튼 클릭 (아카이브 생성)
2. 몇 개의 메시지 전송
3. 메뉴 아이콘(⋮) 클릭 → "초기화" 클릭
4. 초기화 확인 다이얼로그에서 "초기화" 버튼 클릭

**예상 결과**:
- ✅ 초기화 후 아카이브 이름이 "코딩어시스턴트"로 유지
- ✅ archive_type이 'code'로 유지
- ✅ 대화 내용만 초기화됨
- ✅ 새 아카이브가 자동으로 선택됨

**Console 로그 확인**:
```
2️⃣ 새 아카이브 생성 중... {archiveType: "code", newTitle: "코딩어시스턴트"}
✅ 새 아카이브 생성 완료: ...
🎉 아카이브 초기화 완료: ... -> ...
```

**주의**: archiveType='code'인 경우 3️⃣ 단계(이름 변경)가 실행되지 않음 (생성 시 이미 올바른 이름 설정됨)

---

### 테스트 5: 기본 아카이브 초기화 (SAP어시스턴트)

**목적**: archiveType='sap'인 기본 아카이브 초기화 검증

**대상 아카이브**: "SAP어시스턴트" (archive_type: 'sap')

**단계**:
1. 사이드바에서 "SAP 어시스턴트" 버튼 클릭
2. 몇 개의 메시지 전송
3. 메뉴 아이콘(⋮) 클릭 → "초기화" 클릭
4. 초기화 확인

**예상 결과**:
- ✅ 초기화 후 아카이브 이름이 "SAP어시스턴트"로 유지
- ✅ archive_type이 'sap'로 유지

**Console 로그 확인**:
```
2️⃣ 새 아카이브 생성 중... {archiveType: "sap", newTitle: "SAP어시스턴트"}
```

---

### 테스트 6: 기본 아카이브 초기화 (AI Chatbot)

**목적**: archiveType=''이면서 archiveName='AI Chatbot'인 아카이브 초기화 검증

**대상 아카이브**: "AI Chatbot" (archive_type: '')

**단계**:
1. "AI Chatbot" 아카이브 선택
2. 몇 개의 메시지 전송
3. 메뉴 아이콘(⋮) 클릭 → "초기화" 클릭
4. 초기화 확인

**예상 결과**:
- ✅ 초기화 후 아카이브 이름이 "AI Chatbot"으로 유지
- ✅ archive_type이 ''로 유지

**Console 로그 확인**:
```
2️⃣ 새 아카이브 생성 중... {archiveType: "", newTitle: ""}
3️⃣ 아카이브 이름을 "AI Chatbot"으로 변경 중...
✅ 이름 변경 완료
```

---

### 테스트 7: 커스텀 아카이브 이름 변경

**목적**: 커스텀 아카이브 이름 변경 기능 검증

**전제 조건**: 커스텀 아카이브 1개 이상 존재

**단계**:
1. 커스텀 아카이브 메뉴(⋮) 클릭
2. "이름 변경" 옵션 클릭
3. 새 이름 입력 (예: "테스트 프로젝트")
4. "확인" 버튼 클릭

**예상 결과**:
- ✅ 이름 변경 다이얼로그 열림
- ✅ 현재 이름이 입력 필드에 표시됨
- ✅ 새 이름 입력 후 확인하면 아카이브 이름 변경됨
- ✅ "아카이브 이름이 변경되었습니다." 스낵바 표시
- ✅ **Console에 aria-hidden 에러 없음**

**Console 로그 예시**:
```
handleRenameClick 호출됨, selectedArchive: {...}
이름 변경 다이얼로그 열림
handleRenameSubmit 호출됨, selectedArchive: {...}, newName: "테스트 프로젝트"
```

---

### 테스트 8: 기본 아카이브 이름 변경 제한

**목적**: 기본 아카이브 이름을 다른 기본 이름으로 변경하지 못하도록 방지

**단계**:
1. 커스텀 아카이브 메뉴 → "이름 변경" 클릭
2. 다음 이름 중 하나를 입력:
   - "사내업무"
   - "코딩어시스턴트"
   - "SAP어시스턴트"
   - "AI Chatbot"
3. "확인" 버튼 클릭

**예상 결과**:
- ✅ 에러 스낵바 표시: `"[입력한 이름]"는 기본 아카이브 이름으로 사용할 수 없습니다.`
- ✅ 이름 변경되지 않음
- ✅ 다이얼로그가 닫히지 않음

**Console 로그**:
```
제한된 이름 사용 시도: 사내업무
```

---

### 테스트 9: 연속 작업 테스트

**목적**: 여러 작업을 연속으로 수행해도 에러가 발생하지 않는지 확인

**단계**:
1. 아카이브 A 이름 변경
2. 즉시 아카이브 B 초기화
3. 즉시 아카이브 C 삭제
4. 즉시 아카이브 D 이름 변경

**예상 결과**:
- ✅ 모든 작업이 순서대로 정상 실행됨
- ✅ 각 다이얼로그가 올바르게 열리고 닫힘
- ✅ Console에 에러 없음
- ✅ UI가 정상적으로 업데이트됨

---

### 테스트 10: 포커스 및 Aria-hidden 검증

**목적**: 모든 다이얼로그 오픈 시 aria-hidden 에러가 발생하지 않는지 확인

**단계**:
1. Chrome DevTools Console 열기
2. 다음 각 작업 수행:
   - 삭제 다이얼로그 열기
   - 초기화 다이얼로그 열기
   - 이름 변경 다이얼로그 열기

**예상 결과**:
- ✅ Console에 다음 에러가 **절대 표시되지 않음**:
  ```
  Blocked aria-hidden on an element because its descendant retained focus
  ```
- ✅ 모든 다이얼로그가 부드럽게 열림 (300ms 딜레이 후)
- ✅ 다이얼로그 열릴 때 배경이 흐려짐 (backdrop)

---

## 체크리스트

### 시각적 검증
- [ ] 메뉴 아이콘이 호버링 시 표시됨
- [ ] 메뉴 아이콘 fade-in/out 애니메이션 동작
- [ ] 다이얼로그가 부드럽게 열리고 닫힘
- [ ] 스낵바 메시지가 올바르게 표시됨
- [ ] 아카이브 목록이 즉시 업데이트됨

### 기능 검증
- [ ] 커스텀 아카이브 삭제 성공
- [ ] 사내업무 초기화 성공 (이름 유지)
- [ ] 코딩어시스턴트 초기화 성공 (이름 유지)
- [ ] SAP어시스턴트 초기화 성공 (이름 유지)
- [ ] AI Chatbot 초기화 성공 (이름 유지)
- [ ] 커스텀 아카이브 이름 변경 성공
- [ ] 기본 아카이브 이름으로 변경 시 에러 표시
- [ ] 초기화 후 새 아카이브 자동 선택

### Console 로그 검증
- [ ] handleMenuOpen 로그 표시
- [ ] handleDeleteClick/handleRenameClick 로그 표시
- [ ] emoji 로그(🔄, 1️⃣, 2️⃣, 3️⃣, 🎉) 표시
- [ ] **aria-hidden 에러 없음**
- [ ] API 호출 성공 로그 표시

### 에러 케이스 검증
- [ ] 메뉴 버튼 클릭 시 아카이브 선택되지 않음 (stopPropagation)
- [ ] 다이얼로그 열릴 때 포커스 에러 없음
- [ ] 빠른 연속 작업 시 에러 없음
- [ ] 네트워크 에러 시 스낵바로 피드백 표시

---

## 주요 개선 사항 요약

### 1. 이벤트 전파 제어
```typescript
onClick={(e) => {
  e.stopPropagation();  // 부모 클릭 이벤트 방지
  handleMenuOpen(e, archive);
}}
```

### 2. 상태 보존
```typescript
const archiveToProcess = selectedArchive;  // 참조 저장
setAnchorEl(null);  // 메뉴만 닫기
setTimeout(() => {
  setSelectedArchive(archiveToProcess);  // 복원
  setDialogOpen(true);
}, 300);
```

### 3. 포커스 관리
```typescript
if (document.activeElement instanceof HTMLElement) {
  document.activeElement.blur();  // 포커스 제거
}
```

### 4. Flutter 로직 일치
```typescript
// 1. 삭제
await deleteArchive(archiveId);

// 2. 생성 (archiveType에 따라 적절한 타이틀 설정)
const response = await createArchive(userId, newTitle, archiveType);

// 3. 필요시 이름 변경 (archiveType='' && 사내업무/AI Chatbot)
if (archiveType === '' && archiveName === '사내업무') {
  await updateArchive(userId, newArchiveId, '사내업무');
}

// 4. 자동 선택 (Flutter의 selectTopic)
selectArchive(newArchive);
```

---

## 버그 수정 전/후 비교

### Before (문제 상황)
- ❌ 메뉴 아이콘이 보이지 않음
- ❌ 삭제/초기화/이름변경 버튼을 눌러도 아무 일도 일어나지 않음
- ❌ Console에 aria-hidden 에러 표시
- ❌ 초기화 후 아카이브 이름이 빈 문자열로 변경됨
- ❌ 초기화 후 수동으로 아카이브 선택해야 함

### After (수정 후)
- ✅ 메뉴 아이콘이 호버링 시 부드럽게 표시됨
- ✅ 모든 아카이브 관리 기능 정상 작동
- ✅ Console에 aria-hidden 에러 없음
- ✅ 초기화 후 아카이브 이름 올바르게 유지
- ✅ 초기화 후 새 아카이브 자동 선택
- ✅ Flutter 앱과 동일한 동작

---

## 문제 발생 시 디버깅

### Console에 로그가 전혀 표시되지 않는 경우
1. 브라우저 새로고침 (Ctrl+F5)
2. 로그인 다시 시도
3. 캐시 삭제 후 재시작

### 다이얼로그가 열리지 않는 경우
1. Console에서 `handleDeleteClick` 또는 `handleRenameClick` 로그 확인
2. `selectedArchive` 값이 null인지 확인
3. setTimeout이 실행되고 있는지 확인

### aria-hidden 에러가 여전히 발생하는 경우
1. `document.activeElement.blur()` 코드가 실행되는지 확인
2. setTimeout 딜레이가 300ms인지 확인
3. Dialog에 `disableEnforceFocus` 속성이 있는지 확인

### 초기화 후 이름이 잘못된 경우
1. Console에서 🔄, 1️⃣, 2️⃣, 3️⃣, 🎉 emoji 로그 확인
2. archiveType 값 확인
3. `chatService.ts` resetArchive 함수 로직 확인

---

## 관련 파일

- `web_app/src/components/chat/ChatSidebar.tsx` - 사이드바 UI 및 메뉴
- `web_app/src/pages/ChatPage.tsx` - 아카이브 관리 로직 및 다이얼로그
- `web_app/src/services/chatService.ts` - API 호출 (특히 resetArchive)
- `web_app/BUGFIX_ARCHIVE_LEAVE.md` - 버그 수정 상세 문서
- `web_app/ARCHIVE_MANAGEMENT_IMPLEMENTATION.md` - 초기 구현 문서

---

## 결론

모든 테스트를 통과하면 아카이브 관리 기능이 Flutter Windows 앱과 동일하게 작동하며, 다음이 보장됩니다:

1. ✅ 모든 UI 요소가 올바르게 표시됨
2. ✅ 삭제/초기화/이름변경 기능이 정상 작동함
3. ✅ 접근성 에러(aria-hidden)가 발생하지 않음
4. ✅ Flutter 앱과 동일한 사용자 경험 제공
5. ✅ 안정적이고 예측 가능한 동작

**테스트 완료 후 이 문서를 기록으로 보관하시기 바랍니다.**
