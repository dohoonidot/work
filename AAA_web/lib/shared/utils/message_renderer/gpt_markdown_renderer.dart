import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🚀 Clipboard 기능을 위해 추가
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart';
import 'package:url_launcher/url_launcher.dart'; // 🚀 URL 실행을 위해 추가
import 'code_block_renderer.dart'; // 🎨 코드 블록 테마 하이라이팅을 위해 추가

/// GPT Markdown을 사용한 간단한 렌더러
/// 기존 복잡한 MarkdownStyleManager를 대체하여 80% 이상의 코드 간소화
class GptMarkdownRenderer {
  /// 기본 마크다운 렌더링 (80% 케이스 처리)
  ///
  /// 장점:
  /// - AI 응답 최적화 (ChatGPT, Gemini)
  /// - LaTeX 수학 공식 자동 지원
  /// - 체크박스/라디오 버튼 지원
  /// - 향상된 테이블 렌더링
  /// - 코드 간소화 (410줄 → 50줄)
  /// - 🚀 링크 버튼 기능 추가
  /// - 🎨 코드 블록 테마 하이라이팅 지원
  static Widget renderBasicMarkdown(
    String content, {
    TextStyle? style,
    AppColorScheme? themeColors,
    int role = 1,
    String archiveType = '',
    double? maxWidthFactor, // 표 최대 너비 비율 (예: 0.5 = 50%, null = 전체 너비)
  }) {
    // 색상 결정 (기존 로직 단순화)
    Color textColor = _getTextColor(role, archiveType, themeColors);

    // 🚀 링크 추출 및 제거 (버튼으로 표시하기 위해)
    final linkData = _extractLinks(content);
    final cleanedContent = linkData['cleanedContent'] as String;
    final links = linkData['links'] as List<Map<String, String>>;

    String processedContent;

    // 🚀 테이블이 있는 경우와 없는 경우를 분리 처리
    if (_containsTable(cleanedContent)) {
      // 테이블이 있는 경우: <br> 태그 보존하여 커스텀 테이블 위젯에서 처리
      processedContent = _preprocessTableForAI(cleanedContent);
      processedContent = _validateAndFixTable(processedContent);
    } else {
      // 테이블이 없는 경우: <br> 태그를 줄바꿈으로 변환
      processedContent = cleanedContent;
      processedContent = processedContent.replaceAll(
          RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
      processedContent = processedContent.replaceAll(
          RegExp(r'<BR\s*/?>', caseSensitive: false), '\n');
    }
    
    // 🚀 \n을 실제 줄바꿈으로 변환 (알림함 휴가계획 등에서 필요)
    processedContent = processedContent.replaceAll('\\n', '\n');
    processedContent = processedContent.replaceAll(RegExp(r'\r\n'), '\n');
    processedContent = processedContent.replaceAll(RegExp(r'\r'), '\n');

    // 🚀 테이블이 포함된 경우 새로운 하이브리드 렌더링 사용
    if (_containsTable(processedContent)) {
      return _renderHybridMarkdownWithTable(
        processedContent,
        links,
        style: style,
        textColor: textColor,
        themeColors: themeColors,
        role: role,
        archiveType: archiveType,
        maxWidthFactor: maxWidthFactor,
      );
    }

    // 🎨 코드 블록 처리 - utils.dart와 동일한 하이브리드 방식 적용
    return _renderHybridMarkdownWithCodeBlocks(
      processedContent,
      links,
      style: style,
      textColor: textColor,
      themeColors: themeColors,
      role: role,
      archiveType: archiveType,
    );
  }

  /// 🚀 콘텐츠를 테이블과 일반 마크다운으로 분리
  static List<Map<String, dynamic>> _splitContentByTable(String content) {
    final List<Map<String, dynamic>> parts = [];
    final lines = content.split('\n');
    final List<String> currentPart = [];
    bool inTable = false;
    List<String> currentTable = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isTableLine = line.contains('|') && line.trim().isNotEmpty;
      final isHeaderSeparator =
          RegExp(r'^\s*\|\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|\s*$').hasMatch(line);

      if (isTableLine || isHeaderSeparator) {
        if (!inTable) {
          // 테이블 시작 - 이전 마크다운 파트 저장
          if (currentPart.isNotEmpty) {
            parts.add({
              'type': 'markdown',
              'content': currentPart.join('\n').trim(),
            });
            currentPart.clear();
          }
          inTable = true;
        }
        currentTable.add(line);
      } else {
        if (inTable) {
          // 테이블 종료 - 테이블 파트 저장
          if (currentTable.isNotEmpty) {
            final tableData = _parseTableData(currentTable.join('\n'));
            final normalizedTableData = _normalizeTableData(tableData);
            parts.add({
              'type': 'table',
              'content': currentTable.join('\n'),
              'data': normalizedTableData,
            });
            currentTable.clear();
          }
          inTable = false;
        }

        if (line.trim().isNotEmpty || currentPart.isNotEmpty) {
          currentPart.add(line);
        }
      }
    }

    // 마지막 파트 처리
    if (inTable && currentTable.isNotEmpty) {
      final tableData = _parseTableData(currentTable.join('\n'));
      final normalizedTableData = _normalizeTableData(tableData);
      parts.add({
        'type': 'table',
        'content': currentTable.join('\n'),
        'data': normalizedTableData,
      });
    } else if (currentPart.isNotEmpty) {
      parts.add({
        'type': 'markdown',
        'content': currentPart.join('\n').trim(),
      });
    }

    return parts;
  }

  /// 🚀 테이블 데이터 파싱
  static List<List<String>> _parseTableData(String tableContent) {
    final lines = tableContent.split('\n');
    final List<List<String>> rows = [];

    for (String line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.contains('|') && trimmedLine.isNotEmpty) {
        // 헤더 분리선 스킵
        if (RegExp(r'^\s*\|\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|\s*$')
            .hasMatch(trimmedLine)) {
          continue;
        }

        // 셀 데이터 추출
        final cells = trimmedLine
            .split('|')
            .map((cell) => cell.trim())
            .where((cell) => cell.isNotEmpty)
            .toList();

        if (cells.isNotEmpty) {
          rows.add(cells);
        }
      }
    }

    return rows;
  }

  /// 🚀 테이블 데이터 정규화 (불규칙한 행 길이 수정)
  static List<List<String>> _normalizeTableData(List<List<String>> tableData) {
    if (tableData.isEmpty) return tableData;

    // 최대 열 개수 찾기
    int maxColumns = 0;
    for (final row in tableData) {
      if (row.length > maxColumns) {
        maxColumns = row.length;
      }
    }

    // 모든 행을 최대 열 개수에 맞춰 정규화
    final List<List<String>> normalizedData = [];
    for (final row in tableData) {
      final List<String> normalizedRow = List.from(row);

      // 부족한 열은 빈 문자열로 채우기
      while (normalizedRow.length < maxColumns) {
        normalizedRow.add('');
      }

      normalizedData.add(normalizedRow);
    }

    return normalizedData;
  }

  /// 🚀 AI 모델별 테이블 전처리 (GPT-3, Gemini Flash 2.5 최적화)
  static String _preprocessTableForAI(String content) {
    if (!_containsTable(content)) return content;

    final lines = content.split('\n');
    final processedLines = <String>[];
    bool inTable = false;

    for (String line in lines) {
      if (line.contains('|') && line.trim().isNotEmpty) {
        inTable = true;
        String normalizedLine = line;

        // 🚀 테이블 내 br 태그는 이제 커스텀 위젯에서 처리하므로 보존
        // normalizedLine = normalizedLine.replaceAll(
        //     RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
        // normalizedLine = normalizedLine.replaceAll(
        //     RegExp(r'<BR\s*/?>', caseSensitive: false), '\n');

        // 1. 파이프 앞뒤 공백 정규화
        normalizedLine = normalizedLine.replaceAllMapped(
          RegExp(r'\s*\|\s*'),
          (match) => ' | ',
        );

        // 2. 헤더 분리선 표준화 (정렬 기호 보존)
        if (RegExp(r'^\s*\|\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|\s*$')
            .hasMatch(line)) {
          // 좌측 정렬: |---|, 중앙 정렬: |:-:|, 우측 정렬: |--:|
          normalizedLine = normalizedLine.replaceAllMapped(
            RegExp(r':?-+:?'),
            (match) {
              String align = match.group(0)!;
              if (align.startsWith(':') && align.endsWith(':')) {
                return ':---:'; // 중앙 정렬
              } else if (align.endsWith(':')) {
                return '---:'; // 우측 정렬
              } else {
                return '---'; // 좌측 정렬 (기본)
              }
            },
          );
        }

        // 3. 빈 셀 처리 (연속된 파이프 사이에 내용 추가)
        normalizedLine = normalizedLine.replaceAll(RegExp(r'\|\s*\|'), '| - |');

        // 4. 테이블 행 시작/끝 파이프 보장
        normalizedLine = normalizedLine.trim();
        if (!normalizedLine.startsWith('|'))
          normalizedLine = '| $normalizedLine';
        if (!normalizedLine.endsWith('|')) normalizedLine = '$normalizedLine |';

        // 5. 과도한 공백 제거
        normalizedLine = normalizedLine.replaceAll(RegExp(r'\s+'), ' ');

        processedLines.add(normalizedLine);
      } else if (inTable && line.trim().isEmpty) {
        // 테이블 내 빈 줄은 건너뛰기
        continue;
      } else {
        inTable = false;
        processedLines.add(line);
      }
    }

    return processedLines.join('\n');
  }

  /// 🚀 실시간 테이블 검증 및 자동 수정
  static String _validateAndFixTable(String tableContent) {
    final lines = tableContent.split('\n');
    final fixedLines = <String>[];
    int? expectedPipeCount;

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();

      if (line.contains('|') && line.isNotEmpty) {
        // 현재 파이프 개수 계산
        final currentPipeCount = '|'.allMatches(line).length;

        // 첫 번째 테이블 행에서 기준 파이프 개수 설정
        if (expectedPipeCount == null &&
            !RegExp(r'^\s*\|\s*:?-+:?').hasMatch(line)) {
          expectedPipeCount = currentPipeCount;
        }

        // 파이프 개수 일관성 확인 및 수정
        if (expectedPipeCount != null &&
            currentPipeCount != expectedPipeCount &&
            !RegExp(r'^\s*\|\s*:?-+:?').hasMatch(line)) {
          // 파이프 개수가 부족한 경우 빈 셀 추가
          if (currentPipeCount < expectedPipeCount) {
            final missingPipes = expectedPipeCount - currentPipeCount;
            for (int j = 0; j < missingPipes; j++) {
              line += ' - |';
            }
          }
        }

        // 매우 긴 셀 내용 처리 (100자 이상)
        if (line.length > 200) {
          line = _processLongTableCells(line);
        }

        fixedLines.add(line);
      } else {
        fixedLines.add(line);
      }
    }

    return fixedLines.join('\n');
  }

  /// 🚀 긴 테이블 셀 내용 처리
  static String _processLongTableCells(String tableLine) {
    final cells = tableLine.split('|');
    final processedCells = <String>[];

    for (String cell in cells) {
      String processedCell = cell.trim();

      // 100자 이상인 셀은 적절히 줄바꿈
      if (processedCell.length > 100) {
        // 자연스러운 줄바꿈 지점 찾기
        final breakPoints = [', ', '; ', '. ', ') ', '】 ', ': ', ' - '];

        for (String breakPoint in breakPoints) {
          if (processedCell.contains(breakPoint)) {
            processedCell = processedCell =
                processedCell.replaceAll(breakPoint, '$breakPoint');
            break;
          }
        }

        // 브레이크 포인트가 없으면 80자마다 강제 줄바꿈
        if (!processedCell.contains('<br/>')) {
          final chunks = <String>[];
          for (int i = 0; i < processedCell.length; i += 80) {
            chunks.add(processedCell.substring(i,
                i + 80 > processedCell.length ? processedCell.length : i + 80));
          }
          processedCell = chunks.join('');
        }
      }

      processedCells.add(processedCell);
    }

    return processedCells.join('|');
  }

  /// 색상 결정 로직 (기존 복잡한 로직을 간소화)
  static Color _getTextColor(
      int role, String archiveType, AppColorScheme? themeColors) {
    if (themeColors != null) {
      // Light 테마인지 확인
      bool isLightTheme = themeColors.name == 'Light';

      if (isLightTheme) {
        // Light 테마에서는 모든 텍스트를 검정색으로
        return role == 0
            ? Colors.black87 // 사용자 메시지
            : Colors.black87; // AI 메시지
      } else {
        // Dark 테마에서는 기존 색상 사용
        return role == 0
            ? themeColors.userMessageTextColor
            : themeColors.aiMessageTextColor;
      }
    }

    // 기본 색상 설정 (테마가 없는 경우)
    if (archiveType == 'sap' || archiveType == 'code') {
      return Colors.white;
    }

    return role == 0 ? Colors.white : Colors.white;
  }

  /// 테이블 포함 여부 확인
  static bool _containsTable(String content) {
    final lines = content.split('\n');
    int tableRowCount = 0;
    bool hasHeaderSeparator = false;

    for (final line in lines) {
      final trimmedLine = line.trim();

      if (trimmedLine.contains('|') && trimmedLine.isNotEmpty) {
        tableRowCount++;

        // 헤더 분리선 확인
        if (RegExp(r'^\s*\|\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|\s*$')
            .hasMatch(trimmedLine)) {
          hasHeaderSeparator = true;
        }
      } else if (tableRowCount > 0 && trimmedLine.isEmpty) {
        continue;
      } else if (tableRowCount > 0) {
        break;
      }
    }

    return tableRowCount >= 2 && hasHeaderSeparator;
  }

  /// 🚀 수정된 마크다운 렌더링 - 링크 버튼 방식으로 변경
  static Widget _buildMarkdownWithLinks(String content, TextStyle style) {
    // 🚀 br 태그를 먼저 줄바꿈으로 변환 (모든 마크다운에서 처리)
    String processedContent = content;
    processedContent = processedContent.replaceAll(
        RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    processedContent = processedContent.replaceAll(
        RegExp(r'<BR\s*/?>', caseSensitive: false), '\n');
    
    // 🚀 \n을 실제 줄바꿈으로 변환 (알림함 휴가계획 등에서 필요)
    processedContent = processedContent.replaceAll('\\n', '\n');
    processedContent = processedContent.replaceAll(RegExp(r'\r\n'), '\n');
    processedContent = processedContent.replaceAll(RegExp(r'\r'), '\n');

    // 🚀 링크를 제거한 순수 텍스트로 렌더링 (링크는 별도 버튼으로 표시)
    final cleanedContent = processedContent.replaceAll(
        RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1'); // 마크다운 링크를 텍스트만 남김

    // 🔧 일관성 문제 해결: 항상 GptMarkdown 사용
    // 🚀 마크다운 렌더링 개선을 위해 스타일 조정
    return GptMarkdown(
      cleanedContent, 
      style: style.copyWith(
        height: style.height ?? 1.6, // 줄 간격
        fontSize: style.fontSize ?? 14,
      ),
    );
  }

  /// 🚀 검색 하이라이트가 필요한 경우 - GptMarkdown 기반으로 수정
  static Widget renderWithHighlight(
    String content,
    String? searchKeyword,
    int role,
    AppColorScheme? themeColors,
  ) {
    // 🔧 일관성 확보: 검색 하이라이트도 GptMarkdown을 기반으로 처리
    if (searchKeyword == null || searchKeyword.isEmpty) {
      return renderBasicMarkdown(
        content,
        themeColors: themeColors,
        role: role,
        archiveType: '',
      );
    }

    // 하이라이트 처리는 별도로 구현하되, 마크다운 렌더링은 유지
    return _buildHighlightedText(content, searchKeyword, role, themeColors);
  }

  /// 🚀 하이라이트 텍스트 빌드 - GptMarkdown 기반으로 통합
  static Widget _buildHighlightedText(
    String text,
    String? searchKeyword,
    int role,
    AppColorScheme? themeColors,
  ) {
    // 🔧 일관성 확보: 하이라이트 텍스트도 GptMarkdown을 기반으로 처리
    // 검색 키워드 하이라이트는 마크다운 렌더링 후에 처리하는 것이 바람직
    // 우선은 일관성을 위해 GptMarkdown을 사용하고, 하이라이트는 향후 개선

    // Light 테마인지 확인
    bool isLightTheme = themeColors?.name == 'Light';

    // 텍스트 색상 결정
    Color textColor = _getTextColor(role, '', themeColors);

    if (searchKeyword == null || searchKeyword.isEmpty) {
      return GptMarkdown(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontFamily: 'SpoqaHanSansNeo',
        ),
      );
    }

    // 🚀 임시 해결책: 검색 키워드 하이라이트를 위한 기본 텍스트 처리
    // 향후 GptMarkdown 내부에서 하이라이트를 처리하도록 개선 필요
    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerKeyword = searchKeyword.toLowerCase();

    int start = 0;
    while (start < text.length) {
      final int index = lowerText.indexOf(lowerKeyword, start);
      if (index == -1) {
        // 나머지 텍스트 추가
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }

      // 키워드 이전 텍스트
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      // 하이라이트된 키워드
      spans.add(TextSpan(
        text: text.substring(index, index + searchKeyword.length),
        style: TextStyle(
          backgroundColor: isLightTheme ? Colors.yellow : Colors.white,
          color: isLightTheme ? Colors.black : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + searchKeyword.length;
    }

    return SelectableText.rich(
      TextSpan(
        children: spans,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontFamily: 'SpoqaHanSansNeo',
        ),
      ),
    );
  }

  /// CoT와 일반 응답 분리 렌더링
  static Widget renderWithCoTSeparation(
    String messageStr,
    AppColorScheme? themeColors,
    String archiveType,
  ) {
    final int thinkEndIndex = messageStr.indexOf('</think>');

    if (thinkEndIndex != -1 && thinkEndIndex + 9 < messageStr.length) {
      final String thoughtPart = messageStr.substring(0, thinkEndIndex + 9);
      final String responsePart = messageStr.substring(thinkEndIndex + 9);

      // Light 테마인지 확인
      bool isLightTheme = themeColors?.name == 'Light';

      // 텍스트 색상 결정
      Color thoughtTextColor = isLightTheme
          ? Colors.black54 // Light 테마에서는 회색 검정색
          : (themeColors?.aiMessageTextColor ?? Colors.white)
              .withValues(alpha: 0.8);

      Color thoughtLabelColor = isLightTheme
          ? Colors.black87 // Light 테마에서는 검정색
          : themeColors?.aiMessageTextColor ?? Colors.grey;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CoT 부분 (생각 과정)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isLightTheme
                  ? Colors.grey.withValues(alpha: 0.05) // Light 테마에서는 더 연한 배경
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isLightTheme
                      ? Colors.grey
                          .withValues(alpha: 0.2) // Light 테마에서는 더 연한 경계선
                      : Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💭 생각 과정',
                  style: TextStyle(
                    color: thoughtLabelColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  thoughtPart,
                  style: TextStyle(
                    color: thoughtTextColor,
                    fontSize: 13,
                    fontFamily: 'SpoqaHanSansNeo',
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          // 응답 부분 (링크 처리가 포함된 마크다운 렌더링)
          renderBasicMarkdown(
            responsePart,
            themeColors: themeColors,
            role: 1,
            archiveType: archiveType,
          ),
        ],
      );
    }

    // CoT가 없는 경우 일반 렌더링
    return renderBasicMarkdown(
      messageStr,
      themeColors: themeColors,
      role: 1,
      archiveType: archiveType,
    );
  }

  /// 🚀 AI 모델용 완벽한 테이블 형식 가이드 생성
  /// 사용자가 AI에게 테이블을 요청할 때 참고할 수 있는 형식 예시
  static String getTableFormatGuide() {
    return '''
📋 **완벽한 테이블 형식 가이드**

다음 형식으로 표를 만들어주세요:

```
| 헤더1 | 헤더2 | 헤더3 |
|-------|-------|-------|
| 내용1 | 내용2 | 내용3 |
| 내용4 | 내용5 | 내용6 |
```

**주의사항:**
- 각 셀은 파이프(|)로 구분
- 헤더와 데이터 사이에 구분선(---)
- 빈 셀은 '-' 또는 '없음'으로 표시
- 너무 긴 내용은 줄바꿈 고려
- 정렬: 좌측(---), 중앙(:---:), 우측(---:)

**🚀 셀 내부 줄바꿈 예시:**
```
| 제품명 | 설명 |
|--------|------|
| 제품A | 첫 번째 라인<br/>두 번째 라인<br/>세 번째 라인 |
| 제품B | 간단한 설명 |
```
''';
  }

  /// 🚀 br 태그 테이블 테스트 함수 (개발자 도구)
  static String getBrTagTestTable() {
    return '''
테이블 내부 br 태그 테스트:

| 항목 | 내용 |
|------|------|
| 기본 텍스트 | 일반적인 텍스트입니다 |
| br 태그 테스트 | 첫 번째 줄<br/>두 번째 줄<br/>세 번째 줄 |
| BR 태그 테스트 | 첫 번째 줄<BR/>두 번째 줄<BR/>세 번째 줄 |
| 혼합 테스트 | 첫 번째 줄<br>두 번째 줄<br />세 번째 줄 |
| 긴 내용 테스트 | 매우 긴 내용이 있는 경우<br/>자동으로 줄바꿈이 처리되는지<br/>확인해보는 테스트입니다 |
''';
  }

  /// 🚀 WF 시스템 테이블 테스트 함수 (실제 사용 예시)
  static String getWFSystemTestTable() {
    return '''
─────────────────────────────  
1) WF 개요 & 핵심 개념
─────────────────────────────  

| 구분 | 설명 | 실무 팁 |
|------|------|---------|
| 목적 | 업무 프로세스(승인, 알림, 처리) 자동화·모니터링 | "사람 or 시스템 작업을 Workitem 단위로 큐 관리" |
| 실행 엔진 | ABAP 기반, 큐(사서함) + 이벤트 드리븐 | 이벤트=객체 상태 변화(BOR/클래스) |
| 핵심 구성 | • 템플릿(WS*)<br>• 스텝(Task/TS*)<br>• 이벤트<br>• 컨테이너<br>• 에이전트 | 설계(Template) ↔ 실행(Runtime) 분리 |
| 작동 원리 | ① Business Object 이벤트 발생 → ② WF 템플릿 인스턴스 생성 → ③ 개별 스텝이 Workitem 으로 사용자 Inbox 전달 → ④ 결과 피드백 & 다음 스텝 | 모든 데이터는 "컨테이너"로 전달·매핑 |
| 범용성 | ECC·S/4, Fiori Inbox, SAP BTP Workflow, MS Teams 통합 가능 | 클라우드 확장 시 OData/API 활용 |

테이블 다음에 일반 텍스트가 옵니다.
''';
  }

  /// 🚀 테이블 품질 검증 및 점수 계산
  static Map<String, dynamic> validateTableQuality(String content) {
    if (!_containsTable(content)) {
      return {
        'isValid': false,
        'score': 0,
        'issues': ['테이블이 감지되지 않았습니다.']
      };
    }

    List<String> issues = [];
    int score = 100;

    final lines =
        content.split('\n').where((line) => line.contains('|')).toList();

    // 1. 헤더 분리선 확인
    bool hasHeaderSeparator = false;
    for (String line in lines) {
      if (RegExp(r'^\s*\|\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|\s*$').hasMatch(line)) {
        hasHeaderSeparator = true;
        break;
      }
    }

    if (!hasHeaderSeparator) {
      issues.add('헤더 분리선이 없습니다.');
      score -= 30;
    }

    // 2. 파이프 일관성 확인
    int? expectedPipeCount;
    int inconsistentRows = 0;

    for (String line in lines) {
      if (!RegExp(r'^\s*\|\s*:?-+:?').hasMatch(line)) {
        final pipeCount = '|'.allMatches(line).length;
        if (expectedPipeCount == null) {
          expectedPipeCount = pipeCount;
        } else if (pipeCount != expectedPipeCount) {
          inconsistentRows++;
        }
      }
    }

    if (inconsistentRows > 0) {
      issues.add('$inconsistentRows개 행의 열 개수가 일치하지 않습니다.');
      score -= inconsistentRows * 10;
    }

    // 3. 빈 셀 확인
    int emptyCells = 0;
    for (String line in lines) {
      final cells = line.split('|');
      for (String cell in cells) {
        if (cell.trim().isEmpty) {
          emptyCells++;
        }
      }
    }

    if (emptyCells > 0) {
      issues.add('$emptyCells개의 빈 셀이 있습니다.');
      score -= emptyCells * 5;
    }

    // 4. 과도하게 긴 셀 확인
    int longCells = 0;
    for (String line in lines) {
      final cells = line.split('|');
      for (String cell in cells) {
        if (cell.trim().length > 100) {
          longCells++;
        }
      }
    }

    if (longCells > 0) {
      issues.add('$longCells개의 셀이 너무 깁니다. (100자 초과)');
      score -= longCells * 5;
    }

    return {
      'isValid': score >= 70,
      'score': score.clamp(0, 100),
      'issues': issues,
      'rowCount': lines.length,
      'columnCount': expectedPipeCount != null ? expectedPipeCount - 1 : 0,
    };
  }

  /// 🚀 링크 추출 및 제거 (버튼으로 표시하기 위해)
  static Map<String, dynamic> _extractLinks(String content) {
    final RegExp linkRegex = RegExp(
      r'\[(.*?)\]\((.*?)\)', // [텍스트](URL) 패턴
      caseSensitive: false,
    );
    final List<Map<String, String>> links = [];
    final StringBuffer cleanedContent = StringBuffer();

    int lastMatchEnd = 0;
    for (final match in linkRegex.allMatches(content)) {
      // 링크 앞의 텍스트 추가
      if (match.start > lastMatchEnd) {
        cleanedContent.write(content.substring(lastMatchEnd, match.start));
      }

      // 링크 텍스트 추출
      final linkText = match.group(1);
      // 링크 URL 추출
      final linkUrl = match.group(2);

      if (linkText != null && linkUrl != null) {
        // URL이 http나 https로 시작하지 않으면 https를 추가
        String formattedUrl = linkUrl;
        if (!linkUrl.startsWith('http://') && !linkUrl.startsWith('https://')) {
          formattedUrl = 'https://$linkUrl';
        }

        links.add({
          'text': linkText,
          'url': formattedUrl,
        });

        // 링크 텍스트만 남김 (링크 마크다운 제거)
        cleanedContent.write(linkText);
      }
      lastMatchEnd = match.end;
    }

    // 마지막 링크 이후의 텍스트 추가
    if (lastMatchEnd < content.length) {
      cleanedContent.write(content.substring(lastMatchEnd));
    }

    return {
      'cleanedContent': cleanedContent.toString(),
      'links': links,
    };
  }

  /// 🚀 향상된 테이블 렌더링 (동적 너비 확장 + 스크롤바)
  static Widget _renderEnhancedTableWithLinks(
    String content,
    List<Map<String, String>> links, {
    TextStyle? style,
    required Color textColor,
    AppColorScheme? themeColors,
    int role = 1,
    String archiveType = '',
    double? maxWidthFactor,
  }) {
    // 🚀 완전 동적 크기 조정 - 고정 크기 계산 제거
    return LayoutBuilder(
      builder: (context, constraints) {
        // maxWidthFactor가 있으면 적용, 없으면 전체 너비 사용
        final availableWidth = maxWidthFactor != null
            ? constraints.maxWidth * maxWidthFactor
            : constraints.maxWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 넓은 화면에서만 스크롤 힌트 표시 (제거됨)

            // 테이블 콘텐츠 영역 - 완전 동적
            Builder(
              builder: (context) {
                final ScrollController tableScrollController =
                    ScrollController();

                // 기본 마크다운 위젯
                Widget markdownWidget = SelectionArea(
                  child: _buildMarkdownWithLinks(
                    content,
                    style ??
                        TextStyle(
                          color: textColor,
                          fontSize: 14,
                          height: 1.45,
                          fontFamily: 'SpoqaHanSansNeo',
                          letterSpacing: 0.2,
                        ),
                  ),
                );

                // 테이블이 있고 화면이 좁은 경우 스크롤 제공 (maxWidthFactor가 없을 때만)
                if (_containsTable(content) && constraints.maxWidth < 600 && maxWidthFactor == null) {
                  return Scrollbar(
                    controller: tableScrollController,
                    thumbVisibility: true,
                    thickness: 3.0,
                    radius: const Radius.circular(1.5),
                    trackVisibility: false,
                    child: SingleChildScrollView(
                      controller: tableScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: availableWidth, // 최소 너비는 부모와 동일
                          maxWidth: availableWidth * 2, // 최대 너비는 부모의 2배
                        ),
                        child: markdownWidget,
                      ),
                    ),
                  );
                } else {
                  // maxWidthFactor가 있으면 중앙 정렬 및 너비 제한
                  if (maxWidthFactor != null) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: availableWidth),
                        child: markdownWidget,
                      ),
                    );
                  } else {
                    // 일반적인 경우 - 부모 크기에 맞춤
                    return Container(
                      width: double.infinity, // 부모 너비에 완전히 맞춤
                      child: markdownWidget,
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// 🚀 링크 버튼들과 함께 반환
  static Widget _buildMarkdownWithLinkButtons(
    Widget markdownWidget,
    List<Map<String, String>> links,
    AppColorScheme? themeColors,
  ) {
    if (links.isEmpty) {
      return SelectionArea(child: markdownWidget);
    }

    final bool isLightTheme = themeColors?.name == 'Light';
    final List<Widget> linkButtons = [];

    for (final link in links) {
      final String text = link['text']!;
      final String url = link['url']!;

      linkButtons.add(
        Container(
          margin: const EdgeInsets.only(top: 8.0, right: 8.0),
          child: ElevatedButton.icon(
            onPressed: () => _launchUrl(url),
            icon: Icon(
              Icons.open_in_new,
              size: 16,
              color: Colors.white,
            ),
            label: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isLightTheme ? Colors.blue[600] : Colors.blue[500],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 2,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectionArea(child: markdownWidget),
        if (linkButtons.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: linkButtons,
          ),
        ],
      ],
    );
  }

  /// 🚀 URL 실행 함수
  static Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        print('✅ URL 실행 성공: $url');
      } else {
        print('❌ URL을 실행할 수 없습니다: $url');
      }
    } catch (e) {
      print('❌ URL 실행 중 오류 발생: $e');
    }
  }

  /// 🚀 커스텀 테이블 위젯 구현 (br 태그 지원 + 동적 크기 조정 + 연속 드래그 지원)
  static Widget _buildCustomTableWidget(
    List<List<String>> tableData, {
    required Color textColor,
    AppColorScheme? themeColors,
    TextStyle? style,
    double? maxWidthFactor,
  }) {
    // 🚀 마크다운 형식으로 변환하는 함수 (복사 시 사용)
    String convertTableToMarkdown(List<List<String>> data) {
      if (data.isEmpty) return '';

      final StringBuffer buffer = StringBuffer();

      for (int i = 0; i < data.length; i++) {
        final row = data[i];
        buffer.write('| ${row.join(' | ')} |\n');

        // 헤더 다음에 구분선 추가
        if (i == 0) {
          buffer.write('| ${row.map((_) => '---').join(' | ')} |\n');
        }
      }

      return buffer.toString().trim();
    }

    if (tableData.isEmpty) return const SizedBox.shrink();

    // 🚀 테이블 데이터 정규화 (불규칙한 행 길이 수정)
    final normalizedTableData = _normalizeTableData(tableData);

    final bool isLightTheme = themeColors?.name == 'Light';

    // 🚀 동적 크기 조정을 위해 LayoutBuilder 사용
    return LayoutBuilder(
      builder: (context, constraints) {
        // maxWidthFactor가 있으면 적용, 없으면 전체 너비 사용
        final availableWidth = maxWidthFactor != null
            ? constraints.maxWidth * maxWidthFactor
            : constraints.maxWidth;

        // 🚀 기존 Table 위젯 방식 유지하되 SelectionArea로 전체 감싸서 연속 드래그 지원
        final int columnCount = normalizedTableData.first.length;
        final List<TableColumnWidth> columnWidths = List.generate(
          columnCount,
          (index) => const FlexColumnWidth(),
        );

        Widget tableWidget = SelectionArea(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              color: isLightTheme
                  ? Colors.white
                  : Colors.grey[800], // 🎨 라이트 테마는 흰색, 다크 테마는 어두운 회색
              border: Border.all(
                color: isLightTheme
                    ? Colors.grey[400]!
                    : Colors.grey[600]!, // 🎨 테마에 맞는 테두리 색상
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: [
                BoxShadow(
                  color: isLightTheme
                      ? Colors.black.withValues(alpha: 0.1)
                      : Colors.black
                          .withValues(alpha: 0.3), // 🎨 다크 테마에서는 더 진한 그림자
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Table(
              columnWidths: columnWidths.asMap(),
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: isLightTheme
                      ? Colors.grey[300]!
                      : Colors.grey[600]!, // 🎨 테마에 맞는 내부 테두리
                  width: 0.5,
                ),
                verticalInside: BorderSide(
                  color: isLightTheme
                      ? Colors.grey[300]!
                      : Colors.grey[600]!, // 🎨 테마에 맞는 내부 테두리
                  width: 0.5,
                ),
              ),
              children: normalizedTableData.asMap().entries.map((entry) {
                final rowIndex = entry.key;
                final row = entry.value;
                final isHeader = rowIndex == 0;

                return TableRow(
                  decoration: isHeader
                      ? BoxDecoration(
                          color: isLightTheme
                              ? Colors.blue[50]
                              : Colors.blue[900]?.withValues(
                                  alpha:
                                      0.3), // 🎨 라이트 테마는 연한 파란색, 다크 테마는 어두운 파란색
                          border: Border(
                            bottom: BorderSide(
                              color: isLightTheme
                                  ? Colors.blue[200]!
                                  : Colors.blue[600]!, // 🎨 테마에 맞는 헤더 하단 테두리
                              width: 1.0,
                            ),
                          ),
                        )
                      : null,
                  children: row
                      .map((cellContent) => _buildTableCell(
                            cellContent,
                            isHeader: isHeader,
                            textColor: isLightTheme
                                ? Colors.black87
                                : Colors.white, // 🎨 라이트 테마는 검정색, 다크 테마는 흰색
                            themeColors: themeColors,
                            style: style,
                          ))
                      .toList(),
                );
              }).toList(),
            ),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🚀 테이블 선택 힌트와 복사 버튼
            Container(
              margin: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 🚀 테이블 복사 버튼 (마크다운 형식으로)
                  GestureDetector(
                    onTap: () {
                      final tableMarkdown =
                          convertTableToMarkdown(normalizedTableData);
                      Clipboard.setData(ClipboardData(text: tableMarkdown));
                      // 복사 완료 피드백
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('테이블이 마크다운 형식으로 복사되었습니다'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLightTheme
                            ? Colors.blue[50]
                            : Colors.blue[900]?.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLightTheme
                              ? Colors.blue[200]!
                              : Colors.blue[700]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy,
                            size: 12,
                            color: isLightTheme
                                ? Colors.blue[700]
                                : Colors.blue[300],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '복사',
                            style: TextStyle(
                              fontSize: 10,
                              color: isLightTheme
                                  ? Colors.blue[700]
                                  : Colors.blue[300],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 🚀 maxWidthFactor가 있을 때는 중앙 정렬 및 너비 제한
            Builder(
              builder: (context) {
                Widget finalTableWidget = tableWidget;
                
                // maxWidthFactor가 있으면 Center와 ConstrainedBox로 감싸기
                if (maxWidthFactor != null) {
                  finalTableWidget = Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: availableWidth),
                      child: tableWidget,
                    ),
                  );
                }
                
                // 🚀 화면이 좁은 경우 스크롤 제공
                if (availableWidth < 600 && maxWidthFactor == null) {
                  final ScrollController tableScrollController =
                      ScrollController();

                  return Scrollbar(
                    controller: tableScrollController,
                    thumbVisibility: true,
                    thickness: 3.0,
                    radius: const Radius.circular(1.5),
                    trackVisibility: false,
                    child: SingleChildScrollView(
                      controller: tableScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                          maxWidth: constraints.maxWidth * 2,
                        ),
                        child: tableWidget,
                      ),
                    ),
                  );
                } else {
                  // 일반적인 경우 - 부모 크기에 맞춤
                  return SizedBox(
                    width: double.infinity,
                    child: finalTableWidget,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// 🚀 테이블 셀 구현 (br 태그를 실제 줄바꿈으로 처리)
  static Widget _buildTableCell(
    String content, {
    bool isHeader = false,
    required Color textColor,
    AppColorScheme? themeColors,
    TextStyle? style,
  }) {
    // <br> 태그를 기준으로 텍스트 분할
    final textParts = content
        .split(RegExp(r'<br\s*/?>', caseSensitive: false))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    // 🎨 테마 확인
    final bool isLightTheme = themeColors?.name == 'Light';

    // 🎨 테이블용 기본 텍스트 스타일 (테마에 맞는 색상)
    final defaultStyle = TextStyle(
      color: isHeader
          ? (isLightTheme
              ? Colors.blue[800]
              : Colors.blue[300]) // 헤더: 라이트는 진한 파란색, 다크는 밝은 파란색
          : (isLightTheme
              ? Colors.black87
              : Colors.white), // 일반 셀: 라이트는 검정색, 다크는 흰색
      fontSize: isHeader ? 14 : 13,
      fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
      fontFamily: 'SpoqaHanSansNeo',
      height: 1.4,
    );

    final cellStyle = style?.copyWith(
          color: isHeader
              ? (isLightTheme
                  ? Colors.blue[800]
                  : Colors.blue[300]) // 🎨 헤더: 테마에 맞는 파란색
              : (isLightTheme
                  ? Colors.black87
                  : Colors.white), // 🎨 일반 셀: 테마에 맞는 텍스트 색상
          fontSize: isHeader ? 14 : 13,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        ) ??
        defaultStyle;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: textParts.map((part) {
          // 각 파트에 대해 마크다운 처리 (굵은 글씨, 이탤릭 등)
          return Padding(
            padding: const EdgeInsets.only(bottom: 2.0),
            child: _buildCellContent(part, cellStyle),
          );
        }).toList(),
      ),
    );
  }

  /// 🚀 셀 내용 렌더링 (간단한 마크다운 지원) - SelectionArea와 호환되도록 Text 사용
  static Widget _buildCellContent(String content, TextStyle style) {
    // 간단한 마크다운 패턴 처리
    final List<TextSpan> spans = [];
    final RegExp boldRegex = RegExp(r'\*\*(.*?)\*\*');

    int lastEnd = 0;

    // 굵은 글씨 처리
    for (final match in boldRegex.allMatches(content)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: style.copyWith(
          fontWeight: FontWeight.bold,
          color: style.color, // 🎨 굵은 글씨는 기존 텍스트 색상 유지 (테마에 맞게)
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }

    // 🚀 SelectionArea와 호환되도록 일반 Text.rich 사용 (SelectableText 제거)
    return Text.rich(
      TextSpan(children: spans.isEmpty ? [TextSpan(text: content)] : spans),
      style: style,
    );
  }

  /// 🚀 하이브리드 렌더링 - 테이블이 있는 경우 (혼합 콘텐츠 처리)
  static Widget _renderHybridMarkdownWithTable(
    String content,
    List<Map<String, String>> links, {
    TextStyle? style,
    required Color textColor,
    AppColorScheme? themeColors,
    int role = 1,
    String archiveType = '',
    double? maxWidthFactor,
  }) {
    // 테이블만 있는 경우 기존 _renderEnhancedTableWithLinks 사용 (동적 크기 조정)
    if (content.trim().split('\n').every((line) =>
            line.trim().isEmpty ||
            line.contains('|') ||
            RegExp(r'^\s*\|\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|\s*$')
                .hasMatch(line) ||
            line.startsWith('─') // 구분선 허용
        )) {
      return _renderEnhancedTableWithLinks(
        content,
        links,
        style: style,
        textColor: textColor,
        themeColors: themeColors,
        role: role,
        archiveType: archiveType,
        maxWidthFactor: maxWidthFactor,
      );
    }

    // 혼합 콘텐츠인 경우 커스텀 처리
    final parts = _splitContentByTable(content);
    final List<Widget> widgets = [];

    for (final part in parts) {
      if (part['type'] == 'table') {
        // 커스텀 테이블 위젯 (br 태그 지원)
        widgets.add(_buildCustomTableWidget(
          part['data'] as List<List<String>>,
          textColor: textColor,
          themeColors: themeColors,
          style: style,
          maxWidthFactor: maxWidthFactor,
        ));
      } else {
        // 일반 마크다운 (기존 방식)
        final markdownContent = part['content'] as String;
        if (markdownContent.trim().isNotEmpty) {
          widgets.add(_renderHybridMarkdownWithCodeBlocks(
            markdownContent,
            [], // 링크는 나중에 통합 처리
            style: style,
            textColor: textColor,
            themeColors: themeColors,
            role: role,
            archiveType: archiveType,
          ));
        }
      }
    }

    // 링크 버튼과 함께 반환
    return _buildMarkdownWithLinkButtons(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
      links,
      themeColors,
    );
  }

  /// 🎨 하이브리드 렌더링 - 코드 블록은 CodeBlockRenderer, 나머지는 GptMarkdown
  /// utils.dart와 동일한 로직을 적용하여 일관성 확보
  static Widget _renderHybridMarkdownWithCodeBlocks(
    String content,
    List<Map<String, String>> links, {
    TextStyle? style,
    required Color textColor,
    AppColorScheme? themeColors,
    int role = 1,
    String archiveType = '',
  }) {
    // 🎨 코드 블록 매칭을 위한 정규식 (utils.dart와 동일)
    final RegExp codeBlockRegex =
        RegExp(r'```\s*([A-Za-z0-9]*)\s*\n([\s\S]*?)\n\s*```', multiLine: true);
    final List<Widget> contentWidgets = [];

    int currentIndex = 0;
    final double fontSize = 15; // 일반 마크다운 글자크기

    // 🎨 코드 블록 처리 (utils.dart와 동일한 로직)
    for (final match in codeBlockRegex.allMatches(content)) {
      // 코드 블록 이전 마크다운 처리 (🚀 gpt_markdown 사용)
      if (match.start > currentIndex) {
        final markdownPart = content.substring(currentIndex, match.start);
        if (markdownPart.trim().isNotEmpty) {
          contentWidgets.add(_buildMarkdownWithLinks(
            markdownPart,
            style ??
                TextStyle(
                  color: textColor,
                  fontSize: fontSize,
                  height: 1.5,
                  fontFamily: 'SpoqaHanSansNeo',
                ),
          ));
        }
      }

      // 언어 ID와 코드 추출
      final languageId = match.group(1)?.trim().toLowerCase() ?? '';
      final code = match.group(2)?.trim() ?? '';

      // 🚀 markdown 언어인 경우 백틱을 무시하고 일반 마크다운으로 렌더링
      if (languageId == 'markdown' || languageId == 'md') {
        contentWidgets.add(_buildMarkdownWithLinks(
          code,
          style ??
              TextStyle(
                color: textColor,
                fontSize: fontSize,
                height: 1.5,
                fontFamily: 'SpoqaHanSansNeo',
              ),
        ));
      } else if (languageId.isEmpty) {
        // 🔧 언어가 없어도 코드 블록으로 처리하여 테마별 배경색과 스타일 적용
        contentWidgets.add(
            CodeBlockRenderer.buildCodeBlock(code, 'plaintext', themeColors));
      } else {
        // 🎨 언어가 지정된 코드 블록 처리 (기존 CodeBlockRenderer 사용 - 테마별 구문 강조)
        contentWidgets.add(
            CodeBlockRenderer.buildCodeBlock(code, languageId, themeColors));
      }

      currentIndex = match.end;
    }

    // 남은 마크다운 처리 (🚀 gpt_markdown 사용)
    if (currentIndex < content.length) {
      final markdownPart = content.substring(currentIndex);
      if (markdownPart.trim().isNotEmpty) {
        contentWidgets.add(_buildMarkdownWithLinks(
          markdownPart,
          style ??
              TextStyle(
                color: textColor,
                fontSize: fontSize,
                height: 1.5,
                fontFamily: 'SpoqaHanSansNeo',
              ),
        ));
      }
    }

    // 🚀 링크 버튼들과 함께 반환
    return _buildMarkdownWithLinkButtons(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contentWidgets,
      ),
      links,
      themeColors,
    );
  }
}
