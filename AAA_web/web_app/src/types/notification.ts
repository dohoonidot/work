/**
 * SSE 알림 관련 타입 정의
 * SSE_NOTES.md 기반으로 구현
 */

/**
 * SSE 알림 Envelope 타입
 * 서버에서 SSE 프레임의 data 필드로 전송되는 JSON 구조
 */
export interface NotificationEnvelope {
  /** 이벤트 타입 (SSE의 event: 필드와 동일) */
  event: string;
  /** 사용자 ID */
  user_id: string;
  /** RabbitMQ 큐 이름 */
  queue_name: string;
  /** 메시지 페이로드 (JSON 파싱된 객체) */
  payload?: unknown;
  /** 메시지 페이로드 (원본이 JSON이 아닌 경우 텍스트) */
  payload_text?: string;
  /** 전송 시각 (ISO 8601 형식) */
  sent_at: string;
  /** 이벤트 ID (Redis Stream ID, ACK 시 사용) */
  event_id: string;
}

/**
 * SSE 이벤트 타입 목록
 * 서버가 보내는 모든 이벤트 타입을 여기에 등록해야 수신 가능
 */
export const SSE_EVENT_NAMES = [
  // 휴가 관련
  'leave_approval',   // 휴가 승인 요청
  'leave_alert',      // 휴가 알림
  'leave_cc',         // 휴가 참조
  'leave_draft',      // 휴가 임시저장

  // 전자결재 관련
  'eapproval_alert',    // 전자결재 알림
  'eapproval_cc',       // 전자결재 참조
  'eapproval_approval', // 전자결재 승인

  // 일반 알림
  'alert',              // 일반 알림
  'notification',       // 기본 알림

  // render_type으로 내려오는 커스텀 이벤트
  'contest_detail',     // 공모전 상세 알림
  'birthday',           // 생일 알림
  
  // 선물 관련
  'gift',               // 선물 도착 알림
  'gift_arrival',       // 선물 도착 알림 (별칭)
] as const;

/**
 * SSE 이벤트 타입 (Union 타입)
 */
export type SseEventType = typeof SSE_EVENT_NAMES[number];

/**
 * 알림 표시용 데이터
 * UI에서 사용하는 형식
 */
export interface NotificationDisplay {
  /** 고유 ID (event_id와 동일) */
  id: string;
  /** 이벤트 타입 */
  type: string;
  /** 큐 이름 (leave.analyze 등) */
  queue_name: string;
  /** 제목 */
  title: string;
  /** 메시지 내용 */
  message: string;
  /** 페이로드 원본 */
  payload?: unknown;
  /** 수신 시각 */
  receivedAt: Date;
  /** 읽음 여부 */
  read: boolean;
  /** 클릭 시 이동할 경로 (optional) */
  link?: string;
}

/**
 * ACK 요청 바디 (단건)
 */
export interface AckSingleRequest {
  event_id: string;
}

/**
 * ACK 요청 바디 (배치)
 */
export interface AckBatchRequest {
  event_ids: string[];
}

/**
 * ACK 응답
 */
export interface AckResponse {
  deleted: number;
  message?: string;
}

/**
 * 알림함 관련 타입 정의
 * /queue/checkAlerts, /queue/updateAlerts, /queue/deleteAlerts API 사용
 */

/**
 * 알림함 알림 아이템
 */
export interface AlertItem {
  /** 알림 ID */
  id: number;
  /** 큐 이름 (birthday, gift, alert, event 등) */
  queue_name: string;
  /** 알림 메시지 */
  message: string;
  /** 전송 시각 (YYYY-MM-DD HH:mm:ss) */
  send_time: string;
  /** 읽음 여부 */
  is_read: boolean;
  /** 삭제 여부 */
  is_deleted: boolean;
}

/**
 * 알림 목록 조회 요청
 */
export interface CheckAlertsRequest {
  user_id: string;
}

/**
 * 알림 목록 조회 응답
 */
export interface CheckAlertsResponse {
  alerts: AlertItem[];
  error?: string;
}

/**
 * 알림 읽음 처리 요청
 */
export interface UpdateAlertRequest {
  id: number;
  user_id: string;
}

/**
 * 알림 읽음 처리 응답
 */
export interface UpdateAlertResponse {
  alerts: AlertItem[];
  error?: string;
}

/**
 * 알림 삭제 요청
 */
export interface DeleteAlertRequest {
  id: number;
  user_id: string;
}

/**
 * 알림 삭제 응답
 */
export interface DeleteAlertResponse {
  alerts: AlertItem[];
  error?: string;
}
