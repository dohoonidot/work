import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/shared/widgets/sidebar.dart';
import 'package:ASPN_AI_AGENT/shared/utils/common_ui_utils.dart';
import 'package:ASPN_AI_AGENT/features/chat/chat_area_v3.dart';
import 'package:ASPN_AI_AGENT/ui/screens/login_page.dart'; // LoginPage 경로 수정
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:ASPN_AI_AGENT/shared/widgets/scrolling_ticker.dart'; // providers.dart import (notification_notifier, theme_provider 포함)
import 'package:ASPN_AI_AGENT/ui/screens/sap_main_page.dart';
import 'package:ASPN_AI_AGENT/ui/screens/coding_assistant_page.dart';
import 'package:ASPN_AI_AGENT/ui/screens/settings_page.dart'; // 설정 페이지 추가
import 'package:ASPN_AI_AGENT/ui/screens/signflow_screen.dart'; // 전자결재 페이지 추가
import 'package:ASPN_AI_AGENT/ui/screens/leave_management_screen.dart'; // 휴가관리 페이지 추가
import 'package:ASPN_AI_AGENT/ui/screens/admin_leave_approval_screen.dart'; // 관리자 휴가관리 페이지 추가
import 'package:ASPN_AI_AGENT/ui/screens/electronic_approval_management_screen.dart'; // 전자결재관리 추가
import 'package:ASPN_AI_AGENT/ui/screens/vacation_management_webview_screen.dart'; // 휴가 총괄 관리 웹뷰
import 'package:ASPN_AI_AGENT/main.dart'; // navigatorKey import
import 'package:ASPN_AI_AGENT/features/leave/leave_modal_provider.dart';
import 'package:ASPN_AI_AGENT/features/leave/leave_draft_modal.dart';
import 'package:ASPN_AI_AGENT/features/leave/leave_collapsed_tab.dart';
import 'package:ASPN_AI_AGENT/shared/providers/chat_state.dart';
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart'; // AppThemeMode 추가
import 'package:url_launcher/url_launcher.dart';
import 'package:ASPN_AI_AGENT/core/database/auto_login_service.dart'; // 추가
import 'package:ASPN_AI_AGENT/provider/leave_management_provider.dart'; // 휴가관리 프로바이더 추가
import 'package:ASPN_AI_AGENT/features/leave/leave_providers.dart'; // 휴가 관련 프로바이더들 추가
import 'package:ASPN_AI_AGENT/shared/services/leave_api_service.dart'; // 휴가 API 서비스 추가
import 'package:ASPN_AI_AGENT/models/leave_management_models.dart'; // AdminApprovalRequest 모델 추가

import 'package:window_manager/window_manager.dart';
import 'package:ASPN_AI_AGENT/shared/services/amqp_service.dart';

import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart'; // Confetti 패키지 추가
// import 'package:ASPN_AI_AGENT/features/gift/birthday_popup.dart'; // BirthdayPopup import 추가
import 'package:ASPN_AI_AGENT/features/auth/privacy_agreement_popup.dart'; // 개인정보 동의 팝업 추가
import 'package:ASPN_AI_AGENT/shared/services/api_service.dart'; // API 서비스 추가
import 'package:ASPN_AI_AGENT/shared/services/gift_service.dart'; // Gift 서비스 추가
import 'package:ASPN_AI_AGENT/features/auth/login_progress_indicator.dart'; // 로그인 진행률 인디케이터 추가
import 'package:ASPN_AI_AGENT/shared/services/background_init_service.dart'; // 백그라운드 초기화 서비스 추가
import 'package:ASPN_AI_AGENT/features/leave/services/leave_realtime_service.dart'; // 결재 요청 서비스 추가
import 'package:ASPN_AI_AGENT/features/leave/providers/leave_notification_provider.dart'; // 휴가 알림 프로바이더
import 'package:ASPN_AI_AGENT/features/leave/widgets/leave_notification_overlay.dart'; // 휴가 알림 오버레이
import 'package:ASPN_AI_AGENT/features/approval/common_electronic_approval_modal.dart'; // 공통 전자결재 모달
import 'package:ASPN_AI_AGENT/features/leave/widgets/vacation_recommendation_charts.dart'; // 휴가 추천 차트
import 'package:ASPN_AI_AGENT/features/leave/widgets/vacation_ui_components.dart'; // 휴가 UI 컴포넌트
import 'package:ASPN_AI_AGENT/features/leave/widgets/vacation_ui_constants.dart'; // 휴가 UI 상수
import 'package:ASPN_AI_AGENT/shared/utils/message_renderer/gpt_markdown_renderer.dart'; // 마크다운 렌더러
import 'dart:convert'; // JSON 파싱용
import 'package:ASPN_AI_AGENT/update/update_service.dart'; // 업데이트 서비스 추가
import 'package:ASPN_AI_AGENT/update/update_config.dart'; // 업데이트 설정 추가
import 'package:package_info_plus/package_info_plus.dart';
// 업무 관련 기능 숨김 처리
// import 'package:ASPN_AI_AGENT/features/approval/html_test_provider.dart'; // HTML 테스트 프로바이더

// 검색 액션을 위한 Intent 클래스
class SearchIntent extends Intent {
  const SearchIntent();
}

class ChatHomePage extends ConsumerStatefulWidget {
  const ChatHomePage({super.key});

  @override
  ConsumerState<ChatHomePage> createState() => _ChatHomePageState();

  // static 메서드로 외부에서 선물함을 열 수 있도록 함 (WidgetRef용)
  static void showGiftBox(BuildContext context, WidgetRef ref) {
    _ChatHomePageState._showGiftBoxStatic(context, ref);
  }
}

class _ChatHomePageState extends ConsumerState<ChatHomePage>
    with WindowListener {
  // 백그라운드 초기화 상태 추적
  late StreamSubscription<BackgroundInitResult>? _backgroundInitSubscription;
  final AutoLoginService _autoLoginService = AutoLoginService();
  late ConfettiController _confettiController; // ConfettiController 선언
  bool _isConfettiPlaying = false; // 색종이 효과 재생 여부
  StreamSubscription<LeaveApprovalRequest>?
      _approvalRequestSubscription; // 결재 요청 스트림 구독
  StreamSubscription<LeaveEApprovalMessage>?
      _eapprovalMessageSubscription; // 전자결재 알림 스트림 구독
  bool _showEapprovalNotificationIcon = false; // 전자결재 알림 아이콘 표시 여부
  final List<LeaveEApprovalMessage> _eapprovalMessages = [];
  String _appVersion = '';

  // 결재 슬라이드 패널 관련
  bool _isApprovalPanelVisible = false;
  bool _isApprovalPanelExpanded = false; // 패널 펼침/접힘 상태
  bool _isApprovalPanelPinned = false; // 패널 고정 상태
  bool _showApprovalNotificationIcon = false; // 결재요청도착 아이콘 표시 여부
  List<Map<String, dynamic>> _approvalRequests = [];

  // 전자결재 상신 초안 패널 관련
  bool _isElectronicApprovalPanelVisible = false;
  bool _isElectronicApprovalLoading = false;

  // Sidebar 접근을 위한 GlobalKey
  final GlobalKey<SidebarState> _sidebarKey = GlobalKey<SidebarState>();

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
    }
    // ConfettiController 초기화
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 5));

    // 앱 버전 로드 (pubspec.yaml과 동기화)
    _loadAppVersion();

    // AMQP 서비스 초기화
    _initializeAmqp();

    // 휴가 알림 시스템 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(leaveNotificationProvider.notifier).startListening();
    });

    // 결재 요청 서비스 초기화
    _initializeLeaveApprovalService();

    // AMQP 서비스에 선물 확인 콜백 등록
    amqpService.setOnGiftConfirm(() {
      _showGiftBox(context, ref);
    });

    // AMQP 서비스에 선물 개수 업데이트 콜백 등록
    amqpService.setOnGiftCountUpdate(() {
      _updateGiftCount();
    });

    // 앱 시작 시 선물 개수 조회
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateGiftCount();
    });

    // 백그라운드 초기화 상태 리스너 설정
    _setupBackgroundInitListener();

    // 메인 화면 로드 시 백그라운드 초기화 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBackgroundInitIfNeeded();
    });

    // 앱 진입 시 업데이트 확인 (자동로그인 후)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdatesOnAppEntry();
    });
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = info.version;
        });
      }
    } catch (_) {}
  }

  void _initializeAmqp() async {
    // Provider가 준비된 후 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final notifier = ref.read(notificationProvider.notifier);
        final userId = ref.read(userIdProvider);

        print('🔧 NotificationNotifier 설정: 성공');
        print('🔧 사용자 ID: $userId');

        // 모든 Notifier 설정
        final leaveManagementNotifier =
            ref.read(leaveManagementProvider.notifier);

        amqpService.setNotifiers(
          notificationNotifier: notifier,
          chatNotifier: ref.read(chatProvider.notifier),
          alertTickerNotifier: ref.read(alertTickerProvider.notifier),
          leaveManagementNotifier: leaveManagementNotifier,
        );

        // 선물 개수 업데이트 콜백 설정
        amqpService.setOnGiftCountUpdate(() {
          _updateGiftCount();
        });

        // 사용자 ID 검증 후 연결 시도
        if (userId != null && userId.isNotEmpty) {
          bool connected = false;
          if (!amqpService.isConnected) {
            connected = await amqpService.connect(userId); // userId를 인자로 전달
            print('🔧 AMQP 연결 결과: $connected');
          } else {
            print('🔧 AMQP 이미 연결됨: 재연결 스킵');
            connected = true; // 이미 연결된 상태
          }

          if (connected) {
            print('🎯 AMQP 연결 완료');

            // 🔒 개인정보 동의 상태 확인 및 팝업 표시 (Provider에서 확인)
            try {
              print('🔒 ChatHomePage에서 개인정보 동의 상태 확인: $userId');

              // Provider에서 개인정보 동의 상태 확인
              final isAgreed = ref.read(privacyAgreementProvider);

              // AMQP 서비스에 개인정보 동의 상태 전달
              amqpService.setPrivacyAgreement(isAgreed);

              if (!isAgreed) {
                print('🔒 개인정보 미동의 - ChatHomePage에서 동의 팝업 표시');
                await Future.delayed(const Duration(milliseconds: 1000));

                if (mounted) {
                  await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext dialogContext) {
                      return PrivacyAgreementPopup(
                        userId: userId,
                        onAgreementChanged: (isAgreed) async {
                          // 개인정보 동의 시 Provider 상태 업데이트
                          ref.read(privacyAgreementProvider.notifier).state =
                              isAgreed;

                          // AMQP 서비스에 개인정보 동의 상태 전달
                          amqpService.setPrivacyAgreement(isAgreed);

                          // 개인정보 동의 시 즉시 큐 생성 (재연결 없이)
                          if (isAgreed) {
                            await amqpService.onPrivacyAgreementChanged(
                                userId, true);
                          }
                        },
                      );
                    },
                  );
                }
              } else {
                print('🔒 개인정보 이미 동의됨 - ChatHomePage에서 팝업 생략');
              }
            } catch (e) {
              print('🚨 ChatHomePage에서 개인정보 동의 상태 확인 실패: $e');
            }

            // 🔥 새로 추가: 앱 시작시 서버에서 알림 데이터 초기 로드
            try {
              await _loadAlertsFromAPI(ref);
              print('✅ 앱 시작시 서버 알림 데이터 초기 로드 완료');
            } catch (e) {
              print('⚠️ 앱 시작시 서버 알림 데이터 로드 실패: $e');
            }

            // 🎁 새로 추가: 앱 시작시 선물 개수 초기 로드
            try {
              await _updateGiftCount();
              print('✅ 앱 시작시 선물 개수 초기 로드 완료');
            } catch (e) {
              print('⚠️ 앱 시작시 선물 개수 초기 로드 실패: $e');
            }
          } else {
            print('⚠️ AMQP 초기 연결 실패 - 자동 재연결이 시도됩니다.');
          }
        } else {
          print('⚠️ 유효하지 않은 사용자 ID로 인해 AMQP 연결을 시도하지 않습니다: $userId');
        }
      } catch (e) {
        print('❌ AMQP 초기화 실패: $e');
      }
    });
  }

  /// 결재 요청 서비스 초기화
  void _initializeLeaveApprovalService() async {
    print('🔵 [ChatHome] _initializeLeaveApprovalService() 호출됨');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('🔵 [ChatHome] PostFrameCallback 실행 시작');
      try {
        final userId = ref.read(userIdProvider);
        print('🔵 [ChatHome] userId 확인: $userId');

        if (userId == null || userId.isEmpty) {
          print('🚫 결재 요청 서비스: 사용자 ID가 없음');
          return;
        }

        // 결재 요청 서비스 시작 (is_approver가 true인 사용자만 허용)
        final isApprover = ref.read(approverProvider);
        print('🔵 [ChatHome] isApprover 확인: $isApprover');
        print(
            '🔵 [ChatHome] LeaveApprovalRealtimeService.startListening 호출 시작...');

        await LeaveApprovalRealtimeService.instance.startListening(
            userId, ProviderScope.containerOf(context),
            isApprover: isApprover);

        print('🔵 [ChatHome] LeaveApprovalRealtimeService.startListening 완료');

        // 결재 요청 스트림 구독
        _approvalRequestSubscription =
            LeaveApprovalRealtimeService.instance.approvalRequestStream.listen(
          (approvalRequest) {
            _handleApprovalRequest(approvalRequest);
          },
          onError: (error) {
            print('❌ 결재 요청 스트림 오류: $error');
          },
        );

        // 전자결재 알림 스트림 구독 (eapproval.userId)
        print('🟣 [ChatHome] eapproval 스트림 구독 시작');
        _eapprovalMessageSubscription = LeaveApprovalRealtimeService
            .instance.eapprovalMessageStream
            .listen((eMsg) {
          print(
              '🟣 [ChatHome] eapproval 메시지 수신: title="${eMsg.title}", name="${eMsg.name}", dept="${eMsg.department}", type="${eMsg.approvalType}"');

          // eapproval_cc 타입은 별도 UI에서 처리하므로 기존 알림에 추가하지 않음
          if (eMsg.approvalType == 'eapproval_cc') {
            print('🚫 [ChatHome] eapproval_cc 타입 메시지는 기존 알림에서 제외');
            return;
          }

          if (!mounted) return;
          setState(() {
            _eapprovalMessages.add(eMsg);
            _showEapprovalNotificationIcon = true;
          });
        }, onError: (error) {
          print('❌ 전자결재 알림 스트림 오류: $error');
        });

        print('✅ 결재 요청 서비스 초기화 완료');
      } catch (e) {
        print('❌ 결재 요청 서비스 초기화 실패: $e');
      }
    });
  }

  /// 결재 요청 처리
  void _handleApprovalRequest(LeaveApprovalRequest request) {
    if (!mounted) return;

    print('📨 [ChatHome] AMQP 결재 요청 수신: ${request.name}');

    // 알림 아이콘 표시 및 실제 대기 건 수 조회 (배지 표시용)
    setState(() {
      _showApprovalNotificationIcon = true;
    });

    // API 호출하여 대기 건 수 확인 (배지 숫자 표시)
    _fetchApprovalRequests();

    print('✅ [ChatHome] 결재 요청 알림 아이콘 표시 완료');
  }

  /// API를 통해 실제 대기 중인 결재 건 조회
  Future<void> _fetchApprovalRequests() async {
    try {
      print('🔍 [ChatHome] 결재 대기 목록 API 호출 시작');

      final userId = ref.read(userIdProvider);
      print('🔍 [ChatHome] 현재 로그인한 사용자 ID: $userId');

      if (userId == null || userId.isEmpty) {
        print('⚠️ [ChatHome] 사용자 ID가 없어 API 호출 불가');
        return;
      }

      print('🔍 [ChatHome] API에 전송할 approver_id: $userId');

      final waitingLeaves = await LeaveApiService.getAdminWaitingLeaves(
        approverId: userId,
      );

      if (!mounted) return;

      setState(() {
        _approvalRequests =
            waitingLeaves.map((leave) => leave.toJson()).toList();
      });

      print('✅ [ChatHome] 결재 대기 목록 조회 완료: ${waitingLeaves.length}건');
    } catch (e) {
      print('❌ [ChatHome] 결재 대기 목록 조회 실패: $e');
    }
  }

  /// 결재 요청 메시지 클릭 처리
  void handleApprovalRequestClick(Map<String, dynamic> approvalData) {
    // 결재 요청 데이터를 LeaveApprovalRequest 객체로 변환
    final request = LeaveApprovalRequest.fromJson(approvalData);

    // 결재 패널 표시
    _showApprovalPanel(request);
  }

  /// 결재 패널 표시
  void _showApprovalPanel(LeaveApprovalRequest request) async {
    // 기존 휴가 결재 승인 화면을 모달로 열기
    final result = await Navigator.of(context).pushNamed(
      '/admin_leave_approval',
      arguments: {
        'approval_request': request,
        'from_chat': true,
      },
    );

    // 관리자휴가결재화면에서 처리된 경우 리스트에서 제거
    if (result == true && mounted) {
      setState(() {
        _approvalRequests.removeWhere((req) {
          final reqId = req['id']?.toString() ??
              req['requestId']?.toString() ??
              req['leave_id']?.toString() ??
              req['request_id']?.toString() ??
              '';
          final requestId = request.toJson()['id']?.toString() ??
              request.toJson()['requestId']?.toString() ??
              request.toJson()['leave_id']?.toString() ??
              request.toJson()['request_id']?.toString() ??
              '';
          return reqId == requestId && reqId.isNotEmpty;
        });
      });
      print('✅ [ChatHome] 관리자휴가결재화면에서 처리된 건 제거 완료');
    }
  }

  /// 백그라운드 초기화 상태 리스너 설정
  void _setupBackgroundInitListener() {
    final backgroundService = BackgroundInitService();

    _backgroundInitSubscription =
        backgroundService.statusStream.listen((result) {
      print('🔄 [ChatHome] 백그라운드 초기화 상태: ${result.status}');

      // 성공 또는 실패시 진행률 숨기기
      if (result.isSuccess || result.hasFailed) {
        if (result.isSuccess) {
          print('✅ [ChatHome] 백그라운드 초기화 성공');
        } else {
          print('⚠️ [ChatHome] 백그라운드 초기화 실패: ${result.error}');
        }

        // 3초 후 자동으로 진행률 숨김
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            ref.read(loginProgressProvider.notifier).reset();
          }
        });
      }
    });
  }

  /// 로그인 진행률이 AMQP 연결 단계일 때 백그라운드 초기화 시작
  void _startBackgroundInitIfNeeded() {
    final currentStep = ref.read(loginProgressProvider);
    final userId = ref.read(userIdProvider);

    // AMQP 연결 단계이고 사용자 ID가 있으면 백그라운드 초기화 시작
    if (currentStep == LoginStep.connectingAmqp &&
        userId != null &&
        userId.isNotEmpty) {
      print('🚀 [ChatHome] 백그라운드 초기화 시작: $userId');
      _performBackgroundInitialization(userId);
    }
  }

  /// 백그라운드에서 나머지 초기화 수행 (메인 화면에서 실행)
  Future<void> _performBackgroundInitialization(String username) async {
    print('🔄 [ChatHome] 백그라운드 초기화 시작');

    final backgroundService = BackgroundInitService();

    // 진행률 업데이트 콜백 설정
    final result = await backgroundService.performBackgroundInit(
      userId: username,
      ref: ref,
      onStepChange: (step) {
        // Provider를 통해 진행률 업데이트
        if (mounted) {
          ref.read(loginProgressProvider.notifier).setStep(step);
        }
      },
    );

    if (result.isSuccess) {
      print('✅ [ChatHome] 백그라운드 초기화 완료');
    } else {
      print('⚠️ [ChatHome] 백그라운드 초기화 부분 실패: ${result.error}');
      // 실패해도 사용자 경험에는 영향 없음

      // 실패시에도 진행률 완료 상태로 설정 (표시 숨김용)
      if (mounted) {
        ref.read(loginProgressProvider.notifier).setStep(LoginStep.completed);
      }
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    _confettiController.dispose(); // ConfettiController 해제
    _backgroundInitSubscription?.cancel(); // 백그라운드 초기화 리스너 해제
    _approvalRequestSubscription?.cancel(); // 결재 요청 스트림 구독 해제
    _eapprovalMessageSubscription?.cancel(); // 전자결재 알림 스트림 구독 해제

    // 휴가 알림 시스템 정리 - mounted 체크 추가
    if (mounted) {
      try {
        ref.read(leaveNotificationProvider.notifier).stopListening();
      } catch (e) {
        print('⚠️ 휴가 알림 시스템 정리 중 오류: $e');
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(userIdProvider);
    final themeState = ref.watch(themeProvider); // 테마 상태 추가

    if (userId == null) {
      // 사용자 아이디가 없을 때 처리 (예: 로그인 페이지로 이동)
      Future.microtask(() {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final chatState = ref.watch(chatProvider);
    final chatNotifier = ref.read(chatProvider.notifier);

    // hr_leave_grant 트리거 감지하여 전자결재 패널 자동 열기
    ref.listen<String?>(
      chatProvider.select((state) => chatNotifier.tempSystemMessage),
      (previous, current) {
        if (!mounted) return; // 위젯이 dispose된 경우 리턴

        if (current == 'OPEN_ELECTRONIC_APPROVAL_PANEL') {
          print('🏢 [ChatHomePageV5] hr_leave_grant 트리거 감지 - 전자결재 패널 로딩 시작');

          // 로딩 상태 시작
          if (mounted) {
            setState(() {
              _isElectronicApprovalLoading = true;
              // 패널이 열릴 때 사이드바를 접기 (AppBar 버튼과 동일한 로직)
              if (chatState.isSidebarVisible) {
                chatNotifier.toggleSidebarVisibility();
              }
            });
          }

          // 10초 후에 실제 모달 표시
          Future.delayed(const Duration(seconds: 10), () {
            if (mounted) {
              setState(() {
                _isElectronicApprovalLoading = false;
                _isElectronicApprovalPanelVisible = true;
              });
              print('🏢 [ChatHomePageV5] 전자결재 패널 표시 완료');
            }
          });

          // 메시지 초기화
          if (mounted) {
            chatNotifier.tempSystemMessage = null;
          }
        }
      },
    );

    // 휴가 상신 초안 모달 상태 변화에 따라 사이드바 자동 접기/펼치기
    ref.listen<LeaveModalState>(leaveModalProvider, (previous, next) {
      if (!mounted) return; // 위젯이 dispose된 경우 리턴

      // 모달이 새로 펼쳐질 때: 사이드바가 열려있으면 접기
      if ((previous == null || !previous.isExpanded) && next.isExpanded) {
        if (mounted) {
          final isSidebarVisible = ref.read(chatProvider).isSidebarVisible;
          if (isSidebarVisible) {
            ref.read(chatProvider.notifier).toggleSidebarVisibility();
          }
        }
      }

      // 모달이 다시 들어갈 때(펼쳐짐 -> 접힘 또는 숨김): 사이드바가 닫혀있으면 펼치기
      final wasExpanded = previous?.isExpanded ?? false;
      final nowRetracted = next.isCollapsed || !next.isVisible;
      if (wasExpanded && nowRetracted) {
        if (mounted) {
          final isSidebarVisible = ref.read(chatProvider).isSidebarVisible;
          if (!isSidebarVisible) {
            ref.read(chatProvider.notifier).toggleSidebarVisibility();
          }
        }
      }
    });

    // 로그아웃 처리 함수
    Future<void> handleLogout() async {
      final confirmed = await CommonUIUtils.showConfirmDialog(
        context,
        '로그아웃',
        '정말 로그아웃 하시겠습니까?',
      );

      if (confirmed == true) {
        // AMQP 서비스 완전 정리
        final amqpService = ref.read(amqpServiceProvider);
        try {
          await amqpService.dispose(); // 완전한 리소스 정리
          await LeaveApprovalRealtimeService.instance
              .stopListening(); // 결재 요청 서비스 중지
          print('🔌 로그아웃 시 AMQP 서비스 완전 정리 완료');
        } catch (e) {
          print('⚠️ AMQP 서비스 정리 중 오류: $e');
        }

        // 휴가관리 상태 초기화
        try {
          ref.read(leaveManagementProvider.notifier).resetState();
          print('🔄 로그아웃 시 휴가관리 상태 초기화 완료');
        } catch (e) {
          print('⚠️ 휴가관리 상태 초기화 중 오류: $e');
        }

        // 휴가 관련 모든 프로바이더 상태 초기화
        try {
          ref.read(leaveRequestHistoryProvider.notifier).resetState();
          ref.read(leaveBalanceProvider.notifier).resetState();
          ref.read(departmentMembersProvider.notifier).resetState();
          ref.read(departmentLeaveHistoryProvider.notifier).resetState();
          ref.read(leaveManagementTableProvider.notifier).resetState();
          print('🔄 로그아웃 시 모든 휴가 관련 프로바이더 상태 초기화 완료');
        } catch (e) {
          print('⚠️ 휴가 관련 프로바이더 상태 초기화 중 오류: $e');
        }

        // 자동 로그인 정보 삭제
        await _autoLoginService.deleteLoginInfo(ref.read(userIdProvider)!);
        ref.read(userIdProvider.notifier).state = null;

        // 로그인 페이지로 이동
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      }
    }

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF):
            const SearchIntent(),
      },
      child: Actions(
        actions: {
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (SearchIntent intent) {
              // 사이드바의 검색 다이얼로그 열기
              _showSearchDialog(context, ref);
              return null;
            },
          ),
        },
        child: GestureDetector(
          onPanStart: (details) {
            if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
              windowManager.startDragging();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          themeState.colorScheme.appBarGradientStart
                              .withValues(alpha: 0.9),
                          themeState.colorScheme.appBarGradientEnd
                              .withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                  ),
                  // 사이드바가 보일 때 세로선 오른쪽 부분을 채팅화면 배경색과 동일하게 변경
                  if (chatState.isSidebarVisible)
                    Positioned(
                      left: 269, // 세로선 오른쪽부터
                      top: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: themeState.colorScheme
                            .backgroundColor, // opacity 제거하여 순수한 배경색 사용
                      ),
                    ),
                  // 사이드바가 보일 때 사이드바 너비와 동일한 위치에 세로선 그리기
                  if (chatState.isSidebarVisible)
                    Positioned(
                      left: 268, // 세로선 위치 10px 더 증가
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 1.0,
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1.0),
                child: Row(
                  children: [
                    // Sidebar가 보일 때 사이드바 너비만큼 테두리 제거
                    if (chatState.isSidebarVisible)
                      Container(
                        width: 269,
                        height: 1.0,
                        color: Colors.transparent, // 왼쪽 부분 테두리 제거
                      ),
                    // 세로선 오른쪽 부분은 테두리 제거 (투명)
                    if (chatState.isSidebarVisible)
                      Expanded(
                        child: Container(
                          height: 1.0,
                          color: Colors.transparent, // 오른쪽 부분 테두리 제거
                        ),
                      ),
                    // 사이드바가 숨겨져 있을 때는 전체 테두리 유지
                    if (!chatState.isSidebarVisible)
                      Expanded(
                        child: Container(
                          color: themeState.themeMode == AppThemeMode.light
                              ? Colors.grey
                                  .withValues(alpha: 0.3) // Light 테마: 회색 테두리
                              : Colors.grey.withValues(
                                  alpha: 0.3), // Dark 테마도 동일한 회색 테두리
                          height: 1.0,
                        ),
                      ),
                  ],
                ),
              ),
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  // ASPN AI AGENT (AAA) 타이틀
                  Flexible(
                    flex: 0,
                    child: chatState.selectedTopic.isNotEmpty
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'ASPN AI AGENT (AAA)',
                                style: TextStyle(
                                    color:
                                        themeState.colorScheme.appBarTextColor,
                                    fontSize: 20),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ver${_appVersion.isNotEmpty ? _appVersion : ''}',
                                style: TextStyle(
                                    color: themeState
                                        .colorScheme.appBarTextColor
                                        .withValues(alpha: 0.7),
                                    fontSize: 10),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '새로운 대화를 추가해 주세요',
                                style: TextStyle(
                                    color:
                                        themeState.colorScheme.appBarTextColor,
                                    fontSize: 20),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ver${_appVersion.isNotEmpty ? _appVersion : ''}',
                                style: TextStyle(
                                    color: themeState
                                        .colorScheme.appBarTextColor
                                        .withValues(alpha: 0.7),
                                    fontSize: 10),
                              ),
                            ],
                          ),
                  ),
                  // 전광판 영역 (유동적 크기)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Builder(
                        builder: (context) {
                          final tickerMessage =
                              ref.watch(alertTickerMessageProvider);

                          return AnnouncementTicker(
                            message: tickerMessage,
                            textStyle: TextStyle(
                              color: themeState.colorScheme.appBarTextColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            backgroundColor: themeState
                                .colorScheme.appBarTextColor
                                .withValues(alpha: 0.1),
                            showOnlyWhenMessage: true,
                            announcementPrefix: '📢 공지사항',
                            displayDuration: const Duration(
                                seconds: 40), // 30초 스크롤에 맞춰 시간 조정
                            animationDuration:
                                const Duration(milliseconds: 600),
                          );
                        },
                      ),
                    ),
                  ),
                  // 아이콘들을 사이드바 기준으로 왼쪽에서 고정 위치
                  Transform.translate(
                    offset: const Offset(0, 0), // 왼쪽에서부터 500px 위치에 고정
                    child: Row(
                      children: [
                        // 5px 간격 (더 줄임)
                        const SizedBox(width: 5),
                        // 받은 선물함 아이콘 (새로 추가)
                        _buildDashboardIcon(context, Icons.card_giftcard,
                            '받은선물함', themeState, ref),
                        // const SizedBox(width: 4),
                        // // 전자결재 아이콘 추가 (AppBar에서는 숨김)
                        // _buildDashboardIcon(
                        //     context, Icons.description, '전자결재', themeState, ref),
                        // const SizedBox(width: 4),
                        // // 휴가관리 아이콘 추가 (AppBar에서는 숨김)
                        // _buildDashboardIcon(
                        //     context, Icons.beach_access, '휴가관리', themeState, ref),
                        // const SizedBox(width: 4),
                        // 대시보드 아이콘들 (간격 줄임)
                        _buildDashboardIcon(
                            context, Icons.email, 'GroupWare', themeState, ref),
                        const SizedBox(width: 4),
                        _buildDashboardIcon(
                            context, Icons.payment, 'e-Acc', themeState, ref),
                        const SizedBox(width: 4),
                        _buildDashboardIcon(context, Icons.lightbulb_outline,
                            'CSR', themeState, ref),
                        const SizedBox(width: 4),
                        // 생일 팝업 테스트 버튼 추가
                        _buildNotificationIcon(context, themeState, ref),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                // 버전 정보 버튼 추가
                IconButton(
                  icon: Icon(
                    Icons.info_outline,
                    color: themeState.colorScheme.name == 'Dark'
                        ? Colors.white
                        : themeState.colorScheme.appBarTextColor
                            .withValues(alpha: 0.7),
                  ),
                  tooltip: '앱 버전 정보',
                  onPressed: () {
                    _showVersionInfoDialog();
                  },
                ),
                // 전자결재 상신 초안 버튼 추가
                IconButton(
                  icon: Icon(
                    Icons.description_outlined,
                    color: themeState.colorScheme.name == 'Dark'
                        ? Colors.white
                        : themeState.colorScheme.appBarTextColor
                            .withValues(alpha: 0.7),
                  ),
                  tooltip: '전자결재 상신 초안',
                  onPressed: () {
                    if (_isElectronicApprovalPanelVisible) {
                      // 패널이 이미 열려있으면 바로 닫기
                      setState(() {
                        _isElectronicApprovalPanelVisible = false;
                        // 패널이 닫힐 때 사이드바를 다시 펼치기
                        ref
                            .read(chatProvider.notifier)
                            .toggleSidebarVisibility();
                      });
                    } else {
                      // 패널이 닫혀있으면 바로 열기
                      setState(() {
                        _isElectronicApprovalPanelVisible = true;
                        // 패널이 열릴 때 사이드바를 접기
                        if (chatState.isSidebarVisible) {
                          ref
                              .read(chatProvider.notifier)
                              .toggleSidebarVisibility();
                        }
                      });
                    }
                  },
                ),
                // 설정 버튼 추가
                IconButton(
                  icon: Icon(
                    Icons.settings,
                    color: themeState.colorScheme.name == 'Dark'
                        ? Colors.white
                        : themeState.colorScheme.appBarTextColor
                            .withValues(alpha: 0.7),
                  ),
                  tooltip: '환경 설정',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsPage()),
                    );
                  },
                ),
                // 로그아웃 버튼 추가
                IconButton(
                  icon: Icon(
                    Icons.logout,
                    color: themeState.colorScheme.name == 'Dark'
                        ? Colors.white
                        : themeState.colorScheme.appBarTextColor
                            .withValues(alpha: 0.7),
                  ),
                  tooltip: '로그아웃',
                  onPressed: () => handleLogout(),
                ),
                // 피드백 아이콘을 텍스트로 변경
                Tooltip(
                  message: '구글 시트로 이동합니다. 건의사항 및 피드백 부탁드립니다.',
                  child: TextButton(
                    onPressed: () {
                      // 현재 로그인한 사용자 ID 가져오기 (Riverpod 사용)
                      final userId = ref.read(userIdProvider);
                      _launchUserSpecificGoogleSheet(context, userId!);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      foregroundColor: Colors.red, // 텍스트 색상을 빨간색으로 유지
                    ),
                    child: const Text(
                      '이슈리스트',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                // const WindowControls(),
              ],
            ),
            body: Stack(
              children: [
                // 휴가 알림이 있을 때 배경 클릭으로 닫기
                Consumer(builder: (context, ref, child) {
                  final notificationState =
                      ref.watch(leaveNotificationProvider);

                  // 알림이 있을 때만 배경 감지
                  if (notificationState.totalNotificationCount > 0) {
                    return Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent, // 자식 위젯도 클릭 가능
                        onTap: () {
                          // 배경 클릭 시 모든 휴가 알림 닫기
                          ref
                              .read(leaveNotificationProvider.notifier)
                              .clearAllNotifications();
                        },
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),
                Row(
                  children: [
                    if (chatState.isSidebarVisible)
                      Container(
                        width: 269,
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.3),
                              width: 1.0,
                            ),
                          ),
                        ),
                        child: Sidebar(
                          key: _sidebarKey,
                          arvHistory: chatState.arvChatHistory,
                          selectedTopic: chatState.selectedTopic,
                          onTopicSelected: (topicId) async {
                            await chatNotifier.selectTopic(
                                topicId); // selectTopic이 완료될 때까지 대기
                          },
                          onEditTopic: (archiveId, newTitle) => chatNotifier
                              .editArchiveTitle(archiveId, newTitle),
                          onDeleteTopic: (archiveId) =>
                              chatNotifier.deleteArchive(context, archiveId),
                          onToggleSidebar: chatNotifier.toggleSidebarVisibility,
                        ),
                      ),
                    // 채팅 영역 너비를 모달 상태에 따라 동적으로 조정
                    Consumer(builder: (context, ref, child) {
                      final modalState = ref.watch(leaveModalProvider);
                      final originalModalWidth =
                          modalState.isExpanded ? 450.0 : 0.0;

                      // 새로운 TEST 패널이 열려있을 때는 화면의 40%를 차지
                      final screenWidth = MediaQuery.of(context).size.width;
                      final testPanelWidth = _isElectronicApprovalPanelVisible
                          ? screenWidth * 0.6
                          : 0.0;

                      // TEST 패널이 열려있으면 기존 모달은 무시하고, 그렇지 않으면 기존 모달 사용
                      final effectiveModalWidth =
                          _isElectronicApprovalPanelVisible
                              ? testPanelWidth
                              : originalModalWidth;

                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin: EdgeInsets.only(right: effectiveModalWidth),
                          child: Column(
                            children: [
                              // 대시보드 제거됨 - 아이콘들이 AppBar로 이동
                              Flexible(
                                child: _getChatScreenByType(
                                  chatState,
                                  chatNotifier.controller,
                                  chatNotifier.focusNode,
                                  (context) => chatNotifier
                                      .sendMessageToAIServer(userId, context),
                                  chatNotifier.scrollController,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                // 사이드바가 숨겨져 있을 때만 토글 버튼 표시
                if (!chatState.isSidebarVisible)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: chatNotifier.toggleSidebarVisibility,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 20,
                    ),
                  ),
                // 색종이 효과 위젯
                if (_isConfettiPlaying)
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality:
                          BlastDirectionality.explosive, // 모든 방향으로
                      shouldLoop: false, // 한 번만 재생
                      colors: const [
                        // 색종이 색상
                        Colors.green, Colors.blue, Colors.pink, Colors.orange,
                        Colors.purple
                      ],
                      createParticlePath: drawStar, // 별 모양 색종이
                    ),
                  ),

                // 휴가 알림 오버레이
                LeaveNotificationOverlay(
                  onNavigateToLeaveManagement: () {
                    print('📅 휴가관리 페이지로 이동 시작');
                    Navigator.of(context)
                        .push(
                      MaterialPageRoute(
                        builder: (context) => const LeaveManagementScreen(),
                      ),
                    )
                        .then((value) {
                      print('📅 휴가관리 페이지에서 돌아옴');
                    });
                  },
                ),

                // 백그라운드 초기화 진행률 표시 (우측 하단 고정)
                Consumer(builder: (context, ref, child) {
                  final currentStep = ref.watch(loginProgressProvider);

                  // 인증 완료 또는 백그라운드 초기화가 진행 중일 때만 표시
                  final shouldShow = currentStep != LoginStep.authenticating &&
                      currentStep != LoginStep.completed;

                  if (!shouldShow) return const SizedBox.shrink();

                  return Positioned(
                    right: 20,
                    bottom: 20,
                    child: AnimatedOpacity(
                      opacity: shouldShow ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        constraints: const BoxConstraints(
                          maxWidth: 320,
                        ),
                        child: const MiniLoginProgress(),
                      ),
                    ),
                  );
                }),

                // 휴가 상신 모달/접힌 탭 (오른쪽에 표시)
                Consumer(builder: (context, ref, child) {
                  final modalState = ref.watch(leaveModalProvider);

                  if (!modalState.isVisible) {
                    return const SizedBox.shrink();
                  }

                  // 접힌 상태일 때는 탭 표시
                  if (modalState.isCollapsed) {
                    return const Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: LeaveCollapsedTab(),
                    );
                  }

                  // 펼쳐진 상태일 때는 전체 모달 표시
                  if (modalState.isExpanded) {
                    return Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      // customWidth가 있으면 사용, 없으면 기본 600px
                      child: SizedBox(
                        width: modalState.customWidth ?? 600,
                        child: LeaveDraftModal(
                          onClose: null, // onClose 콜백을 null로 설정하여 자동 닫힘 방지
                        ),
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                }),

                // 오른쪽 끝 호버 감지 영역 (접힌 탭이 있을 때만 표시)
                Consumer(builder: (context, ref, child) {
                  final modalState = ref.watch(leaveModalProvider);

                  // 접힌 상태일 때만 호버 감지 영역 표시
                  if (modalState.isCollapsed) {
                    return Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: MouseRegion(
                        onEnter: (_) {
                          ref
                              .read(leaveModalProvider.notifier)
                              .setHovered(true);
                          ref.read(leaveModalProvider.notifier).expandModal();
                        },
                        child: Container(
                          width: 10, // 얇은 감지 영역
                          height: double.infinity,
                          color: Colors.transparent,
                        ),
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                }),

                // 승인 슬라이드 패널
                if (_isApprovalPanelVisible) ...[
                  // 배경 오버레이 (펼쳐져 있을 때만 표시)
                  if (_isApprovalPanelExpanded)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () {
                          // 핀이 고정되지 않은 경우에만 패널 완전히 닫기
                          if (!_isApprovalPanelPinned) {
                            setState(() {
                              _isApprovalPanelVisible = false;
                              _isApprovalPanelExpanded = false;
                              _isApprovalPanelPinned = false;
                            });
                          }
                        },
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  // 슬라이드 패널
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    width: 400,
                    child: _buildApprovalSlidePanel(),
                  ),
                ],

                // 결재요청도착 아이콘 (leave.approval 큐 메시지 수신 시 표시)
                if (_showApprovalNotificationIcon)
                  Positioned(
                    top: MediaQuery.of(context).padding.top +
                        56 +
                        10, // 상태바 + AppBar + 여백
                    right: 16,
                    child: _buildApprovalNotificationIcon(),
                  ),

                // 전자결재 알림 아이콘 (eapproval.userId 수신 시 표시)
                if (_showEapprovalNotificationIcon &&
                    _eapprovalMessages.isNotEmpty)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 56 + 10,
                    right: 100, // 기존 알림과 간격
                    child: _buildEapprovalNotificationIcon(),
                  ),

                // 전자결재 상신 초안 로딩 패널
                if (_isElectronicApprovalLoading)
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    width: 400,
                    child: _buildElectronicApprovalLoadingPanel(),
                  ),

                // TEST 전자결재 상신 초안 패널 (화면의 60% 차지)
                if (_isElectronicApprovalPanelVisible)
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    width: MediaQuery.of(context).size.width * 0.6,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      transform: Matrix4.translationValues(
                        _isElectronicApprovalPanelVisible
                            ? 0.0
                            : MediaQuery.of(context).size.width * 0.6,
                        0.0,
                        0.0,
                      ),
                      child: CommonElectronicApprovalModal(
                        initialApprovalType: '휴가 부여 상신',
                        onClose: () {
                          setState(() {
                            _isElectronicApprovalPanelVisible = false;
                            // 모달이 닫힐 때 사이드바를 다시 펼치기
                            ref
                                .read(chatProvider.notifier)
                                .toggleSidebarVisibility();
                          });
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 검색 다이얼로그를 띄우는 메서드
  void _showSearchDialog(BuildContext context, WidgetRef ref) {
    // 사이드바가 보이지 않으면 먼저 사이드바를 열기
    final chatState = ref.read(chatProvider);
    if (!chatState.isSidebarVisible) {
      ref.read(chatProvider.notifier).toggleSidebarVisibility();
    }

    // Sidebar의 검색 다이얼로그를 호출
    _sidebarKey.currentState?.showSearchDialog(context);
  }

// 구글 시트 열기 함수
  Future<void> _launchUserSpecificGoogleSheet(
      BuildContext context, String userId) async {
    // 기본 구글 시트 URL
    const baseUrl =
        'https://docs.google.com/spreadsheets/d/17obJ-H2J4wcf2EKIEPxg9-HCFQuMHc954XP4lnddXWo/edit?gid=1751857071#gid=1751857071';

    // 모든 사용자를 동일한 탭으로 이동
    final Uri uri = Uri.parse(baseUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // URL 실행 실패시 사용자에게 알림
        if (context.mounted) {
          CommonUIUtils.showErrorSnackBar(context, '이슈 보고 페이지를 열 수 없습니다.');
        }
      }
    } catch (e) {
      // 예외 처리
      if (context.mounted) {
        CommonUIUtils.showErrorSnackBar(context, '링크 실행 중 오류 발생: $e');
      }
    }
  }

  Widget _getChatScreenByType(
    ChatState chatState,
    TextEditingController controller,
    FocusNode focusNode,
    Function(BuildContext) onSendMessage,
    ScrollController scrollController,
  ) {
    switch (chatState.archiveType) {
      case 'code':
        return CodingAssistantPage(
          controller: controller,
          focusNode: focusNode,
          onSendMessage: onSendMessage,
          scrollController: scrollController,
        );
      case 'sap':
        return SapMainPage(
          controller: controller,
          focusNode: focusNode,
          onSendMessage: onSendMessage,
          scrollController: scrollController,
        );
      default:
        return ChatArea(
          controller: controller,
          focusNode: focusNode,
          onSendMessage: onSendMessage,
          scrollController: scrollController,
        );
    }
  }

  Widget _buildDashboardIcon(BuildContext context, IconData icon, String label,
      ThemeState themeState, WidgetRef ref) {
    // 받은 선물함인 경우 새 선물 표시 확인
    bool hasNewGift = false;
    int giftCount = 0;
    if (label == '받은선물함') {
      hasNewGift = ref.watch(notificationProvider).hasNewGift;
      giftCount = ref.watch(giftCountProvider);
    }

    return Tooltip(
      message: label == '받은선물함' ? '받은선물함 : 미사용 쿠폰 ${giftCount}개' : label,
      child: Container(
        width: 40,
        height: 40,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _handleIconTap(context, label, ref);
            },
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    icon,
                    color: themeState.colorScheme.name == 'Dark'
                        ? Colors.white
                        : themeState.colorScheme.appBarTextColor
                            .withValues(alpha: 0.8),
                    size: 22,
                  ),
                ),
                // 선물 개수 배지 (받은 선물함인 경우만)
                if (label == '받은선물함' && giftCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          giftCount > 99 ? '99+' : giftCount.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                // 새 선물 표시 (받은 선물함인 경우만, 개수가 0일 때만)
                if (label == '받은선물함' && hasNewGift && giftCount == 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(
      BuildContext context, ThemeState themeState, WidgetRef ref) {
    final notificationState = ref.watch(notificationProvider);
    final unreadCount = notificationState.unreadCount;

    // 디버깅을 위한 로그 (필요시에만 출력)
    // print('🔍 UI 알림 상태: ${notificationState.notifications.length}개, 읽지 않음: $unreadCount개');

    return Tooltip(
      message: '알림 ($unreadCount개)',
      child: Container(
        width: 40,
        height: 40,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _handleNotificationTap(context, ref);
            },
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.notifications,
                    color: themeState.colorScheme.name == 'Dark'
                        ? Colors.white
                        : themeState.colorScheme.appBarTextColor
                            .withValues(alpha: 0.8),
                    size: 22,
                  ),
                ),
                // 읽지 않은 알림 배지
                if (unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 선물 개수 업데이트 함수
  Future<void> _updateGiftCount() async {
    try {
      final userId = ref.read(userIdProvider);
      if (userId != null && userId.isNotEmpty) {
        final giftCount = await ApiService.updateGiftCount(userId);
        ref.read(giftCountProvider.notifier).state = giftCount;
        print('🎁 선물 개수 업데이트 완료: $giftCount개');
      }
    } catch (e) {
      print('❌ 선물 개수 업데이트 실패: $e');
    }
  }

  // 아이콘 탭 처리 메서드
  void _handleIconTap(BuildContext context, String label, WidgetRef ref) async {
    if (label == '받은선물함') {
      // 받은선물함 클릭 시 선물 개수 업데이트
      await _updateGiftCount();
      _showGiftBox(context, ref);
    } else if (label == '전자결재') {
      // 전자결재 화면으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SignFlowScreen()),
      );
    } else if (label == '휴가관리') {
      // 승인자 여부 확인
      final isApprover = ref.read(approverProvider);
      
      if (isApprover) {
        // 승인자인 경우: 관리자 휴가관리 페이지로 이동
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminLeaveApprovalScreen()),
        );
      } else {
        // 일반사용자인 경우: 기존 휴가관리 페이지로 이동
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LeaveManagementScreen()),
        );
      }
    } else if (label == 'GroupWare') {
      _launchURL('https://gw.aspnc.com');
    } else if (label == 'e-Acc') {
      _launchURL('https://eacc.hellocompany.co.kr');
    } else if (label == 'CSR') {
      // CSR 기능 미구현
      CommonUIUtils.showInfoSnackBar(context, '$label 기능은 추후 구현 예정입니다.');
    }
  }

  // 이미지 확대 다이얼로그 표시
  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: isDarkTheme ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // 헤더
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkTheme ? Colors.grey[800]! : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.image,
                          color: isDarkTheme ? Colors.blue[300] : Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '쿠폰 이미지',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkTheme ? Colors.white : null,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: isDarkTheme ? Colors.white : null,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // 이미지 영역
                Expanded(
                  child: Container(
                    margin: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: InteractiveViewer(
                        panEnabled: true,
                        boundaryMargin: EdgeInsets.all(20),
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    '이미지 로딩 중...',
                                    style: TextStyle(
                                      color:
                                          isDarkTheme ? Colors.grey[300] : null,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 64,
                                    color: Colors.red.shade400,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    '이미지를 불러올 수 없습니다',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isDarkTheme
                                          ? Colors.red[300]
                                          : Colors.red.shade600,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () => _launchURL(imageUrl),
                                    child: Text(
                                      '브라우저에서 열기',
                                      style: TextStyle(
                                        color: isDarkTheme
                                            ? Colors.grey[300]
                                            : null,
                                      ),
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
                ),

                // 하단 액션 버튼들
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkTheme ? Colors.grey[800] : Colors.grey.shade50,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _launchURL(imageUrl),
                        icon: Icon(Icons.open_in_new, size: 16),
                        label: Text('브라우저에서 열기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              final isDarkTheme =
                                  Theme.of(context).brightness ==
                                      Brightness.dark;
                              return AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                content: Text(
                                  '모바일로 내보내기는 3분~ 5분정도 시간이 소요 됩니다. 전송 하시겠습니까?',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkTheme ? Colors.white : null,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(); // 다이얼로그 닫기
                                    },
                                    child: Text(
                                      '취소',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(); // 다이얼로그 닫기
                                      _sendToMobile(context, imageUrl);
                                    },
                                    child: Text(
                                      '전송',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue[600],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF7b8fd1), // 더 어두운 파스텔 블루
                                Color(0xFFb39ddb), // 더 어두운 파스텔 보라
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Color(0xFFb7caff).withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.smartphone,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                '모바일로 내보내기',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // static 메서드로 외부에서 호출 가능한 선물함 표시
  static void _showGiftBoxStatic(BuildContext context, WidgetRef ref) {
    // 새 선물 표시 제거
    ref.read(notificationProvider.notifier).clearNewGiftIndicator();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDarkTheme = ref.read(themeProvider).colorScheme.name == 'Dark';
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 520,
            height: 600,
            decoration: BoxDecoration(
              color: isDarkTheme ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDarkTheme ? Colors.grey[800]! : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDarkTheme
                              ? Colors.grey[700]
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.card_giftcard,
                          color:
                              isDarkTheme ? Colors.white : Colors.grey.shade700,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          '받은 선물함',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: isDarkTheme
                                ? Colors.white
                                : Colors.grey.shade800,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close,
                            color: isDarkTheme
                                ? Colors.white
                                : Colors.grey.shade600),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // 내용
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _loadGiftsFromAPIStatic(ref),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                '선물함을 불러오는 중...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDarkTheme
                                      ? Colors.grey[300]
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red.shade400,
                              ),
                              SizedBox(height: 16),
                              Text(
                                '선물함을 불러오는 중 오류가 발생했습니다',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDarkTheme
                                      ? Colors.grey[300]
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${snapshot.error}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkTheme
                                      ? Colors.grey[400]
                                      : Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }
                      final data = snapshot.data!;
                      final gifts = data['gifts'] as List<dynamic>? ?? [];
                      if (gifts.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isDarkTheme
                                      ? Colors.grey[800]
                                      : Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.card_giftcard,
                                  size: 48,
                                  color: isDarkTheme
                                      ? Colors.grey[500]
                                      : Colors.grey.shade400,
                                ),
                              ),
                              SizedBox(height: 24),
                              Text(
                                '받은 선물이 없습니다',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isDarkTheme
                                      ? Colors.grey[300]
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '선물이 도착하면\n여기에 표시됩니다',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkTheme
                                      ? Colors.grey[400]
                                      : Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: EdgeInsets.all(24),
                        itemCount: gifts.length,
                        itemBuilder: (context, index) {
                          final gift = gifts[index];
                          return _buildGiftItemStatic(context, gift);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Reader용 선물함 표시 메서드

  // static 메서드들
  static Future<Map<String, dynamic>> _loadGiftsFromAPIStatic(
      WidgetRef ref) async {
    try {
      final userId = ref.read(userIdProvider);
      if (userId == null || userId.isEmpty) {
        throw Exception('사용자 ID를 찾을 수 없습니다');
      }
      final response = await ApiService.checkGifts(userId);
      return response;
    } catch (e) {
      print('선물함 로드 실패: $e');
      throw e;
    }
  }

  static Widget _buildGiftItemStatic(BuildContext context, dynamic gift) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.card_giftcard,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '받은 선물',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    gift['gift_type'] ?? '쿠폰',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 선물 내용
          if (gift['gift_content'] != null) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                gift['gift_content'],
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],

          // 이미지 또는 링크
          if (gift['gift_url'] != null) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _launchURLStatic(gift['gift_url']),
                      icon: Icon(Icons.open_in_new, size: 16),
                      label: Text('선물 확인하기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 받은 시간
          if (gift['received_at'] != null) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Icon(Icons.access_time,
                      size: 12, color: Colors.grey.shade500),
                  SizedBox(width: 4),
                  Text(
                    gift['received_at'],
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Future<void> _launchURLStatic(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  // 받은 선물함 표시
  void _showGiftBox(BuildContext context, WidgetRef ref) {
    // 새 선물 표시 제거
    ref.read(notificationProvider.notifier).clearNewGiftIndicator();

    // 선물함 열 때 선물 개수 업데이트
    _updateGiftCount();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDarkTheme = ref.read(themeProvider).colorScheme.name == 'Dark';
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 520,
            height: 600,
            decoration: BoxDecoration(
              color: isDarkTheme ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDarkTheme ? Colors.grey[800]! : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDarkTheme
                              ? Colors.grey[700]
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.card_giftcard,
                          color:
                              isDarkTheme ? Colors.white : Colors.grey.shade700,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          '받은 선물함',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: isDarkTheme
                                ? Colors.white
                                : Colors.grey.shade800,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close,
                            color: isDarkTheme
                                ? Colors.white
                                : Colors.grey.shade600),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // 내용
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _loadGiftsFromAPI(ref),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                '선물함을 불러오는 중...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDarkTheme
                                      ? Colors.grey[300]
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red.shade400,
                              ),
                              SizedBox(height: 16),
                              Text(
                                '선물함을 불러오는 중 오류가 발생했습니다',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDarkTheme
                                      ? Colors.grey[300]
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${snapshot.error}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkTheme
                                      ? Colors.grey[400]
                                      : Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      final data = snapshot.data!;
                      final gifts = data['gifts'] as List<dynamic>? ?? [];

                      if (gifts.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isDarkTheme
                                      ? Colors.grey[800]
                                      : Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.card_giftcard,
                                  size: 48,
                                  color: isDarkTheme
                                      ? Colors.grey[500]
                                      : Colors.grey.shade400,
                                ),
                              ),
                              SizedBox(height: 24),
                              Text(
                                '받은 선물이 없습니다',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isDarkTheme
                                      ? Colors.grey[300]
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '선물이 도착하면\n여기에 표시됩니다',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkTheme
                                      ? Colors.grey[400]
                                      : Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: EdgeInsets.all(24),
                        itemCount: gifts.length,
                        itemBuilder: (context, index) {
                          final gift = gifts[index];
                          return Container(
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color:
                                  isDarkTheme ? Colors.grey[800] : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: isDarkTheme
                                      ? Colors.grey[600]!
                                      : Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: isDarkTheme
                                      ? Colors.black.withValues(alpha: 0.3)
                                      : Colors.grey.shade100,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // 선물 번호 (왼쪽 상단)
                                Positioned(
                                  left: 8,
                                  top: 8,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${gifts.length - index}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 헤더
                                    Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Center(
                                              child: Text(
                                                '이미지를 클릭해주세요',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '쿠폰',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // 쿠폰 이미지
                                    if (gift['coupon_img_url'] != null) ...[
                                      GestureDetector(
                                        onTap: () {
                                          _showImageDialog(
                                              context, gift['coupon_img_url']);
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          height: 140,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: isDarkTheme
                                                    ? Colors.grey[600]!
                                                    : Colors.grey.shade200),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Stack(
                                              children: [
                                                Image.network(
                                                  gift['coupon_img_url'],
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  loadingBuilder: (context,
                                                      child, loadingProgress) {
                                                    if (loadingProgress == null)
                                                      return child;
                                                    return Container(
                                                      color:
                                                          Colors.grey.shade100,
                                                      child: Center(
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            CircularProgressIndicator(
                                                              value: loadingProgress
                                                                          .expectedTotalBytes !=
                                                                      null
                                                                  ? loadingProgress
                                                                          .cumulativeBytesLoaded /
                                                                      loadingProgress
                                                                          .expectedTotalBytes!
                                                                  : null,
                                                              color: Colors.grey
                                                                  .shade400,
                                                            ),
                                                            SizedBox(height: 8),
                                                            Text(
                                                              '이미지 로딩 중...',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .grey
                                                                    .shade600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Container(
                                                      color:
                                                          Colors.grey.shade100,
                                                      child: Center(
                                                        child: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Icon(
                                                                Icons
                                                                    .error_outline,
                                                                color: Colors
                                                                    .grey
                                                                    .shade400),
                                                            SizedBox(height: 4),
                                                            Text(
                                                              '이미지 로드 실패',
                                                              style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .grey
                                                                      .shade600),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                                // 확대 아이콘 오버레이
                                                Positioned(
                                                  top: 8,
                                                  right: 8,
                                                  child: Container(
                                                    padding: EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withValues(
                                                              alpha: 0.6),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Icon(
                                                      Icons.zoom_in,
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],

                                    // 쿠폰 만료 기간
                                    if (gift['coupon_end_date'] != null &&
                                        (gift['coupon_end_date'] as String)
                                            .isNotEmpty) ...[
                                      SizedBox(height: 8),
                                      Padding(
                                        padding:
                                            EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              size: 18,
                                              color: Colors.red.shade600,
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '쿠폰 만료 기간',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Colors.red.shade700,
                                                    ),
                                                  ),
                                                  Text(
                                                    gift['coupon_end_date'],
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          Colors.red.shade800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    // 액션 버튼들
                                    Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          // 왼쪽: 브라우저에서 열기
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => _launchURL(
                                                  gift['coupon_img_url'] ?? ''),
                                              icon: Icon(Icons.open_in_new,
                                                  size: 16),
                                              label: Text('브라우저에서 열기'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.grey.shade600,
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 18,
                                                    vertical: 10),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          // 오른쪽: 모바일로 내보내기 버튼
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder:
                                                      (BuildContext context) {
                                                    final isDarkTheme =
                                                        Theme.of(context)
                                                                .brightness ==
                                                            Brightness.dark;
                                                    return AlertDialog(
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16),
                                                      ),
                                                      content: Text(
                                                        '모바일로 내보내기는 3분~ 5분정도 시간이 소요 됩니다. 전송 하시겠습니까?',
                                                        style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: isDarkTheme
                                                              ? Colors.white
                                                              : null,
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.of(
                                                                    context)
                                                                .pop(); // 다이얼로그 닫기
                                                          },
                                                          child: Text(
                                                            '취소',
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                          ),
                                                        ),
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.of(
                                                                    context)
                                                                .pop(); // 다이얼로그 닫기
                                                            _sendToMobile(
                                                              context,
                                                              gift['coupon_img_url'] ??
                                                                  '',
                                                            );
                                                          },
                                                          child: Text(
                                                            '전송',
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .blue[600],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              },
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 18,
                                                    vertical: 10),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Color(
                                                          0xFF7b8fd1), // 더 어두운 파스텔 블루
                                                      Color(
                                                          0xFFb39ddb), // 더 어두운 파스텔 보라
                                                    ],
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.centerRight,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Color(0xFFb7caff)
                                                          .withValues(
                                                              alpha: 0.08),
                                                      blurRadius: 6,
                                                      offset: Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.smartphone,
                                                        color: Colors.white,
                                                        size: 18),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      '모바일로 내보내기',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),

                                    // 시간 정보
                                    Padding(
                                      padding:
                                          EdgeInsets.fromLTRB(16, 0, 16, 16),
                                      child: Row(
                                        children: [
                                          Icon(Icons.access_time,
                                              size: 12,
                                              color: Colors.grey.shade500),
                                          SizedBox(width: 4),
                                          Text(
                                            gift['received_at'] ?? '',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // NEW 라벨 (좌측 상단)
                                if (gift['is_new'] == true)
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'NEW',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 알림 아이콘 탭 처리
  void _handleNotificationTap(BuildContext context, WidgetRef ref) {
    // 알림이 없어도 모달 표시 (스낵바 제거)
    // 간단한 알림 목록 다이얼로그 표시
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDarkTheme = ref.read(themeProvider).colorScheme.name == 'Dark';
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.notifications,
                  color: isDarkTheme ? Colors.blue[300] : Colors.blue),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                '알림 목록',
                style: TextStyle(
                  color: isDarkTheme ? Colors.white : null,
                ),
              )),
              IconButton(
                icon: Icon(Icons.refresh,
                    color: isDarkTheme ? Colors.blue[300] : Colors.blue),
                onPressed: () {
                  Navigator.of(context).pop();
                  _handleNotificationTap(context, ref);
                },
                tooltip: '새로고침',
              ),
            ],
          ),
          content: Container(
            width: 400,
            height: 300,
            child: FutureBuilder<Map<String, dynamic>>(
              future: _loadAlertsFromAPI(ref),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          '알림을 불러오는 중...',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDarkTheme
                                ? Colors.grey[300]
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red.shade400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '알림을 불러오는 중 오류가 발생했습니다',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDarkTheme
                                ? Colors.grey[300]
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkTheme
                                ? Colors.grey[400]
                                : Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final data = snapshot.data!;
                final alerts = data['alerts'] as List<dynamic>? ?? [];

                if (alerts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off,
                          size: 48,
                          color: isDarkTheme ? Colors.grey[500] : Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '새로운 알림이 없습니다.',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDarkTheme ? Colors.grey[400] : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    final queueName = alert['queue_name'] as String? ?? '';
                    final message = alert['message'] as String? ?? '';
                    final sendTime = alert['send_time'] as String? ?? '';
                    final isRead = alert['is_read'] == true;
                    final isDeleted = alert['is_deleted'] == true;

                    // 삭제된 알림은 표시하지 않음
                    if (isDeleted) return Container();

                    // 번호 계산 (맨 아래를 1로 하여 역순)
                    final displayNumber = alerts.length - index;

                    // queue_name에 따라 아이콘과 색상 결정
                    IconData icon;
                    Color iconColor;
                    String title;
                    switch (queueName.toLowerCase()) {
                      case 'birthday':
                        icon = Icons.cake;
                        iconColor = Colors.pink;
                        title = '생일';
                        break;
                      case 'gift':
                        icon = Icons.card_giftcard;
                        iconColor = Colors.purple;
                        title = '선물이 도착했습니다';
                        break;
                      case 'alert':
                        icon = Icons.notifications_active;
                        iconColor = Colors.orange;
                        title = message; // 서버 메시지를 제목으로 사용
                        break;
                      case 'leave.analyze':
                        icon = Icons.analytics;
                        iconColor = Colors.teal;
                        title = '휴가 AI 추천 분석';
                        break;
                      case 'leave':
                        icon = Icons.auto_awesome;
                        iconColor = Colors.blue;
                        title = '휴가 알림';
                        break;
                      default:
                        if (queueName == 'event') {
                          title = '이벤트 알림';
                          icon = Icons.celebration;
                          iconColor = Colors.purple;
                        } else {
                          title = '알림';
                          icon = Icons.info;
                          iconColor = Colors.blue;
                        }
                    }

                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isRead
                            ? (isDarkTheme
                                ? Colors.grey[800]
                                : Colors.grey.shade100) // 읽은 메시지는 회색 배경
                            : (isDarkTheme
                                ? Colors.grey[850]
                                : Colors.white), // 읽지 않은 메시지는 흰색 배경
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isRead
                              ? (isDarkTheme
                                  ? Colors.grey[600]!
                                  : Colors.grey.shade300)
                              : (isDarkTheme
                                  ? Colors.blue[700]!
                                  : Colors.blue.shade100),
                          width: isRead ? 1 : 2,
                        ),
                      ),
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 번호 표시
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isRead
                                    ? (isDarkTheme
                                        ? Colors.grey[600]
                                        : Colors.grey.shade300)
                                    : (isDarkTheme
                                        ? Colors.blue[700]
                                        : Colors.blue.shade100),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isRead
                                      ? (isDarkTheme
                                          ? Colors.grey[500]!
                                          : Colors.grey.shade400)
                                      : (isDarkTheme
                                          ? Colors.blue[600]!
                                          : Colors.blue.shade300),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  displayNumber.toString(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isRead
                                        ? (isDarkTheme
                                            ? Colors.grey[300]
                                            : Colors.grey.shade600)
                                        : (isDarkTheme
                                            ? Colors.white
                                            : Colors.blue.shade700),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            // 아이콘
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: (isRead ? Colors.grey : iconColor)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                icon,
                                color: isRead ? Colors.grey : iconColor,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                queueName.toLowerCase() == 'alert'
                                    ? title // alert 큐는 서버 메시지 그대로
                                    : _sanitizeText(title), // 다른 큐는 sanitize
                                style: TextStyle(
                                  fontWeight: isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  color: isRead
                                      ? (isDarkTheme
                                          ? Colors.grey[400]
                                          : Colors.grey.shade600)
                                      : (isDarkTheme
                                          ? Colors.white
                                          : Colors.black87),
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!isRead) // 읽지 않은 메시지에만 NEW 표시
                              Container(
                                margin: EdgeInsets.only(left: 8),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'NEW',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // alert 큐가 아닐 때만 메시지 미리보기 표시
                            if (queueName.toLowerCase() != 'alert')
                              Text(
                                _sanitizePreviewText(message.length > 50
                                    ? message.substring(0, 50) + '...'
                                    : message),
                                style: TextStyle(
                                  color: isRead
                                      ? (isDarkTheme
                                          ? Colors.grey[500]
                                          : Colors.grey.shade500)
                                      : (isDarkTheme
                                          ? Colors.grey[300]
                                          : Colors.grey.shade700),
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (queueName.toLowerCase() != 'alert')
                              SizedBox(height: 4),
                            Text(
                              _sanitizeText(_formatDateTime(sendTime)),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkTheme
                                    ? Colors.grey[400]
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        onTap: () async {
                          // 현재 context 저장 (다이얼로그가 닫힌 후 사용할 수 없으므로)
                          final savedAlert = alert;
                          final savedRef = ref;

                          Navigator.of(context).pop();

                          // 읽음 처리는 이미 알림 클릭 시 완료됨 (중복 호출 제거)
                          // 하지만 혹시 모르니 다시 한번 확인
                          final isAlreadyRead = alert['is_read'] == true;
                          if (!isAlreadyRead) {
                            try {
                              final userId = ref.read(userIdProvider);
                              final alertId = alert['id'] as int;
                              await ref
                                  .read(notificationProvider.notifier)
                                  .markAsReadWithAPI(userId!, alertId);
                            } catch (e) {
                              print('❌ 알림 읽음 처리 재시도 실패: $e');
                            }
                          }

                          // 다음 프레임에서 다이얼로그 표시 (navigatorKey를 통한 안전한 context 사용)
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            final safeContext = navigatorKey.currentContext;
                            if (safeContext != null && safeContext.mounted) {
                              _showAlertDetail(safeContext, savedAlert, savedRef);
                            } else {
                              print('⚠️ 알림 상세보기: 유효한 context를 찾을 수 없습니다.');
                            }
                          });
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  // 알림 상세보기 창
  void _showAlertDetail(
      BuildContext context, Map<String, dynamic> alert, WidgetRef ref) {
    final queueName = alert['queue_name'] as String? ?? '';
    final message = alert['message'] as String? ?? '';
    final sendTime = alert['send_time'] as String? ?? '';
    final id = alert['id']?.toString() ?? ''; // int를 String으로 변환

    // queue_name에 따라 제목 결정
    String title;
    IconData icon;
    Color iconColor;
    switch (queueName.toLowerCase()) {
      case 'birthday':
        title = '생일';
        icon = Icons.cake;
        iconColor = Colors.pink;
        break;
      case 'gift':
        title = '선물이 도착했습니다';
        icon = Icons.card_giftcard;
        iconColor = Colors.purple;
        break;
      case 'alert':
        title = 'Alert 알림';
        icon = Icons.notifications_active;
        iconColor = Colors.orange;
        break;
      case 'leave.analyze':
        title = '휴가 AI 추천 분석';
        icon = Icons.analytics;
        iconColor = Colors.teal;
        break;
      case 'leave':
        title = '휴가 알림';
        icon = Icons.auto_awesome;
        iconColor = Colors.blue;
        break;
      default:
        if (queueName == 'event') {
          title = '이벤트 알림';
          icon = Icons.celebration;
          iconColor = Colors.purple;
        } else {
          title = '알림';
          icon = Icons.info;
          iconColor = Colors.blue;
        }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 520,
            height: 680,
            decoration: BoxDecoration(
              color: isDarkTheme ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDarkTheme ? Colors.grey[800]! : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDarkTheme
                              ? Colors.grey[700]
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon, // 기본 아이콘
                          color: iconColor,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: isDarkTheme
                                    ? Colors.white
                                    : Colors.grey.shade800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _sanitizeText(_formatDateTime(sendTime)),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkTheme
                                    ? Colors.grey[400]
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close,
                            color: isDarkTheme
                                ? Colors.white
                                : Colors.grey.shade600),
                        onPressed: () {
                          // 상세보기 모달에서 알림함으로 돌아올 때는 다이얼로그를 다시 열지 않고 그냥 닫기만 함
                          // 이미 알림함이 열려있으므로 다시 열 필요 없음
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),

                // 메시지 내용
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 메시지 텍스트
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                              vertical: 28, horizontal: 22),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDarkTheme
                                  ? [
                                      Color(0xFF374151), // 다크 그레이
                                      Color(0xFF1F2937), // 더 어두운 그레이
                                    ]
                                  : [
                                      Color(0xFFF8F7FF), // Toss 연보라
                                      Colors.white,
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: isDarkTheme
                                    ? Colors.black.withValues(alpha: 0.3)
                                    : Colors.black.withValues(alpha: 0.06),
                                blurRadius: 14,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: queueName == 'alert'
                              ? SelectableText(
                                  message, // 서버에서 보내는 값 그대로 렌더링
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isDarkTheme
                                        ? Colors.grey[300]
                                        : Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.left, // 왼쪽 정렬로 변경
                                )
                              : queueName == 'leave.analyze'
                                  ? _buildLeaveRecommendationContent(message, isDarkTheme)
                              : queueName == 'leave'
                                  ? SelectableText(
                                      _sanitizeText(message),
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: isDarkTheme
                                            ? Colors.grey[300]
                                            : Color(0xFF6B7280),
                                        fontWeight: FontWeight.w500,
                                        height: 1.5,
                                      ),
                                      textAlign: TextAlign.left,
                                    )
                                  : queueName == 'birthday' || queueName == 'gift'
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Icon(Icons.cake,
                                                color: Color(0xFF6C5CE7), size: 32),
                                            SizedBox(height: 14),
                                            Text(
                                              '🎉 알림 메시지',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isDarkTheme
                                                    ? Colors.white
                                                    : Color(0xFF191F28),
                                                letterSpacing: -0.5,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            SizedBox(height: 10),
                                            SelectableText(
                                              _sanitizeText(message),
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: isDarkTheme
                                                    ? Colors.grey[300]
                                                    : Color(0xFF6B7280),
                                                fontWeight: FontWeight.w500,
                                                height: 1.5,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        )
                                      : SelectableText(
                                          _sanitizeText(message),
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: isDarkTheme
                                                ? Colors.grey[300]
                                                : Color(0xFF6B7280),
                                            fontWeight: FontWeight.w500,
                                            height: 1.5,
                                          ),
                                          textAlign: TextAlign.left,
                                        ),
                        ),

                        SizedBox(height: 24),

                        // 선물 메시지인 경우 쿠폰 이미지 영역
                        if (queueName == 'gift') ...[
                          if (message.contains('coupon_img_url')) ...[
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDarkTheme
                                    ? Colors.grey[800]
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: isDarkTheme
                                        ? Colors.grey[600]!
                                        : Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDarkTheme
                                        ? Colors.black.withValues(alpha: 0.3)
                                        : Colors.grey.shade100,
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 쿠폰 이미지
                                  Container(
                                    width: double.infinity,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(12),
                                      ),
                                      child: Image.network(
                                        message
                                            .split('coupon_img_url:')
                                            .last
                                            .split(',')
                                            .first,
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Container(
                                            color: Colors.grey.shade100,
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  CircularProgressIndicator(
                                                    value: loadingProgress
                                                                .expectedTotalBytes !=
                                                            null
                                                        ? loadingProgress
                                                                .cumulativeBytesLoaded /
                                                            loadingProgress
                                                                .expectedTotalBytes!
                                                        : null,
                                                    color: Colors.grey.shade400,
                                                  ),
                                                  SizedBox(height: 8),
                                                  Text('이미지 로딩 중...',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors
                                                            .grey.shade600,
                                                      )),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey.shade100,
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.error_outline,
                                                      size: 32,
                                                      color:
                                                          Colors.grey.shade400),
                                                  SizedBox(height: 8),
                                                  Text('이미지를 불러올 수 없습니다',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors
                                                            .grey.shade600,
                                                      )),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),

                                  // 쿠폰 정보
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.card_giftcard,
                                                color: Colors.grey.shade600,
                                                size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              '쿠폰',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (message
                                            .contains('coupon_end_date')) ...[
                                          SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(Icons.schedule,
                                                  size: 14,
                                                  color: Colors.red.shade600),
                                              SizedBox(width: 4),
                                              Text(
                                                '만료: ${message.split('coupon_end_date:').last.split(',').first}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.red.shade700,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        SizedBox(height: 12),
                                        Column(
                                          children: [
                                            // 첫 번째 줄: 브라우저에서 열기
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () => _launchURL(
                                                        message
                                                            .split(
                                                                'coupon_img_url:')
                                                            .last
                                                            .split(',')
                                                            .first),
                                                    icon: Icon(
                                                        Icons.open_in_new,
                                                        size: 16),
                                                    label: Text('브라우저에서 열기'),
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          Colors.grey.shade600,
                                                      foregroundColor:
                                                          Colors.white,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 8),
                                            // 두 번째 줄: 모바일로 내보내기 버튼
                                            GestureDetector(
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder:
                                                      (BuildContext context) {
                                                    final isDarkTheme =
                                                        Theme.of(context)
                                                                .brightness ==
                                                            Brightness.dark;
                                                    return AlertDialog(
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16),
                                                      ),
                                                      content: Text(
                                                        '모바일로 내보내기는 3분~ 5분정도 시간이 소요 됩니다. 감사합니다.',
                                                        style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: isDarkTheme
                                                              ? Colors.white
                                                              : null,
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.of(
                                                                    context)
                                                                .pop(); // 다이얼로그 닫기
                                                          },
                                                          child: Text(
                                                            '취소',
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                          ),
                                                        ),
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.of(
                                                                    context)
                                                                .pop(); // 다이얼로그 닫기
                                                            _sendToMobile(
                                                              context,
                                                              message
                                                                  .split(
                                                                      'coupon_img_url:')
                                                                  .last
                                                                  .split(',')
                                                                  .first,
                                                            );
                                                          },
                                                          child: Text(
                                                            '확인',
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Colors
                                                                  .blue[600],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              },
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 18,
                                                    vertical: 10),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Color(
                                                          0xFF7b8fd1), // 더 어두운 파스텔 블루
                                                      Color(
                                                          0xFFb39ddb), // 더 어두운 파스텔 보라
                                                    ],
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.centerRight,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Color(0xFFb7caff)
                                                          .withValues(
                                                              alpha: 0.08),
                                                      blurRadius: 6,
                                                      offset: Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.smartphone,
                                                        color: Colors.white,
                                                        size: 18),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      '모바일로 내보내기',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 15,
                                                      ),
                                                    ),
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
                            ),
                          ],
                        ],

                        SizedBox(height: 24),

                        // 메타 정보
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDarkTheme
                                ? Colors.grey[800]
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isDarkTheme
                                    ? Colors.grey[600]!
                                    : Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 18,
                                      color: isDarkTheme
                                          ? Colors.grey[400]
                                          : Colors.grey.shade600),
                                  SizedBox(width: 8),
                                  Text(
                                    '상세 정보',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkTheme
                                          ? Colors.grey[300]
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              _buildInfoRow('메시지 ID', id),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 하단 버튼들
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDarkTheme ? Colors.grey[800] : Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 생일/이벤트 메시지인 경우 선물 고르러 가기 버튼
                      if (queueName == 'birthday' || queueName == 'event')
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _handleNotificationTap(context, ref);
                            final currentUserId = ref.read(userIdProvider);
                            final alertId = alert['id'] as int;
                            print(
                                '🔍 DEBUG: 선물고르기 버튼 클릭 - 현재 userIdProvider 값: $currentUserId');
                            print(
                                '🔍 DEBUG: 선물고르기 버튼 클릭 - alertId 값: $alertId');
                            if (currentUserId != null) {
                              // alertId를 전달하여 선물 고르기 모달 호출
                              ref
                                  .read(notificationProvider.notifier)
                                  .showGiftSelectionFromAlert(context,
                                      currentUserId, alertId, queueName);
                            } else {
                              print('❌ ERROR: userIdProvider가 null입니다');
                            }
                          },
                          icon: Icon(
                            Icons.card_giftcard,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: Text(
                            '선물 고르러 가기',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple[200]
                                ?.withValues(alpha: 0.8), // 반투명한 연보라색
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                        )
                      else
                        SizedBox.shrink(),

                      Row(
                        children: [
                          TextButton(
                            onPressed: () async {
                              try {
                                final userId = ref.read(userIdProvider);
                                final alertId = alert['id'] as int;

                                // 서버 API를 통해 삭제 처리
                                await ref
                                    .read(notificationProvider.notifier)
                                    .deleteAlertWithAPI(userId!, alertId);

                                Navigator.of(context).pop();
                                _handleNotificationTap(context, ref);

                                if (mounted) {
                                  CommonUIUtils.showSuccessSnackBar(
                                      context, '알림이 삭제되었습니다.');
                                }
                              } catch (e) {
                                print('❌ 알림 삭제 실패: $e');
                                if (mounted) {
                                  CommonUIUtils.showErrorSnackBar(
                                      context, '알림 삭제에 실패했습니다.');
                                }
                              }
                            },
                            child: Text('삭제',
                                style: TextStyle(
                                    color: isDarkTheme
                                        ? Colors.grey[400]
                                        : Colors.grey.shade600)),
                          ),
                          SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              _handleNotificationTap(context, ref);
                              if (queueName == 'gift') {
                                _showGiftBox(context, ref);
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF7b8fd1), // 더 어두운 파스텔 블루
                                    Color(0xFFb39ddb), // 더 어두운 파스텔 보라
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF7b8fd1)
                                        .withValues(alpha: 0.08),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // birthday나 gift에서만 아이콘 표시
                                  if (queueName == 'birthday' ||
                                      queueName == 'gift') ...[
                                    Icon(Icons.card_giftcard,
                                        color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                  ],
                                  Text(
                                    queueName == 'gift' ? '선물함으로 이동' : '확인',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
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
          ),
        );
      },
    );
  }

  // 정보 행 위젯
  Widget _buildInfoRow(String label, String value) {
    return Builder(
      builder: (context) {
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDarkTheme ? Colors.grey[400] : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDarkTheme ? Colors.grey[300] : Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // URL 실행 함수
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  // 별 모양 색종이 경로 생성 함수
  Path drawStar(Size size) {
    // Method to convert degree to radians

    final path = Path();
    path.addPolygon([
      Offset(size.width * 0.5, 0),
      Offset(size.width * 0.618, size.height * 0.382),
      Offset(size.width, size.height * 0.382),
      Offset(size.width * 0.691, size.height * 0.618),
      Offset(size.width * 0.809, size.height),
      Offset(size.width * 0.5, size.height * 0.763),
      Offset(size.width * 0.191, size.height),
      Offset(size.width * 0.309, size.height * 0.618),
      Offset(0, size.height * 0.382),
      Offset(size.width * 0.382, size.height * 0.382),
    ], true);
    return path;
  }

  // API에서 선물 데이터 로드
  Future<Map<String, dynamic>> _loadGiftsFromAPI(WidgetRef ref) async {
    try {
      final userId = ref.read(userIdProvider);
      if (userId == null || userId.isEmpty) {
        throw Exception('사용자 ID를 찾을 수 없습니다');
      }

      final response = await ApiService.checkGifts(userId);
      return response;
    } catch (e) {
      print('선물함 로드 실패: $e');
      throw e;
    }
  }

  // API에서 알림 데이터 로드 및 새로고침
  Future<Map<String, dynamic>> _loadAlertsFromAPI(WidgetRef ref) async {
    try {
      final userId = ref.read(userIdProvider);
      if (userId == null || userId.isEmpty) {
        throw Exception('사용자 ID를 찾을 수 없습니다');
      }

      // 서버에서 최신 알림 데이터 조회
      final response = await ApiService.checkAlerts(userId);

      // 서버에서 받아온 알림 데이터를 NotificationNotifier에 업데이트
      final alerts = response['alerts'] as List<dynamic>? ?? [];
      final alertsList = alerts.cast<Map<String, dynamic>>();

      // is_deleted가 false인 알림만 필터링
      final filteredAlerts =
          alertsList.where((alert) => alert['is_deleted'] != true).toList();

      ref
          .read(notificationProvider.notifier)
          .updateServerAlerts(filteredAlerts);

      // 필터링된 데이터로 응답 업데이트
      return {
        ...response,
        'alerts': filteredAlerts,
      };
    } catch (e) {
      print('알림 로드 실패: $e');
      throw e;
    }
  }

  // UTF-16 인코딩 오류 방지를 위한 텍스트 정리 함수
  String _sanitizeText(String text) {
    if (text.isEmpty) return text;

    try {
      // UTF-16 유효성 검사 및 정리
      String sanitized = text;

      // 1. 잘못된 UTF-16 서로게이트 쌍 제거 제거됨 - 이모지 유지

      // 2. 대체 문자 제거
      sanitized = sanitized.replaceAll(RegExp(r'[\uFFFD]'), '?');

      // 3. 제어 문자 제거 (탭, 개행, 캐리지 리턴 제외)
      sanitized = sanitized.replaceAll(
          RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]'), '');

      // 4. 잘못된 유니코드 문자 제거
      sanitized =
          sanitized.replaceAll(RegExp(r'[\uFEFF\u200B-\u200D\u2060]'), '');

      // 5. 연속된 공백 정리 제거됨 - 원본 공백 유지

      // 6. 최종 UTF-16 유효성 검사
      if (sanitized.isEmpty) return '텍스트를 표시할 수 없습니다';

      return sanitized;
    } catch (e) {
      print('텍스트 정리 중 오류: $e, 원본: $text');
      return '텍스트를 표시할 수 없습니다';
    }
  }

  /// 알림 미리보기용 텍스트 정리 (마크다운 문법 제거)
  String _sanitizePreviewText(String text) {
    if (text.isEmpty) return text;

    try {
      String sanitized = text;

      // 1. 기본 텍스트 정리
      sanitized = _sanitizeText(sanitized);

      // 2. 마크다운 문법 제거
      // 헤더 (#, ##, ### 등)
      sanitized = sanitized.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
      
      // 볼드 (**text**, __text__)
      sanitized = sanitized.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
      sanitized = sanitized.replaceAll(RegExp(r'__([^_]+)__'), r'$1');
      
      // 이탤릭 (*text*, _text_)
      sanitized = sanitized.replaceAll(RegExp(r'(?<!\*)\*([^*]+)\*(?!\*)'), r'$1');
      sanitized = sanitized.replaceAll(RegExp(r'(?<!_)_([^_]+)_(?!_)'), r'$1');
      
      // 코드 블록 (```...```)
      sanitized = sanitized.replaceAll(RegExp(r'```[\s\S]*?```', multiLine: true), '');
      sanitized = sanitized.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
      
      // 링크 [text](url)
      sanitized = sanitized.replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1');
      
      // 이미지 ![alt](url)
      sanitized = sanitized.replaceAll(RegExp(r'!\[([^\]]*)\]\([^\)]+\)'), r'$1');
      
      // 리스트 (-, *, +)
      sanitized = sanitized.replaceAll(RegExp(r'^[\s]*[-*+]\s+', multiLine: true), '');
      sanitized = sanitized.replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '');
      
      // 표 (|)
      sanitized = sanitized.replaceAll(RegExp(r'\|'), ' ');
      
      // 수평선 (---, ***)
      sanitized = sanitized.replaceAll(RegExp(r'^[-*]{3,}$', multiLine: true), '');
      
      // 인용 (>)
      sanitized = sanitized.replaceAll(RegExp(r'^>\s+', multiLine: true), '');
      
      // 줄바꿈 정리 (연속된 줄바꿈을 하나로)
      sanitized = sanitized.replaceAll(RegExp(r'\n{3,}'), '\n\n');
      
      // 앞뒤 공백 제거
      sanitized = sanitized.trim();
      
      // 연속된 공백을 하나로
      sanitized = sanitized.replaceAll(RegExp(r' {2,}'), ' ');
      
      // JSON 데이터 제거 (leave 큐의 경우)
      sanitized = sanitized.replaceAll(RegExp(r'\{[^{}]*"leaves"[^{}]*\}', dotAll: true), '');
      sanitized = sanitized.replaceAll(RegExp(r'\{[^{}]*"weekday_counts"[^{}]*\}', dotAll: true), '');
      sanitized = sanitized.replaceAll(RegExp(r'"weekday_counts"[^}]*', dotAll: true), '');
      sanitized = sanitized.replaceAll(RegExp(r'"holiday_adjacent[^}]*', dotAll: true), '');
      sanitized = sanitized.replaceAll(RegExp(r'"total_leave_days"[^}]*', dotAll: true), '');
      
      if (sanitized.isEmpty) return '알림 내용';

      return sanitized;
    } catch (e) {
      print('미리보기 텍스트 정리 중 오류: $e, 원본: $text');
      return text.length > 50 ? text.substring(0, 50) + '...' : text;
    }
  }

  // 시간 포맷팅 함수
  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      // 오늘인 경우
      if (dateTime.year == now.year &&
          dateTime.month == now.month &&
          dateTime.day == now.day) {
        return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      }

      // 어제인 경우
      final yesterday = now.subtract(Duration(days: 1));
      if (dateTime.year == yesterday.year &&
          dateTime.month == yesterday.month &&
          dateTime.day == yesterday.day) {
        return '${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} 어제 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      }

      // 이번 주인 경우
      if (difference.inDays < 7) {
        final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
        final weekday = weekdays[dateTime.weekday - 1];
        return '${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} $weekday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      }

      // 그 외의 경우
      return '${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      // 파싱 실패 시 원본 반환
      return dateTimeString;
    }
  }

  // 결재 슬라이드 패널 위젯
  Widget _buildApprovalSlidePanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
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
          // 헤더
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100.withValues(alpha: 0.8),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.assignment_ind,
                    color: Colors.grey.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '휴가 결재 요청',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_approvalRequests.length}건의 대기 중인 요청',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // 핀 버튼 추가
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isApprovalPanelPinned = !_isApprovalPanelPinned;
                    });
                  },
                  icon: Icon(
                    _isApprovalPanelPinned
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                    color: _isApprovalPanelPinned
                        ? Colors.orange.shade600
                        : Colors.grey.shade600,
                    size: 22,
                  ),
                  tooltip: _isApprovalPanelPinned ? '고정 해제' : '고정하기',
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isApprovalPanelVisible = false;
                      _isApprovalPanelExpanded = false;
                      _isApprovalPanelPinned = false;
                    });
                  },
                  icon: Icon(
                    Icons.close,
                    color: Colors.grey.shade700,
                    size: 24,
                  ),
                  tooltip: '닫기',
                ),
              ],
            ),
          ),
          // 내용
          Expanded(
            child: _approvalRequests.isEmpty
                ? _buildEmptyApprovalState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _approvalRequests.length,
                    itemBuilder: (context, index) {
                      return _buildApprovalRequestCard(
                          _approvalRequests[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // 결재요청도착 아이콘 위젯
  Widget _buildApprovalNotificationIcon() {
    return GestureDetector(
      onTap: () async {
        // 최신 결재 대기 목록 조회
        await _fetchApprovalRequests();

        setState(() {
          _isApprovalPanelVisible = true;
          _isApprovalPanelExpanded = true;
          _isApprovalPanelPinned = false;
          _showApprovalNotificationIcon = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
              Colors.grey.shade100,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_turned_in,
              color: Colors.grey.shade700,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              '결재요청도착',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            if (_approvalRequests.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.shade400,
                      Colors.orange.shade500,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _approvalRequests.length > 99
                      ? '99+'
                      : _approvalRequests.length.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 전자결재 알림 아이콘 위젯
  Widget _buildEapprovalNotificationIcon() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showEapprovalNotificationIcon = false;
        });
        // 대기중인 전자결재 목록 모달 표시
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '전자 결재가 도착했어요',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_eapprovalMessages
                      .any((m) => m.approvalType == 'hr_leave_grant'))
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const VacationManagementWebViewScreen(
                                    webUrl:
                                        'http://210.107.96.193:9999/pages/vacation-admin.html',
                                  )),
                        );
                      },
                      icon: const Icon(Icons.open_in_new,
                          size: 16, color: Colors.blue),
                      label: const Text('휴가총괄관리(웹)로 이동',
                          style: TextStyle(color: Colors.blue, fontSize: 12)),
                    ),
                  if (_eapprovalMessages
                      .any((m) => m.approvalType == 'eapproval'))
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const ElectronicApprovalManagementScreen()),
                        );
                      },
                      icon: const Icon(Icons.open_in_new,
                          size: 16, color: Colors.blue),
                      label: const Text('전자결재관리로 이동',
                          style: TextStyle(color: Colors.blue, fontSize: 12)),
                    ),
                ],
              ),
              content: SizedBox(
                width: 420,
                height: 320,
                child: _eapprovalMessages.isEmpty
                    ? const Center(child: Text('대기중인 전자결재가 없습니다.'))
                    : ListView.builder(
                        itemCount: _eapprovalMessages.length,
                        itemBuilder: (context, index) {
                          final m = _eapprovalMessages[index];
                          final bool isCc = m.approvalType == 'eapproval_cc';
                          final Color accentColor = isCc
                              ? const Color(0xFF0EA5E9)
                              : const Color(0xFF4A6CF7);
                          final subtitleParts = [
                            if (m.name.isNotEmpty) m.name,
                            if (m.department.isNotEmpty) m.department,
                            if (m.status != null && m.status!.isNotEmpty)
                              m.status!,
                            if (isCc) '참조자용',
                          ];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isCc
                                  ? const Color(0xFFE0F2FE)
                                  : const Color(0xFFEFF4FF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.2),
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor:
                                    accentColor.withValues(alpha: 0.15),
                                child: Icon(
                                  isCc
                                      ? Icons.groups_rounded
                                      : Icons.description_rounded,
                                  color: accentColor,
                                ),
                              ),
                              title: Row(
                                children: [
                                  if (isCc)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: _buildApprovalBadge(
                                        label: '참조',
                                        color: accentColor,
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      m.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                subtitleParts.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기'),
                ),
              ],
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEEF2FF), // 연한 인디고
              Color(0xFFEDE9FE), // 연한 보라
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mark_email_unread_rounded,
              color: Color(0xFF4A6CF7),
              size: 28,
            ),
            const SizedBox(height: 6),
            const Text(
              '전자 결재가 도착했어요',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _eapprovalMessages.length > 99
                    ? '99+'
                    : _eapprovalMessages.length.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withValues(alpha: 0.9),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 날짜 범위를 요일과 함께 포맷팅
  String _formatDateRangeWithWeekday(String? startDate, String? endDate) {
    if (startDate == null || endDate == null) return '날짜 정보 없음';

    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);

      final startWeekday = _getKoreanWeekday(start.weekday);
      final endWeekday = _getKoreanWeekday(end.weekday);

      if (start.isAtSameMomentAs(end)) {
        // 같은 날짜인 경우
        return '${start.year}.${start.month.toString().padLeft(2, '0')}.${start.day.toString().padLeft(2, '0')} ($startWeekday)';
      } else {
        // 다른 날짜인 경우
        return '${start.year}.${start.month.toString().padLeft(2, '0')}.${start.day.toString().padLeft(2, '0')} ($startWeekday) ~ ${end.year}.${end.month.toString().padLeft(2, '0')}.${end.day.toString().padLeft(2, '0')} ($endWeekday)';
      }
    } catch (e) {
      return '$startDate ~ $endDate';
    }
  }

  /// 요일을 한국어로 변환
  String _getKoreanWeekday(int weekday) {
    switch (weekday) {
      case 1:
        return '월';
      case 2:
        return '화';
      case 3:
        return '수';
      case 4:
        return '목';
      case 5:
        return '금';
      case 6:
        return '토';
      case 7:
        return '일';
      default:
        return '';
    }
  }

  Widget _buildEmptyApprovalState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '대기 중인 결재 요청이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '새로운 휴가 신청이 있으면 여기에 표시됩니다',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalRequestCard(Map<String, dynamic> request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 신청자 헤더
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      const Color(0xFF1E88E5).withValues(alpha: 0.1),
                  child: Text(
                    request['name']?.isNotEmpty == true
                        ? request['name'].substring(0, 1)
                        : '?',
                    style: const TextStyle(
                      color: Color(0xFF1E88E5),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        request['department'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 취소 상신 여부 표시
                    if ((request['is_cancel'] == 1) ||
                        (request['is_canceled'] == 1))
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53E3E).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '취소 상신',
                          style: TextStyle(
                            color: Color(0xFFE53E3E),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    // 상태 표시
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '대기중',
                        style: TextStyle(
                          color: Color(0xFFFF9800),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 휴가 정보
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildApprovalInfoRow(
                  icon: Icons.event_note,
                  label: '휴가 종류',
                  value: request['leave_type'] ?? '',
                ),
                const SizedBox(height: 12),
                _buildApprovalInfoRow(
                  icon: Icons.calendar_today,
                  label: '기간',
                  value: _formatDateRangeWithWeekday(
                          request['start_date'], request['end_date']) +
                      _getHalfDaySlotLabel(request['half_day_slot']),
                ),
                const SizedBox(height: 12),
                _buildApprovalInfoRow(
                  icon: Icons.schedule,
                  label: '일수',
                  value: '${request['workdays_count']}일',
                ),
                if (request['reason']?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  _buildApprovalInfoRow(
                    icon: Icons.comment,
                    label: '사유',
                    value: request['reason'],
                  ),
                ],
              ],
            ),
          ),
          // 액션 버튼들
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: ((request['is_cancel'] == 1) ||
                    (request['is_canceled'] == 1))
                ? // 취소상신: 취소승인 버튼 1개만
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleApprove(request),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text(
                        '취소승인',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF20C997),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  )
                : // 일반 상신: 반려/승인 버튼 2개
                Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _handleReject(request),
                          icon: const Icon(Icons.cancel, size: 18),
                          label: const Text(
                            '반려',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC3545),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _handleApprove(request),
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text(
                            '승인',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF20C997),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// half_day_slot 값을 사용자 친화적인 라벨로 변환
  String _getHalfDaySlotLabel(String? halfDaySlot) {
    if (halfDaySlot == null || halfDaySlot.isEmpty) return '';
    switch (halfDaySlot.toUpperCase()) {
      case 'AM':
        return ' (오전반차)';
      case 'PM':
        return ' (오후반차)';
      case 'ALL':
        return ' (종일)';
      default:
        return '';
    }
  }

  Widget _buildApprovalInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2C3E50),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _handleApprove(Map<String, dynamic> request) {
    // 서버 API에 따라 is_cancel 또는 is_canceled 필드를 사용
    final isCancelRequest =
        (request['is_cancel'] == 1) || (request['is_canceled'] == 1);
    final title = isCancelRequest ? '휴가 취소 승인' : '휴가 승인';
    final message = isCancelRequest
        ? '${request['name']}님의 휴가 취소 상신을 승인하시겠습니까?'
        : '${request['name']}님의 휴가 신청을 승인하시겠습니까?';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);

              // API 호출
              try {
                final isCancelRequest = (request['is_cancel'] == 1) ||
                    (request['is_canceled'] == 1);
                print('🟢 휴가 승인 API 호출 시작 (취소 상신: $isCancelRequest)');
                print('🟢 Request 데이터:');
                print('  - request[\"id\"]: ${request['id']}');
                print('  - request[\"requestId\"]: ${request['requestId']}');
                print('  - request[\"leave_id\"]: ${request['leave_id']}');
                print('  - request[\"request_id\"]: ${request['request_id']}');
                print('  - request[\"is_cancel\"]: ${request['is_cancel']}');
                print(
                    '  - request[\"is_canceled\"]: ${request['is_canceled']}');
                print(
                    '  - 사용할 requestId: ${request['id']?.toString() ?? request['requestId']?.toString() ?? request['leave_id']?.toString() ?? request['request_id']?.toString() ?? ''}');
                print('  - isApproved: true');
                print('  - request 전체 객체: $request');
                print('  - request.keys: ${request.keys}');

                // requestId 찾기 - 여러 가능한 키를 확인
                final requestId = request['id']?.toString() ??
                    request['requestId']?.toString() ??
                    request['leave_id']?.toString() ??
                    request['request_id']?.toString() ??
                    '';

                print('🟢 최종 사용할 requestId: $requestId');

                if (requestId.isEmpty) {
                  print('🔴 requestId가 비어있음! API 호출 불가능');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('휴가 신청 ID를 찾을 수 없습니다. 서버에 문의하세요.'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                  return;
                }

                // 현재 로그인한 사용자 ID 가져오기
                final currentUserId = ref.read(userIdProvider) ?? '';
                print('🟢 현재 로그인한 사용자 ID (approverId): $currentUserId');

                final adminRequest = AdminApprovalRequest(
                  id: int.parse(requestId),
                  approverId: currentUserId,
                  isApproved: isCancelRequest ? 'CANCEL_APPROVED' : 'APPROVED',
                  rejectMessage: null,
                );

                // is_canceled 값에 따라 다른 API 호출
                print(
                    '🟢 API 선택: ${isCancelRequest ? "/leave/admin/approval/cancel" : "/leave/admin/approval"}');
                final result = isCancelRequest
                    ? await LeaveApiService.processCancelApproval(
                        request: adminRequest,
                      )
                    : await LeaveApiService.processAdminApproval(
                        request: adminRequest,
                      );

                print('🟢 휴가 승인 API Response:');
                print('  - result: $result');
                print('  - result type: ${result.runtimeType}');
                print('  - result.error: ${result.error}');

                if (!mounted) return; // 위젯이 dispose된 경우 종료

                if (result.error == null) {
                  print('🟢 승인 처리 성공 - UI에서 요청 제거');
                  if (mounted) {
                    setState(() {
                      _approvalRequests.remove(request);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('휴가를 승인했습니다.'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                } else {
                  print('🔴 승인 처리 실패 - error: ${result.error}');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('승인 처리 실패: ${result.error}'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                }
              } catch (e) {
                print('🔴 휴가 승인 API 호출 중 Exception 발생: $e');
                print('🔴 Exception Stack Trace: ${StackTrace.current}');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('승인 처리 중 오류가 발생했습니다: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA5D6A7), // 연한 초록
              foregroundColor: const Color(0xFF2E7D32), // 진한 초록 텍스트
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text(
              '승인',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _handleReject(Map<String, dynamic> request) {
    final TextEditingController reasonController = TextEditingController();
    // 서버 API에 따라 is_cancel 또는 is_canceled 필드를 사용
    final isCancelRequest =
        (request['is_cancel'] == 1) || (request['is_canceled'] == 1);
    final title = isCancelRequest ? '휴가 취소 반려' : '휴가 반려';
    final message = isCancelRequest
        ? '${request['name']}님의 휴가 취소 상신을 반려합니다.'
        : '${request['name']}님의 휴가 신청을 반려합니다.';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            const Text(
              '반려 사유를 입력해주세요:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '반려 사유를 입력하세요...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('반려 사유를 입력해주세요.')),
                );
                return;
              }
              Navigator.pop(context);

              // API 호출
              try {
                final isCancelRequest = (request['is_cancel'] == 1) ||
                    (request['is_canceled'] == 1);
                print('🔴 휴가 반료 API 호출 시작 (취소 상신: $isCancelRequest)');
                print('🔴 Request 데이터:');
                print('  - request[\"id\"]: ${request['id']}');
                print('  - request[\"requestId\"]: ${request['requestId']}');
                print('  - request[\"leave_id\"]: ${request['leave_id']}');
                print('  - request[\"request_id\"]: ${request['request_id']}');
                print('  - request[\"is_cancel\"]: ${request['is_cancel']}');
                print(
                    '  - request[\"is_canceled\"]: ${request['is_canceled']}');
                print('  - isApproved: false');
                print('  - comment: ${reasonController.text.trim()}');
                print('  - request 전체 객체: $request');
                print('  - request.keys: ${request.keys}');

                // requestId 찾기 - 여러 가능한 키를 확인
                final requestId = request['id']?.toString() ??
                    request['requestId']?.toString() ??
                    request['leave_id']?.toString() ??
                    request['request_id']?.toString() ??
                    '';

                print('🔴 최종 사용할 requestId: $requestId');

                if (requestId.isEmpty) {
                  print('🔴 requestId가 비어있음! API 호출 불가능');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('휴가 신청 ID를 찾을 수 없습니다. 서버에 문의하세요.'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                  return;
                }

                // 현재 로그인한 사용자 ID 가져오기
                final currentUserId = ref.read(userIdProvider) ?? '';
                print('🔴 현재 로그인한 사용자 ID (approverId): $currentUserId');

                final adminRequest = AdminApprovalRequest(
                  id: int.parse(requestId),
                  approverId: currentUserId,
                  isApproved: 'REJECTED',
                  rejectMessage: reasonController.text.trim(),
                );

                // is_canceled 값에 따라 다른 API 호출
                print(
                    '🔴 API 선택: ${isCancelRequest ? "/leave/admin/approval/cancel" : "/leave/admin/approval"}');
                final result = isCancelRequest
                    ? await LeaveApiService.processCancelApproval(
                        request: adminRequest,
                      )
                    : await LeaveApiService.processAdminApproval(
                        request: adminRequest,
                      );

                print('🔴 휴가 반려 API Response:');
                print('  - result: $result');
                print('  - result type: ${result.runtimeType}');
                print('  - result.error: ${result.error}');

                if (!mounted) return; // 위젯이 dispose된 경우 종료

                if (result.error == null) {
                  print('🟢 반료 처리 성공 - UI에서 요청 제거');
                  if (mounted) {
                    setState(() {
                      _approvalRequests.remove(request);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('휴가를 반려했습니다.'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                } else {
                  print('🔴 반료 처리 실패 - error: ${result.error}');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('반료 처리 실패: ${result.error}'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                }
              } catch (e) {
                print('🔴 휴가 반료 API 호출 중 Exception 발생: $e');
                print('🔴 Exception Stack Trace: ${StackTrace.current}');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('반료 처리 중 오류가 발생했습니다: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF9A9A), // 연한 빨강
              foregroundColor: const Color(0xFFC62828), // 진한 빨강 텍스트
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text(
              '반려',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // 모바일로 이미지 내보내기 API 호출
  Future<void> _sendToMobile(BuildContext context, String imageUrl) async {
    try {
      // GiftService의 sendToMobile API 호출
      final giftService = GiftService();
      final response = await giftService.sendToMobile(couponImgUrl: imageUrl);

      // context가 여전히 유효한지 확인
      if (!context.mounted) {
        print('⚠️ Context가 더 이상 유효하지 않습니다. SnackBar를 표시할 수 없습니다.');
        return;
      }

      // 성공 처리
      if (response.containsKey('code') && response['code'] == 'success') {
        CommonUIUtils.showSuccessSnackBar(
            context, response['message'] ?? '이미지가 모바일로 전송되었습니다.');
      } else {
        CommonUIUtils.showErrorSnackBar(
            context, response['message'] ?? '이미지 전송에 실패했습니다.');
      }
    } catch (e) {
      // context가 여전히 유효한지 확인
      if (!context.mounted) {
        print('⚠️ Context가 더 이상 유효하지 않습니다. 에러 SnackBar를 표시할 수 없습니다.');
        return;
      }

      CommonUIUtils.showErrorSnackBar(context, '이미지 전송 중 오류 발생: $e');
      print('❌ sendToMobile API 호출 실패: $e');
    }
  }

  // HTML 렌더링 테스트 메서드 사용 주석 처리
  /*
  Future<void> _testHtmlRendering() async {
    try {
      // HTML 테스트 데이터 로드
      await ref.read(htmlTestProvider.notifier).loadTestHtmlData();

      // 전자결재 패널이 열려있지 않으면 열기
      if (!_isElectronicApprovalPanelVisible) {
        setState(() {
          _isElectronicApprovalPanelVisible = true;

          // 패널이 열릴 때 사이드바를 접기
          if (ref.read(chatProvider).isSidebarVisible) {
            ref.read(chatProvider.notifier).toggleSidebarVisibility();
          }
        });
      }

      // 성공 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('HTML 테스트 데이터가 로드되었습니다. 전자결재 패널에서 기본양식을 선택하여 확인하세요.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('HTML 테스트 데이터 로드 실패: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  */

  /// 전자결재 상신 초안 로딩 패널
  Widget _buildElectronicApprovalLoadingPanel() {
    final themeState = ref.watch(themeProvider);

    return Container(
      decoration: BoxDecoration(
        color: themeState.colorScheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: themeState.colorScheme.backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF4A6CF7).withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 로딩 아이콘
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A6CF7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF4A6CF7)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 로딩 메시지
              Text(
                'AI가 전자결재 초안을 작성중입니다.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: themeState.colorScheme.textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Text(
                '잠시만 기다려주세요...',
                style: TextStyle(
                  fontSize: 14,
                  color:
                      themeState.colorScheme.textColor.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // 진행 바
              Container(
                width: 200,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A6CF7).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF4A6CF7)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 앱 진입 시 업데이트 확인 메서드
  Future<void> _checkForUpdatesOnAppEntry() async {
    try {
      UpdateConfig.log('로그인 후 업데이트 확인 시작...');

      // auto_updater는 자동으로 다이얼로그를 표시합니다
      await UpdateService().checkForUpdatesAfterLogin();

      UpdateConfig.logSuccess('업데이트 확인 완료');
    } catch (e) {
      UpdateConfig.logError('업데이트 확인 중 오류', e);
    }
  }

  // 버전 정보 모달 표시 메서드
  void _showVersionInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('앱 버전 정보'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '현재 앱 버전: ${_appVersion.isNotEmpty ? _appVersion : "알 수 없음"}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 16),
              Text(
                '업데이트 확인: 자동 업데이트가 활성화되어 있습니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                '확인',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 중첩된 JSON 추출 (중괄호 매칭)
  String? _extractNestedJson(String text, String key) {
    final keyPattern = '"$key"';
    final keyIndex = text.indexOf(keyPattern);
    if (keyIndex == -1) return null;

    // key 다음의 : 를 찾음
    final colonIndex = text.indexOf(':', keyIndex);
    if (colonIndex == -1) return null;

    // colon 다음의 공백을 건너뜀
    int startIndex = colonIndex + 1;
    while (startIndex < text.length && (text[startIndex] == ' ' || text[startIndex] == '\n')) {
      startIndex++;
    }

    // { 로 시작하는지 확인
    if (startIndex >= text.length || text[startIndex] != '{') return null;

    // 중첩된 중괄호를 추적하여 JSON 끝 찾기
    int braceCount = 0;
    int jsonStart = startIndex;
    for (int i = startIndex; i < text.length; i++) {
      if (text[i] == '{') {
        braceCount++;
      } else if (text[i] == '}') {
        braceCount--;
        if (braceCount == 0) {
          return text.substring(jsonStart, i + 1);
        }
      }
    }

    return null;
  }

  /// 휴가 추천 메시지 콘텐츠 빌드 (JSON 데이터 파싱 및 렌더링)
  Widget _buildLeaveRecommendationContent(String message, bool isDarkTheme) {
    // JSON 데이터 파싱
    Map<String, dynamic>? leavesData;
    Map<String, dynamic>? weekdayCounts;
    double? holidayAdjacentUsageRate;
    String markdownContent = message;

    try {
      // leaves JSON 추출 (중첩 구조 지원)
      final leavesJsonStr = _extractNestedJson(message, 'leaves');
      if (leavesJsonStr != null) {
        try {
          // 전체 JSON 객체로 감싸서 파싱
          final fullJsonStr = '{"leaves":$leavesJsonStr}';
          leavesData = jsonDecode(fullJsonStr) as Map<String, dynamic>;
          markdownContent = markdownContent.replaceAll(fullJsonStr, '').trim();
          print('✅ leaves JSON 파싱 성공: $leavesData');
        } catch (e) {
          print('⚠️ leaves JSON 파싱 실패: $e');
          print('   추출된 JSON: $leavesJsonStr');
        }
      }

      // weekday_counts JSON 추출 (앞에 텍스트가 있을 수 있음)
      // short{"weekday_counts":...} 같은 패턴 처리
      final weekdayJsonStr = _extractNestedJson(message, 'weekday_counts');
      if (weekdayJsonStr != null) {
        try {
          // 전체 JSON 객체로 감싸서 파싱
          final fullJsonStr = '{"weekday_counts":$weekdayJsonStr}';
          weekdayCounts = jsonDecode(fullJsonStr) as Map<String, dynamic>;
          
          // weekday_counts 패턴 찾기 (앞의 텍스트 포함)
          // "weekday_counts":{...} 또는 short{"weekday_counts":...} 패턴
          // 정확한 패턴: "weekday_counts":{"mon":4.5,...},} 또는 short{"weekday_counts":{...}}
          
          // 방법 1: weekday_counts로 시작하는 부분 찾기 (가장 정확)
          final weekdayStartIndex = message.indexOf('"weekday_counts"');
          if (weekdayStartIndex != -1) {
            // weekday_counts 앞의 텍스트도 포함 (short, long 등)
            int searchStart = weekdayStartIndex - 20; // 앞으로 20자까지 검색
            if (searchStart < 0) searchStart = 0;
            
            // weekday_counts부터 시작하여 JSON 끝까지 찾기
            int braceCount = 0;
            bool foundStart = false;
            
            for (int i = weekdayStartIndex; i < message.length; i++) {
              if (message[i] == '{') {
                braceCount++;
                foundStart = true;
              } else if (message[i] == '}') {
                braceCount--;
                if (foundStart && braceCount == 0) {
                  // 앞의 텍스트도 포함하여 제거
                  String toRemove = message.substring(searchStart, i + 1);
                  // 쉼표나 공백도 함께 제거
                  if (i + 1 < message.length && (message[i + 1] == ',' || message[i + 1] == ' ')) {
                    toRemove += message[i + 1];
                  }
                  markdownContent = markdownContent.replaceAll(toRemove, '').trim();
                  print('✅ weekday_counts 텍스트 제거 완료');
                  break;
                }
              }
            }
          } else {
            // 대체 방법: 정규식 사용
            final altPattern = RegExp(
              r'"?weekday_counts"?\s*:\s*\{[^}]*\}[^}]*\}?[,\s]*',
              dotAll: true,
            );
            markdownContent = markdownContent.replaceAll(altPattern, '').trim();
          }
          print('✅ weekday_counts JSON 파싱 성공: $weekdayCounts');
        } catch (e) {
          print('⚠️ weekday_counts JSON 파싱 실패: $e');
          print('   추출된 JSON: $weekdayJsonStr');
        }
      }

      // holiday_adjacent_usage_rate 추출
      final holidayRateMatch = RegExp(r'"holiday_adjacent_usage_rate"\s*:\s*([\d.]+)').firstMatch(message);
      if (holidayRateMatch != null) {
        holidayAdjacentUsageRate = double.tryParse(holidayRateMatch.group(1)!);
      }

      // JSON 패턴 제거 (더 강력한 패턴)
      // leaves 제거
      markdownContent = markdownContent
          .replaceAll(RegExp(r'\{[^{}]*"leaves"[^{}]*\}', dotAll: true), '')
          .replaceAll(RegExp(r'"leaves"\s*:\s*\{[^}]*\}[^}]*\}?', dotAll: true), '');
      
      // weekday_counts 제거 (다양한 패턴)
      markdownContent = markdownContent
          .replaceAll(RegExp(r'"weekday_counts"\s*:\s*\{[^}]*\}[^}]*\}?[,\s]*', dotAll: true), '')
          .replaceAll(RegExp(r'[^{]*"weekday_counts"[^{}]*\{[^}]*\}[^}]*\}?[,\s]*', dotAll: true), '')
          .replaceAll(RegExp(r'short\s*\{[^}]*"weekday_counts"[^}]*\}', dotAll: true), '')
          .replaceAll(RegExp(r'long\s*\{[^}]*"weekday_counts"[^}]*\}', dotAll: true), '');
      
      // 기타 JSON 패턴 제거
      markdownContent = markdownContent
          .replaceAll(RegExp(r'"holiday_adjacent[^}]*', dotAll: true), '')
          .replaceAll(RegExp(r'"total_leave_days"[^}]*', dotAll: true), '')
          .replaceAll(RegExp(r'short\{|long\{', dotAll: true), '')
          .replaceAll(RegExp(r'\},\s*\}', dotAll: true), '') // 남은 중괄호 제거
          .replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n')
          .trim();
    } catch (e) {
      print('⚠️ JSON 파싱 중 오류: $e');
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. leaves 데이터 차트 (데이터가 있을 때만 표시)
          if (leavesData != null && leavesData['leaves'] != null) ...[
            _buildLeaveSectionTitle('📈 과거 휴가 사용 내역', isDarkTheme),
            const SizedBox(height: 14),
            GradientCard(
              isDarkTheme: isDarkTheme,
              child: _buildLeavesChart(leavesData, isDarkTheme),
            ),
            const SizedBox(height: 28),
          ],

          // 2. weekday_counts 차트 (데이터가 있을 때만 표시)
          if (weekdayCounts != null && weekdayCounts['weekday_counts'] != null) ...[
            _buildLeaveSectionTitle('📊 요일별 연차 사용량', isDarkTheme),
            const SizedBox(height: 14),
            GradientCard(
              isDarkTheme: isDarkTheme,
              child: _buildWeekdayChart(weekdayCounts, isDarkTheme),
            ),
            const SizedBox(height: 28),
          ],

          // 3. 공휴일 인접 사용률
          if (holidayAdjacentUsageRate != null) ...[
            _buildLeaveSectionTitle('🎯 공휴일 인접 사용률', isDarkTheme),
            const SizedBox(height: 14),
            GradientCard(
              isDarkTheme: isDarkTheme,
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                height: 180,
                child: HolidayAdjacentUsageRateChart(
                  usageRate: holidayAdjacentUsageRate,
                  isDarkTheme: isDarkTheme,
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],

          // 4. 마크다운 콘텐츠 (표 포함)
          if (markdownContent.isNotEmpty) ...[
            _buildLeaveSectionTitle('📋 추천 계획', isDarkTheme),
            const SizedBox(height: 14),
            _buildLeaveMarkdownContent(markdownContent, isDarkTheme),
            const SizedBox(height: 28),
          ],
        ],
      ),
    );
  }

  /// leaves 데이터를 MonthlyDistributionChart 형식으로 변환
  Widget _buildLeavesChart(Map<String, dynamic> leavesData, bool isDarkTheme) {
    try {
      final leaves = leavesData['leaves'] as Map<String, dynamic>?;
      if (leaves == null || leaves.isEmpty) {
        return const SizedBox(
          height: 250,
          child: Center(child: Text('데이터 없음')),
        );
      }

      // leaves 데이터 구조: {"2025":{"01":1.5,"02":0.0,...}}
      Map<int, double> monthlyData = {};
      
      for (var yearEntry in leaves.entries) {
        final yearData = yearEntry.value;
        if (yearData is Map<String, dynamic>) {
          // 연도별 데이터 순회
          for (var monthEntry in yearData.entries) {
            final monthStr = monthEntry.key; // "01", "02", ...
            final days = (monthEntry.value as num).toDouble();
            
            try {
              final month = int.parse(monthStr);
              monthlyData[month] = (monthlyData[month] ?? 0) + days;
            } catch (e) {
              print('⚠️ 월 파싱 실패: $monthStr');
            }
          }
        } else {
          // 기존 형식 (날짜 문자열)도 지원
          final dateStr = yearEntry.key;
          final days = (yearEntry.value as num).toDouble();
          
          try {
            final date = DateTime.parse(dateStr);
            final month = date.month;
            monthlyData[month] = (monthlyData[month] ?? 0) + days;
          } catch (e) {
            print('⚠️ 날짜 파싱 실패: $dateStr');
          }
        }
      }

      if (monthlyData.isEmpty) {
        return const SizedBox(
          height: 250,
          child: Center(child: Text('데이터 없음')),
        );
      }

      print('✅ leaves 차트 데이터: $monthlyData');
      return MonthlyDistributionChart(
        monthlyData: monthlyData,
        isDarkTheme: isDarkTheme,
      );
    } catch (e) {
      print('⚠️ leaves 차트 빌드 실패: $e');
      print('   leavesData: $leavesData');
      return const SizedBox(
        height: 250,
        child: Center(child: Text('데이터 없음')),
      );
    }
  }

  /// weekday_counts를 WeekdayDistributionChart 형식으로 변환
  Widget _buildWeekdayChart(Map<String, dynamic> weekdayData, bool isDarkTheme) {
    try {
      final weekdayCounts = weekdayData['weekday_counts'] as Map<String, dynamic>?;
      if (weekdayCounts == null || weekdayCounts.isEmpty) {
        return const SizedBox(
          height: 250,
          child: Center(child: Text('데이터 없음')),
        );
      }

      Map<String, double> counts = {};
      for (var entry in weekdayCounts.entries) {
        counts[entry.key] = (entry.value as num).toDouble();
      }

      if (counts.isEmpty) {
        return const SizedBox(
          height: 250,
          child: Center(child: Text('데이터 없음')),
        );
      }

      return WeekdayDistributionChart(
        weekdayData: counts,
        isDarkTheme: isDarkTheme,
      );
    } catch (e) {
      print('⚠️ weekday 차트 빌드 실패: $e');
      return const SizedBox(
        height: 250,
        child: Center(child: Text('데이터 없음')),
      );
    }
  }

  /// 마크다운 렌더링 (알림함용 - 표 너비 제한)
  Widget _buildLeaveMarkdownContent(String markdown, bool isDarkTheme) {
    final themeColors = isDarkTheme
        ? AppColorSchemes.codingDarkScheme
        : AppColorSchemes.lightScheme;

    return GradientCard(
      isDarkTheme: isDarkTheme,
      child: GptMarkdownRenderer.renderBasicMarkdown(
        markdown,
        themeColors: themeColors,
        role: 1,
        maxWidthFactor: 0.9, // 표 너비를 화면의 90%로 제한
        style: TextStyle(
          fontSize: 14,
          height: 1.8,
          color: isDarkTheme ? Colors.grey[300] : Colors.grey[800],
        ),
      ),
    );
  }

  /// 섹션 제목 빌드
  Widget _buildLeaveSectionTitle(String title, bool isDarkTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: VacationUIColors.primaryGradient,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDarkTheme ? Colors.white : const Color(0xFF1A1D29),
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
