/// Vacation Recommendation Popup UI 상수 및 스타일
///
/// GPT 스타일의 모던한 UI를 위한 색상, 크기, 그림자 등 디자인 상수

import 'package:flutter/material.dart';

/// 색상 팔레트
class VacationUIColors {
  // 메인 그라데이션 (보라-분홍)
  static const primaryGradient = [Color(0xFF667EEA), Color(0xFF764BA2)];

  // 액센트 그라데이션 (진행률바용 - 3색상)
  static const accentGradient = [
    Color(0xFF667EEA),
    Color(0xFF764BA2),
    Color(0xFFFA8BFF)
  ];

  // Light 배경 그라데이션
  static const lightBackgroundGradient = [
    Color(0xFFFAFAFA),
    Color(0xFFFFFFFF),
    Color(0xFFF5F5F7)
  ];

  // Dark 배경 그라데이션
  static const darkBackgroundGradient = [
    Color(0xFF1A1A1A),
    Color(0xFF2D2D2D),
    Color(0xFF242424)
  ];

  // 카드 배경 (Light)
  static const lightCardGradient = [Color(0xFFFFFFFF), Color(0xFFFAFAFA)];

  // 카드 배경 (Dark)
  static const darkCardGradient = [Color(0xFF3A3A3A), Color(0xFF323232)];
}

/// Border Radius 시스템
class VacationUIRadius {
  static const small = 12.0;
  static const medium = 16.0;
  static const large = 20.0;
  static const xLarge = 24.0;
}

/// Spacing 시스템
class VacationUISpacing {
  static const paddingXL = 24.0;
  static const paddingXXL = 32.0;
  static const marginXL = 28.0;
  static const marginXXL = 32.0;
}

/// BoxShadow 프리셋
class VacationUIShadows {
  /// 모달 그림자 (플로팅 효과)
  static List<BoxShadow> modalShadow(bool isDark) => [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.6 : 0.08),
          blurRadius: 40,
          spreadRadius: 0,
          offset: const Offset(0, 20),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.4 : 0.04),
          blurRadius: 20,
          spreadRadius: -5,
          offset: const Offset(0, 10),
        ),
      ];

  /// 카드 그림자 (elevated card)
  static List<BoxShadow> cardShadow(bool isDark) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withOpacity(0.3)
              : const Color(0xFF667EEA).withOpacity(0.08),
          blurRadius: 24,
          spreadRadius: 0,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ];

  /// 아이콘 글로우 효과
  static List<BoxShadow> iconGlowShadow() => [
        BoxShadow(
          color: const Color(0xFF667EEA).withOpacity(0.4),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
}
