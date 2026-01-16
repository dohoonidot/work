import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart'; // Clipboard 사용을 위해 추가
import 'package:ASPN_AI_AGENT/shared/providers/chat_state.dart';
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart'; // 테마 색상 추가
import 'package:ASPN_AI_AGENT/shared/providers/notification_notifier.dart';
import 'package:ASPN_AI_AGENT/main.dart' show navigatorKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart'; // URL 실행을 위해 추가
import 'package:ASPN_AI_AGENT/shared/utils/common_ui_utils.dart'; // 스낵바 표시를 위해 추가
import 'package:ASPN_AI_AGENT/features/gift/select_gift.dart'; // 선물 고르기 위젯 추가
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart'; // userIdProvider 사용
import 'package:ASPN_AI_AGENT/shared/services/api_service.dart';
import 'package:ASPN_AI_AGENT/ui/screens/admin_leave_approval_screen.dart'; // 결재 승인 화면 추가
import 'package:ASPN_AI_AGENT/ui/screens/voting_screen.dart'; // 공모전 화면 추가
import 'gpt_markdown_renderer.dart'; // 🚀 NEW: gpt_markdown 기반 렌더러
import 'cot_renderer.dart';
import 'utils.dart';
import 'cache_manager.dart';

/// 최적화된 메시지 렌더러 - 메인 클래스
///
/// 이 클래스는 메시지 렌더링을 위한 메인 진입점입니다.
/// 복잡한 마크다운, 코드 블록, Chain of Thought 처리 로직을 다른 클래스로 위임합니다.
class MessageRenderer {
  // FocusNode 관리를 위한 static 인스턴스 - 메모리 누수 방지
  static bool _hasLoggedStreamingMode = false;

  /// 스트리밍 로그 플래그 리셋 (새로운 스트리밍 시작 시 호출)
  static void resetStreamingLogFlag() {
    _hasLoggedStreamingMode = false;
  }

  /// 메시지 위젯 생성 - 단일 진입점
  static Widget buildMessageWidget(Map<String, dynamic> message,
      [ChatState? chatState, AppColorScheme? themeColors]) {
    final int role = message['role'] ?? 1;
    String messageStr = message['message'] ?? '';
    
    // "event: json" 접두사 제거
    messageStr = _removeEventJsonPrefix(messageStr);
    
    final bool isStreaming = message['isStreaming'] ?? false;
    final String archiveType = chatState?.archiveType ?? '';
    final String messageId =
        message['chat_id']?.toString() ?? messageStr.hashCode.toString();
    final int? chatId = message['chat_id'] as int?;

    // 검색 관련 정보
    final String? searchKeyword = chatState?.searchKeyword;
    final int? highlightedChatId = chatState?.highlightedChatId;

    // 수정: 하이라이트 조건 변경 - 키워드가 있고 메시지에 검색어가 포함된 경우에만 하이라이트
    final bool hasSearchTerm = searchKeyword != null &&
        searchKeyword.isNotEmpty &&
        messageStr.toLowerCase().contains(searchKeyword.toLowerCase());

    // 특정 채팅 ID가 지정된 경우 해당 메시지만 하이라이트, 아니면 검색어가 포함된 모든 메시지 하이라이트
    final bool isHighlightedMessage = hasSearchTerm &&
        (highlightedChatId == null ||
            (chatId != null && highlightedChatId == chatId));

    // AI 메시지(role=1)의 로딩 상태 확인
    final bool isLoading = message['isLoading'] == true;

    // 선물 메시지 여부 확인
    final bool isGiftMessage = message['isGiftMessage'] ?? false;
    final bool hasGiftButton = message['hasGiftButton'] ?? false;
    final String? messageType = message['type'];
    final bool isGiftArrival = messageType == 'gift_arrival';

    // 결재 요청 메시지 여부 확인
    final bool isClickable = message['clickable'] ?? false;
    final Map<String, dynamic>? approvalData = message['approval_data'];

    // 공모전 알림 메시지 여부 확인
    final String? renderType = message['renderType'] as String?;
    final int? contestId = message['contest_id'] as int?;
    final bool isContestDetail = renderType == 'contest_detail';

    // 로딩 상태일 때 로딩 스피너와 메시지 표시
    if (isLoading && role == 1) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 부모 컨테이너 크기에 맞춘 동적 조정
            final availableWidth = constraints.maxWidth;

            return Container(
              constraints: BoxConstraints(
                maxWidth: availableWidth, // 부모 너비에 맞춤
                minWidth: availableWidth * 0.3, // 최소 30% 보장
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      '메시지를 생성하고 있습니다...',
                      style: TextStyle(
                        fontSize: 14,
                        color: themeColors?.aiMessageTextColor ?? Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    // 선물 도착 메시지인 경우 특별한 렌더링
    if (isGiftArrival) {
      return _buildGiftArrivalWidget(message, themeColors);
    }

    // 생일 메시지인 경우 특별한 렌더링 (선물 고르러가기 버튼 포함)
    final bool isBirthdayMessage = message['isBirthdayMessage'] ?? false;
    if (isBirthdayMessage && hasGiftButton) {
      final String? realTimeId = message['id'] as String?;
      print(
          '🔍 DEBUG: 생일 메시지에서 realTimeId 추출 - realTimeId: $realTimeId (타입: ${realTimeId.runtimeType})');
      print('🔍 DEBUG: 전체 메시지 데이터: $message');
      return _buildBirthdayMessageWidget(messageStr, themeColors,
          realTimeId: realTimeId);
    }

    // 선물 메시지인 경우 특별한 렌더링
    if (isGiftMessage && hasGiftButton) {
      final String? realTimeId = message['id'] as String?;
      return _buildGiftMessageWidget(messageStr, themeColors, realTimeId);
    }

    // 공모전 알림 메시지인 경우 특별한 렌더링
    if (isContestDetail && contestId != null) {
      final String title = message['announcement_title'] as String? ?? '';
      final String content = message['announcement_content'] as String? ?? '';
      return _buildContestDetailWidget(title, content, contestId, themeColors);
    }

    // 사용자 메시지(role=0)는 간단한 텍스트로 표시
    if (role == 0) {
      // 첨부 파일 확인
      final attachments = message['attachments'] as List<dynamic>? ?? [];

      List<Widget> messageWidgets = [];

      // 텍스트 메시지 추가
      if (messageStr.isNotEmpty) {
        if (isHighlightedMessage) {
          // 🚀 사용자 메시지 검색 하이라이트 (gpt_markdown 사용)
          messageWidgets.add(GptMarkdownRenderer.renderWithHighlight(
              messageStr, searchKeyword, role, themeColors));
        } else {
          // 🚀 사용자 메시지도 gpt_markdown로 렌더링 (마크다운 지원)
          messageWidgets.add(GptMarkdownRenderer.renderBasicMarkdown(
            messageStr,
            themeColors: themeColors,
            role: role,
            archiveType: archiveType,
          ));
        }
      }

      // 첨부 파일이 있으면 이미지 표시
      if (attachments.isNotEmpty) {
        messageWidgets.add(const SizedBox(height: 8));
        messageWidgets.add(_buildAttachmentDisplay(attachments));
      }

      if (messageWidgets.length == 1) {
        return messageWidgets.first;
      } else {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: messageWidgets,
        );
      }
    }

    // 메시지 렌더링 방식 결정 (Chain of Thought 또는 일반)
    final bool shouldUseCotRendering =
        _shouldUseCoTRendering(message, isStreaming);

    // 디버깅용 로그 (한 번만 출력)
    if (isStreaming && !_hasLoggedStreamingMode) {
      print('=== 스트리밍 렌더링 모드 결정 ===');
      print('아카이브 타입: $archiveType');
      print('아카이브 이름: ${message['archive_name'] ?? ''}');
      print('COT 렌더링 사용: $shouldUseCotRendering');
      print('스트리밍 중: $isStreaming');
      _hasLoggedStreamingMode = true;
    }

    // 🚀 검색 하이라이트가 필요한 경우 (gpt_markdown 적용)
    if (isHighlightedMessage) {
      // </think> 태그가 있는지 확인하여 CoT 부분과 응답 부분 분리
      final int thinkEndIndex = messageStr.indexOf('</think>');
      if (role == 1 &&
          thinkEndIndex != -1 &&
          thinkEndIndex + 9 < messageStr.length) {
        // 🚀 CoT와 응답 분리 렌더링 (gpt_markdown 적용)
        return GptMarkdownRenderer.renderWithCoTSeparation(
            messageStr, themeColors, archiveType);
      }

      // 🚀 일반 메시지 하이라이트 (gpt_markdown 사용)
      return GptMarkdownRenderer.renderWithHighlight(
          messageStr, searchKeyword, role, themeColors);
    }

    // 스트리밍 중일 때는 캐싱하지 않음
    final String themeKey = themeColors != null ? 'themed' : 'default';
    if (!isStreaming && !isHighlightedMessage && themeColors == null) {
      final String cacheKey = '$messageId-$role-$archiveType-$themeKey';
      if (MessageCacheManager.hasMessageWidget(cacheKey)) {
        return MessageCacheManager.getMessageWidget(cacheKey)!;
      }
    }

    // 메시지 파싱
    final parsedParts =
        MessageUtils.parseMessage(messageStr, message, isStreaming);

    // 위젯 리스트 생성
    final List<Widget> contentWidgets = [];

    // 시스템 메시지가 있으면 가장 먼저 표시 (메시지 객체에만)
    if (message['systemMessage'] != null &&
        (message['systemMessage'] as String).isNotEmpty) {
      // 아카이브 타입과 이름 확인
      String archiveType = message['archive_type'] ?? '';
      String archiveName = message['archive_name'] ?? '';

      bool shouldHideSystemMessage = archiveName == '코딩 어시스턴트' ||
          archiveName == 'SAP 어시스턴트' ||
          archiveName == 'AI Chatbot' ||
          archiveType == 'coding' ||
          archiveType == 'sap' ||
          archiveType == 'code';

      if (!shouldHideSystemMessage) {
        contentWidgets.add(
            MessageUtils.buildSystemMessageWidget(message['systemMessage']));
      }
    }

    if (shouldUseCotRendering) {
      // Chain of Thought 렌더링 (생각 과정 + 응답)
      ChainOfThoughtRenderer.buildCoTWidgets(
          parsedParts, isStreaming, chatState, contentWidgets, themeColors);
    } else {
      // 🚀 일반 렌더링 (gpt_markdown 적용)
      final String mainMessage = parsedParts['mainMessage'] as String;

      // 80%의 일반적인 경우: gpt_markdown 사용
      contentWidgets.add(_processMessageContentWithGptMarkdown(
          mainMessage, role, archiveType, themeColors));
    }

    // 메시지에 테이블이 포함되어 있는지 확인

    // 🚀 내부 콘텐츠는 부모 컨테이너(채팅 버블) 크기를 따름
    final double maxWidth = double.infinity; // 부모 컨테이너 크기에 맞춤

    // 메시지 컨테이너 생성 (동적 너비 적용)
    Widget innerWidget = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contentWidgets,
      ),
    );

    // 검색 결과 하이라이트 효과 적용 - 컨테이너 하이라이트 제거
    // 대신 스크롤 포지션 지정을 위한 로직만 유지
    if (isHighlightedMessage && highlightedChatId == chatId) {
      // 스크롤 위치 지정을 위한 코드는 유지할 수 있으나 시각적 하이라이트는 제거
    }

    // 기존 래핑 (필요한 경우)
    Widget resultWidget = MessageUtils.createSelectionContainer(innerWidget);

    // 클릭 가능한 메시지 처리 (결재 요청 등)
    if (isClickable && approvalData != null) {
      resultWidget = GestureDetector(
        onTap: () {
          // Navigator context를 통해 결재 승인 화면으로 이동
          final context = navigatorKey.currentContext;
          if (context != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const AdminLeaveApprovalScreen(),
              ),
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            border:
                Border.all(color: Colors.blue.withValues(alpha: 0.5), width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(4),
          child: resultWidget,
        ),
      );
    }

    // 캐싱 (스트리밍 중이 아니고 하이라이트된 메시지가 아닌 경우)
    if (!isStreaming && !isHighlightedMessage && themeColors == null) {
      MessageCacheManager.checkCacheSize();
      final String cacheKey = '$messageId-$role-$archiveType-$themeKey';
      MessageCacheManager.cacheMessageWidget(cacheKey, resultWidget);
    }

    return resultWidget;
  }

  /// 🚀 새로운 메시지 내용 처리 (하이브리드 시스템 적용)
  static Widget _processMessageContentWithGptMarkdown(
      String content, int role, String archiveType,
      [AppColorScheme? themeColors]) {
    // 디렉토리 트리 구조 패턴 감지 (기존 로직 유지)
    if (MessageUtils.containsDirectoryTree(content)) {
      return MessageUtils.processWithDirectoryTree(
          content, role, archiveType, themeColors);
    }

    // 🔀 하이브리드 시스템: 코드 블록은 CodeBlockRenderer, 나머지는 gpt_markdown
    return MessageUtils.processMessageContent(
        content, role, archiveType, themeColors);
  }

  /// script 태그가 포함된 코드 블록 처리
  static String processScriptTags(String code) {
    final StringBuffer result = StringBuffer();
    final RegExp scriptRegex =
        RegExp(r'<script[^>]*>|</script>', multiLine: true);

    int currentIndex = 0;

    // script 태그 매칭
    for (final match in scriptRegex.allMatches(code)) {
      // script 태그 이전 부분 처리
      final beforeScript = code.substring(currentIndex, match.start);
      result.write(beforeScript);

      // script 태그 처리
      final tag = match.group(0)!;
      if (tag.startsWith('</script>')) {
        result.write('```\n'); // JavaScript 코드 블록 종료
        result.write(tag); // </script> 태그 추가
      } else {
        result.write(tag); // <script> 태그 추가
        result.write('\n```javascript\n'); // JavaScript 코드 블록 시작
      }

      currentIndex = match.end;
    }

    // 남은 부분 처리
    if (currentIndex < code.length) {
      result.write(code.substring(currentIndex));
    }

    return result.toString();
  }

  /// CoT 렌더링 사용 여부 결정
  static bool _shouldUseCoTRendering(
      Map<String, dynamic> message, bool isStreaming) {
    // 아카이브 타입과 이름 확인
    final String archiveType = message['archive_type'] ?? '';
    final String archiveName = message['archive_name'] ?? '';

    // 사내업무, new chat 등 일반 아카이브에서만 COT 렌더링 적용
    bool isGeneralArchive = !(archiveName == '코딩 어시스턴트' ||
        archiveName == 'SAP 어시스턴트' ||
        archiveName == 'AI Chatbot' ||
        archiveType == 'coding' ||
        archiveType == 'sap' ||
        archiveType == 'code');

    if (isGeneralArchive) {
      // print(
      //     '일반 아카이브에서 COT 렌더링 적용 - 아카이브: $archiveName, 타입: $archiveType, 스트리밍: $isStreaming');
      return true;
    } else {
      print(
          '특정 아카이브에서 COT 렌더링 비활성화 - 아카이브: $archiveName, 타입: $archiveType, 스트리밍: $isStreaming');
      return false;
    }
  }

  /// 모든 캐시 초기화
  static void clearAllCaches() {
    MessageCacheManager.clearAllCaches();
  }

  /// 첨부 파일 표시 위젯 생성
  static Widget _buildAttachmentDisplay(List<dynamic> attachments) {
    // 이미지와 일반 파일 분리
    List<dynamic> imageAttachments = [];
    List<dynamic> fileAttachments = [];

    for (var attachment in attachments) {
      final String mimeType = attachment['mimeType'] ?? '';
      if (mimeType.startsWith('image/') && attachment['bytes'] != null) {
        imageAttachments.add(attachment);
      } else {
        fileAttachments.add(attachment);
      }
    }

    List<Widget> widgets = [];

    // 이미지 표시
    if (imageAttachments.isNotEmpty) {
      widgets.add(_buildImageGrid(imageAttachments));
    }

    // 일반 파일 표시
    for (var attachment in fileAttachments) {
      final String fileName = attachment['name'] ?? '';
      final String mimeType = attachment['mimeType'] ?? '';
      final int fileSize = attachment['size'] ?? 0;

      widgets.add(_buildFileAttachment(fileName, mimeType, fileSize));

      if (attachment != fileAttachments.last) {
        widgets.add(const SizedBox(height: 8));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// 이미지 그리드 표시 위젯
  static Widget _buildImageGrid(List<dynamic> imageAttachments) {
    return _ImageGridWidget(images: imageAttachments);
  }

  /// 일반 파일 첨부 위젯
  static Widget _buildFileAttachment(
      String fileName, String mimeType, int fileSize) {
    IconData fileIcon;
    if (mimeType.contains('pdf')) {
      fileIcon = Icons.picture_as_pdf;
    } else if (mimeType.contains('text')) {
      fileIcon = Icons.text_snippet;
    } else {
      fileIcon = Icons.insert_drive_file;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(fileIcon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${(fileSize / 1024).toStringAsFixed(1)}KB',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 렌더링 모드 결정 (캐싱 포함)
  static bool determineRenderingMode(Map<String, dynamic> message) {
    final bool isStreaming = message['isStreaming'] ?? false;

    // 스트리밍 중이면 캐싱하지 않고 바로 계산
    if (isStreaming) {
      return _determineRenderingMode(message);
    }

    // 캐시 키 생성
    final String messageId = message['chat_id']?.toString() ??
        (message['message'] ?? '').hashCode.toString();
    final String cacheKey = messageId;

    // 캐시에 있으면 캐시된 결과 반환
    if (MessageCacheManager.hasRenderingDecision(cacheKey)) {
      return MessageCacheManager.getRenderingDecision(cacheKey)!;
    }

    // 없으면 새로 계산하고 캐싱
    final result = _determineRenderingMode(message);
    MessageCacheManager.cacheRenderingDecision(cacheKey, result);

    return result;
  }

  /// 실제 렌더링 모드 결정 로직
  static bool _determineRenderingMode(Map<String, dynamic> message) {
    final bool isStreaming = message['isStreaming'] ?? false;

    // 아카이브 타입과 이름 재확인 (스트리밍 중에도 적용)
    final String archiveType = message['archive_type'] ?? '';
    final String archiveName = message['archive_name'] ?? '';

    // 사내업무, new chat 등 일반 아카이브에서만 COT 렌더링 적용
    bool isGeneralArchive = !(archiveName == '코딩 어시스턴트' ||
        archiveName == 'SAP 어시스턴트' ||
        archiveName == 'AI Chatbot' ||
        archiveType == 'coding' ||
        archiveType == 'sap' ||
        archiveType == 'code');

    if (isGeneralArchive) {
      // print(
      //     '일반 아카이브에서 COT 렌더링 적용 - 아카이브: $archiveName, 타입: $archiveType, 스트리밍: $isStreaming');
      return true;
    } else {
      print(
          '특정 아카이브에서 COT 렌더링 비활성화 - 아카이브: $archiveName, 타입: $archiveType, 스트리밍: $isStreaming');
      return false;
    }
  }

  // 생일 메시지 위젯 생성 (선물 고르러가기 버튼 포함)
  static Widget _buildBirthdayMessageWidget(
      String message, AppColorScheme? themeColors,
      {String? realTimeId}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 생일 축하 메시지 텍스트
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeColors?.name == 'Dark'
                ? Colors.grey[800]
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: themeColors?.name == 'Dark'
                  ? Colors.grey[600]!
                  : Colors.grey[200]!,
            ),
          ),
          child: GptMarkdownRenderer.renderBasicMarkdown(
            message,
            themeColors: themeColors,
            role: 1,
            archiveType: '',
          ),
        ),

        const SizedBox(height: 16),

        // 선물 고르러가기 버튼 (네온 그라데이션)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              final context = navigatorKey.currentContext;
              if (context != null) {
                try {
                  final container = ProviderScope.containerOf(context);
                  final userId = container.read(userIdProvider);
                  if (userId != null) {
                    // realTimeId를 int로 변환하여 사용
                    print('🔍 [RENDERER] ===== realTimeId 처리 시작 =====');
                    print(
                        '🔍 [RENDERER] 실시간 메시지에서 realTimeId 추출 - realTimeId: $realTimeId (타입: ${realTimeId.runtimeType})');
                    int? convertedRealTimeId;
                    if (realTimeId != null) {
                      convertedRealTimeId = int.tryParse(realTimeId);
                      print(
                          '🔍 [RENDERER] realTimeId를 int로 변환 - convertedRealTimeId: $convertedRealTimeId (타입: ${convertedRealTimeId.runtimeType})');
                    } else {
                      print('🔍 [RENDERER] realTimeId가 null입니다');
                    }
                    print('🔍 [RENDERER] ===== realTimeId 처리 완료 =====');

                    print('🎁 [RENDERER] SelectGift.showGiftSelectionModal 호출');
                    print('   - userId: $userId');
                    print('   - realTimeId: $convertedRealTimeId');
                    SelectGift.showGiftSelectionModal(context, userId,
                        realTimeId: convertedRealTimeId, queueName: "birthday");
                    print('🎁 [RENDERER] ===== 선물 고르기 모달 호출 완료 =====');
                  } else {
                    print('사용자 ID가 없습니다. 로그인이 필요합니다.');
                  }
                } catch (e) {
                  print('사용자 ID 가져오기 오류: $e');
                }
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF8F5FE8), // 네온 퍼플
                    Color(0xFF5EFCE8), // 네온 민트
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8F5FE8).withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.card_giftcard, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    '선물 고르러가기',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 선물 도착 안내 메시지
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: themeColors?.name == 'Dark'
                ? Colors.blue[900]?.withValues(alpha: 0.2)
                : Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: themeColors?.name == 'Dark'
                  ? Colors.blue[700]?.withValues(alpha: 0.3) ??
                      Colors.transparent
                  : Colors.blue[200]!,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: themeColors?.name == 'Dark'
                    ? Colors.blue[300]
                    : Colors.blue[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '선물을 직접 고르세요! 이미 선물을 고르셨다면, 잠시만 기다려주세요. 곧 도착합니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: themeColors?.name == 'Dark'
                        ? Colors.blue[300]
                        : Colors.blue[700],
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 선물 메시지 위젯 생성
  static Widget _buildGiftMessageWidget(
      String message, AppColorScheme? themeColors, String? realTimeId) {
    print('🎁 [RENDERER] ===== 선물 메시지 위젯 생성 시작 =====');
    print('🎁 [RENDERER] 입력 파라미터:');
    print('   - message: $message');
    print('   - realTimeId: $realTimeId');
    print('   - realTimeId 타입: ${realTimeId.runtimeType}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 메시지 텍스트
        GptMarkdownRenderer.renderBasicMarkdown(
          message,
          themeColors: themeColors,
          role: 1,
          archiveType: '',
        ),

        const SizedBox(height: 16),

        // 선물고르기 버튼 (네온 그라데이션)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              print('🎁 [RENDERER] ===== 선물 고르기 버튼 클릭 =====');
              final context = navigatorKey.currentContext;
              if (context != null) {
                try {
                  final container = ProviderScope.containerOf(context);
                  final userId = container.read(userIdProvider);
                  if (userId != null) {
                    // realTimeId를 int로 변환하여 사용
                    print('🔍 [RENDERER] ===== realTimeId 처리 시작 =====');
                    print(
                        '🔍 [RENDERER] 실시간 메시지에서 realTimeId 추출 - realTimeId: $realTimeId (타입: ${realTimeId.runtimeType})');
                    int? convertedRealTimeId;
                    if (realTimeId != null) {
                      convertedRealTimeId = int.tryParse(realTimeId);
                      print(
                          '🔍 [RENDERER] realTimeId를 int로 변환 - convertedRealTimeId: $convertedRealTimeId (타입: ${convertedRealTimeId.runtimeType})');
                    } else {
                      print('🔍 [RENDERER] realTimeId가 null입니다');
                    }
                    print('🔍 [RENDERER] ===== realTimeId 처리 완료 =====');

                    print('🎁 [RENDERER] SelectGift.showGiftSelectionModal 호출');
                    print('   - userId: $userId');
                    print('   - realTimeId: $convertedRealTimeId');
                    SelectGift.showGiftSelectionModal(context, userId,
                        realTimeId: convertedRealTimeId, queueName: "birthday");
                    print('🎁 [RENDERER] ===== 선물 고르기 모달 호출 완료 =====');
                  } else {
                    print('❌ [RENDERER] 사용자 ID가 없습니다. 로그인이 필요합니다.');
                  }
                } catch (e) {
                  print('❌ [RENDERER] 사용자 ID 가져오기 오류: $e');
                }
              } else {
                print('❌ [RENDERER] context가 null입니다.');
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF8F5FE8), // 네온 퍼플
                    Color(0xFF5EFCE8), // 네온 민트
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8F5FE8).withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.card_giftcard, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    '선물고르기',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 선물고르기 모달 표시 메서드

  // 선물 카드 위젯

  // 선물함 열기 메서드
  static void _openGiftBox() async {
    final context = navigatorKey.currentContext;
    if (context != null) {
      try {
        final container = ProviderScope.containerOf(context);
        final userId = container.read(userIdProvider);
        if (userId != null) {
          print('Calling checkGifts API for userId: $userId');
          final giftsResponse = await ApiService.checkGifts(userId);
          print('checkGifts API response: $giftsResponse');

          // 받은 선물 데이터를 선물함 표시용으로 변환
          final gifts = giftsResponse['gifts'] as List<dynamic>? ?? [];
          print('🔍 선물 데이터 분석:');
          print('  - gifts 타입: ${gifts.runtimeType}');
          print('  - gifts 길이: ${gifts.length}');
          print('  - gifts 내용: $gifts');

          if (gifts.isEmpty) {
            print('선물함이 비어있습니다');
            // 빈 선물함 표시
            _showGiftBox(context, []);
          } else {
            print('선물 ${gifts.length}개 발견');
            // 선물 데이터를 선물함 표시용 구조로 변환
            final giftsList = gifts.cast<Map<String, dynamic>>();
            print('  - 변환된 giftsList 길이: ${giftsList.length}');
            print(
                '  - 첫 번째 선물 데이터: ${giftsList.isNotEmpty ? giftsList.first : '없음'}');
            _showGiftBox(context, giftsList);
          }
        } else {
          print('User ID is null, cannot call checkGifts API');
          CommonUIUtils.showErrorSnackBar(context, '사용자 정보를 찾을 수 없습니다.');
        }
      } catch (e) {
        print('Error calling checkGifts API or getting user ID: $e');
        CommonUIUtils.showErrorSnackBar(context, '선물함을 여는 데 실패했습니다.');
      }
    }
  }

  // 선물함 표시 메서드 (AppBar의 _showGiftBox와 동일한 기능)
  static void _showGiftBox(
      BuildContext context, List<Map<String, dynamic>> gifts) {
    // 새 선물 표시 제거
    final container = ProviderContainer();
    try {
      container.read(notificationProvider.notifier).clearNewGiftIndicator();
    } catch (e) {
      print('새 선물 표시 제거 중 오류: $e');
    } finally {
      container.dispose();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 520,
            height: 600,
            decoration: BoxDecoration(
              color: isDarkTheme ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDarkTheme ? Colors.grey[800] : Colors.grey.shade50,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDarkTheme
                              ? Colors.grey[700]
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.card_giftcard,
                          color:
                              isDarkTheme ? Colors.white : Colors.grey.shade700,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          '받은 선물함',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: isDarkTheme
                                ? Colors.white
                                : Colors.grey.shade800,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close,
                            color: isDarkTheme
                                ? Colors.white
                                : Colors.grey.shade600),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // 내용
                Expanded(
                  child: Builder(
                    builder: (context) {
                      // 직접 받은 선물 데이터 사용
                      print('🎁 선물함 내용 렌더링:');
                      print('  - 전달받은 gifts 길이: ${gifts.length}');
                      print('  - gifts 내용: $gifts');

                      if (gifts.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isDarkTheme
                                      ? Colors.grey[800]
                                      : Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.card_giftcard,
                                  size: 48,
                                  color: isDarkTheme
                                      ? Colors.grey[500]
                                      : Colors.grey.shade400,
                                ),
                              ),
                              SizedBox(height: 24),
                              Text(
                                '받은 선물이 없습니다',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isDarkTheme
                                      ? Colors.grey[300]
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '선물이 도착하면\n여기에 표시됩니다',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkTheme
                                      ? Colors.grey[400]
                                      : Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 16),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: EdgeInsets.all(24),
                        itemCount: gifts.length,
                        itemBuilder: (context, index) {
                          final gift = gifts[index];
                          return Container(
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade100,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 헤더
                                    Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.card_giftcard,
                                            color: Colors.grey.shade600,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '생일 축하 선물',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '쿠폰',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // 쿠폰 이미지
                                    if (gift['coupon_img_url'] != null) ...[
                                      GestureDetector(
                                        onTap: () {
                                          _showImageDialog(
                                              context, gift['coupon_img_url']!);
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          height: 140,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.grey.shade200),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Stack(
                                              children: [
                                                Image.network(
                                                  gift['coupon_img_url']!,
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  loadingBuilder: (context,
                                                      child, loadingProgress) {
                                                    if (loadingProgress == null)
                                                      return child;
                                                    return Container(
                                                      color:
                                                          Colors.grey.shade100,
                                                      child: Center(
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            CircularProgressIndicator(
                                                              value: loadingProgress
                                                                          .expectedTotalBytes !=
                                                                      null
                                                                  ? loadingProgress
                                                                          .cumulativeBytesLoaded /
                                                                      loadingProgress
                                                                          .expectedTotalBytes!
                                                                  : null,
                                                              color: Colors.grey
                                                                  .shade400,
                                                            ),
                                                            SizedBox(height: 8),
                                                            Text(
                                                              '이미지 로딩 중...',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .grey
                                                                    .shade600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Container(
                                                      color:
                                                          Colors.grey.shade100,
                                                      child: Center(
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Icon(
                                                                Icons
                                                                    .error_outline,
                                                                color: Colors
                                                                    .grey
                                                                    .shade400),
                                                            SizedBox(height: 4),
                                                            Text(
                                                              '이미지 로드 실패',
                                                              style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .grey
                                                                      .shade600),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                                // 확대 아이콘 오버레이
                                                Positioned(
                                                  top: 8,
                                                  right: 8,
                                                  child: Container(
                                                    padding: EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withValues(
                                                              alpha: 0.6),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Icon(
                                                      Icons.zoom_in,
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],

                                    // 쿠폰 만료 기간
                                    if (gift['coupon_end_date'] != null &&
                                        gift['coupon_end_date']
                                            .toString()
                                            .isNotEmpty) ...[
                                      SizedBox(height: 8),
                                      Padding(
                                        padding:
                                            EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              size: 18,
                                              color: Colors.red.shade600,
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '쿠폰 만료 기간',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Colors.red.shade700,
                                                    ),
                                                  ),
                                                  Text(
                                                    gift['coupon_end_date']
                                                        .toString(),
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          Colors.red.shade800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    // 액션 버튼들
                                    Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => _launchURL(
                                                  gift['coupon_img_url']!),
                                              icon: Icon(Icons.open_in_new,
                                                  size: 16),
                                              label: Text('브라우저에서 열기'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.grey.shade600,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // 시간 정보 (서버 데이터에 시간 정보가 없으므로 현재 시간 사용)
                                    Padding(
                                      padding:
                                          EdgeInsets.fromLTRB(16, 0, 16, 16),
                                      child: Row(
                                        children: [
                                          Icon(Icons.access_time,
                                              size: 12,
                                              color: Colors.grey.shade500),
                                          SizedBox(width: 4),
                                          Text(
                                            _formatDateTime(DateTime.now()),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 이미지 확대 다이얼로그 표시
  static void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // 헤더
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.image, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '쿠폰 이미지',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // 이미지 영역
                Expanded(
                  child: Container(
                    margin: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: InteractiveViewer(
                        panEnabled: true,
                        boundaryMargin: EdgeInsets.all(20),
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                  SizedBox(height: 16),
                                  Text('이미지 로딩 중...'),
                                ],
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 64,
                                    color: Colors.red.shade400,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    '이미지를 불러올 수 없습니다',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.red.shade600,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () => _launchURL(imageUrl),
                                    child: Text('브라우저에서 열기'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // 하단 액션 버튼들
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: () => _copyToClipboard(context, imageUrl),
                        icon: Icon(Icons.copy),
                        label: Text('URL 복사'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _launchURL(imageUrl),
                        icon: Icon(Icons.open_in_new),
                        label: Text('브라우저에서 열기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 날짜 시간 포맷팅 헬퍼
  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // 클립보드에 복사
  static void _copyToClipboard(BuildContext context, String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      CommonUIUtils.showSuccessSnackBar(context, '클립보드에 복사되었습니다');
    } catch (e) {
      CommonUIUtils.showErrorSnackBar(context, '복사 실패: $e');
    }
  }

  // URL 실행 함수
  static Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  static Widget _buildGiftArrivalWidget(
      Map<String, dynamic> message, AppColorScheme? themeColors) {
    final String messageStr = message['message'] ?? '';

    return Container(
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFF8F7FF), // Toss 연보라
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.transparent),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Toss 스타일 아이콘
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFEEF0FB),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFB7B7D7).withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.card_giftcard,
                color: Color(0xFF6C5CE7),
                size: 36,
              ),
            ),
            SizedBox(height: 18),
            // 메인 메시지
            Text(
              '🎉 생일 축하 선물이 도착했어요!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF191F28),
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              messageStr,
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 22),
            // Toss 스타일 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _openGiftBox,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  textStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                child: Text('받은 선물함 이동'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 공모전 알림 메시지 위젯 생성
  static Widget _buildContestDetailWidget(String title, String message,
      int contestId, AppColorScheme? themeColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 공모전 알림 메시지 박스
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF4A6CF7).withValues(alpha: 0.1),
                const Color(0xFF6366F1).withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF4A6CF7).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 아이콘과 헤더
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A6CF7).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.campaign,
                      color: const Color(0xFF4A6CF7),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '공모전 알림',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: themeColors?.name == 'Dark'
                            ? Colors.white
                            : const Color(0xFF4A6CF7),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 제목
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: themeColors?.name == 'Dark'
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              // 메시지 내용
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: themeColors?.name == 'Dark'
                      ? Colors.grey[300]
                      : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 액션 버튼들
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  final context = navigatorKey.currentContext;
                  if (context != null) {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    showDialog(
                      context: context,
                      builder: (context) => ContestDetailDialog(
                        contestId: contestId,
                        isDark: isDark,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('상세보기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A6CF7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final context = navigatorKey.currentContext;
                  if (context != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            VotingScreen(initialContestId: contestId),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('화면 이동'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4A6CF7),
                  side: const BorderSide(color: Color(0xFF4A6CF7)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// "event: json" 접두사 제거 헬퍼 함수
  /// 
  /// 휴가 신청 완료 후 채팅방에 표시되는 메시지에서 "event: json" 부분을 제거하고
  /// 한글 메시지만 표시하도록 처리합니다.
  static String _removeEventJsonPrefix(String message) {
    if (message.isEmpty) return message;
    
    // "event: json" 패턴 제거 (대소문자 구분 없이, 앞뒤 공백 포함)
    final regex = RegExp(r'^event:\s*json\s*', caseSensitive: false);
    final cleanedMessage = message.replaceFirst(regex, '').trim();
    
    return cleanedMessage;
  }
}

/// 이미지 그리드 위젯 - 여러 이미지를 2열로 표시하고 더 보기 기능 제공
class _ImageGridWidget extends StatefulWidget {
  final List<dynamic> images;

  const _ImageGridWidget({required this.images});

  @override
  State<_ImageGridWidget> createState() => _ImageGridWidgetState();
}

class _ImageGridWidgetState extends State<_ImageGridWidget> {
  bool _showAll = false;
  static const int _maxVisibleImages = 4; // 최대 표시할 이미지 수 (2x2)

  @override
  Widget build(BuildContext context) {
    final int totalImages = widget.images.length;
    final bool hasMoreImages = totalImages > _maxVisibleImages;
    final List<dynamic> visibleImages = _showAll
        ? widget.images
        : widget.images.take(_maxVisibleImages).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 이미지 그리드
        _buildImageGrid(visibleImages, hasMoreImages && !_showAll),

        // 더 보기/접기 버튼
        if (hasMoreImages)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showAll = !_showAll;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showAll ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showAll
                          ? '접기'
                          : '더 보기 (+${totalImages - _maxVisibleImages})',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImageGrid(List<dynamic> images, bool showMoreIndicator) {
    if (images.length == 1) {
      // 이미지가 1개일 때는 큰 크기로 표시
      return _buildSingleImage(images.first);
    }

    // 2열 그리드로 표시
    List<Widget> rows = [];
    for (int i = 0; i < images.length; i += 2) {
      List<Widget> rowChildren = [];

      // 첫 번째 이미지
      rowChildren.add(
        Expanded(
          child: _buildGridImage(images[i], false),
        ),
      );

      // 두 번째 이미지가 있으면 추가
      if (i + 1 < images.length) {
        rowChildren.add(const SizedBox(width: 8));

        // 마지막 이미지이고 더 보기 표시가 필요한 경우
        bool isLastAndShowMore =
            showMoreIndicator && (i + 1 == images.length - 1);

        rowChildren.add(
          Expanded(
            child: _buildGridImage(images[i + 1], isLastAndShowMore),
          ),
        );
      } else {
        // 홀수 개일 때 빈 공간
        rowChildren.add(const Expanded(child: SizedBox()));
      }

      rows.add(
        Row(
          children: rowChildren,
        ),
      );

      // 행 간 간격
      if (i + 2 < images.length) {
        rows.add(const SizedBox(height: 8));
      }
    }

    return Column(
      children: rows,
    );
  }

  Widget _buildSingleImage(dynamic image) {
    final String fileName = image['name'] ?? '';
    final dynamic bytes = image['bytes'];
    final int fileSize = image['size'] ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 부모 컨테이너 크기에 맞춘 완전 동적 조정
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;

        // 화면 크기 대신 부모 컨테이너 크기 기준으로 조정
        final maxWidth = availableWidth > 0 ? availableWidth * 0.9 : 400.0;
        final maxHeight = availableHeight > 0 ? availableHeight * 0.8 : 300.0;

        return Container(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            minWidth: 200, // 최소 크기 보장
            minHeight: 150,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // 내용에 맞게 크기 조절
            children: [
              Flexible(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                  child: _buildImageContent(bytes),
                ),
              ),
              _buildImageInfo(fileName, fileSize),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGridImage(dynamic image, bool showMoreOverlay) {
    final String fileName = image['name'] ?? '';
    final dynamic bytes = image['bytes'];
    final int fileSize = image['size'] ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 부모 컨테이너 크기에 맞춘 그리드 이미지 동적 조정
        final availableWidth = constraints.maxWidth;

        // 그리드에서는 부모 크기의 일정 비율로 조정
        final gridImageSize = (availableWidth / 3).clamp(100.0, 150.0);

        return Container(
          width: gridImageSize,
          height: gridImageSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(8)),
                      child: _buildImageContent(bytes),
                    ),
                  ),
                  _buildImageInfo(fileName, fileSize),
                ],
              ),

              // 더 보기 오버레이
              if (showMoreOverlay)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.more_horiz,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+${widget.images.length - _maxVisibleImages}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageContent(dynamic bytes) {
    return bytes is List<int>
        ? Image.memory(
            Uint8List.fromList(bytes),
            fit: BoxFit.contain, // cover 대신 contain으로 변경하여 이미지 전체가 보이도록
            gaplessPlayback: true, // 이미지 교체 시 깜박임 방지
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 200,
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey),
                ),
              );
            },
          )
        : Container(
            height: 200,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.image, color: Colors.grey),
            ),
          );
  }

  Widget _buildImageInfo(String fileName, int fileSize) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.image, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${(fileSize / 1024).toStringAsFixed(1)}KB',
            style: TextStyle(fontSize: 9, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
