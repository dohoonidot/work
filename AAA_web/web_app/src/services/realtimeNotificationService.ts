/**
 * 통합 실시간 알림 서비스 인터페이스
 *
 * 플랫폼에 상관없이 동일한 방식으로 실시간 알림을 처리하기 위한 추상화
 * Flutter(AMQP)와 React(SSE)를 통합하는 인터페이스
 */

import type { NotificationEnvelope } from '../types/notification';
import { createLogger } from '../utils/logger';

const logger = createLogger('RealtimeNotificationService');

// ===== 통합 인터페이스 정의 =====

/**
 * 알림 이벤트 타입
 */
export enum NotificationEventType {
  BIRTHDAY = 'birthday',
  LEAVE_APPROVAL = 'leave_approval',
  EAPPROVAL_APPROVAL = 'eapproval_approval',
  GIFT_ARRIVAL = 'gift_arrival',
  LEAVE_REQUESTED = 'leave_requested',
  LEAVE_CANCEL_REQUESTED = 'leave_cancel_requested',
}

/**
 * 연결 상태
 */
export enum ConnectionState {
  DISCONNECTED = 'DISCONNECTED',
  CONNECTING = 'CONNECTING',
  CONNECTED = 'CONNECTED',
  ERROR = 'ERROR',
  RECONNECTING = 'RECONNECTING',
}

/**
 * 알림 메시지 우선순위
 */
export enum MessagePriority {
  LOW = 'low',
  NORMAL = 'normal',
  HIGH = 'high',
  URGENT = 'urgent',
}

/**
 * 통합 알림 메시지 인터페이스
 */
export interface UnifiedNotificationMessage {
  id: string;
  event: NotificationEventType;
  eventId: string;
  userId: string;
  queueName?: string;
  sentAt: Date;
  payload: any;
  priority: MessagePriority;
  acknowledged: boolean;
  retryCount: number;
}

/**
 * 연결 옵션
 */
export interface ConnectionOptions {
  userId: string;
  queues?: string[];
  autoReconnect?: boolean;
  maxRetries?: number;
  reconnectInterval?: number;
  enableQueueing?: boolean;
  maxQueueSize?: number;
}

/**
 * 이벤트 핸들러 타입
 */
export type NotificationHandler = (message: UnifiedNotificationMessage) => void | Promise<void>;
export type ConnectionStateHandler = (state: ConnectionState, error?: Error) => void;
export type ErrorHandler = (error: Error, message?: UnifiedNotificationMessage) => void;

/**
 * 통합 실시간 알림 서비스 인터페이스
 */
export interface IRealtimeNotificationService {
  // ===== 연결 관리 =====

  /**
   * 연결 시작
   */
  connect(options: ConnectionOptions): Promise<void>;

  /**
   * 연결 종료
   */
  disconnect(): Promise<void>;

  /**
   * 현재 연결 상태
   */
  getConnectionState(): ConnectionState;

  /**
   * 연결 상태 변경 시 호출될 핸들러 설정
   */
  onConnectionStateChange(handler: ConnectionStateHandler): void;

  // ===== 이벤트 처리 =====

  /**
   * 알림 이벤트 핸들러 등록
   */
  onNotification(eventType: NotificationEventType, handler: NotificationHandler): void;

  /**
   * 모든 알림 이벤트 핸들러 등록
   */
  onAnyNotification(handler: NotificationHandler): void;

  /**
   * 이벤트 핸들러 제거
   */
  offNotification(eventType: NotificationEventType, handler?: NotificationHandler): void;

  // ===== 메시지 관리 =====

  /**
   * 메시지 수신 확인 (ACK)
   */
  acknowledgeMessage(messageId: string): Promise<void>;

  /**
   * 배치 메시지 수신 확인
   */
  acknowledgeMessages(messageIds: string[]): Promise<void>;

  /**
   * 메시지 큐잉 (오프라인 시)
   */
  queueMessage(message: UnifiedNotificationMessage): void;

  /**
   * 큐에 쌓인 메시지 처리
   */
  processQueuedMessages(): Promise<void>;

  // ===== 에러 처리 =====

  /**
   * 에러 핸들러 설정
   */
  onError(handler: ErrorHandler): void;

  // ===== 진단 및 모니터링 =====

  /**
   * 연결 통계 정보
   */
  getConnectionStats(): {
    connectedAt?: Date;
    disconnectedAt?: Date;
    reconnectCount: number;
    messagesReceived: number;
    messagesAcknowledged: number;
    queuedMessages: number;
    errors: number;
  };

  /**
   * 헬스체크
   */
  healthCheck(): Promise<boolean>;
}

// ===== 플랫폼별 구현 팩토리 =====

/**
 * 플랫폼 감지 및 적절한 구현체 반환
 */
export class RealtimeNotificationFactory {
  static createService(): IRealtimeNotificationService {
    // 브라우저 환경에서는 SSE 사용
    if (typeof window !== 'undefined') {
      return new SSEImplementation();
    }

    // Flutter/Dart 환경에서는 AMQP 사용 (런타임에 결정)
    // 실제로는 빌드 타임이나 런타임 플래그로 결정
    return new AMQPImplementation();
  }
}

// ===== SSE 구현체 (React용) =====

class SSEImplementation implements IRealtimeNotificationService {
  private sseConnection: any = null; // 실제로는 SseConnection 인스턴스
  private connectionState: ConnectionState = ConnectionState.DISCONNECTED;
  private handlers: Map<NotificationEventType, NotificationHandler[]> = new Map();
  private anyHandlers: NotificationHandler[] = [];
  private errorHandlers: ErrorHandler[] = [];
  private connectionStateHandlers: ConnectionStateHandler[] = [];
  private messageQueue: UnifiedNotificationMessage[] = [];
  private options?: ConnectionOptions;

  // 통계 정보
  private stats = {
    connectedAt: undefined as Date | undefined,
    disconnectedAt: undefined as Date | undefined,
    reconnectCount: 0,
    messagesReceived: 0,
    messagesAcknowledged: 0,
    queuedMessages: 0,
    errors: 0,
  };

  async connect(options: ConnectionOptions): Promise<void> {
    this.options = options;

    try {
      this.setConnectionState(ConnectionState.CONNECTING);

      // 실제 SSE 연결 로직 (기존 sseService.ts 활용)
      // 여기서는 인터페이스만 정의

      this.setConnectionState(ConnectionState.CONNECTED);
      this.stats.connectedAt = new Date();
    } catch (error) {
      this.setConnectionState(ConnectionState.ERROR, error as Error);
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    this.stats.disconnectedAt = new Date();
    this.setConnectionState(ConnectionState.DISCONNECTED);
    // 실제 연결 해제 로직
  }

  getConnectionState(): ConnectionState {
    return this.connectionState;
  }

  onConnectionStateChange(handler: ConnectionStateHandler): void {
    this.connectionStateHandlers.push(handler);
  }

  onNotification(eventType: NotificationEventType, handler: NotificationHandler): void {
    if (!this.handlers.has(eventType)) {
      this.handlers.set(eventType, []);
    }
    this.handlers.get(eventType)!.push(handler);
  }

  onAnyNotification(handler: NotificationHandler): void {
    this.anyHandlers.push(handler);
  }

  offNotification(eventType: NotificationEventType, handler?: NotificationHandler): void {
    if (handler) {
      const handlers = this.handlers.get(eventType) || [];
      const index = handlers.indexOf(handler);
      if (index > -1) {
        handlers.splice(index, 1);
      }
    } else {
      this.handlers.delete(eventType);
    }
  }

  async acknowledgeMessage(messageId: string): Promise<void> {
    this.stats.messagesAcknowledged++;
    // 실제 ACK 로직
  }

  async acknowledgeMessages(messageIds: string[]): Promise<void> {
    this.stats.messagesAcknowledged += messageIds.length;
    // 실제 배치 ACK 로직
  }

  queueMessage(message: UnifiedNotificationMessage): void {
    this.messageQueue.push(message);
    this.stats.queuedMessages = this.messageQueue.length;
  }

  async processQueuedMessages(): Promise<void> {
    // 큐에 쌓인 메시지 처리 로직
    const messages = [...this.messageQueue];
    this.messageQueue = [];
    this.stats.queuedMessages = 0;

    for (const message of messages) {
      await this.handleMessage(message);
    }
  }

  onError(handler: ErrorHandler): void {
    this.errorHandlers.push(handler);
  }

  getConnectionStats() {
    return { ...this.stats };
  }

  async healthCheck(): Promise<boolean> {
    return this.connectionState === ConnectionState.CONNECTED;
  }

  // ===== 내부 헬퍼 메서드 =====

  private setConnectionState(state: ConnectionState, error?: Error): void {
    this.connectionState = state;
    this.connectionStateHandlers.forEach(handler => handler(state, error));
  }

  private async handleMessage(message: UnifiedNotificationMessage): Promise<void> {
    this.stats.messagesReceived++;

    try {
      // 이벤트 타입별 핸들러 호출
      const eventHandlers = this.handlers.get(message.event) || [];
      for (const handler of eventHandlers) {
        await handler(message);
      }

      // 전체 핸들러 호출
      for (const handler of this.anyHandlers) {
        await handler(message);
      }
    } catch (error) {
      this.stats.errors++;
      this.errorHandlers.forEach(handler =>
        handler(error as Error, message)
      );
    }
  }
}

// ===== AMQP 구현체 (Flutter용) =====

class AMQPImplementation implements IRealtimeNotificationService {
  // Flutter AMQP 구현체
  // 실제로는 Flutter의 AmqpService를 래핑

  private connectionState: ConnectionState = ConnectionState.DISCONNECTED;
  private handlers: Map<NotificationEventType, NotificationHandler[]> = new Map();
  private anyHandlers: NotificationHandler[] = [];
  private errorHandlers: ErrorHandler[] = [];
  private connectionStateHandlers: ConnectionStateHandler[] = [];
  private messageQueue: UnifiedNotificationMessage[] = [];

  private stats = {
    connectedAt: undefined as Date | undefined,
    disconnectedAt: undefined as Date | undefined,
    reconnectCount: 0,
    messagesReceived: 0,
    messagesAcknowledged: 0,
    queuedMessages: 0,
    errors: 0,
  };

  async connect(options: ConnectionOptions): Promise<void> {
    this.setConnectionState(ConnectionState.CONNECTING);

    try {
      // Flutter AMQP 연결 로직
      // 실제로는 window.amqpService.connect() 같은 방식으로 호출

      this.setConnectionState(ConnectionState.CONNECTED);
      this.stats.connectedAt = new Date();
    } catch (error) {
      this.setConnectionState(ConnectionState.ERROR, error as Error);
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    this.stats.disconnectedAt = new Date();
    this.setConnectionState(ConnectionState.DISCONNECTED);
    // Flutter AMQP 연결 해제 로직
  }

  getConnectionState(): ConnectionState {
    return this.connectionState;
  }

  onConnectionStateChange(handler: ConnectionStateHandler): void {
    this.connectionStateHandlers.push(handler);
  }

  onNotification(eventType: NotificationEventType, handler: NotificationHandler): void {
    if (!this.handlers.has(eventType)) {
      this.handlers.set(eventType, []);
    }
    this.handlers.get(eventType)!.push(handler);
  }

  onAnyNotification(handler: NotificationHandler): void {
    this.anyHandlers.push(handler);
  }

  offNotification(eventType: NotificationEventType, handler?: NotificationHandler): void {
    if (handler) {
      const handlers = this.handlers.get(eventType) || [];
      const index = handlers.indexOf(handler);
      if (index > -1) {
        handlers.splice(index, 1);
      }
    } else {
      this.handlers.delete(eventType);
    }
  }

  async acknowledgeMessage(messageId: string): Promise<void> {
    this.stats.messagesAcknowledged++;
    // Flutter AMQP ACK 로직
  }

  async acknowledgeMessages(messageIds: string[]): Promise<void> {
    this.stats.messagesAcknowledged += messageIds.length;
    // Flutter AMQP 배치 ACK 로직
  }

  queueMessage(message: UnifiedNotificationMessage): void {
    this.messageQueue.push(message);
    this.stats.queuedMessages = this.messageQueue.length;
  }

  async processQueuedMessages(): Promise<void> {
    const messages = [...this.messageQueue];
    this.messageQueue = [];
    this.stats.queuedMessages = 0;

    for (const message of messages) {
      await this.handleMessage(message);
    }
  }

  onError(handler: ErrorHandler): void {
    this.errorHandlers.push(handler);
  }

  getConnectionStats() {
    return { ...this.stats };
  }

  async healthCheck(): Promise<boolean> {
    return this.connectionState === ConnectionState.CONNECTED;
  }

  private setConnectionState(state: ConnectionState, error?: Error): void {
    this.connectionState = state;
    this.connectionStateHandlers.forEach(handler => handler(state, error));
  }

  private async handleMessage(message: UnifiedNotificationMessage): Promise<void> {
    this.stats.messagesReceived++;

    try {
      const eventHandlers = this.handlers.get(message.event) || [];
      for (const handler of eventHandlers) {
        await handler(message);
      }

      for (const handler of this.anyHandlers) {
        await handler(message);
      }
    } catch (error) {
      this.stats.errors++;
      this.errorHandlers.forEach(handler =>
        handler(error as Error, message)
      );
    }
  }
}

// ===== 사용 예시 =====

/*
// React에서 사용
import { RealtimeNotificationFactory, NotificationEventType } from './realtimeNotificationService';

const notificationService = RealtimeNotificationFactory.createService();

// 연결
await notificationService.connect({
  userId: 'user123',
  queues: ['birthday', 'leave_approval'],
  autoReconnect: true,
  maxRetries: 5,
});

// 이벤트 핸들러 등록
notificationService.onNotification(NotificationEventType.LEAVE_APPROVAL, (message) => {
  console.log('휴가 승인 알림:', message);
  // UI 업데이트 로직
});

// 연결 상태 모니터링
notificationService.onConnectionStateChange((state, error) => {
  console.log('연결 상태:', state);
  if (error) logger.error('연결 에러:', error);
});

// Flutter에서 사용 (유사한 방식)
const notificationService = RealtimeNotificationFactory.createService();
await notificationService.connect({
  userId: 'user123',
  queues: ['birthday', 'gift'],
  autoReconnect: true,
});
*/

export default RealtimeNotificationFactory;
