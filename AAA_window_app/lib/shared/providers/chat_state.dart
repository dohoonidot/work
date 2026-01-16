class ChatState {
  final List<Map<String, dynamic>> arvChatHistory;
  final String selectedTopic; // archive_id
  final String currentArchiveId;
  final List<Map<String, dynamic>> arvChatDetail;
  final bool isSidebarVisible;
  final bool isDashboardVisible;
  final String archiveType;
  final bool isNewArchive;
  final bool isStreaming;
  final bool isFirstTimeCodeAssistant;
  final bool isProcessingAutoTitle;
  final String selectedModule;
  final String? searchKeyword; // 현재 검색어
  final int? highlightedChatId; // 하이라이트할 채팅 ID

  String get currentArchiveType => archiveType;

  ChatState({
    this.arvChatHistory = const [],
    this.selectedTopic = '',
    this.currentArchiveId = '',
    this.arvChatDetail = const [],
    this.isSidebarVisible = true,
    this.isDashboardVisible = true,
    this.archiveType = '',
    this.isNewArchive = false,
    this.isStreaming = false,
    this.isFirstTimeCodeAssistant = true,
    this.isProcessingAutoTitle = false,
    this.selectedModule = '', // 기본값 빈 문자열
    this.searchKeyword,
    this.highlightedChatId,
  });

  ChatState copyWith({
    List<Map<String, dynamic>>? arvChatHistory,
    String? selectedTopic,
    String? currentArchiveId,
    List<Map<String, dynamic>>? arvChatDetail,
    bool? isSidebarVisible,
    bool? isDashboardVisible,
    String? archiveType,
    bool? isNewArchive,
    bool? isStreaming,
    bool? isFirstTimeCodeAssistant,
    bool? isProcessingAutoTitle,
    String? selectedModule,
    String? searchKeyword,
    int? highlightedChatId,
    bool clearSearchKeyword = false,
    bool clearHighlightedChatId = false,
  }) {
    return ChatState(
      arvChatHistory: arvChatHistory ?? this.arvChatHistory,
      selectedTopic: selectedTopic ?? this.selectedTopic,
      currentArchiveId: currentArchiveId ?? this.currentArchiveId,
      arvChatDetail: arvChatDetail ?? this.arvChatDetail,
      isSidebarVisible: isSidebarVisible ?? this.isSidebarVisible,
      isDashboardVisible: isDashboardVisible ?? this.isDashboardVisible,
      archiveType: archiveType ?? this.archiveType,
      isNewArchive: isNewArchive ?? this.isNewArchive,
      isStreaming: isStreaming ?? this.isStreaming,
      isFirstTimeCodeAssistant:
          isFirstTimeCodeAssistant ?? this.isFirstTimeCodeAssistant,
      isProcessingAutoTitle:
          isProcessingAutoTitle ?? this.isProcessingAutoTitle,
      selectedModule: selectedModule ?? this.selectedModule,
      searchKeyword:
          clearSearchKeyword ? null : (searchKeyword ?? this.searchKeyword),
      highlightedChatId: clearHighlightedChatId
          ? null
          : (highlightedChatId ?? this.highlightedChatId),
    );
  }
}
