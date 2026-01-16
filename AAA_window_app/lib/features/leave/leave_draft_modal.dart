import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/features/leave/leave_modal_provider.dart';
import 'package:ASPN_AI_AGENT/features/leave/vacation_data_provider.dart';
import 'package:ASPN_AI_AGENT/features/leave/leave_models.dart';
import 'package:ASPN_AI_AGENT/shared/services/leave_api_service.dart';
import 'package:ASPN_AI_AGENT/shared/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ASPN_AI_AGENT/models/leave_management_models.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:ASPN_AI_AGENT/features/leave/approver_selection_modal.dart';
import 'package:ASPN_AI_AGENT/core/config/app_config.dart';

/// 휴가 상신 초안 모달 위젯
/// 기존 휴가신청 폼의 UI를 재사용하되, 채팅 관련 부분은 제외
class LeaveDraftModal extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const LeaveDraftModal({
    super.key,
    this.onClose,
  });

  @override
  ConsumerState<LeaveDraftModal> createState() => _LeaveDraftModalState();
}

class _LeaveDraftModalState extends ConsumerState<LeaveDraftModal>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormBuilderState>();
  Map<String, String?> _fieldErrors = {};
  bool _isSubmitting = false;

  // 폼 데이터
  String? _selectedVacationType;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _reason;
  List<String> _selectedApproverIds = []; // API로 받은 승인자 ID 목록
  Map<String, String> _approverNames = {}; // 승인자 ID -> 이름 매핑
  bool _useNextYearLeave = false; // 내년 정기휴가 사용하기
  bool _useHalfDay = false; // 반차 사용 여부
  String? _halfDayType; // 오전반차/오후반차
  List<CcPerson> _ccList = [];
  // CC 목록을 user_id 기반으로 전송하기 위한 원본 데이터 보관
  List<CcPersonData> _ccListData = [];
  bool _isLeaveStatusExpanded = true; // 휴가 현황 섹션 펼쳐진 상태 (디폴트)

  // 내년 정기휴가 상태
  List<NextYearLeaveStatus>? _nextYearLeaveStatus;
  bool _isLoadingNextYearLeave = false;

  // 휴가 종류 목록 (API 기반)
  List<String> _availableLeaveTypes = [];
  bool _isLoadingLeaveTypes = false;

  late AnimationController _slideController;

  // 타이핑 애니메이션을 위한 컨트롤러
  late AnimationController _typingController;
  Timer? _typingTimer;
  String _currentTypingText = '';

  @override
  void initState() {
    super.initState();

    // 애니메이션 컨트롤러 초기화 (페이드 + 스케일)
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // 타이핑 애니메이션 컨트롤러 초기화
    _typingController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _typingController.repeat();

    // 모달이 생성되면 슬라이드 인 애니메이션 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slideController.forward();
      // 저장된 결재라인 불러오기
      _loadSavedApprovalLine();
      // 휴가 종류 목록 로드
      _loadLeaveTypes();
    });

    // 내 휴가 현황 데이터 로드 - 비활성화됨
    // _loadLeaveStatus();
  }

  /// 내년 정기휴가 상태 조회
  Future<void> _loadNextYearLeaveStatus() async {
    setState(() {
      _isLoadingNextYearLeave = true;
    });

    try {
      final userId = ref.read(userIdProvider);
      if (userId == null || userId.isEmpty) {
        print('⚠️ [LeaveDraftModal] 사용자 ID가 없습니다.');
        setState(() {
          _isLoadingNextYearLeave = false;
          _nextYearLeaveStatus = null;
        });
        return;
      }

      print('📅 [LeaveDraftModal] 내년 정기휴가 조회 시작: userId=$userId');
      final response =
          await LeaveApiService.getNextYearLeaveStatus(userId: userId);

      if (response.error != null) {
        print('❌ [LeaveDraftModal] 내년 정기휴가 조회 실패: ${response.error}');
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
            '✅ [LeaveDraftModal] 내년 정기휴가 조회 완료: ${response.leaveStatus.length}개');
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
      print('❌ [LeaveDraftModal] 내년 정기휴가 조회 중 오류: $e');
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

  /// 내 휴가 현황 조회 - 비활성화됨
  // Future<void> _loadLeaveStatus() async {
  //   try {
  //     // 현재 사용자 ID 가져오기
  //     final userId = ref.read(userIdProvider);
  //     if (userId == null) {
  //       print('⚠️ [LeaveDraftModal] 사용자 ID가 없습니다.');
  //       return;
  //     }

  //     print('📋 [LeaveDraftModal] 내 휴가 현황 조회 시작: userId=$userId');

  //     // 연도별 휴가 데이터 조회 - 비활성화됨
  //     // month 필드에는 연도-월-일 형식으로 전송 (예: "2025-01-01")
  //     // final now = DateTime.now();
  //     // final response = await LeaveApiService.getYearlyLeaveData(
  //     //   request: YearlyLeaveRequest(
  //     //     userId: userId,
  //     //     month: '${now.year}-${now.month.toString().padLeft(2, '0')}-01',
  //     //   ),
  //     // );

  //     // if (response.error != null) {
  //     //   print('❌ [LeaveDraftModal] 휴가 현황 조회 실패: ${response.error}');
  //     //   return;
  //     // }

  //     // YearlyWholeStatus를 LeaveStatusData로 변환 - 빈 리스트로 처리
  //     final leaveStatusList = <LeaveStatusData>[];
  //     // final leaveStatusList = response.yearlyWholeStatus
  //     //     .map((item) => LeaveStatusData(
  //     //           leaveType: item.leaveType,
  //     //           totalDays: item.totalDays,
  //     //           remainDays: item.remainDays,
  //     //         ))
  //     //     .toList();

  //     print('✅ [LeaveDraftModal] 휴가 현황 데이터 수신: ${leaveStatusList.length}개');

  //     // VacationRequestData에 업데이트
  //     ref.read(vacationDataProvider.notifier).updateField('leave_status',
  //         leaveStatusList.map((item) => item.toJson()).toList());

  //     print('✅ [LeaveDraftModal] 휴가 현황 Provider 업데이트 완료');
  //   } catch (e) {
  //     print('❌ [LeaveDraftModal] 휴가 현황 조회 실패: $e');
  //   }
  // }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 모달 상태 변화에 따른 애니메이션 처리
    final modalState = ref.watch(leaveModalProvider);

    if (modalState.isExpanded && !_slideController.isCompleted) {
      _slideController.forward();
    }

    // 로딩 상태에 따른 타이핑 애니메이션 제어
    if (modalState.isLoadingVacationData && _typingTimer == null) {
      _startTypingAnimation();
    } else if (!modalState.isLoadingVacationData && _typingTimer != null) {
      _stopTypingAnimation();
    }

    // 사용자가 변경되었을 때 폼 초기화
    final currentUserId = ref.watch(userIdProvider);
    _resetFormForNewUser(currentUserId);

    // 휴가 데이터 변화 감지 및 폼 자동 채우기
    final vacationData = ref.watch(vacationDataProvider);
    _autoFillFormFromVacationData(vacationData);
  }

  String? _previousUserId;
  VacationRequestData? _previousVacationData;

  /// 새로운 사용자로 로그인했을 때 폼 초기화
  void _resetFormForNewUser(String? currentUserId) {
    if (_previousUserId != null && _previousUserId != currentUserId) {
      // 사용자가 변경되었으면 폼 초기화
      _formKey.currentState?.reset();
      setState(() {
        _selectedVacationType = null;
        _startDate = null;
        _endDate = null;
        _reason = null;
        _useNextYearLeave = false;
        _useHalfDay = false;
        _halfDayType = null;
        _isLeaveStatusExpanded = true;
        _fieldErrors.clear();
      });
    }
    _previousUserId = currentUserId;
  }

  /// 휴가 데이터를 사용하여 폼 자동 채우기
  void _autoFillFormFromVacationData(VacationRequestData vacationData) {
    // 데이터가 변경되지 않았으면 처리하지 않음
    if (_previousVacationData == vacationData || vacationData.isEmpty) {
      return;
    }

    print('🔄 폼 자동 채우기 시작: ${vacationData.toJson()}');

    setState(() {
      // 휴가 종류
      if (vacationData.leaveType != null) {
        _selectedVacationType = vacationData.leaveType;
        print('🔄 채팅 트리거 휴가종류 처리: ${vacationData.leaveType}');
      }

      // 시작일/종료일
      if (vacationData.startDate != null) {
        _startDate = vacationData.startDate;
      }
      if (vacationData.endDate != null) {
        _endDate = vacationData.endDate;
      }

      // 휴가 사유
      if (vacationData.reason != null && vacationData.reason!.isNotEmpty) {
        _reason = vacationData.reason;
      }

      // 승인자 - approvalLine에서 승인자 ID 목록 가져오기
      if (vacationData.approvalLine != null &&
          vacationData.approvalLine!.isNotEmpty) {
        _selectedApproverIds = vacationData.approvalLine!
            .map((approver) => approver.approverId)
            .toList();
        print('📋 승인자 목록 설정 완료: ${_selectedApproverIds.join(', ')}');
      }

      // 참조자 목록 (CcPersonData를 CcPerson으로 변환)
      if (vacationData.ccList != null && vacationData.ccList!.isNotEmpty) {
        // 원본 보관 (name, user_id)
        _ccListData = List<CcPersonData>.from(vacationData.ccList!);
        _ccList = vacationData.ccList!.map((ccData) {
          return CcPerson(
            name: ccData.name,
            department: '', // 서버에는 user_id로 보낼 예정
          );
        }).toList();
        print('📋 참조자 목록 설정 완료: ${_ccList.map((cc) => cc.name).join(', ')}');
      }

      // 반차 타입 (halfDaySlot에서 변환)
      if (vacationData.halfDaySlot != null) {
        if (vacationData.halfDaySlot == 'ALL') {
          // 종일 연차인 경우 반차 체크박스 체크하지 않음
          _useHalfDay = false;
          _halfDayType = null;
        } else if (vacationData.halfDaySlot == 'AM') {
          // 오전반차인 경우 반차 체크박스 체크하고 오전 선택
          _useHalfDay = true;
          _halfDayType = '오전반차';
        } else if (vacationData.halfDaySlot == 'PM') {
          // 오후반차인 경우 반차 체크박스 체크하고 오후 선택
          _useHalfDay = true;
          _halfDayType = '오후반차';
        }
      }

      // 내년 정기휴가 사용 (VacationRequestData에 해당 필드가 없으므로 기본값 유지)
    });

    // FormBuilder 필드들도 업데이트 (setState 완료 후)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateFormBuilderFieldsWithRetry(vacationData);
    });

    _previousVacationData = vacationData;
    print('✅ 폼 자동 채우기 완료');
  }

  /// FormBuilder 필드 업데이트 (재시도 로직 포함)
  Future<void> _updateFormBuilderFieldsWithRetry(
    VacationRequestData vacationData, {
    int retryCount = 0,
    int maxRetries = 10,
  }) async {
    if (!mounted) {
      print('⚠️ Widget이 이미 dispose되어 필드 업데이트를 건너뜁니다.');
      return;
    }

    // API 로딩 중이면 대기
    if (_isLoadingLeaveTypes && retryCount < maxRetries) {
      print('🔄 휴가종류 API 로딩 중... 재시도 ${retryCount + 1}/$maxRetries');
      await Future.delayed(const Duration(milliseconds: 200));
      return _updateFormBuilderFieldsWithRetry(
        vacationData,
        retryCount: retryCount + 1,
      );
    }

    if (_formKey.currentState == null) {
      print('⚠️ FormKey state가 null이어서 필드 업데이트를 건너뜁니다.');
      return;
    }

    final fields = _formKey.currentState!.fields;

    // 휴가종류 필드 업데이트
    if (vacationData.leaveType != null) {
      if (_availableLeaveTypes.isEmpty && retryCount < maxRetries) {
        // 목록이 비어있으면 API 로드 후 재시도
        print('🔄 휴가종류 목록이 비어있어 API 호출 후 재시도 ${retryCount + 1}/$maxRetries');
        if (!_isLoadingLeaveTypes) {
          await _loadLeaveTypes();
        }
        await Future.delayed(const Duration(milliseconds: 200));
        return _updateFormBuilderFieldsWithRetry(
          vacationData,
          retryCount: retryCount + 1,
        );
      }

      if (_availableLeaveTypes.contains(vacationData.leaveType)) {
        print('✅ FormBuilder 휴가종류 필드 업데이트: ${vacationData.leaveType}');
        fields['vacationType']?.didChange(vacationData.leaveType);
      } else if (_availableLeaveTypes.isNotEmpty) {
        print(
            '⚠️ 휴가종류 "${vacationData.leaveType}"가 목록에 없습니다. 목록: $_availableLeaveTypes');
        // 서버에서 온 값이므로 목록에 추가
        print('📝 서버에서 온 휴가종류를 목록에 추가: ${vacationData.leaveType}');
        setState(() {
          _availableLeaveTypes = [
            vacationData.leaveType!,
            ..._availableLeaveTypes
          ];
        });
        // 다음 프레임에서 필드 업데이트 (setState 완료 후)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _formKey.currentState != null) {
            _formKey.currentState!.fields['vacationType']
                ?.didChange(vacationData.leaveType);
            print('✅ 휴가종류 필드 업데이트 완료: ${vacationData.leaveType}');
          }
        });
      } else if (retryCount >= maxRetries) {
        print('❌ 최대 재시도 횟수 초과. 휴가종류 필드 업데이트 실패');
      }
    }

    // 날짜 필드 업데이트
    if (vacationData.startDate != null) {
      fields['vacationStart']?.didChange(vacationData.startDate);
    }
    if (vacationData.endDate != null) {
      fields['vacationEnd']?.didChange(vacationData.endDate);
    }

    // 사유 필드 업데이트
    if (vacationData.reason != null) {
      fields['vacationReason']?.didChange(vacationData.reason);
    }

    print('✅ FormBuilder 필드 업데이트 완료');
  }

  /// 타이핑 애니메이션 시작
  void _startTypingAnimation() {
    const messages = [
      'AI가 초안을 작성중입니다',
      'AI가 초안을 작성중입니다.',
      'AI가 초안을 작성중입니다..',
      'AI가 초안을 작성중입니다...',
    ];

    int currentIndex = 0;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _currentTypingText = messages[currentIndex % messages.length];
        });
        currentIndex++;
      }
    });
  }

  /// 타이핑 애니메이션 중지
  void _stopTypingAnimation() {
    _typingTimer?.cancel();
    _typingTimer = null;
  }

  @override
  void dispose() {
    _slideController.dispose();
    _typingController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  /// 모달 닫기 (슬라이드 아웃 애니메이션 포함) - 오직 명시적 닫기 버튼에서만 호출
  void _closeModal() async {
    final messenger = ScaffoldMessenger.of(context);

    // 슬라이드 애니메이션 완료 대기
    await _slideController.reverse();
    ref.read(leaveModalProvider.notifier).forceHideModal();

    // 모달이 닫힐 때 사이드바 다시 열기
    final chatNotifier = ref.read(chatProvider.notifier);
    final chatState = ref.read(chatProvider);
    if (!chatState.isSidebarVisible) {
      chatNotifier.toggleSidebarVisibility();
      print('✅ [LeaveDraftModal] 모달 닫기: 사이드바 다시 열림');
    }

    // 모달 닫힌 후 스낵바 표시
    await Future.delayed(const Duration(milliseconds: 100));
    messenger.showSnackBar(
      const SnackBar(
        content: Text('상신이 취소되었습니다.'),
        duration: Duration(milliseconds: 1500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modalState = ref.watch(leaveModalProvider);

    return FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(_slideController),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.95, end: 1.0).animate(_slideController),
        child: MouseRegion(
          onEnter: (_) {
            ref.read(leaveModalProvider.notifier).setHovered(true);
          },
          onExit: (_) {
            ref.read(leaveModalProvider.notifier).setHovered(false);
            // 자동 닫힘 완전 비활성화 - 아무것도 하지 않음
          },
          child: GestureDetector(
            // 모달 내부 클릭 시에는 아무것도 하지 않음 (이벤트 흡수)
            onTap: () {},
            child: Container(
              width: double.infinity, // 부모 Container의 크기를 따름
              height: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1A1D1F)
                    : Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: _buildFormContent(),
                      ),
                      _buildFooter(),
                    ],
                  ),
                  // 로딩 오버레이
                  if (modalState.isLoadingVacationData) _buildLoadingOverlay(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 모달 헤더 (제목, 접어두기 버튼, 닫기 버튼)
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
              '휴가 상신 초안',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
              ),
            ),
          ),
          // 접어두기 화살표 버튼 추가
          IconButton(
            onPressed: () {
              ref.read(leaveModalProvider.notifier).forceCollapseModal();

              // 모달이 접힐 때 사이드바 다시 열기
              final chatNotifier = ref.read(chatProvider.notifier);
              final chatState = ref.read(chatProvider);
              if (!chatState.isSidebarVisible) {
                chatNotifier.toggleSidebarVisibility();
                print('✅ [LeaveDraftModal] 모달 접기: 사이드바 다시 열림');
              }
            },
            icon: const Icon(
              Icons.chevron_right,
              color: Color(0xFF8B95A1),
            ),
            tooltip: '접어두기',
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
    final vacationData = ref.watch(vacationDataProvider);
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // 서버에서 받은 leave_status 데이터 사용
    final leaveStatus = vacationData.leaveStatus ?? [];

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
                  // 서버에서 받은 leave_status 데이터가 있으면 그것을 사용
                  if (leaveStatus.isNotEmpty) ...[
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
                    // leave_status 데이터가 없으면 기본 메시지 표시
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '휴가 현황 정보를 불러오는 중...',
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
        Focus(
          onFocusChange: (hasFocus) {
            // 드롭다운에 포커스가 갈 때 (클릭될 때) 휴가종류 API 호출
            if (hasFocus &&
                _availableLeaveTypes.isEmpty &&
                !_isLoadingLeaveTypes) {
              print('🔍 드롭다운 클릭 - 휴가종류 API 호출 시작');
              // 빌드 단계가 끝난 후에 API 호출 (setState 방지)
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _loadLeaveTypes();
                }
              });
            }
          },
          child: FormBuilderDropdown<String>(
            key: ValueKey(
                'vacationType_${_availableLeaveTypes.length}_${_isLoadingLeaveTypes}'),
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
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
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
          // 결재라인 저장 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _saveApprovalLine,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4A6CF7),
                side: const BorderSide(color: Color(0xFF4A6CF7)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.save_outlined, size: 20),
              label: const Text(
                '결재라인 저장',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 휴가 상신 버튼
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
    // TODO: Implement field update logic

    // 필드가 업데이트되면 초안이 있다고 표시
    ref.read(leaveModalProvider.notifier).setHasDraft(true);

    if (_fieldErrors.containsKey(key)) {
      setState(() {
        _fieldErrors.remove(key);
      });
    }
  }

  /// 승인자 선택 모달 표시 (API 연동)
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
      print('✅ 승인자 선택 완료: ${_selectedApproverIds.join(', ')}');

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

      // API 호출
      final response = await LeaveApiService.loadApprovalLine(
        userId: currentUserId,
      );

      if (response.isSuccess && mounted) {
        // 승인자 목록 설정
        if (response.approvalLine.isNotEmpty) {
          // approval_seq 순서대로 정렬
          final sortedLine = response.approvalLine.toList()
            ..sort((a, b) => a.approvalSeq.compareTo(b.approvalSeq));

          setState(() {
            _selectedApproverIds =
                sortedLine.map((item) => item.approverId).toList();
          });

          // 승인자 이름 정보 가져오기
          await _fetchApproverNames();

          print('✅ 승인자 ${_selectedApproverIds.length}명 불러오기 완료');
        }

        // 참조자 목록 설정
        if (response.ccList.isNotEmpty) {
          final ccListData = response.ccList
              .map((item) => CcPersonData(
                    name: item.name,
                    userId: item.userId,
                  ))
              .toList();

          final ccList = ccListData
              .map((item) => CcPerson(
                    name: item.name,
                    department: '', // API에서 department 정보가 없으므로 빈 문자열
                    userId: item.userId.isNotEmpty ? item.userId : null,
                  ))
              .toList();

          setState(() {
            _ccListData = ccListData;
            _ccList = ccList;
          });

          print('✅ 참조자 ${_ccList.length}명 불러오기 완료');
          print(
              '📋 참조자 목록: ${_ccList.map((p) => '${p.name}(${p.userId})').join(', ')}');
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

      print('📋 [LeaveDraftModal] 휴가 종류 목록 로드 시작: userId=$currentUserId');

      // API 직접 호출
      final url = Uri.parse('${AppConfig.baseUrl}/leave/user/getLeaveTypes'); //
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({
        'user_id': currentUserId,
      });

      final response = await http.post(url, headers: headers, body: body);
      print('📋 [LeaveDraftModal] 휴가 종류 API 응답 상태 코드: ${response.statusCode}');

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
                '✅ [LeaveDraftModal] 휴가 종류 ${leaveTypes.length}개 로드 완료: ${leaveTypes}');
          });

          // FormBuilder 필드 업데이트는 setState 외부에서 처리
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _formKey.currentState != null) {
              // 첫 번째 휴가종류를 자동 선택 (선택된 값이 없을 때만)
              if (_availableLeaveTypes.isNotEmpty &&
                  _selectedVacationType == null) {
                setState(() {
                  _selectedVacationType = _availableLeaveTypes[0];
                });
                _formKey.currentState?.fields['vacationType']
                    ?.didChange(_selectedVacationType);
              }
            }
          });
        } else {
          print('⚠️ [LeaveDraftModal] 휴가 종류 API 실패: ${response.statusCode}');
          setState(() {
            _isLoadingLeaveTypes = false;
            _availableLeaveTypes = []; // 폴백
          });
        }
      }
    } catch (e) {
      print('❌ [LeaveDraftModal] 휴가 종류 로드 중 오류 발생: $e');
      if (mounted) {
        setState(() {
          _isLoadingLeaveTypes = false;
          _availableLeaveTypes = []; // 폴백
        });
      }
    }
  }

  /// 결재라인 저장
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
      for (final cc in _ccListData) {
        // CcPersonData에는 department와 jobPosition 정보가 없으므로 빈 문자열로 전송
        ccList.add(CcListItem(
          userId: cc.userId,
          name: cc.name,
          department: '',
          jobPosition: '',
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
        // ccList(view)를 name+user_id 형태로 표시
        if (_ccListData.isNotEmpty) {
          final ccView = _ccListData
              .map((e) => "CCItem(name='${e.name}', user_id='${e.userId}')")
              .join(', ');
          print('  - ccList(view): [$ccView]');
        } else {
          // fallback: 기존 표시 방식
          print(
              '  - ccList(view): ${request.ccList.map((cc) => '${cc.name}(dept:${cc.department})').join(', ')}');
        }
        print('  - reason: ${request.reason}');
        print('  - halfDaySlot: ${request.halfDaySlot}');
        print('  - isNextYear: ${request.isNextYear}');

        // 전송용 바디 생성 (cc_list를 서버 기대 형식으로 교체)
        final Map<String, dynamic> body =
            Map<String, dynamic>.from(request.toJson());
        if (_ccListData.isNotEmpty) {
          // 서버 스펙:
          // cc_list: [{user_id: "...", name: "..."}]
          body['cc_list'] = _ccListData
              .map((cc) => {
                    'user_id': cc.userId,
                    'name': cc.name,
                  })
              .toList();
        }
        print('  - 전송 바디(preview): $body');

        // API 호출
        final response = await LeaveApiService.submitLeaveRequestNewBody(body);

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
            // 제출 완료 시 모달 완전히 닫기
            ref.read(leaveModalProvider.notifier).forceHideModal();
            await _slideController.reverse();
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
                    Text(
                      '선택된 참조자 (${_ccList.length}명)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDarkTheme
                            ? const Color(0xFF20C997)
                            : const Color(0xFF20C997),
                      ),
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
    final vacationData = ref.read(vacationDataProvider);
    showDialog(
      context: context,
      builder: (context) => ReferenceSelectionDialog(
        currentReferences: _ccList,
        onSelectionChanged: (newReferences) {
          setState(() {
            _ccList = newReferences;
            // _ccListData도 함께 업데이트 (서버 전송용)
            _ccListData = newReferences.map((person) {
              return CcPersonData(
                name: person.name,
                userId: person.userId ?? '',
              );
            }).toList();
            print('📋 참조자 업데이트: ${_ccListData.length}명');
            for (var cc in _ccListData) {
              print('  - ${cc.name} (userId: ${cc.userId})');
            }
          });
        },
        vacationData: vacationData,
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

  /// 진행 상황 점 위젯
  Widget _buildProgressDot(int index) {
    return AnimatedBuilder(
      animation: _typingController,
      builder: (context, child) {
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        final progress = (_typingController.value + index * 0.3) % 1.0;
        final opacity = (sin(progress * 2 * pi) + 1) / 2;

        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: (isDarkTheme ? Colors.white : const Color(0xFF4A6CF7))
                .withValues(alpha: 0.3 + opacity * 0.7),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  /// 로딩 오버레이
  Widget _buildLoadingOverlay() {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color:
            (isDarkTheme ? Colors.black : Colors.white).withValues(alpha: 0.8),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkTheme ? const Color(0xFF2D3748) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF4A6CF7)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentTypingText.isEmpty
                        ? 'AI가 초안을 작성중입니다'
                        : _currentTypingText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color:
                          isDarkTheme ? Colors.white : const Color(0xFF1A1D1F),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 진행 상황을 보여주는 작은 점들
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildProgressDot(0),
                      const SizedBox(width: 8),
                      _buildProgressDot(1),
                      const SizedBox(width: 8),
                      _buildProgressDot(2),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '잠시만 기다려주세요.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkTheme
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 참조자 선택 다이얼로그
class ReferenceSelectionDialog extends StatefulWidget {
  final List<CcPerson> currentReferences;
  final Function(List<CcPerson>) onSelectionChanged;
  final VacationRequestData? vacationData; // 서버 조직도 데이터 전달 (fallback용)

  const ReferenceSelectionDialog({
    super.key,
    required this.currentReferences,
    required this.onSelectionChanged,
    this.vacationData,
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
  Map<String, bool> _loadingMembers = {};
  Map<String, String?> _membersError = {};
  Map<String, List<CcPerson>> _departmentMembers = {};

  @override
  void initState() {
    super.initState();
    _selectedReferences = List.from(widget.currentReferences);
    _loadCompanyMembers();
  }

  /// 회사 전체 조직도(부서/인원) 로드
  ///
  /// - 기존에는 부서 목록(`getDepartmentList`)을 먼저 가져오고,
  ///   부서별 인원(`getDepartmentMembers`)을 여러 번 호출했음
  /// - 이제는 `getCompanyMembers` 한 번만 호출해서
  ///   {부서명: [ {name, user_id, job_position?}, ... ]} 형태로 모두 받음
  Future<void> _loadCompanyMembers() async {
    setState(() {
      _isLoadingDepartments = true;
    });

    try {
      print('📋 [참조자 모달] 회사 전체 조직도 조회 시작');
      final companyMembers = await ApiService.getCompanyMembers();

      // 부서 목록 및 부서별 CcPerson 리스트 구성
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
        _departments = departments;
        _departmentMembers = deptMembers;
        _isLoadingDepartments = false;
      });

      print('✅ [참조자 모달] 회사 전체 조직도 로드 완료: ${departments.length}개 부서');
    } catch (e) {
      print('❌ [참조자 모달] 회사 전체 조직도 로드 실패: $e');
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

  // 부서의 선택 상태 확인 (동명이인 구분을 위해 uniqueKey 기준)
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

  // 부서 전체 선택/해제 (uniqueKey 기준)
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
                                  // 로딩 중
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
                                  // 에러 발생
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
                                  // 직원 목록 표시
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
                                                    person.uniqueKey),
                                            onChanged: (selected) {
                                              setState(() {
                                                if (selected == true) {
                                                  if (!_selectedReferences.any(
                                                      (p) =>
                                                          p.uniqueKey ==
                                                          person.uniqueKey)) {
                                                    _selectedReferences
                                                        .add(person);
                                                  }
                                                } else {
                                                  _selectedReferences
                                                      .removeWhere((p) =>
                                                          p.uniqueKey ==
                                                          person.uniqueKey);
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
  final VacationRequestData? vacationData; // 서버 조직도 데이터 전달

  const ApproverSelectionDialog({
    super.key,
    required this.currentApproverId,
    required this.onApproverSelected,
    this.vacationData,
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

  // 서버에서 받은 조직도 데이터를 CcPerson으로 변환
  Map<String, List<CcPerson>> get _departmentStructure {
    if (widget.vacationData?.organizationData == null) {
      // 서버 데이터가 없는 경우 기본 조직도 (하위 호환성)
      return {
        'Biz AI사업부': [
          CcPerson(name: '신주열', department: 'Biz AI사업부'),
          CcPerson(name: '최유연', department: 'Biz AI사업부'),
          CcPerson(name: '김도훈', department: 'Biz AI사업부'),
          CcPerson(name: '한정민', department: 'Biz AI사업부'),
        ],
      };
    }

    final orgData = widget.vacationData!.organizationData!;
    Map<String, List<CcPerson>> structure = {};

    orgData.forEach((department, employeesData) {
      structure[department] = employeesData.map((empData) {
        return CcPerson(
          name: empData['name'] as String? ?? '',
          department: empData['department'] as String? ?? department,
        );
      }).toList();
    });

    return structure;
  }

  @override
  void initState() {
    super.initState();
    _selectedApproverId = widget.currentApproverId;
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
              child: ListView.builder(
                itemCount: _filteredDepartments.keys.length,
                itemBuilder: (context, index) {
                  final department = _filteredDepartments.keys.elementAt(index);
                  final employees = _filteredDepartments[department] ?? [];
                  final isExpanded = _expandedDepartments.contains(department);

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
                                    _selectDepartmentFirstEmployee(department);
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
                            margin: const EdgeInsets.only(left: 32, right: 8),
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
                                  color:
                                      isDarkTheme ? Colors.white : Colors.black,
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
