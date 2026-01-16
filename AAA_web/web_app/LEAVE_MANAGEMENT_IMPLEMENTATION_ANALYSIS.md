# 휴가관리 기능 구현 가능성 분석

## 📋 Flutter 앱의 휴가관리 기능 분석

### 1. 주요 화면 및 컴포넌트

#### ✅ 이미 구현된 기능 (웹 앱)
- ✅ 휴가관리 메인 화면 (`LeaveManagement.tsx`, `LeaveManagementPage.tsx`)
- ✅ 휴가 신청 모달 (`LeaveRequestModal.tsx`)
- ✅ 휴가 취소 상신 다이얼로그 (`LeaveCancelRequestDialog.tsx`)
- ✅ 관리자 승인 화면 (`AdminLeaveApprovalScreen.tsx`, `AdminLeaveApprovalPage.tsx`)
- ✅ 부서 휴가 현황 달력 (`TotalCalendar.tsx`)

#### ⚠️ 부분 구현 또는 미구현 기능
- ⚠️ 월별 달력 조회 (`getMonthlyCalendar`) - API는 정의되어 있으나 UI에서 사용 안 함
- ⚠️ 연도별 휴가 내역 조회 (`getYearlyLeave`) - API는 정의되어 있으나 UI에서 사용 안 함
- ⚠️ 휴가 관리 대장 (`getLeaveManagementTable`) - API는 정의되어 있으나 UI에서 사용 안 함
- ⚠️ 내 휴가 현황 조회 (`getLeaveBalance`) - API는 정의되어 있으나 UI에서 사용 안 함
- ⚠️ 부서 휴가 내역 조회 (`getDepartmentHistory`) - API는 정의되어 있으나 UI에서 사용 안 함
- ⚠️ 내년 정기휴가 조회 (`getNextYearLeaveStatus`) - API는 정의되어 있으나 UI에서 사용 안 함
- ⚠️ 휴가 부여 상신 (`submitLeaveGrantRequest`) - API는 정의되어 있으나 UI에서 사용 안 함

### 2. Flutter 앱의 주요 UI 기능

#### 📅 달력 관련 기능
1. **월별 달력 조회** (`getMonthlyCalendar`)
   - 달력 월 변경 시 해당 월의 휴가 일정 조회
   - Flutter: `leave_management_screen.dart`의 `_buildCalendarSection()`에서 사용
   - 웹 앱: API는 정의되어 있으나 달력 월 변경 시 호출하는 로직 없음

2. **전체 달력 모달** (`FullCalendarModal`)
   - 사이드바에서 "휴가 캘린더" 버튼 클릭 시 전체 화면 달력 모달 표시
   - 내 휴가 내역 / 부서 휴가 현황 뷰 전환 가능
   - 웹 앱: 미구현

3. **부서 휴가 현황 달력** (`getTotalCalendar`)
   - 부서 전체 휴가 현황을 달력 형태로 표시
   - 웹 앱: `TotalCalendar.tsx`에서 일부 구현됨

#### 📊 데이터 조회 기능
1. **연도별 휴가 내역 조회** (`getYearlyLeave`)
   - 개인별 휴가 내역에서 연도 필터링 시 사용
   - Flutter: `leave_management_screen.dart`의 `_loadYearlyData()`에서 사용
   - 웹 앱: API는 정의되어 있으나 연도 필터 기능 없음

2. **휴가 관리 대장** (`getLeaveManagementTable`)
   - 월별 휴가 사용 현황을 테이블 형태로 표시
   - Flutter: `_buildLeaveManagementTable()`에서 사용
   - 웹 앱: API는 정의되어 있으나 UI 미구현

3. **내 휴가 현황 조회** (`getLeaveBalance`)
   - 휴가 유형별 총일수, 사용일수, 잔여일수 조회
   - Flutter: `_buildLeaveBalanceHeader()`에서 사용
   - 웹 앱: API는 정의되어 있으나 UI에서 사용 안 함 (대신 `getLeaveManagement`의 `leaveStatus` 사용)

4. **부서 휴가 내역 조회** (`getDepartmentHistory`)
   - 부서원들의 휴가 내역을 조회
   - 웹 앱: API는 정의되어 있으나 UI 미구현

5. **내년 정기휴가 조회** (`getNextYearLeaveStatus`)
   - 내년 정기휴가 현황 조회
   - 웹 앱: API는 정의되어 있으나 UI 미구현

#### 🎯 관리자 기능
1. **관리자 부서원 휴가 현황** (`getDepartmentLeaveStatus`)
   - 관리자 사이드바에서 부서원 휴가 현황 조회
   - 웹 앱: API는 정의되어 있으나 사이드바에서 사용 안 함

2. **관리자 부서별 달력 조회** (`getAdminDeptCalendar`)
   - 관리자용 부서별 달력 조회 (넓게보기)
   - 웹 앱: API는 정의되어 있으나 UI 미구현

3. **휴가 부여 상신** (`submitLeaveGrantRequest`)
   - 관리자가 부서원에게 휴가를 부여하는 기능
   - 웹 앱: API는 정의되어 있으나 UI 미구현

#### 📝 기타 기능
1. **연차휴가 사용촉진 통지서** (`AnnualLeaveNoticeScreen`)
   - 연차휴가 사용촉진 통지서 화면
   - 웹 앱: 미구현

2. **취소건 숨김 토글**
   - 취소된 휴가 건을 숨기거나 표시하는 기능
   - Flutter: `toggleHideCanceledRecords()` 사용
   - 웹 앱: 미구현

3. **슬라이드 패널 (상세 정보)**
   - 휴가 관리 대장에서 항목 클릭 시 상세 정보를 슬라이드 패널로 표시
   - Flutter: `_buildDetailPanel()` 사용
   - 웹 앱: 미구현

## ✅ 구현 가능 여부

### 완전히 구현 가능한 기능 (100%)
모든 API가 이미 정의되어 있고, Flutter 앱의 로직을 참조하여 구현 가능합니다.

1. **월별 달력 조회** - 달력 월 변경 시 API 호출 로직 추가
2. **연도별 휴가 내역 조회** - 연도 필터 드롭다운 추가 및 API 호출
3. **휴가 관리 대장** - 테이블 컴포넌트 생성 및 데이터 표시
4. **내 휴가 현황 조회** - 별도 API 호출 또는 기존 데이터 활용
5. **부서 휴가 내역 조회** - 부서원 목록 및 휴가 내역 표시
6. **내년 정기휴가 조회** - 별도 섹션 추가
7. **관리자 부서원 휴가 현황** - 사이드바에 추가
8. **관리자 부서별 달력 조회** - 관리자 화면에 추가
9. **휴가 부여 상신** - 관리자 화면에 휴가 부여 모달 추가
10. **연차휴가 사용촉진 통지서** - 별도 페이지 생성
11. **취소건 숨김 토글** - 토글 버튼 추가
12. **슬라이드 패널** - 상세 정보 패널 컴포넌트 생성
13. **전체 달력 모달** - 전체 화면 달력 모달 컴포넌트 생성

## 📝 구현 우선순위

### 높은 우선순위 (핵심 기능)
1. ✅ 월별 달력 조회 - 달력 기능 완성
2. ✅ 연도별 휴가 내역 조회 - 데이터 필터링 기능
3. ✅ 휴가 관리 대장 - 주요 데이터 표시
4. ✅ 취소건 숨김 토글 - 사용자 편의 기능

### 중간 우선순위 (유용한 기능)
5. ✅ 전체 달력 모달 - 달력 전체 보기
6. ✅ 슬라이드 패널 - 상세 정보 표시
7. ✅ 부서 휴가 내역 조회 - 부서원 휴가 확인

### 낮은 우선순위 (부가 기능)
8. ✅ 내년 정기휴가 조회
9. ✅ 관리자 부서원 휴가 현황
10. ✅ 관리자 부서별 달력 조회
11. ✅ 휴가 부여 상신
12. ✅ 연차휴가 사용촉진 통지서

## 🎯 결론

**모든 기능 구현 가능합니다!**

- ✅ 모든 API가 이미 정의되어 있음
- ✅ Flutter 앱의 UI/UX를 참조하여 동일하게 구현 가능
- ✅ React/Material-UI로 충분히 구현 가능한 기능들
- ✅ 단계적으로 구현하면 Flutter 앱과 동일한 기능 제공 가능

**권장 사항:**
1. 먼저 핵심 기능(월별 달력, 연도별 조회, 휴가 관리 대장)부터 구현
2. Flutter 앱의 UI/UX를 최대한 유사하게 구현
3. 기존 웹 앱의 컴포넌트 구조를 활용하여 재사용성 높이기

