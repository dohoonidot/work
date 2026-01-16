/**
 * 통합 실시간 알림 서비스
 *
 * 플랫폼에 상관없이 동일한 인터페이스로 실시간 알림을 처리하기 위한 추상화 레이어
 * - Flutter: AMQP 기반 구현
 * - React: SSE 기반 구현
 *
 * 주요 기능:
 * - SSE 연결 관리 (자동 재연결 포함)
 * - ACK(처리 완료 알림) API
 * - 쿠키 기반 인증 (session_id)
 * - 통합 이벤트 처리 인터페이스
 */

import { API_BASE_URL } from '../utils/apiConfig';
import api from './api';
import type { AckSingleRequest, AckBatchRequest, AckResponse } from '../types/notification';
import { createLogger } from '../utils/logger';

const logger = createLogger('SSE Service');

/**
 * 쿠키에서 session_id 추출
 */
function getSessionIdFromCookie(): string | null {
  const match = document.cookie.match(/session_id=([^;]+)/);
  return match ? match[1] : null;
}

/**
 * SSE ACK API - 단건/배치 모두 지원
 *
 * @param eventIds - ACK할 이벤트 ID (단일 문자열 또는 배열)
 * @returns ACK 응답 (삭제된 개수)
 */
export async function ackSseNotifications(
  eventIds: string | string[]
): Promise<AckResponse> {
  const ids = Array.isArray(eventIds) ? eventIds : [eventIds];

  // 빈 배열이면 아무것도 하지 않음
  if (ids.length === 0) {
    return { deleted: 0, message: 'No event IDs to acknowledge' };
  }

  // 단건/배치에 따라 요청 바디 구성
  const body: AckSingleRequest | AckBatchRequest =
    ids.length === 1
      ? { event_id: ids[0] }
      : { event_ids: ids };

  try {
    // axios 인스턴스 사용 (withCredentials: true 설정됨)
    // 추가로 session_id를 헤더로도 전송
    const sessionId = getSessionIdFromCookie();
    const response = await api.post<AckResponse>('/sse/notifications/ack', body, {
      headers: sessionId ? { 'X-Session-Id': sessionId } : {},
    });

    return response.data;
  } catch (error) {
    logger.error('ACK 실패', error);
    throw error;
  }
}

/**
 * SSE ACK 배치 처리 큐
 * 여러 ACK를 모아서 한 번에 처리하기 위한 유틸리티
 */
export class AckQueue {
  private queue: Set<string> = new Set();
  private timer: number | null = null;
  private readonly batchSize: number;
  private readonly flushInterval: number; // ms

  /**
   * @param batchSize - 한 번에 처리할 최대 개수 (기본: 10)
   * @param flushInterval - 자동 플러시 간격(ms) (기본: 5000ms = 5초)
   */
  constructor(batchSize = 10, flushInterval = 5000) {
    this.batchSize = batchSize;
    this.flushInterval = flushInterval;
  }

  /**
   * ACK 큐에 이벤트 ID 추가
   */
  add(eventId: string): void {
    this.queue.add(eventId);

    // 배치 크기에 도달하면 즉시 플러시
    if (this.queue.size >= this.batchSize) {
      this.flush();
      return;
    }

    // 타이머가 없으면 설정
    if (!this.timer) {
      this.timer = setTimeout(() => {
        this.flush();
      }, this.flushInterval);
    }
  }

  /**
   * 큐에 쌓인 ACK를 모두 전송
   */
  async flush(): Promise<void> {
    // 타이머 정리
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }

    // 큐가 비어있으면 종료
    if (this.queue.size === 0) {
      return;
    }

    // 큐 복사 후 초기화
    const eventIds = Array.from(this.queue);
    this.queue.clear();

    try {
      const result = await ackSseNotifications(eventIds);
      logger.dev(`AckQueue: ${result.deleted}개 이벤트 ACK 완료`);
    } catch (error) {
      logger.error('AckQueue 플러시 실패', error);
      // 실패한 경우 재시도를 위해 다시 큐에 추가할 수도 있음
      // eventIds.forEach(id => this.queue.add(id));
    }
  }

  /**
   * 큐 정리 (언마운트 시 호출)
   */
  destroy(): void {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
    this.queue.clear();
  }
}

/**
 * SSE 연결 상태
 */
export const SseConnectionState = {
  DISCONNECTED: 'DISCONNECTED',
  CONNECTING: 'CONNECTING',
  CONNECTED: 'CONNECTED',
  ERROR: 'ERROR',
} as const;

export type SseConnectionState = typeof SseConnectionState[keyof typeof SseConnectionState];

/**
 * SSE 연결 옵션
 */
export interface SseConnectionOptions {
  /** SSE 엔드포인트 URL (기본: /sse/notifications) */
  url?: string;
  /** 쿠키 포함 여부 (기본: true) */
  withCredentials?: boolean;
  /** 연결 상태 변경 콜백 */
  onStateChange?: (state: SseConnectionState) => void;
  /** 에러 콜백 */
  onError?: (error: Event) => void;
}

/**
 * SSE 연결 래퍼 클래스
 * EventSource를 감싸서 상태 관리 및 정리 기능 제공
 */
export class SseConnection {
  private eventSource: EventSource | null = null;
  private state: SseConnectionState = SseConnectionState.DISCONNECTED;
  private readonly options: Required<SseConnectionOptions>;

  constructor(options: SseConnectionOptions = {}) {
    // url이 undefined일 경우 기본값 사용
    // 다른 서비스들과 동일하게 API_BASE_URL 사용
    // session_id를 쿼리 파라미터로 추가 (EventSource는 쿠키 전송이 불안정함)
    const sessionId = getSessionIdFromCookie();
    const sessionParam = sessionId ? `?session_id=${sessionId}` : '';

    const defaultUrl = `${API_BASE_URL}/sse/notifications${sessionParam}`;

    // options에서 url 분리하여 중복 방지
    const { url, ...otherOptions } = options;

    this.options = {
      withCredentials: true,
      onStateChange: () => { },
      onError: () => { },
      ...otherOptions,
      url: url || defaultUrl,
    };
  }

  /**
   * SSE 연결 시작
   */
  connect(): EventSource {
    if (this.eventSource) {
      logger.warn('이미 SSE 연결되어 있습니다');
      return this.eventSource;
    }

    this.setState(SseConnectionState.CONNECTING);

    try {
      this.eventSource = new EventSource(this.options.url, {
        withCredentials: this.options.withCredentials,
      });

      // 연결 성공 (첫 메시지 수신 시)
      this.eventSource.onopen = () => {
        logger.dev('SSE 연결 성공');
        this.setState(SseConnectionState.CONNECTED);
      };

      // 에러 발생
      this.eventSource.onerror = (error) => {
        logger.error('SSE 연결 에러', error);
        this.setState(SseConnectionState.ERROR);
        this.options.onError(error);

        // EventSource는 자동으로 재연결을 시도합니다.
        // 재연결이 성공하면 onopen이 다시 호출됩니다.
      };

      return this.eventSource;
    } catch (error) {
      logger.error('SSE 연결 생성 실패', error);
      this.setState(SseConnectionState.ERROR);
      throw error;
    }
  }

  /**
   * SSE 연결 종료
   */
  disconnect(): void {
    if (this.eventSource) {
      logger.dev('SSE 연결 종료');
      this.eventSource.close();
      this.eventSource = null;
      this.setState(SseConnectionState.DISCONNECTED);
    }
  }

  /**
   * 현재 EventSource 인스턴스 가져오기
   */
  getEventSource(): EventSource | null {
    return this.eventSource;
  }

  /**
   * 현재 연결 상태 가져오기
   */
  getState(): SseConnectionState {
    return this.state;
  }

  /**
   * 상태 변경 및 콜백 호출
   */
  private setState(newState: SseConnectionState): void {
    if (this.state !== newState) {
      this.state = newState;
      this.options.onStateChange(newState);
    }
  }
}
