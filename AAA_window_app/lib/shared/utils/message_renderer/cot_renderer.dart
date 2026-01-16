import 'package:flutter/material.dart';
import 'package:ASPN_AI_AGENT/shared/providers/chat_state.dart';
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'markdown_style_manager.dart';
import 'gpt_markdown_renderer.dart';

/// Chain of Thought(생각 과정) 렌더링을 담당하는 클래스
///
/// 이 클래스는 AI의 생각 과정과 최종 응답을 시각적으로 구분하여 표시합니다.
class ChainOfThoughtRenderer {
  /// CoT (Chain of Thought) 위젯 구성
  static void buildCoTWidgets(Map<String, dynamic> parsedParts,
      bool isStreaming, ChatState? chatState, List<Widget> contentWidgets,
      [AppColorScheme? themeColors]) {
    // streamChat/withModel API 사용 아카이브에서는 COT 렌더링 완전 차단
    final String archiveType = chatState?.archiveType ?? '';

    // 현재 아카이브 정보를 arvChatHistory에서 찾기
    String archiveName = '';
    if (chatState != null && chatState.currentArchiveId.isNotEmpty) {
      for (var archive in chatState.arvChatHistory) {
        if (archive['archive_id'] == chatState.currentArchiveId) {
          archiveName = archive['archive_name'] ?? '';
          break;
        }
      }
    }

    bool shouldDisableCOT = archiveName == '코딩 어시스턴트' ||
        archiveName == 'SAP 어시스턴트' ||
        archiveName == 'AI Chatbot' ||
        archiveType == 'coding' ||
        archiveType == 'sap' ||
        archiveType == 'code';

    if (shouldDisableCOT) {
      // 로그 출력 제거 - streamChat/withModel API 사용 아카이브에서는 당연히 차단되므로 불필요
      // COT 위젯 생성 차단, 일반 응답만 표시 - GPT Markdown 사용으로 변경
      final String responsePart = parsedParts['responsePart'] as String;
      if (responsePart.isNotEmpty) {
        contentWidgets.add(GptMarkdownRenderer.renderBasicMarkdown(
          responsePart,
          themeColors: themeColors,
          role: 1,
          archiveType: archiveType,
        ));
      }
      return;
    }

    final String thoughtPart = parsedParts['thoughtPart'] as String;
    final String responsePart = parsedParts['responsePart'] as String;
    final bool hasThoughtCompleted = parsedParts['hasThoughtCompleted'] as bool;

    // 생각 과정이 있으면 표시
    if (thoughtPart.isNotEmpty) {
      contentWidgets.add(
        buildThoughtWidget(
          thoughtPart,
          isStreaming,
          hasThoughtCompleted,
          chatState,
          themeColors,
        ),
      );

      // 생각 과정이 완료되었고 응답이 있으면 구분선 추가
      if (hasThoughtCompleted && responsePart.isNotEmpty) {
        contentWidgets.add(_buildDivider(chatState, themeColors));
      }
    }

    // 응답 부분 표시 (있는 경우) - GPT Markdown 사용으로 변경
    if (responsePart.isNotEmpty) {
      contentWidgets.add(GptMarkdownRenderer.renderBasicMarkdown(
        responsePart,
        themeColors: themeColors,
        role: 1,
        archiveType: archiveType,
      ));
    }
  }

  /// 생각 과정 위젯 생성
  static Widget buildThoughtWidget(
    String thoughtText,
    bool isStreaming,
    bool hasThoughtEnded,
    ChatState? chatState, [
    AppColorScheme? themeColors,
  ]) {
    // 헤더 텍스트 결정
    String headerText;
    if (isStreaming) {
      headerText = hasThoughtEnded ? '답변 중...' : '생각 중...';
    } else {
      headerText = '답변 종료';
    }

    // 아카이브 타입에 따른 색상 결정
    final String archiveType = chatState?.archiveType ?? '';
    final bool isLightTheme = themeColors?.name == 'Light';
    final Color backgroundColor = isLightTheme
        ? (themeColors?.backgroundColor ?? Colors.white) // Light 테마: 테마 배경색 사용
        : MarkdownStyleManager.getThoughtBackgroundColor(archiveType);

    final ScrollController scrollController = ScrollController();

    // 스크롤 자동 이동을 위한 후처리 (더 안전한 방식)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients &&
          scrollController.position.maxScrollExtent > 0) {
        try {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        } catch (e) {
          // ScrollController 오류 시 무시
          print('CoT ScrollController 오류 (무시됨): $e');
        }
      }
    });

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLightTheme
              ? Colors.grey.withValues(alpha: 0.3)
              : const Color(0xFF404040),
        ),
        boxShadow: [
          BoxShadow(
            color: isLightTheme
                ? Colors.grey.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 부분
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isLightTheme
                      ? Colors.grey.withValues(alpha: 0.3)
                      : const Color(0xFF4A4A4A),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                isStreaming
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.lightBlueAccent),
                        ),
                      )
                    : const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.lightBlueAccent,
                      ),
                const SizedBox(width: 8),
                Text(
                  headerText,
                  style: TextStyle(
                    color: isLightTheme ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // 내용 부분
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 100,
              minHeight: 50,
            ),
            child: SingleChildScrollView(
              controller: scrollController, // 스크롤 컨트롤러 연결
              padding: const EdgeInsets.all(12),
              child: GptMarkdown(
                MarkdownStyleManager.preprocessMarkdown(thoughtText),
                style: TextStyle(
                  color: isLightTheme ? Colors.black87 : Colors.white,
                  fontSize: 13,
                  fontFamily: 'SpoqaHanSansNeo',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 구분선 위젯 생성
  static Widget _buildDivider(ChatState? chatState,
      [AppColorScheme? themeColors]) {
    final bool isLightTheme = themeColors?.name == 'Light';
    final Color dividerColor = isLightTheme
        ? Colors.grey.withValues(alpha: 0.5)
        : MarkdownStyleManager.getDividerColor(chatState?.archiveType ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: dividerColor,
              thickness: 1.0,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              '최종 응답',
              style: TextStyle(
                color: MarkdownStyleManager.getThoughtHeaderColor(
                    chatState?.archiveType ?? '', themeColors),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: dividerColor,
              thickness: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
