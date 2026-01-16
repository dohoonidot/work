import 'package:flutter/material.dart';

enum AppThemeMode { light, codingDark, system }

class AppColorScheme {
  final String name;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color onPrimaryColor;
  final Color onSecondaryColor;
  final Color onBackgroundColor;
  final Color onSurfaceColor;
  final Color errorColor;
  final Color successColor;
  final Color warningColor;
  final Color infoColor;
  // 사이드바 색상
  final Color sidebarBackgroundColor;
  final Color sidebarTextColor;
  // 사이드바 그라데이션 색상들
  final Color sidebarGradientStart;
  final Color sidebarGradientEnd;
  // 채팅 색상
  final Color chatUserBubbleColor;
  final Color chatAiBubbleColor;
  final Color chatInputBackgroundColor;
  // AppBar 색상
  final Color appBarBackgroundColor;
  final Color appBarTextColor;
  // AppBar 그라데이션 색상들
  final Color appBarGradientStart;
  final Color appBarGradientEnd;
  // 추가 상세 색상들 (사내업무 페이지와 완전 동일화를 위해)
  final Color textFieldBorderColor;
  final Color textFieldFillColor;
  final Color copyButtonColor;
  final Color scrollButtonColor;
  final Color textColor;
  final Color hintTextColor;
  // 메시지 내 텍스트 색상들 (사내업무 페이지와 완전 동일화를 위해)
  final Color userMessageTextColor; // 사용자 메시지 내 텍스트 색상
  final Color aiMessageTextColor; // AI 메시지 내 텍스트 색상
  final Color markdownTextColor; // 마크다운 텍스트 색상
  final Color codeTextColor; // 인라인 코드 텍스트 색상
  final Color tableTextColor; // 테이블 텍스트 색상
  final Color linkTextColor; // 링크 텍스트 색상
  // 코드 블록 전용 색상들
  final Color codeBlockBackgroundColor; // 코드 블록 배경색
  final Color codeBlockTextColor; // 코드 블록 텍스트 색상

  const AppColorScheme({
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.onPrimaryColor,
    required this.onSecondaryColor,
    required this.onBackgroundColor,
    required this.onSurfaceColor,
    required this.errorColor,
    required this.successColor,
    required this.warningColor,
    required this.infoColor,
    required this.sidebarBackgroundColor,
    required this.sidebarTextColor,
    required this.sidebarGradientStart,
    required this.sidebarGradientEnd,
    required this.chatUserBubbleColor,
    required this.chatAiBubbleColor,
    required this.chatInputBackgroundColor,
    required this.appBarBackgroundColor,
    required this.appBarTextColor,
    required this.appBarGradientStart,
    required this.appBarGradientEnd,
    required this.textFieldBorderColor,
    required this.textFieldFillColor,
    required this.copyButtonColor,
    required this.scrollButtonColor,
    required this.textColor,
    required this.hintTextColor,
    required this.userMessageTextColor,
    required this.aiMessageTextColor,
    required this.markdownTextColor,
    required this.codeTextColor,
    required this.tableTextColor,
    required this.linkTextColor,
    required this.codeBlockBackgroundColor,
    required this.codeBlockTextColor,
  });
}

// 테마별 색상 스킴 정의
class AppColorSchemes {
  static const lightScheme = AppColorScheme(
    name: 'Light',
    primaryColor: Color(0xFF1976D2),
    secondaryColor: Color(0xFF03DAC6),
    backgroundColor: Colors.white,
    surfaceColor: Colors.white, // 순수 흰색으로 변경하여 사내업무와 완전히 동일하게
    onPrimaryColor: Colors.white,
    onSecondaryColor: Colors.black,
    onBackgroundColor: Colors.black,
    onSurfaceColor: Colors.black87,
    errorColor: Color(0xFFB00020),
    successColor: Color(0xFF4CAF50),
    warningColor: Color(0xFFFF9800),
    infoColor: Color(0xFF2196F3),
    sidebarBackgroundColor: Color(0xFFF7F7F8), // ChatGPT 스타일 매우 밝은 회색
    sidebarTextColor: Color(0xFF202123), // ChatGPT 스타일 어두운 텍스트
    // ChatGPT 스타일 미묘한 그라데이션 (매우 밝은 회색)
    sidebarGradientStart: Color(0xFFFAFAFA), // 거의 흰색
    sidebarGradientEnd: Color(0xFFF0F0F0), // 매우 밝은 회색
    chatUserBubbleColor: Colors.white, // Light 테마: 흰색 배경
    chatAiBubbleColor: Color(0xFFF7F7F8), // ChatGPT 스타일 밝은 회색
    chatInputBackgroundColor: Color(0xFFFFFFFF), // 순수한 흰색
    appBarBackgroundColor: Color(0xFFF7F7F8), // 사이드바와 동일
    appBarTextColor: Color(0xFF202123), // 어두운 텍스트
    // AppBar도 동일한 미묘한 그라데이션
    appBarGradientStart: Color(0xFFFAFAFA), // 거의 흰색
    appBarGradientEnd: Color(0xFFF0F0F0), // 매우 밝은 회색
    textFieldBorderColor: Color(0xFFE5E5E5),
    textFieldFillColor: Color(0xFFFFFFFF), // 순수한 흰색
    copyButtonColor: Color(0xFF202123),
    scrollButtonColor: Color(0xFF10A37F), // ChatGPT 스타일 녹색
    textColor: Color(0xFF202123), // ChatGPT 스타일 어두운 텍스트
    hintTextColor: Color(0xFFB3B3B3), // 더 연한 회색 힌트 (기존: 0xFF8E8EA0)
    userMessageTextColor: Colors.black, // 사용자 메시지는 검정색 텍스트
    aiMessageTextColor: Color(0xFF202123), // AI 메시지는 어두운 텍스트
    markdownTextColor: Color(0xFF202123),
    codeTextColor: Color(0xFF202123), // 코드도 어두운 텍스트
    tableTextColor: Color(0xFF202123),
    linkTextColor: Color(0xFF10A37F), // ChatGPT 스타일 녹색 링크
    codeBlockBackgroundColor: Color(0xFFFCFCFC), // Light 테마: 더 밝은 회색 배경
    codeBlockTextColor: Colors.black, // Light 테마: 검정 텍스트
  );

  static const codingDarkScheme = AppColorScheme(
    name: 'Dark',
    primaryColor: Color(0xFF4FC3F7),
    secondaryColor: Color(0xFF81C784),
    backgroundColor: Color.fromARGB(255, 30, 30, 30),
    surfaceColor: Color.fromARGB(255, 40, 40, 40),
    onPrimaryColor: Colors.black,
    onSecondaryColor: Colors.black,
    onBackgroundColor: Colors.white,
    onSurfaceColor: Colors.white,
    errorColor: Color(0xFFE57373),
    successColor: Color(0xFF81C784),
    warningColor: Color(0xFFFFB74D),
    infoColor: Color(0xFF64B5F6),
    sidebarBackgroundColor: Color.fromARGB(255, 30, 30, 30),
    sidebarTextColor: Colors.white,
    sidebarGradientStart: Color.fromARGB(255, 30, 30, 30),
    sidebarGradientEnd: Color.fromARGB(255, 50, 50, 50),
    chatUserBubbleColor: Color.fromARGB(255, 45, 45, 45),
    chatAiBubbleColor: Color.fromARGB(255, 50, 50, 50),
    chatInputBackgroundColor: Color.fromARGB(255, 30, 30, 30),
    appBarBackgroundColor: Color.fromARGB(255, 30, 30, 30),
    appBarTextColor: Colors.white,
    appBarGradientStart: Color.fromARGB(255, 30, 30, 30),
    appBarGradientEnd: Color.fromARGB(255, 50, 50, 50),
    textFieldBorderColor: Color.fromARGB(255, 60, 60, 60),
    textFieldFillColor: Color.fromARGB(255, 30, 30, 30),
    copyButtonColor: Colors.grey,
    scrollButtonColor: Colors.grey,
    textColor: Colors.white,
    hintTextColor: Color(0x80FFFFFF), // 더 연한 회색 힌트 (기존: Colors.grey)
    userMessageTextColor: Colors.white,
    aiMessageTextColor: Colors.white,
    markdownTextColor: Colors.white,
    codeTextColor: Colors.white,
    tableTextColor: Colors.white,
    linkTextColor: Colors.blue,
    codeBlockBackgroundColor: Color(0xff272822), // Dark 테마: 어두운 배경 (모노카이)
    codeBlockTextColor: Colors.white, // Dark 테마: 흰색 텍스트
  );

  static Map<AppThemeMode, AppColorScheme> get allSchemes => {
        AppThemeMode.light: lightScheme,
        AppThemeMode.codingDark: codingDarkScheme,
      };
}
