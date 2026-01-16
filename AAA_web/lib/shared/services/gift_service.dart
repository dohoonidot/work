import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ASPN_AI_AGENT/core/config/gift_config.dart';

class GiftService {
  // 싱글톤 패턴
  static final GiftService _instance = GiftService._internal();
  factory GiftService() => _instance;
  GiftService._internal();

  // 1. 선물 보내기 API (통합)
  // URL: send_birthday_gift
  // Request Body: {"id": int, "goods_code": str, "user_id": str, "queue_name": str}
  Future<Map<String, dynamic>> sendGift({
    required String goodsCode,
    required String userId,
    required int id,
    int? realTimeId,
    required String queueName, // "birthday" 또는 "event"
  }) async {
    print('🎁 [GIFT_SERVICE] ===== sendGift API 호출 시작 =====');
    print('🎁 [GIFT_SERVICE] 입력 파라미터:');
    print('   - goodsCode: $goodsCode');
    print('   - userId: $userId');
    print('   - id: $id (타입: ${id.runtimeType})');
    print('   - realTimeId: $realTimeId (타입: ${realTimeId.runtimeType})');
    print('   - queueName: $queueName');

    try {
      // 우선순위: realTimeId > id (alertId)
      final finalId = realTimeId ?? id;

      print('🔍 [GIFT_SERVICE] ===== ID 우선순위 처리 =====');
      print('🔍 [GIFT_SERVICE] id 값 확인 - id: $id (타입: ${id.runtimeType})');
      print(
          '🔍 [GIFT_SERVICE] realTimeId 값 확인 - realTimeId: $realTimeId (타입: ${realTimeId.runtimeType})');
      print(
          '🔍 [GIFT_SERVICE] 최종 사용될 id 값 - finalId: $finalId (타입: ${finalId.runtimeType})');
      print(
          '🔍 [GIFT_SERVICE] ID 소스: ${realTimeId != null ? "realTimeId (실시간 AMQP)" : "id (알림함 또는 기본값)"}');
      print('🔍 [GIFT_SERVICE] ===== ID 우선순위 처리 완료 =====');

      final requestData = {
        'id': finalId,
        'goods_code': goodsCode,
        'user_id': userId,
        'queue_name': queueName,
      };

      print('🔍 [GIFT_SERVICE] ===== API 요청 데이터 =====');
      print('🔍 [GIFT_SERVICE] sendGift API 요청 데이터: $requestData');
      print('🔍 [GIFT_SERVICE] goods_code 값 확인 - goods_code: $goodsCode');
      print('🔍 [GIFT_SERVICE] user_id 값 확인 - user_id: $userId');
      print('🔍 [GIFT_SERVICE] queue_name 값 확인 - queue_name: $queueName');
      print('🔍 [GIFT_SERVICE] JSON 인코딩된 요청 데이터: ${json.encode(requestData)}');
      print('🔍 [GIFT_SERVICE] ===== API 요청 데이터 완료 =====');

      print('🌐 [GIFT_SERVICE] HTTP POST 요청 시작');
      print('   - URL: ${GiftConfig.baseUrl}/send_birthday_gift');
      final response = await http.post(
        Uri.parse('${GiftConfig.baseUrl}/send_birthday_gift'),
        headers: GiftConfig.getApiHeaders(),
        body: json.encode(requestData),
      );
      print('🌐 [GIFT_SERVICE] HTTP POST 요청 완료');
      print('   - Status Code: ${response.statusCode}');
      print('   - Response Body: ${response.body}');

      final responseBody = json.decode(response.body);

      if (response.statusCode == 200) {
        // 정상: detail이 null이어야 함
        print('✅ [GIFT_SERVICE] API 호출 성공');
        print('✅ [GIFT_SERVICE] 응답 데이터: $responseBody');
        return responseBody;
      } else {
        // 오류: detail 값이 있으면 사용자에게 알림
        final detail = responseBody['detail'];
        print('❌ [GIFT_SERVICE] API 호출 실패');
        print('   - Status Code: ${response.statusCode}');
        print('   - Error Detail: $detail');
        throw Exception(detail ?? '선물 보내기 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [GIFT_SERVICE] ===== API 호출 중 오류 발생 =====');
      print('❌ [GIFT_SERVICE] 오류 타입: ${e.runtimeType}');
      print('❌ [GIFT_SERVICE] 오류 메시지: $e');
      throw Exception('선물 보내기 중 오류 발생: $e');
    } finally {
      print('🎁 [GIFT_SERVICE] ===== sendGift API 호출 완료 =====');
    }
  }

  // 2. 받은 생일선물 모바일로 내보내기 API
  // URL: send_to_mobile
  // Request Body: {"couponImgUrl": str}
  // Response Body: {"code": str, "message": str, "result": str}
  Future<Map<String, dynamic>> sendToMobile({
    required String couponImgUrl,
  }) async {
    try {
      final requestData = {
        'couponImgUrl': couponImgUrl,
      };

      final response = await http.post(
        Uri.parse('${GiftConfig.baseUrl}/send_to_mobile'),
        headers: GiftConfig.getApiHeaders(),
        body: json.encode(requestData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);

        // Response 형식 검증
        if (responseData.containsKey('code') &&
            responseData.containsKey('message') &&
            responseData.containsKey('result')) {
          return responseData;
        } else {
          throw Exception('잘못된 응답 형식: $responseData');
        }
      } else {
        throw Exception('모바일 내보내기 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('모바일 내보내기 중 오류 발생: $e');
    }
  }

  // AMQP 서비스에서 couponImgUrl 가져오기 헬퍼 메서드
  static String? getCouponImgUrlFromAmqp(Map<String, dynamic> amqpData) {
    return amqpData['couponImgUrl'] as String?;
  }
}
