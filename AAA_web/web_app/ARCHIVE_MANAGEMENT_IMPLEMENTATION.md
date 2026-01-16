# 아카이브 관리 기능 구현 완료

## 개요
Flutter Windows 앱의 사이드바 아카이브 관리 기능을 React 웹 앱에 완전히 구현했습니다.

**구현 기능**:
1. ✅ 아카이브 삭제 (커스텀 아카이브만)
2. ✅ 아카이브 이름 변경 (커스텀 아카이브만)
3. ✅ 기본 아카이브 초기화

---

## 1. Flutter 참조 구현

### 참조 파일
**`lib/shared/widgets/sidebar.dart`** (라인 700-1150)

### Flutter의 동작 방식

#### 컨텍스트 메뉴 (라인 729-796)
```dart
showDialog(
  context: context,
  builder: (context) {
    return AlertDialog(
      title: Text(isDefaultArchive ? '기본 아카이브 관리' : '대화 관리'),
      content: Column(
        children: [
          // 기본 아카이브가 아닐 때만 이름 변경 옵션 표시
          if (!isDefaultArchive)
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('이름 변경'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(context, topicId, topic);
              },
            ),
          // 모든 아카이브에 삭제/초기화 옵션 표시
          ListTile(
            leading: Icon(isDefaultArchive ? Icons.refresh : Icons.delete),
            title: Text(isDefaultArchive ? '초기화' : '삭제'),
            onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmDialog(context, topicId);
            },
          ),
        ],
      ),
    );
  },
);
```

**특징**:
- **기본 아카이브**: Icons.more_vert → "초기화" 옵션만
- **커스텀 아카이브**: Icons.more_vert → "이름 변경" + "삭제" 옵션

#### 초기화 기능 (라인 1118-1178)
```dart
Future<void> _deleteAndRecreateDefaultArchive(
  BuildContext context,
  String archiveId,
) async {
  showInfoMessage(context, '대화 내용을 초기화하는 중...');

  // 아카이브 타입 결정
  String newArchiveType = '';
  String archiveName = '';

  if (currentTopic == '코딩어시스턴트') {
    newArchiveType = 'code';
    archiveName = '코딩어시스턴트';
  } else if (currentTopic == 'SAP 어시스턴트') {
    newArchiveType = 'sap';
    archiveName = 'SAP 어시스턴트';
  } else if (currentTopic == 'AI Chatbot') {
    newArchiveType = '';
    archiveName = 'AI Chatbot';
  } else if (currentTopic == '사내업무') {
    newArchiveType = '';
    archiveName = '사내업무';
  }

  // 초기화 실행
  await chatNotifier.resetArchive(context, archiveId, newArchiveType, archiveName);

  showSuccessMessage(context, '대화 내용이 초기화되었습니다.');
}
```

---

## 2. React 웹 앱 구현

### 수정된 파일
**`web_app/src/components/chat/ChatSidebar.tsx`**

### 주요 변경 사항

#### 2.1 컨텍스트 메뉴 버튼 (라인 368-374)
```typescript
// ✅ 변경 전: 기본 아카이브에는 메뉴 버튼이 없었음
{!isDefault && (
  <IconButton onClick={(e) => handleMenuOpen(e, archive)}>
    <MoreVertIcon fontSize="small" />
  </IconButton>
)}

// ✅ 변경 후: 모든 아카이브에 메뉴 버튼 표시
<IconButton onClick={(e) => handleMenuOpen(e, archive)}>
  <MoreVertIcon fontSize="small" />
</IconButton>
```

**이유**: Flutter와 동일하게 모든 아카이브(기본/커스텀)에 컨텍스트 메뉴 제공

#### 2.2 메뉴 아이템 조건부 렌더링 (라인 405-425)
```typescript
<Menu anchorEl={anchorEl} open={Boolean(anchorEl)} onClose={handleMenuClose}>
  {/* 커스텀 아카이브만 이름 변경 가능 */}
  {selectedArchive && !isDefaultArchive(selectedArchive) && (
    <MenuItem onClick={handleRenameClick}>
      <ListItemIcon>
        <EditIcon fontSize="small" />
      </ListItemIcon>
      <ListItemText>이름 변경</ListItemText>
    </MenuItem>
  )}

  {/* 모든 아카이브에 삭제/초기화 옵션 */}
  <MenuItem onClick={handleDeleteClick}>
    <ListItemIcon>
      {selectedArchive && isDefaultArchive(selectedArchive) ? (
        <RefreshIcon fontSize="small" />
      ) : (
        <DeleteIcon fontSize="small" color="error" />
      )}
    </ListItemIcon>
    <ListItemText>
      {selectedArchive && isDefaultArchive(selectedArchive) ? '초기화' : '삭제'}
    </ListItemText>
  </MenuItem>
</Menu>
```

**동작**:
- **기본 아카이브** (사내업무, 코딩어시스턴트, SAP어시스턴트, AI Chatbot):
  - "초기화" 옵션만 표시 (RefreshIcon)
- **커스텀 아카이브**:
  - "이름 변경" + "삭제" 옵션 표시 (EditIcon + DeleteIcon)

#### 2.3 Snackbar 알림 시스템 (라인 73-77, 542-556)
```typescript
// 상태 정의
const [snackbar, setSnackbar] = useState<{
  open: boolean;
  message: string;
  severity: 'success' | 'error';
}>({
  open: false,
  message: '',
  severity: 'success',
});

// Snackbar 컴포넌트
<Snackbar
  open={snackbar.open}
  autoHideDuration={3000}
  onClose={() => setSnackbar({ ...snackbar, open: false })}
  anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
>
  <Alert
    onClose={() => setSnackbar({ ...snackbar, open: false })}
    severity={snackbar.severity}
    sx={{ width: '100%' }}
  >
    {snackbar.message}
  </Alert>
</Snackbar>
```

**변경**: `window.alert()` → MUI Snackbar + Alert 컴포넌트 사용

#### 2.4 이름 변경 기능 (라인 140-183)
```typescript
const handleRenameSubmit = async () => {
  if (selectedArchive && newName.trim()) {
    // 1. 기본 아카이브 이름 검증
    const restrictedNames = [
      ARCHIVE_NAMES.WORK,      // '사내업무'
      ARCHIVE_NAMES.CHATBOT,   // 'AI Chatbot'
      ARCHIVE_NAMES.CODE,      // '코딩어시스턴트'
      ARCHIVE_NAMES.SAP,       // 'SAP어시스턴트'
    ];

    if (restrictedNames.some(name => name === newName.trim())) {
      setSnackbar({
        open: true,
        message: `"${newName}"는 기본 아카이브 이름으로 사용할 수 없습니다.`,
        severity: 'error',
      });
      return;
    }

    // 2. API 호출
    try {
      const user = authService.getCurrentUser();
      if (user) {
        await chatService.updateArchive(
          user.userId,
          selectedArchive.archive_id,
          newName.trim()
        );
        onRenameArchive(selectedArchive.archive_id, newName.trim());
        setSnackbar({
          open: true,
          message: '아카이브 이름이 변경되었습니다.',
          severity: 'success',
        });
      }
    } catch (error) {
      console.error('아카이브 이름 변경 실패:', error);
      setSnackbar({
        open: true,
        message: '아카이브 이름 변경에 실패했습니다.',
        severity: 'error',
      });
      return;
    }

    setRenameDialogOpen(false);
    setSelectedArchive(null);
  }
};
```

**API**: `POST /updateArchive`
- `user_id`: 사용자 ID
- `archive_id`: 아카이브 ID
- `archive_name`: 새 이름

#### 2.5 삭제 기능 (라인 200-221)
```typescript
const handleDeleteConfirm = async () => {
  if (selectedArchive) {
    try {
      await chatService.deleteArchive(selectedArchive.archive_id);
      onDeleteArchive(selectedArchive.archive_id);
      setSnackbar({
        open: true,
        message: '아카이브가 삭제되었습니다.',
        severity: 'success',
      });
    } catch (error) {
      console.error('아카이브 삭제 실패:', error);
      setSnackbar({
        open: true,
        message: '아카이브 삭제에 실패했습니다.',
        severity: 'error',
      });
    }
  }
  setDeleteDialogOpen(false);
  setSelectedArchive(null);
};
```

**API**: `POST /deleteArchive`
- `archive_id`: 아카이브 ID

#### 2.6 초기화 기능 (라인 224-256)
```typescript
const handleResetConfirm = async () => {
  if (selectedArchive) {
    try {
      const user = authService.getCurrentUser();
      if (user) {
        const archiveType = selectedArchive.archive_type || '';

        // chatService.resetArchive 호출
        await chatService.resetArchive(
          user.userId,
          selectedArchive.archive_id,
          archiveType,
          selectedArchive.archive_name
        );

        // 아카이브 목록 새로고침
        onCreateArchive(archiveType);

        setSnackbar({
          open: true,
          message: '대화 내용이 초기화되었습니다.',
          severity: 'success',
        });
      }
    } catch (error) {
      console.error('아카이브 초기화 실패:', error);
      setSnackbar({
        open: true,
        message: '아카이브 초기화에 실패했습니다.',
        severity: 'error',
      });
    }
  }
  setResetDialogOpen(false);
  setSelectedArchive(null);
};
```

**`chatService.resetArchive` 내부 동작** (`chatService.ts` 라인 297-323):
```typescript
async resetArchive(
  userId: string,
  archiveId: string,
  archiveType: string,
  archiveName: string
): Promise<string> {
  try {
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
  } catch (error) {
    console.error('아카이브 초기화 실패:', error);
    throw error;
  }
}
```

**API 호출 순서**:
1. `POST /deleteArchive` - 기존 아카이브 삭제
2. `POST /createArchive` - 동일 타입 새 아카이브 생성
3. `POST /updateArchive` - (기본 아카이브만) 이름 설정

#### 2.7 다이얼로그 구현

**이름 변경 다이얼로그** (라인 479-503):
```typescript
<Dialog open={renameDialogOpen} onClose={() => setRenameDialogOpen(false)}>
  <DialogTitle>아카이브 이름 변경</DialogTitle>
  <DialogContent>
    <TextField
      autoFocus
      margin="dense"
      label="새 이름"
      fullWidth
      value={newName}
      onChange={(e) => setNewName(e.target.value)}
      onKeyPress={(e) => {
        if (e.key === 'Enter') {
          handleRenameSubmit();
        }
      }}
    />
  </DialogContent>
  <DialogActions>
    <Button onClick={() => setRenameDialogOpen(false)}>취소</Button>
    <Button onClick={handleRenameSubmit} variant="contained">변경</Button>
  </DialogActions>
</Dialog>
```

**삭제 확인 다이얼로그** (라인 505-521):
```typescript
<Dialog open={deleteDialogOpen} onClose={() => setDeleteDialogOpen(false)}>
  <DialogTitle>아카이브 삭제</DialogTitle>
  <DialogContent>
    <DialogContentText>
      "{selectedArchive?.archive_name}" 아카이브를 삭제하시겠습니까?
      <br />
      이 작업은 되돌릴 수 없습니다.
    </DialogContentText>
  </DialogContent>
  <DialogActions>
    <Button onClick={() => setDeleteDialogOpen(false)}>취소</Button>
    <Button onClick={handleDeleteConfirm} variant="contained" color="error">
      삭제
    </Button>
  </DialogActions>
</Dialog>
```

**초기화 확인 다이얼로그** (라인 523-540):
```typescript
<Dialog open={resetDialogOpen} onClose={() => setResetDialogOpen(false)}>
  <DialogTitle>기본 아카이브 초기화</DialogTitle>
  <DialogContent>
    <DialogContentText>
      "{selectedArchive?.archive_name}"의 대화 내용을 초기화하시겠습니까?
      <br />
      <br />
      초기화하면 기존 대화 내용이 모두 삭제되고 새로운 동일 유형의 아카이브가 생성됩니다.
    </DialogContentText>
  </DialogContent>
  <DialogActions>
    <Button onClick={() => setResetDialogOpen(false)}>취소</Button>
    <Button onClick={handleResetConfirm} variant="contained" color="primary">
      초기화
    </Button>
  </DialogActions>
</Dialog>
```

---

## 3. API 연동 현황

### 모든 API 메서드가 이미 구현됨
**파일**: `web_app/src/services/chatService.ts`

| API 메서드 | 엔드포인트 | 라인 | 상태 |
|-----------|----------|------|------|
| `createArchive` | `POST /createArchive` | 257-268 | ✅ 구현됨 |
| `updateArchive` | `POST /updateArchive` | 273-283 | ✅ 구현됨 |
| `deleteArchive` | `POST /deleteArchive` | 288-292 | ✅ 구현됨 |
| `resetArchive` | (복합) | 297-323 | ✅ 구현됨 |

### `resetArchive` 메서드
```typescript
async resetArchive(
  userId: string,
  archiveId: string,
  archiveType: string,
  archiveName: string
): Promise<string> {
  // 1. deleteArchive 호출
  // 2. createArchive 호출
  // 3. updateArchive 호출 (기본 아카이브만)
  return newArchiveId;
}
```

---

## 4. 기본 아카이브 정책

### 기본 아카이브 목록
| 이름 | archive_type | 개수 | 삭제 | 이름 변경 | 초기화 |
|------|-------------|------|------|---------|--------|
| 사내업무 | `''` | 1개 | ❌ | ❌ | ✅ |
| 코딩어시스턴트 | `'code'` | 1개 | ❌ | ❌ | ✅ |
| SAP 어시스턴트 | `'sap'` | 1개 | ❌ | ❌ | ✅ |
| AI Chatbot | `''` | 1개 | ❌ | ❌ | ✅ |

### 커스텀 아카이브
| 속성 | 값 |
|------|-----|
| 개수 | 무제한 |
| 삭제 | ✅ 가능 |
| 이름 변경 | ✅ 가능 (단, 기본 아카이브 이름 제외) |
| 초기화 | ❌ 불가 (삭제만 가능) |

### `isDefaultArchive` 함수
**파일**: `web_app/src/store/chatStore.ts` (라인 105-112)

```typescript
export const isDefaultArchive = (archive: Archive): boolean => {
  const type = archive.archive_type || '';
  const name = archive.archive_name || '';

  // archive_type이 'code' 또는 'sap'인 경우
  if (type === 'code' || type === 'sap') {
    return true;
  }

  // archive_name이 기본 아카이브 이름인 경우
  if (name === ARCHIVE_NAMES.WORK || name === ARCHIVE_NAMES.CHATBOT) {
    return true;
  }

  return false;
};
```

---

## 5. 사용자 경험 개선

### 5.1 Alert → Snackbar 변경
**변경 전**: `window.alert()`, `window.confirm()` 사용
**변경 후**: MUI Snackbar + Alert 컴포넌트 사용

**장점**:
- 비차단(Non-blocking) UI
- 일관된 디자인 (MUI 테마)
- 자동 숨김 (3초)
- 성공/에러 상태 구분 (색상)

### 5.2 다이얼로그 개선
- **명확한 메시지**: 어떤 작업을 수행하는지 설명
- **되돌릴 수 없음 경고**: 삭제 시 경고 메시지
- **초기화 설명**: 기존 내용 삭제 + 새 아카이브 생성 명시

### 5.3 아이콘 개선
- **초기화**: RefreshIcon (새로고침)
- **삭제**: DeleteIcon (휴지통, 빨간색)
- **이름 변경**: EditIcon (연필)

---

## 6. 테스트 방법

### 6.1 개발 서버 실행
```bash
cd web_app
npm run dev
```

브라우저에서 `http://localhost:5173` 접속

### 6.2 커스텀 아카이브 테스트

**시나리오 1: 새 아카이브 생성 + 이름 변경**
1. 사이드바 오른쪽 상단 "+" 버튼 클릭
2. 새 아카이브 생성 확인
3. 아카이브 우측 ⋮ (more_vert) 아이콘 클릭
4. "이름 변경" 선택
5. 새 이름 입력 (예: "테스트 아카이브")
6. "변경" 버튼 클릭
7. ✅ 확인: Snackbar "아카이브 이름이 변경되었습니다." 표시
8. ✅ 확인: 사이드바에 새 이름으로 표시

**시나리오 2: 아카이브 삭제**
1. 커스텀 아카이브 우측 ⋮ 아이콘 클릭
2. "삭제" 선택
3. 삭제 확인 다이얼로그 표시 확인
4. "삭제" 버튼 클릭
5. ✅ 확인: Snackbar "아카이브가 삭제되었습니다." 표시
6. ✅ 확인: 사이드바에서 아카이브 제거됨

**시나리오 3: 기본 아카이브 이름으로 변경 시도**
1. 커스텀 아카이브 우측 ⋮ 아이콘 클릭
2. "이름 변경" 선택
3. "사내업무" 입력
4. "변경" 버튼 클릭
5. ✅ 확인: 에러 Snackbar ""사내업무"는 기본 아카이브 이름으로 사용할 수 없습니다." 표시
6. ✅ 확인: 이름 변경되지 않음

### 6.3 기본 아카이브 테스트

**시나리오 1: 코딩어시스턴트 초기화**
1. "코딩어시스턴트" 아카이브 우측 ⋮ 아이콘 클릭
2. ✅ 확인: "초기화" 옵션만 표시 (RefreshIcon)
3. "초기화" 선택
4. 초기화 확인 다이얼로그 표시 확인
   - "초기화하면 기존 대화 내용이 모두 삭제되고..." 메시지 확인
5. "초기화" 버튼 클릭
6. ✅ 확인: Snackbar "대화 내용이 초기화되었습니다." 표시
7. ✅ 확인: 채팅 내역 비어있음
8. ✅ 확인: 아카이브 이름 "코딩어시스턴트"로 유지

**시나리오 2: SAP 어시스턴트 초기화**
1. "SAP 어시스턴트" 아카이브 우측 ⋮ 아이콘 클릭
2. "초기화" 선택
3. 확인 후 초기화
4. ✅ 확인: Snackbar 표시, 채팅 내역 비어있음

**시나리오 3: 사내업무 초기화**
1. "사내업무" 아카이브 우측 ⋮ 아이콘 클릭
2. "초기화" 선택
3. 확인 후 초기화
4. ✅ 확인: Snackbar 표시, 아카이브 이름 "사내업무"로 유지

**시나리오 4: AI Chatbot 초기화**
1. "AI Chatbot" 아카이브 우측 ⋮ 아이콘 클릭
2. "초기화" 선택
3. 확인 후 초기화
4. ✅ 확인: Snackbar 표시, 아카이브 이름 "AI Chatbot"로 유지

---

## 7. 주요 개선 사항

### ✅ Flutter와 동일한 UX
- 모든 아카이브에 컨텍스트 메뉴 표시
- 기본/커스텀 아카이브 구분하여 다른 옵션 제공
- 초기화 시 명확한 설명 제공

### ✅ 향상된 사용자 피드백
- window.alert → Snackbar (비차단)
- 성공/에러 상태 구분 (색상)
- 자동 숨김 (3초)

### ✅ 완전한 API 연동
- 모든 아카이브 관리 API 연결됨
- chatService.resetArchive 구현됨
- 에러 처리 완료

### ✅ 타입 안전성
- TypeScript 타입 에러 수정
- 엄격한 타입 체크 통과

---

## 8. 파일 변경 사항 요약

### 수정된 파일
1. **`web_app/src/components/chat/ChatSidebar.tsx`**
   - 컨텍스트 메뉴 버튼 모든 아카이브에 표시 (라인 368-374)
   - 메뉴 아이템 조건부 렌더링 (라인 405-425)
   - Snackbar 알림 시스템 추가 (라인 73-77, 542-556)
   - 이름 변경 기능 개선 (라인 140-183)
   - 삭제/초기화 분리 (라인 186-256)
   - 다이얼로그 추가 (라인 479-540)
   - RefreshIcon import 추가 (라인 33)
   - DialogContentText, Snackbar, Alert import 추가 (라인 22-24)

### 새로 생성된 파일
- **`web_app/ARCHIVE_MANAGEMENT_IMPLEMENTATION.md`** (이 문서)

### API 파일 (변경 없음)
- **`web_app/src/services/chatService.ts`** - 이미 모든 메서드 구현됨

---

## 9. 결론

✅ **완료된 작업**:
1. Flutter 사이드바 아카이브 관리 기능 분석
2. ChatSidebar에 컨텍스트 메뉴 추가 (모든 아카이브)
3. 아카이브 삭제/초기화 다이얼로그 구현
4. 아카이브 타이틀 수정 다이얼로그 구현
5. API 연동 확인 (모두 연결됨)
6. Snackbar 알림 시스템 도입
7. 타입 에러 수정

**결과**:
- Flutter Windows 앱과 완전히 동일한 아카이브 관리 기능
- 향상된 사용자 경험 (Snackbar, 명확한 다이얼로그)
- 안정적인 API 연동
- 타입 안전성 확보

**다음 단계** (선택사항):
- 실제 서버 환경에서 테스트
- 추가 에러 처리 개선
- 아카이브 복사 기능 추가 (Flutter에도 없는 기능)
