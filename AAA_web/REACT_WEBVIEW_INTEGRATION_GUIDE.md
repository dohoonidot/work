# React 양식을 웹뷰로 통합하는 단계별 가이드

## 📋 전체 단계 요약

1. **React 앱 개발 및 배포** → URL 확보
2. **Flutter 코드에서 URL 매핑** → 각 결재 종류별 URL 설정
3. **웹뷰 위젯에 URL 전달** → 자동 처리됨
4. **URL 패턴 제한 설정** (선택) → 보안 강화
5. **테스트 및 검증**

---

## 1단계: React 앱 개발 및 배포

### 작업 내용
- React로 전자결재 양식 개발
- 각 계약서 양식별로 별도 페이지/라우트 구성
- 빌드 후 서버에 배포하여 URL 확보

### 예시 URL 구조
```
http://210.107.96.193:9999/pages/contract-approval-form.html      (매출/매입계약)
http://210.107.96.193:9999/pages/purchase-request-form.html      (구매신청서)
http://210.107.96.193:9999/pages/education-request-form.html     (교육신청서)
http://210.107.96.193:9999/pages/event-expense-form.html         (경조사비)
```

### React 앱 요구사항
- ✅ 웹뷰에서 정상 작동 (반응형 디자인)
- ✅ 제출 버튼 내부에 포함 (React에서 직접 API 호출)
- ✅ CORS 설정 (필요시)
- ✅ 모바일/데스크톱 환경 테스트

---

## 2단계: Flutter 코드에서 URL 매핑 설정

### 현재 코드 위치
**파일**: `lib/features/approval/common_electronic_approval_modal.dart`
**메서드**: `_buildApprovalDetailFields()` (473-502줄)

### 작업 방법

#### 방법 1: 직접 switch 문에 추가 (간단)

```dart
Widget _buildApprovalDetailFields() {
  switch (_selectedApprovalType) {
    case '매출/매입계약 기안서':
      return _buildApprovalDetailWebView(
        webUrl: 'http://210.107.96.193:9999/pages/contract-approval-form.html',
        allowedUrlPatterns: [
          'contract-approval-form.html',
          '/pages/contract-approval-form',
        ],
      );
    
    // ✅ 여기에 새로운 케이스 추가
    case '구매신청서':
      return _buildApprovalDetailWebView(
        webUrl: 'http://210.107.96.193:9999/pages/purchase-request-form.html',
        allowedUrlPatterns: [
          'purchase-request-form.html',
          '/pages/purchase-request',
        ],
      );
    
    case '교육신청서':
      return _buildApprovalDetailWebView(
        webUrl: 'http://210.107.96.193:9999/pages/education-request-form.html',
        allowedUrlPatterns: [
          'education-request-form.html',
          '/pages/education-request',
        ],
      );
    
    case '경조사비 지급신청서':
      return _buildApprovalDetailWebView(
        webUrl: 'http://210.107.96.193:9999/pages/event-expense-form.html',
        allowedUrlPatterns: [
          'event-expense-form.html',
          '/pages/event-expense',
        ],
      );
    
    // 기존 위젯은 그대로 유지
    case '기본양식':
      return _buildBasicApprovalDetail();
    
    case '휴가 부여 상신':
      return _buildLeaveGrantApprovalDetail();
    
    default:
      return _buildDefaultDetail();
  }
}
```

#### 방법 2: URL 매핑 맵 사용 (권장 - 유지보수 용이)

```dart
// 클래스 상단에 추가
static const Map<String, Map<String, dynamic>> _approvalFormUrls = {
  '매출/매입계약 기안서': {
    'url': 'http://210.107.96.193:9999/pages/contract-approval-form.html',
    'patterns': ['contract-approval-form.html', '/pages/contract-approval-form'],
  },
  '구매신청서': {
    'url': 'http://210.107.96.193:9999/pages/purchase-request-form.html',
    'patterns': ['purchase-request-form.html', '/pages/purchase-request'],
  },
  '교육신청서': {
    'url': 'http://210.107.96.193:9999/pages/education-request-form.html',
    'patterns': ['education-request-form.html', '/pages/education-request'],
  },
  '경조사비 지급신청서': {
    'url': 'http://210.107.96.193:9999/pages/event-expense-form.html',
    'patterns': ['event-expense-form.html', '/pages/event-expense'],
  },
};

Widget _buildApprovalDetailFields() {
  // URL 매핑이 있으면 웹뷰 사용
  if (_approvalFormUrls.containsKey(_selectedApprovalType)) {
    final config = _approvalFormUrls[_selectedApprovalType]!;
    return _buildApprovalDetailWebView(
      webUrl: config['url'] as String,
      allowedUrlPatterns: (config['patterns'] as List).cast<String>(),
    );
  }
  
  // 기존 위젯 처리
  switch (_selectedApprovalType) {
    case '기본양식':
      return _buildBasicApprovalDetail();
    case '휴가 부여 상신':
      return _buildLeaveGrantApprovalDetail();
    default:
      return _buildDefaultDetail();
  }
}
```

---

## 3단계: 웹뷰 위젯에 URL 전달 (자동 처리)

### 동작 방식
1. `_buildApprovalDetailWebView()` 호출 시 `webUrl` 전달
2. `_ApprovalDetailWebViewWidget` 위젯이 자동으로:
   - 웹뷰 초기화
   - URL 로드
   - 로딩 상태 표시
   - 에러 처리

### 코드 위치
- **메서드**: `_buildApprovalDetailWebView()` (558줄)
- **위젯**: `_ApprovalDetailWebViewWidget` (2881줄)

### 추가 작업 불필요
- ✅ 웹뷰 초기화: 자동
- ✅ URL 로드: 자동
- ✅ 로딩 인디케이터: 자동
- ✅ 에러 처리: 자동

---

## 4단계: URL 패턴 제한 설정 (선택)

### 목적
웹뷰 내에서 허용된 페이지만 접근 가능하도록 제한

### 설정 방법
```dart
allowedUrlPatterns: [
  'contract-approval-form.html',    // 정확한 파일명
  '/pages/contract-approval-form',  // 경로 패턴
  'contract',                       // 'contract' 포함된 모든 URL
]
```

### 동작 방식
- 허용된 패턴과 일치하는 URL만 접근 가능
- 허용되지 않은 URL로 이동 시도 시 자동으로 원래 URL로 복귀

---

## 5단계: 테스트 및 검증

### 체크리스트

#### 기본 기능
- [ ] 각 결재 종류 선택 시 해당 React 앱이 웹뷰에 표시되는가?
- [ ] 로딩 인디케이터가 정상 작동하는가?
- [ ] 에러 발생 시 재시도 버튼이 작동하는가?

#### URL 제한
- [ ] 허용된 URL만 접근 가능한가?
- [ ] 허용되지 않은 URL로 이동 시도 시 차단되는가?

#### React 앱 기능
- [ ] React 앱 내부 입력 필드가 정상 작동하는가?
- [ ] 제출 버튼이 정상 작동하는가?
- [ ] API 호출이 정상 작동하는가?

#### UX
- [ ] 다크 모드에서도 정상 표시되는가?
- [ ] 반응형 레이아웃이 정상 작동하는가?
- [ ] 스크롤이 정상 작동하는가?

---

## 📝 실제 적용 예시

### 예시 1: 구매신청서 추가

```dart
case '구매신청서':
  return _buildApprovalDetailWebView(
    webUrl: 'http://210.107.96.193:9999/pages/purchase-request-form.html',
    allowedUrlPatterns: [
      'purchase-request-form.html',
      '/pages/purchase-request',
    ],
  );
```

### 예시 2: 교육신청서 추가

```dart
case '교육신청서':
  return _buildApprovalDetailWebView(
    webUrl: 'http://210.107.96.193:9999/pages/education-request-form.html',
    allowedUrlPatterns: [
      'education-request-form.html',
      '/pages/education-request',
    ],
  );
```

---

## 🔧 문제 해결

### 문제 1: 웹뷰가 표시되지 않음
- **원인**: URL이 잘못되었거나 서버가 응답하지 않음
- **해결**: 
  1. 브라우저에서 URL 직접 접근 테스트
  2. CORS 설정 확인
  3. 콘솔 로그 확인

### 문제 2: React 앱이 로드되지 않음
- **원인**: React 앱 빌드 문제 또는 경로 오류
- **해결**:
  1. React 앱 빌드 확인 (`npm run build`)
  2. 서버 배포 경로 확인
  3. 브라우저 개발자 도구로 네트워크 오류 확인

### 문제 3: URL 제한이 작동하지 않음
- **원인**: 패턴 매칭 로직 문제
- **해결**:
  1. `allowedUrlPatterns` 값 확인
  2. 콘솔 로그로 차단 메시지 확인
  3. 패턴을 더 구체적으로 지정

---

## 📌 요약

1. **React 앱 개발** → 서버 배포 → URL 확보
2. **Flutter 코드 수정** → `_buildApprovalDetailFields()`에 케이스 추가
3. **URL 매핑** → 각 결재 종류별 URL 설정
4. **테스트** → 각 양식별로 정상 작동 확인

**핵심**: URL만 넣으면 바로 적용됩니다! 🚀

