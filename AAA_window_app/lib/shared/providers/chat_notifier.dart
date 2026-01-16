import 'dart:async';
import 'dart:convert';
import 'dart:io'; // SocketException을 위해 추가
import 'package:ASPN_AI_AGENT/core/database/database_helper.dart';
// import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/services/api_service.dart';
import 'package:ASPN_AI_AGENT/shared/services/stream_service.dart';
import 'package:ASPN_AI_AGENT/shared/providers/chat_state.dart';
import 'package:ASPN_AI_AGENT/shared/utils/scroll_manager.dart'; // 새로 추가
import 'package:ASPN_AI_AGENT/shared/utils/message_renderer/message_renderer.dart'; // MessageRenderer import 추가
import 'package:ASPN_AI_AGENT/shared/utils/message_renderer/utils.dart'; // MessageUtils import 추가
import 'package:ASPN_AI_AGENT/shared/providers/attachment_provider.dart';
import 'package:ASPN_AI_AGENT/shared/utils/common_ui_utils.dart';
import 'package:ASPN_AI_AGENT/features/leave/leave_modal_provider.dart';
import 'package:ASPN_AI_AGENT/features/leave/vacation_data_provider.dart';
import 'package:ASPN_AI_AGENT/shared/providers/web_search_provider.dart';
import 'package:ASPN_AI_AGENT/features/approval/electronic_approval_draft_modal.dart';

// 오류 타입 정의
enum ErrorType {
  network,
  server,
  app,
  loginNetwork,
  loginServer,
  messageNetwork,
  messageServer,
  unknown,
}

// 오류 정보를 담는 클래스
class ChatError {
  final ErrorType type;
  final String message;
  final String? details;
  final DateTime timestamp;

  ChatError({
    required this.type,
    required this.message,
    this.details,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// StateNotifier에서 WidgetRef 접근을 위한 필드 추가
class ChatNotifier extends StateNotifier<ChatState> {
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();
  String accumulatedResponse = '';
  StreamSubscription<String>? _subscription;
  BuildContext? _currentContext; // 현재 컨텍스트 저장

  final String userId;
  final StateController<bool> isDeleteModeController;
  final StateController<Set<String>> selectedForDeleteController;
  final Map<String, String> _archiveTextFields = {}; // 아카이브별 텍스트필드 상태 저장
  // 스크롤 매니저 추가
  final ScrollManager scrollManager = ScrollManager();

  // 웹검색 대기 메시지 회전용 타이머 및 상태
  Timer? _webSearchLoadingTimer;
  int _webSearchLoadingIndex = 0;
  final List<String> _webSearchLoadingMessages = const [
    '웹검색 중입니다. 잠시만 기다려주세요...',
    '관련 문서를 찾는 중입니다...',
    '최신 정보를 수집하고 있어요...',
    '출처를 검증 중입니다...',
    '요약을 준비하고 있습니다...'
  ];

  final DatabaseHelper _dbHelper = DatabaseHelper(); // 데이터베이스 헬퍼 인스턴스 추가

  // ScrollController에 대한 getter 추가 (뷰에서 사용하기 위함)
  ScrollController get scrollController => scrollManager.scrollController;

  // ChatNotifier 클래스 내부에 tempSystemMessage 선언
  String? tempSystemMessage;

  ChatNotifier(
    this.userId,
    this.isDeleteModeController,
    this.selectedForDeleteController,
  ) : super(
          ChatState(
            arvChatHistory: const [],
            selectedTopic: '',
            currentArchiveId: '',
            arvChatDetail: const [],
            isSidebarVisible: true,
            isDashboardVisible: true,
            archiveType: '',
            isNewArchive: false,
            isStreaming: false,
            isFirstTimeCodeAssistant: true,
          ),
        ) {
    _initializeArchive();
  }

  // 메시지 입력 시작 시 맨 아래로 스크롤하는 메소드 (포커스 이벤트에 연결)
  void scrollOnFocus() {
    // scrollManager.scrollOnFocus();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    focusNode.dispose();
    controller.dispose();
    scrollManager.dispose(); // 스크롤 매니저 정리
    _archiveTextFields.clear(); // 아카이브별 텍스트 필드 상태 정리
    super.dispose();
  }

  /// 전자결재 상신 모달 표시
  void _showElectronicApprovalDraftModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (BuildContext dialogContext) {
        return Stack(
          children: [
            // 배경 클릭 시 닫기
            GestureDetector(
              onTap: () => Navigator.of(dialogContext).pop(),
              child: Container(
                color: Colors.transparent,
              ),
            ),
            // 모달
            Align(
              alignment: Alignment.centerRight,
              child: ElectronicApprovalDraftModal(
                onClose: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ],
        );
      },
    );
  }

  // _initializeArchive() 메서드 수정
  Future<void> _initializeArchive() async {
    print('🔍 아카이브 초기화 시작 - userId: "$userId"');

    // userId가 비어있거나 null인 경우 (로그아웃 상태)
    if (userId.isEmpty) {
      print('🔍 로그아웃 상태 감지 - 아카이브 초기화 건너뜀');
      return;
    }

    try {
      await getArchiveListAll(userId);
      print('아카이브 목록 불러오기 완료 (getArchiveListAll): ${state.arvChatHistory}');

      // 아카이브가 있는 경우에만 첫 번째 아카이브 선택
      if (state.arvChatHistory.isNotEmpty) {
        final defaultArchive = state.arvChatHistory.first;

        state = state.copyWith(
          selectedTopic: defaultArchive['archive_id'],
          currentArchiveId: defaultArchive['archive_id'],
          archiveType: defaultArchive['archive_type'],
        );

        await selectTopic(defaultArchive['archive_id']);
        print('기본 아카이브 상세 정보 불러오기 완료');
      } else {
        print('아카이브가 비어 있습니다.');
      }
    } catch (e) {
      print('❌ 아카이브 초기화 중 오류 발생: $e');
    }
  }

  Future<dynamic> createNewArchive({
    String archiveType = '',
    bool shouldUpdateUI = true,
  }) async {
    // userId가 비어있는 경우 (로그아웃 상태)
    if (userId.isEmpty) {
      print('🔍 createNewArchive: userId가 비어있음 - 로그아웃 상태로 인식');
      return '';
    }

    try {
      String newTitle;

      // 아카이브 타입에 따라 타이틀 설정
      if (archiveType == 'code') {
        newTitle = '코딩 어시스턴트';
      } else if (archiveType == 'sap') {
        newTitle = 'SAP 어시스턴트';
      } else {
        newTitle = 'new chat ${state.arvChatHistory.length - 2}';
      }

      // 1. 서버에 아카이브 생성 요청 (기존 코드)
      final response = await ApiService.createArchive(
        userId,
        newTitle,
        archiveType: archiveType,
      );
      final newArchive = response['archive'];
      final newArchiveId = newArchive['archive_id'];

      // 나머지 코드는 기존과 동일
      if (shouldUpdateUI) {
        await getArchiveListAll(userId);
        await getChatDetail(newArchiveId);
      }

      print('새 아카이브 추가: $newTitle (Type: $archiveType)');
      return newArchiveId;
    } catch (e) {
      print('아카이브 생성 및 업데이트 실패: $e');
      return '';
    }
  }

  // 아카이브 정렬 및 포맷팅을 위한 private 메서드 수정
  List<Map<String, dynamic>> _processArchives(
    List<Map<String, dynamic>> archives,
  ) {
    var sortedArchives = [];
    var regularArchives = [];
    var businessArchives = <Map<String, dynamic>>[];
    var codingArchives = <Map<String, dynamic>>[];
    var sapArchives = <Map<String, dynamic>>[];
    var advancedArchives = <Map<String, dynamic>>[];

    // 아카이브 분류 (다중 기본 아카이브 대응)
    for (var archive in archives) {
      if (archive['archive_name'].toString().toLowerCase() == '사내업무' ||
          (archive['archive_type'] == '' &&
              archive['archive_name'].toString().contains('사내'))) {
        businessArchives.add(archive);
      } else if (archive['archive_name'] == '코딩어시스턴트' ||
          archive['archive_type'] == 'code') {
        codingArchives.add(archive);
      } else if (archive['archive_name'] == 'SAP 어시스턴트' ||
          archive['archive_type'] == 'sap') {
        sapArchives.add(archive);
      } else if (archive['archive_name'] == 'AI Chatbot') {
        advancedArchives.add(archive);
      } else {
        regularArchives.add(archive);
      }
    }

    // 각 기본 아카이브 타입에서 가장 나중에 생성된 것 선택
    var latestBusinessArchive = _getLatestArchive(businessArchives, '사내업무');
    var latestCodingArchive = _getLatestArchive(codingArchives, '코딩어시스턴트');
    var latestSapArchive = _getLatestArchive(sapArchives, 'SAP 어시스턴트');
    var latestAdvancedArchive = _getLatestArchive(
      advancedArchives,
      'AI Chatbot',
    );

    // 우선순위에 따라 정렬
    if (latestBusinessArchive != null)
      sortedArchives.add(latestBusinessArchive);
    if (latestCodingArchive != null) sortedArchives.add(latestCodingArchive);
    if (latestSapArchive != null) sortedArchives.add(latestSapArchive);
    if (latestAdvancedArchive != null)
      sortedArchives.add(latestAdvancedArchive);
    sortedArchives.addAll(regularArchives);

    // UI 표시를 위한 데이터 형식으로 변환
    return sortedArchives
        .map(
          (archive) => {
            'archive_id': archive['archive_id'],
            'archive_name': archive['archive_name'] ?? '',
            'summary_name': archive['archive_name'] ?? '',
            'archive_time':
                archive['archive_time'] ?? DateTime.now().toString(),
            'archive_type': archive['archive_type'] ?? '',
          },
        )
        .toList();
  }

  // 가장 나중에 생성된 아카이브를 선택하는 헬퍼 함수 추가
  Map<String, dynamic>? _getLatestArchive(
    List<Map<String, dynamic>> archives,
    String typeName,
  ) {
    if (archives.isEmpty) return null;
    if (archives.length == 1) return archives.first;

    // archive_time 기준으로 가장 나중에 생성된 것 선택
    archives.sort((a, b) {
      final timeA = DateTime.tryParse(a['archive_time']?.toString() ?? '') ??
          DateTime(1970);
      final timeB = DateTime.tryParse(b['archive_time']?.toString() ?? '') ??
          DateTime(1970);
      return timeB.compareTo(timeA); // 내림차순 정렬 (가장 최신이 첫 번째)
    });

    final latestArchive = archives.first;
    print(
      '다중 $typeName 아카이브 중 가장 최신 선택: ${latestArchive['archive_id']} (${latestArchive['archive_time']})',
    );

    return latestArchive;
  }

  Future<void> getArchiveListAll(String userId) async {
    // userId가 비어있는 경우 (로그아웃 상태)
    if (userId.isEmpty) {
      print('🔍 getArchiveListAll: userId가 비어있음 - 로그아웃 상태로 인식');
      state = state.copyWith(arvChatHistory: []);
      return;
    }

    try {
      final dbHelper = DatabaseHelper();

      // 로컬 DB에서 아카이브 조회
      final localArchives = await dbHelper.getArchiveListFromLocalByUserId(
        userId,
      );
      print('현재 로그인한 사용자($userId)의 아카이브 조회: ${localArchives.length}개 찾음');

      if (localArchives.isEmpty) {
        print('로컬 DB에 사용자($userId)의 아카이브가 없습니다. 서버에서 가져옵니다.');

        try {
          // 서버와 동기화 수행
          final syncResult = await DatabaseHelper.syncArchivesWithDetails(
            userId,
          );
          print(
            '서버 동기화 결과: ${syncResult['success'] ? '성공' : '실패'}, 추가된 아카이브: ${syncResult['addedCount'] ?? 0}개',
          );

          // 동기화 후 다시 로컬 DB 조회
          final updatedArchives =
              await dbHelper.getArchiveListFromLocalByUserId(userId);
          print('동기화 후 로컬 아카이브 조회: ${updatedArchives.length}개 찾음');

          // 정렬 및 포맷팅된 아카이브로 상태 업데이트
          final formattedArchives = _processArchives(updatedArchives);
          state = state.copyWith(arvChatHistory: formattedArchives);

          print('서버에서 가져온 아카이브로 상태 업데이트 완료');
          return;
        } catch (e) {
          print('서버 동기화 중 오류 발생: $e');
          state = state.copyWith(arvChatHistory: []);
          return;
        }
      }

      // 로컬 DB의 아카이브 처리
      final formattedArchives = _processArchives(localArchives);
      state = state.copyWith(arvChatHistory: formattedArchives);

      print('로컬 DB에서 사용자 아카이브 리스트 불러오기 성공');
    } catch (e) {
      print('로컬 DB에서 아카이브 리스트를 불러오지 못했습니다: $e');
      state = state.copyWith(arvChatHistory: []);
    }
  }

  Future<void> getChatDetail(String archiveId) async {
    // userId가 비어있는 경우 (로그아웃 상태)
    if (userId.isEmpty) {
      print('🔍 getChatDetail: userId가 비어있음 - 로그아웃 상태로 인식');
      state = state.copyWith(arvChatDetail: []);
      return;
    }

    try {
      print(
        'getChatDetail 시작: archiveId=$archiveId, userId=$userId, 현재 검색 키워드="${state.searchKeyword}", 하이라이트ID=${state.highlightedChatId}',
      );

      final dbHelper = DatabaseHelper();
      final localChatDetail = await dbHelper.getSingleArchiveFromLocal(
        archiveId,
      );

      // 선택한 아카이브의 타입 확인
      final selectedArchive = state.arvChatHistory.firstWhere(
        (archive) => archive['archive_id'] == archiveId,
        orElse: () => {'archive_type': ''},
      );
      final isCodeArchive = selectedArchive['archive_type'] == 'code';
      final isSapArchive = selectedArchive['archive_type'] == 'sap';
      final isAdvancedArchive = selectedArchive['archive_name'] == 'AI Chatbot';

      // 채팅 내역이 비어있는 경우 초기 메시지 설정 (DB에 저장하지 않음)
      List<Map<String, dynamic>> formattedChatDetail;

      if (localChatDetail.isEmpty) {
        // 각 아카이브 타입에 따른 초기 메시지 생성
        String initialMessage;
        if (isCodeArchive) {
          initialMessage = '**코딩 어시스턴트**에 오신 것을 환영합니다! 🚀\n\n'
              '저는 프로그래밍과 코딩 관련 질문에 답변해드리는 AI 어시스턴트입니다.\n\n'
              '**제가 도와드릴 수 있는 것들:**\n'
              '• 코드 작성 및 디버깅\n'
              '• 알고리즘 설명 및 최적화\n'
              '• 프로그래밍 언어 문법 질문\n'
              '• 코드 리뷰 및 개선 제안\n'
              '• 개발 환경 설정 도움\n\n'
              '어떤 코딩 관련 질문이 있으신가요?';
        } else if (isSapArchive) {
          initialMessage = '**SAP 어시스턴트**에 오신 것을 환영합니다! 💼\n\n'
              '저는 SAP 시스템과 관련된 질문에 답변해드리는 AI 어시스턴트입니다.\n\n'
              '**제가 도와드릴 수 있는 것들:**\n'
              '• SAP 모듈별 기능 설명\n'
              '• SAP 시스템 문제 해결\n'
              '• SAP 설정 및 구성 도움\n'
              '• SAP 업무 프로세스 설명\n'
              '• SAP 관련 모범 사례 안내\n\n'
              '어떤 SAP 관련 질문이 있으신가요?';
        } else if (isAdvancedArchive) {
          initialMessage = '**AI Chatbot**에 오신 것을 환영합니다! 🤖\n\n'
              '**현재 유료 버전인 AI 모델들을 무료로 사용하실 수 있습니다!**\n\n'
              '✅ **Gemini Pro 3**\n'
              '🚀 구글의 최신 대형 언어 모델!\n'
              '강력한 추론 능력과 창의성을 겸비한\n'
              '다양한 작업에 최적화된 올인원 AI입니다.\n'
              '복잡한 분석과 창의적 작업에 탁월합니다.\n\n'
              '🔍 **GPT-5.2**\n'
              '🧠 현재 공개된 **가장 최신이자 강력한 AI 모델!**\n'
              '깊이 있는 추론 능력과 폭넓은 지식을 갖추어\n'
              '전문적인 문제 해결과 고급 분석에 최적입니다.\n'
              '다소 시간이 걸릴 수 있습니다.\n\n'
              '💻 **Claude-Sonnet-4.5**\n'
              '🛠️ 코딩과 개발에 특화된 전문가 모델!\n'
              '코드 작성, 디버깅, 최적화에 탁월하며\n'
              '기술 문서 작성과 시스템 설계에도 강합니다.\n\n'
              '무엇을 도와드릴까요?';
        } else {
          initialMessage =
              '안녕하세요. 저는 **ASPN AI Agent**입니다.🤖 \n\n 저희는 아래와 같은 서비스를 통해 전문적인 도움을 드리고 있습니다!\n\n'
              '**CSR 서비스**\n\n➜ 사용자의 권한을 확인하여 현재 진행 상황 및 담당자를 조회할 수 있습니다.\n\n'
              '➜ 접수된 CSR 요청서에 대해 해결 방안과 과거 유사 이력을 확인할 수 있습니다.\n\n '
              '**ASPN 서비스** \n\n➜ 회사 규정 관련 문의에 대해 정보를 제공합니다. \n\n'
              '➜ 조직도와 임직원 연락처, 메일 주소 등의 정보를 제공합니다. \n\n '
              '무엇을 도와드릴까요?';
        }

        // 초기 메시지를 동적으로 생성 (DB에 저장하지 않음)
        formattedChatDetail = [
          {
            'archive_id': archiveId,
            'user_id': userId,
            'message': initialMessage,
            'role': 1,
            'chat_time': DateTime.now().toString(),
          },
        ];
      } else {
        // 기존 채팅 내역이 있는 경우 그대로 사용
        formattedChatDetail = localChatDetail
            .map(
              (chat) => {
                'archive_id': archiveId,
                'user_id': userId,
                'message': chat['message'] ?? '',
                'role': chat['role'] ?? 1,
                'chat_time': DateTime.now().toString(),
                'chat_id': chat['chat_id'], // chat_id 필드 추가
              },
            )
            .toList();
      }

      // 중요: 검색 키워드와 하이라이트 ID를 유지하도록 수정
      // 로그 추가로 상태 변경 추적
      print(
        '상태 업데이트 전: 검색 키워드="${state.searchKeyword}", 하이라이트ID=${state.highlightedChatId}',
      );

      state = state.copyWith(
        currentArchiveId: archiveId,
        archiveType: selectedArchive['archive_type'],
        arvChatDetail: formattedChatDetail,
        // 검색 관련 정보 명시적으로 유지
        searchKeyword: state.searchKeyword,
        highlightedChatId: state.highlightedChatId,
      );

      print(
        '상태 업데이트 후: 검색 키워드="${state.searchKeyword}", 하이라이트ID=${state.highlightedChatId}',
      );
      print('로드된 채팅 개수: ${formattedChatDetail.length}');
      if (state.highlightedChatId != null) {
        print('하이라이트할 채팅 ID 확인: ${state.highlightedChatId}');
        // 하이라이트할 채팅 ID가 실제 로드된 채팅에 있는지 확인
        bool chatExists = formattedChatDetail.any(
          (chat) => chat['chat_id'] == state.highlightedChatId,
        );
        print('하이라이트할 채팅 ID가 로드된 채팅에 존재함: $chatExists');
      }

      print('로컬 DB에서 아카이브 상세 정보 불러오기 성공');
      scrollManager.scrollToBottom();
    } catch (e) {
      print('로컬 DB에서 아카이브 상세 정보를 불러오지 못했습니다: $e');
      state = state.copyWith(arvChatDetail: []);
    }
  }

  void toggleSidebarVisibility() {
    state = state.copyWith(isSidebarVisible: !state.isSidebarVisible);
    print('Sidebar Visibility: ${state.isSidebarVisible}');
  }

  void toggleDashboardVisibility() {
    state = state.copyWith(isDashboardVisible: !state.isDashboardVisible);
    print('Dashboard Visibility: ${state.isDashboardVisible}');
  }

  // deleteArchive 메서드 수정
  Future<void> deleteArchive(
    BuildContext context,
    String archiveId, {
    bool notifyUI = true,
  }) async {
    try {
      // 1. 서버 DB에서 먼저 삭제
      await ApiService.deleteArchive(archiveId);

      // 2. 서버 성공 후 로컬 DB에서 삭제
      await _dbHelper.deleteArchive(archiveId);

      if (notifyUI) {
        // 로컬 DB에서 최신 아카이브 목록 가져오기 (변경)
        await getArchiveListAll(userId);

        // 삭제된 아카이브가 현재 선택된 아카이브였다면
        if (archiveId == state.selectedTopic &&
            state.arvChatHistory.isNotEmpty) {
          final topArchive = state.arvChatHistory.first;
          await selectTopic(topArchive['archive_id']);
          print('최상단 아카이브로 선택 변경: ${topArchive['archive_id']}');
        }

        if (context.mounted) {
          CommonUIUtils.showInfoSnackBar(context, '대화가 삭제되었습니다.');
        }
      }
    } catch (e) {
      print('아카이브 삭제 실패 (ID: $archiveId): $e');
      if (context.mounted && notifyUI) {
        CommonUIUtils.showErrorSnackBar(context, '삭제 중 오류가 발생했습니다.');
      }
    }
  }

  // deleteSelectedArchives 메서드 수정
  Future<void> deleteSelectedArchives(
    BuildContext context,
    Set<String> archiveIds,
  ) async {
    try {
      // 아카이브 삭제 전 상태 기록
      final totalArchiveCount = state.arvChatHistory.length;
      final selectedCount = archiveIds.length;
      final deleteAll = totalArchiveCount == selectedCount;

      print(
        '삭제 시작: 전체 ${totalArchiveCount}개 중 ${selectedCount}개 삭제 예정 (전체 삭제: $deleteAll)',
      );

      // 전체 삭제인 경우의 처리
      if (deleteAll) {
        print('전체 삭제 감지! 모든 아카이브 삭제 준비');

        // 1. 삭제 전에 모드 초기화
        isDeleteModeController.state = false;
        selectedForDeleteController.state = {};

        // 2. 먼저 상태 초기화
        state = state.copyWith(
          arvChatHistory: [],
          selectedTopic: '',
          currentArchiveId: '',
          arvChatDetail: [],
        );

        // 3. 프로세스 시작 전 스낵바 표시
        if (context.mounted) {
          CommonUIUtils.showInfoSnackBar(
            context,
            '모든 대화가 삭제되었습니다. 새 대화를 시작하세요.',
          );
        }

        // 5. 백그라운드에서 실제 삭제 작업 진행
        for (final archiveId in archiveIds) {
          try {
            // 1. 서버 DB에서 먼저 삭제
            await ApiService.deleteArchive(archiveId);

            // 2. 서버 성공 후 로컬 DB에서 삭제
            await _dbHelper.deleteArchive(archiveId);

            print('아카이브 삭제 완료: $archiveId');
          } catch (e) {
            print('아카이브 삭제 오류 (무시하고 계속): $archiveId - $e');
          }
        }

        return;
      }

      // 일부만 삭제하는 경우
      for (final archiveId in archiveIds) {
        // 1. 서버 DB에서 먼저 삭제
        await ApiService.deleteArchive(archiveId);

        // 2. 서버 성공 후 로컬 DB에서 삭제
        await _dbHelper.deleteArchive(archiveId);

        print('아카이브 삭제 완료: $archiveId');
      }

      // 선택 모드 초기화
      isDeleteModeController.state = false;
      selectedForDeleteController.state = {};

      // 남은 아카이브 목록 갱신
      try {
        await getArchiveListAll(userId);

        // 기존 선택된 아카이브가 삭제된 경우 다른 아카이브 선택
        if ((archiveIds.contains(state.selectedTopic) ||
                state.selectedTopic.isEmpty) &&
            state.arvChatHistory.isNotEmpty) {
          final topArchive = state.arvChatHistory.first;
          await selectTopic(topArchive['archive_id']);
          print('최상단 아카이브로 선택 변경: ${topArchive['archive_id']}');
        }

        if (context.mounted) {
          CommonUIUtils.showInfoSnackBar(context, '선택한 대화가 삭제되었습니다.');
        }
      } catch (e) {
        print('아카이브 목록을 불러오지 못했습니다: $e');

        if (e.toString().contains('204')) {
          print('204 응답: 아카이브가 없습니다. 메인홈페이지로 이동합니다.');

          // 상태 초기화
          state = state.copyWith(
            arvChatHistory: [],
            selectedTopic: '',
            currentArchiveId: '',
            arvChatDetail: [],
          );

          if (context.mounted) {
            CommonUIUtils.showInfoSnackBar(
              context,
              '모든 대화가 삭제되었습니다. 새 대화를 시작하세요.',
            );
          }
        }
      }
    } catch (e) {
      print('선택된 아카이브 삭제 실패: $e');
      if (context.mounted) {
        CommonUIUtils.showErrorSnackBar(context, '삭제 중 오류가 발생했습니다.');
      }
    }
  }

  // editArchiveTitle 메서드 수정
  Future<void> editArchiveTitle(
    String archiveId,
    String newTitle, {
    bool updateUI = true,
  }) async {
    print('📌 아카이브 ID: $archiveId');
    print('📌 새 제목: "$newTitle"');

    // 기본 아카이브 이름 제한 로직 제거 - 시스템에서 기본 아카이브 생성시 허용
    // final restrictedNames = ['사내업무', 'AI Chatbot', '코딩어시스턴트', 'SAP 어시스턴트'];
    // if (restrictedNames.contains(newTitle)) {
    //   print('❌ 제한된 이름으로 변경 시도: "$newTitle" - 작업을 중단합니다.');
    //   return;
    // }

    try {
      // 1. 서버 API 호출 (기존 코드)
      print('API 호출 시작: updateArchive');
      await ApiService.updateArchive(userId, archiveId, newTitle);
      print('✅ API 호출 성공: updateArchive');

      if (updateUI) {
        // 현재 제목 찾기 (로그용)
        final currentTitle = state.arvChatHistory.firstWhere(
          (a) => a['archive_id'] == archiveId,
          orElse: () => {'archive_name': '알 수 없음'},
        )['archive_name'];
        print('🔄 제목 변경: "$currentTitle" → "$newTitle"');

        // UI 상태 업데이트
        state = state.copyWith(
          arvChatHistory: state.arvChatHistory.map((archive) {
            if (archive['archive_id'] == archiveId) {
              print('✓ 아카이브 목록에서 제목 업데이트 완료');
              return {...archive, 'archive_name': newTitle};
            }
            return archive;
          }).toList(),
        );

        // 선택된 토픽이면 해당 정보도 업데이트
        if (state.selectedTopic == archiveId) {
          print('✓ 선택된 토픽 제목도 함께 업데이트 완료');
        }
      }

      print('✅ 아카이브 제목 업데이트 완료: $archiveId -> $newTitle');
    } catch (e) {
      print('❌ 아카이브 제목 업데이트 실패: $e');
    }
  }

  Future<void> resetArchive(
    BuildContext context,
    String archiveId,
    String archiveType,
    String archiveName,
  ) async {
    try {
      // 1. 기존 아카이브 정보 저장
      final existingArchiveIndex = state.arvChatHistory.indexWhere(
        (archive) => archive['archive_id'] == archiveId,
      );

      if (existingArchiveIndex == -1) {
        print('기존 아카이브를 찾을 수 없습니다.');
        return;
      }

      final existingArchive = Map<String, dynamic>.from(
        state.arvChatHistory[existingArchiveIndex],
      );

      // 2. 백엔드에서 아카이브 삭제 (UI 업데이트 없이)
      await deleteArchive(context, archiveId, notifyUI: false);

      // 3. 동일한 타입의 새 아카이브 생성 (UI 업데이트 없이)
      final newArchiveId = await createNewArchive(
        archiveType: archiveType,
        shouldUpdateUI: false,
      );

      // 4. UI 상태 업데이트
      List<Map<String, dynamic>> updatedHistory = List.from(
        state.arvChatHistory,
      );

      // 기존 아카이브 정보에 새 ID 반영
      updatedHistory[existingArchiveIndex] = {
        ...existingArchive,
        'archive_id': newArchiveId,
      };

      // 5. 상태 업데이트
      state = state.copyWith(
        arvChatHistory: updatedHistory,
        selectedTopic: newArchiveId,
        currentArchiveId: newArchiveId,
      );

      // 6. 기본 아카이브인 경우 제목 변경 (백엔드만 업데이트)
      if (archiveType == '' && archiveName == '사내업무') {
        await editArchiveTitle(newArchiveId, '사내업무', updateUI: false);
      } else if (archiveType == '' && archiveName == 'AI Chatbot') {
        await editArchiveTitle(newArchiveId, 'AI Chatbot', updateUI: false);
      }

      // 7. 새 아카이브 선택
      await selectTopic(newArchiveId);

      print('아카이브 초기화 완료: $archiveId -> $newArchiveId');
    } catch (e) {
      print('아카이브 초기화 실패: $e');
      if (context.mounted) {
        CommonUIUtils.showErrorSnackBar(context, '대화 내용 초기화 중 오류가 발생했습니다.');
      }
    }
  }

  // 모듈 선택 메서드 추가
  void setSelectedModule(String module) {
    print('채팅 노티파이어에 SAP 모듈 설정: $module');
    state = state.copyWith(selectedModule: module);
  }

  void sendMessageToAIServer(
    String userId,
    BuildContext context, {
    String? selectedModel,
  }) async {
    _currentContext = context; // 컨텍스트 저장
    state = state.copyWith(isStreaming: true);

    // 스트리밍 시작 - ChatGPT 스타일 자동 스크롤 활성화
    scrollManager.startStreaming();
    String message = controller.text.trim();

    // "전자결재상신" 키워드 감지
    if (message == '전자결재상신') {
      print('🔔 전자결재상신 키워드 감지!');

      // 입력 필드 초기화
      controller.clear();

      // 스트리밍 종료
      state = state.copyWith(isStreaming: false);
      scrollManager.stopStreaming();

      // 전자결재 상신 모달 표시
      _showElectronicApprovalDraftModal(context);

      return; // 메시지 전송 중단
    }

    if (state.selectedTopic.isNotEmpty && message.isNotEmpty) {
      // isNewArchive 상태를 false로 변경
      state = state.copyWith(isNewArchive: false);

      // 아카이브 타입 및 이름 확인
      bool isCodeArchive = false;
      bool isSapArchive = false;
      bool isAiChatbot = false;
      String archiveName = '';

      for (var archive in state.arvChatHistory) {
        if (archive['archive_id'] == state.currentArchiveId) {
          isCodeArchive = archive['archive_type'] == 'code';
          isSapArchive = archive['archive_type'] == 'sap';
          archiveName = archive['archive_name'] ?? '';
          isAiChatbot = archiveName == 'AI Chatbot';
          break;
        }
      }

      // 카테고리 설정
      String category = '';
      String module = '';
      if (isCodeArchive) {
        category = 'code';
      } else if (isSapArchive) {
        category = 'sap';
        // SAP 아카이브인 경우 state에서 직접 선택된 모듈 값 가져오기
        if (state.selectedModule.isNotEmpty) {
          module = state.selectedModule.toLowerCase();
          print('선택된 SAP 모듈: $module (API 요청용 소문자 변환)');
        }
      }

      print('Category for this message: $category');
      print('Archive name: $archiveName');
      print('Selected model: $selectedModel');
      print('Module for this message: $module');

      // 파일 첨부 확인
      final attachments = _currentContext != null
          ? ProviderScope.containerOf(
              _currentContext!,
            ).read(attachmentProvider).files
          : [];

      // PDF 파일이 첨부되었는지 확인
      bool hasPdfFiles = attachments.any(
        (file) => file.extension?.toLowerCase() == 'pdf',
      );

      // 이미지 파일이 첨부되었는지 확인
      bool hasImageFiles = attachments.any((file) {
        final extension = file.extension?.toLowerCase();
        return extension != null &&
            ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
      });

      // PDF 또는 이미지 파일이 있는지 확인

      // 대기 메시지 생성 (모든 질문에 대해 기본 대기 메시지 표시)
      String waitingMessage = '답변을 생성중입니다. 잠시만 기다려주세요...';
      if (hasPdfFiles && hasImageFiles) {
        waitingMessage = 'PDF 및 이미지 파일의 경우 답변 대기 시간이 있습니다. 잠시만 기다려 주세요.';
      } else if (hasPdfFiles) {
        waitingMessage = 'PDF 파일의 경우 답변 대기 시간이 있습니다. 잠시만 기다려 주세요.';
      } else if (hasImageFiles) {
        waitingMessage = '이미지 파일의 경우 답변 대기 시간이 있습니다. 잠시만 기다려 주세요.';
      }

      List<Map<String, dynamic>> updatedChatDetail = [
        ...state.arvChatDetail,
        {
          'category': category,
          'module': '',
          'archive_id': state.currentArchiveId,
          'user_id': userId,
          'message': message,
          'role': 0,
          'chat_time': DateTime.now().toString(),
          'attachments': attachments
              .map(
                (file) => {
                  'name': file.name,
                  'size': file.size,
                  'mimeType': file.mimeType,
                  'bytes': file.bytes,
                },
              )
              .toList(), // 첨부 파일 정보 추가
        },
        // AI의 응답 메시지를 빈 상태로 추가
        {
          'archive_id': state.currentArchiveId,
          'user_id': userId,
          'message': waitingMessage,
          'role': 1,
          'chat_time': DateTime.now().toString(),
          'isStreaming': false, // 스트리밍 상태 초기화
          'isLoading': true, // 모든 질문에 대해 로딩 상태로 설정
          'thoughtPart': '', // 생각 과정 부분
          'responsePart': '', // 최종 응답 부분
          'hasThoughtCompleted': false, // 생각 과정 완료 여부
        },
      ];

      // 시스템 메시지 설정 로그
      if (tempSystemMessage != null) {
        print('AI 메시지 생성 시 systemMessage 설정: $tempSystemMessage');
      } else {
        print('AI 메시지 생성 시 systemMessage 없음');
      }

      state = state.copyWith(arvChatDetail: updatedChatDetail);

      // 웹검색 토글이 켜져있다면 대기 메시지를 주기적으로 교체
      bool webSearchOn = false;
      if (_currentContext != null) {
        try {
          webSearchOn = ProviderScope.containerOf(_currentContext!)
              .read(selectedWebSearchProvider);
        } catch (_) {}
      }
      if (webSearchOn) {
        print('🌐 웹검색 대기 메시지 회전 시작');
        _webSearchLoadingTimer?.cancel();
        _webSearchLoadingIndex = 0;
        _webSearchLoadingTimer =
            Timer.periodic(const Duration(seconds: 2), (_) {
          if (state.arvChatDetail.isEmpty) return;
          // 마지막 AI 메시지만 갱신
          if (state.arvChatDetail.last['role'] == 1 &&
              state.arvChatDetail.last['isLoading'] == true) {
            final nextText = _webSearchLoadingMessages[
                _webSearchLoadingIndex % _webSearchLoadingMessages.length];
            _webSearchLoadingIndex++;
            final updated =
                List<Map<String, dynamic>>.from(state.arvChatDetail);
            final last = Map<String, dynamic>.from(updated.last);
            last['message'] = nextText;
            updated[updated.length - 1] = last;
            state = state.copyWith(arvChatDetail: updated);
            print('🌐 대기 메시지 교체: ' + nextText);
          }
        });
      } else {
        print('🌐 웹검색 대기 메시지 회전 미시작: 토글 OFF');
      }

      // tempSystemMessage 사용 후 초기화
      tempSystemMessage = null;

      // 사용자 메시지 전송 시 맨 아래로 스크롤하여 대화 흐름 확보
      scrollManager.onUserMessageSent();

      // 이전 버전에서는 사용자 메시지를 chat_notifier에서 저장하지 않음
      // StreamService에서 chat_id 헤더와 함께 저장함

      // 메시지 전송 시 DB 정보 출력 (디버깅용)
      try {
        print('\n💬 메시지 전송 시작 - 데이터베이스 정보 확인');
        await DatabaseHelper().printDatabaseInfo();
      } catch (e) {
        print('🚨 메시지 전송 시 DB 정보 출력 실패: $e');
      }

      // 자동 타이틀 업데이트 로직 (기존 코드)
      final isUserFirstMessage =
          state.arvChatDetail.where((msg) => msg['role'] == 0).length == 1;
      if (isUserFirstMessage && !isDefaultArchive(state.currentArchiveId)) {
        updateTitleUsingNoStream(userId, state.currentArchiveId, message);
      }

      // 스크롤 및 텍스트필드 관련 처리 (기존 코드)
      Future.delayed(const Duration(milliseconds: 100), () {
        // 사용자가 아래쪽에 있을 때만 자동 스크롤
        if (scrollManager.isUserNearBottom()) {
          scrollManager.handleNewMessage();
        }
      });

      controller.clear();

      Future.delayed(const Duration(milliseconds: 100), () {
        focusNode.requestFocus();
      });

      if (state.currentArchiveId.isNotEmpty) {
        _archiveTextFields.remove(state.currentArchiveId);
      }

      try {
        Stream<String> stream;

        // AI 모델 선택 기능이 있는 아카이브인지 확인
        bool useModelSelector = isCodeArchive || isSapArchive || isAiChatbot;
        print('\n=== AI 모델 선택 기능 확인 ===');
        print('isCodeArchive: $isCodeArchive');
        print('isSapArchive: $isSapArchive');
        print('isAiChatbot: $isAiChatbot');
        print('useModelSelector: $useModelSelector');
        print('📋 selectedModel from parameter: $selectedModel');
        print('📋 selectedModel is null?: ${selectedModel == null}');

        // 모델 파라미터 변환 (UI에서 받은 값을 API에 맞게 변환)
        String apiModel = '';
        if (useModelSelector) {
          // streamChat/withModel API 사용 아카이브에서는 모델이 선택되지 않았을 때 기본값으로 gemini-pro-3 사용
          String modelToUse = selectedModel ?? 'gemini-pro-3';
          print('🔄 모델 변환 시작: 입력값="$selectedModel", 사용할 값="$modelToUse"');

          if (modelToUse == 'gpt-5.2') {
            apiModel = 'Gpt-5.2';
            print('✅ GPT 모델 선택: $modelToUse -> $apiModel');
          } else if (modelToUse == 'gemini-pro-3') {
            apiModel = 'Gemini-Pro-3';
            print('✅ Gemini 모델 선택: $modelToUse -> $apiModel');
          } else if (modelToUse == 'claude-sonnet-4.5') {
            apiModel = 'Claude-Sonnet-4.5';
            print('✅ Claude 모델 선택: $modelToUse -> $apiModel');
          } else {
            // 알 수 없는 모델인 경우 기본값으로 gemini-pro-3 사용
            apiModel = 'Gemini-Pro-3';
            print('⚠️ 알 수 없는 모델 값, 기본값으로 gemini-pro-3 사용: $modelToUse');
          }
          print('🎯 최종 API 모델: $apiModel');
        } else {
          print('❌ 모델 선택 조건 실패: useModelSelector=$useModelSelector');
        }

        if (attachments.isNotEmpty) {
          try {
            print('\n=== 파일 첨부 메시지 전송 시작 ===');
            print('사용자 ID: $userId');
            print('메시지: $message');
            print('첨부 파일 수: ${attachments.length}개');

            // 각 파일의 상세 정보 출력 및 크기 제한 확인
            for (var i = 0; i < attachments.length; i++) {
              final file = attachments[i];
              print('\n파일 #${i + 1} 상세 정보:');
              print('- 파일명: ${file.name}');
              print('- 크기: ${(file.size / 1024).toStringAsFixed(2)} KB');
              print('- 확장자: ${file.extension}');

              // // 개별 파일 크기 제한 (20MB) - 사내업무 제한 해제
              // if (file.size > 20 * 1024 * 1024) {
              //   throw Exception(
              //     '파일 크기가 너무 큽니다: ${file.name} (${(file.size / 1024 / 1024).toStringAsFixed(2)}MB)',
              //   );
              // }
            }

            // 전체 파일 크기 제한 없음

            // 모델 선택 기능이 있는 아카이브는 새로운 API 사용
            if (useModelSelector) {
              // withModel API: PDF 허용 (검증 제거)
              print('\n=== streamChat/withModel API 호출 시작 (파일 첨부) ===');
              print('새로운 API 사용 중! (코딩/SAP/AI Chatbot 아카이브)');
              print(
                'API 파라미터: category=$category, module=$module, model=$apiModel',
              );
              // 웹검색 토글 상태 반영 (search_yn)
              final webSearchOn = ProviderScope.containerOf(_currentContext!)
                  .read(selectedWebSearchProvider);
              final searchYn = webSearchOn ? 'y' : 'n';
              print('🌐 withModel 전송(파일첨부) - search_yn: ' + searchYn);

              stream = StreamService.getWithModelStream(
                category,
                module,
                apiModel,
                state.currentArchiveId,
                userId,
                message,
                attachments
                    .map((file) => CustomPlatformFile.fromPlatformFile(file))
                    .toList(),
                searchYn: searchYn,
              );
            } else {
              print('\n=== streamChat/timeout API 호출 시작 (파일첨부) ===');
              print('통합 API 사용 중! (사내업무 아카이브 + 파일첨부)');
              print('통합 API 사용 이유: useModelSelector=$useModelSelector');
              // 통합 API 사용 (streamChat/timeout with files)
              stream = StreamService.getEventStream(
                category,
                module,
                state.currentArchiveId,
                userId,
                message,
                files: attachments
                    .map((file) => CustomPlatformFile.fromPlatformFile(file))
                    .toList(),
              );
            }

            // 파일 목록 초기화
            if (_currentContext != null) {
              print('\n파일 목록 초기화');
              ProviderScope.containerOf(
                _currentContext!,
              ).read(attachmentProvider.notifier).clearFiles();
            }
          } catch (e, stackTrace) {
            print('\n=== 파일 업로드 중 오류 발생 ===');
            print('오류 타입: ${e.runtimeType}');
            print('오류 내용: $e');
            print('스택 트레이스: $stackTrace');
            print('현재 아카이브: $archiveName (타입: $category)');
            print('첨부 파일 수: ${attachments.length}');
            for (var i = 0; i < attachments.length; i++) {
              print(
                '  파일 ${i + 1}: ${attachments[i].name} (${attachments[i].size} bytes)',
              );
            }
            _handleDynamicError(e);
            state = state.copyWith(isStreaming: false);
            // 오류 발생 시에도 스트리밍 종료
            scrollManager.stopStreaming();
            return;
          }
        } else {
          print('\n=== 일반 채팅 스트림 시작 (파일 첨부 없음) ===');
          // 모델 선택 기능이 있는 아카이브는 새로운 API 사용
          if (useModelSelector) {
            print('\n=== streamChat/withModel API 호출 시작 (파일 없음) ===');
            print('새로운 API 사용 중! (코딩/SAP/AI Chatbot 아카이브)');
            print(
              'API 파라미터: category=$category, module=$module, model=$apiModel',
            );
            // 웹검색 토글 상태 반영 (search_yn)
            final webSearchOn = _currentContext != null
                ? ProviderScope.containerOf(_currentContext!)
                    .read(selectedWebSearchProvider)
                : false;
            final searchYn = webSearchOn ? 'y' : 'n';
            print('🌐 withModel 전송(파일없음) - search_yn: ' + searchYn);

            stream = StreamService.getWithModelStream(
              category,
              module,
              apiModel,
              state.currentArchiveId,
              userId,
              message,
              [], // 빈 파일 리스트
              searchYn: searchYn,
            );
          } else {
            print('\n=== streamChat/timeout API 호출 시작 (기존) ===');
            print('통합 API 사용 중! (사내업무/일반 아카이브 + 파일없음)');
            print('통합 API 사용 이유: useModelSelector=$useModelSelector');
            // 통합 API 사용 (files 없음)
            stream = StreamService.getEventStream(
              category,
              module,
              state.currentArchiveId,
              userId,
              message,
              files: [], // 빈 파일 리스트
            );
          }
        }

        // 스트림 처리
        await _subscription?.cancel();
        accumulatedResponse = '';
        int chunkCount = 0; // 청크 카운터 추가

        _subscription = stream.listen(
          (event) {
            // 웹검색 대기 타이머는 실제 스트림 데이터가 도착하면 중지 (상태 메시지 제외)
            if (!event.startsWith('{"status":"generating_response"')) {
              _webSearchLoadingTimer?.cancel();
              _webSearchLoadingTimer = null;
            }
            chunkCount++; // 청크 번호 증가

            // 개행 문자 처리 상태 확인
            if (event.contains('\\n')) {}

            // 휴가상신초안 모달 트리거 메시지 처리
            if (event.startsWith('{"type":"trigger_leave_modal"')) {
              try {
                print('🔍 ChatNotifier: 트리거 이벤트 감지');
                print('🔍 ChatNotifier: 이벤트 원본: $event');

                final Map<String, dynamic> triggerData = jsonDecode(event);
                print('🔍 ChatNotifier: 파싱된 트리거 데이터: $triggerData');
                print(
                    '🔍 ChatNotifier: 트리거 데이터 키: ${triggerData.keys.toList()}');

                if (triggerData.containsKey('type') &&
                    triggerData['type'] == 'trigger_leave_modal' &&
                    triggerData.containsKey('data')) {
                  final leaveFormData = triggerData['data'];
                  print('🎯 ChatNotifier: 휴가상신초안 모달 트리거 감지 시작');
                  print(
                      '🎯 ChatNotifier: leave_form 데이터 타입: ${leaveFormData.runtimeType}');
                  print('🎯 ChatNotifier: leave_form 데이터: $leaveFormData');

                  // WidgetRef 접근을 위해 provider를 통해 처리
                  _handleLeaveModalTrigger(leaveFormData);
                  return; // 이 이벤트는 일반 메시지 처리에서 제외
                } else {
                  print('⚠️ ChatNotifier: 트리거 데이터에 필요한 키가 없습니다');
                  print(
                      '⚠️ ChatNotifier: type=${triggerData['type']}, data 존재=${triggerData.containsKey('data')}');
                }
              } catch (e, stackTrace) {
                print('❌ ChatNotifier: 휴가상신초안 모달 트리거 JSON 파싱 오류');
                print('❌ ChatNotifier: 오류 타입: ${e.runtimeType}');
                print('❌ ChatNotifier: 오류 메시지: $e');
                print('❌ ChatNotifier: 스택 트레이스: $stackTrace');
                print('❌ ChatNotifier: 원본 이벤트: $event');
              }
            }

            // 휴가 부여 상신 전자결재 모달 트리거 메시지 처리
            // StreamService에서 category=hr_leave_grant일 때만 JSON을 보내므로
            // JSON 형식이면 바로 휴가 부여 상신으로 처리
            if (event.startsWith('{') &&
                event.contains('"approval_type":"hr_leave_grant"')) {
              try {
                print(
                    '🏢 ChatNotifier: 휴가 부여 상신 JSON 감지 (category=hr_leave_grant)');
                print('🏢 ChatNotifier: 이벤트 원본: $event');

                final Map<String, dynamic> leaveGrantData = jsonDecode(event);
                print(
                    '🏢 ChatNotifier: 파싱된 휴가 부여 상신 데이터 키: ${leaveGrantData.keys.toList()}');
                print('🎯 ChatNotifier: 휴가 부여 상신 전자결재 모달 트리거 시작');

                // 전자결재 모달 트리거 처리
                _handleElectronicApprovalModalTrigger(leaveGrantData);
                return; // 이 이벤트는 일반 메시지 처리에서 제외
              } catch (e, stackTrace) {
                print('❌ ChatNotifier: 휴가 부여 상신 JSON 파싱 오류');
                print('❌ ChatNotifier: 오류 타입: ${e.runtimeType}');
                print('❌ ChatNotifier: 오류 메시지: $e');
                print('❌ ChatNotifier: 스택 트레이스: $stackTrace');
                print('❌ ChatNotifier: 원본 이벤트: $event');
              }
            }

            // 기본양식 전자결재 모달 트리거 메시지 처리
            if (event.startsWith('{') &&
                event.contains('"approval_type":"기본양식"')) {
              try {
                print('🏢 ChatNotifier: 기본양식 JSON 감지');
                print('🏢 ChatNotifier: 이벤트 원본: $event');

                final Map<String, dynamic> basicApprovalData =
                    jsonDecode(event);
                print(
                    '🏢 ChatNotifier: 파싱된 기본양식 데이터 키: ${basicApprovalData.keys.toList()}');
                print('🎯 ChatNotifier: 기본양식 전자결재 모달 트리거 시작');

                // 전자결재 모달 트리거 처리
                _handleBasicApprovalModalTrigger(basicApprovalData);
                return; // 이 이벤트는 일반 메시지 처리에서 제외
              } catch (e, stackTrace) {
                print('❌ ChatNotifier: 기본양식 JSON 파싱 오류');
                print('❌ ChatNotifier: 오류 타입: ${e.runtimeType}');
                print('❌ ChatNotifier: 오류 메시지: $e');
                print('❌ ChatNotifier: 스택 트레이스: $stackTrace');
                print('❌ ChatNotifier: 원본 이벤트: $event');
              }
            }

            // 매출/매입 계약 기안서 전자결재 모달 트리거 메시지 처리
            if (event.startsWith('{') &&
                event.contains('"approval_type":"매출/매입 계약 기안서"')) {
              try {
                print('🏢 ChatNotifier: 매출/매입 계약 기안서 JSON 감지');
                print('🏢 ChatNotifier: 이벤트 원본: $event');

                final Map<String, dynamic> contractApprovalData =
                    jsonDecode(event);
                print(
                    '🏢 ChatNotifier: 파싱된 매출/매입 계약 기안서 데이터 키: ${contractApprovalData.keys.toList()}');
                print('🎯 ChatNotifier: 매출/매입 계약 기안서 전자결재 모달 트리거 시작');

                // 전자결재 모달 트리거 처리
                _handleContractApprovalModalTrigger(contractApprovalData);
                return; // 이 이벤트는 일반 메시지 처리에서 제외
              } catch (e, stackTrace) {
                print('❌ ChatNotifier: 매출/매입 계약 기안서 JSON 파싱 오류');
                print('❌ ChatNotifier: 오류 타입: ${e.runtimeType}');
                print('❌ ChatNotifier: 오류 메시지: $e');
                print('❌ ChatNotifier: 스택 트레이스: $stackTrace');
                print('❌ ChatNotifier: 원본 이벤트: $event');
              }
            }

            // JSON 형식의 상태 메시지 처리 (파일 첨부 시 로딩 상태)
            if (event.startsWith('{"status":"generating_response"')) {
              try {
                final Map<String, dynamic> data = jsonDecode(event);
                if (data.containsKey('status') &&
                    data['status'] == 'generating_response') {
                  String loadingMessage =
                      data['message'] ?? '답변을 생성중입니다. 잠시만 기다려주세요...';
                  print('로딩 상태 감지: $loadingMessage');

                  // 마지막 AI 메시지에 로딩 상태 표시 (PDF 파일이 없거나 아직 로딩 상태가 아닌 경우만)
                  if (state.arvChatDetail.isNotEmpty &&
                      state.arvChatDetail.last['role'] == 1) {
                    List<Map<String, dynamic>> updated = List.from(
                      state.arvChatDetail,
                    );
                    Map<String, dynamic> lastMessage = Map.from(updated.last);

                    // PDF 파일이 이미 로딩 메시지를 표시하고 있는 경우는 메시지를 교체하지 않음
                    if (lastMessage['isLoading'] != true) {
                      lastMessage['message'] = loadingMessage;
                      lastMessage['isStreaming'] = true;
                      lastMessage['isLoading'] = true; // 로딩 상태 플래그 추가

                      // streamChat/withModel API 사용 아카이브에서만 COT 속성 제거
                      // 사내업무 아카이브와 일반 아카이브에서는 COT 속성 유지
                      final String archiveName =
                          lastMessage['archive_name'] ?? '';
                      final String archiveType =
                          lastMessage['archive_type'] ?? '';

                      // COT를 비활성화할 아카이브만 체크
                      bool shouldDisableCOT = archiveName == '코딩 어시스턴트' ||
                          archiveName == 'SAP 어시스턴트' ||
                          archiveName == 'AI Chatbot' ||
                          archiveType == 'coding' ||
                          archiveType == 'sap' ||
                          archiveType == 'code';

                      if (shouldDisableCOT) {
                        lastMessage['thoughtPart'] = '';
                        lastMessage['responsePart'] = lastMessage['message'];
                        lastMessage['hasThoughtCompleted'] = false;
                        print('스트리밍 시작 시 COT 속성 완전 제거됨 - 아카이브: $archiveName');
                      } else if (archiveName == '사내업무') {
                        // 사내업무 아카이브: </think> 태그 기준으로 분리
                        final String currentMessage =
                            lastMessage['message'] ?? '';
                        final int thinkEndIndex = currentMessage.indexOf(
                          '</think>',
                        );
                        if (thinkEndIndex != -1) {
                          lastMessage['thoughtPart'] = currentMessage.substring(
                            0,
                            thinkEndIndex + 9,
                          );
                          lastMessage['responsePart'] =
                              currentMessage.substring(thinkEndIndex + 9);
                          lastMessage['hasThoughtCompleted'] = true;
                        } else {
                          lastMessage['thoughtPart'] = currentMessage;
                          lastMessage['responsePart'] = '';
                          lastMessage['hasThoughtCompleted'] = false;
                        }
                      } else {
                        // 일반 아카이브: COT 속성 설정하지 않음 (일반 메시지 렌더링 사용)
                        // thoughtPart, responsePart, hasThoughtCompleted 속성을 설정하지 않음
                        // MessageRenderer에서 일반 렌더링으로 처리됨
                      }
                    }

                    updated[updated.length - 1] = lastMessage;
                    state = state.copyWith(arvChatDetail: updated);
                    // 사용자가 아래쪽에 있을 때만 자동 스크롤
                    scrollManager.handleStreamingMessage();
                  }
                }
              } catch (e) {
                print('로딩 상태 정보 파싱 오류: $e');
              }
              return;
            }

            // JSON 형식의 카테고리 정보 확인
            if (event.startsWith('{"category":"') && event.endsWith('"}')) {
              try {
                final Map<String, dynamic> data = jsonDecode(event);
                if (data.containsKey('category')) {
                  final categoryHeader = data['category'].toLowerCase();
                  final categoryMessages = {
                    'csr': 'CSR 답변 입니다',
                    'code': 'Code 답변 입니다',
                    'mail': 'Mail 답변 입니다',
                    'policy': 'Policy 답변 입니다',
                    'eaccounting': 'Eaccounting 답변 입니다',
                    'budget': 'Budget 답변 입니다',
                    'common': 'Common 답변 입니다',
                    'hr': 'HR 답변 입니다',
                    'sap': 'SAP 답변 입니다',
                    'csrsearch': 'CSR 과거 이력 조회 답변 입니다',
                    'project': 'Project 답변 입니다',
                    '휴가상신': '휴가상신 초안 작성중입니다. 잠시만 기다려 주십시오.',
                    'vacation': '휴가상신 초안 작성중입니다. 잠시만 기다려 주십시오.',
                    'hr_leave_apply': '휴가 초안 상신',
                  };
                  if (categoryMessages.containsKey(categoryHeader)) {
                    final sysMsg = categoryMessages[categoryHeader]!;
                    if (state.arvChatDetail.isNotEmpty &&
                        state.arvChatDetail.last['role'] == 1) {
                      List<Map<String, dynamic>> updated = List.from(
                        state.arvChatDetail,
                      );
                      Map<String, dynamic> lastMessage = Map.from(updated.last);
                      lastMessage['systemMessage'] = sysMsg;
                      updated[updated.length - 1] = lastMessage;
                      state = state.copyWith(arvChatDetail: updated);

                      // 휴가상신 카테고리 처리
                      if (categoryHeader == '휴가상신' ||
                          categoryHeader == 'vacation' ||
                          categoryHeader == 'hr_leave_apply') {
                        _handleVacationRequestCategory(data);
                      }
                    }
                  }
                }
              } catch (e) {
                print('카테고리 정보 파싱 오류: $e');
              }
              return;
            }

            // 텍스트 형태의 시스템 메시지 확인 (getEventStream, getAttachmentEventStream에서 전송)
            if (event.startsWith('[') &&
                event.contains(' 답변 입니다]') &&
                event.endsWith('\n\n')) {
              try {
                final match = RegExp(
                  r'^\[(.*?) 답변 입니다\]\s*\n+',
                ).firstMatch(event);
                if (match != null) {
                  final sysMsg = '${match.group(1)} 답변 입니다';
                  if (state.arvChatDetail.isNotEmpty &&
                      state.arvChatDetail.last['role'] == 1) {
                    List<Map<String, dynamic>> updated = List.from(
                      state.arvChatDetail,
                    );
                    Map<String, dynamic> lastMessage = Map.from(updated.last);
                    lastMessage['systemMessage'] = sysMsg;
                    updated[updated.length - 1] = lastMessage;
                    state = state.copyWith(arvChatDetail: updated);
                  }
                  return;
                }
              } catch (e) {
                print('텍스트 시스템 메시지 파싱 오류: $e');
              }
            }

            // 일반 텍스트 청크 처리
            String formattedEvent = event
                .replaceAllMapped(RegExp(r'\\n\\n'), (match) => '\n\n')
                .replaceAllMapped(RegExp(r'\\n'), (match) => '\n');

            accumulatedResponse += formattedEvent;

            // 마크다운 포맷팅 적용
            String formattedMarkdown = MessageUtils.formatMarkdownMessage(
              accumulatedResponse,
            );

            // 스트리밍 중 텍스트 업데이트 시 자동 스크롤 (코드 블록 감지 + 줄바꿈 감지)
            final hasCodeBlock = formattedMarkdown.contains('```');
            scrollManager.onStreamingTextUpdate(
              hasCodeBlock: hasCodeBlock,
              textChunk: formattedEvent, // 현재 청크
              accumulatedText: formattedMarkdown, // 누적된 전체 텍스트
            );

            // 마지막 AI 메시지를 UI에서 업데이트
            if (state.arvChatDetail.isNotEmpty &&
                state.arvChatDetail.last['role'] == 1) {
              List<Map<String, dynamic>> updated = List.from(
                state.arvChatDetail,
              );
              Map<String, dynamic> lastMessage = Map.from(updated.last);

              // 첫 번째 실제 답변이 오면 기존 로딩 메시지를 지우고 새 답변으로 교체
              if (lastMessage['isLoading'] == true) {
                lastMessage['message'] = formattedMarkdown;
                // 스트리밍 로그 플래그 리셋 (첫 번째 실제 답변 시작 시)
                MessageRenderer.resetStreamingLogFlag();
              } else {
                lastMessage['message'] = formattedMarkdown;
              }

              lastMessage['isStreaming'] = true;
              lastMessage['isLoading'] = false; // 실제 답변이 시작되면 로딩 상태 해제

              // streamChat/withModel API 사용 아카이브에서는 스트리밍 종료 시에도 COT 속성 완전 제거
              // 데이터 수신 종료 시점에서도 COT 렌더링 차단
              final String archiveName = lastMessage['archive_name'] ?? '';
              final String archiveType = lastMessage['archive_type'] ?? '';
              bool shouldDisableCOT = archiveName == '코딩 어시스턴트' ||
                  archiveName == 'SAP 어시스턴트' ||
                  archiveName == 'AI Chatbot' ||
                  archiveType == 'coding' ||
                  archiveType == 'sap' ||
                  archiveType == 'code';

              if (shouldDisableCOT) {
                lastMessage['thoughtPart'] = '';
                lastMessage['responsePart'] = lastMessage['message'];
                lastMessage['hasThoughtCompleted'] = false;
                print('스트리밍 종료 시 COT 속성 완전 제거됨 - 아카이브: $archiveName');
              } else if (archiveName == '사내업무') {
                // 사내업무 아카이브: </think> 태그 기준으로 분리
                final String currentMessage = lastMessage['message'] ?? '';
                final int thinkEndIndex = currentMessage.indexOf('</think>');
                if (thinkEndIndex != -1) {
                  lastMessage['thoughtPart'] = currentMessage.substring(
                    0,
                    thinkEndIndex + 9,
                  );
                  lastMessage['responsePart'] = currentMessage.substring(
                    thinkEndIndex + 9,
                  );
                  lastMessage['hasThoughtCompleted'] = true;
                } else {
                  lastMessage['thoughtPart'] = currentMessage;
                  lastMessage['responsePart'] = '';
                  lastMessage['hasThoughtCompleted'] = false;
                }
              } else {
                // 일반 아카이브: COT 속성 설정하지 않음 (일반 메시지 렌더링 사용)
                // thoughtPart, responsePart, hasThoughtCompleted 속성을 설정하지 않음
                // MessageRenderer에서 일반 렌더링으로 처리됨
              }

              updated[updated.length - 1] = lastMessage;
              state = state.copyWith(arvChatDetail: updated);
              // 사용자가 아래쪽에 있을 때만 자동 스크롤
              scrollManager.handleStreamingMessage();
            }
          },
          onDone: () {
            print('\n=== 스트리밍 수신 완료 ===');
            print('총 청크 개수: $chunkCount개');
            print('최종 누적 메시지 길이: ${accumulatedResponse.length} 글자');
            print('최종 전체 메시지:');
            print(
              '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
            );
            print(accumulatedResponse);
            print(
              '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
            );

            if (state.arvChatDetail.isNotEmpty &&
                state.arvChatDetail.last['role'] == 1) {
              List<Map<String, dynamic>> updated = List.from(
                state.arvChatDetail,
              );
              Map<String, dynamic> lastMessage = Map.from(updated.last);
              lastMessage['message'] = accumulatedResponse;
              lastMessage['isStreaming'] = false;

              // streamChat/withModel API 사용 아카이브에서는 스트리밍 종료 시에도 COT 속성 완전 제거
              // 데이터 수신 종료 시점에서도 COT 렌더링 차단
              final String archiveName = lastMessage['archive_name'] ?? '';
              final String archiveType = lastMessage['archive_type'] ?? '';
              bool shouldDisableCOT = archiveName == '코딩 어시스턴트' ||
                  archiveName == 'SAP 어시스턴트' ||
                  archiveName == 'AI Chatbot' ||
                  archiveType == 'coding' ||
                  archiveType == 'sap' ||
                  archiveType == 'code';

              if (shouldDisableCOT) {
                lastMessage['thoughtPart'] = '';
                lastMessage['responsePart'] = lastMessage['message'];
                lastMessage['hasThoughtCompleted'] = false;
                print('스트리밍 종료 시 COT 속성 완전 제거됨 - 아카이브: $archiveName');
              }

              updated[updated.length - 1] = lastMessage;
              state = state.copyWith(
                arvChatDetail: updated,
                isStreaming: false,
              );

              // 스트리밍 종료 - ChatGPT 스타일 자동 스크롤 비활성화
              scrollManager.stopStreaming();

              // 서버 우선 로직: AI 응답은 StreamService에서 이미 저장됨
              // 직접 로컬DB 저장 로직 제거

              // 서버-로컬 메시지 동기화 제거 (로그인 시에만 동기화)
              // Future.delayed(const Duration(milliseconds: 500), () {
              //   _syncCurrentArchiveMessages();
              // });

              // 스트림 완료 시 자동 스크롤 제거 (사용자 읽던 위치 방해하지 않음)
              // scrollManager.onStreamComplete();
            }

            print('=== 스트리밍 처리 완전 종료 ===\n');
          },
          onError: (e, stackTrace) {
            print('\n=== 스트림 처리 중 오류 발생 ===');
            print('오류 타입: ${e.runtimeType}');
            print('오류 내용: $e');
            print('스택 트레이스: $stackTrace');
            print('현재 아카이브: $archiveName (타입: $category)');
            print('=== 스트림 오류 정보 완료 ===\n');
            _handleDynamicError(e);
          },
        );
      } catch (e, stackTrace) {
        print('\n=== 파일 업로드 중 오류 발생 ===');
        print('오류 내용: $e');
        print('스택 트레이스: $stackTrace');
        _handleError(
          ChatError(
            type: ErrorType.messageServer,
            message: '파일 업로드 중 오류가 발생했습니다.',
            details: e.toString(),
          ),
        );
        state = state.copyWith(isStreaming: false);
        // 오류 발생 시에도 스트리밍 종료
        scrollManager.stopStreaming();
        return;
      }
    }
    focusNode.requestFocus();
  }

  ErrorType _determineErrorType(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // 네트워크 관련 오류 감지
    if (error is SocketException ||
        errorString.contains('network is unreachable') ||
        errorString.contains('clientexception') ||
        errorString.contains('socketexception') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection reset') ||
        errorString.contains('connection timeout') ||
        errorString.contains('connection closed') ||
        errorString.contains('write failed') ||
        errorString.contains('원격 호스트에 의해') ||
        errorString.contains('강제로 끊겼습니다') ||
        errorString.contains('errno = 10054')) {
      return ErrorType.network;
    } else if (errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503')) {
      return ErrorType.server;
    } else if (error is FormatException ||
        error is TypeError ||
        errorString.contains('null check operator')) {
      return ErrorType.app;
    }
    return ErrorType.unknown;
  }

  void cancelStreaming() {
    _webSearchLoadingTimer?.cancel();
    _webSearchLoadingTimer = null;
    _subscription?.cancel();
    _subscription = null;

    // 스트리밍 중단 시 메시지 상태도 업데이트
    if (state.arvChatDetail.isNotEmpty &&
        state.arvChatDetail.last['role'] == 1) {
      List<Map<String, dynamic>> updated = List.from(state.arvChatDetail);
      Map<String, dynamic> lastMessage = Map.from(updated.last);

      // 로딩 상태이거나 빈 메시지인 경우 해당 메시지를 제거
      if (lastMessage['isLoading'] == true ||
          (lastMessage['message'] as String).trim().isEmpty ||
          (lastMessage['message'] as String).contains('답변 대기 시간이 있습니다') ||
          (lastMessage['message'] as String).contains('답변을 생성중입니다') ||
          (lastMessage['message'] as String).contains('잠시만 기다려주세요')) {
        // 마지막 AI 메시지 제거
        updated.removeLast();
        print('로딩 상태 또는 대기 메시지 제거됨');
      } else {
        // 스트리밍 상태만 종료로 설정
        lastMessage['isStreaming'] = false;
        updated[updated.length - 1] = lastMessage;
      }

      // 상태 업데이트 (스트리밍 false 및 업데이트된 메시지 목록)
      state = state.copyWith(arvChatDetail: updated, isStreaming: false);
    } else {
      state = state.copyWith(isStreaming: false);
    }

    // 응답 중단 후 포커스 설정을 지연 실행
    Future.delayed(const Duration(milliseconds: 100), () {
      focusNode.requestFocus();
    });

    print('스트림 처리가 중단되었습니다.');
  }

  // 수동으로 채팅 내용을 업데이트하는 메서드
  void updateChatDetailManually(List<Map<String, dynamic>> updatedChatDetail) {
    // 현재 상태를 복사하고 대화 내용만 업데이트
    state = state.copyWith(arvChatDetail: updatedChatDetail);

    // 업데이트 후 스크롤 처리
    scrollManager.handleNewMessage();
  }

  // 검색 결과 하이라이트를 위한 메서드 추가
  void setSearchHighlight(String keyword, int? chatId) {
    print('setSearchHighlight 메서드 시작: keyword="$keyword", chatId=$chatId');

    state = state.copyWith(searchKeyword: keyword, highlightedChatId: chatId);

    print(
      '검색 하이라이트 설정 완료: keyword="${state.searchKeyword}", chatId=${state.highlightedChatId}',
    );

    // 약간의 지연 후 스크롤 처리 (필요한 경우)
    if (chatId != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        // 특정 채팅 ID로 스크롤
        scrollManager.scrollToChatId(chatId, state.arvChatDetail);
      });
    }
  }

  // 검색 하이라이트 정보 초기화
  void clearSearchHighlight() {
    print('clearSearchHighlight 메서드 호출: 검색 하이라이트 정보 초기화');

    // 이전 상태의 키워드와 하이라이트 ID 저장
    final previousKeyword = state.searchKeyword;
    final previousHighlightId = state.highlightedChatId;

    // 검색 관련 상태 초기화
    state = state.copyWith(
      clearSearchKeyword: true,
      clearHighlightedChatId: true,
    );

    print(
      '검색 하이라이트 정보 초기화 완료: "${previousKeyword}" → null, ${previousHighlightId} → null',
    );

    // 메시지 캐시 초기화 (마크다운 렌더링 다시 적용을 위해)
    if (previousKeyword != null || previousHighlightId != null) {
      MessageRenderer.clearAllCaches();
      print('메시지 캐시 초기화: 마크다운 렌더링 다시 적용됨');
    }
  }

  Future<void> selectTopic(String topicId) async {
    try {
      final previousArchiveId = state.currentArchiveId;
      // final previousArchiveType = state.archiveType;

      print(
        'selectTopic 시작: topicId=$topicId, 현재 검색 키워드="${state.searchKeyword}", 하이라이트ID=${state.highlightedChatId}',
      );

      // 아카이브 찾기 (PDF 제한 확인용)
      final targetArchive = state.arvChatHistory.firstWhere(
        (archive) => archive['archive_id'] == topicId,
        orElse: () => {'archive_type': ''},
      );

      // 아카이브 타입 확인 (PDF 제한 확인용)
      final targetArchiveType = targetArchive['archive_type'] ?? '';
      final targetArchiveName = targetArchive['archive_name'] ?? '';

      // PDF 제한 아카이브인지 확인
      // final isPdfRestrictedArchive = targetArchiveName == '코딩 어시스턴트' ||
      //     targetArchiveName == '코딩어시스턴트' ||
      //     targetArchiveName == 'SAP 어시스턴트' ||
      //     targetArchiveName == 'AI Chatbot' ||
      //     targetArchiveType == 'code' ||
      //     targetArchiveType == 'sap';

      // 현재 첨부된 파일에서 PDF 파일이 있는지 확인
      List<dynamic> currentAttachments = [];
      if (_currentContext != null) {
        try {
          currentAttachments = ProviderScope.containerOf(
            _currentContext!,
          ).read(attachmentProvider).files;
        } catch (e) {
          print('ProviderScope.containerOf 오류 (위젯이 dispose됨): $e');
          currentAttachments = [];
        }
      }

      print('\n=== selectTopic에서 PDF 파일 상태 확인 ===');
      print('현재 첨부된 파일 수: ${currentAttachments.length}');
      for (var i = 0; i < currentAttachments.length; i++) {
        final file = currentAttachments[i];
        print('파일 ${i + 1}: ${file.name}');
        print('  - extension: ${file.extension}');
        print('  - mimeType: ${file.mimeType}');
      }

      final hasPdfFiles = currentAttachments.any((file) {
        final extension = file?.extension?.toLowerCase() ?? '';
        final isPdf = extension == 'pdf';
        print('파일 ${file?.name}: extension="$extension", isPdf=$isPdf');
        return isPdf;
      });

      print('PDF 파일 첨부 여부: $hasPdfFiles');
      print('이동하려는 아카이브: $targetArchiveName (타입: $targetArchiveType)');
      print('=== selectTopic PDF 파일 상태 확인 완료 ===\n');

      // PDF 파일이 첨부된 상태에서는 어떤 아카이브로도 이동 불가
      if (hasPdfFiles) {
        final pdfFileNames = currentAttachments
            .where((file) => file?.extension?.toLowerCase() == 'pdf')
            .map((file) => file?.name ?? '')
            .where((name) => name.isNotEmpty)
            .join(', ');

        print('🚫 PDF 파일이 첨부된 상태에서 아카이브 이동 시도 차단');
        print('첨부된 PDF 파일: $pdfFileNames');
        print('이동하려는 아카이브: $targetArchiveName (타입: $targetArchiveType)');

        // 에러 메시지 표시 (BuildContext가 있는 경우)
        if (_currentContext != null) {
          try {
            CommonUIUtils.showWarningSnackBar(
              _currentContext!,
              'PDF 파일이 첨부된 상태에서는 다른 아카이브로 이동할 수 없습니다.\n'
              '첨부된 PDF 파일: $pdfFileNames\n'
              '파일 첨부를 삭제한 후 이동 가능합니다.',
            );
          } catch (e) {
            print('스낵바 표시 오류 (위젯이 dispose됨): $e');
          }
        }

        return; // 아카이브 이동 중단
      }

      // 현재 텍스트필드 내용 저장 (항상 저장)
      if (previousArchiveId.isNotEmpty) {
        _archiveTextFields[previousArchiveId] = controller.text;
        print('텍스트필드 내용 저장: ${controller.text} (아카이브 ID: $previousArchiveId)');
      }

      // 아카이브 찾기
      final selectedArchive = state.arvChatHistory.firstWhere(
        (archive) => archive['archive_id'] == topicId,
        orElse: () => {'archive_type': ''},
      );

      // 아카이브 타입 확인
      final newArchiveType = selectedArchive['archive_type'] ?? '';

      // 선택한 아카이브의 저장된 내용이 있으면 복원, 없으면 빈 텍스트로 초기화
      if (_archiveTextFields.containsKey(topicId)) {
        final restoredText = _archiveTextFields[topicId] ?? '';
        controller.text = restoredText;
        print('텍스트필드 내용 복원: $restoredText (아카이브 ID: $topicId)');
      } else {
        controller.clear();
        print('새 아카이브 선택: 텍스트필드 초기화 (아카이브 ID: $topicId)');
      }

      // 새 아카이브로 이동할 때 검색 하이라이트 초기화 (검색 결과로 이동하는 경우 제외)
      final bool clearSearchInfo =
          state.searchKeyword == null || state.highlightedChatId == null;

      print(
        '검색어 상태: "${state.searchKeyword}", 하이라이트ID: ${state.highlightedChatId}',
      );
      print('clearSearchInfo=$clearSearchInfo (검색결과로 이동: ${!clearSearchInfo})');

      // 아카이브 선택 및 상태 업데이트
      state = state.copyWith(
        selectedTopic: topicId,
        currentArchiveId: topicId,
        archiveType: newArchiveType,
        clearSearchKeyword: clearSearchInfo,
        clearHighlightedChatId: clearSearchInfo,
        // clearSystemMessage: true, // 시스템 메시지 제거 파라미터 삭제
      );

      print(
        '상태 업데이트 후: 검색 키워드="${state.searchKeyword}", 하이라이트ID=${state.highlightedChatId}',
      );

      // 검색 정보가 초기화되면 메시지 캐시도 초기화 (마크다운 렌더링 다시 적용을 위해)
      if (clearSearchInfo) {
        MessageRenderer.clearAllCaches();
        print('아카이브 전환: 메시지 캐시 초기화 (마크다운 렌더링 다시 적용)');
      }

      // 아카이브 상세 정보 로드
      await getChatDetail(topicId);

      print(
        'getChatDetail 후: 검색 키워드="${state.searchKeyword}", 하이라이트ID=${state.highlightedChatId}',
      );

      Future.delayed(const Duration(milliseconds: 300), () {
        // 검색에서 이동한 경우 해당 메시지로 스크롤
        if (state.highlightedChatId != null) {
          print('하이라이트된 메시지(ID=${state.highlightedChatId})로 스크롤합니다.');
          scrollManager.scrollToChatId(
            state.highlightedChatId,
            state.arvChatDetail,
          );
        } else {
          // 아니면 기본 스크롤 동작 사용
          scrollManager.scrollToBottom();
        }
      });

      print('아카이브 선택 완료: $topicId (타입: $newArchiveType)');
    } catch (e) {
      print('아카이브 선택 실패: $e');
    }
  }

  void updateCodeAssistantFirstTime() {
    state = state.copyWith(isFirstTimeCodeAssistant: false);
  }

  // disposeResources 메소드 제거됨 - dispose()에서 이미 모든 리소스 해제함
  // 중복 해제로 인한 오류 방지

  bool hasCodeAssistantArchive() {
    return state.arvChatHistory.any(
      (archive) => archive['archive_type'] == 'code',
    );
  }

  // 코딩 어시스턴트 아카이브를 선택하는 메서드
  Future<void> selectExistingCodeAssistant() async {
    final codeArchive = state.arvChatHistory.firstWhere(
      (archive) => archive['archive_type'] == 'code',
      orElse: () => {'archive_id': ''},
    );

    if (codeArchive['archive_id'].isNotEmpty) {
      await selectTopic(codeArchive['archive_id']);
    }
  }

  // 아카이브가 기본(디폴트) 아카이브인지 확인하는 메서드
  bool isDefaultArchive(String archiveId) {
    final archive = state.arvChatHistory.firstWhere(
      (a) => a['archive_id'] == archiveId,
      orElse: () => {},
    );

    final archiveName = archive['archive_name'] ?? '';
    final archiveType = archive['archive_type'] ?? '';

    return archiveName == '사내업무' ||
        archiveName == '코딩어시스턴트' ||
        archiveName == 'SAP 어시스턴트' ||
        archiveName == 'AI Chatbot' ||
        archiveType == 'code' ||
        archiveType == 'sap' ||
        archiveType == 'advanced';
  }

  // 아카이브가 비어있는지(첫 메시지인지) 확인
  bool isFirstMessage(String archiveId) {
    // 현재 아카이브의 메시지 개수를 확인
    return state.arvChatDetail.length <= 1; // 첫 AI 메시지만 있을 경우
  }

  // 자동 타이틀 업데이트 메서드

  // 아카이브 타이틀 UI 업데이트 전용 메서드 추가
  void updateArchiveTitleUI(String archiveId, String newTitle) {
    // 현재 제목 찾기 (로그용)
    final currentTitle = state.arvChatHistory.firstWhere(
      (a) => a['archive_id'] == archiveId,
      orElse: () => {'archive_name': '알 수 없음'},
    )['archive_name'];

    print('🔄 제목 변경 (UI만): "$currentTitle" → "$newTitle"');

    // UI 상태 업데이트
    state = state.copyWith(
      arvChatHistory: state.arvChatHistory.map((archive) {
        if (archive['archive_id'] == archiveId) {
          print('✓ 아카이브 목록에서 제목 업데이트 완료');
          return {...archive, 'archive_name': newTitle};
        }
        return archive;
      }).toList(),
    );

    // 선택된 토픽이면 해당 정보도 업데이트
    if (state.selectedTopic == archiveId) {
      print('✓ 선택된 토픽 제목도 함께 업데이트 완료');
    }
  }

  // 간단한 스트림 기반 타이틀 업데이트
  void updateTitleUsingNoStream(
    String userId,
    String archiveId,
    String message,
  ) {
    print('자동 타이틀 업데이트 시작: $archiveId');
    final accumulatedTitle = StringBuffer();
    StreamSubscription<String>? subscription;

    // 타임아웃과 함께 안전한 구독 관리
    final timeoutTimer = Timer(const Duration(seconds: 30), () {
      subscription?.cancel();
      print('자동 타이틀 업데이트 타임아웃: $archiveId');
    });

    subscription =
        StreamService.getAutoTitleStream(userId, archiveId, message).listen(
      (String title) {
        // 스트림으로 받는 타이틀 조각 처리
        accumulatedTitle.write(title);
      },
      onDone: () {
        // 스트림 완료 시 처리
        timeoutTimer.cancel();
        final finalTitle = accumulatedTitle.toString().trim();
        if (finalTitle.isNotEmpty) {
          print('자동 타이틀 생성 완료: "$finalTitle"');

          // UI만 업데이트 (서버/로컬 DB는 이미 처리됨)
          updateArchiveTitleUI(archiveId, finalTitle);
        }
        subscription?.cancel();
      },
      onError: (error) {
        print('자동 타이틀 스트림 오류: $error');
        timeoutTimer.cancel();
        subscription?.cancel();
      },
    );
  }

  // 선물 메시지 추가 메서드
  void addGiftMessage(Map<String, dynamic> giftMessage) {
    final updatedChatDetail = [...state.arvChatDetail, giftMessage];

    state = state.copyWith(arvChatDetail: updatedChatDetail);

    // 스크롤을 맨 아래로 이동
    Future.delayed(const Duration(milliseconds: 100), () {
      scrollManager.handleNewMessage();
    });

    print('🎁 선물 메시지가 채팅에 추가되었습니다');
  }

  // 생일 메시지 추가 메서드 (선물 고르러가기 버튼 포함)
  void addBirthdayMessage(Map<String, dynamic> birthdayMessage) {
    final updatedChatDetail = [...state.arvChatDetail, birthdayMessage];

    state = state.copyWith(arvChatDetail: updatedChatDetail);

    // 스크롤을 맨 아래로 이동
    Future.delayed(const Duration(milliseconds: 100), () {
      scrollManager.handleNewMessage();
    });

    print('🎂 생일 메시지가 채팅에 추가되었습니다');
  }

  // 결재 요청 메시지 추가 메서드
  void addApprovalMessage(Map<String, dynamic> approvalMessage) {
    final updatedChatDetail = [...state.arvChatDetail, approvalMessage];

    state = state.copyWith(arvChatDetail: updatedChatDetail);

    // 스크롤을 맨 아래로 이동
    Future.delayed(const Duration(milliseconds: 100), () {
      scrollManager.handleNewMessage();
    });

    print('📋 결재 요청 메시지가 채팅에 추가되었습니다');
  }

  // 공지사항 메시지 추가 (테마에 맞게 꾸며서)
  void addAnnouncementMessage(
    String title,
    String content, {
    String renderType = 'text',
    int? contestId,
    String? contestType,
  }) {
    final timestamp = DateTime.now();
    final messageId = timestamp.millisecondsSinceEpoch.toString();

    // 공지사항을 테마에 맞게 꾸민 메시지 생성
    final formattedMessage = '''
📢 **공지사항**

**${title}**

${content}

---
*ASPN AI Assistant*
''';

    final announcementMessage = {
      'archive_id': state.currentArchiveId,
      'user_id': userId,
      'message': formattedMessage,
      'role': 1, // AI 메시지
      'chat_time': timestamp.toString(),
      'isAnnouncementMessage': true, // 공지사항 식별자
      'announcement_title': title,
      'announcement_content': content,
      'notificationId': messageId,
      'timestamp': timestamp.toIso8601String(),
      'messageId': messageId,
      'renderType': renderType, // 렌더링 타입 추가
      'contest_id': contestId, // 공모전 ID 추가
      'contest_type': contestType, // 공모전 타입 추가
    };

    final updatedChatDetail = [...state.arvChatDetail, announcementMessage];
    state = state.copyWith(arvChatDetail: updatedChatDetail);

    // 스크롤을 맨 아래로 이동
    Future.delayed(const Duration(milliseconds: 100), () {
      scrollManager.handleNewMessage();
    });

    print('📢 공지사항 메시지가 채팅에 추가되었습니다: $title (renderType: $renderType)');
  }

  // 오류 처리 메서드들 추가
  void _handleError(ChatError error) {
    print('Error occurred: ${error.type.name} - ${error.message}');

    // UI 상태 업데이트
    _updateUIForError();

    // 오류 메시지 표시
    if (_currentContext != null) {
      _showErrorSnackBar(_currentContext!, error);
    }

    // 채팅 UI에 오류 표시
    _updateChatWithError(error);
  }

  void _handleDynamicError(dynamic error) {
    final errorType = _determineErrorType(error);
    final chatError = ChatError(
      type: errorType,
      message: error.toString(),
      details: error.toString(),
    );
    _handleError(chatError);
  }

  void _updateUIForError() {
    state = state.copyWith(isStreaming: false);
    _subscription?.cancel();
    _subscription = null;

    Future.delayed(const Duration(milliseconds: 100), () {
      focusNode.requestFocus();
    });

    scrollManager.handleNewMessage();
  }

  void _showErrorSnackBar(BuildContext context, ChatError error) {
    String errorMessage;

    switch (error.type) {
      case ErrorType.network:
        errorMessage = "네트워크 연결이 불안정합니다.";
        break;
      case ErrorType.server:
        errorMessage = "서버에 문제가 발생했습니다.";
        break;
      case ErrorType.app:
        errorMessage = "앱 내부 오류가 발생했습니다.";
        break;
      case ErrorType.loginNetwork:
        errorMessage = "로그인 네트워크 오류";
        break;
      case ErrorType.loginServer:
        errorMessage = "로그인 서버 오류";
        break;
      case ErrorType.messageNetwork:
        errorMessage = "메시지 전송 네트워크 오류";
        break;
      case ErrorType.messageServer:
        errorMessage = "메시지 전송 서버 오류";
        break;
      default:
        errorMessage = "알 수 없는 오류가 발생했습니다.";
    }

    print('\n=== 오류 스낵바 표시 ===');
    print('오류 타입: ${error.type}');
    print('오류 메시지: ${error.message}');
    print('오류 상세: ${error.details}');
    print('표시할 메시지: $errorMessage');
    print('=== 오류 스낵바 정보 완료 ===\n');

    CommonUIUtils.showErrorSnackBar(context, errorMessage);
  }

  void _updateChatWithError(ChatError error) {
    if (state.arvChatDetail.isNotEmpty &&
        state.arvChatDetail.last['role'] == 1) {
      List<Map<String, dynamic>> updated = List.from(state.arvChatDetail);
      Map<String, dynamic> lastMessage = Map.from(updated.last);

      String errorMessage;
      switch (error.type) {
        case ErrorType.network:
          errorMessage = "\n\n네트워크 연결이 불안정합니다. 인터넷 연결을 확인해주세요.";
          break;
        case ErrorType.server:
          errorMessage = "\n\n서버에 문제가 발생했습니다. 잠시 후 다시 시도해주세요.";
          break;
        case ErrorType.app:
          errorMessage = "\n\n앱 내부 오류가 발생했습니다. 앱을 재시작해주세요.";
          break;
        default:
          errorMessage = "\n\n알 수 없는 오류가 발생했습니다.";
      }

      lastMessage['message'] += errorMessage;
      lastMessage['isError'] = true;
      updated[updated.length - 1] = lastMessage;
      state = state.copyWith(arvChatDetail: updated);

      // 로컬 DB에도 오류 메시지 반영
      _dbHelper.updateLastAgentMessage(
        state.currentArchiveId,
        lastMessage['message'],
      );
    }
  }

  // 서버-로컬 메시지 동기화 메서드 제거 (로그인 시에만 동기화)
  // _syncCurrentArchiveMessages 메서드는 더 이상 사용되지 않음

  // 선물 도착 메시지를 채팅창에 추가
  void addGiftArrivalMessage(Map<String, dynamic> giftMessage) {
    try {
      // 채팅 히스토리에 추가
      final List<Map<String, dynamic>> updatedChatDetail = List.from(
        state.arvChatDetail,
      );

      final messageForChat = {
        'role': 1, // 에이전트 메시지
        'message': giftMessage['content'],
        'type': 'gift_arrival',
        'timestamp':
            giftMessage['timestamp'] ?? DateTime.now().toIso8601String(),
        'gift_data': giftMessage['gift_data'],
        'id': giftMessage['id'],
        'isUser': false,
        'isGiftArrival': true, // 선물 도착 메시지 표시
      };

      updatedChatDetail.add(messageForChat);

      // 상태 업데이트
      state = state.copyWith(arvChatDetail: updatedChatDetail);

      print('✅ 선물 도착 메시지가 채팅창에 추가되었습니다: ${giftMessage['content']}');

      // 스크롤을 최하단으로 이동
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollManager.scrollToBottom();
      });
    } catch (e) {
      print('❌ 선물 도착 메시지 추가 실패: $e');
    }
  }

  /// 휴가상신 카테고리 헤더 처리
  void _handleVacationRequestCategory(Map<String, dynamic> data) {
    print('🏖️ 휴가상신 카테고리 감지됨: $data');

    try {
      // 현재 컨텍스트가 있는지 확인
      if (_currentContext == null) {
        print('❌ 현재 컨텍스트가 없어 휴가상신 모달을 표시할 수 없습니다');
        return;
      }

      // "사내업무" 아카이브에서만 동작하도록 확인
      String currentArchiveName = '';
      for (var archive in state.arvChatHistory) {
        if (archive['archive_id'] == state.currentArchiveId) {
          currentArchiveName = archive['archive_name'] ?? '';
          break;
        }
      }

      if (currentArchiveName != '사내업무') {
        print('❌ 휴가상신은 사내업무 아카이브에서만 동작합니다. 현재 아카이브: $currentArchiveName');
        return;
      }

      // 휴가상신 모달을 표시
      final container = ProviderScope.containerOf(_currentContext!);
      container.read(leaveModalProvider.notifier).showModal();

      // 로딩 상태 시작
      container.read(leaveModalProvider.notifier).setLoadingVacationData(true);

      // 서버에서 받은 데이터로 자동 채우기 처리
      if (data.containsKey('vacation_data')) {
        _processVacationData(data['vacation_data']);
      } else if (data.containsKey('follow_up_required')) {
        // 필수 값이 없어서 반문이 필요한 경우
        _handleVacationFollowUp(data);
      }

      print('✅ 휴가상신 모달이 표시되었습니다');
    } catch (e) {
      print('❌ 휴가상신 카테고리 처리 실패: $e');
    }
  }

  /// 휴가 데이터로 모달 자동 채우기
  void _processVacationData(Map<String, dynamic> vacationData) {
    print('📝 휴가 데이터로 자동 채우기: $vacationData');

    try {
      if (_currentContext != null) {
        final container = ProviderScope.containerOf(_currentContext!);

        // vacationDataProvider를 사용하여 데이터 업데이트
        container
            .read(vacationDataProvider.notifier)
            .updateFromJson(vacationData);

        print('✅ 휴가 데이터 자동 채우기 완료');
      } else {
        print('❌ 현재 컨텍스트가 없어 휴가 데이터를 처리할 수 없습니다');
      }

      // 로딩 상태 종료 (2초 지연)
      Future.delayed(const Duration(seconds: 2), () {
        if (_currentContext != null) {
          final container = ProviderScope.containerOf(_currentContext!);
          container
              .read(leaveModalProvider.notifier)
              .setLoadingVacationData(false);
        }
      });
    } catch (e) {
      print('❌ 휴가 데이터 처리 실패: $e');

      // 오류 발생 시에도 로딩 상태 종료 (2초 지연)
      Future.delayed(const Duration(seconds: 2), () {
        if (_currentContext != null) {
          final container = ProviderScope.containerOf(_currentContext!);
          container
              .read(leaveModalProvider.notifier)
              .setLoadingVacationData(false);
        }
      });
    }
  }

  /// 휴가상신 반문 처리 (필수값 누락 시)
  void _handleVacationFollowUp(Map<String, dynamic> data) {
    print('❓ 휴가상신 반문 처리: $data');

    try {
      // 필수 정보가 부족한 경우 AI가 추가 정보를 요청
      String followUpMessage = '';
      List<String> missingFields = [];

      if (data.containsKey('missing_fields')) {
        missingFields = List<String>.from(data['missing_fields']);
        print('📋 누락된 필드들: $missingFields');
      }

      if (data.containsKey('follow_up_message')) {
        followUpMessage = data['follow_up_message'];
        print('🤖 AI 반문 메시지: $followUpMessage');
      } else {
        // 기본 반문 메시지 생성
        followUpMessage = _generateDefaultFollowUpMessage(missingFields);
      }

      // 채팅에 반문 메시지 추가
      if (followUpMessage.isNotEmpty) {
        _addFollowUpMessageToChat(followUpMessage, data);
      }

      // 부분적으로 받은 데이터가 있다면 모달에 채우기
      if (data.containsKey('partial_data')) {
        final partialData = data['partial_data'] as Map<String, dynamic>;
        if (_currentContext != null) {
          final container = ProviderScope.containerOf(_currentContext!);
          container
              .read(vacationDataProvider.notifier)
              .updateFromJson(partialData);
        }
      }

      print('🔄 휴가상신 반문 처리 완료');

      // 로딩 상태 종료 (2초 지연)
      Future.delayed(const Duration(seconds: 2), () {
        if (_currentContext != null) {
          final container = ProviderScope.containerOf(_currentContext!);
          container
              .read(leaveModalProvider.notifier)
              .setLoadingVacationData(false);
        }
      });
    } catch (e) {
      print('❌ 휴가상신 반문 처리 실패: $e');

      // 오류 발생 시에도 로딩 상태 종료 (2초 지연)
      Future.delayed(const Duration(seconds: 2), () {
        if (_currentContext != null) {
          final container = ProviderScope.containerOf(_currentContext!);
          container
              .read(leaveModalProvider.notifier)
              .setLoadingVacationData(false);
        }
      });
    }
  }

  /// 기본 반문 메시지 생성
  String _generateDefaultFollowUpMessage(List<String> missingFields) {
    if (missingFields.isEmpty) {
      return '휴가 신청을 위해 추가 정보가 필요합니다. 자세한 내용을 알려주세요.';
    }

    final fieldTranslations = {
      'vacation_type': '휴가 종류',
      'start_date': '시작일',
      'end_date': '종료일',
      'reason': '휴가 사유',
      'approver': '승인자',
    };

    final missingFieldNames = missingFields
        .map((field) => fieldTranslations[field] ?? field)
        .toList();

    if (missingFieldNames.length == 1) {
      return '휴가 신청을 위해 ${missingFieldNames.first}을(를) 알려주세요.';
    } else {
      final allButLast =
          missingFieldNames.sublist(0, missingFieldNames.length - 1);
      final last = missingFieldNames.last;
      return '휴가 신청을 위해 ${allButLast.join(', ')} 및 ${last}을(를) 알려주세요.';
    }
  }

  /// 채팅에 반문 메시지 추가
  void _addFollowUpMessageToChat(String message, Map<String, dynamic> data) {
    try {
      // AI 메시지로 반문 추가
      final followUpChatMessage = {
        'role': 1, // AI 메시지
        'message': message,
        'isUser': false,
        'timestamp': DateTime.now().toIso8601String(),
        'isVacationFollowUp': true, // 휴가 반문 메시지임을 표시
        'followUpData': data, // 반문 관련 데이터 저장
      };

      final updatedChatDetail =
          List<Map<String, dynamic>>.from(state.arvChatDetail);
      updatedChatDetail.add(followUpChatMessage);
      state = state.copyWith(arvChatDetail: updatedChatDetail);

      // 스크롤을 맨 아래로 이동
      Future.delayed(const Duration(milliseconds: 100), () {
        scrollManager.handleNewMessage();
      });

      print('✅ 휴가상신 반문 메시지가 채팅에 추가되었습니다: $message');
    } catch (e) {
      print('❌ 반문 메시지 추가 실패: $e');
    }
  }

  /// 휴가 부여 상신 전자결재 모달 트리거 처리
  void _handleElectronicApprovalModalTrigger(
      Map<String, dynamic> leaveGrantData) {
    try {
      print('🏢 _handleElectronicApprovalModalTrigger: 처리 시작');
      print(
          '🏢 _handleElectronicApprovalModalTrigger: 입력 데이터: $leaveGrantData');

      if (_currentContext == null) {
        print(
            '⚠️ _handleElectronicApprovalModalTrigger: Context가 없어서 모달을 트리거할 수 없습니다');
        return;
      }

      print('✅ _handleElectronicApprovalModalTrigger: Context 확인 완료');

      // 전자결재 모달 표시 (ChatHomePageV5의 메서드 호출)
      final BuildContext context = _currentContext!;

      // ChatHomePageV5에서 전자결재 모달을 여는 메서드를 호출하기 위해
      // 글로벌 키를 통해 접근하거나 콜백을 사용해야 합니다.
      // 여기서는 전역 함수를 통해 처리합니다.
      _showElectronicApprovalModal(context, leaveGrantData);

      print('✅ _handleElectronicApprovalModalTrigger: 전자결재 모달 트리거 완료');
    } catch (e, stackTrace) {
      print('❌ _handleElectronicApprovalModalTrigger: 오류 발생');
      print('❌ 오류 타입: ${e.runtimeType}');
      print('❌ 오류 메시지: $e');
      print('❌ 스택 트레이스: $stackTrace');
    }
  }

  /// 기본양식 전자결재 모달 트리거 처리
  void _handleBasicApprovalModalTrigger(
      Map<String, dynamic> basicApprovalData) {
    try {
      print('🏢 _handleBasicApprovalModalTrigger: 처리 시작');
      print('🏢 _handleBasicApprovalModalTrigger: 입력 데이터: $basicApprovalData');

      if (_currentContext == null) {
        print(
            '⚠️ _handleBasicApprovalModalTrigger: Context가 없어서 모달을 트리거할 수 없습니다');
        return;
      }

      print('✅ _handleBasicApprovalModalTrigger: Context 확인 완료');

      // 전자결재 모달 표시
      final BuildContext context = _currentContext!;
      _showBasicApprovalModal(context, basicApprovalData);

      print('✅ _handleBasicApprovalModalTrigger: 기본양식 모달 트리거 완료');
    } catch (e, stackTrace) {
      print('❌ _handleBasicApprovalModalTrigger: 오류 발생');
      print('❌ 오류 타입: ${e.runtimeType}');
      print('❌ 오류 메시지: $e');
      print('❌ 스택 트레이스: $stackTrace');
    }
  }

  /// 매출/매입 계약 기안서 전자결재 모달 트리거 처리
  void _handleContractApprovalModalTrigger(
      Map<String, dynamic> contractApprovalData) {
    try {
      print('🏢 _handleContractApprovalModalTrigger: 처리 시작');
      print(
          '🏢 _handleContractApprovalModalTrigger: 입력 데이터: $contractApprovalData');

      if (_currentContext == null) {
        print(
            '⚠️ _handleContractApprovalModalTrigger: Context가 없어서 모달을 트리거할 수 없습니다');
        return;
      }

      print('✅ _handleContractApprovalModalTrigger: Context 확인 완료');

      // 전자결재 모달 표시
      final BuildContext context = _currentContext!;
      _showContractApprovalModal(context, contractApprovalData);

      print('✅ _handleContractApprovalModalTrigger: 매출/매입 계약 기안서 모달 트리거 완료');
    } catch (e, stackTrace) {
      print('❌ _handleContractApprovalModalTrigger: 오류 발생');
      print('❌ 오류 타입: ${e.runtimeType}');
      print('❌ 오류 메시지: $e');
      print('❌ 스택 트레이스: $stackTrace');
    }
  }

  /// 전자결재 패널 표시 (기존 AppBar 버튼과 동일한 방식)
  void _showElectronicApprovalModal(
      BuildContext context, Map<String, dynamic> leaveGrantData) {
    print('🏢 _showElectronicApprovalModal: 기존 전자결재 패널 열기 시작');

    // 전역 변수에 데이터 저장 (패널에서 읽을 수 있도록)
    _pendingLeaveGrantData = leaveGrantData;

    // ChatHomePageV5의 전자결재 패널을 열어야 합니다
    // 이를 위해 글로벌 콜백이나 상태를 사용해야 합니다
    print('🏢 전자결재 패널 열기 요청 - 데이터 준비 완료');

    // 전자결재 패널 열기 이벤트 발생 (ChatHomePageV5에서 감지)
    tempSystemMessage = 'OPEN_ELECTRONIC_APPROVAL_PANEL';

    // State를 업데이트하여 리스너가 작동하도록 트리거
    state = state.copyWith();
  }

  /// 기본양식 전자결재 패널 표시
  void _showBasicApprovalModal(
      BuildContext context, Map<String, dynamic> basicApprovalData) {
    print('🏢 _showBasicApprovalModal: 기본양식 전자결재 패널 열기 시작');

    // 전역 변수에 데이터 저장 (패널에서 읽을 수 있도록)
    _pendingBasicApprovalData = basicApprovalData;

    // 전자결재 패널 열기 이벤트 발생 (ChatHomePageV5에서 감지)
    print('🏢 기본양식 전자결재 패널 열기 요청 - 데이터 준비 완료');
    tempSystemMessage = 'OPEN_ELECTRONIC_APPROVAL_PANEL';

    // State를 업데이트하여 리스너가 작동하도록 트리거
    state = state.copyWith();
  }

  /// 매출/매입 계약 기안서 전자결재 패널 표시
  void _showContractApprovalModal(
      BuildContext context, Map<String, dynamic> contractApprovalData) {
    print('🏢 _showContractApprovalModal: 매출/매입 계약 기안서 전자결재 패널 열기 시작');

    // 전역 변수에 데이터 저장 (패널에서 읽을 수 있도록)
    _pendingContractApprovalData = contractApprovalData;

    // 전자결재 패널 열기 이벤트 발생 (ChatHomePageV5에서 감지)
    print('🏢 매출/매입 계약 기안서 전자결재 패널 열기 요청 - 데이터 준비 완료');
    tempSystemMessage = 'OPEN_ELECTRONIC_APPROVAL_PANEL';

    // State를 업데이트하여 리스너가 작동하도록 트리거
    state = state.copyWith();
  }

  /// 전자결재 모달 초기화 트리거 (임시 전역 변수 사용)
  static Map<String, dynamic>? _pendingLeaveGrantData;
  static Map<String, dynamic>? _pendingBasicApprovalData;
  static Map<String, dynamic>? _pendingContractApprovalData;

  /// 전자결재 모달이 읽을 수 있는 pending 데이터 getter
  static Map<String, dynamic>? getPendingLeaveGrantData() {
    final data = _pendingLeaveGrantData;
    _pendingLeaveGrantData = null; // 한 번 읽으면 클리어
    return data;
  }

  /// 기본양식 모달이 읽을 수 있는 pending 데이터 getter
  static Map<String, dynamic>? getPendingBasicApprovalData() {
    final data = _pendingBasicApprovalData;
    _pendingBasicApprovalData = null; // 한 번 읽으면 클리어
    return data;
  }

  /// 매출/매입 계약 기안서 모달이 읽을 수 있는 pending 데이터 getter
  static Map<String, dynamic>? getPendingContractApprovalData() {
    final data = _pendingContractApprovalData;
    _pendingContractApprovalData = null; // 한 번 읽으면 클리어
    return data;
  }

  /// 휴가상신초안 모달 트리거 처리
  void _handleLeaveModalTrigger(Map<String, dynamic> leaveFormData) {
    try {
      print('🏢 _handleLeaveModalTrigger: 처리 시작');
      print('🏢 _handleLeaveModalTrigger: 입력 데이터: $leaveFormData');
      print(
          '🏢 _handleLeaveModalTrigger: 입력 데이터 타입: ${leaveFormData.runtimeType}');
      print(
          '🏢 _handleLeaveModalTrigger: 입력 데이터 키: ${leaveFormData.keys.toList()}');

      if (_currentContext == null) {
        print('⚠️ _handleLeaveModalTrigger: Context가 없어서 모달을 트리거할 수 없습니다');
        return;
      }

      print('✅ _handleLeaveModalTrigger: Context 확인 완료');

      // 로딩 상태 시작
      final container = ProviderScope.containerOf(_currentContext!);
      print('✅ _handleLeaveModalTrigger: Container 생성 완료');

      // 화면 폭의 40%로 로딩 상태 시작 (AI가 초안 작성 중)
      final screenWidth = MediaQuery.of(_currentContext!).size.width;
      final loadingWidth = screenWidth * 0.4;

      container.read(leaveModalProvider.notifier).setLoadingVacationData(true);
      container.read(leaveModalProvider.notifier).state =
          container.read(leaveModalProvider.notifier).state.copyWith(
                customWidth: loadingWidth,
              );
      print('✅ _handleLeaveModalTrigger: 로딩 상태 시작 (폭: 40%)');

      // 휴가상신초안 모달 표시
      container.read(leaveModalProvider.notifier).showModal();
      print('✅ _handleLeaveModalTrigger: 모달 표시 완료');

      // 휴가 데이터를 VacationRequestData 형식으로 변환
      print('🔄 _handleLeaveModalTrigger: 데이터 변환 시작');
      final vacationData = _convertLeaveFormToVacationData(leaveFormData);
      print('✅ _handleLeaveModalTrigger: 데이터 변환 완료');
      print('📋 _handleLeaveModalTrigger: 변환된 데이터: ${vacationData.toJson()}');

      // VacationDataProvider에 데이터 설정
      print('🔄 _handleLeaveModalTrigger: Provider 데이터 설정 시작');
      container
          .read(vacationDataProvider.notifier)
          .updateFromJson(vacationData.toJson());
      print('✅ _handleLeaveModalTrigger: Provider 데이터 설정 완료');

      // 로딩 상태 종료 (2초 지연)
      Future.delayed(const Duration(seconds: 2), () {
        try {
          // 로딩 종료 + 화면 폭 60%로 확장 (사이드바 접힘)
          final expandedWidth =
              MediaQuery.of(_currentContext!).size.width * 0.6;
          container.read(leaveModalProvider.notifier).state =
              container.read(leaveModalProvider.notifier).state.copyWith(
                    isLoadingVacationData: false,
                    customWidth: expandedWidth,
                  );

          // 사이드바 접힘
          if (state.isSidebarVisible) {
            toggleSidebarVisibility();
            print('✅ _handleLeaveModalTrigger: 사이드바 접힘 완료');
          }

          print('✅ _handleLeaveModalTrigger: 로딩 상태 종료 완료 (폭: 60%로 확장)');
        } catch (e) {
          print('❌ _handleLeaveModalTrigger: 로딩 상태 종료 실패: $e');
        }
      });

      print('🎉 _handleLeaveModalTrigger: 전체 처리 완료');
    } catch (e, stackTrace) {
      print('❌ _handleLeaveModalTrigger: 처리 실패');
      print('❌ _handleLeaveModalTrigger: 오류 타입: ${e.runtimeType}');
      print('❌ _handleLeaveModalTrigger: 오류 메시지: $e');
      print('❌ _handleLeaveModalTrigger: 스택 트레이스: $stackTrace');

      // 오류 발생 시에도 로딩 상태 종료 (2초 지연)
      Future.delayed(const Duration(seconds: 2), () {
        if (_currentContext != null) {
          try {
            final container = ProviderScope.containerOf(_currentContext!);
            container
                .read(leaveModalProvider.notifier)
                .setLoadingVacationData(false);
            print('✅ _handleLeaveModalTrigger: 오류 시 로딩 상태 종료 완료');
          } catch (cleanupError) {
            print(
                '❌ _handleLeaveModalTrigger: 오류 시 로딩 상태 종료 실패: $cleanupError');
          }
        }
      });
    }
  }

  /// 휴가 폼 데이터를 VacationRequestData로 변환
  VacationRequestData _convertLeaveFormToVacationData(
      Map<String, dynamic> leaveFormData) {
    try {
      print('🔄 _convertLeaveFormToVacationData: 변환 시작');
      print('🔄 _convertLeaveFormToVacationData: 입력 데이터: $leaveFormData');

      // 날짜 변환 함수
      DateTime? parseDate(String? dateStr) {
        print('📅 parseDate: 파싱 시도 - $dateStr');
        if (dateStr == null || dateStr.isEmpty) {
          print('📅 parseDate: null 또는 빈 문자열');
          return null;
        }
        try {
          final result = DateTime.parse(dateStr);
          print('📅 parseDate: 성공 - $result');
          return result;
        } catch (e) {
          print('❌ parseDate: 파싱 오류 - $dateStr -> $e');
          return null;
        }
      }

      // 휴가 종류 추출
      final leaveType = leaveFormData['leave_type'] as String?;
      print('🔖 leave_type: $leaveType');

      // 날짜 추출
      final startDateStr = leaveFormData['start_date'] as String?;
      final endDateStr = leaveFormData['end_date'] as String?;
      print('📅 start_date: $startDateStr');
      print('📅 end_date: $endDateStr');

      final startDate = parseDate(startDateStr);
      final endDate = parseDate(endDateStr);

      // 휴가 사유 추출
      final reason = leaveFormData['reason'] as String?;
      print('📝 reason: $reason');

      // 참조자 목록 변환 (새로운 CcPersonData 사용)
      List<CcPersonData>? ccList;
      if (leaveFormData['cc_list'] != null) {
        print('👥 cc_list 처리 시작');
        final ccListData = leaveFormData['cc_list'] as List;
        print('👥 cc_list 원본: $ccListData');

        ccList = ccListData.map((cc) {
          final ccPersonData = CcPersonData(
            name: cc['name'] as String? ?? '',
            userId: cc['user_id'] as String? ?? '',
          );
          print('👥 변환된 CcPersonData: ${ccPersonData.toJson()}');
          return ccPersonData;
        }).toList();
        print('👥 전체 ccList 완성: ${ccList.map((cc) => cc.toJson()).toList()}');
      } else {
        print('👥 cc_list가 null입니다');
      }

      // 승인자 목록 변환 (새로운 ApprovalLineData 사용)
      List<ApprovalLineData>? approvalLine;
      if (leaveFormData['approval_line'] != null) {
        print('👤 approval_line 처리 시작');
        final approvalLineData = leaveFormData['approval_line'] as List;
        print('👤 approval_line 원본: $approvalLineData');

        approvalLine = approvalLineData.map((approver) {
          final approverData = ApprovalLineData(
            approverName: approver['approver_name'] as String? ?? '',
            approverId: approver['approver_id'] as String? ?? '',
            approvalSeq: approver['approval_seq'] as int? ?? 1,
          );
          print('👤 변환된 ApprovalLineData: ${approverData.toJson()}');
          return approverData;
        }).toList();
        print(
            '👤 전체 approvalLine 완성: ${approvalLine.map((a) => a.toJson()).toList()}');
      } else {
        print('👤 approval_line이 null입니다');
      }

      // half_day_slot 처리
      final halfDaySlot = leaveFormData['half_day_slot'] as String?;
      print('⏰ half_day_slot: $halfDaySlot');

      // leave_status 처리 (새로운 LeaveStatusData 사용)
      List<LeaveStatusData>? leaveStatus;
      if (leaveFormData['leave_status'] != null) {
        print('📊 leave_status 처리 시작');
        final leaveStatusData = leaveFormData['leave_status'] as List;
        print('📊 leave_status 원본: $leaveStatusData');

        leaveStatus = leaveStatusData.map((status) {
          final statusData = LeaveStatusData(
            leaveType: status['leave_type'] as String? ?? '',
            totalDays: (status['total_days'] as num?)?.toDouble() ?? 0.0,
            remainDays: (status['remain_days'] as num?)?.toDouble() ?? 0.0,
          );
          print('📊 변환된 LeaveStatusData: ${statusData.toJson()}');
          return statusData;
        }).toList();
        print(
            '📊 전체 leaveStatus 완성: ${leaveStatus.map((s) => s.toJson()).toList()}');
      } else {
        print('📊 leave_status가 null입니다');
      }

      final result = VacationRequestData(
        userId: leaveFormData['user_id'] as String?,
        leaveType: leaveType,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        ccList: ccList,
        approvalLine: approvalLine,
        halfDaySlot: halfDaySlot,
        leaveStatus: leaveStatus,
      );

      print('✅ _convertLeaveFormToVacationData: 변환 완료');
      print('✅ _convertLeaveFormToVacationData: 결과: ${result.toJson()}');

      return result;
    } catch (e, stackTrace) {
      print('❌ _convertLeaveFormToVacationData: 변환 오류');
      print('❌ _convertLeaveFormToVacationData: 오류 타입: ${e.runtimeType}');
      print('❌ _convertLeaveFormToVacationData: 오류 메시지: $e');
      print('❌ _convertLeaveFormToVacationData: 스택 트레이스: $stackTrace');
      return VacationRequestData.empty(); // 빈 데이터 반환
    }
  }

  /// 현재 컨텍스트 설정 (ChatHomePage에서 호출)
  void setCurrentContext(BuildContext? context) {
    _currentContext = context;
  }
}
