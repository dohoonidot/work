import 'package:ASPN_AI_AGENT/ui/screens/sap_main_page.dart';
import 'package:ASPN_AI_AGENT/shared/utils/message_renderer/message_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:ASPN_AI_AGENT/shared/providers/web_search_provider.dart';
import 'package:ASPN_AI_AGENT/ui/screens/coding_assistant_page.dart';
import 'package:ASPN_AI_AGENT/features/chat/file_attachment_modal.dart';
import 'package:ASPN_AI_AGENT/features/chat/attachment_preview.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:ASPN_AI_AGENT/shared/providers/theme_provider.dart';
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart';
import 'package:ASPN_AI_AGENT/features/chat/ai_model_selector.dart';
import 'package:ASPN_AI_AGENT/shared/utils/file_attachment_utils.dart';
import 'package:ASPN_AI_AGENT/shared/utils/common_ui_utils.dart';
import 'package:ASPN_AI_AGENT/shared/utils/focus_management_utils.dart';
import 'package:ASPN_AI_AGENT/shared/providers/clipboard_provider.dart'
    as clipboard;

class ChatArea extends ConsumerWidget {
  final ScrollController scrollController;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(BuildContext) onSendMessage;

  const ChatArea({
    super.key,
    required this.scrollController,
    required this.controller,
    required this.focusNode,
    required this.onSendMessage,
  });

  /// AI 메시지 버블의 최적 위치 결정 - 항상 중앙 정렬 (ChatGPT 스타일)
  static Alignment _getAiMessageAlignment(
      Map<String, dynamic> message, dynamic chatState) {
    // ChatGPT 앱처럼 항상 중앙 정렬 유지
    return Alignment.center;
  }

  /// 테이블 포함 여부 확인
  bool _messageContainsTable(String content) {
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

  void _showFileAttachmentModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => FileAttachmentModal(
        onCompleted: () {
          // 파일 첨부 완료 후 텍스트 필드로 포커스 이동 (커서를 텍스트 끝으로)
          FocusManagementUtils.requestFocusWithCursorAtEnd(
              focusNode, controller);
        },
      ),
    );
  }

  /// 🚀 통합된 클립보드 붙여넣기 처리
  void _handleClipboardPaste(BuildContext context, WidgetRef ref) async {
    try {
      // 현재 포커스 상태 저장
      final wasFocused = focusNode.hasFocus;

      // FileAttachmentUtils를 사용하여 텍스트와 이미지 모두 처리
      await FileAttachmentUtils.handleClipboardPaste(context, ref, controller);

      // 포커스가 있었다면 복원 (커서를 텍스트 끝으로)
      if (wasFocused && !focusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusManagementUtils.requestFocusWithCursorAtEndImmediate(
              focusNode, controller);
        });
      }
    } catch (e) {
      print('클립보드 처리 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatProvider);
    final isCodeArchive = chatState.archiveType == 'code';
    final isSapArchive = chatState.archiveType == 'sap';
    final isStreaming = chatState.isStreaming;
    final themeState = ref.watch(themeProvider); // 테마 상태 추가

    // 클립보드 상태 변경 감지하여 사용자 피드백 표시
    ref.listen<clipboard.ClipboardState>(clipboard.clipboardProvider,
        (previous, current) {
      if (current.status == clipboard.ClipboardStatus.success &&
          current.message != null) {
        CommonUIUtils.showSuccessSnackBar(context, current.message!);
      } else if (current.status == clipboard.ClipboardStatus.error &&
          current.message != null) {
        CommonUIUtils.showErrorSnackBar(context, current.message!);
      }
    });

    // 스트리밍 상태 변경 감지하여 자동 포커스 설정
    ref.listen<bool>(chatProvider.select((state) => state.isStreaming), (
      previous,
      current,
    ) {
      // 스트리밍이 true->false로 바뀔 때 (응답이 완료되었을 때)
      // 텍스트 유무와 관계없이 항상 커서를 끝으로 이동
      if (previous == true && current == false) {
        // 약간의 지연을 주고 포커스 설정 (커서를 텍스트 끝으로)
        FocusManagementUtils.requestFocusWithCursorAtEnd(focusNode, controller);
      }
    });

    // 새 아카이브 생성 감지하여 자동 포커스 설정 추가
    ref.listen<bool>(chatProvider.select((state) => state.isNewArchive), (
      previous,
      current,
    ) {
      // 새 아카이브가 생성되었을 때 (true로 변경)
      // 텍스트 유무와 관계없이 항상 커서를 끝으로 이동
      if (current == true) {
        FocusManagementUtils.requestFocusWithCursorAtEnd(focusNode, controller);
      }
    });

    // 중복된 isNewArchive 리스너는 제거하고, 이 위치에 새로운 selectedTopic 리스너 추가
    ref.listen<String>(chatProvider.select((state) => state.selectedTopic), (
      previous,
      current,
    ) {
      // 토픽이 변경되었을 때 텍스트 유무와 관계없이 항상 커서를 끝으로 이동
      if (previous != current) {
        FocusManagementUtils.requestFocusWithCursorAtEnd(focusNode, controller);
      }
    });

    if (isCodeArchive) {
      return CodingAssistantPage(
        controller: controller,
        focusNode: focusNode,
        onSendMessage: onSendMessage,
        scrollController: scrollController,
      );
    }

    // SAP 타입 처리 추가
    if (isSapArchive) {
      return SapMainPage(
        controller: controller,
        focusNode: focusNode,
        onSendMessage: onSendMessage,
        scrollController: scrollController,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          // 화면의 아무 곳이나 클릭하면 검색 하이라이트 초기화
          onTap: () {
            // 검색 키워드가 있을 때만 초기화 수행
            if (chatState.searchKeyword != null ||
                chatState.highlightedChatId != null) {
              print('화면 탭: 검색 하이라이트 초기화');
              ref.read(chatProvider.notifier).clearSearchHighlight();
            }
          },
          // 다른 탭 이벤트가 동작하도록 behavior 설정
          behavior: HitTestBehavior.translucent,
          child: Container(
            // 투명 배경으로 변경하여 하위 레이어가 보이도록 함
            color: Colors.transparent,
            child: Column(
              children: [
                // 질문 예시 전광판 제거 (대시보드에서 표시하므로 중복됨)
                // 이 부분을 제거했습니다.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 30,
                      top: 10,
                      right: 16,
                      bottom: 0,
                    ),
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
                        // 성능 최적화
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        cacheExtent: 1000.0,
                        physics: const ClampingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final message = chatState.arvChatDetail[index];
                          final bool isStreamingMessage =
                              message['isStreaming'] ?? false;
                          final bool isLoadingMessage =
                              message['isLoading'] ?? false;

                          return Padding(
                              padding: EdgeInsets.only(
                                top: 4.0,
                                bottom: (isStreamingMessage || isLoadingMessage)
                                    ? 16.0
                                    : 12.0,
                                left: 8.0,
                                right: 8.0,
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Align(
                                  alignment: message['role'] == 0
                                      ? Alignment.centerRight
                                      : _getAiMessageAlignment(
                                          message, chatState),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      // 부모 컨테이너의 크기에 따라 동적으로 조정
                                      final availableWidth =
                                          constraints.maxWidth;
                                      final hasAttachments =
                                          message['role'] == 0 &&
                                              (message['attachments']
                                                          as List<dynamic>?)
                                                      ?.isNotEmpty ==
                                                  true;

                                      // 마크다운 테이블 감지 (role 1인 경우에만)
                                      final bool hasTable =
                                          message['role'] == 1 &&
                                              _messageContainsTable(
                                                  message['message'] ?? '');

                                      // 동적 크기 계산 (최소/최대 범위 설정)
                                      double dynamicMaxWidth;
                                      if (hasTable) {
                                        dynamicMaxWidth = availableWidth *
                                            0.95; // 테이블이 있을 때 95%
                                      } else if (hasAttachments) {
                                        dynamicMaxWidth = availableWidth *
                                            0.95; // 첨부파일 있을 때 더 넓게
                                      } else {
                                        dynamicMaxWidth =
                                            availableWidth * 0.85; // 일반적인 경우
                                      }

                                      // 최소/최대 제한 (반응형 고려)
                                      final constrainedWidth =
                                          dynamicMaxWidth.clamp(
                                        availableWidth * 0.3, // 최소 30%
                                        availableWidth * 0.95, // 최대 95%
                                      );

                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            constraints: BoxConstraints(
                                              maxWidth: constrainedWidth,
                                              // 높이는 컨텐츠에 따라 자동 조정
                                            ),
                                            decoration: BoxDecoration(
                                              color: (chatState.searchKeyword !=
                                                          null &&
                                                      message['message']
                                                          .toLowerCase()
                                                          .contains(chatState
                                                              .searchKeyword!
                                                              .toLowerCase()))
                                                  ? Colors
                                                      .transparent // 검색어가 포함된 경우 완전히 투명하게
                                                  : message['role'] == 0
                                                      ? themeState.colorScheme
                                                          .chatUserBubbleColor
                                                      : themeState.colorScheme
                                                          .chatAiBubbleColor,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              // 검색어 포함 + 선택된 chatId와 일치하는 경우에만 테두리 표시
                                              border: (chatState.searchKeyword != null &&
                                                      message['message']
                                                          .toLowerCase()
                                                          .contains(chatState
                                                              .searchKeyword!
                                                              .toLowerCase()) &&
                                                      chatState
                                                              .highlightedChatId !=
                                                          null &&
                                                      message['chat_id'] ==
                                                          chatState
                                                              .highlightedChatId)
                                                  ? Border.all(
                                                      color: Colors.amber,
                                                      width: 2.0)
                                                  : null,
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
                                            padding: const EdgeInsets.all(10),
                                            child: MessageRenderer
                                                .buildMessageWidget(
                                              message,
                                              chatState,
                                              themeState.colorScheme,
                                            ),
                                          ),
                                          if (message['role'] == 1)
                                            Positioned(
                                              top: -8,
                                              right: -8,
                                              child: Tooltip(
                                                message: '복사',
                                                preferBelow: false,
                                                verticalOffset: 20,
                                                child: IconButton(
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(
                                                    minWidth: 20,
                                                    minHeight: 20,
                                                  ),
                                                  icon: Icon(
                                                    Icons.copy,
                                                    size: 16,
                                                    color: themeState
                                                        .colorScheme
                                                        .copyButtonColor,
                                                  ),
                                                  onPressed: () {
                                                    // 아카이브 정보 확인
                                                    final chatState =
                                                        ref.read(chatProvider);
                                                    final currentArchive = chatState
                                                        .arvChatHistory
                                                        .where((archive) =>
                                                            archive[
                                                                'archive_id'] ==
                                                            chatState
                                                                .currentArchiveId)
                                                        .firstOrNull;

                                                    final archiveName =
                                                        currentArchive?[
                                                                'archive_name'] ??
                                                            '';
                                                    final archiveType =
                                                        currentArchive?[
                                                                'archive_type'] ??
                                                            '';

                                                    // streamChat/withModel API를 사용하는 아카이브들은 COT 부분 완전 제거
                                                    // (코딩 어시스턴트, SAP 어시스턴트, AI Chatbot - <think> 태그가 없으므로)
                                                    bool shouldRemoveCOT =
                                                        archiveName ==
                                                                '코딩 어시스턴트' ||
                                                            archiveName ==
                                                                'SAP 어시스턴트' ||
                                                            archiveName ==
                                                                'AI Chatbot' ||
                                                            archiveType ==
                                                                'coding' ||
                                                            archiveType ==
                                                                'sap' ||
                                                            archiveType ==
                                                                'code';

                                                    // 메시지에서 </think> 이후 부분만 추출
                                                    final String fullMessage =
                                                        message['message'];
                                                    String finalAnswer =
                                                        fullMessage;

                                                    if (shouldRemoveCOT) {
                                                      final int thinkEndIndex =
                                                          fullMessage.indexOf(
                                                              '</think>');

                                                      if (thinkEndIndex != -1 &&
                                                          thinkEndIndex + 9 <
                                                              fullMessage
                                                                  .length) {
                                                        finalAnswer = fullMessage
                                                            .substring(
                                                                thinkEndIndex +
                                                                    9);
                                                      } else {
                                                        // <think>와 </think> 사이 내용 제거 (정규식 방식)
                                                        final thinkRegex = RegExp(
                                                            r'<think>[\s\S]*?</think>',
                                                            multiLine: true);
                                                        finalAnswer =
                                                            fullMessage
                                                                .replaceAll(
                                                                    thinkRegex,
                                                                    '');
                                                      }
                                                    } else {
                                                      // 기존 로직 유지 (사내업무 및 일반 아카이브)
                                                      final int thinkEndIndex =
                                                          fullMessage.indexOf(
                                                              '</think>');

                                                      if (thinkEndIndex != -1 &&
                                                          thinkEndIndex + 9 <
                                                              fullMessage
                                                                  .length) {
                                                        finalAnswer = fullMessage
                                                            .substring(
                                                                thinkEndIndex +
                                                                    9);
                                                      }
                                                    }

                                                    Clipboard.setData(
                                                      ClipboardData(
                                                          text: finalAnswer),
                                                    );
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                            '최종 답변이 복사되었습니다.'),
                                                        duration: Duration(
                                                          milliseconds: 500,
                                                        ),
                                                        behavior:
                                                            SnackBarBehavior
                                                                .floating,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ));
                        },
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
                        // 현재 포커스 상태 저장
                        final wasFocused = focusNode.hasFocus;

                        // 현재 아카이브 정보를 바탕으로 PDF 제한 여부 판단
                        // final chatState = ref.read(chatProvider);
                        // final currentArchive = chatState.arvChatHistory.firstWhere(
                        //   (archive) => archive['archive_id'] == chatState.currentArchiveId,
                        //   orElse: () => {'archive_name': '', 'archive_type': ''},
                        // );
                        // 아카이브 정보 (미사용)
                        // final archiveName = currentArchive['archive_name'] ?? '';
                        // final archiveType = currentArchive['archive_type'] ?? '';
                        // withModel API(코드/SAP/AI Chatbot)에서도 PDF 허용
                        final isPdfRestricted = false;

                        FileAttachmentUtils.handleDragAccept(
                            details.files, context, ref,
                            isPdfRestricted: isPdfRestricted);

                        // 드래그 앤 드롭 후 포커스 복원 (커서를 텍스트 끝으로)
                        if (wasFocused) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            FocusManagementUtils
                                .requestFocusWithCursorAtEndImmediate(
                                    focusNode, controller);
                          });
                        }
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
                    // 파일 첨부 버튼 추가 (크기 조정)
                    Flexible(
                      flex: 0,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          icon: const Icon(Icons.attach_file, size: 20),
                          onPressed: () => _showFileAttachmentModal(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: DropTarget(
                          onDragDone: (DropDoneDetails details) {
                            // 현재 포커스 상태 저장
                            final wasFocused = focusNode.hasFocus;

                            FileAttachmentUtils.handleDragAndDrop(
                                details, context, ref);

                            // 드래그 앤 드롭 후 포커스 복원 (커서를 텍스트 끝으로)
                            if (wasFocused) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                FocusManagementUtils
                                    .requestFocusWithCursorAtEndImmediate(
                                        focusNode, controller);
                              });
                            }
                          },
                          child: Focus(
                            // KeyboardListener 대신 Focus 위젯 사용
                            onKeyEvent: (FocusNode node, KeyEvent event) {
                              if (event is KeyDownEvent &&
                                  event.logicalKey ==
                                      LogicalKeyboardKey.enter) {
                                if (HardwareKeyboard.instance.isShiftPressed) {
                                  // HardwareKeyboard 사용
                                  return KeyEventResult
                                      .ignored; // Shift + Enter: 줄바꿈 허용
                                }
                                if (!isStreaming &&
                                    controller.text.trim().isNotEmpty) {
                                  // 선택된 AI 모델 가져오기
                                  final selectedModel =
                                      ref.read(selectedAiModelProvider);
                                  print('Chat Area - 선택된 모델: $selectedModel');
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
                                _handleClipboardPaste(context, ref);
                                return KeyEventResult.handled;
                              }

                              // Ctrl + C: 선택 영역 복사
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
                                  CommonUIUtils.showInfoSnackBar(context, '선택한 텍스트를 복사했습니다.');
                                  return KeyEventResult.handled;
                                }
                              }

                              return KeyEventResult.ignored; // 다른 모든 키 이벤트는 무시
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
                                maxHeight: 200,
                                minHeight: 35,
                              ),
                              child: TextField(
                                controller: controller,
                                focusNode: focusNode,
                                autofocus: true, // 초기 화면 로드 시 자동 포커스
                                maxLines: null,
                                minLines: 1,
                                expands: false, // 명시적으로 expands 비활성화
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                textAlign: TextAlign.start, // 텍스트를 왼쪽 끝에서 시작
                                scrollPhysics:
                                    const ClampingScrollPhysics(), // 스크롤 물리 명시
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
                                      '메시지를 입력하세요... (파일을 드래그하여 첨부하거나 📎 버튼을 클릭하세요)',
                                  hintStyle: TextStyle(
                                    color: themeState.colorScheme.hintTextColor,
                                    fontSize: 15,
                                  ),
                                  // AI Chatbot, 코딩 어시스턴트, SAP 어시스턴트일 때 prefix에 모델 선택 버튼 추가
                                  prefixIcon: Consumer(
                                    builder: (context, ref, child) {
                                      final chatState = ref.watch(chatProvider);
                                      // 현재 선택된 아카이브 확인
                                      final currentArchive = chatState
                                          .arvChatHistory
                                          .where((archive) =>
                                              archive['archive_id'] ==
                                              chatState.currentArchiveId)
                                          .firstOrNull;

                                      if (currentArchive == null) {
                                        return const SizedBox.shrink();
                                      }

                                      final archiveName =
                                          currentArchive['archive_name'];
                                      final archiveType =
                                          currentArchive['archive_type'] ?? '';

                                      // AI Chatbot, 코딩 어시스턴트, SAP 어시스턴트인지 확인
                                      final isModelSelectorArchive =
                                          archiveName == 'AI Chatbot' ||
                                              archiveName == '코딩어시스턴트' ||
                                              archiveType == 'code' ||
                                              archiveName == 'SAP 어시스턴트' ||
                                              archiveType == 'sap';

                                      if (!isModelSelectorArchive) {
                                        return const SizedBox.shrink();
                                      }

                                      final webSearchOn =
                                          ref.watch(selectedWebSearchProvider);

                                      return Container(
                                        padding: const EdgeInsets.only(
                                            left: 8, right: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // 웹검색 토글 스위치 (Compact)
                                            Tooltip(
                                              message: '웹검색',
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
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
                                                          '🌐 웹검색 토글 변경: ${v ? 'ON(y)' : 'OFF(n)'}');
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
                                                      color: themeState
                                                                  .themeMode ==
                                                              AppThemeMode.light
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
                                  fillColor: Colors.transparent,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4,
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
                    // 전송 버튼을 더 작은 크기로 조정
                    Flexible(
                      flex: 0,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          icon: Icon(
                            isStreaming
                                ? Icons.stop_circle_outlined
                                : Icons.send,
                            size: 20, // 아이콘 크기 축소
                          ),
                          onPressed: () {
                            if (isStreaming) {
                              ref.read(chatProvider.notifier).cancelStreaming();
                            } else if (controller.text.trim().isNotEmpty) {
                              // 선택된 AI 모델 가져오기
                              final selectedModel =
                                  ref.read(selectedAiModelProvider);
                              print('Chat Area 전송버튼 - 선택된 모델: $selectedModel');
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
                          padding: EdgeInsets.zero, // 패딩 제거
                          constraints: const BoxConstraints(), // 제약 제거
                        ),
                      ),
                    ),
                    const SizedBox(width: 5), // 간격 축소
                  ],
                ),
              ],
            ),
          ),
        ),
        // 스크롤 다운 버튼을 FloatingActionButton으로 교체
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
                    : themeState.colorScheme.scrollButtonColor,
                elevation: themeState.themeMode == AppThemeMode.light ? 0 : 4,
                heroTag: "chatScrollDown", // 여러 FAB가 있을 때 구분하기 위한 태그
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
