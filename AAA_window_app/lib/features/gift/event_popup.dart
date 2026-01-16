import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import 'package:ASPN_AI_AGENT/features/gift/select_gift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';

class EventPopup extends StatefulWidget {
  final String title; // 서버에서 받은 동적 타이틀
  final String message; // 서버에서 받은 동적 메시지
  final String? realTimeId;

  const EventPopup(
      {super.key, required this.title, required this.message, this.realTimeId});

  @override
  State<EventPopup> createState() => _EventPopupState();
}

class _EventPopupState extends State<EventPopup> with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late ConfettiController _confettiController2;
  late ConfettiController _confettiController3;
  late ConfettiController _confettiController4;
  late ConfettiController _confettiController5;
  late ConfettiController _confettiController6;
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 색종이 효과 컨트롤러들 - 더 오래 지속
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 15));
    _confettiController2 =
        ConfettiController(duration: const Duration(seconds: 12));
    _confettiController3 =
        ConfettiController(duration: const Duration(seconds: 18));
    _confettiController4 =
        ConfettiController(duration: const Duration(seconds: 20));
    _confettiController5 =
        ConfettiController(duration: const Duration(seconds: 16));
    _confettiController6 =
        ConfettiController(duration: const Duration(seconds: 22));

    // 애니메이션 컨트롤러들
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // 애니메이션 정의
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    // 애니메이션 시작
    _startAnimations();
  }

  void _startAnimations() {
    _confettiController.play();
    _confettiController2.play();
    _confettiController3.play();
    _confettiController4.play();
    _confettiController5.play();
    _confettiController6.play();
    _scaleController.forward();
    _rotationController.repeat();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _confettiController.stop();
    _confettiController2.stop();
    _confettiController3.stop();
    _confettiController4.stop();
    _confettiController5.stop();
    _confettiController6.stop();
    _confettiController.dispose();
    _confettiController2.dispose();
    _confettiController3.dispose();
    _confettiController4.dispose();
    _confettiController5.dispose();
    _confettiController6.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (mounted) {
          _confettiController.stop();
          _confettiController2.stop();
          _confettiController3.stop();
          _confettiController4.stop();
          _confettiController5.stop();
          _confettiController6.stop();
        }
        return true;
      },
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onTap: () {
            // 외부 영역 클릭 시 팝업 닫기
            if (mounted) {
              _confettiController.stop();
              _confettiController2.stop();
              _confettiController3.stop();
              _confettiController4.stop();
              _confettiController5.stop();
              _confettiController6.stop();
              Navigator.of(context).pop();
            }
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF8FAFC).withValues(alpha: 0.2), // 거의 흰색
                  const Color(0xFFE2E8F0).withValues(alpha: 0.3), // 연한 회색
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // 배경 색종이 효과들 - 단순한 퍼플 색상
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    colors: const [
                      Color(0xFF8B5CF6), // 퍼플
                      Color(0xFFA78BFA), // 연한 퍼플
                      Color(0xFFDDD6FE), // 매우 연한 퍼플
                      Color(0xFFF3F0FF), // 극히 연한 퍼플
                    ],
                    createParticlePath: drawStar,
                    numberOfParticles: 80,
                    maxBlastForce: 60,
                    minBlastForce: 25,
                  ),
                ),
                Align(
                  alignment: Alignment.topLeft,
                  child: ConfettiWidget(
                    confettiController: _confettiController2,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    colors: const [
                      Color(0xFF8B5CF6), // 퍼플
                      Color(0xFFA78BFA), // 연한 퍼플
                      Color(0xFFDDD6FE), // 매우 연한 퍼플
                    ],
                    createParticlePath: drawHeart,
                    numberOfParticles: 60,
                    maxBlastForce: 50,
                    minBlastForce: 20,
                  ),
                ),

                // 메인 팝업 다이얼로그
                Center(
                  child: AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: GestureDetector(
                            onTap: () {
                              // 팝업 내부 클릭 시 이벤트 전파 방지 (팝업이 닫히지 않도록)
                            },
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.45,
                              height: MediaQuery.of(context).size.height * 0.8,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF8B5CF6)
                                        .withValues(alpha: 0.95), // 퍼플
                                    const Color(0xFFA78BFA)
                                        .withValues(alpha: 0.95), // 연한 퍼플
                                    const Color(0xFFF3E8FF)
                                        .withValues(alpha: 0.95), // 매우 연한 퍼플
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8B5CF6)
                                        .withValues(alpha: 0.2),
                                    blurRadius: 15,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // 메인 컨텐츠 - 상단 여백 최소화
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        25.0, 15.0, 25.0, 25.0),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        // 회전하는 이모티콘 (크기 축소)
                                        AnimatedBuilder(
                                          animation: _rotationAnimation,
                                          builder: (context, child) {
                                            return Transform.rotate(
                                              angle: _rotationAnimation.value,
                                              child: const Text(
                                                '🎁',
                                                style: TextStyle(
                                                  fontSize: 45,
                                                ),
                                              ),
                                            );
                                          },
                                        ),

                                        const SizedBox(height: 8),

                                        // 동적 타이틀 (서버에서 받은 값, 빈 값이면 숨김)
                                        if (widget.title.isNotEmpty) ...[
                                          Text(
                                            widget.title,
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                        ],

                                        // 동적 메시지 (서버에서 받은 값, 최대한 큰 영역)
                                        Expanded(
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(18),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.95),
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF7C3AED)
                                                      .withValues(alpha: 0.2),
                                                  blurRadius: 12,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: SingleChildScrollView(
                                              child: Text(
                                                widget.message,
                                                style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(
                                                      0xFF581C87), // 진한 퍼플
                                                  height: 1.5,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 15),

                                        // 선물 고르러 가기 버튼 (단순한 퍼플)
                                        Container(
                                          width: 220,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                const Color(0xFF8B5CF6), // 퍼플
                                                const Color(
                                                    0xFFA78BFA), // 연한 퍼플
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(24),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF8B5CF6)
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              if (mounted) {
                                                _confettiController.stop();
                                                _confettiController2.stop();
                                                _confettiController3.stop();
                                                _confettiController4.stop();
                                                _confettiController5.stop();
                                                _confettiController6.stop();
                                                Navigator.of(context).pop();
                                                try {
                                                  // 기존 ProviderScope의 컨테이너 사용
                                                  final container =
                                                      ProviderScope.containerOf(
                                                          context);
                                                  final userId = container
                                                      .read(userIdProvider);
                                                  print(
                                                      '🔍 DEBUG: event_popup에서 userId 조회 - 값: $userId');
                                                  if (userId != null) {
                                                    // realTimeId를 int로 변환하여 사용
                                                    int? convertedRealTimeId;
                                                    if (widget.realTimeId !=
                                                        null) {
                                                      convertedRealTimeId =
                                                          int.tryParse(widget
                                                              .realTimeId!);
                                                      print(
                                                          '🔍 [EVENT_POPUP] realTimeId 변환: ${widget.realTimeId} → $convertedRealTimeId');
                                                    }
                                                    SelectGift
                                                        .showGiftSelectionModal(
                                                            context, userId,
                                                            realTimeId:
                                                                convertedRealTimeId,
                                                            queueName: "event");
                                                  } else {
                                                    print(
                                                        '사용자 ID가 없습니다. 로그인이 필요합니다.');
                                                  }
                                                } catch (e) {
                                                  print('사용자 ID 가져오기 오류: $e');
                                                }
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.card_giftcard,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            label: const Text(
                                              '선물 고르러 가기',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                              ),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 10),

                                        // 닫기 버튼 (퍼플 그라데이션)
                                        Container(
                                          width: 140,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                const Color(0xFF6366F1), // 인디고
                                                const Color(0xFF8B5CF6), // 퍼플
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF6366F1)
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton(
                                            onPressed: () {
                                              if (mounted) {
                                                _confettiController.stop();
                                                _confettiController2.stop();
                                                _confettiController3.stop();
                                                Navigator.of(context).pop();
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                            child: const Text(
                                              '닫기',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // X 버튼 (오른쪽 상단)
                                  Positioned(
                                    top: 15,
                                    right: 15,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF7C3AED)
                                                .withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        onPressed: () {
                                          if (mounted) {
                                            _confettiController.stop();
                                            _confettiController2.stop();
                                            _confettiController3.stop();
                                            _confettiController4.stop();
                                            _confettiController5.stop();
                                            _confettiController6.stop();
                                            Navigator.of(context).pop();
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.close,
                                          color: Color(0xFF7C3AED),
                                          size: 24,
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 별 모양 파티클을 그리는 함수
  Path drawStar(Size size) {
    // Method to convert degree to radians
    double degToRad(double deg) => deg * (pi / 180.0);

    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final Path path = Path();
    final double fullAngle = 360 / numberOfPoints;

    path.moveTo(size.width, halfWidth);
    for (int i = 1; i <= numberOfPoints; i++) {
      double pointX = halfWidth + externalRadius * cos(degToRad(i * fullAngle));
      double pointY = halfWidth + externalRadius * sin(degToRad(i * fullAngle));
      path.lineTo(pointX, pointY);

      pointX =
          halfWidth + internalRadius * cos(degToRad((i - 0.5) * fullAngle));
      pointY =
          halfWidth + internalRadius * sin(degToRad((i - 0.5) * fullAngle));
      path.lineTo(pointX, pointY);
    }
    path.close();
    return path;
  }

  /// 하트 모양 파티클을 그리는 함수
  Path drawHeart(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;

    path.moveTo(width / 2, height / 4);
    path.cubicTo(width / 4, 0, 0, height / 4, width / 4, height / 2);
    path.lineTo(width / 2, height * 3 / 4);
    path.lineTo(width * 3 / 4, height / 2);
    path.cubicTo(width, height / 4, width * 3 / 4, 0, width / 2, height / 4);
    path.close();

    return path;
  }

  /// 원 모양 파티클을 그리는 함수
  Path drawCircle(Size size) {
    final path = Path();
    path.addOval(Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2,
    ));
    return path;
  }
}
