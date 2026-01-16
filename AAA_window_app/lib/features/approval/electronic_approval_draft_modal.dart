import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:webview_windows/webview_windows.dart';
import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

import '../../shared/providers/providers.dart';
import '../../shared/utils/common_ui_utils.dart';

/// 전자결재 상신 모달 (공통 필수영역 + 에디터)
class ElectronicApprovalDraftModal extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const ElectronicApprovalDraftModal({
    super.key,
    this.onClose,
  });

  @override
  ConsumerState<ElectronicApprovalDraftModal> createState() =>
      _ElectronicApprovalDraftModalState();
}

class _ElectronicApprovalDraftModalState
    extends ConsumerState<ElectronicApprovalDraftModal>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormBuilderState>();

  // 공통 필수영역 데이터
  String? _draftingDepartment;
  DateTime? _draftingDate;
  String? _drafter;
  String? _retentionPeriod;
  String? _selectedApprovalType;

  // 첨부파일
  List<Map<String, String>> _attachments = [];

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
  ];

  // 웹뷰 관련
  WebviewController? _webviewController;
  bool _isWebviewInitialized = false;
  bool _isWebviewLoading = true;
  String? _webviewError;
  StreamSubscription? _webMessageSubscription;
  bool _isWebviewFullscreen = false;
  Timer? _loadingTimeout;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // 슬라이드 애니메이션
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));

    _slideController.forward();

    // 초기값 설정
    _draftingDate = DateTime.now();
    _retentionPeriod = '영구';

    // 웹뷰 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWebview('http://210.107.96.193:3001/default');
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _webMessageSubscription?.cancel();
    _loadingTimeout?.cancel();
    _webviewController?.dispose();
    super.dispose();
  }

  /// 웹뷰 초기화
  Future<void> _initializeWebview(String webUrl) async {
    if (_isWebviewInitialized) return;

    // 기존 타임아웃 취소
    _loadingTimeout?.cancel();

    // 타임아웃 타이머 설정 (15초)
    _loadingTimeout = Timer(const Duration(seconds: 15), () {
      if (_isWebviewLoading && mounted) {
        print('⏱️ 웹뷰 로딩 타임아웃');
        setState(() {
          _isWebviewLoading = false;
          _webviewError = '웹뷰 로딩 시간 초과\n서버에 연결할 수 없습니다.';
        });
      }
    });

    try {
      print('🌐 웹뷰 초기화 시작: $webUrl');

      _webviewController = WebviewController();
      await _webviewController!.initialize();

      // 웹뷰 메시지 리스너
      _webMessageSubscription =
          _webviewController!.webMessage.listen((message) {
        _handleWebMessage(message);
      });

      // 로딩 상태 리스너
      _webviewController!.loadingState.listen((LoadingState state) {
        final bool isLoading = state == LoadingState.loading;

        if (mounted) {
          setState(() {
            _isWebviewLoading = isLoading;
          });
        }

        // 로딩 완료 시 타임아웃 취소 및 에디터 활성화
        if (!isLoading && mounted) {
          _loadingTimeout?.cancel();
          Future.delayed(const Duration(milliseconds: 800), () {
            _activateEditor();
          });
        }
      });

      // URL 로드
      await _webviewController!.loadUrl(webUrl);

      if (mounted) {
        setState(() {
          _isWebviewInitialized = true;
        });
      }

      print('✅ 웹뷰 초기화 완료');
    } catch (e) {
      print('❌ 웹뷰 초기화 실패: $e');
      _loadingTimeout?.cancel();
      if (mounted) {
        setState(() {
          _isWebviewLoading = false;
          _webviewError = '웹뷰 초기화 실패: $e';
        });
      }
    }
  }

  /// 에디터 활성화 (빈 공간 클릭 시 커서 생성)
  Future<void> _activateEditor() async {
    if (_webviewController == null) return;

    try {
      await _webviewController!.executeScript("""
        (function() {
          // 에디터 영역 찾기
          const editor = document.querySelector('[contenteditable="true"]')
                      || document.querySelector('.editor')
                      || document.querySelector('#editor')
                      || document.body;

          if (editor) {
            // contenteditable 설정
            editor.setAttribute('contenteditable', 'true');

            // 스타일 설정 (최소 높이 및 패딩)
            if (!editor.style.minHeight) {
              editor.style.minHeight = '100%';
              editor.style.padding = '20px';
              editor.style.outline = 'none';
            }

            // 자동 포커스
            editor.focus();

            console.log('✅ 에디터 활성화 완료');
          } else {
            console.log('⚠️ 에디터 영역을 찾을 수 없습니다');
          }
        })();
      """);

      print('✅ 에디터 활성화 스크립트 실행 완료');
    } catch (e) {
      print('❌ 에디터 활성화 실패: $e');
    }
  }

  /// 웹뷰 메시지 처리
  void _handleWebMessage(String message) {
    print('📨 메시지 수신: $message');

    try {
      final data = json.decode(message);

      if (data['action'] == 'saveDocument') {
        final htmlContent = data['content'] as String?;
        if (htmlContent != null) {
          _handleSave(htmlContent);
        }
      }
    } catch (e) {
      print('❌ 메시지 파싱 실패: $e');
    }
  }

  /// 문서 저장
  void _handleSave(String htmlContent) {
    print('💾 문서 저장: ${htmlContent.length} bytes');

    // TODO: 서버로 전송
    // await ApiService.saveApprovalDocument(htmlContent);

    _closeModal();
  }

  /// 모달 닫기
  void _closeModal() async {
    await _slideController.reverse();
    if (widget.onClose != null) {
      widget.onClose!();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final modalWidth = screenWidth * 0.7;

    return SlideTransition(
      position: _slideAnimation,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: modalWidth,
          height: double.infinity,
          decoration: BoxDecoration(
            color: isDarkTheme ? const Color(0xFF1A202C) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(-5, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // 헤더
              _buildHeader(isDarkTheme),

              // 스크롤 가능한 본문
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: FormBuilder(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 공통 필수영역
                        _buildSectionTitle('공통 필수영역', Icons.description),
                        const SizedBox(height: 16),
                        _buildCommonRequiredFields(),
                        const SizedBox(height: 24),

                        // 에디터 영역
                        _buildSectionTitle('결재 상세', Icons.assignment),
                        const SizedBox(height: 16),
                        _buildEditorArea(screenHeight, isDarkTheme),
                        const SizedBox(height: 24),

                        // 첨부파일 영역
                        _buildSectionTitle('첨부파일', Icons.attach_file),
                        const SizedBox(height: 16),
                        _buildAttachmentsField(),
                      ],
                    ),
                  ),
                ),
              ),

              // 푸터
              _buildFooter(isDarkTheme),
            ],
          ),
        ),
      ),
    );
  }

  /// 헤더
  Widget _buildHeader(bool isDarkTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
        border: Border(
          bottom: BorderSide(
            color:
                isDarkTheme ? const Color(0xFF4A5568) : const Color(0xFFE9ECEF),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.description_outlined,
            color: const Color(0xFF4A6CF7),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '전자결재 상신',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
              ),
            ),
          ),
          IconButton(
            onPressed: _closeModal,
            icon: Icon(
              Icons.close,
              color: isDarkTheme ? Colors.white70 : const Color(0xFF6C757D),
            ),
            tooltip: '닫기',
          ),
        ],
      ),
    );
  }

  /// 섹션 제목
  Widget _buildSectionTitle(String title, IconData icon) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF4A6CF7),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// 공통 필수영역 필드들
  Widget _buildCommonRequiredFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 1,
              child: FormBuilderDropdown<String>(
                name: 'draftingDepartment',
                decoration: _buildInputDecoration('기안부서', isRequired: true),
                initialValue: _draftingDepartment,
                items: _departments
                    .map((dept) => DropdownMenuItem(
                          value: dept,
                          child: Text(dept),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _draftingDepartment = value;
                  });
                },
                validator:
                    FormBuilderValidators.required(errorText: '기안부서를 선택해주세요'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: Consumer(
                builder: (context, ref, child) {
                  final currentUserId = ref.watch(userIdProvider) ?? 'Unknown';
                  return FormBuilderTextField(
                    name: 'drafter',
                    decoration: _buildInputDecoration('기안자', isRequired: true),
                    initialValue: _drafter ?? currentUserId,
                    readOnly: true,
                    style: const TextStyle(
                      color: Color(0xFF6C757D),
                      fontSize: 14,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _drafter = value;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: FormBuilderDateTimePicker(
                name: 'draftingDate',
                inputType: InputType.date,
                decoration: _buildInputDecoration('기안일', isRequired: true),
                initialValue: _draftingDate ?? DateTime.now(),
                validator:
                    FormBuilderValidators.required(errorText: '기안일은 필수입니다'),
                onChanged: (value) {
                  setState(() {
                    _draftingDate = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: FormBuilderDropdown<String>(
                name: 'retentionPeriod',
                decoration: _buildInputDecoration('보존년한', isRequired: true),
                initialValue: _retentionPeriod ?? '영구',
                validator:
                    FormBuilderValidators.required(errorText: '보존년한은 필수입니다'),
                items: [
                  '영구',
                  '5년',
                  '10년',
                  '15년',
                  '20년',
                ]
                    .map((period) => DropdownMenuItem(
                          value: period,
                          child: Text(period),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _retentionPeriod = value;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FormBuilderDropdown<String>(
          name: 'approvalType',
          decoration: _buildInputDecoration('결재 종류', isRequired: true),
          validator: FormBuilderValidators.required(errorText: '결재 종류는 필수입니다'),
          items: [
            '매출/매입계약 기안서',
            '기본양식',
            '구매신청서',
            '교육신청서',
            '경조사비 지급신청서',
            '휴가 부여 상신',
          ]
              .map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedApprovalType = value;
            });
          },
          initialValue: _selectedApprovalType,
        ),
      ],
    );
  }

  /// 에디터 영역 (화면 높이의 70%, 항상 /default URL 사용)
  Widget _buildEditorArea(double screenHeight, bool isDarkTheme) {
    final editorHeight = screenHeight * 0.7;

    // 전체보기 모드일 때는 안내 메시지 표시
    if (_isWebviewFullscreen) {
      return Container(
        height: editorHeight,
        decoration: BoxDecoration(
          color: isDarkTheme ? const Color(0xFF1A202C) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isDarkTheme ? const Color(0xFF4A5568) : const Color(0xFFE9ECEF),
          ),
        ),
        child: Center(
          child: Text(
            '전체보기 모드에서 편집 중...',
            style: TextStyle(
              color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Container(
          height: editorHeight,
          decoration: BoxDecoration(
            color: isDarkTheme ? const Color(0xFF1A202C) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDarkTheme
                  ? const Color(0xFF4A5568)
                  : const Color(0xFFE9ECEF),
            ),
          ),
          child: _webviewError != null
              ? _buildWebviewError(isDarkTheme)
              : Stack(
                  children: [
                    if (_webviewController != null && _isWebviewInitialized)
                      Positioned.fill(
                        child: FocusScope(
                          canRequestFocus: false,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapDown: (_) {
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                            onPanStart: (_) {
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Webview(_webviewController!),
                            ),
                          ),
                        ),
                      ),
                    if (_isWebviewLoading)
                      Positioned.fill(
                        child: Container(
                          color: isDarkTheme
                              ? const Color(0xFF1A202C)
                              : Colors.white,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF4A6CF7),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        // 전체보기 버튼
        Positioned(
          top: 12,
          right: 12,
          child: ElevatedButton.icon(
            onPressed: _showFullscreen,
            icon: const Icon(Icons.open_in_full, size: 16),
            label: const Text(
              '전체보기',
              style: TextStyle(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: const Color(0xFF4A6CF7),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 전체보기 모드
  void _showFullscreen() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // 전체보기 모드로 전환
    setState(() {
      _isWebviewFullscreen = true;
    });

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          child: SafeArea(
            child: Container(
              color: isDarkTheme ? const Color(0xFF0F172A) : Colors.white,
              child: Column(
                children: [
                  // 헤더
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.fullscreen, color: Color(0xFF4A6CF7)),
                        const SizedBox(width: 8),
                        Text(
                          '전자결재 상신 - 전체보기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkTheme ? Colors.white : Colors.black,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          color: isDarkTheme ? Colors.white : Colors.black,
                          tooltip: '닫기',
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDarkTheme
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFE5E7EB),
                  ),
                  // 웹뷰 영역
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkTheme
                              ? const Color(0xFF1A202C)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDarkTheme
                                ? const Color(0xFF4A5568)
                                : const Color(0xFFE9ECEF),
                          ),
                        ),
                        child:
                            _webviewController != null && _isWebviewInitialized
                                ? FocusScope(
                                    canRequestFocus: false,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTapDown: (_) {
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                      },
                                      onPanStart: (_) {
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Webview(_webviewController!),
                                      ),
                                    ),
                                  )
                                : const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF4A6CF7),
                                    ),
                                  ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      // Dialog가 닫힐 때 기본 모드로 복귀
      if (mounted) {
        setState(() {
          _isWebviewFullscreen = false;
        });
      }
    });
  }

  /// 웹뷰 에러 표시
  Widget _buildWebviewError(bool isDarkTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            '에디터 로드 실패',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _webviewError ?? '알 수 없는 오류',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDarkTheme ? Colors.white70 : const Color(0xFF6C757D),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _webviewError = null;
                _isWebviewInitialized = false;
                _isWebviewLoading = true;
              });
              _initializeWebview('http://210.107.96.193:3001/default');
            },
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A6CF7),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// 첨부파일 필드
  Widget _buildAttachmentsField() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor =
        isDarkTheme ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA);
    final borderColor =
        isDarkTheme ? const Color(0xFF4A5568) : const Color(0xFFE9ECEF);
    final textColor = isDarkTheme ? Colors.white : const Color(0xFF1A1D1F);
    final subtitleColor =
        isDarkTheme ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardColor = isDarkTheme ? const Color(0xFF1A202C) : Colors.white;
    final cardBorderColor =
        isDarkTheme ? const Color(0xFF4A5568) : const Color(0xFFE9ECEF);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Icon(Icons.attach_file, size: 16, color: textColor),
              const SizedBox(width: 8),
              Text(
                _attachments.isEmpty ? '첨부파일' : '첨부파일 ${_attachments.length}개',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const Spacer(),
              if (_attachments.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _attachments.clear();
                    });
                  },
                  child: const Text(
                    '모두 삭제',
                    style: TextStyle(fontSize: 12, color: Color(0xFF4A6CF7)),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _showAttachmentSelection,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('파일 추가'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A6CF7),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),

          // 파일 목록
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _attachments.asMap().entries.map((entry) {
                final index = entry.key;
                final attachment = entry.value;
                final isImage = _isImageFile(attachment['name'] ?? '');

                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cardBorderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDarkTheme ? 0.3 : 0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: isImage
                      ? _buildImageAttachment(attachment, index, isDarkTheme,
                          textColor, subtitleColor)
                      : _buildFileAttachment(attachment, index, isDarkTheme,
                          textColor, subtitleColor),
                );
              }).toList(),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                '파일을 추가하려면 위의 "파일 추가" 버튼을 클릭하세요',
                style: TextStyle(
                  fontSize: 12,
                  color: subtitleColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 파일이 이미지인지 확인
  bool _isImageFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }

  /// 파일 타입에 따른 아이콘 반환
  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  /// 이미지 첨부파일 위젯
  Widget _buildImageAttachment(
    Map<String, String> attachment,
    int index,
    bool isDarkTheme,
    Color textColor,
    Color subtitleColor,
  ) {
    return Stack(
      children: [
        SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isDarkTheme
                      ? const Color(0xFF374151)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkTheme
                        ? const Color(0xFF4B5563)
                        : const Color(0xFFD1D5DB),
                  ),
                ),
                child: Icon(
                  Icons.image,
                  size: 30,
                  color: isDarkTheme
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                attachment['name']!.length > 10
                    ? '${attachment['name']!.substring(0, 7)}...'
                    : attachment['name']!,
                style: TextStyle(fontSize: 10, color: textColor),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (attachment['size'] != null)
                Text(
                  attachment['size']!,
                  style: TextStyle(fontSize: 9, color: subtitleColor),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _attachments.removeAt(index);
              });
            },
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.red[400],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 일반 파일 첨부파일 위젯
  Widget _buildFileAttachment(
    Map<String, String> attachment,
    int index,
    bool isDarkTheme,
    Color textColor,
    Color subtitleColor,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _getFileIcon(attachment['name'] ?? ''),
          size: 20,
          color: const Color(0xFF4A6CF7),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              attachment['name']!.length > 15
                  ? '${attachment['name']!.substring(0, 12)}...'
                  : attachment['name']!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (attachment['size'] != null)
              Text(
                attachment['size']!,
                style: TextStyle(
                  fontSize: 10,
                  color: subtitleColor,
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            setState(() {
              _attachments.removeAt(index);
            });
          },
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDarkTheme
                  ? const Color(0xFF4B5563)
                  : const Color(0xFFE5E7EB),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.close,
              size: 12,
              color: isDarkTheme
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }

  /// 첨부파일 선택
  Future<void> _showAttachmentSelection() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        dialogTitle: '첨부파일 선택',
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (var file in result.files) {
            final isDuplicate = _attachments
                .any((attachment) => attachment['path'] == file.path);

            if (!isDuplicate && file.path != null) {
              String fileSize = _formatFileSize(file.size);

              _attachments.add({
                'name': file.name,
                'path': file.path!,
                'size': fileSize,
                'bytes': file.size.toString(),
              });

              print('✅ 첨부파일 추가: ${file.name} ($fileSize)');
            } else if (isDuplicate) {
              print('⚠️ 중복 파일 무시: ${file.name}');
            }
          }
        });

        if (mounted) {
          CommonUIUtils.showSuccessSnackBar(context, '${result.files.length}개 파일이 추가되었습니다.');
        }
      }
    } catch (e) {
      print('❌ 파일 선택 오류: $e');
      if (mounted) {
        CommonUIUtils.showErrorSnackBar(context, '파일 선택 중 오류가 발생했습니다: $e');
      }
    }
  }

  /// 파일 크기 포맷팅
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// 입력 필드 데코레이션
  InputDecoration _buildInputDecoration(String label,
      {bool isRequired = false}) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      labelText: isRequired ? '$label *' : label,
      labelStyle: TextStyle(
        color: isDarkTheme ? const Color(0xFFA0AEC0) : const Color(0xFF6C757D),
        fontSize: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color:
              isDarkTheme ? const Color(0xFF4A5568) : const Color(0xFFE9ECEF),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color:
              isDarkTheme ? const Color(0xFF4A5568) : const Color(0xFFE9ECEF),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF4A6CF7)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      filled: true,
      fillColor: isDarkTheme ? const Color(0xFF2D3748) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  /// 푸터
  Widget _buildFooter(bool isDarkTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
        border: Border(
          top: BorderSide(
            color:
                isDarkTheme ? const Color(0xFF4A5568) : const Color(0xFFE9ECEF),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _closeModal,
            style: OutlinedButton.styleFrom(
              foregroundColor: isDarkTheme ? Colors.white70 : Colors.black87,
              side: BorderSide(
                color: isDarkTheme
                    ? const Color(0xFF4A5568)
                    : const Color(0xFFE9ECEF),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('취소'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState?.saveAndValidate() ?? false) {
                // 웹뷰에 저장 요청
                _webviewController?.executeScript("""
                  if (window.requestSave) {
                    window.requestSave();
                  }
                """);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A6CF7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              '상신',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
