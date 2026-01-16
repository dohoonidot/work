import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/providers/theme_provider.dart';
import 'package:ASPN_AI_AGENT/ui/screens/voting_screen.dart';
import 'package:ASPN_AI_AGENT/ui/screens/my_submissions_screen.dart';
import 'package:ASPN_AI_AGENT/ui/screens/contest_guide_screen.dart';
import 'package:ASPN_AI_AGENT/shared/services/contest_api_service.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

/// 사내AI 공모전 화면
class ContestScreen extends ConsumerStatefulWidget {
  const ContestScreen({super.key});

  @override
  ConsumerState<ContestScreen> createState() => _ContestScreenState();
}

enum _ContestChatRole { user, assistant }

class _ContestChatMessage {
  const _ContestChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.isError = false,
    this.isPlaceholder = false,
  });

  final _ContestChatRole role;
  final String content;
  final DateTime timestamp;
  final bool isError;
  final bool isPlaceholder;

  _ContestChatMessage copyWith({
    _ContestChatRole? role,
    String? content,
    DateTime? timestamp,
    bool? isError,
    bool? isPlaceholder,
  }) {
    return _ContestChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isError: isError ?? this.isError,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
    );
  }
}

class _ContestScreenState extends ConsumerState<ContestScreen> {
  bool _isFormLoading = false; // 신청서 로딩 상태
  bool _isCheckingSubmission = true; // 제출 여부 체크 중 (초기값: true)

  // 신청서 필드 컨트롤러
  late final TextEditingController _nameController;
  late final TextEditingController _toolNameController;
  late final TextEditingController _workScopeController;
  late final TextEditingController _workMethodController;
  late final TextEditingController _beforeAfterController;
  late final TextEditingController _chatInputController;
  late final ScrollController _chatScrollController;
  late final FocusNode _chatFocusNode;
  final List<_ContestChatMessage> _chatMessages = [];
  bool _isChatSending = false;

  // 부서 및 직급 선택값
  String? _selectedDepartment;
  String? _selectedJobPosition;

  // 부서 목록
  final List<String> _departments = [
    '경영관리실',
    'New Tech사업부',
    '솔루션사업부',
    'FCM사업부',
    'SCM사업부',
    'Innovation Center',
    'Biz AI사업부',
    'HRS사업부',
    'DTE본부',
    'PUBLIC CLOUD사업부',
    'ITS사업부',
    'BAC사업부',
    'NGE본부',
    'BDS사업부',
    '남부지사',
  ];

  // 직급 목록
  final List<String> _jobPositions = [
    '인턴',
    '위원',
    '상무',
    '전문이사',
    '전무',
    '부사장',
    '대표',
  ];

  // 첨부 파일 리스트 (파일명과 데이터를 함께 저장) - 신청서 제출용
  List<Map<String, dynamic>> _selectedFiles = [];

  // chat API 응답에서 받은 attachment_urls (제출 시 전송)
  List<Map<String, dynamic>> _chatAttachmentUrls = [];

  // 제출 후 받은 응답 데이터
  int? _contestId;
  String? _summary;

  @override
  void initState() {
    super.initState();
    // 컨트롤러 초기화
    _nameController = TextEditingController();
    _toolNameController = TextEditingController();
    _workScopeController = TextEditingController();
    _workMethodController = TextEditingController();
    _beforeAfterController = TextEditingController();
    _chatInputController = TextEditingController();
    _chatScrollController = ScrollController();
    _chatFocusNode = FocusNode();

    // 화면 진입 시 사용자 제출 여부 체크 및 분기 처리
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSubmissionAndNavigate();
    });
  }

  /// 사용자 제출 여부를 체크하고 화면 분기 처리
  Future<void> _checkSubmissionAndNavigate() async {
    final userId = ref.read(userIdProvider);
    if (userId == null || userId.isEmpty) {
      print('⚠️ [ContestScreen] 로그인된 사용자 ID가 없습니다.');
      if (mounted) {
        setState(() {
          _isCheckingSubmission = false;
        });
      }
      return;
    }

    try {
      print('🔍 [ContestScreen] 제출 여부 체크 시작: $userId');
      final result = await ContestApiService.checkUserSubmission(
        userId: userId,
        contestType: 'test',
      );

      final status = result['status'] as int? ?? 0;

      if (!mounted) return;

      if (status == 1) {
        // 이미 제출한 경우 - 투표하기 화면으로 바로 이동
        print('✅ [ContestScreen] 이미 제출함 - 투표하기 화면으로 이동');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const VotingScreen(),
          ),
        );
      } else {
        // 미제출인 경우 - 신청서 화면 표시
        print('📝 [ContestScreen] 미제출 - 신청서 화면 표시');
        setState(() {
          _isCheckingSubmission = false;
        });
        _loadUserInfo();
        _showCoffeeWelcomePopup();
      }
    } catch (e) {
      print('❌ [ContestScreen] 제출 여부 체크 실패: $e');
      // 오류 시 기본 동작 (신청서 화면 표시)
      if (mounted) {
        setState(() {
          _isCheckingSubmission = false;
        });
        _loadUserInfo();
        _showCoffeeWelcomePopup();
      }
    }
  }

  /// 사용자 정보를 API에서 가져와서 신청서 필드에 자동 채우기
  Future<void> _loadUserInfo() async {
    final userId = ref.read(userIdProvider);
    if (userId == null || userId.isEmpty) {
      print('⚠️ [ContestScreen] 로그인된 사용자 ID가 없습니다.');
      return;
    }

    try {
      print('👤 [ContestScreen] 사용자 정보 로드 시작: $userId');
      final userInfo = await ContestApiService.getUserInfo(userId: userId);

      if (mounted) {
        setState(() {
          // 이름 채우기
          if (userInfo['name'] != null) {
            _nameController.text = userInfo['name'] as String;
          }

          // 부서 채우기
          if (userInfo['department'] != null) {
            final department = userInfo['department'] as String;
            // 부서 목록에 존재하는지 확인
            if (_departments.contains(department)) {
              _selectedDepartment = department;
            } else {
              print('⚠️ [ContestScreen] 알 수 없는 부서: $department');
            }
          }

          // 직급 채우기
          if (userInfo['job_position'] != null) {
            final jobPosition = userInfo['job_position'] as String;
            // 직급 목록에 존재하는지 확인
            if (_jobPositions.contains(jobPosition)) {
              _selectedJobPosition = jobPosition;
            } else {
              print('⚠️ [ContestScreen] 알 수 없는 직급: $jobPosition');
            }
          }

          print('✅ [ContestScreen] 사용자 정보 자동 채우기 완료');
          print('  - 이름: ${_nameController.text}');
          print('  - 부서: $_selectedDepartment');
          print('  - 직급: $_selectedJobPosition');
        });
      }
    } catch (e) {
      print('❌ [ContestScreen] 사용자 정보 로드 실패: $e');
      // 오류가 발생해도 화면은 정상적으로 표시되도록 함
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _toolNameController.dispose();
    _workScopeController.dispose();
    _workMethodController.dispose();
    _beforeAfterController.dispose();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    _chatFocusNode.dispose();
    super.dispose();
  }

  /// 신청서 제출
  Future<void> _submitContestForm(BuildContext context) async {
    // 필수 필드 검증
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이름을 입력해주세요.'),
        ),
      );
      return;
    }

    if (_selectedDepartment == null || _selectedDepartment!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('부서를 선택해주세요.'),
        ),
      );
      return;
    }

    if (_selectedJobPosition == null || _selectedJobPosition!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('직급을 선택해주세요.'),
        ),
      );
      return;
    }

    if (_toolNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사용한 AI TOOL을 입력해주세요.'),
        ),
      );
      return;
    }

    if (_workScopeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('어떤 업무에 적용했는지 입력해주세요.'),
        ),
      );
      return;
    }

    if (_workMethodController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('어떤 방식으로 사용했는지 입력해주세요.'),
        ),
      );
      return;
    }

    if (_beforeAfterController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Before & After를 입력해주세요.'),
        ),
      );
      return;
    }

    final userId = ref.read(userIdProvider);
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인이 필요합니다.'),
        ),
      );
      return;
    }

    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF14B8A6),
          ),
        ),
      );

      // 첨부 파일에서 바이트 데이터만 추출
      final List<Uint8List>? fileBytes = _selectedFiles.isNotEmpty
          ? _selectedFiles.map((file) => file['data'] as Uint8List).toList()
          : null;

      // 파일명 리스트 추출
      final List<String>? fileNames = _selectedFiles.isNotEmpty
          ? _selectedFiles
              .map((file) => file['filename'] as String? ?? 'image.jpg')
              .toList()
          : null;

      print('📎 [ContestScreen] 신청서 제출 - 첨부 파일 정보:');
      print('  - 로컬 파일: ${_selectedFiles.length}개');
      print('  - 채팅 URL: ${_chatAttachmentUrls.length}개');

      // API 호출
      final response = await ContestApiService.submitContest(
        userId: userId,
        name: _nameController.text.trim(),
        jobPosition: _selectedJobPosition!,
        department: _selectedDepartment!,
        contestType: '공모전',
        toolName: _toolNameController.text.trim(),
        workScope: _workScopeController.text.trim(),
        workMethod: _workMethodController.text.trim(),
        beforeAfter: _beforeAfterController.text.trim(),
        files: fileBytes,
        fileNames: fileNames,
        attachmentUrls:
            _chatAttachmentUrls.isNotEmpty ? _chatAttachmentUrls : null,
      );

      // 응답 데이터 저장
      if (mounted) {
        setState(() {
          _contestId = response['contest_id'] as int?;
          _summary = response['summary'] as String?;
        });

        // 로딩 다이얼로그 닫기
        Navigator.of(context).pop();

        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('신청서가 성공적으로 제출되었습니다. (ID: ${_contestId ?? 'N/A'})'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        print('✅ [ContestScreen] 신청서 제출 완료');
        print('  - contest_id: $_contestId');
        print('  - summary: $_summary');
      }
    } catch (e) {
      print('❌ 신청서 제출 실패: $e');

      if (mounted) {
        // 로딩 다이얼로그 닫기
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('신청서 제출 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 파일 선택 (신청서용)
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true, // 바이트 데이터 포함
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (var file in result.files) {
            if (file.bytes != null) {
              // 파일 확장자로 MIME 타입 결정
              final extension = file.extension?.toLowerCase() ?? '';
              String contentType = 'image/jpeg'; // 기본값
              switch (extension) {
                case 'jpg':
                case 'jpeg':
                  contentType = 'image/jpeg';
                  break;
                case 'png':
                  contentType = 'image/png';
                  break;
                case 'gif':
                  contentType = 'image/gif';
                  break;
                case 'webp':
                  contentType = 'image/webp';
                  break;
                default:
                  contentType = 'image/jpeg';
              }

              _selectedFiles.add({
                'filename': file.name,
                'data': file.bytes!,
                'content_type': contentType,
                'size': file.size,
              });
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedFiles.length}개의 이미지가 선택되었습니다.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ 파일 선택 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('파일 선택 중 오류가 발생했습니다.'),
        ),
      );
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) {
        return;
      }
      try {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } catch (_) {}
    });
  }

  Future<void> _handleChatSend() async {
    if (_isChatSending) return;
    final message = _chatInputController.text.trim();
    if (message.isEmpty) return;

    final userId = ref.read(userIdProvider);
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인이 필요합니다.'),
        ),
      );
      return;
    }

    _chatInputController.clear();

    late int assistantIndex;
    setState(() {
      _isChatSending = true;
      _chatMessages.add(
        _ContestChatMessage(
          role: _ContestChatRole.user,
          content: message,
          timestamp: DateTime.now(),
        ),
      );
      _chatMessages.add(
        _ContestChatMessage(
          role: _ContestChatRole.assistant,
          content: 'AI가 답변을 준비하고 있어요...',
          timestamp: DateTime.now(),
          isPlaceholder: true,
        ),
      );
      assistantIndex = _chatMessages.length - 1;
    });
    _scrollChatToBottom();

    try {
      final List<Uint8List>? files = _selectedFiles.isEmpty
          ? null
          : _selectedFiles.map((file) => file['data'] as Uint8List).toList();

      final List<String>? fileNames = _selectedFiles.isEmpty
          ? null
          : _selectedFiles
              .map((file) => file['filename'] as String? ?? 'image.jpg')
              .toList();

      final response = await ContestApiService.requestContest(
        contestType: '공모전',
        userId: userId,
        message: message,
        files: files,
        fileNames: fileNames,
      );

      // 새로운 응답 구조 처리: 신청서 필드에 자동 채우기
      // 신청서 필드 자동 채우기
      bool hasFormData = false;

      if (response.containsKey('tool_name') &&
          response['tool_name'] != null &&
          (response['tool_name'] as String).trim().isNotEmpty) {
        _toolNameController.text = response['tool_name'] as String;
        hasFormData = true;
      }

      if (response.containsKey('work_scope') &&
          response['work_scope'] != null &&
          (response['work_scope'] as String).trim().isNotEmpty) {
        _workScopeController.text = response['work_scope'] as String;
        hasFormData = true;
      }

      if (response.containsKey('work_method') &&
          response['work_method'] != null &&
          (response['work_method'] as String).trim().isNotEmpty) {
        _workMethodController.text = response['work_method'] as String;
        hasFormData = true;
      }

      if (response.containsKey('before_after') &&
          response['before_after'] != null &&
          (response['before_after'] as String).trim().isNotEmpty) {
        _beforeAfterController.text = response['before_after'] as String;
        hasFormData = true;
      }

      // attachment_urls 처리 및 저장
      List<String> attachmentInfo = [];
      if (response.containsKey('attachment_urls') &&
          response['attachment_urls'] != null) {
        final attachments = response['attachment_urls'] as List<dynamic>;
        print('📎 [ContestScreen] 첨부파일 URL 정보:');

        // attachment_urls 저장 (신청서 제출 시 사용)
        _chatAttachmentUrls.clear();
        for (var attachment in attachments) {
          if (attachment is Map<String, dynamic>) {
            final fileName = attachment['file_name'] as String? ?? '파일명 없음';
            final url = attachment['url'] as String? ?? '';
            final prefix = attachment['prefix'] as String? ?? '';
            attachmentInfo.add('  • $fileName');
            print('  - $fileName: $url (prefix: $prefix)');

            // attachment_urls 리스트에 추가 (서버에서 받은 그대로 저장)
            _chatAttachmentUrls.add({
              'file_name': fileName,
              'url': url,
              'prefix': prefix,
            });
          }
        }

        print('✅ [ContestScreen] ${_chatAttachmentUrls.length}개의 첨부파일 URL 저장됨');
      }

      // 채팅 메시지 생성
      String aiMessage;
      if (hasFormData) {
        aiMessage = '✅ 신청서 양식이 자동으로 채워졌습니다!\n\n'
            '• 사용한 AI TOOL: ${response['tool_name'] ?? '(비어있음)'}\n'
            '• 업무 적용: ${response['work_scope'] ?? '(비어있음)'}\n'
            '• 사용 방식: ${response['work_method'] ?? '(비어있음)'}\n'
            '• Before & After: ${response['before_after'] ?? '(비어있음)'}';

        // 첨부파일 정보가 있으면 추가
        if (attachmentInfo.isNotEmpty) {
          aiMessage += '\n\n📎 첨부 파일:\n${attachmentInfo.join('\n')}';
        }
      } else {
        // 기존 방식으로 메시지 추출 (하위 호환성)
        aiMessage = _extractAiMessage(response);
      }

      setState(() {
        _chatMessages[assistantIndex] = _chatMessages[assistantIndex].copyWith(
          content: aiMessage,
          timestamp: DateTime.now(),
          isPlaceholder: false,
          isError: false,
        );
        _isChatSending = false;

        // 채팅에서 파일을 보낸 후에는 로컬 파일 목록 비우기
        // (서버에서 받은 attachment_urls만 사용)
        _selectedFiles.clear();
        print('✅ [ContestScreen] 로컬 파일 목록 비움 (attachment_urls 사용)');
      });
    } catch (e) {
      setState(() {
        _chatMessages[assistantIndex] = _chatMessages[assistantIndex].copyWith(
          content: '답변 생성 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.\n$e',
          timestamp: DateTime.now(),
          isPlaceholder: false,
          isError: true,
        );
        _isChatSending = false;
      });
    } finally {
      _scrollChatToBottom();
    }
  }

  String _extractAiMessage(dynamic payload) {
    if (payload == null) return '응답을 불러오지 못했습니다.';
    if (payload is String) return payload;

    if (payload is Map<String, dynamic>) {
      const preferredKeys = [
        'message',
        'response',
        'answer',
        'content',
        'summary',
        'result',
      ];

      for (final key in preferredKeys) {
        final value = payload[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        } else if (value is List) {
          final joined = value.whereType<String>().join('\n');
          if (joined.trim().isNotEmpty) return joined.trim();
        } else if (value is Map<String, dynamic>) {
          final nested = _extractAiMessage(value);
          if (nested.isNotEmpty) return nested;
        }
      }

      final buffer = StringBuffer();
      payload.forEach((key, value) {
        if (value is String && value.trim().isNotEmpty) {
          buffer.writeln('$key: ${value.trim()}');
        }
      });
      if (buffer.isNotEmpty) return buffer.toString().trim();

      return const JsonEncoder.withIndent('  ').convert(payload);
    }

    if (payload is List) {
      final joined = payload
          .map((item) => _extractAiMessage(item))
          .where((text) => text.trim().isNotEmpty)
          .join('\n\n');
      if (joined.trim().isNotEmpty) {
        return joined.trim();
      }
    }

    return payload.toString();
  }

  Widget _buildExpandedSidebar(ThemeState themeState) {
    final isDark = themeState.colorScheme.name == 'Dark';
    return Column(
      children: [
        // 헤더 (그라데이션 배경)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF2A2B37).withValues(alpha: 0.8),
                      const Color(0xFF1F2023).withValues(alpha: 0.9),
                    ]
                  : [
                      const Color(0xFFFAFAFA),
                      const Color(0xFFF0F0F0),
                    ],
            ),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.grey[800]!.withValues(alpha: 0.5)
                    : Colors.grey[300]!.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // 뒤로가기 버튼 (사이드바가 열려있을 때)
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey[800]!.withValues(alpha: 0.5)
                      : Colors.grey[100]!.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    size: 18,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onPressed: () => Navigator.pop(context),
                  tooltip: '뒤로가기',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.emoji_events_rounded,
                size: 18,
                color: const Color(0xFF14B8A6),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: isDark
                        ? [
                            Colors.white,
                            Colors.grey[300]!,
                          ]
                        : [
                            const Color(0xFF202123),
                            const Color(0xFF404040),
                          ],
                  ).createShader(bounds),
                  child: Text(
                    '사내AI 공모전',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 투표하기 버튼 (ChatGPT 스타일 + 그라데이션)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VotingScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                          const Color(0xFF6D4CFF).withValues(alpha: 0.2),
                        ]
                      : [
                          const Color(0xFF4A6CF7).withValues(alpha: 0.12),
                          const Color(0xFF6366F1).withValues(alpha: 0.08),
                        ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                      : const Color(0xFF4A6CF7).withValues(alpha: 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                        : const Color(0xFF4A6CF7).withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                const Color(0xFF8B5CF6),
                                const Color(0xFF6D4CFF),
                              ]
                            : [
                                const Color(0xFF4A6CF7),
                                const Color(0xFF6366F1),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.how_to_vote,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      '투표하기',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF202123),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 나의 제출 현황 버튼
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MySubmissionsScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF10B981).withValues(alpha: 0.25),
                          const Color(0xFF059669).withValues(alpha: 0.2),
                        ]
                      : [
                          const Color(0xFF34D399).withValues(alpha: 0.12),
                          const Color(0xFF10B981).withValues(alpha: 0.08),
                        ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF10B981).withValues(alpha: 0.4)
                      : const Color(0xFF10B981).withValues(alpha: 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFF10B981).withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                const Color(0xFF10B981),
                                const Color(0xFF059669),
                              ]
                            : [
                                const Color(0xFF34D399),
                                const Color(0xFF10B981),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.assignment_turned_in,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      '나의 제출 현황',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF202123),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 기타 메뉴
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _buildMenuItem(
                Icons.home,
                '홈으로',
                themeState,
                () => Navigator.pop(context),
              ),
              const SizedBox(height: 6),
              _buildMenuItem(
                Icons.info_outline,
                '공모전 안내',
                themeState,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ContestGuideScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String label,
    ThemeState themeState,
    VoidCallback onTap,
  ) {
    final isDark = themeState.colorScheme.name == 'Dark';
    return _MenuItemWidget(
      icon: icon,
      label: label,
      isDark: isDark,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);

    // 제출 여부 체크 중일 때 로딩 화면 표시
    if (_isCheckingSubmission) {
      return Scaffold(
        backgroundColor: themeState.colorScheme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: const Color(0xFF4A6CF7),
              ),
              const SizedBox(height: 16),
              Text(
                '정보를 불러오는 중...',
                style: TextStyle(
                  fontSize: 14,
                  color: themeState.colorScheme.name == 'Dark'
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: themeState.colorScheme.backgroundColor,
      body: Row(
        children: [
          // 사이드바 (항상 펼쳐진 상태)
          Container(
            width: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: themeState.colorScheme.name == 'Dark'
                    ? [
                        const Color(0xFF202123),
                        const Color(0xFF1A1B1F),
                        const Color(0xFF17181C),
                      ]
                    : [
                        const Color(0xFFFAFAFA),
                        const Color(0xFFF7F7F8),
                        const Color(0xFFF0F0F0),
                      ],
              ),
              border: Border(
                right: BorderSide(
                  color: themeState.colorScheme.name == 'Dark'
                      ? Colors.grey[800]!.withValues(alpha: 0.6)
                      : Colors.grey[300]!.withValues(alpha: 0.8),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: themeState.colorScheme.name == 'Dark'
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: _buildExpandedSidebar(themeState),
          ),

          // 메인 콘텐츠 영역 (신청서만 전체 화면)
          Expanded(
            child: ClipRect(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: themeState.colorScheme.name == 'Dark'
                            ? [
                                const Color(0xFF1F2023).withValues(alpha: 0.5),
                                themeState.colorScheme.backgroundColor,
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.8),
                                themeState.colorScheme.backgroundColor,
                              ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 380,
                            child: _buildChatPanel(themeState),
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            child: SingleChildScrollView(
                              child: _buildContestForm(themeState),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 로딩 오버레이 (블러 효과 + 로딩 인디케이터) - 신청서 영역에만 적용
                  if (_isFormLoading)
                    Positioned.fill(
                      child: ClipRRect(
                        child: AnimatedOpacity(
                          opacity: _isFormLoading ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            color: (themeState.colorScheme.name == 'Dark'
                                    ? Colors.black
                                    : Colors.white)
                                .withValues(alpha: 0.7),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      color: const Color(0xFF14B8A6),
                                      strokeWidth: 3,
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'AI가 초안 작성중입니다.\n잠시만 기다려주세요.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: themeState.colorScheme.name ==
                                                'Dark'
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
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

  Widget _buildChatPanel(ThemeState themeState) {
    final isDark = themeState.colorScheme.name == 'Dark';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1F2023),
                  const Color(0xFF0F1014),
                ]
              : [
                  Colors.white,
                  const Color(0xFFF5F5F5),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.grey.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.chat_bubble_rounded,
                  color: const Color(0xFF14B8A6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI 브레인스토밍',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '아이디어를 묻고 신청서에 바로 반영하세요',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.grey[50]!.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _chatMessages.isEmpty
                  ? _buildChatEmptyState(isDark)
                  : ListView.builder(
                      controller: _chatScrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 18,
                      ),
                      itemCount: _chatMessages.length,
                      itemBuilder: (context, index) {
                        final message = _chatMessages[index];
                        return _buildChatMessageBubble(message, themeState);
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedFiles.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0D9488).withValues(alpha: 0.15)
                    : const Color(0xFF14B8A6).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.attach_file,
                        size: 16,
                        color: const Color(0xFF14B8A6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedFiles.length}개의 이미지가 AI 분석에 함께 전송됩니다.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedFiles.length,
                      itemBuilder: (context, index) {
                        final fileInfo = _selectedFiles[index];
                        final fileBytes = fileInfo['data'] as Uint8List;

                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF14B8A6),
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.memory(
                                    fileBytes,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.grey[200],
                                        child: Icon(
                                          Icons.broken_image,
                                          color: isDark
                                              ? Colors.grey[600]
                                              : Colors.grey[400],
                                          size: 32,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -4,
                                right: -4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedFiles.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          _buildChatInput(themeState),
        ],
      ),
    );
  }

  Widget _buildChatInput(ThemeState themeState) {
    final isDark = themeState.colorScheme.name == 'Dark';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          // 첨부파일 버튼
          SizedBox(
            height: 38,
            width: 38,
            child: IconButton(
              onPressed: _pickFiles,
              icon: Icon(
                Icons.attach_file,
                size: 20,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              tooltip: '파일 첨부',
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: isDark
                    ? Colors.grey[800]!.withValues(alpha: 0.5)
                    : Colors.grey[100],
                shape: const CircleBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _chatInputController,
              focusNode: _chatFocusNode,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'AI에게 궁금한 점을 입력하세요',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (_) {
                if (!_isChatSending) {
                  _handleChatSend();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 38,
            width: 38,
            child: ElevatedButton(
              onPressed: _isChatSending ? null : _handleChatSend,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
                backgroundColor: const Color(0xFF14B8A6),
                disabledBackgroundColor: Colors.grey,
              ),
              child: _isChatSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      size: 18,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 42,
            color: const Color(0xFF14B8A6),
          ),
          const SizedBox(height: 12),
          Text(
            'AI에게 사례 아이디어를 물어보세요',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '업무 맥락, 기대효과 등을 입력하면\n신청서 작성을 도와드려요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessageBubble(
    _ContestChatMessage message,
    ThemeState themeState,
  ) {
    final isUser = message.role == _ContestChatRole.user;
    final isDark = themeState.colorScheme.name == 'Dark';
    final bubbleColor = message.isError
        ? Colors.red.withValues(alpha: isDark ? 0.4 : 0.15)
        : isUser
            ? const Color(0xFF14B8A6)
            : (isDark ? const Color(0xFF111217) : Colors.white);
    final borderColor = isUser
        ? Colors.transparent
        : (isDark ? Colors.grey[800]! : Colors.grey[200]!);
    final textColor = message.isError
        ? Colors.white
        : isUser
            ? Colors.white
            : (isDark ? Colors.white : Colors.black87);

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 60 : 0,
        right: isUser ? 0 : 60,
        bottom: 12,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft:
                  Radius.circular(isUser ? 16 : (message.isError ? 6 : 4)),
              bottomRight:
                  Radius.circular(isUser ? (message.isError ? 6 : 4) : 16),
            ),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                message.content,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatTimestamp(message.timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: message.isError
                      ? Colors.white70
                      : (isUser
                          ? Colors.white70
                          : (isDark ? Colors.grey[400] : Colors.grey[600])),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildContestForm(ThemeState themeState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 내 제출 현황 버튼
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF14B8A6),
                  Color(0xFF0D9488),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MySubmissionsScreen(),
                  ),
                );
              },
              icon: const Icon(
                Icons.assignment_outlined,
                size: 20,
                color: Colors.white,
              ),
              label: const Text(
                '내 제출 현황',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 커피 배너
        _buildCoffeeBanner(themeState),
        const SizedBox(height: 32),
        _buildSectionTitle('신청자 정보', themeState),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                '이름',
                '이름을 입력하세요',
                themeState,
                controller: _nameController,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDropdown(
                '부서',
                '부서를 선택하세요',
                themeState,
                value: _selectedDepartment,
                items: _departments,
                onChanged: (value) {
                  setState(() {
                    _selectedDepartment = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDropdown(
                '직급',
                '직급을 선택하세요',
                themeState,
                value: _selectedJobPosition,
                items: _jobPositions,
                onChanged: (value) {
                  setState(() {
                    _selectedJobPosition = value;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _buildSectionTitle('AI 활용 사례', themeState),
        const SizedBox(height: 16),
        _buildTextField(
          '1. 사용한 AI TOOL',
          '사용한 AI 도구를 입력하세요 (예: ChatGPT, Claude, Gemini 등)',
          themeState,
          controller: _toolNameController,
        ),
        const SizedBox(height: 16),
        _buildTextArea(
          '2. 어떤 업무에 적용 했나요?',
          '어떤 업무에 AI를 적용했는지 작성해주세요',
          themeState,
          controller: _workScopeController,
          maxLines: 12,
        ),
        const SizedBox(height: 16),
        _buildTextArea(
          '3. 어떤 방식으로 사용 했나요?',
          'AI를 어떤 방식으로 활용했는지 상세히 작성해주세요',
          themeState,
          controller: _workMethodController,
          maxLines: 12,
        ),
        const SizedBox(height: 16),
        _buildTextArea(
          '4. Before & After',
          'AI 활용 전후의 변화를 작성해주세요',
          themeState,
          controller: _beforeAfterController,
          maxLines: 12,
        ),
        const SizedBox(height: 32),
        _buildSectionTitle('첨부 파일', themeState),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: themeState.colorScheme.name == 'Dark'
                  ? [
                      Colors.grey[900]!.withValues(alpha: 0.3),
                      Colors.grey[800]!.withValues(alpha: 0.2),
                    ]
                  : [
                      Colors.grey[50]!,
                      Colors.white,
                    ],
            ),
            border: Border.all(
              color: themeState.colorScheme.name == 'Dark'
                  ? Colors.grey[700]!.withValues(alpha: 0.5)
                  : Colors.grey[300]!,
              width: 2,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: themeState.colorScheme.name == 'Dark'
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: (_selectedFiles.isEmpty && _chatAttachmentUrls.isEmpty)
              ? Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: themeState.colorScheme.name == 'Dark'
                            ? Colors.grey[800]!.withValues(alpha: 0.5)
                            : const Color(0xFF14B8A6).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cloud_upload_outlined,
                        size: 56,
                        color: themeState.colorScheme.name == 'Dark'
                            ? Colors.grey[400]
                            : const Color(0xFF14B8A6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '파일을 드래그하거나 클릭하여 업로드하세요',
                      style: TextStyle(
                        color: themeState.colorScheme.name == 'Dark'
                            ? Colors.grey[300]
                            : Colors.grey[700],
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.file_upload, size: 18),
                      label: const Text(
                        '파일 선택',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14B8A6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        // 로컬 파일 표시
                        ..._selectedFiles.asMap().entries.map((entry) {
                          final index = entry.key;
                          final fileInfo = entry.value;
                          final fileBytes = fileInfo['data'] as Uint8List;
                          return Stack(
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: themeState.colorScheme.name ==
                                                'Dark'
                                            ? Colors.grey[700]!
                                            : Colors.grey[300]!,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.memory(
                                        fileBytes,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            color:
                                                themeState.colorScheme.name ==
                                                        'Dark'
                                                    ? Colors.grey[800]
                                                    : Colors.grey[200],
                                            child: Icon(
                                              Icons.broken_image,
                                              color:
                                                  themeState.colorScheme.name ==
                                                          'Dark'
                                                      ? Colors.grey[600]
                                                      : Colors.grey[400],
                                              size: 40,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      fileInfo['filename'] as String? ??
                                          'image.jpg',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: themeState.colorScheme.name ==
                                                'Dark'
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedFiles.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              Colors.red.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                        // 채팅에서 받은 URL 파일 표시
                        ..._chatAttachmentUrls.asMap().entries.map((entry) {
                          final index = entry.key;
                          final attachment = entry.value;
                          final fileName =
                              attachment['file_name'] as String? ?? '파일명 없음';
                          final url = attachment['url'] as String? ?? '';

                          return Stack(
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF14B8A6),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF14B8A6)
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: url.isNotEmpty
                                          ? Image.network(
                                              url,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  color: themeState.colorScheme
                                                              .name ==
                                                          'Dark'
                                                      ? Colors.grey[800]
                                                      : Colors.grey[200],
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons.cloud_done,
                                                        color: const Color(
                                                            0xFF14B8A6),
                                                        size: 32,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'URL',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: const Color(
                                                              0xFF14B8A6),
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                              loadingBuilder: (context, child,
                                                  loadingProgress) {
                                                if (loadingProgress == null)
                                                  return child;
                                                return Container(
                                                  color: themeState.colorScheme
                                                              .name ==
                                                          'Dark'
                                                      ? Colors.grey[800]
                                                      : Colors.grey[200],
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                      value: loadingProgress
                                                                  .expectedTotalBytes !=
                                                              null
                                                          ? loadingProgress
                                                                  .cumulativeBytesLoaded /
                                                              loadingProgress
                                                                  .expectedTotalBytes!
                                                          : null,
                                                      color: const Color(
                                                          0xFF14B8A6),
                                                    ),
                                                  ),
                                                );
                                              },
                                            )
                                          : Container(
                                              color:
                                                  themeState.colorScheme.name ==
                                                          'Dark'
                                                      ? Colors.grey[800]
                                                      : Colors.grey[200],
                                              child: Icon(
                                                Icons.cloud_done,
                                                color: const Color(0xFF14B8A6),
                                                size: 40,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: 120,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.cloud,
                                          size: 12,
                                          color: const Color(0xFF14B8A6),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            fileName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: const Color(0xFF14B8A6),
                                              fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _chatAttachmentUrls.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              Colors.red.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.add_photo_alternate, size: 18),
                          label: const Text(
                            '추가 선택',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A6CF7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedFiles.clear();
                            });
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text(
                            '전체 삭제',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            side: const BorderSide(
                              color: Colors.red,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF14B8A6),
                Color(0xFF0D9488),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF14B8A6).withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: 0,
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () => _submitContestForm(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.send_rounded,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  '신청서 제출하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionTitle(String title, ThemeState themeState) {
    final isDark = themeState.colorScheme.name == 'Dark';
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF14B8A6),
                  Color(0xFF0D9488),
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    ThemeState themeState, {
    TextEditingController? controller,
  }) {
    final isDark = themeState.colorScheme.name == 'Dark';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                letterSpacing: -0.2,
              ),
            ),
          ),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF14B8A6),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.grey[900]!.withValues(alpha: 0.5)
                  : Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextArea(
    String label,
    String hint,
    ThemeState themeState, {
    TextEditingController? controller,
    int maxLines = 4,
  }) {
    final isDark = themeState.colorScheme.name == 'Dark';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                letterSpacing: -0.2,
              ),
            ),
          ),
          TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF14B8A6),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.grey[900]!.withValues(alpha: 0.5)
                  : Colors.white,
              contentPadding: const EdgeInsets.all(16),
            ),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String hint,
    ThemeState themeState, {
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final isDark = themeState.colorScheme.name == 'Dark';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                letterSpacing: -0.2,
              ),
            ),
          ),
          DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF14B8A6),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.grey[900]!.withValues(alpha: 0.5)
                  : Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 14,
            ),
            dropdownColor: isDark ? Colors.grey[900] : Colors.white,
            icon: Icon(
              Icons.arrow_drop_down,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            selectedItemBuilder: (BuildContext context) {
              return items.map<Widget>((String item) {
                return Text(
                  item,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                );
              }).toList();
            },
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// 커피 배너
  Widget _buildCoffeeBanner(ThemeState themeState) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF6B35), // 메가커피 오렌지
            Color(0xFFFF8F4D), // 밝은 오렌지
            Color(0xFFFFA566), // 더 밝은 오렌지
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          // 장식 원형 요소들 (배경 패턴)
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            right: 100,
            bottom: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          // 메인 컨텐츠
          Row(
            children: [
              // 메가커피 이미지
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                padding: const EdgeInsets.all(10),
                child: Image.asset(
                  'assets/images/megacoffee.png',
                  fit: BoxFit.contain,
                ),
              ),
              // 텍스트 영역
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 메시지
                      Flexible(
                        child: Text(
                          'AI 활용 사례 작성하고 메가커피 한잔 받아가세요!',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            height: 1.3,
                            shadows: [
                              Shadow(
                                color: Color(0x40000000),
                                offset: Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 커피 아이콘
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.local_cafe,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ],
      ),
    );
  }

  /// 커피 환영 팝업
  void _showCoffeeWelcomePopup() {
    final themeState = ref.read(themeProvider);
    final isDark = themeState.colorScheme.name == 'Dark';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF2D3748),
                      const Color(0xFF1A202C),
                    ]
                  : [
                      Colors.white,
                      const Color(0xFFF7FAFC),
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 메가커피 이미지
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/megacoffee.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              // 타이틀
              Text(
                '제출만 하셔도 커피 쿠폰을 드립니다!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A202C),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // 설명
              Text(
                'AI 활용 사례를 제출만 하셔도\n메가커피 쿠폰(2,000원)을 드립니다.\n제출 시 바로 수령 가능합니다.',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[300] : Colors.grey[600],
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // 확인 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItemWidget extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _MenuItemWidget({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_MenuItemWidget> createState() => _MenuItemWidgetState();
}

class _MenuItemWidgetState extends State<_MenuItemWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: _isHovered
                ? LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: widget.isDark
                        ? [
                            Colors.grey[800]!.withValues(alpha: 0.4),
                            Colors.grey[700]!.withValues(alpha: 0.3),
                          ]
                        : [
                            Colors.grey[100]!.withValues(alpha: 0.7),
                            Colors.grey[50]!.withValues(alpha: 0.5),
                          ],
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: _isHovered
                      ? LinearGradient(
                          colors: widget.isDark
                              ? [
                                  Colors.grey[700]!,
                                  Colors.grey[800]!,
                                ]
                              : [
                                  Colors.grey[300]!,
                                  Colors.grey[200]!,
                                ],
                        )
                      : null,
                  color: _isHovered
                      ? null
                      : (widget.isDark
                          ? Colors.grey[800]!.withValues(alpha: 0.5)
                          : Colors.grey[200]!.withValues(alpha: 0.6)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  widget.icon,
                  size: 14,
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: widget.isDark
                        ? Colors.grey[300]
                        : const Color(0xFF202123),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
