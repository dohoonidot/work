# SSE 알림 시스템 구현 완료

## 개요
React 웹앱에 Flutter 앱의 AMQP 알림과 동일한 기능을 SSE(Server-Sent Events)로 구현했습니다.

## 구현된 파일 목록

### 1. 타입 정의
- **`src/types/notification.ts`**
  - `NotificationEnvelope`: SSE 서버에서 받는 데이터 구조
  - `NotificationDisplay`: UI에 표시할 알림 데이터 구조
  - `SSE_EVENT_NAMES`: 서버가 보내는 모든 이벤트 타입 목록
  - ACK 요청/응답 타입

### 2. 서비스
- **`src/services/sseService.ts`**
  - `ackSseNotifications()`: ACK API 호출 함수
  - `AckQueue`: ACK 배치 처리 큐 (10개 또는 5초마다 자동 플러시)
  - `SseConnection`: SSE 연결 관리 클래스
  - `SseConnectionState`: 연결 상태 enum

### 3. React Hook
- **`src/hooks/useSseNotifications.ts`**
  - SSE 연결 생성 및 정리
  - 이벤트 타입별 리스너 자동 등록
  - 알림 수신 시 콜백 호출
  - 연결 상태 관리

### 4. 상태 관리 (Zustand)
- **`src/store/notificationStore.ts`**
  - 알림 목록 저장 (최대 100개)
  - 읽음/안읽음 상태 관리
  - SSE 연결 상태 동기화
  - localStorage에 persist (새로고침 시에도 유지)

### 5. UI 컴포넌트
- **`src/components/common/NotificationPanel.tsx`**
  - `NotificationButton`: 헤더에 배치할 알림 아이콘 버튼 (배지 포함)
  - `NotificationPanel`: 알림 목록을 표시하는 Drawer

### 6. 통합
- **`src/App.tsx`**
  - SSE 연결 초기화 (로그인 시 자동 활성화)
  - 알림 수신 핸들러
  - ACK 큐 자동 처리
  - 특정 이벤트는 Snackbar로도 표시

- **`src/pages/ChatPage.tsx`**
  - 모바일 헤더에 NotificationButton 추가

## 주요 기능

### 1. 자동 연결 관리
- **로그인 시**: SSE 연결 자동 시작
- **로그아웃 시**: SSE 연결 자동 종료
- **자동 재연결**: EventSource의 기본 재연결 기능 활용

### 2. 이벤트 처리
서버에서 보내는 모든 이벤트 타입 지원:
- `leave_approval`, `leave_alert`, `leave_cc`, `leave_draft`
- `eapproval_approval`, `eapproval_alert`, `eapproval_cc`
- `alert`, `notification`
- `contest_detail`, `birthday`

### 3. ACK (처리 완료 알림)
- **자동 ACK**: 알림 수신 즉시 ACK 큐에 추가
- **배치 처리**: 10개 또는 5초마다 자동으로 서버에 전송
- **중복 방지**: 이미 ACK한 알림은 새로고침 시 재전송 안 됨

### 4. UI 기능
- **배지 표시**: 읽지 않은 알림 개수 표시
- **알림 패널**: 클릭 시 Drawer로 알림 목록 표시
- **읽음 처리**: 알림 클릭 시 자동 읽음 처리
- **링크 이동**: 알림 클릭 시 관련 페이지로 이동
- **일괄 삭제**: 모든 알림 삭제 기능
- **일괄 읽음**: 모든 알림 읽음 처리 기능

### 5. 데이터 영속성
- **localStorage**: 알림 목록을 localStorage에 저장
- **새로고침 대응**: 페이지 새로고침해도 알림 유지
- **최대 100개**: 오래된 알림은 자동 삭제

## API 엔드포인트

### SSE 구독
```
GET https://ai2great.com:8060/sse/notifications
```
- 인증: `session_id` 쿠키 기반
- 응답: `text/event-stream`

### ACK (처리 완료)
```
POST https://ai2great.com:8060/sse/notifications/ack
Content-Type: application/json

// 단건
{
  "event_id": "1730000000000-0"
}

// 배치
{
  "event_ids": ["1730000000000-0", "1730000000001-0", ...]
}
```

## 사용 방법

### 1. 개발 환경에서 테스트

```bash
cd web_app
npm install  # date-fns 등 필요한 패키지 설치
npm run dev
```

### 2. 로그인 후 확인 사항

#### 콘솔 로그 확인
- `[App] SSE 알림 수신:` - 알림 수신 시
- `[App] SSE 연결 상태:` - 연결 상태 변경 시
- `[SSE AckQueue] N개 이벤트 ACK 완료` - ACK 성공 시

#### Network 탭 확인
- `/sse/notifications` - 연결 유지 (Pending 상태)
- `/sse/notifications/ack` - ACK 요청 (주기적으로 발생)

#### UI 확인
- 우측 상단에 알림 아이콘 (빨간 배지에 개수 표시)
- 클릭 시 알림 패널 열림

### 3. 알림 테스트 방법

#### 서버에서 알림 발송
서버에서 RabbitMQ를 통해 다음 형식으로 알림 발송:

```python
# 예시: 휴가 승인 알림
await channel.default_exchange.publish(
    Message(
        body=json.dumps({
            "requester": "홍길동",
            "type": "annual_leave",
            "days": 2
        }).encode(),
        headers={"render_type": "leave_approval"}  # 선택적
    ),
    routing_key=f"leave.approval.{user_id}"
)

# 예시: 생일 알림
await channel.default_exchange.publish(
    Message(
        body=json.dumps({
            "name": "홍길동",
            "date": "2025-12-17"
        }).encode(),
        headers={"render_type": "birthday"}
    ),
    routing_key=f"alert.{user_id}"
)
```

## 주의사항

### 1. 쿠키 기반 인증
- SSE는 `session_id` 쿠키로 인증합니다
- 로그인 API가 `session_id` 쿠키를 설정해야 합니다
- CORS 설정 필요 (다른 오리진인 경우)

### 2. 이벤트 타입 추가 시
새로운 이벤트 타입을 추가하려면 다음 파일 수정 필요:

1. **`src/types/notification.ts`**
   ```ts
   export const SSE_EVENT_NAMES = [
     // ... 기존 이벤트들
     'new_event_type',  // 새 이벤트 추가
   ] as const;
   ```

2. **`src/store/notificationStore.ts`**
   ```ts
   function envelopeToDisplay(envelope: NotificationEnvelope): NotificationDisplay {
     // ...
     switch (envelope.event) {
       // ... 기존 케이스들
       case 'new_event_type':
         title = '새 이벤트';
         message = '...';
         link = '/path';
         break;
     }
   }
   ```

### 3. 개발 환경 프록시
`vite.config.ts`에 프록시 설정 추가 권장:

```ts
export default defineConfig({
  server: {
    proxy: {
      '/sse': {
        target: 'https://ai2great.com:8060',
        changeOrigin: true,
        secure: false,
      },
      '/api': {
        target: 'https://ai2great.com:8060',
        changeOrigin: true,
        secure: false,
      },
    },
  },
});
```

## 트러블슈팅

### 1. SSE 연결이 안 되는 경우
- 쿠키가 제대로 전송되는지 확인 (Network 탭)
- CORS 설정 확인
- 서버 로그에서 인증 실패 확인

### 2. 알림이 수신되지 않는 경우
- `SSE_EVENT_NAMES`에 이벤트 타입이 등록되어 있는지 확인
- 서버에서 올바른 `routing_key`로 발송하는지 확인
- 콘솔에 에러 메시지가 있는지 확인

### 3. ACK가 전송되지 않는 경우
- Network 탭에서 `/sse/notifications/ack` 요청 확인
- 쿠키 인증이 포함되어 있는지 확인
- 콘솔에서 ACK 실패 로그 확인

## 참고 자료
- **SSE_NOTES.md**: SSE 구현 가이드 (서버 계약 포함)
- **Flutter AMQP 구현**: `lib/services/amqp_service.dart`
- **Flutter 알림 관리**: `lib/provider/notification_notifier.dart`
