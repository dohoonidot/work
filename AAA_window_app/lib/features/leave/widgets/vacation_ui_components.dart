/// Vacation Recommendation Popup 재사용 가능한 UI 컴포넌트
///
/// GPT 스타일 UI를 위한 애니메이션 위젯과 스타일링된 컨테이너

import 'package:flutter/material.dart';
import 'vacation_ui_constants.dart';

/// 섹션 페이드인 애니메이션 위젯
///
/// 각 섹션이 부드럽게 나타나도록 페이드인 + 슬라이드 애니메이션 적용
class FadeInSection extends StatefulWidget {
  final Widget child;
  final int delay; // milliseconds

  const FadeInSection({
    super.key,
    required this.child,
    this.delay = 0,
  });

  @override
  State<FadeInSection> createState() => _FadeInSectionState();
}

class _FadeInSectionState extends State<FadeInSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1), // 약간 아래에서 시작
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // 지연 후 애니메이션 시작
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/// 그라데이션 카드 래퍼
///
/// 모든 콘텐츠 박스에 일관된 그라데이션 배경과 플로팅 효과 적용
class GradientCard extends StatelessWidget {
  final Widget child;
  final bool isDarkTheme;
  final EdgeInsets? padding;
  final double borderRadius;

  const GradientCard({
    super.key,
    required this.child,
    required this.isDarkTheme,
    this.padding,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? EdgeInsets.all(VacationUISpacing.paddingXL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkTheme
              ? VacationUIColors.darkCardGradient
              : VacationUIColors.lightCardGradient,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDarkTheme
              ? const Color(0xFF505050).withOpacity(0.5)
              : const Color(0xFFE9ECEF).withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: VacationUIShadows.cardShadow(isDarkTheme),
      ),
      child: child,
    );
  }
}

/// 그라데이션 아이콘 컨테이너
///
/// 아이콘을 그라데이션 배경과 글로우 효과로 강조
class GradientIconContainer extends StatelessWidget {
  final IconData icon;
  final double size;

  const GradientIconContainer({
    super.key,
    required this.icon,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(size * 0.35),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: VacationUIColors.primaryGradient),
        borderRadius: BorderRadius.circular(size * 0.4),
        boxShadow: VacationUIShadows.iconGlowShadow(),
      ),
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}
