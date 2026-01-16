import 'package:ASPN_AI_AGENT/shared/services/api_service.dart';
import 'package:ASPN_AI_AGENT/shared/services/amqp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrivacyAgreementPopup extends StatefulWidget {
  final Future<void> Function(bool) onAgreementChanged;
  final bool canClose; // 팝업을 닫을 수 있는지 여부
  final String userId;

  const PrivacyAgreementPopup({
    super.key,
    required this.onAgreementChanged,
    this.canClose = false,
    required this.userId,
  });

  @override
  State<PrivacyAgreementPopup> createState() => _PrivacyAgreementPopupState();
}

class _PrivacyAgreementPopupState extends State<PrivacyAgreementPopup>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  bool _isProcessing = false;
  bool _hasScrolledToBottom = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();

    // 애니메이션 컨트롤러 초기화
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
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

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    // 스크롤 컨트롤러 초기화
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // 애니메이션 시작
    _scaleController.forward();
    _fadeController.forward();
  }

  void _onScroll() {
    // 스크롤이 끝에 도달했는지 확인
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50) {
      if (!_hasScrolledToBottom) {
        setState(() {
          _hasScrolledToBottom = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleAgreement(bool isAgreed) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    // 햅틱 피드백
    HapticFeedback.mediumImpact();

    try {
      print('🔒 개인정보 동의 처리 시작: $isAgreed');

      // 서버에 먼저 업데이트 (서버 최우선 원칙)
      await ApiService.updatePrivacyAgreement(widget.userId, isAgreed);
      print('✅ 서버 업데이트 완료');

      // AMQP 서비스에 동의 상태 변경 알림 (즉시 큐 생성)
      await amqpService.onPrivacyAgreementChanged(widget.userId, isAgreed);
      print('✅ AMQP 큐 생성 완료');

      // 콜백 호출
      await widget.onAgreementChanged(isAgreed);

      // 약간의 딜레이 후 팝업 닫기
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.of(context).pop(isAgreed);
      }
    } catch (e) {
      print('🚨 개인정보 동의 처리 중 오류: $e');
      setState(() {
        _isProcessing = false;
      });

      // 오류 발생 시 사용자에게 알림
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('개인정보 동의 처리 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.canClose,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
          ),
          child: Center(
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.5,
                      height: MediaQuery.of(context).size.height * 0.85,
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // 헤더
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF4A90E2),
                                  Color(0xFF7BB3F0),
                                ],
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.privacy_tip_outlined,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    '개인정보 수집·이용 동의서',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (widget.canClose)
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // 내용
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 스크롤 가능한 내용
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Scrollbar(
                                        controller: _scrollController,
                                        thumbVisibility: true,
                                        child: SingleChildScrollView(
                                          controller: _scrollController,
                                          padding: const EdgeInsets.all(16),
                                          child: const Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '㈜ASPN(이하 "회사")는 AI 앱 서비스 AAA(이하 "서비스") 제공을 위하여 다음과 같이 개인정보를 수집·이용합니다. 아래 내용을 충분히 읽고 동의 여부를 결정해주시기 바랍니다.',
                                                style: TextStyle(
                                                    fontSize: 14, height: 1.6),
                                              ),
                                              SizedBox(height: 20),
                                              _PolicySection(
                                                title: '1. 수집·이용 목적',
                                                content:
                                                    '• AAA 서비스 제공 및 맞춤형 기능 지원\n• 직원 식별, 내부 커뮤니케이션 및 기념일(생일 등) 알림 기능 제공\n• 서비스 운영 및 품질 개선을 위한 통계 분석',
                                              ),
                                              _PolicySection(
                                                title: '2. 수집 항목',
                                                content:
                                                    '• 기본정보: 이름, 사번, 부서, 직책\n• 생일 등 기념일 정보\n• 서비스 이용 기록, 기기정보(자동 수집 항목 포함)',
                                              ),
                                              _PolicySection(
                                                title: '3. 보유 및 이용기간',
                                                content:
                                                    '• 수집일로부터 퇴사일 또는 서비스 이용 종료 시까지\n• 관련 법령에 따른 보존 필요 시 해당 법령 기준에 따름',
                                              ),
                                              _PolicySection(
                                                title: '4. 동의 거부 권리 및 불이익',
                                                content:
                                                    '• 귀하는 개인정보 수집·이용에 동의하지 않을 수 있습니다. 단, 동의하지 않을 경우 AAA 서비스의 일부 또는 전체 기능 이용이 제한될 수 있습니다.',
                                              ),
                                              SizedBox(height: 20),
                                              Text(
                                                '위 내용을 확인하였으며, 개인정보 수집·이용에 동의합니다.',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // 스크롤 안내 (아직 끝까지 읽지 않은 경우)
                                  if (!_hasScrolledToBottom)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.orange.shade200,
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.keyboard_arrow_down,
                                            color: Colors.orange,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            '동의서를 끝까지 읽어주세요.',
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // 버튼들
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                            ),
                            child: Row(
                              children: [
                                // 거부 버튼
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isProcessing
                                        ? null
                                        : () => _handleAgreement(false),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade400,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _isProcessing
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          )
                                        : const Text(
                                            '동의하지 않음',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),

                                const SizedBox(width: 16),

                                // 동의 버튼
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed:
                                        (_isProcessing || !_hasScrolledToBottom)
                                            ? null
                                            : () => _handleAgreement(true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4A90E2),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: _isProcessing
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          )
                                        : Text(
                                            _hasScrolledToBottom
                                                ? '동의함'
                                                : '전체 내용을 읽어주세요',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
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
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String content;

  const _PolicySection({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4B5563),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
