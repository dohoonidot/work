# 휴가 취소 상신 API 연동 수정 완료

## 🐛 **문제점**

### **증상**
- APPROVED 상태 휴가의 "취소상신" 버튼 클릭 시 **즉시 취소**됨
- 관리자 승인 없이 바로 취소 처리

### **원인**
`DesktopLeaveManagement.tsx`의 `handleCancelRequest` 함수에서 잘못된 API 호출:

```typescript
// ❌ 잘못된 코드 (즉시 취소 API)
const response = await leaveService.cancelLeaveRequestNew(cancelRequest);
```

- **`cancelLeaveRequestNew`**: `/leave/user/cancel` API 호출 → **즉시 취소**
- **취소 사유 입력 없음**
- **관리자 승인 불필요**

---

## ✅ **수정 내용**

### **1. 올바른 컴포넌트 사용**

기존에 이미 구현되어 있던 `LeaveCancelRequestDialog` 컴포넌트를 활용:

```typescript
// ✅ 올바른 코드 (취소 상신 API)
import LeaveCancelRequestDialog from './LeaveCancelRequestDialog';

<LeaveCancelRequestDialog
  open={cancelRequestModalOpen}
  onClose={() => {
    setCancelRequestModalOpen(false);
    setCancelRequestLeave(null);
  }}
  onSuccess={handleCancelSuccess}
  leave={cancelRequestLeave}
  userId={user?.userId || ''}
/>
```

### **2. API 호출 변경**

| 구분 | 기존 (잘못됨) | 수정 후 (올바름) |
|------|--------------|-----------------|
| **API 엔드포인트** | `/leave/user/cancel` | `/leave/user/cancel/request` |
| **API 함수** | `cancelLeaveRequestNew()` | `requestLeaveCancel()` |
| **취소 사유** | ❌ 없음 | ✅ 필수 입력 |
| **처리 방식** | 즉시 취소 | 관리자 승인 대기 |
| **상태 변경** | `CANCELLED` | `CANCEL_REQUESTED` |

### **3. Request Body 비교**

**기존 (즉시 취소)**:
```json
{
  "id": 123,
  "userId": "admin@aspnc.com"
}
```

**수정 후 (취소 상신)**:
```json
{
  "id": 123,
  "userId": "admin@aspnc.com",
  "reason": "일정 변경으로 인한 휴가 취소"  // ✅ 취소 사유 추가
}
```

---

## 🔧 **수정된 파일**

### **`DesktopLeaveManagement.tsx`**

#### **1) Import 추가**
```typescript
import LeaveCancelRequestDialog from './LeaveCancelRequestDialog';
```

#### **2) handleCancelRequest 함수 제거**
```typescript
// ❌ 제거됨
const handleCancelRequest = async () => {
  // ... cancelLeaveRequestNew 호출 코드
};
```

#### **3) handleCancelSuccess 함수 추가**
```typescript
// ✅ 추가됨
const handleCancelSuccess = () => {
  onRefresh();
  setCancelRequestModalOpen(false);
  setCancelRequestLeave(null);
};
```

#### **4) 기존 취소 확인 모달 제거**
```typescript
// ❌ 제거됨: 간단한 확인 다이얼로그 (취소 사유 없음)
<Dialog open={cancelRequestModalOpen}>
  <DialogTitle>취소 상신 확인</DialogTitle>
  <DialogContent>
    다음 휴가를 취소하시겠습니까?
  </DialogContent>
  <DialogActions>
    <Button onClick={handleCancelRequest}>취소 상신</Button>
  </DialogActions>
</Dialog>
```

#### **5) LeaveCancelRequestDialog 컴포넌트로 대체**
```typescript
// ✅ 추가됨: 취소 사유 입력 다이얼로그
<LeaveCancelRequestDialog
  open={cancelRequestModalOpen}
  onClose={() => {
    setCancelRequestModalOpen(false);
    setCancelRequestLeave(null);
  }}
  onSuccess={handleCancelSuccess}
  leave={cancelRequestLeave}
  userId={user?.userId || ''}
/>
```

---

## 📊 **처리 흐름 비교**

### **기존 (잘못됨)**
```
1. 취소상신 버튼 클릭
2. 간단한 확인 다이얼로그 표시 (취소 사유 없음)
3. 확인 클릭 → cancelLeaveRequestNew() 호출
4. POST /leave/user/cancel
5. ❌ 즉시 취소됨 (CANCELLED 상태)
```

### **수정 후 (올바름)**
```
1. 취소상신 버튼 클릭
2. LeaveCancelRequestDialog 표시
3. 취소 사유 입력 (필수)
4. 상신 클릭 → requestLeaveCancel() 호출
5. POST /leave/user/cancel/request
6. ✅ 관리자 승인 대기 (CANCEL_REQUESTED 상태)
7. 관리자 승인 → CANCELLED 상태로 변경
```

---

## 🎯 **Flutter 앱과의 일관성**

| 기능 | Flutter App | React Web (수정 전) | React Web (수정 후) |
|------|-------------|---------------------|---------------------|
| **API 엔드포인트** | `/leave/user/cancel/request` | `/leave/user/cancel` | `/leave/user/cancel/request` ✅ |
| **취소 사유 입력** | ✅ 필수 | ❌ 없음 | ✅ 필수 |
| **관리자 승인** | ✅ 필요 | ❌ 불필요 (즉시 취소) | ✅ 필요 |
| **상태 변경** | `CANCEL_REQUESTED` | `CANCELLED` | `CANCEL_REQUESTED` ✅ |

---

## ✨ **LeaveCancelRequestDialog 컴포넌트 특징**

### **이미 구현된 기능**

1. **취소 사유 입력**
   - 필수 입력 필드
   - 다중 행 텍스트 입력 (4줄)
   - 플레이스홀더: "예: 일정 변경으로 인한 휴가 취소"

2. **휴가 정보 표시**
   - 휴가 종류
   - 시작일 ~ 종료일
   - 일수 계산

3. **유효성 검증**
   - 취소 사유 필수 입력 체크
   - 빈 문자열 제출 방지

4. **에러 처리**
   - API 에러 메시지 표시
   - 네트워크 오류 핸들링

5. **로딩 상태**
   - 상신 중 버튼 비활성화
   - 중복 제출 방지

6. **반응형 UI**
   - 모바일: 전체 화면 모달
   - 데스크톱: 중간 크기 모달

---

## 🔍 **API 응답 구조**

### **성공 응답**
```json
{
  "approval_status": {
    "requested": 1,
    "approved": 0,
    "rejected": 0
  },
  "leave_status": [
    {
      "id": 123,
      "status": "CANCEL_REQUESTED",  // ✅ 취소 상신 대기 상태
      "leave_type": "연차휴가",
      "start_date": "2024-01-15",
      "end_date": "2024-01-16",
      "total_days": 2,
      "reason": "일정 변경으로 인한 휴가 취소"
    }
  ],
  "error": null
}
```

### **에러 응답**
```json
{
  "error": "휴가 취소 상신에 실패했습니다. 상태 코드: 400"
}
```

---

## 🧪 **테스트 시나리오**

### **1. 정상 흐름**
```
1. ✅ APPROVED 상태 휴가 조회
2. ✅ 취소상신 버튼 클릭
3. ✅ 취소 사유 입력 다이얼로그 표시
4. ✅ 취소 사유 입력 (예: "일정 변경")
5. ✅ "상신" 버튼 클릭
6. ✅ API 호출: POST /leave/user/cancel/request
7. ✅ 상태 변경: APPROVED → CANCEL_REQUESTED
8. ✅ 성공 메시지 표시
9. ✅ 데이터 새로고침
10. ✅ 다이얼로그 닫힘
```

### **2. 유효성 검증**
```
1. ✅ 취소 사유 미입력 시 "상신" 버튼 비활성화
2. ✅ 공백만 입력 시 "취소 사유를 입력해주세요" 에러
```

### **3. 에러 처리**
```
1. ✅ 네트워크 오류 시 에러 메시지 표시
2. ✅ 서버 에러 시 에러 메시지 표시
3. ✅ 상신 중 중복 클릭 방지
```

---

## 📝 **관련 파일**

| 파일 | 역할 | 상태 |
|------|------|------|
| `src/services/leaveService.ts` | API 호출 함수 (`requestLeaveCancel`) | ✅ 이미 구현됨 |
| `src/types/leave.ts` | 타입 정의 (`LeaveCancelRequestPayload`) | ✅ 이미 구현됨 |
| `src/components/leave/LeaveCancelRequestDialog.tsx` | 취소 사유 입력 다이얼로그 | ✅ 이미 구현됨 |
| `src/components/leave/DesktopLeaveManagement.tsx` | 휴가 관리 메인 화면 | ✅ 수정 완료 |

---

## 🎉 **결론**

### **수정 완료!**

✅ **Flutter 앱과 동일한 2단계 취소 프로세스 구현**
- 1단계: 사용자 취소 상신 (취소 사유 입력)
- 2단계: 관리자 승인/반려

✅ **올바른 API 호출**
- `/leave/user/cancel/request` (취소 상신)
- 취소 사유 필수 입력

✅ **관리자 승인 대기 상태**
- `APPROVED` → `CANCEL_REQUESTED`
- 관리자 승인 후 `CANCELLED`

✅ **사용자 경험 개선**
- 취소 사유 입력으로 명확한 의사 전달
- 실수로 인한 즉시 취소 방지

이제 React 웹앱에서도 Flutter 앱과 동일하게 **관리자 승인이 필요한 휴가 취소 상신**이 정상적으로 동작합니다! 🎯
