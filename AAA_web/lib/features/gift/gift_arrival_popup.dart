import 'package:flutter/material.dart';

class GiftArrivalPopup extends StatefulWidget {
  final String? giftName;
  final String? giftDescription;
  final String? message;
  final String? couponImgUrl;
  final String? couponEndDate;
  final String? queueName; // queue_name 추가
  final Map<String, dynamic>? serverData;
  final IconData? giftIcon;
  final Color? giftColor;
  final String? senderName;
  final VoidCallback onConfirm;

  const GiftArrivalPopup({
    super.key,
    this.giftName,
    this.giftDescription,
    this.message,
    this.couponImgUrl,
    this.couponEndDate,
    this.queueName,
    this.serverData,
    this.giftIcon,
    this.giftColor,
    this.senderName,
    required this.onConfirm,
  });

  // 서버 데이터로부터 팝업 생성
  factory GiftArrivalPopup.fromServerData({
    required Map<String, dynamic> giftData,
    required VoidCallback onConfirm,
  }) {
    return GiftArrivalPopup(
      giftName: giftData['gift_name'] ?? '',
      giftDescription: giftData['description'] ?? '',
      message: giftData['message'] ?? '',
      couponImgUrl: giftData['couponImgUrl'] ?? '',
      couponEndDate: giftData['coupon_end_date'] ?? '',
      queueName: giftData['queue_name'] ?? '', // queue_name 추가
      senderName: giftData['sender_name'] ?? 'ASPN AI',
      serverData: giftData,
      onConfirm: onConfirm,
    );
  }

  @override
  State<GiftArrivalPopup> createState() => _GiftArrivalPopupState();
}

class _GiftArrivalPopupState extends State<GiftArrivalPopup>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _scaleController.forward();
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String displayMessage =
        widget.message ?? widget.giftDescription ?? '선물이 도착했습니다!';
    final String displaySender = widget.senderName ?? 'ASPN AI';
    final bool hasServerData = widget.serverData != null;
    final bool isEventGift = widget.queueName == 'event';
    final Color themeColor = isEventGift
        ? Colors.purple.shade400
        : (widget.giftColor ?? Colors.orange);

    return WillPopScope(
      onWillPop: () async => true,
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.5),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: GestureDetector(
                          onTap: () {
                            // 팝업 내부 클릭 시 이벤트 전파 방지
                          },
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.85,
                            constraints: BoxConstraints(
                              maxWidth: 400,
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(30.0),
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 이벤트 선물인 경우 단순한 아이콘
                                    if (isEventGift)
                                      Container(
                                        padding: EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color:
                                              themeColor.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.card_giftcard,
                                          size: 50,
                                          color: themeColor,
                                        ),
                                      )
                                    // 서버 데이터가 있으면 쿠폰 이미지, 없으면 기존 아이콘
                                    else if (hasServerData &&
                                        widget.couponImgUrl?.isNotEmpty == true)
                                      Container(
                                        width: 200,
                                        height: 120,
                                        margin:
                                            EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          child: Image.network(
                                            widget.couponImgUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey.shade200,
                                                child: Icon(
                                                  Icons.card_giftcard,
                                                  size: 48,
                                                  color: Colors.grey.shade400,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      )
                                    else
                                      // 기존 아이콘 표시
                                      Container(
                                        padding: EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: themeColor.withValues(
                                              alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          widget.giftIcon ??
                                              Icons.card_giftcard,
                                          size: 60,
                                          color: themeColor,
                                        ),
                                      ),

                                    SizedBox(height: 20),

                                    // 메인 타이틀 - 이벤트일 때는 단순하게
                                    Text(
                                      isEventGift
                                          ? '선물이 도착했습니다'
                                          : '🎁 선물이 도착했어요!',
                                      style: TextStyle(
                                        fontSize: isEventGift ? 20 : 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),

                                    SizedBox(height: 12),

                                    // 보낸 사람 - 이벤트일 때는 생략
                                    if (!isEventGift)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color:
                                              themeColor.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${displaySender}님이 보낸 선물',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: themeColor.withValues(
                                                alpha: 0.8),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),

                                    if (!isEventGift) SizedBox(height: 20),

                                    // 선물 정보 카드 - 이벤트일 때는 단순하게
                                    if (isEventGift)
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '이벤트 선물이 도착했습니다.\n받은선물함에서 확인해보세요.',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade700,
                                            height: 1.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      )
                                    else
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          border: Border.all(
                                            color: themeColor.withValues(
                                                alpha: 0.3),
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.grey
                                                  .withValues(alpha: 0.1),
                                              blurRadius: 10,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            if (widget.giftName?.isNotEmpty ==
                                                true)
                                              Text(
                                                widget.giftName!,
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey.shade800,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),

                                            if (widget.giftName?.isNotEmpty ==
                                                true)
                                              SizedBox(height: 8),

                                            Text(
                                              displayMessage,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                                height: 1.4,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),

                                            // 사용 기한 표시 (서버 데이터가 있을 때)
                                            if (hasServerData &&
                                                widget.couponEndDate
                                                        ?.isNotEmpty ==
                                                    true)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 12.0),
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Colors.orange.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                        color: Colors
                                                            .orange.shade200),
                                                  ),
                                                  child: Text(
                                                    '사용기한: ${widget.couponEndDate!}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors
                                                          .orange.shade700,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                    SizedBox(height: 25),

                                    // 확인하러가기 버튼
                                    Container(
                                      width: double.infinity,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: themeColor,
                                        borderRadius: BorderRadius.circular(25),
                                        boxShadow: [
                                          BoxShadow(
                                            color: themeColor.withValues(
                                                alpha: 0.3),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          widget.onConfirm();
                                        },
                                        icon: Icon(
                                          Icons.card_giftcard,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        label: Text(
                                          isEventGift ? '받은선물함으로 이동' : '확인하러가기',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(25),
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(height: 15),

                                    // 나중에 확인하기 버튼
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: Text(
                                        '나중에 확인하기',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
