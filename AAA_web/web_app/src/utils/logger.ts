import { IS_PRODUCTION } from '../config/env.config';

/**
 * 민감 정보 마스킹 (배포용에서만 사용)
 */
function maskSensitiveData(data: any): any {
  if (typeof data === 'string') {
    // userId 패턴 마스킹 (이메일 형식)
    return data.replace(/([a-zA-Z0-9._%+-]+)@([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/g, '***@$2');
  }

  if (Array.isArray(data)) {
    return data.map(maskSensitiveData);
  }

  if (typeof data === 'object' && data !== null) {
    const masked: any = {};
    for (const [key, value] of Object.entries(data)) {
      // 민감 필드 마스킹
      if (['userId', 'user_id', 'session_id', 'sessionId', 'token', 'password'].includes(key)) {
        masked[key] = '***';
      } else if (['name', 'email', 'phone'].includes(key)) {
        masked[key] = typeof value === 'string' ? '***' : value;
      } else {
        masked[key] = maskSensitiveData(value);
      }
    }
    return masked;
  }

  return data;
}

/**
 * Logger 클래스
 */
class Logger {
  constructor(private module: string) {}

  /**
   * 개발용 로그 (배포 시 출력 안 됨)
   * 개발 모드에서는 민감 정보 포함 모든 데이터를 그대로 출력
   */
  dev(message: string, ...args: any[]): void {
    if (!IS_PRODUCTION) {
      console.log(`[${this.module}] ${message}`, ...args);
    }
  }

  /**
   * 에러 로그 (배포/개발 모두 출력)
   * 배포 모드에서만 민감정보 마스킹, 개발 모드에서는 모든 데이터 출력
   */
  error(message: string, error?: any): void {
    if (IS_PRODUCTION) {
      // 배포용: 민감 정보 마스킹
      const maskedError = error ? maskSensitiveData(error) : undefined;
      console.error(`[${this.module}] ERROR: ${message}`, maskedError);
    } else {
      // 개발용: 모든 정보 출력 (마스킹 없음)
      console.error(`[${this.module}] ERROR: ${message}`, error);
    }
  }

  /**
   * 경고 로그 (배포/개발 모두 출력)
   * 배포 모드에서만 민감정보 마스킹
   */
  warn(message: string, ...args: any[]): void {
    if (IS_PRODUCTION) {
      const masked = args.map(maskSensitiveData);
      console.warn(`[${this.module}] WARN: ${message}`, ...masked);
    } else {
      // 개발용: 모든 정보 출력 (마스킹 없음)
      console.warn(`[${this.module}] WARN: ${message}`, ...args);
    }
  }

  /**
   * API 요청 로그 (개발용만, 민감 정보 포함 모든 데이터 출력)
   */
  apiRequest(method: string, url: string, data?: any): void {
    if (!IS_PRODUCTION) {
      console.log(`[${this.module}] 📤 ${method} ${url}`, data || '');
    }
  }

  /**
   * API 응답 로그 (개발용만, 민감 정보 포함 모든 데이터 출력)
   */
  apiResponse(method: string, url: string, status: number, data?: any): void {
    if (!IS_PRODUCTION) {
      console.log(`[${this.module}] 📥 ${method} ${url} ${status}`, data || '');
    }
  }
}

/**
 * Logger 인스턴스 생성 함수
 */
export function createLogger(module: string): Logger {
  return new Logger(module);
}

/**
 * 전역 로거 (간단한 용도)
 */
export const logger = {
  /**
   * 개발용 로그 (개발 모드에서만 출력, 모든 데이터 출력)
   */
  dev: (message: string, ...args: any[]) => {
    if (!IS_PRODUCTION) {
      console.log(message, ...args);
    }
  },

  /**
   * 에러 로그 (항상 출력, 배포 모드에서만 마스킹)
   */
  error: (message: string, error?: any) => {
    if (IS_PRODUCTION) {
      const masked = error ? maskSensitiveData(error) : undefined;
      console.error(`ERROR: ${message}`, masked);
    } else {
      console.error(`ERROR: ${message}`, error);
    }
  },

  /**
   * 경고 로그 (항상 출력, 배포 모드에서만 마스킹)
   */
  warn: (message: string, ...args: any[]) => {
    if (IS_PRODUCTION) {
      const masked = args.map(maskSensitiveData);
      console.warn(`WARN: ${message}`, ...masked);
    } else {
      console.warn(`WARN: ${message}`, ...args);
    }
  },
};
