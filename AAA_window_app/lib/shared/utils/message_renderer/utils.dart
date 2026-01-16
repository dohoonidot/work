import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ASPN_AI_AGENT/shared/utils/selection_container.dart' as custom;
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart';
import 'gpt_markdown_renderer.dart';
import 'code_block_renderer.dart';

/// 유틸리티 기능을 모아둔 클래스
///
/// 이 클래스는 여러 컴포넌트에서 공통으로 사용되는 유틸리티 함수들을 제공합니다.
class MessageUtils {
  /// 시스템 메시지 위젯 생성
  static Widget buildSystemMessageWidget(String systemMessage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
        child: Text(
          systemMessage.trim(),
          style: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 14,
            color: Colors.white,
            height: 1.8,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// 메시지 파싱 (시스템 메시지와 메인 메시지 분리, 생각 과정 처리)
  static Map<String, dynamic> parseMessage(String messageStr,
      Map<String, dynamic> originalMessage, bool isStreaming) {
    // 시스템 메시지 분리
    RegExp sysMsgRegExp = RegExp(r'^\[(.*?) 답변 입니다\]\s*\n+');
    String systemMessage = '';
    String mainMessage = messageStr;

    final sysMatch = sysMsgRegExp.firstMatch(messageStr);
    if (sysMatch != null) {
      // 괄호와 마침표 제거: [Common 답변 입니다.] -> Common 답변 입니다
      systemMessage = sysMatch.group(1) ?? '';
      mainMessage = messageStr.substring(sysMatch.end);
    }

    // 아카이브 정보 확인
    final String archiveType = originalMessage['archive_type'] ?? '';
    final String archiveName = originalMessage['archive_name'] ?? '';

    // 일반 아카이브 확인 (사내업무, new chat 등)
    bool isGeneralArchive = !(archiveName == '코딩 어시스턴트' ||
        archiveName == 'SAP 어시스턴트' ||
        archiveName == 'AI Chatbot' ||
        archiveType == 'coding' ||
        archiveType == 'sap' ||
        archiveType == 'code');

    // 생각 과정과 응답 부분 분리
    String thoughtPart = originalMessage['thoughtPart'] ?? '';
    String responsePart = originalMessage['responsePart'] ?? '';
    bool hasThoughtCompleted = originalMessage['hasThoughtCompleted'] ?? false;

    // 속성이 제공되지 않았으면 메시지에서 추출
    if (thoughtPart.isEmpty && responsePart.isEmpty) {
      if (isGeneralArchive) {
        // 사내업무, new chat 등 일반 아카이브에서만 </think> 태그로 분리
        final thinkEndRegex = RegExp(r'</think>', multiLine: true);
        final thinkEndMatch = thinkEndRegex.firstMatch(mainMessage);

        if (thinkEndMatch != null) {
          // </think> 태그가 있으면 생각과정과 응답 분리
          thoughtPart = mainMessage.substring(0, thinkEndMatch.end);
          if (thinkEndMatch.end < mainMessage.length) {
            responsePart = mainMessage.substring(thinkEndMatch.end);
          }
          hasThoughtCompleted = true;
        } else {
          // </think> 태그가 없으면 전체를 응답으로 처리
          thoughtPart = '';
          responsePart = mainMessage;
          hasThoughtCompleted = true;
        }
      } else {
        // 코딩 어시스턴트, SAP 어시스턴트, AI Chatbot 등은 COT 사용 안함
        thoughtPart = '';
        responsePart = mainMessage;
        hasThoughtCompleted = true;
      }
    }

    return {
      'systemMessage': systemMessage,
      'mainMessage': mainMessage,
      'thoughtPart': thoughtPart,
      'responsePart': responsePart,
      'hasThoughtCompleted': hasThoughtCompleted,
    };
  }

  /// 선택 컨테이너 생성 (텍스트 선택 기능)
  static Widget createSelectionContainer(Widget child) {
    return custom.SelectionContainer(child: child);
  }

  /// URL 실행 함수
  static Future<void> launchExternalUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        print('URL을 실행할 수 없습니다: $url');
      }
    } catch (e) {
      print('URL 실행 중 오류 발생: $e');
    }
  }

  /// 디렉토리 트리 구조 여부 확인
  static bool containsDirectoryTree(String text) {
    // 디렉토리 트리 패턴 감지: 여러 줄에 걸쳐 ├──, │, └── 등의 문자가 포함된 경우
    final treePattern = RegExp(r'(├──|└──|│   |\.\.\.|/─+)', multiLine: true);
    final hasFolderIndicators = treePattern.hasMatch(text);

    // 추가적으로 src/, main/, resources/ 등의 폴더 구조 패턴도 검사
    final folderPattern =
        RegExp(r'[a-zA-Z0-9_-]+/(\s+[├└]──|$)', multiLine: true);
    final hasFolderPaths = folderPattern.hasMatch(text);

    return hasFolderIndicators || hasFolderPaths;
  }

  /// 디렉토리 트리가 포함된 텍스트 처리
  static Widget processWithDirectoryTree(
      String responseText, int role, String archiveType,
      [AppColorScheme? themeColors]) {
    // 코드 블록을 분리하기 위한 정규식
    RegExp codeBlockRegex =
        RegExp(r'```\s*([A-Za-z0-9]*)\s*\n([\s\S]*?)\n\s*```');
    int currentIndex = 0;
    List<Widget> responseWidgets = [];

    // 코드 블록 매칭
    for (final match in codeBlockRegex.allMatches(responseText)) {
      // 코드 블록 이전 마크다운 텍스트 처리 (🚀 gpt_markdown 사용)
      if (match.start > currentIndex) {
        final markdownPart = responseText.substring(currentIndex, match.start);
        if (markdownPart.trim().isNotEmpty) {
          responseWidgets.add(GptMarkdownRenderer.renderBasicMarkdown(
            markdownPart,
            themeColors: themeColors,
            role: role,
            archiveType: archiveType,
          ));
        }
      }

      // 디렉토리 트리 코드 블록 처리
      final languageId = match.group(1)?.trim().toLowerCase() ?? '';
      final code = match.group(2)?.trim() ?? '';

      // 🚀 markdown 언어인 경우 백틱을 무시하고 일반 마크다운으로 렌더링
      if (languageId == 'markdown' || languageId == 'md') {
        responseWidgets.add(GptMarkdownRenderer.renderBasicMarkdown(
          code,
          themeColors: themeColors,
          role: role,
          archiveType: archiveType,
        ));
      }
      // 코드 내용에 디렉토리 트리 구조가 포함되어 있는지 확인
      else if (containsDirectoryTree(code)) {
        // 🌳 디렉토리 트리를 위한 특수 처리 (기존 방식 유지)
        responseWidgets
            .add(CodeBlockRenderer.buildDirectoryTreeBlock(code, themeColors));
      } else if (languageId.isEmpty) {
        // 🔧 언어가 없어도 코드 블록으로 처리하여 테마별 배경색과 스타일 적용
        responseWidgets.add(
            CodeBlockRenderer.buildCodeBlock(code, 'plaintext', themeColors));
      } else {
        // 🎨 일반 코드 블록 처리 (기존 CodeBlockRenderer 사용 - 테마별 구문 강조)
        responseWidgets.add(
            CodeBlockRenderer.buildCodeBlock(code, languageId, themeColors));
      }

      currentIndex = match.end;
    }

    // 남은 마크다운 텍스트 처리 (🚀 gpt_markdown 사용)
    if (currentIndex < responseText.length) {
      final markdownPart = responseText.substring(currentIndex);
      if (markdownPart.trim().isNotEmpty) {
        responseWidgets.add(GptMarkdownRenderer.renderBasicMarkdown(
          markdownPart,
          themeColors: themeColors,
          role: role,
          archiveType: archiveType,
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: responseWidgets,
    );
  }

  /// 메시지 내용(마크다운, 코드 블록) 처리
  static Widget processMessageContent(
      String content, int role, String archiveType,
      [AppColorScheme? themeColors]) {
    // 디렉토리 트리 구조 패턴 감지
    if (containsDirectoryTree(content)) {
      return processWithDirectoryTree(content, role, archiveType, themeColors);
    }

    // 🚀 하이브리드 방식: 코드 블록은 기존 방식(테마별 구문 강조), 나머지는 gpt_markdown

    // 코드 블록 매칭을 위한 정규식
    final RegExp codeBlockRegex =
        RegExp(r'```\s*([A-Za-z0-9]*)\s*\n([\s\S]*?)\n\s*```', multiLine: true);
    final List<Widget> contentWidgets = [];

    int currentIndex = 0;

    // 코드 블록 처리
    for (final match in codeBlockRegex.allMatches(content)) {
      // 코드 블록 이전 마크다운 처리 (🚀 gpt_markdown 사용)
      if (match.start > currentIndex) {
        final markdownPart = content.substring(currentIndex, match.start);
        if (markdownPart.trim().isNotEmpty) {
          contentWidgets.add(GptMarkdownRenderer.renderBasicMarkdown(
            markdownPart,
            themeColors: themeColors,
            role: role,
            archiveType: archiveType,
          ));
        }
      }

      // 언어가 지정되지 않은 경우 gpt_markdown으로 렌더링
      final languageId = match.group(1)?.trim().toLowerCase() ?? '';
      final code = match.group(2)?.trim() ?? '';

      // 🚀 markdown 언어인 경우 백틱을 무시하고 일반 마크다운으로 렌더링
      if (languageId == 'markdown' || languageId == 'md') {
        contentWidgets.add(GptMarkdownRenderer.renderBasicMarkdown(
          code,
          themeColors: themeColors,
          role: role,
          archiveType: archiveType,
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
        contentWidgets.add(GptMarkdownRenderer.renderBasicMarkdown(
          markdownPart,
          themeColors: themeColors,
          role: role,
          archiveType: archiveType,
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contentWidgets,
    );
  }

  /// 마크다운 메시지 포맷팅 (테이블 처리)
  static String formatMarkdownMessage(String text) {
    text = text.replaceAll(RegExp(r'\b(null|NULL)\b'), '없음');

    // 테이블 형식 감지 (최소 2행 이상의 파이프 구조)
    List<String> lines = text.split('\n');
    int tableStartIndex = -1;
    int tableEndIndex = -1;

    // 연속된 파이프 라인을 찾아 테이블 영역 확정
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();

      // 파이프가 포함된 줄인지 확인
      if (line.contains('|') && line.isNotEmpty) {
        if (tableStartIndex == -1) {
          tableStartIndex = i;
        }
        tableEndIndex = i;
      } else if (tableStartIndex != -1 && line.isEmpty) {
        // 빈 줄이 나오면 테이블 종료 가능성 (빈 줄은 스킵)
        continue;
      } else if (tableStartIndex != -1) {
        // 파이프가 없는 비어있지 않은 줄이 나오면 테이블 종료
        break;
      }
    }

    // 실제 테이블인지 확인 (최소 2행 이상 및 헤더 분리선 존재)
    bool isValidTable = tableStartIndex != -1 &&
        tableEndIndex > tableStartIndex &&
        (tableEndIndex - tableStartIndex + 1) >= 2;

    // 헤더 분리선이 있는지 추가 확인
    if (isValidTable) {
      bool hasHeaderSeparator = false;
      for (int i = tableStartIndex; i <= tableEndIndex; i++) {
        String line = lines[i].trim();
        if (RegExp(r'^\s*\|\s*(:?-+:?\s*\|)+\s*$').hasMatch(line)) {
          hasHeaderSeparator = true;
          break;
        }
      }
      isValidTable = hasHeaderSeparator;
    }

    if (!isValidTable) {
      // 테이블이 아니면 원본 텍스트 그대로 반환 (\n\n 보존)
      return text;
    }

    // 테이블이 있는 경우 포맷팅 적용
    String beforeTable =
        tableStartIndex > 0 ? lines.sublist(0, tableStartIndex).join('\n') : '';
    List<String> tableLines = lines.sublist(tableStartIndex, tableEndIndex + 1);
    String afterTable = tableEndIndex < lines.length - 1
        ? lines.sublist(tableEndIndex + 1).join('\n')
        : '';

    // 테이블 셀 내용 정리 및 긴 내용 처리
    List<String> processedTableLines = [];
    for (String line in tableLines) {
      if (line.trim().isEmpty) continue;

      // 파이프로 분할하여 각 셀 처리
      List<String> cells = line.split('|');
      List<String> processedCells = [];

      for (int i = 0; i < cells.length; i++) {
        String cell = cells[i].trim();

        // 🚀 긴 셀 내용의 경우 적절히 줄바꿈 (개선된 임계값: 80자)
        if (cell.length > 80 && !cell.contains('·') && !cell.contains('-')) {
          // 더 자연스러운 줄바꿈 지점 찾기
          cell = _wrapLongTableCell(cell);
        }

        processedCells.add(cell);
      }

      processedTableLines.add(processedCells.join('|'));
    }

    String table = processedTableLines.join('\n');

    // 기존 줄바꿈 패턴을 최대한 보존하면서 테이블 주변만 정리
    String result = '';
    if (beforeTable.isNotEmpty) {
      result += beforeTable;
      if (!beforeTable.endsWith('\n\n')) {
        result += beforeTable.endsWith('\n') ? '\n' : '\n\n';
      }
    }
    result += table;
    if (afterTable.isNotEmpty) {
      if (!afterTable.startsWith('\n\n')) {
        result += afterTable.startsWith('\n') ? '\n' : '\n\n';
      }
      result += afterTable;
    }

    return result;
  }

  /// 🚀 긴 테이블 셀 내용을 적절히 줄바꿈 (개선된 버전)
  static String _wrapLongTableCell(String cellContent) {
    if (cellContent.length <= 80) return cellContent;

    // 더 자연스러운 줄바꿈 지점 찾기 (우선순위 순)
    final breakPoints = [
      ', ',
      '; ',
      '. ',
      ') ',
      '】 ',
      '】',
      ': ',
      ' - ',
      ' / ',
      ' | '
    ];

    for (String breakPoint in breakPoints) {
      if (cellContent.contains(breakPoint)) {
        // 한 번에 모든 브레이크 포인트를 변경하지 않고, 80자 간격으로 제한
        String result = '';
        List<String> parts = cellContent.split(breakPoint);
        String currentLine = '';

        for (int i = 0; i < parts.length; i++) {
          String nextPart = parts[i] + (i < parts.length - 1 ? breakPoint : '');

          if (currentLine.length + nextPart.length > 80 &&
              currentLine.isNotEmpty) {
            result += currentLine.trimRight() + '<br/>';
            currentLine = nextPart;
          } else {
            currentLine += nextPart;
          }
        }

        result += currentLine;
        return result;
      }
    }

    // 브레이크 포인트가 없는 경우 80자마다 강제 줄바꿈
    List<String> chunks = [];
    for (int i = 0; i < cellContent.length; i += 80) {
      chunks.add(cellContent.substring(
          i, i + 80 > cellContent.length ? cellContent.length : i + 80));
    }

    return chunks.join('<br/>');
  }

  /// 🚀 markdown 코드 블록 테스트용 샘플 생성 (개발자 도구)
  static String getMarkdownCodeBlockTest() {
    return '''
일반 텍스트입니다.

```markdown
# 마크다운 제목

이것은 **굵은 텍스트**이고 *기울임 텍스트*입니다.

## 테이블 예시

| 컬럼1 | 컬럼2 | 컬럼3 |
|-------|-------|-------|
| 첫 번째 값<br/>줄바꿈 포함 | 두 번째 값 | 세 번째 값 |
| 데이터1 | 데이터2<br/>여러 줄<br/>내용 | 데이터3 |

## 리스트 예시

- 첫 번째 항목
- 두 번째 항목
  - 하위 항목1
  - 하위 항목2
- 세 번째 항목

1. 번호 리스트 1
2. 번호 리스트 2
3. 번호 리스트 3

> 인용문 블록입니다.

`인라인 코드`도 제대로 작동합니다.
```

코드 블록 다음의 일반 텍스트입니다.

```javascript
// 이것은 일반 JavaScript 코드 블록입니다 (구문 강조 적용됨)
console.log("Hello, World!");
```

마지막 텍스트입니다.
''';
  }
}
