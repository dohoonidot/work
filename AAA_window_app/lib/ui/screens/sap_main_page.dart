import 'package:ASPN_AI_AGENT/shared/utils/message_renderer/message_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:ASPN_AI_AGENT/shared/providers/clipboard_provider.dart'
    as clipboard;
import 'package:desktop_drop/desktop_drop.dart';
// 새로 추가된 임포트
import 'package:ASPN_AI_AGENT/features/sap/sap_module_messages.dart';
import 'package:ASPN_AI_AGENT/shared/utils/common_ui_utils.dart';
import 'package:ASPN_AI_AGENT/shared/utils/file_attachment_utils.dart';
import 'package:ASPN_AI_AGENT/shared/utils/focus_management_utils.dart';
import 'package:ASPN_AI_AGENT/features/chat/attachment_preview.dart';
import 'package:ASPN_AI_AGENT/shared/providers/theme_provider.dart'; // 테마 provider 추가
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart'; // AppThemeMode import 추가
import 'package:ASPN_AI_AGENT/features/chat/ai_model_selector.dart';
import 'package:ASPN_AI_AGENT/shared/providers/web_search_provider.dart';

// SAP 전역 색상 정의 제거 - Light 테마로 100% 대체

class SapMainPage extends ConsumerWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(BuildContext) onSendMessage;
  final ScrollController scrollController;

  // SAP 모듈 정의
  static const List<String> sapModules = [
    'BC',
    'CO',
    'FI',
    'HR',
    'IS',
    'MM',
    'PM',
    'PP',
    'PS',
    'QM',
    'SD',
    'TR',
    'WF',
    'General'
  ];

  const SapMainPage({
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

    // Light, Coding Dark 테마일 때는 테마 색상 사용, 다른 테마일 때는 SAP 고유 색상 사용
    final useThemeColors = themeState.themeMode == AppThemeMode.light ||
        themeState.themeMode == AppThemeMode.codingDark ||
        themeState.themeMode == AppThemeMode.system; // system 모드도 테마 색상 사용

    final backgroundColor = useThemeColors
        ? themeState.colorScheme.backgroundColor
        : const Color.fromARGB(255, 30, 30, 30);

    final primaryColor = useThemeColors
        ? themeState.colorScheme.primaryColor
        : const Color(0xFF1976D2);

    final userBubbleColor = useThemeColors
        ? themeState.colorScheme.chatUserBubbleColor
        : const Color.fromARGB(255, 45, 45, 45);
    final aiBubbleColor = useThemeColors
        ? themeState.colorScheme.chatAiBubbleColor
        : const Color.fromARGB(255, 50, 50, 50);
    final textColor =
        useThemeColors ? themeState.colorScheme.textColor : Colors.white;
    final hintTextColor = useThemeColors
        ? themeState.colorScheme.hintTextColor
        : const Color(0x80FFFFFF);
    final copyButtonColor =
        useThemeColors ? themeState.colorScheme.copyButtonColor : Colors.grey;

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

    // SAP 어시스턴트 페이지에서 처음 로드될 때 실행
    if (chatState.isNewArchive) {
      // 첫 실행 메시지 표시
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.text = "";
      });
    }

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

    return GestureDetector(
      // 화면의 아무 곳이나 클릭하면 검색 하이라이트 초기화
      onTap: () {
        // 검색 키워드가 있을 때만 초기화 수행
        if (chatState.searchKeyword != null ||
            chatState.highlightedChatId != null) {
          print('SAP 어시스턴트 화면 탭: 검색 하이라이트 초기화');
          ref.read(chatProvider.notifier).clearSearchHighlight();
        }
      },
      // 다른 탭 이벤트가 동작하도록 behavior 설정
      behavior: HitTestBehavior.translucent,
      child: Container(
        // 조건부로 배경색 사용
        decoration: BoxDecoration(
          color: backgroundColor, // decoration 안에서만 색상 설정
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Expanded(
                  child: Container(
                    // 🔧 명시적으로 배경색 설정 추가
                    decoration: BoxDecoration(
                      color: backgroundColor, // 배경색 명시적 설정
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          offset: const Offset(0, 2),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        scrollbarTheme: ScrollbarThemeData(
                          thumbColor:
                              MaterialStatePropertyAll(Colors.grey[400]),
                          trackColor: const MaterialStatePropertyAll(
                              Colors.transparent),
                          thickness: const MaterialStatePropertyAll(8.0),
                          radius: const Radius.circular(4),
                          thumbVisibility:
                              const MaterialStatePropertyAll(false),
                          trackVisibility:
                              const MaterialStatePropertyAll(false),
                        ),
                      ),
                      child: Scrollbar(
                        controller: scrollController,
                        child: Container(
                          // 🔧 ListView 배경색도 명시적 설정
                          color: backgroundColor,
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
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
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
                                                                as List<
                                                                    dynamic>?)
                                                            ?.isNotEmpty ==
                                                        true
                                                ? MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.9 // 사용자 메시지에 첨부파일이 있으면 더 넓게
                                                : MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: message['role'] == 0
                                                ? userBubbleColor
                                                : aiBubbleColor,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.15),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          child: MessageRenderer
                                              .buildMessageWidget(
                                            message,
                                            chatState,
                                            themeState.colorScheme,
                                          ),
                                        ),
                                        // 복사 버튼 추가 (AI 메시지인 경우에만)
                                        if (message['role'] == 1)
                                          Positioned(
                                            top: -8,
                                            right: -8,
                                            child: Tooltip(
                                              message: '복사',
                                              preferBelow: false,
                                              waitDuration: const Duration(
                                                  milliseconds: 100),
                                              showDuration:
                                                  const Duration(seconds: 2),
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
                                                constraints:
                                                    const BoxConstraints(
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
                                                  String finalAnswer =
                                                      fullMessage;

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
                                                    finalAnswer =
                                                        fullMessage.replaceAll(
                                                            thinkRegex, '');
                                                  }

                                                  Clipboard.setData(
                                                      ClipboardData(
                                                          text: finalAnswer));
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                          '최종 답변이 복사되었습니다.'),
                                                      duration: Duration(
                                                          milliseconds: 500),
                                                      behavior: SnackBarBehavior
                                                          .floating,
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
                  ),
                ),

                // SAP 모듈 버튼들 추가
                Container(
                  width: double.infinity,
                  // 모듈 선택 영역에 배경색 적용 (조건부 색상 사용)
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        offset: const Offset(0, -2),
                        blurRadius: 4,
                      ),
                    ],
                    // 상단 테두리 제거
                    border: null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 섹션 제목 추가
                      Padding(
                        padding:
                            const EdgeInsets.only(left: 16, top: 12, bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.category,
                              color: primaryColor,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'SAP 모듈을 선택하여 더 전문적인 답변을 얻을 수 있습니다.',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 모듈 버튼 스크롤 영역
                      Container(
                        padding: const EdgeInsets.only(bottom: 12, top: 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 10, // 버튼 간 간격 확대
                            runSpacing: 10,
                            children: sapModules.map((module) {
                              return _buildModuleButton(module, context);
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 입력창
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        offset: const Offset(0, -2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // 첨부 파일 미리보기 추가
                      Builder(builder: (context) {
                        final attachments = ref.watch(attachmentProvider).files;
                        if (attachments.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return DropTarget(
                          onDragDone: (DropDoneDetails details) {
                            FileAttachmentUtils.handleDragAccept(
                              details.files,
                              context,
                              ref,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            constraints: const BoxConstraints(maxHeight: 150),
                            child: const AttachmentPreview(),
                          ),
                        );
                      }),
                      Row(
                        children: [
                          // 파일 첨부 버튼을 텍스트 필드 밖으로 이동
                          IconButton(
                            icon: Icon(Icons.attach_file, color: textColor),
                            onPressed: () =>
                                FileAttachmentUtils.showFileAttachmentModal(
                                    context, focusNode, controller),
                          ),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: backgroundColor,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: DropTarget(
                                      onDragDone: (DropDoneDetails details) {
                                        FileAttachmentUtils.handleDragAndDrop(
                                            details, context, ref);
                                      },
                                      child: Focus(
                                        // Enter 키 처리를 위한 Focus 위젯 추가
                                        onKeyEvent:
                                            (FocusNode node, KeyEvent event) {
                                          if (event is KeyDownEvent &&
                                              event.logicalKey ==
                                                  LogicalKeyboardKey.enter) {
                                            if (HardwareKeyboard
                                                .instance.isShiftPressed) {
                                              return KeyEventResult
                                                  .ignored; // Shift + Enter: 줄바꿈 허용
                                            }
                                            if (!isStreaming &&
                                                controller.text
                                                    .trim()
                                                    .isNotEmpty) {
                                              // 선택된 AI 모델 가져오기
                                              final selectedModel =
                                                  ref.read(selectedAiModelProvider);
                                              print('🔍 SAP 어시스턴트 Enter키 - 선택된 모델: $selectedModel');
                                              // ChatNotifier에 직접 모델 전달 (onSendMessage 대신)
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
                                              event.logicalKey ==
                                                  LogicalKeyboardKey.keyV &&
                                              HardwareKeyboard
                                                  .instance.isControlPressed) {
                                            FileAttachmentUtils
                                                .handleClipboardPaste(
                                                    context, ref, controller);
                                            return KeyEventResult.handled;
                                          }

                                          // Ctrl + C 복사 처리 (선택 영역 복사)
                                          if (event is KeyDownEvent &&
                                              event.logicalKey ==
                                                  LogicalKeyboardKey.keyC &&
                                              HardwareKeyboard
                                                  .instance.isControlPressed) {
                                            final selection =
                                                controller.selection;
                                            if (selection.isValid &&
                                                !selection.isCollapsed &&
                                                selection.start >= 0 &&
                                                selection.end <=
                                                    controller.text.length) {
                                              final selectedText =
                                                  controller.text.substring(
                                                      selection.start,
                                                      selection.end);
                                              Clipboard.setData(ClipboardData(
                                                  text: selectedText));
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content:
                                                      Text('선택한 텍스트를 복사했습니다.'),
                                                  duration: Duration(
                                                      milliseconds: 500),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                              return KeyEventResult.handled;
                                            }
                                          }

                                          return KeyEventResult.ignored;
                                        },
                                        child: Container(
                                          constraints: const BoxConstraints(
                                            maxHeight: 250,
                                            minHeight: 40,
                                          ),
                                          child: TextField(
                                            controller: controller,
                                            focusNode: focusNode,
                                            autofocus: true,
                                            maxLines: null,
                                            minLines: 1,
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 15,
                                            ),
                                            keyboardType:
                                                TextInputType.multiline,
                                            textInputAction:
                                                TextInputAction.newline,
                                            onEditingComplete: () {
                                              // IME 조합 완료 시 커서를 텍스트 끝으로 이동
                                              try {
                                                controller.selection =
                                                    TextSelection.collapsed(
                                                  offset:
                                                      controller.text.length,
                                                );
                                              } catch (e) {
                                                // dispose된 경우 무시
                                              }
                                            },
                                            decoration: InputDecoration(
                                              hintText:
                                                  'SAP 관련 질문을 입력하세요... (파일을 드래그하여 첨부하거나 📎 버튼을 클릭하세요)',
                                              hintStyle: TextStyle(
                                                color: hintTextColor,
                                                fontSize: 15,
                                              ),
                                              // SAP 어시스턴트: 웹검색 토글 + 모델 선택기 추가
                                              prefixIcon: Consumer(
                                                builder: (context, ref, child) {
                                                  final webSearchOn = ref.watch(
                                                      selectedWebSearchProvider);
                                                  return Container(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 8, right: 4),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Tooltip(
                                                          message: '웹검색',
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Switch(
                                                                value:
                                                                    webSearchOn,
                                                                onChanged: (v) {
                                                                  ref
                                                                      .read(selectedWebSearchProvider
                                                                          .notifier)
                                                                      .state = v;
                                                                  print(
                                                                      '🌐 웹검색 토글 변경(SAP): ${v ? 'ON(y)' : 'OFF(n)'}');
                                                                },
                                                                materialTapTargetSize:
                                                                    MaterialTapTargetSize
                                                                        .shrinkWrap,
                                                                activeColor: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .primary,
                                                              ),
                                                              const SizedBox(
                                                                  width: 4),
                                                              Text(
                                                                '웹검색',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 11,
                                                                  color:
                                                                      hintTextColor,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  width: 8),
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
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                      horizontal: 16),
                                            ),
                                            cursorColor: useThemeColors
                                                ? themeState.colorScheme
                                                    .textFieldBorderColor
                                                : Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 전송 버튼
                                  IconButton(
                                    icon: Icon(
                                      isStreaming
                                          ? Icons.stop_circle_outlined
                                          : Icons.send,
                                      color: textColor,
                                    ),
                                    onPressed: () {
                                      if (isStreaming) {
                                        ref
                                            .read(chatProvider.notifier)
                                            .cancelStreaming();
                                      } else if (controller.text
                                          .trim()
                                          .isNotEmpty) {
                                        // 선택된 AI 모델 가져오기
                                        final selectedModel =
                                            ref.read(selectedAiModelProvider);
                                        print('🔍 SAP 어시스턴트 - 선택된 모델: $selectedModel');
                                        print('🔍 SAP 어시스턴트 - selectedAiModelProvider 상태 확인: ${ref.read(selectedAiModelProvider.notifier).state}');
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
                                  const SizedBox(width: 8),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // SAP 어시스턴트용 스크롤 다운 버튼
            if (chatState.arvChatDetail.isNotEmpty)
              Positioned(
                right: 20,
                bottom: 80,
                child: Container(
                  decoration: useThemeColors &&
                          themeState.themeMode == AppThemeMode.light
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
                    backgroundColor: useThemeColors &&
                            themeState.themeMode == AppThemeMode.light
                        ? Colors.transparent
                        : (useThemeColors
                            ? themeState.colorScheme.scrollButtonColor
                            : Colors.grey),
                    elevation: useThemeColors &&
                            themeState.themeMode == AppThemeMode.light
                        ? 0
                        : 4,
                    heroTag: "sapScrollDown",
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
                      color: textColor,
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // SAP 모듈 버튼 생성 메서드
  Widget _buildModuleButton(String module, BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final selectedModule = ref.watch(selectedSapModuleProvider);
        final isSelected = selectedModule.toLowerCase() == module.toLowerCase();
        final chatNotifier = ref.read(chatProvider.notifier);
        final themeState = ref.watch(themeProvider); // 테마 상태 추가

        // 조건부 색상 적용
        final useThemeColors = themeState.themeMode == AppThemeMode.light ||
            themeState.themeMode == AppThemeMode.codingDark ||
            themeState.themeMode == AppThemeMode.system; // system 모드도 테마 색상 사용
        final primaryColor = useThemeColors
            ? themeState.colorScheme.primaryColor
            : const Color(0xFF1976D2);
        final textColor =
            useThemeColors ? themeState.colorScheme.textColor : Colors.white;
        final surfaceColor = useThemeColors
            ? (themeState.themeMode == AppThemeMode.light
                ? Colors.grey.shade200
                : themeState.colorScheme.surfaceColor)
            : const Color.fromARGB(255, 50, 50, 50);
        final borderColor = useThemeColors
            ? (themeState.themeMode == AppThemeMode.light
                ? Colors.grey.shade400
                : Colors.transparent)
            : Colors.transparent;

        // 스트리밍 상태 가져오기
        final isStreaming = ref.watch(chatProvider).isStreaming;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isStreaming
                ? null // 스트리밍 중일 때는 버튼이 작동하지 않도록 null 처리
                : () {
                    // 현재 선택된 모듈 저장 (대문자로 저장)
                    ref.read(selectedSapModuleProvider.notifier).state =
                        module.toUpperCase();
                    // 중요: ChatNotifier에도 모듈 정보 직접 저장
                    chatNotifier.setSelectedModule(module.toUpperCase());
                    print('SAP 모듈 선택됨: ${module.toUpperCase()}');

                    // 안내 메시지를 대화 목록에 추가
                    addModuleGuidanceMessage(
                        context, ref, module, scrollController);

                    // 포커스 설정 - 텍스트 필드에 바로 입력할 수 있도록 (커서를 텍스트 끝으로)
                    FocusManagementUtils.requestFocusWithCursorAtEndImmediate(
                        focusNode, controller);
                  },
            // 스트리밍 중일 때는 버튼 스타일 변경하여 비활성화 상태 표시
            borderRadius: BorderRadius.circular(20),
            child: Opacity(
              opacity: isStreaming ? 0.5 : 1.0, // 스트리밍 중일 때 버튼 투명도 조정
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8), // 패딩 증가
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? primaryColor : borderColor,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  module,
                  style: TextStyle(
                    color: isSelected ? primaryColor : textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
