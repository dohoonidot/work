# React Web Client용 SSE 알림 구현 가이드

이 문서는 “React(브라우저) 클라이언트에서 SSE 알림을 안정적으로 수신/처리/ACK”하기 위한 작업 지시서입니다.
코딩 에이전트가 그대로 구현 작업을 진행할 수 있도록 **서버 계약 요약 + 단계별 업무**로 정리했습니다.

---

## 1) 서버 계약 요약(프론트가 반드시 맞춰야 하는 부분)

### 1.1 구독/ACK 엔드포인트 + 인증
- 구독(SSE): `GET /sse/notifications`
- ACK(처리 완료): `POST /sse/notifications/ack`
- 인증: **`session_id` 쿠키 기반**
  - 서버는 SSE 요청에서 `user_id`를 받지 않습니다.
  - 서버는 `session_id` → (Redis) `userId`로 사용자를 확정합니다.
  - 결론: **로그인으로 쿠키가 설정된 뒤에 SSE를 연결**해야 합니다.

추가 제약:
- `EventSource`는 커스텀 헤더를 넣기 어렵습니다. 인증은 **쿠키로만** 처리해야 합니다.
- 프론트/백이 다른 오리진이면 `new EventSource(url, { withCredentials: true })` + 서버 CORS `Allow-Credentials` 설정이 필요합니다.

### 1.2 “어떤 사용자에게 보내는지” 결정 규칙
RabbitMQ publish 훅에서 알림 대상은 **큐/라우팅키 규칙(prefix + userId suffix)** 으로 결정됩니다. (서버: `extractUserIDFromQueueName`)

현재 서버가 인식하는 패턴:
- `leave.approval.{userId}`
- `leave.alert.{userId}`
- `leave.cc.{userId}`
- `leave.draft.{userId}`
- `eapproval.alert.{userId}`
- `eapproval.cc.{userId}`
- `eapproval.{userId}`
- `alert.{userId}`

또한 `queue_name` 결정 규칙:
- 일반 케이스: `queue_name = routingKey`
- `routingKey == ""`이면: `queue_name = exchange`

### 1.3 SSE `event:`(이벤트 타입) 결정 규칙
기본적으로 `queue_name` prefix로 SSE의 `event:` 값이 결정됩니다. (서버: `deriveEventType`)

| queue_name prefix | SSE `event:` (기본) |
|---|---|
| `leave.approval.` | `leave_approval` |
| `leave.alert.` | `leave_alert` |
| `leave.cc.` | `leave_cc` |
| `leave.draft.` | `leave_draft` |
| `eapproval.alert.` | `eapproval_alert` |
| `eapproval.cc.` | `eapproval_cc` |
| `eapproval.` | `eapproval_approval` |
| `alert.` | `alert` |
| (그 외) | `notification` |

중요:
- RabbitMQ publish 시 **헤더 `render_type`가 있으면 그것이 최종 `event:`로 우선**됩니다.
  - 예: `render_type = "contest_detail"`이면 SSE 이벤트 타입도 `contest_detail`
- 결론: 프론트는 **“SSE 프레임의 `event:` 값(e.type)”을 기준으로 라우팅**해야 하며, `queue_name` prefix 추정은 디버깅 보조로만 사용합니다.

### 1.4 SSE 데이터 포맷(프론트 파싱 규칙)
서버는 SSE 프레임을 다음처럼 보냅니다.
- `id:`: Redis Stream ID(문자열) → 브라우저 재연결 시 `Last-Event-ID`로 활용
- `event:`: 위 규칙으로 결정된 이벤트 타입
- `data:`: JSON 문자열(“NotificationEnvelope”)

Envelope 스키마(중요 필드):
```json
{
  "event": "leave_approval",
  "user_id": "12345",
  "queue_name": "leave.approval.12345",
  "payload": { "...": "..." },
  "payload_text": "원본이 JSON이 아니면 여기에",
  "sent_at": "2025-01-01T00:00:00.000000000Z",
  "event_id": "1730000000000-0"
}
```

파싱 규칙:
- 1) `JSON.parse(e.data)`로 Envelope를 파싱합니다. (Envelope 자체는 항상 JSON)
- 2) 원본 메시지는:
  - `payload`가 있으면 사용(객체/배열/문자열 등 타입 다양 가능)
  - `payload`가 없고 `payload_text`가 있으면 텍스트로 처리

참고:
- `env.event === e.type`
- `env.event_id === e.lastEventId` (실제로는 같은 값이 내려옵니다)

### 1.5 재연결/누락분 재전송(Last-Event-ID) + ACK 의미
- 브라우저 `EventSource`는 연결이 끊기면 자동 재연결하며, 마지막으로 받은 `id:`를 `Last-Event-ID` 헤더로 전송합니다.
- 서버는 `Last-Event-ID`가 있으면 Redis Stream에서 “그 이후” 이벤트를 재전송합니다.
- `Last-Event-ID`가 없으면(새로고침/새 탭/기기 변경 등) 최근 100개(`notificationsBacklogDefault`)를 먼저 내려줍니다.

ACK는 “읽음 처리”가 아니라 **Redis Stream에서 해당 이벤트를 삭제(처리 완료 = 삭제)** 하는 용도입니다.
- 새로고침 등으로 `Last-Event-ID`가 유지되지 않으면, **ACK를 하지 않은 과거 알림이 다시 내려올 수 있습니다.**

ACK 요청 예시:
```ts
await fetch("/sse/notifications/ack", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  credentials: "include",
  body: JSON.stringify({ event_id: env.event_id }), // 또는 { event_ids: [...] }
});
```

### 1.6 운영/구현 팁(프론트 영향)
- keep-alive: 서버가 20초마다 `: ping`(comment)을 보냅니다. 브라우저는 자동 무시합니다.
- 느린 클라이언트: 서버는 백프레셔 보호를 위해 버퍼가 꽉 차면 해당 커넥션을 드롭합니다.
  - 프론트는 이벤트 핸들러에서 무거운 동기 작업을 피하고, 상태 업데이트만 하고 나머지는 비동기 처리 권장
- 보관 한계: 사용자별 Redis Stream은 대략 500개 보관(초과 시 트림) + TTL 7일

---

## 2) React 구현 업무(단계별)

> 목표: 로그인된 사용자가 React 앱을 사용하는 동안 SSE 알림을 받고, UI에 반영한 뒤 ACK까지 안정적으로 수행한다.

### Step 1 — 오리진/쿠키 전제 정리
작업:
- 프론트에서 `GET /sse/notifications` 요청이 **쿠키를 포함**해서 나가는지 확인합니다.
  - same-origin이면 보통 자동 포함
  - 다른 오리진이면 `withCredentials: true` + 서버 CORS 설정 필요
- 개발 환경이면 가능한 한 **프론트 dev 서버 프록시**로 same-origin처럼 맞추는 것을 권장합니다.

완료 기준:
- Network 탭에서 `/sse/notifications`가 `200` + `text/event-stream`으로 열리고, 401이 나지 않습니다.

### Step 2 — 이벤트 이름/Envelope 타입 정의(권장: TypeScript)
작업:
- 서버 이벤트 타입 목록(기본 + render_type로 쓰는 커스텀 타입)을 한 곳에 모읍니다.
- Envelope 타입(최소 필드)을 정의합니다.

예시:
```ts
export type NotificationEnvelope = {
  event: string;
  user_id: string;
  queue_name: string;
  payload?: unknown;
  payload_text?: string;
  sent_at: string;
  event_id: string;
};

export const SSE_EVENT_NAMES = [
  "leave_approval",
  "leave_alert",
  "leave_cc",
  "leave_draft",
  "eapproval_alert",
  "eapproval_cc",
  "eapproval_approval",
  "alert",
  "notification",
  // render_type로 내려오는 값이 있으면 여기에 추가
  // "contest_detail",
] as const;
```

완료 기준:
- 프론트 코드에서 “SSE 이벤트 타입 목록”이 하드코딩으로 흩어지지 않고, 상수로 관리됩니다.

### Step 3 — ACK API 함수 구현
작업:
- 단건/배치 ACK를 모두 지원하는 함수를 만듭니다.
- `credentials: "include"`를 강제해 쿠키 인증이 항상 적용되도록 합니다.

예시:
```ts
export async function ackSseNotifications(eventIds: string | string[]) {
  const ids = Array.isArray(eventIds) ? eventIds : [eventIds];
  const res = await fetch("/sse/notifications/ack", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    credentials: "include",
    body: JSON.stringify(ids.length === 1 ? { event_id: ids[0] } : { event_ids: ids }),
  });
  if (!res.ok) throw new Error(`ACK failed: ${res.status}`);
}
```

완료 기준:
- `event_id` 1개, 여러 개 모두 정상 삭제(`deleted > 0`) 응답을 받습니다.

### Step 4 — SSE 연결을 담당하는 Hook/Provider 구현
작업(권장 패턴):
- `useEffect`에서 `EventSource`를 생성하고, 언마운트/로그아웃 시 `close()`로 정리합니다.
- 서버는 항상 `event:`를 설정하므로 **`onmessage`만 쓰면 이벤트를 못 받습니다.**
  - 반드시 `addEventListener(eventName, handler)`로 이벤트별 리스너를 등록합니다.
- 핸들러에서는:
  - `JSON.parse(e.data)` → `NotificationEnvelope`
  - UI 상태 업데이트(가볍게)
  - 필요하면 ACK 큐잉/호출

예시(핵심만):
```ts
import { useEffect, useRef } from "react";

export function useSseNotifications(params: {
  enabled: boolean;
  onEnvelope: (env: NotificationEnvelope) => void;
  withCredentials?: boolean;
}) {
  const { enabled, onEnvelope, withCredentials = true } = params;
  const handlerRef = useRef(onEnvelope);
  handlerRef.current = onEnvelope;

  useEffect(() => {
    if (!enabled) return;

    const es = new EventSource("/sse/notifications", { withCredentials });
    const handle = (e: MessageEvent) => {
      const env = JSON.parse(e.data) as NotificationEnvelope;
      handlerRef.current(env);
    };

    SSE_EVENT_NAMES.forEach((name) => es.addEventListener(name, handle));
    es.onerror = () => {
      // EventSource는 자동 재연결하므로 보통 로그/모니터링만 합니다.
    };

    return () => {
      SSE_EVENT_NAMES.forEach((name) => es.removeEventListener(name, handle));
      es.close();
    };
  }, [enabled, withCredentials]);
}
```

완료 기준:
- React 리렌더링/라우트 이동/StrictMode 개발 환경에서도 SSE 커넥션이 누적되지 않고 정리됩니다.
- `leave_approval` 등 이벤트가 실제로 핸들러로 들어옵니다.

### Step 5 — 상태/화면 반영 + ACK 전략 적용
권장 동작:
- “읽음”과 무관하게, **클라이언트가 처리(저장/표시/큐잉) 완료한 시점에 ACK**합니다.
  - 이유: ACK는 “Stream 삭제(재전송 방지)” 의미이며, 읽음 처리와 다릅니다.

구현 옵션:
- (단순) 알림을 전역 상태에 추가한 직후 `ackSseNotifications(env.event_id)` 호출
- (권장) ACK를 메모리 큐에 쌓고 N초/최대 N개마다 배치로 전송(실패 시 재시도)

완료 기준:
- 새로고침해도 이미 처리한 알림이 반복으로 쏟아지지 않습니다(ACK가 정상 동작).

### Step 6 — 통합 체크리스트(수용 기준)
- 로그인 직후 SSE 연결이 열리고 401이 나지 않습니다.
- `onmessage` 없이도 이벤트를 수신합니다(`addEventListener` 기반).
- 이벤트 타입 추가(render_type 포함) 시 `SSE_EVENT_NAMES`에 반영하지 않으면 수신이 안 된다는 점이 문서/코드로 명확합니다.
- ACK 실패 시에도 앱이 크래시하지 않고(try/catch), 재시도하거나 다음 기회에 처리합니다.
- 이벤트 핸들러에서 무거운 동기 작업을 하지 않습니다(서버 드롭 방지).

---

## 3) 자주 하는 실수(React에서 특히)
- `es.onmessage`만 등록: 서버가 항상 `event:`를 넣기 때문에 **아무것도 못 받습니다**.
- `useEffect` 의존성 관리 실패: 리렌더마다 EventSource가 새로 생겨 **중복 수신**이 발생합니다.
- 로그아웃/언마운트에서 `es.close()` 누락: 서버/브라우저 모두 리소스 누수 및 중복 수신 가능.
- cross-origin에서 쿠키 미전송: `withCredentials`/CORS/쿠키 SameSite 속성을 함께 점검해야 합니다.
