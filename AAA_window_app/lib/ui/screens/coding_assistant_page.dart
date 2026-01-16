import 'package:ASPN_AI_AGENT/shared/utils/message_renderer/message_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:flutter/services.dart'; // HardwareKeyboard 사용
import 'package:ASPN_AI_AGENT/features/chat/attachment_preview.dart';
import 'package:ASPN_AI_AGENT/shared/providers/clipboard_provider.dart'
    as clipboard;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:ASPN_AI_AGENT/features/chat/ai_model_selector.dart';
import 'package:ASPN_AI_AGENT/shared/providers/theme_provider.dart'; // 테마 provider 추가
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart'; // AppThemeMode import 추가
import 'package:ASPN_AI_AGENT/shared/utils/common_ui_utils.dart';
import 'package:ASPN_AI_AGENT/shared/utils/file_attachment_utils.dart';
import 'package:ASPN_AI_AGENT/shared/utils/focus_management_utils.dart';
import 'package:ASPN_AI_AGENT/shared/providers/web_search_provider.dart';

class CodingAssistantPage extends ConsumerWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(BuildContext) onSendMessage;
  final ScrollController scrollController;

  const CodingAssistantPage({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSendMessage,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatProvider);
    final isStreaming = chatState.isStreaming;
    final themeState = ref.watch(themeProvider); // 테마 상태 추가

    // Light, Coding Dark 테마일 때는 테마 색상 사용, 다른 테마일 때는 코딩 고유 색상 사용
    final useThemeColors = themeState.themeMode == AppThemeMode.light ||
        themeState.themeMode == AppThemeMode.codingDark;
    final backgroundColor = useThemeColors
        ? themeState.colorScheme.backgroundColor
        : const Color.fromARGB(255, 30, 30, 30);

    final userBubbleColor = useThemeColors
        ? themeState.colorScheme.chatUserBubbleColor
        : const Color.fromARGB(255, 45, 45, 45);
    final aiBubbleColor = useThemeColors
        ? themeState.colorScheme.chatAiBubbleColor
        : const Color.fromARGB(255, 50, 50, 50);

    final copyButtonColor =
        useThemeColors ? themeState.colorScheme.copyButtonColor : Colors.grey;
    final scrollButtonColor =
        useThemeColors ? themeState.colorScheme.scrollButtonColor : Colors.grey;

    // 클립보드 상태 변경 감지하여 사용자 피드백 표시
    ref.listen<clipboard.ClipboardState>(clipboard.clipboardProvider,
        (previous, current) {
      if (current.status == clipboard.ClipboardStatus.success &&
          current.message != null) {
        CommonUIUtils.showInfoSnackBar(context, current.message!);
      } else if (current.status == clipboard.ClipboardStatus.error &&
          current.message != null) {
        CommonUIUtils.showErrorSnackBar(context, current.message!);
      }
    });

    // 여기에 자동 포커스 리스너 로직 추가
    ref.listen<bool>(
      chatProvider.select((state) => state.isStreaming),
      (previous, current) {
        // 스트리밍이 완료되면 텍스트 유무와 관계없이 항상 커서를 끝으로 이동
        if (previous == true && current == false) {
          FocusManagementUtils.requestFocusWithCursorAtEnd(
              focusNode, controller);
        }
      },
    );

    // 새 아카이브 생성 감지하여 자동 포커스 설정 추가
    ref.listen<bool>(
      chatProvider.select((state) => state.isNewArchive),
      (previous, current) {
        // 새 아카이브가 생성되면 텍스트 유무와 관계없이 항상 커서를 끝으로 이동
        if (current == true) {
          FocusManagementUtils.requestFocusWithCursorAtEnd(
              focusNode, controller);
        }
      },
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          // 화면의 아무 곳이나 클릭하면 검색 하이라이트 초기화
          onTap: () {
            // 검색 키워드가 있을 때만 초기화 수행
            if (chatState.searchKeyword != null ||
                chatState.highlightedChatId != null) {
              print('코딩 어시스턴트 화면 탭: 검색 하이라이트 초기화');
              ref.read(chatProvider.notifier).clearSearchHighlight();
            }
          },
          // 다른 탭 이벤트가 동작하도록 behavior 설정
          behavior: HitTestBehavior.translucent,
          child: Container(
            color: backgroundColor,
            child: Column(
              children: [
                Expanded(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      scrollbarTheme: ScrollbarThemeData(
                        thumbColor: MaterialStateProperty.all(Colors.grey[400]),
                        trackColor:
                            MaterialStateProperty.all(Colors.transparent),
                        thickness: MaterialStateProperty.all(8.0),
                        radius: const Radius.circular(4),
                        thumbVisibility: MaterialStateProperty.all(false),
                        trackVisibility: MaterialStateProperty.all(false),
                      ),
                    ),
                    child: Scrollbar(
                      controller: scrollController,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          // ScrollManager의 사용자 스크롤 감지 메서드 호출
                          ref
                              .read(chatProvider.notifier)
                              .scrollManager
                              .onUserScroll(notification);
                          return false; // 다른 리스너들도 처리할 수 있도록 false 반환
                        },
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: chatState.arvChatDetail.length,
                          padding: const EdgeInsets.all(16),
                          // 성능 최적화
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: true,
                          cacheExtent: 1000.0,
                          physics: const ClampingScrollPhysics(),
                          itemBuilder: (context, index) {
                            final message = chatState.arvChatDetail[index];
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Align(
                                alignment: message['role'] == 0
                                    ? Alignment.centerRight
                                    : CommonUIUtils.getAiMessageAlignment(
                                        message),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      constraints: BoxConstraints(
                                        maxWidth: message['role'] == 0 &&
                                                (message['attachments']
                                                            as List<dynamic>?)
                                                        ?.isNotEmpty ==
                                                    true
                                            ? MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.9 // 사용자 메시지에 첨부파일이 있으면 더 넓게
                                            : MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.8, // 일반적인 경우
                                      ),
                                      decoration: BoxDecoration(
                                        color: message['role'] == 0
                                            ? userBubbleColor
                                            : aiBubbleColor,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.15),
                                            spreadRadius: 0,
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      child: message['role'] == 0
                                          ? MessageRenderer.buildMessageWidget(
                                              message,
                                              chatState,
                                              useThemeColors
                                                  ? themeState.colorScheme
                                                  : null,
                                            )
                                          : MessageRenderer.buildMessageWidget(
                                              message, // 메시지 전체를 Map으로 전달
                                              chatState, // ChatState도 함께 전달
                                              useThemeColors
                                                  ? themeState.colorScheme
                                                  : null,
                                            ),
                                    ),
                                    if (message['role'] == 1)
                                      Positioned(
                                        top: -8,
                                        right: -8,
                                        child: Tooltip(
                                          message: '복사',
                                          preferBelow:
                                              false, // 툴팁이 아이콘 위에 표시되도록 설정
                                          waitDuration: const Duration(
                                              milliseconds:
                                                  100), // 마우스 호버 시 대기시간 설정
                                          showDuration: const Duration(
                                              seconds: 2), // 툴팁 표시 지속시간
                                          textStyle: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white),
                                          decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: 0.8),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 20,
                                              minHeight: 20,
                                            ),
                                            icon: Icon(
                                              Icons.copy,
                                              size: 16,
                                              color: copyButtonColor,
                                            ),
                                            onPressed: () {
                                              // 메시지에서 </think> 이후 부분만 추출
                                              final String fullMessage =
                                                  message['message'];
                                              String finalAnswer = fullMessage;

                                              // streamChat/withModel API 사용으로 COT 부분 완전 제거 (<think> 태그 없음)
                                              final int thinkEndIndex =
                                                  fullMessage
                                                      .indexOf('</think>');

                                              if (thinkEndIndex != -1 &&
                                                  thinkEndIndex + 9 <
                                                      fullMessage.length) {
                                                finalAnswer =
                                                    fullMessage.substring(
                                                        thinkEndIndex + 9);
                                              } else {
                                                // <think>와 </think> 사이 내용 제거 (정규식 방식)
                                                final thinkRegex = RegExp(
                                                    r'<think>[\s\S]*?</think>',
                                                    multiLine: true);
                                                finalAnswer = fullMessage
                                                    .replaceAll(thinkRegex, '');
                                              }

                                              Clipboard.setData(ClipboardData(
                                                  text: finalAnswer));
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content:
                                                      Text('최종 답변이 복사되었습니다.'),
                                                  duration: Duration(
                                                      milliseconds: 500),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // 첨부 파일 미리보기 추가
                Consumer(
                  builder: (context, ref, child) {
                    final attachments = ref.watch(attachmentProvider).files;
                    if (attachments.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return DropTarget(
                      onDragDone: (DropDoneDetails details) {
                        FileAttachmentUtils.handleDragAndDrop(
                            details, context, ref);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const AttachmentPreview(),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    // 파일 첨부 버튼 추가
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      onPressed: () =>
                          FileAttachmentUtils.showFileAttachmentModal(
                              context, focusNode, controller),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.only(left: 10, bottom: 10),
                        child: DropTarget(
                          onDragDone: (DropDoneDetails details) {
                            FileAttachmentUtils.handleDragAndDrop(
                                details, context, ref);
                          },
                          child: Focus(
                            onKeyEvent: (FocusNode node, KeyEvent event) {
                              if (event is KeyDownEvent &&
                                  event.logicalKey ==
                                      LogicalKeyboardKey.enter) {
                                if (HardwareKeyboard.instance.isShiftPressed) {
                                  return KeyEventResult
                                      .ignored; // Shift + Enter: 줄바꿈 허용
                                }
                                if (!isStreaming &&
                                    controller.text.trim().isNotEmpty) {
                                  // 선택된 AI 모델 가져오기
                                  final selectedModel =
                                      ref.read(selectedAiModelProvider);
                                  print('코딩 어시스턴트 - 선택된 모델: $selectedModel');
                                  // ChatNotifier에 직접 모델 전달
                                  ref
                                      .read(chatProvider.notifier)
                                      .sendMessageToAIServer(
                                        ref.read(userIdProvider) ?? '',
                                        context,
                                        selectedModel: selectedModel,
                                      );
                                  return KeyEventResult.handled;
                                }
                              }

                              // Ctrl+V 처리 추가
                              if (event is KeyDownEvent &&
                                  event.logicalKey == LogicalKeyboardKey.keyV &&
                                  HardwareKeyboard.instance.isControlPressed) {
                                FileAttachmentUtils.handleClipboardPaste(
                                    context, ref, controller);
                                return KeyEventResult.handled;
                              }

                              // Ctrl + C 복사 처리 (선택 영역 복사)
                              if (event is KeyDownEvent &&
                                  event.logicalKey == LogicalKeyboardKey.keyC &&
                                  HardwareKeyboard.instance.isControlPressed) {
                                final selection = controller.selection;
                                if (selection.isValid &&
                                    !selection.isCollapsed &&
                                    selection.start >= 0 &&
                                    selection.end <= controller.text.length) {
                                  final selectedText = controller.text
                                      .substring(
                                          selection.start, selection.end);
                                  Clipboard.setData(
                                      ClipboardData(text: selectedText));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('선택한 텍스트를 복사했습니다.'),
                                      duration: Duration(milliseconds: 500),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return KeyEventResult.handled;
                                }
                              }

                              return KeyEventResult.ignored;
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: (themeState.themeMode ==
                                            AppThemeMode.codingDark ||
                                        themeState.themeMode ==
                                            AppThemeMode.light)
                                    ? null
                                    : Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              constraints: const BoxConstraints(
                                maxHeight: 250,
                                minHeight: 40,
                              ),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  scrollbarTheme: ScrollbarThemeData(
                                    thumbColor: MaterialStatePropertyAll(
                                      Colors.grey[600],
                                    ),
                                    thickness:
                                        const MaterialStatePropertyAll(6.0),
                                    radius: const Radius.circular(4),
                                    thumbVisibility:
                                        const MaterialStatePropertyAll(
                                      false,
                                    ),
                                    trackVisibility:
                                        const MaterialStatePropertyAll(
                                      false,
                                    ),
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  child: TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    autofocus: true,
                                    maxLines: null,
                                    minLines: 1,
                                    keyboardType: TextInputType.multiline,
                                    textInputAction: TextInputAction.newline,
                                    onEditingComplete: () {
                                      // IME 조합 완료 시 커서를 텍스트 끝으로 이동
                                      try {
                                        controller.selection =
                                            TextSelection.collapsed(
                                          offset: controller.text.length,
                                        );
                                      } catch (e) {
                                        // dispose된 경우 무시
                                      }
                                    },
                                    decoration: InputDecoration(
                                      hintText:
                                          '코드나 질문을 입력하세요... (파일을 드래그하여 첨부하거나 📎 버튼을 클릭하세요)',
                                      hintStyle: TextStyle(
                                        color: useThemeColors
                                            ? themeState
                                                .colorScheme.hintTextColor
                                            : Colors.white54,
                                        fontSize: 15,
                                      ),
                                      // 코딩 어시스턴트용: 웹검색 토글 + 모델 선택기 추가
                                      prefixIcon: Consumer(
                                        builder: (context, ref, child) {
                                          final webSearchOn = ref
                                              .watch(selectedWebSearchProvider);
                                          return Container(
                                            padding: const EdgeInsets.only(
                                                left: 8, right: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Tooltip(
                                                  message: '웹검색',
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Switch(
                                                        value: webSearchOn,
                                                        onChanged: (v) {
                                                          ref
                                                              .read(
                                                                  selectedWebSearchProvider
                                                                      .notifier)
                                                              .state = v;
                                                          print(
                                                              '🌐 웹검색 토글 변경(코딩): ${v ? 'ON(y)' : 'OFF(n)'}');
                                                        },
                                                        materialTapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                        activeColor:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .primary,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '웹검색',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: useThemeColors
                                                              ? Colors.black54
                                                              : Colors.white70,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                    ],
                                                  ),
                                                ),
                                                const AiModelSelector(),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                      border: InputBorder.none,
                                      filled: true,
                                      fillColor: ((themeState.themeMode ==
                                                      AppThemeMode.light ||
                                                  themeState.themeMode ==
                                                      AppThemeMode.codingDark)
                                              ? themeState.colorScheme
                                                  .chatInputBackgroundColor
                                              : const Color.fromARGB(
                                                  240, 223, 226, 228))
                                          .withValues(alpha: 0.9),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomCenter,
                      children: [
                        // 기존 전송 버튼 (위치, 동작 그대로 유지)
                        IconButton(
                          icon: Icon(
                            isStreaming
                                ? Icons.stop_circle_outlined
                                : Icons.send,
                          ),
                          onPressed: () {
                            if (isStreaming) {
                              ref.read(chatProvider.notifier).cancelStreaming();
                            } else if (controller.text.trim().isNotEmpty) {
                              // 선택된 AI 모델 가져오기
                              final selectedModel =
                                  ref.read(selectedAiModelProvider);
                              print('코딩 어시스턴트 전송버튼 - 선택된 모델: $selectedModel');
                              // ChatNotifier에 직접 모델 전달
                              ref
                                  .read(chatProvider.notifier)
                                  .sendMessageToAIServer(
                                    ref.read(userIdProvider) ?? '',
                                    context,
                                    selectedModel: selectedModel,
                                  );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                  ],
                ),
              ],
            ),
          ),
        ),
        // 코딩 어시스턴트용 스크롤 다운 버튼
        if (chatState.arvChatDetail.isNotEmpty)
          Positioned(
            right: 20,
            bottom: 80,
            child: Container(
              decoration: themeState.themeMode == AppThemeMode.light
                  ? BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          spreadRadius: 0,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    )
                  : null,
              child: FloatingActionButton.small(
                backgroundColor: themeState.themeMode == AppThemeMode.light
                    ? Colors.transparent
                    : scrollButtonColor.withValues(alpha: 0.8),
                elevation: themeState.themeMode == AppThemeMode.light ? 0 : 4,
                heroTag: "codingScrollDown",
                tooltip: "맨 아래로",
                onPressed: () {
                  // 개선된 ScrollManager의 userScrollToBottom 메서드 사용
                  ref
                      .read(chatProvider.notifier)
                      .scrollManager
                      .userScrollToBottom();
                },
                child: Icon(
                  Icons.arrow_downward,
                  color: themeState.themeMode == AppThemeMode.light
                      ? Colors.black87
                      : Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
