import api from './api';
import { createLogger } from '../utils/logger';

const logger = createLogger('SettingsService');

// 설정 관련 타입 정의
export interface PrivacyStatus {
  is_agreed: number;
  success: boolean;
  error?: string;
}

export interface PrivacyUpdateRequest {
  user_id: string;
  is_agreed: number;
}

export interface PrivacyUpdateResponse {
  success: boolean;
  error?: string;
}

class SettingsService {
  /**
   * 개인정보 동의 상태 확인 - Flutter와 동일
   */
  async checkPrivacyAgreement(userId: string): Promise<PrivacyStatus> {
    logger.dev('개인정보 동의 상태 확인 API 요청:', { user_id: userId });
    
    const response = await api.post<PrivacyStatus>('/checkPrivacy', {
      user_id: userId,
    });

    logger.dev('개인정보 동의 상태 확인 응답:', response.data);
    return response.data;
  }

  /**
   * 개인정보 동의 상태 업데이트 - Flutter와 동일
   */
  async updatePrivacyAgreement(userId: string, isAgreed: boolean): Promise<PrivacyUpdateResponse> {
    logger.dev('개인정보 동의 상태 업데이트 API 요청:', { user_id: userId, is_agreed: isAgreed });
    
    const response = await api.post<PrivacyUpdateResponse>('/updatePrivacy', {
      user_id: userId,
      is_agreed: isAgreed ? 1 : 0,
    });

    logger.dev('개인정보 동의 상태 업데이트 응답:', response.data);
    return response.data;
  }

  /**
   * 사용자 프로필 정보 조회 (향후 확장용)
   */
  async getUserProfile(userId: string): Promise<any> {
    logger.dev('사용자 프로필 조회 API 요청:', { user_id: userId });
    
    try {
      const response = await api.post('/user/profile', {
        user_id: userId,
      });

      logger.dev('사용자 프로필 조회 응답:', response.data);
      return response.data;
    } catch (error) {
      console.warn('사용자 프로필 조회 실패:', error);
      return null;
    }
  }

  /**
   * 알림 설정 업데이트 (향후 확장용)
   */
  async updateNotificationSettings(userId: string, settings: {
    pushEnabled: boolean;
    emailEnabled: boolean;
    smsEnabled: boolean;
  }): Promise<any> {
    logger.dev('알림 설정 업데이트 API 요청:', { user_id: userId, settings });
    
    try {
      const response = await api.post('/user/notifications', {
        user_id: userId,
        ...settings,
      });

      logger.dev('알림 설정 업데이트 응답:', response.data);
      return response.data;
    } catch (error) {
      console.warn('알림 설정 업데이트 실패:', error);
      return null;
    }
  }

  /**
   * 테마 설정 업데이트 (로컬 스토리지용)
   */
  updateThemeSettings(themeMode: 'light' | 'dark' | 'system'): void {
    logger.dev('테마 설정 업데이트:', themeMode);
    localStorage.setItem('themeMode', themeMode);
  }

  /**
   * 테마 설정 조회 (로컬 스토리지용)
   */
  getThemeSettings(): 'light' | 'dark' | 'system' {
    const themeMode = localStorage.getItem('themeMode') as 'light' | 'dark' | 'system';
    return themeMode || 'light';
  }
}

export default new SettingsService();
