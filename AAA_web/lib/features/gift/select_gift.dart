import 'package:flutter/material.dart';
import 'package:ASPN_AI_AGENT/shared/services/gift_service.dart';
import 'package:ASPN_AI_AGENT/core/config/gift_config.dart';
import 'package:ASPN_AI_AGENT/main.dart'; // navigatorKey import 필요

class SelectGift {
  // 선물고르기 모달 표시 메서드
  static void showGiftSelectionModal(BuildContext context, String userId,
      {int? alertId, int? realTimeId, String queueName = "birthday"}) {
    String? selectedGiftId;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        // Capture parameters in closure
        final capturedQueueName = queueName;
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: 1400,
                height: 800,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDarkTheme
                        ? [
                            Color(0xFF1F2937), // 다크 그레이
                            Color(0xFF111827), // 더 어두운 그레이
                            Color(0xFF0F172A), // 가장 어두운 그레이
                          ]
                        : [
                            Color(0xFFF8F7FF), // 매우 연한 보라색
                            Color(0xFFF3F1FF), // 연한 보라색
                            Color(0xFFEFECFF), // 중간 연한 보라색
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkTheme
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 헤더
                    Container(
                      padding: EdgeInsets.all(32),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF4F46E5), // 인디고
                                  Color(0xFF7C3AED), // 바이올렛
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Color(0xFF4F46E5).withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.card_giftcard,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '선물 고르기',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: isDarkTheme
                                        ? Colors.white
                                        : Color(0xFF191F28),
                                  ),
                                ),
                                Text(
                                  '원하는 선물을 선택해 주세요! 유효기간 꼭! 확인해주세요.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDarkTheme
                                        ? Colors.grey.shade300
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.red.shade600,
                                      size: 16,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '유효기간은 30일로 기간내에 사용 하지 않으면 사용이 불가합니다.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 20),
                          // 오른쪽 안내 문구 (가로 배치)
                          Container(
                            width: 400,
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDarkTheme
                                  ? Colors.grey.shade800.withValues(alpha: 0.5)
                                  : Colors.blue.shade50.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDarkTheme
                                    ? Colors.grey.shade600
                                    : Colors.blue.shade200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue.shade600,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '선물은 아래 "선물 받기" 버튼을 통해 수령하실 수 있으며, 수령일로부터 30일간 사용 가능합니다. 단, 선물 수령(구매) 자체에는 별도의 기한이 없으므로, 지금 바로 선택하지 않으셔도 괜찮습니다. 추후 사용을 원하실 때, 화면 오른쪽 상단의 알림함에서 해당 메시지를 클릭하여 언제든 선물을 수령하실 수 있습니다.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDarkTheme
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade700,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.close,
                              color: isDarkTheme
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade600,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 선물 목록
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                            childAspectRatio: 1,
                          ),
                          itemCount: _getAvailableGifts().length,
                          itemBuilder: (context, index) {
                            final gift = _getAvailableGifts()[index];
                            return _buildGiftCard(context, gift, selectedGiftId,
                                (String giftId) {
                              setState(() {
                                selectedGiftId = giftId;
                              });
                            });
                          },
                        ),
                      ),
                    ),

                    // 하단 버튼
                    Container(
                      padding: EdgeInsets.all(32),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF4F46E5),
                                    Color(0xFF7C3AED),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF4F46E5)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: selectedGiftId == null
                                    ? null
                                    : () {
                                        final selectedGift =
                                            _getAvailableGifts().firstWhere(
                                                (g) =>
                                                    g['id'] == selectedGiftId);
                                        _showSendingGiftDialog(
                                            context, selectedGift, userId,
                                            alertId: alertId,
                                            realTimeId: realTimeId,
                                            queueName: capturedQueueName);
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                ),
                                child: Text(
                                  '선물 받기',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 사용 가능한 선물 목록 (실제 기프티콘 데이터)
  static List<Map<String, dynamic>> _getAvailableGifts() {
    return [
/*
      {
        'id': 'naver_pay',
        'name': GiftConfig.giftCardInfo['naver_pay']!['name'],
        'description': GiftConfig.giftCardInfo['naver_pay']!['description'],
        'icon': Icons.payment,
        'color': Colors.green,
        'originalPrice': GiftConfig.giftCardInfo['naver_pay']!['originalPrice'],
        'discountRate': GiftConfig.giftCardInfo['naver_pay']!['discountRate'],
        'discountedPrice':
            GiftConfig.giftCardInfo['naver_pay']!['discountedPrice'],
        'brandColor': Colors.green.shade600,
        'backgroundColor': Colors.black,
        'imagePath': GiftConfig.giftCardImages['naver_pay'],
        'goods_code': GiftConfig.giftCardInfo['naver_pay']!['goods_code'],
      },
*/
      {
        'id': 'baedal_minjok',
        'name': GiftConfig.giftCardInfo['baedal_minjok']!['name'],
        'description': GiftConfig.giftCardInfo['baedal_minjok']!['description'],
        'icon': Icons.delivery_dining,
        'color': Colors.blue,
        'originalPrice':
            GiftConfig.giftCardInfo['baedal_minjok']!['originalPrice'],
        'discountRate':
            GiftConfig.giftCardInfo['baedal_minjok']!['discountRate'],
        'discountedPrice':
            GiftConfig.giftCardInfo['baedal_minjok']!['discountedPrice'],
        'brandColor': Colors.blue.shade400,
        'backgroundColor': Colors.lightBlue.shade100,
        'imagePath': GiftConfig.giftCardImages['baedal_minjok'],
        'goods_code': GiftConfig.giftCardInfo['baedal_minjok']!['goods_code'],
      },
      // {
      //   'id': 'starbucks',
      //   'name': GiftConfig.giftCardInfo['starbucks']!['name'],
      //   'description': GiftConfig.giftCardInfo['starbucks']!['description'],
      //   'icon': Icons.local_cafe,
      //   'color': Colors.green,
      //   'originalPrice': GiftConfig.giftCardInfo['starbucks']!['originalPrice'],
      //   'discountRate': GiftConfig.giftCardInfo['starbucks']!['discountRate'],
      //   'discountedPrice':
      //       GiftConfig.giftCardInfo['starbucks']!['discountedPrice'],
      //   'brandColor': Colors.green.shade800,
      //   'backgroundColor': Colors.green.shade900,
      //   'imagePath': GiftConfig.giftCardImages['starbucks'],
      //   'goods_code': GiftConfig.giftCardInfo['starbucks']!['goods_code'],
      // },
      {
        'id': 'shinsegae',
        'name': GiftConfig.giftCardInfo['shinsegae']!['name'],
        'description': GiftConfig.giftCardInfo['shinsegae']!['description'],
        'icon': Icons.shopping_bag,
        'color': Colors.orange,
        'originalPrice': GiftConfig.giftCardInfo['shinsegae']!['originalPrice'],
        'discountRate': GiftConfig.giftCardInfo['shinsegae']!['discountRate'],
        'discountedPrice':
            GiftConfig.giftCardInfo['shinsegae']!['discountedPrice'],
        'brandColor': Colors.orange.shade600,
        'backgroundColor': Colors.white,
        'imagePath': GiftConfig.giftCardImages['shinsegae'],
        'goods_code': GiftConfig.giftCardInfo['shinsegae']!['goods_code'],
      },

      {
        'id': 'cu',
        'name': GiftConfig.giftCardInfo['cu']!['name'],
        'description': GiftConfig.giftCardInfo['cu']!['description'],
        'icon': Icons.store,
        'color': Colors.purple,
        'originalPrice': GiftConfig.giftCardInfo['cu']!['originalPrice'],
        'discountRate': GiftConfig.giftCardInfo['cu']!['discountRate'],
        'discountedPrice': GiftConfig.giftCardInfo['cu']!['discountedPrice'],
        'brandColor': Colors.purple.shade600,
        'backgroundColor': Colors.purple.shade100,
        'imagePath': GiftConfig.giftCardImages['cu'],
        'goods_code': GiftConfig.giftCardInfo['cu']!['goods_code'],
      },
      {
        'id': 'gs25',
        'name': GiftConfig.giftCardInfo['gs25']!['name'],
        'description': GiftConfig.giftCardInfo['gs25']!['description'],
        'icon': Icons.local_convenience_store,
        'color': Colors.blue,
        'originalPrice': GiftConfig.giftCardInfo['gs25']!['originalPrice'],
        'discountRate': GiftConfig.giftCardInfo['gs25']!['discountRate'],
        'discountedPrice': GiftConfig.giftCardInfo['gs25']!['discountedPrice'],
        'brandColor': Colors.blue.shade800,
        'backgroundColor': Colors.blue.shade900,
        'imagePath': GiftConfig.giftCardImages['gs25'],
        'goods_code': GiftConfig.giftCardInfo['gs25']!['goods_code'],
      },
      {
        'id': 'emart',
        'name': GiftConfig.giftCardInfo['emart']!['name'],
        'description': GiftConfig.giftCardInfo['emart']!['description'],
        'icon': Icons.shopping_cart,
        'color': Colors.red,
        'originalPrice': GiftConfig.giftCardInfo['emart']!['originalPrice'],
        'discountRate': GiftConfig.giftCardInfo['emart']!['discountRate'],
        'discountedPrice': GiftConfig.giftCardInfo['emart']!['discountedPrice'],
        'brandColor': Colors.red.shade600,
        'backgroundColor': Colors.red.shade100,
        'imagePath': GiftConfig.giftCardImages['emart'],
        'goods_code': GiftConfig.giftCardInfo['emart']!['goods_code'],
      },
    ];
  }

  // 선물 카드 위젯
  static Widget _buildGiftCard(BuildContext context, Map<String, dynamic> gift,
      String? selectedGiftId, Function(String) onGiftSelected) {
    final isSelected = selectedGiftId == gift['id'];
    final isShinsegae = gift['id'] == 'shinsegae';

    final cardWidget = GestureDetector(
      onTap: () {
        onGiftSelected(gift['id']);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: Color(0xFF4F46E5), width: 2)
              : Border.all(color: Color(0xFFE5E7EB), width: 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Color(0xFF4F46E5).withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Color(0xFF4F46E5).withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: gift['imagePath'] != null
              ? Stack(
                  children: [
                    // 배경 이미지 (카드 전체에서 살짝 축소)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 20, // 하단 20px 여백 확보
                      child: Image.asset(
                        gift['imagePath'],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // 브랜드명 (좌상단)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          gift['name'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // 신세계 상품권 호버링 안내 배지 (우상단)
                    if (isShinsegae)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: MouseRegion(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.red.shade300, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  '교환 안내',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // 상품 설명 (하단 - 확장된 그라디언트 배경)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 50, // 그라디언트 영역 높이 확장
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                              Colors.black.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Text(
                            gift['description'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              height: 1.2,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        gift['backgroundColor'],
                        gift['backgroundColor'].withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // 브랜드 로고/아이콘
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            gift['icon'],
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      // 신세계 상품권 호버링 안내 배지 (우상단)
                      if (isShinsegae)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: MouseRegion(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade700,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.red.shade300, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    '교환 안내',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // 상품 설명 (하단에 위치)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            gift['description'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              height: 1.2,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );

    // 신세계 상품권일 때만 Tooltip으로 감싸기
    if (isShinsegae) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Tooltip(
          message: '⚠️ 백화점 상품권샵에서만 교환 가능합니다\n이마트 상품권샵에서는 교환할 수 없습니다',
          preferBelow: false,
          verticalOffset: 10,
          decoration: BoxDecoration(
            color: Colors.red.shade900,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade300, width: 2),
          ),
          textStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.4,
          ),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          waitDuration: Duration(milliseconds: 300),
          child: cardWidget,
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: cardWidget,
    );
  }

  // 선물 보내는 중 다이얼로그 표시
  static void _showSendingGiftDialog(
      BuildContext context, Map<String, dynamic> selectedGift, String userId,
      {int? alertId, int? realTimeId, required String queueName}) {
    print('🎁 [SELECT_GIFT] ===== 선물 보내는 중 다이얼로그 표시 =====');
    print('🎁 [SELECT_GIFT] 입력 파라미터:');
    print('   - userId: $userId');
    print('   - alertId: $alertId (타입: ${alertId.runtimeType})');
    print('   - realTimeId: $realTimeId (타입: ${realTimeId.runtimeType})');
    print('   - selectedGift: $selectedGift');

    // 안내 다이얼로그 먼저 띄우기
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.card_giftcard, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text('선물 보내는 중'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.grey.shade800,
                    fontFamily: 'Spoqa Han Sans Neo',
                  ),
                  children: [
                    TextSpan(text: '선물 수령시 '),
                    TextSpan(
                      text: '30일',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: ' 이내에 꼭 사용 하셔야 합니다.\n'),
                    TextSpan(text: '확인하셨다면 "받기"를 눌러주세요.'),
                  ],
                ),
              ),
              if (selectedGift['id'] == 'emart') ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade600, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '이마트 상품권은 만원권 두장이 전송됩니다.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (selectedGift['id'] == 'shinsegae') ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.red.shade700, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '⚠️ 백화점 상품권샵에서만 교환 가능합니다',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Padding(
                        padding: EdgeInsets.only(left: 26),
                        child: Text(
                          '이마트 상품권샵에서는 교환할 수 없습니다',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange.shade600, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '신세계상품권 만원권 두장이 전송됩니다',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
              },
              child: Text(
                '취소',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // 다이얼로그 닫기
                Navigator.of(context).pop(); // 선물 선택 모달 닫기

                // 스낵바로 알림 표시
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '선물을 선택하셨습니다. 잠시만 기다려주세요.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: Colors.blue[600],
                    duration: Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );

                // 받기 버튼 클릭 시 API 호출
                await _sendGift(context, selectedGift, userId,
                    alertId: alertId,
                    realTimeId: realTimeId,
                    queueName: queueName);
              },
              child: Text(
                '받기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[600],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 선물 보내기 API 호출 (통합)
  static Future<void> _sendGift(
      BuildContext context, Map<String, dynamic> selectedGift, String userId,
      {int? alertId, int? realTimeId, required String queueName}) async {
    print('🎁 [SELECT_GIFT] ===== 선물 보내기 API 호출 시작 =====');
    print('🎁 [SELECT_GIFT] 입력 파라미터:');
    print('   - userId: $userId');
    print('   - alertId: $alertId (타입: ${alertId.runtimeType})');
    print('   - realTimeId: $realTimeId (타입: ${realTimeId.runtimeType})');
    print('   - queueName: $queueName');
    print('   - selectedGift: $selectedGift');

    // API는 백그라운드에서 호출 (await 제거, 에러만 캐치)
    print('🔍 [SELECT_GIFT] ===== ID 처리 시작 =====');
    print(
        '🔍 [SELECT_GIFT] alertId 값 확인 - alertId: $alertId (타입: ${alertId.runtimeType})');
    print(
        '🔍 [SELECT_GIFT] realTimeId 값 확인 - realTimeId: $realTimeId (타입: ${realTimeId.runtimeType})');
    print(
        '🔍 [SELECT_GIFT] selectedGift 확인 - goods_code: ${selectedGift['goods_code']}');
    print('🔍 [SELECT_GIFT] userId 확인 - userId: $userId');

    final giftService = GiftService();

    // 우선순위: realTimeId > alertId > 0
    final finalId = realTimeId ?? alertId ?? 0;
    print('🔍 [SELECT_GIFT] ===== ID 우선순위 처리 결과 =====');
    print(
        '🔍 [SELECT_GIFT] 최종 전달될 id 값 - finalId: $finalId (타입: ${finalId.runtimeType})');
    print('🔍 [SELECT_GIFT] ID 소스 분석:');
    print('   - realTimeId 사용: ${realTimeId != null ? "실시간 AMQP" : "아니오"}');
    print('   - alertId 사용: ${alertId != null ? "알림함" : "아니오"}');
    print(
        '   - 기본값 사용: ${realTimeId == null && alertId == null ? "0" : "아니오"}');
    print('🔍 [SELECT_GIFT] ===== ID 처리 완료 =====');

    print('🎁 [SELECT_GIFT] GiftService.sendGift 호출');
    print('   - goodsCode: ${selectedGift['goods_code']}');
    print('   - userId: $userId');
    print('   - id: $finalId');
    print('   - realTimeId: $realTimeId');
    print('   - queueName: $queueName');

    giftService
        .sendGift(
      goodsCode: selectedGift['goods_code'],
      userId: userId,
      id: finalId, // 우선순위에 따라 결정된 ID
      realTimeId: realTimeId, // realTimeId도 별도로 전달
      queueName: queueName, // 큐 이름 전달
    )
        .then((response) {
      // 성공 시 응답 데이터 확인
      print('✅ [SELECT_GIFT] API 호출 성공');
      print('📦 [SELECT_GIFT] 응답 데이터: $response');

      // status_code가 400 이상이면 에러로 처리
      final statusCode = response['status_code'] as int? ?? 200;
      if (statusCode >= 400) {
        final detailMsg = response['detail'] as String? ?? '오류가 발생했습니다.';
        _showErrorSnackBarStatic(detailMsg);
      } else {
        _showSuccessSnackBarStatic();
      }
    }).catchError((e) {
      print('❌ [SELECT_GIFT] ===== API 호출 실패 =====');
      print('❌ [SELECT_GIFT] 오류: $e');
      final msg = e.toString();
      String alertMsg = msg;
      // 'Exception: 메시지'에서 메시지만 추출
      final match = RegExp(r'Exception: (.+)').firstMatch(msg);
      if (match != null) {
        alertMsg = match.group(1) ?? msg;
      }
      _showErrorSnackBarStatic(alertMsg);
    });

    print('🎁 [SELECT_GIFT] ===== 생일선물 보내기 API 호출 완료 =====');
  }

  /// 에러 스낵바 표시 (정적 메서드)
  static void _showErrorSnackBarStatic(String message) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.red[600],
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  /// 성공 스낵바 표시 (정적 메서드)
  static void _showSuccessSnackBarStatic() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '선물이 성공적으로 전송되었습니다! 🎁',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.green[600],
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
}
