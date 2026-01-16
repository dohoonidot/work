import 'dart:io';
import 'package:ASPN_AI_AGENT/core/database/database_helper.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ASPN_AI_AGENT/ui/screens/login_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:ASPN_AI_AGENT/shared/providers/providers.dart';
import 'package:ASPN_AI_AGENT/ui/theme/app_theme.dart';
import 'package:ASPN_AI_AGENT/shared/services/amqp_service.dart';
import 'package:ASPN_AI_AGENT/shared/utils/app_version_utils.dart';
import 'package:ASPN_AI_AGENT/update/update_service.dart';
import 'package:ASPN_AI_AGENT/provider/leave_management_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 윈도우 크기 변경을 위한 전역 함수 추
Future<void> changeWindowSize(Size size) async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.setSize(size);
    await windowManager.center();
  }
}

// 메인 화면용 윈도우 옵션을 전역 변수로 선언
final mainWindowOptions = WindowOptions(
  size: const Size(1280, 720),
  minimumSize: const Size(600, 300),
  titleBarStyle: TitleBarStyle.normal,
  // backgroundColor 제거하여 시스템 기본값 사용 (시스템 테마에 자동 맞춤)
  center: true, // 윈도우를 화면 중앙에 배치
);

// Navigator에 접근하기 위한 GlobalKey
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 데이터베이스 스키마 복구 함수
///
/// 불완전한 DB 스키마를 감지하고 누락된 컬럼/테이블을 추가합니다.
/// 한 번만 실행되며, 이후에는 SharedPreferences 플래그로 건너뜁니다.
Future<void> _repairDatabaseIfNeeded() async {
  try {
    // 1. 이미 복구했는지 확인
    final prefs = await SharedPreferences.getInstance();
    final isRepaired = prefs.getBool('db_schema_repaired_v9') ?? false;

    if (isRepaired) {
      print('✅ DB 스키마 이미 검증됨 - 건너뜀');
      return;
    }

    print('🔧 DB 스키마 검증 시작...');

    // 2. DB 인스턴스 가져오기
    final db = await DatabaseHelper().database;

    // 3. 트랜잭션으로 안전하게 복구 작업 수행
    await db.transaction((txn) async {
      // 검사 1: local_archive_details에 user_id 컬럼 확인
      final detailsSchema =
          await txn.rawQuery("PRAGMA table_info(local_archive_details)");
      final hasUserId = detailsSchema.any((col) => col['name'] == 'user_id');

      if (!hasUserId) {
        print('🔧 [복구] local_archive_details에 user_id 컬럼 추가 중...');
        await txn.execute(
            'ALTER TABLE local_archive_details ADD COLUMN user_id VARCHAR(30) NOT NULL DEFAULT ""');
        print('✅ [복구] user_id 컬럼 추가 완료');
      } else {
        print('✓ local_archive_details.user_id 컬럼 존재');
      }

      // 검사 2: privacy_agreement 테이블 확인
      final tables = await txn.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='privacy_agreement'");

      if (tables.isEmpty) {
        print('🔧 [복구] privacy_agreement 테이블 생성 중...');
        await txn.execute('''
          CREATE TABLE privacy_agreement(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT UNIQUE NOT NULL,
            is_agreed BOOLEAN NOT NULL DEFAULT false,
            agreed_at TEXT,
            agreement_version TEXT DEFAULT '1.0',
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
          );
        ''');
        print('✅ [복구] privacy_agreement 테이블 생성 완료');
      } else {
        print('✓ privacy_agreement 테이블 존재');
      }

      // 검사 3: auto_login에 password 컬럼 확인
      final autoLoginSchema =
          await txn.rawQuery("PRAGMA table_info(auto_login)");
      final hasPassword =
          autoLoginSchema.any((col) => col['name'] == 'password');

      if (!hasPassword) {
        print('🔧 [복구] auto_login에 password 컬럼 추가 중...');
        await txn.execute('ALTER TABLE auto_login ADD COLUMN password TEXT');
        print('✅ [복구] password 컬럼 추가 완료');
      } else {
        print('✓ auto_login.password 컬럼 존재');
      }

      // 검사 4: 인덱스 확인
      final indexes = await txn.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_archive_details_archive_id'");

      if (indexes.isEmpty) {
        print('🔧 [복구] 인덱스 생성 중...');
        await txn.execute(
            'CREATE INDEX IF NOT EXISTS idx_archive_details_archive_id ON local_archive_details (archive_id)');
        print('✅ [복구] 인덱스 생성 완료');
      } else {
        print('✓ 인덱스 존재');
      }
    });

    // 4. 복구 완료 플래그 저장
    await prefs.setBool('db_schema_repaired_v9', true);
    print('✅ DB 스키마 검증 완료 - 모두 정상입니다.');
  } catch (e, stackTrace) {
    print('❌ DB 복구 중 오류 발생: $e');
    print('스택트레이스: $stackTrace');
    // 에러가 발생해도 앱은 계속 실행 (치명적이지 않은 오류로 처리)
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 앱 버전 정보 초기화
  await AppVersionUtils.initialize();
  final versionInfo = await AppVersionUtils.getDetailedVersionInfo();
  print('📱 앱 버전 정보: $versionInfo');

  // ✨ 자동 업데이트 서비스 초기화 (다음 이벤트 루프에서 실행하여 스레드 문제를 방지)
  Future.microtask(() async {
    try {
      await UpdateService().initialize();
      print('✅ 업데이트 서비스 초기화 완료');
    } catch (e) {
      print('⚠️ 업데이트 서비스 초기화 실패: $e');
    }
  });

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    // 자동 실행 설정
    if (Platform.isWindows) {
      launchAtStartup.setup(
        appName: 'ASPN AI AGENT',
        appPath: Platform.resolvedExecutable,
      );
      await launchAtStartup.enable();
    }

    // 로그인 화면용 윈도우 옵션 (세로가 가로보다 긴 형태)
    WindowOptions loginWindowOptions = WindowOptions(
      // size: const Size(360, 504), // 720 * 0.7 = 504
      // minimumSize: const Size(360, 504),
      size: const Size(400, 600), // 720 * 0.7 = 504
      minimumSize: const Size(400, 600),
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.transparent,
    );

    // 로그인 화면용 윈도우 설정
    await windowManager.waitUntilReadyToShow(loginWindowOptions, () async {
      await windowManager.show();
      // await windowManager.center();
      await windowManager.focus();
    });
  }
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
  }
  await DatabaseHelper().ensureDatabaseDirectoryExists();

  // DB 정보 출력 (디버깅용)
  try {
    print('\n🚀 앱 시작 - 데이터베이스 정보 확인 중...');
    await DatabaseHelper().printDatabaseInfo();

    // 강제 DB 업그레이드 실행
    await DatabaseHelper().forceDatabaseUpgradeToVersion8();
  } catch (e) {
    print('🚨 DB 정보 출력 실패: $e');
  }

  // ⭐ DB 스키마 복구 (불완전한 스키마를 가진 사용자를 위한 자동 복구)
  await _repairDatabaseIfNeeded();

  runApp(const ProviderScope(child: ChatApp()));
}

class ChatApp extends ConsumerStatefulWidget {
  const ChatApp({super.key});

  @override
  ConsumerState<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends ConsumerState<ChatApp> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // 초기화는 한 번만 실행되도록 보장
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) {
        _initializeApp();
        _isInitialized = true;
      }
    });
  }

  Future<void> _initializeApp() async {
    print('🚀 앱 초기화 시작 - AMQP 서비스 설정');
    print('🔧 AMQP 기본 설정 완료 - 연결 후 초기화 예정');

    // 🚀 NotificationNotifier, ChatNotifier, AlertTickerNotifier 즉시 설정 시도
    try {
      final notificationNotifier = ref.read(notificationProvider.notifier);
      final chatNotifier = ref.read(chatProvider.notifier);
      final alertTickerNotifier = ref.read(alertTickerProvider.notifier);
      final leaveManagementNotifier =
          ref.read(leaveManagementProvider.notifier);

      amqpService.setNotifiers(
        notificationNotifier: notificationNotifier,
        chatNotifier: chatNotifier,
        alertTickerNotifier: alertTickerNotifier,
        leaveManagementNotifier: leaveManagementNotifier,
      );
      print('📊 main.dart에서 모든 Notifier 설정 완료');
    } catch (e) {
      print('⚠️ main.dart에서 Notifier 설정 실패: $e');
    }

    // 앱 재시작 시 저장된 사용자 정보로 AMQP 연결 시도
    try {
      final userId = ref.read(userIdProvider);
      if (userId != null && userId.isNotEmpty) {
        print('🔄 앱 재시작 감지 - AMQP 서비스 연결 시도 중...');
        // connect 함수가 내부적으로 개인정보 동의 및 큐 설정을 처리합니다.
        await amqpService.connect(userId);
        print('✅ AMQP 서비스 연결 시도 완료');
      } else {
        print('ℹ️ 저장된 사용자 정보 없음 - 로그인 후 AMQP 연결 예정');
      }
    } catch (e) {
      print('⚠️ 앱 재시작 시 AMQP 연결 실패: $e');
    }

    print('🎯 main.dart AMQP 초기화 완료');
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);

    return MaterialApp(
      navigatorKey: navigatorKey, // GlobalKey 할당
      title: 'ASPN AI Agent (AAA) APP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getThemeData(themeState.colorScheme),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'), // 한국어
        Locale('en', 'US'), // 영어
      ],
      home: const LoginPage(),
    );
  }
}
