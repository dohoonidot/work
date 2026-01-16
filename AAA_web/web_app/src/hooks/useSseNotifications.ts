/**
 * SSE 알림 수신 React Hook
 * SSE_NOTES.md 기반으로 구현
 *
 * 주요 기능:
 * - SSE 연결 생성 및 정리 (useEffect)
 * - 이벤트 타입별 리스너 등록
 * - 알림 Envelope 파싱 및 콜백 호출
 * - 연결 상태 관리
 */

import { useEffect, useRef, useCallback, useState } from 'react';
import {
  SseConnection,
  SseConnectionState,
  type SseConnectionOptions,
} from '../services/sseService';
import {
  SSE_EVENT_NAMES,
  type NotificationEnvelope,
} from '../types/notification';

/**
 * SSE 알림 Hook 옵션
 */
export interface UseSseNotificationsOptions {
  /** SSE 활성화 여부 (로그인 여부에 따라 제어) */
  enabled: boolean;
  /** 알림 수신 콜백 */
  onNotification: (envelope: NotificationEnvelope) => void;
  /** 쿠키 포함 여부 (기본: true) */
  withCredentials?: boolean;
  /** SSE 엔드포인트 URL (기본: /sse/notifications) */
  url?: string;
  /** 연결 상태 변경 콜백 */
  onConnectionStateChange?: (state: SseConnectionState) => void;
}

/**
 * SSE 알림 수신 Hook
 *
 * @example
 * ```tsx
 * const { connectionState, reconnect } = useSseNotifications({
 *   enabled: isLoggedIn,
 *   onNotification: (envelope) => {
 *     console.log('알림 수신:', envelope);
 *     // 알림 처리 로직
 *   },
 * });
 * ```
 */
export function useSseNotifications(options: UseSseNotificationsOptions) {
  const {
    enabled,
    onNotification,
    withCredentials = true,
    url,
    onConnectionStateChange,
  } = options;

  // 연결 상태
  const [connectionState, setConnectionState] = useState<SseConnectionState>(
    SseConnectionState.DISCONNECTED
  );

  // SSE 연결 인스턴스 (ref로 관리하여 재생성 방지)
  const connectionRef = useRef<SseConnection | null>(null);

  // 콜백을 ref로 관리하여 의존성 변경 시 리스너 재등록 방지
  const onNotificationRef = useRef(onNotification);
  const onConnectionStateChangeRef = useRef(onConnectionStateChange);

  // ref 업데이트
  useEffect(() => {
    onNotificationRef.current = onNotification;
    onConnectionStateChangeRef.current = onConnectionStateChange;
  }, [onNotification, onConnectionStateChange]);

  /**
   * SSE 연결 및 정리
   */
  useEffect(() => {
    if (!enabled) {
      // enabled가 false면 연결 종료
      if (connectionRef.current) {
        connectionRef.current.disconnect();
        connectionRef.current = null;
      }
      setConnectionState(SseConnectionState.DISCONNECTED);
      return;
    }

    // 이미 연결되어 있으면 종료
    if (connectionRef.current) {
      connectionRef.current.disconnect();
      connectionRef.current = null;
    }

    // 새 연결 생성
    const connection = new SseConnection({
      url,
      withCredentials,
      onStateChange: (state) => {
        setConnectionState(state);
        onConnectionStateChangeRef.current?.(state);
      },
      onError: (error) => {
        console.error('[useSseNotifications] SSE 에러:', error);
      },
    });

    connectionRef.current = connection;
    const eventSource = connection.connect();

    // 각 이벤트 타입별 리스너 등록
    const handleMessage = (e: MessageEvent) => {
      try {
        // Envelope 파싱
        const envelope = JSON.parse(e.data) as NotificationEnvelope;

        // 디버깅 로그 - 전체 envelope와 payload 출력
        console.log('[useSseNotifications] SSE 수신 전체:', envelope);
        console.log('[useSseNotifications] payload:', JSON.stringify(envelope.payload, null, 2));
        console.log('[useSseNotifications] payload_text:', envelope.payload_text);

        // 콜백 호출
        onNotificationRef.current(envelope);
      } catch (error) {
        console.error('[useSseNotifications] 메시지 파싱 실패:', error, e.data);
      }
    };

    // SSE_EVENT_NAMES에 있는 모든 이벤트 타입에 리스너 등록
    // 중요: EventSource는 event: 필드가 있으면 onmessage가 호출되지 않음
    SSE_EVENT_NAMES.forEach((eventName) => {
      eventSource.addEventListener(eventName, handleMessage);
    });

    console.log('[useSseNotifications] SSE 연결 시작, 등록된 이벤트:', SSE_EVENT_NAMES);

    // 언마운트 시 정리
    return () => {
      if (connectionRef.current) {
        connectionRef.current.disconnect();
        connectionRef.current = null;
      }
    };
  }, [enabled, withCredentials, url]); // onConnectionStateChange는 ref로 처리하여 의존성에서 제외

  /**
   * 수동 재연결 함수
   */
  const reconnect = useCallback(() => {
    if (connectionRef.current) {
      connectionRef.current.disconnect();
      connectionRef.current = null;
    }
    setConnectionState(SseConnectionState.DISCONNECTED);

    // 다음 렌더링 사이클에서 재연결
    // (enabled 상태가 true로 유지되면 useEffect가 자동으로 재연결)
  }, []);

  return {
    /** 현재 연결 상태 */
    connectionState,
    /** 수동 재연결 함수 */
    reconnect,
    /** 연결 여부 */
    isConnected: connectionState === SseConnectionState.CONNECTED,
  };
}
