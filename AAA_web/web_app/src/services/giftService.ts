import api from './api';
import axios from 'axios';
import type { Gift, CheckGiftsResponse } from '../types/gift';
import { createLogger } from '../utils/logger';

const logger = createLogger('GiftService');

class GiftService {
  /**
   * 받은 선물 목록 조회 (Flutter의 ApiService.checkGifts 참조)
   */
  async checkGifts(userId: string): Promise<CheckGiftsResponse> {
    const response = await api.post<CheckGiftsResponse>('/queue/checkGifts', {
      user_id: userId,
    });

    return response.data;
  }

  /**
   * 선물 보내기 (Flutter의 GiftService.sendGift 참조)
   */
  async sendGift(params: {
    goodsCode: string;
    userId: string;
    id: number;
    realTimeId?: number;
    queueName: string;
  }): Promise<any> {
    const { goodsCode, userId, id, realTimeId, queueName } = params;
    
    const finalId = realTimeId ?? id;
    
    const response = await api.post('/send_birthday_gift', {
      id: finalId,
      goods_code: goodsCode,
      user_id: userId,
      queue_name: queueName,
    });

    return response.data;
  }

  /**
   * 받은 생일선물 모바일로 내보내기 (Flutter의 GiftService.sendToMobile 참조)
   * URL: http://ai2great.com:9999/send_to_mobile
   * Request Body: {"couponImgUrl": string}
   * Response Body: {"code": string, "message": string, "result": string}
   */
  async sendToMobile(couponImgUrl: string): Promise<{
    code: string;
    message: string;
    result: string;
  }> {
    try {
      const requestData = {
        couponImgUrl: couponImgUrl,
      };

      const response = await axios.post(
        'http://ai2great.com:9999/send_to_mobile',
        requestData,
        {
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          timeout: 30000,
        }
      );

      if (response.status === 200 || response.status === 201) {
        const responseData = response.data;

        // Response 형식 검증
        if (
          responseData &&
          typeof responseData.code === 'string' &&
          typeof responseData.message === 'string' &&
          typeof responseData.result === 'string'
        ) {
          return responseData;
        } else {
          throw new Error(`잘못된 응답 형식: ${JSON.stringify(responseData)}`);
        }
      } else {
        throw new Error(`모바일 내보내기 실패: ${response.status}`);
      }
    } catch (error: any) {
      logger.error('모바일 내보내기 중 오류 발생:', error);
      throw new Error(
        error.response?.data?.message ||
        error.message ||
        '모바일 내보내기 중 오류가 발생했습니다.'
      );
    }
  }
}

export default new GiftService();
