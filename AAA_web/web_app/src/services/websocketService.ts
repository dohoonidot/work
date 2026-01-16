/**
 * WebSocket 서비스
 * Flutter 앱의 AMQP 서비스와 동일한 기능을 WebSocket으로 제공
 */

import { WS_BASE_URL } from '../utils/apiConfig';
import { createLogger } from '../utils/logger';

const logger = createLogger('WebSocketService');
const WS_URL = `${WS_BASE_URL}/ws`;

export type MessageType = 'gift' | 'alert' | 'birthday' | 'event' | 'eapproval' | 'leave.draft';

export interface WebSocketMessage {
  type: MessageType;
  data: any;
  timestamp: string;
}

type MessageHandler = (message: WebSocketMessage) => void;
type ConnectionHandler = (connected: boolean) => void;

class WebSocketService {
  private ws: WebSocket | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 15;
  private reconnectDelay = 8000; // 8초
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private isConnecting = false;
  private isDisconnecting = false;
  private userId: string | null = null;
  private messageHandlers: Map<MessageType, Set<MessageHandler>> = new Map();
  private connectionHandlers: Set<ConnectionHandler> = new Set();

  /**
   * WebSocket 연결
   */
  async connect(userId: string): Promise<boolean> {
    if (this.isConnecting || this.isDisconnecting) {
      logger.dev('⏳ [WebSocket] 이미 연결/해제 작업이 진행 중입니다.');
      return false;
    }

    if (this.ws?.readyState === WebSocket.OPEN && this.userId === userId) {
      logger.dev('✅ [WebSocket] 이미 연결되어 있습니다.');
      return true;
    }

    this.isConnecting = true;
    this.userId = userId;

    try {
      // 기존 연결 정리
      await this.disconnect();

      const wsUrl = `${WS_URL}?userId=${userId}`;
      logger.dev('🔌 [WebSocket] 연결 시도:', wsUrl);

      this.ws = new WebSocket(wsUrl);

      return new Promise((resolve) => {
        const timeout = setTimeout(() => {
          logger.error('❌ [WebSocket] 연결 타임아웃');
          this.isConnecting = false;
          resolve(false);
        }, 10000);

        this.ws!.onopen = () => {
          clearTimeout(timeout);
          logger.dev('✅ [WebSocket] 연결 성공');
          this.isConnecting = false;
          this.reconnectAttempts = 0;
          this._notifyConnectionChange(true);
          resolve(true);
        };

        this.ws!.onerror = (error) => {
          clearTimeout(timeout);
          logger.error('❌ [WebSocket] 연결 에러:', error);
          this.isConnecting = false;
          this._notifyConnectionChange(false);
          resolve(false);
        };

        this.ws!.onclose = (event) => {
          clearTimeout(timeout);
          logger.dev('🔌 [WebSocket] 연결 종료:', event.code, event.reason);
          this.isConnecting = false;
          this._notifyConnectionChange(false);

          // 정상 종료가 아니면 재연결 시도
          if (event.code !== 1000 && !this.isDisconnecting) {
            this._attemptReconnect();
          }
        };

        this.ws!.onmessage = (event) => {
          try {
            const message: WebSocketMessage = JSON.parse(event.data);
            logger.dev('📨 [WebSocket] 메시지 수신:', message.type);
            this._handleMessage(message);
          } catch (error) {
            logger.error('❌ [WebSocket] 메시지 파싱 실패:', error);
          }
        };
      });
    } catch (error) {
      logger.error('❌ [WebSocket] 연결 실패:', error);
      this.isConnecting = false;
      this._notifyConnectionChange(false);
      return false;
    }
  }

  /**
   * WebSocket 연결 해제
   */
  async disconnect(): Promise<void> {
    if (this.isDisconnecting) {
      return;
    }

    this.isDisconnecting = true;

    // 재연결 타이머 취소
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }

    if (this.ws) {
      try {
        this.ws.close(1000, '정상 종료');
      } catch (error) {
        logger.error('❌ [WebSocket] 연결 해제 실패:', error);
      }
      this.ws = null;
    }

    this.isDisconnecting = false;
    this._notifyConnectionChange(false);
    logger.dev('✅ [WebSocket] 연결 해제 완료');
  }

  /**
   * 메시지 핸들러 등록
   */
  onMessage(type: MessageType, handler: MessageHandler): () => void {
    if (!this.messageHandlers.has(type)) {
      this.messageHandlers.set(type, new Set());
    }
    this.messageHandlers.get(type)!.add(handler);

    // 해제 함수 반환
    return () => {
      this.messageHandlers.get(type)?.delete(handler);
    };
  }

  /**
   * 연결 상태 변경 핸들러 등록
   */
  onConnectionChange(handler: ConnectionHandler): () => void {
    this.connectionHandlers.add(handler);

    // 해제 함수 반환
    return () => {
      this.connectionHandlers.delete(handler);
    };
  }

  /**
   * 연결 상태 확인
   */
  get isConnected(): boolean {
    return this.ws?.readyState === WebSocket.OPEN;
  }

  /**
   * 메시지 처리
   */
  private _handleMessage(message: WebSocketMessage) {
    const handlers = this.messageHandlers.get(message.type);
    if (handlers) {
      handlers.forEach((handler) => {
        try {
          handler(message);
        } catch (error) {
          logger.error(`❌ [WebSocket] 메시지 핸들러 실행 실패 (${message.type}):`, error);
        }
      });
    }
  }

  /**
   * 연결 상태 변경 알림
   */
  private _notifyConnectionChange(connected: boolean) {
    this.connectionHandlers.forEach((handler) => {
      try {
        handler(connected);
      } catch (error) {
        logger.error('❌ [WebSocket] 연결 상태 핸들러 실행 실패:', error);
      }
    });
  }

  /**
   * 재연결 시도
   */
  private _attemptReconnect() {
    if (this.isDisconnecting || !this.userId) {
      return;
    }

    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      logger.error('❌ [WebSocket] 최대 재연결 시도 횟수 초과');
      return;
    }

    this.reconnectAttempts++;
    const delay = this.reconnectDelay + (this.reconnectAttempts * 2000); // 지수 백오프

    logger.dev(`🔄 [WebSocket] ${delay}ms 후 재연결 시도 (${this.reconnectAttempts}/${this.maxReconnectAttempts})`);

    this.reconnectTimer = setTimeout(() => {
      if (!this.isConnected && !this.isDisconnecting && this.userId) {
        this.connect(this.userId);
      }
    }, delay);
  }

  /**
   * 메시지 전송
   */
  send(message: any): boolean {
    if (!this.isConnected || !this.ws) {
      logger.warn('⚠️ [WebSocket] 연결되지 않아 메시지를 전송할 수 없습니다.');
      return false;
    }

    try {
      this.ws.send(JSON.stringify(message));
      return true;
    } catch (error) {
      logger.error('❌ [WebSocket] 메시지 전송 실패:', error);
      return false;
    }
  }
}

// 싱글톤 인스턴스
const websocketService = new WebSocketService();

export default websocketService;

