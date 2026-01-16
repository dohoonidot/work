import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_windows/webview_windows.dart';
import 'dart:async';
import 'dart:convert';
import '../../shared/providers/chat_notifier.dart';

/// AI 전자결재 전용 모달 (시나리오 1)
/// - 항상 /default 라우트만 사용
/// - AI가 생성한 HTML을 주입
/// - 드롭다운 없음, 단순 에디터만 표시
class AiElectronicApprovalModal extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const AiElectronicApprovalModal({
    super.key,
    this.onClose,
  });

  @override
  ConsumerState<AiElectronicApprovalModal> createState() =>
      _AiElectronicApprovalModalState();
}

class _AiElectronicApprovalModalState
    extends ConsumerState<AiElectronicApprovalModal>
    with TickerProviderStateMixin {
  WebviewController? _webviewController;
  bool _isWebviewInitialized = false;
  bool _isWebviewLoading = true;
  String? _webviewError;
  StreamSubscription? _webMessageSubscription;

  // AI 생성 HTML 데이터
  String? _aiGeneratedHtml;

  // 공통 필수 영역 데이터 (서버에서 받은 값으로 채움)
  String? _draftingDepartment; // 부서
  String? _drafter; // 기안자
  DateTime? _draftingDate; // 기안일
  String? _documentTitle; // 문서 제목
  String? _approvalLine; // 결재선 (간단히 문자열로 관리)
  String? _referencePersons; // 참조자

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

    // Pending 데이터 확인 및 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingData();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _webMessageSubscription?.cancel();
    _webviewController?.dispose();
    super.dispose();
  }

  /// Pending 데이터 확인
  void _checkPendingData() {
    // 매출/매입 계약 기안서 데이터 확인
    final contractData = ChatNotifier.getPendingContractApprovalData();
    if (contractData != null) {
      print('🎨 [AI 모달] 매출/매입 계약 기안서 데이터 발견');
      _initializeWithData(contractData);
      return;
    }

    // 기본양식 데이터 확인
    final basicData = ChatNotifier.getPendingBasicApprovalData();
    if (basicData != null) {
      print('🎨 [AI 모달] 기본양식 데이터 발견');
      _initializeWithData(basicData);
      return;
    }

    // 데이터가 없으면 빈 에디터 표시
    print('⚠️ [AI 모달] Pending 데이터 없음, 빈 에디터 표시');
    _initializeWebview();
  }

  /// 데이터로 초기화
  void _initializeWithData(Map<String, dynamic> data) {
    setState(() {
      _aiGeneratedHtml = data['html_content'] as String?;

      // 공통 필드 초기화 (서버에서 받은 값)
      _documentTitle =
          data['title'] as String? ?? data['document_title'] as String?;
      _draftingDepartment = data['department'] as String? ??
          data['drafting_department'] as String?;
      _drafter = data['drafter'] as String?;
      _draftingDate = data['drafting_date'] != null
          ? DateTime.tryParse(data['drafting_date'].toString())
          : null;
      _approvalLine = data['approval_line'] as String?;
      _referencePersons = data['reference_persons'] as String?;
    });

    print('🎨 [AI 모달] 초기화 완료:');
    print('   - 제목: $_documentTitle');
    print('   - 부서: $_draftingDepartment');
    print('   - 기안자: $_drafter');
    print('   - HTML 길이: ${_aiGeneratedHtml?.length ?? 0}');

    _initializeWebview();
  }

  /// 웹뷰 초기화
  Future<void> _initializeWebview() async {
    if (_isWebviewInitialized) return;

    try {
      print('🌐 [AI 모달] 웹뷰 초기화 시작...');

      _webviewController = WebviewController();
      await _webviewController!.initialize();

      // 웹뷰 메시지 리스너 (JavaScript → Flutter)
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

        // 로딩 완료 시 HTML 주입
        if (!isLoading && _aiGeneratedHtml != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_webviewController != null) {
              _injectHtml(_aiGeneratedHtml!);
            }
          });
        }
      });

      // /default 라우트 로드
      const webUrl = 'http://210.107.96.193:3001/default';
      await _webviewController!.loadUrl(webUrl);

      if (mounted) {
        setState(() {
          _isWebviewInitialized = true;
        });
      }

      print('✅ [AI 모달] 웹뷰 초기화 완료');
    } catch (e) {
      print('❌ [AI 모달] 웹뷰 초기화 실패: $e');
      if (mounted) {
        setState(() {
          _isWebviewLoading = false;
          _webviewError = '웹뷰 초기화 실패: $e';
        });
      }
    }
  }

  /// AI 생성 HTML 주입
  Future<void> _injectHtml(String htmlContent) async {
    if (_webviewController == null) return;

    try {
      print('💉 [AI 모달] HTML 주입 시작...');

      // HTML 이스케이프 처리
      final escapedHtml = htmlContent
          .replaceAll('\\', '\\\\')
          .replaceAll('`', '\\`')
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r');

      // JavaScript로 HTML 주입
      await _webviewController!.executeScript("""
        (function() {
          try {
            if (typeof window.setEditorContent === 'function') {
              window.setEditorContent(`$escapedHtml`);
              console.log('✅ HTML 주입 완료');
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

      print('✅ [AI 모달] HTML 주입 완료');
    } catch (e) {
      print('❌ [AI 모달] HTML 주입 실패: $e');
      if (mounted) {
        setState(() {
          _webviewError = 'HTML 주입 실패: $e';
        });
      }
    }
  }

  /// 웹뷰 메시지 처리 (JavaScript → Flutter)
  void _handleWebMessage(String message) {
    print('📨 [AI 모달] 메시지 수신: $message');

    try {
      final data = json.decode(message);

      if (data['action'] == 'saveDocument') {
        final htmlContent = data['content'] as String?;
        if (htmlContent != null) {
          _handleSave(htmlContent);
        }
      }
    } catch (e) {
      print('❌ [AI 모달] 메시지 파싱 실패: $e');
    }
  }

  /// 문서 저장
  void _handleSave(String htmlContent) {
    print('💾 [AI 모달] 문서 저장: ${htmlContent.length} bytes');

    // TODO: 서버로 전송
    // await ApiService.saveApprovalDocument(htmlContent);

    // 성공 메시지 전송
    _sendMessageToWebView({'status': 'success', 'message': '저장되었습니다.'});

    // 모달 닫기
    _closeModal();
  }

  /// Flutter → JavaScript 메시지 전송
  Future<void> _sendMessageToWebView(Map<String, dynamic> data) async {
    if (_webviewController == null) return;

    try {
      final jsonData = json.encode(data);
      await _webviewController!.executeScript("""
        if (window.handleFlutterMessage) {
          window.handleFlutterMessage($jsonData);
        }
      """);
    } catch (e) {
      print('❌ [AI 모달] 메시지 전송 실패: $e');
    }
  }

  /// 모달 닫기
  void _closeModal() async {
    // 슬라이드 애니메이션 완료 대기
    await _slideController.reverse();

    if (widget.onClose != null) {
      widget.onClose!();
    } else if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      // pop 애니메이션 완료 대기 후 스낵바 표시
      await Future.delayed(const Duration(milliseconds: 100));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('결재 상신이 취소되었습니다.'),
          duration: Duration(milliseconds: 1500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final modalWidth = screenWidth * 0.6; // 화면의 60%

    return SlideTransition(
      position: _slideAnimation,
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

            // 공통 필수 영역 (부서, 기안자 등)
            _buildCommonFields(isDarkTheme),

            // 웹뷰 영역
            Expanded(
              child: _buildWebView(isDarkTheme),
            ),

            // 푸터 버튼
            _buildFooter(isDarkTheme),
          ],
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
              'AI 전자결재 상신',
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

  /// 공통 필수 영역 (부서, 기안자 등)
  Widget _buildCommonFields(bool isDarkTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF1A202C) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color:
                isDarkTheme ? const Color(0xFF4A5568) : const Color(0xFFE9ECEF),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목
          _buildFieldRow(
            label: '문서 제목',
            value: _documentTitle,
            isDarkTheme: isDarkTheme,
            onChanged: (value) => setState(() => _documentTitle = value),
          ),
          const SizedBox(height: 12),

          // 부서
          _buildFieldRow(
            label: '기안 부서',
            value: _draftingDepartment,
            isDarkTheme: isDarkTheme,
            onChanged: (value) => setState(() => _draftingDepartment = value),
          ),
          const SizedBox(height: 12),

          // 기안자
          _buildFieldRow(
            label: '기안자',
            value: _drafter,
            isDarkTheme: isDarkTheme,
            onChanged: (value) => setState(() => _drafter = value),
          ),
          const SizedBox(height: 12),

          // 기안일
          Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  '기안일',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color:
                        isDarkTheme ? Colors.white70 : const Color(0xFF6C757D),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _draftingDate != null
                      ? '${_draftingDate!.year}-${_draftingDate!.month.toString().padLeft(2, '0')}-${_draftingDate!.day.toString().padLeft(2, '0')}'
                      : '미지정',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 결재선
          _buildFieldRow(
            label: '결재선',
            value: _approvalLine,
            isDarkTheme: isDarkTheme,
            onChanged: (value) => setState(() => _approvalLine = value),
          ),
          const SizedBox(height: 12),

          // 참조자
          _buildFieldRow(
            label: '참조자',
            value: _referencePersons,
            isDarkTheme: isDarkTheme,
            onChanged: (value) => setState(() => _referencePersons = value),
          ),
        ],
      ),
    );
  }

  /// 필드 행 (라벨 + 입력)
  Widget _buildFieldRow({
    required String label,
    required String? value,
    required bool isDarkTheme,
    required Function(String) onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDarkTheme ? Colors.white70 : const Color(0xFF6C757D),
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: TextEditingController(text: value ?? ''),
            onChanged: onChanged,
            style: TextStyle(
              fontSize: 14,
              color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
            ),
            decoration: InputDecoration(
              hintText: '입력해주세요',
              hintStyle: TextStyle(
                color: isDarkTheme ? Colors.white38 : const Color(0xFFB0B0B0),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(
                  color: isDarkTheme
                      ? const Color(0xFF4A5568)
                      : const Color(0xFFE9ECEF),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(
                  color: isDarkTheme
                      ? const Color(0xFF4A5568)
                      : const Color(0xFFE9ECEF),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(
                  color: Color(0xFF4A6CF7),
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 웹뷰
  Widget _buildWebView(bool isDarkTheme) {
    if (_webviewError != null) {
      return _buildError(isDarkTheme);
    }

    if (_isWebviewLoading && !_isWebviewInitialized) {
      return _buildLoading(isDarkTheme);
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color:
              isDarkTheme ? const Color(0xFF4A5568) : const Color(0xFFE9ECEF),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            if (_webviewController != null)
              Positioned.fill(
                child: Webview(_webviewController!),
              ),
            if (_isWebviewLoading)
              Positioned.fill(
                child: Container(
                  color: isDarkTheme
                      ? const Color(0xFF1A202C).withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.8),
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
    );
  }

  /// 로딩
  Widget _buildLoading(bool isDarkTheme) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF4A6CF7),
            ),
            const SizedBox(height: 16),
            Text(
              '에디터를 불러오는 중...',
              style: TextStyle(
                color: isDarkTheme ? Colors.white70 : const Color(0xFF6C757D),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 에러
  Widget _buildError(bool isDarkTheme) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Center(
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
                });
                _initializeWebview();
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
      ),
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
            ),
            child: const Text('취소'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              // 웹뷰에 저장 요청
              _webviewController?.executeScript("""
                if (window.requestSave) {
                  window.requestSave();
                }
              """);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A6CF7),
              foregroundColor: Colors.white,
            ),
            child: const Text('상신하기'),
          ),
        ],
      ),
    );
  }
}
