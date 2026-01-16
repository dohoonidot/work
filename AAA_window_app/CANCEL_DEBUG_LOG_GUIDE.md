# 취소상신 디버그 로그 가이드

## 추가된 로그 위치

전체 데이터 흐름에서 `is_cancel` 값을 추적하는 로그를 추가했습니다.

### 1️⃣ API 응답 단계
**파일:** `lib/shared/services/leave_api_service.dart` (line 53-73)

**로그 형식:**
```
🔍 ========== [CANCEL_DEBUG] 서버 응답 분석 시작 ==========
🔍 [CANCEL_DEBUG] yearlyDetails 개수: X개
🔍 [CANCEL_DEBUG] === 휴가 항목 #1 ===
🔍 [CANCEL_DEBUG]   - id: 123
🔍 [CANCEL_DEBUG]   - leave_type: 연차
🔍 [CANCEL_DEBUG]   - status: REQUESTED
🔍 [CANCEL_DEBUG]   - is_cancel: 1 (타입: int)
🔍 [CANCEL_DEBUG]   - start_date: 2024-01-15
🔍 [CANCEL_DEBUG]   ⭐⭐⭐ 취소상신 건 발견! ⭐⭐⭐
🔍 ========== [CANCEL_DEBUG] 서버 응답 분석 종료 ==========
```

**확인 사항:**
- ✅ `is_cancel` 필드가 존재하는가?
- ✅ 취소상신 건의 `is_cancel` 값이 `1`인가?
- ❌ `is_cancel`이 null이거나 항상 `0`이면 → **서버 문제**

---

### 2️⃣ 모델 파싱 단계
**파일:** `lib/models/leave_management_models.dart` (line 160-188)

**로그 형식:**
```
🔍 [CANCEL_DEBUG] YearlyDetail.fromJson 시작
🔍 [CANCEL_DEBUG]   - 원본 is_cancel 값: 1 (타입: int)
🔍 [CANCEL_DEBUG]   - 파싱된 isCancel 값: 1 (타입: int)
🔍 [CANCEL_DEBUG]   - 생성된 객체의 isCancel: 1
🔍 [CANCEL_DEBUG]   - 생성된 객체의 isCancelRequest: true
🔍 [CANCEL_DEBUG]   ⭐⭐⭐ 취소상신 객체 생성됨! (ID: 123) ⭐⭐⭐
```

**확인 사항:**
- ✅ 원본 값이 제대로 파싱되는가?
- ✅ `isCancelRequest` getter가 `true`를 반환하는가?
- ❌ 원본 값은 1인데 파싱 값이 0이면 → **모델 파싱 문제**

---

### 3️⃣ 리스트 필터링 단계
**파일:** `lib/ui/screens/leave_management_screen.dart` (line 879-895)

**로그 형식:**
```
🔍 [CANCEL_DEBUG] ========== 리스트 필터링 상태 ==========
📊 전체 휴가내역: 5개
📊 필터링된 휴가내역: 5개
📊 취소건 숨김 상태: false

🔍 [CANCEL_DEBUG] === 전체 항목 is_cancel 값 확인 ===
🔍 [CANCEL_DEBUG] 항목 #1: ID=123, status=REQUESTED, isCancel=1, isCancelRequest=true
🔍 [CANCEL_DEBUG]   ⭐⭐⭐ 취소상신 발견! ⭐⭐⭐
🔍 [CANCEL_DEBUG] 항목 #2: ID=124, status=APPROVED, isCancel=0, isCancelRequest=false
🔍 [CANCEL_DEBUG] ========================================
```

**확인 사항:**
- ✅ 필터링으로 인해 취소상신 건이 제거되지 않았는가?
- ✅ 각 항목의 `isCancelRequest` 값이 올바른가?
- ❌ 취소건 숨김이 활성화되어 있으면 → **필터 설정 확인**

---

### 4️⃣ UI 렌더링 단계
**파일:** `lib/ui/screens/leave_management_screen.dart` (line 1803-1814)

**로그 형식:**
```
🔍 [CANCEL_DEBUG] ========== UI 렌더링 시작 ==========
🔍 [CANCEL_DEBUG] 휴가 항목 ID: 123
🔍 [CANCEL_DEBUG] leave_type: 연차
🔍 [CANCEL_DEBUG] status: REQUESTED
🔍 [CANCEL_DEBUG] isCancel 값: 1
🔍 [CANCEL_DEBUG] isCancelRequest 값: true
🔍 [CANCEL_DEBUG] 취소상신 배지 표시 여부: ✅ 표시됨
🔍 [CANCEL_DEBUG] ⭐⭐⭐ 취소상신 배지가 화면에 표시되어야 합니다! ⭐⭐⭐
🔍 [CANCEL_DEBUG] ========== UI 렌더링 종료 ==========
```

**확인 사항:**
- ✅ `isCancelRequest`가 `true`인가?
- ✅ 배지 표시 여부가 "✅ 표시됨"인가?
- ❌ 로그는 "✅ 표시됨"인데 화면에 안 보이면 → **UI 렌더링 문제**

---

## 테스트 절차

### Step 1: 앱 실행
```bash
cd /mnt/c/AI_Agent/AI_Agent/Agent_APP/Desktop_App_amqp_beforeLog
flutter run -d windows
```

### Step 2: 휴가관리 화면 진입
1. 로그인
2. 좌측 사이드바에서 "휴가관리" 클릭
3. **콘솔 창을 계속 주시하세요!**

### Step 3: 로그 분석

#### 📍 체크포인트 1: API 응답
콘솔에서 찾을 내용:
```
🔍 ========== [CANCEL_DEBUG] 서버 응답 분석 시작 ==========
```

**정상:**
```
🔍 [CANCEL_DEBUG]   - is_cancel: 1 (타입: int)
🔍 [CANCEL_DEBUG]   ⭐⭐⭐ 취소상신 건 발견! ⭐⭐⭐
```

**비정상 (서버 문제):**
```
🔍 [CANCEL_DEBUG]   - is_cancel: 0 (타입: int)  // ❌ 항상 0
```
또는
```
🔍 [CANCEL_DEBUG]   - is_cancel: null (타입: Null)  // ❌ 필드 없음
```

#### 📍 체크포인트 2: 모델 파싱
**정상:**
```
🔍 [CANCEL_DEBUG]   - 원본 is_cancel 값: 1 (타입: int)
🔍 [CANCEL_DEBUG]   - 생성된 객체의 isCancelRequest: true
```

**비정상 (모델 문제):**
```
🔍 [CANCEL_DEBUG]   - 원본 is_cancel 값: 1 (타입: int)
🔍 [CANCEL_DEBUG]   - 생성된 객체의 isCancelRequest: false  // ❌ 파싱 실패
```

#### 📍 체크포인트 3: UI 렌더링
**정상:**
```
🔍 [CANCEL_DEBUG] isCancelRequest 값: true
🔍 [CANCEL_DEBUG] 취소상신 배지 표시 여부: ✅ 표시됨
```

**비정상 (UI 문제):**
- 로그는 "✅ 표시됨"인데 화면에 배지가 없음

---

## 문제별 해결 방법

### 🔴 문제 A: 서버에서 is_cancel 필드를 보내지 않음
**증상:**
```
🔍 [CANCEL_DEBUG]   - is_cancel: null (타입: Null)
```

**해결:**
백엔드 담당자에게 요청:
- `/leave/user/management` API 응답에 `is_cancel` 필드 추가
- 취소 상신 건은 `is_cancel: 1`, 일반 건은 `is_cancel: 0`

---

### 🟡 문제 B: is_cancel 값이 항상 0
**증상:**
```
🔍 [CANCEL_DEBUG]   - is_cancel: 0 (타입: int)  // 취소상신인데도 0
```

**해결:**
백엔드 버그 - 취소 상신 API가 DB를 업데이트하지 않음
```sql
-- DB 직접 확인
SELECT id, user_id, status, is_cancel
FROM leave_requests
WHERE id = 123;
```

---

### 🟢 문제 C: 앱에서 파싱 실패
**증상:**
```
🔍 [CANCEL_DEBUG]   - 원본 is_cancel 값: 1 (타입: int)
🔍 [CANCEL_DEBUG]   - 생성된 객체의 isCancelRequest: false
```

**해결:**
모델 코드 확인 (현재는 정상이므로 발생 가능성 낮음)

---

### 🔵 문제 D: UI에 배지가 안 보임 (로그는 정상)
**증상:**
- 로그: `취소상신 배지 표시 여부: ✅ 표시됨`
- 화면: 배지가 보이지 않음

**해결:**
임시로 `if (true)`로 변경해서 UI 렌더링 확인

---

## 예상 정상 로그 전체 흐름

```
// ========== API 응답 ==========
🔍 ========== [CANCEL_DEBUG] 서버 응답 분석 시작 ==========
🔍 [CANCEL_DEBUG] yearlyDetails 개수: 3개
🔍 [CANCEL_DEBUG] === 휴가 항목 #1 ===
🔍 [CANCEL_DEBUG]   - id: 123
🔍 [CANCEL_DEBUG]   - leave_type: 연차
🔍 [CANCEL_DEBUG]   - status: REQUESTED
🔍 [CANCEL_DEBUG]   - is_cancel: 1 (타입: int)
🔍 [CANCEL_DEBUG]   - start_date: 2024-01-15
🔍 [CANCEL_DEBUG]   ⭐⭐⭐ 취소상신 건 발견! ⭐⭐⭐
🔍 ========== [CANCEL_DEBUG] 서버 응답 분석 종료 ==========

// ========== 모델 파싱 ==========
🔍 [CANCEL_DEBUG] YearlyDetail.fromJson 시작
🔍 [CANCEL_DEBUG]   - 원본 is_cancel 값: 1 (타입: int)
🔍 [CANCEL_DEBUG]   - 파싱된 isCancel 값: 1 (타입: int)
🔍 [CANCEL_DEBUG]   - 생성된 객체의 isCancel: 1
🔍 [CANCEL_DEBUG]   - 생성된 객체의 isCancelRequest: true
🔍 [CANCEL_DEBUG]   ⭐⭐⭐ 취소상신 객체 생성됨! (ID: 123) ⭐⭐⭐

// ========== 리스트 필터링 ==========
🔍 [CANCEL_DEBUG] ========== 리스트 필터링 상태 ==========
📊 전체 휴가내역: 3개
📊 필터링된 휴가내역: 3개
📊 취소건 숨김 상태: false
🔍 [CANCEL_DEBUG] === 전체 항목 is_cancel 값 확인 ===
🔍 [CANCEL_DEBUG] 항목 #1: ID=123, status=REQUESTED, isCancel=1, isCancelRequest=true
🔍 [CANCEL_DEBUG]   ⭐⭐⭐ 취소상신 발견! ⭐⭐⭐
🔍 [CANCEL_DEBUG] ========================================

// ========== UI 렌더링 ==========
🔍 [CANCEL_DEBUG] ========== UI 렌더링 시작 ==========
🔍 [CANCEL_DEBUG] 휴가 항목 ID: 123
🔍 [CANCEL_DEBUG] leave_type: 연차
🔍 [CANCEL_DEBUG] status: REQUESTED
🔍 [CANCEL_DEBUG] isCancel 값: 1
🔍 [CANCEL_DEBUG] isCancelRequest 값: true
🔍 [CANCEL_DEBUG] 취소상신 배지 표시 여부: ✅ 표시됨
🔍 [CANCEL_DEBUG] ⭐⭐⭐ 취소상신 배지가 화면에 표시되어야 합니다! ⭐⭐⭐
🔍 [CANCEL_DEBUG] ========== UI 렌더링 종료 ==========
```

---

## 로그 제거 방법

테스트 완료 후 로그를 제거하려면:

### 자동 제거 (추천)
```bash
# [CANCEL_DEBUG] 로그가 포함된 모든 라인 찾기
grep -r "CANCEL_DEBUG" lib/
```

### 수동 제거
1. `lib/shared/services/leave_api_service.dart` (line 53-73)
2. `lib/models/leave_management_models.dart` (line 160-188)
3. `lib/ui/screens/leave_management_screen.dart` (line 879-895, 1803-1814)

각 파일에서 `// 🔍 [CANCEL_DEBUG]` 주석이 포함된 블록 삭제

---

## 다음 단계

1. ✅ **앱 실행:** `flutter run -d windows`
2. ✅ **휴가관리 화면 진입**
3. ✅ **콘솔 로그 확인**
4. ✅ **문제 지점 파악**
5. 📩 **서버 팀에 요청 또는 직접 수정**

**Good Luck!** 🍀
