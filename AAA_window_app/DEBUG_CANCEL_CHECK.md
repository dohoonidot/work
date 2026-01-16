# 취소상신 배지 표시 안 되는 문제 진단 가이드

## 1. 앱 로그 확인

### 실행 명령
```bash
cd /mnt/c/AI_Agent/AI_Agent/Agent_APP/Desktop_App_amqp_beforeLog
flutter run -d windows
```

### 확인할 로그

#### A. API 응답 확인
휴가관리 화면 진입 시 다음 로그를 찾으세요:
```
🔍 [LeaveApiService] 관리자 관리 데이터 API 요청 시작
🔍 [LeaveApiService] 응답 바디: {...}
```

#### B. 데이터 파싱 확인
```
📊 전체 휴가내역: X개
📊 첫 번째 항목 상태: REQUESTED
```

#### C. is_cancel 필드 확인
응답 JSON에서 찾아야 할 내용:
```json
{
  "yearlyDetails": [
    {
      "id": 123,
      "leave_type": "연차",
      "start_date": "2024-01-15",
      "end_date": "2024-01-16",
      "status": "REQUESTED",
      "is_cancel": 1,  // ⭐ 이 필드가 있어야 함!
      ...
    }
  ]
}
```

---

## 2. 서버 데이터 확인 (백엔드 담당자 요청)

### 확인 사항
1. **취소 상신 건이 DB에 제대로 저장되어 있는가?**
   - `leave_requests` 테이블의 `is_cancel` 컬럼 값 확인

2. **API가 `is_cancel` 필드를 반환하는가?**
   - `/leave/user/management` 엔드포인트
   - `/leave/admin/management` 엔드포인트

### Postman/cURL 테스트
```bash
curl -X POST https://ai2great.com:8060/leave/user/management \
  -H "Content-Type: application/json" \
  -d '{"user_id": "테스트사용자ID"}'
```

**예상 응답:**
```json
{
  "yearlyDetails": [
    {
      "id": 1,
      "status": "REQUESTED",
      "is_cancel": 1,  // 취소 상신
      ...
    },
    {
      "id": 2,
      "status": "APPROVED",
      "is_cancel": 0,  // 일반 상신
      ...
    }
  ]
}
```

---

## 3. 테스트 시나리오

### A. 새로운 취소 상신 생성
1. 승인된 휴가 1건 선택
2. "취소 상신" 버튼 클릭
3. 취소 사유 입력 후 상신
4. **콘솔 로그 확인:**
   ```
   휴가 취소 상신 API 요청 URL: https://ai2great.com:8060/leave/user/cancel/request
   휴가 취소 상신 API 요청 바디: {"id":123,"user_id":"user001","reason":"개인 사정"}
   휴가 취소 상신 응답 상태 코드: 200
   ```

### B. 휴가관리 화면 새로고침
1. 화면 닫았다가 다시 열기
2. **개인별 휴가 내역**에서 해당 항목 찾기
3. **확인해야 할 것:**
   - 상태 배지: "승인 대기" (주황색)
   - 취소상신 배지: "🚫 취소 상신" (빨간색) ⭐ **이게 보여야 정상!**

---

## 4. 문제별 해결 방법

### 문제 A: 서버에서 is_cancel 필드를 안 보냄
**증상:** 로그에 `"is_cancel"` 필드가 없음

**해결:** 백엔드 개발자에게 요청
```python
# Python/FastAPI 예시
def get_leave_management(user_id: str):
    leaves = db.query(LeaveRequest).filter_by(user_id=user_id).all()
    return {
        "yearlyDetails": [
            {
                ...
                "is_cancel": leave.is_cancel,  # ⭐ 이 필드 추가 필요
            }
            for leave in leaves
        ]
    }
```

### 문제 B: is_cancel 값이 항상 0
**증상:** 취소 상신했는데 `is_cancel: 0`으로 옴

**해결:** 취소 상신 API가 DB를 제대로 업데이트하지 않음
```sql
-- DB 직접 확인
SELECT id, user_id, status, is_cancel
FROM leave_requests
WHERE id = 123;

-- is_cancel이 0이면 백엔드 버그
-- 취소 상신 시 is_cancel = 1로 업데이트되어야 함
```

### 문제 C: 앱에서 is_cancel 파싱 안 됨
**증상:** 서버는 보내는데 앱에서 인식 못함

**해결:** 모델 확인 (현재 코드는 정상이므로 발생 가능성 낮음)
```dart
// lib/models/leave_management_models.dart
factory YearlyDetail.fromJson(Map<String, dynamic> json) {
  return YearlyDetail(
    ...
    isCancel: json['is_cancel'] ?? 0,  // ✅ 이미 구현됨
  );
}
```

---

## 5. 빠른 검증 방법

### Option 1: 하드코딩 테스트
임시로 코드를 수정해서 배지가 보이는지 확인:

```dart
// lib/ui/screens/leave_management_screen.dart:1861
// 기존:
if (detail.isCancelRequest) ...[

// 임시 변경:
if (true) ...[  // ⭐ 모든 항목에 배지 표시
```

**결과:**
- 배지가 보임 → 서버 데이터 문제
- 배지가 안 보임 → UI 렌더링 문제

### Option 2: 로그 추가
```dart
// lib/ui/screens/leave_management_screen.dart:1800
Widget _buildYearlyDetailItem(YearlyDetail detail) {
  // ⭐ 디버그 로그 추가
  print('🔍 [DEBUG] ID: ${detail.id}');
  print('🔍 [DEBUG] 상태: ${detail.status}');
  print('🔍 [DEBUG] is_cancel 값: ${detail.isCancel}');
  print('🔍 [DEBUG] isCancelRequest: ${detail.isCancelRequest}');

  ...
}
```

---

## 6. 예상 결과

### 정상 동작 시
```
📱 휴가관리 화면 > 개인별 휴가 내역

┌─────────────────────────────────────┐
│ [승인 대기] [🚫 취소 상신] 연차       │
│ 2024-01-15 ~ 2024-01-16 (1일)       │
│ 사유: 개인 사정                      │
└─────────────────────────────────────┘
```

### 비정상 시
```
📱 휴가관리 화면 > 개인별 휴가 내역

┌─────────────────────────────────────┐
│ [승인 대기] 연차                     │  ⚠️ 취소상신 배지 없음
│ 2024-01-15 ~ 2024-01-16 (1일)       │
│ 사유: 개인 사정                      │
└─────────────────────────────────────┘
```

---

## 요약

**UI 코드는 완벽합니다.** 문제는 다음 중 하나:

1. ⭐ **서버가 `is_cancel` 필드를 안 보냄** (가장 유력)
2. 서버가 `is_cancel: 0`을 보냄 (DB 업데이트 안 됨)
3. API 응답 형식이 다름

**다음 단계:**
1. `flutter run -d windows` 실행
2. 휴가관리 화면 열기
3. 콘솔 로그에서 `is_cancel` 필드 확인
4. 없으면 → 백엔드 수정 요청
5. 있는데 0이면 → 취소 상신 API 버그
