# 휴가관리 기능 비교 분석 (Flutter vs React)

## 📋 개요
Flutter 앱(`lib`)과 React 웹앱(`web_app/src`)의 휴가관리 기능을 비교하여 누락된 기능과 API를 정리합니다.

---

## ✅ 이미 구현된 기능

### 1. 휴가관리 화면 API
- ✅ `getLeaveManagement` - 휴가관리 데이터 조회
- ✅ `getMonthlyCalendar` - 월별 달력 조회
- ✅ `getYearlyLeave` - 연도별 휴가 내역 조회
- ✅ `getTotalCalendar` - 전체 부서 휴가 현황 조회

### 2. 휴가 신청/취소 API
- ✅ `submitLeaveRequest` - 휴가 상신 (새로운 API)
- ✅ `cancelLeave` - 휴가 취소 (새로운 API)
- ✅ `requestLeaveCancel` - 휴가 취소 상신
- ✅ `getApproverList` - 승인자 목록 조회

### 3. 관리자용 API
- ✅ `getDepartmentLeaveStatus` - 부서원 휴가 현황 조회
- ✅ `getAdminManagementData` - 관리자 관리 페이지 초기 데이터 조회
- ✅ `processAdminApproval` - 관리자 승인/반려 처리
- ✅ `processCancelApproval` - 관리자 취소 승인/반려 처리
- ✅ `getAdminDeptCalendar` - 관리자 부서별 달력 조회
- ✅ `getPendingApprovals` - 관리자 승인 대기 목록 조회 (기존 API)

### 4. 대시보드 통합 API
- ✅ `getLeaveBalance` - 내 휴가 현황 조회
- ✅ `getLeaveRequestHistory` - 휴가 신청 내역 조회
- ✅ `getDepartmentMembers` - 부서원 목록 조회
- ✅ `getDepartmentLeaveHistory` - 부서 휴가 내역 조회
- ✅ `getLeaveManagementTable` - 휴가 관리 대장 데이터 조회

### 5. 기타 API
- ✅ `getNextYearLeaveStatus` - 내년 정기휴가 조회
- ✅ `submitLeaveGrantRequest` - 휴가 부여 상신

---

## ❌ 누락된 기능 및 API

### 1. 관리자 결재 대기 목록 조회 (모달용) - **✅ 구현 완료**

**Flutter API:**
```dart
static Future<List<AdminWaitingLeave>> getAdminWaitingLeaves({
  required String approverId,
}) async {
  final url = Uri.parse('$serverUrl/leave/admin/management/waitingLeaves');
  // ...
}
```

**용도:**
- `leave.approval` 큐 알림 클릭 시 사용
- 현재 대기 중인 결재 건만 조회

**React 구현 상태:**
- ✅ `leaveService.ts`에 `getAdminWaitingLeaves` 함수 추가 완료
- ⚠️ 알림 클릭 시 모달에서 사용하는 UI 구현 필요 (향후 작업)

---

## 🔍 확인 필요 사항

### 1. 휴가 관리 대장 UI
- ✅ React에 구현되어 있음 (`DesktopLeaveManagement.tsx`)
- ⚠️ Flutter 앱과 UI/UX 일치 여부 확인 필요

### 2. 내년 정기휴가 조회 UI
- ✅ API는 구현되어 있음 (`getNextYearLeaveStatus`)
- ⚠️ UI에서 실제로 사용되고 있는지 확인 필요

### 3. 휴가 부여 상신 UI
- ✅ API는 구현되어 있음 (`submitLeaveGrantRequest`)
- ⚠️ UI에서 실제로 사용되고 있는지 확인 필요

### 4. 관리자 결재 대기 목록 모달
- ❌ `getAdminWaitingLeaves` API가 없음
- ❌ 알림 클릭 시 모달이 구현되어 있지 않음

---

## 📝 구현 우선순위

### 🔴 높음 (즉시 구현 필요)
1. **관리자 결재 대기 목록 조회 API** (`getAdminWaitingLeaves`)
   - 알림 클릭 시 모달에서 사용
   - SSE 알림과 연동 필요

### 🟡 중간 (확인 후 구현)
2. **내년 정기휴가 조회 UI**
   - API는 있지만 UI에서 사용 여부 확인
   - Flutter 앱의 UI와 비교하여 구현

3. **휴가 부여 상신 UI**
   - API는 있지만 UI에서 사용 여부 확인
   - 전자결재 상신 모달과 연동 필요

### 🟢 낮음 (향후 개선)
4. **휴가 관리 대장 UI 개선**
   - Flutter 앱과 UI/UX 일치 여부 확인
   - 필요시 개선

---

## 🔧 구현 가이드

### 1. getAdminWaitingLeaves API 추가

**파일:** `web_app/src/services/leaveService.ts`

```typescript
/**
 * 관리자 결재 대기 목록 조회 (모달용) - Flutter와 동일
 * 
 * 사용 시점: leave.approval 큐 알림 클릭 시
 * 반환 데이터: 현재 대기 중인 결재 건만 조회
 */
async getAdminWaitingLeaves(approverId: string): Promise<any[]> {
  console.log('🔍 [LeaveService] 관리자 결재 대기 목록 API 요청:', { approver_id: approverId });

  try {
    const response = await api.post<any>('/leave/admin/management/waitingLeaves', {
      approver_id: approverId,
    });

    console.log('🔍 [LeaveService] 관리자 결재 대기 목록 응답:', response.data);

    // API 응답이 snake_case로 오므로 camelCase로 변환
    const data = response.data;
    const waitingLeaves = (data.waiting_leaves || []).map((item: any) => ({
      id: item.id || 0,
      userId: item.user_id || item.userId || '',
      name: item.name || '',
      department: item.department || '',
      jobPosition: item.job_position || item.jobPosition || '',
      leaveType: item.leave_type || item.leaveType || '',
      startDate: item.start_date || item.startDate || '',
      endDate: item.end_date || item.endDate || '',
      workdaysCount: item.workdays_count || item.workdaysCount || 0,
      reason: item.reason || '',
      status: item.status || '',
      isCancel: item.is_cancel || item.isCancel || 0,
      requestedDate: item.requested_date || item.requestedDate || '',
      // ... 기타 필드
    }));

    return waitingLeaves;
  } catch (error: any) {
    console.error('❌ [LeaveService] 관리자 결재 대기 목록 API 호출 실패:', error);
    return [];
  }
}
```

### 2. 타입 정의 추가

**파일:** `web_app/src/types/leave.ts`

```typescript
export interface AdminWaitingLeave {
  id: number;
  userId: string;
  name: string;
  department: string;
  jobPosition: string;
  leaveType: string;
  startDate: string;
  endDate: string;
  workdaysCount: number;
  reason: string;
  status: string;
  isCancel: number;
  requestedDate: string;
  // ... 기타 필드
}
```

### 3. 알림 클릭 시 모달 구현

**파일:** `web_app/src/components/common/NotificationPanel.tsx` 또는 새 컴포넌트

```typescript
// 알림 클릭 시 관리자 결재 대기 목록 모달 표시
const handleLeaveApprovalNotification = async (notification: NotificationDisplay) => {
  const approverId = authService.getCurrentUser()?.id;
  if (!approverId) return;

  const waitingLeaves = await leaveService.getAdminWaitingLeaves(approverId);
  // 모달 표시 로직
};
```

---

## 📚 참고 파일

### Flutter 앱
- `lib/shared/services/leave_api_service.dart` - API 서비스
- `lib/ui/screens/leave_management_screen.dart` - 휴가관리 화면
- `lib/ui/screens/admin_leave_approval_screen.dart` - 관리자 승인 화면

### React 웹앱
- `web_app/src/services/leaveService.ts` - API 서비스
- `web_app/src/pages/LeaveManagementPage.tsx` - 휴가관리 페이지
- `web_app/src/pages/AdminLeaveApprovalPage.tsx` - 관리자 승인 페이지
- `web_app/src/components/leave/DesktopLeaveManagement.tsx` - 데스크톱 휴가관리 컴포넌트

---

## ✅ 체크리스트

- [x] `getAdminWaitingLeaves` API 구현 ✅
- [x] `AdminWaitingLeave` 타입 정의 확인 (이미 존재) ✅
- [ ] 알림 클릭 시 관리자 결재 대기 목록 모달 구현 (향후 작업)
- [ ] 내년 정기휴가 조회 UI 확인 및 구현
- [ ] 휴가 부여 상신 UI 확인 및 구현
- [ ] 휴가 관리 대장 UI Flutter 앱과 비교 및 개선

