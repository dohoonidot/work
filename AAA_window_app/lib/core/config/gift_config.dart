class GiftConfig {
  static const String baseUrl = 'http://ai2great.com:9999';

  // 선물 관련 API 엔드포인트
  static const String giftListEndpoint = '/api/gifts';
  static const String giftPurchaseEndpoint = '/api/gifts/purchase';
  static const String giftHistoryEndpoint = '/api/gifts/history';

  // API URL 생성 메서드
  static String getGiftListUrl() => '$baseUrl$giftListEndpoint';
  static String getGiftPurchaseUrl() => '$baseUrl$giftPurchaseEndpoint';
  static String getGiftHistoryUrl() => '$baseUrl$giftHistoryEndpoint';

  // API 헤더 설정
  static Map<String, String> getApiHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // 추후 인증 토큰 추가 가능
      // 'Authorization': 'Bearer $token',
    };
  }

  // 선물 카드 이미지 경로
  static const Map<String, String> giftCardImages = {
/*    'naver_pay': 'assets/images/naver_pay.png',
    'starbucks': 'assets/images/starbucks.png',*/
    'shinsegae': 'assets/images/sinsaegae.png',
    'baedal_minjok': 'assets/images/baemin.png',
    'cu': 'assets/images/cu.png',
    'gs25': 'assets/images/gs25.png',
    'emart': 'assets/images/emart.png',
  };

  // 선물 카드 기본 정보
  static const Map<String, Map<String, dynamic>> giftCardInfo = {
/*    'naver_pay': {
      'name': '네이버페이',
      'description': '네이버페이 포인트 2만원',
      'originalPrice': '20,000원',
      'discountRate': '3%',
      'discountedPrice': '19,400원',
      'goods_code': 'G00001971091',
    },
    'starbucks': {
      'name': '스타벅스',
      'description': '스타벅스 e카드 2만원 교환권',
      'originalPrice': '20,000원',
      'discountRate': '4%',
      'discountedPrice': '19,200원',
      'goods_code': 'G00002391579',
    },*/
    'shinsegae': {
      'name': '신세계',
      'description': '신세계 상품권 2만원',
      'originalPrice': '20,000원',
      'discountRate': '6%',
      'discountedPrice': '18,800원',
      'goods_code': 'G00002071060',
    },
    'baedal_minjok': {
      'name': '배달의민족',
      'description': '배달의민족 모바일상품권 2만원',
      'originalPrice': '20,000원',
      'discountRate': '3%',
      'discountedPrice': '19,400원',
      'goods_code': 'G00003471033',
    },
    'cu': {
      'name': 'CU',
      'description': 'CU 모바일상품권 2만원',
      'originalPrice': '20,000원',
      'discountRate': '2%',
      'discountedPrice': '19,600원',
      'goods_code': 'G00004291585',
    },
    'gs25': {
      'name': 'GS25',
      'description': 'GS25 모바일상품권 2만원',
      'originalPrice': '20,000원',
      'discountRate': '2%',
      'discountedPrice': '19,600원',
      'goods_code': 'G00000750719',
    },
    'emart': {
      'name': '이마트',
      'description': '이마트 상품권 2만원',
      'originalPrice': '20,000원',
      'discountRate': '2%',
      'discountedPrice': '19,600원',
      'goods_code': 'G00000830685',
    },
  };
}
