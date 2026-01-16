/**
 * 알림함 API 서비스
 *
 * 다음 3개의 API를 제공합니다:
 * - POST /queue/checkAlerts - 알림 목록 조회
 * - POST /queue/updateAlerts - 알림 읽음 처리
 * - POST /queue/deleteAlerts - 알림 삭제
 */

import api from './api';
import { createLogger } from '../utils/logger';

const logger = createLogger('NotificationApi');

import type {
  CheckAlertsRequest,
  CheckAlertsResponse,
  UpdateAlertRequest,
  UpdateAlertResponse,
  DeleteAlertRequest,
  DeleteAlertResponse,
  AlertItem,
} from '../types/notification';

/**
 * 알림 목록 조회
 * @param userId 사용자 ID (이메일)
 * @returns 알림 목록
 */
export const getAlerts = async (userId: string): Promise<AlertItem[]> => {
  try {
    const requestBody: CheckAlertsRequest = { user_id: userId };

    const response = await api.post<CheckAlertsResponse>(
      '/queue/checkAlerts',
      requestBody
    );

    if (response.data.error) {
      logger.error('알림 목록 조회 실패:', response.data.error);
      throw new Error(response.data.error);
    }

    return response.data.alerts || [];
  } catch (error) {
    logger.error('알림 목록 조회 오류:', error);
    throw error;
  }
};

/**
 * 알림 읽음 처리
 * @param userId 사용자 ID (이메일)
 * @param alertId 알림 ID
 * @returns 업데이트된 알림 목록
 */
export const markAsRead = async (
  userId: string,
  alertId: number
): Promise<AlertItem[]> => {
  try {
    const requestBody: UpdateAlertRequest = {
      id: alertId,
      user_id: userId,
    };

    const response = await api.post<UpdateAlertResponse>(
      '/queue/updateAlerts',
      requestBody
    );

    if (response.data.error) {
      logger.error('알림 읽음 처리 실패:', response.data.error);
      throw new Error(response.data.error);
    }

    return response.data.alerts || [];
  } catch (error) {
    logger.error('알림 읽음 처리 오류:', error);
    throw error;
  }
};

/**
 * 알림 삭제
 * @param userId 사용자 ID (이메일)
 * @param alertId 알림 ID
 * @returns 업데이트된 알림 목록
 */
export const deleteAlert = async (
  userId: string,
  alertId: number
): Promise<AlertItem[]> => {
  try {
    const requestBody: DeleteAlertRequest = {
      id: alertId,
      user_id: userId,
    };

    const response = await api.post<DeleteAlertResponse>(
      '/queue/deleteAlerts',
      requestBody
    );

    if (response.data.error) {
      logger.error('알림 삭제 실패:', response.data.error);
      throw new Error(response.data.error);
    }

    return response.data.alerts || [];
  } catch (error) {
    logger.error('알림 삭제 오류:', error);
    throw error;
  }
};

/**
 * NotificationApi 객체 (기존 코드와의 호환성)
 */
export const notificationApi = {
  getAlerts,
  markAsRead,
  deleteAlert,
};

export default notificationApi;
