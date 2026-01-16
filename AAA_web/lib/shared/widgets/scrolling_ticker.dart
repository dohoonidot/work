import 'package:flutter/material.dart';
import 'dart:async';

class AnnouncementTicker extends StatefulWidget {
  final String message;
  final double? width;
  final TextStyle? textStyle;
  final Duration? displayDuration;
  final Duration? animationDuration;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  final bool showOnlyWhenMessage;
  final String? announcementPrefix;

  const AnnouncementTicker({
    Key? key,
    required this.message,
    this.width,
    this.textStyle,
    this.displayDuration,
    this.animationDuration,
    this.backgroundColor,
    this.padding,
    this.showOnlyWhenMessage = true,
    this.announcementPrefix,
  }) : super(key: key);

  @override
  State<AnnouncementTicker> createState() => _AnnouncementTickerState();
}

class _AnnouncementTickerState extends State<AnnouncementTicker>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _scrollController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _scrollAnimation;
  Timer? _hideTimer;
  bool _isVisible = false;
  double _containerWidth = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _checkMessageVisibility();
  }

  void _initializeAnimation() {
    // 페이드 인/아웃 애니메이션 지속시간
    Duration duration =
        widget.animationDuration ?? const Duration(milliseconds: 800);

    _controller = AnimationController(
      duration: duration,
      vsync: this,
    );

    // 스크롤 애니메이션 컨트롤러 (고정 속도)
    _scrollController = AnimationController(
      duration: const Duration(seconds: 40), // 고정 35초
      vsync: this,
    );

    // 페이드 애니메이션 (투명도)
    _fadeAnimation = Tween<double>(
      begin: 0.0, // 완전 투명
      end: 1.0, // 완전 불투명
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // 스케일 애니메이션 (크기 변화)
    _scaleAnimation = Tween<double>(
      begin: 0.9, // 살짝 작게 시작
      end: 1.0, // 원래 크기
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    // 스크롤 애니메이션 (좌우 이동)
    _scrollAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scrollController,
      curve: Curves.linear,
    ));
  }

  void _checkMessageVisibility() {
    bool shouldShow = widget.message.isNotEmpty;

    if (shouldShow != _isVisible) {
      setState(() {
        _isVisible = shouldShow;
      });

      if (shouldShow) {
        _startShowing();
      } else {
        _startHiding();
      }
    }
  }

  void _startShowing() {
    if (widget.message.isEmpty) return;

    // 신규 메시지 도착 시 기존 스크롤 중단
    _stopAllAnimations();

    _controller.reset();
    _controller.forward(); // 페이드 인

    // 모든 메시지 무조건 스크롤 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forceStartScrolling();
    });

    // 기본 7초 후 자동 숨김
    Duration displayTime = widget.displayDuration ?? const Duration(seconds: 7);
    _hideTimer?.cancel();
    _hideTimer = Timer(displayTime, () {
      if (mounted) {
        _startHiding();
      }
    });
  }

  // 모든 애니메이션 완전 중단
  void _stopAllAnimations() {
    _scrollController.stop();
    _scrollController.reset();
    _hideTimer?.cancel();
  }

  void _startHiding() {
    _stopAllAnimations(); // 모든 애니메이션 중단
    _controller.reverse(); // 페이드 아웃
  }

  // 모든 메시지 무조건 스크롤 시작
  void _forceStartScrolling() {
    if (!mounted) return;

    // 조건 확인 없이 무조건 스크롤 시작
    _startScrolling();
  }

  // 마키 스크롤 시작 (무조건)
  void _startScrolling() {
    if (!mounted) return; // 조건 검사 제거

    // 고정 스크롤 속도 설정 (텍스트 길이와 무관)
    const int fixedDuration = 30; // 고정 35초

    // 즉시 스크롤 시작 (무조건)
    if (mounted) {
      // 기존 컨트롤러 정리
      _scrollController.dispose();

      // 고정 지속시간으로 컨트롤러 생성
      _scrollController = AnimationController(
        duration: Duration(seconds: fixedDuration),
        vsync: this,
      );

      // 스크롤 애니메이션 재설정
      _scrollAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _scrollController,
        curve: Curves.linear,
      ));

      _scrollController.repeat();
    }
  }

  @override
  void didUpdateWidget(AnnouncementTicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.message != widget.message) {
      _checkMessageVisibility();

      // 메시지가 변경되면 애니메이션 다시 시작
      if (widget.message.isNotEmpty) {
        Duration newDuration =
            widget.animationDuration ?? const Duration(milliseconds: 800);

        if (_controller.duration != newDuration) {
          _controller.dispose();
          _controller = AnimationController(
            duration: newDuration,
            vsync: this,
          );
          _fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: _controller,
            curve: Curves.easeInOut,
          ));
          _scaleAnimation = Tween<double>(
            begin: 0.9,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutBack,
          ));
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 메시지가 없고 showOnlyWhenMessage가 true면 빈 컨테이너
    if (widget.showOnlyWhenMessage && !_isVisible) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double containerWidth = widget.width ?? constraints.maxWidth;

        return Container(
          width: containerWidth,
          height: 32, // AppBar에 맞는 높이
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          padding: widget.padding ??
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ClipRect(
            child: _isVisible
                ? AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 공지사항 아이콘 및 프리픽스
                              Icon(
                                Icons.campaign,
                                size: 16,
                                color: widget.textStyle?.color ??
                                    Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.announcementPrefix ?? '공지사항',
                                style: (widget.textStyle ??
                                        TextStyle(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.color,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ))
                                    .copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRect(
                                  child: _buildScrollingText(), // 모든 메시지 스크롤 처리
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : Container(), // 메시지가 없을 때 빈 컨테이너
          ),
        );
      },
    );
  }

  Widget _buildScrollingText() {
    return AnimatedBuilder(
      animation: _scrollAnimation,
      builder: (context, child) {
        double totalDistance = 2000.0; // 고정 거리
        // 텍스트가 완전히 오른쪽 밖에서 시작해서 왼쪽으로 이동
        double scrollOffset =
            _containerWidth + 100 - (_scrollAnimation.value * totalDistance);

        String displayMessage = widget.message.replaceAll('\n', ' ');
        String repeatedMessage =
            '$displayMessage    •    $displayMessage    •    $displayMessage    •    ';

        return Transform.translate(
          offset: Offset(scrollOffset, 0),
          child: Text(
            repeatedMessage,
            style: widget.textStyle ??
                TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
            overflow: TextOverflow.visible,
            textAlign: TextAlign.left,
            softWrap: false, // 한 줄로 유지
          ),
        );
      },
    );
  }
}
