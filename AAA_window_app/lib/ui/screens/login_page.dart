import 'package:ASPN_AI_AGENT/core/database/auto_login_service.dart';
import 'package:ASPN_AI_AGENT/core/database/database_helper.dart';
import 'package:ASPN_AI_AGENT/ui/screens/password_change_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/ui/screens/chat_home_page_v5.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart'; // theme_provider 포함
import 'package:ASPN_AI_AGENT/ui/theme/color_schemes.dart';
import 'package:window_manager/window_manager.dart';
import 'package:ASPN_AI_AGENT/main.dart';
import 'package:ASPN_AI_AGENT/shared/widgets/window_controls.dart';
import 'package:ASPN_AI_AGENT/core/config/app_config.dart';
import 'dart:io';
import 'package:ASPN_AI_AGENT/shared/utils/common_ui_utils.dart';
import 'package:ASPN_AI_AGENT/core/mixins/text_editing_controller_mixin.dart';
import 'package:ASPN_AI_AGENT/shared/utils/app_version_utils.dart';
import 'package:ASPN_AI_AGENT/features/auth/login_progress_indicator.dart';

class EmailTextEditingController extends TextEditingController {
  final String fixedDomain;
  bool _isComposing = false;

  EmailTextEditingController({this.fixedDomain = '@aspnc.com', String? text})
      : super(
            text: (text != null && text.contains('@'))
                ? text.substring(0, text.indexOf('@')) + fixedDomain
                : (text ?? '') + fixedDomain) {
    // 커서 위치를 username 부분 끝으로 설정
    selection = TextSelection.collapsed(
        offset: (text?.contains('@') ?? false
            ? text!.substring(0, text.indexOf('@')).length
            : (text?.length ?? 0)));
  }

  @override
  set value(TextEditingValue newValue) {
    // IME 입력 중인 경우 처리하지 않음
    if (newValue.composing.isValid) {
      _isComposing = true;
      super.value = newValue;
    } else if (_isComposing) {
      // IME 입력이 완료된 경우
      _isComposing = false;
      // IME 입력 완료 후 도메인 추가
      String textBeforeDomain = newValue.text;
      if (textBeforeDomain.contains('@')) {
        textBeforeDomain =
            textBeforeDomain.substring(0, textBeforeDomain.indexOf('@'));
      }
      final finalText = textBeforeDomain + fixedDomain;

      super.value = TextEditingValue(
        text: finalText,
        selection: TextSelection.collapsed(offset: textBeforeDomain.length),
        composing: TextRange.empty,
      );
    } else {
      // "@" 앞부분만 사용자가 편집할 수 있음
      String textBeforeDomain;
      int atIndex = newValue.text.indexOf('@');
      if (atIndex == -1) {
        textBeforeDomain = newValue.text;
      } else {
        textBeforeDomain = newValue.text.substring(0, atIndex);
      }
      final finalText = textBeforeDomain + fixedDomain;

      // 커서 위치는 username 부분 범위로 제한
      int selectionOffset = newValue.selection.baseOffset;
      if (selectionOffset > textBeforeDomain.length) {
        selectionOffset = textBeforeDomain.length;
      }

      super.value = TextEditingValue(
        text: finalText,
        selection: TextSelection.collapsed(offset: selectionOffset),
        composing: TextRange.empty,
      );
    }
  }
}

// 자동 로그인 상태 관리를 위한 Provider는 providers.dart에 정의됨

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with TextEditingControllerMixin {
  late EmailTextEditingController usernameController;
  late TextEditingController passwordController;
  final formKey = GlobalKey<FormState>();
  final AutoLoginService _autoLoginService = AutoLoginService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 로그인 화면 진입 시 윈도우 크기 설정
    _setLoginWindowSize();

    usernameController =
        EmailTextEditingController(text: ref.read(usernameProvider));
    passwordController =
        getController('password', text: ref.read(passwordProvider));

    usernameController.addListener(() {
      ref.read(usernameProvider.notifier).state = usernameController.text;
    });

    passwordController.addListener(() {
      ref.read(passwordProvider.notifier).state = passwordController.text;
    });

    // 자동 로그인 체크
    _checkAutoLogin();
  }

  // 로그인 화면 윈도우 크기 설정 메서드
  Future<void> _setLoginWindowSize() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.setSize(const Size(400, 600));
      // await windowManager.center();
    }
  }

  // 자동 로그인 확인 메서드
  Future<void> _checkAutoLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 자동 로그인 확인 시작...');
      final loginInfo = await _autoLoginService.getLatestLoginInfo();

      if (loginInfo != null) {
        final userId = loginInfo['user_id'];
        final token = loginInfo['token'];
        final hasPassword = loginInfo['password'] != null;

        print('📋 저장된 자동 로그인 정보:');
        print('   - 사용자 ID: $userId');
        print('   - 토큰 존재: ${token != null}');
        print('   - 비밀번호 존재: $hasPassword');

        // 토큰 유효성 검사
        final isValid = await _autoLoginService.isTokenValid(userId, token);

        if (isValid) {
          print('✅ 자동 로그인 정보 유효함: $userId');

          // 🔥 추가: 원본 비밀번호로 로그인 API 호출
          final originalPassword = loginInfo['password']; // 저장된 원본 비밀번호 사용

          if (originalPassword != null) {
            print('🔐 원본 비밀번호 발견, 서버 로그인 API 호출 시작...');
            await _callLoginAPIForHistory(userId, originalPassword);
          } else {
            print('⚠️ 원본 비밀번호가 없어서 서버 로그인 API 호출을 건너뜁니다.');
          }

          // 사용자 정보 설정
          ref.read(usernameProvider.notifier).state = userId;
          ref.read(userIdProvider.notifier).state = userId;

          // 🚀 고속 로그인 시스템 사용
          await _performFastAutoLogin(userId, loginInfo);
        } else {
          print('❌ 자동 로그인 정보가 유효하지 않거나 만료됨');
        }
      } else {
        print('📭 저장된 자동 로그인 정보 없음');
      }
    } catch (e) {
      print('❌ 자동 로그인 확인 중 오류 발생: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 로그인 성공 후 처리 (간소화된 버전 - 동기화는 background_init_service에서 처리)
  Future<void> _handleSuccessfulLogin(String userId) async {
    try {
      print('====== 로그인 성공 처리 시작 ======');

      // 현재 로컬 아카이브 확인 (UI 표시용)
      await ref.read(chatProvider.notifier).getArchiveListAll(userId);

      // 업데이트된 아카이브 목록 가져오기
      final updatedChatState = ref.read(chatProvider);

      // 아카이브 정렬 (1.사내업무 2.코딩어시스턴트 3.SAP 어시스턴트 순서로)
      final sortedArchives = List.of(updatedChatState.arvChatHistory);
      sortedArchives.sort((a, b) {
        final aOrder = _getArchiveOrder(a);
        final bOrder = _getArchiveOrder(b);
        return aOrder.compareTo(bOrder);
      });

      print('아카이브 목록 정렬 완료: ${sortedArchives.length}개');

      // 정렬된 아카이브가 있으면 사내업무 선택
      if (sortedArchives.isNotEmpty) {
        // 사내업무 아카이브 찾기 (없으면 첫 번째 아카이브 선택)
        final businessArchive = sortedArchives.firstWhere(
          (archive) =>
              archive['archive_name'].toString().toLowerCase() == '사내업무',
          orElse: () => sortedArchives.first,
        );

        print(
            '선택한 시작 아카이브: ${businessArchive['archive_name']} (ID: ${businessArchive['archive_id']})');

        // 선택한 아카이브 설정 (selectTopic 사용)
        await ref
            .read(chatProvider.notifier)
            .selectTopic(businessArchive['archive_id']);
      } else {
        print('주의: 표시할 아카이브가 없습니다.');
      }

      print('로그인 성공 처리 완료: $userId');
      print('====== 로그인 성공 처리 완료 ======');

      // 로그인 후 DB 정보 출력 (디버깅용)
      try {
        print('\n📊 로그인 후 - 데이터베이스 정보 확인 중...');
        await DatabaseHelper().printDatabaseInfo();
      } catch (e) {
        print('🚨 로그인 후 DB 정보 출력 실패: $e');
      }

      // 윈도우 크기 변경
      await windowManager.waitUntilReadyToShow(mainWindowOptions, () async {
        await windowManager.show();
        await windowManager.center(); // 윈도우를 화면 중앙에 배치
        await windowManager.focus();
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ChatHomePage()),
        );
      }
    } catch (e) {
      print('로그인 후 처리 중 예외 발생: $e');
      // 심각한 오류의 경우 사용자에게 알림
      if (mounted) {
        CommonUIUtils.showInfoSnackBar(
            context, '로그인 후 초기 설정 중 오류가 발생했습니다. 앱을 다시 시작해주세요.');
      }
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    super.dispose();
  }

  // 🔥 새로 추가: 로그인 API 호출 (히스토리 기록용)
  Future<void> _callLoginAPIForHistory(String userId, String password) async {
    try {
      print('🔥🔥🔥 자동 로그인 히스토리 기록을 위한 서버 로그인 API 호출 시작 🔥🔥🔥');
      print('📤 요청 정보:');
      print('   - 사용자 ID: $userId');
      print('   - 비밀번호 길이: ${password.length}자');
      print('   - API 엔드포인트: ${AppConfig.baseUrl}/api/login');

      // 앱 버전 정보 가져오기
      final versionString = await AppVersionUtils.getVersionString();

      // 기존 로그인 API와 동일한 요청 바디 사용
      final requestBody = jsonEncode(<String, String>{
        'user_id': userId,
        'password': password, // 🔥 원본 비밀번호 사용
        'version_info': versionString, // 🔥 앱 버전 정보 추가
      });

      print('📦 요청 바디: $requestBody');
      print('📱 전송되는 버전 정보: $versionString');

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/login'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: requestBody,
      );

      print('📥 서버 응답:');
      print('   - 상태 코드: ${response.statusCode}');
      print('   - 응답 바디: ${response.body}');

      // 응답은 확인하지만 실패해도 자동 로그인은 계속 진행
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        // 🔒 개인정보 동의 상태 처리 (자동 로그인 시에도)
        final isPrivacyAgreed = responseBody['is_agreed'] == 1;
        ref.read(privacyAgreementProvider.notifier).state = isPrivacyAgreed;
        print('🔒 자동 로그인 - 개인정보 동의 상태: $isPrivacyAgreed');
        
        // 🔑 승인자 상태 처리
        final isApprover = responseBody['is_approver'] == 1;
        ref.read(approverProvider.notifier).state = isApprover;
        print('🔑 자동 로그인 - 승인자 상태: $isApprover');

        // 🔑 권한 상태 처리
        final permission = responseBody['permission'] as int?;
        ref.read(permissionProvider.notifier).state = permission;
        print('🔑 자동 로그인 - 권한 상태: $permission');

        print('✅✅✅ 자동 로그인 히스토리 기록 성공 ✅✅✅');
      } else {
        print('⚠️⚠️⚠️ 자동 로그인 히스토리 기록 실패: ${response.statusCode} ⚠️⚠️⚠️');
      }
    } catch (e) {
      print('❌❌❌ 자동 로그인 히스토리 기록 중 오류: $e ❌❌❌');
      // 오류가 발생해도 자동 로그인은 계속 진행
    }
  }

  /// 🚀 새로운 고속 로그인 메서드 (조기 화면 전환 + 백그라운드 초기화)
  Future<void> login(BuildContext context) async {
    if (formKey.currentState!.validate()) {
      final username = ref.read(usernameProvider);
      final password = ref.read(passwordProvider);
      final rememberMe = ref.read(rememberMeProvider);

      if (username.isNotEmpty && password.isNotEmpty) {
        // 진행률 초기화
        ref.read(loginProgressProvider.notifier).reset();

        setState(() {
          _isLoading = true;
        });

        try {
          // 1단계: 로그인 API 호출 (최우선)
          ref
              .read(loginProgressProvider.notifier)
              .setStep(LoginStep.authenticating);

          final apiResult = await _performLoginAPI(username, password);

          if (apiResult['success']) {
            // API 성공 즉시 필수 상태 설정
            ref.read(userIdProvider.notifier).state = username;
            final isPrivacyAgreed = apiResult['isPrivacyAgreed'] as bool;
            ref.read(privacyAgreementProvider.notifier).state = isPrivacyAgreed;
            final isApprover = apiResult['isApprover'] as bool;
            ref.read(approverProvider.notifier).state = isApprover;
            final permission = apiResult['permission'] as int?;
            ref.read(permissionProvider.notifier).state = permission;

            // 자동 로그인 정보 처리
            await _handleRememberMe(username, password, rememberMe);

            print('🚀 [FastLogin] API 완료 - 즉시 화면 전환');

            // 🎯 핵심: API 완료 즉시 화면 전환!
            await _navigateToMainScreen(context);

            // 🔥 백그라운드 초기화는 메인 화면에서 수행
            // 여기서는 진행률 상태만 설정
            ref
                .read(loginProgressProvider.notifier)
                .setStep(LoginStep.connectingAmqp);
          } else {
            // 로그인 실패 처리
            if (mounted) {
              CommonUIUtils.showErrorSnackBar(
                  context, apiResult['error'] ?? '로그인에 실패했습니다.');
            }
          }
        } catch (e) {
          print('❌ [FastLogin] 로그인 중 오류: $e');
          if (mounted) {
            CommonUIUtils.showErrorSnackBar(context, '로그인 오류: $e');
          }
        } finally {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    }
  }

  /// 로그인 API만 실행 (빠른 인증)
  Future<Map<String, dynamic>> _performLoginAPI(
      String username, String password) async {
    try {
      final versionString = await AppVersionUtils.getVersionString();

      final requestBody = jsonEncode(<String, String>{
        'user_id': username,
        'password': password,
        'version_info': versionString,
      });

      print('🔐 [FastLogin] 로그인 API 호출: $username');

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/login'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: requestBody,
      );

      print('📥 [FastLogin] 서버 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['status_code'] == 200) {
          final isPrivacyAgreed = responseBody['is_agreed'] == 1;
          final isApprover = responseBody['is_approver'] == 1;
          final permission = responseBody['permission'] as int?;

          return {
            'success': true,
            'isPrivacyAgreed': isPrivacyAgreed,
            'isApprover': isApprover,
            'permission': permission,
            'response': responseBody,
          };
        } else {
          return {
            'success': false,
            'error': '인증에 실패했습니다.',
          };
        }
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'error': '아이디 또는 비밀번호가 일치하지 않습니다.',
        };
      } else {
        return {
          'success': false,
          'error': '서버 오류가 발생했습니다. (${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': '네트워크 오류: $e',
      };
    }
  }

  /// 자동 로그인 정보 처리
  Future<void> _handleRememberMe(
      String username, String password, bool rememberMe) async {
    if (rememberMe) {
      await _autoLoginService.saveAutoLoginInfo(username, password, rememberMe);
      print('💾 [FastLogin] 자동 로그인 정보 저장');
    } else {
      await _autoLoginService.deleteLoginInfo(username);
      print('🗑️ [FastLogin] 자동 로그인 정보 삭제');
    }
  }

  /// 메인 화면으로 즉시 이동
  Future<void> _navigateToMainScreen(BuildContext context) async {
    // 윈도우 크기 변경 (기존 로직 유지)
    await windowManager.waitUntilReadyToShow(mainWindowOptions, () async {
      await windowManager.show();
      await windowManager.center();
      await windowManager.focus();
    });

    // 화면 전환
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ChatHomePage()),
      );
      print('🎯 [FastLogin] 메인 화면 전환 완료');
    }
  }

  /// 🚀 고속 자동 로그인 수행
  Future<void> _performFastAutoLogin(
      String userId, Map<String, dynamic> loginInfo) async {
    try {
      // 진행률 초기화
      ref.read(loginProgressProvider.notifier).reset();
      ref
          .read(loginProgressProvider.notifier)
          .setStep(LoginStep.authenticating);

      print('🚀 [FastAutoLogin] 고속 자동 로그인 시작: $userId');

      // 1단계: 서버 API 호출 (이력 기록용)
      final originalPassword = loginInfo['password'];
      if (originalPassword != null) {
        print('🔐 [FastAutoLogin] 서버 로그인 API 호출');
        await _callLoginAPIForHistory(userId, originalPassword);
      }

      // 2단계: 필수 상태 설정 즉시 수행
      ref.read(userIdProvider.notifier).state = userId;

      // 개인정보 동의 상태는 API 응답에서 설정됨

      print('🚀 [FastAutoLogin] API 완료 - 즉시 화면 전환');

      // 3단계: API 완료 즉시 화면 전환!
      await _navigateToMainScreen(context);

      // 4단계: 백그라운드 초기화 신호
      ref
          .read(loginProgressProvider.notifier)
          .setStep(LoginStep.connectingAmqp);

      print('✅ [FastAutoLogin] 고속 자동 로그인 완료');
    } catch (e) {
      print('❌ [FastAutoLogin] 자동 로그인 오류: $e');
      // 오류 시 기존 방식 대체
      await _handleSuccessfulLogin(userId);
    }
  }

  // 아카이브 정렬 순서 결정 메소드
  int _getArchiveOrder(dynamic archive) {
    final archiveName = archive['archive_name'].toString().toLowerCase();
    final archiveType = archive['archive_type'].toString().toLowerCase();

    if (archiveName == '사내업무') return 0;
    if (archiveType == 'code') return 1;
    if (archiveType == 'sap') return 2;
    return 3; // 다른 아카이브는 우선순위 낮게
  }

  @override
  Widget build(BuildContext context) {
    // Provider에서 자동 로그인 상태 가져오기
    final rememberMe = ref.watch(rememberMeProvider);

    // 로딩 중일 때 로딩 인디케이터 표시
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('로그인 중...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    // 화면 크기 계산
    // final screenHeight = MediaQuery.of(context).size.height;
    final maxWidth = 400.0; // 스마트폰 가로 크기

    return DraggableWindow(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: maxWidth,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 로고 이미지
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Image.asset(
                                  'assets/icon/ASPN_AAA_logo.png',
                                  width: 60,
                                  height: 60,
                                ),
                              ),
                            ),

                            // 앱 이름
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.only(bottom: 12.0),
                                child: Text(
                                  'ASPN AI 에이전트',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromARGB(255, 29, 68, 135),
                                  ),
                                ),
                              ),
                            ),

                            // 아이디 입력 필드
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              child: TextFormField(
                                autofocus: true,
                                controller: usernameController,
                                style: const TextStyle(color: Colors.black87),
                                decoration: InputDecoration(
                                  labelText: '아이디',
                                  labelStyle:
                                      const TextStyle(color: Colors.grey),
                                  prefixIcon: const Icon(Icons.person,
                                      color: Colors.grey),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide:
                                        const BorderSide(color: Colors.grey),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide:
                                        const BorderSide(color: Colors.grey),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: const BorderSide(
                                        color:
                                            Color.fromARGB(255, 29, 68, 135)),
                                  ),
                                  fillColor: Colors.white,
                                  filled: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10.0,
                                    horizontal: 16.0,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '아이디를 입력해 주세요.';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (value) => login(context),
                              ),
                            ),

                            const SizedBox(height: 10.0),

                            // 비밀번호 입력 필드
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              child: TextFormField(
                                controller: passwordController,
                                style: const TextStyle(color: Colors.black87),
                                decoration: InputDecoration(
                                  labelText: '비밀번호',
                                  labelStyle:
                                      const TextStyle(color: Colors.grey),
                                  prefixIcon: const Icon(Icons.lock,
                                      color: Colors.grey),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide:
                                        const BorderSide(color: Colors.grey),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide:
                                        const BorderSide(color: Colors.grey),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: const BorderSide(
                                        color:
                                            Color.fromARGB(255, 29, 68, 135)),
                                  ),
                                  fillColor: Colors.white,
                                  filled: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10.0,
                                    horizontal: 16.0,
                                  ),
                                ),
                                obscureText: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '비밀번호를 입력해 주세요.';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (value) => login(context),
                              ),
                            ),

                            const SizedBox(height: 6.0),

                            // 자동 로그인 체크박스
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              child: Consumer(
                                builder: (context, ref, child) {
                                  final themeState = ref.watch(themeProvider);
                                  final isDarkTheme = themeState.themeMode ==
                                      AppThemeMode.codingDark;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0,
                                      vertical: 8.0,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isDarkTheme
                                            ? Colors.grey.shade600
                                            : Colors.grey.shade300,
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                      color: isDarkTheme
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade50,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: Checkbox(
                                            value: rememberMe,
                                            onChanged: (value) {
                                              ref
                                                  .read(rememberMeProvider
                                                      .notifier)
                                                  .state = value!;
                                            },
                                            activeColor: const Color.fromARGB(
                                                255, 29, 68, 135),
                                            checkColor: Colors.white,
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                        ),
                                        const SizedBox(width: 8.0),
                                        Text(
                                          '자동 로그인',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDarkTheme
                                                ? Colors.black
                                                : Colors.black87,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const Spacer(),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 12.0),

                            // 로그인 버튼
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              child: ElevatedButton(
                                onPressed: () => login(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                    255,
                                    29,
                                    68,
                                    135,
                                  ),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10.0,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  elevation: 2,
                                ),
                                child: const Text(
                                  '로그인',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8.0),

                            // 비밀번호 변경 버튼
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const PasswordChangePage(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey[700],
                                ),
                                child: const Text(
                                  '비밀번호 변경',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 윈도우 컨트롤 버튼
              Positioned(
                top: 0,
                right: 0,
                child: const WindowControls(iconColor: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// DraggableWindow 위젯 추가
class DraggableWindow extends StatelessWidget {
  final Widget child;

  const DraggableWindow({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        windowManager.startDragging();
      },
      child: child,
    );
  }
}
