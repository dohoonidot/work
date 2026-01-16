import 'package:flutter/material.dart';
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart';

/// 🔔 마크다운 스타일 관리 (CoT 렌더링 전용)
///
/// gpt_markdown 도입으로 대부분의 기능이 대체되었으며,
/// 현재는 CoT 렌더링과 색상 유틸리티에서만 사용됩니다.
class MarkdownStyleManager {
  /// br 태그를 실제 줄바꿈으로 변환하는 전처리 함수
  /// (CoT 렌더링에서 사용)
  static String preprocessMarkdown(String markdownText) {
    // <br>, <br/>, <br /> 태그를 모두 줄바꿈으로 변환
    String processed = markdownText
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<BR\s*/?>', caseSensitive: false), '\n');

    // 단일 물결표(~)를 이스케이프 처리 (취소선 방지)
    processed = processed.replaceAllMapped(
        RegExp(r'(?<!~)~(?!~)', multiLine: true), (match) => '\\~');

    // 테이블 헤더 분리선 정규화
    processed = processed.replaceAllMapped(
        RegExp(r'\|\s*:?-+:?\s*(?=\|)', multiLine: true), (match) => '| --- ');

    // 테이블 헤더와 분리선 사이의 공백 정리
    processed = processed.replaceAll(RegExp(r'\|(\s*\n\s*)\|'), '|\n|');

    // 연속된 줄바꿈 정규화
    processed = processed.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 공백 정리
    processed = processed.replaceAll(RegExp(r' +\n\n'), '\n\n');
    processed = processed.replaceAll(RegExp(r'\n\n +'), '\n\n');

    // 유니코드 구분선을 표준 마크다운 구분선으로 변환
    processed = processed.replaceAll(RegExp(r'─{4,}'), '\n---\n');
    processed = processed.replaceAll(RegExp(r'━{4,}'), '\n---\n');
    processed = processed.replaceAll(RegExp(r'═{4,}'), '\n---\n');
    processed = processed.replaceAll(RegExp(r'—{4,}'), '\n---\n');

    return processed;
  }

  /// 색상 유틸리티 메서드들 (CoT 렌더링에서 사용)

  /// 생각 과정 배경색 결정
  static Color getThoughtBackgroundColor(String archiveType) {
    if (archiveType == 'code' || archiveType == 'sap') {
      return const Color(0xFF1E1E1E); // 코딩/SAP 어시스턴트용 어두운 배경
    } else {
      return const Color(0xFF2D2D30); // 일반 아카이브용 어두운 회색 배경
    }
  }

  /// 생각 과정 헤더색 결정
  static Color getThoughtHeaderColor(String archiveType,
      [AppColorScheme? themeColors]) {
    // Light 테마일 경우 검정색으로 설정
    if (themeColors != null && themeColors.name == 'Light') {
      return Colors.black;
    }

    if (archiveType == 'code' || archiveType == 'sap') {
      return const Color(0xFFE8E8E8); // 코딩/SAP용 밝은 회색
    } else {
      return const Color(0xFFD4D4D4); // 일반용 밝은 회색
    }
  }

  /// 구분선 색상 결정
  static Color getDividerColor(String archiveType) {
    if (archiveType == 'code' || archiveType == 'sap') {
      return const Color(0xFF3E3E42); // 코딩/SAP용 어두운 회색
    } else {
      return const Color(0xFF484848); // 일반용 중간 회색
    }
  }
}
