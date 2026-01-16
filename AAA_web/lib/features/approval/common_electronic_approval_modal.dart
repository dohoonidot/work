import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

import '../../shared/providers/providers.dart';
import '../../shared/services/api_service.dart';
import '../../core/config/feature_config.dart';
import 'package:webview_windows/webview_windows.dart';
import 'html_test_provider.dart';
import 'editable_html_table_renderer.dart';
import '../../shared/providers/chat_notifier.dart';
import '../../shared/services/leave_api_service.dart';
import '../leave/leave_models.dart';
import '../../models/leave_management_models.dart';
import '../leave/approver_selection_modal.dart';

/// 공통 전자결재 모달 (공통 필수영역 + 승인자/참조자)
class CommonElectronicApprovalModal extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  final String? initialApprovalType;

  const CommonElectronicApprovalModal({
    super.key,
    this.onClose,
    this.initialApprovalType,
  });

  @override
  ConsumerState<CommonElectronicApprovalModal> createState() =>
      _CommonElectronicApprovalModalState();
}

class _CommonElectronicApprovalModalState
    extends ConsumerState<CommonElectronicApprovalModal>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormBuilderState>();
  Map<String, String?> _fieldErrors = {};
  bool _isSubmitting = false;

  // 폼 키를 동적으로 변경하여 위젯 재빌드
  int _formKeyCounter = 0;

  // 폼 데이터
  String? _selectedApprovalType;
  String? _title;
  String? _content;
  String? _urgencyLevel;
  DateTime? _requestDate;
  DateTime? _expectedCompletionDate;
  String? _budget;
  List<String> _selectedApproverIds = []; // 선택된 승인자 ID 리스트
  List<CcPerson> _ccList = []; // String에서 CcPerson으로 변경
  List<Map<String, String>> _attachments = []; // 모달에서 직접 첨부한 파일
  List<Map<String, String>> _chatAttachments =
      []; // 채팅에서 트리거 시 전달된 첨부파일 (URL 포함)

  // 결재선 데이터 구조 (단계별)
  List<Map<String, dynamic>> _approvalLine = [];

  // 공통 필수영역 데이터
  String? _draftingDepartment;
  DateTime? _draftingDate;
  String? _drafter;
  String? _retentionPeriod;
  String? _referencePersons;
  String? _documentTitle;
  bool _isCustomDepartment = false; // 직접입력 모드 여부

  // 부서 목록 (API에서 로드)
  List<String> _departmentsFromApi = [];
  bool _isLoadingDepartments = false;

  // 채팅 트리거 초기화 완료 플래그 (중복 초기화 방지)
  bool _isLeaveGrantInitialized = false;

  // 결재 상세 데이터 (양식별로 다름)
  Map<String, dynamic> _approvalDetailData = {};

  // 서버에서 받은 HTML 콘텐츠 (기본양식용)
  String? _serverHtmlContent;
  bool _isLoadingHtmlContent = false;

  // 휴가 부여 상신 관련 변수들
  bool _isLoadingLeaveGrantData = false;

  // 매출/매입계약 기안서 웹뷰 관련 (데이터 연동을 위해 상위에서 관리)
  WebviewController? _contractWebviewController;
  bool _isContractWebviewFullscreen = false;
  bool _isContractWebviewInitialized = false;
  bool _isContractWebviewLoading = true;
  String? _contractWebviewError;
  String? _contractCurrentAllowedUrl;
  StreamSubscription<String>? _contractUrlSubscription;
  String? _lastLoadedWebviewUrl; // 마지막으로 로드된 웹뷰 URL 추적

  // AI 시나리오 관련 변수
  bool _isAiGeneratedHtml = false;
  String? _aiGeneratedHtmlContent;
  StreamSubscription? _webMessageSubscription;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _selectedApprovalType = widget.initialApprovalType;

    // 슬라이드 애니메이션 컨트롤러 초기화
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

    // 모달이 빌드된 후 pending 데이터 확인 및 저장된 결재라인 불러오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 기안자 초기화 - readOnly 필드이므로 여기서 직접 설정
      final currentUserId = ref.read(userIdProvider);
      if (currentUserId != null && _drafter == null) {
        setState(() {
          _drafter = currentUserId;
        });
      }
      _checkPendingLeaveGrantData();
      _loadSavedApprovalLine();
      _loadDepartmentList();
    });
  }

  /// Pending 휴가 부여 상신 데이터 확인 및 자동 초기화
  void _checkPendingLeaveGrantData() {
    // 휴가 부여 상신 데이터 확인
    final pendingLeaveData = ChatNotifier.getPendingLeaveGrantData();
    if (pendingLeaveData != null) {
      print(
          '🏢 CommonElectronicApprovalModal: Pending 휴가 부여 상신 데이터 발견, 자동 초기화 시작');
      initializeWithLeaveGrantData(pendingLeaveData);
      return;
    }

    // 기본양식 데이터 확인
    final pendingBasicData = ChatNotifier.getPendingBasicApprovalData();
    if (pendingBasicData != null) {
      print('🏢 CommonElectronicApprovalModal: Pending 기본양식 데이터 발견, 자동 초기화 시작');
      initializeWithBasicApprovalData(pendingBasicData);
      return;
    }

    // 매출/매입 계약 기안서 데이터 확인
    final pendingContractData = ChatNotifier.getPendingContractApprovalData();
    if (pendingContractData != null) {
      print(
          '🏢 CommonElectronicApprovalModal: Pending 매출/매입 계약 기안서 데이터 발견, 자동 초기화 시작');
      initializeWithContractApprovalData(pendingContractData);
      return;
    }
  }

  /// 기안부서 목록 API 호출
  Future<void> _loadDepartmentList() async {
    setState(() {
      _isLoadingDepartments = true;
    });

    try {
      final departments = await ApiService.getDepartmentList();
      if (mounted) {
        setState(() {
          _departmentsFromApi = departments;
          _isLoadingDepartments = false;
        });
      }
      print('✅ 부서 목록 로딩 완료: ${departments.length}개');
    } catch (e) {
      print('❌ 부서 목록 로딩 실패: $e');
      if (mounted) {
        setState(() {
          _isLoadingDepartments = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    // 매출/매입계약 웹뷰 정리
    _contractUrlSubscription?.cancel();
    _webMessageSubscription?.cancel();
    _contractWebviewController?.dispose();
    super.dispose();
  }

  /// 매출/매입계약 웹뷰 초기화
  Future<void> _initializeContractWebview(
      String webUrl, List<String>? allowedUrlPatterns) async {
    // 이미 초기화되었으면 중복 실행 방지
    if (_isContractWebviewInitialized) {
      return;
    }

    print('🌐 웹뷰 초기화 시작: $webUrl');

    try {
      _contractWebviewController = WebviewController();
      await _contractWebviewController!.initialize();

      _contractCurrentAllowedUrl = webUrl;

      // URL 변경 감지 및 제한
      _contractUrlSubscription = _contractWebviewController!.url.listen((url) {
        if (url.isNotEmpty) {
          bool isAllowed = true;
          if (allowedUrlPatterns != null && allowedUrlPatterns.isNotEmpty) {
            isAllowed =
                allowedUrlPatterns.any((pattern) => url.contains(pattern));
          }

          if (!isAllowed) {
            print('🚫 허용되지 않은 URL로 이동 시도 차단: $url');
            _contractWebviewController!.loadUrl(_contractCurrentAllowedUrl!);
          } else {
            _contractCurrentAllowedUrl = url;
            print('✅ 허용된 URL: $url');
          }
        }
      });

      // 웹뷰 메시지 리스너 등록 (Flutter ← JavaScript 통신)
      _webMessageSubscription =
          _contractWebviewController!.webMessage.listen((message) {
        _handleWebMessage(message);
      });

      _contractWebviewController!.loadingState.listen((LoadingState state) {
        final bool isLoading = state == LoadingState.loading;

        if (mounted) {
          setState(() {
            _isContractWebviewLoading = isLoading;
          });
        }

        // 로딩 완료 시 AI 생성 HTML 주입 (시나리오 1)
        // LoadingState가 loading이 아니면 완료된 것으로 간주
        if (!isLoading &&
            _isAiGeneratedHtml &&
            _aiGeneratedHtmlContent != null &&
            _contractWebviewController != null) {
          // 짧은 지연 후 HTML 주입 (DOM이 완전히 로드될 때까지 대기)
          Future.delayed(const Duration(milliseconds: 500), () {
            _injectAiGeneratedHtml(_aiGeneratedHtmlContent!);
          });
        }
      });

      await _contractWebviewController!.loadUrl(webUrl);

      if (mounted) {
        setState(() {
          _isContractWebviewInitialized = true;
          _lastLoadedWebviewUrl = webUrl; // 로드된 URL 추적
        });
      }

      print('✅ 웹뷰 초기화 완료: $webUrl');
    } catch (e) {
      print('❌ 웹뷰 초기화 실패: $e');
      if (mounted) {
        setState(() {
          _isContractWebviewLoading = false;
          _contractWebviewError = '웹뷰 초기화 실패: $e';
        });
      }
    }
  }

  /// AI 생성 HTML 주입 (시나리오 1)
  Future<void> _injectAiGeneratedHtml(String htmlContent) async {
    if (_contractWebviewController == null) return;

    try {
      print('🎨 AI 생성 HTML 주입 시작...');

      // HTML 이스케이프 처리 (백틱, 개행 등)
      final escapedHtml = htmlContent
          .replaceAll('\\', '\\\\') // 백슬래시 이스케이프
          .replaceAll('`', '\\`') // 백틱 이스케이프
          .replaceAll('\n', '\\n') // 개행 이스케이프
          .replaceAll('\r', '\\r'); // 캐리지 리턴 이스케이프

      // JavaScript로 HTML 주입
      await _contractWebviewController!.executeScript("""
        (function() {
          try {
            if (typeof window.setEditorContent === 'function') {
              window.setEditorContent(`$escapedHtml`);
              console.log('✅ HTML 콘텐츠 주입 완료');
              return true;
            } else {
              console.error('❌ window.setEditorContent 함수가 정의되지 않았습니다.');
              return false;
            }
          } catch (error) {
            console.error('❌ HTML 주입 중 오류:', error);
            return false;
          }
        })();
      """);

      print('✅ AI 생성 HTML 주입 완료');
    } catch (e) {
      print('❌ HTML 주입 실패: $e');
      if (mounted) {
        setState(() {
          _contractWebviewError = 'HTML 주입 실패: $e';
        });
      }
    }
  }

  /// 웹뷰 메시지 처리 (JavaScript → Flutter 통신)
  void _handleWebMessage(String message) {
    print('📨 웹뷰 메시지 수신: $message');

    try {
      final data = json.decode(message);

      if (data['action'] == 'saveDocument') {
        final htmlContent = data['content'] as String?;
        if (htmlContent != null) {
          _handleDocumentSave(htmlContent);
        }
      } else if (data['action'] == 'getDocumentData') {
        _handleGetDocumentData();
      }
    } catch (e) {
      print('❌ 웹뷰 메시지 파싱 실패: $e');
    }
  }

  /// 문서 저장 처리
  void _handleDocumentSave(String htmlContent) {
    print('💾 문서 저장 요청: ${htmlContent.length} bytes');

    // 저장된 HTML을 상태에 저장
    setState(() {
      _serverHtmlContent = htmlContent;
    });

    // TODO: 서버로 전송하거나 로컬에 저장
    // 예: await ApiService.saveApprovalDocument(htmlContent);

    // 성공 메시지를 웹뷰로 전송
    _sendMessageToWebView({'status': 'success', 'message': '저장되었습니다.'});
  }

  /// 문서 데이터 요청 처리
  void _handleGetDocumentData() {
    print('📄 문서 데이터 요청');

    // 현재 폼 데이터를 웹뷰로 전송
    final documentData = {
      'title': _title,
      'content': _content,
      'drafter': _drafter,
      'department': _draftingDepartment,
      'approvalType': _selectedApprovalType,
    };

    _sendMessageToWebView({'action': 'documentData', 'data': documentData});
  }

  /// Flutter → JavaScript 메시지 전송
  Future<void> _sendMessageToWebView(Map<String, dynamic> data) async {
    if (_contractWebviewController == null) return;

    try {
      final jsonData = json.encode(data);
      await _contractWebviewController!.executeScript("""
        if (window.handleFlutterMessage) {
          window.handleFlutterMessage($jsonData);
        }
      """);
    } catch (e) {
      print('❌ 메시지 전송 실패: $e');
    }
  }

  /// 웹뷰 리셋 (양식 전환 시)
  void _resetWebview() {
    print('🔄 웹뷰 리셋 시작...');

    // 구독 취소
    _contractUrlSubscription?.cancel();
    _webMessageSubscription?.cancel();

    // 컨트롤러 정리
    _contractWebviewController?.dispose();

    // 상태 초기화
    setState(() {
      _contractWebviewController = null;
      _isContractWebviewInitialized = false;
      _isContractWebviewLoading = true;
      _contractWebviewError = null;
      _contractCurrentAllowedUrl = null;
    });

    print('✅ 웹뷰 리셋 완료');
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: 450,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1A1D1F)
              : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(-2, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildFormContent()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  /// 헤더
  Widget _buildHeader() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: isDarkTheme
                  ? const Color(0xFF2D3748)
                  : const Color(0xFFE9ECEF)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.description_outlined,
            color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '전자결재 상신',
              style: TextStyle(
                color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: _closeModal,
            icon: Icon(
              Icons.close,
              color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
            ),
          ),
        ],
      ),
    );
  }

  /// 폼 콘텐츠
  Widget _buildFormContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: FormBuilder(
        key: Key('form_$_formKeyCounter'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 로딩 상태 표시 (공통 필수영역 위에 표시)
            if (_isLoadingLeaveGrantData) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A6CF7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4A6CF7).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF4A6CF7)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '휴가 부여 상신 데이터를 불러오는 중입니다...',
                      style: TextStyle(
                        color: Color(0xFF4A6CF7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            _buildSectionTitle('공통 필수영역', Icons.description),
            const SizedBox(height: 16),
            _buildCommonRequiredFields(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('승인자', Icons.how_to_reg_rounded),
                      const SizedBox(height: 12),
                      _buildApproversField(),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('참조자', Icons.person_add_outlined),
                      const SizedBox(height: 12),
                      _buildReferenceField(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('결재 상세', Icons.assignment),
            const SizedBox(height: 16),
            _buildApprovalDetailFields(),
            const SizedBox(height: 24),
            _buildSectionTitle('첨부파일', Icons.attach_file),
            const SizedBox(height: 16),
            _buildAttachmentsField(),
          ],
        ),
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
          color:
              isDarkTheme ? const Color(0xFF4A6CF7) : const Color(0xFF4A6CF7),
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
              child: _isLoadingDepartments
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : _isCustomDepartment
                      ? FormBuilderTextField(
                          name: 'draftingDepartment',
                          decoration: InputDecoration(
                            labelText: '기안부서 *',
                            hintText: '부서명을 입력하세요',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _isCustomDepartment = false;
                                  _draftingDepartment = null;
                                });
                              },
                              tooltip: '드롭다운으로 돌아가기',
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          initialValue: _draftingDepartment,
                          onChanged: (value) {
                            setState(() {
                              _draftingDepartment = value;
                              // 입력한 값이 드롭다운 리스트에 있으면 자동으로 드롭다운 모드로 전환
                              if (value != null &&
                                  value.isNotEmpty &&
                                  _departmentsFromApi.contains(value)) {
                                _isCustomDepartment = false;
                              }
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '기안부서를 입력해주세요';
                            }
                            return null;
                          },
                        )
                      : FormBuilderDropdown<String>(
                          name: 'draftingDepartment',
                          decoration:
                              _buildInputDecoration('기안부서', isRequired: true),
                          initialValue: _draftingDepartment != null &&
                                  _departmentsFromApi
                                      .contains(_draftingDepartment)
                              ? _draftingDepartment
                              : null,
                          items: [
                            ..._departmentsFromApi
                                .map((dept) => DropdownMenuItem(
                                      value: dept,
                                      child: Text(dept),
                                    ))
                                .toList(),
                            const DropdownMenuItem(
                              value: '__CUSTOM__',
                              child: Row(
                                children: [
                                  Icon(Icons.edit,
                                      size: 16, color: Color(0xFF1E88E5)),
                                  SizedBox(width: 8),
                                  Text('직접입력'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              if (value == '__CUSTOM__') {
                                _isCustomDepartment = true;
                                _draftingDepartment = '';
                              } else {
                                _draftingDepartment = value;
                                _isCustomDepartment = false;
                              }
                            });
                          },
                          validator: FormBuilderValidators.required(
                              errorText: '기안부서를 선택해주세요'),
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
          items: (FeatureConfig.showAllApprovalTypes
                  ? [
                      '매출/매입계약 기안서',
                      '기본양식',
                      '구매신청서',
                      '교육신청서',
                      '경조사비 지급신청서',
                      '휴가 부여 상신',
                    ]
                  : ['휴가 부여 상신'])
              .map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedApprovalType = value;
              // 결재종류 선택 시 하단 제목에 자동 입력
              _documentTitle = value;
              _title = value; // _title도 함께 업데이트

              // 웹뷰 사용 양식인 경우 URL 변경 확인
              if (value == '매출/매입계약 기안서' || value == '구매신청서') {
                // AI 모드 해제
                _isAiGeneratedHtml = false;
                _aiGeneratedHtmlContent = null;

                // 새로운 URL 계산
                String newUrl = value == '매출/매입계약 기안서'
                    ? 'http://210.107.96.193:3001/contract'
                    : 'http://210.107.96.193:3001/purchase';

                // 웹뷰가 초기화되지 않았거나 URL이 변경된 경우 리셋 후 재초기화
                if (!_isContractWebviewInitialized ||
                    _lastLoadedWebviewUrl != newUrl) {
                  print('🔄 URL 변경 감지: $_lastLoadedWebviewUrl → $newUrl');

                  // 웹뷰 리셋
                  _resetWebview();

                  // 새 URL 저장
                  _lastLoadedWebviewUrl = newUrl;

                  // 프레임 후처리로 초기화 (리셋 완료 후)
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _initializeContractWebview(
                        newUrl,
                        [
                          '210.107.96.193:3001',
                          '/default',
                          '/contract',
                          '/purchase',
                          '/',
                        ],
                      );
                    }
                  });
                }
              } else {
                // 웹뷰를 사용하지 않는 양식으로 변경 시 웹뷰 리셋
                if (_contractWebviewController != null) {
                  print('🔄 웹뷰를 사용하지 않는 양식으로 변경, 웹뷰 리셋');
                  _resetWebview();
                  _lastLoadedWebviewUrl = null;
                }
              }
            });
          },
          initialValue: _selectedApprovalType,
        ),
      ],
    );
  }

  /// 결재 상세 필드들 (하위 클래스에서 구현)
  Widget _buildApprovalDetailFields() {
    // 결재 종류에 따라 다른 상세 위젯 반환
    switch (_selectedApprovalType) {
      case '매출/매입계약 기안서':
        // 시나리오 1: AI 생성 HTML인 경우 /default 라우트 사용
        // 시나리오 2: 수동 선택인 경우 /contract 라우트 사용
        final webUrl = _isAiGeneratedHtml
            ? 'http://210.107.96.193:3001/default'
            : 'http://210.107.96.193:3001/contract';

        return _buildApprovalDetailWebView(
          webUrl: webUrl,
          // 허용된 URL 패턴: 이 패턴에 포함된 URL만 접근 가능
          allowedUrlPatterns: [
            '210.107.96.193:3001', // 도메인 허용
            '/default', // AI 생성 HTML용 빈 에디터
            '/contract', // 매출/매입계약 템플릿
            '/', // 루트 경로
          ],
        );

      case '구매신청서':
        // 시나리오 1: AI 생성 HTML인 경우 /default 라우트 사용
        // 시나리오 2: 수동 선택인 경우 /purchase 라우트 사용
        final webUrl = _isAiGeneratedHtml
            ? 'http://210.107.96.193:3001/default'
            : 'http://210.107.96.193:3001/purchase';

        return _buildApprovalDetailWebView(
          webUrl: webUrl,
          allowedUrlPatterns: [
            '210.107.96.193:3001',
            '/default',
            '/purchase', // 구매신청서 템플릿
            '/',
          ],
        );

      case '기본양식':
        return _buildBasicApprovalDetail();
      case '교육신청서':
        return _buildEducationApprovalDetail();
      case '경조사비 지급신청서':
        return _buildEventApprovalDetail();
      case '휴가 부여 상신':
        return _buildLeaveGrantApprovalDetail();
      default:
        return _buildDefaultDetail();
    }
  }

  /// 기본 상세 위젯 (결재 종류 선택 전)
  Widget _buildDefaultDetail() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isDarkTheme ? const Color(0xFF4A5568) : const Color(0xFFE9ECEF),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 48,
            color:
                isDarkTheme ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
          const SizedBox(height: 16),
          Text(
            '결재 종류를 선택해주세요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '위에서 결재 종류를 선택하면\n해당 양식의 상세 입력 화면이 나타납니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDarkTheme
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  /// 결재 상세 영역을 웹뷰로 표시하는 위젯
  ///
  /// 이 영역은 서버에서 제공하는 웹 페이지를 웹뷰로 표시합니다.
  /// URL은 결재 종류에 따라 동적으로 결정됩니다.
  ///
  /// [webUrl]: 웹뷰에 표시할 URL
  /// [allowedUrlPatterns]: 허용된 URL 패턴 목록. 이 패턴에 맞는 URL만 로드됩니다.
  Widget _buildApprovalDetailWebView({
    String? webUrl,
    List<String>? allowedUrlPatterns,
  }) {
    // 웹뷰 URL이 제공되지 않은 경우 기본 메시지 표시
    if (webUrl == null || webUrl.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2D3748)
              : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF4A5568)
                : const Color(0xFFE9ECEF),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.web_outlined,
              size: 48,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF6B7280),
            ),
            const SizedBox(height: 16),
            Text(
              '결재 상세 영역',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF1A1D1F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '웹뷰 URL이 설정되지 않았습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    // ✨ 웹뷰 초기화는 드롭다운의 onChanged에서만 수행됩니다.
    // build() 중에는 초기화를 시도하지 않습니다 (중복 초기화 방지)

    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // 전체보기 모드일 때는 빈 컨테이너 (컨트롤러가 Dialog에서 사용 중)
    if (_isContractWebviewFullscreen) {
      return Container(
        height: 600,
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

    // 웹뷰 + 전체보기 버튼 제공
    return FocusScope(
      canRequestFocus: false,
      child: Stack(
        children: [
          // 상위에서 관리하는 웹뷰 컨트롤러 사용
          Container(
            height: 600,
            decoration: BoxDecoration(
              color: isDarkTheme ? const Color(0xFF1A202C) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDarkTheme
                    ? const Color(0xFF4A5568)
                    : const Color(0xFFE9ECEF),
              ),
            ),
            child: _contractWebviewError != null
                ? _buildContractWebviewError(isDarkTheme)
                : Stack(
                    children: [
                      // 컨트롤러가 null이 아니고 완전히 초기화된 경우에만 웹뷰 렌더링
                      if (_contractWebviewController != null &&
                          _isContractWebviewInitialized)
                        Positioned.fill(
                          key: ValueKey(webUrl), // URL 변경 시 위젯 재생성
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapDown: (_) {
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                            onPanStart: (_) {
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                            child: Webview(_contractWebviewController!),
                          ),
                        ),
                      if (_isContractWebviewLoading)
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
          Positioned(
            top: 12,
            right: 12,
            child: ElevatedButton.icon(
              onPressed: () =>
                  _showApprovalDetailFullscreen(webUrl, allowedUrlPatterns),
              icon: const Icon(Icons.open_in_full, size: 16),
              label: const Text(
                '전체보기',
                style: TextStyle(fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      ),
    );
  }

  /// 웹뷰 에러 표시 위젯
  Widget _buildContractWebviewError(bool isDarkTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            _contractWebviewError ?? '알 수 없는 오류',
            style: TextStyle(
              color: isDarkTheme ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  /// 결재 상세 웹뷰 전체 화면으로 표시
  void _showApprovalDetailFullscreen(
    String webUrl,
    List<String>? allowedUrlPatterns,
  ) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // 전체보기 모드로 전환
    setState(() {
      _isContractWebviewFullscreen = true;
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
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.fullscreen, color: Color(0xFF4A6CF7)),
                        const SizedBox(width: 8),
                        Text(
                          '매출/매입계약 기안서 - 전체보기',
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
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      // 상위에서 관리하는 웹뷰 컨트롤러 사용 (데이터 연동)
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
                        child: _contractWebviewController != null &&
                                _isContractWebviewInitialized
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
                                  child: Webview(_contractWebviewController!),
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
          _isContractWebviewFullscreen = false;
        });
      }
    });
  }

  /// 기본양식 상세 위젯 - 서버 HTML 렌더링 지원
  Widget _buildBasicApprovalDetail() {
    return Consumer(
      builder: (context, ref, child) {
        final htmlTestState = ref.watch(htmlTestProvider);

        // 테스트 프로바이더의 HTML이 있으면 우선 사용, 없으면 기존 로컬 HTML 사용
        final effectiveHtmlContent =
            htmlTestState.htmlContent ?? _serverHtmlContent;
        final effectiveIsLoading =
            htmlTestState.isLoading || _isLoadingHtmlContent;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2D3748)
                : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목 입력 필드 추가
              FormBuilderTextField(
                name: 'documentTitle',
                decoration: _buildInputDecoration('제목', isRequired: true),
                initialValue: _documentTitle,
                validator:
                    FormBuilderValidators.required(errorText: '제목은 필수입니다'),
                onChanged: (value) {
                  setState(() {
                    _documentTitle = value;
                    _title = value; // _title도 함께 업데이트
                  });
                },
              ),
              const SizedBox(height: 16),

              // HTML 콘텐츠가 있는 경우 렌더링, 없는 경우 기본 텍스트 필드
              if (effectiveHtmlContent != null &&
                  effectiveHtmlContent.isNotEmpty) ...[
                // HTML 콘텐츠 렌더링 영역
                Row(
                  children: [
                    Text(
                      '내용 *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFA0AEC0)
                            : const Color(0xFF8B95A1),
                      ),
                    ),
                    const Spacer(),
                    // HTML 소스 표시 (테스트 프로바이더 데이터인 경우)
                    if (htmlTestState.htmlContent != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A6CF7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.science,
                              size: 12,
                              color: const Color(0xFF4A6CF7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'AppBar 테스트 데이터',
                              style: TextStyle(
                                fontSize: 10,
                                color: const Color(0xFF4A6CF7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // 동적 크기 조절 HTML 렌더링 영역
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: 300,
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: EditableHtmlTableRenderer(
                    htmlContent: effectiveHtmlContent,
                    isLoading: effectiveIsLoading,
                    minHeight: 300, // 최소 높이 감소
                    onContentChanged: (newContent) {
                      setState(() {
                        _serverHtmlContent = newContent;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // 테스트 데이터 지우기 버튼 (테스트 프로바이더 데이터가 있는 경우)
                if (htmlTestState.htmlContent != null)
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          // 프로바이더의 HTML 콘텐츠 삭제
                          ref
                              .read(htmlTestProvider.notifier)
                              .clearHtmlContent();

                          // 로컬 서버 HTML 콘텐츠도 함께 삭제하여 완전히 빈 상태로 복원
                          setState(() {
                            _serverHtmlContent = null;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('테스트 HTML 데이터가 삭제되었습니다'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('테스트 데이터 지우기',
                            style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFDC3545),
                        ),
                      ),
                    ],
                  ),
              ] else ...[
                // 기본 텍스트 입력 필드 (HTML이 없는 경우)
                FormBuilderTextField(
                  name: 'basicContent',
                  decoration: _buildInputDecoration('내용', isRequired: true),
                  maxLines: 8,
                  validator:
                      FormBuilderValidators.required(errorText: '내용은 필수입니다'),
                  onChanged: (value) {
                    setState(() {
                      _content = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // HTML 콘텐츠 가져오기 버튼 (개발/테스트용)
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed:
                          effectiveIsLoading ? null : _loadSampleHtmlContent,
                      icon: effectiveIsLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download, size: 16),
                      label: Text(
                        effectiveIsLoading ? '로딩중...' : '서버 템플릿 불러오기',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A6CF7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_serverHtmlContent != null)
                      TextButton.icon(
                        onPressed: _clearHtmlContent,
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('HTML 지우기',
                            style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF6B7280),
                        ),
                      ),
                    const SizedBox(width: 8),
                    // AppBar HTML 테스트 버튼 안내
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF17A2B8).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'AppBar의 HTML 테스트 버튼을 사용해보세요',
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF17A2B8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 교육신청서 상세 위젯 (TODO: 별도 파일로 분리 예정)
  Widget _buildEducationApprovalDetail() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D3748)
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text('교육신청서 상세 (추후 구현)'),
    );
  }

  /// 경조사비 지급신청서 상세 위젯 (TODO: 별도 파일로 분리 예정)
  Widget _buildEventApprovalDetail() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D3748)
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text('경조사비 지급신청서 상세 (추후 구현)'),
    );
  }

  /// 유효한 휴가 종류 반환 (items 리스트에 있는 값만 반환)
  String? _getValidLeaveType() {
    final leaveType = _approvalDetailData['leave_type']?.toString();
    if (leaveType == null || leaveType.isEmpty) {
      return null;
    }

    // 유효한 휴가 종류 리스트
    const validLeaveTypes = [
      '예비군/민방위 연차',
      '배우자 출산휴가',
      '경조사휴가',
      '산전후휴가',
      '결혼휴가',
      '병가',
    ];

    // items 리스트에 있는 값만 반환
    if (validLeaveTypes.contains(leaveType)) {
      return leaveType;
    }

    // items에 없는 값이면 null 반환 (기본값으로 처리)
    return null;
  }

  /// 휴가 부여 상신 상세 위젯
  Widget _buildLeaveGrantApprovalDetail() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 휴가 종류
          FormBuilderDropdown<String>(
            name: 'leaveType',
            decoration: _buildInputDecoration('휴가 종류', isRequired: true),
            validator:
                FormBuilderValidators.required(errorText: '휴가 종류는 필수입니다'),
            initialValue: _getValidLeaveType(),
            items: [
              '예비군/민방위 연차',
              '배우자 출산휴가',
              '경조사휴가',
              '산전후휴가',
              '결혼휴가',
              '병가',
            ]
                .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _approvalDetailData['leave_type'] = value;
              });
            },
          ),
          const SizedBox(height: 16),

          // 제목 입력란
          FormBuilderTextField(
            name: 'title',
            decoration: _buildInputDecoration('제목', isRequired: true),
            initialValue: _title ?? '',
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(errorText: '제목은 필수입니다'),
            ]),
            onChanged: (value) {
              setState(() {
                _title = value;
              });
            },
          ),
          const SizedBox(height: 16),

          // 휴가 부여 일수
          FormBuilderTextField(
            name: 'grantDays',
            decoration: _buildInputDecoration('휴가 부여 일수', isRequired: true),
            keyboardType: TextInputType.number,
            initialValue: _approvalDetailData['grant_days']?.toString() ?? '',
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(errorText: '휴가 부여 일수는 필수입니다'),
              FormBuilderValidators.numeric(errorText: '숫자만 입력해주세요'),
            ]),
            onChanged: (value) {
              setState(() {
                _approvalDetailData['grant_days'] =
                    double.tryParse(value ?? '0') ?? 0.0;
              });
            },
          ),
          const SizedBox(height: 16),

          // 사유
          FormBuilderTextField(
            name: 'reason',
            decoration: _buildInputDecoration('사유', isRequired: false),
            maxLines: 4,
            initialValue: _approvalDetailData['reason']?.toString() ?? '',
            onChanged: (value) {
              setState(() {
                _approvalDetailData['reason'] = value;
              });
            },
          ),
        ],
      ),
    );
  }

  /// 승인자 필드
  Widget _buildApproversField() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 승인자 선택 버튼들
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showApproverSelection(sequential: false),
                icon: const Icon(Icons.how_to_reg_rounded, size: 16),
                label: const Text('승인자 선택'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A6CF7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showApproverSelection(sequential: true),
                icon: const Icon(Icons.format_list_numbered, size: 16),
                label: const Text('순차결재'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _saveApprovalLine(),
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text(
                  '결재라인 저장',
                  style: TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B7280),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 선택된 승인자 표시 영역
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                isDarkTheme ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDarkTheme
                    ? const Color(0xFF4A5568)
                    : const Color(0xFFE9ECEF)),
          ),
          child: _selectedApproverIds.isEmpty
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.how_to_reg_rounded,
                      color: Color(0xFF4A6CF7),
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '승인자 선택',
                      style: TextStyle(
                        color: isDarkTheme
                            ? const Color(0xFFA0AEC0)
                            : const Color(0xFF8B95A1),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.how_to_reg_rounded,
                          color: Color(0xFF4A6CF7),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '선택된 승인자 (${_selectedApproverIds.length}명)',
                          style: TextStyle(
                            color: isDarkTheme
                                ? Colors.white
                                : const Color(0xFF1A1D1F),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _selectedApproverIds.map((approverId) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF4A6CF7).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                approverId,
                                style: const TextStyle(
                                  color: Color(0xFF4A6CF7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  /// 참조자 필드
  Widget _buildReferenceField() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 참조자 선택 버튼
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showReferenceSelection(),
            icon: const Icon(Icons.person_add_outlined, size: 16),
            label: const Text('참조자 선택'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF20C997),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 선택된 참조자 표시 영역
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                isDarkTheme ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDarkTheme
                    ? const Color(0xFF4A5568)
                    : const Color(0xFFE9ECEF)),
          ),
          child: _ccList.isEmpty
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.person_add_outlined,
                      color: Color(0xFF20C997),
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '참조자 선택',
                      style: TextStyle(
                        color: isDarkTheme
                            ? const Color(0xFFA0AEC0)
                            : const Color(0xFF8B95A1),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.person_add_outlined,
                          color: Color(0xFF20C997),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '선택된 참조자 (${_ccList.length}명)',
                          style: TextStyle(
                            color: isDarkTheme
                                ? Colors.white
                                : const Color(0xFF1A1D1F),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _ccList.map((ccPerson) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF20C997).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                ccPerson.name,
                                style: const TextStyle(
                                  color: Color(0xFF20C997),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  /// 첨부파일 필드 (채팅 스타일과 동일)
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
          // 헤더: 아이콘 + 파일 개수 + 버튼
          Row(
            children: [
              Icon(Icons.attach_file, size: 16, color: textColor),
              const SizedBox(width: 8),
              Text(
                (_attachments.isEmpty && _chatAttachments.isEmpty)
                    ? '첨부파일'
                    : '첨부파일 ${_attachments.length + _chatAttachments.length}개',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const Spacer(),
              if (_attachments.isNotEmpty || _chatAttachments.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _attachments.clear();
                      _chatAttachments.clear();
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

          // 채팅에서 전달된 첨부파일 (클라우드 아이콘으로 구분)
          if (_chatAttachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.cloud_done,
                    size: 14, color: const Color(0xFF10B981)),
                const SizedBox(width: 4),
                Text(
                  '채팅에서 첨부됨 (${_chatAttachments.length}개)',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF10B981)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _chatAttachments.asMap().entries.map((entry) {
                final index = entry.key;
                final attachment = entry.value;
                return _buildChatAttachment(
                    attachment, index, isDarkTheme, textColor, subtitleColor);
              }).toList(),
            ),
          ],

          // 직접 첨부한 파일 목록
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            if (_chatAttachments.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.folder_open,
                      size: 14, color: const Color(0xFF4A6CF7)),
                  const SizedBox(width: 4),
                  Text(
                    '직접 첨부 (${_attachments.length}개)',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF4A6CF7)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
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
          ],

          // 둘 다 비어있을 때만 안내 메시지 표시
          if (_attachments.isEmpty && _chatAttachments.isEmpty) ...[
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
              // 이미지 아이콘
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
              // 파일명
              Text(
                attachment['name']!.length > 10
                    ? '${attachment['name']!.substring(0, 7)}...'
                    : attachment['name']!,
                style: TextStyle(fontSize: 10, color: textColor),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // 파일 크기
              if (attachment['size'] != null)
                Text(
                  attachment['size']!,
                  style: TextStyle(fontSize: 9, color: subtitleColor),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
        // 삭제 버튼
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

  /// 채팅에서 전달된 첨부파일 위젯 (클라우드 아이콘, 초록색 테두리)
  Widget _buildChatAttachment(
    Map<String, String> attachment,
    int index,
    bool isDarkTheme,
    Color textColor,
    Color subtitleColor,
  ) {
    final fileName = attachment['name'] ?? '';
    final sizeBytes = int.tryParse(attachment['size'] ?? '0') ?? 0;
    final formattedSize = _formatFileSize(sizeBytes);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkTheme
            ? const Color(0xFF1E3A2F)
            : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_done, size: 16, color: Color(0xFF10B981)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fileName.length > 15
                    ? '${fileName.substring(0, 12)}...'
                    : fileName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              Text(
                formattedSize,
                style: TextStyle(fontSize: 10, color: subtitleColor),
              ),
            ],
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _chatAttachments.removeAt(index);
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
      ),
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

  /// 하단 버튼들
  Widget _buildFooter() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
              color: isDarkTheme
                  ? const Color(0xFF2D3748)
                  : const Color(0xFFE9ECEF)),
        ),
      ),
      child: Column(
        children: [
          // 결재라인 저장 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _saveApprovalLine,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4A6CF7),
                side: const BorderSide(color: Color(0xFF4A6CF7)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.save_outlined, size: 20),
              label: const Text(
                '결재라인 저장',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 기존 버튼들 (초기화 + 상신)
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _resetForm,
                  child: Text(
                    '초기화',
                    style: TextStyle(
                      color: isDarkTheme
                          ? const Color(0xFF8B95A1)
                          : const Color(0xFF8B95A1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitDraft,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A6CF7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '상신',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

  /// 승인자 선택 모달 표시
  Future<void> _showApproverSelection({bool sequential = false}) async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => ApproverSelectionModal(
        initialSelectedApproverIds: _selectedApproverIds,
        sequentialApproval: sequential,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedApproverIds = result;
        // 순차결재 모드로 선택된 경우 _approvalLine도 업데이트
        // (순서 정보 유지를 위해)
      });
    }
  }

  /// 저장된 결재라인 불러오기
  Future<void> _loadSavedApprovalLine() async {
    try {
      // 현재 로그인된 사용자 ID 가져오기
      final currentUserId = ref.read(userIdProvider) ?? '';
      if (currentUserId.isEmpty) {
        print('⚠️ 로그인 정보가 없어 결재라인을 불러올 수 없습니다.');
        return;
      }

      print('💾 저장된 결재라인 불러오기 시작: userId=$currentUserId');

      // API 호출 (전자결재 전용 API)
      final response = await LeaveApiService.loadEApprovalLine(
        userId: currentUserId,
        approvalType: 'hr_leave_grant',
      );

      print(
          '💾 결재라인 불러오기 응답: isSuccess=${response.isSuccess}, error=${response.error}');

      if (response.isSuccess && mounted) {
        print('🔍 API 응답 파싱 성공');
        print('🔍 승인자 목록 개수: ${response.approvalLine.length}');
        print('🔍 참조자 목록 개수: ${response.ccList.length}');

        // 승인자 목록 설정
        if (response.approvalLine.isNotEmpty) {
          // approval_seq 순서대로 정렬
          final sortedLine = response.approvalLine.toList()
            ..sort((a, b) => a.approvalSeq.compareTo(b.approvalSeq));

          setState(() {
            _selectedApproverIds =
                sortedLine.map((item) => item.approverId).toList();
          });

          print('✅ 승인자 ${_selectedApproverIds.length}명 불러오기 완료');
          print('📋 승인자 목록: ${_selectedApproverIds.join(', ')}');
        }

        // 참조자 목록 설정 (CcPerson으로 변환)
        if (response.ccList.isNotEmpty) {
          print('🔄 참조자 목록 변환 시작 - 원본 데이터 개수: ${response.ccList.length}');
          print(
              '🔄 원본 ccList 데이터: ${response.ccList.map((item) => 'name=${item.name}, userId=${item.userId}').join(' | ')}');

          final ccList = response.ccList.map((item) {
            print(
                '🔄 참조자 변환: name=${item.name}, department=${item.department}, userId=${item.userId}');
            final ccPerson = CcPerson(
              name: item.name,
              department: item.department,
              userId: item.userId.isNotEmpty ? item.userId : null,
            );
            print(
                '🔄 CcPerson 생성됨: ${ccPerson.name}, uniqueKey=${ccPerson.uniqueKey}');
            return ccPerson;
          }).toList();

          print(
              '🔄 변환된 CcPerson 목록: ${ccList.map((p) => '${p.name}(${p.uniqueKey})').join(', ')}');

          setState(() {
            _ccList = ccList;
            _referencePersons = _ccList.map((p) => p.name).join(', ');
          });

          print('✅ 참조자 ${_ccList.length}명 불러오기 완료');
          print(
              '📋 참조자 상세 정보: ${_ccList.map((p) => '${p.name}(${p.userId ?? 'no-id'}, uniqueKey=${p.uniqueKey})').join(', ')}');
          print('📋 _referencePersons: $_referencePersons');
        }

        if (response.approvalLine.isNotEmpty || response.ccList.isNotEmpty) {
          print('✅ 저장된 결재라인 불러오기 성공');
        } else {
          print('💾 저장된 결재라인이 없습니다.');
        }
      } else if (response.error != null) {
        print('⚠️ 결재라인 불러오기 실패: ${response.error}');
      }
    } catch (e) {
      print('❌ 결재라인 불러오기 중 오류 발생: $e');
      print('❌ 스택 트레이스: $e');
    }
  }

  /// 참조자 선택 모달 표시
  void _showReferenceSelection() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ApprovalReferenceSelectionDialog(
          currentReferences: _ccList,
          onSelectionChanged: (newReferences) {
            setState(() {
              _ccList = newReferences;
              // _referencePersons도 함께 업데이트
              _referencePersons = _ccList.isEmpty
                  ? null
                  : _ccList.map((p) => p.name).join(', ');
            });
          },
        );
      },
    );
  }

  /// 첨부파일 선택 모달 표시
  Future<void> _showAttachmentSelection() async {
    try {
      // 파일 선택기 열기 (다중 선택 가능)
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        dialogTitle: '첨부파일 선택',
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (var file in result.files) {
            // 중복 체크 (같은 경로의 파일은 추가하지 않음)
            final isDuplicate = _attachments
                .any((attachment) => attachment['path'] == file.path);

            if (!isDuplicate && file.path != null) {
              // 파일 크기를 사람이 읽기 쉬운 형식으로 변환
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

        // 성공 메시지
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result.files.length}개 파일이 추가되었습니다.'),
              duration: const Duration(seconds: 2),
              backgroundColor: const Color(0xFF28A745),
            ),
          );
        }
      } else {
        print('ℹ️ 파일 선택 취소됨');
      }
    } catch (e) {
      print('❌ 파일 선택 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('파일 선택 중 오류가 발생했습니다: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFFDC3545),
          ),
        );
      }
    }
  }

  /// 파일 크기를 사람이 읽기 쉬운 형식으로 변환 (Bytes → KB/MB/GB)
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

  /// 결재라인 저장
  Future<void> _saveApprovalLine() async {
    // 승인자가 선택되지 않은 경우
    if (_selectedApproverIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('승인자를 선택해주세요'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // 현재 로그인된 사용자 ID 가져오기
      final currentUserId = ref.read(userIdProvider) ?? '';
      if (currentUserId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인 정보를 찾을 수 없습니다. 다시 로그인해주세요.'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // 승인자 목록 정보 가져오기
      final approverResponse = await LeaveApiService.getApprover();
      if (!approverResponse.isSuccess) {
        throw Exception('승인자 정보를 불러올 수 없습니다.');
      }

      // approval_line 생성
      final List<SaveApprovalLineData> approvalLine = [];
      for (int i = 0; i < _selectedApproverIds.length; i++) {
        final approverId = _selectedApproverIds[i];
        final nextApproverId = i < _selectedApproverIds.length - 1
            ? _selectedApproverIds[i + 1]
            : '';

        // 승인자 정보 찾기
        final approver = approverResponse.approverList.firstWhere(
          (a) => a.approverId == approverId,
          orElse: () => throw Exception('승인자 정보를 찾을 수 없습니다: $approverId'),
        );

        approvalLine.add(SaveApprovalLineData(
          approverId: approverId,
          nextApproverId: nextApproverId,
          approvalSeq: i + 1,
          approverName: approver.approverName,
        ));
      }

      // cc_list 생성
      final List<CcListItem> ccList = [];
      for (final cc in _ccList) {
        ccList.add(CcListItem(
          userId: cc.userId ?? '',
          name: cc.name,
          department: cc.department,
          jobPosition: '', // CcPerson에 jobPosition 필드가 없어서 빈 문자열로 전송
        ));
      }

      print('💾 결재라인 저장 API 요청 시작');
      print('💾 userId: $currentUserId');
      print('💾 approvalLine: ${approvalLine.length}명');
      print('💾 ccList: ${ccList.length}명');

      // API 호출 (전자결재 전용 API)
      final response = await LeaveApiService.saveEApprovalLine(
        userId: currentUserId,
        approvalType: 'hr_leave_grant',
        approvalLine: approvalLine,
        ccList: ccList,
      );

      if (response.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('결재라인이 성공적으로 저장되었습니다'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        print('✅ 결재라인 저장 성공');
      } else {
        throw Exception(response.error ?? '결재라인 저장에 실패했습니다');
      }
    } catch (e) {
      print('❌ 결재라인 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('결재라인 저장 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 전자결재 상신
  Future<void> _submitDraft() async {
    // 승인자가 선택되지 않은 경우 - 필수값 검증
    if (_selectedApproverIds.isEmpty) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('승인자 필수 선택'),
          content: const Text('전자결재 상신을 위해서는 반드시 승인자를 선택해야 합니다.\n승인자를 선택해주세요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    // 폼 검증은 수동으로 수행 (필수 필드 체크)
    bool isValid = true;
    String errorMessage = '';

    // 필수 필드 검증
    if (_draftingDepartment == null || _draftingDepartment?.isEmpty == true) {
      isValid = false;
      errorMessage = '기안부서를 선택해주세요';
    } else if ((_drafter == null || _drafter?.isEmpty == true) &&
        ref.read(userIdProvider) == null) {
      isValid = false;
      errorMessage = '기안자를 입력해주세요';
    } else if (_selectedApprovalType == null ||
        _selectedApprovalType?.isEmpty == true) {
      isValid = false;
      errorMessage = '결재 종류를 선택해주세요';
    } else if (_title == null || _title?.isEmpty == true) {
      isValid = false;
      errorMessage = '제목을 입력해주세요';
    }

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 폼 데이터는 이미 상태 변수에 저장되어 있으므로 별도 저장 불필요

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('상신 확인'),
        content: const Text('전자결재를 상신하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('상신'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        // 전자결재 상신 데이터 로그
        print('📋 전자결재 상신 데이터:');
        print('  - 결재 종류: $_selectedApprovalType');
        print('  - 제목 (documentTitle): $_documentTitle');
        print('  - 제목 (title): $_title');
        print('  - 내용: $_content');
        print('  - 긴급도: $_urgencyLevel');
        print('  - 요청일: $_requestDate');
        print('  - 완료예정일: $_expectedCompletionDate');
        print('  - 예산: $_budget');
        print('  - 선택된 승인자 IDs: $_selectedApproverIds');
        print('  - 결재선: $_approvalLine');
        print('  - 참조자 목록: $_ccList');
        print('  - 참조자 문자열: $_referencePersons');
        print('  - 첨부파일: $_attachments');
        print('  - 결재 상세 데이터: $_approvalDetailData');

        // 휴가 부여 상신 API 호출
        if (_selectedApprovalType == '휴가 부여 상신') {
          await _submitLeaveGrantRequest();
        } else {
          // 다른 결재 종류는 임시로 지연 처리
          await Future.delayed(const Duration(seconds: 2));
        }

        setState(() {
          _isSubmitting = false;
        });

        if (mounted) {
          // 전자결재 상신 완료 - 모달만 닫기 (스낵바 제거)
          _closeModal(isSuccess: true);
        }
      } catch (e) {
        setState(() {
          _isSubmitting = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('상신 중 오류가 발생했습니다: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  /// 휴가 부여 상신 API 호출 (multipart/form-data)
  Future<void> _submitLeaveGrantRequest() async {
    try {
      // 로그인한 유저의 ID 가져오기
      final currentUserId = ref.read(userIdProvider);
      if (currentUserId == null) {
        throw Exception('로그인된 사용자 정보를 찾을 수 없습니다.');
      }

      print('👤 현재 로그인한 사용자 ID: $currentUserId');

      // 결재선 데이터 변환
      // _selectedApproverIds의 순서가 곧 결재 순서
      List<ApprovalLineItem> approvalLine = [];
      for (int i = 0; i < _selectedApproverIds.length; i++) {
        final approverId = _selectedApproverIds[i];
        // _approvalLine에서 해당 승인자 정보 찾기
        final approverInfo = _approvalLine.firstWhere(
          (a) => a['id'] == approverId,
          orElse: () => {
            'id': approverId,
            'name': '',
            'department': '',
            'position': '',
          },
        );

        // 다음 승인자 ID 결정 (마지막 승인자는 빈 문자열)
        final nextApproverId = i < _selectedApproverIds.length - 1
            ? _selectedApproverIds[i + 1]
            : '';

        approvalLine.add(ApprovalLineItem(
          userId: approverId,
          department: approverInfo['department'] ?? '',
          jobPosition: approverInfo['position'] ?? '',
          approverId: approverId,
          nextApproverId: nextApproverId,
          approvalSeq: i + 1, // 1부터 시작하는 순차 번호
          approverName: approverInfo['name'] ?? '',
          ccList: null, // cc_list는 최상위 레벨로 이동
        ));
      }

      // 채팅 첨부파일 (attachments_list) - URL 포함된 메타데이터
      List<AttachmentItem> chatAttachments = [];
      for (var attachment in _chatAttachments) {
        chatAttachments.add(AttachmentItem(
          fileName: attachment['name'] ?? '',
          size: int.tryParse(attachment['size'] ?? '0') ?? 0,
          url: attachment['url'] ?? '',
          prefix: attachment['prefix'] ?? '',
        ));
      }

      // 모달 직접 첨부파일 (files) - 바이트 데이터 준비
      List<Uint8List> fileBytes = [];
      List<String> fileNames = [];
      for (var attachment in _attachments) {
        final path = attachment['path'];
        if (path != null && path.isNotEmpty) {
          final file = File(path);
          if (await file.exists()) {
            fileBytes.add(await file.readAsBytes());
            fileNames.add(attachment['name'] ?? 'file');
            print('📁 파일 읽기 완료: ${attachment['name']}');
          }
        }
      }

      // 휴가 부여 상신 요청 데이터 로그
      print(
          '📋 [CommonElectronicApprovalModal] _approvalDetailData 전체: $_approvalDetailData');
      print(
          '📋 [CommonElectronicApprovalModal] 참조자 목록(_ccList): ${_ccList.map((e) => '${e.name}(userId:${e.userId ?? ''})').join(', ')}');
      print(
          '📋 [CommonElectronicApprovalModal] 채팅 첨부파일: ${chatAttachments.length}개');
      print('📋 [CommonElectronicApprovalModal] 모달 첨부파일: ${fileBytes.length}개');

      // multipart API 호출
      final response = await LeaveApiService.submitLeaveGrantRequestMultipart(
        userId: currentUserId,
        department: _draftingDepartment ?? '',
        approvalDate: DateTime.now().toIso8601String().split(".")[0] + 'Z',
        approvalType: 'hr_leave_grant',
        approvalLine: approvalLine,
        title: _title ?? '',
        leaveType: _approvalDetailData['leave_type'] ?? '',
        grantDays:
            (_approvalDetailData['grant_days'] as num?)?.toDouble() ?? 0.0,
        reason: _approvalDetailData['reason'] ?? '',
        attachmentsList: chatAttachments,
        startDate: _approvalDetailData['start_date'],
        endDate: _approvalDetailData['end_date'],
        halfDaySlot: _approvalDetailData['half_day_slot'],
        ccList: _ccList.isEmpty ? null : _ccList,
        files: fileBytes.isEmpty ? null : fileBytes,
        fileNames: fileNames.isEmpty ? null : fileNames,
      );

      if (response.error == null) {
        print('✅ 휴가 부여 상신 성공! ID: ${response.id}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('휴가 부여 상신이 성공적으로 완료되었습니다. (ID: ${response.id})'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        print('❌ 휴가 부여 상신 실패: ${response.error}');
        throw Exception(response.error ?? '알 수 없는 오류가 발생했습니다.');
      }
    } catch (e) {
      print('❌ 휴가 부여 상신 API 호출 실패: $e');
      rethrow; // 상위 catch 블록에서 처리하도록 재throw
    }
  }

  /// 폼 초기화
  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _selectedApprovalType = null;
      _title = null;
      _content = null;
      _urgencyLevel = null;
      _requestDate = null;
      _expectedCompletionDate = null;
      _budget = null;
      _selectedApproverIds = [];
      _ccList = [];
      _attachments = [];
      _chatAttachments = [];
      _approvalLine = [];
      _isLeaveGrantInitialized = false;
      _draftingDepartment = null;
      _draftingDate = DateTime.now();
      _drafter = null;
      _retentionPeriod = '영구';
      _referencePersons = null;
      _documentTitle = null;
      _isCustomDepartment = false;
      _fieldErrors.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('폼이 초기화되었습니다'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// 샘플 HTML 콘텐츠 로드 (실제로는 API에서 받아옴)
  Future<void> _loadSampleHtmlContent() async {
    setState(() {
      _isLoadingHtmlContent = true;
    });

    try {
      // 실제 환경에서는 여기서 API를 호출하여 HTML을 받아옵니다
      await Future.delayed(const Duration(seconds: 1)); // 로딩 시뮬레이션

      // 샘플 HTML 콘텐츠 (테이블로만 구성)
      const sampleHtml = '''
        <div style="font-family: Arial, sans-serif; line-height: 1.6;">
          <table style="width: 100%; border-collapse: collapse; margin: 10px 0; border: 2px solid #4A6CF7;">
            <thead>
              <tr style="background-color: #4A6CF7; color: white;">
                <th style="border: 1px solid #ddd; padding: 15px; text-align: center; font-size: 16px;">항목</th>
                <th style="border: 1px solid #ddd; padding: 15px; text-align: center; font-size: 16px;">내용</th>
                <th style="border: 1px solid #ddd; padding: 15px; text-align: center; font-size: 16px;">비고</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td style="border: 1px solid #ddd; padding: 12px; background-color: #f8f9fa; font-weight: bold;">제목</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">기본양식 결재서</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">필수 입력</td>
              </tr>
              <tr>
                <td style="border: 1px solid #ddd; padding: 12px; background-color: #f8f9fa; font-weight: bold;">기안일자</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">2024-01-15</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">자동 입력</td>
              </tr>
              <tr>
                <td style="border: 1px solid #ddd; padding: 12px; background-color: #f8f9fa; font-weight: bold;">기안부서</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">AI사업부</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">부서명</td>
              </tr>
              <tr>
                <td style="border: 1px solid #ddd; padding: 12px; background-color: #f8f9fa; font-weight: bold;">기안자</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">김담당</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">직원명</td>
              </tr>
              <tr>
                <td style="border: 1px solid #ddd; padding: 12px; background-color: #f8f9fa; font-weight: bold;">예산</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">1,000,000원</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">부가세 별도</td>
              </tr>
              <tr>
                <td style="border: 1px solid #ddd; padding: 12px; background-color: #f8f9fa; font-weight: bold;">일정</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">2024년 1월 ~ 3월</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">3개월 소요 예정</td>
              </tr>
              <tr>
                <td style="border: 1px solid #ddd; padding: 12px; background-color: #f8f9fa; font-weight: bold;">담당자</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">김담당 (AI사업부)</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">프로젝트 PM</td>
              </tr>
              <tr>
                <td style="border: 1px solid #ddd; padding: 12px; background-color: #f8f9fa; font-weight: bold;">위험요소</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">일정 지연 가능성</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">대비책 수립 필요</td>
              </tr>
              <tr>
                <td style="border: 1px solid #ddd; padding: 12px; background-color: #f8f9fa; font-weight: bold;">참조자</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">이참조, 박참조</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">관련 부서</td>
              </tr>
              <tr>
                <td style="border: 1px solid #ddd; padding: 12px; background-color: #f8f9fa; font-weight: bold;">첨부파일</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">계약서.pdf, 예산서.xlsx</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">관련 문서</td>
              </tr>
              <tr>
                <td style="border: 1px solid #ddd; padding: 12px; background-color: #f8f9fa; font-weight: bold;">긴급도</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">보통</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">높음/보통/낮음</td>
              </tr>
              <tr>
                <td style="border: 1px solid #ddd; padding: 12px; background-color: #f8f9fa; font-weight: bold;">보존기간</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">5년</td>
                <td style="border: 1px solid #ddd; padding: 12px;" contenteditable="true">법정 보존기간</td>
              </tr>
            </tbody>
          </table>
        </div>
      ''';

      setState(() {
        _serverHtmlContent = sampleHtml;
        _isLoadingHtmlContent = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('서버에서 HTML 템플릿을 불러왔습니다'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingHtmlContent = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('HTML 템플릿 로드 실패: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// HTML 콘텐츠 지우기
  void _clearHtmlContent() {
    // 프로바이더의 HTML 콘텐츠도 함께 삭제
    ref.read(htmlTestProvider.notifier).clearHtmlContent();

    setState(() {
      _serverHtmlContent = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('HTML 콘텐츠가 삭제되었습니다'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  /// 휴가 부여 상신 JSON 데이터 자동 매핑
  void _mapLeaveGrantJsonToFields(Map<String, dynamic> jsonData) {
    print('🏢 [CommonElectronicApprovalModal] 휴가 부여 상신 JSON 매핑 시작');
    print('🏢 [CommonElectronicApprovalModal] JSON 데이터: $jsonData');

    setState(() {
      // 공통 필수영역 매핑
      _draftingDepartment = jsonData['department'] ?? '';
      _drafter = jsonData['name'] ?? '';

      // 결재 종류 자동 선택
      _selectedApprovalType = '휴가 부여 상신';
      _documentTitle = jsonData['title'] ?? '';
      _title = jsonData['title'] ?? '';

      // 휴가 부여 상신 상세 데이터 매핑
      _approvalDetailData.addAll({
        'leave_type': jsonData['leave_type'] ?? '',
        'grant_days': jsonData['grant_days'] ?? 0.0,
        'reason': jsonData['reason'] ?? '',
        'start_date': jsonData['start_date'] ?? '',
        'end_date': jsonData['end_date'] ?? '',
        'half_day_slot': jsonData['half_day_slot'] ?? '',
      });

      // FormBuilder 필드 값을 프로그램적으로 업데이트
      _formKey.currentState?.fields['grantDays']
          ?.didChange(_approvalDetailData['grant_days']?.toString() ?? '');
      _formKey.currentState?.fields['reason']
          ?.didChange(_approvalDetailData['reason']?.toString() ?? '');

      // 📋 _approvalDetailData 전체 로그 출력
      print('📋 [CommonElectronicApprovalModal] _approvalDetailData 설정 완료:');
      print('   - leave_type: ${_approvalDetailData['leave_type']}');
      print('   - grant_days: ${_approvalDetailData['grant_days']}');
      print('   - reason: ${_approvalDetailData['reason']}');
      print('   - start_date: ${_approvalDetailData['start_date']}');
      print('   - end_date: ${_approvalDetailData['end_date']}');
      print('   - half_day_slot: ${_approvalDetailData['half_day_slot']}');

      // 결재라인 매핑
      if (jsonData['approval_line'] != null &&
          jsonData['approval_line'] is List) {
        _approvalLine.clear();
        final approvalLineList = jsonData['approval_line'] as List;
        for (var i = 0; i < approvalLineList.length; i++) {
          final approver = approvalLineList[i];
          _approvalLine.add({
            'name': approver['approver_name'] ?? '',
            'position': approver['job_position'] ?? '',
            'status': 'pending',
            'id': approver['approver_id'] ?? '',
            'department': approver['department'] ?? '',
            'approval_seq': approver['approval_seq'] ?? (i + 1),
          });
        }
        // 임시저장 데이터에서 승인자 ID 리스트 로드
        if (_approvalLine.isNotEmpty) {
          _selectedApproverIds =
              _approvalLine.map((a) => a['id'] as String).toList();
        }
      }

      // 첨부파일 매핑 - 채팅에서 온 첨부파일은 _chatAttachments에 저장 (URL 포함)
      if (jsonData['attachments_list'] != null &&
          jsonData['attachments_list'] is List) {
        _chatAttachments.clear();
        final attachmentsList = jsonData['attachments_list'] as List;
        for (var attachment in attachmentsList) {
          _chatAttachments.add({
            'name': attachment['file_name'] ?? '',
            'url': attachment['url'] ?? '',
            'size': (attachment['size'] ?? 0).toString(),
            'prefix': attachment['prefix'] ?? '',
          });
        }
      }

      // 폼 키를 변경하여 위젯 재빌드 (initialValue가 적용되도록)
      _formKeyCounter++;
    });

    print('🏢 [CommonElectronicApprovalModal] JSON 매핑 완료');
    print('🏢 [CommonElectronicApprovalModal] 기안부서: $_draftingDepartment');
    print('🏢 [CommonElectronicApprovalModal] 기안자: $_drafter');
    print('🏢 [CommonElectronicApprovalModal] 제목: $_title');
    print(
        '🏢 [CommonElectronicApprovalModal] 휴가종류: ${_approvalDetailData['leave_type']}');
    print(
        '🏢 [CommonElectronicApprovalModal] 휴가일수: ${_approvalDetailData['grant_days']}');
    print('🏢 [CommonElectronicApprovalModal] 결재선 수: ${_approvalLine.length}');
    print('🏢 [CommonElectronicApprovalModal] 첨부파일 수: ${_attachments.length}');
  }

  /// 휴가 부여 상신 초기화 (JSON 데이터로)
  void initializeWithLeaveGrantData(Map<String, dynamic> jsonData) async {
    // 이미 초기화되었으면 무시 (중복 호출 방지)
    if (_isLeaveGrantInitialized) {
      print('🏢 [CommonElectronicApprovalModal] 이미 초기화됨, 무시');
      return;
    }
    _isLeaveGrantInitialized = true;

    print('🏢 [CommonElectronicApprovalModal] 휴가 부여 상신 초기화 시작');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📥 [CommonElectronicApprovalModal] 📥 수신된 JSON 데이터 전체:');
    print('   - department: ${jsonData['department']}');
    print('   - name: ${jsonData['name']}');
    print('   - title: ${jsonData['title']}');
    print('   - leave_type: ${jsonData['leave_type']}');
    print('   - grant_days: ${jsonData['grant_days']}');
    print('   - reason: ${jsonData['reason']}');
    print('   - start_date: ${jsonData['start_date']} ⭐');
    print('   - end_date: ${jsonData['end_date']} ⭐');
    print('   - half_day_slot: ${jsonData['half_day_slot']} ⭐');
    print('   - approval_line: ${jsonData['approval_line']}');
    print('   - attachments_list: ${jsonData['attachments_list']}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    setState(() {
      _isLoadingLeaveGrantData = true;
      // 결재종류를 휴가 부여 상신으로 강제 설정
      _selectedApprovalType = '휴가 부여 상신';
    });

    // 7초 로딩 대기
    await Future.delayed(const Duration(seconds: 7));

    // JSON 데이터 매핑
    _mapLeaveGrantJsonToFields(jsonData);

    setState(() {
      _isLoadingLeaveGrantData = false;
    });

    print('🏢 [CommonElectronicApprovalModal] 휴가 부여 상신 초기화 완료');
  }

  /// 기본양식 JSON 데이터 자동 매핑
  void _mapBasicApprovalJsonToFields(Map<String, dynamic> jsonData) {
    print('🏢 [CommonElectronicApprovalModal] 기본양식 JSON 매핑 시작');
    print('🏢 [CommonElectronicApprovalModal] JSON 데이터: $jsonData');

    setState(() {
      // 결재 종류 자동 선택
      _selectedApprovalType = '기본양식';

      // 제목 매핑
      _documentTitle = jsonData['title'] ?? '';
      _title = jsonData['title'] ?? '';

      // HTML 콘텐츠 매핑
      _serverHtmlContent = jsonData['content'] ?? '';

      // 폼 키를 변경하여 위젯 재빌드 (initialValue가 적용되도록)
      _formKeyCounter++;
    });

    print('🏢 [CommonElectronicApprovalModal] 기본양식 JSON 매핑 완료');
    print('🏢 [CommonElectronicApprovalModal] 제목: $_title');
    print(
        '🏢 [CommonElectronicApprovalModal] HTML 콘텐츠 길이: ${_serverHtmlContent?.length ?? 0}');
  }

  /// 기본양식 초기화 (JSON 데이터로)
  void initializeWithBasicApprovalData(Map<String, dynamic> jsonData) async {
    print('🏢 [CommonElectronicApprovalModal] 기본양식 초기화 시작');

    setState(() {
      _isLoadingHtmlContent = true;
      // 결재종류를 기본양식으로 강제 설정
      _selectedApprovalType = '기본양식';
    });

    // 로딩 시뮬레이션 (짧게)
    await Future.delayed(const Duration(milliseconds: 500));

    // JSON 데이터 매핑
    _mapBasicApprovalJsonToFields(jsonData);

    setState(() {
      _isLoadingHtmlContent = false;
    });

    print('🏢 [CommonElectronicApprovalModal] 기본양식 초기화 완료');
  }

  /// 매출/매입 계약 기안서 JSON 데이터 자동 매핑
  void _mapContractApprovalJsonToFields(Map<String, dynamic> jsonData) {
    print('🏢 [CommonElectronicApprovalModal] 매출/매입 계약 기안서 JSON 매핑 시작');
    print('🏢 [CommonElectronicApprovalModal] JSON 데이터: $jsonData');

    setState(() {
      // 결재 종류 자동 선택
      _selectedApprovalType = '매출/매입계약 기안서';

      // 제목 매핑
      _documentTitle = jsonData['title'] ?? '';
      _title = jsonData['title'] ?? '';

      // HTML 콘텐츠 매핑
      _serverHtmlContent = jsonData['content'] ?? '';

      // 폼 키를 변경하여 위젯 재빌드 (initialValue가 적용되도록)
      _formKeyCounter++;
    });

    print('🏢 [CommonElectronicApprovalModal] 매출/매입 계약 기안서 JSON 매핑 완료');
    print('🏢 [CommonElectronicApprovalModal] 제목: $_title');
    print(
        '🏢 [CommonElectronicApprovalModal] HTML 콘텐츠 길이: ${_serverHtmlContent?.length ?? 0}');
  }

  /// 매출/매입 계약 기안서 초기화 (JSON 데이터로)
  void initializeWithContractApprovalData(Map<String, dynamic> jsonData) async {
    print('🏢 [CommonElectronicApprovalModal] 매출/매입 계약 기안서 초기화 시작');

    setState(() {
      _isLoadingHtmlContent = true;
      // 결재종류를 매출/매입계약 기안서로 강제 설정
      _selectedApprovalType = '매출/매입계약 기안서';

      // AI 시나리오 플래그 설정
      _isAiGeneratedHtml = true;

      // AI 생성 HTML 콘텐츠 저장 (JSON에서 추출)
      _aiGeneratedHtmlContent = jsonData['html_content'] as String?;
    });

    // 로딩 시뮬레이션 (짧게)
    await Future.delayed(const Duration(milliseconds: 500));

    // JSON 데이터 매핑
    _mapContractApprovalJsonToFields(jsonData);

    setState(() {
      _isLoadingHtmlContent = false;
    });

    print('🏢 [CommonElectronicApprovalModal] 매출/매입 계약 기안서 초기화 완료');
    print('   - AI 생성 모드: $_isAiGeneratedHtml');
    print('   - HTML 콘텐츠 길이: ${_aiGeneratedHtmlContent?.length ?? 0}');
  }

  /// 모달 닫기
  void _closeModal({bool isSuccess = false}) async {
    await _slideController.reverse();

    // 윈도우 포커스 복원
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        await windowManager.focus();
      } catch (e) {
        print('윈도우 포커스 복원 중 오류: $e');
      }
    }

    if (widget.onClose != null) {
      widget.onClose!();
    } else if (mounted) {
      // 성공한 경우 true, 취소한 경우 false를 반환
      Navigator.of(context).pop(isSuccess);
    }
  }
}

/// 전자결재용 참조자 선택 다이얼로그 (2-stage API)
class ApprovalReferenceSelectionDialog extends StatefulWidget {
  final List<CcPerson> currentReferences;
  final Function(List<CcPerson>) onSelectionChanged;

  const ApprovalReferenceSelectionDialog({
    super.key,
    required this.currentReferences,
    required this.onSelectionChanged,
  });

  @override
  State<ApprovalReferenceSelectionDialog> createState() =>
      _ApprovalReferenceSelectionDialogState();
}

class _ApprovalReferenceSelectionDialogState
    extends State<ApprovalReferenceSelectionDialog> {
  late List<CcPerson> _selectedReferences;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  Set<String> _expandedDepartments = {};

  // API 로딩 상태
  bool _isLoadingDepartments = true;
  List<String> _departmentsFromApi = [];

  // 부서별 멤버 로딩 상태
  Map<String, bool> _loadingMembers = {};
  Map<String, String?> _membersError = {};
  Map<String, List<CcPerson>> _departmentMembers = {};

  @override
  void initState() {
    super.initState();
    _selectedReferences = List.from(widget.currentReferences);
    print('🔍 ApprovalReferenceSelectionDialog 초기화');
    print('🔍 currentReferences 개수: ${widget.currentReferences.length}');
    print(
        '🔍 currentReferences 상세: ${widget.currentReferences.map((p) => 'name=${p.name}, userId=${p.userId}, uniqueKey=${p.uniqueKey}').join(' | ')}');
    _loadCompanyMembers();
  }

  /// 회사 전체 조직도(부서/인원) 로드
  ///
  /// - 기존에는 부서 목록(`getDepartmentList`) + 부서별 인원(`getDepartmentMembers`)을
  ///   여러 번 호출했지만, 이제는 `getCompanyMembers` 한 번만 호출해서
  ///   {부서명: [ {name, user_id, job_position?}, ... ]} 형태로 모두 받는다.
  Future<void> _loadCompanyMembers() async {
    setState(() {
      _isLoadingDepartments = true;
    });

    try {
      print('📋 [전자결재 참조자 모달] 회사 전체 조직도 조회 시작');
      final companyMembers = await ApiService.getCompanyMembers();

      final departments = companyMembers.keys.toList()..sort();
      final Map<String, List<CcPerson>> deptMembers = {};

      companyMembers.forEach((dept, members) {
        deptMembers[dept] = members.map<CcPerson>((m) {
          final name = (m['name'] as String?) ?? '';
          final userId = (m['user_id'] as String?) ?? '';
          return CcPerson(
            name: name,
            department: dept,
            userId: userId.isEmpty ? null : userId,
          );
        }).toList();
      });

      setState(() {
        _departmentsFromApi = departments;
        _departmentMembers = deptMembers;
        _isLoadingDepartments = false;
      });

      print('✅ [전자결재 참조자 모달] 회사 전체 조직도 로드 완료: ${departments.length}개 부서');
    } catch (e) {
      print('❌ [전자결재 참조자 모달] 회사 전체 조직도 로드 실패: $e');
      setState(() {
        _isLoadingDepartments = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 부서별 직원 필터링
  List<String> get _filteredDepartments {
    if (_searchText.isEmpty) {
      return _departmentsFromApi;
    }

    List<String> filteredList = [];

    for (final department in _departmentsFromApi) {
      // 부서명이 검색어와 일치하는 경우
      if (department.toLowerCase().contains(_searchText.toLowerCase())) {
        filteredList.add(department);
        continue;
      }

      // 부서 멤버가 로드된 경우에만 직원 검색
      if (_departmentMembers.containsKey(department)) {
        final employees = _departmentMembers[department] ?? [];
        final hasMatchingEmployee = employees.any((person) =>
            person.name.toLowerCase().contains(_searchText.toLowerCase()));

        if (hasMatchingEmployee) {
          filteredList.add(department);
        }
      }
      // 부서 멤버가 아직 로드되지 않은 경우, 검색어가 있으면 로드 시도는 하지만
      // 필터링 결과에는 포함하지 않음 (로드 완료 후 자동으로 포함됨)
    }

    return filteredList;
  }

  // 부서 내에서 검색어와 일치하는 직원만 필터링
  List<CcPerson> _getFilteredEmployees(String department) {
    final employees = _departmentMembers[department] ?? [];

    if (_searchText.isEmpty) {
      return employees;
    }

    return employees
        .where((person) =>
            person.name.toLowerCase().contains(_searchText.toLowerCase()))
        .toList();
  }

  // 부서의 선택 상태 확인 (동명이인 구분을 위해 uniqueKey 기준)
  bool _isDepartmentSelected(String department) {
    final employees = _departmentMembers[department] ?? [];
    if (employees.isEmpty) return false;

    return employees.every((employee) => _selectedReferences
        .any((selected) => selected.uniqueKey == employee.uniqueKey));
  }

  // 부서의 부분 선택 상태 확인
  bool _isDepartmentPartiallySelected(String department) {
    final employees = _departmentMembers[department] ?? [];
    if (employees.isEmpty) return false;

    final selectedCount = employees
        .where((employee) => _selectedReferences
            .any((selected) => selected.uniqueKey == employee.uniqueKey))
        .length;
    return selectedCount > 0 && selectedCount < employees.length;
  }

  // 부서 전체 선택/해제 (uniqueKey 기준)
  void _toggleDepartmentSelection(String department, bool? selected) {
    setState(() {
      final employees = _departmentMembers[department] ?? [];

      if (selected == true) {
        for (final employee in employees) {
          if (!_selectedReferences
              .any((selected) => selected.uniqueKey == employee.uniqueKey)) {
            _selectedReferences.add(employee);
          }
        }
      } else {
        _selectedReferences.removeWhere((selected) => employees
            .any((employee) => employee.uniqueKey == selected.uniqueKey));
      }
    });
  }

  // 부서 클릭 시 expand + 멤버 로드
  void _onDepartmentTap(String department) {
    setState(() {
      if (_expandedDepartments.contains(department)) {
        _expandedDepartments.remove(department);
      } else {
        _expandedDepartments.add(department);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        height: 600,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkTheme ? const Color(0xFF1A1D1F) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '참조자 선택',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    // 애니메이션 완료 대기
                    await Future.delayed(const Duration(milliseconds: 300));
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('결재 상신이 취소되었습니다.'),
                        duration: Duration(milliseconds: 1500),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.close,
                    color: isDarkTheme ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // 검색 필드
            TextField(
              controller: _searchController,
              style: TextStyle(
                color: isDarkTheme ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: '이름 또는 부서명으로 검색',
                hintStyle: TextStyle(
                  color: isDarkTheme
                      ? const Color(0xFFA0AEC0)
                      : const Color(0xFF8B95A1),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDarkTheme
                      ? const Color(0xFFA0AEC0)
                      : const Color(0xFF8B95A1),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDarkTheme
                    ? const Color(0xFF2D3748)
                    : const Color(0xFFF8F9FA),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDarkTheme
                        ? const Color(0xFF4A5568)
                        : const Color(0xFFE9ECEF),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF20C997)),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                  // 검색어가 입력되면 매칭되는 부서를 자동으로 펼침
                  if (value.isNotEmpty) {
                    // 검색어와 일치하는 부서를 찾아서 펼침
                    for (final department in _departmentsFromApi) {
                      // 부서명이 검색어와 일치하는 경우
                      if (department
                          .toLowerCase()
                          .contains(value.toLowerCase())) {
                        if (!_expandedDepartments.contains(department)) {
                          _expandedDepartments.add(department);
                          // 부서 멤버는 회사 전체 조직도 로드 시 이미 채워짐
                        }
                      } else {
                        // 부서 내 직원 검색 (이미 로드된 부서만 확인)
                        final employees = _departmentMembers[department] ?? [];
                        if (employees.isNotEmpty) {
                          final hasMatchingEmployee = employees.any((person) =>
                              person.name
                                  .toLowerCase()
                                  .contains(value.toLowerCase()));
                          if (hasMatchingEmployee) {
                            if (!_expandedDepartments.contains(department)) {
                              _expandedDepartments.add(department);
                            }
                          } else {
                            // 검색어와 일치하지 않으면 펼쳐진 상태 유지 (필터링은 _getFilteredEmployees에서 처리)
                          }
                        } else {
                          // 부서 멤버가 로드되지 않았고, 검색어가 있으면 로드 시도
                          // 하지만 검색어가 부서명과 일치하지 않으면 로드하지 않음
                        }
                      }
                    }
                  } else {
                    // 검색어가 비어있으면 모든 부서를 닫지 않고 유지 (사용자가 수동으로 펼친 상태 유지)
                  }
                });
              },
            ),
            const SizedBox(height: 4),

            // 선택된 참조자 표시
            if (_selectedReferences.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkTheme
                      ? const Color(0xFF20C997).withValues(alpha: 0.2)
                      : const Color(0xFF20C997).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '선택된 참조자 (${_selectedReferences.length}명)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDarkTheme
                            ? const Color(0xFF20C997).withValues(alpha: 0.8)
                            : const Color(0xFF20C997),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: _selectedReferences.map((person) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF20C997),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                person.name,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedReferences.remove(person);
                                  });
                                },
                                child: const Icon(
                                  Icons.close,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],

            // 부서별 직원 목록
            Expanded(
              child: _isLoadingDepartments
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: const Color(0xFF20C997),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '부서 목록 로딩 중...',
                            style: TextStyle(
                              color: isDarkTheme
                                  ? const Color(0xFFA0AEC0)
                                  : const Color(0xFF8B95A1),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _filteredDepartments.isEmpty
                      ? Center(
                          child: Text(
                            _searchText.isEmpty ? '부서가 없습니다' : '검색 결과가 없습니다',
                            style: TextStyle(
                              color: isDarkTheme
                                  ? const Color(0xFFA0AEC0)
                                  : const Color(0xFF8B95A1),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredDepartments.length,
                          itemBuilder: (context, index) {
                            final department = _filteredDepartments[index];
                            final employees = _getFilteredEmployees(department);
                            final isExpanded =
                                _expandedDepartments.contains(department);
                            final isDepartmentSelected =
                                _isDepartmentSelected(department);
                            final isPartiallySelected =
                                _isDepartmentPartiallySelected(department);
                            final isLoadingMembers =
                                _loadingMembers[department] ?? false;
                            final membersError = _membersError[department];

                            return Column(
                              children: [
                                // 부서 헤더
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDarkTheme
                                        ? const Color(0xFF2D3748)
                                        : const Color(0xFFF8F9FA),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: ListTile(
                                    leading: Icon(
                                      isExpanded
                                          ? Icons.expand_more
                                          : Icons.chevron_right,
                                      color: const Color(0xFF20C997),
                                    ),
                                    title: Row(
                                      children: [
                                        Icon(
                                          Icons.business,
                                          size: 18,
                                          color: const Color(0xFF20C997),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            department,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: isDarkTheme
                                                  ? Colors.white
                                                  : const Color(0xFF1A1D1F),
                                            ),
                                          ),
                                        ),
                                        if (_departmentMembers
                                            .containsKey(department))
                                          Text(
                                            '(${employees.length}명)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDarkTheme
                                                  ? const Color(0xFFA0AEC0)
                                                  : const Color(0xFF6B7280),
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: _departmentMembers
                                                .containsKey(department) &&
                                            _searchText.isEmpty
                                        ? Checkbox(
                                            value: isDepartmentSelected
                                                ? true
                                                : (isPartiallySelected
                                                    ? null
                                                    : false),
                                            tristate: true,
                                            onChanged: (selected) =>
                                                _toggleDepartmentSelection(
                                                    department, selected),
                                          )
                                        : null,
                                    onTap: () => _onDepartmentTap(department),
                                  ),
                                ),

                                // 부서원 목록 (확장된 경우에만 표시)
                                if (isExpanded) ...[
                                  if (isLoadingMembers)
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      margin: const EdgeInsets.only(
                                          left: 32, right: 8),
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: const Color(0xFF20C997),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '부서 인원 로딩 중...',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDarkTheme
                                                    ? const Color(0xFFA0AEC0)
                                                    : const Color(0xFF8B95A1),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else if (membersError != null)
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      margin: const EdgeInsets.only(
                                          left: 32, right: 8),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color: Colors.red,
                                            size: 24,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            membersError,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextButton(
                                            onPressed: () =>
                                                _loadCompanyMembers(),
                                            child: Text('다시 시도'),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (employees.isEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      margin: const EdgeInsets.only(
                                          left: 32, right: 8),
                                      child: Center(
                                        child: Text(
                                          '부서원이 없습니다',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDarkTheme
                                                ? const Color(0xFFA0AEC0)
                                                : const Color(0xFF8B95A1),
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    ...employees.map((person) {
                                      return Container(
                                        margin: const EdgeInsets.only(
                                            left: 32, right: 8),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor:
                                                const Color(0xFF20C997)
                                                    .withValues(alpha: 0.2),
                                            radius: 16,
                                            child: Text(
                                              person.name.isNotEmpty
                                                  ? person.name.substring(0, 1)
                                                  : '?',
                                              style: const TextStyle(
                                                color: Color(0xFF20C997),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            person.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: isDarkTheme
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                          trailing: Checkbox(
                                            value: _selectedReferences.any(
                                                (p) =>
                                                    p.uniqueKey ==
                                                        person.uniqueKey ||
                                                    (p.userId != null &&
                                                        p.userId ==
                                                            person.userId)),
                                            onChanged: (selected) {
                                              setState(() {
                                                if (selected == true) {
                                                  if (!_selectedReferences.any(
                                                      (p) =>
                                                          p.uniqueKey ==
                                                              person
                                                                  .uniqueKey ||
                                                          (p.userId != null &&
                                                              p.userId ==
                                                                  person
                                                                      .userId))) {
                                                    _selectedReferences
                                                        .add(person);
                                                  }
                                                } else {
                                                  _selectedReferences
                                                      .removeWhere((p) =>
                                                          p.uniqueKey ==
                                                              person
                                                                  .uniqueKey ||
                                                          (p.userId != null &&
                                                              p.userId ==
                                                                  person
                                                                      .userId));
                                                }
                                              });
                                            },
                                          ),
                                          onTap: () {
                                            setState(() {
                                              final isSelected =
                                                  _selectedReferences.any((p) =>
                                                      p.uniqueKey ==
                                                          person.uniqueKey ||
                                                      (p.userId != null &&
                                                          p.userId ==
                                                              person.userId));
                                              if (isSelected) {
                                                _selectedReferences.removeWhere(
                                                    (p) =>
                                                        p.uniqueKey ==
                                                            person.uniqueKey ||
                                                        (p.userId != null &&
                                                            p.userId ==
                                                                person.userId));
                                              } else {
                                                if (!_selectedReferences.any(
                                                    (p) =>
                                                        p.uniqueKey ==
                                                            person.uniqueKey ||
                                                        (p.userId != null &&
                                                            p.userId ==
                                                                person
                                                                    .userId))) {
                                                  _selectedReferences
                                                      .add(person);
                                                }
                                              }
                                            });
                                          },
                                        ),
                                      );
                                    }).toList(),
                                ],
                              ],
                            );
                          },
                        ),
            ),

            const SizedBox(height: 4),

            // 버튼들
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onSelectionChanged(_selectedReferences);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF20C997),
                    ),
                    child: Text('확인 (${_selectedReferences.length})'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
