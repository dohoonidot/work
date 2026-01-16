import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/features/leave/leave_models.dart';
import 'package:ASPN_AI_AGENT/shared/services/leave_api_service.dart';
import 'package:ASPN_AI_AGENT/shared/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ASPN_AI_AGENT/models/leave_management_models.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:ASPN_AI_AGENT/provider/leave_management_provider.dart';
import 'package:ASPN_AI_AGENT/features/leave/approver_selection_modal.dart';
import 'package:ASPN_AI_AGENT/core/config/app_config.dart';

/// 휴가 작성 모달 위젯
/// 사용자가 수동으로 휴가신청서를 작성하는 폼
class LeaveRequestManualModal extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const LeaveRequestManualModal({
    super.key,
    this.onClose,
  });

  @override
  ConsumerState<LeaveRequestManualModal> createState() =>
      _LeaveRequestManualModalState();
}

class _LeaveRequestManualModalState
    extends ConsumerState<LeaveRequestManualModal>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormBuilderState>();
  Map<String, String?> _fieldErrors = {};
  bool _isSubmitting = false;

  // 폼 데이터
  String? _selectedVacationType;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _reason;
  List<String> _selectedApproverIds = []; // 선택된 승인자 ID 리스트
  Map<String, String> _approverNames = {}; // 승인자 ID -> 이름 매핑
  bool _useNextYearLeave = false; // 내년 정기휴가 사용하기
  bool _useHalfDay = false; // 반차 사용 여부
  String? _halfDayType; // 오전반차/오후반차
  List<CcPerson> _ccList = [];
  bool _isLeaveStatusExpanded = true; // 휴가 현황 섹션 펼쳐진 상태 (디폴트)

  // 내 휴가 현황 데이터
  List<LeaveStatus> _leaveStatusList = [];
  bool _isLoadingLeaveStatus = false;

  // 휴가 종류 목록 (API 기반)
  List<String> _availableLeaveTypes = [];
  bool _isLoadingLeaveTypes = false;

  // 내년 정기휴가 상태
  List<NextYearLeaveStatus>? _nextYearLeaveStatus;
  bool _isLoadingNextYearLeave = false;

  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();

    // 애니메이션 컨트롤러 초기화 (페이드 + 스케일)
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // 모달이 생성되면 슬라이드 인 애니메이션 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slideController.forward();
      // 휴가 종류 목록 로드
      _loadLeaveTypes();
      // 내 휴가 현황 데이터 로드
      _loadLeaveStatus();
      // 저장된 결재라인 데이터 로드
      _loadApprovalLine();
    });
  }

  /// 내 휴가 현황 로드 (API 연동)
  Future<void> _loadLeaveStatus() async {
    setState(() {
      _isLoadingLeaveStatus = true;
    });

    try {
      final userId = ref.read(userIdProvider);
      if (userId == null || userId.isEmpty) {
        print('⚠️ [LeaveRequestManualModal] 사용자 ID가 없어 휴가 현황을 불러올 수 없습니다.');
        setState(() {
          _isLoadingLeaveStatus = false;
        });
        return;
      }

      print('📊 [LeaveRequestManualModal] 휴가 현황 조회 시작: userId=$userId');

      final leaveData = await LeaveApiService.getLeaveManagement(userId);

      print(
          '✅ [LeaveRequestManualModal] 휴가 현황 조회 완료: ${leaveData.leaveStatus.length}개');

      if (mounted) {
        setState(() {
          _leaveStatusList = leaveData.leaveStatus;
          _isLoadingLeaveStatus = false;
        });
      }
    } catch (e) {
      print('❌ [LeaveRequestManualModal] 휴가 현황 조회 실패: $e');
      if (mounted) {
        setState(() {
          _leaveStatusList = [];
          _isLoadingLeaveStatus = false;
        });
      }
    }
  }

  /// 저장된 결재라인 로드 (API 연동)
  Future<void> _loadApprovalLine() async {
    try {
      final userId = ref.read(userIdProvider);
      if (userId == null || userId.isEmpty) {
        print('⚠️ [LeaveRequestManualModal] 사용자 ID가 없어 결재라인을 불러올 수 없습니다.');
        return;
      }

      print('💾 [LeaveRequestManualModal] 결재라인 조회 시작: userId=$userId');

      final response = await LeaveApiService.loadApprovalLine(userId: userId);

      if (response.isSuccess) {
        // 승인자 데이터 설정
        setState(() {
          _selectedApproverIds =
              response.approvalLine.map((item) => item.approverId).toList();

          _approverNames.clear();
          for (final item in response.approvalLine) {
            _approverNames[item.approverId] = item.approverName;
          }

          // 참조자 데이터 설정
          _ccList = response.ccList
              .map((item) => CcPerson(
                    name: item.name,
                    department: item.department,
                    userId: item.userId,
                  ))
              .toList();
        });

        print('✅ [LeaveRequestManualModal] 결재라인 조회 완료');
        print('💾 승인자: ${_selectedApproverIds.length}명');
        print('💾 참조자: ${_ccList.length}명');
      } else {
        print('⚠️ [LeaveRequestManualModal] 저장된 결재라인이 없습니다: ${response.error}');
        // 저장된 결재라인이 없는 경우는 기본 상태 유지 (빈 리스트)
      }
    } catch (e) {
      print('❌ [LeaveRequestManualModal] 결재라인 조회 실패: $e');
      // 에러가 발생해도 기본 상태 유지
    }
  }

  /// 휴가 종류 목록 로드 (API 호출)
  Future<void> _loadLeaveTypes() async {
    try {
      setState(() {
        _isLoadingLeaveTypes = true;
      });

      // 현재 로그인된 사용자 ID 가져오기
      final currentUserId = ref.read(userIdProvider) ?? '';
      if (currentUserId.isEmpty) {
        print('⚠️ 로그인 정보가 없어 휴가 종류를 불러올 수 없습니다.');
        setState(() {
          _isLoadingLeaveTypes = false;
          _availableLeaveTypes = []; // 기본값
        });
        return;
      }

      print(
          '📋 [LeaveRequestManualModal] 휴가 종류 목록 로드 시작: userId=$currentUserId');

      // API 직접 호출
      final url = Uri.parse('${AppConfig.baseUrl}/leave/user/getLeaveTypes'); //
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({
        'user_id': currentUserId,
      });

      final response = await http.post(url, headers: headers, body: body);
      print(
          '📋 [LeaveRequestManualModal] 휴가 종류 API 응답 상태 코드: ${response.statusCode}');

      if (mounted) {
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          final leaveTypes = (data['leave_types'] as List<dynamic>?)
                  ?.map((item) => item['leave_type'] as String)
                  .toList() ??
              [];

          setState(() {
            _isLoadingLeaveTypes = false;
            _availableLeaveTypes = leaveTypes.isNotEmpty ? leaveTypes : [];
            print(
                '✅ [LeaveRequestManualModal] 휴가 종류 ${leaveTypes.length}개 로드 완료: ${leaveTypes}');

            // 첫 번째 휴가종류를 자동 선택
            if (_availableLeaveTypes.isNotEmpty &&
                _selectedVacationType == null) {
              _selectedVacationType = _availableLeaveTypes[0];
              _formKey.currentState?.fields['vacation_type']
                  ?.didChange(_selectedVacationType);
            }
          });
        } else {
          print(
              '⚠️ [LeaveRequestManualModal] 휴가 종류 API 실패: ${response.statusCode}');
          setState(() {
            _isLoadingLeaveTypes = false;
            _availableLeaveTypes = []; // 폴백
          });
        }
      }
    } catch (e) {
      print('❌ [LeaveRequestManualModal] 휴가 종류 로드 중 오류 발생: $e');
      if (mounted) {
        setState(() {
          _isLoadingLeaveTypes = false;
          _availableLeaveTypes = []; // 폴백
        });
      }
    }
  }

  /// 내년 정기휴가 상태 조회
  Future<void> _loadNextYearLeaveStatus() async {
    setState(() {
      _isLoadingNextYearLeave = true;
    });

    try {
      final userId = ref.read(userIdProvider);
      if (userId == null || userId.isEmpty) {
        print('⚠️ [LeaveRequestManualModal] 사용자 ID가 없습니다.');
        setState(() {
          _isLoadingNextYearLeave = false;
          _nextYearLeaveStatus = null;
        });
        return;
      }

      print('📅 [LeaveRequestManualModal] 내년 정기휴가 조회 시작: userId=$userId');
      final response =
          await LeaveApiService.getNextYearLeaveStatus(userId: userId);

      if (response.error != null) {
        print('❌ [LeaveRequestManualModal] 내년 정기휴가 조회 실패: ${response.error}');
        setState(() {
          _isLoadingNextYearLeave = false;
          _nextYearLeaveStatus = null;
        });
        // 에러 메시지 표시 (선택사항)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('내년 정기휴가 조회에 실패했습니다: ${response.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        print(
            '✅ [LeaveRequestManualModal] 내년 정기휴가 조회 완료: ${response.leaveStatus.length}개');
        setState(() {
          _nextYearLeaveStatus = response.leaveStatus;
          _isLoadingNextYearLeave = false;

          // 첫 번째 휴가종류를 자동 선택
          if (response.leaveStatus.isNotEmpty) {
            _selectedVacationType = response.leaveStatus[0].leaveType;
            _formKey.currentState?.fields['vacationType']
                ?.didChange(_selectedVacationType);
          }
        });
      }
    } catch (e) {
      print('❌ [LeaveRequestManualModal] 내년 정기휴가 조회 중 오류: $e');
      setState(() {
        _isLoadingNextYearLeave = false;
        _nextYearLeaveStatus = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('내년 정기휴가 조회 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  /// 모달 닫기 (슬라이드 아웃 애니메이션 포함)
  void _closeModal() async {
    // ScaffoldMessenger 미리 가져오기
    final messenger = mounted ? ScaffoldMessenger.of(context) : null;

    // 슬라이드 애니메이션 완료 대기
    await _slideController.reverse();
    if (widget.onClose != null) {
      widget.onClose!();
    }
    if (mounted) {
      Navigator.of(context).pop();
    }

    // pop 애니메이션 완료 대기 후 스낵바 표시
    if (messenger != null) {
      await Future.delayed(const Duration(milliseconds: 100));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('상신이 취소되었습니다.'),
          duration: Duration(milliseconds: 1500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(_slideController),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(_slideController),
          child: Container(
            width: 750,
            height: 700,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1A1D1F)
                  : Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _buildFormContent(),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 모달 헤더 (제목, 닫기 버튼)
  Widget _buildHeader() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: isDarkTheme
                  ? const Color(0xFF2D3748)
                  : const Color(0xFFE9ECEF),
              width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4A6CF7).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.beach_access_outlined,
              color: Color(0xFF4A6CF7),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '휴가 작성',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
              ),
            ),
          ),
          IconButton(
            onPressed: _closeModal,
            icon: const Icon(
              Icons.close,
              color: Color(0xFF8B95A1),
            ),
            tooltip: '닫기',
          ),
        ],
      ),
    );
  }

  /// 폼 내용
  Widget _buildFormContent() {
    final draftValues = <String, dynamic>{}; // Placeholder

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: FormBuilder(
        key: _formKey,
        initialValue: draftValues,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLeaveBalanceSection(),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _buildSectionTitle('기본 정보', Icons.person_outline),
                ),
                // 내년 정기휴가 사용하기 체크박스
                Transform.translate(
                  offset: const Offset(-3, 0),
                  child: Checkbox(
                    value: _useNextYearLeave,
                    onChanged: (value) async {
                      final isChecked = value ?? false;

                      if (isChecked) {
                        // 체크 시 API 호출
                        await _loadNextYearLeaveStatus();
                      } else {
                        // 체크 해제 시 상태 초기화
                        setState(() {
                          _nextYearLeaveStatus = null;
                          _selectedVacationType = null;
                        });
                        // 폼 필드도 초기화
                        _formKey.currentState?.fields['vacationType']
                            ?.didChange(null);
                      }

                      setState(() {
                        _useNextYearLeave = isChecked;
                      });
                      _updateField('useNextYearLeave', value);
                    },
                    activeColor: const Color(0xFF4A6CF7),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '내년 정기휴가 사용하기',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF1A1D1F),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildBasicInfoFields(),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildSectionTitle('휴가 상세', Icons.event_note_outlined),
                const SizedBox(width: 10),
                _buildHalfDayCheckbox(),
                if (_useHalfDay) ...[
                  const SizedBox(width: 10),
                  _buildHalfDayTimeSelection(),
                ],
              ],
            ),
            const SizedBox(height: 6),
            _buildVacationDetailFields(),
            const SizedBox(height: 4),
            _buildApproversAndReferenceFields(),
          ],
        ),
      ),
    );
  }

  /// 휴가 잔여량 섹션 (접을 수 있음)
  Widget _buildLeaveBalanceSection() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // API로 로드한 휴가 현황 사용
    final leaveStatus = _leaveStatusList;

    return Container(
      decoration: BoxDecoration(
        color: isDarkTheme ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDarkTheme
                ? const Color(0xFF4A5568)
                : const Color(0xFFE9ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 클릭 가능한 헤더
          GestureDetector(
            onTap: () {
              setState(() {
                _isLeaveStatusExpanded = !_isLeaveStatusExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '내 휴가 현황',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkTheme
                            ? Colors.white
                            : const Color(0xFF1A1D1F),
                      ),
                    ),
                  ),
                  Icon(
                    _isLeaveStatusExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: isDarkTheme
                        ? const Color(0xFFA0AEC0)
                        : const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),

          // 접힐 수 있는 내용
          if (_isLeaveStatusExpanded) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                children: [
                  // 로딩 상태 표시
                  if (_isLoadingLeaveStatus) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: const Color(0xFF4A6CF7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '휴가 현황 로딩 중...',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkTheme
                                    ? Colors.grey[300]
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (leaveStatus.isNotEmpty) ...[
                    // API로 받아온 휴가 현황 표시
                    ...leaveStatus.map((status) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              status.leaveType,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkTheme
                                    ? Colors.grey[300]
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkTheme
                                      ? Colors.grey[300]
                                      : const Color(0xFF6B7280),
                                ),
                                children: [
                                  const TextSpan(text: '남은 일수 '),
                                  TextSpan(
                                    text:
                                        '${status.remainDays.toStringAsFixed(1)}일',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: isDarkTheme
                                          ? const Color(0xFF60A5FA)
                                          : const Color(0xFF3B82F6),
                                    ),
                                  ),
                                  const TextSpan(text: ' / 허용 일수 '),
                                  TextSpan(
                                    text:
                                        '${status.totalDays.toStringAsFixed(1)}일',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: isDarkTheme
                                          ? const Color(0xFF34D399)
                                          : const Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ] else ...[
                    // 데이터가 없는 경우 메시지 표시
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '휴가 현황 정보가 없습니다.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkTheme
                              ? Colors.grey[300]
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
          ),
        ),
      ],
    );
  }

  /// 기본 정보 필드들
  Widget _buildBasicInfoFields() {
    return Column(
      children: [
        Consumer(
          builder: (context, ref, child) {
            final currentUserId = ref.watch(userIdProvider) ?? '';
            return FormBuilderTextField(
              name: 'applicantName',
              decoration: _buildInputDecoration('신청자'),
              readOnly: true,
              initialValue: currentUserId,
              style: const TextStyle(
                color: Color(0xFF6C757D),
                fontSize: 14,
              ),
              onChanged: (value) => _updateField('applicantName', value),
            );
          },
        ),
        const SizedBox(height: 16),
        FormBuilderDropdown<String>(
          name: 'vacationType',
          decoration: _buildInputDecoration('휴가종류', isRequired: true),
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF1A1D1F),
            fontSize: 14,
          ),
          validator: FormBuilderValidators.required(errorText: '휴가종류는 필수입니다'),
          items: (_isLoadingNextYearLeave || _isLoadingLeaveTypes)
              ? [
                  DropdownMenuItem(
                    value: null,
                    child: Text(
                      '로딩 중...',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ]
              : _getVacationTypeItems().map((type) {
                  final daysInfo = _getVacationTypeDaysInfo(type);
                  return DropdownMenuItem(
                    value: type,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          type,
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : const Color(0xFF1A1D1F),
                          ),
                        ),
                        if (daysInfo != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            daysInfo,
                            style: TextStyle(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedVacationType = value;
            });
            _updateField('vacationType', value);
          },
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  /// 휴가 상세 필드들
  Widget _buildVacationDetailFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: FormBuilderDateTimePicker(
                name: 'vacationStart',
                inputType: InputType.date,
                decoration: _buildInputDecoration('시작일', isRequired: true),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF1A1D1F),
                  fontSize: 14,
                ),
                validator:
                    FormBuilderValidators.required(errorText: '시작일은 필수입니다'),
                onChanged: (value) {
                  setState(() {
                    _startDate = value;
                  });
                  _updateField('vacationStart', value);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FormBuilderDateTimePicker(
                name: 'vacationEnd',
                inputType: InputType.date,
                decoration: _buildInputDecoration('종료일', isRequired: true),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF1A1D1F),
                  fontSize: 14,
                ),
                validator:
                    FormBuilderValidators.required(errorText: '종료일은 필수입니다'),
                onChanged: (value) {
                  setState(() {
                    _endDate = value;
                  });
                  _updateField('vacationEnd', value);
                },
              ),
            ),
            const SizedBox(width: 12),
            // 빈 공간 (반차 시간 선택은 위쪽 Row에 표시됨)
            Expanded(
              flex: 1,
              child: const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FormBuilderTextField(
          name: 'vacationReason',
          decoration: _buildInputDecoration('휴가사유', isRequired: false),
          maxLines: 6,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF1A1D1F),
            fontSize: 14,
          ),
          onChanged: (value) {
            setState(() {
              _reason = value;
            });
            _updateField('vacationReason', value);
          },
        ),
      ],
    );
  }

  /// 승인자와 참조자 필드를 나란히 배치
  Widget _buildApproversAndReferenceFields() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 승인자 - 왼쪽 50%
        Expanded(
          flex: 1,
          child: _buildApproversField(),
        ),
        const SizedBox(width: 12),
        // 참조자 - 오른쪽 50%
        Expanded(
          flex: 1,
          child: _buildReferenceField(),
        ),
      ],
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
                label: const Text(
                  '승인자 선택',
                  style: TextStyle(fontSize: 12),
                ),
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
                label: const Text(
                  '순차결재',
                  style: TextStyle(fontSize: 12),
                ),
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

  /// 하단 버튼들
  Widget _buildFooter() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
              color: isDarkTheme
                  ? const Color(0xFF2D3748)
                  : const Color(0xFFE9ECEF),
              width: 1),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitDraft,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isSubmitting ? Colors.grey : const Color(0xFF4A6CF7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '상신 중...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      '휴가 상신',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// 입력 필드 데코레이션
  InputDecoration _buildInputDecoration(String label,
      {bool isRequired = false, String? errorText}) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      labelText: isRequired ? '$label *' : label,
      labelStyle: TextStyle(
        color: isDarkTheme ? const Color(0xFFA0AEC0) : const Color(0xFF8B95A1),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      errorText: errorText,
      filled: true,
      fillColor:
          isDarkTheme ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
            color:
                isDarkTheme ? const Color(0xFF4A5568) : const Color(0xFFE9ECEF),
            width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF4A6CF7), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  /// 필드 값 업데이트
  void _updateField(String key, dynamic value) {
    if (_fieldErrors.containsKey(key)) {
      setState(() {
        _fieldErrors.remove(key);
      });
    }
  }

  /// 결재 라인 저장
  Future<void> _saveApprovalLine() async {
    // 승인자가 선택되지 않은 경우 - 필수값 검증
    if (_selectedApproverIds.isEmpty) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('승인자 필수 선택'),
          content: const Text('휴가 신청을 위해서는 반드시 승인자를 선택해야 합니다.\n승인자를 선택해주세요.'),
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

      // API 요청 생성
      final request = ApprovalLineSaveRequest(
        userId: currentUserId,
        approvalLine: approvalLine,
        ccList: ccList,
      );

      print('💾 결재라인 저장 API 요청 시작');
      print('💾 userId: $currentUserId');
      print('💾 approvalLine: ${approvalLine.length}명');
      print('💾 ccList: ${ccList.length}명');

      // API 호출
      final response = await LeaveApiService.saveApprovalLine(request: request);

      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('결재라인이 성공적으로 저장되었습니다'),
            backgroundColor: Color(0xFF20C997),
            duration: Duration(seconds: 2),
          ),
        );
        print('✅ 결재라인 저장 성공');
      } else {
        throw Exception(response.error ?? '결재라인 저장에 실패했습니다');
      }
    } catch (e) {
      print('❌ 결재라인 저장 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('결재라인 저장 중 오류가 발생했습니다: $e'),
          backgroundColor: const Color(0xFFDC3545),
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
      });

      // 승인자 이름 정보 가져오기
      await _fetchApproverNames();
    }
  }

  /// 선택된 승인자들의 이름 정보 가져오기
  Future<void> _fetchApproverNames() async {
    try {
      final response = await LeaveApiService.getApprover();
      if (response.isSuccess) {
        setState(() {
          _approverNames.clear();
          for (final approver in response.approverList) {
            if (_selectedApproverIds.contains(approver.approverId)) {
              _approverNames[approver.approverId] = approver.approverName;
            }
          }
        });
        print('✅ 승인자 이름 정보 로드 완료: $_approverNames');
      }
    } catch (e) {
      print('❌ 승인자 이름 정보 로드 실패: $e');
    }
  }

  /// 휴가 상신
  Future<void> _submitDraft() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('입력 정보를 확인해주세요'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    _formKey.currentState?.save();

    // 필수 필드 검증
    if (_selectedVacationType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('휴가종류를 선택해주세요'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('휴가 시작일과 종료일을 선택해주세요'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    // 휴가 사유는 선택 입력 항목으로 변경됨

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('상신 확인'),
        content: const Text('휴가신청서를 상신하시겠습니까?'),
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
        // 현재 로그인된 사용자 ID 가져오기
        final currentUserId = ref.read(userIdProvider) ?? '';
        if (currentUserId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('로그인 정보를 찾을 수 없습니다. 다시 로그인해주세요.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 1),
            ),
          );
          return;
        }

        // 결재선 데이터 생성 (순차결재)
        final List<LeaveRequestApprovalLine> approvalLine = [];
        for (int i = 0; i < _selectedApproverIds.length; i++) {
          final approverId = _selectedApproverIds[i];
          final nextApproverId = i < _selectedApproverIds.length - 1
              ? _selectedApproverIds[i + 1]
              : '';
          final approverName = _approverNames[approverId] ?? '';

          approvalLine.add(LeaveRequestApprovalLine(
            approverId: approverId,
            nextApproverId: nextApproverId,
            approvalSeq: i + 1,
            approverName: approverName,
          ));
        }

        // 휴가 상신 요청 객체 생성
        final request = LeaveRequestRequest(
          userId: currentUserId,
          leaveType: _selectedVacationType!,
          startDate: _startDate!,
          endDate: _endDate!,
          approvalLine: approvalLine,
          ccList: _ccList,
          reason: _reason?.trim() ?? '',
          halfDaySlot: _getHalfDaySlotValue(),
          isNextYear: _useNextYearLeave ? 1 : 0,
        );

        // API 요청 데이터 로그 출력
        print('🚀 휴가 상신 API 요청 데이터:');
        print('  - userId: ${request.userId}');
        print('  - leaveType: ${request.leaveType}');
        print('  - startDate: ${request.startDate}');
        print('  - endDate: ${request.endDate}');
        print(
            '  - approvalLine: ${request.approvalLine.map((a) => '${a.approverName}(seq:${a.approvalSeq})').join(' -> ')}');
        print(
            '  - ccList: ${request.ccList.map((cc) => '${cc.name}(dept:${cc.department})').join(', ')}');
        print('  - reason: ${request.reason}');
        print('  - halfDaySlot: ${request.halfDaySlot}');
        print('  - isNextYear: ${request.isNextYear}');

        // API 호출
        final response = await LeaveApiService.submitLeaveRequestNew(
          request: request,
        );

        setState(() {
          _isSubmitting = false;
        });

        if (response.isSuccess) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('휴가신청서가 성공적으로 상신되었습니다'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 1),
              ),
            );

            // 휴가 관리 데이터 새로고침
            ref
                .read(leaveManagementProvider.notifier)
                .loadLeaveManagementData(currentUserId);

            // 제출 완료 시 모달 완전히 닫기
            await _slideController.reverse();
            _closeModal();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response.error ?? '휴가 상신에 실패했습니다'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 1),
              ),
            );
          }
        }
      } catch (e) {
        setState(() {
          _isSubmitting = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('휴가 상신 중 오류가 발생했습니다: $e'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    }
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
            label: const Text(
              '참조자 선택',
              style: TextStyle(fontSize: 12),
            ),
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

  /// 참조자 선택 모달 표시
  void _showReferenceSelection() {
    showDialog(
      context: context,
      builder: (context) => ReferenceSelectionDialog(
        currentReferences: _ccList,
        onSelectionChanged: (newReferences) {
          setState(() {
            _ccList = newReferences;
          });
        },
      ),
    );
  }

  /// 반차 사용 체크박스
  Widget _buildHalfDayCheckbox() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 0.8,
          child: Checkbox(
            value: _useHalfDay,
            onChanged: (value) {
              setState(() {
                _useHalfDay = value ?? false;
                if (!_useHalfDay) {
                  _halfDayType = null;
                } else {
                  // 반차 사용 체크 시 오전을 기본으로 선택
                  _halfDayType = '오전반차';
                }
              });
              _updateField('useHalfDay', value);
            },
            activeColor: const Color(0xFF4A6CF7),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '반차 사용',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color:
                isDarkTheme ? const Color(0xFFA0AEC0) : const Color(0xFF8B95A1),
          ),
        ),
      ],
    );
  }

  /// 반차 시간 선택 위젯 (체크박스가 체크되었을 때만 표시)
  Widget _buildHalfDayTimeSelection() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 0.9,
          child: Radio<String>(
            value: '오전반차',
            groupValue: _halfDayType,
            onChanged: (value) {
              setState(() {
                _halfDayType = value;
              });
              _updateField('halfDayType', value);
            },
            activeColor: const Color(0xFF4A6CF7),
          ),
        ),
        Text(
          '오전',
          style: TextStyle(
            fontSize: 12,
            color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
          ),
        ),
        const SizedBox(width: 12),
        Transform.scale(
          scale: 0.9,
          child: Radio<String>(
            value: '오후반차',
            groupValue: _halfDayType,
            onChanged: (value) {
              setState(() {
                _halfDayType = value;
              });
              _updateField('halfDayType', value);
            },
            activeColor: const Color(0xFF4A6CF7),
          ),
        ),
        Text(
          '오후',
          style: TextStyle(
            fontSize: 12,
            color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            setState(() {
              _useHalfDay = false;
              _halfDayType = null;
            });
          },
          child: const Icon(
            Icons.close,
            size: 18,
            color: Color(0xFF8B95A1),
          ),
        ),
      ],
    );
  }

  /// 반차 타입을 API 형식으로 변환
  String _getHalfDaySlotValue() {
    if (_useHalfDay && _halfDayType == '오전반차') {
      return 'AM';
    } else if (_useHalfDay && _halfDayType == '오후반차') {
      return 'PM';
    }

    return 'ALL'; // 반차를 사용하지 않거나 기본값
  }

  /// 휴가종류 드롭다운 아이템 목록 반환
  List<String> _getVacationTypeItems() {
    // 내년 정기휴가 사용하기 체크 시 서버 응답의 leave_type만 표시 (최우선)
    if (_useNextYearLeave &&
        _nextYearLeaveStatus != null &&
        _nextYearLeaveStatus!.isNotEmpty) {
      return _nextYearLeaveStatus!.map((status) => status.leaveType).toList();
    }

    // API에서 받아온 휴가 종류가 있으면 우선 사용
    if (_availableLeaveTypes.isNotEmpty) {
      return _availableLeaveTypes;
    }

    // API에서 받아온 값만 사용, 기본 목록 없음
    return [];
  }

  /// 휴가종류에 대한 잔여일수/총일수 정보 반환
  String? _getVacationTypeDaysInfo(String? vacationType) {
    if (!_useNextYearLeave ||
        _nextYearLeaveStatus == null ||
        vacationType == null) {
      return null;
    }

    final status = _nextYearLeaveStatus!.firstWhere(
      (s) => s.leaveType == vacationType,
      orElse: () => _nextYearLeaveStatus!.first,
    );

    return '${status.remainDays.toStringAsFixed(1)}일 / ${status.totalDays.toStringAsFixed(1)}일';
  }
}

/// 참조자 선택 다이얼로그
class ReferenceSelectionDialog extends StatefulWidget {
  final List<CcPerson> currentReferences;
  final Function(List<CcPerson>) onSelectionChanged;

  const ReferenceSelectionDialog({
    super.key,
    required this.currentReferences,
    required this.onSelectionChanged,
  });

  @override
  State<ReferenceSelectionDialog> createState() =>
      _ReferenceSelectionDialogState();
}

class _ReferenceSelectionDialogState extends State<ReferenceSelectionDialog> {
  late List<CcPerson> _selectedReferences;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  Set<String> _expandedDepartments = {};

  // API 로딩 상태
  bool _isLoadingDepartments = true;
  List<String> _departments = [];

  // 부서별 멤버 로딩 상태

  Map<String, List<CcPerson>> _departmentMembers = {};

  @override
  void initState() {
    super.initState();
    _selectedReferences = List.from(widget.currentReferences);
    _loadCompanyMembers();
  }

  /// 회사 전체 조직도(부서/인원) 로드
  /// - 기존에는 부서 목록 + 부서별 인원을 개별 API로 불러왔지만,
  ///   이제는 `getCompanyMembers` 한 번으로 전체를 가져온다.
  Future<void> _loadCompanyMembers() async {
    setState(() {
      _isLoadingDepartments = true;
    });

    try {
      print('📋 [수동 휴가 상신] 회사 전체 조직도 조회 시작');
      final companyMembers = await ApiService.getCompanyMembers();

      final departments = companyMembers.keys.toList()..sort();
      final Map<String, List<CcPerson>> deptMembers = {};

      companyMembers.forEach((dept, members) {
        deptMembers[dept] = members.map<CcPerson>((m) {
          final name = (m['name'] as String?) ?? '';
          final userId = (m['user_id'] as String?) ?? '';
          print('👤 [수동 휴가 상신] 멤버 생성: $name, user_id: $userId, 전체 데이터: $m');
          return CcPerson(
            name: name,
            department: dept,
            userId: userId.isEmpty ? null : userId,
          );
        }).toList();
      });

      setState(() {
        _departments = departments;
        _departmentMembers = deptMembers;
        _isLoadingDepartments = false;
      });

      print('✅ [수동 휴가 상신] 회사 전체 조직도 로드 완료: ${departments.length}개 부서');
    } catch (e) {
      print('❌ [수동 휴가 상신] 회사 전체 조직도 로드 실패: $e');
      setState(() {
        _isLoadingDepartments = false;
        // 폴백: 기본 부서 설정
        _departments = ['Biz AI사업부'];
        _departmentMembers['Biz AI사업부'] = [
          CcPerson(name: '신주열', department: 'Biz AI사업부', userId: 'user_001'),
          CcPerson(name: '최유연', department: 'Biz AI사업부', userId: 'user_002'),
          CcPerson(name: '김도훈', department: 'Biz AI사업부', userId: 'user_003'),
          CcPerson(name: '한정민', department: 'Biz AI사업부', userId: 'user_004'),
        ];
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
      return _departments;
    }

    List<String> filteredList = [];

    for (final department in _departments) {
      // 부서명에 검색어가 포함되는 경우
      if (department.toLowerCase().contains(_searchText.toLowerCase())) {
        filteredList.add(department);
        continue;
      }

      // 직원명에 검색어가 포함되는 경우
      final employees = _departmentMembers[department] ?? [];
      final hasMatchingEmployee = employees.any((person) =>
          person.name.toLowerCase().contains(_searchText.toLowerCase()));

      if (hasMatchingEmployee) {
        filteredList.add(department);
      }
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

  // 부서의 선택 상태 확인
  bool _isDepartmentSelected(String department) {
    final employees = _departmentMembers[department] ?? [];
    if (employees.isEmpty) return false;

    return employees.every((employee) => _selectedReferences
        .any((selected) => selected.uniqueKey == employee.uniqueKey));
  }

  // 부서의 부분 선택 상태 확인 (일부만 선택된 경우)
  bool _isDepartmentPartiallySelected(String department) {
    final employees = _departmentMembers[department] ?? [];
    if (employees.isEmpty) return false;

    final selectedCount = employees
        .where((employee) => _selectedReferences
            .any((selected) => selected.uniqueKey == employee.uniqueKey))
        .length;
    return selectedCount > 0 && selectedCount < employees.length;
  }

  // 부서 전체 선택/해제
  void _toggleDepartmentSelection(String department, bool? selected) {
    setState(() {
      final employees = _departmentMembers[department] ?? [];

      if (selected == true) {
        // 부서 전체 선택
        for (final employee in employees) {
          if (!_selectedReferences
              .any((selected) => selected.uniqueKey == employee.uniqueKey)) {
            _selectedReferences.add(employee);
          }
        }
      } else {
        // 부서 전체 해제
        _selectedReferences.removeWhere((selected) => employees
            .any((employee) => employee.uniqueKey == selected.uniqueKey));
      }
    });
  }

  // 부서 클릭 시 expand
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
                  onPressed: () => Navigator.pop(context),
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
                                    // 검색 중일 때는 부서 체크박스 숨김
                                    trailing: (_departmentMembers
                                                .containsKey(department) &&
                                            _searchText.isEmpty)
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
                                  if (employees.isEmpty)
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
                                                    person.uniqueKey),
                                            onChanged: (selected) {
                                              print(
                                                  '🔘 체크박스 클릭: ${person.name} (uniqueKey: ${person.uniqueKey})');
                                              print('   선택됨: $selected');
                                              print('   현재 선택된 참조자들:');
                                              for (var ref
                                                  in _selectedReferences) {
                                                print(
                                                    '     - ${ref.name} (uniqueKey: ${ref.uniqueKey})');
                                              }

                                              setState(() {
                                                if (selected == true) {
                                                  if (!_selectedReferences.any(
                                                      (p) =>
                                                          p.uniqueKey ==
                                                          person.uniqueKey)) {
                                                    _selectedReferences
                                                        .add(person);
                                                    print(
                                                        '✅ 추가됨: ${person.name} (uniqueKey: ${person.uniqueKey})');
                                                  }
                                                } else {
                                                  _selectedReferences
                                                      .removeWhere((p) =>
                                                          p.uniqueKey ==
                                                          person.uniqueKey);
                                                  print(
                                                      '❌ 제거됨: ${person.name} (uniqueKey: ${person.uniqueKey})');
                                                }
                                              });
                                            },
                                          ),
                                          onTap: () {
                                            setState(() {
                                              final isSelected =
                                                  _selectedReferences.any((p) =>
                                                      p.uniqueKey ==
                                                      person.uniqueKey);
                                              if (isSelected) {
                                                _selectedReferences.removeWhere(
                                                    (p) =>
                                                        p.uniqueKey ==
                                                        person.uniqueKey);
                                              } else {
                                                if (!_selectedReferences.any(
                                                    (p) =>
                                                        p.uniqueKey ==
                                                        person.uniqueKey)) {
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

/// 승인자 선택 다이얼로그
class ApproverSelectionDialog extends StatefulWidget {
  final String currentApproverId;
  final Function(String) onApproverSelected;

  const ApproverSelectionDialog({
    super.key,
    required this.currentApproverId,
    required this.onApproverSelected,
  });

  @override
  State<ApproverSelectionDialog> createState() =>
      _ApproverSelectionDialogState();
}

class _ApproverSelectionDialogState extends State<ApproverSelectionDialog> {
  String? _selectedApproverId;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  Set<String> _expandedDepartments = {};

  // API로부터 로드된 조직도 데이터
  bool _isLoadingDepartments = true;
  Map<String, List<CcPerson>> _departmentStructure = {};

  @override
  void initState() {
    super.initState();
    _selectedApproverId = widget.currentApproverId;
    _loadDepartments();
  }

  /// 부서 목록 로드 (API 연동)
  Future<void> _loadDepartments() async {
    setState(() {
      _isLoadingDepartments = true;
    });

    try {
      print('📋 승인자 다이얼로그: 부서 목록 조회 시작 (API 호출)');

      // API로 부서 목록 조회
      final departments = await ApiService.getDepartmentList();

      print('✅ 승인자 다이얼로그: 부서 목록 조회 완료: ${departments.length}개 부서');

      setState(() {
        _isLoadingDepartments = false;
      });

      // 각 부서의 멤버를 로드
      for (final department in departments) {
        await _loadDepartmentMembers(department);
      }
    } catch (e) {
      print('❌ 승인자 다이얼로그: 부서 목록 조회 실패: $e');
      setState(() {
        _isLoadingDepartments = false;
        // 폴백: 기본 부서 설정
        _departmentStructure = {
          'Biz AI사업부': [
            CcPerson(name: '신주열', department: 'Biz AI사업부', userId: 'user_001'),
            CcPerson(name: '최유연', department: 'Biz AI사업부', userId: 'user_002'),
            CcPerson(name: '김도훈', department: 'Biz AI사업부', userId: 'user_003'),
            CcPerson(name: '한정민', department: 'Biz AI사업부', userId: 'user_004'),
          ],
        };
      });
    }
  }

  /// 부서별 멤버 로드 (API 연동)
  Future<void> _loadDepartmentMembers(String department) async {
    try {
      print('👥 승인자 다이얼로그: 부서 멤버 조회 시작: $department');

      // 회사 전체 조직도에서 해당 부서의 멤버만 필터링
      final companyMembers = await ApiService.getCompanyMembers();
      final members = companyMembers[department] ?? [];

      print('✅ 승인자 다이얼로그: 부서 멤버 조회 완료: ${members.length}명');

      setState(() {
        _departmentStructure[department] = members.map((member) {
          return CcPerson(
            name: member['name'] ?? '',
            department: department,
            userId: member['user_id'] ?? member['userId'], // user_id 추가
          );
        }).toList();
      });
    } catch (e) {
      print('❌ 승인자 다이얼로그: 부서 멤버 조회 실패 ($department): $e');
      setState(() {
        _departmentStructure[department] = [];
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 부서별 직원 필터링
  Map<String, List<CcPerson>> get _filteredDepartments {
    if (_searchText.isEmpty) {
      return _departmentStructure;
    }

    Map<String, List<CcPerson>> filteredMap = {};

    _departmentStructure.forEach((department, employees) {
      // 부서명에 검색어가 포함되는 경우 해당 부서의 모든 직원 포함
      if (department.toLowerCase().contains(_searchText.toLowerCase())) {
        filteredMap[department] = employees;
      } else {
        // 직원명에 검색어가 포함되는 직원들만 필터링
        final filteredEmployees = employees
            .where((person) =>
                person.name.toLowerCase().contains(_searchText.toLowerCase()))
            .toList();
        if (filteredEmployees.isNotEmpty) {
          filteredMap[department] = filteredEmployees;
        }
      }
    });

    return filteredMap;
  }

  // 부서의 선택 상태 확인 (승인자는 한 명만 선택 가능)
  bool _isDepartmentSelected(String department) {
    final employees = _departmentStructure[department] ?? [];
    return employees.any((employee) => _selectedApproverId == employee.name);
  }

  // 부서 전체 선택 (승인자는 한 명만 선택 가능하므로 첫 번째 직원 선택)
  void _selectDepartmentFirstEmployee(String department) {
    final employees = _departmentStructure[department] ?? [];
    if (employees.isNotEmpty) {
      setState(() {
        _selectedApproverId = employees.first.name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
                  '승인자 선택',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
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
                  borderSide: const BorderSide(color: Color(0xFF4A6CF7)),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                });
              },
            ),
            const SizedBox(height: 4),

            // 현재 선택된 승인자 표시
            if (_selectedApproverId != null &&
                _selectedApproverId!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkTheme
                      ? const Color(0xFF4A6CF7).withValues(alpha: 0.2)
                      : const Color(0xFF4A6CF7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.how_to_reg_rounded,
                      color: isDarkTheme
                          ? const Color(0xFF4A6CF7).withValues(alpha: 0.8)
                          : const Color(0xFF4A6CF7),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '선택된 승인자: $_selectedApproverId',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkTheme
                            ? const Color(0xFF4A6CF7).withValues(alpha: 0.8)
                            : const Color(0xFF4A6CF7),
                      ),
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
                            color: const Color(0xFF4A6CF7),
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
                  : ListView.builder(
                      itemCount: _filteredDepartments.keys.length,
                      itemBuilder: (context, index) {
                        final department =
                            _filteredDepartments.keys.elementAt(index);
                        final employees =
                            _filteredDepartments[department] ?? [];
                        final isExpanded =
                            _expandedDepartments.contains(department);

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
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              child: ListTile(
                                leading: Icon(
                                  isExpanded
                                      ? Icons.expand_more
                                      : Icons.chevron_right,
                                  color: const Color(0xFF4A6CF7),
                                ),
                                title: Row(
                                  children: [
                                    Checkbox(
                                      value: _isDepartmentSelected(department),
                                      onChanged: (selected) {
                                        if (selected == true) {
                                          _selectDepartmentFirstEmployee(
                                              department);
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.business,
                                      size: 18,
                                      color: const Color(0xFF4A6CF7),
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
                                onTap: () {
                                  setState(() {
                                    if (isExpanded) {
                                      _expandedDepartments.remove(department);
                                    } else {
                                      _expandedDepartments.add(department);
                                    }
                                  });
                                },
                              ),
                            ),

                            // 부서원 목록 (확장된 경우에만 표시)
                            if (isExpanded) ...[
                              ...employees.map((person) {
                                return Container(
                                  margin:
                                      const EdgeInsets.only(left: 32, right: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFF4A6CF7)
                                          .withValues(alpha: 0.2),
                                      radius: 16,
                                      child: Text(
                                        person.name.substring(0, 1),
                                        style: const TextStyle(
                                          color: Color(0xFF4A6CF7),
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
                                    trailing: Radio<String>(
                                      value: person.name,
                                      groupValue: _selectedApproverId,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedApproverId = value;
                                        });
                                      },
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedApproverId = person.name;
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
                    onPressed: _selectedApproverId != null &&
                            _selectedApproverId!.isNotEmpty
                        ? () {
                            widget.onApproverSelected(_selectedApproverId!);
                            Navigator.pop(context);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A6CF7),
                    ),
                    child: const Text('확인'),
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
