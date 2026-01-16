import axios from 'axios';
import { API_BASE_URL } from '../utils/apiConfig';
import { createLogger } from '../utils/logger';

const logger = createLogger('API');

// API 기본 URL (Flutter app_config.dart 참조)
// 항상 https://ai2great.com:8060 사용
const BASE_URL = API_BASE_URL;

// Axios 인스턴스 생성
const api = axios.create({
  baseURL: BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true, // 쿠키 기반 인증을 위해 필수 (SSE session_id 쿠키 전송)
});

// 요청 인터셉터: 쿠키 기반 인증 사용 (Flutter와 동일)
api.interceptors.request.use(
  (config) => {
    // 디버깅: 아카이브 관련 API 요청 로깅
    if (config.url?.includes('Archive') || config.url?.includes('archive')) {
      logger.apiRequest(
        config.method?.toUpperCase() || 'GET',
        config.url || '',
        config.data
      );
    }

    // Authorization 헤더 제거 - 쿠키 기반 인증 사용
    // Flutter에서는 별도의 Authorization 헤더 없이 쿠키로 인증 처리
    // const token = localStorage.getItem('auth_token');
    // if (token) {
    //   config.headers.Authorization = `Bearer ${token}`;
    // }

    // 필요한 경우 특정 API에서만 토큰 사용 (현재는 모두 쿠키 기반)
    return config;
  },
  (error) => {
    logger.error('API 요청 에러', error);
    return Promise.reject(error);
  }
);

// 응답 인터셉터: 에러 처리
api.interceptors.response.use(
  (response) => {
    // 디버깅: 아카이브 관련 API 응답 로깅
    if (response.config.url?.includes('Archive') || response.config.url?.includes('archive')) {
      logger.apiResponse(
        response.config.method?.toUpperCase() || 'GET',
        response.config.url || '',
        response.status,
        response.data
      );
    }
    return response;
  },
  async (error) => {
    // 디버깅: 아카이브 관련 API 에러 로깅
    if (error.config?.url?.includes('Archive') || error.config?.url?.includes('archive')) {
      logger.error('아카이브 API 응답 에러', {
        url: error.config?.url,
        status: error.response?.status,
        message: error.message,
      });
    }

    if (error.response?.status === 401) {
      // 인증 실패 시 refresh 시도
      logger.warn('인증 만료 - refresh 시도');
      try {
        // refresh API 호출 (authService import 필요하지만 순환 참조 방지를 위해 직접 호출)
        const refreshResponse = await fetch(`${API_BASE_URL}/api/web/refresh`, {
          method: 'POST',
          credentials: 'include',
        });

        if (refreshResponse.status === 200) {
          // refresh 성공 - 원래 요청 재시도는 하지 않고 그냥 통과
          logger.dev('리프레시 성공 - 인증 상태 복구');
          return Promise.reject(error); // 원래 에러는 그대로 전달
        } else {
          // refresh 실패 - 로그인 페이지로 이동
          logger.warn('리프레시 실패 - 로그인 페이지로 이동');
          window.location.href = '/login';
        }
      } catch (refreshError) {
        // refresh 호출 자체가 실패 - 로그인 페이지로 이동
        logger.error('리프레시 호출 실패:', refreshError);
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);

export default api;
