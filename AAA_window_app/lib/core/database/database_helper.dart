import 'dart:async';
import 'dart:io';
// import 'dart:convert';

import 'package:ASPN_AI_AGENT/shared/services/api_service.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static File? _debugLogFile;

  // 싱글톤 패턴
  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  // 디버그 로그 초기화
  Future<void> _initDebugLog() async {
    try {
      String executableDir = Directory(Platform.resolvedExecutable).parent.path;
      String logPath = join(executableDir, 'aspn_agent_debug.log');
      _debugLogFile = File(logPath);

      // 로그 파일이 없으면 생성
      if (!await _debugLogFile!.exists()) {
        await _debugLogFile!.create();
      }
    } catch (e) {
      print('디버그 로그 초기화 실패: $e');
    }
  }

  // 디버그 로그 기록
  Future<void> _debugLog(String message) async {
    try {
      if (_debugLogFile == null) {
        await _initDebugLog();
      }

      if (_debugLogFile != null) {
        String timestamp = DateTime.now().toIso8601String();
        String logMessage = '[$timestamp] $message\n';
        await _debugLogFile!.writeAsString(logMessage, mode: FileMode.append);
      }
    } catch (e) {
      print('디버그 로그 기록 실패: $e');
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    await _debugLog('데이터베이스 초기화 시작');

    // 시스템 정보 로깅
    await _debugLog('시스템 정보:');
    await _debugLog('OS: ${Platform.operatingSystem}');
    await _debugLog('실행 경로: ${Platform.resolvedExecutable}');

    // FFI 초기화
    if (Platform.isWindows || Platform.isLinux) {
      await _debugLog('SQLite FFI 초기화');
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // 1. Documents 폴더 시도
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, 'aspn_agent.db');

      await _debugLog('=== DB 경로 정보 ===');
      await _debugLog('Documents 폴더 경로: ${documentsDirectory.path}');
      await _debugLog('시도할 DB 파일 전체 경로: $path');

      // 파일 존재 여부 확인
      File dbFile = File(path);
      bool fileExists = await dbFile.exists();
      await _debugLog('기존 DB 파일 존재 여부: $fileExists');

      if (fileExists) {
        var stat = await dbFile.stat();
        await _debugLog('기존 DB 파일 크기: ${stat.size} bytes');
        await _debugLog('기존 DB 파일 수정 시간: ${stat.modified}');
      }

      // 디렉토리 존재 여부 확인
      bool dirExists = await documentsDirectory.exists();
      await _debugLog('Documents 폴더 존재 여부: $dirExists');

      // 디렉토리 접근 권한 확인
      try {
        await documentsDirectory.stat();
        await _debugLog('Documents 폴더 접근 가능');
      } catch (e) {
        await _debugLog('Documents 폴더 접근 불가: $e');
      }

      final db = await openDatabase(
        path,
        version: 9, // DB 버전 9로 변경
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: _onConfigure,
      );

      // DB 생성 후 파일 정보 다시 확인
      File finalDbFile = File(path);
      if (await finalDbFile.exists()) {
        var finalStat = await finalDbFile.stat();
        await _debugLog('=== DB 생성 완료 ===');
        await _debugLog('최종 DB 파일 경로: $path');
        await _debugLog('최종 DB 파일 크기: ${finalStat.size} bytes');
        await _debugLog('최종 DB 파일 수정 시간: ${finalStat.modified}');

        // 콘솔에도 출력
        print('\n🎯🎯🎯 === 중요: 실제 사용 중인 DB 파일 정보 === 🎯🎯🎯');
        print('🎯 [DB 경로] 성공: $path');
        print('🎯 [DB 크기] ${finalStat.size} bytes');
        print('🎯 [DB 수정시간] ${finalStat.modified}');

        // 파일 탐색기 명령어 출력
        String dirPath = Directory(path).parent.path;
        print('🎯 [탐색기에서 열기] explorer "$dirPath"');
        print('🎯 [DBeaver 연결 경로] $path');
        print('🎯🎯🎯 ========================================== 🎯🎯🎯\n');
      }

      await _debugLog('Documents 폴더에 DB 생성 성공');
      return db;
    } catch (e, stackTrace) {
      await _debugLog('Documents 폴더에 DB 생성 실패:');
      await _debugLog('에러: $e');
      await _debugLog('스택트레이스: $stackTrace');

      // 2. 실행 파일 폴더 시도
      try {
        String executablePath = Platform.resolvedExecutable;
        String executableDir = Directory(executablePath).parent.path;
        String alternativePath = join(executableDir, 'aspn_agent.db');

        await _debugLog('=== 대체 경로 시도 ===');
        await _debugLog('실행 파일 폴더 경로: $executableDir');
        await _debugLog('시도할 DB 파일 전체 경로: $alternativePath');

        final db = await openDatabase(
          alternativePath,
          version: 9, // DB 버전 9로 변경
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
          onConfigure: _onConfigure,
        );

        // 대체 경로 DB 생성 후 파일 정보 확인
        File altDbFile = File(alternativePath);
        if (await altDbFile.exists()) {
          var altStat = await altDbFile.stat();
          await _debugLog('=== 대체 경로 DB 생성 완료 ===');
          await _debugLog('최종 DB 파일 경로: $alternativePath');
          await _debugLog('최종 DB 파일 크기: ${altStat.size} bytes');

          // 콘솔에도 출력
          print('\n🎯🎯🎯 === 중요: 실제 사용 중인 DB 파일 정보 (대체경로) === 🎯🎯🎯');
          print('🎯 [대체 DB 경로] 성공: $alternativePath');
          print('🎯 [대체 DB 크기] ${altStat.size} bytes');
          print('🎯 [DB 수정시간] ${altStat.modified}');

          // 파일 탐색기 명령어 출력
          String dirPath = Directory(alternativePath).parent.path;
          print('🎯 [탐색기에서 열기] explorer "$dirPath"');
          print('🎯 [DBeaver 연결 경로] $alternativePath');
          print(
              '🎯🎯🎯 ============================================== 🎯🎯🎯\n');
        }

        await _debugLog('실행 파일 폴더에 DB 생성 성공');
        return db;
      } catch (e2, stackTrace2) {
        await _debugLog('실행 파일 폴더에 DB 생성 실패:');
        await _debugLog('에러: $e2');
        await _debugLog('스택트레이스: $stackTrace2');

        // 3. 임시 폴더 시도
        try {
          Directory tempDir = await getTemporaryDirectory();
          String tempPath = join(tempDir.path, 'aspn_agent.db');

          await _debugLog('=== 임시 폴더 시도 ===');
          await _debugLog('임시 폴더 경로: ${tempDir.path}');
          await _debugLog('시도할 DB 파일 전체 경로: $tempPath');

          final db = await openDatabase(
            tempPath,
            version: 9, // DB 버전 9로 변경
            onCreate: _onCreate,
            onUpgrade: _onUpgrade,
            onConfigure: _onConfigure,
          );

          // 임시 폴더 DB 생성 후 파일 정보 확인
          File tempDbFile = File(tempPath);
          if (await tempDbFile.exists()) {
            var tempStat = await tempDbFile.stat();
            await _debugLog('=== 임시 폴더 DB 생성 완료 ===');
            await _debugLog('최종 DB 파일 경로: $tempPath');
            await _debugLog('최종 DB 파일 크기: ${tempStat.size} bytes');

            // 콘솔에도 출력
            print('\n🎯🎯🎯 === 중요: 실제 사용 중인 DB 파일 정보 (임시폴더) === 🎯🎯🎯');
            print('🎯 [임시 DB 경로] 성공: $tempPath');
            print('🎯 [임시 DB 크기] ${tempStat.size} bytes');
            print('🎯 [DB 수정시간] ${tempStat.modified}');

            // 파일 탐색기 명령어 출력
            String dirPath = Directory(tempPath).parent.path;
            print('🎯 [탐색기에서 열기] explorer "$dirPath"');
            print('🎯 [DBeaver 연결 경로] $tempPath');
            print(
                '🎯🎯🎯 ============================================ 🎯🎯🎯\n');
          }

          await _debugLog('임시 폴더에 DB 생성 성공');
          return db;
        } catch (e3, stackTrace3) {
          await _debugLog('임시 폴더에 DB 생성 실패:');
          await _debugLog('에러: $e3');
          await _debugLog('스택트레이스: $stackTrace3');
          await _debugLog('모든 경로에서 DB 생성 실패');
          rethrow;
        }
      }
    }
  }

  // 데이터베이스 업그레이드를 위한 콜백 함수
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('데이터베이스 업그레이드: $oldVersion → $newVersion');
    if (oldVersion < 2) {
      // 자동 로그인 테이블 생성
      await db.execute('''
        CREATE TABLE auto_login(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL,
          password_hash TEXT NOT NULL,
          token TEXT NOT NULL,
          created_at TEXT NOT NULL,
          expiration_date TEXT NOT NULL
        );
      ''');
    }

    // 버전 2에서 버전 3으로 업그레이드
    if (oldVersion < 3) {
      print('버전 3으로 업그레이드: local_archives 테이블 수정 및 chat_id AUTOINCREMENT 제거');

      // local_archives 테이블에 id, user_id 컬럼 추가
      await db.execute('''
      CREATE TABLE new_local_archives (
        archive_id TEXT PRIMARY KEY NOT NULL,
        id INTEGER,
        user_id TEXT,
        archive_name TEXT,
        archive_type TEXT,
        archive_time TEXT
      );
    ''');

      // 기존 데이터 복사
      await db.execute('''
      INSERT INTO new_local_archives 
      (archive_id, archive_name, archive_type, archive_time) 
      SELECT archive_id, archive_name, archive_type, archive_time 
      FROM local_archives;
    ''');

      // 기존 테이블 삭제
      await db.execute('DROP TABLE IF EXISTS local_archives');
      await db
          .execute('ALTER TABLE new_local_archives RENAME TO local_archives');

      // local_archive_details 테이블 chat_id에서 AUTOINCREMENT 제거
      await db.execute('''
      CREATE TABLE new_local_archive_details (
        chat_id INTEGER PRIMARY KEY,
        archive_id TEXT NOT NULL,
        message TEXT NOT NULL,
        role INTEGER NOT NULL,
        FOREIGN KEY (archive_id) REFERENCES local_archives (archive_id) 
          ON DELETE CASCADE
      );
    ''');

      // 기존 데이터 복사
      await db.execute('''
        INSERT INTO new_local_archive_details 
        (chat_id, archive_id, message, role) 
        SELECT chat_id, archive_id, message, role 
        FROM local_archive_details;
      ''');

      // 기존 테이블 삭제
      await db.execute('DROP TABLE IF EXISTS local_archive_details');
      await db.execute(
          'ALTER TABLE new_local_archive_details RENAME TO local_archive_details');
    }

    // 버전 3에서 버전 4로 업그레이드
    if (oldVersion < 4) {
      print('버전 4로 업그레이드: 데이터베이스 일관성 검사 및 복구');

      // 테이블이 올바르게 생성되었는지 확인
      try {
        final tables = await db
            .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
        print('현재 테이블 목록: ${tables.map((t) => t['name']).toList()}');

        // local_archives 테이블의 스키마 확인
        final archivesSchema =
            await db.rawQuery("PRAGMA table_info(local_archives)");
        print('local_archives 테이블 스키마: $archivesSchema');

        // local_archive_details 테이블의 스키마 확인
        final detailsSchema =
            await db.rawQuery("PRAGMA table_info(local_archive_details)");
        print('local_archive_details 테이블 스키마: $detailsSchema');
      } catch (e) {
        print('스키마 검사 중 오류: $e');
      }

      // 인덱스 생성으로 성능 개선
      try {
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_archive_details_archive_id ON local_archive_details (archive_id)');
        print('local_archive_details 테이블에 인덱스 생성 완료');
      } catch (e) {
        print('인덱스 생성 중 오류: $e');
      }
    }

    // 버전 4에서 버전 5로 업그레이드
    if (oldVersion < 5) {
      print('버전 5로 업그레이드: birth_message 테이블 생성');

      // 생일 축하 메시지 테이블 생성 (IF NOT EXISTS 추가)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS birth_message(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL,
          message TEXT,
          coupon_image BLOB,
          is_read INTEGER DEFAULT 0,
          is_deleted INTEGER DEFAULT 0
        );
      ''');

      print('birth_message 테이블 생성 완료');
    }

    // 버전 5에서 버전 6으로 업그레이드
    if (oldVersion < 6) {
      print('버전 6으로 업그레이드: birth_message 테이블 BOOLEAN 타입 변경');

      try {
        // 테이블 존재 여부 확인
        final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='birth_message'");

        if (tables.isNotEmpty) {
          // birth_message 테이블이 존재하는 경우에만 업그레이드 수행
          print('기존 birth_message 테이블 발견 - BOOLEAN 타입으로 업그레이드 시작');

          // 기존 데이터를 임시 테이블로 백업
          await db.execute('''
            CREATE TABLE birth_message_backup AS 
            SELECT * FROM birth_message;
          ''');

          // 기존 테이블 삭제
          await db.execute('DROP TABLE IF EXISTS birth_message');

          // 새로운 스키마로 테이블 재생성 (BOOLEAN 타입 사용)
          await db.execute('''
            CREATE TABLE birth_message(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT NOT NULL,
              message TEXT,
              coupon_image BLOB,
              is_read BOOLEAN DEFAULT false,
              is_deleted BOOLEAN DEFAULT false
            );
          ''');

          // 기존 데이터 마이그레이션 (0/1 → false/true 변환)
          await db.execute('''
            INSERT INTO birth_message (id, user_id, message, coupon_image, is_read, is_deleted)
            SELECT 
              id, 
              user_id, 
              message, 
              coupon_image,
              CASE WHEN is_read = 1 THEN true ELSE false END,
              CASE WHEN is_deleted = 1 THEN true ELSE false END
            FROM birth_message_backup;
          ''');

          // 백업 테이블 삭제
          await db.execute('DROP TABLE IF EXISTS birth_message_backup');

          print('birth_message 테이블 BOOLEAN 변환 완료');
        } else {
          // 테이블이 없는 경우 새로 생성
          print('birth_message 테이블이 없음 - 새로 생성');
          await db.execute('''
            CREATE TABLE birth_message(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT NOT NULL,
              message TEXT,
              coupon_image BLOB,
              is_read BOOLEAN DEFAULT false,
              is_deleted BOOLEAN DEFAULT false
            );
          ''');
          print('birth_message 테이블 생성 완료');
        }
      } catch (e) {
        print('birth_message 테이블 업그레이드 중 오류: $e');
        // 오류 발생 시 롤백 시도
        try {
          await db.execute('DROP TABLE IF EXISTS birth_message');
          final backupExists = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='birth_message_backup'");
          if (backupExists.isNotEmpty) {
            await db.execute(
                'ALTER TABLE birth_message_backup RENAME TO birth_message');
            print('롤백 완료');
          }
        } catch (rollbackError) {
          print('롤백 실패: $rollbackError');
        }
        // 치명적이지 않은 오류로 처리 - 앱 진행 계속
        print('birth_message 테이블 업그레이드 실패했지만 앱 진행');
      }
    }

    // 버전 6에서 버전 7로 업그레이드 - local_archive_details에 user_id 추가 & 개인정보 동의 테이블 추가
    if (oldVersion < 7) {
      print(
          '버전 7로 업그레이드: local_archive_details에 user_id 컬럼 추가 및 privacy_agreement 테이블 추가');

      try {
        // 1. local_archive_details 테이블에 user_id 컬럼 추가
        await db.execute('''
          ALTER TABLE local_archive_details 
          ADD COLUMN user_id VARCHAR(30) NOT NULL DEFAULT '';
        ''');
        print('local_archive_details 테이블에 user_id 컬럼 추가 완료');

        // 2. 개인정보 동의 테이블 생성
        await db.execute('''
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
        print('privacy_agreement 테이블 생성 완료');

        // 3. 기존 local_archive_details 데이터의 user_id 업데이트
        print('기존 local_archive_details 데이터의 user_id 업데이트 시작');

        // local_archives와 조인하여 user_id 업데이트
        await db.execute('''
          UPDATE local_archive_details 
          SET user_id = (
            SELECT la.user_id 
            FROM local_archives la 
            WHERE la.archive_id = local_archive_details.archive_id
          )
          WHERE user_id = '' OR user_id IS NULL;
        ''');

        final updatedRows = await db.rawQuery('''
          SELECT COUNT(*) as count 
          FROM local_archive_details 
          WHERE user_id != '' AND user_id IS NOT NULL;
        ''');

        print(
            'local_archive_details user_id 업데이트 완료: ${updatedRows.first['count']}개 행 업데이트됨');
      } catch (e) {
        print('버전 7 업그레이드 중 오류: $e');
      }
    }

    // 버전 7에서 버전 8로 업그레이드 - birth_message 테이블 서버 스키마로 재구성
    if (oldVersion < 8) {
      print('버전 8로 업그레이드: birth_message 테이블 서버 스키마로 재구성');

      try {
        // 기존 birth_message 테이블 삭제
        await db.execute('DROP TABLE IF EXISTS birth_message');

        // 새로운 서버 스키마로 birth_message 테이블 생성
        await db.execute('''
          CREATE TABLE birth_message(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id VARCHAR(50) NOT NULL,
            message TEXT,
            tr_id VARCHAR(20),
            pin_number VARCHAR(20),
            coupon_img_url VARCHAR(100),
            coupon_end_date TIMESTAMP,
            coupon_status VARCHAR(10),
            is_read BOOLEAN DEFAULT false,
            is_deleted BOOLEAN DEFAULT false,
            send_time TIMESTAMP
          );
        ''');
        print('새로운 birth_message 테이블 생성 완료');
      } catch (e) {
        print('버전 8 업그레이드 중 오류: $e');
      }
    }

    // 버전 8에서 버전 9로 업그레이드 - auto_login 테이블에 password 컬럼 추가
    if (oldVersion < 9) {
      print('버전 9로 업그레이드: auto_login 테이블에 password 컬럼 추가');

      try {
        // auto_login 테이블에 password 컬럼 추가 (NULL 허용)
        await db.execute('ALTER TABLE auto_login ADD COLUMN password TEXT');
        print('auto_login 테이블에 password 컬럼 추가 완료');
      } catch (e) {
        print('password 컬럼 추가 중 오류: $e');
      }
    }
  }

  // 외래 키 활성화를 위한 콜백 함수 추가
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // 데이터베이스 테이블 생성 (버전 9 최신 스키마)
  Future<void> _onCreate(Database db, int version) async {
    print('🔨 데이터베이스 최초 생성 (버전 $version)');

    // 아카이브 테이블 생성 (id, user_id 컬럼 포함)
    await db.execute('''
      CREATE TABLE local_archives(
        archive_id TEXT PRIMARY KEY NOT NULL,
        id INTEGER,
        user_id TEXT,
        archive_name TEXT,
        archive_type TEXT,
        archive_time TEXT
      );
    ''');
    print('✅ local_archives 테이블 생성 완료');

    // 채팅 상세 테이블 생성 (user_id 컬럼 포함 - 버전 7부터)
    await db.execute('''
      CREATE TABLE local_archive_details(
        chat_id INTEGER PRIMARY KEY,
        archive_id TEXT NOT NULL,
        message TEXT NOT NULL,
        role INTEGER NOT NULL,
        user_id VARCHAR(30) NOT NULL DEFAULT '',
        FOREIGN KEY (archive_id) REFERENCES local_archives (archive_id)
          ON DELETE CASCADE
      );
    ''');
    print('✅ local_archive_details 테이블 생성 완료 (user_id 포함)');

    // 자동 로그인 테이블 생성 (password 컬럼 포함 - 버전 9부터)
    await db.execute('''
      CREATE TABLE auto_login(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        token TEXT NOT NULL,
        created_at TEXT NOT NULL,
        expiration_date TEXT NOT NULL,
        password TEXT
      );
    ''');
    print('✅ auto_login 테이블 생성 완료 (password 포함)');

    // 개인정보 동의 테이블 생성 (버전 7부터)
    await db.execute('''
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
    print('✅ privacy_agreement 테이블 생성 완료');

    // 생일 축하 메시지 테이블 생성 (버전 8 스키마)
    await db.execute('''
      CREATE TABLE birth_message(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id VARCHAR(50) NOT NULL,
        message TEXT,
        tr_id VARCHAR(20),
        pin_number VARCHAR(20),
        coupon_img_url VARCHAR(100),
        coupon_end_date TIMESTAMP,
        coupon_status VARCHAR(10),
        is_read BOOLEAN DEFAULT false,
        is_deleted BOOLEAN DEFAULT false,
        send_time TIMESTAMP
      );
    ''');
    print('✅ birth_message 테이블 생성 완료');

    // 인덱스 생성 (버전 4부터)
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_archive_details_archive_id ON local_archive_details (archive_id)');
    print('✅ 인덱스 생성 완료');

    print('🎉 데이터베이스 초기화 완료 - 모든 테이블이 최신 스키마(v$version)로 생성됨');
  }

// 자동 로그인 관련 메소드 추가
  Future<int> saveLoginInfo(Map<String, dynamic> loginInfo) async {
    final db = await database;

    // 기존에 같은 user_id로 저장된 정보가 있으면 삭제
    await db.delete(
      'auto_login',
      where: 'user_id = ?',
      whereArgs: [loginInfo['user_id']],
    );

    return await db.insert('auto_login', loginInfo);
  }

  Future<Map<String, dynamic>?> getLoginInfo(String userId) async {
    final db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'auto_login',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getLatestLoginInfo() async {
    final db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'auto_login',
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<int> deleteLoginInfo(String userId) async {
    final db = await database;
    return await db.delete(
      'auto_login',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> deleteAllLoginInfo() async {
    final db = await database;
    await db.delete('auto_login');
  }

  // 유효하지 않은(만료된) 로그인 정보 삭제
  Future<void> cleanupExpiredLoginInfo() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.delete(
      'auto_login',
      where: 'expiration_date < ?',
      whereArgs: [now],
    );
  }

  Future<bool> isLoginTokenValid(String userId, String token) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    List<Map<String, dynamic>> results = await db.query(
      'auto_login',
      where: 'user_id = ? AND token = ? AND expiration_date > ?',
      whereArgs: [userId, token, now],
    );

    return results.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getArchiveListFromLocalByUserId(
      String userId) async {
    final db = await database;

    // user_id로 필터링하여 아카이브 조회
    return await db.query(
      'local_archives',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'archive_time DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getSingleArchiveFromLocal(
      String archiveId) async {
    final db = await database;
    return await db.query(
      'local_archive_details',
      where: 'archive_id = ?',
      whereArgs: [archiveId],
      orderBy: 'chat_id ASC',
    );
  }

  Future<int> createArchive(Map<String, dynamic> archive) async {
    final db = await database;
    return await db.insert('local_archives', archive);
  }

  Future<int> updateArchiveTitle(String archiveId, String newTitle) async {
    final db = await database;
    return await db.update(
      'local_archives',
      {'archive_name': newTitle},
      where: 'archive_id = ?',
      whereArgs: [archiveId],
    );
  }

  Future<int> deleteArchiveChats(String archiveId) async {
    final db = await database;
    return await db.delete(
      'local_archive_details',
      where: 'archive_id = ?',
      whereArgs: [archiveId],
    );
  }

  Future<int> deleteArchive(String archiveId) async {
    final db = await database;
    await deleteArchiveChats(archiveId);

    // 외래 키 제약 조건으로 관련 채팅도 삭제됨

    return await db.delete(
      'local_archives',
      where: 'archive_id = ?',
      whereArgs: [archiveId],
    );
  }

  // 채팅 관련 메소드 (수정됨)
  Future<int> insertUserMessage(String archiveId, String message, String userId,
      {int? chat_id}) async {
    final db = await database;

    // 중복 방지 로직 제거 - 이전 버전 방식으로 복원
    return await db.insert(
      'local_archive_details',
      {
        'chat_id': chat_id,
        'archive_id': archiveId,
        'message': message,
        'role': 0, // 사용자 메시지
        'user_id': userId,
      },
    );
  }

  Future<int> insertAgentMessage(
      String archiveId, String message, String userId,
      {int? chat_id}) async {
    final db = await database;

    // 중복 방지 로직 제거 - 이전 버전 방식으로 복원
    return await db.insert(
      'local_archive_details',
      {
        'chat_id': chat_id,
        'archive_id': archiveId,
        'message': message,
        'role': 1, // 에이전트 메시지
        'user_id': userId,
      },
    );
  }

  Future<bool> archiveExists(String archiveId) async {
    final db = await database;
    var result = await db.query(
      'local_archives',
      where: 'archive_id = ?',
      whereArgs: [archiveId],
    );
    return result.isNotEmpty;
  }

  // 마지막 AI 메시지 찾아 업데이트 (이전 버전 방식)
  Future<void> updateLastAgentMessage(String archiveId, String message) async {
    final db = await database;

    // 아카이브의 모든 채팅 가져오기
    var chats = await db.query(
      'local_archive_details',
      where: 'archive_id = ?',
      whereArgs: [archiveId],
      orderBy: 'chat_id DESC',
    );

    // 마지막 AI 메시지 찾기
    Map<String, dynamic>? lastAiMessage;
    for (var chat in chats) {
      if (chat['role'] == 1) {
        lastAiMessage = chat;
        break;
      }
    }

    if (lastAiMessage != null) {
      // 마지막 AI 메시지 업데이트만 수행
      await db.update(
        'local_archive_details',
        {'message': message},
        where: 'chat_id = ?',
        whereArgs: [lastAiMessage['chat_id']],
      );
      print('마지막 AI 메시지 업데이트 완료: ${lastAiMessage['chat_id']} (이전 버전 방식)');
    }
    // else 블록 제거 - 새 메시지 생성하지 않음 (이전 버전 방식)
  }

  Future<void> ensureDatabaseDirectoryExists() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    if (!await documentsDirectory.exists()) {
      await documentsDirectory.create(recursive: true);
    }
  }

  // 서버 <-> 로컬 싱크 관련 메소드
  static Future<int> getLocalArchiveMaxSerial(String userId) async {
    try {
      // 싱글톤 인스턴스를 직접 생성
      final db = await DatabaseHelper().database;

      // 특정 user_id를 가진 레코드 중 최대 id 값 조회
      final result = await db.rawQuery(
          'SELECT MAX(id) as max_id FROM local_archives WHERE user_id = ?',
          [userId]);

      // 결과 확인 및 반환
      if (result.isNotEmpty && result[0]['max_id'] != null) {
        return result[0]['max_id'] as int;
      } else {
        return 0;
      }
    } catch (e) {
      print('로컬 아카이브 최대 id 조회 오류: $e');
      return 0;
    }
  }

/*
 * max serial 차이에 해당하는 아카이브만 효율적으로 동기화하는 함수
 * (불연속적인 ID도 처리 가능)
 * 
 * @param userId 사용자 ID
 * @return 동기화 결과 정보
 */

  static Future<Map<String, dynamic>> syncArchivesBySerialGap(
      String userId) async {
    try {
      print('아카이브 리스트 동기화 시작 (사용자: $userId)');

      // 1. 로컬 DB에서 해당 사용자의 가장 높은 serial 번호 찾기
      final localMaxSerial = await getLocalArchiveMaxSerial(userId);
      print('로컬 DB의 최대 serial 번호: $localMaxSerial');

      // 2. 서버에서 최대 serial 번호 가져오기
      final serverMaxSerial = await ApiService.getMaxSerial(userId);
      print('서버의 최대 serial 번호: $serverMaxSerial');

      // 3. 서버와 로컬의 max serial이 같으면 동기화 불필요
      if (serverMaxSerial <= localMaxSerial) {
        print('동기화 불필요: 서버와 로컬의 max serial이 같거나 로컬이 더 큼');
        return {
          'success': true,
          'synchronized': false,
          'reason': '동기화 불필요 (로컬 데이터가 최신)',
          'localMaxSerial': localMaxSerial,
          'serverMaxSerial': serverMaxSerial
        };
      }

      // 4. 동기화 필요: 서버의 해당 사용자 아카이브 목록 가져오기
      final serverArchives = await ApiService.getArchiveListFromServer(userId);
      print('서버에서 가져온 사용자 아카이브 수: ${serverArchives.length}');

      // 5. 로컬 DB에서 이미 가지고 있는 아카이브 ID 목록 가져오기
      final db = await DatabaseHelper().database;

      // 전체 로컬 아카이브 조회
      final allLocalArchives = await db.query('local_archives');
      print('전체 로컬 아카이브 개수: ${allLocalArchives.length}');

      // user_id 필터링된 아카이브 조회
      final localArchives = await db.query('local_archives',
          columns: ['archive_id', 'id', 'user_id'],
          where: 'user_id = ?',
          whereArgs: [userId]);

      print('user_id가 "$userId"인 로컬 아카이브 개수: ${localArchives.length}');

      // archive_id를 키로 하는 맵 생성 (중복 검사용)
      final localArchiveMap = {
        for (var archive in localArchives)
          archive['archive_id'].toString(): archive['id']
      };

      print('로컬 아카이브 맵 크기: ${localArchiveMap.length}');

      // 서버 아카이브 ID 목록 출력
      final serverArchiveIds =
          serverArchives.map((a) => a['archive_id']).toList();
      print('서버 아카이브 ID 목록 (전체): $serverArchiveIds');

      // ID 값을 Set으로 만들어 빠른 포함 여부 확인
      localArchives.map((a) => a['id'] as int).toSet();

      // 6. 로컬에 없는 아카이브 중 ID가 localMaxSerial보다 큰 것만 필터링
      final newArchives = serverArchives.where((archive) {
        // archive['id']의 값을 그대로 사용
        final serialId = archive['id'] as int;
        final archiveId = archive['archive_id'].toString();

        // 로컬에 없는 아카이브만 추가
        final isNewArchive = !localArchiveMap.containsKey(archiveId);

        // 디버그 로그 추가 - id 값을 정확히 출력
        print(
            'Archive Check: id=$serialId, archiveId=$archiveId, isNewArchive=$isNewArchive');

        // 새로운 아카이브는 serial ID와 상관없이 추가
        return isNewArchive;
      }).toList();
      print(newArchives);
      print('추가할 새 아카이브 수: ${newArchives.length}');

      // ID가 존재하는 순으로 정렬 (낮은 ID부터)
      newArchives.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));

      // 7. 새 아카이브를 로컬 DB에 배치 삽입 (한 번의 트랜잭션으로)
      int addedCount = 0;
      if (newArchives.isNotEmpty) {
        await db.transaction((txn) async {
          for (var archive in newArchives) {
            // INSERT OR REPLACE를 사용하여 UNIQUE 제약 위반 방지
            await txn.rawInsert('''
              INSERT OR REPLACE INTO local_archives 
              (archive_id, id, user_id, archive_name, archive_type, archive_time) 
              VALUES (?, ?, ?, ?, ?, ?)
            ''', [
              archive['archive_id'],
              archive['id'],
              userId,
              archive['archive_name'],
              archive['archive_type'] ?? '',
              archive['archive_time'],
            ]);
            addedCount++;

            // 삽입 내용 로그
            print(
                '아카이브 추가: ID=${archive['id']}, 이름=${archive['archive_name']}');
          }
        });
      }

      print(
          '동기화 완료: $addedCount개 아카이브 추가됨 (ID 범위: ${localMaxSerial + 1}~$serverMaxSerial)');
      return {
        'success': true,
        'synchronized': true,
        'addedCount': addedCount,
        'localMaxSerial': localMaxSerial,
        'serverMaxSerial': serverMaxSerial,
        'addedIds': newArchives.map((a) => a['id']).toList(),
      };
    } catch (e) {
      print('아카이브 동기화 중 오류 발생: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /*
 * 아카이브 리스트와 디테일을 함께 동기화하는 통합 함수
 * max serial과 max chat id를 기준으로 필요한 데이터만 효율적으로 동기화
 * 
 * @param userId 사용자 ID
 * @return 동기화 결과 정보
 */
  static Future<Map<String, dynamic>> syncArchivesWithDetails(
      String userId) async {
    try {
      print('아카이브 리스트 및 디테일 통합 동기화 시작 (사용자: $userId)');

      // 1. 아카이브 리스트 먼저 동기화
      final listSyncResult = await syncArchivesBySerialGap(userId);

      // 2. 동기화 실패 또는 불필요한 경우 바로 결과 반환
      if (!listSyncResult['success']) {
        print('아카이브 리스트 동기화 실패: ${listSyncResult['error']}');
        return listSyncResult;
      }

      if (!listSyncResult['synchronized']) {
        print('아카이브 리스트 동기화 불필요: ${listSyncResult['reason']}');
        return {
          ...listSyncResult,
          'detailsSynchronized': false,
          'detailReason': '아카이브 리스트 동기화가 불필요하여 디테일 동기화 생략'
        };
      }

      // 3. 새로 추가된 아카이브만 디테일 동기화 진행
      final addedArchiveIds = listSyncResult['addedIds'] as List<dynamic>;
      print('디테일 동기화가 필요한 아카이브 수: ${addedArchiveIds.length}개');

      final detailResults = <String, dynamic>{};
      int totalChatsAdded = 0;

      // 4. 각 새 아카이브의 채팅 내역 가져오기
      for (var id in addedArchiveIds) {
        // id를 문자열로 변환하여 archiveId로 직접 사용하지 말고, archive_id를 DB에서 조회
        final db = await DatabaseHelper().database;
        final archiveResult = await db.query(
          'local_archives',
          columns: ['archive_id'],
          where: 'id = ?',
          whereArgs: [id],
        );

        if (archiveResult.isEmpty) {
          print('ID $id에 해당하는 아카이브를 찾을 수 없습니다.');
          continue;
        }

        final archiveId = archiveResult.first['archive_id'] as String;

        try {
          // 아카이브 디테일 동기화 (새 아카이브이므로 maxChatId=0으로 시작)
          final detailResult =
              await syncArchiveDetail(archiveId, userId: userId);
          detailResults[archiveId] = detailResult;

          if (detailResult['success'] && detailResult['synchronized']) {
            totalChatsAdded += detailResult['addedCount'] as int;
          }
        } catch (e) {
          print('아카이브 ID $archiveId의 디테일 동기화 오류: $e');
          detailResults[archiveId] = {
            'success': false,
            'error': e.toString(),
            'synchronized': false
          };
        }
      }

      print(
          '아카이브 통합 동기화 완료: ${addedArchiveIds.length}개 아카이브, $totalChatsAdded개 채팅 추가');

      // 5. 최종 결과 반환
      return {
        ...listSyncResult,
        'detailsSynchronized': true,
        'totalChatsAdded': totalChatsAdded,
        'detailResults': detailResults
      };
    } catch (e) {
      print('아카이브 통합 동기화 중 오류 발생: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

/*
 * 단일 아카이브의 디테일(채팅) 동기화 함수
 * max chat id를 기준으로 필요한 채팅만 가져와 로컬 DB에 저장
 * 
 * @param archiveId 아카이브 ID
 * @return 동기화 결과 정보
 */
  static Future<Map<String, dynamic>> syncArchiveDetail(String archiveId,
      {String? userId}) async {
    try {
      print('아카이브 디테일 동기화 시작: $archiveId');

      // 새 아카이브이므로 maxChatId를 0으로 설정 (모든 채팅 가져오기)
      final maxChatId = 0;
      print('아카이브 $archiveId의 모든 채팅 가져오기');

      // 서버에서 새 채팅 가져오기
      final newChats = await ApiService.getArchiveDetailFromServer(archiveId,
          maxChatId: maxChatId);

      // 새 채팅이 없어도 성공으로 처리 (수정된 부분)
      if (newChats.isEmpty) {
        print('아카이브 $archiveId: 채팅 내역 없음 (정상)');
        return {
          'success': true, // false에서 true로 변경
          'synchronized': true, // false에서 true로 변경
          'addedCount': 0,
          'archiveId': archiveId,
          'newMaxChatId': 0,
          'chats': 0
        };
      }

      // 새 채팅을 로컬 DB에 저장
      final db = await DatabaseHelper().database;
      int addedCount = 0;
      int newMaxChatId = 0;

      // 트랜잭션으로 모든 채팅 삽입 처리
      await db.transaction((txn) async {
        for (var chat in newChats) {
          final chatId = chat['chat_id'] as int;
          final role = chat['role'] as int;
          final message = chat['message'] as String;

          // 새 채팅 삽입
          await txn.insert('local_archive_details', {
            'chat_id': chatId,
            'archive_id': archiveId,
            'message': message,
            'role': role,
            'user_id': userId ?? '', // user_id 추가
          });

          addedCount++;

          // 최대 chat_id 업데이트
          if (chatId > newMaxChatId) {
            newMaxChatId = chatId;
          }
        }
      });

      print(
          '아카이브 $archiveId 디테일 동기화 완료: $addedCount개 채팅 추가됨 (max_chat_id: $newMaxChatId)');

      // 결과 반환
      return {
        'success': true,
        'synchronized': true,
        'addedCount': addedCount,
        'archiveId': archiveId,
        'newMaxChatId': newMaxChatId,
        'chats': newChats.length
      };
    } catch (e) {
      print('아카이브 디테일 동기화 중 오류 발생: $e');
      return {'success': false, 'error': e.toString(), 'archiveId': archiveId};
    }
  }

/*
 * 로컬 DB에서 특정 아카이브의 최대 chat_id 조회
 * 
 * @param archiveId 아카이브 ID
 * @return 최대 chat_id (없으면 0 반환)
 */
  static Future<int> getLocalMaxChatId(String archiveId) async {
    try {
      final db = await DatabaseHelper().database;

      final result = await db.rawQuery(
          'SELECT MAX(chat_id) as max_chat_id FROM local_archive_details WHERE archive_id = ?',
          [archiveId]);

      if (result.isNotEmpty && result[0]['max_chat_id'] != null) {
        return result[0]['max_chat_id'] as int;
      }

      return 0; // 채팅이 없는 경우
    } catch (e) {
      print('로컬 최대 chat_id 조회 오류: $e');
      return 0; // 오류 시 기본값
    }
  }

  // 아카이브 내용 검색 메서드 수정
  Future<List<Map<String, dynamic>>> searchArchiveContent(
    String searchText, {
    required String userId, // userId를 필수 파라미터로 변경
  }) async {
    try {
      if (searchText.isEmpty) {
        return [];
      }

      final db = await database;
      final results = <Map<String, dynamic>>[];

      // 1. 사용자의 아카이브 목록만 가져오기
      final archives = await db.query(
        'local_archives',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      print('검색 대상 아카이브 수: ${archives.length}개');

      // 2. 각 아카이브에서 검색
      for (var archive in archives) {
        final archiveId = archive['archive_id'] as String;
        final archiveName = archive['archive_name'] as String;
        final archiveType = archive['archive_type'] as String? ?? '';

        // 2-1. 아카이브 제목 검색
        if (archiveName.toLowerCase().contains(searchText.toLowerCase())) {
          results.add({
            ...archive,
            'match_type': 'title',
            'match_text': archiveName,
            'snippet': null,
          });
        }

        // 2-2. 해당 아카이브의 채팅 내용에서만 검색
        final chatMessages = await db.rawQuery(
          '''
          SELECT chat_id, message, role, archive_id 
          FROM local_archive_details 
          WHERE archive_id = ? AND message LIKE ?
          ORDER BY chat_id ASC
          ''',
          [archiveId, '%$searchText%'],
        );

        print('아카이브 $archiveId에서 검색된 채팅 수: ${chatMessages.length}개');

        // 2-3. 검색 결과 처리
        for (var chat in chatMessages) {
          final message = chat['message'] as String;
          final role = chat['role'] as int;
          final chatId = chat['chat_id'] as int;

          // COT 내용 필터링
          String filteredMessage =
              _filterCOTContent(message, archiveType, archiveName, role: role);

          // 검색어의 모든 발생 위치 찾기
          final lowerMessage = filteredMessage.toLowerCase();
          final lowerSearchText = searchText.toLowerCase();
          final matches = lowerSearchText.allMatches(lowerMessage).toList();

          // 각 발생 위치마다 별도의 스니펫 생성
          for (var match in matches) {
            String snippet =
                _createSnippet(filteredMessage, searchText, match.start);

            results.add({
              'archive_id': archiveId,
              'archive_name': archiveName,
              'archive_type': archiveType,
              'chat_id': chatId,
              'role': role,
              'message': filteredMessage,
              'match_type': 'content',
              'match_text': searchText,
              'snippet': snippet,
              'match_index': match.start,
            });
          }
        }
      }

      print('전체 검색 결과 수: ${results.length}개');
      return results;
    } catch (e) {
      print('아카이브 검색 중 오류 발생: $e');
      return [];
    }
  }

  // COT 내용 필터링을 위한 헬퍼 메서드
  String _filterCOTContent(
      String fullText, String archiveType, String archiveName,
      {int? role}) {
    // 사용자 메시지(role=0)는 COT 필터링 없이 원본 반환
    if (role == 0) {
      return fullText;
    }

    // streamChat/withModel API를 사용하는 아카이브들은 COT 부분 완전 제거
    // (코딩 어시스턴트, SAP 어시스턴트, AI Chatbot - <think> 태그가 없으므로)
    bool shouldRemoveCOT = archiveName == '코딩 어시스턴트' ||
        archiveName == 'SAP 어시스턴트' ||
        archiveName == 'AI Chatbot' ||
        archiveType == 'coding' ||
        archiveType == 'sap' ||
        archiveType == 'code';

    if (shouldRemoveCOT) {
      // 1. </think> 태그가 있는지 확인
      final thinkEndIndex = fullText.indexOf('</think>');

      if (thinkEndIndex != -1) {
        // </think> 태그가 있으면 그 이후 부분만 반환
        if (thinkEndIndex + 9 < fullText.length) {
          return fullText.substring(thinkEndIndex + 9); // 태그 길이(9)만큼 건너뛰기
        } else {
          return ''; // </think> 뒤에 내용이 없으면 빈 문자열 반환
        }
      }

      // 2. <think>와 </think> 사이 내용 제거 (기존 정규식 방식)
      final thinkRegex = RegExp(r'<think>[\s\S]*?</think>', multiLine: true);
      final withoutThink = fullText.replaceAll(thinkRegex, '');
      return withoutThink;
    }

    // 사내업무 아카이브 조건 확인
    bool isBusinessArchive = archiveName == '사내업무' || archiveType == '';

    // 1. </think> 태그가 있는지 확인
    final thinkEndIndex = fullText.indexOf('</think>');

    if (thinkEndIndex != -1) {
      // </think> 태그가 있으면 그 이후 부분만 반환
      if (thinkEndIndex + 9 < fullText.length) {
        return fullText.substring(thinkEndIndex + 9); // 태그 길이(9)만큼 건너뛰기
      } else {
        return ''; // </think> 뒤에 내용이 없으면 빈 문자열 반환
      }
    }

    // 2. <think>와 </think> 사이 내용 제거 (기존 정규식 방식)
    // 사내업무 아카이브이고 </think> 태그가 없는 경우에는 특별 처리 필요
    if (isBusinessArchive) {
      // 사내업무에서는 처음부터 cot 시작으로 간주하고 응답 부분만 찾아야 함
      // </think> 태그가 없으면 전체 내용을 COT로 간주하므로 빈 문자열 반환
      return '';
    }

    final thinkRegex = RegExp(r'<think>[\s\S]*?</think>', multiLine: true);
    final withoutThink = fullText.replaceAll(thinkRegex, '');

    return withoutThink;
  }

  // 스니펫 생성 헬퍼 메서드
  String _createSnippet(String fullText, String searchText,
      [int? customIndex]) {
    try {
      final lowerFullText = fullText.toLowerCase();
      final lowerSearchText = searchText.toLowerCase();

      // customIndex가 제공된 경우 해당 인덱스 사용, 아니면 첫 번째 등장 위치 찾기
      final index = customIndex ?? lowerFullText.indexOf(lowerSearchText);

      if (index == -1) return fullText;

      // 검색어 위치의 앞뒤 컨텍스트 포함 (10자)
      int start = (index - 10) < 0 ? 0 : index - 10;
      int end = (index + searchText.length + 10) > fullText.length
          ? fullText.length
          : index + searchText.length + 10;

      String snippet = fullText.substring(start, end);

      // 시작과 끝을 표시
      if (start > 0) snippet = '...$snippet';
      if (end < fullText.length) snippet = '$snippet...';

      return snippet;
    } catch (e) {
      print('스니펫 생성 중 오류: $e');
      return fullText;
    }
  }

  // DB 경로 정보를 반환하는 메소드 (디버깅용)
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;
    Map<String, dynamic> info = {};

    try {
      // 현재 사용 중인 DB 경로 찾기
      if (Platform.isWindows || Platform.isLinux) {
        // 1. Documents 경로 확인
        try {
          Directory documentsDirectory =
              await getApplicationDocumentsDirectory();
          String documentsPath = join(documentsDirectory.path, 'aspn_agent.db');
          File documentsFile = File(documentsPath);

          if (await documentsFile.exists()) {
            var stat = await documentsFile.stat();
            info['documents_path'] = documentsPath;
            info['documents_size'] = stat.size;
            info['documents_modified'] = stat.modified.toString();
            info['active_path'] = documentsPath;
          }
        } catch (e) {
          info['documents_error'] = e.toString();
        }

        // 2. 실행 파일 경로 확인
        try {
          String executablePath = Platform.resolvedExecutable;
          String executableDir = Directory(executablePath).parent.path;
          String execPath = join(executableDir, 'aspn_agent.db');
          File execFile = File(execPath);

          if (await execFile.exists()) {
            var stat = await execFile.stat();
            info['executable_path'] = execPath;
            info['executable_size'] = stat.size;
            info['executable_modified'] = stat.modified.toString();
            if (!info.containsKey('active_path')) {
              info['active_path'] = execPath;
            }
          }
        } catch (e) {
          info['executable_error'] = e.toString();
        }

        // 3. 임시 폴더 경로 확인
        try {
          Directory tempDir = await getTemporaryDirectory();
          String tempPath = join(tempDir.path, 'aspn_agent.db');
          File tempFile = File(tempPath);

          if (await tempFile.exists()) {
            var stat = await tempFile.stat();
            info['temp_path'] = tempPath;
            info['temp_size'] = stat.size;
            info['temp_modified'] = stat.modified.toString();
            if (!info.containsKey('active_path')) {
              info['active_path'] = tempPath;
            }
          }
        } catch (e) {
          info['temp_error'] = e.toString();
        }
      }

      // DB 버전 정보
      var version = await db.rawQuery('PRAGMA user_version');
      info['db_version'] =
          version.isNotEmpty ? version.first['user_version'] : 'unknown';

      // 테이블 목록
      var tables = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      info['tables'] = tables.map((t) => t['name']).toList();

      // 각 테이블의 레코드 수
      for (var table in [
        'local_archives',
        'local_archive_details',
        'auto_login'
      ]) {
        try {
          var count = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
          info['${table}_count'] = count.first['count'];
        } catch (e) {
          info['${table}_error'] = e.toString();
        }
      }
    } catch (e) {
      info['error'] = e.toString();
    }

    return info;
  }

  // DB 정보를 콘솔과 로그에 출력하는 메소드
  Future<void> printDatabaseInfo() async {
    print('\n🔍 ===== 데이터베이스 정보 조회 =====');
    await _debugLog('===== 데이터베이스 정보 조회 시작 =====');

    var info = await getDatabaseInfo();

    for (var key in info.keys) {
      String message = '$key: ${info[key]}';
      print('🔍 $message');
      await _debugLog(message);
    }

    // birth_message 테이블 스키마 확인
    await _checkBirthMessageSchema();

    print('🔍 ===== 데이터베이스 정보 조회 완료 =====\n');
    await _debugLog('===== 데이터베이스 정보 조회 완료 =====');

    // 실제 사용 중인 DB 경로 강제 출력
    await _forceShowDatabasePath();
  }

  // birth_message 테이블 스키마 확인 메서드
  Future<void> _checkBirthMessageSchema() async {
    try {
      final db = await database;

      print('\n🔍 ===== birth_message 테이블 스키마 확인 =====');

      // 테이블 존재 여부 확인
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='birth_message'");

      if (tables.isEmpty) {
        print('🔍 birth_message 테이블이 존재하지 않습니다.');
        return;
      }

      // 테이블 스키마 확인
      final schema = await db.rawQuery("PRAGMA table_info(birth_message)");
      print('🔍 birth_message 테이블 스키마:');
      for (var column in schema) {
        print(
            '🔍   ${column['name']} ${column['type']} (NOT NULL: ${column['notnull']}, DEFAULT: ${column['dflt_value']})');
      }

      // 현재 DB 버전 확인
      final version = await db.rawQuery("PRAGMA user_version");
      print('🔍 현재 데이터베이스 버전: ${version.first['user_version']}');

      print('🔍 ===== birth_message 테이블 스키마 확인 완료 =====\n');
    } catch (e) {
      print('🔍 birth_message 테이블 스키마 확인 중 오류: $e');
    }
  }

  // 강제로 데이터베이스를 버전 8로 업그레이드하는 메서드
  Future<void> forceDatabaseUpgradeToVersion8() async {
    try {
      print('\n🔧 ===== 강제 DB 업그레이드 버전 8 시작 =====');

      final db = await database;

      // 현재 버전 확인
      final currentVersion = await db.rawQuery("PRAGMA user_version");
      int version = currentVersion.first['user_version'] as int;
      print('🔧 현재 DB 버전: $version');

      if (version < 8) {
        print('🔧 버전 8로 업그레이드 실행 중...');

        // birth_message 테이블 재구성
        await db.execute('DROP TABLE IF EXISTS birth_message');
        print('🔧 기존 birth_message 테이블 삭제 완료');

        // 새로운 서버 스키마로 birth_message 테이블 생성
        await db.execute('''
          CREATE TABLE birth_message(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id VARCHAR(50) NOT NULL,
            message TEXT,
            tr_id VARCHAR(20),
            pin_number VARCHAR(20),
            coupon_img_url VARCHAR(100),
            coupon_end_date TIMESTAMP,
            coupon_status VARCHAR(10),
            is_read BOOLEAN DEFAULT false,
            is_deleted BOOLEAN DEFAULT false,
            send_time TIMESTAMP
          );
        ''');
        print('🔧 새로운 birth_message 테이블 생성 완료');

        // 버전을 8로 업데이트
        await db.execute('PRAGMA user_version = 8');
        print('🔧 데이터베이스 버전을 8로 업데이트 완료');

        // 업그레이드 확인
        final newVersion = await db.rawQuery("PRAGMA user_version");
        print('🔧 업그레이드 후 DB 버전: ${newVersion.first['user_version']}');

        print('🔧 ===== 강제 DB 업그레이드 완료 =====\n');
      } else {
        print('🔧 이미 버전 8 이상입니다. 업그레이드 불필요.');
      }
    } catch (e) {
      print('🔧 강제 DB 업그레이드 중 오류: $e');
    }
  }

  // DB 경로를 강제로 출력하는 메소드
  Future<void> _forceShowDatabasePath() async {
    try {
      print('\n🎯🎯🎯 === DB 경로 강제 확인 시작 === 🎯🎯🎯');

      // 1. Documents 경로 확인
      try {
        Directory documentsDirectory = await getApplicationDocumentsDirectory();
        String documentsPath = join(documentsDirectory.path, 'aspn_agent.db');
        File documentsFile = File(documentsPath);

        if (await documentsFile.exists()) {
          var stat = await documentsFile.stat();
          print('🎯 [Documents] 발견: $documentsPath');
          print('🎯 [Documents] 크기: ${stat.size} bytes');
          print('🎯 [Documents] 수정: ${stat.modified}');
          print('🎯 [탐색기] explorer "${documentsDirectory.path}"');
          print('🎯 [DBeaver 연결] $documentsPath');
        } else {
          print('🎯 [Documents] 없음: $documentsPath');
        }
      } catch (e) {
        print('🎯 [Documents] 오류: $e');
      }

      // 2. 실행 파일 경로 확인
      try {
        String executablePath = Platform.resolvedExecutable;
        String executableDir = Directory(executablePath).parent.path;
        String execPath = join(executableDir, 'aspn_agent.db');
        File execFile = File(execPath);

        if (await execFile.exists()) {
          var stat = await execFile.stat();
          print('🎯 [실행파일] 발견: $execPath');
          print('🎯 [실행파일] 크기: ${stat.size} bytes');
          print('🎯 [실행파일] 수정: ${stat.modified}');
          print('🎯 [탐색기] explorer "$executableDir"');
          print('🎯 [DBeaver 연결] $execPath');
        } else {
          print('🎯 [실행파일] 없음: $execPath');
        }
      } catch (e) {
        print('🎯 [실행파일] 오류: $e');
      }

      // 3. 임시 폴더 확인
      try {
        Directory tempDir = await getTemporaryDirectory();
        String tempPath = join(tempDir.path, 'aspn_agent.db');
        File tempFile = File(tempPath);

        if (await tempFile.exists()) {
          var stat = await tempFile.stat();
          print('🎯 [임시폴더] 발견: $tempPath');
          print('🎯 [임시폴더] 크기: ${stat.size} bytes');
          print('🎯 [임시폴더] 수정: ${stat.modified}');
          print('🎯 [탐색기] explorer "${tempDir.path}"');
          print('🎯 [DBeaver 연결] $tempPath');
        } else {
          print('🎯 [임시폴더] 없음: $tempPath');
        }
      } catch (e) {
        print('🎯 [임시폴더] 오류: $e');
      }

      print('🎯🎯🎯 === DB 경로 강제 확인 완료 === 🎯🎯🎯\n');
    } catch (e) {
      print('🚨 DB 경로 강제 확인 실패: $e');
    }
  }

  // ===== 개인정보 동의 관련 메서드들 =====

  /// 개인정보 동의 상태 조회
  Future<Map<String, dynamic>?> getPrivacyAgreement(String userId) async {
    final db = await database;
    final result = await db.query(
      'privacy_agreement',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    if (result.isNotEmpty) {
      print('🔒 개인정보 동의 상태 조회: ${result.first}');
      return result.first;
    }

    print('🔒 개인정보 동의 기록 없음: $userId');
    return null;
  }

  /// 개인정보 동의 저장 또는 업데이트
  Future<int> savePrivacyAgreement(String userId, bool isAgreed) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    try {
      // 기존 기록 확인
      final existing = await getPrivacyAgreement(userId);

      if (existing != null) {
        // 기존 기록 업데이트
        final result = await db.update(
          'privacy_agreement',
          {
            'is_agreed': isAgreed ? 1 : 0, // bool을 int로 변환
            'agreed_at': isAgreed ? now : null,
            'updated_at': now,
          },
          where: 'user_id = ?',
          whereArgs: [userId],
        );
        print('🔒 개인정보 동의 상태 업데이트: $userId → $isAgreed');
        return result;
      } else {
        // 새 기록 생성
        final result = await db.insert('privacy_agreement', {
          'user_id': userId,
          'is_agreed': isAgreed ? 1 : 0, // bool을 int로 변환
          'agreed_at': isAgreed ? now : null,
          'agreement_version': '1.0',
          'created_at': now,
          'updated_at': now,
        });
        print('🔒 개인정보 동의 상태 생성: $userId → $isAgreed');
        return result;
      }
    } catch (e) {
      print('🚨 개인정보 동의 상태 저장 실패: $e');
      return -1;
    }
  }

  /// 개인정보 동의 여부 확인 (boolean 반환)
  Future<bool> isPrivacyAgreed(String userId) async {
    final agreement = await getPrivacyAgreement(userId);
    bool isAgreed =
        agreement?['is_agreed'] == true || agreement?['is_agreed'] == 1;
    print('🔒 개인정보 동의 여부 확인: $userId → $isAgreed');
    return isAgreed;
  }

  /// 모든 사용자의 개인정보 동의 상태 조회 (디버깅용)
  Future<List<Map<String, dynamic>>> getAllPrivacyAgreements() async {
    final db = await database;
    return await db.query('privacy_agreement', orderBy: 'created_at DESC');
  }

  /// 개인정보 동의 기록 삭제 (사용자 탈퇴 시)
  Future<int> deletePrivacyAgreement(String userId) async {
    final db = await database;
    final result = await db.delete(
      'privacy_agreement',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    print('🔒 개인정보 동의 기록 삭제: $userId');
    return result;
  }

  // ===== 개인정보 동의 관련 메서드들 (제거됨) =====
  // 이제 로그인 API 응답에서 개인정보 동의 상태를 받아서 Provider로 관리
}
