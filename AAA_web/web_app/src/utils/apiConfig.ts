/**
 * API 설정 유틸리티
 * Flutter의 app_config.dart와 동일한 로직
 *
 * 개발 환경: 8060 포트
 * 프로덕션 환경: 8080 포트
 *
 * 환경 변경: web_app/src/config/env.config.ts에서 IS_PRODUCTION 값만 변경하면 됩니다.
 */

import { API_BASE_URL, IS_PRODUCTION } from '../config/env.config';
import { logger } from './logger';

// API 기본 URL을 다시 export (env.config.ts에서 가져옴)
export { API_BASE_URL, IS_PRODUCTION };

// WebSocket URL (API URL과 동일한 포트 사용)
export const WS_BASE_URL = API_BASE_URL.replace('https://', 'wss://');

// 환경 정보 로그 (개발 모드에서만 출력)
logger.dev(`🔧 [API Config] 환경: ${IS_PRODUCTION ? '프로덕션' : '개발'}, API URL: ${API_BASE_URL}`);

