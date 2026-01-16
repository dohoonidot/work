# 관리자용 휴가 결재 화면 - 취소 승인 기능 구현 완료

## 🎯 **구현 목표**

React 웹앱의 **휴가관리 → 관리자용 결재 화면**에서 상태별로 다른 버튼을 표시하고 각각 올바른 API를 호출

---

## ✅ **구현 완료 내용**

### **1. 상태별 버튼 표시 로직**

#### **수정 전 (❌ 문제점)**
```typescript
// 모든 REQUESTED 상태에 대해 승인 + 반려 버튼을 모두 표시
{leave.status.includes('REQUESTED') && (
  <Box>
    <Button>승인</Button>
    <Button>반려</Button>
  </Box>
)}
```

#### **수정 후 (✅ 올바름)**
```typescript
{leave.status.includes('REQUESTED') && (
  <Box sx={{ display: 'flex', gap: 0.5, justifyContent: 'center' }}>
    {leave.isCancel === 1 ? (
      // CANCEL_REQUESTED 상태: 취소 승인 버튼만 표시
      <Button
        size="small"
        variant="contained"
        color="warning"
        onClick={() => {
          setSelectedLeave(leave);
          setApprovalAction('approve');
          setApprovalDialog(true);
        }}
      >
        취소 승인
      </Button>
    ) : (
      // REQUESTED 상태: 승인 + 반려 버튼 표시
      <>
        <Button color="success">승인</Button>
        <Button color="error">반려</Button>
      </>
    )}
  </Box>
)}
```

### **2. 다이얼로그 제목 동적 표시**

#### **수정 전**
```typescript
<DialogTitle>
  <Typography>
    {approvalAction === 'approve' ? '휴가 승인' : '휴가 반려'}
  </Typography>
</DialogTitle>
```

#### **수정 후**
```typescript
<DialogTitle>
  <Typography>
    {selectedLeave?.isCancel === 1
      ? '휴가 취소 승인'           // 취소 상신일 때
      : approvalAction === 'approve'
      ? '휴가 승인'                // 일반 승인일 때
      : '휴가 반려'}               // 반려일 때
  </Typography>
</DialogTitle>
```

### **3. API 호출 로직 (기존 유지)**

이미 구현되어 있던 API 호출 로직은 그대로 유지:

```typescript
// 승인 처리
const handleApprove = async () => {
  const isCancel = selectedLeave.isCancel === 1;

  if (isCancel) {
    // 취소 상신 승인 → /leave/admin/approval/cancel
    await leaveService.processCancelApproval({
      id: selectedLeave.id,
      approverId: user.userId,
      isApproved: 'APPROVED',
    });
  } else {
    // 일반 휴가 승인 → /leave/admin/approval
    await leaveService.processAdminApproval({
      id: selectedLeave.id,
      approverId: user.userId,
      isApproved: 'APPROVED',
    });
  }
};

// 반려 처리
const handleReject = async () => {
  const isCancel = selectedLeave.isCancel === 1;

  if (isCancel) {
    // 취소 상신 반려 → /leave/admin/approval/cancel
    await leaveService.processCancelApproval({
      id: selectedLeave.id,
      approverId: user.userId,
      isApproved: 'REJECTED',
      rejectMessage: rejectMessage.trim(),
    });
  } else {
    // 일반 휴가 반려 → /leave/admin/approval
    await leaveService.processAdminApproval({
      id: selectedLeave.id,
      approverId: user.userId,
      isApproved: 'REJECTED',
      rejectMessage: rejectMessage.trim(),
    });
  }
};
```

---

## 📊 **상태별 UI 표시**

| 상태 | `isCancel` 값 | 표시되는 버튼 | 버튼 색상 | API 엔드포인트 |
|------|---------------|---------------|-----------|----------------|
| **CANCEL_REQUESTED** | `1` | "취소 승인" 만 | `warning` (주황색) | `/leave/admin/approval/cancel` |
| **REQUESTED** | `0` | "승인" + "반려" | `success` + `error` | `/leave/admin/approval` |
| **APPROVED** | - | 없음 | - | - |
| **REJECTED** | - | 없음 | - | - |
| **CANCELLED** | - | 없음 | - | - |

---

## 🔧 **수정된 파일**

### **`AdminLeaveApprovalScreen.tsx`**

1. **버튼 표시 로직 수정** (line 533-580)
   - `isCancel === 1`: "취소 승인" 버튼만 표시
   - `isCancel === 0`: "승인" + "반려" 버튼 표시

2. **다이얼로그 제목 수정** (line 614-625)
   - 취소 상신일 때: "휴가 취소 승인"
   - 일반 승인일 때: "휴가 승인" / "휴가 반려"

---

## 🎨 **버튼 디자인**

### **취소 승인 버튼**
```typescript
<Button
  size="small"
  variant="contained"
  color="warning"  // 주황색 (취소 상신 구분)
>
  취소 승인
</Button>
```

### **일반 승인 버튼**
```typescript
<Button
  size="small"
  variant="contained"
  color="success"  // 녹색
>
  승인
</Button>
```

### **반려 버튼**
```typescript
<Button
  size="small"
  variant="contained"
  color="error"    // 빨간색
>
  반려
</Button>
```

---

## 🔍 **API 요청/응답 구조**

### **1. 일반 승인/반려**

**엔드포인트**: `POST /leave/admin/approval`

**Request**:
```json
{
  "id": 123,
  "approver_id": "admin@aspnc.com",
  "is_approved": "APPROVED",  // or "REJECTED"
  "reject_message": "반려 사유"  // 반려 시에만
}
```

### **2. 취소 승인/반려**

**엔드포인트**: `POST /leave/admin/approval/cancel`

**Request**:
```json
{
  "id": 123,
  "approver_id": "admin@aspnc.com",
  "is_approved": "APPROVED",  // or "REJECTED"
  "reject_message": "반려 사유"  // 반려 시에만
}
```

---

## 📝 **사용자 시나리오**

### **시나리오 1: 일반 휴가 승인**
```
1. 관리자용 결재 화면 진입
2. REQUESTED 상태 휴가 확인
3. "승인" 또는 "반려" 버튼 표시됨
4. "승인" 클릭
5. "휴가 승인" 다이얼로그 표시
6. "승인하기" 버튼 클릭
7. POST /leave/admin/approval 호출
8. 상태가 APPROVED로 변경
```

### **시나리오 2: 휴가 취소 승인**
```
1. 관리자용 결재 화면 진입
2. CANCEL_REQUESTED 상태 휴가 확인 (🔄 취소 대기 표시)
3. "취소 승인" 버튼만 표시됨 (주황색)
4. "취소 승인" 클릭
5. "휴가 취소 승인" 다이얼로그 표시
6. "승인하기" 버튼 클릭
7. POST /leave/admin/approval/cancel 호출
8. 상태가 CANCELLED로 변경
```

---

## ✨ **주요 개선 사항**

### **1. 명확한 UI/UX**
- ✅ 취소 상신과 일반 상신을 시각적으로 구분 (주황색 vs 녹색)
- ✅ 상태에 따라 적절한 버튼만 표시
- ✅ 다이얼로그 제목으로 작업 내용 명확히 표시

### **2. API 분리**
- ✅ 일반 승인: `/leave/admin/approval`
- ✅ 취소 승인: `/leave/admin/approval/cancel`
- ✅ 서버에서 로직을 명확히 구분 가능

### **3. 일관성**
- ✅ Flutter 앱과 동일한 동작
- ✅ 사용자 경험 통일
- ✅ 관리자의 혼란 방지

---

## 🧪 **테스트 체크리스트**

### **일반 휴가 승인**
- [ ] REQUESTED 상태 휴가에 "승인" + "반려" 버튼 표시
- [ ] "승인" 클릭 → "휴가 승인" 다이얼로그 표시
- [ ] "승인하기" 클릭 → API 호출 성공
- [ ] 상태가 APPROVED로 변경
- [ ] 데이터 새로고침

### **휴가 취소 승인**
- [ ] CANCEL_REQUESTED 상태 휴가에 "취소 승인" 버튼만 표시
- [ ] 버튼 색상이 주황색(warning)으로 표시
- [ ] "취소 승인" 클릭 → "휴가 취소 승인" 다이얼로그 표시
- [ ] "승인하기" 클릭 → API 호출 성공
- [ ] 상태가 CANCELLED로 변경
- [ ] 데이터 새로고침

### **반려 처리**
- [ ] 일반 휴가 반려 시 `/leave/admin/approval` 호출
- [ ] 취소 상신 반려 시 `/leave/admin/approval/cancel` 호출
- [ ] 반려 사유 필수 입력 체크
- [ ] 상태가 REJECTED로 변경

---

## 🎯 **결론**

### **구현 완료!** ✅

React 웹앱의 관리자 결재 화면에서:

1. ✅ **상태별 버튼 표시**
   - `CANCEL_REQUESTED`: "취소 승인" 버튼만
   - `REQUESTED`: "승인" + "반려" 버튼

2. ✅ **API 분기 처리**
   - 취소 상신: `/leave/admin/approval/cancel`
   - 일반 상신: `/leave/admin/approval`

3. ✅ **다이얼로그 제목 동적 표시**
   - 상황에 맞는 제목 표시

4. ✅ **Flutter 앱과 동일한 동작**
   - 완벽한 기능 일치

이제 관리자가 **일반 휴가 승인**과 **취소 승인**을 명확히 구분하여 처리할 수 있습니다! 🎉
