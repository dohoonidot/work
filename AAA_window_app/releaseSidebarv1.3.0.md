import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/widgets/help_guide_dialog.dart'; // 도움말 다이얼로그 임포트 추가
import 'package:ASPN_AI_AGENT/core/database/database_helper.dart'; // DatabaseHelper 임포트 추가
import 'package:ASPN_AI_AGENT/shared/providers/theme_provider.dart'; // 테마 provider 추가
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart'; // AppThemeMode import 추가
import 'package:ASPN_AI_AGENT/shared/utils/common_ui_utils.dart';
import 'package:ASPN_AI_AGENT/core/mixins/text_editing_controller_mixin.dart';
import 'package:ASPN_AI_AGENT/shared/providers/attachment_provider.dart';
import 'package:ASPN_AI_AGENT/ui/screens/electronic_approval_management_screen.dart'; // 전자결재관리 화면 추가
import 'package:ASPN_AI_AGENT/ui/screens/leave_management_screen.dart'; // 휴가관리 화면 추가

class Sidebar extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> arvHistory;
  final String selectedTopic;
  final Function(String, String) onEditTopic;
  final Function(String) onTopicSelected;
  final Function(String) onDeleteTopic;
  final VoidCallback onToggleSidebar;

  const Sidebar({
    super.key,
    required this.arvHistory,
    required this.selectedTopic,
    required this.onTopicSelected,
    required this.onEditTopic,
    required this.onDeleteTopic,
    required this.onToggleSidebar,
  });

  @override
  SidebarState createState() => SidebarState();
}

class SidebarState extends ConsumerState<Sidebar>
    with TextEditingControllerMixin {
  // 스크롤 컨트롤러 추가
  final ScrollController _scrollController = ScrollController();

  // 검색 컨트롤러 추가
  late final TextEditingController _searchController = getController('search');

  // 검색 결과 저장 리스트
  List<Map<String, dynamic>> _searchResults = [];

  // 검색 중 상태 관리
  bool _isSearching = false;

  // 아카이브 설명 맵 추가
  final Map<String, String> _archiveDescriptions = {
    'code': '개발자를 위한 AI 도우미, 코드 작성, 디버깅, 최적화 지원',
    'sap': 'SAP 시스템 관련 질문에 모듈별 최적화된 답변 제공',
  };

  // AI Chatbot 제목과 아이콘을 위한 위젯
  Widget _buildAIChatbotTitle() {
    final themeState = ref.watch(themeProvider);
    final isDarkMode = themeState.themeMode != AppThemeMode.light;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // AI Chatbot 텍스트
        Expanded(
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: isDarkMode
                  ? [
                      // Dark 테마에서 더 밝은 색상들
                      const Color(0xFF9F7AEA),
                      const Color(0xFFB794F6),
                      const Color(0xFFE9D8FD),
                    ]
                  : [
                      // Light 테마에서는 기존 색상 유지
                      const Color(0xFF6B46C1),
                      const Color(0xFF8B5CF6),
                      const Color(0xFFA78BDB),
                    ],
            ).createShader(bounds),
            child: const Text(
              'AI Chatbot',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 5),
        // GPT 아이콘
        Tooltip(
          message: 'GPT-5',
          child: Container(
            width: 20,
            height: 20,
            child: ColorFiltered(
              colorFilter: isDarkMode
                  ? const ColorFilter.matrix([
                      // 색상 반전 매트릭스 (흰색으로 변환)
                      -1.0, 0.0, 0.0, 0.0, 255.0,
                      0.0, -1.0, 0.0, 0.0, 255.0,
                      0.0, 0.0, -1.0, 0.0, 255.0,
                      0.0, 0.0, 0.0, 1.0, 0.0,
                    ])
                  : const ColorFilter.mode(
                      Colors.transparent, BlendMode.multiply),
              child: Image.asset(
                'assets/icon/ai_models/chatgpt_icon.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  print('GPT 아이콘 로드 실패: $error');
                  return Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: isDarkMode ? Colors.white : const Color(0xFF10A37F),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Gemini 아이콘
        Tooltip(
          message: 'Gemini Flash 2.5',
          child: Container(
            width: 20,
            height: 20,
            child: Image.asset(
              'assets/icon/ai_models/gemini_icon.png',
              width: 20,
              height: 20,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                print('Gemini 아이콘 로드 실패: $error');
                return const Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: Color(0xFF4285F4),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Claude 아이콘
        Tooltip(
          message: 'Claude Sonnet 4.5',
          child: Container(
            width: 20,
            height: 20,
            child: Image.asset(
              'assets/icon/ai_models/claude_icon.png',
              width: 20,
              height: 20,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                print('Claude 아이콘 로드 실패: $error');
                return const Icon(
                  Icons.auto_awesome,
                  size: 20,
                  color: Color(0xFFD97706),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // dispose 메서드 추가 - 스크롤 컨트롤러 해제
  @override
  void dispose() {
    _scrollController.dispose(); // 메모리 누수 방지를 위해 컨트롤러 해제
    // _searchController는 TextEditingControllerMixin에서 자동으로 dispose됨
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDeleteMode = ref.watch(isDeleteModeProvider);
    final selectedItems = ref.watch(selectedForDeleteProvider);
    final hoveredId = ref.watch(hoveredArchiveIdProvider);
    final themeState = ref.watch(themeProvider);

    // 아카이브 순서를 정의하는 함수
    int getArchiveOrder(Map<String, dynamic> archive) {
      final archiveType = archive['archive_type'] ?? '';
      final archiveName = archive['archive_name'] ?? '';

      if (archiveName == '사내업무' ||
          (archiveType == '' && archiveName.contains('사내업무'))) {
        return 1;
      } else if (archiveName == '코딩어시스턴트' || archiveType == 'code') {
        return 2;
      } else if (archiveName == 'SAP 어시스턴트' || archiveType == 'sap') {
        return 3;
      }
      return 4; // 일반 아카이브는 항상 4번째 이후
    }

    // 아카이브 목록 정렬
    final sortedArchives = [...widget.arvHistory];
    sortedArchives
        .sort((a, b) => getArchiveOrder(a).compareTo(getArchiveOrder(b)));

    return Container(
      width: 230,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            themeState.colorScheme.sidebarGradientStart,
            themeState.colorScheme.sidebarGradientEnd,
          ],
        ),
      ),
      child: Column(
        children: [
          ListTile(
            title: Row(
              children: [
                // "대화목록" 텍스트 제거하고 돋보기 아이콘 추가
                Tooltip(
                  message: '대화내용 검색',
                  verticalOffset: 20,
                  preferBelow: true,
                  child: IconButton(
                    icon: Icon(Icons.search,
                        color: themeState.colorScheme.sidebarTextColor,
                        size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => showSearchDialog(context),
                    hoverColor: Colors.white.withValues(alpha:0.2),
                  ),
                ),
                const Spacer(), // 나머지 공간을 채워서 아이콘들을 오른쪽으로 밀기
                Row(
                  mainAxisSize: MainAxisSize.min, // Row의 크기를 내용물에 맞게 조정
                  children: [
                    Tooltip(
                      message: '대화 추가',
                      verticalOffset: 20,
                      preferBelow: true,
                      child: IconButton(
                        icon: Icon(Icons.add_comment_outlined,
                            color: themeState.colorScheme.sidebarTextColor,
                            size: 19),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          // 스트리밍 중인지 확인
                          final isStreaming =
                              ref.read(chatProvider).isStreaming;

                          // 스트리밍 중이라면 새 채팅 생성을 막고 안내 메시지 표시
                          if (isStreaming) {
                            CommonUIUtils.showInfoSnackBar(context,
                                'AI가 응답 중입니다. 응답이 완료된 후 새 채팅을 시작할 수 있습니다.');
                            return;
                          }

                          // PDF 파일 첨부 상태 확인 (실시간으로 watch)
                          final attachmentState = ref.watch(attachmentProvider);
                          final currentAttachments = attachmentState.files;

                          print('\n🔍 === 새 채팅 생성 버튼 클릭 - 첨부 상태 확인 ===');
                          print('총 첨부 파일 수: ${currentAttachments.length}');
                          print('첨부 파일 목록:');
                          for (var i = 0; i < currentAttachments.length; i++) {
                            final file = currentAttachments[i];
                            print('  ${i + 1}. ${file.name}');
                            print('     - extension: ${file.extension}');
                            print('     - mimeType: ${file.mimeType}');
                            print('     - size: ${file.size} bytes');
                          }

                          final hasPdfFiles = currentAttachments.any((file) {
                            final extension =
                                file.extension?.toLowerCase() ?? '';
                            final isPdf = extension == 'pdf';
                            print(
                                '파일 체크: ${file.name}, extension="$extension", isPdf=$isPdf');
                            return isPdf;
                          });

                          print('🎯 PDF 파일 첨부 여부: $hasPdfFiles');
                          print('=== 첨부 상태 확인 완료 ===\n');

                          // PDF 파일이 첨부된 상태에서는 새 채팅 생성 차단
                          if (hasPdfFiles) {
                            final pdfFileNames = currentAttachments
                                .where((file) =>
                                    file.extension?.toLowerCase() == 'pdf')
                                .map((file) => file.name)
                                .join(', ');

                            print('🚫 사이드바에서 PDF 첨부 상태로 새 채팅 생성 차단');
                            print('첨부된 PDF 파일: $pdfFileNames');

                            CommonUIUtils.showWarningSnackBar(
                              context,
                              'PDF 파일이 첨부된 상태에서는 새 채팅을 시작할 수 없습니다.\n'
                              '첨부된 PDF 파일: $pdfFileNames\n'
                              '파일 첨부를 삭제한 후 새 채팅을 시작할 수 있습니다.',
                            );
                            return; // 여기서 완전히 중단, createNewArchive 호출하지 않음
                          }

                          // PDF도 없고 스트리밍 중도 아니라면 정상적으로 새 채팅 생성
                          print('✅ 사이드바에서 새 채팅 생성 허용');
                          ref
                              .read(chatProvider.notifier)
                              .createNewArchive()
                              .then((archiveId) async {
                            if (archiveId.isNotEmpty) {
                              print('✅ 새 채팅 생성 완료, 아카이브 ID: $archiveId');
                              await ref
                                  .read(chatProvider.notifier)
                                  .selectTopic(archiveId);
                            }
                          });
                        },
                        hoverColor: Colors.white.withValues(alpha:0.2),
                      ),
                    ),
                    const SizedBox(width: 12), // 아이콘 사이 간격
                    Tooltip(
                      message: isDeleteMode ? '대화 선택 삭제 확인' : '대화 선택 삭제',
                      verticalOffset: 20,
                      preferBelow: true,
                      child: IconButton(
                        icon: Icon(
                          isDeleteMode
                              ? Icons.delete_forever_outlined
                              : Icons.delete_outline,
                          color: isDeleteMode
                              ? themeState.colorScheme.warningColor
                              : themeState.colorScheme.sidebarTextColor,
                          size: 19,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (isDeleteMode && selectedItems.isNotEmpty) {
                            CommonUIUtils.showConfirmDialog(
                              context,
                              '확인',
                              '선택한 대화를 삭제하시겠습니까?',
                            ).then((confirmed) {
                              if (confirmed == true) {
                                // 선택된 아카이브 일괄 삭제 실행
                                ref
                                    .read(chatProvider.notifier)
                                    .deleteSelectedArchives(
                                        context, selectedItems);
                                ref.read(isDeleteModeProvider.notifier).state =
                                    false;
                                ref
                                    .read(selectedForDeleteProvider.notifier)
                                    .state = {};
                              } else {
                                // 취소 시에도 삭제 모드를 종료하고 체크박스를 모두 해제
                                ref.read(isDeleteModeProvider.notifier).state =
                                    false;
                                ref
                                    .read(selectedForDeleteProvider.notifier)
                                    .state = {};
                              }
                            });
                          } else {
                            ref.read(isDeleteModeProvider.notifier).state =
                                !isDeleteMode;
                            ref.read(selectedForDeleteProvider.notifier).state =
                                {};
                          }
                        },
                        hoverColor: Colors.white.withValues(alpha:0.2),
                      ),
                    ),
                    const SizedBox(width: 12), // 아이콘 사이 간격
                    Tooltip(
                      message: '사이드바 축소',
                      verticalOffset: 20,
                      preferBelow: true,
                      child: IconButton(
                        icon: Icon(Icons.menu,
                            color: themeState.colorScheme.sidebarTextColor,
                            size: 19),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: widget.onToggleSidebar,
                        hoverColor: Colors.white.withValues(alpha:0.2),
                      ),
                    ),
                    const SizedBox(width: 0), // 마지막 아이콘 뒤 여백
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                scrollbarTheme: ScrollbarThemeData(
                  thumbColor:
                      MaterialStateProperty.all(Colors.grey.withValues(alpha:0.4)),
                  thickness: MaterialStateProperty.all(6.0),
                  radius: const Radius.circular(10),
                  thumbVisibility: MaterialStateProperty.all(true),
                  trackVisibility: MaterialStateProperty.all(false),
                  trackColor: MaterialStateProperty.all(Colors.transparent),
                ),
              ),
              child: Scrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: sortedArchives.length,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemBuilder: (context, index) {
                    final archive = sortedArchives[index];
                    final topic = archive['archive_name'];
                    final topicId = archive['archive_id'];
                    final archiveType = archive['archive_type'] ?? '';

                    final isSelected = selectedItems.contains(topicId);
                    final isHovered = hoveredId == topicId;
                    final isCurrentTopic = topicId == widget.selectedTopic;
                    final isDefault = isDefaultArchive(archive);

                    // 아카이브 타입에 따른 설명 텍스트 가져오기
                    final String? description =
                        _archiveDescriptions[archiveType];
                    final bool hasDescription =
                        description != null && isDefault;

                    return MouseRegion(
                      onEnter: (_) => ref
                          .read(hoveredArchiveIdProvider.notifier)
                          .state = topicId,
                      onExit: (_) => ref
                          .read(hoveredArchiveIdProvider.notifier)
                          .state = null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (isDeleteMode) {
                                // 디폴트 아카이브인 경우 선택 방지
                                if (isDefault) {
                                  // 디폴트 아카이브 선택 시도 시 사용자에게 알림
                                  CommonUIUtils.showInfoSnackBar(context,
                                      '기본 아카이브는 삭제할 수 없습니다. 개별 관리 메뉴에서 초기화할 수 있습니다.');
                                  return; // 추가 처리하지 않고 함수 종료
                                }

                                // 일반 아카이브는 기존 로직대로 처리
                                final selectedItems = ref
                                    .read(selectedForDeleteProvider.notifier);
                                if (selectedItems.state.contains(topicId)) {
                                  selectedItems.state = {...selectedItems.state}
                                    ..remove(topicId);
                                } else {
                                  selectedItems.state = {
                                    ...selectedItems.state,
                                    topicId
                                  };
                                }
                              } else {
                                // PDF 파일 첨부 상태 확인 (ref.read 방식으로 간단하게)
                                final currentAttachments =
                                    ref.read(attachmentProvider).files;
                                final hasPdfFiles = currentAttachments.any(
                                    (file) =>
                                        file.extension?.toLowerCase() == 'pdf');

                                // PDF 파일이 첨부된 상태에서는 아카이브 전환 차단
                                if (hasPdfFiles) {
                                  final pdfFileNames = currentAttachments
                                      .where((file) =>
                                          file.extension?.toLowerCase() ==
                                          'pdf')
                                      .map((file) => file.name)
                                      .join(', ');

                                  CommonUIUtils.showWarningSnackBar(
                                    context,
                                    'PDF 파일이 첨부된 상태에서는 다른 아카이브로 이동할 수 없습니다.\n'
                                    '첨부된 PDF 파일: $pdfFileNames\n'
                                    '파일 첨부를 삭제한 후 이동 가능합니다.',
                                  );
                                  return; // 여기서 완전히 중단, onTopicSelected 호출하지 않음
                                }

                                // 스트리밍 중인지 확인
                                final isStreaming =
                                    ref.read(chatProvider).isStreaming;

                                // 스트리밍 중이라면 아카이브 전환을 막고 안내 메시지 표시
                                if (isStreaming) {
                                  CommonUIUtils.showInfoSnackBar(context,
                                      'AI가 응답 중입니다. 응답이 완료된 후 아카이브를 전환할 수 있습니다.');
                                  return;
                                }

                                // PDF도 없고 스트리밍 중도 아니라면 정상적으로 아카이브 전환
                                widget.onTopicSelected(topicId);
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2), // ChatGPT 스타일 여백 추가
                              decoration: BoxDecoration(
                                color: isCurrentTopic
                                    ? (themeState.themeMode ==
                                            AppThemeMode.light
                                        ? (topic == 'AI Chatbot'
                                            ? const Color(0xFF6B46C1)
                                                .withValues(alpha:
                                                    0.08) // AI Chatbot은 은은한 보라색
                                            : const Color(
                                                0xFFE5E7EB)) // 다른 아카이브는 밝은 회색 (선택됨)
                                        : Colors.white.withValues(alpha:
                                            0.1)) // Dark 테마: 밝은 흰색 투명도
                                    : isHovered
                                        ? (themeState.themeMode ==
                                                AppThemeMode.light
                                            ? (topic == 'AI Chatbot'
                                                ? const Color(0xFF6B46C1)
                                                    .withValues(alpha:
                                                        0.05) // AI Chatbot은 더 은은한 보라색 (호버)
                                                : const Color(
                                                    0xFFE5E7EB)) // 다른 아카이브는 더 진한 회색 (호버)
                                            : Colors.white.withValues(alpha:
                                                0.05)) // Dark 테마: 더 연한 흰색 투명도
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                    8), // ChatGPT 스타일 둥근 모서리 추가
                                // AI Chatbot만 추가 boxShadow 적용
                                boxShadow: topic == 'AI Chatbot'
                                    ? [
                                        BoxShadow(
                                          color:
                                              _getDefaultArchiveColor(archive)
                                                  .withValues(alpha:0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: ListTile(
                                selected: isSelected || isCurrentTopic,
                                selectedTileColor: Colors.blue.withValues(alpha:0.1),
                                // 기본 아카이브에는 아이콘 추가
                                leading: isDeleteMode
                                    ? isDefault
                                        ? null
                                        : Checkbox(
                                            value: isSelected,
                                            onChanged: (bool? value) {
                                              final selectedItems = ref.read(
                                                  selectedForDeleteProvider
                                                      .notifier);
                                              if (value == true) {
                                                selectedItems.state = {
                                                  ...selectedItems.state,
                                                  topicId
                                                };
                                              } else {
                                                selectedItems.state = {
                                                  ...selectedItems.state
                                                }..remove(topicId);
                                              }
                                            },
                                            fillColor: MaterialStateProperty
                                                .resolveWith(
                                                    (states) => Colors.white),
                                            checkColor: Colors.blue,
                                          )
                                    : isDefault
                                        ? Icon(
                                            _getDefaultArchiveIcon(archive),
                                            color: _getDefaultArchiveColor(
                                                archive),
                                            size: 18,
                                          )
                                        : Icon(
                                            Icons.chat_bubble_outline,
                                            color: ref
                                                .watch(themeProvider)
                                                .colorScheme
                                                .sidebarTextColor
                                                .withValues(alpha:0.7),
                                            size: 18,
                                          ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: topic == 'AI Chatbot'
                                          ? _buildAIChatbotTitle()
                                          : Text(
                                              topic,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: themeState.themeMode ==
                                                        AppThemeMode.light
                                                    ? Colors
                                                        .black // 라이트 테마에서는 완전히 검정색
                                                    : Colors
                                                        .white, // 다크모드일 때는 밝은 흰색으로 변경
                                                fontWeight: isDefault
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                fontSize: (topic == '코딩어시스턴트' ||
                                                        archiveType == 'code' ||
                                                        topic == '사내업무' ||
                                                        topic == 'SAP 어시스턴트' ||
                                                        archiveType == 'sap')
                                                    ? 14.0 // AI Chatbot 제외한 기본 아카이브 글자크기 작게
                                                    : null, // 다른 아카이브는 기본 크기
                                              ),
                                            ),
                                    ),
                                    // 기본 아카이브에는 작은 태그 표시 (태그가 비어있지 않을 때만)
                                    if (isDefault &&
                                        !isDeleteMode &&
                                        !isHovered &&
                                        _getDefaultArchiveTag(archive)
                                            .isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          // AI Chatbot만 그라데이션 배경
                                          gradient: topic == 'AI Chatbot'
                                              ? LinearGradient(
                                                  colors: [
                                                    _getDefaultArchiveColor(
                                                            archive)
                                                        .withValues(alpha:0.3),
                                                    _getDefaultArchiveColor(
                                                            archive)
                                                        .withValues(alpha:0.1),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                              : null,
                                          color: topic != 'AI Chatbot'
                                              ? _getDefaultArchiveColor(archive)
                                                  .withValues(alpha:0.2)
                                              : null,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          // AI Chatbot만 추가 테두리
                                          border: topic == 'AI Chatbot'
                                              ? Border.all(
                                                  color:
                                                      _getDefaultArchiveColor(
                                                              archive)
                                                          .withValues(alpha:0.3),
                                                  width: 1.2,
                                                )
                                              : null,
                                        ),
                                        child: Text(
                                          _getDefaultArchiveTag(archive),
                                          style: TextStyle(
                                            color: _getDefaultArchiveColor(
                                                archive),
                                            fontSize: topic == 'AI Chatbot'
                                                ? 9
                                                : 10, // AI Chatbot은 조금 더 작게
                                            fontWeight: FontWeight.bold,
                                            // AI Chatbot만 추가 스타일
                                            letterSpacing:
                                                topic == 'AI Chatbot' ? 0.5 : 0,
                                          ),
                                        ),
                                      ),
                                    // AlertDialog 표시 부분
                                    if (!isDeleteMode && isHovered)
                                      Tooltip(
                                        message: '아카이브 관리',
                                        child: IconButton(
                                          icon: Icon(Icons.more_vert,
                                              color: ref
                                                  .watch(themeProvider)
                                                  .colorScheme
                                                  .sidebarTextColor,
                                              size: 20),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            // 기본 아카이브 여부 확인
                                            final archiveType =
                                                archive['archive_type'] ?? '';
                                            final isCodeAssistant =
                                                topic == '코딩어시스턴트' ||
                                                    archiveType == 'code';
                                            final isSapAssistant =
                                                topic == 'SAP 어시스턴트' ||
                                                    archiveType == 'sap';
                                            final isBusinessArchive =
                                                topic == '사내업무';
                                            final isAdvancedAssistant =
                                                topic == 'AI Chatbot';
                                            final isDefaultArchive =
                                                isCodeAssistant ||
                                                    isSapAssistant ||
                                                    isBusinessArchive ||
                                                    isAdvancedAssistant;

                                            showDialog(
                                              context: context,
                                              builder: (context) {
                                                final isDarkTheme =
                                                    Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark;
                                                return AlertDialog(
                                                  title: Text(
                                                    isDefaultArchive
                                                        ? '기본 아카이브 관리'
                                                        : '대화 관리',
                                                    style: TextStyle(
                                                      color: isDarkTheme
                                                          ? Colors.white
                                                          : null,
                                                    ),
                                                  ),
                                                  content: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      // 기본 아카이브가 아닌 경우만 '이름 변경' 옵션 표시
                                                      if (!isDefaultArchive)
                                                        ListTile(
                                                          leading: const Icon(
                                                              Icons.edit),
                                                          title: const Text(
                                                              '이름 변경'),
                                                          onTap: () {
                                                            Navigator.pop(
                                                                context);
                                                            _showEditDialog(
                                                                context,
                                                                topicId,
                                                                topic);
                                                          },
                                                        ),
                                                      // 모든 아카이브에 '삭제' 또는 '초기화' 옵션 표시
                                                      ListTile(
                                                        leading: Icon(
                                                            isDefaultArchive
                                                                ? Icons.refresh
                                                                : Icons.delete),
                                                        title: Text(
                                                            isDefaultArchive
                                                                ? '초기화'
                                                                : '삭제'),
                                                        onTap: () {
                                                          Navigator.pop(
                                                              context);
                                                          _showDeleteConfirmDialog(
                                                              context, topicId);
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context),
                                                      child: const Text('취소'),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                                onTap: isDeleteMode
                                    ? () {
                                        // 디폴트 아카이브인 경우 선택 방지
                                        if (isDefault) {
                                          CommonUIUtils.showInfoSnackBar(
                                              context,
                                              '기본 아카이브는 삭제할 수 없습니다. 개별 관리 메뉴에서 초기화할 수 있습니다.');
                                          return;
                                        }

                                        // 일반 아카이브는 기존 로직대로 처리
                                        final selectedItems = ref.read(
                                            selectedForDeleteProvider.notifier);
                                        if (isSelected) {
                                          selectedItems.state = {
                                            ...selectedItems.state
                                          }..remove(topicId);
                                        } else {
                                          selectedItems.state = {
                                            ...selectedItems.state,
                                            topicId
                                          };
                                        }
                                      }
                                    : () {
                                        // PDF 파일 첨부 상태 확인 (ref.read 방식으로 간단하게)
                                        final currentAttachments =
                                            ref.read(attachmentProvider).files;
                                        final hasPdfFiles =
                                            currentAttachments.any((file) =>
                                                file.extension?.toLowerCase() ==
                                                'pdf');

                                        // PDF 파일이 첨부된 상태에서는 아카이브 전환 차단
                                        if (hasPdfFiles) {
                                          final pdfFileNames =
                                              currentAttachments
                                                  .where((file) =>
                                                      file.extension
                                                          ?.toLowerCase() ==
                                                      'pdf')
                                                  .map((file) => file.name)
                                                  .join(', ');

                                          CommonUIUtils.showWarningSnackBar(
                                            context,
                                            'PDF 파일이 첨부된 상태에서는 다른 아카이브로 이동할 수 없습니다.\n'
                                            '첨부된 PDF 파일: $pdfFileNames\n'
                                            '파일 첨부를 삭제한 후 이동 가능합니다.',
                                          );
                                          return; // 여기서 완전히 중단, onTopicSelected 호출하지 않음
                                        }

                                        // 스트리밍 중인지 확인
                                        final isStreaming =
                                            ref.read(chatProvider).isStreaming;

                                        // 스트리밍 중이라면 아카이브 전환을 막고 안내 메시지 표시
                                        if (isStreaming) {
                                          CommonUIUtils.showInfoSnackBar(
                                              context,
                                              'AI가 응답 중입니다. 응답이 완료된 후 아카이브를 전환할 수 있습니다.');
                                          return;
                                        }

                                        // PDF도 없고 스트리밍 중도 아니라면 정상적으로 아카이브 전환
                                        widget.onTopicSelected(topicId);
                                      },
                              ),
                            ),
                          ),
                          // 아카이브 설명 추가 (디폴트 아카이브이고 설명이 있는 경우에만)
                          if (hasDescription && !isDeleteMode)
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 14.0, right: 8.0, bottom: 8.0),
                              child: Text(
                                description,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 11,
                                  // fontStyle: FontStyle.italic, // 이탤릭체 제거
                                  height: 1.2,
                                ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // Container(
          //   padding:
          //       const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          //   decoration: BoxDecoration(
          //     color:
          //         ref.watch(themeProvider).colorScheme.sidebarBackgroundColor,
          //   ),
          //   child: Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     children: [
          //       Row(
          //         children: [
          //           Icon(
          //             Icons.warning_amber_rounded,
          //             color: themeState.themeMode == AppThemeMode.light
          //                 ? Colors.amber[700] // 라이트 테마: 더 진한 amber
          //                 : Colors.amber[300],
          //             size: 16,
          //           ),
          //           const SizedBox(width: 8),
          //           Text(
          //             '응답 오류 해결 방법',
          //             style: TextStyle(
          //               color: themeState.themeMode == AppThemeMode.light
          //                   ? Colors.black // 라이트 테마: 검정색
          //                   : Colors.amber[300],
          //               fontWeight: FontWeight.bold,
          //               fontSize: 13,
          //             ),
          //           ),
          //         ],
          //       ),
          //       const SizedBox(height: 6),
          //       Text(
          //         'AI가 응답을 생성하지 못하는 경우, 새로운 채팅방을 생성하거나 사내업무 방의 경우 초기화를 통해 문제를 해결할 수 있습니다.',
          //         style: TextStyle(
          //           color: themeState.themeMode == AppThemeMode.light
          //               ? Colors.black87 // 라이트 테마: 검정색 (약간 투명)
          //               : Colors.grey[300],
          //           fontSize: 11,
          //           height: 1.4,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
          // 업무 메뉴 섹션 추가
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            decoration: BoxDecoration(
              color:
                  ref.watch(themeProvider).colorScheme.sidebarBackgroundColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.business_center_rounded,
                      color: themeState.themeMode == AppThemeMode.light
                          ? const Color(0xFF4A6CF7)
                          : const Color(0xFF8B5CF6),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '업무',
                      style: TextStyle(
                        color: themeState.themeMode == AppThemeMode.light
                            ? Colors.black
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 미구현: 전자결재 버튼 투명 처리 (공간만 유지)
                IgnorePointer(
                  ignoring: true,
                  child: Opacity(
                    opacity: 0.0,
                    child: _buildWorkMenuItem(
                      context,
                      Icons.description_rounded,
                      '전자결재',
                      const Color(0xFF6B7280),
                      () => _navigateToSignFlow(context),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // 미구현: 휴가관리 버튼 투명 처리 (공간만 유지)
                IgnorePointer(
                  ignoring: true,
                  child: Opacity(
                    opacity: 0.0,
                    child: _buildWorkMenuItem(
                      context,
                      Icons.beach_access_rounded,
                      '휴가관리',
                      const Color(0xFF6B7280),
                      () => _navigateToLeaveManagement(context),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 도움말 버튼 추가 (새로 추가된 부분)
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color:
                  ref.watch(themeProvider).colorScheme.sidebarBackgroundColor,
            ),
            child: InkWell(
              onTap: () => _showHelpDialog(context),
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    color: themeState.themeMode == AppThemeMode.light
                        ? Colors.black54 // 라이트 테마: 검정색 (투명)
                        : ref
                            .watch(themeProvider)
                            .colorScheme
                            .sidebarTextColor
                            .withValues(alpha:0.7),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AI에이전트 사용가이드',
                    style: TextStyle(
                      color: themeState.themeMode == AppThemeMode.light
                          ? Colors.black // 라이트 테마: 검정색
                          : ref
                              .watch(themeProvider)
                              .colorScheme
                              .sidebarTextColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, String topicId, String currentTitle) {
    CommonUIUtils.showTextInputDialog(
      context,
      '대화명 변경',
      '새로운 대화명 입력',
      initialValue: currentTitle,
    ).then((newTitle) {
      if (newTitle != null && newTitle.isNotEmpty) {
        // 기본 아카이브 이름들로는 변경할 수 없도록 제한
        final restrictedNames = ['사내업무', 'AI Chatbot', '코딩어시스턴트', 'SAP 어시스턴트'];
        if (restrictedNames.contains(newTitle)) {
          CommonUIUtils.showWarningSnackBar(
              context, '"$newTitle"는 기본 아카이브 이름으로 사용할 수 없습니다.');
          return;
        }
        widget.onEditTopic(topicId, newTitle);
      }
    });
  }

  // _showDeleteConfirmDialog 메서드 수정
  void _showDeleteConfirmDialog(BuildContext context, String topicId) {
    // 아카이브 정보 확인
    final archive = widget.arvHistory.firstWhere(
      (a) => a['archive_id'] == topicId,
      orElse: () => {},
    );

    final topic = archive['archive_name'] ?? '';
    final archiveType = archive['archive_type'] ?? '';

    // 기본 아카이브 여부 확인
    final isCodeAssistant = topic == '코딩어시스턴트' || archiveType == 'code';
    final isSapAssistant = topic == 'SAP 어시스턴트' || archiveType == 'sap';
    final isBusinessArchive = topic == '사내업무';
    final isAdvancedAssistant = topic == 'AI Chatbot';
    final isDefaultArchive = isCodeAssistant ||
        isSapAssistant ||
        isBusinessArchive ||
        isAdvancedAssistant;

    final dialogTitle = isDefaultArchive ? '대화 내용 초기화' : '대화 삭제';
    final dialogContent = isDefaultArchive
        ? '기본 아카이브의 대화 내용을 초기화하시겠습니까?\n새로운 동일 유형의 아카이브가 생성됩니다.'
        : '이 대화를 삭제하시겠습니까?';

    CommonUIUtils.showConfirmDialog(
      context,
      dialogTitle,
      dialogContent,
    ).then((confirmed) {
      if (confirmed == true) {
        if (isDefaultArchive) {
          // 기본 아카이브인 경우 삭제 후 재생성
          _deleteAndRecreateDefaultArchive(
              context, topicId, archiveType, topic);
        } else {
          // 일반 아카이브는 그냥 삭제
          widget.onDeleteTopic(topicId);
        }
      }
    });
  }

  // 새로운 메서드: 기본 아카이브 삭제 후 재생성
  void _deleteAndRecreateDefaultArchive(BuildContext context, String archiveId,
      String archiveType, String archiveName) async {
    try {
      final chatNotifier = ref.read(chatProvider.notifier);

      // 1. 메시지를 표시하여 사용자에게 알림 (mounted 체크 추가)
      if (context.mounted) {
        CommonUIUtils.showInfoSnackBar(context, '대화 내용을 초기화하는 중...');
      }

      // 2. 아카이브 정보 저장 (chatNotifier에서 처리하도록 수정)
      String newArchiveType = '';
      if (archiveName == '사내업무' || archiveType == '') {
        newArchiveType = ''; // 사내업무는 빈 타입
      } else if (archiveName == '코딩어시스턴트' || archiveType == 'code') {
        newArchiveType = 'code';
      } else if (archiveName == 'SAP 어시스턴트' || archiveType == 'sap') {
        newArchiveType = 'sap';
      } else if (archiveName == 'AI Chatbot') {
        newArchiveType = ''; // AI Chatbot도 빈 타입
      }

      // 3. ChatNotifier에 재생성 요청
      await chatNotifier.resetArchive(
          context, archiveId, newArchiveType, archiveName);

      // 4. 완료 메시지 (mounted 체크 추가)
      if (context.mounted) {
        CommonUIUtils.showSuccessSnackBar(context, '대화 내용이 초기화되었습니다.');
      }
    } catch (e) {
      print('아카이브 초기화 실패: $e');
      // 오류 발생 시에도 mounted 체크
      if (context.mounted) {
        CommonUIUtils.showErrorSnackBar(context, '대화 내용 초기화 중 오류가 발생했습니다.');
      }
    }
  }

  // 기본 아카이브 여부 확인
  bool isDefaultArchive(Map<String, dynamic> archive) {
    final archiveType = archive['archive_type'] ?? '';
    final archiveName = archive['archive_name'] ?? '';

    // 아카이브 타입으로 먼저 확인
    if (archiveType == 'code' || archiveType == 'sap') {
      return true;
    }

    // 이름으로 확인하는 디폴트 아카이브들
    if (archiveName == '사내업무' || archiveName == 'AI Chatbot') {
      return true;
    }

    return false;
  }

  // 기본 아카이브 아이콘 결정
  IconData _getDefaultArchiveIcon(Map<String, dynamic> archive) {
    final String archiveType = archive['archive_type'] ?? '';
    final String archiveName = archive['archive_name'] ?? '';

    if (archiveType == 'code' || archiveName == '코딩어시스턴트') {
      return Icons.code;
    } else if (archiveType == 'sap' || archiveName == 'SAP 어시스턴트') {
      return Icons.business;
    } else if (archiveName == 'AI Chatbot') {
      return Icons.auto_awesome; // 프리미엄한 느낌의 반짝이는 아이콘
    } else if (archiveName == '사내업무') {
      return Icons.lock; // 보안이 지켜진다는 느낌의 자물쇠 아이콘
    }

    return Icons.star;
  }

  // 기본 아카이브 색상 결정
  Color _getDefaultArchiveColor(Map<String, dynamic> archive) {
    final String archiveType = archive['archive_type'] ?? '';
    final String archiveName = archive['archive_name'] ?? '';

    // Light theme에서는 회색 그라데이션 배경에 어울리는 밝은 색상들 사용
    final themeState = ref.watch(themeProvider);
    if (themeState.themeMode == AppThemeMode.light) {
      if (archiveType == 'code' || archiveName == '코딩어시스턴트') {
        return const Color(0xFF10B981); // 에메랄드 그린
      } else if (archiveType == 'sap' || archiveName == 'SAP 어시스턴트') {
        return const Color(0xFF3B82F6); // 밝은 블루
      } else if (archiveName == 'AI Chatbot') {
        return const Color(0xFF6B46C1); // 딥 퍼플 (모던하고 프리미엄한 느낌)
      } else if (archiveName == '사내업무') {
        return const Color(0xFFF59E0B); // 앰버 오렌지
      }
      return const Color(0xFFA855F7); // 보라색
    }

    // 다른 테마에서는 기존 색상 유지
    if (archiveType == 'code' || archiveName == '코딩어시스턴트') {
      return Colors.green;
    } else if (archiveType == 'sap' || archiveName == 'SAP 어시스턴트') {
      return Colors.blue;
    } else if (archiveName == 'AI Chatbot') {
      return const Color(0xFFE879F9); // Dark 테마에서는 더 밝은 핫 핑크 (가시성 향상)
    } else if (archiveName == '사내업무') {
      return Colors.orange;
    }

    return Colors.purple;
  }

  // 기본 아카이브 태그 텍스트 결정
  String _getDefaultArchiveTag(Map<String, dynamic> archive) {
    final String archiveType = archive['archive_type'] ?? '';
    final String archiveName = archive['archive_name'] ?? '';

    if (archiveType == 'code' || archiveName == '코딩어시스턴트') {
      return 'CODE';
    } else if (archiveType == 'sap' || archiveName == 'SAP 어시스턴트') {
      return 'SAP';
    } else if (archiveName == 'AI Chatbot') {
      return ''; // PRO 태그 제거
    } else if (archiveName == '사내업무') {
      return '기본';
    }

    return '기본';
  }

  // 도움말 다이얼로그를 표시하는 메서드
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI에이전트 사용가이드'),
        content: const SizedBox(
          width: 800,
          height: 600,
          child: HelpGuideDialog(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  // 검색 다이얼로그를 표시하는 메서드 (외부에서 호출 가능하도록 public으로 변경)
  void showSearchDialog(BuildContext context) {
    // 검색 결과 초기화
    _searchResults = [];
    _searchController.clear();
    _isSearching = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          final themeState = ref.watch(themeProvider);
          final isDarkMode = themeState.themeMode != AppThemeMode.light;

          // 아카이브별로 결과 그룹화
          Map<String, List<Map<String, dynamic>>> groupedResults = {};

          // 검색 결과가 있을 때 아카이브별로 그룹화
          if (_searchResults.isNotEmpty) {
            for (var result in _searchResults) {
              final archiveName = result['archive_name'] as String;
              if (!groupedResults.containsKey(archiveName)) {
                groupedResults[archiveName] = [];
              }
              groupedResults[archiveName]!.add(result);
            }
          }

          // 아카이브 이름 목록 (탭으로 사용)
          List<String> archiveNames = groupedResults.keys.toList();

          // 기본 아카이브와 일반 아카이브 분리
          List<String> defaultArchives = [];
          List<String> customArchives = [];

          // 아카이브 분류
          for (String name in archiveNames) {
            if (name == '사내업무' ||
                name == '코딩어시스턴트' ||
                name == '코딩 어시스턴트' ||
                name == 'SAP어시스턴트' ||
                name == 'SAP 어시스턴트' ||
                name == 'AI Chatbot') {
              defaultArchives.add(name);
            } else {
              customArchives.add(name);
            }
          }

          // 기본 아카이브는 고정 순서로 정렬
          defaultArchives.sort((a, b) {
            int getArchiveOrder(String name) {
              if (name == '사내업무') return 1;
              if (name == '코딩어시스턴트' || name == '코딩 어시스턴트') return 2;
              if (name == 'SAP어시스턴트' || name == 'SAP 어시스턴트') return 3;
              if (name == 'AI Chatbot') return 4;
              return 5;
            }

            return getArchiveOrder(a).compareTo(getArchiveOrder(b));
          });

          // 일반 아카이브는 최신 생성순(archive_time 내림차순)으로 정렬
          customArchives.sort((a, b) {
            // 각 아카이브의 첫 번째 결과에서 archive_time 비교
            final aTime =
                groupedResults[a]!.first['archive_time'] as String? ?? '';
            final bTime =
                groupedResults[b]!.first['archive_time'] as String? ?? '';

            // 내림차순 정렬(최신이 먼저)
            return bTime.compareTo(aTime);
          });

          // 모든 아카이브를 함께 정렬 (기본 아카이브는 고정 위치, 일반 아카이브는 시간순)
          archiveNames.sort((a, b) {
            // 기본 아카이브 확인
            bool isDefaultA = defaultArchives.contains(a);
            bool isDefaultB = defaultArchives.contains(b);

            // 둘 다 기본 아카이브면 지정된 순서대로
            if (isDefaultA && isDefaultB) {
              int orderA = defaultArchives.indexOf(a);
              int orderB = defaultArchives.indexOf(b);
              return orderA.compareTo(orderB);
            }

            // 기본 아카이브가 항상 먼저
            if (isDefaultA) return -1;
            if (isDefaultB) return 1;

            // 둘 다 일반 아카이브면 시간 내림차순(최신이 먼저)
            final aTime =
                groupedResults[a]!.first['archive_time'] as String? ?? '';
            final bTime =
                groupedResults[b]!.first['archive_time'] as String? ?? '';
            return bTime.compareTo(aTime); // 내림차순 - 더 최신(늦게 생성된) 아카이브가 앞에 옴
          });

          return DefaultTabController(
            length: archiveNames.isEmpty ? 1 : archiveNames.length,
            child: AlertDialog(
              backgroundColor:
                  isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              title: Row(
                children: [
                  Icon(Icons.search,
                      color: isDarkMode ? Colors.white : Colors.blue),
                  const SizedBox(width: 10),
                  Text(
                    '대화 내용 검색',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  // 결과 수 표시
                  if (_searchResults.isNotEmpty && !_isSearching)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.blue.withValues(alpha:0.2)
                            : Colors.blue.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_searchResults.length}개 결과',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white : Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              content: SizedBox(
                width: 550, // 대화상자 너비 약간 증가
                height: 450, // 대화상자 높이 약간 증가
                child: Column(
                  children: [
                    // 검색 필드
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.grey[800]
                            : Colors.grey.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: '검색어를 입력하세요',
                          hintStyle: TextStyle(
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            icon: Icon(Icons.clear,
                                color: isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setDialogState(() {
                                _searchResults = [];
                                _isSearching = false;
                              });
                            },
                          ),
                        ),
                        onSubmitted: (value) {
                          _performSearch(value, setDialogState);
                        },
                        autofocus: true, // 다이얼로그 열릴 때 자동 포커스
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 검색 상태 표시
                    if (_isSearching)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                color: isDarkMode ? Colors.white : Colors.blue,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '검색 중...',
                                style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_searchResults.isEmpty)
                      // 검색 결과가 없을 때 안내 메시지
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: isDarkMode
                                    ? Colors.grey[600]
                                    : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '검색어를 입력하면 대화 내용을 검색합니다',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      // 검색 결과가 있을 때 탭 및 결과 표시
                      Expanded(
                        child: Column(
                          children: [
                            // 탭바 추가
                            TabBar(
                              isScrollable: true, // 탭이 많을 때 스크롤 가능하도록
                              labelColor:
                                  isDarkMode ? Colors.white : Colors.black,
                              unselectedLabelColor: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.black54,
                              indicatorColor:
                                  isDarkMode ? Colors.grey[600] : Colors.blue,
                              tabs: archiveNames.map((name) {
                                final count = groupedResults[name]!.length;
                                return Tab(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(name),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDarkMode
                                              ? Colors.blue.withValues(alpha:0.2)
                                              : Colors.blue.withValues(alpha:0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '$count',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isDarkMode
                                                ? Colors.white
                                                : Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            // 탭바 뷰 추가
                            Expanded(
                              child: TabBarView(
                                children: archiveNames.map((name) {
                                  final results = groupedResults[name]!;
                                  return ListView.builder(
                                    itemCount: results.length,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    itemBuilder: (context, index) {
                                      final result = results[index];
                                      final isTitle =
                                          result['match_type'] == 'title';
                                      final snippet =
                                          result['snippet'] as String?;
                                      final matchText =
                                          result['match_text'] as String;

                                      return Card(
                                        elevation: 0,
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 4, horizontal: 2),
                                        color: isDarkMode
                                            ? const Color(0xFF2D2D30)
                                            : Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: InkWell(
                                          onTap: () {
                                            final archiveId =
                                                result['archive_id'] as String;
                                            final chatId =
                                                result['chat_id'] as int?;
                                            final searchText = matchText;

                                            // 검색어와 채팅 ID 저장
                                            if (!isTitle && chatId != null) {
                                              ref
                                                  .read(chatProvider.notifier)
                                                  .setSearchHighlight(
                                                    searchText,
                                                    chatId,
                                                  );
                                            }

                                            Navigator.pop(context);

                                            // 선택한 검색 결과의 아카이브로 이동
                                            widget.onTopicSelected(archiveId);

                                            // 채팅 ID가 있는 경우 해당 채팅으로 스크롤 기능 추가 가능
                                            if (!isTitle &&
                                                result['chat_id'] != null) {
                                              CommonUIUtils.showInfoSnackBar(
                                                  context,
                                                  '검색 결과 "${matchText}"(으)로 이동했습니다');
                                            }
                                          },
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // 번호 표시 추가
                                                Container(
                                                  width: 24,
                                                  height: 24,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    color: isDarkMode
                                                        ? Colors.blue
                                                            .withValues(alpha:0.2)
                                                        : Colors.blue
                                                            .withValues(alpha:0.1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  margin: const EdgeInsets.only(
                                                      right: 8, top: 2),
                                                  child: Text(
                                                    '${index + 1}',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                      color: isDarkMode
                                                          ? Colors.white
                                                          : Colors.blue,
                                                    ),
                                                  ),
                                                ),
                                                // 아이콘 컨테이너 삭제
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      isTitle
                                                          ? Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 8,
                                                                vertical: 2,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: isDarkMode
                                                                    ? Colors
                                                                        .orange
                                                                        .withValues(alpha:
                                                                            0.2)
                                                                    : Colors
                                                                        .orange
                                                                        .withValues(alpha:
                                                                            0.1),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            4),
                                                              ),
                                                              child: Text(
                                                                '아카이브 제목 일치',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 12,
                                                                  color: isDarkMode
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .orange,
                                                                ),
                                                              ),
                                                            )
                                                          : Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: result[
                                                                            'role'] ==
                                                                        0
                                                                    ? (isDarkMode
                                                                        ? Colors
                                                                            .blue
                                                                            .withValues(alpha:
                                                                                0.2)
                                                                        : Colors
                                                                            .blue
                                                                            .withValues(alpha:
                                                                                0.1))
                                                                    : (isDarkMode
                                                                        ? Colors
                                                                            .grey
                                                                            .withValues(alpha:
                                                                                0.2)
                                                                        : Colors
                                                                            .grey
                                                                            .withValues(alpha:0.1)),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                                // 테두리 스타일 제거
                                                              ),
                                                              margin: EdgeInsets
                                                                  .only(
                                                                left:
                                                                    result['role'] ==
                                                                            1
                                                                        ? 0
                                                                        : 24,
                                                                right:
                                                                    result['role'] ==
                                                                            0
                                                                        ? 0
                                                                        : 24,
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment: result[
                                                                            'role'] ==
                                                                        0
                                                                    ? CrossAxisAlignment
                                                                        .end
                                                                    : CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  // 역할 표시를 왼쪽 또는 오른쪽에 배치
                                                                  Container(
                                                                    padding: const EdgeInsets
                                                                        .symmetric(
                                                                        horizontal:
                                                                            4,
                                                                        vertical:
                                                                            2),
                                                                    margin: const EdgeInsets
                                                                        .only(
                                                                        bottom:
                                                                            4),
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: result['role'] ==
                                                                              0
                                                                          ? (isDarkMode
                                                                              ? Colors.blue.withValues(alpha:
                                                                                  0.3)
                                                                              : Colors.blue.withValues(alpha:
                                                                                  0.2))
                                                                          : (isDarkMode
                                                                              ? Colors.green.withValues(alpha:0.3)
                                                                              : Colors.green.withValues(alpha:0.2)),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              4),
                                                                    ),
                                                                    child: Text(
                                                                      result['role'] ==
                                                                              0
                                                                          ? '사용자'
                                                                          : 'AI',
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            10,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: result['role'] ==
                                                                                0
                                                                            ? (isDarkMode
                                                                                ? Colors.white
                                                                                : Colors.blue)
                                                                            : (isDarkMode ? Colors.white : Colors.green),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  // 왼쪽/오른쪽 표시선을 가진 컨테이너로 메시지 감싸기
                                                                  Container(
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      border:
                                                                          Border(
                                                                        left:
                                                                            BorderSide(
                                                                          color: result['role'] == 1
                                                                              ? (isDarkMode ? Colors.green : Colors.green)
                                                                              : Colors.transparent,
                                                                          width:
                                                                              3,
                                                                        ),
                                                                        right:
                                                                            BorderSide(
                                                                          color: result['role'] == 0
                                                                              ? (isDarkMode ? Colors.blue : Colors.blue)
                                                                              : Colors.transparent,
                                                                          width:
                                                                              3,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .only(
                                                                      left: 8,
                                                                      right: 8,
                                                                    ),
                                                                    child: _buildHighlightedText(
                                                                        snippet ??
                                                                            '',
                                                                        matchText,
                                                                        isDarkMode),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '닫기',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.grey[800],
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_searchController.text.isNotEmpty) {
                      _performSearch(_searchController.text, setDialogState);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDarkMode ? Colors.grey[600] : Colors.blue,
                    foregroundColor: isDarkMode ? Colors.white : Colors.white,
                  ),
                  child: const Text('검색'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 검색 실행 메서드
  void _performSearch(String searchText, StateSetter setDialogState) async {
    if (searchText.isEmpty) {
      setDialogState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setDialogState(() {
      _isSearching = true;
    });

    try {
      // 검색 텍스트로 DB 검색 실행
      final dbHelper = DatabaseHelper();
      final results = await dbHelper.searchArchiveContent(
        searchText,
        userId: ref.read(userIdProvider) ?? '',
      );

      setDialogState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      print('검색 중 오류 발생: $e');
      setDialogState(() {
        _searchResults = [];
        _isSearching = false;
      });

      // 사용자에게 오류 알림
      if (context.mounted) {
        CommonUIUtils.showErrorSnackBar(context, '검색 중 오류가 발생했습니다: $e');
      }
    }
  }

  // 하이라이트된 텍스트 위젯 생성
  Widget _buildHighlightedText(String text, String highlight, bool isDarkMode) {
    if (highlight.isEmpty || text.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontSize: 13,
        ),
      );
    }

    final matches = RegExp(highlight, caseSensitive: false).allMatches(text);
    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontSize: 13,
        ),
      );
    }

    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (final match in matches) {
      // 매치 이전 텍스트
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey,
                fontSize: 13),
          ),
        );
      }

      // 매치된 텍스트 (하이라이트)
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: TextStyle(
            color: isDarkMode ? Colors.black : Colors.black,
            backgroundColor:
                isDarkMode ? Colors.white : const Color(0xFFFFEB3B),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      );

      lastIndex = match.end;
    }

    // 마지막 매치 이후 텍스트
    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey, fontSize: 13),
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 3, // 줄 수 증가
      overflow: TextOverflow.ellipsis,
    );
  }

  // 업무 메뉴 아이템 빌더
  // ignore: unused_element
  Widget _buildWorkMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    Color iconColor,
    VoidCallback onTap,
  ) {
    final themeState = ref.watch(themeProvider);
    final isDarkMode = themeState.themeMode != AppThemeMode.light;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: isDarkMode
              ? Colors.white.withValues(alpha:0.05)
              : Colors.grey.withValues(alpha:0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isDarkMode
                  ? const Color(0xFF2D3748)
                  : const Color(0xFFF8F9FA),
              border: Border.all(
                color: isDarkMode
                    ? const Color(0xFF4A5568)
                    : const Color(0xFFE1E5E9),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha:0.1)
                        : iconColor.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: isDarkMode ? Colors.white : iconColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color:
                          isDarkMode ? Colors.white : const Color(0xFF2D3748),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color:
                      isDarkMode ? Colors.grey[400] : const Color(0xFF9CA3AF),
                  size: 12,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 전자결재관리 화면으로 네비게이션
  // ignore: unused_element
  void _navigateToSignFlow(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const ElectronicApprovalManagementScreen()),
    );
  }

  // 휴가관리 화면으로 네비게이션
  // ignore: unused_element
  void _navigateToLeaveManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LeaveManagementScreen()),
    );
  }
}
