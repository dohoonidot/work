/// AMQP 시스템 전용 로거
/// 로그 레벨에 따라 출력을 제어하여 운영환경에서 성능을 최적화합니다.
class AmqpLogger {
  static const String _tag = '[AMQP]';
  
  /// 로그 레벨 정의
  static const int LEVEL_ERROR = 1;   // 에러만
  static const int LEVEL_WARN = 2;    // 경고 + 에러
  static const int LEVEL_INFO = 3;    // 정보 + 경고 + 에러
  static const int LEVEL_DEBUG = 4;   // 모든 로그
  
  /// 현재 로그 레벨 (운영: LEVEL_WARN, 개발: LEVEL_DEBUG)
  static int _currentLevel = LEVEL_INFO; // 기본값: INFO
  
  /// 로그 레벨 설정
  static void setLevel(int level) {
    _currentLevel = level;
    info('로그 레벨 변경: ${_levelToString(level)}');
  }
  
  /// 현재 로그 레벨 반환
  static int getCurrentLevel() => _currentLevel;
  
  /// 에러 로그 (항상 출력)
  static void error(String message, [dynamic error]) {
    if (_currentLevel >= LEVEL_ERROR) {
      if (error != null) {
        print('❌ $_tag $message: $error');
      } else {
        print('❌ $_tag $message');
      }
    }
  }
  
  /// 경고 로그
  static void warn(String message) {
    if (_currentLevel >= LEVEL_WARN) {
      print('⚠️ $_tag $message');
    }
  }
  
  /// 정보 로그
  static void info(String message) {
    if (_currentLevel >= LEVEL_INFO) {
      print('ℹ️ $_tag $message');
    }
  }
  
  /// 성공 로그
  static void success(String message) {
    if (_currentLevel >= LEVEL_INFO) {
      print('✅ $_tag $message');
    }
  }
  
  /// 디버그 로그
  static void debug(String message) {
    if (_currentLevel >= LEVEL_DEBUG) {
      print('🔍 $_tag $message');
    }
  }
  
  /// 연결 관련 로그
  static void connection(String message) {
    if (_currentLevel >= LEVEL_INFO) {
      print('🔌 $_tag $message');
    }
  }
  
  /// 헬스체크 로그
  static void health(String message) {
    if (_currentLevel >= LEVEL_DEBUG) {
      print('💓 $_tag $message');
    }
  }
  
  /// 메시지 처리 로그
  static void message(String message) {
    if (_currentLevel >= LEVEL_DEBUG) {
      print('📨 $_tag $message');
    }
  }
  
  /// 리소스 정리 로그
  static void cleanup(String message) {
    if (_currentLevel >= LEVEL_INFO) {
      print('🧹 $_tag $message');
    }
  }
  
  /// 재연결 로그
  static void reconnect(String message) {
    if (_currentLevel >= LEVEL_INFO) {
      print('🔄 $_tag $message');
    }
  }
  
  /// 상태 변경 로그
  static void state(String message) {
    if (_currentLevel >= LEVEL_INFO) {
      print('📊 $_tag $message');
    }
  }
  
  /// 로그 레벨을 문자열로 변환
  static String _levelToString(int level) {
    switch (level) {
      case LEVEL_ERROR: return 'ERROR';
      case LEVEL_WARN: return 'WARN';
      case LEVEL_INFO: return 'INFO';
      case LEVEL_DEBUG: return 'DEBUG';
      default: return 'UNKNOWN';
    }
  }
  
  /// 운영환경용 로그 레벨 설정
  static void setProductionLevel() {
    setLevel(LEVEL_WARN);
  }
  
  /// 개발환경용 로그 레벨 설정
  static void setDevelopmentLevel() {
    setLevel(LEVEL_DEBUG);
  }
  
  /// 테스트환경용 로그 레벨 설정
  static void setTestLevel() {
    setLevel(LEVEL_INFO);
  }
}